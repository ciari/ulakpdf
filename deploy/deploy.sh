#!/usr/bin/env bash
# Build + start the production docker stack.
# Run from the project root (/opt/spdf) after install.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

# ---------- 1. .env sanity check ----------
if [ ! -f .env ]; then
    echo "[deploy] .env not found at $ROOT/.env" >&2
    echo "[deploy] copy deploy/.env.production.example to .env and fill in real values" >&2
    exit 1
fi

# Minimal required-key check.
missing=()
for k in DOMAIN SP_BASE_URL SP_ENTITY_ID IDP_METADATA_URL ADMIN_EPPNS; do
    if ! grep -qE "^${k}=" .env || grep -qE "^${k}=$" .env; then
        missing+=("$k")
    fi
done
if [ "${#missing[@]}" -ne 0 ]; then
    echo "[deploy] .env is missing values for: ${missing[*]}" >&2
    exit 1
fi

# Either IDP_ENTITY_ID (single-IdP mode) OR IDP_DISCOVERY_URL (federation mode)
# must be set — entrypoint picks the SSO style accordingly.
has_entity=0
has_discovery=0
grep -qE '^IDP_ENTITY_ID=.+' .env       && has_entity=1
grep -qE '^IDP_DISCOVERY_URL=.+' .env   && has_discovery=1
if [ "$has_entity" -eq 0 ] && [ "$has_discovery" -eq 0 ]; then
    echo "[deploy] .env must set either IDP_ENTITY_ID (single-IdP mode)" >&2
    echo "          or IDP_DISCOVERY_URL (federation mode)." >&2
    exit 1
fi

# ---------- 2. Build images ----------
echo "[deploy] building images..."
docker compose -f deploy/docker-compose.prod.yml --env-file .env build

# ---------- 3. Bring up ----------
echo "[deploy] starting stack..."
docker compose -f deploy/docker-compose.prod.yml --env-file .env up -d

# ---------- 4. Wait for nginx-shib to be healthy ----------
echo -n "[deploy] waiting for nginx-shib healthy"
for i in $(seq 1 60); do
    s=$(docker inspect --format='{{.State.Health.Status}}' ulakpdf-nginx-shib 2>/dev/null || echo missing)
    if [ "$s" = "healthy" ]; then echo " ✓"; break; fi
    echo -n "."
    sleep 2
done

docker compose -f deploy/docker-compose.prod.yml --env-file .env ps

cat <<EOF

[deploy] DONE.

SP metadata to register with Yetkim:
  https://$(grep '^DOMAIN=' .env | cut -d= -f2)/Shibboleth.sso/Metadata

Useful URLs:
  https://$(grep '^DOMAIN=' .env | cut -d= -f2)/         (landing)
  https://$(grep '^DOMAIN=' .env | cut -d= -f2)/stats/   (admin-only, eppn in ADMIN_EPPNS)
  https://$(grep '^DOMAIN=' .env | cut -d= -f2)/logout   (terminate Shib session)

Logs:
  docker compose -f deploy/docker-compose.prod.yml logs -f nginx-shib
  docker compose -f deploy/docker-compose.prod.yml logs -f stats-api
EOF
