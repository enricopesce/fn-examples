provider "oci" {}

locals {
  fnroot         = abspath(path.root)
  fndocker       = "${abspath(path.root)}/Dockerfile"
  fnyaml         = "${abspath(path.root)}/func.yaml"
  fncode         = "${abspath(path.root)}/func.py"
  fnrequirements = "${abspath(path.root)}/requirements.txt"
  rawfndata      = yamldecode(file(local.fnyaml))
}

###################################################################################################

resource "oci_core_vcn" "test_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_id
  display_name   = "vcn-${var.application_name}"
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block     = "10.0.100.0/24"
  compartment_id = var.compartment_id
  display_name   = "public_subnet"
  vcn_id         = oci_core_vcn.test_vcn.id
  route_table_id = oci_core_vcn.test_vcn.default_route_table_id
  security_list_ids = [
    oci_core_vcn.test_vcn.default_security_list_id,
  ]
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_id
  display_name   = "internet_gateway"
  vcn_id         = oci_core_vcn.test_vcn.id
}

resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.test_vcn.default_route_table_id
  route_rules {
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

##################################################################################################

resource "oci_objectstorage_bucket" "input_bucket" {
  compartment_id        = var.compartment_id
  name                  = "input-bucket"
  namespace             = var.bucket_namespace
  object_events_enabled = "true"
}

resource "oci_events_rule" "rule" {
  actions {
    actions {
      action_type = "FAAS"
      function_id = oci_functions_function.function.id
      is_enabled  = "true"
    }
  }
  compartment_id = var.compartment_id
  condition      = "{\"eventType\":[\"com.oraclecloud.objectstorage.createobject\"],\"data\":{\"additionalDetails\":{\"bucketName\":[\"${oci_objectstorage_bucket.input_bucket.name}\"]}}}"
  display_name   = var.application_name
  is_enabled     = "true"
}

resource "oci_objectstorage_bucket" "processed_bucket" {
  compartment_id = var.compartment_id
  name           = "processed-bucket"
  namespace      = var.bucket_namespace
}

##################################################################################################

resource "oci_database_autonomous_database" "adb" {
  compartment_id              = var.compartment_id
  db_name                     = var.application_name
  admin_password              = base64decode(data.oci_secrets_secretbundle.bundle.secret_bundle_content.0.content)
  data_storage_size_in_tbs    = 1
  db_version                  = "21c"
  db_workload                 = "OLTP"
  display_name                = "db-${var.application_name}"
  is_free_tier                = true
  is_mtls_connection_required = true
  ocpu_count                  = 1
}

resource "oci_database_autonomous_database_wallet" "adb_wallet" {
  autonomous_database_id = oci_database_autonomous_database.adb.id
  password               = base64decode(data.oci_secrets_secretbundle.bundle.secret_bundle_content.0.content)
  base64_encode_content  = "true"
}

resource "local_file" "autonomous_database_wallet_file" {
  content_base64 = oci_database_autonomous_database_wallet.adb_wallet.content
  filename       = "${path.module}/wallet.zip"
}

output "database_autonomous_database_wallet_autonomous_database_id" {
  value = oci_database_autonomous_database_wallet.adb_wallet.autonomous_database_id
}

output "database_autonomous_database_wallet_id" {
  value = oci_database_autonomous_database_wallet.adb_wallet.id
}

output "password_id" {
  value = oci_vault_secret.db_password.secret_name
}

###################################################################################################

resource "oci_functions_application" "application" {
  compartment_id = var.compartment_id
  display_name   = var.application_name
  subnet_ids     = [oci_core_subnet.public_subnet.id]
}

resource "null_resource" "deploy_function" {
  depends_on = [oci_functions_application.application, local_file.autonomous_database_wallet_file]
  triggers = {
    fnyaml                = "${sha1(file(local.fnyaml))}"
    fnfilechanged         = "${sha1(file(local.fncode))}"
    fnrequirementschanged = "${sha1(file(local.fnrequirements))}"
    dockerfilechanged     = "${sha1(file(local.fndocker))}"
  }

  provisioner "local-exec" {
    working_dir = local.fnroot
    command     = <<-EOC
      fn build
      fn push
    EOC
  }
}

locals {
  fndata = {
    name    = local.rawfndata.name
    version = local.rawfndata.version
    memory  = local.rawfndata.memory
    image   = "${var.registry}/${local.rawfndata.name}:${local.rawfndata.version}"
  }
}

resource "oci_functions_function" "function" {
  depends_on     = [oci_database_autonomous_database.adb]
  application_id = oci_functions_application.application.id
  display_name   = local.fndata.name
  image          = local.fndata.image
  memory_in_mbs  = local.fndata.memory
  config = {
    "ATP_USERNAME"      = "ADMIN"
    "ATP_PASSWORD_OCID" = oci_vault_secret.db_password.id
    "DB_DNS"            = [for profile in oci_database_autonomous_database.adb.connection_strings[0].profiles : profile.display_name if upper(profile.consumer_group) == "HIGH"][0]
    "TNS_ADMIN" : "/function/wallet"
  }
  provisioned_concurrency_config {
    strategy = "CONSTANT"
    count    = 20
  }  
}

resource "oci_identity_dynamic_group" "dynamic_group" {
  compartment_id = var.root_compartment_id
  description    = "enable function access to secrets"
  matching_rule  = "All {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_id}'}"
  name           = "${var.application_name}-${random_string.id.result}"
}

resource "oci_identity_policy" "policy" {
  compartment_id = var.root_compartment_id
  description    = "enable function access to secrets"
  name           = "${var.application_name}-${random_string.id.result}"
  statements     = ["Allow dynamic-group ${oci_identity_dynamic_group.dynamic_group.name} to read secret-bundles in compartment id ${var.compartment_id}"]
}

###################################################################################################

resource "oci_logging_log_group" "log_group" {
  compartment_id = var.compartment_id
  display_name   = "log_group-${var.application_name}"
}

resource "oci_logging_log" "fn_log" {
  display_name = "log_fn-${local.rawfndata.name}"
  log_group_id = oci_logging_log_group.log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "invoke"
      resource    = oci_functions_application.application.id
      service     = "functions"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_id
  }
  is_enabled = true
}

###################################################################################################

resource "random_password" "password" {
  length           = 16
  special          = true
  min_numeric      = 1
  min_upper        = 1
  min_lower        = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "id" {
  length  = 4
  special = false
}

resource "oci_vault_secret" "db_password" {
  compartment_id = var.compartment_id
  key_id         = var.vault_key_ocid
  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.password.result)
  }
  secret_name = "db-${random_string.id.result}"
  vault_id    = var.vault_ocid
}

data "oci_secrets_secretbundle" "bundle" {
  secret_id = oci_vault_secret.db_password.id
}


