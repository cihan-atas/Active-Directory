# 11. YANAL HAREKET VE UZAK KOD YÜRÜTME (LATERAL MOVEMENT & EXECUTION)

> **Modül:** [Modül 11 — Araç Cephaneliği](../README.md) · **Kol:** 🔴 Red Team  
> **Toplam Araç:** 9 Araç

---

## 🛠️ Bu Kategorideki Araçlar

| No | Araç | Dokümantasyon Dosyası | Ne İçin Kullanılır? (Tanım ve Amaç) |
|:---:|:---|:---|:---|
| 1 | **NetExec (nxc)** | [NetExec_nxc.md](./NetExec_nxc.md) | SMB, WinRM, LDAP, MSSQL, RDP ve SSH protokolleri üzerinden parola püskürtme, kimlik doğrulama, komut yürütme ve veri hasadı gerçekleştiren yeni nesil çok amaçlı otomasyon aracıdır. |
| 2 | **impacket-psexec** | [impacket-psexec.md](./impacket-psexec.md) | SMB üzerinden hedef Windows sisteminde geçici bir servis oluşturarak doğrudan NT AUTHORITY\SYSTEM yetkisinde interaktif bir komut istemcisi açan araçtır. |
| 3 | **impacket-smbexec** | [impacket-smbexec.md](./impacket-smbexec.md) | Hedef sistemde çalıştırılabilir (.exe) dosya bırakmadan, SMB Named Pipe ve BATCH betikleri üzerinden gizli komut yürütme sağlayan servissiz yanal hareket aracıdır. |
| 4 | **impacket-wmiexec** | [impacket-wmiexec.md](./impacket-wmiexec.md) | DCOM/WMI arayüzü (TCP 135) üzerinden Win32_Process sınıfı ile komut çalıştırıp çıktıları SMB paylaşımı aracılığıyla okuyan yarı-etkileşimli dosyasız kabuk aracıdır. |
| 5 | **impacket-atexec** | [impacket-atexec.md](./impacket-atexec.md) | Task Scheduler servisi (MS-TSCH) RPC arayüzü üzerinden hedef sistemde geçici zamanlanmış görev oluşturarak kod yürüten ve iş bitiminde görevi silen araçtır. |
| 6 | **impacket-dcomexec** | [impacket-dcomexec.md](./impacket-dcomexec.md) | MMC20.Application, ShellWindows ve ShellBrowserWindow gibi DCOM nesneleri üzerinden uzaktan komut yürüterek WMI/SMB filtrelerini atlatan araçtır. |
| 7 | **Evil-WinRM** | [Evil-WinRM.md](./Evil-WinRM.md) | Windows Remote Management (WinRM) servisi üzerinden Pass-the-Hash ve Kerberos desteğiyle etkileşimli PowerShell oturumu açan, dosya transferi ve bellek içi yükleme sağlayan lider Linux istemcisidir. |
| 8 | **SharpWMI** | [SharpWMI.md](./SharpWMI.md) | Cobalt Strike ve C2 altyapıları için geliştirilmiş, WMI/DCOM üzerinden WQL sorgulama ve uzaktan süreç başlatma gerçekleştiren C# aracıdır. |
| 9 | **WMIHacker** | [WMIHacker.md](./WMIHacker.md) | Port 445 (SMB) kapalıyken yalnızca TCP 135 (RPC) üzerinden Windows Kayıt Defteri'ni girdi/çıktı kanalı olarak kullanarak komut çalıştıran ve çıktı alan özel araçtır. |


## 🗺️ Yanal Hareket Protokol Seçim Matrisi

```
                 [Yanal Hareket Protokol Karar Ağacı]
                                  |
         +------------------------+------------------------+
         |                                                 |
  [SMB (TCP 445) Açık mı?]                         [SMB (TCP 445) Kapalı mı?]
         |                                                 |
    +----+----+                                       +----+----+
    |         |                                       |         |
 [Servis]  [Sessiz/Servissiz]                      [Port 5985/5986?]   [Port 135 (DCOM)?]
    |         |                                       |         |          |
 psexec    smbexec / atexec                        Evil-WinRM   |      WMIHacker
                                                                |   (Zero-SMB Registry)
                                                        wmiexec / SharpWMI / dcomexec
```

---

---

---

> **Önceki Kategori:** [← Kategori 10](../Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/README.md) · **Sonraki Kategori:** [Kategori 12 →](../Kategori_12_NTDS_GPO_Sifreleri_ve_LAPS_Hasadi/README.md)
