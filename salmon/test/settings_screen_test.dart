import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/auth/login_screen.dart';
import 'package:salmon/ui/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Saves the push preference when returning to notifications', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();
    final notificationSwitch = find.byType(GlassSwitch);
    expect(tester.widget<GlassSwitch>(notificationSwitch).value, isTrue);
    await tester.tap(notificationSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<GlassSwitch>(notificationSwitch).value, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();
    expect(tester.widget<GlassSwitch>(notificationSwitch).value, isFalse);
  });

  testWidgets('Opens withdrawal and confirms logout through the account menu', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.text('계정'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 정보 없음'), findsOneWidget);

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.text('정말 탈퇴하시겠어요?'), findsOneWidget);
    await tester.tap(find.text('계속 이용하기'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 정보'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃하시겠어요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃하시겠어요?'), findsNothing);
    expect(find.text('로그인 정보'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('로그아웃')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
  });
}
