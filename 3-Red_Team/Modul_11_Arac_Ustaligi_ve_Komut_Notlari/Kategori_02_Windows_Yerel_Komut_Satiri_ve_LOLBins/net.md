# net.exe

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows yerel yönetim LOLBin aracı; etki alanı ve yerel kullanıcılar (`net user`), güvenlik grupları (`net group`), parola politikaları (`net accounts`) ve paylaşımlar (`net share` / `net view`).

---

## 1. Genel Bakış ve Amaç

`net.exe`, MS-DOS ve OS/2 LAN Manager döneminden bu yana tüm Windows NT tabanlı işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\net.exe`) bulunan en temel yönetim ve keşif aracıdır. Bir Active Directory sızma testinde veya Red Team operasyonunda sisteme ilk ayak basıldığında (Initial Access / Foothold), operatörün harici hiçbir ikili dosya yüklemeden hedef etki alanının parola politikasını, kullanıcı hesaplarını, ayrıcalıklı gruplarını (`Domain Admins`, `Enterprise Admins`) ve ağ paylaşımlarını haritalaması için ilk başvurduğu **Living Off the Land Binary (LOLBin)** aracıdır.

### Protokol ve Çalışma Prensibi

`net.exe` bir yürütücü (wrapper) gibi davranır; komut satırından çağrıldığında arka planda doğrudan `C:\Windows\System32\net1.exe` ikili dosyasını tetikler. Arka planda etki alanı sorguları gerçekleştirirken **SAMR (Security Account Manager Remote)** protokolü, **Netlogon Remote Protocol (MS-NRPC)** ve **Workstation/Server Service RPC (WKST/SRVSVC)** arayüzlerini kullanır:

```
┌──────────────────────────────────────────────────────────────┐
│                      Yerel İstemci                           │
│  [ net.exe ] ──────(Process Spawn)─────► [ net1.exe ]        │
└──────────────────────────────────────────────┬───────────────┘
                                               │
               1. SMB Bağlantısı (TCP 445 / TreeConnect: IPC$) 
               2. Named Pipe Açma (\pipe\samr veya \pipe\srvsvc)
               3. SAMR / SRVSVC RPC Çağrıları (MSRPC)           
                                               │
                                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Etki Alanı Denetleyicisi (DC)                │
│                 [ LSASS.EXE / SAM Database ]                 │
│                                                              │
│  - SamrQueryInformationDomain (Parola ve Hesap Politikası)   
│  - SamrEnumerateUsersInDomain (Etki Alanı Kullanıcıları)     
│  - SamrEnumerateGroupsInDomain (Etki Alanı Grupları)         
│  - SamrQueryInformationUser (Kullanıcı Öznitelikleri & RID)   
└──────────────────────────────────────────────────────────────┘
```

1. **`net.exe` -> `net1.exe` İlişkisi:** `net.exe` girdi parametrelerini doğrular ve asıl işlevselliği yürüten `net1.exe` sürecini başlatır. Bu durum, EDR ve SIEM korelasyonlarında karakteristik bir Parent-Child süreci oluşturur.
2. **SAMR RPC Trafiği:** `net user /domain` veya `net group /domain` komutları çalıştırıldığında, istemci etki alanı denetleyicisinin `IPC$` paylaşımına bağlanır ve `\pipe\samr` (Security Account Manager Remote) named pipe'ı üzerinden DC'deki SAM/NTDS veritabanına sorgu atar.
3. **LDAP Yerine RPC Kullanımı:** `net.exe` modern LDAP (TCP 389) yerine eski tip MSRPC/SAMR kullandığı için, LDAP sorgularını loglayan sensörleri atlatabilir ancak `RestrictRemoteSAM` gibi modern savunma sertleştirmelerine takılabilir.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Parola Politikası Keşfi** | Parola püskürtme (Password Spraying) öncesi kilitleme eşiği (`Lockout threshold`) ve süresini öğrenme. |
| **Ayrıcalıklı Hesap Tespiti** | `Domain Admins`, `Enterprise Admins` ve yerel `Administrators` grup üyelerini listeleme. |
| **Yanal Hareket Öncesi Keşif** | Ağdaki aktif makineleri (`net view`) ve açık SMB paylaşımlarını listeleme. |
| **Kalıcılık (Persistence)** | Hedef makinede gizli yerel kullanıcı açma ve yöneticiler grubuna ekleme. |
| **Ağ Sürücüsü Bağlama** | Uzak hedeflere kimlik bilgisi enjekte ederek SMB/IPC$ paylaşımını sürücü harfiyle mount etme (`net use`). |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `net.exe` / `net1.exe` | `PowerView (PowerShell)` | `ldapsearch` | `rpcclient (Linux)` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Tüm Windows sürümlerinde hazır | Harici script indirilmelidir | Yalnızca Linux/Samba'da | Yalnızca Linux/Samba'da |
| **Kullandığı Protokol** | MSRPC (SAMR, SRVSVC) | LDAP / ADWS | LDAP / LDAPS | MSRPC (SAMR, LSA) |
| **EDR / Antivirüs Algısı** | Komut satırı argümanı yüksek risklidir | Script Block Logging (EID 4104) | Doğrudan ağ trafiğindedir | Windows uç noktada iz bırakmaz |
| **Sorgu Derinliği** | Temel (Yalnızca standart alanlar) | Çok Yüksek (Tüm AD öznitelikleri) | Çok Yüksek (Ham LDAP verisi) | Yüksek (RID, Policy, Pipe) |
| **Çalıştırma Ortamı** | Yerel Windows Komut Satırı | Windows PowerShell | Uzaktan Linux Terminali | Uzaktan Linux Terminali |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
net <alt_komut> [nesne] [seçenekler] [/domain]
```

