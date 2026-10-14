# linWinPwn

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Lefy (@lefayjiss) tarafından geliştirilen; Linux ortamında çalışan, Active Directory sızma testlerinde kullanılan onlarca açık kaynaklı keşif, sertifika analizi (AD CS) ve istismar aracını tek bir çatı altında modüler olarak zincirleyen gelişmiş bash otomasyon aracı.

---

## 1. Genel Bakış ve Amaç

**linWinPwn**, kırmızı takım operatörlerinin ve sızma testi uzmanlarının harici veya dahili ağ testlerinde karşılaştıkları Active Directory altyapısını Linux tabanlı bir saldırı makinesinden (Kali Linux, Parrot OS, BlackArch vb.) çok hızlı ve sistematik bir şekilde haritalandırmasını sağlayan güçlü bir otomasyon betiğidir. Araç; Impacket, NetExec (nxc), BloodHound.py, Certipy, ldapdomaindump, adidnsdump, Coercer, PetitPotam ve smbclient gibi onlarca saygın güvenlik aracını bir orkestrasyon motoru gibi yönetir.

linWinPwn'ın temel tasarım amacı; operatörün tek tek 15-20 farklı aracı elle çalıştırması, komut satırı parametrelerini hatırlaması ve çıktıları birleştirmesi yerine, tek bir komutla tüm keşif, parola püskürtme, Kerberos zafiyet tespiti, zorlamalı kimlik doğrulama (coercion) ve Active Directory Sertifika Servisleri (AD CS ESC1-ESC13) denetimini otomatize etmektir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              LINWINPWN MİMARİSİ                                   |
+-----------------------------------------------------------------------------------+
                                          |
                    [Operatör / Kali Linux / SOCKS Proxy]
                     ./linWinPwn.sh -M <Module> [Bayraklar]
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        linWinPwn Orkestrasyon Motoru                              |
|   (Parametre Doğrulama, Bağımlılık Kontrolü, Paralel İş Parçacıkları)             |
+-----------------------------------------------------------------------------------+
                                          |
        +------------------+--------------+------------------+------------------+
        |                  |                                 |                  |
        v                  v                                 v                  v
+---------------+  +---------------+                 +---------------+  +---------------+
| NetExec / CME |  | Impacket Mod. |                 |    Certipy    |  | BloodHound.py |
| - SMB Signing |  | - GetUserSPNs |                 | - ESC1 - ESC13|  | - Dizin Verisi|
| - Null Session|  | - GetNPUsers  |                 | - CA Keşfi    |  | - Graf JSON   |
| - PasswordSpr.|  | - secretsdump |                 | - Şablon Denet|  | - ACL Analizi |
+---------------+  +---------------+                 +---------------+  +---------------+
        |                  |                                 |                  |
        +------------------+--------------+------------------+------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Protokol ve İletişim Katmanı                               |
|        [SMB: 445]   [LDAP/S: 389/636]   [Kerberos: 88]   [RPC: 135]   [HTTP]      |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Hedef Active Directory Ortamı                              |
|          Domain Controllers, Sertifika Sunucuları (CA), Üye Sistemler             |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                         Yapılandırılmış Rapor Çıktıları                           |
|      Klasör: linWinPwn/reports/<Domain>/<Tarih>/ (Metin, JSON, Grep, ZIP)        |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi Avantajı |
|---|---|---|
| **Tek Hamlede Tam Denetim** | 10'dan fazla bağımsız aracı otomatik sıralı çalıştırır. | Keşif süresini saatlerden dakikalara indirir; hiçbir kritik vektörü atlamaz. |
| **AD CS Zafiyet Taraması** | Certipy motorunu entegre ederek ESC1'den ESC13'e kadar tüm açık şablonları bulur. | Domain Admin yetkisine giden en hızlı sertifika saldırı yollarını gösterir. |
| **Kimlik Doğrulama Çeşitliliği**| Açık metin parola, NTLM Hash (Pass-the-Hash) ve Anonim (Null Session) destekler. | Her erişim seviyesine uygun esnek keşif senaryosu sunar. |
| **Proxychains & Tünelleme** | C2 veya pivot tünelleri (`-s` socks proxy) üzerinden kusursuz çalışır. | İç ağa doğrudan IP erişimi olmadan uzaktan pivoting yapmayı kolaylaştırır. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | linWinPwn | NetExec (nxc) | AutoRecon | ADRecon | BloodHound.py |
|---|---|---|---|---|---|
| **Araç Türü** | Orkestrasyon / Zincir | Çok Protokollü Pentest | Port / Ağ Tarayıcı | Denetim / Excel | Graf Toplayıcı |
| **Kapsam** | Keşif + İstismar + ADCS | Keşif + Yayılma | Genel Port / Servis | Sadece Dizin Keşfi | Sadece Graf Verisi |
| **AD CS Desteği** | **Tam (Certipy Entegre)**| Kısmi | Yok | Kısmi | Var (SharpHound) |
| **Çalışma Platformu**| Linux (Bash) | Linux / Windows | Linux (Python) | Windows (PS) | Linux / Windows |
| **OPSEC Gürültüsü** | **Çok Yüksek** | Orta | Çok Yüksek | Yüksek | Düşük / Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

