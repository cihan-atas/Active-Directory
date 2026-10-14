# dsquery / dsget

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows yerleşik Active Directory komut satırı arama araçları; LDAP filtreleriyle nesne bulma (`dsquery`) ve bulunan nesnelerin özniteliklerini boru hattı (pipeline) üzerinden dökme (`dsget`).

---

## 1. Genel Bakış ve Amaç

`dsquery.exe` ve `dsget.exe`, Windows Server işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\dsquery.exe` ve `dsget.exe`), Windows istemci işletim sistemlerinde ise **RSAT (Remote Server Administration Tools)** paketiyle gelen yerel Active Directory komut satırı araçlarıdır. Bu araç çifti, Unix felsefesine benzer bir boru hattı (pipelining `|`) mimarisiyle çalışır: `dsquery` hedef Active Directory veritabanında belirtilen kriterlere göre nesnelerin DN (Distinguished Name) yollarını sorgular, `dsget` ise boru hattından gelen bu DN girdilerini alarak nesnelerin güvenlik grupları, e-posta adresleri, parola süreleri, SID ve açıklama gibi detaylı özniteliklerini döker.

Red Team ve sızma testi operasyonlarında, etki alanına dahil bir Windows sunucusu veya RSAT kurulu bir yönetici iş istasyonu ele geçirildiğinde, harici hiçbir araç indirmeden doğrudan Windows'un yerleşik araçlarıyla derinlemesine **LDAP keşfi**, **hiyerarşik OU analizi**, **içiçe (nested) grup çözümü** ve **zafiyet filtrelemesi** (SPN avı, Unconstrained Delegation vb.) gerçekleştirmek için en güçlü LOLBin ikilisidir.

### Protokol ve Çalışma Prensibi

`dsquery` ve `dsget`, doğrudan **LDAP (Lightweight Directory Access Protocol)** ve **Global Catalog (GC)** protokolleri üzerinden Active Directory ile haberleşir:

```
┌──────────────────────────────────────────────────────────────┐
│                      Yerel İstemci                           │
│  [ dsquery.exe ] ──(LDAP Search Query)──┐                    │
│         │ (DN Listesi Çıktısı)          │                    │
│         ▼                               │                    │
│     [ PIPE | ]                          ▼                    │
│         │ (DN Girdisi)            [ TCP 389 (LDAP) ]         │
│         ▼                         [ TCP 3268 (GC)  ]         │
│  [ dsget.exe ] ───(LDAP Read Attr)──────┘                    │
└─────────────────────────────────────────┬────────────────────┘
                                          │
                                          ▼
