import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/marker_manager_service.dart';

class MapView extends StatefulWidget {
  const MapView({super.key, required this.title});

  final String title;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const String _mapStyle =
      "https://data.geopf.fr/annexes/ressources/vectorTiles/styles/PLAN.IGN/standard.json";
  static const double _cameraPitch = 37.5; // Angle de confort de lecture
  static const _userLocationSourceId = 'user-location-source';
  static const _userLocationLayerId = 'user-location-layer';
  static const double _movementThreshold =
      3.0; // Seuil de déplacement en mètres
  static const double _bearingThreshold =
      5.0; // Seuil de changement d'orientation en degrés

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _isUpdatingSources = false;
  bool _sourcesAdded = false;
  double _currentZoom = 15.0;

  MarkerManagerService? _markerManager;
  Timer? _mapUpdateDebounce;
  Timer? _cameraUpdateDebounce;
  Position? _lastUserPosition;
  double? _lastHeading; // Dernier heading GPS pour calculer l'orientation

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateUpdated);

      // Forcer le chargement initial des toilettes
      debugPrint('Début chargement initial des toilettes...');
      appState.updateLocation().then((_) {
        debugPrint('Chargement initial terminé');
      }).catchError((e) {
        debugPrint('Erreur chargement initial: $e');
      });
    });
  }

  @override
  void dispose() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_onAppStateUpdated);
    _markerManager?.dispose();
    _mapUpdateDebounce?.cancel();
    _cameraUpdateDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onAppStateUpdated() {
    if (_styleLoaded && _sourcesAdded) {
      final appState = Provider.of<AppState>(context, listen: false);

      if (_markerManager != null) {
        _markerManager!.selectedToiletId = appState.selectedToiletId;
      }

      // Optimized camera update with debouncing
      _debouncedCameraUpdate(appState);

      // Toujours mettre à jour les sources pour diagnostiquer
      debugPrint(
          'AppState mis à jour: ${appState.nearbyToilets.length} toilettes disponibles');

      // Si pas de toilettes chargées après 5 secondes, utiliser le fallback
      if (appState.nearbyToilets.isEmpty) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && appState.nearbyToilets.isEmpty) {
            debugPrint('Tentative de chargement fallback sans position...');
            appState.loadToiletsWithoutLocation().then((_) {
              debugPrint('Chargement fallback terminé');
            }).catchError((e) {
              debugPrint('Erreur chargement fallback: $e');
            });
          }
        });
      }

      _updateSources();
    }
  }

  void _debouncedCameraUpdate(AppState appState) {
    _cameraUpdateDebounce?.cancel();
    _cameraUpdateDebounce = Timer(const Duration(milliseconds: 8), () {
      _updateUserLocationAndCamera(appState);
    });
  }

  Future<void> _updateUserLocationAndCamera(AppState appState) async {
    final currentPosition = appState.currentLocation;
    if (currentPosition == null) return;

    // Only update if position changed significantly
    if (_lastUserPosition == null ||
        _hasSignificantLocationChange(_lastUserPosition!, currentPosition)) {
      // Suivre le heading GPS pour l'orientation
      _lastHeading = currentPosition.heading;
      _lastUserPosition = currentPosition;

      final hasLocationChanged = await _updateUserLocationMarker(appState);
      if (mounted && hasLocationChanged) {
        _updateCameraPosition();
      }
    }
  }

  bool _hasSignificantLocationChange(Position oldPos, Position newPos) {
    // Calculer la distance de déplacement avec seuil plus sensible
    final distance = Geolocator.distanceBetween(
      oldPos.latitude,
      oldPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    // Vérifier le changement de direction avec seuil plus sensible
    final headingChange =
        _lastHeading != null ? (newPos.heading - _lastHeading!).abs() : 0.0;

    // Logique OR pour plus de réactivité: déplacement OU changement d'orientation
    return distance > _movementThreshold || headingChange > _bearingThreshold;
  }

  Future<void> _updateSources() async {
    if (_isUpdatingSources || _mapController == null) return;

    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    _isUpdatingSources = true;
    try {
      // Optimisation: mise à jour immédiate sans délai
      if (_markerManager != null && appState.nearbyToilets.isNotEmpty) {
        debugPrint(
            'Mise à jour des marqueurs: ${appState.nearbyToilets.length} toilettes');

        // Récupérer bounds avec gestion d'erreur
        LatLngBounds? bounds;
        try {
          bounds = await _mapController!.getVisibleRegion();
        } catch (e) {
          debugPrint('Erreur récupération bounds: $e');
          // Utiliser bounds par défaut en cas d'erreur
          bounds = null;
        }

        if (_mapController?.cameraPosition != null) {
          _currentZoom = _mapController!.cameraPosition!.zoom;
        }

        debugPrint(
            'Bounds visibles: ${bounds?.southwest} à ${bounds?.northeast}');

        // Mise à jour optimisée des marqueurs TOUS sans filtrage
        try {
          await _markerManager!.updateMarkers(
            allToilets: appState.nearbyToilets,
            visibleBounds: bounds ?? _getDefaultBounds(),
            zoomLevel: _currentZoom,
          );
          debugPrint('Marqueurs mis à jour avec succès');
        } catch (e) {
          debugPrint('Erreur mise à jour marqueurs: $e');
        }
      } else {
        debugPrint('Pas de toilettes à afficher ou marker manager null');
      }
    } catch (e) {
      debugPrint('Error updating sources: $e');
    } finally {
      _isUpdatingSources = false;
    }
  }

  LatLngBounds _getDefaultBounds() {
    // Bounds par défaut en cas d'erreur de récupération
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentLocation != null) {
      final center = LatLng(
        appState.currentLocation!.latitude,
        appState.currentLocation!.longitude,
      );
      const offset = 0.01; // ~1km
      return LatLngBounds(
        southwest: LatLng(center.latitude - offset, center.longitude - offset),
        northeast: LatLng(center.latitude + offset, center.longitude + offset),
      );
    }
    // Bounds par défaut absolues
    return LatLngBounds(
      southwest: const LatLng(48.8, 2.3), // Paris approx
      northeast: const LatLng(48.9, 2.4),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _markerManager = MarkerManagerService(controller);
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    if (_mapController == null) return;
    await _addImages();
    if (!_sourcesAdded) {
      await _initializeMapSources();
      // Initialiser la source et la couche des toilettes
      await _markerManager?.initializeToiletSource();
      await _markerManager?.initializeToiletLayer();
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
  }

  Future<void> _addImages() async {
    if (_mapController == null) return;

    Future<void> addImageFromAsset(String name, String assetPath) async {
      try {
        final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
        await _mapController!.addImage(name, bytes);
        debugPrint('Image chargée avec succès: $name');
      } catch (e) {
        debugPrint('Erreur chargement image $name depuis $assetPath: $e');
      }
    }

    debugPrint('Début chargement des images...');
    await addImageFromAsset('toilet-pin', 'assets/images/toiletPin.png');
    await addImageFromAsset('urgent-user-pin', 'assets/images/urgentPin.png');
    await addImageFromAsset(
        'toilet-pin-selected', 'assets/images/toiletPinSelected.png');

    debugPrint('Chargement des images terminé');
  }

  Future<bool> _updateUserLocationMarker(AppState appState) async {
    if (_mapController == null) return false;
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
        return true;
      } catch (e) {
        debugPrint('Error updating user location: $e');
        return false;
      }
    }
    return false;
  }

  void _updateCameraPosition() {
    if (_mapController == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentLocation != null) {
      // Calculer l'orientation du déplacement si possible
      double bearing = 37.5; // Valeur par défaut
      if (_lastUserPosition != null && _lastHeading != null) {
        bearing = _lastHeading!;
      }

      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              appState.currentLocation!.latitude,
              appState.currentLocation!.longitude,
            ),
            zoom: _currentZoom,
            tilt: 60.0, // Angle plus élevé pour effet de courbure terrestre
            bearing:
                bearing, // Orientation selon déplacement ou 37.5° par défaut
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
                    tilt: _cameraPitch, // Angle de confort de lecture à 37.5°
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
        onPressed: () {
          // Recentrer la carte sur la position utilisateur avec orientation optimale
          final appState = Provider.of<AppState>(context, listen: false);
          if (appState.currentLocation != null) {
            double bearing = 37.5; // Valeur par défaut
            if (_lastHeading != null) {
              bearing = _lastHeading!;
            }

            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(
                    appState.currentLocation!.latitude,
                    appState.currentLocation!.longitude,
                  ),
                  zoom: 15.0,
                  tilt: 60.0, // Angle pour effet de courbure terrestre
                  bearing: bearing, // Orientation selon déplacement
                ),
              ),
            );
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
        ),
      ),
    );
  }
}
