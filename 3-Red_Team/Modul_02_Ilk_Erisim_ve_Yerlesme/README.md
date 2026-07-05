# 🔴 Modül 02 — İlk Erişim ve Yerleşme

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Initial Access / Resource Development → Foothold
> **Simetrik Blue modülü:** [Blue M01 — Görünürlük](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/) · [Blue M02 — SIEM ve Tespit](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/)
> **Amaç:** Sıfır kimlikten ilk domain kimliğine, oradan sağlam bir foothold'a. Ağ zehirleme ile hash toplamak, spray ile parola bulmak, foothold sonrası "nerede olduğunu" tanımak.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

Keşif ([Modül 01](../Modul_01_Kesif_ve_Numaralandirma/)) haritayı çizdi; şimdi ilk ayak izini bırakıyorsun. İki ana giriş kapısı var:

> **1) Ağ dinlerken kimlik gelir (LLMNR/relay) — istismarsız hash. 2) Zayıf parola istatistiksel kesinliktir (spray). İkisi de gürültü/kilitleme ile ele verir — bu yüzden "low and slow" ve foothold sonrası önce durum tespiti.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [02.1](./02.1_LLMNR_NBTNS_mDNS_Poisoning.md) | **LLMNR/NBT-NS/mDNS Poisoning** | Çözümleme geri-düşüşü, NetNTLMv2 challenge-response, Responder/mitm6, kır vs. relay |
| [02.2](./02.2_Password_Spraying.md) | **Password Spraying** | Kilit politikası matematiği, low-and-slow, badPwdCount, çok protokol |
| [02.3](./02.3_Kerbrute_ile_Enum_ve_Spray.md) | **Kerbrute Enum + Spray** | AS-REQ pre-auth yan kanalı, kilitlemesiz kullanıcı enum, AS-REP bonusu |
| [02.4](./02.4_Ilk_Foothold_ve_Durum_Tespiti.md) | **Foothold ve Durum Tespiti** | 5-soru çerçevesi, privilege→sömürü eşlemesi, EDR tanıma, GPP cPassword |

## Önerilen okuma sırası

`02.1 → 02.2 → 02.3 → 02.4` (kimliksiz hash → parola tahmini → kilitlemesiz enum → foothold triyajı).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** İlk erişim izlerini yakalayan telemetri → [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/); spray/enum tespiti → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); LLMNR/relay önleme → [Blue 08.4](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.4_Koersiyon_Onleme_PetitPotam_PrinterBug.md).
- 🏛️ **Sistem tabanı:** [Sistem M05 — DNS](../../1-Sistem_Yoneticisi/Modul_05_DNS_ve_Ad_Cozumleme/) · [Sistem M03 — Nesne/Kimlik (parola politikası)](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/).
- ⬅️ **Önceki Red modülü:** [Red M01 — Keşif ve Numaralandırma](../Modul_01_Kesif_ve_Numaralandirma/)
- ➡️ **Sonraki Red modülü:** [Red M03 — Kimlik Bilgisi Erişimi](../Modul_03_Kimlik_Bilgisi_Erisimi/)

## MITRE ATT&CK kapsamı

`T1557.001` (LLMNR/NBT-NS Poisoning & Relay) · `T1110.003` (Password Spraying) · `T1558.004` (AS-REP Roasting) · `T1087.002` (Account Discovery) · `T1033`/`T1082` (Situational Awareness) · `T1552.006` (GPP Passwords).

## Kaynak yaklaşımı

🏛️ Microsoft [MS-KILE] + RFC'ler → 🎓 The Hacker Recipes / harmj0y / dirkjanm → 🛠️ Responder / kerbrute / NetExec / Impacket / Seatbelt. Her dosya sonunda erişim tarihli kaynaklar.
