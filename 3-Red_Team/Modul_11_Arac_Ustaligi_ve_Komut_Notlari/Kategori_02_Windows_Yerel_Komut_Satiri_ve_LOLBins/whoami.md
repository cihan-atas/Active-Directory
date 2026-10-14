# whoami

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows yerleşik kimlik ve token analiz aracı; kullanıcı SID tespiti (`/user`), token ayrıcalıkları (`/priv`), güvenlik grupları ve UAC bütünlük seviyesi analizi (`/groups`, `/all`).

---

## 1. Genel Bakış ve Amaç

`whoami.exe`, Windows Server 2003 ve Windows Vista'dan bu yana tüm Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\whoami.exe`) bulunan, geçerli komut satırı oturumunun güvenlik bağlamını (Security Context) ve **Erişim Belirtecini (Access Token)** sorgulayan yerel bir LOLBin aracıdır.

Saldırgan bir sisteme web shell, uzaktan komut çalıştırma (RCE) veya kimlik bilgisiyle ilk ayak bastığında (Initial Foothold), operatörün saniyeler içinde cevaplaması gereken en temel sorular şunlardır:
1. **Ben kimim?** (Hizmet hesabı mı, yerel kullanıcı mı, etki alanı kullanıcısı mı?)
2. **Hangi yetkilere sahibim?** (Token üzerinde `SeImpersonatePrivilege`, `SeDebugPrivilege` veya `SeBackupPrivilege` var mı?)
3. **UAC filtresine takılmış mıyım?** (Medium Integrity mi, yoksa High/System Integrity mi?)
4. **Hangi etki alanı ve yerel grupların üyesiyim?** (`Administrators`, `Domain Admins`, `Remote Desktop Users` vb.)

`whoami`, harici hiçbir araç gerektirmeden bu kritik operasyonel soruların tamamını tek bir komutla yanıtlar ve **Yerel Yetki Yükseltme (Local Privilege Escalation - LPE)** stratejisinin temelini belirler.

### Protokol ve Çalışma Prensibi

`whoami.exe`, işletim sistemi çekirdeğindeki (Kernel) Güvenlik Referans İzleyicisi (Security Reference Monitor - SRM) ve LSASS ile Win32 API fonksiyonları üzerinden doğrudan haberleşir:

```
┌──────────────────────────────────────────────────────────────┐
│                    Kullanıcı Komut Kabuğu                    │
│                      [ whoami.exe ]                          │
└──────────────────────────────┬───────────────────────────────┘
                               │
                1. OpenProcessToken(GetCurrentProcess(), ...)  
                2. GetTokenInformation(TokenUser, ...)         
                3. GetTokenInformation(TokenGroups, ...)       
                4. GetTokenInformation(TokenPrivileges, ...)   
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│              Windows Kernel / Erişim Belirteci               │
│                   [ Process Access Token ]                   │
│                                                              │
│  - User SID (S-1-5-21-...-500 veya 1104)                     │
│  - Group SIDs & Mandatory Labels (UAC Integrity Level)       │
│  - Privileges Array (SeImpersonate, SeDebug, SeBackup vb.)   │
│  - Restricted / Filtered Token Bayrakları                    │
└──────────────────────────────────────────────────────────────┘
```

