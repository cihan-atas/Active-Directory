# windapsearch

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Python tabanlı hızlı LDAP numaralandırma; SPN, unconstrained delegation, Domain Admins ve parola politikası filtreleme.

---

## 1. Genel Bakış ve Amaç

`windapsearch`, Ronnie Flathers (`ropnop`) tarafından geliştirilen ve Active Directory sızma testlerinde LDAP keşif sürecini hızlandırmak için tasarlanmış açık kaynaklı bir numaralandırma aracıdır. Standart [ldapsearch](./ldapsearch.md) aracında operatörün karmaşık `BaseDN` değerlerini, OID eşleme kurallarını (`1.2.840.113556.1.4.803` vb.) ve sayfalama parametrelerini manuel olarak girmesi gerekirken; `windapsearch`, Active Directory keşif adımlarını **önceden tanımlanmış hazır modüller** halinde otomatikleştirir.

Araç iki farklı versiyonda sunulmaktadır:
1. **Python Sürümü (`windapsearch.py`):** `ldap3` kütüphanesini kullanır, esnek ve genişletilebilirdir.
2. **Go Sürümü (`go-windapsearch`):** Bağımsız, tek bir ikili dosya (static binary) olarak derlenebilir; hedef Windows veya Linux makineye taşınarak harici Python bağımlılığı olmadan yerel olarak çalıştırılabilir.

`windapsearch`, hedef Etki Alanı Denetleyicisine (DC) bağlandığında `RootDSE` sorgusunu otomatik koşturarak `defaultNamingContext` (BaseDN) bilgisini tespit eder, LDAP sayfalama (paging) mekanizmasını arka planda şeffaf olarak yönetir ve sonuçları renkli konsol tabloları veya JSON formatında sunar.

### Mimari ve Protokol Akışı

```
┌──────────────┐                 TCP 389 (LDAP) / TCP 636 (LDAPS)       ┌──────────────┐
│ windapsearch │ ─────────────────────────────────────────────────────► │   Hedef DC   │
│   (Python)   │      1. Otomatik RootDSE Sorgusu (BaseDN Tespiti)      │ (Active Dir) │
│              │ ◄───────────────────────────────────────────────────── │              │
│              │      2. BaseDN Yanıtı (DC=corp,DC=local)               │              │
│              │ ─────────────────────────────────────────────────────► │              │
│              │      3. Modül Sorgusu (Örn: unconstrained-computers)   │              │
│              │         - Sayfalama (Paging) Otomatik Yönetilir       │              │
│              │ ◄───────────────────────────────────────────────────── │              │
│              │      4. Ayrıştırılmış Sonuçlar (User/Group/SPN)        │              │
└──────────────┘                                                        └──────────────┘
      │
      ▼ Hazır Operasyonel Modüller:
      ├── users                 ──► Tüm kullanıcılar ve öznitelikleri
      ├── domain-admins         ──► Domain Admins üyeleri
      ├── privileged-users      ──► Tüm ayrıcalıklı grupların üyeleri
      ├── unconstrained         ──► Kısıtlamasız delegasyonlu sunucular
      ├── user-spns             ──► Kerberoastable hesaplar
      ├── asreproast            ──► DONT_REQ_PREAUTH hesaplar
      ├── gpos                  ──► Grup İlkeleri ve SYSVOL yolları
      └── custom                ──► Özel LDAP filtre çalıştırma
```

### Neden Önemli?

| Senaryo | Operasyonel Katkı |
|---|---|
| **Sıfır Ön Bilgiyle Keşif** | Etki alanı adını veya BaseDN'i bilmeye gerek kalmadan hedef DC IP'si ile doğrudan çalışır. |
| **Hızlı Saldırı Vektörü Keşfi** | Kerberoasting (`user-spns`), AS-REP Roasting (`asreproast`) ve Delegasyon açıklarını tek bayrakla listeler. |
| **Pass-the-Hash Desteği** | Parola bilinmediğinde NTLM hash (`--hash`) ile LDAP sorgulaması yapabilir. |
| **JSON Pipeline Entegrasyonu** | Çıktıları doğrudan JSON formatında (`-j`) üreterek `jq`, Python veya raporlama şablonlarına aktarır. |
| **Otomatik Sayfalama** | 1000 nesnelik Active Directory limitine takılmadan binlerce nesneyi kesintisiz çeker. |

