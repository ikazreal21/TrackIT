import 'package:flutter/material.dart';

import '../models/health_data.dart';
import '../services/api_service.dart';
import '../services/health_connect_service.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import '../widgets/stat_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;

  const HomeScreen({super.key, required this.onToggleDarkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _health = HealthConnectService();
  final _settings = SettingsService();
  final _localStorage = LocalStorageService();

  List<HealthRecord> _records = [];
  bool _loading = false;
  bool _authorized = false;
  String _status = 'Not started';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _loading = true);

    final (supported, status) = await _health.isSupported;
    if (!supported) {
      setState(() {
        _loading = false;
        _status = 'Health Connect not available: $status';
      });
      return;
    }

    final localRecords = await _localStorage.loadRecords();
    final hasPermissions = await _health.hasPermissions();

    setState(() {
      _records = localRecords;
      _authorized = hasPermissions;
      _loading = false;
      _status = hasPermissions
          ? 'Loaded ${localRecords.length} records. Tap "Fetch stats" to update.'
          : 'Health Connect supported ($status). Grant permission to begin.';
    });
  }

  Future<void> _grant() async {
    setState(() => _loading = true);
    final (granted, message) = await _health.requestAuthorization();
    setState(() {
      _loading = false;
      _authorized = granted;
      _status = granted
          ? 'Access granted. Tap "Fetch stats".'
          : 'Access denied or not supported: $message';
    });
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final days = await _settings.daysToFetch;
    final newRecords = await _health.fetchLastNDays(days);

    final merged = [..._records];
    final existingKeys = _records
        .map((r) => '${r.type}|${r.dateFrom.toUtc().toIso8601String()}|${r.dateTo.toUtc().toIso8601String()}')
        .toSet();

    var added = 0;
    for (final r in newRecords) {
      final key = '${r.type}|${r.dateFrom.toUtc().toIso8601String()}|${r.dateTo.toUtc().toIso8601String()}';
      if (!existingKeys.contains(key)) {
        merged.add(r);
        existingKeys.add(key);
        added++;
      }
    }

    await _localStorage.saveRecords(newRecords);

    setState(() {
      _records = merged;
      _loading = false;
      _status = 'Fetched ${newRecords.length} records. $added new data points added for last $days days.';
    });
  }

  Future<void> _upload() async {
    final url = await _settings.serverUrl;
    if (url == null || url.isEmpty) {
      _showSnack('Set the server URL in Settings first.');
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ApiService(baseUrl: url);
      final created = await api.uploadRecords(_records);
      setState(() {
        _loading = false;
        _status = 'Uploaded $created new records to server.';
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Upload failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _summary(String type, {String prefix = '', String unit = '', List<String> altTypes = const []}) {
    final allTypes = [type, ...altTypes];
    final matches = _records.where((r) => allTypes.contains(r.type)).toList();
    if (matches.isEmpty) return '--';
    final total = matches.fold<num>(0, (sum, r) => sum + r.value);
    return '$prefix${total.toStringAsFixed(0)}$unit';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrackIT'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleDarkMode,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: _loading ? null : _grant,
                  child: const Text('1. Grant access'),
                ),
                FilledButton(
                  onPressed: _loading || !_authorized ? null : _fetch,
                  child: const Text('2. Fetch stats'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading || _records.isEmpty ? null : _upload,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('3. Upload to server'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    StatCard(
                      title: 'Steps',
                      icon: Icons.directions_walk,
                      value: _summary('STEPS'),
                    ),
                    StatCard(
                      title: 'Distance (m)',
                      icon: Icons.map,
                      accent: Colors.blue,
                      value: _summary('DISTANCE_DELTA'),
                    ),
                    StatCard(
                      title: 'Calories (kcal)',
                      icon: Icons.local_fire_department,
                      accent: Colors.deepOrange,
                      value: _summary(
                        'ACTIVE_ENERGY_BURNED',
                        altTypes: ['TOTAL_CALORIES_BURNED', 'BASAL_ENERGY_BURNED'],
                      ),
                    ),
                    StatCard(
                      title: 'Sleep (h)',
                      icon: Icons.bedtime,
                      accent: Colors.indigo,
                      value: _summary(
                        'SLEEP_SESSION',
                        unit: ' h',
                        prefix: '',
                        altTypes: ['SLEEP_ASLEEP', 'SLEEP_LIGHT', 'SLEEP_DEEP', 'SLEEP_REM'],
                      ),
                    ),
                    StatCard(
                      title: 'Heart Rate',
                      icon: Icons.favorite,
                      accent: Colors.red,
                      value: _summary('HEART_RATE'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