linWinPwn bir bash betiğidir ve çalıştırılmadan önce yürütme izni verilmelidir (`chmod +x linWinPwn.sh`):

```bash
./linWinPwn.sh -M [modül] -t [hedef_dc_ip] [kimlik_parametreleri] [seçenekler]
```

### 2.1 Temel Çalışma Modülleri (`-M` Bayrağı)

| Modül Adı | Açıklama | Dahili Çalıştırılan Araçlar |
|---|---|---|
| `ad_dc_only` | Yalnızca Etki Alanı Denetleyicisi odaklı hızlı keşif yapar. | NetExec (SMB/LDAP), ldapdomaindump, GetUserSPNs. |
| `curse_all_checks` | **Tam Kapsamlı:** Ağdaki tüm host'ları, DC'yi, AD CS'yi ve kullanıcıları baştan sona tarar. | NetExec, Impacket, Certipy, BloodHound, Coercer. |
| `ad_cs` | Yalnızca Active Directory Sertifika Servisleri (AD CS) zafiyetlerini arar. | Certipy (find, vulnerable template check). |
| `user_spray` | Etki alanı kilitleme eşiğini dikkate alarak parola püskürtmesi yapar. | NetExec / Kerbrute. |
| `interactive` | Hangi adımların çalıştırılacağını adım adım soran etkileşimli menü. | Operatör seçimine dayalı. |

### 2.2 Kimlik Doğrulama Parametreleri

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-d`, `--domain` | Hedef Active Directory etki alanı adı. | `-d "corp.local"` |
| `-t`, `--target-ip` | Hedef Etki Alanı Denetleyicisi (DC) IP adresi. | `-t "10.10.10.10"` |
| `-u`, `--username` | Kimlik doğrulamada kullanılacak kullanıcı adı. | `-u "jdoe"` |
| `-p`, `--password` | İlgili kullanıcının açık metin parolası. | `-p "Parola123!"` |
| `-H`, `--hash` | NTLM kimlik doğrulama hash'i (Pass-the-Hash). | `-H "e19ccf75ee54e06b06a53264f92fc504"` |
| `-o`, `--output-dir`| Raporların ve çıktıların kaydedileceği klasör. | `-o "/opt/recon/reports"` |

### 2.3 Gelişmiş Bayraklar ve Tünelleme

| Parametre | Açıklama |
|---|---|
| `-s`, `--proxy` | Proxychains veya SOCKS proxy üzerinden çalıştırma (`socks5://127.0.0.1:1080`). |
| `-k`, `--kerberos` | NTLM yerine Kerberos kimlik doğrulaması kullanma. |
| `--spn` | Yalnızca Kerberoasting odaklı SPN sorgularını tetikler. |
| `--asreproast` | Yalnızca AS-REP Roasting zafiyetli kullanıcıları çeker. |
| `--bloodhound` | Dizin verilerini BloodHound uyumlu JSON dosyaları olarak dökme. |

### 2.4 linWinPwn Tarafından Zincirlenen Alt Araçlar ve Saldırı Kontrolleri

