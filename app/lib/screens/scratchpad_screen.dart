import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/loot_model.dart';
import '../services/command_service.dart';
import '../services/scratchpad_service.dart';
import '../theme/app_theme.dart';
import 'command_generator_screen.dart';
import 'ticket_inspector_screen.dart';

/// Operasyonel Ganimet ve Karalama Defteri Ekranı (Scratchpad Screen)
/// Sızma testlerinde elde edilen kimlik bilgileri, hedef IP'ler,
/// hash'ler ve Kerberos biletlerini yerel cihazda yönetir ve komut motoruna bağlar.
class ScratchpadScreen extends StatefulWidget {
  const ScratchpadScreen({super.key});

  @override
  State<ScratchpadScreen> createState() => _ScratchpadScreenState();
}

class _ScratchpadScreenState extends State<ScratchpadScreen> {
  final ScratchpadService _service = ScratchpadService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  LootCategory? _selectedCategory; // null = Tümü
  final Set<String> _revealedItemIds = <String>{};

  @override
  void initState() {
    super.initState();
    _service.init();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  List<LootItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();
    return _service.items.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;

      final inTitle = item.title.toLowerCase().contains(query);
      final inPrimary = item.primaryValue.toLowerCase().contains(query);
      final inSecondary = item.secondaryValue?.toLowerCase().contains(query) ?? false;
      final inDomain = item.domain?.toLowerCase().contains(query) ?? false;
      final inNotes = item.notes?.toLowerCase().contains(query) ?? false;
      final inTags = item.tags.any((t) => t.toLowerCase().contains(query));

      return inTitle || inPrimary || inSecondary || inDomain || inNotes || inTags;
    }).toList();
  }

  int _countForCategory(LootCategory cat) {
    return _service.items.where((e) => e.category == cat).length;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚔️ Ganimet & Karalama Defteri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_service.items.length} Kayıtlı Loot · %100 Çevrimdışı & Güvenli',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined, color: AppTheme.toolsAmber),
            tooltip: 'Kerberos Bilet Çözümleyici (Inspector)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TicketInspectorScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: AppTheme.toolsAmber),
            tooltip: 'Rapor ve Dışa Aktarma (Export)',
            onPressed: () => _showExportSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            tooltip: 'Diğer İşlemler',
            onSelected: (val) {
              if (val == 'clear_all') {
                _confirmClearAll();
              } else if (val == 'jump_generator') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommandGeneratorScreen()),
                );
              } else if (val == 'ticket_inspector') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TicketInspectorScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'ticket_inspector',
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined, color: AppTheme.toolsAmber, size: 18),
                    SizedBox(width: 8),
                    Text('Kerberos Bilet Çözümleyici'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'jump_generator',
                child: Row(
                  children: [
                    Icon(Icons.terminal, color: AppTheme.redTeam, size: 18),
                    SizedBox(width: 8),
                    Text('Komut Oluşturucuya Git'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppTheme.redTeam, size: 18),
                    SizedBox(width: 8),
                    Text('Tüm Defteri Temizle', style: TextStyle(color: AppTheme.redTeam)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.redTeam,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Ganimet Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditModal(context, null),
      ),
      body: Column(
        children: [
          // 1. Arama Çubuğu
          _buildSearchBar(),

          // 2. Kategori Filtre Çipleri
          _buildCategoryFilters(),

          const Divider(height: 1, color: AppTheme.border),

          // 3. Ganimet Listesi veya Boş Durum
          Expanded(
            child: items.isEmpty ? _buildEmptyState() : _buildLootList(items),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'IP, parola, hash, kullanıcı adı veya etiket ara...',
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.bgCard,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.blueTeam),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Tümü (${_service.items.length})',
            isSelected: _selectedCategory == null,
            color: AppTheme.blueTeam,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 6),
          ...LootCategory.values.map((cat) {
            final count = _countForCategory(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildFilterChip(
                label: '${cat.label.split('(')[0].trim()} ($count)',
                icon: cat.icon,
                isSelected: _selectedCategory == cat,
                color: Color(cat.badgeColorHex),
                onTap: () => setState(() => _selectedCategory = cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? color : AppTheme.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLootList(List<LootItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildLootCard(item);
      },
    );
  }

  Widget _buildLootCard(LootItem item) {
    final catColor = Color(item.category.badgeColorHex);
    final isRevealed = _revealedItemIds.contains(item.id);
    final isMasked = item.isSensitive && !isRevealed;

    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Kategori Rozeti + Domain + Zaman
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: catColor.withAlpha(90)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.category.icon, size: 12, color: catColor),
                      const SizedBox(width: 4),
                      Text(
                        item.category.label.split('(')[0].trim(),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: catColor),
                      ),
                    ],
                  ),
                ),
                if (item.domain != null && item.domain!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.blueTeam.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.domain!,
                      style: const TextStyle(fontSize: 10, color: AppTheme.blueTeam, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Başlık
            Text(
              item.title,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),

            if (item.secondaryValue != null && item.secondaryValue!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Text('İkincil Bilgi / Kullanıcı: ', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                  Text(
                    item.secondaryValue!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),

            // Temel Değer Kutusu (Terminal Box)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgCode,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderHighlight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      isMasked ? '••••••••••••••••••••••••' : item.primaryValue,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: isMasked ? AppTheme.textMuted : AppTheme.toolsAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.isSensitive)
                    IconButton(
                      icon: Icon(
                        isRevealed ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      tooltip: isRevealed ? 'Gizle' : 'Göster',
                      onPressed: () {
                        setState(() {
                          if (isRevealed) {
                            _revealedItemIds.remove(item.id);
                          } else {
                            _revealedItemIds.add(item.id);
                          }
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppTheme.textSecondary),
                    tooltip: 'Değeri Kopyala',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.primaryValue));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.title} değeri panoya kopyalandı!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Etiketler
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: item.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Notlar
            if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark.withAlpha(120),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.notes!,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.3),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Alt Eylem Butonları
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.redTeam.withAlpha(35),
                      foregroundColor: AppTheme.redTeam,
                      side: const BorderSide(color: AppTheme.redTeam, width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text(
                      'Komut Motoruna Aktar',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _service.sendToCommandContext(item);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('${item.title} canlı hedef bağlamına aktarıldı!'),
                          action: SnackBarAction(
                            label: 'KOMUTLARA GİT',
                            textColor: AppTheme.toolsAmber,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CommandGeneratorScreen()),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (item.category == LootCategory.kerberosTicket) ...[
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined, size: 19, color: AppTheme.toolsAmber),
                    tooltip: 'Bileti Görsel Olarak Çözümle (Inspector)',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TicketInspectorScreen(
                            initialRawTicket: item.primaryValue,
                            initialTitle: item.title,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                  tooltip: 'Düzenle',
                  onPressed: () => _showAddEditModal(context, item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.redTeam),
                  tooltip: 'Sil',
                  onPressed: () => _confirmDeleteItem(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.redTeam.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.redTeam.withAlpha(80)),
              ),
              child: const Icon(Icons.shield_outlined, size: 40, color: AppTheme.redTeam),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ganimet Defteri Boş',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sızma testi sırasında ele geçirilen kimlik bilgilerini, NTLM hash\'lerini ve hedef IP\'leri buraya kaydedin.\nTek dokunuşla komut motoruna canlı bağlam olarak aktarabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.redTeam,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('İlk Ganimeti Ekle'),
              onPressed: () => _showAddEditModal(context, null),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditModal(BuildContext context, LootItem? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddEditLootModal(existing: existing),
    );
  }

  void _confirmDeleteItem(LootItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Ganimeti Sil', style: TextStyle(color: Colors.white)),
        content: Text('${item.title} kalıcı olarak silinecek. Onaylıyor musunuz?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteItem(item.id);
            },
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Tüm Ganimetleri Temizle', style: TextStyle(color: AppTheme.redTeam)),
        content: const Text(
          'Ganimet defterindeki tüm kimlik bilgileri, hostlar ve notlar silinecektir. Bu işlem geri alınamaz!',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
            child: const Text('Tümünü Temizle', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.clearAll();
            },
          ),
        ],
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.ios_share, color: AppTheme.toolsAmber, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Ganimet Raporu ve Dışa Aktar (Export)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // 1. Markdown Raporu Kopyala
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.blueTeam.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined, color: AppTheme.blueTeam, size: 20),
                ),
                title: const Text('Markdown Sızma Testi Raporu Kopyala', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                subtitle: const Text('Tablolar halinde biçimlendirilmiş operasyonel ganimet dökümü', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  final md = _service.exportMarkdown();
                  Clipboard.setData(ClipboardData(text: md));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Markdown ganimet raporu panoya kopyalandı!')),
                  );
                },
              ),

              // 2. JSON Dışa Aktar
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.toolsAmber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.code, color: AppTheme.toolsAmber, size: 20),
                ),
                title: const Text('JSON Veri Yedeği Kopyala', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                subtitle: const Text('Başka cihaz veya oturuma aktarılabilir ham JSON dökümü', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  final jsonStr = _service.exportJson();
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON veri yedeği panoya kopyalandı!')),
                  );
                },
              ),

              // 3. JSON İçe Aktar
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.sysAdmin.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.file_download_outlined, color: AppTheme.sysAdmin, size: 20),
                ),
                title: const Text('JSON Veri İçe Aktar (Import)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                subtitle: const Text('Panodaki JSON ganimet listesini bu deftere ekleyin', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('JSON Ganimet İçe Aktar', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ganimet JSON dizisini aşağıya yapıştırın:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white),
              decoration: const InputDecoration(
                hintText: '[{"title": "...", "primaryValue": "..."}]',
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.sysAdmin),
            child: const Text('İçe Aktar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final added = await _service.importJson(text);
              nav.pop();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('$added yeni ganimet başarıyla eklendi!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Ganimet Ekleme ve Düzenleme Modal Formu
class _AddEditLootModal extends StatefulWidget {
  final LootItem? existing;
  const _AddEditLootModal({this.existing});

  @override
  State<_AddEditLootModal> createState() => _AddEditLootModalState();
}

class _AddEditLootModalState extends State<_AddEditLootModal> {
  final _formKey = GlobalKey<FormState>();
  late LootCategory _category;
  late TextEditingController _titleController;
  late TextEditingController _primaryController;
  late TextEditingController _secondaryController;
  late TextEditingController _domainController;
  late TextEditingController _tagsController;
  late TextEditingController _notesController;
  bool _isSensitive = true;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _category = ex?.category ?? LootCategory.credential;
    _titleController = TextEditingController(text: ex?.title ?? '');
    _primaryController = TextEditingController(text: ex?.primaryValue ?? '');
    _secondaryController = TextEditingController(text: ex?.secondaryValue ?? '');
    _domainController = TextEditingController(text: ex?.domain ?? CommandService().targetContext.domain);
    _tagsController = TextEditingController(text: ex?.tags.join(', ') ?? '');
    _notesController = TextEditingController(text: ex?.notes ?? '');
    _isSensitive = ex?.isSensitive ?? (_category == LootCategory.credential);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    _domainController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _primaryLabel {
    switch (_category) {
      case LootCategory.credential:
        return 'Parola veya NTLM Hash *';
      case LootCategory.targetHost:
        return 'Hedef IP Adresi *';
      case LootCategory.kerberosTicket:
        return 'Bilet Yolu / Base64 / Kirbikirbi *';
      case LootCategory.adArtifact:
        return 'Nesne Adı / Sertifika Şablonu *';
      case LootCategory.quickNote:
        return 'Temel Bilgi / Loot İçeriği *';
    }
  }

  String get _secondaryLabel {
    switch (_category) {
      case LootCategory.credential:
        return 'Kullanıcı Adı (sAMAccountName)';
      case LootCategory.targetHost:
        return 'Host Adı (FQDN)';
      case LootCategory.kerberosTicket:
        return 'İlgili SPN veya Servis';
      case LootCategory.adArtifact:
        return 'Etkilenen Grup veya SID';
      case LootCategory.quickNote:
        return 'İkincil Parametre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Ganimeti Düzenle' : 'Yeni Ganimet Kaydet',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Kategori Seçici
                const Text('Ganimet Türü', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<LootCategory>(
                  value: _category,
                  dropdownColor: AppTheme.bgCard,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: LootCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(cat.icon, size: 16, color: Color(cat.badgeColorHex)),
                          const SizedBox(width: 8),
                          Text(cat.label, style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _category = val;
                        if (val == LootCategory.credential) _isSensitive = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Başlık
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Başlık (Örn: Domain Admin, SQL Server, DC01) *',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Başlık zorunludur' : null,
                ),
                const SizedBox(height: 10),

                // Temel Değer
                TextFormField(
                  controller: _primaryController,
                  style: const TextStyle(color: AppTheme.toolsAmber, fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _primaryLabel,
                    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Temel değer zorunludur' : null,
                ),
                const SizedBox(height: 10),

                // İkincil Bilgi & Domain Yan Yana
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _secondaryController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: _secondaryLabel,
                          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _domainController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Domain (corp.local)',
                          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Etiketler
                TextFormField(
                  controller: _tagsController,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Etiketler (Virgülle ayırın: Tier-0, DCSync, LAPS)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                // Notlar
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Operasyonel Notlar ve Keşif Detayı',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),

                // Hassas Değer Maskeleme Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hassas Değer (Ekranda Maskele)', style: TextStyle(fontSize: 12.5, color: Colors.white)),
                  subtitle: const Text('Göz simgesiyle açılana kadar gizli tutulur', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: _isSensitive,
                  activeColor: AppTheme.redTeam,
                  onChanged: (val) => setState(() => _isSensitive = val),
                ),
                const SizedBox(height: 12),

                // Kaydet Butonu
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.redTeam,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    isEdit ? 'Değişiklikleri Güncelle' : 'Ganimeti Deftere Ekle',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState?.validate() != true) return;

                    final tags = _tagsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    final item = LootItem(
                      id: widget.existing?.id ?? 'loot_${DateTime.now().millisecondsSinceEpoch}',
                      category: _category,
                      title: _titleController.text.trim(),
                      primaryValue: _primaryController.text.trim(),
                      secondaryValue: _secondaryController.text.trim().isNotEmpty
                          ? _secondaryController.text.trim()
                          : null,
                      domain: _domainController.text.trim().isNotEmpty
                          ? _domainController.text.trim()
                          : null,
                      notes: _notesController.text.trim().isNotEmpty
                          ? _notesController.text.trim()
                          : null,
                      tags: tags,
                      isSensitive: _isSensitive,
                      createdAt: widget.existing?.createdAt ?? DateTime.now(),
                    );

                    final nav = Navigator.of(context);
                    final service = ScratchpadService();
                    if (isEdit) {
                      await service.updateItem(item);
                    } else {
                      await service.addItem(item);
                    }

                    if (!mounted) return;
                    nav.pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
