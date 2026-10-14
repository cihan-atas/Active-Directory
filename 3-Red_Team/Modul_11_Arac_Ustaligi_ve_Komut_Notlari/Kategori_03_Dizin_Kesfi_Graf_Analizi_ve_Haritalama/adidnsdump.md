# adidnsdump

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Dirk-jan Mollema (@_dirkjan) tarafından geliştirilen; DNS Bölge Transferi (AXFR) kapalı olsa dahi Active Directory ile Bütünleşik DNS (ADIDNS) bölgelerindeki tüm kayıtları doğrudan LDAP üzerinden sorgulayıp CSV formatında döken Python tabanlı keşif aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında standart DNS sunucuları genellikle Bölge Transferi (Zone Transfer - AXFR) isteklerine kapatılmıştır. Ancak etki alanına dahil edilen Etki Alanı ile Bütünleşik DNS (**ADIDNS - Active Directory Integrated DNS**) bölgelerinde tutulan DNS kayıtları, geleneksel metin dosyaları yerine doğrudan Active Directory veritabanı (NTDS.dit) içerisindeki özel uygulama dizini bölümlerinde (**Application Directory Partitions**) birer LDAP nesnesi (`dnsNode`) olarak saklanır.

Standart bir etki alanı kullanıcısı, bu uygulama dizini bölümleri (`DC=DomainDnsZones` ve `DC=ForestDnsZones`) üzerinde varsayılan olarak **okuma (Read) hakkına** sahiptir. **adidnsdump**, bu mimari yapılandırmayı suistimal ederek AXFR izinlerine gerek kalmadan, yalnızca standart bir kullanıcının LDAP oturumuyla tüm kurumsal iç ağın IP ve DNS haritasını (sunucular, veritabanları, ESXi ana makineleri, VPN ağ geçitleri, test ortamları vb.) saniyeler içinde çeker.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            ADIDNSDUMP ÇALIŞMA MİMARİSİ                            |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Kali Linux / Sızma Testçisi]
                       adidnsdump -u user -p pass [seçenekler] <DC_IP>
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kimlik Doğrulama Mekanizması                               |
|        - Açık Metin Parola (-p)                                                   |
|        - NTLM Hash / Pass-the-Hash (-H)                                           |
|        - Kerberos Bileti / ccache (-k --no-pass)                                  |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        LDAP / LDAPS İletişimi (TCP 389 / 636)                     |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                       Active Directory Uygulama Bölümleri                         |
|   1. DC=DomainDnsZones,DC=corp,DC=local  (Etki Alanı Seviyesi Bölgeler)           |
|   2. DC=ForestDnsZones,DC=corp,DC=local  (Orman Seviyesi Global Bölgeler)         |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        dnsNode Nesneleri & dnsRecord İkili Blobu                  |
|   (A, AAAA, CNAME, PTR, SRV, TXT ve Silinmiş / Tombstoned Kayıtlar)               |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                          Ayrıştırılmış CSV Çıktısı                                |
|        records.csv (IP Adresleri, Host Adları, Kayıt Türleri, Durumlar)           |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi Avantajı |
|---|---|---|
| **AXFR Korumasını Aşma** | DNS port 53 yerine LDAP (389) üzerinden bölgeyi boşaltır. | AXFR kısıtlamalarını tamamen baypas eder; tüm iç ağ envanterini açığa çıkarır. |
| **Sıfır Ayrıcalık Gereksinimi**| En düşük yetkili etki alanı kullanıcısıyla çalışır. | İlk erişim (Initial Access) sonrası anında tüm ağ topolojisini haritalar. |
| **Tombstoned Kayıt Tespiti**| Silinmiş ancak henüz temizlenmemiş DNS kayıtlarını döker. | Sahipsiz kalan host adlarını tespit edip DNS Zehirleme / Takeover yapma olanağı. |
| **CSV Çıktı Standardı** | Sonuçları `records.csv` olarak formatlar. | `grep`, `awk` veya Excel ile kritik sunucuları (vcenter, backup vb.) saniyeler içinde filtreleme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | adidnsdump | dig / nslookup (AXFR) | nmap dns-brute | dnstool.py | ldapsearch |
|---|---|---|---|---|---|
| **Kullanılan Protokol** | LDAP / LDAPS | DNS (TCP 53) | DNS (UDP 53) | LDAP (Yazma Odaklı) | Ham LDAP |
| **AXFR Zorunluluğu** | **Yok** | **Var (Şarttır)** | Yok (Kaba Kuvvet) | Yok | Yok |
| **Kayıt Kapsamı** | Tüm Kayıtlar (%100) | Varsa Tamamı | Yalnızca Wordlist | Tekil Nesne | Ham Binary |
| **Tombstoned Desteği**| **Var (`-t`)** | Yok | Yok | Yok | Ham Filtre |
| **Gürültü Seviyesi** | Düşük (Tekil LDAP) | Çok Düşük | Çok Yüksek (Brute) | Düşük | Düşük |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

