import 'dart:convert';
import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../core/config/env.dart';
import '../models/theme_config.dart';

/// Fetches the remote brand theme (`app_theme_json.php`) and exposes it as
/// a [ThemeConfig].
///
/// Resolution order at startup:
///   1. Network fetch — newest theme, also written to the Hive cache.
///   2. Hive cache    — last good theme, used when the network fails.
///   3. Baked-in defaults ([ThemeService.defaults]) — guarantees the app
///      always has a complete, valid theme to render.
///
/// The call is best-effort and never throws: a failure simply yields the
/// cached or default theme so startup is never blocked by theming.
abstract class ThemeService {
  Future<ThemeConfig> load();
}

class ThemeServiceImpl implements ThemeService {
  static const _boxName = 'app_theme';
  static const _cacheKey = 'theme_json';
  static const _path = '/app_theme_json.php';

  final Dio _dio;

  ThemeServiceImpl({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Env.baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) debugPrint('[API →] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('[API ←] ${response.statusCode} '
              '${response.requestOptions.method} ${response.requestOptions.uri}');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('[API ✗] ${error.response?.statusCode} '
              '${error.requestOptions.uri} | ${error.message}');
        }
        handler.next(error);
      },
    ));
  }

  /// Baked-in palette + asset URLs. These mirror the current backend
  /// values so the app looks correct even on a cold first launch with no
  /// connectivity.
  static const ThemeConfig defaults = ThemeConfig(
    themeVersion: '0',
    primary: Color(0xFFE25327),
    secondary: Color(0xFF48BEB4),
    accent: Color(0xFFF2BB43),
    background: Color(0xFFFAF4DE),
    text: Color(0xFF56442A),
    logoUrl: null,
    backgroundUrl: null,
    webviewStartUrl: null,
    trackingIntervalSeconds: 5,
  );

  @override
  Future<ThemeConfig> load() async {
    // Try the network first.
    try {
      final res = await _dio.get<dynamic>(_path);
      final data = res.data;
      final map = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : (data as Map).cast<String, dynamic>();

      if (map['status'] == 'success') {
        final config = ThemeConfig.fromJson(map, defaults: defaults);
        await _cache(map);
        return config;
      }
    } catch (e) {
      debugPrint('[theme] network load failed: $e');
    }

    // Fall back to the last cached theme.
    final cached = await _readCache();
    if (cached != null) return cached;

    // Last resort: baked-in defaults.
    return defaults;
  }

  Future<void> _cache(Map<String, dynamic> raw) async {
    try {
      final box = await _box();
      await box.put(_cacheKey, jsonEncode(raw));
    } catch (e) {
      debugPrint('[theme] cache write failed: $e');
    }
  }

  Future<ThemeConfig?> _readCache() async {
    try {
      final box = await _box();
      final raw = box.get(_cacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ThemeConfig.fromJson(map, defaults: defaults);
    } catch (e) {
      debugPrint('[theme] cache read failed: $e');
      return null;
    }
  }

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    return Hive.openBox<String>(_boxName);
  }
}
