import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const _brand = Color(0xFFD9553E);

// 검색 API의 문자열 좌표를 앱에서 사용할 숫자로 변환합니다.
// 공통 데이터 타입을 선언
class KakaoSearchResult {
  const KakaoSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isAddress,
    this.placeId,
    this.category = '',
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isAddress;
  final String? placeId;
  final String category;

  static KakaoSearchResult? fromDocument(
    Map<String, dynamic> document, {
    required bool isAddress,
  }) {
    final latitude = double.tryParse('${document['y']}');
    final longitude = double.tryParse('${document['x']}');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }

    final roadAddress = document['road_address_name'] as String? ?? '';
    final address = document['address_name'] as String? ?? '';
    return KakaoSearchResult(
      name: isAddress ? address : document['place_name'] as String? ?? '',
      address: roadAddress.isNotEmpty ? roadAddress : address,
      latitude: latitude,
      longitude: longitude,
      isAddress: isAddress,
      placeId: document['id'] as String?,
      category: document['category_name'] as String? ?? '',
    );
  }

  // 이후 백엔드 연동 시 이 정보를 요청 본문으로 사용할 수 있습니다.
  Map<String, Object?> toJson() => {
    'provider': 'kakao',
    'type': isAddress ? 'address' : 'place',
    'placeId': placeId,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };
}

// 검색창 UI
class RouteSearchField extends StatelessWidget {
  const RouteSearchField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.settings,
    required this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final LiquidGlassSettings settings;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GlassSearchBar(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onCancel: onCancel,
        showsCancelButton: true,
        cancelButtonAlwaysVisible: true,
        cancelButtonSemanticLabel: '장소 선택 취소',
        placeholder: '$label 검색',
        clearButtonSemanticLabel: '검색 지우기',
        autocorrect: false,
        settings: settings,
      ),
    );
  }
}

// 검색 결과 목록 UI
class RouteSearchScreen extends StatelessWidget {
  const RouteSearchScreen({
    required this.isSearching,
    required this.message,
    required this.results,
    required this.onResultSelected,
    super.key,
  });

  final bool isSearching;
  final String? message;
  final List<KakaoSearchResult> results;
  final ValueChanged<KakaoSearchResult> onResultSelected;

  @override
  Widget build(BuildContext context) {
    return GlassGroupedSection(
      margin: EdgeInsets.zero,
      shape: const LiquidRoundedSuperellipse(borderRadius: 16),
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        if (isSearching)
          const Padding(
            padding: EdgeInsets.all(8),
            child: GlassProgressIndicator.linear(
              height: 6.0,
              color: _brand,
              backgroundColor: Color(0x3371777D),
              semanticLabel: '장소 검색 중',
            ),
          ),
        if (message != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(message!)),
        for (final result in results)
          GlassListTile(
            leading: Icon(
              result.isAddress ? Icons.home_outlined : Icons.place_outlined,
            ),
            title: Text(result.name),
            subtitle: Text(
              [
                result.isAddress ? '주소' : '장소',
                if (result.address.isNotEmpty && result.address != result.name)
                  result.address,
                if (result.category.isNotEmpty) result.category,
              ].join(' · '),
            ),
            onTap: () => onResultSelected(result),
          ),
      ],
    );
  }
}

class RouteSearchPanel extends StatelessWidget {
  const RouteSearchPanel({
    super.key,
    required this.settings,
    required this.origin,
    required this.destination,
    required this.busField,
    required this.onSearch,
    required this.bottomInset,
    required this.keyboardVisible,
    this.suggestions,
  });

  final LiquidGlassSettings settings;
  final Widget origin;
  final Widget destination;
  final Widget busField;
  final Widget? suggestions;
  final VoidCallback? onSearch;
  final double bottomInset;
  final bool keyboardVisible;

  @override
  Widget build(BuildContext context) {
    final sheetScroll = ScrollControllerProvider.of(context);
    final safeArea = MediaQuery.viewPaddingOf(context);

    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        controller: sheetScroll?.controller,
        physics: keyboardVisible
            ? const ClampingScrollPhysics()
            : sheetScroll?.physics,
        padding: EdgeInsets.fromLTRB(
          safeArea.left + 16,
          24,
          safeArea.right + 16,
          bottomInset + 16,
        ),
        child: GlassContainer.card(
          settings: settings,
          useOwnLayer: true,
          padding: const EdgeInsets.all(12),
          shape: const LiquidRoundedRectangle(borderRadius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              origin,
              destination,
              ?suggestions,
              busField,
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE0E0E2),
                  disabledForegroundColor: const Color(0xFF606067),
                  minimumSize: const Size(0, 52),
                ),
                onPressed: onSearch,
                child: const Text('경로 검색'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutePanelRow extends StatelessWidget {
  const RoutePanelRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: const Color(0xFFA9ABB0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GlassListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
