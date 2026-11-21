import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pet_tracker_app/app/routes/app_pages.dart';
import 'package:pet_tracker_app/app/routes/app_routes.dart';
import 'package:pet_tracker_app/app/theme/app_preferences.dart';
import 'package:pet_tracker_app/core/api/api_client.dart';
import 'package:pet_tracker_app/core/api/api_exception.dart';
import 'package:pet_tracker_app/core/services/notification_service.dart';
import 'package:pet_tracker_app/data/models/models.dart';
import 'package:pet_tracker_app/data/repositories/repositories.dart';
import 'package:pet_tracker_app/features/alerts/views/alerts_screen.dart';
import 'package:pet_tracker_app/features/auth/controllers/auth_controller.dart';
import 'package:pet_tracker_app/features/auth/views/email_settings_screen.dart';
import 'package:pet_tracker_app/features/auth/views/login_screen.dart';
import 'package:pet_tracker_app/features/auth/views/register_screen.dart';
import 'package:pet_tracker_app/features/devices/services/tracker_local_setup.dart';
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
import 'package:pet_tracker_app/features/profile/views/settings_screen.dart';
import 'package:pet_tracker_app/features/tracking/controllers/tracking_controller.dart';
import 'package:pet_tracker_app/features/tracking/views/tracking_screen.dart';
import 'package:pet_tracker_app/main.dart';

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
  int alertsReads = 0;
  int emailSends = 0;
  bool emailVerified = false;
  bool emailAlerts = false;
  Map? trackerSetup;

  Map<String, dynamic> _emailUserJson() => {
    'uid': 'owner',
    'email': 'owner@example.com',
    'display_name': 'Owner',
    'email_verified': emailVerified,
    'email_verification_required': false,
    'email_alerts_enabled': emailAlerts,
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/alerts') alertsReads++;
    if (path == '/devices/ESP32_002') return _deviceJson();
    if (path == '/pets' && trackerSetup != null) {
      return [
        {'id': 'p1', 'name': 'Milo', 'species': 'Dog'},
      ];
    }
    if (path == '/devices/PT-012345ABCDEF') {
      if (trackerSetup?['name'] == null) {
        throw ApiException('Not found', statusCode: 404);
      }
      return {'device_id': 'PT-012345ABCDEF', 'pet_id': 'p1'};
    }
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
  Future<dynamic> post(String path, {Object? body}) async {
    if (path == '/devices/setup') {
      trackerSetup = body as Map;
      return {
        'device_id': 'PT-012345ABCDEF',
        'device_secret': 'test-only-secret',
        'backend_url': trackerSetup?['backend_url'],
      };
    }
    if (path == '/auth/email/send') {
      emailSends++;
      return <String, dynamic>{};
    }
    if (path == '/auth/email/verify') {
      emailVerified = true;
      return _emailUserJson();
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async {
    if (path == '/auth/me') {
      final changes = body is Map ? body : const {};
      return {
        'uid': 'owner',
        'email': 'owner@example.com',
        'display_name': changes['display_name'] ?? 'Owner',
        'phone': changes['phone'],
        'location': changes['location'],
        'bio': changes['bio'],
        'email_verified': false,
        'email_verification_required': false,
        'email_alerts_enabled': false,
      };
    }
    if (path == '/auth/email/alerts') {
      emailAlerts = (body as Map?)?['enabled'] == true;
      return _emailUserJson();
    }
    return <String, dynamic>{};
  }

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

  testWidgets('connecting by ID probes the tracker automatically', (
    tester,
  ) async {
    final api = Get.find<ApiClient>() as FakeApiClient;
    api.trackerSetup = {};
    var probes = 0;
    final setup = TrackerLocalSetup(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/status');
        probes++;
        return http.Response(
          '{"protocol":"pet-tracker-c3-v1","setup_mode":true,"device_id":"PT-012345ABCDEF"}',
          200,
        );
      }),
    );
    await _pumpScreen(tester, DeviceWifiSetupScreen(localSetup: setup));
    await tester.enterText(
      find.widgetWithText(TextField, 'Device name'),
      'Milo’s Tracker',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Device ID'),
      'PT-012345ABCDEF',
    );
    await tester.scrollUntilVisible(
      find.text('Connect Device'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Connect Device'));
    await tester.pumpAndSettle();
    expect(probes, 1);
    expect(api.trackerSetup?['name'], 'Milo’s Tracker');
    expect(find.text('Choose Your WiFi Network'), findsOneWidget);
  });

  testWidgets(
    'browser setup gives a truthful guide and supports back navigation',
    (tester) async {
      await _pumpScreen(
        tester,
        const DeviceWifiSetupScreen(browserOverride: true),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Device ID'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Device name'),
        'Milo’s Tracker',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Device ID'),
        'pt012345abcdef',
      );
      await tester.scrollUntilVisible(
        find.text('Connect Device'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Connect Device'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('PetTracker-ABCDEF'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('Finish setup in the Android app'), findsOneWidget);
      expect(find.text('Home WiFi network name'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Back'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tracking screen builds', (tester) async {
    await _pumpScreen(tester, const TrackingScreen());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    if (Get.isRegistered<TrackingController>()) {
      await Get.delete<TrackingController>(force: true);
    }
  });

  testWidgets('live map uses tracker coordinates without a saved focus', (
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
    final c = Get.find<TrackingController>();
    await c.fetchLive();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(c.mapController.camera.center.latitude, closeTo(5.01657, .001));
    expect(c.mapController.camera.center.longitude, closeTo(119.77074, .001));
    if (Get.isRegistered<TrackingController>()) {
      await Get.delete<TrackingController>(force: true);
    }
  });

  testWidgets('History shows the recorded trail and centers it on the map', (
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
    expect(c.history, isEmpty);
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final trail = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(trail.polylines.single.points.map((p) => p.latitude), [
      5.01570,
      5.01592,
      5.01613,
    ]);
    expect(c.mapController.camera.center.latitude, closeTo(5.016, .01));
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

  testWidgets('Menu unread shortcut opens the inbox with the unread filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const ProfileScreen(), getPages: AppPages.pages),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread alerts'));
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    final unread = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'unread'),
    );
    expect(unread.selected, isTrue);
  });

  testWidgets('email settings verifies the address and toggles alerts', (
    tester,
  ) async {
    final auth = Get.find<AuthController>();
    final api = Get.find<ApiClient>() as FakeApiClient;
    auth.backendUser.value = UserModel(
      uid: 'owner',
      email: 'owner@example.com',
      displayName: 'Owner',
    );
    await _pumpScreen(tester, const EmailSettingsScreen());
    expect(find.text('Email notifications'), findsOneWidget);
    expect(find.text('Email not verified'), findsOneWidget);
    await tester.tap(find.text('Send a code'));
    await tester.pumpAndSettle();
    expect(api.emailSends, 1);
    expect(find.textContaining('Code sent'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0123456789abcdef');
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();
    expect(auth.backendUser.value?.emailVerified, isTrue);
    expect(
      find.text('Email verified. You can now enable email alerts.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(api.emailAlerts, isTrue);
    expect(auth.backendUser.value?.emailAlertsEnabled, isTrue);
    auth.backendUser.value = null;
    await tester.pump();
  });

  testWidgets('profile form saves contact details', (tester) async {
    final auth = Get.find<AuthController>();
    auth.backendUser.value = UserModel(
      uid: 'owner',
      email: 'owner@example.com',
      displayName: 'Owner',
    );
    await _pumpScreen(tester, const AccountProfileScreen());
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Owner Name');
    await tester.enterText(fields.at(1), '0917 555 1234');
    await tester.enterText(fields.at(2), 'Bongao, Tawi-Tawi');
    await tester.enterText(fields.at(3), 'Dog dad and weekend hiker.');
    await tester.scrollUntilVisible(
      find.text('Save profile'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(auth.backendUser.value?.displayName, 'Owner Name');
    expect(auth.backendUser.value?.phone, '0917 555 1234');
    expect(auth.backendUser.value?.location, 'Bongao, Tawi-Tawi');
    expect(auth.backendUser.value?.bio, 'Dog dad and weekend hiker.');
    expect(find.text('Profile saved.'), findsOneWidget);
    auth.backendUser.value = null;
    await tester.pump();
  });

  testWidgets(
    'selecting dark mode keeps Settings open and persists the choice',
    (tester) async {
      await AppPreferences.load();
      await tester.pumpWidget(const PetTrackerApp());
      await tester.pumpAndSettle();
      Get.toNamed(Routes.settings);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      final settings = tester.element(find.text('Appearance'));
      expect(Theme.of(settings).brightness, Brightness.dark);
      AppPreferences.themeMode.value = ThemeMode.system;
      await AppPreferences.load();
      expect(AppPreferences.themeMode.value, ThemeMode.dark);
      await AppPreferences.setTheme(ThemeMode.system);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dashboard auto-refreshes while active, pauses, and refreshes on resume',
    (tester) async {
      await _pumpScreen(tester, const HomeScreen());
      final auth = Get.find<AuthController>();
      final api = Get.find<ApiClient>() as FakeApiClient;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      auth.backendUser.value = UserModel(
        uid: 'owner',
        email: 'owner@example.com',
        displayName: 'Owner',
      );
      await tester.pump();
      final initialReads = api.alertsReads;
      expect(initialReads, greaterThan(0));
      await tester.pump(const Duration(seconds: 30));
      expect(api.alertsReads, greaterThan(initialReads));
      final foregroundReads = api.alertsReads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(api.alertsReads, foregroundReads);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.alertsReads, greaterThan(foregroundReads));
      auth.backendUser.value = null;
      await tester.pump();
    },
  );
}
