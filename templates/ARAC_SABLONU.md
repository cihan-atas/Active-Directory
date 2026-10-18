# [Araç Adı]

> **Kategori:** [Kategori Numarası ve Adı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)  
> **Tanım:** [Tek cümlelik net operasyonel tanım; aracın Active Directory ortamındaki birincil misyonu].

---

## 1. Genel Bakış ve Amaç

[Aracın ne olduğu, çalışma prensibi, Active Directory ortamında hangi protokolleri (SMB, LDAP, Kerberos, RPC, WMI, WinRM vb.) kullandığı ve neden tercih edildiği detaylıca açıklanır.]

### 1.1 Mimari Akış Şeması
```text
+-----------------------+        Protokol (Port)        +------------------------+
|   Saldırgan Makine    | ----------------------------> | Hedef Domain Controller |
|    ([arac_adi])       | <---------------------------- |       (192.168.1.10)   |
+-----------------------+         Kimlik / Veri         +------------------------+
```

### 1.2 Neden Önemli ve Kullanım Senaryoları
| Senaryo / Aşama | Operasyonel Amaç | Beklenen Çıktı / Fayda |
|-----------------|------------------|------------------------|
| Keşif ve Numaralandırma | Hedef etki alanındaki nesneleri haritalandırma | Kullanıcı, grup, bilgisayar ve SPN listesi |
| Yetki Yükseltme | Zafiyetli konfigürasyonları tespit etme | Yanal hareket ve yerel yönetici erişimi |
| Kalıcılık (Persistence) | Ortamda tespit edilmeden barınma | Bilet sahteleme ve yetkili hesap oluşturma |

### 1.3 Alternatif Araçlarla Karşılaştırma
| Özellik / Kriter | [Bu Araç] | Alternatif Araç 1 | Alternatif Araç 2 |
|------------------|-----------|-------------------|-------------------|
| Protokol Desteği | SMB, RPC | LDAP | WMI |
| OPSEC Gürültüsü | Orta / Düşük | Düşük | Yüksek |
| Kimlik Doğrulama | Kerberos / NTLM | NTLM | Kerberos |
| Platform Desteği | Linux / Windows | Yalnızca Linux | Yalnızca Windows |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

Genel çalıştırma formatı:
```bash
arac_adi [ana_secenekler] -u 'Kullanici' -p 'Parola' -d 'DOMAIN' <HEDEF_IP>
```

### Desteklenen Kritik Bayraklar
| Parametre | Uzun Ad / Alternatif | Açıklama | Örnek Değer |
|-----------|----------------------|----------|-------------|
| `-u` | `--username` | Kimlik doğrulamada kullanılacak kullanıcı adı | `Administrator` |
| `-p` | `--password` | Kimlik doğrulamada kullanılacak parola | `Password123!` |
| `-H` | `--hashes` | Pass-the-Hash için NTLM hash (`LM:NT`) | `aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0` |
| `-d` | `--domain` | Hedef Active Directory etki alanı (FQDN veya NetBIOS) | `corp.local` |
| `-k` | `--kerberos` | NTLM yerine Kerberos kimlik doğrulaması kullan (Ccache) | *Bayrak (değersiz)* |
| `-oA` | `--output-all` | Sonuçları tüm formatlarda (JSON, TXT, CSV) kaydet | `/opt/loot/scan_result` |

---

## 3. Pratik Komut Örnekleri

### 3.1 Anonim / Null Session Keşfi
```bash
arac_adi -u '' -p '' -d 'corp.local' 192.168.1.10 --enum-shares
```
*Açıklama:* Parolasız oturum açarak etki alanında anonim erişime açık paylaşımları ve izinleri denetler.

### 3.2 Etki Alanı Kullanıcısı ile Yetkili Numaralandırma
```bash
arac_adi -u 'jdoe' -p 'Winter2024!' -d 'corp.local' 192.168.1.10 --all-objects
```
*Açıklama:* Geçerli bir domain kullanıcısının haklarıyla dizin veritabanındaki tüm nesneleri kısıtlamasız çeker.

