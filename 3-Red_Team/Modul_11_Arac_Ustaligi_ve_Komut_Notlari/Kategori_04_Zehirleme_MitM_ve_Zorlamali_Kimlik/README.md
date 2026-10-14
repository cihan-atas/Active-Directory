# 4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 13 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Responder** | [Responder.md](./Responder.md) | Kurumsal ağda LLMNR, NBT-NS ve mDNS yayınlarını zehirleyerek sahte SMB/HTTP sunucuları üzerinden NetNTLM kimlik doğrulama hash'lerini yakalayan lider zehirleme aracıdır. |
| 2 | **Inveigh** | [Inveigh.md](./Inveigh.md) | Windows sistemlerde yerel olarak çalışan, LLMNR/mDNS/NBNS sahteciliği ile kimlik yakalayan C# ve PowerShell tabanlı Responder alternatifidir. |
| 3 | **mitm6** | [mitm6.md](./mitm6.md) | Windows makinelerin varsayılan IPv6 yapılandırmasını istismar ederek sahte DHCPv6 DNS sunucusu olan ve trafiği NTLM relay saldırılarına yönlendiren MitM aracıdır. |
| 4 | **PetitPotam** | [PetitPotam.md](./PetitPotam.md) | MS-EFSRPC protokolünü kullanarak hedef sunucuları (özellikle etki alanı denetleyicilerini) saldırganın dinleyicisine NTLM doğrulaması yapmaya zorlayan coerce aracıdır. |
| 5 | **SpoolSample** | [SpoolSample.md](./SpoolSample.md) | MS-RPRN Print System protokolü (PrinterBug) üzerinden etki alanı denetleyicisini belirlenen bir SMB hedefine NTLM doğrulaması yapmaya zorlayan araçtır. |
| 6 | **DFSCoerce** | [DFSCoerce.md](./DFSCoerce.md) | MS-DFSNM (Distributed File System Namespace) protokolü üzerinden Windows sunuculardan saldırgana zorlamalı NTLM kimlik doğrulaması tetikleyen araçtır. |
| 7 | **ShadowCoerce** | [ShadowCoerce.md](./ShadowCoerce.md) | MS-FSRVP (File Server Remote VSS Protocol) arayüzünü kullanarak Windows sunucuları saldırganın kontrolündeki hedefe kimlik doğrulamaya zorlayan araçtır. |
| 8 | **PrivExchange** | [PrivExchange.md](./PrivExchange.md) | Microsoft Exchange Server EWS PushSubscription bildirim zafiyetini kullanarak Exchange makine hesabını saldırgana NTLM doğrulaması yapmaya zorlayan araçtır. |
| 9 | **Dementor** | [Dementor.md](./Dementor.md) | MS-RPRN (PrinterBug) yöntemini Python ile uygulayarak uzaktaki Windows sunuculardan zorlamalı SMB kimlik doğrulaması başlatan hafif bir araçtır. |
| 10 | **Coercer** | [Coercer.md](./Coercer.md) | PetitPotam, SpoolSample, DFSCoerce ve ShadowCoerce dahil olmak üzere tüm zorlamalı kimlik doğrulama yöntemlerini tek bir çatı altında toplayan gelişmiş araçtır. |
| 11 | **Pre2k** | [Pre2k.md](./Pre2k.md) | Active Directory'deki eski işletim sistemi (Windows 2000 öncesi) bilgisayar hesaplarının varsayılan zayıf makine parolalarını sömüren araçtır. |
| 12 | **Crop** | [Crop.md](./Crop.md) | WebDAV servisi üzerinden Windows kullanıcı ve servis hesaplarını dış hedefe kimlik doğrulamaya zorlayan bir coerce aracıdır. |
| 13 | **Farmer** | [Farmer.md](./Farmer.md) | Sahte WebDAV sunucusu ayağa kaldırarak ve kurban makinelerde SCF/LNK dosyaları tetikleyerek NetNTLM hash'lerini toplayan C# tabanlı bir araçtır. |


---

> **Önceki Kategori:** [← Kategori 3](../Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/README.md) · **Sonraki Kategori:** [Kategori 5 →](../Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/README.md)
