import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../home/controllers/app_data_controller.dart';
import '../controllers/tracking_controller.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<TrackingController>()
        ? Get.find<TrackingController>()
        : Get.put(TrackingController());
    final data = Get.find<AppDataController>();

    return AppScaffold(
      title: 'Tracking',
      currentIndex: 1,
      child: Obx(() {
        if (c.deviceId == null) {
          return const EmptyState(
            icon: Icons.link_off,
            title: 'No tracker assigned',
            message: 'Assign a tracker to a pet first.',
          );
        }
        if (!c.focusSet.value && c.focusLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!c.focusSet.value) {
          return _MapFocusPrompt(controller: c);
        }
        if (c.loading.value && c.device.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.error.value.isNotEmpty && c.device.value == null) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Backend error',
            message: c.error.value,
            action: FilledButton(
              onPressed: c.fetchLive,
              child: const Text('Retry'),
            ),
          );
        }

        final live = c.liveLatLng;
        final center =
            c.focusCenter.value ??
            live ??
            (c.history.isNotEmpty
                ? LatLng(c.history.last.latitude, c.history.last.longitude)
                : const LatLng(14.5995, 120.9842));
        final fences = data.geofences
            .where((g) => c.pet == null || g.petId == c.pet!.id)
            .toList();
        final historyPoints = c.trackPoints;

        return Stack(
          children: [
            FlutterMap(
              mapController: c.mapController,
              options: MapOptions(initialCenter: center, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'pet_tracker_app',
                ),
                CircleLayer(
                  circles: fences
                      .map(
                        (g) => CircleMarker(
                          point: LatLng(g.center.latitude, g.center.longitude),
                          radius: g.radiusMeters,
                          useRadiusInMeter: true,
                          color: Colors.green.withValues(alpha: .12),
                          borderColor: g.enabled ? Colors.green : Colors.grey,
                          borderStrokeWidth: 2,
                        ),
                      )
                      .toList(),
                ),
                if (c.mode.value == 'history' && historyPoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: historyPoints,
                        strokeWidth: 3.5,
                        color: AppTheme.orange,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (c.mode.value == 'history') ...[
                      ..._trailPawMarkers(historyPoints),
                      ..._trailWaypointMarkers(historyPoints),
                    ],
                    Marker(
                      point: center,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.place,
                        color: Colors.green,
                        size: 34,
                      ),
                    ),
                    if (live != null)
                      Marker(
                        point: live,
                        width: 130,
                        height: 110,
                        child: _JumpingPetMarker(
                          live: live,
                          petName: c.pet?.name ?? 'Pet',
                          photoUrl: c.pet?.photoUrl,
                          lastUpdate: c.device.value?.lastLocationUpdate,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Collapsible Top Pet Card
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _CollapsiblePetCard(controller: c, live: live),
            ),

            // Map Controls
            Positioned(
              right: 16,
              bottom: 110,
              child: Column(
                children: [
                  _MapRoundButton(
                    icon: Icons.my_location,
                    color: AppTheme.green,
                    onPressed: c.recenter,
                  ),
                  const SizedBox(height: 10),
                  _MapRoundButton(
                    icon: Icons.add,
                    onPressed: () => c.mapController.move(
                      c.mapController.camera.center,
                      c.mapController.camera.zoom + 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MapRoundButton(
                    icon: Icons.remove,
                    onPressed: () => c.mapController.move(
                      c.mapController.camera.center,
                      c.mapController.camera.zoom - 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  List<Marker> _trailPawMarkers(List<LatLng> points) {
    if (points.length < 2) return const [];
    final markers = <Marker>[];
    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      if (_samePoint(from, to)) continue;
      markers.add(
        Marker(
          point: LatLng(
            (from.latitude + to.latitude) / 2,
            (from.longitude + to.longitude) / 2,
          ),
          width: 22,
          height: 22,
          child: Transform.rotate(
            angle: _bearingRadians(from, to) + math.pi / 2,
            child: const Icon(
              Icons.pets,
              color: Colors.black87,
              size: 17,
              shadows: [Shadow(blurRadius: 2, color: Colors.white70)],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  List<Marker> _trailWaypointMarkers(List<LatLng> points) {
    if (points.isEmpty) return const [];
    final markers = <Marker>[];
    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      final isStart = i == 0;
      final isEnd = i == points.length - 1;
      if (isEnd) continue;
      markers.add(
        Marker(
          point: pt,
          width: isStart ? 38 : 26,
          height: isStart ? 38 : 26,
          child: Container(
            decoration: BoxDecoration(
              color: isStart ? const Color(0xFF2563EB) : AppTheme.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isStart
                  ? const Icon(Icons.flag, color: Colors.white, size: 18)
                  : Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  double _bearingRadians(LatLng from, LatLng to) {
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final deltaLon = _degreesToRadians(to.longitude - from.longitude);
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    return math.atan2(y, x);
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  bool _samePoint(LatLng a, LatLng b) =>
      a.latitude.toStringAsFixed(6) == b.latitude.toStringAsFixed(6) &&
      a.longitude.toStringAsFixed(6) == b.longitude.toStringAsFixed(6);
}

class _CollapsiblePetCard extends StatefulWidget {
  const _CollapsiblePetCard({
    required this.controller,
    required this.live,
  });

  final TrackingController controller;
  final LatLng? live;

  @override
  State<_CollapsiblePetCard> createState() => _CollapsiblePetCardState();
}

class _CollapsiblePetCardState extends State<_CollapsiblePetCard> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isOnline = c.device.value?.status == 'online';
    final battery = c.device.value?.batteryLevel?.toString() ?? '--';
    final petName = c.pet?.name ?? 'Pet';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: _minimized ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_minimized ? 20 : 28),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single row with Pet Name, Online status, Battery, Mode toggle, and Collapse/Expand Chevron
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.green,
                    width: 2,
                  ),
                ),
                child: PetAvatar(
                  photoUrl: c.pet?.photoUrl,
                  size: _minimized ? 36 : 46,
                  borderRadius: BorderRadius.circular(_minimized ? 18 : 23),
                ),
              ),
              const SizedBox(width: 10),
              // Single-row pet name text + status
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: _minimized ? 14 : 16,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? AppTheme.green : AppTheme.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$battery%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Mode switcher
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppTheme.green,
                  selectedForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: 'live', label: Text('Live', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 'history', label: Text('History', style: TextStyle(fontSize: 12))),
                ],
                selected: {c.mode.value},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  if (s.first == 'live') {
                    c.showLive();
                  } else {
                    c.loadHistory();
                  }
                },
              ),
              const SizedBox(width: 4),
              // Minimize / Maximize toggle dropdown
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _minimized = !_minimized),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _minimized ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    size: 24,
                    color: AppTheme.green,
                  ),
                ),
              ),
            ],
          ),

          // Extended Details (hidden when minimized)
          if (!_minimized) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Focus: ${c.focusLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Get.toNamed(Routes.mapFocus),
                  icon: const Icon(Icons.edit_location_alt, size: 16),
                  label: const Text('Edit Focus', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            if (widget.live == null)
              Text(
                c.device.value?.status == 'offline'
                    ? 'Tracker is offline. Showing saved focus area.'
                    : 'Awaiting GPS fix. Showing focus area.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.orange,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            if (c.mode.value == 'history')
              Text(
                c.history.isEmpty ? 'No recent history.' : '${c.history.length} location waypoints recorded',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _MapFocusPrompt extends StatelessWidget {
  const _MapFocusPrompt({required this.controller});

  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.travel_explore,
                      size: 40,
                      color: AppTheme.green,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Setup Focus Map',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your tracking area on the interactive map so the app knows where to center.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Get.toNamed(Routes.mapFocus),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text(
                        'Setup Focus Map & Start Tracking',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JumpingPetMarker extends StatefulWidget {
  const _JumpingPetMarker({
    required this.live,
    required this.petName,
    required this.photoUrl,
    required this.lastUpdate,
  });

  final LatLng live;
  final String petName;
  final String? photoUrl;
  final DateTime? lastUpdate;

  @override
  State<_JumpingPetMarker> createState() => _JumpingPetMarkerState();
}

class _JumpingPetMarkerState extends State<_JumpingPetMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jumpController;
  late final Animation<double> _jumpAnimation;

  @override
  void initState() {
    super.initState();
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -20.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -20.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_jumpController);

    _jumpController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant _JumpingPetMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live || oldWidget.lastUpdate != widget.lastUpdate) {
      _jumpController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _jumpAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _jumpAnimation.value),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppTheme.green,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.green.withValues(alpha: .35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: PetAvatar(
              photoUrl: widget.photoUrl,
              size: 50,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.green, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .14),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.petName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isGreen = color == AppTheme.green;
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: isGreen ? Colors.white : AppTheme.ink),
        ),
      ),
    );
  }
}
