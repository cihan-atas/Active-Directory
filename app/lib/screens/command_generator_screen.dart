import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/command_model.dart';
import '../services/command_service.dart';
import '../services/scratchpad_service.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';
import 'scratchpad_screen.dart';

class CommandGeneratorScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialTool;
  final String? initialCategory;
  final OpsecTag? initialOpsecTag;

  final CommandPillar? initialPillar;

  const CommandGeneratorScreen({
    super.key,
    this.initialSearchQuery,
    this.initialTool,
    this.initialCategory,
    this.initialOpsecTag,
    this.initialPillar,
  });

  @override
  State<CommandGeneratorScreen> createState() => _CommandGeneratorScreenState();
}

/// Popüler Araç Ailesi Tanımı ve Akıllı Filtre Eşleyicisi
class PopularToolInfo {
  final String key;
  final String label;
  final bool Function(String tool) matcher;

  const PopularToolInfo({
    required this.key,
    required this.label,
    required this.matcher,
  });
}

class _CommandGeneratorScreenState extends State<CommandGeneratorScreen> {
  final CommandService _service = CommandService();
  bool _isLoading = true;
  bool _isContextExpanded = false;

  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  String _selectedTool = 'Tümü';
  String _selectedPlatform = 'Tümü';
  String _selectedFilterType = 'all'; // all, favorites, custom
  OpsecTag _selectedOpsecTag = OpsecTag.all;
  CommandPillar _selectedPillar = CommandPillar.all;

  // Popüler Araç Aileleri (Büyük/Küçük harf ve takma ad duyarsız)
  static final List<PopularToolInfo> popularToolList = [
    PopularToolInfo(
      key: 'Mimikatz',
      label: 'Mimikatz',
      matcher: (t) => t.toLowerCase().contains('mimikatz'),
    ),
    PopularToolInfo(
      key: 'BloodHound',
      label: 'BloodHound',
      matcher: (t) {
        final l = t.toLowerCase();
        return l.contains('hound') || l.contains('bloodhound');
      },
    ),
    PopularToolInfo(
      key: 'Certipy',
      label: 'Certipy',
      matcher: (t) => t.toLowerCase().contains('certipy'),
    ),
    PopularToolInfo(
      key: 'Rubeus',
      label: 'Rubeus',
      matcher: (t) => t.toLowerCase().contains('rubeus'),
    ),
    PopularToolInfo(
      key: 'NetExec',
      label: 'NetExec (nxc)',
      matcher: (t) {
        final l = t.toLowerCase();
        return l == 'nxc' || l.contains('netexec');
      },
    ),
    PopularToolInfo(
      key: 'Impacket',
      label: 'Impacket',
      matcher: (t) => t.toLowerCase().contains('impacket'),
    ),
    PopularToolInfo(
      key: 'PowerView',
      label: 'PowerView',
      matcher: (t) {
        final l = t.toLowerCase();
        return l.contains('powerview') || l.startsWith('get-domain') || l.startsWith('find-domain');
      },
    ),
    PopularToolInfo(
      key: 'Hashcat',
      label: 'Hashcat',
      matcher: (t) => t.toLowerCase().contains('hashcat'),
    ),
    PopularToolInfo(
      key: 'bloodyAD',
      label: 'bloodyAD',
      matcher: (t) => t.toLowerCase().contains('bloodyad'),
    ),
    PopularToolInfo(
      key: 'Responder',
      label: 'Responder',
      matcher: (t) => t.toLowerCase().contains('responder'),
    ),
  ];

  // Performans İçin Önbelleklenmiş (Cached / Pre-computed) Durum Değişkenleri
  List<VaultCommand> _filteredCommands = [];
  Map<String, int> _toolCounts = {};
  List<String> _tools = ['Tümü'];
  Map<String, int> _popularToolCounts = {};
  Map<String, int> _categoryCounts = {};
  List<String> _categories = ['Tümü'];
  int _redTeamCount = 0;
  int _blueTeamCount = 0;
  int _systemCount = 0;
  int _linuxCount = 0;
  int _powershellCount = 0;
  int _windowsCmdCount = 0;

  // Arama & Debounce Kontrolleri
  late TextEditingController _searchController;
  Timer? _searchDebounceTimer;

