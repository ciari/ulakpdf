# Arayüz

UlakPDF'in arayüzü, BentoPDF üzerine UlakPDF markası ve Ulakbim
kurumsal teması işlenerek elde edilmiştir.

## Üst Çubuk

| Öğe | Açıklama |
|---|---|
| **UlakPDF** logosu (sol) | Anasayfaya döner |
| Tema düğmesi (ay/güneş ikonu) | Aydınlık ↔ karanlık tema; tercih tarayıcıda saklanır |
| eppn / e-posta | Giriş yapan kullanıcının kimliği |
| **Çıkış** | Oturumu sonlandırır |

## Tema

İki tema mevcuttur:

- **Aydınlık**: Ulakbim mavisi accent'ı, beyaz panel
- **Karanlık**: koyu lacivert arka plan, açık mavi accent

Tema seçiminiz `localStorage` içinde tutulur ve UlakPDF içindeki tüm
sayfalarda (karşılama, araçlar, dokümantasyon, yönetici paneli) ortak
çalışır. İlk ziyarette işletim sistemi tercihiniz otomatik algılanır.

## Arama ve gezinme

Anasayfada bir **arama kutusu** vardır: "split", "düzenle", "sıkıştır"
gibi anahtar kelimelerle aracı hızlıca bulabilirsiniz.

Tüm araçlar tek bir grid içinde listelenir; bir araca tıkladığınızda o
araç penceresi açılır ve dosyalarınızı yükleyebilirsiniz.

## Dosya gizliliği

Yüklediğiniz dosyalar **sunucuya gönderilmez**. Dosya seçer seçmez
tarayıcı belleğine alınır, WebAssembly modülleriyle yerinde işlenir,
sonuç tarayıcıda hazırlanıp size indirme olarak sunulur.

!!! tip "Tarayıcı belleği"
    Çok büyük PDF'ler (örn. 500MB+) tarayıcı sekmesinin RAM kullanımını
    artırır. Sayfayı yenilemek veya kapatmak belleği serbest bırakır.
    Sunucu hiçbir kayıt tutmaz.

## Yetkilerinize göre değişen şeyler

- Standart kullanıcı: tüm PDF araçlarını kullanabilir.
- Yönetici (`ADMIN_EPPNS` listesindeki eppn'ler): aynı araçlara ek
  olarak `/stats/` adresinden [yönetici panelini](yonetici.md) görür.
