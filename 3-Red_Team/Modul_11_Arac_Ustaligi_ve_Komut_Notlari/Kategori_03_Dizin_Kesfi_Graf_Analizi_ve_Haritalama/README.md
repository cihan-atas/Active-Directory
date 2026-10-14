# 3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 20 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **BloodHound CE** | [BloodHound_CE.md](./BloodHound_CE.md) | Active Directory ortamlarındaki karmaşık yetki ilişkilerini, ACL izinlerini ve gizli saldırı yollarını Neo4j/PostgreSQL graf veritabanında görselleştiren modern analiz platformudur. |
| 2 | **SharpHound** | [SharpHound.md](./SharpHound.md) | BloodHound için C# ile yazılmış veri toplayıcısıdır; LDAP, SMB ve yerel oturumları tarayarak graf analizinde kullanılacak JSON verilerini üretir. |
| 3 | **BloodHound.py** | [BloodHound.md](./BloodHound.md) | Linux ortamından etki alanı kimlik bilgileriyle Active Directory nesnelerini tarayıp BloodHound uyumlu JSON dosyaları üreten Python tabanlı veri toplayıcıdır. |
| 4 | **AzureHound** | [AzureHound.md](./AzureHound.md) | Microsoft Entra ID (Azure AD) ortamlarındaki rolleri, kullanıcıları, servis sorumlularını ve bulut saldırı yollarını BloodHound grafiğine aktaran toplayıcıdır. |
| 5 | **PowerView** | [PowerView.md](./PowerView.md) | Active Directory etki alanını derinlemesine haritalamak, kullanıcıları, grupları, GPO'ları ve ACL yetkilerini sorgulamak için kullanılan efsanevi PowerShell keşif kütüphanesidir. |
| 6 | **SharpView** | [SharpView.md](./SharpView.md) | PowerView işlevlerinin C# ile yeniden yazılmış halidir; PowerShell çalıştırmadan doğrudan .NET bellek alanında Active Directory keşfi yürütür. |
| 7 | **pywerview** | [pywerview.md](./pywerview.md) | PowerView mantığını Linux platformuna taşıyan, Python tabanlı LDAP ve RPC sorgularıyla etki alanı keşfi yapan bir kütüphanedir. |
| 8 | **ADRecon** | [ADRecon.md](./ADRecon.md) | Active Directory ormanının tüm kullanıcı, bilgisayar, GPO, DNS, trust ve sertifika yapılandırmasını tarayıp kapsamlı bir Excel raporu üreten PowerShell aracıdır. |
| 9 | **linWinPwn** | [linWinPwn.md](./linWinPwn.md) | Linux üzerinden birden fazla AD keşif ve istismar aracını otomatize ederek etki alanındaki zafiyetleri ve yetki yükseltme yollarını hızla tarayan bash çerçevesidir. |
| 10 | **ldapdomaindump** | [ldapdomaindump.md](./ldapdomaindump.md) | LDAP üzerinden tüm etki alanı nesnelerini (kullanıcılar, bilgisayarlar, gruplar, trust'lar) çekerek insan tarafından okunabilir HTML ve JSON raporlarına dönüştüren araçtır. |
| 11 | **ldeep** | [ldeep.md](./ldeep.md) | Python ile yazılmış LDAP sorgulama aracıdır; etki alanı parolalarını, SPN'leri, delegasyon izinlerini ve güvenlik gruplarını hızlıca listeler. |
| 12 | **adalanche** | [adalanche.md](./adalanche.md) | Active Directory ACL ve yetki ilişkilerini haritalayan, saldırı yollarını görselleştiren Go tabanlı bağımsız bir graf analiz aracıdır. |
| 13 | **AdFind** | [AdFind.md](./AdFind.md) | Joeware tarafından geliştirilen; son derece hızlı, esnek ve güçlü filtrelerle Active Directory LDAP veritabanını komut satırından sorgulayan araçtır. |
| 14 | **AdMod** | [AdMod.md](./AdMod.md) | Active Directory nesnelerinin özniteliklerini (örneğin SPN, logonScript, açıklama alanları) komut satırından toplu olarak değiştirmek için kullanılan yönetim aracıdır. |
| 15 | **adidnsdump** | [adidnsdump.md](./adidnsdump.md) | Active Directory Entegre DNS (ADI-DNS) bölgelerini LDAP üzerinden sorgulayarak iç ağdaki tüm sunucu ve IP adreslerini haritalayan araçtır. |
| 16 | **dnstool.py** | [dnstool.md](./dnstool.md) | Active Directory DNS veritabanına uzaktan yeni DNS A veya PTR kayıtları ekleyerek Ortadaki Adam (MitM) ve relay saldırılarını tetikleyen Python aracıdır. |
| 17 | **Kerbrute** | [Kerbrute.md](./Kerbrute.md) | Kerberos Pre-Authentication (AS-REQ) isteklerini kullanarak hedef kullanıcı hesaplarını kilitlemeden doğrulamak ve parola püskürtme yapmak için kullanılan Go tabanlı hızlı araçtır. |
| 18 | **DomainPasswordSpray** | [DomainPasswordSpray.md](./DomainPasswordSpray.md) | Etki alanındaki tüm kullanıcı hesaplarına lockout ilkesini dikkate alarak tek bir parola püskürten (password spraying) PowerShell betiğidir. |
| 19 | **Spray-Passwords** | [Spray-Passwords.md](./Spray-Passwords.md) | Çeşitli protokoller üzerinden etki alanı kullanıcılarına kontrollü parola püskürtme saldırıları düzenleyen alternatif bir otomasyon scriptidir. |
| 20 | **SOAPHound** | [SOAPHound.md](./SOAPHound.md) | LDAP izlemelerini atlatmak için Active Directory Web Services (ADWS - TCP 9389) üzerinden SOAP XML sorguları ile BloodHound verisi toplayan keşif aracıdır. |

---

> **Önceki Kategori:** [← Kategori 2](../Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/README.md) · **Sonraki Kategori:** [Kategori 4 →](../Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md)
