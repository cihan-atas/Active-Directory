# nltest

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows yerel komut satırı aracı; Netlogon servisi üzerinden DC tespiti, güvenli kanal (secure channel) doğrulaması, güven ilişkileri (trusts) ve kullanıcı sorgulaması.

---

## 1. Genel Bakış ve Amaç

`nltest.exe`, Windows işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\nltest.exe`) bulunan ve **Netlogon** hizmeti (`netlogon.dll`) ile doğrudan etkileşime geçen yerel bir yönetim ve tanılama aracıdır. Bir Active Directory sızma testinde veya Red Team operasyonunda sisteme ilk ayak basıldığında (foothold), harici hiçbir araç (third-party binary) yüklemeden hedef etki alanının mimarisini, etki alanı denetleyicilerini (Domain Controller), orman (forest) sınırlarını ve güven ilişkilerini (domain trusts) haritalamak için en kritik **LOLBin (Living Off the Land Binary)** araçlarından biridir.

### Protokol ve Çalışma Prensibi

`nltest`, istemci ile etki alanı denetleyicisi arasındaki **MS-NRPC (Netlogon Remote Protocol)** ve **DC Locator (DsGetDcName)** mekanizmalarını tetikler. Çalışma mimarisi şu şekildedir:

```
┌──────────────────────────────────────────────────────────────┐
│                      Yerel İstemci                           │
│  [ nltest.exe ] ──(LPC / ALPC)──► [ Netlogon Servisi ]       │
└──────────────────────────────────────────┬───────────────────┘
                                           │
             1. DNS SRV Sorgusu (_ldap._tcp.dc._msdcs.domain)  
             2. ICMP Ping / LDAP Ping (Port 389 UDP)           
             3. Netlogon RPC (MSRPC / TCP 135 & Dinamik Port)   
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────┐
│                 Etki Alanı Denetleyicisi (DC)                │
│             [ Netlogon (LSASS) / Active Directory ]          │
│                                                              │
│  - Secure Channel (Kayıtlı Parola Doğrulaması)               │
│  - Trust İlişkileri ve Yönleri (Inbound/Outbound/Bidirectional)
│  - Site ve Kapsama Alanı Bilgileri                           │
└──────────────────────────────────────────────────────────────┘
```

1. **DC Locator Süreci:** `nltest /dsgetdc:domain` çalıştırıldığında, istemci işletim sistemi DNS sunucusuna `_ldap._tcp.dc._msdcs.<DomainName>` SRV kayıtlarını sorar, dönen DC listesine UDP 389 üzerinden bir LDAP ping (mailslot) göndererek en yakın ve yanıt veren DC'yi tespit eder.
2. **Secure Channel (Güvenli Kanal):** Etki alanına katılmış her Windows makinesinin bilgisayar hesabı (`MACHINE$`) ile etki alanı denetleyicisi arasında paylaşılan bir simetrik parola (Computer Password) bulunur. `nltest /sc_query`, Netlogon servisinin bu güvenli kanal üzerinden DC ile kurduğu şifreli tüneli (RPC over SMB veya doğrudan RPC) sorgular.
3. **Trust Enumeration:** `nltest /domain_trusts`, etki alanının orman içi ve ormanlar arası güven ilişkilerini doğrudan etki alanı denetleyicisindeki LSA (Local Security Authority) veritabanından çeker.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Sıfır İndirme Keşfi (Living off the Land)** | Harici dosya bırakmadan (fileless) sistemde yerleşik olarak DC ve güven ilişkisi tespiti. |
| **Trust Haritalama (Forest Hop)** | Ormanlar arası geçiş yollarını (Trust Direction, Transitive, SID Filtering) tek komutla açığa çıkarma. |
| **PDC Emulator ve Site Tespiti** | Ağdaki PDC (Primary Domain Controller) ve istemcinin bulunduğu Active Directory Site'ını öğrenme. |
| **Güvenli Kanalın (Secure Channel) Durumu** | Makinenin etki alanıyla iletişim yeteneğini ve makine parolası senkronizasyonunu kontrol etme. |
| **Kullanıcı Doğrulama ve Bilgi Çekme** | LDAP yerine Netlogon RPC üzerinden hesap kilitleme, parola yaşı ve grup SID bilgilerini sorgulama. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `nltest.exe` | `netdom.exe` | `PowerShell (ActiveDirectory)` | `dsquery.exe` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Windows 7/Server 2008+'da hazır | RSAT gerektirebilir | RSAT/AD Modülü gerektirir | Server OS veya RSAT gerekir |
| **Protokol** | MS-NRPC, MSRPC, DNS | RPC, LDAP | LDAP, ADWS (Port 9389) | LDAP (Port 389/636) |
| **Ayrıcalık Gereksinimi** | Düşük Yetkili Kullanıcı | Genelde Local Admin | Düşük Yetkili Kullanıcı | Düşük Yetkili Kullanıcı |
| **EDR Görünürlüğü / OPSEC** | Komut satırı izlenir, ağ izi az | Komut satırı izlenir | Script Block Logging (EID 4104) | Komut satırı ve LDAP logları |
| **Trust Analizi Derinliği** | Yüksek (Bayraklar, SID'ler) | Orta | Çok Yüksek (Objeler) | Düşük |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
nltest [/SERVER:<ServerName>] <Sorgu_Parametresi> [Seçenekler]
```

