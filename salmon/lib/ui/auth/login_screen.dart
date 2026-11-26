import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/auth/signup_screen.dart';

const _brand = Color(0xFFD9553E);

const _pagePadding = 20.0;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String _email = '';
  String _password = '';
  bool _showPassword = false;

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canLogin = _email.trim().isNotEmpty && _password.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false, // 키보드가 표시돼도 본문을 줄이지 않고, 키보드가 본문 위를 덮도록
      backgroundColor: Color(0xFFFFFFFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: _pagePadding, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '거슬렁',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: _brand,
                ),
              ),
              Text(
                '내가 원하는 길로, 편안하게',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              Text(
                '나에게 맞는 이동을 거슬러에서 시작하세요.',
                style: TextStyle(color: Color(0xFF71777D)),
              ),
              SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  _input(
                    '이메일',
                    placeholder: '이메일을 입력해 주세요',
                    onChanged: (value) => setState(() => _email = value),
                  ),
                  _input(
                    '비밀번호',
                    placeholder: '비밀번호를 입력해 주세요',
                    onChanged: (value) => setState(() => _password = value),
                    isPassword: true,
                  ),
                ],
              ),
              SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassButton.custom(
                    height: 52,
                    surfaceStyle: GlassSurfaceStyle.solid,
                    enabled: canLogin,
                    color: canLogin ? _brand : _brand.withAlpha(225),
                    shape: LiquidRoundedRectangle(borderRadius: 24),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/my_routes', (route) => false);
                    },
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignupScreen()),
                      );
                    },
                    child: const Text(
                      '계정이 없으신가요? 회원가입',
                      style: TextStyle(color: Color(0xFF71777D)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    spacing: 12,
                    children: [
                      Expanded(child: Divider()),
                      Text('또는 간편 로그인'),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: 1008 / 138,
                    child: GlassButton.custom(
                      label: '카카오 로그인',
                      onTap: () {},
                      surfaceStyle: GlassSurfaceStyle.solid,
                      style: GlassButtonStyle.transparent,
                      shape: const LiquidRoundedRectangle(borderRadius: 12),
                      child: Image.asset(
                        'assets/images/kakao_login_kr_large.png',
                        fit: BoxFit.contain,
                        excludeFromSemantics: true, // 버튼의 label을 읽도록 함
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    String label, {
    required String placeholder,
    required ValueChanged<String> onChanged,
    bool isPassword = false,
  }) {
    final focusNode = isPassword ? _passwordFocusNode : _emailFocusNode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
              keyboardType: isPassword
                  ? TextInputType.visiblePassword
                  : TextInputType.emailAddress,
              obscureText: isPassword && !_showPassword,
              height: 52,
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
              suffixIcon: isPassword
                  ? IconButton(
                      tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 표시',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
