resource "random_password" "n8n_encryption_key" {
  length  = 48
  special = false
}

resource "random_password" "postgres_password" {
  length  = 32
  special = false
}

resource "random_password" "n8n_basic_auth_password" {
  length  = 24
  special = false
}

resource "oci_kms_vault" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-vault"
  vault_type     = "DEFAULT" # software-backed, gratuito
}

resource "oci_kms_key" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-key"
  management_endpoint = oci_kms_vault.main.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_vault_secret" "n8n_encryption_key" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.main.id
  key_id         = oci_kms_key.main.id
  secret_name    = "${var.project_name}-encryption-key"
  description    = "N8N_ENCRYPTION_KEY. NUNCA mude depois de criado, quebra workflows."

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.n8n_encryption_key.result)
  }
}

resource "oci_vault_secret" "postgres_password" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.main.id
  key_id         = oci_kms_key.main.id
  secret_name    = "${var.project_name}-postgres-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.postgres_password.result)
  }
}

resource "oci_vault_secret" "n8n_basic_auth_password" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.main.id
  key_id         = oci_kms_key.main.id
  secret_name    = "${var.project_name}-basic-auth-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.n8n_basic_auth_password.result)
  }
}

# Dynamic group: engloba a instância para usar instance principal
resource "oci_identity_dynamic_group" "n8n_instance" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-instance-dg"
  description    = "Dynamic group para instância ${var.project_name} ler secrets do Vault via instance principal."
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

# Policy: permite ao dynamic group ler secrets no compartment
resource "oci_identity_policy" "n8n_read_secrets" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-read-secrets"
  description    = "Permite à instância ${var.project_name} ler secrets do Vault."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.n8n_instance.name} to read secret-family in compartment id ${var.compartment_ocid}"
  ]
}
