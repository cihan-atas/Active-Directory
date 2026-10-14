# adalanche

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Lars Karlslund (@lkarlslund) tarafından Go dilinde geliştirilen; harici bir Neo4j veya Docker veritabanına ihtiyaç duymadan, LDAP üzerinden Active Directory ACL ve yetki zincirlerini toplayıp dahili bellek içi graf motoru ve gömülü web arayüzü ile görselleştiren bağımsız saldırı yolu analiz aracı.

---

## 1. Genel Bakış ve Amaç

**adalanche**, Active Directory ortamlarındaki Erişim Denetim Listeleri (ACL), nesne sahiplikleri ve grup üyelik hiyerarşilerini analiz etmek amacıyla geliştirilmiş modern, hızlı ve bağımsız bir graf analiz platformudur. BloodHound'un getirdiği graf tabanlı saldırı yolu mantığını benimseyen adalanche; harici bir veritabanı motoru (Neo4j, PostgreSQL), Java çalışma ortamı veya Docker konteyner altyapısı **gerektirmemesiyle** öne çıkar.

Go dilinde statik olarak derlenmiş tek bir ikili (single standalone binary) olarak dağıtılan araç, hedef etki alanına standart LDAP/LDAPS protokolleri üzerinden bağlanır. Dizin nesnelerini çeker çekmez kendi dahili bellek içi (in-memory) graf motorunda işler ve yerel bir web soketi açarak (varsayılan: `http://localhost:4888`) operatöre zengin, interaktif ve donanım hızlandırmalı bir web arayüzü sunar.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              ADALANCHE ÇALIŞMA MİMARİSİ                           |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Kali / Windows / macOS]
                     adalanche [bağlantı seçenekleri] visual
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kimlik Doğrulama Katmanı                                   |
|  - Kullanıcı Adı & Açık Metin Parola (-username / -password)                      |
|  - Pass-the-Hash (-hashes LM:NT)                                                  |
|  - Kerberos Bileti                                                                |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Dahili Go LDAP İstemcisi                                   |
|   (Sayfalanmış LDAP / LDAPS Sorguları: TCP 389 / 636)                            |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Hedef Active Directory                               |
|        Domain Controllers (Users, Groups, Computers, OUs, DACLs, ACEs)            |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                     Dahili Bellek İçi Graf Motoru (In-Memory)                     |
|  - Harici Neo4j / Veritabanı YOK!                                                 |
|  - Otomatik Kısa Yol (Shortest Path) ve Yetki Tırmanma Algoritmaları             |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                     Gömülü Web Sunucusu & İnteraktif UI                           |
|       http://127.0.0.1:4888 (Web Arayüzü, Graf Görselleştirme, Analiz Raporu)     |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi Avantajı |
|---|---|---|
| **Sıfır Bağımlılık (Standalone)** | Docker, Java veya Neo4j kurulumu gerektirmez. | Saniyeler içinde kurulup çalıştırılır; kısıtlı ortamlarda hayat kurtarır. |
| **Dahili Web Görselleştirme** | Kendi içinde barındırdığı modern web UI ile grafı render eder. | Tarayıcıda anında etkileşimli saldırı yollarını inceleme imkanı verir. |
| **Yüksek Performans (Go)** | Çok iş parçacıklı (goroutine) yapısıyla verileri çok hızlı toplar. | 100.000+ nesneli dev etki alanlarında dahi düşük kaynak tüketimi sağlar. |
| **Pass-the-Hash Desteği** | Açık metin parola olmadan NTLM hash ile çalışabilir. | Kimlik bilgisi kırmaya gerek kalmadan graf analizini başlatır. |
| **Çevrimdışı İnceleme** | Toplanan verileri SQLite veya yerel dosya formatında saklar. | Müşteri ağından çıktıktan sonra veritabanı kurmadan incelemeyi sürdürür. |

### 1.1 adalanche Tarafından Modellenen Kritik Yetki Kenarları (Graph Edges)

adalanche, dizindeki Access Control Entries (ACE) ve üyelik ilişkilerini çözerken aşağıdaki kritik saldırı kenarlarını haritalandırır:

