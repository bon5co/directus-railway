# directus-railway

Wrapper image for deploying [Directus](https://directus.io) on
[Railway](https://railway.com). Published as
`ghcr.io/bon5co/directus-railway:12.3.0`.

It is `directus/directus:12.3.0` plus a boot script that fixes two things the
platform breaks.

## An administrator actually exists

`directus bootstrap` creates the first user only when `ADMIN_EMAIL` and
`ADMIN_PASSWORD` are present. Without them it installs the schema, starts the
server and answers `GET /server/ping` with `200` while `directus_users` has no
rows — and no HTTP route creates the first account (`POST /users` returns
`403`). The deploy looks healthy and can never be signed into.

This entrypoint refuses to start on an empty `ADMIN_EMAIL` or `ADMIN_PASSWORD`,
so that state is unreachable.

It also re-applies the password on every boot with `directus users passwd`, so a
redeploy is a working password reset. Directus's own recovery path is an emailed
link, which a deployment with no SMTP account cannot use.

## The uploads volume is writable

Railway mounts volumes owned by uid 0; this image runs as `node` (uid 1000). The
entrypoint repairs ownership of the uploads and extensions directories as root
and then drops to `node` with `su-exec` before any Directus process starts.

## Variables

| Variable | Required | Notes |
| --- | --- | --- |
| `ADMIN_EMAIL` | yes | the administrator's sign-in address |
| `ADMIN_PASSWORD` | yes | re-applied on every boot |
| `SECRET` | yes | session/token signing key; keep it stable across redeploys |
| `DB_CLIENT`, `DB_CONNECTION_STRING` | yes | e.g. `pg` and a Postgres URL |
| `PUBLIC_URL` | recommended | the deployment's public URL |

Baked into the image: local file storage rooted at `/directus/uploads`,
extensions at `/directus/extensions`, websockets on, telemetry off.

## Building

Pushed to GHCR by `.github/workflows/publish.yml` on every push to `main`.
