# 🔴 Modül 04 — Yanal Hareket (Lateral Movement)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Yanal Hareket ve Yayılma (Lateral Movement)  
> **Simetrik Savunma Karşılığı:** [Blue M04 — Yanal Hareket Tespiti](../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/) & [Blue M03 — Kimlik Bilgisi Koruması](../../2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)  
> **Sistem Tabanı:** [Sistem M03 — Nesne ve Kimlik Yönetimi](../../1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/) & [Sistem M09 — Otomasyon ve Arayüzler](../../1-Sistem_Yoneticisi/Modul_09_Otomasyon_ve_Arayuzler/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Yanal Hareket Felsefesi

Yanal Hareket (Lateral Movement), bir saldırganın etki alanında ele geçirdiği bir başlangıç noktasından (Foothold) ağdaki diğer kritik sistemlere (sunucular, SQL veritabanları, yedekleme sistemleri ve Domain Controller'lar) sıçramasını sağlayan teknikler bütünüdür.

Active Directory ortamlarında yanal hareketin en çarpıcı gerçeği şudur: **Saldırganlar çoğunlukla yeni bir yazılım zafiyeti (exploit) sömürmezler; sistem yöneticilerinin ortamı yönetmek için her gün meşru olarak kullandığı protokolleri (SMB, WMI, WinRM, RPC, RDP) ele geçirilmiş kimliklerle kullanırlar.**

Kimlik doğrulama süreçlerinde açık metin parola bilmek şart değildir:
- **Pass-the-Hash (PtH):** NTLM kimlik doğrulamasında istemci parolayı değil, parolanın MD4 özetini (NT karması) sunucuya kanıtlar. Bu nedenle NT hash bir parola eşdeğeridir.
- **Overpass-the-Hash (Pass-the-Key):** NT veya AES anahtarı kullanılarak KDC'den doğrudan geçerli bir Kerberos TGT talep edilir; NTLM trafiğinden Kerberos'a geçiş yapılır.
- **Pass-the-Ticket (PtT):** Bellekten veya oturumdan çıkarılan `.kirbi` veya `.ccache` formatındaki Kerberos biletleri yeni oturuma enjekte edilerek parola/hash olmadan kaynaklara erişilir.

> **💡 Operasyonel İlke:**  
> *"PsExec gibi hizmet oluşturan araçlar diske ikili dosya yazar ve Sistem Olay Günlüğü'nde Event ID 7045 üretir (Gürültülü). Buna karşılık WMI (`wmiprvse.exe`) veya WinRM (`wsmprovhost.exe`) diske dosya bırakmadan bellek içinde çalışır (Sessiz). Hedef sistemin EDR yeteneklerine göre doğru protokolü seçin."*

---

## 2. Yanal Hareket Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      YANAL HAREKET VE YAYILMA AKIŞI                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Kimlik Doğrulama Yönteminin Belirlenmesi]
           - NT Hash mevcut ise ──▶ Pass-the-Hash (PtH)
           - AES Anahtarı mevcut ise ──▶ Overpass-the-Hash (TGT talebi)
           - Kerberos Bileti mevcut ise ──▶ Pass-the-Ticket (PtT - Kirbi/Ccache)
           - Araçlar: Rubeus, Mimikatz, NetExec, ticketConverter
                                      │
                                      ▼
           [Aşama 2: Uzak Yürütme Kanalının Seçilmesi (Execution Channel)]
           - SMB / Servis Tabanlı (Port 445): PsExec, SMBExec (Diske dosya yazar / 7045)
           - WMI Tabanlı (Port 135 + Dinamik RPC): WMIExec (DCOM/WmiPrvSE bellek içi)
           - WinRM / WS-Man (Port 5985/5986): Evil-WinRM, PowerShell Remoting (En modern)
           - Araçlar: impacket-wmiexec, impacket-psexec, Evil-WinRM, NetExec
                                      │
                                      ▼
           [Aşama 3: Hedefte Oturum Açma ve Yerel Yönetici Teyidi]
           - NetExec ile alt ağ taraması: nxc smb 10.10.10.0/24 -u user -H hash
           - "Pwn3d!" işareti: Hedef makinede Local Administrator hakkı onaylandı
                                      │
                                      ▼
           [Aşama 4: Yeni Hedefte Kimlik Hasadı ve Zincirleme]
           - Hedef sunucuda LSASS ve DPAPI hasadı (Modül 03)
           - Yeni oturum açmış kullanıcıları (HasSession) avlama (Modül 01.2)
           - Tier-0 (Domain Controller) hedefine ulaşana kadar döngüyü tekrarla
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **04.1** | [Pass-the-Hash ve Overpass-the-Hash](./04.1_Pass_the_Hash_ve_Overpass_the_Hash.md) | NTLM challenge-response matematiği, Pass-the-Key (AES-128/256), Pass-the-Cert (PKINIT), Overpass-the-Hash ile TGT üretimi ve LocalAccountTokenFilterPolicy (Remote UAC) baypas mekanizmaları. |
| **04.2** | [Pass-the-Ticket](./04.2_Pass_the_Ticket.md) | Kerberos TGT/TGS bilet anatomisi, `.kirbi` ve `.ccache` format dönüşümleri, `kerberos::ptt`, Kerberos Double-Hop sorunu ve çözümleri (tgtdeleg, CredSSP, RBCD). |
| **04.3** | [PsExec, WMI ve WinRM](./04.3_PsExec_WMI_WinRM.md) | SMB, WMI ve WinRM protokol karşılaştırması, DCOM tabanlı yanal hareket (`MMC20.Application`, `ShellWindows`), RDP oturum ele geçirme (`tscon.exe`) ve telemetri izleri. |
| **04.4** | [NetExec ile Otomasyon](./04.4_NetExec_Otomasyon.md) | Çoklu protokol orkestrasyonu (SMB, WMI, WinRM, RDP, MSSQL), "Pwn3d!" mantığı, modüler yürütme yöntemleri (`wmiexec, smbexec, atexec, mmcexec`) ve `spider_plus`/`lsassy` modülleri. |
| **04.5** | [MSSQL Database Link ve Çapraz Orman SQL Pivoting](./04.5_MSSQL_Database_Link_ve_Cross_Trust_Pivoting.md) | MSSQL veritabanı bağlantıları (`sp_addlinkedserver`), çok kademeli (multi-hop) `OPENQUERY` zincirleri, `rpc out` suiistimali ve trust sınırlarını aşarak `xp_cmdshell` ile RCE. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Yanal hareket operasyonlarında kullanılan başlıca araçların komut rehberleri:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **NetExec (nxc)** | [NetExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md) | SMB, WMI, WinRM, MSSQL ve LDAP protokolleri üzerinden kimlik doğrulayan, yerel yönetici tespiti yapan ve yanal hareketi otomatikleştiren lider araç. |
| 02 | **Evil-WinRM** | [Evil-WinRM.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/Evil-WinRM.md) | WinRM (5985/5986) servisi üzerinden PowerShell oturumu açan, Pass-the-Hash, dosya transferi ve bellek içi script yürütme sağlayan sızma aracı. |
| 03 | **WMIExec** | [WMIExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-wmiexec.md) | DCOM/WMI üzerinden diske servis yüklemeden yarı-etkileşimli komut yürüten, düşük tespit izine sahip Impacket aracı. |
| 04 | **PsExec** | [PsExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-psexec.md) | SMB üzerinden uzaktaki hedefe geçici Windows servisi kurarak doğrudan `NT AUTHORITY\SYSTEM` yetkisinde komut yürüten klasik araç. |
| 05 | **SMBExec** | [SMBExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/impacket-smbexec.md) | Hedef makinede `.exe` dosyası oluşturmadan doğrudan servis girdisi ile komut çalıştırıp çıktıyı SMB paylaşımları üzerinden okuyan Impacket aracı. |
| 06 | **CrackMapExec** | [CrackMapExec.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/NetExec_nxc.md) | Geniş ağlarda kimlik doğrulama testleri ve modüler yayılma gerçekleştiren NetExec'in öncülü olan popüler yanal hareket aracı. |
| 07 | **Rubeus** | [Rubeus.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Overpass-the-Hash (`asktgt`) ve Pass-the-Ticket (`ptt`) işlemlerini bellek içinde gerçekleştiren Kerberos manipülasyon aracı. |
| 08 | **ticketConverter** | [ticketConverter.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-ticketConverter.md) | Linux Kerberos biletleri (`.ccache`) ile Windows biletleri (`.kirbi`) arasında karşılıklı çift yönlü format dönüşümü yapan Impacket betiği. |
| 09 | **klist** | [klist.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/klist.md) | Windows yerel aracılığıyla geçerli oturumdaki Kerberos biletlerini listeleyen (`klist`) ve biletleri temizleyen (`klist purge`) LOLBin. |
| 10 | **wmic / schtasks** | [wmic.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/wmic.md) | Uzak sistemlerde meşru yönetim komutları ve zamanlanmış görevler tetikleyerek yanal hareket icra eden Windows yerel komutları. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

Yanal hareket eylemleri ağ ve uç nokta seviyesinde kuvvetli log korelasyonları üretir:

- **Windows Event ID 4624 (Logon Type 3 - Network):** SMB, WMI ve WinRM üzerinden gerçekleşen tüm uzaktan oturum açma eylemleri Logon Type 3 olarak kaydedilir.
- **Windows Event ID 7045 / 4697 (Yeni Servis Kuruldu):** PsExec veya SMBExec çalıştırıldığında oluşturulan servisler (PSEXESVC vb.) sistem günlüğüne kaydedilir.
- **Sysmon Event ID 1 (Process Creation):** `wsmprovhost.exe` (WinRM) veya `wmiprvse.exe` (WMI) süreçlerinin altında başlatılan `cmd.exe` veya `powershell.exe` çocuk süreçleri tipik bir yanal hareket göstergesidir.
- **PowerShell Script Block Logging (Event ID 4104):** WinRM veya uzak PowerShell oturumlarında çalıştırılan tüm bloklar içerikleriyle denetlenir.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M04 — Yanal Hareket Tespiti](../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/)
  - [Blue 04.2 — Pass-the-Hash ve Pass-the-Ticket Tespiti](../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/04.2_Pass_the_Hash_Ticket_Tespiti.md)
  - [Blue 04.3 — Uzak Yürütme İzleri](../../2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/04.3_Uzak_Yurutme_Izleri.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde açıklanan Pass-the-Hash, Pass-the-Ticket, WMI/WinRM uzak komut yürütme ve ağ yayılma teknikleri; **yalnızca yetkilendirilmiş kırmızı takım testleri, sızma testleri ve kontrollü laboratuvar ortamları** için hazırlanmıştır.
>
> Onaylanmış kapsam sınırları dışında ağ içi yanal hareket gerçekleştirmek sistem kararsızlıklarına yol açabileceği gibi TCK Madde 243-245 uyarınca ağır adli sonuçlar doğurur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Lateral Movement (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/lateral-movement/): Pass-the-Hash, Pass-the-Ticket ve uzak yürütme rehberleri.
- 🌐 [HackTricks Wiki — Lateral Movement in Active Directory (Carlos Polop)](https://book.hacktricks.wiki/): WMI, WinRM, SMB ve DCOM istismar metodolojisi.
- 🌐 [The Hacker Recipes — Lateral Movement](https://www.thehacker.recipes/): Pass-the-Hash ve uzak komut yürütme kanalları.
- 🌐 [SpecterOps — Pass-the-Hash & Pass-the-Ticket Guidance](https://posts.specterops.io/): Kerberos bilet enjeksiyonu ve NTLM kısıtlamaları.

---

> **Önceki Modül:** [← Modül 03 — Kimlik Bilgisi Erişimi](../Modul_03_Kimlik_Bilgisi_Erisimi/README.md) · **Sonraki Modül:** [Modül 05 — Yetki Yükseltme (ACL & GPO) →](../Modul_05_Yetki_Yukseltme_ACL_ve_GPO/README.md)
