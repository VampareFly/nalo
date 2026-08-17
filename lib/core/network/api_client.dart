// 自有业务 API 的薄请求客户端及通用网络模型。
// 负责统一响应解析、异常映射和脱敏日志，不处理业务 Model、Toast 或导航。

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// 服务端返回非零业务码时的异常。
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => 'ApiException($code, $message)';
}

/// 网络传输异常类别。
enum NetworkExceptionType { timeout, connection, cancelled, unknown }

/// 请求未能正常获得可解析业务响应时的异常。
class NetworkException implements Exception {
  const NetworkException({required this.type, required this.message});

  final NetworkExceptionType type;
  final String message;
}

/// 服务端响应结构不符合约定时的异常。
class ResponseFormatException implements Exception {
  const ResponseFormatException(this.message);

  final String message;
}

/// Access Token 已失效且需要重新登录时的异常。
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'Please log in again']);

  final String message;
}

/// 自有业务 API 的统一响应包。
class ApiResponse<T> {
  const ApiResponse({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final T? data;

  /// 校验统一外层结构，并按需解析 data。
  factory ApiResponse.fromJson(
    Map<String, dynamic> json, [
    T Function(Object? data)? decoder,
  ]) {
    final code = json['code'];
    final message = json['msg'];
    if (code is! int || message is! String) {
      throw const ResponseFormatException(
        'The API response is missing a valid code or msg.',
      );
    }
    final rawData = json['data'];
    return ApiResponse<T>(
      code: code,
      message: message,
      data: rawData == null || decoder == null ? null : decoder(rawData),
    );
  }
}

/// 封装自有业务 API 的通用 HTTP 请求。
class ApiClient {
  const ApiClient({
    required Dio dio,
    required Future<void> Function(String message) onSessionExpired,
  }) : _dio = dio,
       _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final Future<void> Function(String message) _onSessionExpired;

  /// 发送 GET 请求并解析统一响应。
  Future<T?> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Object? data)? decoder,
    bool requiresAuth = true,
  }) => _request(
    path,
    method: 'GET',
    queryParameters: queryParameters,
    decoder: decoder,
    requiresAuth: requiresAuth,
  );

  /// 发送 POST 请求并解析统一响应。
  Future<T?> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Object? data)? decoder,
    bool requiresAuth = true,
  }) => _request(
    path,
    method: 'POST',
    data: data,
    queryParameters: queryParameters,
    decoder: decoder,
    requiresAuth: requiresAuth,
  );

  /// 发送 PUT 请求并解析统一响应。
  Future<T?> put<T>(
    String path, {
    Object? data,
    T Function(Object? data)? decoder,
    bool requiresAuth = true,
  }) => _request(
    path,
    method: 'PUT',
    data: data,
    decoder: decoder,
    requiresAuth: requiresAuth,
  );

  /// 发送 DELETE 请求并解析统一响应。
  Future<T?> delete<T>(
    String path, {
    Object? data,
    T Function(Object? data)? decoder,
    bool requiresAuth = true,
  }) => _request(
    path,
    method: 'DELETE',
    data: data,
    decoder: decoder,
    requiresAuth: requiresAuth,
  );

  Future<T?> _request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Object? data)? decoder,
    required bool requiresAuth,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method, extra: {'requiresAuth': requiresAuth}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const ResponseFormatException(
          'The API response is not an object.',
        );
      }
      final envelope = ApiResponse<Object?>.fromJson(body);
      if (envelope.code == 0) {
        final rawData = body['data'];
        if (rawData == null || decoder == null) return null;
        return decoder(rawData);
      }
      if (_sessionExpiredCodes.contains(envelope.code)) {
        await _onSessionExpired(envelope.message);
        throw SessionExpiredException(envelope.message);
      }
      throw ApiException(
        code: envelope.code,
        message: envelope.message,
        data: body['data'],
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  static const _sessionExpiredCodes = {
    1000001,
    1000002,
    1000010,
    1000011,
    1000013,
    1000016,
  };

  NetworkException _mapDioException(DioException error) {
    final type = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => NetworkExceptionType.timeout,
      DioExceptionType.connectionError => NetworkExceptionType.connection,
      DioExceptionType.cancel => NetworkExceptionType.cancelled,
      _ => NetworkExceptionType.unknown,
    };
    return NetworkException(
      type: type,
      message: error.message ?? 'Network request failed.',
    );
  }
}

/// 记录经过敏感字段脱敏的自有 API 请求与响应。
class NetworkLogInterceptor extends Interceptor {
  NetworkLogInterceptor(this._logger);

  final Logger _logger;
  static const _sensitiveKeys = {
    'authorization',
    'password',
    'access_token',
    'refresh_token',
    'code',
    'code_verifier',
    'state',
    'auth_attempt_id',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d(
      '${options.method} ${_safeUri(options)}\n'
      'headers=${_sanitize(options.headers)} data=${_sanitize(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.d(
      '${response.statusCode} ${_safeUri(response.requestOptions)}\n'
      'data=${_sanitize(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    _logger.w(
      '${error.requestOptions.method} ${_safeUri(error.requestOptions)}: '
      '${error.message}',
    );
    handler.next(error);
  }

  Object? _sanitize(Object? value) {
    if (value is Map) {
      return value.map((key, item) {
        final normalizedKey = key.toString().toLowerCase();
        return MapEntry(
          key,
          _sensitiveKeys.contains(normalizedKey) ? '***' : _sanitize(item),
        );
      });
    }
    if (value is Iterable) return value.map(_sanitize).toList(growable: false);
    return value;
  }

  Uri _safeUri(RequestOptions options) {
    final parameters = options.queryParameters.map((key, value) {
      return MapEntry(
        key,
        _sensitiveKeys.contains(key.toLowerCase()) ? '***' : value,
      );
    });
    return options.uri.replace(queryParameters: parameters);
  }
}
