#!/usr/bin/env bash
# Restore do postgres a partir do dump mais recente.
# Uso: ./restore.sh /opt/n8n/backups/postgres-20260416T120000Z.sql.gz

set -euo pipefail

DUMP="${1:?uso: $0 <arquivo.sql.gz>}"

cd /opt/n8n

echo "[restore] parando n8n..."
docker compose stop n8n

echo "[restore] drop + recreate do banco..."
docker compose exec -T postgres psql -U n8n -d postgres -c "DROP DATABASE IF EXISTS n8n;"
docker compose exec -T postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n OWNER n8n;"

echo "[restore] restaurando de $DUMP..."
gunzip -c "$DUMP" | docker compose exec -T postgres psql -U n8n -d n8n

echo "[restore] subindo n8n..."
docker compose start n8n

echo "[restore] feito."
