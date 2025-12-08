import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/toilets_service.dart';

class AppState with ChangeNotifier {
  Position? _currentLocation;
  bool _hasInternet = true;
  List<LatLng> _nearbyToilets = [];

  final LocationService _locationService = LocationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ToiletsService _toiletsService = ToiletsService();

  Position? get currentLocation => _currentLocation;
  bool get hasInternet => _hasInternet;
  List<LatLng> get nearbyToilets => _nearbyToilets;

  Future<void> updateLocation() async {
    try {
      _currentLocation = await _locationService.getCurrentLocation();
      notifyListeners();
      if (_currentLocation != null) {
        await updateNearbyToilets();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la mise à jour de la localisation: $e');
      }
    }
  }

  Future<void> checkConnectivity() async {
    _hasInternet = await _connectivityService.checkInternetConnectivity();
    notifyListeners();
  }

  Future<void> updateNearbyToilets() async {
    if (_currentLocation != null && _hasInternet) {
      try {
        _nearbyToilets = await _toiletsService.getNearbyToilets(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors de la récupération des toilettes à proximité: $e');
        }
      }
    }
  }
}
