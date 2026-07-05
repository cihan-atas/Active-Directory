# 🔴 Modül 06 — Kerberos Delegation Saldırıları

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Privilege Escalation / Lateral Movement (Kerberos)
> **Simetrik Blue modülü:** [Blue M06 — Kerberos ve Delegation Sertleştirme](../../2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/)
> **Amaç:** Kerberos'un "bir servis kullanıcı adına başka servise gider" özelliğini (delegation) silaha çevirmek. Unconstrained TGT hasadı, S4U ile kimliğe bürünme, GenericWrite'ı RBCD ile ele geçirmeye çevirme, ve son savunma çizgisini (Bronze Bit) delme.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

Delegation, AD'nin en güçlü ve en yanlış anlaşılan özelliğidir. Yanlış yapılandırıldığında, sıradan bir yazma hakkını domain hakimiyetine çevirir.

> **Delegation, "kimlik ödünç verme" mekanizmasıdır. Unconstrained 'herkesi' ödünç alır (TGT hasadı); constrained/S4U 'istediğin kullanıcıyı' üretir (protocol transition); RBCD 'makineye yazma = makineyi alma' köprüsüdür; Bronze Bit son kalkanı (sensitive/Protected Users) deler. Savunma: delegation temizliği + AES/PAC + yama + Protected Users.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [06.1](./06.1_Unconstrained_Delegation_Abuse.md) | **Unconstrained Delegation** | TGT forwarding, pasif/aktif hasat, koersiyon + DC$ TGT → DCSync |
| [06.2](./06.2_Constrained_Delegation_S4U.md) | **Constrained & S4U** | S4U2Self/S4U2Proxy paket akışı, protocol transition, altservice hilesi |
| [06.3](./06.3_Resource_Based_Constrained_Delegation.md) | **RBCD** | AllowedToActOnBehalfOf, MachineAccountQuota, GenericWrite→ele geçirme |
| [06.4](./06.4_Bronze_Bit.md) | **Bronze Bit (CVE-2020-17049)** | forwardable bit kırma, sensitive/Protected Users bypass, yama bağımlılığı |

## Önerilen okuma sırası

`06.1 → 06.2 → 06.3 → 06.4` (en eski/geniş → S4U mekaniği → kaynak-taraflı köprü → son kalkanı delme).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** Delegation envanteri/temizliği, unconstrained önlemi, AES/PAC zorlama, anomali izleme → [Blue M06](../../2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/).
- 🔗 **Bağlı Red modülleri:** Keşif ([01.1](../Modul_01_Kesif_ve_Numaralandirma/01.1_LDAP_Enumerasyonu.md) UAC bitleri) · GenericWrite kaynağı ([05.2](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/05.2_WriteOwner_AddMember_GPLink.md)/[05.4](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/05.4_Shadow_Credentials.md)) · koersiyon ([Modül 08](../Modul_08_Koersiyon_ve_NTLM_Relay/)) · DCSync/Golden ([Modül 09](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/)).
- 🏛️ **Sistem tabanı:** [Sistem M03 — Hesap Yönetimi](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/).
- ⬅️ **Önceki Red modülü:** [Red M05 — Yetki Yükseltme](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/)
- ➡️ **Sonraki Red modülü:** [Red M07 — AD CS / PKI Saldırıları](../Modul_07_AD_CS_PKI_Saldirilari/)

## MITRE ATT&CK kapsamı

`T1558` / `T1558.003` (Steal/Forge Kerberos Tickets, Kerberoasting) · `T1550.003` (Pass the Ticket) · `T1187` (Forced Authentication) · `T1098` (Account Manipulation) · `T1136.001` (Create Account) · `T1003.006` (DCSync).

## Kaynak yaklaşımı

🏛️ Microsoft [MS-SFU]/[MS-KILE] + CVE-2020-17049 → 🎓 Elad Shamir (Wagging the Dog) / harmj0y / Netspi / The Hacker Recipes → 🛠️ Rubeus / Impacket (getST/rbcd/addcomputer) / PowerView / NetExec. Her dosya sonunda erişim tarihli kaynaklar.
