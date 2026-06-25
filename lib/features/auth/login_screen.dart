import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/maintenance_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLogin,
  });

  final MaintenanceRepository repository;
  final ValueChanged<AppUser> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _matriculeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  UserRole _role = UserRole.preventive;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _matriculeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    final matricule = _matriculeCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    AppUser? found = await widget.repository.login(
      matricule: matricule,
      password: password,
      role: _role,
    );

    if (!mounted) {
      return;
    }

    setState(() => _loading = false);
    if (found == null) {
      setState(() => _error = 'Identifiants invalides ou role incorrect.');
      return;
    }
    widget.onLogin(found);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF003A34), Color(0xFF006B5F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'M-link SEBN',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gestion preventive et corrective',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        SegmentedButton<UserRole>(
                          segments: const <ButtonSegment<UserRole>>[
                            ButtonSegment<UserRole>(
                              value: UserRole.preventive,
                              icon: Icon(Icons.build_circle_outlined),
                              label: Text('Preventif'),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.corrective,
                              icon: Icon(Icons.engineering_outlined),
                              label: Text('Correctif'),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.admin,
                              icon: Icon(Icons.admin_panel_settings_outlined),
                              label: Text('Admin'),
                            ),
                          ],
                          selected: <UserRole>{_role},
                          onSelectionChanged: (selection) {
                            setState(() => _role = selection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _matriculeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Matricule',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Entrez votre matricule';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Entrez votre mot de passe';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Se connecter'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
