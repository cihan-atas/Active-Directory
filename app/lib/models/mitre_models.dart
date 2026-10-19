import 'package:flutter/material.dart';

/// MITRE ATT&CK Taktik Sütunları
enum MitreTactic {
  recon(
    id: 'TA0043_TA0007',
    name: 'Keşif & Numaralandırma',
    colorHex: 0xFF3B82F6, // Blue
    icon: Icons.search,
  ),
  initialAccess(
    id: 'TA0001_TA0006',
    name: 'İlk Erişim & Kimlik Avı',
    colorHex: 0xFFF59E0B, // Amber
    icon: Icons.vpn_key_outlined,
  ),
  privEsc(
    id: 'TA0004_TA0003',
    name: 'Yetki Yükseltme & Kalıcılık',
    colorHex: 0xFFEF4444, // Red
    icon: Icons.trending_up,
  ),
  lateralMovement(
    id: 'TA0008_TA0002',
    name: 'Yanal Hareket & Relay',
    colorHex: 0xFF8B5CF6, // Purple
    icon: Icons.swap_horiz,
  ),
  defenseEvasion(
    id: 'TA0005',
    name: 'Savunma Atlatma & DFIR',
    colorHex: 0xFF10B981, // Emerald
    icon: Icons.shield_outlined,
  );

  final String id;
  final String name;
  final int colorHex;
  final IconData icon;

  const MitreTactic({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.icon,
  });

  Color get color => Color(colorHex);
}

/// MITRE ATT&CK Teknik Tanımı
class MitreTechnique {
  final String id; // Örn: 'T1558.003'
  final String name; // Örn: 'Kerberoasting'
  final MitreTactic tactic;
  final String description;
  final List<String> tools; // ['Rubeus', 'GetUserSPNs.py', 'PowerView']
  final List<int> eventIds; // [4769, 4768]
  final String detectionSummary;
  final List<String> commandQueries;
  final String? relatedArticlePath;
  final int heatScore; // 1 - 5 (Isı haritası yoğunluğu)

  const MitreTechnique({
    required this.id,
    required this.name,
    required this.tactic,
    required this.description,
    required this.tools,
    required this.eventIds,
    required this.detectionSummary,
    required this.commandQueries,
    this.relatedArticlePath,
    required this.heatScore,
  });

  Color get heatColor {
    switch (heatScore) {
      case 5:
        return const Color(0xFFEF4444); // Parlak Kırmızı (En popüler/kritik)
      case 4:
        return const Color(0xFFF97316); // Turuncu
      case 3:
        return const Color(0xFFF59E0B); // Amber
      case 2:
        return const Color(0xFF3B82F6); // Mavi
      default:
        return const Color(0xFF64748B); // Koyu Gri/Mavi
    }
  }
}

