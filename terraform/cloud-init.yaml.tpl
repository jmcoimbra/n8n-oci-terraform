#cloud-config
# Bootstrap n8n em Ubuntu 22.04 ARM com Docker + OCI CLI + Caddy (TLS automático).

package_update: true
package_upgrade: true

packages:
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - jq
  - unzip
  - fail2ban
  - ufw
  - unattended-upgrades
  - python3-pip

write_files:
  - path: /etc/docker/daemon.json
    permissions: "0644"
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }

  - path: /etc/fail2ban/jail.local
    permissions: "0644"
    content: |
      [DEFAULT]
      bantime  = 1h
      findtime = 10m
      maxretry = 5
      backend  = systemd

      [sshd]
      enabled = true
      port    = 22
      logpath = %(sshd_log)s

  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    permissions: "0644"
    content: |
      PasswordAuthentication no
      PermitRootLogin no
      ChallengeResponseAuthentication no
      KbdInteractiveAuthentication no
      X11Forwarding no
      LoginGraceTime 30
      MaxAuthTries 3

  - path: /opt/n8n/docker-compose.yml
    permissions: "0644"
    content: |
      services:
        caddy:
          image: ${caddy_image}
          restart: unless-stopped
          ports:
            - "80:80"
            - "443:443"
          volumes:
            - ./Caddyfile:/etc/caddy/Caddyfile:ro
            - caddy_data:/data
            - caddy_config:/config
          networks:
            - n8n-net
          depends_on:
            - n8n
          healthcheck:
            test: ["CMD", "wget", "--spider", "-q", "http://localhost:80"]
            interval: 30s
            timeout: 5s
            retries: 3

        postgres:
          image: ${postgres_image}
          restart: unless-stopped
          environment:
            POSTGRES_USER: n8n
            POSTGRES_DB: n8n
            POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
          volumes:
            - postgres_data:/var/lib/postgresql/data
          secrets:
            - postgres_password
          healthcheck:
            test: ["CMD-SHELL", "pg_isready -U n8n"]
            interval: 10s
            timeout: 5s
            retries: 5
          networks:
            - n8n-net

        n8n:
          image: ${n8n_image}
          restart: unless-stopped
          environment:
            N8N_HOST: "${domain}"
            N8N_PORT: 5678
            N8N_PROTOCOL: https
            WEBHOOK_URL: "https://${domain}"
            NODE_ENV: production
            GENERIC_TIMEZONE: America/Sao_Paulo
            TZ: America/Sao_Paulo
            DB_TYPE: postgresdb
            DB_POSTGRESDB_HOST: postgres
            DB_POSTGRESDB_PORT: 5432
            DB_POSTGRESDB_DATABASE: n8n
            DB_POSTGRESDB_USER: n8n
            DB_POSTGRESDB_PASSWORD_FILE: /run/secrets/postgres_password
            N8N_ENCRYPTION_KEY_FILE: /run/secrets/n8n_encryption_key
            N8N_BASIC_AUTH_ACTIVE: "true"
            N8N_BASIC_AUTH_USER: "${n8n_basic_auth_user}"
            N8N_BASIC_AUTH_PASSWORD_FILE: /run/secrets/n8n_basic_auth_password
            N8N_DIAGNOSTICS_ENABLED: "false"
            N8N_VERSION_NOTIFICATIONS_ENABLED: "false"
          volumes:
            - n8n_data:/home/node/.n8n
          secrets:
            - postgres_password
            - n8n_encryption_key
            - n8n_basic_auth_password
          depends_on:
            postgres:
              condition: service_healthy
          healthcheck:
            test: ["CMD-SHELL", "wget --spider -q http://localhost:5678/healthz || exit 1"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 60s
          networks:
            - n8n-net

      volumes:
        n8n_data:
        postgres_data:
        caddy_data:
        caddy_config:

      networks:
        n8n-net:
          driver: bridge

      secrets:
        postgres_password:
          file: /opt/n8n/secrets/postgres_password
        n8n_encryption_key:
          file: /opt/n8n/secrets/n8n_encryption_key
        n8n_basic_auth_password:
          file: /opt/n8n/secrets/n8n_basic_auth_password

  - path: /opt/n8n/Caddyfile
    permissions: "0644"
    content: |
      {
        email ${acme_email}
      }
      ${domain} {
        encode gzip
        request_body {
          max_size 100MB
        }
        reverse_proxy n8n:5678 {
          flush_interval -1
        }
      }

  - path: /opt/n8n/fetch-secrets.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      # Busca secrets do OCI Vault via instance principal.
      # Retry por até 10 min pra absorver propagação da policy.
      set -euo pipefail
      mkdir -p /opt/n8n/secrets
      chmod 700 /opt/n8n/secrets

      fetch_secret() {
        local ocid="$1"
        local dest="$2"
        local attempts=0
        local max_attempts=20
        until oci secrets secret-bundle get \
          --secret-id "$ocid" \
          --auth instance_principal \
          --query 'data."secret-bundle-content".content' \
          --raw-output 2>/dev/null | base64 -d > "$dest"; do
          attempts=$((attempts+1))
          if [ $attempts -ge $max_attempts ]; then
            echo "[fetch-secrets] falhou após $attempts tentativas: $ocid" >&2
            return 1
          fi
          echo "[fetch-secrets] tentativa $attempts/$max_attempts para $ocid..." >&2
          sleep 30
        done
        chmod 600 "$dest"
      }

      fetch_secret "${encryption_key_secret_ocid}" /opt/n8n/secrets/n8n_encryption_key
      fetch_secret "${postgres_secret_ocid}"       /opt/n8n/secrets/postgres_password
      fetch_secret "${basic_auth_secret_ocid}"     /opt/n8n/secrets/n8n_basic_auth_password

      echo "[fetch-secrets] ok."

  - path: /opt/n8n/backup.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      # Backup live (sem pausar containers). pg_dump é MVCC-safe.
      # Upload para Object Storage se BACKUP_BUCKET estiver setado.
      set -euo pipefail

      BACKUP_DIR="$${BACKUP_DIR:-/opt/n8n/backups}"
      BUCKET="$${BACKUP_BUCKET:-${backup_bucket}}"
      RETENTION_DAYS="$${RETENTION_DAYS:-14}"
      TS="$(date -u +%Y%m%dT%H%M%SZ)"
      mkdir -p "$BACKUP_DIR"

      cd /opt/n8n

      echo "[backup] pg_dump live..."
      docker compose exec -T postgres pg_dump -U n8n -Fc n8n > "$BACKUP_DIR/postgres-$TS.dump"
      gzip -f "$BACKUP_DIR/postgres-$TS.dump"

      echo "[backup] tarball de n8n_data (read-only)..."
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

      echo "[backup] limpando backups locais > $RETENTION_DAYS dias..."
      find "$BACKUP_DIR" -name "postgres-*.dump.gz" -mtime +$RETENTION_DAYS -delete
      find "$BACKUP_DIR" -name "n8n-data-*.tar.gz" -mtime +$RETENTION_DAYS -delete

      echo "[backup] feito."

  - path: /opt/n8n/restore.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      # Uso: ./restore.sh <postgres-dump.gz>
      set -euo pipefail

      DUMP="$${1:?uso: $0 <arquivo.dump.gz>}"
      [ -f "$DUMP" ] || { echo "arquivo não encontrado: $DUMP"; exit 1; }

      cd /opt/n8n

      echo "[restore] parando n8n..."
      docker compose stop n8n

      echo "[restore] terminando conexões remanescentes..."
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

  - path: /opt/n8n/keepalive.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      # Gera CPU real + tráfego outbound pra evitar reclamação de A1 Always Free.
      # Oracle recicla instâncias Always Free com CPU < 20% por 7 dias.
      set -eu
      curl -s -o /dev/null --max-time 10 https://ifconfig.me || true
      # Pequeno trabalho de CPU pra elevar média
      dd if=/dev/urandom bs=1M count=16 2>/dev/null | sha256sum > /dev/null || true

  - path: /etc/systemd/system/n8n.service
    permissions: "0644"
    content: |
      [Unit]
      Description=n8n via docker compose
      Requires=docker.service
      After=docker.service network-online.target

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      WorkingDirectory=/opt/n8n
      Environment=BACKUP_BUCKET=${backup_bucket}
      ExecStartPre=/opt/n8n/fetch-secrets.sh
      ExecStart=/usr/bin/docker compose up -d
      ExecStop=/usr/bin/docker compose down
      Restart=on-failure
      RestartSec=30s

      [Install]
      WantedBy=multi-user.target

  - path: /etc/cron.d/n8n-keepalive
    permissions: "0644"
    content: |
      */5 * * * * root /opt/n8n/keepalive.sh >/dev/null 2>&1

  - path: /etc/cron.d/n8n-backup
    permissions: "0644"
    content: |
      0 3 * * * root BACKUP_BUCKET=${backup_bucket} /opt/n8n/backup.sh >> /var/log/n8n-backup.log 2>&1

runcmd:
  # Lockdown de permissões do diretório
  - chmod 700 /opt/n8n
  - chown -R root:root /opt/n8n

  # Docker repo oficial
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - chmod a+r /etc/apt/keyrings/docker.gpg
  - echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # OCI CLI via pip (versão pinada + PyPI assinado)
  - pip3 install --no-cache-dir "oci-cli==3.43.0"

  # SSH hardening aplicado
  - systemctl reload ssh

  # Firewall host-level (além da security list)
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  # Fail2ban
  - systemctl enable fail2ban
  - systemctl restart fail2ban

  # Unattended security updates
  - dpkg-reconfigure -f noninteractive unattended-upgrades

  # Docker daemon com log rotation
  - systemctl restart docker

  # Fetch secrets + sobe n8n
  - systemctl daemon-reload
  - systemctl enable n8n.service
  - systemctl start n8n.service
