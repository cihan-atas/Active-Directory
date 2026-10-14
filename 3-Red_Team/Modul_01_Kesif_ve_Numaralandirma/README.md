# 🔴 Modül 01 — Keşif ve Numaralandırma (Reconnaissance & Discovery)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Keşif ve Ağ Haritalama (Reconnaissance / Discovery)  
> **Simetrik Savunma Karşılığı:** [Blue M01 — Görünürlük ve Log Yönetimi](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/) & [Blue M09 — Tehdit Avcılığı](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/)  
> **Sistem Tabanı:** [Sistem M01 — Mimari ve Temeller](../../1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/) & [Sistem M03 — Nesne ve Kimlik Yönetimi](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Keşif Felsefesi

Active Directory güvenliğinde değişmez bir temel kural vardır: **Kimliği doğrulanmış (authenticated) herhangi bir etki alanı kullanıcısı veya makine hesabı, dizin veritabanının (NTDS.dit) büyük bir bölümünü doğal haklarıyla okuyabilir.** Bu durum bir yazılım hatası veya güvenlik açığı değil; Kerberos bilet değişimi, grup ilkesi dağıtımı, LDAP ad çözümleme ve etki alanı işlevselliği için Microsoft tarafından tasarlanmış meşru bir çalışma modelidir.

Saldırganlar ve kırmızı takım operatörleri açısından bu tasarım, hiçbir zafiyet sömürüsüne (exploit) başvurmadan ortamın tüm topolojisini, yüksek ayrıcalıklı hesapları, servis hesaplarını, zayıf izinli nesneleri (ACL) ve güven ilişkilerini çıkarma imkânı tanır.

> **💡 Operasyonel İlke:**  
> *"Keşif ucuz ve sessizdir; sömürü gürültülü ve maliyetlidir. Başarılı bir sızma testi veya kırmızı takım tatbikatının %80'i keşif aşamasında kazanılır. Rastgele parola denemek yerine doğru hedefi önceden tespit etmek, EDR/SIEM radarına yakalanma riskini en aza indirir."*

---

## 2. Keşif Yaşam Döngüsü ve Mimari Akış

Bir etki alanında keşif süreci rastgele araç çalıştırmakla değil, kademeli bir mantık zinciriyle yürütülür:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ETKİ ALANI KEŞİF YAŞAM DÖNGÜSÜ                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Anonim / Yetkisiz Keşif (Unauthenticated)]
           - TCP/389 RootDSE sorgusu (namingContexts, DC adları, Forest seviyesi)
           - NetBIOS / LLMNR / mDNS pasif dinleme
           - Araçlar: ldapsearch, nxc, Responder
                                      │
                                      ▼
           [Aşama 2: Kimlikli Temel LDAP Numaralandırması]
           - Parola kilitlenme politikası (--pass-pol) sorgulama
           - DONT_REQ_PREAUTH hesapları (AS-REP Roasting havuzu)
           - SPN tanımlı hesaplar (Kerberoasting havuzu)
           - Araçlar: NetExec (nxc), windapsearch, ldapdomaindump, AdFind
                                      │
                                      ▼
           [Aşama 3: Graf Tabanlı İlişki ve Oturum Haritalama]
           - DCOnly LDAP toplaması veya yerel oturum (Session) avcılığı
           - Nesne ilişkileri (MemberOf, AdminTo, HasSession, WriteDacl)
           - Araçlar: SharpHound, BloodHound CE, RustHound, AzureHound
                                      │
                                      ▼
           [Aşama 4: İzinler (ACL), İlkeler (GPO) ve Nesne Derinliği]
           - Tehlikeli ACE izinleri: GenericAll, WriteOwner, AddKeyCredentialLink
           - SYSVOL / GPO izinleri ve yerel admin dağıtan GPP'ler
           - Araçlar: PowerView, SharpView, StandIn, LDP.exe
                                      │
                                      ▼
           [Aşama 5: Forest ve Güven İlişkileri (Trusts)]
           - İki yönlü/tek yönlü trust'lar, transitiflik ve SID Filtering analizi
           - Araçlar: nltest, dsquery, PowerView (Get-DomainTrust)
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **01.1** | [LDAP Enumerasyonu](./01.1_LDAP_Enumerasyonu.md) | RootDSE mekanizması, Partition'lar (Domain, Configuration, Schema), Global Catalog (3268), LDAP bit filtreleri (1.2.840.113556.1.4.803), ASN.1 BER ve MaxPageSize sayfalaması. |
| **01.2** | [SharpHound ve BloodHound](./01.2_SharpHound_ve_BloodHound.md) | Graf veri modeli, toplayıcı metotları (CollectionMethods), HasSession kenarı ile avlanma, Cypher sorguları ile en kısa DA yolunu tespit etme. |
| **01.3** | [Kullanıcı, Grup, ACL, SPN, ADI-DNS ve Paylaşım Keşfi](./01.3_Kullanici_Grup_ACL_SPN_Kesfi.md) | SPN keşfi ile Kerberoast havuzu, ADI-DNS (adidnsdump), Snaffler ile ağ paylaşımları ve loot avı, gMSA/dMSA parola okuma yetkileri, tehlikeli DACL hakları (GenericAll, WriteDacl) ve GPO sömürü yüzeyi. |
| **01.4** | [Trust ve Forest Enumerasyonu](./01.4_Trust_ve_Forest_Enumerasyonu.md) | Forest güvenlik sınırları, trust yönü ve transitiflik, `trustAttributes` bayrakları, SID filtering ve cross-forest sıçrama öncesi haritalama. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Bu modüldeki keşif ve numaralandırma tekniklerinin sahada icra edilmesinde kullanılan başlıca araçların komut rehberleri ve parametre analizleri Modül 11 altında detaylandırılmıştır:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **NetExec (nxc)** | [NetExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md) | LDAP modülü ile kullanıcı, parola politikası, SPN ve yetki devri bilgilerini tek satırda sorgulayan çok protokollü keşif aracı. |
| 02 | **BloodHound CE** | [BloodHound_CE.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/BloodHound_CE.md) | Active Directory nesneleri arasındaki karmaşık erişim ve yetki ilişkilerini graf teorisiyle modelleyen saldırı yolu analiz platformu. |
| 03 | **SharpHound** | [SharpHound.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/SharpHound.md) | Windows hedef sistemler üzerinde LDAP, SAMR ve RPC sorgularıyla BloodHound için veri toplayan resmi C# ajanı. |
| 04 | **PowerView** | [PowerView.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/PowerView.md) | PowerShell ortamında etki alanı nesnelerini, SPN'leri, DACL izinlerini ve GPO'ları derinlemesine numaralandıran PowerSploit aracı. |
| 05 | **SharpView** | [SharpView.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/SharpView.md) | PowerView işlevlerini PowerShell kısıtlamalarını atlatmak üzere saf .NET/C# assembly olarak sunan keşif aracı. |
| 06 | **AdFind** | [AdFind.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/AdFind.md) | Windows komut satırından hızlı ve esnek LDAP sorguları çalıştırmaya yarayan güçlü yerel LOLBin aracı. |
| 07 | **ldapdomaindump** | [ldapdomaindump.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/ldapdomaindump.md) | Tüm Active Directory dizin hiyerarşisini LDAP üzerinden çekip çevrimdışı taranabilir HTML/JSON/Greppable raporlara dönüştüren Python aracı. |
| 08 | **ADExplorer** | [ADExplorer.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/ADExplorer.md) | Sysinternals ailesinden AD veritabanını anlık gezinmeye ve çevrimdışı snapshot (.dat) almaya yarayan sessiz GUI aracı. |
| 09 | **LDP.exe** | [LDP.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/LDP.md) | Windows yerleşik grafiksel LDAP/LDAPS istemcisi; EDR filtrelerini atlatarak dizin araması yapmaya olanak tanır. |
| 10 | **dsquery / dsget** | [dsquery_dsget.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/dsquery_dsget.md) | Windows Server yerleşik komut satırı aracı; harici dosya yüklemeden SPN, kullanıcı ve bilgisayar listelemeyi sağlar. |
| 11 | **nltest** | [nltest.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/nltest.md) | Netlogon servisini sorgulayarak etki alanı denetleyicilerini, site bilgilerini ve güven ilişkilerini listeleyen yerel LOLBin. |
| 12 | **adalanche** | [adalanche.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/adalanche.md) | Harici veritabanına ihtiyaç duymadan tek bir ikili dosyayla çalışan yüksek performanslı AD graf ve yetki analiz motoru. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

