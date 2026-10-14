# BloodHound CE

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Neo4j ve PostgreSQL tabanlı yeni nesil etki alanı saldırı yolu, ACL ve hibrit yetki ilişkilerini görselleştiren modern Attack Path Management (APM) platformu.

---

## 1. Genel Bakış ve Amaç

`BloodHound Community Edition (CE)`, SpecterOps tarafından geliştirilen ve Active Directory ile Entra ID (Azure AD) ortamlarındaki gizli yetki ilişkilerini, erişim denetim listesi (ACL/ACE) suiistimallerini ve karmaşık saldırı yollarını (**Attack Paths**) **Graf Teorisi (Graph Theory)** kullanarak haritalayan endüstri standardı açık kaynaklı analiz platformudur.

Geleneksel Active Directory denetim araçları güvenliği nesne bazlı (kullanıcılar, gruplar, bilgisayarlar) listeler halinde incelerken, BloodHound güvenliği **ilişkiler ağı (Edges)** olarak modeller. Saldırganın sıradan bir etki alanı kullanıcısından (`Domain Users`), dolaylı grup üyelikleri (`MemberOf`), oturum hakları (`AdminTo` / `HasSession`), şifre sıfırlama (`ForceChangePassword`), nesne sahipliği (`WriteOwner`) ve delegasyon hakları üzerinden adım adım nasıl **Domain Admin / Enterprise Admin** olabileceğini saniyeler içinde hesaplar.

BloodHound CE (v5+), eski Electron/Legacy mimarisini tamamen geride bırakarak kurumsal düzeyde **Docker tabanlı istemci-sunucu (Client-Server)**, çok kullanıcılı web arayüzü, RESTful API ve gelişmiş AD CS (Active Directory Certificate Services) grafik modellemesi sunar.

### Protokol ve Çalışma Prensibi

BloodHound CE, toplayıcılar (`SharpHound`, `AzureHound`, `BloodHound.py`) tarafından toplanan JSON/ZIP verilerini işleyip ilişkisel ve graf veritabanlarına kaydeder:

```
┌──────────────────────────────────────────────────────────────┐
│             Hedef Ağ (Toplayıcılar - Ingestion)              │
│       [ SharpHound.exe ]       [ BloodHound.py / AdxHound ]  │
└──────────────────────────────┬───────────────────────────────┘
                               │ (Toplanan Veri: ZIP / JSON)
                               │ REST API / Web UI Upload (Port 8080)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 BloodHound CE Sunucu Katmanı                 │
│                                                              │
│  ┌─────────────────────────┐     ┌────────────────────────┐  │
│  │   bloodhound (API/Go)   │────►│  PostgreSQL (Port 5432)│  │
│  │   Web UI (Port 8080)    │     │  Kullanıcılar, Tokenlar│  │
│  └────────────┬────────────┘     └────────────────────────┘  │
│               │ (Cypher Sorguları / Bolt Protokolü Port 7687)│
│               ▼                                              │
│  ┌─────────────────────────┐                                 │
│  │    Neo4j Graph Database │                                 │
│  │  - Düğümler (Nodes)     │                                 │
│  │  - Kenarlar (Edges)     │                                 │
│  └─────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────┘
```

### Düğümler (Nodes) ve Kenarlar (Edges) Sözlüğü

| Düğüm Türü | Temsil Ettiği Nesne |
|---|---|
| `User` | Active Directory kullanıcı hesapları ve servis hesapları (SPN, msDS-SupportedEncryptionTypes vb.). |
| `Computer` | Domain Controller, sunucu ve iş istasyonu bilgisayar hesapları. |
| `Group` | Güvenlik grupları (Security Groups) ve dağıtım grupları. |
| `Domain` | Active Directory etki alanı kök nesnesi. |
| `OU` | Organizasyonel Birimler (Organizational Units). |
| `GPO` | Grup İlke Nesneleri (Group Policy Objects). |
| `CertTemplate` | Active Directory Sertifika Servisleri (AD CS) sertifika şablonları. |
| `EnterpriseCA` | Kurumsal Sertifika Otoritesi (CA) sunucuları. |
| `Container` | AD içindeki genel konteyner nesneleri (Users, Computers, NTDS vb.). |

