import 'package:flutter/material.dart';

import '../core/widgets/app_primary_button.dart';

/// 시트의 드래그 컨트롤러에 연결되는 길찾기 입력 폼입니다.
class RouteSearchPanel extends StatelessWidget {
  const RouteSearchPanel({
    super.key,
    required this.scrollController,
    required this.origin,
    required this.destination,
    required this.busField,
    required this.onSearch,
    required this.bottomInset,
    required this.keyboardVisible,
    this.suggestions,
    this.suggestionsAfterOrigin = false,
  });

  final ScrollController scrollController;
  final Widget origin;
  final Widget destination;
  final Widget busField;
  final Widget? suggestions;
  final bool suggestionsAfterOrigin;
  final VoidCallback? onSearch;
  final double bottomInset;
  final bool keyboardVisible;

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.viewPaddingOf(context);

    return CustomScrollView(
      controller: scrollController,
      physics: keyboardVisible ? const ClampingScrollPhysics() : null,
      slivers: [
        PinnedHeaderSliver(
          child: Semantics(
            label: '길찾기 패널 크기 조절',
            child: const ColoredBox(
              color: Colors.white,
              child: SizedBox(
                height: 24,
                child: Center(
                  child: SizedBox(
                    width: 32,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF71777D),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            safeArea.left + 16,
            24,
            safeArea.right + 16,
            bottomInset + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                origin,
                if (suggestionsAfterOrigin) ?suggestions,
                destination,
                if (!suggestionsAfterOrigin) ?suggestions,
                busField,
                AppPrimaryButton(
                  label: '경로 검색',
                  onTap: onSearch ?? () {},
                  enabled: onSearch != null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
