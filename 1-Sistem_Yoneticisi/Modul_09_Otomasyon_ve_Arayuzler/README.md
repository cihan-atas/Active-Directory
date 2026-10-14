# 🤖 Modül 09 — Otomasyon ve Arayüzler

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** AD'yi ölçekte yönetmek — elle tıklamayı bırakıp LDAP, PowerShell, IaC (DSC) ve API entegrasyonlarıyla tekrarlanabilir, denetlenebilir otomasyona geçmek. Her arayüz aynı zamanda bir yetki taşıdığından, güvenlik boyutu her konuya işlenmiştir.

---

## Bu modülde ne öğreneceksin?

Tüm AD araçlarının altındaki ham dili (LDAP), onu verimli süren PowerShell modülünü, durumu koda döken DSC'yi ve dış sistemlerle (Graph API, İK/IGA, WAC) güvenli entegrasyonu. Ana ilke:

> **Her araç arka planda LDAP'tır; her entegrasyon bir yetkidir. Verimlilik = doğru filtre + en az ayrıcalık.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [09.1](./09.1_LDAP_Mimarisi_ve_Sorgulama.md) | **LDAP Mimarisi ve Sorgulama** | Portlar/bind, search anatomisi (base/scope/filter/attr), RFC 4515 filtre + bit-testleri, LDP.exe, sayfalama |
| [09.2](./09.2_PowerShell_AD_Modulu.md) | **PowerShell AD Modülü** | Cmdlet→LDAP eşlemesi, `-Filter` vs `-LDAPFilter`, `-Properties`, `-Server` tutarlılığı, verimli desenler |
| [09.3](./09.3_Configuration_as_Code_DSC.md) | **Configuration as Code (DSC)** | Deklaratif model, LCM, push/pull, idempotency & drift düzeltme, ActiveDirectoryDsc |
| [09.4](./09.4_REST_API_ve_WAC.md) | **REST API / LDAP Entegrasyonu / WAC** | On-prem LDAP vs Graph API, app registration yetki riski, WAC gateway güvenliği |

## Önerilen okuma sırası

`09.1 → 09.2 → 09.3 → 09.4` (ham LDAP → PowerShell → IaC → dış entegrasyon).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** Aynı LDAP/PowerShell araçlarıyla enumerasyon (PowerView/BloodHound) → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); app registration/service principal abuse → [Red M10](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/).
- 🔵 **Blue Team:** PowerShell/LDAP loglama & WEF → [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/), [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); LDAP signing/channel binding → [Blue M08](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/); DSC baseline dayatma & WAC/entegrasyon Tier koruması → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/).
- ⬅️ **Önceki:** [Modül 08 — Hibrit Kimlik ve Federasyon](../Modul_08_Hibrit_Kimlik_ve_Federasyon/)
- ➡️ **Sonraki:** [Modül 10 — Güvenlik, Yedekleme ve Kurtarma](../Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / RFC 4515 → 🎓 ADSecurity.org / dirkjanm.io. Her dosya sonunda erişim tarihli kaynaklar.
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
