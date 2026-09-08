part of '../main.dart';

class SafeZonesPage extends StatelessWidget {
  final List<Pet> pets;
  final List<SafeZone> safeZones;
  final ValueChanged<SafeZone> onSave;

  const SafeZonesPage({
    super.key,
    required this.pets,
    required this.safeZones,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Zones')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showSafeZoneDialog(context, pets: pets, onSave: onSave),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: safeZones
            .map(
              (zone) => SafeZoneCard(
                zone: zone,
                petName:
                    pets
                        .where((pet) => pet.id == zone.petId)
                        .firstOrNull
                        ?.name ??
                    'Unknown pet',
                onToggle: (enabled) => onSave(
                  SafeZone(
                    id: zone.id,
                    petId: zone.petId,
                    name: zone.name,
                    center: zone.center,
                    radiusMeters: zone.radiusMeters,
                    enabled: enabled,
                    lastState: zone.lastState,
                  ),
                ),
                onEdit: () => showSafeZoneDialog(
                  context,
                  pets: pets,
                  zone: zone,
                  onSave: onSave,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
