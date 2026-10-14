# Active Directory Projesi — Geliştirme ve Dokümantasyon Kuralları (Memory & Rules)

Bu dosya, projenin tüm modülleri ve özellikle **Modül 11 (Kırmızı Takım Araç Cephaneliği ve Komut Rehberi)** yazımında uyulması zorunlu standartları, mimari prensipleri ve hafıza notlarını içerir.

---

## 📌 Proje Genel Yapısı
- **1-Teori:** Active Directory mimarisi, kimlik doğrulama protokolleri (Kerberos, NTLM, LDAP).
- **2-Blue_Team:** Savunma, log analizi, tespit kuralları, sertleştirme.
- **3-Red_Team:** Saldırı teknikleri, sızma testleri, operasyonel cephanelik:
  - **Modul 01 - 10:** Taktik ve teknik odaklı saldırı modülleri.
  - **Modul 11 (Arac Ustaligi ve Komut Notlari):** 18 kategori ve 145 aracın kapsamlı operasyonel komut rehberi.

---

## 🎯 Modül 11 Araç Dokümantasyon Standardı (ZORUNLU HEPSİ)

Her bir araç markdown dosyası (`*.md`), istisnasız aşağıdaki 6 ana bölüm ve navigasyon yapısına sahip olmalıdır:

```markdown
# [Araç Adı]

> **Kategori:** [Kategori Numarası ve Adı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** [Tek cümlelik net operasyonel tanım].

---

## 1. Genel Bakış ve Amaç
- Aracın ne olduğu, çalışma prensibi, kullandığı protokoller (SMB, LDAP, Kerberos, RPC vb.).
- Mimari akış şeması (ASCII diyagram).
- "Neden Önemli?" ve kullanım senaryoları tablosu.
- Varsa alternatif araçlarla karşılaştırma tablosu (Örn: smbclient vs smbmap, enum4linux vs enum4linux-ng).

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)
- Genel CLI bağlantı ve çalıştırma sözdizimi.
- Desteklenen kritik bayraklar (Parametre, Açıklama, Örnek Değer tablosu).
- Modül / yetenek bazlı bayrak grupları.

## 3. Pratik Komut Örnekleri
- Gerçek dünya sızma testi senaryolarına göre gruplandırılmış kopyala-çalıştır komut blokları.
- Çıktı analizleri ve adım adım operasyon adımları.

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)
- Sahada en sık karşılaşılan hata mesajları (Access Denied, Logon Failure, Timeout, SMB Dialect Mismatch vb.).
- Neden kaynaklandığı ve kesin çözüm adımları (Tablo halinde).

## 5. OPSEC ve Karşı Tespit (IOC)
- 5.1 Bırakılan İzler (Windows Security Event ID: 4624, 4625, 5140, 5145, 1644, Sysmon vb.).
- 5.2 Ağ ve EDR İmzaları (Gürültü seviyesi, process injection izleri, user-agent).
- 5.3 MITRE ATT&CK Eşleştirmesi (Teknik ID, Teknik Adı, Kullanım).
- 5.4 OPSEC Önerileri (Risk ve Önlem tablosu).
- 5.5 Savunma Karşılığı (Blue Team bağlantıları ve sertleştirme adımları).

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)
- Operatörün sahada en sık başvuracağı 6-10 adet hazır tek satırlık komut.
- Her komut için:
  - Kod bloğu (kopyala-çalıştır)
  - **Ne Yapar?** (Net teknik açıklama)
  - **Ne Zaman Kullanılır?** (Operasyonel aşama / senaryo)
  - **Parametreler** (Kullanılan bayrakların detaylı analizi)

---

## Kaynaklar
- Resmi GitHub reposu, RFC / Microsoft protokol dokümantasyonu, MITRE linkleri.

---

> **Önceki:** [← Önceki Araç](./arac1.md) · **Sonraki:** [Sonraki Araç →](./arac2.md)
```

---

## ⚡ Yazım Kuralları
1. **Dil:** Profesyonel, teknik ve akıcı Türkçe.
2. **Derinlik:** Dosyalar özet değil; operasyonel kılavuz niteliğinde (~250-400 satır) derinlemesine yazılır.
3. **Bağlantılar:** Modül içi, Blue Team ve komşu araçlara markdown iç linkleri eksiksiz verilir.
4. **Gerçekçilik:** Tüm komutlar geçerli CLI sözdizimine ve güncel versiyonlara uygun olmalıdır.
