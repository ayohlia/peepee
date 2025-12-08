import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // URL du style Plan IGN standard (souvent un bon point de départ pour le routier)
  static const String _mapStyle =
      "https://data.geopf.fr/annexes/ressources/vectorTiles/styles/PLAN.IGN/standard.json";
  static const double _initialPitch = 60.0;
  static const _userLocationSourceId = 'user-location-source';
  static const _userLocationLayerId = 'user-location-layer';
  static const _toiletsSourceId = 'toilets-source';
  static const _toiletsLayerId = 'toilets-layer';

  MaplibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _isUpdatingSources = false; // Lock flag
  bool _sourcesAdded = false;

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

    _isUpdatingSources = true;
    try {
      // Run updates sequentially to avoid race conditions.
      await _addToiletMarkers();
      await _updateUserLocationMarker();
    } finally {
      _isUpdatingSources = false;
    }
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    if (_mapController == null) return;
    await _addImages();
    if (!_sourcesAdded) {
      await _initializeMapSources();
      _sourcesAdded = true;
    }
    _onAppStateUpdated(); // Initial call to load data
  }

  Future<void> _initializeMapSources() async {
    if (_mapController == null) return;

    // Defensively remove existing layers and sources to prevent crashes on hot restart
    try {
      await _mapController!.removeLayer(_userLocationLayerId);
      await _mapController!.removeSource(_userLocationSourceId);
    } catch (_) {
      // Ignore if they don't exist
    }
    try {
      await _mapController!.removeLayer(_toiletsLayerId);
      await _mapController!.removeSource(_toiletsSourceId);
    } catch (_) {
      // Ignore if they don't exist
    }

    // Add user location source and layer
    await _mapController!.addSource(
      _userLocationSourceId,
      const GeojsonSourceProperties(data: {
        'type': 'FeatureCollection',
        'features': [],
      }),
    );
    await _mapController!.addLayer(
        _userLocationSourceId,
        _userLocationLayerId,
        const SymbolLayerProperties(
          iconImage: 'urgent-user-pin',
          iconSize: 0.5,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ));

    // Add toilets source and layer
    await _mapController!.addSource(
      _toiletsSourceId,
      const GeojsonSourceProperties(data: {
        'type': 'FeatureCollection',
        'features': [],
      }),
    );
    await _mapController!.addLayer(
      _toiletsSourceId,
      _toiletsLayerId,
      const SymbolLayerProperties(
        iconImage: 'toilet-pin',
        iconSize: 0.5,
        iconAllowOverlap: true,
      ),
    );
  }

  Future<void> _addImages() async {
    if (_mapController == null) return;
    final ByteData byteData =
        await rootBundle.load('assets/images/toiletPin.png');
    final Uint8List bytes = byteData.buffer.asUint8List();
    await _mapController!.addImage('toilet-pin', bytes);
    final urgentBytes = (await rootBundle.load('assets/images/urgentPin.png'))
        .buffer
        .asUint8List();
    await _mapController!.addImage('urgent-user-pin', urgentBytes);
  }

  Future<void> _updateUserLocationMarker() async {
    if (_mapController == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
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

      await _mapController!.setGeoJsonSource(_userLocationSourceId, geojson);
    }
  }

  Future<void> _addToiletMarkers() async {
    if (_mapController == null) return;
    final appState = Provider.of<AppState>(context, listen: false);

    final features = appState.nearbyToilets.map((toilet) {
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [toilet.longitude, toilet.latitude],
        },
        'properties': {},
      };
    }).toList();

    final geojson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    await _mapController!.setGeoJsonSource(_toiletsSourceId, geojson);
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
      body: appState.currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : MaplibreMap(
              styleString: _mapStyle,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              initialCameraPosition: CameraPosition(
                target: LatLng(appState.currentLocation!.latitude,
                    appState.currentLocation!.longitude),
                zoom: 15.0,
                tilt: _initialPitch,
              ),
              myLocationEnabled: false, // Désactive le point par défaut
              myLocationTrackingMode: MyLocationTrackingMode.none,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenterMap,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
