# SharpHound

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** BloodHound için resmi C# (.NET) veri toplayıcısı; LDAP, SMB, RPC, Session ve AD CS verilerini çok iş parçacıklı olarak toplayıp analiz arşivine (`.zip`) dönüştürme.

---

## 1. Genel Bakış ve Amaç

`SharpHound`, SpecterOps tarafından geliştirilen ve Active Directory ortamlarındaki güvenlik ilişkilerini, izinleri ve saldırı yollarını haritalamak amacıyla kullanılan resmi **BloodHound veri toplayıcısıdır (Ingestor)**. C# (.NET Framework 4.7.2+ ve .NET Core / .NET 8) ile geliştirilmiş olan araç; kullanıcıları, bilgisayarları, güvenlik gruplarını, etki alanı güven ilişkilerini (trusts), yerel yönetici gruplarını (LocalAdmin), aktif kullanıcı oturumlarını (Sessions), erişim denetim listelerini (ACL/ACE) ve Active Directory Sertifika Hizmetleri (AD CS) yapılandırmalarını toplar.

Bir sızma testinde veya Red Team operasyonunda `SharpHound`, operatörün hedef ağdaki karmaşık hiyerarşiyi, gizli yetki devirlerini ve etki alanı yöneticiliğine giden yolları açığa çıkarmak için kullandığı en temel veri toplama motorudur. Toplanan tüm veriler sıkıştırılmış bir `.zip` arşivi (içerisinde `users.json`, `computers.json`, `groups.json`, `domains.json`, `ous.json`, `gpos.json`, `containers.json`, `certtemplates.json`) olarak dışa aktarılır ve doğrudan **BloodHound CE (v5+)** veya Legacy BloodHound arayüzüne yüklenir.

### SharpHound v1.x (Legacy) vs SharpHound v2.x (BloodHound CE)

| Özellik / Kriter | SharpHound v1.x (Legacy) | SharpHound v2.x (BloodHound CE) |
|---|---|---|
| **Hedef Platform** | BloodHound v4.x (Electron GUI) | BloodHound CE (v5+ Docker/Web) |
| **JSON Şeması** | Schema v4 | Schema v5 (Genişletilmiş öznitelikler) |
| **AD CS Desteği** | Kısıtlı / Eklenti gerekir | Yerleşik ve Tam (Certificates metodu) |
| **Büyük Veri Yönetimi** | Bellek taşması yapabilir | Akış (streaming) bazlı JSON yazımı |
| **Şifreli Çıktı** | Kısıtlı | `--encryptzip` ve `--password` desteği |
| **Çalışma Çatısı** | .NET Framework 4.5 / 4.7 | .NET Framework 4.7.2+ & .NET 8 bağımsız |

### Protokol ve Çalışma Prensibi

`SharpHound`, toplama metoduna göre iki temel ağ iletişim hattını kullanır:

```
┌──────────────────────────────────────────────────────────────┐
│                    Saldırgan İş İstasyonu                    │
│                      [ SharpHound.exe ]                      │
└───────────────────┬───────────────────────────────┬──────────┘
                    │                               │
    (A) Dizin Keşfi │                               │ (B) Oturum & Admin Avı
    LDAP / LDAPS    │                               │ SMB / MSRPC (TCP 445 / 135)
    TCP 389 / 636   │                               │ NetSessionEnum / Samr
                    ▼                               ▼
┌──────────────────────────────────────┐   ┌───────────────────────────┐
│        Domain Controller (DC)        │   │  Tüm Ağdaki Bilgisayarlar │
│     [ Active Directory NTDS.DIT ]    │   │  (İş İstasyonları/Server) │
│                                      │   │                           │
│ - Kullanıcılar, Gruplar, OU'lar      │   │ - Local Admins Grubu      │
│ - ACL ve İzinler (nTSecurityDesc)    │   │ - Aktif Oturumlar (Session│
│ - AD CS Şablonları ve CA Kayıtları   │   │ - Kayıtlı Servisler / RDP │
└──────────────────────────────────────┘   └───────────────────────────┘
```

