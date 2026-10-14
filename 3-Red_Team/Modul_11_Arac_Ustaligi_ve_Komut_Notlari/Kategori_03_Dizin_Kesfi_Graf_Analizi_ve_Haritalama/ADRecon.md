# ADRecon

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Prashant Mahajan (@sense-of-security) tarafından geliştirilen; standart bir etki alanı kullanıcısı yetkisiyle LDAP, ADSI ve WMI sorguları üzerinden tüm Active Directory topolojisini çıkarıp çok sekmeli Microsoft Excel (.xlsx), CSV veya JSON raporlarına dönüştüren PowerShell tabanlı denetim ve keşif aracı.

---

## 1. Genel Bakış ve Amaç

**ADRecon**, kurumsal Active Directory ortamlarının kapsamlı bir güvenlik envanterini ve topolojisini çıkarmak için geliştirilmiş gelişmiş bir PowerShell keşif ve denetim aracıdır. Özellikle kırmızı takım operatörleri, sızma testi uzmanları ve güvenlik denetçileri (auditors) için tasarlanan araç, hedef ağda herhangi bir yönetimsel ayrıcalığa (Local Admin veya Domain Admin) veya üçüncü taraf bir ajana ihtiyaç duymadan, yalnızca standart bir etki alanı kullanıcısının okuma izinleriyle çalışır.

Aracın operasyonel sahadaki en belirgin gücü; etki alanı denetleyicileri, kullanıcılar, gruplar, grup üyelikleri, SPN kayıtları (Kerberoast hedefleri), parola politikaları (Fine-Grained Password Policies dahil), Grup İlkesi Nesneleri (GPO), güven ilişkileri, AD CS sertifika şablonları ve DNS kayıtları gibi onlarca farklı kategoriyi tek bir çalıştırmada çekip **her bir kategoriyi ayrı bir sekme (worksheet) olarak formatlanmış bir Microsoft Excel (`.xlsx`) tablosuna** dönüştürmesidir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              ADRECON ÇALIŞMA MİMARİSİ                             |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Standart Domain User]
                       .\ADRecon.ps1 [modül parametreleri]
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                            ADRecon Çekirdek Motoru                                |
|  - .NET System.DirectoryServices (ADSI / LDAP)                                    |
|  - WMI / CIM (Win32_OperatingSystem, Win32_ComputerSystem)                        |
|  - ADWS (Active Directory Web Services) / COM Arayüzleri                          |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Sorgulanan Protokoller ve Portlar                          |
|         [LDAP / LDAPS: 389/636]   [WMI / RPC: 135/445]   [DNS: 53]                |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                         Toplanan Varlıklar ve Modüller                            |
+-----------------------------------------------------------------------------------+
  |-- Forest & Domains           |-- Computers & OS Versiyonları  |-- GPO & GPO Bağlantıları
  |-- Domain Controllers         |-- Domain Admins & Yetkililer   |-- AD CS Sertifikaları
  |-- Trusts & Güven Yönleri     |-- SPN Kayıtları (Kerberoast)   |-- LAPS Durumları
  |-- Users & Password Policies  |-- Groups & Üyelik Zincirleri   |-- DNS Bölgeleri & Kayıtlar
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Raporlama ve Çıktı Üretim Katmanı                          |
|         - Microsoft Excel (.xlsx - Çok Sekmeli & Otomatik Formatlı)               |
|         - CSV Dosyaları (Her modül için ayrı .csv)                                |
|         - JSON & HTML Raporları                                                   |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi & Kırmızı Takım Faydası |
|---|---|---|
| **Sıfır Ayrıcalık Gereksinimi** | Dizin okuma izni olan en düşük yetkili kullanıcıyla tüm veriyi çeker. | İlk erişim (Initial Access) elde edilir edilmez tüm ağ envanterini döker. |
| **Excel Formatlı Analiz** | Onlarca kategoriyi pivot edilebilir ve filtrelenebilir Excel sayfalarına yazar. | Manuel komut çalıştırmadan saatler sürecek analizi dakikalara indirir. |
| **Genişletilmiş Modül Desteği**| LAPS, Fine-Grained Password Policy, AD CS ve gMSA nesnelerini kapsar. | Gizli yetki yükseltme ve zafiyetli yapılandırma noktalarını anında gösterir. |
| **Ajansız ve Kurulumsun** | Hedef sisteme ek DLL veya RSAT bileşeni yüklemeden çalışır. | Sistem üzerinde minimum ayak izi bırakır. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | ADRecon | BloodHound / SharpHound | PowerView.ps1 | ldapdomaindump | PingCastle |
|---|---|---|---|---|---|
| **Çıktı Formatı** | Excel (.xlsx), CSV, JSON | Neo4j Graf Veritabanı | PowerShell Nesneleri | HTML, JSON, Grep | HTML Risk Raporu |
| **Kullanım Amacı** | Kapsamlı Envanter & Denetim | Saldırı Yolu Haritalama | Hedefli Komut Çalıştırma | Hızlı Çevrimdışı İnceleme | Risk Puanlama & Sertleştirme |
| **Görselleştirme** | Excel Tabloları | İnteraktif Graf Arayüzü | Yok (Metin/Tablo) | Statik HTML Sayfaları | Risk Grafikleri / Puanlar |
| **Analiz Hızı** | Çok Yüksek (Excel Filtreleme) | Orta (Cypher Sorguları) | Manuel Sorgulama | Hızlı | Otomatik Değerlendirme |
| **Yazıldığı Dil** | PowerShell (.ps1) | C# (.NET) / Python | PowerShell (.ps1) | Python 3 | C# (.NET) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ADRecon bir PowerShell betiği olarak doğrudan komut satırından parametrelerle çağrılır:

