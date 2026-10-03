#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log "=== Backup run started at $(date) ==="

EXIT_CODE=0
for project_script in "${SCRIPT_DIR}/projects/"*.sh; do
  [ -f "$project_script" ] || continue
  log "Running: $(basename "$project_script")"
  if ! bash "$project_script"; then
    error "$(basename "$project_script") failed"
    EXIT_CODE=1
  fi
done

if [ $EXIT_CODE -eq 0 ]; then
  success "=== All backups completed at $(date) ==="
else
  error "=== Backup run finished with errors at $(date) ==="
fi

exit $EXIT_CODE
