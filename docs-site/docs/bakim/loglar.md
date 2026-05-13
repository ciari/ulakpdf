# Loglar ve İzleme

## Log konumları

| Bileşen | Konum | Format |
|---|---|---|
| Host nginx access | `/var/log/nginx/ulakpdf.access.log` | combined |
| Host nginx error | `/var/log/nginx/ulakpdf.error.log` | warn+ |
| Container nginx access | `nginx-logs:/var/log/nginx/access.log` | shib custom |
| Container nginx stats | `nginx-logs:/var/log/nginx/stats.log` | JSON (per Shib request) |
| shibd | `nginx-logs:/var/log/shibboleth/shibd.log` | INFO+ |
| shibd transaction | `nginx-logs:/var/log/shibboleth/transaction.log` | login events |
| stats-api | `docker logs ulakpdf-stats-api` | uvicorn access |

## Logları okuma

### Live tail (tüm servisler)

```bash
cd /opt/spdf
docker compose -f deploy/docker-compose.prod.yml --env-file .env logs -f --tail 100
```

### Yalnızca SAML olayları

```bash
docker exec ulakpdf-nginx-shib tail -f /var/log/shibboleth/transaction.log
```

Her giriş bir satır:
```
2026-05-13 09:14:56|Shibboleth-TRANSACTION.Login||<sessionId>|<idpEntityId>|...|...|<userAgent>|<remoteAddr>
```

### Hata ayıklama (shibd)

```bash
docker exec ulakpdf-nginx-shib tail -100 /var/log/shibboleth/shibd.log \
    | grep -iE 'warn|error|crit'
```

### Stats JSON akışı

```bash
docker exec ulakpdf-nginx-shib tail -f /var/log/nginx/stats.log
```

Her satır bir JSON kayıt:

```json
{"ts":"2026-05-13T09:15:01+00:00","ip":"...","eppn":"ali@kurum.tr",
 "mail":"ali@kurum.tr","affil":"faculty","method":"GET",
 "uri":"/pdf-merge-split","status":200,"bytes":18059,"ua":"..."}
```

### Host nginx erişim

```bash
sudo tail -f /var/log/nginx/ulakpdf.access.log
```

## Log rotation

Otomatik:

- **Host nginx logları**: Debian'ın paket-default'u (`/etc/logrotate.d/nginx`)
- **Container nginx + shibd logları**: `install.sh` tarafından kurulan
  `/etc/logrotate.d/ulakpdf` — günlük, 14 gün, gzip

Manuel test:

```bash
sudo logrotate -d /etc/logrotate.d/ulakpdf   # dry-run
sudo logrotate -f /etc/logrotate.d/ulakpdf   # force
```

## Healthcheck'ler

Tüm Docker servislerinin healthcheck'i vardır:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file .env ps
# her satırda Up X (healthy) ya da (unhealthy) görünür
```

Hızlı manuel kontroller:

```bash
# Genel canlılık
curl -fsS https://<sunucunuz>/ -o /dev/null -w '%{http_code}\n'

# SP metadata serve ediliyor mu
curl -fsS https://<sunucunuz>/Shibboleth.sso/Metadata | head -3

# stats-api healthz
docker exec ulakpdf-stats-api curl -fsS http://localhost:8000/api/healthz
```

## Prometheus / dış izleme (opsiyonel)

Resmi bir metrics endpoint yok. Basit izleme için:

- **Uptime**: UptimeRobot, BetterStack, kuruma ait monitoring sistemi —
  `https://<sunucunuz>/Shibboleth.sso/Metadata` üzerine 1-5 dk aralıklı
  GET. 200 dönmüyorsa uyarı.
- **Disk**: `df -h /var/lib/docker /var/log` haftalık kontrol.
- **Sertifika**: `certbot certificates` çıktısı; veya
  `openssl s_client -connect <host>:443 </dev/null 2>/dev/null \
   | openssl x509 -noout -enddate`.

Daha gelişmiş senaryoda nginx exporter, node_exporter ve Prometheus
kurulabilir; `/var/log/nginx/stats.log` JSON-formatlı olduğu için
Promtail/Loki ile satır bazında ingest etmek de seçenek.

## Disk büyümesi

| Kaynak | Tipik büyüme |
|---|---|
| nginx access log | ~200 byte/istek |
| stats.log (JSON) | ~250 byte/Shib istek |
| shibd transaction log | ~400 byte/login |
| stats SQLite | ~200 byte/istek |
| Docker image katmanları | İlk derleme ~1 GB; sonra delta |

10 bin günlük istekte stats DB ~2 MB/gün, 1 yılda ~750 MB. Periyodik
prune için bkz. [Yönetici paneli](../kullanim/yonetici.md).
