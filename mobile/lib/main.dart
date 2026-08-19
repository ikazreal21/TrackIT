import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundSyncService.initialize();
  runApp(const TrackITApp());
}

class TrackITApp extends StatefulWidget {
  const TrackITApp({super.key});

  @override
  State<TrackITApp> createState() => _TrackITAppState();
}

class _TrackITAppState extends State<TrackITApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleDarkMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: HomeScreen(onToggleDarkMode: _toggleDarkMode),
    );
  }
}