# Active Directory Ustalık Programı: Sistem Mimarı Müfredatı (Platin Sürüm)

Bu belge, projenin tamamlanması için gereken tüm modülleri ve konuları içeren ana yol haritasıdır. Tamamlanan her madde işaretlenmelidir.

---

### **Amaç ve Hedef**

*   **Amaç:** Bu müfredat, Active Directory altyapılarını kurumsal ölçekte tasarlayabilen, güvenliğini sağlayabilen, otomasyon ile sürdürülebilir hale getirebilen ve modern hibrit bulut ortamlarına entegre edebilen sistem mimarları ve güvenlik uzmanları yetiştirmeyi amaçlar.
*   **Hedef Kitle:** Kariyerini Microsoft altyapıları üzerine kurmayı hedefleyen sistem yöneticileri, siber güvenlik uzmanları, altyapı mimarları ve DevOps mühendisleri.
*   **Öğrenme Çıktıları:** Bu programı tamamlayan bir profesyonel;
    *   Sıfırdan, güvenli ve ölçeklenebilir bir kurumsal AD topolojisi planlayabilir ve dağıtabilir.
    *   Gelişmiş GPO, PKI, DNSSEC ve Federasyon (AD FS) yapılandırmalarını hayata geçirebilir.
    *   Katmanlı yönetim modeli (Tier Model) ve modern güvenlik araçlarıyla AD güvenliğini en üst seviyeye çıkarabilir.
    *   PowerShell, DSC ve API entegrasyonları ile AD operasyonlarını otomatize edebilir.
    *   Felaket kurtarma, uyumluluk denetimi ve migration senaryolarını başarıyla yönetebilir.

---

### 🗂️ Modül 1: Mimari ve Temeller (Kalenin Planı)

- [ ] **1.1. Mantıksal Hiyerarşi:** Forest, Tree, Domain, Schema, Global Catalog, Fonksiyon Seviyeleri.
- [ ] **1.2. Fiziksel Altyapı ve Replikasyon:**
    - [ ] Domain Controllers (DC), AD Siteleri ve Servisleri.
    - [ ] Replikasyon Mekanizması: KCC (Knowledge Consistency Checker), Bridgehead Sunucuları, Intersite/Intrasite replikasyon farkları ve `repadmin` ile sağlık kontrolü.
    - [ ] Derinlemesine (Replikasyon Sağlığı): USN Rollback senaryoları, Tombstone Lifetime kavramı ve replikasyon çakışmaları.
- [ ] **1.3. Operasyonel Roller (FSMO):** 5 Rolün görevleri, yönetimi ve NTP (Zaman Senkronizasyonu) için PDC Emulator'un rolü.
- [ ] **1.4. Özel DC Rolleri:** Read-Only Domain Controller (RODC) ve Parola Önbellekleme Politikaları (PRP).

### 👥 Modül 2: Nesne Yönetimi (Kalenin Nüfusu)

- [ ] **2.1. Organizasyonel Birimler (OUs):** Tasarım Mimarisi, Yetki Devri (Delegation).
- [ ] **2.2. Hesap Yönetimi:** UPN vs. sAMAccountName, Attribute Editor ile nesne özellikleri.
- [ ] **2.3. Grup Yönetimi Ustalığı:** Türler, Kapsamlar, En İyi Pratik (AGDLP).
- [ ] **2.4. Özel Hesap Türleri:** Managed Service Accounts (MSA/gMSA).
- [ ] **2.5. Granüler Parola Politikaları (FGPP):** OU veya grup bazlı parola politikaları.

### 📜 Modül 3: Merkezi Yönetim (Kalenin Kanunları ve Fermanları)

- [ ] **3.1. GPO Mimarisi ve İşleyişi:** İşlenme Sırası (LSDOU), İstisnalar, GPC/GPT, Slow Link Detection.
- [ ] **3.2. GPO Hedefleme ve Filtreleme:** Security Filtering, WMI Filters, Item-Level Targeting.
- [ ] **3.3. Pratik Uygulamalar:** Güvenlik Politikaları, Yazılım Dağıtımı, Administrative Templates (ADMX/ADML) ve Central Store (Yeni işletim sistemi sürümlerine ait ADMX dosyalarının merkezi depoya eklenmesi dahil).
- [ ] **3.4. Group Policy Preferences (GPP):** Registry, kısayol, ortam değişkeni yönetimi.
- [ ] **3.5. GPO Sorun Giderme ve Analiz:** `gpresult`, `rsop.msc`, GPO Modelleme ve WEF ile merkezi log toplama.

