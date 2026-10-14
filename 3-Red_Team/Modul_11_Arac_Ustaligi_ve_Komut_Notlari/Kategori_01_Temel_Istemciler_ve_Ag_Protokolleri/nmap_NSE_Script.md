# nmap (NSE Script)

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** smb2-security-mode (signing kontrolü), smb-enum-shares, krb5-enum-users, ldap-rootdse ve AD keşif scriptleri.

---

## 1. Genel Bakış ve Amaç

`nmap` (Network Mapper), yalnızca bir port ve servis tarayıcısı değil; bünyesinde barındırdığı **NSE (Nmap Scripting Engine)** altyapısıyla Active Directory sızma testlerinde ilk temas (initial reconnaissance) ve saldırı yüzeyi haritalamanın en kritik aracıdır. Lua programlama diliyle yazılmış NSE scriptleri, hedef etki alanı ortamında doğrudan Active Directory protokolleriyle (SMB, Kerberos, LDAP, MS-RPC) el sıkışarak konfigürasyon zafiyetlerini, kimlik doğrulama politikalarını ve servis ayrıntılarını saniyeler içinde raporlar.

Active Directory operasyonlarında Nmap NSE scriptlerinin sunduğu en kritik yetenek, **saldırı fizibilitesini doğrulamaktır**:
1. **NTLM Relay Fizibilitesi:** `smb2-security-mode.nse` ile ağdaki tüm sunucularda SMB İmzalama (SMB Signing) zorunluluğunun bulunup bulunmadığı tek komutla tespit edilir.
2. **Kilitlenme Riski Olmadan Kullanıcı Avı:** `krb5-enum-users.nse` ile Kerberos portu (TCP/UDP 88) üzerinden hesap kilitlenme sayacını (`badPwdCount`) artırmadan geçerli kullanıcı adları doğrulanır.
3. **Etki Alanı Haritası Çıkarma:** `smb-os-discovery.nse` ve `ldap-rootdse.nse` ile hedef makinelerin tam FQDN adları, NetBIOS isimleri, orman yapıları ve işletim sistemi build numaraları sızdırılır.

### Mimari ve Protokol Akışı

```
┌────────────────────────────────────────────────────────┐
│                   Nmap NSE Motoru                      │
│                                                        │
│   [ smb2-security-mode ]  [ krb5-enum-users ]          │
│   [ smb-os-discovery   ]  [ ldap-rootdse    ]          │
└─────────────────────────┬──────────────────────────────┘
                          │
         ┌────────────────┼────────────────┬────────────────┐
         │ TCP 445 (SMB)  │ TCP/UDP 88     │ TCP 389 (LDAP) │ TCP 135 (RPC)
         ▼                ▼ (Kerberos)     ▼                ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  SMB Negotiate   │ │ AS-REQ /     │ │ RootDSE      │ │ EPMAPPER     │
│  & Security Mode │ │ KDC Error    │ │ Search       │ │ Lookup       │
└──────────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
         │                │                │                │
         ▼                ▼                ▼                ▼
   Signing REQUIRED   KDC_ERR_PREAUTH   DefaultNaming    Kayıtlı RPC
   veya NOT REQUIRED  (Kullanıcı Var)   Context          Kuleleri
   (Relay Adayı)      0x19 Kodu         (BaseDN)         (Servis Portları)
```

### Karşılaştırma: Nmap NSE vs Alternatif Keşif Motorları

| Özellik | Nmap NSE | NetExec (nxc) | CrackMapExec | enum4linux-ng |
|---|---|---|---|---|
| **Birincil Rol** | Port taraması + Script motoru | Hızlı AD sömürü ve sprey | Klasik AD sömürü aracı | Çoklu protokol dökümü |
| **SMB Signing Tespiti**| ✅ `smb2-security-mode` | ✅ Dahili (Her çıktıda) | ✅ Dahili | ✅ Dahili |
| **Kerberos User Enum** | ✅ `krb5-enum-users` | ✅ Kerbrute modülü | ❌ Yok | ❌ Yok |
| **Gürültü Seviyesi** | Düşük-Orta (Hedefli) | Orta | Orta | Yüksek |
| **Yetkilendirme İhtiyacı**| Çoğu script için parolasız | Kimlik bilgisi gerektirir | Kimlik bilgisi gerektirir | Parolasız / Parolalı |
| **Çıktı Formatları** | Text, XML (`-oX`), Grepable | Tablo, SQLite veritabanı | Tablo | JSON, YAML, Text |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Sözdizimi

