import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.useCurrentWeekAsDefault,
    required this.chosenDefaultWeek,
    required this.onDefaultCalendarWeekChanged,
    required this.onPasswordChanged,
    required this.onLogout,
  });

  final AppUser user;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final bool useCurrentWeekAsDefault;
  final int chosenDefaultWeek;
  final void Function({
    required bool useCurrentWeek,
    required int chosenWeek,
  }) onDefaultCalendarWeekChanged;
  final Future<bool> Function(String currentPassword, String newPassword)
      onPasswordChanged;
  final VoidCallback onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _anomalyNotifications = true;
  bool _preventiveReminderNotifications = true;
  String _reminderFrequency = 'Quotidien';
  late bool _useCurrentWeekAsDefault;
  late int _chosenDefaultWeek;

  @override
  void initState() {
    super.initState();
    _useCurrentWeekAsDefault = widget.useCurrentWeekAsDefault;
    _chosenDefaultWeek = widget.chosenDefaultWeek;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parametres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _section(
            title: 'Affichage',
            children: <Widget>[
              SwitchListTile(
                value: widget.isDarkMode,
                onChanged: widget.onThemeChanged,
                secondary: Icon(
                  widget.isDarkMode
                      ? Icons.nights_stay_outlined
                      : Icons.wb_sunny_outlined,
                ),
                title: const Text('Mode sombre'),
              ),
              ListTile(
                leading: const Icon(Icons.format_size),
                title: const Text('Taille du texte'),
                subtitle: SegmentedButton<double>(
                  selected: <double>{widget.textScaleFactor},
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<double>>[
                    ButtonSegment<double>(value: 0.9, label: Text('Petit')),
                    ButtonSegment<double>(value: 1.0, label: Text('Normal')),
                    ButtonSegment<double>(value: 1.15, label: Text('Grand')),
                  ],
                  onSelectionChanged: (value) {
                    widget.onTextScaleChanged(value.first);
                  },
                ),
              ),
            ],
          ),
          _section(
            title: 'Notifications',
            children: <Widget>[
              SwitchListTile(
                value: _anomalyNotifications,
                onChanged: (value) {
                  setState(() => _anomalyNotifications = value);
                },
                secondary: const Icon(Icons.campaign_outlined),
                title: const Text('Notifications anomalies'),
              ),
              SwitchListTile(
                value: _preventiveReminderNotifications,
                onChanged: (value) {
                  setState(() => _preventiveReminderNotifications = value);
                },
                secondary: const Icon(Icons.event_repeat_outlined),
                title: const Text('Rappels preventif'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Frequence des rappels'),
                trailing: DropdownButton<String>(
                  value: _reminderFrequency,
                  items: const <String>['Quotidien', 'Hebdomadaire']
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _reminderFrequency = value);
                    }
                  },
                ),
              ),
            ],
          ),
          _section(
            title: 'Calendrier',
            children: <Widget>[
              RadioListTile<bool>(
                value: true,
                groupValue: _useCurrentWeekAsDefault,
                onChanged: (value) => _setCalendarDefault(useCurrentWeek: true),
                secondary: const Icon(Icons.today_outlined),
                title: const Text('Semaine actuelle'),
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: _useCurrentWeekAsDefault,
                onChanged: (value) =>
                    _setCalendarDefault(useCurrentWeek: false),
                secondary: const Icon(Icons.calendar_month_outlined),
                title: const Text('Semaine choisie'),
              ),
              if (!_useCurrentWeekAsDefault)
                ListTile(
                  leading: const Icon(Icons.date_range_outlined),
                  title: const Text('Semaine par defaut'),
                  trailing: DropdownButton<int>(
                    value: _chosenDefaultWeek,
                    items: List<DropdownMenuItem<int>>.generate(
                      52,
                      (index) {
                        final week = index + 1;
                        return DropdownMenuItem<int>(
                          value: week,
                          child: Text('KW $week'),
                        );
                      },
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        _setCalendarDefault(
                          useCurrentWeek: false,
                          chosenWeek: value,
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
          _section(
            title: 'Compte',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.lock_reset_outlined),
                title: const Text('Changer mot de passe'),
                subtitle: Text(widget.user.matricule),
                onTap: _showPasswordDialog,
              ),
            ],
          ),
          _section(
            title: 'A propos',
            children: const <Widget>[
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Version application'),
                subtitle: Text('M-LINK v1.0'),
              ),
              ListTile(
                leading: Icon(Icons.support_agent_outlined),
                title: Text('Contact support'),
                subtitle: Text('support@m-link.local'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLogout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Deconnexion'),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  void _setCalendarDefault({
    required bool useCurrentWeek,
    int? chosenWeek,
  }) {
    final week = chosenWeek ?? _chosenDefaultWeek;
    setState(() {
      _useCurrentWeekAsDefault = useCurrentWeek;
      _chosenDefaultWeek = week;
    });
    widget.onDefaultCalendarWeekChanged(
      useCurrentWeek: useCurrentWeek,
      chosenWeek: week,
    );
  }

  Future<void> _showPasswordDialog() async {
    final matriculeCtrl = TextEditingController(text: widget.user.matricule);
    final currentCtrl = TextEditingController();
    final nextCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Changer mot de passe'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: matriculeCtrl,
                      decoration: const InputDecoration(labelText: 'Matricule'),
                      validator: (value) {
                        if (value?.trim() != widget.user.matricule) {
                          return 'Matricule incorrect';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Ancien mot de passe'),
                      validator: (value) {
                        final entered = value?.trim() ?? '';
                        if (entered.isEmpty) {
                          return 'Ancien mot de passe requis';
                        }
                        final memoryPassword = widget.user.password;
                        if (memoryPassword.isNotEmpty &&
                            entered != memoryPassword) {
                          return 'Ancien mot de passe incorrect';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: nextCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe'),
                      validator: (value) {
                        if ((value?.trim().length ?? 0) < 6) {
                          return 'Minimum 6 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          final dialogNavigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(this.context);
                          setDialogState(() => saving = true);
                          final ok = await widget.onPasswordChanged(
                            currentCtrl.text.trim(),
                            nextCtrl.text.trim(),
                          );
                          if (!mounted) {
                            return;
                          }
                          if (ok) {
                            dialogNavigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Mot de passe mis a jour.'),
                              ),
                            );
                          } else {
                            setDialogState(() => saving = false);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Impossible de changer le mot de passe.'),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );

    matriculeCtrl.dispose();
    currentCtrl.dispose();
    nextCtrl.dispose();
  }
}
