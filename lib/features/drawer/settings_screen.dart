import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parametres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: SwitchListTile(
              value: isDarkMode,
              onChanged: onThemeChanged,
              secondary: Icon(
                isDarkMode ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined,
              ),
              title: const Text('Mode sombre'),
              subtitle: const Text('Activer / desactiver le theme sombre'),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Version application'),
              subtitle: Text('M-LINK v1.0'),
            ),
          ),
        ],
      ),
    );
  }
}
