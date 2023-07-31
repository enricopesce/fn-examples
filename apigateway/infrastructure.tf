provider "oci" {}

locals {
  fnroot         = abspath(path.root)
  # fndocker       = "${abspath(path.root)}/Dockerfile"
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

resource "oci_functions_application" "application" {
  compartment_id = var.compartment_id
  display_name   = var.application_name
  subnet_ids     = [oci_core_subnet.public_subnet.id]
}

resource "null_resource" "deploy_function" {
  depends_on = [oci_functions_application.application]
  triggers = {
    fnyaml                = "${sha1(file(local.fnyaml))}"
    fnfilechanged         = "${sha1(file(local.fncode))}"
    fnrequirementschanged = "${sha1(file(local.fnrequirements))}"
    # dockerfilechanged     = "${sha1(file(local.fndocker))}"
  }

  provisioner "local-exec" {
    working_dir = local.fnroot
    command     = <<-EOC
      fn deploy --verbose --app ${var.application_name}
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
  application_id = oci_functions_application.application.id
  display_name   = local.fndata.name
  image          = local.fndata.image
  memory_in_mbs  = local.fndata.memory
  config = {
    "ATP_USERNAME" = "ADMIN"
  }
}

resource "oci_identity_policy" "FoggyKitchenManageAPIGWFamilyPolicy" {
  name           = "FoggyKitchenManageAPIGWFamilyPolicy"
  description    = "FoggyKitchenManageAPIGWFamilyPolicy"
  compartment_id = var.compartment_id
  statements     = ["Allow group Administrators to manage api-gateway-family in compartment id ${var.compartment_id}"]
}

resource "oci_identity_policy" "FoggyKitchenManageVCNFamilyPolicy" {
  name           = "FoggyKitchenManageVCNFamilyPolicy"
  description    = "FoggyKitchenManageVCNFamilyPolicy"
  compartment_id = var.compartment_id
  statements     = ["Allow group Administrators to manage virtual-network-family in compartment id ${var.compartment_id}"]
}

resource "oci_identity_policy" "FoggyKitchenUseFnFamilyPolicy" {
  name           = "FoggyKitchenUseFnFamilyPolicy"
  description    = "FoggyKitchenUseFnFamilyPolicy"
  compartment_id = var.compartment_id
  statements     = ["Allow group Administrators to use functions-family in compartment id ${var.compartment_id}"]
}

resource "oci_identity_policy" "FoggyKitchenAnyUserUseFnPolicy" {
  name           = "FoggyKitchenAnyUserUseFnPolicy"
  description    = "FoggyKitchenAnyUserUseFnPolicy"
  compartment_id = var.compartment_id
  statements     = ["ALLOW any-user to use functions-family in compartment id ${var.compartment_id} where ALL { request.principal.type= 'ApiGateway' , request.resource.compartment.id = '${var.compartment_id}'}"]
}

resource "random_string" "id" {
  length  = 4
  special = false
}

###################################################################################################

resource "oci_logging_log_group" "log_group" {
  compartment_id = var.compartment_id
  display_name   = "log_group-${var.application_name}"
}

resource "oci_logging_log" "fn" {
  display_name = "fn-${local.rawfndata.name}"
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

resource "oci_logging_log" "apigwaccess" {
  display_name = "apigwaccess-${local.rawfndata.name}"
  log_group_id = oci_logging_log_group.log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "access"
      resource    = oci_apigateway_deployment.FunctionAPIGatewayDeployment.id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_id
  }
}

resource "oci_logging_log" "api_gateway_execution" {
  display_name       = "apigwexe-${local.rawfndata.name}"
  is_enabled         = "true"
  log_group_id       = oci_logging_log_group.log_group.id
  log_type           = "SERVICE"
  retention_duration = "30"

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "execution"
      resource    = oci_apigateway_deployment.FunctionAPIGatewayDeployment.id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }
  }
}

###################################################################################################

resource "oci_apigateway_gateway" "FunctionAPIGateway" {
  compartment_id = var.compartment_id
  endpoint_type  = "PUBLIC"
  subnet_id      = oci_core_subnet.public_subnet.id
  display_name   = "FunctionAPIGateway"
}

resource "oci_apigateway_deployment" "FunctionAPIGatewayDeployment" {
  compartment_id = var.compartment_id
  gateway_id     = oci_apigateway_gateway.FunctionAPIGateway.id
  path_prefix    = "/v1"
  display_name   = "FunctionAPIGatewayDeployment"

  specification {
    routes {
      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.function.id
      }
      methods = ["GET", "POST", "DELETE", "PUT"]
      path    = "/customers"
    }
  }
}

data "oci_apigateway_deployment" "FunctionAPIGatewayDeployment" {
  deployment_id = oci_apigateway_deployment.FunctionAPIGatewayDeployment.id
}

output "FunctionAPIGatewayDeployment_EndPoint" {
  value = [data.oci_apigateway_deployment.FunctionAPIGatewayDeployment.endpoint]
}
