import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'journey_presentation.dart';
import 'journey_recommendation.dart';

class JourneyResultCard extends StatelessWidget {
  const JourneyResultCard({super.key, required this.route, this.onTap});

  final Map<String, dynamic> route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final summary = route['summary'] as Map?;
    final minutes =
        summary?['total_minutes'] ??
        route['total_time_minutes'] ??
        route['provider_total_minutes'];
    final transfers = summary?['transfer_count'] ?? route['transfer_count'];
    final fare = summary?['payment_won'] ?? route['payment_won'];
    final walkMeters = route['total_walk_meters'];
    final departure = journeyClock(summary?['departure_at']);
    final arrival = journeyClock(summary?['arrival_at']);
    final segments = journeySegments(route).toList();
    final walkingSegments = segments.where(
      (segment) =>
          const ['walk', 'transfer_walk'].contains(journeyMode(segment)),
    );
    final walkingMinutes =
        summary?['walking_minutes'] ??
        (walkingSegments.isNotEmpty &&
                walkingSegments.every(
                  (segment) => journeyMinutes(segment) != null,
                )
            ? walkingSegments.fold<num>(
                0,
                (sum, segment) => sum + journeyMinutes(segment)!,
              )
            : null);
    final timings = [
      if (departure != null) '$departure 출발',
      if (arrival != null) '$arrival 도착',
    ];
    final metrics = [
      if (walkingMinutes is num) '도보 ${walkingMinutes.round()}분',
      if (walkMeters is num) '${_formatNumber(walkMeters)}m',
      if (transfers is num) '환승 ${transfers.round()}회',
      if (fare is num) '${_formatNumber(fare)}원',
    ];
    final timedSegments = segments
        .where((segment) => (journeyMinutes(segment) ?? 0) > 0)
        .toList();
    final transitSegments = segments.where(
      (segment) => const ['bus', 'subway'].contains(journeyMode(segment)),
    );

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3E0DE)),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      minutes is num ? '${minutes.round()}분' : '소요 시간 미제공',
                      style: const TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: Colors.black54),
                ],
              ),
              if (timings.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(timings.join(' – '), style: _secondary),
              ],
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(metrics.join(' · '), style: _secondary),
              ],
              JourneyRecommendation(route: route),
              if (timedSegments.isNotEmpty) ...[
                const SizedBox(height: 14),
                JourneyTimeBar(segments: timedSegments),
              ],
              for (final segment in transitSegments) ...[
                const SizedBox(height: 14),
                _TransitStops(segment: segment),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _secondary = TextStyle(color: Color(0xFF666A6E));

String _formatNumber(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

class JourneyTimeBar extends StatelessWidget {
  const JourneyTimeBar({super.key, required this.segments});

  final List<JourneySegment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<num>(
      0,
      (sum, segment) => sum + journeyMinutes(segment)!,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = MediaQuery.textScalerOf(context).scale(44);
        final extraWidth = math.max(
          0.0,
          constraints.maxWidth - minWidth * segments.length,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                for (final segment in segments)
                  Container(
                    color: journeySegmentColor(segment),
                    width:
                        minWidth +
                        extraWidth * journeyMinutes(segment)! / total,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    alignment: Alignment.center,
                    child: Text(
                      '${journeyMinutes(segment)!.round()}분',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel:
                          '${switch (journeyMode(segment)) {
                            'bus' => '버스',
                            'subway' => '지하철',
                            'wait' => '대기',
                            _ => '도보',
                          }} ${journeyMinutes(segment)!.round()}분',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            journeySegmentColor(segment).computeLuminance() >
                                0.45
                            ? const Color(0xFF292D32)
                            : Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransitStops extends StatelessWidget {
  const _TransitStops({required this.segment});

  final JourneySegment segment;

  @override
  Widget build(BuildContext context) {
    final start = journeyStationName(
      segment['boarding_station'],
      segment['start_stop_name'],
    );
    final end = journeyStationName(
      segment['alighting_station'],
      segment['end_stop_name'],
    );
    final route = segment['route_name'];
    final time = journeyClock(segment['estimated_boarding_at']);
    final prediction = segment['seat_prediction'] as Map?;
    final seats = prediction?['estimated_remaining_seats'];
    final predictionStatus = journeySeatStatus(prediction?['status']);
    final routeInfo = [
      if (route is String && route.isNotEmpty) route,
      if (time != null) '$time 예상',
    ];
    final isBus = journeyMode(segment) == 'bus';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isBus ? Icons.directions_bus_outlined : Icons.subway_outlined,
          color: journeySegmentColor(segment),
          size: 21,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              if (start != null)
                Text(
                  start,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (routeInfo.isNotEmpty ||
                  seats is num ||
                  predictionStatus != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (routeInfo.isNotEmpty)
                      Text(routeInfo.join(' · '), style: _secondary),
                    if (seats is num)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF4ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            '예상 잔여 ${seats.round()}석',
                            style: const TextStyle(color: Color(0xFF386044)),
                          ),
                        ),
                      )
                    else if (predictionStatus != null)
                      Text(predictionStatus, style: _secondary),
                  ],
                ),
              if (end != null) Text('→ $end 하차', style: _secondary),
            ],
          ),
        ),
      ],
    );
  }
}