### Karşılaştırma: windapsearch vs Alternatif LDAP Araçları

| Özellik | windapsearch | ldapsearch | BloodHound | NetExec (nxc ldap) |
|---|---|---|---|---|
| **Kullanım Zorluğu** | Çok Kolay (Hazır Modüller) | Orta-Zor (Ham Filtre) | Kolay (Grafik Arayüz) | Kolay (Protokol Bayrakları) |
| **BaseDN Tespiti** | Otomatik | Manuel (`-b`) | Otomatik | Otomatik |
| **Önceden Tanımlı Modüller**| ✅ Geniş (SPN, Delegasyon) | ❌ Yok | ✅ Geniş Grafik | ✅ Modüller mevcut |
| **Pass-the-Hash Desteği** | ✅ `--hash` | ❌ Desteklemez | ✅ Destekler | ✅ Destekler |
| **Çıktı Formatı** | Tablo, JSON, Renkli Konsol | LDIF / Düz Metin | JSON (Neo4j) | Konsol Tablosu |
| **Taşınabilirlik** | Go sürümü tek binary | Paket kurulumu gerekir | SharpHound binary | Python / pipx |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Sözdizimi

```bash
# Python sürümü:
windapsearch.py -d <DOMAIN> --dc <DC_IP> -u <USER> -p <PASS> [modül_seçenekleri]

# Go sürümü:
windapsearch -d <DOMAIN> --dc <DC_IP> -u <USER> -p <PASS> [modül_seçenekleri]
```

### Kritik Parametreler

| Parametre | Uzun Parametre | Açıklama | Örnek Değer |
|---|---|---|---|
| `-d` | `--domain` | Hedef NetBIOS veya FQDN etki alanı adı | `-d corp.local` |
| `--dc` | `--dc-ip` | Hedef Etki Alanı Denetleyicisi IP adresi veya hostname | `--dc 192.168.1.10` |
| `-u` | `--user` | Kimlik doğrulama için kullanıcı adı | `-u j.doe` |
| `-p` | `--password` | Kullanıcı parolası | `-p 'P@ssw0rd123!'` |
| `--hash` | `--ntlm-hash` | Pass-the-Hash için NTLM hash (`LM:NT` veya `:NT`) | `--hash :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-k` | `--kerberos` | Kerberos bilet önbelleği kullan (`KRB5CCNAME`) | `-k` |
| `-s` | `--secure` | SSL/TLS şifreli LDAPS (Port 636) kullanır | `-s` |
| `-j` | `--json` | Sonuçları standart JSON formatında üretir | `-j` |
| `-o` | `--output` | Çıktıyı belirtilen dosyaya kaydeder | `-o /tmp/results.json` |
| `--full` | `--full-attributes` | Yalnızca temel alanlar yerine nesnenin tüm özniteliklerini döker | `--full` |
| `--attrs`| `--attributes` | Döndürülecek spesifik öznitelik listesi (Virgülle ayrılmış) | `--attrs sAMAccountName,mail,title` |
| `--custom` | `--custom-filter` | Özel LDAP arama filtresi çalıştırır | `--custom '(adminCount=1)'` |
| `-v` | `--verbose` | Ayrıntılı hata ayıklama ve bağlantı loglarını gösterir | `-v` |

### Modül Listesi (Enumeration Modules)

`windapsearch` bünyesinde doğrudan çağrılabilen hazır operasyonel modüller:

