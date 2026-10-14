# ldapsearch

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** OpenLDAP CLI istemcisi; basit ve Kerberos GSSAPI bind ile ham LDAP sorguları, gelişmiş eşleme kuralları (OID), filtreleme ve sayfalama.

---

## 1. Genel Bakış ve Amaç

`ldapsearch`, OpenLDAP projesinin resmi komut satırı istemcisidir ve Active Directory (AD) ortamlarında dizin veritabanını doğrudan sorgulamak için kullanılan en temel, esnek ve güçlü araçtır. Active Directory'nin omurgasını oluşturan **LDAP (Lightweight Directory Access Protocol)** protokolü üzerinden Etki Alanı Denetleyicileri (DC) ile haberleşerek kullanıcılar, bilgisayarlar, güvenlik grupları, GPO'lar, sertifika şablonları, güven ilişkileri ve erişim denetim listeleri (ACL) hakkında ayrıntılı bilgi toplar.

Bir sızma testinde SMB veya RPC protokolleri güvenlik duvarları veya EDR kuralları tarafından kısıtlandığında, **TCP 389 (LDAP)** ve **TCP 636 (LDAPS)** portları genellikle etki alanı işlevselliği için açık bırakılmak zorundadır. `ldapsearch`, gelişmiş LDAP filtreleri ve bit düzeyinde (bitwise) mantıksal operatörler kullanarak tek bir sorguyla Kerberoasting, AS-REP Roasting, Unconstrained Delegation, RBCD ve LAPS parolaları gibi kritik güvenlik açıklarını doğrudan tespit etmeyi sağlar.

### Protokol ve Mimari Akış

```
┌────────────┐                  TCP 389 / TCP 636                     ┌─────────────┐
│ ldapsearch │ ─────────────────────────────────────────────────────► │  Hedef DC   │
│  (Linux)   │      1. LDAP Bind Request (Anonymous / Simple / SASL)  │ (Active Dir)│
│            │ ◄───────────────────────────────────────────────────── │             │
│            │      2. LDAP Bind Response (Success)                   │             │
│            │ ─────────────────────────────────────────────────────► │             │
│            │      3. SearchRequest (BaseDN, Scope, Filter, Attrs)   │             │
│            │ ◄───────────────────────────────────────────────────── │             │
│            │      4. SearchResultEntry (1..N adet Dizin Nesnesi)    │             │
│            │ ◄───────────────────────────────────────────────────── │             │
│            │      5. SearchResultDone (Sonuç Tamamlandı)            │             │
└────────────┘                                                        └─────────────┘
```

1. **Bağlantı ve Bind:** İstemci, TCP 389 (LDAP) veya TCP 636 (LDAPS) üzerinden DC'ye bağlanır. Kimlik doğrulama anonim (null bind), kullanıcı adı/parola (Simple Bind) veya Kerberos bileti (SASL GSSAPI) ile gerçekleştirilir.
2. **Arama Talebi (SearchRequest):** Arama kökü (`BaseDN`), arama derinliği (`Scope: base/one/sub`), zaman/boyut sınırları, filtrelenecek LDAP sözdizimi ve talep edilen öznitelikler (attributes) iletilir.
3. **Sonuçların Alınması (SearchResultEntry):** Eşleşen her AD nesnesi LDIF (LDAP Data Interchange Format) formatında istemciye basılır.
4. **Paging (Sayfalama):** Active Directory varsayılan olarak tek bir LDAP aramasında en fazla **1000 nesne** (`MaxPageSize`) döndürür. Daha büyük dizinlerde `-E pr=1000/noprompt` Paged Results Control uzantısı kullanılır.

### Active Directory LDAP Portları

| Port | Protokol | Servis / Kullanım Alanı |
|---|---|---|
| **TCP 389** | LDAP | Düz metin LDAP (StartTLS ile şifrelenebilir) |
| **TCP 636** | LDAPS | SSL/TLS ile şifrelenmiş güvenli LDAP bağlantısı |
| **TCP 3268** | LDAP-GC | Global Catalog (Tüm ormandaki nesnelerin kısmi öznitelikleri) |
| **TCP 3269** | LDAPS-GC | Global Catalog üzerinden SSL/TLS şifreli sorgulama |

