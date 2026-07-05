# 📁 Modül 06 — Depolama ve Dosya Servisleri

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** Kurumsal dosya hizmetlerini (namespace, replikasyon, kota/engelleme) kurmak ve AD'nin dosya-tabanlı kalbini — **SYSVOL** — anlamak. Bu modül, GPO dağıtımının fiziksel omurgasını ve dosya sunucusu güvenliğini kapsar.

---

## Bu modülde ne öğreneceksin?

Fiziksel paylaşımların önüne konan sanal isim alanını (DFS-N), kopyaları senkron tutan motoru (DFS-R), disk/güvenlik yönetimini (FSRM) ve GPO'ların yaşadığı SYSVOL'ün nasıl replike olduğunu. Ana ilke:

> **SYSVOL sağlığı = GPO tutarlılığı. DFS-R replikasyondur, yedek değildir.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [06.1](./06.1_DFS_Namespaces.md) | **DFS Namespaces** | Sanal isim alanı, domain-based vs standalone, folder target, site-farkındalıklı referral, ABE |
| [06.2](./06.2_DFS_R_Replikasyon.md) | **DFS-R Replikasyon** | Multi-master motor, RDC/staging, backlog, conflict resolution, FRS vs DFS-R, `dfsrdiag` |
| [06.3](./06.3_FSRM_Kota_ve_Dosya_Engelleme.md) | **FSRM: Kota ve Dosya Engelleme** | Hard/soft kota, file screening (ransomware azaltma), depolama raporları |
| [06.4](./06.4_SYSVOL_ve_GPO_Dagitimi.md) | **SYSVOL ve GPO Dağıtımı** | SYSVOL yapısı, FRS→DFS-R geçişi (`dfsrmig`), SYSVOL sağlığı ↔ GPO tutarlılığı |

## Önerilen okuma sırası

`06.1 → 06.2 → 06.3 → 06.4` (namespace → replikasyon → yönetim/güvenlik → SYSVOL).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** Paylaşım/SYSVOL enumerasyonu + dosya avı → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); GPP cpassword hasadı → [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); SYSVOL/GPO yazımı ile kod çalıştırma → [Red M05](../../3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/).
- 🔵 **Blue Team:** Dosya erişim & SYSVOL izleme → [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/), [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); ransomware tespiti/kurtarma → [Blue M10](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Modül 05 — DNS ve Ad Çözümleme](../Modul_05_DNS_ve_Ad_Cozumleme/)
- ➡️ **Sonraki:** [Modül 07 — PKI ve Sertifika Servisleri](../Modul_07_PKI_ve_Sertifika_Servisleri/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn → 🎓 ADSecurity.org / SpecterOps. Her dosya sonunda erişim tarihli kaynaklar.
