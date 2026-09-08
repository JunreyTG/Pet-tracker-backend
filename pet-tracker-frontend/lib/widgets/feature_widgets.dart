part of '../main.dart';

class PetCard extends StatelessWidget {
  final Pet pet;
  final TrackerDevice? device;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const PetCard({
    super.key,
    required this.pet,
    required this.device,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        onTap: onTap,
        leading: PetAvatar(species: pet.species),
        title: Text(
          pet.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${pet.species}${pet.breed == null ? '' : ' • ${pet.breed}'}${pet.age == null ? '' : ' • ${pet.age} yrs'}\n${device == null ? 'No tracker assigned' : '${device!.deviceId} • ${device!.status.name} • ${device!.batteryLevel ?? '-'}%'}',
        ),
        isThreeLine: true,
        trailing: onDelete == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final TrackerDevice device;
  final Pet? pet;
  final List<Pet> pets;
  final ValueChanged<Pet?> onAssign;

  const DeviceCard({
    super.key,
    required this.device,
    required this.pet,
    required this.pets,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(
              Icons.gps_fixed_rounded,
              color: Color(0xFF5B5FEF),
            ),
            title: Text(
              device.deviceId,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Status: ${device.status.name} • Battery: ${device.batteryLevel ?? '-'}%',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String?>(
              initialValue: pet?.id,
              decoration: inputDecoration('Assigned pet'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                ...pets.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                ),
              ],
              onChanged: (value) => onAssign(
                value == null
                    ? null
                    : pets.firstWhere((item) => item.id == value),
              ),
            ),
          ),
          if (device.deviceSecret != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: InfoPanel(
                icon: Icons.key_rounded,
                text: 'Mock one-time device secret: ${device.deviceSecret}',
              ),
            ),
        ],
      ),
    );
  }
}

class SafeZoneCard extends StatelessWidget {
  final SafeZone zone;
  final String petName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const SafeZoneCard({
    super.key,
    required this.zone,
    required this.petName,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        onTap: onEdit,
        leading: const Icon(Icons.shield_rounded, color: Color(0xFF5B5FEF)),
        title: Text(
          zone.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$petName • ${zone.radiusMeters.toStringAsFixed(0)} meters • ${zone.lastState?.name ?? 'unchecked'}',
        ),
        trailing: Switch(value: zone.enabled, onChanged: onToggle),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final TrackerAlert alert;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  const AlertCard({
    super.key,
    required this.alert,
    required this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: Icon(alertIcon(alert.type), color: const Color(0xFF5B5FEF)),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${alert.message}\n${relativeTime(alert.createdAt)}'),
        isThreeLine: true,
        trailing: Wrap(
          children: [
            if (!alert.read)
              IconButton(
                icon: const Icon(Icons.done_rounded),
                onPressed: onRead,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
