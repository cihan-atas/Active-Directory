# Grouper2

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory SYSVOL paylaşımındaki Group Policy Object (GPO) yapılandırmalarını derinlemesine ayrıştırarak güvenlik açığı oluşturan ayarları, yetki devri hatalarını ve gömülü parolaları otomatik puanlayan C# (.NET) aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında etki alanı politikaları (`GPO`), tüm sunucu ve iş istasyonlarının güvenlik yapılandırmasını, yerel kullanıcı haklarını, denetim kurallarını ve oturum açma betiklerini belirleyen en kritik yönetim mekanizmasıdır. Ancak kurumsal ağlarda yıllar içinde biriken yüzlerce karmaşık GPO, sistem yöneticilerinin farkında olmadan oluşturduğu yetki yükseltme (privilege escalation) açıklarına, zayıf erişim izinlerine ve unutulmuş şifrelere ev sahipliği yapar.

Geleneksel araçlar (`Get-GPPPassword` vb.) yalnızca Group Policy Preferences altındaki `cpassword` dizelerini ararken; **Grouper2** (Mike Loss / @mikeloss tarafından C# ile geliştirilmiştir), etki alanındaki tüm GPO altyapısını bütünsel olarak denetleyen yeni nesil bir analiz motorudur. Araç:
* `Registry.pol` ikili kayıt defteri ilke dosyalarını,
* `GptTmpl.inf` güvenlik şablonlarını,
* `Groups.xml`, `Services.xml`, `ScheduledTasks.xml` tercih dosyalarını,
* Başlatma/kapatma ve oturum açma/kapatma betiklerini (`.bat`, `.ps1`, `.vbs`)
derinlemesine inceler.

Bulguları önem derecesine göre 4 farklı seviyede puanlar:
* **Level 1 (Bilgi/İlginç):** Temel yapılandırma tercihleri.
* **Level 2 (Dikkat Çekici):** İncelenmeye değer güvenlik gevşetmeleri.
* **Level 3 (Yüksek Risk):** Yetki yükseltmeye veya zafiyete yol açabilecek ayarlar.
* **Level 4 (Kritik / Defcon 1):** Açık parolalar, yerel yönetici eklemeleri veya kritik hak devirleri.

C# tabanlı olması sayesinde Cobalt Strike veya modern C2 altyapılarında `execute-assembly` ile doğrudan bellek içinde koşturulabilir; diske dosya yazmaz ve PowerShell Script Block loglarını tetiklemez.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              GROUPER2 MIMARI AKIŞI                                |
+-----------------------------------------------------------------------------------+
  [Denetçi / C2 Beacon]                              [Domain Controller (DC)]
   (Grouper2.exe / CLR)                                 (SYSVOL Paylaşımı)
            |                                                   |
            |--- 1. SMB Bağlantısı (Port 445: \\DOMAIN\SYSVOL)->|
            |       [Kimliği Doğrulanmış Okuma Erişimi]         |
            |                                                   |--- 2. Policies Klasörü
            |--- 2. Özyinelemeli İlke Dosyaları İndirilir ----->|       Taranır
            |       (*.pol, *.inf, *.xml, *.bat, *.ps1)         |
            |<-- 3. GPO Yapılandırma Dosyaları Belleğe Akar ----|
            |
  [Grouper2 Bellek İçi Ayrıştırma Motoru]
  ├── Registry.pol Parser -> UAC, Defender, LAPS Devre Dışı Bırakma Bulguları
  ├── GptTmpl.inf Parser  -> User Rights Assignment (SeDebug, SeImpersonate)
  ├── XML Preferences     -> cpassword ve Yerel Administrator Atamaları
  └── Script Analyzer     -> Gömülü Parolalar ve Ağ Paylaşımı Referansları
            |
            v
  [Zafiyet Puanlama ve Raporlama]
  ├── [Level 4] GPP Password Found in Groups.xml!
  ├── [Level 4] Domain Users added to Local Administrators!
  └── [Level 3] SeDebugPrivilege granted to Service Accounts!
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Geniş Kapsamlı GPO Analizi**| Yalnızca GPP değil; inf, pol ve betik dosyalarını inceler. | Çok katmanlı hak yükseltme vektörlerini tek seferde yakalar. |
| **Zafiyet Puanlama Motoru** | Bulguları Level 1'den Level 4'e filtreleyerek sıralar. | Yüzlerce GPO arasında kritik açıkları anında öne çıkarır. |
| **Bellekte Yürütme (C2)** | `execute-assembly` ile RAM'de dosyasız çalışır. | EDR dosya taramalarını ve PowerShell loglarını (4104) atlatır. |
| **Çok Formatlı Raporlama** | HTML, JSON ve konsol çıktıları üretir. | Operasyonel analiz ve müşteri raporlamasını hızlandırır. |
| **Çevrimdışı İnceleme** | Yerel klasörü (`-g`) ağa bağlanmadan analiz eder. | Canlı ağda SMB trafiği oluşturmaktan kaçınmayı sağlar. |

### Karşılaştırma Tablosu

| Özellik | Grouper2 | Get-GPPPassword | SharpGPOAbuse | StandIn |
| :--- | :--- | :--- | :--- | :--- |
| **Geliştirme Dili** | C# (.NET Framework) | PowerShell | C# (.NET Framework) | C# (.NET Framework) |
| **Temel Görevi** | Salt Okunur GPO Zafiyet Analizi| Yalnızca GPP cpassword Taraması| GPO Değiştirme (Yazma İstismarı)| AD ve GPO Nesne Denetimi |
| **Tespit Kapsamı** | Parolalar, Haklar, Registry, Betikler| Yalnızca cpassword XML'leri | Yazma izni olan GPO'lar | LDAP ACL ve GPO Özellikleri |
| **Değişiklik Yapar mı?** | Hayır (Tamamen güvenli okuma) | Hayır (Salt okuma) | Evet (GPO üzerine zararlı kod yazar)| Opsiyonel |
| **Bellek Yürütme** | Evet (`execute-assembly`) | Evet (IEX / Dot-source) | Evet (`execute-assembly`) | Evet (`execute-assembly`) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Grouper2 komut satırından hedef etki alanı, yerel yol ve çıktı filtreleme parametreleriyle koşturulur:

```cmd
Grouper2.exe -g <SYSVOL_Yolu> [-l <Seviye>] [-f <Format>] [-s]
```

### Desteklenen Kritik Bayraklar

| Parametre | Uzun Adı | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `-g` | `--gpodir` | Taranacak yerel veya uzak SYSVOL/Policies dizini. | `-g \\corp.local\sysvol\corp.local\Policies` |
| `-d` | `--domain` | Taranacak hedef etki alanının FQDN adı. | `-d corp.local` |
| `-l` | `--level` | Gösterilecek minimum zafiyet seviyesi (1-4, Varsayılan: 3). | `-l 3` veya `-l 4` |
| `-f` | `--format` | Çıktı formatı türü (Varsayılan: text). | `-f html` veya `-f json` |
| `-s` | `--save` | Sonuçları ekrana basmak yerine belirtilen dosyaya kaydeder. | `-s report.html` |
| `-v` | `--verbose` | Ayrıştırma süreçlerini ve taranan tüm dosyaları detaylandırır. | Bayrak |
| `-h` | `--help` | Yardım menüsünü ve parametre listesini görüntüler. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Varsayılan SYSVOL Yolunda Yüksek ve Kritik Seviye (Level 3+) Taraması
Mevcut etki alanında yalnızca operatörün ilgisini çekecek yüksek riskli zafiyetleri ve parolaları listeleme:

```cmd
Grouper2.exe -d corp.local -l 3
```

**Konsol Çıktı Analizi:**
```
[+] Grouper2 - Group Policy Analysis Tool by @mikeloss
[*] Targeting Domain: corp.local
[*] Connecting to SYSVOL: \\corp.local\sysvol\corp.local\Policies
[*] Parsing 42 GPOs found in domain...

[!] [Level 4: Critical] Vulnerable GPP Password Found!
    GPO: {31B2F340-016D-11D2-945F-00C04FB984F9} - "Standard Server Baseline"
    File: Groups.xml
    User: Administrator
    Decrypted Password: LocalAdminPass2026!

[!] [Level 4: Critical] Restricted Groups Membership Manipulation!
    GPO: {6A4D9120-4412-11D0-9122-00A0C91E6D22} - "HelpDesk Privileges"
    File: GptTmpl.inf
    Group: Builtin\Administrators
    Members Added: CORP\Domain Users  <-- STANDART KULLANICILAR YÖNETİCİ YAPILMIŞ

[!] [Level 3: High] Sensitive User Right Assignment!
    GPO: {B892140A-5512-4211-9988-112233445566} - "SQL Servers Policy"
    File: GptTmpl.inf
    Privilege: SeDebugPrivilege
    Granted To: CORP\sql_service_acct

[+] Analysis complete. 3 actionable vulnerabilities identified.
```

### Senaryo 2: Yerel İndirilmiş Klasör Üzerinde Çevrimdışı GPO Analizi
Ağda hiçbir SMB sorgusu yapmadan önceden taşınmış klasör üzerinde tam analiz yürütme:

```cmd
Grouper2.exe -g "C:\Offline_Policies" -l 2
```

**Konsol Çıktı Analizi:**
```
[*] Local GPO Directory Specified: C:\Offline_Policies
[*] Level filter set to: 2 (Show interesting configurations)
[*] Parsing local files...
[!] [Level 2: Interesting] Windows Defender Tamper Protection Disabled via Registry.pol
    Setting: DisableAntiSpyware = 1
```

### Senaryo 3: Sonuçları Görsel HTML Raporu Olarak Kaydetme
Denetim bulgularını müşteri veya mavi takım için okunabilir HTML dosyası formatında kaydetme:

```cmd
Grouper2.exe -d corp.local -l 2 -f html -s C:\Reports\GPO_Audit_2026.html
```

**Konsol Çıktı Analizi:**
```
[*] Generating HTML report...
[+] Report successfully saved to: C:\Reports\GPO_Audit_2026.html
```

### Senaryo 4: Yalnızca En Kritik (Defcon 1 / Level 4) Zafiyetleri Filtreleme
Yüzlerce ayar arasından doğrudan yönetici erişimi veya açık parola sağlayan bulguları listeleme:

```cmd
Grouper2.exe -d corp.local -l 4
```

**Konsol Çıktı Analizi:**
```
[*] Filter: Level 4 Only
[!] [Level 4] Cleartext credentials found in Startup Script!
    GPO: "Map Network Drives"
    File: \\corp.local\sysvol\...\logon.bat
    Line: "net use Z: \\storage\share /user:corp\svc_share SecretPass2026!"
```

### Senaryo 5: Cobalt Strike `execute-assembly` ile Bellek İçi Yürütme
Hedef iş istasyonunun belleğinde C2 ajanı (Beacon) üzerinden aracı dosyasız koşturma:

```
beacon> execute-assembly /opt/Tools/Grouper2.exe -d corp.local -l 3
```

**Beacon Konsol Çıktısı:**
```
[*] Tasked beacon to run assembly: Grouper2.exe -d corp.local -l 3
[+] host called home, sent: 112640 bytes
[!] [Level 4: Critical] Vulnerable GPP Password Found!
    User: Administrator | Password: LocalAdminPass2026!
[+] Analysis complete.
```

### Senaryo 6: JSON Formatında Otomasyon Çıktısı Alma
Sonuçları SIEM veya otomatik analiz araçlarına aktarmak üzere JSON formatında üretme:

```cmd
Grouper2.exe -d corp.local -l 3 -f json -s C:\Temp\gpo_vulns.json
```

**Konsol Çıktı Analizi:**
```
[+] JSON data exported successfully to C:\Temp\gpo_vulns.json
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Failed to find SYSVOL path automatically` | DNS çözümleme hatası veya makine etki alanı üyesi değil. | `-d <FQDN>` ile etki alanını veya `-g \\<DC_IP>\sysvol\...` ile tam SMB yolunu el ile tanımlayın. |
| `Access is denied reading GPO policy files` | Kullanıcının belirli GPO GUID klasörlerinde okuma izni kaldırılmış. | `Authenticated Users` grubunun okuma izinlerini denetleyin; farklı bir domain kullanıcısının belirtecine geçin. |
| `Unhandled Exception: System.IO.FileNotFoundException` | GPO veritabanında referansı olan ancak SYSVOL'den silinmiş hayalet (orphaned) GPO klasörleri mevcut. | `-v` bayrağını kapatın; Grouper2'nin en güncel derlemesini kullanarak eksik dosya atlama mantığını etkinleştirin. |
| `Failed to parse Registry.pol binary stream` | `Registry.pol` dosyası PReg format standartlarına uymuyor veya üçüncü parti araçla bozulmuş. | Hatalı GPO klasörünü `-g` parametresiyle izole edin; diğer GPO'ları bağımsız olarak tarayın. |
| `execute-assembly output truncated or timeout` | Etki alanında binlerce GPO var ve analiz C2 zaman aşımını (timeout) aşıyor. | Filtreyi `-l 4` seviyesine çekerek yalnızca kritik açıkları listeleyin veya analizi yerel offline klasörde yapın. |
| `This application requires .NET Framework 4.7.2` | Hedef işletim sisteminde gereken .NET CLR derleme sürümü yüklü değil. | İkiliyi .NET Framework 3.5 veya 4.0 hedefleyecek şekilde yeniden derleyin (`/t:exe /p:TargetFrameworkVersion=v4.0`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[5.0 - IN-MEMORY .NET & SYSVOL READ]-------------- 10
  - Ağ Seviyesi: SMB SYSVOL okumaları (Olağan GPO eşitleme trafiğiyle örtüşür)
  - Uç Nokta Seviyesi: execute-assembly ile dosyasız yürütme (Sıfır PowerShell logu, düşük disk izi)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 5140 / 5145 (File Share Auditing):**
  * `Share Name: \\*\SYSVOL`
  * `RelativeTargetName: Policies\{GUID}\Machine\Registry.pol`, `GptTmpl.inf` dosyalarının okunması loglanır.
* **Microsoft-Windows-DotNETRuntime (ETW Logları):**
  * .NET CLR motoru bellekte `Grouper2` assembly'sini yüklediğinde ETW sağlayıcısı üzerinden `AssemblyLoad` olayı üretilir.
* **Sysmon Event ID 1 (Process Creation):**
  * Eğer CLI üzerinden doğrudan çalıştırılırsa `Grouper2.exe` proses oluşturma kaydı düşer. `execute-assembly` kullanıldığında ana süreç (örn: `rundll32.exe`) içinde yürütülür.

### 5.2 Ağ ve EDR İmzaları

* **Sıfır PowerShell İmzası:**
  Grouper2 saf C# kodu olduğundan `Microsoft-Windows-PowerShell/Operational` (Event ID 4104) günlüklerinde hiçbir iz bırakmaz.
* **Ağ Seviyesinde SMB Okuma Yoğunluğu:**
  Kısa sürede yüzlerce GPO dosyasının art arda okunması, NDR sistemlerinde "Automated Group Policy Enumeration" anomalisi olarak izlenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Discovery** | `T1615` | Group Policy Discovery | Etki alanı grup politikalarını ve yapılandırmalarını derinlemesine tarama. |
| **Credential Access** | `T1552.006` | Unsecured Credentials: Group Policy Preferences | XML dosyalarındaki şifreli ve açık parolaları bulma. |
| **Privilege Escalation** | `T1484.001` | Group Policy Modification (Analysis) | Zayıf GPO izinlerini ve yanlış yapılandırmaları tespit etme. |
| **Discovery** | `T1083` | File and Directory Discovery | SYSVOL dosya sistemini haritalama. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Toplu SMB Okuma Tespiti** | Tüm GPO'ları aynı anda taramak yerine, SYSVOL'ü önceden indirip çevrimdışı (`-g`) modda analiz etmek ağ gürültüsünü sıfırlar. |
| **C# Assembly İmzası** | Derlenmiş ikilinin string ve fonksiyon adları karıştırılmalı (obfuscation), ConfuserEx veya benzeri korumalar uygulanmalıdır. |
| **Beacon İletişim Boyutu** | Tam raporlar büyük veri döndürebileceğinden, C2 trafiğini şişirmemek için `-l 4` seviyesinde kısa çıktılar tercih edilmelidir. |
| **Kayıt Dosyası Temizliği** | Diske `-s` ile kaydedilen raporlar analiz sonrası güvenli biçimde silinmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Grouper2 Benzeri Toplu GPO Dosya Analiz Tespiti
```yaml
title: Olagandisi SYSVOL ve GPO Ilke Dosyalari Taramasi
id: e8912401-4412-4c99-b122-881239aa1122
status: experimental
description: Kisa surede cok sayida GPO Registry.pol ve GptTmpl.inf dosyasinin okunmasini yakalar.
references:
    - https://attack.mitre.org/techniques/T1615/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: security
    product: windows
    definition: 'Security Event ID 5145'
detection:
    selection:
        ShareName|endswith: '\SYSVOL'
        RelativeTargetName|contains:
            - '\Registry.pol'
            - '\GptTmpl.inf'
        AccessMask: '0x1'
    timeframe: 1m
    condition: selection | count() by IpAddress > 20
falsepositives:
    - Domain Controller replikasyon surecleri.
level: medium
tags:
    - attack.discovery
    - attack.t1615
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// Grouper2 assembly yuklemesini ve eszamanli SYSVOL SMB okuma olaylarini korele eder
DeviceEvents
| where ActionType == "ClrAssemblyLoaded"
| where AdditionalFields has "Grouper" or AdditionalFields has "mikeloss"
| join kind=inner (
    DeviceNetworkEvents
    | where RemotePort == 445
    | project TimeGenerated, DeviceName, RemoteIP
) on DeviceName
| project TimeGenerated, DeviceName, RemoteIP, AdditionalFields
```

#### YARA Kuralı: Grouper2 C# İkili İmzası
```yara
rule Threat_Tool_Grouper2 {
    meta:
        description = "Grouper2 GPO zafiyet analiz aracinin derlenmis assembly imzasini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "Grouper2" ascii wide nocase
        $s2 = "mikeloss" ascii wide nocase
        $s3 = "Registry.pol" ascii wide
        $s4 = "GptTmpl.inf" ascii wide
        $s5 = "Level 4: Critical" ascii wide
    condition:
        uint16(0) == 0x5A4D and (3 of ($s*))
}
```

#### Sertleştirme (Hardening) Adımları
1. **GPO Erişim Denetimlerinin Sıkılaştırılması:** Tüm GPO'ların ACL yapılandırması denetlenmeli; standart kullanıcılara veya yetkisiz gruplara `WriteGPO` veya `CreateChild` hakkı verilmemelidir.
2. **Restricted Groups Politikalarının İncelenmesi:** Yerel `Administrators` veya `Remote Desktop Users` gruplarına etki alanı kullanıcılarının atanmadığı düzenli olarak doğrulanmalıdır.
3. **Kullanıcı Hak Atamalarının (User Rights) Sınırlandırılması:** `SeDebugPrivilege`, `SeImpersonatePrivilege` ve `SeTcbPrivilege` hakları etki alanı genelinde yalnızca zorunlu servis hesaplarına tahsis edilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Varsayılan Kritik GPO Taraması (Level 3+)
```cmd
Grouper2.exe -d corp.local -l 3
```
* **Ne Yapar?:** Etki alanındaki GPO'ları tarayarak yalnızca yüksek ve kritik zafiyetleri konsola listeler.
* **Ne Zaman Kullanılır?:** Operasyon başında en hızlı hak yükseltme vektörlerini yakalamak için.
* **Parametreler:** `-d` etki alanı adı, `-l 3` seviye 3 ve üzeri filtre.

#### 2. Tüm Zafiyet Seviyelerini Kapsayan Tam Tarama (Level 1)
```cmd
Grouper2.exe -d corp.local -l 1
```
* **Ne Yapar?:** En küçük güvenlik tercihlerinden kritik açıklara kadar tüm bulguları raporlar.
* **Ne Zaman Kullanılır?:** Kapsamlı bir AD güvenlik denetimi ve sıkılaştırma analizi yaparken.
* **Parametreler:** `-l 1` tüm seviyeler.

#### 3. Çevrimdışı İndirilmiş SYSVOL Klasörünü İnceleme
```cmd
Grouper2.exe -g "C:\Loot\SYSVOL\Policies" -l 3
```
* **Ne Yapar?:** Canlı ağda SMB trafiği oluşturmadan yerel klasördeki ilke dosyalarını analiz eder.
* **Ne Zaman Kullanılır?:** Tam gizlilik gerektiren kırmızı takım operasyonlarında.
* **Parametreler:** `-g <yerel_yol>`.

#### 4. HTML Formatında Görsel Rapor Üretme
```cmd
Grouper2.exe -d corp.local -l 2 -f html -s C:\Reports\gpo_audit.html
```
* **Ne Yapar?:** Bulguları filtrelenebilir ve renk kodlu bir HTML rapor dosyası olarak dışa aktarır.
* **Ne Zaman Kullanılır?:** Bulguları yönetim veya mavi takım ile paylaşmak için.
* **Parametreler:** `-f html` format, `-s` kayıt yolu.

#### 5. JSON Formatında Yapılandırılmış Çıktı Alma
```cmd
Grouper2.exe -d corp.local -l 3 -f json -s C:\Temp\vulns.json
```
* **Ne Yapar?:** Bulguları JSON sözdiziminde kaydeder.
* **Ne Zaman Kullanılır?:** Çıktıları otomatik ayrıştırma betiklerine veya SIEM'e aktarmak için.
* **Parametreler:** `-f json`.

#### 6. Yalnızca En Kritik (Defcon 1 / Level 4) Zafiyetleri Filtreleme
```cmd
Grouper2.exe -d corp.local -l 4
```
* **Ne Yapar?:** Sadece açık parolaları ve doğrudan yönetici hak devirlerini görüntüler.
* **Ne Zaman Kullanılır?:** Zaman kısıtlı sızma testlerinde anında sonuç almak için.
* **Parametreler:** `-l 4` seviye 4 filtresi.

#### 7. Cobalt Strike execute-assembly ile Bellekte Çalıştırma
```
execute-assembly /opt/Tools/Grouper2.exe -d corp.local -l 3
```
* **Ne Yapar?:** Aracı diske yazmadan Beacon sürecinin belleğinde yürüterek sonuçları C2 konsoluna döker.
* **Ne Zaman Kullanılır?:** EDR dosya tarama ve AMSI engellerini bertaraf etmek için.
* **Parametreler:** Beacon konsol sözdizimi.

#### 8. Ayrıntılı (Verbose) Hata Ayıklama Modunda Tarama
```cmd
Grouper2.exe -d corp.local -l 3 -v
```
* **Ne Yapar?:** Taranan her bir GPO GUID'ini ve okunan her bir dosya yolunu ekrana yazdırır.
* **Ne Zaman Kullanılır?:** Hangi GPO'da takılma veya erişim sorunu olduğunu tespit etmek için.
* **Parametreler:** `-v` verbose modu.

#### 9. Belirli Bir Alt Etki Alanını Hedefleme
```cmd
Grouper2.exe -d child.corp.local -l 3
```
* **Ne Yapar?:** Forest içerisindeki güvenilen alt etki alanının politikalarını sorgular.
* **Ne Zaman Kullanılır?:** Çapraz etki alanı zafiyet denetimlerinde.
* **Parametreler:** `-d <Alt_Domain>`.

#### 10. Operasyon Sonrası Geçici Rapor Dosyalarını Temizleme
```cmd
del /f /q C:\Temp\gpo_vulns.json
```
* **Ne Yapar?:** Hasat edilen analiz çıktılarını hedef diskten siler.
* **Ne Zaman Kullanılır?:** Operasyon tamamlandığında adli izleri ortadan kaldırmak için.
* **Parametreler:** `del /f /q`.

---

## Kaynaklar
* [Grouper2 Resmi GitHub Deposu (Mike Loss)](https://github.com/mikeloss/Grouper2)
* [Microsoft Dokümantasyonu: Group Policy Technical Overview](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh831791(v=ws.11))
* [MITRE ATT&CK: Group Policy Discovery (T1615)](https://attack.mitre.org/techniques/T1615/)
* [MITRE ATT&CK: Unsecured Credentials: Group Policy Preferences (T1552.006)](https://attack.mitre.org/techniques/T1552/006/)
* [SpecterOps: Group Policy Abuse Techniques](https://posts.specterops.io/)
* [HackTricks: Pentesting Group Policies](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#group-policy-preferences-gpp)

---

> **Önceki:** [← Get-GPPPassword](./Get-GPPPassword.md) · **Sonraki:** [LAPSToolkit.ps1 →](./LAPSToolkit.md)
