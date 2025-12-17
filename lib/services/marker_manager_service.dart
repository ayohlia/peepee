import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/toilet_model.dart';

class MarkerCluster {
  final List<Toilet> toilets;
  final LatLng center;
  final int count;

  MarkerCluster(this.toilets)
      : center = _calculateCenter(toilets),
        count = toilets.length;

  static LatLng _calculateCenter(List<Toilet> toilets) {
    if (toilets.isEmpty) return const LatLng(0, 0);

    double totalLat = 0;
    double totalLng = 0;

    for (final toilet in toilets) {
      totalLat += toilet.latitude;
      totalLng += toilet.longitude;
    }

    return LatLng(totalLat / toilets.length, totalLng / toilets.length);
  }
}

class MarkerManagerService {
  static const double _clusterRadius = 0.002; // ~200m
  static const int _maxMarkersPerBatch = 100;
  static const int _maxMarkersVisible = 500; // Augmenté de 200 à 500

  final MapLibreMapController _mapController;
  final List<Symbol> _visibleSymbols = [];
  final List<Symbol> _clusterSymbols = [];
  final Map<String, dynamic> _symbolData = {}; // Stockage externe des données

  // Optimisation: Table de recherche directe pour les symboles par ID de toilette
  final Map<String, Symbol> _toiletIdToSymbol = {};
  String? _previouslySelectedToiletId;

  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _selectedToiletId;

  MarkerManagerService(this._mapController);

  bool get isLoading => _isLoading;
  int get visibleMarkersCount => _visibleSymbols.length;
  int get clusterCount => _clusterSymbols.length;

  // Getter pour accéder aux données des symboles depuis MapScreen
  Map<String, dynamic> get symbolData => _symbolData;

  // Setter pour mettre à jour la toilette sélectionnée
  set selectedToiletId(String? id) {
    if (_selectedToiletId != id) {
      _selectedToiletId = id;
    }
  }

  // Méthode publique pour mettre à jour le marqueur sélectionné
  Future<void> updateSelectedMarker() async {
    await _updateSelectedMarker();
  }

