# ⚔️ Active Directory Saldırı Yaşam Döngüsü ve Operasyonel Oyun Kitabı (Playbook)

> **Kapsam:** 🔴 Red Team (Saldırı & Tehdit Analizi) · **Modül Eşleşmesi:** [Modül 01 - 10](../3-Red_Team/) & [Modül 11 (145 Araçlık Cephanelik)](./Modul_11_Arac_Ustaligi_ve_Komut_Notlari/README.md)
> **Amaç:** 10 modüldeki teorik ve pratik tekniklerin gerçek dünya sızma testlerinde ve yetkili güvenlik tatbikatlarında nasıl uçtan uca zincirlendiğini (Attack Chain) göstermek.
> ⚠️ **Etik ve Yasal Sınır (§6):** Bu oyun kitabı yalnızca **yetkili sızma testi, kırmızı takım tatbikatları ve laboratuvar eğitimleri** içindir.

---

## 1. Giriş: Kill Chain ve Operasyonel Yaklaşım

Active Directory sızma testlerinde başarı, rastgele araç çalıştırmakla değil; etki alanının mimarisini, güven sınırlarını ve savunma telemetrisini anlayarak **doğru teknikleri doğru sırayla zincirlemekle** elde edilir.

```
[Faz 1: Keşif] ──▶ [Faz 2: İlk Erişim] ──▶ [Faz 3: Numaralandırma] ──▶ [Faz 4: Yanal Hareket] ──▶ [Faz 5: Yükseltme & Hakimiyet]
   (Modül 01)         (Modül 02)              (Modül 01/03)                (Modül 04/08)              (Modül 05/06/07/09/10)
```

---

## 2. Senaryo A: Sıfır Bilgi / İç Ağ Erişimi (Black-Box Internal)

Bu senaryoda saldırgan fiziksel veya VPN üzerinden iç ağa erişmiştir; ancak hiçbir etki alanı kullanıcı adı veya parolasına sahip değildir.

```
       [İç Ağa Bağlantı (Kimliksiz)]
                    │
                    ▼
       1. Pasif Ağ Dinleme & Poisoning (Modül 02.1)
          - Responder ile LLMNR / NBT-NS trafiğini yakala
          - Araç: Responder (Modül 11 Kat 01)
          - Alternatif: mitm6 ile IPv6 DNS trafiğini ele geçir (Modül 11 Kat 01)
                    │
                    ▼
       2. NTLMv2 Karması / LDAP Relay (Modül 08.1)
          - Yakalanan NTLMv2 karmasını çevrimdışı kır (Hashcat / John - Modül 11 Kat 12)
          - VEYA LDAP imzasız ise ntlmrelayx ile doğrudan LDAP'a relay et (Modül 11 Kat 10)
                    │
                    ▼
       3. İlk Etki Alanı Kimliği (Foothold) (Modül 02.4)
          - Standart kullanıcı (jdoe) elde edildi
          - NetExec ile kimlik doğrula: nxc smb/ldap (Modül 11 Kat 03)
                    │
                    ▼
       4. Graf Tabanlı Saldırı Yolu Analizi (Modül 01.2)
          - SharpHound / BloodHound CE ile etki alanı haritasını çıkar (Modül 11 Kat 04)
          - En kısa DA (Domain Admin) yolunu Cypher sorgularıyla tespit et
                    │
                    ▼
       5. AD CS Zafiyet Sömürüsü (Modül 07.1 - ESC1)
          - Certipy find ile ESC1 şablonunu keşfet (Modül 11 Kat 09)
          - SAN=Administrator içeren sertifika talep et
                    │
                    ▼
       6. Etki Alanı Hakimiyeti (Modül 09.1 / 09.2)
          - PKINIT ile DA TGT al ──▶ DCSync ile krbtgt anahtarını çek (secretsdump - Modül 11 Kat 06)
          - Diamond Ticket ile tespit izi düşük kalıcılık kur (Rubeus - Modül 11 Kat 08)
```

---

## 3. Senaryo B: Varsayılan İhlal (Assumed Breach / Kurumsal Kimlik)

