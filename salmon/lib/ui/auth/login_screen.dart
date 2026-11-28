import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:salmon/data/auth/auth_api.dart';
import 'package:salmon/data/auth/kakao_login_sdk.dart';
import 'package:salmon/ui/core/widgets/app_glass_text_field.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/auth/signup_screen.dart';
import 'package:salmon/ui/core/widgets/app_primary_button.dart';

const _brand = Color(0xFFD9553E);

const _pagePadding = 20.0;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authApi});

  final AuthApi? authApi;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _emailController = TextEditingController();
  String _password = '';
  bool _showPassword = false;
  bool _submitting = false;

  AuthApi get _authApi => widget.authApi ?? AuthApi.instance;

  Future<void> _runLogin(Future<bool> Function() authenticate) async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      if (!await authenticate() || !mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/my_routes', (_) => false);
    } on AuthFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted && !isKakaoLoginCancellation(error)) {
        _showMessage('로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _login() => _runLogin(() async {
    await _authApi.login(email: _emailController.text, password: _password);
    return true;
  });

  Future<void> _kakaoLogin() => _runLogin(() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('카카오 로그인은 Android 앱에서 이용할 수 있어요.');
      return false;
    }
    final token = await getKakaoLoginToken();
    if (!mounted) return false;
    try {
      await _authApi.loginWithKakao(token.accessToken);
    } on AuthFailure catch (error) {
      if (error.code != 'consent_required') rethrow;
      if (!mounted || !await _confirmKakaoConsent() || !mounted) return false;
      await _authApi.loginWithKakao(token.accessToken, consentGranted: true);
    }
    return true;
  });

  Future<bool> _confirmKakaoConsent() async {
    var terms = false;
    var privacy = false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('카카오 계정으로 가입'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: terms,
                    onChanged: (value) =>
                        setDialogState(() => terms = value == true),
                    title: const Text('이용약관 동의 (필수)'),
                  ),
                  CheckboxListTile(
                    value: privacy,
                    onChanged: (value) =>
                        setDialogState(() => privacy = value == true),
                    title: const Text('개인정보 수집 및 이용 동의 (필수)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: terms && privacy
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('동의하고 계속'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _openSignup() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => SignupScreen(authApi: _authApi)),
    );
    if (!mounted || email == null) return;
    setState(() => _emailController.text = email);
    _showMessage('회원가입이 완료됐어요. 가입한 계정으로 로그인해 주세요.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _emailController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canLogin =
        !_submitting &&
        _emailController.text.trim().isNotEmpty &&
        _password.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false, // 키보드가 표시돼도 본문을 줄이지 않고, 키보드가 본문 위를 덮도록
      backgroundColor: Color(0xFFFFFFFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: _pagePadding, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                '거슬렁',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: _brand,
                ),
              ),
              SizedBox(height: 12,),
              Text(
                '내가 원하는 길로, 편안하게',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '나에게 맞는 이동을 거슬러에서 시작하세요.',
                style: TextStyle(fontSize: 18, color: Color(0xFF71777D)),
              ),
              SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  _input(
                    '이메일',
                    placeholder: '이메일을 입력해 주세요',
                    onChanged: (_) => setState(() {}),
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
                  AppPrimaryButton(
                    label: _submitting ? '로그인 중…' : '로그인',
                    enabled: canLogin,
                    onTap: _login,
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _openSignup,
                    child: const Text(
                      '계정이 없으신가요? 회원가입',
                      style: TextStyle(color: Color(0xFF71777D)),
                    ),
                  ),
                  const SizedBox(height: 52),
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
                      enabled: !_submitting,
                      onTap: _kakaoLogin,
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
        AppGlassTextField(
          controller: isPassword ? null : _emailController,
          focusNode: focusNode,
          placeholder: placeholder,
          onChanged: onChanged,
          keyboardType: isPassword
              ? TextInputType.visiblePassword
              : TextInputType.emailAddress,
          obscureText: isPassword && !_showPassword,
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
      ],
    );
  }
}
