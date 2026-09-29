import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pet_tracker_app/core/api/api_client.dart';
import 'package:pet_tracker_app/core/services/notification_service.dart';
import 'package:pet_tracker_app/data/models/models.dart';
import 'package:pet_tracker_app/data/repositories/repositories.dart';
import 'package:pet_tracker_app/features/alerts/views/alerts_screen.dart';
import 'package:pet_tracker_app/features/auth/controllers/auth_controller.dart';
import 'package:pet_tracker_app/features/auth/views/login_screen.dart';
import 'package:pet_tracker_app/features/auth/views/register_screen.dart';
import 'package:pet_tracker_app/features/devices/views/device_details_screen.dart';
import 'package:pet_tracker_app/features/devices/views/device_wifi_setup_screen.dart';
import 'package:pet_tracker_app/features/devices/views/devices_screen.dart';
import 'package:pet_tracker_app/features/geofences/views/geofences_screen.dart';
import 'package:pet_tracker_app/features/home/controllers/app_data_controller.dart';
import 'package:pet_tracker_app/features/home/views/home_screen.dart';
import 'package:pet_tracker_app/features/pets/views/pet_details_screen.dart';
import 'package:pet_tracker_app/features/pets/views/pet_form_screen.dart';
import 'package:pet_tracker_app/features/pets/views/pets_screen.dart';
import 'package:pet_tracker_app/features/profile/views/profile_screen.dart';
import 'package:pet_tracker_app/features/tracking/controllers/tracking_controller.dart';
import 'package:pet_tracker_app/features/tracking/views/tracking_screen.dart';

Map<String, dynamic> _deviceJson() => {
  'id': 'ESP32_002',
  'device_id': 'ESP32_002',
  'pet_id': 'p1',
  'status': 'online',
  'battery_level': 87,
  'current_location': {'latitude': 5.01657, 'longitude': 119.77074},
  'last_seen': '2026-09-26T17:00:17.906',
  'last_location_update': '2026-09-26T17:00:17.906',
  'low_battery_alert_active': false,
};

List<Map<String, dynamic>> _historyJson() => [
  {
    'id': 'h1',
    'pet_id': 'p1',
    'device_id': 'ESP32_002',
    'latitude': 5.01570,
    'longitude': 119.76995,
    'battery_level': 91,
    'recorded_at': '2026-09-26T16:58:00.000',
  },
  {
    'id': 'h2',
    'pet_id': 'p1',
    'device_id': 'ESP32_002',
    'latitude': 5.01592,
    'longitude': 119.77012,
    'battery_level': 90,
    'recorded_at': '2026-09-26T16:59:00.000',
  },
  {
    'id': 'h3',
    'pet_id': 'p1',
    'device_id': 'ESP32_002',
    'latitude': 5.01613,
    'longitude': 119.77032,
    'battery_level': 89,
    'recorded_at': '2026-09-26T17:00:00.000',
  },
];

class FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/devices/ESP32_002') return _deviceJson();
    if (path.contains('/location-history')) return _historyJson();
    if (path == '/places/countries') {
      return [
        {'code': 'PH', 'name': 'Philippines'},
      ];
    }
    if (path == '/places/provinces') {
      return [
        {'code': 'TT', 'name': 'Tawi-Tawi'},
      ];
    }
    if (path == '/places/cities') {
      return [
        {'code': 'BG', 'name': 'Bongao'},
      ];
    }
    if (path == '/places/barangays') {
      return [
        {'code': 'NL', 'name': 'Nalil'},
      ];
    }
    return <dynamic>[];
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async =>
      <String, dynamic>{};

  @override
  Future<dynamic> patch(String path, {Object? body}) async =>
      <String, dynamic>{};

  @override
  Future<dynamic> delete(String path) async => null;
}

