# ldapdomaindump

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Dirk-jan Mollema (@_dirkjan) tarafından geliştirilen; Active Directory etki alanındaki tüm nesneleri LDAP sayfalama (paging) yöntemiyle hızlıca çekip çevrimdışı incelemeye uygun HTML, JSON ve Grep formatında raporlayan Python tabanlı dizin döküm aracı.

---

## 1. Genel Bakış ve Amaç

**ldapdomaindump** (kısaca `ldd`), sızma testi uzmanlarının ve kırmızı takım operatörlerinin hedef Active Directory etki alanından tek bir hamlede kapsamlı bir bilgi havuzu oluşturmasını sağlayan popüler bir keşif aracıdır. Araç, saf Python ve **ldap3** kütüphanesi üzerine inşa edilmiş olup, standart bir etki alanı kullanıcısının (veya izin verilmişse anonim kullanıcının) okuma izinlerini kullanarak hedef Etki Alanı Denetleyicisine (DC) bağlanır.

ldapdomaindump'ın en ayırt edici mimari özelliği, LDAP protokolünün **Basit Sayfalanmış Sonuçlar Kontrolü (Simple Paged Results Control - RFC 2696)** yeteneğini kullanarak on binlerce nesneyi DC sunucusunu kilitlemeden veya bellek sınırlarına takılmadan parça parça çekmesidir. Toplanan veriler; taranabilir ve bağlantılı **HTML tablolarına**, komut satırında hızlıca filtrelenebilen **grep dostu düz metin dosyalarına (.grep)** ve diğer araçlara aktarılabilecek **yapılandırılmış JSON dosyalarına** dönüştürülür.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                           LDAPDOMAINDUMP ÇALIŞMA MİMARİSİ                         |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Kali Linux / Sızma Testçisi]
                       ldapdomaindump [bağlantı bayrakları]
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                       Kimlik Doğrulama Mekanizması                                |
|  - Standart Kullanıcı Parolası (user:pass)                                        |
|  - Anonim / Null Oturum (Anonymous Binding)                                       |
|  - NTLM Kimlik Doğrulaması veya Kerberos                                          |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        LDAP İletişimi & Paged Search Motoru                       |
|   (ldap3 RFC 2696 Paging - 1000'lik Sayfalar Halinde Asenkron Döküm)              |
|              Port 389 (LDAP) veya Port 636 (LDAPS / StartTLS)                     |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Hedef Etki Alanı Denetleyicisi                        |
|        Active Directory Veritabanı (NTDS.dit İçindeki Dizin Nesneleri)            |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                         Üretilen Çevrimdışı Rapor Dosyaları                       |
+-----------------------------------------------------------------------------------+
  |-- domain_users.html / .json / .grep        (Tüm Kullanıcılar & SPN'ler)
  |-- domain_computers.html / .json / .grep    (Bilgisayarlar & İşletim Sistemleri)
  |-- domain_groups.html / .json / .grep       (Güvenlik Grupları & Üyelikler)
  |-- domain_policy.html / .json / .grep       (Parola Politikaları & Eşikler)
  |-- domain_trusts.html / .json / .grep       (Güven İlişkileri & Yönleri)
  |-- domain_ous.html / .json / .grep          (Organizasyonel Birimler / Hiyerarşi)
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Saldırı / Analiz Avantajı |
|---|---|---|
| **Çevrimdışı Analiz (Offline Recon)** | Tüm etki alanı verisini tek seferde yerel diske indirir. | Ağ bağlantısı kopsa veya tespit edilip atılsanız dahi verileri çevrimdışı inceleme imkanı verir. |
| **İnteraktif HTML Raporları** | Kullanıcı, bilgisayar ve grup ilişkilerini köprülerle (hyperlink) bağlar. | Web tarayıcısında tıklayarak nesneler arasında gezinme kolaylığı sağlar. |
| **Hızlı Grep Edilebilirlik** | Her varlık için tab-separated `.grep` dosyaları üretir. | `grep -i "admin" domain_users.grep` ile milisaniyeler içinde komut satırı araması yapılır. |
| **NetExec Entegrasyonu** | NetExec içerisinde dahili modül (`-M ldapdomaindump`) olarak yer alır. | Ayrı bir komut dizisi ezberlemeden hızlıca DC keşfi tetiklenebilir. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | ldapdomaindump | ldeep | ADRecon | BloodHound.py | ldapsearch |
|---|---|---|---|---|---|
| **Rapor Formatı** | HTML, JSON, Grep | CLI Tablo, JSON | Excel (.xlsx), CSV | Neo4j Graf JSON | Ham LDIF Metin |
| **Görselleştirme** | Statik HTML Sayfaları | Yok (Konsol Çıktısı) | Excel Çalışma Kitabı | İnteraktif Graf UI | Yok |
| **Ağ Gürültüsü** | Orta | Düşük (Hedefli) | Yüksek | Orta / Yüksek | Düşük (Tekil Sorgu)|
| **Paging Desteği** | Var (Otomatik) | Var | Var | Var | Manuel (`-E pr=...`)|
| **Kurulum / Dil** | Python 3 (Hafif) | Python 3 | PowerShell | Python 3 | C (OpenLDAP) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ldapdomaindump doğrudan terminalden çalıştırılan bir Python komut satırı aracıdır:

```bash
ldapdomaindump [seçenekler] [hedef_dc]
```

### 2.1 Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Kısa Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| `-u`, `--user` | `-u` | Kimlik doğrulamada kullanılacak kullanıcı adı (`DOMAIN\user` veya `user`). | `-u "corp\jdoe"` |
| `-p`, `--password` | `-p` | İlgili kullanıcının açık metin parolası. | `-p "P@ssw0rd123"` |
| `-at`, `--authtype`| `-at`| Kimlik doğrulama yöntemi (`NTLM` veya `SIMPLE`). | `-at NTLM` |
| `-s`, `--ssl` | `-s` | Bağlantıda LDAPS (port 636) protokolünü zorlar. | *(Anahtar bayrak)* |
| `-t`, `--starttls` | `-t` | Standart port 389 üzerinden StartTLS şifreli oturumu başlatır. | *(Anahtar bayrak)* |
| `-b`, `--base` | `-b` | LDAP arama kökünü belirler (Distinguished Name). | `-b "DC=corp,DC=local"` |

### 2.2 Çıktı ve Format Parametreleri

| Parametre | Açıklama | Varsayılan Değer |
|---|---|---|
| `-o`, `--outdir` | Raporların ve dosyaların kaydedileceği yerel klasör yolu. | Mevcut dizin (`.`) |
| `--no-html` | HTML raporlarının üretilmesini engeller. | `false` |
| `--no-json` | JSON dosyalarının üretilmesini engeller. | `false` |
| `--no-grep` | Grep dostu düz metin (.grep) dosyalarının üretilmesini engeller. | `false` |
| `--grouped-json` | Kullanıcı ve bilgisayar nesnelerini grup bazlı hiyerarşik JSON yapar. | `false` |

### 2.3 Üretilen Rapor Dosyaları ve İçerikleri

| Dosya Adı | Formatlar | Kapsadığı Dizin Bilgisi |
|---|---|---|
| `domain_users` | `.html`, `.json`, `.grep` | Tüm kullanıcılar, sAMAccountName, e-posta, SPN'ler, adminCount, son giriş zamanı. |
| `domain_computers` | `.html`, `.json`, `.grep` | Etki alanındaki tüm makineler, işletim sistemleri, DNS adları, IP adresleri. |
| `domain_groups` | `.html`, `.json`, `.grep` | Tüm güvenlik ve dağıtım grupları, grup üyeleri ve üye türleri. |
| `domain_policy` | `.html`, `.json`, `.grep` | Minimum parola uzunluğu, kilitlenme eşiği, parola geçerlilik süresi. |
| `domain_trusts` | `.html`, `.json`, `.grep` | Güvenilen etki alanları, güven yönleri (Inbound/Outbound/Bidirectional) ve türleri. |
| `domain_ous` | `.html`, `.json`, `.grep` | Organizasyonel Birimler (OU), hiyerarşik yapı ve nesne dağılımları. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı ile Tüm Dökümü Alma

Geçerli bir etki alanı kullanıcısıyla tüm dizin yapısını `/opt/recon/ldd_out` klasörüne dökme:

```bash
ldapdomaindump -u "corp.local\ahmet" -p "Parola123!" -o /opt/recon/ldd_out 10.10.10.10
```

**Konsol Çıktısı Analizi:**

```text
[*] Connecting to host...
[*] Binding to host...
[+] Bind OK
[*] Starting domain dump
[*] Dumping domain policy...
[*] Dumping users...
[*] Dumping groups...
[*] Dumping computers...
[*] Dumping trusts...
[*] Dumping OUs...
[*] Writing domain policy to /opt/recon/ldd_out/domain_policy.html
[*] Writing users to /opt/recon/ldd_out/domain_users.html
[*] Writing groups to /opt/recon/ldd_out/domain_groups.html
[*] Writing computers to /opt/recon/ldd_out/domain_computers.html
[*] Writing trusts to /opt/recon/ldd_out/domain_trusts.html
[*] Dumping completed successfully!
```
*Analiz: Tüm etki alanı nesneleri çekilmiş ve HTML sayfaları hazır hale getirilmiştir. Operatör `firefox /opt/recon/ldd_out/domain_users.html` komutuyla grafik arayüzde aramaya başlayabilir.*

### Senaryo 2: Anonim / Null Session ile Dizin Dökümü Alma

Parola olmadan, boş kimlik bilgisiyle etki alanından veri çekme denemesi:

```bash
ldapdomaindump -u '' -p '' -o ./null_dump 10.10.10.10
```

### Senaryo 3: NetExec (nxc) ile ldapdomaindump Çalıştırma

NetExec'in dahili modülünü kullanarak tek bir satırda dizin dökümü tetikleme:

```bash
nxc ldap 10.10.10.10 -u ahmet -p 'Parola123!' -M ldapdomaindump
```

### Senaryo 4: Güvenli LDAPS (Port 636) Protokolü ile Şifreli Döküm

Ağ koklayıcılarından (network sniffers) korunmak amacıyla tüm sorguları TLS şifrelemesiyle yürütme:

```bash
ldapdomaindump -u "corp\ahmet" -p "Parola123!" -s -o /opt/recon/secure_dump dc01.corp.local
```

### Senaryo 5: Grep Dosyalarını Kullanarak Hızlı Komut Satırı Filtrelemesi

HTML açmadan terminal üzerinden Kerberoastable SPN'leri veya eski işletim sistemlerini saniyeler içinde bulma:

```bash
# 1. SPN kaydı olan (Kerberoastable) kullanıcıları bulma
cat domain_users.grep | grep -v "None" | awk -F'\t' '$10 != "" {print $1, $10}'

# 2. Açıklama satırında "pass" veya "parola" kelimesi geçen hesaplar
grep -iE "pass|parola|şifre" domain_users.grep

# 3. Windows Server 2008 veya Windows 7 çalıştıran zafiyetli makineler
grep -iE "Server 2008|Windows 7" domain_computers.grep | cut -f 1,4
```

### Senaryo 6: JSON Çıktısı Üzerinden jq ile Özel Sorgu

İndirilen `domain_users.json` dosyasından `adminCount=1` olan kullanıcıların listesini çekme:

```bash
cat domain_users.json | jq -r '.[] | select(.adminCount == "1") | .sAMAccountName'
```

### Senaryo 7: HTML Raporlarını Ekip İçi İnceleme İçin Web Sunucusu Olarak Yayınlama

Sızma testi ekibinin indirilen raporlara kendi tarayıcılarından kolayca erişebilmesi için yerel hafif bir Python HTTP sunucusu başlatma:

```bash
# 1. Çıktı klasörüne geçiş
cd /opt/recon/ldd_out

# 2. Yerel HTTP sunucusu başlatma
python3 -m http.server 8080 --bind 127.0.0.1
```
*Operatör `http://127.0.0.1:8080/domain_users.html` adresinden tüm kullanıcıları, grupları ve bilgisayarları tıkla-incele şeklinde hızlıca analiz edebilir.*

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAPSocketOpenError: unable to open socket` | Hedef IP'ye ulaşılamıyor, port 389 güvenlik duvarı tarafından engelli veya DC kapalı. | IP adresini kontrol edin. `nc -nvz <DC_IP> 389` ile port erişimini test edin. Gerekirse `-s` ile port 636 LDAPS deneyin. |
| `LDAPBindError: invalidCredentials` | Kullanıcı adı veya parola hatalı ya da etki alanı adı formatı yanlış girildi. | Kullanıcı adını `DOMAIN\user` veya `user@domain.local` şeklinde yazın. Özel karakter içeren parolaları tek tırnak (`'...'`) içine alın. |
| `UnicodeDecodeError: 'utf-8' codec can't decode byte...` | Active Directory'deki bazı kullanıcı veya grup açıklamalarında latin/türkçe karakter uyumsuzluğu var. | En güncel ldapdomaindump sürümünü kullanın (`pip install --upgrade ldapdomaindump`). Hata devam ederse `--no-html` kullanarak sadece JSON/grep formatında çekin. |
| `LDAPSessionTerminatedByServerError` | Çok büyük etki alanlarında DC'nin maksimum sayfa limiti (MaxPageSize) aşıldı. | Komuta spesifik arama kökü (`-b "OU=Users,DC=corp,DC=local"`) vererek sorguyu alt OU'lara bölün. |
| `SSL: CERTIFICATE_VERIFY_FAILED on -s (LDAPS)` | DC'nin ürettiği kendinden imzalı (self-signed) SSL sertifikası Python güven havuzunda bulunmuyor. | DC'nin FQDN adresiyle (`dc01.corp.local`) bağlanmayı deneyin veya standart port 389 üzerinden StartTLS (`-t`) kullanın. |
| `Empty files generated (0 bytes)` | Kimlik doğrulama başarılı oldu ancak kullanılan kullanıcının dizin nesnelerini okuma yetkisi kısıtlanmış. | Farklı bir geçerli etki alanı kullanıcısıyla kimlik doğrulayın veya `-b` bayrağı ile doğrudan etki alanı kökünü belirtin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

ldapdomaindump hafif ve hızlı bir araç olmasına karşın, **kısa sürede etki alanındaki tüm nesneleri indirdiği için** Etki Alanı Denetleyicisi seviyesinde net bir parmak izi bırakır.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4624 (Logon Type 3):**
   - Saldırgan makinesinden DC'nin LDAP/S servisine yapılan ağ oturumu kaydı.
2. **Directory Service Expensive Search Query (Event ID 1644):**
   - Active Directory Denetim Günlüklerinde, `(objectClass=user)` ve `(objectClass=computer)` gibi jenerik filtrelerle on binlerce nesnenin istenmesi "High Expensive Search" kaydı olarak loglanır.
3. **LDAP Paged Results Kontrolü (RFC 2696 OID):**
   - İstek paketlerinde `1.2.840.113556.1.4.319` OID'si barındıran sayfalama bayrakları ağ analiz araçları tarafından tespit edilebilir.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Ağ Hacmi:** Dakikalar içinde 10-50 MB arasında dizin nesnesi verisinin istemciye düz metin (plaintext) olarak akması.
- **İstemci Parmak İzi:** ldap3 kütüphanesinin varsayılan ASN.1 BER kodlama yapısı ve kimlik doğrulama paketleri.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | ldapdomaindump Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `domain_users` dökümü |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `domain_groups` dökümü |
| **T1018** | Remote System Discovery | `domain_computers` dökümü |
| **T1201** | Password Policy Discovery | `domain_policy` dökümü |
| **T1482** | Domain Trust Discovery | `domain_trusts` dökümü |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Düz Metin LDAP İzlemesi** | Port 389 trafiğinin IDS/NDR sistemleri tarafından okunması. | Daima `-s` (LDAPS) veya `-t` (StartTLS) kullanarak LDAP trafiğini SSL/TLS ile şifreleyin. |
| **Toplu Döküm Uyarısı** | Tüm nesnelerin tek hamlede çekilmesi. | Tüm etki alanını bir kerede indirmek yerine `ldeep` veya `ldapsearch` ile hedefli sorgular yapın. |
| **Çıktı Güvenliği** | İndirilen HTML/JSON dosyalarında yüzlerce açık metin kullanıcı bilgisinin bulunması. | Elde edilen dosyaları şifreli disk bölümlerinde (`/tmp` veya Veracrypt) saklayın; operasyon bitince temizleyin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

LDAP tabanlı toplu veri dökümünü tespit eden örnek kural mantığı:

```yaml
title: High Volume LDAP Search (LDAP Domain Dump)
id: f42a8b91-ldapdomaindump-detection
status: experimental
description: Detects massive LDAP queries enumerating all user, computer and group objects within a short time window.
logsource:
    product: windows
    service: directory_service
detection:
    selection:
        EventID: 1644
        SearchFilter|contains:
            - '(objectClass=user)'
            - '(objectClass=computer)'
            - '(objectClass=group)'
    condition: selection
level: medium
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Kullanıcı ile Tüm Dökümü Alma
ldapdomaindump -u "corp\user" -p "pass" -o /opt/recon/dump 10.10.10.10
```
- **Ne Yapar?** Kullanıcı, bilgisayar, grup, politika ve trust verilerini çeker ve HTML/JSON/grep formatında yazar.
- **Ne Zaman Kullanılır?** İlk etki alanı kimlik bilgisi elde edildiğinde anında çevrimdışı envanter oluşturmak için.
- **Parametreler:** `-u` kullanıcı adı; `-p` parola; `-o` çıktı klasörü.

```bash
# 2. Şifreli LDAPS (Port 636) ile Güvenli Döküm Alma
ldapdomaindump -u "corp\user" -p "pass" -s -o /opt/recon/secure_dump dc01.corp.local
```
- **Ne Yapar?** Sorguları TLS şifrelemesiyle yaparak ağ koklayıcılarından (network sniffers) gizler.
- **Ne Zaman Kullanılır?** Ağ üzerinde aktif IDS/NDR sensörlerinin bulunduğu ortamlarda.
- **Parametreler:** `-s` SSL/LDAPS protokolünü zorlar.

```bash
# 3. Anonim / Null Session ile Dizin Taraması
ldapdomaindump -u '' -p '' -o ./null_dump 10.10.10.10
```
- **Ne Yapar?** Parolasız olarak hedef DC'deki nesneleri okumaya çalışır.
- **Ne Zaman Kullanılır?** Ağda hiçbir kullanıcı hesabı bulunmadığında başlangıç noktası ararken.
- **Parametreler:** `-u '' -p ''` boş kimlik doğrulaması gönderir.

```bash
# 4. Yalnızca JSON Formatında Çıktı Üretme
ldapdomaindump -u "corp\user" -p "pass" --no-html --no-grep -o ./json_out 10.10.10.10
```
- **Ne Yapar?** HTML ve Grep dosyalarını atlayarak yalnızca script'lerle ayrıştırılabilir JSON üretir.
- **Ne Zaman Kullanılır?** Çıktıları otomatik analiz araçlarına beslerken disk alanı tasarrufu sağlamak için.
- **Parametreler:** `--no-html` ve `--no-grep` diğer formatları kapatır.

```bash
# 5. Belirli Bir Arama Kökü (Base DN) ile Hedefli Döküm
ldapdomaindump -u "corp\user" -p "pass" -b "OU=Finans,DC=corp,DC=local" -o ./finans 10.10.10.10
```
- **Ne Yapar?** Yalnızca belirtilen Organizasyonel Birim altındaki nesneleri çeker.
- **Ne Zaman Kullanılır?** Tüm etki alanını taramadan yalnızca belirli bir departmanı hedeflerken.
- **Parametreler:** `-b` arama kökü Distinguished Name (DN).

```bash
# 6. StartTLS (Port 389) ile Şifreleme Başlatma
ldapdomaindump -u "corp\user" -p "pass" -t -o ./starttls_dump 10.10.10.10
```
- **Ne Yapar?** Port 389 üzerinden başlayıp oturumu StartTLS ile şifreli tünele yükseltir.
- **Ne Zaman Kullanılır?** Port 636 kapalı fakat DC StartTLS destekliyorsa.
- **Parametreler:** `-t` StartTLS modunu açar.

```bash
# 7. Grup Odaklı Hiyerarşik JSON Dökümü
ldapdomaindump -u "corp\user" -p "pass" --grouped-json -o ./grouped 10.10.10.10
```
- **Ne Yapar?** Nesneleri düz liste yerine ait oldukları güvenlik grupları altında gruplandırarak JSON yapar.
- **Ne Zaman Kullanılır?** Yetki ağaçlarını ve grup üyelik hiyerarşisini programatik incelemek için.
- **Parametreler:** `--grouped-json` hiyerarşik JSON üretir.

```bash
# 8. Grep Dosyasından SPN Tanımlı Hesapları Çekme
grep -v "None" domain_users.grep | awk -F'\t' '$10 != "" {print $1, $10}'
```
- **Ne Yapar?** Döküm sonrası `domain_users.grep` dosyasındaki Kerberoastable SPN'leri tek satırda listeler.
- **Ne Zaman Kullanılır?** Döküm tamamlandıktan sonra anında parola kırma hedeflerini ayıklamak için.
- **Parametreler:** `awk -F'\t'` sekme ile ayrılmış sütunlardan SPN alanını (10. sütun) filtreler.

```bash
# 9. Açıkça NTLM Kimlik Doğrulama Türünü Zorlama
ldapdomaindump -u "corp\user" -p "pass" -at NTLM -o ./ntlm_dump 10.10.10.10
```
- **Ne Yapar?** Basit parola doğrulaması (SIMPLE) yerine Windows NTLM Challenge/Response mekanizmasını zorlar.
- **Ne Zaman Kullanılır?** DC basit kimlik doğrulamayı (Cleartext Bind) reddettiğinde.
- **Parametreler:** `-at NTLM` kimlik doğrulama tipini belirler.

```bash
# 10. NetExec Entegrasyonu ile Tek Satırda Döküm Alma
nxc ldap 10.10.10.10 -u user -p pass -M ldapdomaindump
```
- **Ne Yapar?** NetExec üzerinden arka planda ldapdomaindump modülünü çalıştırarak verileri yerel klasöre kaydeder.
- **Ne Zaman Kullanılır?** Zaten NetExec çalıştırılan bir senaryoda hızlıca ek araç kurmadan döküm almak için.
- **Parametreler:** `-M ldapdomaindump` dahili NetExec modülü.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [dirkjanm / ldapdomaindump](https://github.com/dirkjanm/ldapdomaindump)
- **Dirk-jan Mollema Blogu:** [dirkjanm.io Active Directory Research](https://dirkjanm.io/)
- **RFC 2696 (LDAP Paged Results):** [IETF RFC 2696 Specification](https://datatracker.ietf.org/doc/html/rfc2696)
- **MITRE ATT&CK Framework:** [Technique T1087 - Account Discovery](https://attack.mitre.org/techniques/T1087/)

---

> **Önceki:** [← linWinPwn](./linWinPwn.md) · **Sonraki:** [ldeep →](./ldeep.md)