┌──────────────────────────────────────────────────────────────┐
│                 Etki Alanı Denetleyicisi (DC)                │
│                 [ NTDS.DIT / Active Directory ]              │
│                                                              │
│  - Object Category & Class Filtreleme                        │
│  - Hiyerarşik OU ve Nesne Ağacı Taraması                     │
│  - Token-Groups / Rekürsif Grup Çözümlemesi                  │
│  - Bitwise UserAccountControl Karşılaştırmaları              │
└──────────────────────────────────────────────────────────────┘
```

1. **Arama ve DN Tespiti:** `dsquery user`, `dsquery computer` veya genel LDAP araması yapan `dsquery *`, etki alanı denetleyicisinin LDAP servisine (TCP 389) veya orman genelinde Global Catalog servisine (TCP 3268) standart RFC 4515 LDAP filtreleri gönderir. Dönen nesnelerin DN yollarını (`CN=jdoe,OU=Users,DC=lab,DC=local`) satır satır standart çıktıya (stdout) basar.
2. **Boru Hattı ile Öznitelik Dökümü:** Windows boru hattı (`|`) kullanılarak DN listesi doğrudan `dsget` aracının standart girdisine (stdin) aktarılır. `dsget`, bu DN yollarındaki nesnelerin özniteliklerini tek tek veya topluca sorgulayarak tablo veya liste halinde kullanıcıya sunar.
3. **Rekürsif İçiçe Grup Çözümleme (`-expand`):** `dsget group <DN> -members -expand` komutu, Active Directory'deki `LDAP_MATCHING_RULE_IN_CHAIN` mekanizmasına benzer şekilde içiçe geçmiş tüm alt grup üyeliklerini tek bir komutla açığa çıkarır.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **İçiçe Geçmiş (Nested) Grup Avı** | Bir kullanıcının dolaylı olarak `Domain Admins` veya `Enterprise Admins` yetkisine sahip olup olmadığını rekürsif olarak çözme. |
| **Zafiyetli Hesap Analizi** | Parolası hiç süresi dolmayan (`-pwdneverexpires`), devre dışı bırakılmış veya eski hesapları filtreleme. |
| **Kerberoasting & AS-REP Roast Keşfi** | Ham LDAP filtresi (`dsquery *`) ile SPN tanımlı servis hesaplarını ve `DONT_REQ_PREAUTH` bayraklı hesapları listeleme. |
| **Delegasyon Analizi** | Sınırsız delegasyon (`TRUSTED_FOR_DELEGATION`) yetkisine sahip sunucuları ve bilgisayarları haritalama. |
| **Sıfır Dosya Bırakma (Zero Artifact)** | Hedef sistemde ek bir DLL veya EXE derlemeden Windows'un kendi araçlarıyla kurumsal LDAP verisini dökme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `dsquery / dsget` | `PowerView (PowerShell)` | `Get-ADUser (AD Module)` | `ldapsearch (Linux)` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Windows Server'da hazır, Win10'da RSAT gerekir | Harici script indirilmelidir | RSAT / ADWS gerektirir | Linux ortamlarında hazır |
| **Protokol** | LDAP (389), GC (3268) | LDAP / ADWS | ADWS (TCP 9389) | LDAP / LDAPS |
| **Boru Hattı (Pipeline)** | Yerel Windows Borusu (`\|`) | PowerShell Pipeline (`\|`) | PowerShell Pipeline (`\|`) | Bash Borusu (`\| grep/awk`) |
| **Öznitelik Esnekliği** | Yüksek (Özel filtreler ve attr'ler) | Çok Yüksek | Yüksek | Çok Yüksek (Ham ASN.1) |
| **EDR Görünürlüğü** | Komut satırı argümanı kaydedilir | Script Block Logging (EID 4104) | Script Block Logging | Windows uç noktada sıfır iz |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
:: 1. dsquery Sözdizimi:
dsquery <nesne_türü> [arama_kriterleri] [-o {dn | rdn | upn | samid}] [-limit <N>] [-gc]

:: 2. dsget Sözdizimi:
dsget <nesne_türü> <Nesne_DN> [-öznitelikler]

:: 3. Birleşik Boru Hattı (Pipeline) Sözdizimi:
dsquery <nesne_türü> [filtre] | dsget <nesne_türü> [-öznitelikler]
```

### Desteklenen Nesne Türleri

| Nesne Türü | Açıklama |
|---|---|
| `user` | Kullanıcı hesaplarını arar / inceler. |
| `computer` | Bilgisayar ve sunucu hesaplarını arar / inceler. |
| `group` | Güvenlik ve dağıtım gruplarını arar / inceler. |
| `ou` | Organizasyonel Birimleri (Organizational Unit) arar / inceler. |
| `server` | Etki alanındaki Domain Controller ve sunucuları arar. |
| `site` | Active Directory Site nesnelerini listeler. |
| `subnet` | Tanımlı IP alt ağlarını (subnets) listeler. |
| `*` | Ham LDAP filtresi ile herhangi bir nesne sınıfını arar (`(objectClass=*)`). |

### Kritik Parametreler ve Açıklamaları

