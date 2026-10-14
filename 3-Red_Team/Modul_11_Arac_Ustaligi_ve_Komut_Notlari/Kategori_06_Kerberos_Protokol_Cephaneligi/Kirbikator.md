# Kirbikator

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Benjamin Delpy (@gentilkiwi) tarafından geliştirilen Kekeo cephaneliğinin bir parçası olan, Windows ortamında yerel olarak çalışan, Kerberos biletlerini dönüştürme (`.kirbi` <-> `.ccache`), çoklu bilet havuzlarını parçalama (`split`), biletleri tek dosya altında birleştirme (`merge`) ve LSA bilet yapısını manipüle etme yeteneklerine sahip yüksek performanslı C tabanlı bilet işlemcisi.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında Kerberos biletleri operatörler tarafından sürekli olarak toplanır, üretilir veya transfer edilir. Linux tarafında Impacket'in `ticketConverter.py` aracı bulunurken, Windows işletim sisteminde bağımlılıksız, saf Win32 C mimarisiyle yazılmış, Python veya .NET CLR çalıştırma zorunluluğu olmayan yerel bir bilet dönüştürme ve işleme aracına ihtiyaç duyulur.

**`Kirbikator`**, Mimikatz ve Kekeo projelerinin yaratıcısı Benjamin Delpy tarafından tam da bu operasyonel ihtiyacı karşılamak üzere geliştirilmiştir. Araç:
1. **İki Yönlü Dönüşüm:** Windows LSA / Mimikatz formatı olan `.kirbi` (RFC 4120 `KRB-CRED`) biletlerini tek bir komutla Linux uyumlu MIT Kerberos `.ccache` formatına dönüştürür ve tersi işlemi gerçekleştirir.
2. **Çoklu Bilet Parçalama (Split):** Tek bir `.ccache` dosyası içinde birden fazla kullanıcının veya servisin bileti saklanabilir. Kirbikator bu biletleri ayrıştırarak her bir bileti bağımsız bir `.kirbi` dosyasına böler.
3. **Bilet Birleştirme (Merge):** Farklı zamanlarda elde edilmiş tekil `.kirbi` biletlerini tek bir `.ccache` dosyasında konsolide eder.
4. **LSA Biçimlendirme:** Biletleri doğrudan Windows LSA önbelleğine enjekte edilmeye hazır formata getirir.

### Mimari Akış Şeması

