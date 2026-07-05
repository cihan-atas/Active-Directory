# 🔵 Modül 06 — Kerberos ve Delegation Sertleştirme

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M06 — Kerberos Delegation Saldırıları](../../3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/)
> **Amaç:** Kerberos'un en tehlikeli yanlış yapılandırmalarını (delegation) temizlemek, zayıf şifrelemeyi (RC4) kapatıp AES/PAC ile temeli sağlamlaştırmak ve kalan riski (Golden/Silver Ticket) anomali ile yakalamak.

---

## Bu modülde ne öğreneceksin?

Delegation "senin adına başkasına gidebilme" yetkisidir; yanlış verildiğinde ayrıcalık yükseltme yoludur. Zayıf şifreleme bileti kırılabilir kılar; forge PAC sahte yetki yazar. Ana ilke:

> **Gereksiz her delegation bir "başkasına bürünme" hediyesidir; RC4 Kerberoasting'in yakıtıdır; Golden Ticket mükemmel görünür — onu tutarsızlıklardan yakalarsın. Sertleştirme daraltır, anomali izleme kapatır.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [06.1](./06.1_Delegation_Envanteri_ve_Temizligi.md) | **Delegation Envanteri** | Üç tür + risk sırası, msDS öznitelikleri, gereksizleri kaldırma |
| [06.2](./06.2_Unconstrained_Delegation_Riskleri_ve_Onlemi.md) | **Unconstrained Delegation** | TGT hasadı + koersiyon zinciri, "tek sunucu → domain", AccountNotDelegated |
| [06.3](./06.3_AES_Zorlama_RC4_ve_PAC.md) | **AES / RC4 / PAC** | etype riskleri, msDS-SupportedEncryptionTypes, PAC & strong mapping KB'leri |
| [06.4](./06.4_Kerberos_Anomali_Izleme.md) | **Kerberos Anomali İzleme** | Golden/Silver Ticket, TGT'siz TGS, var olmayan hesap, krbtgt 2x reset bağlantısı |

## Önerilen okuma sırası

`06.1 → 06.2 → 06.3 → 06.4` (delegation envanteri → en tehlikeli türü kapat → şifreleme/PAC temeli → kalan riski izle).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** Unconstrained/Constrained/RBCD + S4U → [Red M06](../../3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/); Kerberoasting (RC4) → [Red M03](../../3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/); Golden/Silver/Diamond Ticket → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/); koersiyon → [Red M08](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/).
- 🔵 **Blue Team:** Kerberos tespit temeli [Blue M02](../Modul_02_SIEM_ve_Tespit_Muhendisligi/); Protected Users/AccountNotDelegated [Blue 03.3](../Modul_03_Kimlik_Bilgisi_Korumasi/03.3_Protected_Users_ve_Authentication_Policies.md); DACL hijyeni (RBCD yazma) [Blue 05.2](../Modul_05_Yetki_ve_ACL_Sikilastirma/05.2_Tehlikeli_DACL_Denetimi_ve_Temizligi.md); koersiyon/relay önleme [Blue M08](../Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/); sertifika strong mapping [Blue M07](../Modul_07_AD_CS_PKI_Guvenligi/); krbtgt reset/IR [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Blue M05 — Yetki ve ACL Sıkılaştırma](../Modul_05_Yetki_ve_ACL_Sikilastirma/)
- ➡️ **Sonraki:** [Blue M07 — AD CS / PKI Güvenliği](../Modul_07_AD_CS_PKI_Guvenligi/)
- 🏛️ **Sistem tabanı:** [Sistem 03.4 — gMSA](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/03.4_gMSA_ve_FGPP.md) · [Sistem 10.3 — Hardening](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/10.3_Hardening_Temelleri.md)

## Kaynak yaklaşımı

🏛️ Microsoft Learn (Kerberos delegation/encryption/PAC KB'leri) → 🎓 ADSecurity / harmj0y (S4U, unconstrained) → 🛠️ Atomic Red Team / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
