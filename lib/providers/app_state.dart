import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../errors/app_exception.dart';
import '../models/toilet_model.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/toilets_service.dart';

class AppState with ChangeNotifier {
  Position? _currentLocation;
  bool _hasInternet = true;
  List<Toilet> _nearbyToilets = [];
  String? _errorMessage;
  StreamSubscription<Position>? _positionStreamSubscription;

  final LocationService _locationService = LocationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ToiletsService _toiletsService = ToiletsService();

  Position? get currentLocation => _currentLocation;
  bool get hasInternet => _hasInternet;
  List<Toilet> get nearbyToilets => _nearbyToilets;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    stopLocationUpdates();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
  }

  void startLocationUpdates() {
    stopLocationUpdates(); // Cancel any existing subscription
    try {
      _positionStreamSubscription = _locationService.getPositionStream().handleError((error) {
        if (kDebugMode) {
          print('Erreur dans le flux de localisation: $error');
        }
        _errorMessage = 'Impossible de suivre la position.';
        notifyListeners();
      }).listen((Position position) {
         if (kDebugMode) {
          print('Nouvelle position: ${position.latitude}, ${position.longitude}');
        }
        _currentLocation = position;
        notifyListeners();
      });
    } catch (e) {
       if (kDebugMode) {
        print('Impossible de démarrer le suivi de la position: $e');
      }
      _errorMessage = 'Impossible de démarrer le suivi de la position.';
      notifyListeners();
    }
  }

  Future<void> updateLocation() async {
    try {
      _clearError();
      _currentLocation = await _locationService.getCurrentLocation();
      if (_currentLocation != null) {
        // Fetch toilets only if the list is empty, to avoid re-fetching on every app start
        if(_nearbyToilets.isEmpty) {
          await updateNearbyToilets();
        }
        startLocationUpdates(); // Start streaming after the first location is fetched
      }
      notifyListeners(); // Notify listeners once after initial setup
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la mise à jour de la localisation: $e');
      }
      _errorMessage = 'Impossible de récupérer la position.';
      notifyListeners();
    }
  }

  Future<void> checkConnectivity() async {
    _hasInternet = await _connectivityService.checkInternetConnectivity();
    notifyListeners();
  }

  Future<void> updateNearbyToilets() async {
    if (_currentLocation != null && _hasInternet) {
      try {
        _clearError();
        _nearbyToilets = await _toiletsService.getNearbyToilets(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
      } on AppException catch (e) {
        _errorMessage = e.message;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors de la récupération des toilettes à proximité: $e');
        }
        _errorMessage = 'Une erreur inconnue est survenue.';
        notifyListeners();
      }
    }
  }
}

