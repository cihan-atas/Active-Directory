# Snaffler

> **Kategori:** [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory etki alanındaki SMB ve DFS ağ paylaşımlarını otomatik keşfeden, dosya ve dizinleri çok iş parçacıklı kural motoruyla (regex/triage) tarayarak parola, API anahtarı, sertifika, SSH anahtarı, veritabanı yedeği ve yapılandırma sırlarını sınıflandıran C# tabanlı veri avı aracı.

---

## 1. Genel Bakış ve Amaç

Snaffler, kurumsal Active Directory ortamlarında geniş dosya sistemleri (File Servers, DFS ad alanları, NAS üniteleri ve iş istasyonları) üzerinde unutulmuş, güvensiz depolanmış veya aşırı yetkili (Everyone / Authenticated Users read access) izinlerle paylaşılan hassas kurumsal verileri tespit etmek amacıyla geliştirilmiş yüksek performanslı bir veri avı (data hunting) ve denetim aracıdır.

Snaffler, etki alanı denetleyicisine (Domain Controller) LDAP protokolü üzerinden bağlanarak etki alanına dahil tüm bilgisayar hesaplarını sorgular. Keşfettiği her uç noktaya SMB (Server Message Block - TCP 445) üzerinden bağlanarak `NetShareEnum` API çağrıları veya doğrudan SMB ağaç bağlantıları (Tree Connect) ile okunabilir paylaşımları listeler. Ardından, önceden tanımlanmış veya özelleştirilmiş regex kuralları, dosya adı desenleri, uzantı filtreleri ve içerik inceleme motoru aracılığıyla dosyaları derinlemesine analiz eder.

Bulunan veriler, operasyonel önceliğe göre sınıflandırılarak renk kodlarıyla raporlanır:
* **Black (Siyah):** Kesinlikle operasyonel değere sahip kritik sırlar (şifresiz özel anahtarlar, açık kimlik bilgileri, KeePass veritabanları).
* **Red (Kırmızı):** Çok yüksek olasılıkla parola veya kritik konfigürasyon içeren belgeler (`web.config`, `unattend.xml`, `.pfx` dosyaları).
* **Yellow (Sarı):** İncelenmeye değer ilginç dosya veya anahtar kelimeler (SQL scriptleri, PowerShell otomasyon betikleri).
* **Green (Yeşil):** Bilgi toplama ve genel keşif niteliğindeki dosya listelemeleri.

### 1.1 Kural Motoru ve Sınıflandırıcılar (Classifier Architecture)
Snaffler, dosyaları dosya sistemi hiyerarşisinde gezinirken aşamalı bir kural değerlendirme süzgecinden geçirir:
1. **Enumeration Phase:** Hedef sunucuda `NetShareEnum` çağrısıyla tüm paylaşımlar (`STYPE_DISKTREE`) listelenir.
2. **Path Filter (DiscardPath):** Windows dizinleri (`C:\Windows`, `C:\Program Files`), geri dönüşüm kutuları (`$Recycle.Bin`) veya sistem önbellekleri regex ile elenir.
3. **File Extension Check (KeepExt / DiscardExt):** Uzantı denetimi yapılır. Örneğin `.dll`, `.exe`, `.iso` gibi büyük ve metin dışı ikililer elenirken; `.kdbx`, `.key`, `.ovpn`, `.config`, `.ps1` uzantıları doğrudan triage kuyruğuna alınır.
4. **File Name Regex (KeepFilename / DiscardFilename):** Dosya adında `passw`, `secret`, `credential`, `unattend`, `backup` gibi kalıplar aranır.
5. **Content Regex (FileContentRegex):** Dosya açılır, akış belleğe alınır ve içerisindeki `connectionString`, `password=`, `BEGIN PRIVATE KEY` kalıpları çok iş parçacıklı olarak incelenir.

```
+-------------------------------------------------------------------------+
|                         Snaffler Mimari Akışı                          |
+-------------------------------------------------------------------------+
                               |
               1. LDAP Query (TCP 389/636)
          [sAMAccountType=805306369 / Computers]
                               v
                +------------------------------+
                | Active Directory DC          |
                +------------------------------+
                               | Bilgisayar Listesi
                               v
                     +-------------------+
                     |  Snaffler Engine  |
                     +-------------------+
                       /       |       \
       SMB (TCP 445)  /        |        \  SMB (TCP 445)
                     v         v         v
              +----------+ +----------+ +----------+
              | FileSrv1 | |  NAS01   | | Workstn1 |
              +----------+ +----------+ +----------+
                     |         |         |
          NetShareEnum & NetShareGetInfo (RPC / srvsvc)
                     \         |         /
                      v        v        v
         +---------------------------------------------+
         |     Share Enumeration & Permission Triage   |
         |  (C$, ADMIN$, IPC$, SYSVOL, NETLOGON, Data) |
         +---------------------------------------------+
                               | Read Access OK
                               v
         +---------------------------------------------+
         | Multi-Threaded File & Content Rule Engine   |
         |  1. Path Discard Filter (Regex)             |
         |  2. File Extension Filter (KeepExt)         |
         |  3. File Name Matcher (KeepFilename)        |
         |  4. Content Matcher (Regex / Aho-Corasick)  |
         +---------------------------------------------+
                               |
                               v
         +---------------------------------------------+
         |      Kategorize Edilmiş Raporlama / Triage  |
         |   [Black] > [Red] > [Yellow] > [Green]      |
         +---------------------------------------------+
```

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Açık Parola ve Sır Tespiti** | BT ekiplerinin scriptlerde (`.ps1`, `.bat`, `.vbs`) veya konfigürasyon dosyalarında (`web.config`, `appsettings.json`) bıraktığı açık metin yönetici parolalarının avlanması. |
| **KeePass ve Cüzdan Keşfi** | Sistem yöneticilerine ait `.kdbx` dosyalarının, bulut erişim anahtarlarının (`credentials`, `id_rsa`) veya VPN profillerinin merkezi sunucularda unutulmasının tespiti. |
| **Yedekleme ve SQL Dökümleri** | Paylaşıma açık bırakılmış `.bak`, `.sql`, `.vmdk` veya `.vhdx` dosyaları üzerinden veritabanı ve kimlik doğrulama verilerinin çekilmesi. |
| **Sertifika ve Özel Anahtar Avı** | Parolasız veya zayıf parolalı `.pfx`, `.p12` sertifikalarının ele geçirilerek AD CS ve PKINIT saldırı zincirlerine entegre edilmesi. |
| **Kurumsal İzin Hijyeni Denetimi** | Aşırı geniş tanımlanmış (Everyone / Domain Users `Full Control` veya `Read`) ağ dizinlerinin denetlenerek en az yetki prensibine uyumluluğun ölçülmesi. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | Snaffler | SharpShares | PowerView (Find-DomainShare) | smbclient / smbmap |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET Framework) | C# (.NET) | PowerShell | C / Python |
| **Kural Motoru Derinliği** | Gelişmiş Regex & Boyut & İçerik Denetimi | Yalnızca Paylaşım Düzeyi | Temel ACL Denetimi | Manuel / Script tabanlı |
| **İçerik (Dahili Veri) İnceleme** | Evet (Canlı dosya okuma ve regex) | Hayır (Sadece paylaşım listesi) | Hayır | Kısmi / Manuel |
| **Triage / Sınıflandırma** | Otomatik Renk Skalası (Black/Red/Yellow) | Yok | Yok | Yok |
| **Performans ve İş Parçacığı** | Çok Yüksek (Multi-threaded producer/consumer) | Yüksek | Orta / Yavaş | Orta |
| **OPSEC İzi** | Yüksek (Binlerce dosya okuma isteği) | Düşük / Orta | Orta | Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Snaffler, doğrudan komut satırından derlenmiş bir ikili (`Snaffler.exe`) olarak, Cobalt Strike / Havoc gibi C2 ortamlarında `execute-assembly` ile bellek üzerinden veya doğrudan yetkilendirilmiş bir Windows kabuğundan yürütülebilir.