| Kenar (Edge) Adı | Teknik Açıklama ve Saldırı Anlamı |
|---|---|
| `MemberOf` | Düğümün bir grubun doğrudan veya dolaylı (iç içe) üyesi olduğunu gösterir. |
| `AdminTo` | Kullanıcının veya grubun hedef bilgisayarda yerel yönetici (Local Administrator) olduğunu gösterir. |
| `HasSession` | Kullanıcının hedef bilgisayarda aktif veya bellekte kalmış bir oturumu (LSASS) olduğunu belirtir. |
| `GenericAll` | Hedef nesne üzerinde tam denetim (Full Control). Parola sıfırlama, grup üyesi ekleme, SPN yazma yapılabilir. |
| `GenericWrite` | Hedef nesnenin tüm yazılabilir özniteliklerini değiştirme yetkisi (`msDS-AllowedToActOnBehalfOfOtherIdentity` vb.). |
| `WriteDacl` | Hedef nesnenin ACL/ACE izinlerini değiştirme hakkı (Saldırgan kendine `GenericAll` verebilir). |
| `WriteOwner` | Nesnenin sahipliğini devralma hakkı (Sahiplik alındıktan sonra DACL değiştirilebilir). |
| `AllExtendedRights`| Hedef nesnedeki tüm genişletilmiş haklara sahip olma (DCSync, ForceChangePassword vb.). |
| `ForceChangePassword` | Kullanıcının mevcut parolasını bilmeden yeni parola atama yetkisi. |
| `AddMember` | Hedef gruba doğrudan yeni üye ekleme yetkisi. |
| `DCSync` | `DS-Replication-Get-Changes` ve `DS-Replication-Get-Changes-All` hakları; tüm etki alanı hash'lerini çekme. |
| `SyncLAPSPassword` / `ReadLAPSPassword` | LAPS veya Windows LAPS ile korunan yerel yönetici parolasını okuma yetkisi. |
| `WriteSPN` | Kullanıcı nesnesine SPN ekleme yetkisi (Kerberoasting zafiyeti oluşturulabilir). |
| `AddAllowedToAct` | Bilgisayar nesnesine RBCD (Resource-Based Constrained Delegation) yetkisi enjekte etme hakkı. |
| `AddKeyCredentialLink` | Shadow Credentials saldırısı ile nesneye `msDS-KeyCredentialLink` yazıp PKINIT ile TGT alma. |
| `ADCSESC1` - `ESC13` | AD CS sertifika şablonu ve CA zafiyetleri üzerinden yetki yükseltme yolları. |
| `GoldenCert` | Kök CA'nın özel anahtarını kullanarak keyfi etki alanı kullanıcısı adına sertifika basabilme. |

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **En Kısa Saldırı Yolu Tespiti** | Düşük yetkili bir foothold noktasından etki alanı yöneticiliğine giden en az adımlı yolu haritalama. |
| **AD CS Zafiyet Analizi (ESC1-ESC13)** | Sertifika şablonları ve CA'lar arasındaki hatalı yapılandırmaları grafik üzerinde otomatik çıkarma. |
| **DCSync İzinlerinin Tespiti** | Etki alanı kökünde `DS-Replication-Get-Changes-All` hakkına sahip gizli kullanıcı ve grupları bulma. |
| **LAPS ve Delegasyon Analizi** | LAPS parolalarını okuyabilen veya RBCD ile ele geçirilebilecek makineleri tek sorguyla görme. |
| **Hibrit Saldırı Yolları (Entra ID + On-Prem)** | AzureHound entegrasyonu ile buluttan kurum içine (Cloud-to-Ground) yetki yükseltme yollarını keşfetme. |
| **REST API ve Headless Operasyonlar** | SharpHound verilerini API üzerinden otomatik yükleme ve Cypher sorgularını script'lerle uzaktan çalıştırma. |

### Alternatif Araçlarla Karşılaştırma

