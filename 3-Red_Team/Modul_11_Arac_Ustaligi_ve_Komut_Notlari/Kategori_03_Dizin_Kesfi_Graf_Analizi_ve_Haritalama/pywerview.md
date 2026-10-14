# pywerview

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Yannick Méheut (@the-useless-one) tarafından geliştirilen; Impacket ve ldap3 kütüphaneleri üzerinden PowerView'ın temel keşif yeteneklerini Linux ortamına taşıyan, NTLM hash ve Kerberos biletleriyle (ccache) uzaktan etki alanı sorgulama imkanı sunan Python aracı.

---

## 1. Genel Bakış ve Amaç

**pywerview**, kırmızı takım operatörlerinin ve sızma testi uzmanlarının Windows işletim sistemine bağımlı kalmadan, doğrudan Linux (Kali, Parrot vb.) saldırı makineleri üzerinden Active Directory etki alanını sorgulamasını sağlayan açık kaynaklı bir Python kütüphanesidir. Will Schroeder'in ünlü `PowerView.ps1` betiğinin fonksiyonel yapısını örnek alan araç, arka planda **ldap3** ve **Impacket** kütüphanelerini kullanarak LDAP, SMB ve RPC protokolleri üzerinden hedef DC ve üye sunucularla haberleşir.

