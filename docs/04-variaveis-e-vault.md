# 04. Variáveis e Vault (secrets)

Este setup usa **OCI Vault** para armazenar secrets. A VM lê os secrets em tempo de boot via **instance principal** (não precisa de chave API na VM). Padrão production-grade.

## 4.1 Variáveis de entrada (terraform.tfvars)

| Variável | Obrigatória | Exemplo | Observação |
|---|---|---|---|
| `tenancy_ocid` | sim | `ocid1.tenancy.oc1..aaaa...` | Do bloco `[DEFAULT]` |
| `user_ocid` | sim | `ocid1.user.oc1..aaaa...` | Do bloco `[DEFAULT]` |
| `fingerprint` | sim | `aa:bb:cc:...` | Da API Key criada |
| `private_key_path` | sim | `~/.oci/oci_api_key.pem` | Caminho local |
| `region` | sim | `sa-saopaulo-1` | `us-ashburn-1` se A1 esgotado |
| `compartment_ocid` | sim | igual a `tenancy_ocid` | Root funciona pra começar |
| `ssh_public_key` | sim | `ssh-ed25519 AAAA...` | Conteúdo completo do `.pub` |
| `domain` | sim | `n8n.seusite.com.br` | Subdomínio que vai hospedar n8n |
| `acme_email` | sim | `voce@exemplo.com` | Usado pelo Caddy pro Let's Encrypt |
| `project_name` | não | `n8n` | Prefixo de recursos |
| `allowed_ssh_cidr` | não | `seu-ip/32` | Restrinja em produção |
| `instance_shape` | não | `VM.Standard.A1.Flex` | Default cobre Always Free |
| `instance_ocpus` | não | `1` | A1 Always Free aceita até 4 no total |
| `instance_memory_gb` | não | `6` | A1 Always Free aceita até 24 no total |
| `boot_volume_size_gb` | não | `50` | Mínimo 50 |
| `n8n_basic_auth_user` | não | `admin` | UI do n8n pede basic auth extra |

## 4.2 Secrets gerados automaticamente

O Terraform gera 3 passwords aleatórios via `random_password` e armazena no Vault:

| Secret | Tamanho | Uso |
|---|---|---|
| `n8n-encryption-key` | 48 chars | Criptografa credenciais dentro do n8n. **NUNCA troque** depois de criado, quebra workflows existentes |
| `n8n-postgres-password` | 32 chars | Senha do postgres interno |
| `n8n-basic-auth-password` | 24 chars | Senha do Basic Auth da UI |

Esses valores **não aparecem em logs nem em outputs do Terraform** (marcados `sensitive`).

## 4.3 Como a VM lê os secrets

1. Terraform cria um **dynamic group** que engloba toda instância do compartment
2. Terraform cria uma **policy** que permite ao dynamic group ler secrets no compartment
3. Cloud-init instala `oci-cli`
4. No boot, o systemd unit `n8n.service` roda `fetch-secrets.sh`
5. O script usa `--auth instance_principal` pra buscar os secrets sem precisar de API key
6. Grava em `/opt/n8n/secrets/` com `chmod 600`
7. Docker compose monta como `docker secrets` (nunca vão para env vars expostas)

Zero secrets commitados. Zero secrets em variáveis de ambiente visíveis via `docker inspect`.

## 4.4 Ler o valor de um secret (quando precisar)

Do seu laptop:

```bash
# Listar secrets do vault
oci vault secret list --compartment-id $COMPARTMENT_OCID

# Ler o valor (base64)
oci secrets secret-bundle get --secret-id $SECRET_OCID \
  --query 'data."secret-bundle-content".content' --raw-output | base64 -d
```

O OCID de cada secret aparece em `terraform output secrets_ocids` (marcado sensitive, precisa `-json`):

```bash
terraform output -json secrets_ocids | jq
```

Para pegar a senha do Basic Auth rapidamente:

```bash
SECRET_OCID=$(terraform output -json secrets_ocids | jq -r .n8n_basic_auth_password)
oci secrets secret-bundle get --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output | base64 -d
```

## 4.5 Rotacionar um secret

Via Terraform: `terraform taint random_password.postgres_password && terraform apply`. Vai gerar novo password, atualizar o Vault. Você precisa reiniciar o postgres e atualizar credenciais do n8n.

Para `n8n-encryption-key`: **não rotacione**. Quebra credenciais salvas. Se realmente precisar, exporte workflows primeiro, rotacione, reimporte.

## Próximo

[05. Deploy](./05-deploy.md)
