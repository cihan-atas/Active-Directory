# 🔵 Modül 09 — Tehdit Avcılığı ve Değerlendirme

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M09 — Domain Hakimiyeti ve Kalıcılık](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/)
> **Amaç:** Reaktif tespitten (M01-M08) **proaktif değerlendirmeye** geçmek — saldırganın aracıyla (BloodHound) attack path'i çizmek, risk skorunu (PingCastle) ölçmek, Tier 0'ı (Forest Druid) haritalamak ve bunları sürekli bir kapatma-döngüsüne bağlamak.

---

## Bu modülde ne öğreneceksin?

Saldırgan tekil hataya değil, hatalar zincirine bakar; savunma da öyle bakmalı ve saldırgandan önce ölçmeli. Ana ilke:

> **Saldırgandan önce attack path'i çiz ve kır. Ölçemediğini yönetemezsin. Güvenlik proje değil süreçtir — tek tarama fotoğraf, düzenli döngü filmdir.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [09.1](./09.1_BloodHound_ile_Savunma_Analizi.md) | **BloodHound (Savunma)** | Attack path grafiği, SharpHound, Cypher sorguları, kenar kırma, toplama tespiti |
| [09.2](./09.2_PingCastle_ile_Risk_Skorlama.md) | **PingCastle Risk Skorlama** | 4 kategori, 0-100 skor, bulgu→Blue kontrolü eşleme, trend |
| [09.3](./09.3_Purple_Knight_ve_Forest_Druid.md) | **Purple Knight / Forest Druid** | Tier 0 haritalama (içeriden dışarı), IoE vs IoC, kapsam kayması |
| [09.4](./09.4_Duzenli_Proaktif_Degerlendirme.md) | **Düzenli Değerlendirme Süreci** | Kapatma-döngüsü, kadans, KPI/metrik, regresyon takibi |

## Önerilen okuma sırası

`09.1 → 09.2 → 09.3 → 09.4` (attack path → genel skor → Tier 0 kapsamı → sürekli süreç). Araçlardan sürece: son dosya hepsini bağlar.

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** SharpHound keşfi → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); değerlendirmenin öngördüğü domain hakimiyeti/kalıcılık → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/); trust/hibrit riskler → [Red M10](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/).
- 🔵 **Blue Team:** Bulguların düzeltileceği kontroller — DACL/Tier [Blue M05](../Modul_05_Yetki_ve_ACL_Sikilastirma/), Kerberos [Blue M06](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/), AD CS [Blue M07](../Modul_07_AD_CS_PKI_Guvenligi/), relay [Blue M08](../Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/); tespit kapsamı [Blue 02.4](../Modul_02_SIEM_ve_Tespit_Muhendisligi/02.4_Atomic_Red_Team_ile_Dogrulama.md); IoC → IR [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- ➡️ **Sonraki:** [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/)
- 🏛️ **Sistem tabanı:** [Sistem 10.3 — Hardening](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.3_Hardening_Temelleri.md) · [Sistem 10.4 — Denetim ve Uyumluluk](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.4_Denetim_ve_Uyumluluk.md)

## Kaynak yaklaşımı

🛠️ BloodHound (SpecterOps) / PingCastle / Purple Knight-Forest Druid (Semperis) → 🏛️ Microsoft AD security best practices → 🛠️ SharpHound / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
