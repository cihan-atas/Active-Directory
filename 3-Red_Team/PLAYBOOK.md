# ⚔️ Active Directory Saldırı Yaşam Döngüsü ve Operasyonel Oyun Kitabı (Playbook)

> **Kapsam:** 🔴 Red Team (Saldırı & Tehdit Analizi)
> **Amaç:** 10 modüldeki tekniklerin gerçek dünya sızma testlerinde ve yetkili güvenlik tatbikatlarında nasıl uçtan uca zincirlendiğini (Attack Chain) göstermek.
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
          - Alternatif: mitm6 ile IPv6 DNS trafiğini ele geçir
                    │
                    ▼
       2. NTLMv2 Karması / LDAP Relay (Modül 08.1)
          - Yakalanan NTLMv2 karmasını çevrimdışı kır (Hashcat)
          - VEYA LDAP imzasız ise doğrudan LDAP'a relay et
                    │
                    ▼
       3. İlk Etki Alanı Kimliği (Foothold) (Modül 02.4)
          - Standart kullanıcı (jdoe) elde edildi
                    │
                    ▼
       4. Graf Tabanlı Saldırı Yolu Analizi (Modül 01.2)
          - SharpHound / BloodHound CE ile etki alanı haritasını çıkar
          - En kısa DA (Domain Admin) yolunu tespit et
                    │
                    ▼
       5. AD CS Zafiyet Sömürüsü (Modül 07.1 - ESC1)
          - Certipy find ile ESC1 şablonunu keşfet
          - SAN=Administrator içeren sertifika talep et
                    │
                    ▼
       6. Etki Alanı Hakimiyeti (Modül 09.1 / 09.2)
          - PKINIT ile DA TGT al ──▶ DCSync ile krbtgt anahtarını çek
          - Diamond Ticket ile tespit izi düşük kalıcılık kur
```

---

## 3. Senaryo B: Varsayılan İhlal (Assumed Breach / Kurumsal Kimlik)

Bu senaryoda saldırgan bir oltalama (phishing) veya ele geçirilmiş kurumsal bilgisayar üzerinden düşük yetkili bir etki alanı hesabına (`ayilmaz`) zaten sahiptir.

```
       [Düşük Yetkili Hesap: ayilmaz]
                    │
                    ▼
       1. Çevrimdışı Kimlik Avı (Modül 03.1)
          - GetUserSPNs ile Kerberoasting (Servis hesaplarını hedefle)
          - GetNPUsers ile AS-REP Roasting (DONT_REQ_PREAUTH taraması)
          - Hashcat ile svc_sql parolasını çöz: 'Summer2024!'
                    │
                    ▼
       2. ACL ve Yetki Devri Keşfi (Modül 05.1 / 05.2)
          - svc_sql hesabının BACKUP-SRV bilgisayarı üzerinde GenericWrite yetkisi var
                    │
                    ▼
       3. RBCD Tabanlı Yetki Yükseltme (Modül 06.3)
          - MAQ kotası ile EVILPC$ makine hesabı oluştur
          - BACKUP-SRV'nin AllowedToAct özniteliğine EVILPC$ ekle
          - S4U2proxy ile BACKUP-SRV üzerinde Administrator olarak bilet al
                    │
                    ▼
       4. Yerel SYSTEM ve LSASS Hasadı (Modül 03.2 / 04.3)
          - WMI/PsExec ile BACKUP-SRV'ye bağlan
          - LSASS bellek görüntüsünden (Snapshot / nanodump) oturum açmış
            Tier-1 Yöneticisinin NT karmasını çek
                    │
                    ▼
       5. Forest ve Domain Kalıcılığı (Modül 09.3 / 10.1)
          - Tier-0 erişimiyle DCShadow üzerinden izsiz sidHistory ekle
          - DSRM arka kapısını yapılandır
