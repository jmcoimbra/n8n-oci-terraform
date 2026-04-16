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

## Erro: `Service limit exceeded`

**Causa:** Já tem recursos usando todo o Always Free no tenancy.

**Solução:** Liste e remova recursos não usados:

```bash
oci compute instance list --compartment-id $COMPARTMENT_OCID
oci network vcn list --compartment-id $COMPARTMENT_OCID
```

## Erro: `400-Authorization failed` no cloud-init

**Causa:** Dynamic group policy ainda não propagou quando a VM boota.

**Solução:** Aguarde 2-3 minutos após o apply e reinicie o serviço:

```bash
ssh ubuntu@<ip>
sudo systemctl restart n8n.service
sudo journalctl -u n8n.service -f
```

Se persistir, valide a policy no console: Identity > Policies. Confirme que `Allow dynamic-group ...` está lá.

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

**Solução:** Aguarde 1h ou use staging. Edite `docker/Caddyfile`:
```
{
  email voce@exemplo.com
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}
```

## n8n retorna 502 Bad Gateway

**Causa:** n8n ainda não subiu ou postgres não está healthy.

```bash
docker compose ps
docker compose logs n8n --tail=50
docker compose logs postgres --tail=50
```

Espere o postgres health check passar (10-20s no primeiro boot).

## Workflows "perderam" credenciais após restore

**Causa:** Encryption key mudou.

**Solução:** Nunca rotacione `n8n-encryption-key`. Se realmente mudou, reimporte credenciais manualmente ou restaure o state completo.

## Conta OCI suspensa

**Causa típica:** Cadastro usando VPN, IP compartilhado, ou Oracle detectou atividade "suspeita".

**Solução:** Abra ticket em My Oracle Support. Resposta leva 24-72h. Na pior hipótese, crie nova conta com email diferente e IP residencial limpo.

## VM reclamada por idle

**Causa:** Oracle reciclou A1 Always Free por baixa CPU.

**Solução:** 
1. Valide keepalive: `cat /etc/cron.d/n8n-keepalive`
2. Se foi reciclada: `terraform destroy && terraform apply`. Você perde o postgres (tenha backup).

## Como destruir tudo

```bash
cd terraform
terraform destroy
```

Confirmação: digite `yes`. Remove todos os recursos. Restaura tenancy ao estado original.
