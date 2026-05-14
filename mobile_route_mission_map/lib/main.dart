import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const RouteMissionApp());
}

class RouteMissionApp extends StatelessWidget {
  const RouteMissionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rota Görev Haritası',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D747C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F2),
      ),
      home: const MissionMapScreen(),
    );
  }
}

class MissionCheckpoint {
  MissionCheckpoint({
    required this.id,
    required this.name,
    required this.point,
    this.visited = false,
  });

  final String id;
  final String name;
  final LatLng point;
  bool visited;
}

enum MapVisualStyle {
  standard(
    label: 'Standart',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
  light(
    label: 'Açık',
    urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
  ),
  topo(
    label: 'Topografik',
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
  );

  const MapVisualStyle({
    required this.label,
    required this.urlTemplate,
  });

  final String label;
  final String urlTemplate;
}

class MissionMapScreen extends StatefulWidget {
  const MissionMapScreen({super.key});

  @override
  State<MissionMapScreen> createState() => _MissionMapScreenState();
}

class _MissionMapScreenState extends State<MissionMapScreen> {
  static const _initialCenter = LatLng(41.0082, 28.9784);
  static const _visitRadiusMeters = 38.0;
  static const _storageKey = 'route-mission-state-v2';

  final _mapController = MapController();
  final _distance = const Distance();
  final List<LatLng> _route = [];
  final List<MissionCheckpoint> _checkpoints = [];

  StreamSubscription<Position>? _positionSubscription;
  Timer? _durationTimer;
  Timer? _demoTimer;

  LatLng _center = _initialCenter;
  LatLng? _currentPoint;
  double? _accuracy;
  double _mapZoom = 17;
  double _distanceMeters = 0;
  int _missionRadius = 320;
  MapVisualStyle _mapStyle = MapVisualStyle.standard;
  bool _missionActive = false;
  bool _askingLocation = true;
  bool _isLocating = false;
  bool _initialized = false;
  DateTime? _startedAt;
  Duration _elapsedBeforePause = Duration.zero;
  String _status = 'Konum bekleniyor';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _demoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('$_storageKey-center-lat')) return;

