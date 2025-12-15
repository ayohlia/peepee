import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'services/toilets_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Third-party libraries
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerLazySingleton<Dio>(() {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          responseType: ResponseType.json,
          headers: const {
            'Accept': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        dio.interceptors.add(
          LogInterceptor(
            requestHeader: false,
            requestBody: false,
            responseHeader: false,
            responseBody: false,
            error: true,
          ),
        );
      }

      return dio;
    });
  }

  // Services
  if (!getIt.isRegistered<ToiletsService>()) {
    getIt.registerLazySingleton<ToiletsService>(
        () => ToiletsService(dio: getIt<Dio>()));
  }
  if (!getIt.isRegistered<LocationService>()) {
    getIt.registerLazySingleton<LocationService>(() => LocationService());
  }
  if (!getIt.isRegistered<ConnectivityService>()) {
    getIt.registerLazySingleton<ConnectivityService>(
        () => ConnectivityService());
  }
}
