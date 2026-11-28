import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/widgets/journey_presentation.dart';
import 'saved_route_segments.dart';

class SavedRouteCard extends StatelessWidget {
  const SavedRouteCard({
    super.key,
    required this.title,
    this.places,
    this.route,
    this.onTap,
  });

  final String title;
  final String? places;
  final Map<String, dynamic>? route;
  final VoidCallback? onTap;

  static const _ink = Color(0xFF292F36);
  static const _muted = Color(0xFF656C72);

  @override
  Widget build(BuildContext context) {
    final summary = route?['summary'] as Map?;
    final duration =
        summary?['total_minutes'] ??
        route?['total_time_minutes'] ??
        route?['provider_total_minutes'];
    final arrival = journeyClock(summary?['arrival_at']);
    final segments = route == null
        ? const <JourneySegment>[]
        : journeySegments(route!);
    final seats = _remainingSeats(segments);
    final timed = [
      for (final segment in segments)
        if (journeyMinutes(segment) case final minutes?
            when minutes.isFinite && minutes > 0)
          (segment: segment, minutes: minutes),
    ];
    final stops = savedRouteStops(segments);

    return Card(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      color: const Color(0xFFFEFEFD),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3E0DE)),
      ),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale;
            final titleHeight = scale(18) * 1.25;
            final factsHeight = math.max(
              scale(32) * 1.15,
              scale(13) * 1.25 + 10,
            );
            final barHeight = math.max(24.0, scale(11) * 1.2 + 6);
            final stopHeight = scale(14) * 1.25 + 6;
            final contentHeight = constraints.maxHeight - 28;
            final factsEnd = titleHeight + 8 + factsHeight;
            final showFacts = route != null && contentHeight >= factsEnd;
            final showBar =
                showFacts &&
                timed.isNotEmpty &&
                contentHeight >= factsEnd + 10 + barHeight;
            final overviewHeight = factsEnd + (showBar ? 10 + barHeight : 0);
            // 지도와 카드가 공간을 나눠 쓰는 화면에서는 승하차 목록을 줄입니다.
            final visibleStops =
                ((contentHeight - overviewHeight - 19) / stopHeight)
                    .floor()
                    .clamp(0, 3);
            final subtitle =
                route == null &&
                places != null &&
                contentHeight >= titleHeight + 6 + scale(13) * 1.25;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.maxHeight >= titleHeight)
                    SizedBox(
                      height: titleHeight,
                      child: Text(
                        places ?? title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (subtitle) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '경로 정보 준비 중',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (showFacts) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: factsHeight,
                      child: _overview(
                        duration,
                        arrival,
                        seats,
                        badgeWidth:
                            math.max(0.0, constraints.maxWidth - 32) * 0.44,
                      ),
                    ),
                  ],
                  if (showBar) ...[
                    const SizedBox(height: 10),
                    SavedRouteTimeBar(segments: timed, height: barHeight),
                  ],
                  if (showFacts && visibleStops > 0 && stops.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFECEBE8),
                    ),
                    const SizedBox(height: 6),
                    SavedRouteTimeline(
                      stops: stops.take(visibleStops).toList(),
                      rowHeight: stopHeight,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _overview(
    Object? duration,
    String? arrival,
    num? seats, {
    required double badgeWidth,
  }) {
    final hasDuration = duration is num && duration.isFinite && duration >= 0;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  hasDuration ? '${duration.round()}분' : '소요시간 정보 없음',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: hasDuration ? 32 : 13,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (arrival != null)
                Flexible(
                  child: Text(
                    '· $arrival 도착',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: badgeWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: seats == null
                  ? const Color(0xFFF0EFEE)
                  : const Color(0xFFFAF1DA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                seats == null ? '잔여석 정보 없음' : '잔여 ${seats.round()}석',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: seats == null ? _muted : const Color(0xFF8A5D12),
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  num? _remainingSeats(Iterable<JourneySegment> segments) {
    final minimum = route?['min_remaining_seats'];
    if (minimum is num && minimum.isFinite && minimum >= 0) return minimum;
    num? estimatedMinimum;
    for (final segment in segments) {
      final prediction = segment['seat_prediction'];
      if (prediction is! Map) continue;
      final seats = prediction['estimated_remaining_seats'];
      if (seats is! num || !seats.isFinite || seats < 0) continue;
      estimatedMinimum = estimatedMinimum == null
          ? seats
          : math.min(estimatedMinimum, seats);
    }
    return estimatedMinimum;
  }
}
