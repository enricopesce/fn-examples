provider "oci" {}

# locals {
#   fnroot    = abspath(path.root)
#   fnyaml    = "${abspath(path.root)}/func.yaml"
#   fncode    = "${abspath(path.root)}/func.py"
#   rawfndata = yamldecode(file(local.fnyaml))
#   fndata = {
#     name    = local.rawfndata.name
#     version = local.rawfndata.version
#     memory  = local.rawfndata.memory
#     image   = "${var.registry}/${local.rawfndata.name}:${local.rawfndata.version}"
#   }
# }

# resource "oci_core_vcn" "test_vcn" {
#   cidr_block     = "10.0.0.0/16"
#   compartment_id = var.compartment_id
#   display_name   = "test_vcn"
# }

# resource "oci_core_subnet" "test_public_subnet" {
#   cidr_block     = "10.0.100.0/24"
#   compartment_id = var.compartment_id
#   display_name   = "test_public_subnet"
#   vcn_id         = oci_core_vcn.test_vcn.id
#   route_table_id = oci_core_vcn.test_vcn.default_route_table_id
#   security_list_ids = [
#     oci_core_vcn.test_vcn.default_security_list_id,
#   ]
# }

# resource "oci_core_internet_gateway" "test_internet_gateway" {
#   compartment_id = var.compartment_id
#   display_name   = "test_internet_gateway"
#   vcn_id         = oci_core_vcn.test_vcn.id
# }

# resource "oci_core_default_route_table" "test_default_route_table" {
#   manage_default_resource_id = oci_core_vcn.test_vcn.default_route_table_id
#   route_rules {
#     network_entity_id = oci_core_internet_gateway.test_internet_gateway.id
#     destination       = "0.0.0.0/0"
#     destination_type  = "CIDR_BLOCK"
#   }
# }

# resource "oci_functions_application" "test_application" {
#   compartment_id = var.compartment_id
#   display_name   = var.application_name
#   subnet_ids     = [oci_core_subnet.test_public_subnet.id]
# }

# resource "null_resource" "deploy_function" {
#   triggers = {
#     fnfilechanged = "${sha1(file(local.fncode))}"
#   }

#   provisioner "local-exec" {
#     working_dir = local.fnroot
#     command     = <<-EOC
#       fn deploy --app ${var.application_name}
#     EOC
#   }
# }

# resource "oci_functions_function" "test_function" {
#   depends_on     = [null_resource.deploy_function]
#   application_id = oci_functions_application.test_application.id
#   display_name   = local.fndata.name
#   image          = local.fndata.image
#   memory_in_mbs  = local.fndata.memory
#   provisioned_concurrency_config {
#     strategy = "CONSTANT"
#     count    = 20
#   }
# }

# resource "oci_logging_log_group" "test_log_group" {
#   compartment_id = var.compartment_id
#   display_name   = "test_log_group"
# }

# resource "oci_logging_log" "test_fn_log" {
#   display_name = "test_fn_log"
#   log_group_id = oci_logging_log_group.test_log_group.id
#   log_type     = "SERVICE"

#   configuration {
#     source {
#       category    = "invoke"
#       resource    = oci_functions_application.test_application.id
#       service     = "functions"
#       source_type = "OCISERVICE"
#     }
#     compartment_id = var.compartment_id
#   }
#   is_enabled = true
# }

# resource "oci_logging_log" "test_event_log" {
#   display_name = "test_event_log"
#   log_group_id = oci_logging_log_group.test_log_group.id
#   log_type     = "SERVICE"

#   configuration {
#     source {
#       category    = "ruleexecutionlog"
#       resource    = oci_events_rule.test_rule.id
#       service     = "cloudevents"
#       source_type = "OCISERVICE"
#     }
#     compartment_id = var.compartment_id
#   }
#   is_enabled = true
# }

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "oci_kms_vault" "vault" {
  compartment_id = var.compartment_id
  display_name   = "vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "vault_master_key" {
  compartment_id = var.compartment_id
  display_name   = "key"
  key_shape {
    algorithm = "AES"
    length    = "32"
  }
  management_endpoint = oci_kms_vault.vault.management_endpoint
}

resource "oci_vault_secret" "db_password" {
  compartment_id = var.compartment_id
  key_id         = oci_kms_key.vault_master_key.id
  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.password.result)
  }
  secret_name = "DB_PSWD"
  vault_id    = oci_kms_vault.vault.id
}

data "oci_secrets_secretbundle" "bundle" {
  secret_id = oci_vault_secret.db_password.id
}

resource "oci_database_autonomous_database" "adb" {
  compartment_id              = var.compartment_id
  db_name                     = "DEMO"
  admin_password              = base64decode(data.oci_secrets_secretbundle.bundle.secret_bundle_content.0.content)
  cpu_core_count              = 1
  data_storage_size_in_tbs    = 1
  db_version                  = "21c"
  db_workload                 = "OLTP"
  display_name                = "ADB Free Tier 21c"
  is_free_tier                = true
  is_mtls_connection_required = true
  ocpu_count                  = 1
}

resource "oci_database_autonomous_database_wallet" "autonomous_database_wallet" {
  autonomous_database_id = oci_database_autonomous_database.adb.id
  password               = base64decode(data.oci_secrets_secretbundle.bundle.secret_bundle_content.0.content)
  base64_encode_content  = "true"
}

resource "local_file" "autonomous_database_wallet_file" {
  content_base64 = oci_database_autonomous_database_wallet.autonomous_database_wallet.content
  filename       = "${path.module}/autonomous_database_wallet.zip"
}

output "database_autonomous_database_wallet_autonomous_database_id" {
  value = oci_database_autonomous_database_wallet.autonomous_database_wallet.autonomous_database_id
}

output "database_autonomous_database_wallet_content" {
  value = oci_database_autonomous_database_wallet.autonomous_database_wallet.content
}

output "database_autonomous_database_wallet_id" {
  value = oci_database_autonomous_database_wallet.autonomous_database_wallet.id
}

# output "database_autonomous_database_wallet_password" {
#   value = oci_database_autonomous_database_wallet.autonomous_database_wallet.password
# }