# enum4linux-ng

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Python tabanlı yeni nesil bilgi toplama aracı; SMB, RPC, LDAP ve NetBIOS verilerini otomatik çıkarma.

---

## 1. Genel Bakış ve Amaç

`enum4linux-ng`, Windows ve Samba sistemlerinden bilgi toplamak amacıyla geliştirilmiş klasik Perl tabanlı `enum4linux` aracının Python 3 ile sıfırdan yazılmış modern, hızlı ve çok daha kararlı ardılıdır. Bir sızma testinin keşif (reconnaissance) fazında hedef etki alanı veya üye sunucu hakkında tek bir komutla en kapsamlı resmi çeken "hepsi bir arada" (all-in-one) bilgi toplama motorudur.

Eski Perl sürümünün getirdiği yavaşlık, karmaşık bağımlılıklar ve modern SMBv2/v3 protokolleriyle yaşanan uyumsuzluklar, `enum4linux-ng` ile Impacket, ldap3 ve smbprotocol kütüphaneleri doğrudan entegre edilerek çözülmüştür. Araç, hedefteki Windows veya Samba sunucunun güvenlik konfigürasyonunu, kullanıcı hesaplarını, paylaşım izinlerini ve parola kurallarını saniyeler içinde haritalar.

### Protokol ve Çalışma Prensibi

`enum4linux-ng`, hedef makineye karşı birden fazla protokol üzerinden eşzamanlı ve kademeli sorgular yürütür:

```
                  ┌───────────────────────────────┐
                  │        enum4linux-ng          │
                  │   (Python 3 Recon Engine)     │
                  └──────────────┬────────────────┘
                                 │
         ┌───────────────┬───────┴───────┬───────────────┐
         │ (UDP 137)     │ (TCP 445/139) │ (TCP 445)     │ (TCP 389/636)
         ▼               ▼               ▼               ▼
   [ NetBIOS ]      [ SMBv1-v3 ]     [ MS-RPC ]      [ LDAP/S ]
   - Workgroup      - OS & Sürüm     - SAMR (User)   - Dizin Ağacı
   - Hostname       - Paylaşımlar    - LSA (Policy)  - OU & Gruplar
   - Domain Adı     - İzin Taraması  - RID Cycling   - SPN Arama
```

1. **NetBIOS Keşfi (UDP 137):** Hedef sistemin NetBIOS adını, çalışma grubunu (Workgroup) ve etki alanı adını çözer.
2. **SMB Numaralandırma (TCP 445/139):** Hedef işletim sistemi sürümünü, SMB signing durumunu ve tüm açık ağ paylaşımlarını (`C$`, `ADMIN$`, `SYSVOL`, özel klasörler) tespit eder; okuma/yazma izinlerini sınar.
3. **MS-RPC Üzerinden Kimlik Hasadı (Named Pipes):** `\pipe\samr`, `\pipe\lsarpc` ve `\pipe\srvsvc` boru hatlarını kullanarak etki alanı kullanıcılarını, gruplarını, parola kilitleme politikasını sorgular ve RID Cycling uygular.
4. **LDAP Keşfi (TCP 389/636):** Hedef bir Etki Alanı Denetleyicisi (DC) ise doğrudan LDAP sorguları ile dizin nesnelerini döker.

### Modül Matrisi ve Protokol Eşleştirmesi

