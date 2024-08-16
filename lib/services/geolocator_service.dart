import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../models/utilisateur_model.dart';

class GeolocatorService {
  late UtilisateurModel _currentLocation;
  late bool _permissionDenied = false;

  final StreamController<UtilisateurModel> _locationController =
      StreamController<UtilisateurModel>.broadcast();
  final StreamController<bool> _permissionsController =
      StreamController<bool>.broadcast();

  GeolocatorService() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((locationData) {
      _permissionsController.add(false);
      _locationController.add(UtilisateurModel(
          latitude: locationData.latitude, longitude: locationData.longitude));
    }).onError((error, stackTrace) {
      _permissionDenied = true;
      _permissionsController.add(_permissionDenied);
    }).timeout(const Duration(seconds: 10), onTimeout: () {
      _permissionDenied = true;
      _permissionsController.add(_permissionDenied);
    });
  }

  Stream<bool> get permissionAskLocation => _permissionsController.stream;
  Stream<UtilisateurModel> get location => _locationController.stream;

  Future<UtilisateurModel> getLocation() async {
    try {
      final userLocation = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      _currentLocation = UtilisateurModel(
        latitude: userLocation.latitude,
        longitude: userLocation.longitude,
      );
    } on Exception {
      final userLocation = await Geolocator.getLastKnownPosition();
      _currentLocation = UtilisateurModel(
          latitude: userLocation!.latitude, longitude: userLocation.longitude);
      //print('Ne peut pas trouver la position: ${e.toString()}');
    }
    return _currentLocation;
  }
}