Eğer `/domain` bayrağı eklenirse sorgu doğrudan **Primary Domain Controller (PDC)** veya etki alanı denetleyicisine iletilir. Bayrak eklenmezse işlem yalnızca **yerel makine** üzerinde gerçekleşir.

### Alt Komutlar ve Kritik Bayraklar

| Alt Komut / Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `accounts [/domain]` | Parola uzunluğu, parola geçerlilik süresi ve hesap kilitleme politikasını gösterir. | `net accounts /domain` |
| `user [/domain]` | Yerel veya etki alanındaki tüm kullanıcı hesaplarını listeler. | `net user /domain` |
| `user <ad> [/domain]` | Belirtilen kullanıcının hesap durumu, parola son değişim tarihi ve gruplarını döker. | `net user Administrator /domain` |
| `user <ad> <parola> /add` | Sistemde yeni bir yerel veya etki alanı kullanıcısı oluşturur (Yönetici yetkisi gerekir). | `net user backup_svc P@ss123! /add` |
| `user <ad> /active:{yes\|no}` | Belirtilen kullanıcı hesabını aktif veya pasif hale getirir. | `net user Guest /active:yes` |
| `group [/domain]` | Etki alanındaki tüm global güvenlik gruplarını listeler. | `net group /domain` |
| `group <grup> [/domain]` | Belirtilen etki alanı grubuna üye olan tüm kullanıcı ve bilgisayarları listeler. | `net group "Domain Admins" /domain` |
| `group <grup> <ad> /add` | Bir kullanıcıyı etki alanı grubuna ekler. | `net group "Domain Admins" attacker /add /domain` |
| `localgroup` | Yerel makinedeki tüm yerel güvenlik gruplarını listeler. | `net localgroup` |
| `localgroup <grup>` | Belirtilen yerel grubun üyelerini döker (Domain üyeleri dahil). | `net localgroup Administrators` |
| `localgroup <grup> <ad> /add`| Belirtilen kullanıcıyı yerel gruba ekler. | `net localgroup Administrators jdoe /add` |
| `view [\\hedef] [/all]` | Ağdaki bilgisayarları veya hedefteki paylaşımları listeler. | `net view \\DC01 /all` |
| `use <sürücü:> \\hedef\paylaşım` | Uzak SMB paylaşımına kimlik bilgisiyle ağ sürücüsü olarak bağlanır. | `net use Z: \\DC01\SYSVOL /user:LAB\admin P@ss` |
| `share` | Makinedeki tüm aktif paylaşımları ve yerel dosya yolu karşılıklarını döker. | `net share` |
| `session` | Makineye açık olan aktif SMB oturumlarını ve bağlanan kullanıcıları listeler. | `net session` |
| `time [/domain]` | Etki alanındaki zaman sunucusunun (PDC) geçerli saatini sorgular. | `net time /domain` |

### Modül Ağacı Şeması

