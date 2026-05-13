# Yönetici Paneli

`https://<sunucu>/stats/` adresinde, yalnızca `ADMIN_EPPNS` listesindeki
eppn'lerin erişebildiği özet panel bulunur.

## Erişim

1. Standart Yetkim girişi yapın.
2. Eğer eppn'iniz `ADMIN_EPPNS` ortam değişkenindeki listedeyse `/stats/`
   açılır; değilse "Yetkisiz" sayfası görürsünüz.
3. Liste virgülle ayrılır, büyük/küçük harf duyarsızdır:
   `ADMIN_EPPNS=ali.veli@kurum.tr,zeynep.demir@kurum.tr`

Liste değişikliği yalnızca `.env` düzenlemesi + `docker compose
restart stats-api` ile uygulanır.

## Panelde gösterilenler

### KPI'lar (üst satır)

- **Toplam İstek** — seçili tarih aralığında tüm istek sayısı
- **Tekil Kullanıcı** — eppn bazında benzersiz sayı
- **Kurum** — eppn domain'i bazında benzersiz kurum sayısı
- **Kullanıcı-Gün** — (gün × kullanıcı) çiftleri; aktiflik göstergesi

### Grafikler

- **Zaman çizelgesi (günlük)** — istek + kullanıcı eğrisi
- **Kuruma göre kullanıcı** — donut grafik, eppn domain bazında dağılım
- **Açılan araç sayfaları** — en çok ziyaret edilen araç sayfaları (yatay bar)
- **Son etkinlik** — en yeni 50 istek (zaman, kullanıcı, kurum, URI, durum)

### Detay tablosu

Kuruma göre kullanıcı/istek sayıları ayrıntılı listelenir.

## Tarih aralığı

Sağ üstteki **Aralık** açılır menüsünden:
- Bugün
- Son 7 gün
- Son 30 gün (varsayılan)
- Son 90 gün

## Veri kaynağı ve sınırlar

UlakPDF'in tüm dosya işleme **tarayıcıda** olduğu için sunucu
şunları **bilmez**:
- Hangi dosya işlendi
- Dosya boyutu / sayfa sayısı
- İşlemin başarılı olup olmadığı

Sunucu yalnızca **HTTP isteklerini** loglar — yani:
- Hangi kullanıcı, hangi araç sayfasını açtı (kullanım niyeti göstergesi)
- Hangi statik kaynak indirildi (WASM modül = hangi yetenek yüklendi)

İstatistikler bu HTTP loglarından üretilir.

## Veri saklama ve silme

- Olaylar `stats-db` adlı Docker named volume'unda SQLite içinde tutulur.
- Otomatik bir saklama politikası **yoktur**; istediğiniz aralıkta veri
  silmek için yöneticilik komutları:

```bash
# 90 günden eski olayları sil
docker exec ulakpdf-stats-api python -c "
import sqlite3
c = sqlite3.connect('/data/stats.sqlite')
c.execute(\"DELETE FROM events WHERE day < date('now', '-90 days')\")
c.commit()
c.execute('VACUUM')
"
```

Tam temizleme:
```bash
docker exec ulakpdf-stats-api rm /data/stats.sqlite
docker compose -f deploy/docker-compose.prod.yml restart stats-api
```

## API erişimi

Panel JS'i şu uç noktaları kullanır (yönetici Shibboleth oturumu gerekir):

| Uç nokta | Açıklama |
|---|---|
| `GET /stats/api/summary?days=30` | KPI verileri |
| `GET /stats/api/by-institution?days=30` | Kurum bazında dağılım |
| `GET /stats/api/by-tool?days=30` | En çok kullanılan araçlar |
| `GET /stats/api/timeline?days=14` | Günlük seri |
| `GET /stats/api/recent?limit=50` | Son etkinlik |
| `GET /stats/api/admins` | Mevcut yönetici listesi |

Yetkim attribute release'i kurumlara göre değişebilir; bazı kurumlar
`affil` (rol bilgisi) göndermeyebilir. Bu durumda ilgili sütun boş
gözükür.
