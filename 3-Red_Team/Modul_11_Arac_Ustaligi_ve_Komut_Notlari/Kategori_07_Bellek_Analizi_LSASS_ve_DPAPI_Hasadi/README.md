# 7. BELLEK ANALİZİ, LSASS DÖKÜMÜ VE KASA HASADI (CREDENTIAL HARVESTING & DPAPI)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 18 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Mimikatz** | [Mimikatz.md](./Mimikatz.md) | LSASS bellek alanından açık metin parolaları, NTLM hash'lerini, Kerberos biletlerini çıkaran; DCSync, DCShadow ve Pass-the-Hash gerçekleştiren lider kimlik avı aracıdır. |
| 2 | **pypykatz** | [pypykatz.md](./pypykatz.md) | Mimikatz'ın saf Python ile sıfırdan yazılmış açık kaynaklı sürümüdür; çevrimdışı LSASS minidump dosyalarını Linux üzerinde ayrıştırarak parola ve biletleri çıkarır. |
| 3 | **nanodump** | [nanodump.md](./nanodump.md) | EDR ve Sysmon kancalarını atlatmak için kısıtlı erişim maskeleri (0x1010) ve PSS snapshot API'si kullanarak LSASS sürecini diske döken son derece gizli bir araçtır. |
| 4 | **Dumpert** | [Dumpert.md](./Dumpert.md) | Doğrudan sistem çağrıları (Direct System Calls) ve API kancalama atlatma teknikleri ile LSASS bellek dökümü alan C++ tabanlı bir araçtır. |
| 5 | **comsvcs.dll** | [comsvcs.dll.md](./comsvcs.dll.md) | Windows yerleşik MiniDump işlevini rundll32.exe ile çağırarak harici bir araç yüklemeden LSASS sürecini diske döken yerleşik LOLBin yöntemidir. |
| 6 | **lsassy** | [lsassy.md](./lsassy.md) | Uzak Windows sistemleri üzerinde etkileşimli kabuk açmadan veya diske dosya bırakmadan RPC/WMI ve DLL teknikleriyle LSASS dökümünü uzaktan alan Python aracıdır. |
| 7 | **SafetyKatz** | [SafetyKatz.md](./SafetyKatz.md) | GhostPack ailesinin bir parçasıdır; Minidump API'si ile LSASS'ı belleğe alıp Mimikatz'ı bellek içinde çalıştırdıktan sonra dökümü anında silen güvenli bir toplayıcıdır. |
| 8 | **SharpKatz** | [SharpKatz.md](./SharpKatz.md) | C# ile geliştirilmiş; Mimikatz'ın sekurlsa mantığını doğrudan .NET üzerinden çalıştırarak LSASS'tan kimlik bilgisi toplayan bir araçtır. |
| 9 | **SharpDPAPI** | [SharpDPAPI.md](./SharpDPAPI.md) | Windows Data Protection API (DPAPI) mimarisini istismar ederek saklanan tarayıcı şifrelerini, Vault kasalarını ve RDP bağlantı parolalarını çözen C# aracıdır. |
| 10 | **DonPAPI** | [DonPAPI.md](./DonPAPI.md) | Uzak makinelerdeki DPAPI ile şifrelenmiş kimlik bilgilerini, Chrome/Edge şifrelerini ve WiFi anahtarlarını etki alanı genelinde otomatik toplayan Python aracıdır. |
| 11 | **dpapi.py** | [dpapi.md](./dpapi.md) | Impacket çatısı altında bulunan; DPAPI ana anahtarlarını (Master Keys) ve etki alanı yedekleme özel anahtarlarıyla korunan verileri ayrıştıran araçtır. |
| 12 | **SharpChrome** | [SharpChrome.md](./SharpChrome.md) | Google Chrome, Microsoft Edge ve Brave tarayıcılarında kayıtlı kullanıcı parolalarını, çerezlerini ve form geçmişini bellekten veya diskten çıkaran C# aracıdır. |
| 13 | **Seatbelt** | [Seatbelt.md](./Seatbelt.md) | Güvenlik denetimleri ve sızma testleri için hedef sistemdeki yerel güvenlik yapılandırmalarını, şüpheli süreçleri ve kimlik kalıntılarını toplayan C# situasyonel farkındalık aracıdır. |
| 14 | **Internal-Monologue** | [Internal-Monologue.md](./Internal-Monologue.md) | LSASS sürecine dokunmadan ve bellek dökümü almadan, mevcut kullanıcının NetNTLM hash'ini yerel Netlogon API'si üzerinden hafızadan çıkaran son derece gizli bir araçtır. |
| 15 | **LaZagne** | [lazagne.md](./lazagne.md) | Windows ve Linux sistemlerde web tarayıcıları, e-posta istemcileri, veritabanları ve WiFi profillerinde saklanan açık metin parolaları toplayan açık kaynaklı araçtır. |
| 16 | **PPLKiller** | [PPLKiller.md](./PPLKiller.md) | Zafiyetli ve meşru bir çekirdek sürücüsünü (BYOVD) sisteme yükleyerek LSASS üzerindeki RunAsPPL korumasını çekirdek seviyesinde devre dışı bırakan araçtır. |
| 17 | **PPLMedic & PPLDump** | [PPLMedic_PPLDump.md](./PPLMedic_PPLDump.md) | Windows'un Protected Process Light (PPL) korumasını kullanıcı alanındaki mantıksal nesne hiyerarşisi hatalarını istismar ederek aşan ve korunan LSASS bellek dökümünü alan araçlardır. |
| 18 | **DragonCastle** | [DragonCastle.md](./DragonCastle.md) | AutodialDLL ve BITS servisi manipülasyonu ile LSASS'a sahte SSP yükleyerek NTLM karmalarını ve AES oturum anahtarlarını uzaktan kazıyan araçtır. |


---

> **Önceki Kategori:** [← Kategori 6](../Kategori_06_Kerberos_Protokol_Cephaneligi/README.md) · **Sonraki Kategori:** [Kategori 8 →](../Kategori_08_Active_Directory_Sertifika_Servisleri/README.md)
