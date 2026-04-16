# 04. Variáveis e Vault (secrets)

Este setup usa **OCI Vault** para armazenar secrets. A VM lê os secrets em tempo de boot via **instance principal** (não precisa de chave API na VM). Padrão production-grade.

## 4.1 Variáveis de entrada (terraform.tfvars)

### Obrigatórias

| Variável | Exemplo | Observação |
|---|---|---|
| `tenancy_ocid` | `ocid1.tenancy.oc1..aaaa...` | Do bloco `[DEFAULT]` |
| `user_ocid` | `ocid1.user.oc1..aaaa...` | Do bloco `[DEFAULT]` |
| `fingerprint` | `aa:bb:cc:...` | Da API Key criada |
| `private_key_path` | `~/.oci/oci_api_key.pem` | Caminho local |
| `region` | `sa-saopaulo-1` | `us-ashburn-1` se A1 esgotado |
| `compartment_ocid` | `ocid1.compartment.oc1..` | **Dedicado, não root**. Validação bloqueia root |
| `ssh_public_key` | `ssh-ed25519 AAAA...` | Conteúdo completo do `.pub`. Validado |
| `allowed_ssh_cidr` | `177.x.x.x/32` | **Obrigatório /32**. Validação bloqueia `0.0.0.0/0` |
| `domain` | `n8n.seusite.com.br` | FQDN validado |
| `acme_email` | `voce@exemplo.com` | Email validado |

### Opcionais

| Variável | Default | Observação |
|---|---|---|
| `project_name` | `n8n` | Prefixo de recursos |
| `instance_shape` | `VM.Standard.A1.Flex` | Cobre Always Free |
| `instance_ocpus` | `1` | A1 aceita até 4 no total |
| `instance_memory_gb` | `6` | A1 aceita até 24 no total |
| `boot_volume_size_gb` | `50` | Mínimo 50 |
| `n8n_basic_auth_user` | `admin` | UI do n8n pede basic auth |
| `n8n_image` | `n8nio/n8n:1.77.0` | **Pinado**. Atualize deliberadamente |
| `postgres_image` | `postgres:16.4-alpine` | **Pinado** |
| `caddy_image` | `caddy:2.8.4-alpine` | **Pinado** |
| `enable_offsite_backup` | `true` | Cria bucket + policy para backups no Object Storage |

## 4.2 Secrets gerados automaticamente

O Terraform gera 3 passwords aleatórios via `random_password` e armazena no Vault:

| Secret | Tamanho | Uso |
|---|---|---|
| `n8n-encryption-key` | 48 chars | Criptografa credenciais dentro do n8n. **NUNCA troque** depois de criado, quebra workflows existentes |
| `n8n-postgres-password` | 32 chars | Senha do postgres interno |
| `n8n-basic-auth-password` | 24 chars | Senha do Basic Auth da UI |

Esses valores **não aparecem em logs nem em outputs do Terraform** (secrets só via comando explícito).

## 4.3 Como a VM lê os secrets

1. Terraform cria um **dynamic group** que engloba toda instância do compartment (por isso exigimos compartment dedicado)
2. Terraform cria uma **policy** que permite ao dynamic group ler secrets no compartment
3. Cloud-init instala `oci-cli` pinado (via pip `oci-cli==3.43.0`)
4. No boot, o systemd unit `n8n.service` roda `fetch-secrets.sh` com **retry loop** (até 20 tentativas × 30s = 10 min) para absorver propagação da policy
5. O script usa `--auth instance_principal` pra buscar os secrets sem precisar de API key
6. Grava em `/opt/n8n/secrets/` com `chmod 600` (diretório `/opt/n8n` com `chmod 700`)
7. Docker compose monta como `docker secrets` (nunca vão para env vars expostas)

Zero secrets commitados. Zero secrets em variáveis de ambiente visíveis via `docker inspect`.

## 4.4 Ler o valor de um secret (quando precisar)

Jeito fácil (output do Terraform já com o comando pronto):

```bash
cd terraform
terraform output -raw get_basic_auth_password_command | bash
```

Manual:

```bash
# Listar secrets do vault
oci vault secret list --compartment-id $COMPARTMENT_OCID

# Ler o valor (base64 decodificado)
oci secrets secret-bundle get --secret-id $SECRET_OCID \
  --query 'data."secret-bundle-content".content' --raw-output | base64 -d
```

Os OCIDs ficam em outputs não-sensíveis:

```bash
terraform output encryption_key_secret_ocid
terraform output postgres_secret_ocid
terraform output basic_auth_secret_ocid
```

## 4.5 Rotacionar um secret

Via Terraform: `terraform taint random_password.postgres_password && terraform apply`. Vai gerar novo password, atualizar o Vault. Você precisa reiniciar o postgres e atualizar credenciais do n8n.

Para `n8n-encryption-key`: **não rotacione**. Quebra credenciais salvas. Se realmente precisar, exporte workflows primeiro, rotacione, reimporte.

## Próximo

[05. Deploy](./05-deploy.md)
