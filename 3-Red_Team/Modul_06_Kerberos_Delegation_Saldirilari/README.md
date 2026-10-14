# 🔴 Modül 06 — Kerberos Delegation Saldırıları (Kerberos Delegation Abuse)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Ayrıcalık Yükseltme ve Yanal Hareket (Privilege Escalation / Lateral Movement)  
> **Simetrik Savunma Karşılığı:** [Blue M06 — Kerberos ve Delegation Sertleştirme](../../2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/)  
> **Sistem Tabanı:** [Sistem M03 — Nesne ve Kimlik (Hesap Yönetimi)](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) & [Sistem 01.1 — Mantıksal Hiyerarşi](../../1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/01.1_Mantiksal_Hiyerarsi.md)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Yetki Devri Felsefesi

Active Directory ortamlarında çok katmanlı (multi-tier) uygulamaların (örneğin bir Web sunucusunun kullanıcı adına arka plandaki SQL veritabanına bağlanması) çalışabilmesi için Microsoft tarafından geliştirilen mekanizmaya **Kerberos Delegation (Yetki Devri)** adı verilir.

Yetki devri, bir servisin kendisini arayan istemcinin kimliğine bürünerek (impersonation) üçüncü bir servise onun adına kimlik doğrulamasına olanak tanır. Doğru kısıtlamalar konulmadığında bu özellik, saldırganlar için **etki alanındaki en ölümcül yetki yükseltme kapısına** dönüşür:

1. **Unconstrained Delegation (Kısıtlamasız Yetki Devri):** Bir sunucu bu bayrağa (`TRUSTED_FOR_DELEGATION`) sahipse, kendisine bağlanan her kullanıcının TGT (Ticket Granting Ticket) bileti belleğe (`lsass.exe`) kaydedilir. Saldırgan bu sunucuyu ele geçirdiğinde, sisteme bağlanan Domain Admin'lerin TGT'lerini toplayarak anında etki alanı yöneticisi olur.
2. **Constrained Delegation (Kısıtlı Yetki Devri - S4U):** Servisin yalnızca belirli hedeflere bürünmesine izin verilir. Ancak Microsoft'un Kerberos uzantıları olan **S4U2self** (Servisin kullanıcı adına kendisine bilet alması) ve **S4U2proxy** (Bu bileti hedef servise yönlendirmesi) protokol geçişi (Protocol Transition) ile istismar edilerek herhangi bir kullanıcı adına bilet üretilebilir.
3. **Resource-Based Constrained Delegation (RBCD):** Kısıtlı yetki devrinin hedef makine tarafından kontrol edilmesidir (`msDS-AllowedToActOnBehalfOfOtherIdentity`). Bir bilgisayar nesnesi üzerinde `GenericWrite` hakkı bulunan saldırgan, MachineAccountQuota (MAQ) ile yeni bir makine hesabı oluşturup hedef makineyi ele geçirebilir.
4. **Bronze Bit (CVE-2020-17049):** Kerberos servis biletlerindeki `Forwardable` bayrağının KDC kontrol mekanizmasını atlatarak Protected Users ve Sensitive kısıtlamalarını delme tekniğidir.

> **💡 Operasyonel İlke:**  
> *"RBCD tekniği, 'makine hesabına yazma hakkı = makineyi ele geçirme' formülüdür. Hedef sunucuda doğrudan komut yürütme yetkiniz olmasa bile, sadece LDAP üzerinden öznitelik yazarak makinenin SYSTEM yetkisini alabilirsiniz."*

---

