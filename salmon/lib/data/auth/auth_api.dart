import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../backend.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;
}

class AuthApi {
  AuthApi({Dio? dio, FlutterSecureStorage? storage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: salmonBackendUrl,
              contentType: Headers.jsonContentType,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _storage = storage ?? const FlutterSecureStorage();

  static final instance = AuthApi();
  static const _refreshKey = 'geoseulleong.refresh_token';
  final Dio _dio;
  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? get accessToken => _accessToken;
  ({String email, String nickname})? _user;
  ({String email, String nickname})? get user => _user;

  Future<void> signup({
    required String email,
    required String password,
    required String passwordConfirm,
    required String nickname,
    required bool termsAgreed,
    required bool privacyAgreed,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup',
        data: {
          'email': email.trim(),
          'password': password,
          'password_confirm': passwordConfirm,
          'nickname': nickname.trim(),
          'terms_agreed': termsAgreed,
          'privacy_agreed': privacyAgreed,
        },
      );
      if (response.statusCode != 201 || response.data?['user'] is! Map) {
        throw const AuthFailure('회원가입 응답을 확인할 수 없어요.');
      }
    } on DioException catch (error) {
      throw _requestFailure(error, invalid: '이메일, 비밀번호, 닉네임 입력을 확인해 주세요.');
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      await _saveSession(response.data);
    } on DioException catch (error) {
      throw _requestFailure(error, invalid: '이메일 또는 비밀번호를 확인해 주세요.');
    }
  }

  Future<void> loginWithKakao(
    String token, {
    bool consentGranted = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/kakao',
        data: {
          'access_token': token,
          if (consentGranted) 'terms_agreed': true,
          if (consentGranted) 'privacy_agreed': true,
        },
      );
      await _saveSession(response.data);
    } on DioException catch (error) {
      throw _requestFailure(error, invalid: '카카오 인증을 확인할 수 없어요. 다시 시도해 주세요.');
    }
  }

  Future<bool> restore() async {
    final token = await _storage.read(key: _refreshKey);
    if (token == null) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': token},
      );
      await _saveSession(response.data);
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _storage.delete(key: _refreshKey);
        _accessToken = null;
        _user = null;
        return false;
      }
      throw _requestFailure(error, invalid: '로그인 상태를 확인할 수 없어요.');
    }
  }

  Future<String?> logout() async {
    final token = await _storage.read(key: _refreshKey);
    await _storage.delete(key: _refreshKey);
    _accessToken = null;
    _user = null;
    if (token == null) return null;
    try {
      await _dio.post<void>(
        '/api/v1/auth/logout',
        data: {'refresh_token': token},
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      return '기기에서 로그아웃했어요. 서버 세션 종료는 확인하지 못했어요.';
    }
    return null;
  }

  Future<void> _saveSession(Map<String, dynamic>? data) async {
    final access = data?['access_token'];
    final refresh = data?['refresh_token'];
    final user = data?['user'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        user is! Map ||
        user['email'] is! String ||
        user['nickname'] is! String) {
      throw const AuthFailure('로그인 응답을 확인할 수 없어요.');
    }
    await _storage.write(key: _refreshKey, value: refresh);
    _accessToken = access;
    _user = (
      email: user['email'] as String,
      nickname: user['nickname'] as String,
    );
  }

  AuthFailure _requestFailure(DioException error, {required String invalid}) {
    final body = error.response?.data;
    final details = body is Map ? body['error'] : null;
    final code = details is Map ? details['code'] : null;
    return AuthFailure(switch (error.response?.statusCode) {
      400 || 401 || 422 => invalid,
      409 => '이미 사용 중인 이메일 또는 닉네임이에요.',
      429 => '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
      null => '서버에 연결하지 못했어요. 네트워크를 확인해 주세요.',
      _ => '서버에서 요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.',
    }, code: code is String ? code : null);
  }
}
