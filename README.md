# Active Directory Ustalık Programı

Bu proje, Active Directory (AD) altyapılarını sıfırdan en ileri seviyeye kadar anlamak, yönetmek, güvenliğini sağlamak ve saldırı/savunma boyutlarıyla kavramak için oluşturulmuş **kitap/eğitim niteliğinde kapsamlı bir dokümantasyon deposudur**. Aynı sistem, **üç farklı bakış açısıyla** ve bu kollar birbirine çapraz referans vererek işlenir: **Sistem Mimarı**, **Blue Team (Savunma)** ve **Red Team (Saldırı)**.

# Active Directory Ustalık Programı

Bu proje, Active Directory (AD) altyapılarını sıfırdan en ileri seviyeye kadar anlamak, yönetmek, güvenliğini sağlamak ve saldırı/savunma boyutlarıyla kavramak için oluşturulmuş **ansiklopedik eğitim ve referans dokümantasyon deposudur**. Aynı sistem, **üç farklı bakış açısıyla** ve bu kollar birbirine çift yönlü çapraz referans vererek işlenir: **Sistem Mimarı**, **Blue Team (Savunma)** ve **Red Team (Saldırı & Araç Cephaneliği)**.

> **Durum:** 🟢 **Tamamlandı** — 3 kol · 31 modül · **265+ konu ve araç kılavuzu** + 31 modül ve 18 kategori README'si.

---

## 🎯 Temel Felsefe

Bir konu üç açıdan da ele alınır ve birbirine bağlanır. Örneğin **Kerberos delegation**:

- **Sistem Yöneticisi** → ne olduğunu, neden gerektiğini ve nasıl güvenle yapılandırıldığını anlatır.
- **Red Team** → nasıl kötüye kullanıldığını (unconstrained / constrained / RBCD abuse) gösterir.
- **Blue Team** → nasıl tespit ve önleneceğini (Event ID, Sigma, hardening) anlatır.

Her Red tekniği, karşılık gelen Blue tespiti/önlemiyle **1:1 simetrik** eşleştirilmiştir (Red Modül N ↔ Blue Modül N), ayrıca **Modül 11** ile tüm bu saldırı tekniklerini sahada icra eden 145 aracın operasyonel komut rehberi sunulmuştur.

---

## 🗂️ Proje Yapısı

| Kol | Klasör | Bakış Açısı | Modül Sayısı | Kapsam |
|-----|--------|-------------|--------------|--------|
| 🏗️ **Sistem Yöneticisi / Mimar** | [`1-Sistem_Yoneticisi`](1-Sistem_Yoneticisi/) | Kurma, yapılandırma, işletme | 10 Modül | Fiziksel altyapı, replikasyon, kimlik yönetimi, GPO, DNS, AD CS, hibrit Entra |
| 🛡️ **Blue Team (Savunma)** | [`2-Blue_Team`](2-Blue_Team/) | İzleme, tespit, sıkılaştırma, kurtarma | 10 Modül | WEF, Sysmon, SIEM/Sigma, Credential Guard, Tiering, PKI güvenliği, DFIR |
| 🔴 **Red Team (Saldırı & Cephanelik)** | [`3-Red_Team`](3-Red_Team/) | Keşif, sömürü, yanal hareket, cephanelik | 11 Modül | 10 Saldırı Aşaması + 18 Kategori ve 145 Araçlık Derin Cephanelik (Modül 11) |

---

## 📚 Modül Haritası