---

## 2. LDAP Eşleme Kuralları (Matching Rule OID) ve Sözdizimi Analizi

Active Directory, standart eşitlik operatörlerinin (`=`, `>=`, `<=`, `~=`) çözemediği bit düzeyindeki bayrakları ve iç içe geçmiş hiyerarşik yapıları sorgulamak için **Extensible Match Rules (Genişletilebilir Eşleme Kuralları)** adı verilen özel Object Identifier (OID) kurallarını destekler.

### Sözdizimi Formatı
```text
(<öznitelik>:<eşleme_kuralı_oid>:=<aranan_değer>)
```

---

### 2.1 `1.2.840.113556.1.4.803` — LDAP_MATCHING_RULE_BIT_AND
Bu kural, belirtilen tamsayı öznitelik değeri ile aranan bit maskesi arasında mantıksal **Bitwise AND (&)** işlemi gerçekleştirir. Eğer öznitelikte ilgili bit **1 (aktif)** ise nesne sonuç kümesine dahil edilir.

- **Kullanım Sözdizimi:** `(userAccountControl:1.2.840.113556.1.4.803:=<ondalık_bit_değeri>)`
- **Operasyonel Anlamı:** Bir kullanıcının veya bilgisayarın belirli bir güvenlik bayrağına sahip olup olmadığını tek başına sınar.

#### Kritik Bitwise AND Kullanım Örnekleri:

| Aranan Güvenlik Durumu | Ondalık Değer | Onaltılık (Hex) | Filtre Sözdizimi | Operasyonel Açıklama |
|---|---|---|---|---|
| **AS-REP Roasting (DONT_REQ_PREAUTH)** | `4194304` | `0x400000` | `(userAccountControl:1.2.840.113556.1.4.803:=4194304)` | Kerberos ön doğrulaması kapatılmış hesapları yakalar. Parola karması parolasız çekilebilir. |
| **Unconstrained Delegation** | `524288` | `0x80000` | `(userAccountControl:1.2.840.113556.1.4.803:=524288)` | Kısıtlamasız yetkilendirilmiş sunucuları listeler. Kullanıcı TGT'si bellekte önbelleğe alınır. |
| **Constrained Delegation w/ Protocol Transition** | `1048576` | `0x100000` | `(userAccountControl:1.2.840.113556.1.4.803:=1048576)` | S4U2Self ile herhangi bir kullanıcı adına bilet üretme yetkisi olan hesapları bulur. |
| **Devre Dışı Hesaplar (ACCOUNTDISABLE)** | `2` | `0x0002` | `(userAccountControl:1.2.840.113556.1.4.803:=2)` | Sistemde kapatılmış / pasif hesapları listeler. `!(...:=2)` ile aktifler süzülür. |
| **Parolası Asla Sona Ermeyenler** | `65536` | `0x10000` | `(userAccountControl:1.2.840.113556.1.4.803:=65536)` | Eski, unutulmuş veya parola rotasyonu uygulanmayan servis hesaplarını tespit eder. |
| **Parola Zorunlu Olmayanlar (PASSWD_NOTREQD)** | `32` | `0x0020` | `(userAccountControl:1.2.840.113556.1.4.803:=32)` | Boş parola kabul edebilen zafiyetli kullanıcı hesaplarını bulur. |
| **Tersinir Şifreleme (ENCRYPTED_TEXT_PWD_ALLOWED)**| `128` | `0x0080` | `(userAccountControl:1.2.840.113556.1.4.803:=128)` | Parolası tersine çevrilebilir (Reversible encryption) saklanan hesapları yakalar. |
| **Akıllı Kart Zorunlu Hesaplar** | `262144` | `0x40000` | `(userAccountControl:1.2.840.113556.1.4.803:=262144)` | SmartCard zorunlu kılınmış hesapları listeler. |
| **Etki Alanı Denetleyicisi (SERVER_TRUST_ACCOUNT)** | `8192` | `0x2000` | `(userAccountControl:1.2.840.113556.1.4.803:=8192)` | Etki alanındaki tüm Domain Controller bilgisayar hesaplarını doğrudan çeker. |

---