| Graf Kenarı (Edge) | Kaynak Nesne | Hedef Nesne | İstismar Yöntemi (Abuse Vector) |
|---|---|---|---|
| **`CanResetPassword`** | Kullanıcı / Grup | ADUser | Hedef kullanıcının parolasını doğrudan sıfırlayarak hesaba el koyma. |
| **`WriteDacl`** | Kullanıcı / Grup | Herhangi Nesne | Nesnenin DACL'ına `GenericAll` hakkı ekleyerek tam denetim kazanma. |
| **`WriteOwner`** | Kullanıcı / Grup | Herhangi Nesne | Nesne sahipliğini (Owner) devralıp ardından izinleri yeniden yazma. |
| **`GenericAll`** | Kullanıcı / Grup | Herhangi Nesne | Hedef nesne üzerinde sınırsız hak (Grup üyesi ekleme, parola sıfırlama). |
| **`GenericWrite`** | Kullanıcı / Grup | ADUser / ADComputer| `scriptPath`, `msDS-KeyCredentialLink` gibi kritik öznitelikleri değiştirme. |
| **`AddMember`** | Kullanıcı / Grup | ADGroup | Gruba doğrudan kullanıcı ekleme (örneğin Server Operators grubuna sızma). |
| **`DCSync`** | Kullanıcı / Bilgisayar | Domain-DNS | `DS-Replication-Get-Changes-All` hakkıyla NTDS.dit hash dökümü alma. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | adalanche | BloodHound CE | SharpHound | PowerView.ps1 | PingCastle |
|---|---|---|---|---|---|
| **Altyapı Gereksinimi** | **Yok (Tek Binary)** | Docker + Neo4j + PG | Yok (Sadece Toplayıcı) | Yok (PowerShell) | Yok (Tek Binary) |
| **Görselleştirme** | Gömülü Web UI | Web UI (CE) | Yok (Graf İstemcisi Gerekir) | Yok | HTML Rapor |
| **Saldırı Yolu Analizi** | Var (Dahili) | Mükemmel (Cypher) | Yok | Manuel Sorgu | Risk Puanı |
| **Toplama Hızı** | Çok Yüksek (Go) | Orta | Yüksek (.NET) | Orta | Yüksek |
| **Platform** | Linux, Win, macOS | Linux, Win, macOS | Windows | Windows | Windows |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

adalanche CLI arayüzü genel bayraklar ve ardından çalıştırılacak çalışma modundan oluşur:

```bash
adalanche [genel_seçenekler] [komut / mod]
```

### 2.1 Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-server` | Hedef Etki Alanı Denetleyicisi IP'si veya FQDN'i. | `-server 10.10.10.10` |
| `-domain` | Hedef Active Directory etki alanı adı. | `-domain corp.local` |
| `-username` | Kimlik doğrulamada kullanılacak kullanıcı adı. | `-username ahmet` |
| `-password` | İlgili kullanıcının açık metin parolası. | `-password 'Parola123!'` |
| `-hashes` | NTLM kimlik doğrulama hash'i (`LM:NT` veya `:NT`). | `-hashes :e19ccf75ee...` |
| `-ssl` | Güvenli LDAPS (TCP 636) protokolünü zorlar. | `-ssl` |
| `-insecure` | Kendinden imzalı (self-signed) SSL sertifikalarını yoksayar. | `-insecure` |

### 2.2 Çalışma Modları ve Komutlar

| Mod / Komut | Açıklama |
|---|---|
| `visual` | Dizin verisini toplar, dahili graf motoruna yükler ve web arayüzünü (port 4888) başlatır. |
| `collect` | Yalnızca veriyi toplar ve yerel bir veri tabanı dosyasına (`.db`) kaydeder. |
| `dump` | Çevrimdışı kayıtlı veri tabanını analiz ederek konsola özet metin raporu döker. |
| `serve` | Daha önce `collect` ile kaydedilmiş veri tabanını web arayüzünde açar. |

### 2.3 Sunucu ve Ağ Yapılandırma Parametreleri

| Parametre | Açıklama | Varsayılan Değer |
|---|---|---|
| `-listen` | Web arayüzünün bağlanacağı IP ve port adresi. | `127.0.0.1:4888` |
| `-db` | Veri tabanı dosyasının kaydedileceği veya okunacağı yol. | `adalanche.db` |
| `-threads` | Eşzamanlı çalışacak LDAP sorgu iş parçacığı sayısı. | `8` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Tek Komutla Keşif ve Web Arayüzünü Başlatma

Hedef DC'ye bağlanıp tüm nesneleri çekerek doğrudan tarayıcı üzerinden graf analizini başlatma:

```bash
adalanche -server 10.10.10.10 -domain corp.local -username ahmet -password 'Parola123!' visual
```

**Konsol Çıktısı Analizi:**

