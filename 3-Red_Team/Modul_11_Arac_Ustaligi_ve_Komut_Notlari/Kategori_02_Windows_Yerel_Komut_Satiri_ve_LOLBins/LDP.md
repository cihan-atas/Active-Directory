# LDP.exe

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft yerleşik gelişmiş LDAP yönetim, arama ve protokol tanı aracı; ham LDAP öznitelik analizi, genişletilmiş kontroller (Controls), silinmiş nesne avı (Tombstone) ve güvenlik tanımlayıcısı (DACL) inceleme.

---

## 1. Genel Bakış ve Amaç

`ldp.exe`, Windows Server işletim sistemlerinde varsayılan olarak (`C:\Windows\System32\ldp.exe`) bulunan ve Windows istemcilerinde **RSAT (Remote Server Administration Tools)** paketiyle gelen, Microsoft'un Active Directory için geliştirdiği en köklü ve güçlü grafiksel/komut satırı LDAP istemcisidir.

Standart Active Directory yönetim konsolları (`dsa.msc` - ADUC vb.), kullanıcıya yalnızca standartlaştırılmış ve filtrelenmiş verileri sunar. Birçok hassas öznitelik (örneğin `nTSecurityDescriptor`, `msDS-AllowedToActOnBehalfOfOtherIdentity`, `servicePrincipalName`, `adminCount`, `objectSid`, `schemaIDGUID`) standart arayüzlerde ya hiç görünmez ya da salt-okunur olarak kısıtlanır.

Red Team operasyonlarında ve derinlemesine Active Directory güvenlik denetimlerinde `ldp.exe`, saldırganın hedef etki alanında harici hiçbir ikili dosya veya script yüklemeden:
1. **Ham LDAP Özniteliklerini İncelemesi ve Manipüle Etmesi:** Standart araçların gizlediği ikili (binary) güvenlik yapılarını doğrudan okumak ve değiştirmek (örneğin Resource-Based Constrained Delegation - RBCD saldırıları).
2. **Genişletilmiş LDAP Kontrollerini (Extended Controls) Kullanması:** Active Directory Çöp Kutusu'ndaki (Recycle Bin / Tombstone) silinmiş nesneleri ortaya çıkarmak (`LDAP_SERVER_SHOW_DELETED_OID`), güvenlik tanımlayıcılarını ham DACL seviyesinde çekmek (`LDAP_SERVER_SD_FLAGS_OID`).
3. **Sıfır Dosya İziyle (Pure Living-off-the-Land) Keşif:** Microsoft tarafından işletim sisteminin çekirdeğinde sağlanan güvenilir bir ikili dosya ile güvenlik alarmlarını tetiklemeden derinlemesine LDAP keşfi yürütmek.

### Protokol ve Çalışma Prensibi

`ldp.exe`, Windows'un resmi LDAP istemci kütüphanesi olan `wldap32.dll` üzerinden doğrudan Active Directory ile haberleşir:

```
┌──────────────────────────────────────────────────────────────┐
│                    Yönetici / Saldırgan                      │
│                         [ ldp.exe ]                          │
└──────────────────────────────┬───────────────────────────────┘
                               │
            1. Connect (TCP 389 LDAP / TCP 636 LDAPS)          
            2. Bind (SSPI / Kerberos / NTLM / Simple)          
            3. Extended Controls OID Enjeksiyonu               
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Etki Alanı Denetleyicisi (DC)                │
│                 [ NTDS.DIT / LDAP Service ]                  │
│                                                              │
│  - RootDSE Sorgusu (SupportedCapabilities, Controls)        │
│  - Ham Güvenlik Tanımlayıcısı (nTSecurityDescriptor)        │
│  - Silinmiş Nesneler (isDeleted=TRUE / Tombstones)           │
│  - Şema ve Yapılandırma Bölümleri (Schema/Configuration)     │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Arama ve Manipülasyon:
         - RBCD: msDS-AllowedToActOnBehalfOfOtherIdentity ekleme
         - Shadow Credentials: msDS-KeyCredentialLink yazma
```