### ⚙️ Modül 4: Altyapı ve Ekosistem (Kaleyi Destekleyen Servisler)

- [ ] **4.1. DNS Yönetimi:**
    - [ ] AD-Integrated Zones, Kritik SRV Kayıtları.
    - [ ] Yönetim: Aging ve Scavenging ayarları ile eski (stale) kayıtların otomatik temizlenmesi.
    - [ ] Güvenlik: DNSSEC ve Secure Dynamic Updates yapılandırması.
    - [ ] Sorun Giderme: `nslookup`, `dcdiag /test:dns`, `dnslint`.
- [ ] **4.2. Dosya, Yazıcı ve Sertifika Servisleri (PKI):**
    - [ ] DFS: Namespace/Replication ve `dfsrdiag` ile sağlık kontrolü. FSRM ile kota ve dosya engelleme politikaları.
    - [ ] Derinlemesine (AD CS): Sertifika Yaşam Döngüsü, CRL, Autoenrollment.
- [ ] **4.3. Hibrit Kimlik ve Federasyon:** Azure AD Connect (Entra ID Connect), Active Directory Federation Services (AD FS).

### 🤖 Modül 5: Otomasyon ve Arayüzler (Kalenin Dış Dünya ile Konuşması)

- [ ] **5.1. Protokoller ve Arayüzler:**
    - [ ] LDAP Mimarisi, `LDP.exe` ile sorgulama.
    - [ ] Pratik Entegrasyon: REST API ve LDAP tabanlı kimlik yönetim senaryoları (örneğin Entra ID API veya Python LDAP ile).
- [ ] **5.2. PowerShell ile Otomasyon Ustalığı:**
    - [ ] `ActiveDirectory` Modülü, gelişmiş replikasyon ve altyapı komutları.
    - [ ] Configuration as Code (IaC): PowerShell Desired State Configuration (DSC) ile AD yönetimi.
- [ ] **5.3. Modern Yönetim Arayüzleri:** Windows Admin Center (WAC).

### 🛡️ Modül 6: Güvenlik, Kurtarma ve Uyumluluk (Kalenin Zırhı)

- [ ] **6.1. AD Veritabanı (NTDS):** Kritik Dosyalar, SYSVOL (DFS-R), `ntdsutil.exe` ile bakım.
- [ ] **6.2. Yedekleme ve Kurtarma:** System State, Authoritative/Non-Authoritative Restore, AD Recycle Bin.
- [ ] **6.3. Güvenlik Sıkılaştırma (Hardening):**
    - [ ] Protokol Güvenliği: LDAP Signing/Channel Binding, NTLMv2 zorlaması, SMB signing gibi ayarların GPO ile yapılandırılması.
    - [ ] Hesap Güvenliği: Protected Users Group.
    - [ ] Mimari Güvenlik: Admin Tier Model (Tier 0-1-2).
- [ ] **6.4. İzleme ve SIEM Entegrasyonu:**
    - [ ] Windows Event Forwarding (WEF) ile log toplama.
    - [ ] Kritik Event ID'ler: AD güvenliği için izlenmesi gereken temel olaylar (örn: 4625 - Başarısız Giriş, 4720 - Kullanıcı Oluşturma, 4740 - Hesap Kilitleme, 4732 - Gruba Kritik Üye Ekleme).
- [ ] **6.5. İleri Seviye Operasyonlar:**
    - [ ] Proaktif Güvenlik Değerlendirmesi: BloodHound, PingCastle, Purple Knight ile düzenli güvenlik analizi.
    - [ ] Felaket Kurtarma Planı (DRP), Active Directory Migration Tool (ADMT).
- [ ] **6.6. Denetim ve Uyumluluk (Compliance):** ISO 27001, GDPR, SOC 2 gibi standartlar için GPO ve SACL'ler ile AD denetim politikalarını yapılandırma.
