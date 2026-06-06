import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/app_user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.initialProfileImage,
    required this.onProfileImageChanged,
    required this.onPasswordChanged,
  });

  final AppUser user;
  final Uint8List? initialProfileImage;
  final ValueChanged<Uint8List?> onProfileImageChanged;
  final Future<bool> Function(String currentPassword, String newPassword) onPasswordChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _profileImage;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    _profileImage = widget.initialProfileImage;
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final file = await _imagePicker.pickImage(source: source, maxWidth: 1280, imageQuality: 85);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    setState(() {
      _profileImage = bytes;
    });
    widget.onProfileImageChanged(bytes);
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _savingPassword = true);
    final ok = await widget.onPasswordChanged(
      _currentPasswordCtrl.text.trim(),
      _newPasswordCtrl.text.trim(),
    );
    if (!mounted) {
      return;
    }

    setState(() => _savingPassword = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de changer le mot de passe.')),
      );
      return;
    }

    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _confirmPasswordCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe mis a jour avec succes.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  backgroundImage: _profileImage != null ? MemoryImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 52)
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: FilledButton.tonal(
                    onPressed: _pickImage,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                    child: const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Informations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: widget.user.fullName,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: widget.user.matricule,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Matricule',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Modification de mot de passe',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _currentPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    final current = value?.trim() ?? '';
                    if (current.isEmpty) {
                      return 'Entrez votre mot de passe actuel';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _newPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) {
                    final next = value?.trim() ?? '';
                    if (next.isEmpty) {
                      return 'Entrez un nouveau mot de passe';
                    }
                    if (next.length < 4) {
                      return 'Minimum 4 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                  validator: (value) {
                    final confirm = value?.trim() ?? '';
                    if (confirm.isEmpty) {
                      return 'Confirmez le nouveau mot de passe';
                    }
                    if (confirm != _newPasswordCtrl.text.trim()) {
                      return 'La confirmation ne correspond pas';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _savingPassword ? null : _savePassword,
            icon: _savingPassword
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer les modifications'),
          ),
        ],
      ),
    );
  }
}
