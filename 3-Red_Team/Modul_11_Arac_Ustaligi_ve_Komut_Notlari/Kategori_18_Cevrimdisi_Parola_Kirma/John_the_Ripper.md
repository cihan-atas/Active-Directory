# John the Ripper

> **Kategori:** [18. ÇEVRİMDIŞI PAROLA KIRMA (OFFLINE CRACKING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Otomatik hash formatı tespiti, `*2john` dönüştürücü ekosistemi (kirbi2john, pfx2john vb.), Single Crack ve Markov tabanlı Incremental modlarıyla Active Directory NTLM, Kerberos ve sertifika parolalarını çevrimdışı çözen esnek parola kırma motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde parola kırma süreci yalnızca saf GPU kaba kuvvet hızına değil; heterojen ortamlardan elde edilen karmaşık veri formatlarının (Mimikatz `.kirbi` biletleri, AD CS `.pfx` sertifikaları, KeePass veritabanları, BitLocker anahtarları, ham ağ paketleri) işlenebilmesine dayanır. GPU tabanlı Hashcat devasa sözlük ve maske saldırılarında ham NTLM hızında lider olsa da, format dönüştürme esnekliği, otomatik hash ayrıştırma ve kullanıcı bilgilerini temel alan "Single Crack" gibi sezgisel saldırılarda **John the Ripper (JtR)** kırmızı takımların vazgeçilmez aracıdır.

Alexander Peslyak (Solar Designer) ve Openwall topluluğu tarafından geliştirilen **John the Ripper - Jumbo** sürümü, CPU'nun modern vektör komut setlerinden (AVX-512, AVX2, SSE4) ve çoklu çekirdek paralel işlemcilerinden (OpenMP / fork) azami verim alır. JtR'ı Active Directory operasyonlarında benzersiz kılan iki temel mimari özellik bulunmaktadır:
1. **`*2john` Dönüştürücü Cephaneliği:** Rubeus/Mimikatz ile dökülen Kerberos `.kirbi` biletlerini (`kirbi2john.py`), Active Directory Certificate Services (AD CS) üzerinden çalınan özel anahtar sertifikalarını (`pfx2john.py`) veya ağ paketlerindeki TGS/AS-REP yanıtlarını anında kırılabilir metin formatına dönüştüren zengin bir script kütüphanesine sahiptir.
2. **Single Crack Modu:** Parola listesi kullanmadan, kullanıcı adı, GECOS bilgisi (tam ad, e-posta, unvan vb.) ve etki alanı adını akıllı mutasyon kurallarından geçirerek saniyeler içinde "hızlı kazanım" (quick win) kurumsal parolaları çözer.

```
+---------------------------------------------------------------------------------------------------+
|                        JOHN THE RIPPER ÇEVRİMDIŞI KIRMA VE DÖNÜŞTÜRME AKIŞI                       |
+---------------------------------------------------------------------------------------------------+

 [ Active Directory Ham Veri Kaynakları ]
   • Mimikatz / Rubeus .kirbi Biletleri ───► kirbi2john.py ────┐
   • AD CS .pfx Özel Anahtar Sertifikası ──► pfx2john.py ──────┤
   • Responder Ağ Paketleri (PCAP) ────────► pcap2john.py ─────┼─► [ JtR Kırılabilir Hash ]
   • NTDS.dit / SAM Dökümü ────────────────► Doğrudan Metin ───┘   ($krb5tgs$, $pfx$, NT)
                                                                            │
             ┌──────────────────────────────────────────────────────────────┘
             ▼
 [ John the Ripper (Jumbo Engine) ]
             │
             ├─► 1. Otomatik Format Tespiti (--format=...)
             │
             ├─► 2. Akıllı Saldırı Modları:
             │      • Single Crack (--single): Kullanıcı adı/bilgisinden türetme
             │      • Wordlist + Rules (--wordlist + --rules=Jumbo)
             │      • Incremental (--incremental): İstatistiksel Markov olasılıkları
             │
             ├─► 3. Çoklu CPU Çekirdeği / SIMD Vektörizasyonu (AVX2/AVX-512)
             │
             ▼
 [ Çözülen Parolalar ]
             │
             ├─► Ekrana Basılır ve ~/.john/john.pot Dosyasına Kaydedilir
             │
             └─► Sonuçlar: john --show hashes.txt
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **Zengin `*2john` Dönüştürücüleri** | `.kirbi`, `.pfx`, KeePass, BitLocker ve 100+ farklı özel formatı tek komutla kırılabilir hash'e çevirir. |
| **Single Crack Sezgisel Saldırısı** | Sözlük kullanmadan kullanıcı adı ve etki alanı adından türetilen parolaları saniyeler içinde çözer. |
| **Markov Tabanlı Incremental Mod** | Rastgele deneme yapmak yerine dillerdeki harf ve karakter frekans olasılıklarına göre parola türetir. |
| **Otomatik Hash Tespiti** | Hash türü belirtilmediğinde dosya içeriğini analiz ederek en uygun algoritmayı otomatik belirler. |
| **İşlemci Mimarisi Optimizasyonu** | AVX2, AVX-512 ve NEON yönergeleriyle GPU bulunmayan sunucularda bile yüksek CPU başarımına ulaşır. |

### Çevrimdışı Parola Kırma Araçları Karşılaştırması

| Kriter | John the Ripper (Jumbo) | Hashcat | Ophcrack | Hydra |
|:---|:---|:---|:---|:---|
| **Ana Kullanım Alanı** | Çevrimdışı (Geniş Format/CPU) | Çevrimdışı (Yüksek Hız/GPU) | Çevrimdışı (Rainbow Table) | Çevrimiçi Ağ Kaba Kuvveti |
| **Format Dönüştürücüler**| ✅ 100+ Dahili Script (`*2john`)| ❌ Harici Araçlar Gerekir | ❌ Yok | ❌ Yok |
| **Single Crack Modu** | ✅ Mükemmel Sezgisel Motor | ❌ Yok | ❌ Yok | ❌ Yok |
| **Ham NTLM Kırma Hızı**| Yüksek (CPU Vektörel) | **Aşırı Yüksek (GPU CUDA)**| Çok Hızlı (Küçük Parolalar)| Çok Yavaş (Ağ Gecikmesi) |
| **Pfx/Sertifika Kırma**| ✅ Doğrudan (`pfx2john`) | ⚠️ Karmaşık Dönüşüm | ❌ Desteklemez | ❌ Desteklemez |
| **Hesap Kilitleme Riski**| ❌ SIFIR (Offline) | ❌ SIFIR (Offline) | ❌ SIFIR (Offline) | ⚠️ Çok Yüksek (Online) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

John the Ripper CLI sözdizimi, saldırı modu, format seçimi ve hedef dosya parametrelerinden oluşur.

```bash
john [SEÇENEKLER] <HASH_DOSYASI>
```

### 2.1 Kritik Active Directory Formatları (`--format=...`)

| Format Adı | Protokol / Açıklama | Kaynak Araç | Örnek Hash Başlığı |
|:---|:---|:---|:---|
| `NT` | NTLM (Windows NT Hash) | secretsdump, ntdsutil | `31d6cfe0d16ae931b73c59d7e0c089c0` |
| `netntlm` | NetNTLMv1 (Challenge/Response) | Responder, Inveigh | `u::d:1122334455667788:...` |
| `netntlmv2` | NetNTLMv2 (Windows Vista+) | Responder, PetitPotam | `admin::CORP:11223344:...` |
| `krb5tgs` | Kerberos 5 TGS-REP etype 23 | kirbi2john, Rubeus | `$krb5tgs$23$*user$realm$...` |
| `krb5asrep` | Kerberos 5 AS-REP etype 23 | asrep2john, GetNPUsers | `$krb5asrep$23$user@realm:...` |
| `pfx` | PKCS#12 / PFX Sertifikaları | pfx2john, AD CS | `$pfx$1$32$...` |
| `keepass` | KeePass 1.x / 2.x Veritabanları | keepass2john | `$keepass$*2*...` |

### 2.2 Saldırı Modları ve Parametre Tablosu

| Parametre | Açıklama | Tür | Örnek Değer |
|:---|:---|:---|:---|
| `--wordlist=<dosya>` | Belirtilen kelime listesi üzerinden sözlük saldırısı yürütür. | Sözlük | `--wordlist=rockyou.txt` |
| `--single` | Kullanıcı adı ve GECOS bilgilerini kurallarla mutasyona uğratan Single Crack modunu çalıştırır. | Sezgisel | `--single` |
| `--incremental` | Markov tabanlı istatistiksel karakter olasılıklarına göre kaba kuvvet saldırısı başlatır. | Kaba Kuvvet | `--incremental` |
| `--rules[=<set>]` | Sözlük kelimelerine uygulanacak kural setini belirler (Varsayılan: Jumbo). | Kural | `--rules=KoreLogic` |
| `--format=<format>` | Otomatik tespit yerine belirli bir hash formatını zorlar. | Algoritma | `--format=krb5tgs` |
| `--fork=<N>` | İşlemi belirtilen sayıda paralel CPU çekirdeğine böler (Multiprocessing). | Performans | `--fork=8` |
| `--show` | Daha önce kırılmış ve `john.pot` dosyasına yazılmış parolaları listeler. | Raporlama | `--show` |
| `--session=<ad>` | Kırma operasyonuna bir oturum adı atar; sonradan devam ettirilebilir. | Oturum | `--session=ad_tgs` |
| `--restore[=<ad>]`| Kesilen veya durdurulan oturumu kaldığı noktadan devam ettirir. | Devam | `--restore=ad_tgs` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Single Crack Modu ile Hızlı Parolaları Çözme (Quick Wins)
Parola sözlüğü yüklemeden, kullanıcı adları ve departman bilgilerinden türetilen zayıf parolaları (örneğin `ahmet` kullanıcısının `Ahmet123!` veya `Ahmet2026` parolasını) saniyeler içinde kırar.

```bash
john --format=NT --single /opt/hashes/domain_users.ntds
```

```text
Loaded 1245 password hashes with 850 different salts (NT [MD4 128/128 AVX 4x3])
Press 'q' or Ctrl-C to abort, almost any other key for status
Mehmet2025!      (mehmet_oz)
Sirket123*       (ali_kaya)
Administrator    (Administrator)
3g 0:00:00:04 0.7500g/s 452100p/s 452100c/s 452100C/s Mehmet2025!..Sirket123*
Session completed
```

### Senaryo 2: Mimikatz `.kirbi` Biletlerini Dönüştürme ve Kırma (`kirbi2john`)
Hedef makineden Rubeus veya Mimikatz ile dökülen `.kirbi` biletleri JtR formatına dönüştürülüp kırılır.

**Adım 1: Dönüştürme**
```bash
python3 /usr/share/john/kirbi2john.py /tmp/tickets/mssql_svc.kirbi > /opt/hashes/tgs.john
```

**Adım 2: Kırma**
```bash
john --format=krb5tgs --wordlist=/usr/share/wordlists/rockyou.txt --rules=Jumbo /opt/hashes/tgs.john
```

```text
Loaded 1 password hash (krb5tgs, Kerberos 5 TGS-REP etype 23 [MD4 HMAC-MD5 RC4])
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
SqlServiceP@ss1  ($krb5tgs$23$*mssql_svc$CORP.LOCAL)
1g 0:00:00:12 0.0833g/s 342100p/s 342100c/s 342100C/s SqlServiceP@ss1
Session completed
```

### Senaryo 3: AD CS Çalınan PFX Sertifika Parolasını Kırma (`pfx2john`)
Sertifika yetkilisinden çalınan ve şifreli olan `domain_admin.pfx` özel anahtar dosyası dönüştürülüp kırılır.

```bash
python3 /usr/share/john/pfx2john.py /opt/certs/domain_admin.pfx > /opt/hashes/pfx_hash.txt
john --format=pfx --wordlist=/usr/share/wordlists/rockyou.txt /opt/hashes/pfx_hash.txt
```

```text
Loaded 1 password hash (pfx, PKCS#12 PFX [SHA1/SHA2 128/128 AVX 4x])
Will run 8 OpenMP threads
P@ssw0rdCert2026 (/opt/certs/domain_admin.pfx)
1g 0:00:00:02 0.5000g/s 125400p/s 125400c/s 125400C/s P@ssw0rdCert2026
Session completed
```

### Senaryo 4: NetNTLMv2 Hash'lerini Çoklu Çekirdekle Kırma (`--fork`)
Responder ile yakalanan NetNTLMv2 hash'leri 8 ayrı CPU çekirdeğine bölünerek kırılır.

```bash
john --format=netntlmv2 --fork=8 --wordlist=/usr/share/wordlists/rockyou.txt --rules=best64 /opt/hashes/responder_v2.txt
```

```text
Loaded 2 password hashes (netntlmv2, NTLMv2 C/R [MD4 HMAC-MD5 128/128 AVX 4x])
Node numbers 1-8 of 8 (fork)
1 0g 0:00:00:03 0.0000g/s 210000p/s 210000c/s 210000C/s ...
4 Sirket2026!     (CORP\admin)
Waiting for 7 children to terminate...
Session completed
```

### Senaryo 5: AS-REP Roasting Hash'lerini Kırma
Kerberos önkimlik doğrulaması kapalı kullanıcılardan toplanan hash'ler çözülür.

```bash
john --format=krb5asrep --wordlist=/usr/share/wordlists/rockyou.txt /opt/hashes/asrep_hashes.txt
```

```text
Loaded 1 password hash (krb5asrep, Kerberos 5 AS-REP etype 23 [MD4 HMAC-MD5 RC4])
Will run 8 OpenMP threads
BackupAdmin2024  ($krb5asrep$23$backup_user@CORP.LOCAL)
1g 0:00:00:05 0.2000g/s 189000p/s 189000c/s 189000C/s BackupAdmin2024
Session completed
```

### Senaryo 6: Kırılmış Parolaları Raporlama (`--show`)
Daha önce çözülen tüm kullanıcı hesaplarının açık metin karşılıkları dökülür.

```bash
john --format=NT --show /opt/hashes/domain_users.ntds
```

```text
Administrator:Password123!:500:aad3b435b51404ee:8846f7eaee8fb117:::
svc_backup:Backup2024!:1105:aad3b435b51404ee:e19ccf750c3ba2ee:::
ali_kaya:Sirket123*:1108:aad3b435b51404ee:b4b9b02e6f09a9bd:::

3 password hashes cracked, 847 left
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `No password hashes loaded (see FAQ)` | Hash formatı belirtilen `--format` parametresiyle uyuşmuyor veya hash zaten kırılmış potfile içindedir. | `--format` belirtmeden John'un otomatik tespit etmesini sağlayın; daha önce kırılmışsa görmek için `--show` ekleyin. |
| `Unknown ciphertext format name requested` | Jumbo sürümü yerine standart John paketi kuruludur ve istenen modern format (örn. `krb5tgs`) eksiktir. | Dağıtımınızdaki Jumbo paketini kurun (`apt install john`) veya resmi GitHub deposundan kaynak kodla `--enable-openmp` derleyin. |
| `fopen: ~/.john/john.pot: Permission denied` | Potfile dosyasının dosya izinleri bozulmuş veya root oturumundan kalan kilit dosyası vardır. | `~/.john/john.pot` dosyasının sahipliğini (`chown $USER`) düzeltin veya asılı kalan `.rec` oturum dosyalarını temizleyin. |
| `Error: Cannot open wordlist file` | Belirtilen kelime listesi dosya yolu yanlıştır veya dosya sıkıştırılmış (`.gz`) haldedir. | Dosya yolunu teyit edin; `rockyou.txt.gz` ise `gzip -d` ile açın. |
| Performans beklenenden çok düşük (Düşük c/s hızı) | İşlemci SIMD yönergeleri (AVX2/AVX-512) derleme sırasında devre dışı kalmış veya tek iş parçacığı çalışmaktadır. | `--fork=<çekirdek_sayısı>` parametresini kullanın; `john --list=build-info` ile AVX2 desteğini teyit edin. |
| `UTF-8 decoding error / invalid bytes` | Kullanıcı adı veya hash dosyası geçersiz UTF-8 veya BOM karakterleri içermektedir. | Dosyayı `iconv -f ISO-8859-1 -t UTF-8 hashes.txt > clean.txt` ile temizleyin ya da `--encoding=utf8` bayrağını verin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                                JOHN THE RIPPER OPSEC VE İZ PROFİLİ                                |
+---------------------------------------------------------------------------------------------------+

 [ Hedef Kurumsal Ağ / Active Directory ]
  - Ağ Trafiği: SIFIR (0 Paket)             ====> Hedef Ağda Hiçbir Paket Dolaşmaz!
  - Active Directory Olayları: SIFIR Olay   ====> Event ID 4625 (Logon Failure) Oluşmaz!
  - Hesap Kilitleme Eşiği (Lockout): YOK   ====> Kullanıcılar Kilitlenmez!

 [ Gerçek Tespit Alanı: Hasat & Dönüştürme ]
  - .kirbi / .pfx Dosyalarının Alınması    ====> Sysmon Event ID 11 (File Create / Copy)
  - Mimikatz / Rubeus Yürütülmesi          ====> EDR Bellek & LSASS Tespiti
  - Kırılan Parolanın İlk Kullanımı        ====> Event ID 4624 (Logon Type 2 / Type 3)
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Çevrimdışı İzolasyon:** John the Ripper tamamen operatörün yerel bilgisayarında çalıştığından, hedef etki alanında **hiçbir doğrudan log kaydı üretmez**.
* **Hasat Aşaması İzleri:** JtR'a girdi sağlayan araçların hedef ağda bıraktığı izler incelenmelidir:
  * **Event ID 4662:** `DS-Replication-Get-Changes-All` hakkı ile DCSync gerçekleştirilmesi.
  * **Event ID 4769:** `0x17` (RC4) şifreleme türüyle istenen TGS biletleri.
  * **Event ID 4886 / 4887:** AD CS sunucusunda yetkisiz şablon üzerinden sertifika talebi ve verilmesi.

### 5.2 Ağ ve EDR İmzaları
* JtR ağ üzerinden çalışmaz; tamamen yerel CPU ve RAM kaynaklarını tüketir.
* Kırılan parola daha sonra iç ağda kullanıldığında `Event ID 4624` oluşur; parola püskürtme veya yatay hareket EDR korelasyonlarına takılabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Credential Access** | `T1110.002` | Brute Force: Password Cracking | NTLM, Kerberos ve PFX sertifika parolalarını çevrimdışı çözme. |
| **Credential Access** | `T1558.003` | Steal or Forge Kerberos Tickets: Kerberoasting | `.kirbi` ve TGS biletlerini `krb5tgs` formatında kırma. |
| **Credential Access** | `T1558.004` | Steal or Forge Kerberos Tickets: AS-REP Roasting | `krb5asrep` formatıyla önkimliksiz biletleri kırma. |
| **Credential Access** | `T1649` | Steal or Forge Authentication Certificates | Çalınan PKCS#12 / PFX sertifikalarının özel anahtar şifrelerini çözme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Yerel Potfile Dosyası Güvenliği | **DÜŞÜK** | Operasyon bitiminde `~/.john/john.pot` dosyasını `shred -u` ile güvenli şekilde silin; hassas müşteri verilerini diske bırakmayın. |
| Kırılan Parolanın Erken Kullanımı| **YÜKSEK** | Kırılan parolayı mesai saatleri dışında ve hedef kullanıcının her zaman oturum açtığı iş istasyonlarından farklı bir IP'den aniden denemeyin. |
| Hasat Edilen Dosyaların Taşınması | **ORTA** | `.kirbi` ve `.pfx` dosyalarını ağdan dışarı aktarırken parola korumalı 7z veya GPG ile şifreleyin. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (DCSync ve NTDS Hash İhracı):
```yaml
title: Potential Directory Replication Secret Access
id: d19a7410-2b0e-436e-b1cf-71d34c1b52a1
status: production
description: Detects replication operations requesting directory secrets from non-DC hosts.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4662
    AccessMask: '0x100'
  condition: selection
level: critical
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
SecurityEvent
| where EventID == 4769
| where TicketEncryptionType == "0x17" // RC4
| where ServiceName !endswith "$"
| summarize Count = count(), Services = make_set(ServiceName) by Computer, TargetUserName, bin(TimeGenerated, 10m)
| where Count > 5
| project TimeGenerated, TargetUserName, Computer, Count, Services
```

#### YARA Kuralı (John the Ripper Hash Dosyaları Tespiti):
```yara
rule Indicator_JtR_Hash_Files {
    meta:
        description = "Detects exported John the Ripper hash files for Kerberos or PFX"
        author = "RedTeam SecOps"
        date = "2026-10-14"
    strings:
        $s1 = "$krb5tgs$23$*" ascii
        $s2 = "$krb5asrep$23$" ascii
        $s3 = "$pfx$1$" ascii
        $s4 = "$keepass$*" ascii
    condition:
        any of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Uzun Parola Politikaları:** Minimum parola uzunluğu en az 15 karaktere çıkarılmalıdır.
* **Kerberoasting Engelleme:** SPN hesaplarında gMSA zorunlu tutulmalı; RC4 şifreleme türü devre dışı bırakılmalıdır.
* **Sertifika Özel Anahtar Koruması:** AD CS sertifika yetkilisi üzerinde zafiyetli şablonlar (ESC1) kapatılmalı, özel anahtarlar TPM veya akıllı kart (Smart Card) ile korunmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Single Crack Modu ile Hızlı Parolaları Çözme
```bash
john --format=NT --single domain_ntds.txt
```
* **Ne Yapar?:** Sözlük kullanmadan kullanıcı adı ve etki alanı adından türeterek zayıf parolaları saniyeler içinde çözer.
* **Ne Zaman Kullanılır?:** NTDS dökümü sonrası ilk hızlı kazanım (quick win) elde etmek için.
* **Parametreler:** `--format=NT`, `--single`.

#### 2. Kerberos `.kirbi` Biletini Dönüştürme ve Kırma
```bash
python3 /usr/share/john/kirbi2john.py ticket.kirbi > ticket.hash && john --format=krb5tgs --wordlist=rockyou.txt ticket.hash
```
* **Ne Yapar?:** Mimikatz biletini JtR formatına çevirir ve sözlükle kırar.
* **Ne Zaman Kullanılır?:** Kerberoasting sonrası servis hesabı parolasını bulmak için.
* **Parametreler:** `kirbi2john.py`, `--format=krb5tgs`.

#### 3. AD CS Sertifika PFX Dosyası Parolasını Kırma
```bash
python3 /usr/share/john/pfx2john.py cert.pfx > pfx.hash && john --format=pfx --wordlist=rockyou.txt pfx.hash
```
* **Ne Yapar?:** PKCS#12 sertifikasını dönüştürerek özel anahtarı koruyan parolayı kırar.
* **Ne Zaman Kullanılır?:** Çalınan etki alanı yöneticisi sertifikalarını içe aktarmadan önce.
* **Parametreler:** `pfx2john.py`, `--format=pfx`.

#### 4. NetNTLMv2 Hash'lerini Kırma
```bash
john --format=netntlmv2 --wordlist=rockyou.txt responder.txt
```
* **Ne Yapar?:** Responder ile yakalanan NTLMv2 ağ hash'lerini sözlükle kırar.
* **Ne Zaman Kullanılır?:** LLMNR zehirlemesi sonrası açık metin parola elde etmek için.
* **Parametreler:** `--format=netntlmv2`.

#### 5. Çoklu CPU Çekirdeği ile Paralel Kırma (`--fork`)
```bash
john --format=NT --fork=8 --wordlist=rockyou.txt hashes.ntds
```
* **Ne Yapar?:** Kırma iş yükünü 8 ayrı paralel işlemci çekirdeğine böler.
* **Ne Zaman Kullanılır?:** Büyük NTDS dökümlerini CPU üzerinde hızlandırmak için.
* **Parametreler:** `--fork=8`.

#### 6. Gelişmiş Kural Seti Uygulama (`--rules=Jumbo`)
```bash
john --format=NT --wordlist=passwords.txt --rules=Jumbo hashes.ntds
```
* **Ne Yapar?:** Kelime listesindeki her adaya yüzlerce mutasyon (büyük/küçük harf, yıl, özel karakter) ekler.
* **Ne Zaman Kullanılır?:** Standart sözlük başarısız olduğunda parola varyasyonlarını denemek için.
* **Parametreler:** `--rules=Jumbo`.

#### 7. Kırılmış Parolaları Ekrana Basma
```bash
john --format=NT --show domain_ntds.txt
```
* **Ne Yapar?:** Potfile içinde kayıtlı olan kırılmış hash ve parola eşleşmelerini listeler.
* **Ne Zaman Kullanılır?:** Kırma tamamlandıktan sonra sonuçları incelemek ve raporlamak için.
* **Parametreler:** `--show`.

#### 8. AS-REP Roasting Hash'lerini Kırma
```bash
john --format=krb5asrep --wordlist=rockyou.txt asrep.txt
```
* **Ne Yapar?:** Önkimlik doğrulaması kapalı kullanıcılardan toplanan AS-REP biletlerini çözer.
* **Ne Zaman Kullanılır?:** GetNPUsers sonrası parola elde etmek için.
* **Parametreler:** `--format=krb5asrep`.

#### 9. Belirli Bir Oturum Adıyla Başlatma ve Devam Ettirme
```bash
john --session=ntds_audit --format=NT --wordlist=large.txt hashes.ntds
john --restore=ntds_audit
```
* **Ne Yapar?:** Kırma işlemini adlandırılmış bir oturum olarak kaydeder; kesilirse kaldığı yerden sürdürür.
* **Ne Zaman Kullanılır?:** Uzun süreli denetimlerde işlemi kontrollü yönetmek için.
* **Parametreler:** `--session=<ad>`, `--restore=<ad>`.

#### 10. Markov Tabanlı Kaba Kuvvet Saldırısı (Incremental)
```bash
john --format=NT --incremental hashes.ntds
```
* **Ne Yapar?:** Dil karakter sıklığı olasılıklarına göre akıllı kaba kuvvet saldırısı yürütür.
* **Ne Zaman Kullanılır?:** Sözlüklerde bulunmayan karmaşık kurumsal parolaları bulmak için.
* **Parametreler:** `--incremental`.

---

## Kaynaklar

* [Openwall Resmi Web Sitesi: John the Ripper](https://www.openwall.com/john/)
* [Openwall Resmi GitHub Deposu: John the Ripper (Jumbo)](https://github.com/openwall/john)
* [John the Ripper Topluluk Wiki ve Dokümantasyonu](https://openwall.info/wiki/john)
* [The Hacker Recipes: Cracking with John the Ripper](https://www.thehacker.recipes/a-d/credentials/cracking)
* [HackTricks: Brute-forcing and Cracking Hashes (John Guide)](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/brute-force.html)
* [MITRE ATT&CK: Password Cracking (T1110.002)](https://attack.mitre.org/techniques/T1110/002/)

---

> **Önceki:** [← Hashcat](./Hashcat.md) · **Son:** [Modül 11 Kök Dizini (README) →](../README.md)
