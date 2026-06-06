import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/models/app_user.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.user,
    required this.profileImageBytes,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onProfileTap,
    required this.onHistoryTap,
    required this.onSettingsTap,
    required this.onHelpTap,
    required this.onLogout,
  });

  final AppUser user;
  final Uint8List? profileImageBytes;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onProfileTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onHelpTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? const <Color>[Color(0xFF02104F), Color(0xFF000521)]
                      : const <Color>[Color(0xFF00B4D8), Color(0xFFCAF0F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: <Widget>[
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        profileImageBytes != null ? MemoryImage(profileImageBytes!) : null,
                    child: profileImageBytes == null
                        ? const Icon(Icons.person, size: 34, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Matricule : ${user.matricule}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DrawerLinkTile(
              icon: Icons.person_outline,
              title: 'Mon Profil',
              onTap: onProfileTap,
            ),
            _DrawerLinkTile(
              icon: Icons.history,
              title: 'Historique',
              onTap: onHistoryTap,
            ),
            _DrawerLinkTile(
              icon: Icons.settings_outlined,
              title: 'Parametres',
              onTap: onSettingsTap,
            ),
            _DrawerLinkTile(
              icon: Icons.help_outline,
              title: 'Aide',
              onTap: onHelpTap,
            ),
            const Divider(height: 24),
            SwitchListTile(
              value: isDarkMode,
              onChanged: onThemeChanged,
              secondary: Icon(
                isDarkMode ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined,
              ),
              title: Text(isDarkMode ? 'Mode sombre' : 'Mode clair'),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: FilledButton.icon(
                onPressed: onLogout,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD45151),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Deconnexion'),
              ),
            ),
            Text(
              'M-LINK v1.0',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerLinkTile extends StatelessWidget {
  const _DrawerLinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
