# impacket-rpcdump

> **Kategori:** [1. TEMEL İSTEMCİLER VE AĞ PROTOKOL ARAÇLARI (NATIVE CLIENTS & UTILITIES)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** RPC Endpoint Mapper (TCP 135) üzerinden hedef sistemdeki kayıtlı RPC arayüzlerini ve servisleri dökme.

---

## 1. Genel Bakış ve Amaç

`impacket-rpcdump` (veya Impacket suite içindeki adıyla `rpcdump.py`), Microsoft Windows sistemlerinde çalışan **RPC Endpoint Mapper (EPMAPPER)** servisini uzaktan sorgulayan bir Python aracıdır. Windows mimarisinde birçok kritik servis (Print Spooler, Task Scheduler, WMI, Active Directory Replikasyonu, Sertifika Servisleri, EFS vb.) sabit portlar yerine sistem açılışında dinamik olarak atanan rastgele yüksek TCP portları (49152-65535) veya SMB adlandırılmış boru hatları (Named Pipes) üzerinde dinlemeye başlar.

Bu dinamik servislerin hangi port veya pipe üzerinde dinleme yaptığını istemcilere bildiren merkezi rehber **TCP 135** portunda çalışan **RPC Endpoint Mapper**'dır. `impacket-rpcdump`, bu rehbere bağlanarak hedef işletim sisteminde kayıtlı olan tüm RPC arayüzlerini, bunlara ait benzersiz **UUID (Universally Unique Identifier)** değerlerini ve dinledikleri adresleri (Tower/Endpoint) döker.

### Mimari ve Protokol Akışı

```
┌──────────────────┐               TCP 135 (EPMAPPER)              ┌──────────────────┐
│ impacket-rpcdump │ ────────────────────────────────────────────► │  Hedef Windows   │
│     (Linux)      │        1. RPC Bind: EPMAPPER UUID             │   (DC / Server)  │
│                  │ ◄──────────────────────────────────────────── │                  │
│                  │        2. ept_lookup İsteği (Giriş Sorgusu)   │                  │
│                  │ ────────────────────────────────────────────► │                  │
│                  │        3. Kayıtlı RPC Kuleleri (Tower Listesi)│                  │
│                  │ ◄──────────────────────────────────────────── │                  │
└──────────────────┘                                               └──────────────────┘
     │
     ▼ Çözümlenen Uç Noktalar:
     ├── MS-RPRN  (Print Spooler)   ──► ncacn_np:[\\pipe\\spoolss]  (Zorlamalı Kimlik Doğrulama)
     ├── MS-EFSR  (PetitPotam)      ──► ncacn_np:[\\pipe\\efsrpc]   (NTLM Relay Zafiyeti)
     ├── DRSUAPI  (DCSync/Replication)► ncacn_ip_tcp:[49667]        (Domain Hash Dökümü)
     ├── MS-DFSNM (DFSCoerce)       ──► ncacn_np:[\\pipe\\netdfs]   (NetBIOS/AD Coercion)
     └── Task Sched (atsvc)         ──► ncacn_np:[\\pipe\\atsvc]    (Uzak Kod Yürütme)
```

1. **EPM Bağlantısı:** İstemci, hedefin TCP 135 portuna bağlanır veya SMB `\pipe\epmapper` üzerinden bağlantı açar.
2. **UUID Sorgusu (`ept_lookup`):** İstemci, Endpoint Mapper veritabanındaki tüm kayıtları sırayla ister.
3. **Arayüz Haritası Çıkarımı:** Hedef sunucu, her bir RPC arayüzü için UUID, sürüm, protokol sırası (TCP veya Named Pipe) ve adres bilgisini yanıt olarak döner.

### Kritik Active Directory RPC Arayüzleri ve UUID Kataloğu

Sızma testlerinde `rpcdump` çıktısında aranan en kritik RPC arayüzleri ve operasyonel karşılıkları:

| Protokol Spesifikasyonu | UUID Değeri | Sürüm | Taşıma Protokolü / Boru | Operasyonel Tehdit / İstismar Amacı |
|---|---|---|---|---|
| **MS-EFSR** (Encrypting File System) | `c681d488-d850-11d0-8c52-00c04fd90f7e` | v1.0 | `ncacn_np:[\pipe\efsrpc]` | **PetitPotam:** DC makine hesabını NTLM relay için dinleyiciye zorlama |
| **MS-EFSR (Alternate)** | `df1941c5-fe89-4e79-bf10-463657acf44d` | v1.0 | `ncacn_np:[\pipe\lsarpc]` | PetitPotam alternatif arayüzü |
| **MS-RPRN** (Print System Remote) | `12345678-1234-abcd-ef00-0123456789ab` | v1.0 | `ncacn_np:[\pipe\spoolss]` | **SpoolSample / PrintNightmare:** Kimlik doğrulama zorlama ve RCE |
| **MS-PAR** (Print System Async) | `76f03843-0000-0000-c000-000000000046` | v1.0 | `ncacn_np:[\pipe\spoolss]` | Modern PrintNightmare RPC arayüzü |
| **MS-DRSR / DRSUAPI** | `e3514235-4b06-11d1-ab04-00c04fc2dcd2` | v4.0 | `ncacn_ip_tcp:[Dinamik Port]` | **DCSync:** Etki alanı parola özetlerini (NTDS.dit) uzaktan replike etme |
| **MS-SAMR** (Security Account Mgr) | `12345778-1234-abcd-ef00-0123456789ac` | v1.0 | `ncacn_np:[\pipe\samr]` | Kullanıcı, grup ve parola politikalarını sorgulama ve RID Cycling |
| **MS-LSAD / MS-LSAT** (LSA Policy) | `12345778-1234-abcd-ef00-0123456789ab` | v0.0 | `ncacn_np:[\pipe\lsarpc]` | Domain SID sorgulama ve hesap ayrıcalıklarını haritalama |
| **MS-SCMR** (Service Control Mgr) | `367abb81-9844-35f1-ad32-98f038001003` | v2.0 | `ncacn_np:[\pipe\svcctl]` | **PsExec:** Servis oluşturma yoluyla SYSTEM yetkisinde kod yürütme |
| **MS-TSCH** (Task Scheduler) | `1ff70682-0a51-30e8-076d-740be8cee98b` | v1.0 | `ncacn_np:[\pipe\atsvc]` | **atexec:** Zamanlanmış görev oluşturarak uzaktan kod yürütme |
| **MS-DFSNM** (DFS Namespace) | `4fc742e0-4a10-11cf-8273-00aa004ae673` | v3.0 | `ncacn_np:[\pipe\netdfs]` | **DFSCoerce:** Dağıtık dosya sistemi üzerinden NTLM coercion |
| **MS-FSRVP** (Shadow Copy Mgmt) | `a8e0653c-2744-4389-a61d-7373df8b2292` | v1.0 | `ncacn_np:[\pipe\FssagentRpc]` | **ShadowCoerce:** VSS servisi üzerinden NTLM coercion |
| **MS-ICPR** (Cert Enrollment) | `91af37a7-2007-4e7a-9c7a-7c229986b72a` | v1.0 | `ncacn_ip_tcp:[Dinamik Port]` | **AD CS ESC8:** RPC üzerinden sertifika talebi ve NTLM relay |
| **MS-WMI / DCOM** | `4a2a850f-e175-40e5-a65e-49b16bf79472` | v0.0 | `ncacn_ip_tcp:[Dinamik Port]` | **wmiexec / DcomExec:** WMI ve DCOM ile yanal hareket |

### Karşılaştırma: rpcdump vs Alternatif Araçlar

| Yetenek | impacket-rpcdump | rpcclient | nmap (msrpc-enum) | Sysinternals epdump |
|---|---|---|---|---|
| **EPM Dökümü (TCP 135)** | ✅ Tam ve Otomatik | ❌ Yalnızca manuel arayüz | ✅ NSE scripti ile | ✅ Konsol çıktısı |
| **SMB Tünelleme (`\pipe\epmapper`)**| ✅ Destekler | ❌ Desteklemez | ❌ Yalnızca TCP 135 | ❌ Yalnızca yerel/TCP |
| **Pass-the-Hash Desteği** | ✅ Yerleşik (`-hashes`) | ✅ `--pw-nt-hash` | ❌ Desteklemez | ❌ Desteklemez |
| **Kerberos Desteği (ccache)** | ✅ `-k -no-pass` | ✅ `-k` | ❌ Desteklemez | ❌ Yalnızca Windows oturumu |
| **Çıktı Formatı** | Detaylı Tower kaydı | İnteraktif kabuk | Nmap text XML | Düz metin |
| **Platform** | Bağımsız (Python) | Linux (Samba) | Cross-platform | Yalnızca Windows |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

### Genel CLI Sözdizimi

```bash
# Standart bağlantı sözdizimi:
impacket-rpcdump [domain/]username[:password]@<hedef_IP_veya_Host>

# Impacket script doğrudan çağrısı:
rpcdump.py [domain/]username[:password]@<hedef_IP_veya_Host>

# Protokol dizgisi (binding string) ile doğrudan bağlama:
rpcdump.py ncacn_ip_tcp:192.168.1.10[135]
```

### Bağlantı ve Kimlik Doğrulama Parametreleri

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `target` | Hedef sistem IP adresi veya FQDN | `192.168.1.10` veya `dc01.corp.local` |
| `domain/user:pass` | Kimlik doğrulama bilgisi (Anonim için boş bırakılabilir) | `CORP/j.doe:P@ss123` |
| `-hashes` | Pass-the-Hash için NTLM hash (`LM:NT` veya `:NT`) | `-hashes :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-no-pass` | Parola sorma istemini tamamen devre dışı bırakır | `-no-pass` |
| `-k` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME` önbelleği) | `-k -no-pass` |
| `-aesKey` | Kerberos kimlik doğrulamasında kullanılacak 128/256-bit AES anahtarı | `-aesKey 7b318d...` |
| `-port` | RPC Endpoint Mapper dinleme portu (Varsayılan: 135) | `-port 135` |
| `-target-ip` | Kerberos auth kullanılırken FQDN yerine gidilecek fiziksel IP | `-target-ip 192.168.1.10` |
| `-ts` | Çıktı satırlarına zaman damgası (timestamp) ekler | `-ts` |
| `-debug` | Ayrıntılı soket ve protokol hata ayıklama çıktılarını gösterir | `-debug` |

### Protokol Taşıma Dizgileri (Protocol Sequences)
`rpcdump`, hedefe farklı ağ katmanları üzerinden erişebilir:
- `ncacn_ip_tcp:<IP>[135]` — Doğrudan TCP soketi üzerinden RPC haberleşmesi.
- `ncacn_np:<IP>[\pipe\epmapper]` — SMB taşıyıcısı içindeki Named Pipe üzerinden RPC.
- `ncalrpc:[epmapper]` — Yalnızca yerel sistemler arası (Local Inter-Process RPC).

---

## 3. Pratik Komut Örnekleri

### 3.1 Anonim (Parolasız) RPC Dökümü ve Çıktı Analizi
Hedef sunucuya herhangi bir kimlik bilgisi girmeden bağlanıp EPM tablosunu çekme:

```bash
impacket-rpcdump 192.168.1.10
```

**Gerçekçi Çıktı Kesiti ve Satır Satır Analiz:**
```text
Protocol: ncacn_ip_tcp
Provider: None
UUID: e3514235-4b06-11d1-ab04-00c04fc2dcd2 v4.0 
Comment: MS-DRSR (Directory Replication Service)
Binding: ncacn_ip_tcp:192.168.1.10[49667]

Protocol: ncacn_np
Provider: None
UUID: 12345678-1234-abcd-ef00-0123456789ab v1.0 
Comment: Spooler SubSystem Service
Binding: ncacn_np:192.168.1.10[\pipe\spoolss]

Protocol: ncacn_np
Provider: None
UUID: c681d488-d850-11d0-8c52-00c04fd90f7e v1.0 
Comment: Encrypting File System
Binding: ncacn_np:192.168.1.10[\pipe\efsrpc]
```
- `Protocol: ncacn_ip_tcp` → Servise doğrudan TCP üzerinden erişilebilir.
- `Binding: ncacn_ip_tcp:192.168.1.10[49667]` → DRSUAPI (DCSync) servisi 49667 portunda dinlemededir.
- `Protocol: ncacn_np` → Servise SMB adlandırılmış borusu üzerinden erişilmelidir (`\pipe\spoolss` ve `\pipe\efsrpc`).

### 3.2 PetitPotam (MS-EFSR) Zafiyetini Doğrulama
Hedef sunucunun PetitPotam saldırısına açık olup olmadığını tek adımda denetleme:

```bash
impacket-rpcdump 192.168.1.10 | grep -i -E "efs|c681d488"
```
- **Operasyonel Anlamı:** Eğer çıktı dönerse, hedef sistem NTLM Relay saldırılarında (örneğin AD CS Web Enrollment ESC8 zafiyetine karşı) zorlayıcı (coercion) olarak kullanılabilir.

### 3.3 Print Spooler (MS-RPRN) Varlığını Doğrulama (SpoolSample Kontrolü)
Etki Alanı Denetleyicisinde Print Spooler servisinin unutulup unutulmadığını kontrol etme:

```bash
impacket-rpcdump 192.168.1.10 | grep -i -E "spooler|12345678-1234-abcd"
```
- **Operasyonel Anlamı:** Eğer DC üzerinde Print Spooler açıksa, kısıtlamasız delegasyona (Unconstrained Delegation) sahip bir sunucu ele geçirildiğinde DC'nin makine hesabı TGT bileti yakalanabilir.

### 3.4 DFSCoerce (MS-DFSNM) Arayüzünü Tarama
Dağıtık Dosya Sistemi (DFS) arayüzünün varlığını doğrulama:

```bash
impacket-rpcdump 192.168.1.10 | grep -i -E "netdfs|4fc742e0"
```
- **Operasyonel Anlamı:** Spooler ve EFS kapatılmışsa, DFSCoerce saldırısı için `\pipe\netdfs` boru hattının açık olup olmadığı tespit edilir.

### 3.5 ShadowCoerce (MS-FSRVP) Arayüzünü Tarama
Gölge Kopya (Volume Shadow Copy) yönetim servisinin dökümü:

```bash
impacket-rpcdump 192.168.1.10 | grep -i -E "fssagentrpc|a8e0653c"
```
- **Operasyonel Anlamı:** Dosya sunucularında VSS File Server Remote VSS servisi üzerinden NTLM coercion tetiklenebilir.

### 3.6 DCSync Dinamik Portunu Tespit Etme
DCSync saldırısı öncesi DC'nin replikasyon portunu belirleme:

```bash
impacket-rpcdump 192.168.1.10 | grep -A 2 -i "e3514235-4b06-11d1-ab04-00c04fc2dcd2"
```

### 3.7 Pass-the-Hash ile SMB Üzerinden EPM Dökümü
TCP 135 portu güvenlik duvarı tarafından engellendiğinde, SMB üzerinden NTLM hash ile `\pipe\epmapper` borusuna bağlanma:

```bash
impacket-rpcdump -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 CORP/Administrator@192.168.1.10
```

### 3.8 Kerberos Bileti ile Parolasız ve İz Bırakmadan Tarama
NTLM trafiği üretmeden, mevcut TGT/TGS bileti ile FQDN üzerinden sorgulama:

```bash
export KRB5CCNAME=/tmp/administrator.ccache
impacket-rpcdump -k -no-pass dc01.corp.local
```

### 3.9 Python ile Özel EPM Tarama Otomasyonu
Impacket kütüphanesini doğrudan Python betiğinde kullanarak hedefte belirli bir UUID'yi otomatik sorgulama:

```python
#!/usr/bin/env python3
from impacket.dcerpc.v5 import transport, epm

target = "192.168.1.10"
string_binding = f"ncacn_ip_tcp:{target}[135]"
rpctransport = transport.DCERPCTransportFactory(string_binding)
rpctransport.set_connect_timeout(5)

try:
    dce = rpctransport.get_dce_rpc()
    dce.connect()
    entries = epm.hept_lookup(None, dce=dce)
    print(f"[+] {target} üzerinde {len(entries)} adet RPC uç noktası tespit edildi.")
    for entry in entries:
        uuid_str = str(entry['tower']['Floors'][0])
        if "c681d488-d850-11d0-8c52-00c04fd90f7e" in uuid_str:
            print("[!] KRİTİK: PetitPotam (MS-EFSR) arayüzü açık!")
        if "12345678-1234-abcd-ef00-0123456789ab" in uuid_str:
            print("[!] KRİTİK: Print Spooler (MS-RPRN) arayüzü açık!")
    dce.disconnect()
except Exception as e:
    print(f"[-] Hata: {e}")
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Kesin Operasyonel Çözüm |
|---|---|---|
| `Connection refused (port 135)` | TCP 135 portu Windows Firewall tarafından kapatılmış veya ağ güvenlik duvarı engelliyor. | Port durumunu `nmap -p 135 <IP>` ile doğrulayın; SMB 445 açıksa bağlantıyı adlandırılmış boru üzerinden deneyin: `rpcdump.py ncacn_np:<IP>[\pipe\epmapper]`. |
| `RPC_S_SERVER_UNAVAILABLE` | Hedef makine kapalı, RPC servisi yanıt vermiyor veya aradaki ağ paketleri düşürüyor. | Hedefe ping atın; TCP 135 soketinin açık olduğunu `nc -nvz <IP> 135` ile test edin. |
| `STATUS_ACCESS_DENIED` | Endpoint Mapper anonim sorgulamaya kapatılmış (`RestrictAnonymous=2` veya RPC filtreleme). | Düz kullanıcı kimlik bilgisi (`CORP/user:pass`) veya NTLM hash (`-hashes`) sağlayarak bağlanın. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos auth kullanılırken hedef IP olarak girilmiş veya SPN KDC'de kayıtlı değil. | IP adresi yerine hedefin tam FQDN adını (`dc01.corp.local`) verin; `/etc/hosts` dosyasında IP-FQDN eşleştirmesini doğrulayın. |
| `[Errno 104] Connection reset by peer` | Ağdaki EDR/IPS cihazı TCP 135 üzerindeki seri `ept_lookup` trafiğini anomali sayarak RST paketi gönderdi. | İstekleri yavaşlatın veya tüm tabloyu çekmek yerine yalnızca belirli arayüze doğrudan bağlanmayı deneyin. |
| `DCERPC Exception: code: 0x1c010002` | `RPC_S_NOT_LISTENING` — Hedeflenen RPC servisi o anda çalışmıyor veya durdurulmuş. | Servisin hedef makinede aktif olup olmadığını (örneğin Spooler) kontrol edin. |
| `Kerberos Clock Skew too great` | Saldırı makinesi ile hedef Etki Alanı Denetleyicisi arasında 5 dakikadan fazla saat farkı var. | `ntpdate <DC_IP>` veya `rdate -n <DC_IP>` komutu ile saatinizi etki alanıyla senkronize edin. |
| `ModuleNotFoundError: No module named 'impacket'` | Impacket Python kütüphanesi geçerli Python ortamında yüklü değil. | `pip3 install impacket` veya sanal ortam (`venv`) kullanarak bağımlılıkları yükleyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler

| Log Kaynağı | Event ID / Log | Detay ve İz Açıklaması |
|---|---|---|
| **Windows Security Log** | **4624** (Logon Type 3) | SMB üzerinden bağlanıldığında üretilen standart ağ oturumu kaydı. |
| **Windows Security Log** | **4625** | Başarısız kimlik doğrulama veya engellenen anonim oturum denemesi. |
| **Windows Security Log** | **5145** | SMB üzerinden `IPC$` paylaşımındaki `\pipe\epmapper` borusuna erişim (`AccessMask: 0x12019f`). |
| **Sysmon** | **Event ID 3** | İstemci IP'sinden gelen TCP 135 bağlantısı (DestinationPort: 135, Image: `svchost.exe`). |
| **Windows RPC Filter Log** | **RPC Runtime** | Dinamik RPC portlarına yapılan yetkisiz veya engellenen bağlantı girişimleri. |

### 5.2 Ağ ve EDR İmzaları
- **EPM Sweeping Tespiti:** Tipik bir kullanıcı iş istasyonu normal şartlarda sunucuların TCP 135 portundaki yüzlerce RPC kaydını tek bir bağlantıda arka arkaya sorgulamaz. NDR (Network Detection & Response) çözümleri ve SIEM kuralları, yüksek sayıda `ept_lookup` isteğini **"Reconnaissance - RPC Endpoint Mapper Sweep"** kuralıyla yakalar.
- **Dinamik Port Taraması Alarmı:** rpcdump çıktısı alındıktan hemen sonra listede görülen rastgele yüksek portlara (49152-65535) doğru port taraması başlatılması korelasyon alarmlarını tetikler.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | impacket-rpcdump Kullanımı |
|---|---|---|
| **T1046** | Network Service Discovery | Hedefteki aktif RPC servislerini, portlarını ve named pipe'ları tespit etme |
| **T1018** | Remote System Discovery | Hedefin DC, sertifika otoritesi (CA) veya dosya sunucusu rollerini doğrulama |
| **T1187** | Forced Authentication | PetitPotam (EFS) veya SpoolSample arayüzlerini bularak zorlamalı kimlik tetikleme |
| **T1021.002** | Remote Services: SMB/Admin Shares | SMB adlandırılmış boru hattı üzerinden RPC tünelleme |

### 5.4 OPSEC Önerileri

| Risk | Operasyonel Önlem |
|---|---|
| **TCP 135 ağda yoğun izlenir** | Tüm EPM tablosunu dökmek yerine, hedeflediğiniz spesifik servisin boru hattını (örneğin doğrudan `\pipe\spoolss`) tekil sınayın. |
| **Toplu port taramasından kaçının** | Dökülen portların tamamına Nmap çalıştırmayın; yalnızca istismar edeceğiniz servisin portunu hedefleyin. |
| **SMB Tünellemesini Tercih Edin** | Doğrudan TCP 135 yerine mevcut SMB 445 kanalı üzerinden `\pipe\epmapper` sorgulaması yapın. |
| **Kerberos Auth Kullanın** | NTLM hash'i ağda taşımamak ve NTLM logları üretmemek için ccache biletleri (`-k -no-pass`) tercih edin. |

### 5.5 Savunma Karşılığı (Blue Team Linkleri)
- RPC izleme ve tespit senaryoları → [Blue M01 — Görünürlük ve Log Yönetimi](../../../2-Blue_Team/Modul_01_Gorunurluk_ve_Log_Yonetimi/)
- Spooler servisini DC'lerde kapatma → `Stop-Service Spooler -Passthru; Set-Service Spooler -StartupType Disabled`
- RPC Endpoint Mapper erişim kısıtlaması → Windows Defender Firewall ile port 135'e yalnızca yetkili PAW (Privileged Access Workstation) alt ağlarından izin verilmesi.
- RPC Filtreleme (RPC Filters) → Netsh ile yetkisiz arayüzlerin dinamik portlara bağlanmasının engellenmesi.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

Aşağıdaki liste, sızma testlerinde ve operasyonel keşiflerde en sık başvurulan `impacket-rpcdump` komut kombinasyonlarını, kullanım amaçlarını ve parametre analizlerini bir araya getirir:

### 6.1 Anonim Olarak Tüm RPC Uç Noktalarını Dökme
```bash
impacket-rpcdump 192.168.1.10
```
- **Ne Yapar?** Kimlik doğrulaması olmaksızın hedefteki TCP 135 Endpoint Mapper servisine bağlanarak sistemde kayıtlı tüm RPC servis ve port listesini ekrana basar.
- **Ne Zaman Kullanılır?** İç ağdaki bir Windows sunucuyla ilk temas anında açık servisleri ve zafiyet yüzeyini haritalamak için.
- **Parametreler:** Yalnızca hedef IP veya host adı belirtilir.

### 6.2 PetitPotam (EFS) Zafiyet Arayüzünü Hızlıca Doğrulama
```bash
impacket-rpcdump 192.168.1.10 | grep -i "c681d488-d850-11d0-8c52-00c04fd90f7e"
```
- **Ne Yapar?** Tüm döküm içerisinden yalnızca Encrypting File System (MS-EFSR) protokolüne ait UUID'yi arar.
- **Ne Zaman Kullanılır?** Sunucunun PetitPotam üzerinden NTLM Coercion saldırısına açık olup olmadığını tek satırda doğrulamak için.

### 6.3 Print Spooler (MS-RPRN) Servisinin Açık Olduğunu Teyit Etme
```bash
impacket-rpcdump 192.168.1.10 | grep -i "12345678-1234-abcd-ef00-0123456789ab"
```
- **Ne Yapar?** Hedef sunucuda Spooler SubSystem Service (MS-RPRN) RPC arayüzünün varlığını sorgular.
- **Ne Zaman Kullanılır?** Etki Alanı Denetleyicisini zorlamalı kimlik doğrulamaya (SpoolSample) zorlamadan önce servisin çalıştığını teyit etmek için.

### 6.4 DCSync (DRSUAPI) Replikasyon Servis Portunu Belirleme
```bash
impacket-rpcdump 192.168.1.10 | grep -A 2 -i "e3514235-4b06-11d1-ab04-00c04fc2dcd2"
```
- **Ne Yapar?** Active Directory Directory Replication Service (DRSUAPI) arayüzünü arar ve dinlediği dinamik TCP portunu gösterir.
- **Ne Zaman Kullanılır?** DCSync saldırısı gerçekleştirilmeden önce hedef DC'nin hangi RPC portu üzerinden hizmet verdiğini tespit etmek için.

### 6.5 DFSCoerce (MS-DFSNM) Arayüzünü Kontrol Etme
```bash
impacket-rpcdump 192.168.1.10 | grep -i "4fc742e0-4a10-11cf-8273-00aa004ae673"
```
- **Ne Yapar?** Dağıtık Dosya Sistemi Yönetimi (Netdfs) arayüzünün varlığını doğrular.
- **Ne Zaman Kullanılır?** Spooler servisi kapalı DC'lerde alternatif NTLM coercion yolu ararken.

### 6.6 ShadowCoerce (MS-FSRVP) Arayüzünü Kontrol Etme
```bash
impacket-rpcdump 192.168.1.10 | grep -i "a8e0653c-2744-4389-a61d-7373df8b2292"
```
- **Ne Yapar?** File Server Remote VSS Protocol (FssagentRpc) arayüzünün hedefte aktif olup olmadığını kontrol eder.
- **Ne Zaman Kullanılır?** Windows dosya sunucularından NTLM kimlik doğrulamasını tetiklemek için.

### 6.7 Pass-the-Hash (NTLM Hash) ile Kimlik Doğrulamalı RPC Dökümü
```bash
impacket-rpcdump -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 CORP/Administrator@192.168.1.10
```
- **Ne Yapar?** Düz parola bilmeden ele geçirilen NT hash ile oturum açar ve yetkili RPC uç noktalarını döker.
- **Ne Zaman Kullanılır?** TCP 135 doğrudan anonim erişime kapalı olduğunda SMB üzerinden hash ile erişim sağlamak için.
- **Parametreler:** `-hashes` (`:NTHASH` formatında NTLM hash).

### 6.8 Kerberos Bileti ile Parolasız ve Sessiz RPC Taraması
```bash
export KRB5CCNAME=/tmp/admin.ccache
impacket-rpcdump -k -no-pass dc01.corp.local
```
- **Ne Yapar?** NTLM yerine ccache Kerberos biletini kullanarak FQDN üzerinden hedef sisteme bağlanır ve RPC servislerini döker.
- **Ne Zaman Kullanılır?** NTLM trafiğinin kesinlikle yasak olduğu veya izlendiği ortamlarda OPSEC standartlarına uygun keşif yapmak için.
- **Parametreler:** `-k` (Kerberos kullanımı zorlar), `-no-pass` (Parola sormaz).

### 6.9 Doğrudan SMB Adlandırılmış Boru Hattı ile EPM Sorgulama
```bash
rpcdump.py ncacn_np:192.168.1.10[\pipe\epmapper]
```
- **Ne Yapar?** TCP 135 portuna hiç dokunmadan, SMB 445 kanalı içerisindeki `\pipe\epmapper` borusu üzerinden Endpoint Mapper dökümü alır.
- **Ne Zaman Kullanılır?** Güvenlik duvarı TCP 135'i engellemiş ancak SMB (TCP 445) bağlantısına izin vermişse.

### 6.10 Çıktıyı Dosyaya Kaydederek Servis Yorumlarını Hızlıca Listeleme
```bash
impacket-rpcdump 192.168.1.10 > /tmp/rpcdump.txt && grep "Comment:" /tmp/rpcdump.txt | sort -u
```
- **Ne Yapar?** Hedefteki tüm RPC dökümünü bir metin dosyasına kaydeder ve kaydedilen dosyadan yalnızca benzersiz servis açıklamalarını ayıklar.
- **Ne Zaman Kullanılır?** Hedef sistemde çalışan servislerin hızlı özetini tek bakışta görmek ve raporlamak için.

---

## Kaynaklar

| Kaynak | Bağlantı |
|---|---|
| Impacket rpcdump.py Kaynak Kodu | [github.com/fortra/impacket](https://github.com/fortra/impacket/blob/main/examples/rpcdump.py) |
| MS-EPM Protokol Spesifikasyonu | [Microsoft Docs](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-epm/) |
| MITRE ATT&CK T1046 | [attack.mitre.org](https://attack.mitre.org/techniques/T1046/) |
| Microsoft RPC Endpoint Mapper Port Gereksinimleri | [Microsoft Support](https://docs.microsoft.com/en-us/troubleshoot/windows-server/networking/service-overview-and-network-port-requirements) |
| HackTricks — Pentesting RPC & EPM | [book.hacktricks.wiki](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-rpc.html) |

---

> **Önceki:** [← rpcclient](./rpcclient.md) · **Sonraki:** [impacket-samrdump →](./impacket-samrdump.md)
