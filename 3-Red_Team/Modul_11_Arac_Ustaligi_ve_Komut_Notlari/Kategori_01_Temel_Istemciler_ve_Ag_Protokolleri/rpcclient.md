# rpcclient

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Samba MS-RPC CLI istemcisi; SAMR/LSA üzerinden kullanıcı/grup listeleme, RID lookup, parola politikası sorgulama.

---

## 1. Genel Bakış ve Amaç

`rpcclient`, Samba araç setinin parçası olan ve Windows sistemlerindeki **MS-RPC (Microsoft Remote Procedure Call)** fonksiyonlarını komut satırından tetiklemek amacıyla kullanılan son derece yetenekli bir istemcidir. Bir Active Directory sızma testinde özellikle kimlik doğrulama yapılmadan (Null Session) veya düşük yetkili bir etki alanı kullanıcısıyla hedef sistemdeki hesapları, grupları, etki alanı SID bilgisini, parola politikalarını ve güven ilişkilerini numaralandırmak için kullanılır.

`rpcclient`, arka planda SMB (TCP 445 veya TCP 139) üzerinden erişilen **Named Pipes (Adlandırılmış Boru Hatları)** aracılığıyla çalışır. Bu sayede grafik arayüze (GUI) ihtiyaç duymadan doğrudan Windows işletim sisteminin çekirdek yönetim arabirimleriyle (SAMR, LSA, Netlogon, SRVSVC) doğrudan haberleşir.

### Mimari ve Protokol Akışı

`rpcclient` hedef Windows sunucuya bağlandığında tipik bir SMB oturumu üzerinden RPC boru hattına bağlanır:

```
┌─────────────┐     1. SMB Negotiate & Session Setup (TCP 445)     ┌──────────────┐
│  rpcclient  │ ─────────────────────────────────────────────────► │    Hedef     │
│   (Linux)   │     2. Tree Connect to IPC$ Share                  │ (DC / Server)│
│             │ ─────────────────────────────────────────────────► │              │
│             │     3. CreateFile / Open Named Pipe (\pipe\samr)   │              │
│             │ ─────────────────────────────────────────────────► │              │
│             │     4. RPC Bind (SAMR UUID)                        │              │
│             │ ─────────────────────────────────────────────────► │              │
│             │     5. RPC Request (SamrEnumerateUsersInDomain)    │              │
│             │ ─────────────────────────────────────────────────► │              │
│             │ ◄───────────────────────────────────────────────── │              │
│             │     6. RPC Response (Kullanıcı Listesi & RID'ler)  │              │
└─────────────┘                                                    └──────────────┘
```

### Kullanılan Kritik Named Pipe Arayüzleri

| Boru Hattı (Named Pipe) | Protokol Spesifikasyonu | Kullanım Alanı ve Yetenekler |
|---|---|---|
| `\pipe\samr` | **MS-SAMR** (Security Account Manager) | Kullanıcı/grup listeleme, hesap oluşturma/silme, parola değiştirme, RID çözümleme |
| `\pipe\lsarpc` | **MS-LSAD** / **MS-LSAT** (LSA Policy) | Domain SID tespiti, SID-isim dönüştürme, hesap ayrıcalıkları |
| `\pipe\srvsvc` | **MS-SRVS** (Server Service) | Paylaşımları listeleme, paylaşım izinleri ve bağlantı oturumlarını dökme |
| `\pipe\netlogon` | **MS-NRPC** (Netlogon Remote) | DC keşfi, güven ilişkileri sorgulama, ZeroLogon zafiyet yüzeyi |
| `\pipe\wkssvc` | **MS-WKST** (Workstation Service) | Oturum açmış aktif kullanıcıları (logged-on users) listeleme |
| `\pipe\spoolss` | **MS-RPRN** (Print System Remote) | Yazıcı servisleri sorgulama, PrintNightmare / Coercion tetikleme |

### Neden Önemli?

