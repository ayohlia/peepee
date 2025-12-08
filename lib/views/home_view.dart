import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../models/utilisateur_model.dart';
import '../services/geolocator_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, this.title = 'PeePee'});
  final String title;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        title:
            Text(widget.title, style: Theme.of(context).textTheme.displayLarge),
      ),
      body: Provider<GeolocatorService>(
        create: (context) => GeolocatorService(),
        child: const MapView(),
      ),
    );
  }
}

class MapView extends StatefulWidget {
  const MapView({super.key});
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with AutomaticKeepAliveClientMixin<MapView> {
  late GeolocatorService _geolocation;
  final UtilisateurModel _utilisateur = UtilisateurModel();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _geolocation = Provider.of<GeolocatorService>(context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<UtilisateurModel>(
        stream: _geolocation.location,
        builder: (context, AsyncSnapshot<UtilisateurModel> snapshotLocation) {
          return StreamBuilder<bool>(
              stream: _geolocation.permissionAskLocation,
              builder: (context, AsyncSnapshot<bool> snapshotPermission) {
                if (snapshotLocation.hasData && snapshotPermission.hasData) {
                  _utilisateur.latitude = snapshotLocation.data?.latitude;
                  _utilisateur.longitude = snapshotLocation.data?.longitude;
                }

                if (snapshotLocation.connectionState ==
                        ConnectionState.waiting ||
                    snapshotPermission.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshotPermission.data == true) {
                  return const Center(
                      child: Text('Impossible de vous localiser !'));
                }
                return SafeArea(
                    child: MaplibreMap(
                  onMapCreated: (controller) {},
                  styleString: "https://demotiles.maplibre.org/style.json",
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_utilisateur.latitude ?? 50.63,
                        _utilisateur.longitude ?? 3.05),
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationTrackingMode: MyLocationTrackingMode.tracking,
                ));
              });
        });
  }
}
