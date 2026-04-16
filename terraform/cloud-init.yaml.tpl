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

write_files:
  - path: /opt/n8n/docker-compose.yml
    permissions: "0644"
    content: |
      services:
        caddy:
          image: caddy:2-alpine
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

        postgres:
          image: postgres:16-alpine
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
          image: n8nio/n8n:latest
          restart: unless-stopped
          environment:
            N8N_HOST: ${domain}
            N8N_PORT: 5678
            N8N_PROTOCOL: https
            WEBHOOK_URL: https://${domain}/
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
            N8N_BASIC_AUTH_USER: ${n8n_basic_auth_user}
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
        reverse_proxy n8n:5678 {
          flush_interval -1
        }
      }

  - path: /opt/n8n/fetch-secrets.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      mkdir -p /opt/n8n/secrets
      chmod 700 /opt/n8n/secrets

      fetch_secret() {
        local ocid="$1"
        local dest="$2"
        oci secrets secret-bundle get \
          --secret-id "$ocid" \
          --auth instance_principal \
          --query 'data."secret-bundle-content".content' \
          --raw-output | base64 -d > "$dest"
        chmod 600 "$dest"
      }

      fetch_secret "${encryption_key_secret_ocid}" /opt/n8n/secrets/n8n_encryption_key
      fetch_secret "${postgres_secret_ocid}"       /opt/n8n/secrets/postgres_password
      fetch_secret "${basic_auth_secret_ocid}"     /opt/n8n/secrets/n8n_basic_auth_password

  - path: /etc/systemd/system/n8n.service
    permissions: "0644"
    content: |
      [Unit]
      Description=n8n via docker compose
      Requires=docker.service
      After=docker.service

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      WorkingDirectory=/opt/n8n
      ExecStartPre=/opt/n8n/fetch-secrets.sh
      ExecStart=/usr/bin/docker compose up -d
      ExecStop=/usr/bin/docker compose down

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Docker repo oficial
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - chmod a+r /etc/apt/keyrings/docker.gpg
  - echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # OCI CLI
  - curl -L -o /tmp/install-oci.sh https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
  - bash /tmp/install-oci.sh --accept-all-defaults --install-dir /opt/oci-cli --exec-dir /usr/local/bin

  # Firewall host-level (além da security list)
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  # Fetch secrets + sobe n8n
  - systemctl daemon-reload
  - systemctl enable n8n.service
  - systemctl start n8n.service

  # Health check tocando a VM (evita reclamação de idle Always Free)
  - echo "*/5 * * * * root curl -s -o /dev/null http://localhost:5678/healthz || true" > /etc/cron.d/n8n-keepalive