| Kriter / Yetenek | `BloodHound CE (v5+)` | `BloodHound Legacy (v4.x)` | `Adalanche (Go)` | `PingCastle` |
|---|---|---|---|---|
| **Mimari** | Web / Docker (İstemci-Sunucu) | Electron Masaüstü Uygulaması | Tek Statik Binary (GUI) | Tek EXE / HTML Rapor |
| **Veritabanı** | Neo4j + PostgreSQL | Yalnızca Yerel Neo4j | Bellek İçi / SQLite | Yok (Statik Analiz) |
| **Çok Kullanıcılı Destek** | Var (Roller, API Anahtarları) | Yok (Tekil oturum) | Yok | Yok |
| **AD CS Desteği** | Çok Gelişmiş (ESC1-ESC13) | Yalnızca topluluk eklentileri | Var | Kısıtlı |
| **Performans ve Ölçek** | Çok Yüksek (100k+ nesne) | Büyük ağlarda kilitlenir | Yüksek | Yüksek |
| **REST API** | Kapsamlı RESTful API | Yok | Yok | Yok |

---

## 2. Temel Sözdizimi, Dağıtım ve API (CLI & Docker Flags)

### Docker Compose ile Dağıtım Sözdizimi

BloodHound CE resmi olarak Docker Compose ile dağıtılır. Temel dizin yapısı ve komutlar:

```bash
# BloodHound CE dizinini oluştur ve yapılandırma dosyasını indir
mkdir -p /opt/bloodhound && cd /opt/bloodhound
curl -L https://ghst.ly/getbhce -o docker-compose.yml

# Konteynerleri arka planda başlat
docker compose up -d

# Logları canlı takip et
docker compose logs -f bloodhound

# Konteynerleri durdur
docker compose down
```

### Örnek Docker Compose Yapılandırması ve Bellek Optimizasyonu

Büyük ölçekli Active Directory ortamlarında (50.000+ nesne) Neo4j ve PostgreSQL bellek yetersizliğinden çökebilir. `docker-compose.yml` içinde bellek ayarları şu şekilde optimize edilmelidir:

```yaml
version: '3.8'
services:
  app-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: bloodhound
      POSTGRES_PASSWORD: BloodHoundPostgresPass2026!
      POSTGRES_DB: bloodhound
    volumes:
      - postgres-data:/var/lib/postgresql/data

  graph-db:
    image: neo4j:4.4-community
    environment:
      NEO4J_AUTH: neo4j/BloodHoundNeo4jPass2026!
      NEO4J_dbms_memory_heap_initial__size: 2G
      NEO4J_dbms_memory_heap_max__size: 4G
      NEO4J_dbms_memory_pagecache_size: 2G
      NEO4J_apoc_export_file_enabled: "true"
      NEO4J_apoc_import_file_enabled: "true"
      NEO4J_dbms_security_procedures_unrestricted: "apoc.*"
    volumes:
      - neo4j-data:/data

  bloodhound:
    image: specterops/bloodhound:latest
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      bhe_database_connection: postgresql://bloodhound:BloodHoundPostgresPass2026!@app-db:5432/bloodhound
      bhe_neo4j_connection: bolt://neo4j:BloodHoundNeo4jPass2026!@graph-db:7687
    depends_on:
      - app-db
      - graph-db

volumes:
  postgres-data:
  neo4j-data:
```

### İlk Yönetici Parolasını Alma ve Sıfırlama CLI Komutları

Konteyner ilk başlatıldığında rastgele bir `admin` parolası üretilir:

```bash
# İlk kurulumda üretilen varsayılan parolayı loglardan çekme:
docker compose logs bloodhound | grep -i "initial password"

# Yönetici parolasını CLI üzerinden manuel sıfırlama:
docker compose exec bloodhound bloodhound-cli reset-password --username admin --password "YeniGucluParola2026!"
```

### REST API Uç Noktaları ve Kullanımı

BloodHound CE tüm işlevlerini REST API üzerinden açar:

