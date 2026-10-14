# 2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 15 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **nltest** | [nltest.md](./nltest.md) | Etki alanı denetleyicilerini (/dclist), güven ilişkilerini (/domain_trusts) ve güvenli kanal (Secure Channel) durumunu sorgulamak için kullanılan yerleşik Windows aracıdır. |
| 2 | **net.exe** | [net.md](./net.md) | Yerel ve etki alanı kullanıcılarını (net user /domain), grup üyeliklerini ve parola politikalarını yönetmek veya keşfetmek için kullanılan temel Windows komutudur. |
| 3 | **dsquery / dsget** | [dsquery_dsget.md](./dsquery_dsget.md) | Active Directory hiyerarşisindeki nesneleri (kullanıcı, bilgisayar, OU, grup) aramak ve özniteliklerini komut satırından dökümlemek için kullanılan yerleşik dizin araçlarıdır. |
| 4 | **klist** | [klist.md](./klist.md) | Mevcut Windows oturumunun belleğinde saklanan Kerberos biletlerini (TGT/TGS) görüntülemek, temizlemek (purge) ve SPN bileti talep etmek için kullanılır. |
| 5 | **certutil** | [certutil.md](./certutil.md) | Sertifika yetkilisi (CA) bilgilerini ve şablonlarını sorgulamanın yanı sıra, uzaktan dosya indirme ve Base64 kod çözme amacıyla kötüye kullanılan bir LOLBin aracıdır. |
| 6 | **whoami** | [whoami.md](./whoami.md) | Mevcut kullanıcının SID değerini, dahil olduğu grupları ve sahip olduğu güvenlik belirteci ayrıcalıklarını (/priv) görüntülemek için kullanılır. |
| 7 | **cmdkey** | [cmdkey.md](./cmdkey.md) | Windows Kimlik Yöneticisi (Credential Manager) kasasında saklanan kayıtlı RDP, uzak sunucu ve ağ kimlik bilgilerini listelemek veya eklemek için kullanılır. |
| 8 | **gpresult** | [gpresult.md](./gpresult.md) | Hedef makine ve kullanıcı üzerinde uygulanan Grup İlkelerini (GPO) ve İlke Sonuç Kümesini (RSoP) detaylı analiz etmek için kullanılır. |
| 9 | **reg.exe** | [reg.md](./reg.md) | Windows Kayıt Defteri'ni komut satırından sorgulamak ve yerel parola hash'lerini içeren SAM, SYSTEM ve SECURITY kovanlarını diske kopyalamak için kullanılır. |
| 10 | **sc.exe** | [sc.md](./sc.md) | Windows servislerini yerel veya uzaktan oluşturmak (sc create), yapılandırmak ve başlatmak (sc start) suretiyle yetki yükseltme ve yanal hareket için kullanılan servis yöneticisidir. |
| 11 | **schtasks.exe** | [schtasks.md](./schtasks.md) | Zamanlanmış görevler oluşturarak (/create) yerel veya uzak sistemlerde belirlenen zamanda yetkili komut çalıştırmak ve kalıcılık sağlamak için kullanılır. |
| 12 | **wmic.exe** | [wmic.md](./wmic.md) | Windows Yönetim Araçları (WMI) arayüzü üzerinden sistem bilgilerini sorgulamak ve uzaktan süreç başlatmak (process call create) için kullanılan komut satırı aracıdır. |
| 13 | **ADExplorer** | [ADExplorer.md](./ADExplorer.md) | Sysinternals tarafından geliştirilen; canlı Active Directory veritabanında gezinmeyi, anlık snapshot almayı ve iki snapshot arasındaki yetki değişikliklerini karşılaştırmayı sağlayan gelişmiş GUI aracıdır. |
| 14 | **LDP.exe** | [LDP.md](./LDP.md) | Microsoft'un dahili gelişmiş LDAP yönetim aracıdır; Active Directory dizin ağacında derinlemesine arama, öznitelik inceleme ve güvenlik tanımlayıcısı (Security Descriptor) analizi için kullanılır. |
| 15 | **ProcDump** | [ProcDump.md](./ProcDump.md) | Sysinternals imzalı meşru bir araçtır; LSASS bellek alanını diske mini-dump olarak kaydederek parola hash'lerinin ve Kerberos biletlerinin çevrimdışı analiz edilmesini sağlar. |


---

> **Önceki Kategori:** [← Kategori 1](../Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/README.md) · **Sonraki Kategori:** [Kategori 3 →](../Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/README.md)