```
[ Windows Operasyon Hostu (Kirbikator.exe) ]
       │
       ├── (1) Bilet Dönüştürme Modu (ccache <-> kirbi)
       │     ├── .kirbi  ──[Kirbikator ccache]──>  .ccache (Linux için)
       │     └── .ccache ──[Kirbikator kirbi]──>   .kirbi (Windows için)
       │
       ├── (2) Çoklu Bilet Parçalama (Split Modu)
       │     └── multi_tickets.ccache
       │           ├── [0] Administrator@krbtgt.kirbi
       │           ├── [1] svc_sql@MSSQLSvc.kirbi
       │           └── [2] workstation01$@cifs.kirbi
       │
       ├── (3) Bilet Havuzu Konsolidasyonu (Merge Modu)
       │     └── ticket1.kirbi + ticket2.kirbi ──> unified.ccache
       │
       ▼
[ Sonuç: Python veya .NET Bağımlılığı Olmadan Saf Win32 Hızı ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Bağımlılık (Native C)** | Python veya .NET Framework gerektirmez; saf Win32 ikilisidir. | Eski Windows Server 2008'den en yeni Windows 11'e kadar her ortamda doğrudan çalışır. |
| **Bilet Parçalama (Split)** | Çoklu bilet içeren Linux `.ccache` dosyalarını tekil `.kirbi` dosyalarına ayırır. | Hedef kullanıcı biletini tek başına izole edip oturuma enjekte etmeyi sağlar. |
| **Bilet Birleştirme (Merge)** | Ayrı ayrı toplanan biletleri tek bir konteyner dosyasında toplar. | Linux pivot makinelerine tek bir bilet havuzu dosyası aktarılmasını sağlar. |
| **Mimikatz ve Kekeo Uyumu** | Gentilkiwi ekosisteminin veri yapılarıyla (`kull_m_kerberos_asn1`) tam entegredir. | Mimikatz ile dump edilen biletlerin anında dönüştürülmesini sağlar. |

### Karşılaştırma Tablosu

| Kriter | Kirbikator | impacket-ticketConverter | Kekeo | Rubeus |
|---|---|---|---|---|
| **Platform** | Windows (Yerel C / Win32) | Linux (Python) | Windows (C / Win32) | Windows (.NET / C#) |
| **Çalışma Şekli** | CLI Komut Satırı | CLI Komut Satırı | İnteraktif Kabuk | CLI / Execute-Assembly |
| **Bilet Parçalama (Split)** | Var (`split`) | Yok | Var | Kısmi |
| **Bilet Birleştirme (Merge)**| Var (`merge`) | Yok | Var | Yok |
| **Python İhtiyacı** | Yok | Evet | Yok | Yok |
| **.NET İhtiyacı** | Yok | Yok | Yok | Evet (.NET CLR) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```cmd
kirbikator.exe [İŞLEM_MODU] [GİRDİ_DOSYASI] [ÇIKTI_DOSYASI]
```

### İşlem Modları ve Parametreler

| Mod / Komut | Açıklama | Örnek Kullanım |
|---|---|---|
| `ccache` | `.kirbi` formatındaki bilet(ler)i Linux MIT Kerberos `.ccache` formatına dönüştürür. | `kirbikator.exe ccache ticket.kirbi` |
| `kirbi` | `.ccache` formatındaki bilet(ler)i Windows/Mimikatz `.kirbi` formatına dönüştürür. | `kirbikator.exe kirbi ticket.ccache` |
| `lsa` | Biletin LSA uyumluluğunu denetler ve LSA önbellek enjeksiyonu için optimize eder. | `kirbikator.exe lsa ticket.kirbi` |
| `split` | Çoklu bilet içeren `.ccache` dosyasını ayrı ayrı `.kirbi` dosyalarına böler. | `kirbikator.exe split multi.ccache` |
| `merge` | Birden çok `.kirbi` dosyasını tek bir `.ccache` konteynerinde birleştirir. | `kirbikator.exe merge t1.kirbi t2.kirbi out.ccache` |
| `print` | Biletin ASN.1 yapısını ve kurban/servis başlıklarını ekrana basar. | `kirbikator.exe print ticket.kirbi` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Windows Üzerinde Tek Komutla .ccache Biletini .kirbi Formatına Çevirme

Linux saldırı makinesinden Windows C2 sunucusuna indirilen `admin.ccache` bileti, Python veya ek araç gerekmeksizin doğrudan Windows komut satırında dönüştürülür.

```cmd
kirbikator.exe kirbi admin.ccache
```

**Konsol Çıktısı Analizi:**

```text
  .#####.   kirbikator 1.0 (win32) - (c) Benjamin DELPY `gentilkiwi`
 .## ^ ##.
 ## / \ ##  /* * *
 ## \ / ##   Benjamin DELPY `gentilkiwi` ( benjamin@gentilkiwi.com )
 '## v ##'   https://blog.gentilkiwi.com/kekeo
  '#####'    * * */

