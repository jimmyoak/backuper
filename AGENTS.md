# AGENTS.md — backuper

## Purpose

This repo runs a containerized daily backup service for remote projects hosted on OVH (or any SSH-accessible host). It is designed to run on a Raspberry Pi but works on any machine with Docker.

## Repository structure

```
backuper/
├── Dockerfile                       # Alpine + bash + openssh-client + rsync + gzip + tzdata
├── docker-compose.yml
├── env.example                      # Template — copy to .env and fill in values
├── .gitignore
├── README.md
├── AGENTS.md
├── ssh/
│   └── id_rsa                       # SSH private key (gitignored, placed at deploy time)
└── scripts/
    ├── entrypoint.sh                # Installs crontab, starts crond
    ├── run-all.sh                   # Called by cron; sources every projects/*.sh
    ├── lib/
    │   └── common.sh                # log/success/warn/error helpers
    └── projects/
        └── quierocambiarlo.sh       # One file per project
```

## Conventions

### Adding a project

1. Add env vars for the new project to `.env` (and document them in `env.example`).
2. Create `scripts/projects/<projectname>.sh`. It will be auto-discovered by `run-all.sh`.
3. Rebuild: `docker compose build && docker compose up -d`.

A project script must:
- `source "${SCRIPT_DIR}/../lib/common.sh"` for logging.
- Read all config from env vars (no hardcoded hosts, users, or paths).
- Exit non-zero on failure so `run-all.sh` can report it.

### Database backups

Use a direct SSH pipe — never create a temp file on the remote:

```bash
ssh ${SSH_OPTS} "${REMOTE_USER}@${REMOTE_HOST}" \
  "docker exec ${DB_CONTAINER} pg_dumpall -c -U ${DB_USER} | gzip" \
  > "${DB_DIR}/dump_${TIMESTAMP}.sql.gz"
```

Apply retention with:
```bash
find "${DB_DIR}" -name "dump_*.sql.gz" -mtime +"${RETENTION_DAYS}" -delete
```

### File/uploads backups

Use `rsync --delete --backup --backup-dir` for a live mirror with a delta archive:

```bash
rsync -avz --delete \
  --backup --backup-dir="${ARCHIVE_DIR}" \
  -e "ssh ${SSH_OPTS}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" \
  "${CURRENT_DIR}/"
```

- `current/` is always a live mirror.
- Deleted or overwritten files are moved to `archive/YYYY-MM-DD/` instead of being destroyed.
- Archive dirs older than `RETENTION_DAYS` are pruned with `find -mtime +N -exec rm -rf`.
- Never use `tar` for file trees — it creates full archives every run and does not scale.

### SSH

All SSH calls use:
```bash
SSH_OPTS="-i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o BatchMode=yes"
```

`BatchMode=yes` prevents SSH from hanging waiting for a password if key auth fails.
`StrictHostKeyChecking=no` avoids interactive host-key prompts in cron. For stricter setups, place a `known_hosts` file in `./ssh/` and mount it at `/root/.ssh/known_hosts`.

### Logging

Use the helpers from `lib/common.sh`: `log`, `success`, `warn`, `error`. These match the colour scheme of the existing project scripts (`quierocambiarlo-boot`).

### No state files, no temp files on the remote

All state lives in the backup volume. Nothing is written to the remote host during a backup.
