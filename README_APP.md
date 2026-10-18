# 📱 Active Directory Vault — Çevrimdışı Mobil (APK) ve Web Platformu

Active Directory siber güvenlik (Red Team, Blue Team ve Sistem Yöneticisi) bilgi tabanını ve **Modül 11 (146 Araçlık Kırmızı Takım Cephaneliği)** içeriğini **%100 çevrimdışı (offline)** olarak mobil cihazlarda ve web tarayıcısında kullanmanızı sağlayan kapsamlı siber güvenlik çalışma ve operasyon platformu.

---

## 🚀 Yeni Eklenen Gelişmiş Özellikler (mitre-app Mimarisi)

1. **Öğrenme ve Okuma İlerlemesi (Hero Progress Tracker):**
   - Ana sayfada "Kaldığın Yerden Devam Et" kartı ve anlık ilerleme çubuğu (%X tamamlandı).
   - Her makale sayfasında tek dokunuşla **"Okundu Olarak İşaretle"** (✓) özelliği.
   - 4 Siber Metrik Sayacı: Okunan Konu Sayısı, Cephanelik Araçları, Ustalaşılan Kartlar, Kayıtlı Yer İmleri.

2. **Sesli Okuma Motoru (TTS — Text-to-Speech):**
   - Makale sayfalarında tek dokunuşla sesli dinleme (🔊).
   - Ekranın altında yapışkan **Floating TTS Player Bar**: Oynat, Duraklat, Durdur, Okunan Başlık ve Hız Ayarı (0.75x, 0.9x, 1.0x, 1.25x).
   - Markdown temizleyici filtre: Kod blokları ve işaretleme etiketlerini konuşma diline uyarlayarak pürüzsüz dinleme sağlar.

3. **Active Directory Flashcards & Akıllı Kartlar (SRS):**
   - Leitner kutuları (Box 1-5) ve 3D kart çevirme (Flip) animasyonu.
   - Özenle hazırlanmış 3 kategori:
     - 🔍 **Event ID & Loglar:** 4624 (Logon Type 3), 4625, 4768, 4769, 5145, Sysmon 10 vb.
     - ⚔️ **Araçlar & Komutlar:** Mimikatz DCSync, Rubeus Kerberoast, Certipy Find, Impacket vb.
     - 🔑 **AD Kavramları & Haklar:** RBCD, Golden/Silver Ticket, AdminSDHolder, Shadow Credentials vb.

4. **Saldırı Zinciri Senaryoları (Kill Chain Simulator):**
   - Gerçek dünya Active Directory sızma testi senaryoları:
     - *1. Standart Kullanıcıdan Domain Admin'e (AS-REP -> Kerberoast -> DCSync)*
     - *2. RBCD ile Hedef Sunucuda SYSTEM Yetkisi Ele Geçirme*
     - *3. AD CS ESC1 Zafiyeti ile Anında Domain Admin*
     - *4. PetitPotam ve NTLM Relay ile DC Sertifikası Çıkarma*
     - *5. GPO ve Zamanlanmış Görev İstismarı ile Kalıcılık (Persistence)*
   - Her senaryoda aşama aşama taktikler, araçlar, kopyalanabilir komutlar ve tespit Event ID'leri.

5. **Active Directory Terimler Sözlüğü (Glossary):**
   - Kerberos, KDC, TGT, TGS, PAC, SPN, RBCD, DACL, SACL, LAPS, gMSA, NTDS.dit, Shadow Credentials, PtH, Overpass-the-Hash vb. 30+ kritik kavramın operasyonel tanımları ve güvenlik etkileri.

6. **Günün Odak Noktası (Daily Spotlight):**
   - Her gün deterministik olarak otomatik değişen "Günün Saldırı Tekniği / Aracı" ve "Günün Savunma / Event ID Kuralı".

7. **İsteğe Bağlı AI Siber Güvenlik Asistanı (✨):**
   - Varsayılan olarak %100 çevrimdışıdır (Zero-Network).
   - Kullanıcı Google Gemini (`AIza...`), Groq (`gsk_...`) veya OpenRouter (`sk-or-...`) API anahtarı girdiğinde otomatik sağlayıcı tespitiyle aktifleşir:
     - 💡 "Bu Bölümü Basitçe Açıkla"
     - ⚡ "Komut & Saldırı Analizi Yap"
     - 🛡️ "Tespit & Savunma Kuralı Yaz"
     - 💬 "Doküman Hakkında Serbest Soru Sor"

---

## 🛠️ Hızlı Derleme ve Kullanım

```bash
# Android APK Derleme (Varsayılan):
./build.sh
# veya
./build.sh --apk

# Web Sürümünü Derleme:
./build.sh --web

# Kullanım Kılavuzu:
./build.sh --help
```

- **Android APK Çıktısı:** `dist/ActiveDirectory_Handbook.apk`
- **Web Sürümü Çıktısı:** `dist/web/`

### Cihaza Yükleme
```bash
adb install -r dist/ActiveDirectory_Handbook.apk
```
veya yerel ağ üzerinden telefona indirmek için:
```bash
python3 -m http.server -d dist 8080
```
Telefon tarayıcısından: `http://<bilgisayar_ip>:8080/ActiveDirectory_Handbook.apk`
