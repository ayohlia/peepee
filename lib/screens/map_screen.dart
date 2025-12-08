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

  MaplibreMapController? _mapController;
  bool _styleLoaded = false;

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
    if (_styleLoaded) {
      _addToiletMarkers();
      _updateUserLocationMarker();
    }
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    if (_mapController == null) return;
    await _addImages();
    await _setupUserLocationLayer();
    _onAppStateUpdated(); // Appel initial pour les marqueurs
  }

  Future<void> _addImages() async {
    if (_mapController == null) return;
    final ByteData byteData =
        await rootBundle.load('assets/images/toiletPin.png');
    final Uint8List bytes = byteData.buffer.asUint8List();
    await _mapController!.addImage('toilet-pin', bytes);
  }

  Future<void> _setupUserLocationLayer() async {
    if (_mapController == null) return;
    // Ajoute une source pour la position de l'utilisateur avec des données initiales vides
    await _mapController!.addSource(
        _userLocationSourceId,
        const GeojsonSourceProperties(
            data: {'type': 'FeatureCollection', 'features': []}));

    // Ajoute une couche de cercle pour afficher la position
    await _mapController!.addLayer(
        _userLocationSourceId,
        _userLocationLayerId,
        const CircleLayerProperties(
          circleColor: '#FF9800', // Couleur orange
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
          circlePitchAlignment: 'map',
        ));
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

      // Met à jour la source de données GeoJSON
      await _mapController!.setGeoJsonSource(_userLocationSourceId, geojson);
    }
  }

  Future<void> _addToiletMarkers() async {
    if (_mapController == null) return;
    await _mapController!.clearSymbols();
    final appState = Provider.of<AppState>(context, listen: false);

    for (final toilet in appState.nearbyToilets) {
      await _mapController!.addSymbol(SymbolOptions(
        geometry: toilet,
        iconImage: 'toilet-pin',
        iconSize: 0.5,
      ));
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
