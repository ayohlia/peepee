import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/toilet_model.dart';

class MarkerManagerService {
  final MapLibreMapController _mapController;
  final Map<String, Symbol> _symbols = {};
  String? _selectedToiletId;
  static const String _toiletSourceId = 'toilet-source';

  MarkerManagerService(this._mapController);

  set selectedToiletId(String? id) {
    if (_selectedToiletId != id) {
      _selectedToiletId = id;
    }
  }

  Future<void> initializeToiletSource() async {
    try {
      await _mapController.addSource(
        _toiletSourceId,
        const GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []},
        ),
      );
      debugPrint('Source toilettes initialisée');
    } catch (e) {
      debugPrint('Erreur initialisation source toilettes: $e');
    }
  }

  Future<void> initializeToiletLayer() async {
    try {
      // Utiliser une seule couche pour éviter les conflits
      await _mapController.addLayer(
        _toiletSourceId,
        'toilet-layer',
        const SymbolLayerProperties(
          iconImage: 'toilet-pin',
          iconSize: 0.5,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'bottom',
        ),
      );

      debugPrint('Couche toilettes initialisée avec succès');
    } catch (e) {
      debugPrint('Erreur initialisation couche toilettes: $e');
    }
  }

  Future<void> updateMarkers({
    required List<Toilet> allToilets,
    required LatLngBounds visibleBounds,
    required double zoomLevel,
  }) async {
    debugPrint(
        'updateMarkers appelé avec ${allToilets.length} toilettes (TOUS SANS FILTRAGE)');

    // Afficher TOUS les pins sans filtrage pour éviter le clustering
    final toiletsToDisplay = allToilets
        .where((toilet) => toilet.latitude != null && toilet.longitude != null)
        .toList();

    debugPrint('Toilettes à afficher: ${toiletsToDisplay.length}');

    if (toiletsToDisplay.isEmpty) {
      debugPrint('Aucune toilette à afficher - retour');
      return;
    }

    // Convertir en GeoJSON pour la source
    final features = toiletsToDisplay
        .map((toilet) => {
              'type': 'Feature',
              'id': toilet.id,
              'geometry': {
                'type': 'Point',
                'coordinates': [toilet.longitude, toilet.latitude]
              },
              'properties': {
                'isSelected': _isToiletSelected(toilet),
              }
            })
        .toList();

    final geojson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    debugPrint('GeoJSON créé avec ${features.length} features');

    try {
      await _mapController.setGeoJsonSource(_toiletSourceId, geojson);
      debugPrint('Source toilettes mise à jour avec succès');
    } catch (e) {
      debugPrint('Erreur mise à jour source toilettes: $e');
    }
  }

  bool _isToiletSelected(Toilet toilet) {
    return _selectedToiletId == toilet.id.toString();
  }

  void dispose() {
    _symbols.clear();
  }
}
