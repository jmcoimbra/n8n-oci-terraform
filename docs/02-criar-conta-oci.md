# 02. Criar conta OCI e coletar credenciais

## 2.1 Criar conta

1. Acesse https://signup.cloud.oracle.com
2. Selecione **Home Region: Brazil East (São Paulo)**: `sa-saopaulo-1`
3. Verifique com cartão de crédito (não cobra)
4. Aguarde email de ativação (até 24h, normalmente em minutos)

**Se der erro "suspicious activity":**
- Desligue VPN
- Use IP residencial brasileiro
- Tente de novo no dia seguinte (24h de cooldown)

## 2.2 Criar API key

Você precisa gerar uma chave para o Terraform se autenticar na OCI.

No console OCI:

1. Clique no ícone do usuário (canto superior direito) > **User settings**
2. Menu lateral > **API Keys** > **Add API Key**
3. Selecione **Generate API Key Pair** > **Download Private Key**
4. Salve em `~/.oci/oci_api_key.pem`
5. Clique **Add**
6. Copie o bloco `[DEFAULT]` que aparece na tela. Você vai precisar dele:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...
fingerprint=aa:bb:cc:dd:ee:ff:...
tenancy=ocid1.tenancy.oc1..aaaa...
region=sa-saopaulo-1
key_file=~/.oci/oci_api_key.pem
```

Ajuste permissões da chave:

```bash
chmod 600 ~/.oci/oci_api_key.pem
```

## 2.3 Coletar OCIDs necessários

Anote os seguintes OCIDs (você vai colar no `terraform.tfvars`):

| OCID | Onde achar |
|---|---|
| `tenancy_ocid` | User settings > Tenancy Details, OU bloco `[DEFAULT]` acima |
| `user_ocid` | User settings, OU bloco `[DEFAULT]` |
| `fingerprint` | API Keys (fingerprint da chave criada) |
| `compartment_ocid` | Identity > Compartments. Use o root (= tenancy_ocid) para começar, ou crie um dedicado `n8n` |

## 2.4 Validar autenticação (opcional mas recomendado)

```bash
oci setup config   # segue o wizard, aponta pra ~/.oci/oci_api_key.pem
oci iam region list --config-file ~/.oci/config
```

Se listou regiões, auth está funcionando.

## Próximo

[03. Configurar Terraform](./03-configurar-terraform.md)
