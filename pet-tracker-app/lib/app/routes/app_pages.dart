import 'package:get/get.dart';

import '../../features/alerts/views/alerts_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/devices/views/device_details_screen.dart';
import '../../features/devices/views/device_wifi_setup_screen.dart';
import '../../features/devices/views/devices_screen.dart';
import '../../features/geofences/views/geofence_form_screen.dart';
import '../../features/geofences/views/geofences_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/pets/views/pet_form_screen.dart';
import '../../features/pets/views/pet_details_screen.dart';
import '../../features/pets/views/pets_screen.dart';
import '../../features/profile/views/profile_screen.dart';
import '../../features/tracking/views/map_focus_screen.dart';
import '../../features/tracking/views/tracking_screen.dart';
import 'app_routes.dart';

class AppPages {
  static const loginScreen = LoginScreen();
  static const homeScreen = HomeScreen();

  static final pages = [
    GetPage(name: Routes.login, page: () => const LoginScreen()),
    GetPage(name: Routes.register, page: () => const RegisterScreen()),
    GetPage(name: Routes.home, page: () => const HomeScreen()),
    GetPage(name: Routes.pets, page: () => const PetsScreen()),
    GetPage(name: Routes.petDetails, page: () => const PetDetailsScreen()),
    GetPage(name: Routes.addPet, page: () => const PetFormScreen()),
    GetPage(name: Routes.devices, page: () => const DevicesScreen()),
    GetPage(
      name: Routes.deviceDetails,
      page: () => const DeviceDetailsScreen(),
    ),
    GetPage(
      name: Routes.deviceWifiSetup,
      page: () => const DeviceWifiSetupScreen(),
    ),
    GetPage(name: Routes.tracking, page: () => const TrackingScreen()),
    GetPage(name: Routes.mapFocus, page: () => const MapFocusScreen()),
    GetPage(name: Routes.geofences, page: () => const GeofencesScreen()),
    GetPage(
      name: Routes.geofenceForm,
      page: () => const GeofenceFormScreen(),
    ),
    GetPage(name: Routes.alerts, page: () => const AlertsScreen()),
    GetPage(name: Routes.profile, page: () => const ProfileScreen()),
  ];
}
