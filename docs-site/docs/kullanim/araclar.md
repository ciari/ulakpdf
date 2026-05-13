# PDF Araçları

UlakPDF, BentoPDF üzerine inşa edilmiştir; 80+ PDF aracı tarayıcıda
çalışır. Aşağıda en çok kullanılan kategoriler gösterilmiştir.

## Düzenleme & Sayfa Yönetimi

| Araç | Ne işe yarar |
|---|---|
| **Birleştir (Merge)** | Birden çok PDF'i tek dosyaya birleştirir. Yer imleri korunur. |
| **Böl (Split)** | Belirli sayfaları çıkarır, dosyayı parçalara ayırır. |
| **Sayfa Düzenle** | Sürükle-bırak ile sayfa sıralama, silme, çoğaltma. |
| **Çıkar (Extract)** | Bir sayfa aralığını yeni PDF olarak kaydeder. |
| **Sil** | İstenmeyen sayfaları kaldırır. |
| **Döndür** | Tek sayfa veya tüm sayfaları döndürür. |
| **Boş Sayfa Ekle** | İstediğiniz konuma boş sayfa ekler. |
| **Ters Çevir** | Sayfa sırasını ters çevirir. |
| **N-up** | Birden çok sayfayı tek sayfada birleştirir (kitapçık). |

## Dönüştürme

| Kaynak → Hedef | |
|---|---|
| **Word/Excel/PowerPoint → PDF** | DOCX, XLSX, PPTX ve eski formatlar |
| **Görsel → PDF** | JPG, PNG, BMP, GIF, TIFF, HEIC, WebP, SVG, PSD |
| **E-kitap → PDF** | EPUB, MOBI, FB2, CBZ |
| **Markdown → PDF** | Yazıp veya yapıştırıp anında PDF |
| **PDF → Görsel** | PDF'i JPG/PNG'ye çevirir |
| **PDF → Word** | Düzenlenebilir Word çıktısı |

## Düzenleyici (PDF Editor)

Tek bir araçta:

- Metin notu ekleme, vurgulama (highlight)
- Şekil, ok, kutu çizme
- İmza ekleme (çizim, görsel, sertifika)
- Karartma (redact) — kalıcı silme
- Yorum ekleme

## Form

- **Form Oluştur**: Metin alanı, onay kutusu, açılır liste, imza alanı
- **Form Doldur**: Mevcut formları tarayıcıda doldur

## Güvenlik

| Araç | |
|---|---|
| **Şifreleme** | Parola ile koruma (AES-128/256) |
| **Şifre Kaldır** | Bilinen parolayı temizleme |
| **İmza Doğrulama** | Dijital imza kontrolü |
| **Sertifika ile İmzalama** | RFC 3161 zaman damgası destekli |

## Optimizasyon

- **Sıkıştır**: Boyut küçültme (kalite seviyesi seçilebilir)
- **OCR**: Taranmış belgeyi metin tabanlı PDF'e çevirir (Tesseract WASM)
- **Bates Numaralama**: Hukuki belgelerde sayfa numaralandırma
- **Filigran (Watermark)**: Metin veya görsel filigran

## Otomasyon

- **PDF İş Akışı (Workflow Builder)**: Görsel düğüm editörü ile
  zincirleme işlem (örn. birleştir → sıkıştır → filigran ekle)

!!! note "Tam liste"
    Ana sayfadaki arama kutusuna anahtar kelime girerek aracın hangi
    isimle listelendiğini bulabilirsiniz. Toplam ~80 araç vardır.

## Performans ipuçları

| Senaryo | Öneri |
|---|---|
| Çok büyük (200MB+) PDF | Tarayıcı belleğini artırın; gereksiz sekmeleri kapatın |
| OCR yavaş çalışıyor | OCR ilk kullanımda dil paketi indirir; sonraki çalıştırmalar hızlıdır |
| Excel → PDF beklenenden farklı | Karmaşık makrolar/grafikler için sunucu tarafı dönüştürücü gerekir; bu sürümde yoktur |

## Çevrimdışı kullanım

İlk yüklemeden sonra büyük WASM modülleri tarayıcıda önbelleğe alınır;
bağlantınız kopsa bile çoğu işlem çalışmaya devam eder. (Ancak yeni
oturum açmak için Yetkim'e bağlantı gerekir.)
