import 'package:flutter/material.dart';
import 'package:salmon/data/auth/auth_api.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_screen.dart';

const _brand = Color(0xFFD9553E);
const _ink = Color(0xFF292D32);
const _muted = Color(0xFF71777D);
const _dividerColor = Color(0xFFECEDEF);
const _pagePadding = EdgeInsets.fromLTRB(20, 24, 20, 24);
const _titleStyle = TextStyle(
  color: _ink,
  fontSize: 16,
  fontWeight: FontWeight.w700,
);
const _descriptionStyle = TextStyle(color: _muted, fontSize: 13, height: 1.5);
const _sectionStyle = TextStyle(color: _muted, fontWeight: FontWeight.w600);

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

class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings();

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  static const _pushPreference = 'settings.pushNotificationsEnabled';

  SharedPreferences? _preferences;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _enabled = preferences.getBool(_pushPreference) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _updatePreference(bool enabled) async {
    final preferences = _preferences;
    if (preferences == null || _saving) return;
    final previous = _enabled;
    setState(() {
      _enabled = enabled;
      _saving = true;
    });

    try {
      if (!await preferences.setBool(_pushPreference, enabled)) {
        throw StateError('Failed to save push notification preference');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _enabled = previous);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: '알림',
      body: ListView(
        padding: _pagePadding,
        children: [
          const Text('앱 알림', style: _sectionStyle),
          const SizedBox(height: 16),
          GlassListTile(
            title: const Text('푸시 알림 받기', style: _titleStyle),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            trailing: GlassSwitch(
              value: _enabled,
              onChanged: _preferences == null || _saving
                  ? null
                  : _updatePreference,
              activeColor: _brand,
              semanticLabel: '푸시 알림 받기',
            ),
          ),
          const Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 20),
          const Text(
            '거슬렁의 푸시 알림 수신 여부를 설정할 수 있어요. '
            '기기에서 알림 권한을 허용해야 알림을 받을 수 있어요.',
            style: _descriptionStyle,
          ),
        ],
      ),
    );
  }
}

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
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '로그아웃하시겠어요?',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('다시 이용하려면 로그인이 필요해요.', style: _descriptionStyle),
                const SizedBox(height: 20),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: _muted,
                          side: const BorderSide(color: _dividerColor),
                        ),
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('취소'),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: _brand,
                          side: const BorderSide(color: _brand),
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

class _WithdrawSettings extends StatelessWidget {
  const _WithdrawSettings();

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: '회원 탈퇴',
      body: ListView(
        padding: _pagePadding,
        children: const [
          Text(
            '정말 탈퇴하시겠어요?',
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 20),
          Text('탈퇴하면 이 계정으로 더 이상 로그인할 수 없어요.', style: _descriptionStyle),
          SizedBox(height: 20),
          _SettingsCard(
            background: Color(0xFFFDF4F0),
            title: '탈퇴 전 확인해 주세요',
            description:
                '저장한 경로와 개인 설정이 삭제돼요.\n'
                '삭제된 정보는 복구할 수 없어요.',
          ),
          SizedBox(height: 20),
          Text('회원 탈퇴 기능은 준비 중이에요.', style: _descriptionStyle),
        ],
      ),
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              GlassButton.custom(
                height: 52,
                surfaceStyle: GlassSurfaceStyle.solid,
                color: _brand,
                shape: LiquidRoundedRectangle(borderRadius: 24),
                label: '계속 이용하기',
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  '계속 이용하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: const Color(0xFFA13E2F),
                ),
                onPressed: () => {},
                child: const Text('탈퇴하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.body, this.bottom});

  final String title;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(top: false, bottom: bottom == null, child: body),
      bottomNavigationBar: bottom,
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 99),
          child: GlassListTile(
            title: Text(title, style: _titleStyle),
            subtitle: Text(description, style: _descriptionStyle),
            trailing: const Icon(Icons.chevron_right, color: _muted, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            onTap: onTap,
          ),
        ),
        const Divider(height: 1, color: _dividerColor),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.background,
    required this.title,
    required this.description,
  });

  final Color background;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(title, style: _titleStyle),
          Text(description, style: _descriptionStyle),
        ],
      ),
    );
  }
}
