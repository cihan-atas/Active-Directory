# wmic.exe

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Yönetim Araçları Komut Satırı (WMI CLI) LOLBin aracı; uzaktan süreç başlatma (`process call create`), sistem/yama keşfi (`qfe`, `os`), kullanıcı/SID analizi (`useraccount`) ve savunma engelleme (`shadowcopy delete`).

---

## 1. Genel Bakış ve Amaç

`wmic.exe` (Windows Management Instrumentation Command-line), Windows XP ve Windows Server 2003'ten bu yana Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\wbem\wmic.exe`) bulunan, **Windows Yönetim Araçları (WMI)** ve **Ortak Bilgi Modeli (Common Information Model - CIM)** havuzuna komut satırından tam erişim sağlayan en güçlü yerleşik LOLBin araçlarından biridir.

Active Directory sızma testlerinde ve Red Team operasyonlarında `wmic.exe`, hem **Ayrıntılı İç Keşif (Reconnaissance)** hem de **Yanal Hareket (Lateral Movement)** safhalarında operatörlerin birincil başvuru noktasıdır:
1. **Yanal Hareket (Remote Process Execution - T1047):** Uzak bir hedef makinede (`wmic /node:<IP> process call create ...`) DCOM/RPC üzerinden doğrudan yeni bir süreç başlatarak parolasız veya ele geçirilmiş kimliklerle uzaktan kod çalıştırmak (Impacket `wmiexec.py` metodolojisinin yerel karşılığı).
2. **Sistem ve Güvenlik Durumu Keşfi:** İşletim sistemine yüklenmiş tüm güvenlik güncellemelerini (`qfe`), çalışan antivirüs ve EDR yazılımlarını (`AntiVirusProduct`), ağ yapılandırmalarını ve başlangıç programlarını sorgulamak.
3. **Savunma Engelleme (Inhibit System Recovery - T1490):** Sistem geri yükleme noktalarını ve Birim Gölge Kopyalarını (`shadowcopy delete`) tek komutla yok etmek.

### Protokol ve Çalışma Prensibi

`wmic`, yerel sistemde **LPC/ALPC**, uzaktaki sistemlerle ise **DCOM (Distributed Component Object Model)** over **MSRPC** (TCP 135 ve 49152-65535 dinamik portları) üzerinden iletişim kurar:

```
┌──────────────────────────────────────────────────────────────┐
│                    Saldırgan İstemcisi                       │
│                        [ wmic.exe ]                          │
└──────────────────────────────┬───────────────────────────────┘
                               │
            Yerel: LPC / ALPC  │ Uzak: DCOM / MSRPC
            WMI Core API       │ 1. TCP 135 (RPC Endpoint Mapper)
                               │ 2. Dinamik Portlar (TCP 49152+)
                               │ Kimlik Doğrulama: NTLM / Kerberos
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 WMI Hizmeti ve Sağlayıcı Host                │
│                 [ winmgmt / WmiPrvSE.exe ]                   │
│                                                              │
│  - CIM Repository: C:\Windows\System32\wbem\Repository       │
│  - WMI Namespace: root\cimv2 (Sistem/Süreç)                  │
│  - WMI Namespace: root\SecurityCenter2 (Antivirüs/EDR)       │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Win32_Process.Create() Metodu Tetiklenir
         Üst Süreç (Parent Process) = WmiPrvSE.exe olur!
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                  Oluşturulan Alt Süreç                       │
│      cmd.exe /c "powershell -enc <Payload> > out.txt"        │
└──────────────────────────────────────────────────────────────┘
```