### 3.3 Pass-the-Hash (PtH) ile Parolasız Erişim
```bash
arac_adi -u 'Administrator' -H '31d6cfe0d16ae931b73c59d7e0c089c0' -d 'corp.local' 192.168.1.10 --exec 'whoami'
```
*Açıklama:* Açık metin parola olmadan yalnızca NT hash kullanarak hedef sistemde komut çalıştırır.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Neden | Kesin Çözüm Adımı |
|-------------|-------------|-------------------|
| `STATUS_LOGON_FAILURE` | Yanlış kullanıcı adı, parola veya kilitli hesap | Kimlik bilgilerini ve hesap durumunu doğrulayın; domain adının doğruluğunu teyit edin. |
| `STATUS_ACCESS_DENIED` | Kullanıcının hedef nesneye veya RPC/SMB servisine erişim yetkisi yok | Daha yetkili bir hesapla tekrar deneyin veya alternatif protokolleri (LDAP/WinRM) test edin. |
| `KRB_AP_ERR_SKEW` | Yerel makine saati ile DC saati arasında 5 dakikadan fazla fark var | `rdate -n <DC_IP>` veya `ntpdate <DC_IP>` komutuyla saat senkronizasyonu yapın. |
| `Connection timed out` | Hedef makine kapalı, IP yanlış veya güvenlik duvarı portu engelliyor | `nmap -Pn -p <port> <DC_IP>` ile port erişilebilirliğini test edin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler ve Olay Günlükleri (Event Logs)
- **Windows Security Event ID 4624:** Başarılı oturum açma (Logon Type 3 - Network).
- **Windows Security Event ID 4625:** Başarısız oturum açma denemesi (Kaba kuvvet tespiti).
- **Windows Security Event ID 5140 / 5145:** Ağ paylaşım nesnesine erişim veya ayrıntılı dosya izin denetimi.
- **Sysmon Event ID 1:** İşlem başlatma (Process Creation - komut satırı argümanları).

### 5.2 Ağ ve EDR İmzaları
- Anormal miktarda RPC veya SMB çağrısı SOC/SIEM alarmlarını tetikleyebilir.
- Varsayılan user-agent veya statik paket bayrakları EDR tarafından kolayca yakalanır.

### 5.3 MITRE ATT&CK Eşleştirmesi
| Teknik ID | Teknik Adı | Kullanım Amacı |
|-----------|------------|----------------|
| `T1087.002` | Account Discovery: Domain Account | Etki alanı kullanıcılarını listeleme |
| `T1069.002` | Permission Groups Discovery: Domain Groups | Domain Admins ve ayrıcalıklı grupları keşfetme |
| `T1078` | Valid Accounts | Ele geçirilen geçerli hesaplarla oturum açma |

### 5.4 OPSEC Önerileri
| Risk Seviyesi | Risk Tanımı | Operasyonel Önlem |
|---------------|-------------|-------------------|
| Yüksek | Yüksek frekanslı seri istekler | Gecikme süresi (`--delay` / jitter) ekleyerek istekleri zamana yayın. |
| Orta | Varsayılan komut satırı izleri | Wrapper betikler veya pipe üzerinden parola iletimi tercih edin. |
| Düşük | Kerberos bilet izleri | Ccache biletlerini kullandıktan sonra temizleyin (`kdestroy`). |

### 5.5 Savunma Karşılığı (Blue Team)
- Kısıtlayıcı SMB ve LDAP imzalama (`SMB Signing`, `LDAP Signing & Channel Binding`) zorunlu kılınmalıdır.
- Anonim numaralandırma (`RestrictAnonymous = 1` veya `2`) kayıt defterinde aktif edilmelidir.
- Ayrıcalıklı hesapların standart iş istasyonlarına oturum açması kısıtlanmalıdır (Tiered Administration).

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

### 1. Anonim Paylaşım ve Kullanıcı Taraması
```bash
arac_adi -u '' -p '' -d 'corp.local' 192.168.1.10 --enum-all
```
**Ne Yapar?**  
Hedef sistemde anonim (null) oturum açarak şifresiz erişilebilen kullanıcı hesaplarını, paylaşımları ve temel domain ilkelerini numaralandırır.  
**Ne Zaman Kullanılır?**  
İç ağ sızma testinin ilk keşif aşamasında, elimizde hiçbir geçerli kullanıcı kimlik bilgisi bulunmadığında.  
**Parametreler:**  
- `-u ''`: Boş kullanıcı adı ile anonim oturum başlatır.  
- `-p ''`: Boş parola gönderir.  
- `-d 'corp.local'`: Hedef Active Directory NetBIOS / FQDN etki alanını tanımlar.  
- `--enum-all`: Desteklenen tüm temel numaralandırma kontrollerini sırayla yürütür.  