1. **Bağlantı ve Kimlik Doğrulama (Connect & Bind):** `ldp.exe`, hedef DC'nin 389 (LDAP), 636 (LDAPS), 3268 (Global Catalog) veya 3269 (GC SSL) portuna bağlanır. Kimlik doğrulama aşamasında (`Bind`) o anki Windows oturumunun Kerberos biletini (`SSPI / Currently logged on user`) kullanarak sıfır kimlik bilgisi ifşasıyla oturum açar.
2. **RootDSE İncelemesi:** Bağlantı kurulduğu an DC'nin `RootDSE` nesnesini çeker; desteklenen SASL mekanizmalarını, etki alanı kök DN yolunu (`defaultNamingContext`) ve sunucunun işlevsel düzeyini (Forest/Domain Functional Level) anında listeler.
3. **Genişletilmiş Kontroller (LDAP Controls OID):** Standart LDAP sorgularının yapamadığı özel operasyonlar için ASN.1 kodlu OID dizgilerini isteklere ekler. Örneğin `1.2.840.113556.1.4.417` kontrolü ile sistemdeki tüm silinmiş kullanıcı ve bilgisayarların geçmiş kayıtları dökülebilir.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Resource-Based Constrained Delegation (RBCD)** | Hedef bilgisayar hesabının `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine ham DACL yazarak makineyi ele geçirme. |
| **Silinmiş Nesne Avı (Tombstone Carving)** | Sistemden silinmiş eski yöneticilerin SID, grup ve öznitelik bilgilerini `Show Deleted` kontrolü ile kurtarma. |
| **Ham DACL ve Özel Hak Analizi** | Nesneler üzerindeki `DS-Replication-Get-Changes-All` (DCSync) ve `GenericAll` haklarını en düşük seviyede inceleme. |
| **Shadow Credentials Analizi** | Kullanıcı veya bilgisayar hesabında `msDS-KeyCredentialLink` (WHfB / PKINIT) anahtarlarının varlığını denetleme. |
| **Gelişmiş LDAP Filtre Testleri** | Karmaşık RFC 4515 LDAP filtrelerini canlı sistemde test ederek sonuçları satır satır doğrulama. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `ldp.exe` | `ADExplorer` | `ldapsearch (Linux)` | `ADUC (dsa.msc)` |
|---|---|---|---|---|
| **Varsayılan Bulunabilirlik** | Windows Server'da hazır, Win10'da RSAT gerekir | Harici indirme gerekir | Yalnızca Linux/Samba'da | Windows Server / RSAT |
| **Gelişmiş Kontroller (OIDs)** | Tam Destek (Menüden seçilebilir) | Kısıtlı | CLI bayraklarıyla var (`-e`) | Yok |
| **Ham DACL/Hex İnceleme** | Var (Security Descriptor dökümü) | Var (ACL Sekmesi) | Var (Base64 ASN.1) | Yalnızca Standart GUI |
| **Öznitelik Ekleme / Değiştirme** | Var (`Modify`, `Add`) | Salt-Okunur (Değiştiremez) | Var (`ldapmodify`) | Kısıtlı GUI alanları |
| **EDR Algısı** | Çok Düşük (Resmi Windows aracı) | Düşük (Sysinternals) | Windows uç noktada yok | Sıfır |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags & Menü Ağacı)

### Komut Satırı Başlatma Sözdizimi

`ldp.exe` doğrudan komut satırından hedef sunucu veya port parametreleriyle başlatılabilir:

```cmd
ldp.exe [sunucu_adı_veya_ip] [port]
```

**Örnekler:**
```cmd
:: Standart LDAP ile DC01'e bağlan
ldp.exe DC01.lab.local

:: LDAPS (SSL Port 636) ile bağlan
ldp.exe DC01.lab.local 636

