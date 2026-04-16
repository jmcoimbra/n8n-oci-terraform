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
  description = "OCID de um compartment DEDICADO (não use root/tenancy). A dynamic group terá acesso a TODOS os recursos deste compartment, por isso ele precisa ser isolado. Crie no console: Identity > Compartments > Create."
  type        = string

  validation {
    condition     = startswith(var.compartment_ocid, "ocid1.compartment.")
    error_message = "compartment_ocid deve ser um OCID de compartment válido. Crie um compartment dedicado no console OCI (Identity > Compartments)."
  }
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
  description = "CIDR permitido para SSH (22). OBRIGATÓRIO restringir ao seu IP: 'curl ifconfig.me'/32. Nunca use 0.0.0.0/0."
  type        = string

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr não pode ser 0.0.0.0/0. Restrinja ao seu IP residencial com /32."
  }
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

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-) ", var.ssh_public_key))
    error_message = "ssh_public_key deve começar com ssh-ed25519, ssh-rsa ou ecdsa-sha2-."
  }
}

# ===== Domínio / n8n =====

variable "domain" {
  description = "Domínio onde n8n será exposto. Ex: n8n.meusite.com.br. Você vai criar um A record apontando para a IP pública depois do apply."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.domain))
    error_message = "domain deve ser um FQDN válido (ex: n8n.seusite.com.br)."
  }
}

variable "acme_email" {
  description = "Email usado pelo Caddy para emitir certificado Let's Encrypt."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.acme_email))
    error_message = "acme_email deve ser um email válido."
  }
}

variable "n8n_basic_auth_user" {
  description = "Usuário básico opcional pra proteger a UI do n8n antes do primeiro login. Deixe vazio pra desabilitar."
  type        = string
  default     = "admin"
}

# ===== Imagens Docker (pinned) =====

variable "n8n_image" {
  description = "Imagem Docker do n8n pinada. Veja https://hub.docker.com/r/n8nio/n8n/tags e atualize deliberadamente."
  type        = string
  default     = "n8nio/n8n:1.77.0"
}

variable "postgres_image" {
  description = "Imagem Docker do Postgres pinada."
  type        = string
  default     = "postgres:16.4-alpine"
}

variable "caddy_image" {
  description = "Imagem Docker do Caddy pinada."
  type        = string
  default     = "caddy:2.8.4-alpine"
}

# ===== Backup =====

variable "enable_offsite_backup" {
  description = "Se true, cria bucket Object Storage e policy para backups offsite. Default true (Always Free: 20 GB grátis)."
  type        = bool
  default     = true
}
