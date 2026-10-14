# 🔴 Modül 02 — İlk Erişim ve Yerleşme (Initial Access & Foothold)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** İlk Erişim ve Tutunma (Initial Access / Resource Development → Foothold)  
> **Simetrik Savunma Karşılığı:** [Blue M01 — Görünürlük](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/), [Blue M02 — SIEM ve Tespit](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/) & [Blue 08.4 — Koersiyon Önleme](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.4_Koersiyon_Onleme_PetitPotam_PrinterBug.md)  
> **Sistem Tabanı:** [Sistem M05 — DNS](../../1-Sistem_Yoneticisi/Modul_05_DNS_ve_Ad_Cozumleme/) & [Sistem M03 — Nesne ve Kimlik](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve İlk Erişim Felsefesi

Active Directory ortamlarında sıfır bilgiyle (Black-Box) veya sınırlı ağ erişimiyle başlayan bir saldırgan için ilk aşama, **etki alanında geçerli bir kullanıcı kimliği (Foothold)** elde etmektir. Bir etki alanına ilk erişim genellikle iki temel zafiyet ekseni üzerinden gerçekleşir:

1. **Eski Ad Çözümleme Protokollerinin Zehirlenmesi (LLMNR / NBT-NS / mDNS):** DNS sunucusunun çözemediği yerel ağ isteklerinde makineler yerel yayın (broadcast/multicast) yapar. Saldırgan bu istekleri sahte yanıtlarla zehirleyerek istemcilerden NTLMv2 kimlik doğrulama karmalarını (NetNTLMv2) toplar veya SMB/LDAP/HTTP servislerine aktarır (Relay).
2. **Kullanıcı Davranışları ve Zayıf Parolalar (Password Spraying):** Tek bir kullanıcıya binlerce parola denemek (Brute-Force) hesapları kilitler ve SIEM'de alarm üretir. Bunun yerine yüzlerce kullanıcıya mevsimlik/yıllık tek bir popüler parola (`Sonbahar2024!`, `Kurum123!`) denemek (**Password Spraying**), kilitlenme eşiğine takılmadan ilk hesabı düşürür.

> **💡 Operasyonel İlke:**  
> *"İlk erişimde en büyük düşman acele etmektir. Etki alanının parola politikasını (LockoutThreshold) bilmeden yapılan kontrolsüz denemeler, onlarca kullanıcının kilitlenmesine ve kırmızı takım operasyonunun anında ifşa olmasına yol açar. 'Low and Slow' yaklaşımı ile hareket edin."*

---

## 2. İlk Erişim Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      İLK ERİŞİM VE FOOTHOLD YAŞAM DÖNGÜSÜ                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Senaryo 1: Ağ Zehirleme (Poisoning) & MitM]
           - LLMNR / NBT-NS broadcast trafiğini dinle
           - mitm6 ile sahte IPv6 DNS/DHCP sunucusu olarak kendini duyur
           - NetNTLMv2 hash'lerini topla veya ntlmrelayx ile LDAP'a aktar
           - Araçlar: Responder, mitm6, Inveigh
                                      │
                                      ▼
           [Senaryo 2: Parola Püskürtme (Password Spraying)]
           - Kerbrute veya LDAP ile kullanıcı adı listesi doğrula (User Enum)
           - Kilitlenme politikasını sorgula (Lockout Window / BadPwdCount)
           - Güvenli zaman aralıklarıyla (örn. 30-45 dk) tek parola püskürt
           - Araçlar: Kerbrute, NetExec (nxc), DomainPasswordSpray
                                      │
                                      ▼
           [Elde Edilen Kimlik: Geçerli Domain Hesabı]
           - Kimlik doğrulama testi: nxc smb/ldap/winrm <IP> -u user -p pass
           - Hesap durum tespiti: Kilitli mi, süresi dolmuş mu, parola değişimi gerekli mi?
                                      │
                                      ▼
           [Durum Tespiti (Situational Awareness) ve Triyaj]
           - "Kimim ben?" (whoami /all, gruplar, ayrıcalıklar: SeDebugPrivilege vb.)
           - "Neredeyim?" (Host IP, Domain/Workgroup, OS mimarisi, EDR süreçleri)
           - "Ne yapabilirim?" (Modül 01 keşfine geçiş veya Modül 03 kimlik hasadı)
           - Araçlar: whoami, Seatbelt, PowerView, nltest
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **02.1** | [LLMNR, NBT-NS, mDNS, WPAD ve IPv6 Zehirlemesi](./02.1_LLMNR_NBTNS_mDNS_Poisoning.md) | Windows ad çözümleme geri düşüş mimarisi, NetNTLMv2 challenge-response, WPAD proxy sömürüsü, mitm6 ile IPv6 DNS ele geçirme, PXE/WDS boot imajı ve yazıcı sızıntıları. |
| **02.2** | [Password Spraying ve Pre2k Sömürüsü](./02.2_Password_Spraying.md) | Etki alanı kilitlenme politikası matematiği (`lockoutThreshold`, `badPwdCount`), zaman pencereleri, pre-Windows 2000 (`pre2k`) bilgisayar hesabı sömürüsü, çok protokollü spray. |
| **02.3** | [Kerbrute ile Enum, Spray, Timeroasting ve No-Auth NRPC](./02.3_Kerbrute_ile_Enum_ve_Spray.md) | Kerberos AS-REQ pre-auth yan kanalı (`userenum`), NauthNRPC ile kimliksiz kullanıcı dökümü, Timeroasting (NTP/SNTP) ile makine hesabı hash avı ve güvenli spray. |
| **02.4** | [İlk Foothold ve Durum Tespiti](./02.4_Ilk_Foothold_ve_Durum_Tespiti.md) | İlk ele geçirilen makinede 5 temel soru çerçevesi, `whoami /priv` ayrıcalıkları (SeImpersonate, SeDebug), fltmc ile minifilter EDR tespiti, PSReadLine geçmişi ve Potato privesc. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

İlk erişim ve durum tespiti süreçlerinde sahada aktif kullanılan araçların kapsamlı kılavuzları:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **Responder** | [Responder.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Responder.md) | LLMNR, NBT-NS ve MDNS yayınlarını sahte servislerle zehirleyerek istemcilerden NTLMv1/v2 kimlik doğrulamalarını yakalayan Python aracı. |
| 02 | **mitm6** | [mitm6.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/mitm6.md) | IPv4 ağlarda yapılandırılmamış IPv6 trafiğini istismar ederek sahte DNS sunucusu olan ve NTLM kimlik doğrulamasını tetikleyen MitM aracı. |
| 03 | **Inveigh** | [Inveigh.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Inveigh.md) | Windows hedeflerde PowerShell veya C# üzerinden çalışan, yerel yönetici olmadan da LLMNR/mDNS zehirlemesi yapabilen araç. |
| 04 | **Kerbrute** | [Kerbrute.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/Kerbrute.md) | Kerberos pre-authentication mekanizmasını kullanarak hesap kilitlemeden kullanıcı numaralandıran ve parola püskürten Go tabanlı hızlı araç. |
| 05 | **DomainPasswordSpray** | [DomainPasswordSpray.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/DomainPasswordSpray.md) | PowerShell üzerinden etki alanı kilitlenme politikasını otomatik okuyarak hesapları kilitlemeden kontrollü parola püskürtme yapan araç. |
| 06 | **Spray-Passwords** | [Spray-Passwords.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/Spray-Passwords.md) | Linux/Python ortamında çoklu protokolle (SMB, LDAP, Kerberos) güvenli parola püskürtme gerçekleştiren script. |
| 07 | **whoami** | [whoami.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/whoami.md) | Foothold alınan sistemde geçerli kullanıcının SID'sini, grup üyeliklerini ve ayrıcalıklarını (`/priv`) listeleyen temel Windows aracı. |
| 08 | **Seatbelt** | [Seatbelt.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Seatbelt.md) | Uç noktada güvenlik ayarlarını, yüklü savunma yazılımlarını, kayıt defteri zafiyetlerini ve durum tespitini yapan C# güvenlik denetim aracı. |
| 09 | **cmdkey** | [cmdkey.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/cmdkey.md) | Windows Credential Manager üzerinde saklanan açık/önbelleklenmiş kimlik bilgilerini (`cmdkey /list`) listeleyen yerel LOLBin. |
| 10 | **Hashcat** | [Hashcat.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_18_Cevrimdisi_Parola_Kirma/Hashcat.md) | Responder ile yakalanan NetNTLMv2 karmalarını (Mod 5600) GPU gücüyle çevrimdışı kırmaya yarayan endüstri standardı araç. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

İlk erişim girişimleri SIEM, EDR ve ağ izleme sistemlerinde belirgin izler bırakır:

- **Windows Event ID 4625 (Başarısız Oturum Açma):** Belirli bir zaman diliminde aynı kaynak IP'den çok sayıda farklı kullanıcı adına gelen başarısız oturum denemeleri parola püskürtmeyi (Spray) ele verir.
- **Windows Event ID 4768 / 4771 (Kerberos Ön Kimlik Doğrulama Hatası):** Kerbrute veya spray araçlarının ürettiği `0x18 (Pre-auth failed)` veya `0x6 (Client unknown)` hata kodları SIEM kurallarıyla yakalanır.
- **LLMNR/NBT-NS Kapatılması (GPO):** Savunmacılar GPO ile `Turn off multicast name resolution` politikasını etkinleştirerek zehirleme yüzeyini tamamen ortadan kaldırabilir.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M02 — SIEM ve Tespit Mühendisliği](../../2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/)
  - [Blue M03 — Kimlik Bilgisi Koruması](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)
  - [Blue 08.4 — Koersiyon Önleme](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.4_Koersiyon_Onleme_PetitPotam_PrinterBug.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan ağ zehirleme (Poisoning), parola püskürtme (Password Spraying) ve durum tespiti komutları; **yalnızca yasal yazılı izin belgesi bulunan sızma testleri ve yetkili eğitim senaryoları** için hazırlanmıştır.
>
> Yetkisiz ağlarda yayın paketlerini zehirlemek veya parola tahmin saldırıları gerçekleştirmek kurumsal iş akışlarını aksatabileceği gibi (hesap kilitlenmeleri), TCK Madde 243-245 uyarınca hukuki ve cezai sorumluluk doğurur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Initial Access & Password Attacks (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/initial-access/): LLMNR poisoning, password spray ve foothold analizleri.
- 🌐 [HackTricks Wiki — Windows Local Privilege Escalation & Recon (Carlos Polop)](https://book.hacktricks.wiki/): Foothold durum tespiti ve kimlik avı.
- 🌐 [The Hacker Recipes — LLMNR/NBT-NS Poisoning](https://www.thehacker.recipes/): Responder, Inveigh ve NTLMv2 karma analizleri.
- 🌐 [SpecterOps — Password Spraying Topolojileri](https://posts.specterops.io/): Kurumsal ortamlarda spray tespiti ve savunma yöntemleri.

---

> **Önceki Modül:** [← Modül 01 — Keşif ve Numaralandırma](../Modul_01_Kesif_ve_Numaralandirma/README.md) · **Sonraki Modül:** [Modül 03 — Kimlik Bilgisi Erişimi →](../Modul_03_Kimlik_Bilgisi_Erisimi/README.md)
