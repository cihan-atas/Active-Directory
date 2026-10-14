# 18. ÇEVRİMDIŞI PAROLA KIRMA (OFFLINE CRACKING)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 2 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Hashcat** | [Hashcat.md](./Hashcat.md) | Modern GPU hızlandırması (CUDA/OpenCL) ile Active Directory NTLM (1000), NetNTLMv2 (5600), Kerberoast (13100) ve AS-REP (18200) hash'lerini saniyede milyarlarca hızla çözen parola kurtarma motorudur. |
| 2 | **John the Ripper** | [John_the_Ripper.md](./John_the_Ripper.md) | *2john ekosistemi (kirbi2john, pfx2john), Single Crack modu ve Markov tabanlı Incremental kaba kuvvet ile zengin format dönüştürme ve parola çözme motorudur. |


## 🎯 Operasyonel Rol ve Çevrimdışı Parola Kırma

Active Directory ortamlarında DCSync, LLMNR zehirleme veya Kerberoasting ile ele geçirilen kimlik bilgileri hedef ağ üzerinde aktif bir oturum açma veya hesap kilitleme (lockout) riski oluşturmadan, tamamen izole saldırgan donanımında çevrimdışı kırılır:

```
[ Active Directory Hasadı ]
  - NTDS.dit (DCSync) ──► NTLM Hash ──────────┐
  - Responder (LLMNR) ──► NetNTLMv2 Hash ─────┼─► [ Çevrimdışı Kırma İstasyonu ]
  - Kerberoasting ──────► TGS-REP ($krb5tgs$) ─┤    │
  - AD CS Sertifikası ──► .pfx Özel Anahtarı ──┘    ├─► Hashcat (Aşırı Hızlı GPU Çözümü)
                                                    └─► John the Ripper (*2john & Single Crack)
                                                                │
                                                                ▼
                                                    [ Açık Metin Parola: Sirket2026! ]
```

---

---

---

> **Önceki Kategori:** [← Kategori 17](../Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/README.md) · **Modül 11 Ana Sayfa:** [Modül 11 Kök Dizini (README) →](../README.md)