| Modül Adı | Açıklama | Hedeflenen Saldırı Yüzeyi |
|---|---|---|
| `users` | Etki alanındaki tüm kullanıcıları listeler | Genel kullanıcı envanteri ve profil keşfi |
| `groups` | Güvenlik ve dağıtım gruplarını listeler | Grup hiyerarşisi haritalama |
| `computers` | Etki alanındaki tüm bilgisayarları ve sunucuları listeler | İşletim sistemi ve hedef sistem tespiti |
| `domain-admins` | `Domain Admins` grubunun doğrudan ve dolaylı üyeleri | Yüksek ayrıcalıklı hesapların tespiti |
| `privileged-users`| Tüm kritik idari grupların (EA, SA, DA, Account Ops vb.) üyeleri | Tam ayrıcalıklı hesap haritası |
| `user-spns` | SPN atanmış kullanıcı hesaplarını listeler | **Kerberoasting** saldırı hazırlığı |
| `asreproast` | Kerberos ön doğrulaması kapatılmış kullanıcılar | **AS-REP Roasting** saldırı hazırlığı |
| `unconstrained-computers` | Kısıtlamasız delegasyon sahibi bilgisayar hesapları | **Unconstrained Delegation** istismarı |
| `gpos` | Tüm Grup İlkeleri (GPO) ve SYSVOL bağlantı yolları | GPO yetki aşımı ve script avı |
| `metadata` | Dizin üst verileri ve etki alanı parola politikası | Parola püskürtme güvenlik sınırları |
| `custom` | Kullanıcının belirteceği özel LDAP filtresini çalıştırır | Hedefli arama ve esnek filtreleme |

---

## 3. Pratik Komut Örnekleri

### 3.1 Etki Alanı Parola Politikasını ve Üst Verilerini Çekme
Parola püskürtme öncesinde kilitlenme eşiğini ve domain metadata bilgilerini alma:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m metadata
```
**Örnek Çıktı:**
```text
[+] Searching for Domain Metadata...
[*] Domain: corp.local
[*] Domain SID: S-1-5-21-3829182391-238491823-1029384918
[*] Forest Functional Level: Windows Server 2016
[*] Domain Functional Level: Windows Server 2016
[*] Password Policy:
    - Minimum Password Length: 8
    - Password Complexity: Enabled
    - Account Lockout Threshold: 5
    - Lockout Duration: 30 minutes
    - Lockout Observation Window: 30 minutes
```

### 3.2 Kerberoastable Kullanıcı Hesaplarını Bulma (`user-spns`)
SPN atanmış kullanıcıları tek komutla dökme:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m user-spns
```
- **Çıktı Analizi:** Listelenen `svc_sql`, `svc_backup` gibi kullanıcılar doğrudan Impacket `GetUserSPNs.py` veya Rubeus ile Kerberoast edilmeye hazırdır.

### 3.3 AS-REP Roastable Hesapları Tespit Etme (`asreproast`)
Kerberos ön doğrulaması kapatılmış (`DONT_REQ_PREAUTH`) hesapları listeleme:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m asreproast
```

### 3.4 Kısıtlamasız Delegasyon Sahibi Sunucuları Bulma (`unconstrained-computers`)
TGT yakalama saldırılarına açık olan sunucuları haritalama:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m unconstrained-computers
```

### 3.5 Ayrıcalıklı Kullanıcıları ve Yöneticileri Listeleme (`privileged-users`)
Yalnızca Domain Admins değil, Enterprise Admins, Schema Admins, Account Operators gibi tüm ayrıcalıklı kullanıcıları tek raporda toplama:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m privileged-users
```

### 3.6 Pass-the-Hash (NTLM Hash) ile LDAP Keşfi
Düz metin parolası bulunmayan bir yerel veya etki alanı yöneticisi hash'i ile arama yapma:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u Administrator --hash :31d6cfe0d16ae931b73c59d7e0c089c0 -m domain-admins
```

### 3.7 Çıktıyı JSON Olarak Kaydetme ve `jq` ile İşleme
Sonuçları yapılandırılmış JSON formatında kaydedip kullanıcı adlarını ayıklama:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m users -j -o /tmp/users.json
cat /tmp/users.json | jq -r '.[].sAMAccountName' > /opt/recon/users.txt
```

### 3.8 Özel LDAP Filtresi Çalıştırma (`custom`)
`windapsearch`'in otomatik sayfalama motorunu kullanarak özel bir LDAP filtresini koşturma:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' \
  --custom '(&(objectCategory=person)(description=*pass*))' --attrs sAMAccountName,description
```

