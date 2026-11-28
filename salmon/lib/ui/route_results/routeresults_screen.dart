import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:salmon/ui/core/widgets/app_map_icon_button.dart';
import 'package:salmon/ui/core/widgets/chip_button.dart';

import '../../data/journeys/journey_search_api.dart';
import '../../data/places/kakao_search_result.dart';
import '../core/widgets/journey_map_geometry.dart';
import '../core/widgets/journey_result_card.dart';
import 'journey_result_filters.dart';
import 'route_detail_screen.dart';

const _brand = Color(0xFFD9553E);

class RouteResultsScreen extends StatefulWidget {
  const RouteResultsScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.preferredBusNumber,
    this.preferredBusLabel,
    this.journeyClient,
  });

  final KakaoSearchResult origin;
  final KakaoSearchResult destination;
  final String? preferredBusNumber;
  final String? preferredBusLabel;
  final Dio? journeyClient;

  @override
  State<RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends State<RouteResultsScreen> {
  static const _showSwaggerExample = bool.fromEnvironment(
    'JOURNEY_USE_MOCK',
    defaultValue: kDebugMode,
  );
  final _cancelToken = CancelToken();
  bool get _usingExample => _showSwaggerExample && widget.journeyClient == null;
  late final _client =
      widget.journeyClient ??
      createJourneySearchClient(useExample: _usingExample);
  late Future<Map<String, dynamic>> _request = _search();
  String _filter = 'all';

  Future<Map<String, dynamic>> _search() => searchJourneys(
    _client,
    origin: widget.origin,
    destination: widget.destination,
    preferredBusNumber: widget.preferredBusNumber,
    cancelToken: _cancelToken,
  );

  @override
  void dispose() {
    _cancelToken.cancel();
    if (widget.journeyClient == null) _client.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _request,
    builder: _buildResults,
  );

  Widget _buildResults(
    BuildContext context,
    AsyncSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data;
    final origin = data?['origin'];
    final destination = data?['destination'];
    final originName = origin is Map && origin['name'] is String
        ? origin['name'] as String
        : widget.origin.name;
    final destinationName = destination is Map && destination['name'] is String
        ? destination['name'] as String
        : widget.destination.name;
    final candidates = ((data?['candidates'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final filters = data == null
        ? const <Map<String, dynamic>>[]
        : journeyResultFilters(
            data,
            candidates,
            preferredBusNumber: widget.preferredBusNumber,
            preferredBusLabel: widget.preferredBusLabel,
          );
    final selected = filters
        .where((filter) => filter['key'] == _filter)
        .firstOrNull;
    final results = selected == null
        ? candidates
        : candidates
              .where((route) => journeyMatchesFilter(route, selected))
              .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '경로 추천',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_usingExample) const Center(child: Text('Swagger 예시')),
          CloseButton(onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _brand,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '출발  $originName   →   도착  $destinationName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '거슬렁 추천순',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '좌석 여유와 이동 시간을 고려한 추천 경로예요.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final filter in filters)
                      ChipButton(
                        settings: appMapGlassSettings,
                        label:
                            '${filter['label']} ${filter['count'] ?? candidates.where((route) => journeyMatchesFilter(route, filter)).length}',
                        selected: _filter == filter['key'],
                        onTap: () =>
                            setState(() => _filter = filter['key'] as String),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildCards(snapshot, results, candidates)),
          ],
        ),
      ),
    );
  }

  Widget _buildCards(
    AsyncSnapshot<Map<String, dynamic>> snapshot,
    List<Map<String, dynamic>> results,
    List<Map<String, dynamic>> candidates,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('경로를 불러오지 못했어요.'),
            TextButton(
              onPressed: () => setState(() {
                _filter = 'all';
                _request = _search();
              }),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(child: Text('표시할 경로가 없어요.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: results.length,
      itemBuilder: (context, index) => JourneyResultCard(
        route: results[index],
        onTap: () async {
          final data = snapshot.requireData;
          final finished = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => RouteDetailScreen(
                route: results[index],
                candidates: candidates,
                searchId: data['search_id'],
                journeyClient: _usingExample ? null : _client,
                origin: _detailPlace(data['origin'], widget.origin),
                destination: _detailPlace(
                  data['destination'],
                  widget.destination,
                ),
              ),
            ),
          );
          if (finished == true && mounted) {
            Navigator.pop(this.context, true);
          }
        },
      ),
    );
  }

  JourneyPlace _detailPlace(Object? value, KakaoSearchResult fallback) {
    final place = value is Map ? value : null;
    final name = place?['name'];
    return (
      name: name is String && name.isNotEmpty ? name : fallback.name,
      position:
          journeyPosition(place) ??
          LatLng(fallback.latitude, fallback.longitude),
    );
  }
}
