# Modül 09 — Domain Hakimiyeti ve Kalıcılık 🔴

> **Kol:** Red Team (Saldırı) · **Simetrik Blue modülleri:** [Blue M09 — Tehdit Avcılığı](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/) · [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/)
> **Önceki modül:** [Red M08 — Koersiyon ve NTLM Relay](../Modul_08_Koersiyon_ve_NTLM_Relay/) · **Sonraki:** [Red M10 — Trust, Forest ve Hibrit Saldırılar](../Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/)

---

## Modül Özeti

Bu modül, "domain admin oldum" ile "domain'i **sahiplendim ve elimde tutuyorum**" arasındaki farkı işler. [DCSync](./09.1_DCSync_ile_Hash_Cikarma.md) ile meşru replikasyon protokolünü kötüye kullanıp `krbtgt` dahil her hash'i çekeriz; **forged ticket** aileleriyle (Golden/Silver/Diamond/Sapphire) Kerberos'un imza güvenini kırar, istediğimiz kimliği üretiriz. Ardından **kırılgan** ticket kalıcılığından **yapısal** kalıcılığa (AdminSDHolder, DCShadow, DSRM) geçer; son olarak Skeleton Key ve NTDS.dit exfiltration ile evrensel giriş ve tam parola veritabanı kopyasını alırız.

Her teknik Tier-0 erişimi gerektirir — bunlar kill chain'in **hakimiyet ve kalıcılık** fazıdır ve [Blue M10 kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/) ile doğrudan karşıttır.

---

## İçindekiler

| # | Konu | MITRE ATT&CK | Karşı Blue |
|---|------|--------------|-----------|
| 09.1 | [DCSync ile Hash Çıkarma](./09.1_DCSync_ile_Hash_Cikarma.md) | T1003.006 | [Blue 10.2](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.2_KRBTGT_Cift_Reset_ve_Ticket_Gecersizlestirme.md) |
| 09.2 | [Golden / Silver / Diamond / Sapphire Ticket](./09.2_Golden_Silver_Diamond_Sapphire_Ticket.md) | T1558.001/002 | [Blue 10.2](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.2_KRBTGT_Cift_Reset_ve_Ticket_Gecersizlestirme.md) |
| 09.3 | [AdminSDHolder, DCShadow, DSRM Kalıcılığı](./09.3_AdminSDHolder_DCShadow_DSRM.md) | T1098 / T1207 / T1556 | [Blue 10.1](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.1_IR_Playbook_Tespitten_Containment.md) |
| 09.4 | [Skeleton Key ve NTDS.dit Exfiltration](./09.4_Skeleton_Key_ve_NTDS_Exfiltration.md) | T1556.001 / T1003.003 | [Blue 10.3](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.3_NTDS_Adli_Analiz_ve_Timeline.md) |

---

## Öğrenme Hedefleri

- MS-DRSR replikasyonunun DCSync ile nasıl kötüye kullanıldığını ve `krbtgt`'nin neden anahtar olduğunu kavramak.
- PAC imza katmanlarını ve Golden/Silver/Diamond/Sapphire ticket'ların **iz farklarını** anlamak.
- Kırılgan (ticket) ve yapısal (AdminSDHolder/DCShadow/DSRM) kalıcılık ayrımını yapmak.
- NTDS.dit'in PEK/BootKey şifreleme zincirini ve offline çözüm gereksinimini bilmek.
- Her tekniğin **krbtgt çift-reset / forest recovery** ile nasıl kurtarıldığını görmek.

## Kaynak Yaklaşımı (KAYNAKLAR.md)

🏛️ Resmi (MS-DRSR, MS-PAC, NTDS/ntdsutil, AdminSDHolder dokümanı) → 🎓 Uzman (gentilkiwi/Mimikatz, ADSecurity/Sean Metcalf, SpecterOps/Charlie Clark) → 🛠️ Araç (Impacket secretsdump/ticketer, Rubeus, Mimikatz, NetExec).

> **Simetri kuralı:** Bu modüldeki her hakimiyet/kalıcılık tekniği, [Blue M09](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/) tehdit avcılığı ve [Blue M10](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/) DFIR/kurtarma süreçleriyle 1:1 eşleşir.
