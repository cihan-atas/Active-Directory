# Modül 11 — Kırmızı Takım Araç Cephaneliği ve Komut Rehberi

> **Kol:** 🔴 Red Team (Saldırı) · **Kapsam:** 18 Kategori · 145 Araç  
> **Amaç:** Active Directory sızma testleri ve kırmızı takım operasyonlarında kullanılan tüm araçların operasyonel komut referansı, protokol mimarisi, OPSEC/tespit analizleri ve parametre kütüphanesi.

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> [!CAUTION]
> **Yalnızca Yetkili ve Yasal Testler İçindir:** Bu modülde yer alan araçlar, komutlar, istismar teknikleri ve metodolojiler; yalnızca yasal izinleri alınmış sızma testleri (penetration testing), kırmızı takım (red teaming) tatbikatları ve savunma ekiplerinin (blue team) tespit yeteneklerini güçlendirmesi amacıyla hazırlanmıştır.
> Yetkisiz sistemlere yönelik gerçekleştirilecek herhangi bir tarama, istismar veya yetki yükseltme faaliyeti yasa dışıdır ve Türk Ceza Kanunu (Madde 243-245) ile uluslararası siber suç mevzuatları kapsamında cezai sorumluluk doğurur. Bu dokümantasyonun kötü niyetli kullanımından doğacak her türlü hukuki ve cezai sorumluluk doğrudan uygulayıcıya aittir.

