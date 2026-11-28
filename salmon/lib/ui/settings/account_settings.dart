part of 'settings_screen.dart';

// 계정 정보와 로그아웃, 회원 탈퇴 화면 진입을 처리합니다.
class _AccountSettings extends StatefulWidget {
  const _AccountSettings();

  @override
  State<_AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<_AccountSettings> {
  bool _loggingOut = false;

  Future<void> _confirmLogout(BuildContext context) async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppMessageDialog(
        title: '로그아웃하시겠어요?',
        message: '다시 이용하려면 로그인이 필요해요.',
        cancelLabel: '취소',
        actionLabel: '로그아웃',
      ),
    );

    if (confirmed == true && context.mounted) {
      _loggingOut = true;
      try {
        final warning = await AuthApi.instance.logout();
        if (!context.mounted) return;
        if (warning != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(warning)));
        }
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃을 완료하지 못했어요. 다시 시도해 주세요.')),
        );
      } finally {
        _loggingOut = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthApi.instance.user;
    return _SettingsPage(
      title: '계정',
      body: ListView(
        padding: _pagePadding,
        children: [
          const Text('로그인 정보', style: _sectionStyle),
          const SizedBox(height: 16),
          _SettingsCard(
            background: const Color(0xFFF5F5F5),
            title: user?.nickname ?? '거슬렁 사용자',
            description: switch (user?.email) {
              null => '로그인 정보 없음',
              '' => '카카오 계정으로 로그인',
              final email => email,
            },
          ),
          const SizedBox(height: 20),
          _SettingsMenuRow(
            title: '로그아웃',
            description: '다른 계정으로 로그인할 수 있어요',
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 20),
          _SettingsMenuRow(
            title: '회원 탈퇴',
            description: '거슬렁 계정을 삭제해요',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _WithdrawSettings()),
            ),
          ),
        ],
      ),
    );
  }
}
