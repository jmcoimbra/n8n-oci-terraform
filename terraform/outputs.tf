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

output "secrets_ocids" {
  description = "OCIDs dos secrets no Vault."
  value = {
    n8n_encryption_key     = oci_vault_secret.n8n_encryption_key.id
    postgres_password      = oci_vault_secret.postgres_password.id
    n8n_basic_auth_password = oci_vault_secret.n8n_basic_auth_password.id
  }
  sensitive = true
}

output "n8n_basic_auth_user" {
  description = "Usuário Basic Auth configurado. Senha: ver Vault ou rodar 'oci vault secret read'."
  value       = var.n8n_basic_auth_user
}

output "first_access_url" {
  description = "URL de primeiro acesso. Aguarde 3-5 minutos após o apply para DNS + TLS propagarem."
  value       = "https://${var.domain}"
}
