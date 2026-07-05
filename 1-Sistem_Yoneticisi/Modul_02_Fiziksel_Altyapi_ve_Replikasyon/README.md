# 🏛️ Modül 02 — Fiziksel Altyapı ve Replikasyon

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** [Modül 01](../Modul_01_Mimari_ve_Temeller/)'de kurulan **mantıksal** yapının gerçek dünyadaki karşılığını — sunucular, ağlar ve aralarındaki veri akışını — kavramak. AD'nin "nasıl ayakta ve tutarlı kaldığı" bu modülde anlaşılır.

---

## Bu modülde ne öğreneceksin?

Bir AD ortamının fiziksel omurgasını okuyabilecek ve sağlığını teşhis edebileceksin: Hangi DC nerede, istemci neden o DC'ye gidiyor, değişiklikler nasıl yayılıyor, hangi işler tek-yetkili (FSMO), ve replikasyon bozulduğunda (USN rollback, lingering object) ne yapılır.

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [02.1](./02.1_Domain_Controller_ve_Site_Topolojisi.md) | **DC ve Site Topolojisi** | DC servisleri, Site/Subnet/Site-Link, DC Locator, subnet-site eşlemesi, NO_CLIENT_SITE |
| [02.2](./02.2_Replikasyon_KCC_ve_Bridgehead.md) | **Replikasyon: KCC ve Bridgehead** | Multi-master, KCC/ISTG, intrasite vs intersite, bridgehead, USN/HWMV/UTDV, urgent replikasyon |
| [02.3](./02.3_FSMO_Rolleri.md) | **FSMO Rolleri** | 5 rol (2 forest + 3 domain), PDC Emulator & NTP hiyerarşisi, transfer vs seize |
| [02.4](./02.4_RODC_USN_Rollback_ve_Saglik.md) | **RODC, USN Rollback ve Sağlık** | RODC/PRP, USN rollback, tombstone & lingering objects, dcdiag/repadmin cephanesi |

## Önerilen okuma sırası

`02.1 → 02.2 → 02.3 → 02.4` (topoloji → replikasyon motoru → tek-yetkili roller → bütünlük & sağlık).

## Bu modülün diğer kollardaki karşılığı

Temel bir altyapı modülüdür; en güçlü çapraz bağlantılar:

- 🔴 **Red Team:** Replikasyon protokolünün kötüye kullanımı **DCSync** → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/); topoloji enumerasyonu → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); Kerberos zaman toleransı → [Red M06](../../3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/).
- 🔵 **Blue Team:** DS-Replication-Get-Changes izleme → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); DC/PDCe Tier 0 koruması → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/); DC bütünlük olay müdahalesi → [Blue M10](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki modül:** [Modül 01 — Mimari ve Temeller](../Modul_01_Mimari_ve_Temeller/)
- ➡️ **Sonraki modül:** [Modül 03 — Nesne ve Kimlik Yönetimi](../Modul_03_Nesne_ve_Kimlik_Yonetimi/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / MS-DRSR → 🎓 ADSecurity.org. Her dosya sonunda erişim tarihli kaynaklar.
