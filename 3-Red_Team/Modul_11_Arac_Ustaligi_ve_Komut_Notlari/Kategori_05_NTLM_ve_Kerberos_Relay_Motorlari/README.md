# 5. NTLM VE KERBEROS RELAY MOTORLARI (RELAY ENGINES)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 3 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **impacket-ntlmrelayx** | [impacket-ntlmrelayx.md](./impacket-ntlmrelayx.md) | Yakalanan SMB veya HTTP NTLM kimlik doğrulama isteklerini LDAP, LDAPS, MSSQL ve IMAP servislerine aktararak RBCD kurma, kullanıcı oluşturma veya AD CS sertifikası alma işlemlerini gerçekleştiren relay motorudur. |
| 2 | **KrbRelay** | [KrbRelay.md](./KrbRelay.md) | Windows yerel makinesindeki SYSTEM veya servis hesaplarını COM/RPC üzerinden hedef SPN'e yönlendirerek Kerberos AP-REQ biletlerini LDAP veya HTTP servislerine aktaran yerel relay aracıdır. |
| 3 | **KrbRelayUp** | [KrbRelayUp.md](./KrbRelayUp.md) | KrbRelay, RBCD, Shadow Credentials ve Rubeus (S4U2Proxy) adımlarını tek bir komutta zincirleyerek standart kullanıcıdan doğrudan yerel SYSTEM haklarına yükselen hepsi bir arada yetki yükseltme aracıdır. |


---

> **Önceki Kategori:** [← Kategori 4](../Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md) · **Sonraki Kategori:** [Kategori 6 →](../Kategori_06_Kerberos_Protokol_Cephaneligi/README.md)
