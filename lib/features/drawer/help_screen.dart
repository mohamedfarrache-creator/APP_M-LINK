import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          Card(
            child: ListTile(
              leading: Icon(Icons.support_agent_outlined),
              title: Text('Support technique'),
              subtitle: Text('Contactez l\'admin SEBN pour assistance.'),
            ),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.menu_book_outlined),
              title: Text('Guide rapide'),
              subtitle: Text('1. Ouvrez le dashboard\n2. Selectionnez une action\n3. Validez les interventions'),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }
}