### 2.2 `1.2.840.113556.1.4.804` — LDAP_MATCHING_RULE_BIT_OR
Bu kural, öznitelik değeri ile aranan bit maskesi arasında mantıksal **Bitwise OR (|)** işlemi yapar. Maskedeki bitlerden **en az biri** aktif ise nesne eşleşir.

- **Kullanım Sözdizimi:** `(userAccountControl:1.2.840.113556.1.4.804:=<ondalık_toplam_maske>)`
- **Operasyonel Anlamı:** Birden fazla riskli durumdan herhangi birini barındıran nesneleri tek bir sorguda birleştirmek için kullanılır.
- **Örnek:** Hem AS-REP Roastable (`4194304`) hem de Unconstrained Delegation (`524288`) sahibi olan veya iki durumdan birini taşıyan nesneleri tek sorguda çekmek:
  ```text
  (userAccountControl:1.2.840.113556.1.4.804:=4718592)
  # 4194304 + 524288 = 4718592
  ```

---

### 2.3 `1.2.840.113556.1.4.1941` — LDAP_MATCHING_RULE_IN_CHAIN (Nested / Transitive Resolution)
Active Directory'de gruplar birbirlerinin içine eklenebilir (iç içe geçmiş / nested gruplar). Standart `(memberOf=CN=Domain Admins,...)` sorgusu, yalnızca o gruba **doğrudan** eklenmiş kullanıcıları döndürür; grup içinde başka bir grup varsa (Örn: `Helpdesk -> Tier2_Admins -> Domain Admins`) o gruptaki kullanıcıları göremez.

`1.2.840.113556.1.4.1941` kuralı, Active Directory hiyerarşik nesne ağacında yukarıdan aşağıya veya aşağıdan yukarıya **özyinelemeli (recursive / transitive)** arama yapar.

#### 1. Belirli Bir Grubun Tüm Dolaylı ve Doğrudan Üyelerini Bulma:
```bash
(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,DC=corp,DC=local))
```
- **Ne Yapar?** `Domain Admins` grubuna doğrudan veya başka bir ara grup vasıtasıyla üye olan istisnasız tüm kullanıcıları listeler.

#### 2. Belirli Bir Kullanıcının Üye Olduğu Tüm Grupları (İç İçe Gruplar Dahil) Bulma (Reverse In-Chain):
```bash
(&(objectCategory=group)(member:1.2.840.113556.1.4.1941:=CN=John Doe,OU=Users,DC=corp,DC=local))
```
- **Ne Yapar?** John Doe isimli kullanıcının hiyerarşik olarak dahil olduğu tüm güvenlik ve dağıtım gruplarını listeler.

---

## 3. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Sözdizimi

```bash
ldapsearch -H <LDAP_URI> -x -D '<Kullanıcı_DN_veya_UPN>' -w '<Parola>' -b '<Search_Base_DN>' [seçenekler] '<Filtre>' [öznitelikler]
```

### Kritik Parametreler

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-H` | Hedef LDAP sunucu adresi (URI formatında) | `-H ldap://192.168.1.10` veya `-H ldaps://dc01.corp.local` |
| `-x` | Basit kimlik doğrulama (Simple Bind) kullanır (SASL yerine) | `-x` |
| `-D` | Bind için kullanıcı adı (DN, UPN veya `DOMAIN\user` formatında) | `-D 'j.doe@corp.local'` veya `-D 'CN=John,OU=Users,DC=corp,DC=local'` |
| `-w` | Kimlik doğrulama parolası (Açık metin) | `-w 'P@ssw0rd123!'` |
| `-W` | Parolayı komut satırında yazmak yerine gizli olarak sorar | `-W` |
| `-y` | Parolayı belirtilen dosyadan okur | `-y /root/.secret` |
| `-b` | Arama tabanı (Search Base DN) | `-b 'DC=corp,DC=local'` |
| `-s` | Arama kapsamı (`base`, `one`, `sub` — varsayılan: `sub`) | `-s sub` |
| `-LLL` | Yorum satırlarını, sürüm bilgilerini ve meta verileri gizler (Temiz LDIF) | `-LLL` |
| `-E` | LDAP genişletilmiş kontrolleri (Örn: Paging kontrolü) | `-E pr=1000/noprompt` |
| `-Y` | SASL kimlik doğrulama mekanizması (Kerberos için `GSSAPI`) | `-Y GSSAPI` |
| `-Z` | StartTLS kullanarak bağlantıyı şifreli kanala yükseltir | `-Z` |
| `-o` | Genel ldap.conf seçenekleri geçirir | `-o ldif-wrap=no` (Satır bölmeyi engeller) |
| `-z` | Maksimum döndürülecek nesne sayısı (Size limit) | `-z 50` |
| `-l` | Maksimum sorgu bekleme süresi (Time limit, saniye) | `-l 10` |
| `-d` | Debug / hata ayıklama seviyesi | `-d 1` |

