# 📜 Modül 04 — Grup İlkeleri / GPO (Kalenin Kanunları)

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** Binlerce kullanıcı ve bilgisayarın yapılandırmasını ve sertleştirmesini merkezî, kurallı ve denetlenebilir biçimde yönetmek. GPO, hem operasyonun hem de güvenlik baseline'ının uygulanma motorudur — ve aynı zamanda güçlü bir saldırı yoludur.

---

## Bu modülde ne öğreneceksin?

Bir ayarın nerede saklandığını (GPC/GPT), hangi sırayla ve hangi istisnalarla uygulandığını (LSDOU/Enforced/Block), nasıl ince hedeflendiğini (Security/WMI/ILT), pratikte neyin yapıldığını (güvenlik/ADMX/GPP) ve "uygulanmıyor" dendiğinde nasıl teşhis edileceğini. Ana ilke:

> **Link kapsar, LSDOU sıralar, filtreleme daraltır, RSoP gerçeği söyler.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [04.1](./04.1_GPO_Mimarisi_ve_Isleyis.md) | **Mimari ve İşleyiş** | GPC/GPT, Computer/User, LSDOU, Enforced/Block, Loopback, refresh & slow link |
| [04.2](./04.2_Hedefleme_ve_Filtreleme.md) | **Hedefleme ve Filtreleme** | Security Filtering (MS16-072!), WMI Filter, Item-Level Targeting |
| [04.3](./04.3_Pratik_Uygulamalar_ADMX_GPP.md) | **Pratik: Güvenlik/ADMX/GPP** | Güvenlik ayarları, Central Store, GPP ve **cpassword zafiyeti (MS14-025)** |
| [04.4](./04.4_Sorun_Giderme_ve_Analiz.md) | **Sorun Giderme ve Analiz** | Teşhis zinciri, `gpresult`, RSoP, GPMC Results vs Modeling, yedekleme |

## Önerilen okuma sırası

`04.1 → 04.2 → 04.3 → 04.4` (mekanizma → hedefleme → uygulama → teşhis).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** GPO/SYSVOL enumerasyonu + GPP cpassword → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/), [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); GPO düzenleme yetkisiyle SYSTEM kod çalıştırma → [Red M05](../../3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/).
- 🔵 **Blue Team:** Denetim/log politikası → [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/); GPO değişiklik izleme → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); LAPS (GPP'nin doğru alternatifi) → [Blue M03](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/); baseline/Tier dayatma → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/); protokol sertleştirme → [Blue M08](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/).
- ⬅️ **Önceki:** [Modül 03 — Nesne ve Kimlik Yönetimi](../Modul_03_Nesne_ve_Kimlik_Yonetimi/)
- ➡️ **Sonraki:** [Modül 05 — DNS ve Ad Çözümleme](../Modul_05_DNS_ve_Ad_Cozumleme/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / MS bültenleri → 🎓 ADSecurity.org / SpecterOps. Her dosya sonunda erişim tarihli kaynaklar.
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