```text
[*] adalanche v2024.1 - Active Directory Graph Analysis Engine
[*] Connecting to LDAP server 10.10.10.10:389...
[+] Connected! Authenticated as corp.local\ahmet
[*] Collecting directory objects (Users, Groups, Computers, OUs, DACLs)...
[*] Fetched 2,410 Users...
[*] Fetched 320 Groups...
[*] Fetched 850 Computers...
[*] Fetched 18,400 Access Control Entries (ACEs)...
[*] Processing ACL graph in memory... [DONE]
[*] Starting embedded web server at http://127.0.0.1:4888
[+] Ready! Open your browser and navigate to http://127.0.0.1:4888 to view the graph.
```
*Analiz: Harici hiçbir Docker konteyneri veya veritabanı kurmaya gerek kalmadan tüm etki alanı grafı çıkarılmış ve `http://127.0.0.1:4888` adresinde tarayıcıya hazır hale getirilmiştir.*

### Senaryo 2: Pass-the-Hash ile Parolasız Analiz Başlatma

Açık metin parola bilinmiyorken NTLM hash kullanarak güvenli LDAPS üzerinden analiz başlatma:

```bash
adalanche -server 10.10.10.10 -domain corp.local -username mehmet -hashes ':8846f7eaee8fb117ad06bdd830b7586c' -ssl -insecure visual
```

### Senaryo 3: Veriyi Sadece Toplayıp Dosyaya Kaydetme (Collect Modu)

Müşteri veya hedef ağda uzun süre kalmamak için hızlıca veriyi diske kaydedip oturumu sonlandırma:

```bash
adalanche -server 10.10.10.10 -domain corp.local -username ahmet -password 'Parola123!' -db /opt/loot/corp_ad.db collect
```

### Senaryo 4: Daha Önce Toplanmış Veritabanını Çevrimdışı İnceleme (Serve Modu)

Ağ bağlantısı kesildikten sonra yerel makinede kaydedilen `.db` dosyasını web arayüzünde açma:

```bash
adalanche -db /opt/loot/corp_ad.db serve
```

### Senaryo 5: Web Arayüzünü Ağdaki Diğer Ekip Üyelerine Açma

Sızma testi ekibindeki diğer araştırmacıların da grafı inceleyebilmesi için servisi tüm arayüzlerde (`0.0.0.0`) dinletme:

```bash
adalanche -db corp_ad.db -listen 0.0.0.0:4888 serve
```

### Senaryo 6: SOCKS5 Proxy / C2 Pivot Üzerinden Uzaktan Çalıştırma

İç ağdaki bir implant üzerinden proxychains ile tünellenerek doğrudan saldırgan makinesinden veri toplama:

