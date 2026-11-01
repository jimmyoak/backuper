#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

REMOTE_HOST="${PF_REMOTE_HOST}"
REMOTE_USER="${PF_REMOTE_USER:-debian}"
DB_CONTAINER="${PF_DB_CONTAINER:-pirfila-pirfila-database-1}"
DB_USER="${PF_DB_USER:-pirfila}"
DB_NAME="${PF_DB_NAME:-pirfila}"
DB_RETENTION_DAYS="${PF_DB_RETENTION_DAYS:-30}"

SSH_OPTS="-i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o BatchMode=yes"

DB_DIR="/backups/pirfila/database"
mkdir -p "${DB_DIR}"

# ── Database backup ───────────────────────────────────────────────────────────
# Custom-format pg_dump (-Fc) is already compressed, so no gzip. Restore with pg_restore.
log "pirfila: starting database backup..."
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DUMP_FILE="${DB_DIR}/dump_${TIMESTAMP}.dump"

if ssh ${SSH_OPTS} "${REMOTE_USER}@${REMOTE_HOST}" \
     "docker exec ${DB_CONTAINER} pg_dump -U ${DB_USER} -Fc ${DB_NAME}" \
     > "${DUMP_FILE}" && [ -s "${DUMP_FILE}" ]; then
  success "pirfila: database dump saved to ${DUMP_FILE}"
else
  error "pirfila: database backup failed"
  rm -f "${DUMP_FILE}"
  exit 1
fi

find "${DB_DIR}" -name "dump_*.dump" -mtime +"${DB_RETENTION_DAYS}" -delete
log "pirfila: database retention applied (${DB_RETENTION_DAYS} days)"

success "pirfila: all backups completed"
