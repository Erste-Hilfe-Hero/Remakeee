#!/usr/bin/env bash
# Dumps the whole database to backups/chimora-YYYY-MM-DD.dump and deletes dumps older than 14 days.
# Restore: docker compose exec -T db pg_restore -U postgres -h localhost -d postgres --clean < FILE
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p backups
chmod 700 backups
out="backups/chimora-$(date +%F).dump"
docker compose exec -T db pg_dump -U postgres -h localhost -Fc postgres > "$out.tmp"
mv "$out.tmp" "$out"
find backups -name 'chimora-*.dump' -mtime +14 -delete
echo "$(date -Is) backup $out $(du -h "$out" | cut -f1)"