adidnsdump doğrudan komut satırından parametreler ve hedef DC adresi verilerek çalıştırılır:

```bash
adidnsdump [seçenekler] [hedef_dc_adresi]
```

### 2.1 Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Kısa Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|---|
| `--user` | `-u` | Kimlik doğrulamada kullanılacak kullanıcı adı (`DOMAIN\user`). | `-u "corp.local\ahmet"` |
| `--password` | `-p` | İlgili kullanıcının açık metin parolası. | `-p "Parola123!"` |
| `--hashes` | `-H` | NTLM kimlik doğrulama hash'i (`LM:NT` veya `:NT`). | `-H ":8846f7eaee..."` |
| `--kerberos` | `-k` | NTLM yerine Kerberos kimlik doğrulaması kullanma. | `-k` |
| `--no-pass` | | Parola sormadan `KRB5CCNAME` biletini kullanır. | `--no-pass` |
| `--ssl` | | LDAP yerine şifreli LDAPS (TCP 636) bağlantısını zorlar. | `--ssl` |

### 2.2 Bölge ve Filtreleme Parametreleri

| Parametre | Kısa Bayrak | Açıklama |
|---|---|---|
| `--zone` | `-z` | Yalnızca belirtilen DNS bölgesini döker (Varsayılan: mevcut etki alanı). |
| `--print-zones` | | Mevcut tüm ADIDNS bölgelerini listeler ancak döküm yapmaz. |
| `--forest` | | `DomainDnsZones` yerine `ForestDnsZones` bölümünü sorgular. |
| `--legacy` | | `CN=MicrosoftDNS,CN=System` altındaki eski tip bölgeleri sorgular. |
| `--include-tombstoned`| `-t` | Silinmiş/bayat (tombstoned) kayıtları da CSV çıktısına dahil eder. |
| `--resolve-hostnames` | `-r` | Dökülen host adlarını işletim sistemi DNS çözümleyicisiyle doğrular. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı ile Tüm İç Ağ DNS Kayıtlarını Çekme

Geçerli bir etki alanı kullanıcısıyla tüm iç ağ DNS tablosunu yerel dizine `records.csv` olarak dökme:

```bash
adidnsdump -u "corp.local\ahmet" -p "Parola123!" 10.10.10.10
```

**Konsol Çıktısı Analizi:**

```text
[*] Connecting to host...
[*] Binding to host...
[+] Bind OK
[*] Querying zone for records
[+] Found 1,842 records in zone corp.local
[*] Written 1,842 records to records.csv
```
*Analiz: 10.10.10.10 DC sunucusundaki AXFR korumasına takılmadan, `records.csv` dosyasına 1,842 adet iç ağ ana makinesinin adı ve statik IP adresi yazılmıştır.*

### Senaryo 2: Orman Düzeyindeki (ForestDnsZones) Kayıtları Çekme

Tüm orman genelinde paylaşılan global servis kayıtlarını (`_msdcs` bölgeleri dahil) dökme:

```bash
adidnsdump -u "corp\ahmet" -p "Parola123!" --forest 10.10.10.10
```

### Senaryo 3: Silinmiş ve Sahipsiz (Tombstoned) Kayıtları Tespit Etme

DNS devralma (Subdomain Takeover / DNS Hijacking) fırsatlarını yakalamak için silinmiş kayıtları da listeleme:

```bash
adidnsdump -u "corp\ahmet" -p "Parola123!" -t -z "corp.local" 10.10.10.10
```

**Konsol Çıktısı:**

```text
[+] Found record: dev-portal.corp.local (Type: A, IP: 192.168.1.185) [TOMBSTONED]
[+] Found record: old-sharepoint.corp.local (Type: CNAME, Target: sp.corp.local) [TOMBSTONED]
```
*Analiz: `dev-portal.corp.local` kaydı silinmiş durumdadır. Standart bir kullanıcı `dnstool.py` ile bu kaydı kendi kontrolündeki bir IP'ye yeniden kaydederek (Dynamic DNS) ağ trafiğini zehirleyebilir.*

