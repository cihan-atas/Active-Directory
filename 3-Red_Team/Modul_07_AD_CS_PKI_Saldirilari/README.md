# 🔴 Modül 07 — AD CS / PKI Saldırıları

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Privilege Escalation / Persistence (PKI)
> **Simetrik Blue modülü:** [Blue M07 — AD CS / PKI Güvenliği](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/)
> **Amaç:** Sertifika = kimlik. AD CS yanlış yapılandırmalarını (ESC1-8) ve CVE'yi (Certifried) domain hakimiyetine çevirmek, Certipy ile uçtan uca otomasyon, ve CA anahtarıyla yıllarca süren Golden Certificate kalıcılığı.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

AD CS, son yılların en etkili AD saldırı yüzeyidir. Çünkü bir sertifika PKINIT ile TGT verir ve parola değişse bile geçerli kalır.

> **Sertifikanın "kim olduğunu" SAN belirler; SAN'ı sen belirtebiliyorsan (ESC1) veya makine adını manipüle edebiliyorsan (Certifried) 'administrator' olursun. CA anahtarını çalarsan (ForgeCert) CA'ya dokunmadan yıllarca geçerli kimlik forge edersin — krbtgt reset bile bunu öldürmez. Savunma: şablon denetimi + KB5014754 strong mapping + CA koruma (HSM).**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [07.1](./07.1_ESC1_ESC8_Somuru_Teknikleri.md) | **ESC1–ESC8** | SAN belirtme, EKU'lar, ManageCA/ESC6/ESC7, PKINIT zinciri, Certipy find |
| [07.2](./07.2_Certifried_CVE_2022_26923.md) | **Certifried (CVE-2022-26923)** | dNSHostName manipülasyonu, DC$ kimliği, KB5014754 strong mapping |
| [07.3](./07.3_Certipy_ile_Otomasyon.md) | **Certipy Otomasyon** | find/req/auth/ca/account/shadow/forge, ESC6/ESC7, SID-uyumlu talep |
| [07.4](./07.4_ForgeCert_ve_Sertifika_Kaliciligi.md) | **ForgeCert & Kalıcılık** | CA anahtarı çalma, Golden Certificate, izsiz forge, THEFT/PERSIST |

## Önerilen okuma sırası

`07.1 → 07.2 → 07.3 → 07.4` (yanlış yapılandırma → CVE → otomasyon → CA anahtarı ile kalıcılık).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** Şablon izin denetimi (ESC önleme), CA hardening/ESC6, sertifika kalıcılık tespiti, PKI izleme → [Blue M07](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/).
- 🔗 **Bağlı Red modülleri:** Shadow Credentials/PKINIT ([05.4](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/05.4_Shadow_Credentials.md)) · makine hesabı/MAQ ([06.3](../Modul_06_Kerberos_Delegation_Saldirilari/06.3_Resource_Based_Constrained_Delegation.md)) · ESC8 relay ([Modül 08](../Modul_08_Koersiyon_ve_NTLM_Relay/)) · DC$ hash → DCSync ([Modül 09](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/)).
- 🏛️ **Sistem tabanı:** [Sistem M07 — PKI ve Sertifika Servisleri](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/).
- ⬅️ **Önceki Red modülü:** [Red M06 — Kerberos Delegation](../Modul_06_Kerberos_Delegation_Saldirilari/)
- ➡️ **Sonraki Red modülü:** [Red M08 — Koersiyon ve NTLM Relay](../Modul_08_Koersiyon_ve_NTLM_Relay/)

## MITRE ATT&CK kapsamı

`T1649` (Steal or Forge Authentication Certificates) · `T1136.001` (Create Account) · `T1098` (Account Manipulation) · `T1552.004` (Private Keys) · `T1555` (Credentials from Password Stores) · `T1112` (Modify Registry — ESC6).

## Kaynak yaklaşımı

🏛️ Microsoft AD CS + KB5014754 / CVE-2022-26923 → 🎓 SpecterOps (Certified Pre-Owned) / ly4k (Certifried, Certipy) / The Hacker Recipes → 🛠️ Certipy / Certify / ForgeCert / Rubeus / SharpDPAPI. Her dosya sonunda erişim tarihli kaynaklar.
