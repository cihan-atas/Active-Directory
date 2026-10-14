# impacket-describeTicket

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux `.ccache`, Windows `.kirbi` veya ham ASN.1 Kerberos bilet dosyalarını ayrıştırarak bilet bayraklarını, şifreleme türlerini, geçerlilik sürelerini, oturum anahtarlarını (Session Key) ve Privilege Attribute Certificate (PAC) yetkilendirme bloklarını ayrıntılı olarak ekrana döken adli analiz ve protokol denetim aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında Kerberos biletleri ikili (binary) olarak serileştirilmiş karmaşık ASN.1 ve Microsoft PAC veri yapılarından oluşur. Bir sızma testi uzmanı veya kırmızı takım operatörü; bellekten bir bilet çaldığında (`dump`), sahte bir bilet ürettiğinde (`ticketer` / Golden Ticket) veya yetki devri bilet değişimi yaptığında (`getST` / S4U), bu biletin hedef sistemde çalışıp çalışmayacağını anlamak için içeriğini incelemek zorundadır. Ancak bilet içeriğini doğrudan bir metin editörüyle veya basit bir terminal komutuyla okumak mümkün değildir.

**`impacket-describeTicket`**, Kerberos biletlerini RFC 4120 ve Microsoft [MS-PAC] protokol spesifikasyonlarına göre bayt düzeyinde ayrıştıran resmi inceleme ve adli analiz aracıdır:
- **İstemci ve Sunucu Kimliği (Principals):** Biletin hangi kullanıcı adına (`cname`) ve hangi servis/SPN adına (`sname`) düzenlendiğini gösterir.
- **Bilet Bayrakları (Ticket Flags):** Biletin iletilebilir (`forwardable`), yenilenebilir (`renewable`), proxy edilebilir (`proxiable`) veya ilk bilet (`initial`) olup olmadığını listeler.
- **Kriptografik Ayrıntılar:** Kullanılan şifreleme türünü (RC4-HMAC, AES128-CTS-HMAC, AES256-CTS-HMAC) ve oturum anahtarını (Session Key) dışa aktarır.
- **PAC (Privilege Attribute Certificate) Bloğu:** Bilet içindeki kullanıcı SID'sini, etki alanı SID'sini, dahil olunan tüm güvenlik gruplarını (`Domain Admins` - RID 512, `Enterprise Admins` - RID 519), SID History (`extra-sids`) kayıtlarını ve KDC imza bütünlüğünü listeler.

### Microsoft PAC Veri Yapısı ve Tamponları (Buffers)

Microsoft Active Directory ortamında biletin en kritik bileşeni PAC bloğudur. `impacket-describeTicket` aşağıdaki standart PAC tamponlarını teker teker inceler:
1. **`PAC_LOGON_INFO (0x00000001)`:** Kullanıcının hesap adı, etki alanı adı, parola son değiştirilme tarihi, User RID, Primary Group RID ve tüm güvenlik grup üyeliklerini içerir.
2. **`PAC_CLIENT_INFO (0x0000000a)`:** İstemcinin kimlik doğrulama zaman damgasını ve istemci adını saklar.
3. **`PAC_SERVER_CHECKSUM (0x00000006)`:** Hedef sunucunun anahtarı ile imzalanan bütünlük kontrol özetidir.
4. **`PAC_PRIVSVR_CHECKSUM (0x00000007)`:** KDC'nin KRBTGT anahtarı ile imzalanan KDC imza özetidir.
5. **`PAC_ATTRIBUTES_INFO (0x00000011)`:** PAC bayraklarını ve istemci özniteliklerini taşır.
6. **`PAC_REQUESTOR (0x00000012)`:** KB5008380 güncellemesi sonrası eklenen, bileti talep eden hesabın SID değerini doğrulayan kritik tampondur.

### Mimari Akış Şeması

