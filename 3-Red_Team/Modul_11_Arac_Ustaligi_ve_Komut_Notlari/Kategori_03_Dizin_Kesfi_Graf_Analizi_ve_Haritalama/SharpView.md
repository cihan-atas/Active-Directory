# SharpView

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Kevin Robertson (@NetSPI) tarafından geliştirilen; PowerView.ps1 betiğinin bağımsız C# (.NET) ortamına aktarılmış hali olup, PowerShell kısıtlamalarını (CLM), betik günlüğünü (Script Block Logging) ve AMSI kontrollerini aşarak bellek içi (in-memory) etki alanı keşfi sağlayan saldırı aracı.

---

## 1. Genel Bakış ve Amaç

**SharpView**, kırmızı takım operasyonlarında devrim yaratan PowerView.ps1 kütüphanesinin saf C# (.NET Framework 4.5/4.7.2) ile yeniden yazılmış derlenmiş (compiled) ikili (binary) versiyonudur. PowerShell tabanlı keşif araçlarının modern kurumsal ağlarda Antimalware Scan Interface (AMSI), Constrained Language Mode (CLM), Script Block Logging (Event ID 4104) ve Transcription Logging mekanizmaları tarafından anında engellenmesi, operatörleri derlenmiş .NET ikililerine yöneltmiştir.

SharpView; Cobalt Strike, Havoc, Sliver, Mythic ve Covenant gibi modern Komuta ve Kontrol (C2) çerçevelerinin `execute-assembly` yeteneğiyle mükemmel uyum sağlar. Bu sayede hedef makinenin sabit diskine hiçbir `.ps1` veya `.exe` dosyası yazılmadan, `powershell.exe` süreci başlatılmadan ve `System.Management.Automation` kütüphanesine dokunulmadan, yalnızca bellek içinde geçici bir süreç açılarak (fork & run) etki alanı keşfi icra edilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                             SHARPVIEW ÇALIŞMA MİMARİSİ                            |
+-----------------------------------------------------------------------------------+
                                          |
                      [Saldırgan C2 Sunucusu / Operatör]
                         execute-assembly SharpView.exe
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|               Kurban Sistem (Bellek İçi - In-Memory Execution)                   |
|                                                                                   |
|  [Meşru Kurban Süreç: örn. werfault.exe / svchost.exe]                            |
|       |                                                                           |
|       +---- Unmanaged CLR Host (clr.dll) Başlatılır                               |
|       +---- SharpView.exe Assembly'si Belleğe Enjekte Edilir                     |
|       +---- PowerShell motoru YOK! ScriptBlock Logging (4104) YOK!               |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                                SharpView Çekirdeği                                |
+-----------------------------------------------------------------------------------+
        |                                 |                                 |
        v                                 v                                 v
[System.DirectoryServices]      [Netapi32.dll (P/Invoke)]      [ActiveDirectory (SDDL)]
- LDAP Binds & Search           - NetSessionEnum               - Object ACE/ACL Parsing
- DirectorySearcher             - NetWkstaUserEnum             - GUID Resolution
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

### PowerView ve SharpView Fonksiyon Eşleştirme Haritası

| PowerView Cmdlet Karşılığı | SharpView CLI Çağrısı | Protokol / API |
|---|---|---|
| `Get-Domain` | `SharpView.exe Get-Domain` | LDAP (RootDSE) |
| `Get-DomainController` | `SharpView.exe Get-DomainController` | LDAP / NetrServerGetInfo |
| `Get-DomainUser` | `SharpView.exe Get-DomainUser` | LDAP DirectorySearcher |
| `Get-DomainComputer` | `SharpView.exe Get-DomainComputer` | LDAP DirectorySearcher |
| `Get-DomainGroup` | `SharpView.exe Get-DomainGroup` | LDAP DirectorySearcher |
| `Get-DomainGroupMember` | `SharpView.exe Get-DomainGroupMember -Identity <Grup>` | LDAP / TokenGroups |
| `Get-DomainOU` | `SharpView.exe Get-DomainOU` | LDAP DirectorySearcher |
| `Get-DomainGPO` | `SharpView.exe Get-DomainGPO` | LDAP (CN=Policies) |
| `Get-DomainObjectAcl` | `SharpView.exe Get-DomainObjectAcl -Identity <Nesne>` | LDAP (nTSecurityDescriptor) |
| `Find-LocalAdminAccess` | `SharpView.exe Find-LocalAdminAccess` | SMB (OpenSCManagerW) |
| `Invoke-UserHunter` | `SharpView.exe Invoke-UserHunter` | SMB / NetSessionEnum |
| `Get-DomainTrust` | `SharpView.exe Get-DomainTrust` | LDAP (trustedDomain) |