1. **DCOM ve RPC El Sıkışması:** Uzak bir makineye `/node:<IP>` ile bağlanıldığında, istemci ilk olarak hedefin TCP 135 (RPC Port Mapper) portuna bağlanarak WMI DCOM arayüzünün (`IWbemLevel1Login`) hangi dinamik portta (49152-65535) dinlediğini öğrenir. Ardından bu dinamik porta bağlanarak NTLM veya Kerberos ile kimlik doğrular.
2. **Parent Process Anomalisi (`WmiPrvSE.exe`):** `wmic process call create` ile başlatılan tüm süreçler, `WMI Provider Host` (`C:\Windows\System32\wbem\WmiPrvSE.exe`) sürecinin alt süreci (child process) olarak doğar. Bu durum, savunma analistleri ve EDR korelasyon kuralları için en belirgin göstergelerden (IOC) biridir.
3. **Deprecation Notu:** Microsoft, Windows 11 24H2 ve modern sürümlerde `wmic.exe` aracını isteğe bağlı özellik (Feature on Demand - FOD) haline getirmiş ve kullanım dışı (deprecated) bırakmıştır. Ancak kurumsal ortamlarda ve Windows Server 2012/2016/2019/2022 sistemlerinde varsayılan olarak varlığını sürdürmektedir. Modern alternatifleri PowerShell CIM cmdlet'leridir (`Get-CimInstance`, `Invoke-CimMethod`).

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **WMI Yanal Hareket (wmiexec)** | SMB Named Pipe yerine DCOM/RPC kullanarak uzak sunucularda sessizce komut yürütme. |
| **Kernel Exploit İçin Yama Analizi** | `wmic qfe` ile hedefte hangi güvenlik yamalarının (KB) eksik olduğunu anında tespit etme. |
| **Gölge Kopyaları Yok Etme** | Adli inceleme ve geri yüklemeyi önlemek için `wmic shadowcopy delete` çalıştırma. |
| **EDR ve Antivirüs Tespiti** | `root\SecurityCenter2` altından sistemde hangi güvenlik yazılımının aktif olduğunu öğrenme. |
| **Hesap ve Parola Politikası Analizi** | `useraccount` takma adıyla yerel ve etki alanı kullanıcılarının kilitlenme/şifre durumlarını sorgulama. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `wmic.exe` | `PowerShell (Get-CimInstance)` | `wmiexec.py (Impacket)` | `WinRM / Enter-PSSession` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Windows 10 / Server 2022'ye kadar hazır | Windows 8 / Server 2012+ hazır | Harici Linux aracı | WinRM servisi açık olmalıdır |
| **Kullandığı Protokol** | DCOM / MSRPC (TCP 135 + Dinamik) | WSMAN (5985) veya DCOM | DCOM / MSRPC (TCP 135) | WSMAN (HTTP 5985 / HTTPS 5986) |
| **Uzak Komut Yürütme** | Var (`process call create`) | Var (`Invoke-CimMethod`) | Var (Otomatik Shell) | Var (İnteraktif Kabuk) |
| **Parent Process İzi** | `WmiPrvSE.exe` | `WmiPrvSE.exe` veya `wsmprovhost` | `WmiPrvSE.exe` | `wsmprovhost.exe` |
| **EDR Görünürlüğü** | Komut satırı argümanı yüksek risklidir | Script Block Logging (EID 4104) | Ağ seviyesinde DCOM trafiği | WSMAN trafiği |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
wmic [genel_anahtarlar] <alias | class> [where_şartı] <fiil | metot> [parametreler]
```

### Kritik Genel Anahtarlar (Global Switches)

| Anahtar | Açıklama | Örnek Kullanım |
|---|---|---|
| `/node:<Sunucu>` | Komutun çalıştırılacağı hedef makine adı veya IP adresi. | `/node:192.168.1.10` |
| `/user:<Kullanıcı>` | Uzak makinede kimlik doğrulama hesabı (`DOMAIN\User` veya `User`). | `/user:LAB\Administrator` |
| `/password:<Parola>` | Uzak makine için kimlik doğrulama parolası. | `/password:P@ssw0rd2026!` |
| `/namespace:<Yol>` | Sorgulanacak WMI ad alanı (Varsayılan: `root\cimv2`). | `/namespace:\\root\SecurityCenter2` |
| `/format:<Format>` | Çıktı biçimlendirmesi: `table`, `list`, `csv`, `htable` (HTML). | `/format:csv` |
| `/output:<Dosya>` | Standart çıktıyı doğrudan belirtilen dosyaya yönlendirir. | `/output:C:\Temp\procs.txt` |
| `/privileges:<enable\|disable>`| Belirteç ayrıcalıklarını aktif eder (Varsayılan: `enable`). | `/privileges:enable` |

### En Çok Kullanılan Takma Adlar (WMI Aliases)

| Takma Ad (Alias) | İlgili WMI / CIM Sınıfı | Açıklama |
|---|---|---|
| `process` | `Win32_Process` | Süreç listeleme, sonlandırma ve uzaktan başlatma (`call create`). |
| `service` | `Win32_Service` | Windows servislerini sorgulama, başlatma ve durdurma. |
| `useraccount` | `Win32_UserAccount` | Yerel ve etki alanı kullanıcı hesaplarını inceleme. |
| `group` | `Win32_Group` | Güvenlik gruplarını listeleme. |
| `qfe` | `Win32_QuickFixEngineering` | Yüklü Windows yamalarını ve güncellemelerini listeleme. |
| `os` | `Win32_OperatingSystem` | İşletim sistemi sürümü, mimarisi ve sistem dizinleri. |
| `computersystem` | `Win32_ComputerSystem` | Etki alanı üyeliği, toplam RAM ve üretici bilgisi. |
| `shadowcopy` | `Win32_ShadowCopy` | Birim gölge kopyalarını listeleme ve silme. |
| `startup` | `Win32_StartupCommand` | Otomatik başlayan başlangıç programlarını sorgulama. |
| `nicconfig` | `Win32_NetworkAdapterConfiguration` | Ağ bağdaştırıcıları, IP, Subnet, DNS ve Gateway ayarları. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Uzak Makinede Süreç Başlatarak Yanal Hareket (Manuel wmiexec)

Etki alanı yöneticisi haklarıyla hedef makinede arka planda bir komut çalıştırmak:

```cmd
wmic /node:192.168.1.10 /user:LAB\da_admin /password:P@ssw0rd2026! process call create "cmd.exe /c whoami /all > C:\Windows\Temp\out.txt"
```

**Örnek Çıktı Analizi:**
```text
Executing (Win32_Process)->Create()
Method execution successful.
Out Parameters:
instance of __PARAMETERS
{
        ProcessId = 4812;
        ReturnValue = 0;
};
```
- `ReturnValue = 0`: Metodun başarıyla çalıştığını doğrular. (Eğer `ReturnValue = 2` dönerse dosya bulunamamıştır, `ReturnValue = 8` ise bilinmeyen hata).
- `ProcessId = 4812`: Uzak makinede açılan sürecin PID değeridir.
- Çıktı dosyası `\\192.168.1.10\C$\Windows\Temp\out.txt` üzerinden okunabilir.

---

### Senaryo 2: Yüklü Windows Güvenlik Yamalarını ve Güncellemeleri Listeleme (Kernel Exploit Avı)

Yetki yükseltme aşamasında sistemde hangi yamaların eksik olduğunu analiz etmek:

```cmd
wmic qfe get Caption,Description,HotFixID,InstalledOn
```

**Örnek Çıktı:**
```text
Description      HotFixID   InstalledOn
Update           KB5003637  6/10/2021
Security Update  KB5004237  7/14/2021
Security Update  KB5005033  8/12/2021
```
Eğer sistemde 2021'den sonra yama yüklenmemişse, **PrintNightmare (CVE-2021-34527)** veya **ZeroLogon** gibi yerel yetki yükseltme exploit'leri hemen değerlendirilebilir.

---

### Senaryo 3: Çalışan Süreçleri ve Tam Komut Satırı Argümanlarını Çıkarma

Hafızadaki hassas süreçleri, çalışan batch script'lerini ve komut satırında unutulmuş açık parolaları avlamak:

```cmd
wmic process get Caption,ProcessId,CommandLine
```

**Örnek Çıktı Analizi:**
```text
Caption      CommandLine                                                 ProcessId
powershell.exe powershell.exe -enc SQBFAFgAIAAoAE5ldy...                   3912
backup.exe   C:\Scripts\backup.exe /user:db_admin /pass:SqlSecret2025!   5120
```
- `backup.exe` sürecinin komut satırında düz metin veritabanı parolası yakalanmıştır!

---

### Senaryo 4: Etki Alanı ve Yerel Kullanıcı Hesaplarını ve SID'lerini Dökme

Kullanıcıların kilitlenme durumlarını ve tam SID'lerini listelemek:

```cmd
wmic useraccount get Name,SID,Lockout,Disabled,PasswordRequired
```

---

### Senaryo 5: Sistemdeki Antivirüs ve EDR Yazılımlarını Sorgulama

Makinede hangi güvenlik ürününün devrede olduğunu WMI üzerinden tespit etmek:

```cmd
wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState
```

**Örnek Çıktı:**
```text
displayName                   productState
Windows Defender              397568
CrowdStrike Falcon Sensor     266240
```
- Sistemde hem Windows Defender hem de CrowdStrike Falcon Sensor'ün aktif olduğu teyit edilir; saldırganın agresif ikili dosya çalıştırmaktan kaçınması gerektiği anlaşılır.

---

### Senaryo 6: Birim Gölge Kopyalarını (Shadow Copies) Silme (Anti-Forensics)

Sistem geri yükleme noktalarını ve eski dosya sürümlerini yok etmek:

```cmd
wmic shadowcopy delete /nointeractive
```

---

### Senaryo 7: PowerShell ile WMI Süreçlerini ve WmiPrvSE Alt Süreçlerini Bulan Betik

Uzak WMI saldırılarını tespit etmek için `WmiPrvSE.exe` altındaki şüpheli çocuk süreçleri listeleyen savunma/denetim betiği:

```powershell
# WmiPrvSE tarafından başlatılmış anormal süreçleri avlayan script:
Get-CimInstance Win32_Process | Where-Object { 
    $parent = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.ParentProcessId)")
    $parent.Name -match 'WmiPrvSE.exe' 
} | Select-Object ProcessId, Name, CommandLine, CreationDate | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `ERROR: Description = Access is denied.` / `0x80070005` | Uzak sistemde yönetici ayrıcalığı yoktur veya UAC kısıtlaması nedeniyle kısıtlı belirteç uygulanmaktadır (`LocalAccountTokenFilterPolicy`). | Etki Alanı Yöneticisi kimliği (`LAB\da_admin`) kullanın veya hedef makinede `LocalAccountTokenFilterPolicy` kaydını 1 yapın. |
| `ERROR: Description = The RPC server is unavailable.` / `0x800706ba` | Hedef makinede WMI veya DCOM trafiği güvenlik duvarında engellidir (TCP 135 veya dinamik RPC portları kapalıdır). | Güvenlik duvarı durumunu kontrol edin; uzaktan WMI kural grubuna izin verilip verilmediğini doğrulayın (`netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes`). |
| `ERROR: Description = Access denied` / `0x80041003` | WMI ad alanına (`namespace`) erişim izni yoktur (Kullanıcının DCOM veya WMI yetkisi kısıtlanmıştır). | `wmimgmt.msc` üzerinden WMI güvenlik izinlerini denetleyin. |
| `'wmic' is not recognized as an internal or external command...` | Windows 11 (24H2+) üzerinde WMIC özelliği kaldırılmıştır veya PATH çevre değişkeni eksiktir. | İsteğe bağlı özellik olarak yükleyin (`DISM /Online /Add-Capability /CapabilityName:WMIC~~~~`) veya doğrudan PowerShell CIM alternatiflerini (`Get-CimInstance`, `Invoke-CimMethod`) kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Parent Process Anomalisi:** WMI üzerinden uzaktan başlatılan tüm komutlar (`process call create`), `C:\Windows\System32\wbem\WmiPrvSE.exe` ebeveyn süreci altında çalışır.
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `ParentImage: C:\Windows\System32\wbem\WmiPrvSE.exe` ve `CommandLine` argümanları kaydedilir.
  - **Event ID 4624 (Successful Logon - Type 3 / Network):** DCOM kimlik doğrulaması sırasında hedef makinede Ağ Oturumu (Type 3) oluşur.
  - **WMI-Activity Olay Günlüğü (`Microsoft-Windows-WMI-Activity/Operational`):**
    - **Event ID 5861 (WMI Activity):** Kalıcı WMI Event Subscription oluşturulduğunda kaydedilir.
    - **Event ID 5858 (Method Execution Error):** WMI çağrılarındaki hataları dökerek operasyonel gürültüyü kaydeder.

