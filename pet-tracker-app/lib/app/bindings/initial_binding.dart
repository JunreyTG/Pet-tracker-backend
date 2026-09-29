import 'package:get/get.dart';

import '../../core/api/api_client.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/repositories.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/home/controllers/app_data_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ApiClient(), permanent: true);
    Get.put(PetRepository(Get.find()), permanent: true);
    Get.put(DeviceRepository(Get.find()), permanent: true);
    Get.put(GeofenceRepository(Get.find()), permanent: true);
    Get.put(PlaceRepository(Get.find()), permanent: true);
    Get.put(AlertRepository(Get.find()), permanent: true);
    Get.put(NotificationRepository(Get.find()), permanent: true);
    Get.put(BackendAuthRepository(Get.find()), permanent: true);
    Get.put(NotificationService(Get.find()), permanent: true);
    Get.put(AuthController(Get.find(), Get.find()), permanent: true);
    Get.put(
      AppDataController(Get.find(), Get.find(), Get.find(), Get.find()),
      permanent: true,
    );
  }
}
