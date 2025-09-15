// lib/api/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

class ApiService {
  final http.Client _client;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<dynamic>> getDocumentList() async {
    final response = await _client.get(Uri.parse('$SERVER_URL/api/status'));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load document list');
    }
  }

  Future<String> getDownloadLink(String pin) async {
    final url = '$SERVER_URL/api/download/$pin';
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['downloadLink'] as String;
    } else {
      throw Exception('Failed to get download link');
    }
  }

  Future<Uint8List> downloadFile(String downloadLink) async {
    final response = await _client.get(Uri.parse(downloadLink));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download file');
    }
  }
}
