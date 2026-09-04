import 'package:flutter/material.dart';

import 'screens/shell.dart';
import 'services/background_sync_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background sync is only available on Android/iOS. Guard it so the app
  // can still run elsewhere (e.g. web preview) without crashing on startup.
  try {
    await BackgroundSyncService.initialize();
  } catch (_) {
    // Unsupported platform — background sync stays disabled.
  }
  runApp(const TrackITApp());
}

class TrackITApp extends StatefulWidget {
  const TrackITApp({super.key});

  @override
  State<TrackITApp> createState() => _TrackITAppState();
}

class _TrackITAppState extends State<TrackITApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleDarkMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: MainScreen(
        onToggleDarkMode: _toggleDarkMode,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
