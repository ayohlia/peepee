import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../models/utilisateur_model.dart';

class GeolocatorService {
  UtilisateurModel? _currentLocation;
  // permission state is emitted via _permissionsController

  final StreamController<UtilisateurModel> _locationController =
      StreamController<UtilisateurModel>.broadcast();
  final StreamController<bool> _permissionsController =
      StreamController<bool>.broadcast();

  GeolocatorService() {
    _init();
  }

  Future<void> _init() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _permissionsController.add(true);
        return;
      }

      const settings = LocationSettings(accuracy: LocationAccuracy.best);
      final pos =
          await Geolocator.getCurrentPosition(locationSettings: settings)
              .timeout(const Duration(seconds: 10));

      _permissionsController.add(false);
      _currentLocation =
          UtilisateurModel(latitude: pos.latitude, longitude: pos.longitude);
      _locationController.add(_currentLocation!);
    } catch (e) {
      _permissionsController.add(true);
    }
  }

  Stream<bool> get permissionAskLocation => _permissionsController.stream;
  Stream<UtilisateurModel> get location => _locationController.stream;

  Future<UtilisateurModel?> getLocation() async {
    try {
      const settings = LocationSettings(accuracy: LocationAccuracy.best);
      final userLocation =
          await Geolocator.getCurrentPosition(locationSettings: settings);
      _currentLocation = UtilisateurModel(
        latitude: userLocation.latitude,
        longitude: userLocation.longitude,
      );
    } catch (_) {
      final userLocation = await Geolocator.getLastKnownPosition();
      if (userLocation != null) {
        _currentLocation = UtilisateurModel(
            latitude: userLocation.latitude, longitude: userLocation.longitude);
      }
    }
    return _currentLocation;
  }

  void dispose() {
    _locationController.close();
    _permissionsController.close();
  }
}
