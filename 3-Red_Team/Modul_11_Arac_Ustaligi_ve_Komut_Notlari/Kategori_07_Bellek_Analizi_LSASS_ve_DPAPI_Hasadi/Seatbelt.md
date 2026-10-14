# Seatbelt

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Will Schroeder (@harmj0y) tarafından GhostPack projesi kapsamında geliştirilen; kırmızı takım operatörlerine bir sisteme sızdıktan sonra (Post-Exploitation) güvenlik yazılımlarını (EDR/AV), LSA korumalarını (RunAsPPL, Credential Guard), oturum sırlarını, DPAPI anahtarlarını ve sistem duruşunu (Situational Awareness) bellek içinde dosyasız denetleme imkanı veren C# tabanlı durumsal farkındalık aracı.

---

## 1. Genel Bakış ve Amaç

Bir hedef makinede ilk erişim (Initial Access) veya yetki yükseltme (Privilege Escalation) sağlandıktan sonra, operatörün yapacağı en büyük hata ortamdaki güvenlik önlemlerini araştırmadan doğrudan `mimikatz.exe`, `comsvcs.dll` veya `PPLDump` gibi agresif araçları çalıştırmaktır. Hedefte:
- Hangi EDR yazılımı (CrowdStrike, SentinelOne, Defender for Endpoint) devrede?
- LSASS süreci `RunAsPPL` ile korunuyor mu?
- Donanım tabanlı **Windows Defender Credential Guard** aktif mi?
- PowerShell komut günlüğü (`ScriptBlockLogging` veya `Transcription`) açık mı?
- Kullanıcının oturumunda hangi DPAPI MasterKey'leri, kayıtlı RDP şifreleri veya bulut (AWS, Azure, GCP) kimlikleri var?

sorularının yanıtı bilinmeden atılacak bir adım operasyonun saniyeler içinde ifşa olmasına (Blue Team uyarısı) yol açar.

