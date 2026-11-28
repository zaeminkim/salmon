import 'package:flutter/material.dart';
import 'package:salmon/data/auth/auth_api.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/core/widgets/app_message_dialog.dart';
import 'package:salmon/ui/core/widgets/app_primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_screen.dart';

part 'account_settings.dart';
part 'notification_settings.dart';
part 'settings_components.dart';
part 'withdraw_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: '설정',
      body: ListView(
        padding: _pagePadding,
        children: [
          _SettingsMenuRow(
            title: '알림',
            description: '푸시 알림을 관리해요',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _NotificationSettings()),
            ),
          ),
          const SizedBox(height: 20),
          _SettingsMenuRow(
            title: '계정',
            description: '로그인 정보와 회원 탈퇴를 확인해요',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _AccountSettings()),
            ),
          ),
        ],
      ),
    );
  }
}