:: Global Catalog (Port 3268) ile bağlan
ldp.exe DC01.lab.local 3268
```

### Operasyonel Menü Hiyerarşisi

```
ldp.exe Menü Ağacı
├── Connection (Bağlantı Yönetimi)
│   ├── Connect... (Sunucu, Port, Connectionless, SSL/TLS)
│   ├── Bind... (Currently logged on user, Simple, SSPI)
│   └── Disconnect (Bağlantıyı sonlandırma)
├── View (Görünüm Seçenekleri)
│   └── Tree... (BaseDN belirterek hiyerarşik nesne ağacını açma)
├── Browse (Arama ve Nesne Manipülasyonu)
│   ├── Search... (Filtre, Scope, Nitelikler, Controls)
│   ├── Modify... (Öznitelik ekleme, silme, güncelleme - RBCD/ShadowCreds)
│   ├── Add... / Delete... (Yeni nesne oluşturma / silme)
│   └── Security -> Descriptor... (Ham DACL/SACL dökümü)
└── Options (Gelişmiş Yapılandırma)
    ├── General... (Sayfalama ve çıktı ayarları)
    └── Controls... (LDAP OID kontrollerini aktif etme)
```

### Kritik Genişletilmiş LDAP Kontrolleri (Controls OID Tablosu)

| Kontrol Adı | OID Değeri | Operasyonel Kullanım Amacı |
|---|---|---|
| `LDAP_SERVER_SHOW_DELETED_OID` | `1.2.840.113556.1.4.417` | Silinmiş nesneleri (`isDeleted=TRUE`) ve Active Directory Çöp Kutusu'nu listeler. |
| `LDAP_SERVER_SD_FLAGS_OID` | `1.2.840.113556.1.4.801` | Nesnelerin ham güvenlik tanımlayıcılarını (`nTSecurityDescriptor` - Owner, DACL, SACL) çeker. |
| `LDAP_PAGED_RESULT_OID_STRING` | `1.2.840.113556.1.4.319` | 1000 nesnelik MaxPageSize limitini aşmak için paged search uygular. |
| `LDAP_SERVER_NOTIFICATION_OID` | `1.2.840.113556.1.4.528` | Active Directory'de yapılan değişiklikleri (yeni kullanıcı, parola değişimi) canlı izler. |
| `LDAP_SERVER_PERMISSIVE_MODIFY_OID` | `1.2.840.113556.1.4.1413` | Mevcut özniteliklere değer eklerken hata vermesini engeller (RBCD için kritik). |

---

## 3. Pratik Kullanım Senaryoları

### Senaryo 1: Active Directory'ye Bağlanma ve Mevcut Oturum ile Kimlik Doğrulama (Connect & Bind)

1. `ldp.exe` açılır.
2. Üst menüden **Connection -> Connect** seçilir:
   - `Server:` `DC01.lab.local` (veya IP adresi)
   - `Port:` `389`
   - **OK** butonuna basılır. Sağ panelde `RootDSE` bilgileri listelenir.
3. Üst menüden **Connection -> Bind** seçilir:
   - `Bind type:` **Bind as currently logged on user** (Kerberos SSPI) seçilir.
   - **OK** butonuna basılır.
4. Çıktıda şu satır doğrulanır:
   ```text
   res = ldap_bind_s(ld, NULL, &NtAuthIdentity, 1158); // v.3
   Authenticated as: 'LAB\jdoe'.
   ```

---

### Senaryo 2: Silinmiş Nesneleri Ortaya Çıkarma (Tombstone Carving)

Saldırgan veya denetçi, sistemde daha önce açılıp sonradan silinmiş yönetici veya servis hesaplarını incelemek ister:

1. **Options -> Controls** menüsüne gidilir:
   - `Load Predefined:` açılır menüsünden **Return deleted objects** seçilir (`OID: 1.2.840.113556.1.4.417`).
   - `Type:` **Server**, `Criticality:` **Checked** yapılır ve **Check In** butonuna basılarak aktif listeye eklenir. **OK** ile çıkılır.
2. **Browse -> Search** menüsüne gidilir:
   - `Base DN:` `CN=Deleted Objects,DC=lab,DC=local`
   - `Filter:` `(objectClass=*)`
   - `Scope:` **Subtree**
   - **Run** butonuna basılır.

**Örnek Çıktı Analizi:**
```text
Getting 1 entries:
Dn: CN=da_backup\0ADEL:8f1b2c3d-1234-5678-90ab-cdef01234567,CN=Deleted Objects,DC=lab,DC=local
    objectClass: top, person, organizationalPerson, user;
    sAMAccountName: da_backup;
    isDeleted: TRUE;
    objectSid: S-1-5-21-1111111111-2222222222-3333333333-1150;
    lastKnownParent: OU=Admins,DC=lab,DC=local;