### Toplama Metotları ve Protokol Eşleştirmesi

| Metot Adı | Hedef Sistemler | Kullandığı Protokoller | Çağrılan Windows API / Mekanizma |
|---|---|---|---|
| `DCOnly` | Yalnızca Domain Controller | LDAP / LDAPS (TCP 389/636) | `System.DirectoryServices.Protocols` (Sorgu ve nTSecurityDescriptor) |
| `Group` | Domain Controller | LDAP (TCP 389/636) | Dizin grup üyelikleri ve iç içe (nested) hiyerarşi |
| `LocalAdmin` | Tüm Ağdaki Bilgisayarlar | SMB (TCP 445) / SAMR (TCP 135) | `NetLocalGroupGetMembers`, `SamrOpenAlias` |
| `Session` | Tüm Ağdaki Bilgisayarlar | SMB (TCP 445 / Named Pipe) | `NetSessionEnum` (srvsvc named pipe üzerinden) |
| `LoggedOn` | Tüm Ağdaki Bilgisayarlar | SMB / Remote Registry / RPC | `NetWkstaUserEnum`, HKEY_USERS kayıt defteri taraması |
| `Trusts` | Domain Controller | LDAP / Kerberos | Etki alanı güven ilişkileri (`trustedDomain` nesneleri) |
| `Certificates` | Domain Controller | LDAP (TCP 389/636) | `CN=Public Key Services,CN=Services,CN=Configuration` |
| `RDP` / `DCOM` | Tüm Ağdaki Bilgisayarlar | SMB / SAMR | `Remote Desktop Users` ve `Distributed COM Users` grupları |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
SharpHound.exe -c <Metotlar> [seçenekler]
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Varsayılan | Örnek Kullanım |
|---|---|---|---|
| `-c, --collectionmethods <Metot>` | Toplama metodunu belirler (Virgülle çoklu seçim yapılabilir). | `Default` | `-c DCOnly` veya `-c All,Certificates` |
| `-d, --domain <Domain>` | Hedef etki alanının FQDN adını belirler. | Bulunulan Domain | `-d sirket.local` |
| `--domaincontroller <DC_IP>` | LDAP sorgularının gönderileceği spesifik DC IP'si veya adı. | Otomatik | `--domaincontroller 192.168.1.10` |
| `--distinguishedname <DN>` | Yalnızca belirtilen OU altındaki nesneleri tarar (Hedefli tarama). | Tüm Etki Alanı | `--distinguishedname "OU=Finans,DC=lab,DC=local"` |
| `--ldapfilter <Filtre>` | Dizin sorgulamalarında kullanılacak özel LDAP arama filtresi. | Boş | `--ldapfilter "(adminCount=1)"` |
| `--searchforest` | Bulunulan etki alanının bağlı olduğu tüm ormandaki (forest) domain'leri tarar. | Kapalı | `--searchforest` |
| `--stealth` | Tarama hızını düşürür, iş parçacıklarını sınırlar ve yalnızca güvenli portları dener. | Kapalı | `--stealth` |
| `--exclude-dcs` | Domain Controller sunucularına oturum veya yerel yönetici sorgusu atmaz (OPSEC). | Kapalı | `--exclude-dcs` |
| `--throttle <Milisaniye>` | Her ağ isteği arasına milisaniye cinsinden bekleme süresi koyar. | 0 | `--throttle 1500` |
| `--jitter <Yüzde>` | Gecikme sürelerine rastgelelik katar (örn: %20 jitter). | 0 | `--jitter 25` |
| `--threads <Sayı>` | Eşzamanlı çalışacak iş parçacığı sayısı. | 50 | `--threads 10` |
| `--portchecktimeout <Ms>` | Bilgisayarların port kontrolü için zaman aşımı süresi. | 500 ms | `--portchecktimeout 1000` |
| `--skipportcheck` | Port kontrolünü atlar, doğrudan tüm bilgisayarlara SMB/RPC açmayı dener. | Kapalı | `--skipportcheck` |
| `--loop` | Oturum toplamayı sürekli bir döngüde çalıştırır (User Hunting). | Kapalı | `--loop` |
| `--loopduration <Süre>` | Döngünün ne kadar süre çalışacağını belirler (SS:DD:SN). | Süresiz | `--loopduration 02:00:00` |
| `--loopinterval <Süre>` | Döngü tekrarları arasındaki bekleme süresi. | Boş | `--loopinterval 00:05:00` |
| `--secureldap` | Standart port 389 yerine LDAPS (TCP 636) şifreli bağlantısını zorlar. | Kapalı | `--secureldap` |
| `-z, --zipfilename <İsim>` | Oluşturulacak ZIP arşivinin özel dosya adını belirler. | Otomatik | `-z CorpRecon.zip` |
| `--outputdirectory <Dizin>` | ZIP dosyasının ve geçici JSON'ların yazılacağı hedef klasör yolu. | Çalışılan Dizin | `--outputdirectory C:\Windows\Temp` |
| `--nozip` | JSON dosyalarını ZIP içine sıkıştırmadan doğrudan klasörde bırakır. | Kapalı | `--nozip` |
| `--encryptzip` | ZIP dosyasını AES şifreleme ile korur. | Kapalı | `--encryptzip` |
| `--password <Parola>` | Şifrelenecek ZIP dosyasının parolası. | Boş | `--password GucluSifre2026!` |

