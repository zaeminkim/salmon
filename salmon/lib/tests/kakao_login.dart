import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
// 해당 라이브러리의 기능을 사용할 때 kakao. 를 앞에 붙인다
// 별명을 붙이면 어떤 패키지의 기능인지 명확해지고, 이름 충돌을 피할 수 있다
import 'package:dio/dio.dart';

class KakaoLogin extends StatefulWidget {
  const KakaoLogin({super.key});

  @override
  State<KakaoLogin> createState() => _KakaoLoginState();
}

class _KakaoLoginState extends State<KakaoLogin> {
  kakao.User? _user; // 처음에는 로그인한 유저가 없기 때문에 nullable
  
  // 거슬렁 서버가 발급한 토큰
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _serverUser;

  String _message = '카카오 로그인을 테스트해 보세요.';
  final bool _isLoading = false; // 작업 중인지를 나타내는 상태 추가

  bool _termsAgreed = false; // 최초 가입시 약관 동의
  bool _privacyAgreed = false;

  // Dio 객체 만들기: 서버 통신에 사용
  final _dio = Dio(
    BaseOptions(
      baseUrl:
          'https://geoseulleong-06469e76bb18.herokuapp.com', // API들이 공유하는 주소
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: Duration(seconds: 30),
      contentType: Headers.jsonContentType, // JSON 타입
    ),
  );

  bool _isCancelled(Object error) {
    return (error is PlatformException &&
            (error.code == 'CANCELED' || error.code == 'CANCELLED')) ||
        (error is kakao.KakaoClientException &&
            error.reason == kakao.ClientErrorCause.cancelled);
  }

  // 1. 카카오 SDK에서 카카오 토큰을 받습니다.
  // 카카오톡 앱/브라우저 로그인 두 분기에서 모두 OAuthToken을 반환하게 함
  // 반환타입: kakao.OAuthToken
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
    // Backend 연결: AuthToken을 수신함
    final kakaoToken = await _authenticateKakao();
    debugPrint('카카오 토큰: ${kakaoToken.accessToken}'); // 확인용 코드

    // POST를 연결하고 응답을 화면 상태로 옮긴다
    if (!mounted) return;
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/kakao',
      data: {
        'access_token': kakaoToken.accessToken,
        'terms_agreed': _termsAgreed,
        'privacy_agreed': _privacyAgreed,
      },
    );

    final data = response.data; // 거슬렁 서버가 발급한 두 토큰
    final accessToken = data?['access_token']; // 1
    final refreshToken = data?['refresh_token']; // 2
    final user = data?['user'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken.isEmpty ||
        refreshToken.isEmpty ||
        user is! Map<String, dynamic>) {
      throw const FormatException('서버 로그인 응답 형식 오류');
    }

    if (!mounted) return;

    setState(() {
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _serverUser = user;
      _message = '서버 로그인 성공: HTTP ${response.statusCode}';
    });

    // if (_isLoading) return;

    // setState(() {
    //   _isLoading = true;
    //   _message = '로그인 중...';
    // });

    // // 실패할 수도 있는 작업을 try-catch문으로 감싼다
    // try {
    //   // // // 1. 카카오톡 설치 여부까지 고려하지 않고, 카카오계정 로그인 브라우저로 이동
    //   // // await kakao.UserApi.instance.loginWithKakaoAccount();

    //   // // 4. 카카오톡 앱이 있으면 앱으로 로그인하는 것까지 고려
    //   // if (await kakao.isKakaoTalkInstalled()) {
    //   //   try {
    //   //     await kakao.UserApi.instance.loginWithKakaoTalk();
    //   //   } catch (error) {
    //   //     if (_isCancelled(error)) rethrow;

    //   //     await kakao.UserApi.instance.loginWithKakaoAccount();
    //   //   }
    //   // } else {
    //   //   await kakao.UserApi.instance.loginWithKakaoAccount();
    //   // }

    //   // 2. 로그인 이후 사용자 정보 조회
    //   final user = await kakao.UserApi.instance.me(); // (1)
    //   debugPrint('회원 ID: ${user.id}');
    //   debugPrint('닉네임: ${user.kakaoAccount?.profile?.nickname}');

    //   // 3. 조회한 사용자 정보를 화면에도 출력
    //   // 필요한 것 두 가지
    //   // (1): 함수 실행이 끝나도 사용자 정보를 보관할 곳
    //   // (2): 정보가 바뀌었을 때 화면을 다시 그릴 방법
    //   if (!mounted) return;

    //   // (2)
    //   setState(() {
    //     _user = user; // 받은 정보를 화면의 상태에 저장하고, Flutter에 다시 그리도록 알림
    //     _message = '로그인 성공';
    //   });
    // } catch (error) {
    //   // 4. 실패했을 때에도 화면이 반응하도록 구현
    //   if (!mounted) return;

    //   setState(() {
    //     _message = '로그인 또는 사용자 정보 조회 실패: $error';
    //   });
    // } finally {
    //   // 성공하든 실패하든, 작업 중 상태는 반드시 끝내야 함
    //   if (mounted) {
    //     setState(() {
    //       _isLoading = false;
    //     });
    //   }
    // }
  }

  // Future<void> _logout() async {
  //   if (_isLoading) return;

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     await kakao.UserApi.instance.logout();

  //     if (!mounted) return;

  //     setState(() {
  //       _user = null;
  //       _message = '로그아웃했습니다.';
  //     });
  //   } catch (error) {
  //     if (!mounted) return;

  //     setState(() {
  //       _message = '로그아웃 실패: $error';
  //     });
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final user = _serverUser;

    return Scaffold(
      appBar: AppBar(title: Text('카카오 로그인 SDK')),
      body: ListView(
        // 3. 조회한 사용자 정보를 화면에도 출력
        children: [
          Text(_message),
          _user == null
              ? ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  // onPressed가 null이면 버튼이 비활성화됨
                  child: Text('카카오 로그인'),
                )
              : Text('회원 ID: ${_user!.id}'),
          CheckboxListTile(
            title: Text('이용약관 동의'),
            value: _termsAgreed,
            onChanged: _isLoading
                ? null
                : (checked) => setState(() {
                    _termsAgreed = checked ?? false;
                  }),
          ),
          CheckboxListTile(
            title: Text('개인정보 수집 및 이용 동의'),
            value: _privacyAgreed,
            onChanged: _isLoading
                ? null
                : (checked) => setState(() {
                    _privacyAgreed = checked ?? false;
                  }),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _logout,
            child: Text('카카오 로그아웃'),
          ),
        ],
      ),
    );
  }
}
