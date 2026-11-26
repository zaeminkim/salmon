import 'package:flutter/material.dart';

import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:salmon/tests/kakaomap_sdk.dart';

// kakao_map_sdk
// UI를 빌드하기 전에 카카오맵 SDK를 준비하는 과정이 필요하기 때문
Future<void> main() async {
  // 1. 화면 시작 전에 SDK를 호출할 준비 - Flutter 바인딩을 준비함
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 빌드 과정에서 카카오 앱 키 읽기
  const appKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  // 3. 키를 전달하지 않았다면 오류 발생
  if (appKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY를 --dart-define으로 전달하세요.');
  }

  // 4. 앱 키로 SDK 객체를 초기화하고 완료를 기다림
  await KakaoMapSdk.instance.initialize(appKey);

  // 5. 앱 화면 시작
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 이 위젯은 애플리케이션의 최상위 위젯입니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // 애플리케이션의 테마입니다.
        //
        // 직접 해보기: "flutter run"으로 애플리케이션을 실행해 보세요.
        // 보라색 툴바가 표시됩니다. 앱을 종료하지 않은 상태에서
        // 아래 colorScheme의 seedColor를 Colors.green으로 바꾸고
        // "핫 리로드"를 실행해 보세요.
        // Flutter를 지원하는 IDE에서는 변경 사항을 저장하거나
        // "핫 리로드" 버튼을 누르면 됩니다.
        // 명령줄에서 앱을 실행했다면 "r"을 누르세요.
        //
        // 카운터가 0으로 초기화되지 않는다는 점을 확인하세요.
        // 핫 리로드를 해도 애플리케이션의 상태는 유지됩니다.
        // 상태를 초기화하려면 핫 리스타트를 사용하세요.
        //
        // 값뿐만 아니라 코드에도 적용됩니다.
        // 대부분의 코드 변경은 핫 리로드만으로 확인할 수 있습니다.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),

      builder: (context, child) {
        return Material(type: MaterialType.transparency, child: child!);
      },
      home: const KakaomapSdk(),
    );
  }
}
