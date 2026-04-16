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

## 2.2 Criar compartment dedicado (OBRIGATÓRIO)

Por que: a dynamic group usada por este setup dá acesso aos secrets do Vault para **qualquer instância do compartment**. Se você usar o root, qualquer VM futura terá acesso aos secrets do n8n. Isolamento = segurança.

No console OCI:

1. Menu lateral > **Identity & Security** > **Compartments**
2. **Create Compartment**
3. Name: `n8n`
4. Parent Compartment: `<sua-tenancy>` (root)
5. Description: "n8n self-hosted resources"
6. Create

Copie o OCID do compartment (começa com `ocid1.compartment.oc1..`). Vai entrar em `compartment_ocid` no tfvars.

## 2.3 Criar API key

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

## 2.4 Coletar OCIDs necessários

Anote os seguintes OCIDs (você vai colar no `terraform.tfvars`):

| OCID | Onde achar |
|---|---|
| `tenancy_ocid` | User settings > Tenancy Details, OU bloco `[DEFAULT]` acima |
| `user_ocid` | User settings, OU bloco `[DEFAULT]` |
| `fingerprint` | API Keys (fingerprint da chave criada) |
| `compartment_ocid` | Identity > Compartments > `n8n` (o dedicado que você criou no passo 2.2) |

## 2.5 Criar budget alarm (safety net: R$ 0 garantido)

Trava de segurança contra cobrança inesperada. Se qualquer coisa sair do Always Free, você recebe email antes de virar fatura.

No console OCI:

1. Menu lateral > **Billing & Cost Management** > **Budgets**
2. **Create Budget**
3. Name: `always-free-guard`
4. Target Compartment: selecione o compartment `n8n` (não a tenancy)
5. Monthly Budget Amount: `1` (USD)
6. Alert Rule:
   - Threshold: `50` (%)
   - Type: **Actual Spend**
   - Recipients: seu email
7. Create

Se algum recurso fora do Always Free for provisionado, você é avisado antes de passar de **US$ 0,50**. Na prática, como este setup fica 100% dentro do Always Free, o alarme nunca dispara.

Para segurança extra, crie um segundo alarme em 90% (`Threshold: 90`) como backup.

## 2.6 Validar autenticação (opcional mas recomendado)

```bash
oci setup config   # segue o wizard, aponta pra ~/.oci/oci_api_key.pem
oci iam region list --config-file ~/.oci/config
```

Se listou regiões, auth está funcionando.

## Próximo

[03. Configurar Terraform](./03-configurar-terraform.md)