Keşif aşaması çoğunlukla standart LDAP protokolü üzerinden yürütüldüğünden geleneksel antivirüs yazılımları tarafından tespit edilmesi zordur. Ancak gelişmiş izleme mekanizmalarıyla görünür kılınabilir:

- **1644 Event ID (Dizin Hizmeti Pahalı/Verimsiz Aramalar):** DC üzerinde `15 Field Engineering` loglama seviyesi açılarak geniş kapsamlı `(objectClass=*)` sorguları yakalanabilir.
- **Sysmon Event ID 1 & 3:** SharpHound veya AdFind gibi araçların uç noktada çalıştırılması ve TCP/389 bağlantıları korelasyonla tespit edilir.
- **RPC/SAMR Denetimi:** SharpHound oturum toplaması (`Session`) sırasında çok sayıda uç noktaya yapılan `NetSessionEnum` çağrıları NDR ve host loglarında anomali oluşturur.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M01 — Görünürlük ve Log Yönetimi](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
  - [Blue M05 — Yetki ve ACL Sıkılaştırma](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/)
  - [Blue M09 — Tehdit Avcılığı ve Değerlendirme](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan keşif teknikleri, LDAP filtreleri ve komut senaryoları; **yalnızca yasal sınırlar dahilinde gerçekleştirilen yetkili sızma testleri, kırmızı takım tatbikatları ve laboratuvar eğitimleri** amacıyla sunulmuştur.
>
> Yazılı izin ve yetkilendirme belgesi bulunmaksızın bir kurumsal dizin üzerinde yetkisiz numaralandırma veya sorgu çalıştırmak, 5237 Sayılı TCK Madde 243 ve ilgili uluslararası siber suç mevzuatları uyarınca suç teşkil edebilir. Proje yazarları, bilgilerin amacı dışında kullanımından sorumlu tutulamaz.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Active Directory Enumeration (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/enumeration/): LDAP filtreleme, SPN keşfi ve referans komutlar.
- 🌐 [HackTricks Wiki — Active Directory Enumeration (Carlos Polop)](https://book.hacktricks.wiki/): LDAP, BloodHound, RPC ve SAMR numaralandırma yöntemleri.
- 🌐 [The Hacker Recipes — Active Directory Recon](https://www.thehacker.recipes/): LDAP sorguları, BloodHound toplama teknikleri ve yetki analizi.
- 🌐 [SpecterOps — BloodHound Documentation](https://posts.specterops.io/): Graf tabanlı saldırı yolları ve ACE analizi.
- 🌐 [Microsoft Open Specifications [MS-ADTS]](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/): Active Directory Technical Specification.

---

> **Sonraki Modül:** [Modül 02 — İlk Erişim ve Yerleşme →](../Modul_02_Ilk_Erisim_ve_Yerlesme/README.md)