**`Seatbelt`**, bu "güvenlik kontrollerini" (*Safety Checks*) gerçekleştirmek üzere tasarlanmış modüler bir .NET aracıdır. Araç:
1. **Modüler Komut Yapısı:** 70'in üzerinde bağımsız denetim modülüne sahiptir. Operatör tüm sistemi taratabileceği gibi (`-group=all`), yalnızca parola ve kasalara (`-group=user`) veya yalnızca güvenlik mekanizmalarına (`AntiVirusSummary`, `LSAProtectedProcess`, `CredentialGuard`) odaklanabilir.
2. **Dosyasız C2 Entegrasyonu:** Tamamen saf C# (.NET) ile yazılmıştır; Cobalt Strike, Mythic veya Havoc üzerinde `execute-assembly` ile diske yazılmadan doğrudan bellek içinde yürütülür.
3. **Kasa ve DPAPI Ön Keşfi:** Kategori 07 bağlamında; makinede hangi DPAPI anahtarlarının bulunduğunu, kayıtlı RDP bağlantılarını (`RDPSavedConnections`), PuTTY oturumlarını, Windows Vault kayıtlarını ve bulut anahtarlarını önceden raporlayarak sonraki parola hasadı adımlarına kesin yol gösterir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│             SALDIRGAN / C2 BEACON (execute-assembly)                   │
│                                                                        │
│  [ Seatbelt.exe (.NET / C#) ]                                          │
│         │                                                              │
│         ├── [ 1. GÜVENLİK VE SAVUNMA KEŞFİ (Safety Checks) ]           │
│         │     ├── AntiVirusSummary    ──> EDR / AV Süreçlerini Saptar │
│         │     ├── LSAProtectedProcess ──> RunAsPPL Durumu (0x0, 0x1)   │
│         │     ├── CredentialGuard     ──> VBS / IUM LsaIso Kontrolü    │
│         │     └── UAC / AuditSettings ──> Yetki ve Loglama Düzeyi      │
│         │                                                              │
│         ├── [ 2. KİMLİK VE KASA ÖN DEĞERLENDİRMESİ (Credential Recon)]│
│         │     ├── DPAPIMasterKeys     ──> Kullanıcı MasterKey Dosyaları│
│         │     ├── CredEnum / Vault    ──> RDP / Windows Kasa Kayıtları │
│         │     ├── CloudCredentials    ──> AWS, Azure, GCP CLI Tokenları│
│         │     └── PuttySessions       ──> SSH Özel Anahtarları ve Host │
│         │                                                              │
│         └── [ 3. SİSTEM VE AĞ HARİTALAMASI (Host Awareness) ]          │
│               ├── NetworkShares / ARP ──> Yanal Hareket Hedefleri      │
│               └── Processes / Services──> İlgi Çekici Yazılımlar       │
│                         │                                              │
│                         ▼                                              │
│             [ Renkli Konsol / Tablo / JSON Çıktısı ]                   │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Kategori 07 İçin Kritik Seatbelt Komutları

| Seatbelt Komutu | Denetlenen Güvenlik Mekanizması / Kasa | Operasyonel Karar |
|---|---|---|
| **`AntiVirusSummary`** | WMI (`root\SecurityCenter2`) ve çalışan servisler taranarak aktif EDR saptanır. | SentinelOne/CrowdStrike varsa klasik dökümden vazgeçilip BOF veya Dumpert'e geçilir. |
| **`LSAProtectedProcess`**| `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL` değeri sorgulanır. | `0x1` ise `comsvcs.dll` yerine `PPLMedic` veya `PPLKiller` kullanılır. |
| **`CredentialGuard`** | WMI `Win32_DeviceGuard` ve VBS (Sanallaştırma) durumu denetlenir. | Aktifse LSASS dökümünden parola çıkmayacağı anlaşılır; DPAPI ve token avına geçilir. |
| **`DPAPIMasterKeys`** | `%APPDATA%\Microsoft\Protect\` altındaki MasterKey dosyalarını ve GUID'lerini listeler. | `SharpDPAPI` veya `DonPAPI` ile hangi anahtarların çözüleceğini hedefler. |
| **`CredEnum`** | Windows Credential Manager'da kayıtlı olan RDP ve SSO kimliklerini listeler. | Hedef sunuculara anında yanal hareket için hazır kimlikler sunar. |
| **`CloudCredentials`** | `.aws\credentials`, `.azure\`, `gcloud` yapılandırma dizinlerini tarar. | Şirketin bulut ortamlarına doğrudan sızma imkanı sağlar. |

---

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Kritik Hataları Önleme** | EDR veya Credential Guard varken körlemesine Mimikatz çalıştırmayı engeller. | Kırmızı takım operasyonunun ilk dakikalarda ifşa olmasını önleyen en temel kalkandır. |
| **70+ Modül Zenginliği** | Sistem, kullanıcı, tarayıcı, bulut ve ağ denetimlerini tek bir çatıda birleştirir. | Saatlerce sürecek manuel CMD kontrollerini 5 saniyelik tek bir komuta indirir. |
| **execute-assembly Uyumu** | Diske dosya bırakmadan Beacon belleği üzerinden yürütülür. | Disk tabanlı antivirüs taramalarını tamamen atlatır. |
| **Özelleştirilebilir Filtreleme**| Tüm komutları çalıştırmak yerine yalnızca spesifik komutlar seçilebilir. | Uç noktada WMI ve süreç tarama gürültüsünü minimuma indirir. |

### Karşılaştırma Tablosu

| Kriter | Seatbelt | winPEAS | SharpUp | PowerView |
|---|---|---|---|---|
| **Odak Alanı** | Durumsal Farkındalık / EDR | Yetki Yükseltme Yolları | Hızlı Yetki Yükseltme | Active Directory Keşfi |
| **Kod Tabanı** | Saf C# (.NET) | C# (.NET) / BAT | Saf C# (.NET) | PowerShell |
| **Credential Guard Tespiti**| **Mükemmel** | Var | Yok | Yok |
| **DPAPI / Kasa Taraması** | **Mükemmel** | Çok Yüksek (Gürültülü) | Kısıtlı | Yok |
| **EDR Yakalanma Seviyesi** | Düşük - Orta | Yüksek (Aşırı gürültülü) | Düşük | Orta (ScriptBlock) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
Seatbelt.exe <Komut|Grup> [seçenekler]
```

### Önceden Tanımlı Komut Grupları

| Grup Adı | Kapsam ve Açıklama |
|---|---|
| `system` | İşletim sistemi, EDR/AV, LSA korumaları, UAC, denetim ilkeleri, servisler ve sürücüler. |
| `user` | Oturum açmış kullanıcının DPAPI anahtarları, tarayıcıları, kasaları, bulut kimlikleri. |
| `all` | Sistemdeki 70+ modülün tamamını sırayla çalıştırır (Yüksek gürültülüdür). |
| `interesting` | Sistemde dikkat çeken olağandışı süreçler, servisler ve kayıt defteri ayarları. |
| `remote` | Uzak sistemleri WMI üzerinden denetlemek için kullanılan modüller. |

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-group=<grup>` | Belirtilen komut grubunu toplu olarak çalıştırır. | `-group=system` veya `-group=user` |
| `-full` | Sonuçları özet yerine tüm ayrıntılarıyla ekrana basar. | `Seatbelt.exe -group=system -full` |
| `-outputfile=<yol>` | Çıktıyı konsol yerine belirtilen metin dosyasına kaydeder. | `-outputfile=C:\Temp\recon.txt` |
| `-quiet` | Başlık banner'ını ve gereksiz bilgilendirme satırlarını gizler. | `Seatbelt.exe -quiet AntiVirusSummary` |
| `/filter:<arama>` | Sonuçlar içerisinde belirli bir kelimeyi veya deseni filtreler. | `/filter:CrowdStrike` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: LSASS/DPAPI Saldırısı Öncesi Kritik Güvenlik Duruşu Tespiti

Operatör makineye ilk girdiğinde, doğrudan savunma mekanizmalarını ve korumalı süreç durumunu denetler:

```cmd
Seatbelt.exe AntiVirusSummary LSAProtectedProcess CredentialGuard
```

**Konsol Çıktısı Analizi:**

```text
[*] Seatbelt by @harmj0y
[*] Target: Local Machine

====== AntiVirusSummary ======
  [+] WMI SecurityCenter2:
      Product: Windows Defender
      State  : Enabled (Real-time protection ON)
  [+] Running Processes:
      CrowdStrike Falcon Sensor (CSFalconService.exe) -> [CRITICAL: EDR ACTIVE!]

====== LSAProtectedProcess ======
  [+] RunAsPPL: 1 (Enabled - PsProtectedSignerLsa-Light)
  [!] WARNING: LSASS is a Protected Process. Standard dumps (Mimikatz/comsvcs) will FAIL!

====== CredentialGuard ======
  [+] Virtualization Based Security: Enabled
  [+] Credential Guard Status      : Running (LsaIso.exe is active)
  [!] WARNING: Passwords and NTLM hashes in LSASS are isolated in VTL 1. Target DPAPI instead!

[+] Safety checks completed!
```

---

### Senaryo 2: Kullanıcı Kimlik, Kasa ve DPAPI Ön Taraması (`-group=user`)

Kullanıcının tarayıcı şifreleri, MasterKey'leri ve RDP kayıtları tek hamlede listelenir:

```cmd
Seatbelt.exe -group=user
```

---

### Senaryo 3: Bulut ve Geliştirici Kimliklerini Toplama

Yazılımcı veya DevOps mühendisi makinelerinde AWS, Azure CLI ve PuTTY özel anahtarlarını arama:

```cmd
Seatbelt.exe CloudCredentials PuttySessions GitConfig
```

---

### Senaryo 4: Cobalt Strike `execute-assembly` ile Dosyasız Situational Awareness

Beacon oturumu üzerinden hiçbir dosya indirmeden bellek içi güvenlik denetimi yapma:

```text
beacon> execute-assembly /opt/GhostPack/Seatbelt.exe AntiVirusSummary LSAProtectedProcess
```

---

### Senaryo 5: Sistem Seviyesinde Detaylı Denetim (`-group=system -full`)

SYSTEM yetkilerine ulaşıldığında işletim sisteminin tüm yapılandırmasını ayrıntılı olarak raporlama:

```cmd
Seatbelt.exe -group=system -full -outputfile=C:\Windows\Temp\audit_report.txt
```

---

### Senaryo 6: Yanal Hareket Öncesi Ağ ve Paylaşım Taraması

Ağdaki diğer sistemleri ve erişilebilir paylaşımları haritalama:

```cmd
Seatbelt.exe NetworkShares ARPTable DNSCache
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `WMI query failed: Access Denied (0x80041003)` | Kullanıcı oturumu `root\SecurityCenter2` veya belirli WMI sınıflarını okumak için yetersiz. | Süreci yerel yönetici haklarına yükseltin veya WMI gerektirmeyen komutları (Registry tabanlı) tercih edin. |
| `Execution timeout / Beacon hangs on -group=all` | Tüm modüllerin çalıştırılması dakikalarca sürebilir ve yüzlerce WMI sorgusu üretir. | Asla `-group=all` çalıştırmayın; yalnızca ihtiyaç duyulan 3-4 kritik modülü tek tek belirtin. |
| `AntiVirusSummary returns empty / no AV found` | Windows Server sürümlerinde `root\SecurityCenter2` WMI isim alanı varsayılan olarak bulunmaz. | Süreç listesi (`Processes`) veya servis listesi (`Services`) üzerinden güvenlik ajanlarını arayın. |
| `CLR Exception / Assembly failed to load` | Hedef makinedeki .NET Framework sürümü (örneğin .NET 3.5) derlenen sürümle (.NET 4.5+) uyuşmuyor. | Seatbelt'i hedef sistemin .NET sürümüne göre (`net35` veya `net40`) derleyip çalıştırın. |
| `Truncated output in C2 console` | Cobalt Strike veya Mythic konsolunun çıktı arabelleği doldu. | Çıktıyı doğrudan C2 konsoluna basmak yerine `-outputfile=` ile geçici bir dosyaya yönlendirip dosyayı indirin. |
| `PowerShell ScriptBlockLogging: Active` | PowerShell denetim modu açık; PowerShell üzerinden çağrılan komutlar loglanıyor. | PowerShell yerine doğrudan `execute-assembly` veya CMD altından ikili çalıştırma kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇALIŞTIRILAN MODÜLE GÖRE DEĞİŞİR (1-2 MODÜL: DÜŞÜK / ALL: ÇOK YÜKSEK)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4688 (Process Creation) [execute-assembly hariç]
[ Sysmon ]          : Event ID 7 (.NET CLR Loading), Event ID 1
[ WMI İmzası ]      : root\SecurityCenter2 ve root\cimv2 Çoklu Sorguları
[ EDR Davranışı ]   : EDR süreçlerinin taranması anomali olarak izlenebilir
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Sysmon Event ID 7 (ImageLoaded):**
   - Standart bir sürece `execute-assembly` ile enjekte edildiğinde `clr.dll` ve `mscorlib.dll` yüklenmesi.
2. **WMI Etkinlik Logları:**
   - Microsoft-Windows-WMI-Activity/Operational günlüğünde ardışık WMI sorgu kayıtları (`SELECT * FROM AntiVirusProduct`).
3. **Kayıt Defteri Sorgu Yoğunluğu:**
   - `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` ve `HKLM\Software\Policies\Microsoft\Windows\PowerShell` anahtarlarına yönelik okuma kayıtları.

### 5.2 Ağ ve EDR İmzaları

- **Reconnaissance (Keşif) Davranışsal Analizi:** `-group=all` çalıştırıldığında saniyeler içinde onlarca WMI ve kayıt defteri çağrısı yapılması EDR davranışsal analiz motorlarında "Host Reconnaissance" alarmı üretir.
- **AMSI Taraması:** Derlenmiş hazır `Seatbelt.exe` ikilisi kamuya açık statik dizgiler (`@harmj0y`, `Seatbelt`, `GhostPack`) içerdiğinden AMSI tarafından doğrudan engellenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1082** | System Information Discovery | İşletim sistemi, yama ve donanım bilgilerini toplama. |
| **T1518.001** | Security Software Discovery | Antivirüs ve EDR yazılımlarını saptama (`AntiVirusSummary`). |
| **T1057** | Process Discovery | Çalışan süreçleri ve servisleri listeleme. |
| **T1555** | Credentials from Password Stores | DPAPI MasterKey'lerini ve Windows Vault verilerini arama. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Aşırı Gürültülü Keşif** | `-group=all` seçeneğini **asla** kullanmayın. Yalnızca operasyonel kararınız için gereken 2-3 modülü (`AntiVirusSummary LSAProtectedProcess`) çağırın. |
| **AMSI İmzası** | Projeyi GitHub'dan derlemeden önce kaynak kodundaki namespace, sınıf ve metot isimlerini değiştirin (InvisibilityCloak veya DefenderCheck kullanın). |
| **WMI Tespiti** | WMI izlemesi olan sıkı ortamlarda WMI kullanan modüller yerine doğrudan kayıt defterini okuyan modülleri tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Seatbelt .NET Assembly Tespiti:**

```yara
rule Suspicious_Seatbelt_Assembly {
    meta:
        description = "Detects Seatbelt situational awareness tool based on unique module strings"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $s1 = "Seatbelt" ascii wide nocase
        $s2 = "AntiVirusSummary" ascii wide
        $s3 = "LSAProtectedProcess" ascii wide
        $s4 = "CredentialGuard" ascii wide
        $s5 = "DPAPIMasterKeys" ascii wide
    condition:
        uint16(0) == 0x5A4D and 3 of them
}
```

**Sigma Kuralı — Şüpheli Keşif Modüllerinin Komut Satırında Çağrılması:**

```yaml
title: Suspicious Seatbelt Reconnaissance Tool Execution
status: experimental
description: Detects command line usage of Seatbelt situational awareness modules.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    CommandLine|contains|any:
      - 'AntiVirusSummary'
      - 'LSAProtectedProcess'
      - 'CredentialGuard'
      - '-group=system'
      - '-group=user'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Hızlı Güvenlik Yazılımı Keşif Sorguları:**

```kql
DeviceEvents
| where ActionType == "WmiQuery"
| where AdditionalFields has "AntiVirusProduct" or AdditionalFields has "Win32_DeviceGuard"
| summarize QueryCount = count() by DeviceName, InitiatingProcessFileName, bin(TimeGenerated, 5m)
| where QueryCount > 3
| project TimeGenerated, DeviceName, InitiatingProcessFileName, QueryCount
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Hızlı Güvenlik ve EDR Kontrolü (Minimum Gürültü)
```cmd
Seatbelt.exe AntiVirusSummary LSAProtectedProcess CredentialGuard
```
- **Ne Yapar?** Hangi EDR'ın çalıştığını, RunAsPPL'in ve Credential Guard'ın aktif olup olmadığını raporlar.
- **Ne Zaman Kullanılır?** Makineye ilk erişim sağlandığında saldırı aracını seçmeden önce ilk adım olarak.
- **Parametreler:** Yalnızca belirtilen 3 kritik güvenlik modülünü icra eder.

### Komut 2: Kullanıcı Kasa ve Kimlik Taraması
```cmd
Seatbelt.exe -group=user
```
- **Ne Yapar?** Kullanıcının MasterKey'lerini, Vault kayıtlarını, RDP ve tarayıcı şifrelerini arar.
- **Ne Zaman Kullanılır?** Kullanıcı oturumundaki potansiyel kimlik materyallerini haritalamak için.
- **Parametreler:** `-group=user`: Kullanıcı düzeyi modül grubu.

### Komut 3: Bulut ve DevOps Anahtarlarını Arama
```cmd
Seatbelt.exe CloudCredentials PuttySessions GitConfig
```
- **Ne Yapar?** AWS, Azure CLI, PuTTY ve Git SSH anahtarlarını tarar.
- **Ne Zaman Kullanılır?** Bulut altyapısına veya kod depolarına sızmak amacıyla geliştirici kimliklerini ararken.
- **Parametreler:** Bulut ve geliştirici modülleri.

### Komut 4: Cobalt Strike Beacon ile Bellek İçi Keşif
```text
beacon> execute-assembly Seatbelt.exe AntiVirusSummary LSAProtectedProcess
```
- **Ne Yapar?** Seatbelt'i diske dokunmadan Beacon belleği üzerinden yürütür.
- **Ne Zaman Kullanılır?** C2 operasyonlarında dosyasız durumsal farkındalık elde etmek için.
- **Parametreler:** `execute-assembly`: .NET bellek yükleyicisi.

### Komut 5: Sistem Duruşunu Özet Raporlama
```cmd
Seatbelt.exe -group=system
```
- **Ne Yapar?** İşletim sistemi, güvenlik ilkeleri, UAC ve servis yapılandırmalarını listeler.
- **Ne Zaman Kullanılır?** Yetki yükseltme fırsatlarını ve sistem sıkılaştırmasını değerlendirmek için.
- **Parametreler:** `-group=system`: Sistem modül grubu.

### Komut 6: PowerShell Günlükleme ve Denetim Durumunu İnceleme
```cmd
Seatbelt.exe PowerShellSettings AuditSettings
```
- **Ne Yapar?** ScriptBlockLogging ve Windows Güvenlik Denetimi ilkelerinin durumunu gösterir.
- **Ne Zaman Kullanılır?** PowerShell tabanlı bir saldırı yapmadan önce loglanma riskini ölçmek için.
- **Parametreler:** PowerShell ve Denetim modülleri.

### Komut 7: DPAPI MasterKey Dosyalarını Listeleme
```cmd
Seatbelt.exe DPAPIMasterKeys
```
- **Ne Yapar?** Kullanıcının diskte saklanan tüm MasterKey GUID'lerini ve dosya yollarını dökümünü çıkarır.
- **Ne Zaman Kullanılır?** `SharpDPAPI` veya `DonPAPI` ile hangi anahtarların çözüleceğini planlarken.
- **Parametreler:** `DPAPIMasterKeys`: DPAPI modülü.

### Komut 8: Kayıtlı RDP Bağlantılarını Listeleme
```cmd
Seatbelt.exe RDPSavedConnections RDCManFiles
```
- **Ne Yapar?** Windows Credential Manager'daki RDP hedeflerini ve RDCMan bağlantı dosyalarını bulur.
- **Ne Zaman Kullanılır?** Ağdaki diğer kritik sunucuların IP adreslerini ve kayıtlı hesapları öğrenmek için.
- **Parametreler:** RDP keşif modülleri.

### Komut 9: Sessiz Modda (Quiet) Çıktı Alma
```cmd
Seatbelt.exe -quiet AntiVirusSummary
```
- **Ne Yapar?** Başlık ASCII logosunu ve bilgilendirme metinlerini atlayarak yalnızca sonucu gösterir.
- **Ne Zaman Kullanılır?** Konsol çıktısını temiz tutmak veya otomatik betiklerle ayrıştırmak için.
- **Parametreler:** `-quiet`: Sessiz mod bayrağı.

### Komut 10: Çıktıyı Dosyaya Yönlendirerek Kaydetme
```cmd
Seatbelt.exe -group=user -outputfile=C:\Windows\Temp\user_recon.txt
```
- **Ne Yapar?** Toplanan tüm kullanıcı kimlik verilerini belirtilen metin dosyasına yazar.
- **Ne Zaman Kullanılır?** Büyük çıktıları daha sonra çevrimdışı incelemek veya indirmek için.
- **Parametreler:** `-outputfile=`: Dosya yolu parametresi.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [GhostPack / Seatbelt](https://github.com/GhostPack/Seatbelt)
- **Harmj0y Blog:** [Seatbelt: Situational Awareness for .NET](https://blog.harmj0y.net/)
- **MITRE ATT&CK Referansı:** [T1082 - System Information Discovery](https://attack.mitre.org/techniques/T1082/)
- **SpecterOps Araştırması:** [Operational Guidance for Situational Awareness](https://posts.specterops.io/)

---

> **Önceki:** [← SharpChrome](./SharpChrome.md) · **Sonraki:** [Internal-Monologue →](./Internal-Monologue.md)
