import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.updateLocation();
      //appState.checkConnectivity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text(widget.title,
              style: Theme.of(context).textTheme.displayLarge),
        ),
        body: Consumer<AppState>(builder: (context, appState, child) {
          if (appState.currentLocation == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(appState.currentLocation!.latitude,
                  appState.currentLocation!.longitude),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(
                  markers: appState.nearbyToilets.map((toilet) {
                return Marker(
                    width: 60.0,
                    height: 60.0,
                    point: toilet,
                    child: Image.asset(
                      'assets/images/toiletPin.png',
                      width: 35.0,
                      height: 35.0,
                      fit: BoxFit.fitHeight,
                    ));
              }).toList())
            ],
          );
        }));
  }
}
