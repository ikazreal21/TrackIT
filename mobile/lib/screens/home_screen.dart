import 'package:flutter/material.dart';

import '../models/health_data.dart';
import '../services/api_service.dart';
import '../services/health_connect_service.dart';
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

  List<HealthRecord> _records = [];
  bool _loading = false;
  bool _authorized = false;
  String _status = 'Not started';

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await _health.isSupported;
    setState(() {
      _status = supported
          ? 'Health Connect supported. Grant permission to begin.'
          : 'Health Connect is not available on this device.';
    });
  }

  Future<void> _grant() async {
    setState(() => _loading = true);
    final granted = await _health.requestAuthorization();
    setState(() {
      _loading = false;
      _authorized = granted;
      _status = granted
          ? 'Access granted. Tap "Fetch stats".'
          : 'Access denied or not supported.';
    });
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final days = await _settings.daysToFetch;
    final records = await _health.fetchLastNDays(days);
    setState(() {
      _records = records;
      _loading = false;
      _status = 'Fetched ${records.length} data points for last $days days.';
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

  String _summary(String type, {String prefix = '', String unit = ''}) {
    final matches = _records.where((r) => r.type == type).toList();
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
                      value: _summary('DISTANCE_WALKING_RUNNING'),
                    ),
                    StatCard(
                      title: 'Calories (kcal)',
                      icon: Icons.local_fire_department,
                      accent: Colors.deepOrange,
                      value: _summary('ACTIVE_ENERGY_BURNED'),
                    ),
                    StatCard(
                      title: 'Sleep (h)',
                      icon: Icons.bedtime,
                      accent: Colors.indigo,
                      value: _summary('SLEEP_SESSION', unit: ' h', prefix: ''),
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