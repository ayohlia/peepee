import 'package:flutter/material.dart';
import 'package:peepee/screens/map_screen.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'assets/app_theme.dart';
import 'providers/app_state.dart';
import 'service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  setupServiceLocator();
  await WakelockPlus.enable();
  runApp(
    ChangeNotifierProvider(
        create: (context) => AppState(), child: const PeePee()),
  );
}

class PeePee extends StatelessWidget {
  const PeePee({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toilettes Publiques App',
      theme: AppTheme.lightTheme,
      home: const MapScreen(title: 'PeePee'),
    );
  }
}
