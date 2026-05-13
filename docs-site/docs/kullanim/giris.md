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

| Belirti | Olası neden |
|---|---|
| "Giriş Yap" → boş sayfa veya hata | Yetkim IdP geçici olarak erişilemiyor olabilir |
| Giriş başarılı ama "yetkisiz" gözüküyorsunuz | Kurumunuz UlakPDF'e attribute release etmemiş olabilir; sistem yöneticisine bildirin |
| "Oturum açıldı" ama araçlara erişim yok | Tarayıcı çerezleri engelli; çerezlere izin verin |

Daha ayrıntılı sorun giderme için [Sorun giderme](../bakim/sorun-giderme.md)
sayfasına bakın.