#### `dsquery` Parametreleri:
| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-o {dn \| rdn \| upn \| samid}` | Çıktı formatını belirler (Varsayılan: `dn`). | `dsquery user -o samid` |
| `-limit <N>` | Dönecek maksimum nesne sayısını ayarlar (`0` = sınırsız). | `dsquery user -limit 0` |
| `-name <Pattern>` | Nesne adında wildcard (`*`) araması yapar. | `dsquery user -name "adm*"` |
| `-disabled` | Yalnızca devre dışı bırakılmış hesapları döndürür. | `dsquery user -disabled` |
| `-inactive <Hafta>` | Belirtilen hafta sayısı boyunca oturum açmamış hesapları listeler. | `dsquery user -inactive 4` |
| `-pwdneverexpires` | Parolası hiç süresi dolmayan hesapları filtreler. | `dsquery user -pwdneverexpires` |
| `-scope {base \| onelevel \| subtree}` | Arama derinliğini belirler (Varsayılan: `subtree`). | `dsquery user -scope onelevel` |
| `-gc` | Sorguyu etki alanı denetleyicisi yerine Global Catalog (TCP 3268) üzerinden yapar. | `dsquery user -name "*admin*" -gc` |
| `-filter <LDAP_Filter>` | Ham LDAP arama filtresi uygular (`dsquery *` ile zorunludur). | `dsquery * -filter "(servicePrincipalName=*)"` |
| `-attr <Attr1 Attr2>` | `dsquery *` çıktısında görüntülenecek öznitelikleri belirtir. | `dsquery * -attr samAccountName description` |

#### `dsget` Parametreleri:
| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `user <DN> -memberof` | Kullanıcının doğrudan üye olduğu grupları listeler. | `dsget user "CN=jdoe..." -memberof` |
| `user <DN> -expand` | `-memberof` ile birlikte içiçe tüm dolaylı grup üyeliklerini çözer. | `dsget user "CN=jdoe..." -memberof -expand` |
| `user <DN> -sid` | Kullanıcının güvenlik tanımlayıcısını (SID) görüntüler. | `dsget user "CN=jdoe..." -sid` |
| `user <DN> -pwdneverexpires` | Parolanın süresiz olup olmadığını doğrular (`yes/no`). | `dsget user "CN=jdoe..." -pwdneverexpires` |
| `group <DN> -members` | Grubun doğrudan üyelerini döker. | `dsget group "CN=Domain Admins..." -members` |
| `group <DN> -expand` | Grubun içiçe tüm alt grup üyelerini rekürsif olarak çözer. | `dsget group "CN=Domain Admins..." -members -expand` |
| `computer <DN> -loc` | Bilgisayar hesabında kayıtlı fiziksel konum bilgisini gösterir. | `dsget computer "CN=SRV01..." -loc` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Ayrıcalıklı Grup Üyelerini ve İçiçe Grupları Rekürsif Çözme

Saldırgan `Domain Admins` grubuna doğrudan veya başka gruplar aracılığıyla (nested) üye olan tüm kullanıcıları tek zincirde listelemek ister:

```cmd
dsquery group -name "Domain Admins" | dsget group -members -expand
```

**Örnek Çıktı Analizi:**
```text
"CN=Administrator,CN=Users,DC=lab,DC=local"
"CN=svc_backup,OU=ServiceAccounts,DC=lab,DC=local"
"CN=da_jdoe,OU=IT_Staff,DC=lab,DC=local"
"CN=helpdesk_lead,OU=Helpdesk,DC=lab,DC=local"
```
- `-expand` bayrağı sayesinde, örneğin `Helpdesk Tier 2` grubu `Domain Admins` içine eklenmişse, `helpdesk_lead` kullanıcısı doğrudan listelenir ve gizli yetki yükseltme yolları açığa çıkarılır.

Tüm bu kullanıcıların yalnızca sAMAccountName (kullanıcı adı) değerlerini almak için zincire ikinci bir `dsget` eklenebilir:
```cmd
dsquery group -name "Domain Admins" | dsget group -members -expand | dsget user -samid
```

---

### Senaryo 2: Parolası Hiç Süresi Dolmayan ve Devre Dışı Bırakılmamış Hesapları Avlama

Parolası hiç süresi dolmayan kullanıcılar, eski ve zayıf parola kullanma ihtimali en yüksek hedeflerdir:

```cmd
dsquery user -pwdneverexpires -limit 0 | dsget user -samid -pwdneverexpires -disabled
```

**Örnek Çıktı:**
```text
  samid               pwdneverexpires  disabled
  Administrator       yes              no
  krbtgt              yes              yes
  sql_service         yes              no
  jenkins_build       yes              no