```bash
nmap [tarama_seçenekleri] -p <portlar> --script <script_adı_veya_kategorisi> [--script-args <argümanlar>] <hedef>
```

### Kritik Parametreler

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `--script` | Çalıştırılacak NSE scripti, script listesi veya kategorisi | `--script smb2-security-mode` |
| `--script-args` | Scriptlere aktarılacak özel argümanlar (`anahtar=değer`) | `--script-args krb5-enum-users.realm='CORP.LOCAL'` |
| `--script-trace` | Scriptin gönderip aldığı tüm ağ paketlerini canlı gösterir (Debug) | `--script-trace` |
| `--script-help` | Belirtilen scriptin yardım ve dokümantasyonunu basar | `--script-help smb2-security-mode` |
| `-Pn` | Ping (ICMP) kontrolünü atlar, hedefin açık olduğunu varsayar | `-Pn` |
| `-n` | DNS ad çözümlemesini kapatır (Taramayı hızlandırır ve OPSEC korur) | `-n` |
| `-p` | Taranacak port veya port aralığı | `-p 445`, `-p 88,135,389,445` |
| `-sC` | Nmap varsayılan (default) güvenli script grubunu çalıştırır | `-sC` |
| `-oA` | Sonuçları tüm formatlarda (nmap, gnmap, xml) kaydeder | `-oA /opt/loot/nmap_ad` |
| `-oX` | Sonuçları XML formatında kaydeder (Ayrıştırma için ideal) | `-oX /opt/loot/scan.xml` |

### Active Directory İçin Kritik NSE Scriptleri Kataloğu

| Script Adı | Hedef Port | Çalışma Prensibi ve Operasyonel Amacı |
|---|---|---|
| **`smb2-security-mode.nse`** | TCP 445 | SMBv2/v3 imzalama durumunu (`Message signing enabled but not required`) denetler. **NTLM Relay** fizibilitesini kanıtlar. |
| **`smb-security-mode.nse`** | TCP 445 / 139 | SMBv1 imzalama durumunu ve kullanıcı/paylaşım seviyesi güvenlik modunu denetler. |
| **`smb-os-discovery.nse`** | TCP 445 / 139 | Hedefin tam FQDN adını, NetBIOS adını, etki alanı/orman adını ve Windows sürümünü çeker. |
| **`smb-protocols.nse`** | TCP 445 / 139 | Hedefin desteklediği tüm SMB dialect sürümlerini (SMBv1, 2.0.2, 2.1, 3.0, 3.1.1) listeler. |
| **`smb2-capabilities.nse`** | TCP 445 | SMBv3 yeteneklerini (AES-128-GCM şifreleme, RDMA, multichannel) listeler. |
| **`smb-enum-shares.nse`** | TCP 445 / 139 | Paylaşımları listeler ve anonim/kullanıcı erişim izinlerini test eder. |
| **`smb-enum-users.nse`** | TCP 445 / 139 | SAMR/LSA arayüzleri üzerinden yerel ve etki alanı kullanıcılarını listeler. |
| **`smb-enum-sessions.nse`** | TCP 445 / 139 | Hedef sunucuda aktif SMB oturumu açmış kullanıcıları ve kaynak IP'leri döker. |
| **`krb5-enum-users.nse`** | TCP/UDP 88 | Parola denemesi yapmadan Kerberos hata yanıtlarıyla geçerli kullanıcıları doğrular. |
| **`ldap-rootdse.nse`** | TCP 389 | RootDSE sorgusu ile `defaultNamingContext` (BaseDN) ve desteklenen SASL mekanizmalarını döker. |
| **`msrpc-enum.nse`** | TCP 135 | TCP 135 Endpoint Mapper üzerinden kayıtlı tüm RPC servislerini ve UUID'lerini listeler. |
| **`smb-vuln-ms17-010.nse`** | TCP 445 | Sistemde EternalBlue (MS17-010) zafiyetinin bulunup bulunmadığını test eder. |

---

## 3. Pratik Komut Örnekleri

### 3.1 NTLM Relay Ön Kontrolü: SMB Signing Durumu Tespiti
Bir alt ağ genelinde NTLM Relay saldırısına açık olan sunucuları saniyeler içinde belirleme:

```bash
nmap -p 445 --script smb2-security-mode -Pn -n 192.168.1.0/24
```

