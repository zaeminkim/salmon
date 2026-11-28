import 'package:flutter/material.dart';

/// 값이 있을 때만 표시하고, 검색 상태는 각 입력란에서 초기화합니다.
class SearchFieldClearButton extends StatelessWidget {
  const SearchFieldClearButton({
    super.key,
    required this.controller,
    required this.tooltip,
    required this.onCleared,
  });

  final TextEditingController controller;
  final String tooltip;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => value.text.isEmpty
          ? const SizedBox.shrink()
          : IconButton(
              tooltip: tooltip,
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.clear();
                onCleared();
              },
            ),
    );
  }
}