### Neden Önemli?

| Operasyonel Avantaj | Teknik Açıklama | Savunma Atlatma Boyutu |
|---|---|---|
| **Sıfır Disk İzi (Zero-Disk)** | C2 üzerinden belleğe enjekte edilir, diske yazılmaz. | Statik disk tarayıcıları ve dosya bütünlük denetleyicilerini (FIM) atlatır. |
| **PowerShell İzlerini Önleme** | `powershell.exe` sürecini veya runspace'i kullanmaz. | Event ID 4104 (Script Block) ve 4103 (Module Logging) logları üretilmez. |
| **CLM & AppLocker Bypass** | Constrained Language Mode kısıtlamalarına tabi değildir. | Kısıtlı PowerShell ortamlarında dahi sınırsız .NET API çağrısı yapar. |
| **Boru Hattı Sözdizimi Uyumu** | PowerView cmdlet argüman yapısını (`Get-DomainUser -SPN`) birebir korur. | Operatörün komut ezberleme veya yeni sözdizimi öğrenme ihtiyacını ortadan kaldırır. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | SharpView.exe | PowerView.ps1 | pywerview | AdFind.exe | SharpHound.exe |
|---|---|---|---|---|---|
| **Çalışma Ortamı** | .NET CLR / C# | PowerShell | Linux / Python | Win32 C++ | .NET CLR / C# |
| **C2 Execute-Assembly** | Tam Uyumlu | Desteklemez | Desteklemez | PE Yükleyici Gerekir | Tam Uyumlu |
| **Script Block Log (4104)**| **Üretmez** | **Üretir** | Üretmez | Üretmez | **Üretmez** |
| **AMSI Tetikleme** | Düşük (.NET AMSI) | Çok Yüksek | Sıfır | Sıfır | Orta |
| **Odak Noktası** | Hedefli Sorgulama | Hedefli Sorgulama | Uzaktan Sorgu | Dizin Arama | Kitlesel Graf Toplama |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SharpView, PowerView'ın komut satırı arabirimini birebir simüle eden bir argüman ayrıştırıcısına (parser) sahiptir. İlk parametre her zaman çalıştırılacak **PowerView fonksiyonunun adı** olmalıdır:

```cmd
SharpView.exe [Metot / Fonksiyon Adı] [Parametreler]
```

### Sık Kullanılan Parametreler Tablosu

