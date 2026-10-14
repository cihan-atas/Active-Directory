# restorepassword.py

> **Kategori:** [13. Tarihi ve Kritik Zafiyet Araçları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Zerologon (CVE-2020-1472) istismarı sonrasında sıfırlanan etki alanı denetleyicisi makine hesabı (`DC$`) parolasını, yerel SAM kovanındaki orijinal değerine geri yükleyerek Active Directory replikasyonunu ve güvenli kanalı onaran kurtarma aracı.

---

## 1. Genel Bakış ve Amaç

Zerologon (CVE-2020-1472) istismarı, Netlogon protokolündeki kriptografik zafiyeti kullanarak etki alanı denetleyicisinin bilgisayar hesabı (`DC$`) parolasını Active Directory veritabanında (`NTDS.dit`) boş bir dizeye (`""`) sıfırlar. Bu işlem saldırganın DCSync ile tüm etki alanı parola özetlerini çekmesini sağlasa da, Active Directory mimarisi açısından son derece tehlikeli ve yıkıcı bir yan etki üretir:

Windows Server işletim sisteminde etki alanı denetleyicisinin makine parolası iki farklı konumda tutulur:
1. **Active Directory Veritabanı (`NTDS.dit`):** Etki alanındaki diğer tüm sunucu ve denetleyicilerin referans aldığı merkezi nesne özniteliği (`unicodePwd`).
2. **Yerel Kayıt Defteri Kovanı (`HKLM\SAM` ve LSA Sırları):** İşletim sisteminin yerel diskinde saklanan ve sunucunun kendi kimliğini doğrulamak için kullandığı `$MACHINE.ACC` parolası.

Zerologon istismar betiği yalnızca Active Directory nesnesindeki parolayı sıfırlar; yerel `SAM` kovanındaki parolaya dokunmaz. Bu durum ortaya bir **parola desenkronizasyonu (desynchronization)** çıkarır:
* DC kendi yerel parolasının eski hash olduğunu düşünür.
* Active Directory ise parolanın boş olduğunu kabul eder.

Bu tutarsızlık nedeniyle etki alanı denetleyicisi kendi güvenli kanalını (Secure Channel) kaybeder; diğer etki alanı denetleyicileriyle çoğaltma (Replication) yapamaz, Kerberos anahtar dağıtım servisi (KDC) bilet üretirken hatalar verir ve ortamda ciddi hizmet kesintileri (Denial of Service) meydana gelir.

**restorepassword.py** (Dirk-jan Mollema / @dirkjanm tarafından geliştirilmiştir), bu kritik durumu düzeltmek amacıyla yazılmış zorunlu bir kurtarma aracıdır. Araç, etki alanı denetleyicisine boş parola ile Netlogon RPC üzerinden bağlanır ve yerel SAM kovanından çıkarılan orijinal `$MACHINE.ACC` hex dizesini `NetrServerPasswordSet2` çağrısıyla Active Directory'ye yeniden yazar. Böylece AD ve SAM arasındaki parola uyumu sağlanır, güvenli kanal onarılır ve replikasyon normale döner.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                        RESTOREPASSWORD.PY MIMARI AKIŞI                            |
+-----------------------------------------------------------------------------------+
  [Denetçi / Operatör]                               [Domain Controller (DC)]
 (restorepassword.py)                                   (Netlogon & SAM Hive)
           |                                                      |
           |--- 1. secretsdump ile SAM Kovanından --------------->|
           |       Orijinal $MACHINE.ACC Hash'i Alınır            |
           |<-- 2. Orijinal Hex Hash Döner (Örn: a9128f44...) ---|
           |                                                      |
           |--- 3. RPC Bağlantısı Açılır (MS-NRPC) -------------->|
           |       [Kimlik: DC01$ / Parola: Boş (Empty)]          |--- 4. AD'deki Boş Parola
           |<-- 4. Netlogon Oturumu Doğrulanır -------------------|       ile Oturum Açılır
           |                                                      |
           |--- 5. NetrServerPasswordSet2 Çağrısı --------------->|--- 5. Orijinal Hash
           |       [NewPassword: a9128f441029384756102938...]     |       AD Nesnesine Yazılır
           |<-- 6. STATUS_SUCCESS (0x00000000) -------------------|
           |                                                      |
           v                                                      v
  [AD ve SAM Parolaları Tekrar Eşitlendi] -> [Replikasyon ve Güvenli Kanal Onarıldı!]
```

### Neden Önemli?

| Yetenek | Operasyonel Avantaj | Alternatif Onarım Yollarına Üstünlüğü |
| :--- | :--- | :--- |
| **Hizmet Kesintisini Önler** | Bozuk AD replikasyonunu dakikalar içinde düzeltir. | DC'nin ağdan düşmesini ve domain çökmesini engeller. |
| **Uzaktan RPC Onarımı** | Linux üzerinden uzaktan parametreyle çalışır. | DC'ye RDP yapma veya sunucuyu yeniden başlatma gereğini kaldırır. |
| **Orijinal SAM Değeri** | Parolayı rastgele değil, yerel SAM kovanındaki orijinal değerine eşitler. | Sunucu üzerinde ek konfigürasyon değişikliği gerektirmez. |
| **Adli İz Azaltma** | Desenkronizasyon hatalarını (Event 5805/5723) sonlandırır. | Mavi takım loglarında devam eden sürekli gürültüyü keser. |
| **Impacket Entegrasyonu**| Standart Impacket kimlik doğrulama modelleriyle uyumludur. | Ekstra bağımlılık gerektirmeden sızma testi cephaneliğine oturur. |

### Karşılaştırma Tablosu

| Özellik | restorepassword.py | netdom resetpwd (Yerleşik) | Reset-ComputerMachinePassword |
| :--- | :--- | :--- | :--- |
| **Çalıştırma Ortamı** | Linux / Windows (Python) | DC Yerel Konsolu (Windows) | DC Yerel PowerShell |
| **Gereken Girdi** | SAM'den çıkarılan Hex Hash | Domain Admin Parolası | Domain Admin Yetki Belirteci |
| **Yöntem** | Netlogon RPC ile AD'ye yazma | Netlogon servisine şifre sıfırlatma | Win32 API ile yeni şifre atama |
| **Ağ Üzerinden Uzaktan** | Evet (Hedef IP ile) | Hayır (Yerel komut) | Hayır (PowerShell Remoting gerekir) |
| **Replikasyon Kurtarma Hızı**| Anında (Milisaniyeler) | Birkaç dakika sürer | Birkaç dakika sürer |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`restorepassword.py`, hedef etki alanı/makine tanımlayıcısı, hedef IP ve SAM'den elde edilen orijinal hex parola parametreleriyle çalıştırılır:

```bash
python3 restorepassword.py <DOMAIN>/<DC_ADI>@<DC_FQDN> -target-ip <DC_IP> -hexpass <ORIJINAL_HEX_HASH>
```

### Desteklenen Kritik Bayraklar

| Parametre | Zorunluluk | Açıklama | Örnek Değer |
| :--- | :--- | :--- | :--- |
| `<DOMAIN>/<DC_ADI>@<DC_FQDN>`| Zorunlu | Hedef DC makine hesabı ve etki alanı yolu (`$` işareti olmadan verilir). | `CORP.LOCAL/DC01@dc01.corp.local` |
| `-target-ip` | Zorunlu | Hedef etki alanı denetleyicisinin IPv4 adresi. | `-target-ip 192.168.1.10` |
| `-hexpass` | Zorunlu | SAM kovanından çıkarılan `$MACHINE.ACC` orijinal NT hash değeri (Hex dize). | `-hexpass a9128f44102938475610293847561029` |
| `-debug` | Opsiyonel | RPC paket trafiğini ve Netlogon hata kodlarını ayrıntılı listeler. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Hex Hash ile Parola Geri Yükleme
Zerologon istismarı ve DCSync sonrasında, SAM kovanından alınan hash ile DC makine parolasını onarma:

```bash
python3 restorepassword.py CORP.LOCAL/DC01@dc01.corp.local -target-ip 192.168.1.10 -hexpass a9128f44102938475610293847561029
```

**Konsol Çıktı Analizi:**
```
[*] Connecting to Netlogon RPC on 192.168.1.10...
[*] Authenticating as CORP.LOCAL\DC01$ with empty password...
[+] Successfully authenticated to Netlogon service!
[*] Setting machine account password to original hex value: a9128f44102938475610293847561029...
[+] Password successfully restored!
[+] Active Directory database and local SAM are now synchronized.
```

### Senaryo 2: secretsdump ile SAM Kovanından $MACHINE.ACC Çıkarma
Geri yükleme için gereken orijinal hash'i elde etmek amacıyla Administrator haklarıyla DC'nin yerel SAM kovanını dökme:

```bash
impacket-secretsdump -hashes :329153f560eb344c3f9e3ec4e086166f 'CORP.LOCAL/Administrator@192.168.1.10'
```

**Konsol Çıktı Analizi:**
```
[*] Service RemoteRegistry is in stopped state
[*] Starting service RemoteRegistry
[*] Target system bootKey: 0x8a92...
[*] Dumping local SAM hashes...
Administrator:500:aad3b435b51404eeaad3b435b51404ee:329153f560eb344c3f9e3ec4e086166f:::
$MACHINE.ACC:aad3b435b51404eeaad3b435b51404ee:a9128f44102938475610293847561029:::  <-- BU DEĞER KOPYALANIR
[*] Cleaning up...
```

### Senaryo 3: Geri Yükleme Sonrası Güvenli Kanal Doğrulaması
Parola onarımının başarılı olduğunu ve güvenli kanalın kurulduğunu DC konsolundan `nltest` ile teyit etme:

```cmd
nltest /sc_query:corp.local
```

**Konsol Çıktı Analizi:**
```
Flags: 30 HAS_IP  HAS_TIMESERV
Trusted DC Name \\DC01.corp.local
Trusted DC Connection StatusStatus = 0 0x0 NERR_Success
The command completed successfully
```

### Senaryo 4: Active Directory Replikasyon Sağlığını Kontrol Etme
Etki alanı denetleyicileri arasındaki veri eşitleme durumunu `repadmin` ile denetleme:

```cmd
repadmin /replsummary
```

**Konsol Çıktı Analizi:**
```
Replication Summary Start Time: 2026-10-14 21:10:00

Source DSA          largest delta    fails/total %%   error
 DC01                      08m:12s    0 /   5    0
 DC02                      05m:44s    0 /   5    0

Destination DSA     largest delta    fails/total %%   error
 DC01                      05m:44s    0 /   5    0
 DC02                      08m:12s    0 /   5    0

[+] All replications are healthy (0 fails).
```

### Senaryo 5: Acil Durumda Windows Yerelinden Parola Onarımı (netdom)
Eğer `restorepassword.py` script'ine erişilemiyorsa, DC üzerinde yerel yönetici haklarıyla güvenli kanalı sıfırlama:

```cmd
netdom resetpwd /s:DC02.corp.local /ud:corp.local\Administrator /pd:AdminPass123!
```

**Konsol Çıktı Analizi:**
```
The machine account password for the local machine has been successfully reset.
The command completed successfully.
```

### Senaryo 6: KDC Kerberos Bilet Önbelleğini Sıfırlama
Parola değişikliğinin ardından bayat kalmış Kerberos biletlerini temizleme:

```cmd
klist purge -li 0x3e7
```

**Konsol Çıktı Analizi:**
```
Targeting SYSTEM logon session (0x3e7)...
Deleting all tickets:
    Ticket(s) purged!
```

### Senaryo 7: PowerShell ile Otomatik Sağlık Doğrulama Zinciri
Onarım sonrasında Active Directory etki alanı sağlığını tek bir PowerShell komut dizisiyle baştan sona kontrol etme:

```powershell
$dc = "DC01.corp.local"
Write-Host "[*] Checking Secure Channel..." -ForegroundColor Cyan
Test-ComputerSecureChannel -Server $dc -Verbose
Write-Host "[*] Checking Replication Status..." -ForegroundColor Cyan
repadmin /showrepl $dc
Write-Host "[*] Checking Netlogon Service..." -ForegroundColor Cyan
Get-Service -Name Netlogon -ComputerName $dc
```

**Konsol Çıktı Analizi:**
```
[*] Checking Secure Channel...
VERBOSE: Secure channel connection to DC01.corp.local is verified.
True
[*] Checking Replication Status...
All inbound neighbors successfully synchronized. No errors reported.
[*] Checking Netlogon Service...
Status   Name       DisplayName
------   ----       -----------
Running  Netlogon   Netlogon
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Kök Neden | Kesin Çözüm Adımı |
| :--- | :--- | :--- |
| `STATUS_ACCESS_DENIED (0xc0000022)` | Boş parola ile oturum açılamıyor; ya parola önceden onarılmış ya da exploit boş parola atayamamış. | `nltest /sc_query` ile güvenli kanalı kontrol edin; DC'de oturum açıp `netdom resetpwd` alternatifini kullanın. |
| `STATUS_NOLOGON_WORKSTATION_TRUST_ACCOUNT` | Komutta verilen DC adı formatı hatalı; hesap adının sonuna `$` konulmamalıdır (`DC01` yazılmalıdır). | Sözdizimini `CORP/DC01@dc01.corp.local` biçiminde düzeltin; `DC01$` yazmaktan kaçının. |
| `ValueError: non-hexadecimal number found in fromhex()` | `-hexpass` parametresine girilen dize geçersiz karakterler içeriyor veya 32 karakterlik NT hash formatında değil. | SAM dökümündeki `$MACHINE.ACC` satırındaki yalnızca 32 karakterlik NT hash kısmını kopyalayın. |
| `Replication errors persist after restore (Event 5805)` | Parola onarıldı ancak Netlogon servisi yeni parolayı belleğe yüklemedi. | DC üzerinde `net stop netlogon && net start netlogon` komutuyla servisi yeniden başlatın. |
| `DC FQDN could not be resolved` | Linux denetim makinesinde DNS yapılandırması eksik. | `/etc/hosts` dosyasına `<DC_IP> dc01.corp.local DC01` kaydını ekleyin. |
| `Kerberos ticket request failed after restoration` | İşletim sistemi bilet önbelleğinde eski oturum anahtarları kaldı. | DC üzerinde `klist purge` çalıştırın veya sistemi yeniden başlatın (reboot). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
[OPSEC GÜRÜLTÜ SKALASI: DÜŞÜK - ORTA]
0 --------------[4.5 - NETLOGON REPAIR]---------------------- 10
  - Ağ Seviyesi: Tek bir Netlogon RPC bağlantısı (Meşru yönetimsel parola değişimine benzer)
  - Uç Nokta Seviyesi: Event ID 4742 (Bilgisayar hesabı parolası değiştirildi) üretilir
```

### 5.1 Bırakılan İzler (Event Logs)

* **Security Event Log (Event ID 4742 - A computer account was changed):**
  * `TargetUserName: DC01$`
  * `PasswordLastSet`: Bilgisayar hesabı parolasının orijinal haline döndürüldüğü an kaydedilir. Bu olay, exploit esnasında oluşan 4742 olayının hemen ardından gelmelidir.
* **Security Event Log (Event ID 4624 - Logon Type 3):**
  * Netlogon servisine yapılan ağ oturumu kaydedilir.
* **System Event Log (Event ID 5807):**
  * Netlogon servisinin güvenli kanal bağlantısını başarıyla doğruladığını gösteren meşru sistem olayı.

### 5.2 Ağ ve EDR İmzaları

* **Azalan Hata Trafiği:**
  `restorepassword.py` çalıştırılana kadar ağda yüzlerce Event 5805 ve Kerberos reddi akarken, bu aracın çalışmasının ardından ağ trafiği aniden olağan seyrine döner.
* **Tekil NetrServerPasswordSet2 Çağrısı:**
  Araç yalnızca tek bir RPC oturumu kurar ve şifreyi yazar; exploit'teki gibi yüzlerce başarısız oturum açma döngüsü üretmez.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
| :--- | :--- | :--- | :--- |
| **Defense Evasion** | `T1098` | Account Manipulation | DC makine hesabı parolasını SAM ile eşitleyerek izleri gizleme. |
| **Persistence / Evasion** | `T1078.002` | Valid Accounts: Domain Accounts | Sistem güvenli kanalını çalışır durumda tutma. |

### 5.4 OPSEC Önerileri

| Tespit Riski | Önlem / İyileştirme |
| :--- | :--- |
| **Uzun Süreli Desenkronizasyon** | Exploit çalıştırıldıktan sonra DCSync en fazla 30-60 saniye içinde tamamlanmalı ve hemen `restorepassword.py` koşturulmalıdır. |
| **Açık Bırakılan Boş Parola** | DC parolasının boş bırakılması ortamdaki tüm kullanıcıların erişimini kilitler; onarım adımı asla atlanmamalıdır. |
| **Log Analizi** | Onarım sonrası `Get-WinEvent` ile Event 5805 hatalarının kesildiği teyit edilmelidir. |

### 5.5 Savunma Karşılığı

#### Sigma Kuralı: Domain Controller Makine Parolasının Art Arda Değiştirilmesi
```yaml
title: DC Makine Parolasinin Supheli Sekilde Sifirlanmasi ve Geri Yuklenmesi
id: d18294a1-4412-4c88-b991-334411aa9900
status: experimental
description: Kisa sure icinde DC$ bilgisayar hesabi uzerinde olusan birden fazla Event ID 4742 degisikligini tespit eder (Zerologon + Restore).
references:
    - https://attack.mitre.org/techniques/T1098/
author: Active Directory Guvenlik Ekibi
date: 2026/10/14
logsource:
    service: security
    product: windows
detection:
    selection:
        EventID: 4742
        TargetUserName|endswith: '$'
    timeframe: 5m
    condition: selection | count() by TargetUserName >= 2
falsepositives:
    - Cok nadir olagandisi yonetimsel makine parolasi sifirlamalari.
level: critical
tags:
    - attack.defense_evasion
    - attack.t1098
```

#### Microsoft Sentinel KQL Sorgusu
```kql
// DC bilgisayar hesabi icin kisa araliklarla olusan Event ID 4742 degisikliklerini yakalar
SecurityEvent
| where TimeGenerated >= ago(2h)
| where EventID == 4742
| where TargetUserName endswith "$"
| summarize ChangeCount = count(), FirstChange = min(TimeGenerated), LastChange = max(TimeGenerated) by TargetUserName, Computer
| where ChangeCount >= 2 and datetime_diff('minute', LastChange, FirstChange) <= 10
| project FirstChange, LastChange, Computer, TargetUserName, ChangeCount
```

#### YARA Kuralı: restorepassword Python Script İmzası
```yara
rule Threat_Script_Zerologon_RestorePassword {
    meta:
        description = "Zerologon parola onarim betigi restorepassword.py imzasini tespit eder"
        author = "AD Guvenlik Laboratuvari"
        date = "2026-10-14"
        severity = "Medium"
    strings:
        $s1 = "restorepassword" ascii wide nocase
        $s2 = "NetrServerPasswordSet2" ascii wide
        $s3 = "-hexpass" ascii wide
        $s4 = "target-ip" ascii wide
    condition:
        all of ($s*)
}
```

#### Sertleştirme (Hardening) Adımları
1. **Netlogon Güvenli Kanal Zorunluluğu:** `FullSecureChannelProtection = 1` kaydı ile Zerologon istismarı tamamen engellenmeli; bu sayede geri yükleme ihtiyacı baştan bertaraf edilmelidir.
2. **Yedekleme ve Felaket Kurtarma Planı:** DC sistem durumu (System State) yedekleri düzenli olarak alınmalı ve parola bozulmalarına karşı test edilmelidir.
3. **Privileged Access Management (PAM):** Domain Controller yönetim erişimleri yalnızca Tier-0 izole yönetim iş istasyonları üzerinden gerçekleştirilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. Standart restorepassword Komutu
```bash
python3 restorepassword.py CORP.LOCAL/DC01@dc01.corp.local -target-ip 192.168.1.10 -hexpass a9128f44102938475610293847561029
```
* **Ne Yapar?:** Active Directory'deki `DC01$` parolasını SAM'den alınan orijinal hex değerine geri döndürür.
* **Ne Zaman Kullanılır?:** Zerologon istismarı ve DCSync tamamlandıktan hemen sonra.
* **Parametreler:** `CORP/DC01@FQDN`, `-target-ip`, `-hexpass`.

#### 2. secretsdump ile SAM Kovanından Makine Hash'i Alma
```bash
impacket-secretsdump -hashes :ADMIN_HASH 'CORP/Administrator@192.168.1.10'
```
* **Ne Yapar?:** Yerel SAM veritabanından `$MACHINE.ACC` orijinal NT hash'ini çıkarır.
* **Ne Zaman Kullanılır?:** Geri yüklenecek orijinal şifre bilinmediğinde.
* **Parametreler:** `-hashes` yönetici hash'i.

#### 3. nltest ile Güvenli Kanalı Doğrulama
```cmd
nltest /sc_query:corp.local
```
* **Ne Yapar?:** DC güvenli kanal durumunu denetler; `NERR_Success` dönmelidir.
* **Ne Zaman Kullanılır?:** Parola onarıldıktan sonra ilk kontrol adımı olarak.
* **Parametreler:** `/sc_query:<domain>`.

#### 4. repadmin ile Replikasyon Özetini İnceleme
```cmd
repadmin /replsummary
```
* **Ne Yapar?:** Tüm DC'ler arasındaki çoğaltma durumunu raporlar; hata sayısı `0` olmalıdır.
* **Ne Zaman Kullanılır?:** Güvenli kanal onarıldıktan sonra replikasyon sağlığını doğrulamak için.
* **Parametreler:** `repadmin` komutu.

#### 5. Kerberos Biletlerini Sıfırlama (klist purge)
```cmd
klist purge -li 0x3e7
```
* **Ne Yapar?:** SYSTEM oturumundaki eski biletleri temizler.
* **Ne Zaman Kullanılır?:** Parola değişiminden sonra Kerberos bilet hatalarını önlemek için.
* **Parametreler:** `-li 0x3e7` SYSTEM oturum ID'si.

#### 6. Netlogon Servisini Yeniden Başlatma
```cmd
net stop netlogon && net start netlogon
```
* **Ne Yapar?:** Netlogon servisini durdurup başlatarak yeni parolayı belleğe yükler.
* **Ne Zaman Kullanılır?:** Parola geri yüklendiği halde replikasyon hatası devam ediyorsa.
* **Parametreler:** Windows yerel servis komutları.

#### 7. netdom ile Yerel Parola Sıfırlama (Alternatif)
```cmd
netdom resetpwd /s:DC02.corp.local /ud:corp.local\Administrator /pd:AdminPass123!
```
* **Ne Yapar?:** Windows yerel komutu ile güvenli kanalı sıfırlar ve yeni parola belirler.
* **Ne Zaman Kullanılır?:** Python script'i çalışmadığında DC yerel konsolundan kurtarma yapmak için.
* **Parametreler:** `/s` eş DC adı, `/ud` yönetici kullanıcı, `/pd` parola.

#### 8. PowerShell Test-ComputerSecureChannel Denetimi
```powershell
Test-ComputerSecureChannel -Verbose
```
* **Ne Yapar?:** Bilgisayarın etki alanı ile güvenli kanalının geçerli olup olmadığını boolean olarak test eder.
* **Ne Zaman Kullanılır?:** Güvenli kanal durumunu hızlıca doğrulamak için.
* **Parametreler:** `Test-ComputerSecureChannel`.

#### 9. Event ID 4742 Günlüğünü Sorgulama
```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4742} -MaxEvents 5
```
* **Ne Yapar?:** Bilgisayar hesabı parola değişiklik olaylarını listeler.
* **Ne Zaman Kullanılır?:** Onarım işleminin işletim sistemi tarafından kaydedildiğini teyit etmek için.
* **Parametreler:** `Get-WinEvent`.

#### 10. Geçici Kurtarma Hash Dosyalarını Temizleme
```bash
rm -f /tmp/machine_acc.txt
```
* **Ne Yapar?:** Linux sistemde tutulan geçici hash dosyasını siler.
* **Ne Zaman Kullanılır?:** Onarım tamamlandıktan sonra hassas verileri imha etmek için.
* **Parametreler:** `rm -f`.

---

## Kaynaklar
* [Dirk-jan Mollema Resmi GitHub Deposu: restorepassword.py](https://github.com/dirkjanm/CVE-2020-1472)
* [Secura Zerologon Araştırma Dokümanı](https://www.secura.com/uploads/whitepapers/Zerologon.pdf)
* [Microsoft Dokümantasyonu: [MS-NRPC] Netlogon Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-nrpc/)
* [Microsoft Dokümantasyonu: How to Manage the Changes in Netlogon Secure Channel (CVE-2020-1472)](https://support.microsoft.com/en-us/topic/how-to-manage-the-changes-in-netlogon-secure-channel-connections-associated-with-cve-2020-1472-f7e8ea17-08f3-4e43-267f-77da21ac19f7)
* [MITRE ATT&CK: Account Manipulation (T1098)](https://attack.mitre.org/techniques/T1098/)

---

> **Önceki:** [← cve-2020-1472-exploit](./cve-2020-1472-exploit.md) · **Sonraki:** [PrintNightmare →](./PrintNightmare.md)