```
[ İncelenecek Kerberos Bilet Dosyası (.ccache / .kirbi / ASN.1) ]
                               │
                               ▼
                 [ impacket-describeTicket ]
                               │
        ┌──────────────────────┴──────────────────────┐
        ▼                                             ▼
┌──────────────────────────────┐        ┌──────────────────────────────┐
│   RFC 4120 KERBEROS KATMANI  │        │   MS-PAC YETKİLENDİRME BLOKU │
│ - Client: Administrator      │        │ - User SID: S-1-5-21-...-500 │
│ - Service: krbtgt/CORP.LOCAL │        │ - Primary Group: 513         │
│ - Auth Time: 2026-04-14      │        │ - Group Memberships:         │
│ - End Time: 2036-04-14 (10y) │        │     * 512 (Domain Admins)    │
│ - Flags: forwardable, initial│        │     * 519 (Enterprise Admins)│
│ - Etype: aes256-cts-hmac     │        │ - Extra SIDs (SID History)   │
│ - Key: 1673a9f0...           │        │ - KDC Signature & Server Sig │
└──────────────────────────────┘        └──────────────────────────────┘
                               │
                               ▼
        [ Ayrıntılı Terminal / Adli Analiz Çıktısı ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Bilet Doğrulama ve Sağlama** | Üretilen Golden/Silver biletlerin sahaya sürülmeden önce yapısını test eder. | Hatalı bilet enjeksiyonundan kaynaklı `KRB_AP_ERR_MODIFIED` hatalarını baştan önler. |
| **Sıfır Ağ İletişimi ile Analiz**| İnceleme tamamen yerel makinede yapılır; DC'ye hiçbir sorgu gitmez. | Ağ sensörlerine ve SOC loglarına takılmadan bilet içeriğini okumayı sağlar. |
| **SID History Denetimi** | Biletin içinde harici orman SID'lerinin bulunup bulunmadığını gösterir. | Forest Hopping ve güven ilişkisi sıçramalarının başarı durumunu teyit eder. |
| **Adli Bilişim (DFIR) Uyumluluğu**| Olay müdahale ekiplerinin sahte biletleri tespit etmesi için gereken anomalileri döker. | Mavi takım tarafında bilet manipülasyonu ve süresi anomalisini kanıtlar. |
| **KB5008380 Uyumluluk Analizi** | Bilette yeni PAC imzalarının ve Requestor SID bloğunun olup olmadığını denetler. | Modern DC'lerde biletin reddedilip reddedilmeyeceğini anlamayı sağlar. |

### Karşılaştırma Tablosu

| Kriter | impacket-describeTicket | Rubeus (describe) | Windows 'klist' | Wireshark Kerberos Parser |
|---|---|---|---|---|
| **Platform** | Linux / Python | Windows (.NET / C#) | Windows (Yerel CLI) | Çapraz Platform (GUI) |
| **Girdi Desteği** | `.ccache` & `.kirbi` Dosyaları | Base64 / `.kirbi` Dosyası | Yalnızca Aktif Bellek | `.pcap` Ağ Paketleri |
| **PAC Detayı Gösterme** | Tam Detay (RID, SID, Sign) | Tam Detay (Hex/Text) | Kısıtlı (Yalnızca süreler) | Kısmi (Şifresiz ise) |
| **Oturum Anahtarı Dökümü**| Var | Var | Yok (Güvenlik gereği) | Yalnızca anahtar biliniyorsa |
| **Ağ İletişimi Şartı** | Hayır (Tamamen Çevrimdışı) | Hayır (Çevrimdışı) | Hayır | Hayır |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
impacket-describeTicket <BILET_DOSYASI>
```

### Bilet Bayrakları Sözlüğü (Ticket Flags)

`impacket-describeTicket` çıktısında listelenen bilet bayrakları RFC 4120 standardında tanımlı şu anlamlara gelir:
- **`forwardable (0x40000000)`:** Biletin başka bir ağ adresine iletilmesine izin verilir (Yetki devri için zorunludur).
- **`forwarded (0x20000000)`:** Biletin bir yetki devri sonucunda iletildiğini belirtir.
- **`proxiable (0x10000000)`:** Biletin bir proxy sunucusu tarafından kullanılabileceğini gösterir.
- **`renewable (0x00800000)`:** Bilet süresi dolmadan önce KDC'ye başvurarak süresinin uzatılabileceğini belirtir.
- **`initial (0x00400000)`:** Biletin doğrudan KDC AS-REP döngüsüyle (TGT olarak) üretildiğini teyit eder.
- **`pre-authent (0x00200000)`:** İstemcinin bilet talep ederken ön kimlik doğrulama sağladığını gösterir.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: impacket-ticketer ile Üretilen Golden Ticket'ın Doğrulanması

Saldırgan `Administrator.ccache` dosyasını oluşturduktan sonra biletin geçerlilik süresini, grup üyeliklerini (`Domain Admins`) ve şifreleme türünü inceleyerek doğrular.

