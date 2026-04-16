#!/usr/bin/env bash
# Backup dos volumes do n8n (postgres + n8n_data) para tarball local.
# Rode na VM: ssh ubuntu@<ip> 'bash -s' < backup.sh
# Ou copie pra /opt/n8n/backup.sh e agende no cron.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/n8n/backups}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"

cd /opt/n8n

echo "[backup] pausando containers..."
docker compose pause n8n postgres

echo "[backup] exportando postgres..."
docker compose exec -T postgres pg_dump -U n8n n8n | gzip > "$BACKUP_DIR/postgres-$TS.sql.gz"

echo "[backup] tarball de n8n_data..."
docker run --rm -v n8n_n8n_data:/src:ro -v "$BACKUP_DIR":/dst alpine \
  tar czf "/dst/n8n-data-$TS.tar.gz" -C /src .

echo "[backup] retomando..."
docker compose unpause n8n postgres

echo "[backup] feito: $BACKUP_DIR/*-$TS*"
ls -lh "$BACKUP_DIR" | tail -5

# Opcional: upload para Object Storage
# oci os object put --bucket-name n8n-backups --file "$BACKUP_DIR/postgres-$TS.sql.gz" --auth instance_principal
