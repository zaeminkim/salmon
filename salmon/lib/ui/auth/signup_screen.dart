import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const _brand = Color(0xFFD9553E);
const _ink = Color(0xFF292D32);
const _muted = Color(0xFF71777D);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmationFocusNode = FocusNode();
  final _nicknameFocusNode = FocusNode();

  String _email = '';
  String _password = '';
  String _passwordConfirmation = '';
  String _nickname = '';
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;

  bool get _allAgreed => _termsAgreed && _privacyAgreed;

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmationFocusNode.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passwordsDiffer =
        _passwordConfirmation.isNotEmpty && _password != _passwordConfirmation;
    final canSignup =
        _email.trim().isNotEmpty &&
        _password.isNotEmpty &&
        _password == _passwordConfirmation &&
        _nickname.trim().isNotEmpty &&
        _allAgreed;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          '회원가입',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '거슬렁과 함께 편안한 이동을 시작해 보세요.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  _input(
                    '이메일',
                    focusNode: _emailFocusNode,
                    placeholder: '이메일을 입력해 주세요',
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => setState(() => _email = value),
                  ),
                  _input(
                    '비밀번호',
                    focusNode: _passwordFocusNode,
                    placeholder: '비밀번호를 입력해 주세요',
                    keyboardType: TextInputType.visiblePassword,
                    showPassword: _showPassword,
                    onToggleVisibility: () =>
                        setState(() => _showPassword = !_showPassword),
                    onChanged: (value) => setState(() => _password = value),
                  ),
                  _input(
                    '비밀번호 확인',
                    focusNode: _confirmationFocusNode,
                    placeholder: '비밀번호를 입력해 주세요',
                    keyboardType: TextInputType.visiblePassword,
                    showPassword: _showConfirmation,
                    onToggleVisibility: () =>
                        setState(() => _showConfirmation = !_showConfirmation),
                    onChanged: (value) =>
                        setState(() => _passwordConfirmation = value),
                    error: passwordsDiffer ? '비밀번호가 일치하지 않습니다.' : null,
                  ),
                  _input(
                    '닉네임',
                    focusNode: _nicknameFocusNode,
                    placeholder: '사용할 닉네임을 입력해 주세요',
                    onChanged: (value) => setState(() => _nickname = value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '약관 동의',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              _agreement(
                '전체 동의',
                value: _allAgreed,
                onChanged: (agreed) => setState(() {
                  _termsAgreed = agreed;
                  _privacyAgreed = agreed;
                }),
              ),
              const Divider(height: 8, thickness: 1, color: Color(0xFFE9E9E7)),
              _agreement(
                '이용약관 동의 (필수)',
                value: _termsAgreed,
                onChanged: (agreed) => setState(() => _termsAgreed = agreed),
                detailsTitle: '이용약관',
              ),
              _agreement(
                '개인정보 수집 및 이용 동의 (필수)',
                value: _privacyAgreed,
                onChanged: (agreed) => setState(() => _privacyAgreed = agreed),
                detailsTitle: '개인정보 수집 및 이용',
              ),
              const SizedBox(height: 24),
              GlassButton.custom(
                height: 52,
                surfaceStyle: GlassSurfaceStyle.solid,
                enabled: canSignup,
                color: canSignup ? _brand : _brand.withAlpha(225),
                shape: const LiquidRoundedRectangle(borderRadius: 24),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('회원가입에 필요한 입력을 확인했습니다.')),
                    );
                },
                child: const Text(
                  '회원가입 완료',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  '이미 계정이 있으신가요? 로그인',
                  style: TextStyle(color: _muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    String label, {
    required FocusNode focusNode,
    required String placeholder,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    bool showPassword = false,
    VoidCallback? onToggleVisibility,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        TextFieldTapRegion(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () {
              final editableText = focusNode.context
                  ?.findAncestorStateOfType<EditableTextState>();
              if (editableText != null) {
                editableText.requestKeyboard();
              } else {
                focusNode.requestFocus();
              }
            },
            child: GlassTextField(
              focusNode: focusNode,
              placeholder: placeholder,
              onChanged: onChanged,
              keyboardType: keyboardType,
              obscureText: onToggleVisibility != null && !showPassword,
              height: 52,
              textStyle: const TextStyle(fontFamily: 'Noto Sans KR'),
              placeholderStyle: const TextStyle(fontFamily: 'Noto Sans KR'),
              surfaceStyle: GlassSurfaceStyle.glass,
              useOwnLayer: true,
              settings: const LiquidGlassSettings(
                bodyMode: GlassBodyMode.clear,
                glassColor: Color(0xB3E1E7EF),
              ),
              shape: const LiquidRoundedRectangle(
                borderRadius: 12,
                side: BorderSide(color: Color(0xFFA9ABB0)),
              ),
              suffixIcon: onToggleVisibility == null
                  ? null
                  : IconButton(
                      tooltip: showPassword ? '비밀번호 숨기기' : '비밀번호 표시',
                      onPressed: onToggleVisibility,
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
            ),
          ),
        ),
        if (error != null)
          Text(error, style: const TextStyle(color: _brand, fontSize: 12)),
      ],
    );
  }

  Widget _agreement(
    String label, {
    required bool value,
    required ValueChanged<bool> onChanged,
    String? detailsTitle,
  }) {
    final isAll = detailsTitle == null;
    final checkbox = ListTileTheme(
      horizontalTitleGap: 6,
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        minTileHeight: 40,
        dense: true,
        activeColor: _brand,
        side: const BorderSide(color: Color(0xFF90959A), width: 1.5),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isAll ? _ink : _muted,
            fontSize: isAll ? 13 : 12,
            fontWeight: isAll ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );

    if (detailsTitle == null) {
      return Material(
        color: const Color(0xFFF6F6F5),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: checkbox,
      );
    }

    return Row(
      children: [
        Expanded(child: checkbox),
        IconButton(
          tooltip: '$detailsTitle 자세히 보기',
          icon: const Icon(Icons.chevron_right, color: _muted, size: 20),
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(detailsTitle),
                content: const Text('약관 본문을 준비 중입니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