### 📚 Yararlanılan Başlıca Açık Kaynaklar ve Metodolojiler
* [InternalAllTheThings — Active Directory Methodology (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/)
* [HackTricks Wiki — Active Directory Methodology](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/index.html)
* [The Hacker Recipes — Active Directory Exploitation](https://www.thehacker.recipes/)
* [MITRE ATT&CK® Enterprise Matrix](https://attack.mitre.org/)
* [Microsoft Open Specifications (MS-NRPC, MS-SAMR, MS-DRSR, MS-KILE, MS-RPRN)](https://learn.microsoft.com/en-us/openspecs/)

---

## 🗂️ Kategori İndeksi

1. [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/README.md) — *(11 araç)*
2. [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/README.md) — *(15 araç)*
3. [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/README.md) — *(19 araç)*
4. [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md) — *(13 araç)*
5. [5. NTLM VE KERBEROS RELAY MOTORLARI (RELAY ENGINES)](Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/README.md) — *(3 araç)*
6. [6. KERBEROS PROTOKOL CEPHANELİĞİ (KERBEROS SUITE)](Kategori_06_Kerberos_Protokol_Cephaneligi/README.md) — *(10 araç)*
7. [7. BELLEK ANALİZİ, LSASS DÖKÜMÜ VE KASA HASADI (CREDENTIAL HARVESTING & DPAPI)](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/README.md) — *(17 araç)*
8. [8. ACTIVE DIRECTORY SERTİFİKA SERVİSLERİ (AD CS / PKI EXPLOITATION)](Kategori_08_Active_Directory_Sertifika_Servisleri/README.md) — *(7 araç)*
9. [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/README.md) — *(11 araç)*
10. [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/README.md) — *(6 araç)*
11. [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/README.md) — *(9 araç)*
12. [12. NTDS.DIT, GPO ŞİFRELERİ VE LAPS HASADI (CREDENTIAL DUMPING & LAPS)](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/README.md) — *(8 araç)*
13. [13. TARİHİ VE KRİTİK ZAFİYET İSTİSMAR ARAÇLARI (EXPLOIT TOOLING)](Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/README.md) — *(4 araç)*
14. [14. AD FS, BULUT VE HİBRİT KİMLİK (FEDERATION & HYBRID PIVOT)](Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/README.md) — *(3 araç)*
15. [15. YEREL YETKİ YÜKSELTME (LPE) VE POTATO AİLESİ](Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/README.md) — *(3 araç)*
16. [16. TÜNELLEME, PİVOT VE SOCKS PROXY (PIVOTING & TUNNELING)](Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/README.md) — *(3 araç)*
17. [17. MODERN EDR-SAFE BEACON OBJECT FILES (AD BOFS)](Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/README.md) — *(1 araç)*
18. [18. ÇEVRİMDIŞI PAROLA KIRMA (OFFLINE CRACKING)](Kategori_18_Cevrimdisi_Parola_Kirma/README.md) — *(2 araç)*

---

## 🛠️ Kategori ve Araç Cephaneliği Detaylı Listesi

### 📁 Kategori 1: [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **smbclient** | [smbclient.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/smbclient.md) | Samba paketinin CLI istemcisidir; SMB/CIFS paylaşımlarını listelemek, dosya transferi yapmak ve oturumsuz (null session) keşif gerçekleştirmek için kullanılır. |
| 2 | **smbmap** | [smbmap.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/smbmap.md) | Ağdaki SMB paylaşımlarının okuma/yazma izinlerini otomatik denetleyen ve hassas dosyaları regex kalıplarıyla tarayan yetki denetim aracıdır. |
| 3 | **impacket-smbclient** | [impacket-smbclient.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/impacket-smbclient.md) | Pass-the-Hash (PTH) ve Kerberos biletleri ile uzak SMB paylaşımlarına bağlanıp dosya yönetimi ve komut yürütme sağlayan Python istemcisidir. |
| 4 | **mount.cifs** | [mount.cifs.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/mount.cifs.md) | Uzak Windows ve SMB paylaşımlarını Linux dosya sistemine yerel bir dizin olarak bağlayarak grep ve find gibi Linux araçlarıyla derin dosya analizi yapmayı sağlar. |
| 5 | **ldapsearch** | [ldapsearch.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/ldapsearch.md) | OpenLDAP paketinin komut satırı aracıdır; OID bitwise filtreleri ve sayfalama desteğiyle Active Directory veritabanında derinlemesine nesne ve yetki sorgulaması yapar. |
| 6 | **windapsearch** | [windapsearch.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/windapsearch.md) | SPN taşıyan hesapları, kısıtlanmamış yetki devirlerini (unconstrained delegation) ve etki alanı yöneticilerini hızlıca keşfetmek için geliştirilmiş pratik LDAP keşif aracıdır. |
| 7 | **rpcclient** | [rpcclient.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/rpcclient.md) | Samba MS-RPC arayüz istemcisidir; SAMR ve LSA named pipe'ları üzerinden kullanıcı/grup listeleme, RID cycling ve parola politikası keşfi için kullanılır. |
| 8 | **impacket-rpcdump** | [impacket-rpcdump.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/impacket-rpcdump.md) | Port 135 RPC Endpoint Mapper üzerinden hedef sistemde kayıtlı RPC arayüzlerini ve UUID değerlerini listeleyerek zafiyetli servisleri tespit eder. |
| 9 | **impacket-samrdump** | [impacket-samrdump.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/impacket-samrdump.md) | SAMR protokolünü sorgulayarak hedef sistemdeki yerel ve etki alanı kullanıcılarını, gruplarını ve parola kilitleme politikalarını döker. |
| 10 | **enum4linux-ng** | [enum4linux-ng.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/enum4linux-ng.md) | SMB, RPC, LDAP ve NetBIOS protokollerini birleştirerek Windows ve Samba sistemlerinden kullanıcı, grup, paylaşım ve işletim sistemi bilgilerini toplayan hepsi bir arada keşif aracıdır. |
| 11 | **nmap (NSE Script)** | [nmap_NSE_Script.md](Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/nmap_NSE_Script.md) | Nmap script motoru üzerinden SMB imzalama zorunluluğunu (SMB Signing), işletim sistemi sürümlerini ve MS17-010 gibi kritik zafiyetleri denetleyen ağ tarama aracıdır. |

### 📁 Kategori 2: [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **nltest** | [nltest.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/nltest.md) | Etki alanı denetleyicilerini (/dclist), güven ilişkilerini (/domain_trusts) ve güvenli kanal (Secure Channel) durumunu sorgulamak için kullanılan yerleşik Windows aracıdır. |
| 2 | **net.exe** | [net.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/net.md) | Yerel ve etki alanı kullanıcılarını (net user /domain), grup üyeliklerini ve parola politikalarını yönetmek veya keşfetmek için kullanılan temel Windows komutudur. |
| 3 | **dsquery / dsget** | [dsquery_dsget.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/dsquery_dsget.md) | Active Directory hiyerarşisindeki nesneleri (kullanıcı, bilgisayar, OU, grup) aramak ve özniteliklerini komut satırından dökümlemek için kullanılan yerleşik dizin araçlarıdır. |
| 4 | **klist** | [klist.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/klist.md) | Mevcut Windows oturumunun belleğinde saklanan Kerberos biletlerini (TGT/TGS) görüntülemek, temizlemek (purge) ve SPN bileti talep etmek için kullanılır. |
| 5 | **certutil** | [certutil.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/certutil.md) | Sertifika yetkilisi (CA) bilgilerini ve şablonlarını sorgulamanın yanı sıra, uzaktan dosya indirme ve Base64 kod çözme amacıyla kötüye kullanılan bir LOLBin aracıdır. |
| 6 | **whoami** | [whoami.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/whoami.md) | Mevcut kullanıcının SID değerini, dahil olduğu grupları ve sahip olduğu güvenlik belirteci ayrıcalıklarını (/priv) görüntülemek için kullanılır. |
| 7 | **cmdkey** | [cmdkey.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/cmdkey.md) | Windows Kimlik Yöneticisi (Credential Manager) kasasında saklanan kayıtlı RDP, uzak sunucu ve ağ kimlik bilgilerini listelemek veya eklemek için kullanılır. |
| 8 | **gpresult** | [gpresult.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/gpresult.md) | Hedef makine ve kullanıcı üzerinde uygulanan Grup İlkelerini (GPO) ve İlke Sonuç Kümesini (RSoP) detaylı analiz etmek için kullanılır. |
| 9 | **reg.exe** | [reg.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/reg.md) | Windows Kayıt Defteri'ni komut satırından sorgulamak ve yerel parola hash'lerini içeren SAM, SYSTEM ve SECURITY kovanlarını diske kopyalamak için kullanılır. |
| 10 | **sc.exe** | [sc.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/sc.md) | Windows servislerini yerel veya uzaktan oluşturmak (sc create), yapılandırmak ve başlatmak (sc start) suretiyle yetki yükseltme ve yanal hareket için kullanılan servis yöneticisidir. |
| 11 | **schtasks.exe** | [schtasks.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/schtasks.md) | Zamanlanmış görevler oluşturarak (/create) yerel veya uzak sistemlerde belirlenen zamanda yetkili komut çalıştırmak ve kalıcılık sağlamak için kullanılır. |
| 12 | **wmic.exe** | [wmic.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/wmic.md) | Windows Yönetim Araçları (WMI) arayüzü üzerinden sistem bilgilerini sorgulamak ve uzaktan süreç başlatmak (process call create) için kullanılan komut satırı aracıdır. |
| 13 | **ADExplorer** | [ADExplorer.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/ADExplorer.md) | Sysinternals tarafından geliştirilen; canlı Active Directory veritabanında gezinmeyi, anlık snapshot almayı ve iki snapshot arasındaki yetki değişikliklerini karşılaştırmayı sağlayan gelişmiş GUI aracıdır. |
| 14 | **LDP.exe** | [LDP.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/LDP.md) | Microsoft'un dahili gelişmiş LDAP yönetim aracıdır; Active Directory dizin ağacında derinlemesine arama, öznitelik inceleme ve güvenlik tanımlayıcısı (Security Descriptor) analizi için kullanılır. |
| 15 | **ProcDump** | [ProcDump.md](Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/ProcDump.md) | Sysinternals imzalı meşru bir araçtır; LSASS bellek alanını diske mini-dump olarak kaydederek parola hash'lerinin ve Kerberos biletlerinin çevrimdışı analiz edilmesini sağlar. |

### 📁 Kategori 3: [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **BloodHound CE** | [BloodHound_CE.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/BloodHound_CE.md) | Active Directory ortamlarındaki karmaşık yetki ilişkilerini, ACL izinlerini ve gizli saldırı yollarını Neo4j/PostgreSQL graf veritabanında görselleştiren modern analiz platformudur. |
| 2 | **SharpHound** | [SharpHound.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/SharpHound.md) | BloodHound için C# ile yazılmış veri toplayıcısıdır; LDAP, SMB ve yerel oturumları tarayarak graf analizinde kullanılacak JSON verilerini üretir. |
| 3 | **BloodHound.py** | [BloodHound.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/BloodHound.md) | Linux ortamından etki alanı kimlik bilgileriyle Active Directory nesnelerini tarayıp BloodHound uyumlu JSON dosyaları üreten Python tabanlı veri toplayıcıdır. |
| 4 | **AzureHound** | [AzureHound.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/AzureHound.md) | Microsoft Entra ID (Azure AD) ortamlarındaki rolleri, kullanıcıları, servis sorumlularını ve bulut saldırı yollarını BloodHound grafiğine aktaran toplayıcıdır. |
| 5 | **PowerView** | [PowerView.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/PowerView.md) | Active Directory etki alanını derinlemesine haritalamak, kullanıcıları, grupları, GPO'ları ve ACL yetkilerini sorgulamak için kullanılan efsanevi PowerShell keşif kütüphanesidir. |
| 6 | **SharpView** | [SharpView.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/SharpView.md) | PowerView işlevlerinin C# ile yeniden yazılmış halidir; PowerShell çalıştırmadan doğrudan .NET bellek alanında Active Directory keşfi yürütür. |
| 7 | **pywerview** | [pywerview.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/pywerview.md) | PowerView mantığını Linux platformuna taşıyan, Python tabanlı LDAP ve RPC sorgularıyla etki alanı keşfi yapan bir kütüphanedir. |
| 8 | **ADRecon** | [ADRecon.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/ADRecon.md) | Active Directory ormanının tüm kullanıcı, bilgisayar, GPO, DNS, trust ve sertifika yapılandırmasını tarayıp kapsamlı bir Excel raporu üreten PowerShell aracıdır. |
| 9 | **linWinPwn** | [linWinPwn.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/linWinPwn.md) | Linux üzerinden birden fazla AD keşif ve istismar aracını otomatize ederek etki alanındaki zafiyetleri ve yetki yükseltme yollarını hızla tarayan bash çerçevesidir. |
| 10 | **ldapdomaindump** | [ldapdomaindump.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/ldapdomaindump.md) | LDAP üzerinden tüm etki alanı nesnelerini (kullanıcılar, bilgisayarlar, gruplar, trust'lar) çekerek insan tarafından okunabilir HTML ve JSON raporlarına dönüştüren araçtır. |
| 11 | **ldeep** | [ldeep.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/ldeep.md) | Python ile yazılmış LDAP sorgulama aracıdır; etki alanı parolalarını, SPN'leri, delegasyon izinlerini ve güvenlik gruplarını hızlıca listeler. |
| 12 | **adalanche** | [adalanche.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/adalanche.md) | Active Directory ACL ve yetki ilişkilerini haritalayan, saldırı yollarını görselleştiren Go tabanlı bağımsız bir graf analiz aracıdır. |
| 13 | **AdFind** | [AdFind.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/AdFind.md) | Joeware tarafından geliştirilen; son derece hızlı, esnek ve güçlü filtrelerle Active Directory LDAP veritabanını komut satırından sorgulayan araçtır. |
| 14 | **AdMod** | [AdMod.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/AdMod.md) | Active Directory nesnelerinin özniteliklerini (örneğin SPN, logonScript, açıklama alanları) komut satırından toplu olarak değiştirmek için kullanılan yönetim aracıdır. |
| 15 | **adidnsdump** | [adidnsdump.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/adidnsdump.md) | Active Directory Entegre DNS (ADI-DNS) bölgelerini LDAP üzerinden sorgulayarak iç ağdaki tüm sunucu ve IP adreslerini haritalayan araçtır. |
| 16 | **dnstool.py** | [dnstool.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/dnstool.md) | Active Directory DNS veritabanına uzaktan yeni DNS A veya PTR kayıtları ekleyerek Ortadaki Adam (MitM) ve relay saldırılarını tetikleyen Python aracıdır. |
| 17 | **Kerbrute** | [Kerbrute.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/Kerbrute.md) | Kerberos Pre-Authentication (AS-REQ) isteklerini kullanarak hedef kullanıcı hesaplarını kilitlemeden doğrulamak ve parola püskürtme yapmak için kullanılan Go tabanlı hızlı araçtır. |
| 18 | **DomainPasswordSpray** | [DomainPasswordSpray.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/DomainPasswordSpray.md) | Etki alanındaki tüm kullanıcı hesaplarına lockout ilkesini dikkate alarak tek bir parola püskürten (password spraying) PowerShell betiğidir. |
| 19 | **Spray-Passwords** | [Spray-Passwords.md](Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/Spray-Passwords.md) | Çeşitli protokoller üzerinden etki alanı kullanıcılarına kontrollü parola püskürtme saldırıları düzenleyen alternatif bir otomasyon scriptidir. |

### 📁 Kategori 4: [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Responder** | [Responder.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Responder.md) | Kurumsal ağda LLMNR, NBT-NS ve mDNS yayınlarını zehirleyerek sahte SMB/HTTP sunucuları üzerinden NetNTLM kimlik doğrulama hash'lerini yakalayan lider zehirleme aracıdır. |
| 2 | **Inveigh** | [Inveigh.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Inveigh.md) | Windows sistemlerde yerel olarak çalışan, LLMNR/mDNS/NBNS sahteciliği ile kimlik yakalayan C# ve PowerShell tabanlı Responder alternatifidir. |
| 3 | **mitm6** | [mitm6.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/mitm6.md) | Windows makinelerin varsayılan IPv6 yapılandırmasını istismar ederek sahte DHCPv6 DNS sunucusu olan ve trafiği NTLM relay saldırılarına yönlendiren MitM aracıdır. |
| 4 | **PetitPotam** | [PetitPotam.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/PetitPotam.md) | MS-EFSRPC protokolünü kullanarak hedef sunucuları (özellikle etki alanı denetleyicilerini) saldırganın dinleyicisine NTLM doğrulaması yapmaya zorlayan coerce aracıdır. |
| 5 | **SpoolSample** | [SpoolSample.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/SpoolSample.md) | MS-RPRN Print System protokolü (PrinterBug) üzerinden etki alanı denetleyicisini belirlenen bir SMB hedefine NTLM doğrulaması yapmaya zorlayan araçtır. |
| 6 | **DFSCoerce** | [DFSCoerce.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/DFSCoerce.md) | MS-DFSNM (Distributed File System Namespace) protokolü üzerinden Windows sunuculardan saldırgana zorlamalı NTLM kimlik doğrulaması tetikleyen araçtır. |
| 7 | **ShadowCoerce** | [ShadowCoerce.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/ShadowCoerce.md) | MS-FSRVP (File Server Remote VSS Protocol) arayüzünü kullanarak Windows sunucuları saldırganın kontrolündeki hedefe kimlik doğrulamaya zorlayan araçtır. |
| 8 | **PrivExchange** | [PrivExchange.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/PrivExchange.md) | Microsoft Exchange Server EWS PushSubscription bildirim zafiyetini kullanarak Exchange makine hesabını saldırgana NTLM doğrulaması yapmaya zorlayan araçtır. |
| 9 | **Dementor** | [Dementor.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Dementor.md) | MS-RPRN (PrinterBug) yöntemini Python ile uygulayarak uzaktaki Windows sunuculardan zorlamalı SMB kimlik doğrulaması başlatan hafif bir araçtır. |
| 10 | **Coercer** | [Coercer.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Coercer.md) | PetitPotam, SpoolSample, DFSCoerce ve ShadowCoerce dahil olmak üzere tüm zorlamalı kimlik doğrulama yöntemlerini tek bir çatı altında toplayan gelişmiş araçtır. |
| 11 | **Pre2k** | [Pre2k.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Pre2k.md) | Active Directory'deki eski işletim sistemi (Windows 2000 öncesi) bilgisayar hesaplarının varsayılan zayıf makine parolalarını sömüren araçtır. |
| 12 | **Crop** | [Crop.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Crop.md) | WebDAV servisi üzerinden Windows kullanıcı ve servis hesaplarını dış hedefe kimlik doğrulamaya zorlayan bir coerce aracıdır. |
| 13 | **Farmer** | [Farmer.md](Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Farmer.md) | Sahte WebDAV sunucusu ayağa kaldırarak ve kurban makinelerde SCF/LNK dosyaları tetikleyerek NetNTLM hash'lerini toplayan C# tabanlı bir araçtır. |

### 📁 Kategori 5: [5. NTLM VE KERBEROS RELAY MOTORLARI (RELAY ENGINES)](Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **impacket-ntlmrelayx** | [impacket-ntlmrelayx.md](Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/impacket-ntlmrelayx.md) | Yakalanan SMB veya HTTP NTLM kimlik doğrulama isteklerini LDAP, LDAPS, MSSQL ve IMAP servislerine aktararak RBCD kurma, kullanıcı oluşturma veya AD CS sertifikası alma işlemlerini gerçekleştiren relay motorudur. |
| 2 | **KrbRelay** | [KrbRelay.md](Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/KrbRelay.md) | Windows yerel makinesindeki SYSTEM veya servis hesaplarını COM/RPC üzerinden hedef SPN'e yönlendirerek Kerberos AP-REQ biletlerini LDAP veya HTTP servislerine aktaran yerel relay aracıdır. |
| 3 | **KrbRelayUp** | [KrbRelayUp.md](Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/KrbRelayUp.md) | KrbRelay, RBCD, Shadow Credentials ve Rubeus (S4U2Proxy) adımlarını tek bir komutta zincirleyerek standart kullanıcıdan doğrudan yerel SYSTEM haklarına yükselen hepsi bir arada yetki yükseltme aracıdır. |

### 📁 Kategori 6: [6. KERBEROS PROTOKOL CEPHANELİĞİ (KERBEROS SUITE)](Kategori_06_Kerberos_Protokol_Cephaneligi/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Rubeus** | [Rubeus.md](Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Kerberos bilet yönetimi, Kerberoasting, AS-REP Roasting, S4U delegasyon istismarı, Pass-the-Ticket, Golden/Silver/Diamond ticket üretimi için geliştirilmiş en kapsamlı C# Kerberos aracıdır. |
| 2 | **impacket-GetUserSPNs** | [impacket-GetUserSPNs.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-GetUserSPNs.md) | Active Directory'de Service Principal Name (SPN) barındıran servis hesaplarını listeleyen ve çevrimdışı parola kırma için TGS biletlerini indiren (Kerberoasting) araçtır. |
| 3 | **impacket-GetNPUsers** | [impacket-GetNPUsers.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-GetNPUsers.md) | Kerberos önkimlik doğrulaması gerektirmeyen (DONT_REQ_PREAUTH) kullanıcıları tespit ederek parolasız AS-REP biletlerini hasat eden (AS-REP Roasting) araçtır. |
| 4 | **impacket-getTGT** | [impacket-getTGT.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-getTGT.md) | Kullanıcının parolası, NTLM hash'i veya AES anahtarı ile Kerberos KDC'den TGT (Ticket Granting Ticket) talep edip ccache dosyasına kaydeden araçtır. |
| 5 | **impacket-getST** | [impacket-getST.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-getST.md) | Kısıtlı yetki devri (Constrained Delegation) ve S4U2self/S4U2proxy uzantılarını kullanarak herhangi bir etki alanı yöneticisi adına sahte Servis Bileti (Service Ticket) üreten araçtır. |
| 6 | **impacket-ticketer** | [impacket-ticketer.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-ticketer.md) | Çalınan KRBTGT hash'i ile Altın Bilet (Golden Ticket) veya servis NTLM hash'i ile Gümüş Bilet (Silver Ticket) üreten araçtır. |
| 7 | **impacket-ticketConverter** | [impacket-ticketConverter.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-ticketConverter.md) | Linux (ccache) ve Windows (kirbi) Kerberos bilet formatları arasında çift yönlü dönüşüm sağlayan yardımcı araçtır. |
| 8 | **impacket-describeTicket** | [impacket-describeTicket.md](Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-describeTicket.md) | Kerberos bilet dosyasını (kirbi veya ccache) ayrıştırarak içerisindeki kullanıcı SID'lerini, grup üyeliklerini ve PAC alanlarını ekrana basan analiz aracıdır. |
| 9 | **Kirbikator** | [Kirbikator.md](Kategori_06_Kerberos_Protokol_Cephaneligi/Kirbikator.md) | Mimikatz ve Rubeus tarafından üretilen .kirbi biletlerini toplu olarak dönüştürmek ve yönetmek için kullanılan bir kütüphanedir. |
| 10 | **TGSTomp** | [TGSTomp.md](Kategori_06_Kerberos_Protokol_Cephaneligi/TGSTomp.md) | Kerberoasting tespit sistemlerini atlatmak amacıyla TGS bilet isteklerindeki şifreleme türünü ve istek başlıklarını manipüle eden bir araçtır. |

### 📁 Kategori 7: [7. BELLEK ANALİZİ, LSASS DÖKÜMÜ VE KASA HASADI (CREDENTIAL HARVESTING & DPAPI)](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Mimikatz** | [Mimikatz.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Mimikatz.md) | LSASS bellek alanından açık metin parolaları, NTLM hash'lerini, Kerberos biletlerini çıkaran; DCSync, DCShadow ve Pass-the-Hash gerçekleştiren lider kimlik avı aracıdır. |
| 2 | **pypykatz** | [pypykatz.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/pypykatz.md) | Mimikatz'ın saf Python ile sıfırdan yazılmış açık kaynaklı sürümüdür; çevrimdışı LSASS minidump dosyalarını Linux üzerinde ayrıştırarak parola ve biletleri çıkarır. |
| 3 | **nanodump** | [nanodump.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/nanodump.md) | EDR ve Sysmon kancalarını atlatmak için kısıtlı erişim maskeleri (0x1010) ve PSS snapshot API'si kullanarak LSASS sürecini diske döken son derece gizli bir araçtır. |
| 4 | **Dumpert** | [Dumpert.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Dumpert.md) | Doğrudan sistem çağrıları (Direct System Calls) ve API kancalama atlatma teknikleri ile LSASS bellek dökümü alan C++ tabanlı bir araçtır. |
| 5 | **comsvcs.dll** | [comsvcs.dll.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/comsvcs.dll.md) | Windows yerleşik MiniDump işlevini rundll32.exe ile çağırarak harici bir araç yüklemeden LSASS sürecini diske döken yerleşik LOLBin yöntemidir. |
| 6 | **lsassy** | [lsassy.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/lsassy.md) | Uzak Windows sistemleri üzerinde etkileşimli kabuk açmadan veya diske dosya bırakmadan RPC/WMI ve DLL teknikleriyle LSASS dökümünü uzaktan alan Python aracıdır. |
| 7 | **SafetyKatz** | [SafetyKatz.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/SafetyKatz.md) | GhostPack ailesinin bir parçasıdır; Minidump API'si ile LSASS'ı belleğe alıp Mimikatz'ı bellek içinde çalıştırdıktan sonra dökümü anında silen güvenli bir toplayıcıdır. |
| 8 | **SharpKatz** | [SharpKatz.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/SharpKatz.md) | C# ile geliştirilmiş; Mimikatz'ın sekurlsa mantığını doğrudan .NET üzerinden çalıştırarak LSASS'tan kimlik bilgisi toplayan bir araçtır. |
| 9 | **SharpDPAPI** | [SharpDPAPI.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/SharpDPAPI.md) | Windows Data Protection API (DPAPI) mimarisini istismar ederek saklanan tarayıcı şifrelerini, Vault kasalarını ve RDP bağlantı parolalarını çözen C# aracıdır. |
| 10 | **DonPAPI** | [DonPAPI.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/DonPAPI.md) | Uzak makinelerdeki DPAPI ile şifrelenmiş kimlik bilgilerini, Chrome/Edge şifrelerini ve WiFi anahtarlarını etki alanı genelinde otomatik toplayan Python aracıdır. |
| 11 | **dpapi.py** | [dpapi.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/dpapi.md) | Impacket çatısı altında bulunan; DPAPI ana anahtarlarını (Master Keys) ve etki alanı yedekleme özel anahtarlarıyla korunan verileri ayrıştıran araçtır. |
| 12 | **SharpChrome** | [SharpChrome.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/SharpChrome.md) | Google Chrome, Microsoft Edge ve Brave tarayıcılarında kayıtlı kullanıcı parolalarını, çerezlerini ve form geçmişini bellekten veya diskten çıkaran C# aracıdır. |
| 13 | **Seatbelt** | [Seatbelt.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Seatbelt.md) | Güvenlik denetimleri ve sızma testleri için hedef sistemdeki yerel güvenlik yapılandırmalarını, şüpheli süreçleri ve kimlik kalıntılarını toplayan C# situasyonel farkındalık aracıdır. |
| 14 | **Internal-Monologue** | [Internal-Monologue.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Internal-Monologue.md) | LSASS sürecine dokunmadan ve bellek dökümü almadan, mevcut kullanıcının NetNTLM hash'ini yerel Netlogon API'si üzerinden hafızadan çıkaran son derece gizli bir araçtır. |
| 15 | **LaZagne** | [lazagne.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/lazagne.md) | Windows ve Linux sistemlerde web tarayıcıları, e-posta istemcileri, veritabanları ve WiFi profillerinde saklanan açık metin parolaları toplayan açık kaynaklı araçtır. |
| 16 | **PPLKiller** | [PPLKiller.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/PPLKiller.md) | Zafiyetli ve meşru bir çekirdek sürücüsünü (BYOVD) sisteme yükleyerek LSASS üzerindeki RunAsPPL korumasını çekirdek seviyesinde devre dışı bırakan araçtır. |
| 17 | **PPLMedic & PPLDump** | [PPLMedic_PPLDump.md](Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/PPLMedic_PPLDump.md) | Windows'un Protected Process Light (PPL) korumasını kullanıcı alanındaki mantıksal nesne hiyerarşisi hatalarını istismar ederek aşan ve korunan LSASS bellek dökümünü alan araçlardır. |

### 📁 Kategori 8: [8. ACTIVE DIRECTORY SERTİFİKA SERVİSLERİ (AD CS / PKI EXPLOITATION)](Kategori_08_Active_Directory_Sertifika_Servisleri/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Certify** | [Certify.md](Kategori_08_Active_Directory_Sertifika_Servisleri/Certify.md) | Active Directory Certificate Services (AD CS) ortamındaki zafiyetli şablonları (ESC1-ESC4) tarayan ve kötüye kullanılabilir şablonlardan sertifika talep eden C# aracıdır. |
| 2 | **Certipy** | [Certipy.md](Kategori_08_Active_Directory_Sertifika_Servisleri/Certipy.md) | AD CS mimarisini keşfeden, ESC1'den ESC16'ya kadar tüm zafiyetleri istismar eden, Golden Certificate üreten ve PKINIT ile NTLM hash'e dönüştüren en kapsamlı Python çerçevesidir. |
| 3 | **ForgeCert** | [ForgeCert.md](Kategori_08_Active_Directory_Sertifika_Servisleri/ForgeCert.md) | Ele geçirilen CA özel anahtarı ve sertifikası ile çevrimdışı ortamda herhangi bir etki alanı kullanıcısı adına geçerli Altın Sertifikalar (Golden Certificates) üreten araçtır. |
| 4 | **PKINITtools** | [PKINITtools.md](Kategori_08_Active_Directory_Sertifika_Servisleri/PKINITtools.md) | X.509 sertifikalarını Kerberos PKINIT protokolü üzerinden TGT biletlerine ve kullanıcı NTLM hash'lerine dönüştüren Python araç setidir. |
| 5 | **Whisker** | [Whisker.md](Kategori_08_Active_Directory_Sertifika_Servisleri/Whisker.md) | Active Directory nesnelerinin msDS-KeyCredentialLink özniteliğine sertifika anahtarı enjekte ederek Shadow Credentials saldırısı düzenleyen C# aracıdır. |
| 6 | **pyWhiskey** | [pyWhiskey.md](Kategori_08_Active_Directory_Sertifika_Servisleri/pyWhiskey.md) | Whisker aracının Linux ortamında çalışan Python karşılığıdır; hedef kullanıcı veya bilgisayar hesaplarına LDAP üzerinden Shadow Credentials bağlar. |
| 7 | **CertStealer** | [CertStealer.md](Kategori_08_Active_Directory_Sertifika_Servisleri/CertStealer.md) | Windows işletim sisteminde CryptoAPI ve CNG depolarında bulunan ve dışa aktarılamaz (non-exportable) olarak işaretlenmiş özel anahtarları bellekten çekip çıkaran araçtır. |

### 📁 Kategori 9: [9. ACL, GPO VE NESNE MANİPÜLASYONU (OBJECT, ACL & DELEGATION ABUSE)](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **bloodyAD** | [bloodyAD.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/bloodyAD.md) | Doğrudan LDAP protokolü üzerinden parola sıfırlama, grup üyeliği ekleme, sahip değiştirme ve RBCD yapılandırması gerçekleştiren Python tabanlı AD yetki yükseltme aracıdır. |
| 2 | **aclpwn.py** | [aclpwn.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/aclpwn.md) | BloodHound Neo4j veritabanını analiz ederek tespit ettiği zafiyetli ACL saldırı zincirlerini (GenericAll, WriteDacl vb.) otomatik olarak işleten exploit motorudur. |
| 3 | **SharpGPOAbuse** | [SharpGPOAbuse.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/SharpGPOAbuse.md) | Düzenleme yetkisi bulunan Grup İlkelerine (GPO) arka planda Scheduled Task, yerel yönetici veya başlangıç betikleri enjekte eden C# aracıdır. |
| 4 | **pyGPOAbuse** | [pyGPOAbuse.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/pyGPOAbuse.md) | SharpGPOAbuse işlevlerini Linux üzerinden uygulayarak yazma izni olan GPO'lar vasıtasıyla hedef sistemlerde uzaktan kod yürüten Python aracıdır. |
| 5 | **StandIn** | [StandIn.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/StandIn.md) | Windows sistemlerinde C# ile Active Directory nesne özniteliklerini değiştiren, grup ekleyen ve dACL izinlerini manipüle eden bir post-exploitation aracıdır. |
| 6 | **PowerMad** | [PowerMad.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/PowerMad.md) | Etki alanında standart kullanıcı hesabıyla yeni bilgisayar hesapları ekleme (MachineAccountQuota) ve DNS manipülasyonu sağlayan PowerShell modülüdür. |
| 7 | **impacket-addcomputer** | [impacket-addcomputer.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/impacket-addcomputer.md) | SAMR veya LDAP protokolleri üzerinden etki alanına yeni bilgisayar hesapları ekleyerek RBCD ve sAMAccountName spoofing saldırılarını besleyen araçtır. |
| 8 | **impacket-rbcd** | [impacket-rbcd.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/impacket-rbcd.md) | Hedef bilgisayar hesabının msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğini güncelleyerek Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD) kuran araçtır. |
| 9 | **dsacls** | [dsacls.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/dsacls.md) | Windows yerleşik komut satırı aracıdır; Active Directory nesnelerinin erişim denetim listelerini (DACL/SACL) görüntülemek ve izin ekleyip kaldırmak için kullanılır. |
| 10 | **Incognito** | [Incognito.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/Incognito.md) | Hedef makinedeki erişim belirteçlerini (access tokens) listeleyen ve yönetici belirteçlerini taklit ederek yetki yükselten klasik token avı aracıdır. |
| 11 | **Tokenvator** | [Tokenvator.md](Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/Tokenvator.md) | Windows ayrıcalıklarını denetleyen, UAC kısıtlamalarını aşan ve mevcut süreçlerin güvenlik belirteçlerini çalarak taklit eden gelişmiş C# belirteç aracıdır. |

### 📁 Kategori 10: [10. KURUMSAL ALTYAPI, PAYLAŞIM VE VERİ AVI (ENTERPRISE DATA HUNTING)](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Snaffler** | [Snaffler.md](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/Snaffler.md) | Etki alanı genelindeki SMB ve DFS ağ paylaşımlarını otomatik tarayarak regex ile parola, kdbx kasası, SSH anahtarları ve yapılandırma sırlarını avlayan yüksek performanslı C# aracıdır. |
| 2 | **SharpShares** | [SharpShares.md](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/SharpShares.md) | Active Directory bilgisayarlarını LDAP üzerinden sorgulayarak ağ paylaşımlarını ve mevcut kullanıcının erişim izinlerini çok hızlı listeleyen C# aracıdır. |
| 3 | **PowerUpSQL** | [PowerUpSQL.md](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/PowerUpSQL.md) | Etki alanındaki tüm Microsoft SQL Server örneklerini keşfeden, veritabanı bağlantı zincirlerini (linked servers) sömüren ve xp_cmdshell ile yetki yükselten PowerShell araç setidir. |
| 4 | **impacket-mssqlclient** | [impacket-mssqlclient.md](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/impacket-mssqlclient.md) | Linux üzerinden TDS protokolüyle MSSQL veritabanlarına bağlanan, Windows/SQL kimlik doğrulaması yapan ve etkileşimli SQL kabuğu sunan araçtır. |
| 5 | **SharpSCCM** | [SharpSCCM.md](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/SharpSCCM.md) | Microsoft Endpoint Configuration Manager (SCCM/MECM) altyapısını WMI üzerinden sorgulayarak sertifika çekme, komut yürütme ve etki alanı genelinde yetki yükseltme sağlayan C# aracıdır. |
| 6 | **MalSCCM** | [MalSCCM.md](Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/MalSCCM.md) | SCCM dağıtım noktalarını ve yönetim servislerini kötüye kullanarak yönetilen tüm uç noktalara zararlı yazılım ve ters kabuk dağıtan saldırı aracıdır. |

### 📁 Kategori 11: [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **NetExec (nxc)** | [NetExec_nxc.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md) | SMB, WinRM, LDAP, MSSQL, RDP ve SSH protokolleri üzerinden parola püskürtme, kimlik doğrulama, komut yürütme ve veri hasadı gerçekleştiren yeni nesil çok amaçlı otomasyon aracıdır. |
| 2 | **impacket-psexec** | [impacket-psexec.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-psexec.md) | SMB üzerinden hedef Windows sisteminde geçici bir servis oluşturarak doğrudan NT AUTHORITY\SYSTEM yetkisinde interaktif bir komut istemcisi açan araçtır. |
| 3 | **impacket-smbexec** | [impacket-smbexec.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-smbexec.md) | Hedef sistemde çalıştırılabilir (.exe) dosya bırakmadan, SMB Named Pipe ve BATCH betikleri üzerinden gizli komut yürütme sağlayan servissiz yanal hareket aracıdır. |
| 4 | **impacket-wmiexec** | [impacket-wmiexec.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-wmiexec.md) | DCOM/WMI arayüzü (TCP 135) üzerinden Win32_Process sınıfı ile komut çalıştırıp çıktıları SMB paylaşımı aracılığıyla okuyan yarı-etkileşimli dosyasız kabuk aracıdır. |
| 5 | **impacket-atexec** | [impacket-atexec.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-atexec.md) | Task Scheduler servisi (MS-TSCH) RPC arayüzü üzerinden hedef sistemde geçici zamanlanmış görev oluşturarak kod yürüten ve iş bitiminde görevi silen araçtır. |
| 6 | **impacket-dcomexec** | [impacket-dcomexec.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-dcomexec.md) | MMC20.Application, ShellWindows ve ShellBrowserWindow gibi DCOM nesneleri üzerinden uzaktan komut yürüterek WMI/SMB filtrelerini atlatan araçtır. |
| 7 | **Evil-WinRM** | [Evil-WinRM.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/Evil-WinRM.md) | Windows Remote Management (WinRM) servisi üzerinden Pass-the-Hash ve Kerberos desteğiyle etkileşimli PowerShell oturumu açan, dosya transferi ve bellek içi yükleme sağlayan lider Linux istemcisidir. |
| 8 | **SharpWMI** | [SharpWMI.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/SharpWMI.md) | Cobalt Strike ve C2 altyapıları için geliştirilmiş, WMI/DCOM üzerinden WQL sorgulama ve uzaktan süreç başlatma gerçekleştiren C# aracıdır. |
| 9 | **WMIHacker** | [WMIHacker.md](Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/WMIHacker.md) | Port 445 (SMB) kapalıyken yalnızca TCP 135 (RPC) üzerinden Windows Kayıt Defteri'ni girdi/çıktı kanalı olarak kullanarak komut çalıştıran ve çıktı alan özel araçtır. |

### 📁 Kategori 12: [12. NTDS.DIT, GPO ŞİFRELERİ VE LAPS HASADI (CREDENTIAL DUMPING & LAPS)](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **ntdsutil** | [ntdsutil.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/ntdsutil.md) | Windows Server üzerinde Active Directory veritabanını (NTDS.dit) ve sistem kovanlarını yerleşik IFM (Install From Media) mekanizmasıyla diske çıkaran yönetim aracıdır. |
| 2 | **vssadmin / diskshadow** | [vssadmin_diskshadow.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/vssadmin_diskshadow.md) | Volume Shadow Copy Service (VSS) altyapısını kullanarak kilitli durumdaki NTDS.dit dosyasının anlık gölge kopyasını oluşturan ve dışa aktaran yerleşik araçlardır. |
| 3 | **Invoke-NinjaCopy** | [Invoke-NinjaCopy.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/Invoke-NinjaCopy.md) | VSS kullanmaksızın doğrudan ham NTFS disk sektörleri (\\.\C:) ve MFT kayıtlarını okuyarak kilitli NTDS.dit ve SYSTEM dosyalarını kopyalayan PowerShell aracıdır. |
| 4 | **gpp-decrypt** | [gpp-decrypt.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/gpp-decrypt.md) | SYSVOL paylaşımındaki Group Policy Preferences (GPP) XML dosyalarında yer alan, Microsoft'un statik AES anahtarıyla şifrelenmiş cpassword değerlerini çözen şifre çözücüdür. |
| 5 | **Get-GPPPassword** | [Get-GPPPassword.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/Get-GPPPassword.md) | SYSVOL paylaşımını özyinelemeli tarayarak GPP XML dosyalarındaki şifreli cpassword değerlerini otomatik tespit eden ve açık metne çeviren PowerShell aracıdır. |
| 6 | **Grouper2** | [Grouper2.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/Grouper2.md) | SYSVOL'deki Grup İlkelerini (GPO) ayrıştırarak zafiyet oluşturan ayarları, yetki devri hatalarını ve gömülü parolaları otomatik puanlayan C# motorudur. |
| 7 | **LAPSToolkit.ps1** | [LAPSToolkit.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/LAPSToolkit.md) | Active Directory'de Microsoft LAPS yapılandırmasını denetleyen, delegasyon açıklarını haritalayan ve okunabilir ms-Mcs-AdmPwd yerel yönetici parolalarını LDAP üzerinden hasat eden PowerShell aracıdır. |
| 8 | **pyLAPS** | [pyLAPS.md](Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/pyLAPS.md) | Linux üzerinden Pass-the-Hash ve Kerberos desteğiyle LDAP sorguları yaparak LAPS yerel yönetici parolalarını çeken Python aracıdır. |

### 📁 Kategori 13: [13. TARİHİ VE KRİTİK ZAFİYET İSTİSMAR ARAÇLARI (EXPLOIT TOOLING)](Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **cve-2020-1472-exploit (Zerologon)** | [cve-2020-1472-exploit.md](Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/cve-2020-1472-exploit.md) | Netlogon Uzaktan Yönetim Protokolü'ndeki (MS-NRPC) kriptografik hatayı istismar ederek kimlik bilgisi olmadan Domain Controller makine hesabı parolasını sıfırlayan kritik zafiyet aracıdır. |
| 2 | **restorepassword.py** | [restorepassword.md](Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/restorepassword.md) | Zerologon istismarı sonrasında sıfırlanan Domain Controller makine hesabı parolasını yerel SAM kovanındaki orijinal değerine geri yükleyerek AD replikasyonunu onaran kurtarma aracıdır. |
| 3 | **PrintNightmare** | [PrintNightmare.md](Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/PrintNightmare.md) | Windows Print Spooler (spoolsv.exe) servisindeki yetki denetimi açığını (CVE-2021-1675/34527) istismar ederek standart kullanıcıyla hedef sistemlerde uzaktan SYSTEM yetkisinde DLL çalıştıran istismar aracıdır. |
| 4 | **noPac / sam-the-admin** | [noPac_sam-the-admin.md](Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/noPac_sam-the-admin.md) | sAMAccountName sahteciliği (CVE-2021-42278) ve Kerberos PAC kafa karışıklığı (CVE-2021-42287) açıklarını birleştirerek dakikalar içinde Domain Admin yetkisine sıçrayan istismar aracıdır. |

### 📁 Kategori 14: [14. AD FS, BULUT VE HİBRİT KİMLİK (FEDERATION & HYBRID PIVOT)](Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **AADInternals** | [AADInternals.md](Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/AADInternals.md) | Azure AD (Microsoft Entra ID), M365 ve Azure AD Connect altyapılarını yönetmek, MSOL_ senkronizasyon parolalarını dökmek ve parola hash senkronizasyonunu (PHS) manipüle etmek için kullanılan kapsamlı PowerShell modülüdür. |
| 2 | **ADFSpoof (Golden SAML)** | [ADFSpoof.md](Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/ADFSpoof.md) | Ele geçirilen AD FS Token-Signing özel anahtarını kullanarak, şirket içi sunuculara uğramadan herhangi bir kullanıcı adına sahte SAML 2.0 belirteçleri üreten ve bulutta parola/MFA olmaksızın oturum açan Python aracıdır. |
| 3 | **ROADtools / roadrecon** | [ROADtools_roadrecon.md](Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/ROADtools_roadrecon.md) | Azure AD / Entra ID bulut ortamlarındaki kullanıcıları, grupları, rolleri ve Koşullu Erişim politikalarını tarayan, yerel veritabanında depolayan ve görsel web arayüzünde analiz eden keşif çerçevesidir. |

### 📁 Kategori 15: [15. YEREL YETKİ YÜKSELTME (LPE) VE POTATO AİLESİ](Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **PrintSpoofer** | [PrintSpoofer.md](Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/PrintSpoofer.md) | Windows 10 ve Server 2016-2022 sistemlerde SeImpersonatePrivilege yetkisini Print Spooler Named Pipe (\\.\pipe\spoolss) üzerinden istismar ederek doğrudan interaktif SYSTEM konsolu açan yüksek başarımlı LPE aracıdır. |
| 2 | **SweetPotato / JuicyPotatoNG** | [SweetPotato_JuicyPotatoNG.md](Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/SweetPotato_JuicyPotatoNG.md) | DCOM sıkılaştırmasını aşarak BITS, DCOM CLSID ve Spooler vektörlerini birleştiren, .NET ve Native C++ tabanlı yeni nesil belirteç (token) kaçırma araçlarıdır. |
| 3 | **GodPotato** | [GodPotato.md](Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/GodPotato.md) | Windows Server 2008-2022 arasında DCOM IStorage arayüzü ve yerel RPC dispatching mekanizmasıyla çalışan, harici porta veya Spooler servisine ihtiyaç duymayan evrensel yetki yükseltme aracıdır. |

### 📁 Kategori 16: [16. TÜNELLEME, PİVOT VE SOCKS PROXY (PIVOTING & TUNNELING)](Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Chisel** | [Chisel.md](Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/Chisel.md) | HTTP/WebSocket protokolü üzerinden tünellenmiş ve dahili SSH v2 ile şifrelenmiş ters (reverse) SOCKS5 ve port yönlendirme sağlayan yüksek performanslı pivot aracıdır. |
| 2 | **Ligolo-ng** | [Ligolo-ng.md](Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/Ligolo-ng.md) | Sanal TUN arabirimi ile Katman 3 düzeyinde yönlendirme sağlayan, Proxychains bağımlılığını kaldıran ve tam Nmap SYN / ICMP desteği sunan yeni nesil pivot aracıdır. |
| 3 | **Proxychains-ng** | [Proxychains-ng.md](Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/Proxychains-ng.md) | LD_PRELOAD kancalamasıyla Linux araçlarının TCP ve DNS bağlantılarını SOCKS4/5 veya HTTP vekilleri üzerinden iç Active Directory ağına yönlendiren zincirleme motorudur. |

### 📁 Kategori 17: [17. MODERN EDR-SAFE BEACON OBJECT FILES (AD BOFS)](Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **BOF-AD / SA-BOF** | [BOF-AD_SA-BOF.md](Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/BOF-AD_SA-BOF.md) | C ile yazılmış, unlinked COFF mimarisinde derlenen; alt süreç (No Fork & Run) açmadan ve CLR yüklemeden doğrudan ajan bellek alanında Win32 API'leri ile çalışan EDR-safe Active Directory keşif kütüphaneleridir. |

### 📁 Kategori 18: [18. ÇEVRİMDIŞI PAROLA KIRMA (OFFLINE CRACKING)](Kategori_18_Cevrimdisi_Parola_Kirma/README.md)

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Hashcat** | [Hashcat.md](Kategori_18_Cevrimdisi_Parola_Kirma/Hashcat.md) | Modern GPU hızlandırması (CUDA/OpenCL) ile Active Directory NTLM (1000), NetNTLMv2 (5600), Kerberoast (13100) ve AS-REP (18200) hash'lerini saniyede milyarlarca hızla çözen parola kurtarma motorudur. |
| 2 | **John the Ripper** | [John_the_Ripper.md](Kategori_18_Cevrimdisi_Parola_Kirma/John_the_Ripper.md) | *2john ekosistemi (kirbi2john, pfx2john), Single Crack modu ve Markov tabanlı Incremental kaba kuvvet ile zengin format dönüştürme ve parola çözme motorudur. |

---

## 🎯 Modül Standartları ve Kullanım Kılavuzu

Her bir araç kılavuzu istisnasız aşağıdaki 6 operasyonel bölüme sahiptir:
1. **Genel Bakış ve Amaç:** Protokol temeli, mimari ASCII akış şeması, operasyonel önem ve alternatif araçlarla karşılaştırma matrisi.
2. **Temel Sözdizimi ve Parametreler (CLI Flags):** Bağlantı ve çalıştırma sözdizimi, detaylı parametre tabloları.
3. **Pratik Komut Örnekleri:** Sahada kopyala-çalıştır gerçek sızma testi senaryoları ve adım adım konsol çıktı analizleri.
4. **Karşılaşılan Hatalar ve Çözümleri (Troubleshooting):** Sahada en sık karşılaşılan hata kodları, nedenleri ve kesin çözüm adımları tablosu.
5. **OPSEC ve Karşı Tespit (IOC):** Sysmon ve Windows Security Event ID günlükleri, EDR imzaları, MITRE ATT&CK matrisi, OPSEC risk/önlem tablosu, Sigma YAML kuralı, Microsoft Sentinel KQL sorgusu ve YARA kuralı.
6. **En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet):** Operatörün sahada en sık başvuracağı 8-10 hazır tek satırlık komut (Ne Yapar?, Ne Zaman Kullanılır?, Parametreler analizi).
