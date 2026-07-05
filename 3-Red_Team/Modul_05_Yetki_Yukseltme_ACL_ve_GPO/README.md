# 🔴 Modül 05 — Yetki Yükseltme (ACL & GPO Abuse)

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Privilege Escalation
> **Simetrik Blue modülü:** [Blue M05 — Yetki ve ACL Sıkılaştırma](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/)
> **Amaç:** Yanlış yapılandırılmış izinleri (DACL) ve merkezi politikayı (GPO) zincirleyerek sıradan bir hesaptan Domain Admin'e. Exploit değil, "özellik kötüye kullanımı" (abuse) — yama ile kapanmaz, hijyen ile kapanır.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

AD'de yükseltmenin çoğu bir açıktan değil, **biriken yanlış izinlerden** gelir. BloodHound ([01.2](../Modul_01_Kesif_ve_Numaralandirma/01.2_SharpHound_ve_BloodHound.md)) bu kenarları haritalar; bu modül onları eyleme çevirir.

> **AD'de bir 'exploit' aramazsın — bir 'yanlış tabela' ararsın. GenericAll, WriteOwner, AddMember, gPLink, KeyCredentialLink: her biri meşru bir yönetim yeteneğidir; yanlış kişide olması yükseltmedir. Savunma bunu tespitle değil, DACL hijyeni ve tier modeliyle kapatır.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [05.1](./05.1_DACL_Abuse.md) | **DACL Abuse** | GenericAll/WriteDacl/ForceChangePassword → parola sıfırla/roast/DCSync ACE |
| [05.2](./05.2_WriteOwner_AddMember_GPLink.md) | **WriteOwner/AddMember/GPLink** | Sahiplik alma zinciri, grup iç içe geçme, OU'ya GPO bağlama |
| [05.3](./05.3_GPO_Abuse_SharpGPOAbuse.md) | **GPO Abuse** | GPC/GPT yapısı, Immediate Task, ölçekli SYSTEM yürütme, SharpGPOAbuse/pyGPOAbuse |
| [05.4](./05.4_Shadow_Credentials.md) | **Shadow Credentials** | msDS-KeyCredentialLink, PKINIT, UnPAC-the-Hash, parola değiştirmeden ele geçirme |

## Önerilen okuma sırası

`05.1 → 05.2 → 05.3 → 05.4` (doğrudan haklar → dolaylı zincirler → ölçekli GPO → sertifika tabanlı sessiz ele geçirme).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** DACL denetimi/temizliği, tier model, GPO güvenliği, AdminSDHolder → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/); Shadow Cred tespiti → [Blue 07.3](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/07.3_Sertifika_Tabanli_Kalicilik_Tespiti.md).
- 🏛️ **Sistem tabanı:** [Sistem M03 — Nesne/Kimlik (OU/AGDLP)](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) · [Sistem M04 — GPO](../../1-Sistem_Yoneticisi/Modul_04_Grup_Ilkeleri_GPO/).
- ⬅️ **Önceki Red modülü:** [Red M04 — Yanal Hareket](../Modul_04_Yanal_Hareket/)
- ➡️ **Sonraki Red modülü:** [Red M06 — Kerberos Delegation Saldırıları](../Modul_06_Kerberos_Delegation_Saldirilari/)

## MITRE ATT&CK kapsamı

`T1098` / `T1098.001` (Account Manipulation / Additional Credentials) · `T1222.001` (DACL Modification) · `T1484.001` (Group Policy Modification) · `T1053.005` (Scheduled Task) · `T1558.003` (targeted Kerberoast).

## Kaynak yaklaşımı

🏛️ Microsoft [MS-ADTS]/[MS-GPOL]/[MS-KILE] → 🎓 SpecterOps (ACE Up the Sleeve, Shadow Credentials) / The Hacker Recipes → 🛠️ PowerView / Impacket / bloodyAD / SharpGPOAbuse / Whisker / Certipy. Her dosya sonunda erişim tarihli kaynaklar.
