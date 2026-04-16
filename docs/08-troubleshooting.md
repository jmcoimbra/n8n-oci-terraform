# 08. Troubleshooting

## Erro: `Out of host capacity` no apply

**Causa:** ARM A1 esgotado na região.

**Solução:**
- Trocar região no `terraform.tfvars`: `region = "us-ashburn-1"`
- Ou rodar retry loop:

```bash
while ! terraform apply -auto-approve; do
  echo "retry em 60s..."
  sleep 60
done
```

## Erro: `compartment_ocid deve ser um OCID de compartment válido`

**Causa:** Você colocou o tenancy OCID em vez de um compartment dedicado.

**Solução:** Crie um compartment `n8n` (ver doc 02.2). A validação bloqueia root por segurança: a dynamic group dá acesso a secrets pra qualquer VM do compartment.

## Erro: `allowed_ssh_cidr não pode ser 0.0.0.0/0`

**Causa:** Validação bloqueando configuração insegura.

**Solução:** Rode `curl ifconfig.me`, pegue seu IP público, coloque com `/32`:

```hcl
allowed_ssh_cidr = "177.123.45.67/32"
```

Se seu IP muda (internet residencial dinâmica), ou use Cloudflare Tunnel, ou atualize o tfvars quando precisar.

## Erro: `Service limit exceeded`

**Causa:** Já tem recursos usando todo o Always Free no tenancy.

**Solução:** Liste e remova recursos não usados:

```bash
oci compute instance list --compartment-id $COMPARTMENT_OCID
oci network vcn list --compartment-id $COMPARTMENT_OCID
```

## fetch-secrets.sh falha no boot

**Causa:** Policy do dynamic group ainda não propagou. O retry loop automático (20 × 30s = 10 min) absorve isso na maioria dos casos.

**Validação:**
```bash
ssh ubuntu@<ip>
sudo journalctl -u n8n.service -f
```

Você deve ver `[fetch-secrets] tentativa X/20...` e eventualmente `[fetch-secrets] ok.`. Se passar de 10 min sem sucesso:

```bash
# Valide policy no console OCI ou CLI
oci iam policy list --compartment-id $COMPARTMENT_OCID

# Rerun manual
sudo /opt/n8n/fetch-secrets.sh
sudo systemctl restart n8n.service
```

## Erro: Caddy não consegue emitir certificado

**Causa típica 1:** DNS ainda não propagou. Let's Encrypt falha o challenge HTTP-01.

**Validação:**
```bash
dig +short n8n.seusite.com.br
# Deve retornar o IP público da VM
```

**Causa típica 2:** Firewall bloqueando 80 ou 443.

**Validação:**
```bash
curl -I http://n8n.seusite.com.br
# Deve retornar algo, mesmo que 301 redirect
```

**Causa típica 3:** Rate limit do Let's Encrypt (5 certs/semana/domínio).

**Solução:** Aguarde 1h ou use staging. Edite `/opt/n8n/Caddyfile` na VM:
```
{
  email voce@exemplo.com
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}
```
Depois `docker compose restart caddy`.

## n8n retorna 502 Bad Gateway

**Causa:** n8n ainda não subiu ou postgres não está healthy.

```bash
docker compose ps
docker compose logs n8n --tail=50
docker compose logs postgres --tail=50
```

Espere o postgres health check passar (10-20s no primeiro boot). Depois o healthcheck do n8n (start_period 60s).

## Webhook URL com `//` (barra dupla)

**Causa:** Versão antiga do WEBHOOK_URL tinha trailing slash.

**Solução:** Já corrigido em `WEBHOOK_URL: https://${domain}` (sem slash final). Se você upgraded de versão antiga, edite `/opt/n8n/docker-compose.yml` e `docker compose up -d n8n`.

## Workflows "perderam" credenciais após restore

**Causa:** Encryption key mudou.

**Solução:** Nunca rotacione `n8n-encryption-key`. Se realmente mudou, reimporte credenciais manualmente.

## Conta OCI suspensa

**Causa típica:** Cadastro usando VPN, IP compartilhado, ou Oracle detectou atividade "suspeita".

**Solução:** Abra ticket em My Oracle Support. Resposta leva 24-72h. Na pior hipótese, crie nova conta com email diferente e IP residencial limpo.

## VM reclamada por idle

**Causa:** Oracle reciclou A1 Always Free por baixa CPU (< 20% por 7 dias).

**Prevenção:** Cloud-init instala `/opt/n8n/keepalive.sh` que gera CPU + tráfego outbound a cada 5 min.

**Validação:**
```bash
cat /etc/cron.d/n8n-keepalive
# */5 * * * * root /opt/n8n/keepalive.sh ...
```

**Recuperação (se reciclou):**
```bash
terraform destroy
# Restaurar do último backup offsite (se enable_offsite_backup=true):
# 1. terraform apply (nova VM)
# 2. oci os object list --bucket-name n8n-backups
# 3. oci os object get ... --file /tmp/restore.dump.gz
# 4. sudo /opt/n8n/restore.sh /tmp/restore.dump.gz
```

## Como destruir tudo

```bash
cd terraform
terraform destroy
```

Confirmação: digite `yes`. Remove todos os recursos. Restaura compartment ao estado original.

**Nota:** Bucket de backups é excluído junto. Se quiser preservar backups, baixe antes:

```bash
oci os object bulk-download --bucket-name n8n-backups --download-dir ./backup-archive
```
