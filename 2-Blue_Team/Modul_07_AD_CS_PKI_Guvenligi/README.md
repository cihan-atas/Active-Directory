# 🔵 Modül 07 — AD CS / PKI Güvenliği

> **Kol:** 2 · Blue Team (Savunma)
> **Simetrik Red modülü:** [Red M07 — AD CS / PKI Saldırıları](../../3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/)
> **Amaç:** AD CS'i domain ele geçirmenin en sessiz yolu olmaktan çıkarmak — ESC1-8 şablon zafiyetlerini kapatmak, CA'yı Tier 0 gibi sertleştirmek, sertifika kalıcılığını (Shadow Credentials) yakalamak ve PKI'yı sürekli izlemek.

---

## Bu modülde ne öğreneceksin?

Sertifika parola/hash gerektirmez, uzun ömürlüdür ve krbtgt reset'ini atlatır. Yanlış bir şablon veya tek bir CA bayrağı tüm domain'i düşürür. Ana ilke:

> **Bir kullanıcı "başkası adına" kimlik sertifikası alabiliyorsa zaten o kişidir. Sertifika parola değişimini umursamaz — tespit edilip iptal edilmedikçe yıllarca açık bir arka kapıdır. AD CS çoğu SOC'un kör noktasıdır.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [07.1](./07.1_Sertifika_Sablonu_Izin_Denetimi_ESC.md) | **Şablon İzin Denetimi (ESC1-8)** | ESC haritası, ESC1 anatomisi, Certipy find, şablon düzeltme |
| [07.2](./07.2_CA_Hardening_ve_ESC6.md) | **CA Hardening & ESC6** | EDITF_ATTRIBUTESUBJECTALTNAME2, ManageCA (ESC7), NTAuthCert (ESC5), CA audit |
| [07.3](./07.3_Sertifika_Tabanli_Kalicilik_Tespiti.md) | **Sertifika Kalıcılığı** | Shadow Credentials (msDS-KeyCredentialLink), krbtgt reset'i atlatma, iptal + temizlik |
| [07.4](./07.4_PKI_Izleme_ve_Olay_Kayitlari.md) | **PKI İzleme** | 4886-4899 olay ailesi, issuance→PKINIT korelasyonu, kör nokta kapatma |

## Önerilen okuma sırası

`07.1 → 07.2 → 07.3 → 07.4` (şablon zafiyeti → CA sertleştirme → kalıcılık → sürekli izleme).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** ESC1-8 sömürüsü, Certipy, Shadow Credentials → [Red M07](../../3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/); ESC8 (web enrollment + relay) → [Red M08](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/); sertifika ile domain hakimiyeti → [Red M09](../../3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/).
- 🔵 **Blue Team:** Log toplama [Blue M01](../Modul_01_Gorunurluk_ve_Log_Yonetimi/); tespit/korelasyon [Blue M02](../Modul_02_SIEM_ve_Tespit_Muhendisligi/); DACL hijyeni (ESC4/ESC5, Shadow Cred yazma) [Blue 05.2](../Modul_05_Yetki_ve_ACL_Sikilastirma/05.2_Tehlikeli_DACL_Denetimi_ve_Temizligi.md); AES/PAC & strong mapping [Blue M06](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/); ESC8 relay önleme [Blue M08](../Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/); IR/kurtarma [Blue M10](../Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/).
- ⬅️ **Önceki:** [Blue M06 — Kerberos ve Delegation Sertleştirme](../Modul_06_Kerberos_ve_Delegation_Sertlestirme/)
- ➡️ **Sonraki:** [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
- 🏛️ **Sistem tabanı:** [Sistem 07.1 — PKI Mimarisi](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/07.1_PKI_Mimarisi_ve_CA_Hiyerarsisi.md) · [Sistem 07.2 — Şablonlar/İzinler](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/07.2_Sertifika_Sablonlari_ve_Izinler.md)

## Kaynak yaklaşımı

🎓 SpecterOps "Certified Pre-Owned" (ESC1-8 kaynağı) → 🏛️ Microsoft Learn AD CS / KB5014754 → 🛠️ Certipy / Whisker / MITRE ATT&CK. Her dosya sonunda erişim tarihli kaynaklar.
