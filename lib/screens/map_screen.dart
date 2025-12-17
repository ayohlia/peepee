import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/toilet_model.dart';
import '../providers/app_state.dart';
import '../services/marker_manager_service.dart';

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

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _isUpdatingSources = false;
  bool _sourcesAdded = false;
  int _lastToiletsCount = 0;
  double _currentZoom = 15.0;

  MarkerManagerService? _markerManager;
  Timer? _mapUpdateDebounce;

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
    _markerManager?.dispose();
    _mapUpdateDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onAppStateUpdated() {
    if (_styleLoaded && _sourcesAdded) {
      final appState = Provider.of<AppState>(context, listen: false);

      // Mettre à jour la sélection dans le MarkerManager SANS recréer les marqueurs
      if (_markerManager != null) {
        _markerManager!.selectedToiletId = appState.selectedToiletId;
        // Mettre à jour UNIQUEMENT le marqueur sélectionné
        _markerManager!.updateSelectedMarker();
      }

      // Mettre à jour les sources SEULEMENT si la liste des toilettes a changé
      // Vérifier si la liste a réellement changé avant de recréer les marqueurs
      if (appState.nearbyToilets.length != _lastToiletsCount) {
        _updateSources();
      }
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

      // Mettre à jour les marqueurs SEULEMENT si la liste des toilettes a changé
      // Ne pas recréer les marqueurs si c'est juste une sélection qui change
      if (_markerManager != null && appState.nearbyToilets.isNotEmpty) {
        // Vérifier si la liste des toilettes a changé
        if (appState.nearbyToilets.length != _lastToiletsCount) {
          final bounds = await _mapController!.getVisibleRegion();
          _currentZoom =
              15.0; // Valeur par défaut si getCameraPosition n'existe pas

          await _markerManager!.updateMarkers(
            allToilets: appState.nearbyToilets,
            visibleBounds: bounds,
            zoomLevel: _currentZoom,
          );

          _lastToiletsCount = appState.nearbyToilets.length;
        }
      }
    } finally {
      _isUpdatingSources = false;
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _markerManager = MarkerManagerService(controller);
    _mapController!.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onSymbolTapped(Symbol symbol) {
    debugPrint('Symbol tapped');

    if (_markerManager == null) return;

    final appState = Provider.of<AppState>(context, listen: false);

    // Vérifier si c'est un cluster ou un marqueur individuel
    if (_markerManager!.isClusterSymbol(symbol)) {
      _handleClusterTap(symbol);
    } else {
      final toilet = _markerManager!.getToiletFromSymbol(symbol);
      if (toilet != null) {
        // Sélectionner ou désélectionner la toilette
        if (appState.selectedToiletId == toilet.id.toString()) {
          debugPrint('Deselecting toilet');
          appState.deselectToilet();
        } else {
          debugPrint('Selecting toilet');
          appState.selectToilet(toilet.id.toString());
          _showToiletDetails(toilet);
        }
      }
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
  }

  Future<void> _addImages() async {
    if (_mapController == null) return;

    Future<void> addImageFromAsset(String name, String assetPath) async {
      try {
        final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
        await _mapController!.addImage(name, bytes);
        debugPrint('Successfully loaded image: $name');
      } catch (e) {
        debugPrint('Error loading image $name from $assetPath: $e');
      }
    }

    await addImageFromAsset('toilet-pin', 'assets/images/toiletPin.png');
    await addImageFromAsset('urgent-user-pin', 'assets/images/urgentPin.png');
    await addImageFromAsset(
        'toilet-pin-selected', 'assets/images/toiletPinSelected.png');

    // Ajouter une icône de cluster simple (cercle bleu)
    try {
      final clusterBytes = await _createClusterIcon();
      await _mapController!.addImage('cluster-pin', clusterBytes);
      debugPrint('Successfully created and loaded image: cluster-pin');
    } catch (e) {
      debugPrint('Error creating cluster icon: $e');
    }
  }

  Future<Uint8List> _createClusterIcon() async {
    // Créer une icône de cluster simple
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Dessiner un cercle
    canvas.drawCircle(const Offset(25, 25), 20, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(50, 50);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _handleClusterTap(Symbol clusterSymbol) async {
    if (_markerManager == null) return;

    final toilets = await _markerManager!.getToiletsInCluster(clusterSymbol);
    if (toilets.isEmpty) return;

    // Zoom sur le cluster (utiliser le centre du cluster)
    final clusterData = _markerManager!.symbolData[clusterSymbol.id];
    if (clusterData != null && clusterData['cluster'] != null) {
      final cluster = clusterData['cluster'] as MarkerCluster;
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: cluster.center,
            zoom: _currentZoom + 2, // Zoomer de 2 niveaux
          ),
        ),
      );
    }

    // Afficher les toilettes du cluster dans une modal
    _showClusterToiletsModal(toilets);
  }

// ... (le reste du code du fichier reste identique)

  void _showClusterToiletsModal(List<Toilet> toilets) {
    final appState = Provider.of<AppState>(context, listen: false);
    final userLocation = appState.currentLocation;

    // Trier les toilettes par distance si la localisation de l'utilisateur est disponible
    if (userLocation != null) {
      toilets.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          a.latitude,
          a.longitude,
        );
        final distanceB = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${toilets.length} toilettes dans cette zone',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: toilets.length,
                      itemBuilder: (context, index) {
                        final toilet = toilets[index];
                        String subtitle = toilet.openingHours ?? '';

                        if (userLocation != null) {
                          final distance = Geolocator.distanceBetween(
                            userLocation.latitude,
                            userLocation.longitude,
                            toilet.latitude,
                            toilet.longitude,
                          );
                          final distanceString = distance < 1000
                              ? '${distance.toStringAsFixed(0)} m'
                              : '${(distance / 1000).toStringAsFixed(1)} km';

                          if (subtitle.isNotEmpty) {
                            subtitle += ' • $distanceString';
                          } else {
                            subtitle = distanceString;
                          }
                        }

                        return ListTile(
                          title: Text(toilet.name ?? 'Toilettes publiques'),
                          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                          trailing: const Icon(Icons.navigation),
                          onTap: () {
                            Navigator.pop(context);
                            appState.selectToilet(toilet.id.toString());
                            _showToiletDetails(toilet);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
