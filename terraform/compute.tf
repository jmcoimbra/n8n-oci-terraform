data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Ubuntu 22.04 ARM (Canonical). Pega a imagem mais recente da região.
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  backup_bucket_name = var.enable_offsite_backup ? oci_objectstorage_bucket.backups[0].name : ""

  cloud_init = templatefile("${path.module}/cloud-init.yaml.tpl", {
    domain                     = var.domain
    acme_email                 = var.acme_email
    n8n_basic_auth_user        = var.n8n_basic_auth_user
    region                     = var.region
    encryption_key_secret_ocid = oci_vault_secret.n8n_encryption_key.id
    postgres_secret_ocid       = oci_vault_secret.postgres_password.id
    basic_auth_secret_ocid     = oci_vault_secret.n8n_basic_auth_password.id
    n8n_image                  = var.n8n_image
    postgres_image             = var.postgres_image
    caddy_image                = var.caddy_image
    backup_bucket              = local.backup_bucket_name
    enable_offsite_backup      = var.enable_offsite_backup
  })
}

resource "oci_core_instance" "n8n" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "${var.project_name}-host"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = false
    hostname_label   = var.project_name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  freeform_tags = {
    "role"    = "n8n"
    "managed" = "terraform"
  }

  # Se A1 estiver out-of-stock, o apply falha. Documentado em docs/08-troubleshooting.md.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }

  # Garante que policy esteja propagada (amortiza, não elimina, a race)
  depends_on = [
    oci_identity_policy.n8n_read_secrets,
  ]
}

# IP público reservado. VNIC sobe sem ephemeral (assign_public_ip=false), reserved é anexado em seguida.
data "oci_core_vnic_attachments" "n8n" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.n8n.id
}

data "oci_core_vnic" "n8n" {
  vnic_id = data.oci_core_vnic_attachments.n8n.vnic_attachments[0].vnic_id
}

data "oci_core_private_ips" "n8n" {
  vnic_id = data.oci_core_vnic.n8n.id
}

resource "oci_core_public_ip" "n8n" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-public-ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.n8n.private_ips[0].id
}
