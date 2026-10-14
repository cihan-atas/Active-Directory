# gpresult

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows yerleşik Grup İlkesi (GPO) tanılama aracı; uygulanan ilkeleri, LSDOU hiyerarşisini, AppLocker kurallarını ve RSoP (Resultant Set of Policy) raporunu dökme (`/r`, `/v`, `/h`).

---

## 1. Genel Bakış ve Amaç

`gpresult.exe`, Windows 2000 ve Windows XP'den bu yana tüm modern Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\gpresult.exe`) bulunan, istemci ve sunucu sistemlerinde etkin olan **Grup İlkesi Nesnelerini (Group Policy Objects - GPO)** ve **İlke Sonuç Kümesini (Resultant Set of Policy - RSoP)** sorgulayan yerel bir LOLBin aracıdır.

Active Directory ortamlarında etki alanı yöneticileri, binlerce bilgisayar ve kullanıcıyı merkezi olarak yönetmek, güvenlik sıkılaştırması (hardening) uygulamak, **AppLocker / SRP** uygulama beyaz listeleme kurallarını dağıtmak, başlangıç/oturum komut dosyaları (**Startup / Logon Scripts**) tanımlamak ve yerel yönetici parolalarını yönetmek (**LAPS**) için Grup İlkelerini kullanır.

Red Team ve sızma testi operasyonlarında `gpresult.exe`, saldırganın hedef uç noktada uygulanan savunma mekanizmalarını (AppLocker kural setleri, PowerShell kısıtlamaları, parola politikaları), merkezi script'lerde saklanan açık metin kimlik bilgilerini ve etki alanındaki Organizasyonel Birim (OU) yapısını hiçbir harici araç yüklemeden açığa çıkarması için en kritik **Discovery (T1615)** aracıdır.

### Protokol ve Çalışma Prensibi

`gpresult`, işletim sisteminin WMI (Windows Management Instrumentation) alt yapısında tutulan RSoP veri tabanını (`root\rsop\computer` ve `root\rsop\user`) sorgular:

```
┌──────────────────────────────────────────────────────────────┐
│                    Kullanıcı Komut Kabuğu                    │
│                      [ gpresult.exe ]                        │
└──────────────────────────────┬───────────────────────────────┘
                               │
               1. WMI Sorgusu (root\rsop\computer & user)      
               2. Registry Önbelleği (HKLM\Software\Policies)   
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                  İlke Sonuç Kümesi (RSoP)                    │
│                                                              │
│  LSDOU Sıralaması: Local -> Site -> Domain -> OU             │
│  - Uygulanan GPO'lar (Applied GPOs)                          │
│  - Reddedilen / Filtrelenen GPO'lar (WMI / Security Filter)   │
│  - AppLocker / Software Restriction Kuralları                │
│  - Başlangıç / Oturum Script Yolları (SYSVOL)                │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Raporlama Çıktıları
         - Metin / Konsol Formatı (/r, /v, /z)
         - Görsel HTML Raporu (/h report.html)
         - Yapılandırılmış XML (/x report.xml)
```