void _registerFakes() {
  final api = FakeApiClient();
  Get.put<ApiClient>(api, permanent: true);
  Get.put(PetRepository(api), permanent: true);
  Get.put(DeviceRepository(api), permanent: true);
  Get.put(GeofenceRepository(api), permanent: true);
  Get.put(PlaceRepository(api), permanent: true);
  Get.put(AlertRepository(api), permanent: true);
  Get.put(NotificationRepository(api), permanent: true);
  Get.put(BackendAuthRepository(api), permanent: true);
  Get.put(NotificationService(Get.find()), permanent: true);
  Get.put(AuthController(Get.find(), Get.find()), permanent: true);
  Get.put(
    AppDataController(Get.find(), Get.find(), Get.find(), Get.find()),
    permanent: true,
  );
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(GetMaterialApp(home: screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('corrupt backend payloads', () {
    test('parseModelList skips malformed docs', () {
      final items = parseModelList([
        {
          'id': 'h1',
          'pet_id': 'p1',
          'device_id': 'ESP32_002',
          'latitude': 5.01,
          'longitude': 119.77,
        },
        {
          'id': 'bad',
          'pet_id': 'p1',
          'device_id': 'ESP32_002',
          'latitude': null,
          'longitude': null,
        },
        'not-a-map',
      ], LocationHistoryModel.fromJson);
      expect(items, hasLength(1));
      expect(items.first.id, 'h1');
    });

    test('device parses missing location and odd battery types', () {
      final fromNull = DeviceModel.fromJson({
        'device_id': 'ESP32_X',
        'current_location': null,
        'battery_level': null,
      });
      expect(fromNull.currentLocation, isNull);
      expect(fromNull.batteryLevel, isNull);

      final fromDouble = DeviceModel.fromJson({
        'device_id': 'ESP32_X',
        'battery_level': 87.9,
      });
      expect(fromDouble.batteryLevel, 87);
    });
  });

  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    _registerFakes();
  });

  tearDown(() async {
    if (Get.isRegistered<TrackingController>()) {
      await Get.delete<TrackingController>(force: true);
    }
    Get.reset();
  });

  testWidgets('login screen builds', (tester) async {
    await _pumpScreen(tester, const LoginScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('register screen builds', (tester) async {
    await _pumpScreen(tester, const RegisterScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen builds', (tester) async {
    await _pumpScreen(tester, const HomeScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('pets screen builds', (tester) async {
    await _pumpScreen(tester, const PetsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet details screen builds', (tester) async {
    await _pumpScreen(tester, const PetDetailsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet form screen builds', (tester) async {
    await _pumpScreen(tester, const PetFormScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('devices screen builds', (tester) async {
    await _pumpScreen(tester, const DevicesScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('device details screen builds', (tester) async {
    await _pumpScreen(tester, const DeviceDetailsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('device wifi setup screen builds', (tester) async {
    await _pumpScreen(tester, const DeviceWifiSetupScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracking screen builds', (tester) async {
    await _pumpScreen(tester, const TrackingScreen());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    if (Get.isRegistered<TrackingController>()) {
      await Get.delete<TrackingController>(force: true);
    }
  });

  testWidgets('tracking focus form builds with place options', (tester) async {
    final data = Get.find<AppDataController>();
    data.selectedPet.value = PetModel(
      id: 'p1',
      name: 'Tong',
      species: 'Dog',
      deviceId: 'ESP32_002',
    );
    await _pumpScreen(tester, const TrackingScreen());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Set map focus first'), findsOneWidget);
    if (Get.isRegistered<TrackingController>()) {
      await Get.delete<TrackingController>(force: true);
    }
  });

  testWidgets('tracking map renders with live device and history', (
    tester,
  ) async {
    final data = Get.find<AppDataController>();
    data.selectedPet.value = PetModel(
      id: 'p1',
      name: 'Tong',
      species: 'Dog',
      deviceId: 'ESP32_002',
    );
    await _pumpScreen(tester, const TrackingScreen());
    await tester.pump(const Duration(milliseconds: 500));
    final c = Get.find<TrackingController>();
    await c.fetchLive();
    await tester.pump(const Duration(milliseconds: 500));
    c.focusSet.value = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    if (Get.isRegistered<TrackingController>()) {
      await Get.delete<TrackingController>(force: true);
    }
  });

  testWidgets('geofences screen builds', (tester) async {
    await _pumpScreen(tester, const GeofencesScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('alerts screen builds', (tester) async {
    await _pumpScreen(tester, const AlertsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile screen builds', (tester) async {
    await _pumpScreen(tester, const ProfileScreen());
    expect(tester.takeException(), isNull);
  });
}