### Çıktı Dosyaları ve JSON Şema Mimarisi

Toplama tamamlandığında üretilen ZIP arşivi içinde aşağıdaki JSON dosyaları bulunur:

```
[SharpHound_Output.zip]
├── users.json           -> Kullanıcılar, SPN'ler, dontreqpreauth, adminCount, pwdlastset
├── computers.json       -> Bilgisayarlar, OS sürümleri, unconstraineddelegation, allowedtoact
├── groups.json          -> Güvenlik grupları ve doğrudan/dolaylı grup üyeleri (MemberOf)
├── domains.json         -> Etki alanı kök nesnesi ve nesne izinleri (DCSync hakları)
├── ous.json             -> Organizasyonel birimler ve hiyerarşik yapı
├── gpos.json            -> Grup İlkeleri ve bağlandıkları OU'lar (GPLink)
├── containers.json      -> Özel Active Directory kapsayıcıları
└── certtemplates.json   -> AD CS sertifika şablonları, EKU ayarları ve kayıt izinleri
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart ve Kapsamlı Veri Toplama (Tüm Etki Alanı)

Saldırgan tespit edilme kaygısı olmayan bir sızma testinde tüm ilişkileri eksiksiz çıkarmak ister:

```cmd
SharpHound.exe -c All --zipfilename FullRecon.zip --outputdirectory C:\Windows\Temp
```

**Konsol Çıktısı Analizi:**
```text
2026-10-14T14:30:00 [INFO] Resolved Domain: lab.local
2026-10-14T14:30:01 [INFO] Flags: All
2026-10-14T14:30:02 [INFO] Beginning LDAP search for lab.local
2026-10-14T14:30:15 [INFO] Completed LDAP search in 13.2s
2026-10-14T14:30:16 [INFO] Found 1,240 computers in lab.local
2026-10-14T14:30:17 [INFO] Starting computer collection with 50 threads
2026-10-14T14:31:45 [INFO] Completed computer collection in 1m28s
2026-10-14T14:31:46 [INFO] Compressing output files to C:\Windows\Temp\FullRecon.zip
2026-10-14T14:31:50 [INFO] SharpHound Enumeration Completed at 14:31:50!
```
- `Found 1,240 computers`: Ağdaki tüm bilgisayarlar taranmıştır.
- Çıktı `C:\Windows\Temp\FullRecon.zip` dosyası BloodHound CE'ye aktarılmaya hazırdır.

---

### Senaryo 2: OPSEC Dostu Sessiz Keşif (DCOnly Modu)

**En kritik operasyonel senaryodur.** Ağdaki iş istasyonlarına yüzlerce SMB bağlantısı atıp IDS/IPS ve EDR port taraması alarmlarını tetiklemek yerine, yalnızca etki alanı denetleyicisi ile güvenli LDAPS üzerinden konuşulur:

```cmd
SharpHound.exe -c DCOnly --secureldap -z DCOnly_Audit.zip
```
- Bu komut ağdaki hiçbir iş istasyonuna ping veya SMB bağlantısı göndermez.
- Yalnızca DC'den kullanıcılar, gruplar, GPO'lar, ACL'ler ve delegasyon hakları çekilir.
- Ağ izleme sistemleri açısından standart bir kurumsal LDAP sorgusundan farksızdır.

---

### Senaryo 3: Oturum Avı ve LocalAdmin Analizi (Domain Controller'ları Hariç Tutarak)

Hangi bilgisayarda hangi etki alanı yöneticisinin oturumu olduğunu keşfetmek ancak Domain Controller'larda güvenlik alarmı üretmemek için:

```cmd
SharpHound.exe -c Session,LocalAdmin --exclude-dcs -z Sessions_NoDC.zip
```
- `--exclude-dcs`: DC'lere `NetSessionEnum` sorgusu gitmesini engeller; böylece Microsoft Defender for Identity (MDI) alarmları atlatılır.

---

### Senaryo 4: AD CS Sertifika Zafiyetleri Taraması (ESC Analizi)

Active Directory Certificate Services ortamındaki hatalı şablon izinlerini grafikleştirmek:

```cmd
SharpHound.exe -c Certificates,DCOnly -z ADCS_Recon.zip
```
- `Certificates` metodu, CA sunucularını, sertifika şablonlarını ve kayıt izinlerini toplar.

---

### Senaryo 5: Ağ Gürültüsünü Azaltarak Düşük Hızlı ve Jitter'lı Tarama (Stealth)

Ağ sensörlerini ve anormal trafik eşiklerini atlatmak için istekler arasına yapay gecikme eklemek:

```cmd
SharpHound.exe -c Default --throttle 1500 --jitter 30 --threads 5 -z SlowRecon.zip
```
- `--threads 5`: Eşzamanlı bağlantı sayısı 50'den 5'e indirilir.
- `--throttle 1500 --jitter 30`: Her istek arasına 1000-2000 ms arasında rastgele gecikmeler serpiştirilir.

---

### Senaryo 6: Sürekli Oturum İzleme Döngüsü (Looping Session Collection)

Domain Admin'ler gün içerisinde farklı sunucularda kısa süreli oturum açıp kapatabilir. SharpHound'u 2 saat boyunca her 5 dakikada bir oturumları tarayacak şekilde arka planda çalıştırma:

```cmd
SharpHound.exe -c Session --loop --loopduration 02:00:00 --loopinterval 00:05:00 --exclude-dcs -z LoopSessions.zip
```
- Operatör 2 saat boyunca ağa giren yeni DA oturumlarını otomatik yakalar.

---

### Senaryo 7: Belirli Bir OU Altını Hedefleyerek Taramayı Sınırlandırma

Tüm şirketi taramak yerine yalnızca hassas finans veya yönetim birimini haritalamak:

```cmd
SharpHound.exe -c DCOnly --distinguishedname "OU=Executive,OU=Corporate,DC=lab,DC=local" -z ExecOU.zip
```
- Yalnızca ilgili OU altındaki nesneler ve izinler çekilir; zaman ve log üretimi minimuma iner.

---

### Senaryo 8: Cobalt Strike Beacon Üzerinden Bellek İçi Çalıştırma ve Şifreli ZIP

Diske şifresiz dosya bırakmamak için çıktıyı AES ile şifreleyerek RAM'de yürütme:

```text
beacon> execute-assembly C:\Tools\SharpHound.exe -c DCOnly --secureldap --encryptzip --password "GizliSifre2026!" -z C:\Windows\Temp\perf_diag.zip
```
- İkili dosya RAM'de yürütülür; üretilen ZIP dosyası şifreli olduğundan SOC ekipleri içeriğini analiz edemez.

---

### Senaryo 9: Kerberos Pass-the-Ticket (PtT) ile Kimliksiz Çalıştırma

Oturumda mevcut bir Kerberos bileti (TGT) varsa, ek bir parola veya kullanıcı adı vermeden mevcut güvenlik bağlamı üzerinden tarama:

```cmd
SharpHound.exe -c DCOnly --secureldap -z PtT_Recon.zip
```
*Analiz:* SharpHound Windows SSPI kütüphanelerini kullanarak doğrudan geçerli Windows oturumunun Kerberos biletini kullanır.

---

### Senaryo 10: Port Taraması Sürelerini Optimize Etme (Zayıf Ağlar İçin)

Ağ gecikmesi yüksek olan WAN veya VPN bağlantılarında port zaman aşımını artırarak sahte çevrimdışı sonuçları engelleme:

```cmd
SharpHound.exe -c Session,LocalAdmin --portchecktimeout 1500 --threads 15 -z WAN_Recon.zip
```
- `--portchecktimeout 1500`: Yanıt vermeyen sunucular için bekleme süresi 1.5 saniyeye çıkarılır.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `Status: 0xc0000022 / Access is denied on NetSessionEnum` | Hedef Windows 10/11 iş istasyonunda `NetSessionEnum` varsayılan olarak sıradan kullanıcılara kapatılmıştır (`NetSessionEnum default permissions / NetCease`). | Bu beklenen bir davranıştır. Oturum toplamak için yerel yönetici ayrıcalığı gerekir veya yalnızca sunucu işletim sistemleri hedeflenmelidir (`--exclude-dcs` ve sunucu OU'ları). |
| `SharpHound timeout on LDAP connection / 0x8007203a` | Belirtilen etki alanı denetleyicisi ile iletişim kopmuştur veya LDAP portu (TCP 389/636) engellenmiştir. | DNS IP yapılandırmasını kontrol edin; `--domaincontroller` parametresiyle açıkça erişilebilir bir DC IP'si veya FQDN'i belirtin. |
| `High CPU usage / System freezing during computer collection` | Varsayılan 50 iş parçacığı (`threads`) düşük donanımlı sanal makinelerde veya zayıf ağlarda tıkanıklığa yol açmıştır. | İş parçacığı sayısını düşürün: `--threads 10` veya `--threads 5`. |
| `The type initializer for 'SharpHound...LDAPUtils' threw an exception` | Hedef makinedeki .NET Framework sürümü (4.5 öncesi) yetersizdir veya gerekli DLL bileşenleri eksiktir. | .NET 4.7.2+ kurulu olduğundan emin olun veya .NET Core tabanlı bağımsız derlemeyi (Self-contained binary) kullanın. |
| `ZIP file is empty or 0 KB` | Toplama sırasında hiçbir nesne bulunamamıştır veya yazma izni olmayan bir dizine çıktı verilmeye çalışılmıştır. | `--outputdirectory C:\Windows\Temp` veya `%TEMP%` gibi yazılabilir bir dizin belirtin. |
| `SharpHound kilitleniyor / OutOfMemoryException` | Çok büyük bir AD ormanında tüm nesne öznitelikleri RAM'de biriktirilmiştir. | Taramayı OU bazlı bölün (`--distinguishedname`) veya `--collectionmethods DCOnly` kullanın. |
| `RPC Server Unavailable (RPC 1722)` | Hedef makinenin Windows Güvenlik Duvarı RPC/SMB portlarını bloklamaktadır. | Bu sistemler çevrimdışı veya filtrelenmiş kabul edilir; `--skipportcheck` parametresini kaldırarak tarama süresini hızlandırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `SharpHound.exe` çalıştırılması, komut satırı argümanları (`-c All`, `--collectionmethods`) kaydedilir.
  - **Sysmon Event ID 11 (File Create):** Diske yazılan `*_BloodHound.zip` ve geçici `*.json` dosyaları loglanır.
  - **Sysmon Event ID 3 (Network Connection - EN BÜYÜK IOC):** `SharpHound.exe`'nin ağdaki yüzlerce IP adresine aynı anda TCP 445 ve TCP 135 portlarından bağlantı açtığı kaydedilir (**Port Sweep / Network Scanning göstergesi**).
- **Etki Alanı Denetleyicisi Günlükleri (DC Logs):**
  - **Directory Service Event ID 1644:** Tek bir istemciden gelen on binlerce nesnelik rekürsif LDAP sorgu fırtınası.
  - **Security Event ID 4662:** Nesneler üzerindeki güvenlik tanımlayıcıları (`nTSecurityDescriptor`) tek tek okunduğunda oluşan denetim kayıtları.

### 5.2 Ağ ve EDR İmzaları

- **İç Ağ Port Taraması Anomalisi (Internal Port Sweep):** Varsayılan `SharpHound -c All` veya `Default` komutu, ağdaki yüzlerce/binlerce makineye eşzamanlı olarak SMB port taraması yapar. Bu davranış, istisnasız tüm modern NDR, EDR ve IDS/IPS sistemleri (Darktrace, CrowdStrike, Suricata) tarafından saniyeler içinde **Internal Reconnaissance / Port Scan** olarak tespit edilir.
- **Microsoft Defender for Identity (MDI) Tespiti:** MDI sensörleri, `NetSessionEnum` sorgularını ve toplu LDAP taramalarını korele ederek doğrudan **Reconnaissance using SMB (Session Enumeration)** alarmı üretir.
- **İkili Dosya İmzası:** Standart derlenmiş `SharpHound.exe` dosyası ve string'leri antivirüsler tarafından bilinen statik imza ile anında karantinaya alınır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesapları ve izinlerini toplama (`DCOnly`). |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup üyeliklerini ve iç içe geçmiş hiyerarşiyi haritalama. |
| **T1018** | Remote System Discovery | Ağdaki tüm bilgisayar ve sunucuları tespit etme. |
| **T1033** | System Owner/User Discovery | Hangi kullanıcının hangi bilgisayarda oturumu olduğunu bulma (`Session`). |
| **T1482** | Domain Trust Discovery | Forest ve Domain güven ilişkilerini haritalama. |
| **T1649** | Steal or Forge Authentication Certificates | AD CS sertifika şablonu ve CA yapılandırmasını toplama. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Ağ Taraması Alarmı (Port Sweep)** | Asla kontrolsüzce `-c All` çalıştırmayın! İlk aşamada kesinlikle `-c DCOnly --secureldap` kullanın; böylece hiçbir iş istasyonuna paket gitmez. |
| **MDI Oturum Taraması Uyarısı** | Oturum toplamak zorundaysanız mutlaka `--exclude-dcs` parametresini ekleyin; DC'lere oturum sorgusu gitmesini engelleyin. |
| **Statik Dosya İmzası** | `SharpHound.exe`'yi diske bırakmayın; Cobalt Strike `execute-assembly` veya bellek içi PowerShell ile çalıştırın. Kendi SharpHound derlemenizi kaynak koddan (obfuscated) derleyin. |
| **ZIP Dosya Adı İmzası** | Varsayılan `*_BloodHound.zip` adını `-z` parametresiyle masum bir dosya adıyla değiştirin (`-z C:\Temp\win_diag_report.zip`). |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (KQL — Microsoft Sentinel / Defender for Identity)
```kql
// Çok Sayıda Makineye SMB Session Enumeration Tespiti (SharpHound Session)
DeviceNetworkEvents
| where ActionType == "ConnectionSuccess"
| where RemotePort in (445, 139)
| where InitiatingProcessFileName !in~ ("System", "svchost.exe", "explorer.exe")
| summarize DestinationCount = dcount(RemoteIP), DestinationIPs = make_set(RemoteIP) by InitiatingProcessFileName, bin(Timestamp, 5m)
| where DestinationCount > 30
| order by DestinationCount desc
```

#### Tespit Kuralı (Sigma — SharpHound Komut Satırı Tespiti)
```yaml
title: SharpHound Ingestor Execution
status: high
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        CommandLine|contains|any:
            - 'CollectionMethods'
            - 'DCOnly'
            - 'ExcludeDCs'
            - 'Stealth'
            - 'searchforest'
            - 'loopduration'
    condition: selection