  Future<void> updateMarkers({
    required List<Toilet> allToilets,
    required LatLngBounds visibleBounds,
    required double zoomLevel,
  }) async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      // Debounce les mises à jour rapides
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
        await _performMarkerUpdate(allToilets, visibleBounds, zoomLevel);
      });
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _performMarkerUpdate(
    List<Toilet> allToilets,
    LatLngBounds visibleBounds,
    double zoomLevel,
  ) async {
    // Filtrer les toilettes visibles
    final visibleToilets = _filterVisibleToilets(allToilets, visibleBounds);

    if (kDebugMode) {
      print('Visible toilets: ${visibleToilets.length} / ${allToilets.length}');
    }

    // Clustering ou affichage individuel selon le zoom
    if (zoomLevel < 14 && visibleToilets.length > _maxMarkersVisible) {
      await _showClusteredMarkers(visibleToilets);
    } else {
      await _showIndividualMarkers(visibleToilets);
    }
  }

  List<Toilet> _filterVisibleToilets(
      List<Toilet> toilets, LatLngBounds bounds) {
    if (kDebugMode) {
      print(
          'Bounds: NE(${bounds.northeast.latitude}, ${bounds.northeast.longitude}) - SW(${bounds.southwest.latitude}, ${bounds.southwest.longitude})');
      print('Total toilets available: ${toilets.length}');
    }

    final visibleToilets = toilets.where((toilet) {
      return bounds.contains(LatLng(toilet.latitude, toilet.longitude));
    }).toList();

    if (kDebugMode) {
      print('Filtered to ${visibleToilets.length} visible toilets.');
    }
    return visibleToilets;
  }

  Future<void> _showClusteredMarkers(List<Toilet> toilets) async {
    await _clearAllMarkers();

    // Vérifier si une toilette est sélectionnée et l'extraire du clustering
    Toilet? selectedToilet;
    if (_selectedToiletId != null) {
      try {
        selectedToilet =
            toilets.firstWhere((t) => t.id.toString() == _selectedToiletId);
      } catch (e) {
        // La toilette sélectionnée n'est pas dans la liste
      }
    }

    // Créer les clusters avec les toilettes non sélectionnées
    final nonSelectedToilets = selectedToilet != null
        ? toilets.where((t) => t.id.toString() != _selectedToiletId).toList()
        : toilets;

    final finalClusters = _createClusters(nonSelectedToilets);

    // Afficher les clusters par lots
    for (int i = 0; i < finalClusters.length; i += _maxMarkersPerBatch) {
      final batch = finalClusters.skip(i).take(_maxMarkersPerBatch).toList();
      await _createClusterSymbols(batch);

      // Petit délai pour ne pas bloquer l'UI
      if (i + _maxMarkersPerBatch < finalClusters.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    // Ajouter le pin sélectionné individuellement s'il existe
    if (selectedToilet != null) {
      await _createIndividualSymbols([selectedToilet]);
    }
  }

  Future<void> _showIndividualMarkers(List<Toilet> toilets) async {
    await _clearAllMarkers();

    // Limiter le nombre de marqueurs individuels
    final limitedToilets = toilets.take(_maxMarkersVisible).toList();

    // Afficher les marqueurs par lots
    for (int i = 0; i < limitedToilets.length; i += _maxMarkersPerBatch) {
      final batch = limitedToilets.skip(i).take(_maxMarkersPerBatch).toList();
      await _createIndividualSymbols(batch);

      // Petit délai pour ne pas bloquer l'UI
      if (i + _maxMarkersPerBatch < limitedToilets.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  List<MarkerCluster> _createClusters(List<Toilet> toilets) {
    final clusters = <MarkerCluster>[];
    final processed = <Toilet>{};

    for (final toilet in toilets) {
      if (processed.contains(toilet)) continue;

      // Trouver les toilettes proches
      final nearbyToilets = toilets.where((other) {
        if (processed.contains(other)) return false;

        final distance = _calculateDistance(
          LatLng(toilet.latitude, toilet.longitude),
          LatLng(other.latitude, other.longitude),
        );

        return distance <= _clusterRadius;
      }).toList();

      // Marquer comme traitées
      processed.addAll(nearbyToilets);

      // Créer un cluster
      clusters.add(MarkerCluster(nearbyToilets));
    }

    return clusters;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // mètres

    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> _createClusterSymbols(List<MarkerCluster> clusters) async {
    for (final cluster in clusters) {
      try {
        final symbol = await _mapController.addSymbol(
          SymbolOptions(
            geometry: cluster.center,
            iconImage: 'cluster-pin',
            iconSize: 0.6,
            iconAnchor: 'center',
            textField: cluster.count.toString(),
            textSize: 12.0,
            textColor: '#FFFFFF',
            textHaloColor: '#000000',
            textHaloWidth: 1.0,
            textAnchor: 'center',
            textOffset: const Offset(0.0, 0.0),
          ),
        );

        // Stocker les données dans notre Map externe
        _symbolData[symbol.id] = {'cluster': cluster};
        _clusterSymbols.add(symbol);
      } catch (e) {
        debugPrint('Error creating cluster symbol: $e');
      }
    }
  }

  Future<void> _createIndividualSymbols(List<Toilet> toilets) async {
    for (final toilet in toilets) {
      try {
        // Vérifier si cette toilette est sélectionnée
        final isSelected = _isToiletSelected(toilet);

        final symbol = await _mapController.addSymbol(
          SymbolOptions(
            geometry: LatLng(toilet.latitude, toilet.longitude),
            iconImage: isSelected ? 'toilet-pin-selected' : 'toilet-pin',
            iconSize:
                isSelected ? 0.6 : 0.5, // Augmenter la taille si sélectionné
            iconAnchor: 'bottom',
          ),
        );

        // Stocker les données dans nos Maps externes
        _symbolData[symbol.id] = {'toilet': toilet};
        _toiletIdToSymbol[toilet.id.toString()] = symbol;
        _visibleSymbols.add(symbol);
      } catch (e) {
        debugPrint('Error creating individual symbol: $e');
      }
    }
  }

  bool _isToiletSelected(Toilet toilet) {
    // Vérifier si cette toilette est sélectionnée
    return _selectedToiletId == toilet.id.toString();
  }

  Future<void> _updateSelectedMarker() async {
    debugPrint('=== _updateSelectedMarker (Optimized) START ===');
    debugPrint(
        'Selected: $_selectedToiletId, Previously Selected: $_previouslySelectedToiletId');

    // Rien à faire si la sélection n'a pas changé
    if (_selectedToiletId == _previouslySelectedToiletId) {
      debugPrint('No change in selection.');
      debugPrint('=== _updateSelectedMarker (Optimized) END ===');
      return;
    }

    // Mettre à jour le symbole précédemment sélectionné à son état normal
    if (_previouslySelectedToiletId != null) {
      final previousSymbol = _toiletIdToSymbol[_previouslySelectedToiletId];
      if (previousSymbol != null) {
        try {
          await _mapController.updateSymbol(
            previousSymbol,
            const SymbolOptions(
                iconImage: 'toilet-pin', iconSize: 0.5, iconAnchor: 'bottom'),
          );
          debugPrint(
              'Updated previous symbol $_previouslySelectedToiletId to normal state.');
        } catch (e) {
          debugPrint('Error updating previous symbol: $e');
        }
      }
    }

    // Mettre à jour le nouveau symbole à son état sélectionné
    if (_selectedToiletId != null) {
      final newSymbol = _toiletIdToSymbol[_selectedToiletId];
      if (newSymbol != null) {
        try {
          await _mapController.updateSymbol(
            newSymbol,
            const SymbolOptions(
                iconImage: 'toilet-pin-selected',
                iconSize: 0.6,
                iconAnchor: 'bottom'),
          );
          debugPrint(
              'Updated new symbol $_selectedToiletId to selected state.');
        } catch (e) {
          debugPrint('Error updating new symbol: $e');
        }
      }
    }

    // Mettre à jour la variable de suivi pour le prochain cycle
    _previouslySelectedToiletId = _selectedToiletId;

    debugPrint('=== _updateSelectedMarker (Optimized) END ===');
  }

  Future<void> _clearAllMarkers() async {
    try {
      // Supprimer les symboles individuels
      for (final symbol in _visibleSymbols) {
        _symbolData.remove(symbol.id);
        await _mapController.removeSymbol(symbol);
      }
      _visibleSymbols.clear();
      _toiletIdToSymbol.clear();

      // Supprimer les symboles de cluster
      for (final symbol in _clusterSymbols) {
        _symbolData.remove(symbol.id);
        await _mapController.removeSymbol(symbol);
      }
      _clusterSymbols.clear();
    } catch (e) {
      debugPrint('Error clearing markers: $e');
    }
  }

  Future<List<Toilet>> getToiletsInCluster(Symbol clusterSymbol) async {
    final data = _symbolData[clusterSymbol.id];
    if (data != null && data['cluster'] != null) {
      final cluster = data['cluster'] as MarkerCluster;
      return cluster.toilets;
    }
    return [];
  }

  Toilet? getToiletFromSymbol(Symbol symbol) {
    final data = _symbolData[symbol.id];
    if (data != null && data['toilet'] != null) {
      return data['toilet'] as Toilet;
    }
    return null;
  }

  bool isClusterSymbol(Symbol symbol) {
    final data = _symbolData[symbol.id];
    return data != null && data['cluster'] != null;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _clearAllMarkers();
  }
}
