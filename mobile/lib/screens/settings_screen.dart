import 'package:flutter/material.dart';

import '../services/background_sync_service.dart';
import '../services/health_connect_service.dart';
import '../services/settings_service.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _health = HealthConnectService();
  late final TextEditingController _urlController;
  int _days = 7;
  bool _autoSync = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final url = await _settings.serverUrl;
    final days = await _settings.daysToFetch;
    final autoSync = await _settings.autoSyncEnabled;
    if (mounted) {
      setState(() {
        _urlController.text = url ?? '';
        _days = days;
        _autoSync = autoSync;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _toggleAutoSync(bool enabled) async {
    setState(() => _loading = true);

    if (enabled) {
      final (authorized, _) = await _health.requestAuthorization();
      if (!authorized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Health Connect permission required')),
          );
        }
        setState(() => _loading = false);
        return;
      }
      await BackgroundSyncService.scheduleWeekly();
    } else {
      await BackgroundSyncService.cancelAll();
    }

    await _settings.setAutoSyncEnabled(enabled);
    if (mounted) {
      setState(() {
        _autoSync = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final raw = _urlController.text.trim();
    final url = raw.isEmpty ? raw : raw.replaceAll(RegExp(r'/+$'), '');
    await _settings.setServerUrl(url);
    await _settings.setDaysToFetch(_days);

    if (_autoSync) {
      await BackgroundSyncService.scheduleWeekly();
    }

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Local server URL (http://IP:8000)',
              helperText: 'e.g. http://192.168.1.50:8000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Days of history to fetch & upload'),
          Slider(
            value: _days.toDouble(),
            min: 1,
            max: 365,
            divisions: 364,
            label: '$_days days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          Text('$_days days', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Auto-sync weekly'),
            subtitle: const Text('Automatically upload health data once a week'),
            value: _autoSync,
            onChanged: _loading ? null : _toggleAutoSync,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
            icon: const Icon(Icons.info_outline),
            label: const Text('About TrackIT'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