## 2. Delegation Saldırı Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 KERBEROS DELEGATION SALDIRI YAŞAM DÖNGÜSÜ                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: LDAP ile Yetki Devri Yapılandırmalarının Keşfi]
           - Unconstrained: userAccountControl:1.2.840.113556.1.4.803:=524288
           - Constrained: msDS-AllowedToDelegateTo özniteliği dolu hesaplar
           - Araçlar: impacket-findDelegation, NetExec, PowerView
                                      │
                                      ▼
           [Aşama 2: Sömürü Metodunun Uygulanması]
           │
           ├─► [Unconstrained Delegation + Koersiyon (Coercion)]
           │   - Saldırgan ele geçirdiği unconstrained sunucuda dinleme yapar (Rubeus monitor)
           │   - SpoolSample veya PetitPotam ile Domain Controller zorlanır (RPC tetikleme)
           │   - DC01$ makinesinin TGT'si sunucu belleğine düşer ──▶ DCSync ile Domain Admin
           │   - Araçlar: Rubeus, SpoolSample, PetitPotam, impacket-secretsdump
           │
           ├─► [Constrained Delegation (S4U2self + S4U2proxy)]
           │   - Ele geçirilen servis hesabının hash/biletini kullan
           │   - S4U2self ile Administrator adına TGS bilet üret
           │   - S4U2proxy ile hedef SPN'e bilet yönlendir (alternatif servis hilesi: cifs/ldap)
           │   - Araçlar: impacket-getST, Rubeus s4u
           │
           └─► [Resource-Based Constrained Delegation (RBCD)]
               - Hedef bilgisayarda GenericWrite / WriteProperty hakkı
               - MAQ ile sahte makine oluştur: addcomputer.py -computer-name EVILPC$
               - msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğine EVILPC$'ı ekle
               - S4U2proxy ile hedef makinede Administrator bileti al ──▶ SYSTEM erişimi
               - Araçlar: impacket-addcomputer, rbcd.py, impacket-getST, Rubeus
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **06.1** | [Unconstrained Delegation Abuse](./06.1_Unconstrained_Delegation_Abuse.md) | Kısıtlamasız yetki devri mimarisi, TGT forwarding mekanizması, Rubeus ile bellekten TGT hasadı, PrinterBug/PetitPotam ile DC makine hesabını yakalayıp DCSync yapma. |
| **06.2** | [Constrained Delegation ve S4U](./06.2_Constrained_Delegation_S4U.md) | S4U2self ve S4U2proxy uzantıları, Protokol Geçişi (Protocol Transition), Service Principal Name (SPN) manipülasyonu ve AltService (cifs/host/http/ldap) alternatif servis hilesi. |
| **06.3** | [Resource-Based Constrained Delegation (RBCD)](./06.3_Resource_Based_Constrained_Delegation.md) | Kaynak tabanlı yetki devri, `msDS-AllowedToActOnBehalfOfOtherIdentity`, MachineAccountQuota (MAQ) istismarı, SPN-less RBCD ve NTLM relay ile otomatik delegasyon yazma. |
| **06.4** | [Bronze Bit (CVE-2020-17049)](./06.4_Bronze_Bit.md) | KDC bilet denetim açığı, `Forwardable` bitinin manipüle edilmesi, `USER_NOT_DELEGATED` ve Protected Users baypas teknikleri, Golden gMSA/dMSA saldırıları. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Kerberos yetki devri saldırılarında sahada kullanılan başlıca araçların komut rehberleri:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **Rubeus** | [Rubeus.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Unconstrained TGT izleme (`monitor`), S4U bilet talepleri (`s4u`), RBCD ve Bronze Bit saldırılarını Windows belleğinde yöneten lider C# aracı. |
| 02 | **impacket-getST** | [impacket-getST.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-getST.md) | S4U2self ve S4U2proxy protokol geçişlerini kullanarak istenen kullanıcı adına hedef servise Service Ticket (ST) üreten Impacket betiği. |
| 03 | **impacket-findDelegation** | [impacket-findDelegation.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/impacket-rbcd.md) | Etki alanındaki Unconstrained, Constrained ve RBCD yapılandırmasına sahip tüm hesapları listeleyen LDAP keşif betiği. |
| 04 | **impacket-addcomputer** | [impacket-addcomputer.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_09_ACL_GPO_ve_Nesne_Manipulasyonu/impacket-addcomputer.md) | MachineAccountQuota (MAQ) hakkını kullanarak RBCD saldırılarında gereksinim duyulan sahte makine hesabını etki alanına ekleyen araç. |
| 05 | **PowerView** | [PowerView.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/PowerView.md) | `Get-DomainComputer -Unconstrained` ve `Get-DomainUser -TrustedToAuth` komutları ile yetki devri tanımlı nesneleri listeleyen PowerShell modülü. |
| 06 | **SpoolSample / PrinterBug** | [SpoolSample.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/SpoolSample.md) | MS-RPRN Print System Remote Protocol üzerinden hedef sistemi saldırgan sunucusuna kimlik doğrulamaya zorlayan koersiyon aracı. |
| 07 | **PetitPotam** | [PetitPotam.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/PetitPotam.md) | MS-EFSR Encrypting File System Remote Protocol üzerinden hedef etki alanı denetleyicisini zorlayarak TGT/NTLM oturumu başlatan araç. |
| 08 | **Kekeo** | [Kekeo.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Benjamin Delpy tarafından yazılmış, ham Kerberos paketleri ve S4U istekleri üreten düşük seviyeli manipülasyon aracı. |
| 09 | **NetExec** | [NetExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md) | `--trusted-for-delegation` bayrağı ile etki alanındaki yetki devri yapılandırmalarını tek komutta tarayan çok amaçlı araç. |
| 10 | **secretsdump** | [secretsdump.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/ntdsutil.md) | Unconstrained delegation ile ele geçirilen DC makine hesabı TGT'si üzerinden tüm etki alanı karmalarını çeken (DCSync) araç. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

Delegation saldırılarına karşı alınabilecek başlıca tespit ve sıkılaştırma önlemleri:

- **Windows Event ID 4769 (S4U Kerberos Service Ticket Talebi):** `Transited Services` alanında beklenmeyen servis isimlerinin yer alması veya `0x40810000` bilet seçenekleri S4U istismarını gösterir.
- **Unconstrained Delegation Temizliği:** DC'ler haricinde hiçbir sunucuda kısıtlamasız yetki devri bırakılmamalı; eski IIS/SQL sunucuları RBCD mimarisine taşınmalıdır.
- **Protected Users Grubu:** Kritik ve ayrıcalıklı hesaplar (Domain Admins vb.) `Protected Users` grubuna eklenmeli veya hesap özelliklerinde `Account is sensitive and cannot be delegated` bayrağı işaretlenmelidir.
- **MachineAccountQuota (MAQ = 0):** Standart kullanıcıların etki alanına 10 adet bilgisayar ekleme hakkı sınırlandırılarak RBCD saldırıları önlenmelidir.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M06 — Kerberos ve Delegation Sertleştirme](../../2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/)
  - [Blue 06.1 — Delegation Envanteri ve Temizliği](../../2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/06.1_Delegation_Envanteri_ve_Temizligi.md)
  - [Blue 06.2 — Unconstrained Delegation Riskleri ve Önlemleri](../../2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/06.2_Unconstrained_Delegation_Riskleri_ve_Onlemi.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan Kerberos delegation istismarları, S4U protokol geçişleri, RBCD ve zorlamalı kimlik doğrulama (Coercion) komutları; **yalnızca yetkili kırmızı takım tatbikatları, sızma testleri ve güvenli laboratuvar çalışmaları** için hazırlanmıştır.
>
> Yazılı izin belgesi bulunmayan kurumsal ağlarda etki alanı denetleyicilerini zorlamak veya kimlik devralma saldırıları gerçekleştirmek kurumsal kimlik altyapısına kalıcı zararlar verebilir ve 5237 Sayılı TCK Madde 243-245 kapsamında suçtur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Kerberos Delegation Attacks (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/kerberos/delegations/): Unconstrained, Constrained ve RBCD rehberleri.
- 🌐 [HackTricks Wiki — Kerberos Delegation (Carlos Polop)](https://book.hacktricks.wiki/): S4U2self, S4U2proxy ve RBCD sömürü detayları.
- 🌐 [The Hacker Recipes — Kerberos Delegations](https://www.thehacker.recipes/): Protokol geçişleri ve kaynak tabanlı yetki devri kılavuzu.
- 🌐 [Elad Shamir — Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://eladshamir.com/): RBCD saldırısının keşif ve teorik makalesi.
- 🌐 [Microsoft Open Specifications [MS-SFU]](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-sfu/): Kerberos Protocol Extensions: Service for User.

---

> **Önceki Modül:** [← Modül 05 — Yetki Yükseltme (ACL & GPO)](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/README.md) · **Sonraki Modül:** [Modül 07 — AD CS / PKI Saldırıları →](../Modul_07_AD_CS_PKI_Saldirilari/README.md)
