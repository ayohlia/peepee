import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:peepee/views/map_view.dart';
import 'assets/app_colors.dart';
import 'assets/app_theme.dart';
import 'providers/app_state.dart';
import 'service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.statusBarCyan,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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
      home: const MapView(title: 'PeePee'),
    );
  }
}
