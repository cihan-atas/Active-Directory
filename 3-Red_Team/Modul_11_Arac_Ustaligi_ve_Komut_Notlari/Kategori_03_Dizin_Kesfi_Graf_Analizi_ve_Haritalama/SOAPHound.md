# SOAPHound

> **Kategori:** [3. Dizin Keşfi, Graf Analizi ve Saldırı Yolu Haritalama](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)  
> **Tanım:** FalconForce tarafından geliştirilen; standart LDAP (TCP 389/636) izleme mekanizmalarını ve bal küpü (honeytoken) tuzaklarını atlatmak amacıyla Active Directory Web Services (ADWS - TCP Port 9389) arayüzünü SOAP XML sorguları ile kullanarak etki alanı nesnelerini gizlice toplayan ve BloodHound uyumlu JSON çıktıları üreten C# ve Python tabanlı yeni nesil keşif aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında dizin keşfi (enumeration) genellikle `SharpHound`, `PowerView`, `ldapsearch` veya `AdFind` gibi LDAP tabanlı araçlarla yürütülür. Ancak modern kurumsal savunma mimarilerinde SOC analistleri ve EDR çözümleri; **TCP 389 (LDAP)** ve **TCP 636 (LDAPS)** portları üzerinden akan trafiği, olağandışı sorgu hacimlerini, unindexed arama modellerini ve özellikle bal küpü hesaplara (Honeytokens / Decoys) yapılan sorguları sıkı bir şekilde izler.

**Active Directory Web Services (ADWS)**, Windows Server 2008 R2 ile birlikte her Domain Controller üzerinde varsayılan olarak çalışan ve **TCP 9389** portunu dinleyen Windows Communication Foundation (WCF) tabanlı bir SOAP XML web servisidir. Microsoft'un yerel PowerShell Active Directory modülü (`Get-ADUser`, `Get-ADGroup` vb.) arka planda doğrudan ADWS ile haberleşir.

**`SOAPHound`**, LDAP protokolüne hiç dokunmadan, tüm keşif trafiğini ADWS SOAP arayüzüne yönlendirir:
1. **LDAP İzleme Mekanizmalarını Baypas Eder:** Ağ tabanlı IDS/IPS sistemleri ve LDAP tuzakları port 389/636 trafiğini dinlerken; port 9389 üzerinden akan WCF/SOAP XML paketleri klasik LDAP denetimlerinden tamamen sıyrılır.
2. **BloodHound Uyumluluğu:** Topladığı kullanıcı, grup, bilgisayar, OU, GPO ve güven (trust) ilişkilerini doğrudan BloodHound CE veya klasik BloodHound formatında JSON dosyalarına dönüştürür.
3. **Çoklu Platform:** Hem Windows (.NET / C# binary) hem de Linux (Python - `pySOAPHound`) ortamlarında çalışabilir; parola, NTLM hash veya Kerberos biletleri ile kimlik doğrulamayı destekler.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│               SALDIRGAN MAKİNESİ (C# / PYTHON İSTEMCİ)                 │
│                                                                        │
│  [ SOAPHound.exe --build-cache ]                                       │
│         │                                                              │
│         ├── (1) TCP Port 9389 Üzerinden ADWS Uç Noktasına Bağlanır:    │
│         │       http://<DC_FQDN>:9389/ActiveDirectoryWebServices/Windows│
│         │                                                              │
│         ├── (2) Kerberos / NTLM ile WCF Güvenlik Zarfı Oluşturulur     │
│         │                                                              │
│         ├── (3) SOAP XML Paketleri İletilir:                           │
│         │       - <EnumerateRequest> (Nesne Arama Filtresi)            │
│         │       - <PullRequest> (Sayfalanmış Nesne Verisi)             │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (ADWS & NTDS.DIT) ]                               │
│         │                                                              │
│         ├── (4) ADWS Servisi (Microsoft.ActiveDirectory.WebServices)   │
│         │       sorguyu yerel olarak NTDS.dit veritabanından çeker     │
│         │                                                              │
│         ├── (5) SOAP Yanıtı (XML) Olarak İstemciye İletilir            │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: BloodHound Uyumlu JSON Dosyaları (users.json, groups.json) ] │
└────────────────────────────────────────────────────────────────────────┘
```

### Karşılaştırma Tablosu

| Özellik / Kriter | Standart SharpHound (LDAP) | ldapsearch / PowerView | SOAPHound (ADWS SOAP) |
|---|---|---|---|
| **Kullanılan Port** | TCP 389 / 636 / 3268 / 445 | TCP 389 / 636 | **TCP 9389** (WCF SOAP) |
| **Protokol** | Saf LDAP / LDAPS | Saf LDAP | **SOAP XML over HTTP/TCP** |
| **LDAP İzleme / Honeytoken Tespiti** | Yüksek risk (Tespit edilir) | Orta-Yüksek risk | **Çok Düşük (Baypas eder)** |
| **BloodHound JSON Üretimi** | Doğal / Tam destek | Manuel ayrıştırma gerekir | **Doğal / Tam destek** |
| **Çalışma Platformu** | C# (Windows) | C# / Python / Bash | **C# (.NET) ve Python (Linux)** |
| **Oturum Çalma Yeteneği** | Var (Session collection) | Yok | Yok (Yalnızca dizin verisi) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
# Windows CLI Temel Sözdizimi:
SOAPHound.exe [eylem_bayrakları] [bağlantı_seçenekleri]

# Linux Python CLI Temel Sözdizimi:
python3 pySOAPHound.py -d <domain> -u <kullanıcı> -p <parola> --dc-ip <DC_IP> [seçenekler]
```

