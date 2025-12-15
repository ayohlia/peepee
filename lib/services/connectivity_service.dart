import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> checkInternetConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Stream<bool> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged
        .map((result) => !result.contains(ConnectivityResult.none))
        .distinct();
  }
}
