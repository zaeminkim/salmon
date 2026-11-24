import 'package:flutter/material.dart';

import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:salmon/tests/kakaomap_sdk.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/tests/liquid_glass_widgets.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:salmon/tests/kakao_login.dart';

import 'package:dio/dio.dart';
import 'package:salmon/tests/auth.dart';

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

// // liquid_glass_widgets
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // 유리 효과에 필요한 셰이더를 미리 준비합니다.
//   await LiquidGlassWidgets.initialize();

//   runApp(
//     LiquidGlassWidgets.wrap(
//       brightnessResolver: Theme.maybeBrightnessOf,
//       child: const MyApp(),
//     ),
//   );
// }

// // kakao_flutter_sdk_user
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   const appKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

//   if (appKey.isEmpty) {
//     throw StateError(
//       'KAKAO_NATIVE_APP_KEY를 --dart-define 또는 '
//       '--dart-define-from-file로 전달하세요.',
//     );
//   }

//   // 카카오 로그인 SDK 초기화
//   await KakaoSdk.init(nativeAppKey: appKey);

//   runApp(const MyApp());
// }

// // dio
// void main() {
//   runApp(const MyApp());
// }

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // 이 위젯은 애플리케이션의 홈 페이지입니다.
  // 상태를 가지는 위젯으로, 화면 표시 방식에 영향을 주는
  // 필드를 가진 State 객체가 아래에 정의되어 있습니다.

  // 이 클래스는 상태에 필요한 설정을 담습니다.
  // 부모 위젯인 App 위젯이 전달한 값(여기서는 title)을 보관하며,
  // State의 build 메서드가 이 값을 사용합니다.
  // Widget을 상속한 클래스의 필드는 항상 "final"로 선언합니다.

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // setState를 호출하면 Flutter 프레임워크에
      // 이 State에 변경 사항이 생겼다고 알립니다.
      // 그러면 아래 build 메서드가 다시 실행되어
      // 변경된 값이 화면에 반영됩니다.
      // setState()를 호출하지 않고 _counter만 변경하면
      // build 메서드가 호출되지 않아 화면에 변화가 나타나지 않습니다.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 이 메서드는 setState가 호출될 때마다 다시 실행됩니다.
    // 예를 들어 위의 _incrementCounter 메서드에서 호출할 때 실행됩니다.
    //
    // Flutter 프레임워크는 build 메서드가 빠르게 재실행되도록
    // 최적화되어 있습니다. 따라서 변경이 필요한 위젯을
    // 개별적으로 수정하는 대신 다시 빌드할 수 있습니다.
    return Scaffold(
      appBar: AppBar(
        // 직접 해보기: 이 색상을 특정 색상(예: Colors.amber)으로 바꾸고
        // 핫 리로드를 실행해 보세요.
        // 다른 색상은 유지되면서 AppBar의 색상만 바뀌는지 확인하세요.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // App.build 메서드에서 생성한 MyHomePage 객체의
        // title 값을 가져와 앱 바의 제목으로 사용합니다.
        title: Text(widget.title),
      ),
      body: Center(
        // Center는 하나의 자식 위젯을 받아
        // 부모 영역의 가운데에 배치하는 레이아웃 위젯입니다.
        child: Column(
          // Column도 레이아웃 위젯입니다.
          // 여러 자식 위젯을 받아 세로로 배치합니다.
          // 기본적으로 가로 크기는 자식들을 감쌀 만큼으로 정하고,
          // 세로 크기는 부모의 높이만큼 커지려고 합니다.
          //
          // Column에는 크기와 자식 배치를 제어하는 다양한 속성이 있습니다.
          // 여기서는 mainAxisAlignment를 사용해 자식들을 세로 가운데에 배치합니다.
          // Column은 자식들을 세로로 배치하므로 주축은 세로 방향이고,
          // 교차축은 가로 방향입니다.
          //
          // 직접 해보기: IDE에서 "Toggle Debug Paint"를 선택하거나
          // 콘솔에서 "p"를 눌러 디버그 페인팅을 실행해 보세요.
          // 각 위젯의 윤곽선을 확인할 수 있습니다.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