Aracın operasyonel sahadaki en büyük avantajı; hedef ağdaki herhangi bir Windows iş istasyonunda kod çalıştırmaya (ve dolayısıyla uç nokta EDR'larına, AMSI kontrollerine veya PowerShell Script Block loglarına yakalanmaya) gerek kalmadan, ele geçirilen kimlik bilgileriyle (parola, NTLM hash veya Kerberos `.ccache` bileti) uzaktan etki alanı keşfi icra edebilmesidir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                              PYWERVIEW ÇALIŞMA MİMARİSİ                           |
+-----------------------------------------------------------------------------------+
                                          |
                [Linux Saldırı İstasyonu / Kali / Docker]
                   pywerview <subcommand> [bayraklar]
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                          Kimlik Doğrulama Mekanizması                             |
|  - Açık Metin Parola (-u user -p pass)                                           |
|  - Pass-the-Hash (-H LM:NT / --hashes)                                            |
|  - Kerberos Bileti (-k -no-pass / KRB5CCNAME=.ccache)                             |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        pywerview Çekirdek Modülleri                               |
|   (Impacket SMB/RPC Entegrasyonu & Python ldap3 Asenkron İstemcisi)               |
+-----------------------------------------------------------------------------------+
        |                                 |                                 |
        v                                 v                                 v
   [LDAP / LDAPS]                  [SMB / NetAPI]                  [Kerberos / RPC]
   TCP 389 / 636                   TCP 445                         TCP 88 / 135
        |                                 |                                 |
        +---------------+                 |                 +---------------+
                        |                 |                 |
                        v                 v                 v
+-----------------------------------------------------------------------------------+
|                      Hedef Windows Active Directory Ağı                           |
|       - Domain Controller (Dizin Verisi, Nesneler, ACL'ler, GPO'lar)              |
|       - Domain Member Hosts (Aktif Oturumlar, Yerel Yönetici Kontrolleri)         |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Savunma Atlatma / OPSEC Boyutu |
|---|---|---|
| **Windows Bağımsızlığı** | Windows host üzerinde oturum açmadan Linux'tan doğrudan keşif. | Uç nokta EDR, AMSI, Sysmon ve PowerShell loglarını tamamen baypas eder. |
| **Pass-the-Hash Desteği** | Açık metin parola olmadan NTLM hash (`aad3b435...:nt_hash`) ile sorgulama. | Parola kırmaya gerek kalmadan anında dizin keşfi başlatır. |
| **Kerberos & ccache Uyumu** | Rubeus/Mimikatz ile çalınan Kerberos biletlerini Linux'ta kullanma. | Ağda NTLM trafiği oluşturmadan meşru Kerberos biletleriyle gizli hareket. |
| **Hedefli ve Hafif Sorgu** | BloodHound gibi tüm veritabanını indirmek yerine spesifik nesne sorgusu. | DC üzerindeki LDAP yükünü ve SIEM anomali alarmlarını minimize eder. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | pywerview | PowerView.ps1 | NetExec (nxc ldap) | ldapsearch | BloodHound.py |
|---|---|---|---|---|---|
| **Platform** | Linux / Python | Windows / PS | Linux / Python | Linux / C (OpenLDAP) | Linux / Python |
| **Sözdizimi Yapısı** | PowerView Benzeri | PowerShell Native | Modül / Bayrak Odaklı | Ham LDAP Sözdizimi | Toplu Veri Toplayıcı |
| **Pass-the-Hash** | Var (`-H`) | Yok (Mimikatz gerekir) | Var (`-H`) | Yok | Var (`--hashes`) |
| **Kerberos ccache** | Var (`-k`) | Var (Bellekten) | Var (`-k`) | Var (`-k`) | Var (`-k`) |
| **ACL & GPO Analizi**| Yüksek | Mükemmel | Orta | Düşük (Elle Çözümleme) | Mükemmel (Graf) |
| **Oturum Avcılığı** | Var (SMB/RPC) | Var (NetSessionEnum) | Kısmi | Yok | Var |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

pywerview alt komutlar (subcommands) mantığıyla çalışır. Genel CLI sözdizimi:

```bash
pywerview [subcommand] [bağlantı seçenekleri] [filtreler]
```

### 2.1 Desteklenen Temel Alt Komutlar (Subcommands)

| Alt Komut | PowerView Karşılığı | Açıklama |
|---|---|---|
| `get-netdomain` | `Get-Domain` | Etki alanının temel konfigürasyonunu ve SID değerini döker. |
| `get-netdomaincontroller` | `Get-DomainController` | Etki alanındaki tüm Etki Alanı Denetleyicilerini (DC) listeler. |
| `get-netuser` | `Get-DomainUser` | Kullanıcı hesaplarını, SPN'leri, pre-auth durumlarını sorgular. |
| `get-netcomputer` | `Get-DomainComputer` | Etki alanındaki bilgisayarları, OS sürümlerini ve IP'lerini döker. |
| `get-netgroup` | `Get-DomainGroup` | Güvenlik gruplarını ve grup tiplerini listeler. |
| `get-netgroupmember` | `Get-DomainGroupMember` | Belirli bir grubun doğrudan veya iç içe üyelerini döker. |
| `get-netgpo` | `Get-DomainGPO` | Grup İlkesi Nesnelerini (GPO) listeler. |
| `get-objectacl` | `Get-DomainObjectAcl` | Belirtilen nesnenin Güvenlik Tanımlayıcısını (DACL/ACE) çözümler. |
| `get-netsession` | `Get-NetSession` | Uzak bilgisayardaki aktif SMB oturumlarını listeler. |
| `get-netloggedon` | `Get-NetLoggedon` | Uzak sistemde oturum açmış kullanıcıları (Registry/RPC) döker. |
| `invoke-userhunter` | `Invoke-UserHunter` | Ağ genelinde oturum açmış Domain Admin'leri haritalandırır. |
| `find-localadminaccess` | `Find-LocalAdminAccess` | Verilen kimlik bilgisiyle lokal admin olunan host'ları bulur. |

### 2.2 Kimlik Doğrulama ve Bağlantı Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-u`, `--user` | Kimlik doğrulamada kullanılacak kullanıcı adı. | `-u "jdoe"` |
| `-p`, `--password` | İlgili kullanıcının açık metin parolası. | `-p "P@ssw0rd123"` |
| `-H`, `--hashes` | NTLM kimlik doğrulama hash'i (`LM:NT` veya `:NT`). | `-H ":e19ccf75ee54e06b06a53264f92fc504"` |
| `-d`, `--domain` | Hedef Active Directory etki alanı adı. | `-d "corp.local"` |
| `-t`, `--target` | Sorgulanacak hedef Etki Alanı Denetleyicisi IP'si veya FQDN'i. | `-t "10.10.10.10"` |
| `--dc-ip` | DNS çözülemediğinde kullanılacak Etki Alanı Denetleyicisi IP'si. | `--dc-ip "10.10.10.10"` |
| `-k`, `--kerberos` | NTLM yerine Kerberos kimlik doğrulaması kullanır. | `-k` |
| `--no-pass` | Parola girmeden `KRB5CCNAME` ortam değişkenindeki ccache biletini kullanır. | `--no-pass` |
| `--ssl` | LDAP yerine güvenli LDAPS (TCP 636) protokolünü zorlar. | `--ssl` |

### 2.3 Filtreleme ve Çıktı Seçenekleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-w`, `--spn` | Yalnızca Service Principal Name (SPN) kaydı olan hesapları getirir. | `-w` |
| `--preauth-not-required`| AS-REP Roasting için Kerberos pre-auth zorunluluğu olmayanları filtreler. | `--preauth-not-required` |
| `-s`, `--select` | Çıktıda yalnızca belirtilen öznitelikleri (virgülle ayrılmış) gösterir. | `-s "sAMAccountName,memberOf"` |
| `--raw-filter` | Doğrudan hedef DC'ye iletilecek sunucu taraflı özel LDAP filtresi. | `--raw-filter "(adminCount=1)"` |
| `-o`, `--output` | Çıktıyı dosyaya kaydeder. | `-o users.txt` |
| `--json` | Sonuçları otomatik işleme için JSON formatında üretir. | `--json` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Pass-the-Hash ile Linux'tan Kerberoastable SPN Hesaplarını Çekme

Açık metin parola olmadan, ele geçirilen NTLM hash ile SPN tanımlı kullanıcıları ve servis adlarını listeleme:

```bash
pywerview get-netuser \
  -u "ahmet" \
  -H ":8846f7eaee8fb117ad06bdd830b7586c" \
  -d "corp.local" \
  -t "10.10.10.10" \
  -w \
  -s "sAMAccountName,servicePrincipalName,memberOf"
```

**Konsol Çıktısı Analizi:**

```text
[*] Authenticating against 10.10.10.10 using NTLM hash...
[*] Successfully bound to LDAP server (ldap://10.10.10.10:389)
[*] Querying user objects with SPN configured...
======================================================================
sAMAccountName       : svc_sql_prod
servicePrincipalName : ['MSSQLSvc/db01.corp.local:1433', 'MSSQLSvc/db01.corp.local']
memberOf             : ['CN=SQL Admins,OU=Groups,DC=corp,DC=local']
----------------------------------------------------------------------
sAMAccountName       : svc_web_api
servicePrincipalName : ['HTTP/api.corp.local']
memberOf             : ['CN=Domain Users,CN=Users,DC=corp,DC=local']
======================================================================
[*] 2 user objects found.
```
*Analiz: `svc_sql_prod` hesabı yüksek yetkili SQL Admins grubundadır. Bu hesap için doğrudan Impacket'in `GetUserSPNs.py` aracıyla TGS bileti talep edilip çevrimdışı kırılabilir.*

### Senaryo 2: Kerberos ccache Biletiyle Parolasız Etki Alanı Yöneticilerini Listeleme

Önceden elde edilmiş bir TGT biletini (`KRB5CCNAME`) kullanarak NTLM trafiği oluşturmadan Domain Admins üyelerini sorgulama:

```bash
export KRB5CCNAME=/opt/tickets/administrator.ccache

pywerview get-netgroupmember \
  -k --no-pass \
  -d "corp.local" \
  -t "dc01.corp.local" \
  --group-name "Domain Admins"
```

### Senaryo 3: AS-REP Roasting için DONT_REQ_PREAUTH Hesapları Tespit Etme

Parola hash'i bilinmeyen ancak Kerberos ön kimlik doğrulaması kapatılmış kullanıcıları listeleme:

```bash
pywerview get-netuser \
  -u "ahmet" -p "Parola123!" \
  -d "corp.local" -t "10.10.10.10" \
  --preauth-not-required \
  -s "sAMAccountName,userAccountControl,description"
```

### Senaryo 4: Hedef Kullanıcı/Grup Üzerindeki ACL Haklarını Çözümleme

Bir kullanıcının başka bir nesne üzerinde `GenericAll` veya `WriteDacl` hakkı olup olmadığını tespit etme:

```bash
pywerview get-objectacl \
  -u "ahmet" -p "Parola123!" \
  -d "corp.local" -t "10.10.10.10" \
  --target-name "Domain Admins" \
  --resolve-guids
```

### Senaryo 5: Ağ Genelinde Aktif Oturum Avcılığı (User Hunting)

Etki alanı yöneticilerinin hangi makinelerde aktif oturumu olduğunu SMB/RPC oturumlarını tarayarak bulma:

```bash
pywerview invoke-userhunter \
  -u "ahmet" -p "Parola123!" \
  -d "corp.local" \
  --target-group "Domain Admins" \
  --threads 15
```

### Senaryo 6: JSON Çıktısı Alıp jq ile Filtreleme

Geniş etki alanı taramasında işletim sistemi Windows Server 2019 olan makineleri JSON formatında çekip `jq` ile ayrıştırma:

```bash
pywerview get-netcomputer \
  -u "ahmet" -p "Parola123!" \
  -d "corp.local" -t "10.10.10.10" \
  --json | jq -r '.[] | select(.operatingSystem | contains("2019")) | .dNSHostName'
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `ldap3.core.exceptions.LDAPSocketOpenError: unable to open socket` | İstemci makine DC'nin TCP 389 (veya 636) portuna erişemiyor veya yanlış IP/FQDN verildi. | DC IP adresini ping veya nc (`nc -nvz <DC_IP> 389`) ile doğrulayın. `--dc-ip` parametresiyle IP'yi elle girin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | `-k` bayrağı kullanıldığında DC için SPN kaydı çözülemedi (IP yerine FQDN kullanılmalı). | Komutta `-t` argümanına IP adresi yerine mutlaka DC'nin tam FQDN'ini (`dc01.corp.local`) verin ve `/etc/hosts` dosyasına DC IP-FQDN eşleştirmesini ekleyin. |
| `impacket.smbconnection.SessionError: STATUS_LOGON_FAILURE` | Kullanıcı adı, parola veya NTLM hash hatalı; hesap kilitli veya devre dışı. | Kimlik bilgilerini doğrulayın. NTLM hash kullanırken başında iki nokta olmasına dikkat edin (`:e19ccf...`). |
| `ssl.SSLError: [SSL: CERTIFICATE_VERIFY_FAILED]` | `--ssl` (LDAPS) kullanıldığında DC'nin sertifikası saldırgan makinenin CA havuzunda tanınmıyor. | Python ldap3 sertifika doğrulamasını atlamak için araca güvenilmeyen sertifikaları yoksayma bayrağı ekleyin veya standart port 389'a dönün. |
| `KeyError: 'userAccountControl'` veya şema çözümleme hatası | Hedef DC özel veya eski bir LDAP şemasına sahip, ilgili öznitelik nesnede tanımlı değil. | `-s` parametresiyle yalnızca varlığından emin olduğunuz temel öznitelikleri (`sAMAccountName,cn`) çağırın. |
| `impacket.smbconnection.SessionError: STATUS_ACCESS_DENIED in get-netsession` | Modern Windows sürümlerinde uzaktan `NetSessionEnum` RPC çağrısı standart kullanıcılara kısıtlıdır. | SMB oturum taraması yerine LDAP tabanlı `get-netuser` ve `get-objectacl` sorgularına odaklanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

pywerview Linux üzerinden çalıştığı için kurban Windows host'larında işlem (process) veya bellek (memory) izi bırakmaz. Ancak ağ ve etki alanı denetleyicisi seviyesinde tespit edilebilir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4624 (Logon Type 3 - Network):**
   - Linux makinesinden DC'ye yapılan her LDAP ve SMB bağlantısı Etki Alanı Denetleyicisi üzerinde Type 3 oturum kaydı oluşturur.
2. **Windows Security Event ID 4768 & 4769 (Kerberos TGT / TGS Requests):**
   - Kerberos kimlik doğrulaması (`-k`) kullanıldığında KDC üzerinde bilet talep logları oluşur.
3. **Directory Service Access (Event ID 4662 / LDAP 1644):**
   - Çok sayıda LDAP nesnesi hızlıca çekildiğinde DC üzerinde yüksek hacimli LDAP sorgu günlüğü tetiklenebilir.

### 5.2 Ağ ve EDR İmzaları

- **İstemci İşletim Sistemi İmzası:** LDAP Bind paketlerinde Linux tabanlı istemciler genellikle OS detayını göndermez ya da boş bırakır.
- **SMB Başlıkları:** Impacket kütüphanesinin varsayılan SMB istemci başlıkları (`SMB_COM_NEGOTIATE`) bazı gelişmiş NDR (Ağ Tespit ve Müdahale) sistemleri tarafından imzalanmıştır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | pywerview Karşılığı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `get-netuser`, `get-netuser -w`, `--preauth-not-required` |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `get-netgroup`, `get-netgroupmember` |
| **T1018** | Remote System Discovery | `get-netcomputer`, `find-localadminaccess` |
| **T1033** | System Owner/User Discovery | `get-netsession`, `get-netloggedon`, `invoke-userhunter` |
| **T1078.002** | Valid Accounts: Domain Accounts | Pass-the-Hash (`-H`) ve ccache (`-k`) ile kimlik doğrulama |
| **T1484.001** | Domain Policy Modification: Group Policy Modification | `get-netgpo` ile ilke nesnelerini analiz etme |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **Ağ Üzerinde NTLM Trafiği** | NTLM kimlik doğrulamasının SIEM ve IDS tarafından yakalanması. | Parola veya hash ile NTLM kullanmak yerine `-k` bayrağı ile Kerberos biletleri (`.ccache`) kullanın. |
| **Kitlesel LDAP Araması** | Tüm kullanıcıların (`objectClass=*`) tek sorguda istenmesi. | Sorgularınızı `--raw-filter` ile daraltın ve yalnızca kritik OU'ları veya grupları hedefleyin. |
| **RPC/SMB Oturum Avı Gürültüsü**| `invoke-userhunter` ile ağdaki tüm IP'lere 445 portundan sorgu yapılması. | Geniş çaplı oturum avcılığı yapmayın; hedef bilgisayarları önceden belirleyip sadece tekil `get-netsession` çağırın. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

Linux üzerinden gelen şüpheli LDAP ve Impacket trafiğini tespit eden örnek kural mantığı:

```yaml
title: Suspicious LDAP Query from Non-Domain Joined Host
id: e8a72b01-pywerview-ldap-recon
status: experimental
description: Detects rapid LDAP object enumeration originating from a non-domain joined IP address.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4624
        LogonType: 3
        WorkstationName: ''  # Non-domain joined or empty client name
    condition: selection
level: medium
```

Sertleştirme önerileri:
1. **LDAP Channel Binding ve Signing:** Etki alanı denetleyicilerinde LDAP imzalama zorunluluğu (`LDAPServerIntegrity = 2`) getirerek MitM ve sahte LDAP isteklerini engelleyin.
2. **NetSessionEnum Erişimini Sıkılaştırma:** Standart kullanıcıların diğer kullanıcıların SMB oturumlarını görmesini engelleyen kayıt defteri anahtarlarını dağıtın.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Kerberoasting Hedeflerini (SPN) NTLM Hash ile Listeleme
pywerview get-netuser -u "user" -H ":hash" -d "corp.local" -t "10.10.10.10" -w -s "sAMAccountName,servicePrincipalName"
```
- **Ne Yapar?** Servis hesabı parolalarını çevrimdışı kırmak için SPN tanımlı kullanıcıları listeler.
- **Ne Zaman Kullanılır?** Linux makinesinden açık metin parola olmadan Pass-the-Hash yaparken.
- **Parametreler:** `-w` SPN filtresi; `-H` NTLM hash; `-s` seçilen alanlar.

```bash
# 2. Kerberos Ön Kimlik Doğrulaması Kapatılmış (AS-REP Roastable) Hesapları Bulma
pywerview get-netuser -u "user" -p "pass" -d "corp.local" -t "10.10.10.10" --preauth-not-required
```
- **Ne Yapar?** Parola gerekmeden AS-REP bilet özeti talep edilebilecek hesapları tespit eder.
- **Ne Zaman Kullanılır?** İlk aşama parola kırma saldırısı için zafiyetli kullanıcı ararken.
- **Parametreler:** `--preauth-not-required` DONT_REQ_PREAUTH bayrağını sorgular.

```bash
# 3. Domain Admins Grubu Üyelerini Kerberos Biletiyle Listeleme
pywerview get-netgroupmember -k --no-pass -d "corp.local" -t "dc01.corp.local" --group-name "Domain Admins"
```
- **Ne Yapar?** KRB5CCNAME biletini kullanarak yüksek yetkili grubun üyelerini döker.
- **Ne Zaman Kullanılır?** NTLM trafiği oluşturmadan gizlice yönetici hesaplarını öğrenmek için.
- **Parametreler:** `-k` Kerberos modu; `--no-pass` bilet kullan; `--group-name` hedef grup.

```bash
# 4. Hedef Kullanıcı Üzerindeki ACL Haklarını Çözümleme
pywerview get-objectacl -u "user" -p "pass" -d "corp.local" -t "10.10.10.10" --target-name "da_mehmet" --resolve-guids
```
- **Ne Yapar?** Belirtilen kullanıcı üzerinde kimlerin `ResetPassword` veya `GenericAll` hakkı olduğunu gösterir.
- **Ne Zaman Kullanılır?** Yetki yükseltme ve hesap ele geçirme yollarını araştırırken.
- **Parametreler:** `--target-name` incelenen nesne; `--resolve-guids` hakları metne çevirir.

```bash
# 5. Etki Alanındaki Tüm Windows Server Sistemleri Listeleme
pywerview get-netcomputer -u "user" -p "pass" -d "corp.local" -t "10.10.10.10" --raw-filter "(operatingSystem=*Server*)" -s "dNSHostName,operatingSystem"
```
- **Ne Yapar?** Yalnızca sunucu işletim sistemine sahip bilgisayarları filtreleyerek getirir.
- **Ne Zaman Kullanılır?** İş istasyonlarını eleyip doğrudan kritik sunucu altyapısına odaklanırken.
- **Parametreler:** `--raw-filter` sunucu taraflı LDAP filtresi uygular.

```bash
# 6. Belirli Bir Uzak Sunucudaki SMB Oturumlarını Çekme
pywerview get-netsession -u "user" -p "pass" -d "corp.local" -t "filesvr01.corp.local"
```
- **Ne Yapar?** Hedef dosya sunucusuna bağlı olan aktif kullanıcı oturumlarını ve kaynak IP'leri döker.
- **Ne Zaman Kullanılır?** Kritik yöneticilerin hangi sistemlere bağlandığını tespit etmek için.
- **Parametreler:** `-t` sorgulanacak uzak üye sunucu FQDN'i.

```bash
# 7. Güvenli LDAPS (TCP 636) Protokolü ile Gizli Keşif
pywerview get-netdomain -u "user" -p "pass" -d "corp.local" -t "10.10.10.10" --ssl
```
- **Ne Yapar?** LDAP sorgularını TLS şifrelemesiyle yaparak ağ koklayıcılarından (sniffer) gizler.
- **Ne Zaman Kullanılır?** Ağ üzerinde IDS veya açık metin LDAP trafiğini izleyen sensörler varken.
- **Parametreler:** `--ssl` port 636 LDAPS şifrelemesini zorlar.

```bash
# 8. Otomasyon için JSON Çıktısı Alma
pywerview get-netuser -u "user" -p "pass" -d "corp.local" -t "10.10.10.10" --json -o users.json
```
- **Ne Yapar?** Kullanıcı listesini diğer script'ler ve analiz araçları için JSON formatında kaydeder.
- **Ne Zaman Kullanılır?** Keşif verilerini otomatik raporlama veya özel Python araçlarına aktarırken.
- **Parametreler:** `--json` JSON çıktısı üretir; `-o` dosya yolunu belirtir.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [the-useless-one / pywerview](https://github.com/the-useless-one/pywerview)
- **Impacket Kütüphanesi:** [SecureAuthCorp / Impacket](https://github.com/fortra/impacket)
- **Python ldap3 Dokümantasyonu:** [ldap3.readthedocs.io](https://ldap3.readthedocs.io/)
- **MITRE ATT&CK Bilgi Bankası:** [T1087 - Account Discovery](https://attack.mitre.org/techniques/T1087/)

---

> **Önceki:** [← SharpView](./SharpView.md) · **Sonraki:** [ADRecon →](./ADRecon.md)