### 3.9 LDAPS (Port 636) Üzerinden Güvenli Sorgulama
LDAP signing zorunlu ortamlarda SSL/TLS üzerinden bağlantı sağlama:

```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -s -m gpos
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `[-] Bind failed: Invalid credentials` | Kullanıcı adı veya parola hatalı / hesap kilitlenmiş. | Kimlik bilgilerini NetExec veya smbclient ile tek seferde doğrulayın; parola kilitlenme eşiğini aşmayın. |
| `[-] Failed to connect to LDAP server` | Hedef DC IP'si yanlış, port 389 güvenlik duvarı tarafından engelleniyor veya DC kapalı. | `nc -nvz <DC_IP> 389` ile port erişimini test edin; IP adresini doğrulayın. |
| `[-] LDAP server requires SSL/TLS` | Hedef DC, düz metin LDAP bağlantılarını reddediyor (LDAP Signing / Channel Binding devrede). | Komuta `-s` (`--secure`) bayrağını ekleyerek LDAPS (Port 636) üzerinden bağlanın. |
| `[-] Kerberos error: KDC_ERR_S_PRINCIPAL_UNKNOWN` | `--kerberos` kullanılırken DC IP olarak verilmiş veya SPN çözülemiyor. | `--dc` parametresine IP yerine etki alanı denetleyicisinin tam FQDN adını (`dc01.corp.local`) verin. |
| `ModuleNotFoundError: No module named 'ldap3'` | Gerekli Python kütüphanesi ortamda yüklü değil. | `pip3 install ldap3 dnspython` komutuyla bağımlılıkları yükleyin veya derlenmiş Go sürümünü (`go-windapsearch`) kullanın. |
| `[-] No results returned for module` | İlgili özniteliğe sahip nesne dizinde bulunmuyor (Örn: Hiç AS-REP Roastable hesap yok). | Modülü doğrulayın veya `--custom` ile daha geniş bir filtre deneyin. |
| `TLS: CERTIFICATE_VERIFY_FAILED` | LDAPS bağlantısında sunucu sertifikası yerel CA havuzunda doğrulanmadı. | `windapsearch` varsayılan olarak sertifika doğrulamasını atlar; Python SSL ortam değişkenlerini kontrol edin (`PYTHONHTTPSVERIFY=0`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Log Kaynağı | Event ID / Log | Detay ve Açıklama |
|---|---|---|
| **Directory Service Access** | **1644** | Pahalı ve verimsiz LDAP sorguları (Örn: `users --full` ile tüm öznitelikler çekildiğinde). |
| **Directory Service Access** | **4662** | Dizin servisi nesnesine erişim (Hassas nesneler okunduğunda). |
| **Windows Security Log** | **4624** (Logon Type 3) | Ağ oturumu (Network Logon) — LDAP bind işlemi sırasında DC üzerinde üretilir. |
| **Windows Security Log** | **4625** | Başarısız kimlik doğrulama denemelerinde üretilir. |
| **Sysmon** | **Event ID 3** | İstemciden DC'nin TCP 389 veya 636 portuna giden ağ trafiği. |

### 5.2 Ağ ve EDR İmzaları
- **LDAP Normalizasyonu:** `windapsearch`, SMB tabanlı araçlara (psexec, wmiexec) kıyasla çok daha düşük gürültü profiline sahiptir. Kurumsal ağlarda LDAP sorguları olağan trafik sayılır.
- **Toplu Öznitelik Çekme Uyarısı:** `users --full` parametresi çalıştırıldığında yüzlerce kullanıcının tüm dizin alanları tek seferde talep edilir; NDR sistemleri ve SIEM Event 1644 korelasyonu bu veri anomalisi üzerinden alarm üretebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | windapsearch Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `users`, `domain-admins`, `privileged-users` modülleri |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `groups` modülü ile grup üyeliklerinin dökülmesi |
| **T1018** | Remote System Discovery | `computers` modülü ile sunucu rollerinin belirlenmesi |
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | `user-spns` modülü ile Kerberoastable hesap keşfi |
| **T1558.004** | Steal or Forge Kerberos Tickets: AS-REP Roasting | `asreproast` modülü ile ön doğrulamasız hesap keşfi |
| **T1484.001** | Group Policy Modification | `gpos` modülü ile Grup İlkeleri ve dosya yolları keşfi |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **Gereksiz Veri İndirme** | `--full` parametresini tüm kullanıcılar için kullanmayın; yalnızca hedeflenen öznitelikleri (`--attrs sAMAccountName,mail`) isteyin. |
| **Düz Metin Parola İletimi** | Mümkün olan her senaryoda `-s` (`--secure`) bayrağı ile LDAPS (TCP 636) üzerinden çalışın. |
| **NTLM Trafiği Tespiti** | NTLM yerine Kerberos ccache biletini (`-k`) tercih edin. |
| **Toplu Modül Taraması** | Tüm modülleri tek seferde ardı ardına çalıştırmak yerine operasyonel ihtiyaca göre hedefli modüller seçin. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- Log analizi ve tespit senaryoları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- LDAP İmzalama ve Kanal Bağlama zorunluluğu → [Blue M08 — Protokol Sertleştirme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- LDAP Arama Günlüğü Yapılandırması → Field Engineering seviyesi artırılarak Event 1644 izleme.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve operasyonel keşiflerde en sık başvurulan `windapsearch` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Etki Alanı Parola Politikasını ve Kilitlenme Eşiğini Çekme
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m metadata
```
- **Ne Yapar?** Etki alanı denetleyicisinden domain SID, etki alanı işlevsellik seviyesi ve en önemlisi parola kilitleme kurallarını (`Account Lockout Threshold`) çeker.
- **Ne Zaman Kullanılır?** Parola püskürtme saldırısından önce hesapların kilitlenmesini engellemek için izin verilen hata limitini öğrenmek amacıyla.
- **Parametreler:** `-m metadata` (Üst veri ve parola politikası modülü).