Bu senaryoda saldırgan bir oltalama (phishing) veya ele geçirilmiş kurumsal bilgisayar üzerinden düşük yetkili bir etki alanı hesabına (`ayilmaz`) zaten sahiptir.

```
       [Düşük Yetkili Hesap: ayilmaz]
                    │
                    ▼
       1. Çevrimdışı Kimlik Avı (Modül 03.1)
          - GetUserSPNs ile Kerberoasting (Servis hesaplarını hedefle - Modül 11 Kat 06)
          - GetNPUsers ile AS-REP Roasting (DONT_REQ_PREAUTH taraması - Modül 11 Kat 06)
          - Hashcat ile svc_sql parolasını çöz: 'Summer2024!' (Modül 11 Kat 12)
                    │
                    ▼
       2. ACL ve Yetki Devri Keşfi (Modül 05.1 / 05.2)
          - PowerView / BloodHound ile incele: svc_sql hesabının BACKUP-SRV bilgisayarı
            üzerinde GenericWrite yetkisi var (Modül 11 Kat 05)
                    │
                    ▼
       3. RBCD Tabanlı Yetki Yükseltme (Modül 06.3)
          - Standart makine kotası (MAQ) ile EVILPC$ makine hesabı oluştur (addcomputer.py)
          - BACKUP-SRV'nin msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğine EVILPC$ ekle
          - S4U2proxy ile BACKUP-SRV üzerinde Administrator adına servis bileti al (Rubeus / getST)
                    │
                    ▼
       4. Yerel SYSTEM ve LSASS Hasadı (Modül 03.2 / 04.3)
          - WMI / PsExec / WinRM ile BACKUP-SRV'ye bağlan (Modül 11 Kat 11)
          - LSASS bellek görüntüsünden (nanodump / procdump / comsvcs - Modül 11 Kat 07)
            oturum açmış Tier-1 Yöneticisinin NT karmasını çek
                    │
                    ▼
       5. Forest ve Domain Kalıcılığı (Modül 09.3 / 10.1)
          - Tier-0 erişimiyle DCShadow üzerinden izsiz sidHistory ekle (Mimikatz)
          - DSRM arka kapısını yapılandır ve çift KRBTGT döngüsü planla
```

---

## 4. Senaryo C: AD CS Web Enrollment Koersiyon ve NTLM Relay Zinciri (ESC8)

Bu senaryoda etki alanında HTTP Web Enrollment (`certsrv`) açıktır ve NTLM kimlik doğrulama zorlaması (EPA) yapılmamıştır.

```
       [Saldırgan Makinesi]
               │
               ▼
       1. Dinleyici Hazırla (Modül 08.1 / 08.3):
          - ntlmrelayx.py -t http://ca.corp.local/certsrv/certfnsh.asp --template DomainController
               │
               ▼
       2. Koersiyon Tetikle (Modül 08.2):
          - PetitPotam (EfsRpcOpenFileRaw) veya Coercer / PrinterBug ile DC01$'ı zorla
          - DC01$ makinesi SMB üzerinden saldırgana kimlik doğrulamaya çalışır
               │
               ▼
       3. HTTP Üzerinden AD CS'e Relay Et (Modül 07.1 / 08.3):
          - ntlmrelayx gelen NTLM oturumunu CA Web arayüzüne iletir
          - CA, DC01$ adına makine sertifikası üretir (base64 certificate + private key)
               │
               ▼
       4. PKINIT ile Kerberos TGT Alma (Modül 07.3):
          - Certipy auth -pfx dc01.pfx -dc-ip <DC_IP>
          - DC01$ makine hesabı adına Kerberos TGT ve NT karma alınır
               │
               ▼
       5. DCSync ile Tam Hakimiyet (Modül 09.1):
          - secretsdump.py corp.local/'DC01$'@<DC_IP> -hashes :<dc01_nt_hash> -just-dc-user krbtgt
```

---

## 5. Senaryo D: ACL Abuse ve Shadow Credentials Zinciri

Bu senaryoda saldırgan bir kullanıcı veya makine üzerinde `GenericAll`, `GenericWrite` veya `WriteProperty` (özellikle `msDS-KeyCredentialLink`) yetkisine sahiptir. Parola sıfırlamadan (OPSEC dostu) kimlik ele geçirilir.