### 5.2 Ağ ve EDR İmzaları

- **DCOM Ağ İmzası:** İstemci ile hedef sunucu arasında TCP 135 portuna ek olarak rastgele yüksek portlara (TCP 49152+) doğru yoğun çift yönlü RPC trafiği oluşur. Bu trafik, Zeek ve kurumsal IDS sistemleri tarafından doğrudan **DCOM WMI Remoting** olarak sınıflandırılır.
- **EDR Davranışsal Tespiti:** Bir web shell (`w3wp.exe`) veya saldırgan oturumu altından `wmic.exe process call create` çağrılması, hemen hemen tüm modern EDR'lar için doğrudan **Kritik Yanal Hareket Girişimi (MITRE T1047)** alarmıdır.
- **`shadowcopy delete` İmzası:** Fidye yazılımları (Ransomware) tarafından sıkça kullanıldığı için `wmic shadowcopy delete` komutu EDR davranış motorları tarafından derhal engellenir ve süreç öldürülür.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1047** | Windows Management Instrumentation | Uzak sistemlerde kod yürütme ve yanal hareket (`process call create`). |
| **T1082** | System Information Discovery | İşletim sistemi, BIOS ve donanım yapılandırmasını öğrenme (`os`, `computersystem`). |
| **T1057** | Process Discovery | Çalışan süreçleri ve komut satırı argümanlarını dökme (`process get CommandLine`). |
| **T1490** | Inhibit System Recovery | Gölge kopyaları silerek adli kurtarmayı engelleme (`shadowcopy delete`). |
| **T1087.001 / .002** | Account Discovery | Yerel ve etki alanı kullanıcı hesaplarını haritalama (`useraccount get`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`wmic.exe` Süreç Oluşturma Tespiti** | `wmic.exe` ikili dosyasını çağırmak yerine, doğrudan bellek içi PowerShell `Invoke-CimMethod -ClassName Win32_Process -MethodName Create` veya C# WMI API'lerini kullanın. |
| **`WmiPrvSE.exe` Parent Süreç İmzası** | WMI ile doğrudan hedef payload'u çalıştırmak yerine, zamanlanmış görev tetikleyen veya servis başlatan küçük bir aracı komut çalıştırarak parent-child ilişkisini kırın. |
| **DCOM Port Taraması Alarmı** | Hedefe DCOM ile bağlanırken statik port yapılandırması veya WinRM (TCP 5985) gibi tek port üzerinden çalışan alternatifleri tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team)

