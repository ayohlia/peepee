import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peepee/views/home_view.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  setupLocator();
  runApp(PeePee());
}

class PeePee extends StatelessWidget {
  PeePee({super.key});
  final String _appTitle = 'Pee-Pee';
  final _colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF35CAC6),
      brightness: Brightness.light,
      primary: const Color(0xFF098EAF),
      secondary: const Color(0xFFA4CBC9));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _appTitle,
      theme: ThemeData(
        colorScheme: _colorScheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
            titleTextStyle: TextStyle(
                fontFamily: 'Urbanist',
                fontSize: 24,
                color: _colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold),
            backgroundColor: _colorScheme.inversePrimary,
            systemOverlayStyle: SystemUiOverlayStyle(
                statusBarIconBrightness:
                    _colorScheme.brightness == Brightness.dark
                        ? Brightness.dark
                        : Brightness.light,
                statusBarColor: _colorScheme.onPrimaryContainer,
                systemNavigationBarColor: _colorScheme.onPrimaryContainer)),
      ),
      home: HomePage(title: _appTitle),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late AppLifecycleState? _lastLifecycleState;
  late bool _permissionGranted = false;
  final Permission _permission = Permission.location;

  @override
  void initState() {
    _lastLifecycleState = AppLifecycleState.inactive;
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lastLifecycleState = state;
  }

  Future<bool> _checkPermissions(Permission permission) async {
    _permissionGranted = await permission.isGranted;
    return _permissionGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(widget.title)),
        body: (_lastLifecycleState == AppLifecycleState.resumed &&
                _permissionGranted)
            ? const HomeView()
            : FutureBuilder<bool>(
                future: _checkPermissions(_permission),
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data ?? false) {
                      return const HomeView();
                    } else {
                      return TextButton(
                          onPressed: () async {
                            await GrantPermissionPositionStrategy().request(
                                onPermanentlyDenied: () async {
                              await openAppSettings();
                            }, onGranted: () {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          HomePage(title: widget.title)));
                            });
                          },
                          child: FittedBox(
                              child: Text("Suivant",
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer))));
                    }
                  } else {
                    return const Text("Chargement");
                  }
                }));
  }
}

class GrantPermissionPositionStrategy extends GrantPermissionStrategy {
  GrantPermissionPositionStrategy() : super(Permission.location);
}

abstract class GrantPermissionStrategy {
  final Permission permission;

  GrantPermissionStrategy(this.permission);

  Future<void> request({
    required final OnPermanentlyDenied onPermanentlyDenied,
    required final OnGranted onGranted,
  }) async {
    PermissionStatus status = await permission.status;

    if (!status.isLimited && !status.isGranted) {
      final PermissionStatus result = await permission.request();
      if (result.isPermanentlyDenied) {
        onPermanentlyDenied.call();
        return;
      }
      if (!result.isGranted) {
        return;
      }
    }
    onGranted.call();
  }
}

typedef OnPermanentlyDenied = void Function();

typedef OnGranted = void Function();
