import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';

/// Lets the owner push new Wi-Fi credentials straight to the physical
/// collar over the local network. This never touches the cloud backend —
/// the request goes directly from this phone to the collar's own tiny
/// web server, which is only reachable when both are on the same network.
class DeviceWifiScreen extends StatefulWidget {
  const DeviceWifiScreen({super.key});

  @override
  State<DeviceWifiScreen> createState() => _DeviceWifiScreenState();
}

enum _Mode { hotspot, onNetwork }

class _DeviceWifiScreenState extends State<DeviceWifiScreen> {
  final _form = GlobalKey<FormState>();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController();
  final _dashboardKey = TextEditingController();
  _Mode _mode = _Mode.hotspot;
  bool _busy = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    _host.dispose();
    _dashboardKey.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _success = false;
    });
    try {
      final onHotspot = _mode == _Mode.hotspot;
      final host = onHotspot ? '192.168.4.1' : _host.text.trim();
      final uri = Uri.parse(
        onHotspot ? 'http://$host/save' : 'http://$host/api/wifi',
      );
      final response = await http
          .post(
            uri,
            headers: onHotspot
                ? null
                : {'X-Tracker-Key': _dashboardKey.text.trim()},
            body: {'ssid': _ssid.text.trim(), 'password': _password.text},
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _success = true;
          _message =
              'Saved. The collar is restarting and will connect to '
              '"${_ssid.text.trim()}" shortly.';
        });
      } else {
        setState(() {
          _message = response.body.isNotEmpty
              ? response.body
              : 'The collar rejected the request (HTTP ${response.statusCode}).';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _message =
              'Could not reach the collar. Make sure your phone is on the '
              'same network as the tracker, then try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not reach the collar. Make sure your phone is on the '
              'same network as the tracker, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onHotspot = _mode == _Mode.hotspot;
    return AppScaffold(
      title: 'Collar Wi-Fi',
      currentIndex: 3,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(
                    value: _Mode.hotspot,
                    label: Text('Setup hotspot'),
                    icon: Icon(Icons.wifi_tethering),
                  ),
                  ButtonSegment(
                    value: _Mode.onNetwork,
                    label: Text('Already online'),
                    icon: Icon(Icons.sensors),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() {
                        _mode = s.first;
                        _message = null;
                      }),
              ),
              const SizedBox(height: 16),
              SectionCard(
                margin: EdgeInsets.zero,
                child: Text(
                  onHotspot
                      ? 'The collar opens its own "PetTracker-XXXX" Wi-Fi '
                            'network when it can\'t connect. Go to your '
                            'phone\'s Wi-Fi settings, join that network, '
                            'then come back here and submit the form below.'
                      : 'Use this only when your phone is on the same '
                            'network as a collar that\'s already connected. '
                            'The local address and dashboard key were '
                            'printed on Serial Monitor when it booted.',
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(
                  children: [
                    if (!onHotspot) ...[
                      TextFormField(
                        controller: _host,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Collar local address',
                          hintText: 'e.g. 192.168.0.169',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter the collar\'s local IP address.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dashboardKey,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Local dashboard key',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter the dashboard key printed on Serial Monitor.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _ssid,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Wi-Fi name (SSID)',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter the Wi-Fi name.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Wi-Fi password',
                        hintText: 'Leave blank for open networks',
                      ),
                    ),
                  ],
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _success
                        ? AppTheme.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Sending…' : 'Save & Restart Collar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
