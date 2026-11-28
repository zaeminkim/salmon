part of 'settings_screen.dart';

// 설정 화면들이 공통으로 쓰는 레이아웃과 스타일을 정의합니다.
const _brand = Color(0xFFD9553E);
const _ink = Color(0xFF292D32);
const _muted = Color(0xFF71777D);
const _dividerColor = Color(0xFFECEDEF);
const _pagePadding = EdgeInsets.fromLTRB(20, 24, 20, 24);
const _titleStyle = TextStyle(
  color: _ink,
  fontSize: 20,
  fontWeight: FontWeight.w600,
);
const _descriptionStyle = TextStyle(color: _muted, fontSize: 15, height: 2.5);
const _sectionStyle = TextStyle(color: _muted, fontWeight: FontWeight.w600);

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
        titleSpacing: -4,
        title: Text(
          title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
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
