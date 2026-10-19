import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/kerberos_ticket_model.dart';
import '../models/loot_model.dart';
import '../services/command_service.dart';
import '../services/scratchpad_service.dart';
import '../theme/app_theme.dart';

/// İnteraktif Kerberos Bilet Çözümleyici Ekranı
class TicketInspectorScreen extends StatefulWidget {
  final String? initialRawTicket;
  final String? initialTitle;

  const TicketInspectorScreen({
    super.key,
    this.initialRawTicket,
    this.initialTitle,
  });

  @override
  State<TicketInspectorScreen> createState() => _TicketInspectorScreenState();
}

class _TicketInspectorScreenState extends State<TicketInspectorScreen> {
  final TextEditingController _inputController = TextEditingController();
  KerberosTicketData? _parsedData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialRawTicket != null && widget.initialRawTicket!.isNotEmpty) {
      _inputController.text = widget.initialRawTicket!;
      _inspectTicket();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _inspectTicket() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedData = null;
        _errorMessage = 'Lütfen çözümlenecek bir Base64 .kirbi, CCache veya terminal çıktısı girin.';
      });
      return;
    }

    try {
      final parsed = KerberosTicketParser.parse(text);
      setState(() {
        _parsedData = parsed;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _parsedData = null;
        _errorMessage = 'Bilet ayrıştırılamadı: ${e.toString()}';
      });
    }
  }

  void _loadSample(String sampleType) {
    if (sampleType == 'tgt') {
      _inputController.text = '''
ServiceName              :  krbtgt/CORP.LOCAL
ServiceRealm             :  CORP.LOCAL
UserName                 :  Administrator
UserRealm                :  CORP.LOCAL
StartTime                :  ${DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()}
EndTime                  :  ${DateTime.now().add(const Duration(hours: 9)).toIso8601String()}
RenewTill                :  ${DateTime.now().add(const Duration(days: 7)).toIso8601String()}
Flags                    :  name_canonicalize, pre_authent, initial, renewable, forwardable
KeyType                  :  aes256_cts_hmac_sha1
Base64EncodedTicket      :  doIFqjCCBaa... [Mimikatz/Rubeus KRB-CRED]
''';
    } else if (sampleType == 'tgs_rc4') {
      _inputController.text = '''
ServiceName              :  MSSQLSvc/sql01.corp.local:1433
ServiceRealm             :  CORP.LOCAL
UserName                 :  svc_sql
UserRealm                :  CORP.LOCAL
StartTime                :  ${DateTime.now().toIso8601String()}
EndTime                  :  ${DateTime.now().add(const Duration(hours: 10)).toIso8601String()}
RenewTill                :  ${DateTime.now().add(const Duration(days: 7)).toIso8601String()}
Flags                    :  forwardable, renewable, pre_authent
KeyType                  :  rc4_hmac (Kerberoastable!)
Base64EncodedTicket      :  doIF2jCCBdq...
''';
    } else if (sampleType == 'tgs_cifs') {
      _inputController.text = '''
ServiceName              :  cifs/dc01.corp.local
ServiceRealm             :  CORP.LOCAL
UserName                 :  DA_John
UserRealm                :  CORP.LOCAL
StartTime                :  ${DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()}
EndTime                  :  ${DateTime.now().add(const Duration(hours: 8)).toIso8601String()}
Flags                    :  forwardable, proxiable, renewable, pre_authent, ok_as_delegate
KeyType                  :  aes256_cts_hmac_sha1
''';
    }
    _inspectTicket();
  }

  void _saveToScratchpad() {
    if (_parsedData == null) return;
    final item = LootItem(
      id: 'kirbi_${DateTime.now().millisecondsSinceEpoch}',
      category: LootCategory.kerberosTicket,
      title: '${_parsedData!.ticketType}: ${_parsedData!.clientPrincipal}',
      primaryValue: _inputController.text.trim(),
      secondaryValue: _parsedData!.servicePrincipal,
      domain: _parsedData!.realm,
      notes: 'Format: ${_parsedData!.rawSourceFormat} · Etype: ${_parsedData!.etype.label} · Süre: ${_parsedData!.remainingTimeFormatted}',
      tags: ['Kerberos', _parsedData!.isTgt ? 'TGT' : 'TGS', _parsedData!.etype.label.split(' ').first],
      isSensitive: false,
    );
    ScratchpadService().addItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Kerberos bileti Ganimet Defteri\'ne kaydedildi!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _sendToCommandContext() {
    if (_parsedData == null) return;
    final cmdService = CommandService();
    final ctx = cmdService.targetContext;
    final userPart = _parsedData!.clientPrincipal.split('@').first;
    final domainPart = _parsedData!.realm.isNotEmpty ? _parsedData!.realm : ctx.domain;

    cmdService.updateTargetContext(
      ctx.copyWith(
        ticket: _inputController.text.trim(),
        user: userPart,
        spn: _parsedData!.servicePrincipal,
        domain: domainPart,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Bilet verileri ({{ticket}}, {{user}}, {{spn}}) Komut Oluşturucuya aktarıldı!'),
        backgroundColor: AppTheme.redTeam,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('🎟 Kerberos Bilet Çözümleyici'),
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Girdiyi Temizle',
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              _inputController.clear();
              setState(() {
                _parsedData = null;
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bilgi ve Başlık Kartı
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E2211), Color(0xFF151B26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.toolsAmber.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.toolsAmber.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.confirmation_number_outlined, color: AppTheme.toolsAmber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KERBEROS TICKET & KIRBI INSPECTOR',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber, letterSpacing: 0.8),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Base64 .kirbi (KRB-CRED), Linux CCache veya Rubeus/Mimikatz bilet çıktılarını istemci tarafında anında görsel kimlik kartına dönüştürün.',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Örnek Yükleme Rozetleri
                Row(
                  children: [
                    const Text('Hızlı Örnekler:', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    _buildSampleChip('TGT (AES256)', () => _loadSample('tgt')),
                    const SizedBox(width: 6),
                    _buildSampleChip('TGS (RC4 / Roastable)', () => _loadSample('tgs_rc4'), color: AppTheme.redTeam),
                    const SizedBox(width: 6),
                    _buildSampleChip('CIFS TGS (Delegation)', () => _loadSample('tgs_cifs'), color: AppTheme.blueTeam),
                  ],
                ),
                const SizedBox(height: 10),

                // Girdi Alanı
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _inputController,
                        maxLines: 5,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Base64 .kirbi bilet verisi, ccache hex veya Rubeus/klist çıktısı yapıştırın...',
                          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) => _inspectTicket(),
                      ),
                      const Divider(height: 16, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.paste, size: 16),
                            label: const Text('Panodan Yapıştır', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                _inputController.text = data!.text!;
                                _inspectTicket();
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.toolsAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Bileti Çözümle', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _inspectTicket,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.redTeam.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.redTeam.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.redTeam, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.redTeam, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // Çözümlenmiş Bilet Kimlik Kartı
                if (_parsedData != null) ...[
                  _buildTicketBadgeCard(_parsedData!),
                  const SizedBox(height: 16),

                  // Aksiyon Butonları
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.toolsAmber),
                            foregroundColor: AppTheme.toolsAmber,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text('Ganimet Defterine Ekle', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          onPressed: _saveToScratchpad,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.redTeam,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.terminal, size: 18),
                          label: const Text('Komut Motoruna Aktar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          onPressed: _sendToCommandContext,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSampleChip(String label, VoidCallback onTap, {Color? color}) {
    final col = color ?? AppTheme.toolsAmber;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: col.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: col.withAlpha(90)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
      ),
    );
  }

  Widget _buildTicketBadgeCard(KerberosTicketData t) {
    final isExpired = t.isExpired;
    final statusColor = isExpired ? AppTheme.redTeam : const Color(0xFF10B981);
    final etypeColor = t.etype.isStrong ? AppTheme.blueTeam : AppTheme.redTeam;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.isTgt ? AppTheme.toolsAmber.withAlpha(160) : AppTheme.blueTeam.withAlpha(140), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (t.isTgt ? AppTheme.toolsAmber : AppTheme.blueTeam).withAlpha(30),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgDark.withAlpha(180),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Icon(
                  t.isTgt ? Icons.stars : Icons.confirmation_number,
                  color: t.isTgt ? AppTheme.toolsAmber : AppTheme.blueTeam,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.ticketType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      Icon(isExpired ? Icons.cancel : Icons.check_circle, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        t.remainingTimeFormatted,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Client & Service Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildBadgeField(
                        label: 'İSTEMCİ KİMLİĞİ (Client Principal)',
                        value: t.clientPrincipal,
                        icon: Icons.person_outline,
                        color: AppTheme.blueTeam,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildBadgeField(
                        label: 'HEDEF SERVİS (Service Principal / SPN)',
                        value: t.servicePrincipal,
                        icon: Icons.dns_outlined,
                        color: t.isTgt ? AppTheme.toolsAmber : AppTheme.redTeam,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildBadgeField(
                        label: 'REALM / ETKİ ALANI',
                        value: t.realm,
                        icon: Icons.domain,
                        color: AppTheme.sysAdmin,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildBadgeField(
                        label: 'ŞİFRELEME ALGORİTMASI (EType)',
                        value: t.etype.label,
                        icon: Icons.lock_outline,
                        color: etypeColor,
                        trailingTag: t.etype.id == 23 ? 'KERBEROASTABLE' : 'GÜÇLÜ',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Zaman Çizelgesi
                const Text(
                  'ZAMAN DAMGALARI VE GEÇERLİLİK',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeColumn('Başlangıç', t.startTime),
                      Container(height: 24, width: 1, color: AppTheme.border),
                      _buildTimeColumn('Bitiş (Expire)', t.endTime, isHighlight: true),
                      if (t.renewTill != null) ...[
                        Container(height: 24, width: 1, color: AppTheme.border),
                        _buildTimeColumn('Yenileme Sınırı', t.renewTill),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ticket Flags
                const Text(
                  'BİLET BAYRAKLARI (TICKET FLAGS)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: t.flags.map((f) => _buildFlagBadge(f)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeField({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? trailingTag,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trailingTag,
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, DateTime? dt, {bool isHighlight = false}) {
    final str = dt != null ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : 'Yok';
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 3),
        Text(
          str,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.toolsAmber : Colors.white,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildFlagBadge(String flag) {
    Color col = AppTheme.blueTeam;
    if (flag.contains('FORWARDABLE') || flag.contains('INITIAL')) col = const Color(0xFF10B981);
    if (flag.contains('OK-AS-DELEGATE')) col = AppTheme.redTeam;
    if (flag.contains('RENEWABLE')) col = AppTheme.toolsAmber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: col.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withAlpha(90)),
      ),
      child: Text(
        flag,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col, letterSpacing: 0.5),
      ),
    );
  }
}
