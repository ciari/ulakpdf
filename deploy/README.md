# UlakPDF — Production deployment (Debian 12)

Step-by-step deployment guide. Target topology:

```
internet ──▶ host nginx :443 (TLS)  ──▶ docker stack :8081 (loopback)
                ↑                          ├─▶ nginx-shib  (SP)
            certbot (LE)                   ├─▶ bentopdf    (static)
                                           └─▶ stats-api   (FastAPI)
                                                  ↕
                                          Yetkim IdP (SAML2)
```

The docker stack listens **only on 127.0.0.1** — the host nginx is the
only thing exposed to the internet. TLS terminates at the host nginx,
which forwards plain HTTP (with `X-Forwarded-Proto: https`) to the
docker stack.

## Prerequisites

- A Debian 12 VM with root SSH access
- A domain whose A/AAAA records already point at the VM
- A Yetkim IdP account: you'll need its entity ID and metadata URL
- An email address for Let's Encrypt registration

## 1. Get the code on the VM

Either rsync your local working tree, or clone from your repo. The path
**must** be `/opt/spdf` (the install/deploy scripts assume it):

```bash
sudo mkdir -p /opt/spdf
sudo chown $USER /opt/spdf
rsync -av --delete --exclude=upstream/ ./ root@vm:/opt/spdf/
```

## 2. Run the bootstrap script

```bash
sudo bash /opt/spdf/deploy/install.sh
```

This installs:
- Docker engine + compose plugin
- nginx + certbot + python3-certbot-nginx
- UFW firewall (opens 22 / 80 / 443, denies the rest)
- `logrotate` rules for the docker nginx logs

It does **not** touch your domain or get a certificate yet.

## 3. Fill in `.env`

```bash
cd /opt/spdf
cp deploy/.env.production.example .env
$EDITOR .env
```

Required keys:
- `DOMAIN` — e.g. `ulakpdf.example.tr`
- `IDP_ENTITY_ID`, `IDP_METADATA_URL` — from Yetkim
- `ADMIN_EPPNS` — comma-separated eppns that can see `/stats/`
- `SUPPORT_CONTACT` — shown on Shib error pages

## 4. Configure the host nginx site

```bash
cd /opt/spdf
# Substitute ${DOMAIN} into the template
DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)
sudo bash -c "DOMAIN=$DOMAIN envsubst '\${DOMAIN}' < deploy/nginx-host.conf > /etc/nginx/sites-available/ulakpdf"
sudo ln -sf /etc/nginx/sites-available/ulakpdf /etc/nginx/sites-enabled/ulakpdf
sudo nginx -t && sudo systemctl reload nginx
```

At this point port 80 serves a redirect-to-https that doesn't yet resolve.

## 5. Get the TLS certificate

```bash
sudo certbot --nginx \
    -d "$DOMAIN" \
    --redirect \
    --agree-tos \
    -m admin@example.tr   # your email
```

Certbot edits `/etc/nginx/sites-available/ulakpdf` in place, adding
`ssl_certificate` lines. Renewal runs automatically via the systemd timer
`certbot.timer` (`systemctl status certbot.timer`).

## 6. (optional) Strict Yetkim metadata verification

For production you should verify the signature of the IdP metadata
shibd downloads. Place the federation signing certificate at:

```
nginx-shib/shibboleth/federation-cert.pem
```

Then edit `nginx-shib/shibboleth/shibboleth2.xml`, find the
`<MetadataProvider>` block, and add a Signature filter:

```xml
<MetadataProvider type="XML" url="${IDP_METADATA_URL}"
                  backingFilePath="idp-metadata.xml"
                  maxRefreshDelay="7200">
    <MetadataFilter type="RequireValidUntil" maxValidityInterval="2419200"/>
    <MetadataFilter type="Signature" certificate="federation-cert.pem"/>
</MetadataProvider>
```