### Genel Sözdizimi
```cmd
Snaffler.exe [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-s`, `--stream` | Çıktıyı dosyaya yazmak yerine anlık olarak standart konsol çıkışına (stdout) akıtır. | *Argümansız bayrak* |
| `-o`, `--outputfile` | Tarama bulgularının yazılacağı yerel dosya yolu. | `-o C:\Temp\snaffler.log` |
| `-d`, `--domain` | Taranacak hedef Active Directory etki alanı adı. Belirtilmezse oturum açılan etki alanı kullanılır. | `-d corp.local` |
| `-c`, `--domaincontroller` | LDAP sorguları için bağlanılacak hedef Etki Alanı Denetleyicisi IP veya FQDN. | `-c dc01.corp.local` |
| `-i`, `--computerlist` | LDAP sorgusu yapmak yerine taranacak hedef bilgisayarların yer aldığı metin dosyası. | `-i targets.txt` |
| `-n`, `--dryrun` | Paylaşımları tarar ancak dosya içeriklerini okumaz (Yalnızca paylaşım keşfi). | *Argümansız bayrak* |
| `-l`, `--interestlevel` | Konsola basılacak minimum ilgi seviyesi (`Black`, `Red`, `Yellow`, `Green`). | `-l Red` |
| `-m`, `--maxfilesize` | Taranacak maksimum dosya boyutu (Bayt cinsinden). Varsayılan 10MB'dır. | `-m 5242880` (5MB) |
| `-r`, `--rulesdir` | Özel Snaffler kural dosyalarının (`.json`) bulunduğu dizin yolu. | `-r C:\Tools\custom_rules` |
| `-t`, `--threads` | Eşzamanlı çalışacak iş parçacığı sayısı (Varsayılan CPU çekirdeğine göre optimize edilir). | `-t 20` |
| `-y`, `--matchsysvol` | Varsayılan olarak atlanan SYSVOL ve NETLOGON paylaşımlarının taranmasını zorlar. | *Argümansız bayrak* |
| `-v`, `--verbosity` | Ayrıntı düzeyi (`Debug`, `Info`, `Warning`, `Error`). | `-v Info` |
| `-b`, `--sharebust` | Gizli paylaşımları (`C$`, `ADMIN$`, `D$`) hedefleyerek agresif paylaşım denetimi yapar. | *Argümansız bayrak* |
| `-u`, `--dfsdiscovery` | DFS (Distributed File System) ad alanlarını LDAP üzerinden sorgulayıp hedefe dahil eder. | *Argümansız bayrak* |
| `-z`, `--configfile` | Önceden yapılandırılmış parametre ve filtre ayarlarını içeren YAML/JSON konfigürasyon dosyası. | `-z config.json` |
| `-x`, `--regex-timeout` | Karmaşık regex kontrolleri için dosya başına tanınan zaman aşımı süresi (saniye). | `-x 15` |
| `-a`, `--scan-archives` | Sıkıştırılmış `.zip` arşivlerinin içine girerek içerik taraması yürütür. | *Argümansız bayrak* |
| `-p`, `--preview-chars` | Regex eşleşmesinde kural tetikleyen metnin çevresinden ekrana basılacak bağlam karakter sayısı. | `-p 100` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanı Genelinde Yüksek İlgi Seviyeli Canlı Akış Taraması
Etki alanındaki tüm bilgisayarların taranması, SYSVOL paylaşımlarının dahil edilmesi ve sadece Red/Black seviyesindeki kritik bulguların stdout akışına yönlendirilmesi.