```bash
impacket-describeTicket Administrator.ccache
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[+] Ticket:
    Ticket Version Number: 5
    Server Name: krbtgt/CORP.LOCAL
    Realm: CORP.LOCAL
    Client Name: Administrator
    Auth Time: 2026-04-14 16:30:00
    Start Time: 2026-04-14 16:30:00
    End Time: 2036-04-11 16:30:00 (Validity: 3650 days)
    Renew Till: 2036-04-11 16:30:00
    Flags: 0x40a00000 (forwardable, renewable, pre-authent)
[+] Key:
    KeyType: 18 (aes256-cts-hmac-sha1-96)
    Key: 1673a9f0e1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8
[+] PAC_LOGON_INFO:
    Account Name: Administrator
    User ID: 500
    Primary Group ID: 513 (Domain Users)
    Group Memberships:
        - 512 (Domain Admins)
        - 519 (Enterprise Admins)
        - 520 (Group Policy Creator Owners)
    User SID: S-1-5-21-2559786414-2279769532-2164155192-500
[+] Signatures:
    Server Signature: (Type: 16, Signature: b4c8e1...)
    KDC Signature: (Type: 16, Signature: f9a2d3...)
```

> [!WARNING]
> Çıktıda bilet süresinin **3650 gün** (10 yıl) olduğu açıkça görülmektedir. Bilet sahada kullanılmadan önce OPSEC açısından şüphe çekmeyecek bir süreye (`-duration 1`) ayarlanmalıdır!

---

### Senaryo 2: Windows LSA Belleğinden Çalınan Bir .kirbi Biletinin Kimliğini Öğrenme

Mimikatz ile LSA belleğinden çekilen rastgele isimli bir `.kirbi` dosyasının hangi kullanıcıya ve servise ait olduğunu anlamak için:

```bash
impacket-describeTicket '[0;3e7]-2-0-40e10000-svc_sql@MSSQLSvc.kirbi'
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[+] Ticket:
    Server Name: MSSQLSvc/sql01.corp.local:1433
    Realm: CORP.LOCAL
    Client Name: svc_sql
    End Time: 2026-04-15 02:30:00 (Validity: 10 hours)
    Flags: 0x40a10000 (forwardable, renewable, initial)
[+] Key:
    KeyType: 23 (rc4-hmac)
    Key: 01fc5a6be7bc6929c40372d23f5052b3
[+] PAC_LOGON_INFO:
    Account Name: svc_sql
    User ID: 1105
    Group Memberships:
        - 513 (Domain Users)
        - 1102 (SQL Admins)
```

---

### Senaryo 3: SID History (Forest Hopping) Enjeksiyonunun Tespiti

Güven ilişkisi (Trust) üzerinden Root Domain'e sıçramak amacıyla üretilen bir bilette Extra SIDs alanının doğrulanması:

```bash
impacket-describeTicket forest_hop.ccache
```

**Çıktı Analizi (Extra SIDs Bölümü):**

```text
[+] Extra SIDs:
    - S-1-5-21-9999999999-8888888888-7777777777-519 (Attributes: 0x7 - Enabled, Default, Mandatory)
[+] Result: Bilet kök etki alanının Enterprise Admins grubuna ait SID History değerini başarıyla taşımaktadır!
```

---

### Senaryo 4: Şifreleme Türü ve Oturum Anahtarının İncelenmesi (RC4 vs AES)

Sıkılaştırılmış ve RC4'ün engellendiği bir ortamda biletin doğru şifreleme türüyle üretilip üretilmediğinin denetimi:

```bash
impacket-describeTicket test_ticket.ccache | grep -E "KeyType|End Time|Server Name"
```

---

### Senaryo 5: Diamond Ticket ile Golden Ticket Farkını Ayrıştırma

Diamond Ticket meşru KDC zaman damgası ve meşru PAC imzaları barındırırken, el yapımı Golden Ticket'ta imzaların sahte KDC anahtarıyla türetildiği görülür.

