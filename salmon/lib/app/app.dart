// 앱 설정과 첫 화면을 정함

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/data/auth/auth_api.dart';
import 'package:salmon/ui/auth/login_screen.dart';
import 'package:salmon/ui/my_routes/myroutes_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _restoredSession = AuthApi.instance.restore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '거슬렁',
      theme: ThemeData(),
      builder: (context, child) {
        return Material(type: MaterialType.transparency, child: child!);
      },
      home: FutureBuilder<bool>(
        future: _restoredSession,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: GlassProgressIndicator.circular(
                size: 40,
                strokeWidth: 5.5,
                color: Color(0xFFD9553E),
              )),
            );
          }
          return snapshot.data == true
              ? const MyRoutesScreen()
              : const LoginScreen();
        },
      ),
      routes: {'/my_routes': (_) => const MyRoutesScreen()},
    );
  }
}
