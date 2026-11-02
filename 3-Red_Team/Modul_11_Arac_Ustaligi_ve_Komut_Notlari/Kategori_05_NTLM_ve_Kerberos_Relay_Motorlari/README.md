# 5. NTLM VE KERBEROS RELAY MOTORLARI (RELAY ENGINES)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 5 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **impacket-ntlmrelayx** | [impacket-ntlmrelayx.md](./impacket-ntlmrelayx.md) | Yakalanan SMB veya HTTP NTLM kimlik doğrulama isteklerini LDAP, LDAPS, MSSQL ve IMAP servislerine aktararak RBCD kurma, kullanıcı oluşturma veya AD CS sertifikası alma işlemlerini gerçekleştiren relay motorudur. |
| 2 | **KrbRelay** | [KrbRelay.md](./KrbRelay.md) | Windows yerel makinesindeki SYSTEM veya servis hesaplarını COM/RPC üzerinden hedef SPN'e yönlendirerek Kerberos AP-REQ biletlerini LDAP veya HTTP servislerine aktaran yerel relay aracıdır. |
| 3 | **KrbRelayUp** | [KrbRelayUp.md](./KrbRelayUp.md) | KrbRelay, RBCD, Shadow Credentials ve Rubeus (S4U2Proxy) adımlarını tek bir komutta zincirleyerek standart kullanıcıdan doğrudan yerel SYSTEM haklarına yükselen hepsi bir arada yetki yükseltme aracıdır. |
| 4 | **lsarelayx** | [lsarelayx.md](./lsarelayx.md) | LSA sürecine sahte kimlik sağlayıcı yükleyerek sisteme gelen tüm kimlik doğrulamaları yakalayan, Kerberos'u kasten NTLM'e düşüren ve harici hedeflere relay eden sistem düzeyi relay aracıdır. |
| 5 | **LdapRelayScan** | [LdapRelayScan.md](./LdapRelayScan.md) | Domain Controller'ların LDAP İmzalama (LDAP Signing) ve LDAPS Kanal Bağlama (Channel Binding Token - CBT) politikalarını parolasız veya kimlikli test eden güvenlik tarayıcısıdır. |


---

> **Önceki Kategori:** [← Kategori 4](../Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md) · **Sonraki Kategori:** [Kategori 6 →](../Kategori_06_Kerberos_Protokol_Cephaneligi/README.md)
