part of '../main.dart';

class TrackingPage extends StatefulWidget {
  final List<Pet> pets;
  final List<TrackerDevice> devices;
  final TrackerDevice? Function(Pet pet) deviceForPet;

  const TrackingPage({
    super.key,
    required this.pets,
    required this.devices,
    required this.deviceForPet,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  String? selectedPetId;

  @override
  Widget build(BuildContext context) {
    if (widget.pets.isEmpty) {
      return const PageShell(
        title: 'Live Tracking',
        subtitle: 'Displays frontend mock of ESP32 telemetry',
        children: [
          EmptyState(text: 'No pets available. Add a pet before tracking.'),
        ],
      );
    }

    final pet = widget.pets.firstWhere(
      (item) => item.id == (selectedPetId ?? widget.pets.first.id),
      orElse: () => widget.pets.first,
    );
    final device = widget.deviceForPet(pet);
    final location = device?.currentLocation;

    return PageShell(
      title: 'Live Tracking',
      subtitle: 'Displays frontend mock of ESP32 telemetry',
      children: [
        DropdownButtonFormField<String>(
          initialValue: pet.id,
          decoration: inputDecoration('Tracked pet'),
          items: widget.pets
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => selectedPetId = value),
        ),
        const SizedBox(height: 14),
        Container(
          height: 360,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECF2),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: MapPatternPainter())),
              Center(
                child: MapPetMarker(pet: pet, device: device),
              ),
              Positioned(
                left: 15,
                bottom: 15,
                child: StatusChip(
                  text: location == null
                      ? 'No telemetry yet'
                      : '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.battery_6_bar_rounded,
                title: 'Battery',
                value: device?.batteryLevel == null
                    ? 'Unknown'
                    : '${device!.batteryLevel}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoCard(
                icon: Icons.access_time_rounded,
                title: 'Last seen',
                value: relativeTime(device?.lastSeen),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
