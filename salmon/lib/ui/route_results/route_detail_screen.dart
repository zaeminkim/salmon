import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../data/journeys/journey_example_api.dart';
import '../core/journey_presentation.dart';
import '../core/widgets/app_primary_button.dart';
import '../core/widgets/journey_recommendation.dart';
import 'journey_preview_map.dart';
import 'route_guidance_screen.dart';

typedef JourneyPlace = ({String name, LatLng position});

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.route,
    required this.origin,
    required this.destination,
    this.searchId,
    this.candidates = const [],
  });

  final Map<String, dynamic> route;
  final JourneyPlace origin;
  final JourneyPlace destination;
  final Object? searchId;
  final List<Map<String, dynamic>> candidates;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  late final _detail = loadJourneyExampleDetail(
    searchId: widget.searchId,
    candidateId: widget.route['candidate_id'],
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _detail,
    builder: (context, snapshot) {
      final detail = snapshot.data;
      final candidate = detail?['candidate'];
      return _buildDetail(
        context,
        route: candidate is Map<String, dynamic>
            ? {...widget.route, ...candidate}
            : widget.route,
        loading: snapshot.connectionState != ConnectionState.done,
        detail: detail,
      );
    },
  );

  Widget _buildDetail(
    BuildContext context, {
    required Map<String, dynamic> route,
    required bool loading,
    required Map<String, dynamic>? detail,
  }) {
    final origin = widget.origin;
    final destination = widget.destination;
    final attributions = detail?['attributions'];
    final sources = [
      if (attributions is List)
        for (final entry in attributions.whereType<Map>())
          if (entry['attribution'] case final String label) label,
    ];
    final summary = route['summary'] as Map?;
    final minutes =
        summary?['total_minutes'] ??
        route['total_time_minutes'] ??
        route['provider_total_minutes'];
    final transfers = summary?['transfer_count'] ?? route['transfer_count'];
    final arrival = journeyClock(summary?['arrival_at']);
    final departure = journeyClock(summary?['departure_at']);
    final segments = journeySegments(route).toList();
    final walkingMinutes = segments
        .where(
          (segment) =>
              const ['walk', 'transfer_walk'].contains(journeyMode(segment)),
        )
        .map(journeyMinutes)
        .nonNulls
        .fold<num>(0, (total, minutes) => total + minutes);
    final metrics = [
      if (arrival != null) '$arrival 도착',
      if (transfers is num) '환승 ${transfers.round()}회',
      if (walkingMinutes > 0) '도보 ${walkingMinutes.round()}분',
    ];
    final times = [
      if (departure != null) '$departure 출발',
      if (arrival != null) '$arrival 도착',
    ];
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('경로 상세'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: AppPrimaryButton(
          label: '경로 안내',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RouteGuidanceScreen(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              '${origin.name} → ${destination.name}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (minutes is num)
              Text(
                '총 ${minutes.round()}분',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (metrics.isNotEmpty)
              Text(
                metrics.join(' · '),
                style: const TextStyle(color: Colors.black54),
              ),
            JourneyRecommendation(route: route),
            const SizedBox(height: 18),
            if (loading)
              const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              JourneyPreviewMap(
                origin: journeyPosition(detail?['origin']) ?? origin.position,
                destination:
                    journeyPosition(detail?['destination']) ??
                    destination.position,
                segments: segments,
              ),
            if (sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  sources.join(' · '),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              '상세 이동 여정',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (times.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(times.join(' → ')),
              ),
            const SizedBox(height: 12),
            if (segments.isEmpty) const Text('구간별 이동 정보가 없어요.'),
            for (final segment in segments) _JourneyStep(segment: segment),
            ..._relatedRoutes(context, route),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _relatedRoutes(
    BuildContext context,
    Map<String, dynamic> route,
  ) sync* {
    final alternatives = route['alternative_candidate_ids'];
    final originals = route['alternative_for'];
    for (final (heading, ids) in [
      (
        '대체 경로',
        alternatives is List
            ? alternatives.whereType<String>().toSet()
            : <String>{},
      ),
      (
        '이 경로가 대체하는 후보',
        originals is List
            ? originals
                  .whereType<Map>()
                  .map((item) => item['original_candidate_id'])
                  .whereType<String>()
                  .toSet()
            : <String>{},
      ),
    ]) {
      final matches = widget.candidates
          .where(
            (candidate) =>
                candidate['candidate_id'] != route['candidate_id'] &&
                ids.contains(candidate['candidate_id']),
          )
          .toList();
      if (matches.isEmpty) continue;
      yield const SizedBox(height: 20);
      yield Text(heading, style: Theme.of(context).textTheme.titleMedium);
      for (final candidate in matches) {
        final rank = candidate['recommendation_rank'];
        final minutes =
            (candidate['summary'] as Map?)?['total_minutes'] ??
            candidate['provider_total_minutes'];
        final title = [
          if (rank is num) '추천 ${rank.round()}위',
          if (minutes is num) '${minutes.round()}분',
        ].join(' · ');
        final comparison = heading == '대체 경로'
            ? _alternativeComparison(candidate, route['candidate_id'])
            : null;
        yield ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title.isEmpty ? '경로 상세 보기' : title),
          subtitle: comparison == null ? null : Text(comparison),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => RouteDetailScreen(
                route: candidate,
                searchId: widget.searchId,
                origin: widget.origin,
                destination: widget.destination,
                candidates: widget.candidates,
              ),
            ),
          ),
        );
      }
    }
  }

  String? _alternativeComparison(
    Map<String, dynamic> candidate,
    Object? originalId,
  ) {
    final relations = candidate['alternative_for'];
    if (relations is! List) return null;
    final relation = relations
        .whereType<Map>()
        .where((relation) => relation['original_candidate_id'] == originalId)
        .firstOrNull;
    final minutes = relation?['additional_travel_minutes'];
    final reduction = relation?['low_seat_reduction_pp'];
    final changes = [
      if (minutes is num && minutes < 0) '${minutes.abs().round()}분 단축',
      if (minutes is num && minutes > 0) '${minutes.round()}분 추가',
      if (minutes == 0) '소요 시간 동일',
      if (reduction is num && reduction > 0)
        '잔여 5석 이하 확률 ${reduction.toStringAsFixed(1)}%p 감소',
    ];
    return changes.isEmpty ? null : changes.join(' · ');
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({required this.segment});

  final JourneySegment segment;

  @override
  Widget build(BuildContext context) {
    final mode = journeyMode(segment);
    final (label, icon) = switch (mode) {
      'bus' => ('버스', Icons.directions_bus_outlined),
      'subway' => ('지하철', Icons.subway_outlined),
      'walk' => ('도보', Icons.directions_walk),
      'transfer_walk' => ('환승 도보', Icons.directions_walk),
      'wait' => ('대기', Icons.schedule),
      _ => ('이동', Icons.route_outlined),
    };
    final isTransit = mode == 'bus' || mode == 'subway';
    final color = isTransit
        ? journeySegmentColor(segment)
        : const Color(0xFF666A6E);
    final boarding = journeyStationName(
      segment['boarding_station'],
      segment['start_stop_name'],
    );
    final alighting = journeyStationName(
      segment['alighting_station'],
      segment['end_stop_name'],
    );
    final prediction = segment['seat_prediction'] as Map?;
    final seats = prediction?['estimated_remaining_seats'];
    final seatInfo = [
      if (seats is num)
        '예상 잔여 ${seats.round()}석'
      else
        ?journeySeatStatus(prediction?['status']),
      ?journeyLowSeatChance(prediction?['low_seat_probability']),
    ];
    final minutes = journeyMinutes(segment);
    final distance = segment['distance_meters'];
    final routeName = segment['route_name'];
    final start = journeyClock(
      segment['estimated_start_at'] ?? segment['estimated_boarding_at'],
    );
    final end = journeyClock(
      segment['estimated_end_at'] ?? segment['estimated_alighting_at'],
    );
    final time = [?start, ?end].join('–');
    final stops = [
      if (boarding != null) isTransit ? '$boarding 승차' : boarding,
      if (alighting != null) isTransit ? '$alighting 하차' : alighting,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  [
                    if (time.isNotEmpty) time,
                    if (isTransit &&
                        routeName is String &&
                        routeName.isNotEmpty)
                      '$routeName $label'
                    else
                      label,
                    if (minutes != null) '${minutes.round()}분',
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (stops.isNotEmpty) Text(stops.join(' → ')),
                if (distance is num) Text('${distance.round()}m'),
                if (seatInfo.isNotEmpty)
                  Text(
                    seatInfo.join(' · '),
                    style: TextStyle(
                      color: seats is num
                          ? const Color(0xFF386044)
                          : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
