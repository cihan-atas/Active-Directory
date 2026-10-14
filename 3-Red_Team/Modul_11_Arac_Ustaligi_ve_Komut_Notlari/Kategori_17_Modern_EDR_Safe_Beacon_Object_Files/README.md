# 17. MODERN EDR-SAFE BEACON OBJECT FILES (AD BOFS)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 1 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **BOF-AD / SA-BOF** | [BOF-AD_SA-BOF.md](./BOF-AD_SA-BOF.md) | C ile yazılmış, unlinked COFF mimarisinde derlenen; alt süreç (No Fork & Run) açmadan ve CLR yüklemeden doğrudan ajan bellek alanında Win32 API'leri ile çalışan EDR-safe Active Directory keşif kütüphaneleridir. |


## 🎯 Operasyonel Rol ve EDR-Safe Bellek İçi Keşif

Geleneksel `Fork & Run` yöntemleri (`net.exe user /domain`, `whoami /priv`, PowerShell `Get-ADUser`) modern EDR yazılımlarının süreç ağacı izleme ve komut satırı loglama kurallarına yakalanır. BOF-AD mimarisi, ajan sürecinin mevcut iş parçacığında doğrudan `wldap32.dll`, `netapi32.dll` ve `secur32.dll` fonksiyonlarını yürüterek sıfır süreç anomalisi ile derin keşif sağlar:

```
[ C2 Ajanı (Beacon / Agent) ]
        │
        ├─► COFF Yükleyicisi (Bellek İçi Dinamik Fonksiyon Çözümleme - DFR)
        │
        ├─► ldapsearch.o  ──► Win32 wldap32.dll ──► [ DC LDAP Sorgusu (Süreçsiz) ]
        ├─► whoami.o      ──► Win32 advapi32.dll ──► [ Token SID/Hak Analizi ]
        ├─► adcs_enum.o   ──► Win32 wldap32.dll ──► [ ESC1/ESC8 Sertifika Zafiyetleri ]
        └─► kerberoast.o  ──► Win32 secur32.dll ──► [ Bellek İçi TGS Bilet Hasadı ]
```

---

---

---

> **Önceki Kategori:** [← Kategori 16](../Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/README.md) · **Sonraki Kategori:** [Kategori 18 →](../Kategori_18_Cevrimdisi_Parola_Kirma/README.md)