---

## 4. Pratik Komut Örnekleri ve Kapsamlı LDAP Filtre Kataloğu

### 4.1 Kullanıcı ve Hesap Numaralandırma Filtreleri

#### 1. Tüm Aktif (Devre Dışı Olmayan) Kullanıcı Hesapları:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))' \
  sAMAccountName mail title
```

#### 2. Parolası Asla Sona Ermeyen Aktif Kullanıcılar:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=65536))' \
  sAMAccountName pwdLastSet description
```

#### 3. Boş Parola Kabul Edebilen Zafiyetli Hesaplar (`PASSWD_NOTREQD`):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=32))' \
  sAMAccountName
```

#### 4. Tersine Çevrilebilir Şifrelemeyle Saklanan Parolalar (`ENCRYPTED_TEXT_PWD_ALLOWED`):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=128))' \
  sAMAccountName
```

---

### 4.2 Yetkili ve Hassas Hesapların Avlanması (Privilege Discovery)

#### 1. AdminSDHolder Tarafından Korunan Tüm Nesneler (`adminCount=1`):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(adminCount=1)(objectCategory=person)(objectClass=user))' \
  sAMAccountName memberOf description
```
- **Operasyonel Önemi:** `adminCount=1` olan kullanıcılar, geçmişte veya şu anda Domain Admins, Enterprise Admins, Schema Admins, Account Operators gibi kritik gruplara üye olmuş ve ACL miras alması kapatılmış yüksek yetkili hedeflerdir.

#### 2. Kritik İdari Grupların Listelenmesi:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=group)(|(cn=Domain Admins)(cn=Enterprise Admins)(cn=Schema Admins)(cn=Account Operators)(cn=Backup Operators)(cn=Server Operators)(cn=DnsAdmins)))' \
  cn member description
```

---

### 4.3 Kerberos Saldırı Yüzeyi Filtreleri

#### 1. Kerberoasting Adayı Kullanıcı Hesapları (SPN Tanımlı Normal Kullanıcılar):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectClass=user)(servicePrincipalName=*)(!(objectClass=computer))(!(userAccountControl:1.2.840.113556.1.4.803:=2)))' \
  sAMAccountName servicePrincipalName memberOf
```

#### 2. Kerberoastable ve Aynı Zamanda Yönetici Olan Hesaplar:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectClass=user)(servicePrincipalName=*)(adminCount=1)(!(objectClass=computer)))' \
  sAMAccountName servicePrincipalName
```

#### 3. AS-REP Roasting Adayı Hesaplar (`DONT_REQ_PREAUTH`):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))' \
  sAMAccountName description
```

#### 4. Shadow Credentials (msDS-KeyCredentialLink) Tanımlı Hesaplar:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(msDS-KeyCredentialLink=*)' \
  sAMAccountName msDS-KeyCredentialLink
```
- **Operasyonel Önemi:** Hedefte Whisker / pyWhiskey veya PKINIT ile sertifika anahtarı eklenmiş hesapları gösterir (Yetki yükseltme ve persistence tespiti).

---

### 4.4 Kerberos Delegasyon Analiz Filtreleri

#### 1. Kısıtlamasız Delegasyon (Unconstrained Delegation) Sahibi Sistemler:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(primaryGroupID=516)))' \
  sAMAccountName dNSHostName operatingSystem
```

#### 2. Kısıtlı Delegasyon (Constrained Delegation) Yapılandırılmış Hesaplar:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(msDS-AllowedToDelegateTo=*)' \
  sAMAccountName msDS-AllowedToDelegateTo userAccountControl
```

