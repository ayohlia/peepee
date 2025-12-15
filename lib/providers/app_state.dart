import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:peepee/service_locator.dart';

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
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _gpsCheckTimer;
  bool _isFetchingToilets = false;

  final LocationService _locationService = getIt<LocationService>();
  final ConnectivityService _connectivityService = getIt<ConnectivityService>();
  final ToiletsService _toiletsService = getIt<ToiletsService>();

  Position? get currentLocation => _currentLocation;
  bool get hasInternet => _hasInternet;
  List<Toilet> get nearbyToilets => _nearbyToilets;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    stopLocationUpdates();
    _connectivitySubscription?.cancel();
    _gpsCheckTimer?.cancel();
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
      _positionStreamSubscription =
          _locationService.getPositionStream().handleError((error) {
        if (kDebugMode) {
          print('Erreur dans le flux de localisation: $error');
        }
        _errorMessage = 'Impossible de suivre la position.';
        notifyListeners();
        _startGpsCheckTimer();
      }).listen((Position position) {
        if (kDebugMode) {
          print(
              'Nouvelle position: ${position.latitude}, ${position.longitude}');
        }
        _currentLocation = position;
        _clearError();
        _gpsCheckTimer?.cancel();
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Impossible de démarrer le suivi de la position: $e');
      }
      _errorMessage = 'Impossible de démarrer le suivi de la position.';
      notifyListeners();
      _startGpsCheckTimer();
    }
  }

  void _startGpsCheckTimer() {
    _gpsCheckTimer?.cancel();
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final position = await _locationService.getCurrentLocation();
        _currentLocation = position;
        _clearError();
        _gpsCheckTimer?.cancel();
        startLocationUpdates();
      } catch (e) {
        if (kDebugMode) {
          print('GPS still unavailable: $e');
        }
      }
    });
  }

  void startConnectivityUpdates() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged().listen((hasInternet) {
      if (_hasInternet == hasInternet) return;
      _hasInternet = hasInternet;
      if (!_hasInternet) {
        _errorMessage = 'Pas de connexion Internet.';
        notifyListeners();
        return;
      }

      _clearError();
      updateNearbyToilets();
    });
  }

  Future<void> updateLocation() async {
    try {
      _clearError();
      await checkConnectivity();
      startConnectivityUpdates();
      _currentLocation = await _locationService.getCurrentLocation();
      if (_currentLocation != null) {
        await updateNearbyToilets();
        startLocationUpdates(); // Start streaming after the first location is fetched
      }
      notifyListeners(); // Notify listeners once after initial setup
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
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
    if (_isFetchingToilets) return;
    if (_currentLocation != null && _hasInternet) {
      try {
        _isFetchingToilets = true;
        _clearError();
        _nearbyToilets = await _toiletsService.getNearbyToilets(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
        notifyListeners();
      } on AppException catch (e) {
        _errorMessage = e.message;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors de la récupération des toilettes à proximité: $e');
        }
        _errorMessage = 'Une erreur inconnue est survenue.';
        notifyListeners();
      } finally {
        _isFetchingToilets = false;
      }
    }
  }
}
