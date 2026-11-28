import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/core/widgets/chip_button.dart';

import '../../my_routes/saved_route_card.dart';
import '../../route_results/route_detail_screen.dart';
import '../../my_routes/route_management_screen.dart';

const _routes = [
  (name: '예시 경로', from: '집', to: '회사'),
  (name: '출근길', from: '집', to: '회사'),
  (name: '퇴근길', from: '회사', to: '집'),
  (name: '등교길', from: '집', to: '학교'),
  (name: '주말 산책', from: '집', to: '공원'),
  (name: '주말 외식', from: '집', to: '레스토랑'),
];

class SavedRoutesOverlay extends StatefulWidget {
  const SavedRoutesOverlay({
    super.key,
    required this.settings,
    required this.cardHeight,
    required this.example,
    required this.onExampleSelected,
  });

  static const maxCardHeight = 232.0;
  static const paginationHeight = 18.0;
  final LiquidGlassSettings settings;
  final double cardHeight;
  final Future<Map<String, dynamic>> example;
  final ValueChanged<bool> onExampleSelected;

  @override
  State<SavedRoutesOverlay> createState() => _SavedRoutesOverlayState();
}

class _SavedRoutesOverlayState extends State<SavedRoutesOverlay> {
  final _pages = PageController(viewportFraction: 0.92);
  int _selected = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Widget _buildExampleCard(BuildContext context) {
    return FutureBuilder(
      future: widget.example,
      builder: (context, snapshot) {
        final example = snapshot.data;
        if (example == null) {
          return SavedRouteCard(
            title: snapshot.hasError ? '예시 경로를 불러오지 못했어요.' : '예시 경로 불러오는 중…',
          );
        }
        final candidates = example['candidates'] as List;
        final candidate = candidates
            .whereType<Map<String, dynamic>>()
            .firstOrNull;
        final origin = _examplePlace(example['origin'] as Map);
        final destination = _examplePlace(example['destination'] as Map);
        return SavedRouteCard(
          title: _routes.first.name,
          route: candidate,
          places: '${origin.name} → ${destination.name}',
          onTap: candidate == null
              ? null
              : () => Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => RouteDetailScreen(
                      route: candidate,
                      candidates: candidates
                          .whereType<Map<String, dynamic>>()
                          .toList(),
                      searchId: example['search_id'],
                      origin: origin,
                      destination: destination,
                    ),
                  ),
                ),
        );
      },
    );
  }

  JourneyPlace _examplePlace(Map place) => (
    name: place['name'] as String,
    position: LatLng(
      (place['latitude'] as num).toDouble(),
      (place['longitude'] as num).toDouble(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: AlignmentDirectional.topStart,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                for (int i = 0; i < _routes.length; i++)
                  ChipButton(
                    settings: widget.settings,
                    label: _routes[i].name,
                    selected: _selected == i,
                    onTap: () => _pages.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                // 경로가 추가돼도 관리 항목은 가로 목록의 마지막에 남습니다.
                ChipButton(
                  settings: widget.settings,
                  label: '경로 관리',
                  icon: Icons.tune,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const RouteManagementScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: widget.cardHeight,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _routes.length,
                  onPageChanged: (index) {
                    setState(() => _selected = index);
                    widget.onExampleSelected(index == 0);
                  },
                  itemBuilder: (_, i) {
                    final route = _routes[i];
                    return i == 0
                        ? _buildExampleCard(context)
                        : SavedRouteCard(
                            title: route.name,
                            places: '${route.from} → ${route.to}',
                          );
                  },
                ),
              ),
              SizedBox(
                height: SavedRoutesOverlay.paginationHeight,
                child: Semantics(
                  label: '경로 카드 ${_selected + 1} / ${_routes.length}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      for (var i = 0; i < _routes.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _selected
                                ? const Color(0xFFD9553E)
                                : const Color(0xFF8A8E94),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
