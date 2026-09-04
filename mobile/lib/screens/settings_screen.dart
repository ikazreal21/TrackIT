import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/background_sync_service.dart';
import '../services/health_connect_service.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onToggleDarkMode;
  final bool isDark;

  const SettingsScreen({
    super.key,
    this.onToggleDarkMode,
    this.isDark = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _health = HealthConnectService();
  final _localStorage = LocalStorageService();
  late final TextEditingController _urlController;

  int _days = 7;
  bool _autoSync = false;
  String _frequency = 'weekly';
  int _recordCount = 0;
  bool _loading = false;
  bool _busySync = false;
  bool? _connectionOk;

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
    final frequency = await _settings.syncFrequency;
    final records = await _localStorage.loadRecords();
    if (mounted) {
      setState(() {
        _urlController.text = url ?? '';
        _days = days;
        _autoSync = autoSync;
        _frequency = frequency;
        _recordCount = records.length;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _scheduleSync() async {
    if (_frequency == 'daily') {
      await BackgroundSyncService.scheduleDaily();
    } else {
      await BackgroundSyncService.scheduleWeekly();
    }
  }

  Future<void> _toggleAutoSync(bool enabled) async {
    setState(() => _loading = true);

    if (enabled) {
      final (authorized, _) = await _health.requestAuthorization();
      if (!authorized) {
        if (mounted) {
          _snack('Health Connect permission required');
          setState(() => _loading = false);
        }
        return;
      }
      await _settings.setHcGranted(true);
      await _scheduleSync();
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

  Future<void> _changeFrequency(String frequency) async {
    setState(() => _frequency = frequency);
    await _settings.setSyncFrequency(frequency);
    if (_autoSync) {
      await _scheduleSync();
      _snack('Sync schedule updated to $frequency');
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final raw = _urlController.text.trim();
    final url = raw.isEmpty ? raw : raw.replaceAll(RegExp(r'/+$'), '');
    await _settings.setServerUrl(url);
    await _settings.setDaysToFetch(_days);
    await _settings.setSyncFrequency(_frequency);

    if (_autoSync) {
      await _scheduleSync();
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _connectionOk = null;
      });
      _snack('Settings saved');
    }
  }

  Future<void> _testConnection() async {
    final raw = _urlController.text.trim();
    final url = raw.replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      _snack('Enter a server URL first.');
      return;
    }
    setState(() {
      _loading = true;
      _connectionOk = null;
    });
    final ok = await ApiService(baseUrl: url).ping();
    if (mounted) {
      setState(() {
        _loading = false;
        _connectionOk = ok;
      });
      _snack(ok ? 'Server is reachable.' : 'Could not reach the server.');
    }
  }

  Future<void> _fetchNow() async {
    setState(() => _busySync = true);
    var authorized = await _health.hasPermissions();
    if (!authorized) {
      final (granted, _) = await _health.requestAuthorization();
      authorized = granted;
      if (granted) await _settings.setHcGranted(true);
    }
    if (!authorized) {
      if (mounted) setState(() => _busySync = false);
      _snack('Health Connect permission required');
      return;
    }

    final existing = await _localStorage.loadRecords();
    final existingKeys = existing
        .map((r) =>
            '${r.type}|${r.dateFrom.toUtc().toIso8601String()}|${r.dateTo.toUtc().toIso8601String()}')
        .toSet();

    final fresh = await _health.fetchLastNDays(_days);
    final unseen = fresh.where((r) {
      final key =
          '${r.type}|${r.dateFrom.toUtc().toIso8601String()}|${r.dateTo.toUtc().toIso8601String()}';
      return !existingKeys.contains(key);
    }).toList();
    await _localStorage.saveRecords(fresh);

    if (mounted) {
      setState(() {
        _busySync = false;
        _recordCount = existing.length + unseen.length;
      });
      _snack('Fetched ${fresh.length} records (${unseen.length} new).');
    }
  }

  Future<void> _uploadNow() async {
    final raw = _urlController.text.trim();
    final url = raw.replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      _snack('Enter a server URL first.');
      return;
    }
    setState(() => _busySync = true);
    try {
      final records = await _localStorage.loadRecords();
      if (records.isEmpty) {
        if (mounted) setState(() => _busySync = false);
        _snack('No local records to upload. Fetch first.');
        return;
      }
      final created =
          await ApiService(baseUrl: url).uploadRecords(records);
      await _settings.setServerUrl(url);
      if (mounted) {
        setState(() => _busySync = false);
        _snack('Uploaded $created new records to the server.');
      }
    } catch (e) {
      if (mounted) setState(() => _busySync = false);
      _snack('Upload failed: $e');
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear local data?'),
        content: Text(
            'This deletes all $_recordCount locally stored records. Server data is untouched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _localStorage.clear();
    if (mounted) {
      setState(() => _recordCount = 0);
      _snack('Local records cleared.');
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
          _sectionLabel(theme, 'Server connection'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Local server URL',
                      hintText: 'http://192.168.1.50:8000',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.dns_outlined),
                      suffixIcon: _connectionOk == null
                          ? null
                          : Icon(
                              _connectionOk!
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _connectionOk!
                                  ? Colors.green
                                  : theme.colorScheme.error,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _testConnection,
                      icon: const Icon(Icons.wifi_find, size: 18),
                      label: const Text('Test connection'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _save,
                      icon:
                          const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(theme, 'Health data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Local records'),
                  trailing: Text(
                    '$_recordCount',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Days of history to fetch: $_days',
                          style: theme.textTheme.bodyMedium),
                      Slider(
                        value: _days.toDouble(),
                        min: 1,
                        max: 365,
                        divisions: 364,
                        label: '$_days days',
                        onChanged: (v) =>
                            setState(() => _days = v.round()),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busySync ? null : _fetchNow,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Fetch now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busySync ? null : _uploadNow,
                          icon: const Icon(Icons.cloud_upload_outlined,
                              size: 18),
                          label: const Text('Upload now'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busySync)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  title: const Text('Clear local data'),
                  subtitle:
                      const Text('Server data is untouched'),
                  onTap: _recordCount == 0 ? null : _clearData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(theme, 'Automatic sync'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.sync),
                  title: const Text('Auto-sync'),
                  subtitle:
                      const Text('Upload health data in the background'),
                  value: _autoSync,
                  onChanged: _loading ? null : _toggleAutoSync,
                ),
                if (_autoSync) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(
                              value: 'daily', label: Text('Daily')),
                          ButtonSegment(
                              value: 'weekly', label: Text('Weekly')),
                        ],
                        selected: {_frequency},
                        onSelectionChanged: (s) =>
                            _changeFrequency(s.first),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(theme, 'Appearance'),
          Card(
            child: SwitchListTile(
              secondary: Icon(widget.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: widget.isDark,
              onChanged: widget.onToggleDarkMode == null
                  ? null
                  : (_) => widget.onToggleDarkMode!(),
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(theme, 'About'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About TrackIT'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
