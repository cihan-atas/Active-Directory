# 🔴 Modül 08 — Koersiyon ve NTLM Relay (Coercion & NTLM Relay Attacks)

> **Kol:** 🔴 Red Team (Saldırı & Operasyonel Cephanelik) · **Kill Chain Aşaması:** Kimlik Bilgisi İstismarı ve Yanal Hareket (Credential Abuse / Lateral Movement)  
> **Simetrik Savunma Karşılığı:** [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)  
> **Sistem Tabanı:** [Sistem M01 — Mimari ve Temeller](../../1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/) & [Sistem M07 — PKI ve Sertifika Servisleri](../../1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/)  
> **Operasyonel Cephanelik:** [Modül 11 — Araç Ustalığı ve Komut Notları](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)

---

## 1. Genel Bakış ve Relay Felsefesi

NTLM kimlik doğrulama protokolünün (NTLMSSP) mimari açıdan en ölümcül zafiyeti; **kimlik doğrulama oturumunun hedef sunucuya veya güvenli kanala kriptografik olarak bağlanmamasıdır (Mutual Authentication ve Channel Binding eksikliği).**

Bir istemci sunucuya NTLM ile kimlik doğrulamak istediğinde; sunucunun ürettiği rastgele meydan okumayı (Challenge) kendi NT karmasıyla imzalayarak bir yanıt (Response / NetNTLMv2) döner. Araya giren bir saldırgan bu meydan okuma-yanıt trafiğini **hiç değiştirmeden ve kırmaya çalışmadan** üçüncü bir hedef servise (SMB, LDAP, HTTP, MSSQL) ileterek (Relay) kurbanın haklarıyla oturum açabilir.

