# 🔐 Modül 07 — PKI ve Sertifika Servisleri (AD CS)

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** Kurumsal sertifika altyapısını (CA hiyerarşisi, şablonlar, dağıtım, yaşam döngüsü) güvenli biçimde tasarlamak. AD CS modern kimliğin omurgasıdır **ve** AD'nin en yoğun saldırı yüzeylerinden biridir (ESC1-8) — bu modül hem kurulumu hem savunmanın temelini verir.

---

## Bu modülde ne öğreneceksin?

Güven zincirinin nasıl kurulduğunu, şablon yanlış yapılandırmalarının (ESC) neden domain'i düşürebildiğini, sertifikaların nasıl dağıtılıp iptal edildiğini ve güçlü eşleme (strong mapping) ile ESC saldırılarının nasıl kırıldığını. Ana ilke:

> **PKI bir Tier 0 varlığıdır. Yanlış bir şablon = herhangi bir kullanıcının Domain Admin sertifikası.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [07.1](./07.1_PKI_Mimarisi_ve_CA_Hiyerarsisi.md) | **PKI Mimarisi ve CA Hiyerarşisi** | Güven zinciri, two-tier + offline root, Standalone vs Enterprise, NTAuth |
| [07.2](./07.2_Sertifika_Sablonlari_ve_Izinler.md) | **Sertifika Şablonları ve İzinler** | Şablon anatomisi, enroll izinleri, EKU, **ESC1-8 savunma kontrol listesi** |
| [07.3](./07.3_Autoenrollment_CRL_OCSP.md) | **Autoenrollment, CRL, OCSP** | GPO autoenroll, CDP/AIA, revocation altyapısı, offline root CRL takvimi |
| [07.4](./07.4_Sertifika_Yasam_Dongusu.md) | **Yaşam Döngüsü ve Güçlü Eşleme** | Yenileme, key archival, PKINIT, **KB5014754 strong mapping / enforcement** |

## Önerilen okuma sırası

`07.1 → 07.2 → 07.3 → 07.4` (hiyerarşi → şablon güvenliği → dağıtım/iptal → yaşam döngüsü & sertleştirme).

## Bu modülün diğer kollardaki karşılığı

Bu modülün Red/Blue karşılığı **doğrudan aynı numaralı** (M07) modüllerdir — simetri en güçlü burada:

- 🔴 **Red Team:** ESC1-8 sömürü, Certipy/Certify, ForgeCert, PKINIT abuse → [Red M07](../../3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/); web enrollment relay (ESC8) → [Red M08](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/).
- 🔵 **Blue Team:** Şablon/NTAuth denetimi (Locksmith/PSPKIAudit), strong mapping enforcement, sertifika izleme → [Blue M07](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/); CA'nın Tier 0 korunması → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/).
- ⬅️ **Önceki:** [Modül 06 — Depolama ve Dosya Servisleri](../Modul_06_Depolama_ve_Dosya_Servisleri/)
- ➡️ **Sonraki:** [Modül 08 — Hibrit Kimlik ve Federasyon](../Modul_08_Hibrit_Kimlik_ve_Federasyon/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / KB → 🎓 SpecterOps "Certified Pre-Owned" / PKI Solutions. Her dosya sonunda erişim tarihli kaynaklar.
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
