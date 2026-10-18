import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class GlossaryItem {
  final String term;
  final String category; // 'Kimlik Doğrulama', 'Yetkilendirme', 'Saldırı & Kalıcılık', 'Savunma & Sertleştirme', 'AD CS & PKI'
  final String definition;
  final String securityContext;

  const GlossaryItem({
    required this.term,
    required this.category,
    required this.definition,
    required this.securityContext,
  });
}

const List<GlossaryItem> kGlossaryItems = [
  // ==========================================
  // --- KİMLİK DOĞRULAMA (AUTHENTICATION) ---
  // ==========================================
  GlossaryItem(
    term: 'Kerberos',
    category: 'Kimlik Doğrulama',
    definition: 'Simetrik anahtarlı şifreleme ve bilet (ticket) mekanizmasına dayanan, Active Directory\'nin birincil güvenli kimlik doğrulama protokolü.',
    securityContext: 'Bilet hırsızlığı (Pass the Ticket), Kerberoasting, AS-REP Roasting ve Golden/Silver Ticket saldırılarının ana hedefidir.',
  ),
  GlossaryItem(
    term: 'KDC (Key Distribution Center)',
    category: 'Kimlik Doğrulama',
    definition: 'Domain Controller üzerinde çalışan, Authentication Service (AS) ve Ticket Granting Service (TGS) bileşenlerinden oluşan Kerberos merkezi.',
    securityContext: 'KDC ele geçirilirse veya KRBTGT hash\'i sızdırılırsa tüm etki alanı güvenliği tamamen düşer.',
  ),
  GlossaryItem(
    term: 'TGT (Ticket Granting Ticket)',
    category: 'Kimlik Doğrulama',
    definition: 'Kullanıcının parolasını KDC\'ye doğruladıktan sonra aldığı ve diğer servislere bilet (TGS) talep etmek için kullandığı ana oturum bileti.',
    securityContext: 'KRBTGT hesabı parolasıyla şifrelenir. Golden Ticket saldırısında sahte TGT üretilir.',
  ),
  GlossaryItem(
    term: 'TGS (Ticket Granting Service Ticket)',
    category: 'Kimlik Doğrulama',
    definition: 'İstemcinin ağdaki belirli bir servise (SMB, MSSQL, HTTP) erişmek için KDC\'den aldığı servis erişim bileti.',
    securityContext: 'Servis hesabı parolasıyla şifrelenir. Kerberoasting saldırısında hafızadan veya ağdan çekilip çevrimdışı kırılabilir.',
  ),
  GlossaryItem(
    term: 'PAC (Privilege Attribute Certificate)',
    category: 'Kimlik Doğrulama',
    definition: 'Kerberos biletlerinin içinde taşınan, kullanıcının SID, grup üyelikleri ve yetkilerini içeren dijital imzalı veri yapısı.',
    securityContext: 'KDC ve Sunucu tarafından imzalanır. MS14-068 ve CVE-2021-42287 gibi açıklarda PAC sahteciliği ile standart kullanıcıdan Domain Admin olunmuştur.',
  ),
  GlossaryItem(
    term: 'SPN (Service Principal Name)',
    category: 'Kimlik Doğrulama',
    definition: 'Bir servis örneğini (örn: MSSQLSvc/db01.corp:1433) bir Active Directory kullanıcı veya bilgisayar hesabıyla eşleştiren benzersiz tanımlayıcı.',
    securityContext: 'SPN tanımlı kullanıcı hesapları Kerberoasting saldırısının birincil hedefidir.',
  ),
  GlossaryItem(
    term: 'NTLM (NT LAN Manager)',
    category: 'Kimlik Doğrulama',
    definition: 'Eski nesil Challenge/Response tabanlı kimlik doğrulama protokolü. Kerberos başarısız olduğunda veya IP ile bağlanıldığında devreye girer.',
    securityContext: 'Relay (NTLM Relaying) ve Pass-the-Hash saldırılarına karşı savunmasızdır; imzalamasız SMB üzerinde ölümcüldür.',
  ),
  GlossaryItem(
    term: 'NetNTLMv1 / NetNTLMv2',
    category: 'Kimlik Doğrulama',
    definition: 'Ağ üzerinde istemci ve sunucu arasında Challenge/Response aşamasında taşınan parola karması (hash).',
    securityContext: 'Pass-the-Hash ile doğrudan kullanılamaz; Responder ile yakalanıp Hashcat (mod 5600) ile çevrimdışı kırılır veya relay edilir.',
  ),
  GlossaryItem(
    term: 'PKINIT (Public Key Cryptography for Initial Authentication)',
    category: 'Kimlik Doğrulama',
    definition: 'Kerberos AS aşamasında simetrik parola yerine X.509 dijital sertifikalarıyla kimlik doğrulamayı sağlayan uzantı (RFC 4556).',
    securityContext: 'Shadow Credentials ve AD CS ESC1-ESC13 saldırılarında sertifika ile Kerberos TGT elde etmenin anahtarıdır.',
  ),
  GlossaryItem(
    term: 'FAST / Kerberos Armoring',
    category: 'Kimlik Doğrulama',
    definition: 'İstemci ve KDC arasındaki Kerberos ön-kimlik doğrulama trafiğini bilgisayar hesabı oturum anahtarıyla şifreleyen zırhlama mekanizması.',
    securityContext: 'AS-REP Roasting ve çevrimdışı parola deneme saldırılarını önler.',
  ),

  // ==========================================
  // --- YETKİLENDİRME & DELEGASYON ---
  // ==========================================
  GlossaryItem(
    term: 'RBCD (Resource-Based Constrained Delegation)',
    category: 'Yetkilendirme',
    definition: 'Bir sunucu veya servisin, kendisine kimlerin erişim yetkisi devredeceğini kendi bilgisayar hesabındaki öznitelik üzerinden belirlemesi.',
    securityContext: 'msDS-AllowedToActOnBehalfOfOtherIdentity özniteliğine yazma yetkisi olan saldırgan sunucuda anında SYSTEM yetkisi elde edebilir.',
  ),
  GlossaryItem(
    term: 'Unconstrained Delegation',
    category: 'Yetkilendirme',
    definition: 'Bir sunucunun kendisine bağlanan tüm kullanıcıların TGT biletini kendi LSASS belleğinde kopyalama hakkına sahip olması.',
    securityContext: 'Saldırgan sunucuyu ele geçirirse ve bir Domain Admin sunucuya bağlanırsa, admin TGT\'si çalınarak domain düşürülür.',
  ),
  GlossaryItem(
    term: 'Constrained Delegation (S4U2self & S4U2proxy)',
    category: 'Yetkilendirme',
    definition: 'Bir servisin yalnızca önceden belirlenmiş belirli SPN\'lere kullanıcı adına erişim devri yapabilmesini sağlayan Kerberos uzantıları.',
    securityContext: 'S4U2self ile servis kullanıcı adına bilet üretir, S4U2proxy ile bu bileti hedef servise sunar.',
  ),
  GlossaryItem(
    term: 'DACL (Discretionary Access Control List)',
    category: 'Yetkilendirme',
    definition: 'Bir Active Directory nesnesine (kullanıcı, grup, GPO) kimlerin hangi haklarla (GenericAll, WriteDacl, AllExtendedRights) erişebileceğini belirleyen liste.',
    securityContext: 'BloodHound ile analiz edilen en kritik saldırı yollarının temelini zafiyetli DACL yapılandırmaları oluşturur.',
  ),
  GlossaryItem(
    term: 'AdminSDHolder & SDProp',
    category: 'Yetkilendirme',
    definition: 'Active Directory korumalı gruplarının (Domain Admins, Enterprise Admins) ACL bütünlüğünü korumak için 60 dakikada bir çalışan şablon mekanizma.',
    securityContext: 'Saldırgan AdminSDHolder nesnesine yetki ekleyerek silinmesi ve fark edilmesi zor kalıcı bir arka kapı bırakabilir.',
  ),
  GlossaryItem(
    term: 'SID History (sIDHistory)',
    category: 'Yetkilendirme',
    definition: 'Domain migrasyonları sırasında kullanıcının eski etki alanındaki yetkilerini koruması için eklenen SID geçmişi özniteliği.',
    securityContext: 'Saldırgan bir kullanıcıya Domain Admin SID\'sini (512) bu öznitelikle ekleyerek gizli tam yetki elde edebilir.',
  ),
  GlossaryItem(
    term: 'SID Filtering',
    category: 'Yetkilendirme',
    definition: 'Forest güven ilişkileri (Forest Trust) arasında geçen Kerberos ve NTLM biletlerindeki yabancı SID değerlerini süzen güvenlik mekanizması.',
    securityContext: 'Forest Trust üzerinden Enterprise Admin atlamasını engelleyen en kritik sınır mekanizmasıdır.',
  ),

  // ==========================================
  // --- SALDIRI & KALICILIK (ATTACKS) ---
  // ==========================================
  GlossaryItem(
    term: 'Kerberoasting',
    category: 'Saldırı & Kalıcılık',
    definition: 'Ağdaki geçerli bir kullanıcıyla SPN tanımlı servis hesapları için TGS bileti talep edip, bileti belleğe çekerek çevrimdışı parola kırma saldırısı.',
    securityContext: 'RC4 şifreleme downgrade isteği yapılarak Hashcat mod 13100 ile servis hesabı parolası kırılır.',
  ),
  GlossaryItem(
    term: 'AS-REP Roasting',
    category: 'Saldırı & Kalıcılık',
    definition: 'Kerberos ön-kimlik doğrulaması kapatılmış ("Do not require Kerberos preauthentication") hesaplardan parola bilmeden AS-REP paketi çekme saldırısı.',
    securityContext: 'Dönen veri kullanıcının parola karmasıyla şifrelidir; Hashcat mod 18200 ile çevrimdışı kırılır.',
  ),
  GlossaryItem(
    term: 'Pass the Hash (PtH)',
    category: 'Saldırı & Kalıcılık',
    definition: 'Düz metin parolayı bilmeye gerek kalmadan kullanıcının NTLM hash\'ini kullanarak NTLM kimlik doğrulaması üzerinden oturum açma tekniği.',
    securityContext: 'SMB, WMI ve WinRM üzerinden yanal harekette yaygın kullanılır.',
  ),
  GlossaryItem(
    term: 'Overpass the Hash (Pass the Key)',
    category: 'Saldırı & Kalıcılık',
    definition: 'Kullanıcının NTLM veya AES hash\'ini KDC\'ye sunarak yasal bir Kerberos TGT bileti elde etme ve Kerberos servislere erişme tekniği.',
    securityContext: 'NTLM\'i Kerberos biletine dönüştürdüğü için kısıtlı NTLM ortamlarını ve log filtrelerini aşmayı sağlar.',
  ),
  GlossaryItem(
    term: 'Pass the Ticket (PtT)',
    category: 'Saldırı & Kalıcılık',
    definition: 'Çalınan veya sahte üretilen Kerberos biletlerini (.kirbi veya .ccache) mevcut oturumun bellek alanına enjekte ederek kaynaklara erişme tekniği.',
    securityContext: 'Rubeus ptt veya mimikatz kerberos::ptt ile uygulanır.',
  ),
  GlossaryItem(
    term: 'Golden Ticket',
    category: 'Saldırı & Kalıcılık',
    definition: 'KRBTGT hesabının NTLM veya AES-256 anahtarı kullanılarak üretilen ve istenilen haklara sahip sahte Kerberos TGT bileti.',
    securityContext: 'KDC tarafından doğrulanmış sayılır; 10 yıl geçerli sınırsız etki alanı hâkimiyeti sağlar.',
  ),
  GlossaryItem(
    term: 'Silver Ticket',
    category: 'Saldırı & Kalıcılık',
    definition: 'Belirli bir servis veya bilgisayar hesabının NTLM hash\'i kullanılarak üretilen ve KDC ile temas kurmayan sahte TGS bileti.',
    securityContext: 'KDC loglarında (4768/4769) iz bırakmaz; doğrudan hedef serviste yerel SYSTEM yetkisi verir.',
  ),
  GlossaryItem(
    term: 'Diamond Ticket',
    category: 'Saldırı & Kalıcılık',
    definition: 'KDC\'den meşru bir TGT talep edip, KRBTGT anahtarıyla biletin şifresini çözerek yalnızca PAC içeriğini modifiye edip yeniden şifreleme tekniği.',
    securityContext: 'Bilet KDC tarafından üretildiği için meşru bilet kimliği taşır; gelişmiş Kerberos anomali tespitlerini tamamen atlatır.',
  ),
  GlossaryItem(
    term: 'DCSync',
    category: 'Saldırı & Kalıcılık',
    definition: 'DRSUAPI protokolünü kullanarak kendini bir Domain Controller gibi gösterip diğer DC\'lerden kullanıcı parola hash\'lerini talep etme tekniği.',
    securityContext: 'Replicating Directory Changes haklarına sahip bir hesapla Mimikatz veya secretsdump üzerinden çalıştırılır.',
  ),
  GlossaryItem(
    term: 'DCShadow',
    category: 'Saldırı & Kalıcılık',
    definition: 'Geçici olarak sahte bir Domain Controller kaydederek Active Directory veritabanına doğrudan RPC replikasyonuyla öznitelik veya yetki yazma tekniği.',
    securityContext: 'Geleneksel LDAP nesne düzenleme (Event ID 5136) loglarını tetiklemez; tespiti son derece zordur.',
  ),
  GlossaryItem(
    term: 'Shadow Credentials',
    category: 'Saldırı & Kalıcılık',
    definition: 'Hedef nesnenin msDS-KeyCredentialLink özniteliğine genel anahtar ekleyerek parola bilmeden PKINIT ile Kerberos TGT alma tekniği.',
    securityContext: 'Parola sıfırlamadan ve bariz hesap modifikasyonu yapmadan sessiz kimlik doğrulaması sağlar.',
  ),
  GlossaryItem(
    term: 'Skeleton Key',
    category: 'Saldırı & Kalıcılık',
    definition: 'Domain Controller üzerinde çalışan lsass.exe sürecine yama yaparak etki alanındaki tüm kullanıcılar için geçerli bir master parola tanımlayan bellek zararlısı.',
    securityContext: 'Tüm kullanıcıların kendi parolaları geçerliliğini korurken saldırgan her hesaba girebilir.',
  ),
  GlossaryItem(
    term: 'noPac (SamAccountName Spoofing)',
    category: 'Saldırı & Kalıcılık',
    definition: 'CVE-2021-42278 ve CVE-2021-42287 zafiyetlerini birleştirerek makine adı sahteciliğiyle standart kullanıcıdan saniyeler içinde Domain Admin olma saldırısı.',
    securityContext: 'PAC içermeyen TGT talebi ve sAMAccountName değişikliğiyle KDC\'yi yanıltarak DC makine hesabı adına TGS bileti alınır.',
  ),
  GlossaryItem(
    term: 'PetitPotam (MS-EFSR)',
    category: 'Saldırı & Kalıcılık',
    definition: 'EfsRpcOpenFileRaw çağrısı üzerinden bir Domain Controller\'ı saldırganın dinleyicisine NTLM kimlik doğrulaması yapmaya zorlama (coerce) saldırısı.',
    securityContext: 'AD CS HTTP Enroll servisine veya SMB relay dinleyicisine yönlendirilerek Domain Admin yetkisi alınır.',
  ),

  // ==========================================
  // --- SAVUNMA & SERTLEŞTİRME (DEFENSE) ---
  // ==========================================
  GlossaryItem(
    term: 'LAPS (Local Administrator Password Solution)',
    category: 'Savunma & Sertleştirme',
    definition: 'Domain\'e bağlı bilgisayarların yerel Administrator parolalarını rastgele oluşturan ve Active Directory\'de şifreli saklayan Microsoft çözümü.',
    securityContext: 'Aynı yerel parola üzerinden yapılan yanal hareketi (Lateral Movement) tamamen keser.',
  ),
  GlossaryItem(
    term: 'Windows LAPS (v2)',
    category: 'Savunma & Sertleştirme',
    definition: 'Windows 10/11 ve Server 2022 içerisine yerel gömülen, Azure AD/Entra ID ve yerel AD hibrit desteği olan yeni nesil LAPS mimarisi.',
    securityContext: 'Parolayı DAPI korumalı şifreler, parola geçmişi tutar ve otomatik rotasyon sağlar.',
  ),
  GlossaryItem(
    term: 'gMSA (Group Managed Service Accounts)',
    category: 'Savunma & Sertleştirme',
    definition: 'Parolası Active Directory tarafından otomatik yönetilen, 128 karakterli ve Kerberoasting saldırılarına karşı güvenli servis hesabı türü.',
    securityContext: 'Klasik servis hesaplarının yerine gMSA kullanılması Kerberoasting riskini tamamen ortadan kaldırır.',
  ),
  GlossaryItem(
    term: 'Protected Users',
    category: 'Savunma & Sertleştirme',
    definition: 'NTLM kimlik doğrulamasını, Kerberos zayıf şifrelemelerini (DES/RC4) yasaklayan ve LSASS belleğinde kimlik bilgilerinin saklanmasını önleyen güvenlik grubu.',
    securityContext: 'Domain Admin ve hassas hesaplar bu gruba eklenerek Pass-the-Hash ve Mimikatz saldırılarından korunur.',
  ),
  GlossaryItem(
    term: 'Tiered Administration Model',
    category: 'Savunma & Sertleştirme',
    definition: 'Active Directory varlıklarını kontrol seviyesine göre ayıran (Tier 0: DC/PKI, Tier 1: Sunucular, Tier 2: İstemciler) mimari güvenlik ayrımı.',
    securityContext: 'Tier 0 kimlik bilgilerinin Tier 1 veya Tier 2 uç noktalarda oturum açmasını engelleyerek kimlik hırsızlığını sonlandırır.',
  ),
  GlossaryItem(
    term: 'PAW (Privileged Access Workstations)',
    category: 'Savunma & Sertleştirme',
    definition: 'Yalnızca Domain Controller ve kritik altyapı yönetimi için ayrılmış, internete kapalı, sertleştirilmiş özel fiziksel iş istasyonları.',
    securityContext: 'Phishing ve uç nokta zararlı yazılımlarının Tier 0 yöneticilerini ele geçirmesini engeller.',
  ),
  GlossaryItem(
    term: 'Credential Guard',
    category: 'Savunma & Sertleştirme',
    definition: 'Sanallaştırma tabanlı güvenlik (VBS) kullanarak NTLM hash\'leri ve Kerberos biletlerini izole edilmiş sanal bellek alanında (LSAIso) saklayan Windows özelliği.',
    securityContext: 'Saldırgan sistemde yerel SYSTEM veya SeDebugPrivilege yetkisi alsa bile Mimikatz ile bellekten hash çekemez.',
  ),
  GlossaryItem(
    term: 'Restricted Admin Mode',
    category: 'Savunma & Sertleştirme',
    definition: 'RDP bağlantılarında kimlik bilgilerinin uzak sunucunun belleğine gönderilmesini engelleyen ve Pass-the-Hash ile RDP oturumuna izin veren mod.',
    securityContext: 'Uzak sunucunun kompromize olması durumunda admin parolasının ele geçirilmesini önler.',
  ),
  GlossaryItem(
    term: 'NTDS.dit',
    category: 'Savunma & Sertleştirme',
    definition: 'Domain Controller üzerinde tüm kullanıcıların kimlik bilgilerini, parola hash\'lerini ve Kerberos anahtarlarını barındıran ESE veritabanı.',
    securityContext: 'VSS (Volume Shadow Copy) veya ntdsutil ile çalınırsa domainin tüm parolaları offline kırılabilir.',
  ),

  // ==========================================
  // --- AD CS & SERTİFİKA GÜVENLİĞİ (PKI) ---
  // ==========================================
  GlossaryItem(
    term: 'AD CS (Active Directory Certificate Services)',
    category: 'AD CS & PKI',
    definition: 'Active Directory ortamında açık anahtarlı şifreleme (PKI), dijital imzalama ve akıllı kart kimlik doğrulaması sağlayan sunucu rolü.',
    securityContext: 'Zafiyetli sertifika şablonları (ESC1-ESC13) üzerinden standart kullanıcıdan Domain Admin olma imkanı sunar.',
  ),
  GlossaryItem(
    term: 'ESC1 (Enrollee Supplies Subject)',
    category: 'AD CS & PKI',
    definition: 'İstemcinin sertifika talebinde Subject Alternative Name (SAN) belirleyebildiği ve istemci kimlik doğrulamasına izin veren zafiyetli şablon.',
    securityContext: 'Standart kullanıcı Administrator UPN\'i belirterek sertifika alır ve PKINIT ile Domain Admin TGT\'si talep eder.',
  ),
  GlossaryItem(
    term: 'ESC4 (Vulnerable Certificate Template Access Control)',
    category: 'AD CS & PKI',
    definition: 'Standart veya düşük yetkili bir kullanıcının sertifika şablonunun DACL izinlerinde Write veya GenericAll yetkisine sahip olması.',
    securityContext: 'Saldırgan şablonu ESC1 zafiyetine dönüştürerek istediği hesap adına sertifika üretir ve yetki yükseltir.',
  ),
  GlossaryItem(
    term: 'ESC8 (AD CS NTLM Relay to HTTP Enrollment)',
    category: 'AD CS & PKI',
    definition: 'AD CS web kayıt servisinin (HTTP /certsrv) NTLM kimlik doğrulamasında EPA ve SMB signing koruması olmaması zafiyeti.',
    securityContext: 'PetitPotam ile DC tetiklenir, DC makine hesabı NTLM doğrulaması HTTP /certsrv servisine relay edilir ve DC adına sertifika alınır.',
  ),
  GlossaryItem(
    term: 'SAN (Subject Alternative Name)',
    category: 'AD CS & PKI',
    definition: 'X.509 sertifikalarında sertifikanın hangi kullanıcılara (UPN) veya DNS adlarına ait olduğunu belirten genişletilmiş kimlik alanı.',
    securityContext: 'Saldırgan SAN alanına başka bir kullanıcının UPN değerini yazarak o kullanıcının kimliğine bürünür.',
  ),
];

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _filter = '';
  String _selectedCategory = 'Tümü';

  final List<String> _categories = const [
    'Tümü',
    'Kimlik Doğrulama',
    'Yetkilendirme',
    'Saldırı & Kalıcılık',
    'Savunma & Sertleştirme',
    'AD CS & PKI',
  ];

  Color _categoryColor(String category) {
    switch (category) {
      case 'Kimlik Doğrulama':
        return AppTheme.blueTeam;
      case 'Yetkilendirme':
        return AppTheme.toolsAmber;
      case 'Saldırı & Kalıcılık':
        return AppTheme.redTeam;
      case 'Savunma & Sertleştirme':
        return AppTheme.sysAdmin;
      case 'AD CS & PKI':
        return const Color(0xFFA855F7); // Mor
      default:
        return AppTheme.blueTeam;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kGlossaryItems.where((item) {
      final matchesCategory = _selectedCategory == 'Tümü' || item.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return item.term.toLowerCase().contains(q) ||
          item.definition.toLowerCase().contains(q) ||
          item.securityContext.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.menu_book, color: AppTheme.blueTeam, size: 22),
            SizedBox(width: 8),
            Text('AD Terimler ve Kavramlar Sözlüğü'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Arama Girişi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _filter = val),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Kavram, protokol veya saldırı ara... (Örn: Kerberos, PAC, ESC1)',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppTheme.blueTeam),
                ),
              ),
            ),
          ),

          // Kategori Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppTheme.blueTeam.withAlpha(50),
                    checkmarkColor: AppTheme.blueTeam,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    backgroundColor: AppTheme.bgCard,
                    side: BorderSide(
                      color: isSelected ? AppTheme.blueTeam : AppTheme.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Liste
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final tagColor = _categoryColor(item.category);

                return Card(
                  color: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.term,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tagColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tagColor.withAlpha(70)),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: tagColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.definition,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131A26),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderHighlight),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.security, size: 14, color: AppTheme.redTeam),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.securityContext,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Tanımı Kopyala',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: '${item.term}: ${item.definition}\nOperasyonel Bağlam: ${item.securityContext}'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Terim tanımı kopyalandı!'), duration: Duration(seconds: 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
