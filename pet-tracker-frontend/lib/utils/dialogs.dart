part of '../main.dart';

void showPetDialog(
  BuildContext context, {
  Pet? pet,
  required Future<void> Function(Pet pet) onSave,
}) {
  final name = TextEditingController(text: pet?.name ?? '');
  final species = TextEditingController(text: pet?.species ?? 'Dog');
  final breed = TextEditingController(text: pet?.breed ?? '');
  final age = TextEditingController(text: pet?.age?.toString() ?? '');
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(pet == null ? 'Add Pet' : 'Edit Pet'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: inputDecoration('Name')),
            const SizedBox(height: 10),
            TextField(
              controller: species,
              decoration: inputDecoration('Species'),
            ),
            const SizedBox(height: 10),
            TextField(controller: breed, decoration: inputDecoration('Breed')),
            const SizedBox(height: 10),
            TextField(
              controller: age,
              decoration: inputDecoration('Age'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty || species.text.trim().isEmpty) return;
            await onSave(
              Pet(
                id: pet?.id ?? 'pet-${DateTime.now().millisecondsSinceEpoch}',
                name: name.text.trim(),
                species: species.text.trim(),
                breed: breed.text.trim().isEmpty ? null : breed.text.trim(),
                age: int.tryParse(age.text.trim()),
                photoUrl: pet?.photoUrl,
                deviceId: pet?.deviceId,
              ),
            );
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showDeviceDialog(
  BuildContext context,
  Future<void> Function(String deviceId) onRegisterDevice,
) {
  final deviceId = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Register Tracker'),
      content: TextField(
        controller: deviceId,
        decoration: inputDecoration('Public device ID'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (deviceId.text.trim().isEmpty) return;
            await onRegisterDevice(deviceId.text.trim());
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: const Text('Register'),
        ),
      ],
    ),
  );
}

void showSafeZoneDialog(
  BuildContext context, {
  required List<Pet> pets,
  SafeZone? zone,
  required ValueChanged<SafeZone> onSave,
}) {
  final name = TextEditingController(text: zone?.name ?? '');
  final radius = TextEditingController(
    text: zone?.radiusMeters.toStringAsFixed(0) ?? '100',
  );
  final lat = TextEditingController(
    text: zone?.center.latitude.toString() ?? '14.5995',
  );
  final lng = TextEditingController(
    text: zone?.center.longitude.toString() ?? '120.9842',
  );
  var petId = zone?.petId ?? pets.firstOrNull?.id;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(zone == null ? 'Add Safe Zone' : 'Edit Safe Zone'),
      content: StatefulBuilder(
        builder: (context, setDialogState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: petId,
                decoration: inputDecoration('Pet'),
                items: pets
                    .map(
                      (pet) => DropdownMenuItem(
                        value: pet.id,
                        child: Text(pet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => petId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                decoration: inputDecoration('Zone name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: radius,
                decoration: inputDecoration('Radius meters'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lat,
                decoration: inputDecoration('Latitude'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lng,
                decoration: inputDecoration('Longitude'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (petId == null || name.text.trim().isEmpty) return;
            onSave(
              SafeZone(
                id: zone?.id ?? 'zone-${DateTime.now().millisecondsSinceEpoch}',
                petId: petId!,
                name: name.text.trim(),
                center: LocationPoint(
                  double.tryParse(lat.text.trim()) ?? 0,
                  double.tryParse(lng.text.trim()) ?? 0,
                ),
                radiusMeters: double.tryParse(radius.text.trim()) ?? 100,
                enabled: zone?.enabled ?? true,
                lastState: zone?.lastState,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showTokenDialog(
  BuildContext context, {
  required ValueChanged<PushToken> onSave,
}) {
  final token = TextEditingController();
  final deviceName = TextEditingController();
  var platform = NotificationPlatform.android;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Push Token'),
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<NotificationPlatform>(
              initialValue: platform,
              decoration: inputDecoration('Platform'),
              items: NotificationPlatform.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.name)),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => platform = value!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: deviceName,
              decoration: inputDecoration('Device name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: token,
              decoration: inputDecoration('FCM token'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (token.text.trim().isEmpty) return;
            onSave(
              PushToken(
                id: 'token-${DateTime.now().millisecondsSinceEpoch}',
                platform: platform,
                token: token.text.trim(),
                deviceName: deviceName.text.trim().isEmpty
                    ? null
                    : deviceName.text.trim(),
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
