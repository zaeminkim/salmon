import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../data/places/kakao_search_result.dart';
import 'search_suggestions_progress.dart';

export '../../data/places/kakao_search_result.dart';
export 'route_search_panel.dart';

// 검색 결과 목록 UI
class RouteSearchScreen extends StatelessWidget {
  const RouteSearchScreen({
    required this.isSearching,
    required this.message,
    required this.results,
    required this.onResultSelected,
    required this.isLocating,
    required this.onCurrentLocation,
    super.key,
  });

  final bool isSearching;
  final String? message;
  final List<KakaoSearchResult> results;
  final ValueChanged<KakaoSearchResult> onResultSelected;
  final bool isLocating;
  final VoidCallback onCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return GlassGroupedSection(
      margin: EdgeInsets.zero,
      shape: const LiquidRoundedSuperellipse(borderRadius: 16),
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        GlassListTile(
          leading: const Icon(Icons.near_me_outlined, color: Colors.black),
          title: const Text('내 위치', style: TextStyle(color: Colors.black)),
          subtitle: isLocating ? const Text('현재 위치 확인 중…') : null,
          onTap: isLocating ? null : onCurrentLocation,
        ),
        if (isSearching)
          const SearchSuggestionsProgress(semanticLabel: '장소 검색 중'),
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
