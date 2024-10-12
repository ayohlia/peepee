import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class ToiletsService {
  Future<List<LatLng>> getNearbyToilets(double lat, double lon) async {
    try {
      final response = await Dio().get(
          'https://overpass-api.de/api/interpreter?data=[out:json];node[amenity=toilets](around:50000,$lat,$lon);out;');
      List<dynamic> elements = response.data['elements'];
      List<LatLng> toilets =
          elements.map((e) => LatLng(e['lat'], e['lon'])).toList();
      return toilets;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fetch toilets: $e');
      }
      return [];
    }
  }
}
