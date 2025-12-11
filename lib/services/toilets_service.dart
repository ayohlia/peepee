import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../models/toilet_model.dart';

class ToiletsService {
  Future<List<Toilet>> getNearbyToilets(double lat, double lon) async {
    try {
      final response = await Dio().get(
          'https://overpass-api.de/api/interpreter?data=[out:json];node[amenity=toilets](around:50000,$lat,$lon);out;');
      
      if (response.data == null || response.data['elements'] is! List) {
        return [];
      }

      List<dynamic> elements = response.data['elements'];
      
      List<Toilet> toilets = elements
          .map((e) => Toilet.fromOverpassJson(e))
          .toList();
          
      return toilets;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw AppException(
            'Vous avez atteint la limite de requêtes. Veuillez réessayer plus tard.');
      }
      throw AppException(
          'Erreur de réseau. Veuillez vérifier votre connexion.');
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fetch toilets: $e');
      }
      throw AppException('Une erreur inconnue est survenue.');
    }
  }
}