```
       [Ele Geçirilmiş Hesap / Hak: GenericWrite on TargetUser]
                    │
                    ▼
       1. ACL İncelemesi (Modül 05.1):
          - PowerView: Get-DomainObjectAcl -Identity TargetUser -ResolveGUIDs
          - TargetUser nesnesinde msDS-KeyCredentialLink yazma hakkı teyit edilir
                    │
                    ▼
       2. Shadow Credentials Enjeksiyonu (Modül 05.4):
          - pywhiskey / Whisker ile asimetrik RSA anahtar çifti üret
          - TargetUser'ın msDS-KeyCredentialLink özniteliğine KeyCredential blob'u yaz
                    │
                    ▼
       3. PKINIT Ön Kimlik Doğrulama (Modül 07.3 / 11 Kat 09):
          - Üretilen özel anahtarla KDC'ye PKINIT isteği gönder
          - TargetUser adına TGT ve NT hash doğrudan bellekten çekilir
                    │
                    ▼
       4. İz Temizliği (OPSEC):
          - Alınan TGT ile iş bittiğinde pywhiskey -action clear ile eklenen anahtar silinir
```

---

## 6. Kerberos ve Active Directory Hata Çözüm Matrisi (Troubleshooting)

Operasyonlar sırasında araçların ürettiği hata kodları, kök nedenleri ve sahada kanıtlanmış çözüm adımları:

| Hata Kodu | Protokol Anlamı | Kök Neden | Saha Çözümü (Remediation) |
|---|---|---|---|
| `KRB_AP_ERR_SKEW (0x25)` | Clock skew too great | Saldırı makinesi ile KDC arasındaki saat farkı **5 dakikadan fazladır**. | `rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` komutu ile saldırı makinesinin saatini etki alanı denetleyicisine eşitleyin. |
| `KDC_ERR_ETYPE_NOSUPP (0x0e)` | KDC has no support for encryption type | Talep edilen şifreleme türü (genellikle RC4 - etype 23) KDC üzerinde tamamen kapatılmıştır. | Araca `--aes` veya `/enctype:aes256` parametresi ekleyerek AES bilet talep edin; hash kırma işlemini Hashcat mod 19700'e aktarın. |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN (0x07)` | Server not found in Kerberos database | Talep edilen SPN veya hedef makine FQDN formatında değildir ya da silinmiştir. | IP adresi yerine tam FQDN (`cifs/target01.corp.local`) kullanın; `/etc/hosts` dosyanızda DNS çözümlemesini doğrulayın. |
| `KDC_ERR_C_PRINCIPAL_UNKNOWN (0x06)` | Client not found in Kerberos database | Bilet talep edilen kullanıcı adı etki alanında mevcut değildir ya da yanlış realm belirtilmiştir. | Realm adını BÜYÜK HARFLERLE (`CORP.LOCAL`) yazın; kullanıcı sAMAccountName değerini LDAP üzerinden teyit edin. |
| `KDC_ERR_POLICY (0x0c)` | KDC policy rejects request | Hedef hesap **Protected Users** grubundadır veya yetki devrine kapatılmıştır (`Cannot be delegated`). | S4U delegasyonu veya taklit (impersonation) için o kullanıcı yerine Protected Users grubunda olmayan başka bir yetkili seçin. |
| `KDC_ERR_BADOPTION (0x0d)` | KDC cannot accommodate requested option | S4U2proxy isteğinde bilet iletim (Forwardable) bayrağı eksiktir. | Bilet talep ederken `/forwardable` bayrağının açık olduğundan emin olun; RBCD hedef SPN'ini kontrol edin. |
| `KDC_ERR_CLIENT_REVOKED (0x12)` | Client credentials have been revoked | Kimlik bilgisi kullanılan hesap kilitlenmiş, süresi dolmuş veya devre dışı bırakılmıştır. | Parola püskürtmeyi (Password Spray) durdurun; hesap kilitlenme süresini LDAP üzerinden kontrol edin. |
| `0x00000005 (ACCESS_DENIED)` | Access Denied | LSASS üzerinde **RunAsPPL** etkindir ya da EDR kernel seviyesinde handle engellemektedir. | LSASS'a doğrudan bağlanmak yerine kayıt defteri kovanlarını (`reg save SAM/SYSTEM`) yedekleyin veya Shadow Credentials yoluna gidin. |
| `STATUS_LOGON_TYPE_NOT_GRANTED` | Logon failure: user not granted requested logon type | Hesabın RDP (Logon 10) veya yerel oturum açma (Logon 2) yetkisi engellenmiştir (GPO kısıtlaması). | WMI (Logon 3 - Network) veya WinRM (Logon 3) protokolleri üzerinden komut yürütmeyi deneyin. |

