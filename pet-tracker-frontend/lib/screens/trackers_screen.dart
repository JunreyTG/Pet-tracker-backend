part of '../main.dart';

class TrackersPage extends StatelessWidget {
  final List<Pet> pets;
  final List<TrackerDevice> devices;
  final bool isSyncingDevices;
  final String devicesStatus;
  final String devicesMessage;
  final Future<void> Function() onLoadDevices;
  final Future<void> Function(String deviceId) onRegisterDevice;
  final Future<void> Function(TrackerDevice device, Pet? pet) onAssignDevice;

  const TrackersPage({
    super.key,
    required this.pets,
    required this.devices,
    required this.isSyncingDevices,
    required this.devicesStatus,
    required this.devicesMessage,
    required this.onLoadDevices,
    required this.onRegisterDevice,
    required this.onAssignDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Trackers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDeviceDialog(context, onRegisterDevice),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DevicesSyncCard(
            status: devicesStatus,
            message: devicesMessage,
            loading: isSyncingDevices,
            onLoadDevices: onLoadDevices,
          ),
          const SizedBox(height: 12),
          ...devices.map(
            (device) => DeviceCard(
              device: device,
              pet: pets.where((pet) => pet.id == device.petId).firstOrNull,
              pets: pets,
              onAssign: (pet) => onAssignDevice(device, pet),
            ),
          ),
        ],
      ),
    );
  }
}