```bash
impacket-describeTicket diamond.ccache
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Cannot parse ASN.1 structure / Bad format` | Bilet dosyası bozuk, eksik indirilmiş veya geçersiz bir veri formatına sahip. | Dosyanın boyutunu kontrol edin; Base64 metni ise önce `base64 -d` ile saf ikiliye çevirin. |
| `Unsupported ticket container / Magic mismatch` | Dosya ne MIT `.ccache` ne de Windows `.kirbi` başlığına sahiptir. | Dosyayı `hexdump -C` ile inceleyip `05 04` (.ccache) veya `76 82` (.kirbi) baytlarını doğrulayın. |
| `KeyError: 'PAC'` | Bilette Privilege Attribute Certificate (PAC) verisi bulunmuyor (Bilet `-no-pac` ile üretilmiş). | Normal bir durumdur; bazı servis biletleri PAC içermeyebilir. |
| `Encrypted PAC cannot be decrypted` | Bilet TGS bileti olup şifreli kısmı çözmek için servis anahtarı sağlanmamış. | impacket-describeTicket yalnızca şifresi çözülmüş oturum anahtarı olan biletlerin içeriğini tam açabilir. |
| `Permission denied` | İlgili dosya için Linux okuma izni eksik. | `chmod +r <dosya>` komutunu uygulayın. |
| `IndexError: tuple index out of range` | Çoklu bilet içeren `.ccache` dosyasında ayrıştırma hatası meydana geldi. | `impacket-ticketConverter` ile tekil bilet haline getirdikten sonra inceleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: SIFIR (TAMAMEN ÇEVRİMDIŞI)
──────────────────────────────────────────────────────────────────
[ Ağ Trafiği ]      : Sıfır paket (Tüm ayrıştırma yerel bellekte gerçekleşir)
[ Windows Logları ] : KDC veya hedef sistemde hiçbir log oluşmaz
[ Kullanım Amacı ]  : Operatörün hata yapmasını önleyen OPSEC güvenlik ağıdır
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

- **Sıfır Operasyonel İz:** `impacket-describeTicket` hiçbir ağ soketi açmaz, RPC çağrısı yapmaz ve etki alanı denetleyicisiyle konuşmaz.
- **DFIR & Adli Bilişim Tarafı:**
  - Olay müdahale (Incident Response) uzmanları ele geçirdikleri şüpheli bilet dosyalarını bu araçla analiz ederek:
    1. Biletin sahte (Golden Ticket) olup olmadığını (10 yıllık süre, olağandışı KDC imzası),
    2. Biletin hangi kullanıcı hesabı ve haklarla donatıldığını,
    3. Hangi Domain SID ve grup RID'lerinin hedeflendiğini dakikalar içinde tespit eder.

### 5.2 Ağ ve EDR İmzaları

- Araç yerel Linux terminalinde çalıştığından hedef Windows ağında hiçbir EDR veya IDS tetiklemesi oluşturmaz.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558** | Steal or Forge Kerberos Tickets | Elde edilen veya sahte üretilen biletlerin bütünlüğünü doğrulama. |
| **T1087** | Account Discovery | Bilet içindeki kullanıcı ve grup SID'lerini çevrimdışı inceleme. |

### 5.4 OPSEC Tavsiyeleri

- **Sahaya Sürmeden Önce Test Edin:** Ürettiğiniz Golden veya Silver Ticket'ı ağda çalıştırmadan önce mutlaka `impacket-describeTicket` ile inceleyin. Bilet süresinin 10 yıl olarak kaldığını veya RC4 ile şifrelendiğini fark ederseniz bileti revize edin.
- **Geçici Dosyaları Temizleyin:** İnceleme tamamlandıktan sonra bilet dosyasını yerel diskten kaldırın.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Linux .ccache Biletinin Tam Yapısını İnceleme
```bash
impacket-describeTicket admin.ccache
```
- **Ne Yapar?** Belirtilen `.ccache` dosyasındaki Kerberos biletinin tüm başlıklarını, bayraklarını, geçerlilik sürelerini ve PAC gruplarını ekrana basar.
- **Ne Zaman Kullanılır?** `getTGT` veya `ticketer` ile üretilen biletin içeriğini doğrulamak için.
- **Parametreler:** Dosya adı tek argümandır.

### Komut 2: Windows .kirbi Biletini Ayrıştırma
```bash
impacket-describeTicket ticket.kirbi
```
- **Ne Yapar?** Windows Mimikatz/Rubeus formatındaki biletin ASN.1 yapısını çözerek kullanıcı ve servis detaylarını listeler.
- **Ne Zaman Kullanılır?** Windows bellek dökümünden elde edilen biletin kime ait olduğunu anlamak için.
- **Parametreler:** `.kirbi` dosya yolu.

### Komut 3: Yalnızca Bilet Sürelerini ve İsimlerini Filtreleme
```bash
impacket-describeTicket admin.ccache | grep -E "Client Name|Server Name|End Time|Flags"
```
- **Ne Yapar?** Çıktıyı filtreleyerek yalnızca kullanıcı adı, servis adı, bitiş süresi ve bilet bayraklarını gösterir.
- **Ne Zaman Kullanılır?** Hızlı bir şekilde biletin geçerlilik süresini ve hedefini kontrol etmek için.
- **Parametreler:** Standart Linux `grep` filtresi.

