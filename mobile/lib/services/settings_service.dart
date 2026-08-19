import 'package:shared_preferences/shared_preferences.dart';

/// Persists app-level preferences (e.g. the local server URL).
class SettingsService {
  static const _serverUrlKey = 'server_url';
  static const _daysKey = 'days_to_fetch';
  static const _autoSyncKey = 'auto_sync_enabled';

  Future<String?> get serverUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  Future<int> get daysToFetch async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_daysKey) ?? 7;
  }

  Future<void> setDaysToFetch(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_daysKey, days);
  }

  Future<bool> get autoSyncEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? false;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }
}