1. **LSDOU Hiyerarşisi:** Grup ilkeleri sırasıyla **Local -> Site -> Domain -> OU (Organizational Unit)** sırasıyla uygulanır. Son uygulanan ilke öncekilerin üzerine yazar (precedence). `gpresult`, bu çakışmaları çözerek uç noktada nihai olarak hangi ayarın geçerli olduğunu (Winning GPO) raporlar.
2. **Kapsam Ayrımı (Computer vs User Scope):** Bilgisayar ilkeleri makinenin kendi hesabına (`MACHINE$`), kullanıcı ilkeleri ise oturum açmış kişiye uygulanır. Bilgisayar kapsamındaki güvenlik ayarlarını (`/scope computer`) görmek için **Yönetici (Elevated)** yetkisi gerekirken, kullanıcı kapsamı (`/scope user`) düşük yetkiyle görüntülenebilir.
3. **SYSVOL ve Script Tespiti:** GPO ile dağıtılan başlangıç (startup) veya oturum açma (logon) betikleri, etki alanı denetleyicisinin `\\<Domain>\SYSVOL\<Domain>\Policies\<GUID>\...` paylaşımında barındırılır. `gpresult /v` bu betiklerin tam ağ yollarını dökerek saldırganın bu dosyalarda gömülü parola aramasına imkan tanır.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **AppLocker ve WDAC Keşfi** | Sistemde hangi uzantıların (`.exe`, `.ps1`, `.dll`) hangi klasörlerden (`C:\Windows\*`) çalıştırılmasına izin verildiğini öğrenme. |
| **GPO Script'lerinde Parola Avı** | Startup/Logon script yollarını bularak SYSVOL üzerindeki `.bat`, `.vbs`, `.ps1` dosyalarında sabit kodlanmış kimlik bilgilerini arama. |
| **LAPS Durumu Tespiti** | Makinede LAPS (Local Administrator Password Solution) politikasının etkin olup olmadığını doğrulama. |
| **Merkezi Savunma Analizi** | Windows Defender, PowerShell Script Block Logging ve Güvenlik Duvarı kurallarının merkezi olarak zorlanıp zorlanmadığını anlama. |
| **Görsel HTML Raporlama** | Tüm sistem ve kullanıcı yapılandırmasını tek bir HTML dosyası olarak dışa aktarma (`/h report.html`). |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `gpresult.exe` | `Get-GPOReport (PowerShell)` | `rsop.msc` (GUI) | `SharpGPOAbuse` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | RSAT / GPMC modülü gerektirir | Windows İstemcilerinde hazır (GUI) | Harici C# Binary |
| **Çalıştırma Ortamı** | CLI (Komut Satırı / Web Shell) | PowerShell CLI | GUI (RDP / Masaüstü) | CLI / Bellek İçi |
| **Yetki İhtiyacı** | User için Düşük, Computer için Admin | Domain User (Okuma izni) | User için Düşük, Computer için Admin | GPO Yazma Hakkı Gerekir |
| **Rapor Çıktısı** | Konsol, HTML, XML | XML, HTML | GUI Konsol Ağacı | Yok (İstismar aracı) |
| **EDR Algısı** | Düşük (Meşru Windows Tanı Aracı) | Script Block Logging (EID 4104) | Sıfır (GUI) | Yüksek (.NET Assembly) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
gpresult [/s <sunucu> [/u <kullanıcı> [/p <parola>]]] [/user [<hedef_kullanıcı>]] [/scope {user | computer}] {/r | /v | /z | /x <xml_dosya> | /h <html_dosya>}
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `/r` | RSoP özet verisini listeler (Uygulanan ve reddedilen GPO'lar, güvenlik grupları). | `gpresult /r` |
| `/v` | Ayrıntılı (Verbose) çıktı üretir; her ilkenin altındaki spesifik ayarları gösterir. | `gpresult /v` |
| `/z` | Süper ayrıntılı (Debug) çıktı üretir; güvenlik ayarlarını, kayıt defteri değerlerini döker. | `gpresult /z` |
| `/scope {user \| computer}` | Yalnızca kullanıcı veya yalnızca bilgisayar düzeyindeki ilkeleri sorgular. | `gpresult /scope computer /r` |
| `/h <dosya_yolu>` | Tüm ilke sonuçlarını görsel ve aranabilir bir HTML raporu olarak kaydeder. | `gpresult /h C:\Temp\report.html /f` |
| `/x <dosya_yolu>` | İlke sonuçlarını XML formatında dışa aktarır (Otomasyon ve script parsing için). | `gpresult /x C:\Temp\report.xml /f` |
| `/f` | `/h` veya `/x` kullanıldığında hedef dosyanın üzerine yazmayı zorlar (Force). | `gpresult /h report.html /f` |
| `/user <kullanıcı>` | Belirtilen kullanıcının RSoP verilerini sorgular (Yönetici yetkisi gerektirir). | `gpresult /user jdoe /r` |
| `/s <sunucu>` | Uzaktaki bir bilgisayarın GPO durumunu WMI/RPC üzerinden sorgular. | `gpresult /s SRV01 /r` |
| `/u <kullanıcı>` | Uzak sorgu (`/s`) için kimlik bilgisi kullanıcı adı. | `gpresult /s SRV01 /u LAB\admin` |
| `/p <parola>` | Uzak sorgu için parola. | `/p P@ssw0rd2026!` |

### Modül ve Yetenek Şeması

```
gpresult.exe Yetenek Ağacı
├── 1. Hızlı Özet ve Durum Tespiti
│   ├── gpresult /r                    (Genel RSoP özeti)
│   ├── gpresult /scope computer /r    (Yalnızca makine GPO'ları)
│   └── gpresult /scope user /r        (Yalnızca kullanıcı GPO'ları)
├── 2. Ayrıntılı Güvenlik Analizi
│   ├── gpresult /v                    (Ayrıntılı ilke değerleri)
│   └── gpresult /z                    (Süper detaylı kayıt defteri ve ACL'ler)
├── 3. Rapor Dışa Aktarma (Exfiltration)
│   ├── gpresult /h <dosya.html> /f    (Görsel HTML raporu)
│   └── gpresult /x <dosya.xml> /f     (Script parsing için XML)
└── 4. Uzak Sistem Sorgusu (WMI/RPC)
    └── gpresult /s <sunucu> /r        (Uzak sunucu GPO analizi)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Hızlı RSoP Özeti — Uygulanan ve Reddedilen GPO'ları Listeleme

Sisteme sızıldığında hangi kurumsal ilkelerin uygulandığını görmek için:

```cmd
gpresult /r
```

**Örnek Çıktı Analizi:**
```text
RSOP data for LAB\jdoe on WORKSTATION01 : Logging Mode
------------------------------------------------------

OS Configuration:            Member Workstation
OS Version:                  10.0.19045
Site Name:                   Default-First-Site-Name
Roaming Profile:             N/A
Local Profile:               C:\Users\jdoe
Connected over a slow link?: No

USER SETTINGS
--------------
    Applied Group Policy Objects
    ----------------------------
        Default Domain Policy
        SecOps - Password and Lockout Policy
        IT - Desktop Restrictions

    The following GPOs were not applied because they were filtered out
    -------------------------------------------------------------------
        Local Group Policy
            Filtering:  Not Applied (Empty)
        HR Department Policies
            Filtering:  Denied (Security)
```
- `Applied Group Policy Objects`: Kullanıcıya uygulanan aktif GPO'ların tam adlarını listeler.
- `The following GPOs were not applied... (Denied Security)`: Kullanıcının üyesi olmadığı veya WMI filtresine takılan ilkeleri gösterir; bu da etki alanındaki diğer departmanların ve politikaların varlığını kanıtlar.

---

### Senaryo 2: Yalnızca Bilgisayar Düzeyindeki (AppLocker, LAPS) İlkeleri İnceleme

Kullanıcı gürültüsünden kaçınarak yalnızca makine politikalarını incelemek:

```cmd
gpresult /scope computer /r
```

**Örnek Çıktı:**
```text
COMPUTER SETTINGS
------------------
    Applied Group Policy Objects
    ----------------------------
        Default Domain Controllers Policy
        SecOps - Endpoint Hardening
        SecOps - LAPS Deployment
        AppLocker - Enforce Executable Rules
```
- `SecOps - LAPS Deployment`: Hedef sistemde LAPS'ın aktif olduğunu gösterir; yerel `Administrator` parolasının her makinede farklı ve rastgele olduğunu doğrular.
- `AppLocker - Enforce Executable Rules`: Sistemde AppLocker uygulama beyaz listelemesinin zorunlu olduğunu gösterir; rastgele bir EXE çalıştırılmadan önce bypass yöntemleri (LOLBins veya DLL Hijacking) araştırılmalıdır.

---

### Senaryo 3: Ayrıntılı HTML Raporu Çıkarma ve Veri Sızdırma

Komut satırı metninde kaybolmak yerine, yüzlerce ilkeyi tarayıcıda incelenebilir grafiksel bir HTML raporuna dönüştürmek:

```cmd
gpresult /h C:\Windows\Temp\gpreport.html /f
```
- Üretilen `gpreport.html` dosyası indirildiğinde (veya SMB paylaşımına kopyalandığında), AppLocker kuralları, PowerShell Script Block Logging, NTLM kısıtlamaları ve kayıt defteri ayarları tek ekranda tablo halinde incelenebilir.

---

### Senaryo 4: Başlangıç ve Oturum Script'lerini (Startup Scripts) Tespit Etme

Yöneticilerin SYSVOL üzerinde bıraktığı script'leri açığa çıkarmak:

```cmd
gpresult /v | findstr /I "Scripts .bat .vbs .ps1 \\SYSVOL"
```

**Örnek Çıktı:**
```text
            GPO: IT - Drive Mappings and Scripts
                Folder: \\lab.local\sysvol\lab.local\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\User\Scripts\Logon
                Script: map_drives.bat
```
Saldırgan doğrudan bu ağ yolundaki dosyayı okuyarak açık parolaları avlar:
```cmd
type \\lab.local\sysvol\lab.local\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\User\Scripts\Logon\map_drives.bat
```

---

### Senaryo 5: Süper Ayrıntılı (Debug) Çıktı ile Güvenlik Ayarlarını Dökme

Kayıt defteri anahtarlarını, Denetim (Audit) politikalarını ve Kısıtlı Grupları (Restricted Groups) listelemek:

```cmd
gpresult /z
```

---

### Senaryo 6: Uzak Bir Sunucunun Grup İlkelerini WMI Üzerinden Sorgulama

Yanal hareket öncesinde ele geçirilen yönetici kimliğiyle uzak sunucudaki ilkeleri denetleme:

```cmd
gpresult /s SRV-FILE01.lab.local /r
```

---

### Senaryo 7: PowerShell ile XML Raporunu Parse Edip Uygulanan GPO Listesini Çıkaran Betik

`gpresult /x` çıktısını yapılandırılmış veri olarak ayrıştıran PowerShell otomasyonu:

```powershell
# gpresult XML çıktısını nesneleştiren betik:
$xmlPath = "$env:TEMP\rsop.xml"
gpresult /x $xmlPath /f | Out-Null

[xml]$rsop = Get-Content $xmlPath

Write-Host "[*] Uygulanan Bilgisayar GPO'ları:" -ForegroundColor Cyan
$rsop.Rsop.ComputerResults.GPO | Where-Object { $_.AppliedOrder -ne $null } | Select-Object AppliedOrder, Name, Guid | Format-Table -AutoSize

Write-Host "[*] Uygulanan Kullanıcı GPO'ları:" -ForegroundColor Green
$rsop.Rsop.UserResults.GPO | Where-Object { $_.AppliedOrder -ne $null } | Select-Object AppliedOrder, Name, Guid | Format-Table -AutoSize

Remove-Item $xmlPath -Force
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `INFO: The user does not have RSOP data.` | Belirtilen kullanıcının bu makinede henüz yerel bir oturumu veya profili oluşmamıştır (Etkileşimli oturum açmamıştır). | Kullanıcının etkileşimli oturum açmasını sağlayın veya komutu oturumu açık olan kullanıcı bağlamında çalıştırın. |
| `ERROR: Access is denied.` | `/scope computer` parametresi veya `/user <baskasi>` komutu çağrılırken komut istemcisi yükseltilmemiştir (Local Admin gereklidir). | Komut istemcisini "Run as Administrator" (High Integrity) olarak çalıştırın veya yalnızca düşük yetkili kullanıcı kapsamını sorgulayın: `gpresult /scope user /r`. |
| `ERROR: The RPC server is unavailable.` | `/s <uzak_sunucu>` çalıştırıldığında hedef sunucuda WMI / RPC (TCP 135) portu güvenlik duvarı tarafından engellenmektedir. | Hedef makinede Windows Güvenlik Duvarı WMI kurallarını kontrol edin veya komutu uzak makinenin kendi içinde (WinRM / PsExec ile) çalıştırın. |
| `ERROR: Invalid syntax.` | Parametre sıralaması yanlıştır; örneğin `/h` veya `/x` parametresinden sonra dosya adı belirtilmemiştir. | Doğru sözdizimini kullanın: `gpresult /h C:\Temp\report.html /f`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `gpresult.exe` çalıştırılması, komut satırı argümanları (`/r`, `/v`, `/h`, `/scope computer`) ve üst süreç bilgisi kaydedilir.
  - **WMI-Activity Olay Günlükleri:** `Microsoft-Windows-WMI-Activity/Operational` günlüğünde WMI RSoP sorguları (Event ID 5857 ve 5858) loglanır.
  - **Sysmon Event ID 11 (File Create):** `/h` veya `/x` kullanıldığında diske yazılan HTML/XML rapor dosyaları kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **LOLBin / Güvenilir Dosya:** `gpresult.exe` Microsoft tarafından imzalı bir işletim sistemi aracı olduğundan dosya bütünlüğü denetimlerinden (AppLocker) geçer.
- **EDR Komut Satırı Tespiti:** Arka arkaya `gpresult /h` veya `gpresult /r` çağrılması, EDR sistemleri tarafından **Discovery: Group Policy Discovery (MITRE T1615)** davranışı olarak tespit edilip düşük/orta önem dereceli bir keşif etkinliği olarak alarm üretebilir.
- **Ağ Seviyesinde İz:** Tamamen yerel WMI RSoP veritabanını okuduğu için ağda hiçbir anomali veya paket oluşturmaz (Uzak `/s` parametresi kullanılmadığı sürece).

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1615** | Group Policy Discovery | Etki alanında uygulanan GPO'ları, AppLocker ve parola politikalarını keşfetme. |
| **T1082** | System Information Discovery | İşletim sistemi sürümü, etki alanı adı ve Active Directory Site tespiti. |
| **T1069.001 / .002** | Permission Groups Discovery | RSoP çıktısındaki kullanıcı güvenlik gruplarını listeleme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Komut Satırı ve Rapor Dosyası Tespiti** | Diske `gpreport.html` gibi belirgin isimli dosyalar yazmak yerine çıktıyı doğrudan belleğe (`Out-String`) alın veya doğrudan kayıt defterindeki GPO anahtarlarını okuyun: `reg query "HKLM\Software\Policies"`. |
| **GPO Script Keşfinde SYSVOL Alarmı** | SYSVOL üzerindeki script dosyalarını doğrudan açmak yerine, dosyanın hash'ini veya çevrimdışı yedeğini kontrol edin. |
| **Uzak Sorgu Gürültüsü** | `/s <sunucu>` ile uzaktan WMI sorgusu yapmak ağ IDS'lerinde gürültü yaratır; bunun yerine hedef makinede oturum elde ettikten sonra yerel olarak çalıştırın. |

### 5.5 Savunma Karşılığı (Blue Team)

- **WMI Denetimi:** GPO sorgularını izlemek için `Microsoft-Windows-WMI-Activity/Operational` günlüğünü SIEM platformlarına iletin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Group Policy Discovery via Gpresult
  status: medium
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\gpresult.exe'
          CommandLine|contains:
              - '/r'
              - '/v'
              - '/z'
              - '/h '
              - '/scope '
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Uygulanan GPO'ların Standart Özetini Alma
```cmd
gpresult /r
```
- **Ne Yapar?** Kullanıcıya ve bilgisayara uygulanan tüm GPO'ları, filtrelenen ilkeleri ve güvenlik gruplarını konsola döker.
- **Ne Zaman Kullanılır?** İlk sistem keşfinde uygulanan politikaları tek bakışta görmek için.
- **Parametreler:** `/r` (RSoP özet modu).

### 6.2 Yalnızca Bilgisayar (Machine) İlkelerini Görüntüleme
```cmd
gpresult /scope computer /r
```
- **Ne Yapar?** Kullanıcı ilkelerini atlayarak yalnızca makine düzeyindeki politikaları (AppLocker, LAPS, BitLocker) listeler.
- **Ne Zaman Kullanılır?** Sistem düzeyindeki güvenlik sıkılaştırmalarını analiz etmek için (Yönetici yetkisi gerektirir).
- **Parametreler:** `/scope computer`, `/r`.

### 6.3 Yalnızca Kullanıcı (User) İlkelerini Görüntüleme
```cmd
gpresult /scope user /r
```
- **Ne Yapar?** Yalnızca mevcut oturum açmış kullanıcıya uygulanan masaüstü ve güvenlik kısıtlamalarını gösterir.
- **Ne Zaman Kullanılır?** Düşük yetkili bir kabukta kullanıcıya özel kısıtlamaları incelemek için.
- **Parametreler:** `/scope user`, `/r`.

### 6.4 Tüm İlkeleri Ayrıntılı HTML Raporu Olarak Kaydetme
```cmd
gpresult /h C:\Windows\Temp\gp.html /f
```
- **Ne Yapar?** Tüm kullanıcı ve bilgisayar ilkelerini renkli, sekmeli ve aranabilir bir HTML dosyasına kaydeder.
- **Ne Zaman Kullanılır?** Yüzlerce ilkeyi tarayıcıda grafik arayüzle detaylı incelemek ve dışa aktarmak için.
- **Parametreler:** `/h <dosya>` (HTML çıktısı), `/f` (Üzerine yazmayı zorlar).

### 6.5 Tüm Detayları ve Güvenlik Ayarlarını Dökme
```cmd
gpresult /z
```
- **Ne Yapar?** Güvenlik ilkelerinin, kayıt defteri değerlerinin ve denetim ayarlarının en derin teknik detaylarını döker.
- **Ne Zaman Kullanılır?** Belirli bir politikanın kayıt defteri karşılığını veya tam değerini bulmak için.
- **Parametreler:** `/z` (Süper ayrıntılı debug modu).

### 6.6 Sonuçları XML Olarak Dışa Aktarma
```cmd
gpresult /x C:\Windows\Temp\gp.xml /f
```
- **Ne Yapar?** Tüm RSoP verilerini yapılandırılmış XML formatında kaydeder.
- **Ne Zaman Kullanılır?** PowerShell veya Python script'leri ile ilkeleri otomatik ayrıştırmak için.
- **Parametreler:** `/x <dosya>`, `/f`.

### 6.7 Uzak Sunucunun GPO Durumunu Sorgulama
```cmd
gpresult /s SRV-DB01.lab.local /r
```
- **Ne Yapar?** Belirtilen uzak sunucunun uygulanan GPO özetini uzaktan çeker.
- **Ne Zaman Kullanılır?** Yanal hareket öncesinde hedef sunucunun koruma durumunu incelemek için.
- **Parametreler:** `/s <sunucu>`, `/r`.

### 6.8 Belirli Bir Kullanıcının RSoP Verisini İnceleme
```cmd
gpresult /user jdoe /r
```
- **Ne Yapar?** Belirtilen hedef kullanıcının oturum ilkelerini dökerek ayrıcalıklarını analiz eder.
- **Ne Zaman Kullanılır?** Çok kullanıcılı sunucularda (Terminal Server vb.) hedef personelin ilkelerini görmek için.
- **Parametreler:** `/user <ad>`, `/r`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — gpresult command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/gpresult) |
| MITRE ATT&CK T1615 (Group Policy Discovery) | [attack.mitre.org](https://attack.mitre.org/techniques/T1615/) |
| LOLBAS Project — gpresult.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |
| SpecterOps — Group Policy Hierarchy & Abuses | [posts.specterops.io](https://posts.specterops.io/) |

---

> **Önceki:** [← cmdkey](./cmdkey.md) · **Sonraki:** [reg.exe →](./reg.md)