```
net.exe Modül Ağacı
├── 1. Kimlik ve Politika Keşfi
│   ├── net accounts [/domain]        (Parola ve kilitleme politikası)
│   ├── net user [/domain]            (Kullanıcı envanteri)
│   └── net user <ad> [/domain]       (Hesap öznitelikleri, son parola)
├── 2. Grup ve Yetki Analizi
│   ├── net group [/domain]           (AD Global Grupları)
│   ├── net group "Grup" [/domain]    (Grup üyeleri)
│   ├── net localgroup                (Yerel gruplar)
│   └── net localgroup Administrators (Yerel yöneticiler)
├── 3. Paylaşım ve Ağ Oturumu
│   ├── net view [\\hedef]            (Ağ ve paylaşım taraması)
│   ├── net share                     (Yerel paylaşılan klasörler)
│   ├── net use [Z:] [\\hedef\share]  (Ağ sürücüsü bağlama/koparma)
│   └── net session                   (Aktif SMB oturumları)
└── 4. Sistem ve Süreç Kontrolü
    ├── net time [/domain]            (Etki alanı saat senkronizasyonu)
    └── net start / net stop          (Windows servis yönetimi)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Parola Politikası ve Hesap Kilitleme Analizi (Password Spray Öncesi)

Bir parola püskürtme saldırısı başlatmadan önce hesapların kilitlenmesini önlemek için etki alanı kilitleme eşiği kesinlikle kontrol edilmelidir:

```cmd
net accounts /domain
```

**Örnek Çıktı Analizi:**
```text
Force user logoff how long after time expires?:       Never
Minimum password age (days):                          1
Maximum password age (days):                          90
Minimum password length:                              8
Length of password history maintained:                24
Lockout threshold:                                    5
Lockout duration (minutes):                           30
Lockout observation window (minutes):                 30
Computer role:                                        PRIMARY
The command completed successfully.
```
- `Lockout threshold: 5`: Arka arkaya 5 hatalı parola girildiğinde hesap kilitlenir. Bu değer, saldırganın her hesap için güvenli deneme sayısını (örneğin 3 deneme) belirlemesini sağlar.
- `Lockout observation window: 30`: Sayaç 30 dakika sonra sıfırlanır. Saldırgan her parola püskürtme dalgası arasına en az 31 dakika bekletme koymalıdır.
- `Minimum password length: 8`: Minimum parola uzunluğunun 8 karakter olduğunu gösterir; daha kısa sözlük girdileri elenebilir.

---

### Senaryo 2: Etki Alanı Kullanıcılarını ve Ayrıcalıklı Hesapları İnceleme

Etki alanındaki tüm kullanıcı hesaplarını listelemek:
```cmd
net user /domain
```

Hedef bir yöneticinin detaylı hesap özniteliklerini dökmek:
```cmd
net user Administrator /domain
```

**Örnek Çıktı Analizi:**
```text
User name                    Administrator
Full Name                    Built-in domain administrator
Comment                      Built-in account for administering the computer/domain
User's comment               
Country/region code          000 (System Default)
Account active               Yes
Account expires              Never

Password last set            10/12/2025 09:15:22 AM
Password expires             Never
Password changeable          10/13/2025 09:15:22 AM
Password required            Yes
User may change password     Yes

Workstations allowed         All
Logon script                 
User profile                 
Home directory               
Last logon                   10/14/2026 11:42:01 AM

Logon hours allowed          All

Local Group Memberships      *Administrators       
Global Group memberships     *Domain Admins        *Enterprise Admins    
                             *Schema Admins        *Group Policy Creator Owners
The command completed successfully.
```
- `Password last set`: Parolanın ne kadar süredir değiştirilmediğini gösterir. Çok eski parolalar zayıf olabilir veya parola listelerinde bulunabilir.
- `Global Group memberships`: Kullanıcının sahip olduğu en yüksek ayrıcalıkları (`Domain Admins`, `Enterprise Admins`, `Schema Admins`) kanıtlar.
- `Workstations allowed`: Eğer belirli makinelerle kısıtlanmışsa (`Logon Workstations`), saldırgan yalnızca izin verilen makineler üzerinden bu hesabı kullanabilir.

---

### Senaryo 3: Ayrıcalıklı Güvenlik Gruplarının Üyelerini Listeleme

Etki alanındaki en kritik hedefleri belirlemek için `Domain Admins` grubu taranır:

```cmd
net group "Domain Admins" /domain
```

**Örnek Çıktı Analizi:**
```text
Group name     Domain Admins
Comment        Designated administrators of the domain

