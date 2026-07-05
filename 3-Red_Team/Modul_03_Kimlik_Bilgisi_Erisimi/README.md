# 🔴 Modül 03 — Kimlik Bilgisi Erişimi

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Credential Access
> **Simetrik Blue modülü:** [Blue M02 — SIEM ve Tespit](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/) · [Blue M03 — Kimlik Bilgisi Koruması](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)
> **Amaç:** Bir domain kimliğinden çok sayıda kimliğe. Protokol yan etkileriyle (roasting) offline kırılabilir hash, bellekten (LSASS) ve diskten (DPAPI) sır hasadı, ve toplananları kırma stratejisi.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

AD saldırısının kalbi. Kill chain burada hız kazanır: bir kimlik, birçok kimliğe dönüşür.

> **Kerberos'un tasarımı (roasting) ve SSO'nun gereği (LSASS/DPAPI) saldırgana kimlik verir. En önemli ders: NT hash varsa KIRMA — pass-the-hash. Credential Guard varsa LSASS boştur — DPAPI/roasting'e dön. Savunma kontrollerini (CG/LAPS/gMSA/AES) tanı, yolunu ona göre seç.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [03.1](./03.1_Kerberoasting_ve_AS_REP_Roasting.md) | **Kerberoasting / AS-REP** | TGS-REP şifreleme, etype/RC4 downgrade, Rubeus/Impacket, targeted roast |
| [03.2](./03.2_LSASS_Bellek_Dokumu.md) | **LSASS Bellek Dökümü** | SSP paketleri, WDigest, PPL/Credential Guard, comsvcs LOLBin, pypykatz |
| [03.3](./03.3_DPAPI_ve_Credential_Vault.md) | **DPAPI / Vault / Tarayıcı** | Master key zinciri, domain backup key, SharpDPAPI/SharpChrome, CG'yi atlama |
| [03.4](./03.4_Offline_Hash_Kirma.md) | **Offline Hash Kırma** | Hash→mod eşlemesi, wordlist+rules stratejisi, PtH mı kırma mı, DCC2 yavaşlığı |

## Önerilen okuma sırası

`03.1 → 03.2 → 03.3 → 03.4` (protokol roast → bellek → disk/at-rest → kırma stratejisi).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** Roasting/dump tespiti → [Blue 02.3](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/02.3_Kerberoasting_AS_REP_Tespiti.md); Credential Guard/RunAsPPL/LAPS/DPAPI koruması → [Blue M03](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/).
- 🏛️ **Sistem tabanı:** [Sistem M03 — Nesne/Kimlik (gMSA/FGPP)](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) · [Sistem M07 — PKI](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/).
- ⬅️ **Önceki Red modülü:** [Red M02 — İlk Erişim ve Yerleşme](../Modul_02_Ilk_Erisim_ve_Yerlesme/)
- ➡️ **Sonraki Red modülü:** [Red M04 — Yanal Hareket](../Modul_04_Yanal_Hareket/)

## MITRE ATT&CK kapsamı

`T1558.003` (Kerberoasting) · `T1558.004` (AS-REP Roasting) · `T1003.001` (LSASS Memory) · `T1003.002/.004` (SAM/LSA) · `T1555` / `T1555.003` (Password Stores / Browsers) · `T1110.002` (Password Cracking).

## Kaynak yaklaşımı

🏛️ Microsoft [MS-KILE] / DPAPI / LSA Protection → 🎓 harmj0y / SpecterOps / The Hacker Recipes → 🛠️ Rubeus / Mimikatz / pypykatz / SharpDPAPI / Hashcat. Her dosya sonunda erişim tarihli kaynaklar.
