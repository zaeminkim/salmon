import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../route_search/routesearch_screen.dart';

class RouteResultsScreen extends StatelessWidget {
  const RouteResultsScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.preferredBusNumber,
  });

  final KakaoSearchResult origin;
  final KakaoSearchResult destination;
  final String? preferredBusNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('경로 검색 결과'),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassGroupedSection(
              margin: EdgeInsets.zero,
              surfaceStyle: GlassSurfaceStyle.solid,
              children: [
                GlassListTile(
                  leading: const Icon(Icons.radio_button_checked),
                  title: Text(origin.name),
                  subtitle: const Text('출발지'),
                ),
                GlassListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(destination.name),
                  subtitle: const Text('목적지'),
                ),
                if (preferredBusNumber case final number?)
                  GlassListTile(
                    leading: const Icon(Icons.directions_bus_outlined),
                    title: Text(number),
                    subtitle: const Text('선호 광역버스'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('대중교통 경로 조회는 준비 중이에요.'),
          ],
        ),
      ),
    );
  }
}
