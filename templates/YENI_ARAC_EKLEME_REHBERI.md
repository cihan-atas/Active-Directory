# 🚀 Yeni Araç ve Komut Ekleme Rehberi (Otomatik Derleme & Senkronizasyon)

Bu rehber, Active Directory projesine yeni bir araç dokümanı veya operasyonel komut eklendiğinde sistemin bunu **nasıl %100 otomatik olarak algıladığını**, derleme sürecinin nasıl çalıştığını ve geliştiricinin/araştırmacının uyması gereken şablon kurallarını açıklar.

---

## ⚡ 1. Temel İlke: Sıfır Manuel Müdahale

Projemizdeki hibrit mimari sayesinde:
- ❌ **Asla** Flutter/Dart koduna (`command_generator_screen.dart`, `command_service.dart` vb.) elle yeni komut yazılmaz.
- ❌ **Asla** `commands_catalog.json` dosyası elle düzenlenmez.
- ✅ Tüm komutlar, parametreler, OPSEC imzaları ve operasyonel açıklamalar doğrudan **Markdown (`.md`)** dokümanlarından dinamik olarak çekilir.
- ✅ `./build.sh` (veya `--web`, `--apk`, `--sync-only`) çalıştırıldığı anda tüm dokümanlar taranır, sözdizimi ayrıştırılır ve Komut Oluşturucu kütüphanesine otomatik eklenir.

```text
+------------------------------------+
|  1-Sistem_Yoneticisi/*.md          |
|  2-Blue_Team/*.md                  |
|  3-Red_Team/**/*.md                |
+------------------------------------+
                  │
                  ▼  (./build.sh veya --sync-only)
+------------------------------------+
| scripts/build_content.py           | ──> content_index.json (Tüm Makaleler & Arama)
| scripts/extract_commands.py        | ──> commands_catalog.json (3.300+ Canlı Komut)
+------------------------------------+
                  │
                  ▼
+------------------------------------+
| Flutter Uygulaması (Mobil & Web)   |
| • Komut Oluşturucu                 |
| • Parametre & Bayrak Analizi       |
| • Dinamik Değişken Entegrasyonu    |
+------------------------------------+
```

---

## 🛠️ 2. Yeni Araç Ekleme Adımları

### Adım 1: Şablonu Kopyalayın
[`templates/ARAC_SABLONU.md`](./ARAC_SABLONU.md) dosyasını kopyalayın ve hedef modül klasörüne yapıştırın.

Örnek (Modül 11 içinde yeni bir araç için):
```bash
cp templates/ARAC_SABLONU.md 3-Red_Team/11-Arac_Katalogu/03-Kerberos_Saldirilari/yeni_arac.md
```

### Adım 2: Dokümanı Doldurun
Dokümanı [`GEMINI.md`](../GEMINI.md) standartlarına uygun 6 bölümle doldurun:
1. **Genel Bakış ve Amaç** (ASCII şeması ve protokol açıklamaları)
2. **Temel Sözdizimi ve Parametreler (CLI Flags)** (Komut kalıbı ve bayrak tablosu)
3. **Pratik Komut Örnekleri** (Senaryo bazlı komutlar)
4. **Karşılaşılan Hatalar ve Çözümleri** (Troubleshooting tablosu)
5. **OPSEC ve Karşı Tespit** (Event ID, EDR ve MITRE ATT&CK eşleştirmesi)
6. **En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)** (Hızlı referans komutları)

> 💡 **İpucu:** Bölüm 6'daki komutlar için `**Ne Yapar?**`, `**Ne Zaman Kullanılır?**` ve `**Parametreler:**` başlıklarını eksiksiz yazarsanız; Komut Oluşturucu bu bilgileri otomatik olarak canlı analiz kartlarına dönüştürür.

### Adım 3: Senkronizasyonu Çalıştırın
Herhangi bir derleme yapmadan, yalnızca komutların ve makalelerin güncellenmesini sağlamak için:

```bash
./build.sh --sync-only
```

Konsol çıktısında çıkarılan toplam komut sayısını, taranan yeni dosyayı ve doğrulama raporunu göreceksiniz:
```text
📚 Markdown Konuları ve Cephanelik Taranıyor...
...
🎯 [3/3] Çıkarım Tamamlandı!
   • Taranan Toplam Doküman : 268
   • Çıkarılan Canlı Komut  : 3.385+
   • Çevrimdışı Katalog     : app/assets/data/commands_catalog.json
```

### Adım 4: Canlı Test Edin
- **Web Ortamında Test:**
  ```bash
  ./build.sh --web
  python3 -m http.server -d dist/web 8080
  ```
  Tarayıcınızda `http://localhost:8080` adresini açıp **Komut Oluşturucu** ekranında yeni aracınızı aratın.
- **Android APK Derleme:**
  ```bash
  ./build.sh --apk
  ```
  `dist/ActiveDirectory_Handbook.apk` dosyasını telefonunuza veya emülatöre yükleyin (`adb install -r dist/ActiveDirectory_Handbook.apk`).

---

## 🔍 3. Komut Ayrıştırıcının (Extractor) Özellikleri

Gelişmiş motorumuz ([`scripts/extract_commands.py`](../scripts/extract_commands.py)) şunları otomatik olarak gerçekleştirir:

1. **Komut Temizleme (Prompt Stripping):**  
   Dokümanda `C:\Tools>`, `PS C:\>`, `root@kali:~#`, `rpcclient $>`, `beacon>` gibi terminal promptları bulunsa bile bunları temizleyerek saf komuta dönüştürür.
2. **Dinamik Değişken Tespiti:**  
   `<DC_IP>`, `<HEDEF_IP>`, `<DOMAIN>`, `<KULLANICI>`, `<HASH>` gibi yer tutucuları tespit eder ve kullanıcının arayüzde değiştirebileceği değişken kutucuklarına bağlar.
3. **Akıllı Bayrak Analizi:**  
   - `-u`, `-p`, `-d`, `-H`, `-k` gibi bayrakları ayırt eder.
   - `-p` tek başına ise `"Paylaşılan yazıcıları sorgula"` veya `"Üst dizin oluştur"`, ardından değer geliyorsa `"Kimlik doğrulama parolası"` olduğunu akıllıca anlar.
   - Linux dosya yollarını (`/opt/loot`, `/tmp`) ve PowerShell operatörlerini (`-eq`, `-ne`, `-like`) bayrak hatası olarak algılamaz.
4. **OPSEC & Olay Günlüğü Zenginleştirmesi:**  
   Dokümanın Bölüm 5'inde belirtilen Windows Security Event ID'lerini (4624, 4625, 4768, 4769, 5140 vb.) komut kartlarına otomatik ilişkilendirir.

---

## 📌 4. Sıkça Sorulan Sorular

### Soru: Var olan bir komutu değiştirdiğimde veya sildiğimde ne olur?
**Cevap:** İlgili `.md` dosyasını düzenleyip `./build.sh` (veya `./build.sh --sync-only`) çalıştırdığınızda, eski komut silinir veya güncellenir. Tamamen senkronize çalışır.

### Soru: Dokümandaki komut başlığını nasıl yazmalıyım?
**Cevap:** Bölüm 6 altında:
```markdown
### 1. Komut Başlığı
```bash
komut --bayrak deger
```
**Ne Yapar?**
Operasyonel açıklama...
**Ne Zaman Kullanılır?**
Hangi senaryoda kullanılacağı...
**Parametreler:**
- `-bayrak`: Açıklaması...
```
Formatını kullandığınızda en zengin görsel kart deneyimi elde edilir.