| Parametre | Açıklama | Varsayılan | Örnek Kullanım |
|---|---|---|---|
| `-Identity` | Hedef nesnenin sAMAccountName, DN veya GUID değeri. | Tüm Nesneler | `-Identity "da_mehmet"` |
| `-Domain` | Mevcut etki alanı dışındaki hedef etki alanı adı. | Mevcut Domain | `-Domain "sub.corp.local"` |
| `-Server` | Belirli bir Etki Alanı Denetleyicisi IP'si veya FQDN'i. | Otomatik | `-Server "192.168.1.10"` |
| `-Credential` | Farklı kimlik bilgisiyle sorgulamak için `domain\user:pass`. | Mevcut Token | `-Credential "corp\ali:Parola123"` |
| `-Filter` | Dahili nesne filtreleme dizisi. | Boş | `-Filter "admincount=1"` |
| `-LDAPFilter` | Sunucu taraflı çalışacak ham LDAP filtresi. | Boş | `-LDAPFilter "(servicePrincipalName=*)"` |
| `-Properties` | Sadece listelenmek istenen öznitelikler (virgülle ayrılmış). | Tüm Öznitelikler | `-Properties "samaccountname,mail"` |
| `-SearchBase` | LDAP aramasının başlayacağı kök OU yolu (Distinguished Name). | Domain Root | `-SearchBase "OU=Users,DC=lab,DC=local"` |
| `-SearchScope` | Arama derinliği (`Base`, `OneLevel`, `Subtree`). | `Subtree` | `-SearchScope "OneLevel"` |
| `-SPN` | Sadece SPN tanımlı kullanıcıları getiren anahtar bayrak. | Kapalı | `-SPN` |
| `-PreauthNotRequired`| AS-REP Roasting'e açık hesapları getiren anahtar bayrak. | Kapalı | `-PreauthNotRequired` |
| `-AdminCount` | Yalnızca `adminCount=1` olan korumalı hesapları filtreler. | Kapalı | `-AdminCount` |
| `-TrustedToAuth` | Kısıtlı delegasyon (Constrained Delegation) bayraklı hesaplar. | Kapalı | `-TrustedToAuth` |
| `-Unconstrained` | Sınırsız delegasyonlu (Unconstrained) bilgisayarları filtreler. | Kapalı | `-Unconstrained` |
| `-ResolveGUIDs` | ACL GUID değerlerini insan okunabilir haklara dönüştürür. | Kapalı | `-ResolveGUIDs` |
| `-SecurityIdentifier`| Yalnızca belirli bir SID'ye ait ACL izinlerini filtreler. | Tümü | `-SecurityIdentifier "S-1-5-21-..."` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: C2 Üzerinden In-Memory (Bellek İçi) SPN ve AS-REP Keşfi

Cobalt Strike veya Sliver C2 oturumunda hiçbir dosya diske bırakılmadan Kerberoast ve AS-REP Roast hedeflerinin belirlenmesi:

```text
# Cobalt Strike Beacon konsolunda:
beacon> execute-assembly /opt/tools/SharpView.exe Get-DomainUser -SPN -Properties samaccountname,serviceprincipalname

beacon> execute-assembly /opt/tools/SharpView.exe Get-DomainUser -PreauthNotRequired -Properties samaccountname
```

**Konsol Çıktısı Analizi:**
```text
[*] Tasked beacon to run .NET assembly: SharpView.exe Get-DomainUser -SPN -Properties samaccountname,serviceprincipalname
[+] host called home, sent: 184320 bytes
[+] received output:
samaccountname        : svc_mssql
serviceprincipalname  : {MSSQLSvc/sql01.corp.local:1433, MSSQLSvc/sql01.corp.local}

samaccountname        : svc_backup
serviceprincipalname  : {VeeamBackup/vbr01.corp.local}
```
*Analiz: Diske hiçbir iz bırakılmadan iki adet servis hesabı tespit edilmiştir. Bu hesaplara ait TGS biletleri bellekten `Rubeus.exe kerberoast` çağrısıyla çekilebilir.*

---

### Senaryo 2: Yerel Yönetici Yetkisi Olan Makinelerin Tespiti

Mevcut kullanıcının etki alanındaki hangi sistemlerde Administrative yetkilere sahip olduğunu saptama:

```cmd
SharpView.exe Find-LocalAdminAccess -Domain "corp.local"
```

**Konsol Çıktısı:**
```text
[+] Local admin access detected on: PC-FINANS-04.corp.local
[+] Local admin access detected on: DEV-SRV-02.corp.local
[*] Tested 142 total hosts, found local administrator access on 2 systems.
```

---

### Senaryo 3: Domain Admins Grubu Üzerindeki Tehlikeli ACL'lerin Çözümlenmesi

Yetki yükseltme yollarını keşfetmek amacıyla Domain Admins grubu üzerinde kimlerin `GenericAll` veya `WriteDacl` hakkına sahip olduğunu bulma:

```cmd
SharpView.exe Get-DomainObjectAcl -Identity "Domain Admins" -ResolveGUIDs
```

**Konsol Çıktısı Analizi:**
```text
ObjectAceType          : 
ActiveDirectoryRights  : GenericAll
SecurityIdentifier     : S-1-5-21-123456789-1002
IdentityReferenceName  : IT-Helpdesk-Leads
AceQualifier           : AccessAllowed
```
*Analiz: `IT-Helpdesk-Leads` grubu Domain Admins nesnesi üzerinde `GenericAll` (Tam Denetim) hakkına sahiptir. Bu gruba üye olan herhangi bir kullanıcı, Domain Admins grubuna doğrudan üye ekleyebilir.*