| Senaryo | Operasyonel Değer |
|---|---|
| **Null Session ile İlk Bilgi Sızdırma** | Parolasız bağlantıyla kullanıcı adlarını ve domain SID bilgisini elde etme. |
| **Parola Kilitleme Politikası Öğrenme** | `getdompwinfo` ile kilitlenme eşiğini görerek güvenli parola püskürtme (spraying) planlama. |
| **RID Cycling (lookupsids)** | LDAP kapalı veya kısıtlı olsa dahi sıralı RID değerleri (500-1100) sorgulayarak gizli kullanıcıları tespit etme. |
| **Domain Trusts Keşfi** | Etki alanları arasındaki güven ilişkilerini tek komutla haritalama. |
| **Parola Değiştirme / Yönetim** | Ele geçirilen yetkiyle uzaktan kullanıcının parolasını güncelleme veya yeni kullanıcı açma. |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Bağlantı Sözdizimi

```bash
# İnteraktif kabuk açma:
rpcclient -U 'DOMAIN\kullanıcı%parola' <hedef_IP_veya_FQDN>

# Null session (parolasız) bağlantı:
rpcclient -U '' -N <hedef_IP_veya_FQDN>

# Tek komut çalıştırıp çıkma (Non-interactive):
rpcclient -U 'DOMAIN\kullanıcı%parola' -c 'komut1; komut2' <hedef_IP_veya_FQDN>
```

### Kritik Parametreler

| Parametre | Açıklama | Örnek Kullanım |
|---|---|---|
| `-U` | Oturum açılacak kullanıcı (`DOMAIN\user%pass` formatında) | `-U 'CORP\j.doe%P@ss123'` |
| `-N` | Parola sorma istemini tamamen kapatır (Null session için şarttır) | `-U '' -N` |
| `-W` | Çalışma grubu veya etki alanı adı | `-W CORP` |
| `-c` | İnteraktif kabuk açmadan belirtilen komutları koşturup çıkar | `-c 'enumdomusers; exit'` |
| `--pw-nt-hash` | Düz parola yerine 32 karakterlik NTLM hash ile bağlanır (PTH) | `--pw-nt-hash` |
| `-k` | Kerberos kimlik doğrulaması kullan (`KRB5CCNAME` ccache) | `-k` |
| `-A` | Kimlik bilgilerini dosyadan okur (`username=`, `password=`, `domain=`) | `-A /root/.smbcreds` |
| `-I` | Hedef IP adresini belirtir (NetBIOS/DNS ad çözümlemesi atlanır) | `-I 10.10.10.100` |
| `-p` | Hedef SMB portu (varsayılan: 445) | `-p 139` |
| `-d` | Debug/hata ayıklama seviyesi (0-10) | `-d 3` |

### İnteraktif `rpcclient` Komutları Kütüphanesi

Bağlantı kurulduktan sonra `rpcclient $>` isteminde çalıştırılan yerleşik komutlar:

#### 1. SAMR Komutları (Kullanıcı, Grup ve Hesap Yönetimi)
- `enumdomusers` — Etki alanındaki tüm kullanıcıları RID değerleriyle listeler.
- `enumdomgroups` — Etki alanı güvenlik gruplarını listeler.
- `queryuser <RID_veya_Username>` — Belirtilen kullanıcının logon script, parola son değişim tarihi, kilitlenme durumunu döker.
- `querygroup <RID>` — Belirtilen grubun özniteliklerini gösterir.
- `querygroupmem <RID>` — Belirtilen gruba üye olan kullanıcıların RID listesini verir.
- `queryusergroups <RID>` — Kullanıcının üye olduğu tüm grupları döker.
- `lookupnames <username>` — Kullanıcı/grup adını SID değerine çevirir.
- `lookupsids <SID>` — SID değerini kullanıcı/grup adına çevirir (RID Cycling temeli).
- `getdompwinfo` — Parola karmaşıklığı, minimum uzunluk ve kilitleme politikasını getirir.
- `chgpasswd <user> <eski_parola> <yeni_parola>` — Kullanıcı parolasını değiştirir.
- `createdomuser <username>` — Etki alanında yeni kullanıcı oluşturur.
- `deletedomuser <username>` — Etki alanından kullanıcıyı siler.

