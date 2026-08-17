import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  late final TextEditingController _urlController;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final url = await _settings.serverUrl;
    final days = await _settings.daysToFetch;
    if (mounted) {
      setState(() {
        _urlController.text = url ?? '';
        _days = days;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _urlController.text.trim();
    final url = raw.isEmpty ? raw : raw.replaceAll(RegExp(r'/+$'), '');
    await _settings.setServerUrl(url);
    await _settings.setDaysToFetch(_days);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            max: 90,
            divisions: 89,
            label: '$_days days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          Text('$_days days', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}