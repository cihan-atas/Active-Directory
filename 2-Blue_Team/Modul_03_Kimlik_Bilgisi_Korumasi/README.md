# 🔵 Modül 03 — Kimlik Bilgisi Koruması

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M03 — Kimlik Bilgisi Erişimi](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/)
> **Amaç:** Saldırganın en değerli hedefini — **kimlik bilgisini** — bellekte, diskte, önbellekte ve mimaride korumak. Kerberoasting/PtH/PtT'nin yakıtını kaynağında kurutmak.

---

## Bu modülde ne öğreneceksin?

Kimlik bilgisi LSASS belleğinde, diskte (DPAPI) ve önbellekte (DCC2) yaşar; hepsi ayrı korunmalı. En değerli kimlik ise riskli makineye **hiç uğramamalı**. Ana ilke:

> **Belleği koruyup diski/önbelleği unutmak, kapıyı kilitleyip pencereyi açık bırakmaktır. Ortak yerel admin parolası = tek noktadan tüm ağın düşmesi.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [03.1](./03.1_Credential_Guard_ve_LSASS_Korumasi.md) | **Credential Guard ve LSASS Koruması** | VBS/LSAISO mimarisi, RunAsPPL, neyi korur/korumaz, LSASS erişim tespiti |
| [03.2](./03.2_LAPS_ile_Yerel_Admin_Parola_Yonetimi.md) | **LAPS** | Benzersiz/dönen yerel admin parolası, PtH yayılma yarıçapını 1'e indirme, LAPS harvesting tespiti |
| [03.3](./03.3_Protected_Users_ve_Authentication_Policies.md) | **Protected Users & Auth Silos** | NTLM/RC4/delegation kapatma, Silo ile "nereden" kilidi, 4820/4821 |
| [03.4](./03.4_DPAPI_ve_Onbelleklenmis_Kimlik.md) | **DPAPI & Cached Credentials** | DPAPI masterkey/backup key, DCC2/MSCACHEv2, cache=0, disk sırları |

## Önerilen okuma sırası

`03.1 → 03.2 → 03.3 → 03.4` (bellek → ortak parola → mimari kısıt → disk/önbellek). Katmanlı savunma: her dosya bir öncekinin kapatamadığı yüzeyi kapatır.

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** LSASS/DPAPI/cache hasadı → [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); çalınan kimlikle yanal hareket (PtH/PtT) → [Red M04](../../3-Red_Team/Modul_04_Yanal_Hareket/); domain DPAPI backup key / DCSync → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/).
- 🔵 **Blue Team:** LSASS telemetrisi [Blue 01.3](../Modul_01_Gorunurluk_ve_Log_Yonetimi/01.3_Sysmon_ile_Derin_Telemetri.md); çalınan hash kullanımının tespiti [Blue M04](../Modul_04_Yanal_Hareket_Tespiti/); Tier Model [Blue M05](../Modul_05_Yetki_ve_ACL_Sikilastirma/); Kerberos sertleştirme [Blue M06](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/).
- ⬅️ **Önceki:** [Blue M02 — SIEM ve Tespit Mühendisliği](../Modul_02_SIEM_ve_Tespit_Muhendisligi/)
- ➡️ **Sonraki:** [Blue M04 — Yanal Hareket Tespiti](../Modul_04_Yanal_Hareket_Tespiti/)
- 🏛️ **Sistem tabanı:** [Sistem 10.3 — Hardening Temelleri](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.3_Hardening_Temelleri.md) · [Sistem 03.4 — gMSA](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/03.4_gMSA_ve_FGPP.md)

## Kaynak yaklaşımı

🏛️ Microsoft Learn (Credential Guard/LAPS/Protected Users/DPAPI) → 🎓 ADSecurity / Securing Privileged Access → 🛠️ Atomic Red Team / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
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
