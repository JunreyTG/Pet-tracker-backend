import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/routes/app_routes.dart';
import '../constants/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  final _client = http.Client();
  final _cache = <String, _CachedResponse>{};
  final _pendingGets = <String, Future<dynamic>>{};
  String? _authToken;
  static const _tokenStorageKey = 'pet_tracker_jwt_token';

  bool get hasAuthToken => _authToken != null && _authToken!.isNotEmpty;
  String? get authToken => _authToken;

  Future<void> initTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenStorageKey);
      if (token != null && token.isNotEmpty) {
        _authToken = token;
      }
    } catch (_) {}
  }

  void setAuthToken(String token) {
    _authToken = token;
    _clearCache();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_tokenStorageKey, token);
    }).catchError((_) {});
  }

  void clearAuthToken() {
    _authToken = null;
    _clearCache();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_tokenStorageKey);
    }).catchError((_) {});
  }

  Future<dynamic> get(String path, {Map<String, String?> query = const {}}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String?> query = const {},
  }) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (hasAuthToken) headers['Authorization'] = 'Bearer $_authToken';
      final uri = AppConfig.apiUri(path, query);
      final cacheDuration = _cacheDuration(method, path);
      final cacheKey = uri.toString();
      if (cacheDuration != null) {
        final cached = _cache[cacheKey];
        if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
          return cached.data;
        }
        final pending = _pendingGets[cacheKey];
        if (pending != null) return pending;
      }

      if (method != 'GET') _clearCache();

      final encoded = body == null ? null : jsonEncode(body);
      final request = _request(
        method,
        uri,
        headers,
        encoded,
        cacheDuration,
        cacheKey,
      );
      if (cacheDuration != null) _pendingGets[cacheKey] = request;
      final responseData = await request;
      return responseData;
    } on http.ClientException {
      throw ApiException(
        'Backend is unreachable or blocked by browser CORS. Check the API URL and backend CORS settings.',
      );
    } on SocketException {
      throw ApiException('No internet connection or backend is unreachable.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on FormatException {
      throw ApiException('Unexpected backend response.');
    }
  }

  Future<dynamic> _request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? encoded,
    Duration? cacheDuration,
    String cacheKey,
  ) async {
    try {
      final response = await _httpRequest(
        method,
        uri,
        headers,
        encoded,
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 401 && hasAuthToken) {
        clearAuthToken();
        Get.offAllNamed(Routes.login);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = response.body.isEmpty
            ? null
            : jsonDecode(response.body);
        if (cacheDuration != null) {
          _cache[cacheKey] = _CachedResponse(
            decoded,
            DateTime.now().add(cacheDuration),
          );
        }
        return decoded;
      }
      throw ApiException(_message(response), statusCode: response.statusCode);
    } finally {
      _pendingGets.remove(cacheKey);
    }
  }

  Future<http.Response> _httpRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        return _client.get(uri, headers: headers);
    }
  }

  Duration? _cacheDuration(String method, String path) {
    if (method != 'GET') return null;
    if (path.startsWith('/devices')) return null;
    if (path.contains('/location-history')) return null;
    if (path.startsWith('/places')) return const Duration(days: 1);
    return const Duration(seconds: 20);
  }

  void _clearCache() {
    _cache.clear();
    _pendingGets.clear();
  }

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is String) return detail;
      if (detail is List) return 'Please check the highlighted fields.';
    } catch (_) {}
    return switch (response.statusCode) {
      404 => 'Resource was not found.',
      409 => 'The request conflicts with existing data.',
      422 => 'Please check your input.',
      503 => 'Service is temporarily unavailable.',
      _ => 'Request failed (${response.statusCode}).',
    };
  }
}

class _CachedResponse {
  _CachedResponse(this.data, this.expiresAt);
  final dynamic data;
  final DateTime expiresAt;
}