  // Form Controller'ları
  late TextEditingController _domainController;
  late TextEditingController _netbiosController;
  late TextEditingController _dcIpController;
  late TextEditingController _dcHostController;
  late TextEditingController _targetIpController;
  late TextEditingController _targetHostController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _hashController;
  late TextEditingController _ticketController;
  late TextEditingController _spnController;
  late TextEditingController _caNameController;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!;
    }
    _searchController = TextEditingController(text: _searchQuery);
    if (widget.initialTool != null && widget.initialTool!.isNotEmpty) {
      _selectedTool = widget.initialTool!;
    }
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialOpsecTag != null) {
      _selectedOpsecTag = widget.initialOpsecTag!;
    }
    if (widget.initialPillar != null) {
      _selectedPillar = widget.initialPillar!;
    }
    _initControllers(const TargetContext());
    _loadData();
  }

  void _initControllers(TargetContext ctx) {
    _domainController = TextEditingController(text: ctx.domain);
    _netbiosController = TextEditingController(text: ctx.netbios);
    _dcIpController = TextEditingController(text: ctx.dcIp);
    _dcHostController = TextEditingController(text: ctx.dcHost);
    _targetIpController = TextEditingController(text: ctx.targetIp);
    _targetHostController = TextEditingController(text: ctx.targetHost);
    _userController = TextEditingController(text: ctx.user);
    _passController = TextEditingController(text: ctx.pass);
    _hashController = TextEditingController(text: ctx.hash);
    _ticketController = TextEditingController(text: ctx.ticket);
    _spnController = TextEditingController(text: ctx.spn);
    _caNameController = TextEditingController(text: ctx.caName);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _domainController.dispose();
    _netbiosController.dispose();
    _dcIpController.dispose();
    _dcHostController.dispose();
    _targetIpController.dispose();
    _targetHostController.dispose();
    _userController.dispose();
    _passController.dispose();
    _hashController.dispose();
    _ticketController.dispose();
    _spnController.dispose();
    _caNameController.dispose();
    super.dispose();
  }

  /// 180ms Debounced Arama Girişi (60 FPS Pürüzsüz Yazım Deneyimi)
  void _onSearchChanged(String val) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = val;
        _applyFilters();
      });
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _service.init();
    _updateControllersFromService();
    _initPrecomputedData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateControllersFromService() {
    final ctx = _service.targetContext;
    _domainController.text = ctx.domain;
    _netbiosController.text = ctx.netbios;
    _dcIpController.text = ctx.dcIp;
    _dcHostController.text = ctx.dcHost;
    _targetIpController.text = ctx.targetIp;
    _targetHostController.text = ctx.targetHost;
    _userController.text = ctx.user;
    _passController.text = ctx.pass;
    _hashController.text = ctx.hash;
    _ticketController.text = ctx.ticket;
    _spnController.text = ctx.spn;
    _caNameController.text = ctx.caName;
  }

  void _onContextChanged() {
    final newCtx = TargetContext(
      domain: _domainController.text.trim(),
      netbios: _netbiosController.text.trim(),
      dcIp: _dcIpController.text.trim(),
      dcHost: _dcHostController.text.trim(),
      targetIp: _targetIpController.text.trim(),
      targetHost: _targetHostController.text.trim(),
      user: _userController.text.trim(),
      pass: _passController.text.trim(),
      hash: _hashController.text.trim(),
      ticket: _ticketController.text.trim(),
      spn: _spnController.text.trim(),
      caName: _caNameController.text.trim(),
    );
    _service.updateTargetContext(newCtx);
    setState(() {});
  }

  void _initPrecomputedData() {
    final allCmds = _service.allCommands;

    // 1. Araç Sayımları & Sıralı Liste
    final tMap = <String, int>{};
    for (var c in allCmds) {
      final t = c.tool.trim();
      if (t.isNotEmpty) {
        tMap[t] = (tMap[t] ?? 0) + 1;
      }
    }
    _toolCounts = tMap;

    final sortedTools = tMap.keys.toList()
      ..sort((a, b) {
        final countA = tMap[a] ?? 0;
        final countB = tMap[b] ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });
    _tools = ['Tümü', ...sortedTools];

    // 2. Popüler Araç Ailesi Sayımları (Mimikatz, BloodHound, Certipy vb.)
    final pMap = <String, int>{};
    for (final p in popularToolList) {
      pMap[p.key] = allCmds.where((c) => p.matcher(c.tool)).length;
    }
    _popularToolCounts = pMap;

    // 3. Kategori Sayımları & Listesi
    final catMap = <String, int>{};
    final catSet = <String>{'Tümü'};
    for (var uCat in _service.userCategories) {
      if (uCat.trim().isNotEmpty) catSet.add(uCat.trim());
    }
    for (var c in allCmds) {
      final cat = c.category.trim();
      if (cat.isNotEmpty) {
        catMap[cat] = (catMap[cat] ?? 0) + 1;
        catSet.add(cat);
      }
      if (c.customCategory != null && c.customCategory!.trim().isNotEmpty) {
        final custCat = c.customCategory!.trim();
        catMap[custCat] = (catMap[custCat] ?? 0) + 1;
        catSet.add(custCat);
      }
    }
    _categoryCounts = catMap;
    _categories = catSet.toList();

    // 4. Sütun (Pillar) Sayımları
    int red = 0, blue = 0, sys = 0;
    for (var c in allCmds) {
      switch (c.pillar) {
        case CommandPillar.redTeam:
          red++;
          break;
        case CommandPillar.blueTeam:
          blue++;
          break;
        case CommandPillar.system:
          sys++;
          break;
        default:
          break;
      }
    }
    _redTeamCount = red;
    _blueTeamCount = blue;
    _systemCount = sys;

    // 5. Platform Sayımları
    int lnx = 0, ps = 0, win = 0;
    for (var c in allCmds) {
      final plat = c.platform.toLowerCase();
      if (plat.contains('linux')) lnx++;
      if (plat.contains('powershell')) ps++;
      if (plat.contains('windows')) win++;
    }
    _linuxCount = lnx;
    _powershellCount = ps;
    _windowsCmdCount = win;

    // İlk filtrelemeyi hesapla
    _applyFilters();
  }

  /// Akıllı Araç Eşleyicisi (Takma Ad, Büyük/Küçük Harf ve Aile Desteği)
  bool _matchesTool(String cmdTool, String selectedTool) {
    if (selectedTool == 'Tümü') return true;

    // 1. Popüler Araç Ailesi Kontrolü
    for (final p in popularToolList) {
      if (p.key.toLowerCase() == selectedTool.toLowerCase() ||
          p.label.toLowerCase() == selectedTool.toLowerCase()) {
        return p.matcher(cmdTool);
      }
    }

    // 2. Normal Araç Adı Eşleşmesi
    final c = cmdTool.trim().toLowerCase();
    final s = selectedTool.trim().toLowerCase();
    return c == s || c.contains(s) || s.contains(c);
  }

  /// Filtreleri Tek Seferde Çalıştır ve _filteredCommands Listesini Sakla
  void _applyFilters() {
    final allCmds = _service.allCommands;
    final q = _searchQuery.trim().toLowerCase();
    final hasSearch = q.isNotEmpty;
    final isFav = _selectedFilterType == 'favorites';
    final isCustom = _selectedFilterType == 'custom';
    final hasPlatform = _selectedPlatform != 'Tümü';
    final hasCategory = _selectedCategory != 'Tümü';
    final hasTool = _selectedTool != 'Tümü';
    final hasOpsec = _selectedOpsecTag != OpsecTag.all;
    final hasPillar = _selectedPillar != CommandPillar.all;

    if (!hasSearch && !isFav && !isCustom && !hasPlatform && !hasCategory && !hasTool && !hasOpsec && !hasPillar) {
      _filteredCommands = List.of(allCmds);
      return;
    }

    _filteredCommands = allCmds.where((cmd) {
      if (hasPillar && cmd.pillar != _selectedPillar) return false;
      if (isFav && !cmd.isFavorite) return false;
      if (isCustom && !cmd.isUserCreated) return false;

      if (hasPlatform) {
        final p = cmd.platform.toLowerCase();
        if (_selectedPlatform == 'Linux' && !p.contains('linux')) return false;
        if (_selectedPlatform == 'PowerShell' && !p.contains('powershell')) return false;
        if (_selectedPlatform == 'Windows CMD' && !p.contains('windows')) return false;
      }

      if (hasCategory) {
        if (cmd.category != _selectedCategory && cmd.customCategory != _selectedCategory) {
          return false;
        }
      }

      if (hasTool) {
        if (!_matchesTool(cmd.tool, _selectedTool)) {
          return false;
        }
      }

      if (hasOpsec) {
        if (!cmd.opsecTags.contains(_selectedOpsecTag)) return false;
      }

      if (hasSearch) {
        if (!cmd.searchCorpus.contains(q)) {
          final inNote = cmd.userNote != null && cmd.userNote!.toLowerCase().contains(q);
          if (!inNote) return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _isFilterActive =>
      _searchQuery.trim().isNotEmpty ||
      _selectedPillar != CommandPillar.all ||
      _selectedPlatform != 'Tümü' ||
      _selectedCategory != 'Tümü' ||
      _selectedTool != 'Tümü' ||
      _selectedFilterType != 'all' ||
      _selectedOpsecTag != OpsecTag.all;

  @override
  Widget build(BuildContext context) {
    final ctx = _service.targetContext;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚡ Komut Oluşturucu',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              _isLoading
                  ? 'Katalog yükleniyor...'
                  : '${_filteredCommands.length} / ${_service.allCommands.length} Operasyonel Komut',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.toolsAmber),
            tooltip: 'Topluluk Paketi (İçe / Dışa Aktar)',
            onPressed: _showCommunityPackDialog,
          ),
          IconButton(
            icon: Icon(
              _isContextExpanded ? Icons.tune : Icons.tune_outlined,
              color: _isContextExpanded ? AppTheme.redTeam : AppTheme.textSecondary,
            ),
            tooltip: 'Hedef Değişkenleri Paneli',
            onPressed: () {
              setState(() => _isContextExpanded = !_isContextExpanded);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.redTeam,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Komut Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditCommandDialog(null),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.redTeam),
                  SizedBox(height: 16),
                  Text('3.300+ Operasyonel Komut ve Cephanelik Hazırlanıyor...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : Column(
              children: [
                // 1. Hedef Bağlamı ve Değişken Paneli (Açılır / Kapanır)
                _buildTargetContextPanel(ctx),

                // 2. Arama ve Filtre Kontrolleri
                _buildSearchAndFilters(),

                // 3. Canlı Filtre ve Sonuç Sayaç Çubuğu
                _buildResultsBar(),

                // 4. Komut Listesi
                Expanded(
                  child: _filteredCommands.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                          cacheExtent: 600,
                          itemCount: _filteredCommands.length,
                          itemBuilder: (context, index) {
                            final cmd = _filteredCommands[index];
                            return _buildCommandCard(cmd, ctx);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// Hedef Parametreleri Giriş Paneli
  Widget _buildTargetContextPanel(TargetContext ctx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isContextExpanded ? AppTheme.redTeam.withAlpha(180) : AppTheme.border,
          width: _isContextExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Başlık ve Özet Çubuğu
          InkWell(
            onTap: () => setState(() => _isContextExpanded = !_isContextExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.redTeam.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.hub, color: AppTheme.redTeam, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HEDEF PARAMETRELERİ (CANLI YER TUTUCULAR)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.9,
                            color: AppTheme.redTeam,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ctx.domain}  •  ${ctx.dcIp}  •  ${ctx.user}',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isContextExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Genişletilebilir Giriş Formu
          if (_isContextExpanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSmallTextField('Domain (FQDN)', _domainController, 'corp.local')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallTextField('NetBIOS', _netbiosController, 'CORP')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildSmallTextField('Domain Controller IP', _dcIpController, '10.10.10.5')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallTextField('DC Host Adı', _dcHostController, 'DC01')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildSmallTextField('Hedef IP', _targetIpController, '10.10.10.20')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallTextField('Hedef Host Adı', _targetHostController, 'SRV-SQL01')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildSmallTextField('Kullanıcı', _userController, 'Administrator')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallTextField('Parola', _passController, 'Password123!')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSmallTextField('NTLM Hash (:NTLM veya LM:NTLM)', _hashController, 'e19ccf7504d36cedc34e212d4e6547e0'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildSmallTextField('SPN Servis Adı', _spnController, 'cifs/SRV-SQL01.corp.local')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallTextField('Sertifika Şablonu', _caNameController, 'ESC1')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.toolsAmber,
                          side: const BorderSide(color: AppTheme.toolsAmber),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('Ganimet Defterinden Yükle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _showPickFromScratchpadSheet,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Sıfırla', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _initControllers(const TargetContext());
                          _onContextChanged();
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.blueTeam,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Kapat', style: TextStyle(fontSize: 12)),
                        onPressed: () => setState(() => _isContextExpanded = false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPickFromScratchpadSheet() {
    final scratchpad = ScratchpadService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: AppTheme.toolsAmber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ganimet Defterinden Yükle',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.blueTeam),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Defteri Aç', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScratchpadScreen()),
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 12),
              if (scratchpad.items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 36, color: AppTheme.textMuted),
                        const SizedBox(height: 10),
                        const Text('Henüz kayıtlı bir ganimet yok.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ganimet Defterine Git'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScratchpadScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: scratchpad.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = scratchpad.items[index];
                      final catColor = Color(item.category.badgeColorHex);
                      return InkWell(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          await scratchpad.sendToCommandContext(item);
                          if (!mounted) return;
                          _initControllers(_service.targetContext);
                          _onContextChanged();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('⚡ ${item.title} canlı hedef bağlamına aktarıldı!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCode,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: catColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(item.category.icon, size: 18, color: catColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.primaryValue,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppTheme.toolsAmber),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item.secondaryValue != null && item.secondaryValue!.isNotEmpty)
                                      Text(
                                        item.secondaryValue!,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.toolsAmber),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 12.5, color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            filled: true,
            fillColor: AppTheme.bgDark,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.redTeam)),
          ),
          onChanged: (_) => _onContextChanged(),
        ),
      ],
    );
  }

  /// Arama ve Filtreleme Bileşeni
  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          // Arama Girişi
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Komut, araç, Event ID veya açıklama ara...',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchDebounceTimer?.cancel();
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.bgCard,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 8),

          // Sütun / Rol Filtre Barı (Red, Blue, System, All)
          _buildPillarFilterBar(),
          const SizedBox(height: 8),

          // Tip & Platform Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tümü (${_service.allCommands.length})', _selectedFilterType == 'all', () {
                  setState(() {
                    _selectedFilterType = 'all';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 6),
                _buildFilterChip('⭐ Favoriler (${_service.favoriteCommands.length})', _selectedFilterType == 'favorites', () {
                  setState(() {
                    _selectedFilterType = 'favorites';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 6),
                _buildFilterChip('👤 Özel (${_service.customCommands.length})', _selectedFilterType == 'custom', () {
                  setState(() {
                    _selectedFilterType = 'custom';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 12),
                Container(height: 18, width: 1, color: AppTheme.border),
                const SizedBox(width: 12),
                _buildFilterChip('🐧 Linux ($_linuxCount)', _selectedPlatform == 'Linux', () {
                  setState(() {
                    _selectedPlatform = _selectedPlatform == 'Linux' ? 'Tümü' : 'Linux';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 6),
                _buildFilterChip('⚡ PowerShell ($_powershellCount)', _selectedPlatform == 'PowerShell', () {
                  setState(() {
                    _selectedPlatform = _selectedPlatform == 'PowerShell' ? 'Tümü' : 'PowerShell';
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 6),
                _buildFilterChip('🪟 Windows CMD ($_windowsCmdCount)', _selectedPlatform == 'Windows CMD', () {
                  setState(() {
                    _selectedPlatform = _selectedPlatform == 'Windows CMD' ? 'Tümü' : 'Windows CMD';
                    _applyFilters();
                  });
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // OPSEC Davranış ve Güvenlik Filtresi
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: OpsecTag.values.map((tag) {
                final isSelected = _selectedOpsecTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedOpsecTag = isSelected && tag != OpsecTag.all ? OpsecTag.all : tag;
                        _applyFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? tag.color.withAlpha(35) : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? tag.color : AppTheme.border,
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tag.icon, size: 12, color: isSelected ? tag.color : AppTheme.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            tag.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? tag.color : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Kategori Seçici ve Hızlı Filtre Barı
          _buildCategoryFilterBar(),
          const SizedBox(height: 8),

          // Araç Seçici ve Popüler Araçlar Barı
          _buildToolFilterBar(),
        ],
      ),
    );
  }

  /// Sütun / Rol Filtre Barı (Red, Blue, System, All)
  Widget _buildPillarFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CommandPillar.values.map((p) {
          final isSelected = _selectedPillar == p;
          final count = switch (p) {
            CommandPillar.all => _service.allCommands.length,
            CommandPillar.redTeam => _redTeamCount,
            CommandPillar.blueTeam => _blueTeamCount,
            CommandPillar.system => _systemCount,
          };

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPillar = isSelected && p != CommandPillar.all ? CommandPillar.all : p;
                  _applyFilters();
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? p.color.withAlpha(40) : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? p.color : AppTheme.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.icon, size: 13, color: isSelected ? p.color : AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? p.color.withAlpha(50) : Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? p.color : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Modern Kategori Seçim ve Hızlı Erişim Barı
  Widget _buildCategoryFilterBar() {
    final activeCount = _selectedCategory == 'Tümü'
        ? _service.allCommands.length
        : (_categoryCounts[_selectedCategory] ?? 0);
    final isCustomSelected = _selectedCategory != 'Tümü';

    return Row(
      children: [
        // 1. Ana Kategori Açılır Menü / BottomSheet Butonu
        Expanded(
          child: InkWell(
            onTap: _showCategorySelectorModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
              decoration: BoxDecoration(
                color: isCustomSelected ? AppTheme.blueTeam.withAlpha(45) : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCustomSelected ? AppTheme.blueTeam : AppTheme.border,
                  width: isCustomSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category_rounded,
                    size: 15,
                    color: isCustomSelected ? AppTheme.blueTeam : AppTheme.toolsAmber,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      isCustomSelected
                          ? _selectedCategory
                          : '📂 Tüm Kategoriler (${_categories.length - 1} Kategori)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCustomSelected ? FontWeight.bold : FontWeight.w600,
                        color: isCustomSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCustomSelected ? AppTheme.blueTeam.withAlpha(60) : Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isCustomSelected ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isCustomSelected ? AppTheme.blueTeam : AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Eğer seçili bir kategori varsa, "Tümü"ne dönme sıfırlama butonu
        if (isCustomSelected) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = 'Tümü';
                _applyFilters();
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7.5),
              decoration: BoxDecoration(
                color: AppTheme.redTeam.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.redTeam.withAlpha(100)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 14, color: AppTheme.redTeam),
                  SizedBox(width: 3),
                  Text('Tümü', style: TextStyle(fontSize: 11, color: AppTheme.redTeam, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(width: 6),
        // + Kategori Ekle
        InkWell(
          onTap: _showCreateCategoryDialog,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7.5),
            decoration: BoxDecoration(
              color: AppTheme.toolsAmber.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.toolsAmber.withAlpha(140)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.create_new_folder_outlined, size: 14, color: AppTheme.toolsAmber),
                SizedBox(width: 4),
                Text(
                  'Yeni',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.toolsAmber,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Modern Araç Seçim ve Popüler Araçlar Hızlı Erişim Barı
  Widget _buildToolFilterBar() {
    final activeCount = _selectedTool == 'Tümü'
        ? _service.allCommands.length
        : (_popularToolCounts[_selectedTool] ?? _toolCounts[_selectedTool] ?? _filteredCommands.length);
    final isToolSelected = _selectedTool != 'Tümü';

    return Row(
      children: [
        // 1. Ana Araç Seçici Butonu
        InkWell(
          onTap: _showToolSelectorModal,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            decoration: BoxDecoration(
              color: isToolSelected ? AppTheme.redTeam.withAlpha(45) : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isToolSelected ? AppTheme.redTeam : AppTheme.border,
                width: isToolSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.handyman_rounded,
                  size: 15,
                  color: isToolSelected ? AppTheme.redTeam : AppTheme.toolsAmber,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    isToolSelected ? _selectedTool : '🛠️ Araç (${_tools.length - 1})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToolSelected ? FontWeight.bold : FontWeight.w600,
                      color: isToolSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToolSelected ? AppTheme.redTeam.withAlpha(60) : Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isToolSelected ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: isToolSelected ? AppTheme.redTeam : AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),

        // Eğer seçili bir araç varsa, "Tümü"ne dönme sıfırlama butonu
        if (isToolSelected) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              setState(() {
                _selectedTool = 'Tümü';
                _applyFilters();
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7.5),
              decoration: BoxDecoration(
                color: AppTheme.redTeam.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.redTeam.withAlpha(100)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 13, color: AppTheme.redTeam),
                  SizedBox(width: 3),
                  Text('Tümü', style: TextStyle(fontSize: 11, color: AppTheme.redTeam, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(width: 8),

        // Popüler Araçlar Yatay Kaydırılabilir Çipleri (Doğru komut sayaçları ile)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: popularToolList.map((p) {
                final isSelected = _selectedTool.toLowerCase() == p.key.toLowerCase() ||
                    _selectedTool.toLowerCase() == p.label.toLowerCase();
                final count = _popularToolCounts[p.key] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTool = isSelected ? 'Tümü' : p.key;
                        _applyFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.redTeam.withAlpha(45) : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.redTeam : AppTheme.border.withAlpha(120),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.redTeam.withAlpha(70) : Colors.white.withAlpha(14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isSelected ? Colors.white : AppTheme.toolsAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Araç Cephaneliği Modal Bottom Sheet
  void _showToolSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final allTools = _tools;

            final filteredTools = allTools.where((tool) {
              if (tool == 'Tümü') {
                return searchQuery.isEmpty;
              }
              if (searchQuery.isNotEmpty && !tool.toLowerCase().contains(searchQuery.toLowerCase())) {
                return false;
              }
              return true;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.80,
              minChildSize: 0.45,
              maxChildSize: 0.94,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      // Sürükleme Tutamacı
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Başlık Satırı
                      Row(
                        children: [
                          const Icon(Icons.handyman_rounded, color: AppTheme.redTeam, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Araç Cephaneliği & Filtresi',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${_tools.length - 1} Araç · ${_service.allCommands.length} Operasyonel Komut',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Arama Kutusu
                      TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Araç ara... (örn: certipy, rubeus, mimikatz)',
                          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setModalState(() => searchQuery = ''),
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.bgCard,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => setModalState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 10),

                      // Araç Listesi
                      Expanded(
                        child: filteredTools.isEmpty
                            ? Center(
                                child: Text(
                                  '"$searchQuery" ile eşleşen araç bulunamadı.',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredTools.length,
                                itemBuilder: (context, index) {
                                  final tool = filteredTools[index];
                                  final isSel = _selectedTool == tool;
                                  final count = tool == 'Tümü'
                                      ? _service.allCommands.length
                                      : (_toolCounts[tool] ?? 0);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Material(
                                      color: isSel ? AppTheme.redTeam.withAlpha(35) : AppTheme.bgCard,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedTool = tool;
                                            _applyFilters();
                                          });
                                          Navigator.pop(modalCtx);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSel ? AppTheme.redTeam : AppTheme.border.withAlpha(60),
                                              width: isSel ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                tool == 'Tümü' ? Icons.apps : Icons.terminal,
                                                size: 17,
                                                color: isSel ? AppTheme.redTeam : AppTheme.toolsAmber,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  tool == 'Tümü' ? 'Tüm Araçlar' : tool,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                                    color: isSel ? Colors.white : AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: isSel ? AppTheme.redTeam.withAlpha(50) : Colors.black38,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isSel ? AppTheme.redTeam : Colors.white12,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$count komut',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                                    color: isSel ? Colors.white : AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                              if (isSel) ...[
                                                const SizedBox(width: 8),
                                                const Icon(Icons.check_circle, size: 16, color: AppTheme.redTeam),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Arama, Sekmeli Filtreleme ve Canlı Sayaçlı Kategori Cephaneliği Modal Bottom Sheet
  void _showCategorySelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        String searchQuery = '';
        String selectedGroup = 'Tümü';

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final allCats = _categories;

            final filteredCats = allCats.where((cat) {
              if (cat == 'Tümü') {
                return searchQuery.isEmpty && selectedGroup == 'Tümü';
              }

              // Arama sorgusu
              if (searchQuery.isNotEmpty && !cat.toLowerCase().contains(searchQuery.toLowerCase())) {
                return false;
              }

              // Grup sekmesi filtresi
              if (selectedGroup == '🔴 Red Team') {
                return cat.startsWith('Red Team') ||
                    (!cat.startsWith('Blue Team') &&
                        !cat.startsWith('Sistem Yöneticisi') &&
                        !_service.userCategories.contains(cat) &&
                        cat != 'Özel');
              } else if (selectedGroup == '🔵 Blue Team') {
                return cat.startsWith('Blue Team');
              } else if (selectedGroup == '🟢 Sistem Yöneticisi') {
                return cat.startsWith('Sistem Yöneticisi');
              } else if (selectedGroup == '⭐ Özel') {
                return _service.userCategories.contains(cat) || cat == 'Özel';
              }

              return true;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.80,
              minChildSize: 0.45,
              maxChildSize: 0.94,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      // Sürükleme Tutamacı
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Başlık Satırı
                      Row(
                        children: [
                          const Icon(Icons.category_rounded, color: AppTheme.toolsAmber, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kategori Cephaneliği',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${_categories.length - 1} Kategori · ${_service.allCommands.length} Canlı Komut',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Hızlı Arama Kutusu
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                            hintText: 'Kategori ara... (Örn: Kerberos, Relay, Mimikatz, GPO)',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            border: InputBorder.none,
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.white60),
                                    onPressed: () => setModalState(() => searchQuery = ''),
                                  )
                                : null,
                          ),
                          onChanged: (val) => setModalState(() => searchQuery = val),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Grup Filtre Sekmeleri
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final grp in ['Tümü', '🔴 Red Team', '🔵 Blue Team', '🟢 Sistem Yöneticisi', '⭐ Özel'])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(grp, style: const TextStyle(fontSize: 11)),
                                  selected: selectedGroup == grp,
                                  selectedColor: AppTheme.blueTeam.withAlpha(60),
                                  backgroundColor: AppTheme.bgCard,
                                  labelStyle: TextStyle(
                                    color: selectedGroup == grp ? Colors.white : AppTheme.textMuted,
                                    fontWeight: selectedGroup == grp ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: selectedGroup == grp ? AppTheme.blueTeam : AppTheme.border,
                                  ),
                                  onSelected: (_) => setModalState(() => selectedGroup = grp),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 8),

                      // Kategori Listesi
                      Expanded(
                        child: filteredCats.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aramanızla eşleşen kategori bulunamadı.',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredCats.length,
                                itemBuilder: (context, idx) {
                                  final cat = filteredCats[idx];
                                  final isSel = _selectedCategory == cat;
                                  final count = cat == 'Tümü'
                                      ? _service.allCommands.length
                                      : (_categoryCounts[cat] ?? 0);

                                  Color catColor = AppTheme.toolsAmber;
                                  IconData catIcon = Icons.folder_outlined;
                                  if (cat == 'Tümü') {
                                    catColor = Colors.white;
                                    catIcon = Icons.all_inclusive_rounded;
                                  } else if (cat.startsWith('Red Team') ||
                                      (!cat.startsWith('Blue') && !cat.startsWith('Sistem') && !_service.userCategories.contains(cat))) {
                                    catColor = AppTheme.redTeam;
                                    catIcon = Icons.shield_outlined;
                                  } else if (cat.startsWith('Blue Team')) {
                                    catColor = AppTheme.blueTeam;
                                    catIcon = Icons.verified_user_outlined;
                                  } else if (cat.startsWith('Sistem Yöneticisi')) {
                                    catColor = AppTheme.sysAdmin;
                                    catIcon = Icons.dns_outlined;
                                  } else {
                                    catColor = AppTheme.toolsAmber;
                                    catIcon = Icons.star_border_rounded;
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Material(
                                      color: isSel ? catColor.withAlpha(35) : AppTheme.bgCard,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedCategory = cat;
                                            _applyFilters();
                                          });
                                          Navigator.pop(modalCtx);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSel ? catColor : AppTheme.border.withAlpha(60),
                                              width: isSel ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(catIcon, size: 17, color: catColor),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  cat,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                                    color: isSel ? Colors.white : AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: isSel ? catColor.withAlpha(50) : Colors.black38,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isSel ? catColor : Colors.white12,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$count',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                                    color: isSel ? Colors.white : AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                              if (isSel) ...[
                                                const SizedBox(width: 8),
                                                Icon(Icons.check_circle, size: 16, color: catColor),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Alt Aksiyon Butonu
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.toolsAmber,
                            side: const BorderSide(color: AppTheme.toolsAmber),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('+ Yeni Özel Kategori Oluştur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            _showCreateCategoryDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Canlı Filtre ve Sonuç Sayaç Çubuğu
  Widget _buildResultsBar() {
    final total = _service.allCommands.length;
    final matched = _filteredCommands.length;
    final percent = total > 0 ? (matched / total * 100).toStringAsFixed(1) : '0';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isFilterActive ? AppTheme.redTeam.withAlpha(140) : AppTheme.border,
          width: _isFilterActive ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isFilterActive ? AppTheme.redTeam : AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isFilterActive ? AppTheme.redTeam : AppTheme.border,
                  ),
                ),
                child: Text(
                  '$matched / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isFilterActive
                          ? '$matched komut eşleşti (Toplamın %$percent\'i)'
                          : 'Katalogdaki tüm $total komut listeleniyor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isFilterActive ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (_isFilterActive)
                      Text(
                        '${total - matched} komut filtrelendi',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
              if (_isFilterActive)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.close, size: 14, color: AppTheme.redTeam),
                  label: const Text(
                    'Sıfırla',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.redTeam, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _searchDebounceTimer?.cancel();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedPillar = CommandPillar.all;
                      _selectedCategory = 'Tümü';
                      _selectedTool = 'Tümü';
                      _selectedPlatform = 'Tümü';
                      _selectedFilterType = 'all';
                      _selectedOpsecTag = OpsecTag.all;
                      _applyFilters();
                    });
                  },
                ),
            ],
          ),

          // Aktif Filtre Hapları (Pills)
          if (_isFilterActive) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_searchQuery.trim().isNotEmpty)
                  _buildActiveFilterPill(
                    'Arama: "${_searchQuery.trim()}"',
                    () {
                      _searchDebounceTimer?.cancel();
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _applyFilters();
                      });
                    },
                  ),
                if (_selectedPillar != CommandPillar.all)
                  _buildActiveFilterPill(
                    'Sütun: ${_selectedPillar.label}',
                    () => setState(() {
                      _selectedPillar = CommandPillar.all;
                      _applyFilters();
                    }),
                  ),
                if (_selectedFilterType != 'all')
                  _buildActiveFilterPill(
                    _selectedFilterType == 'favorites' ? '⭐ Favoriler' : '👤 Özel Komutlarım',
                    () => setState(() {
                      _selectedFilterType = 'all';
                      _applyFilters();
                    }),
                  ),
                if (_selectedPlatform != 'Tümü')
                  _buildActiveFilterPill(
                    'Platform: $_selectedPlatform',
                    () => setState(() {
                      _selectedPlatform = 'Tümü';
                      _applyFilters();
                    }),
                  ),
                if (_selectedCategory != 'Tümü')
                  _buildActiveFilterPill(
                    'Kategori: $_selectedCategory',
                    () => setState(() {
                      _selectedCategory = 'Tümü';
                      _applyFilters();
                    }),
                  ),
                if (_selectedTool != 'Tümü')
                  _buildActiveFilterPill(
                    '🛠️ Araç: $_selectedTool',
                    () => setState(() {
                      _selectedTool = 'Tümü';
                      _applyFilters();
                    }),
                  ),
                if (_selectedOpsecTag != OpsecTag.all)
                  _buildActiveFilterPill(
                    'OPSEC: ${_selectedOpsecTag.label}',
                    () => setState(() {
                      _selectedOpsecTag = OpsecTag.all;
                      _applyFilters();
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFilterPill(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.redTeam.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: AppTheme.redTeam),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.redTeam.withAlpha(50) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.redTeam : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Komut Kartı Bileşeni
  Widget _buildCommandCard(VaultCommand cmd, TargetContext ctx) {
    final liveCommand = cmd.interpolate(ctx);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cmd.isUserCreated ? AppTheme.toolsAmber.withAlpha(120) : AppTheme.border,
          width: cmd.isUserCreated ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst Satır: Araç, Platform ve Rozetler
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                // Araç Rozeti (Tıklanabilir Filtre)
                Tooltip(
                  message: '${cmd.tool} komutlarını filtrele',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTool = _selectedTool == cmd.tool ? 'Tümü' : cmd.tool;
                        _applyFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _selectedTool == cmd.tool
                            ? AppTheme.redTeam
                            : AppTheme.redTeam.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedTool == cmd.tool
                              ? AppTheme.redTeam
                              : AppTheme.redTeam.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.handyman_rounded,
                            size: 11,
                            color: _selectedTool == cmd.tool ? Colors.white : AppTheme.redTeam,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cmd.tool,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedTool == cmd.tool ? Colors.white : AppTheme.redTeam,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Platform Rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    cmd.platform,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),

                if (cmd.isUserCreated) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.toolsAmber.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.toolsAmber),
                    ),
                    child: const Text(
                      'ÖZEL',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber),
                    ),
                  ),
                ],

                if (cmd.customCategory != null &&
                    cmd.customCategory!.isNotEmpty &&
                    cmd.customCategory != 'Genel' &&
                    cmd.customCategory != cmd.category) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.blueTeam.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.blueTeam.withAlpha(100)),
                    ),
                    child: Text(
                      '📁 ${cmd.customCategory}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.blueTeam),
                    ),
                  ),
                ],

                const Spacer(),

                // Favori & Not Butonu
                IconButton(
                  icon: Icon(
                    cmd.isFavorite ? Icons.star : Icons.star_border,
                    color: cmd.isFavorite ? AppTheme.toolsAmber : AppTheme.textMuted,
                    size: 20,
                  ),
                  tooltip: cmd.isFavorite ? 'Favoriyi & Notu Düzenle' : 'Favorilere Ekle',
                  onPressed: () => _showFavoriteDialog(cmd),
                ),
              ],
            ),
          ),

          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              cmd.title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          if (cmd.opsecTags.isNotEmpty) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                children: cmd.opsecTags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tag.color.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: tag.color.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tag.icon, size: 10, color: tag.color),
                        const SizedBox(width: 4),
                        Text(
                          tag.label.replaceAll(RegExp(r'^[^\s]+\s*'), ''),
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: tag.color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (cmd.whatItDoes.isNotEmpty) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                cmd.whatItDoes.replaceAll(RegExp(r'^\*+\s*'), ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Komut Kutusu (Monospace & Kopyalama)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderHighlight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    liveCommand,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF7EE787),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: liveCommand));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kopyalandı: $liveCommand'),
                        backgroundColor: AppTheme.redTeam,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.copy, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Hızlı Parametre Etiketleri
          if (cmd.parameterList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: cmd.parameterList.take(3).map((p) {
                  final flag = p['flag'] ?? '';
                  final desc = p['desc'] ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: flag,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: AppTheme.toolsAmber,
                            ),
                          ),
                          if (desc.isNotEmpty) ...[
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: desc.length > 25 ? '${desc.substring(0, 25)}...' : desc,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Kullanıcı Özel Operasyon Notu (Varsa)
          if (cmd.userNote != null && cmd.userNote!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF282110),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.toolsAmber.withAlpha(140)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.sticky_note_2, size: 14, color: AppTheme.toolsAmber),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Not: ${cmd.userNote}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFD54F), fontStyle: FontStyle.italic),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showFavoriteDialog(cmd),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.edit, size: 13, color: AppTheme.toolsAmber),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Alt Çubuk: Ne Yapar Kısa Özet ve Detay Butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(
              children: [
                if (cmd.eventIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    children: cmd.eventIds.take(2).map((id) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.blueTeam.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.blueTeam.withAlpha(80)),
                        ),
                        child: Text(
                          'ID $id',
                          style: const TextStyle(fontSize: 10, color: AppTheme.blueTeam, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (cmd.isUserCreated) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: AppTheme.textSecondary),
                    tooltip: 'Düzenle',
                    onPressed: () => _showAddEditCommandDialog(cmd),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16, color: AppTheme.redTeam),
                    tooltip: 'Sil',
                    onPressed: () async {
                      await _service.deleteCustomCommand(cmd.id);
                      setState(() {});
                    },
                  ),
                ],
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.info_outline, size: 14, color: AppTheme.blueTeam),
                  label: const Text('Detay & Parametreler', style: TextStyle(fontSize: 11.5, color: AppTheme.blueTeam)),
                  onPressed: () => _showCommandDetailSheet(cmd, liveCommand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Komut Detay Alt Sayfası
  void _showCommandDetailSheet(VaultCommand cmd, String liveCommand) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.redTeam.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.redTeam),
                        ),
                        child: Text(cmd.tool, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.redTeam)),
                      ),
                      const SizedBox(width: 8),
                      Text(cmd.platform, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(cmd.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),

                  // Canlı Komut Kutusu
                  _buildSectionHeader('CANLI DERLENMİŞ KOMUT (HEDEF BAĞLAMI)'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderHighlight),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SelectableText(
                            liveCommand,
                            style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF7EE787), fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: liveCommand));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Panoya Kopyalandı!')));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ne Yapar?
                  if (cmd.whatItDoes.isNotEmpty) ...[
                    _buildSectionHeader('NE YAPAR? (OPERASYONEL AÇIKLAMA)'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.blueTeam.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.blueTeam.withAlpha(80)),
                      ),
                      child: Text(
                        cmd.whatItDoes.replaceAll(RegExp(r'^\*+\s*'), ''),
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ne Zaman Kullanılır?
                  if (cmd.whenToUse.isNotEmpty) ...[
                    _buildSectionHeader('NE ZAMAN KULLANILIR? (OPERASYONEL AŞAMA)'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.toolsAmber.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.toolsAmber.withAlpha(80)),
                      ),
                      child: Text(
                        cmd.whenToUse.replaceAll(RegExp(r'^\*+\s*'), ''),
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Parametreler ve Bayrak Analizi
                  if (cmd.parameterList.isNotEmpty || cmd.parameters.isNotEmpty) ...[
                    _buildSectionHeader('KULLANILAN PARAMETRELER VE BAYRAK ANALİZİ'),
                    if (cmd.parameterList.isNotEmpty) ...[
                      Column(
                        children: cmd.parameterList.map((p) {
                          final flag = p['flag'] ?? '';
                          final desc = p['desc'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.toolsAmber.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.toolsAmber.withAlpha(120)),
                                  ),
                                  child: Text(
                                    flag,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: AppTheme.toolsAmber,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    desc,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(cmd.parameters, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // OPSEC ve Event ID'ler
                  if (cmd.opsec.isNotEmpty || cmd.eventIds.isNotEmpty) ...[
                    _buildSectionHeader('OPSEC VE TESPİT İMZALARI'),
                    if (cmd.eventIds.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: cmd.eventIds.map((id) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.blueTeam.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.blueTeam),
                            ),
                            child: Text('Windows Security Event ID $id', style: const TextStyle(fontSize: 11, color: AppTheme.blueTeam, fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (cmd.opsec.isNotEmpty)
                      Text(cmd.opsec, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                  ],

                  // İlgili Dokümana Git Butonu
                  if (cmd.docId != null || cmd.docPath != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.redTeam.withAlpha(40),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.redTeam, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.menu_book, color: AppTheme.redTeam, size: 20),
                        label: Text(
                          cmd.tool.length <= 25 ? '${cmd.tool} Rehberini Aç' : 'İlgili Dokümanı Aç',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          final targetId = cmd.docPath ?? cmd.docId ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleScreen(articleId: targetId, initialTitle: cmd.tool),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.9, color: AppTheme.toolsAmber),
      ),
    );
  }

  /// Yeni Komut Ekleme veya Düzenleme Diyaloğu
  void _showAddEditCommandDialog(VaultCommand? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final toolCtrl = TextEditingController(text: existing?.tool ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'Özel');
    final templateCtrl = TextEditingController(text: existing?.template ?? existing?.rawCommand ?? '');
    final whatCtrl = TextEditingController(text: existing?.whatItDoes ?? '');
    final whenCtrl = TextEditingController(text: existing?.whenToUse ?? '');
    final paramsCtrl = TextEditingController(text: existing?.parameters ?? '');
    final opsecCtrl = TextEditingController(text: existing?.opsec ?? '');
    String platform = existing?.platform ?? 'Linux CLI';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgDark,
              title: Text(existing == null ? '⚡ Yeni Özel Komut Ekle' : '⚡ Komutu Düzenle', style: const TextStyle(fontSize: 16)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Komut Başlığı', hintText: 'Örn: Hashcat ile NTLM Kırma'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: toolCtrl,
                              decoration: const InputDecoration(labelText: 'Araç Adı', hintText: 'hashcat / rubeus'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: platform,
                              decoration: const InputDecoration(labelText: 'Platform'),
                              dropdownColor: AppTheme.bgCard,
                              items: const [
                                DropdownMenuItem(value: 'Linux CLI', child: Text('Linux CLI')),
                                DropdownMenuItem(value: 'PowerShell', child: Text('PowerShell')),
                                DropdownMenuItem(value: 'Windows CMD / Binary', child: Text('Windows CMD')),
                                DropdownMenuItem(value: 'Linux / Cross-Platform', child: Text('Çapraz Platform')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => platform = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: templateCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Komut Şablonu (Yer Tutucular Desteklenir)',
                          hintText: 'impacket-secretsdump -hashes :{{hash}} {{domain}}/{{user}}@{{dc_ip}}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: whatCtrl,
                        decoration: const InputDecoration(labelText: 'Ne Yapar? (Opsiyonel)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: whenCtrl,
                        decoration: const InputDecoration(labelText: 'Ne Zaman Kullanılır? (Opsiyonel)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: paramsCtrl,
                        decoration: const InputDecoration(labelText: 'Parametreler (Opsiyonel)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: opsecCtrl,
                        decoration: const InputDecoration(labelText: 'OPSEC / Risk Notu (Opsiyonel)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('İptal'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
                  child: Text(existing == null ? 'Kaydet' : 'Güncelle'),
                  onPressed: () async {
                    if (templateCtrl.text.trim().isEmpty) return;

                    final newCmd = VaultCommand(
                      id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      tool: toolCtrl.text.trim().isEmpty ? 'Özel' : toolCtrl.text.trim(),
                      category: catCtrl.text.trim().isEmpty ? 'Özel' : catCtrl.text.trim(),
                      platform: platform,
                      title: titleCtrl.text.trim().isEmpty ? 'Özel Komut' : titleCtrl.text.trim(),
                      rawCommand: templateCtrl.text.trim(),
                      template: templateCtrl.text.trim(),
                      whatItDoes: whatCtrl.text.trim(),
                      whenToUse: whenCtrl.text.trim(),
                      parameters: paramsCtrl.text.trim(),
                      opsec: opsecCtrl.text.trim(),
                      eventIds: existing?.eventIds ?? [],
                      isUserCreated: true,
                      isFavorite: existing?.isFavorite ?? false,
                    );

                    final nav = Navigator.of(context);
                    if (existing == null) {
                      await _service.addCustomCommand(newCmd);
                    } else {
                      await _service.updateCustomCommand(newCmd);
                    }

                    if (!mounted) return;
                    nav.pop();
                    setState(() {});
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Topluluk Paketi Paylaşma ve İçe Aktarma
  void _showCommunityPackDialog() {
    final importCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgDark,
          title: const Row(
            children: [
              Icon(Icons.hub, color: AppTheme.toolsAmber, size: 20),
              SizedBox(width: 8),
              Text('Topluluk Komut Paketleri', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kendi özel komutlarınızı arkadaşlarınızla paylaşabilir veya topluluktan gelen bir paketi içe aktarabilirsiniz.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text('ÖZEL KOMUTLARIMI DIŞA AKTAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber)),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bgCard),
                    icon: const Icon(Icons.file_upload, size: 16, color: Colors.white),
                    label: Text('${_service.customCommands.length} Özel Komutu Panoya Kopyala (JSON)'),
                    onPressed: () {
                      final jsonString = _service.exportToCommunityPack(
                        packName: 'Özel Komutlarım',
                        author: 'Zeus',
                        description: 'Active Directory Vault Özel Komut Paketi',
                      );
                      Clipboard.setData(ClipboardData(text: jsonString));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Paket JSON formatında panoya kopyalandı!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text('TOPLULUK PAKETİNİ İÇE AKTAR (JSON)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.blueTeam)),
                const SizedBox(height: 6),
                TextField(
                  controller: importCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: '{"name": "CRTP Pack", "commands": [...]} yapıştırın...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Kapat'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueTeam),
              child: const Text('Paketi İçe Aktar'),
              onPressed: () async {
                final text = importCtrl.text.trim();
                if (text.isEmpty) return;

                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final count = await _service.importFromCommunityPack(text);
                  if (!mounted) return;
                  nav.pop();
                  setState(() {});
                  messenger.showSnackBar(
                    SnackBar(content: Text('Tebrikler! $count adet yeni komut kütüphanenize eklendi.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Hata: Geçersiz paket formatı ($e)')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Yeni Kullanıcı Kategorisi Oluşturma Diyaloğu
  void _showCreateCategoryDialog() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgDark,
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: AppTheme.toolsAmber, size: 20),
              SizedBox(width: 8),
              Text('Yeni Kategori Oluştur', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: TextField(
            controller: catCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Örn: CRTP Sınavı, HTB Zephyr, Müşteri X...',
              labelText: 'Kategori Adı',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.toolsAmber, foregroundColor: Colors.black),
              onPressed: () async {
                final name = catCtrl.text.trim();
                if (name.isNotEmpty) {
                  final nav = Navigator.of(context);
                  await _service.addUserCategory(name);
                  if (!mounted) return;
                  nav.pop();
                  setState(() {
                    _selectedCategory = name;
                  });
                }
              },
              child: const Text('Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Favori Notu ve Kategorisi Düzenleme Diyaloğu
  void _showFavoriteDialog(VaultCommand cmd) {
    final existingFav = _service.getFavorite(cmd.id);
    final noteCtrl = TextEditingController(text: cmd.userNote ?? existingFav?.note ?? '');
    String selectedCat = cmd.customCategory ?? existingFav?.category ?? 'Genel';

    // Kategoriler listesi
    final availableCategories = <String>{'Genel'};
    for (var u in _service.userCategories) {
      if (u.trim().isNotEmpty) availableCategories.add(u.trim());
    }
    if (cmd.category.isNotEmpty) availableCategories.add(cmd.category);
    if (!availableCategories.contains(selectedCat)) {
      availableCategories.add(selectedCat);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgDark,
              title: Row(
                children: [
                  Icon(
                    cmd.isFavorite ? Icons.star : Icons.star_border,
                    color: AppTheme.toolsAmber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cmd.isFavorite ? 'Favoriyi & Notu Düzenle' : 'Favorilere Ekle',
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cmd.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),

                      // Kategori Seçimi & Yeni Kategori
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kategori / Klasör',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              _showInlineAddCategory(setDialogState, (newCat) {
                                availableCategories.add(newCat);
                                selectedCat = newCat;
                              });
                            },
                            child: const Text(
                              '+ Yeni Kategori',
                              style: TextStyle(fontSize: 11, color: AppTheme.toolsAmber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedCat,
                        dropdownColor: AppTheme.bgCard,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.bgCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: availableCategories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCat = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Özel Operasyon Notu
                      const Text(
                        'Özel Operasyon Notu (İsteğe Bağlı)',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 12.5, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Örn: Lab 2\'de test edildi. Port 88 kapalıysa -no-smb2 eklemeyi unutma...',
                          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                          filled: true,
                          fillColor: AppTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (cmd.isFavorite)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
                    icon: const Icon(Icons.star_border, size: 16),
                    label: const Text('Favoriden Çıkar'),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await _service.removeFavorite(cmd.id);
                      if (!mounted) return;
                      nav.pop();
                      setState(() {});
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.toolsAmber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await _service.saveFavorite(
                      cmd.id,
                      note: noteCtrl.text.trim(),
                      category: selectedCat,
                    );
                    if (!mounted) return;
                    nav.pop();
                    setState(() {});
                  },
                  child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInlineAddCategory(StateSetter setParentState, Function(String) onAdded) {
    final newCatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgDark,
          title: const Text('Yeni Kategori Adı', style: TextStyle(fontSize: 14)),
          content: TextField(
            controller: newCatCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(hintText: 'Örn: Sınav Notları'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.toolsAmber, foregroundColor: Colors.black),
              onPressed: () async {
                final name = newCatCtrl.text.trim();
                if (name.isNotEmpty) {
                  final nav = Navigator.of(context);
                  await _service.addUserCategory(name);
                  onAdded(name);
                  setParentState(() {});
                  if (!mounted) return;
                  nav.pop();
                  setState(() {});
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Kriterlere Uygun Komut Bulunamadı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Arama kelimenizi veya filtrelerinizi değiştirebilirsiniz.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
            onPressed: () {
              _searchDebounceTimer?.cancel();
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'Tümü';
                _selectedTool = 'Tümü';
                _selectedPlatform = 'Tümü';
                _selectedFilterType = 'all';
                _selectedPillar = CommandPillar.all;
                _selectedOpsecTag = OpsecTag.all;
                _applyFilters();
              });
            },
            child: const Text('Filtreleri Temizle'),
          ),
        ],
      ),
    );
  }
}
