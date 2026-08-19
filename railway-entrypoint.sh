#!/bin/sh
# Railway entrypoint for Directus.
#
# Fixes two Railway-specific problems, both of which the marketplace listings
# ship unfixed:
#
#   1. `directus bootstrap` creates an administrator only when ADMIN_EMAIL and
#      ADMIN_PASSWORD are set. Without them the schema is installed, the server
#      starts, /server/ping answers 200 -- and directus_users has no rows. No
#      HTTP route creates the first user, so the instance can never be signed
#      into. This entrypoint refuses to start rather than produce that.
#   2. Railway mounts volumes owned by uid 0 while this image runs as `node`
#      (uid 1000), so an uploads volume is not writable by the process that has
#      to write to it.
#
# Ordering matters: the account exists and its password is current before the
# HTTP port is ever opened.
set -e

DATA_DIR="${STORAGE_LOCAL_ROOT:-/directus/uploads}"
EXT_DIR="${EXTENSIONS_PATH:-/directus/extensions}"

fail() {
  echo "[railway] $1" >&2
  exit 1
}

[ -n "$ADMIN_EMAIL" ] || fail "ADMIN_EMAIL is empty. Refusing to start: Directus would boot with no account and no way to create one."
[ -n "$ADMIN_PASSWORD" ] || fail "ADMIN_PASSWORD is empty. Refusing to start: Directus would boot with no account and no way to create one."

for dir in "$DATA_DIR" "$EXT_DIR" /directus/database; do
  mkdir -p "$dir"
  chown -R node:node "$dir" 2>/dev/null || true
done
echo "[railway] uploads=$(stat -c %u:%g "$DATA_DIR") extensions=$(stat -c %u:%g "$EXT_DIR")"

as_node() {
  su-exec node:node "$@"
}

# Installs the schema and, on an empty database, creates the administrator from
# ADMIN_EMAIL/ADMIN_PASSWORD. Idempotent on later boots.
as_node node /directus/cli.js bootstrap

# Re-apply the password on every boot, so a redeploy is a working password
# reset. Directus's own recovery path is an emailed link, which a deployment
# with no SMTP account cannot use.
if as_node node /directus/cli.js users passwd --email "$ADMIN_EMAIL" --password "$ADMIN_PASSWORD"; then
  echo "[railway] admin password applied for $ADMIN_EMAIL"
else
  echo "[railway] WARNING: could not set the password for $ADMIN_EMAIL" >&2
fi

# Hand back to the stock boot sequence (bootstrap re-check, then pm2-runtime).
exec su-exec node:node node /directus/docker-entrypoint.cjs