### 6.2 Kerberoastable Kullanıcı Hesaplarını Tek Hamlede Listeleme
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m user-spns
```
- **Ne Yapar?** SPN atanmış tüm normal kullanıcı hesaplarını, SPN değerlerini ve hesap isimlerini ekrana basar.
- **Ne Zaman Kullanılır?** Kerberoasting saldırısı için hedef kullanıcı listesini hazırlamak amacıyla.
- **Parametreler:** `-m user-spns` (SPN tanımlı kullanıcı modülü).

### 6.3 AS-REP Roastable Hesapları Tespit Etme
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m asreproast
```
- **Ne Yapar?** `DONT_REQ_PREAUTH` bayrağı aktif edilmiş hesapları otomatik filtreler.
- **Ne Zaman Kullanılır?** Parolasız AS-REP karması çekilip Hashcat ile kırılabilecek zafiyetli kullanıcıları avlamak için.
- **Parametreler:** `-m asreproast` (Ön doğrulamasız hesap modülü).

### 6.4 Kısıtlamasız Delegasyon Sahibi Sunucuları Bulma
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m unconstrained-computers
```
- **Ne Yapar?** TGT biletlerini bellekte saklayan kısıtlamasız delegasyonlu sunucuları listeler.
- **Ne Zaman Kullanılır?** PetitPotam veya SpoolSample ile zorlamalı kimlik tetiklendiğinde DC makine biletini yakalamak için pivot sunucu belirlerken.
- **Parametreler:** `-m unconstrained-computers` (Kısıtlamasız delegasyon modülü).

### 6.5 Tüm Ayrıcalıklı Kullanıcıları (Privileged Users) Listeleme
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m privileged-users
```
- **Ne Yapar?** Domain Admins, Enterprise Admins, Schema Admins, Backup Operators dahil tüm kritik idari grupların üyelerini tek listede toplar.
- **Ne Zaman Kullanılır?** Etki alanındaki tüm idari hedefleri ve yüksek yetkili hesapları saniyeler içinde haritalamak için.
- **Parametreler:** `-m privileged-users` (Ayrıcalıklı kullanıcılar modülü).

