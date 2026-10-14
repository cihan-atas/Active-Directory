# 1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 11 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **smbclient** | [smbclient.md](./smbclient.md) | Samba paketinin CLI istemcisidir; SMB/CIFS paylaşımlarını listelemek, dosya transferi yapmak ve oturumsuz (null session) keşif gerçekleştirmek için kullanılır. |
| 2 | **smbmap** | [smbmap.md](./smbmap.md) | Ağdaki SMB paylaşımlarının okuma/yazma izinlerini otomatik denetleyen ve hassas dosyaları regex kalıplarıyla tarayan yetki denetim aracıdır. |
| 3 | **impacket-smbclient** | [impacket-smbclient.md](./impacket-smbclient.md) | Pass-the-Hash (PTH) ve Kerberos biletleri ile uzak SMB paylaşımlarına bağlanıp dosya yönetimi ve komut yürütme sağlayan Python istemcisidir. |
| 4 | **mount.cifs** | [mount.cifs.md](./mount.cifs.md) | Uzak Windows ve SMB paylaşımlarını Linux dosya sistemine yerel bir dizin olarak bağlayarak grep ve find gibi Linux araçlarıyla derin dosya analizi yapmayı sağlar. |
| 5 | **ldapsearch** | [ldapsearch.md](./ldapsearch.md) | OpenLDAP paketinin komut satırı aracıdır; OID bitwise filtreleri ve sayfalama desteğiyle Active Directory veritabanında derinlemesine nesne ve yetki sorgulaması yapar. |
| 6 | **windapsearch** | [windapsearch.md](./windapsearch.md) | SPN taşıyan hesapları, kısıtlanmamış yetki devirlerini (unconstrained delegation) ve etki alanı yöneticilerini hızlıca keşfetmek için geliştirilmiş pratik LDAP keşif aracıdır. |
| 7 | **rpcclient** | [rpcclient.md](./rpcclient.md) | Samba MS-RPC arayüz istemcisidir; SAMR ve LSA named pipe'ları üzerinden kullanıcı/grup listeleme, RID cycling ve parola politikası keşfi için kullanılır. |
| 8 | **impacket-rpcdump** | [impacket-rpcdump.md](./impacket-rpcdump.md) | Port 135 RPC Endpoint Mapper üzerinden hedef sistemde kayıtlı RPC arayüzlerini ve UUID değerlerini listeleyerek zafiyetli servisleri tespit eder. |
| 9 | **impacket-samrdump** | [impacket-samrdump.md](./impacket-samrdump.md) | SAMR protokolünü sorgulayarak hedef sistemdeki yerel ve etki alanı kullanıcılarını, gruplarını ve parola kilitleme politikalarını döker. |
| 10 | **enum4linux-ng** | [enum4linux-ng.md](./enum4linux-ng.md) | SMB, RPC, LDAP ve NetBIOS protokollerini birleştirerek Windows ve Samba sistemlerinden kullanıcı, grup, paylaşım ve işletim sistemi bilgilerini toplayan hepsi bir arada keşif aracıdır. |
| 11 | **nmap (NSE Script)** | [nmap_NSE_Script.md](./nmap_NSE_Script.md) | Nmap script motoru üzerinden SMB imzalama zorunluluğunu (SMB Signing), işletim sistemi sürümlerini ve MS17-010 gibi kritik zafiyetleri denetleyen ağ tarama aracıdır. |


---

> **Modül 11 Ana Sayfa:** [← Modül 11 Kök Dizini](../README.md) · **Sonraki Kategori:** [Kategori 2 →](../Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/README.md)