```powershell
.\ADRecon.ps1 [parametreler]
```

### 2.1 Bağlantı ve Hedef Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-Domain` | Sorgulanacak hedef etki alanının FQDN adı. | `-Domain "corp.local"` |
| `-DomainController` | Sorguların yönlendirileceği spesifik DC IP'si veya adı. | `-DomainController "10.10.10.10"` |
| `-Credential` | Farklı kimlik bilgisi kullanmak için `PSCredential` nesnesi. | `-Credential (Get-Credential)` |
| `-Protocol` | LDAP bağlantı protokolü (`LDAP` veya `LDAPS`). | `-Protocol "LDAPS"` |
| `-Port` | LDAP portu (Varsayılan: 389 veya LDAPS için 636). | `-Port 636` |

### 2.2 Toplama ve Modül Filtreleme Parametreleri

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-Collect` | Yalnızca belirtilen modülleri toplar (virgülle ayrılmış liste). | `-Collect Users,SPNs,Groups` |
| `-Exclude` | Belirtilen modülleri toplamadan atlar. | `-Exclude Computers,DNS` |
| `-OutputFormat` | Çıktı formatı (`Excel`, `CSV`, `JSON`, `HTML`). | `-OutputFormat CSV` |
| `-OutputPath` | Raporların kaydedileceği klasör yolu. | `-OutputPath "C:\ADRecon-Results"` |
| `-NoExcel` | Excel yüklü olmayan sistemlerde `.xlsx` üretimini kapatıp CSV'ye zorlar. | *(Anahtar bayrak)* |
| `-Quiet` | Konsola detay yazdırmadan arka planda sessiz çalışır. | *(Anahtar bayrak)* |

### 2.3 Desteklenen Modül İsimleri (Collect / Exclude Listesi)

| Modül Adı | Toplanan İçerik |
|---|---|
| `Forest` | Orman fonksiyonel seviyesi, FSMO rolleri, kök etki alanı bilgisi. |
| `Domain` | Etki alanı SID, GUID, şifre politikası ve temel öznitelikler. |
| `DomainControllers`| Etki alanındaki tüm DC'ler, IP'leri, rolleri ve OS sürümleri. |
| `Trusts` | Çift ve tek yönlü etki alanı güven ilişkileri. |
| `Users` | Tüm kullanıcılar, kilitli/devre dışı durumları, son parola değişim tarihleri. |
| `SPNs` | Servis hesabı (Kerberoastable) kullanıcıları ve kayıtlı SPN'leri. |
| `Groups` | Tüm güvenlik grupları ve grup türleri. |
| `GroupMemberships`| Hangi kullanıcının hangi gruplara üye olduğunun detaylı dökümü. |
| `Computers` | Etki alanına katılmış tüm bilgisayarlar, OS versiyonları, LAPS durumları. |
| `GPOs` | Grup Politikası Nesneleri, GUID'leri ve değiştirilme zamanları. |
| `PasswordPolicies`| Fine-Grained Password Policies (PSO) ve standart etki alanı parolası kuralları. |
| `DNS` | Active Directory Integrated DNS (ADIDNS) bölgeleri ve kayıtları. |

### 2.4 İncelenen Kritik Öznitelikler ve Güvenlik Anlamları

ADRecon tarafından Excel hücrelerine aktarılan aşağıdaki öznitelikler sızma testlerinde doğrudan saldırı vektörlerine işaret eder:

| Öznitelik (Attribute) | Modül | Güvenlik Anlamı ve Saldırı Değeri |
|---|---|---|
| `servicePrincipalName` | SPNs | Kerberoasting saldırısı için TGS bilet özeti talep edilebilir hesap. |
| `userAccountControl` | Users / Computers | `DONT_REQ_PREAUTH` (AS-REP Roasting), `TRUSTED_FOR_DELEGATION` (Unconstrained). |
| `msDS-AllowedToDelegateTo` | Users / Computers | Kısıtlı delegasyon (S4U) hedef servisleri; bilet sahteciliği potansiyeli. |
| `adminCount` | Users / Groups | Nesnenin AdminSDHolder koruması altında olduğunu veya eskiden yetkili olduğunu gösterir. |
| `ms-Mcs-AdmPwd` | Computers | LAPS kurulu makinelerde açık metin yerel yönetici parolası alanı. |
| `pwdLastSet` | Users | Parolası yıllardır değiştirilmemiş bayat (stale) servis veya kullanıcı hesapları. |
| `description` | Users / Computers | Açıklama satırında unutulmuş açık metin parolalar veya sistem notları. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Tam Keşif ve Otomatik Excel Raporu Üretme

Mevcut etki alanı kullanıcısı oturumunda tüm etki alanı envanterini toplayıp masaüstüne Excel formatında kaydetme:

```powershell
# 1. PowerShell ExecutionPolicy kısıtlamasını geçici olarak atlatma
powershell.exe -ExecutionPolicy Bypass -NoProfile

