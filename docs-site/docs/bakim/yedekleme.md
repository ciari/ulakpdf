# Yedekleme

## Yedeklenmesi gerekenler

| Veri | Konum | Kayıp halinde sonuç |
|---|---|---|
| **SP keypair** | `ulakpdf_shib-state` named volume | Yetkim'e yeniden SP register etmek zorunda kalırsınız |
| **Stats DB** | `ulakpdf_stats-db` named volume | Geçmiş istatistikler kaybolur (yeni veri toplar) |
| **`.env`** | `/opt/spdf/.env` | Kurulumu yeniden yapılandırmak gerekir |
| **`shibboleth2.xml` özelleştirmeleri** | `/opt/spdf/nginx-shib/shibboleth/` | Custom MetadataFilter vb. kaybolur |
| **TLS sertifikası** | `/etc/letsencrypt/` | certbot 90 günde bir yeni alır; backup gerekmez |

## Tek komut yedekleme

```bash
#!/usr/bin/env bash
# /usr/local/sbin/ulakpdf-backup.sh
set -euo pipefail

BACKUP_DIR=/backups/ulakpdf
DATE=$(date +%F)
mkdir -p "$BACKUP_DIR"

# 1. Named volumes
for vol in shib-state stats-db; do
    docker run --rm \
        -v "ulakpdf_${vol}:/data:ro" \
        -v "$BACKUP_DIR:/backup" \
        alpine tar czf "/backup/${vol}-${DATE}.tar.gz" -C /data .
done

# 2. Konfigürasyon
tar czf "$BACKUP_DIR/config-${DATE}.tar.gz" \
    /opt/spdf/.env \
    /opt/spdf/nginx-shib/shibboleth/ \
    /opt/spdf/landing/ \
    /etc/nginx/sites-available/ulakpdf

# 3. Eski yedekleri budayın (30 günden eski)
find "$BACKUP_DIR" -name '*.tar.gz' -mtime +30 -delete

echo "[backup] tamamlandı: $BACKUP_DIR/*-${DATE}.tar.gz"
```

Cron'a ekleyin:

```bash
sudo install -m 700 /opt/spdf/scripts/ulakpdf-backup.sh /usr/local/sbin/
sudo crontab -e
# Her gece 03:30
30 3 * * * /usr/local/sbin/ulakpdf-backup.sh > /var/log/ulakpdf-backup.log 2>&1
```

## Off-host saklama

Yerel diske yedek almak yetmez — VM çökerse her şey gider. Önerilen:

- **rclone** ile S3/MinIO/Backblaze B2'ye senkronize edin
- **rsync** ile başka bir sunucuya
- Kurum policy'sine uygun bir merkezi backup ürünü

Örnek `rclone` ile:

```bash
rclone sync /backups/ulakpdf remote:ulakpdf-backups/$(hostname)
```

## Geri yükleme

### SP keypair geri yükleme

```bash
docker compose -f /opt/spdf/deploy/docker-compose.prod.yml \
    --env-file /opt/spdf/.env stop nginx-shib

docker run --rm \
    -v ulakpdf_shib-state:/data \
    -v $(pwd):/backup \
    alpine sh -c 'rm -rf /data/* && tar xzf /backup/shib-state-2026-05-13.tar.gz -C /data'

docker compose -f /opt/spdf/deploy/docker-compose.prod.yml \
    --env-file /opt/spdf/.env start nginx-shib
```

### Stats DB geri yükleme

```bash
docker compose -f /opt/spdf/deploy/docker-compose.prod.yml \
    --env-file /opt/spdf/.env stop stats-api

docker run --rm \
    -v ulakpdf_stats-db:/data \
    -v $(pwd):/backup \
    alpine sh -c 'rm -rf /data/* && tar xzf /backup/stats-db-2026-05-13.tar.gz -C /data'

docker compose -f /opt/spdf/deploy/docker-compose.prod.yml \
    --env-file /opt/spdf/.env start stats-api
```

### Tam felaket kurtarma

Yeni bir VM hazırladığınızı varsayalım:

1. [Kurulum](../kurulum/kurulum.md) adımlarını izleyin (yedeklediğiniz `.env`'i
   ve özel `shibboleth2.xml`'i kullanın)
2. **Stack'i başlatmadan önce** SP keypair yedeğini geri yükleyin
   (yukarıdaki adımlarla `shib-state` volume'unu doldurun)
3. Stats DB yedeğini de geri yükleyin
4. `bash deploy/deploy.sh` ile başlatın
5. DNS'i yeni VM IP'sine yönlendirin (eski VM hâlâ ayaktaysa kapatın)

Not: SP keypair değişmediği için Yetkim tarafında bir şey yapmanız
gerekmez — aynı SP olarak tanınırsınız.

## Sertifika yedeği (opsiyonel)

certbot sertifikalarını `/etc/letsencrypt`'te tutar. Kayıp halinde
yeniden alınabilir (90 gün geçerli, otomatik yenilenir), ama acil
durumda kullanmak için yedek almak fena fikir değil:

```bash
sudo tar czf /backups/letsencrypt-$(date +%F).tar.gz \
    /etc/letsencrypt/live /etc/letsencrypt/archive /etc/letsencrypt/renewal
```