- **WMI Denetimi:** `Microsoft-Windows-WMI-Activity/Operational` günlüğünü aktifleştirerek uzaktan WMI çağrılarını SIEM üzerinden korele edin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: WMI Remote Process Creation via WMIC
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\wmic.exe'
          CommandLine|contains:
              - 'process'
              - 'call'
              - 'create'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Uzak Sistemde Yeni Bir Süreç Başlatma (Yanal Hareket)
```cmd
wmic /node:192.168.1.10 /user:LAB\admin /password:P@ss process call create "calc.exe"
```
- **Ne Yapar?** Uzak hedef makinede belirtilen programı arka planda bağımsız bir süreç olarak başlatır.
- **Ne Zaman Kullanılır?** Uzak sistemde komut çalıştırmak ve yanal hareket gerçekleştirmek için.
- **Parametreler:** `/node:<IP>`, `/user:<Kullanıcı>`, `/password:<Parola>`, `process call create "<Komut>"`.

### 6.2 Çalışan Süreçlerin Tam Komut Satırlarını Görüntüleme
```cmd
wmic process get Caption,ProcessId,CommandLine
```
- **Ne Yapar?** Sistemdeki tüm süreçlerin adını, PID numarasını ve başlatılırken verilen parametreleri döker.
- **Ne Zaman Kullanılır?** Komut satırında açık metin unutulmuş parolaları ve gizli script'leri avlamak için.
- **Parametreler:** `process get Caption,ProcessId,CommandLine`.

