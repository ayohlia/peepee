import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'assets/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  runApp(ChangeNotifierProvider(
      create: (context) => AppState(), child: const PeePee()));
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
