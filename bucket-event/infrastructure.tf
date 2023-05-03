provider "oci" {}

locals {
  fnroot    = abspath(path.root)
  fnyaml    = "${abspath(path.root)}/func.yaml"
  fncode    = "${abspath(path.root)}/func.py"
  rawfndata = yamldecode(file(local.fnyaml))
  fndata = {
    name    = local.rawfndata.name
    version = local.rawfndata.version
    memory  = local.rawfndata.memory
    image   = "${var.registry}/${local.rawfndata.name}:${local.rawfndata.version}"
  }
}

resource "oci_objectstorage_bucket" "test_bucket" {
  compartment_id        = var.compartment_id
  name                  = var.bucket_name
  namespace             = var.bucket_namespace
  object_events_enabled = "true"
}

resource "oci_core_vcn" "test_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_id
  display_name   = "test_vcn"
}

resource "oci_core_subnet" "test_public_subnet" {
  cidr_block     = "10.0.100.0/24"
  compartment_id = var.compartment_id
  display_name   = "test_public_subnet"
  vcn_id         = oci_core_vcn.test_vcn.id
  route_table_id = oci_core_vcn.test_vcn.default_route_table_id
  security_list_ids = [
    oci_core_vcn.test_vcn.default_security_list_id,
  ]
}

resource "oci_core_internet_gateway" "test_internet_gateway" {
  compartment_id = var.compartment_id
  display_name   = "test_internet_gateway"
  vcn_id         = oci_core_vcn.test_vcn.id
}

resource "oci_core_default_route_table" "test_default_route_table" {
  manage_default_resource_id = oci_core_vcn.test_vcn.default_route_table_id
  route_rules {
    network_entity_id = oci_core_internet_gateway.test_internet_gateway.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_functions_application" "test_application" {
  compartment_id = var.compartment_id
  display_name   = var.application_name
  subnet_ids     = [oci_core_subnet.test_public_subnet.id]
}

resource "oci_events_rule" "test_rule" {
  actions {
    actions {
      action_type = "FAAS"
      function_id = oci_functions_function.test_function.id
      is_enabled  = "true"
    }
  }
  compartment_id = var.compartment_id
  condition      = "{\"eventType\":[\"com.oraclecloud.objectstorage.createobject\"],\"data\":{\"additionalDetails\":{\"bucketName\":[\"${oci_objectstorage_bucket.test_bucket.name}\"]}}}"
  display_name   = "testrule"
  is_enabled     = "true"
}

resource "null_resource" "deploy_function" {
  triggers = {
    fnfilechanged = "${sha1(file(local.fncode))}"
  }

  provisioner "local-exec" {
    working_dir = local.fnroot
    command     = <<-EOC
      fn deploy --app ${var.application_name}
    EOC
  }
}

resource "oci_functions_function" "test_function" {
  depends_on     = [null_resource.deploy_function]
  application_id = oci_functions_application.test_application.id
  display_name   = local.fndata.name
  image          = local.fndata.image
  memory_in_mbs  = local.fndata.memory
}

resource "oci_logging_log_group" "test_log_group" {
  compartment_id = var.compartment_id
  display_name   = "test_log_group"
}

resource "oci_logging_log" "test_fn_log" {
  display_name = "test_fn_log"
  log_group_id = oci_logging_log_group.test_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "invoke"
      resource    = oci_functions_application.test_application.id
      service     = "functions"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_id
  }
  is_enabled = true
}

resource "oci_logging_log" "test_event_log" {
  display_name = "test_event_log"
  log_group_id = oci_logging_log_group.test_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "ruleexecutionlog"
      resource    = oci_events_rule.test_rule.id
      service     = "cloudevents"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_id
  }
  is_enabled = true
}