---

### Senaryo 4: Kısıtlamasız Kerberos Delegasyonu (Unconstrained Delegation) Tespiti

Etki Alanı Denetleyicileri dışındaki Unconstrained Delegation yetkisine sahip sunucuların belirlenmesi:

```cmd
SharpView.exe Get-DomainComputer -Unconstrained -Properties samaccountname,dnshostname
```

---

### Senaryo 5: Etki Alanı Yöneticisi Oturumlarını Haritalama (User Hunting)

Domain Admin hesaplarının hangi iş istasyonlarında aktif olduğunu ve operatörün bu makinelere erişimi olup olmadığını tespit etme:

```cmd
SharpView.exe Invoke-UserHunter -CheckAccess -TargetGroupName "Domain Admins"
```

---

### Senaryo 6: Kısıtlı Delegasyon (Constrained Delegation) ve Protokol Geçişi Keşfi

S4U2Self ve S4U2Proxy suistimali ile herhangi bir etki alanı yöneticisi adına sahte bilet üretebilecek hesapların ve hedef servislerin tespiti:

```cmd
SharpView.exe Get-DomainUser -TrustedToAuth -Properties samaccountname,msds-allowedtodelegateto
```

---

### Senaryo 7: LAPS (Local Administrator Password Solution) Parolalarını Sorgulama

Mevcut kullanıcının okuma yetkisi olan bilgisayarların yerel yönetici parolalarını (`ms-Mcs-AdmPwd`) LDAP üzerinden çekme:

```cmd
SharpView.exe Get-DomainComputer -Properties samaccountname,ms-mcs-admpwd
```

---

### Senaryo 8: GPO ve OU Eşleştirmesi ile Yetki Analizi

Etki alanında uygulanan Grup İlkelerini ve hangi OU'lara bağlandıklarını haritalama:

```cmd
SharpView.exe Get-DomainGPO -Properties displayname,gpcfilesyspath
```
*Analiz:* GPO SYSVOL yolları tespit edilir; bu yollara yazma hakkı olan kullanıcılar hedef bilgisayarlara komut enjekte edebilir.

---

### Senaryo 9: Özel LDAP Filtresi ile Exchange Servis Hesaplarını Avlama

Standart filtreler yetersiz kaldığında ham LDAP filtresi ile hassas Exchange hesaplarını listeleme:

```cmd
SharpView.exe Get-DomainUser -LDAPFilter "(&(objectCategory=user)(servicePrincipalName=*exchange*))" -Properties samaccountname,serviceprincipalname
```

---

### Senaryo 10: Farklı Kimlik Bilgisi ile Çapraz Etki Alanı Keşfi

Ele geçirilen bir kullanıcının kimlik bilgileriyle güven ilişkisi olan komşu etki alanını sorgulama:

