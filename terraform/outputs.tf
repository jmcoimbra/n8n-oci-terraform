output "public_ip" {
  description = "IP público reservado. Crie um A record no DNS: <domain> -> <public_ip>."
  value       = oci_core_public_ip.n8n.ip_address
}

output "ssh_command" {
  description = "Comando SSH pronto para copiar e colar."
  value       = "ssh ubuntu@${oci_core_public_ip.n8n.ip_address}"
}

output "domain" {
  description = "Domínio configurado. Caddy vai emitir certificado automático via Let's Encrypt."
  value       = var.domain
}

output "vault_ocid" {
  description = "OCID do Vault. Use no console OCI para gerenciar secrets."
  value       = oci_kms_vault.main.id
}

output "encryption_key_secret_ocid" {
  description = "OCID do secret com N8N_ENCRYPTION_KEY."
  value       = oci_vault_secret.n8n_encryption_key.id
}

output "postgres_secret_ocid" {
  description = "OCID do secret com a senha do postgres."
  value       = oci_vault_secret.postgres_password.id
}

output "basic_auth_secret_ocid" {
  description = "OCID do secret com a senha do Basic Auth."
  value       = oci_vault_secret.n8n_basic_auth_password.id
}

output "n8n_basic_auth_user" {
  description = "Usuário Basic Auth configurado. Senha: ler via 'oci secrets secret-bundle get --secret-id <basic_auth_secret_ocid>'."
  value       = var.n8n_basic_auth_user
}

output "backup_bucket" {
  description = "Nome do bucket Object Storage para backups (se enable_offsite_backup=true)."
  value       = var.enable_offsite_backup ? oci_objectstorage_bucket.backups[0].name : null
}

output "first_access_url" {
  description = "URL de primeiro acesso. Aguarde 3-5 minutos após o apply para DNS + TLS propagarem."
  value       = "https://${var.domain}"
}

output "get_basic_auth_password_command" {
  description = "Rode este comando para ver a senha do Basic Auth."
  value       = "oci secrets secret-bundle get --secret-id ${oci_vault_secret.n8n_basic_auth_password.id} --query 'data.\"secret-bundle-content\".content' --raw-output | base64 -d; echo"
}
