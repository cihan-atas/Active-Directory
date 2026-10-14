# 6. KERBEROS PROTOKOL CEPHANELİĞİ (KERBEROS SUITE)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 10 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Rubeus** | [Rubeus.md](./Rubeus.md) | Kerberos bilet yönetimi, Kerberoasting, AS-REP Roasting, S4U delegasyon istismarı, Pass-the-Ticket, Golden/Silver/Diamond ticket üretimi için geliştirilmiş en kapsamlı C# Kerberos aracıdır. |
| 2 | **impacket-GetUserSPNs** | [impacket-GetUserSPNs.md](./impacket-GetUserSPNs.md) | Active Directory'de Service Principal Name (SPN) barındıran servis hesaplarını listeleyen ve çevrimdışı parola kırma için TGS biletlerini indiren (Kerberoasting) araçtır. |
| 3 | **impacket-GetNPUsers** | [impacket-GetNPUsers.md](./impacket-GetNPUsers.md) | Kerberos önkimlik doğrulaması gerektirmeyen (DONT_REQ_PREAUTH) kullanıcıları tespit ederek parolasız AS-REP biletlerini hasat eden (AS-REP Roasting) araçtır. |
| 4 | **impacket-getTGT** | [impacket-getTGT.md](./impacket-getTGT.md) | Kullanıcının parolası, NTLM hash'i veya AES anahtarı ile Kerberos KDC'den TGT (Ticket Granting Ticket) talep edip ccache dosyasına kaydeden araçtır. |
| 5 | **impacket-getST** | [impacket-getST.md](./impacket-getST.md) | Kısıtlı yetki devri (Constrained Delegation) ve S4U2self/S4U2proxy uzantılarını kullanarak herhangi bir etki alanı yöneticisi adına sahte Servis Bileti (Service Ticket) üreten araçtır. |
| 6 | **impacket-ticketer** | [impacket-ticketer.md](./impacket-ticketer.md) | Çalınan KRBTGT hash'i ile Altın Bilet (Golden Ticket) veya servis NTLM hash'i ile Gümüş Bilet (Silver Ticket) üreten araçtır. |
| 7 | **impacket-ticketConverter** | [impacket-ticketConverter.md](./impacket-ticketConverter.md) | Linux (ccache) ve Windows (kirbi) Kerberos bilet formatları arasında çift yönlü dönüşüm sağlayan yardımcı araçtır. |
| 8 | **impacket-describeTicket** | [impacket-describeTicket.md](./impacket-describeTicket.md) | Kerberos bilet dosyasını (kirbi veya ccache) ayrıştırarak içerisindeki kullanıcı SID'lerini, grup üyeliklerini ve PAC alanlarını ekrana basan analiz aracıdır. |
| 9 | **Kirbikator** | [Kirbikator.md](./Kirbikator.md) | Mimikatz ve Rubeus tarafından üretilen .kirbi biletlerini toplu olarak dönüştürmek ve yönetmek için kullanılan bir kütüphanedir. |
| 10 | **TGSTomp** | [TGSTomp.md](./TGSTomp.md) | Kerberoasting tespit sistemlerini atlatmak amacıyla TGS bilet isteklerindeki şifreleme türünü ve istek başlıklarını manipüle eden bir araçtır. |


---

> **Önceki Kategori:** [← Kategori 5](../Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/README.md) · **Sonraki Kategori:** [Kategori 7 →](../Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/README.md)
