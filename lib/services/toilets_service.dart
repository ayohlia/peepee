import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../models/toilet_model.dart';

class ToiletsService {
  final Dio _dio;
  static const String _overpassApiUrl = 'https://overpass-api.de/api/interpreter';

  ToiletsService({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<Toilet>> getNearbyToilets(double lat, double lon) async {
    try {
      final response = await _dio.get(
          '$_overpassApiUrl?data=[out:json];node[amenity=toilets](around:50000,$lat,$lon);out;');
      
      if (response.data == null || response.data['elements'] is! List) {
        return [];
      }

      final List<dynamic> elements = response.data['elements'];
      
      final List<Toilet> toilets = elements
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
        // ignore: avoid_print
        print('Failed to fetch toilets: $e');
      }
      throw AppException('Une erreur inconnue est survenue.');
    }
  }
}