| Dahili Araç | Protokol / Port | Gerçekleştirilen Operasyonel Kontroller |
|---|---|---|
| **NetExec (nxc)** | SMB (445), LDAP (389) | SMB İmzalama (Signing) durumu, Null Session, Password Policy, Spidering. |
| **ldapdomaindump** | LDAP (389 / 636) | Dizin nesnelerinin (kullanıcılar, bilgisayarlar, OU'lar) HTML/JSON dökümü. |
| **Impacket (GetUserSPNs)** | Kerberos (88) / LDAP | Kerberoasting için aktif SPN kayıtlarının ve TGS biletlerinin çekilmesi. |
| **Impacket (GetNPUsers)** | Kerberos (88) | AS-REP Roasting için DONT_REQ_PREAUTH bayraklı hesapların tespiti. |
| **Certipy** | LDAP, RPC, HTTP | AD CS Sertifika Otoritesi (CA) keşfi, ESC1'den ESC13'e zafiyet analizi. |
| **BloodHound.py** | LDAP, SMB | Neo4j graf veritabanı için JSON dosyalarının (`users.json`, `computers.json` vb.) üretilmesi. |
| **Coercer / PetitPotam** | MS-EFSRPC / MS-RPRN | Etki alanı denetleyicisi ve sunucuları sahte SMB/HTTP dinleyicisine zorlama. |
| **adidnsdump** | LDAP (389) | Active Directory Integrated DNS (ADIDNS) kayıtlarının tam dökümü. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Anonim / Null Session ile Başlangıç Keşfi

Ağda hiçbir kullanıcı adı veya parola bilinmiyorken, DC üzerinde anonim veya misafir erişimiyle bilgi toplama:

```bash
./linWinPwn.sh -M ad_dc_only -t 10.10.10.10 -d corp.local -u '' -p ''
```

**Konsol Çıktısı Analizi:**

```text
[*] Starting linWinPwn - Active Directory Automation Engine
[*] Target Domain: corp.local (10.10.10.10)
[*] Mode: ad_dc_only | Auth: Anonymous / Null Session
----------------------------------------------------------------------
[+] Testing SMB Anonymous Connection on 10.10.10.10... [SUCCESS]
[+] SMB Signing: False (Vulnerable to NTLM Relay!)
[+] Domain SID: S-1-5-21-3928172635-182736452-91827364
[*] Testing LDAP Anonymous Binding... [FAILED - Requires NTLM/Kerberos]
[*] Testing RPC Null Session via NetExec...
[+] Found Domain Name: CORP
[+] Password Policy: MinLength: 8, LockoutThreshold: 5, LockoutDuration: 30m
[+] Found 120 Usernames via RPC ms-ds-enums! Saved to: /reports/users_enum.txt
```
*Analiz: Anonim SMB üzerinden SMB Signing'in kapalı olduğu ve RPC null session ile 120 adet kullanıcı adının başarıyla çekildiği tespit edilmiştir. Bu kullanıcı listesi doğrudan Senaryo 4'te parola püskürtmeye girdi olarak verilebilir.*

### Senaryo 2: Standart Kullanıcı Kimliği ile Tam Kapsamlı Keşif (`curse_all_checks`)

Düşük yetkili bir etki alanı kullanıcısı ele geçirildiğinde tüm AD mimarisini, AD CS'yi ve BloodHound verilerini tek hamlede dökme:

```bash
./linWinPwn.sh -M curse_all_checks -t 10.10.10.10 -d corp.local -u ahmet -p 'Parola123!'
```

### Senaryo 3: Pass-the-Hash ile Yalnızca AD CS Sertifika Zafiyetlerini Denetleme

Ele geçirilen bir NTLM hash ile etki alanındaki tüm Sertifika Otoritelerini (CA) ve ESC1-ESC13 açıklarını tarama:

```bash
./linWinPwn.sh -M ad_cs -t 10.10.10.10 -d corp.local -u mehmet -H 8846f7eaee8fb117ad06bdd830b7586c
```

### Senaryo 4: Güvenli ve Kilitlenmeye Karşı Korumalı Parola Püskürtme

Önceden toplanmış kullanıcı listesine, etki alanı kilitlenme eşiğini (Lockout Threshold) aşmadan 1 adet parola deneme:

```bash
./linWinPwn.sh -M user_spray -t 10.10.10.10 -d corp.local -p 'Spring2026!'
```

### Senaryo 5: C2 Pivot / SOCKS5 Proxy Üzerinden linWinPwn Çalıştırma

İç ağdaki bir C2 beacon'ı üzerinden 1080 portunda açılan dinamik SOCKS proxy üzerinden tüm testleri tünelleme:

```bash
./linWinPwn.sh -M ad_dc_only -t 192.168.1.10 -d corp.local -u pentest -p 'Secret123!' -s socks5://127.0.0.1:1080
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[!] Error: Required tool 'netexec' or 'crackmapexec' not found in PATH` | linWinPwn'ın bağımlı olduğu alt araç sistemde kurulu değil veya sanal ortamda (venv) kaldı. | Aracı çalıştırmadan önce `pipx install netexec` veya `install.sh` betiği ile tüm bağımlılıkları sisteme yükleyin. |
| `/bin/bash^M: bad interpreter: No such file or directory` | Betik Windows ortamında düzenlenmiş veya Git CRLF satır sonu formatıyla klonlanmış. | `dos2unix linWinPwn.sh` komutunu çalıştırarak satır sonlarını Linux formatına (LF) dönüştürün. |
| `Certipy: command failed / unknown option` | Sistemde Certipy v4 yerine Certipy v3 veya uyumsuz bir sürüm yüklü. | `pip install --upgrade certipy-ad` ile Certipy'ı en güncel sürüme yükseltin. |
| `[!] LDAP connection timed out on port 389` | DC güvenlik duvarı doğrudan LDAP erişimini engelliyor veya routing problemi var. | IP ve port erişimini `nc -nvz <DC_IP> 389` ile kontrol edin. Gerekirse `--ssl` bayrağı ile port 636 LDAPS deneyin. |
| `STATUS_ACCOUNT_LOCKED_OUT during user_spray` | Parola püskürtme modülü çalışırken kilitlenme eşiği aşıldı. | Parola denemeleri arasındaki uyku süresini (sleep) artırın ve kilitlenme politikasını (`Password Policy`) önce `ad_dc_only` ile doğrulayın. |
| `BloodHound.py ingestion failed: JSON decode error` | DC tarafındaki şema çözümlemesinde beklenmeyen bir Unicode karakter veya bozuk nesne ile karşılaşıldı. | BloodHound modülünü tek başına `--bloodhound -d domain -u user -p pass` ile hata ayıklama modunda çalıştırın. |
| `Certipy ESC8: Web Enrollment HTTP connection failed` | AD CS Web Enrollment (HTTP) servisi kurulu değil veya NTLM Relay kısıtlaması mevcut. | Yalnızca RPC tabanlı şablon zafiyetlerine (`ESC1-ESC4`) odaklanın veya HTTP portunu (80/443) doğrulayın. |
| `Proxychains broken pipe / SOCKS handshake failure` | SOCKS proxy tüneli üzerinden DNS çözümlenemedi veya C2 bağlantısı koptu. | `/etc/proxychains.conf` dosyasında `proxy_dns` seçeneğini aktif edin ve DC IP'sini `/etc/hosts` dosyasına kaydedin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

linWinPwn, doğası gereği **son derece gürültülü (noisy)** bir araçtır. Otomatize edilmiş yapısı nedeniyle savunma ekipleri ve SIEM/SOAR platformları için yüksek görünürlük üretir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4624 & 4625 (Logon Success / Failure):**
   - Özellikle `user_spray` veya `curse_all_checks` çalıştırıldığında kısa süre içinde onlarca farklı kullanıcı adına yapılan başarısız oturum açma denemeleri (Event ID 4625) SIEM alarmlarını tetikler.
2. **Windows Security Event ID 4768 & 4769 (Kerberos Ticket Operations):**
   - Kerberoast ve AS-REP Roasting adımlarında onlarca hesap için arka arkaya `RC4_HMAC` (0x17) şifrelemesiyle TGS/TGT talep edilir.
3. **RPC Named Pipe Bağlantıları (Sysmon Event ID 17 / 18):**
   - Coercion modülleri çalıştığında `\pipe\spoolss` (SpoolSample) ve `\pipe\efsrpc` (PetitPotam) borularına şüpheli RPC bağlantıları açılır.
4. **Active Directory Web Services & LDAP Denetimi:**
   - ldapdomaindump ve BloodHound çalıştırıldığında binlerce nesne saniyeler içinde taranır (`Event ID 1644`).

### 5.2 Ağ ve IDS İmzaları

- **Snort / Suricata İmzaları:** Impacket ve Certipy'ın varsayılan HTTP/RPC kullanıcı ajanları ve paket başlıkları.
- **Port Tarama Deseni:** Kısa süre içerisinde 88, 135, 139, 389, 445, 636, 3268 ve 5985 portlarına ardışık TCP SYN paketleri gönderilmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | linWinPwn Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | LDAP ve RPC kullanıcı envanteri |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Güvenlik grupları ve üyelik haritalama |
| **T1110.003** | Brute Force: Password Spraying | `user_spray` modülü |
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | `GetUserSPNs` entegrasyonu |
| **T1558.004** | Steal or Forge Kerberos Tickets: AS-REP Roasting | `GetNPUsers` entegrasyonu |
| **T1649** | Steal or Forge Authentication Certificates | `ad_cs` (Certipy ESC1-ESC13 denetimi) |
| **T1187** | Forced Authentication | Coercer / PetitPotam zorlamalı kimlik doğrulama |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Kitlesel Alarm Fırtınası** | `curse_all_checks` modülünün tüm araçları aynı anda çalıştırması. | Kırmızı takım sızma operasyonlarında **asla** `curse_all_checks` kullanmayın; yalnızca hedefli modülleri (`ad_dc_only`, `ad_cs`) tekil çalıştırın. |
| **Hesap Kilitlenmesi (Lockout)** | `user_spray` sırasında bilinmeyen kilitlenme politikasının aşılması. | Püskürtme yapmadan önce mutlaka etki alanı kilitlenme politikasını (`LockoutThreshold`) elle doğrulayın. |
| **Ağ Taraması Tespiti** | Tüm IP bloklarına 445 ve 135 portlarından ping/probe atılması. | Taramayı belirli bir hedef sunucu (`-t <DC_IP>`) ile sınırlayın, tüm subnet'i taratmayın. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

linWinPwn kaynaklı kitle keşif aktivitelerini tespit eden örnek Splunk / ELK korelasyon mantığı:

```text
index=wineventlog EventCode=4624 Logon_Type=3 
| stats count dc(TargetUserName) as UniqueUsers by Source_Network_Address
| where UniqueUsers > 20 and count > 100
```
*Açıklama: Tek bir kaynak IP adresinden kısa sürede 20'den fazla farklı kullanıcı adıyla Type 3 oturumu açılması linWinPwn veya benzeri otomasyonların güçlü bir göstergesidir.*

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Yalnızca Etki Alanı Denetleyicisi Keşfi (Düşük Gürültü)
./linWinPwn.sh -M ad_dc_only -t 10.10.10.10 -d corp.local -u user -p pass
```
- **Ne Yapar?** Yalnızca DC'ye bağlanarak LDAP, SMB ve RPC üzerinden temel etki alanı bilgilerini çeker.
- **Ne Zaman Kullanılır?** İlk erişim sonrası ağdaki diğer bilgisayarları rahatsız etmeden hızlıca DC envanteri almak için.
- **Parametreler:** `-M ad_dc_only` hedefi DC ile sınırlar; `-t` DC IP adresi.

```bash
# 2. Active Directory Sertifika Servisleri (AD CS) Zafiyet Taraması
./linWinPwn.sh -M ad_cs -t 10.10.10.10 -d corp.local -u user -p pass
```
- **Ne Yapar?** Certipy motorunu çalıştırarak ESC1'den ESC13'e kadar tüm zafiyetli şablonları listeler.
- **Ne Zaman Kullanılır?** Sertifika tabanlı yetki yükseltme (privilege escalation) fırsatlarını ararken.
- **Parametreler:** `-M ad_cs` yalnızca sertifika kontrollerini devreye sokar.

```bash
# 3. Anonim (Null Session) ile Kullanıcı ve Politika Toplama
./linWinPwn.sh -M ad_dc_only -t 10.10.10.10 -d corp.local -u '' -p ''
```
- **Ne Yapar?** Kimlik bilgisi olmadan SMB ve RPC üzerinden etki alanı politikasını ve kullanıcı listesini arar.
- **Ne Zaman Kullanılır?** Ağda hiçbir hesap bilgisi bulunmadığında başlangıç noktası bulmak için.
- **Parametreler:** `-u '' -p ''` anonim oturum bayrağıdır.

```bash
# 4. Pass-the-Hash ile Tam Denetim Çalıştırma
./linWinPwn.sh -M curse_all_checks -t 10.10.10.10 -d corp.local -u admin -H e19ccf...
```
- **Ne Yapar?** NTLM hash kullanarak tüm keşif ve denetim modüllerini sırayla icra eder.
- **Ne Zaman Kullanılır?** Açık metin parolası olmayan yüksek yetkili hesapla tam sızma testi yaparken.
- **Parametreler:** `-H` NTLM hash'i; `-M curse_all_checks` tam tarama modu.

```bash
# 5. Güvenli Parola Püskürtme Modülü
./linWinPwn.sh -M user_spray -t 10.10.10.10 -d corp.local -p 'Winter2026!'
```
- **Ne Yapar?** Belirtilen parolayı etki alanındaki tüm kullanıcılara hesapları kilitlemeden sırayla dener.
- **Ne Zaman Kullanılır?** Varsayılan veya dönemsel parola kullanan hesapları tespit etmek için.
- **Parametreler:** `-M user_spray` parola püskürtme motoru; `-p` denenecek tekil parola.

```bash
# 6. SOCKS5 Proxy / C2 Pivot Üzerinden Çalıştırma
./linWinPwn.sh -M ad_dc_only -t 10.10.10.10 -d corp.local -u user -p pass -s socks5://127.0.0.1:1080
```
- **Ne Yapar?** Tüm trafiği belirtilen yerel SOCKS tüneli üzerinden hedef etki alanına iletir.
- **Ne Zaman Kullanılır?** İç ağa bir C2 oturumu üzerinden pivot yapıldığında.
- **Parametreler:** `-s` proxy protokolü ve adresi.

```bash
# 7. Etkileşimli (Menü Tabanlı) Çalıştırma
./linWinPwn.sh -M interactive -t 10.10.10.10 -d corp.local
```
- **Ne Yapar?** Konsolda interaktif bir metin menüsü açarak operatöre adım adım test seçtirir.
- **Ne Zaman Kullanılır?** Hangi aracın çalıştırılacağı üzerinde anlık tam kontrol istendiğinde.
- **Parametreler:** `-M interactive` menü modunu etkinleştirir.

```bash
# 8. Özel Çıktı Klasörüne Raporlama
./linWinPwn.sh -M ad_dc_only -t 10.10.10.10 -d corp.local -u user -p pass -o /opt/reports/client_ad
```
- **Ne Yapar?** Oluşturulan tüm metin, JSON ve özet raporları belirtilen özel dizine yazar.
- **Ne Zaman Kullanılır?** Birden fazla müşteri veya sızma testi projesini organize ederken.
- **Parametreler:** `-o` çıktı klasörü yolu.

```bash
# 9. Kerberos ccache Biletiyle Parolasız linWinPwn Çalıştırma
export KRB5CCNAME=/opt/tickets/admin.ccache
./linWinPwn.sh -M ad_dc_only -t dc01.corp.local -d corp.local -k
```
- **Ne Yapar?** NTLM yerine Linux ortamındaki Kerberos biletini kullanarak sessizce DC keşfi yapar.
- **Ne Zaman Kullanılır?** NTLM kimlik doğrulamasının loglandığı veya engellendiği ortamlarda.
- **Parametreler:** `-k` Kerberos modunu açar; `-t` DC FQDN adresi.

```bash
# 10. Yalnızca BloodHound Veri Toplama Modunu Tetikleme
./linWinPwn.sh -t 10.10.10.10 -d corp.local -u user -p pass --bloodhound
```
- **Ne Yapar?** Diğer modülleri atlayarak yalnızca BloodHound.py toplayıcısını çalıştırır ve ZIP üretir.
- **Ne Zaman Kullanılır?** linWinPwn içerisinden hızlıca BloodHound CE için JSON paketi almak istendiğinde.
- **Parametreler:** `--bloodhound` bayrağı BloodHound motorunu aktif eder.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [lefayjiss / linWinPwn](https://github.com/lefayjiss/linWinPwn)
- **Certipy Projesi:** [ly4k / Certipy](https://github.com/ly4k/Certipy)
- **NetExec (Ex-CrackMapExec):** [Pennywiese / NetExec](https://github.com/Pennywiese/NetExec)
- **MITRE ATT&CK Matrix:** [Enterprise Matrix - Discovery](https://attack.mitre.org/tactics/TA0007/)

---

> **Önceki:** [← ADRecon](./ADRecon.md) · **Sonraki:** [ldapdomaindump →](./ldapdomaindump.md)
