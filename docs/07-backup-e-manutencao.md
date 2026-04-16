# 07. Backup e manutenção

## 7.1 O que precisa de backup

- **Postgres** (`/var/lib/postgresql/data`): workflows, executions, credentials criptografadas
- **n8n_data** (`/home/node/.n8n`): config, arquivos binários de workflow
- **Vault secrets** (já replicados pela Oracle, não precisa backup manual)

## 7.2 Backup manual

Na VM:

```bash
sudo cp /path/to/scripts/backup.sh /opt/n8n/backup.sh
sudo chmod +x /opt/n8n/backup.sh
sudo /opt/n8n/backup.sh
```

Gera em `/opt/n8n/backups/`:
- `postgres-<timestamp>.sql.gz`
- `n8n-data-<timestamp>.tar.gz`

## 7.3 Backup automático (cron)

```bash
sudo crontab -e
# Adiciona:
0 3 * * * /opt/n8n/backup.sh >> /var/log/n8n-backup.log 2>&1
```

Roda todo dia às 3h UTC (meia-noite em SP).

## 7.4 Backup offsite (OCI Object Storage)

Always Free: 20 GB. Mais que suficiente pra backups de n8n.

1. Crie um bucket no console OCI: Object Storage > Buckets > **Create Bucket** > `n8n-backups`
2. Ajuste `backup.sh` descomentando a linha do `oci os object put`
3. Policy adicional (adicione no `vault.tf`):

```hcl
"Allow dynamic-group ${oci_identity_dynamic_group.n8n_instance.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name='n8n-backups'"
```

Re-aplicar: `terraform apply`.

## 7.5 Restore

Copia o dump de volta pra VM e roda:

```bash
sudo /opt/n8n/scripts/restore.sh /opt/n8n/backups/postgres-<timestamp>.sql.gz
```

## 7.6 Monitoramento básico

Sem custo, via logs:

```bash
# Uso de recursos
htop                                # CPU/RAM em tempo real
docker stats                        # uso por container
df -h                               # disco

# Logs
docker compose logs -f n8n          # aplicação
journalctl -u n8n.service           # systemd
tail -f /var/log/cloud-init-output.log
```

Alerta por email via OCI (gratuito): Monitoring > Alarms. Métrica `CpuUtilization > 80%` por 5 min.

## 7.7 Manter Always Free vivo

Oracle reclama A1 Always Free após 7 dias de CPU muito baixa. O cloud-init já cria um keepalive:

```bash
*/5 * * * * root curl -s -o /dev/null http://localhost:5678/healthz
```

Se você for inativo por muito tempo, considere também um workflow no próprio n8n tipo "fetch RSS a cada 15 min".

## 7.8 Atualizações de OS

Ubuntu 22.04 LTS: updates de segurança automáticos via unattended-upgrades (já vem habilitado).

Reboot mensal (opcional):

```bash
sudo apt upgrade -y
sudo reboot
# IP público reservado NÃO muda em reboot.
```

## Próximo

[08. Troubleshooting](./08-troubleshooting.md)
