# 🛡️ Active Directory Ustalık Programı & Vault

[![GitHub Release](https://img.shields.io/badge/Release-v1.2.0-blue.svg)](https://github.com/cihan-atas/Active-Directory/releases/tag/v1.2.0)
[![Download APK](https://img.shields.io/badge/Download-Android%20APK%20(v1.2.0)-success?logo=android&logoColor=white)](https://github.com/cihan-atas/Active-Directory/releases/download/v1.2.0/ActiveDirectory_Vault_v1.2.0.apk)
[![Architecture](https://img.shields.io/badge/Architecture-100%25%20Offline%20First-orange.svg)](#)
[![Topics](https://img.shields.io/badge/Külliyat-329%20Doküman-purple.svg)](#)
[![Operational Commands](https://img.shields.io/badge/Operasyonel%20Komut-3.160+-red.svg)](#)
[![MITRE ATT&CK](https://img.shields.io/badge/Framework-MITRE%20ATT%26CK-informational.svg)](https://attack.mitre.org/)
[![Status](https://img.shields.io/badge/Durum-Tamamlandı%20(v1.2)-brightgreen.svg)](#)

Active Directory (AD) kurumsal altyapılarını sıfırdan en ileri seviyeye kadar anlamak, yönetmek, sertleştirmek ve saldırı/savunma simetrisiyle derinlemesine kavramak amacıyla inşa edilmiş **ansiklopedik eğitim külliyatı ve operasyonel cephanelik platformudur**.

Aynı sistem mimarisi, birbirine çift yönlü çapraz referanslar veren **üç farklı operasyonel perspektif** üzerinden ele alınır:
- 🏗️ **Sistem Mimarı / Yöneticisi:** Kurulum, tasarım, replikasyon, kimlik ve orman yönetimi.
- 🛡️ **Blue Team (Savunma):** Tehdit avcılığı, SIEM/Sigma kuralları, Event ID telemetrisi ve sıkılaştırma.
- 🔴 **Red Team (Saldırı & Cephanelik):** Sızma teknikleri, yetki yükseltme, yanal hareket ve 153 araçlık operasyonel cephanelik.

---

## 📱 Active Directory Vault — Mobil ve Web Uygulaması

Projede yer alan tüm külliyat, sahadaki siber güvenlik operatörleri, pentester'lar ve sistem yöneticileri için **%100 Çevrimdışı (Offline-First)** çalışan modern bir uygulamaya dönüştürülmüştür.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ACTIVE DIRECTORY VAULT                          │
│   [ Hub ]     [ Red Team ]     [ Blue Team ]     [ SysAdmin ]          │
├────────────────────────────────────────────────────────────────────────┤
│  ⚡ KOMUT MOTORU      : 3.160+ Hazır Parametreli CLI Komutu & Debounce │
│  🎟 BİLET ÇÖZÜMLEME   : .kirbi & .ccache Base64 Kerberos Inspector     │
│  🗺 MITRE MATRİSİ     : İnteraktif Isı Haritası & Taktik Navigatörü    │
│  📊 YETENEK RADARI    : Sınav Karnesi & Konu Bazlı Radar Grafiği       │
│  🤖 AI OKUMA & SOHBET : Tam Ekran Okuma, Çevrimdışı Soru & İzole Tarih │
│  🎯 PENTEST CHECKLIST : CRTP / OSCP / CEH Uyumlu 8 Faz, 45+ Madde      │
│  🏆 GANİMET (LOOT)    : Hash, Bilet, IP ve Parola Defteri              │
│  🧠 LAB & SINAV       : 122 Soru Bankası & 10 Karar Ağacı Senaryosu    │
│  🎧 GELİŞMİŞ TTS      : 5 Ses Profili & Kesintisiz Dinamik Hız (2.5x)  │
│  🔍 AKILLI ARAMA      : Milisaniyelik Çevrimdışı Tam Metin İndeksi     │
│  🔗 SMART ROUTER      : Dahili Bağlantı Gezintisi & Dış Kaynak Pop-up  │
└────────────────────────────────────────────────────────────────────────┘
```

### 📥 Kurulum ve Çalıştırma

#### 1. Android (APK)
Uygulamayı harici hiçbir mağazaya veya internete ihtiyaç duymadan doğrudan telefonunuza ya da tabletinize yükleyebilirsiniz:
* 📲 **Doğrudan İndir:** [ActiveDirectory_Vault_v1.2.0.apk (56 MB)](https://github.com/cihan-atas/Active-Directory/releases/download/v1.2.0/ActiveDirectory_Vault_v1.2.0.apk)
* **Manuel ADB Kurulumu:**
  ```bash
  adb install -r ActiveDirectory_Vault_v1.2.0.apk
  ```

#### 2. Web Sürümü (Tarayıcı)
Projeyi yerel ağınızda veya tarayıcınızda sıfır kurulumla başlatmak için:
```bash
# Web sürümünü derleyin (opsiyonel)
./build_web.sh

# Yerel HTTP sunucusunu başlatın
python3 -m http.server -d dist/web 8080
```
Tarayıcınızda açın: **`http://localhost:8080`**

---

## 📊 Külliyat ve Cephanelik Metrikleri

Projenin derleme pipeline'ı tarafından taranan güncel operasyonel veriler:

| Metrik | Sayısal Değer | Açıklama |
| :--- | :--- | :--- |
| **Operasyonel Kol (Pillars)** | **3 Kol** | Sistem Yöneticisi, Blue Team, Red Team |
| **Modül Sayısı** | **31 Modül** | 10 Sistem + 10 Blue + 11 Red Team Modülü |
| **Alt Araç Kategorisi** | **18 Kategori** | Modül 11 kapsamındaki derin araç sınıflandırması |
| **Toplam Doküman & Kılavuz** | **329 Doküman** | Ansiklopedik derinlikte hazırlanmış markdown konuları |
| **Toplam Satır Sayısı** | **88.000+ Satır** | Pratik anlatım, kod blokları ve senaryolar |
| **Toplam Kelime Hacmi** | **615.000+ Kelime**| Kapsamlı teknik referans arşivi |
| **Operasyonel Komut Kataloğu** | **3.160+ Komut** | Parametre çözümleyicili, kopyalamaya hazır filtrelenmiş komutlar |
| **Desteklenen Araç Sayısı** | **153 Araç** | Impacket, Mimikatz, BloodHound, NetExec, Rubeus vb. |

---

## 🚀 Son Sürüm: v1.2.0 Öne Çıkan Yenilikler

* 🐧 **Linux Active Directory & SSSD Desteği (3 Kol Simetrisi):** Red Team bilet/keytab hasadı (`03.5`), Blue Team keytab & PAM sıkılaştırma (`03.5`), Sistem Yöneticisi SSSD/realmd entegrasyonu (`03.5`).
* 🗄️ **MSSQL Database Link & Cross-Trust Pivoting:** SQL Server `OPENQUERY` zincirleme, `xp_cmdshell` impersonation ve cross-trust atlama teknikleri (`Red 04.5`), SIEM telemetrisi ve link sıkılaştırma (`Blue 04.3`).
* 🔑 **OpenSSH LPK & LDAP Şema İstismarı:** `sshPublicKey` LDAP özniteliği manipülasyonu ile domain kalıcılığı ve yetki yükseltme (`Red 05.5`).
* 🧪 **GOAD & Simülasyon Laboratuvarı:** Game of Active Directory (GOAD), BadBlood ve AD test lablarının otomatik kurulum kılavuzu (`SysAdmin 10.5`).
* 🧰 **153 Araçlık Cephanelik (+7 Yeni Araç):** `lsarelayx`, `LdapRelayScan`, `ADFSRelay`, `LNKUp`, `Lnkbomb`, `DragonCastle`, `NTLMParse` 6 bölümlük standart operasyonel rehberle eklendi.
* 📱 **Vault Uygulaması Geliştirmeleri:** AI Asistanında dikkat dağıtıcı öğeleri gizleyen tam ekran okuma modu, modül/doküman bazlı izole geçmiş mimarisi ve 3.164 operasyonel komuta sahip arındırılmış komut motoru.

---

## 🎯 1:1 Simetrik Savunma ve Saldırı Felsefesi

Active Directory altyapısında hiçbir güvenlik olgusu tek taraflı değildir. Projedeki her Red Team saldırı tekniği, Blue Team tarafında **1:1 simetrik tespit ve önleme modülüyle** eşleştirilmiştir:

$$\text{Red Team Modül } N \iff \text{Blue Team Modül } N$$

*Örnek: **Kerberos Delegation***
- **Sistem Yöneticisi (Modül 03 & 04):** Hizmet hesaplarının (gMSA, SPN) işlevini ve güvenli delegation ilkelerini açıklar.
- **Red Team (Modül 06):** Unconstrained, Constrained, RBCD ve Shadow Credentials istismarlarını pratik komutlarla gösterir.
- **Blue Team (Modül 06):** Event ID 4768/4769 log telemetrisi, `AccountNotDelegated` koruması ve Sigma kurallarıyla tespiti öğretir.
- **Araç Cephaneliği (Modül 11):** Rubeus, Impacket, KrbRelayUp gibi araçların operasyonel parametrelerini listeler.

---

## 🗂️ Modül ve İçerik Haritası

### 🏗️ 1. Sistem Yöneticisi (Kurulum, Mimari ve İşletim)
[`1-Sistem_Yoneticisi/`](1-Sistem_Yoneticisi/)
1. **[Mimari ve Temeller](1-Sistem_Yoneticisi/Modul_01_Mimari_ve_Temeller/)** — Forest/Tree/Domain mantıksal hiyerarşisi, Schema, GC, Fonksiyonel Seviyeler.
2. **[Fiziksel Altyapı ve Replikasyon](1-Sistem_Yoneticisi/Modul_02_Fiziksel_Altyapi_ve_Replikasyon/)** — DC topolojisi, Sites & Subnets, KCC, FSMO Rolleri, RODC.
3. **[Nesne ve Kimlik Yönetimi](1-Sistem_Yoneticisi/Modul_03_Nesne_ve_Kimlik_Yonetimi/)** — OU mimarisi, Delegasyon, AGDLP gruplama, gMSA, FGPP parola politikaları, Linux SSSD/realmd entegrasyonu.
4. **[Grup İlkeleri (GPO)](1-Sistem_Yoneticisi/Modul_04_Grup_Ilkeleri_GPO/)** — LSDOU işleme sırası, WMI filtreleme, GPP, Central Store.
5. **[DNS ve Ad Çözümleme](1-Sistem_Yoneticisi/Modul_05_DNS_ve_Ad_Cozumleme/)** — AD-Integrated Bölgeler, SRV kayıtları, Scavenging, DNSSEC.
6. **[Depolama ve Dosya Servisleri](1-Sistem_Yoneticisi/Modul_06_Depolama_ve_Dosya_Servisleri/)** — DFS-Namespaces, DFS-Replication, FSRM kotaları.
7. **[PKI ve Sertifika Servisleri (AD CS)](1-Sistem_Yoneticisi/Modul_07_PKI_ve_Sertifika_Servisleri/)** — İki katmanlı PKI, Enterprise CA, Şablonlar, CRL/OCSP, Autoenrollment.
8. **[Hibrit Kimlik ve Federasyon](1-Sistem_Yoneticisi/Modul_08_Hibrit_Kimlik_ve_Federasyon/)** — Microsoft Entra Connect (PHS/PTA), AD FS, Seamless SSO.
9. **[Otomasyon ve Arayüzler](1-Sistem_Yoneticisi/Modul_09_Otomasyon_ve_Arayuzler/)** — Active Directory PowerShell Module, DSC, ADSI/LDAP, Windows Admin Center.
10. **[Güvenlik, Yedekleme ve Kurtarma](1-Sistem_Yoneticisi/Modul_10_Guvenlik_Yedekleme_ve_Kurtarma/)** — NTDS.dit bakımı, System State Backup, Tombstone, AD Recycle Bin, GOAD simülasyon laboratuvar kurulumu.

---

### 🛡️ 2. Blue Team (Tespit, İzleme, Sertleştirme ve DFIR)
[`2-Blue_Team/`](2-Blue_Team/)
1. **[Görünürlük ve Log Yönetimi](2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)** ↔ Red 01 — Audit Policy, WEF (Windows Event Forwarding), Sysmon konfigürasyonu.
2. **[SIEM ve Tespit Mühendisliği](2-Blue_Team/Modul_02_SIEM_ve_Tespit_Muhendisligi/)** ↔ Red 02/03 — Sigma kural yazımı, MITRE ATT&CK telemetrisi, Event ID kataloğu.
3. **[Kimlik Bilgisi Koruması](2-Blue_Team/Modul_03_Kimlik_Bilgisi_Korumasi/)** ↔ Red 03 — Credential Guard, Remote Credential Guard, LAPS, Protected Users, Linux keytab sertleştirme ve LSA SSP / SilentProcessExit tespiti.
4. **[Yanal Hareket Tespiti](2-Blue_Team/Modul_04_Yanal_Hareket_Tespiti/)** ↔ Red 04 — PtH, Overpass-the-Hash, PsExec, WMI/WinRM avcılığı, MSSQL xp_cmdshell ve LNK zehirleme telemetrisi.
5. **[Yetki ve ACL Sıkılaştırma](2-Blue_Team/Modul_05_Yetki_ve_ACL_Sikilastirma/)** ↔ Red 05 — Tiering / Enterprise Access Model, Privileged Access Workstations (PAW), DACL temizliği.
6. **[Kerberos ve Delegation Sertleştirme](2-Blue_Team/Modul_06_Kerberos_ve_Delegation_Sertlestirme/)** ↔ Red 06 — Delegation denetimi, AES zorlaması, PAC Validation, Kerberos zırhı (FAST).
7. **[AD CS / PKI Güvenliği](2-Blue_Team/Modul_07_AD_CS_PKI_Guvenligi/)** ↔ Red 07 — Sertifika şablon denetimi, ESC1-ESC8 sıkılaştırması, Certify telemetrisi.
8. **[Protokol Sertleştirme ve Relay Önleme](2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)** ↔ Red 08 — SMB Signing, LDAP Signing & Channel Binding, LLMNR/mDNS kapatma.
9. **[Tehdit Avcılığı ve Risk Değerlendirmesi](2-Blue_Team/Modul_09_Tehdit_Avciligi_ve_Degerlendirme/)** ↔ Red 09 — PingCastle, Purple Knight, BloodHound Blue, baseline denetimi.
10. **[Olay Müdahalesi, DFIR ve Kurtarma](2-Blue_Team/Modul_10_Olay_Mudahalesi_DFIR_ve_Kurtarma/)** ↔ Red 10 — KRBTGT çift resetleme prosedürü, Forest Recovery, NTDS adli incelemesi.

---

### 🔴 3. Red Team (Saldırı Yaşam Döngüsü ve Operasyonel Cephanelik)
[`3-Red_Team/`](3-Red_Team/)
> ⚔️ **Uçtan Uca Operasyon:** [Operasyonel Oyun Kitabı (PLAYBOOK.md)](3-Red_Team/PLAYBOOK.md) — 7 Aşamalı Attack Path, Kerberos Hata Kodları ve OPSEC Matrisi.

1. **[Keşif ve Numaralandırma](3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/)** — Anonim/Kimlikli LDAP, BloodHound/SharpHound graf keşfi, SPN tarama.
2. **[İlk Erişim ve Yerleşme](3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/)** — LLMNR/NBT-NS Poisoning (Responder), Password Spraying, Smart Card keşfi.
3. **[Kimlik Bilgisi Erişimi](3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/)** — Kerberoasting, AS-REP Roasting, LSASS Memory Dump (WerFault / Shtinkering), DPAPI, Linux AD bilet ve keytab hasadı.
4. **[Yanal Hareket](3-Red_Team/Modul_04_Yanal_Hareket/)** — Pass-the-Hash (PtH), Overpass-the-Hash, Pass-the-Ticket (PtT), PsExec, WMI, WinRM, MSSQL Database Link & cross-trust pivoting.
5. **[Yetki Yükseltme (ACL & GPO Abuse)](3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/)** — GenericAll, WriteDacl, Shadow Credentials (WHfB), OpenSSH LPK LDAP şema manipülasyonu, GPO istismarı.
6. **[Kerberos Delegation Saldırıları](3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/)** — Unconstrained, Constrained (S4U2Self/S4U2Proxy), RBCD, Bronze Bit.
7. **[AD CS / PKI Saldırıları](3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/)** — ESC1'den ESC8'e sertifika şablon istismarları, Certifried, ForgeCert.
8. **[Koersiyon ve NTLM Relay](3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/)** — PetitPotam, PrinterBug, ShadowCoerce, ntlmrelayx (AD CS & LDAP relay).
9. **[Domain Hakimiyeti ve Kalıcılık](3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/)** — DCSync, Golden/Silver/Diamond Ticket, Skeleton Key, AdminSDHolder, düşük yetkili DC kalıcılığı.
10. **[Trust, Forest ve Hibrit Saldırılar](3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/)** — SID History abuse, Cross-forest Kerberos hop, Azure AD Connect sync hesabı çıkarma.
11. **[Araç Ustalığı ve Komut Notları](3-Red_Team/Modul_11_Arac_Ustaligi_ve_Komut_Notlari/)** — **18 Kategori ve 153 Araçlık Tam Saha Cephaneliği**:
    - *Kategori 01:* Temel İstemciler ve Ağ Protokolleri (`smbclient`, `enum4linux-ng`, `netexec`, `rpcclient`, `ntlmparse`...)
    - *Kategori 02:* Windows Yerel Komut Satırı ve LOLBins (`cmd`, `powershell`, `certutil`, `reg`, `nltest`, `dsquery`...)
    - *Kategori 03:* Dizin Keşfi, Graf Analizi ve Haritalama (`BloodHound`, `SharpHound`, `ldapdomaindump`, `windapsearch`...)
    - *Kategori 04:* Zehirleme, MitM ve Zorlamalı Kimlik (`Responder`, `mitm6`, `inveigh`, `LNKUp`, `PetitPotam`, `Coercer`...)
    - *Kategori 05:* NTLM ve Kerberos Relay Motorları (`ntlmrelayx`, `lsarelayx`, `LdapRelayScan`, `KrbRelayUp`...)
    - *Kategori 06:* Kerberos Protokol Cephaneliği (`Rubeus`, `getTGT`, `getST`, `kerbrute`, `PKINITtools`...)
    - *Kategori 07:* Bellek Analizi, LSASS ve DPAPI Hasadı (`Mimikatz`, `pypykatz`, `Procdump`, `DragonCastle`, `DonPAPI`...)
    - *Kategori 08:* Active Directory Sertifika Servisleri (AD CS) (`Certify`, `Certipy`, `ForgeCert`, `PassTheCert`...)
    - *Kategori 09:* ACL, GPO ve Nesne Manipülasyonu (`PowerView`, `dacledit`, `pyGPOAbuse`, `Whisker`...)
    - *Kategori 10:* Kurumsal Altyapı Paylaşım ve Veri Avı (`Snaffler`, `Lnkbomb`, `CrackMapExec`, `SprayHound`...)
    - *Kategori 11:* Yanal Hareket ve Uzak Kod Yürütme (`wmiexec`, `psexec`, `evil-winrm`, `smbexec`, `atexec`...)
    - *Kategori 12:* NTDS, GPO Şifreleri ve LAPS Hasadı (`secretsdump`, `gpp-decrypt`, `LAPSToolkit`, `SharpLAPS`...)
    - *Kategori 13:* Tarihi ve Kritik Zafiyet Araçları (`MS14-068`, `Zerologon`, `NoPac`, `PrintNightmare`...)
    - *Kategori 14:* AD FS, Bulut ve Hibrit Kimlik (`ROADtools`, `AADInternals`, `ADFSRelay`, `o365spray`...)
    - *Kategori 15:* Yerel Yetki Yükseltme ve Potato Ailesi (`JuicyPotato`, `SweetPotato`, `GodPotato`, `PrintSpoofer`...)
    - *Kategori 16:* Tünelleme, Pivot ve SOCKS Proxy (`Chisel`, `Ligolo-ng`, `SocksOverRDP`, `rpivot`...)
    - *Kategori 17:* Modern EDR-Safe Beacon Object Files (BOF) (`Inline-Execute-Assembly`, `bof-netexec`, `nanodump`...)
    - *Kategori 18:* Çevrimdışı Parola Kırma (`Hashcat`, `John the Ripper`, `kerberoast.py`...)

---

## 🛠️ Derleme ve Otomasyon Sistemi

Proje, dokümantasyon güncellemelerini otomatik olarak parse edip derleyen betik altyapısına sahiptir:

```bash
# 1. Tüm Markdown Külliyatını Tara ve İndeksle
python3 scripts/build_content.py app/assets/data

# 2. Operasyonel Komutları ve Parametreleri Çıkar (3.160+ Komut)
python3 scripts/extract_commands.py

# 3. Yüksek Çözünürlüklü İkon ve Logoları Üret
python3 scripts/generate_app_icons.py

# 4. Android APK ve Web Sürümünü Paketle
./build.sh
```

---

## ⚖️ YASAL UYARI VE ETİK SINIRLAR (DISCLAIMER)

> **DİKKAT:** Bu depoda sunulan tüm içerikler, teknik açıklamalar, istismar kodları ve komut dizilimleri; **yalnızca yasal yazılı izin belgesi bulunan sızma testleri, kırmızı takım tatbikatları, yetkili güvenlik denetimleri ve siber savunma yeteneklerinin artırılması** amacıyla hazırlanmıştır.
>
> 1. Yetkisiz sistemler üzerinde bu tekniklerin uygulanması 5237 Sayılı TCK (Madde 243-245) ve uluslararası bilişim suçları kanunları gereğince hapis cezası ile sonuçlanabilecek ağır suçlar teşkil eder.
> 2. Proje yazarları ve katkıda bulunanlar, bilgilerin kötüye kullanılmasından veya sistemlerde oluşabilecek aksaklıklardan hiçbir koşulda sorumlu tutulamaz.
> 3. Savunma ve sıkılaştırma yönergeleri her zaman önceliklidir.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Swisskyrepo](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/): Sömürü teknikleri ve pratik komut dizilimleri.
- 🌐 [HackTricks Wiki — Carlos Polop](https://book.hacktricks.wiki/): Ansiklopedik ayrıcalık yükseltme ve AD sömürü yöntemleri.
- 🌐 [The Hacker Recipes — Shutdown](https://www.thehacker.recipes/): AD protokolleri ve PKI metodoloji arşivi.
- 🌐 [SpecterOps Research](https://posts.specterops.io/): BloodHound graf teorisi ve AD CS araştırma makaleleri.
- 🌐 [Microsoft Open Specifications](https://learn.microsoft.com/en-us/openspecs/windows_protocols/): `[MS-ADTS]`, `[MS-KILE]`, `[MS-DRSR]`, `[MS-SFU]` standartları.

---

**⭐ Yıldız Vermeyi Unutmayın!** Bu çalışmayı faydalı bulduysanız projeye GitHub üzerinden yıldız vererek topluluğa ulaşmasına destek olabilirsiniz.