Members

-------------------------------------------------------------------------------
Administrator            svc_backup               da_jdoe                  
The command completed successfully.
```
Buradaki `svc_backup` servis hesabı (Kerberoasting potansiyeli) ve `da_jdoe` personeli anında yüksek öncelikli hedef haline gelir.

Yerel yönetici grubunu kontrol etmek (Lokal Local Admin kimlikleri için):
```cmd
net localgroup Administrators
```

---

### Senaryo 4: Ağ Paylaşımlarını Keşfetme ve Bağlama (Network Share Discovery)

Hedef bir etki alanı denetleyicisindeki veya dosya sunucusundaki açık paylaşımları listelemek:

```cmd
net view \\DC01 /all
```

**Örnek Çıktı:**
```text
Shared resources at \\DC01

Share name  Type  Used as  Comment

-------------------------------------------------------------------------------
NETLOGON    Disk           Logon server share 
SYSVOL      Disk           Logon server share 
Yedekler    Disk           Kurumsal Yedek Dizini
The command completed successfully.
```

Elde edilen kimlik bilgileriyle paylaşıma yerel bir sürücü harfi (`Z:`) atayarak bağlanmak:
```cmd
net use Z: \\DC01\Yedekler /user:LAB\da_jdoe P@ssw0rd2026!
```

Bağlantıyı sonlandırmak (İz temizliği):
```cmd
net use Z: /delete /y
```

---

### Senaryo 5: Kalıcılık (Persistence) — Yerel Gizli Yönetici Oluşturma

Ele geçirilen bir iş istasyonunda veya sunucuda kalıcı arka kapı hesabı açmak:

```cmd
:: 1. Yeni kullanıcı oluştur
net user support_svc P@ssw0rd2026! /add /comment:"IT Support Diagnostic Account"

:: 2. Kullanıcıyı yerel yöneticiler grubuna ekle
net localgroup Administrators support_svc /add

:: 3. Uzak Masaüstü (RDP) erişimi için Remote Desktop Users grubuna ekle
net localgroup "Remote Desktop Users" support_svc /add
```

---

### Senaryo 6: Yerel Paylaşım Açma (Dosya Sızdırma / Staging)

Saldırgan ele geçirdiği makinede yerel bir dizini gizli bir SMB paylaşımı haline getirebilir:

```cmd
net share Exfil$=C:\Windows\Temp /grant:Everyone,FULL
```
- `Exfil$`: Paylaşım adının sonuna `$` konulduğunda paylaşım Windows Gezgini'nde gizlenir (Hidden Share).

Paylaşımı silmek:
```cmd
net share Exfil$ /delete
```

---

### Senaryo 7: PowerShell ile Tüm Domain ve Local Admin Üyelerini Tek Seferde Dökme

Komut satırı sınırlamalarını aşarak `net.exe` çıktılarını birleştiren otomasyon tek satırlığı:

```powershell
# Etki Alanı ve Yerel Yönetici Gruplarını JSON formatında çıkaran betik:
$Report = [PSCustomObject]@{
    DomainAdmins = (net group "Domain Admins" /domain | Select-Object -Skip 6 | Where-Object { $_ -and $_ -notmatch 'The command completed' -and $_ -notmatch '---' } | ForEach-Object { $_.Trim().Split('\s+') } | Where-Object { $_ })
    EnterpriseAdmins = (net group "Enterprise Admins" /domain | Select-Object -Skip 6 | Where-Object { $_ -and $_ -notmatch 'The command completed' -and $_ -notmatch '---' } | ForEach-Object { $_.Trim().Split('\s+') } | Where-Object { $_ })
    LocalAdministrators = (net localgroup Administrators | Select-Object -Skip 6 | Where-Object { $_ -and $_ -notmatch 'The command completed' -and $_ -notmatch '---' } | Where-Object { $_ })
}
$Report | ConvertTo-Json
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kodu | Olası Neden | Çözüm Adımı |
|---|---|---|
| `System error 5 has occurred. Access is denied.` | Kullanıcı ekleme, grup değiştirme veya `/domain` sorgusu için yetki yetersizdir (Local Admin veya etki alanı kimliği gereklidir). | Komut istemcisini "Run as Administrator" olarak açın veya geçerli bir Domain User bağlamında çalıştırın. |
| `System error 1311 has occurred. There are currently no logon servers available to service the logon request.` | `/domain` parametresi kullanıldığında makine etki alanı denetleyicisine ulaşamamaktadır (DNS veya ağ hatası). | DNS IP yapılandırmasını kontrol edin (`ipconfig /all`). DC IP adresine ping atarak veya `nltest /dsgetdc` ile bağlantıyı test edin. |
| `System error 1378 has occurred. The specified account name is already a member of the group.` | Kullanıcı zaten ilgili gruba eklenmiştir. | Grup üyelerini `net localgroup <grup>` ile kontrol ederek kullanıcının zaten üye olduğunu teyit edin. |
| `System error 2221 has occurred. The user name could not be found.` | Sorgulanan kullanıcı adı etki alanında veya yerel makinede mevcut değildir ya da yazım hatası yapılmıştır. | `net user /domain` listesinden tam hesap adını bulun; hesap adında boşluk varsa tırnak içine alın (`"John Doe"`). |
| `System error 53 has occurred. The network path was not found.` | `net view \\hedef` veya `net use` çalıştırıldığında hedef IP/sunucuya SMB (TCP 445) üzerinden ulaşılamamaktadır. | Hedefte Windows Güvenlik Duvarı Dosya ve Yazıcı Paylaşımını (File and Printer Sharing) engelliyor olabilir; IP adresiyle bağlanmayı deneyin. |
| `System error 1219 has occurred. Multiple connections to a server or shared resource by the same user... are not allowed.` | Hedef sunucuya farklı kimlik bilgileriyle önceden açılmış bir SMB oturumu mevcuttur. | Önceki oturumu kapatın: `net use \\hedef /delete /y` ve ardından yeni kimlik bilgisiyle komutu yeniden çalıştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