---

## 7. Operasyonel Güvenlik (OPSEC) Altın Kuralları

1. **Gürültülü Ağ Taramalarından Kaçının:**
   Etki alanında port taraması (`nmap -p-`) yapmak SIEM ve NDR sistemlerinde anında alarm üretir. Bunun yerine tek bir TCP/389 (LDAP) sorgusu ile tüm etki alanı bilgisayar listesini (`operatingSystem`, `dNSHostName`) çekin.
2. **Kullanıcı Hesabı Kilitleme Riskini Yönetin:**
   Parola püskürtme (Password Spray) yapmadan önce mutlaka etki alanının kilitlenme politikasını (`lockoutThreshold`, `lockoutDuration`, `resetLockoutCount`) sorgulayın. Eşik değerinin en az yarısı kadar güvenli aralıklarla deneyin.
3. **Diske Dosya Bırakmayın (Living off the Land):**
   Hedef sistemlere derlenmiş üçüncü taraf `.exe` araçları yüklemek yerine, Windows yerleşik LOLBin'lerini (`rundll32`, `certutil`, `wmic`, `powershell`) veya bellek içi yükleyicileri (`execute-assembly`) kullanın.
4. **Bilet Sürelerini Gerçekçi Tutun:**
   Golden veya Silver bilet üretirken 10 yıllık bilet basmayın; ortamın standart Kerberos bilet ömrü olan **10 saat** parametresini (`/duration:10`) verin.
5. **İzleri Düzenli Temizleyin:**
   RBCD ile eklenen sahte makine hesaplarını engagement sonunda silin; `AdminSDHolder` veya `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliklerini orijinal hallerine döndürün (`flush`).

---

## ⚖️ YASAL UYARI VE SORUMLULUK REDDİ (DISCLAIMER)

> **ÖNEMLİ:** Bu oyun kitabında yer alan tüm saldırı zincirleri, araç parametreleri ve operasyon senaryoları; **yalnızca yasal yetkilendirme belgesi bulunan sızma testleri, kırmızı takım tatbikatları ve laboratuvar eğitimleri** için tasarlanmıştır.
>
> Yazılı izin olmaksızın herhangi bir kurumsal ağ üzerinde bu tekniklerin uygulanması TCK Madde 243-245 ve ilgili siber suç yasaları uyarınca ağır cezai yaptırımlara tabidir. Proje yazarları materyalin yetkisiz kullanımından doğacak zararlardan sorumlu tutulamaz.

---

## 🌐 Yararlanılan Başlıca Açık Kaynaklar

- 🌐 [InternalAllTheThings — Swisskyrepo (Active Directory)](https://swisskyrepo.github.io/InternalAllTheThings/active-directory/): Bütünleşik AD sömürü senaryoları ve referans komutlar.
- 🌐 [HackTricks Wiki — Carlos Polop (Pentesting Active Directory)](https://book.hacktricks.wiki/): Genişletilmiş metodolojiler, ayrıcalık yükseltme ve yanal hareket matrisi.
- 🌐 [The Hacker Recipes — Shutdown](https://www.thehacker.recipes/): Kerberos protokol ayrıntıları, AD CS ve NTLM relay operasyonel rehberleri.
- 🌐 [SpecterOps Red Team Research](https://posts.specterops.io/): Saldırı yolu grafikleri ve modern Active Directory zafiyet analizleri.

