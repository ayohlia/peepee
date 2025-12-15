import '../models/toilet_model.dart';
import '../services/toilets_service.dart';

// Fonction top-level pour compute()
Future<List<Toilet>> fetchToiletsInBackground(List<dynamic> params) async {
  final lat = params[0] as double;
  final lon = params[1] as double;
  final toiletsService = params[2] as ToiletsService;
  return await toiletsService.getNearbyToilets(lat, lon);
}
