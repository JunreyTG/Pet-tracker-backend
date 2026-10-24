import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../data/models/models.dart';

/// The firmware contract currently documented by this project is HTTP POST
/// /config. A GET response proves that the local address answered; it does not
/// prove the identity of the device or that the firmware supports WiFi scans.
class TrackerLocalSetup {
  TrackerLocalSetup({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<bool> checkConnection(Uri endpoint) async {
    final request = http.Request('GET', endpoint)..followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 6));
    // 405 is expected when firmware implements only POST /config.
    return response.statusCode != 404 && response.statusCode < 500;
  }

  Future<TrackerDelivery> sendConfiguration({
    required Uri endpoint,
    required String wifiName,
    required String wifiPassword,
    required String deviceId,
    required String deviceSecret,
    required String backendUrl,
  }) async {
    final origin = backendUrl.replaceFirst(RegExp(r'/+$'), '');
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'wifi_ssid': wifiName,
              'wifi_password': wifiPassword,
              'device_id': deviceId,
              'device_secret': deviceSecret,
              'backend_url': origin,
              'telemetry_url': '$origin/api/v1/device/telemetry',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TrackerConfigurationRejected(response.statusCode);
      }
      return TrackerDelivery.accepted;
    } on TimeoutException {
      // Firmware may close the connection as it restarts. Check fresh telemetry.
      return TrackerDelivery.unconfirmed;
    } on http.ClientException {
      return TrackerDelivery.unconfirmed;
    } on SocketException {
      return TrackerDelivery.unconfirmed;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

enum TrackerDelivery { accepted, unconfirmed }

class TrackerConfigurationRejected implements Exception {
  TrackerConfigurationRejected(this.statusCode);
  final int statusCode;
}

/// A prior online status cannot confirm that a new configuration worked.
bool hasFreshOnlineReport(DeviceModel device, DateTime configurationStartedAt) {
  final lastSeen = device.lastSeen;
  return device.status == 'online' &&
      lastSeen != null &&
      lastSeen.isAfter(
        configurationStartedAt.subtract(const Duration(seconds: 5)),
      );
}
