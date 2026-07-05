# 🔴 Modül 04 — Yanal Hareket

> **Kol:** 3 · Red Team (Saldırı) · **Kill chain aşaması:** Lateral Movement
> **Simetrik Blue modülü:** [Blue M04 — Yanal Hareket Tespiti](../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/)
> **Amaç:** Bir makinedeki kimliği tüm ağa yaymak. Hash/bilet ile kimlik doğrulama (PtH/OPtH/PtT), meşru uzak yönetim kanallarıyla kod yürütme (SMB/WMI/WinRM), ve NetExec ile endüstriyel otomasyon.
>
> ⚠️ **Etik (§6):** Yetkili sızma testi, CTF ve eğitim bağlamı. Her teknik karşı Blue tespiti/önlemiyle eşlenmiştir.

---

## Bu modülde ne öğreneceksin?

Kimlik ele geçti ([Modül 03](../Modul_03_Kimlik_Bilgisi_Erisimi/)); şimdi onu hareketе dönüştürüyorsun. AD'nin acı gerçeği:

> **Yanal hareket yeni açık sömürmez — yöneticilerin her gün kullandığı meşru protokolleri ele geçirilmiş kimlikle kullanır. Parola gerekmez (hash/bilet yeter), yeni araç gerekmez (SMB/WMI/WinRM zaten var). Farkı bağlam yaratır: kim, nereye, ne zaman. Bu yüzden savunma "olay" değil "davranış" izler.**

## İçindekiler

| # | Konu | Özet |
|---|------|------|
| [04.1](./04.1_Pass_the_Hash_ve_Overpass_the_Hash.md) | **PtH / Overpass-the-Hash** | NTLM challenge mekaniği, hash=parola-eşdeğeri, hash→TGT, RC4/AES OPSEC |
| [04.2](./04.2_Pass_the_Ticket.md) | **Pass-the-Ticket** | TGT/TGS anatomisi, .kirbi/.ccache, bilet enjeksiyonu, tgtdeleg, PtT vs forge |
| [04.3](./04.3_PsExec_WMI_WinRM.md) | **PsExec / WMI / WinRM** | Üç kanalın mekaniği ve izi (7045/WmiPrvSE/4104), kanal=iz seçimi |
| [04.4](./04.4_NetExec_Otomasyon.md) | **NetExec Otomasyon** | Çok protokol/kimlik, "Pwn3d!" mantığı, modül ekosistemi, tarama OPSEC'i |

## Önerilen okuma sırası

`04.1 → 04.2 → 04.3 → 04.4` (hash ile kimlik → bilet ile kimlik → kod yürütme kanalları → otomasyon).

## Bu modülün diğer kollardaki karşılığı

- 🔵 **Blue Team:** PtH/PtT tespiti, uzak yürütme izleri, oturum anomalisi → [Blue M04](../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/); Protected Users/Credential Guard önlemi → [Blue M03](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/).
- 🏛️ **Sistem tabanı:** [Sistem M03 — Hesap Yönetimi](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) · [Sistem M09 — Otomasyon/PowerShell](../../1-Sistem_Yoneticisi/Modul_09_Otomasyon_ve_Arayuzler/).
- ⬅️ **Önceki Red modülü:** [Red M03 — Kimlik Bilgisi Erişimi](../Modul_03_Kimlik_Bilgisi_Erisimi/)
- ➡️ **Sonraki Red modülü:** [Red M05 — Yetki Yükseltme (ACL & GPO)](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/)

## MITRE ATT&CK kapsamı

`T1550.002` (Pass the Hash) · `T1550.003` (Pass the Ticket) · `T1021.002` (SMB/Admin Shares) · `T1047` (WMI) · `T1021.006` (WinRM) · `T1569.002` (Service Execution) · `T1053.005` (Scheduled Task).

## Kaynak yaklaşımı

🏛️ Microsoft [MS-NLMP]/[MS-KILE]/WMI/WinRM → 🎓 harmj0y / The Hacker Recipes / SANS → 🛠️ Rubeus / Mimikatz / Impacket / evil-winrm / NetExec. Her dosya sonunda erişim tarihli kaynaklar.