```cmd
Snaffler.exe -s -y -l Red -o C:\Users\Public\snaffler_critical.log
```

**Örnek Konsol Çıktısı:**
```text
[+] Snaffler 1.0.150 started at 2026-10-14 20:10:00 UTC
[+] Parsing domain controllers for corp.local...
[+] Found 1 Domain Controller: DC01.corp.local (10.0.0.1)
[+] Found 142 computer accounts via LDAP query.
[*] Starting host share discovery using 16 threads...
[+] Host: FS01.corp.local | Share: \\FS01.corp.local\SharedDocs | Access: Read
[+] Host: FS01.corp.local | Share: \\FS01.corp.local\IT_Backups | Access: Read
[!] [Black] [KeepassDatabaseFile] {\Red\Keepass} <\\FS01.corp.local\IT_Backups\Network_Admins.kdbx>
    - LastModified: 2026-08-12 14:22:01 | Size: 18432 bytes
[!] [Black] [RsaPrivateKey] {\Red\SSH} <\\FS01.corp.local\SharedDocs\DevOps\id_rsa>
    - Matched Rule: FileExtension / Content Pattern (BEGIN RSA PRIVATE KEY)
[!] [Red] [ConnectionStringConfig] {\Red\Config} <\\FS01.corp.local\SharedDocs\ERP\web.config>
    - Matched Content: connectionString="Server=SQL01.corp.local;Database=HR;Uid=sa;Pwd=CompanySecret2026!;"
[+] Scanning completed. 142 hosts checked, 39 shares accessible, 3 high-value credentials discovered.
```

