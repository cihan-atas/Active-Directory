# Hashcat

> **Kategori:** [18. ÇEVRİMDIŞI PAROLA KIRMA (OFFLINE CRACKING)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Modern GPU (CUDA / OpenCL / Metal) donanım hızlandırmasını kullanarak Active Directory ortamlarından elde edilen NTLM, NetNTLMv2, Kerberoast ve AS-REP bilet hash'lerini saniyede milyarlarca deneme hızıyla çözen dünyanın en gelişmiş çevrimdışı parola kırma motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında ağ üzerinden toplanan veya veritabanlarından dökülen kimlik bilgileri genellikle açık metin (plaintext) parola olarak değil, tek yönlü kriptografik özetler (hash) veya şifrelenmiş biletler biçiminde elde edilir:
* **NTDS.dit ve SAM:** `secretsdump.py` veya `ntdsutil` ile elde edilen kullanıcı NTLM hash'leri (`MD4(UTF-16LE(parola))`).
* **LLMNR/NBT-NS Zehirleme:** `Responder` veya `Inveigh` ile yakalanan NetNTLMv1 ve NetNTLMv2 (Challenge/Response) ağ kimlik doğrulamaları.
* **Kerberoasting:** Servis hesapları (SPN) için istenen RC4-HMAC (`$krb5tgs$23$`) veya AES (`$krb5tgs$18$`) biletleri.
* **AS-REP Roasting:** `Do not require Kerberos preauthentication` işaretli hesaplar için elde edilen AS-REP yanıtları (`$krb5asrep$23$`).

Bu hash'ler hedef ağda aktif bir kilitlenme riski yaratmadan, tamamen saldırganın kendi izole donanımında (offline) kırılmalıdır. Jens Steube (@jsteube) tarafından geliştirilen **Hashcat**, modern grafik işlemcilerinin (GPU) binlerce paralel çekirdeğinden (NVIDIA CUDA, AMD ROCm/OpenCL, Apple Metal) yararlanarak CPU tabanlı çözücülere kıyasla yüzlerce kat daha yüksek hesaplama hızına ulaşır. Hashcat; doğrudan sözlük saldırılarından (wordlist), kural tabanlı saldırılara (rules), maske/kombinasyon yöntemlerinden kurumsal parola kalıplarını hedefleyen hibrit yaklaşımlara kadar kapsamlı bir saldırı cephaneliği sunar.

```
+---------------------------------------------------------------------------------------------------+
|                                 HASHCAT ÇEVRİMDIŞI KIRMA MİMARİSİ                                 |
+---------------------------------------------------------------------------------------------------+

 [ Active Directory Ağındaki Hasat Kaynakları ]
   • NTDS.dit Dökümü (DCSync) ────────► NTLM Hash (Mode 1000)
   • Responder / Coerce (LLMNR) ──────► NetNTLMv2 Hash (Mode 5600)
   • Kerberoast (GetUserSPNs) ────────► Kerberos 5 TGS etype 23 (Mode 13100)
   • AS-REP Roasting (GetNPUsers) ────► Kerberos 5 AS-REP etype 23 (Mode 18200)
             │
             ├─► Hash Dosyası Dışarıya Aktarılır (hashes.txt)
             │
             ▼
 [ Saldırganın Çevrimdışı Kırma İstasyonu (GPU Rig) ]
             │
             ├─► 1. Sözlük & Kural Motoru (rockyou.txt + best64.rule)
             │
             ├─► 2. Hashcat Çekirdeği (Kernel Optimization -O)
             │      (Bellek ve Register Optimizasyonu)
             │
             ├─► 3. Paralel GPU Dağıtımı (NVIDIA CUDA / AMD OpenCL)
             │      (Binlerce CUDA Çekirdeği Eşzamanlı Hash Üretir)
             │
             ▼
 [ Karşılaştırma & Eşleşme (Hash Match) ]
             │
             ├─► Eşleşen Parola: "Sirket2026!"
             │
             └─► hashcat.potfile Dosyasına Yazılır ve Ekrana Basılır
```

### Neden Önemli?

| Özellik | Operasyonel Avantajı |
|:---|:---|
| **Sıfır Hesap Kilitleme Riski** | Tamamen çevrimdışı çalışır; etki alanındaki `badPwdCount` sayacını artırmaz ve lockout eşiğini tetiklemez. |
| **Aşırı Yüksek Donanım Hızı** | Modern bir NVIDIA RTX 4090 GPU üzerinde NTLM için saniyede 100+ GigaHash (100 milyar deneme) hızına ulaşır. |
| **Geniş AD Hash Desteği** | NTLM, NetNTLMv1/v2, Kerberos TGS (RC4/AES), AS-REP ve BitLocker formatlarını yerel olarak destekler. |
| **Gelişmiş Kural Motoru (Rules)** | Parola sonuna yıl, özel karakter ekleme ve büyük/küçük harf permütasyonlarını GPU çekirdeğinde otomatik üretir. |
| **Kesinti ve Devam Desteği (`--restore`)** | Günler süren kırma operasyonları durdurulabilir ve kaldığı yerden sorunsuz devam ettirilebilir. |

### Çevrimdışı Parola Kırma Araçları Karşılaştırması

| Kriter | Hashcat | John the Ripper (JtR) | Ophcrack | Cain & Abel |
|:---|:---|:---|:---|:---|
| **Birincil Donanım** | **GPU (CUDA / OpenCL)** | CPU (Jumbo GPU kısmi) | Bellek / Rainbow Tables | CPU |
| **NTLM Hızı** | **Aşırı Yüksek (100+ GH/s)**| Yüksek (CPU sınırında) | Hızlı (Küçük Parolalar) | Düşük |
| **Kerberos AES Desteği** | ✅ Tam Destek (19600/19700) | ✅ Destekler | ❌ Yok | ❌ Yok |
| **Kural Motoru Esnekliği** | ✅ Çok Güçlü (C-benzeri) | ✅ Çok Güçlü | ❌ Kural Yok | ⚠️ Çok Basit |
| **Optimizasyon Seviyesi** | ✅ Donanım Düzeyi Kernel | ⚠️ Derleme Seviyesi | ⚠️ Tablo Boyutu Sınırlı | ❌ Eski / Terk Edilmiş |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Hashcat CLI sözdizimi; saldırı modu (`-a`), hash türü (`-m`), hedef dosya ve parola listesi/maske tanımından oluşur.

```bash
hashcat -m <HASH_TIPI> -a <SALDIRI_MODU> [SEÇENEKLER] <HASH_DOSYASI> [SOZLUK|MASKE]
```

### 2.1 Kritik Active Directory Hash Modları (`-m`)

| Mod Kodu | Adı / Protokol | Elde Edilme Yöntemi | Örnek Hash Başlığı |
|:---|:---|:---|:---|
| `1000` | NTLM | NTDS.dit dökümü, SAM, LSA Secrets | `31d6cfe0d16ae931b73c59d7e0c089c0` |
| `5600` | NetNTLMv2 | Responder, Inveigh, WebDAV/SMB Coerce | `admin::CORP:11223344:...` |
| `5500` | NetNTLMv1 | Eski NTLMv1 SMB yakalamaları | `u::d:1122334455667788:...` |
| `13100` | Kerberos 5 TGS-REP etype 23 | Kerberoasting (RC4-HMAC) | `$krb5tgs$23$*user$realm$...` |
| `18200` | Kerberos 5 AS-REP etype 23 | AS-REP Roasting (Önkimliksiz hesaplar) | `$krb5asrep$23$user@realm:...` |
| `19600` | Kerberos 5 TGS-REP etype 17 | Kerberoasting (AES128-CTS-HMAC) | `$krb5tgs$17$...` |
| `19700` | Kerberos 5 TGS-REP etype 18 | Kerberoasting (AES256-CTS-HMAC) | `$krb5tgs$18$...` |

### 2.2 Saldırı Modları (`-a`)

| Mod | Adı | Çalışma Mantığı | Örnek Sözdizimi |
|:---|:---|:---|:---|
| `-a 0` | Düz Sözlük (Straight) | Belirtilen kelime listesindeki adayları tek tek dener. | `hashcat -m 1000 -a 0 ntlm.txt rockyou.txt` |
| `-a 1` | Kombinasyon (Combination) | İki kelime listesini birleştirir (örn. `word1 + word2`). | `hashcat -m 1000 -a 1 ntlm.txt list1.txt list2.txt` |
| `-a 3` | Kaba Kuvvet / Maske (Brute-Force)| Belirlenen karakter kalıbına göre tüm permütasyonları üretir. | `hashcat -m 1000 -a 3 ntlm.txt ?u?l?l?l?d?d?d?s` |
| `-a 6` | Hibrit Sözlük + Maske | Kelimenin sonuna belirlenen karakterleri ekler. | `hashcat -m 1000 -a 6 ntlm.txt dict.txt ?d?d?d?d` |
| `-a 7` | Hibrit Maske + Sözlük | Kelimenin başına belirlenen karakterleri ekler. | `hashcat -m 1000 -a 7 ntlm.txt ?d?d?d?d dict.txt` |

### 2.3 Donanım ve Optimizasyon Parametreleri

| Parametre | Açıklama | Önerilen Değer |
|:---|:---|:---|
| `-w <1-4>` | İş yükü profili (Workload Profile): `1` (Düşük/Masaüstü), `2` (Varsayılan), `3` (Yüksek), `4` (Kabus/Tam Yük). | `-w 3` |
| `-O, --optimized-kernel-buffers` | Parola uzunluğunu sınırlandırarak (örn. <= 32 karakter) GPU hızını maksimize eder. | `-O` |
| `-r <kural_dosyası>` | Sözlükteki her kelimeye uygulanacak manipülasyon kuralları. | `-r rules/best64.rule` |
| `--status` | Ekranda periyodik olarak donanım sıcaklığı, hız ve tahmini bitiş süresini gösterir. | `--status` |
| `--status-timer <sn>` | Durum ekranının güncellenme aralığı (saniye). | `--status-timer 5` |
| `--show` | Daha önce kırılmış ve potfile içine yazılmış parolaları ekrana basar. | `--show` |
| `--left` | Henüz kırılmamış hash'leri ekrana basar. | `--left` |
| `-o <dosya>` | Kırılan parolaları belirtilen çıktı dosyasına kaydeder. | `-o cracked.txt` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: NTDS.dit Dökümünden Alınan NTLM Hash'lerini Kırma (Mode 1000)
Etki alanı denetleyicisinden DCSync ile çekilen NTLM hash listesi, `rockyou.txt` sözlüğü ve `best64.rule` kuralları ile GPU üzerinde hızlandırılmış olarak kırılır.

```bash
hashcat -m 1000 -a 0 -w 3 -O /opt/hashes/domain_ntlm.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule -o /opt/hashes/cracked_ntlm.txt
```

```text
nvmlDeviceGetHandleByPciBusId(): Success

Hashes: 1245 digests; 850 unique digests
Bitmaps: 16 bits, 65536 entries, 0x0000ffff mask, 262144 bytes
Rules: 64

Applicable optimizers applied:
* Optimized-Kernel
* Zero-Byte

Watchdog: Temperature abort trigger set to 90c

Host memory required for this attack: 145 MB

[s]tatus [p]ause [b]ypass [c]heckpoint [f]inish [q]uit => s

Speed.#1.........: 45212.4 MH/s (58.41ms) @ [GPU #1: NVIDIA RTX 4090]
Recovered........: 612/850 (72.00%) Digests, 612/850 (72.00%) Salts
Progress.........: 917504000/917504000 (100.00%)
Status...........: Completed
```

### Senaryo 2: Responder ile Yakalanan NetNTLMv2 Hash'lerini Kırma (Mode 5600)
Kurumsal ağda LLMNR/NBT-NS zehirlemesi ile ele geçirilen `admin::CORP:112233...` formatındaki NetNTLMv2 hash'i sözlük saldırısıyla çözülür.

```bash
hashcat -m 5600 -a 0 -w 3 /opt/hashes/responder_netntlmv2.txt /usr/share/wordlists/rockyou.txt
```

```text
Hash.Name........: NetNTLMv2
Speed.#1.........:  1425.2 MH/s @ [GPU #1: NVIDIA RTX 4090]
Recovered........: 1/1 (100.00%) Digests
Result...........: admin::CORP:1122334455667788:6a81...:Sirket2026!
```

### Senaryo 3: Kerberoasting Biletlerini (TGS-REP) Kırma (Mode 13100)
`impacket-GetUserSPNs` ile elde edilen RC4-HMAC servis hesabı biletleri kural tabanlı saldırı ile hedeflenir.

```bash
hashcat -m 13100 -a 0 -w 3 /opt/hashes/kerberoast_tgs.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/OneRuleToRuleThemAll.rule
```

```text
Hash.Name........: Kerberos 5, etype 23, TGS-REP
Speed.#1.........:   412.8 MH/s @ [GPU #1: NVIDIA RTX 4090]
Recovered........: 3/5 (60.00%) Digests
Result...........: $krb5tgs$23$*mssql_svc*CORP.LOCAL*...:SqlServiceP@ss1
```

### Senaryo 4: AS-REP Roasting Biletlerini Kırma (Mode 18200)
Kerberos önkimlik doğrulaması kapatılmış kullanıcılardan toplanan AS-REP hash'leri çözülür.

```bash
hashcat -m 18200 -a 0 -w 3 /opt/hashes/asrep_hashes.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/d3ad0ne.rule
```

```text
Hash.Name........: Kerberos 5, etype 23, AS-REP
Speed.#1.........:   408.1 MH/s @ [GPU #1: NVIDIA RTX 4090]
Recovered........: 1/2 (50.00%) Digests
Result...........: $krb5asrep$23$backup_user@CORP.LOCAL:...:Backup2024!
```

### Senaryo 5: Kurumsal Maske Saldırısı (Mask Attack - Mode 3)
Kurumsal ortamlarda yaygın olan `BüyükHarf + 3 KüçükHarf + 4 Rakam + 1 ÖzelKarakter` (Örn: `Ankara2026!`, `Sirket1234*`) şablonunu kırmak için maske tanımlanır.

Karakter Kümeleri:
* `?u`: Büyük harfler (A-Z)
* `?l`: Küçük harfler (a-z)
* `?d`: Rakamlar (0-9)
* `?s`: Özel karakterler (!, @, #, $, vb.)

```bash
hashcat -m 1000 -a 3 -w 3 -O /opt/hashes/ntlm.txt "?u?l?l?l?l?l?d?d?d?d?s"
```

```text
Time.Started.....: Wed Oct 14 21:47:10 2026
Time.Estimated...: Wed Oct 14 22:15:30 2026 (28 mins)
Guess.Mask.......: ?u?l?l?l?l?l?d?d?d?d?s [12]
Candidates.#1....: Mehmet1985! -> Zeynep2026*
```

### Senaryo 6: Kırılmış Parolaları Listeleme ve İnceleme (`--show`)
Daha önce kırılmış hash'lerin hangi kullanıcılara ait olduğunu potfile üzerinden eşleştirerek listeleme.

```bash
hashcat -m 1000 /opt/hashes/domain_ntlm.txt --show
```

```text
31d6cfe0d16ae931b73c59d7e0c089c0:
8846f7eaee8fb117ad06bdd830b7586c:Password123!
e19ccf750c3ba2eee95d657a40a8c438:Spring2026#
b4b9b02e6f09a9bd760f388b67351e2b:Administrator2025!
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|:---|:---|:---|
| `Token length exception` / `Line-length exception` | Hash formatı belirtilen mod (`-m`) ile uyuşmuyor veya hash dosyasında hatalı satır/boşluk vardır. | Hash dosyasını inceleyin; NTLM için 32 hex karakter, Kerberoast için `$krb5tgs$23$` başlığı olduğundan emin olun; dosyadaki fazlalıkları temizleyin. |
| `CL_OUT_OF_RESOURCES` / `CUDA_ERROR_OUT_OF_MEMORY` | GPU VRAM belleği yetersizdir veya kural dosyası çok fazla aday üreterek belleği doldurmuştur. | `-w` değerini `2` seviyesine çekin; çok büyük kural dosyalarını parça parça uygulayın veya `--segment-size` parametresini düşürün. |
| `Device #1: Temperature limit hit (90c)! Aborting...` | GPU çekirdek sıcaklığı güvenli sınırı aşmıştır; donanımı korumak için işlem durdurulmuştur. | Fan hızını manuel artırın; `-w 2` ile iş yükünü düşürün veya `--gpu-temp-abort=95` ile kritik eşiği kontrollü olarak ayarlayın. |
| `No hashes loaded` | Yüklenmek istenen tüm hash'ler zaten daha önce kırılmış ve `hashcat.potfile` içerisine yazılmıştır. | Kırılmış değerleri görmek için komutun sonuna `--show` ekleyin; sıfırdan taramak için `--potfile-disable` kullanın. |
| `Device not recognized / OpenCL not found` | Sistemde tescilli NVIDIA veya AMD GPU sürücüleri ya da OpenCL çalışma zamanı (runtime) eksiktir. | `nvidia-smi` çıktısını doğrulayın; Linux üzerinde `apt install ocl-icd-libopencl1 nvidia-cuda-toolkit` paketlerini kurun. |
| `Separator unmatched` | Hash dosyası kullanıcı adı içeriyor (`user:hash`) ancak komutta uygun format ayrıştırıcı belirtilmemiştir. | Hashcat komutuna `--username` bayrağını ekleyin (`hashcat -m 1000 --username domain_ntlm.txt ...`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
+---------------------------------------------------------------------------------------------------+
|                                 HASHCAT OPSEC VE TESPİT PROFİLİ                                   |
+---------------------------------------------------------------------------------------------------+

 [ Hedef Kurumsal Ağ / Active Directory ]
  - Ağ Trafiği: SIFIR (0 Paket)             ====> Ağ Tabanlı IDS/IPS Tespit Edemez!
  - Active Directory Olayları: SIFIR Olay   ====> Event ID 4625 (Logon Failure) ÜRETMEZ!
  - Hesap Kilitleme (Account Lockout): YOK  ====> badPwdCount Değeri Değişmez!

 [ Gerçek Risk: Hasat ve Sızıntı (Exfiltration) Aşaması ]
  - NTDS.dit Dökümü                         ====> Event ID 4662 (Directory Service Access - DCSync)
  - Kerberoast Bilet İstekleri (Toplu TGS)  ====> Event ID 4769 (Encryption: 0x17)
  - Hash Dosyalarının Ağ Dışına Çıkarılması ====> Egress DLP / DNS Tunneling Tespiti
```

### 5.1 Bırakılan İzler ve Windows Olay Günlükleri
* **Çevrimdışı İzolasyon:** Hashcat tamamen hedef ağın dışındaki saldırgan sunucusunda çalıştırıldığından hedef Active Directory üzerinde **hiçbir doğrudan olay günlüğü (Event Log) oluşturmaz**.
* **Ön Göstergeler (Pre-Cracking IOCs):** Hashcat'in kıracağı hash'lerin toplanması sırasında hedef ağda izler oluşur:
  * **Event ID 4662:** DCSync saldırısı ile replikasyon yetkilerinin kötüye kullanılması.
  * **Event ID 4769:** Kısa sürede anormal sayıda servis hesabı için `0x17` (RC4) şifrelemeli TGS biletlerinin talep edilmesi.
  * **Sysmon Event ID 11 (File Create):** Kurban sistemde `ntds.dit`, `SYSTEM` hive veya Responder `*.txt` loglarının diskte oluşturulması.

### 5.2 Ağ ve EDR İmzaları
* Hashcat ağ trafiği üretmez.
* Ancak kırılan parolalar daha sonra iç ağa karşı yatay hareket (lateral movement) veya oturum açma amacıyla kullanıldığında, `Event ID 4624` (Başarılı Oturum Açma) günlüğü oluşur.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Kullanım Amacı |
|:---|:---|:---|:---|
| **Credential Access** | `T1110.002` | Brute Force: Password Cracking | Elde edilen NTLM ve Kerberos hash'lerini çevrimdışı çözme. |
| **Credential Access** | `T1558.003` | Steal or Forge Kerberos Tickets: Kerberoasting | Toplanan TGS biletlerinin parolasını Hashcat (13100) ile kırma. |
| **Credential Access** | `T1558.004` | Steal or Forge Kerberos Tickets: AS-REP Roasting | AS-REP biletlerinin parolasını Hashcat (18200) ile kırma. |
| **Credential Access** | `T1003.003` | OS Credential Dumping: NTDS | Dökülen NTDS veritabanı hash'lerini açık metne dönüştürme. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Risk Seviyesi | Operasyonel Önlem / Kaçınma Yöntemi |
|:---|:---|:---|
| Hash Dosyalarının Sızdırılması | **YÜKSEK** | Kurban makineden çıkarılan hash dosyalarını şifreleyin (GPG/AES); düz metin dosya transferi yapmaktan kaçının. |
| Saldırgan İstasyonunda İzler | **DÜŞÜK** | Operasyon bittiğinde `hashcat.potfile` dosyasındaki hassas müşteri parolalarını güvenli şekilde silin (`shred -u`). |
| Kırılan Parolanın İlk Kullanımı | **KRİTİK** | Kırılan parola ile tek bir IP'den aniden onlarca sisteme oturum açmayın; kullanıcı davranış analitiğine (UEBA) dikkat edin. |

### 5.5 Tespit Kuralı Örnekleri (Sigma & KQL)

#### Sigma Kuralı (DCSync ve NTDS Hash Çıkarma Davranışı):
```yaml
title: Potential In-Memory Credential Dumping via DCSync
id: 7b819a02-4c22-48a1-9a71-d81b9381c110
status: production
description: Detects replication operations requesting directory secrets from non-DC hosts.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4662
    AccessMask: '0x100'
    Properties|contains:
      - '1131f6aa-9c07-11d1-f79f-00c04fc2dcd2' # DS-Replication-Get-Changes
      - '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2' # DS-Replication-Get-Changes-All
  condition: selection
level: critical
```

#### Microsoft Sentinel KQL Sorgusu:
```kusto
SecurityEvent
| where EventID == 4769
| where TicketEncryptionType == "0x17" // RC4 Kerberoast
| where ServiceName !endswith "$"
| summarize TicketCount = count(), Accounts = make_set(TargetUserName) by bin(TimeGenerated, 15m), Computer
| where TicketCount > 10
| project TimeGenerated, Computer, TicketCount, Accounts
```

#### Incident Response (IR) PowerShell Hash Döküm Tespiti:
```powershell
# NTDS dökümüne işaret eden DiskShadow veya VSS oluşturma komutlarını denetleme
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688} -MaxEvents 500 | Where-Object {
    $_.Message -match "ntdsutil|diskshadow|vssadmin"
} | Select-Object TimeCreated, @{N='Command';E={$_.Message}}
```

#### YARA Kuralı (Hashcat Hash Çıktı Dosyaları Tespiti):
```yara
rule Indicator_Hashcat_Potfile_And_Hashes {
    meta:
        description = "Detects Hashcat potfiles or exported Kerberos/NetNTLM hash dumps"
        author = "RedTeam SecOps"
        date = "2026-10-14"
    strings:
        $s1 = "$krb5tgs$23$*" ascii
        $s2 = "$krb5asrep$23$" ascii
        $s3 = "::CORP:" ascii
        $s4 = ":31d6cfe0d16ae931b73c59d7e0c089c0" ascii
    condition:
        2 of ($s*)
}
```

### 5.6 Savunma Karşılığı ve Sertleştirme
* **Karmaşık ve Uzun Parola İlkeleri (Fine-Grained Password Policy - FGPP):** Active Directory genelinde en az 15 karakter uzunluğunda parola zorunluluğu getirilmelidir. 15 karakter ve üzeri parolalar NTLM kırma maliyetini logaritmik olarak artırır.
* **Kerberoasting Savunması (AES Zorunluluğu & gMSA):** Tüm servis hesapları (SPN) Group Managed Service Accounts (gMSA) mimarisine taşınmalı, destekleyen hesaplarda RC4 şifreleme türü devre dışı bırakılmalıdır.
* **Sözlük Parolalarının Engellenmesi (Azure AD Password Protection):** Bilinen sözlük kelimeleri ve sızdırılmış parolalar şirket içi AD ortamında Active Directory Password Protection ajanı ile bloklanmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

#### 1. NTLM Hash'lerini Sözlük ve Kural ile Kırma
```bash
hashcat -m 1000 -a 0 -w 3 -O hashes.ntlm rockyou.txt -r rules/best64.rule
```
* **Ne Yapar?:** NTDS.dit'ten çıkarılan NTLM hash'lerini GPU hızlandırması ve kurallarla kırar.
* **Ne Zaman Kullanılır?:** DCSync sonrası tüm etki alanı kullanıcı parolalarını çözmek için.
* **Parametreler:** `-m 1000`, `-a 0`, `-w 3`, `-O`, `-r best64.rule`.

#### 2. NetNTLMv2 Hash'lerini Kırma
```bash
hashcat -m 5600 -a 0 -w 3 netntlmv2.txt rockyou.txt
```
* **Ne Yapar?:** Responder ile yakalanan NTLMv2 ağ kimlik doğrulamalarını sözlükle kırar.
* **Ne Zaman Kullanılır?:** LLMNR/NBT-NS veya WebDAV coerce saldırılarından hemen sonra.
* **Parametreler:** `-m 5600` (NetNTLMv2).

#### 3. Kerberoast (TGS-REP RC4) Hash'lerini Kırma
```bash
hashcat -m 13100 -a 0 -w 3 tgs_hashes.txt rockyou.txt -r rules/OneRuleToRuleThemAll.rule
```
* **Ne Yapar?:** Servis hesaplarından toplanan RC4 Kerberos biletlerini gelişmiş kuralla kırar.
* **Ne Zaman Kullanılır?:** Kerberoasting ile yetkili servis hesabı parolalarını çözmek için.
* **Parametreler:** `-m 13100` (Kerberos 5 TGS etype 23).

#### 4. AS-REP Roasting Hash'lerini Kırma
```bash
hashcat -m 18200 -a 0 -w 3 asrep.txt rockyou.txt
```
* **Ne Yapar?:** Kerberos önkimlik doğrulaması kapalı kullanıcılardan alınan AS-REP biletlerini çözer.
* **Ne Zaman Kullanılır?:** AS-REP Roasting sonrası ilk parolayı elde etmek için.
* **Parametreler:** `-m 18200` (AS-REP etype 23).

#### 5. Kurumsal Şablon İçin Maske Saldırısı Başlatma
```bash
hashcat -m 1000 -a 3 -w 3 hashes.ntlm "?u?l?l?l?l?d?d?d?s"
```
* **Ne Yapar?:** `BüyükHarf + 4 KüçükHarf + 3 Rakam + ÖzelKarakter` maskesindeki tüm olasılıkları dener.
* **Ne Zaman Kullanılır?:** Şirket çalışanlarının standart parola kalıplarını kırmak için.
* **Parametreler:** `-a 3` (maske modu), `?u?l?l...` (maske deseni).

#### 6. Kırılan Parolaları Gösterme
```bash
hashcat -m 1000 hashes.ntlm --show
```
* **Ne Yapar?:** Daha önce çözülen hash'lerin açık metin karşılıklarını ekrana listeler.
* **Ne Zaman Kullanılır?:** Kırma işlemi tamamlandıktan sonra sonuçları incelemek için.
* **Parametreler:** `--show`.

#### 7. Kırılmamış Hash'leri Ayıklama
```bash
hashcat -m 1000 hashes.ntlm --left > uncracked.ntlm
```
* **Ne Yapar?:** Potfile içinde bulunmayan, henüz kırılamamış hash'leri ayrı bir dosyaya yazar.
* **Ne Zaman Kullanılır?:** Kalan zorlu hash'ler için daha ağır kural veya maske saldırılarına geçerken.
* **Parametreler:** `--left`.

#### 8. Yarıda Kalan Kırma İşlemini Devam Ettirme
```bash
hashcat --restore
```
* **Ne Yapar?:** Elektrik kesintisi veya operatör tarafından durdurulan oturumu kaldığı noktadan sürdürür.
* **Ne Zaman Kullanılır?:** Günler süren uzun kırma operasyonlarını yeniden başlatırken.
* **Parametreler:** `--restore`.

#### 9. Kullanıcı Adı İçeren Hash Dosyalarını Kırma
```bash
hashcat -m 1000 --username domain_users_ntlm.txt rockyou.txt
```
* **Ne Yapar?:** `kullanici:hash` biçimindeki dosyaları parse ederek kullanıcı adını yok sayıp hash'i kırar.
* **Ne Zaman Kullanılır?:** secretsdump çıktısını düzenlemeden doğrudan çalıştırmak için.
* **Parametreler:** `--username`.

#### 10. Donanım Sıcaklığı ve Hızını Canlı İzleme
```bash
hashcat -m 1000 -a 0 hashes.ntlm rockyou.txt --status --status-timer 5
```
* **Ne Yapar?:** Her 5 saniyede bir GPU sıcaklığını, fan hızını ve saniyedeki kırma hızını ekrana basar.
* **Ne Zaman Kullanılır?:** GPU aşırı ısınmasını önlemek ve operasyonel performansı takip etmek için.
* **Parametreler:** `--status`, `--status-timer 5`.

---

## Kaynaklar

* [Hashcat Resmi Web Sitesi ve Deposu](https://hashcat.net/hashcat/)
* [Jens Steube (jsteube) Resmi GitHub Deposu: Hashcat](https://github.com/hashcat/hashcat)
* [Hashcat Wiki: Örnek Hash'ler ve Mod Listesi](https://hashcat.net/wiki/doku.php?id=example_hashes)
* [The Hacker Recipes: Cracking Hashes with Hashcat](https://www.thehacker.recipes/a-d/credentials/cracking)
* [HackTricks: Brute-forcing and Cracking Hashes](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/brute-force.html)
* [MITRE ATT&CK: Password Cracking (T1110.002)](https://attack.mitre.org/techniques/T1110/002/)

---

> **Önceki:** [← BOF-AD / SA-BOF (Kategori 17)](../Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/BOF-AD_SA-BOF.md) · **Sonraki:** [John the Ripper →](./John_the_Ripper.md)