1. **Token Okuma API Çağrıları:** `whoami`, kendi sürecinin erişim belirtecini (`OpenProcessToken`) açar ve çekirdekten `GetTokenInformation` API'si ile `TokenUser`, `TokenGroups`, `TokenPrivileges` yapılarını okur. Bu işlem **tamamen yereldir**, hiçbir ağ trafiği (LDAP/SMB) oluşturmaz.
2. **UAC ve Bütünlük Seviyeleri (Integrity Levels):** Bir kullanıcı yerel `Administrators` grubunda olsa bile, Kullanıcı Hesabı Denetimi (UAC) açıkken oturum varsayılan olarak **Medium Integrity** seviyesinde (Filtrelenmiş Belirteç / Filtered Token) başlatılır. `whoami /groups` çıktısındaki `Mandatory Label\High Mandatory Level` etiketi, sürecin UAC kısıtlamasını aşıp aşmadığını (Elevated) kanıtlar.
3. **Ayrıcalık Durumları (State):** `whoami /priv` çıktısında listelenen ayrıcalıklar `Enabled` (Etkin) veya `Disabled` (Devre Dışı) olabilir. Windows'ta bir ayrıcalığın `Disabled` olması onun kullanılamayacağı anlamına gelmez; token'da mevcut olduğu sürece `AdjustTokenPrivileges` API'siyle anında `Enabled` durumuna geçirilebilir.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Potato İstismarı Tespiti** | Hizmet hesaplarında (`IIS APPPOOL`, `MSSQLSERVER`) `SeImpersonatePrivilege` yetkisini doğrulayarak SYSTEM'e yükselme. |
| **LSASS Dump Yetkisi** | Yerel yönetici oturumunda `SeDebugPrivilege` varlığını teyit ederek bellek dökümü planlama. |
| **Veritabanı ve SAM Hırsızlığı** | `SeBackupPrivilege` yetkisi ile kilitli `NTDS.dit` veya `SAM` hive dosyalarını doğrudan kopyalama. |
| **UAC Durum Analizi** | Mevcut kabuğun yükseltilmiş (High IL) olup olmadığını anlayarak UAC Bypass ihtiyacını belirleme. |
| **SID Analizi** | Etki alanı SID'sini (Domain SID) ve nesne RID'sini öğrenerek Golden/Silver Ticket veya PAC oluşturma. |

### Kritik Token Ayrıcalıkları ve İstismar Karşılıkları

| Belirteç Ayrıcalığı (Privilege) | Operasyonel Risk / İstismar Vektörü |
|---|---|
| **`SeImpersonatePrivilege`** | Herhangi bir istemciyi taklit etme. **Potato Ailesi (SweetPotato, GodPotato, JuicyPotato)** ile anında `NT AUTHORITY\SYSTEM` olma. |
| **`SeAssignPrimaryTokenPrivilege`** | Yeni süreçlere belirteç atama. Doğrudan `SYSTEM` belirteci üreterek süreç başlatma. |
| **`SeDebugPrivilege`** | Sistemdeki herhangi bir sürecin belleğini okuma/yazma. `LSASS.exe` bellek dökümü alma veya süreç enjeksiyonu. |
| **`SeBackupPrivilege`** | ACL kontrollerini bypass ederek tüm dosyaları okuma. `C:\Windows\System32\config\SAM` ve `SYSTEM` hive'larını çalma. |
| **`SeRestorePrivilege`** | ACL kontrollerini bypass ederek tüm dosyalara yazma. Sistem ikili dosyalarını veya kayıt defteri anahtarlarını ezme. |
| **`SeTakeOwnershipPrivilege`** | Herhangi bir dosya, klasör veya kayıt defteri anahtarının sahipliğini zorla devralma. |
| **`SeLoadDriverPrivilege`** | Çekirdek sürücüsü yükleme. **BYOVD (Bring Your Own Vulnerable Driver)** ile EDR/AV kör etme. |
| **`SeManageVolumePrivilege`** | Disk birimlerini doğrudan yönetme. Ham disk okuma ile dosya kilitlerini bypass etme. |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
whoami [parametreler] [/fo {table | list | csv}] [/nh]
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| *(parametresiz)* | Yalnızca etki alanı ve geçerli kullanıcı adını döndürür (`DOMAIN\User`). | `whoami` |
| `/user` | Geçerli kullanıcının adını ve güvenlik tanımlayıcısını (SID) listeler. | `whoami /user` |
| `/groups` | Kullanıcının dahil olduğu tüm güvenlik gruplarını, SID'lerini ve özniteliklerini gösterir. | `whoami /groups` |
| `/priv` | Kullanıcının erişim belirtecinde tanımlı tüm ayrıcalıkları (Privileges) ve durumlarını döker. | `whoami /priv` |
| `/all` | Kullanıcı, gruplar, ayrıcalıklar ve UAC bütünlük seviyesini eksiksiz olarak raporlar. | `whoami /all` |
| `/claims` | Kullanıcıya atanmış Dynamic Access Control (DAC) talep tanımlayıcılarını listeler. | `whoami /claims` |
| `/fo <format>` | Çıktı biçimlendirmesini belirler: `table` (varsayılan), `list` veya `csv`. | `whoami /priv /fo csv` |
| `/nh` | Çıktıdaki başlık satırını gizler (No Header); script'lerde regex/split parsing için kullanılır. | `whoami /user /nh` |