| Modül Adı | Bayrak | Taşıyıcı Protokol | Windows Fonksiyonu / Arka Plan Çağrısı | Çıkarılan Kritik Veri |
|---|---|---|---|---|
| **NetBIOS Info** | `-i` | UDP 137 | NetBIOS Node Status Request | Bilgisayar adı, Workgroup/Domain adı, MAC |
| **SMB Info** | `-I` | TCP 445/139 | SMB Negotiate & Session Setup | İşletim sistemi sürümü, Build no, SMB signing |
| **Users** | `-U` | SMB / LDAP | `SamrEnumerateUsersInDomain` / LDAP search | Tüm kullanıcı hesapları, RID'ler, açıklamalar |
| **Groups** | `-G` | SMB / LDAP | `SamrEnumerateGroupsInDomain` | Güvenlik grupları ve grup üyeleri listesi |
| **Shares** | `-S` | TCP 445 | `NetShareEnumAll` & SMB TreeConnect | Paylaşım listesi, açıklamalar, disk yolları |
| **Share Check** | `-C` | TCP 445 | `CreateFile` / `DeleteFile` (İzin Sınaması) | Paylaşımlarda READ, WRITE veya NO ACCESS durumu |
| **Password Policy** | `-P` | MS-SAMR | `SamrQueryInformationDomain` | Min parola boyutu, kilitleme eşiği, geçmiş |
| **RID Cycling** | `-R` | MS-LSAT / SAMR | `LsarLookupSids` / `SamrLookupRids` | Kullanıcı listesi kapalıyken brute-force kullanıcı avı |
| **Domain Trusts** | `-T` | MS-LSAD / Netlogon | `DsRcvEnumDomainTrusts` | Orman ve etki alanı güven ilişkileri |
| **Sessions** | `-e` | MS-SRVS | `NetSessionEnum` / `NetWkstaUserEnum` | Sunucuda oturum açmış aktif kullanıcılar |
| **Printers** | `-p` | MS-RPRN | `RpcEnumPrinters` | Ağda paylaşılan yazıcılar (PrintNightmare yüzeyi) |

### Neden Önemli?

| Kullanım Senaryosu | Operasyonel Katkı |
|---|---|
| **Sıfır Bilgi (Black-Box) Keşif** | Parolasız (Null/Guest) oturum açarak tüm kullanıcı adlarını ve parola politikasını sızdırır. |
| **Parola Püskürtme Öncesi Hazırlık** | Parola kilitleme eşiğini (`Lockout Threshold`) öğrenerek hesap kilitlenmelerini önler; geçerli kullanıcı listesini çıkarır. |
| **RID Cycling ile Gizli Hesap Tespiti** | LDAP'ta listelenmeyen veya gizlenmiş yerel/etki alanı hesaplarını RID (Relative Identifier) döngüsüyle yakalar. |
| **Yazılabilir Paylaşım Tespiti** | Zararlı DLL, SCF veya zararlı script bırakılabilecek yazılabilir alanları otomatik listeler. |
| **CI/CD ve Raporlama Entegrasyonu** | Çıktıları doğrudan JSON ve YAML formatlarında üreterek diğer otomasyon araçlarına veri sağlar. |

### enum4linux vs enum4linux-ng Karşılaştırması

| Özellik | Eski enum4linux (Perl) | enum4linux-ng (Python 3) |
|---|---|---|
| **Geliştirme Dili** | Perl (Eski bağımlılıklar) | Python 3 (Modern Impacket & ldap3) |
| **SMB Desteği** | Çoğunlukla SMBv1 odaklı | SMBv1, SMBv2 ve SMBv3 tam destek |
| **Çalışma Hızı** | Yavaş (her komut için yeni process) | Çok Hızlı (optimize soket ve kütüphane çağrıları) |
| **Çıktı Formatı** | Yalnızca düz metin stdout | Renkli stdout, JSON (`-oJ`), YAML (`-oY`), Metin (`-oA`) |
| **Pass-the-Hash (PTH)** | ❌ Doğrudan destek yok | ✅ `-H` parametresi ile yerleşik NTLM Hash desteği |
| **Protokol Filtreleme** | Sınırlı | ✅ `-As` (yalnız SMB), `-Ar` (RPC), `-Al` (LDAP) |
| **Hata Yönetimi** | Beklenmeyen çökmeler | Ayrıştırılmış hata kodları ve zaman aşımı kontrolü |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```bash
enum4linux-ng [seçenekler] <hedef_IP_veya_FQDN>
```

### Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Uzun Adı | Açıklama | Örnek |
|---|---|---|---|
| `-u` | `--user` | Kimlik doğrulamada kullanılacak kullanıcı adı | `-u 'j.doe'` |
| `-p` | `--password` | Kullanıcı parolası | `-p 'P@ssw0rd123'` |
| `-d` | `--domain` | Hedef NetBIOS etki alanı veya çalışma grubu adı | `-d 'CORP'` |
| `-H` | `--hashes` | Pass-the-Hash için NTLM hash (`LM:NT` veya `:NT`) | `-H ':31d6cfe0d16ae931b73c59d7e0c089c0'` |
| `-k` | `--kerberos` | Kerberos kimlik doğrulaması kullan (`KRB5CCNAME`) | `-k` |
| `-w` | `--workgroup` | İstemci çalışma grubu belirtme | `-w 'WORKGROUP'` |
| `-s` | `--shares-file` | Taranacak özel paylaşım listesi dosyası | `-s /opt/shares.txt` |
| `--no-random-auth`| `--no-random-auth`| Kimlik doğrulama testlerinde rastgele hesaplar yerine sadece belirtilen hesabı dener | `--no-random-auth` |

