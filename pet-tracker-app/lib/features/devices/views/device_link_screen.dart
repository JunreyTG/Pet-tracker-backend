import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../data/models/models.dart';
import '../../home/controllers/app_data_controller.dart';

class DeviceLinkScreen extends StatefulWidget {
  const DeviceLinkScreen({super.key});

  @override
  State<DeviceLinkScreen> createState() => _DeviceLinkScreenState();
}

class _DeviceLinkScreenState extends State<DeviceLinkScreen> {
  final _data = Get.find<AppDataController>();
  final _code = TextEditingController();
  late final PetModel? _fixedPet = Get.arguments is PetModel
      ? Get.arguments as PetModel
      : null;
  String? _petId;
  DeviceModel? _device;
  String? _error;
  Timer? _poll;
  bool _busy = false;
  bool _checking = false;

  bool get _online {
    final lastSeen = _device?.lastSeen;
    return _device?.status == 'online' &&
        lastSeen != null &&
        DateTime.now().difference(lastSeen) < const Duration(minutes: 5);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _link(String? petId) async {
    if (_busy || petId == null) return;
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^PT-[0-9A-F]{12}$').hasMatch(code)) {
      setState(
        () => _error = 'Enter PT- followed by 12 characters (0–9 or A–F).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final linked = await _data.devicesRepo.claim(code, petId);
      if (!mounted) return;
      setState(() => _device = linked);
      unawaited(_data.refreshAll());
      if (!_online) {
        _poll = Timer.periodic(const Duration(seconds: 5), (timer) {
          if (timer.tick >= 12) timer.cancel();
          unawaited(_checkStatus());
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 404
              ? 'Tracker not available. Check the ID and make sure the tracker was enrolled.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not link the tracker. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() async {
    final id = _device?.deviceId;
    if (_checking || id == null) return;
    setState(() => _checking = true);
    try {
      final status = await _data.devicesRepo.get(id);
      if (!mounted) return;
      setState(() {
        _device = status;
        _error = null;
      });
      if (_online) _poll?.cancel();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check tracker status. Try again.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Device')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Obx(() {
            final available = _data.pets
                .where((pet) => pet.deviceId == null)
                .toList();
            final fixed = _fixedPet;
            final petId =
                fixed?.id ??
                (available.length == 1
                    ? available.single.id
                    : available.any((pet) => pet.id == _petId)
                    ? _petId
                    : null);
            final device = _device;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (device != null) ...[
                  Text(
                    '${device.deviceId} linked',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _online
                        ? device.gpsFix == true
                              ? 'Online · GPS reporting'
                              : 'Online · waiting for GPS'
                        : 'Waiting for the tracker to report. Make sure it has Wi-Fi internet.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Get.offNamed(
                      Routes.deviceDetails,
                      arguments: device.deviceId,
                    ),
                    child: const Text('Open Tracker'),
                  ),
                  if (!_online)
                    TextButton(
                      onPressed: _checking ? null : _checkStatus,
                      child: const Text('Check Status'),
                    ),
                ] else ...[
                  Text(
                    fixed == null
                        ? 'Link a Wi-Fi tracker'
                        : 'Link a tracker to ${fixed.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter the ID that came with the tracker. Your phone can use Wi-Fi or mobile data.',
                  ),
                  const SizedBox(height: 16),
                  if (fixed == null && available.isEmpty)
                    const Text('Add a pet without an assigned tracker first.')
                  else if (fixed == null && available.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: available.any((pet) => pet.id == petId)
                          ? petId
                          : null,
                      decoration: const InputDecoration(labelText: 'Pet'),
                      items: available
                          .map(
                            (pet) => DropdownMenuItem(
                              value: pet.id,
                              child: Text(pet.name),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _petId = value),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _code,
                    enabled: !_busy && (fixed != null || available.isNotEmpty),
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'PT- followed by 12 characters',
                    ),
                    onSubmitted: (_) => _link(petId),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || petId == null
                        ? null
                        : () => _link(petId),
                    child: Text(_busy ? 'Linking…' : 'Connect Device'),
                  ),
                  if (fixed != null)
                    TextButton(
                      onPressed: _busy ? null : () => Get.offNamed(Routes.pets),
                      child: const Text('Skip for Now'),
                    ),
                ],
                if (_error case final String error)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    ),
  );
}