### 6.3 Yüklü Windows Güvenlik Güncellemelerini (Hotfix) Listeleme
```cmd
wmic qfe get HotFixID,InstalledOn
```
- **Ne Yapar?** Sistemde yüklü olan tüm KB güncelleme numaralarını ve yüklenme tarihlerini listeler.
- **Ne Zaman Kullanılır?** Hedef sistemin hangi çekirdek (kernel) zafiyetlerine karşı savunmasız olduğunu belirlemek için.
- **Parametreler:** `qfe get HotFixID,InstalledOn`.

### 6.4 Tüm Kullanıcı Hesaplarını ve SID Değerlerini Alma
```cmd
wmic useraccount get Name,SID,Disabled,Lockout
```
- **Ne Yapar?** Makinedeki ve etki alanındaki kullanıcıların adlarını, güvenlik tanımlayıcılarını ve kilitlenme durumlarını döker.
- **Ne Zaman Kullanılır?** Etki alanı SID'sini öğrenmek ve kilitlenmiş/devre dışı hesapları haritalamak için.
- **Parametreler:** `useraccount get Name,SID,Disabled,Lockout`.

### 6.5 Ağ Bağdaştırıcılarının IP ve DNS Yapılandırmasını İnceleme
```cmd
wmic nicconfig where IPEnabled=TRUE get IPAddress,DefaultIPGateway,DNSServerSearchOrder
```
- **Ne Yapar?** Yalnızca aktif IP adresi bulunan ağ kartlarının IP, ağ geçidi ve DNS sunucu adreslerini listeler.
- **Ne Zaman Kullanılır?** İç ağ segmentlerini ve DC/DNS sunucu IP'lerini tespit etmek için.
- **Parametreler:** `nicconfig where IPEnabled=TRUE get ...`.