```bash
proxychains4 adalanche -server 10.10.10.10 -domain corp.local -username pentest -password 'Pass123!' -db pivot_corp.db collect
```
*Bu yöntem kurban Windows makinesinde hiçbir dosya çalıştırmadan veya port açmadan doğrudan pivot üzerinden veritabanını yerel Linux diskinize çeker.*

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Failed to bind to LDAP: invalid credentials` | Kullanıcı adı veya parola hatalı girildi ya da UPN formatı uyuşmadı. | Kullanıcı adını etki alanı öneki olmadan (`ahmet`) veya UPN (`ahmet@corp.local`) olarak deneyin. Özel karakterleri tek tırnak içine alın. |
| `listen tcp 127.0.0.1:4888: bind: address already in use` | 4888 portu başka bir adalanche süreci veya uygulama tarafından kullanılıyor. | Komuta `-listen 127.0.0.1:5888` parametresini ekleyerek farklı bir boş porta yönlendirin. |
| `x509: certificate signed by unknown authority` | `-ssl` bayrağı ile bağlanırken DC'nin SSL sertifikası doğrulanamadı. | Komuta `-insecure` bayrağını ekleyerek sertifika doğrulamasını atlayın. |
| `Out of memory / killed during graph processing` | Milyonlarca ACE içeren devasa kurumsal ortamlarda bellek (RAM) yetersizliği. | Makinenin swap alanını artırın veya `-threads 2` ile eşzamanlı işlem yükünü azaltın. |
| `Failed to connect to LDAP server: dial tcp: i/o timeout` | DC IP adresine erişilemiyor, port 389 güvenlik duvarı tarafından engelli veya routing yok. | Ağ erişimini `nc -nvz <DC_IP> 389` ile test edin; VPN ve rota tablolarını kontrol edin. |
| `Access Denied during container enumeration` | Kurban kullanıcının bazı hassas OU'lar (örneğin Domain Controllers OU) üzerinde okuma izni kısıtlanmış. | adalanche izin alabildiği tüm nesneleri toplamaya devam eder; hata kritik değildir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

adalanche, BloodHound/SharpHound benzeri bir graf toplayıcısı olduğu için hedef ağ üzerinde belirli LDAP ve ağ izleri bırakır.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4624 (Logon Type 3):**
   - Etki Alanı Denetleyicisine yapılan LDAP/S bağlantısı ağ oturumu olarak loglanır.
2. **Directory Service Expensive Queries (Event ID 1644):**
   - Tüm kullanıcı, bilgisayar ve ACL nesnelerini çektiği için DC tarafında yüksek hacimli arama alarmı üretir.
3. **Açılan Yerel Dinleme Soketi (Port 4888):**
   - Eğer `visual` veya `serve` modu doğrudan sızılan bir hedef makinede çalıştırılırsa, makinede açılan port 4888 EDR/SOC tarafından yerel dinleme anomalisi olarak yakalanır.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Sayfalama Trafiği:** Kısa süre içerisinde DC'den megabaytlarca ACL ve nesne verisinin tek bir soketten çekilmesi.
- **Go HTTP İstemci İmzası:** Kaynak kod seviyesinde özelleştirilmemişse standart Go LDAP istemci paket başlıkları.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | adalanche Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı nesnelerinin toplanması |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup ve iç içe grup üyeliklerinin tespiti |
| **T1018** | Remote System Discovery | Bilgisayar ve DC envanteri |
| **T1484.001** | Domain Policy Modification: Group Policy Modification | GPO ve yetki zincirlerinin analizi |
| **T1078.002** | Valid Accounts: Domain Accounts | Pass-the-Hash ve meşru hesapla kimlik doğrulama |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Kurban Makinede Port Açılması**| Hedef makinede `visual` moduyla port 4888 dinletilmesi. | adalanche'ı **asla** kurban Windows host'unda çalıştırmayın; doğrudan kendi Linux saldırı makinenizden uzaktan çalıştırın. |
| **Açık Metin LDAP Trafiği** | Port 389 trafiğinin IDS/NDR sistemleri tarafından dinlenmesi. | Her zaman `-ssl -insecure` bayraklarıyla bağlantıyı TLS üzerinden şifreleyin. |
| **Büyük Veri İndirme Uyarısı** | Tüm nesnelerin tek seferde hızlıca çekilmesi. | Yoğun izleme yapılan hassas ağlarda adalanche yerine `ldeep` ile cerrahi tekil sorgular tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

LDAP üzerinden toplu ACL okuma aktivitelerini tespit eden örnek kural mantığı:

```yaml
title: Mass Active Directory ACL Enumeration
id: a7391bc4-adalanche-acl-recon
status: experimental
description: Detects large-scale querying of Active Directory DACLs and ACEs typically generated by BloodHound or adalanche.
logsource:
    product: windows
    service: directory_service
detection:
    selection:
        EventID: 1644
        SearchFilter|contains:
            - '(nTSecurityDescriptor=*)'
    condition: selection
level: medium
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Tek Hamlede Dizin Keşfi ve Web Graf Arayüzünü Başlatma
adalanche -server 10.10.10.10 -domain corp.local -username user -password pass visual
```
- **Ne Yapar?** Tüm AD nesnelerini ve ACL'leri toplar, bellekte işler ve `http://localhost:4888` arayüzünü açar.
- **Ne Zaman Kullanılır?** Hızlıca saldırı yollarını görselleştirmek istendiğinde.
- **Parametreler:** `-server` DC IP'si; `-domain` etki alanı; `visual` GUI başlatma modu.

```bash
# 2. Şifreli LDAPS (Port 636) ile Güvenli Analiz
adalanche -server dc01.corp.local -domain corp.local -username user -password pass -ssl -insecure visual
```
- **Ne Yapar?** Trafiği TLS şifrelemesiyle yaparak ağ koklayıcılarından (sniffers) gizler.
- **Ne Zaman Kullanılır?** Ağ üzerinde aktif IDS/NDR izlemesi varken.
- **Parametreler:** `-ssl` port 636 kullanımı; `-insecure` sertifika uyarısını yoksayma.