### Modül ve Yetenek Şeması

```
whoami.exe Yetenek Ağacı
├── 1. Kimlik ve SID Analizi
│   ├── whoami (Basit DOMAIN\User)
│   └── whoami /user (Kullanıcı Adı ve Object SID)
├── 2. Güvenlik Belirteci (Token) Ayrıcalıkları
│   ├── whoami /priv (Ayrıcalık tablosu: SeImpersonate, SeDebug vb.)
│   └── whoami /priv /fo csv (Script parsing formatı)
├── 3. Grup ve Bütünlük (Integrity) Tespiti
│   ├── whoami /groups (Yerel ve Domain grupları)
│   └── Mandatory Label (High / Medium / System IL tespiti)
└── 4. Kapsamlı Raporlama
    ├── whoami /all (Tüm alanların eksiksiz dökümü)
    └── whoami /claims (Dinamik yetkilendirme talepleri)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: İlk Ayak İzi Sonrası Kapsamlı Token ve Yetki Analizi

Sisteme sızıldığında ilk çalıştırılan standart keşif komutu:

```cmd
whoami /all
```

**Örnek Çıktı Analizi:**
```text
USER INFORMATION
----------------
User Name      SID
============== ==============================================
lab\sql_svc    S-1-5-21-1111111111-2222222222-3333333333-1105

GROUP INFORMATION
-----------------
Group Name                                  Type             SID                                            Attributes
=========================================== ================ ============================================== ==================================================
Everyone                                    Well-known group S-1-1-0                                        Mandatory group, Enabled by default, Enabled group
BUILTIN\Users                               Alias            S-1-5-32-545                                   Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\SERVICE                        Well-known group S-1-5-6                                        Mandatory group, Enabled by default, Enabled group
Mandatory Label\High Mandatory Level        Label            S-1-16-12288                                  