# 2. ADRecon'u tam kapsamlı çalıştırma
.\ADRecon.ps1 -OutputPath "C:\Users\Public\ADRecon_Report"
```

**Konsol Çıktısı Analizi:**

```text
======================================================================
ADRecon v2.2 - Active Directory Reconnaissance Tool
Sense of Security Pty Ltd - https://www.senseofsecurity.com.au
======================================================================
[*] Starting Active Directory Reconnaissance at 14:10:02...
[*] Querying Forest and Domain information... [DONE]
[*] Querying Domain Controllers... [Found: 3 DC]
[*] Querying Trusts... [Found: 1 Trust]
[*] Querying User Accounts... [Found: 1,842 Users]
[*] Querying Service Principal Names (SPNs)... [Found: 24 SPN Users]
[*] Querying Groups and Memberships... [Found: 145 Groups]
[*] Querying Computer Accounts... [Found: 620 Computers]
[*] Querying Group Policy Objects (GPOs)... [Found: 48 GPOs]
[*] Generating Microsoft Excel Report...
[+] Report generated successfully: C:\Users\Public\ADRecon_Report\ADRecon-Report-CORP-2026-10-14.xlsx
[*] Total execution time: 142 seconds.
```
*Analiz: Elde edilen `ADRecon-Report-CORP.xlsx` dosyası açıldığında; "SPNs" sekmesinde Kerberoast edilebilir 24 hesap, "Users" sekmesinde parolası süresi dolmayan hesaplar ve "Computers" sekmesinde LAPS uygulanmamış sunucular saniyeler içinde filtrelenebilir.*

### Senaryo 2: Excel Bulunmayan Sistemde Hızlı CSV Dökümü Alma

Hedef makinede Microsoft Office / Excel yüklü olmadığında COM nesnesi hatası almamak için CSV modunda çalıştırma:

```powershell
.\ADRecon.ps1 -NoExcel -OutputFormat CSV -OutputPath "C:\Temp\ADData"
```

### Senaryo 3: Hedefli Keşif (Yalnızca Kritik Saldırı Vektörleri)

Ağda gereksiz LDAP gürültüsü yapmamak için yalnızca parola kırma ve yetki analizi odaklı modülleri toplama:

```powershell
.\ADRecon.ps1 -Collect DomainControllers,Users,SPNs,Groups,PasswordPolicies -OutputPath "C:\Temp\Targeted"
```

### Senaryo 4: Uzak Etki Alanı ve Farklı Kimlik Bilgisiyle Keşif

Ele geçirilen farklı bir kullanıcının kimlik bilgileriyle, güven ilişkisi olan bir üst veya komşu etki alanını sorgulama:

```powershell
$secpass = ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("CORP\pentest_user", $secpass)