| HTTP Metodu | Uç Nokta | Açıklama |
|---|---|---|
| `POST` | `/api/v1/login` | Kullanıcı adı/parola ile JWT oturum tokenı alma. |
| `POST` | `/api/v1/file-upload/start` | Veri yükleme işlemi başlatma (Upload ID döner). |
| `POST` | `/api/v1/file-upload/{id}` | Parçalı veya tam ZIP dosyasını yükleme. |
| `POST` | `/api/v1/file-upload/{id}/end` | Dosya yüklemesini tamamlama ve ingestion motorunu tetikleme. |
| `POST` | `/api/v1/graphs/cypher` | API üzerinden doğrudan Cypher sorgusu yürütme. |
| `GET` | `/api/v1/saved-queries` | Kayıtlı arama sorgularını listeleme. |

---

## 3. Pratik Komut ve Kullanım Senaryoları

### Senaryo 1: Docker Compose ile BloodHound CE Kurulumu ve Başlatılması

Saldırgan analiz sunucusunda (Kali Linux / Ubuntu VPS) platformu ayağa kaldırır:

```bash
mkdir -p /opt/bloodhound && cd /opt/bloodhound
curl -L https://ghst.ly/getbhce -o docker-compose.yml
docker compose pull
docker compose up -d
```

Tarayıcıdan `http://localhost:8080` adresine gidilir. Loglardan çekilen geçici parola ile giriş yapılarak yeni parola belirlenir.

---

### Senaryo 2: Toplanan Verilerin (ZIP) Arayüze Yüklenmesi

1. `SharpHound.exe` veya `BloodHound.py` tarafından üretilen `*.zip` arşivi elde edilir.
2. BloodHound CE web arayüzünde sol menüden **Administration -> File Ingestion** sekmesi açılır.
3. ZIP dosyası sürükle-bırak yöntemiyle yüklenir.
4. Arka planda `Ingestion Progress` çubuğu dolar ve Neo4j graf indeksleri otomatik oluşturulur.

---

### Senaryo 3: En Kısa Yoldan Domain Admins'e Ulaşım Analizi (Shortest Path to DA)

Sol üstteki arama çubuğundan yerleşik sorgu çalıştırılır veya Cypher konsoluna şu sorgu yazılır:

```cypher
MATCH p=shortestPath((n)-[r:MemberOf|HasSession|AdminTo|GenericAll|WriteDacl|WriteOwner|ForceChangePassword*1..]->(g:Group))
WHERE g.name ENDS WITH "DOMAIN ADMINS@LAB.LOCAL" AND NOT n=g
RETURN p
```

**Graf Analiz Adımları:**
1. Graf başlangıçta `jdoe` kullanıcısını gösterir.
2. `jdoe` -> `MemberOf` -> `Helpdesk Tier 1`.
3. `Helpdesk Tier 1` -> `GenericAll` -> `SRV-BACKUP$` bilgisayar nesnesi.
4. `SRV-BACKUP$` -> `HasSession` -> `da_admin` (Domain Admin oturumu!).
5. **Operasyonel Çıkarım:** Saldırgan `SRV-BACKUP$` makinesine LPE ile sızıp LSASS dökümü alarak `da_admin` biletini ele geçirebilir.

---

### Senaryo 4: DCSync Yetkisine Sahip Sıradan Hesapları Avlama

Domain Controller olmadan etki alanı şifrelerini çalma (DCSync) hakkı olan gizli hesaplar:

```cypher
MATCH (n)-[r:DCSync|GetChanges|GetChangesAll]->(d:Domain)
WHERE NOT n.name STARTS WITH "DOMAIN CONTROLLERS"
RETURN n.name, type(r), d.name
```

**Örnek Sonuç:**
```text
n.name                          type(r)      d.name
MSOL_5b2c1a8e3d@LAB.LOCAL       DCSync       LAB.LOCAL
svc_replication@LAB.LOCAL       GetChangesAll LAB.LOCAL
```
- `MSOL_...` hesabı (Azure AD Connect Sync hesabı) tespit edilir; bu hesabın parolası ele geçirilirse doğrudan `secretsdump.py` ile tüm NTDS.dit dökülebilir!

---

### Senaryo 5: AD CS ESC1 İstismar Yollarını Haritalama

Kullanıcıların sertifikada başka birinin kimliğini (SAN) belirterek etki alanı yöneticisi sertifikası üretmesini sağlayan ESC1 yolları:

