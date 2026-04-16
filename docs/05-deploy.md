# 05. Deploy

## 5.1 Apply

```bash
cd terraform
terraform apply tfplan
```

Leva 3-5 minutos. Ao final:

```
Outputs:

public_ip = "132.226.xxx.xxx"
ssh_command = "ssh ubuntu@132.226.xxx.xxx"
domain = "n8n.seusite.com.br"
first_access_url = "https://n8n.seusite.com.br"
```

**Se der erro `Out of host capacity`:** ARM A1 está esgotado em sa-saopaulo-1. Opções:
1. Trocar região: `region = "us-ashburn-1"` (latência ~150ms, aceitável)
2. Trocar shape: `instance_shape = "VM.Standard.E2.1.Micro"` + `instance_ocpus = 1` + `instance_memory_gb = 1` (x86 Always Free, bem mais limitado)
3. Retry com script: `while ! terraform apply tfplan; do sleep 60; done`

## 5.2 Criar A record no DNS

Com o IP público em mãos, crie o DNS no provedor do seu domínio:

| Tipo | Nome | Valor | TTL |
|---|---|---|---|
| A | `n8n` | `132.226.xxx.xxx` | 300 |

(ajuste `n8n` para o subdomínio que você escolheu)

Verifique a propagação:

```bash
dig +short n8n.seusite.com.br
```

Deve retornar o IP. Pode levar até 30 minutos (cache de DNS). Na maioria das vezes, 1-5 minutos.

## 5.3 Aguardar cloud-init

A VM leva 3-5 minutos pra instalar Docker + OCI CLI + sobrir containers. SSH e acompanhe:

```bash
ssh ubuntu@$(terraform output -raw public_ip)

# Logs do cloud-init
sudo tail -f /var/log/cloud-init-output.log
# Aguarde ver: "cloud-init final ... finished"

# Status do systemd
sudo systemctl status n8n.service

# Containers
docker ps
# Espera: caddy, n8n, postgres todos "Up" e healthy
```

## 5.4 Aguardar TLS (Let's Encrypt)

Na primeira request HTTPS, Caddy emite o certificado automaticamente. Pode levar 15-30 segundos.

Logs do Caddy:

```bash
docker logs -f n8n-caddy-1
# Espera: "certificate obtained successfully"
```

## 5.5 Validar

Do seu laptop:

```bash
./scripts/health-check.sh n8n.seusite.com.br
```

Saída esperada: DNS resolve, TLS válido, HTTP 200.

## 5.6 Acesso

Abra no navegador:

```
https://n8n.seusite.com.br
```

Vai pedir Basic Auth. Credenciais:

- Usuário: `admin` (ou o que você pôs em `n8n_basic_auth_user`)
- Senha: execute no laptop

```bash
SECRET_OCID=$(terraform output -json secrets_ocids | jq -r .n8n_basic_auth_password)
oci secrets secret-bundle get --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output | base64 -d
echo
```

## Próximo

[06. Primeiro acesso ao n8n](./06-primeiro-acesso.md)
