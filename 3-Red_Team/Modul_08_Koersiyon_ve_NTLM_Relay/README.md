# Modül 08 — Koersiyon ve NTLM Relay 🔴

> **Kol:** Red Team (Saldırı) · **Simetrik Blue modülü:** [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
> **Önceki modül:** [Red M07 — AD CS / PKI Saldırıları](../Modul_07_AD_CS_PKI_Saldirilari/) · **Sonraki:** [Red M09 — Domain Hakimiyeti ve Kalıcılık](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/)

---

## Modül Özeti

NTLM'in doğuştan gelen kör noktası — **kimlik doğrulamanın hedefe bağlanmaması** — bu modülün merkezindedir. Bir kurbanın kimlik doğrulamasını yakalayıp *değiştirmeden başka bir sunucuya ileterek (relay)* onun ayrıcalıklarını devralırız. **Koersiyon** ise bu saldırıyı şansa bırakmaz: seçtiğimiz bir sunucuyu (özellikle **Domain Controller'ı**) tam istediğimiz anda kimlik doğrulamaya **zorlar**. Zincir ESC8 ile AD CS'e bağlandığında tek bir RPC çağrısı domain'i düşürür.

Bu modül [Red M02 poisoning](../Modul_02_Ilk_Erisim_ve_Yerlesme/02.1_LLMNR_NBTNS_mDNS_Poisoning.md), [Red M06 delegation](../Modul_06_Kerberos_Delegation_Saldirilari/) ve [Red M07 AD CS](../Modul_07_AD_CS_PKI_Saldirilari/) konularını tek bir relay omurgasında birleştirir.

---

## İçindekiler

| # | Konu | MITRE ATT&CK | Karşı Blue |
|---|------|--------------|-----------|
| 08.1 | [NTLM Relay (ntlmrelayx) Senaryoları](./08.1_NTLM_Relay_Senaryolari.md) | T1557.001 | [Blue 8.3](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.3_NTLM_Kisitlama_ve_NTLMv2.md) |
| 08.2 | [PetitPotam / PrinterBug / DFSCoerce](./08.2_PetitPotam_PrinterBug_DFSCoerce.md) | T1187 | [Blue 8.4](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.4_Koersiyon_Onleme_PetitPotam_PrinterBug.md) |
| 08.3 | [Relay → AD CS (ESC8) Zinciri](./08.3_Relay_AD_CS_ESC8_Zinciri.md) | T1557 + T1649 | [Blue 8.1](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.1_LDAP_Signing_ve_Channel_Binding.md) |
| 08.4 | [KrbRelayUp ile Yerel Yükseltme](./08.4_KrbRelayUp_ile_Yerel_Yukseltme.md) | T1068 | [Blue 8.1](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.1_LDAP_Signing_ve_Channel_Binding.md) |

---

## Öğrenme Hedefleri

- NTLMSSP challenge-response akışını ve neden relay'e açık olduğunu **paket seviyesinde** kavramak.
- Poisoning ile koersiyon farkını ve koersiyonun neden **DC hedefli** olduğunu anlamak.
- ESC8 zinciriyle bir DC'yi sertifika → PKINIT → DCSync yoluyla domain hakimiyetine çevirmek.
- KrbRelayUp ile **yerel** SYSTEM yükseltmesini RBCD/Shadow Cred köprüsüyle kurmak.
- Her relay hedefinin **imzalama/EPA/MAQ** savunmasıyla nasıl kapandığını görmek.

## Kaynak Yaklaşımı (KAYNAKLAR.md)

🏛️ Resmi (MS-NLMP, MS-EFSRPC, MS-RPRN, MS-DFSNM, MS-WCCE, KB5005413) → 🎓 Uzman (Fox-IT/Dirk-jan, SpecterOps, topotam, Dec0ne) → 🛠️ Araç (Impacket ntlmrelayx, Responder, PetitPotam, Coercer, Certipy, KrbRelayUp).

> **Simetri kuralı:** Bu modüldeki her saldırı, [Blue M08](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)'deki karşı sertleştirmeyle (SMB/LDAP signing, Channel Binding/EPA, NTLM kısıtlama, koersiyon yamaları) 1:1 eşleşir.
