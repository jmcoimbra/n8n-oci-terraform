resource "random_password" "n8n_encryption_key" {
  length  = 48
  special = true
  # Caracteres seguros pra arquivo montado como docker secret
  override_special = "!@#%^&*()-_=+[]{}<>:?"
}

resource "random_password" "postgres_password" {
  length           = 32
  special          = true
  override_special = "!@#%^&*()-_=+"
}

resource "random_password" "n8n_basic_auth_password" {
  length           = 24
  special          = true
  override_special = "!@#%^&*()-_=+"
}

resource "oci_kms_vault" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-vault"
  vault_type     = "DEFAULT" # software-backed, gratuito

  timeouts {
    create = "30m"
    delete = "30m"
  }
}

resource "oci_kms_key" "main" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-key"
  management_endpoint = oci_kms_vault.main.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  timeouts {
    create = "30m"
    delete = "30m"
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

# Dynamic group: escopo ao compartment. Exige compartment DEDICADO (validado em variables.tf).
resource "oci_identity_dynamic_group" "n8n_instance" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-instance-dg"
  description    = "Dynamic group para instância ${var.project_name} ler secrets e escrever backups."
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

# ===== Backup bucket (opcional, default true) =====

resource "oci_objectstorage_bucket" "backups" {
  count          = var.enable_offsite_backup ? 1 : 0
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns[0].namespace
  name           = "${var.project_name}-backups"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled"
  storage_tier   = "Standard"
}

data "oci_objectstorage_namespace" "ns" {
  count          = var.enable_offsite_backup ? 1 : 0
  compartment_id = var.tenancy_ocid
}

resource "oci_identity_policy" "n8n_write_backups" {
  count          = var.enable_offsite_backup ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-write-backups"
  description    = "Permite à instância ${var.project_name} gravar backups no Object Storage."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.n8n_instance.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name='${oci_objectstorage_bucket.backups[0].name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.n8n_instance.name} to read buckets in compartment id ${var.compartment_ocid}"
  ]
}