```
- Silinen `da_backup` hesabının orijinal SID değeri (`1150`) ve hangi OU altında bulunduğu (`OU=Admins`) açığa çıkarılır.

---

### Senaryo 3: Bir Nesnenin Ham Güvenlik Tanımlayıcısını (DACL/SACL) Dökme

Bir kullanıcının etki alanı kök nesnesi üzerinde `DCSync` yetkisine (`DS-Replication-Get-Changes-All`) sahip olup olmadığını denetlemek:

1. **Browse -> Security -> Descriptor** menüsüne gidilir.
2. `Dn:` `DC=lab,DC=local` yazılır.
3. `SACL` ve `DACL` kutucukları işaretlenir, **OK** butonuna basılır.
4. Açılan pencerede tüm ACE (Access Control Entry) listesi ham GUID değerleriyle dökülür:
   - Eğer `Right: 0x100` (Control Access) ve `Object Type: 1131f6ad-9c07-11d1-f071-00c04fc2dcd2` (DS-Replication-Get-Changes-All) eşleşmesi görülüyorsa, ilgili kullanıcı etki alanında doğrudan DCSync çalıştırabilir!

---

### Senaryo 4: Resource-Based Constrained Delegation (RBCD) Özniteliğini İnceleme

Hedef bir sunucuya (`SRV01$`) sızıldığında, bu makine üzerinde kimlerin delegasyon hakkı olduğunu kontrol etmek:

1. **Browse -> Search** menüsünden `SRV01$` bilgisayarı bulunur.
2. Nesne detaylarında `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliği aranır.
3. Bu öznitelik ikili bir güvenlik tanımlayıcısıdır (Binary DACL). `ldp.exe` bu veriyi otomatik olarak çözerek izin verilen makine veya kullanıcının SID değerini ekranda açıkça gösterir.

---

### Senaryo 5: Sayfalı Arama (Paged Search) ile 1000 Nesne Sınırını Aşma

Active Directory varsayılan olarak tek bir LDAP sorgusunda en fazla 1000 nesne döndürür (`MaxPageSize`). Tüm kullanıcıları tek seferde dökmek için:

1. **Browse -> Search** menüsünde **Options** butonuna basılır.
2. `Search Call Type:` **Paged** seçilir.
3. `Page Size:` `1000` girilir ve **OK** denir.
4. Artık etki alanındaki 50.000 kullanıcı olsa bile sayfalama yapılarak tüm kayıtlar eksiksiz listelenir.

---

### Senaryo 6: Komut Satırından Hedef DC ve Port ile LDP Başlatma

Operatör konsoldan doğrudan hedef DC IP'si ve Global Catalog portu ile ldp başlatabilir:

```cmd
ldp.exe 192.168.1.10 3268
```

---

### Senaryo 7: PowerShell ile ldp.exe'nin Tombstone Mekanizmasını Taklit Eden Betik

