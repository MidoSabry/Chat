import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl; // e.g. http://localhost:8080
  ApiClient(this.baseUrl);

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    if (res.statusCode >= 400) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
  final res = await http.post(
    Uri.parse('$baseUrl$path'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(body),
  );

  if (res.statusCode >= 400) {
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  return json.decode(res.body) as Map<String, dynamic>;
}

}
