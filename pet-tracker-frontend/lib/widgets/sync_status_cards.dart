part of '../main.dart';

class PetsSyncCard extends StatelessWidget {
  final String status;
  final String message;
  final bool loading;
  final Future<void> Function() onLoadPets;

  const PetsSyncCard({
    super.key,
    required this.status,
    required this.message,
    required this.loading,
    required this.onLoadPets,
  });

  @override
  Widget build(BuildContext context) {
    final connected = status.toLowerCase().contains('connected');
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: connected
                  ? const Color(0xFFEAFBF1)
                  : const Color(0xFFEDEEFF),
              child: Icon(
                connected ? Icons.pets_rounded : Icons.sync_rounded,
                color: connected
                    ? const Color(0xFF15803D)
                    : const Color(0xFF5B5FEF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend Pets',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: connected
                          ? const Color(0xFF15803D)
                          : const Color(0xFF5B5FEF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF73778A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: loading ? null : onLoadPets,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(loading ? 'Loading' : 'Load'),
            ),
          ],
        ),
      ),
    );
  }
}

class DevicesSyncCard extends StatelessWidget {
  final String status;
  final String message;
  final bool loading;
  final Future<void> Function() onLoadDevices;

  const DevicesSyncCard({
    super.key,
    required this.status,
    required this.message,
    required this.loading,
    required this.onLoadDevices,
  });

  @override
  Widget build(BuildContext context) {
    final connected = status.toLowerCase().contains('connected');
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: connected
                  ? const Color(0xFFEAFBF1)
                  : const Color(0xFFEDEEFF),
              child: Icon(
                connected ? Icons.gps_fixed_rounded : Icons.sync_rounded,
                color: connected
                    ? const Color(0xFF15803D)
                    : const Color(0xFF5B5FEF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend Trackers',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: connected
                          ? const Color(0xFF15803D)
                          : const Color(0xFF5B5FEF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF73778A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: loading ? null : onLoadDevices,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(loading ? 'Loading' : 'Load'),
            ),
          ],
        ),
      ),
    );
  }
}