.\ADRecon.ps1 -Domain "eu.target.local" -DomainController "10.20.20.10" -Credential $cred -Protocol LDAPS
```

### Senaryo 5: Toplanan Excel Verilerinin Operasyonel Değerlendirilmesi

ADRecon çalışması bittikten sonra operatörün Excel üzerinde hızlıca uygulayacağı filtreler:
1. **`SPNs` Sekmesi:** `servicePrincipalName` sütununda `MSSQLSvc*` ve `HTTP*` olan hesaplar Kerberoasting için filtrelenir.
2. **`Users` Sekmesi:** `PasswordNotRequired = True` veya `DontExpirePassword = True` olan hesaplar taranır.
3. **`PasswordPolicies` Sekmesi:** Fine-Grained Password Policies ile Domain Admins veya Servis hesaplarına daha gevşek parola kuralları atanıp atanmadığı doğrulanır.
4. **`Computers` Sekmesi:** `OperatingSystem` sütununda `Windows Server 2008` / `Windows 7` gibi eski ve zafiyetli makineler tespit edilir.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `New-Object : Retrieving the COM class factory for component with CLSID {00024500-0000-0000-C000-000000000046} failed` | Hedef sistemde Microsoft Excel yüklü değil. PowerShell Excel COM motorunu başlatamıyor. | Komuta mutlaka `-NoExcel` bayrağını ekleyin. Veriler Excel yerine standart CSV dosyaları olarak kaydedilecektir. |
| `ADRecon.ps1 is not digitally signed. You cannot run this script on the current system` | PowerShell `ExecutionPolicy` ayarı `Restricted` veya `AllSigned` olarak yapılandırılmış. | `powershell -ExecutionPolicy Bypass -File .\ADRecon.ps1` komutuyla yürütme politikasını geçin. |
| `This script contains malicious content and has been blocked by your antivirus software` | Windows Defender veya EDR çözümü ADRecon içerisindeki betik bloklarını AMSI üzerinden yakaladı. | Bellek içi AMSI bypass uygulayın veya betiği şifreleyerek (`Invoke-Obfuscation`) belleğe yükleyin. |
| `System.DirectoryServices.DirectoryServicesCOMException: The server is not operational` | İstemci hedef Etki Alanı Denetleyicisinin LDAP (389) portuna erişemiyor veya yanlış FQDN verildi. | `-DomainController <DC_IP>` bayrağı ile doğrudan geçerli DC IP adresini belirtin. |
| `WMI / CIM connection failed on member servers: Access is Denied (0x80070005)` | WMI modülü etki alanı üyelerinden uzaktan OS ve LAPS bilgisi çekerken standart kullanıcının RPC izinlerine takıldı. | ADRecon LDAP sorgularına devam eder. WMI hatalarını görmezden gelebilir veya bu modülü `-Exclude WMI` ile atlayabilirsiniz. |
| `Execution timeout / Memory leak on large domains (50,000+ objects)` | 10 binden fazla nesne barındıran dev kurumsal ortamlarda bellek yetersizliği veya LDAP sayfalama gecikmesi. | Tüm modülleri tek seferde çalıştırmak yerine `-Collect Users` ve `-Collect Computers` şeklinde parçalı çalıştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

ADRecon, operasyonel açıdan mükemmel bir envanter sunsa da, **etki alanındaki tüm nesneleri sistematik olarak çekmesi nedeniyle** en gürültülü keşif araçlarından biridir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **PowerShell Script Block Logging (Event ID 4104):**
   - ADRecon fonksiyonları (`Get-ADReconForest`, `Get-ADReconDomain`, `Get-ADReconUsers`) `Microsoft-Windows-PowerShell/Operational` günlüğüne tam metin olarak yazılır.
2. **Directory Service Access (Event ID 4662 / LDAP Sorgu Günlükleri):**
   - Etki Alanı Denetleyicisi üzerinde kısa bir zaman diliminde binlerce kullanıcı, bilgisayar, grup ve GPO nesnesinin okunması (`Event ID 1644 - LDAP Expensive/Inefficient Search Queries`).
3. **Windows Security Event ID 4624 (Logon Type 3):**
   - DC'ye yapılan LDAP bağlantıları için ağ oturumu açma kayıtları.
4. **Sysmon Event ID 1 (Process Creation):**
   - `powershell.exe -ExecutionPolicy Bypass .\ADRecon.ps1` komut satırı izi.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Ağ Gürültüsü:** Dakikalar içerisinde megabaytlarca LDAP arama yanıtı (SearchResEntry) transfer edilir.
- **WMI / RPC Yoklamaları:** Bilgisayar nesneleri için uzaktan WMI sorguları IDS/IPS sensörlerinde port 135 ve yüksek port anomalileri oluşturur.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | ADRecon Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesapları ve SPN'lerin toplu dökümü |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Güvenlik grupları ve grup üyeliklerinin çıkarılması |
| **T1482** | Domain Trust Discovery | Güven ilişkilerinin (Trusts) listelenmesi |
| **T1018** | Remote System Discovery | Etki alanı bilgisayarları ve DC'lerin tespiti |
| **T1201** | Password Policy Discovery | Standart ve Fine-Grained Password Policy kuralları |
| **T1484.001** | Domain Policy Modification: Group Policy Modification | GPO nesnelerinin ve bağlantılarının envanteri |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Geniş LDAP Taraması** | Tüm AD nesnelerinin tek bir oturumda dakikalar içinde okunması. | ADRecon'u körlemesine çalıştırmayın; yalnızca hedefiniz olan modülleri (`-Collect SPNs,PasswordPolicies`) seçin. |
| **AMSI ve 4104 Logları** | Standart ADRecon betik metinlerinin Defender tarafından yakalanması. | Betik bloklarını karıştırın (obfuscation) veya bellekte unmanaged PowerShell ile çalıştırın. |
| **Excel COM Nesnesi** | `Excel.Application` sürecinin arka planda sessizce başlatılması. | Excel kurulu olmayan sistemleri tercih edin veya `-NoExcel` kullanarak veriyi düz CSV formatında çekin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

ADRecon ve benzeri kitle keşif betiklerini tespit eden örnek Sigma kuralı:

```yaml
title: ADRecon Execution via Script Block Logging
id: b3491f09-adrecon-detection-4104
status: experimental
description: Detects execution of ADRecon Active Directory reconnaissance tool via PowerShell 4104 logs.
logsource:
    product: windows
    service: powershell
