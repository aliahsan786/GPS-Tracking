import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env.dart';
import '../core/errors/domain_error.dart';
import '../core/events/auth_events_bus.dart';
import 'secure_storage_service.dart';

/// HTTP gateway. Owns:
///   - Base URL + timeouts
///   - session_token injection **into the JSON body** (matches the
///     backend's PHP endpoint contract, not a Bearer header)
///   - Envelope unwrap — tolerant of both `{ok, data, error}` and bare
///     `{field: ...}` responses (the mock may not wrap; the real
///     backend likely will)
///   - DioException -> DomainError mapping
///   - 401 broadcast to [AuthEventsBus]
class ApiClient {
  final Dio _dio;
  final SecureStorageService _storage;
  final AuthEventsBus _authEvents;

  ApiClient({
    required SecureStorageService storage,
    required AuthEventsBus authEvents,
    Dio? dio,
  })  : _storage = storage,
        _authEvents = authEvents,
        _dio = dio ?? Dio() {
    _configure();
  }

  void _configure() {
    _dio.options = BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: Env.requestTimeout,
      receiveTimeout: Env.requestTimeout,
      sendTimeout: Env.requestTimeout,
      responseType: ResponseType.json,
      headers: {'Content-Type': 'application/json'},
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        // TEMP DIAGNOSTIC: dump the exact request + response so we can
        // hand the raw payloads to the backend team. Debug builds only.
        if (kDebugMode) {
          final req = error.requestOptions;
          debugPrint('───── API ERROR ─────');
          debugPrint('POST ${req.uri}');
          debugPrint('REQUEST BODY: ${req.data}');
          debugPrint('STATUS: ${error.response?.statusCode}');
          debugPrint('RESPONSE BODY: ${error.response?.data}');
          debugPrint('DIO TYPE: ${error.type} | ${error.message}');
          debugPrint('─────────────────────');
        }
        if (error.response?.statusCode == 401) {
          _authEvents.emit(SessionExpiredEvent());
        }
        handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _call(() => _dio.get(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool skipAuth = false,
  }) {
    return _call(() async {
      final finalBody = await _buildBody(body, skipAuth: skipAuth);
      return _dio.post(path, data: finalBody);
    });
  }

  /// Auth-injection happens here: for non-skipAuth calls, we pull the
  /// stored session_token and merge it into a JSON body map. If no
  /// token is stored yet (first login), we pass the body through
  /// unchanged — the backend will 401 and the interceptor handles it.
  Future<Object?> _buildBody(Object? body, {required bool skipAuth}) async {
    if (skipAuth) return body;
    final token = await _storage.readSessionToken();
    if (token == null || token.isEmpty) return body;

    if (body == null) return {'session_token': token};
    if (body is Map<String, dynamic>) {
      return {...body, 'session_token': token};
    }
    // Non-map payloads (rare) are passed through untouched.
    return body;
  }

  Future<Map<String, dynamic>> _call(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return _unwrap(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on DomainError {
      rethrow;
    } catch (_) {
      throw const UnknownError();
    }
  }

  Map<String, dynamic> _unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const ServerError(message: 'Malformed response');
    }

    // Strict envelope: `{ok: bool, data: {...}, error: {...}}`.
    if (body.containsKey('ok')) {
      if (body['ok'] != true) {
        final err = body['error'] as Map<String, dynamic>?;
        throw ServerError(
          statusCode: response.statusCode,
          code: err?['code'] as String?,
          message: (err?['message'] as String?) ?? 'Server error',
        );
      }
      final inner = body['data'];
      if (inner is Map<String, dynamic>) return inner;
      return const <String, dynamic>{};
    }

    // Lenient: bare JSON object. Used for the current mock endpoints and
    // any backend that decides not to wrap. Repositories must tolerate
    // missing fields.
    return body;
  }

  DomainError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return const NetworkError();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 401) return const SessionExpiredError();
        final body = e.response?.data;
        final err = (body is Map<String, dynamic>)
            ? body['error'] as Map<String, dynamic>?
            : null;
        if (status >= 400 && status < 500) {
          return ValidationError(
            message: (err?['message'] as String?) ?? 'Invalid request',
          );
        }
        return ServerError(
          statusCode: status,
          code: err?['code'] as String?,
          message: (err?['message'] as String?) ?? 'Server error',
        );
      case DioExceptionType.cancel:
        return const UnknownError('Request cancelled');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownError();
    }
  }
}
