# Kurulum Adımları

[Ön hazırlık](on-hazirlik.md) tamamlandıktan sonra, sırayla:

## 1. Projeyi VM'e kopyala

Yerel makinenizden veya bir git deposundan `/opt/spdf` altına kopyalayın.

```bash
# Yerel klondan
sudo mkdir -p /opt/spdf
sudo chown $USER /opt/spdf
rsync -av --delete ./ root@VM:/opt/spdf/
```

veya:

```bash
# Git deposundan
sudo git clone <repo-url> /opt/spdf
```

## 2. Sistem bootstrap

VM üzerinde root olarak:

```bash
sudo bash /opt/spdf/deploy/install.sh
```

Yapılanlar:

- Docker engine ve docker-compose-plugin
- nginx + certbot + python3-certbot-nginx
- UFW (22, 80, 443 açık; gerisi kapalı)
- logrotate kuralları (`/etc/logrotate.d/ulakpdf`)
- ACME challenge için `/var/www/letsencrypt`

Script idempotenttir; tekrar çalıştırmak güvenli.

## 3. `.env` dosyasını doldur

```bash
cd /opt/spdf
cp deploy/.env.production.example .env
$EDITOR .env
```

Doldurulması zorunlu alanlar:

| Anahtar | Örnek | Açıklama |
|---|---|---|
| `DOMAIN` | `ulakpdf.kurum.tr` | Public hostname |
| `IDP_ENTITY_ID` | `https://idp.yetkim.gov.tr/idp/shibboleth` | Yetkim IdP entity ID |
| `IDP_METADATA_URL` | aynı veya alternatif | shibd metadata fetch URL |
| `ADMIN_EPPNS` | `ali@kurum.tr,zeynep@kurum.tr` | Yönetici eppn listesi |
| `SUPPORT_CONTACT` | `destek@kurum.tr` | Shib hata sayfasında gösterilir |
| `VITE_BRAND_NAME` | `UlakPDF` | Logo/footer markası |
| `VITE_FOOTER_TEXT` | `© 2026 ...` | Footer metni |

## 4. Host nginx site'ı oluştur

```bash
cd /opt/spdf
DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)

sudo bash -c "DOMAIN=$DOMAIN envsubst '\${DOMAIN}' \
    < deploy/nginx-host.conf \
    > /etc/nginx/sites-available/ulakpdf"

sudo ln -sf /etc/nginx/sites-available/ulakpdf /etc/nginx/sites-enabled/ulakpdf
sudo nginx -t
sudo systemctl reload nginx
```

Bu noktada port 80, HTTPS'e yönlendirme yapan ama henüz HTTPS dinlemeyen
bir konfigürasyon servisindedir.

## 5. TLS sertifikasını al

```bash
sudo certbot --nginx \
    -d "$DOMAIN" \
    --redirect \
    --agree-tos \
    -m destek@kurum.tr   # kendi e-postanız
```

Certbot:
- Let's Encrypt'ten sertifika alır
- `/etc/nginx/sites-available/ulakpdf` dosyasını otomatik düzenler
  (`ssl_certificate` satırlarını ekler)
- nginx'i yeniden yükler
- Otomatik yenileme için `certbot.timer` systemd timer'ını kurar

Yenileme durumunu kontrol:

```bash
sudo systemctl status certbot.timer
sudo certbot certificates
```

## 6. Docker stack'i ayağa kaldır

```bash
bash /opt/spdf/deploy/deploy.sh
```

Yapılanlar:

- `bentopdf` (UlakPDF markalı build), `nginx-shib`, `stats-api`,
  `docs` imajları derlenir
- Tüm servisler başlatılır
- `nginx-shib` healthy olana kadar bekler
- SP metadata URL'i ekrana yazılır

İlk derleme ~5 dakika sürer (BentoPDF npm install + Vite build, nginx
kaynaktan derlenir).

## 7. SP metadata'sını Yetkim'e gönder

```bash
echo "https://$DOMAIN/Shibboleth.sso/Metadata"
# Veya statik kopya
curl -fsSL "https://$DOMAIN/Shibboleth.sso/Metadata" > ulakpdf-sp-metadata.xml
```

URL'i Yetkim self-servis portaline veya destek ekibine iletin. Bkz.
[Yetkim entegrasyonu](yetkim.md).

## 8. Duman testi

Tarayıcıda `https://<sunucunuz>/`:

- [ ] HTTP → HTTPS yönlenmesi çalışıyor
- [ ] Anonim ziyarette UlakPDF karşılama sayfası geliyor
- [ ] **Yetkim SSO** düğmesi → kurum seçim → giriş → BentoPDF açılıyor
- [ ] Sağ üstte eppn'iniz ve **Çıkış** düğmesi var
- [ ] Tema düğmesi çalışıyor (aydınlık/karanlık)
- [ ] `/docs/` adresinden bu dokümantasyona erişebiliyorsunuz
- [ ] (Yöneticiyseniz) `/stats/` panelden veri görüyorsunuz

## 9. (Opsiyonel) Sıkı IdP doğrulaması

Yetkim metadata'sının imzasını doğrulamak için (kesinlikle önerilir):

1. Yetkim federasyon signing sertifikasını edinin.
2. `nginx-shib/shibboleth/federation-cert.pem` olarak kaydedin.
3. `nginx-shib/shibboleth/shibboleth2.xml` içindeki `<MetadataProvider>`'a
   filter ekleyin:
   ```xml
   <MetadataFilter type="Signature" certificate="federation-cert.pem"/>
   <MetadataFilter type="RequireValidUntil" maxValidityInterval="2419200"/>
   ```
4. Yeniden derleyip başlatın:
   ```bash
   bash /opt/spdf/deploy/deploy.sh
   ```

## Tamamlandı 🎉

Sıkıntı çıkarsa [sorun giderme](../bakim/sorun-giderme.md) sayfasına bakın.