* Input file   : admin.ccache
* Output type  : KIRBI
> Converting : admin.ccache -> admin.kirbi
[+] File 'admin.kirbi' successfully written!
```

```cmd
:: Alınan bilet Rubeus veya Mimikatz ile oturuma enjekte edilir:
Rubeus.exe ptt /ticket:admin.kirbi
```

---

### Senaryo 2: Mimikatz ile Dökülen Biletleri Linux ccache Formatına Çevirme

Mimikatz `sekurlsa::tickets /export` komutu ile diske kaydedilen onlarca `.kirbi` dosyasından bir tanesi Linux Impacket için dönüştürülür.

```cmd
kirbikator.exe ccache [0;3e7]-2-0-40e10000-Administrator@krbtgt-CORP.LOCAL.kirbi admin.ccache
```

**Konsol Çıktısı:**

```text
* Input file   : [0;3e7]-2-0-40e10000-Administrator@krbtgt-CORP.LOCAL.kirbi
* Output type  : CCACHE
> Converting : [0;3e7]-2-0-40e10000-Administrator@krbtgt-CORP.LOCAL.kirbi -> admin.ccache
[+] File 'admin.ccache' successfully written!
```

---

### Senaryo 3: Çoklu Bilet (Multi-Ticket) İçeren .ccache Dosyasını Parçalama (`split`)

Linux ortamından aktarılan ve içinde 5 farklı kullanıcının biletini barındıran büyük bir kimlik önbelleği dosyası (`harvested.ccache`) her bir kullanıcı için ayrı `.kirbi` dosyalarına bölünür.

```cmd
kirbikator.exe split harvested.ccache
```

**Konsol Çıktısı Analizi:**

```text
* Input file   : harvested.ccache
* Action       : SPLIT
[1] Found Ticket: CORP.LOCAL / Administrator -> krbtgt/CORP.LOCAL (Writing to 0_Administrator.kirbi)
[2] Found Ticket: CORP.LOCAL / svc_sql -> MSSQLSvc/sql01.corp.local (Writing to 1_svc_sql.kirbi)
[3] Found Ticket: CORP.LOCAL / jdoe -> cifs/dc01.corp.local (Writing to 2_jdoe.kirbi)
[+] 3 tickets successfully extracted from harvested.ccache!
```

---

### Senaryo 4: Farklı Kullanıcı Biletlerini Tek Bir ccache Dosyasında Birleştirme (`merge`)

Farklı sistemlerden toplanan biletler Linux'a aktarılmadan önce tek bir dosyada birleştirilir.

```cmd
kirbikator.exe merge da_admin.kirbi svc_backup.kirbi sql_admin.kirbi combined.ccache
```

**Konsol Çıktısı:**

```text
* Action       : MERGE
* Adding file  : da_admin.kirbi
* Adding file  : svc_backup.kirbi
* Adding file  : sql_admin.kirbi
* Output file  : combined.ccache
[+] Merged 3 tickets into 'combined.ccache'!
```

---

### Senaryo 5: Bilet Başlık ve Kimlik Bilgilerini İnceleme (`print`)

Bileti dönüştürmeden veya enjekte etmeden önce kime ait olduğunu ve hangi şifreleme türünü kullandığını görmek için:

```cmd
kirbikator.exe print test_ticket.kirbi
```

**Konsol Çıktısı:**

```text
* Input file   : test_ticket.kirbi
* Client Name  : CORP.LOCAL \ Administrator
* Service Name : krbtgt / CORP.LOCAL
* EncType      : 18 (AES-256-CTS-HMAC-SHA1-96)
* Flags        : 0x40a00000 (Forwardable, Renewable)
* Validity     : 2026/04/14 16:30 -> 2026/04/15 02:30
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `kull_m_kerberos_asn1_helper error (0x80090308)` | Bilet ASN.1 DER yapısı bozuk veya eksik bayt içermektedir. | Dosyanın tam indirildiğini teyit edin; dosya boyutu 0 byte ise yeniden dışa aktarın. |
| `Unsupported container version` | Bilet dosyası MIT Kerberos ccache v1, v2 veya v3 sürümündedir (Kirbikator v4 bekler). | Linux sisteminde `klist` veya `kinit` ile güncel sürüm bilet üretin. |
| `Architecture mismatch (x86 vs x64)` | 64-bit Windows işletim sisteminde 32-bit `kirbikator.exe` çalıştığında bellek adresleme hataları. | Sistem mimarisine uygun sürümü (`x64\kirbikator.exe`) çalıştırın. |
| `Access Denied creating output file` | Çıktı dosyasının yazılmak istendiği dizinde yerel kullanıcı yazma yetkisine sahip değil. | Çıktı yolunu `C:\Users\Public\` veya `C:\Windows\Temp\` olarak belirtin. |
| `Missing Session Key in KRB-CRED` | Bellekten döküm alınırken oturum anahtarı LSA tarafından korunmuş (PPL koruması). | LSASS dökümü alırken PPL baypas araçlarını (`PPLMedic` / `PPLKiller`) kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK (HOST BAZLI STATİK İMZALAR)
──────────────────────────────────────────────────────────────────
[ Ağ Trafiği ]      : Sıfır paket (Dönüşüm tamamen çevrimdışı)
[ Windows Logları ] : KDC logu YOKTUR (Yalnızca bilet kullanıldığında Event 4624)
[ Disk İzleri ]     : Diske yazılan .kirbi ve .ccache dosyaları
[ EDR / AV ]        : Benjamin Delpy imza desenleri (Gentilkiwi stringleri)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Statik Dosya İmzaları:**
   - Benjamin Delpy ikilileri (`kekeo`, `mimikatz`, `kirbikator`) antivirüs ve EDR motorlarının statik imza veritabanlarında (YARA kuralları) ilk sıralarda yer alır.
   - Derlenmiş orijinal `kirbikator.exe` diske bırakıldığı anda Microsoft Defender veya kurumsal EDR tarafından karantinaya alınabilir.
2. **DFIR Dosya Artefaktları:**
   - Diskte oluşturulan `*.kirbi` ve `*.ccache` dosyaları olay müdahale ekiplerine bilet hırsızlığı yapıldığını kanıtlar.

### 5.2 Ağ ve EDR İmzaları

- **Sıfır Ağ İmzası:** Araç hiçbir TCP/UDP soketi açmaz; KDC'ye hiçbir paket göndermez.
- **Bellek İmzaları:** İkili dosyanın içindeki `gentilkiwi`, `kekeo` ve `kull_m_kerberos` dizgileri bellek tarayıcıları tarafından tespit edilebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1550.002** | Use Alternate Authentication Material: Pass the Ticket | Biletleri platformlar arası taşıyarak oturum enjeksiyonuna hazırlama. |
| **T1078** | Valid Accounts: Domain Accounts | Meşru kullanıcı biletlerini dönüştürerek kimlik doğrulamada kullanma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Bilinen İkili (EXE) İmzası** | Orijinal `kirbikator.exe` ikilisini kullanmayın. Kaynak kodunu yeniden derleyin (String obfuscation uygulayın, yazar bilgilerini temizleyin). |
| **Diske Dosya Bırakma** | Bilet dönüşümünü Windows diski yerine Linux tarafında (`impacket-ticketConverter`) yaparak Windows'a yalnızca bellek içi Base64 bilet aktarın. |
| **Geçici Dosya Hijyeni** | Dönüşüm sonrasında diskte kalan bilet dosyalarını `sdelete` veya PowerShell sıfırlama döngüleriyle güvenli silin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Kirbikator İkilisinin Çalıştırılması Tespiti:**

```yaml
title: Kirbikator Kerberos Tool Execution
status: experimental
description: Detects execution of Kirbikator or Kekeo ticket transformation tool based on image or commandline.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4688
  process_match:
    NewProcessName|endswith: 'kirbikator.exe'
  cmdline_match:
    CommandLine|contains:
      - 'kirbi'
      - 'ccache'
      - 'split'
      - 'merge'
  condition: selection and (process_match or cmdline_match)
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli Bilet Dönüşüm Aktivitesi:**

