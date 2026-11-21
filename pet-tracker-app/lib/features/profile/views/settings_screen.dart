import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_preferences.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/controllers/auth_controller.dart';
import '../services/profile_photo_store.dart';
import '../widgets/profile_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Settings',
    children: [
      const _SectionLabel('Account'),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              subtitle: const Text('Display name and email'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.accountProfile),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email notifications'),
              subtitle: const Text(
                'Verify your email and manage tracker emails',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.emailSettings),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.changePassword),
            ),
          ],
        ),
      ),
      const _SectionLabel('Appearance'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(
            () => DropdownButtonFormField<ThemeMode>(
              initialValue: AppPreferences.themeMode.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'App theme',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Follow system'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) AppPreferences.setTheme(mode);
              },
            ),
          ),
        ),
      ),
      const _SectionLabel('Tracking and alerts'),
      Card(
        child: Column(
          children: [
            Obx(
              () => SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('In-app alert banners'),
                subtitle: const Text(
                  'Show a banner while Pet Tracker is open. Phone notifications are controlled separately.',
                ),
                value: AppPreferences.showAlertBanners.value,
                onChanged: AppPreferences.setAlertBanners,
              ),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text('Default map location'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.mapFocus),
            ),
          ],
        ),
      ),
      const _SectionLabel('About'),
      const Card(
        child: ListTile(
          leading: Icon(Icons.pets_outlined),
          title: Text('Pet Tracker'),
          subtitle: Text('Location, safe zones, and collar alerts.'),
        ),
      ),
    ],
  );
}

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final _name = TextEditingController(
    text: _auth.backendUser.value?.displayName,
  );
  late final _phone = TextEditingController(
    text: _auth.backendUser.value?.phone,
  );
  late final _location = TextEditingController(
    text: _auth.backendUser.value?.location,
  );
  late final _bio = TextEditingController(text: _auth.backendUser.value?.bio);
  bool _saving = false;
  bool _photoBusy = false;
  String? _message;
  bool _success = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
      _success = false;
    });
    try {
      await _auth.updateProfile(
        displayName: _name.text.trim(),
        phone: _phone.text.trim(),
        location: _location.text.trim(),
        bio: _bio.text.trim(),
      );
      if (mounted) {
        setState(() {
          _message = 'Profile saved.';
          _success = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not save your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    if (_photoBusy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _photoBusy = true;
      _message = null;
      _success = false;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > ProfilePhotoStore.maxBytes) {
        if (mounted) {
          setState(() => _message = 'Choose an image smaller than 2 MB.');
        }
        return;
      }
      await ProfilePhotoStore.save(bytes);
      if (mounted) {
        setState(() {
          _message = 'Profile photo saved on this device.';
          _success = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not open the photo picker. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    await ProfilePhotoStore.remove();
    if (mounted) {
      setState(() {
        _message = 'Profile photo removed.';
        _success = true;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Profile',
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(
            () => Row(
              children: [
                ProfileAvatar(
                  displayName: _auth.backendUser.value?.displayName,
                  radius: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile photo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text('Stored only on this device.'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _photoBusy ? null : _changePhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Change'),
                          ),
                          if (ProfilePhotoStore.photo.value != null)
                            TextButton.icon(
                              onPressed: _photoBusy ? null : _removePhoto,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Obx(
        () => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
            title: const Text('Sign-in email'),
            subtitle: SelectableText(_auth.backendUser.value?.email ?? ''),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (name) =>
                  (name ?? '').trim().isEmpty ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 30,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'City or address (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'Optional note for your account',
              ),
            ),
          ],
        ),
      ),
      if (_message != null) _StatusText(_message!, success: _success),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save profile'),
      ),
    ],
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _hide = true;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Get.find<AuthController>().changePassword(
        _current.text,
        _next.text,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not change your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController input,
    String? Function(String?) validate,
    String hint,
  ) => TextFormField(
    controller: input,
    obscureText: _hide,
    autofillHints: [hint],
    autocorrect: false,
    enableSuggestions: false,
    enabled: !_saving,
    decoration: InputDecoration(labelText: label),
    validator: validate,
  );

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Change password',
    children: [
      const Text(
        'Use at least 8 characters. You’ll sign in again after changing your password.',
      ),
      const SizedBox(height: 20),
      Form(
        key: _form,
        child: AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Column(
            children: [
              _field(
                'Current password',
                _current,
                (value) => value == null || value.isEmpty
                    ? 'Enter your current password.'
                    : null,
                AutofillHints.password,
              ),
              const SizedBox(height: 14),
              _field('New password', _next, (value) {
                final length = (value ?? '').runes.length;
                if (length < 8 || length > 128) return 'Use 8–128 characters.';
                if (value == _current.text) {
                  return 'Choose a different password.';
                }
                return null;
              }, AutofillHints.newPassword),
              const SizedBox(height: 14),
              _field(
                'Confirm new password',
                _confirmation,
                (value) =>
                    value != _next.text ? 'Passwords do not match.' : null,
                AutofillHints.newPassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(
                    _hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  label: Text(_hide ? 'Show passwords' : 'Hide passwords'),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_error != null) _StatusText(_error!),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Updating…' : 'Update password'),
      ),
    ],
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.message, {this.success = false});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(
        color: success
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.error,
      ),
    ),
  );
}