detection:
    selection:
        ScriptBlockText|contains:
            - 'ADRecon'
            - 'Get-ADReconDomain'
            - 'Get-ADReconUsers'
            - 'Get-ADReconComputers'
            - 'Get-ADReconSPNs'
    condition: selection
level: high
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```powershell
# 1. Tam Kapsamlı Keşif ve Otomatik Excel Raporu Alma
.\ADRecon.ps1 -OutputPath "C:\Reports"
```
- **Ne Yapar?** Tüm modülleri sorgular ve `C:\Reports` klasörüne çok sekmeli bir Excel tablosu kaydeder.
- **Ne Zaman Kullanılır?** İlk erişim sonrası ağın genel resmini Excel üzerinde görmek istendiğinde.
- **Parametreler:** `-OutputPath` rapor klasörünü belirler.

```powershell
# 2. Excel Olmadan Sadece CSV Dosyaları Üretme
.\ADRecon.ps1 -NoExcel -OutputFormat CSV -OutputPath "C:\Temp\csv_out"
```
- **Ne Yapar?** Excel bağımlılığını kaldırır; her kategoriyi ayrı bir `.csv` dosyası olarak yazar.
- **Ne Zaman Kullanılır?** Microsoft Office yüklü olmayan sunucu ortamlarında.
- **Parametreler:** `-NoExcel` COM başlatmayı engeller; `-OutputFormat CSV` CSV modunu seçer.

```powershell
# 3. Yalnızca Kerberoasting Hedeflerini (SPN) ve Parola Politikalarını Çekme
.\ADRecon.ps1 -Collect SPNs,PasswordPolicies -NoExcel -OutputFormat CSV
```
- **Ne Yapar?** Yalnızca SPN tanımlı hesapları ve şifre politikalarını hızlıca çeker.
- **Ne Zaman Kullanılır?** Düşük gürültülü ve hedefli parola saldırıları planlarken.
- **Parametreler:** `-Collect` hedef modül listesini sınırlandırır.

```powershell
# 4. Yalnızca Kullanıcı ve Grup Üyeliklerini Toplama
.\ADRecon.ps1 -Collect Users,Groups,GroupMemberships -NoExcel
```
- **Ne Yapar?** Kullanıcı listesini, güvenlik gruplarını ve kimin nereye üye olduğunu döker.
- **Ne Zaman Kullanılır?** Yetkili kullanıcı ve grup ilişkilerini analiz etmek için.
- **Parametreler:** `-Collect` spesifik kullanıcı/grup modüllerini seçer.

