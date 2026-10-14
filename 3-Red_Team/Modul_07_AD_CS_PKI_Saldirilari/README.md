# 🔴 Modül 07 — AD CS / PKI Saldırıları (Active Directory Certificate Services)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Ayrıcalık Yükseltme ve Kalıcılık (Privilege Escalation / Persistence)  
> **Simetrik Savunma Karşılığı:** [Blue M07 — AD CS / PKI Güvenliği](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/)  
> **Sistem Tabanı:** [Sistem M07 — PKI ve Sertifika Servisleri](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve PKI Saldırı Felsefesi

Active Directory Sertifika Servisleri (AD CS), kurumsal ağlarda akıllı kart oturum açma, VPN, SSL/TLS ve şifreleme için kullanılan Microsoft'un resmi Açık Anahtar Altyapısıdır (PKI). 2021 yılında Will Schroeder ve Lee Christensen (SpecterOps) tarafından yayınlanan *"Certified Pre-Owned"* araştırmasıyla birlikte AD CS, **modern Active Directory ortamlarının en yıkıcı saldırı yüzeyi** haline gelmiştir.

PKI güvenliğindeki temel prensip şudur: **Sertifika = Kimlik Kanıtı**. Bir istemci sertifikası (Client Authentication EKU), Kerberos PKINIT protokolü üzerinden doğrudan bir TGT (Ticket Granting Ticket) biletine dönüştürülebilir:
- **ESC1 (SAN Belirtme):** Şablon istemcinin sertifika üzerinde Subject Alternative Name (SAN) belirtmesine izin veriyorsa (`ENROLLEE_SUPPLIES_SUBJECT`), düşük yetkili bir kullanıcı SAN alanına `Administrator` yazarak anında Domain Admin sertifikası talep edebilir.
- **ESC4 (Şablon İzinleri):** Şablon üzerinde `WriteDacl` veya `GenericWrite` yetkisi varsa, şablon güvenlik ayarları dinamik olarak ESC1 zafiyetine dönüştürülüp sömürülebilir.
- **ESC6 (EDITF_ATTRIBUTESUBJECTALTNAME2):** CA seviyesinde bu bayrak etkinse, İSTİSNASIZ TÜM ŞABLONLARDA istemcinin SAN belirtmesine izin verilir.
- **ESC8 (HTTP Web Enrollment Relay):** CA Web Arayüzünde (`certsrv`) NTLM imzalama ve EPA kapalıysa, PetitPotam ile zorlanan Domain Controller hesabı (DC01$) CA'ya relay edilerek makine sertifikası alınır.
- **Certifried (CVE-2022-26923):** Standart kullanıcının `dNSHostName` özniteliğini DC adı olarak değiştirip makine şablonundan sertifika alması zafiyetidir.
- **ForgeCert (Golden Certificate):** CA'nın özel anahtarı (`.pfx`) çalındığında, CA'ya veya DC'ye hiç dokunmadan yıllarca geçerli sahte sertifikalar üretilebilir. KRBTGT parolası sıfırlansa bile geçerliliğini korur!

> **💡 Operasyonel İlke:**  
> *"Golden Certificate (ForgeCert), Golden Ticket'tan bile daha sinsi bir kalıcılık yöntemidir. KRBTGT çift sıfırlama döngüsü bile Golden Certificate'i geçersiz kılmaz; kurtulmanın tek yolu CA kök sertifikasını iptal etmek veya yeniden kurmaktır."*

---

## 2. AD CS Saldırı Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AD CS / PKI SALDIRI YAŞAM DÖNGÜSÜ                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Zafiyetli Şablon ve CA Taraması]
           - Certipy find veya Certify find /vulnerable
           - ESC1 - ESC8 zafiyetli şablonların ve CA izinlerinin tespiti
           - Araçlar: Certipy, Certify, PSPKIAudit
                                      │
                                      ▼
           [Aşama 2: Sömürü Metodolojisi]
           │
           ├─► [ESC1: İstemci SAN Belirtme]
           │   - certipy req -u user -p pass -ca CA-NAME -template ESC1-TEMPLATE -upn administrator@corp.local
           │   - Administrator sertifikası (pfx) elde edilir
           │
           ├─► [ESC8: Web Enrollment NTLM Relay]
           │   - ntlmrelayx dinleyici aç: -t http://ca.corp.local/certsrv/certfnsh.asp
           │   - PetitPotam / Coercer ile DC01$ makinesini koersiyonla zorla
           │   - DC01$ adına makine sertifikası (pfx) elde edilir
           │
           └─► [Certifried (CVE-2022-26923)]
               - addcomputer ile sahte makine hesabı aç
               - dNSHostName özniteliğini DC FQDN'ine eşitle
               - Machine şablonundan sertifika talep et ──▶ DC01$ pfx
                                      │
                                      ▼
           [Aşama 3: PKINIT ile Kerberos Kimlik Doğrulama]
           - certipy auth -pfx administrator.pfx -dc-ip <DC_IP>
           - Sertifika ile Kerberos TGT alınır ve NT karması (UnPAC-the-Hash) dökülür
                                      │
                                      ▼
           [Aşama 4: Domain Hakimiyeti ve Kalıcılık]
           - DC01$ hesabı ile secretsdump çalıştırarak DCSync gerçekleştir
           - CA yedek anahtarı ile ForgeCert (Golden Certificate) üret
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **07.1** | [ESC1 - ESC8 Sömürü Teknikleri](./07.1_ESC1_ESC8_Somuru_Teknikleri.md) | Client Authentication EKU analizi, `ENROLLEE_SUPPLIES_SUBJECT` (ESC1), Any Purpose EKU (ESC2), Enrollment Agent (ESC3), şablon ACL (ESC4), akıllı kart PKINIT ve Certipy analizleri. |
| **07.2** | [Certifried (CVE-2022-26923)](./07.2_Certifried_CVE_2022_26923.md) | `dNSHostName` ve `servicePrincipalName` öznitelik çakışması, DC makine taklidi, KB5014754 güncellemesi ve Strong Certificate Mapping (SID OID) mekanizması. |
| **07.3** | [Certipy ile Otomasyon](./07.3_Certipy_ile_Otomasyon.md) | Certipy komut ailesi (`find`, `req`, `auth`, `ca`, `account`, `shadow`, `forge`), ESC6/ESC7 yönetici izinleri sömürüsü ve UnPAC-the-Hash tekniği. |
| **07.4** | [ForgeCert ve Sertifika Kalıcılığı](./07.4_ForgeCert_ve_Sertifika_Kaliciligi.md) | CA özel anahtarının (Private Key) çalınması, Golden Certificate üretimi, çevrimdışı izsiz sertifika taklitleri ve çift KRBTGT sıfırlamasını atlatma stratejisi. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

AD CS saldırılarında sahada kullanılan başlıca araçların komut rehberleri:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **Certipy** | [Certipy.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/Certipy.md) | AD CS ortamlarında ESC1-ESC8 taraması, sertifika talebi, PKINIT kimlik doğrulaması ve CA yönetimi yapan eksiksiz Python aracı. |
| 02 | **Certify** | [Certify.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/Certify.md) | Windows hedeflerde çalışan, zafiyetli sertifika şablonlarını listeleyen ve talepte bulunan SpecterOps C# aracı. |
| 03 | **ForgeCert** | [ForgeCert.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/ForgeCert.md) | Çalınan CA sertifikası ve özel anahtarı ile etki alanındaki herhangi bir kullanıcı adına sahte Golden Certificate üreten C# aracı. |
| 04 | **PassTheCert** | [PassTheCert.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/CertStealer.md) | Elde edilen istemci sertifikasını doğrudan Schannel/LDAPS bağlantılarında kullanarak Kerberos'a ihtiyaç duymadan AD nesnelerini manipüle eden araç. |
| 05 | **PKINITtools** | [PKINITtools.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/PKINITtools.md) | Sertifika dosyası (`.pfx`) üzerinden Diffie-Hellman anahtar değişimiyle TGT bilet talebi (`gettgtpkinit.py`) ve NT hash dökümü yapan araç kiti. |
| 06 | **PSPKIAudit** | [PSPKIAudit.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/Certify.md) | PowerShell tabanlı AD CS denetim betiği; şablon izinlerini ve CA yapılandırma risklerini raporlar. |
| 07 | **impacket-ntlmrelayx** | [impacket-ntlmrelayx.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/impacket-ntlmrelayx.md) | ESC8 senaryosunda NTLM oturumlarını AD CS Web Kayıt (`/certsrv`) arayüzüne aktararak makine sertifikası üreten motor. |
| 08 | **PetitPotam** | [PetitPotam.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/PetitPotam.md) | ESC8 saldırısında etki alanı denetleyicisini (DC01$) saldırgan makinesine NTLM kimlik doğrulaması göndermeye zorlayan koersiyon aracı. |
| 09 | **Rubeus** | [Rubeus.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | `rubeus asktgt /certificate` komutuyla üretilen sertifikaları Kerberos TGT biletine çeviren Windows aracı. |
| 10 | **secretsdump** | [secretsdump.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/ntdsutil.md) | ESC1 veya ESC8 ile ele geçirilen DC makine hesabı üzerinden krbtgt ve tüm kullanıcı NT karmalarını çeken araç. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

AD CS saldırıları PKI ve KDC seviyesinde güçlü izler bırakır:

- **Windows Event ID 4886 / 4887 (Sertifika Talep Edildi / Onaylandı):** CA sunucusunda oluşturulan sertifika talepleri ve verilen izinler şablon adı ve talep eden kullanıcıyla kaydedilir.
- **Windows Event ID 4768 (Kerberos TGT Talebi - PKINIT):** Ön kimlik doğrulama türü `16 (PKINIT)` veya `17` olan TGT talepleri; sertifika parmak izi (Thumbprint) bilgisiyle SIEM'e akar.
- **Strong Certificate Mapping (KB5014754):** Microsoft güncellemeleri ile sertifika içine kullanıcının nesne SID değeri (`1.3.6.1.4.1.311.25.2`) gömülerek Certifried ve sahte UPN manipülasyonları engellenir.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M07 — AD CS / PKI Güvenliği](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/)
  - [Blue 07.1 — Sertifika Şablonu İzin Denetimi (ESC)](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/07.1_Sertifika_Sablonu_Izin_Denetimi_ESC.md)
  - [Blue 07.2 — CA Hardening ve ESC6 Önleme](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/07.2_CA_Hardening_ve_ESC6.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde incelenen AD CS zafiyetleri (ESC1-ESC8), sahte sertifika üretimi (ForgeCert) ve PKINIT manipülasyonları; **yalnızca yetkili kurumsal sızma testleri, kırmızı takım tatbikatları ve eğitim amaçlı laboratuvarlar** için geçerlidir.
>
> Bir kurumun Sertifika Otoritesini (CA) manipüle etmek veya yetkisiz kimlik sertifikaları üretmek sistem genelinde kimlik sahteciliğine neden olabilir ve TCK Madde 243-245 kapsamında suçtur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — AD CS & PKI Attacks (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/adcs/): ESC1-ESC8 şablon sömürüleri ve referans komutlar.
- 🌐 [HackTricks Wiki — Active Directory Certificate Services (Carlos Polop)](https://book.hacktricks.wiki/): PKINIT, Certipy ve sertifika yükseltme yolları.
- 🌐 [The Hacker Recipes — AD CS (Active Directory Certificate Services)](https://www.thehacker.recipes/): Sertifika sömürü şablonları ve mimari detaylar.
- 🌐 [SpecterOps — Certified Pre-Owned Research Paper](https://posts.specterops.io/): Will Schroeder ve Lee Christensen tarafından hazırlanan temel AD CS araştırma raporu.
- 🌐 [Oliver Lyak (ly4k) — Certifried & Certipy Documentation](https://github.com/ly4k/Certipy): CVE-2022-26923 analizi ve araç dokümantasyonu.

---

> **Önceki Modül:** [← Modül 06 — Kerberos Delegation](../Modul_06_Kerberos_Delegation_Saldirilari/README.md) · **Sonraki Modül:** [Modül 08 — Koersiyon ve NTLM Relay →](../Modul_08_Koersiyon_ve_NTLM_Relay/README.md)
