# backuper

Dockerized backup service. Runs on any machine (Raspberry Pi, VPS, laptop) and backs up remote projects via SSH on a configurable cron schedule.

## How it works

- **Database**: dumps Postgres directly over SSH (no temp file on the remote), saves a timestamped `.sql.gz` locally, and prunes dumps older than a configurable retention window.
- **Uploads/files**: syncs a live mirror with `rsync --delete`, but before deleting anything locally it moves displaced files into a dated archive directory. Storage cost = one full copy of current files + N days of delta (only what changed or was deleted). On the first run it does a full download; subsequent runs transfer only differences.

## Prerequisites

- Docker and Docker Compose
- SSH key pair with access to the remote host (key-based auth, no password)
- An external partition or dedicated directory for backup storage

## Setup

**1. Clone and configure**

```bash
git clone <repo-url>
cd backuper
cp env.example .env
# Edit .env — fill in BACKUP_LOCATION, QC_REMOTE_HOST, and any other vars
```

**2. Place your SSH private key**

```bash
cp ~/.ssh/your_key ssh/id_rsa
# The file is gitignored — never committed
```

The key must grant access to the remote host as the user specified in `QC_REMOTE_USER`.

**3. Mount the external partition** (Raspberry Pi example)

Add to `/etc/fstab`:
```
UUID=your-disk-uuid  /mnt/backups  ext4  defaults,noatime  0  2
```

Then set `BACKUP_LOCATION=/mnt/backups` in `.env`.

**4. Start the service**

```bash
docker compose up -d
docker compose logs -f
```

The service waits for the cron schedule (default: 3 AM daily). To run immediately:

```bash
docker compose exec backuper /opt/backuper/run-all.sh
```

## Configuration (`.env`)

| Variable | Default | Description |
|---|---|---|
| `TZ` | — | Timezone (e.g. `Europe/Madrid`) |
| `BACKUP_CRON` | `0 3 * * *` | Cron schedule for backups |
| `BACKUP_LOCATION` | — | Host path to mount as `/backups` |
| `QC_REMOTE_HOST` | — | OVH host IP or hostname |
| `QC_REMOTE_USER` | `debian` | SSH user on the remote |
| `QC_REMOTE_BASE_PATH` | `/home/debian/quierocambiarlo` | Project root on the remote |
| `QC_DB_CONTAINER` | `quierocambiarlo-database-1` | Docker container name for Postgres |
| `QC_DB_USER` | `basic` | Postgres superuser for `pg_dumpall` |
| `QC_DB_RETENTION_DAYS` | `30` | Days to keep database dumps |
| `QC_UPLOADS_RETENTION_DAYS` | `30` | Days to keep displaced files in the uploads archive |

## Backup layout

```
/backups/
└── quierocambiarlo/
    ├── database/
    │   ├── dump_2025-01-15_03-00-01.sql.gz
    │   └── dump_2025-01-16_03-00-02.sql.gz
    └── uploads/
        ├── current/          ← live mirror of remote .uploads/
        └── archive/
            ├── 2025-01-15/   ← files deleted or overwritten on that day
            └── 2025-01-16/
```

## Adding a new project

1. Add the project's env vars to `.env` (use `env.example` as reference).
2. Create `scripts/projects/<projectname>.sh` — see `quierocambiarlo.sh` as the template.
3. `run-all.sh` picks up all `scripts/projects/*.sh` automatically; no other changes needed.
4. Rebuild the image: `docker compose build && docker compose up -d`

## Manual operations

```bash
# Trigger all backups now
docker compose exec backuper /opt/backuper/run-all.sh

# Trigger a single project
docker compose exec backuper bash /opt/backuper/projects/quierocambiarlo.sh

# Dry-run uploads sync (no changes made)
docker compose exec backuper rsync --dry-run --itemize-changes -avz \
  -e "ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no" \
  debian@YOUR_HOST:/home/debian/quierocambiarlo/.uploads/ \
  /backups/quierocambiarlo/uploads/current/

# View logs
docker compose logs -f --tail=100
```
