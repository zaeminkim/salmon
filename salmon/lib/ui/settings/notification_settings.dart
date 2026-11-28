part of 'settings_screen.dart';

// 푸시 알림 설정값과 저장 상태를 한곳에서 관리합니다.
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
            '거슬렁의 푸시 알림 수신 여부를 설정할 수 있어요.\n'
            '기기에서 알림 권한을 허용해야 알림을 받을 수 있어요.',
            style: _descriptionStyle,
          ),
        ],
      ),
    );
  }
}