```cmd
SharpView.exe Get-DomainUser -Domain "partner.corp" -Credential "partner.corp\ahmet:Parola2026!" -Properties samaccountname
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Could not load file or assembly 'System.DirectoryServices.Protocols'` | Hedef sistemde eski .NET Framework (örneğin 3.5) yüklü veya derleme hedefi (.NET 4.5/4.7) sistemle uyumsuz. | SharpView'ı hedef sistemin yüklü .NET sürümüne göre (tercihen .NET Framework 3.5 veya 4.0) derleyin. |
| `Execute-assembly: Output exceeds buffer / Task timed out` | Sorgu sonucunda dönen çıktı boyutu C2 framework'ünün maksimum boru hattı (pipe) sınırını aştı. | `-Properties` parametresiyle sadece ilgilendiğiniz öznitelikleri isteyin veya `-SearchBase` ile aramayı daraltın. |
| `System.DirectoryServices.DirectoryServicesCOMException: The server is not operational` | İstemci makine DC ile iletişim kuramıyor veya DNS sunucusu etki alanı denetleyicisini çözemiyor. | `-Server <DC_IP_ADRESI>` parametresiyle doğrudan DC IP adresini belirtin. |
| `Access is denied (NetSessionEnum / Win32Exception 5)` | Windows 10/Server 2016+ sürümlerinde uzaktan oturum sorgulama (NetSessionEnum) standart kullanıcılara engellidir. | Oturum avcılığı yerine LDAP tabanlı sorgulamalara odaklanın veya yerel yönetici olunan host'larda deneyin. |
| `Antivirus / Defender: Program:Win32/SharpView detected in memory` | Bellek içi tarama yapan modern EDR/AV çözümleri (AMSI for .NET), SharpView'ın bilinen string ve metot imzalarını yakaladı. | SharpView kaynak kodundaki namespace, class ve metot adlarını string obfuscation araçlarıyla (ConfuserEx vb.) karıştırın veya bellek içi AMSI yamalama uygulayın. |
| `Exception: The specified domain either does not exist or could not be contacted` | Yanlış `-Domain` argümanı girildi veya çapraz orman (cross-forest) güveninde DNS çözümlemesi eksik. | FQDN formatını kontrol edin (`corp.local`). Çapraz domainlerde Global Catalog (`:3268`) portunu kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **İşlem Enjeksiyonu ve Fork & Run (Sysmon Event ID 8 & Event ID 10):**
   - C2 çerçeveleri `execute-assembly` çalıştırırken varsayılan olarak geçici bir süreç (örneğin `rundll32.exe`, `werfault.exe` veya `notepad.exe`) başlatır ve bu sürecin belleğine SharpView kodunu enjekte eder.
2. **.NET CLR Yüklenme Olayları (Sysmon Event ID 7):**
   - Normal şartlarda .NET kullanmayan bir süreç (örneğin `rundll32.exe`) aniden `clr.dll` ve `mscorlib.dll` yüklediğinde EDR alarmları tetiklenir.
3. **Windows Security Event ID 4624 (Logon Type 3):**
   - `Find-LocalAdminAccess` ve `Invoke-UserHunter` çalıştırıldığında ağdaki onlarca sisteme kısa sürede RPC/SMB üzerinden Type 3 oturum açılır.
4. **ETW (Event Tracing for Windows) - Microsoft-Windows-DotNETRuntime:**
   - .NET çalışma zamanı, belleğe yüklenen assembly'nin adını (`SharpView`) ETW tüketicilerine bildirir.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Trafiği:** DC'ye yapılan yoğun LDAP bind ve search istekleri.
- **RPC Çağrıları:** `\PIPE\srvsvc` ve `\PIPE\wkssvc` üzerinden yapılan `NetSessionEnum` çağrıları.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | SharpView Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `Get-DomainUser`, `Get-DomainUser -SPN` |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `Get-DomainGroup`, `Get-DomainGroupMember` |
| **T1018** | Remote System Discovery | `Get-DomainComputer`, `Find-LocalAdminAccess` |
| **T1033** | System Owner/User Discovery | `Invoke-UserHunter` |
| **T1055.001** | Process Injection: Dynamic-link Library Injection | C2 `execute-assembly` mimarisiyle CLR yükleme |
| **T1482** | Domain Trust Discovery | `Get-DomainTrust` |

### 5.4 OPSEC Önerileri

| Risk | Tespit Mekanizması | OPSEC Azaltma Yöntemi |
|---|---|---|
| **Süreç Başlatma Anomalisı** | `rundll32.exe` içerisine .NET enjeksiyonu. | C2 profilinde `spawnto` ayarını meşru bir .NET ikilisine (örneğin `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe`) yönlendirin. |
| **ETW .NET İzleri** | ETW üzerinden `SharpView` assembly isminin loglanması. | Assembly çalıştırmadan önce `ntdll!EtwEventWrite` fonksiyonunu bellekten yamalayın (ETW Patching). |
| **Geniş Ağ Taraması** | `Find-LocalAdminAccess` ile tüm ağın taranması. | Ağ geneline tarama yapmayın; LDAP üzerinden `ms-Mcs-AdmPwd` veya GPO izinlerini analiz ederek hedefli hareket edin. |
| **Binary İmzası** | Standart NetSPI derlemesinin bilinen hash'i. | Kodları kendi ortamınızda yeniden derleyin, stringleri şifreleyin ve metot isimlerini değiştirin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (KQL — Microsoft Defender for Endpoint)
```kql
// .NET kullanmaması gereken meşru Windows süreçlerinde clr.dll yüklenmesi tespiti
DeviceImageLoadEvents
| where InitiatingProcessFileName in~ ("rundll32.exe", "svchost.exe", "werfault.exe", "notepad.exe", "calc.exe")
| where FileName in~ ("clr.dll", "mscorwks.dll", "clrjit.dll")
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessCommandLine, FileName, FolderPath
```

