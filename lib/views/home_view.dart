import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/utilisateur_model.dart';
import '../services/geolocator_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    return Provider<GeolocatorService>(
      create: (context) => GeolocatorService(),
      child: const MapView(),
    );
  }
}

class MapView extends StatefulWidget {
  const MapView({super.key});
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late GeolocatorService _geolocation;
  final UtilisateurModel _utilisateur = UtilisateurModel();
  final _mapController = MapController();

  @override
  initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _geolocation = Provider.of<GeolocatorService>(context);
    super.didChangeDependencies();
  }

  // ????????
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: _geolocation.location,
        builder: <UtilisateurModel>(context, snapshotLocation) {
          return StreamBuilder(
              stream: _geolocation.permissionAskLocation,
              builder: <bool>(context, snapshotPermission) {
                if (snapshotLocation.hasData && snapshotPermission.hasData) {
                  _utilisateur.latitude = snapshotLocation.data.latitude;
                  _utilisateur.longitude = snapshotLocation.data.longitude;
                }

                if (snapshotLocation.connectionState ==
                        ConnectionState.waiting &&
                    snapshotPermission.connectionState ==
                        ConnectionState.waiting) {
                  return const Text("Chargement des données.");
                }

                if (snapshotPermission!.data) {
                  return const Text('Impossible de vous localiser !');
                }
                return SafeArea(
                    child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                            _utilisateur.latitude!,
                            _utilisateur
                                .longitude!), // Center the map over London
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // OSMF's Tile Server
                        ),
                      ],
                    )
                  ],
                ));
              });
        });
  }
}
