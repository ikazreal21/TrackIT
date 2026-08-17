import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/health_data.dart';

/// Posts health records to the local FastAPI analysis server.
class ApiService {
  ApiService({required this.baseUrl});

  /// e.g. "http://192.168.1.50:8000". Set from the settings screen.
  final String baseUrl;

  Uri _endpoint(String path) => Uri.parse('$baseUrl$path');

  /// Pushes a batch of records. Returns the number accepted by the server.
  Future<int> uploadRecords(List<HealthRecord> records) async {
    final payload = jsonEncode({
      'source': 'stat_tracker_mobile',
      'records': records.map((r) => r.toJson()).toList(),
    });

    final res = await http
        .post(
          _endpoint('/api/records/batch'),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException('Server responded ${res.statusCode}: ${res.body}');
    }

    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['created'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Simple reachability check.
  Future<bool> ping() async {
    try {
      final res = await http.get(_endpoint('/health')).timeout(
            const Duration(seconds: 5),
          );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}