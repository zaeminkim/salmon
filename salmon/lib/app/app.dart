// 앱 설정과 첫 화면을 정함

import 'package:flutter/material.dart';
import 'package:salmon/ui/auth/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 이 위젯은 애플리케이션의 최상위 위젯입니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '거슬렁',
      theme: ThemeData(),

      builder: (context, child) {
        return Material(type: MaterialType.transparency, child: child!);
      },
      home: LoginScreen(),
    );
  }
}