#### Tespit Kuralı (Sigma — Şüpheli .NET Yüklenmesi)
```yaml
title: Suspicious .NET CLR Loading in Non-DotNet Process
status: high
logsource:
    category: image_load
    product: windows
detection:
    selection:
        Image|endswith:
            - '\rundll32.exe'
            - '\notepad.exe'
            - '\werfault.exe'
        ImageLoaded|endswith:
            - '\clr.dll'
            - '\mscoree.dll'
    condition: selection
level: high
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. SPN Tanımlı (Kerberoastable) Hesapları Keşfetme
SharpView.exe Get-DomainUser -SPN -Properties samaccountname,serviceprincipalname
```
- **Ne Yapar?** Servis biletleri çevrimdışı kırılabilecek tüm kullanıcı hesaplarını listeler.
- **Ne Zaman Kullanılır?** İlk erişim sonrası parola kırma saldırısı için hedef belirlerken.
- **Parametreler:** `-SPN` yalnızca SPN'i olanları seçer; `-Properties` gereksiz alanları gizler.

```cmd
# 2. AS-REP Roasting Açık Hesapları Bulma
SharpView.exe Get-DomainUser -PreauthNotRequired -Properties samaccountname
```
- **Ne Yapar?** Ön kimlik doğrulaması kapatılmış hesapları döker.
- **Ne Zaman Kullanılır?** Parola bilinmeden Kerberos AS-REP hash'i yakalamak istendiğinde.
- **Parametreler:** `-PreauthNotRequired` UAC bayrağını sorgular.

```cmd
# 3. Mevcut Kullanıcının Yerel Yönetici Olduğu Sistemleri Tarama
SharpView.exe Find-LocalAdminAccess
```
- **Ne Yapar?** Ağdaki sistemleri kontrol ederek operatörün Administrative haklara sahip olduğu makineleri bulur.
- **Ne Zaman Kullanılır?** Yatay hareket (lateral movement) için güvenli geçiş noktası seçerken.
- **Parametreler:** Argümansız kullanım tüm aktif etki alanı bilgisayarlarını test eder.

```cmd
# 4. Domain Admins Grubu Üyelerini Listeleme
SharpView.exe Get-DomainGroupMember -Identity "Domain Admins" -Properties MemberName
```
- **Ne Yapar?** Etki alanı yöneticisi grubundaki kullanıcı ve alt grupları listeler.
- **Ne Zaman Kullanılır?** Saldırı hedefindeki kilit yönetici hesaplarını saptamak için.
- **Parametreler:** `-Identity` hedef grup adı; `-Properties` üye isimlerini filtreler.

```cmd
# 5. Domain Admins Üzerindeki Hassas ACL İzinlerini Bulma
SharpView.exe Get-DomainObjectAcl -Identity "Domain Admins" -ResolveGUIDs
```
- **Ne Yapar?** Yüksek yetkili grup üzerindeki `GenericAll`, `WriteDacl` veya `WriteOwner` izinlerini görüntüler.
- **Ne Zaman Kullanılır?** Yetki yükseltme (privilege escalation) zinciri kurgularken.
- **Parametreler:** `-ResolveGUIDs` GUID kimliklerini okunabilir metne dönüştürür.

```cmd
# 6. Unconstrained Kerberos Delegasyonuna Sahip Makineleri Bulma
SharpView.exe Get-DomainComputer -Unconstrained -Properties samaccountname,dnshostname
```
- **Ne Yapar?** TGT biletlerini bellekte saklayan kısıtlamasız delegasyonlu sunucuları bulur.
- **Ne Zaman Kullanılır?** Coerced authentication (zorlamalı kimlik doğrulama) ile DC hesabı ele geçirme aşamasında.
- **Parametreler:** `-Unconstrained` ilgili Active Directory bayrağını filtreler.

