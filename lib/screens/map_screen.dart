import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/toilet_model.dart';
import '../providers/app_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _mapStyle =
      "https://data.geopf.fr/annexes/ressources/vectorTiles/styles/PLAN.IGN/standard.json";
  static const double _initialPitch = 60.0;
  static const _userLocationSourceId = 'user-location-source';
  static const _userLocationLayerId = 'user-location-layer';
  static const _toiletsSourceId = 'toilets-source';
  static const _toiletsLayerId = 'toilets-layer';

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _isUpdatingSources = false;
  bool _sourcesAdded = false;
  int _lastToiletsCount = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateUpdated);
      appState.updateLocation();
    });
  }

  @override
  void dispose() {
    Provider.of<AppState>(context, listen: false)
        .removeListener(_onAppStateUpdated);
    _mapController?.dispose();
    super.dispose();
  }

  void _onAppStateUpdated() {
    if (_styleLoaded && _sourcesAdded) {
      _updateSources();
    }
  }

  Future<void> _updateSources() async {
    if (_isUpdatingSources || _mapController == null) return;

    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    _isUpdatingSources = true;
    try {
      // Délai de synchronisation
      await Future.delayed(const Duration(milliseconds: 100));

      // Update user location marker
      await _updateUserLocationMarker(appState);

      if (appState.nearbyToilets.isNotEmpty &&
          appState.nearbyToilets.length != _lastToiletsCount) {
        await _addToiletMarkers(appState);
        if (!mounted) return;
        setState(() {
          _lastToiletsCount = appState.nearbyToilets.length;
        });
      }
    } finally {
      _isUpdatingSources = false;
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _mapController!.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onSymbolTapped(Symbol symbol) {
    final properties = symbol.data;
    if (properties == null || properties['id'] == null) {
      return;
    }

    final toiletId = properties['id'];
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final toilet = appState.nearbyToilets.firstWhere((t) => t.id == toiletId);
      _showToiletDetails(toilet);
    } catch (e) {
      debugPrint('Toilet with id $toiletId not found.');
    }
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    if (_mapController == null) return;
    await _addImages();
    if (!_sourcesAdded) {
      await _initializeMapSources();
      _sourcesAdded = true;
    }
    _onAppStateUpdated();
  }

  Future<void> _initializeMapSources() async {
    if (_mapController == null) return;

    // Source pour l'utilisateur
    await _mapController!.addSource(
      _userLocationSourceId,
      const GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []}),
    );

    // Halo utilisateur - Couche 1
    await _mapController!.addLayer(
      _userLocationSourceId,
      'user-pulse-layer-1',
      const CircleLayerProperties(
        circleColor: '#FFA500',
        circleRadius: 12.0,
        circleOpacity: 0.6,
        circleBlur: 0.5,
        circlePitchAlignment: 'map',
        circlePitchScale: 'viewport',
        circleStrokeWidth: 0.0,
      ),
    );

    // Halo utilisateur - Couche 2
    await _mapController!.addLayer(
      _userLocationSourceId,
      'user-pulse-layer-2',
      const CircleLayerProperties(
        circleColor: '#FFA500',
        circleRadius: 18.0,
        circleOpacity: 0.35,
        circleBlur: 0.8,
        circlePitchAlignment: 'map',
        circlePitchScale: 'viewport',
        circleStrokeWidth: 0.0,
      ),
    );

    // Halo utilisateur - Couche 3
    await _mapController!.addLayer(
      _userLocationSourceId,
      'user-pulse-layer-3',
      const CircleLayerProperties(
        circleColor: '#FFA500',
        circleRadius: 24.0,
        circleOpacity: 0.15,
        circleBlur: 1.0,
        circlePitchAlignment: 'map',
        circlePitchScale: 'viewport',
        circleStrokeWidth: 0.0,
      ),
    );

    // Pin utilisateur
    await _mapController!.addLayer(
      _userLocationSourceId,
      _userLocationLayerId,
      const SymbolLayerProperties(
        iconImage: 'urgent-user-pin',
        iconSize: 0.4,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: 'bottom',
      ),
    );

    // Source pour les toilettes
    await _mapController!.addSource(
      _toiletsSourceId,
      const GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []}),
    );

    // Pin des toilettes
    await _mapController!.addLayer(
      _toiletsSourceId,
      _toiletsLayerId,
      const SymbolLayerProperties(
        iconImage: 'toilet-pin',
        iconSize: 0.5,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: 'bottom',
      ),
    );
  }

  Future<void> _addImages() async {
    if (_mapController == null) return;

    final toiletBytes = (await rootBundle.load('assets/images/toiletPin.png'))
        .buffer
        .asUint8List();
    await _mapController!.addImage('toilet-pin', toiletBytes);

    final urgentBytes = (await rootBundle.load('assets/images/urgentPin.png'))
        .buffer
        .asUint8List();
    await _mapController!.addImage('urgent-user-pin', urgentBytes);
  }

  Future<void> _updateUserLocationMarker(AppState appState) async {
    if (_mapController == null) return;
    final location = appState.currentLocation;

    if (location != null) {
      final geojson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [location.longitude, location.latitude]
            }
          }
        ]
      };

      try {
        await _mapController!.setGeoJsonSource(_userLocationSourceId, geojson);
      } catch (e) {
        debugPrint('Error updating user location: $e');
      }
    }
  }

  Future<void> _addToiletMarkers(AppState appState) async {
    if (_mapController == null) return;

    final features = appState.nearbyToilets.map((toilet) {
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [toilet.longitude, toilet.latitude],
        },
        'properties': {'id': toilet.id},
      };
    }).toList();

    final geojson = {'type': 'FeatureCollection', 'features': features};

    try {
      await _mapController!.setGeoJsonSource(_toiletsSourceId, geojson);
    } catch (e) {
      debugPrint('Error updating toilet markers: $e');
    }
  }

  void _recenterMap() {
    if (_mapController == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(appState.currentLocation!.latitude,
                appState.currentLocation!.longitude),
            zoom: 15.0,
            tilt: _initialPitch,
          ),
        ),
      );
    }
  }

  Future<void> _launchNavigation(Toilet toilet) async {
    final lat = toilet.latitude;
    final lon = toilet.longitude;

    Uri uri;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // For iOS, use Apple Maps URL scheme for walking directions.
      uri = Uri.parse('http://maps.apple.com/?daddr=$lat,$lon&dirflg=w');
    } else {
      // For Android and other platforms, use Google Maps URL with walking mode.
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking');
    }

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        throw Exception('Cannot launch navigation');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer la navigation.')),
        );
      }
    }
  }

  void _showToiletDetails(Toilet toilet) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                toilet.name ?? 'Toilettes publiques',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (toilet.openingHours != null) ...[
                Text('Horaires: ${toilet.openingHours}'),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('Y aller'),
                onPressed: () {
                  Navigator.pop(context);
                  _launchNavigation(toilet);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        title:
            Text(widget.title, style: Theme.of(context).textTheme.displayLarge),
      ),
      body: Stack(
        children: [
          appState.currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : MapLibreMap(
                  styleString: _mapStyle,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(appState.currentLocation!.latitude,
                        appState.currentLocation!.longitude),
                    zoom: 15.0,
                    tilt: _initialPitch,
                  ),
                  myLocationEnabled: false,
                  myLocationTrackingMode: MyLocationTrackingMode.none,
                ),
          if (appState.errorMessage != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    appState.errorMessage!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenterMap,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
