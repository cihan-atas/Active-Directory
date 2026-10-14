# mount.cifs

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux dosya sistemine uzaktaki Windows SMB/CIFS paylaşımlarını yerel klasör olarak bağlama.

---

## 1. Genel Bakış ve Amaç

`mount.cifs`, Linux işletim sisteminde uzaktaki Windows veya Samba SMB/CIFS dosya paylaşımlarını (`\\sunucu\paylaşım`) yerel bir dizine (`/mnt/paylaşım`) bağlamak (mount) için kullanılan çekirdek düzeyinde (kernel-level) bir yardımcı araçtır (`cifs-utils` paketinin bir parçasıdır). Linux çekirdeğinin sanal dosya sistemi katmanındaki **CIFS VFS (`cifs.ko`)** modülü ile doğrudan haberleşerek uzak ağ paylaşımını sanki yerel bir sabit diskmiş gibi işletim sistemine entegre eder.

Kullanıcı alanında (user-space) çalışan [smbclient](./smbclient.md) veya [smbmap](./smbmap.md) gibi araçlarda operatörün kısıtlı bir FTP benzeri kabuk içinde veya tekil bayraklarla çalışması gerekirken; `mount.cifs` ile bağlanan bir paylaşım üzerinde Linux'un tüm yerel araçları (**`grep`**, **`find`**, **`ripgrep`**, **`awk`**, **`sed`**, **`tree`**, **`rsync`**, **`python`**) doğrudan ve rekürsif olarak koşturulabilir.

### Mimari ve Protokol Akışı

```
┌────────────────────────────────────────────────────────┐
│                   Linux Saldırı Makinesi               │
│                                                        │
│  [ grep / ripgrep / find / Grouper2 / Python ]        │
│                         │ (Yerel Dosya Sistemi Çağrısı) │
│                         ▼                              │
│             [ Linux VFS (Sanal Dosya Sistemi) ]        │
│                         │                              │
│                         ▼                              │
│             [ CIFS VFS Modülü (cifs.ko) ]              │
└─────────────────────────┬──────────────────────────────┘
                          │ TCP 445 (SMBv2/v3 / Kerberos / NTLMSSP)
                          ▼
┌────────────────────────────────────────────────────────┐
│                   Hedef Windows Sunucu                 │
│                                                        │
│  [ \\DC01\SYSVOL ] veya [ \\FILESRV\C$ ]               │
│  - Paylaşılan Klasörler ve Dosyalar                    │
│  - GPO Scriptleri, Groups.xml, Konfigürasyonlar        │
└────────────────────────────────────────────────────────┘
```

1. **Bağlantı Kurulumu:** `mount -t cifs` komutu verildiğinde `mount.cifs` çağrılır, hedef SMB servisine Negotiate ve Session Setup paketleri gönderir.
2. **Kimlik Doğrulama:** NTLMv2, Kerberos (`sec=krb5`) veya anonim (Null/Guest) bağlamda kimlik doğrulanır.
3. **VFS Entegrasyonu:** Uzaktaki dosya sistemi yerel dizin ağacına bağlanır. Dosya okuma/yazma talepleri çekirdek tarafından otomatik olarak SMB `READ`/`WRITE` komutlarına dönüştürülür.
4. **Yerel Analiz:** Operatör, terabaytlarca büyüklükteki paylaşımları yerel diske indirmeden (streaming) doğrudan komut satırından arayabilir.

### Neden Önemli?

| Kullanım Senaryosu | Operasyonel Katkı |
|---|---|
| **SYSVOL & GPP Parola Analizi** | Etki alanındaki tüm GPO'ları yerel dizine bağlayıp `Groups.xml` ve `.bat/.ps1` scriptlerinde parola arama. |
| **Büyük Veri Havuzlarında Parola Avı** | Dosya sunucularını indirip disk doldurmak yerine, `ripgrep` ile uzaktan canlı regex araması yapma. |
| **Salt Okunur (`ro`) Bağlama ile Temiz Kalma** | `ro` bayrağı ile bağlanarak hedefteki dosyaların erişim ve değişim zaman damgalarını (Timestomp riski) bozmadan inceleme. |
| **Kimlik Bilgisi Gizleme (`credentials`)** | Parolayı komut geçmişinde (`history`) veya proses listesinde (`ps aux`) ifşa etmeden dosyadan okuma. |
| **Kerberos Biletli Bağlama (`sec=krb5`)** | Ağda NTLM trafiği üretmeden, mevcut ccache bileti ile güvenli ve OPSEC uyumlu dosya erişimi sağlama. |