#### 3. Resource-Based Constrained Delegation (RBCD) Tanımlı Bilgisayarlar:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(msDS-AllowedToActOnBehalfOfOtherIdentity=*)' \
  sAMAccountName msDS-AllowedToActOnBehalfOfOtherIdentity
```

---

### 4.5 Bilgisayar, Sunucu ve Altyapı Keşfi

#### 1. Tüm Etki Alanı Denetleyicileri (Domain Controllers):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))' \
  dNSHostName operatingSystem operatingSystemVersion
```

#### 2. Tüm Windows Sunucu Sistemleri (Server OS):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=computer)(operatingSystem=*Server*))' \
  dNSHostName operatingSystem
```

#### 3. MSSQL Veritabanı Sunucuları (SPN Tabanlı Keşif):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=computer)(servicePrincipalName=MSSQLSvc*))' \
  dNSHostName servicePrincipalName
```

#### 4. Eski ve Desteklenmeyen İşletim Sistemleri (Zafiyetli Hedefler):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=computer)(|(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*XP*)(operatingSystem=*Windows 7*)))' \
  dNSHostName operatingSystem
```

---

### 4.6 GPO, Güven İlişkileri ve Sertifika Servisleri (AD CS)

#### 1. Tüm Grup İlkeleri (GPO) ve SYSVOL Dosya Yolları:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(objectClass=groupPolicyContainer)' \
  displayName gPCFileSysPath
```

#### 2. Etki Alanı Güven İlişkileri (Domain Trusts):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(objectClass=trustedDomain)' \
  trustPartner trustDirection trustType trustAttributes
```

#### 3. Kurumsal Sertifika Otoriteleri (AD CS Enterprise CA):
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' \
  -b 'CN=Configuration,DC=corp,DC=local' -LLL \
  '(objectClass=pKIEnrollmentService)' \
  name dNSHostName certificateTemplates
```

---

### 4.7 Bilgi İfşası (Information Leakage) ve Parola Avı

#### 1. Kullanıcı Açıklamalarında Parola Avı:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=person)(objectClass=user)(|(description=*pass*)(description=*sifre*)(description=*pwd*)(description=*welcome*)(description=*temp*)))' \
  sAMAccountName description
```

#### 2. Notlar (`info`) Alanında Gizlenen Veriler:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(&(objectCategory=person)(objectClass=user)(info=*))' \
  sAMAccountName info
```

#### 3. Unix / RFC 2307 Düz Metin Parola Öznitelikleri:
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL \
  '(|(userPassword=*)(unixUserPassword=*))' \
  sAMAccountName userPassword unixUserPassword
```

---

## 5. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kodu | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `ldap_bind: Invalid credentials (49)` | Kullanıcı adı/parola hatalı veya hesap kilitli. Win32 alt kodları: `52e` (yanlış parola), `532` (parola süresi dolmuş), `533` (hesap devre dışı), `775` (hesap kilitli). | Kimlik bilgilerini doğrulayın; `-D` parametresinde `user@corp.local` veya `CN=...,DC=...` tam formatını kullanın. |
| `ldap_bind: Strong(er) authentication required (8)` | Hedef DC, LDAP İmzalama (LDAP Signing) veya Channel Binding (CBT) zorunlu kılmış. | Şifreli kanala geçin: `-H ldaps://<IP>:636` kullanın veya komuta `-Z` (StartTLS) ekleyin. |
| `ldap_search_ext: Size limit exceeded (4)` | Dizin sorgusu 1000 nesneden (`MaxPageSize`) fazla sonuç döndürdü. | Komuta sayfalama kontrolü ekleyin: `-E pr=1000/noprompt`. |
| `ldap_search_ext: Referral (10)` | Nesne geçerli etki alanında değil, başka bir etki alanı/orman kapsamında bulunuyor. | `-C` (Chase referrals) bayrağını ekleyin veya aramayı doğrudan Global Catalog portuna yönlendirin: `-H ldap://<IP>:3268`. |
| `ldap_sasl_interactive_bind_s: Local error (-2)` | Kerberos GSSAPI kimlik doğrulamasında `KRB5CCNAME` geçersiz veya hedef FQDN değil. | `klist` ile geçerli TGT olduğunu doğrulayın; `-H` parametresine IP yerine sunucunun FQDN adını (`dc01.corp.local`) verin. |
| `Can't contact LDAP server (-1)` | Hedefte LDAP servisi kapalı, güvenlik duvarı engelliyor veya routing sorunu var. | `nc -nvz <IP> 389` ile port erişimini test edin. |
| `TLS: hostname verification failed` | LDAPS sertifikasındaki isim ile `-H` parametresindeki hedef adı uyuşmuyor. | `LDAPTLS_REQCERT=never` ortam değişkenini ekleyerek sertifika doğrulamasını atlayın. |
| `ldap_search_ext: Operations error (1)` | `adminCount` veya SACL korumalı bazı nesnelerde anonim/yetkisiz okuma engeli. | Kimlik doğrulama sağlayarak sorgulayın (`-D` ve `-w`). |