`ldp.exe` GUI'sine erişim olmayan saf komut satırı oturumlarında, aynı LDAP kontrolünü (`1.2.840.113556.1.4.417`) kullanan operasyonel PowerShell betiği:

```powershell
# System.DirectoryServices.Protocols ile silinmiş nesneleri avlama:
Add-Type -AssemblyName System.DirectoryServices.Protocols

$dc = (Get-CimInstance Win32_ComputerSystem).Domain
$ldapId = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($dc)
$con = New-Object System.DirectoryServices.Protocols.LdapConnection($ldapId)
$con.Bind()

# Show Deleted OID kontrolünü oluştur
$showDeletedControl = New-Object System.DirectoryServices.Protocols.ShowDeletedControl
$request = New-Object System.DirectoryServices.Protocols.SearchRequest(
    "CN=Deleted Objects,DC=$($dc.Replace('.',',DC='))",
    "(objectClass=*)",
    [System.DirectoryServices.Protocols.SearchScope]::Subtree,
    @("sAMAccountName", "objectSid", "isDeleted", "lastKnownParent")
)
$request.Controls.Add($showDeletedControl) | Out-Null

$response = $con.SendRequest($request)
Write-Host "[+] Bulunan Silinmiş Nesneler:" -ForegroundColor Green
foreach ($entry in $response.Entries) {
    [PSCustomObject]@{
        DN             = $entry.DistinguishedName
        sAMAccountName = $entry.Attributes["sAMAccountName"][0]
        LastParent     = $entry.Attributes["lastKnownParent"][0]
    }
} | Format-Table -AutoSize
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `Cannot connect to server: Error 0x51 (Server Down)` | Belirtilen IP/FQDN ulaşılamaz durumdadır veya TCP 389 portu güvenlik duvarında engellidir. | Ağ bağlantısını doğrulayın; `Test-NetConnection <DC_IP> -Port 389` ile port erişimini test edin. |
| `ldap_bind_s failed: 0x31 (Invalid Credentials)` | Girilen parola hatalıdır veya hesap kilitlenmiştir. | Parolayı doğrulayın; SSPI (`Currently logged on user`) modunu kullanarak açık parola girmekten kaçının. |
| `ldap_search_s failed: 0x4 (Size Limit Exceeded)` | Dönen nesne sayısı 1000 sınırını aşmıştır. | **Search -> Options** menüsünden `Search Call Type` ayarını **Paged** yapın ve `Page Size: 1000` belirleyin. |
| `ldap_modify_s failed: 0x32 (Insufficient Rights / Access Denied)` | Değiştirilmek istenen öznitelik (örneğin RBCD veya SPN) üzerinde kullanıcının yazma hakkı (`WriteProperty`) yoktur. | İlgili nesnenin DACL izinlerini inceleyin; işlemi hesap üzerinde tam kontrole (`GenericAll`) sahip bir kullanıcı bağlamında yürütün. |
| `SSL connect error: 0x51 (Server Down / Untrusted Certificate)` | Port 636 ile LDAPS bağlantısı yapılırken istemci, DC'nin Sertifika Yetkilisini (CA) tanımamaktadır. | CA kök sertifikasını istemcinin `Trusted Root Certification Authorities` deposuna yükleyin veya standart port 389'u kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `ldp.exe` çalıştırılması, komut satırı argümanları (`DC01 389`) ve üst süreç bilgisi kaydedilir.
- **Etki Alanı Denetleyicisi Günlükleri (DC Logs):**
  - **Event ID 4624 (Logon Type 3 - Network):** İstemciden DC'ye LDAP kimlik doğrulaması yapıldığında ağ oturumu oluşur.
  - **Directory Service Event ID 1644 (Active Directory LDAP Query Search):** Kapsamlı alt ağaç (`Subtree`) aramaları veya sayfalı aramalar DC üzerinde LDAP filtre günlüklerine yansır.
  - **Security Event ID 4662 (Operation performed on AD object):** `ldp.exe` üzerinden bir nesnenin özniteliği (`Modify`) veya DACL'i değiştirildiğinde DC'de nesne denetim kaydı oluşur.

### 5.2 Ağ ve EDR İmzaları

- **İmzalı Windows Bileşeni:** `ldp.exe` Microsoft tarafından dijital olarak imzalanmış meşru bir Windows sistem aracıdır. Bu nedenle antivirüsler, AppLocker ve WDAC kuralları tarafından engellenmez.
- **Sıradan İstemcide Anomali:** Bir muhasebe veya insan kaynakları iş istasyonunda `ldp.exe` sürecinin başlatılması ve DC'ye doğru LDAP sorguları atması, EDR ve UEBA sistemleri için **Olağandışı Yönetim Aracı Kullanımı (Suspicious Admin Tool Execution)** alarmı oluşturur.
- **LDAPS ile Şifreleme:** Bağlantı Port 636 (LDAPS) üzerinden kurulduğunda, tüm arama filtreleri ve dönen öznitelikler TLS ile şifrelendiğinden ağ tabanlı IDS/IPS sistemleri (Snort, Suricata, Zeek) içerideki arama trafiğini göremez.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesaplarını, SPN ve kilitlenme durumlarını ham LDAP ile listeleme. |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup hiyerarşisini ve iç içe geçmiş üyelikleri inceleme. |
| **T1482** | Domain Trust Discovery | Forest ve Domain güven ilişkilerini haritalama. |
| **T1098** | Account Manipulation | RBCD (`msDS-AllowedToActOnBehalfOfOtherIdentity`) özniteliğini manipüle etme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Uç Noktada `ldp.exe` Çalıştırma Alarmı** | `ldp.exe` sürecini şüpheli uç noktalarda başlatmak yerine, yerleşik PowerShell komut dosyaları veya C# bellek içi LDAP kütüphaneleri (`System.DirectoryServices`) kullanın. |
| **Ağ Paket Denetimi (Deep Packet Inspection)** | Ağ IDS sistemlerinin arama filtrelerini incelemesini engellemek için her zaman Port 636 (LDAPS) veya Port 3269 (GC SSL) kullanın. |
| **Sayfalama Trafiği Gürültüsü** | Tüm dizini çekmek yerine, filtrelerinizi spesifik nesnelere (`sAMAccountName=target`) veya tekil OU'lara daraltın. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Ldp.exe Süreç İzleme:** İstemci makinelerinde `ldp.exe` çalıştırılmasını EDR üzerinden kurala bağlayın; yalnızca yetkili sistem yöneticisi iş istasyonlarında (PAW) çalışmasına izin verin.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Active Directory Enumeration via LDP.EXE
  status: medium
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith: '\ldp.exe'
      filter_admin_workstations:
          ComputerName|startswith: 'PAW-'
      condition: selection and not filter_admin_workstations
  ```

