#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

REMOTE_HOST="${QC_REMOTE_HOST}"
REMOTE_USER="${QC_REMOTE_USER:-debian}"
REMOTE_BASE_PATH="${QC_REMOTE_BASE_PATH:-/home/debian/quierocambiarlo}"
DB_CONTAINER="${QC_DB_CONTAINER:-quierocambiarlo-database-1}"
DB_USER="${QC_DB_USER:-basic}"
DB_RETENTION_DAYS="${QC_DB_RETENTION_DAYS:-30}"
UPLOADS_RETENTION_DAYS="${QC_UPLOADS_RETENTION_DAYS:-30}"

SSH_OPTS="-i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o BatchMode=yes"

DB_DIR="/backups/quierocambiarlo/database"
UPLOADS_CURRENT="/backups/quierocambiarlo/uploads/current"
UPLOADS_ARCHIVE="/backups/quierocambiarlo/uploads/archive"

mkdir -p "${DB_DIR}" "${UPLOADS_CURRENT}" "${UPLOADS_ARCHIVE}"

# ── Database backup ───────────────────────────────────────────────────────────
log "quierocambiarlo: starting database backup..."
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DUMP_FILE="${DB_DIR}/dump_${TIMESTAMP}.sql.gz"

if ssh ${SSH_OPTS} "${REMOTE_USER}@${REMOTE_HOST}" \
     "docker exec ${DB_CONTAINER} pg_dumpall -c -U ${DB_USER} | gzip" \
     > "${DUMP_FILE}"; then
  success "quierocambiarlo: database dump saved to ${DUMP_FILE}"
else
  error "quierocambiarlo: database backup failed"
  rm -f "${DUMP_FILE}"
  exit 1
fi

find "${DB_DIR}" -name "dump_*.sql.gz" -mtime +"${DB_RETENTION_DAYS}" -delete
log "quierocambiarlo: database retention applied (${DB_RETENTION_DAYS} days)"

# ── Uploads backup (live mirror + delta archive) ──────────────────────────────
log "quierocambiarlo: starting uploads sync..."
DATE=$(date +"%Y-%m-%d")
ARCHIVE_DIR="${UPLOADS_ARCHIVE}/${DATE}"

if rsync -avz --delete \
         --backup --backup-dir="${ARCHIVE_DIR}" \
         -e "ssh ${SSH_OPTS}" \
         "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_PATH}/.uploads/" \
         "${UPLOADS_CURRENT}/"; then
  success "quierocambiarlo: uploads synced"
else
  error "quierocambiarlo: uploads sync failed"
  exit 1
fi

# Remove today's archive dir if nothing was displaced (no changes/deletions)
[ -d "${ARCHIVE_DIR}" ] && [ -z "$(ls -A "${ARCHIVE_DIR}")" ] && rmdir "${ARCHIVE_DIR}"

find "${UPLOADS_ARCHIVE}" -maxdepth 1 -mindepth 1 -type d \
     -mtime +"${UPLOADS_RETENTION_DAYS}" -exec rm -rf {} \;
log "quierocambiarlo: uploads retention applied (${UPLOADS_RETENTION_DAYS} days)"

success "quierocambiarlo: all backups completed"