PRIVILEGES INFORMATION
----------------------
Privilege Name                Description                               State
============================= ========================================= ========
SeAssignPrimaryTokenPrivilege Replace a process level token             Disabled
SeIncreaseQuotaPrivilege      Adjust memory quotas for a process        Disabled
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled
SeImpersonatePrivilege        Impersonate a client after authentication Enabled
SeCreateGlobalPrivilege       Create global objects                     Enabled
```
- `User Name: lab\sql_svc`: Hizmet hesabı bağlamındayız.
- `Mandatory Label\High Mandatory Level`: Süreç kısıtlamasız (High Integrity) çalışmaktadır; UAC engeli yoktur.
- `SeImpersonatePrivilege: Enabled`: **Sistem anında ele geçirilebilir!** Bir Potato exploit'i (GodPotato veya SweetPotato) çalıştırılarak saniyeler içinde `NT AUTHORITY\SYSTEM` olunabilir.

---

### Senaryo 2: Yerel Yönetici Oturumunda SeDebugPrivilege Analizi

Local Administrator kullanıcısı ile oturum açıldığında LSASS bellek erişim yetkisini teyit etmek:

```cmd
whoami /priv
```

**Örnek Çıktı:**
```text
Privilege Name                  Description                               State
=============================== ========================================= ========
SeDebugPrivilege                Debug programs                            Enabled
SeBackupPrivilege               Back up files and directories             Disabled
SeRestorePrivilege              Restore files and directories             Disabled
SeShutdownPrivilege             Shut down the system                      Disabled
```
- `SeDebugPrivilege: Enabled`: Saldırgan `procdump.exe`, Mimikatz veya PowerShell API'si ile `lsass.exe` sürecinin belleğini diske dökebilir veya doğrudan kod enjekte edebilir.

---

### Senaryo 3: UAC Kısıtlamasını ve Bütünlük Seviyesini (Integrity Level) Tespiti

Bir kullanıcı `Administrators` grubunda olsa dahi komut satırının "Yönetici Olarak Çalıştır" (Elevated) açılıp açılmadığını anlamak:

```cmd
whoami /groups | findstr /I "Mandatory Administrators"
```

**Olası Çıktı 1 (Kısıtlı - UAC Bypass Gerektirir):**
```text
BUILTIN\Administrators Alias S-1-5-32-544 Group used for deny only
Mandatory Label\Medium Mandatory Level Label S-1-16-8192
```
- `Group used for deny only`: Kullanıcı admin grubundadır ancak UAC filtresi nedeniyle yönetici hakları askıya alınmıştır.
- `Medium Mandatory Level`: Doğrudan SAM veya registry'ye yazılamaz; önce **UAC Bypass** uygulanmalıdır.

**Olası Çıktı 2 (Yükseltilmiş - Tam Yetkili):**
```text
BUILTIN\Administrators Alias S-1-5-32-544 Mandatory group, Enabled by default, Enabled group
Mandatory Label\High Mandatory Level Label S-1-16-12288
```
- Artık doğrudan yüksek ayrıcalıklı saldırılar yürütülebilir.

---

### Senaryo 4: Kullanıcı ve Etki Alanı SID Değerini Tek Satırda Alma

Golden Ticket, Silver Ticket veya Kerberos PAC enjeksiyonu hazırlığında Etki Alanı SID'si gereklidir:

```cmd
whoami /user /fo csv /nh
```

**Örnek Çıktı:**
```text
"lab\jdoe","S-1-5-21-2856481723-1940251782-3928174621-1104"
```
- Etki Alanı SID'si (Domain SID): `S-1-5-21-2856481723-1940251782-3928174621`
- Kullanıcı RID (Relative Identifier): `1104`

---

### Senaryo 5: Web Shell / IIS Üzerinde Potato Exploitation Kontrolü

Bir web shell üzerinden tek satırda yetki yükseltme potansiyelini filtreleme:

```cmd
whoami /priv | findstr /I "SeImpersonatePrivilege SeAssignPrimaryTokenPrivilege"
```
Eğer çıktı dönüyorsa, sisteme derhal `GodPotato-NET4.exe -cmd "cmd.exe /c whoami"` gönderilerek SYSTEM kabuğu alınabilir.

---

### Senaryo 6: CSV Formatında Script Parsing

Toplu otomasyonlarda başlık satırı olmadan CSV çıktısı almak:

```cmd
whoami /priv /fo csv /nh
```

---

### Senaryo 7: PowerShell ile Token Ayrıcalıklarını Parse Edip LPE Yöntemi Öneren Betik

`whoami /priv` çıktısını otomatik inceleyip uygun yerel yetki yükseltme saldırısını ekrana basan operasyonel betik:

```powershell
# whoami /priv çıktısını analiz eden akıllı karar motoru:
$privs = whoami /priv /fo csv | ConvertFrom-Csv

$PrivList = $privs.'Privilege Name'

Write-Host "[*] Güvenlik Belirteci Analiz Ediliyor..." -ForegroundColor Cyan

