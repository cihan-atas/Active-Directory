# 🗂️ Modül 01 — Mimari ve Temeller (Kalenin Planı)

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** Active Directory'nin mantıksal iskeletini — bir kaleyi taşıyan temel taşları — kavramak. Bu modül tüm programın zeminidir; sonraki her modül buradaki kavramlara dayanır.

---

## Bu modülde ne öğreneceksin?

Bir AD ortamına baktığında "bu neden böyle kurulmuş, sınırlar nerede, kim neye hükmediyor?" sorularını yanıtlayabileceksin. Özellikle tüm mimarinin dayandığı tek ilkeyi içselleştireceksin:

> **Domain bir yönetim sınırıdır; forest ise güvenlik sınırıdır.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [01.1](./01.1_Mantiksal_Hiyerarsi.md) | **Mantıksal Hiyerarşi** | Forest / Tree / Domain / OU, yönetim vs. güvenlik sınırı, DN/GUID/SID ile adresleme |
| [01.2](./01.2_Schema_Global_Catalog_Partitionlar.md) | **Schema, Global Catalog, Partition'lar** | AD'nin sözlüğü (schema), naming context'ler ve replikasyon kapsamları, GC'nin 4 görevi |
| [01.3](./01.3_Fonksiyon_Seviyeleri.md) | **Fonksiyon Seviyeleri** | DFL/FFL, sürüm-özellik haritası, yükseltme kuralları ve geri-alınamazlık |
| [01.4](./01.4_Trust_Iliskileri.md) | **Trust İlişkileri** | Trust türleri/yön/geçişlilik, TDO, SID filtering & selective authentication |

## Önerilen okuma sırası

`01.1 → 01.2 → 01.3 → 01.4` (her dosya bir öncekine dayanır).

## Bu modülün diğer kollardaki karşılığı

Bu bir *temel* modülüdür; doğrudan simetrik bir Red/Blue modülü yoktur, ama şu bağlantılar kritiktir:

- 🔴 **Red Team:** Mantıksal yapı enumerasyonu → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); forest/trust sınırlarının saldırıda kullanımı → [Red M10](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/).
- 🔵 **Blue Team:** Forest root / Tier 0 koruması ve trust hijyeni → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/) ve [Blue M09](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/).
- ➡️ **Sonraki modül:** [Modül 02 — Fiziksel Altyapı ve Replikasyon](../Modul_02_Fiziksel_Altyapi_ve_Replikasyon/) (mantıksal yapının fiziksel karşılığı).

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: önce 🏛️ Microsoft Learn / MS-ADTS, sonra 🎓 ADSecurity.org gibi uzman kaynaklar. Her dosyanın sonunda erişim tarihli kaynak listesi vardır.
---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu dokümanda açıklanan Active Directory mimarisi, nesne yönetimi, replikasyon ve sistem yapılandırmaları; **kurumsal altyapıların en iyi uygulamalar (Best Practices) doğrultusunda güvenle yönetilmesi** amacıyla hazırlanmıştır.
>
> Üretim ortamlarında uygulanacak yapılandırmalar öncesinde mutlaka tam yedekleme (System State / NTDS) alınmalı ve değişiklikler yetkili değişim yönetimi prosedürlerine uygun olarak icra edilmelidir.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [Microsoft Learn — Windows Server Documentation](https://learn.microsoft.com/en-us/windows-server/): Active Directory Domain Services resmi teknik rehberi.
- 🌐 [Microsoft Open Specifications](https://learn.microsoft.com/en-us/openspecs/windows_protocols/): MS-ADTS, MS-DRSR, MS-KILE protokol standartları.
- 🌐 [InternalAllTheThings — Active Directory Architecture](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/): Mimari şablonlar ve operasyonel notlar.