    setState(() {
      _center = LatLng(
        prefs.getDouble('$_storageKey-center-lat') ?? _initialCenter.latitude,
        prefs.getDouble('$_storageKey-center-lng') ?? _initialCenter.longitude,
      );
      final currentLat = prefs.getDouble('$_storageKey-current-lat');
      final currentLng = prefs.getDouble('$_storageKey-current-lng');
      if (currentLat != null && currentLng != null) {
        _currentPoint = LatLng(currentLat, currentLng);
      }
      _accuracy = prefs.getDouble('$_storageKey-accuracy');
      _mapZoom = prefs.getDouble('$_storageKey-zoom') ?? 17;
      _distanceMeters = prefs.getDouble('$_storageKey-distance') ?? 0;
      _missionRadius = prefs.getInt('$_storageKey-radius') ?? 320;
      final styleIndex = prefs.getInt('$_storageKey-style');
      if (styleIndex != null && styleIndex < MapVisualStyle.values.length) {
        _mapStyle = MapVisualStyle.values[styleIndex];
      }
      _elapsedBeforePause = Duration(seconds: prefs.getInt('$_storageKey-elapsed') ?? 0);

      final routeJson = prefs.getString('$_storageKey-route');
      if (routeJson != null) {
        final list = jsonDecode(routeJson) as List;
        _route.addAll(list.map((e) => LatLng(e['lat'] as double, e['lng'] as double)));
      }

      final checkpointsJson = prefs.getString('$_storageKey-checkpoints');
      if (checkpointsJson != null) {
        final list = jsonDecode(checkpointsJson) as List;
        _checkpoints.addAll(list.map((e) => MissionCheckpoint(
              id: e['id'] as String,
              name: e['name'] as String,
              point: LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()),
              visited: e['visited'] as bool,
            )));
      }

      _status = _currentPoint == null ? 'Konum bekleniyor' : 'Konum alındı (kaydedildi)';
      _askingLocation = _currentPoint == null;
    });

    _initialized = true;
  }

  Future<void> _saveState() async {
    if (!_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('$_storageKey-center-lat', _center.latitude);
    await prefs.setDouble('$_storageKey-center-lng', _center.longitude);

    final current = _currentPoint;
    if (current != null) {
      await prefs.setDouble('$_storageKey-current-lat', current.latitude);
      await prefs.setDouble('$_storageKey-current-lng', current.longitude);
    } else {
      await prefs.remove('$_storageKey-current-lat');
      await prefs.remove('$_storageKey-current-lng');
    }

    if (_accuracy != null) {
      await prefs.setDouble('$_storageKey-accuracy', _accuracy!);
    } else {
      await prefs.remove('$_storageKey-accuracy');
    }

    await prefs.setDouble('$_storageKey-zoom', _mapZoom);
    await prefs.setDouble('$_storageKey-distance', _distanceMeters);
    await prefs.setInt('$_storageKey-radius', _missionRadius);
    await prefs.setInt('$_storageKey-style', _mapStyle.index);
    await prefs.setInt('$_storageKey-elapsed', _elapsed.inSeconds);

    if (_route.isNotEmpty) {
      await prefs.setString('$_storageKey-route', jsonEncode(
        _route.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList(),
      ));
    } else {
      await prefs.remove('$_storageKey-route');
    }

    if (_checkpoints.isNotEmpty) {
      await prefs.setString('$_storageKey-checkpoints', jsonEncode(
        _checkpoints.map((e) => {
          'id': e.id,
          'name': e.name,
          'lat': e.point.latitude,
          'lng': e.point.longitude,
          'visited': e.visited,
        }).toList(),
      ));
    } else {
      await prefs.remove('$_storageKey-checkpoints');
    }
  }

  int get _visitedCount => _checkpoints.where((checkpoint) => checkpoint.visited).length;

  int get _progress {
    if (_checkpoints.isEmpty) return 0;
    return ((_visitedCount / _checkpoints.length) * 100).round();
  }

  Duration get _elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) return _elapsedBeforePause;
    return _elapsedBeforePause + DateTime.now().difference(startedAt);
  }

  MissionCheckpoint? get _nextCheckpoint {
    for (final checkpoint in _checkpoints) {
      if (!checkpoint.visited) return checkpoint;
    }
    return null;
  }

  Future<void> _requestCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _status = 'Konum izni bekleniyor';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _setStatus('Konum servisi kapalı');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setStatus('Konum izni verilmedi');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setStatus('Konum izni ayarlardan açılmalı');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _applyPosition(position);
    } catch (_) {
      _setStatus('Konum alınamadı');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _askingLocation = false;
        });
      }
    }
  }

  Future<void> _startMission() async {
    _demoTimer?.cancel();
    _durationTimer?.cancel();

    setState(() {
      _missionActive = true;
      _askingLocation = false;
      _startedAt = DateTime.now();
      _status = 'Canlı konum izleniyor';
    });

    if (_currentPoint == null) {
      await _requestCurrentLocation();
    }

    final current = _currentPoint;
    if (current != null && _checkpoints.isEmpty) {
      _createMission(current);
    }

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4,
      ),
    ).listen(_applyPosition, onError: (_) => _setStatus('Konum izlenemiyor'));

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _saveState();
  }

  void _pauseMission() {
    _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _demoTimer?.cancel();

    setState(() {
      _missionActive = false;
      if (_startedAt != null) {
        _elapsedBeforePause += DateTime.now().difference(_startedAt!);
      }
      _startedAt = null;
      _status = 'Görev duraklatıldı';
    });

    _saveState();
  }

  void _resetMission() {
    _pauseMission();
    setState(() {
      _route.clear();
      _checkpoints.clear();
      _distanceMeters = 0;
      _elapsedBeforePause = Duration.zero;
      _status = _currentPoint == null ? 'Konum bekleniyor' : 'Konum alındı';
    });
    _clearSavedState();
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_storageKey)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  void _startDemoWalk() {
    _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _demoTimer?.cancel();

    final origin = _currentPoint ?? _center;
    _createMission(origin);

    setState(() {
      _route.clear();
      _distanceMeters = 0;
      _missionActive = true;
      _askingLocation = false;
      _startedAt = DateTime.now();
      _elapsedBeforePause = Duration.zero;
      _status = 'Demo yürüyüş oynatılıyor';
    });

    final demoRoute = <LatLng>[origin, ..._checkpoints.map((item) => item.point)];
    var segment = 0;
    var step = 0;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _saveState();

    _demoTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (segment >= demoRoute.length - 1) {
        timer.cancel();
        _setStatus('Demo görev tamamlandı');
        return;
      }

      step += 1;
      final from = demoRoute[segment];
      final to = demoRoute[segment + 1];
      final t = step / 18;
      final point = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      _applyLatLng(point, accuracy: 12);

      if (step >= 18) {
        step = 0;
        segment += 1;
      }
    });
  }

  void _applyPosition(Position position) {
    _applyLatLng(
      LatLng(position.latitude, position.longitude),
      accuracy: position.accuracy,
    );
  }

  void _applyLatLng(LatLng point, {double? accuracy}) {
    final previous = _route.isEmpty ? null : _route.last;

    setState(() {
      _currentPoint = point;
      _center = point;
      _accuracy = accuracy;
      _askingLocation = false;

      if (previous == null || _distance.as(LengthUnit.Meter, previous, point) >= 4) {
        if (previous != null) {
          _distanceMeters += _distance.as(LengthUnit.Meter, previous, point);
        }
        _route.add(point);
      }

      if (_missionActive && _checkpoints.isEmpty) {
        _createMission(point);
      }

      _updateVisitedPoints(point);
      _status = _missionActive ? 'Canlı konum izleniyor' : 'Konum alındı';
    });

    _mapController.move(point, _mapZoom);
    _saveState();
  }

  void _createMission(LatLng origin) {
    const bearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 25.0, 115.0, 205.0, 295.0];
    const distancePattern = [0.34, 0.48, 0.62, 0.77, 0.90, 0.55, 0.72, 0.42, 1.0, 0.86, 0.68, 0.52];

    _checkpoints
      ..clear()
      ..addAll(
        List.generate(bearings.length, (index) {
          return MissionCheckpoint(
            id: 'checkpoint-$index-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Kontrol ${index + 1}',
            point: _destinationPoint(
              origin,
              _missionRadius * distancePattern[index],
              bearings[index],
            ),
          );
        }),
      );
  }

  LatLng _destinationPoint(LatLng origin, double distanceMeters, double bearingDegrees) {
    const earthRadius = 6371000.0;
    final bearing = _toRad(bearingDegrees);
    final lat1 = _toRad(origin.latitude);
    final lng1 = _toRad(origin.longitude);
    final delta = distanceMeters / earthRadius;

    final lat2 = asin(
      sin(lat1) * cos(delta) + cos(lat1) * sin(delta) * cos(bearing),
    );
    final lng2 = lng1 +
        atan2(
          sin(bearing) * sin(delta) * cos(lat1),
          cos(delta) - sin(lat1) * sin(lat2),
        );

    return LatLng(_toDeg(lat2), _toDeg(lng2));
  }

  void _updateVisitedPoints(LatLng current) {
    for (final checkpoint in _checkpoints) {
      if (checkpoint.visited) continue;
      final distance = _distance.as(LengthUnit.Meter, current, checkpoint.point);
      if (distance <= _visitRadiusMeters) {
        checkpoint.visited = true;
      }
    }
  }

  void _recenter() {
    final point = _currentPoint;
    if (point == null) return;
    setState(() => _mapZoom = 17);
    _mapController.move(point, _mapZoom);
    _saveState();
  }

  void _zoomIn() {
    setState(() => _mapZoom = (_mapZoom + 1).clamp(3, 19).toDouble());
    _mapController.move(_mapController.camera.center, _mapZoom);
    _saveState();
  }

  void _zoomOut() {
    setState(() => _mapZoom = (_mapZoom - 1).clamp(3, 19).toDouble());
    _mapController.move(_mapController.camera.center, _mapZoom);
    _saveState();
  }

  void _changeMapStyle(MapVisualStyle style) {
    setState(() => _mapStyle = style);
    _saveState();
  }

  void _changeRadius(double value) {
    setState(() => _missionRadius = value.round());
    _saveState();
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() {
      _status = value;
      _isLocating = false;
    });
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.round()} m';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double _toRad(double value) => value * pi / 180;

  double _toDeg(double value) => value * 180 / pi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final map = _MapPane(
              center: _center,
              currentPoint: _currentPoint,
              accuracy: _accuracy,
              mapZoom: _mapZoom,
              mapStyle: _mapStyle,
              route: _route,
              checkpoints: _checkpoints,
              nextCheckpoint: _nextCheckpoint,
              controller: _mapController,
              status: _status,
              askingLocation: _askingLocation,
              locating: _isLocating,
              onRequestLocation: _requestCurrentLocation,
              onDismissLocation: () => setState(() => _askingLocation = false),
              onRecenter: _recenter,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onMapStyleChanged: _changeMapStyle,
            );

            final panel = _MissionPanel(
              progress: _progress,
              visited: _visitedCount,
              total: _checkpoints.length,
              traveledDistance: _formatDistance(_distanceMeters),
              accuracy: _accuracy == null ? '-' : '~${_accuracy!.round()} m',
              duration: _formatDuration(_elapsed),
              missionRadius: _missionRadius,
              missionActive: _missionActive,
              checkpoints: _checkpoints,
              currentPoint: _currentPoint,
              nextCheckpoint: _nextCheckpoint,
              onRadiusChanged: _changeRadius,
              onStart: _startMission,
              onPause: _pauseMission,
              onReset: _resetMission,
              onDemo: _startDemoWalk,
              distanceCalculator: _distance,
            );

            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: map),
                    const SizedBox(width: 16),
                    SizedBox(width: 390, child: panel),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(flex: 11, child: map),
                Expanded(flex: 9, child: panel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapPane extends StatelessWidget {
  const _MapPane({
    required this.center,
    required this.currentPoint,
    required this.accuracy,
    required this.mapZoom,
    required this.mapStyle,
    required this.route,
    required this.checkpoints,
    required this.nextCheckpoint,
    required this.controller,
    required this.status,
    required this.askingLocation,
    required this.locating,
    required this.onRequestLocation,
    required this.onDismissLocation,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMapStyleChanged,
  });

  final LatLng center;
  final LatLng? currentPoint;
  final double? accuracy;
  final double mapZoom;
  final MapVisualStyle mapStyle;
  final List<LatLng> route;
  final List<MissionCheckpoint> checkpoints;
  final MissionCheckpoint? nextCheckpoint;
  final MapController controller;
  final String status;
  final bool askingLocation;
  final bool locating;
  final VoidCallback onRequestLocation;
  final VoidCallback onDismissLocation;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<MapVisualStyle> onMapStyleChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: mapZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: mapStyle.urlTemplate,
                userAgentPackageName: 'com.unalcot.routemissionmap',
              ),
              if (route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      color: Colors.white.withValues(alpha:0.92),
                      strokeWidth: 9,
                    ),
                    Polyline(
                      points: route,
                      color: const Color(0xFFE4572E),
                      strokeWidth: 5,
                    ),
                  ],
                ),
              CircleLayer(
                circles: [
                  if (currentPoint != null && accuracy != null)
                    CircleMarker(
                      point: currentPoint!,
                      radius: accuracy!.clamp(18, 120).toDouble(),
                      color: const Color(0xFF0D747C).withValues(alpha:0.12),
                      borderColor: const Color(0xFF0D747C).withValues(alpha:0.35),
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  ...checkpoints.indexed.map((entry) {
                    final index = entry.$1;
                    final checkpoint = entry.$2;
                    final active = nextCheckpoint?.id == checkpoint.id;
                    return Marker(
                      point: checkpoint.point,
                      width: 36,
                      height: 36,
                      child: _CheckpointMarker(
                        label: '${index + 1}',
                        visited: checkpoint.visited,
                        active: active,
                      ),
                    );
                  }),
                  if (currentPoint != null)
                    Marker(
                      point: currentPoint!,
                      width: 34,
                      height: 34,
                      child: const _LocationMarker(),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 72,
            child: _MapHeader(status: status),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: _MapControlStack(
              selectedStyle: mapStyle,
              onRecenter: onRecenter,
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onMapStyleChanged: onMapStyleChanged,
            ),
          ),
          if (askingLocation)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _LocationPrompt(
                locating: locating,
                onRequestLocation: onRequestLocation,
                onDismissLocation: onDismissLocation,
              ),
            ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE4572E), Color(0xFFF3BA4D), Color(0xFF0D747C)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rota Görev Haritası',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64746F)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({
    required this.locating,
    required this.onRequestLocation,
    required this.onDismissLocation,
  });

  final bool locating;
  final VoidCallback onRequestLocation;
  final VoidCallback onDismissLocation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Konumunu güncelleyelim mi?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Haritayı cihazının mevcut konumuna taşımak için izin isteyeceğim.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64746F)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismissLocation,
                    child: const Text('Sonra'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: locating ? null : onRequestLocation,
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_searching_rounded),
                    label: const Text('Güncelle'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconMapButton extends StatelessWidget {
  const _IconMapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha:0.92),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: const Color(0xFF0A575D)),
          ),
        ),
      ),
    );
  }
}