### Kritik Bayraklar ve Açıklamaları

| Parametre | Tip | Açıklama | Örnek Değer |
|---|---|---|---|
| `--build-cache` / `-b` | Bayrak | Tüm etki alanı nesnelerini toplayarak yerel önbellek ve BloodHound dosyalarını üretir. | `--build-cache` |
| `--dns` / `-s` | String | Hedef Domain Controller'ın DNS FQDN adı veya IP adresi. | `--dns dc01.corp.local` |
| `--domain` / `-d` | String | Hedef etki alanının FQDN adı. | `-d corp.local` |
| `--output-directory` / `-o` | Dizin | Çıktı JSON dosyalarının kaydedileceği yerel yol. | `-o C:\Windows\Temp\output` |
| `--search-base` | String | Keşfin sınırlandırılacağı belirli bir OU veya konteyner DN'i. | `--search-base "OU=Users,DC=corp,DC=local"` |
| `--batch-size` | Sayı | Her bir SOAP Pull isteğinde çekilecek maksimum nesne sayısı (varsayılan: 500). | `--batch-size 250` |
| `--username` / `-u` | String | Kimlik doğrulama için kullanıcı adı. | `-u jdoe` |
| `--password` / `-p` | String | Kimlik doğrulama parolası. | `-p 'Passw0rd123!'` |
| `--hashes` / `-H` | String | Pass-the-Hash için NTLM karma dizesi (`LM:NT`). | `-H :31d6cfe0d16ae...` |
| `--use-kerberos` / `-k` | Bayrak | `KRB5CCNAME` ortam değişkenindeki Kerberos biletini kullanır. | `-k` |

---

## 3. Pratik Komut Örnekleri

### 3.1 Windows Ortamında Geçerli Oturum ile Tam BloodHound Keşfi
```cmd
:: Mevcut Windows oturumunun kimlik bilgileriyle tam keşif yapar ve BloodHound JSON'larını üretir
SOAPHound.exe --build-cache --output-directory C:\Windows\Temp\soaphound
```
* **Operasyon Adımı:** `SOAPHound.exe` çalıştırıldığında DNS üzerinden geçerli etki alanı denetleyicisini otomatik bulur, TCP 9389 üzerinden oturum açar ve kullanıcı, grup, bilgisayar, GPO nesnelerini toplar.

