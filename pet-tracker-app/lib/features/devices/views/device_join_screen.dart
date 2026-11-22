import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../home/controllers/app_data_controller.dart';

/// Lets a second account gain read-only visibility into a collar someone
/// else already owns and linked to a pet — live location, status, battery,
/// and history, but never editing or management actions.
class DeviceJoinScreen extends StatefulWidget {
  const DeviceJoinScreen({super.key});

  @override
  State<DeviceJoinScreen> createState() => _DeviceJoinScreenState();
}

class _DeviceJoinScreenState extends State<DeviceJoinScreen> {
  final _data = Get.find<AppDataController>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^PT-([0-9A-F]{12}|[0-9A-F]{32})$').hasMatch(code)) {
      setState(
        () => _error =
            'Check the tracker ID on the package and enter it in full.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await _data.devicesRepo.join(code);
      await _data.refreshAll();
      if (mounted) {
        setState(() {
          _success = true;
          _error = null;
        });
        Get.snackbar(
          'Tracker Joined',
          'You can now view ${device.deviceId} and its pet (read-only).',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not join the tracker. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Join a Shared Tracker',
    currentIndex: 3,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Join a tracker someone else owns',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the tracker ID printed on the device package. You\'ll '
              'see its live location, status, battery, and history on your '
              'own account — but you can\'t edit it, reassign it, or remove '
              'the original owner\'s access.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Tracker ID',
                hintText: 'PT-…',
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text(_busy ? 'Joining…' : 'Join Tracker'),
            ),
            if (_success) ...[
              const SizedBox(height: 12),
              const Text(
                'Joined. Check My Pets or Collars to see it.',
                style: TextStyle(color: Colors.green),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
