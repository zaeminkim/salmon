import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/backend.dart';

// AuthApi: 화면에서 받은 값을 서버로 보내는 역할 (서버와 통신)
class AuthApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: salmonBackendUrl,
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // 회원가입
  Future<void> signup({
    required String email,
    required String password,
    required String passwordConfirm,
    required String nickname,
    required bool termsAgreed,
    required bool privacyAgreed,
  }) async {
    // post 메서드:
    // Map(data)을 JSON으로 바꿔서 서버에 보내고
    // 그 응답을 반환타입(Map<String, dynamic>)으로 받음
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/signup',
      data: {
        // '서버가 요구하는 이름': 실제 데이터
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'nickname': nickname,
        'terms_agreed': termsAgreed,
        'privacy_agreed': privacyAgreed,
      },
    );
  }

  // 로그인
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // response는 HTTP 응답 전체
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );

    // response.data는 HTTP 응답 전체에서 변환된 Map만
    final session = response.data;
    if (session == null ||
        session['access_token'] is! String ||
        session['refresh_token'] is! String) {
      throw const FormatException('로그인 응답에 토큰이 없어요');
    }
    return session;
  }

  // 로그아웃
  Future<void> logout({required String refreshToken}) async {
    await _dio.post<void>(
      '/api/v1/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  void close() {
    _dio.close(force: true);
  }
}

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

// _AuthState: 화면에서 일어나는 일 처리
class _AuthState extends State<Auth> {
  final _api = AuthApi();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _nickname = TextEditingController();

  bool _isSignup = true;
  bool _isLoading = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  String _message = '';
  Map<String, dynamic>? _session;

  Future<void> _submit() async {
    // 입력칸에서 문자열 꺼내기
    final email = _email.text.trim();
    final password = _password.text;
    final passwordConfirm = _passwordConfirm.text;
    final nickname = _nickname.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = '이메일과 비밀번호를 입력해 주세요');
      return;
    }

    if (_isSignup &&
        (nickname.isEmpty ||
            password != passwordConfirm ||
            !_termsAgreed ||
            !_privacyAgreed)) {
      setState(() {
        _message = '닉네임, 비밀번호 확인, 두 동의 항목을 확인해 주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      if (_isSignup) {
        await _api.signup(
          email: email,
          password: password,
          passwordConfirm: passwordConfirm,
          nickname: nickname,
          termsAgreed: _termsAgreed,
          privacyAgreed: _privacyAgreed,
        );

        if (!mounted) return;
        _password.clear();
        _passwordConfirm.clear();

        setState(() {
          _isSignup = false;
          _message = '회원가입이 완료됐어요. 같은 계정으로 로그인해 주세요.';
        });
      } else {
        final session = await _api.login(email: email, password: password);

        if (!mounted) return;
        _password.clear();

        setState(() {
          _session = session;
          _message = '로그인에 성공했어요.';
        });
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final response = error.response;
      final body = response?.data;
      final serverMessage = body is Map ? body['message'] : null;

      setState(() {
        if (serverMessage is String && serverMessage.isNotEmpty) {
          _message = 'HTTP ${response?.statusCode} · $serverMessage';
        } else if (response != null) {
          _message = '요청에 실패했어요. HTTP ${response.statusCode}';
        } else {
          _message = '서버 응답을 받지 못했어요. 연결을 확인해 주세요.';
        }
      });
    } on FormatException {
      if (!mounted) return;
      setState(() => _message = '로그인 응답에서 토큰을 확인할 수 없어요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final refreshToken = _session?['refresh_token'];
    if (_isLoading || refreshToken is! String) return;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await _api.logout(refreshToken: refreshToken);
      if (!mounted) return;

      setState(() {
        _session = null;
        _isSignup = false;
        _message = '로그아웃했어요.';
      });
    } on DioException catch (error) {
      if (!mounted) return;

      final statusCode = error.response?.statusCode;
      final body = error.response?.data;
      final serverError = body is Map ? body['error'] : null;
      final serverMessage = serverError is Map ? serverError['message'] : null;

      setState(() {
        if (statusCode == 401) {
          _session = null;
          _isSignup = false;
          _message = '세션이 만료되었거나 유효하지 않아요. 다시 로그인해 주세요.';
        } else if (serverMessage is String && serverMessage.isNotEmpty) {
          _message = '로그아웃 실패 · $serverMessage';
        } else {
          _message = '로그아웃을 완료하지 못했어요. 다시 시도해 주세요.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _api.close();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignup ? '회원가입' : '로그인';
    final user = _session?['user'];
    final nickname = user is Map ? user['nickname'] : null;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_session == null) ...[
            TextField(
              controller: _email,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            TextField(
              controller: _password,
              enabled: !_isLoading,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            if (_isSignup) ...[
              TextField(
                controller: _passwordConfirm,
                enabled: !_isLoading,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
              ),
              TextField(
                controller: _nickname,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: '닉네임'),
              ),
              CheckboxListTile(
                title: const Text('이용약관에 동의합니다'),
                value: _termsAgreed,
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _termsAgreed = value == true),
              ),
              CheckboxListTile(
                title: const Text('개인정보 처리에 동의합니다'),
                value: _privacyAgreed,
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _privacyAgreed = value == true),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: Text(_isLoading ? '요청 중…' : title),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _password.clear();
                      _passwordConfirm.clear();
                      setState(() {
                        _isSignup = !_isSignup;
                        _message = '';
                      });
                    },
              child: Text(_isSignup ? '로그인 화면으로' : '회원가입 화면으로'),
            ),
          ],
          if (nickname is String) Text('$nickname님, 환영해요.'),
          if (_session != null)
            OutlinedButton(
              onPressed: _isLoading ? null : _logout,
              child: Text(_isLoading ? '로그아웃 중…' : '로그아웃'),
            ),
          if (_message.isNotEmpty) Text(_message),
        ],
      ),
    );
  }
}
