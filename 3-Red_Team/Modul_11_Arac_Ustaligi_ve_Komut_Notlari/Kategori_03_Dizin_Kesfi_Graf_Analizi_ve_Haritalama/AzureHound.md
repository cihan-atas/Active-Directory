# AzureHound

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Entra ID (eski adıyla Azure AD) ve Azure bulut ortamlarındaki kullanıcılar, roller, servis prensipleri, uygulama izinleri ve Azure kaynakları arasındaki yetki ilişkilerini ve hibrit saldırı yollarını haritalandıran Go tabanlı BloodHound veri toplayıcısı.

---

## 1. Genel Bakış ve Amaç

**AzureHound**, SpectreOps tarafından geliştirilen ve Microsoft Entra ID (Azure Active Directory) ile Azure Resource Manager (ARM) ortamlarını hedef alan modern bir veri toplama (ingestor) aracıdır. Go dilinde sıfırdan yeniden yazılan v2 sürümü; kurumsal bulut mimarisindeki kullanıcı hesapları, güvenlik grupları, yönetici rolleri (Directory Roles), uygulama kayıtları (App Registrations), servis prensipleri (Service Principals), abonelikler (Subscriptions), kaynak grupları ve Azure Key Vault gibi kritik bileşenleri Microsoft Graph API ve Azure REST API üzerinden sorgular.

