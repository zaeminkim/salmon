// 앱을 실행함

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const appKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  if (appKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY를 빌드 설정으로 전달해 주세요.');
  }

  // 카카오맵을 열기 전에 SDK 초기화
  await KakaoMapSdk.instance.initialize(appKey);

  // 유리 효과에 필요한 셰이더를 미리 세팅.
  await LiquidGlassWidgets.initialize();

  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const MyApp(),
    ),
  );
}