### Karşılaştırma: mount.cifs vs Kullanıcı Alanı SMB İstemcileri

| Özellik | mount.cifs | smbclient | smbmap | impacket-smbclient |
|---|---|---|---|---|
| **Çalışma Katmanı** | Kernel-space (VFS modülü) | User-space (Samba CLI) | User-space (Python) | User-space (Python) |
| **Linux Araçları Desteği**| ✅ Tüm CLI araçları (`grep`, `find`) | ❌ Yalnızca dahili komutlar | ❌ Regex tarama sınırlı | ❌ MiniImpacketShell |
| **Yerel Dosya Sistemi Hissi**| ✅ Tam entegre dizin | ❌ FTP benzeri kabuk | ❌ Yok | ❌ Yok |
| **Salt Okunur Mod (`ro`)**| ✅ Çekirdek düzeyinde koruma | ❌ Manuel dikkat gerekir | ❌ Yok | ❌ Yok |
| **Pass-the-Hash (PTH)** | ❌ Doğrudan desteklemez | ✅ Destekler | ✅ Destekler | ✅ Mükemmel destek |
| **Kerberos Desteği** | ✅ `sec=krb5` (Kernel upcall) | ✅ `-k` bayrağı | ❌ Yok | ✅ `-k -no-pass` |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Sözdizimi

```bash
# mount komutu üzerinden çağrı:
mount -t cifs //<HEDEF_IP_veya_FQDN>/<PAYLASIM> <BAGLANTI_NOKTASI> -o <SECENEKLER>

# mount.cifs doğrudan çağrısı:
mount.cifs //<HEDEF_IP_veya_FQDN>/<PAYLASIM> <BAGLANTI_NOKTASI> -o <SECENEKLER>
```

### Kritik Bağlantı Parametreleri (`-o` Seçenekleri)

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `username=` | SMB oturumu açılacak kullanıcı adı | `username=j.doe` |
| `password=` | Kullanıcı parolası (Boş parola için `password=""`) | `password='P@ss123!'` |
| `domain=` | Etki alanı (Domain) veya Workgroup adı | `domain=CORP` |
| `credentials=` | Kimlik bilgilerini içeren dosyanın tam yolu | `credentials=/root/.smbcreds` |
| `vers=` | Kullanılacak SMB protokol sürümü (`1.0`, `2.0`, `2.1`, `3.0`, `3.1.1`) | `vers=3.0` |
| `sec=` | Güvenlik ve kimlik doğrulama modu (`none`, `ntlmv2`, `ntlmssp`, `krb5`, `krb5i`, `krb5p`) | `sec=ntlmssp` veya `sec=krb5` |
| `ro` | Paylaşımı salt okunur (Read-Only) bağlar (Dosya yazma/silme engellenir) | `ro` |
| `rw` | Paylaşımı okuma-yazma (Read-Write) yetkisiyle bağlar (Varsayılan) | `rw` |
| `uid=` | Bağlanan dosya ve dizinlerin yerel Linux sahibi (Owner UID) | `uid=1000` veya `uid=0` |
| `gid=` | Bağlanan dosya ve dizinlerin yerel Linux grubu (Group GID) | `gid=1000` veya `gid=0` |
| `file_mode=` | Bağlanan dosyalara atanacak Linux dosya izinleri (Oktal) | `file_mode=0700` |
| `dir_mode=` | Bağlanan klasörlere atanacak Linux dizin izinleri (Oktal) | `dir_mode=0700` |
| `noperm` | İstemci tarafında Linux izin denetimini atlar (Sunucu denetler) | `noperm` |
| `seal` | SMBv3 protokol şifrelemesini (Encryption) zorunlu kılar | `seal` |
| `sign` | SMB paket imzalamayı (SMB Signing) zorunlu kılar | `sign` |
| `cruid=` | Kerberos biletini kullanacak yerel Linux kullanıcısının UID'si | `cruid=0` |
| `nounix` | CIFS Unix uzantılarını devre dışı bırakır | `nounix` |
| `noserverino` | Sunucu inode numaraları yerine istemci tarafı inode üretir (Hata önleme) | `noserverino` |

### Güvenlik Modları (`sec=`) Detay Tablosu