### 3.2 Linux Üzerinden Python ile NTLM Hash Kullanarak Keşif
```bash
# pySOAPHound ile Pass-the-Hash yöntemini kullanarak ADWS keşfi yapma
python3 pySOAPHound.py -d corp.local -u da_user -H 31d6cfe0d16ae931b73c59d7e0c089c0 \
  --dc-ip 10.10.10.10 --build-cache -o ./loot_soaphound
```

### 3.3 Yalnızca Belirli Bir OU Altındaki Yönetici Hesaplarını Hedefleme
```bash
# Geniş ağlarda gürültüyü kısmak için yalnızca Tier-0 OU'sunu sorgulama
python3 pySOAPHound.py -d corp.local -u jdoe -p 'Welcome123!' --dc-ip 10.10.10.10 \
  --search-base "OU=Tier0,DC=corp,DC=local" -o ./tier0_data
```

### 3.4 Çıktı Analizi ve BloodHound'a İçe Aktarma
Komut tamamlandığında belirtilen çıktı dizininde şu dosyalar oluşur:
```text
[+] Connecting to ADWS at dc01.corp.local:9389...
[+] Connected! Authenticated as CORP\jdoe via Kerberos.
[*] Enumerating containers and organizational units...
[*] Enumerating users (batch size: 500)... [Total: 1,420]
[*] Enumerating computers... [Total: 380]
[*] Enumerating domain groups and nested memberships... [Total: 215]
[*] Parsing ACL security descriptors and GPO links...
[+] Successfully generated BloodHound JSON files:
    - 20261014_users.json
    - 20261014_groups.json
    - 20261014_computers.json
    - 20261014_domains.json
```
Operatör bu JSON dosyalarını doğrudan BloodHound GUI veya BloodHound CE arayüzüne sürükle-bırak yöntemiyle yükleyebilir.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Çözüm ve Doğrulama Adımı |
|---|---|---|
| `EndpointNotFoundException: There was no endpoint listening at http://...:9389/` | Hedef sunucuda ADWS servisi durdurulmuştur veya aradaki güvenlik duvarı TCP 9389 portunu engellemektedir. | `Test-NetConnection -ComputerName <DC_IP> -Port 9389` ile port erişimini teyit edin. DC üzerinde `Active Directory Web Services` servisinin çalıştığını doğrulayın. |
| `MessageSecurityException: The security timestamp is invalid or clock skew too great` | İstemci ile Domain Controller arasındaki saat farkı **5 dakikadan fazladır**. | Linux makinenizde `ntpdate <DC_IP>` veya Windows makinenizde `w32tm /resync` çalıştırarak saatleri eşitleyin. |
| `FaultException: The server was unable to process the request due to an internal error` | Belirtilen Naming Context veya Search-Base DN sözdizimi hatalıdır. | `--search-base` parametresindeki etki alanı kökünü (`DC=corp,DC=local`) doğru formatta yazın. |
| `Request Too Large / Timeout during PullRequest` | Çok büyük etki alanlarında varsayılan 500 nesnelik paket boyutu WCF arabelleğini zorlamaktadır. | `--batch-size 200` veya `--batch-size 100` parametresi ile paket boyutunu küçültün. |
| `Authentication Failure / 401 Unauthorized` | Kimlik doğrulama parametrelerinde kullanıcı adı, parola veya FQDN uyuşmazlığı vardır. | Kullanıcı adını `user@corp.local` veya `CORP\user` formatında belirtin; hesabın kilitli olmadığını doğrulayın. |
| `BloodHound Import Error: Invalid JSON schema` | SOAPHound sürümü ile kullanılan BloodHound veritabanı şeması arasında versiyon uyuşmazlığı yaşanmıştır. | SOAPHound'un en güncel sürümünü kullanın veya BloodHound CE arayüzündeki toplu içe aktarma modülünü seçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler ve Olay Günlükleri (Event ID)
- **Windows Security Event ID 4624 (Logon Type 3):** ADWS servisine kimlik doğrulandığında DC üzerinde standart bir ağ oturumu kaydı oluşur. `LogonProcessName: Kerberos` veya `NtLmSsp` görünür.
- **ADWS Operational Logları:** `Applications and Services Logs -> Active Directory Web Services -> Operational` altında ADWS istekleri ve WCF oturumları kaydedilebilir (varsayılan olarak detaylı hata ayıklama seviyesi kapalıdır).
- **LDAP Denetimleri Atlatılır:** Security günlüğündeki **Event ID 1644** (Pahalı/Verimsiz LDAP aramaları) SOAPHound kullanımında **tetiklenmez**; çünkü arama LDAP arayüzünden değil, yerel servis çağrısı olarak DC'nin kendi içinden yürütülür.