### 🏗️ Sistem Yöneticisi — Kurulum ve İşletme
1. [Mimari ve Temeller](1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/) — Forest/Tree/Domain, Schema, GC, Fonksiyon Seviyeleri
2. [Fiziksel Altyapı ve Replikasyon](1-Sistem_Yoneticisi/Modul_02_Fiziksel_Altyapi_ve_Replikasyon/) — DC, Sites, KCC, FSMO, RODC
3. [Nesne ve Kimlik Yönetimi](1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) — OU/Delegation, Gruplar (AGDLP), gMSA, FGPP
4. [Grup İlkeleri (GPO)](1-Sistem_Yoneticisi/Modul_04_Grup_Ilkeleri_GPO/) — LSDOU, filtreleme, GPP, Central Store
5. [DNS ve Ad Çözümleme](1-Sistem_Yoneticisi/Modul_05_DNS_ve_Ad_Cozumleme/) — AD-Integrated Zones, SRV, DNSSEC
6. [Depolama ve Dosya Servisleri](1-Sistem_Yoneticisi/Modul_06_Depolama_ve_Dosya_Servisleri/) — DFS-N/DFS-R, FSRM
7. [PKI ve Sertifika Servisleri (AD CS)](1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/) — Şablonlar, CRL, Autoenrollment
8. [Hibrit Kimlik ve Federasyon](1-Sistem_Yoneticisi/Modul_08_Hibrit_Kimlik_ve_Federasyon/) — Entra ID Connect, AD FS, SSO
9. [Otomasyon ve Arayüzler](1-Sistem_Yoneticisi/Modul_09_Otomasyon_ve_Arayuzler/) — PowerShell, DSC, LDAP/REST, WAC
10. [Güvenlik, Yedekleme ve Kurtarma](1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/) — NTDS, `ntdsutil`, Restore, hardening

### 🔴 Red Team — Saldırı Yaşam Döngüsü ve Araç Cephaneliği
> ⚔️ **Uçtan Uca Senaryolar:** [Operasyonel Oyun Kitabı (Playbook)](3-Red_Team/PLAYBOOK.md) — Attack Chain zincirleri, Kerberos hata çözümü ve OPSEC ilkeleri.