---

## 6. En Çok Kullanılan İşlemler ve Filtreler (Hızlı Referans / Cheat Sheet)

### 6.1 LDP'yi Doğrudan Hedef DC'ye Bağlanarak Başlatma
```cmd
ldp.exe DC01.lab.local 389
```
- **Ne Yapar?** Aracı açar ve belirtilen etki alanı denetleyicisine TCP 389 üzerinden otomatik bağlantı girişiminde bulunur.
- **Ne Zaman Kullanılır?** Hızlıca LDAP oturumu başlatıp RootDSE özniteliklerini incelemek için.
- **Parametreler:** `DC01.lab.local` (Sunucu FQDN/IP), `389` (Port).

### 6.2 Mevcut Kullanıcı İle Parolasız SSPI Bind Yapma
- **Menü:** `Connection -> Bind`
- **İşlem:** `Bind as currently logged on user` seçeneğini işaretleyip **OK**'e basın.
- **Ne Yapar?** Oturumun Kerberos biletini kullanarak açık parola girmeden güvenli kimlik doğrulaması sağlar.
- **Ne Zaman Kullanılır?** Sisteme ele geçirilen bir hesapla giriş yapıldığında şifre girmeden anında AD'ye bağlanmak için.

### 6.3 SPN Tanımlı (Kerberoastable) Hesapları Arama Filtresi
- **Menü:** `Browse -> Search`
- **Filtre:** `(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))`
- **Ne Yapar?** Üzerinde servis bileti kaydı bulunan tüm kullanıcı hesaplarını listeler.
- **Ne Zaman Kullanılır?** Kerberoasting saldırısı öncesinde bilet talep edilebilecek servis hesaplarını tespit etmek için.

