# 03. Configurar Terraform

## 3.1 Clone o repo

```bash
git clone https://github.com/jmcoimbra/n8n-oci-terraform.git
cd n8n-oci-terraform/terraform
```

## 3.2 Criar `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` com os valores coletados no passo 02:

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaa..."
user_ocid        = "ocid1.user.oc1..aaaa..."
fingerprint      = "aa:bb:cc:dd:ee:ff:..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "sa-saopaulo-1"
compartment_ocid = "ocid1.tenancy.oc1..aaaa..."  # mesmo que tenancy se usar root

project_name = "n8n"

# SSH: cole o conteúdo de ~/.ssh/id_ed25519.pub
ssh_public_key = "ssh-ed25519 AAAAC3... voce@laptop"

# Domínio: subdomínio que você quer expor (vai criar A record no DNS depois)
domain     = "n8n.seusite.com.br"
acme_email = "voce@exemplo.com"
```

**Importante:** `terraform.tfvars` está no `.gitignore`. Nunca commite.

## 3.3 Restringir SSH (recomendado)

Abre o seu IP público:

```bash
curl ifconfig.me
```

No `terraform.tfvars`:

```hcl
allowed_ssh_cidr = "177.123.45.67/32"
```

Se o seu IP muda (casa com internet residencial), use `0.0.0.0/0` mesmo e conte com a segurança do SSH (chave obrigatória, sem senha). Em produção de verdade, use um bastion ou VPN.

## 3.4 Inicializar

```bash
terraform init
```

Baixa o provider OCI + random. Esperado: `Terraform has been successfully initialized!`

## 3.5 Validar sintaxe

```bash
terraform validate
terraform fmt -check
```

## 3.6 Ver o plano

```bash
terraform plan -out=tfplan
```

Revise. Deve mostrar cerca de 15-20 recursos a serem criados: VCN, IGW, route table, security list, subnet, compute instance, public IP, vault, key, 3 secrets, dynamic group, policy, random passwords.

## Próximo

[04. Variáveis e Vault](./04-variaveis-e-vault.md)
