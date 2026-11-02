# LdapRelayScan

> **Kategori:** [5. NTLM ve Kerberos Relay Motorları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Etki Alanı Denetleyicilerinin (Domain Controllers) NTLM relay saldırılarına karşı güvenliğini doğrulamak amacıyla LDAP İmzalama (LDAP Signing) ve LDAPS Kanal Bağlama (Channel Binding Tokens - CBT / EPA) politikalarını kimlik doğrulamalı veya parolasız olarak denetleyen güvenlik tarama aracı.

---

## 1. Genel Bakış ve Amaç

Active Directory ortamlarında gerçekleştirilen NTLM Relay saldırılarının en yıkıcı hedeflerinden biri LDAP ve LDAPS servisleridir. Bir etki alanı denetleyicisine yapılan LDAP relay saldırısı sayesinde saldırganlar yeni kullanıcı oluşturabilir, mevcut kullanıcıların parolalarını sıfırlayabilir veya bilgisayar hesaplarına Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD) tanımlayabilir.

Microsoft, bu saldırıları engellemek için iki temel savunma mekanizması sunar:
1. **LDAP Server Signing:** Düz metin LDAP (TCP 389) trafiğinde NTLM kimlik doğrulamasının kriptografik olarak imzalanmasını zorunlu kılar.
2. **LDAPS Channel Binding (CBT / EPA):** SSL/TLS şifreli LDAPS (TCP 636) oturumlarında istemci ile sunucu arasındaki TLS tüneli ile NTLM kimlik doğrulamasını birbirine bağlar (Gss-Channel-Binding). Relay yapıldığında TLS tüneli saldırganda sonlandığı için DC bu isteği `SEC_E_BAD_BINDINGS (0x80090346)` hatasıyla reddeder.

**`LdapRelayScan`** (zyn3rgy tarafından geliştirilen), bir sızma testi veya kırmızı takım tatbikatında hedef DC'lerin LDAP relay saldırılarına açık olup olmadığını operasyon öncesinde güvenli ve sessiz bir şekilde test etmeyi sağlar. Araç, LDAPS testini **hiçbir kimlik bilgisi gerektirmeden (unauthenticated)** yapabilir; LDAP imzalama testi için ise standart bir domain kullanıcısının kimlik bilgilerini kullanır.

### Mimari Akış Şeması