### Modül ve Numaralandırma Seçenekleri

| Parametre | Açıklama |
|---|---|
| `-A`, `--all` | Tüm numaralandırma modüllerini sırayla çalıştırır (En kapsamlı tarama) |
| `-As` | Yalnızca SMB tabanlı modülleri çalıştırır |
| `-Ar` | Yalnızca RPC tabanlı modülleri çalıştırır |
| `-Al` | Yalnızca LDAP tabanlı modülleri çalıştırır |
| `-U`, `--users` | Kullanıcı hesaplarını listeler (RPC SAMR / LDAP) |
| `-G`, `--groups` | Grupları ve grup üyeliklerini listeler |
| `-S`, `--shares` | Paylaşımları listeler ve erişim izinlerini test eder |
| `-C`, `--check-shares`| Paylaşımların yazılabilirliğini geçici dosya oluşturarak test eder |
| `-P`, `--pass-pol` | Etki alanı / yerel parola politikasını çeker (Kilitleme eşiği, min uzunluk vb.) |
| `-i`, `--netbios` | NetBIOS üzerinden sistem bilgilerini sorgular |
| `-I`, `--smb-info` | SMB üzerinden işletim sistemi ve sürüm bilgisini çeker |
| `-L`, `--ldap-info` | LDAP RootDSE ve temel dizin bilgilerini sorgular |
| `-T`, `--trusts` | Etki alanı güven ilişkilerini (Domain Trusts) listeler |
| `-e`, `--sessions` | Oturum açmış aktif kullanıcıları (Logged-on users) listeler |
| `-p`, `--printers` | Paylaşılan yazıcıları sorgular |
| `-R`, `--rid-cycling` | Belirtilen aralıkta RID döngüsü yaparak kullanıcı/grup arar |

### Çıktı ve Ağ Parametreleri

| Parametre | Açıklama | Örnek |
|---|---|---|
| `-oA` | Tüm formatlarda (JSON, YAML, TXT) dosyalara kaydeder | `-oA /root/recon_dc01` |
| `-oJ` | Çıktıyı JSON dosyasına yazar | `-oJ dc01_result.json` |
| `-oY` | Çıktıyı YAML formatında kaydeder | `-oY dc01_result.yaml` |
| `-v`, `--verbose` | Ayrıntılı hata ve debug çıktılarını gösterir | `-v` |
| `--timeout` | Soket zaman aşımı süresi (saniye, varsayılan: 10) | `--timeout 5` |
| `--smb-version` | Kullanılacak SMB sürümünü zorlar (1, 2, 3) | `--smb-version 2` |
| `--port` | SMB portunu özelleştirir (Varsayılan: 445) | `--port 445` |

---

## 3. Pratik Komut Örnekleri

### 3.1 Anonim / Null Session ile Hızlı Keşif ve Çıktı Analizi
Hedef sistemde hiçbir kimlik bilgisi girmeden ilk temas keşfi yapılır:

```bash
enum4linux-ng -A 192.168.1.10
```

