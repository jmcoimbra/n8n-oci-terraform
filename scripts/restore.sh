#!/usr/bin/env bash
# Restore do postgres a partir de dump. Trata conexões ativas antes do DROP.
# Uso: ./restore.sh /opt/n8n/backups/postgres-20260416T120000Z.dump.gz

set -euo pipefail

DUMP="${1:?uso: $0 <arquivo.dump.gz>}"
[ -f "$DUMP" ] || { echo "arquivo não encontrado: $DUMP"; exit 1; }

cd /opt/n8n

echo "[restore] parando n8n..."
docker compose stop n8n

echo "[restore] terminando conexões ativas no banco n8n..."
docker compose exec -T postgres psql -U n8n -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='n8n' AND pid <> pg_backend_pid();" || true

echo "[restore] drop + recreate do banco..."
docker compose exec -T postgres psql -U n8n -d postgres -c "DROP DATABASE IF EXISTS n8n;"
docker compose exec -T postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n OWNER n8n;"

echo "[restore] restaurando de $DUMP..."
gunzip -c "$DUMP" | docker compose exec -T postgres pg_restore -U n8n -d n8n

echo "[restore] subindo n8n..."
docker compose start n8n

echo "[restore] feito."
