import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'services/toilets_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Third-party libraries
  getIt.registerLazySingleton<Dio>(() => Dio());

  // Services
  getIt.registerLazySingleton<ToiletsService>(() => ToiletsService(dio: getIt<Dio>()));
  getIt.registerLazySingleton<LocationService>(() => LocationService());
  getIt.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
}
