#!/usr/bin/env bash
# Backup live do n8n (postgres + n8n_data). pg_dump é MVCC-safe, não precisa pausar.
# Rodar na VM. Cloud-init já instala uma cópia em /opt/n8n/backup.sh com cron diário às 3h UTC.
# Este arquivo existe como referência / override manual.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/n8n/backups}"
BUCKET="${BACKUP_BUCKET:-}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"

cd /opt/n8n

echo "[backup] pg_dump live (formato custom)..."
docker compose exec -T postgres pg_dump -U n8n -Fc n8n > "$BACKUP_DIR/postgres-$TS.dump"
gzip -f "$BACKUP_DIR/postgres-$TS.dump"

echo "[backup] tarball de n8n_data..."
docker run --rm -v n8n_n8n_data:/src:ro -v "$BACKUP_DIR":/dst alpine \
  tar czf "/dst/n8n-data-$TS.tar.gz" -C /src .

if [ -n "$BUCKET" ]; then
  echo "[backup] upload para Object Storage: $BUCKET"
  for f in "postgres-$TS.dump.gz" "n8n-data-$TS.tar.gz"; do
    oci os object put --bucket-name "$BUCKET" --file "$BACKUP_DIR/$f" \
      --auth instance_principal --force >/dev/null
  done
else
  echo "[backup] BACKUP_BUCKET vazio, skip upload offsite."
fi

echo "[backup] retention: remove backups locais > $RETENTION_DAYS dias..."
find "$BACKUP_DIR" -name "postgres-*.dump.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "n8n-data-*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "[backup] feito:"
ls -lh "$BACKUP_DIR" | tail -5