if ($PrivList -contains 'SeImpersonatePrivilege' -or $PrivList -contains 'SeAssignPrimaryTokenPrivilege') {
    Write-Host "[!] KRİTİK: SeImpersonate / SeAssignPrimaryToken tespit edildi!" -ForegroundColor Red
    Write-Host "    -> Öneri: GodPotato, SweetPotato veya JuicyPotato ile SYSTEM yetkisine yükselin." -ForegroundColor Yellow
}
if ($PrivList -contains 'SeDebugPrivilege') {
    Write-Host "[!] YÜKSEK: SeDebugPrivilege etkin!" -ForegroundColor Red
    Write-Host "    -> Öneri: LSASS sürecini dump edin veya SYSTEM sürecine enjeksiyon yapın." -ForegroundColor Yellow
}
if ($PrivList -contains 'SeBackupPrivilege') {
    Write-Host "[!] YÜKSEK: SeBackupPrivilege etkin!" -ForegroundColor Red
    Write-Host "    -> Öneri: reg save HKLM\SAM / SYSTEM ile yerel parola hash'lerini çalın." -ForegroundColor Yellow
}
if ($PrivList -contains 'SeLoadDriverPrivilege') {
    Write-Host "[!] YÜKSEK: SeLoadDriverPrivilege etkin!" -ForegroundColor Red
    Write-Host "    -> Öneri: Savunmasız çekirdek sürücüsü yükleyerek (BYOVD) EDR korumalarını kaldırın." -ForegroundColor Yellow
}
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata / Durum | Olası Neden | Çözüm Adımı |
|---|---|---|
| `ERROR: Access is denied.` | Çok kısıtlı bir sandbox veya AppContainer (UWP uygulaması) içinden çağrılmıştır; belirteç okuma API'sine izin verilmemektedir. | Sandbox escape teknikleri kullanın veya standart bir komut kabuğu elde etmeye çalışın. |
| `ERROR: Unable to get token information.` | Sürecin access token tutamacı (handle) bozulmuş veya kısıtlı bir `Deny-Only` belirtecine zorlanmıştır. | Yeni bir alt süreç başlatın (`cmd.exe /c whoami`) veya alternatif Win32 API çağrıları deneyin. |
| `Privilege State: Disabled` | İlgili ayrıcalık belirteçte mevcuttur ancak süreç tarafından aktif edilmemiştir (`AdjustTokenPrivileges` çağrılmamıştır). | Bu bir hata değildir. Exploit araçları (SweetPotato, Mimikatz vb.) çalışma anında bu ayrıcalığı otomatik olarak `Enabled` durumuna geçirir. |
| `Group used for deny only` | Kullanıcı yöneticidir ancak UAC nedeniyle oturum kısıtlı başlatılmıştır. | UAC Bypass tekniklerini (Fodhelper, Eventvwr, Mock Directories vb.) uygulayarak komut kabuğunu High Integrity seviyesinde yeniden başlatın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `whoami.exe` çağrısı, komut satırı argümanları (`/all`, `/priv`, `/groups`) ve üst süreç (`ParentImage`) bilgisiyle kaydedilir.
- **Sıfır Ağ İzi (Network Stealth):**
  - `whoami.exe` tamamen yerel Win32 API'leri (`GetTokenInformation`) ile çalıştığı için **hiçbir ağ veya Active Directory sorgusu (LDAP, Kerberos, SMB) üretmez**. Ağ sensörleri (NDR, Zeek, Suricata) açısından tamamen görünmezdir.

### 5.2 Ağ ve EDR İmzaları

