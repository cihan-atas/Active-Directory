# 16. TÜNELLEME, PİVOT VE SOCKS PROXY (PIVOTING & TUNNELING)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 3 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **Chisel** | [Chisel.md](./Chisel.md) | HTTP/WebSocket protokolü üzerinden tünellenmiş ve dahili SSH v2 ile şifrelenmiş ters (reverse) SOCKS5 ve port yönlendirme sağlayan yüksek performanslı pivot aracıdır. |
| 2 | **Ligolo-ng** | [Ligolo-ng.md](./Ligolo-ng.md) | Sanal TUN arabirimi ile Katman 3 düzeyinde yönlendirme sağlayan, Proxychains bağımlılığını kaldıran ve tam Nmap SYN / ICMP desteği sunan yeni nesil pivot aracıdır. |
| 3 | **Proxychains-ng** | [Proxychains-ng.md](./Proxychains-ng.md) | LD_PRELOAD kancalamasıyla Linux araçlarının TCP ve DNS bağlantılarını SOCKS4/5 veya HTTP vekilleri üzerinden iç Active Directory ağına yönlendiren zincirleme motorudur. |


## 🎯 Operasyonel Rol ve Tünelleme Mimarisi

Dış ağdan iç kurumsal Active Directory segmentine erişirken güvenlik duvarları, NAT ve DPI sistemleri doğrudan bağlantıları engeller. Bu kategorideki araçlar, ele geçirilen bir pivot makinesi üzerinden saldırganın tüm araç cephaneliğini iç ağa şeffaf biçimde taşır:

```
[ Saldırgan Makinesi ]
      │
      ├─► Ligolo-ng (Katman 3 TUN Arabirimi) ──► [ Şeffaf IP Yönlendirme: nmap, netexec ]
      │
      └─► Chisel (HTTP/WebSocket SOCKS5) ──────► Proxychains-ng ──► [ Dinamik Soket Kancalama ]
                                                                            │
                                                                            ▼
                                                                [ İç Active Directory Ağı ]
```

---

---

---

> **Önceki Kategori:** [← Kategori 15](../Kategori_15_Yerel_Yetki_Yukseltme_ve_Potato_Ailesi/README.md) · **Sonraki Kategori:** [Kategori 17 →](../Kategori_17_Modern_EDR_Safe_Beacon_Object_Files/README.md)
