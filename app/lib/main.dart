import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/pillar_screen.dart';
import 'screens/settings_screen.dart';
import 'services/content_service.dart';
import 'services/app_state.dart';
import 'services/tts_service.dart';
import 'services/ai_service.dart';
import 'services/command_service.dart';
import 'services/scratchpad_service.dart';
import 'services/quiz_service.dart';
import 'theme/app_theme.dart';
import 'widgets/tts_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ActiveDirectoryApp());
}

class ActiveDirectoryApp extends StatelessWidget {
  const ActiveDirectoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Directory Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final ContentService _contentService = ContentService();
  final AppState _appState = AppState();
  final TtsService _ttsService = TtsService();
  final AiService _aiService = AiService();

  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.wait([
      _contentService.init(),
      _appState.init(),
      _ttsService.init(),
      _aiService.init(),
      CommandService().init(),
      ScratchpadService().init(),
      QuizService().init(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.redTeam.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.redTeam, width: 2),
                ),
                child: const Icon(Icons.security, size: 48, color: AppTheme.redTeam),
              ),
              const SizedBox(height: 24),
              const Text(
                'ACTIVE DIRECTORY VAULT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Çevrimdışı Cephanelik & Modüller Yükleniyor...',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  color: AppTheme.redTeam,
                  backgroundColor: AppTheme.bgCard,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final redTeam = _contentService.getPillarById('red_team');
    final blueTeam = _contentService.getPillarById('blue_team');
    final sysAdmin = _contentService.getPillarById('sistem_yoneticisi');

    final screens = <Widget>[
      HomeScreen(),
      if (redTeam != null) PillarScreen(pillar: redTeam) else const SizedBox(),
      if (blueTeam != null) PillarScreen(pillar: blueTeam) else const SizedBox(),
      if (sysAdmin != null) PillarScreen(pillar: sysAdmin) else const SizedBox(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TtsPlayerBar(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.redTeam),
            label: 'Hub',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security, color: AppTheme.redTeam),
            label: 'Red Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: AppTheme.blueTeam),
            label: 'Blue Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns, color: AppTheme.sysAdmin),
            label: 'SysAdmin',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppTheme.toolsAmber),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