```

---

## 4. Kerberos ve Active Directory Hata Çözüm Matrisi (Troubleshooting)

Operasyonlar sırasında araçların ürettiği hata kodları ve teknik çözümleri:

| Hata Kodu | Protokol Anlamı | Kök Neden | Saha Çözümü (Remediation) |
|---|---|---|---|
| `KRB_AP_ERR_SKEW (0x25)` | Clock skew too great | Saldırı makinesi ile KDC arasındaki saat farkı **5 dakikadan fazladır**. | `rdate -n <DC_IP>` veya `sudo ntpdate <DC_IP>` komutu ile saldırı makinesinin saatini etki alanı denetleyicisine eşitleyin. |
| `KDC_ERR_ETYPE_NOSUPP (0x0e)` | KDC has no support for encryption type | Talep edilen şifreleme türü (genellikle RC4 - etype 23) KDC üzerinde tamamen kapatılmıştır. | Araca `--aes` veya `/enctype:aes256` parametresi ekleyerek AES bilet talep edin; hash kırma işlemini Hashcat mod 19700'e aktarın. |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN (0x07)` | Server not found in Kerberos database | Talep edilen SPN veya hedef makine FQDN formatında değildir ya da silinmiştir. | IP adresi yerine tam FQDN (`cifs/target01.corp.local`) kullanın; `/etc/hosts` dosyanızda DNS çözümlemesini doğrulayın. |
| `KDC_ERR_POLICY (0x0c)` | KDC policy rejects request | Hedef hesap **Protected Users** grubundadır veya yetki devrine kapatılmıştır (`Cannot be delegated`). | S4U delegasyonu veya taklit (impersonation) için o kullanıcı yerine Protected Users grubunda olmayan başka bir yetkili seçin. |
| `KDC_ERR_BADOPTION (0x0d)` | KDC cannot accommodate requested option | S4U2proxy isteğinde bilet iletim (Forwardable) bayrağı eksiktir. | Bilet talep ederken `/forwardable` bayrağının açık olduğundan emin olun; RBCD hedef SPN'ini kontrol edin. |
| `KDC_ERR_CLIENT_REVOKED (0x12)` | Client credentials have been revoked | Kimlik bilgisi kullanılan hesap kilitlenmiş, süresi dolmuş veya devre dışı bırakılmıştır. | Parola püskürtmeyi (Password Spray) durdurun; hesap kilitlenme süresini LDAP üzerinden kontrol edin. |
| `0x00000005 (ACCESS_DENIED)` | Access Denied | LSASS üzerinde **RunAsPPL** etkindir ya da EDR kernel seviyesinde handle engellemektedir. | LSASS'a doğrudan bağlanmak yerine kayıt defteri kovanlarını (`reg save SAM/SYSTEM`) yedekleyin veya Shadow Credentials yoluna gidin. |

---

## 5. Operasyonel Güvenlik (OPSEC) Altın Kuralları

1. **Gürültülü Ağ Taramalarından Kaçının:**
   Etki alanında port taraması (Nmap -p- vb.) yapmak SIEM ve NDR sistemlerinde anında alarm üretir. Bunun yerine tek bir TCP/389 (LDAP) sorgusu ile tüm etki alanı bilgisayar listesini (`operatingSystem`, `dNSHostName`) çekin.
2. **Kullanıcı Hesabı Kilitleme Riskini Yönetin:**
   Parola püskürtme (Password Spray) yapmadan önce mutlaka etki alanının kilitlenme politikasını (`lockoutThreshold`, `lockoutDuration`, `resetLockoutCount`) sorgulayın. Eşik değerinin en az yarısı kadar güvenli aralıklarla deneyin.
3. **Diske Dosya Bırakmayın (Living off the Land):**
   Hedef sistemlere derlenmiş üçüncü taraf `.exe` araçları yüklemek yerine, Windows yerleşik LOLBin'lerini (`rundll32`, `certutil`, `wmic`, `powershell`) veya bellek içi yükleyicileri (`execute-assembly`) kullanın.
4. **Bilet Sürelerini Gerçekçi Tutun:**
   Golden veya Silver bilet üretirken 10 yıllık bilet basmayın; ortamın standart Kerberos bilet ömrü olan **10 saat** parametresini (`/duration:10`) verin.
5. **İzleri Düzenli Temizleyin:**
   RBCD ile eklenen sahte makine hesaplarını engagement sonunda silin; `AdminSDHolder` veya `msDS-AllowedToActOnBehalfOfOtherIdentity` özniteliklerini orijinal hallerine döndürün (`flush`).
