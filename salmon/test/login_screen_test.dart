import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/data/auth/auth_api.dart';
import 'package:salmon/ui/auth/login_screen.dart';

void main() {
  testWidgets(
    'Submits signup and opens the map only after a successful login',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FlutterSecureStorage.setMockInitialValues({});
      final requests = <RequestOptions>[];
      var rejectLogin = true;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              if (request.path.endsWith('/signup')) {
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 201,
                    data: <String, dynamic>{
                      'user': {'email': 'user@example.com'},
                    },
                  ),
                );
              } else if (rejectLogin) {
                handler.reject(
                  DioException.badResponse(
                    statusCode: 401,
                    requestOptions: request,
                    response: Response(
                      requestOptions: request,
                      statusCode: 401,
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'user': {'email': 'user@example.com', 'nickname': '테스트'},
                      'access_token': 'test-access',
                      'refresh_token': 'test-refresh',
                    },
                  ),
                );
              }
            },
          ),
        );
      addTearDown(dio.close);
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authApi: AuthApi(dio: dio)),
          routes: {'/my_routes': (_) => const Scaffold(body: Text('지도 화면'))},
        ),
      );

      await tester.tap(find.text('계정이 없으신가요? 회원가입'));
      await tester.pumpAndSettle();
      final fields = find.byType(EditableText);
      for (final (index, value) in [
        (0, 'user@example.com'),
        (1, 'Example9!Only'),
        (2, 'Example9!Only'),
        (3, '테스트'),
      ]) {
        await tester.enterText(fields.at(index), value);
      }
      await tester.ensureVisible(find.text('전체 동의'));
      await tester.tap(find.text('전체 동의'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('회원가입 완료'));
      await tester.tap(find.text('회원가입 완료'));
      await tester.pumpAndSettle();
      expect(requests.single.path, '/api/v1/auth/signup');
      expect(requests.single.data, {
        'email': 'user@example.com',
        'password': 'Example9!Only',
        'password_confirm': 'Example9!Only',
        'nickname': '테스트',
        'terms_agreed': true,
        'privacy_agreed': true,
      });
      expect(
        tester.widget<EditableText>(fields.first).controller.text,
        'user@example.com',
      );
      await tester.enterText(fields.last, 'Example9!Only');
      await tester.pump();
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/v1/auth/login');
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.text('지도 화면'), findsNothing);

      rejectLogin = false;
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/v1/auth/login');
      expect(find.text('지도 화면'), findsOneWidget);
      expect((await const FlutterSecureStorage().readAll()).values, [
        'test-refresh',
      ]);
    },
  );

  testWidgets('Tapping the glass padding opens the matching keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final fields = find.byType(GlassTextField);
    final email = tester.widget<GlassTextField>(fields.first);
    final password = tester.widget<GlassTextField>(fields.last);
    final emailPadding = tester.getTopLeft(fields.first) + const Offset(8, 8);

    await tester.tapAt(emailPadding);
    await tester.pump();
    expect(email.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    tester.testTextInput.hide();
    await tester.tapAt(emailPadding);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('비밀번호 표시'));
    await tester.pump();
    expect(find.byTooltip('비밀번호 숨기기'), findsOneWidget);
    expect(email.focusNode!.hasFocus, isTrue);

    await tester.tapAt(tester.getTopLeft(fields.last) + const Offset(8, 8));
    await tester.pump();
    expect(password.focusNode!.hasFocus, isTrue);

    await tester.tap(find.text('이메일'));
    await tester.pump();
    expect(password.focusNode!.hasFocus, isFalse);
  });
}