```cmd
# 7. Etki Alanı Güven İlişkilerini Listeleme
SharpView.exe Get-DomainTrust
```
- **Ne Yapar?** Mevcut etki alanının bağlı olduğu tüm güven (trust) ilişkilerini ve güven yönlerini döker.
- **Ne Zaman Kullanılır?** Çocuk etki alanından (child domain) orman köküne (forest root) geçiş yolları ararken.
- **Parametreler:** Standart parametre mevcut etki alanının tüm ilişkilerini getirir.

```cmd
# 8. Belirli Bir OU İçindeki Bilgisayarları Sorgulama
SharpView.exe Get-DomainComputer -SearchBase "OU=Servers,DC=corp,DC=local"
```
- **Ne Yapar?** Yalnızca belirtilen Organizasyonel Birim altındaki sunucuları listeler.
- **Ne Zaman Kullanılır?** Tüm ağı taramadan yalnızca sunucu havuzunda hedefli keşif yaparken.
- **Parametreler:** `-SearchBase` LDAP sorgu kökünü belirler.

```cmd
# 9. LAPS Yönetici Parolalarını (ms-Mcs-AdmPwd) Okuma
SharpView.exe Get-DomainComputer -Properties samaccountname,ms-mcs-admpwd
```
- **Ne Yapar?** LAPS ile yönetilen iş istasyonlarının yerel Administrator açık metin parolasını LDAP üzerinden çeker.
- **Ne Zaman Kullanılır?** Düşük yetkili bir hesapla yetki yükseltme ve yatay hareket fırsatları araştırırken.
- **Parametreler:** `-Properties` yalnızca bilgisayar adı ve LAPS parola alanını getirir.

```cmd
# 10. S4U Protokol Geçişine (Constrained Delegation) İzinli Hesapları Bulma
SharpView.exe Get-DomainUser -TrustedToAuth -Properties samaccountname,msds-allowedtodelegateto
```
- **Ne Yapar?** Ön kimlik doğrulamasız kullanıcı adına TGS bileti talep edebilen kısıtlı delegasyonlu hesapları listeler.
- **Ne Zaman Kullanılır?** S4U2Self ve S4U2Proxy saldırı zinciri hazırlarken.
- **Parametreler:** `-TrustedToAuth` kısıtlı delegasyon bayrağı açık olanları filtreler.

```cmd
# 11. Belirli bir kullanıcı üzerindeki WriteOwner ve GenericAll haklarını arama
SharpView.exe Get-DomainObjectAcl -Identity "da_ali" -ResolveGUIDs | findstr /i "GenericAll WriteDacl WriteOwner"
```
- **Ne Yapar?:** Hedef etki alanı yöneticisinin hesabı üzerinde tehlikeli haklara sahip nesneleri listeler.
- **Ne Zaman Kullanılır?:** Hedef kullanıcıyı ele geçirmek için ACL suistimali araştırırken.
- **Parametreler:** `findstr` ile kritik hakları filtreler.

```cmd
# 12. Korumalı Ayrıcalıklı Hesapları (adminCount=1) Listeleme
SharpView.exe Get-DomainUser -AdminCount -Properties samaccountname,memberof
```
- **Ne Yapar?:** AdminSDHolder koruması altındaki tüm yüksek ayrıcalıklı hesapları döker.
- **Ne Zaman Kullanılır?:** Etki alanındaki gerçek yönetici ve servis hesaplarını izole etmek için.
- **Parametreler:** `-AdminCount`.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [NetSPI / SharpView](https://github.com/NetSPI/SharpView)
- **NetSPI Güvenlik Blogu:** [NetSPI Active Directory Reconnaissance Research](https://www.netspi.com/blog/)
- **PowerView Orijinal Kütüphanesi:** [PowerShellMafia / PowerSploit](https://github.com/PowerShellMafia/PowerSploit)
- **MITRE ATT&CK Bilgi Bankası:** [Technique T1087 - Account Discovery](https://attack.mitre.org/techniques/T1087/)

---

> **Önceki:** [← PowerView.ps1](./PowerView.md) · **Sonraki:** [pywerview →](./pywerview.md)
