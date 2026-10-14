# 🛡️ Modül 10 — Güvenlik, Yedekleme ve Kurtarma (Kalenin Zırhı)

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** Kurulan altyapıyı **korumak, kurtarmak ve denetlemek**. Bu modül, "çalışan AD"yi "savunulan, kurtarılabilir ve uyumlu AD"ye dönüştürür — ve Sistem Yöneticisi kolunu Blue Team'e bağlar.

---

## Bu modülde ne öğreneceksin?

AD'nin kalbini (NTDS.dit) korumayı ve bakımını, hangi felakette hangi kurtarmanın seçileceğini, varsayılan zafiyetleri kapatan hardening temellerini ve olan biteni görünür/kanıtlanabilir kılan denetimi. Ana ilke:

> **NTDS.dit = domain'in tüm sırları. Replikasyon yedek değildir. Hardening zorlaştırır, denetim görünür kılar.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [10.1](./10.1_NTDS_ve_ntdsutil.md) | **NTDS.dit ve ntdsutil** | ESE veritabanı & dosya seti, `ntdsutil` bakımı, DSRM, NTDS hırsızlığı riski |
| [10.2](./10.2_Yedekleme_ve_Kurtarma.md) | **Yedekleme ve Kurtarma** | System State, kurtarma karar ağacı, Recycle Bin/non-auth/authoritative, Forest Recovery, krbtgt 2x reset, ADMT |
| [10.3](./10.3_Hardening_Temelleri.md) | **Hardening Temelleri** | Protokol (signing/NTLM/AES), hesap (Protected Users/LAPS/gMSA), mimari (Tier Model) |
| [10.4](./10.4_Denetim_ve_Uyumluluk.md) | **Denetim ve Uyumluluk** | DACL vs SACL, denetim boru hattı, kritik Event ID'ler, ISO 27001/SOC 2/GDPR |

## Önerilen okuma sırası

`10.1 → 10.2 → 10.3 → 10.4` (veritabanı → kurtarma → sertleştirme → denetim).

## Bu modülün diğer kollardaki karşılığı

Bu modül **Blue Team'e köprüdür** — hardening ve denetim temelleri orada derinleşir:

- 🔴 **Red Team:** NTDS.dit hırsızlığı/DCSync/Golden Ticket → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/); bu kontrollerin kapattığı relay/PtH/Kerberoast → [Red M02](../../3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/), [Red M04](../../3-Red_Team/Modul_04_Yanal_Hareket/), [Red M08](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/).
- 🔵 **Blue Team:** Log toplama → [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/); tespit → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); kimlik bilgisi koruması → [Blue M03](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/); Tier Model → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/); protokol sertleştirme → [Blue M08](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/); değerlendirme → [Blue M09](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/); IR/kurtarma → [Blue M10](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Modül 09 — Otomasyon ve Arayüzler](../Modul_09_Otomasyon_ve_Arayuzler/)
- ➡️ **Sonraki kol:** 🎉 Sistem Yöneticisi tamamlandı → [Blue Team](../../2-Blue_Team/) · [Red Team](../../3-Red_Team/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / Forest Recovery Guide → 📐 CIS/NSA-CISA / uyumluluk standartları. Her dosya sonunda erişim tarihli kaynaklar.
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
