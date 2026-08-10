#!/usr/bin/env bash
# Boots shibd, the two FCGI helpers, and nginx in a single container.
# - Restores /etc/shibboleth defaults if a volume mount masked them.
# - Generates an SP signing/encryption keypair on first run if none exists.
# - Overlays our shibboleth/ config on top of the package defaults.
# - Substitutes ${VAR} placeholders in shibboleth2.xml from the environment.
set -euo pipefail

SHIB_ETC=/etc/shibboleth
SHIB_RUN=/var/run/shibboleth
SHIB_OVERLAY=/etc/shibboleth-overlay
SHIB_DEFAULTS=/opt/shibboleth-defaults

mkdir -p "$SHIB_RUN"

# 1) If /etc/shibboleth is empty (e.g. a fresh named volume just got mounted
#    over it), restore the package defaults baked into the image.
if [ -z "$(ls -A "$SHIB_ETC" 2>/dev/null)" ]; then
    echo "[entrypoint] /etc/shibboleth is empty; restoring package defaults."
    cp -a "$SHIB_DEFAULTS"/. "$SHIB_ETC"/
fi

# 2) Overlay our config (shibboleth2.xml, attribute-map.xml, ...) on top.
if [ -d "$SHIB_OVERLAY" ]; then
    cp -a "$SHIB_OVERLAY"/. "$SHIB_ETC"/
fi

# 3) Build the <SSO> block. If IDP_DISCOVERY_URL is set we run in federation
#    mode (Shibboleth SAMLDS profile) — the user picks their home IdP at the
#    discovery service, then SP issues a SAML2 AuthnRequest to that IdP.
#    Otherwise we fall back to single-IdP mode pinning to IDP_ENTITY_ID.
if [ -n "${IDP_DISCOVERY_URL:-}" ]; then
    echo "[entrypoint] SSO mode: federation (Discovery Service @ $IDP_DISCOVERY_URL)"
    SSO_BLOCK="<SSO discoveryProtocol=\"SAMLDS\" discoveryURL=\"${IDP_DISCOVERY_URL}\">SAML2</SSO>"
else
    echo "[entrypoint] SSO mode: single-IdP (entityID=${IDP_ENTITY_ID:-?})"
    SSO_BLOCK="<SSO entityID=\"${IDP_ENTITY_ID:-}\">SAML2</SSO>"
fi
export SSO_BLOCK

# 4) Render env vars into shibboleth2.xml (envsubst with an allow-list so we
#    don't accidentally clobber other ${...} occurrences).
SHIB_VARS='${SP_ENTITY_ID} ${SP_BASE_URL} ${SP_HOSTNAME} ${IDP_ENTITY_ID} ${IDP_METADATA_URL} ${IDP_DISCOVERY_URL} ${SUPPORT_CONTACT} ${SSO_BLOCK}'
tmp=$(mktemp)
envsubst "$SHIB_VARS" < "$SHIB_ETC/shibboleth2.xml" > "$tmp"
mv "$tmp" "$SHIB_ETC/shibboleth2.xml"

# 5) Generate SP keypairs on first boot.
if [ ! -f "$SHIB_ETC/sp-signing-cert.pem" ] || [ ! -f "$SHIB_ETC/sp-signing-key.pem" ]; then
    echo "[entrypoint] Generating SP signing keypair..."
    shib-keygen -h "${SP_HOSTNAME:-localhost}" -y 5 -e "${SP_ENTITY_ID:-https://localhost/shibboleth}" \
        -o "$SHIB_ETC" -n sp-signing -f
fi
if [ ! -f "$SHIB_ETC/sp-encrypt-cert.pem" ] || [ ! -f "$SHIB_ETC/sp-encrypt-key.pem" ]; then
    echo "[entrypoint] Generating SP encryption keypair..."
    shib-keygen -h "${SP_HOSTNAME:-localhost}" -y 5 -e "${SP_ENTITY_ID:-https://localhost/shibboleth}" \
        -o "$SHIB_ETC" -n sp-encrypt -f
fi
chown -R _shibd:_shibd "$SHIB_ETC" "$SHIB_RUN" /var/log/shibboleth 2>/dev/null || true

# 6) Wait for the IdP metadata endpoint BEFORE shibd starts — shibd needs
#    successful first metadata load or it exits with a fatal init error.
if [ -n "${IDP_METADATA_URL:-}" ] && [ "${WAIT_FOR_IDP:-1}" = "1" ]; then
    echo "[entrypoint] Waiting for IdP metadata at $IDP_METADATA_URL ..."
    for i in $(seq 1 60); do
        if curl -sfk --max-time 3 "$IDP_METADATA_URL" >/dev/null; then
            echo "[entrypoint] IdP metadata reachable."
            break
        fi
        sleep 2
    done
