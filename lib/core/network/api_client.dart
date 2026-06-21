import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({required http.Client httpClient, FirebaseAuth? firebaseAuth})
    : _httpClient = httpClient,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final http.Client _httpClient;
  final FirebaseAuth _firebaseAuth;

  Future<Object?> get(String path) async {
    final http.Response response = await _httpClient.get(
      _buildUri(path),
      headers: await _buildHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Object?> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    final http.Response response = await _httpClient.post(
      _buildUri(path),
      headers: await _buildHeaders(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Uri _buildUri(String path) {
    final String baseUrl = dotenv.env['BACKEND_URL']?.trim() ?? '';
    if (baseUrl.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        code: 'missing_backend_url',
        message: 'Backend URL is not configured.',
      );
    }

    final Uri baseUri = Uri.parse(baseUrl);
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return baseUri.resolve(normalizedPath);
  }

  Future<Map<String, String>> _buildHeaders() async {
    final String? token = await _firebaseAuth.currentUser?.getIdToken();
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Object? _handleResponse(http.Response response) {
    final Object? decodedBody = _decodeResponseBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody is Map<String, Object?> || decodedBody is List<Object?>) {
        return decodedBody;
      }
      if (decodedBody == null) {
        return null;
      }
      throw ApiException(
        statusCode: response.statusCode,
        code: 'invalid_response',
        message: 'Backend returned an unexpected response.',
      );
    }

    final ({String code, String message}) error = _parseError(decodedBody);
    throw ApiException(
      statusCode: response.statusCode,
      code: error.code,
      message: error.message,
    );
  }

  Object? _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decodedJson = jsonDecode(body);
      if (decodedJson is Map<String, Object?> || decodedJson is List<Object?>) {
        return decodedJson;
      }
      return decodedJson;
    } on FormatException {
      return body;
    }
  }

  ({String code, String message}) _parseError(Object? decodedBody) {
    if (decodedBody is Map<String, Object?>) {
      final Object? code = decodedBody['code'];
      final Object? message = decodedBody['message'];
      return (
        code: code is String && code.isNotEmpty ? code : 'api_error',
        message: message is String && message.isNotEmpty
            ? message
            : 'Request failed.',
      );
    }

    return (code: 'api_error', message: 'Request failed.');
  }
}