### Senaryo 2: Belirli Hedef Listesi Üzerinden Dosya Boyut Sınırlamasıyla Tarama
Yalnızca önceden belirlenmiş kritik dosya sunucularını (`fileservers.txt`) hedef alarak, ağ trafiğini ve bellek tüketimini kontrol altında tutmak için 2MB'den büyük dosyaları atlayarak tarama yürütme.

```cmd
Snaffler.exe -i C:\Temp\fileservers.txt -s -m 2097152 -l Yellow -o C:\Temp\shares_triage.txt
```

### Senaryo 3: Cobalt Strike execute-assembly Üzerinden Bellekte Sessiz Yürütme
EDR disk taramalarından kaçınmak için ikiliyi diske yazmadan bellek içinde çalıştırma ve sonuçları Cobalt Strike Beacon konsolunda yakalama.

```text
beacon> execute-assembly /opt/tools/Snaffler.exe -s -l Black -d corp.local -m 1048576
```

### Senaryo 4: Sadece KeePass, Sertifika ve SSH Anahtarlarını Avlayan Özel Kural Taraması
Gereksiz dosya taramasını önlemek için kural dizinini sınırlandırarak yalnızca kimlik doğrulama anahtarlarına odaklanma.

```cmd
Snaffler.exe -s -r C:\Tools\SnafflerRules\CryptoOnly -l Black -b
```

### Senaryo 5: DFS Ad Alanı (Distributed File System) ve Çoklu Paylaşım Taraması
Büyük kurumsal ağlarda dağınık dosya sunucularını merkezi bir çatı altında toplayan DFS köklerini hedefleyerek gizli şube paylaşımlarını tarama.

```cmd
Snaffler.exe -s -u -y -l Red -o C:\Temp\dfs_shares.log
```

### Senaryo 6: Dizin Dışlama (Exclusion List) ile Performanslı Veri Avı
Geliştirici depoları, node_modules veya derleme çıktıları gibi milyonlarca önemsiz dosya içeren dizinleri atlayarak hedefli tarama gerçekleştirme.

```cmd
Snaffler.exe -s -i C:\Temp\dev_servers.txt -m 1048576 -l Red -v Info
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAP Connection Failure: The server is not operational.` | Hedef etki alanı denetleyicisine TCP 389/636 bağlantısı kurulamıyor veya DNS çözümlenemiyor. | `-c <DC_IP>` parametresi ile DC IP'sini doğrudan belirtin ve etki alanı DNS sunucularını kontrol edin. |
| `System.UnauthorizedAccessException: Access to the path is denied.` | Taranan paylaşıma veya dizine geçerli kullanıcının SMB okuma hakkı (DACL) bulunmuyor. | Normal bir durumdur; Snaffler erişemediği dizinleri atlayarak devam eder. Daha yüksek izinli bir kullanıcı bağlamında çalıştırın. |
| `OutOfMemoryException during share enumeration.` | Çok geniş dosya yapılarında iş parçacığı kuyruğunun bellek sınırını aşması. | `-m 1048576` (1MB sınır) ekleyin, `-t 8` ile iş parçacığını düşürün veya hedef dizinleri `-i` dosyası ile parçalara bölün. |
| `System.IO.IOException: The network path was not found.` | Hedef bilgisayar kapalı, SMB servisi devre dışı veya ana makine tabanlı güvenlik duvarı TCP 445 portunu engelliyor. | Tarama öncesinde `Test-NetConnection -Port 445` ile erişilebilir makineleri filtreleyip listeyi `-i` bayrağıyla besleyin. |
| `No rules found or loaded.` | Belirtilen kural dizini boş veya Snaffler'ın varsayılan dahili kuralları derleme sırasında hasar görmüş. | `-r` bayrağını kaldırarak gömülü kuralları kullanın veya resmi depodan güncel kural JSON dosyalarını temin edin. |
| `Logon failure: unknown user name or bad password.` | Mevcut Windows oturum bileti (Kerberos) zaman aşımına uğramış veya geçersiz kılınmış. | `klist` ile biletleri kontrol edin; `klist purge` ve yeniden kimlik doğrulama yaparak geçerli TGT temin edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

