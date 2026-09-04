import 'package:shared_preferences/shared_preferences.dart';

/// Persists app-level preferences (e.g. the local server URL).
class SettingsService {
  static const _serverUrlKey = 'server_url';
  static const _daysKey = 'days_to_fetch';
  static const _autoSyncKey = 'auto_sync_enabled';
  static const _hcGrantedKey = 'hc_granted';
  static const _syncFrequencyKey = 'sync_frequency';

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

  /// Cached Health Connect grant flag. The OS permission itself remains the
  /// source of truth (re-verified via hasPermissions), but this lets the app
  /// remember a previous grant so the user is not prompted on every launch.
  Future<bool> get hcGranted async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hcGrantedKey) ?? false;
  }

  Future<void> setHcGranted(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hcGrantedKey, granted);
  }

  /// 'daily' or 'weekly'. Defaults to 'weekly'.
  Future<String> get syncFrequency async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncFrequencyKey) ?? 'weekly';
  }

  Future<void> setSyncFrequency(String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncFrequencyKey, frequency);
  }
}