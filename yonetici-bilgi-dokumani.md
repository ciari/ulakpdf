# UlakPDF — Yönetici Bilgi Dokümanı

**Hazırlayan:** ULAKBİM Bulut Birimi
**Tarih:** Haziran 2026
**Versiyon:** 1.0
**Hedef Kitle:** ULAKBİM yöneticileri, TÜBİTAK paydaşları, BTYK temsilcileri

---

## 1. Genel Bakış

### 1.1 UlakPDF Nedir?

**UlakPDF**, TÜBİTAK ULAKBİM tarafından akademik ve idari kullanıcılara
sunulan, **tarayıcıda çalışan** kurumsal bir PDF araç setidir. Adobe
Acrobat gibi ücretli yazılımlara veya güvenilirliği şüpheli online
hizmetlere alternatif olarak konumlanmıştır.

### 1.2 Neden Geliştirildi?

| İhtiyaç | UlakPDF'in Sunduğu Çözüm |
|---|---|
| **Lisans maliyeti** — Adobe Acrobat Pro ~5.500₺/kullanıcı/yıl | Tamamen ücretsiz, sınırsız kullanıcı |
| **Veri sızıntısı riski** — online PDF servisleri belgeleri sunucularına yüklüyor | Dosyalar **tarayıcıdan asla çıkmaz** (WebAssembly) |
| **Kurum dışı bağımlılık** — yabancı şirketlerin servisleri ULAKNET dışı | %100 ULAKBİM altyapısında, ULAKNET üzerinden |
| **KVKK uyumsuzluğu** — yurt dışı hizmetlerde veri egemenliği belirsiz | Tüm veri TÜBİTAK altyapısında, açık rıza ile |
| **Tek imza ihtiyacı** — her servise ayrı parola | Yetkim SSO ile tek tıkla giriş |

### 1.3 Hizmet Kapsamı

- **80+ PDF aracı**: birleştir, böl, dönüştür, OCR, imzala, form oluştur/doldur, sıkıştır, watermark, redact, vd.
- **Çok formatlı dönüşüm**: Word, Excel, PowerPoint, görsel, e-kitap → PDF (ve tersi)
- **Aydınlık/karanlık tema** ve **Türkçe arayüz**
- **Mobil ve masaüstü uyumlu** (responsive)

### 1.4 Hedef Kitle

Birinci aşama: ULAKBİM içi kullanım (pilot)
İkinci aşama: TÜBİTAK çatısı altındaki tüm enstitüler
Üçüncü aşama: YETKİM federasyonu üzerinden **tüm Türk akademik
camiası** (181+ üye kurum, ~yüz binlerce potansiyel kullanıcı)

---

## 2. Teknik Altyapı

### 2.1 Yığın (Stack)

```
İnternet → Host nginx + Let's Encrypt (TLS)
              ↓
          Docker stack (tek VM, 127.0.0.1 bağlı)
              ├── nginx-shib   — Shibboleth SP, kapı bekçisi
              ├── bentopdf     — Statik + WASM, PDF araçları
              ├── stats-api    — FastAPI + SQLite, kullanım istatistikleri
              └── docs         — mkdocs-material, kullanıcı dokümantasyonu
              ↓
          YETKİM federasyon IdP'leri (SAML2)
```

Tüm bileşenler **Docker container'larında** izole çalışır. Tek bir
**Debian 12** VM yeterlidir.

### 2.2 Veri İşleme Mimarisi — Gizliliğin Teknik Garantisi

UlakPDF'i diğer PDF servislerinden ayıran kritik özellik:

> **Yüklenen PDF dosyaları sunucumuza HİÇBİR ZAMAN gönderilmez.**

Tüm işleme **kullanıcının tarayıcısında**, WebAssembly modülleri
(PyMuPDF, Ghostscript, cpdf, Tesseract OCR) tarafından yapılır.
Sunucu yalnızca statik dosya servis eder. Bu mimari karar, bir
güvenlik politikası değil teknik bir garantidir — sunucumuza
ulaşmayan bir veri sızdırılamaz.

### 2.3 Kaynak Tüketimi

UlakPDF'in mimarisi, **server-side** çalışan benzer ürünlere göre
çok hafiftir:

| Çözüm | RAM | vCPU | Disk |
|---|---|---|---|
| **UlakPDF** (BentoPDF tabanlı) | 2 GB | 2 | 30 GB |
| Stirling-PDF (alternatif) | 8 GB | 4 | 50+ GB |
| Adobe Acrobat Server | 16 GB+ | 8+ | 100+ GB |

Kaynak farkının kaynağı: PDF işleme yükü server'da değil, **kullanıcı
cihazlarında** dağıtılıyor.

### 2.4 Türkçeleştirme