Snaffler, yapısı gereği son derece gürültülü (noisy) bir araçtır. Kısa bir zaman dilimi içinde yüzlerce ana makineye SMB bağlantısı kurar, binlerce `Tree Connect` ve dosya açma (`IRP_MJ_CREATE`) işlemi gerçekleştirir.

```
[Snaffler Çalıştırması]
        │
        ├──> LDAP Taraması (Computer Query) ───> Event ID 1644 / LDAP Profiling
        │
        ├──> SMB Oturum Açma (Logon Type 3) ──> Event ID 4624 (Hedef Sunucularda)
        │
        ├──> Ağ Paylaşımı Bağlantısı ─────────> Event ID 5140 (Share Accessed)
        │
        └──> Milyonlarca Dosya İnceleme ────────> Event ID 5145 (Ayrıntılı Paylaşım Denetimi)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Security Event ID 4624 (Logon Type 3):** Snaffler'ın bağlandığı tüm sunucu ve iş istasyonlarında ağ oturumu açma kaydı oluşur.
* **Security Event ID 5140 / 5145:** Ağ paylaşımlarına erişim ve özellikle `AccessMask: 0x1` (ReadData) veya `0x80` (ReadAttributes) olayları loglanır. Kısa sürede tek bir IP'den yüzlerce dosyaya erişim EDR/SIEM korelasyonlarında anomalidir.
* **Sysmon Event ID 3 (Network Connection):** `Snaffler.exe` sürecinin hedef IP'lerin 445 portuna yönelik kitlesel bağlantı kayıtları.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Discovery** | [T1083](https://attack.mitre.org/techniques/T1083/) | File and Directory Discovery | Ağ paylaşımlarındaki dosya sistemlerinin ve hiyerarşinin listelenmesi. |
| **Discovery** | [T1135](https://attack.mitre.org/techniques/T1135/) | Network Share Discovery | `NetShareEnum` API ve SMB protokolü ile ağ paylaşımlarının tespiti. |
| **Credential Access** | [T1552.001](https://attack.mitre.org/techniques/T1552/001/) | Credentials in Files | Parola, özel anahtar, KeePass ve API secret dosyalarının avlanması. |
| **Collection** | [T1039](https://attack.mitre.org/techniques/T1039/) | Data from Network Shared Drive | Uzak paylaşımlardan hassas kurumsal verilerin toplanması. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Ağ Anomali Alarmı** | Tek kaynaktan etki alanındaki tüm IP'lerin 445 portuna eşzamanlı bağlantı açılması. | `-d` ile tüm etki alanını taramak yerine `-i` ile hedefli 3-5 kritik sunucu seçin; `-t 2` ile iş parçacığını düşürün. |
| **Disk İmzası (AV/EDR)** | Standart derlenmiş `Snaffler.exe` ikilisinin bilinen statik imzalara sahip olması. | İkiliyi obfuscate ederek derleyin veya C2 üzerinden `execute-assembly` ile doğrudan bellekten yürütün. |
| **Hassas Dosya Alarmı (Canary/Trap)** | Kuruluşun bilerek paylaşıma yerleştirdiği bal küpü (honeypot) `.kdbx` dosyalarının okunması. | Dosya tarihçesini ve üst dizin yapısını analiz etmeden her bulguyu toplu indirmeyin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (Kısa Sürede Anormal Dosya Paylaşımı Erişimi)
```yaml
title: Mass Network Share Access by Single Host (Snaffler Behavior)
id: d4b3c2a1-8765-4321-fedc-ba9876543210
status: experimental
description: Tek bir istemci IP adresinden çok kısa bir zaman aralığında aşırı sayıda SMB dosya okuma işlemi tespit edildi.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5145
    AccessMask: '0x1'
  filter:
    ShareName:
      - '*\\SYSVOL'
      - '*\\NETLOGON'
  timeframe: 1m
  condition: selection and not filter | count(RelativeTargetName) by IpAddress > 200