```powershell
# 5. Farklı Bir Etki Alanı ve Denetleyicisini Hedefleme
.\ADRecon.ps1 -Domain "sub.corp.local" -DomainController "10.10.20.5" -NoExcel
```
- **Ne Yapar?** Mevcut makinenin bağlı olduğu etki alanı dışındaki hedef bir DC'yi sorgular.
- **Ne Zaman Kullanılır?** Orman içi güven ilişkileri üzerinden yan domain'lere keşif yaparken.
- **Parametreler:** `-Domain` hedef etki alanı; `-DomainController` hedef DC IP'si.

```powershell
# 6. Güvenli LDAPS (TCP 636) Protokolü ile Çalıştırma
.\ADRecon.ps1 -Protocol LDAPS -Port 636 -NoExcel
```
- **Ne Yapar?** Sorguları şifreli SSL tüneli üzerinden yaparak ağ koklayıcılarından gizler.
- **Ne Zaman Kullanılır?** Ağda IDS/NDR izlemesi olan hassas kurumsal ortamlarda.
- **Parametreler:** `-Protocol LDAPS` şifrelemeyi zorlar; `-Port 636` port numarasını ayarlar.

```powershell
# 7. Farklı Kullanıcı Kimlik Bilgisi ile Çalıştırma
.\ADRecon.ps1 -Credential (Get-Credential) -NoExcel
```
- **Ne Yapar?** Etkileşimli kimlik doğrulama penceresi açarak farklı bir kullanıcı yetkisiyle sorgu yapar.
- **Ne Zaman Kullanılır?** Mevcut lokal oturumdan çıkmadan ele geçirilen etki alanı kullanıcısıyla keşif yaparken.
- **Parametreler:** `-Credential` kimlik doğrulama nesnesi alır.

```powershell
# 8. Çıktıyı JSON Formatında Otomasyona Hazırlama
.\ADRecon.ps1 -OutputFormat JSON -OutputPath "C:\Temp\json_out"
```
- **Ne Yapar?** Tüm keşif verilerini script'lerle ayrıştırılabilir JSON formatında dışa aktarır.
- **Ne Zaman Kullanılır?** Verileri diğer analiz araçlarına veya SIEM/ELK sistemlerine beslemek için.
- **Parametreler:** `-OutputFormat JSON` çıktı biçimini JSON olarak ayarlar.

```powershell
# 9. Gürültülü Modülleri Hariç Tutarak Hızlı Tarama
.\ADRecon.ps1 -Exclude Computers,DNS,GPOs -NoExcel -OutputPath "C:\Temp\fast_recon"
```
- **Ne Yapar?** Binlerce satırlık bilgisayar ve DNS sorgularını atlayarak sadece kritik kimlik ve politika verilerini çeker.
- **Ne Zaman Kullanılır?** Büyük ağlarda (50.000+ host) tarama süresini dakikalardan saniyelere indirmek için.
- **Parametreler:** `-Exclude` belirtilen modülleri atlar.

```powershell
# 10. Konsol Çıktısız Tamamen Sessiz Çalıştırma
.\ADRecon.ps1 -Quiet -NoExcel -OutputPath "C:\Temp\silent"
```
- **Ne Yapar?** Ekrana hiçbir ilerleme çubuğu veya metin yazdırmadan arka planda sessizce CSV'leri üretir.
- **Ne Zaman Kullanılır?** Hedef sistemde kullanıcı oturumu izlenirken veya C2 oturumundan gizlice veri çekerken.
- **Parametreler:** `-Quiet` konsol çıktılarını kapatır; `-NoExcel` COM başlatmaz.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [sense-of-security / ADRecon](https://github.com/sense-of-security/ADRecon)
- **Sense of Security Araştırma Blogu:** [Sense of Security Active Directory Security](https://www.senseofsecurity.com.au/)
- **MITRE ATT&CK Framework:** [Technique T1087 - Account Discovery](https://attack.mitre.org/techniques/T1087/)
- **PowerShell Gallery:** [ADRecon PowerShell Modülleri](https://www.powershellgallery.com/)

---

> **Önceki:** [← pywerview](./pywerview.md) · **Sonraki:** [linWinPwn →](./linWinPwn.md)
