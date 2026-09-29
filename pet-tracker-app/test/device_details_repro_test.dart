import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pet_tracker_app/core/api/api_client.dart';
import 'package:pet_tracker_app/core/services/notification_service.dart';
import 'package:pet_tracker_app/data/models/models.dart';
import 'package:pet_tracker_app/data/repositories/repositories.dart';
import 'package:pet_tracker_app/features/auth/controllers/auth_controller.dart';
import 'package:pet_tracker_app/features/devices/views/device_details_screen.dart';
import 'package:pet_tracker_app/features/home/controllers/app_data_controller.dart';

class FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String?> query = const {},
  }) async => <dynamic>[];

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

Future<void> _openDetails(WidgetTester tester, Object? argument) async {
  await tester.pumpWidget(
    GetMaterialApp(home: const Scaffold(body: SizedBox())),
  );
  Get.to(() => const DeviceDetailsScreen(), arguments: argument);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    _registerFakes();
  });

  tearDown(Get.reset);

  testWidgets('populated device renders', (tester) async {
    final data = Get.find<AppDataController>();
    data.pets.assignAll([
      PetModel(id: 'p1', name: 'Tong', species: 'Dog', deviceId: 'ESP32_002'),
    ]);
    data.devices.assignAll([
      DeviceModel(
        id: 'ESP32_002',
        deviceId: 'ESP32_002',
        petId: 'p1',
        status: 'online',
        batteryLevel: 87,
        currentLocation: LocationModel(latitude: 5.01, longitude: 119.77),
        lastSeen: DateTime(2026, 9, 26),
        lastLocationUpdate: DateTime(2026, 9, 26),
        lowBatteryAlertActive: false,
      ),
    ]);

    await _openDetails(tester, 'ESP32_002');

    expect(tester.takeException(), isNull);
    expect(find.text('ESP32_002'), findsOneWidget);
    expect(find.text('Assigned to Tong'), findsOneWidget);
  });

  testWidgets('missing optional fields render', (tester) async {
    final data = Get.find<AppDataController>();
    data.devices.assignAll([
      DeviceModel(
        id: 'ESP32_003',
        deviceId: 'ESP32_003',
        status: 'unregistered',
        lowBatteryAlertActive: false,
      ),
    ]);

    await _openDetails(tester, 'ESP32_003');

    expect(tester.takeException(), isNull);
    expect(find.text('No assigned pet'), findsOneWidget);
    expect(find.textContaining('Coordinates: None'), findsOneWidget);
  });

  testWidgets('no argument shows not found', (tester) async {
    final data = Get.find<AppDataController>();
    data.devices.assignAll([
      DeviceModel(
        id: 'ESP32_004',
        deviceId: 'ESP32_004',
        status: 'offline',
        lowBatteryAlertActive: false,
      ),
    ]);

    await _openDetails(tester, null);

    expect(tester.takeException(), isNull);
    expect(find.text('Tracker not found.'), findsOneWidget);
  });

  testWidgets('non-string argument does not crash', (tester) async {
    final data = Get.find<AppDataController>();
    data.devices.assignAll([
      DeviceModel(
        id: 'ESP32_005',
        deviceId: 'ESP32_005',
        status: 'offline',
        lowBatteryAlertActive: false,
      ),
    ]);

    await _openDetails(tester, 12345);

    expect(tester.takeException(), isNull);
    expect(find.text('Tracker not found.'), findsOneWidget);
  });

  testWidgets('device in list but different id shows not found', (
    tester,
  ) async {
    final data = Get.find<AppDataController>();
    data.devices.assignAll([
      DeviceModel(
        id: 'ESP32_006',
        deviceId: 'ESP32_006',
        status: 'offline',
        lowBatteryAlertActive: false,
      ),
    ]);

    await _openDetails(tester, 'ESP32_999');

    expect(tester.takeException(), isNull);
    expect(find.text('Tracker not found.'), findsOneWidget);
  });
}
