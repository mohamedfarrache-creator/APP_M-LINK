import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/models/app_user.dart';
import 'data/repositories/hybrid_maintenance_repository.dart';
import 'data/repositories/maintenance_repository.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/calendars/preventive_calendar_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/widgets/app_drawer.dart';
import 'features/drawer/help_screen.dart';
import 'features/drawer/history_screen.dart';
import 'features/drawer/settings_screen.dart';
import 'features/interventions/anomaly_report_screen.dart';
import 'features/map/map_screen.dart';
import 'features/machines/machine_detail_screen.dart';
import 'features/profile/profile_screen.dart';

class MLinkApp extends StatefulWidget {
  const MLinkApp({super.key});

  @override
  State<MLinkApp> createState() => _MLinkAppState();
}

class _MLinkAppState extends State<MLinkApp> {
  late final MaintenanceRepository _repository;
  late final Future<void> _initFuture;

  AppUser? _currentUser;
  int _index = 0;
  ThemeMode _themeMode = ThemeMode.light;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _repository = HybridMaintenanceRepository();
    _initFuture = _repository.initialize();
  }

  void _onLoggedIn(AppUser user) {
    setState(() {
      _currentUser = user;
      _index = 0;
    });
  }

  void _logout() {
    unawaited(_repository.logout());
    setState(() {
      _currentUser = null;
      _index = 0;
      _profileImageBytes = null;
    });
  }

  void _onThemeChanged(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _onProfileImageChanged(Uint8List? imageBytes) {
    setState(() {
      _profileImageBytes = imageBytes;
    });
  }

  Future<bool> _onPasswordChanged(String currentPassword, String newPassword) async {
    final user = _currentUser;
    if (user == null) {
      return false;
    }

    try {
      await _repository.updateUserPassword(
        userId: user.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      setState(() {
        _currentUser = user.copyWith(password: newPassword);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'M-link SEBN',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          home: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return _currentUser == null
                  ? LoginScreen(
                      repository: _repository,
                      onLogin: _onLoggedIn,
                    )
                  : _HomeShell(
                      user: _currentUser!,
                      index: _index,
                      repository: _repository,
                      onIndexChanged: (value) => setState(() => _index = value),
                      onLogout: _logout,
                      isDarkMode: _themeMode == ThemeMode.dark,
                      onThemeChanged: _onThemeChanged,
                      profileImageBytes: _profileImageBytes,
                      onProfileImageChanged: _onProfileImageChanged,
                      onPasswordChanged: _onPasswordChanged,
                    );
            },
          ),
        );
      },
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({
    required this.user,
    required this.index,
    required this.repository,
    required this.onIndexChanged,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.profileImageBytes,
    required this.onProfileImageChanged,
    required this.onPasswordChanged,
  });

  final AppUser user;
  final int index;
  final MaintenanceRepository repository;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final Uint8List? profileImageBytes;
  final ValueChanged<Uint8List?> onProfileImageChanged;
  final Future<bool> Function(String currentPassword, String newPassword) onPasswordChanged;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        user: user,
        repository: repository,
      ),
      const PreventiveCalendarScreen(),
      PlantMapView(
        repository: repository,
        isAdmin: user.role == UserRole.admin,
        onMachineTap: (machine) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MachineDetailScreen(
                machine: machine,
                repository: repository,
              ),
            ),
          );
        },
      ),
      AnomalyReportScreen(
        currentUser: user,
        repository: repository,
      ),
      if (user.role == UserRole.admin)
        AdminScreen(
          repository: repository,
        ),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        label: 'Calendriers',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.map_outlined),
        label: 'Carte',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.campaign_outlined),
        label: 'Signaler',
      ),
      if (user.role == UserRole.admin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: 'Admin',
        ),
    ];

    void openProfile() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            user: user,
            initialProfileImage: profileImageBytes,
            onProfileImageChanged: onProfileImageChanged,
            onPasswordChanged: onPasswordChanged,
          ),
        ),
      );
    }

    void openHistory() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HistoryScreen(interventions: repository.interventions),
        ),
      );
    }

    void openSettings() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged,
          ),
        ),
      );
    }

    void openHelp() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const HelpScreen(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('M-LINK SEBN'),
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      drawer: AppDrawer(
        user: user,
        profileImageBytes: profileImageBytes,
        isDarkMode: isDarkMode,
        onThemeChanged: onThemeChanged,
        onProfileTap: openProfile,
        onHistoryTap: openHistory,
        onSettingsTap: openSettings,
        onHelpTap: openHelp,
        onLogout: onLogout,
      ),
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: onIndexChanged,
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }
}
