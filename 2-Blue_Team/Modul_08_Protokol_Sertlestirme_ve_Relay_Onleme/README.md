# 🔵 Modül 08 — Protokol Sertleştirme ve Relay Önleme

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M08 — Koersiyon ve NTLM Relay](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/)
> **Amaç:** NTLM relay ve koersiyon zincirini uçtan uca kırmak — imzalama (LDAP/SMB), kanal bağlama (EPA), NTLM kısıtlama ve koersiyon yüzeyini (PetitPotam/PrinterBug) kapatma.

---

## Bu modülde ne öğreneceksin?

Relay, kimlik doğrulamayı bağlamından koparıp başka yere taşımaktır; koersiyon ise kurbanı (DC'yi bile) zorla getirir. Zincir çok noktalı kesilir. Ana ilke:

> **Signing bütünlüğü, Channel Binding kanal-bağlamını zorlar — "bu auth başka yere taşınamaz." NTLM her relay/PtH'nin ortak paydasıdır. Relay için saldırganın beklemesi gerekmez; koersiyon yüzeyini de kapat.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [08.1](./08.1_LDAP_Signing_ve_Channel_Binding.md) | **LDAP Signing & Channel Binding** | Require signing, EPA/CBT (LDAPS), event 2889, relay engelleme |
| [08.2](./08.2_SMB_Signing_Zorlama.md) | **SMB Signing Zorlama** | Server/client "always", SMB relay kesme, signing envanteri |
| [08.3](./08.3_NTLM_Kisitlama_ve_NTLMv2.md) | **NTLM Kısıtlama / NTLMv2** | LmCompatibilityLevel=5, Restrict NTLM (audit→deny), Kerberos'a geçiş |
| [08.4](./08.4_Koersiyon_Onleme_PetitPotam_PrinterBug.md) | **Koersiyon Önleme** | PetitPotam/PrinterBug/DFSCoerce, Spooler kapatma, RPC filtreleme, çok-katman |

## Önerilen okuma sırası

`08.1 → 08.2 → 08.3 → 08.4` (protokol-özel signing → NTLM'i baştan kısıtla → koersiyon tetikleyicisini kapat).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** NTLM/SMB/LDAP relay (ntlmrelayx, Responder) → [Red M08](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/); Pass-the-Hash → [Red M04](../../3-Red_Team/Modul_04_Yanal_Hareket/); ESC8 (AD CS relay) → [Red M07](../../3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/).
- 🔵 **Blue Team:** PtH tespiti [Blue 04.2](../Modul_04_Yanal_Hareket_Tespiti/04.2_Pass_the_Hash_Ticket_Tespiti.md); Protected Users (NTLM kapatma) [Blue 03.3](../Modul_03_Kimlik_Bilgisi_Korumasi/03.3_Protected_Users_ve_Authentication_Policies.md); unconstrained+koersiyon [Blue 06.2](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/06.2_Unconstrained_Delegation_Riskleri_ve_Onlemi.md); ESC8 [Blue M07](../Modul_07_AD_CS_PKI_Guvenligi/); relay ile eklenen ACL/RBCD [Blue 05.2](../Modul_05_Yetki_ve_ACL_Sikilastirma/05.2_Tehlikeli_DACL_Denetimi_ve_Temizligi.md); IR [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Blue M07 — AD CS / PKI Güvenliği](../Modul_07_AD_CS_PKI_Guvenligi/)
- ➡️ **Sonraki:** [Blue M09 — Tehdit Avcılığı ve Değerlendirme](../Modul_09_Tehdit_Avciligi_ve_Degerlendirme/)
- 🏛️ **Sistem tabanı:** [Sistem 10.3 — Hardening](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.3_Hardening_Temelleri.md) · [Sistem 06.1 — DFS-N/SMB](../../1-Sistem_Yoneticisi/Modul_06_Depolama_ve_Dosya_Servisleri/06.1_DFS_Namespaces.md)

## Kaynak yaklaşımı

🏛️ Microsoft KB5005413 / ADV190023 / Restrict NTLM → 🎓 dirkjanm / TrustedSec / SpecterOps (relay research) → 🛠️ PetitPotam / ntlmrelayx / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan savunma, tespit, log denetimi ve sıkılaştırma yönergeleri; **yalnızca yetkili sistem yöneticileri, mavi takım analistleri ve kurum içi güvenlik ekiplerinin savunma kabiliyetlerini artırmak** amacıyla hazırlanmıştır.
>
> Yapılandırma değişiklikleri öncesinde test ortamlarında doğrulama yapılmalı, olası kesintilere karşı tedbir alınmalıdır. Yazarlar, sistem değişikliklerinden kaynaklanabilecek iş sürekliliği aksaklıklarından sorumlu tutulamaz.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Active Directory Hardening (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/): Savunma mekanizmaları ve protokol sıkılaştırma kılavuzları.
- 🌐 [HackTricks Wiki — Defensive Security (Carlos Polop)](https://book.hacktricks.wiki/): Tespit kuralları, Event ID analizleri ve telemetri mimarisi.
- 🌐 [Microsoft Security Documentation](https://learn.microsoft.com/en-us/security/): Kurumsal Active Directory sıkılaştırma standartları.
- 🌐 [SigmaHQ Rules Repository](https://github.com/SigmaHQ/sigma): Açık kaynak SIEM tespit kuralları.