level: high
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. En güvenli ve sessiz keşif taraması (DCOnly)
SharpHound.exe -c DCOnly --secureldap -z DCOnly_Report.zip
```
- **Ne Yapar?:** Yalnızca etki alanı denetleyicisi ile şifreli LDAPS (TCP 636) üzerinden konuşur; iş istasyonlarına hiç dokunmadan kullanıcı, grup, OU, GPO ve ACL verilerini toplar.
- **Ne Zaman Kullanılır?:** EDR ve ağ IDS/IPS alarmlarını tetiklemeden en güvenli ve sessiz BloodHound verisini toplamak için.
- **Parametreler:** `-c DCOnly`, `--secureldap`, `-z <Ad>`.

```cmd
# 2. Tam kapsamlı toplama (Tüm izinler ve oturumlar)
SharpHound.exe -c All --zipfilename FullRecon.zip
```
- **Ne Yapar?:** LDAP, SMB, Session, LocalAdmin, RDP, DCOM ve AD CS dahil tüm ilişkileri eksiksiz toplar.
- **Ne Zaman Kullanılır?:** Sızma testlerinde gürültü kısıtı olmadığında ve tüm saldırı yollarının tam dökümü istendiğinde.
- **Parametreler:** `-c All`.

```cmd
# 3. Yalnızca AD CS sertifika zafiyetlerini toplama
SharpHound.exe -c Certificates,DCOnly -z ADCS_Scan.zip
```
- **Ne Yapar?:** Etki alanındaki Sertifika Yetkililerini (CA), sertifika şablonlarını ve kayıt izinlerini toplar.
- **Ne Zaman Kullanılır?:** ESC1-ESC13 sertifika yetki yükseltme yollarını analiz etmek için.
- **Parametreler:** `-c Certificates,DCOnly`.

```cmd
# 4. DC'leri hariç tutup yalnızca oturum verisi toplama
SharpHound.exe -c Session,LocalAdmin --exclude-dcs -z Sessions.zip
```
- **Ne Yapar?:** Domain Controller'ları hariç tutarak ağdaki bilgisayarlara bağlanır ve oturum/yerel yönetici bilgilerini toplar.
- **Ne Zaman Kullanılır?:** DC üzerinde MDI alarmları üretmeden kullanıcı avı (User Hunting) yapmak için.
- **Parametreler:** `--exclude-dcs`.

```cmd
# 5. Ağ gürültüsünü azaltarak düşük hızlı tarama (Stealth Mod)
SharpHound.exe -c Default --throttle 1000 --jitter 25 --threads 5 -z SlowRecon.zip
```
- **Ne Yapar?:** İstekleri 5 iş parçacığına sınırlar ve her istek arasına 1000 ms (+/- %25 jitter) gecikme koyar.
- **Ne Zaman Kullanılır?:** Ağ anomali tespit sistemlerini (NDR) ve eşik bazlı alarmları atlatmak için.
- **Parametreler:** `--throttle 1000`, `--jitter 25`, `--threads 5`.

```cmd
# 6. Belirli bir OU altındaki nesneleri hedefleme
SharpHound.exe -c DCOnly --distinguishedname "OU=Sunucular,DC=sirket,DC=local" -z ServerOU.zip
```
- **Ne Yapar?:** Tüm etki alanı yerine yalnızca belirtilen OU yolundaki nesneleri çeker.
- **Ne Zaman Kullanılır?:** Hedef odaklı ve minimum gürültülü analizler için.
- **Parametreler:** `--distinguishedname`.

```cmd
# 7. Sürekli oturum izleme döngüsü (Looping Session)
SharpHound.exe -c Session --loop --loopduration 01:00:00 --loopinterval 00:05:00 --exclude-dcs -z Loop.zip
```
- **Ne Yapar?:** 1 saat boyunca her 5 dakikada bir oturumları tarayarak ağa giren yöneticileri izler.
- **Ne Zaman Kullanılır?:** Hedef kullanıcının sisteme oturum açmasını beklerken.
- **Parametreler:** `--loop`, `--loopduration`, `--loopinterval`.

```cmd
# 8. Özel LDAP filtresi ile hassas hesapları tarama
SharpHound.exe -c DCOnly --ldapfilter "(adminCount=1)" -z ProtectedUsers.zip
```
- **Ne Yapar?:** Yalnızca `adminCount=1` olan korumalı ayrıcalıklı hesapları toplar.
- **Ne Zaman Kullanılır?:** Ayrıcalıklı hesapları hızlıca izole edip incelemek için.
- **Parametreler:** `--ldapfilter`.

```cmd
# 9. Şifreli ZIP arşivi oluşturma (Antivirüs atlatma)
SharpHound.exe -c DCOnly --encryptzip --password "KriptoPass123!" -z EncryptedBH.zip
```
- **Ne Yapar?:** Çıktı arşivini AES ile şifreleyerek AV/EDR dosya denetimlerini atlatır.
- **Ne Zaman Kullanılır?:** Dosya denetiminin sıkı olduğu uç noktalarda.
- **Parametreler:** `--encryptzip`, `--password`.

```cmd
# 10. Orman çapında tüm güven ilişkilerini tarama
SharpHound.exe -c DCOnly,Trusts --searchforest -z ForestRecon.zip
```
- **Ne Yapar?:** Ormandaki tüm etki alanlarını ve güven ilişkilerini toplar.
- **Ne Zaman Kullanılır?:** Çok alanlı kurumsal yapılarda orman çapında analiz için.
- **Parametreler:** `--searchforest`.

```cmd
# 11. Belirli bir Domain Controller'a yönlendirme (--domaincontroller)
SharpHound.exe -c DCOnly --domaincontroller 192.168.1.10 -z TargetedDC.zip
```
- **Ne Yapar?:** Dizin sorgulamalarını doğrudan belirtilen IP adresindeki DC'ye yönlendirir.
- **Ne Zaman Kullanılır?:** DNS çözümlemesi çalışmadığında veya izole bir DC incelenirken.
- **Parametreler:** `--domaincontroller`.

```cmd
# 12. Sıkıştırmasız JSON dökümü alma (--nozip)
SharpHound.exe -c DCOnly --nozip --outputdirectory C:\ReconData
```
- **Ne Yapar?:** ZIP oluşturmadan ham JSON dosyalarını doğrudan diske döker.
- **Ne Zaman Kullanılır?:** JSON dosyalarını scriptlerle anında ayrıştırmak gerektiğinde.
- **Parametreler:** `--nozip`, `--outputdirectory`.

---

## Kaynaklar

- **SharpHound Resmi GitHub Reposu:** [https://github.com/SpecterOps/SharpHound](https://github.com/SpecterOps/SharpHound)
- **BloodHound CE Toplama Kılavuzu:** [https://support.bloodhoundenterprise.io/hc/en-us/articles/17278278273691-SharpHound-Community-Edition](https://support.bloodhoundenterprise.io/hc/en-us/articles/17278278273691-SharpHound-Community-Edition)
- **MITRE ATT&CK T1087.002:** [https://attack.mitre.org/techniques/T1087/002/](https://attack.mitre.org/techniques/T1087/002/)
- **SpecterOps — SharpHound Detection Analysis:** [https://posts.specterops.io/](https://posts.specterops.io/)

---

> **Önceki:** [← BloodHound CE](./BloodHound_CE.md) · **Sonraki:** [BloodHound.py →](./BloodHound.md)
