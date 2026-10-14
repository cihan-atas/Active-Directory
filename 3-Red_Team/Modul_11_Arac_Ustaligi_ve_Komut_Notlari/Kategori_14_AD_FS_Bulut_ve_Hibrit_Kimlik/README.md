# 14. AD FS, BULUT VE HİBRİT KİMLİK (FEDERATION & HYBRID PIVOT)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 3 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **AADInternals** | [AADInternals.md](./AADInternals.md) | Azure AD (Microsoft Entra ID), M365 ve Azure AD Connect altyapılarını yönetmek, MSOL_ senkronizasyon parolalarını dökmek ve parola hash senkronizasyonunu (PHS) manipüle etmek için kullanılan kapsamlı PowerShell modülüdür. |
| 2 | **ADFSpoof (Golden SAML)** | [ADFSpoof.md](./ADFSpoof.md) | Ele geçirilen AD FS Token-Signing özel anahtarını kullanarak, şirket içi sunuculara uğramadan herhangi bir kullanıcı adına sahte SAML 2.0 belirteçleri üreten ve bulutta parola/MFA olmaksızın oturum açan Python aracıdır. |
| 3 | **ROADtools / roadrecon** | [ROADtools_roadrecon.md](./ROADtools_roadrecon.md) | Azure AD / Entra ID bulut ortamlarındaki kullanıcıları, grupları, rolleri ve Koşullu Erişim politikalarını tarayan, yerel veritabanında depolayan ve görsel web arayüzünde analiz eden keşif çerçevesidir. |


## 🎯 Operasyonel Rol ve AD-Bulut Köprüsü

Bu kategorideki araçlar, şirket içi yerel Active Directory (on-premises) ile bulut (Microsoft Entra ID / Microsoft 365) arasındaki hibrit kimlik mimarisini hedef alır. Kurumların şirket içi etki alanında elde edilen ayrıcalıklar, federasyon ve senkronizasyon mekanizmaları üzerinden buluta pivot yapmak veya bulut üzerindeki izinleri yerel ağda yetki yükseltmek için kullanılır:

```
[ On-Premises Active Directory ]
      │
      ├─► ADFS Sunucusu (Token-Signing Key) ──────► ADFSpoof ──────► [ Bulut / M365 Golden SAML ]
      │
      └─► Azure AD Connect (MSOL_ Account) ─────► AADInternals ───► [ Bulut Kimlik / PHS Enjeksiyonu ]
                                                                             │
                                                                             ▼
                                                                     [ ROADtools Keşif ]
```

---

---

---

> **Önceki Kategori:** [← Kategori 13](../Kategori_13_Tarihi_ve_Kritik_Zafiyet_Araclari/README.md) · **Sonraki Kategori:** [Kategori 15 →](../Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/README.md)