/// Active Directory MITRE ATT&CK Bilgi Bankası
class MitreDataRepository {
  static final List<MitreTechnique> allTechniques = [
    // 1. Keşif & Numaralandırma (Recon & Discovery)
    const MitreTechnique(
      id: 'T1087.002',
      name: 'Domain Account Discovery',
      tactic: MitreTactic.recon,
      description: 'Active Directory etki alanındaki kullanıcı hesaplarının, parola politikalarının ve bayraklarının (DONT_REQ_PREAUTH vb.) LDAP veya RPC ile taranması.',
      tools: ['PowerView', 'ldapsearch', 'BloodHound', 'net.exe', 'AD-Module'],
      eventIds: [4661, 1644],
      detectionSummary: 'Kısa süre içinde alışılmadık istemcilerden gelen yoğun LDAP sorguları (Directory Service Access) ve Event ID 1644 sorgu analizi.',
      commandQueries: ['Get-DomainUser', 'ldapsearch', 'net user /domain'],
      relatedArticlePath: '3-Red_Team/Modul_01_Kesif/1.1_Pasif_Aktif_Kesif.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1069.002',
      name: 'Domain Groups Discovery',
      tactic: MitreTactic.recon,
      description: 'Domain Admins, Enterprise Admins ve özel ayrıcalıklı grupların ve üyelerinin listelenmesi.',
      tools: ['BloodHound', 'PowerView', 'SharpView', 'net.exe'],
      eventIds: [4661, 4798],
      detectionSummary: 'Ayrıcalıklı grupların üyelerinin sorgulanması sırasında Event ID 4798 tetiklenir.',
      commandQueries: ['Get-DomainGroupMember', 'net group "Domain Admins" /domain'],
      relatedArticlePath: '3-Red_Team/Modul_01_Kesif/1.2_LDAP_RPC_Numaralandirma.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1482',
      name: 'Domain Trust Discovery',
      tactic: MitreTactic.recon,
      description: 'Etki alanları ve ormanlar arasındaki güven ilişkilerinin (Forest/External/Parent-Child Trust) tespit edilmesi.',
      tools: ['PowerView', 'nltest', 'SharpShares', 'dsquery'],
      eventIds: [4661],
      detectionSummary: 'nltest /domain_trusts ve LsaQueryTrustedDomains API çağrıları.',
      commandQueries: ['Get-DomainTrust', 'nltest /domain_trusts'],
      relatedArticlePath: '3-Red_Team/Modul_09_Forest_Trusts/9.1_Trust_Mimarisi_ve_Numaralandirma.md',
      heatScore: 3,
    ),
    const MitreTechnique(
      id: 'T1018',
      name: 'Remote System Discovery',
      tactic: MitreTactic.recon,
      description: 'Etki alanındaki Domain Controller, dosya sunucusu ve istemcilerin taranması.',
      tools: ['crackmapexec', 'nmap', 'NetExec', 'SharpShares'],
      eventIds: [5140, 5145],
      detectionSummary: 'Ağ genelinde 445 (SMB) ve 88 (Kerberos) portlarına yönelik eşzamanlı bağlantılar.',
      commandQueries: ['nmap -p 445', 'crackmapexec smb', 'Get-DomainComputer'],
      relatedArticlePath: '3-Red_Team/Modul_01_Kesif/1.3_Port_Servis_Taramasi.md',
      heatScore: 3,
    ),

    // 2. İlk Erişim & Kimlik Avı (Initial Access & Credential Access)
    const MitreTechnique(
      id: 'T1558.003',
      name: 'Kerberoasting',
      tactic: MitreTactic.initialAccess,
      description: 'Hizmet hesabı (SPN) olan hesaplar adına TGS bileti talep edilerek bilet içindeki RC4/AES hash\'inin çevrimdışı kırılması.',
      tools: ['Rubeus', 'GetUserSPNs.py', 'Invoke-Kerberoast', 'Mimikatz'],
      eventIds: [4769, 4768],
      detectionSummary: 'Event ID 4769 altında Ticket Encryption Type 0x17 (RC4-HMAC) ve Ticket Options 0x40810000 olan toplu TGS istekleri.',
      commandQueries: ['rubeus kerberoast', 'GetUserSPNs.py', 'Invoke-Kerberoast'],
      relatedArticlePath: '3-Red_Team/Modul_03_Kerberos_Saldirilari/3.1_Kerberoasting.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1558.004',
      name: 'AS-REP Roasting',
      tactic: MitreTactic.initialAccess,
      description: 'Do Not Require Kerberos Preauthentication (DONT_REQ_PREAUTH) bayrağı olan hesaplar için ön doğrulamasız AS-REP şifreli metnini alıp kırma.',
      tools: ['Rubeus', 'GetNPUsers.py', 'PowerView'],
      eventIds: [4768],
      detectionSummary: 'Event ID 4768 altında Pre-Authentication Type değerinin 0 (None) olması.',
      commandQueries: ['GetNPUsers.py', 'rubeus asreproast'],
      relatedArticlePath: '3-Red_Team/Modul_03_Kerberos_Saldirilari/3.2_ASREP_Roasting.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1110.003',
      name: 'Password Spraying',
      tactic: MitreTactic.initialAccess,
      description: 'Hesap kilitleme eşiğini aşmamak için tüm kullanıcılara tek bir yaygın parola (Summer2024!, Welcome123!) denenmesi.',
      tools: ['kerbrute', 'crackmapexec', 'Spray-Passwords', 'DomainPasswordSpray'],
      eventIds: [4625, 4771],
      detectionSummary: 'Kısa sürede birçok farklı kullanıcı için aynı istemci IP\'sinden gelen 4771 (Kerberos pre-auth failed - KDC_ERR_PREAUTH_FAILED).',
      commandQueries: ['kerbrute passwordspray', 'crackmapexec smb --spray'],
      relatedArticlePath: '3-Red_Team/Modul_02_Ilk_Erisim/2.1_Password_Spraying.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1003.001',
      name: 'LSASS Memory Dumping',
      tactic: MitreTactic.initialAccess,
      description: 'Local Security Authority Subsystem Service (LSASS) bellek alanından düz metin parola ve NTLM hash dökümü.',
      tools: ['Mimikatz', 'procdump', 'comsvcs.dll', 'nanodump', 'SharpKatz'],
      eventIds: [4656, 4663, 10], // Sysmon 10
      detectionSummary: 'Sysmon Event ID 10: LSASS sürecine yönelik PROCESS_VM_READ yetkisiyle açılan Handle istekleri.',
      commandQueries: ['sekurlsa::logonpasswords', 'comsvcs.dll MiniDump', 'procdump -ma lsass.exe'],
      relatedArticlePath: '3-Red_Team/Modul_04_Kimlik_Kazanimi/4.1_LSASS_Dumping.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1003.003',
      name: 'DCSync / NTDS.dit Dumping',
      tactic: MitreTactic.initialAccess,
      description: 'MS-DRSR protokolü taklit edilerek etki alanındaki tüm kullanıcı ve KRBTGT hash\'lerinin Domain Controller\'dan çekilmesi.',
      tools: ['secretsdump.py', 'Mimikatz', 'SharpKatz', 'ntdsutil'],
      eventIds: [4662],
      detectionSummary: 'Event ID 4662 altında DS-Replication-Get-Changes ve DS-Replication-Get-Changes-All genişletilmiş erişim hakları.',
      commandQueries: ['secretsdump.py -just-dc', 'lsadump::dcsync', 'ntdsutil ac i'],
      relatedArticlePath: '3-Red_Team/Modul_08_Domain_Dominance/8.1_DCSync.md',
      heatScore: 5,
    ),

    // 3. Yetki Yükseltme & Kalıcılık (Privilege Escalation & Persistence)
    const MitreTechnique(
      id: 'T1649',
      name: 'AD CS Certificate Abuse (ESC1 - ESC8)',
      tactic: MitreTactic.privEsc,
      description: 'Active Directory Sertifika Servisleri (AD CS) hatalı yapılandırmalarıyla (SAN enjeksiyonu, Web Enrollment NTLM Relay) Domain Admin yetkisi alma.',
      tools: ['Certipy', 'Certify', 'ForgeCert', 'gettgtpkinit.py'],
      eventIds: [4886, 4887],
      detectionSummary: 'CA sunucusunda Event ID 4887: Subject Alternative Name (SAN) içeren sertifika taleplerinin onaylanması.',
      commandQueries: ['certipy find -vulnerable', 'certipy req -ca', 'Certify.exe find'],
      relatedArticlePath: '3-Red_Team/Modul_06_ADCS_Saldirilari/6.1_ADCS_Mimarisi_ve_Numaralandirma.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1558.001',
      name: 'Golden Ticket (KRBTGT)',
      tactic: MitreTactic.privEsc,
      description: 'KRBTGT hesabı NTLM/AES anahtarı ile sahte bir Ticket Granting Ticket (TGT) üreterek 10 yıl geçerli Domain Admin yetkisi sağlama.',
      tools: ['Mimikatz', 'Rubeus', 'ticketer.py'],
      eventIds: [4768, 4769],
      detectionSummary: 'Etki alanında karşılığı olmayan Event ID 4768 olmaksızın doğrudan 4769 TGS istekleri görülmesi ve 10 yıllık bilet süresi.',
      commandQueries: ['kerberos::golden', 'rubeus golden', 'ticketer.py -nthash'],
      relatedArticlePath: '3-Red_Team/Modul_08_Domain_Dominance/8.2_Golden_Silver_Ticket.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1098',
      name: 'Account Manipulation / Shadow Credentials',
      tactic: MitreTactic.privEsc,
      description: 'Hedef bilgisayar veya kullanıcının msDS-KeyCredentialLink özniteliğine RSA anahtarı yazarak parolasız PKINIT oturumu açma.',
      tools: ['pywhisker', 'Whisker', 'ShadowCredentials', 'StandIn'],
      eventIds: [5136, 4768],
      detectionSummary: 'Event ID 5136 (Directory Service Object Modified): msDS-KeyCredentialLink özniteliğinde değişiklik.',
      commandQueries: ['pywhisker.py -d', 'Whisker.exe add', 'Set-DomainObject'],
      relatedArticlePath: '3-Red_Team/Modul_05_Yetki_Yukseltme/5.3_Shadow_Credentials.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1484.001',
      name: 'Group Policy Modification',
      tactic: MitreTactic.privEsc,
      description: 'Grup İlkesi Nesnelerine (GPO) zararlı Zamanlanmış Görev (Scheduled Task) veya servis enjekte ederek OU makinelerinde SYSTEM olma.',
      tools: ['pyGPOAbuse', 'SharpGPOAbuse', 'PowerView'],
      eventIds: [5136, 5145],
      detectionSummary: 'SYSVOL dizini altındaki GptTmpl.inf veya ScheduledTasks.xml dosyalarında beklenmedik değişiklikler.',
      commandQueries: ['pyGPOAbuse.py', 'SharpGPOAbuse.exe --gponame'],
      relatedArticlePath: '3-Red_Team/Modul_05_Yetki_Yukseltme/5.2_GPO_Abuse.md',
      heatScore: 4,
    ),

    // 4. Yanal Hareket & Relay (Lateral Movement & Relay)
    const MitreTechnique(
      id: 'T1550.002',
      name: 'Pass the Hash (PtH)',
      tactic: MitreTactic.lateralMovement,
      description: 'Düz metin parola yerine çalınan NTLM hash\'i kullanılarak SMB, WMI veya WinRM üzerinden uzaktan komut yürütme.',
      tools: ['crackmapexec', 'psexec.py', 'wmiexec.py', 'Mimikatz'],
      eventIds: [4624],
      detectionSummary: 'Event ID 4624 Logon Type 3, NTLM Kimlik Doğrulama Paketi ve boş/sıfır LM/NTLM hash eşleşmesi.',
      commandQueries: ['psexec.py -hashes', 'crackmapexec smb -H', 'wmiexec.py -hashes'],
      relatedArticlePath: '3-Red_Team/Modul_07_Yanal_Hareket/7.1_Pass_the_Hash.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1550.003',
      name: 'Pass the Ticket (PtT)',
      tactic: MitreTactic.lateralMovement,
      description: 'Elde edilen veya üretilen Kerberos biletini (TGT/TGS) yerel LSASS oturumuna enjekte ederek ağ kaynaklarına yetkili erişim.',
      tools: ['Rubeus', 'Mimikatz', 'klist'],
      eventIds: [4624, 4672],
      detectionSummary: 'Farklı bir istemci IP\'sinden talep edilen TGT\'nin başka bir iş istasyonunda kullanılması.',
      commandQueries: ['rubeus ptt /ticket:', 'kerberos::ptt', 'export KRB5CCNAME='],
      relatedArticlePath: '3-Red_Team/Modul_07_Yanal_Hareket/7.2_Pass_the_Ticket.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1557.001',
      name: 'LLMNR / NBT-NS Poisoning & Relay',
      tactic: MitreTactic.lateralMovement,
      description: 'Çözümlenemeyen DNS isteklerini zehirleyerek NetNTLMv2 hash yakalama veya SMB imzasız sunuculara LDAP relay yapma.',
      tools: ['Responder', 'ntlmrelayx.py', 'mitm6', 'Inveigh'],
      eventIds: [4624, 4625],
      detectionSummary: 'Ağda yoğun mDNS, LLMNR (5355 UDP) ve NetBIOS yanıtları üreten şüpheli IP telemetrisi.',
      commandQueries: ['responder -I eth0', 'ntlmrelayx.py -t', 'mitm6 -d'],
      relatedArticlePath: '3-Red_Team/Modul_02_Ilk_Erisim/2.2_LLMNR_NBTNS_Poisoning.md',
      heatScore: 5,
    ),
    const MitreTechnique(
      id: 'T1021.002',
      name: 'SMB / Windows Admin Shares',
      tactic: MitreTactic.lateralMovement,
      description: 'C\$ ve ADMIN\$ paylaşımlarına ikili dosya yazarak Service Control Manager (SCM) ile uzaktan kod yürütme (PsExec).',
      tools: ['psexec.py', 'smbexec.py', 'crackmapexec', 'PsExec.exe'],
      eventIds: [5145, 7045],
      detectionSummary: 'Event ID 5145 (A network share object was checked) ADMIN\$ ve C\$ erişimi, ardından Event ID 7045 (A new service was installed).',
      commandQueries: ['psexec.py', 'smbexec.py', 'crackmapexec smb -x'],
      relatedArticlePath: '3-Red_Team/Modul_07_Yanal_Hareket/7.3_PsExec_ve_SMB_Yanal.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1047',
      name: 'Windows Management Instrumentation (WMI)',
      tactic: MitreTactic.lateralMovement,
      description: 'WMI Win32_Process nesnesi üzerinden uzaktan process başlatma; diskte dosya bırakmadığı için sessizdir.',
      tools: ['wmiexec.py', 'Invoke-WmiMethod', 'wmic.exe', 'SharpWMI'],
      eventIds: [4688, 1], // Sysmon 1
      detectionSummary: 'WmiPrvSE.exe alt süreci olarak başlayan cmd.exe veya powershell.exe süreçleri.',
      commandQueries: ['wmiexec.py', 'wmic /node: process call create'],
      relatedArticlePath: '3-Red_Team/Modul_07_Yanal_Hareket/7.4_WMI_ve_WinRM.md',
      heatScore: 4,
    ),

    // 5. Savunma Atlatma & DFIR (Defense Evasion)
    const MitreTechnique(
      id: 'T1556.002',
      name: 'Skeleton Key (Kalıcı Arka Kapı)',
      tactic: MitreTactic.defenseEvasion,
      description: 'Domain Controller belleğindeki LSASS sürecine yama yaparak etki alanındaki tüm hesaplar için evrensel bir arka kapı parolası tanımlama.',
      tools: ['Mimikatz'],
      eventIds: [4624],
      detectionSummary: 'LSASS sürecinde bellek modifikasyonu ve NT 6/7 mimarilerinde şüpheli DLL enjeksiyonu.',
      commandQueries: ['misc::skeleton'],
      relatedArticlePath: '3-Red_Team/Modul_08_Domain_Dominance/8.3_Skeleton_Key.md',
      heatScore: 4,
    ),
    const MitreTechnique(
      id: 'T1562.001',
      name: 'Disable or Modify Tools / Event Log Tampering',
      tactic: MitreTactic.defenseEvasion,
      description: 'Windows Olay Günlüklerini temizleme veya EDR / AMSI telemetrisini bellek düzeyinde bypass etme.',
      tools: ['Invoke-Phant0m', 'wevtutil', 'AMSI-Bypass', 'Mimikatz'],
      eventIds: [1102, 104], // 1102: Security log cleared
      detectionSummary: 'Security günlüğünde Event ID 1102 (The audit log was cleared) ve System günlüğünde Event ID 104.',
      commandQueries: ['wevtutil cl Security', 'event::drop'],
      relatedArticlePath: '2-Blue_Team/Modul_01_Gorunurluk/1.4_Log_Toplama.md',
      heatScore: 3,
    ),
  ];
}
