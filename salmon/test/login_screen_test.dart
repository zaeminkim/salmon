import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/auth/login_screen.dart';

void main() {
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