dsget succeeded
```
- `disabled: no` ve `pwdneverexpires: yes` olan `sql_service` ve `jenkins_build` hesapları parola püskürtme veya Kerberoasting için birincil hedeftir.

---

### Senaryo 3: Etki Alanındaki Tüm Domain Controller ve Sunucu İşletim Sistemlerini Haritalama

Ağdaki tüm DC'leri listelemek:
```cmd
dsquery server -o rdn
```

Sunucu işletim sistemi (Windows Server 2016, 2019, 2022) çalıştıran tüm bilgisayarları bulmak:
```cmd
dsquery computer -limit 0 | dsget computer -samid -desc -loc
```

---

### Senaryo 4: Belirli Bir Organizasyonel Birim (OU) Altındaki Kullanıcıları Sorgulama

Belirli bir departmana (örneğin Finans veya Yönetim) ait kullanıcıları listelemek:

```cmd
dsquery user "OU=Yonetim,OU=Kullanicilar,DC=lab,DC=local" -limit 50 | dsget user -samid -title -dept
```

**Örnek Çıktı:**
```text
  samid         title                    dept
  ahmet.kaya    Finans Direktoru         Mali Isler
  selin.demir   Genel Mudur Yardimcisi   Yonetim
dsget succeeded
```

---

### Senaryo 5: Gelişmiş Ham LDAP Filtresi ile Kerberoastable (SPN Kayıtlı) Hesapları Bulma

`dsquery *` modu doğrudan ham LDAP filtrelerini kabul eder:

```cmd
dsquery * domainroot -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))" -attr samAccountName servicePrincipalName -limit 0
```

**Örnek Çıktı:**
```text
  samAccountName    servicePrincipalName
  svc_sql           MSSQLSvc/db01.lab.local:1433
  svc_iis           HTTP/web.lab.local
dsget succeeded
```
- Dönen kullanıcı hesapları Kerberoasting saldırısı ile bilet çekilerek çevrimdışı parola kırma testine tabi tutulabilir.

---

### Senaryo 6: Unconstrained Delegation (Sınırsız Delegasyon) Sahibi Sistemleri Avlama

`userAccountControl` bayrağı `TRUSTED_FOR_DELEGATION` (`0x80000 = 524288`) olan sistemleri bitwise LDAP filtresi ile bulma:

```cmd
dsquery * domainroot -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))" -attr samAccountName dNSHostName
```

**Örnek Çıktı:**
```text
  samAccountName    dNSHostName
  DC01$             DC01.lab.local
  DC02$             DC02.lab.local
  SRV-PRINT01$      SRV-PRINT01.lab.local
