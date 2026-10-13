# 🧪 Active Directory Pratik Laboratuvar Kurulum Kılavuzu

Bu belge, **Active Directory Ustalık Programı** kapsamındaki Sistem Mimarisi, Mavi Takım (Savunma & Tespit) ve Kırmızı Takım (Tehdit Analizi & Zafiyet Modellemesi) konularını güvenli, izole ve yasal bir ortamda test edebilmeniz için gereken laboratuvar altyapısını adım adım açıklar.

---

## 1. Laboratuvar Mimarisi ve Topoloji

Eğitimdeki 30 modülün tamamını test edebilmek için önerilen asgari topoloji 3 sanal makineden (VM) oluşur:

```
                          ┌──────────────────────────────┐
                          │   İzole Sanal Ağ (Host-Only)  │
                          │        192.168.56.0/24       │
                          └──────────────┬───────────────┘
                                         │
       ┌─────────────────────────────────┼─────────────────────────────────┐
       │                                 │                                 │
┌──────┴──────────────┐       ┌──────────┴──────────┐       ┌──────────────┴──────┐
│  DC01.corp.local    │       │  SRV01.corp.local   │       │   WKS01.corp.local  │
│  IP: 192.168.56.10  │       │  IP: 192.168.56.20  │       │   IP: 192.168.56.50 │
│  Windows Server     │       │  Windows Server     │       │   Windows 10/11     │
│  (AD DS, DNS, CA)   │       │  (IIS, DFS, MSSQL)  │       │   (İstemci, Sysmon) │
└─────────────────────┘       └─────────────────────┘       └─────────────────────┘
```

### Donanım Gereksinimleri (Asgari)
* **İşlemci (CPU):** Sanallaştırma destekli (VT-x / AMD-V) 4 çekirdek ve üzeri.
* **Bellek (RAM):** 16 GB RAM (DC01: 4 GB, SRV01: 4 GB, WKS01: 4 GB, Host: 4 GB).
* **Depolama (Disk):** ~80 GB boş SSD alanı.
* **Hipervizör:** VirtualBox (ücretsiz), VMware Workstation Pro / Player veya Hyper-V.

---

## 2. Adım Adım Kurulum Aşamaları

### Adım 1: Sanal Ağın İzolasyonu
1. Hipervizörünüzde yalnızca sanal makinelerin birbiriyle konuşabileceği bir **Host-Only** veya **Internal Network** oluşturun.
2. Ağ bloğu: `192.168.56.0/24`.
3. Sanal makinelerin fiziksel yerel ağınıza veya kurumsal ağınıza erişmediğinden emin olun.

---

### Adım 2: Domain Controller (DC01) Dağıtımı
1. Windows Server 2022 Evaluation ISO'su ile yeni bir sanal makine oluşturun.
2. Statik IP atayın:
   * **IP:** `192.168.56.10`
   * **Subnet:** `255.255.255.0`
   * **DNS:** `127.0.0.1` (veya `192.168.56.10`)
3. PowerShell ile AD DS rolünü yükleyin ve yeni forest kurun:

```powershell
# AD DS rolünü ekle
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Yeni Forest oluştur (corp.local)
Install-ADDSForest `
  -DomainName "corp.local" `
  -DomainNetbiosName "CORP" `
  -DomainMode "WinThreshold" `
  -ForestMode "WinThreshold" `
  -InstallDns:$true `
  -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force) `
  -Force:$true
```

Sunucu otomatik olarak yeniden başlayacaktır.

---

### Adım 3: Denetim ve Telemetri Altyapısı (Blue Team Hazırlığı)
Laboratuvarın savunma ve tespit modüllerini (Blue Team M01-M10) çalıştırabilmesi için gelişmiş denetim ilkelerinin açılması şarttır.

1. **Gelişmiş Denetim İlkelerini (Advanced Audit Policy) Etkinleştirin:**
```powershell
# Default Domain Controllers Policy veya yerel komut ile açın
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
auditpol /set /subcategory:"Kerberos Authentication Service" /success:enable /failure:enable
auditpol /set /subcategory:"Directory Service Changes" /success:enable /failure:enable
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Computer Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
```

2. **Komut Satırı Süreç Günlüğünü (Process Creation Event 4688) Açın:**
```powershell
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
  /v "ProcessCreationIncludeCmdLine_Enabled" /t REG_DWORD /d 1 /f
```

3. **Sysmon Dağıtımı (DC01 ve WKS01):**
SwiftOnSecurity veya Florian Roth Sysmon yapılandırmasıyla Sysmon kurun:
```cmd
Sysmon64.exe -i sysmonconfig.xml -accepteula
```

---

### Adım 4: Örnek Nesneler ve Test Verisi Oluşturma
Gerçekçi bir etki alanı simülasyonu için test kullanıcıları, hizmet hesapları ve OU hiyerarşisi oluşturun:

```powershell
# OU Hiyerarşisi
New-ADOrganizationalUnit -Name "Yonetim" -Path "DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Personel" -Path "DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Servisler" -Path "DC=corp,DC=local"

# Test Kullanıcıları
$SecPassword = ConvertTo-SecureString "UserPass123!" -AsPlainText -Force
New-ADUser -Name "Ahmet Yilmaz" -SamAccountName "ayilmaz" -UserPrincipalName "ayilmaz@corp.local" `
  -Path "OU=Personel,DC=corp,DC=local" -AccountPassword $SecPassword -Enabled $true

# SPN Atanmış Servis Hesabı (Kerberoasting Analizi için)
New-ADUser -Name "SQL Service" -SamAccountName "svc_sql" -UserPrincipalName "svc_sql@corp.local" `
  -Path "OU=Servisler,DC=corp,DC=local" -AccountPassword $SecPassword -Enabled $true
Set-ADUser -Identity "svc_sql" -ServicePrincipalNames @{Add="MSSQLSvc/srv01.corp.local:1433"}

# Pre-Auth Kapalı Hesap (AS-REP Roasting Analizi için)
New-ADUser -Name "Legacy App" -SamAccountName "legacy_user" -UserPrincipalName "legacy_user@corp.local" `
  -Path "OU=Servisler,DC=corp,DC=local" -AccountPassword $SecPassword -Enabled $true
Set-ADAccountControl -Identity "legacy_user" -DoesNotRequirePreAuth $true
```

---

## 3. Güvenlik ve Yasal Uyarılar

> [!CAUTION]
> * Bu laboratuvardaki tüm ayarlar, zafiyet senaryoları ve test hesapları **yalnızca eğitim ve araştırma amaçlıdır.**
> * Laboratuvarda kullanılan parolaları (`UserPass123!` vb.) asla kurumsal veya kişisel hesaplarınızda kullanmayın.
> * Laboratuvar sanal makinelerinin internete doğrudan köprülenmiş (Bridged) olmadığından ve kurumsal üretim ağlarından tamamen yalıtılmış olduğundan emin olun.
