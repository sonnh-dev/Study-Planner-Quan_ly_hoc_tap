import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? token;
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );
  Uri _uri(String path) => Uri.parse('$_baseUrl$path');
  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, Map<String, Object?> body) =>
      _request('POST', path, body);
  Future<Map<String, dynamic>> put(String path, Map<String, Object?> body) =>
      _request('PUT', path, body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Request-Id': DateTime.now().microsecondsSinceEpoch.toString(),
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = _uri(path);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      'PUT' => await _client.put(uri, headers: headers, body: jsonEncode(body)),
      _ => throw UnsupportedError('Unsupported method: $method'),
    };
    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } on FormatException {
        // Some authorization failures are returned by the web server, not as JSON.
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(
        decoded['errorMessage'] as String? ?? 'Không thể kết nối máy chủ.',
        response.statusCode,
      );
    }
    return decoded;
  }
}

class ApiFailure implements Exception {
  const ApiFailure(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}
