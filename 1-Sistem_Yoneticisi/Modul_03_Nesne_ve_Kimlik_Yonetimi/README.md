# 👥 Modül 03 — Nesne ve Kimlik Yönetimi (Kalenin Nüfusu)

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** AD'nin "nüfusunu" — kullanıcılar, gruplar, servis hesapları — güvenli ve yönetilebilir şekilde organize etmek. Bu modül, kimlik ve yetkilendirmenin günlük operasyonel çekirdeğidir ve doğrudan saldırı yüzeyini belirler.

---

## Bu modülde ne öğreneceksin?

Kimin hangi isimle var olduğunu, hesapların hangi özniteliklerinin güvenlik kritik olduğunu, kaynak erişiminin AGDLP ile nasıl düzenlendiğini ve servis hesaplarının Kerberoasting'e karşı gMSA ile nasıl korunduğunu. Ana ilke:

> **OU yönetim için toplar; grup kaynak erişimi için toplar. İzin daima Domain Local gruba verilir (AGDLP).**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [03.1](./03.1_OU_Tasarimi_ve_Yetki_Devri.md) | **OU Tasarımı ve Yetki Devri** | OU modelleri, ACL/ACE ile delegation, kalıtım, AdminSDHolder istisnası, en az ayrıcalık |
| [03.2](./03.2_Hesap_Yonetimi.md) | **Hesap Yönetimi** | UPN vs sAMAccountName, userAccountControl bayrakları (güvenlik!), SPN/adminCount, Attribute Editor, stale hesaplar |
| [03.3](./03.3_Grup_Ustaligi_AGDLP.md) | **Grup Ustalığı ve AGDLP** | Tür/kapsam kuralları, AGDLP/AGUDLP, primaryGroupID tuzağı, korumalı gruplar & SDProp |
| [03.4](./03.4_gMSA_ve_FGPP.md) | **gMSA ve FGPP** | MSA/gMSA/dMSA, KDS Root Key, servis hesabı sertleştirme, PSO ile granüler parola politikası |

## Önerilen okuma sırası

`03.1 → 03.2 → 03.3 → 03.4` (kap/delegation → hesap → grup → özel hesap & politika).

## Bu modülün diğer kollardaki karşılığı

Bu modül, saldırı ve savunmanın en yoğun kesiştiği yerlerden biridir:

- 🔴 **Red Team:** Nesne/ACL/SPN enumerasyonu → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); AS-REP/Kerberoasting → [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); ACL/delegation abuse → [Red M05](../../3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/); delegation bayrakları → [Red M06](../../3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/); AdminSDHolder/Golden dMSA → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/).
- 🔵 **Blue Team:** Kimlik bilgisi koruması (Protected Users, LAPS, gMSA) → [Blue M03](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/); DACL/Tier hijyeni → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/); nesne/ACL izleme → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/).
- ⬅️ **Önceki:** [Modül 02 — Fiziksel Altyapı ve Replikasyon](../Modul_02_Fiziksel_Altyapi_ve_Replikasyon/)
- ➡️ **Sonraki:** [Modül 04 — Grup İlkeleri (GPO)](../Modul_04_Grup_Ilkeleri_GPO/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / MS-GKDI → 🎓 ADSecurity.org / SpecterOps. Her dosya sonunda erişim tarihli kaynaklar.