#### 2. LSA Komutları (Yerel Güvenlik Otoritesi ve SID Keşfi)
- `lsaquery` — Hedef sistemin birincil etki alanı adını ve **Domain SID** değerini döndürür.
- `lsaenumsid` — Sistemde tanımlı tüm LSA SID nesnelerini numaralandırır.
- `lsaenumprivsaccount <SID>` — Belirtilen SID'ye atanmış ayrıcalıkları (SeDebugPrivilege vb.) listeler.

#### 3. SRVSVC & Paylaşım Komutları
- `netshareenum` — Sunucudaki açık paylaşımları listeler.
- `netshareenumall` — İdari gizli paylaşımlar (`C$`, `ADMIN$`) dahil tüm paylaşımları döker.
- `netsharegetinfo <paylaşım_adı>` — Paylaşımın disk yolu ve açıklama bilgilerini gösterir.

#### 4. Etki Alanı ve Sistem Komutları
- `dsroledominfo` — Makinenin rolünü (Stand-alone, Domain Member, Primary DC) gösterir.
- `dsenumdomtrusts` — Etki alanının sahip olduğu tüm güven ilişkilerini (Trusts) listeler.
- `getusername` — Geçerli oturumun kimlik bağlamını döndürür.

---

## 3. Pratik Komut Örnekleri

### 3.1 Anonim (Null Session) ile İlk Bağlantı ve Keşif
Hedef sistemde misafir/anonim erişim denemesi:

```bash
rpcclient -U '' -N 192.168.1.10
```
Kabuk açıldığında sistem hakkında temel kimlik bilgileri alınır:
```text
rpcclient $> getusername
Account Name: anonymous, Authority Name: 
rpcclient $> lsaquery
Domain Name: CORP
Domain Sid: S-1-5-21-3829182391-238491823-1029384918
```

### 3.2 Etki Alanı Kullanıcılarını ve RID Değerlerini Listeleme
```text
rpcclient $> enumdomusers
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[j.doe] rid:[0x450]
user:[sql_service] rid:[0x451]
```
> `0x1f4` onaltılık (hexadecimal) gösterimdir; onluk (decimal) karşılığı `500`'dür (varsayılan Domain Admin).

### 3.3 Belirli Bir Kullanıcının Detaylı Profilini İnceleme (`queryuser`)
Elde edilen bir RID üzerinden hesap kilitlenme ve son parola değişim tarihini sorgulama:

```text
rpcclient $> queryuser 0x450
        User Name   :   j.doe
        Full Name   :   John Doe
        Home Drive  :   
        Dir Drive   :   
        Profile Path:   
        Logon Script:   logon.bat
        Password Last Set Time: Wed, 12 Oct 2026 14:22:10 UTC
        Account Expires Time  : Infinite
        Password Inactive Time: Infinite
        Account Attributes    : 0x00000010 (NORMAL_ACCOUNT)
```

### 3.4 Parola Kilitleme Politikasını Çekme (`getdompwinfo`)
Parola püskürtme (spray) saldırısı öncesi güvenlik sınırlarını anlama:

```text
rpcclient $> getdompwinfo
min_password_len: 8
password_properties: 0x00000001 (COMPLEXITY)
num_passwords_checked: 0
account_lockout_threshold: 5
account_lockout_duration: 30 minutes
reset_count_time: 30 minutes
```

### 3.5 RID Cycling / Brute-Force (Bash Script ile Otomatik SID Çözme)
Null session ile `enumdomusers` engellenmiş olsa bile, `lookupsids` fonksiyonu çoğu zaman açık bırakılır. `lsaquery` ile alınan Domain SID'nin sonuna 500-1100 arasındaki RID'ler eklenerek bash döngüsüyle kullanıcılar çekilir:

```bash
DOMAIN_SID="S-1-5-21-3829182391-238491823-1029384918"
for rid in $(seq 500 1100); do
    rpcclient -U '' -N -c "lookupsids ${DOMAIN_SID}-${rid}; exit" 192.168.1.10 2>/dev/null | grep -v "unknown"
done
```

