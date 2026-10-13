# Katkı Sağlama Rehberi (Contributing Guide)

**Active Directory Ustalık Programı** projesine katkıda bulunmak istediğiniz için teşekkür ederiz! Bu kılavuz, depoya içerik veya kod eklerken uyulması gereken standartları belirler.

---

## 1. Temel Prensipler

1. **Üç Kol Simetrisi:**
   * Sistem Mimarisi, Mavi Takım (Savunma) ve Kırmızı Takım (Tehdit Analizi) kollarının birbirine çapraz referans vermesi esastır. Bir zafiyet ele alındığında, mutlaka karşılık gelen tespit Event ID'si ve sertleştirme adımı da sunulmalıdır.
2. **Derinlik Standardı:**
   * Konular yüzeysel olmamalı; kavramsal temel, protokol mimarisi, kopyalanıp çalıştırılabilir komutlar/kodlar ve kaynaklar eksiksiz yer almalıdır.
3. **Etik ve Yasal Sorumluluk:**
   * İçerikler yalnızca yetkili güvenlik testleri, savunma mühendisliği ve eğitim amaçlıdır.

---

## 2. Dosya İsimlendirme ve Bağlantı Kuralları

* **Dosya Adları:** `<modul>.<sira>_<Konu_Adi>.md` biçiminde, Türkçe karaktersiz ve alt tire (`_`) ile yazılmalıdır (Örn: `01.1_LDAP_Enumerasyonu.md`).
* **Çapraz Referanslar:** Diğer modüllere verilen tüm linkler tıklanabilir göreli Markdown bağlantısı olmalıdır (Örn: `[Blue M01](./2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)` veya modül içinden `../../2-Blue_Team/...`).
* **Diyagramlar:** Her konuda akışı kolaylaştıran en az bir ASCII veya Mermaid diyagramı yer almalıdır.

---

## 3. Katkı Adımları (Pull Request Süreci)

1. Depoyu forklayın (`fork`) ve yeni bir özellik dalı (`feature/yeni-konu`) açın.
2. Değişikliklerinizi yapın ve göreli linklerin çalıştığını doğrulayın.
3. Anlaşılır bir commit mesajı ile PR (Pull Request) gönderin.