`net.exe` ve tetiklediği `net1.exe` araçları çalıştırıldığında işletim sistemi ve DC üzerinde belirgin olay günlükleri üretilir:

- **Windows Security Olay Günlükleri:**
  - **Event ID 4688 (Process Creation):** Süreç izleme etkinleştirilmişse, `New Process Name: C:\Windows\System32\net.exe` ve saniyeler sonra `C:\Windows\System32\net1.exe` ikilisi argümanlarıyla birlikte (`net group "Domain Admins" /domain`) kaydedilir.
  - **Event ID 4720 (A user account was created):** `net user <ad> <parola> /add` çalıştırıldığında tetiklenir.
  - **Event ID 4728 (A member was added to a security-enabled global group):** Etki alanı grubuna üye eklendiğinde DC'de oluşur.
  - **Event ID 4732 (A member was added to a security-enabled local group):** Yerel yöneticiler grubuna kullanıcı eklendiğinde uç noktada oluşur.
  - **Event ID 5140 / 5145 (Network Share Access):** `net view` veya `net use` ile SMB paylaşımına erişildiğinde hedef sunucuda üretilir.
- **Sysmon İzleri:**
  - **Sysmon Event ID 1 (Process Creation):** Parent-child anomalisi (`cmd.exe` -> `net.exe` -> `net1.exe`) doğrudan yakalanır.
  - **Sysmon Event ID 3 (Network Connection):** `net1.exe`'nin DC'ye TCP 445 (SMB) üzerinden bağlandığı kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **Karakteristik Parent-Child Anomalisi:** Güvenlik operasyon merkezleri (SOC) ve EDR sistemleri, `net.exe` çağrısının hemen ardından gelen `net1.exe` sürecini izler. Web shell (`w3wp.exe`), MS Office (`winword.exe`, `excel.exe`) veya komut satırı altından arka arkaya `net user /domain`, `net group "Domain Admins" /domain` çağrılması neredeyse tüm EDR'lar için doğrudan **Severity: High / Critical Reconnaissance** alarmıdır.