---

## 6. OPSEC ve Karşı Tespit (IOC)

### 6.1 Bırakılan İzler

| Log Kaynağı | Event ID / Log | Detay ve Açıklama |
|---|---|---|
| **Directory Service Access** | **1644** | **Expensive / Inefficient LDAP Queries:** DC üzerinde yüksek kaynak tüketen, indekssiz veya çok geniş `*` içeren LDAP aramaları loglanır. |
| **Directory Service Access** | **4662** | Dizin servisi nesnesine erişim denetimi (SACL tanımlı hassas nesnelerde üretilir). |
| **Windows Security Log** | **4624** (Logon Type 3) | Network Logon — Basit bind veya Kerberos bind oturumlarında üretilir. |
| **Windows Security Log** | **4625** | Başarısız LDAP bind denemelerinde (hatalı parola) loglanır. |
| **Sysmon** | **Event ID 3** | İstemci IP'sinden TCP 389 / TCP 636 / TCP 3268 portlarına ağ bağlantısı. |

### 6.2 Ağ ve EDR İmzaları
- **LDAP Normalizasyonu:** LDAP sorguları, dosya açma (SMB) veya proses oluşturma (RPC) gibi doğrudan uç nokta alarmları tetiklemez. Kurumsal ağlarda binlerce meşru LDAP sorgusu aktığı için gürültü seviyesi düşüktür.
- **İndekssiz ve Geniş Sorgu Tespiti:** Tüm dizini tek seferde çekmeye çalışan filtreler (`(objectClass=*)` veya `(sAMAccountName=*admin*)`) DC CPU kullanımını zıplatır ve SIEM'de Event ID 1644 korelasyonu ile anomali yaratır.
- **LDAP Cleartext İmzası:** TCP 389 üzerinden düz metin Simple Bind kullanımı ağ dinleyicileri (Zeek/Suricata) tarafından parolaların yakalanmasına yol açar.

### 6.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | ldapsearch Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesaplarının ve niteliklerinin listelenmesi |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup üyeleri ve iç içe geçmiş üyeliklerin tespiti |
| **T1018** | Remote System Discovery | Bilgisayar ve sunucu rollerinin belirlenmesi |
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | SPN tanımlı kullanıcı hesaplarının keşfi |
| **T1558.004** | Steal or Forge Kerberos Tickets: AS-REP Roasting | `DONT_REQ_PREAUTH` bayraklı hesapların keşfi |
| **T1555** | Credentials from Password Stores: LAPS | `ms-Mcs-AdmPwd` özniteliğinden yerel yönetici parolalarını okuma |

### 6.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **Event 1644 (Pahalı Arama Alarmı)** | Aramalarınızda daima spesifik nesne sınıfları (`objectClass=user`, `objectCategory=person`) kullanın; genel joker (`*`) aramalardan kaçının. |
| **Parolanın Ağda Açık Gitmesi** | Simple Bind (`-x`) yerine mutlaka LDAPS (`ldaps://`, port 636) veya StartTLS (`-Z`) kullanın. |
| **Büyük Veri Transferi Tespiti** | Tüm öznitelikleri (`*`) istemek yerine yalnızca operasyon için gerekenleri (`sAMAccountName`, `userAccountControl`) talep edin. |
| **Maksimum OPSEC için Kerberos** | Basit parola ile bağlanmak yerine Kerberos ccache bileti (`-Y GSSAPI`) kullanarak kimlik doğrulayın. |