falsepositives:
  - Yedekleme yazılımları (Veeam, Commvault)
  - Antivirüs merkezi tarama motorları
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 5145
| where AccessMask in ("0x1", "0x80", "0x120089")
| where RelativeTargetName endswith ".kdbx" or RelativeTargetName endswith ".pfx" or RelativeTargetName endswith "id_rsa" or RelativeTargetName endswith "web.config"
| summarize DiscoveredFilesCount = count(), AccessedFiles = make_set(RelativeTargetName, 50) by IpAddress, SubjectUserName, bin(TimeGenerated, 5m)
| where DiscoveredFilesCount > 3
| order by DiscoveredFilesCount desc
```

#### YARA Kuralı
```yara
rule Snaffler_Tool_Detection {
    meta:
        description = "Snaffler veri avlama ve ağ paylaşımı analiz aracı tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/SnaffCon/Snaffler"
    strings:
        $s1 = "Snaffler" ascii wide nocase
        $s2 = "SnaffCore" ascii wide
        $s3 = "KeepassDatabaseFile" ascii wide
        $s4 = "TriageRule" ascii wide
        $s5 = "[Black]" ascii wide
        $s6 = "[Red]" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Access-Based Enumeration (ABE) Etkinleştirme:** Dosya sunucusu paylaşımlarında ABE etkinleştirildiğinde, kullanıcılar yalnızca NTFS okuma iznine sahip oldukları klasör ve dosyaları görebilir. Bu durum, yetkisiz saldırganların ağaç yapısını keşfetmesini engeller.
* **Gereksiz Paylaşımların Kaldırılması ve İzin Hijyeni:** `Everyone` veya `Domain Users` gruplarına verilen genel `Read` izinleri incelenmeli, en az yetki (Least Privilege) ilkesi gereği paylaşımlar rol bazlı güvenlik gruplarıyla sınırlandırılmalıdır.
* **SYSVOL / NETLOGON Temizliği:** Eski Grup İlkesi Tercihleri (`GPP cpassword`) içeren XML dosyaları, açık şifreli VBS/BAT betikleri denetlenerek merkezi Active Directory politikalarından arındırılmalıdır.
* **Deception / Bal Küpü (Canary Files):** Kritik dosya sunucularına saldırganların ilgisini çekecek sahte `passwords.kdbx` veya `connectionstrings.config` dosyaları yerleştirilmeli; bu dosyalara erişim yapıldığı anda Security Event ID 5145 tetiklenerek SOC ekibine yüksek öncelikli alarm iletilmelidir.
* **Merkezi Parola Kasası ve Gizli Yönetimi (Privileged Access Management):** Açık metin konfigürasyon parolaları yerine Azure Key Vault, HashiCorp Vault veya CyberArk gibi kurumsal kasa çözümleri kullanılmalı, kod depolarında ve paylaşımlarda şifresiz kimlik bilgisi tutulması yasaklanmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Temel Canlı Akış Taraması (Sadece Red ve Black Bulgular)
Snaffler.exe -s -l Red

# 2. SYSVOL ve NETLOGON Dahil Tam Etki Alanı Taraması
Snaffler.exe -s -y -l Red -o C:\Temp\snaffler_full.txt

# 3. Yalnızca Belirli Sunucu Listesini Tarama
Snaffler.exe -i C:\Temp\targets.txt -s -l Red

# 4. Dosya Boyutunu 1MB ile Sınırlayarak Hızlı Triage
Snaffler.exe -s -m 1048576 -l Red

# 5. Gizli Paylaşımları (C$, ADMIN$) Zorlayarak Tarama
Snaffler.exe -s -b -l Red -o C:\Temp\hidden_shares.log

# 6. İş Parçacığı Sayısını Düşürerek Düşük Gürültülü Çalıştırma
Snaffler.exe -s -t 4 -l Black -i C:\Temp\critical_srv.txt

# 7. Sadece Dosya ve Paylaşım İsimlerini Keşfetme (İçerik İnceleme Yok)
Snaffler.exe -s -n -l Yellow

# 8. Özel Kural Setiyle Kriptografik Anahtar ve Sertifika Avı
Snaffler.exe -s -r C:\Tools\Rules\CryptoOnly -l Black

# 9. Belirli Bir Etki Alanı ve Denetleyici Belirterek Tarama
Snaffler.exe -s -d corp.local -c 10.0.0.1 -l Red

# 10. Hata Ayıklama (Debug) Seviyesinde Detaylı Günlükleme
Snaffler.exe -s -v Debug -l Green -o C:\Temp\snaffler_debug.log
```

### Komut Detay Analizleri

#### 1. Temel Canlı Akış Taraması (Sadece Red ve Black Bulgular)
* **Ne Yapar?:** Etki alanındaki tüm bilgisayarları sorgular, okunabilir paylaşımları bulur ve regex kural motorunda yalnızca en kritik (Black ve Red) bulguları anlık olarak ekrana basar.
* **Ne Zaman Kullanılır?:** Operasyon sırasında vakit kaybetmeden doğrudan parola, özel anahtar veya KeePass dökümlerine ulaşılmak istendiğinde.
* **Parametreler:**
  * `-s`: Standard output üzerinden canlı akış sağlar.
  * `-l Red`: Red ve üzeri (Red ve Black) ilgi düzeyine sahip bulguları filtreler.

#### 2. SYSVOL ve NETLOGON Dahil Tam Etki Alanı Taraması
* **Ne Yapar?:** Varsayılan olarak taranmayan etki alanı ilke dizinlerini (`SYSVOL`, `NETLOGON`) de incelemeye dahil ederek grup politikaları içindeki şifreleri (`GPP`) ve scriptleri arar.
* **Ne Zaman Kullanılır?:** Etki alanı ilkeleri içinde unutulmuş servis hesabı parolalarını veya otomasyon betiklerini ortaya çıkarmak için.
* **Parametreler:**
  * `-y`: SYSVOL/NETLOGON paylaşımlarını analiz kuyruğuna ekler.
  * `-o C:\Temp\snaffler_full.txt`: Tüm çıktıları belirtilen yerel metin dosyasına kaydeder.

#### 3. Yalnızca Belirli Sunucu Listesini Tarama
* **Ne Yapar?:** Etki alanının tamamına gürültülü LDAP sorgusu atmak yerine sadece sağlanan metin dosyasındaki sunucuları hedefler.
* **Ne Zaman Kullanılır?:** Tespit riskini minimize etmek ve sadece dosya sunucusu veya yedekleme sunucusu rolündeki 2-3 makineyi denetlemek istendiğinde.
* **Parametreler:**
  * `-i C:\Temp\targets.txt`: Hedef ana makine isimlerinin veya IP'lerinin bulunduğu dosya.

#### 4. Dosya Boyutunu 1MB ile Sınırlayarak Hızlı Triage
* **Ne Yapar?:** Boyutu 1 MB'tan büyük dosyaları okumayı reddeder, böylece ISO, VMDK, devasa yedekler gibi bant genişliği tüketen dosyaları atlar.
* **Ne Zaman Kullanılır?:** Yavaş WAN ağlarında veya düşük bant genişlikli VPN tünelleri üzerinden test yürütülürken performansı korumak için.
* **Parametreler:**
  * `-m 1048576`: Maksimum incelenecek dosya boyutunu 1,048,576 bayt (1 MB) ile sınırlar.

#### 5. Gizli Paylaşımları (C$, ADMIN$) Zorlayarak Tarama
* **Ne Yapar?:** Yalnızca açıkça paylaşıma sunulmuş dizinleri değil, varsayılan yönetimsel paylaşımları (`C$`, `ADMIN$`, `D$`) da zorlar.
* **Ne Zaman Kullanılır?:** Yetkili bir hesap ele geçirildiğinde tüm disk bölüntülerindeki kritik kullanıcı profillerini ve `web.config` dosyalarını taramak için.
* **Parametreler:**
  * `-b`: Paylaşım patlatma (share busting) özelliğini etkinleştirir.

#### 6. İş Parçacığı Sayısını Düşürerek Düşük Gürültülü Çalıştırma
* **Ne Yapar?:** Eşzamanlı ağ bağlantı sayısını 4 iş parçacığına düşürerek ağ anahtarları ve SIEM sistemleri üzerindeki ani trafik sıçramalarını engeller.
* **Ne Zaman Kullanılır?:** OPSEC kısıtlamalarının yüksek olduğu, EDR/SIEM anomalilerinin sıkı izlendiği kurumsal ağlarda.
* **Parametreler:**
  * `-t 4`: Maksimum çalışan iş parçacığı (threads) sayısını 4 ile sınırlar.
  * `-l Black`: Sadece tartışmasız en değerli bulguları bildirir.

#### 7. Sadece Dosya ve Paylaşım İsimlerini Keşfetme (İçerik İnceleme Yok)
* **Ne Yapar?:** Paylaşımları ve dosya adlarını listeler ancak dosyaların içine girip regex taraması yapmaz (dry run).
* **Ne Zaman Kullanılır?:** Ağ bant genişliği harcamadan sadece dosya adlarından (`passwords.txt`, `backup.kdbx`) ön keşif yapmak için.
* **Parametreler:**
  * `-n`: Dry-run modunu etkinleştirir.

#### 8. Özel Kural Setiyle Kriptografik Anahtar ve Sertifika Avı
* **Ne Yapar?:** Snaffler'ın varsayılan genel kurallarını devre dışı bırakıp operatör tarafından hazırlanan özel kural dizinini yükler.
* **Ne Zaman Kullanılır?:** Hedeflenen özel bir yazılımın lisans dosyaları veya özel donanım anahtarları aranırken.
* **Parametreler:**
  * `-r C:\Tools\Rules\CryptoOnly`: Belirtilen dizindeki kural JSON'larını okur.

#### 9. Belirli Bir Etki Alanı ve Denetleyici Belirterek Tarama
* **Ne Yapar?:** Bulunulan makinenin oturum açtığı etki alanından farklı bir güvenilen (trusted) etki alanını hedef alır.
* **Ne Zaman Kullanılır?:** Forest trust veya external trust ilişkisi üzerinden hedef kuruluşa geçiş yapıldığında.
* **Parametreler:**
  * `-d corp.local`: Hedef etki alanının adı.
  * `-c 10.0.0.1`: Hedef etki alanı denetleyicisinin IP adresi.

#### 10. Hata Ayıklama (Debug) Seviyesinde Detaylı Günlükleme
* **Ne Yapar?:** Erişilemeyen paylaşımlar, reddedilen izinler ve ağ zaman aşımları dahil olmak üzere tüm operasyonel adımları günlüğe yazar.
* **Ne Zaman Kullanılır?:** Ağ yapılandırmasındaki erişim sorunlarını ve izin problemlerini analiz etmek amacıyla.
* **Parametreler:**
  * `-v Debug`: En ayrıntılı çıktı modunu seçer.
  * `-l Green`: Tüm ilgi seviyelerini rapora yansıtır.

---

## Kaynaklar
* [Snaffler Resmi GitHub Deposu](https://github.com/SnaffCon/Snaffler)
* [MITRE ATT&CK: Network Share Discovery (T1135)](https://attack.mitre.org/techniques/T1135/)
* [Microsoft Dokümantasyonu: NetShareEnum API](https://learn.microsoft.com/en-us/windows/win32/api/lmshare/nf-lmshare-netshareenum)

---

> **Önceki:** [← Tokenvator (Kategori 09)](../Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/Tokenvator.md) · **Sonraki:** [SharpShares →](./SharpShares.md)
