# Giriş ve Oturum

## İlk ziyaret

UlakPDF'in açılış sayfasına doğrudan girdiğinizde basit bir karşılama
göreceksiniz:

- **UlakPDF** logosu ve kısa bir açıklama
- **Yetkim SSO** giriş düğmesi
- Sağ üstte tema (aydınlık/karanlık) düğmesi

Bu sayfa anonim ziyaretçilere göstermek için tasarlanmıştır — burada PDF
araçlarını kullanamazsınız, önce oturum açmanız gerekir.

## Oturum açma

1. **Yetkim SSO** düğmesine tıklayın.
2. Kurum seçim ekranında bağlı olduğunuz kurumu seçin.
3. Kurumunuzun kullanıcı adı ve parolasıyla giriş yapın.
4. UlakPDF arayüzü açılır; sağ üstte e-posta/eppn'iniz ve **Çıkış**
   düğmesi belirir.

!!! note "Tek girişle her şey"
    Yetkim, tek imza (SSO) ilkesiyle çalışır. Eğer aynı tarayıcıda başka
    bir Yetkim hizmetine zaten giriş yaptıysanız, UlakPDF açılırken
    parola istemeyebilir — doğrudan içeri alır.

## Oturumun süresi

- Shibboleth oturumu **8 saat** geçerlidir; süre boyunca pencereyi
  kapatıp tekrar açsanız bile yeniden parola istenmez.
- 1 saat boyunca etkinlik olmazsa oturum boşta sonlanabilir.
- Tarayıcıyı kapatıp gelseniz bile, kalıcı çerez sayesinde oturum
  devam eder.

## Çıkış

Sağ üstteki **Çıkış** düğmesi:

1. UlakPDF'in Shibboleth oturumunu sonlandırır.
2. Sizi karşılama sayfasına geri götürür.
3. Yetkim federasyon oturumu (kurum IdP'sindeki) etkilenmez — başka
   Yetkim hizmetlerinde çalışmaya devam edebilirsiniz. Tam çıkış için
   tarayıcıyı kapatın veya kurum IdP'sinden ayrıca çıkış yapın.

## Sorun mu var?

| Belirti | Önce deneyin |
|---|---|
| "Giriş Yap" → boş sayfa veya hata | Birkaç dakika sonra tekrar deneyin; Yetkim IdP geçici olarak erişilemiyor olabilir |
| Kurum seçim ekranında kurumunuz yok | Kurumunuz Yetkim üyesi olmayabilir; bilgi işlem birimine danışın |
| Giriş başarılı ama "yetkisiz" yazısı | Kurumunuz UlakPDF'e attribute release etmemiş; sistem yöneticisine bildirin |
| "Oturum açıldı" ama araçlara erişim yok | Tarayıcı çerezleri engelli — çerezlere izin verin, tarayıcıyı yeniden başlatın |
| Tarayıcı uyarı veriyor | Farklı bir tarayıcıda deneyin (Firefox, Chrome, Edge) |

Sıkıntı sürerse kurumunuzun bilgi işlem destek hattına başvurun.