**Gerçekçi Konsol Çıktı Analizi:**
```text
[*] Target: 192.168.1.10
[*] Initiating enumeration using SMBv2/SMBv3
[+] NetBIOS Names:
    - NetBIOS name: DC01
    - Domain/Workgroup: CORP
[+] SMB Dialect: SMB 3.1.1 (Security Mode: Signing REQUIRED)
[+] Domain Information:
    - Domain Name: corp.local
    - Domain SID: S-1-5-21-3829182391-238491823-1029384918
[+] Users found via SAMR:
    - Administrator (RID 500): Built-in admin account
    - Guest (RID 501): Disabled
    - j.doe (RID 1104): IT Helpdesk
    - backup_svc (RID 1105): Backup Service Account
[+] Shares found:
    - ADMIN$ (C:\Windows) - NO ACCESS
    - C$ (C:\) - NO ACCESS
    - SYSVOL (C:\Windows\SYSVOL\sysvol) - READ
    - NETLOGON (C:\Windows\SYSVOL\sysvol\corp.local\SCRIPTS) - READ
    - Backups (D:\Backups) - READ, WRITE
[+] Password Policy:
    - Account Lockout Threshold: 5
    - Minimum Password Length: 8
    - Lockout Observation Window: 30 minutes
```
- **Kritik İstismar Noktaları:**
  1. `Backups` paylaşımında `READ, WRITE` izni tespit edildi → Paylaşıma zararlı dosya veya SCF bırakılabilir.
  2. `Account Lockout Threshold: 5` → Parola püskürtme saldırısında kullanıcı başına en fazla 4 deneme yapılmalıdır.
  3. `backup_svc` gibi servis hesapları tespit edildi → Kerberoasting adayıdır.

### 3.2 Kimlik Doğrulamalı Kapsamlı Etki Alanı Keşfi
Ele geçirilen bir etki alanı kullanıcısı ile tüm detaylar çekilir:

```bash
enum4linux-ng -A -u 'j.doe' -p 'P@ssw0rd123!' -d 'CORP' 192.168.1.10 -oA /opt/loot/dc01_full
```
- **Açıklama:** Standart kullanıcı yetkisiyle tüm modülleri çalıştırır. Sonuçları `dc01_full.json`, `dc01_full.yaml` ve `dc01_full.txt` olarak kaydeder.

### 3.3 Pass-the-Hash (NTLM Hash) ile İnceleme
Düz metin parolası bilinmeyen ancak NT hash'i bulunan bir hesapla oturum açma:

```bash
enum4linux-ng -A -u 'Administrator' -H ':31d6cfe0d16ae931b73c59d7e0c089c0' -d 'CORP' 192.168.1.10
```
- **Açıklama:** `-H` parametresi sayesinde Impacket katmanı üzerinden NTLM kimlik doğrulaması gerçekleştirir. Yönetici haklarıyla idari paylaşımları (`C$`, `ADMIN$`) da dökebilir.

### 3.4 Yalnızca Parola Politikası ve Kullanıcı Listesi Çekme
Gereksiz trafik üretmeden yalnızca parola püskürtme operasyonunda gereken verileri toplama:

```bash
enum4linux-ng -U -P -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10
```

### 3.5 RID Cycling Yöntemi ile Gizli Kullanıcıları Keşfetme
RPC oturumu üzerinden SID numaralarının sonundaki RID kısmını sırayla sorgulayarak hesapları keşfetme:

```bash
enum4linux-ng -R 500-1150 -u '' -p '' 192.168.1.10
```
- **Açıklama:** 500 ile 1150 arasındaki RID değerlerini (`500=Administrator`, `501=Guest`, `502=KRBTGT`, `1000+=Standart Kullanıcılar`) `Lookupsids` RPC çağrısıyla yoklar. Null session ile kullanıcı listeleme engellenmiş olsa dahi birçok Windows sunucuda RID sorguları çalışır.

### 3.6 Paylaşım İzinlerini Test Etme ve Yazılabilir Alanları Bulma
Paylaşımların sadece adını değil, yazma hakkı olup olmadığını otomatik denetleme:

```bash
enum4linux-ng -S -C -u 'guest' -p '' 192.168.1.10
```

### 3.7 JSON Çıktısını `jq` ile Otomasyona Bağlama
Üretilen JSON dosyasından parola püskürtme için kullanıcı adlarını ve yazılabilir paylaşımları ayıklama:

```bash
# Tüm kullanıcı adlarını filtreleme:
jq -r '.users[].username' /opt/loot/dc01_full.json > /tmp/users_spray.txt

# Yalnızca WRITE izni olan paylaşımları listeleme:
jq -r '.shares[] | select(.access_rights | contains("WRITE")) | .name' /opt/loot/dc01_full.json
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata / Sorun | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `NT_STATUS_ACCESS_DENIED` | Hedef sunucuda null session (anonim erişim) kısıtlanmış (`RestrictAnonymous=1/2`). | Geçerli bir etki alanı kullanıcısı ve parolası (`-u 'kullanici' -p 'parola'`) girin. |
| `NT_STATUS_CONNECTION_REFUSED` | Hedefte SMB servisi (TCP 445/139) kapalı veya güvenlik duvarı engelliyor. | IP adresini ve port erişimini `nmap -p 139,445 <IP>` ile doğrulayın. |
| `Cannot connect to LDAP server` | Hedef bir Domain Controller değil veya LDAP (TCP 389) portu filtreleniyor. | Yalnızca SMB/RPC modlarını kullanmak için `-As` veya `-Ar` parametresini kullanın. |
| `SMBv1 disabled / Dialect mismatch` | Hedef sistem SMBv1'i tamamen kapatmış. | `--smb-version 2` veya `--smb-version 3` bayrağını ekleyerek modern sürümleri zorlayın. |
| `Failed to parse JSON output` | Çıktı dosya yolu izni yok veya disk dolu. | Yazılabilir bir dizin belirtin (`-oJ /tmp/output.json`). |
| `ModuleNotFoundError: No module named 'impacket'` | Gerekli Python kütüphaneleri ortamda yüklü değil. | `pip3 install impacket ldap3 smbprotocol` komutu ile bağımlılıkları tamamlayın. |
| `SMB SessionError: STATUS_PIPE_NOT_AVAILABLE` | İlgili named pipe servis kapalı olduğu için bulunamadı (Örn: Print Spooler). | Spooler veya WINS servisinin çalışıp çalışmadığını kontrol edin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos auth kullanılırken hedef IP olarak girilmiş. | Hedef IP yerine sunucunun FQDN adını (`dc01.corp.local`) girin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Kaynak | Event ID / Log | Detay |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | Network logon — her SMB/RPC oturumu açılışında üretilir. |
| **Windows Security Log** | **4625** (Logon Failure) | Null session reddedildiğinde veya hatalı kimlik girildiğinde loglanır. |
| **Windows Security Log** | **5140** | Ağ paylaşımına erişildiğinde üretilir (her paylaşım sorgusunda). |
| **Windows Security Log** | **5145** | `IPC$` veya named pipe (`\pipe\samr`, `\pipe\lsarpc`) erişim detayları. |
| **Windows Directory Service** | **1644** | LDAP aramaları pahalı veya verimsiz olduğunda loglanır. |
| **Sysmon** | **Event ID 3** | TCP 445, 139, 389 ve UDP 137 bağlantı kayıtları. |

### 5.2 Ağ ve EDR İmzaları
- **Yüksek Gürültü Düzeyi:** `-A` bayrağı ile çalıştırıldığında hedef sunucuya saniyeler içinde yüzlerce RPC ve SMB paketi gönderilir. SOC/SIEM sistemlerinde "Reconnaissance / Lateral Discovery" kurallarını tetikler.
- **RID Cycling Alarmı:** `\pipe\samr` boru hattı üzerinden ardışık RID lookup çağrıları (500'den 1100'e kadar seri sorgular), modern EDR ve SIEM korelasyon kurallarında doğrudan **"Active Directory User Enumeration via SAMR"** uyarısı oluşturur.
- **Null Session İmzası:** Boş domain ve boş kullanıcı adı içeren `Session Setup` istekleri NDR (Ağ Tespit Sistemleri) tarafından anında işaretlenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | enum4linux-ng Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesaplarının SAMR ve LDAP ile listelenmesi |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Etki alanı grup üyeliklerinin haritalanması |
| **T1135** | Network Share Discovery | Ağ paylaşımlarının ve izinlerinin taranması |
| **T1201** | Password Policy Discovery | Parola karmaşıklığı ve kilitleme politikalarının dökülmesi |
| **T1018** | Remote System Discovery | NetBIOS ve etki alanı rollerinin belirlenmesi |
| **T1550.002** | Pass the Hash | `-H` ile NTLM hash tabanlı oturum açma |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **Tüm modüllerin (`-A`) gürültüsü** | Tüm modülleri tek seferde çalıştırmayın. Sadece ihtiyacınız olanı seçin (`-U`, `-P` veya `-S`). |
| **Seri RID Cycling tespiti** | RID aralığını geniş tutmak yerine hedeflenmiş dar aralıklar seçin veya LDAP tercih edin. |
| **SMBv1 eski protokol alarmı** | Modern ortamlarda anomali oluşturmamak için `--smb-version 2` parametresi kullanın. |
| **Log yoğunluğu** | Mümkünse anonim sorgular yerine ele geçirilmiş meşru kullanıcı kimliğiyle sorgulayın. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- Log analizi ve tespit senaryoları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- Null session engelleme → `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RestrictAnonymous = 2` ayarı
- SAMR uzaktan sorgulama kısıtlaması → `Network access: Restrict clients allowed to make remote calls to SAM` GPO politikası
- SMB Signing zorunluluğu → [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve kırmızı takım tatbikatlarında en sık başvurulan `enum4linux-ng` komut kombinasyonlarını, operasyonel amaçlarını ve parametre analizlerini içerir:

### 6.1 Anonim (Null Session) ile Hızlı Tam Keşif
```bash
enum4linux-ng -A 192.168.1.10
```
- **Ne Yapar?** Hedef sunucuda parola sormadan tüm bilgi toplama modüllerini (NetBIOS, SMB, RPC, LDAP, Paylaşımlar, Kullanıcılar, Parola Politikası) sırayla çalıştırır.
- **Ne Zaman Kullanılır?** İlk temas anında hedef sistemin anonim erişim sınırlarını ve dışarı sızdırdığı temel konfigürasyonu görmek için.
- **Parametreler:** `-A` (Tüm modülleri çalıştırır: OS info, users, groups, shares, password policy, sessions).

### 6.2 Etki Alanı Kullanıcısı ile Yetkili ve Eksiksiz Döküm
```bash
enum4linux-ng -A -u 'j.doe' -p 'P@ssw0rd123!' -d 'CORP' 192.168.1.10 -oA /opt/loot/dc01_enum
```
- **Ne Yapar?** Meşru bir etki alanı kullanıcısıyla oturum açarak kısıtlamasız tüm etki alanı nesnelerini çeker; sonuçları JSON, YAML ve TXT dosyalarına kaydeder.
- **Ne Zaman Kullanılır?** Bir kullanıcı hesabı ele geçirildiğinde etki alanının tüm kullanıcı ve paylaşım haritasını tek seferde arşivlemek için.
- **Parametreler:** `-A` (Tüm modüller), `-u` (Kullanıcı), `-p` (Parola), `-d` (Etki alanı adı), `-oA` (Tüm çıktı formatlarında dosyaya yaz).

### 6.3 Pass-the-Hash (NTLM Hash) ile Kimlik Doğrulama
```bash
enum4linux-ng -A -u 'Administrator' -H ':31d6cfe0d16ae931b73c59d7e0c089c0' -d 'CORP' 192.168.1.10
```
- **Ne Yapar?** Parola girmeksizin ele geçirilen NT hash'i ile oturum açar ve en üst yetki seviyesinde paylaşım ve dizin bilgilerini döker.
- **Ne Zaman Kullanılır?** SAM veya LSASS bellek dökümünden hash alındığında, parolayı kırmaya çalışmadan doğrudan yetkili keşif yapmak için.
- **Parametreler:** `-H` (`:NTHASH` formatında NTLM hash'i kabul eder).

### 6.4 Parola Püskürtme Öncesi Parola Politikası ve Kullanıcı Hasadı
```bash
enum4linux-ng -U -P -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10
```
- **Ne Yapar?** Sadece aktif kullanıcı listesini (`-U`) ve etki alanının parola kilitleme politikasını (`-P`) çeker; gereksiz modülleri çalıştırmaz.
- **Ne Zaman Kullanılır?** Password Spraying saldırısı planlarken hesap kilitlenme eşiğini (`Lockout Threshold`) öğrenmek ve hedef kullanıcı listesini hazırlamak için.
- **Parametreler:** `-U` (Kullanıcıları listele), `-P` (Parola ve kilitleme politikasını getir).

### 6.5 Sadece Paylaşımları ve Yazma İzinlerini Denetleme
```bash
enum4linux-ng -S -C -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10
```
- **Ne Yapar?** Ağ paylaşımlarını listeler (`-S`) ve her bir paylaşımda dosya oluşturma/yazma testi (`-C`) yaparak yazılabilir alanları tespit eder.
- **Ne Zaman Kullanılır?** Dosya sunucularında SCF saldırısı, zararlı kısayol bırakma veya DLL hijacking için yazılabilir klasör ararken.
- **Parametreler:** `-S` (Paylaşımları listele), `-C` (Yazma iznini test et).

### 6.6 Kısıtlı Ortamda RID Cycling ile Kullanıcı Keşfi
```bash
enum4linux-ng -R 500-1100 -u '' -p '' 192.168.1.10
```
- **Ne Yapar?** 500 ile 1100 arasındaki RID numaralarını tek tek RPC `Lookupsids` fonksiyonuna göndererek SID'ye karşılık gelen hesap adlarını çözer.
- **Ne Zaman Kullanılır?** Standart kullanıcı listeleme komutları erişim engeli (`Access Denied`) aldığında, RID döngüsü üzerinden kullanıcı adlarını sızdırmak için.
- **Parametreler:** `-R` (RID aralığını belirler: `başlangıç-bitiş`).

### 6.7 Yalnızca LDAP Modülünü Kullanarak Sessiz Keşif
```bash
enum4linux-ng -Al -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10
```
- **Ne Yapar?** SMB ve RPC protokollerini tamamen devre dışı bırakır; tüm verileri yalnızca TCP 389 (LDAP) sorgularıyla çeker.
- **Ne Zaman Kullanılır?** Ağda SMB/RPC filtrelemesi olduğunda veya SMB trafiği çok sıkı izlenirken LDAP üzerinden daha sessiz bilgi toplamak için.
- **Parametreler:** `-Al` (Yalnızca LDAP modüllerini çalıştırır).

### 6.8 JSON Çıktısı Üreterek Otomasyona ve Araçlara Veri Aktarma
```bash
enum4linux-ng -A -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10 -oJ /tmp/target_ad.json
```
- **Ne Yapar?** Tarama sonuçlarını temiz, yapılandırılmış bir JSON dosyasına yazar.
- **Ne Zaman Kullanılır?** Çıktıyı Python, `jq` veya SIEM/veritabanı araçlarıyla otomatik ayrıştırmak (parse) ve sızma testi raporuna aktarmak için.
- **Parametreler:** `-oJ` (JSON formatında kayıt dosyası yolu).

### 6.9 Oturum Açmış Aktif Kullanıcıları (Logged-on Sessions) Listeleme
```bash
enum4linux-ng -e -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10
```
- **Ne Yapar?** NetSessionEnum ve NetWkstaUserEnum RPC API'leri üzerinden hedef sunucuda o anda aktif oturumu bulunan kullanıcıları listeler.
- **Ne Zaman Kullanılır?** Domain Admin veya ayrıcalıklı bir kullanıcının hedef sunucuda oturum açıp açmadığını tespit ederek token/hasat saldırısı planlamak için.
- **Parametreler:** `-e` (Oturumları numaralandırır).

### 6.10 Paylaşılan Yazıcıları Numaralandırma
```bash
enum4linux-ng -p -u 'j.doe' -p 'P@ssw0rd123!' 192.168.1.10
```
- **Ne Yapar?** Hedef sistemdeki paylaşılan yazıcıları (`spoolss`) sorgular ve sürücü/yol detaylarını döker.
- **Ne Zaman Kullanılır?** PrintNightmare zafiyet yüzeyini veya uzaktan yazdırma servislerini haritalamak için.
- **Parametreler:** `-p` (Yazıcıları listeler).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| enum4linux-ng GitHub Deposu | [github.com/cddmp/enum4linux-ng](https://github.com/cddmp/enum4linux-ng) |
| Klasik enum4linux (Perl) | [github.com/Cisco-Talos/enum4linux](https://github.com/Cisco-Talos/enum4linux) |
| MITRE ATT&CK T1087.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |
| MITRE ATT&CK T1201 | [attack.mitre.org](https://attack.mitre.org/techniques/T1201/) |
| MS-SAMR Protokol Spesifikasyonu | [Microsoft Docs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/) |

---

> **Önceki:** [← impacket-samrdump](./impacket-samrdump.md) · **Sonraki:** [nmap_NSE_Script →](./nmap_NSE_Script.md)