```
[ Saldırgan / Güvenlik Uzmanı ]                       [ Domain Controller (DC01) ]
             │                                                       │
             ├─── (1) LDAPS (Port 636) TLS Handshake ───────────────►│
             │                                                       │
             ├─── (2) Sahte / Hatalı Channel Binding NTLM Paketi ───►│ (SEC_E_BAD_BINDINGS Testi)
             │                                                       │
             │◄── (3) DC Yanıtı: Kabul / 80090346 Hatası ────────────┤
             │                                                       │
             │   [ Analiz Sonucu: CBT Durumu ]                       │
             │   - "Never" (Relay Mümkün! Zafiyet Var)               │
             │   - "When Supported" (Downgrade ile Relay Mümkün!)    │
             │   - "Always" (Tam Koruma - Relay Engellendi)          │
             │                                                       │
             ├─── (4) Düz LDAP (Port 389) Basit NTLM Bind ──────────►│
             │                                                       │
             │◄── (5) DC Yanıtı: result_code = 8 (strongerAuthReq) ──┤
             │                                                       │
             ▼   [ Analiz Sonucu: LDAP Signing Durumu ]              │
         [ Rapor: LDAP Signing = False -> Relay Uygulanabilir! ]     ▼
```

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
python3 LdapRelayScan.py -method <LDAPS|BOTH> -dc-ip <DC_IP> [KİMLİK SEÇENEKLERİ]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-method` | Tarama modu: `LDAPS` (Kimliksiz CBT testi) veya `BOTH` (İmzalama + CBT testi) | `-method BOTH` |
| `-dc-ip` | Hedef Etki Alanı Denetleyicisinin IPv4 adresi | `-dc-ip 10.0.0.10` |
| `-u / --username` | LDAP signing testi için etki alanı kullanıcı adı | `-u jdoe` |
| `-p / --password` | Kullanıcı parolası | `-p 'P@ssw0rd123'` |
| `-nthash` | Parola yerine NT hash kullanımı (Pass-the-Hash) | `-nthash 58a478e...` |
| `-timeout` | Bağlantı zaman aşımı süresi (saniye) | `-timeout 10` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Parolasız / Kimliksiz LDAPS Channel Binding Denetimi

Ortamda hiçbir etki alanı hesabına sahip olunmadığı durumlarda DC'nin LDAPS relay'e açık olup olmadığını test etme:

```bash
# Sadece LDAPS tüneli üzerinden Channel Binding durumunu sorgulama
python3 LdapRelayScan.py -method LDAPS -dc-ip 10.0.0.10
```

*Çıktı Analizi:*
```text
[*] Testing LDAPS Channel Binding on 10.0.0.10:636...
[-] LDAPS Channel Binding: NOT ENFORCED (Policy: Never)
[!] CRITICAL: Target DC is VULNERABLE to LDAPS NTLM Relaying! (CVE-2021-36942 / PetitPotam)
```

---

### Senaryo 2: Standart Kullanıcı ile Tam Denetim (LDAP Signing + LDAPS CBT)

```bash
# Hem Port 389 imzalama hem Port 636 kanal bağlama politikalarını doğrulama
python3 LdapRelayScan.py -method BOTH -dc-ip 10.0.0.10 -u standard_user -p 'Welcome2026!'
```

*Çıktı Analizi:*
```text
[*] Connecting to LDAP (389)...
[-] LDAP Server Signing: NOT REQUIRED (Policy: None) -> VULNERABLE
[*] Connecting to LDAPS (636)...
[+] LDAPS Channel Binding: ENFORCED (Policy: Always / result: 80090346) -> PROTECTED
[!] Summary: Port 389 Relay is POSSIBLE. Port 636 Relay is BLOCKED.
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `SEC_E_BAD_BINDINGS (80090346)` | DC tarafında Channel Binding Token (CBT) başarıyla devrededir; sahte paket reddedildi. | Bu bir hata değil, DC'nin korunduğunu gösteren beklenen yanıttır. Port 389 imzalama durumunu kontrol edin. |
| `resultCode: 8 (strongerAuthRequired)` | DC'de LDAP imzalama zorunludur; imzasız basit NTLM bind kabul edilmez. | DC'ye NTLM relay yapılamaz; Kerberos veya imzalı bağlantı gerekir. |
| `Connection timed out on port 636` | Hedef DC üzerinde LDAPS sertifikası yüklü değildir veya TCP 636 güvenlik duvarında kapalıdır. | DC üzerinde AD CS veya 3. parti sunucu sertifikası olduğunu doğrulayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler
* **Directory Service Event ID 2886 & 2887:** DC olay günlüklerinde imzasız LDAP bağlantılarının gerçekleştiğine dair özet uyarı kayıtları.
* **Security Event ID 4625:** Kanal bağlama hatası nedeniyle reddedilen oturum açma denemeleri (`Status: 0xC000006D, SubStatus: 0xC000035B`).

### 5.2 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **[T1046](https://attack.mitre.org/techniques/T1046/)** | Network Service Discovery | LDAP servis güvenlik seviyelerinin taranması. |
| **[T1557.001](https://attack.mitre.org/techniques/T1557/001/)** | Adversary-in-the-Middle: LLMNR/NBT-NS and NTLM Relay | Relay uygulanabilirlik testi. |

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```bash
# 1. Parolasız hızlı LDAPS kanal bağlama testi
python3 LdapRelayScan.py -method LDAPS -dc-ip 10.0.0.10

# 2. Kimlik bilgisi ile hem LDAP hem LDAPS denetimi
python3 LdapRelayScan.py -method BOTH -dc-ip 10.0.0.10 -u jdoe -p 'P@ss!'

# 3. NT Hash ile Pass-the-Hash denetimi
python3 LdapRelayScan.py -method BOTH -dc-ip 10.0.0.10 -u admin -nthash 58a478e...

# 4. Docker konteyneri üzerinden çalıştırma
docker run --rm -it zyn3rgy/ldaprelayscan -method BOTH -dc-ip 10.0.0.10 -u guest -p ''
```

---

## Kaynaklar
- [GitHub — LdapRelayScan (zyn3rgy)](https://github.com/zyn3rgy/LdapRelayScan)
- [Microsoft KB4520412 — 2020 LDAP channel binding and LDAP signing requirements for Windows](https://support.microsoft.com/)

---

> **Önceki:** [← lsarelayx](./lsarelayx.md) · **Sonraki:** [impacket-ntlmrelayx →](./impacket-ntlmrelayx.md)
