import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'api/auth_api.dart';
import 'api/devices_api.dart';
import 'api/health_api.dart';
import 'api/pets_api.dart';
import 'core/network/api_client.dart';
import 'core/network/api_exception.dart';
import 'services/firebase_auth_service.dart';
export 'app/app.dart';
part 'models/app_models.dart';
part 'screens/login_screen.dart';
part 'screens/dashboard_screen.dart';
part 'screens/pets_screen.dart';
part 'screens/tracking_screen.dart';
part 'screens/alerts_screen.dart';
part 'screens/profile_screen.dart';
part 'screens/trackers_screen.dart';
part 'screens/safe_zones_screen.dart';
part 'screens/notification_settings_screen.dart';
part 'widgets/feature_widgets.dart';
part 'widgets/sync_status_cards.dart';
part 'widgets/auth_widgets.dart';
part 'widgets/shared_widgets.dart';
part 'utils/dialogs.dart';
part 'utils/ui_helpers.dart';

void main() {
  runApp(const ProviderScope(child: PetTrackerApp()));
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final FirebaseAuthService firebaseAuthService = FirebaseAuthService();
  late final ApiClient apiClient;
  late final HealthApi healthApi;
  late final AuthApi authApi;
  late final PetsApi petsApi;
  late final DevicesApi devicesApi;
  bool isCheckingBackend = false;
  String backendStatus = 'Not checked yet';
  String backendMessage = 'Tap Check Backend to call /health.';
  bool backendOnline = false;
  bool isAuthenticating = false;
  bool isSignedIn = false;
  String authStatus = 'Not signed in';
  String authMessage = 'Configure Firebase, then sign in and call /auth/me.';
  CurrentUser? backendUser;
  bool isSyncingPets = false;
  String petsStatus = 'Using local sample pets';
  String petsMessage = 'Sign in, then load pets from the backend.';
  bool isSyncingDevices = false;
  String devicesStatus = 'Using local sample trackers';
  String devicesMessage = 'Sign in, then load trackers from the backend.';
  final OwnerProfile owner = OwnerProfile(
    uid: 'firebase-user-001',
    email: 'owner@example.com',
    displayName: 'Test Owner',
  );
  final List<Pet> pets = [
    Pet(
      id: 'pet-max',
      name: 'Max',
      species: 'Dog',
      breed: 'Golden Retriever',
      age: 3,
      deviceId: 'dev-max',
    ),
    Pet(
      id: 'pet-milo',
      name: 'Milo',
      species: 'Cat',
      breed: 'Persian',
      age: 2,
      deviceId: 'dev-milo',
    ),
  ];
  final List<TrackerDevice> devices = [
    TrackerDevice(
      id: 'dev-max',
      deviceId: 'PT-ESP32-001',
      petId: 'pet-max',
      status: DeviceStatus.online,
      batteryLevel: 87,
      currentLocation: const LocationPoint(14.5995, 120.9842),
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      lastLocationUpdate: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    TrackerDevice(
      id: 'dev-milo',
      deviceId: 'PT-ESP32-002',
      petId: 'pet-milo',
      status: DeviceStatus.online,
      batteryLevel: 24,
      currentLocation: const LocationPoint(14.6042, 120.9822),
      lastSeen: DateTime.now().subtract(const Duration(minutes: 8)),
      lastLocationUpdate: DateTime.now().subtract(const Duration(minutes: 8)),
      lowBatteryAlertActive: true,
    ),
  ];
  final List<SafeZone> safeZones = [
    SafeZone(
      id: 'zone-home',
      petId: 'pet-max',
      name: 'Home',
      center: const LocationPoint(14.5995, 120.9842),
      radiusMeters: 100,
      lastState: GeofenceState.inside,
    ),
    SafeZone(
      id: 'zone-park',
      petId: 'pet-max',
      name: 'Park',
      center: const LocationPoint(14.6042, 120.9822),
      radiusMeters: 200,
      lastState: GeofenceState.outside,
    ),
  ];
  final List<TrackerAlert> alerts = [
    TrackerAlert(
      id: 'alert-1',
      petId: 'pet-max',
      deviceId: 'dev-max',
      type: TrackerAlertType.geofenceExit,
      title: 'Safe Zone Exit',
      message: 'Max left the Home safe zone.',
      location: const LocationPoint(14.6001, 120.985),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    TrackerAlert(
      id: 'alert-2',
      petId: 'pet-milo',
      deviceId: 'dev-milo',
      type: TrackerAlertType.lowBattery,
      title: 'Low Battery',
      message: "Milo's tracker battery is low.",
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  ];
  final List<PushToken> pushTokens = [
    PushToken(
      id: 'token-1',
      platform: NotificationPlatform.android,
      token: 'mock-fcm-token-android',
      deviceName: 'Owner phone',
    ),
  ];

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient(authTokenProvider: firebaseAuthService.idToken);
    healthApi = HealthApi(ApiClient());
    authApi = AuthApi(apiClient);
    petsApi = PetsApi(apiClient);
    devicesApi = DevicesApi(apiClient);
    initializeAuth();
  }

  Future<void> initializeAuth() async {
    await firebaseAuthService.initialize();
    if (!mounted) return;
    final user = firebaseAuthService.currentUser;
    setState(() {
      if (!firebaseAuthService.isConfigured) {
        authStatus = 'Firebase not configured';
        authMessage =
            'Add Firebase --dart-define values before using /auth/me.';
      } else if (user == null) {
        isSignedIn = false;
        authStatus = 'Ready';
        authMessage = 'Firebase is configured. Sign in or create an account.';
      } else {
        isSignedIn = true;
        authStatus = 'Signed in';
        authMessage = user.email ?? user.uid;
      }
    });
  }

  void openTab(int index) => setState(() => currentIndex = index);

  Future<void> loadPetsFromBackend() async {
    await runPetsAction('Loaded pets from backend.', () async {
      final backendPets = await petsApi.listPets();
      pets
        ..clear()
        ..addAll(backendPets.map(Pet.fromApi));
    });
  }

  Future<void> savePet(Pet pet) async {
    final isExisting = pets.any((item) => item.id == pet.id);
    await runPetsAction(
      isExisting ? 'Updated pet in backend.' : 'Created pet in backend.',
      () async {
        final savedPet = isExisting
            ? await petsApi.updatePet(pet.id, pet.toPayload())
            : await petsApi.createPet(pet.toPayload());
        final mappedPet = Pet.fromApi(savedPet);
        final index = pets.indexWhere((item) => item.id == mappedPet.id);
        if (index == -1) {
          pets.add(mappedPet);
        } else {
          pets[index] = mappedPet;
        }
      },
    );
  }

  Future<void> deletePet(Pet pet) async {
    await runPetsAction('Deleted pet from backend.', () async {
      await petsApi.deletePet(pet.id);
      pets.removeWhere((item) => item.id == pet.id);
      for (final device in devices.where((item) => item.petId == pet.id)) {
        device.petId = null;
      }
      safeZones.removeWhere((zone) => zone.petId == pet.id);
      alerts.removeWhere((alert) => alert.petId == pet.id);
    });
  }

  Future<void> runPetsAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    setState(() {
      isSyncingPets = true;
      petsStatus = 'Syncing pets...';
      petsMessage = 'Calling backend /api/v1/pets.';
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        petsStatus = 'Backend pets connected';
        petsMessage = successMessage;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        petsStatus = 'Pets sync failed';
        petsMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => isSyncingPets = false);
      }
    }
  }

  Future<void> loadDevicesFromBackend() async {
    await runDevicesAction('Loaded trackers from backend.', () async {
      final backendDevices = await devicesApi.listDevices();
      devices
        ..clear()
        ..addAll(backendDevices.map(TrackerDevice.fromApi));
      syncPetDeviceIds();
    });
  }

  Future<void> registerDevice(String publicId) async {
    await runDevicesAction('Registered tracker in backend.', () async {
      final registeredDevice = await devicesApi.registerDevice(publicId);
      upsertDevice(TrackerDevice.fromApi(registeredDevice));
    });
  }

  Future<void> assignDevice(TrackerDevice device, Pet? pet) async {
    await runDevicesAction(
      pet == null
          ? 'Unassigned tracker in backend.'
          : 'Assigned tracker to pet in backend.',
      () async {
        final updatedDevice = pet == null
            ? await devicesApi.unassignDevice(device.deviceId)
            : await devicesApi.assignDevice(
                deviceId: device.deviceId,
                petId: pet.id,
              );
        upsertDevice(TrackerDevice.fromApi(updatedDevice));
        syncPetDeviceIds();
      },
    );
  }

  Future<void> runDevicesAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    setState(() {
      isSyncingDevices = true;
      devicesStatus = 'Syncing trackers...';
      devicesMessage = 'Calling backend /api/v1/devices.';
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        devicesStatus = 'Backend trackers connected';
        devicesMessage = successMessage;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        devicesStatus = 'Tracker sync failed';
        devicesMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => isSyncingDevices = false);
      }
    }
  }

  void upsertDevice(TrackerDevice device) {
    final index = devices.indexWhere((item) => item.id == device.id);
    if (index == -1) {
      devices.add(device);
    } else {
      devices[index] = device;
    }
  }

  void syncPetDeviceIds() {
    for (final pet in pets) {
      pet.deviceId = devices
          .where((device) => device.petId == pet.id)
          .firstOrNull
          ?.id;
    }
  }

  void saveSafeZone(SafeZone zone) {
    setState(() {
      final index = safeZones.indexWhere((item) => item.id == zone.id);
      if (index == -1) {
        safeZones.add(zone);
      } else {
        safeZones[index] = zone;
      }
    });
  }

  void markAlertRead(TrackerAlert alert) => setState(() => alert.read = true);

  void deleteAlert(TrackerAlert alert) => setState(() => alerts.remove(alert));

  void saveToken(PushToken token) {
    setState(() {
      final index = pushTokens.indexWhere((item) => item.id == token.id);
      if (index == -1) {
        pushTokens.add(token);
      } else {
        pushTokens[index] = token;
      }
    });
  }

  TrackerDevice? deviceForPet(Pet pet) {
    for (final device in devices) {
      if (device.id == pet.deviceId || device.petId == pet.id) return device;
    }
    return null;
  }

  Future<void> checkBackendHealth() async {
    setState(() {
      isCheckingBackend = true;
      backendStatus = 'Checking...';
      backendMessage = 'Calling backend /health endpoint.';
      backendOnline = false;
    });

    try {
      final health = await healthApi.check();
      if (!mounted) return;
      setState(() {
        backendStatus = health.status;
        backendMessage = health.message;
        backendOnline = health.status.toLowerCase() == 'ok';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        backendStatus = 'Unavailable';
        backendMessage = error.message;
        backendOnline = false;
      });
    } finally {
      if (mounted) {
        setState(() => isCheckingBackend = false);
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    await runAuthAction(() async {
      await firebaseAuthService.signIn(email: email, password: password);
      final user = firebaseAuthService.currentUser;
      isSignedIn = true;
      authStatus = 'Signed in';
      authMessage = user?.email ?? user?.uid ?? 'Firebase user signed in.';
      backendUser = null;
    });
  }

  Future<void> signUp(String email, String password) async {
    await runAuthAction(() async {
      await firebaseAuthService.signUp(email: email, password: password);
      final user = firebaseAuthService.currentUser;
      isSignedIn = true;
      authStatus = 'Signed in';
      authMessage = user?.email ?? user?.uid ?? 'Firebase account created.';
      backendUser = null;
    });
  }

  Future<void> signOut() async {
    await runAuthAction(() async {
      await firebaseAuthService.signOut();
      isSignedIn = false;
      authStatus = firebaseAuthService.isConfigured
          ? 'Ready'
          : 'Firebase not configured';
      authMessage = firebaseAuthService.isConfigured
          ? 'Signed out. Sign in before calling /auth/me.'
          : 'Add Firebase --dart-define values before using /auth/me.';
      backendUser = null;
    });
  }

  Future<void> loadCurrentUser() async {
    await runAuthAction(() async {
      final user = await authApi.me();
      backendUser = user;
      authStatus = 'Backend verified';
      authMessage =
          '${user.displayName ?? 'Firebase User'} • ${user.email ?? user.uid}';
    });
  }

  Future<void> runAuthAction(Future<void> Function() action) async {
    setState(() => isAuthenticating = true);
    try {
      await action();
    } on ApiException catch (error) {
      authStatus = 'Backend auth failed';
      authMessage = error.message;
    } on FirebaseAuthServiceException catch (error) {
      authStatus = 'Firebase not configured';
      authMessage = error.message;
    } catch (error) {
      authStatus = 'Auth failed';
      authMessage = error.toString();
    } finally {
      if (mounted) {
        setState(() => isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSignedIn) {
      return LoginScreen(
        backendStatus: backendStatus,
        backendMessage: backendMessage,
        backendOnline: backendOnline,
        isCheckingBackend: isCheckingBackend,
        onCheckBackend: checkBackendHealth,
        authStatus: authStatus,
        authMessage: authMessage,
        backendUser: backendUser,
        isAuthenticating: isAuthenticating,
        onSignIn: signIn,
        onSignUp: signUp,
        onSignOut: signOut,
        onLoadCurrentUser: loadCurrentUser,
      );
    }

    final pages = [
      DashboardPage(
        pets: pets,
        devices: devices,
        alerts: alerts,
        deviceForPet: deviceForPet,
        openTab: openTab,
        backendStatus: backendStatus,
        backendMessage: backendMessage,
        backendOnline: backendOnline,
        isCheckingBackend: isCheckingBackend,
        onCheckBackend: checkBackendHealth,
        authStatus: authStatus,
        authMessage: authMessage,
        backendUser: backendUser,
        isAuthenticating: isAuthenticating,
        onSignIn: signIn,
        onSignUp: signUp,
        onSignOut: signOut,
        onLoadCurrentUser: loadCurrentUser,
      ),
      PetsPage(
        pets: pets,
        deviceForPet: deviceForPet,
        onSave: savePet,
        onDelete: deletePet,
        onLoadPets: loadPetsFromBackend,
        isSyncingPets: isSyncingPets,
        petsStatus: petsStatus,
        petsMessage: petsMessage,
      ),
      TrackingPage(pets: pets, devices: devices, deviceForPet: deviceForPet),
      AlertsPage(alerts: alerts, onRead: markAlertRead, onDelete: deleteAlert),
      ProfilePage(
        owner: owner,
        pets: pets,
        devices: devices,
        safeZones: safeZones,
        pushTokens: pushTokens,
        isSyncingDevices: isSyncingDevices,
        devicesStatus: devicesStatus,
        devicesMessage: devicesMessage,
        onLoadDevices: loadDevicesFromBackend,
        onRegisterDevice: registerDevice,
        onAssignDevice: assignDevice,
        onSaveSafeZone: saveSafeZone,
        onSaveToken: saveToken,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: openTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), label: 'Pets'),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