Skipping this means anyone who can MITM the metadata fetch can spoof the
IdP — only acceptable if `IDP_METADATA_URL` is HTTPS and you trust the
hostname end-to-end. Yetkim metadata is normally signed; turn this on.

## 7. Build and start the stack

```bash
cd /opt/spdf
bash deploy/deploy.sh
```

This:
- Builds `bentopdf` (with your brand vars), `nginx-shib`, `stats-api`
- Brings everything up
- Waits for `nginx-shib` to be healthy
- Prints the SP metadata URL you'll register with Yetkim

## 8. Register the SP with Yetkim

Send Yetkim the metadata URL: `https://<your-domain>/Shibboleth.sso/Metadata`

Or download a static copy:

```bash
curl -fsSL "https://$DOMAIN/Shibboleth.sso/Metadata" > /tmp/ulakpdf-sp-metadata.xml
```

Yetkim will release the attributes you've mapped:
- `eduPersonPrincipalName` (eppn) — required for stats user identity
- `mail`, `displayName`, `givenName`, `sn` — used by the navbar user menu
- `eduPersonAffiliation` — surfaced as institution / role

## 9. Smoke test

Visit `https://<your-domain>/`:
- Should redirect HTTP → HTTPS
- Anonymous → custom UlakPDF landing
- "Yetkim SSO" → bounces to Yetkim → after login → BentoPDF
- Navbar shows your eppn + Çıkış button
- `/stats/` shows the admin dashboard (only for users in `ADMIN_EPPNS`)

## Operations

### Daily logs
```bash
docker compose -f deploy/docker-compose.prod.yml --env-file .env logs -f --tail 100
```

### Update the codebase
```bash
cd /opt/spdf
rsync -av --delete --exclude=upstream/ source/ /opt/spdf/   # or git pull
bash deploy/deploy.sh   # rebuilds and restarts
```

### Rotate / clear stats
```bash
docker compose -f deploy/docker-compose.prod.yml --env-file .env exec stats-api \
    rm /data/stats.sqlite   # next boot recreates an empty DB
docker compose -f deploy/docker-compose.prod.yml --env-file .env restart stats-api
```

### Back up SP keypair + stats
The SP signing/encryption keys live in the `ulakpdf_shib-state` named
volume. Re-issuing keys means re-registering with Yetkim, so back this up:

```bash
docker run --rm -v ulakpdf_shib-state:/data -v $(pwd):/backup alpine \
    tar czf /backup/shib-state-$(date +%F).tar.gz -C /data .
docker run --rm -v ulakpdf_stats-db:/data -v $(pwd):/backup alpine \
    tar czf /backup/stats-db-$(date +%F).tar.gz -C /data .
```

### Restart after VM reboot
Docker's restart policy is `always`, so all services come back up automatically.
The host nginx is a systemd service; it also restarts on boot.

## Troubleshooting

### "Connection refused" on https://your-domain
`docker compose ps` — nginx-shib should be healthy. If not, check
`docker logs ulakpdf-nginx-shib`. Almost always: the `IDP_METADATA_URL`
isn't reachable from inside the container (firewall, typo).

### SAML round-trip fails with "Insufficient information from IdP"
Yetkim isn't releasing the attributes our `attribute-map.xml` expects.
Check `docker exec ulakpdf-nginx-shib tail /var/log/shibboleth/shibd.log`
for "skipping SAML 2.0 Attribute" warnings; the name format Yetkim sends
may not match what shibd is configured for. Edit
`nginx-shib/shibboleth/attribute-map.xml` and rebuild.

### Admin dashboard shows "Yetkisiz" for an eppn that should be admin
The eppn check is case-insensitive but exact-match. Verify the value in
`/stats/api/recent` matches what you put in `ADMIN_EPPNS`.

### Stats SQLite getting large
The `events` table grows ~200 bytes per request. To prune:

```sql
DELETE FROM events WHERE day < date('now', '-90 days');
VACUUM;
```

Run via `docker exec -it ulakpdf-stats-api python -c '...'` or open the
DB file directly from the named volume on the host.
