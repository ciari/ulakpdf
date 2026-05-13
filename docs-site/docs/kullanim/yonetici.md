# Yönetici Paneli

Eğer yöneticilik yetkisi tanımlanmış bir kullanıcıysanız,
`https://<sunucunuz>/stats/` adresinden kullanım istatistiklerini
görebilirsiniz.

!!! note "Yönetici miyim?"
    Yöneticiler kurum yöneticisi tarafından önceden eklenir. Eğer
    `/stats/` sayfasını açtığınızda **"Yetkisiz"** mesajı görüyorsanız,
    yöneticilik yetkiniz yok demektir. Yetki almak için sistem
    yöneticisine başvurun.

## Erişim

1. UlakPDF'e Yetkim hesabınızla [normal giriş](giris.md) yapın.
2. Tarayıcı adres çubuğuna `/stats/` ekleyin (örn.
   `https://ulakpdf.tr/stats/`).
3. Yöneticiyseniz panel açılır; değilseniz "Yetkisiz" sayfası görürsünüz.

## Panelde neler var

### Üst KPI'lar

Seçili tarih aralığında özet sayılar:

- **Toplam İstek** — UlakPDF'e gelen tüm istek sayısı
- **Tekil Kullanıcı** — kullanıcı (eppn) bazında benzersiz sayı
- **Kurum** — kuruma (eppn domain'i) göre benzersiz sayı
- **Kullanıcı-Gün** — aktiflik göstergesi: (gün × kullanıcı) çiftleri

### Grafikler

- **Zaman çizelgesi** — günlük istek + kullanıcı eğrisi
- **Kuruma göre kullanıcı** — donut grafik, eppn domain bazında dağılım
- **Açılan araç sayfaları** — en çok ziyaret edilen araçlar
- **Son etkinlik** — en yeni 50 istek (zaman, kullanıcı, kurum, URI)
- **Kuruma göre detay tablo** — kurum bazında tekil kullanıcı + istek
  sayıları

### Tarih aralığı

Sağ üstteki **Aralık** açılır menüsünden:

- Bugün
- Son 7 gün
- Son 30 gün (varsayılan)
- Son 90 gün

Veriler 30 saniyede bir otomatik yenilenir.

## Bunlar göstermez

UlakPDF'in tasarım gereği **dosyalar sunucuya yüklenmez** — bütün PDF
işleme tarayıcıda olur. Bu yüzden istatistikler şunları **görmez**:

- Hangi PDF dosyası işlendi (içerik, ad, boyut)
- İşlemin başarılı veya başarısız olduğu
- Kullanıcının hangi aracı seçtikten sonra ne yaptığı

Sunucu sadece **HTTP isteklerini** kaydeder:

- Kim (eppn) ne zaman hangi araç sayfasını açtı
- Hangi statik kaynak indirildi (örn. OCR modülü = OCR yapılma niyeti)

Bu, sunucu tarafında dosya gizliliğini koruyan tasarım kararının
doğal sonucudur.

## Sıkça sorulanlar

**Bir kullanıcı sayısı düştü, neden?**
Aynı kullanıcı aynı gün içinde birden çok kez girse bile bir kez
sayılır (tekil eppn). Düşüş genelde gerçek kullanım azalmasıdır,
veri kaybı değildir.

**Geçmiş veri ne kadar saklanır?**
Varsayılan olarak süresiz. Kurum politikasına göre periyodik olarak
budanır. Detay için bilgi işlem yöneticinize başvurun.

**Kurum listesinde benim kurumum yok**
Kurumunuzun kullanıcısı henüz UlakPDF'e giriş yapmamış olabilir.
İlk girişten sonra otomatik eklenir.

**"Affil" sütunu boş gözüküyor**
Kurumun IdP'si `eduPersonAffiliation` attribute'ını release etmiyor
olabilir; kurumun bilgi işlem birimine bildirin.