**Gerçekçi Çıktı Analizi:**
```text
Nmap scan report for 192.168.1.10 (DC01)
PORT    STATE SERVICE
445/tcp open  microsoft-ds
| smb2-security-mode: 
|   3.1.1: 
|_    Message signing enabled and required    <-- ZAFİYET YOK (DC Varsayılanı)

Nmap scan report for 192.168.1.25 (FILESRV01)
PORT    STATE SERVICE
445/tcp open  microsoft-ds
| smb2-security-mode: 
|   3.1.1: 
|_    Message signing enabled but not required <-- ZAFİYET MEVCUT! (NTLM Relay Hedefi)
```
- **Operasyonel Çıkarım:** `192.168.1.25` üzerinde SMB signing zorunlu değildir (`not required`). Bu makineye yönlendirilen NTLM kimlik doğrulama istekleri (PetitPotam veya Responder ile) başarıyla relay edilerek yerel yönetici erişimi elde edilebilir.

### 3.2 Hedefin Kesin FQDN, Domain ve İşletim Sistemi Sürümünü Tespit Etme
Hedef hakkında Active Directory hiyerarşisi bilgilerini toplama:

```bash
nmap -p 445 --script smb-os-discovery -Pn -n 192.168.1.10
```

**Örnek Çıktı:**
```text
| smb-os-discovery: 
|   OS: Windows Server 2022 Standard 20348 (Windows Server 2022 10.0)
|   OS CPE: cpe:/o:microsoft:windows_server_2022
|   Computer name: DC01
|   NetBIOS computer name: DC01\x00
|   Domain name: corp.local
|   Forest name: corp.local
|   FQDN: DC01.corp.local
|_  System time: 2026-10-14T14:15:30+03:00
```
- **Kritik Bilgiler:** Kerberos biletleri ve SPN oluşturmak için gereken kesin FQDN (`DC01.corp.local`), etki alanı adı ve hedef sunucu saat farkı (`System time`) elde edildi.

### 3.3 Kerberos ile Kilitlenme Riski Olmadan Kullanıcı Doğrulama
Hedef Etki Alanı Denetleyicisinde parola denemesi yapmadan kullanıcı listesi doğrulama:

```bash
nmap -p 88 --script krb5-enum-users --script-args krb5-enum-users.realm='CORP.LOCAL',userdb=/opt/wordlists/users.txt -Pn -n 192.168.1.10
```
- **Çalışma Prensibi:** Script, KDC'ye boş veya rastgele ön doğrulama verisiyle `AS-REQ` isteği gönderir:
  - Eğer KDC `KDC_ERR_PREAUTH_REQUIRED` (0x19) koduyla dönerse ➔ **Kullanıcı mevcuttur.**
  - Eğer KDC `KDC_ERR_C_PRINCIPAL_UNKNOWN` (0x06) koduyla dönerse ➔ **Kullanıcı yoktur.**
  - **OPSEC Avantajı:** Parola denenmediği için Windows Security Log'da Event ID 4625 (Logon Failure) üretilmez ve `badPwdCount` artmaz!

### 3.4 Anonim / Yetkili SMB Paylaşım Taraması
Paylaşımları ve erişim izinlerini hızlıca dökme:

```bash
# Anonim tarama:
nmap -p 445 --script smb-enum-shares -Pn -n 192.168.1.10

# Kimlik bilgisi ile yetkili tarama:
nmap -p 445 --script smb-enum-shares --script-args smbusername=j.doe,smbpassword='P@ss123!',smbdomain=CORP -Pn -n 192.168.1.10
```

### 3.5 LDAP RootDSE ile Dizin Mimarisi Keşfi
Etki alanının temel LDAP parametrelerini çekme:

```bash
nmap -p 389 --script ldap-rootdse -Pn -n 192.168.1.10
```
- **Dönen Bilgiler:** `defaultNamingContext: DC=corp,DC=local`, `supportedSASLMechanisms: GSSAPI, GSS-SPNEGO`, `dnsHostName: DC01.corp.local`.

### 3.6 RPC Endpoint Mapper Arayüzlerini Numaralandırma
Hedef sunucunun TCP 135 portundaki kayıtlı RPC arayüzlerini ve dinledikleri portları listeleme:

```bash
nmap -p 135 --script msrpc-enum -Pn -n 192.168.1.10
```

