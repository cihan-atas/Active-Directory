# 9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 11 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **bloodyAD** | [bloodyAD.md](./bloodyAD.md) | Doğrudan LDAP protokolü üzerinden parola sıfırlama, grup üyeliği ekleme, sahip değiştirme ve RBCD yapılandırması gerçekleştiren Python tabanlı AD yetki yükseltme aracıdır. |
| 2 | **aclpwn.py** | [aclpwn.md](./aclpwn.md) | BloodHound Neo4j veritabanını analiz ederek tespit ettiği zafiyetli ACL saldırı zincirlerini (GenericAll, WriteDacl vb.) otomatik olarak işleten exploit motorudur. |
| 3 | **SharpGPOAbuse** | [SharpGPOAbuse.md](./SharpGPOAbuse.md) | Düzenleme yetkisi bulunan Grup İlkelerine (GPO) arka planda Scheduled Task, yerel yönetici veya başlangıç betikleri enjekte eden C# aracıdır. |
| 4 | **pyGPOAbuse** | [pyGPOAbuse.md](./pyGPOAbuse.md) | SharpGPOAbuse işlevlerini Linux üzerinden uygulayarak yazma izni olan GPO'lar vasıtasıyla hedef sistemlerde uzaktan kod yürüten Python aracıdır. |
| 5 | **StandIn** | [StandIn.md](./StandIn.md) | Windows sistemlerinde C# ile Active Directory nesne özniteliklerini değiştiren, grup ekleyen ve dACL izinlerini manipüle eden bir post-exploitation aracıdır. |
| 6 | **PowerMad** | [PowerMad.md](./PowerMad.md) | Etki alanında standart kullanıcı hesabıyla yeni bilgisayar hesapları ekleme (MachineAccountQuota) ve DNS manipülasyonu sağlayan PowerShell modülüdür. |
| 7 | **impacket-addcomputer** | [impacket-addcomputer.md](./impacket-addcomputer.md) | SAMR veya LDAP protokolleri üzerinden etki alanına yeni bilgisayar hesapları ekleyerek RBCD ve sAMAccountName spoofing saldırılarını besleyen araçtır. |
| 8 | **impacket-rbcd** | [impacket-rbcd.md](./impacket-rbcd.md) | Hedef bilgisayar hesabının msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğini güncelleyerek Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD) kuran araçtır. |
| 9 | **dsacls** | [dsacls.md](./dsacls.md) | Windows yerleşik komut satırı aracıdır; Active Directory nesnelerinin erişim denetim listelerini (DACL/SACL) görüntülemek ve izin ekleyip kaldırmak için kullanılır. |
| 10 | **Incognito** | [Incognito.md](./Incognito.md) | Hedef makinedeki erişim belirteçlerini (access tokens) listeleyen ve yönetici belirteçlerini taklit ederek yetki yükselten klasik token avı aracıdır. |
| 11 | **Tokenvator** | [Tokenvator.md](./Tokenvator.md) | Windows ayrıcalıklarını denetleyen, UAC kısıtlamalarını aşan ve mevcut süreçlerin güvenlik belirteçlerini çalarak taklit eden gelişmiş C# belirteç aracıdır. |


---

> **Önceki Kategori:** [← Kategori 8](../Kategori_08_Active_Directory_Sertifika_Servisleri/README.md) · **Sonraki Kategori:** [Kategori 10 →](../Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/README.md)