### Senaryo 4: Mevcut Tüm ADIDNS Bölgelerini Listeleme

Etki alanında barındırılan tüm birincil, ikincil ve ters (reverse) arama bölgelerini görme:

```bash
adidnsdump -u "corp\ahmet" -p "Parola123!" --print-zones 10.10.10.10
```

### Senaryo 5: Pass-the-Hash ile Şifreli LDAPS Üzerinden Döküm Alma

Açık metin parola olmadan NTLM hash ile TLS şifreli kanaldan DNS dökümü alma:

```bash
adidnsdump -u "corp\mehmet" -H ":8846f7eaee8fb117ad06bdd830b7586c" --ssl dc01.corp.local
```

### Senaryo 6: CSV Çıktısını Ayrıştırıp Kritik Sistemleri Filtreleme

Dökülen `records.csv` dosyasından yüksek değerli hedefleri (Yönetim, Sanallaştırma, Yedekleme) ayıklama:

```bash
# 1. VMware, ESXi ve vCenter sunucularını bulma
grep -iE "vcenter|esx|vsphere" records.csv

# 2. Yedekleme ve Depolama altyapısını listeleme
grep -iE "backup|veeam|nas|san|storage" records.csv

# 3. Yalnızca IP adreslerini ve FQDN'leri temiz liste yapma
cut -d',' -f1,3 records.csv | grep -v "NodeName" | sort -u
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAPBindError: invalidCredentials` | Kullanıcı adı veya parola hatalı ya da hesap etki alanında kilitlenmiş. | Kimlik bilgilerini doğrulayın. Kullanıcı adını `DOMAIN\user` veya `user@domain.local` formatında yazın. |
| `[!] No zones found in DomainDnsZones` | ADIDNS `DomainDnsZones` bölümü henüz bu DC'ye replike olmamış veya bölge eski tip (`--legacy`) alanda tutuluyor. | Komuta `--legacy` veya `--forest` bayrağını ekleyerek farklı bölümleri tarayın ya da diğer bir DC'yi hedefleyin. |
| `TypeError: 'NoneType' object is not subscriptable (in dnsRecord parsing)` | DNS bölgesinde üçüncü taraf yazılımlar tarafından yazılmış bozuk veya standart dışı bir DNS kayıt tipi var. | En güncel adidnsdump sürümünü kullanın (`pip install --upgrade adidnsdump`). Sorunlu kaydı atlamak için `-z` ile spesifik alt bölgeleri hedefleyin. |
| `SSL: CERTIFICATE_VERIFY_FAILED on --ssl` | DC'nin ürettiği sertifika istemcinin yerel CA havuzunda tanınmıyor. | DC FQDN adresiyle (`dc01.corp.local`) bağlanmayı deneyin veya port 389 standart LDAP'a dönün. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | `-k` kullanılırken hedef olarak IP adresi girildi. | Kerberos biletleri IP üzerinden çalışmaz; hedef olarak mutlaka DC'nin tam FQDN adını belirtin. |
| `Permission Denied on records.csv` | Çalıştırılan dizinde yazma izni yok veya `records.csv` dosyası başka bir program tarafından kilitlenmiş. | Farklı bir çalışma dizinine geçin (`cd /tmp`) veya komutu oradan yürütün. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

adidnsdump, **geleneksel DNS sunucu loglarına (DNS Debug Logs) veya AXFR alarmlarına yakalanmaz**, çünkü DNS port 53'ü değil doğrudan LDAP port 389'u kullanır.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4624 (Logon Type 3):**
   - Saldırganın IP adresinden DC'nin LDAP servisine açılan oturum kaydı.
2. **Directory Service Access (Event ID 4662 / LDAP 1644):**
   - `CN=MicrosoftDNS,DC=DomainDnsZones...` kapsayıcısı altında binlerce `dnsNode` nesnesinin hızlıca taranması (`(objectClass=dnsNode)` filtresi).
3. **DNS Query Loglarında İz Bırakmaz:**
   - Normal şartlarda port 53 üzerinden yapılan zone transfer denemeleri SIEM'e "Unauthorized Zone Transfer Attempt" alarmı düşürürken; adidnsdump bu logların hiçbirini üretmez!

