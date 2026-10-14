# klist

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows yerel Kerberos tanı aracı; LSASS bellek önbelleğindeki Kerberos biletlerini görüntüleme (`klist`), bilet temizleme (`purge`) ve KDC'den servis bileti talep etme (`get`).

---

## 1. Genel Bakış ve Amaç

`klist.exe`, Windows Vista ve Windows Server 2008'den bu yana tüm Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\klist.exe`) bulunan yerleşik bir Kerberos bilet yönetim ve tanılama aracıdır. Windows mimarisinde Kerberos kimlik doğrulaması, **LSASS (Local Security Authority Subsystem Service)** süreci içerisindeki **Kerberos Güvenlik Destek Sağlayıcısı (Kerberos SSP - `kerberos.dll`)** tarafından yönetilir. Kullanıcıların ve makine hesaplarının etki alanı denetleyicisinden (KDC) aldıkları **TGT (Ticket Granting Ticket)** ve hedef servislere erişirken kullandıkları **TGS (Ticket Granting Service / Servis Bileti)** biletleri doğrudan LSASS bellek alanındaki oturum önbelleğinde saklanır.

Red Team operasyonlarında `klist.exe`, saldırganın sisteme ayak bastığı andan itibaren bellek içi bilet durumunu denetlemesi, enjekte edilen biletlerin (**Pass-the-Ticket, Golden/Silver Ticket**) geçerliliğini doğrulaması, harici hiçbir saldırı aracı yüklemeden yerleşik olarak KDC'den servis bileti talep ederek **Kerberoasting** hazırlığı yapması ve oturum izlerini temizlemesi (**Ticket Purging**) için en kritik LOLBin araçlarından biridir.

### Protokol ve Çalışma Prensibi

`klist.exe`, doğrudan LSASS süreciyle yerel **LPC/ALPC** üzerinden haberleşerek `LsaCallAuthenticationPackage` API fonksiyonunu tetikler:

```
┌──────────────────────────────────────────────────────────────┐
│                      Yerel İstemci                           │
│  [ klist.exe ] ──(LsaCallAuthenticationPackage)──┐           │
└──────────────────────────────────────────────────┼───────────┘
                                                   │
                                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    LSASS.EXE (Local System)                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │             Kerberos SSP (kerberos.dll)                │  │
│  │                                                        │  │
│  │  Logon Session (LUID: 0x3e7 - SYSTEM)                 │  │
│  │  Logon Session (LUID: 0x4a2f1 - jdoe)                  │  │
│  │    ├── TGT: krbtgt/LAB.LOCAL (AES-256)                 │  │
│  │    └── TGS: cifs/DC01.LAB.LOCAL (AES-256)              │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
                               │
         Kerberos Protokolü    │ 1. AS-REQ / AS-REP (Port 88)
         (Bilet Talebi: get)   │ 2. TGS-REQ / TGS-REP (Port 88)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Etki Alanı Denetleyicisi (DC)                │
│                 [ KDC (Key Distribution Center) ]            │
└──────────────────────────────────────────────────────────────┘
```

