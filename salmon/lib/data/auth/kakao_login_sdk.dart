import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

/// 카카오톡으로 먼저 인증하고, 사용할 수 없으면 카카오계정으로 인증합니다.
Future<kakao.OAuthToken> getKakaoLoginToken() async {
  if (await kakao.isKakaoTalkInstalled()) {
    try {
      return await kakao.UserApi.instance.loginWithKakaoTalk();
    } catch (error) {
      if (isKakaoLoginCancellation(error)) rethrow;
    }
  }
  return kakao.UserApi.instance.loginWithKakaoAccount();
}

bool isKakaoLoginCancellation(Object error) =>
    (error is PlatformException &&
        (error.code == 'CANCELED' || error.code == 'CANCELLED')) ||
    (error is kakao.KakaoClientException &&
        error.reason == kakao.ClientErrorCause.cancelled);