- **Web Shell ve Servis Hesabı Anomalisi:** EDR sistemleri (CrowdStrike, Defender for Endpoint, SentinelOne), IIS (`w3wp.exe`), SQL Server (`sqlservr.exe`) veya Tomcat (`java.exe`) gibi web/veritabanı süreçlerinin altından `cmd.exe` ve hemen ardından `whoami` çalıştırılmasını **MITRE T1033 (System Owner/User Discovery)** kuralıyla doğrudan **High / Critical Severity** saldırı kanıtı olarak etiketler.
- **Argüman İmzaları:** Arka arkaya `whoami /priv` ve `whoami /groups` komutlarının çağrılması, otomatik saldırı script'lerinin ve stager'ların karakteristik davranışıdır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1033** | System Owner/User Discovery | Oturum açan kullanıcının kimliğini ve SID'sini belirleme (`whoami /user`). |
| **T1069.001** | Permission Groups Discovery: Local Groups | Kullanıcının dahil olduğu yerel yönetim gruplarını listeleme (`whoami /groups`). |
| **T1134** | Access Token Manipulation | Token ayrıcalıklarını denetleyerek Potato/LPE saldırısı planlama (`whoami /priv`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`whoami.exe` Süreç Oluşturma Tespiti** | Yeni bir `whoami.exe` süreci başlatmak (EID 4688) yerine ortam değişkenlerini (Environment Variables) okuyun: `echo %USERNAME%` ve `echo %USERDOMAIN%`. |
| **Token Ayrıcalıklarını Dosyasız İnceleme** | `whoami /priv` yerine bellek içi çalışan PowerShell komutunu çağırın: `[System.Security.Principal.WindowsIdentity]::GetCurrent().Claims`. |
| **Web Shell İçinde whoami Çağrısı** | Web shell komut istemcisinde `whoami` çalıştırmaktan kaçının; web shell kodunun içine yerel `System.Environment.UserName` API çağrısını gömün. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Anormal Üst Süreç Kuralı (Sigma Kuralı Mantığı):**
  ```yaml
  title: Discovery via Whoami from Suspicious Parent
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\whoami.exe'
          ParentImage|endswith:
              - '\w3wp.exe'
              - '\sqlservr.exe'
              - '\httpd.exe'
              - '\nginx.exe'
              - '\tomcat.exe'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Tam Token Bilgisini Görüntüleme
```cmd
whoami /all
```
- **Ne Yapar?** Kullanıcı adını, SID'yi, grup üyeliklerini, token ayrıcalıklarını ve UAC bütünlük seviyesini eksiksiz döker.
- **Ne Zaman Kullanılır?** İlk ayak basıldığında sistem bağlamını tek bakışta analiz etmek için.
- **Parametreler:** `/all` (Tüm belirteç bilgilerini listeler).

### 6.2 Token Ayrıcalıklarını (Privileges) Listeleme
```cmd
whoami /priv
```
- **Ne Yapar?** Belirteçteki tüm ayrıcalıkları (`SeImpersonate`, `SeDebug`, `SeBackup` vb.) ve durumlarını tablo olarak listeler.
- **Ne Zaman Kullanılır?** Yerel yetki yükseltme (LPE) vektörlerini belirlemek için.
- **Parametreler:** `/priv` (Yalnızca ayrıcalıklar).

### 6.3 Kullanıcı SID Değerini Alma
```cmd
whoami /user
```
- **Ne Yapar?** Kullanıcının tam etki alanı adını ve nesne güvenlik tanımlayıcısını (SID) gösterir.
- **Ne Zaman Kullanılır?** Etki alanı SID'sini öğrenmek ve Kerberos bilet enjeksiyonlarında nesne tanımlamak için.
- **Parametreler:** `/user`.

### 6.4 Grup Üyelikleri ve Bütünlük Seviyesini Gösterme
```cmd
whoami /groups
```
- **Ne Yapar?** Kullanıcının üye olduğu tüm grupları ve en altta UAC bütünlük seviyesini (`Mandatory Label\High` veya `Medium`) gösterir.
- **Ne Zaman Kullanılır?** Yönetici haklarının UAC tarafından filtrelenip filtrelenmediğini anlamak için.
- **Parametreler:** `/groups`.

### 6.5 Başlıksız Formatında Kullanıcı Adı ve SID Alma (Script Friendly)
```cmd
whoami /user /nh /fo csv
```
- **Ne Yapar?** Tablo başlığı olmadan doğrudan CSV satırı olarak kullanıcı adı ve SID çıktısı üretir.
- **Ne Zaman Kullanılır?** Otomasyon script'lerinde değişken içine doğrudan değer çekmek için.
- **Parametreler:** `/nh` (No Header), `/fo csv` (CSV formatı).

### 6.6 Ayrıcalıkları CSV Olarak Dökme
```cmd
whoami /priv /fo csv
```
- **Ne Yapar?** Token ayrıcalıklarını virgülle ayrılmış (CSV) formatta listeler.
- **Ne Zaman Kullanılır?** PowerShell veya CMD script'leri ile ayrıcalıkları parse etmek için.
- **Parametreler:** `/fo csv`.

### 6.7 Dinamik Talep Tanımlayıcılarını (Claims) Gösterme
```cmd
whoami /claims
```
- **Ne Yapar?** Active Directory Dynamic Access Control (DAC) politikaları kapsamında kullanıcıya atanmış talepleri döker.
- **Ne Zaman Kullanılır?** Gelişmiş Active Directory yetkilendirme modellerini analiz etmek için.
- **Parametreler:** `/claims`.

### 6.8 Yalnızca Etki Alanı ve Kullanıcı Adını Alma
```cmd
whoami
```
- **Ne Yapar?** Konsola yalnızca `DOMAIN\username` metnini yazar.
- **Ne Zaman Kullanılır?** Oturumun kimin adına çalıştığını en hızlı ve en sade şekilde doğrulamak için.
- **Parametreler:** Ek parametre gerektirmez.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — whoami command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/whoami) |
| MITRE ATT&CK T1033 (System Owner/User Discovery) | [attack.mitre.org](https://attack.mitre.org/techniques/T1033/) |
| LOLBAS Project — whoami.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |
| HackTricks — Windows Privilege Escalation (Privileges) | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/privilege-escalation-abusing-tokens.html) |

---

> **Önceki:** [← certutil](./certutil.md) · **Sonraki:** [cmdkey →](./cmdkey.md)
