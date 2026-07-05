# 🔵 Modül 01 — Görünürlük ve Log Yönetimi

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M01 — Keşif ve Numaralandırma](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/)
> **Amaç:** Savunmanın **sıfırıncı adımı** — görünürlük. Bu modül, "olan biteni gören, kaydeden, kalıcılaştıran ve aranabilir kılan" telemetri altyapısını kurar. Sonraki her Blue modülü (tespit, avcılık, DFIR) bu ham maddeyi tüketir.

---

## Bu modülde ne öğreneceksin?

Göremediğini savunamazsın. Bu modül dört katmanı kurar: olayı **üret** → merkeze **taşı** → **derinleştir** → **sakla/normalleştir**. Ana ilke:

> **Log yerelde kalırsa saldırgan siler. Üretilmeyen olay yoktur; normalleştirilmeyen log aranamaz; saklanmayan log soruşturulamaz.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [01.1](./01.1_Windows_Event_Forwarding_WEF.md) | **Windows Event Forwarding (WEF)** | Source-Initiated abonelik, Kerberos/HTTPS taşıma, merkezî toplama, 1102 iz-silme tespiti |
| [01.2](./01.2_Advanced_Audit_Policy.md) | **Advanced Audit Policy** | Basic↔Advanced çakışması, kritik alt kategoriler, Event ID kataloğu, 4688 komut satırı, 4719 |
| [01.3](./01.3_Sysmon_ile_Derin_Telemetri.md) | **Sysmon ile Derin Telemetri** | EID 1/3/10 vb., LSASS erişim tespiti, parent-process ağacı, config gürültü kontrolü |
| [01.4](./01.4_Log_Toplama_Saklama_Normalizasyon.md) | **Toplama, Saklama, Normalizasyon** | Pipeline, ECS/ASIM şema eşleme, retention/immutable, kaynak-sessizliği tespiti |

## Önerilen okuma sırası

`01.1 → 01.2 → 01.3 → 01.4` (taşı → üret → derinleştir → sakla). Kavramsal olarak "üret"ten önce "taşı"yı görmek, neden merkezîleştirdiğimizi netleştirir.

## Bu modülün diğer kollardaki karşılığı

Bu modül, Sistem kolunun denetim temelini ([Sistem 10.4](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.4_Denetim_ve_Uyumluluk.md)) operasyonel bir SOC pipeline'ına dönüştürür.

- 🔴 **Red Team:** Bu telemetrinin yakaladığı keşif/enumerasyon → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); LSASS/kimlik hırsızlığı izleri → [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); telemetri körleştirme/iz temizleme → [Red M10](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/).
- 🔵 **Blue Team (devamı):** Bu ham veri → tespit mühendisliği [Blue M02](../Modul_02_SIEM_ve_Tespit_Muhendisligi/); kimlik koruması [Blue M03](../Modul_03_Kimlik_Bilgisi_Korumasi/); tehdit avcılığı [Blue M09](../Modul_09_Tehdit_Avciligi_ve_Degerlendirme/); DFIR/kurtarma [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Sistem tabanı:** [Sistem 10.4 — Denetim ve Uyumluluk](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.4_Denetim_ve_Uyumluluk.md)
- ➡️ **Sonraki modül:** [Blue M02 — SIEM ve Tespit Mühendisliği](../Modul_02_SIEM_ve_Tespit_Muhendisligi/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / Sysinternals → 🎓 NSA-CISA / SwiftOnSecurity / Elastic ECS → 🛠️ Palantir WEF / Atomic Red Team. Her dosya sonunda erişim tarihli kaynaklar.
