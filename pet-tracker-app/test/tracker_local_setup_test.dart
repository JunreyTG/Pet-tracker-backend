import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_tracker_app/data/models/models.dart';
import 'package:pet_tracker_app/features/devices/services/tracker_local_setup.dart';

const trackerId = 'PT-012345ABCDEF';
const nonce = '0bf93a862aad4928a236e42e0a20b926';

http.Response status({String id = trackerId, bool setupMode = true}) =>
    http.Response(
      jsonEncode({
        'protocol': TrackerLocalSetup.protocol,
        'device_id': id,
        'setup_mode': setupMode,
      }),
      200,
    );

Future<TrackerDelivery> configure(TrackerLocalSetup setup) =>
    setup.sendConfiguration(
      wifiName: 'Home Network',
      wifiPassword: 'sample-password',
      hotspotPassword: 'aabbccdd44556677',
      deviceId: trackerId,
      deviceSecret: 'private-key',
      backendUrl: 'https://example.com/',
      setupNonce: nonce,
    );

void main() {
  test('an unrelated device never receives setup credentials', () async {
    final setup = TrackerLocalSetup(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://192.168.4.1/api/status');
        expect(request.followRedirects, isFalse);
        return status(id: 'PT-012345111111');
      }),
    );
    await expectLater(
      configure(setup),
      throwsA(isA<TrackerIdentityMismatch>()),
    );
  });

  test('legacy and non-setup endpoints cannot confirm identity', () async {
    for (final reply in [http.Response('', 405), status(setupMode: false)]) {
      final setup = TrackerLocalSetup(client: MockClient((_) async => reply));
      expect(await setup.checkConnection(trackerId), isFalse);
    }
  });

  test(
    'matching setup posts credentials only to the fixed local endpoint',
    () async {
      final setup = TrackerLocalSetup(
        client: MockClient((request) async {
          if (request.method == 'GET') return status();
          expect(request.url, TrackerLocalSetup.endpoint);
          expect(request.followRedirects, isFalse);
          expect(request.headers['x-tracker-key'], 'aabbccdd44556677');
          expect(jsonDecode(request.body), {
            'wifi_ssid': 'Home Network',
            'wifi_password': 'sample-password',
            'device_id': trackerId,
            'device_secret': 'private-key',
            'backend_url': 'https://example.com',
            'setup_nonce': nonce,
          });
          return http.Response(
            jsonEncode({'accepted': true, 'device_id': trackerId}),
            202,
          );
        }),
      );
      expect(await configure(setup), TrackerDelivery.accepted);
    },
  );

  test('reboot during delivery requires cloud confirmation', () async {
    final setup = TrackerLocalSetup(
      client: MockClient((request) async {
        if (request.method == 'GET') return status();
        throw http.ClientException('connection closed');
      }),
    );
    expect(await configure(setup), TrackerDelivery.unconfirmed);
  });

  test('rejected configuration stays an error', () async {
    final setup = TrackerLocalSetup(
      client: MockClient(
        (request) async =>
            request.method == 'GET' ? status() : http.Response('', 403),
      ),
    );
    await expectLater(
      configure(setup),
      throwsA(isA<TrackerConfigurationRejected>()),
    );
  });

  test('only an online report for this pairing attempt confirms setup', () {
    DeviceModel device(String status, String? attempt, {bool fix = false}) =>
        DeviceModel.fromJson({
          'id': trackerId,
          'status': status,
          'setup_nonce': attempt,
          'last_seen': '2026-11-20T10:00:00Z',
          'gps_fix': fix,
        });
    expect(hasFreshOnlineReport(device('online', null), nonce), isFalse);
    expect(hasFreshOnlineReport(device('offline', nonce), nonce), isFalse);
    final heartbeat = device('online', nonce);
    expect(hasFreshOnlineReport(heartbeat, nonce), isTrue);
    expect(heartbeat.gpsFix, isFalse);
    expect(device('online', nonce, fix: true).gpsFix, isTrue);
  });
}