dsget succeeded
```
- DC'ler haricindeki `SRV-PRINT01$` sistemi sınırsız yetkilendirmeye sahiptir. Bu makineye TGT enjekte ettirilerek (örneğin PrinterBug/SpoolSample ile) etki alanı yöneticisi biletleri ele geçirilebilir.

---

### Senaryo 7: PowerShell ile dsquery/dsget Çıktısını Nesneleştiren Otomasyon

CMD boru hattının çıktılarını PowerShell içerisinde JSON veya PSCustomObject olarak ayrıştıran operasyonel betik:

```powershell
# Domain Admins üyelerini ve SID değerlerini nesneleştiren betik:
$Members = dsquery group -name "Domain Admins" | dsget group -members -expand
$Members | ForEach-Object {
    $dn = $_.Trim('"')
    if ($dn) {
        $userData = dsget user "$dn" -samid -sid -pwdneverexpires | Select-Object -Skip 1 -First 1
        $parts = $userData.Trim() -split '\s+'
        [PSCustomObject]@{
            DistinguishedName = $dn
            sAMAccountName    = $parts[0]
            SID               = $parts[1]
            PwdNeverExpires   = $parts[2]
        }
    }
} | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `The term 'dsquery' is not recognized as the name of a cmdlet, function, or operable program.` | `dsquery.exe` ve `dsget.exe` yalnızca Windows Server'da varsayılandır; istemcide RSAT kurulu değildir. | Windows İstemcisinde RSAT modülünü yükleyin: `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` veya doğrudan DC/Sunucu üzerinde çalıştırın. |
| `dsquery failed:The directory service is exhausted.` / `Size Limit Exceeded` | LDAP arama sonucu varsayılan 100 nesne limitine takılmıştır. | Komuta `-limit 0` parametresini ekleyerek arama sınırını kaldırın (`dsquery user -limit 0`). |
| `dsquery failed:A referral was returned from the server.` | Sorgulanan nesne mevcut etki alanında değil, başka bir child veya forest domain'dedir. | Komuta `-gc` parametresi ekleyerek Global Catalog üzerinden arayın veya `-d <TargetDomain>` ile hedef etki alanını açıkça belirtin. |
| `dsget failed:Value for attribute could not be converted.` | `dsget` için sağlanan nesne türü ile DN nesnesinin gerçek sınıfı uyuşmuyor (Örneğin bir bilgisayar DN'i için `dsget user` çağrılmıştır). | Nesne sınıfını doğrulayın; genel sorgu için `dsget *` veya nesneye uygun `dsget computer` / `dsget group` kullanın. |
| `dsquery failed:Server is unwilling to process request.` | Gönderilen ham LDAP filtresi (`-filter`) sözdizimsel olarak hatalıdır veya parantez eşleşmesi bozuktur. | LDAP filtresini kontrol edin; RFC 4515 kurallarına göre her mantıksal operatör (`&`, `|`, `!`) parantezle kapatılmalıdır. |
| `dsquery failed:An operations error occurred.` | İstemcinin DC ile LDAP iletişimi (TCP 389) kesintiye uğramıştır veya Kerberos bilet süresi dolmuştur. | `klist purge` ile biletleri temizleyin ve `nltest /dsgetdc` ile DC bağlantısını doğrulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Windows Security Olay Günlükleri:**
  - **Event ID 4688 (Process Creation):** Süreç oluşturma denetimi açık olduğunda `dsquery.exe` ve `dsget.exe` komut satırı argümanları (`-pwdneverexpires`, `-filter`, `-expand`) kaydedilir.
  - **Event ID 1644 (Active Directory LDAP Query Auditing):** Etki alanı denetleyicisinde gelişmiş LDAP sorgu günlüğü etkinse, `dsquery *` ile yapılan veritabanı taramaları, incelenen kayıt sayısı (`EntriesReturned`, `EntriesVisited`) ile birlikte DC `Directory Service` günlüğüne kaydedilir.
  - **Event ID 4662 (Directory Service Access):** Hassas Active Directory nesneleri veya şifrelenmiş öznitelikler sorgulandığında oluşturulur.
- **Sysmon İzleri:**
  - **Sysmon Event ID 1 (Process Creation):** Boru hattı çalıştırıldığında `cmd.exe` -> `dsquery.exe` ve hemen ardından boru hattından okuyan `dsget.exe` ikili süreç zinciri kaydedilir.
  - **Sysmon Event ID 3 (Network Connection):** `dsquery.exe`'nin DC IP adresine doğru TCP 389 (LDAP) veya TCP 3268 (Global Catalog) portuna açtığı bağlantılar loglanır.

### 5.2 Ağ ve EDR İmzaları

- **LOLBin / İmzalı Dosya:** Her iki araç da Microsoft imzalı güvenilir sistem bileşenleridir. Dosya karma kontrolü (AppLocker) genellikle bu araçları engellemez.
- **EDR Davranışsal Analizi:** Düşük yetkili bir kullanıcının veya olağandışı bir sürecin (Örn: `w3wp.exe`, `powershell.exe`) `dsquery` ile `Domain Admins` veya `-pwdneverexpires` sorgulaması EDR ve SIEM alarmlarını doğrudan tetikler.
- **Ağ Seviyesinde LDAP:** Trafik Kerberos ile imzalanmış veya şifrelenmiş (LDAPS / SASL) olsa dahi, LDAP filtre sorgularının yoğunluğu ağ anomali sensörleri tarafından fark edilebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesaplarını ve parola özniteliklerini sorgulama (`dsquery user`). |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup üyeliklerini ve içiçe yapıları çözme (`dsquery group | dsget group -expand`). |
| **T1018** | Remote System Discovery | Domain Controller ve sunucu hesaplarını keşfetme (`dsquery server`, `dsquery computer`). |
| **T1482** | Domain Trust Discovery | Global Catalog ve orman nesnelerini haritalama (`dsquery ... -gc`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Komut Satırı Argümanı Tespiti** | `dsquery` yerine PowerShell içinde bellek içi (in-memory) LDAP araması yapan ADSI sınıflarını kullanın: `[adsisearcher]'(samAccountType=805306368)'`. |
| **Yüksek Kayıt Döndürme Uyarısı (EID 1644)** | `-limit 0` kullanarak tüm dizini tek seferde çekmek yerine, spesifik OU'ları hedefleyin veya `-limit 50` gibi kontrollü limitler kullanın. |
| **İçiçe Grup Çözümleme Gürültüsü** | `-expand` bayrağı DC üzerinde yoğun işlemci yükü ve token çözümleme sorgusu oluşturur; bunu yalnızca kritik tekil hedefler için uygulayın. |

### 5.5 Savunma Karşılığı (Blue Team)

- **LDAP Sorgu Sınırlandırması ve Denetimi:** Gelişmiş LDAP sorgu analizi için kayıt defteri üzerinden Event ID 1644 eşiklerini yapılandırın:
  ```cmd
  reg add "HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics" /v "15 Field Engineering" /t REG_DWORD /d 5 /f
  ```
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Suspicious Active Directory Reconnaissance via DSQUERY
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith:
              - '\dsquery.exe'
              - '\dsget.exe'
          CommandLine|contains:
              - 'Domain Admins'
              - '-pwdneverexpires'
              - 'servicePrincipalName'
              - 'userAccountControl'
              - '-expand'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Domain Admins Grubunun Tüm Üyelerini Rekürsif Olarak Dökme
```cmd
dsquery group -name "Domain Admins" | dsget group -members -expand
```
- **Ne Yapar?** `Domain Admins` grubuna doğrudan veya alt gruplar üzerinden dolaylı olarak üye olan tüm kullanıcıların tam DN yollarını listeler.
- **Ne Zaman Kullanılır?** Yetki yükseltme ve yanal hareket hedeflerini eksiksiz haritalamak için.
- **Parametreler:** `-name "Domain Admins"` (Grup adı), `-members` (Üyeleri listeler), `-expand` (İçiçe geçmiş tüm grupları çözer).

### 6.2 Parolası Hiç Süresi Dolmayan Kullanıcıları Listeleme
```cmd
dsquery user -pwdneverexpires -limit 0 | dsget user -samid -pwdneverexpires -disabled
```
- **Ne Yapar?** Parolası süresiz olan tüm hesapları bulur; hesapların kullanıcı adını, süresiz parola durumunu ve aktiflik bilgisini tablo olarak döker.
- **Ne Zaman Kullanılır?** Parola püskürtme saldırısı için zayıf ve unutulmuş hesapları tespit etmek amacıyla.
- **Parametreler:** `-pwdneverexpires` (Süresiz parola filtresi), `-limit 0` (Kayıt sınırını kaldırır).

### 6.3 Ağdaki Tüm Domain Controller Sunucularını Bulma
```cmd
dsquery server -o rdn
```
- **Ne Yapar?** Etki alanındaki tüm Domain Controller sunucularının yalnızca isimlerini (RDN) listeler.
- **Ne Zaman Kullanılır?** Kimlik doğrulama ve replikasyon noktası olan DC'leri tespit etmek için.
- **Parametreler:** `server` (Sunucu nesnelerini arar), `-o rdn` (Yalnızca nesne adını verir, DN yolunu kırpar).

### 6.4 Belirli Bir Kullanıcının Dahil Olduğu Tüm Grupları Çözme
```cmd
dsquery user -name "jdoe*" | dsget user -memberof -expand
```
- **Ne Yapar?** Adı `jdoe` ile başlayan kullanıcının doğrudan ve dolaylı olarak üyesi olduğu tüm grupları rekürsif olarak döker.
- **Ne Zaman Kullanılır?** Ele geçirilen bir kullanıcının sahip olduğu tüm etki alanı ayrıcalıklarını analiz etmek için.
- **Parametreler:** `-name "jdoe*"` (Wildcard kullanıcı arama), `-memberof` (Grupları listeler), `-expand` (İçiçe grupları açar).

### 6.5 SPN Kaydı Olan (Kerberoastable) Kullanıcıları Filtreleme
```cmd
dsquery * domainroot -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))" -attr samAccountName servicePrincipalName
```
- **Ne Yapar?** Üzerinde SPN (Service Principal Name) kaydı bulunan tüm kullanıcı servis hesaplarını döker.
- **Ne Zaman Kullanılır?** Kerberoasting saldırısı öncesinde bilet talep edilebilecek hedef hesapları listelemek için.
- **Parametreler:** `* domainroot` (Kök dizinden arar), `-filter` (LDAP arama filtresi), `-attr` (Görüntülenecek öznitelikler).

### 6.6 Pasif veya Devre Dışı Bırakılmış Hesapları Listeleme
```cmd
dsquery user -disabled -limit 0 | dsget user -samid -desc
```
- **Ne Yapar?** Etki alanında devre dışı bırakılmış tüm kullanıcıları ve açıklama alanlarını (`description`) listeler.
- **Ne Zaman Kullanılır?** Açıklama kısmında unutulmuş geçici parolaları veya eski yönetici hesaplarını keşfetmek için.
- **Parametreler:** `-disabled` (Yalnızca pasif hesaplar), `-desc` (Açıklama özniteliğini gösterir).

### 6.7 Belirli Bir OU Altındaki Tüm Bilgisayarları Bulma
```cmd
dsquery computer "OU=Workstations,DC=lab,DC=local" -limit 0
```
- **Ne Yapar?** Yalnızca belirtilen Organizasyonel Birim altındaki bilgisayar hesaplarını sorgular.
- **Ne Zaman Kullanılır?** Şube veya departman bazlı iş istasyonu hedeflerini daraltmak için.
- **Parametreler:** `"OU=Workstations..."` (Aramanın başlayacağı temel DN).

### 6.8 Unconstrained Delegation Yetkisine Sahip Sistemleri Avlama
```cmd
dsquery * domainroot -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))" -attr samAccountName dNSHostName
```
- **Ne Yapar?** Sınırsız delegasyon yetkisi verilmiş tüm bilgisayarları listeler.
- **Ne Zaman Kullanılır?** TGT kaçırma ve yetki yükseltme (PrinterBug / PetitPotam) operasyonlarında hedef belirlemek için.
- **Parametreler:** `userAccountControl:1.2.840.113556.1.4.803:=524288` (Bitwise AND kontrolü).

### 6.9 Global Catalog Üzerinden Orman Çapında Kullanıcı Arama
```cmd
dsquery user -name "*admin*" -gc
```
- **Ne Yapar?** Yalnızca yerel etki alanında değil, tüm Active Directory ormanındaki ağaç ve etki alanlarında Global Catalog portu (TCP 3268) üzerinden kullanıcı arar.
- **Ne Zaman Kullanılır?** Çoklu etki alanı (multi-domain forest) yapılarında orman geneline yayılmış yönetici hesaplarını bulmak için.
- **Parametreler:** `-gc` (Global Catalog sunucusuna sorgu gönderir).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — dsquery Dokümantasyonu | [learn.microsoft.com](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc732952(v=ws.11)) |
| Microsoft Learn — dsget Dokümantasyonu | [learn.microsoft.com](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc755162(v=ws.11)) |
| RFC 4515: LDAP String Representation of Search Filters | [datatracker.ietf.org](https://datatracker.ietf.org/doc/html/rfc4515) |
| MITRE ATT&CK T1087.002 (Account Discovery: Domain Account) | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |

---

> **Önceki:** [← net.exe](./net.md) · **Sonraki:** [klist →](./klist.md)
