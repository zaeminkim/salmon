import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/widgets/journey_result_card.dart';
import '../../route_results/route_detail_screen.dart';
import '../route_management_screen.dart';

const _routes = [
  (name: '예시 경로', from: '집', to: '회사'),
  (name: '퇴근길', from: '회사', to: '집'),
  (name: '등교길', from: '집', to: '학교'),
  (name: '주말 경로', from: '집', to: '공원'),
];

class SavedRoutesOverlay extends StatefulWidget {
  const SavedRoutesOverlay({
    super.key,
    required this.settings,
    required this.cardHeight,
    required this.example,
    required this.onExampleSelected,
  });

  static const maxCardHeight = 288.0;
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
          return Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                snapshot.hasError ? '예시 경로를 불러오지 못했어요.' : '예시 경로 불러오는 중…',
              ),
            ),
          );
        }
        final candidates = example['candidates'] as List;
        final candidate = candidates
            .whereType<Map<String, dynamic>>()
            .firstOrNull;
        final origin = _examplePlace(example['origin'] as Map);
        final destination = _examplePlace(example['destination'] as Map);
        return JourneyResultCard(
          route: candidate ?? const {},
          places: '${origin.name} → ${destination.name}',
          onTap: candidate == null
              ? null
              : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
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
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < _routes.length; i++)
                        GlassChip(
                          label: _routes[i].name,
                          selected: _selected == i,
                          selectedColor: Colors.transparent,
                          surfaceStyle: GlassSurfaceStyle.glass,
                          settings: _selected == i
                              ? widget.settings.copyWith(
                                  glassColor: const Color(0xC6D9553E),
                                )
                              : widget.settings,
                          onTap: () => _pages.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: const Icon(Icons.tune),
                  semanticLabel: '경로 관리',
                  surfaceStyle: GlassSurfaceStyle.glass,
                  useOwnLayer: true,
                  settings: widget.settings,
                  onPressed: () => Navigator.of(context).push<void>(
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
          child: SizedBox(
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
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: i == 0
                        ? _buildExampleCard(context)
                        : JourneyResultCard(
                            route: const {},
                            places: '${route.from} → ${route.to}',
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
