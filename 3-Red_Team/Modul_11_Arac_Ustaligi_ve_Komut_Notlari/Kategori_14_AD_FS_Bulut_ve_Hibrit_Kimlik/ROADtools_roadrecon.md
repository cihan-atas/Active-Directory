# ROADtools / roadrecon

> **Kategori:** [14. AD FS, Bulut ve Hibrit Kimlik](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Azure AD / Microsoft Entra ID bulut ortamlarındaki kullanıcıları, grupları, rolleri, uygulamaları ve Koşullu Erişim (Conditional Access) politikalarını Microsoft Graph API üzerinden tarayan, yerel SQLite veritabanında depolayan ve görsel web arayüzünde analiz eden keşif çerçevesi.

---

## 1. Genel Bakış ve Amaç

Şirket içi Active Directory ortamlarında keşif ve saldırı yolu analizi için LDAP ve BloodHound ne kadar kritikse; bulut ve hibrit kimlik dünyasında (Microsoft Entra ID / Azure AD) **ROADtools** aynı derecede merkezi bir role sahiptir. Bulut ortamlarında LDAP veya yerel RPC protokolleri bulunmaz; tüm nesneler, yetkiler ve güvenlik politikaları Microsoft Graph API ve eski Azure AD Graph API (`graph.windows.net`) üzerinden yönetilir.

**ROADtools** (Dirk-jan Mollema / @dirkjanm tarafından Python ile geliştirilmiştir), Azure AD güvenliğini denetlemek ve sızma testlerinde bulut varlıklarını haritalamak amacıyla tasarlanmış açık kaynaklı bir çatıdır. Çatının temel keşif bileşeni olan **roadrecon**:
1. Standart kimlik bilgileri, OAuth erişim belirteçleri (Access Token), Primary Refresh Token (PRT) veya cihaz sertifikalarıyla Azure AD'ye kimlik doğrular.
2. Kiracıda (Tenant) bulunan tüm nesneleri (Kullanıcılar, Gruplar, Cihazlar, Uygulama Kayıtları / Service Principals, Dizin Rolleri ve Koşullu Erişim Politikaları) özyinelemeli olarak çeker (`roadrecon gather`).
3. Toplanan devasa JSON verisini yapılandırılmış bir yerel SQLite veritabanında (`roadrecon.db`) birleştirir.
4. Yerleşik bir web sunucusu başlatarak (`roadrecon gui`), operatörün tüm bulut hiyerarşisini, hak devirlerini ve ayrıcalıklı erişim yollarını tarayıcı üzerinden interaktif olarak incelemesini sağlar.

Ayrıca çatının tamamlayıcı bileşeni olan **roadtx (ROADtools Token eXchange)**; PRT çalma, cihaz kaydı taklit etme (Device Registration) ve Koşullu Erişim politikalarını aşma (CAP Bypass) yetenekleri sunar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            ROADRECON MIMARI AKIŞI                                 |
+-----------------------------------------------------------------------------------+
  [Denetçi / Operatör]                               [Microsoft Entra ID / Cloud]
     (roadrecon CLI)                                   (Microsoft Graph REST API)
            |                                                     |
            |--- 1. roadrecon auth ------------------------------>|
            |       [User/Pass / PRT / Device Code / Token]       |
            |<-- 2. OAuth2 Access Token & Refresh Token Döner ----|
            |                                                     |
            |--- 3. roadrecon gather (Toplu API Sorguları) ------>|--- 3. Graph API:
            |       /v1.0/users, /v1.0/groups, /v1.0/devices      |       /applications,
            |       /identity/conditionalAccess/policies          |       /directoryRoles
            |<-- 4. Ham JSON Nesne Akışı Döner -------------------|
            |
  [Yerel Analiz İstasyonu]
  ├── roadrecon.db (SQLite Veritabanı)
  │   ├── Users & Password Policies
  │   ├── Service Principals & App Roles
  │   └── Conditional Access Policies
  │
  └── roadrecon gui (Flask / Angular Web Sunucusu)
            |
            v  [Port 5000: http://127.0.0.1:5000]
  [Görsel Bulut Haritası & Saldırı Yolu Analizi (Tarayıcı Konsolu)]
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Kapsamlı Bulut Keşfi** | Entra ID'deki tüm nesneleri tek hamlede toplar. | Parça parça PowerShell betikleri çalıştırma ihtiyacını kaldırır. |
| **Görsel Web Konsolu** | İlişkileri ve rolleri tarayıcıda grafik arayüzle sunar.| Karmaşık JSON çıktılarını okuma zorluğunu ortadan kaldırır. |
| **Koşullu Erişim Analizi** | Tüm CAP kurallarını ve boşluklarını haritalar. | MFA ve cihaz uyumluluğu zorunlu olmayan yolları gösterir. |
| **Esnek Kimlik Doğrulama** | Parola, Token, PRT ve Cihaz Sertifikası destekler. | Ele geçirilen her tür bulut kimlik bilgisiyle çalışabilir. |
| **Çevrimdışı Analiz** | Veriyi `roadrecon.db` olarak saklar; ağsız incelenir.| Canlı buluta sürekli API isteği yapmaktan kaçınmayı sağlar. |

### Karşılaştırma Tablosu

| Özellik | ROADtools (roadrecon) | AzureHound (BloodHound) | AADInternals | Az (PowerShell Modülü) |
| :--- | :--- | :--- | :--- | :--- |
| **Geliştirme Dili** | Python (Flask / SQLAlchemy) | Go / C# | PowerShell | PowerShell / C# |
| **Görselleştirme** | Kendi Web GUI Konsolu (Port 5000)| BloodHound (Neo4j Grafı) | Yok (CLI / Portal açma) | Yok (Komut satırı) |
| **Koşullu Erişim Ayrıştırma**| Çok Detaylı (Özel Analiz)| Kısmi | Kısmi | Ham JSON |
| **PRT / Token Yetenekleri** | Evet (`roadtx` bileşeni) | Hayır | Evet (PRT & SAML) | Hayır |
| **Hedef Platform** | Linux / macOS / Windows | Windows / Linux | Windows (PowerShell) | Windows / Linux |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ROADtools operasyonu genellikle üç aşamalı bir iş akışından oluşur: `auth` (kimlik doğrulama), `gather` (veri toplama) ve `gui` (görselleştirme):

```bash
roadrecon auth -u <KULLANICI> -p <PAROLA> [-t <TENANT_ID>]
roadrecon gather
roadrecon gui [-p <PORT>]
```

### Desteklenen Kritik Alt Komutlar ve Bayraklar

| Komut / Bayrak | Alt Komut | Açıklama | Örnek Kullanım |
| :--- | :--- | :--- | :--- |
| `auth` | `roadrecon auth` | Azure AD ile kimlik doğrular ve `.roadtools_auth` token dosyasını oluşturur. | `roadrecon auth -u user@corp.com -p 'Pass!'` |
| `--device-code` | `auth` | Tarayıcı üzerinden Device Code Flow ile interaktif oturum açar (MFA için ideal). | `roadrecon auth --device-code` |
| `--access-token` | `auth` | Önceden elde edilmiş ham JWT Access Token kullanarak bağlanır. | `roadrecon auth --access-token eyJ...` |
| `gather` | `roadrecon gather` | Azure AD API'lerini sorgulayarak verileri `roadrecon.db` veritabanına yazar. | `roadrecon gather` |
| `--mfa` | `gather` | Kullanıcının MFA hakları varsa ek ayrıcalıklı verileri de toplamaya çalışır. | `roadrecon gather --mfa` |
| `gui` | `roadrecon gui` | Web arayüzünü yerel makinede başlatır (Varsayılan: `127.0.0.1:5000`). | `roadrecon gui --port 8080` |
| `-d` / `--database`| Genel | Kullanılacak SQLite veritabanı dosya yolu. | `-d /tmp/corp_aad.db` |
| `dump` | `roadrecon dump` | SQLite veritabanındaki nesneleri JSON dosyalarına dışa aktarır. | `roadrecon dump` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı Bilgileri ile Kimlik Doğrulama ve Token Alma
Düşük yetkili bir etki alanı kullanıcısının bulut kimlik bilgileriyle kimlik doğrulama:

```bash
roadrecon auth -u "jdoe@corp.com" -p "Winter2026!#Secure" -t "corp.com"
```

**Konsol Çıktı Analizi:**
```
[*] Authenticating to Azure Active Directory...
[+] Authentication successful!
[+] Tokens saved to .roadtools_auth
[*] Access token expires: 2026-10-14 22:30:15
```

### Senaryo 2: Device Code Akışı ile MFA Korumalı Hesapla Giriş Yapma
Kullanıcı hesabında Çok Faktörlü Kimlik Doğrulama (MFA) etkin olduğunda, tarayıcıdan onay koduyla yetki alma:

```bash
roadrecon auth --device-code
```

**Konsol Çıktı Analizi:**
```
[*] To sign in, use a web browser to open the page https://microsoft.com/devicelogin
[*] and enter the code: D91A-88BC to authenticate.
[+] Authentication completed via browser! Tokens written to .roadtools_auth.
```

### Senaryo 3: Tüm Kiracı Verilerini SQLite Veritabanına Çekme (`gather`)
Oluşturulan token ile tüm kullanıcıları, grupları, cihazları ve politikaları yerel veritabanına indirme:

```bash
roadrecon gather
```

**Konsol Çıktı Analizi:**
```
[*] Gathering data from Azure AD Graph & MS Graph...
[*] Gathering users... Found 1,240 users.
[*] Gathering groups... Found 312 groups.
[*] Gathering service principals and applications... Found 450 apps.
[*] Gathering directory roles... Found 48 roles.
[*] Gathering devices... Found 890 devices.
[*] Gathering Conditional Access policies... Found 14 policies.
[+] Data gathering completed successfully. Database written to: roadrecon.db
```

### Senaryo 4: Görsel Web Arayüzünü Başlatma ve İnceleme (`gui`)
Veritabanındaki bulut topolojisini tarayıcı üzerinden grafiksel olarak analiz etmek için sunucuyu başlatma:

```bash
roadrecon gui --port 5000
```

**Konsol Çıktı Analizi:**
```
[*] Starting ROADrecon Web Server...
[*] Serving application at: http://127.0.0.1:5000/
[*] Open your browser and navigate to the link above to explore tenant assets.
```

### Senaryo 5: Koşullu Erişim Politikalarını (Conditional Access) Haritalama
Kiracıdaki MFA ve güvenilen konum zorunluluklarını inceleyerek açıkta kalan servis veya kullanıcıları tespit etme:

```bash
python3 -c "import sqlite3; conn=sqlite3.connect('roadrecon.db'); cur=conn.cursor(); cur.execute('SELECT displayName, state FROM ConditionalAccessPolicies'); print(cur.fetchall())"
```

**Konsol Çıktı Analizi:**
```
[('Require MFA for Administrators', 'enabled'),
 ('Block Legacy Authentication', 'enabled'),
 ('Require Compliant Device for All Users', 'disabled')]  <-- KRİTİK GEVŞETME
```

### Senaryo 6: Hizmet Sorumlularını (Service Principals) ve Gizli API İzinlerini Sorgulama
Uygulama izinleri (`Application Permissions` - Mail.Read, Directory.ReadWrite.All) atanmış yüksek yetkili servis hesaplarını listeleme:

```bash
python3 -c "import sqlite3; conn=sqlite3.connect('roadrecon.db'); cur=conn.cursor(); cur.execute('SELECT appDisplayName, servicePrincipalType FROM ServicePrincipals WHERE appOwnerOrganizationId IS NOT NULL'); print(cur.fetchmany(5))"
```

**Konsol Çıktı Analizi:**
```
[('Backup-Integration-App', 'Application'),
 ('Automation-Deployer', 'Application'),
 ('Graph-Audit-Service', 'Application')]
```

### Senaryo 7: roadtx ile Primary Refresh Token (PRT) Kullanarak MFA'sız Token Alma
Hedef kullanıcının Windows iş istasyonundan (lsass/browser) çalınmış PRT ile doğrudan bulut erişim belirteci üretme:

```bash
roadtx prt -p "PRT_COOKIE_VALUE_BURAYA" -k "PRT_SESSION_KEY_HEX" --action prt-to-token
```

**Konsol Çıktı Analizi:**
```
[*] Exchanging Primary Refresh Token for Azure AD Access Token...
[+] Successfully claimed token with MFA claim included in PRT context!
[*] Access token: eyJ0eXAiOiJKV1QiLC...
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `AADSTS50076: Due to a configuration change made by your administrator, you must use multi-factor authentication` | Kullanıcıda MFA zorunlu tutuluyor; standart kullanıcı/parola akışı engellenmiş. | `--device-code` parametresini kullanarak MFA'yı tarayıcıdan tamamlayın veya ele geçirilen bir PRT / Access Token ile bağlanın. |
| `Insufficient privileges to complete the operation` | Düşük yetkili kullanıcı hesabı kiracıdaki bazı nesneleri (örn: diğer kullanıcıların cihazları veya CAP'ler) okuma hakkına sahip değil. | Normal bir durumdur; roadrecon okuyabildiği tüm nesneleri yine de veritabanına yazar. Daha yüksek yetkili bir hesapla `gather` komutunu yenileyin. |
| `sqlite3.OperationalError: database is locked` | `roadrecon gather` çalışırken eşzamanlı olarak `roadrecon gui` veya başka bir script aynı veritabanını yazma modunda açmış. | Çalışan diğer roadrecon işlemlerini kapatın veya `-d` bayrağı ile farklı bir veritabanı dosya adı (`roadrecon_2.db`) belirtin. |
| `Error: Address already in use (Port 5000)` | 5000 portu yerel makinede başka bir servis (Docker, Flask vb.) tarafından kullanılıyor. | `roadrecon gui --port 8085` komutunu kullanarak boşta olan farklı bir port tanımlayın. |
| `Token has expired during gather operation` | Çok büyük kiracılarda (10.000+ kullanıcı) veri toplama işlemi 1 saatten uzun sürüyor ve access token'ın süresi doluyor. | roadrecon'ın en güncel sürümünü kullanın (otomatik refresh token yenileme desteği) veya parçalı sorgulama yapın. |
| `AADSTS53003: Access has been blocked by Conditional Access policies` | Saldırganın IP adresi veya konumu, kurumun coğrafi engelleme (Geofencing) ya da güvenilen IP politikalarına takılıyor. | Şirket içi güvenilen ağa ait bir proxy/VPN üzerinden çıkış yaparak kimlik doğrulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[5.0 - GRAPH API REST ENUMERATION]-------------- 10
  - Şirket İçi Seviye: SIFIR İZ (Şirket içi ağa veya DC'ye doğrudan paket gitmez)
  - Bulut Seviyesi: Microsoft Graph API toplu istekleri ve Azure AD Sign-in Logs telemetrisi
```

### 5.1 Bırakılan İzler (Event Logs)

* **Azure AD / Entra ID Sign-in Logs:**
  * **Uygulama Adı:** Oturum açma yöntemine göre `Azure Active Directory PowerShell` (AppID: `1b730954-7985-4b43-b428-e4b782764b10`) veya `Microsoft Graph Command Line Tools`.
  * **User-Agent:** Python `requests` kütüphanesine ait başlıklar veya `roadrecon` özelleştirilmiş dizeleri.
  * **IP Adresi ve Konum:** Saldırganın harici çıkış IP adresi kaydedilir.
* **Entra ID Audit Logs (Denetim Günlükleri):**
  * Eğer `roadtx` ile yeni bir cihaz kaydı (Device Registration) yapılmışsa, `Add registered owner to device` olayı denetim günlüğüne düşer.
* **Şirket İçi Sunucularda Sıfır Log:**
  * Tüm operasyon doğrudan Microsoft'un bulut uç noktaları (`login.microsoftonline.com`, `graph.microsoft.com`) üzerinde cereyan ettiğinden şirket içi SIEM'e yerel log düşmez.

### 5.2 Ağ ve EDR İmzaları

* **Ağ Tarafında HTTPS Trafiği:**
  İletişim tamamen port 443 üzerinden TLS şifreli REST API çağrıları biçiminde akar. NIDS sistemleri içerik şifreli olduğu için paket içerisindeki JSON verilerini inceleyemez.
* **API Hız Limiti (Rate Limiting) Anomalisi:**
  Binlerce nesnenin art arda `GET /v1.0/users` ile paginated (sayfalı) biçimde talep edilmesi, Microsoft Defender for Cloud Apps tarafından "Mass Data Download / Graph API Enumeration" davranışı olarak işaretlenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Discovery** | `T1087.004` | Account Discovery: Cloud Account | Kiracıdaki tüm bulut kullanıcılarını ve rollerini listeleme. |
| **Discovery** | `T1069.003` | Permission Groups Discovery: Cloud Groups | Azure AD güvenlik gruplarını ve rollerini haritalama. |
| **Discovery** | `T1018` | Remote System Discovery | Buluta katılmış (Azure AD Joined) cihazları keşfetme. |
| **Credential Access** | `T1528` | Steal Application Access Token | OAuth belirteçlerini ve PRT oturumlarını kullanma. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Python User-Agent İmzası** | Kod içerisindeki veya HTTP oturumundaki User-Agent dizesi meşru bir kurumsal Edge/Chrome başlığı ile değiştirilmelidir. |
| **Yabancı IP Adresinden Giriş** | Hedef kurumun merkez ofisinin bulunduğu coğrafi bölgeye/ülkeye ait bir proxy sunucusu üzerinden kimlik doğrulanmalıdır. |
| **Device Code Kullanımı** | Mümkün olduğunda doğrudan şifre girmek yerine `--device-code` kullanılarak kullanıcının kendi meşru oturumundan token temin edilmelidir. |
| **Veritabanı Güvenliği** | Hasat edilen `roadrecon.db` dosyası hassas tüm kiracı verilerini barındırdığından diskte şifreli tutulmalı ve test bitince silinmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Şüpheli Azure AD Graph API Toplu Veri Çekme Tespiti
```yaml
title: Olagandisi Entra ID Graph API Toplu Nesne Kesfi (ROADtools)
id: e1294a80-4412-4c88-b112-998811aa6677
status: experimental
description: Kisa surede Graph API uzerinden cok sayida kullanici, grup ve cihaz nesnesinin sayfalanarak indirilmesini tespit eder.
references:
    - https://attack.mitre.org/techniques/T1087/004/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: azure_audit
    product: azure
detection:
    selection_app:
        AppId: '1b730954-7985-4b43-b428-e4b782764b10' # Azure AD PowerShell
    selection_useragent:
        UserAgent|contains:
            - 'python-requests'
            - 'roadrecon'
            - 'roadtools'
    condition: selection_app or selection_useragent
falsepositives:
    - Sistem yoneticilerinin mesru Python otomasyon scriptleri.
level: high
tags:
    - attack.discovery
    - attack.t1087.004
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// Azure AD Sign-in loglarinda supheli Python veya ROADtools kaynakli girisleri tespit eder
SigninLogs
| where TimeGenerated >= ago(24h)
| where UserAgent has_any ("python-requests", "roadrecon", "roadtools")
     or (AppDisplayName == "Azure Active Directory PowerShell" and RiskLevelDuringSignIn in ("medium", "high"))
| project TimeGenerated, UserPrincipalName, IPAddress, Location, UserAgent, AppDisplayName, ResultType
| order by TimeGenerated desc
```

#### YARA Kuralı: ROADtools Python Modül İmzası
```yara
rule Threat_Tool_ROADtools_roadrecon {
    meta:
        description = "ROADtools ve roadrecon Azure AD kesif kutuphanesini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "Medium"
    strings:
        $s1 = "roadrecon" ascii wide nocase
        $s2 = "roadtools" ascii wide nocase
        $s3 = "roadtools_auth" ascii wide
        $s4 = "ConditionalAccessPolicies" ascii wide
        $s5 = "servicePrincipals" ascii wide
    condition:
        3 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Koşullu Erişimde Eski Kimlik Doğrulamayı Engelleme (Block Legacy Auth):** Temel kimlik doğrulama (Basic Auth) tamamen engellenmeli; tüm kullanıcılar Modern Kimlik Doğrulama ve FIDO2/MFA'ya zorlanmalıdır.
2. **Kullanıcıların Diğer Nesneleri Okumasını Kısıtlama:** Entra ID yönetim merkezinde "Users can read other users" ve "Restrict non-admin users from creating tenant objects" politikaları sıkılaştırılmalıdır.
3. **Uyumlu Cihaz Zorunluluğu (Require Compliant Device):** Koşullu Erişim politikalarında kurumsal Microsoft Intune kayıtlı ve uyumlu olmayan cihazların Graph API ve şirket verilerine erişmesi engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Parola ile Kimlik Doğrulama
```bash
roadrecon auth -u "user@corp.com" -p 'Password123!' -t "corp.com"
```
* **Ne Yapar?:** Kullanıcı adı ve parola ile oturum açarak `.roadtools_auth` token dosyasını üretir.
* **Ne Zaman Kullanılır?:** Kullanıcının düz metin parolası bilindiğinde ilk kimlik doğrulama adımı olarak.
* **Parametreler:** `-u` kullanıcı adı, `-p` parola, `-t` kiracı etki alanı.

#### 2. Device Code Akışı ile Etkileşimli Giriş
```bash
roadrecon auth --device-code
```
* **Ne Yapar?:** Tarayıcı üzerinden onay koduyla oturum açarak MFA gereksinimini güvenle tamamlar.
* **Ne Zaman Kullanılır?:** Kullanıcıda MFA etkin olduğunda veya parola girilmek istenmediğinde.
* **Parametreler:** `--device-code` bayrağı.

#### 3. Kiracı Verilerini Çekme (gather)
```bash
roadrecon gather
```
* **Ne Yapar?:** Token'ı kullanarak Azure AD'deki tüm kullanıcı, grup, cihaz ve politikaları SQLite'a indirir.
* **Ne Zaman Kullanılır?:** Kimlik doğrulama başarıyla tamamlandıktan hemen sonra.
* **Parametreler:** Parametresiz çalıştırma.

#### 4. Görsel Web Konsolunu Başlatma (gui)
```bash
roadrecon gui --port 5000
```
* **Ne Yapar?:** Yerel web sunucusunu açarak veritabanı içeriğini tarayıcıda grafiksel arayüze döker.
* **Ne Zaman Kullanılır?:** Toplanan verileri görsel olarak gezinmek ve analiz etmek için.
* **Parametreler:** `--port` web portu (Varsayılan: 5000).

#### 5. Veritabanını JSON Olarak Dökme (dump)
```bash
roadrecon dump
```
* **Ne Yapar?:** `roadrecon.db` içerisindeki tüm tabloları ayrı JSON dosyaları halinde diske aktarır.
* **Ne Zaman Kullanılır?:** Verileri diğer analiz script'lerine veya raporlama araçlarına beslemek için.
* **Parametreler:** `dump` alt komutu.

#### 6. Access Token ile Doğrudan Bağlanma
```bash
roadrecon auth --access-token "eyJ0eXAiOiJKV1QiLC..."
```
* **Ne Yapar?:** Önceden çalınmış veya belleğe yakalanmış JWT belirteciyle şifresiz oturum açar.
* **Ne Zaman Kullanılır?:** Kullanıcı parolası olmayıp elinizde geçerli bir token bulunduğunda.
* **Parametreler:** `--access-token <JWT_Dizesi>`.

#### 7. Özel Veritabanı Yolu Tanımlama
```bash
roadrecon gather -d /tmp/target_tenant.db
```
* **Ne Yapar?:** Verileri varsayılan dosya yerine belirtilen SQLite yoluna kaydeder.
* **Ne Zaman Kullanılır?:** Birden fazla kiracıyı birbirinden izole dosyalarda incelemek için.
* **Parametreler:** `-d` veritabanı yolu.

#### 8. Koşullu Erişim Politikalarını Sorgulama
```bash
python3 -c "import sqlite3; c=sqlite3.connect('roadrecon.db'); print([r[0] for r in c.execute('SELECT displayName FROM ConditionalAccessPolicies')])"
```
* **Ne Yapar?:** Kiracıdaki tüm aktif Koşullu Erişim kural başlıklarını hızlıca listeler.
* **Ne Zaman Kullanılır?:** Web GUI açmadan kuralları konsolda hızlıca görmek için.
* **Parametreler:** Python tek satırlık SQLite sorgusu.

#### 9. roadtx ile PRT Takası Yapma
```bash
roadtx prt -p "PRT_COOKIE" -k "SESSION_KEY"
```
* **Ne Yapar?:** Cihaz Primary Refresh Token'ını Azure AD Access Token'ına dönüştürür.
* **Ne Zaman Kullanılır?:** İş istasyonundan çalınan PRT ile MFA'yı atlatmak için.
* **Parametreler:** `roadtx` CLI komutu.

#### 10. SQLite Veritabanını ve Token Dosyasını Güvenle Temizleme
```bash
rm -f .roadtools_auth roadrecon.db
```
* **Ne Yapar?:** Hasat edilen oturum belirteçlerini ve tüm bulut veritabanını yerel diskten siler.
* **Ne Zaman Kullanılır?:** Denetim tamamlandığında hassas müşteri verilerini imha etmek için.
* **Parametreler:** `rm -f`.

---

## Kaynaklar
* [Dirk-jan Mollema Resmi ROADtools GitHub Deposu](https://github.com/dirkjanm/ROADtools)
* [Dirk-jan Mollema Blog: Introducing ROADtools](https://dirkjanm.io/introducing-roadtools-and-roadrecon-azure-ad-exploration-framework/)
* [Microsoft Dokümantasyonu: Microsoft Graph API Overview](https://learn.microsoft.com/en-us/graph/overview)
* [MITRE ATT&CK: Account Discovery: Cloud Account (T1087.004)](https://attack.mitre.org/techniques/T1087/004/)
* [HackTricks: Pentesting Azure AD with ROADtools](https://book.hacktricks.xyz/cloud-security/azure/roadtools)

---

> **Önceki:** [← ADFSpoof](./ADFSpoof.md) · **Sonraki:** [PrintSpoofer (Kategori 15) →](../Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/PrintSpoofer.md)
