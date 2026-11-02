# 🔴 Modül 05 — Yetki Yükseltme (ACL & GPO Abuse)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Ayrıcalık Yükseltme (Privilege Escalation)  
> **Simetrik Savunma Karşılığı:** [Blue M05 — Yetki ve ACL Sıkılaştırma](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/) & [Blue 07.3 — Sertifika Tabanlı Kalıcılık Tespiti](../../2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/07.3_Sertifika_Tabanli_Kalicilik_Tespiti.md)  
> **Sistem Tabanı:** [Sistem M03 — Nesne ve Kimlik (OU/AGDLP)](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) & [Sistem M04 — Grup İlkeleri (GPO)](../../1-Sistem_Yoneticisi/Modul_04_Grup_Ilkeleri_GPO/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Yetki Yükseltme Felsefesi

Active Directory güvenliğinde ayrıcalık yükseltme (Privilege Escalation) çoğunlukla bir işletim sistemi çekirdek açığı (kernel exploit) ile gerçekleşmez. AD ortamlarında yetki yükseltme, **yıllar içinde birikmiş yanlış yapılandırılmış erişim denetim listelerinin (DACL) ve merkezi yönetim mekanizmalarının (GPO) istismar edilmesiyle** sağlanır.

Microsoft ekosisteminde her nesnenin (kullanıcı, bilgisayar, grup, GPO, OU) bir Güvenlik Tanımlayıcısı (Security Descriptor) ve buna bağlı Erişim Denetim Girişleri (ACE) bulunur:
- **GenericAll:** Hedef nesne üzerinde tam denetim sağlar. Kullanıcı parolasını sıfırlama, gruba üye ekleme veya bilgisayar özniteliklerini değiştirme hakkı verir.
- **WriteOwner / TakeOwnership:** Nesnenin sahipliğini ele geçirip ardından kendi hesabına `Full Control (GenericAll)` yetkisi verme zincirini başlatır.
- **WriteProperty (msDS-KeyCredentialLink):** Hedef hesaba asimetrik anahtar enjekte ederek parola değiştirmeden PKINIT ile kimliğini devralma olanağı tanır (**Shadow Credentials**).
- **GPO Değiştirme (Edit / Write):** Bir OU'ya bağlı Grup İlkesini düzenleyerek o OU altındaki tüm sunucu ve iş istasyonlarında SYSTEM yetkisinde görev çalıştırma (Immediate Scheduled Task) gücü sunar.

> **💡 Operasyonel İlke:**  
> *"DACL ve GPO sömürüleri birer 'özellik kötüye kullanımı'dır (feature abuse). Güvenlik yamaları ile kapatılamazlar; yalnızca düzenli DACL hijyeni, Tiering modeli ve en az ayrıcalık (Least Privilege) prensibiyle engellenebilirler."*

---

## 2. Yetki Yükseltme Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 DACL, GPO VE SHADOW CREDENTIALS YÜKSELTME AKIŞI             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: BloodHound / PowerView ile Yetki Kenarı Keşfi]
           - Nesne üzerindeki izinleri sorgula: Get-DomainObjectAcl
           - BloodHound ön-tanımlı sorguları: "Shortest Paths from Owned Principals"
           - Hedef izin tespiti: GenericAll, GenericWrite, WriteDacl, WriteOwner
                                      │
                                      ▼
           [Aşama 2: Sömürü Rotasının Belirlenmesi]
           │
           ├─► [DACL: Doğrudan Parola Sıfırlama / Üye Ekleme]
           │   - ForceChangePassword ile hedef parolasını değiştir
           │   - AddMember ile kendini hedef ayrıcalıklı gruba ekle
           │   - Araçlar: PowerView, bloodyAD, NetExec
           │
           ├─► [GPO Abuse: Ölçekli SYSTEM Yürütme]
           │   - OU'ya bağlı GPO'da Write yetkisi varsa
           │   - Immediate Scheduled Task enjekte et (C:\Windows\System32...)
           │   - Araçlar: SharpGPOAbuse, pyGPOAbuse
           │
           └─► [Shadow Credentials: İz Bırakmadan Kimlik Devralma]
               - Hedef nesnede msDS-KeyCredentialLink yazma izni
               - RSA anahtarı üret ve özniteliğe enjekte et
               - PKINIT ile TGT al ve NT hash'i çek (UnPAC-the-Hash)
               - Araçlar: Whisker, pywhiskey, Certipy
                                      │
                                      ▼
           [Aşama 3: Domain Admins / Tier-0 Seviyesine Ulaşma]
           - Domain Controller nesnesi veya Domain Admins grubu kontrol altına alındı
           - DCSync yetkisi ekleme veya doğrudan DCSync icrası (Modül 09)
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **05.1** | [DACL Abuse](./05.1_DACL_Abuse.md) | Windows güvenlik tanımlayıcısı mimarisi (SDDL, DACL, ACE), `GenericAll`, `WriteDacl`, `ForceChangePassword`, `userAccountControl` bayrak manipülasyonu, targeted Kerberoasting ve dinamik nesneler (`entryTTL`). |
| **05.2** | [WriteOwner, AddMember ve GPLink](./05.2_WriteOwner_AddMember_GPLink.md) | Sahiplik alma zincirleri (`OwnerSID` ile örtük `WRITE_DAC`), grup hiyerarşisi (AGDLP) istismarı, OU nesnelerine zorlanmış GPO bağlama (`gPLink/gPOptions`) ve AdminSDHolder/SDProp mekanizması. |
| **05.3** | [GPO Abuse ve SharpGPOAbuse](./05.3_GPO_Abuse_SharpGPOAbuse.md) | Group Policy mimarisi (GPC LDAP vs. GPT SYSVOL), İstemci Uzantıları (CSE), SYSTEM bağlamında Immediate Task enjeksiyonu, GPP Local Admin, User Rights Assignment ve hedeflenmiş güvenlik filtreleme. |
| **05.4** | [Shadow Credentials](./05.4_Shadow_Credentials.md) | `msDS-KeyCredentialLink` özniteliği, Windows Hello for Business (Key Trust) altyapısı, parola sıfırlamadan gizli kimlik devralma, UnPAC-the-Hash ile NT hash çözme ve Whisker/Certipy otomasyonu. |
| **05.5** | [OpenSSH LPK ve Hassas LDAP Nitelik Manipülasyonu](./05.5_OpenSSH_LPK_ve_LDAP_Sema_Manipulasyonu.md) | OpenSSH LPK şeması (`ldapPublicKey`, `sshPublicKey` enjeksiyonu ile parolasız Linux root erişimi), `supplementalCredentials` hasadı, `primaryGroupID` ve `userWorkstations` istismarı. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

ACL ve GPO sömürü operasyonlarında kullanılan başlıca araçların komut kılavuzları:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **SharpGPOAbuse** | [SharpGPOAbuse.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/SharpGPOAbuse.md) | Yazma yetkisi bulunan GPO nesnelerine zamanlanmış görev, yerel yönetici veya başlangıç betiği enjekte eden C# aracı. |
| 02 | **pyGPOAbuse** | [pyGPOAbuse.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/pyGPOAbuse.md) | Linux üzerinden SMB bağlantısıyla hedef GPO'yu düzenleyip Immediate Task enjeksiyonu yapan Python aracı. |
| 03 | **Whisker** | [Whisker.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/Whisker.md) | Windows hedeflerde `msDS-KeyCredentialLink` özniteliğine sertifika anahtarı enjekte ederek Shadow Credentials saldırısını yöneten C# aracı. |
| 04 | **pywhiskey** | [pywhiskey.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/pyWhiskey.md) | Linux ortamından hedef Active Directory hesabına anahtar enjeksiyonu yapıp PKINIT ile TGT alan Python Shadow Credentials aracı. |
| 05 | **StandIn** | [StandIn.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/StandIn.md) | .NET tabanlı küçük ve bağımsız AD keşif ve yetki manipülasyon aracı; DACL listeleme ve düzenleme sağlar. |
| 06 | **PowerView** | [PowerView.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/PowerView.md) | `Add-DomainObjectAcl`, `Set-DomainObjectOwner` fonksiyonları ile hedef nesnelerin ACL izinlerini manipüle eden PowerShell aracı. |
| 07 | **bloodyAD** | [bloodyAD.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/bloodyAD.md) | LDAP protokolü üzerinden parola sıfırlama, nesne sahipliği değiştirme ve DACL yazma işlemlerini tek çatı altında toplayan Python kütüphanesi. |
| 08 | **Certipy** | [Certipy.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_08_Active_Directory_Sertifika_Servisleri/Certipy.md) | Shadow Credentials aşamasında üretilen sertifikalarla PKINIT kimlik doğrulaması (`certipy auth`) yapan çok yönlü araç. |
| 09 | **gpresult** | [gpresult.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/gpresult.md) | Hedef sistemde uygulanan GPO'ları, bağlantı durumlarını ve kapsam ilkelerini (`gpresult /z`) raporlayan Windows LOLBin. |
| 10 | **schtasks** | [schtasks.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/schtasks.md) | GPO tarafından dağıtılan veya yerel yetki yükseltmede kullanılan zamanlanmış görevleri denetleyen ve tetikleyen komut satırı aracı. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

DACL ve GPO istismarları dizin ve dosya sistemi denetimleri ile yakalanabilir:

- **Windows Event ID 5136 (Dizin Hizmeti Nesnesi Değiştirildi):** Bir nesnenin DACL veya `msDS-KeyCredentialLink` özniteliği değiştiğinde tetiklenir (SACL yapılandırması şarttır).
- **Windows Event ID 5145 (Ağ Paylaşımı Nesnesi Denetimi):** SYSVOL paylaşımı altındaki GPO dosyalarının (`ScheduledTasks.xml` vb.) değiştirilmesi izlenebilir.
- **Windows Event ID 4738 (Kullanıcı Hesabı Değiştirildi):** Parola sıfırlama veya UAC bayrağı değişiklikleri tespit edilir.
- **AdminSDHolder Koruması:** Korunan grupların (Domain Admins vb.) izinleri saatte bir `SDProp` süreci tarafından varsayılan şablona zorlanarak yetkisiz ACE eklemeleri otomatik temizlenir.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M05 — Yetki ve ACL Sıkılaştırma](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/)
  - [Blue 05.2 — Tehlikeli DACL Denetimi ve Temizliği](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/05.2_Tehlikeli_DACL_Denetimi_ve_Temizligi.md)
  - [Blue 05.3 — GPO Güvenliği ve Yetki Devri Hijyeni](../../2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/05.3_GPO_Guvenligi_ve_Yetki_Devri_Hijyeni.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan DACL manipülasyonu, GPO Immediate Task enjeksiyonu ve Shadow Credentials teknikleri; **yalnızca yasal yazılı izin belgesine sahip kırmızı takım tatbikatları, yetkili sızma testleri ve kontrollü eğitim laboratuvarları** amacıyla kullanılmalıdır.
>
> Bir kurumun merkezi grup politikalarını veya etki alanı nesne izinlerini izinsiz değiştirmek, iş sürekliliğini durdurabilecek zararlar verebileceği gibi TCK Madde 243-245 kapsamında suçtur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — ACL & GPO Abuse (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/privilege-escalation/): DACL abuse, GPO istismarları ve referans komutlar.
- 🌐 [HackTricks Wiki — Active Directory ACLs & GPO (Carlos Polop)](https://book.hacktricks.wiki/): GenericAll, WriteOwner, Shadow Credentials ve GPO yetki yükseltme.
- 🌐 [The Hacker Recipes — ACE/ACL Abuse](https://www.thehacker.recipes/): DACL saldırı rotaları ve Shadow Credentials adımları.
- 🌐 [SpecterOps — An ACE Up the Sleeve](https://posts.specterops.io/): Active Directory DACL sömürü matematiği ve graf analizi.

---

> **Önceki Modül:** [← Modül 04 — Yanal Hareket](../Modul_04_Yanal_Hareket/README.md) · **Sonraki Modül:** [Modül 06 — Kerberos Delegation Saldırıları →](../Modul_06_Kerberos_Delegation_Saldirilari/README.md)
