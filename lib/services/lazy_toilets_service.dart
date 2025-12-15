import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/toilet_model.dart';
import '../services/toilets_service.dart';

class LazyToiletsService {
  final ToiletsService _toiletsService;
  final Map<String, List<Toilet>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const double _maxRadius = 20000; // 20km maximum
  static const int _maxToiletsPerRequest = 1000;

  Timer? _debounceTimer;

  LazyToiletsService(this._toiletsService);

  /// Récupère les toilettes de manière optimisée avec chargement paresseux
  Future<List<Toilet>> getToiletsOptimized({
    required Position center,
    required double zoomLevel,
    int? maxResults,
  }) async {
    // Calculer le rayon dynamique selon le niveau de zoom
    final dynamicRadius = _calculateDynamicRadius(zoomLevel);
    final maxResultsToUse = maxResults ?? _maxToiletsPerRequest;

    // Générer une clé de cache
    final cacheKey = _generateCacheKey(center, dynamicRadius);

    // Vérifier le cache
    if (_isCacheValid(cacheKey)) {
      if (kDebugMode) {
        print('Using cached toilets for key: $cacheKey');
      }
      return _cache[cacheKey]!;
    }

    // Récupérer depuis l'API
    final toilets = await _fetchToiletsWithRetry(
      center.latitude,
      center.longitude,
      dynamicRadius,
      maxResults: maxResultsToUse,
    );

    // Mettre en cache
    _cache[cacheKey] = toilets;
    _cacheTimestamps[cacheKey] = DateTime.now();

    // Nettoyer le cache expiré
    _cleanExpiredCache();

    return toilets;
  }

  /// Calcule le rayon de recherche dynamique selon le zoom
  double _calculateDynamicRadius(double zoomLevel) {
    // Rayon plus petit pour les niveaux de zoom élevés (plus de détails)
    // Rayon plus grand pour les niveaux de zoom bas (moins de détails)
    if (zoomLevel >= 16) {
      return 2000; // 2km pour zoom très élevé
    } else if (zoomLevel >= 14) {
      return 5000; // 5km pour zoom élevé
    } else if (zoomLevel >= 12) {
      return 10000; // 10km pour zoom moyen
    } else {
      return _maxRadius; // 20km pour zoom bas
    }
  }

  /// Génère une clé de cache unique
  String _generateCacheKey(Position center, double radius) {
    // Arrondir les coordonnées pour une meilleure utilisation du cache
    final latRounded = (center.latitude * 1000).round() / 1000;
    final lngRounded = (center.longitude * 1000).round() / 1000;
    final radiusRounded = (radius / 1000).round(); // en km

    return '${latRounded}_${lngRounded}_${radiusRounded}km';
  }

  /// Vérifie si le cache est valide
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Nettoie le cache expiré
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) >= _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
      print('Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  /// Récupère les toilettes avec système de retry
  Future<List<Toilet>> _fetchToiletsWithRetry(
    double lat,
    double lon,
    double radius, {
    int? maxResults,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final toilets = await _toiletsService.getNearbyToilets(lat, lon);

        // Limiter les résultats si nécessaire
        if (maxResults != null && toilets.length > maxResults) {
          // Trier par distance et prendre les plus proches
          final sortedToilets = _sortByDistance(toilets, lat, lon);
          return sortedToilets.take(maxResults).toList();
        }

        return toilets;
      } catch (e) {
        if (kDebugMode) {
          print('Attempt ${attempt + 1} failed: $e');
        }

        if (attempt == maxRetries - 1) {
          rethrow;
        }

        // Attendre avant de réessayer (exponentiel backoff)
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    throw Exception('Failed to fetch toilets after $maxRetries attempts');
  }

  /// Trie les toilettes par distance d'un point
  List<Toilet> _sortByDistance(
      List<Toilet> toilets, double centerLat, double centerLon) {
    final sorted = List<Toilet>.from(toilets);

    sorted.sort((a, b) {
      final distanceA =
          _calculateDistance(centerLat, centerLon, a.latitude, a.longitude);
      final distanceB =
          _calculateDistance(centerLat, centerLon, b.latitude, b.longitude);
      return distanceA.compareTo(distanceB);
    });

    return sorted;
  }

  /// Calcule la distance entre deux points
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // mètres

    final double lat1Rad = lat1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;
    final double deltaLatRad = (lat2 - lat1) * math.pi / 180;
    final double deltaLonRad = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Précharge les toilettes pour une zone donnée (background loading)
  Future<void> preloadToiletsForArea(Position center, double radius) async {
    final cacheKey = _generateCacheKey(center, radius);

    if (_isCacheValid(cacheKey)) {
      return; // Déjà en cache
    }

    try {
      // Exécuter en arrière-plan sans bloquer
      unawaited(
          _fetchToiletsWithRetry(center.latitude, center.longitude, radius)
              .then((toilets) {
        _cache[cacheKey] = toilets;
        _cacheTimestamps[cacheKey] = DateTime.now();

        if (kDebugMode) {
          print('Preloaded ${toilets.length} toilets for area: $cacheKey');
        }
      }));
    } catch (e) {
      if (kDebugMode) {
        print('Failed to preload toilets: $e');
      }
    }
  }

  /// Vide le cache manuellement
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();

    if (kDebugMode) {
      print('Cache cleared manually');
    }
  }

  /// Obtient des statistiques sur le cache
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cache.length,
      'totalToiletsCached':
          _cache.values.fold<int>(0, (sum, toilets) => sum + toilets.length),
      'oldestEntry': _cacheTimestamps.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newestEntry': _cacheTimestamps.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  void dispose() {
    _debounceTimer?.cancel();
    clearCache();
  }
}

/// Extension pour exécuter des futures sans attendre (unawaited)
void unawaited(Future<void> future) {
  // Ne fait rien, juste pour éviter le warning "unawaited_future"
}
