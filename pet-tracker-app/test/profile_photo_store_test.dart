import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_tracker_app/features/profile/services/profile_photo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores profile photos per account on the device', () async {
    SharedPreferences.setMockInitialValues({});
    await ProfilePhotoStore.loadFor('owner');
    expect(ProfilePhotoStore.photo.value, isNull);

    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await ProfilePhotoStore.save(bytes);
    expect(ProfilePhotoStore.photo.value, bytes);

    await ProfilePhotoStore.loadFor('other');
    expect(ProfilePhotoStore.photo.value, isNull);

    await ProfilePhotoStore.loadFor('owner');
    expect(ProfilePhotoStore.photo.value, bytes);

    await ProfilePhotoStore.remove();
    expect(ProfilePhotoStore.photo.value, isNull);

    await ProfilePhotoStore.loadFor('owner');
    expect(ProfilePhotoStore.photo.value, isNull);
  });
}
