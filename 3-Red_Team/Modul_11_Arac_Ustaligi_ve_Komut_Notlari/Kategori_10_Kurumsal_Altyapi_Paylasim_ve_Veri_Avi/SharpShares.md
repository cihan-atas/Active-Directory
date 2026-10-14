# SharpShares

> **Kategori:** [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory etki alanındaki bilgisayarları LDAP üzerinden sorgulayarak çok iş parçacıklı Win32 NetShareEnum API çağrılarıyla ağ paylaşımlarını keşfeden, okuma ve yazma (Read/Write) erişim yetkilerini hızla denetleyen C# (.NET) tabanlı paylaşım keşif aracı.

---

## 1. Genel Bakış ve Amaç

SharpShares, Dwight Hohnstein tarafından C# (.NET) dilinde geliştirilmiş, kurumsal Active Directory ortamlarında ağ paylaşımlarının (SMB Shares) hızlı, hafif ve çok iş parçacıklı (multi-threaded) olarak keşfedilmesini ve operatörün mevcut erişim haklarının (Read, Write, Unauthorized) doğrulanmasını sağlayan bir keşif aracıdır.

Snaffler gibi ağır içerik tarama ve regex analizi yapan araçların aksine SharpShares, dosya içeriklerine derinlemesine girmez. Temel odak noktası; ağ üzerindeki tüm paylaşımların dökümünü çıkarmak, varsayılan yönetimsel paylaşımları (`C$`, `ADMIN$`, `IPC$`) filtrelemek veya listelemek ve operatörün elindeki geçerli kimlik bilgisiyle hangi paylaşımlara yazma (Write) veya okuma (Read) hakkı olduğunu saniyeler içinde raporlamaktır.

SharpShares, etki alanı denetleyicisinden (DC) LDAP sorgusuyla bilgisayar hesaplarının listesini çeker. Ardından tanımlanan iş parçacığı havuzu (thread pool) üzerinden her bir hedef makinenin SMB (TCP 445) ve RPC `srvsvc` (Server Service) arayüzüne `NetShareEnum` Win32 API çağrısı gönderir. Dönen paylaşım listesi üzerinde `GetDirectories` ve geçici dosya yazma denemeleriyle izin matrisi çıkarılır.

### 1.1 Win32 NetShareEnum API ve Paylaşım Türleri (SHARE_INFO Mimarisi)
SharpShares, temel keşif fonksiyonunu Windows API `Netapi32.dll` içerisindeki `NetShareEnum` fonksiyonunu P/Invoke ile çağırarak gerçekleştirir:
* **Level 1 (`SHARE_INFO_1`):** Paylaşım adını (`shi1_netname`), paylaşım türünü (`shi1_type`) ve açıklamasını (`shi1_remark`) döndürür. Düşük yetkili kullanıcılar için en uygun ve gürültüsüz döküm düzeyidir.
* **Paylaşım Türü Bayrakları (Share Types):**
  * `STYPE_DISKTREE (0x0)`: Normal disk sürücüsü paylaşımı (C$, OrtakDizin, Yedekler).
  * `STYPE_PRINTQ (0x1)`: Yazıcı kuyruğu paylaşımı.
  * `STYPE_DEVICE (0x2)`: İletişim aygıtı paylaşımı.
  * `STYPE_IPC (0x3)`: Süreçler arası iletişim (`IPC$`) paylaşımı; RPC ve Named Pipe oturumları için kullanılır.
  * `STYPE_SPECIAL (0x80000000)`: Sistem tarafından ayrılmış özel/yönetimsel paylaşımlar (`ADMIN$`, `C$`, `NETLOGON`, `SYSVOL`).
* **Erişim Doğrulama Mantığı:** SharpShares, her bir `STYPE_DISKTREE` paylaşımı için `Directory.EnumerateFileSystemEntries` çağrısıyla okuma hakkını (`READ`) doğrular. Ardından rasgele bir GUID adıyla geçici dosya oluşturmayı (`File.Create`) dener; başarılı olursa `WRITE` bayrağını işaretleyip hemen ardından dosyayı siler (`File.Delete`).

```
+-------------------------------------------------------------------------+
|                       SharpShares Mimari Akışı                          |
+-------------------------------------------------------------------------+
                               |
               1. LDAP Query (TCP 389/636)
          [(&(objectCategory=computer)(operatingSystem=*))]
                               v
                +------------------------------+
                | Active Directory DC          |
                +------------------------------+
                               | Bilgisayar FQDN / IP Listesi
                               v
                     +--------------------+
                     | SharpShares Engine |
                     +--------------------+
                       /        |        \
       RPC / srvsvc   /         |         \  RPC / srvsvc
       (NetShareEnum)/          |          \ (NetShareEnum)
                     v          v           v
              +----------+  +----------+  +----------+
              | FileSrv1 |  |  AppSrv2 |  | Workstn5 |
              +----------+  +----------+  +----------+
                     |          |           |
          SHARE_INFO_1 Dökümü (NetShareEnum Level 1)
                     \          |          /
                      v         v         v
         +---------------------------------------------+
         |        Access Validation Subroutine         |
         |  - Directory.EnumerateFileSystemEntries()   |
         |  - File.Create() / File.Delete() (WriteTest)|
         +---------------------------------------------+
                               |
                               v
         +---------------------------------------------+
         |          Renkli ve Yapılandırılmış Çıktı    |
         |  [+] \\Host\Share - READ                    |
         |  [!] \\Host\Share - READ, WRITE             |
         |  [-] \\Host\Share - UNAUTHORIZED            |
         +---------------------------------------------+
```

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Yazılabilir Paylaşım Tespiti** | Uzak sistemlerde DLL hijacking, SCF/URL NTLM coercion veya zararlı dosya barındırma amacıyla yazılabilir (`WRITE`) dizinlerin hızlıca tespiti. |
| **Yanal Hareket Ön Keşfi** | Yönetici yetkisi ele geçirilen hesapların hangi sunuculardaki `C$` veya `ADMIN$` paylaşımlarına erişebildiğinin doğrulanması. |
| **Hafif ve Hızlı Triage** | Dosya içeriklerini okumadan saniyeler içinde tüm etki alanı paylaşım haritasının çıkarılması; düşük bant genişliği tüketimi. |
| **Bellek İçi Yürütme (C2 Entegrasyonu)** | Cobalt Strike, Havoc veya Covenant üzerinden `execute-assembly` ile diske dokunmadan çalıştırılabilmesi. |
| **En Az Yetki Denetimi** | Standart etki alanı kullanıcılarının erişmemesi gereken finans, İK veya yönetim paylaşımlarının denetlenmesi. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | SharpShares | Snaffler | PowerView (Find-DomainShare) | smbmap |
|---|---|---|---|---|
| **Ana Amaç** | Hızlı Paylaşım & İzin Keşfi | Derin Dosya & Regex Veri Avı | Genel AD Paylaşım Keşfi | SMB Paylaşım ve İzin Taraması |
| **Geliştirme Dili** | C# (.NET) | C# (.NET) | PowerShell | Python |
| **Dosya İçeriği Taraması** | Yok (Hafif) | Var (Kapsamlı Regex) | Yok | Manuel / Sınırlı |
| **Yazma Yetkisi Testi** | Evet (Otomatik Write Test) | Hayır (Sadece Read) | Evet (CheckShareAccess) | Evet |
| **Bant Genişliği Maliyeti** | Çok Düşük | Çok Yüksek | Düşük | Düşük / Orta |
| **İş Parçacığı Yönetimi** | Dahili Multi-threaded (.NET) | Multi-threaded | Tek / Sınırlı iş parçacığı | Multi-threaded |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SharpShares, komut satırı argümanları olarak LDAP filtreleri, hedef listeleri ve filtreleme bayrakları kabul eder.

### Genel Sözdizimi
```cmd
SharpShares.exe [Argümanlar]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `/threads:` | Eşzamanlı sorgulanacak hedef makine sayısı (Varsayılan 25). | `/threads:50` |
| `/ldap:` | Etki alanı denetleyicisine gönderilecek özel LDAP bilgisayar sorgu filtresi. | `/ldap:servers` veya `/ldap:"(name=*sql*)"` |
| `/targets:` | Taranacak IP veya ana makine adlarını içeren yerel metin dosyası yolu. | `/targets:C:\Temp\hosts.txt` |
| `/dc:` | LDAP sorguları için kullanılacak yetkili Etki Alanı Denetleyicisi IP veya FQDN. | `/dc:10.0.0.1` |
| `/domain:` | Taranacak hedef etki alanı adı (Varsayılan geçerli etki alanıdır). | `/domain:corp.local` |
| `/filter:` | Çıktıdan filtrelenecek paylaşım isimleri (Virgülle ayrılmış liste). | `/filter:SYSVOL,NETLOGON,IPC$` |
| `/stealth` | Bilinen yönetimsel paylaşımları (`C$`, `ADMIN$`, `IPC$`, `PRINT$`) taramadan hariç tutar. | *Argümansız bayrak* |
| `/noshares` | Paylaşımları listelemeden yalnızca canlı ana makineleri tespit eder. | *Argümansız bayrak* |
| `/check` | Paylaşımların erişim izinlerini doğrular (`READ`, `WRITE`). | *Argümansız bayrak* |
| `/outfile:` | Sonuçların kaydedileceği yerel metin dosyası yolu. | `/outfile:C:\Temp\shares.txt` |
| `/verbose` | Zaman aşımları ve erişim engelleri dahil tüm ayrıntılı hata çıktılarını gösterir. | *Argümansız bayrak* |

### Yerleşik LDAP Filtre Kısayolları (`/ldap:`)
SharpShares, operatörün uzun LDAP filtreleri yazmasını önlemek için dahili kısayollar sunar:
* `all`: Etki alanındaki tüm etkin bilgisayar nesneleri (`(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))`).
* `servers`: Yalnızca Windows Server işletim sistemi çalıştıran makineler (`(&(objectCategory=computer)(operatingSystem=*server*))`).
* `workstations`: Yalnızca Windows istemci (iş istasyonu) makineleri (`(&(objectCategory=computer)(!(operatingSystem=*server*)))`).
* `dc`: Yalnızca Etki Alanı Denetleyicileri (`(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))`).
* `exclude-dcs`: Etki alanı denetleyicileri hariç tüm sunucu ve makineler.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanındaki Tüm Sunucularda Paylaşım ve İzin Taraması
Etki alanı denetleyicileri dahil tüm sunucuları hedefleyerek okuma ve yazma izinlerinin renkli konsol çıktısıyla dökülmesi.

```cmd
SharpShares.exe /ldap:servers /check /threads:40 /outfile:C:\Temp\server_shares.txt
```

**Örnek Konsol Çıktısı:**
```text
[+] SharpShares 2.1 started at 2026-10-14 20:20:00
[+] Domain Controller: DC01.corp.local (10.0.0.1)
[+] Executing LDAP Query: (&(objectCategory=computer)(operatingSystem=*server*))
[+] Found 28 servers in Active Directory.
[*] Starting multi-threaded share enumeration (40 threads)...
[-] \\DC01.corp.local\SYSVOL - READ
[-] \\DC01.corp.local\NETLOGON - READ
[-] \\DC01.corp.local\C$ - UNAUTHORIZED
[+] \\FS01.corp.local\SharedData - READ
[!] \\FS01.corp.local\SoftwareDeployment - READ, WRITE
[!] \\BACKUP01.corp.local\SQL_Backups - READ, WRITE
[-] \\BACKUP01.corp.local\ADMIN$ - UNAUTHORIZED
[+] \\APP02.corp.local\Logs - READ
[+] Enumeration complete: 28 hosts queried, 14 accessible shares found (2 WRITE, 12 READ).
```

### Senaryo 2: Stealth Modunda Sessiz Paylaşım Keşfi
Yönetimsel paylaşımlara (`C$`, `ADMIN$`) dokunmayarak SOC/EDR alarmlarını tetiklemeden yalnızca kurumsal paylaşımları listeleme.

```cmd
SharpShares.exe /ldap:all /stealth /threads:15
```

### Senaryo 3: Cobalt Strike execute-assembly ile Bellek İçi Yürütme
Hedef ana makinede diske dosya yazmadan doğrudan Beacon bellek alanında çalıştırma ve yazılabilir paylaşımları filtreleme.

```text
beacon> execute-assembly /opt/tools/SharpShares.exe /ldap:servers /check /threads:20
```

### Senaryo 4: Hedef Listesi Dosyası Üzerinden Belirli IP Bloklarını Tarama
LDAP kullanmadan, port taraması sonucunda TCP 445 açık bulunan IP listesini besleyerek paylaşımları çıkarma.

```cmd
SharpShares.exe /targets:C:\Temp\smb_alive.txt /check /filter:IPC$,PRINT$
```

### Senaryo 5: Özel LDAP Filtresi ile SQL Sunucularına Odaklanma
İsminde veya işletim sisteminde `SQL` geçen makineleri hedefleyerek veritabanı yedek paylaşımlarını arama.

```cmd
SharpShares.exe /ldap:"(&(objectCategory=computer)(name=*sql*))" /check /threads:10
```

### Senaryo 6: Yalnızca Yazılabilir Paylaşımları İzole Etme (Write-Only Hunting)
Ağ üzerindeki tüm sunucularda yalnızca yazma izni bulunan (`READ, WRITE`) paylaşımları tespit ederek DLL hijack veya SCF tuzak noktalarını belirleme.

```cmd
SharpShares.exe /ldap:servers /check /stealth /outfile:C:\Temp\writable_shares.txt
```

### Senaryo 7: Farklı Güvenilen Etki Alanında (Trust) Paylaşım Taraması
İki yönlü orman güveni (Forest Trust) bulunan yabancı bir etki alanındaki dosya sunucularını hedef etki alanı denetleyicisi üzerinden sorgulama.

```cmd
SharpShares.exe /domain:subsidiary.corp /dc:192.168.100.10 /ldap:servers /check /threads:15
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAP search failed: The server is not operational.` | Hedef DC erişilemez durumda, DNS çözümlemesi başarısız veya TCP 389/636 portu engelleniyor. | `/dc:<IP>` parametresi ile çalışan bir etki alanı denetleyicisini doğrudan IP adresiyle belirtin. |
| `System.ComponentModel.Win32Exception: The network path was not found (53)` | Hedef ana makine çevrimdışı, SMB servisi durdurulmuş veya yerel güvenlik duvarı TCP 445'i engelliyor. | Hedefin açık olduğunu `Test-NetConnection -Port 445` ile doğrulayın veya `/threads` değerini düşürerek ağ tıkanıklığını önleyin. |
| `System.AccessViolationException / Crash on NetShareEnum` | Çok yüksek iş parçacığı (`/threads:200+`) kullanımında P/Invoke bellek yapılarının taşması. | `/threads:` parametresini 20–50 aralığında tutun. |
| `All shares return UNAUTHORIZED` | Oturum açan kullanıcının Kerberos bileti (TGT) düşmüş veya makine etki alanından ayrılmış. | `klist` komutuyla Kerberos biletlerini kontrol edin; `runas /netonly` veya Rubeus ile geçerli bilet enjekte edin. |
| `NetShareEnum Error: Access is denied (5)` | Hedef makinede `srvsvc` Remote IPC çağrılarına kısıtlama getirilmiş veya SMB Guest/Anon kısıtlaması etkin. | Geçerli bir etki alanı kullanıcısı bağlamında çalıştığınızdan emin olun (`whoami`). |
| `No computers returned from LDAP query` | Verilen LDAP filtresi hatalı veya kullanıcının Active Directory nesnelerini okuma yetkisi kısıtlanmış. | Basit `/ldap:all` filtresi ile yeniden deneyin veya LDAP sözdizimini kontrol edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

SharpShares, dosya içeriklerini okumadığı için Snaffler'a kıyasla ağ üzerinde çok daha az gürültü üretir; ancak aynı anda çok sayıda makinenin 445 portuna bağlanması SIEM korelasyonlarında yanal hareket ön keşfi olarak yakalanabilir.

```
[SharpShares Yürütmesi]
          │
          ├──> LDAP Bilgisayar Sorgusu ──────> Event ID 1644 / LDAP Recon
          │
          ├──> RPC srvsvc (NetShareEnum) ────> Event ID 4624 (Logon Type 3)
          │                                  Event ID 5140 (Share Accessed: IPC$)
          │
          └──> Write Test (File.Create) ────> Event ID 5145 (AccessMask: 0x2 / WriteData)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Security Event ID 4624 (Logon Type 3):** Taranan her hedef sunucuda Kerberos/NTLM ağ oturumu açma kaydı oluşur.