| Katman | Türkçe içerik |
|---|---|
| **Marka** | UlakPDF (BentoPDF üzerine kurumsal kimlik overlay'i) |
| **Karşılama sayfası** | Tamamen Türkçe |
| **KVKK aydınlatma metni** | TÜBİTAK KVKK politikasıyla uyumlu Türkçe |
| **Yönetici paneli** | Türkçe istatistik dashboard |
| **Dokümantasyon** | mkdocs-material ile yayınlanan tam Türkçe kullanıcı kılavuzu |
| **Tema rengi** | Ulakbim kurumsal mavisi (#005CA9) |
| **BentoPDF UI** | Upstream'in 20+ dil destekli arayüzü (Türkçe seçili default) |

Türkçeleştirme **upstream BentoPDF kaynağına dokunmadan**, build-time
overlay yaklaşımıyla yapılmıştır; upstream güncellemeleri sorunsuz
alınabilir.

### 2.5 Güvenlik & Standartlar

- **TLS:** Let's Encrypt, otomatik yenileme (`certbot.timer`)
- **SAML2 SP:** Shibboleth SP (sektör standardı)
- **KVKK:** Açık rıza ile, TÜBİTAK aydınlatma metni çerçevesinde
- **CSP, HSTS:** Modern web güvenlik başlıkları
- **Sunucu loglarında saklanan kişisel veri:** yalnızca e-posta ve affiliation
- **Log kayıtları:** ULAKBİM altyapısında, yurt dışına aktarılmaz

### 2.6 Bakım & İşletme

- **Kurulum süresi:** `install.sh` + `deploy.sh` ile sıfırdan ~15 dakika
- **Güncelleme:** `git pull && bash deploy/deploy.sh` (sıfır kesinti hedefi)
- **Yedekleme:** Otomatik script (SP keypair + istatistik DB + config)
- **İzleme:** Docker healthcheck'leri + yönetici istatistik paneli
- **Felaket kurtarma:** Volume bazlı yedek geri yükleme, yeni VM'de
  ~30 dakikada hizmete dönüş

---

## 3. Özellikler ve Kapsam

### 3.1 Kota Yapısı

UlakPDF'te **kullanıcı bazlı kota yoktur**:

| Sınır | UlakPDF | Yorum |
|---|---|---|
| Dosya boyutu | **Sınır yok** | Kullanıcının RAM'i ile sınırlı (pratikte ~500MB+) |
| Günlük işlem sayısı | **Sınır yok** | İşleme tarayıcıda olduğu için sunucu yüklenmez |
| Eşzamanlı kullanıcı | **Pratikte sınır yok** | Tek küçük VM yüz binlerce kullanıcıyı kaldırır |
| Saklanan dosya | **Yok** | Dosyalar sunucuya yüklenmediği için zaten yer kaplamıyor |
| Aylık trafik | İlk ziyaret ~30 MB, sonraki ziyaretler ~0 | Tarayıcı cache'i; CDN ile maliyet ihmal edilebilir |

Bu "kota-yok" durumu, mimari tasarım kararının doğal sonucudur — yapay
limitler koymak yerine sunucu kaynaklarını kullanıcı cihazlarına
dağıtmak.

### 3.2 YETKİM Federasyon Entegrasyonu

UlakPDF, YETKİM kimlik federasyonunun bir **Service Provider (SP)**
üyesidir:

- **SP Entity ID:** `https://ulakpdf.tr/shibboleth`
- **Federasyon Metadata:** `https://md.yetkim.org.tr/yetkim-metadata.xml`
- **Discovery Service:** `https://ds.yetkim.org.tr/`
- **Üye IdP sayısı:** 181 (Mayıs 2026 itibarıyla Türkiye'nin akademik
  IdP'leri + eduGAIN köprüsü)

Kullanıcı UlakPDF'e girdiğinde:
1. YETKİM kurum seçim ekranına yönlendirilir
2. Bağlı olduğu kurumu seçer (örn. ODTÜ, Bilkent, ULAKBİM, ...)
3. Kurumun kendi IdP'sinde giriş yapar
4. UlakPDF'e döner ve hizmeti kullanır

**Tek bir kayıt**, ülkedeki tüm akademik kurumlar için yeterli.

### 3.3 ULAKNET Üzerinden Erişim

UlakPDF, **ULAKNET omurgası** üzerinden servis edilir:

- ULAKNET üye kurumları için **doğrudan, hızlı erişim**
- Yurt dışı CDN bağımlılığı yok
- Bant genişliği maliyeti ULAKBİM operasyonel bütçesi içinde

### 3.4 Veri Egemenliği

KVKK ve veri egemenliği çerçevesinde:

- **Veri Sorumlusu:** TÜBİTAK (KVKK m.3/1-(ı))
- **Veri İşleyen:** ULAKBİM (UlakPDF operatörü)
- **Saklama Konumu:** Yalnızca TÜBİTAK ULAKBİM altyapısı
- **Yurt Dışına Aktarım:** **YOK**
- **Üçüncü Taraflarla Paylaşım:** **YOK**
- **Toplanan Kişisel Veri:** Yalnızca e-posta ve affiliation (kurum içi rol)
- **PDF Dosyaları:** Sunucuya hiçbir zaman ulaşmaz (mimari garanti)
- **Açık Rıza:** İlk girişte KVKK aydınlatma metni gösterilir, onay
  alındıktan sonra hizmet kullanıma açılır; onay kaydı denetlenebilir

Bu yapı, **KVKK uyumluluğunu yerinden çözer** — kurumumuzun veri
sorumluluğu açısından dışarı bir taahhüt verme zorunluluğu yoktur.

### 3.5 Yönetici İstatistik Paneli

`https://ulakpdf.tr/stats/` adresinden yetkilendirilmiş yöneticiler:

- Günlük/haftalık/aylık aktif kullanıcı sayısı
- Kuruma göre kullanım dağılımı
- En çok kullanılan araçlar
- Son etkinlik akışı

görüntüleyebilir. Yetkilendirme, `ADMIN_EPPNS` listesi üzerinden
kontrol edilir; herhangi bir kullanıcı varsayılan olarak panele
erişemez.

---

## 4. Sonuç ve Erişim

### 4.1 Mevcut Durum

- **Geliştirme:** Tamamlandı (Nisan–Haziran 2026)
- **YETKİM federasyon entegrasyonu:** Tamam ✅
- **TLS + production deployment:** Canlı ✅
- **KVKK aydınlatma metni & onay akışı:** Tamam ✅
- **Yönetici istatistik paneli:** Çalışıyor ✅
- **Dokümantasyon:** Türkçe, kullanıcı odaklı, mkdocs-material ✅
- **Pilot kullanıma açılış:** ULAKBİM içi duyuru aşamasında

### 4.2 Erişim

| Kaynak | URL |
|---|---|
| **Servis** | <https://ulakpdf.tr> |
| **Kullanıcı dokümantasyonu** | <https://ulakpdf.tr/docs/> |
| **Yönetici paneli** | <https://ulakpdf.tr/stats/> (yetki gerekir) |
| **SP metadata (YETKİM kaydı için)** | <https://ulakpdf.tr/Shibboleth.sso/Metadata> |
| **Destek** | <bulut@ulakbim.gov.tr> |

### 4.3 Roadmap

**Kısa vadeli (Q3 2026):**
- ULAKBİM içi tam yaygınlaştırma
- TÜBİTAK enstitüleri için onboarding
- Kullanıcı geri bildirimine göre arayüz iyileştirmeleri

**Orta vadeli (Q4 2026 – Q1 2027):**
- YETKİM federasyonu duyurusu (181 üye kurum)
- Yatay ölçek hazırlığı (multi-replica, Redis session store)
- Prometheus metrik dışa aktarımı

**Uzun vadeli:**
- eduGAIN köprüsü üzerinden uluslararası akademik kullanım
- ULAKBİM diğer servisleriyle entegrasyon (örn. doküman yönetim
  sistemleriyle "UlakPDF'te aç" düğmesi)

### 4.4 Maliyet Özeti

| Kalem | Tutar |
|---|---|
| Geliştirme | Bitti (mevcut ULAKBİM kapasitesiyle yapıldı) |
| Sunucu (1 küçük VM) | Mevcut bulut altyapısı içinde, ek maliyet ~0 |
| Lisans (yazılım) | **0** (tamamı açık kaynak) |
| Bandwidth | İhmal edilebilir (CDN ile sıfıra yakın) |
| Bakım | Mevcut DevOps kapasitesi içinde |
| **Yıllık toplam maliyet** | **Pratik olarak sıfır** |

Karşılaştırma: Aynı kullanıcı sayısı için Adobe Acrobat Pro lisansı
yıllık ~milyon TL bandında olur.

---

## 5. Özet Mesaj

> UlakPDF; **veri egemenliği**, **lisans bağımsızlığı**, **YETKİM
> entegrasyonu** ve **sıfır ek maliyet** ile akademik camiamıza
> kurumsal PDF aracı sunmamızı sağlayan, ULAKBİM kapasitesiyle
> üretilmiş bir hizmettir. Pilot sonrası tüm YETKİM ekosistemine
> ölçeklenmeye hazırdır.

---

**İletişim:**
ULAKBİM Bulut Birimi
TÜBİTAK ULAKBİM, Tunus Cad. No:80, 06680 Kavaklıdere / Ankara
<bulut@ulakbim.gov.tr>