```cypher
MATCH p=(u:User)-[:Enroll]->(ct:CertTemplate)-[:PublishedTo]->(ca:EnterpriseCA)-[:TrustedForNTAuth]->(d:Domain)
WHERE ct.enrolleesuppliessubject = true 
  AND ct.authenticationenabled = true
RETURN p
```
- Graf üzerinde zafiyetli şablon (`ct`), kayıt hakkı olan kullanıcılar (`u`) ve hedef CA tek zincirde görüntülenir.

---

### Senaryo 6: LAPS Şifrelerini Okuyabilen Kullanıcıları ve Bilgisayarları Bulma

LAPS korumalı yerel yönetici parolalarını doğrudan AD özniteliklerinden okuma yetkisi olan hesaplar:

```cypher
MATCH p=(u:User)-[r:SyncLAPSPassword|ReadLAPSPassword|AllExtendedRights]->(c:Computer)
RETURN u.name, type(r), c.name
```
*Operasyonel Fayda:* Ele geçirilen bir kullanıcı bu hakka sahipse, `nxc ldap <DC> -u user -p pass -M laps` ile hedef makinenin yerel `Administrator` parolası anında okunabilir.

---

### Senaryo 7: RBCD (Resource-Based Constrained Delegation) Yollarını Tespit Etme

Bir bilgisayar nesnesine `GenericAll`, `GenericWrite` veya `WriteDacl` hakkı olan kullanıcıların bu makineyi RBCD ile ele geçirme yolu:

```cypher
MATCH p=(u:User)-[r:GenericAll|GenericWrite|WriteDacl|WriteOwner]->(c:Computer)
WHERE NOT c.name STARTS WITH "DC"
RETURN p
```
*Operasyonel Fayda:* Saldırgan `rbcd.py` veya `Set-DomainObject` ile hedef bilgisayarın `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine kendi oluşturduğu bir makine hesabını ekler ve hedefte SYSTEM yetkisi alır.

---

### Senaryo 8: GPO İstismar Yollarını Haritalama (GPO Abuse Paths)

Bir GPO üzerinde değişiklik yapma hakkı olup bu GPO'nun uygulandığı OU veya bilgisayarları kontrol etme:

```cypher
MATCH p=(u:User)-[r:GenericAll|GenericWrite|WriteDacl]->(g:GPO)-[:GPLink]->(ou:OU)-[:Contains*1..]->(c:Computer)
RETURN p
```
*Operasyonel Fayda:* Saldırgan `pyGPOAbuse` veya `SharpGPOAbuse` ile ilgili GPO içine yerel yönetici ekleyen bir zamanlanmış görev (Scheduled Task) enjekte eder.

---

### Senaryo 9: Python ile BloodHound CE REST API'sine Otomatik Dosya Yükleyen Betik

Büyük operasyonlarda toplanan zip dosyalarını otomatik olarak BloodHound CE'ye gönderen otomasyon:

```python
#!/usr/bin/env python3
import requests
import sys

URL = "http://127.0.0.1:8080/api/v1/file-upload/start"
TOKEN = "bhe_your_api_key_token"

if len(sys.argv) < 2:
    print("Kullanım: python3 bh_upload.py <bloodhound_output.zip>")
    sys.exit(1)

zip_path = sys.argv[1]

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/zip"
}

print(f"[*] Dosya yükleniyor: {zip_path}")
with open(zip_path, 'rb') as f:
    response = requests.post(URL, headers=headers, data=f)

if response.status_code in [200, 201]:
    print("[+] Dosya başarıyla yüklendi ve işleme alındı!")