### 5.2 Ağ ve EDR İmzaları

- **LDAP Ağ Hacmi:** Binlerce DNS kaydının LDAP yanıtları (SearchResEntry) halinde tek bir TCP oturumundan akması.
- **İstemci Parmak İzi:** ldap3 kütüphanesinin varsayılan ASN.1 veri paketleri.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | adidnsdump Karşılığı |
|---|---|---|
| **T1018** | Remote System Discovery | İç ağdaki tüm sunucu ve makinelerin DNS'ten keşfi |
| **T1046** | Network Service Discovery | IP ve host adı eşleştirmelerinin çıkarılması |
| **T1087.002** | Account Discovery: Domain Account | LDAP üzerinden yetkili oturumla dizin sorgulama |
| **T1584.004** | Compromise Infrastructure: DNS Server | Tombstoned kayıtların tespit edilip zehirlenmeye hazırlanması |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Düz Metin LDAP İzlemesi** | Port 389 trafiğinin NDR/IDS sensörleri tarafından incelenmesi. | Daima `--ssl` bayrağını kullanarak LDAP trafiğini TLS tüneline alın. |
| **Toplu `dnsNode` Taraması** | Tek hamlede tüm DNS ağacının istenmesi. | Tüm bölgeyi tek seferde çekmek yerine yalnızca ilgilendiğiniz alt bölgeyi (`-z sub.corp.local`) isteyin. |
| **CSV Dosya İzi** | Disk üzerinde `records.csv` dosyasının açık metin bırakılması. | Dosyayı şifreli RAM disk (`/dev/shm`) üzerinde oluşturun ve operasyon bittiğinde güvenli silin (`shred -u`). |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

LDAP tabanlı DNS dökümü aktivitelerini tespit eden örnek kural mantığı:

```yaml
title: Active Directory Integrated DNS (ADIDNS) Dump via LDAP
id: b9281a44-adidnsdump-detection
status: experimental
description: Detects LDAP queries querying the dnsNode class within DomainDnsZones or ForestDnsZones partitions.
logsource:
    product: windows
    service: directory_service
detection:
    selection:
        EventID: 1644
        SearchFilter|contains:
            - '(objectClass=dnsNode)'
            - '(objectCategory=dnsNode)'
    condition: selection
level: medium
```

