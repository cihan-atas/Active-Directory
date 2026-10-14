# 15. YEREL YETKİ YÜKSELTME (LPE) VE POTATO AİLESİ

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 3 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **PrintSpoofer** | [PrintSpoofer.md](./PrintSpoofer.md) | Windows 10 ve Server 2016-2022 sistemlerde SeImpersonatePrivilege yetkisini Print Spooler Named Pipe (\\.\pipe\spoolss) üzerinden istismar ederek doğrudan interaktif SYSTEM konsolu açan yüksek başarımlı LPE aracıdır. |
| 2 | **SweetPotato / JuicyPotatoNG** | [SweetPotato_JuicyPotatoNG.md](./SweetPotato_JuicyPotatoNG.md) | DCOM sıkılaştırmasını aşarak BITS, DCOM CLSID ve Spooler vektörlerini birleştiren, .NET ve Native C++ tabanlı yeni nesil belirteç (token) kaçırma araçlarıdır. |
| 3 | **GodPotato** | [GodPotato.md](./GodPotato.md) | Windows Server 2008-2022 arasında DCOM IStorage arayüzü ve yerel RPC dispatching mekanizmasıyla çalışan, harici porta veya Spooler servisine ihtiyaç duymayan evrensel yetki yükseltme aracıdır. |


## 🎯 Operasyonel Rol ve Potato Ailesi Evrimi

Active Directory ortamlarındaki servis hesapları (IIS Application Pools, MSSQL, Jenkins vb.), kısıtlı yerel yetkilere sahip olmalarına rağmen işletim sistemi çekirdeği düzeyinde `SeImpersonatePrivilege` veya `SeAssignPrimaryTokenPrivilege` kullanıcı haklarına sahiptir. Bu haklar, bir servis sürecinin kimlik doğrulayan başka bir kullanıcının güvenlik bağlamına bürünmesini sağlar.

```
[ Kısıtlı Servis Hesabı (IIS / MSSQL) - SeImpersonatePrivilege ]
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
  PrintSpoofer   SweetPotato    GodPotato
  (Named Pipe)   (BITS / DCOM)  (IStorage RPC)
        │             │             │
        └─────────────┼─────────────┘
                      ▼
            [ NT AUTHORITY\SYSTEM ]
```

---

---

---

> **Önceki Kategori:** [← Kategori 14](../Kategori_14_AD_FS_Bulut_ve_Hibrit_Kimlik/README.md) · **Sonraki Kategori:** [Kategori 16 →](../Kategori_16_Tunelleme_Pivot_ve_SOCKS_Proxy/README.md)