else:
    print(f"[-] Yükleme hatası: {response.status_code} - {response.text}")
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata / Belirti | Olası Neden | Çözüm Adımı |
|---|---|---|
| `Database connection failed / Neo4j container unhealthy` | Neo4j veya PostgreSQL konteyneri bellek yetersizliğinden çökmüştür ya da port çakışması vardır (7687/5432). | `docker compose ps` ile sağlık durumunu kontrol edin; makineye en az 4 GB RAM tahsis edin ve çakışan servisleri durdurun. `NEO4J_dbms_memory_heap_max__size` değerini 4G yapın. |
| İlk admin parolası loglarda görünmüyor | Konteyner logları temizlenmiş veya sessiz modda başlatılmıştır. | CLI üzerinden parolayı zorla sıfırlayın: `docker compose exec bloodhound bloodhound-cli reset-password --username admin --password "NewPass123!"`. |
| `File upload failed: Ingestion timeout / 413 Payload Too Large` | Yüklenen ZIP dosyası çok büyüktür (100 MB+) veya ters vekil (reverse proxy) gövde boyutunu sınırlamıştır. | ZIP içindeki JSON dosyalarını tek tek yükleyin veya Nginx/Docker ayarlarında `client_max_body_size 500M;` tanımlayın. |
| Cypher sorgusu boş dönüyor (`No records found`) | Düğümler küçük harf/büyük harf duyarlılığına takılmıştır (Örn: `DOMAIN ADMINS` yerine `Domain Admins`). | Arama koşullarında `toUpper(n.name)` fonksiyonunu veya `=~ '(?i).*admin.*'` regex eşleştirmesini kullanın. |
| `AD CS ilişkileri görünmüyor` | Toplama işlemi eski SharpHound v1.x ile yapılmıştır; AD CS toplayıcı bayrağı (`--collectionmethods All,Certificates`) kullanılmamıştır. | SharpHound v2+ kullanarak sertifika verilerini eksiksiz toplayın. |
| `Neo4j OutOfMemoryError / Java Heap Space` | Büyük veritabanlarında karmaşık Cypher sorguları RAM'i tüketmiştir. | Sorgulara `LIMIT 100` ekleyin veya `neo4j.conf` içinde heap boyutunu artırıp konteyneri yeniden başlatın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Sıfır Hedef Ağ İzi:** `BloodHound CE` analiz sunucusunda (Off-target) çalıştığı için hedef etki alanında hiçbir ağ paketi, olay günlüğü veya bellek izi oluşturmaz.
- **Toplayıcı İmzaları (Endpoint & DC):**
  - Hedef ağdaki asıl izler veriyi toplayan `SharpHound.exe` veya `BloodHound.py` tarafından bırakılır:
    - **Event ID 4662 (Directory Service Access):** Binlerce nesne üzerinde ACL/ACE okuma işlemi.
    - **Directory Service Event ID 1644:** Pahalı LDAP aramaları.
    - **Sysmon Event ID 3 (Network Connection):** DC'ye doğru binlerce LDAP/SMB oturumu.

### 5.2 Ağ ve EDR İmzaları

- **İzole Analiz:** EDR ve SOC ekipleri BloodHound CE sunucusunu göremez; yalnızca toplayıcının DC ve iş istasyonlarıyla kurduğu yoğun LDAP/RPC bağlantılarını (özellikle `NetSessionEnum` SMB çağrıları) izleyebilir.
- **Web UI Güvenliği:** BloodHound CE portu (8080) kesinlikle doğrudan genel internete (Public IP) açılmamalıdır; aksi takdirde kuruluşun tüm saldırı haritası Shodan gibi tarayıcılar tarafından indekslenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesapları ve ayrıcalık hiyerarşisini haritalama. |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup üyelikleri ve iç içe (nested) grupları görselleştirme. |
| **T1482** | Domain Trust Discovery | Etki alanı ve ormanlar arası güven ilişkilerini çıkarma. |
| **T1078** | Valid Accounts | Ele geçirilen hesapların kontrol ettiği sistemleri tespit etme. |
| **T1649** | Steal or Forge Authentication Certificates | AD CS sertifika şablonu saldırı yollarını tespit etme. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Web UI'ın Açığa Çıkması** | Port 8080'i yalnızca `127.0.0.1` adresine bağlayın (`127.0.0.1:8080:8080`) ve uzak erişim için **SSH Local Port Forwarding** (`ssh -L 8080:localhost:8080 user@vps`) kullanın. |
| **Veritabanı Çalınması Riski** | Toplanan AD verileri kritik kurum içi sırlar barındırdığından, Docker volume'lerini barındıran diski LUKS ile şifreleyin. |
| **Toplama Gürültüsünü Azaltma** | `SharpHound` çalıştırırken oturum toplama (`Session`) metodunu kapatarak yalnızca LDAP bazlı `DCOnly` toplayın. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (KQL — Microsoft Sentinel / Defender for Identity)
```kql
// Kısa sürede anormal sayıda nesne üzerinde ACL okuma tespiti
IdentityDirectoryEvents
| where ActionType == "DirectoryServiceAccess"
| where AdditionalFields has "Read Property" or AdditionalFields has "nTSecurityDescriptor"
| summarize QueryCount = count() by AccountName, IPAddress, bin(Timestamp, 5m)
| where QueryCount > 500
| order by QueryCount desc
```

