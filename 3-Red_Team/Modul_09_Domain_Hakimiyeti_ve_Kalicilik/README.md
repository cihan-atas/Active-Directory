# 🔴 Modül 09 — Domain Hakimiyeti ve Kalıcılık (Domain Dominance & Persistence)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Hakimiyet Kurma ve Kalıcılık (Dominance & Persistence)  
> **Simetrik Savunma Karşılığı:** [Blue M09 — Tehdit Avcılığı](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/) & [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/)  
> **Sistem Tabanı:** [Sistem M02 — Fiziksel Altyapı ve Replikasyon](../../1-Sistem_Yoneticisi/Modul_02_Fiziksel_Altyapi_ve_Replikasyon/) & [Sistem M10 — Güvenlik, Yedekleme ve Kurtarma](../../1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Hakimiyet Felsefesi

Active Directory sızma testlerinde ve kırmızı takım operasyonlarında "Domain Admin olmak" ile "Etki alanını **sahiplenmek ve kalıcı olmak**" arasında derin bir ayrım vardır. Parolalar değiştirildiğinde, kullanıcı hesapları silindiğinde veya oturumlar kapatıldığında saldırganın ortama yeniden ve iz bırakmadan erişebilmesini sağlayan tekniklere **Kalıcılık (Persistence)** adı verilir.

Bu aşamada etki alanının çekirdek mekanizmaları istismar edilir:

1. **Replikasyon Protokolü İstismarı (DCSync):** Microsoft'un etki alanı denetleyicileri arasında kullanıcı ve parola verilerini eşitlemek için kullandığı DRSNAPI (`[MS-DRSR]`) protokolü taklit edilir. Saldırgan DC üzerinde komut çalıştırmadan, uzaktan `krbtgt` hesabı dahil tüm etki alanının NT karmalarını çeker.
2. **Sahte Kerberos Biletleri (Forged Tickets):** Kerberos KDC'nin kalbi olan `krbtgt` anahtarı veya servis anahtarları kullanılarak kriptografik olarak kusursuz biletler üretilir:
   - **Golden Ticket:** `krbtgt` anahtarıyla üretilen, 10 yıla kadar geçerli kılınabilen sınırsız yetkili sahte TGT.
   - **Silver Ticket:** Yalnızca hedef servisin (CIFS, HTTP, LDAP) anahtarıyla üretilen ve KDC'ye hiç uğramayan sahte TGS bileti (Tamamen DC-dışı sessiz erişim).
   - **Diamond & Sapphire Ticket:** KDC'den meşru bir TGT isteyip PAC (Privilege Attribute Certificate) alanını bellekte değiştirerek tespit riskini (Event ID anomalileri) sıfıra indiren modern bilet teknikleri.
3. **Yapısal ve Dizin Tabanlı Kalıcılık:** DSRM (Directory Services Restore Mode) yönetici hesabı arka kapısı, AdminSDHolder nesnesi manipülasyonu ve DCShadow (Etki alanına geçici sahte DC ekleyerek SIEM logu üretmeden nesne değiştirme).
4. **Veritabanı Çıkarma (NTDS Exfiltration):** Volume Shadow Copy (VSS) veya `ntdsutil` kullanılarak `ntds.dit` ve SYSTEM kovanı çevrimdışı analiz için sızdırılır.

> **💡 Operasyonel İlke:**  
> *"Golden Ticket çok gürültülü olabilir; çünkü KDC loglarında bilet talebi olmadan (Event ID 4768 olmaksızın) birdenbire ortaya çıkan TGS talepleri (Event ID 4769) gelişmiş SIEM kurallarına takılır. Tespit edilmemek için meşru biletin PAC alanını modifiye eden Diamond Ticket veya DC'ye hiç uğramayan Silver Ticket tercih edilmelidir."*

---

## 2. Hakimiyet ve Kalıcılık Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 DOMAIN HAKİMİYETİ VE KALICILIK YAŞAM DÖNGÜSÜ                │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Replikasyon Protokolü Taklidi (DCSync)]
           - DS-Replication-Get-Changes-All haklarını kullan
           - krbtgt NT hash ve AES-256 anahtarını çek
           - Tüm etki alanı kullanıcılarının karmalarını dışa aktar
           - Araçlar: impacket-secretsdump, Mimikatz, NetExec
                                      │
                                      ▼
           [Aşama 2: Bilet Sahteciliği (Forged Kerberos Tickets)]
           │
           ├─► [Golden Ticket]
           │   - krbtgt hash + Domain SID + sahte PAC (500 Administrator)
           │   - Araçlar: ticketer.py, Mimikatz, Rubeus
           │
           ├─► [Silver Ticket]
           │   - Hedef servis NT hash (örn: CIFS/FILE01$)
           │   - KDC'ye uğramadan doğrudan servise erişim
           │   - Araçlar: ticketer.py, Mimikatz
           │
           └─► [Diamond & Sapphire Ticket]
               - KDC'den meşru TGT talep et ──▶ PAC alanını şifre çözüp yükselt
               - Bilet kimlik numarası (Ticket ID) meşru kalır, SIEM'i atlatır
               - Araçlar: Rubeus diamond
                                      │
                                      ▼
           [Aşama 3: Yapısal Dizin Kalıcılığı]
           - AdminSDHolder DACL'ine kalıcı kullanıcı ACE'si ekle (SDProp ile yayılır)
           - DCShadow ile RPC replikasyonu üzerinden izsiz nesne güncelle
           - DSRM logon behavior (DsrmAdminLogonBehavior=2) ile yerel DC arka kapısı
                                      │
                                      ▼
           [Aşama 4: Tam Veritabanı Sızdırma (NTDS.dit)]
           - VSS veya ntdsutil ile ntds.dit + SYSTEM kovanını kopyala
           - Çevrimdışı PEK anahtarı ile tüm parolaları ve geçmişlerini dök
           - Araçlar: secretsdump, pypykatz, ntdsutil
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **09.1** | [DCSync ile Hash Çıkarma](./09.1_DCSync_ile_Hash_Cikarma.md) | MS-DRSR replikasyon protokolü, `DS-Replication-Get-Changes` izinleri, DCSync paket akışı, `krbtgt` anahtarlarının önemi ve secretsdump kullanımı. |
| **09.2** | [Golden, Silver, Diamond ve Sapphire Ticket](./09.2_Golden_Silver_Diamond_Sapphire_Ticket.md) | PAC imza doğrulama mimarisi, Golden vs. Silver farkları, PAC sahteciliğini gizleyen Diamond ve Sapphire ticket teknikleri, bilet süre OPSEC'i. |
| **09.3** | [AdminSDHolder, DCShadow ve DSRM](./09.3_AdminSDHolder_DCShadow_DSRM.md) | `SDProp` sürecinin çalışması, AdminSDHolder arka kapısı, DCShadow ile SIEM logu üretmeden replikasyon enjeksiyonu ve DSRM yönetici hesabı istismarı. |
| **09.4** | [Skeleton Key ve NTDS.dit Exfiltration](./09.4_Skeleton_Key_ve_NTDS_Exfiltration.md) | LSASS bellek yamalama ile evrensel parola (`mimikatz`), Volume Shadow Copy (VSS) ile `ntds.dit` kopyalama, PEK (Page Encryption Key) çözme. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Domain hakimiyeti ve kalıcılık operasyonlarında kullanılan başlıca araçların komut rehberleri:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **ntdsutil** | [ntdsutil.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/ntdsutil.md) | Active Directory veritabanını (NTDS.dit) ve SYSTEM kovanını IFM yöntemiyle kilitsiz ve yasal yedekleme maskesi altında dışa aktaran araç. |
| 02 | **impacket-ticketer** | [impacket-ticketer.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-ticketer.md) | Linux ortamında Golden ve Silver Kerberos biletleri üreterek `.ccache` formatında dışa aktaran Impacket aracı. |
| 03 | **Mimikatz** | [Mimikatz.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Mimikatz.md) | Golden Ticket (`kerberos::golden`), DCSync (`lsadump::dcsync`), Skeleton Key (`misc::skeleton`) ve DCShadow (`misc::shadow`) yeteneklerini barındıran efsanevi araç. |
| 04 | **Rubeus** | [Rubeus.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Diamond Ticket (`diamond`) ve Sapphire Ticket sahteciliklerini bellek içinde icra ederek EDR alarmlarını atlatabilen C# Kerberos aracı. |
| 05 | **NetExec (nxc)** | [NetExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md) | `--ntds` bayrağı ile VSS veya ntdsutil yöntemlerini otomatik tetikleyerek etki alanı veritabanını dışa aktaran araç. |
| 06 | **pypykatz** | [pypykatz.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/pypykatz.md) | Sızdırılan `ntds.dit` ve SYSTEM kovanlarını Linux ortamında tamamen çevrimdışı ayrıştıran ve parolaları döken araç. |
| 07 | **reg** | [reg.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/reg.md) | DSRM arka kapısını yapılandırmak için kayıt defteri anahtarlarını (`reg add`) düzenleyen Windows yerel LOLBin. |
| 08 | **whoami** | [whoami.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/whoami.md) | Kalıcılık sonrasında sahte bilet enjeksiyonunun geçerliliğini doğrulamak için kullanılan komut satırı aracı. |
| 09 | **Hashcat** | [Hashcat.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_18_Cevrimdisi_Parola_Kirma/Hashcat.md) | NTDS dökümünden elde edilen binlerce NT karmasını şirket parola politikası analizi için çevrimdışı kıran GPU motoru. |
| 10 | **vssadmin / diskshadow** | [vssadmin_diskshadow.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/vssadmin_diskshadow.md) | Volume Shadow Copy servisini kullanarak kilitli NTDS.dit veritabanının anlık gölge kopyasını oluşturan Windows yerleşik araçları. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

Hakimiyet ve kalıcılık aşaması, DFIR (Dijital Adli Bilişim ve Olay Müdahalesi) için en kritik kanıtları içerir:

- **Windows Event ID 4662 (Dizin Hizmeti İşlemi - DCSync):** DC üzerinde DRSNAPI genişletilmiş haklarını (`1131f6aa-9c07-11d1-f79f-00c04fc2dcd2`) DC olmayan bir IP veya kullanıcının talep etmesi anında DCSync alarmı üretir.
- **Windows Event ID 4769 Bilet Uyuşmazlıkları:** TGT talebi (4768) olmadan doğrudan TGS talebi gelmesi sahte Golden Ticket kullanımını ele verir.
- **KRBTGT Çift Sıfırlama Döngüsü:** Bir ortama Golden Ticket bulaşmışsa kurtulmanın tek yolu, `krbtgt` hesabının parolasını Kerberos bilet ömrü (genellikle 10 saat) arayla **iki kez** sıfırlamaktır.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M09 — Tehdit Avcılığı ve Değerlendirme](../../2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/)
  - [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/)
  - [Blue 10.2 — KRBTGT Çift Reset ve Ticket Geçersizleştirme](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.2_KRBTGT_Cift_Reset_ve_Ticket_Gecersizlestirme.md)
  - [Blue 10.3 — NTDS Adli Analiz ve Timeline](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.3_NTDS_Adli_Analiz_ve_Timeline.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan DCSync replikasyonu, sahte bilet enjeksiyonları (Golden/Silver/Diamond), AdminSDHolder kalıcılığı ve NTDS veritabanı sızdırma teknikleri; **yalnızca yetkili kırmızı takım tatbikatları, onaylı sızma testleri ve güvenli laboratuvar senaryoları** için sunulmuştur.
>
> Bir kurumun kimlik veritabanını izinsiz çekmek, şifrelemek veya kalıcı arka kapılar yerleştirmek ulusal ve uluslararası siber suç mevzuatları (TCK Madde 243-245) kapsamında ağır cezai müeyyidelere tabidir.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Domain Persistence & Dominance (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/persistence/): DCSync, Golden/Silver Ticket ve DCShadow rehberleri.
- 🌐 [HackTricks Wiki — Active Directory Persistence (Carlos Polop)](https://book.hacktricks.wiki/): Kerberos bilet sahtecilikleri, DSRM ve Skeleton Key.
- 🌐 [The Hacker Recipes — Domain Dominance](https://www.thehacker.recipes/): DCSync akışı, bilet manipülasyonu ve NTDS çıkarma.
- 🌐 [SpecterOps — Kerberos Ticket Modifications (Diamond & Sapphire)](https://posts.specterops.io/): Charlie Clark tarafından yayınlanan modern Kerberos kalıcılık araştırmaları.
- 🌐 [Sean Metcalf (ADSecurity) — Active Directory Persistence Techniques](https://adsecurity.org/): AdminSDHolder, DSRM ve DCShadow mimari analizleri.

---

> **Önceki Modül:** [← Modül 08 — Koersiyon ve NTLM Relay](../Modul_08_Koersiyon_ve_NTLM_Relay/README.md) · **Sonraki Modül:** [Modül 10 — Trust, Forest ve Hibrit Saldırılar →](../Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/README.md)