- **SAMR Protokol Gürültüsü:** Ağ seviyesinde DC'nin `\pipe\samr` arayüzüne yapılan aşırı sorgulamalar ağ tabanlı IDS/IPS (Suricata, Zeek) tarafından tespit edilebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.001** | Account Discovery: Local Account | Yerel kullanıcıları listeleme (`net user`). |
| **T1087.002** | Account Discovery: Domain Account | Etki alanı kullanıcılarını listeleme (`net user /domain`). |
| **T1069.001** | Permission Groups Discovery: Local Groups | Yerel yöneticileri listeleme (`net localgroup Administrators`). |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Etki alanı ayrıcalıklı gruplarını keşfetme (`net group "Domain Admins" /domain`). |
| **T1201** | Password Policy Discovery | Parola karmaşıklığı ve kilitleme politikasını çekme (`net accounts /domain`). |
| **T1135** | Network Share Discovery | Ağ paylaşımlarını haritalama (`net view`, `net share`). |
| **T1124** | System Time Discovery | DC zaman senkronizasyonunu kontrol etme (`net time /domain`). |
| **T1136.001** | Create Account: Local Account | Kalıcılık için yerel kullanıcı oluşturma (`net user /add`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`net.exe` / `net1.exe` Komut Satırı Tespiti** | Komut satırı argümanları EDR tarafından kaydedildiği için `net.exe` yerine doğrudan **PowerShell ADSI (Active Directory Service Interfaces)** veya Win32 API çağrıları kullanın: `[ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"`. |
| **Parent Process İzini Gizleme** | Doğrudan `net.exe` çağırmak yerine doğrudan `net1.exe` ikili dosyasını meşru bir süreç bağlamında başlatın. |
| **Grup Sorgularında İsim Bazlı Filtreleme** | "Domain Admins" ifadesi doğrudan SIEM kurallarına takıldığı için, LDAP filtrelerinde RID (`512`) bazlı sorgulama yapan araçlar (`ldapsearch`, `windapsearch`) tercih edilmelidir. |

### 5.5 Savunma Karşılığı (Blue Team)

- **RestrictRemoteSAM Politikası:** Windows 10/Server 2016 ve sonrasında GPO üzerinden `Network access: Restrict clients allowed to make remote calls to SAM` ayarını aktif ederek sıradan kullanıcıların SAMR üzerinden kullanıcı/grup listelemesini engelleyin.
- **Süreç Argümanı Günlüğü (Command-Line Auditing):** GPO ile `Audit Process Creation` ve `Include command line in process creation events` politikalarını açın.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Reconnaissance via Net.exe
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith:
              - '\net.exe'
              - '\net1.exe'
          CommandLine|contains:
              - 'group "Domain Admins" /domain'
              - 'group "Enterprise Admins" /domain'
              - 'accounts /domain'
              - 'user /domain'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Etki Alanı Parola ve Kilitleme Politikasını Çekme
```cmd
net accounts /domain
```
- **Ne Yapar?** Etki alanı genelindeki minimum parola uzunluğunu, maksimum parola yaşını ve hesap kilitleme eşiğini (`Lockout threshold`) listeler.
- **Ne Zaman Kullanılır?** Parola püskürtme (Password Spraying) saldırısı öncesinde kilitlenme limitlerini öğrenmek için.
- **Parametreler:** `/domain` (Sorgunun yerel makine yerine etki alanı denetleyicisine yönlendirilmesini sağlar).

### 6.2 Etki Alanındaki Tüm Kullanıcıları Listeleme
```cmd
net user /domain
```
- **Ne Yapar?** Etki alanındaki tüm kullanıcı hesaplarının kullanıcı adlarını konsola döker.
- **Ne Zaman Kullanılır?** Saldırı yüzeyini belirlemek ve parola püskürtme için kullanıcı listesi (username list) oluşturmak için.
- **Parametreler:** `/domain` (Etki alanı veritabanını sorgular).

### 6.3 Belirli Bir Kullanıcının Detaylı Profilini Sorgulama
```cmd
net user Administrator /domain
```
- **Ne Yapar?** Kullanıcının parolasının son değiştirilme tarihini, hesap kilitlenme durumunu ve üye olduğu tüm grupları gösterir.
- **Ne Zaman Kullanılır?** Hedef kullanıcının ayrıcalık seviyesini ve parola eskisini incelemek için.
- **Parametreler:** `Administrator` (Hedef kullanıcı adı), `/domain` (Etki alanı sorgusu).

### 6.4 Domain Admins Grubunun Üyelerini Listeleme
```cmd
net group "Domain Admins" /domain
```
- **Ne Yapar?** Etki alanındaki en yetkili grup olan `Domain Admins` grubuna doğrudan üye olan tüm hesapları listeler.
- **Ne Zaman Kullanılır?** Yanal hareket ve yetki yükseltme aşamasında hedeflenecek en kritik hesapları tespit etmek için.
- **Parametreler:** `"Domain Admins"` (Grup adı; boşluk içerdiği için tırnak içinde yazılmalıdır), `/domain`.

### 6.5 Enterprise Admins Grubunun Üyelerini Listeleme
```cmd
net group "Enterprise Admins" /domain
```
- **Ne Yapar?** Orman (forest) kök etki alanındaki en üst düzey ayrıcalıklı yöneticileri listeler.
- **Ne Zaman Kullanılır?** Çoklu etki alanı (multi-domain forest) ortamlarında orman genelinde tam kontrol sağlamak için.
- **Parametreler:** `"Enterprise Admins"`, `/domain`.

### 6.6 Yerel Yöneticiler Grubunu İnceleme
```cmd
net localgroup Administrators
```
- **Ne Yapar?** Bulunulan yerel makinede tam yönetici (Local Administrator) yetkisine sahip yerel ve etki alanı kullanıcılarını listeler.
- **Ne Zaman Kullanılır?** İlk erişim sağlanan makinede yerel yetki durumunu ve atanmış Domain User'ları görmek için.
- **Parametreler:** `Administrators` (Yerel yönetici grubu adı).

### 6.7 Uzak Sunucudaki Paylaşımları Listeleme
```cmd
net view \\DC01 /all
```
- **Ne Yapar?** Hedef sunucudaki tüm açık ve yönetimsel SMB paylaşımlarını döker.
- **Ne Zaman Kullanılır?** Dosya sunucularında veya DC'de okunabilir paylaşımları (`SYSVOL`, `NETLOGON`, `Backups`) belirlemek için.
- **Parametreler:** `\\DC01` (Hedef makine adı veya IP), `/all` (Tüm paylaşımları gösterir).

### 6.8 Ağ Paylaşımını Kimlik Bilgisiyle Sürücüye Bağlama
```cmd
net use Z: \\FS01\Muhasebe /user:LAB\da_jdoe P@ssw0rd2026!
```
- **Ne Yapar?** Uzak bir SMB paylaşımına yerel `Z:` sürücü harfini atayarak belirtilen kimlik bilgisiyle oturum açar.
- **Ne Zaman Kullanılır?** Ele geçirilen kimlik bilgileriyle paylaşımdaki verilere doğrudan dosya sistemi üzerinden erişmek için.
- **Parametreler:** `Z:` (Bağlanacak sürücü harfi), `/user:<Domain\Kullanıcı>` (Kimlik doğrulama hesabı).

### 6.9 Kalıcılık İçin Yeni Yerel Kullanıcı Oluşturma
```cmd
net user srv_support P@ssw0rd2026! /add /comment:"Windows Diagnostic Service Account"
```
- **Ne Yapar?** Sistemde yerel bir kullanıcı hesabı açar ve parola atar.
- **Ne Zaman Kullanılır?** Hedef makinede kalıcılık (persistence) sağlamak ve sonradan geri dönüş için arka kapı bırakmak için.
- **Parametreler:** `/add` (Yeni hesap ekleme), `/comment:` (Hesaba açıklama ekleme; şüphe çekmemek için).

### 6.10 Kullanıcıyı Yerel Yöneticiler Grubuna Ekleme
```cmd
net localgroup Administrators srv_support /add
```
- **Ne Yapar?** Oluşturulan veya mevcut bir kullanıcıyı yerel `Administrators` grubuna ekleyerek tam yetki verir.
- **Ne Zaman Kullanılır?** Oluşturulan arka kapı hesabına yerel yönetici ayrıcalıkları kazandırmak için.
- **Parametreler:** `Administrators` (Hedef grup), `srv_support` (Eklenecek kullanıcı), `/add` (Gruba ekleme bayrağı).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — net command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc771865(v=ws.11)) |
| MS-SAMR: Security Account Manager (SAM) Remote Protocol | [learn.microsoft.com](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/) |
| MITRE ATT&CK T1087 (Account Discovery) | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/) |
| LOLBAS Project — net.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← nltest](./nltest.md) · **Sonraki:** [dsquery / dsget →](./dsquery_dsget.md)
