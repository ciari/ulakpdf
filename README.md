# UlakPDF

Yetkim SSO ile korunan, tarayıcıda çalışan kurumsal PDF araç seti.

```
internet → host nginx :443 (TLS) → docker stack :8081 (loopback)
                                       ├─ nginx-shib  (Shibboleth SP)
                                       ├─ bentopdf    (UlakPDF, statik + WASM)
                                       ├─ stats-api   (FastAPI + SQLite)
                                       └─ docs        (mkdocs-material)
                                              ↕
                                       Yetkim IdP (SAML2)
```

PDF dosyaları **sunucuya yüklenmez** — tüm işlem kullanıcının
tarayıcısında WebAssembly ile yapılır. Sunucu kimlik doğrulaması ve
statik içerik servisi dışında bir iş yapmaz.

## Hızlı başlangıç

### Geliştirme / test ortamı (yerel SimpleSAMLphp IdP ile)

```bash
docker compose up -d
# tarayıcıda: http://localhost:8081
# kullanıcı: user1 / user1pass  (veya user2 / user2pass)
```

### Production kurulum

Tam adımlar: [`deploy/README.md`](deploy/README.md) veya kurduktan sonra
`https://<sunucunuz>/docs/kurulum/kurulum/` adresinden.

Özet:

```bash
sudo bash /opt/spdf/deploy/install.sh        # Debian 12 bootstrap
cp deploy/.env.production.example .env       # düzenle: DOMAIN, IDP_*, ADMIN_EPPNS
DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)
sudo bash -c "DOMAIN=$DOMAIN envsubst '\${DOMAIN}' \
    < deploy/nginx-host.conf > /etc/nginx/sites-available/ulakpdf"
sudo ln -sf /etc/nginx/sites-available/ulakpdf /etc/nginx/sites-enabled/ulakpdf
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d "$DOMAIN" --redirect --agree-tos -m sen@kurum.tr
bash /opt/spdf/deploy/deploy.sh              # build + start docker stack
```

## Proje yapısı

| Dizin | İçerik |
|---|---|
| `bentopdf/` | BentoPDF kaynağı + UlakPDF overlay (light tema, marka, toggle) |
| `nginx-shib/` | Custom nginx + nginx-http-shibboleth + shibd (SP) |
| `stats-api/` | FastAPI ile yönetici istatistik API'si |
| `stats-admin/` | Statik admin dashboard (Chart.js) |
| `landing/` | Anonim ziyaretçilere gösterilen UlakPDF karşılama sayfası |
| `docs-site/` | mkdocs-material ile site (kullanıcı + kurulum + ops kılavuzları) |
| `deploy/` | Production kurulum scriptleri ve compose dosyası |
| `idp-config/` | Sadece local test-idp için SimpleSAMLphp config |
| `docker-compose.yml` | Geliştirme/test compose (test-idp dahil) |
| `deploy/docker-compose.prod.yml` | Production compose (test-idp YOK) |

## Dokümantasyon

Stack çalışırken `https://<sunucunuz>/docs/` (veya yerelde
`http://localhost:8081/docs/`) adresinden ulaşılır. mkdocs-material ile
Türkçe yazılmıştır:

- Kullanım kılavuzu (giriş, arayüz, araçlar, yönetici paneli)
- Kurulum adımları (ön hazırlık, kurulum, Yetkim entegrasyonu)
- İşletme & Bakım (loglar, yedekleme, sorun giderme)
- Mimari

Kaynak markdown'lar `docs-site/docs/` altındadır; düzenleyip
`docker compose build docs && docker compose up -d --force-recreate docs`
ile yayınlayabilirsiniz.

## Lisans

UlakPDF, açık kaynaklı bileşenler üzerine inşa edilmiştir:

- [BentoPDF](https://github.com/alam00000/bentopdf) — AGPL-3.0
- Shibboleth SP — Apache 2.0
- nginx, mkdocs-material, FastAPI — kendi lisansları

UlakPDF overlay/yapılandırma kodları AGPL-3.0 lisansı ile sunulmaktadır.
Kaynak kod: <https://github.com/ciari/ulakpdf>
