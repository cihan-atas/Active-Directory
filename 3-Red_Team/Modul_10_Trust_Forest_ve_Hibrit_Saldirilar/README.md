# Modül 10 — Trust, Forest ve Hibrit Saldırılar 🔴

> **Kol:** Red Team (Saldırı) · **Simetrik Blue modülü:** [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/) (ayrıca iz gizleme ↔ [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/))
> **Önceki modül:** [Red M09 — Domain Hakimiyeti ve Kalıcılık](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/) · **Kill chain sonu**

---

## Modül Özeti

Kill chain'in en geniş kapsamlı modülü: tek bir domain hakimiyetini **forest**, **başka forest** ve **bulut (Entra ID)** sınırlarının ötesine taşır. Intra-forest'ta SID filtering olmadığından [SID History injection](./10.1_SID_History_Injection.md) ile child→forest yükseliriz; cross-forest'ta SID filtering'i [trust key ve RID>1000 SID'lerle aşarız](./10.2_Cross_Forest_Trust_Abuse.md); hibrit ortamda [Entra Connect / Golden SAML / PRT](./10.3_Entra_ID_ve_Bulut_Pivot.md) ile on-prem↔bulut pivot yaparız. Son olarak [AMSI/ETW bypass ve OPSEC](./10.4_Savunma_Atlatma_AMSI_ETW_OPSEC.md) ile tüm zincirin **görünmezlik katmanını** ve — §6 çerçevesinde — savunmanın kör noktalarını işleriz.

Bu modül [Red M01 trust enumerasyonu](../Modul_01_Kesif_ve_Numaralandirma/01.4_Trust_ve_Forest_Enumerasyonu.md) ve [Red M09 hakimiyet](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/) çıktılarını sınır-ötesi hedeflere yansıtır.

---

## İçindekiler

| # | Konu | MITRE ATT&CK | Karşı Blue |
|---|------|--------------|-----------|
| 10.1 | [SID History Injection ve Intra-Forest Yükseltme](./10.1_SID_History_Injection.md) | T1134.005 | [Blue 10.2](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.2_KRBTGT_Cift_Reset_ve_Ticket_Gecersizlestirme.md) |
| 10.2 | [Cross-Forest Trust Abuse](./10.2_Cross_Forest_Trust_Abuse.md) | T1134.005 / T1550.003 | [Blue 10.1](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.1_IR_Playbook_Tespitten_Containment.md) |
| 10.3 | [Entra ID / Bulut Pivot](./10.3_Entra_ID_ve_Bulut_Pivot.md) | T1606.002 / T1550.001 | [Blue 10.1](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.1_IR_Playbook_Tespitten_Containment.md) |
| 10.4 | [Savunma Atlatma: AMSI/ETW Bypass, OPSEC](./10.4_Savunma_Atlatma_AMSI_ETW_OPSEC.md) | T1562.001 / T1070 | [Blue 1.3](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/01.3_Sysmon_ile_Derin_Telemetri.md) |

---

## Öğrenme Hedefleri

- Intra-forest (filtering'siz) ve cross-forest (filtering'li) yükseltme farkını SID mantığıyla kavramak.
- Trust key + inter-realm TGT mekaniğini ve SID filtering'in RID>1000 kör noktasını anlamak.
- Hibrit kimlik modellerinin (PHS/PTA/Federation) her birinin farklı bulut saldırı yüzeyini bilmek.
- Golden SAML, PRT çalma ve Entra Connect pivot ile on-prem↔bulut geçişini kurmak.
- AMSI/ETW/logging yüzeylerinin nasıl kör edildiğini ve — §6 gereği — bunun savunmayı güçlendirmek için raporlandığını görmek.

## Kaynak Yaklaşımı (KAYNAKLAR.md)

🏛️ Resmi (SID filtering, trustAttributes, Entra Connect, AD FS) → 🎓 Uzman (harmj0y trust guide, Dirk-jan/ROADtools, Syynimaa/AADInternals, CyberArk Golden SAML) → 🛠️ Araç (PowerView, Impacket, AADInternals, ROADtools, AzureHound, Invoke-Obfuscation).

> **Simetri kuralı:** Bu modüldeki her sınır-ötesi saldırı, [Blue M10](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/) DFIR/kurtarma ve [Blue M01](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/) görünürlük süreçleriyle 1:1 eşleşir. Kill chain burada kapanır; savunma döngüsü Blue M10 forest recovery ile devam eder.
