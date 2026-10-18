import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/checklist_models.dart';
import '../services/checklist_service.dart';
import '../services/content_service.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';
import 'command_generator_screen.dart';
import 'search_screen.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final ChecklistService _checklistService = ChecklistService();
  final ContentService _contentService = ContentService();

  String _searchFilter = '';
  String _selectedPhase = 'Tümü';
  String _selectedStatusFilter = 'Tümü';
  final Set<String> _expandedItemIds = {};

  final List<String> _phases = const [
    'Tümü',
    'Faz 1: Keşif & Pasif İstihbarat',
    'Faz 2: Aktif Numaralandırma',
    'Faz 3: İlk Erişim & Parola Saldırıları',
    'Faz 4: Kimlik Bilgisi & Bilet Toplama',
    'Faz 5: Yanal Hareket & Uzak Yürütme',
    'Faz 6: Yetki Yükseltme & Delegasyon',
    'Faz 7: Etki Alanı Hâkimiyeti & Kalıcılık',
    'Faz 8: Ormanlar Arası & Temizlik',
  ];

  @override
  void initState() {
    super.initState();
    _checklistService.addListener(_onServiceChanged);
    _checklistService.init();
  }

  @override
  void dispose() {
    _checklistService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Color _opsecColor(String opsec) {
    if (opsec.contains('Düşük') || opsec.contains('Sessiz')) {
      return AppTheme.sysAdmin;
    }
    if (opsec.contains('Orta')) {
      return AppTheme.toolsAmber;
    }
    return AppTheme.redTeam;
  }

  Widget _buildStatusIcon(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.completed:
        return const Icon(Icons.check_circle, color: AppTheme.sysAdmin, size: 24);
      case ChecklistStatus.failed:
        return const Icon(Icons.cancel, color: AppTheme.redTeam, size: 24);
      case ChecklistStatus.na:
        return const Icon(Icons.remove_circle, color: AppTheme.toolsAmber, size: 24);
      case ChecklistStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: AppTheme.textMuted, size: 24);
    }
  }

  String _statusLabel(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.completed:
        return 'Başarılı / Zafiyet Var';
      case ChecklistStatus.failed:
        return 'Başarısız / Koruma Var';
      case ChecklistStatus.na:
        return 'Kapsam Dışı / N/A';
      case ChecklistStatus.pending:
        return 'Bekliyor / Denenmedi';
    }
  }

  void _showEditProfileDialog() {
    final p = _checklistService.activeProfile;
    final nameCtrl = TextEditingController(text: p.name);
    final domainCtrl = TextEditingController(text: p.targetDomain);
    final dcIpCtrl = TextEditingController(text: p.targetDcIp);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Operasyon Bilgilerini Düzenle', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Operasyon / Müşteri Adı'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: domainCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Hedef Domain (Örn: corp.local)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dcIpCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Hedef DC IP (Örn: 192.168.1.10)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueTeam, foregroundColor: Colors.black),
            onPressed: () async {
              await _checklistService.updateActiveProfile(
                name: nameCtrl.text,
                targetDomain: domainCtrl.text,
                targetDcIp: dcIpCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showNewProfileDialog() {
    final nameCtrl = TextEditingController();
    final domainCtrl = TextEditingController(text: 'corp.local');
    final dcIpCtrl = TextEditingController(text: '192.168.1.10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Yeni Operasyon Profili', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Operasyon Adı',
                hintText: 'Örn: CRTP Lab / Müşteri B',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: domainCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Hedef Domain'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dcIpCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Hedef DC IP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueTeam, foregroundColor: Colors.black),
            onPressed: () async {
              await _checklistService.createProfile(
                name: nameCtrl.text,
                targetDomain: domainCtrl.text,
                targetDcIp: dcIpCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Oluştur & Başla'),
          ),
        ],
      ),
    );
  }

  void _showProfilesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Operasyon Profilleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Yeni Profil'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showNewProfileDialog();
                    },
                  ),
                ],
              ),
              const Divider(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _checklistService.profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final prof = _checklistService.profiles[index];
                    final isActive = prof.id == _checklistService.activeProfileId;

                    return ListTile(
                      tileColor: isActive ? const Color(0xFF162030) : AppTheme.bgDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isActive ? AppTheme.blueTeam : AppTheme.border),
                      ),
                      leading: Icon(Icons.assignment, color: isActive ? AppTheme.blueTeam : AppTheme.textMuted),
                      title: Text(prof.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text('${prof.targetDomain} · ${prof.targetDcIp}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      trailing: _checklistService.profiles.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
                              onPressed: () async {
                                await _checklistService.deleteProfile(prof.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            )
                          : null,
                      onTap: () async {
                        await _checklistService.setActiveProfile(prof.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
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

  void _showItemNoteDialog(ChecklistItem item) {
    final noteCtrl = TextEditingController(text: _checklistService.activeProfile.getNote(item.id));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Row(
          children: const [
            Icon(Icons.edit_note, color: AppTheme.toolsAmber, size: 22),
            SizedBox(width: 8),
            Text('Operasyonel Not & Bulgu', style: TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.blueTeam)),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Örn: svc_sql Kerberoast edildi, hash kırıldı: Summer2024!',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.toolsAmber, foregroundColor: Colors.black),
            onPressed: () async {
              await _checklistService.setItemNote(item.id, noteCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Notu Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final report = _checklistService.exportReportMarkdown();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Row(
              children: [
                Icon(Icons.assessment, color: AppTheme.blueTeam, size: 22),
                SizedBox(width: 8),
                Text('Sızma Testi Raporu', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 350),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    report,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11.5, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueTeam, foregroundColor: Colors.black),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Raporu Kopyala'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Operasyon raporu panoya kopyalandı!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openArticleForPath(String? path, String title, {String? tool}) {
    if (path == null && tool == null) return;
    final item = _contentService.findArticleItem(path: path, tool: tool, keyword: title);
    if (item != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleScreen(articleId: item.id, initialTitle: item.title),
        ),
      );
      return;
    }

    // Doğrudan eşleşme bulunamazsa ilgili konuyu arama motorunda listele
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: tool ?? title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prof = _checklistService.activeProfile;

    final filtered = kDefaultChecklistItems.where((item) {
      if (_selectedPhase != 'Tümü' && item.phaseTitle != _selectedPhase) {
        return false;
      }

      final st = prof.getStatus(item.id);
      if (_selectedStatusFilter == 'Tamamlananlar' && st != ChecklistStatus.completed) {
        return false;
      }
      if (_selectedStatusFilter == 'Kalanlar' && st == ChecklistStatus.completed) {
        return false;
      }

      if (_searchFilter.isNotEmpty) {
        final q = _searchFilter.toLowerCase();
        return item.title.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            (item.recommendedTool?.toLowerCase().contains(q) ?? false) ||
            (item.mitreTechnique?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.checklist_rtl, color: AppTheme.sysAdmin, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Denetim Checklist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.toolsAmber),
            tooltip: 'Denetim Raporu Al',
            onPressed: _showReportDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'profiles') _showProfilesSheet();
              if (val == 'edit') _showEditProfileDialog();
              if (val == 'new') _showNewProfileDialog();
              if (val == 'reset') {
                _checklistService.resetActiveProfile();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Operasyon durumları sıfırlandı.')),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profiles', child: Text('Operasyon Değiştir')),
              const PopupMenuItem(value: 'edit', child: Text('Hedef Bilgilerini Düzenle')),
              const PopupMenuItem(value: 'new', child: Text('Yeni Operasyon Aç')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'reset', child: Text('Bu Operasyonu Sıfırla')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Profil ve İlerleme Kartı
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppTheme.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showProfilesSheet,
                        child: Row(
                          children: [
                            const Icon(Icons.assignment, size: 18, color: AppTheme.blueTeam),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                prof.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppTheme.blueTeam, size: 18),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: AppTheme.textMuted),
                      tooltip: 'Hedefi Düzenle',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _showEditProfileDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.border)),
                      child: Text(prof.targetDomain, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.border)),
                      child: Text(prof.targetDcIp, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.toolsAmber)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'OPERASYONEL İLERLEME',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '%${(_checklistService.progressRatio * 100).toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.sysAdmin),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _checklistService.progressRatio > 0 ? _checklistService.progressRatio : 0.02,
                    minHeight: 6,
                    backgroundColor: AppTheme.bgDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.sysAdmin),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatPill('Başarılı', _checklistService.completedCount, AppTheme.sysAdmin),
                    _buildStatPill('Başarısız', _checklistService.failedCount, AppTheme.redTeam),
                    _buildStatPill('Muaf', _checklistService.naCount, AppTheme.toolsAmber),
                    _buildStatPill('Kalan', _checklistService.pendingCount, AppTheme.textMuted),
                  ],
                ),
              ],
            ),
          ),

          // 2. Arama ve Durum Filtresi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchFilter = val),
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Madde, araç veya teknik ara...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.bgCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter,
                      dropdownColor: AppTheme.bgCard,
                      icon: const Icon(Icons.filter_list, size: 16, color: AppTheme.blueTeam),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'Tümü', child: Text('Tümü')),
                        DropdownMenuItem(value: 'Tamamlananlar', child: Text('Başarılı')),
                        DropdownMenuItem(value: 'Kalanlar', child: Text('Kalanlar')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatusFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Faz Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _phases.map((phase) {
                final isSelected = _selectedPhase == phase;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(phase),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedPhase = phase),
                    backgroundColor: AppTheme.bgCard,
                    selectedColor: AppTheme.blueTeam.withAlpha(50),
                    checkmarkColor: AppTheme.blueTeam,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    side: BorderSide(color: isSelected ? AppTheme.blueTeam : AppTheme.border),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),

          // 4. Kontrol Listesi
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Kriterlere uygun kontrol maddesi bulunamadı.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final status = prof.getStatus(item.id);
                      final isExpanded = _expandedItemIds.contains(item.id);
                      final note = prof.getNote(item.id);

                      return Card(
                        color: AppTheme.bgCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: status == ChecklistStatus.completed
                                ? AppTheme.sysAdmin.withAlpha(120)
                                : status == ChecklistStatus.failed
                                    ? AppTheme.redTeam.withAlpha(120)
                                    : AppTheme.border,
                            width: status == ChecklistStatus.completed ? 1.4 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedItemIds.remove(item.id);
                              } else {
                                _expandedItemIds.add(item.id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Durum Değiştirme Butonu (Tıklayınca Döngüsel Değişir)
                                    IconButton(
                                      icon: _buildStatusIcon(status),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: '${_statusLabel(status)} (Değiştirmek için dokunun)',
                                      onPressed: () => _checklistService.cycleItemStatus(item.id),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: status == ChecklistStatus.completed ? Colors.white : AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: _opsecColor(item.opsecLevel).withAlpha(25),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.opsecLevel,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _opsecColor(item.opsecLevel),
                                                  ),
                                                ),
                                              ),
                                              if (item.mitreTechnique != null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  item.mitreTechnique!,
                                                  style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textMuted),
                                                ),
                                              ],
                                              if (note.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.note_alt, size: 13, color: AppTheme.toolsAmber),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      color: AppTheme.textMuted,
                                      size: 20,
                                    ),
                                  ],
                                ),

                                // Açılır Detay Alanı
                                if (isExpanded) ...[
                                  const Divider(height: 16),
                                  Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                                  ),
                                  if (item.recommendedTool != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('Önerilen Araç: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        Text(item.recommendedTool!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.blueTeam)),
                                      ],
                                    ),
                                  ],
                                  if (item.exampleCommand != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.bgCode,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.exampleCommand!,
                                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFF472B6)),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: item.exampleCommand!));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Komut panoya kopyalandı!'), duration: Duration(seconds: 1)),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF261D13),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.toolsAmber.withAlpha(90)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.note, size: 14, color: AppTheme.toolsAmber),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(note, style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.edit_note, size: 16, color: AppTheme.toolsAmber),
                                        label: Text(note.isEmpty ? 'Not Ekle' : 'Notu Düzenle', style: const TextStyle(fontSize: 11.5, color: AppTheme.toolsAmber)),
                                        onPressed: () => _showItemNoteDialog(item),
                                      ),
                                      if (item.docPath != null)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                          icon: const Icon(Icons.menu_book, size: 15, color: AppTheme.blueTeam),
                                          label: const Text('Rehberi Aç', style: TextStyle(fontSize: 11.5, color: AppTheme.blueTeam)),
                                          onPressed: () => _openArticleForPath(item.docPath, item.title, tool: item.recommendedTool),
                                        ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          side: const BorderSide(color: AppTheme.redTeam),
                                        ),
                                        icon: const Icon(Icons.terminal, size: 14, color: AppTheme.redTeam),
                                        label: const Text('Komut Oluşturucu', style: TextStyle(fontSize: 11, color: AppTheme.redTeam)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const CommandGeneratorScreen()),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ],
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
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: $count', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
