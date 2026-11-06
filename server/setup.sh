#!/usr/bin/env bash
# Installs or updates the Chimora game server on a fresh Ubuntu 24.04 machine (for example a Contabo
# Cloud VPS). Safe to run again: it keeps the database and the keys, applies new migrations and
# restarts what changed.
#
#   sudo bash server/setup.sh                 # address <server-ip>.sslip.io, no domain needed
#   sudo DOMAIN=api.example.de bash server/setup.sh
#   LOCAL_TEST=1 bash server/setup.sh         # CI: plain http://localhost, no firewall or cron
#
# On a machine where another Caddy already serves ports 80/443 (shared host):
#   SHARED_HOST=1 SHARED_NETWORK=<its docker network> PROXY_CONTAINER=<its container> \
#   DOMAIN=<chimora address> bash server/setup.sh
# Chimora then opens no ports and leaves the firewall alone; the other Caddy gets one route for
# DOMAIN in its running config (proxy_site.sh), and one site block in its Caddyfile (PROXY_CADDYFILE) so the proxy's own deploys keep it;
# re-checked every 10 minutes.
#
# Prints the server address and the public anon key at the end; they are also served at
# https://<address>/chimora.json, where CI picks them up for the game builds.
set -euo pipefail
cd "$(dirname "$0")"
here="$(pwd)"
local_test="${LOCAL_TEST:-0}"
shared="${SHARED_HOST:-0}"

if [ "$local_test" != "1" ] && [ "$(id -u)" != "0" ]; then
	echo "Please run as root (sudo)." >&2
	exit 1
fi

# --- Programs ----------------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
	echo "Installing Docker..."
	apt-get update -q
	DEBIAN_FRONTEND=noninteractive apt-get install -yq docker.io docker-compose-v2 openssl curl
	systemctl enable --now docker
fi

# --- Address -----------------------------------------------------------------------------------
if [ "$local_test" = "1" ] && [ "$shared" != "1" ]; then
	site=":80"
	public_url="http://localhost"
elif [ "$shared" = "1" ]; then
	site=":80"
	public_url="https://${DOMAIN:?DOMAIN is needed on a shared host}"
else
	domain="${DOMAIN:-}"
	if [ -z "$domain" ] && [ -f .env ]; then
		domain="$(sed -n 's/^DOMAIN=//p' .env)"
	fi
	if [ -z "$domain" ]; then
		ip="$(curl -fsS4 https://api.ipify.org || hostname -I | awk '{print $1}')"
		domain="${ip//./-}.sslip.io"
	fi
	site="$domain"
	public_url="https://$domain"
fi

# --- Keys (made once, kept in .env, never leave this machine except the public anon key) --------
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
if [ ! -f .env ]; then
	pg="$(openssl rand -hex 24)"
	secret="$(openssl rand -hex 32)"
	now="$(date +%s)"
	header="$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)"
	payload="$(printf '{"role":"anon","iss":"chimora","iat":%d,"exp":%d}' "$now" "$((now + 10 * 365 * 86400))" | b64url)"
	sig="$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$secret" -binary | b64url)"
	umask 077
	cat > .env <<ENV
POSTGRES_PASSWORD=$pg
JWT_SECRET=$secret
ANON_KEY=$header.$payload.$sig
ENV
	umask 022
fi
# Address lines are rewritten each run (DOMAIN can change).
grep -v '^\(DOMAIN\|SITE_ADDRESS\|PUBLIC_URL\|COMPOSE_FILE\|SHARED_NETWORK\)=' .env > .env.new || true
{
	cat .env.new
	[ "$local_test" = "1" ] || [ "$shared" = "1" ] || echo "DOMAIN=$site"
	echo "SITE_ADDRESS=$site"
	echo "PUBLIC_URL=$public_url"
	if [ "$shared" = "1" ]; then
		echo "COMPOSE_FILE=docker-compose.yml:docker-compose.shared.yml"
		echo "SHARED_NETWORK=${SHARED_NETWORK:?SHARED_NETWORK is needed on a shared host}"
	fi
} > .env
rm -f .env.new
chmod 600 .env
anon="$(sed -n 's/^ANON_KEY=//p' .env)"

mkdir -p public
printf '{"url": "%s", "anon_key": "%s"}\n' "$public_url" "$anon" > public/chimora.json

# --- Start -------------------------------------------------------------------------------------
docker compose pull -q
docker compose up -d --remove-orphans
# The Caddyfile is a bind mount; an update replaces the file, so the container must restart to see it.
docker compose restart caddy >/dev/null

echo "Waiting for the sign-in service to set up its tables..."
for i in $(seq 1 90); do
	if docker compose exec -T db psql -U postgres -h localhost -d postgres -tAc \
		"select to_regclass('auth.users') is not null and exists (select 1 from auth.schema_migrations)" 2>/dev/null | grep -q t; then
		break
	fi
	if [ "$i" = 90 ]; then
		docker compose logs --tail 50 auth db >&2
		echo "The sign-in service did not start." >&2
		exit 1
	fi
	sleep 2
done

bash "$here/migrate.sh"

if [ "$shared" = "1" ]; then
	DOMAIN="${DOMAIN}" PROXY_CADDYFILE="${PROXY_CADDYFILE:-}" bash "$here/proxy_site.sh"
fi

# --- Machine care (not in CI) ------------------------------------------------------------------
if [ "$local_test" != "1" ] && [ "$shared" != "1" ]; then
	if command -v ufw >/dev/null 2>&1; then
		ufw allow 22/tcp >/dev/null
		ufw allow 80/tcp >/dev/null
		ufw allow 443/tcp >/dev/null
		ufw --force enable >/dev/null
	fi
	DEBIAN_FRONTEND=noninteractive apt-get install -yq unattended-upgrades >/dev/null 2>&1 || true
fi
if [ "$local_test" != "1" ]; then
	cat > /etc/cron.d/chimora-backup <<CRON
# Nightly database backup, kept 14 days (server/backup.sh).
30 3 * * * root bash $here/backup.sh >> /var/log/chimora-backup.log 2>&1
# Weekly restore test of the newest backup (server/restore_test.sh), result in /status.json.
0 5 * * 1 root bash $here/restore_test.sh >> /var/log/chimora-restore.log 2>&1
CRON
	if [ "$shared" = "1" ]; then
		cat > /etc/cron.d/chimora-proxy <<CRON
# Puts Chimora's route back when the shared proxy loads its own config again (server/proxy_site.sh).
*/10 * * * * root QUIET=1 PROXY_CONTAINER=${PROXY_CONTAINER} PROXY_CADDYFILE=${PROXY_CADDYFILE:-} DOMAIN=${DOMAIN} bash $here/proxy_site.sh >> /var/log/chimora-proxy.log 2>&1
CRON
	fi
fi

echo
echo "Chimora server is running."
echo "  Address:  $public_url"
echo "  Anon key: $anon"
echo "  (both are public; the game builds read them from $public_url/chimora.json)"
