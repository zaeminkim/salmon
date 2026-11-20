import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class LiquidGlass extends StatefulWidget {
  const LiquidGlass({super.key});

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  // 컴포넌트의 현재 값
  bool _enabled = true;
  bool _favorite = false;
  final bool _notifications = true;

  final int _periodIndex = 0;
  int _tabIndex = 0;

  final double _volume = 0.5;
  final double _steppedValue = 0.75;

  String _query = '';

  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 기본 구조
    return GlassScaffold(
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFECE3FF), Color(0xF949D880)],
          ),
        ),
      ),
      // 상단 앱바
      appBar: GlassAppBar(title: const Text('Liguid Glass 테스트')),
      // 하단 탭바
      bottomBar: GlassTabBar.bottom(
        tabs: [
          GlassTab(icon: Icon(Icons.tune), label: '컨트롤'),
          GlassTab(icon: Icon(Icons.home), label: '홈'),
          GlassTab(icon: Icon(Icons.edit_note), label: '입력'),
        ],
        selectedIndex: _tabIndex,
        onTabSelected: (index) {
          FocusScope.of(context).unfocus();

          setState(() {
            _tabIndex = index;
          });
        },
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 스위치
            GlassSwitch(
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            SizedBox(height: 24),
            // 일반 버튼
            GlassButton(icon: Icon(Icons.gps_fixed), onTap: () {}),
            SizedBox(height: 24),
            // 커스텀 버튼
            GlassButton.custom(
              width: 353,
              height: 52,
              // tintColor: Color(0xFFD9553E),
              surfaceStyle: GlassSurfaceStyle.solid,
              color: Color(0xFFD9553E),
              shape: LiquidRoundedRectangle(borderRadius: 24),
              onTap: () {
                // 토스트
                // GlassToast.show(context, message: '저장 버튼을 눌렀습니다');
              },
              child: const Text(
                '로그인',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 24),
            // 아이콘 버튼
            GlassIconButton(
              icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border),
              iconColor: _favorite ? Colors.red : Colors.black,
              semanticLabel: '즐겨찾기',
              onPressed: () {
                setState(() {
                  _favorite = !_favorite;
                });
              },
            ),
            SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              // 검색창
              child: GlassSearchBar(
                placeholder: '버스 번호를 입력하세요',
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
            ),
            SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              // 입력창
              child: GlassTextField(
                controller: _nameController,
                placeholder: '이메일을 입력해 주세요',
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
