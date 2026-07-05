# 🔵 Modül 02 — SIEM ve Tespit Mühendisliği

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M02 — İlk Erişim](../../3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/) · [Red M03 — Kimlik Bilgisi Erişimi](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/)
> **Amaç:** [Blue M01](../Modul_01_Gorunurluk_ve_Log_Yonetimi/)'in topladığı ham telemetriyi **çalışan, taşınabilir, doğrulanmış tespitlere** çevirmek. Bu modül, "log var" ile "saldırıyı görürüm" arasındaki mühendislik köprüsüdür.

---

## Bu modülde ne öğreneceksin?

Hangi olay saldırıyı ele verir, o olay nasıl taşınabilir kurala dönüşür, kural nasıl doğrulanır. Ana ilke:

> **Event ID = harf, korelasyon = kelime, bağlam = cümle. Test edilmemiş kural hipotezdir; Atomic ile kanıtlanınca tespittir.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [02.1](./02.1_Kritik_Event_ID_Katalogu.md) | **Kritik Event ID Kataloğu** | Kill-chain eşlemeli olay aileleri, 4624 LogonType, 4768/4769/4662 bağlamı, MITRE eşleme |
| [02.2](./02.2_Sigma_Elastic_Splunk_Kural_Yazimi.md) | **Sigma/Elastic/Splunk Kural Yazımı** | Sigma anatomi, Pyramid of Pain, detection-as-code, aynı tespit üç dilde |
| [02.3](./02.3_Kerberoasting_AS_REP_Tespiti.md) | **Kerberoasting / AS-REP Tespiti** | 4769 RC4 downgrade mekaniği, davranışsal eşik, gMSA önlemi |
| [02.4](./02.4_Atomic_Red_Team_ile_Dogrulama.md) | **Atomic Red Team ile Doğrulama** | Purple-team döngüsü, kapsam matrisi, tespit boşluğu raporu |

## Önerilen okuma sırası

`02.1 → 02.2 → 02.3 → 02.4` (olayı tanı → kural yaz → örnek saldırıya uygula → doğrula).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** Bu kuralların yakaladığı ilk erişim (spray/poisoning) → [Red M02](../../3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/); kimlik hırsızlığı (Kerberoast/AS-REP) → [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); yanal hareket → [Red M04](../../3-Red_Team/Modul_04_Yanal_Hareket/).
- 🔵 **Blue Team:** Ham telemetri kaynağı [Blue M01](../Modul_01_Gorunurluk_ve_Log_Yonetimi/); yanal hareket tespiti [Blue M04](../Modul_04_Yanal_Hareket_Tespiti/); Kerberos sertleştirme [Blue M06](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/); değerlendirme/kapsam [Blue M09](../Modul_09_Tehdit_Avciligi_ve_Degerlendirme/).
- ⬅️ **Önceki:** [Blue M01 — Görünürlük ve Log Yönetimi](../Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- ➡️ **Sonraki:** [Blue M03 — Kimlik Bilgisi Koruması](../Modul_03_Kimlik_Bilgisi_Korumasi/)
- 🏛️ **Sistem tabanı:** [Sistem 10.4 — Denetim ve Uyumluluk](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.4_Denetim_ve_Uyumluluk.md) · [Sistem 03.4 — gMSA](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/03.4_gMSA_ve_FGPP.md)

## Kaynak yaklaşımı

🏛️ Microsoft event reference / ATT&CK → 🎓 ADSecurity / SigmaHQ / Pyramid of Pain → 🛠️ Atomic Red Team / Elastic-Splunk detection rules. Her dosya sonunda erişim tarihli kaynaklar.
