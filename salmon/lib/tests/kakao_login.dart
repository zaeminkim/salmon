import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    as kakao;

class KakaoLogin extends StatefulWidget {
  const KakaoLogin({super.key});

  @override
  State<KakaoLogin> createState() => _KakaoLoginState();
}

class _KakaoLoginState extends State<KakaoLogin> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://geoseulleong-06469e76bb18.herokuapp.com',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ),
  );

  // 거슬렁 서버가 발급한 토큰입니다.
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _serverUser;

  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _isLoading = false;
  String _message = '서버 연결 테스트를 시작하세요.';

  bool _isCancelled(Object error) {
    return (error is PlatformException &&
            (error.code == 'CANCELED' || error.code == 'CANCELLED')) ||
        (error is kakao.KakaoClientException &&
            error.reason == kakao.ClientErrorCause.cancelled);
  }

  // 모든 버튼 작업의 로딩·실패 처리를 공통으로 담당합니다.
  Future<void> _run(
    String progressMessage,
    Future<void> Function() action,
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _message = progressMessage;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;

      String message;

      if (_isCancelled(error)) {
        message = '카카오 로그인을 취소했습니다.';
      } else if (error is DioException) {
        final status = error.response?.statusCode;
        final data = error.response?.data;
        final serverError = data is Map ? data['error'] : null;
        final code = serverError is Map ? serverError['code'] : null;

        message = status == null
            ? '서버에 연결하지 못했습니다. 네트워크와 서버 상태를 확인하세요.'
            : '서버 요청 실패: HTTP $status / ${code ?? "unknown"}';
      } else {
        message = '처리 실패: ${error.runtimeType}';
      }

      setState(() {
        _message = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 1. 카카오 SDK에서 카카오 토큰을 받습니다.
  Future<kakao.OAuthToken> _authenticateKakao() async {
    if (await kakao.isKakaoTalkInstalled()) {
      try {
        return await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (error) {
        if (_isCancelled(error)) rethrow;
      }
    }

    return await kakao.UserApi.instance.loginWithKakaoAccount();
  }

  // 2. 카카오 토큰을 거슬렁 서버에 보내 로그인합니다.
  Future<void> _login() async {
    await _run('카카오 인증 및 서버 로그인 중...', () async {
      final kakaoToken = await _authenticateKakao();

      // 카카오 인증 후 화면이 닫혔다면 서버 요청을 진행하지 않습니다.
      if (!mounted) return;

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/kakao',
        data: {
          'access_token': kakaoToken.accessToken,
          'terms_agreed': _termsAgreed,
          'privacy_agreed': _privacyAgreed,
        },
      );

      final data = response.data;
      final accessToken = data?['access_token'];
      final refreshToken = data?['refresh_token'];
      final user = data?['user'];

      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty ||
          user is! Map) {
        throw const FormatException('서버 로그인 응답 형식 오류');
      }

      if (!mounted) return;

      setState(() {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _serverUser = Map<String, dynamic>.from(user);
        _message = '서버 로그인 성공: HTTP ${response.statusCode}\n'
            '이제 내 정보 조회 버튼을 눌러 보세요.';
      });
    });
  }

  // 3. 거슬렁 토큰으로 보호된 API를 호출합니다.
  Future<void> _fetchMe() async {
    final token = _accessToken;
    if (token == null) return;

    await _run('거슬렁 내 정보 조회 중...', () async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final user = response.data?['user'];
      if (user is! Map) {
        throw const FormatException('내 정보 응답 형식 오류');
      }

      if (!mounted) return;

      setState(() {
        _serverUser = Map<String, dynamic>.from(user);
        _message = '내 정보 조회 성공: HTTP ${response.statusCode}\n'
            '거슬렁 토큰 인증까지 정상 작동합니다.';
      });
    });
  }

  // 4. 거슬렁 서버 세션을 폐기하고 화면의 로그인 정보를 비웁니다.
  Future<void> _logout() async {
    final token = _refreshToken;
    if (token == null) return;

    await _run('서버 로그아웃 중...', () async {
      await _dio.post<void>(
        '/api/v1/auth/logout',
        data: {'refresh_token': token},
      );

      // 서버 로그아웃 성공 후 카카오 SDK의 로그인도 정리합니다.
      var kakaoLogoutSucceeded = true;
      try {
        await kakao.UserApi.instance.logout();
      } catch (_) {
        kakaoLogoutSucceeded = false;
      }

      if (!mounted) return;

      setState(() {
        _accessToken = null;
        _refreshToken = null;
        _serverUser = null;
        _message = kakaoLogoutSucceeded
            ? '서버·카카오 SDK 로그아웃 완료'
            : '서버 로그아웃 완료. 카카오 SDK 로그아웃은 실패했습니다.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _serverUser;
    final loggedIn = _accessToken != null;

    return Scaffold(
      appBar: AppBar(title: const Text('카카오 → 거슬렁 서버 테스트')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_message),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),

            if (!loggedIn) ...[
              const Text('최초 가입에는 거슬렁 서비스 약관 동의가 필요합니다.'),
              CheckboxListTile(
                title: const Text('거슬렁 이용약관 동의'),
                value: _termsAgreed,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _termsAgreed = value ?? false;
                        });
                      },
              ),
              CheckboxListTile(
                title: const Text('개인정보 수집·이용 동의'),
                value: _privacyAgreed,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _privacyAgreed = value ?? false;
                        });
                      },
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: const Text('카카오 인증 후 서버 로그인'),
              ),
            ],

            if (user != null) ...[
              Text('거슬렁 회원 ID: ${user['id']}'),
              const SizedBox(height: 8),
              Text('닉네임: ${user['nickname']}'),
              const SizedBox(height: 8),
              Text('상태: ${user['status']}'),
              const SizedBox(height: 16),
            ],

            if (loggedIn) ...[
              ElevatedButton(
                onPressed: _isLoading ? null : _fetchMe,
                child: const Text('거슬렁 내 정보 조회'),
              ),
              OutlinedButton(
                onPressed: _isLoading ? null : _logout,
                child: const Text('서버 로그아웃'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}