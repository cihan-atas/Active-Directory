# 🔵 Modül 04 — Yanal Hareket Tespiti

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M04 — Yanal Hareket](../../3-Red_Team/Modul_04_Yanal_Hareket/)
> **Amaç:** Saldırganın "bir makineden diğerine atlayarak DC'ye ulaşma" hareketini yakalamak. Kimliğe bürünme (PtH/PtT) + komut çalıştırma (PsExec/WMI/WinRM) izlerini ve tuzaklarla (honeytoken) sıfır-gürültülü erken uyarıyı kurar.

---

## Bu modülde ne öğreneceksin?

Yanal hareket iki adımdır: kimliğe bürün + komut çalıştır. Her adım iz bırakır; anomali (baseline sapması) ve deception (tuzak) ile yakalanır. Ana ilke:

> **Yanal hareket tek bir kötü olay değil, anormal bir bağlantı desenidir. Anomali gürültülüdür; honeytoken gürültüsüzdür — ikisini birlikte kullan.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [04.1](./04.1_Anormal_Oturum_Acma_Analizi.md) | **Anormal Oturum Açma (4624 LogonType)** | LogonType tam referansı, fan-out grafiği, baseline, 4648 pivot |
| [04.2](./04.2_Pass_the_Hash_Ticket_Tespiti.md) | **PtH / PtT Tespiti** | NTLM anomalisi, Overpass imzası (Type 9 + seclogo), önlem: Protected Users |
| [04.3](./04.3_Uzak_Yurutme_Izleri.md) | **Uzak Yürütme (PsExec/WMI/WinRM)** | Her kanalın parmak izi, servis+pipe vs süreç-ağacı, fileless tehlike |
| [04.4](./04.4_Honeytoken_ve_Honey_Account.md) | **Honeytoken / Honey-Account** | Sıfır-gürültülü tuzak, Kerberoast yemi, deception haritası |

## Önerilen okuma sırası

`04.1 → 04.2 → 04.3 → 04.4` (oturum anomalisi → kimliğe bürünme → komut çalıştırma → proaktif tuzak).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** PtH/Overpass/PtT + PsExec/WMI/WinRM ile yayılma → [Red M04](../../3-Red_Team/Modul_04_Yanal_Hareket/); tuzağa düşen keşif/Kerberoast → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); bilet forge (Golden/Silver) → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/).
- 🔵 **Blue Team:** Telemetri kaynağı [Blue M01](../Modul_01_Gorunurluk_ve_Log_Yonetimi/); kural yazımı [Blue M02](../Modul_02_SIEM_ve_Tespit_Muhendisligi/); çalınan kimliğin önlenmesi [Blue M03](../Modul_03_Kimlik_Bilgisi_Korumasi/); Tier Model [Blue M05](../Modul_05_Yetki_ve_ACL_Sikilastirma/); NTLM/protokol sertleştirme [Blue M08](../Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/); IR [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Blue M03 — Kimlik Bilgisi Koruması](../Modul_03_Kimlik_Bilgisi_Korumasi/)
- ➡️ **Sonraki:** [Blue M05 — Yetki ve ACL Sıkılaştırma](../Modul_05_Yetki_ve_ACL_Sikilastirma/)
- 🏛️ **Sistem tabanı:** [Sistem 02.1 — DC ve Topoloji](../../1-Sistem_Yoneticisi/Modul_02_Fiziksel_Altyapi_ve_Replikasyon/02.1_Domain_Controller_ve_Site_Topolojisi.md) · [Sistem 09.2 — PowerShell](../../1-Sistem_Yoneticisi/Modul_09_Otomasyon_ve_Arayuzler/09.2_PowerShell_AD_Modulu.md)

## Kaynak yaklaşımı

🏛️ Microsoft event reference / PtH mitigation → 🎓 ADSecurity / JPCERT / SpecterOps → 🛠️ Atomic Red Team / Canarytokens / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
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