class _MapControlStack extends StatelessWidget {
  const _MapControlStack({
    required this.selectedStyle,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMapStyleChanged,
  });

  final MapVisualStyle selectedStyle;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<MapVisualStyle> onMapStyleChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _IconMapButton(
            icon: Icons.my_location,
            tooltip: 'Konuma odaklan',
            onTap: onRecenter,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _IconMapButton(
                icon: Icons.remove_rounded,
                tooltip: 'Uzaklaştır',
                onTap: onZoomOut,
              ),
              const SizedBox(width: 8),
              _IconMapButton(
                icon: Icons.add_rounded,
                tooltip: 'Yakınlaştır',
                onTap: onZoomIn,
              ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.92),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MapVisualStyle>(
                  value: selectedStyle,
                  isExpanded: true,
                  icon: const Icon(Icons.layers_rounded, size: 18),
                  items: MapVisualStyle.values.map((style) {
                    return DropdownMenuItem(
                      value: style,
                      child: Text(
                        style.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  }).toList(),
                  onChanged: (style) {
                    if (style != null) onMapStyleChanged(style);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationMarker extends StatelessWidget {
  const _LocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0D747C),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D747C).withValues(alpha:0.28),
            spreadRadius: 8,
            blurRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _CheckpointMarker extends StatelessWidget {
  const _CheckpointMarker({
    required this.label,
    required this.visited,
    required this.active,
  });

  final String label;
  final bool visited;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = visited
        ? const Color(0xFF0F9F6E)
        : active
            ? const Color(0xFFE4572E)
            : const Color(0xFF1F5560);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.22),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({
    required this.progress,
    required this.visited,
    required this.total,
    required this.traveledDistance,
    required this.accuracy,
    required this.duration,
    required this.missionRadius,
    required this.missionActive,
    required this.checkpoints,
    required this.currentPoint,
    required this.nextCheckpoint,
    required this.onRadiusChanged,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onDemo,
    required this.distanceCalculator,
  });

  final int progress;
  final int visited;
  final int total;
  final String traveledDistance;
  final String accuracy;
  final String duration;
  final int missionRadius;
  final bool missionActive;
  final List<MissionCheckpoint> checkpoints;
  final LatLng? currentPoint;
  final MissionCheckpoint? nextCheckpoint;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onDemo;
  final Distance distanceCalculator;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F7F2),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProgressCard(progress: progress, total: total, nextCheckpoint: nextCheckpoint),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _StatCard(label: 'Geçilen', value: '$visited/$total'),
              _StatCard(label: 'Mesafe', value: traveledDistance),
              _StatCard(label: 'Doğruluk', value: accuracy),
              _StatCard(label: 'Süre', value: duration),
            ],
          ),
          const SizedBox(height: 12),
          _RadiusCard(value: missionRadius, onChanged: onRadiusChanged),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: missionActive ? null : onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Görevi Başlat'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: missionActive ? onPause : null,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Duraklat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDemo,
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('Demo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onReset,
            child: const Text('Sıfırla'),
          ),
          const SizedBox(height: 12),
          _CheckpointList(
            checkpoints: checkpoints,
            currentPoint: currentPoint,
            nextCheckpoint: nextCheckpoint,
            distance: distanceCalculator,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.total,
    required this.nextCheckpoint,
  });