Pasif zehirlemede (LLMNR/NBT-NS) kurbanın ağda hata yapması beklenirken; **Zorlamalı Kimlik Doğrulama (Coercion)** yöntemleri sayesinde saldırgan, etki alanındaki herhangi bir sunucuyu (özellikle **Domain Controller'ı**) saniyeler içinde istediği hedefe NTLM bağlantısı açmaya zorlar.

> **💡 Operasyonel İlke:**  
> *"SMB imzalama (SMB Signing) açık olsa bile, gelen NTLM oturumunu HTTP veya LDAP protokollerine aktarmak (Cross-Protocol Relay) mümkündür. Özellikle AD CS Web Enrollment (ESC8) veya imzasız LDAP arayüzleri, Domain Controller'ı tek bir RPC çağrısıyla düşürmek için mükemmel hedeflerdir."*

---

## 2. Koersiyon ve Relay Yaşam Döngüsü ve Mimari Akış

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    KOERSİYON VE NTLM RELAY YAŞAM DÖNGÜSÜ                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
           [Aşama 1: Dinleyici ve Relay Motorunun Hazırlanması]
           - ntlmrelayx başlat: -t ldap://dc01.corp.local --delegate-access
           - VEYA AD CS ESC8 için: -t http://ca.corp.local/certsrv/certfnsh.asp --template DomainController
           - Araçlar: impacket-ntlmrelayx
                                      │
                                      ▼
           [Aşama 2: Hedef Makinenin Koersiyon ile Zorlanması]
           - Hedef: DC01$ (Domain Controller makine hesabı)
           - MS-EFSR RPC çağrısı: PetitPotam (EfsRpcOpenFileRaw)
           - MS-RPRN RPC çağrısı: SpoolSample / PrinterBug
           - MS-DFSNM RPC çağrısı: DFSCoerce / Coercer
           - Araçlar: PetitPotam, Coercer, DFSCoerce, SpoolSample
                                      │
                                      ▼
           [Aşama 3: Meydan Okuma - Yanıt Değişimi (Relay Anı)]
           - DC01$, saldırganın IP'sine SMB kimlik doğrulaması başlatır
           - ntlmrelayx, gelen NTLM isteğini hedef Web (HTTP) veya LDAP servisine aktarır
           - Hedef servis kimliği doğrular ve yetkilendirir
                                      │
                                      ▼
           [Aşama 4: Hak Kazanımı ve Domain Hakimiyeti]
           │
           ├─► [LDAP Hedefli: RBCD veya Shadow Credentials Enjeksiyonu]
           │   - ntlmrelayx LDAP üzerinde DC01$ adına yeni makine açar veya RBCD ekler
           │   - S4U2proxy ile DC01$ üzerinde Administrator bileti alınır
           │
           └─► [AD CS ESC8 Hedefli: DC01$ Makine Sertifikası Üretimi]
               - CA sunucusu DC01$ adına geçerli bir makine sertifikası (pfx) döner
               - Certipy auth ile Kerberos TGT ve DC01$ NT karması çekilir
               - secretsdump ile tüm etki alanı veritabanı (krbtgt) dökülür (DCSync)
```

---

## 3. Modül Konuları ve Çalışma Kapsamı

| Konu | Dokümantasyon Dosyası | Kapsam ve Öğrenim Hedefleri |
|---|---|---|
| **08.1** | [NTLM Relay Senaryoları](./08.1_NTLM_Relay_Senaryolari.md) | NTLMSSP challenge-response akışı, SMB-to-SMB, SMB-to-LDAP, SMB-to-MSSQL relay matrisi, SMB Signing ve MIC (Message Integrity Code) kısıtlamaları. |
| **08.2** | [PetitPotam, PrinterBug ve DFSCoerce](./08.2_PetitPotam_PrinterBug_DFSCoerce.md) | RPC tabanlı zorlamalı kimlik doğrulama mimarisi, MS-EFSR, MS-RPRN, MS-DFSNM protokol analizleri, Coercer ile otomatik koersiyon taraması. |
| **08.3** | [Relay → AD CS (ESC8) Zinciri](./08.3_Relay_AD_CS_ESC8_Zinciri.md) | HTTP Web Enrollment (/certsrv) arayüzüne NTLM relay, EPA (Extended Protection for Authentication) yokluğu, DC01$ sertifikası ile anında DCSync zinciri. |
| **08.4** | [KrbRelayUp ile Yerel Yükseltme](./08.4_KrbRelayUp_ile_Yerel_Yukseltme.md) | Kerberos/NTLM yerel oturum relay teknikleri, COM/RPC arabirimleri, yerel `NT AUTHORITY\SYSTEM` yükseltmesinde RBCD ve Shadow Cred köprüleri. |

---

## 4. Operasyonel Araç Cephaneliği ve Modül 11 Eşleştirmesi

Koersiyon ve NTLM Relay operasyonlarında kullanılan başlıca araçların komut rehberleri:

| No | Araç | Modül 11 Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|---|---|---|---|
| 01 | **impacket-ntlmrelayx** | [impacket-ntlmrelayx.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/impacket-ntlmrelayx.md) | Gelen NTLM kimlik doğrulama oturumlarını yakalayıp LDAP, HTTP, SMB ve MSSQL servislerine aktaran endüstri standardı relay motoru. |
| 02 | **PetitPotam** | [PetitPotam.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/PetitPotam.md) | MS-EFSR (EfsRpcOpenFileRaw) üzerinden hedef Windows sistemlerini saldırgan makinesine NTLM bağlantısı açmaya zorlayan koersiyon aracı. |
| 03 | **Coercer** | [Coercer.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Coercer.md) | PetitPotam, PrinterBug, DFSCoerce, ShadowCoerce dahil 12'den fazla RPC metodunu tek çatı altında otomatik deneyen modern koersiyon aracı. |
| 04 | **DFSCoerce** | [DFSCoerce.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/DFSCoerce.md) | MS-DFSNM (Distributed File System Namespace Management) servisini kullanarak kimlik doğrulama zorlaması yapan araç. |
| 05 | **SpoolSample** | [SpoolSample.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/SpoolSample.md) | Yazıcı servisi (MS-RPRN Print System Remote Protocol) üzerinden hedefi zorlayan klasik PrinterBug uygulama aracı. |
| 06 | **ShadowCoerce** | [ShadowCoerce.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/ShadowCoerce.md) | MS-FSRVP (File Server Remote VSS Protocol) protokolünü kullanarak dosya sunucularını kimlik doğrulamaya zorlayan araç. |
| 07 | **Dementor** | [Dementor.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Dementor.md) | Spooler servisini tetikleyerek SMB kimlik doğrulamasını saldırgana yönlendiren Python betiği. |
| 08 | **KrbRelayUp** | [KrbRelayUp.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/KrbRelayUp.md) | Windows hedeflerde hiçbir ağ dinlemesi yapmadan yerel RPC/LDAP üzerinden doğrudan `NT AUTHORITY\SYSTEM` yetkisine yükselten C# aracı. |
| 09 | **KrbRelay** | [KrbRelay.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/KrbRelay.md) | Kerberos biletlerini yerel COM servisleri üzerinden relay ederek ayrıcalık yükselten düşük seviyeli araç. |
| 10 | **Responder** | [Responder.md](../Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/Responder.md) | Relay senaryolarında SMB ve HTTP sunucularını kapatıp (`SMB = Off`, `HTTP = Off`) trafiği ntlmrelayx'e yönlendiren zehirleme aracı. |

---

## 5. Savunma Karşılığı ve Mavi Takım Simetrisi

NTLM Relay ve koersiyon eylemleri savunma tarafında şu mekanizmalarla tamamen engellenebilir:

- **SMB ve LDAP İmzalama (Signing):** `RequireSecuritySignature = 1` ve `LDAPServerIntegrity = 2` ayarları ile oturum bütünlüğü zorlanarak relay girişimleri bağlantı aşamasında reddedilir.
- **EPA (Extended Protection for Authentication):** AD CS Web Enrollment ve IIS servislerinde EPA etkinleştirilerek NTLM oturumunun TLS kanalına (Channel Binding Token) bağlanması sağlanır.
- **RPC Filtreleme ve Gereksiz Servislerin Kapatılması:** Domain Controller'lar üzerinde Print Spooler servisi (`spoolsv.exe`) tamamen durdurulmalı; EFSR/DFSNM protokollerine RPC filtreleri uygulanmalıdır.
- **Detaylı Savunma Kılavuzları:**
  - [Blue M08 — Protokol Sertleştirme ve Relay Önleme](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)
  - [Blue 08.1 — LDAP Signing ve Channel Binding](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.1_LDAP_Signing_ve_Channel_Binding.md)
  - [Blue 08.4 — Koersiyon Önleme (PetitPotam & PrinterBug)](../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/08.4_Koersiyon_Onleme_PetitPotam_PrinterBug.md)

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu modülde yer alan NTLM relay, RPC zorlamalı kimlik doğrulama (Coercion) ve KrbRelayUp komutları; **yalnızca yetkili kırmızı takım tatbikatları, onaylı sızma testleri ve güvenli laboratuvar senaryoları** için sunulmuştur.
>
> Bir kurum ağında etki alanı denetleyicilerini zorlamak veya kimlik doğrulama akışlarını saptırmak kritik servis kesintilerine yol açabilir ve TCK Madde 243-245 kapsamında suçtur.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — NTLM Relay & Coercion (Swisskyrepo)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/ntlm/relay/): NTLM relay zincirleri, PetitPotam ve ESC8 rehberleri.
- 🌐 [HackTricks Wiki — NTLM Relay (Carlos Polop)](https://book.hacktricks.wiki/): SMB-to-LDAP, ESC8 Web Enrollment ve Coercion araçları.
- 🌐 [The Hacker Recipes — NTLM Relay Attacks](https://www.thehacker.recipes/): ntlmrelayx kullanımı, MIC baypası ve RBCD relay.
- 🌐 [Dirk-jan Mollema — The Worst of Both Worlds](https://dirkjanm.io/): SMB-to-LDAP relay ve RBCD zincirinin mimari analizi.

---

> **Önceki Modül:** [← Modül 07 — AD CS / PKI Saldırıları](../Modul_07_AD_CS_PKI_Saldirilari/README.md) · **Sonraki Modül:** [Modül 09 — Domain Hakimiyeti ve Kalıcılık →](../Modul_09_Domain_Hakimiyeti_ve_Kalicilik/README.md)
