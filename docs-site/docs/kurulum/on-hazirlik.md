# Ön Hazırlık

UlakPDF'i kurmadan önce aşağıdakileri hazırlamış olmanız gerekir.

## VM özellikleri

Önerilen başlangıç:

| Kaynak | Boyut |
|---|---|
| **vCPU** | 2 |
| **RAM** | 4 GB |
| **Disk** | 30 GB SSD |
| **Bandwidth** | 100 Mbps (CDN ile daha az) |

BentoPDF tüm PDF işlemini tarayıcıda yaptığı için sunucu CPU'su asla
darboğaz olmaz. Asıl maliyet **bant genişliği** (ilk ziyarette ~25–30 MB
WASM indirme). Yoğun kurumlar için Cloudflare ücretsiz tier önerilir.

## Yazılım

| Bileşen | Sürüm | Notlar |
|---|---|---|
| **OS** | Debian 12 (Bookworm) | Diğer dağıtımlar elle uyarlamayla çalışır |
| **Docker** | 24+ | `install.sh` yükler |
| **Docker Compose** | v2.20+ | docker-compose-plugin |
| **Host nginx** | 1.22+ | TLS terminator |
| **certbot** | 2.0+ | Let's Encrypt |

## DNS

- Bir **alt alan adı** (örn. `ulakpdf.example.tr`) hazırlayın.
- A/AAAA kaydı, kuracağınız VM'in IP'sini göstermeli.
- Kayıt yayılana kadar bekleyin (genelde ~5 dk, en kötü 24 saat).

```bash
# Doğrulama
dig +short A ulakpdf.example.tr
# VM IP'si dönmeli
```

## Yetkim hesabı

UlakPDF'i Yetkim federasyonuna **Service Provider (SP)** olarak
tanıtmanız gerekir. Önceden hazırlayın:

| Bilgi | Nereden alınır |
|---|---|
| Yetkim IdP **Entity ID** | Yetkim self-servis portali |
| Yetkim IdP **Metadata URL** | Yetkim self-servis portali |
| (Opsiyonel) Federasyon **signing cert** | Yetkim destek |

SP kaydı için Yetkim'e vereceğiniz bilgi:
- **SP Entity ID**: `https://<sunucunuz>/shibboleth`
- **SP Metadata URL**: `https://<sunucunuz>/Shibboleth.sso/Metadata`

İlk kurulumdan sonra metadata URL'i Yetkim'e iletirsiniz; gerisini Yetkim
otomatik halleder.

!!! warning "Attribute release"
    UlakPDF'in çalışması için Yetkim'in en az `eduPersonPrincipalName`
    (eppn) salması gerekir. Tercihen `mail`, `displayName`, `givenName`,
    `sn`, `eduPersonAffiliation` de istenir. Kurumunuz attribute release
    politikasını sıkı tutuyorsa, yöneticisinden bu attribute'ların
    UlakPDF SP'sine açılmasını isteyin.

## Yönetici eppn listesi

İstatistik panelinde kim yönetici olacak, eppn'lerini şimdiden belirleyin.
Format:

```
ali.veli@bilkent.edu.tr
zeynep.demir@itu.edu.tr
```

Bu liste `.env` dosyasındaki `ADMIN_EPPNS=` değişkenine virgülle ayrılmış
olarak yazılacak.

## E-posta adresi

Certbot Let's Encrypt sertifikasını alırken bir e-posta ister
(renewal uyarıları için). Hazır bulundurun.

## Sonraki adım

Hazırsanız, [Kurulum Adımları](kurulum.md) sayfasına geçin.