```bash
# 3. Pass-the-Hash ile NTLM Hash Kullanarak Çalıştırma
adalanche -server 10.10.10.10 -domain corp.local -username user -hashes ':hash' visual
```
- **Ne Yapar?** Açık metin parola olmadan NTLM hash ile kimlik doğrulayıp grafı çıkarır.
- **Ne Zaman Kullanılır?** Bellekten veya SAM veritabanından yalnızca NTLM hash elde edildiğinde.
- **Parametreler:** `-hashes` NTLM hash değeri.

```bash
# 4. Yalnızca Veriyi Toplayıp Yerel Dosyaya Kaydetme (Collect)
adalanche -server 10.10.10.10 -domain corp.local -username user -password pass -db target.db collect
```
- **Ne Yapar?** Web arayüzünü açmadan sadece veriyi çeker ve `target.db` dosyasına yazar.
- **Ne Zaman Kullanılır?** Ağda kısa süre kalıp hızlıca veri indirmek istendiğinde.
- **Parametreler:** `collect` toplama modu; `-db` çıktı veri tabanı yolu.

```bash
# 5. Kaydedilmiş Veritabanını Çevrimdışı Web Arayüzünde Açma (Serve)
adalanche -db target.db serve
```
- **Ne Yapar?** Ağ bağlantısına ihtiyaç duymadan yerel `target.db` dosyasını `http://localhost:4888` üzerinde açar.
- **Ne Zaman Kullanılır?** Müşteri ağından ayrıldıktan sonra çevrimdışı analiz yaparken.
- **Parametreler:** `serve` sunucu modu; `-db` okunacak veri tabanı.

```bash
# 6. Web Arayüzünü Tüm Ekip Üyelerine Açma (0.0.0.0)
adalanche -db target.db -listen 0.0.0.0:4888 serve
```
- **Ne Yapar?** Web arayüzünü yerel makine dışındaki IP'lerden erişime açar.
- **Ne Zaman Kullanılır?** Kırmızı takım operasyonlarında grafı ekip arkadaşlarıyla paylaşırken.
- **Parametreler:** `-listen 0.0.0.0:4888` dinleme soketi.

```bash
# 7. Konsola Özet Metin Raporu Dökme (Dump)
adalanche -db target.db dump
```
- **Ne Yapar?** Web tarayıcısı açmadan en kritik yetkileri ve özet graf istatistiklerini terminale basar.
- **Ne Zaman Kullanılır?** SSH veya kısıtlı komut satırı ortamlarında hızlı çıktı almak için.
- **Parametreler:** `dump` konsol döküm modu.

```bash
# 8. Eşzamanlı İş Parçacığı Sayısını Ayarlayarak Hızlı Toplama
adalanche -server 10.10.10.10 -domain corp.local -username user -password pass -threads 16 collect
```
- **Ne Yapar?** Eşzamanlı goroutine sayısını 16'ya çıkararak toplama süresini minimuma indirir.
- **Ne Zaman Kullanılır?** Büyük kurumsal ağlarda keşif süresini hızlandırmak için.
- **Parametreler:** `-threads 16` iş parçacığı sayısı.

```bash
# 9. Özel Port Üzerinde Web Sunucusu Başlatma
adalanche -db target.db -listen 127.0.0.1:8888 serve
```
- **Ne Yapar?** Varsayılan port 4888 meşgulse graf web sunucusunu port 8888 üzerinde açar.
- **Ne Zaman Kullanılır?** Port çakışmalarını önlemek veya standart portları atlatmak için.
- **Parametreler:** `-listen` yerel IP ve hedef port.

```bash
# 10. Proxychains ile C2 SOCKS Tüneli Üzerinden Çalıştırma
proxychains4 adalanche -server 10.10.10.10 -domain corp.local -username user -password pass -db remote.db collect
```
- **Ne Yapar?** C2 pivot tüneli üzerinden doğrudan uzaktan veritabanı dökümü alır.
- **Ne Zaman Kullanılır?** Hedef ağda doğrudan IP rotası bulunmadığında.
- **Parametreler:** `proxychains4` SOCKS tünelleme sağlar; `collect` yerel dosyaya yazar.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [lkarlslund / adalanche](https://github.com/lkarlslund/adalanche)
- **Lars Karlslund Blogu:** [Active Directory ACL Graph Analysis](https://twitter.com/lkarlslund)
- **BloodHound vs adalanche Analizi:** [SpectreOps Graph Theory Research](https://posts.specterops.io/)
- **MITRE ATT&CK Framework:** [Technique T1087 - Account Discovery](https://attack.mitre.org/techniques/T1087/)

---

> **Önceki:** [← ldeep](./ldeep.md) · **Sonraki:** [AdFind.exe →](./AdFind.md)