### 3.6 Non-Interactive Bash Entegrasyonu (Tek Satırda Veri Alma)
Etki alanı kullanıcı listesini doğrudan bir text dosyasına aktarma:

```bash
rpcclient -U 'CORP\j.doe%Password123!' -c 'enumdomusers; exit' 192.168.1.10 | awk -F'[' '{print $2}' | cut -d']' -f1 > /opt/recon/users.txt
```

### 3.7 Etki Alanı Güven İlişkilerini (Trusts) Numaralandırma
```text
rpcclient $> dsenumdomtrusts
Direction: Inbound/Outbound
Flags    : 0x00000020
Type     : Forest Trust
Partner  : PARTNER.LOCAL
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Kodu / Mesaj | Olası Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `NT_STATUS_ACCESS_DENIED` | Hedefte null session engellenmiş (`RestrictAnonymous`) veya kullanıcı yetkisiz. | Geçerli bir domain kullanıcısı (`-U 'DOMAIN\user%pass'`) kullanın veya LDAP/RID Cycling yöntemine geçin. |
| `NT_STATUS_LOGON_FAILURE` | Kullanıcı adı veya parola hatalı / hesap devre dışı veya kilitli. | Kimlik bilgilerini teyit edin; hesap kilitlenmelerine karşı parolayı tekrar tekrar denemeyin. |
| `NT_STATUS_CONNECTION_REFUSED` | TCP 445 veya TCP 139 portu kapalı veya güvenlik duvarı tarafından engelleniyor. | `nmap -p 139,445 <IP>` ile portun açık olduğunu doğrulayın. |
| `NT_STATUS_PIPE_NOT_AVAILABLE` | İlgili named pipe (örneğin `\pipe\spoolss` veya `\pipe\samr`) hedefte devre dışı bırakılmış. | Hedefin ilgili servisi (Print Spooler vb.) çalışıp çalışmadığını kontrol edin. |
| `NT_STATUS_NO_SUCH_USER` | `queryuser` komutuna geçilen RID veya kullanıcı adı hedef veritabanında mevcut değil. | Önce `enumdomusers` veya `lookupsids` ile geçerli RID değerini teyit edin. |
| `NT_STATUS_PASSWORD_RESTRICTION` | `chgpasswd` komutu ile verilen yeni parola etki alanı karmaşıklık kurallarına uymuyor. | Yeni parolayı büyük harf, küçük harf, rakam ve özel karakter içerecek şekilde uzatın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Kaynak | Event ID / Log | Detay ve Açıklama |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | Ağ oturumu (Network Logon) — Her rpcclient bağlantısında üretilir. |
| **Windows Security Log** | **4625** | Başarısız oturum açma (hatalı parola veya reddedilen null session). |
| **Windows Security Log** | **5145** | Ayrıntılı paylaşılan nesne erişimi — `IPC$` paylaşımındaki `\pipe\samr`, `\pipe\lsarpc` borularına erişim loglanır. |
| **Windows Security Log** | **4738** | `chgpasswd` ile kullanıcı hesabı modifiye edildiğinde üretilir. |
| **Windows Security Log** | **4720** | `createdomuser` ile yeni kullanıcı oluşturulduğunda üretilir. |
| **Sysmon** | **Event ID 3** | TCP 445/139 üzerinden istemci IP adresinden gelen ağ bağlantısı. |

### 5.2 Ağ ve EDR İmzaları
- **SAMR Uzaktan Numaralandırma Anomalisi:** `rpcclient` ile art arda yapılan `SamrEnumerateUsersInDomain` veya yüzlerce `SamrLookupNames` çağrısı, modern EDR ve Microsoft Defender for Identity (MDI) tarafından **"Active Directory Reconnaissance via SAMR"** alarmı olarak işaretlenir.
- **Null Session İmzası:** Anonim bağlamda gelen SMB oturum açma istekleri SIEM kurallarında `Logon Type 3` ve boş `TargetUserName` filtresiyle doğrudan yakalanır.
- **RestrictRemoteSAM:** Windows 10 (1607+) ve Server 2016+ sürümlerinde varsayılan olarak yöneticiler haricindeki kullanıcıların uzaktan SAMR sorgusu yapması kısıtlanmıştır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | rpcclient Kullanımı |
|---|---|---|
| **T1087.002** | Account Discovery: Domain Account | `enumdomusers` ve `queryuser` ile kullanıcı tespiti |
| **T1087.001** | Account Discovery: Local Account | Yerel SAM kullanıcılarının listelenmesi |
| **T1069.002** | Permission Groups Discovery: Domain Groups | `enumdomgroups` ve `querygroupmem` ile grup haritalama |
| **T1201** | Password Policy Discovery | `getdompwinfo` ile kilitleme ve parola kurallarını çekme |
| **T1482** | Domain Trust Discovery | `dsenumdomtrusts` ile etki alanı güven ilişkilerini haritalama |
| **T1135** | Network Share Discovery | `netshareenumall` ile idari paylaşımları keşfetme |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **Seri lookupsids çağrıları EDR tetikler** | Yüzlerce RID'i saniyeler içinde taramak yerine, gecikmeli (`sleep`) çalıştırın veya doğrudan LDAP sorgularını tercih edin. |
| **Null Session yüksek alarm üretir** | Ortamda meşru bir kullanıcı hesabı ele geçirildiyse null session yerine o hesabı kullanın. |
| **NTLM trafiği ağda görünür** | NTLM yerine Kerberos bilet önbelleği (`-k`) kullanarak Kerberos kimlik doğrulamasına geçin. |
| **Gereksiz RPC modülleri çalıştırmayın** | Sadece hedeflenen komutları (`-c`) çalıştırıp oturumu derhal kapatın. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- Log analizi ve tespit kuralları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- Uzaktan SAMR kısıtlaması → `Network access: Restrict clients allowed to make remote calls to SAM` GPO politikası (`RestrictRemoteSAM`)
- Null session engelleme → `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RestrictAnonymous = 2`
- SMB İmzalama (Signing) zorunluluğu → [Blue M08 — Protokol Sertleştirme](../../../2-Blue_Team/Modul_08_Protokol_Sertlestirme_ve_Relay_Onleme/)

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve kırmızı takım operasyonlarında en sık kullanılan `rpcclient` komutlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Anonim (Null Session) ile İnteraktif Kabuk Başlatma
```bash
rpcclient -U '' -N 192.168.1.10
```
- **Ne Yapar?** Kullanıcı adı ve parola sormadan hedef sunucuya parolasız SMB oturumu ve RPC kabuğu açar.
- **Ne Zaman Kullanılır?** İlk temas anında hedef sistemin anonim RPC erişimine açık olup olmadığını test etmek için.
- **Parametreler:** `-U ''` (Boş kullanıcı adı), `-N` (Parola sormayı devre dışı bırakır).

### 6.2 Tek Satırda Parola Politikasını Çekme (Non-Interactive)
```bash
rpcclient -U 'CORP\j.doe%P@ss123!' -c 'getdompwinfo; exit' 192.168.1.10
```
- **Ne Yapar?** Kabuğa girmeden parola karmaşıklığı, minimum uzunluk ve hesap kilitlenme eşiğini ekrana basıp çıkar.
- **Ne Zaman Kullanılır?** Parola püskürtme (spray) operasyonu öncesinde hesapları kilitlememek için güvenlik eşiğini öğrenmek amacıyla.
- **Parametreler:** `-c` (Çalıştırılacak yerleşik RPC komut dizisi).

### 6.3 Etki Alanı Kullanıcılarını ve RID Değerlerini Listeleme
```bash
rpcclient -U 'CORP\j.doe%P@ss123!' -c 'enumdomusers; exit' 192.168.1.10
```
- **Ne Yapar?** Etki alanındaki tüm kullanıcı hesaplarını ve bunlara karşılık gelen onaltılık RID değerlerini (`[0x1f4]`, `[0x450]` vb.) listeler.
- **Ne Zaman Kullanılır?** Etki alanı kullanıcı envanterini hızlıca elde etmek ve hedef kullanıcı listesi oluşturmak için.

### 6.4 Belirli Bir RID Üzerinden Detaylı Kullanıcı Bilgisi Sorgulama
```bash
rpcclient -U 'CORP\j.doe%P@ss123!' -c 'queryuser 0x1f4; exit' 192.168.1.10
```
- **Ne Yapar?** Belirtilen RID değerine sahip hesabın (0x1f4 = Administrator) son parola değişim tarihini, oturum script'ini ve hesap bayraklarını getirir.
- **Ne Zaman Kullanılır?** Kritik idari hesapların durumunu, aktif olup olmadıklarını ve parola yaşını analiz etmek için.

### 6.5 Domain SID Değerini Öğrenme (`lsaquery`)
```bash
rpcclient -U 'CORP\j.doe%P@ss123!' -c 'lsaquery; exit' 192.168.1.10
```
- **Ne Yapar?** Hedef sistemin birincil etki alanı adını ve `S-1-5-21-...` ile başlayan Domain SID değerini döker.
- **Ne Zaman Kullanılır?** Golden/Silver Ticket üretimi, RID cycling veya manuel Kerberos manipülasyonları için Domain SID gerektiğinde.

### 6.6 Otomatik RID Cycling ile Kullanıcı Listesini Sızdırma
```bash
for rid in $(seq 500 1100); do rpcclient -U '' -N -c "lookupsids S-1-5-21-3829182391-238491823-1029384918-$rid; exit" 192.168.1.10 2>/dev/null | grep "SidTypeUser"; done
```
- **Ne Yapar?** 500-1100 arasındaki tüm RID'leri döngüyle SID çözümleme çağrısına gönderir ve sadece kullanıcı tipindeki hesapları listeler.
- **Ne Zaman Kullanılır?** `enumdomusers` komutunun engellendiği ancak `lookupsids` fonksiyonunun çalıştığı kısıtlı ortamlarda.

### 6.7 Etki Alanı Güven İlişkilerini (Trusts) Listeleme
```bash
rpcclient -U 'CORP\j.doe%P@ss123!' -c 'dsenumdomtrusts; exit' 192.168.1.10
```
- **Ne Yapar?** Etki alanının diğer ormanlar (forests) ve etki alanlarıyla kurduğu gelen (inbound), giden (outbound) ve iki yönlü güven ilişkilerini listeler.
- **Ne Zaman Kullanılır?** Çoklu etki alanı (multi-domain) mimarilerinde güven ilişkileri üzerinden yanal hareket yolları ararken.

### 6.8 Kerberos Bileti (ccache) ile Parolasız rpcclient Oturumu Açma
```bash
export KRB5CCNAME=/tmp/admin.ccache
rpcclient -k -no-pass dc01.corp.local
```
- **Ne Yapar?** NTLM trafiği üretmeksizin mevcut Kerberos bilet önbelleğini kullanarak etki alanı denetleyicisine RPC oturumu açar.
- **Ne Zaman Kullanılır?** NTLM'in kapalı olduğu veya ağda NTLM trafiğinin tespit edildiği sertleştirilmiş ortamlarda OPSEC dostu keşif için.
- **Parametreler:** `-k` (Kerberos kimlik doğrulamasını zorlar), `-no-pass` (Parola sormayı engeller).

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Samba rpcclient Dokümantasyonu | [samba.org/docs](https://www.samba.org/samba/docs/current/man-html/rpcclient.1.html) |
| MS-SAMR Protokol Dokümantasyonu | [Microsoft Docs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/) |
| MS-LSAD Protokol Dokümantasyonu | [Microsoft Docs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-lsad/) |
| MITRE ATT&CK T1087.002 | [attack.mitre.org](https://attack.mitre.org/techniques/T1087/002/) |
| HackTricks — Pentesting SMB & RPC | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smb.html) |

---

> **Önceki:** [← windapsearch](./windapsearch.md) · **Sonraki:** [impacket-rpcdump →](./impacket-rpcdump.md)
