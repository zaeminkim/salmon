part of 'settings_screen.dart';

// 회원 탈퇴 전에 확인할 항목을 표시합니다.
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
              AppPrimaryButton(
                label: '계속 이용하기',
                onTap: () => Navigator.of(context).pop(),
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
