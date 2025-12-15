import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../errors/app_exception.dart';

class LocationService {
  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .handleError((_) {
      throw AppException('Impossible de suivre la position.');
    });
  }

  Future<Position> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw AppException('Les services de localisation sont désactivés.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw AppException('Les permissions de localisation sont refusées.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw AppException(
            'Les permissions de localisation sont définitivement refusées.');
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      return await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw AppException('La localisation prend trop de temps. Réessayez.');
    } on Exception {
      throw AppException('Impossible de récupérer la position.');
    }
  }
}