Aracın ana çalışma mantığı, bulut ortamında gözden kaçan yetki zincirlerini (örneğin bir Service Principal'ın sahip olduğu `RoleManagement.ReadWrite.Directory` izni veya sanal makineye atanan Managed Identity üzerinden abonelik düzeyinde `Contributor` yetkisine sıçrama) ve **hibrit kimlik (Hybrid Identity)** saldırı vektörlerini açığa çıkarmaktır. Azure AD Connect üzerinden senkronize edilen on-prem hesaplar ile Entra ID rolleri arasındaki köprüler bu sayede graf üzerinde tek bir zincir olarak modellenebilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                           AZUREHOUND TOPLAMA MİMARİSİ                              |
+-----------------------------------------------------------------------------------+
                                          |
                [1. Kimlik Doğrulama Katmanı]
                - Kullanıcı Adı / Parola (ROPC)
                - Cihaz Kodu Akışı (--device-code)
                - Servis Prensibi (--app-id & --secret / --certificate)
                - JWT / Refresh Token (--jwt / --refresh-token)
                                          |
                                          v
+------------------------+                        +---------------------------------+
|   Microsoft Graph API  |                        |  Azure Resource Manager (ARM)   |
| (graph.microsoft.com)  |                        |    (management.azure.com)       |
+------------------------+                        +---------------------------------+
            |                                                      |
            +---- AZUser, AZGroup, AZDirectoryRole                |
            +---- AZApp, AZServicePrincipal                        +---- AZSubscription
            +---- AZDevice, AZKeyVault Access Policies             +---- AZResourceGroup
            +---- AppRoleAssignments, OAuth2PermissionGrants       +---- AZRoleAssignment
                                          |
                                          v
                    +-------------------------------------------+
                    |           AzureHound v2 Çekirdeği         |
                    | (Go Concurrency, Batching & Normalization)|
                    +-------------------------------------------+
                                          |
                     +--------------------+---------------------+
                     |                                          |
                     v                                          v
        [Lokal JSON / ZIP Dosyası]               [BloodHound CE REST API]
        - azurehound_*.json                      - Doğrudan Ingest Pipeline
                     |                                          |
                     +--------------------+---------------------+
                                          v
                       +-------------------------------------+
                       |   BloodHound CE (Neo4j / Postgres)  |
                       |       Graf Saldırı Yolları          |
                       +-------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Hibrit / Bulut Tehdidi |
|---|---|---|
| **Graph API İzin Zincirleri** | Bir uygulamanın sahip olduğu MS Graph API izinlerini analiz eder (`AppRoleAssignments`). | `Application.ReadWrite.All` ile arka kapı Service Principal kimliği üretme. |
| **Rol Atamaları ve PIM** | Kalıcı rol atamalarını ve etkinleştirilebilir rolleri açığa çıkarır. | Global Administrator veya Privileged Role Administrator yetkisine tırmanma. |
| **Managed Identity Keşfi** | Azure VM ve App Service nesnelerine tanımlanmış Managed Identity ilişkilerini haritalar. | VM komuta kontrolü sonrası bulut kaynaklarına yatay/dikey geçiş. |
| **Hibrit Senkronizasyon Tespiti** | On-prem Active Directory ile Entra ID arasındaki `DirSyncEnabled` nesnelerini gösterir. | On-prem etki alanı ele geçirilince Azure AD Connect üzerinden bulut tenant'ını düşürme. |
| **Azure RBAC Analizi** | Yönetim Grubu, Abonelik ve Kaynak Grubu seviyesindeki rol atamalarını çeker. | `User Access Administrator` veya `Owner` rollerini suistimal etme. |

### 1.1 BloodHound Tarafından Modellenen Kritik Entra ID İlişkileri (Edge Types)

AzureHound tarafından toplanan veriler BloodHound graf veritabanına aktarıldığında aşağıdaki kritik yetki ilişkileri (edges) otomatik olarak haritalandırılır:

| Graf Kenarı (Edge) | Kaynak Nesne | Hedef Nesne | İstismar Vektörü (Abuse Vector) |
|---|---|---|---|
| **`AZResetPassword`** | Kullanıcı / SP | AZUser | Hedef kullanıcının parolasını sıfırlayarak hesabını doğrudan devralma. |
| **`AZAddMembers`** | Kullanıcı / SP | AZGroup | Yüksek yetkili güvenlik grubuna (örneğin Privileged Role Admin barındıran gruba) sızma. |
| **`AZOwns`** | Kullanıcı / SP | AZApp / AZServicePrincipal | Uygulama veya servis prensibine yeni gizli anahtar (`Add-Secret`) ekleyerek kimliğine bürünme. |
| **`AZGlobalAdmin`** | Kullanıcı / SP | AZTenant | Kiracı genelinde en yüksek yönetim yetkisi (tüm nesneleri yönetme ve şartlı erişimi kaldırma). |
| **`AZPrivilegedAuthAdmin`** | Kullanıcı / SP | AZUser | Hedef kullanıcının FIDO2 anahtarını, telefon numarasını veya MFA doğrulayıcısını silip sıfırlama. |
| **`AZAppAdmin`** | Kullanıcı / SP | AZApp / AZServicePrincipal | Parola dışındaki kimlik bilgilerini, redirect URI'larını ve izinleri manipüle etme. |
| **`AZContributor`** | Kullanıcı / SP / MI | AZSubscription / AZVM | Sanal makinelerde `Run Command` ile SYSTEM/root komut çalıştırma ve Managed Identity çalma. |
| **`SyncedToADUser`** | ADUser (On-Prem) | AZUser (Cloud) | On-prem Active Directory hesabı ele geçirildiğinde bulut hesabına geçiş köprüsü. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | AzureHound v2 | ROADtools / ROADrecon | Stormspotter | MicroBurst | AADInternals |
|---|---|---|---|---|---|
| **Geliştirici / Dil** | SpectreOps (Go) | Dirk-jan Mollema (Python) | Azure Team (Python) | NetSPI (PowerShell) | Nestori Syynimaa (PS) |
| **BloodHound Uyumluluğu** | Doğrudan (Resmi v2 JSON/API) | Dolaylı (Dönüştürücü gerekir) | Özel Arayüz (Neo4j) | Graf çıktısı yok | Graf çıktısı yok |
| **Graph API Kapsamı** | Çok Yüksek (Graph + ARM) | Çok Yüksek (Lokal DB) | Orta (Sadece Azure RBAC) | Düşük (Saldırı odaklı) | Yüksek (Özel federasyon) |
| **MFA & Device Code** | Tam Destekli | Tam Destekli | Kısmi Destekli | CLI tabanlı | Özel token desteği |
| **Canlı API Aktarımı** | Var (BloodHound CE API) | Yok | Yok | Yok | Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

AzureHound v2 bağımsız bir ikili (binary) olarak çalışır. Genel CLI sözdizimi şu şekildedir:

```bash
azurehound [global options] [command] [command options]
```

En sık kullanılan ana komut `list` (eski sürümlerde `dump`) komutudur.

### 2.1 Kimlik Doğrulama Parametreleri

| Parametre | Kısa Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| `--username` | `-u` | Kullanıcı adı (User Principal Name - UPN). | `user@contoso.onmicrosoft.com` |
| `--password` | `-p` | İlgili kullanıcının parolası (MFA kapalıysa). | `P@ssw0rd123!` |
| `--tenant` | `-t` | Hedef Azure Tenant ID veya etki alanı adı. | `11111111-2222-3333-4444-555555555555` |
| `--app-id` | `-a` | Kimlik doğrulama için kullanılacak App Registration Client ID. | `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` |
| `--secret` | `-s` | İlgili Service Principal / App Secret parolası. | `Abc123_~XyZ987...` |
| `--certificate` | `-c` | Kimlik doğrulama için kullanılacak PFX/PEM sertifika yolu. | `/opt/certs/app.pfx` |
| `--jwt` | `-j` | Daha önce elde edilmiş ham JWT Bearer Access Token. | `eyJ0eXAiOiJKV1QiLC...` |
| `--refresh-token` | `-r` | OAuth2 Refresh Token (otomatik token yenileme için). | `0.ARwA1...` |
| `--device-code` | `-d` | Web tarayıcısı üzerinden Device Code Flow başlatır (MFA uyumlu). | *(Bayrak olarak verilir)* |

### 2.2 Toplama ve Filtreleme Parametreleri

| Parametre | Açıklama | Varsayılan Değer |
|---|---|---|
| `list` | Tenant ve Azure aboneliklerindeki nesneleri toplar ve listeler. | Ana çalışma modu |
| `-o`, `--output` | Toplanan JSON verilerinin yazılacağı dosya veya klasör yolu. | Konsol / Standart Çıktı |
| `--json` | Çıktıyı insan okunabilir tablo yerine sıkıştırılmamış JSON formatında üretir. | `false` |
| `--batch-size` | Microsoft Graph API çağrılarında sayfalama (paging) boyutu. | `100` |
| `--threads` | Eşzamanlı çalışacak iş parçacığı (goroutine) sayısı. | `10` |
| `-v`, `--verbosity` | Günlük detay seviyesi (`0`=Hata, `1`=Bilgi, `2`=Hata Ayıklama). | `1` |
| `--proxy` | HTTP/HTTPS trafiğini yönlendirmek için kullanılacak proxy (Burp Suite vb.). | `http://127.0.0.1:8080` |

### 2.3 BloodHound CE Doğrudan Gönderim Parametreleri

| Parametre | Açıklama | Örnek |
|---|---|---|
| `--api-url` | BloodHound CE API sunucusunun tam URL adresi. | `http://192.168.1.50:8080` |
| `--api-token` | BloodHound CE arayüzünden üretilen API Key / Secret Token. | `bhtoken_ey...` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Device Code Akışı ile Etkileşimli Kimlik Doğrulama (MFA Uyumlu)
Kurumsal ortamlarda hemen her kullanıcıda MFA zorunludur. Device Code akışı, saldırganın parolasız şekilde kurbanın web oturumu üzerinden yetki almasını sağlar:

```bash
azurehound list --tenant "contoso.onmicrosoft.com" --device-code -o /opt/recon/azure_dump.json
```

**Konsol Çıktısı ve Operasyon Adımları:**

```text
[+] AzureHound v2.1.8 - BloodHound Azure Collector
[*] Authenticating using Device Code Flow...
[!] To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code: F4K3-C0D3
[*] Waiting for user authentication on Microsoft portal...
[+] Authentication successful! Received tokens for tenant: 9c2a61b8-6d2f-4a3b-9e8c-123456789abc
[*] Enumerating Azure Active Directory Objects (Tenants, Users, Groups, Roles)...
[*] [Graph API] Fetched 1,420 Users...
[*] [Graph API] Fetched 285 Groups...
[*] [Graph API] Fetched 42 Directory Roles...
[*] [Graph API] Fetched 118 Service Principals...
[*] [ARM API] Enumerating Azure Subscriptions and Role Assignments...
[*] [ARM API] Found 4 Subscriptions (Production, Staging, Dev, Shared-Services).
[*] Writing JSON output to /opt/recon/azure_dump.json...
[+] Collection complete! Processed 2,180 total entities in 34.2s.
```

### Senaryo 2: Service Principal Kimliği ile Otomatize Toplama
Ele geçirilen bir CI/CD pipeline yapılandırmasından veya GitHub reposundan bulunan App Registration kimlik bilgileriyle sessizce veri toplama:

```bash
azurehound list \
  --tenant "9c2a61b8-6d2f-4a3b-9e8c-123456789abc" \
  --app-id "55555555-4444-3333-2222-111111111111" \
  --secret "mY_sUp3r_S3cr3t_K3y_v@lu3~999" \
  --json -o /opt/recon/sp_azure_data.json
```

### Senaryo 3: Azure CLI Cache / Access Token Kullanarak Toplama
Eğer hedef bir sistemde veya sızma testi makinesinde `az login` ile önceden giriş yapılmışsa, Azure CLI'ın önbelleğindeki Access Token çekilerek AzureHound'a verilebilir:

```bash
# 1. Azure CLI üzerinden MS Graph API için geçerli token alma
GRAPH_TOKEN=$(az account get-access-token --resource-type ms-graph --query accessToken -o tsv)

# 2. Token ile AzureHound çalıştırma
azurehound list --jwt "$GRAPH_TOKEN" --tenant "contoso.onmicrosoft.com" -o /opt/recon/token_recon.json
```

### Senaryo 4: Verileri Doğrudan BloodHound CE Sunucusuna Canlı Aktarma
Toplanan verileri yerel diske kaydetmeden doğrudan canlı BloodHound Community Edition REST API arayüzüne basma:

```bash
azurehound list \
  --tenant "contoso.com" \
  --device-code \
  --api-url "http://10.10.10.150:8080" \
  --api-token "bhe_token_c00k13_xYz123=="
```

### Senaryo 5: Sertifika Tabanlı Kimlik Doğrulama (Certificate-Based Authentication)
Parola yerine PEM/PFX sertifikası kullanan yüksek yetkili Service Principal varlıkları için kimlik doğrulama:

```bash
azurehound list \
  --tenant "9c2a61b8-6d2f-4a3b-9e8c-123456789abc" \
  --app-id "33333333-2222-1111-0000-aaaaaaaaaaaa" \
  --certificate "/opt/certs/azure_service_principal.pem" \
  -o /opt/recon/cert_azurehound.json
```

### Senaryo 6: Docker Konteyneri Olarak AzureHound Çalıştırma
Sızma testi makinesinde Go bağımlılığı kurmadan doğrudan SpectreOps resmi Docker imajı üzerinden çalıştırma:

```bash
docker run --rm -it \
  -v /opt/recon:/data \
  specterops/azurehound:latest list \
  --tenant "contoso.onmicrosoft.com" \
  --device-code \
  -o /data/azure_docker_dump.json
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `AADSTS50076: Due to a configuration change... you must use multi-factor authentication` | Kullanıcı adı/parola (`-u`/`-p`) ile girilmeye çalışıldı ancak hesapta MFA aktif. | ROPC akışı MFA desteklemez. `--device-code` bayrağı ile tarayıcı üzerinden giriş yapın veya önceden alınmış `--jwt` / `--refresh-token` kullanın. |
| `AADSTS50126: Error validating credentials due to invalid username or password` | Parola yanlış veya tenant etki alanı adı geçersiz girildi. | UPN formatını (`user@domain.com`) ve tenant ID değerini doğrulayın. Özel karakter içeren parolaları çift tırnak içine alın. |
| `AADSTS700016: Application with identifier '...' was not found in the directory` | Verilen `--app-id` hedef tenant içinde kayıtlı değil veya yanlış yazıldı. | Client ID'nin doğruluğunu kontrol edin. Çoklu kiracılı (multi-tenant) uygulamalarda `--tenant` bayrağı ile doğru kiracı kimliğini belirtin. |
| `429 Too Many Requests (Rate Limiting / Throttling)` | Microsoft Graph API dakikalık istek limitine takıldı (özellikle çok büyük kiracılarda). | AzureHound komutuna `--threads 2` ve `--batch-size 50` parametreleri ekleyerek API istek sıklığını düşürün. |
| `Authorization_RequestDenied: Insufficient privileges to complete the operation` | Kullanılan Service Principal veya hesap dizin okuma (`Directory.Read.All`) yetkisine sahip değil. | Service Principal'a Azure Portal üzerinden `Directory.Read.All` izni verilip Admin Consent verilmesi gerekir. Normal kullanıcı hesabıyla giriş yapmayı deneyin. |
| `AADSTS53003: Access has been blocked by Conditional Access policies` | Tenant üzerinde IP whitelisting, konum kısıtlaması veya Intune/MAM zorunluluğu var. | IP adresinizi şirket içi izinli VPN aralığına çekin ya da `--proxy` parametresiyle kurum içi kurumsal proxy üzerinden bağlanın. |
| `AADSTS65001: The user or administrator has not consented to use the application` | Üçüncü taraf bir Client ID kullanılırken tenant yöneticisi onayı (Admin Consent) verilmemiş. | Tanınmış birinci parti Microsoft Client ID'lerini (Azure CLI: `04b07795-8ddb-461a-bbee-02f9e1bf7b46` veya PowerShell: `1950a258-227b-4e31-a9cf-717495945fc2`) kullanın. |
| `Failed to connect to BloodHound CE: 401 Unauthorized` | `--api-token` geçersiz veya süresi dolmuş. | BloodHound CE yönetim panelinden yeni bir API Key üretip secret string'i tam kopyalayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

AzureHound bulut API'leri üzerinden çalıştığı için yerel uç nokta EDR'ları tarafından değil, doğrudan Microsoft Entra ID ve Microsoft Sentinel tarafından izlenir.

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Microsoft Entra ID Sign-in Logs (Oturum Açma Günlükleri):**
   - **Interactive Sign-ins:** `--device-code` kullanıldığında loglarda `Application: Microsoft Azure PowerShell` veya `Azure CLI` kimliğiyle oturum açma görünür.
   - **Non-Interactive Sign-ins:** Service Principal veya Token kullanıldığında ilgili IP adresi ve kaynak API (`Microsoft Graph`) kaydedilir.
2. **Audit Logs (Dizin Denetim Günlükleri):**
   - Tek başına okuma (Read) işlemleri Audit Log oluşturmaz. Ancak ardışık ve kitlesel API çağrıları "Anomalous Token Usage" veya "Impossible Travel" risk tetikleyicilerini devreye sokabilir.
3. **Azure Activity Logs:**
   - Abonelik düzeyinde yapılan ARM API rol listeleme çağrıları denetim kayıtlarına yansır.

### 5.2 Ağ, API ve EDR İmzaları

- **User-Agent:** AzureHound'un varsayılan User-Agent başlığı `AzureHound/v2.x (SpectreOps)` veya standart Go HTTP istemcisidir (`Go-http-client/1.1`). Sentinel üzerinde bu başlık doğrudan alarmlara neden olur.
- **Trafik Deseni:** Kısa süre içerisinde `graph.microsoft.com/v1.0/users`, `/groups`, `/servicePrincipals`, `/directoryRoles` uç noktalarına yüzlerce `$batch` ve paging isteği yapılması.

### 5.3 MITRE ATT&CK Eşleştirmesi (Cloud Matrix)

| Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|
| **T1087.004** | Account Discovery: Cloud Account | Entra ID üzerindeki tüm kullanıcı hesaplarının, konukların (guests) ve rolların listelenmesi. |
| **T1069.003** | Permission Groups Discovery: Cloud Groups | Güvenlik grupları, dinamik gruplar ve rol atanabilir grupların tespiti. |
| **T1526** | Cloud Service Discovery | Tenant bünyesindeki Azure Resource Manager abonelikleri ve kaynaklarının keşfi. |
| **T1078.004** | Valid Accounts: Cloud Accounts | Device code veya Service Principal kimlik bilgileriyle meşru API oturumu başlatma. |
| **T1484.002** | Domain Trust Modification: Trust Modification | On-Prem ile Azure AD arasındaki federasyon ve senkronizasyon yetki ilişkilerini haritalama. |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **User-Agent Alarmı** | `AzureHound` veya `Go-http-client` içeren imzalı HTTP başlığı. | AzureHound kaynak kodundan User-Agent başlığını `Mozilla/5.0 (Windows NT 10.0; Win64; x64)...` veya `Azure-PowerShell` olarak değiştirip derleyin. |
| **Şüpheli Konum / IP** | AWS/DigitalOcean sunucusundan yapılan kurumsal Azure oturum açması. | IP adresinizi kurban firmanın coğrafi bölgesindeki konut IP'lerine (residential proxy) veya kurum içi bir atlama noktasına (jumpbox) bağlayın. |
| **MFA Reddi ve Bloklanma** | Parolalı giriş denemelerinde Conditional Access engeline takılma. | Parola ile brute-force/login denemeyin; kurbanın tarayıcısından `ESTSAUTH` cookie'si veya Refresh Token çalarak oturumu sürdürün. |
| **Aşırı İstek Hızı (Rate Burst)** | Saniyeler içinde binlerce API sorgusu ile Graph API kota aşımı. | `--threads 1` ve gecikme parametreleri kullanarak sorguları mesai saatlerine yayın. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

Microsoft Sentinel üzerinde AzureHound ve toplu Graph API keşif aktivitelerini tespit eden örnek KQL (Kusto Query Language) kuralı:

```kql
// AzureHound benzeri araçların şüpheli User-Agent ve API kullanım tespiti
SigninLogs
| where TimeGenerated > ago(24h)
| where AppDisplayName in ("Microsoft Graph", "Azure Active Directory PowerShell", "Azure CLI")
| where UserAgent has_any ("AzureHound", "Go-http-client", "python-requests")
| project TimeGenerated, Identity, UserDisplayName, IPAddress, Location, UserAgent, AppDisplayName, ResourceDisplayName
```

Sertleştirme önerileri:
1. **Conditional Access:** Yöneticiler ve hassas hesaplar için yalnızca uyumlu/yönetilen cihazlardan (Compliant / Hybrid Joined Device) ve şirket içi IP bloklarından erişime izin verin.
2. **Device Code Flow Kısıtlaması:** Gerekmedikçe Device Code kimlik doğrulamasını Conditional Access politikalarıyla devre dışı bırakın.
3. **Privileged Identity Management (PIM):** Kalıcı Global Admin rollerini kaldırın; rolleri "Just-In-Time" (JIT) onay mekanizmasına bağlayın.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Device Code ile Etkileşimli Toplama (En Güvenli & Standart)
azurehound list --tenant "target.onmicrosoft.com" --device-code -o azure_data.json
```
- **Ne Yapar?** Tarayıcı üzerinden cihaz kodu ile MFA doğrulaması yaptırarak kiracıdaki tüm Entra ID ve Azure nesnelerini çeker.
- **Ne Zaman Kullanılır?** Kurban kullanıcıda MFA aktifken veya red team operasyonunda ilk bulut ayak izi elde edildiğinde.
- **Parametreler:** `--tenant` hedef kiracı adı; `--device-code` web tabanlı giriş akışı; `-o` çıktı dosyası.

```bash
# 2. Service Principal (Client Secret) ile Sessiz Toplama
azurehound list --tenant "TENANT_ID" --app-id "CLIENT_ID" --secret "CLIENT_SECRET" -o sp_data.json
```
- **Ne Yapar?** Bir App Registration'a ait yetkilerle etkileşimsiz olarak tüm dizin verilerini çeker.
- **Ne Zaman Kullanılır?** CI/CD, web config veya kaynak kodlardan uygulama kimlik bilgisi sızdırıldığında.
- **Parametreler:** `--app-id` uygulamanın Application ID'si; `--secret` istemci parolası.

```bash
# 3. Önceden Alınmış JWT Access Token ile Keşif
azurehound list --jwt "eyJ0eXAi..." --tenant "TENANT_ID" -o jwt_data.json
```
- **Ne Yapar?** Parola veya kimlik doğrulamaya gerek kalmadan var olan geçerli Bearer token ile API sorguları yapar.
- **Ne Zaman Kullanılır?** Bellekten veya komuta kontrol (C2) oturumundan Azure CLI / PowerShell token'ı çalındığında.
- **Parametreler:** `--jwt` ham erişim belirteci.

```bash
# 4. Refresh Token ile Oturum Tazeleme ve Toplama
azurehound list --refresh-token "0.ARwA1..." --tenant "target.com" -o refresh_data.json
```
- **Ne Yapar?** Süresi dolmuş token yerine Refresh Token kullanarak yeni Access Token üretir ve veri toplar.
- **Ne Zaman Kullanılır?** Kurbanın tarayıcı önbelleğinden veya yerel diskinden Refresh Token ele geçirildiğinde.
- **Parametreler:** `--refresh-token` OAuth2 yenileme belirteci.

```bash
# 5. Doğrudan BloodHound CE API Sunucusuna Aktarım
azurehound list --tenant "target.com" --device-code --api-url "http://10.10.10.50:8080" --api-token "bhe_tok_xxx"
```
- **Ne Yapar?** Verileri ara bir JSON dosyasına yazmadan doğrudan BloodHound Community Edition veritabanına aktarır.
- **Ne Zaman Kullanılır?** Disk izi bırakmak istenmediğinde ve analiz sunucusuna doğrudan ağ erişimi olduğunda.
- **Parametreler:** `--api-url` sunucu REST adresi; `--api-token` kimlik doğrulama anahtarı.

```bash
# 6. Sıkıştırılmamış Ham JSON Formatında Çıktı Alma
azurehound list --tenant "target.com" --device-code --json -o raw_graph.json
```
- **Ne Yapar?** Graf verilerini insan ve script tarafından okunabilir formatta, formatlanmış JSON olarak kaydeder.
- **Ne Zaman Kullanılır?** Özel Python betikleri veya `jq` filtreleriyle belirli nesneleri elle analiz etmek istendiğinde.
- **Parametreler:** `--json` satır satır JSON çıktısı üretir.

```bash
# 7. Burp Suite Proxy Üzerinden İnceleyerek Çalıştırma
azurehound list --tenant "target.com" --device-code --proxy "http://127.0.0.1:8080"
```
- **Ne Yapar?** Tüm Microsoft Graph API ve ARM REST çağrılarını yerel web proxy'sine yönlendirir.
- **Ne Zaman Kullanılır?** Giden HTTP isteklerini incelemek, header'ları değiştirmek veya güvenlik duvarlarını atlatmak için.
- **Parametreler:** `--proxy` HTTP proxy soket adresi.

```bash
# 8. Hız Limitli ve Düşük İş Parçacıklı OPSEC Taraması
azurehound list --tenant "target.com" --device-code --threads 2 --batch-size 25 -o stealth_azure.json
```
- **Ne Yapar?** API çağrı frekansını düşürerek Microsoft Graph API kotalarına (throttling) takılmadan sessizce veri toplar.
- **Ne Zaman Kullanılır?** Gelişmiş SOC ve Cloud SIEM ekiplerinin aktif izleme yaptığı kurumsal ortamlarda.
- **Parametreler:** `--threads 2` eşzamanlı istek sayısını sınırlar; `--batch-size 25` sayfa boyutunu küçültür.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [SpectreOps / AzureHound](https://github.com/SpectreOps/azurehound)
- **BloodHound Resmi Dokümantasyonu:** [BloodHound Cloud / CE AzureHound Guide](https://support.bloodhoundenterprise.io/hc/en-us/articles/11456108998811-AzureHound-Quick-Start)
- **Microsoft Graph API Dokümantasyonu:** [Microsoft Graph REST API Reference](https://learn.microsoft.com/en-us/graph/api/overview)
- **MITRE ATT&CK Cloud Matrix:** [Cloud Matrix - Reconnaissance & Discovery](https://attack.mitre.org/matrices/enterprise/cloud/)

---

> **Önceki:** [← BloodHound.py](./BloodHound.md) · **Sonraki:** [PowerView.ps1 →](./PowerView.md)
