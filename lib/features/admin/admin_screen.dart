import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/maintenance_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.repository,
  });

  final MaintenanceRepository repository;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _nameCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.preventive;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _matriculeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _addTech() async {
    if (_nameCtrl.text.trim().isEmpty || _matriculeCtrl.text.trim().isEmpty) {
      return;
    }
    final password = _passwordCtrl.text.trim().isEmpty
        ? _matriculeCtrl.text.trim()
        : _passwordCtrl.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = AppUser(
        id: 'tech-${DateTime.now().millisecondsSinceEpoch}',
        fullName: _nameCtrl.text.trim(),
        matricule: _matriculeCtrl.text.trim(),
        password: password,
        role: _role,
      );
      await widget.repository.addUser(user);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Erreur lors de la creation: $error';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
    });
    _nameCtrl.clear();
    _matriculeCtrl.clear();
    _passwordCtrl.clear();
    _role = UserRole.preventive;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Technicien ajoute.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techs = widget.repository.users
        .where((u) => u.role == UserRole.preventive || u.role == UserRole.corrective)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Administration utilisateurs',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _matriculeCtrl,
                  decoration: const InputDecoration(labelText: 'Matricule'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Mot de passe (optionnel)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  value: _role,
                  items: const <DropdownMenuItem<UserRole>>[
                    DropdownMenuItem<UserRole>(
                      value: UserRole.preventive,
                      child: Text('Technicien Preventif'),
                    ),
                    DropdownMenuItem<UserRole>(
                      value: UserRole.corrective,
                      child: Text('Technicien Correctif'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _role = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (_error != null) const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _addTech,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter technicien'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Techniciens enregistres: ${techs.length}'),
        const SizedBox(height: 8),
        ...techs.map(
          (user) => Card(
            child: ListTile(
              leading: Icon(
                user.role == UserRole.preventive ? Icons.build : Icons.engineering,
              ),
              title: Text(user.fullName),
              subtitle: Text('${user.roleLabel} | Matricule ${user.matricule}'),
            ),
          ),
        ),
      ],
    );
  }
}