### 6.6 Pass-the-Hash (NTLM Hash) ile Kimlik Doğrulama
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u Administrator --hash :31d6cfe0d16ae931b73c59d7e0c089c0 -m domain-admins
```
- **Ne Yapar?** Düz parola yerine ele geçirilen NT hash ile oturum açarak Domain Admins üyelerini sorgular.
- **Ne Zaman Kullanılır?** Bellekten veya SAM veritabanından NTLM hash alındığında parolayı kırmaya gerek kalmadan yetkili LDAP sorgusu yapmak için.
- **Parametreler:** `--hash` (`:NTHASH` formatında NTLM hash).

### 6.7 Çıktıyı JSON Formatında Kaydetme ve Wordlist Üretme
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m users -j -o /tmp/users.json
```
- **Ne Yapar?** Tüm etki alanı kullanıcı envanterini yapılandırılmış JSON dosyası olarak diske yazar.
- **Ne Zaman Kullanılır?** Sonuçları otomatik ayrıştırmak ve parola püskürtme için temiz kullanıcı adı listesi oluşturmak için.
- **Parametreler:** `-j` (JSON formatı), `-o` (Çıktı dosyası yolu).

### 6.8 Grup İlkelerini (GPO) ve SYSVOL Yollarını Listeleme
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -m gpos
```
- **Ne Yapar?** Etki alanında tanımlı tüm GPO'ları, GUID değerlerini ve SYSVOL üzerindeki dosya yollarını döker.
- **Ne Zaman Kullanılır?** GPP parolaları (`Groups.xml`), yetkisiz GPO düzenleme açıkları (SharpGPOAbuse) veya başlangıç scriptleri ararken.
- **Parametreler:** `-m gpos` (Grup ilkeleri modülü).

### 6.9 LDAPS (Port 636) Üzerinden Şifreli Bağlantı Zorlama
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' -s -m users
```
- **Ne Yapar?** LDAP trafiğini SSL/TLS ile şifreleyerek port 636 üzerinden sorgulama yapar.
- **Ne Zaman Kullanılır?** Düz metin port 389'un engellendiği veya LDAP signing zorunlu kılındığı sertleştirilmiş ortamlarda.
- **Parametreler:** `-s` (`--secure`: SSL/TLS aktif).

### 6.10 Özel LDAP Filtresi ile Hedefli Arama Koşturma
```bash
python3 windapsearch.py -d corp.local --dc 192.168.1.10 -u j.doe -p 'P@ss123!' --custom '(&(objectCategory=person)(description=*sifre*))' --attrs sAMAccountName,description
```
- **Ne Yapar?** `windapsearch`'in sayfalama motorunu kullanarak özel bir LDAP filtresini koşturur ve sadece istenen öznitelikleri gösterir.
- **Ne Zaman Kullanılır?** Hazır modüller dışındaki spesifik senaryolarda (açıklama alanında parola avı vb.) hedefli arama yapmak için.
- **Parametreler:** `--custom` (Özel LDAP filtre dizgisi), `--attrs` (Döndürülecek öznitelikler).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| windapsearch GitHub Deposu (ropnop) | [github.com/ropnop/windapsearch](https://github.com/ropnop/windapsearch) |
| go-windapsearch (Go Sürümü) | [github.com/ropnop/go-windapsearch](https://github.com/ropnop/go-windapsearch) |
| ropnop Blog — Fun with LDAP | [blog.ropnop.com](https://blog.ropnop.com) |
| MITRE ATT&CK T1087.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |
| MITRE ATT&CK T1558.003 | [attack.mitre.org](https://attack.mitre.org/techniques/T1558/003/) |

---

> **Önceki:** [← ldapsearch](./ldapsearch.md) · **Sonraki:** [rpcclient →](./rpcclient.md)