Sertleştirme önlemleri:
1. **DACL Sıkılaştırması:** `CN=MicrosoftDNS,DC=DomainDnsZones...` kapsayıcısının izinlerini inceleyerek standart etki alanı kullanıcılarının okuma yetkisini yalnızca gerekli OU'larla sınırlandırın.
2. **DNS Scavenging:** Silinmiş (tombstoned) kayıtların ağda birikmesini önlemek için DNS Scavenging periyodunu kısaltın.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Kullanıcı ile Tüm DNS Kayıtlarını CSV'ye Dökme
adidnsdump -u "corp\user" -p "pass" 10.10.10.10
```
- **Ne Yapar?** Etki alanı DNS bölgesindeki tüm A, CNAME, SRV kayıtlarını çeker ve `records.csv` olarak yazar.
- **Ne Zaman Kullanılır?** İlk erişim sonrası iç ağ topolojisini çıkarmak için.
- **Parametreler:** `-u` kullanıcı adı; `-p` parola; hedef DC IP'si.

```bash
# 2. Şifreli LDAPS (Port 636) ile Güvenli Döküm Alma
adidnsdump -u "corp\user" -p "pass" --ssl dc01.corp.local
```
- **Ne Yapar?** Sorguları TLS ile şifreleyerek ağ dinleyicilerinden gizler.
- **Ne Zaman Kullanılır?** Ağ üzerinde aktif IDS/NDR sensörleri varken.
- **Parametreler:** `--ssl` port 636 bağlantısını zorlar.

```bash
# 3. Silinmiş (Tombstoned) Kayıtları da Dahil Ederek Dökme
adidnsdump -u "corp\user" -p "pass" -t 10.10.10.10
```
- **Ne Yapar?** Silinmiş ancak scavenging yapılmamış eski DNS kayıtlarını da listeler.
- **Ne Zaman Kullanılır?** DNS hijacking / devralma zafiyetlerini ararken.
- **Parametreler:** `-t` veya `--include-tombstoned` bayrağı.

```bash
# 4. Orman Düzeyindeki (ForestDnsZones) Global Kayıtları Çekme
adidnsdump -u "corp\user" -p "pass" --forest 10.10.10.10
```
- **Ne Yapar?** Tüm orman çapında geçerli global DNS kayıtlarını (`_msdcs` vb.) döker.
- **Ne Zaman Kullanılır?** Orman kök etki alanı ve global servis altyapısını analiz ederken.
- **Parametreler:** `--forest` orman bölümünü hedefler.

```bash
# 5. Mevcut Tüm ADIDNS Bölgelerini Listeleme (Döküm Yapmadan)
adidnsdump -u "corp\user" -p "pass" --print-zones 10.10.10.10
```
- **Ne Yapar?** Dizin üzerinde kayıtlı tüm birincil ve ters DNS bölgelerini listeler.
- **Ne Zaman Kullanılır?** Hangi alt etki alanlarının veya IP subnet'lerinin mevcut olduğunu anlamak için.
- **Parametreler:** `--print-zones` salt bölge listeleme modu.

```bash
# 6. Belirli Bir Alt Bölgeyi (Sub-Zone) Hedefleyerek Döküm Alma
adidnsdump -u "corp\user" -p "pass" -z "dev.corp.local" 10.10.10.10
```
- **Ne Yapar?** Yalnızca belirtilen alt DNS bölgesini sorgular.
- **Ne Zaman Kullanılır?** Tüm şirketi taramadan yalnızca belirli bir geliştirme veya sunucu bloğuna odaklanırken.
- **Parametreler:** `-z` hedef DNS bölgesi adı.

```bash
# 7. Pass-the-Hash ile NTLM Hash Kullanarak Döküm Alma
adidnsdump -u "corp\user" -H ":e19ccf..." 10.10.10.10
```
- **Ne Yapar?** Parola gerekmeden NTLM hash ile kimlik doğrulayıp DNS dökümü alır.
- **Ne Zaman Kullanılır?** Açık metin parola olmadan Pass-the-Hash yaparken.
- **Parametreler:** `-H` NTLM hash'i.

```bash
# 8. Kerberos ccache Biletiyle Parolasız Çalıştırma
export KRB5CCNAME=/opt/tickets/admin.ccache
adidnsdump -k --no-pass dc01.corp.local
```
- **Ne Yapar?** NTLM trafiği oluşturmadan mevcut Kerberos oturumu üzerinden DNS tablosunu çeker.
- **Ne Zaman Kullanılır?** NTLM kimlik doğrulamasının engellendiği veya izlendiği ortamlarda.
- **Parametreler:** `-k` Kerberos modu; `--no-pass` bilet kullan; hedef FQDN adresi.

```bash
# 9. Eski Tip (Legacy) DNS Bölümlerini Sorgulama
adidnsdump -u "corp\user" -p "pass" --legacy 10.10.10.10
```
- **Ne Yapar?** `CN=MicrosoftDNS,CN=System` altında saklanan eski Windows Server 2000/2003 bölgelerini arar.
- **Ne Zaman Kullanılır?** Modern `DomainDnsZones` bölümünde kayıt bulunamadığında.
- **Parametreler:** `--legacy` eski sistem kapsayıcısını sorgular.

```bash
# 10. Dökülen Host Adlarını Otomatik DNS Çözümlemesiyle Doğrulama
adidnsdump -u "corp\user" -p "pass" -r 10.10.10.10
```
- **Ne Yapar?** Dökülen kayıtların canlı olup olmadığını yerel DNS üzerinden `gethostbyname` ile test eder.
- **Ne Zaman Kullanılır?** Aktif ve yanıt veren host'ları ölü kayıtlardan ayıklamak için.
- **Parametreler:** `-r` veya `--resolve-hostnames` çözümleme bayrağı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [dirkjanm / adidnsdump](https://github.com/dirkjanm/adidnsdump)
- **Dirk-jan Mollema Araştırma Makalesi:** [Getting the full picture of an AD network through ADIDNS](https://dirkjanm.io/getting-in-the-zone-dumping-active-directory-dns-using-ldap/)
- **Microsoft ADIDNS Mimarisi:** [Understanding Active Directory-Integrated DNS](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/active-directory-integrated-dns-zones)
- **MITRE ATT&CK Framework:** [Technique T1018 - Remote System Discovery](https://attack.mitre.org/techniques/T1018/)

---

> **Önceki:** [← AdMod.exe](./AdMod.md) · **Sonraki:** [dnstool.py →](./dnstool.md)