### 6.6 Sistemdeki Tüm Birim Gölge Kopyalarını (Shadow Copies) Silme
```cmd
wmic shadowcopy delete /nointeractive
```
- **Ne Yapar?** Windows Volume Shadow Copy servisi tarafından alınan tüm anlık yedekleri ve geri yükleme noktalarını siler.
- **Ne Zaman Kullanılır?** Adli incelemeyi engellemek ve sistemin eski bir duruma geri döndürülmesini önlemek için.
- **Parametreler:** `shadowcopy delete /nointeractive` (Onay sormadan sil).

### 6.7 Yüklü Antivirüs ve EDR Ürünlerini Sorgulama
```cmd
wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState
```
- **Ne Yapar?** Windows Güvenlik Merkezi'ne kayıtlı tüm üçüncü parti ve yerleşik antivirüs yazılımlarını listeler.
- **Ne Zaman Kullanılır?** Hedef sistemdeki aktif güvenlik çözümlerini (Defender, CrowdStrike vb.) tespit etmek için.
- **Parametreler:** `/namespace:\\root\SecurityCenter2`, `path AntiVirusProduct`.

### 6.8 Başlangıçta Otomatik Çalışan Programları Listeleme
```cmd
wmic startup get Caption,Command,User
```
- **Ne Yapar?** Kayıt defteri ve Başlangıç klasörü üzerinden otomatik başlayan uygulamaları listeler.
- **Ne Zaman Kullanılır?** Kalıcılık tespiti yapmak veya yetki yükseltme potansiyeli olan başlangıç programlarını bulmak için.
- **Parametreler:** `startup get Caption,Command,User`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — WMIC command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wmic) |
| MITRE ATT&CK T1047 (Windows Management Instrumentation) | [attack.mitre.org](https://attack.mitre.org/techniques/T1047/) |
| LOLBAS Project — wmic.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |
| SpecterOps — WMI Attacks, Defense, and Forensics | [specterops.io](https://specterops.io/) |

---

> **Önceki:** [← schtasks.exe](./schtasks.md) · **Sonraki:** [ADExplorer →](./ADExplorer.md)