```kql
SecurityEvent
| where EventID == 4688
| where CommandLine has_any ("kirbikator", "kekeo") or (CommandLine has "ccache" and CommandLine has "kirbi")
| project TimeGenerated, Computer, SubjectUserName, NewProcessName, CommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: .ccache Biletini .kirbi Formatına Çevirme
```cmd
kirbikator.exe kirbi ticket.ccache
```
- **Ne Yapar?** Linux formatındaki bilet önbelleğini Windows uyumlu `.kirbi` dosyasına dönüştürür.
- **Ne Zaman Kullanılır?** Linux'tan Windows'a aktarılan bileti Mimikatz veya Rubeus ile kullanmak için.
- **Parametreler:** `kirbi`: Dönüştürme modu, `ticket.ccache`: Girdi dosyası.

### Komut 2: .kirbi Biletini .ccache Formatına Çevirme
```cmd
kirbikator.exe ccache ticket.kirbi
```
- **Ne Yapar?** Windows'tan dökülen bilet dosyasını Linux Impacket araçlarının kullanabileceği `.ccache` formatına dönüştürür.
- **Ne Zaman Kullanılır?** Windows'ta çalınan bilet ile Linux üzerinde secretsdump veya wmiexec çalıştırmak için.
- **Parametreler:** `ccache`: Dönüştürme modu, `ticket.kirbi`: Girdi dosyası.

### Komut 3: Çoklu Bilet Dosyasını Parçalama (Split)
```cmd
kirbikator.exe split multi.ccache
```
- **Ne Yapar?** Birden fazla kullanıcının biletini barındıran `.ccache` dosyasındaki tüm biletleri ayrı ayrı `.kirbi` dosyalarına ayıklar.
- **Ne Zaman Kullanılır?** Toplu bilet havuzundan belirli bir Domain Admin biletini izole etmek için.
- **Parametreler:** `split`: Parçalama komutu.

### Komut 4: Birden Çok Bilet Dosyasını Tek Dosyada Birleştirme (Merge)
```cmd
kirbikator.exe merge t1.kirbi t2.kirbi t3.kirbi all.ccache
```
- **Ne Yapar?** Ayrı ayrı toplanan 3 farklı `.kirbi` biletini tek bir `.ccache` dosyası içinde toplar.
- **Ne Zaman Kullanılır?** Çoklu bilet koleksiyonunu Linux saldırı makinesine tek dosya halinde aktarmak için.
- **Parametreler:** `merge`: Birleştirme komutu, son parametre çıktı dosyasıdır.

### Komut 5: Bilet Detaylarını ve Geçerlilik Süresini İnceleme (Print)
```cmd
kirbikator.exe print admin.kirbi
```
- **Ne Yapar?** Biletin kime ait olduğunu, hangi SPN için düzenlendiğini, şifreleme türünü ve son geçerlilik tarihini ekrana basar.
- **Ne Zaman Kullanılır?** Bileti oturuma enjekte etmeden önce geçerliliğini teyit etmek için.
- **Parametreler:** `print`: Ekrana döküm komutu.

### Komut 6: Özel Çıktı Dosya Adı ile Dönüştürme
```cmd
kirbikator.exe ccache input.kirbi custom_name.ccache
```
- **Ne Yapar?** Dönüştürülen biletin hedef dosya adını açıkça belirler.
- **Ne Zaman Kullanılır?** Otomasyon betiklerinde dosya isimlerini standartlaştırmak için.
- **Parametreler:** İlk girdi dosyası, ikinci çıktı dosyası.

### Komut 7: LSA Optimizasyonu ile Bilet Hazırlama
```cmd
kirbikator.exe lsa admin.kirbi
```
- **Ne Yapar?** Biletin Windows LSA tarafından sorunsuz kabul edilmesi için başlık ve bayrak yapılarını optimize eder.
- **Ne Zaman Kullanılır?** Bilet enjeksiyonu sırasında `0xc0000022` veya format hatası alındığında.
- **Parametreler:** `lsa`: LSA hazırlama modu.

### Komut 8: Klasördeki Tüm Biletleri Toplu Dönüştürme (CMD For Döngüsü)
```cmd
for %f in (*.kirbi) do kirbikator.exe ccache "%f"
```
- **Ne Yapar?** Bulunulan dizindeki tüm `.kirbi` dosyalarını tek hamlede `.ccache` dosyalarına dönüştürür.
- **Ne Zaman Kullanılır?** Mimikatz ile dump edilen onlarca bileti Linux için hazır hale getirirken.
- **Parametreler:** Windows CMD batch döngüsü.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Gentilkiwi / Kekeo](https://github.com/gentilkiwi/kekeo)
- **Benjamin Delpy Blog:** [Kekeo & Kerberos Manipulations](https://blog.gentilkiwi.com/)
- **RFC 4120 Standardı:** [The Kerberos Network Authentication Service (V5)](https://datatracker.ietf.org/doc/html/rfc4120)
- **SpecterOps:** [Kerberos Interoperability: Windows vs Linux Formats](https://posts.specterops.io/)

---

> **Önceki:** [← TGSTomp](./TGSTomp.md) · **Sonraki:** [Mimikatz (Kategori 07) →](../Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Mimikatz.md)
