import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:statusbarmanager/statusbarmanager.dart';

void main() {
  runApp(const PeePeeBar());
}

class PeePeeBar extends StatelessWidget {
  const PeePeeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarManager(
      translucent: false,
      statusBarColor: const Color(0xFF8B5A2B),
      navigationBarColor: const Color(0xFF8B5A2B),
      navigationBarDividerColor: const Color(0xFFF5F5DC),
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
      navigationBarBrightness: Brightness.light,
      child: const PeePee(),
    );
  }
}

class PeePee extends StatelessWidget {
  const PeePee({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pee-Pee',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE1C16E)),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Pee-Pee'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          shadowColor: Theme.of(context).colorScheme.onPrimaryContainer,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title)),
      body: SafeArea(
          child: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter:
                  LatLng(46.813744, 1.693057), // Center the map over London
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                // Display map tiles from any source
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // OSMF's Tile Server
              ),
            ],
          )
        ],
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {},
        tooltip: 'Filter',
        child: const Icon(Icons.filter),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
