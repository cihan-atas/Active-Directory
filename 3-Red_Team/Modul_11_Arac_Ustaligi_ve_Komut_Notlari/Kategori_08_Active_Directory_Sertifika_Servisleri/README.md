# 8. ACTIVE DIRECTORY SERTİFİKA SERVİSLERİ (AD CS / PKI EXPLOITATION)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 7 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Certify** | [Certify.md](./Certify.md) | Active Directory Certificate Services (AD CS) ortamındaki zafiyetli şablonları (ESC1-ESC4) tarayan ve kötüye kullanılabilir şablonlardan sertifika talep eden C# aracıdır. |
| 2 | **Certipy** | [Certipy.md](./Certipy.md) | AD CS mimarisini keşfeden, ESC1'den ESC16'ya kadar tüm zafiyetleri istismar eden, Golden Certificate üreten ve PKINIT ile NTLM hash'e dönüştüren en kapsamlı Python çerçevesidir. |
| 3 | **ForgeCert** | [ForgeCert.md](./ForgeCert.md) | Ele geçirilen CA özel anahtarı ve sertifikası ile çevrimdışı ortamda herhangi bir etki alanı kullanıcısı adına geçerli Altın Sertifikalar (Golden Certificates) üreten araçtır. |
| 4 | **PKINITtools** | [PKINITtools.md](./PKINITtools.md) | X.509 sertifikalarını Kerberos PKINIT protokolü üzerinden TGT biletlerine ve kullanıcı NTLM hash'lerine dönüştüren Python araç setidir. |
| 5 | **Whisker** | [Whisker.md](./Whisker.md) | Active Directory nesnelerinin msDS-KeyCredentialLink özniteliğine sertifika anahtarı enjekte ederek Shadow Credentials saldırısı düzenleyen C# aracıdır. |
| 6 | **pyWhiskey** | [pyWhiskey.md](./pyWhiskey.md) | Whisker aracının Linux ortamında çalışan Python karşılığıdır; hedef kullanıcı veya bilgisayar hesaplarına LDAP üzerinden Shadow Credentials bağlar. |
| 7 | **CertStealer** | [CertStealer.md](./CertStealer.md) | Windows işletim sisteminde CryptoAPI ve CNG depolarında bulunan ve dışa aktarılamaz (non-exportable) olarak işaretlenmiş özel anahtarları bellekten çekip çıkaran araçtır. |


---

> **Önceki Kategori:** [← Kategori 7](../Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/README.md) · **Sonraki Kategori:** [Kategori 9 →](../Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/README.md)
