import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._();

  ApiClient._();

  // 10.0.2.2 — хост с точки зрения Android-эмулятора. В браузере такого адреса нет.
  // На телефоне в той же сети сюда подставляют IP компьютера.
  String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  String? token;
  Map<String, dynamic>? currentUser;
  bool isSupportUser = false;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String?>? query]) {
    final clean = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.isNotEmpty) clean[key] = value;
    });
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: clean.isEmpty ? null : clean);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 204) return null;
    final text = utf8.decode(res.bodyBytes);
    try {
      return text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  dynamic _handle(http.Response res) {
    final decoded = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    var message = 'Ошибка ${res.statusCode}';
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail
            .map((item) => item['msg'] ?? item.toString())
            .join('; ');
      }
    }
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path, [Map<String, String?>? query]) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    return _handle(res);
  }

  Future<String> getRawText(String path) async {
    final res = await http.get(_uri(path), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return utf8.decode(res.bodyBytes);
    }
    _handle(res);
    return '';
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers);
    _handle(res);
  }

  Future<void> refreshProfile() async {
    currentUser = await get('/api/v1/users/me') as Map<String, dynamic>;
    try {
      // В профиле нет роли «поддержка»: доступ виден только по этому маршруту.
      await get('/api/v1/support/requests', {'limit': '1'});
      isSupportUser = true;
    } catch (_) {
      // 403 и обрыв сети неотличимы — вкладку в обоих случаях прячем.
      isSupportUser = false;
    }
  }

  void clearSession() {
    token = null;
    currentUser = null;
    isSupportUser = false;
  }
}
