# 🔴 Modül 10 — Trust, Forest ve Hibrit Saldırılar (Trusts, Multi-Forest & Hybrid Cloud Attacks)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Forest Genişlemesi ve Bulut Pivotu (Forest Compromise / Cloud Pivot / Defense Evasion)  
> **Simetrik Savunma Karşılığı:** [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/) & [Blue M01 — Görünürlük](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)  
> **Sistem Tabanı:** [Sistem 01.4 — Trust İlişkileri](../../1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/01.4_Trust_Iliskileri.md) & [Sistem M08 — Hibrit Kimlik ve Federasyon](../../1-Sistem_Yoneticisi/Modul_08_Hibrit_Kimlik_ve_Federasyon/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Sınır-Ötesi Saldırı Felsefesi

Active Directory mimarisinde **tek bir etki alanı (Domain) bir güvenlik sınırı değildir; gerçek güvenlik sınırı Orman (Forest) yapısıdır.** Tek bir alt etki alanını (Child Domain) ele geçiren bir saldırgan, etki alanı sınırlarını rahatlıkla aşarak tüm ormanın kök etki alanına (Root Domain / Enterprise Admins) yükselebilir.

Ayrıca modern kurumsal yapılar artık yalnızca kurum içi (on-premises) AD ile sınırlı kalmayıp; **Microsoft Entra ID (Azure AD)** ve çoklu orman (Multi-Forest) güven ilişkileri ile birbirine bağlanmış hibrit mimarilere dönüşmüştür.

Bu modül, saldırı yaşam döngüsünün en ileri sınırlarını kapsar:

1. **Intra-Forest (Orman İçi) SID History Enjeksiyonu:** Aynı forest içindeki trust ilişkilerinde SID Filtering (SID Filtreleme) varsayılan olarak kapalıdır. Alt domain'in `krbtgt` anahtarıyla üretilen bir Golden Ticket'ın `ExtraSids` alanına Root Domain'in Enterprise Admins SID değeri (`-519`) enjekte edilerek orman genelinde tam kontrol sağlanır.
2. **Cross-Forest (Ormanlar Arası) Trust İstismarı:** İki farklı orman arasındaki External veya Forest trust ilişkilerinde SID Filtering devreye girer. Ancak `trustAttributes` incelemesi, Trust Key (`[MS-ADTS]`) çıkarma ve inter-realm TGT biletleri ile filtrelemenin izin verdiği RID > 1000 paylaşımlı kaynaklar sömürülür.
3. **Hibrit Kimlik ve Bulut Pivotu (Entra ID / Office 365):** Kurum içi ile bulutu eşitleyen **Microsoft Entra Connect (AADC)** sunucusunun ele geçirilmesi, şifrelenmiş senkronizasyon hesabı parolasının (`MSOL_`) bellekten çekilmesi, Primary Refresh Token (PRT) hırsızlığı ve AD FS üzerinden **Golden SAML** ile bulutta istenen kullanıcı adına imzasız token basılması.
4. **Savunma Atlatma (Defense Evasion - AMSI & ETW):** Saldırının her aşamasında PowerShell ve bellek içi kod çalıştırmayı engelleyen Antimalware Scan Interface (AMSI) ve telemetri toplayan Event Tracing for Windows (ETW) mekanizmalarının bellek içi yamalanması (`patching`).

> **💡 Operasyonel İlke:**  
> *"Bir alt etki alanını (child domain) güvenceye almadan kök etki alanını (forest root) koruyamazsınız. Aynı forest içindeki herhangi bir child domain'in ele geçirilmesi, matematiksel kesinlikle Enterprise Admins yetkisine giden yoldur (SID History)."*

---

## 2. Trust ve Hibrit Saldırı Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 TRUST, FOREST VE HİBRİT PİVOT YAŞAM DÖNGÜSÜ                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Orman İçi SID History Sıçraması (Intra-Forest)]
           - Child domain KRBTGT hash'i elde edildi (Modül 09)
           - Root domain Enterprise Admins SID değerini bul (Get-DomainGroup)
           - ExtraSids eklenmiş Golden Ticket üret: ticketer.py -extra-sid <ROOT_SID>-519
           - Root Domain Controller üzerinde doğrudan Enterprise Admin ol!
           - Araçlar: Mimikatz, ticketer.py, Rubeus
                                      │
                                      ▼
           [Aşama 2: Ormanlar Arası Güven Geçişi (Cross-Forest)]
           - Güven anahtarını (Trust Key / Inter-Realm Key) DCSync ile çek
           - Inter-Realm TGT üret ──▶ Hedef ormanın KDC'sinden TGS iste
           - Güven ilişkisindeki SID Filtering ve TGT Delegasyonunu test et
           - Araçlar: Rubeus, Mimikatz, PowerView
                                      │
                                      ▼
           [Aşama 3: Kurum İçi'nden Buluta Sıçrama (Entra ID Pivot)]
           │
           ├─► [Entra Connect / AADC Sunucusu Ele Geçirme]
           │   - LocalDB SQL veritabanından MSOL_ şifreli kimliğini çöz
           │   - Bulut üzerinde Global Reader veya Directory Synchronization yetkisi al
           │   - Araçlar: AADInternals, AzureHound
           │
           └─► [AD FS ve Golden SAML Saldırısı]
               - AD FS Token İmzalama Sertifikasını (Private Key) export et
               - Bulut KDC'ye sormadan sahte SAML yanıtı üret ──▶ Bulut Global Admin!
               - Araçlar: Mimikatz, AADInternals
                                      │
                                      ▼
           [Aşama 4: Görünmezlik ve Operasyonel Güvenlik (Defense Evasion)]
           - Bellek içi AMSI yamalama: amsiInitFailed bayrağını 1 yap
           - ETW sağlayıcılarını devreden çıkarma: EtwEventWrite API patch
           - Bellek içi yükleyiciler ile EDR taramalarını atlatma
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **10.1** | [SID History Injection ve Intra-Forest Yükseltme](./10.1_SID_History_Injection.md) | `sIDHistory` özniteliği, Kerberos PAC ExtraSids yapısı, Child-to-Parent yükseltme zinciri, mimari güvenlik sınırı illüzyonu ve Mimikatz/ticketer kullanımı. |
| **10.2** | [Cross-Forest Trust Abuse](./10.2_Cross_Forest_Trust_Abuse.md) | External vs. Forest Trust farkları, Inter-Realm Kerberos bilet değişimi, SID Filtering mimarisi, `trustAttributes` (Quarantine, ForestTransitive) analizi. |
| **10.3** | [Entra ID ve Bulut Pivot](./10.3_Entra_ID_ve_Bulut_Pivot.md) | Hibrit mimariler (PHS, PTA, AD FS), Entra Connect SQL şifre çözme, Primary Refresh Token (PRT) hırsızlığı, Golden SAML ile bulut hakimiyeti. |
| **10.4** | [Savunma Atlatma: AMSI, ETW ve OPSEC](./10.4_Savunma_Atlatma_AMSI_ETW_OPSEC.md) | Antimalware Scan Interface (AMSI) mimarisi ve bellek içi baypas teknikleri, Event Tracing for Windows (ETW) engelleme, EDR komut satırı izlerini gizleme. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Trust, forest ve bulut pivot saldırılarında sahada kullanılan başlıca araçların komut rehberleri:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **Mimikatz** | [Mimikatz.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_07_Bellek_Analizi_LSASS_ve_DPAPI_Hasadi/Mimikatz.md) | SID History enjeksiyonlu Golden Ticket basımı (`/sids`), AD FS token sertifikası çıkarma ve bellek içi AMSI baypas komutları. |
| 02 | **Rubeus** | [Rubeus.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/Rubeus.md) | Cross-Forest trust bilet değişimi, Inter-Realm TGT enjeksiyonu ve ExtraSids parametreli sahte bilet üretimi. |
| 03 | **AADInternals** | [AADInternals.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/AADInternals.md) | Entra Connect sunucusundan senkronizasyon kimliklerini deşifre eden ve Golden SAML token'ları üreten önde gelen PowerShell modülü. |
| 04 | **AzureHound** | [AzureHound.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/AzureHound.md) | Microsoft Entra ID (Azure AD) nesnelerini, tenant rollerini ve bulut saldırı yollarını BloodHound için toplayan resmi ajan. |
| 05 | **PowerView** | [PowerView.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/PowerView.md) | `Get-DomainTrust`, `Get-ForestDomain` ve `Get-DomainForeignGroupMember` fonksiyonlarıyla güven ilişkilerini ve orman sınırlarını haritalayan araç. |
| 06 | **impacket-ticketer** | [impacket-ticketer.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_06_Kerberos_Protokol_Cephaneligi/impacket-ticketer.md) | Orman içi ve ormanlar arası güven sömürüsünde ExtraSIDs ve Inter-Realm TGT biletleri üreten Linux aracı. |
| 07 | **ROADtools** | [ROADtools_roadrecon.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/ROADtools_roadrecon.md) | Entra ID tenant verilerini yerel SQLite veritabanına indirerek bulut kimlik ve uygulama izinlerini analiz eden keşif çatısı. |
| 08 | **nltest** | [nltest.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/nltest.md) | Yerel komut satırından güven ilişkilerini (`/domain_trusts`), SID filtreleme durumunu ve domain denetleyicilerini sorgulayan LOLBin. |
| 09 | **BOF-AD / SA-BOF** | [BOF-AD_SA-BOF.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/BOF-AD_SA-BOF.md) | Yeni süreç açmadan (processless) doğrudan beacon belleğinde çalışan EDR dostu C/C++ Active Directory keşif nesneleri. |
| 10 | **Ligolo-ng** | [Ligolo-ng.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/Ligolo-ng.md) | TUN arayüzü kullanarak kurumsal iç ağdaki hedeflere yerel ağ gibi doğrudan IP seviyesinde rota açan modern pivotlama aracı. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

Trust ve hibrit saldırılara karşı orman güvenliği ve bulut denetimi önlemleri:

- **SID Filtering (SID Karantinası Zorlaması):** Cross-forest External ve Forest trust ilişkilerinde `Enable-SIDFiltering` açık tutulmalı; `Quarantine` bayrağı aktif edilmelidir.
- **Entra Connect Güvenliği:** AADC sunucusu Tier-0 olarak sınıflandırılmalı, üzerinde yalnızca Domain Admins oturum açabilmeli ve EDR ile sıkı izlenmelidir.
- **AD FS Token Signing Sertifika Güvenliği:** Token imzalama anahtarı Donanımsal Güvenlik Modülünde (HSM) saklanmalı ve dışa aktarımı engellenmelidir.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M10 — Olay Müdahalesi, DFIR ve Kurtarma](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/)
  - [Blue 10.4 — Forest Recovery Süreci](../../2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/10.4_Forest_Recovery_Sureci.md)
  - [Blue 01.3 — Sysmon ile Derin Telemetri (AMSI/Process Injection)](../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/01.3_Sysmon_ile_Derin_Telemetri.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan SID History manipülasyonu, Cross-Forest trust istismarı, Entra ID bulut pivotu ve AMSI/ETW atlatma teknikleri; **yalnızca yetkilendirilmiş kırmızı takım tatbikatları, onaylı sızma testleri ve güvenli laboratuvar çalışmaları** için hazırlanmıştır.
>
> Bir kurumun ormanlar arası güven ilişkilerini sömürmek veya bulut kimlik altyapısını manipüle etmek tüm kurumsal ekosistemde yetkisiz erişimlere sebep olabilir ve TCK Madde 243-245 kapsamında suç teşkil eder.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Forest & Trust Attacks (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/forest-trust/): Cross-forest trust analizi, SID History ve bilet manipülasyonları.
- 🌐 [HackTricks Wiki — Active Directory Trusts & Cloud Pivot (Carlos Polop)](https://book.hacktricks.wiki/): Güven ilişkileri, AADInternals ve Entra Connect zafiyetleri.
- 🌐 [The Hacker Recipes — Forest Trusts & SID History](https://www.thehacker.recipes/): SID filtering mekanizması ve Golden Ticket ExtraSids rehberi.
- 🌐 [Will Schroeder (harmj0y) — A Guide to Attacking Domain Trusts](https://posts.specterops.io/): Trust mimarisi ve istismar metodolojisi.
- 🌐 [Dirk-jan Mollema — ROADtools & Azure AD Architecture](https://dirkjanm.io/): Entra ID ve hibrit kimlik güvenlik araştırmaları.

---

> **Önceki Modül:** [← Modül 09 — Domain Hakimiyeti ve Kalıcılık](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/README.md) · **Sonraki Modül:** [Modül 11 — Araç Ustalığı ve Komut Notları (145 Araçlık Cephanelik) →](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)
