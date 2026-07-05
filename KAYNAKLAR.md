# 📚 Kaynak Kütüphanesi — Active Directory Ustalık Programı

Bu proje **birincil (resmi/otoriter) kaynaklara** dayandırılarak yazılır. Bir konu yazılırken en az bir resmi (Microsoft/RFC) + bir uzman topluluk kaynağı referans alınır. Her doküman sonuna kullanılan kaynaklar linklenir.

**Güvenilirlik seviyeleri:**
`🏛️ Birincil/Resmi` · `🎓 Otoriter Uzman` · `🛠️ Araç/Dokümantasyon` · `📖 Kitap` · `🧪 Lab/Pratik` · `🎬 Video/Eğitim` · `📐 Standart/Uyumluluk`

**İçindekiler**
- [0. Genel & Temel Referanslar](#0-genel--temel-referanslar)
- [0.1 Protokol Spesifikasyonları (MS Open Specs & RFC)](#01-protokol-spesifikasyonları)
- [0.2 Kitaplar](#02-kitaplar)
- [1. Sistem Yöneticisi / Mimar](#1️⃣-sistem-yöneticisi--mimar-kaynakları)
- [2. Blue Team (Savunma)](#2️⃣-blue-team-savunma-kaynakları)
- [3. Red Team (Saldırı)](#3️⃣-red-team-saldırı-kaynakları)
- [4. Standartlar & Uyumluluk (Baseline/Benchmark)](#4-standartlar--uyumluluk)
- [5. Kritik CVE / Zafiyet Referansları](#5-kritik-cve--zafiyet-referansları)
- [6. Lab / Pratik Ortamlar](#6-lab--pratik-ortamlar)
- [7. Video / Eğitim / Konferans](#7-video--eğitim--konferans)
- [8. Topluluk & Agregatör](#8-topluluk--agregatör)
- [9. Kullanım Kuralı](#-kullanım-kuralı)

---

## 0. Genel & Temel Referanslar

- 🏛️ **Microsoft Learn — Active Directory Domain Services** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-domain-services
- 🏛️ **Microsoft Learn — Windows Server Docs (hub)** — https://learn.microsoft.com/en-us/windows-server/
- 🏛️ **Microsoft Learn — Identity & Access hub** — https://learn.microsoft.com/en-us/windows-server/identity/identity-and-access
- 🏛️ **Ask the Directory Services Team (arşiv blog)** — https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/bg-p/CoreInfrastructureandSecurityBlog — Ned Pyle vd. derin AD/DFSR/replikasyon yazıları.
- 🎓 **The Hacker Recipes — AD** — https://www.thehacker.recipes/a-d/ — Saldırı+savunma çapraz, en düzenli teknik kaynak.
- 🎓 **ADSecurity.org (Sean Metcalf)** — https://adsecurity.org/ — AD iç mekaniği, Kerberos, güvenlik (üç kol için de değerli).
- 🎓 **Trimarc Content Hub** — https://www.hub.trimarcsecurity.com/ — AD güvenlik webcast/whitepaper.
- 🛠️ **LDAP Wiki** — https://ldapwiki.com/ — Attribute, OID, LDAP kavram sözlüğü.
- 🛠️ **SS64 — PowerShell/CMD komut referansı** — https://ss64.com/ps/
- 🛠️ **Sysinternals Suite** — https://learn.microsoft.com/en-us/sysinternals/ — AccessChk, ADExplorer, ProcMon, Autoruns.
- 🎓 **Awesome Active Directory (GitHub liste)** — https://github.com/Orange-Cyberdefense/awesome-industrial-protocols yerine → https://github.com/chryzsh/awesome-windows-security & https://github.com/InfoSecWarrior/Offensive-Resources
- 🎓 **Orange Cyberdefense — AD Attack Mindmap ( Php'li poster)** — https://orange-cyberdefense.github.io/ocd-mindmaps/

---

## 0.1 Protokol Spesifikasyonları
> Bit/paket seviyesi derinlik gerektiğinde birincil kaynak. `CLAUDE.md §3` "Teknik Derinlik" katmanı için.

**Microsoft Open Specifications** — https://learn.microsoft.com/en-us/openspecs/windows_protocols/
- 🏛️ **MS-ADTS** — AD Technical Specification (nesne modeli, replikasyon metadata).
- 🏛️ **MS-DRSR** — Directory Replication Service (DCSync'in dayandığı protokol).
- 🏛️ **MS-KILE** — Kerberos Extensions (PAC, S4U, delegation).
- 🏛️ **MS-PAC** — Privilege Attribute Certificate (ticket içi yetki verisi).
- 🏛️ **MS-SAMR** — Security Account Manager Remote (hesap/grup işlemleri).
- 🏛️ **MS-LSAD / MS-LSAT** — Local Security Authority (SID/trust).
- 🏛️ **MS-NRPC** — Netlogon (Zerologon'un temeli).
- 🏛️ **MS-GKDI** — Group Key Distribution (gMSA/LAPS parola şifreleme, "Golden dMSA").
- 🏛️ **MS-ADCS / MS-WCCE / MS-ICPR** — Sertifika kayıt protokolleri (ESC saldırıları).

**IETF RFC'ler** — https://datatracker.ietf.org/
- 🏛️ **RFC 4120** — Kerberos v5.
- 🏛️ **RFC 4178** — SPNEGO.
- 🏛️ **RFC 4511 / 4512 / 4513** — LDAP protokol / dizin modeli / kimlik doğrulama.
- 🏛️ **RFC 2782** — DNS SRV kayıtları.
- 🏛️ **RFC 4033-4035** — DNSSEC.

---

## 0.2 Kitaplar

- 📖 **Active Directory (5th ed.) — Desmond, Richards, Allen, Lowe-Norris (O'Reilly)** — Klasik mimar referansı.
- 📖 **Windows Internals, Part 1 & 2 — Russinovich, Solomon, Ionescu** — LSASS, token, güvenlik alt sistemi.
- 📖 **The Hacker Playbook 3 — Peter Kim** — Pratik saldırı metodolojisi.
- 📖 **Kerberos: The Definitive Guide — Jason Garman (O'Reilly)** — Protokol derinliği.
- 📖 **PowerShell for Sysadmins — Adam Bertram (No Starch)** — Otomasyon.
- 📖 **Building an Effective Security Program for Active Directory** & **NSA/CISA "Detecting and Mitigating AD Compromises" (2024, ücretsiz PDF)** — https://www.cisa.gov/news-events/alerts

---

## 1️⃣ Sistem Yöneticisi / Mimar Kaynakları

**Tasarım & Mimari**
- 🏛️ **AD DS Design & Planning** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/
- 🏛️ **AD Forest Design Models** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/forest-design-models
- 🏛️ **Functional Levels** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels

**Replikasyon & FSMO**
- 🏛️ **AD Replication Concepts** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts
- 🏛️ **repadmin / dcdiag** — https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/
- 🏛️ **FSMO Roles & Placement** — https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/fsmo-roles
- 🏛️ **USN Rollback & Tombstone** — https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/

**Group Policy**
- 🏛️ **Group Policy Overview & Processing** — https://learn.microsoft.com/en-us/troubleshoot/windows-server/group-policy/
- 🛠️ **ADMX.help / getadmx.com** — https://admx.help/ — Her GPO ayarının açıklaması ve registry karşılığı.
- 🏛️ **Central Store (ADMX)** — https://learn.microsoft.com/en-us/troubleshoot/windows-client/group-policy/create-and-manage-central-store

**DNS / DFS / FSRM / PKI**
- 🏛️ **DNS (Aging/Scavenging, DNSSEC, SRV)** — https://learn.microsoft.com/en-us/windows-server/networking/dns/
- 🏛️ **DFS Namespaces & Replication** — https://learn.microsoft.com/en-us/windows-server/storage/dfs-namespaces/dfs-overview
- 🏛️ **FSRM (kota/dosya engelleme)** — https://learn.microsoft.com/en-us/windows-server/storage/fsrm/fsrm-overview
- 🏛️ **AD CS (PKI) Design** — https://learn.microsoft.com/en-us/windows-server/networking/core-network-guide/cncg/server-certs/
- 🎓 **PKI Solutions (Vadims Podāns) blog** — https://www.pkisolutions.com/blog/ — Kurumsal PKI derinliği.

**Hibrit Kimlik / Federasyon**
- 🏛️ **Microsoft Entra ID (hibrit)** — https://learn.microsoft.com/en-us/entra/identity/hybrid/
- 🏛️ **AD FS Operations** — https://learn.microsoft.com/en-us/windows-server/identity/ad-fs/ad-fs-overview

**Otomasyon**
- 🛠️ **PowerShell ActiveDirectory Module** — https://learn.microsoft.com/en-us/powershell/module/activedirectory/
- 🛠️ **PowerShell DSC** — https://learn.microsoft.com/en-us/powershell/dsc/overview
- 🛠️ **Windows Admin Center** — https://learn.microsoft.com/en-us/windows-server/manage/windows-admin-center/overview

**Uygulamalı SysAdmin Blogları**
- 🎓 **4sysops** — https://4sysops.com/ · **Adam the Automator** — https://adamtheautomator.com/ · **Petri IT** — https://petri.com/

---

## 2️⃣ Blue Team (Savunma) Kaynakları

**Resmi Sıkılaştırma & Mimari**
- 🏛️ **Best Practices for Securing AD** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory
- 🏛️ **Enterprise Access Model (Tier 0/1/2)** — https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-access-model
- 🏛️ **Privileged Access Workstations (PAW)** — https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-devices
- 🏛️ **Credential Guard** — https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/
- 🏛️ **Protected Users & Authentication Policies/Silos** — https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/protected-users-security-group
- 🏛️ **LAPS (Windows LAPS)** — https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview
- 🏛️ **Securing Domain Controllers** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/securing-domain-controllers-against-attack

**Denetim, Log, Telemetri**
- 🏛️ **Advanced Security Audit Policy** — https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/advanced-security-audit-policy-settings
- 🏛️ **Appendix L — Events to Monitor** — https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/appendix-l--events-to-monitor
- 🏛️ **Windows Event Forwarding (WEF)** — https://learn.microsoft.com/en-us/windows/security/threat-protection/use-windows-event-forwarding-to-assist-in-intrusion-detection
- 🛠️ **Palantir WEF Configuration** — https://github.com/palantir/windows-event-forwarding — Üretim seviyesi WEF abonelikleri.
- 🛠️ **Sysmon + SwiftOnSecurity config** — https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon · https://github.com/SwiftOnSecurity/sysmon-config · https://github.com/olafhartong/sysmon-modular
- 🎓 **Malware Archaeology — Windows Logging Cheat Sheets** — https://www.malwarearchaeology.com/cheat-sheets

**Tespit Mühendisliği (Detection Engineering)**
- 🎓 **MITRE ATT&CK** — https://attack.mitre.org/ — Teknik→tespit eşlemesi.
- 🎓 **MITRE D3FEND** — https://d3fend.mitre.org/ — Savunma tekniği taksonomisi (ATT&CK'in savunma karşılığı).
- 🛠️ **Sigma Rules (SigmaHQ)** — https://github.com/SigmaHQ/sigma — Platform-bağımsız kural.
- 🛠️ **Elastic Detection Rules** — https://github.com/elastic/detection-rules
- 🛠️ **Splunk Security Content (ESCU)** — https://research.splunk.com/
- 🛠️ **Microsoft Sentinel Content Hub / GitHub** — https://github.com/Azure/Azure-Sentinel
- 🛠️ **Atomic Red Team** — https://github.com/redcanaryco/atomic-red-team — Tespitleri doğrulamak için kontrollü saldırı simülasyonu.
- 🎓 **The DFIR Report** — https://thedfirreport.com/ — Gerçek olay analizleri (AD saldırı zincirleri + tespit).
- 🎓 **Red Canary Threat Detection Report** — https://redcanary.com/threat-detection-report/

**Tehdit Avcılığı & Değerlendirme Araçları**
- 🛠️ **BloodHound Community / Enterprise** — https://bloodhound.specterops.io/
- 🛠️ **PingCastle** — https://www.pingcastle.com/documentation/
- 🛠️ **Purple Knight (Semperis)** — https://www.purple-knight.com/
- 🛠️ **Microsoft Defender for Identity** — https://learn.microsoft.com/en-us/defender-for-identity/
- 🛠️ **ADACLScanner** — https://github.com/canix1/ADACLScanner — DACL denetimi.
- 🛠️ **ORADAD / Forest Druid (Purple Knight)** — Tier-0 saldırı yüzeyi haritalama.
- 🎓 **Semperis / Improsec / Trimarc araştırma blogları** — https://www.semperis.com/blog/ · https://improsec.com/tech-blog

**Kurumsal Rehberler (Devlet/Kurum)**
- 📐 **NSA/CISA — Detecting and Mitigating AD Compromises (2024)** — https://media.defense.gov/
- 📐 **ANSSI — Points de contrôle Active Directory** — https://www.cert.ssi.gouv.fr/ · https://github.com/ANSSI-FR/ADTimeline
- 📐 **ACSC (Avustralya) — Essential Eight / Securing AD** — https://www.cyber.gov.au/

---

## 3️⃣ Red Team (Saldırı) Kaynakları

> ⚠️ Yalnızca yetkili sızma testi / CTF / eğitim. Her teknik **MITRE T-numarası + Blue karşılığıyla** eşleştirilir.

**Metodoloji & Bilgi Tabanı**
- 🎓 **HackTricks — AD Methodology** — https://book.hacktricks.xyz/windows-hardening/active-directory-methodology
- 🎓 **The Hacker Recipes — AD** — https://www.thehacker.recipes/a-d/
- 🎓 **ired.team (Mantvydas Baranauskas)** — https://www.ired.team/ — Teknik başına derin, PoC'li notlar.
- 🎓 **ADSecurity.org** — https://adsecurity.org/ — Kerberos saldırı derinliği.
- 🎓 **SpecterOps Blog** — https://posts.specterops.io/ — Delegation, ACL, ADCS araştırmaları.
- 🎓 **harmj0y (Will Schroeder) blog** — https://blog.harmj0y.net/ — PowerView, delegation, GPO abuse köken yazıları.
- 🎓 **dirkjanm.io (Dirk-jan Mollema)** — https://dirkjanm.io/ — NTLM relay, ADCS, Azure/hibrit saldırılar.
- 🎓 **Elad Shamir — "Wagging the Dog" (RBCD)** — https://shenaniganslabs.io/2019/01/28/Wagging-the-Dog.html
- 📖 **Certified Pre-Owned (ADCS ESC1-8)** — https://posts.specterops.io/certified-pre-owned-d95910965cd2 & whitepaper.

**Enumerasyon Araçları**
- 🛠️ **BloodHound / SharpHound** — https://bloodhound.specterops.io/
- 🛠️ **PowerView (PowerSploit/Dev)** — https://powersploit.readthedocs.io/
- 🛠️ **ldapdomaindump / adidnsdump** — https://github.com/dirkjanm/ldapdomaindump
- 🛠️ **ADRecon** — https://github.com/adrecon/ADRecon
- 🛠️ **Snaffler** — https://github.com/SnaffCon/Snaffler — Paylaşımlarda kimlik bilgisi avı.
- 🛠️ **Seatbelt / SharpUp (GhostPack)** — https://github.com/GhostPack

**İlk Erişim / Kimlik Bilgisi / Koersiyon**
- 🛠️ **Responder** — https://github.com/lgandx/Responder — LLMNR/NBT-NS/mDNS poisoning.
- 🛠️ **Impacket (ntlmrelayx, GetUserSPNs, secretsdump, GetNPUsers)** — https://github.com/fortra/impacket
- 🛠️ **Kerbrute** — https://github.com/ropnop/kerbrute — Kullanıcı enum + password spray.
- 🛠️ **Coercer** — https://github.com/p0dalirius/Coercer — PetitPotam/PrinterBug/DFSCoerce zorlama.
- 🎓 **PetitPotam / PrinterBug / DFSCoerce yazıları** — https://github.com/topotam/PetitPotam · https://dirkjanm.io/

**Yanal Hareket & Post-Exploitation**
- 🛠️ **NetExec (CrackMapExec halefi)** — https://github.com/Pennyw0rth/NetExec
- 🛠️ **Mimikatz** — https://github.com/gentilkiwi/mimikatz/wiki — DCSync, PtH/PtT, ticket, DPAPI.
- 🛠️ **Rubeus** — https://github.com/GhostPack/Rubeus — Kerberoast, S4U, ticket forge.
- 🛠️ **Certify / ForgeCert (GhostPack)** — https://github.com/GhostPack/Certify — ADCS saldırıları.
- 🛠️ **Certipy (ly4k)** — https://github.com/ly4k/Certipy — ADCS ESC otomasyonu.
- 🛠️ **Whisker / Powermad / Shadow Credentials** — https://github.com/eladshamir/Whisker · https://github.com/Kevin-Robertson/Powermad
- 🛠️ **SharpGPOAbuse** — https://github.com/FSecureLABS/SharpGPOAbuse
- 🛠️ **bloodyAD** — https://github.com/CravateRouge/bloodyAD — LDAP üzerinden AD nesne manipülasyonu.

**Kalıcılık / Domain Dominance**
- 🎓 **AdminSDHolder / SDProp, DCShadow, Golden/Silver/Diamond/Sapphire Ticket** — ADSecurity + The Hacker Recipes ilgili sayfaları.
- 🛠️ **DSInternals** — https://github.com/MichaelGrafnetter/DSInternals — NTDS.dit offline analiz, hash çıkarma, DPAPI.

**Referans / Yük Kütüphaneleri**
- 🧪 **PayloadsAllTheThings** — https://github.com/swisskyrepo/PayloadsAllTheThings
- 🛠️ **LOLBAS (Living Off The Land Binaries)** — https://lolbas-project.github.io/
- 🎓 **MITRE ATT&CK — Enterprise (Windows)** — https://attack.mitre.org/matrices/enterprise/windows/

---

## 4. Standartlar & Uyumluluk
> `CLAUDE.md §3` "Güvenlik Notu" ve Sistem Yöneticisi Modül 6.6 için baseline kaynakları.

- 📐 **CIS Benchmarks (Windows Server / AD)** — https://www.cisecurity.org/cis-benchmarks
- 📐 **CIS-CAT / hardening içerikleri** — https://www.cisecurity.org/
- 📐 **DISA STIG — Windows Server & Active Directory Domain STIG** — https://public.cyber.mil/stigs/
- 📐 **Microsoft Security Compliance Toolkit + Security Baselines** — https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10
- 📐 **NIST SP 800-53 (kontroller)** — https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final
- 📐 **NIST SP 800-63 (dijital kimlik)** — https://pages.nist.gov/800-63-3/
- 📐 **ISO/IEC 27001** — https://www.iso.org/standard/27001
- 📐 **SOC 2 (AICPA TSC)** — https://www.aicpa-cima.com/
- 📐 **GDPR** — https://gdpr-info.eu/

---

## 5. Kritik CVE / Zafiyet Referansları
> Her biri için birincil kaynak: NVD kaydı + araştırmacı yazısı. Red konusunda sömürü, Blue konusunda yama/tespit anlatılır.

| Ad | CVE | Konu | Kaynak |
|----|-----|------|--------|
| **Zerologon** | CVE-2020-1472 | Netlogon (MS-NRPC) DC ele geçirme | Secura whitepaper + MSRC |
| **PrintNightmare** | CVE-2021-34527 / -1675 | Print Spooler RCE/LPE | MSRC + 0patch |
| **noPac / sAMAccountName spoofing** | CVE-2021-42278 + -42287 | DC impersonation | Microsoft + charlie.dev |
| **PetitPotam** | (koersiyon, CVE-2021-36942 kısmi) | MS-EFSRPC ile NTLM zorlama | topotam PoC |
| **Bronze Bit** | CVE-2020-17049 | Kerberos constrained delegation bypass | NetSPI |
| **Certifried** | CVE-2022-26923 | AD CS makine sertifikası ile priv-esc | Oliver Lyak / Certipy |
| **KrbRelayUp** | (relay tekniği) | Yerel-den-domain yükseltme | GitHub Dec0ne |
| **Golden dMSA** | MS-GKDI kötüye kullanımı | Delegated MSA anahtar türetme | Semperis (2024) |

- 🏛️ **NVD (NIST)** — https://nvd.nist.gov/
- 🏛️ **MSRC Security Update Guide** — https://msrc.microsoft.com/update-guide/
- 🎓 **Project Zero** — https://googleprojectzero.blogspot.com/

---

## 6. Lab / Pratik Ortamlar

- 🧪 **GOAD — Game of Active Directory** — https://github.com/Orange-Cyberdefense/GOAD — Kasıtlı zafiyetli multi-forest AD lab.
- 🧪 **DetectionLab** — https://github.com/clong/DetectionLab — Blue/telemetri (Sysmon+Splunk+Velociraptor) hazır lab.
- 🧪 **Ludus** — https://ludus.cloud/ — Otomatik AD range kurulum.
- 🧪 **Sccmhunter / MAAD-AF** — SCCM ve AD saldırı simülasyon lab içerikleri.
- 🧪 **vulnerable-AD** — https://github.com/WazeHell/vulnerable-AD — Tek script ile zafiyet enjekte.
- 🧪 **TryHackMe (AD yolları)** — https://tryhackme.com/ · **Hack The Box / HTB Academy** — https://academy.hackthebox.com/
- 🏛️ **Microsoft Evaluation Center (Windows Server/Client ISO)** — https://www.microsoft.com/en-us/evalcenter/

---

## 7. Video / Eğitim / Konferans

- 🎬 **SANS SEC505 (Securing Windows/PowerShell), SEC560, FOR509** — https://www.sans.org/
- 🎬 **Altered Security — CRTP / CRTE / CRTM** — https://www.alteredsecurity.com/ — Pratik AD saldırı sertifikaları.
- 🎬 **IppSec (HTB walkthrough)** — https://www.youtube.com/@ippsec
- 🎬 **John Hammond** — https://www.youtube.com/@_JohnHammond
- 🎬 **13Cubed (DFIR/Windows forensics)** — https://www.youtube.com/@13Cubed
- 🎬 **Black Hat / DEF CON / Troopers arşivleri** — https://www.youtube.com/@BlackHatOfficialYT · https://troopers.de/
- 🎬 **Trimarc Webcasts** — https://www.hub.trimarcsecurity.com/

---

## 8. Topluluk & Agregatör

- 🎓 **r/activedirectory · r/sysadmin · r/blueteamsec** — https://www.reddit.com/r/activedirectory/
- 🎓 **BloodHoundGang Slack / SpecterOps topluluk** — https://bloodhoundhq.slack.com/
- 🎓 **Awesome listeler** — https://github.com/chryzsh/awesome-windows-security · https://github.com/meitar/awesome-cybersecurity-blueteam
- 🎓 **HackTricks Cloud / Windows** — https://cloud.hacktricks.xyz/

---

## 📋 Kullanım Kuralı

Bir konu yazarken izlenecek zincir:
1. **🏛️ Resmi kaynağı** oku → doğru mekanizma (protokol gerekiyorsa **0.1 Spec**'e in).
2. **🎓 Uzman kaynağıyla** derinleştir → gerçek dünya nüansları.
3. **🛠️ Araç dokümanıyla** pratik komutları doğrula (mümkünse **§6 lab**'da test et).
4. Red konusu ise **MITRE ATT&CK T-numarası** + ilgili **§5 CVE**'yi ver, **Blue karşılığını** linkle.
5. Baseline gerekiyorsa **§4 Standart** (CIS/STIG) referansı ekle.
6. Doküman sonuna **"Kaynaklar"** bölümü: kullanılan linkler + erişim tarihi.

> ⚠️ Linkler zamanla taşınabilir; yazım sırasında erişilebilirlik doğrulanmalı. Bir link kırıksa arşiv (web.archive.org) veya güncel muadili aranır.

*Son güncelleme: 2026-07-03 — Kapsamlı sürüm.*
