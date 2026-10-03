#!/bin/bash
set -euo pipefail

mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/known_hosts

if [ -f /root/.ssh/id_rsa ]; then
  chmod 600 /root/.ssh/id_rsa
fi

BACKUP_CRON="${BACKUP_CRON:-0 3 * * *}"
echo "${BACKUP_CRON} /opt/backuper/run-all.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "[INFO] Backup service started. Schedule: ${BACKUP_CRON}"
exec crond -f -L /dev/stdout