#### Tespit Kuralı (Sigma — SharpHound Süreç Tespiti)
```yaml
title: SharpHound Reconnaissance Activity
status: high
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        CommandLine|contains:
            - 'CollectionMethods'
            - 'DCOnly'
            - 'ExcludeDCs'
            - 'Stealth'
    condition: selection
level: high
```

---

## 6. En Çok Kullanılan Cypher Sorguları ve Komutlar (Hızlı Referans / Cheat Sheet)

```cypher
// 1. Domain Admins grubuna giden en kısa saldırı yolları
MATCH p=shortestPath((n)-[r*1..]->(g:Group))
WHERE g.name ENDS WITH "DOMAIN ADMINS@LAB.LOCAL" AND NOT n=g
RETURN p
```
- **Ne Yapar?:** Etki alanındaki herhangi bir nesneden `Domain Admins` grubuna ulaşan en az adımlı yolları çizer.
- **Ne Zaman Kullanılır?:** İlk foothold alındıktan sonra yetki yükseltme planı yaparken.

```cypher
// 2. DCSync yetkisine sahip kullanıcı ve grupları listeleme
MATCH (n)-[r:DCSync|GetChangesAll]->(d:Domain)
WHERE NOT n.name STARTS WITH "DOMAIN CONTROLLERS"
RETURN n.name, type(r)
```
- **Ne Yapar?:** Etki alanı şifre veritabanını uzaktan replike etme yetkisine sahip tüm hesapları listeler.
- **Ne Zaman Kullanılır?:** Kimlik hırsızlığı öncesinde DCSync hedefi belirlemek için.

```cypher
// 3. Kerberoastable kullanıcıların yönetici olduğu sistemleri bulma
MATCH (u:User {hasspn: true})-[r:AdminTo]->(c:Computer)
RETURN u.name, c.name
```
- **Ne Yapar?:** SPN tanımlı olup aynı zamanda bilgisayarlarda yerel yönetici olan hesapları listeler.
- **Ne Zaman Kullanılır?:** Kerberoasting sonrası elde edilecek hash'in nerelerde yönetici olduğunu önceden bilmek için.

```cypher
// 4. Parolası asla sona ermeyen ve yönetici yetkisine sahip hesaplar
MATCH (u:User {pwdneverexpires: true})-[r:AdminTo]->(c:Computer)
RETURN u.name, c.name
```
- **Ne Yapar?:** Parolası süresiz olan ve hedef sistemlerde yönetici hakkı bulunan hesapları filtreler.
- **Ne Zaman Kullanılır?:** Kalıcılık ve parola püskürtme hedeflerini önceliklendirmek için.

```cypher
// 5. AD CS ESC1 zafiyetli sertifika şablonu saldırı yolları
MATCH p=(u:User)-[:Enroll]->(ct:CertTemplate)-[:PublishedTo]->(ca:EnterpriseCA)
WHERE ct.enrolleesuppliessubject = true AND ct.authenticationenabled = true
RETURN p
```
- **Ne Yapar?:** Kullanıcının sertifikada SAN belirterek yönetici sertifikası alabileceği yolları gösterir.
- **Ne Zaman Kullanılır?:** AD CS zafiyet sömürüsü planlarken.

```cypher
// 6. Unconstrained Delegation yetkisine sahip sunucuları bulma
MATCH (c:Computer {unconstraineddelegation: true})
WHERE NOT c.name STARTS WITH "DC"
RETURN c.name
```
- **Ne Yapar?:** DC'ler haricinde sınırsız yetkilendirmeye sahip sunucuları döker (TGT yakalama hedefleri).
- **Ne Zaman Kullanılır?:** SpoolSample / PetitPotam ile yönetici TGT'si yakalamak için hedef seçerken.