### Komut 4: PAC Grup Üyeliklerini Listeleme
```bash
impacket-describeTicket golden.ccache | grep -A 10 "Group Memberships:"
```
- **Ne Yapar?** Bilet sahibinin üye olduğu tüm güvenlik gruplarını (Domain Admins, Enterprise Admins vb.) gösterir.
- **Ne Zaman Kullanılır?** Biletin hedef sistemde hangi yetkileri taşıyacağını teyit etmek için.
- **Parametreler:** `grep -A 10`: Başlıktan sonraki 10 satırı yazdırır.

### Komut 5: SID History (Extra SIDs) Varlığını Kontrol Etme
```bash
impacket-describeTicket forest.ccache | grep -A 5 "Extra SIDs:"
```
- **Ne Yapar?** Bilette ormanlar arası yetki atlama (Forest Hopping) için eklenmiş harici SID'lerin bulunup bulunmadığını kontrol eder.
- **Ne Zaman Kullanılır?** Alt etki alanından kök etki alanına yapılan bilet sahteciliğini doğrulamak için.
- **Parametreler:** Extra SIDs arama filtresi.

### Komut 6: Oturum Anahtarını (Session Key) Çekme
```bash
impacket-describeTicket admin.ccache | grep -A 2 "Key:"
```
- **Ne Yapar?** İstemci ile sunucu arasındaki simetrik oturum anahtarını ve şifreleme algoritmasını görüntüler.
- **Ne Zaman Kullanılır?** Wireshark ile şifreli Kerberos trafiğini çözmek için oturum anahtarına ihtiyaç duyulduğunda.
- **Parametreler:** Key arama filtresi.

### Komut 7: Şifreleme Türü Analizi (RC4 vs AES)
```bash
impacket-describeTicket ticket.ccache | grep "KeyType:"
```
- **Ne Yapar?** Biletin RC4 (`KeyType: 23`), AES-128 (`KeyType: 17`) veya AES-256 (`KeyType: 18`) ile şifrelendiğini tek satırda gösterir.
- **Ne Zaman Kullanılır?** Modern ortamlarda OPSEC uyumluluğunu doğrulamak için.
- **Parametreler:** KeyType filtresi.

### Komut 8: Adli Bilişim İncelemesinde Rapor Oluşturma
```bash
impacket-describeTicket evidence_ticket.kirbi > /tmp/forensic_report.txt
```
- **Ne Yapar?** Biletin tüm bileşenlerini adli analiz raporuna eklenmek üzere metin dosyasına kaydeder.
- **Ne Zaman Kullanılır?** Siber olay müdahale (DFIR) süreçlerinde sahte bilet kanıtı oluştururken.
- **Parametreler:** Standart kabuk yönlendirmesi (`>`).

### Komut 9: Bilet Bayraklarını İnceleme (Forwardable Kontrolü)
```bash
impacket-describeTicket s4u.ccache | grep "Flags:"
```
- **Ne Yapar?** Biletin yetki devri için uygun (`forwardable`) olup olmadığını doğrular.
- **Ne Zaman Kullanılır?** Kısıtlı yetki devri operasyonlarında bilet reddedilmeden önce kontrol için.
- **Parametreler:** Flags filtresi.

### Komut 10: Kullanıcı RID Değerini Teyit Etme
```bash
impacket-describeTicket admin.ccache | grep -E "User ID|Account Name"
```
- **Ne Yapar?** Biletin yerel Administrator (RID 500) mi yoksa standart bir kullanıcı adına mı düzenlendiğini gösterir.
- **Ne Zaman Kullanılır?** Taklit edilen hesabın kimliğini kontrol ederken.
- **Parametreler:** RID filtresi.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **Microsoft Protocol Specification:** [[MS-PAC]: Privilege Attribute Certificate Data Structure](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/)
- **RFC 4120:** [The Kerberos Network Authentication Service (V5)](https://datatracker.ietf.org/doc/html/rfc4120)
- **SpecterOps:** [Kerberos Ticket Forensics and PAC Validation](https://posts.specterops.io/)

---

> **Önceki:** [← impacket-ticketConverter](./impacket-ticketConverter.md) · **Sonraki:** [TGSTomp →](./TGSTomp.md)
