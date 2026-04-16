# 07. Backup e manutenção

## 7.1 O que precisa de backup

- **Postgres** (`postgres_data` volume): workflows, executions, credentials criptografadas
- **n8n_data** (`n8n_n8n_data` volume): config, arquivos binários de workflow
- **Vault secrets** (já replicados pela Oracle, não precisa backup manual)

## 7.2 Automação (já habilitada por default)

Cloud-init instala:

- `/opt/n8n/backup.sh`: dump postgres live (MVCC-safe, sem pausar) + tarball n8n_data
- `/opt/n8n/restore.sh`: restore com `pg_terminate_backend` antes do DROP
- Cron `/etc/cron.d/n8n-backup`: roda diariamente às 3h UTC (meia-noite em SP)
- Log em `/var/log/n8n-backup.log`

Se `enable_offsite_backup = true` (default), também:

- Bucket `n8n-backups` no Object Storage (Always Free: 20 GB)
- Policy permitindo à instância gravar via instance principal
- `backup.sh` faz upload automático após cada dump

Retention: 14 dias local (variável `RETENTION_DAYS`). Object Storage não é limpo automaticamente (lifecycle policy fica por sua conta).

## 7.3 Rodar backup manual

```bash
ssh ubuntu@<ip>
sudo /opt/n8n/backup.sh
```

Gera em `/opt/n8n/backups/`:
- `postgres-<timestamp>.dump.gz` (formato custom, usar `pg_restore`)
- `n8n-data-<timestamp>.tar.gz`

## 7.4 Restore

Do dump no Object Storage:

```bash
oci os object get --bucket-name n8n-backups --name postgres-20260416T030000Z.dump.gz \
  --file /tmp/restore.dump.gz --auth instance_principal

sudo /opt/n8n/restore.sh /tmp/restore.dump.gz
```

Do dump local:

```bash
sudo /opt/n8n/restore.sh /opt/n8n/backups/postgres-<timestamp>.dump.gz
```

## 7.5 Monitoramento básico

Sem custo, via logs:

```bash
# Uso de recursos
htop                                # CPU/RAM em tempo real
docker stats                        # uso por container
df -h                               # disco

# Logs
docker compose logs -f n8n          # aplicação (json-file driver com rotação 10m x 3)
journalctl -u n8n.service           # systemd
tail -f /var/log/cloud-init-output.log
tail -f /var/log/n8n-backup.log
```

Alerta por email via OCI (gratuito): Monitoring > Alarms. Métrica `CpuUtilization > 80%` por 5 min.

## 7.6 Keepalive (evita reclamação Always Free)

Cloud-init instala `/opt/n8n/keepalive.sh` que roda a cada 5 min:

- `curl https://ifconfig.me` (gera tráfego outbound real)
- `dd if=/dev/urandom | sha256sum` (gera CPU real)

Oracle recicla A1 Always Free quando CPU < 20% por 7 dias. Este keepalive mantém a VM ativa.

Se for inativo por muito tempo, considere também um workflow no próprio n8n tipo "fetch RSS a cada 15 min" para uso real.

## 7.7 Atualizações

### OS (automático)

Ubuntu 22.04 LTS com `unattended-upgrades` habilitado em cloud-init. Updates de segurança rodam sem intervenção.

Reboot mensal (opcional):

```bash
sudo apt upgrade -y
sudo reboot
# IP público reservado NÃO muda em reboot.
```

### Docker images

Versões pinadas em `variables.tf`. Para atualizar:

1. **SEMPRE faça backup primeiro** (7.3)
2. Edite `variables.tf` ou `terraform.tfvars`: `n8n_image = "n8nio/n8n:1.78.0"`
3. `terraform apply` (atualiza user_data via cloud-init)
4. SSH + `docker compose pull n8n && docker compose up -d n8n`

Verifique release notes do n8n antes de upgrades major (1.x → 2.x): https://github.com/n8n-io/n8n/releases

## Próximo

[08. Troubleshooting](./08-troubleshooting.md)
