# 10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 7 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Snaffler** | [Snaffler.md](./Snaffler.md) | Etki alanı genelindeki SMB ve DFS ağ paylaşımlarını otomatik tarayarak regex ile parola, kdbx kasası, SSH anahtarları ve yapılandırma sırlarını avlayan yüksek performanslı C# aracıdır. |
| 2 | **SharpShares** | [SharpShares.md](./SharpShares.md) | Active Directory bilgisayarlarını LDAP üzerinden sorgulayarak ağ paylaşımlarını ve mevcut kullanıcının erişim izinlerini çok hızlı listeleyen C# aracıdır. |
| 3 | **PowerUpSQL** | [PowerUpSQL.md](./PowerUpSQL.md) | Etki alanındaki tüm Microsoft SQL Server örneklerini keşfeden, veritabanı bağlantı zincirlerini (linked servers) sömüren ve xp_cmdshell ile yetki yükselten PowerShell araç setidir. |
| 4 | **impacket-mssqlclient** | [impacket-mssqlclient.md](./impacket-mssqlclient.md) | Linux üzerinden TDS protokolüyle MSSQL veritabanlarına bağlanan, Windows/SQL kimlik doğrulaması yapan ve etkileşimli SQL kabuğu sunan araçtır. |
| 5 | **SharpSCCM** | [SharpSCCM.md](./SharpSCCM.md) | Microsoft Endpoint Configuration Manager (SCCM/MECM) altyapısını WMI üzerinden sorgulayarak sertifika çekme, komut yürütme ve etki alanı genelinde yetki yükseltme sağlayan C# aracıdır. |
| 6 | **MalSCCM** | [MalSCCM.md](./MalSCCM.md) | SCCM dağıtım noktalarını ve yönetim servislerini kötüye kullanarak yönetilen tüm uç noktalara zararlı yazılım ve ters kabuk dağıtan saldırı aracıdır. |
| 7 | **Lnkbomb** | [Lnkbomb.md](./Lnkbomb.md) | Açık SMB ağ paylaşımlarına zararlı `.url`/`.lnk` dosyaları enjekte ederek klasörü açan kullanıcıların NTLMv1/v2 hash'lerini toplayan ve otomatik temizlik yapan araçtır. |


---

> **Önceki Kategori:** [← Kategori 9](../Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/README.md) · **Sonraki Kategori:** [Kategori 11 →](../Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/README.md)