---

### 2. Etki Alanı Kullanıcısı ile Tam Dizin Dökümü
```bash
arac_adi -u 'Administrator' -p 'Password123!' -d 'corp.local' 192.168.1.10 -oA /opt/loot/dc_dump
```
**Ne Yapar?**  
Yetkili veya standart bir etki alanı kullanıcısıyla DC üzerinde oturum açarak tüm kullanıcı, grup, parola ilkesi ve paylaşım veritabanını çıkarır; sonuçları diskte arşivler.  
**Ne Zaman Kullanılır?**  
İlk geçerli hesap ele geçirildiğinde, etki alanının tüm varlık haritasını tek seferde çıkarmak için.  
**Parametreler:**  
- `-u 'Administrator'`: Kimlik doğrulamada kullanılacak kullanıcı hesabı.  
- `-p 'Password123!'`: Kullanıcıya ait açık metin parola.  
- `-d 'corp.local'`: Hedef etki alanı adı.  
- `-oA /opt/loot/dc_dump`: Çıktıları TXT, JSON ve YAML formatlarında arşiv dosyasına kaydeder.  

---

### 3. Pass-the-Hash ile Parolasız Oturum Doğrulama
```bash
arac_adi -u 'Administrator' -H 'aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0' -d 'corp.local' 192.168.1.10 --check
```
**Ne Yapar?**  
Açık metin parolaya ihtiyaç duymadan, dump edilen NT/LM hash değerini kullanarak hedef sistemde NTLM kimlik doğrulamasını tamamlar.  
**Ne Zaman Kullanılır?**  
LSASS bellek dökümünden veya SAM/NTDS.dit dosyasından hash elde edildiğinde kırma (cracking) işlemine gerek kalmadan doğrudan erişim sağlamak için.  
**Parametreler:**  
- `-u 'Administrator'`: Hedef sistemde test edilecek kullanıcı hesabı.  
- `-H 'LM:NT'`: Pass-the-Hash için kullanılacak NTLM hash ikilisi.  
- `-d 'corp.local'`: Hedef etki alanı.  
- `--check`: Oturumun geçerli olup olmadığını kontrol edip bağlantıyı sonlandırır.  

---

### 4. Kerberos Ticket (Ccache) ile Bilet Tabanlı Bağlantı
```bash
KRB5CCNAME=/tmp/admin.ccache arac_adi -k -no-pass -d 'CORP.LOCAL' dc01.corp.local
```
**Ne Yapar?**  
NTLM yerine Kerberos protokolünü kullanarak, önceden elde edilmiş veya sahtelenmiş (Golden/Silver Ticket) bilet dosyasını belleğe yükler ve hedefe bağlanır.  
**Ne Zaman Kullanılır?**  
NTLM ağ trafiği devre dışı bırakıldığında veya Pass-the-Ticket (PtT) teknikleri uygulandığında.  
**Parametreler:**  
- `KRB5CCNAME=/tmp/admin.ccache`: Kullanılacak Kerberos bilet dosyasının yolu.  
- `-k`: Kimlik doğrulamasında Kerberos biletini zorunlu kılar.  
- `-no-pass`: Parola sormasını engeller; yalnızca bileti kullanır.  
- `-d 'CORP.LOCAL'`: Kerberos Realm / FQDN etki alanı adı.  

---

## Kaynaklar
- Resmi Proje Deposu: [GitHub Linki](https://github.com/...)
- Microsoft Dökümantasyonu: [Active Directory Technical Documentation](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/)
- MITRE ATT&CK: [Active Directory Tactics & Techniques](https://attack.mitre.org/)

---

> **Önceki:** [← Önceki Araç](./arac_onceki.md) · **Sonraki:** [Sonraki Araç →](./arac_sonraki.md)