Eğer `/SERVER:<ServerName>` belirtilmezse, komut çalıştırılan yerel makineyi hedef alır.

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `/dclist:<DomainName>` | Belirtilen etki alanındaki tüm Domain Controller'ları listeler. | `nltest /dclist:lab.local` |
| `/dsgetdc:<DomainName>` | DC Locator API'sini çağırarak en uygun DC ve özelliklerini gösterir. | `nltest /dsgetdc:lab.local` |
| `/domain_trusts` | Bulunulan etki alanının bildiği tüm güven (trust) ilişkilerini listeler. | `nltest /domain_trusts` |
| `/all_trusts` | `/domain_trusts` ile birlikte kullanılarak tüm orman ve transitif güvenleri döker. | `nltest /domain_trusts /all_trusts /v` |
| `/v` | Ayrıntılı (verbose) çıktı formatını aktif eder (Trust bayrakları ve SID'leri gösterir). | `nltest /domain_trusts /v` |
| `/sc_query:<DomainName>` | Yerel veya uzak makinenin hedef domain ile güvenli kanal durumunu sorgular. | `nltest /sc_query:lab.local` |
| `/sc_verify:<DomainName>` | Güvenli kanalı DC ile gerçek zamanlı bir RPC çağrısı yaparak test eder. | `nltest /sc_verify:lab.local` |
| `/sc_reset:<DomainName>` | Güvenli kanalı sıfırlar ve zorla yeni bir DC ile kanal kurar. | `nltest /sc_reset:lab.local\DC02` |
| `/sc_change_pwd:<DomainName>` | Makine hesabının etki alanı parolasını anında değiştirir. | `nltest /sc_change_pwd:lab.local` |
| `/dsgetsite` | İstemcinin şu an bağlı olduğu Active Directory Site adını döndürür. | `nltest /dsgetsite` |
| `/dsgetsitecov` | Etki alanındaki DC'lerin kapsadığı tüm Site adlarını listeler. | `nltest /dsgetsitecov` |
| `/user:<UserName>` | Belirtilen kullanıcının Netlogon özniteliklerini (SID, bayraklar vb.) çeker. | `nltest /user:Administrator` |
| `/whowill:<Domain> <User>` | Kullanıcının kimlik doğrulamasını hangi DC'nin karşılayacağını simüle eder. | `nltest /whowill:lab.local jdoe` |
| `/parentdomain` | Bulunulan child domain'in üst (parent) etki alanını gösterir. | `nltest /parentdomain` |
| `/dsgetfti:<DomainName>` | Orman güveni bilgilerini (Forest Trust Info - FTI) ve SID filtrelerini listeler. | `nltest /dsgetfti:target.corp` |
| `/query` | Yerel Netlogon servisinin genel çalışma ve önbellek durumunu raporlar. | `nltest /query` |
| `/server:<ServerName>` | Komutun uzaktaki bir sunucu/DC bağlamında yürütülmesini sağlar. | `nltest /server:DC01 /query` |

### Yetenek Bazlı Parametre Grupları

```
nltest Parametre Grupları
├── 1. DC Keşfi ve Locator
│   ├── /dclist:<Domain>           (Tüm DC'ler)
│   ├── /dsgetdc:<Domain> [/flags] (En uygun DC, PDC, GC tespiti)
│   └── /parentdomain              (Üst etki alanı tespiti)
├── 2. Güven (Trust) Analizi
│   ├── /domain_trusts             (Doğrudan güven ilişkileri)
│   ├── /all_trusts                (Transitif ve orman güvenleri)
│   └── /dsgetfti:<Domain>         (SID filtreleme ve Forest Trust Info)
├── 3. Güvenli Kanal (Secure Channel) Sağlığı
│   ├── /sc_query:<Domain>         (Güvenli kanal durumu)
│   ├── /sc_verify:<Domain>        (Kanal bağlantı testi)
│   └── /sc_reset:<Domain>         (Kanalı yeniden kurma)
└── 4. Kimlik ve Site Bilgisi
    ├── /dsgetsite                 (İstemci AD Site'ı)
    ├── /user:<Kullanıcı>          (Kullanıcı kimlik detayları)
    └── /whowill:<Domain> <User>   (Oturum açma DC testi)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: İlk Ayak İzi Sonrası DC ve Orman Tespiti

Saldırgan bir kullanıcı iş istasyonuna eriştiğinde ilk olarak ağdaki etki alanı yapısını anlamalıdır:

```cmd
nltest /dsgetdc:lab.local
```

**Örnek Çıktı Analizi:**
```text
           DC: \\DC01.lab.local
      Address: \\192.168.1.10
     Dom Guid: 3b14522a-6379-425d-bb85-ef163829cf92
     Dom Name: lab.local
  Forest Name: lab.local
 Dc Site Name: Default-First-Site-Name
Our Site Name: Default-First-Site-Name
        Flags: PDC GC DS LDAP KDC TIMESERV GTIMESERV WRITABLE DNS_DC DNS_DOMAIN DNS_FOREST CLOSE_SITE FULL_SECRET WS
The command completed successfully
```
- `Flags: PDC`: Bu sunucunun Primary Domain Controller Emulator (PDCE) rolüne sahip olduğunu doğrular.
- `Flags: GC`: Global Catalog sunucusudur (Orman çapında sorgular bu sunucuya yapılabilir).
- `Flags: KDC`: Kerberos Key Distribution Center servisini barındırır.
- `Address`: DC'nin IP adresini verir; DNS çözümlemesine gerek kalmadan hedef belirlenir.

Tüm etki alanı denetleyicilerini dökmek için:
```cmd
nltest /dclist:lab.local
```

---

### Senaryo 2: Trust İlişkilerini ve SID Filtreleme Durumunu Haritalama

Yetki yükseltme veya ormanlar arası geçiş (Forest Pivoting) için güven ilişkilerinin eksiksiz analizi:

```cmd
nltest /domain_trusts /all_trusts /v
```

**Örnek Çıktı Analizi:**
```text
List of domain trusts:
    0: LAB lab.local (NT 5) (Forest Tree Root) (Primary Domain) (Native)
        GUID: 3b14522a 6379 425d bb85 ef163829cf92
        SID: S-1-5-21-1111111111-2222222222-3333333333
    1: DEV dev.lab.local (NT 5) (Tree Child) (Direct Outbound) (Direct Inbound)
        GUID: 8a7f1b2c 1234 4567 89ab cdef01234567
        SID: S-1-5-21-4444444444-5555555555-6666666666
    2: PARTNER partner.corp (NT 5) (Forest: partner.corp) (External) (Direct Outbound)
        GUID: 9f8e7d6c 5432 10fe dcba 76543210fedc
        SID: S-1-5-21-7777777777-8888888888-9999999999
        Flags: [0x2] NON_TRANSITIVE
The command completed successfully
```
- `Direct Outbound`: Bulunduğumuz etki alanı karşı tarafa güveniyor (Bizim kaynaklarımıza onlar gelebilir).
- `Direct Inbound`: Karşı taraf bize güveniyor (Biz onların kaynaklarına erişebiliriz - Saldırgan için altın değerinde!).
- `Forest Tree Root` vs `Tree Child`: Hiyerarşik child domain yapısını ve geçiş yollarını gösterir.

Forest Trust Information (FTI) ve SID Filtreleme kontrolü:
```cmd
nltest /dsgetfti:partner.corp
```

---

### Senaryo 3: Güvenli Kanal Doğrulaması (Secure Channel Check)

Bir makine hesabının etki alanı ile ilişkisini test etmek ve makine parolasının geçerliliğini denetlemek:

```cmd
nltest /sc_query:lab.local
```

Güvenli kanal üzerinden DC ile canlı bir RPC handshake gerçekleştirmek:
```cmd
nltest /sc_verify:lab.local
```

**Örnek Çıktı:**
```text
Flags: b0 KEY_VERIFIED 
Connection Status = 0 0x0 NERR_Success
The trust relationship between this workstation and the "lab.local" domain is acceptable.
The command completed successfully
```

---

### Senaryo 4: Kullanıcı Hesabı Detaylarını Netlogon Üzerinden Sorgulama

LDAP portları engellenmiş veya izleniyor olsa dahi, Netlogon RPC üzerinden hesap kontrolü:

```cmd
nltest /user:jdoe
```

**Örnek Çıktı:**
```text
User: jdoe
Status: 0 0x0 NERR_Success
flags: 0x20000000 (NORMAL_ACCOUNT)
auth_flags: 0x0
User Id: 0x452 (1106)
Primary Group Id: 0x201 (513 - Domain Users)
Number of groups: 3
Group: 513
Group: 1102
Group: 1105
Logon Server: \\DC01
Logon Script: logon.bat
Profile Path: \\filesrv\profiles\jdoe
Home Directory: \\filesrv\users\jdoe
Bad Password Count: 0
Number of Logons: 42
The command completed successfully
```
- `Bad Password Count`: Parola püskürtme (Password Spraying) saldırısı öncesinde kilitlenme riskini ölçmek için kritik değerdir.
- `Primary Group Id` ve `Group`: Kullanıcının dahil olduğu grupların RID değerleridir.

---

### Senaryo 5: Active Directory Site ve Kapsama Analizi

Saldırgan hangi fiziksel/mantıksal ağ segmentinde olduğunu anlamak için Site bilgisini kullanır:

```cmd
nltest /dsgetsite
```

Ağdaki tüm DC'lerin kapsadığı Site yapılandırmasını listelemek:
```cmd
nltest /dsgetsitecov
```

---

### Senaryo 6: Uzak Sunucu Üzerinde Netlogon Durumu Sorgulama

Yanal hareket (Lateral Movement) sonrası ele geçirilen bir sunucunun hangi DC'ye bağlı olduğunu uzaktan sorgulama:

```cmd
nltest /server:SRV-WEB01 /query
```

---

### Senaryo 7: PowerShell ile Tüm DC ve Trust Yapısını Otomatik Parse Eden Wrapper

`nltest` çıktısını ayrıştırıp JSON veya tablo formatına dönüştüren operasyonel PowerShell tek satırlığı:

```powershell
# Tüm Domain Controller'ları IP adresleriyle birlikte nesneleştiren script:
(nltest /dclist:(Get-CimInstance Win32_ComputerSystem).Domain) | Where-Object { $_ -match '^\\\\' } | ForEach-Object {
    $dcName = ($_.Split(' ')[0] -replace '^\\\\','').Trim()
    [PSCustomObject]@{
        DCName = $dcName
        IPAddress = ([System.Net.Dns]::GetHostAddresses($dcName) | Where-Object {$_.AddressFamily -eq 'InterNetwork'} | Select-Object -ExpandProperty IPAddressToString -First 1)
        Status = if ($_ -match 'PDC') { "Primary DC" } else { "Replica DC" }
    }
} | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `ERROR_NO_SUCH_DOMAIN (0x54b - 1355)` | DNS sunucusu etki alanını çözemiyor veya `_ldap._tcp.dc._msdcs` SRV kaydı bulunamıyor. | İstemcinin DNS ayarlarını kontrol edin (`ipconfig /all`). Etki alanı DC IP'sini birincil DNS olarak ekleyin veya `/dsgetdc` yerine `/server:<DC_IP>` deneyin. |
| `ERROR_ACCESS_DENIED (0x5)` | Çalıştırılan komut yerel yönetici veya yetkili hesap gerektiriyor (`/sc_reset` veya `/sc_change_pwd`). | Keşif komutları (`/dsgetdc`, `/domain_trusts`, `/dclist`) düşük yetkiyle çalışır; yönetimsel komutlar için `RunAs` veya yetki yükseltme uygulayın. |
| `RPC_S_SERVER_UNAVAILABLE (0x6ba - 1722)` | Hedef makinede veya DC'de RPC servisi yanıt vermiyor; TCP 135 veya dinamik RPC portları (49152-65535) güvenlik duvarında engelli. | Ağ yolundaki güvenlik duvarını kontrol edin; SMB bağlantısını (`net view \\DC01`) test edin. |
| `ERROR_NO_LOGON_SERVERS (0x51f - 1311)` | İstemci etki alanı denetleyicisi ile hiçbir ağ kanalı üzerinden iletişim kuramıyor (Kablo çekik, izole VLAN). | Ağ erişilebilirliğini doğrulayın (`ping <DC_IP>`); Netlogon servisinin çalıştığından emin olun (`sc query netlogon`). |
| `NERR_NetlogonNotStarted (0x89a - 2192)` | Yerel makinede Netlogon servisi durdurulmuş veya devre dışı bırakılmış. | `net start netlogon` komutuyla servisi başlatın veya servisin durumunu `sc qc netlogon` ile kontrol edin. |
| `ERROR_TRUSTED_DOMAIN_FAILURE (0x6fc - 1788)` | Etki alanları arasındaki güven ilişkisi (Trust Password / Shared Secret) bozulmuş veya senkronizasyon kaybolmuş. | Güven ilişkisinin her iki tarafta yeniden yapılandırılması veya `/sc_reset` komutu ile güvenli kanalın yenilenmesi gerekir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

`nltest.exe` çalıştırıldığında uç noktada ve etki alanı denetleyicisinde şu olay günlükleri oluşur:

- **Windows Security Olay Günlükleri:**
  - **Event ID 4688 (Process Creation):** Süreç oluşturma denetimi açıksa, `Process Name: C:\Windows\System32\nltest.exe` ve `CommandLine` argümanları (`/domain_trusts`, `/dclist`, `/dsgetdc`) kaydedilir.
  - **Event ID 4624 (Successful Logon - Type 3):** Ağ üzerinden uzak bir DC'ye `/user` veya `/whowill` ile sorgu atıldığında Kerberos veya NTLM ağ oturumu oluşur.
  - **Event ID 5805 / 5723 (Netlogon Failures):** Güvenli kanal doğrulaması başarısız olursa etki alanı denetleyicisinin `System` günlüğüne Netlogon uyarıları düşer.
- **Sysmon İzleri:**
  - **Sysmon Event ID 1 (Process Creation):** `ParentImage` (örneğin `cmd.exe` veya `powershell.exe`), tam `CommandLine` ve hash bilgileri loglanır.
  - **Sysmon Event ID 3 (Network Connection):** `nltest.exe`'nin DC IP'sine doğru TCP 135 veya dinamik MSRPC portlarına açtığı bağlantılar kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **LOLBin Avantajı:** `nltest.exe`, Microsoft tarafından dijital imzalı meşru bir Windows sistem dosyası olduğu için dosya bütünlüğü kontrollerinden (AppLocker, Windows Defender Application Control - WDAC) doğrudan geçer.
- **EDR Komut Satırı Tespiti:** Modern EDR sistemleri (CrowdStrike, Defender for Endpoint, SentinelOne), düşük yetkili bir süreçten (özellikle `Office`, `wscript.exe`, `sqlservr.exe` veya web shell altından) `nltest /domain_trusts` veya `nltest /dclist` çalıştırılmasını **Domain Trust Discovery (T1482)** davranışı olarak tespit eder ve alarm üretir.
- **Ağ Gürültüsü:** Ağ trafiğinde `MS-NRPC` RPC çağrıları ve DNS SRV sorguları yer alır; port taramasına kıyasla son derece sessizdir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1082** | System Information Discovery | Yerel sistemin dahil olduğu domain ve site bilgilerini öğrenme (`/dsgetsite`). |
| **T1018** | Remote System Discovery | Etki alanındaki tüm Domain Controller'ları tespit etme (`/dclist`). |
| **T1482** | Domain Trust Discovery | Forest, tree ve external güven ilişkilerini haritalama (`/domain_trusts /all_trusts /v`). |
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesap durumu, grup RID'leri ve kilitlenme bilgilerini Netlogon ile sorgulama (`/user`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **CLI Komut Satırı Tespiti (Process Auditing)** | `nltest.exe` çağırmak yerine doğrudan Win32 API çağrıları yapan .NET assembly'leri veya hafıza içi araçlar (in-memory execution) kullanın. Örneğin: `[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().GetAllTrustRelationships()`. |
| **Parent Process Anomalisini Önleme** | `nltest.exe` komutunu doğrudan `cmd.exe` içinden değil, explorer veya meşru bir yönetim süreci altından çalıştırmayı deneyin (Process Parent Spoofing). |
| **Gereksiz Flag Kullanımından Kaçınma** | `/all_trusts /v` gibi çok bilinen EDR kural imzaları yerine sadece hedef domain için tekil `/dsgetdc` veya doğrudan LDAP araması yapın. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Gelişmiş Süreç Denetimi (Process Creation Auditing):** GPO üzerinden `Audit Process Creation` ve `Include command line in process creation events` politikalarını açarak Event ID 4688 kayıtlarında argümanları toplayın.
- **Sigma / SIEM Tespit Kuralı Mantığı:**
  ```yaml
  title: Active Directory Reconnaissance via NLTEST
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\nltest.exe'
          CommandLine|contains:
              - '/domain_trusts'
              - '/all_trusts'
              - '/dclist'
              - '/dsgetdc'
      condition: selection
  ```
- **RPC Filtreleme ve Sertleştirme:** Windows Güvenlik Duvarı üzerinden istemcilerin DC'ye MSRPC erişimlerini yalnızca gerekli yönetim subnetleri ile sınırlandırın.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Geçerli Domain Controller ve PDC Tespiti
```cmd
nltest /dsgetdc:lab.local
```
- **Ne Yapar?** İstemcinin bağlı olduğu en uygun DC'yi, PDC Emulator'ı, GC durumunu ve IP adresini döndürür.
- **Ne Zaman Kullanılır?** İlk erişim anında etki alanının merkez sunucusunu ve IP bloğunu öğrenmek için.
- **Parametreler:** `/dsgetdc:<DomainName>` (Hedef etki alanının FQDN adı).

### 6.2 Etki Alanındaki Tüm Domain Controller Listesini Alma
```cmd
nltest /dclist:lab.local
```
- **Ne Yapar?** Belirtilen etki alanına hizmet veren tüm DC'lerin NetBIOS ve FQDN isimlerini listeler.
- **Ne Zaman Kullanılır?** Hangi sunucuların replikasyon veya kimlik doğrulama noktası olduğunu haritalamak için.
- **Parametreler:** `/dclist:<DomainName>` (Listelenecek etki alanı adı).

### 6.3 Çift Yönlü / Tek Yönlü Tüm Trust İlişkilerini Detaylı Haritalama
```cmd
nltest /domain_trusts /all_trusts /v
```
- **Ne Yapar?** Ormandaki tüm etki alanlarını, güven yönlerini (Inbound/Outbound) ve güvenlik SID'lerini gösterir.
- **Ne Zaman Kullanılır?** Bir etki alanından diğerine yanal hareket (Cross-Forest Lateral Movement) planlarken.
- **Parametreler:** `/domain_trusts` (Güvenleri listeler), `/all_trusts` (Transitif tüm güvenleri dahil eder), `/v` (Ayrıntılı çıktı üretir).

### 6.4 Bilgisayarın DC ile Güvenli Kanalını (Secure Channel) Doğrulama
```cmd
nltest /sc_verify:lab.local
```
- **Ne Yapar?** İstemci makinenin DC ile paylaştığı makine hesabı parolasını canlı RPC oturumuyla test eder.
- **Ne Zaman Kullanılır?** Makine hesabı üzerinden kimlik doğrulaması yapılıp yapılamayacağını anlamak için.
- **Parametreler:** `/sc_verify:<DomainName>` (Hedef etki alanı).

### 6.5 Belirli Bir Kullanıcının Hesap Durumunu Netlogon Üzerinden Sorgulama
```cmd
nltest /user:Administrator
```
- **Ne Yapar?** Kullanıcının RID değerini, grup üyeliklerini ve hatalı parola sayacını (`Bad Password Count`) listeler.
- **Ne Zaman Kullanılır?** LDAP engellendiğinde kullanıcı hakkında bilgi toplamak veya parola püskürtme öncesi kilitlenme eşiğini izlemek için.
- **Parametreler:** `/user:<UserName>` (Hedef kullanıcı adı).

### 6.6 İstemcinin Bulunduğu Active Directory Site Bilgisini Alma
```cmd
nltest /dsgetsite
```
- **Ne Yapar?** İstemcinin IP adresine göre Active Directory Sites and Services konsolunda tanımlı olan Site adını verir.
- **Ne Zaman Kullanılır?** Saldırganın ağ içindeki fiziksel veya mantıksal lokasyonunu (Merkez, Şube, DMZ) belirlemek için.
- **Parametreler:** Ek parametre gerektirmez.

### 6.7 Kullanıcının Oturumunu Hangi DC'nin Doğrulayacağını Test Etme
```cmd
nltest /whowill:lab.local jdoe
```
- **Ne Yapar?** Belirtilen kullanıcının oturum açma isteğinin ağdaki hangi DC tarafından karşılanacağını simüle eder.
- **Ne Zaman Kullanılır?** NTLM Relay veya Kerberoasting hedeflerinin hangi DC trafiğinde yakalanabileceğini belirlemek için.
- **Parametreler:** `/whowill:<DomainName> <UserName>` (Etki alanı adı ve kullanıcı adı).

### 6.8 Forest Trust Bilgilerini ve SID Filtreleme Durumunu İnceleme
```cmd
nltest /dsgetfti:target.corp
```
- **Ne Yapar?** Orman güveni özniteliklerini, Name Suffix yönlendirmelerini ve SID filtreleme durumunu listeler.
- **Ne Zaman Kullanılır?** Golden Ticket ile SID History injection saldırısı öncesinde SID filtrelemenin etkin olup olmadığını kontrol etmek için.
- **Parametreler:** `/dsgetfti:<DomainName>` (Hedef orman etki alanı).

### 6.9 Uzak Bir Sunucu Üzerinde Netlogon Durumunu Sorgulama
```cmd
nltest /server:SRV01.lab.local /query
```
- **Ne Yapar?** Belirtilen uzak sunucunun Netlogon hizmetinin hangi DC ile güvenli kanal kurduğunu uzaktan sorgular.
- **Ne Zaman Kullanılır?** Yanal hareket öncesinde kritik bir sunucunun (örneğin SQL veya Web sunucusu) etki alanı iletişim hattını keşfetmek için.
- **Parametreler:** `/server:<ServerName>` (Uzak sunucu adı/IP), `/query` (Netlogon durum sorgusu).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — nltest Dokümantasyonu | [learn.microsoft.com](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc731935(v=ws.11)) |
| MS-NRPC: Netlogon Remote Protocol | [learn.microsoft.com](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-nrpc/) |
| MITRE ATT&CK T1482 (Domain Trust Discovery) | [attack.mitre.org](https://attack.mitre.org/techniques/T1482/) |
| LOLBAS Project (Living Off The Land Binaries) | [lolbas-project.github.io](https://lolbas-project.github.io/) |

---

> **Önceki:** [← Kategori 01 — Temel İstemciler](../Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/README.md) · **Sonraki:** [net.exe →](./net.md)
