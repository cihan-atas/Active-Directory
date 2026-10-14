# 🔵 Modül 10 — Olay Müdahalesi, DFIR ve Kurtarma

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M10 — Trust, Forest ve Hibrit Saldırılar](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/)
> **Amaç:** Bir ihlal gerçekleştiğinde kaosu disipline çevirmek — playbook ile containment, krbtgt 2x reset ile Golden Ticket'ı öldürme, NTDS adli analiziyle kapsam belirleme ve son çare olarak forest recovery. Blue kolunun kapanış halkası.

---

## Bu modülde ne öğreneceksin?

Tespit ve değerlendirme bir saldırıyı ortaya çıkardığında "şimdi ne yapmalı?" sorusunun disiplinli cevabı. AD'nin kritik zorluğu: Tier 0 ele geçtiyse ortam güvenilmezdir. Ana ilke:

> **IR panik değil, prova edilmiş disiplindir. Golden Ticket parola değişimini umursamaz — krbtgt iki kez resetlenir. AD'nin kendisi güvenilmez hale geldiyse tek yol temiz yedekten yeniden inşadır — ama prova edilmemişse işe yaramaz.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [10.1](./10.1_IR_Playbook_Tespitten_Containment.md) | **IR Playbook** | NIST yaşam döngüsü, AD containment ikilemi, Tier 0 ihlali kararı, triage |
| [10.2](./10.2_KRBTGT_Cift_Reset_ve_Ticket_Gecersizlestirme.md) | **KRBTGT Çift-Reset** | N/N-1 geçmişi, iki-reset zorunluluğu, replikasyon bekleme, Golden'ı öldürme |
| [10.3](./10.3_NTDS_Adli_Analiz_ve_Timeline.md) | **NTDS Adli Analiz** | repadmin metadata, üç-kaynak korelasyonu, NTDS hırsızlığı, timeline |
| [10.4](./10.4_Forest_Recovery_Sureci.md) | **Forest Recovery** | Karar ağacı, Microsoft adımları, temiz-nokta yedek, tatbikat/RTO |

## Önerilen okuma sırası

`10.1 → 10.2 → 10.3 → 10.4` (playbook/containment → eradication (krbtgt) → adli analiz/kapsam → son çare kurtarma).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** Domain hakimiyeti (Golden/DCSync/DCShadow) → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/); trust/forest/hibrit saldırılar → [Red M10](../../3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/).
- 🔵 **Blue Team:** Tetikleyen tespitler [Blue M02](../Modul_02_SIEM_ve_Tespit_Muhendisligi/); Golden Ticket tespiti [Blue 06.4](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/06.4_Kerberos_Anomali_Izleme.md); DCSync/AdminSDHolder [Blue M05](../Modul_05_Yetki_ve_ACL_Sikilastirma/); sertifika kalıcılığı [Blue 07.3](../Modul_07_AD_CS_PKI_Guvenligi/07.3_Sertifika_Tabanli_Kalicilik_Tespiti.md); immutable log [Blue 01.4](../Modul_01_Gorunurluk_ve_Log_Yonetimi/01.4_Log_Toplama_Saklama_Normalizasyon.md); IoC kaynağı [Blue M09](../Modul_09_Tehdit_Avciligi_ve_Degerlendirme/).
- ⬅️ **Önceki:** [Blue M09 — Tehdit Avcılığı ve Değerlendirme](../Modul_09_Tehdit_Avciligi_ve_Degerlendirme/)
- ➡️ **Sonraki kol:** 🎉 Blue Team tamamlandı → [Red Team](../../3-Red_Team/) · [Sistem Yöneticisi](../../1-Sistem_Yoneticisi/)
- 🏛️ **Sistem tabanı:** [Sistem 10.1 — NTDS/ntdsutil](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.1_NTDS_ve_ntdsutil.md) · [Sistem 10.2 — Yedekleme ve Kurtarma](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.2_Yedekleme_ve_Kurtarma.md)

## Kaynak yaklaşımı

🏛️ Microsoft AD Forest Recovery Guide / DART playbook → 🎓 NIST SP 800-61 / SANS DFIR / ADSecurity → 🛠️ New-KrbtgtKeys.ps1 / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
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
