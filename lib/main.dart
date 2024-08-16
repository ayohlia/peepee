import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'locator.dart';
import 'views/home_view.dart';

void main() {
  setupLocator();
  runApp(PeePee());
}

class PeePee extends StatelessWidget {
  PeePee({super.key});
  final String _appTitle = 'Pee-Pee';
  final _colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF5F5DC),
      brightness: Brightness.light,
      primary: const Color(0xFFE1C16E));

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

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(widget.title)),
        body: const HomeView());
  }
}