| Mod | Açıklama | Operasyonel Risk ve Kullanım |
|---|---|---|
| `sec=none` | Parolasız anonim veya Guest bağlantısı | Null session taramaları için |
| `sec=ntlmv2` | Standart NTLMv2 karma doğrulaması | Yaygın kurumsal ortamlar |
| `sec=ntlmssp` | NTLMSSP sarmalayıcısı ile NTLMv2 doğrulaması | Windows Server 2012+ için önerilen |
| `sec=krb5` | Kerberos kimlik doğrulaması | ccache bileti ile parolasız ve NTLM izi bırakmadan |
| `sec=krb5i` | Paket bütünlüğü (Packet Integrity / Signing) doğrulamalı Kerberos | İmzalı bağlantı zorunlu sunucularda |
| `sec=krb5p` | Uçtan uca şifreli (Packet Privacy / Encryption) Kerberos | Paketlerin ağda dinlenmesini kesin engelleme |

---

## 3. Pratik Komut Örnekleri

### 3.1 Kimlik Dosyası (Credentials File) ile Güvenli Bağlantı
Parolanın `ps aux` çıktısında ve bash history'de görünmesini engellemek için önce kimlik dosyası oluşturulur:

```bash
# 1. Kimlik dosyasını oluştur ve izinlerini sınırla:
cat << 'EOF' > /root/.smbcreds
username=j.doe
password=P@ssw0rd123!
domain=CORP
EOF
chmod 600 /root/.smbcreds

# 2. SYSVOL paylaşımını salt-okunur (ro) olarak bağla:
mkdir -p /mnt/dc_sysvol
mount -t cifs //192.168.1.10/SYSVOL /mnt/dc_sysvol -o credentials=/root/.smbcreds,ro,vers=3.0
```

### 3.2 SYSVOL Üzerinde Canlı GPP ve Parola Avı
SYSVOL bağlandıktan sonra Linux araçlarıyla derinlemesine parola taraması:

```bash
# Groups.xml içerisindeki cpassword (GPP zafiyeti) alanlarını arama:
find /mnt/dc_sysvol -type f -name "*.xml" -exec grep -in "cpassword" {} +

# Tüm script dosyalarında açık parola tanımlarını arama:
grep -rnEi "(password|parola|pwd|credentials|admin)" /mnt/dc_sysvol/ --include="*.{bat,ps1,vbs,cmd}"
```

### 3.3 Kerberos Bileti (`KRB5CCNAME`) ile Parolasız Bağlama
Golden Ticket veya ele geçirilmiş bir bilet ile DC'nin `C$` paylaşımını bağlama:

```bash
# 1. Bileti ortam değişkenine al:
export KRB5CCNAME=/tmp/administrator.ccache

# 2. Kerberos modunda bağla (Hedef FQDN olmalıdır):
mkdir -p /mnt/dc_c
mount -t cifs //dc01.corp.local/C$ /mnt/dc_c -o sec=krb5,vers=3.0,ro
```

### 3.4 Anonim / Guest Olarak Paylaşım Bağlama
Parolasız açık paylaşımları test etme:

```bash
mkdir -p /mnt/guest_share
mount -t cifs //192.168.1.10/Ortak /mnt/guest_share -o username=guest,password="",vers=2.1,ro
```

### 3.5 SMBv3 ve Uçtan Uca Şifreleme (Sealing) ile Bağlantı
Ağda IDS/IPS veya dinleyicilerin SMB trafiğini görmesini engellemek için şifrelemeyi zorlama:

```bash
mount -t cifs //192.168.1.10/Muhasebe /mnt/muhasebe -o credentials=/root/.smbcreds,vers=3.1.1,seal,ro
```

### 3.6 Terabaytlarca Dosya İçinde `ripgrep` ile Canlı Anahtar Avı
Tüm paylaşımı indirmeden, uzaktan canlı özel anahtar (`id_rsa`, `.kdbx`, `.ovpn`) ve konfigürasyon arama:

```bash
# Özel anahtar ve konfigürasyon dosyalarını listeleme:
find /mnt/muhasebe -type f \( -name "*.kdbx" -o -name "*.ovpn" -o -name "*id_rsa*" -o -name "web.config" \)

# Dosya içeriklerinde parola deseni arama:
rg -i "connectionstring|db_password|api_key" /mnt/muhasebe/
```

### 3.7 Paylaşımı Güvenli Şekilde Ayrıştırma (Unmount / Lazy Unmount)
Bağlantı koptuğunda veya işlem bittiğinde paylaşımı kaldırma:

```bash
# Standart unmount:
umount /mnt/dc_sysvol

# Paylaşım askıda kaldıysa veya meşgulse zorlamalı/tembel unmount:
umount -l /mnt/dc_sysvol
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kodu | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `mount error(13): Permission denied` | Kullanıcı adı/parola hatalı, hesap kilitli veya SMBv1/v2 dialect uyuşmazlığı var. | Kimlik bilgilerini doğrulayın; `-o sec=ntlmssp,vers=3.0` bayraklarını açıkça belirterek modern kimlik doğrulamayı zorlayın. |
| `mount error(112): Host is down` | İstemci hedef sunucunun desteklemediği eski bir SMB sürümü (örneğin SMBv1) talep ediyor veya hedef port 445 kapalı. | `vers=2.0` veya `vers=3.0` parametresi ekleyin; portu `nc -nvz <IP> 445` ile kontrol edin. |
| `mount error(22): Invalid argument` | `-o` parametre dizisinde sözdizimi hatası veya desteklenmeyen bir seçenek var. | `dmesg \| tail` komutunu çalıştırarak çekirdeğin hangi parametreyi reddettiğini inceleyin. |
| `mount error(126): Required key not available` | `sec=krb5` kullanılırken Kerberos bileti Linux çekirdek anahtarlık (`keyctl` / `cifs.upcall`) sistemine aktarılamadı. | `keyutils` paketini yükleyin (`apt install keyutils`), `klist` ile biletin geçerli olduğunu doğrulayın ve hedefi FQDN olarak girin. |
| `CIFS: VFS: cifs_mount failed w/return code = -11` | Ağ bağlantısı kesintiye uğradı veya hedef sunucu bağlantı sınırına ulaştı. | Yeniden deneyin; ağ rotasını ve bağlantı zaman aşımı süresini kontrol edin. |
| `Stale file handle` | Ağ bağlantısı koptuktan sonra açık kalan dosya tanıtıcıları geçersiz hale geldi. | Paylaşımı `umount -l <nokta>` ile tembel olarak ayırıp yeniden bağlayın. |
| `mount error: cifs filesystem not supported by the system` | Linux çekirdeğinde CIFS VFS modülü yüklü değil veya paket eksik. | `modprobe cifs` komutunu çalıştırın ve `apt install cifs-utils` ile paketi kurun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Log Kaynağı | Event ID / Log | Detay ve Açıklama |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | Paylaşım ilk bağlandığında üretilen standart ağ oturumu kaydı. |
| **Windows Security Log** | **5140** | Ağ paylaşım nesnesine erişildiğinde üretilir (Mount anında bir kez). |
| **Windows Security Log** | **5145** | **Dosya/Klasör Erişim Detayı:** Bağlantı noktası altında `grep` veya `find` çalıştırıldığında okunan **her dosya için ayrı bir 5145 olayı** üretilir. |
| **Windows Session Management** | `net session` | Hedef sunucuda `net session` komutu çalıştırıldığında Linux makinesinin IP'si aktif oturum olarak listelenir. |
| **Sysmon** | **Event ID 3** | İstemci IP'sinden hedef TCP 445 portuna giden sürekli açık ağ soketi. |

### 5.2 Ağ ve EDR İmzaları
- **Kalıcı SMB Oturumu Anomalisi:** `smbclient` işi bitince oturumu kapatırken, `mount.cifs` paylaşım ayrılana (`umount`) kadar SMB oturumunu saatlerce açık tutar. Bu durum `net session` inceleyen Blue Team analistleri için net bir göstergedir.
- **Toplu 5145 Olayı Patlaması:** Bağlanan paylaşım üzerinde tüm alt klasörleri kapsayan bir `grep -rn` veya `ripgrep` koşturulduğunda, hedef sunucuda saniyeler içinde binlerce Event ID 5145 logu üretilir. SIEM kuralları **"Mass Share File Access Anomaly"** alarmı üretir.
- **Zaman Damgası Koruması:** `rw` ile bağlandığında dosyaların erişim zamanı (`atime`) güncellenebilir. Bu nedenle mutlaka `ro` kullanılmalıdır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | mount.cifs Kullanımı |
|---|---|---|
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | C$, ADMIN$, SYSVOL paylaşımlarını yerel sisteme bağlama |
| **T1039** | Data from Network Shared Drive | Bağlanan paylaşımlar üzerinden veri sızdırma ve hassas dosya avı |
| **T1552.001** | Credentials in Files | SYSVOL/GPO üzerindeki `Groups.xml` ve scriptlerde parola arama |
| **T1083** | File and Directory Discovery | `find` ve `tree` ile uzaktaki dosya sistemini haritalama |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **Kalıcı oturumun hedefte görünmesi** | İşiniz bittiği anda derhal `umount` komutuyla paylaşımı kaldırın; saatlerce bağlı bırakmayın. |
| **5145 log fırtınası** | Tüm paylaşımı körlemesine `grep` ile taramak yerine, sadece hedeflenen klasörleri (örneğin yalnızca `Policies`) bağlayın. |
| **Zaman damgalarının bozulması** | Paylaşımları daima `-o ro` (salt okunur) bayrağıyla bağlayarak dosya meta verilerinin değişmesini önleyin. |
| **Parolanın bellekte ifşası** | Parolayı komut satırında yazmayın; `-o credentials=/root/.smbcreds` dosyasını kullanın ve dosyayı `chmod 600` yapın. |
| **NTLM izi bırakmama** | NTLM yerine Kerberos (`sec=krb5`) kullanarak etki alanında parola özeti trafiği oluşturmayın. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- SMB paylaşım izleme ve denetim senaryoları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- GPP parolalarını engelleme → KB2971288 güncellemesi ve `Groups.xml` temizliği
- SMB İmzalamayı (Signing) zorunlu kılma → [Blue M08 — Protokol Sertleştirme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- Aktif oturum denetimi → `Get-SmbSession` PowerShell cmdlet'i ile periyodik oturum analizi.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve operasyonel çalışmalarda en sık başvurulan `mount.cifs` komut kombinasyonlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 SYSVOL Paylaşımını Kimlik Dosyası ile Salt Okunur Bağlama
```bash
mount -t cifs //192.168.1.10/SYSVOL /mnt/sysvol -o credentials=/root/.smbcreds,vers=3.0,ro
```
- **Ne Yapar?** Parolayı komut geçmişine yazmadan, kimlik dosyasını kullanarak hedef DC'nin SYSVOL paylaşımını salt okunur olarak bağlar.
- **Ne Zaman Kullanılır?** GPO scriptlerini, XML konfigürasyonlarını ve GPP parolalarını hedefteki dosya meta verilerini değiştirmeden güvenle incelemek için.
- **Parametreler:** `credentials=` (Kimlik dosyası yolu), `vers=3.0` (SMB sürümü), `ro` (Salt okunur mod).

### 6.2 Kerberos Bileti (ccache) ile Parolasız C$ Yönetici Paylaşımını Bağlama
```bash
export KRB5CCNAME=/tmp/admin.ccache && mount -t cifs //dc01.corp.local/C$ /mnt/dc_c -o sec=krb5,vers=3.0,ro
```
- **Ne Yapar?** Mevcut Kerberos biletini kullanarak hedef sunucunun tüm C$ sürücüsünü NTLM trafiği oluşturmadan bağlar.
- **Ne Zaman Kullanılır?** Golden/Silver Ticket veya delegation istismarı sonrası yönetici erişimi elde edildiğinde dosya sistemini yerel araçlarla taramak için.
- **Parametreler:** `sec=krb5` (Kerberos kimlik doğrulaması), hedef FQDN olmalıdır.

### 6.3 Anonim / Guest Olarak Paylaşım Bağlama
```bash
mount -t cifs //192.168.1.10/Ortak /mnt/ortak -o username=guest,password="",vers=2.1,ro
```
- **Ne Yapar?** Parola girmeksizin misafir (guest) yetkisiyle hedef paylaşımı bağlar.
- **Ne Zaman Kullanılır?** İlk temas anında parolasız erişime açık paylaşımların içeriğini yerel Linux komutlarıyla incelemek için.
- **Parametreler:** `username=guest`, `password=""`.

### 6.4 SMBv3 Paket Şifrelemesi (Sealing) Zorlayarak Bağlanma
```bash
mount -t cifs //192.168.1.10/Finans /mnt/finans -o credentials=/root/.smbcreds,vers=3.1.1,seal,ro
```
- **Ne Yapar?** SMBv3.1.1 protokolünü ve uçtan uca AES paket şifrelemesini (`seal`) zorunlu kılar.
- **Ne Zaman Kullanılır?** Ağdaki IDS/IPS sistemlerinin veya ağ dinleyicilerinin dosya trafiğini incelemesini kesin olarak engellemek için.
- **Parametreler:** `vers=3.1.1`, `seal` (SMB paket şifreleme).

### 6.5 Bağlanan Paylaşım Üzerinde GPP Parolalarını (`cpassword`) Arama
```bash
find /mnt/sysvol -name "*.xml" -exec grep -in "cpassword" {} +
```
- **Ne Yapar?** Bağlı SYSVOL dizinindeki tüm XML dosyalarını tarayarak MS14-025 öncesi Group Policy Preferences parolalarını yakalar.
- **Ne Zaman Kullanılır?** Dizin bağlandıktan hemen sonra yerel yönetici veya servis hesabı parolalarını sızdırmak için.

### 6.6 Bağlanan Paylaşımda Canlı Regex ile Hassas Dosya ve Parola Avı
```bash
grep -rnEi "(password|parola|api_key|secret)" /mnt/finans/ --include="*.{config,txt,ini,ps1}"
```
- **Ne Yapar?** Paylaşımı yerel diske indirmeden, uzaktaki konfigürasyon ve script dosyalarının içindeki hassas anahtarları filtreler.
- **Ne Zaman Kullanılır?** Dosya sunucularında unutulmuş veritabanı bağlantı dizgilerini veya API anahtarlarını bulmak için.

### 6.7 Özel Anahtar ve Kasa Dosyalarını Listeleme
```bash
find /mnt/finans -type f \( -name "*.kdbx" -o -name "*.ovpn" -o -name "*id_rsa*" -o -name "*.pfx" \)
```
- **Ne Yapar?** Paylaşım içindeki KeePass kasalarını, OpenVPN profillerini, SSH özel anahtarlarını ve PFX sertifikalarını listeler.
- **Ne Zaman Kullanılır?** Yanal hareket için kritik kimlik deposu dosyalarını hızla tespit etmek için.

### 6.8 Yerel Kullanıcı Yetkisi ile Bağlama (UID/GID Tanımlama)
```bash
mount -t cifs //192.168.1.10/Arsiv /mnt/arsiv -o credentials=/root/.smbcreds,uid=1000,gid=1000,file_mode=0700,dir_mode=0700
```
- **Ne Yapar?** Dosya sahipliğini root yerine yerel standart kullanıcıya (UID 1000) verir ve izinleri yalnızca o kullanıcıya sınırlar.
- **Ne Zaman Kullanılır?** Root dışındaki yerel araçların veya editörlerin paylaşıma erişmesini sağlamak için.
- **Parametreler:** `uid=1000`, `gid=1000`, `file_mode=0700`, `dir_mode=0700`.

### 6.9 Paylaşımı Güvenli Şekilde Ayrıştırma (Unmount)
```bash
umount /mnt/sysvol
```
- **Ne Yapar?** Yerel bağlantı noktasını temiz bir şekilde çözer ve uzaktaki Windows sunucudaki SMB oturumunu sonlandırır.
- **Ne Zaman Kullanılır?** İnceleme bittiğinde sunucudaki `net session` kaydını kapatmak ve OPSEC izini temizlemek için.

### 6.10 Askıda Kalan Paylaşımı Tembel / Zorlamalı Ayrıştırma (Lazy Unmount)
```bash
umount -l /mnt/sysvol
```
- **Ne Yapar?** Ağ bağlantısı koptuğunda veya bir proses dizini kilitlediğinde dosya sistemini derhal VFS hiyerarşisinden koparır (`lazy unmount`).
- **Ne Zaman Kullanılır?** Sunucu yanıt vermediğinde veya terminal askıda kaldığında zorlamalı ayırmak için.
- **Parametreler:** `-l` (Lazy unmount).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Linux mount.cifs Kılavuzu | `man mount.cifs` / [linux.die.net](https://linux.die.net/man/8/mount.cifs) |
| Linux Kernel CIFS Dokümantasyonu | [kernel.org/doc/html/latest/filesystems/cifs](https://www.kernel.org/doc/html/latest/filesystems/cifs/) |
| MITRE ATT&CK T1021.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1021/002/) |
| MITRE ATT&CK T1552.001 | [attack.mitre.org](https://attack.mitre.org/techniques/T1552/001/) |
| HackTricks — Pentesting SMB | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smb.html) |

---

> **Önceki:** [← impacket-smbclient](./impacket-smbclient.md) · **Sonraki:** [ldapsearch →](./ldapsearch.md)
