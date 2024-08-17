import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'views/home_view.dart';

class PermissionCheck extends StatefulWidget {
  const PermissionCheck({super.key});
  @override
  State<PermissionCheck> createState() => _PermissionCheckState();
}

class _PermissionCheckState extends State<PermissionCheck>
    with WidgetsBindingObserver {
  late AppLifecycleState? _lastLifecycleState;
  late bool _permissionGranted = false;
  final Permission _permission = Permission.location;

  @override
  void initState() {
    _lastLifecycleState = AppLifecycleState.inactive;
    WidgetsBinding.instance.addObserver(this);
    super.initState();
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
    return (_lastLifecycleState == AppLifecycleState.resumed &&
            _permissionGranted)
        ? const HomeView()
        : FutureBuilder<bool>(
            future: _checkPermissions(_permission),
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data ?? false) {
                  return const HomeView();
                } else {
                  return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Stack(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.only(
                                    left: 20, top: 20, right: 20, bottom: 20),
                                decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black,
                                          offset: Offset(2, 5),
                                          blurRadius: 10),
                                    ]),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    RichText(
                                      text: const TextSpan(
                                          text:
                                              "Permissions de géolocalisation requises !",
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black)),
                                      textAlign: TextAlign.left,
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 20),
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5.0),
                                        child: RichText(
                                            text: const TextSpan(
                                                text:
                                                    'L’application utilise votre localisation en arrière-plan, partout où vous allez, afin de recevoir des notifications sur des éventuels bons plans, des notifications par des commerçants qui se trouvent autour de vous dans une zone de quelques dizaines de kilomètres.',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black)),
                                            textAlign: TextAlign.justify,
                                            maxLines: 10)),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Align(
                                            alignment: Alignment.bottomLeft,
                                            child: Container()),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: TextButton(
                                              onPressed: () async {
                                                await GrantPermissionPositionStrategy()
                                                    .request(
                                                        onPermanentlyDenied:
                                                            () async {
                                                  await openAppSettings();
                                                }, onGranted: () {
                                                  Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              const HomeView()));
                                                });
                                              },
                                              child: const FittedBox(
                                                  child: Text("Suivant",
                                                      style: TextStyle(
                                                          fontSize: 18)))),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          )));
                }
              } else {
                return const Text("Chargement");
              }
            });
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
