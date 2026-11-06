#!/usr/bin/env bash
# Dumps the whole database to backups/chimora-YYYY-MM-DD.dump and deletes dumps older than 14 days.
# BACKUP_NAME=pre-migration names the dump chimora-pre-migration-<time>.dump instead (migrate.sh).
# Restore: docker compose exec -T db pg_restore -U postgres -h localhost -d postgres --clean < FILE
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p backups
chmod 700 backups
if [ -n "${BACKUP_NAME:-}" ]; then
	out="backups/chimora-${BACKUP_NAME}-$(date +%Y%m%dT%H%M%S).dump"
else
	out="backups/chimora-$(date +%F).dump"
fi
docker compose exec -T db pg_dump -U postgres -h localhost -Fc postgres > "$out.tmp"
# An empty or cut-off dump is not a backup: pg_restore must be able to list it.
docker compose exec -T db pg_restore --list < "$out.tmp" > /dev/null
mv "$out.tmp" "$out"
find backups -name 'chimora-*.dump' -mtime +14 -delete
echo "$(date -Is) backup $out $(du -h "$out" | cut -f1)"