```cypher
// 7. LAPS parolalarını okuyabilen kullanıcıları listeleme
MATCH p=(u:User)-[r:SyncLAPSPassword|ReadLAPSPassword]->(c:Computer)
RETURN u.name, c.name
```
- **Ne Yapar?:** Hedef bilgisayarın yerel admin parolasını okuyabilecek kullanıcıları listeler.
- **Ne Zaman Kullanılır?:** Uç noktalara doğrudan yerel yönetici erişimi sağlamak için.

```cypher
// 8. Bilgisayarlar üzerinde RBCD (AddAllowedToAct) yetkisi olan kullanıcılar
MATCH p=(u:User)-[r:GenericAll|GenericWrite|WriteDacl]->(c:Computer)
WHERE NOT c.name STARTS WITH "DC"
RETURN u.name, type(r), c.name
```
- **Ne Yapar?:** Hedef bilgisayar nesnesi üzerinde RBCD enjekte edebilecek hesapları listeler.
- **Ne Zaman Kullanılır?:** Yanal hareket ve makine ele geçirme senaryolarında.

```cypher
// 9. AS-REP Roasting zafiyeti olan (Pre-Auth gerektirmeyen) hesaplar
MATCH (u:User {dontreqpreauth: true})
RETURN u.name
```
- **Ne Yapar?:** Şifre girmeden TGS/AS-REP hash'i çekilebilecek kullanıcıları bulur.
- **Ne Zaman Kullanılır?:** İlk erişim aşamasında çevrimdışı hash kırma için.

```cypher
// 10. Shadow Credentials (AddKeyCredentialLink) ile ele geçirilebilecek hedefler
MATCH p=(u:User)-[r:AddKeyCredentialLink|GenericAll|WriteProperty]->(t)
WHERE t:User OR t:Computer
RETURN u.name, type(r), t.name
```
- **Ne Yapar?:** `pywhiskey` veya `Whiskey` ile sertifika anahtarı enjekte edilip TGT alınabilecek hedefleri bulur.
- **Ne Zaman Kullanılır?:** Parola değiştirmeden PKINIT ile hesap devralmak için.

```bash
# 11. Docker CLI ile yönetici parolasını sıfırlama
docker compose exec bloodhound bloodhound-cli reset-password --username admin --password "P@ssw0rd2026!"
```
- **Ne Yapar?:** Unutulan veya kaybolan `admin` parolasını doğrudan backend CLI üzerinden günceller.
- **Ne Zaman Kullanılır?:** Arayüze giriş yapılamadığında.

```bash
# 12. Neo4j veritabanı indekslerini manuel güncelleme (Performans artışı)
docker compose exec graph-db cypher-shell -u neo4j -p BloodHoundNeo4jPass2026! "CREATE INDEX FOR (n:Base) ON (n.name);"
```
- **Ne Yapar?:** Sorguların 10 kata kadar daha hızlı çalışması için düğüm adı indeksini yeniden oluşturur.
- **Ne Zaman Kullanılır?:** 50.000+ nesneli büyük veritabanlarında yavaşlama yaşandığında.

---

## Kaynaklar

- **BloodHound CE Resmi Dokümantasyonu:** [https://support.bloodhoundenterprise.io/hc/en-us/categories/17277174304795-BloodHound-Community-Edition](https://support.bloodhoundenterprise.io/hc/en-us/categories/17277174304795-BloodHound-Community-Edition)
- **SpecterOps — BloodHound CE GitHub:** [https://github.com/SpecterOps/BloodHound](https://github.com/SpecterOps/BloodHound)
- **MITRE ATT&CK T1087.002:** [https://attack.mitre.org/techniques/T1087/002/](https://attack.mitre.org/techniques/T1087/002/)
- **Neo4j Cypher Manual:** [https://neo4j.com/docs/cypher-manual/current/](https://neo4j.com/docs/cypher-manual/current/)

---

> **Önceki Kategori:** [← 2. Windows Yerel Komut Satırı ve LOLBins](../Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/README.md) · **Sonraki:** [SharpHound →](./SharpHound.md)
