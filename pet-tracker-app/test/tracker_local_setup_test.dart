import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_tracker_app/data/models/models.dart';
import 'package:pet_tracker_app/features/devices/services/tracker_local_setup.dart';

void main() {
  final endpoint = Uri.parse('http://192.168.4.1/config');

  test(
    'GET 405 confirms the documented POST-only setup address answered',
    () async {
      final setup = TrackerLocalSetup(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url, endpoint);
          return http.Response('', 405);
        }),
      );
      expect(await setup.checkConnection(endpoint), isTrue);
    },
  );

  test(
    'missing setup address cannot be mistaken for a connected tracker',
    () async {
      final setup = TrackerLocalSetup(
        client: MockClient((_) async => http.Response('', 404)),
      );
      expect(await setup.checkConnection(endpoint), isFalse);
    },
  );

  test(
    'configuration uses existing firmware JSON contract without URL secrets',
    () async {
      final setup = TrackerLocalSetup(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url, endpoint);
          expect(request.url.toString(), isNot(contains('private-key')));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['wifi_ssid'], 'Home Network');
          expect(body['wifi_password'], 'sample-password');
          expect(body['device_id'], 'ESP32_123');
          expect(body['device_secret'], 'private-key');
          expect(body['backend_url'], 'https://example.com');
          expect(
            body['telemetry_url'],
            'https://example.com/api/v1/device/telemetry',
          );
          return http.Response('', 200);
        }),
      );
      expect(
        await setup.sendConfiguration(
          endpoint: endpoint,
          wifiName: 'Home Network',
          wifiPassword: 'sample-password',
          deviceId: 'ESP32_123',
          deviceSecret: 'private-key',
          backendUrl: 'https://example.com/',
        ),
        TrackerDelivery.accepted,
      );
    },
  );

  test(
    'restarting tracker leaves delivery unconfirmed, not successful',
    () async {
      final setup = TrackerLocalSetup(
        client: MockClient((_) async {
          throw http.ClientException('connection closed');
        }),
      );
      expect(
        await setup.sendConfiguration(
          endpoint: endpoint,
          wifiName: 'Home',
          wifiPassword: 'wrong',
          deviceId: 'ESP32_123',
          deviceSecret: 'secret',
          backendUrl: 'https://example.com',
        ),
        TrackerDelivery.unconfirmed,
      );
    },
  );

  test('rejected configuration stays an error', () async {
    final setup = TrackerLocalSetup(
      client: MockClient((_) async => http.Response('', 400)),
    );
    expect(
      () => setup.sendConfiguration(
        endpoint: endpoint,
        wifiName: 'Home',
        wifiPassword: 'wrong',
        deviceId: 'ESP32_123',
        deviceSecret: 'secret',
        backendUrl: 'https://example.com',
      ),
      throwsA(isA<TrackerConfigurationRejected>()),
    );
  });

  test('success requires fresh authenticated backend telemetry', () {
    final started = DateTime(2026, 10, 24, 10);
    DeviceModel device(String status, DateTime? seen) => DeviceModel(
      id: 'ESP32_123',
      deviceId: 'ESP32_123',
      status: status,
      lastSeen: seen,
      lowBatteryAlertActive: false,
    );
    expect(
      hasFreshOnlineReport(
        device('online', started.subtract(const Duration(minutes: 2))),
        started,
      ),
      isFalse,
    );
    expect(
      hasFreshOnlineReport(
        device('offline', started.add(const Duration(seconds: 5))),
        started,
      ),
      isFalse,
    );
    expect(hasFreshOnlineReport(device('online', null), started), isFalse);
    expect(
      hasFreshOnlineReport(
        device('online', started.add(const Duration(seconds: 5))),
        started,
      ),
      isTrue,
    );
  });
}
