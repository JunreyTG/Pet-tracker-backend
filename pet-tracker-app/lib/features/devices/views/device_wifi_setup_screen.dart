import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_config.dart';
import '../../../data/models/models.dart';
import '../../home/controllers/app_data_controller.dart';

class DeviceWifiSetupScreen extends StatefulWidget {
  const DeviceWifiSetupScreen({super.key});

  @override
  State<DeviceWifiSetupScreen> createState() => _DeviceWifiSetupScreenState();
}

class _DeviceWifiSetupScreenState extends State<DeviceWifiSetupScreen> {
  final _data = Get.find<AppDataController>();
  final _deviceId = TextEditingController();
  final _deviceSecret = TextEditingController();
  final _wifiSsid = TextEditingController();
  final _wifiPassword = TextEditingController();
  final _backendUrl = TextEditingController(text: AppConfig.baseUrl);
  final _setupEndpoint = TextEditingController(
    text: 'http://192.168.4.1/config',
  );
  DeviceProvisioningModel? _provisioning;
  bool _preparing = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final argument = Get.arguments;
    _deviceId.text = argument is String && argument.isNotEmpty
        ? argument
        : 'ESP32_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _deviceSecret.dispose();
    _wifiSsid.dispose();
    _wifiPassword.dispose();
    _backendUrl.dispose();
    _setupEndpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = _data.devices.firstWhereOrNull(
      (d) => d.deviceId == _deviceId.text.trim(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Tracker WiFi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Section 1: Tracker Credentials
          _FormCard(
            title: '1. Tracker Credentials',
            icon: Icons.key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _deviceId,
                  decoration: const InputDecoration(
                    labelText: 'Device ID',
                    hintText: 'Enter tracker ID (e.g. ESP32_xxx)',
                    prefixIcon: Icon(Icons.perm_identity),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _backendUrl,
                  decoration: const InputDecoration(
                    labelText: 'Backend Server URL',
                    hintText: 'http://192.168.0.47:8000',
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _preparing ? null : _prepareTracker,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _preparing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.vpn_key),
                  label: const Text('Register & Generate Secret'),
                ),
                if (_provisioning != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.green.withValues(alpha: .3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          'Hotspot SSID: ${_provisioning!.setupHotspotSsid}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          'Device Secret: ${_provisioning!.deviceSecret}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _deviceSecret,
                  decoration: const InputDecoration(
                    labelText: 'Device Secret Key',
                    hintText: 'Paste secret key here',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Section 2: Hotspot Setup Endpoint
          _FormCard(
            title: '2. Tracker Setup Endpoint',
            icon: Icons.wifi_tethering,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _setupEndpoint,
                  decoration: const InputDecoration(
                    labelText: 'Tracker Hotspot IP / Endpoint',
                    hintText: 'http://192.168.4.1/config',
                    prefixIcon: Icon(Icons.router),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Section 3: Target WiFi Network
          _FormCard(
            title: '3. WiFi Network Settings',
            icon: Icons.wifi,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _wifiSsid,
                  decoration: const InputDecoration(
                    labelText: 'WiFi Network (SSID)',
                    hintText: 'Your home or mobile hotspot WiFi name',
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wifiPassword,
                  decoration: const InputDecoration(
                    labelText: 'WiFi Password',
                    hintText: 'Network password',
                    prefixIcon: Icon(Icons.password),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _sending ? null : _sendWifiSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send WiFi Setup to Tracker'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Section 4: Live Status
          _FormCard(
            title: '4. Tracker Online Status',
            icon: Icons.cell_tower,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: device?.status == 'online'
                            ? AppTheme.green.withValues(alpha: .15)
                            : AppTheme.orange.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        (device?.status ?? 'Not connected').toUpperCase(),
                        style: TextStyle(
                          color: device?.status == 'online' ? AppTheme.green : AppTheme.orange,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Battery Level:', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${device?.batteryLevel?.toString() ?? '--'}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _data.refreshAll();
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareTracker() async {
    final id = _deviceId.text.trim();
    final backendUrl = _backendUrl.text.trim();
    if (id.isEmpty || backendUrl.isEmpty) {
      Get.snackbar('Tracker setup', 'Enter a device ID and backend URL.');
      return;
    }

    setState(() => _preparing = true);
    try {
      final provisioning = await _data.devicesRepo.provision(
        id,
        backendUrl: backendUrl,
      );
      await _data.refreshAll();
      setState(() {
        _provisioning = provisioning;
        _deviceSecret.text = provisioning.deviceSecret;
        _backendUrl.text = provisioning.backendUrl;
      });
      Get.snackbar(
        'Tracker credentials ready',
        'Device secret generated and filled.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      Get.snackbar('Tracker setup', e.message);
    } catch (e) {
      Get.snackbar('Tracker setup', e.toString());
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _sendWifiSettings() async {
    final id = _deviceId.text.trim();
    final secret = _deviceSecret.text.trim();
    final ssid = _wifiSsid.text.trim();
    final setupEndpoint = _setupEndpoint.text.trim();
    final backendUrl = _backendUrl.text.trim().replaceFirst(RegExp(r'/+$'), '');

    if ([id, secret, ssid, setupEndpoint, backendUrl].any((value) => value.isEmpty)) {
      Get.snackbar(
        'Missing fields',
        'Please fill in Device ID, Secret, WiFi SSID, setup endpoint, and backend URL.',
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final response = await http
          .post(
            Uri.parse(setupEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'wifi_ssid': ssid,
              'wifi_password': _wifiPassword.text,
              'device_id': id,
              'device_secret': secret,
              'backend_url': backendUrl,
              'telemetry_url': '$backendUrl${AppConfig.apiPrefix}/device/telemetry',
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('ESP32 returned error code (${response.statusCode}).');
      }
      Get.snackbar(
        'Setup Sent',
        'WiFi credentials sent. Tracker is rebooting to join your WiFi.',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _data.refreshAll();
      setState(() {});
    } catch (e) {
      Get.snackbar(
        'Tracker setup failed',
        'Could not reach tracker hotspot. Ensure you are connected to the tracker WiFi. (${e.toString()})',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.green),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