### 5.2 Ağ ve EDR İmzaları
- **Ağ Seviyesinde TCP 9389 Trafiği:** Uç noktadan DC'ye doğru yoğun port 9389 trafiği akması, ağ analiz araçları (NDR) için güçlü bir korelasyon sinyalidir.
- **WCF HTTP User-Agent İmzası:** SOAP zarflarının HTTP başlıklarında `.NET WCF Client` imzası yer alır.

### 5.3 MITRE ATT&CK Eşleştirmesi
- **Taktik:** Discovery (TA0007), Defense Evasion (TA0005)
- **Teknik:** Account Discovery: Domain Account ([T1087.002](https://attack.mitre.org/techniques/T1087/002/))
- **İlişkili Teknik:** Permission Groups Discovery ([T1069.002](https://attack.mitre.org/techniques/T1069/002/)), Remote System Discovery ([T1018](https://attack.mitre.org/techniques/T1018/))

### 5.4 OPSEC Önerileri

| Risk Alanı | Tespit Seviyesi | Karşı Önlem / Strateji |
|---|---|---|
| **Ağ Portu (TCP 9389)** | Orta | Şirket içinde PowerShell remoting ve AD modülü sık kullanılıyorsa 9389 trafiği meşru görünür. Çok sessiz olmak için `--batch-size` küçültülmeli ve arama istekleri arasına gecikme konulmalıdır. |
| **Tam Etki Alanı Keşfi** | Orta-Yüksek | Tüm etki alanını bir kerede indirmek yerine, operasyonel olarak yalnızca hedef alınan belirli OU'lar sorgulanmalıdır. |

### 5.5 Savunma Karşılığı ve Mavi Takım Sıkılaştırması
- **Güvenlik Duvarı Sıkılaştırması:** Kullanıcı iş istasyonlarının (VLAN) etki alanı denetleyicilerine ait TCP 9389 portuna doğrudan erişmesi engellenmeli; bu port yalnızca yönetim sunucularına (PAW) açılmalıdır.
- **ADWS Servis İzleme:** DC'ler üzerinde `Microsoft.ActiveDirectory.WebServices.exe` sürecinin kaynak kullanımı ve bağlantı kurduğu istemci IP adresleri SIEM/EDR üzerinden izlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# Komut 1: Geçerli Windows oturumu ile anında tam BloodHound veri önbelleği oluşturma
SOAPHound.exe --build-cache -o C:\Windows\Temp\loot
```
* **Ne Yapar?:** Mevcut kullanıcı haklarıyla TCP 9389 üzerinden tüm AD nesnelerini çeker ve BloodHound JSON'larını üretir.
* **Ne Zaman Kullanılır?:** Ele geçirilmiş bir Windows iş istasyonunda LDAP alarmlarını tetiklemeden hızlı keşif gerektiğinde.
* **Parametreler:** `--build-cache`: Tam dizin taraması; `-o`: Çıktı klasörü.

```bash
# Komut 2: Linux üzerinden NTLM Hash kullanarak gizli ADWS keşfi yapma
python3 pySOAPHound.py -d corp.local -u user1 -H :<NTHASH> --dc-ip 10.10.10.10 --build-cache -o ./results
```
* **Ne Yapar?:** Pass-the-Hash tekniği ile ADWS servisine kimlik doğrular ve uzaktan tüm dizini indirir.
* **Ne Zaman Kullanılır?:** Parola bilinmediğinde veya Linux saldırı makinesinden iz bırakmadan keşif yapılacağında.
* **Parametreler:** `-H`: NTLM karması; `--dc-ip`: Hedef etki alanı denetleyicisi IP'si.

```bash
# Komut 3: Kerberos bilet önbelleği (ccache) kullanarak parolasız ADWS keşfi
export KRB5CCNAME=admin.ccache
python3 pySOAPHound.py -d corp.local -k --dc-ip 10.10.10.10 --build-cache -o ./kerb_loot
```
* **Ne Yapar?:** Mevcut Kerberos biletini (`admin.ccache`) kullanarak hiçbir kimlik bilgisi girmeden ADWS üzerinden keşif yürütür.
* **Ne Zaman Kullanılır?:** Pass-the-Ticket saldırısı sonrasında yüksek yetkili bilet ile gizli haritalama yaparken.
* **Parametreler:** `-k`: Kerberos kimlik doğrulamasını zorunlu kılar.

```bash
# Komut 4: Yalnızca belirli bir Kritik Yönetici OU'sunu hedefleyerek gürültüyü sınırlama
python3 pySOAPHound.py -d corp.local -u da_user -p 'Pass123' --dc-ip 10.10.10.10 --search-base "OU=Domain Admins,DC=corp,DC=local" -o ./da_only
```
* **Ne Yapar?:** Keşif kapsamını yalnızca belirtilen OU ile sınırlandırarak minimum ağ trafiği ve sorgu üretir.
* **Ne Zaman Kullanılır?:** Hedef odaklı yetki analizi yaparken ve tüm dizini taramanın riskli olduğu yüksek güvenlikli ağlarda.
* **Parametreler:** `--search-base`: Sorgu kapsamı DN'i.

```cmd
:: Komut 5: Sayfalama boyutunu (batch size) düşürerek EDR trafik alarmlarını atlatma
SOAPHound.exe --build-cache --batch-size 100 -o C:\temp\low_noise
```
* **Ne Yapar?:** Her SOAP paketindeki nesne sayısını 100 ile sınırlayarak büyük boyutlu veri transferi anomalisi oluşturmaz.
* **Ne Zaman Kullanılır?:** Ağ düzeyinde paket boyutu ve anomali tespiti yapan NDR sistemlerinin bulunduğu ortamlarda.
* **Parametreler:** `--batch-size 100`: Her çekme isteğinde en fazla 100 kayıt getirir.

```powershell
# Komut 6: Hedef DC üzerinde ADWS (Port 9389) servis erişilebilirliğini sessizce test etme
Test-NetConnection -ComputerName dc01.corp.local -Port 9389 -InformationLevel Detailed
```
* **Ne Yapar?:** Hedef etki alanı denetleyicisinde ADWS servis portunun açık ve erişilebilir olduğunu doğrular.
* **Ne Zaman Kullanılır?:** SOAPHound çalıştırmadan önce hedefte ADWS'in dinleyip dinlemediğini hızlıca anlamak için.
* **Parametreler:** `-Port 9389`: ADWS standart dinleme portu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [FalconForceTeam / SOAPHound](https://github.com/FalconForceTeam/SOAPHound)
- **FalconForce Araştırma Blogu:** [SOAPHound: Tool for Active Directory Enumeration via ADWS](https://falconforce.nl/)
- **Microsoft Learn:** [Active Directory Web Services (ADWS) Architecture & Overview](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd391908(v=ws.10))
- **MITRE ATT&CK Bilgi Bankası:** [Technique T1087.002 - Domain Account Discovery](https://attack.mitre.org/techniques/T1087/002/)

---

> **Önceki:** [← Spray-Passwords](./Spray-Passwords.md) · **Sonraki:** [Kategori 04: Zehirleme, MitM ve Zorlamalı Kimlik Doğrulama →](../Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md)
