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
    // hasPermissions() is false on partial grants, so a remembered grant
    // keeps the app usable. It is only cleared when a fetch truly fails.
    final cached = await _settings.hcGranted;
    if (!mounted) return;
    final next = has || cached;
    if (next != _authorized) setState(() => _authorized = next);
    if (has && !cached) await _settings.setHcGranted(true);
  }

  Future<void> _grant() async {
    final (granted, _) = await _health.requestAuthorization();
    final has = granted || await _health.hasPermissions();
    await _settings.setHcGranted(has);
    if (!mounted) return;
    setState(() => _authorized = has);
    _snack(has
        ? 'Access granted — it stays on, no need to grant again.'
        : 'Access not granted.');
  }

  /// Ensures Health Connect access, trusting a remembered grant.
  Future<bool> _ensureAccess() async {
    if (_authorized) return true;
    if (!_supported) return false;
    var ok = await _health.hasPermissions();
    if (!ok) {
      final (granted, _) = await _health.requestAuthorization();
      ok = granted || await _health.hasPermissions();
    }
    await _settings.setHcGranted(ok);
    if (mounted && ok != _authorized) setState(() => _authorized = ok);
    return ok;
  }

  /// Fetch from Health Connect and merge into local storage.
  /// Returns (merged, added, fetched) or null when unauthorized.
  Future<(List<HealthRecord>, int, int)?> _fetchRecords() async {
    if (!await _ensureAccess()) {
      _snack('Health Connect permission required.');
      return null;
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
    if (mounted) setState(() => _records = merged);
    return (merged, added, fresh.length);
  }

  /// Upload records to the configured server. Returns created count.
  Future<int?> _uploadRecords(List<HealthRecord> records) async {
    final url = await _settings.serverUrl;
    if (url == null || url.isEmpty) {
      _snack('Set a server URL in Account to upload.');
      return null;
    }
    try {
      return await ApiService(baseUrl: url).uploadRecords(records);
    } catch (e) {
      _snack('Upload failed: $e');
      return null;
    }
  }

  Future<void> _runGuarded(Future<void> Function() fn) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Header Fetch button: fetch only.
  Future<void> _fetchOnly() => _runGuarded(() async {
        final res = await _fetchRecords();
        if (res != null) {
          _snack('Fetched ${res.$3} records (${res.$2} new).');
        }
      });

  /// Header Upload button: upload only.
  Future<void> _uploadOnly() => _runGuarded(() async {
        if (_records.isEmpty) {
          _snack('No local records. Fetch first.');
          return;
        }
        final created = await _uploadRecords(_records);
        if (created != null) _snack('Uploaded $created new records.');
      });

  /// Pull-to-refresh: fetch, then upload when a server is set.
  Future<void> _syncAll() => _runGuarded(() async {
        final res = await _fetchRecords();
        if (res == null) return;
        var msg = 'Fetched ${res.$3} records (${res.$2} new).';
        final created = await _uploadRecords(res.$1);
        if (created != null) msg += ' Uploaded $created.';
        _snack(msg);
      });

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
        onFetch: _fetchOnly,
        onUpload: _uploadOnly,
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