  final int progress;
  final int total;
  final MissionCheckpoint? nextCheckpoint;

  @override
  Widget build(BuildContext context) {
    final hint = total == 0
        ? 'Görevi başlatınca yakın çevrende kontrol noktaları oluşur.'
        : progress == 100
            ? 'Görev tamamlandı. Yeni alan için sıfırlayıp tekrar başlatabilirsin.'
            : 'Sıradaki nokta: ${nextCheckpoint?.name ?? '-'}';

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _PanelLabel('Tamamlanma')),
              Text(
                '$progress%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 0.9,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progress / 100,
              backgroundColor: const Color(0xFFE5ECE7),
              color: const Color(0xFF0F9F6E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64746F)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PanelLabel(label),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RadiusCard extends StatelessWidget {
  const _RadiusCard({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelLabel('Görev alanı'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 120,
                  max: 700,
                  divisions: 29,
                  value: value.toDouble(),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '$value m',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckpointList extends StatelessWidget {
  const _CheckpointList({
    required this.checkpoints,
    required this.currentPoint,
    required this.nextCheckpoint,
    required this.distance,
  });

  final List<MissionCheckpoint> checkpoints;
  final LatLng? currentPoint;
  final MissionCheckpoint? nextCheckpoint;
  final Distance distance;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Görev Noktaları',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _PanelLabel(checkpoints.isEmpty ? 'Hazır' : 'Aktif'),
              ],
            ),
          ),
          const Divider(height: 1),
          if (checkpoints.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Henüz kontrol noktası yok.'),
            )
          else
            ...checkpoints.indexed.map((entry) {
              final index = entry.$1;
              final checkpoint = entry.$2;
              final active = nextCheckpoint?.id == checkpoint.id;
              final distanceText = currentPoint == null
                  ? '-'
                  : checkpoint.visited
                      ? 'Geçildi'
                      : '${distance.as(LengthUnit.Meter, currentPoint!, checkpoint.point).round()} m';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: checkpoint.visited
                      ? const Color(0xFF0F9F6E)
                      : active
                          ? const Color(0xFFE4572E)
                          : const Color(0xFFE7EEF0),
                  foregroundColor: checkpoint.visited || active ? Colors.white : const Color(0xFF315359),
                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                title: Text(checkpoint.name),
                trailing: Text(distanceText, style: const TextStyle(fontWeight: FontWeight.w800)),
              );
            }),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E1DA)),
      ),
      child: child,
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF64746F),
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
    );
  }
}
