# 13. TARİHİ VE KRİTİK ZAFİYET İSTİSMAR ARAÇLARI (EXPLOIT TOOLING)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 4 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **cve-2020-1472-exploit (Zerologon)** | [cve-2020-1472-exploit.md](./cve-2020-1472-exploit.md) | Netlogon Uzaktan Yönetim Protokolü'ndeki (MS-NRPC) kriptografik hatayı istismar ederek kimlik bilgisi olmadan Domain Controller makine hesabı parolasını sıfırlayan kritik zafiyet aracıdır. |
| 2 | **restorepassword.py** | [restorepassword.md](./restorepassword.md) | Zerologon istismarı sonrasında sıfırlanan Domain Controller makine hesabı parolasını yerel SAM kovanındaki orijinal değerine geri yükleyerek AD replikasyonunu onaran kurtarma aracıdır. |
| 3 | **PrintNightmare** | [PrintNightmare.md](./PrintNightmare.md) | Windows Print Spooler (spoolsv.exe) servisindeki yetki denetimi açığını (CVE-2021-1675/34527) istismar ederek standart kullanıcıyla hedef sistemlerde uzaktan SYSTEM yetkisinde DLL çalıştıran istismar aracıdır. |
| 4 | **noPac / sam-the-admin** | [noPac_sam-the-admin.md](./noPac_sam-the-admin.md) | sAMAccountName sahteciliği (CVE-2021-42278) ve Kerberos PAC kafa karışıklığı (CVE-2021-42287) açıklarını birleştirerek dakikalar içinde Domain Admin yetkisine sıçrayan istismar aracıdır. |


## 🗺️ Kritik Zafiyet Etki Matrisi

```
                 [Tarihi ve Kritik AD Zafiyet Vektörleri]
                                    |
         +--------------------------+--------------------------+
         |                                                     |
  [Kimliksiz Anonim Erişim]                             [Düşük Yetkili Domain Kullanıcısı]
         |                                                     |
    +----+----+                                           +----+----+
    |         |                                           |         |
[Zerologon (CVE-2020-1472)]                   [PrintNightmare]      [noPac (sam-the-admin)]
    |                                                 |                     |
Netlogon AES-CFB8 Kripto Kusuru               spoolsv.exe RCE       sAMAccountName + PAC Spoof
DC$ Parolası Sıfırlanır                       SYSTEM DLL Yükletir   60 Saniyede Domain Admin
    |                                                 |                     |
    v                                                 v                     v
restorepassword.py (Onarım Şart!)             SYSTEM Kabuk/Beacon   DCSync / Tam Yetkili TGT
```

---

---

---

> **Önceki Kategori:** [← Kategori 12](../Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/README.md) · **Sonraki Kategori:** [Kategori 14 →](../Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/README.md)
