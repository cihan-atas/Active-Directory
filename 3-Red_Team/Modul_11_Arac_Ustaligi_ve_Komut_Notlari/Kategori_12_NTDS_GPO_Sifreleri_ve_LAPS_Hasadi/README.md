# 12. NTDS.DIT, GPO ŞİFRELERİ VE LAPS HASADI (CREDENTIAL DUMPING & LAPS)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 8 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **ntdsutil** | [ntdsutil.md](./ntdsutil.md) | Windows Server üzerinde Active Directory veritabanını (NTDS.dit) ve sistem kovanlarını yerleşik IFM (Install From Media) mekanizmasıyla diske çıkaran yönetim aracıdır. |
| 2 | **vssadmin / diskshadow** | [vssadmin_diskshadow.md](./vssadmin_diskshadow.md) | Volume Shadow Copy Service (VSS) altyapısını kullanarak kilitli durumdaki NTDS.dit dosyasının anlık gölge kopyasını oluşturan ve dışa aktaran yerleşik araçlardır. |
| 3 | **Invoke-NinjaCopy** | [Invoke-NinjaCopy.md](./Invoke-NinjaCopy.md) | VSS kullanmaksızın doğrudan ham NTFS disk sektörleri (\\.\C:) ve MFT kayıtlarını okuyarak kilitli NTDS.dit ve SYSTEM dosyalarını kopyalayan PowerShell aracıdır. |
| 4 | **gpp-decrypt** | [gpp-decrypt.md](./gpp-decrypt.md) | SYSVOL paylaşımındaki Group Policy Preferences (GPP) XML dosyalarında yer alan, Microsoft'un statik AES anahtarıyla şifrelenmiş cpassword değerlerini çözen şifre çözücüdür. |
| 5 | **Get-GPPPassword** | [Get-GPPPassword.md](./Get-GPPPassword.md) | SYSVOL paylaşımını özyinelemeli tarayarak GPP XML dosyalarındaki şifreli cpassword değerlerini otomatik tespit eden ve açık metne çeviren PowerShell aracıdır. |
| 6 | **Grouper2** | [Grouper2.md](./Grouper2.md) | SYSVOL'deki Grup İlkelerini (GPO) ayrıştırarak zafiyet oluşturan ayarları, yetki devri hatalarını ve gömülü parolaları otomatik puanlayan C# motorudur. |
| 7 | **LAPSToolkit.ps1** | [LAPSToolkit.md](./LAPSToolkit.md) | Active Directory'de Microsoft LAPS yapılandırmasını denetleyen, delegasyon açıklarını haritalayan ve okunabilir ms-Mcs-AdmPwd yerel yönetici parolalarını LDAP üzerinden hasat eden PowerShell aracıdır. |
| 8 | **pyLAPS** | [pyLAPS.md](./pyLAPS.md) | Linux üzerinden Pass-the-Hash ve Kerberos desteğiyle LDAP sorguları yaparak LAPS yerel yönetici parolalarını çeken Python aracıdır. |


## 🗺️ Kimlik Bilgisi Hasat Taksonomisi

```
                     [Merkezi Kimlik Hasat Vektörleri]
                                     |
         +---------------------------+---------------------------+
         |                                                       |
  [Domain Controller (DC)]                                [SYSVOL & LDAP]
         |                                                       |
    +----+----+                                             +----+----+
    |         |                                             |         |
[NTDS.dit Kilidi Aşma]                                [GPO Şifreleri] [LAPS Parolaları]
    |                                                       |              |
    |-- ntdsutil (IFM Snapshot)                             |-- gpp-decrypt|-- LAPSToolkit (PS)
    |-- vssadmin / diskshadow (VSS Expose)                  |-- Get-GPPPass|-- pyLAPS (Linux PtH)
    `-- Invoke-NinjaCopy (Raw MFT Disk)                     `-- Grouper2   `-- NetExec (--laps)
```

---

---

---

> **Önceki Kategori:** [← Kategori 11](../Kategori_11_Yanal_Hareket_ve_Uzak_Kod_Yurutme/README.md) · **Sonraki Kategori:** [Kategori 13 →](../Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/README.md)
