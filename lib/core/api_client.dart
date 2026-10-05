import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_environment.dart';

typedef Json = Map<String, dynamic>;

class ApiFailure implements Exception {
  const ApiFailure(
    this.code,
    this.message, {
    this.status = 0,
    this.fields = const {},
    this.retryAt,
  });
  final String code, message;
  final int status;
  final Map<String, List<String>> fields;
  final DateTime? retryAt;
  bool get uncertain => status == 0 || status >= 500;
  @override
  String toString() => 'ApiFailure($code, $status)'; // Never include response/user data.
}

class ApiClient {
  ApiClient(
    this.environment, {
    http.Client? transport,
    this.timeout = const Duration(seconds: 20),
    this.onDiagnostic,
  }) : _transport = transport ?? http.Client();
  final ApiEnvironment environment;
  final http.Client _transport;
  final Duration timeout;
  final void Function(String)? onDiagnostic;
  String? token;
  DateTime? _retryAt;
  void Function(ApiFailure)? onSessionFailure;
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    String? idempotencyKey,
    bool authenticated = true,
  }) async {
    final credential = authenticated ? token : null;
    final retryAt = _retryAt;
    if (retryAt != null && DateTime.now().isBefore(retryAt)) {
      throw ApiFailure(
        'rate_limited',
        'Please wait before trying again.',
        status: 429,
        retryAt: retryAt,
      );
    }
    final uri = environment.endpoint(path, query);
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
    if (credential != null) {
      request.headers['Authorization'] = 'Bearer $credential';
    }
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response =
          await (() async => http.Response.fromStream(
            await _transport.send(request),
          ))().timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Request timed out');
            },
          );
      if (onDiagnostic != null &&
          const bool.fromEnvironment('MHP_API_DIAGNOSTICS')) {
        final route = path.replaceAll(RegExp(r'/[0-9]+(?=/|$)'), '/:id');
        // Protocol metadata only: never credentials, payloads or response bodies.
        onDiagnostic!(
          'MHP API $method $route HTTP ${response.statusCode}; bearer=${credential != null ? "attached" : "none"}',
        );
      }
      Json data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body) as Json;
        } catch (_) {
          if (response.statusCode >= 200 && response.statusCode < 300) {
            throw const ApiFailure(
              'invalid_response',
              'The server returned an unexpected response. Check the API deployment.',
              status: 502,
            );
          }
          // Still honor HTTP authentication/throttle semantics for proxy errors.
          data = {};
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      final rawRetry = response.headers['retry-after'];
      DateTime? until;
      if (rawRetry != null) {
        final seconds = int.tryParse(rawRetry);
        if (seconds != null) {
          until = DateTime.now().add(Duration(seconds: seconds));
        } else {
          try {
            until = HttpDate.parse(rawRetry);
          } catch (_) {}
        }
      }
      if (response.statusCode == 429) {
        _retryAt = until ?? DateTime.now().add(const Duration(seconds: 60));
      }
      final fields = <String, List<String>>{};
      if (data['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          if (value is List) {
            fields[key.toString()] = value.map((e) => e.toString()).toList();
          }
        });
      }
      final failure = ApiFailure(
        data['code'] as String? ?? 'http_${response.statusCode}',
        data['message'] as String? ?? 'The request could not be completed.',
        status: response.statusCode,
        fields: fields,
        retryAt: response.statusCode == 429 ? _retryAt : until,
      );
      if (credential != null &&
          credential == token &&
          (failure.status == 401 ||
              [
                'account_suspended',
                'email_verification_required',
                'trial_choice_required',
              ].contains(failure.code))) {
        onSessionFailure?.call(failure);
      }
      throw failure;
    } on HandshakeException {
      throw const ApiFailure(
        'tls_error',
        'Cannot establish a trusted secure connection to MHP. Check your device date and time. If it persists, the server certificate configuration needs checking.',
      );
    } on TimeoutException {
      throw const ApiFailure(
        'timeout',
        'Connection timed out. Your changes are not confirmed.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        'network_error',
        'Cannot connect. Check your connection and try again.',
      );
    } on SocketException {
      throw const ApiFailure(
        'network_error',
        'Cannot connect. Check your connection and try again.',
      );
    }
  }

  void close() => _transport.close();
}
