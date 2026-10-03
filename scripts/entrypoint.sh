#!/bin/bash
set -euo pipefail

mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/known_hosts

# Copy the key from the read-only mount so we can set correct permissions
if [ -f /run/secrets/id_rsa ]; then
  cp /run/secrets/id_rsa /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
else
  echo "[WARN] No SSH key found at /run/secrets/id_rsa — backups will fail"
fi

BACKUP_CRON="${BACKUP_CRON:-0 3 * * *}"
echo "${BACKUP_CRON} /opt/backuper/run-all.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "[INFO] Backup service started. Schedule: ${BACKUP_CRON}"
exec crond -f -L /dev/stdout
