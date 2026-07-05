# ☁️ Modül 08 — Hibrit Kimlik ve Federasyon

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** On-prem AD ile Microsoft Entra ID (bulut) arasındaki köprüyü kurmak ve **güvenli** hale getirmek. Hibrit dünyada güvenlik sınırı artık yalnızca on-prem değildir — bu modül, on-prem ↔ bulut arasındaki saldırı yollarını ve savunmayı kapsar.

---

## Bu modülde ne öğreneceksin?

Nesnelerin buluta nasıl senkronlandığını, parolanın nerede doğrulandığını (PHS/PTA/Federation) ve bunun güvenlik etkisini, AD FS'in neden büyük bir saldırı yüzeyi olduğunu (Golden SAML) ve SSO mekanizmalarının (Seamless SSO / PRT) risklerini. Ana ilke:

> **Entra Connect sunucusu, PTA agent'ı ve AD FS = Tier 0. Hibrit köprü, on-prem ile bulutu aynı güvenlik kaderine bağlar.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [08.1](./08.1_Entra_Connect_Senkronizasyon.md) | **Entra Connect Senkronizasyon** | Connector space/metaverse akışı, sourceAnchor, topolojiler, sync hesabının DCSync yetkisi |
| [08.2](./08.2_Kimlik_Dogrulama_PHS_PTA_Federation.md) | **PHS / PTA / Federation** | Üç modelin "doğrulama nerede" akışları, dayanıklılık ve risk karşılaştırması |
| [08.3](./08.3_AD_FS_Mimarisi.md) | **AD FS Mimarisi** | Token akışı & claims pipeline, token signing certificate, Golden SAML, emeklilik yolu |
| [08.4](./08.4_Hibrit_ve_Seamless_SSO.md) | **Hibrit ve Seamless SSO** | AZUREADSSOACC Kerberos akışı & Silver Ticket riski, Hybrid Join, PRT |

## Önerilen okuma sırası

`08.1 → 08.2 → 08.3 → 08.4` (senkron → doğrulama modeli → federation → SSO).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** On-prem ↔ bulut pivot, Golden SAML, AZUREADSSOACC Silver Ticket, PRT theft → [Red M10](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/); sync hesabıyla DCSync → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/).
- 🔵 **Blue Team:** Auth altyapısı Tier 0 koruması → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/); kimlik bilgisi koruması → [Blue M03](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/); bulut/hibrit anomali izleme → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/).
- ⬅️ **Önceki:** [Modül 07 — PKI ve Sertifika Servisleri](../Modul_07_PKI_ve_Sertifika_Servisleri/)
- ➡️ **Sonraki:** [Modül 09 — Otomasyon ve Arayüzler](../Modul_09_Otomasyon_ve_Arayuzler/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn (Entra) → 🎓 dirkjanm.io / SpecterOps (hibrit saldırılar). Her dosya sonunda erişim tarihli kaynaklar.
