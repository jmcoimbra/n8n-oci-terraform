# ===== OCI auth (usuário API key) =====

variable "tenancy_ocid" {
  description = "OCID da tenancy. Console OCI > canto inferior esquerdo > Tenancy."
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário. Profile > User Settings."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API key (gerada em User Settings > API Keys)."
  type        = string
}

variable "private_key_path" {
  description = "Caminho local para a private key PEM da API."
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "Região OCI. sa-saopaulo-1 (SP) ou sa-vinhedo-1 (Vinhedo). us-ashburn-1 como fallback se A1 estiver esgotado."
  type        = string
  default     = "sa-saopaulo-1"
}

# ===== Projeto =====

variable "project_name" {
  description = "Prefixo para os recursos. Apenas letras, números e hífen."
  type        = string
  default     = "n8n"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name deve conter apenas minúsculas, números e hífen."
  }
}

variable "compartment_ocid" {
  description = "OCID do compartment onde os recursos serão criados. Use root compartment (tenancy_ocid) se não quiser criar um dedicado."
  type        = string
}

# ===== Rede =====

variable "vcn_cidr" {
  description = "CIDR da VCN."
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR da subnet pública."
  type        = string
  default     = "10.20.1.0/24"
}

variable "allowed_ssh_cidr" {
  description = "CIDR permitido para SSH (22). Restrinja ao seu IP: 'curl ifconfig.me'/32. Default 0.0.0.0/0 apenas para facilitar bootstrap."
  type        = string
  default     = "0.0.0.0/0"
}

# ===== Compute =====

variable "instance_shape" {
  description = "Shape da VM. A1.Flex (ARM) está no Always Free. E2.1.Micro (x86) é alternativa se A1 estiver esgotado."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Número de OCPUs. A1.Flex Always Free: até 4 OCPU total no tenancy."
  type        = number
  default     = 1
}

variable "instance_memory_gb" {
  description = "Memória em GB. A1.Flex Always Free: até 24 GB total no tenancy."
  type        = number
  default     = 6
}

variable "boot_volume_size_gb" {
  description = "Tamanho do boot volume em GB. Mínimo 50. Always Free: 200 GB total."
  type        = number
  default     = 50
}

variable "ssh_public_key" {
  description = "Chave pública SSH completa (conteúdo do ~/.ssh/id_ed25519.pub)."
  type        = string
}

# ===== Domínio / n8n =====

variable "domain" {
  description = "Domínio onde n8n será exposto. Ex: n8n.meusite.com.br. Você vai criar um A record apontando para a IP pública depois do apply."
  type        = string
}

variable "acme_email" {
  description = "Email usado pelo Caddy para emitir certificado Let's Encrypt."
  type        = string
}

variable "n8n_basic_auth_user" {
  description = "Usuário básico opcional pra proteger a UI do n8n antes do primeiro login. Deixe vazio pra desabilitar."
  type        = string
  default     = "admin"
}