fi

# 7) Validate config (informational; warnings are non-fatal).
echo "[entrypoint] shibd -t (config check)..."
shibd -t || echo "[entrypoint] shibd -t reported issues; continuing."

# 8) Launch shibd in the foreground (-F) and background it from the script
#    so it stays our child and signals propagate. -f forces removal of any
#    stale listener socket.
echo "[entrypoint] Starting shibd..."
shibd -F -f -p /var/run/shibd.pid &
SHIBD_PID=$!
sleep 2
if ! kill -0 "$SHIBD_PID" 2>/dev/null; then
    echo "[entrypoint] shibd died on startup; aborting." >&2
    exit 1
fi

# 9) Spawn the FCGI helpers as _shibd (they need to read /etc/shibboleth, which
#    is locked down to that user). Socket mode 0666 lets nginx (www-data)
#    connect — safe inside the container's private namespace.
#
#    The helpers read SHIBSP_SERVER_{NAME,SCHEME,PORT} from their OS env (NOT
#    from FCGI request params), so we derive them from SP_BASE_URL and pass
#    via spawn-fcgi -e. Without these, every generated URL comes out as
#    "http://_/..." and the SAML AuthnRequest's ACS gets rejected by the IdP.
SP_URL="${SP_BASE_URL:-http://localhost:8081}"
SP_SCHEME="${SP_URL%%://*}"
SP_HOSTPORT="${SP_URL#*://}"
SP_HOSTPORT="${SP_HOSTPORT%%/*}"
case "$SP_HOSTPORT" in
    *:*) SP_HOST="${SP_HOSTPORT%:*}" ; SP_PORT="${SP_HOSTPORT##*:}" ;;
    *)   SP_HOST="$SP_HOSTPORT"
         SP_PORT=$([ "$SP_SCHEME" = "https" ] && echo 443 || echo 80) ;;
esac
echo "[entrypoint] SHIBSP_SERVER_NAME=$SP_HOST SCHEME=$SP_SCHEME PORT=$SP_PORT"

echo "[entrypoint] Starting shibauthorizer + shibresponder FCGI helpers..."
export SHIBSP_SERVER_NAME="$SP_HOST"
export SHIBSP_SERVER_SCHEME="$SP_SCHEME"
export SHIBSP_SERVER_PORT="$SP_PORT"
spawn-fcgi -u _shibd -g _shibd \
    -s "$SHIB_RUN/shibauthorizer.sock" -M 0666 \
    -- /usr/lib/x86_64-linux-gnu/shibboleth/shibauthorizer
spawn-fcgi -u _shibd -g _shibd \
    -s "$SHIB_RUN/shibresponder.sock" -M 0666 \
    -- /usr/lib/x86_64-linux-gnu/shibboleth/shibresponder

# 10) Discover bentopdf replicas via Docker DNS and generate an upstream
#     config so nginx can load-balance across all instances.
echo "[entrypoint] Discovering bentopdf replicas..."
BENTOPDF_IPS=$(getent ahosts bentopdf 2>/dev/null | awk '/STREAM/ {print $1}' | sort -u || true)
BENTOPDF_SERVERS=""
for ip in $BENTOPDF_IPS; do
    BENTOPDF_SERVERS="${BENTOPDF_SERVERS}    server ${ip}:8080;
"
done
if [ -z "$BENTOPDF_SERVERS" ]; then
    echo "[entrypoint] WARNING: no bentopdf replicas found via DNS; falling back to service name."
    BENTOPDF_SERVERS="    server bentopdf:8080;
"
fi
REPLICA_COUNT=$(echo "$BENTOPDF_IPS" | grep -c . 2>/dev/null || echo 1)
echo "[entrypoint] Found $REPLICA_COUNT bentopdf replica(s)."

cat > /etc/nginx/conf.d/00-upstream-bentopdf.conf <<UPSTREAM_EOF
upstream bentopdf_pool {
    # Uncomment for sticky sessions (pin client IP to one replica):
    # ip_hash;

${BENTOPDF_SERVERS}}
UPSTREAM_EOF
cat /etc/nginx/conf.d/00-upstream-bentopdf.conf

# 11) Hand off PID 1 to nginx (foreground) so signals propagate cleanly.
echo "[entrypoint] Starting nginx..."
exec nginx -g 'daemon off;'
