import 'package:flutter/material.dart';

import '../models/health_data.dart';
import '../services/api_service.dart';
import '../services/health_connect_service.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import 'analytics_tab.dart';
import 'home_tab.dart';
import 'records_tab.dart';
import 'settings_screen.dart';
import 'sleep_detail.dart';
import 'strain_detail.dart';

/// Bottom-tab shell owning records, auth and sync. Tabs:
/// Home (scores) / Records / Analytics (ranges) / Account (settings).
class MainScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDark;

  const MainScreen({
    super.key,
    required this.onToggleDarkMode,
    required this.isDark,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  final _health = HealthConnectService();
  final _settings = SettingsService();
  final _localStorage = LocalStorageService();

  List<HealthRecord> _records = [];
  bool _loading = true;
  bool _syncing = false;
  bool _authorized = false;
  bool _supported = false;
  String _supportMsg = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAuth();
  }

  Future<void> _initialize() async {
    final (supported, status) = await _health.isSupported;
    final localRecords = await _localStorage.loadRecords();
    var authorized = false;
    if (supported) {
      authorized = await _health.hasPermissions();
      if (authorized) await _settings.setHcGranted(true);
    }
    if (!mounted) return;
    setState(() {
      _records = localRecords;
      _supported = supported;
      _supportMsg = status;
      _authorized = authorized;
      _loading = false;
    });
  }

  Future<void> _refreshAuth() async {
    if (!_supported) return;
    final has = await _health.hasPermissions();
    if (!mounted) return;
    if (has != _authorized) setState(() => _authorized = has);
    if (has) await _settings.setHcGranted(true);
  }

  Future<void> _grant() async {
    final (granted, _) = await _health.requestAuthorization();
    await _settings.setHcGranted(granted);
    if (!mounted) return;
    setState(() => _authorized = granted);
    _snack(granted
        ? 'Access granted — it stays on, no need to grant again.'
        : 'Access not granted.');
  }

  /// Fetch from Health Connect, save locally, upload if a server is set.
  Future<void> _syncAll() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      var authorized = _authorized;
      if (!authorized && _supported) {
        authorized = await _health.hasPermissions();
        if (!authorized) {
          final (granted, _) = await _health.requestAuthorization();
          authorized = granted;
        }
        if (authorized) await _settings.setHcGranted(true);
      }
      if (!authorized) {
        _snack('Health Connect permission required.');
        return;
      }

      final days = await _settings.daysToFetch;
      final fresh = await _health.fetchLastNDays(days);

      final merged = [..._records];
      final keys = _records
          .map((r) =>
              '${r.type}|${r.dateFrom.toUtc().toIso8601String()}|${r.dateTo.toUtc().toIso8601String()}')
          .toSet();
      var added = 0;
      for (final r in fresh) {
        final key =
            '${r.type}|${r.dateFrom.toUtc().toIso8601String()}|${r.dateTo.toUtc().toIso8601String()}';
        if (keys.add(key)) {
          merged.add(r);
          added++;
        }
      }
      await _localStorage.saveRecords(fresh);

      var msg = 'Fetched ${fresh.length} records ($added new).';
      final url = await _settings.serverUrl;
      if (url != null && url.isNotEmpty) {
        try {
          final created =
              await ApiService(baseUrl: url).uploadRecords(merged);
          msg += ' Uploaded $created.';
        } catch (e) {
          msg += ' Upload failed: $e';
        }
      } else {
        msg += ' Set a server URL in Account to upload.';
      }
      if (!mounted) return;
      setState(() {
        _records = merged;
        _authorized = true;
      });
      _snack(msg);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = [
      HomeTab(
        records: _records,
        supported: _supported,
        supportMsg: _supportMsg,
        authorized: _authorized,
        syncing: _syncing,
        onGrant: _grant,
        onSync: _syncAll,
        onOpenSleep: (evening) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SleepDetailScreen(records: _records, evening: evening),
          ),
        ),
        onOpenStrain: (day) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StrainDetailScreen(records: _records, day: day),
          ),
        ),
      ),
      RecordsTab(records: _records, onRefresh: _syncAll),
      AnalyticsTab(records: _records),
      SettingsScreen(
        onToggleDarkMode: widget.onToggleDarkMode,
        isDark: widget.isDark,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: 'Records'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account'),
        ],
      ),
    );
  }
}
