# 🌐 Modül 05 — DNS ve Ad Çözümleme

> **Kol:** 1 · Sistem Yöneticisi / Mimar
> **Amaç:** AD'nin bağımlı olduğu ad çözümleme altyapısını kurmak, güvenli hale getirmek ve teşhis etmek. **DNS bozulursa AD'nin neredeyse her parçası bozulur** — bu modül o omurgayı ele alır.

---

## Bu modülde ne öğreneceksin?

AD-Integrated DNS'in nasıl çalıştığını, hangi SRV kayıtlarının hayati olduğunu, ölü kayıtların nasıl temizlendiğini (aging/scavenging), DNS'in nasıl sertleştirildiğini (secure updates + DNSSEC) ve bir sorun çıktığında nasıl teşhis edileceğini. Ana ilke:

> **AD sorununda önce DNS'e bak. Yazma tarafını Secure Update, okuma tarafını DNSSEC korur.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [05.1](./05.1_AD_Integrated_Zones_ve_SRV.md) | **AD-Integrated Zones ve SRV** | Zone AD'ye gömme, application partition'lar, zone türleri, kritik SRV/`_msdcs` kayıtları |
| [05.2](./05.2_Aging_ve_Scavenging.md) | **Aging ve Scavenging** | Timestamp, No-Refresh + Refresh aralıkları, iki-seviye etkinleştirme, tuzaklar |
| [05.3](./05.3_DNSSEC_ve_Secure_Updates.md) | **DNSSEC ve Secure Updates** | Secure-only dinamik güncelleme, GQBL (WPAD/ISATAP), DNSSEC imzalama & güven zinciri, ADIDNS |
| [05.4](./05.4_Sorun_Giderme.md) | **Sorun Giderme** | Teşhis zinciri, `Resolve-DnsName`/`nslookup`, `dcdiag /test:dns`, SRV yeniden kayıt |

## Önerilen okuma sırası

`05.1 → 05.2 → 05.3 → 05.4` (yapı → hijyen → güvenlik → teşhis).

## Bu modülün diğer kollardaki karşılığı

- 🔴 **Red Team:** DNS/SRV enumerasyonu → [Red M01](../../3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/); ADIDNS/WPAD spoofing → [Red M02](../../3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/); ad zehirleme → NTLM Relay → [Red M08](../../3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/); DnsAdmins ile privesc → [Red M05](../../3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/).
- 🔵 **Blue Team:** DNS log toplama → [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/); anomali izleme → [Blue M02](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/); LLMNR/NBT-NS kapatma & relay önleme → [Blue M08](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/).
- ⬅️ **Önceki:** [Modül 04 — Grup İlkeleri (GPO)](../Modul_04_Grup_Ilkeleri_GPO/)
- ➡️ **Sonraki:** [Modül 06 — Depolama ve Dosya Servisleri](../Modul_06_Depolama_ve_Dosya_Servisleri/)

## Kaynak yaklaşımı

Tüm dosyalar `KAYNAKLAR.md` zincirini izler: 🏛️ Microsoft Learn / RFC 4033-4035 → 🎓 ADSecurity.org / SpecterOps. Her dosya sonunda erişim tarihli kaynaklar.