### 6.5 Savunma Karşılığı (Blue Team Linkleri)
- Log analizi ve tespit senaryoları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- LDAP İmzalama ve Kanal Bağlama zorunluluğu → [Blue M08 — Protokol Sertleştirme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- Event 1644 izleme konfigürasyonu → `HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics\15 Field Engineering = 5` registry ayarı.

**Sigma Kuralı — Pahalı / İndekssiz LDAP Keşif Sorguları (Event ID 1644):**

```yaml
title: Inefficient or Expensive LDAP Reconnaissance Query
status: experimental
description: Detects LDAP queries scanning a high volume of directory entries (e.g. broad wildcard user or SPN enumeration).
logsource:
  product: windows
  service: directory_service
detection:
  selection:
    EventID: 1644
  filter_volume:
    EntriesVisited: '> 1000'
  condition: selection and filter_volume
level: medium
```

**Microsoft Sentinel (KQL) — Şüpheli Toplu LDAP Sorguları:**

```kql
SecurityEvent
| where EventID == 1644
| where toint(extract(@"Entries returned: (\d+)", 1, EventData)) > 500
| project TimeGenerated, Computer, IpAddress, ClientIP, SearchFilter = extract(@"Search filter: ([^\r\n]+)", 1, EventData)
```

---

## 7. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve operasyonel keşiflerde en sık başvurulan `ldapsearch` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 7.1 Anonim (Null Bind) ile RootDSE ve Etki Alanı Adını Öğrenme
```bash
ldapsearch -H ldap://192.168.1.10 -x -s base -b '' '(objectClass=*)' defaultNamingContext
```
- **Ne Yapar?** Kimlik doğrulaması olmadan hedef DC'nin temel etki alanı DN'ini (`DC=corp,DC=local`) çeker.
- **Ne Zaman Kullanılır?** İlk temas anında hedef etki alanının tam adını öğrenmek ve sonraki komutlara temel oluşturmak için.
- **Parametreler:** `-s base` (Yalnızca kök nesneyi sorgular), `-b ''` (Boş arama tabanı).

### 7.2 Kerberoastable Kullanıcı Hesaplarını Tek Satırda Listeleme
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(&(objectClass=user)(servicePrincipalName=*)(!(objectClass=computer)))' sAMAccountName
```
- **Ne Yapar?** SPN atanmış tüm normal kullanıcı hesaplarını filtreler ve kullanıcı adlarını ekrana döker.
- **Ne Zaman Kullanılır?** Kerberoasting saldırısı öncesinde hangi hesapların hedefleneceğini belirlemek için.

### 7.3 AS-REP Roastable Hesapları Bitwise Filtre ile Çekme
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))' sAMAccountName
```
- **Ne Yapar?** `DONT_REQ_PREAUTH` biti aktif olan hesapları bit düzeyinde mantıksal AND kuralıyla saniyeler içinde yakalar.
- **Ne Zaman Kullanılır?** Kerbrute veya Impacket GetNPUsers öncesi AS-REP Roasting kurbanlarını listelemek için.

### 7.4 Domain Admins Grubunun Tüm Üyelerini İç İçe (Transitive) Çözme
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(&(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,DC=corp,DC=local))' sAMAccountName
```
- **Ne Yapar?** `LDAP_MATCHING_RULE_IN_CHAIN` kuralıyla alt gruplar üzerinden dolaylı olarak Domain Admin yetkisine sahip tüm hesapları bulur.
- **Ne Zaman Kullanılır?** Karmaşık etki alanı mimarilerinde gizli veya dolaylı yönetici hesaplarını haritalamak için.

### 7.5 Unconstrained Delegation Sahibi Sunucuları Bulma
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(primaryGroupID=516)))' sAMAccountName dNSHostName
```
- **Ne Yapar?** DC'ler hariç, kısıtlamasız delegasyon yetkisi bulunan üye sunucuları listeler.
- **Ne Zaman Kullanılır?** SpoolSample / PetitPotam ile zorlamalı kimlik tetiklendiğinde TGT yakalanacak hedef sunucuları seçmek için.

### 7.6 LAPS Parolalarını Sorgulama
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(ms-Mcs-AdmPwd=*)' sAMAccountName ms-Mcs-AdmPwd
```
- **Ne Yapar?** Dizin üzerinde okunabilir LAPS parolası barındıran bilgisayarları ve düz metin yerel admin parolalarını döker.
- **Ne Zaman Kullanılır?** Yanal hareket aşamasında üye sunucularda yerel yönetici erişimi elde etmek için.

### 7.7 Sayfalama ile Tüm Kullanıcıları Temiz LDIF Olarak Kaydetme
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -E pr=1000/noprompt -LLL -o ldif-wrap=no '(objectClass=user)' sAMAccountName > /tmp/users.ldif
```
- **Ne Yapar?** 1000 kayıt limitine takılmadan tüm kullanıcıları tek bir metin dosyasına satır kaydırmadan yazar.
- **Ne Zaman Kullanılır?** Büyük kurumsal ağlarda eksiksiz kullanıcı envanteri çıkarmak ve çevrimdışı analiz yapmak için.

### 7.8 Kerberos GSSAPI ile Parolasız ve Şifreli Sorgu Koşturma
```bash
export KRB5CCNAME=/tmp/admin.ccache && ldapsearch -H ldap://dc01.corp.local -Y GSSAPI -b 'DC=corp,DC=local' -LLL '(&(objectClass=user)(adminCount=1))' sAMAccountName
```
- **Ne Yapar?** NTLM yerine Kerberos bilet önbelleğiyle bağlanarak ayrıcalıklı korunan hesapları (`adminCount=1`) listeler.
- **Ne Zaman Kullanılır?** NTLM trafiğinin izlendiği sıkı ortamlarda en yüksek OPSEC standardıyla arama yapmak için.

### 7.9 Kullanıcı Açıklamalarında (description) Parola Arama
```bash
ldapsearch -H ldap://192.168.1.10 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(&(objectCategory=person)(objectClass=user)(|(description=*pass*)(description=*sifre*)))' sAMAccountName description
```
- **Ne Yapar?** Açıklama kısmında `pass` veya `sifre` geçen hesapları yakalar.
- **Ne Zaman Kullanılır?** Sistem yöneticilerinin unutarak açıklama alanına yazdığı kimlik bilgilerini keşfetmek için.

### 7.10 LDAPS (Port 636) ile Sertifika Doğrulamayı Atlayarak Şifreli Bağlanma
```bash
LDAPTLS_REQCERT=never ldapsearch -H ldaps://192.168.1.10:636 -x -D 'j.doe@corp.local' -w 'P@ss123!' -b 'DC=corp,DC=local' -LLL '(objectClass=domain)' name
```
- **Ne Yapar?** Geçersiz veya kendinden imzalı (self-signed) CA sertifikası olan ortamlarda SSL/TLS şifreli kanalla güvenli sorgu yapar.
- **Ne Zaman Kullanılır?** Düz metin port 389 engellendiğinde veya LDAP signing zorunlu olduğunda bağlantı kurmak için.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| OpenLDAP ldapsearch Kılavuzu | [openldap.org/software/man](https://www.openldap.org/software/man.cgi?query=ldapsearch) |
| Microsoft Active Directory LDAP Filtre Sözdizimi | [Microsoft Docs](https://docs.microsoft.com/en-us/windows/win32/adsi/search-filter-syntax) |
| Microsoft UserAccountControl Bayrakları | [Microsoft Support](https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/useraccountcontrol-manipulate-account-properties) |
| Active Directory Search Rules (Bitwise & In-Chain) | [Microsoft Docs](https://docs.microsoft.com/en-us/windows/win32/adsi/search-filter-syntax#matching-rule-oids) |
| MITRE ATT&CK T1087.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |
| PayloadsAllTheThings — LDAP Injection & Search | [github.com/swisskyrepo](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/LDAP%20Injection) |

---

> **Önceki:** [← mount.cifs](./mount.cifs.md) · **Sonraki:** [windapsearch →](./windapsearch.md)
