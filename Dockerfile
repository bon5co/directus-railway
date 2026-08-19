# Directus for Railway.
#
# Two Railway-specific problems are fixed here, both of which the marketplace
# listings ship unfixed:
#
#   1. Directus creates no user account unless ADMIN_EMAIL and ADMIN_PASSWORD are
#      present when `directus bootstrap` runs against an empty database. The
#      server still starts and /server/ping still answers 200, so the deploy
#      looks healthy while nobody can sign in — and no HTTP route creates the
#      first user.
#   2. Railway mounts volumes owned by uid 0 while this image runs as `node`
#      (uid 1000), so a volume mounted on the uploads directory is not writable
#      by the process that has to write to it.
FROM directus/directus:12.3.0

USER root

RUN apk add --no-cache su-exec

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV STORAGE_LOCATIONS="local" \
    STORAGE_LOCAL_DRIVER="local" \
    STORAGE_LOCAL_ROOT="/directus/uploads" \
    EXTENSIONS_PATH="/directus/extensions" \
    WEBSOCKETS_ENABLED="true" \
    LOG_STYLE="raw" \
    TELEMETRY="false"

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
