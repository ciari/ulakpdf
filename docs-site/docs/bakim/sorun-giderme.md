# Sorun Giderme

## Tanı sırası

Bir sorun bildirildiğinde, baştan sona şu sırayla bakın:

1. `docker compose ... ps` — tüm servisler healthy mi?
2. `docker logs ulakpdf-nginx-shib` — son hata var mı?
3. Tarayıcıda DevTools Network sekmesi — hangi istek başarısız?
4. shibd `transaction.log` — kullanıcının login eventı geldi mi?
5. nginx `stats.log` — istek nginx'e ulaştı mı?

## Yaygın sorunlar

### "Bu siteye ulaşılamıyor" / "Connection refused"

| Olası neden | Doğrulama | Çözüm |
|---|---|---|
| Host nginx çalışmıyor | `systemctl status nginx` | `systemctl restart nginx` |
| Docker stack çalışmıyor | `docker compose ps` | `bash deploy/deploy.sh` |
| Firewall engelliyor | `ufw status` | `ufw allow 443/tcp` |
| DNS yanlış | `dig +short A <domain>` | A kaydını düzelt |

### TLS sertifika hatası

```bash
sudo certbot certificates
```

| Görüntü | Anlam | Çözüm |
|---|---|---|
| Cert görünmüyor | Hiç alınmamış | `sudo certbot --nginx -d <domain>` |
| "Expires in 5 days" | Otomatik yenilenmedi | `sudo certbot renew` |
| "Domain doesn't match" | Yanlış SAN | Yeni cert: `sudo certbot --nginx -d <doğru>` |

### Yetkim'e yönlendiriyor ama dönüş başarısız

shibd transaction log'unda **Login** satırı gözükmeli. Görünmüyorsa
SAML response geri ulaşmamış.

```bash
docker exec ulakpdf-nginx-shib tail -50 /var/log/shibboleth/shibd.log
```

Olası nedenler:
- Yetkim tarafında SP henüz aktive edilmemiş
- Federasyon metadata'sı henüz yenilenmemiş (Yetkim 24 saate kadar bekleyebilir)
- ACS URL Yetkim'e yanlış kayıtlı (HTTP yerine HTTPS olmalı, port belirtilmemeli)

### Login başarılı ama "Yetkisiz" gözüküyor

Kullanıcı sayfayı görüyor ama `/stats/` 403 dönüyor.

Sebep: `ADMIN_EPPNS` listesinde değil.

```bash
# Kullanıcının eppn'i ne?
docker exec ulakpdf-nginx-shib tail /var/log/nginx/stats.log | jq -r '.eppn' | sort -u

# Listede var mı?
grep ADMIN_EPPNS /opt/spdf/.env
```

Ekleyip restart:

```bash
$EDITOR /opt/spdf/.env
# ADMIN_EPPNS=ali@kurum.tr,zeynep@kurum.tr,yenikullanici@kurum.tr
cd /opt/spdf
docker compose -f deploy/docker-compose.prod.yml --env-file .env restart stats-api
```

### "no values left, removing attribute" — eppn boş geliyor

shibd loglarında:

```
WARN Shibboleth.AttributeFilter: no values left, removing attribute (eppn)
```

Sebep: Yetkim attribute'ı bekleneni aşan bir formatta sallıyor (örn.
scope kontrolü başarısız, name format eşleşmiyor).

Test/sandbox IdP için zaten gevşek bir `attribute-policy.xml` ile
çalışıyoruz (bkz. `nginx-shib/shibboleth/attribute-policy.xml`).
Production'da Yetkim normalde scoped attribute gönderir; politika
problem çıkarmaz. Çıkarsa, log'daki tam hata mesajına göre rule
güncellemesi gerekir.

### URL'ler `http://_/...` veya yanlış port

Sebep: shibresponder `SHIBSP_SERVER_*` env değerlerini OS env'inden okur
ve bu değerler entrypoint'te `SP_BASE_URL`'den türetilir. `.env`'de
`SP_BASE_URL` yanlışsa metadata'daki ACS URL hatalı çıkar.

```bash
docker logs ulakpdf-nginx-shib | grep SHIBSP_SERVER
# [entrypoint] SHIBSP_SERVER_NAME=ulakpdf.kurum.tr SCHEME=https PORT=443
```

Yanlışsa `.env`'i düzeltip `bash deploy/deploy.sh` ile yeniden derle.

### nginx-shib boot loop'ta

```bash
docker logs --tail 50 ulakpdf-nginx-shib
```

Yaygın hatalar:

- `host not found in upstream "bentopdf:8080"` — variable-based proxy_pass
  kullandığımızdan beri görünmemeli; görünüyorsa nginx imajı bayat,
  rebuild edin.
- `shibd died on startup` — `IDP_METADATA_URL` erişilemiyor + yedek
  metadata file yok. `WAIT_FOR_IDP=1` ile çalıştırırsanız ilk boot'ta
  bekler. Production'da `0` set ettik; ilk boot'ta IdP unreachable
  olursa shibd start oluyor ama metadata cache'i boş kalıyor — hatayı
  shibd.log'da görürsünüz.

### Tarayıcıda her tıklamada login isteniyor

Sebep: `_shibsession_*` çerezi tarayıcıda saklanmıyor.

Olası nedenler:
- Tarayıcı third-party çerezleri engellemiş — kontrol edin
- Tarayıcının tracking protection ayarları bizim domain'i engellemiş
- HTTPS değil HTTP'te erişim deneniyor (SameSite/Secure çerezi düşer)
- HSTS ayarı yanlış: bir kez HTTPS gördüyse tarayıcı HTTP'ye dönmez,
  ama "doğru" HTTPS'i engelliyorsa erişim kopabilir

### Disk doldu

```bash
df -h
docker system df
```

| Doluluk kaynağı | Çözüm |
|---|---|
| Eski Docker imaj/layer | `docker system prune -a` |
| Stats SQLite çok büyüdü | Bkz. [Yönetici paneli](../kullanim/yonetici.md) → veri silme |
| Container nginx logları | `logrotate` çalışıyor mu? `sudo logrotate -f /etc/logrotate.d/ulakpdf` |
| `/var/log/journal/` | `sudo journalctl --vacuum-time=14d` |

## Hızlı reset

Bir şey çok bozulmuşsa, veriyi koruyarak servisleri yeniden başlatın:

```bash
cd /opt/spdf
docker compose -f deploy/docker-compose.prod.yml --env-file .env down
docker compose -f deploy/docker-compose.prod.yml --env-file .env up -d
```

Tam temiz başlangıç (SP keypair YEDEKLEDİĞİNİZE EMİN OLUN — değişirse
Yetkim'e yeniden register lazım):

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file .env down -v
bash deploy/deploy.sh
```

`-v` named volume'ları siler; SP anahtarları, stats verisi gider.

## Daha fazla yardım

| Belirti | Bak |
|---|---|
| Log konumları | [Loglar ve İzleme](loglar.md) |
| Yedek geri yükleme | [Yedekleme](yedekleme.md) |
| Yetkim kaynaklı | [Yetkim entegrasyonu](../kurulum/yetkim.md) |