1. [Keşif ve Numaralandırma](3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/) — LDAP/BloodHound, ACL/SPN keşfi
2. [İlk Erişim ve Yerleşme](3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/) — LLMNR/NBT-NS Poisoning, Password Spraying
3. [Kimlik Bilgisi Erişimi](3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/) — Kerberoasting, AS-REP, LSASS, DPAPI
4. [Yanal Hareket](3-Red_Team/Modul_04_Yanal_Hareket/) — PtH/PtT, Overpass-the-Hash, PsExec/WMI/WinRM
5. [Yetki Yükseltme (ACL & GPO Abuse)](3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/) — DACL abuse, GPO abuse, Shadow Credentials
6. [Kerberos Delegation Saldırıları](3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/) — Unconstrained/Constrained/RBCD, Bronze Bit
7. [AD CS / PKI Saldırıları](3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/) — ESC1-8, Certifried, ForgeCert
8. [Koersiyon ve NTLM Relay](3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/) — ntlmrelayx, PetitPotam, ESC8, KrbRelayUp
9. [Domain Hakimiyeti ve Kalıcılık](3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/) — DCSync, Golden/Silver/Diamond, AdminSDHolder
10. [Trust, Forest ve Hibrit Saldırılar](3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/) — SID History, cross-forest, Entra pivot, OPSEC
11. [Araç Ustalığı ve Komut Notları](3-Red_Team/Modul_11_Arac_Ustaligi_ve_Komut_Notlari/) — **18 Kategori ve 145 Araçlık Tam Operasyonel Cephanelik** (CLI Bayrakları, Pratik Senaryolar, Troubleshooting, OPSEC/IOC ve Cheat Sheet'ler)

### 🛡️ Blue Team — Savunma Yaşam Döngüsü (Red ile 1:1 Simetrik)
1. [Görünürlük ve Log Yönetimi](2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/) ↔ Red 01 — WEF, Sysmon, Audit Policy
2. [SIEM ve Tespit Mühendisliği](2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/) ↔ Red 02/03 — Sigma/Elastic/Splunk, Event ID kataloğu
3. [Kimlik Bilgisi Koruması](2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/) ↔ Red 03 — Credential Guard, LAPS, Protected Users
4. [Yanal Hareket Tespiti](2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/) ↔ Red 04 — PtH/PtT tespiti, honeytoken
5. [Yetki ve ACL Sıkılaştırma](2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/) ↔ Red 05 — Tier Model, DACL hijyeni
6. [Kerberos ve Delegation Sertleştirme](2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/) ↔ Red 06 — delegation temizliği, AES
7. [AD CS / PKI Güvenliği](2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/) ↔ Red 07 — şablon denetimi, ESC önleme
8. [Protokol Sertleştirme ve Relay Önleme](2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/) ↔ Red 08 — LDAP/SMB signing, EPA
9. [Tehdit Avcılığı ve Değerlendirme](2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/) ↔ Red 09 — BloodHound, PingCastle, Purple Knight
10. [Olay Müdahalesi, DFIR ve Kurtarma](2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/) ↔ Red 10 — IR playbook, KRBTGT reset, Forest Recovery

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu depoda yer alan tüm dokümantasyon, teknik analizler, saldırı komutları ve araç kullanım kılavuzları; **yalnızca yasal sınırlar dahilinde gerçekleştirilen sızma testleri, kırmızı takım tatbikatları, yetkili güvenlik denetimleri ve savunma mekanizmalarının geliştirilmesi** amacıyla hazırlanmıştır.
>
> 1. **İzin ve Onay:** Buradaki tekniklerin yazılı izin ve yetkilendirme belgesi bulunmayan bilişim sistemleri üzerinde uygulanması; 5237 Sayılı Türk Ceza Kanunu (Madde 243, 244, 245) ve uluslararası siber suç mevzuatları (CFAA vb.) kapsamında suç teşkil eder.
> 2. **Sorumluluk Sınırı:** Proje yazarları ve katkıda bulunanlar; buradaki bilgilerin kötüye kullanılmasından, hedef sistemlerde meydana gelebilecek veri kayıplarından, kesintilerden veya yasal yaptırımlardan doğrudan ya da dolaylı olarak **sorumlu tutulamaz**.
> 3. **Savunma Önceliği:** Tüm saldırı teknikleri; güvenlik analistlerinin, mavi takım uzmanlarının ve sistem yöneticilerinin Active Directory ortamlarını sıkılaştırması (hardening) ve saldırıları gerçek zamanlı tespit edebilmesi amacıyla simetrik olarak sunulmuştur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar ve Teşekkür

Bu çalışmanın hazırlanmasında, siber güvenlik ekosistemine yön veren ve Active Directory araştırmalarına öncülük eden aşağıdaki saygın açık kaynak projelerinden, araştırma makalelerinden ve dokümantasyonlardan istifade edilmiştir:

- 🌐 [InternalAllTheThings — Swisskyrepo](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/): Active Directory sömürü teknikleri, komut dizilimleri ve referans saldırı kılavuzları.
- 🌐 [HackTricks Wiki — Carlos Polop](https://book.hacktricks.wiki/): Ağ, Active Directory ve ayrıcalık yükseltme tekniklerine dair ansiklopedik güvenlik rehberi.
- 🌐 [The Hacker Recipes — Shutdown](https://www.thehacker.recipes/): Active Directory protokolleri, Kerberos ve AD CS mekanizmaları üzerine derinlemesine metodoloji arşivi.
- 🌐 [SpecterOps Research](https://posts.specterops.io/): BloodHound graf teorisi, Certified Pre-Owned (AD CS) ve erişim kontrolü (ACL) araştırma raporları.
- 🌐 [MITRE ATT&CK Framework](https://attack.mitre.org/): Taktik, teknik ve alt-teknik eşleştirmeleri.
- 🌐 [Microsoft Open Specifications](https://learn.microsoft.com/en-us/openspecs/windows_protocols/): `[MS-ADTS]`, `[MS-KILE]`, `[MS-DRSR]`, `[MS-SFU]` protokol standartları ve teknik belgeleri.

---

## 🎓 Kimler İçin?

Kariyerini Microsoft kurumsal altyapıları üzerine kuran sistem yöneticileri, siber güvenlik uzmanları, altyapı mimarları, pentester'lar, tehdit avcıları ve SOC analistleri. Her dosya tek başına okunduğunda konuyu hem **öğretir**, hem **uygulatır**, hem de **savunma/saldırı boyutunu** eksiksiz gösterir.

