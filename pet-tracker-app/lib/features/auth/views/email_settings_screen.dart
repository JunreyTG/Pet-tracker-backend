import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/api/api_exception.dart';
import '../controllers/auth_controller.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final _auth = Get.find<AuthController>();
  final _code = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  bool _failed = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _message = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _message = e.message;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Email settings are unavailable. Try again.';
          _failed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _send() => _run(() async {
    await _auth.sendEmailVerification();
    if (mounted) {
      setState(() {
        _sent = true;
        _message = 'Code sent. Check your inbox and spam folder.';
      });
    }
  });

  Future<void> _verify() => _run(() async {
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^[0-9A-F]{16}$').hasMatch(code)) {
      throw ApiException('Enter the 16-character code from your email.');
    }
    await _auth.verifyEmail(code);
    if (mounted) {
      _code.clear();
      setState(
        () => _message = 'Email verified. You can now enable email alerts.',
      );
    }
  });

  @override
  Widget build(BuildContext context) => Obx(() {
    final user = _auth.backendUser.value;
    final verified = user?.emailVerified == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Email notifications')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: user == null
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Sign in to manage your email notifications.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          verified
                              ? Icons.verified_outlined
                              : Icons.mail_outline,
                        ),
                        title: SelectableText(user.email),
                        subtitle: Text(
                          verified ? 'Verified email' : 'Email not verified',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (verified)
                        Card(
                          child: SwitchListTile(
                            title: const Text('Email me tracker alerts'),
                            subtitle: const Text(
                              'Safe-zone activity, collar status changes, and reported low battery.',
                            ),
                            value: user.emailAlertsEnabled,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      _run(() => _auth.setEmailAlerts(value)),
                          ),
                        )
                      else ...[
                        const Text(
                          'Verify this address before enabling email alerts.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _code,
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                          ),
                          enabled: !_busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9a-fA-F]'),
                            ),
                            LengthLimitingTextInputFormatter(16),
                          ],
                          onSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _verify,
                          child: const Text('Verify email'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _send,
                          child: Text(_sent ? 'Resend code' : 'Send a code'),
                        ),
                      ],
                      if (_busy) const LinearProgressIndicator(),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _failed
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  });
}
