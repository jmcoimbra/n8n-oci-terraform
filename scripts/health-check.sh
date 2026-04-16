#!/usr/bin/env bash
# Health check básico. Use no seu laptop pra validar o deploy.
# Uso: ./health-check.sh n8n.meusite.com.br

set -euo pipefail

DOMAIN="${1:?uso: $0 <domain>}"

echo "[1/4] DNS:"
dig +short "$DOMAIN" || { echo "DNS não resolve"; exit 1; }

echo "[2/4] ICMP:"
ping -c 2 "$DOMAIN" || echo "ICMP bloqueado (ok, não é fatal)"

echo "[3/4] TLS:"
echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null \
  | openssl x509 -noout -subject -dates

echo "[4/4] HTTP 200:"
curl -sI "https://$DOMAIN" | head -1

echo "OK."