* **Security Event ID 5140 (Network Share Object Was Accessed):** `IPC$` paylaşımına bağlanılarak `srvsvc` adlandırılmış borusu (named pipe) üzerinden `NetShareEnum` çağrıldığında loglanır.
* **Security Event ID 5145 (Detailed File Share Access):** `/check` bayrağı kullanıldığında paylaşımlara yazma denemesi yapılır. Bu deneme `AccessMask: 0x2` (WriteData) ile denetim günlüklerine yansır.
* **Sysmon Event ID 3 (Network Connection Detected):** `SharpShares.exe` sürecinin hedef IP'lerin 445 portuna yönelik kitlesel bağlantıları.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Discovery** | [T1135](https://attack.mitre.org/techniques/T1135/) | Network Share Discovery | Ağ paylaşımlarının `NetShareEnum` API ile tespiti. |
| **Discovery** | [T1018](https://attack.mitre.org/techniques/T1018/) | Remote System Discovery | LDAP sorgusu ile etki alanındaki aktif sunucuların keşfedilmesi. |
| **Lateral Movement** | [T1021.002](https://attack.mitre.org/techniques/T1021/002/) | SMB/Windows Admin Shares | Yazılabilir ve okunabilir paylaşımlar üzerinden yanal hareket vektörlerinin belirlenmesi. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Write Test İzi** | `/check` bayrağının paylaşıma test dosyası oluşturup silmesi EDR/FIM alarmlarını tetikleyebilir. | Yazma testi yapmadan sadece `/stealth` ve temel paylaşım listelemesi yapın; yazma denemelerini manuel gerçekleştirin. |
| **Geniş Ağ Taraması Alarmı** | Kısa sürede 100+ sunucuya SMB bağlantısı açılması. | `/threads:5` ile yavaş tarama yapın veya `/targets:` ile yalnızca kritik hedefleri listeleyin. |
| **Statik Binary İmzası** | `SharpShares.exe` derleme çıktısının bilinen AV/EDR imzalarına takılması. | Kaynak koddan sınıf/değişken isimlerini değiştirerek derleyin veya C2 bellek içi çalıştırıcıları (`execute-assembly`) kullanın. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (SharpShares Network Share Enumeration)
```yaml
title: Network Share Discovery via SharpShares Pattern
id: c3b2a109-8765-4321-ba98-fedcba098765
status: experimental
description: Tek bir kaynaktan çok sayıda sunucuya yönelik kısa sürede srvsvc NetShareEnum RPC çağrısı ve IPC$ oturumu tespit edildi.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5140
    ShareName: '*\\IPC$'
  timeframe: 1m
  condition: selection | count(IpAddress) by SubjectUserName > 20
falsepositives:
  - Merkezi yönetim yazılımları (SCCM, Lansweeper, Nessus)
level: medium
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 5140
| where ShareName endswith "IPC$"
| summarize TargetServersCount = dcount(Computer), TargetShares = make_set(ShareName, 20) by IpAddress, SubjectUserName, bin(TimeGenerated, 5m)
| where TargetServersCount > 15
| order by TargetServersCount desc
```

#### YARA Kuralı
```yara
rule SharpShares_Assembly_Detection {
    meta:
        description = "SharpShares .NET ağ paylaşımı keşif aracı bellek ve dosya tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/djhohnstein/SharpShares"
    strings:
        $s1 = "SharpShares" ascii wide nocase
        $s2 = "NetShareEnum" ascii wide
        $s3 = "SHARE_INFO_1" ascii wide
        $s4 = "UNAUTHORIZED" ascii wide
        $s5 = "/ldap:" ascii wide
        $s6 = "/stealth" ascii wide
    condition:
        uint16(0) == 0x5A4D and 4 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **SMB Null Session ve Anonim Paylaşım Kısıtlaması:** `NullSessionShares` kayıt defteri anahtarı boş bırakılmalı ve anonim RPC/Named Pipe erişimleri kısıtlanmalıdır.
* **Ağ İzolasyonu ve Güvenlik Duvarı:** İstemci iş istasyonlarının birbirleri arasında (workstation-to-workstation) TCP 445 SMB iletişimi ana makine tabanlı güvenlik duvarı (Windows Defender Firewall) ile engellenmelidir.
* **SMB İmzalama Zorunluluğu (SMB Signing):** Tüm etki alanı sunucu ve istemcilerinde SMB imzalama zorunlu kılınarak yetkisiz araya girme ve röle saldırıları engellenmelidir.
* **Yönetimsel Paylaşımların Kısıtlanması:** Yerel yönetici hesapları için UAC uzaktan kısıtlamaları (`LocalAccountTokenFilterPolicy = 0`) korunarak varsayılan `C$` ve `ADMIN$` erişimleri sınırlandırılmalıdır.
* **SMBv1 Protokolünün Devre Dışı Bırakılması:** Eski ve güvensiz SMBv1 protokolü tüm sistemlerden tamamen kaldırılmalı, yalnızca SMBv2/SMBv3 ve SMB Şifreleme (SMB Encryption) zorunlu tutulmalıdır.
* **RPC Filtreleme ve srvsvc Kısıtlamaları:** Standart etki alanı kullanıcılarının uzak sunucularda `srvsvc` üzerinden `NetShareEnum` çalıştırmasını kısıtlayan RPC filtreleme ilkeleri yapılandırılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Tüm Sunucularda Paylaşım ve Erişim İzni Denetimi
SharpShares.exe /ldap:servers /check

# 2. Stealth Moduyla Gizli/Yönetimsel Paylaşımları Hariç Tutarak Tarama
SharpShares.exe /ldap:servers /stealth /check

# 3. Tüm Etki Alanı Bilgisayarlarında Hızlı Keşif (50 İş Parçacığı)
SharpShares.exe /ldap:all /threads:50

# 4. Belirli Paylaşımları Filtreleyerek Çıktıyı Sadeleştirme
SharpShares.exe /ldap:servers /filter:SYSVOL,NETLOGON,IPC$,PRINT$ /check

# 5. Dosyadan Alınan Hedef Listesinde İzin Doğrulama
SharpShares.exe /targets:C:\Temp\targets.txt /check /outfile:C:\Temp\results.txt

# 6. Yalnızca Etki Alanı Denetleyicilerini Tarama
SharpShares.exe /ldap:dc /check

# 7. Etki Alanı Denetleyicileri Dışındaki Tüm Sunucuları Hedefleme
SharpShares.exe /ldap:exclude-dcs /check /threads:30

# 8. Özel SQL Sunucuları LDAP Filtresiyle Tarama
SharpShares.exe /ldap:"(&(objectCategory=computer)(name=*sql*))" /check

# 9. Belirli Bir DC ve Etki Alanı Tanımlayarak Tarama
SharpShares.exe /domain:corp.local /dc:10.0.0.1 /ldap:servers /check

# 10. Paylaşımları Listelemeden Canlı Sunucu Tespiti
SharpShares.exe /ldap:servers /noshares /threads:40
```

### Komut Detay Analizleri

#### 1. Tüm Sunucularda Paylaşım ve Erişim İzni Denetimi
* **Ne Yapar?:** Active Directory'deki Windows Server nesnelerini sorgular, her sunucudaki paylaşımları listeler ve geçerli kullanıcının Read/Write haklarını doğrular.
* **Ne Zaman Kullanılır?:** Etki alanına ilk adım atıldığında kritik sunuculardaki erişilebilir paylaşımların haritasını çıkarmak için.
* **Parametreler:**
  * `/ldap:servers`: Yalnızca Server işletim sistemli makineleri sorgular.
  * `/check`: Paylaşımlarda okuma ve yazma erişim izinlerini test eder.

#### 2. Stealth Moduyla Gizli/Yönetimsel Paylaşımları Hariç Tutarak Tarama
* **Ne Yapar?:** `C$`, `ADMIN$`, `IPC$` gibi yönetimsel paylaşımları atlayarak yalnızca kullanıcı ve uygulama odaklı paylaşımları tarar.
* **Ne Zaman Kullanılır?:** EDR/SIEM alarm eşiklerini tetiklememek ve gürültüyü minimuma indirmek amacıyla.
* **Parametreler:**
  * `/stealth`: Varsayılan yönetimsel ve sistem paylaşımlarını analiz dışı bırakır.

#### 3. Tüm Etki Alanı Bilgisayarlarında Hızlı Keşif (50 İş Parçacığı)
* **Ne Yapar?:** Etki alanındaki tüm sunucu ve iş istasyonlarını 50 eşzamanlı iş parçacığıyla çok hızlı şekilde sorgular.
* **Ne Zaman Kullanılır?:** Zaman kısıtlaması olan sızma testi operasyonlarında geniş ağları dakikalar içinde taramak için.
* **Parametreler:**
  * `/ldap:all`: Tüm aktif bilgisayar nesnelerini çeker.
  * `/threads:50`: İş parçacığı havuzu boyutunu 50 yapar.

#### 4. Belirli Paylaşımları Filtreleyerek Çıktıyı Sadeleştirme
* **Ne Yapar?:** Standart etki alanı paylaşımlarını (`SYSVOL`, `NETLOGON`, `IPC$`) rapordan çıkararak operatörün dikkatini özel paylaşımlara odaklar.
* **Ne Zaman Kullanılır?:** Yüzlerce sunucunun bulunduğu ortamlarda rapor karmaşasını önlemek için.
* **Parametreler:**
  * `/filter:...`: Belirtilen paylaşım isimlerini raporda göstermez.

#### 5. Dosyadan Alınan Hedef Listesinde İzin Doğrulama
* **Ne Yapar?:** LDAP sorgusu çalıştırmadan, operatör tarafından hazırlanan `targets.txt` dosyasındaki hedefleri tarar ve sonuçları dosyaya kaydeder.
* **Ne Zaman Kullanılır?:** LDAP erişimi kısıtlı olduğunda veya belirli bir alt ağ izole test edilirken.
* **Parametreler:**
  * `/targets:C:\Temp\targets.txt`: Hedef ana makine listesi.
  * `/outfile:C:\Temp\results.txt`: Raporun yazılacağı dosya yolu.

#### 6. Yalnızca Etki Alanı Denetleyicilerini Tarama
* **Ne Yapar?:** LDAP'tan sadece DC rolündeki makineleri çeker ve üzerlerindeki paylaşımları denetler.
* **Ne Zaman Kullanılır?:** DC'ler üzerinde unutulmuş özel yedek dizinleri veya yetkisiz erişime açık klasörleri denetlemek için.
* **Parametreler:**
  * `/ldap:dc`: Etki alanı denetleyicisi filtre kısayolu.

#### 7. Etki Alanı Denetleyicileri Dışındaki Tüm Sunucuları Hedefleme
* **Ne Yapar?:** DC'leri hariç tutarak uygulama, dosya ve veritabanı sunucularını hedefler.
* **Ne Zaman Kullanılır?:** DC'ler üzerindeki katı log denetimlerinden kaçınarak üye sunucularda yanal hareket fırsatı ararken.
* **Parametreler:**
  * `/ldap:exclude-dcs`: DC'leri filtre dışı bırakan yerleşik kısayol.

#### 8. Özel SQL Sunucuları LDAP Filtresiyle Tarama
* **Ne Yapar?:** Bilgisayar adında `sql` geçen makineleri LDAP sorgusuyla izole eder ve paylaşımlarını dökümler.
* **Ne Zaman Kullanılır?:** Veritabanı yedekleri (`.bak`, `.mdf`) barındıran sunucuları doğrudan tespit etmek için.
* **Parametreler:**
  * `/ldap:"(&(objectCategory=computer)(name=*sql*))"`: Özel nesne adı filtresi.

#### 9. Belirli Bir DC ve Etki Alanı Tanımlayarak Tarama
* **Ne Yapar?:** Mevcut makinenin üyesi olmadığı farklı veya güvenilen (trust) bir etki alanındaki sunucuları hedefler.
* **Ne Zaman Kullanılır?:** Forest trust geçişlerinde veya harici test cihazlarından Active Directory'e bağlanırken.
* **Parametreler:**
  * `/domain:corp.local`: Hedef etki alanı FQDN.
  * `/dc:10.0.0.1`: Hedef etki alanının denetleyici IP adresi.

#### 10. Paylaşımları Listelemeden Canlı Sunucu Tespiti
* **Ne Yapar?:** SMB paylaşımlarını sorgulamadan yalnızca ağ üzerinde SMB servisi açık ve yanıt veren sunucuları doğrular.
* **Ne Zaman Kullanılır?:** Ağ haritalama ve canlı hedef doğrulama amacıyla düşük izli keşif yürütürken.
* **Parametreler:**
  * `/noshares`: Paylaşım dökümü adımını atlar.

---

## Kaynaklar
* [SharpShares Resmi GitHub Deposu](https://github.com/djhohnstein/SharpShares)
* [Microsoft Dokümantasyonu: NetShareEnum Fonksiyonu](https://learn.microsoft.com/en-us/windows/win32/api/lmshare/nf-lmshare-netshareenum)
* [Microsoft Open Specifications: [MS-SRVS] Server Service Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-srvs/)
* [MITRE ATT&CK: Network Share Discovery (T1135)](https://attack.mitre.org/techniques/T1135/)
* [SpecterOps: Hunting for Insecure File Shares in Active Directory](https://posts.specterops.io/)

---

> **Önceki:** [← Snaffler](./Snaffler.md) · **Sonraki:** [PowerUpSQL →](./PowerUpSQL.md)
