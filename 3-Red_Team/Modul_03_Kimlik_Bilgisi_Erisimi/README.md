# 🔴 Modül 03 — Kimlik Bilgisi Erişimi (Credential Access)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Kimlik Bilgisi Erişimi (Credential Access)  
> **Simetrik Savunma Karşılığı:** [Blue M02 — SIEM ve Tespit](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/) & [Blue M03 — Kimlik Bilgisi Koruması](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)  
> **Sistem Tabanı:** [Sistem M03 — Nesne ve Kimlik (gMSA/FGPP)](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) & [Sistem M07 — PKI/Sertifikalar](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Kimlik Hasadı Felsefesi

Active Directory saldırı yaşam döngüsünde (Kill Chain) operasyonun ivme kazandığı en kritik dönüm noktası **Kimlik Bilgisi Erişimi** aşamasıdır. Düşük yetkili tek bir hesap elde edildikten sonra hedef; etki alanındaki diğer servis hesaplarını, yerel yöneticileri ve nihayetinde etki alanı yöneticilerini (Domain Admins) temsil eden kimlik kanıtlarını (NTLM karmaları, Kerberos biletleri, açık metin parolalar) ele geçirmektir.

Bu aşamada iki temel zafiyet ekseni kullanılır:

1. **Kerberos Protokol Tasarımı (Offline Roasting):** İstemciler servislerle iletişim kurabilmek için KDC'den TGS bileti talep eder. Biletin şifrelendiği anahtar ilgili servis hesabının (SPN) parolası olduğundan, kimliği doğrulanmış herhangi bir kullanıcı bu biletleri çekip çevrimdışı (offline) kırabilir (**Kerberoasting**). Benzer şekilde Kerberos ön kimlik doğrulaması kapatılmış (`DONT_REQ_PREAUTH`) hesapların AS-REP yanıtları doğrudan çekilebilir (**AS-REP Roasting**).
2. **İşletim Sistemi ve Bellek Mimarisi (LSASS & DPAPI):** Windows işletim sisteminde Single Sign-On (SSO) deneyimi sunabilmek için `lsass.exe` süreci kullanıcıların kimlik bilgilerini (NTLM hash, Kerberos TGT, WDigest) RAM üzerinde saklar. Ayrıca DPAPI (Data Protection API) kullanıcıların web tarayıcı şifrelerini, VPN profillerini ve RDP kayıtlarını diskte şifreler.

> **💡 Operasyonel İlke:**  
> *"Eğer elinizde bir NT karması (NTLM hash) varsa, onu kırmak için boşuna zaman ve GPU kaynağı harcamayın; Pass-the-Hash (PtH) ile doğrudan kullanın. Eğer hedef makinede Credential Guard aktifse, LSASS boştur; zaman kaybetmeden DPAPI sırlarına veya Kerberoasting'e yönelin."*

---

## 2. Kimlik Bilgisi Erişimi Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    KİMLİK BİLGİSİ ERİŞİMİ YAŞAM DÖNGÜSÜ                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Protokol Tabanlı Çevrimdışı Saldırılar (Roasting)]
           - Kerberoasting: GetUserSPNs veya Rubeus ile TGS-REP biletlerini iste
             (etype 23 - RC4 downgrade zorlaması)
           - AS-REP Roasting: GetNPUsers ile DONT_REQ_PREAUTH hesap biletlerini çek
           - Araçlar: impacket-GetUserSPNs, impacket-GetNPUsers, Rubeus
                                      │
                                      ▼
           [Aşama 2: Yerel Bellek Hasadı (LSASS Dökümü)]
           - SeDebugPrivilege yetkisini doğrula
           - Savunma Tespiti: RunAsPPL veya Credential Guard devrede mi?
           - PPL Yoksa: LOLBin (comsvcs.dll) veya sessiz bellek dökümü (nanodump)
           - PPL Varsa: Kernel driver, handle duplication veya DPAPI'ye yönel
           - Araçlar: nanodump, comsvcs.dll, Mimikatz, pypykatz, ProcDump
                                      │
                                      ▼
           [Aşama 3: Disk ve Kasa Hasadı (DPAPI & Vault)]
           - DPAPI MasterKey'lerini çöz (LSA Secret, Domain Backup Key veya RPC)
           - Tarayıcı kasaları (Chrome/Edge Login Data), RDP profilleri, Vault
           - Araçlar: SharpDPAPI, dpapi.py, DonPAPI, Seatbelt
                                      │
                                      ▼
           [Aşama 4: Çevrimdışı Kırma ve Hash Triyajı]
           - Kırma Stratejisi: Hashcat / John the Ripper
           - Mod Seçimi: Mod 13100 (Kerberoast RC4), Mod 18200 (AS-REP Roast), Mod 1000 (NTLM)
           - Karar: Kırılabilir basit parolalar çözülür; kırılamayan NT hash'ler PtH'a aktarılır
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **03.1** | [Kerberoasting, AS-REP Roasting ve Hedefli SPN Enjeksiyonu](./03.1_Kerberoasting_ve_AS_REP_Roasting.md) | Kerberos TGS-REP ve AS-REP bilet şifreleme matematiği, RC4/AES etype downgrade, hedefli SPN atama (Targeted Kerberoasting), PAC-less bilet talepleri ve Hashcat kırma. |
| **03.2** | [LSASS Bellek Mimarisi, PPL Baypas ve Özel SSP Enjeksiyonu](./03.2_LSASS_Bellek_Dokumu.md) | SSP paketleri (MSV1_0, Kerberos, CloudAP), RunAsPPL baypasları (BYOVD sürücüleri, PPLdump), özel SSP enjeksiyonu (`mimilib`), EDR filtrelerini atlatarak `nanodump` ve `comsvcs.dll` ile bellek dökümü. |
| **03.3** | [DPAPI, Credential Vault, LAPS ve Tarayıcı Sırlarının Hasadı](./03.3_DPAPI_ve_Credential_Vault.md) | DPAPI mimarisi, Kullanıcı/Sistem Master Key zincirleri, Domain Backup Key (`LsaUnprotectMemory` / PVK), LAPS v1 ve modern Windows LAPS (v2) çözümü, Chrome App-Bound Encryption çerez hasadı. |
| **03.4** | [Çevrimdışı Hash Kırma, Strateji ve Hash Shucking (NT Adayı)](./03.4_Offline_Hash_Kirma.md) | Hashcat mod seçimleri, Hash Shucking (NT-Adayı modları 35300, 35400, 27100), maske ve kural tabanlı kırma stratejileri, Pass-the-Hash vs. Hash Cracking operasyonel kararı. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Kimlik bilgisi erişimi tekniklerinde sahada kullanılan başlıca araçların komut kılavuzları:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **impacket-GetUserSPNs** | [impacket-GetUserSPNs.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-GetUserSPNs.md) | Etki alanındaki SPN kayıtlı servis hesaplarını sorgulayıp TGS biletlerini Hashcat formatında dışa aktaran Kerberoasting aracı. |
| 02 | **impacket-GetNPUsers** | [impacket-GetNPUsers.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-GetNPUsers.md) | Ön kimlik doğrulama gerektirmeyen kullanıcıların AS-REP biletlerini çekerek parolasız hash toplayan AS-REP Roasting aracı. |
| 03 | **Rubeus** | [Rubeus.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Windows ortamında ham Kerberos bilet manipülasyonu, Kerberoasting, AS-REP Roasting, Pass-the-Ticket ve bilet hasadı yapan C# aracı. |
| 04 | **Mimikatz** | [Mimikatz.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Mimikatz.md) | LSASS belleğinden açık metin parola, NT hash, Kerberos biletleri ve PIN'leri çıkaran efsanevi Windows güvenlik aracı. |
| 05 | **pypykatz** | [pypykatz.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/pypykatz.md) | LSASS minidump dosyalarını ve NTDS kovanlarını Linux ortamında tamamen çevrimdışı ayrıştıran saf Python Mimikatz uygulaması. |
| 06 | **nanodump** | [nanodump.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/nanodump.md) | EDR ve PPL mekanizmalarını atlatmak için Syscall ve handle duplication teknikleriyle son derece küçük ve şifreli LSASS dökümü alan C kütüphanesi. |
| 07 | **comsvcs.dll** | [comsvcs.dll.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/comsvcs.dll.md) | Windows yerleşik DLL'i; `MiniDump` fonksiyonu üzerinden hiçbir harici ikili yüklemeden LSASS dökümü almaya yarayan LOLBin. |
| 08 | **SharpDPAPI** | [SharpDPAPI.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/SharpDPAPI.md) | Windows DPAPI master key'lerini, tarayıcı kayıtlarını, Vault ve RDP şifrelerini bellekten ve diskten çözen C# aracı. |
| 09 | **DonPAPI** | [DonPAPI.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/DonPAPI.md) | Uzak Windows hedeflerine bağlanarak DPAPI sırlarını ve korunan kimlik bilgilerini otomatik toplayan Python aracı. |
| 10 | **ProcDump** | [ProcDump.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/ProcDump.md) | Sysinternals ailesinden meşru hata ayıklama aracı; EDR kurallarını atlatarak LSASS süreç dökümünü almakta kullanılır. |
| 11 | **Hashcat** | [Hashcat.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_18_Cevrimdisi_Parola_Kirma/Hashcat.md) | Kerberos TGS (13100), AS-REP (18200) ve NTLM (1000) karmalarını yüksek performansla kıran GPU destekli parola kırma motoru. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

Kimlik bilgisi erişimi teşebbüsleri mavi takım için en yüksek öncelikli alarm kaynaklarıdır:

- **Windows Event ID 4769 (Kerberos Bilet Talebi - Kerberoasting):** Bilet şifreleme türü `0x17 (RC4-HMAC)` olan veya kısa sürede çok sayıda servis için talep edilen TGS istekleri Kerberoasting alarmı üretir.
- **Windows Event ID 4768 (Ön Kimlik Doğrulama Kapalı - AS-REP):** Pre-auth türü `0` olan TGT talepleri izlenmelidir.
- **Sysmon Event ID 10 (ProcessAccess to LSASS):** `lsass.exe` sürecine `0x1010` veya `0x1FFFFF` erişim maskeleriyle handle açan şüpheli süreçler EDR/SIEM tarafından yakalanır.
- **RunAsPPL ve Credential Guard:** LSA sürecini korumalı süreç (Protected Process Light) yaparak yetkisiz bellek okumalarını engeller; Credential Guard ise sırları izole sanal makinede (VBS/LSAIso) saklar.
- **Detaylı Savunma Kılavuzları:**
  - [Blue 02.3 — Kerberoasting ve AS-REP Tespiti](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/02.3_Kerberoasting_AS_REP_Tespiti.md)
  - [Blue M03 — Kimlik Bilgisi Koruması](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)
  - [Blue 03.1 — Credential Guard ve LSASS Koruması](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/03.1_Credential_Guard_ve_LSASS_Korumasi.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde anlatılan Kerberoasting, LSASS bellek dökümü ve DPAPI anahtar çözme teknikleri; **yalnızca yetkili sızma testi sözleşmeleri, kırmızı takım tatbikatları ve laboratuvar eğitimleri** kapsamında yürütülebilir.
>
> Yetki dışı sistemlerde bellek okuma veya etki alanı biletlerini çekerek çevrimdışı kırma girişimleri 5237 Sayılı TCK Madde 243-245 kapsamında suç teşkil eder. Yazarlar, bilgilerin hukuka aykırı kullanımından sorumlu değildir.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Credential Access (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/credential-access/): Kerberoasting, LSASS dökümü ve DPAPI sırları.
- 🌐 [HackTricks Wiki — Stealing Credentials (Carlos Polop)](https://book.hacktricks.wiki/): LSASS dumping, DPAPI extraction ve credential harvesting.
- 🌐 [The Hacker Recipes — Kerberoasting & Dumping](https://www.thehacker.recipes/): Kerberos bilet analizi ve bellek analizi rehberi.
- 🌐 [SpecterOps — Kerberoasting & DPAPI Architecture](https://posts.specterops.io/): DPAPI domain backup keys ve LSA koruma mekanizmaları.

---

> **Önceki Modül:** [← Modül 02 — İlk Erişim ve Yerleşme](../Modul_02_Ilk_Erisim_ve_Yerlesme/README.md) · **Sonraki Modül:** [Modül 04 — Yanal Hareket →](../Modul_04_Yanal_Hareket/README.md)
