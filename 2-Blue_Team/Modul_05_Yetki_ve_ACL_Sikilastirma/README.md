# 🔵 Modül 05 — Yetki ve ACL Sıkılaştırma

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M05 — Yetki Yükseltme (ACL & GPO Abuse)](../../3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/)
> **Amaç:** Ayrıcalık yükseltmenin kök nedenlerini kapatmak — katman ihlali, gizli DACL yolları, GPO/delegation gevşekliği ve AdminSDHolder kalıcılığı. "Kim neye yetkili" sorusunu mimari, ACL ve denetim düzeyinde sıkılaştırır.

---

## Bu modülde ne öğreneceksin?

Yetki grup üyeliğiyle *görünür*, DACL ile *görünmez* verilir. Saldırgan görünmez yolları arar; savunma aynı grafiği çizip budar. Ana ilke:

> **GPO'ya kim yazabiliyorsa bağlı makinelerde SYSTEM'dir; bir DA hesabına GenericAll'ı olan zaten DA'dır; AdminSDHolder'a hak ekleyen kendini onaran bir arka kapı kurar.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [05.1](./05.1_Admin_Tier_Model.md) | **Admin Tier Model (0-1-2)** | Katman mimarisi, credential exposure, "Deny logon" + Silos ile teknik kilit |
| [05.2](./05.2_Tehlikeli_DACL_Denetimi_ve_Temizligi.md) | **Tehlikeli DACL Denetimi** | GenericAll/WriteDACL/DCSync hakları, attack path grafiği, BloodHound ile budama |
| [05.3](./05.3_GPO_Guvenligi_ve_Yetki_Devri_Hijyeni.md) | **GPO Güvenliği & Delegation** | GPO = uzaktan RCE, GPC/GPT DACL, en-dar-kapsam delegation |
| [05.4](./05.4_AdminSDHolder_ve_SDProp_Izleme.md) | **AdminSDHolder / SDProp** | Self-healing persistence, adminCount, orphaned hesap temizliği |

## Önerilen okuma sırası

`05.1 → 05.2 → 05.3 → 05.4` (mimari katman → gizli ACL yolları → GPO/delegation → kalıcılık noktası). Genelden özele: her dosya bir öncekinin kapatmadığı yetki yüzeyini kapatır.

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** DACL/GPO abuse ile yükseltme → [Red M05](../../3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/); AdminSDHolder kalıcılık + DCSync → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/); yükselişin başladığı yanal hareket → [Red M04](../../3-Red_Team/Modul_04_Yanal_Hareket/).
- 🔵 **Blue Team:** Kimlik doğrulama kilidi (Silos) [Blue 03.3](../Modul_03_Kimlik_Bilgisi_Korumasi/03.3_Protected_Users_ve_Authentication_Policies.md); değişim telemetrisi [Blue M01](../Modul_01_Gorunurluk_ve_Log_Yonetimi/); savunma amaçlı BloodHound/değerlendirme [Blue M09](../Modul_09_Tehdit_Avciligi_ve_Degerlendirme/); kurtarma [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Blue M04 — Yanal Hareket Tespiti](../Modul_04_Yanal_Hareket_Tespiti/)
- ➡️ **Sonraki:** [Blue M06 — Kerberos ve Delegation Sertleştirme](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/)
- 🏛️ **Sistem tabanı:** [Sistem 10.3 — Hardening](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.3_Hardening_Temelleri.md) · [Sistem 03.1 — OU/Yetki Devri](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/03.1_OU_Tasarimi_ve_Yetki_Devri.md) · [Sistem 04.1 — GPO Mimarisi](../../1-Sistem_Yoneticisi/Modul_04_Grup_Ilkeleri_GPO/04.1_GPO_Mimarisi_ve_Isleyis.md)

## Kaynak yaklaşımı

🏛️ Microsoft Securing Privileged Access / protected accounts → 🎓 ADSecurity / SpecterOps (An ACE Up the Sleeve) → 🛠️ BloodHound / Atomic Red Team / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