1. **Bellek İçi Bilet Önbelleği (LUID Bağlamı):** Windows her kullanıcı oturumu için benzersiz bir **LUID (Locally Unique Identifier)** oluşturur. Biletler bu LUID'ye bağlı bellek havuzunda tutulur. Düşük yetkili bir kullanıcı yalnızca kendi LUID'sine ait biletleri görebilirken, yerel yönetici (`SYSTEM` / `Elevated Admin`) tüm sistem oturumlarını (`klist sessions`) listeleyebilir.
2. **KDC ile Servis Bileti Talebi (`klist get`):** Operatör `klist get <SPN>` komutunu verdiğinde, `klist` istemciyi KDC'ye (Port 88 UDP/TCP) bir `TGS-REQ` paketi göndermeye zorlar. Dönen `TGS-REP` bileti doğrudan LSASS önbelleğine yazılır. Bu sayede harici bir araç (Rubeus, Mimikatz vb.) kullanılmadan KDC'den şifreli servis bileti belleğe indirilebilir.
3. **Bilet Temizleme (`klist purge`):** Oturumdaki tüm TGT ve TGS biletlerini bellekten silerek istemciyi sonraki ağ erişiminde yeni bir kimlik doğrulama döngüsüne zorlar.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Pass-the-Ticket Doğrulama** | Mimikatz veya Rubeus ile belleğe aktarılan TGT/TGS biletlerinin oturumda geçerli olup olmadığını teyit etme. |
| **Living off the Land Kerberoasting** | EDR tarafından engellenen harici araçlar yerine `klist get` ile hedef SPN için bilet talep etme ve belleğe alma. |
| **Ağ Erişim Analizi** | Bellekteki mevcut servis biletlerini inceleyerek kullanıcının yakın zamanda hangi sunuculara bağlandığını tespit etme. |
| **Şifreleme Türü Tespiti (Encryption Type)** | Biletlerin RC4 (`0x17`), AES-128 (`0x12`) veya AES-256 (`0x13`) şifrelemelerinden hangisini kullandığını açığa çıkarma. |
| **İz Temizleme ve Test Sıfırlama** | Hatalı veya süresi dolmuş biletleri bellekten temizleyerek (`purge`) oturumu taze bilet talep etmeye zorlama. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `klist.exe` (Windows) | `Rubeus.exe (triage/klist)` | `Mimikatz (sekurlsa::tickets)` | `klist (Linux - MIT Kerberos)` |
|---|---|---|---|---|
| **Gereksinim** | Varsayılan (Her Windows'ta var) | Harici C# Binary (.NET) | Harici C Binary / Driver | Linux krb5-user paketi |
| **Yetki İhtiyacı** | Kendi oturumu için Low-Priv, diğerleri için Admin | Diğer oturumlar için Local Admin | LSASS erişimi için Local Admin/SYSTEM | Linux kullanıcısı |
| **Bilet Dışa Aktarma (Export)** | Yok (Yalnızca görüntüler/talep eder) | Var (`dump` / `kirbi`) | Var (`export` / `.kirbi`) | Var (`KRB5CCNAME` dosyasında) |
| **EDR Algısı** | Çok Düşük (Meşru Windows LOLBin) | Yüksek (Bellek taraması & EDR imzası) | Çok Yüksek (LSASS açma uyarısı) | Yok (Linux istemci) |
| **Bilet Talep Etme (TGS Request)** | Var (`klist get <SPN>`) | Var (`Rubeus asktgs`) | Yok | Var (`kvno <SPN>`) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
klist [tickets] [-li <LUID>]
klist tgt [-li <LUID>]
klist purge [-li <LUID>]
klist get <SPN> [-kdcoptions <flags>]
klist sessions
klist bind
klist query [-li <LUID>]
```

### Alt Komutlar ve Kritik Bayraklar

| Alt Komut / Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `[tickets]` | (Varsayılan) Mevcut oturumdaki önbelleğe alınmış tüm TGT ve TGS biletlerini listeler. | `klist` |
| `tgt` | Yalnızca oturuma ait Ticket Granting Ticket (TGT) bilgilerini ve bilet bayraklarını döker. | `klist tgt` |
| `purge` | Mevcut oturumdaki (veya `-li` ile belirtilen) tüm biletleri bellekten siler. | `klist purge` |
| `get <SPN>` | Belirtilen Service Principal Name için KDC'den TGS bileti talep eder ve belleğe ekler. | `klist get cifs/DC01.lab.local` |
| `-li <LUID>` | Belirtilen Logon Session LUID değerine ait bilet havuzunu hedefler (Hex format: `0x3e7`). | `klist -li 0x3e7` |
| `sessions` | Sistemdeki tüm etkin kullanıcı oturumlarını, LUID'lerini ve kullanıcı adlarını döker (Admin gerektirir). | `klist sessions` |
| `bind` | Kerberos SSP'nin etki alanı denetleyicisi ile olan RPC binding durumunu görüntüler. | `klist bind` |
| `query` | Belirtilen oturumun kimlik ve güvenlik paketi özetini görüntüler. | `klist query` |
| `-kdcoptions <hex>` | Bilet talep ederken (`get`) KDC'ye iletilecek özel Kerberos seçenek bayraklarını belirler. | `klist get HTTP/web01 -kdcoptions 0x40810000` |

### Modül ve Yetenek Şeması

```
klist.exe Yetenek Ağacı
├── 1. Bilet Görüntüleme ve Denetim
│   ├── klist (Tüm TGT ve TGS biletleri)
│   ├── klist tgt (Yalnızca TGT ve bayraklar)
│   └── klist query (Oturum güvenlik detayları)
├── 2. Bilet Talep Etme (Kerberoasting Hazırlığı)
│   ├── klist get <SPN> (KDC'den TGS bileti çekme)
│   └── klist get <SPN> -kdcoptions <hex> (Özel bayraklarla talep)
├── 3. Çoklu Oturum Yönetimi (Privileged)
│   ├── klist sessions (Tüm kullanıcı LUID'leri)
│   ├── klist -li <LUID> (Hedef oturumun biletleri)
│   └── klist purge -li <LUID> (Hedef oturum biletlerini silme)
└── 4. Bilet ve Önbellek Temizleme
    ├── klist purge (Mevcut oturumu sıfırlama)
    └── klist bind (DC RPC bağlama analizi)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Mevcut Oturumdaki Kerberos Biletlerini ve Şifreleme Türlerini İnceleme

Hedef sisteme sızıldığında mevcut kullanıcının belleğindeki biletleri listelemek:

```cmd
klist
```

**Örnek Çıktı Analizi:**
```text
Current LogonId is 0:0x4a2f1

Cached Tickets: (2)

#0>     Client: jdoe @ LAB.LOCAL
        Server: krbtgt/LAB.LOCAL @ LAB.LOCAL
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x40e10000 -> forwardable renewable initial pre_authent name_canonicalize 
        Start Time: 10/14/2026 10:15:00 (local)
        End Time:   10/14/2026 20:15:00 (local)
        Renew Time: 10/21/2026 10:15:00 (local)
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0x1 -> PRIMARY 
        Kdc Called: DC01.lab.local

#1>     Client: jdoe @ LAB.LOCAL
        Server: MSSQLSvc/sql01.lab.local:1433 @ LAB.LOCAL
        KerbTicket Encryption Type: RSADSI RC4-HMAC(NT)
        Ticket Flags 0x40a10000 -> forwardable renewable pre_authent name_canonicalize 
        Start Time: 10/14/2026 10:30:12 (local)
        End Time:   10/14/2026 20:15:00 (local)
        Renew Time: 10/21/2026 10:15:00 (local)
        Session Key Type: RSADSI RC4-HMAC(NT)
        Cache Flags: 0 
        Kdc Called: DC01.lab.local
```
- `#0 Ticket (krbtgt)`: Bu bilet kullanıcının **TGT** biletidir. `Encryption Type: AES-256` modern ve güvenli bir şifreleme kullanıldığını gösterir.
- `#1 Ticket (MSSQLSvc)`: Bu bir **TGS** servis biletidir. `KerbTicket Encryption Type: RSADSI RC4-HMAC(NT)` kullanmaktadır. **RC4 (0x17)** tipi biletler, çevrimdışı parola kırma (Kerberoasting) saldırılarına karşı son derece savunmasızdır!
- `End Time`: Biletin ne zaman süresinin dolacağını gösterir. Bu süreden sonra bilet geçersiz kalacaktır.

---

### Senaryo 2: Yalnızca TGT (Ticket Granting Ticket) ve Session Key Özniteliklerini İnceleme

Kullanıcının etki alanı kimlik kanıtı olan TGT detaylarını izole etmek:

```cmd
klist tgt
```

**Örnek Çıktı:**
```text
Current LogonId is 0:0x4a2f1

Cached TGT:

ServiceName              : krbtgt
TargetName (Requested)   : krbtgt
FullServiceName          : krbtgt/LAB.LOCAL
DomainName               : LAB.LOCAL
TargetDomainName         : LAB.LOCAL
ClientName               : jdoe
DomainName               : LAB.LOCAL
Extended Error           : 0x0
Key (Session Key)        : [AES-256-CTS-HMAC-SHA1-96] KeyType 0x13
Ticket                   : [AES-256-CTS-HMAC-SHA1-96] KeyType 0x13
The command completed successfully.
```

---

### Senaryo 3: LOLBin ile Kerberoasting — Komut Satırından TGS Bileti Talep Etme

Sistemde EDR veya antivirüs Rubeus / Invoke-Kerberoast gibi araçları engelliyorsa, yerel `klist get` komutu ile hedef SPN için KDC'den servis bileti talep ettirilebilir:

```cmd
klist get MSSQLSvc/sql01.lab.local:1433
```

**Örnek Çıktı:**
```text
Current LogonId is 0:0x4a2f1
A ticket to MSSQLSvc/sql01.lab.local:1433 has been retrieved.
Server: MSSQLSvc/sql01.lab.local:1433 @ LAB.LOCAL
KerbTicket Encryption Type: RSADSI RC4-HMAC(NT)
Ticket Flags 0x40a10000 -> forwardable renewable pre_authent name_canonicalize 
Start Time: 10/14/2026 11:05:40 (local)
End Time:   10/14/2026 20:15:00 (local)
The command completed successfully.
```
- Bu komut KDC'ye bir `TGS-REQ` paketi gönderir ve dönen şifreli bileti LSASS önbelleğine kaydeder.
- Ardından operatör bellek dökümü (LSASS dump veya `sekurlsa::tickets`) alarak veya PowerShell ile bilet önbelleğini okuyarak bu bileti çevrimdışı hash kırma formatına dönüştürebilir.

---

### Senaryo 4: Pass-the-Ticket (PTT) / Golden Ticket Enjeksiyonunun Doğrulanması

Saldırgan Mimikatz (`kerberos::ptt`) veya Rubeus (`ptt /ticket:...`) ile oturuma sahte veya çalınmış bir bilet enjekte ettiğinde, biletin işletim sistemi tarafından kabul edilip edilmediği `klist` ile test edilir:

```cmd
klist
```
Eğer çıktı enjekte edilen kullanıcı adına (`Client: Administrator @ LAB.LOCAL`) ve hedef etki alanına işaret ediyorsa, PTT saldırısı başarılı olmuştur ve ağ komutları (`dir \\DC01\C$`) bu biletle yürütülebilir.

---

### Senaryo 5: Biletlerin Temizlenmesi (Purge) ve Yeniden Kimlik Doğrulama Zorlama

İz temizlemek veya test senaryolarında oturumu sıfırlamak için:

```cmd
klist purge
```

**Örnek Çıktı:**
```text
Current LogonId is 0:0x4a2f1
        Deleting ticket #0>     Client: jdoe @ LAB.LOCAL
        Deleting ticket #1>     Client: jdoe @ LAB.LOCAL
Tickets deleted in current logon session!
The command completed successfully.
```

---

### Senaryo 6: Yerel Yönetici Yetkisiyle Tüm Kullanıcı Oturumlarının (LUID) Taranması

Yüksek yetkili bir oturumda (`Administrator` veya `SYSTEM`), makinedeki tüm oturumlar listelenir:

```cmd
klist sessions
```

**Örnek Çıktı:**
```text
LogonId: 0:0x3e7
  User: WORKSTATION01$ (SYSTEM)
  Package: Kerberos

LogonId: 0:0x4a2f1
  User: jdoe (Interactive)
  Package: Kerberos

LogonId: 0:0x9c812
  User: da_admin (RemoteInteractive / RDP)
  Package: Kerberos
The command completed successfully.
```

Ele geçirilen hedef yönetici oturumuna (`0x9c812`) ait biletleri görüntülemek:
```cmd
klist -li 0x9c812
```

---

### Senaryo 7: PowerShell ile Bellekteki Biletleri Parse Eden ve Zayıf RC4 Biletlerini Raporlayan Betik

`klist` çıktısını otomatik ayrıştıran operasyonel betik:

```powershell
# klist çıktısındaki RC4 şifrelemeli (Kerberoastable) biletleri tespit eden script:
$Tickets = klist | Out-String
$TicketBlocks = $Tickets -split '(?=#\d+>)' | Where-Object { $_ -match '#\d+>' }

$Results = foreach ($block in $TicketBlocks) {
    [PSCustomObject]@{
        Index          = ($block | Select-String '#(\d+)>').Matches.Groups[1].Value
        Server         = ($block | Select-String 'Server:\s+([^\r\n]+)').Matches.Groups[1].Value.Trim()
        EncryptionType = ($block | Select-String 'KerbTicket Encryption Type:\s+([^\r\n]+)').Matches.Groups[1].Value.Trim()
        EndTime        = ($block | Select-String 'End Time:\s+([^\r\n]+)').Matches.Groups[1].Value.Trim()
        IsVulnerable   = if ($block -match 'RC4') { "YES (RC4 - Kerberoastable)" } else { "NO (AES)" }
    }
}
$Results | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `klist failed with 0x8009030e: No credentials available in the security package.` | Oturumda hiçbir Kerberos bileti yoktur; kullanıcı yerel bir hesapla oturum açmış veya henüz hiçbir etki alanı kaynağına erişmemiştir. | Bir etki alanı kaynağına erişim deneyin (`dir \\DC01\SYSVOL`) veya bir etki alanı kullanıcısı bağlamında komut çalıştırın. |
| `klist failed with 0x80090304: The system cannot contact a domain controller...` | `klist get` çalıştırıldığında istemci KDC'ye (TCP/UDP Port 88) ulaşamamaktadır. | Ağ ve DNS yapılandırmasını kontrol edin; DC IP'sini pingleyin ve Port 88 erişimini test edin (`Test-NetConnection <DC_IP> -Port 88`). |
| `Target SPN could not be found / KDC_ERR_S_PRINCIPAL_UNKNOWN (0x7)` | `klist get <SPN>` ile istenen servis adı Active Directory'de hiçbir kullanıcı veya bilgisayar hesabında kayıtlı değildir. | SPN adını doğrulayın; `setspn -Q <SPN>` veya `dsquery * -filter "(servicePrincipalName=...)"` ile SPN'in varlığını kontrol edin. |
| `Error 0x520 / 0x521: A specified logon session does not exist.` | `-li <LUID>` ile sorgulanan oturum kimliği kapanmış veya geçersizdir ya da bu oturumu sorgulamak için yönetici yetkiniz yoktur. | `klist sessions` ile aktif LUID listesini yeniden alın ve komut istemcisini yönetici ("Run as Administrator") olarak başlatın. |
| `KRB_AP_ERR_SKEW (0x25): Clock skew too great.` | İstemci saati ile etki alanı denetleyicisi saati arasında 5 dakikadan fazla fark vardır. | İstemci saatini DC ile senkronize edin: `net time \\DC01 /set /y` veya `w32tm /resync`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Windows Güvenlik Olay Günlükleri (DC Tarafı):**
  - **Event ID 4768 (A Kerberos authentication ticket (TGT) was requested):** Kullanıcı oturum açtığında veya yeni bir TGT aldığında DC'de oluşur.
  - **Event ID 4769 (A Kerberos service ticket was requested):** `klist get <SPN>` çalıştırıldığında DC üzerinde doğrudan kaydedilir. Eğer bilet şifreleme türü `0x17 (RC4-HMAC)` ise SIEM sistemleri bunu **Kerberoasting Tespiti** olarak etiketler.
- **Uç Nokta Günlükleri (Endpoint):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `klist.exe purge` veya `klist.exe get <SPN>` komut argümanları kaydedilir.
  - **Sysmon Event ID 3 (Network Connection):** `klist get` çalıştırıldığında `klist.exe` veya LSASS sürecinin DC IP'sine Port 88 üzerinden açtığı bağlantı kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **LOLBin Güvenilirliği:** `klist.exe`, Windows çekirdek tanı aracı olduğundan antivirüsler ve AppLocker tarafından engellenmez.
- **EDR Komut Satırı Kuralları:** `klist purge` çağrısı, savunma araçları (EDR) tarafından yanal hareket öncesi bilet tazeleme veya Pass-the-Ticket hazırlığı olarak kabul edilip `Warning / Medium` seviyesinde loglanabilir.
- **`klist get` ile Anormal Bilet Talebi:** Bir iş istasyonunun aniden MSSQL, HTTP veya CIFS servisleri için peş peşe `klist get` çalıştırması davranışsal analiz (UEBA) alarmlarını tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | `klist get <SPN>` ile servis biletlerini talep ederek belleğe çekme. |
| **T1550.002** | Use Alternate Authentication Material: Pass the Ticket | Enjekte edilen biletlerin bellekte geçerliliğini doğrulama (`klist`). |
| **T1558.001** | Steal or Forge Kerberos Tickets: Golden Ticket | Sahte krbtgt TGT biletini denetleme (`klist tgt`). |
| **T1082** | System Information Discovery | Oturumdaki aktif biletler üzerinden hedef sunucuları haritalama. |
| **T1070** | Indicator Removal on Host | Biletleri temizleyerek adli izleri silme (`klist purge`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **`klist purge` Alarmı** | Biletleri manuel purge etmek yerine doğal yollarla oturumun kapanmasını veya bilet süresinin (varsayılan 10 saat) dolmasını bekleyin. |
| **`klist get` Komut Satırı İmzası** | `klist get SPN` çalıştırmak yerine, doğrudan hedef kaynağa meşru bir bağlantı başlatın (Örn: `Test-NetConnection` veya PowerShell üzerinden HTTP/SMB tetiklemesi). Bu sayede Kerberos bileti işletim sistemi tarafından arka planda doğal olarak talep edilir. |
| **RC4 Şifreleme Tuzağı** | Güncel ortamlarda yalnızca RC4 biletleri izlendiği için, KDC seçeneklerinde AES destekli biletler talep edilmelidir. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Event 4769 Bilet Denetimi:** DC güvenlik günlüklerinde `Ticket Options: 0x40810000` ve `Ticket Encryption Type: 0x17` içeren olayları izleyerek Kerberoasting girişimlerini anında tespit edin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Suspicious Kerberos Ticket Operations via KLIST
  status: medium
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\klist.exe'
          CommandLine|contains:
              - 'purge'
              - 'get '
              - '-li '
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Oturumdaki Tüm Kerberos Biletlerini Listeleme
```cmd
klist
```
- **Ne Yapar?** Kullanıcı oturumundaki önbelleğe alınmış tüm TGT ve TGS biletlerini, geçerlilik sürelerini ve şifreleme türlerini listeler.
- **Ne Zaman Kullanılır?** İlk erişim sağlandığında kullanıcının hangi servislere eriştiğini ve bilet şifreleme tiplerini analiz etmek için.
- **Parametreler:** Ek parametre gerektirmez.

### 6.2 Yalnızca TGT (Ticket Granting Ticket) Biletini Gösterme
```cmd
klist tgt
```
- **Ne Yapar?** Oturumdaki yalnızca TGT biletinin detaylarını, KDC adresini ve session key şifreleme algoritmasını döker.
- **Ne Zaman Kullanılır?** Pass-the-Ticket veya Golden Ticket enjeksiyonu sonrasında etki alanı kimlik biletinin varlığını teyit etmek için.
- **Parametreler:** `tgt` (Yalnızca TGT filtresi).

### 6.3 Bellekteki Tüm Kerberos Biletlerini Temizleme
```cmd
klist purge
```
- **Ne Yapar?** Mevcut oturumdaki tüm biletleri LSASS bellek önbelleğinden anında siler.
- **Ne Zaman Kullanılır?** Yeni bir bilet enjekte etmeden önce eski bilet çakışmalarını önlemek veya test sonrası adli izleri temizlemek için.
- **Parametreler:** `purge` (Bilet silme komutu).

### 6.4 Belirli Bir Servis İçin KDC'den TGS Bileti Talep Etme
```cmd
klist get MSSQLSvc/sql01.lab.local:1433
```
- **Ne Yapar?** Belirtilen SQL Server SPN'i için etki alanı denetleyicisinden canlı bir Kerberos servis bileti çeker ve belleğe yükler.
- **Ne Zaman Kullanılır?** Harici araç olmadan Living-off-the-Land Kerberoasting bilet talebi gerçekleştirmek için.
- **Parametreler:** `get <SPN>` (Hedef servis adı).

### 6.5 Sistemdeki Tüm Logon Session LUID Değerlerini Listeleme
```cmd
klist sessions
```
- **Ne Yapar?** Sistemde aktif olan tüm kullanıcı oturumlarının LUID numaralarını, kullanıcı adlarını ve oturum tiplerini döker.
- **Ne Zaman Kullanılır?** Yerel yönetici yetkisi elde edildiğinde bellekte bilet barındıran diğer etki alanı yöneticilerini tespit etmek için.
- **Parametreler:** `sessions` (Yönetici yetkisi gerektirir).

### 6.6 Belirli Bir Oturumun Biletlerini İnceleme
```cmd
klist -li 0x3e7
```
- **Ne Yapar?** `0x3e7` (Yerel SYSTEM oturumu) veya başka bir kullanıcının LUID oturumundaki bilet havuzunu döker.
- **Ne Zaman Kullanılır?** Makine hesabının (`COMPUTER$`) veya oturumu açık kalmış bir etki alanı yöneticisinin biletlerini incelemek için.
- **Parametreler:** `-li <LUID>` (Hedef oturum kimliği).

### 6.7 Kerberos Domain Bağlama (Binding) Önbelleğini Görüntüleme
```cmd
klist bind
```
- **Ne Yapar?** Kerberos SSP'nin etki alanındaki hangi DC ile RPC bağlamı kurduğunu listeler.
- **Ne Zaman Kullanılır?** İstemcinin hangi etki alanı denetleyicisi ile aktif iletişim kurduğunu doğrulamak için.
- **Parametreler:** `bind`.

### 6.8 HTTP Web Servisi İçin Kerberos Servis Bileti Çekme
```cmd
klist get HTTP/webportal.lab.local
```
- **Ne Yapar?** Kurumsal intranet web sunucusu için bilet talep eder.
- **Ne Zaman Kullanılır?** Web servis hesabının parolasını kırmak veya web sunucusuna kimlik doğrulama testi yapmak için.
- **Parametreler:** `get HTTP/<FQDN>`.

### 6.9 Belirli Bir Oturumun Biletlerini Bellekten Silme
```cmd
klist purge -li 0x4a2f1
```
- **Ne Yapar?** Belirtilen hedef LUID oturumundaki tüm biletleri uzaktan temizler.
- **Ne Zaman Kullanılır?** Hedef bir kullanıcının biletini sıfırlayarak onu yeniden kimlik doğrulamaya (veya parola sormaya) zorlamak için.
- **Parametreler:** `purge`, `-li <LUID>`.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — klist command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh831592(v=ws.11)) |
| RFC 4120: The Kerberos Network Authentication Service (V5) | [datatracker.ietf.org](https://datatracker.ietf.org/doc/html/rfc4120) |
| MITRE ATT&CK T1558.003 (Kerberoasting) | [attack.mitre.org](https://attack.mitre.org/techniques/T1558/003/) |
| LOLBAS Project — klist.exe | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← dsquery / dsget](./dsquery_dsget.md) · **Sonraki:** [certutil →](./certutil.md)
