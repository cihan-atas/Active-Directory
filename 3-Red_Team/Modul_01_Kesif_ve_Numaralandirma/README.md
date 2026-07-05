# 🔴 Modül 01 — Keşif ve Numaralandırma

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Reconnaissance / Discovery
> **Simetrik Blue modülü:** [Blue M01 — Görünürlük ve Log Yönetimi](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
> **Amaç:** Tek bir sıradan domain hesabıyla (hatta yetkisiz) tüm ortamı haritalamak — kullanıcı/grup/SPN/ACL/GPO/trust. Sömürü yok, sadece görünürlük. Kill chain'in en sessiz ve en verimli adımı.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

AD'nin temel gerçeği: **kimliği doğrulanmış herhangi bir kullanıcı dizinin çoğunu okuyabilir.** Bu bir açık değil, tasarımdır — ve saldırgana istismarsız tam harita verir.

> **Keşif ucuzdur ve sessizdir; sömürü pahalı ve gürültülüdür. İyi bir operatör saldırının %80'ini keşifte kazanır — doğru yolu bulmak, denemekten iyidir.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [01.1](./01.1_LDAP_Enumerasyonu.md) | **LDAP Enumerasyonu** | RootDSE, naming context'ler, UAC bit filtreleri, `ldapsearch`/`nxc`/`LDP.exe`, yetkisiz vs yetkili |
| [01.2](./01.2_SharpHound_ve_BloodHound.md) | **SharpHound / BloodHound** | Grafik veri modeli, CollectionMethods, Session altını, Cypher ile en-kısa-yol |
| [01.3](./01.3_Kullanici_Grup_ACL_SPN_Kesfi.md) | **Kullanıcı/Grup/ACL/SPN/GPO** | SPN → Kerberoast havuzu, tehlikeli DACL hakları, GPO sömürü yüzeyi, PowerView/Impacket |
| [01.4](./01.4_Trust_ve_Forest_Enumerasyonu.md) | **Trust ve Forest Enum** | Trust yön/transitiflik, `trustAttributes`, SID filtering, forest = güvenlik sınırı |

## Önerilen okuma sırası

`01.1 → 01.2 → 01.3 → 01.4` (ham LDAP → grafik → nesne derinliği → forest yüzeyi).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** Keşfi görünür kılan telemetri ve loglama → [Blue M01 — Görünürlük](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/); aynı grafikle savunma → [Blue M09 — Tehdit Avcılığı](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/); tehlikeli ACL önleme → [Blue M05](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/).
- 🏛️ **Sistem tabanı:** [Sistem M01 — Mimari ve Temeller](../../1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/) · [Sistem M03 — Nesne ve Kimlik Yönetimi](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/).
- ➡️ **Sonraki Red modülü:** [Red M02 — İlk Erişim ve Yerleşme](../Modul_02_Ilk_Erisim_ve_Yerlesme/)

## MITRE ATT&CK kapsamı

`T1087` (Account Discovery) · `T1069` (Permission Groups Discovery) · `T1018` (Remote System Discovery) · `T1482` (Domain Trust Discovery) · `T1615` (Group Policy Discovery) · `T1049` (System Network Connections Discovery).

## Kaynak yaklaşımı

🏛️ Microsoft [MS-ADTS]/[MS-KILE] + RFC 4515 → 🎓 SpecterOps (ACE Up the Sleeve), harmj0y, The Hacker Recipes → 🛠️ PowerView / Impacket / NetExec / BloodHound. Her dosya sonunda erişim tarihli kaynaklar.
