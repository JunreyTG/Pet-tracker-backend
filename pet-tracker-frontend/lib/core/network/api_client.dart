import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

typedef AuthTokenProvider = FutureOr<String?> Function();
typedef UnauthorizedHandler = FutureOr<void> Function();

class ApiClient {
  final ApiConfig config;
  final AuthTokenProvider? authTokenProvider;
  final AuthTokenProvider? refreshAuthTokenProvider;
  final UnauthorizedHandler? onUnauthorized;
  final http.Client _httpClient;

  ApiClient({
    this.config = const ApiConfig(),
    this.authTokenProvider,
    this.refreshAuthTokenProvider,
    this.onUnauthorized,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _send(
      (headers) async => _httpClient.get(_uri(path), headers: headers),
    );
    return _decodeObject(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _send(
      (headers) async => _httpClient.get(_uri(path), headers: headers),
    );
    final decoded = _decode(response);
    if (decoded is List<dynamic>) return decoded;
    throw const ApiException('Expected a JSON array response.');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      (headers) async => _httpClient.post(
        _uri(path),
        headers: headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      (headers) async => _httpClient.patch(
        _uri(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    return _decodeObject(response);
  }

  Future<void> delete(String path) async {
    await _send(
      (headers) async => _httpClient.delete(_uri(path), headers: headers),
    );
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _send(
      (headers) async => _httpClient.delete(_uri(path), headers: headers),
    );
    return _decodeObject(response);
  }

  Uri _uri(String path) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

  Future<Map<String, String>> _headers({bool refreshToken = false}) async {
    final headers = {'Content-Type': 'application/json'};
    final token = refreshToken
        ? await refreshAuthTokenProvider?.call()
        : await authTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      var response = await request(
        await _headers(),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 && refreshAuthTokenProvider != null) {
        response = await request(
          await _headers(refreshToken: true),
        ).timeout(const Duration(seconds: 15));
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      if (response.statusCode == 401) {
        await onUnauthorized?.call();
      }
      throw ApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException('Backend request timed out.', cause: error);
    } on http.ClientException catch (error) {
      throw ApiException('Could not reach the backend API.', cause: error);
    } on FormatException catch (error) {
      throw ApiException('Backend returned invalid JSON.', cause: error);
    }
  }

  Object? _decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException('Expected a JSON object response.');
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
    } on FormatException {
      // Fall through to generic status message.
    }
    return 'Backend request failed.';
  }
}