### 3.7 Alt Ağda NTLM Relay Hedef Listesi Çıkarma (Grep Pipeline)
Geniş bir IP aralığından NTLM Relay hedeflerini tek satırlık bash boru hattıyla temiz bir dosyaya dökme:

```bash
nmap -p 445 --script smb2-security-mode -Pn -n 192.168.1.0/24 -oG /tmp/smb_signing.gnmap
grep -B 1 "Message signing enabled but not required" /tmp/smb_signing.gnmap | grep "Host:" | awk '{print $2}' > /opt/loot/relay_targets.txt
```

### 3.8 MS17-010 (EternalBlue) Zafiyet Kontrolü
Ağda eski veya yamalanmamış sistemlerin uzaktan kod yürütme açığını test etme:

```bash
nmap -p 445 --script smb-vuln-ms17-010 -Pn -n 192.168.1.0/24
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata / Sorun | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `Script failed to run: Host seems down` | Hedef sunucu ICMP ping paketlerini engelliyor. | Taramaya `-Pn` bayrağını ekleyerek host discovery adımını zorunlu atlayın. |
| `SMB: Failed to negotiate protocol` | İstemci ile sunucu arasında desteklenen ortak SMB dialect bulunamadı. | Nmap SMB kütüphanesini güncelleyin veya `--script-args smb2=true` ekleyin. |
| `krb5-enum-users: Realm not specified` | Kerberos arayüzü etki alanı adını (Realm) otomatik çözemedi. | `--script-args krb5-enum-users.realm='CORP.LOCAL'` parametresi ile Realm adını BÜYÜK HARFLERLE açıkça belirtin. |
| `ACCESS_DENIED on smb-enum-shares` | Hedef sunucu anonim paylaşım listelemeyi kapatmış (`RestrictAnonymous`). | `--script-args smbusername=user,smbpassword=pass` ile geçerli kimlik bilgisi sağlayın. |
| `NSE: Script Engine Scan Aborted` | Firewall veya IPS bağlantıyı sıfırladı (RST) ya da eşzamanlı script sayısı fazla geldi. | Zamanlama şablonunu yavaşlatın (`-T3` veya `-T2`) ve `--max-parallelism 10` uygulayın. |
| `False Positive: Signing required görünüyor` | Hedef makine SMBv1 için signing istiyor ancak SMBv2/v3 için istemiyor olabilir. | `smb-security-mode` yerine mutlaka `smb2-security-mode` scriptini baz alın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Log Kaynağı | Event ID / Log | Detay ve İz Açıklaması |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | SMB scriptleri bağlandığında üretilen ağ oturumu kaydı. |
| **Windows Security Log** | **4625** | Başarısız kimlik doğrulamalı SMB denemelerinde loglanır. |
| **Windows Security Log** | **4768** | **Kerberos TGT İsteği:** `krb5-enum-users` çalıştığında DC'de her kullanıcı için bir 4768 olayı üretilir: Kullanıcı varsa `Failure Code: 0x19`, yoksa `Failure Code: 0x6` oluşur. |
| **Sysmon** | **Event ID 3** | İstemci IP'sinden TCP 445, 88, 389, 135 portlarına ardışık ağ bağlantıları. |
| **Ağ Cihazları / IDS** | **Nmap İmzaları** | Nmap'in varsayılan TCP window size, paket dizilimi ve NSE User-Agent dizgileri Snort/Suricata tarafından yakalanır. |

### 5.2 Ağ ve EDR İmzaları
- **Toplu Port Taraması Uyarısı:** Ağdaki tüm IP'lere 445 ve 135 portları üzerinden yapılan paralel taramalar SIEM'de **"Internal Port Scan / Reconnaissance"** alarmlarını tetikler.
- **Kerberos TGT Failure Fırtınası:** Yüzlerce kullanıcı adı içeren bir liste ile `krb5-enum-users` koşturulduğunda, DC üzerinde saniyeler içinde yüzlerce Event 4768 (Result Code: `0x6`) logu patlar. Bu durum MDI (Defender for Identity) tarafından **"Kerberos Reconnaissance"** olarak işaretlenir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Nmap NSE Kullanımı |
|---|---|---|
| **T1046** | Network Service Discovery | Aktif AD servislerini ve portlarını tespit etme |
| **T1018** | Remote System Discovery | SMB OS Discovery ve LDAP RootDSE ile sistem rollerini çıkarma |
| **T1087.002** | Account Discovery: Domain Account | `krb5-enum-users` ve `smb-enum-users` ile kullanıcı tespiti |
| **T1135** | Network Share Discovery | `smb-enum-shares` ile paylaşım ve izin haritalama |
| **T1210** | Exploitation of Remote Services | MS17-010 EternalBlue zafiyet yüzeyini doğrulama |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **Geniş port taraması IDS tetikler** | Tüm portları taramak yerine yalnızca hedeflenen spesifik portları (`-p 445` veya `-p 88`) sorgulayın. |
| **DNS Sorgu Sızıntısı** | Ters DNS sorgularının hedef DC'de iz bırakmasını önlemek için daima `-n` (no DNS resolution) kullanın. |
| **Kerberos 4768 Log Fırtınası** | Binlerce rastgele kullanıcıyı Kerberos ile test etmeyin; küçük ve hedeflenmiş kullanıcı listeleri kullanın. |
| **Tarama Hızı Tespiti** | Agresif (`-T4/-T5`) taramalar yerine normal veya sessiz (`-T2/-T3`) zamanlama şablonlarını tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- Ağ taramalarını ve log analizi senaryolarını izleme → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- SMB Signing Zorunluluğu Getirme (Relay Engelleme) → GPO: `Microsoft network server: Digitally sign communications (always) = Enabled` ([Blue M08 — Protokol Sertleştirme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/))
- Event 4768 Korelasyonu → Result Code `0x6` patlamalarını SIEM üzerinde kurala bağlama.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve operasyonel keşiflerde en sık başvurulan Nmap Active Directory NSE komut kombinasyonlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Alt Ağda NTLM Relay Hedeflerini (Signing Disabled) Tek Satırda Bulma
```bash
nmap -p 445 --script smb2-security-mode -Pn -n 192.168.1.0/24 | grep -B 2 "Message signing enabled but not required"
```
- **Ne Yapar?** Tüm alt ağdaki sunucuların SMBv2/v3 imzalama durumunu kontrol eder ve NTLM Relay saldırısına açık olanları filtreler.
- **Ne Zaman Kullanılır?** Responder veya Coercer saldırılarından önce NTLM hash'lerinin hangi makinelere yönlendirilebileceğini belirlemek için.
- **Parametreler:** `-p 445` (Yalnızca SMB portu), `--script smb2-security-mode`, `-Pn -n` (Ping ve DNS çözümlemesini atla).

### 6.2 SMB OS Discovery ile DC, FQDN ve Saat Bilgisini Çekme
```bash
nmap -p 445 --script smb-os-discovery -Pn -n 192.168.1.10
```
- **Ne Yapar?** Hedef sunucunun tam FQDN adını, NetBIOS adını, etki alanı/orman adını, Windows build sürümünü ve sistem saatini döker.
- **Ne Zaman Kullanılır?** Kerberos biletleri üretmeden önce hedef makinenin FQDN ve saat farkı (clock skew) bilgilerini teyit etmek için.

### 6.3 Kerberos ile Kilitlenme Üretmeden Kullanıcı Doğrulama
```bash
nmap -p 88 --script krb5-enum-users --script-args krb5-enum-users.realm='CORP.LOCAL',userdb=/tmp/users.txt -Pn -n 192.168.1.10
```
- **Ne Yapar?** Parola denemesi yapmadan, Kerberos KDC hata kodları üzerinden etki alanındaki geçerli kullanıcı hesaplarını tespit eder.
- **Ne Zaman Kullanılır?** Parola püskürtme öncesinde hesap kilitlenme sayacını artırmadan kullanıcı listesi doğrulamak için.
- **Parametreler:** `--script krb5-enum-users`, `krb5-enum-users.realm` (Büyük harfle Domain FQDN), `userdb` (Kullanıcı listesi).

### 6.4 SMB Paylaşımlarını ve İzinlerini Listeleme
```bash
nmap -p 445 --script smb-enum-shares -Pn -n 192.168.1.10
```
- **Ne Yapar?** Hedef makinedeki açık paylaşımları, paylaşım açıklamalarını ve anonim erişim izinlerini döker.
- **Ne Zaman Kullanılır?** Ağdaki dosya sunucularını ve erişilebilir paylaşımları hızlıca keşfetmek için.

### 6.5 LDAP RootDSE ile Etki Alanı Naming Contexts Bilgisini Çekme
```bash
nmap -p 389 --script ldap-rootdse -Pn -n 192.168.1.10
```
- **Ne Yapar?** Kimlik doğrulaması olmadan DC'nin LDAP kök dizinini, BaseDN bilgisini (`defaultNamingContext`) ve desteklenen SASL mekanizmalarını listeler.
- **Ne Zaman Kullanılır?** Dizin hakkında temel etki alanı DN bilgisini almak için.

### 6.6 RPC Endpoint Mapper Arayüzlerini Numaralandırma
```bash
nmap -p 135 --script msrpc-enum -Pn -n 192.168.1.10
```
- **Ne Yapar?** TCP 135 portundaki Endpoint Mapper'a bağlanarak hedef sunucuda çalışan kayıtlı RPC servislerini ve UUID değerlerini döker.
- **Ne Zaman Kullanılır?** Spooler, EFS veya Task Scheduler gibi kritik RPC arayüzlerinin varlığını teyit etmek için.

### 6.7 Desteklenen SMB Versiyonlarını ve Şifreleme Yeteneklerini Listeleme
```bash
nmap -p 445 --script smb-protocols,smb2-capabilities -Pn -n 192.168.1.10
```
- **Ne Yapar?** Hedef sunucunun hangi SMB sürümlerini (SMBv1-v3) ve şifreleme algoritmalarını (AES-128-GCM vb.) desteklediğini raporlar.
- **Ne Zaman Kullanılır?** Eski SMBv1 protokolünün açık olup olmadığını veya modern şifreleme zorunluluklarını anlamak için.

### 6.8 MS17-010 EternalBlue Zafiyet Kontrolü
```bash
nmap -p 445 --script smb-vuln-ms17-010 -Pn -n 192.168.1.10
```
- **Ne Yapar?** Hedef sistemin MS17-010 SMB uzaktan kod yürütme zafiyetine karşı yamalı olup olmadığını doğrular.
- **Ne Zaman Kullanılır?** Eski Windows sürümleri içeren ağlarda doğrudan SYSTEM yetkisinde RCE imkanını test etmek için.

### 6.9 Kimlik Bilgisi ile Yetkili Paylaşım ve Kullanıcı Numaralandırma
```bash
nmap -p 445 --script smb-enum-shares,smb-enum-users --script-args smbusername=j.doe,smbpassword='P@ss123!',smbdomain=CORP -Pn -n 192.168.1.10
```
- **Ne Yapar?** Sağlanan etki alanı kimlik bilgisiyle oturum açarak hem paylaşımları hem de yerel/etki alanı kullanıcılarını listeler.
- **Ne Zaman Kullanılır?** Standart bir hesap ele geçirildiğinde yetkili görünümle paylaşım ve kullanıcı envanteri çıkarmak için.

### 6.10 Tek Satırda Tüm Temel AD Keşif Scriptlerini Birlikte Koşturma
```bash
nmap -p 88,135,389,445 --script smb2-security-mode,smb-os-discovery,ldap-rootdse,msrpc-enum -Pn -n 192.168.1.10 -oA /tmp/ad_recon_dc01
```
- **Ne Yapar?** Active Directory'nin en kritik 4 portunu (88, 135, 389, 445) tek seferde tarar; signing, OS sürümü, LDAP kökü ve RPC servislerini aynı anda raporlar.
- **Ne Zaman Kullanılır?** Yeni bir DC tespit edildiğinde 10 saniye içinde tam bir güvenlik ve konfigürasyon özeti almak için.
- **Parametreler:** `-oA` (Tüm formatlarda rapor kaydeder).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Nmap Scripting Engine Resmi Dokümantasyonu | [nmap.org/book/nse.html](https://nmap.org/book/nse.html) |
| Nmap smb2-security-mode Kılavuzu | [nmap.org/nsedoc/scripts/smb2-security-mode.html](https://nmap.org/nsedoc/scripts/smb2-security-mode.html) |
| Nmap krb5-enum-users Kılavuzu | [nmap.org/nsedoc/scripts/krb5-enum-users.html](https://nmap.org/nsedoc/scripts/krb5-enum-users.html) |
| MITRE ATT&CK T1046 | [attack.mitre.org](https://attack.mitre.org/techniques/T1046/) |
| MITRE ATT&CK T1087.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |

---

> **Önceki:** [← enum4linux-ng](./enum4linux-ng.md) · **Sonraki:** [Kategori 02: Windows Yerel Komut Satırı ve LOLBins →](../Kategori_02_Windows_Yerel_Komut_Satiri_ve_LOLBins/README.md)
