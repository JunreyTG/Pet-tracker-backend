import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../data/models/models.dart';

class TrackerLocalSetup {
  static final endpoint = Uri.parse('http://192.168.4.1/config');
  static const protocol = 'pet-tracker-c3-v1';
  static final _deviceCode = RegExp(r'^PT-[0-9A-F]{12}$');

  static bool validDeviceCode(String code) => _deviceCode.hasMatch(code);

  static String newSetupNonce() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  TrackerLocalSetup({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<http.Response> _send(http.Request request, Duration timeout) {
    request.followRedirects = false;
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(timeout);
  }

  Future<bool> checkConnection(String deviceId) async {
    final response = await _send(
      http.Request('GET', endpoint.replace(path: '/api/status')),
      const Duration(seconds: 6),
    );
    if (response.statusCode != 200) return false;
    try {
      final status = jsonDecode(response.body);
      return status is Map &&
          status['protocol'] == protocol &&
          status['setup_mode'] == true &&
          status['device_id'] == deviceId;
    } on FormatException {
      return false;
    }
  }

  Future<TrackerDelivery> sendConfiguration({
    required String wifiName,
    required String wifiPassword,
    required String hotspotPassword,
    required String deviceId,
    required String deviceSecret,
    required String backendUrl,
    required String setupNonce,
  }) async {
    final origin = backendUrl.replaceFirst(RegExp(r'/+$'), '');
    if (!await checkConnection(deviceId)) throw const TrackerIdentityMismatch();
    try {
      final request = http.Request('POST', endpoint)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'X-Tracker-Key': hotspotPassword,
        })
        ..body = jsonEncode({
          'wifi_ssid': wifiName,
          'wifi_password': wifiPassword,
          'device_id': deviceId,
          'device_secret': deviceSecret,
          'backend_url': origin,
          'setup_nonce': setupNonce,
        });
      final response = await _send(request, const Duration(seconds: 12));
      if (response.statusCode != 202) {
        throw TrackerConfigurationRejected(response.statusCode);
      }
      final reply = jsonDecode(response.body);
      return reply is Map &&
              reply['accepted'] == true &&
              reply['device_id'] == deviceId
          ? TrackerDelivery.accepted
          : TrackerDelivery.unconfirmed;
    } on FormatException {
      return TrackerDelivery.unconfirmed;
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

class TrackerIdentityMismatch implements Exception {
  const TrackerIdentityMismatch();
}

class TrackerConfigurationRejected implements Exception {
  TrackerConfigurationRejected(this.statusCode);
  final int statusCode;
}

/// The server only receives this nonce after a report from this setup attempt.
bool hasFreshOnlineReport(DeviceModel device, String setupNonce) {
  return device.status == 'online' &&
      device.lastSeen != null &&
      device.setupNonce == setupNonce;
}
