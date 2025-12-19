import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/toilet_model.dart';

class MarkerManagerService {
  final MapLibreMapController _mapController;
  static const String _toiletSourceId = 'toilet-source';
  bool _isInitialized = false;

  // Propriétés pour la sélection des toilettes
  String? _selectedToiletId;
  Function(String?)? onToiletSelected;

  set selectedToiletId(String? id) {
    if (_selectedToiletId != id) {
      _selectedToiletId = id;
      // Mettre à jour le style du marqueur si nécessaire
    }
  }

  MarkerManagerService(this._mapController);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialiser la source des toilettes
      await _mapController.addSource(
        _toiletSourceId,
        const GeojsonSourceProperties(
          data: {'type': 'FeatureCollection', 'features': []},
        ),
      );

      // Ajouter la couche des toilettes
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

      _isInitialized = true;
      debugPrint('MarkerManagerService initialisé avec succès');
    } catch (e) {
      debugPrint('Erreur initialisation MarkerManagerService: $e');
      rethrow;
    }
  }

  Future<void> updateMarkers({
    required List<Toilet> allToilets,
    required LatLngBounds visibleBounds,
    required double zoomLevel,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Filtrer uniquement les toilettes valides
    final validToilets = allToilets
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (validToilets.isEmpty) {
      await _clearMarkers();
      return;
    }

    // Convertir en GeoJSON
    final features = validToilets.map(_toGeoJsonFeature).toList();

    try {
      await _mapController.setGeoJsonSource(
        _toiletSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
      debugPrint('${features.length} marqueurs de toilettes mis à jour');
    } catch (e) {
      debugPrint('Erreur mise à jour des marqueurs: $e');
    }
  }

  Map<String, dynamic> _toGeoJsonFeature(Toilet toilet) {
    return {
      'type': 'Feature',
      'id': toilet.id,
      'geometry': {
        'type': 'Point',
        'coordinates': [toilet.longitude, toilet.latitude]
      },
      'properties': {
        'name': toilet.name ?? 'Toilettes publiques',
        'wheelchair': toilet.isWheelchairAccessible == true ? 'yes' : 'no',
      }
    };
  }

  Future<void> _clearMarkers() async {
    try {
      await _mapController.setGeoJsonSource(
        _toiletSourceId,
        {'type': 'FeatureCollection', 'features': []},
      );
    } catch (e) {
      debugPrint('Erreur vidage des marqueurs: $e');
    }
  }

  void dispose() {
    // Nettoyage si nécessaire
  }
}