### 6.4 Silinmiş Nesneleri Görme (Show Deleted Objects Control)
- **Menü:** `Options -> Controls -> Load Predefined: Return deleted objects`
- **Arama BaseDN:** `CN=Deleted Objects,DC=lab,DC=local`
- **Ne Yapar?** Active Directory Çöp Kutusu'ndaki tüm silinmiş kullanıcı ve bilgisayarları listeler.
- **Ne Zaman Kullanılır?** Eski yönetici hesaplarının SID bilgilerini veya unutulmuş özniteliklerini açığa çıkarmak için.

### 6.5 Nesnenin Ham DACL/Owner Güvenlik Tanımlayıcısını İnceleme
- **Menü:** `Browse -> Security -> Descriptor`
- **Parametre:** Hedef nesnenin DN yolu (`CN=Administrator,CN=Users,DC=lab,DC=local`).
- **Ne Yapar?** Nesnenin tüm ACE izinlerini, sahipliğini ve denetim kurallarını ham güvenlik formatında döker.
- **Ne Zaman Kullanılır?** Gizli yetki yükseltme haklarını (`GenericAll`, `WriteDacl`) doğrulamak için.

### 6.6 Sayfalı Arama (Paged Search) ile 1000 Nesne Limitini Aşma
- **Menü:** `Browse -> Search -> Options -> Search Call Type: Paged (Size: 1000)`
- **Ne Yapar?** LDAP sunucusunun varsayılan 1000 kayıt limitini sayfalama yaparak aşar ve tüm veriyi çeker.
- **Ne Zaman Kullanılır?** 10.000+ nesneye sahip kurumsal etki alanlarında eksiksiz kullanıcı dökümü almak için.

### 6.7 Global Catalog (Port 3268) ile Orman Çapında Kullanıcı Arama
```cmd
ldp.exe ForestRootDC01.corp.local 3268
```
- **Ne Yapar?** Global Catalog portuna bağlanarak ormandaki tüm etki alanlarının özet nesne veritabanını sorgular.
- **Ne Zaman Kullanılır?** Çoklu etki alanı (multi-domain forest) yapılarında diğer child domain kullanıcılarını bulmak için.

### 6.8 Unconstrained Delegation Bilgisayarlarını Filtreleme
- **Menü:** `Browse -> Search`
- **Filtre:** `(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))`
- **Ne Yapar?** Sınırsız delegasyon yetkisine sahip tüm bilgisayar ve sunucu hesaplarını listeler.
- **Ne Zaman Kullanılır?** TGT kaçırma ve yetki yükseltme operasyonlarında hedef belirlemek için.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — ldp command reference | [learn.microsoft.com](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc771022(v=ws.11)) |
| RFC 4511: Lightweight Directory Access Protocol (LDAP) | [datatracker.ietf.org](https://datatracker.ietf.org/doc/html/rfc4511) |
| Microsoft Open Specifications — MS-ADTS (Extended Controls) | [learn.microsoft.com](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/) |
| MITRE ATT&CK T1087.002 (Account Discovery: Domain Account) | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |

---

> **Önceki:** [← ADExplorer](./ADExplorer.md) · **Sonraki:** [ProcDump →](./ProcDump.md)
