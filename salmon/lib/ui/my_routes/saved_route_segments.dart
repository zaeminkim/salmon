import 'package:flutter/material.dart';

import '../core/widgets/journey_presentation.dart';

typedef SavedRouteStop = ({String label, String? time, Color color});

bool _isTransit(JourneySegment segment) => switch (journeyMode(segment)) {
  'bus' || 'subway' => true,
  _ => false,
};

Color _routeColor(JourneySegment segment) =>
    Color.lerp(journeySegmentColor(segment), const Color(0xFF9E9784), 0.35)!;

String _segmentLabel(JourneySegment segment) {
  final name = segment['route_name'];
  final label = name is String && name.trim().isNotEmpty ? name.trim() : null;
  return switch (journeyMode(segment)) {
    'walk' || 'transfer_walk' => '도보',
    'bus' => label == null ? '버스' : '$label 버스',
    'subway' => label ?? '지하철',
    'wait' => '대기',
    _ => label ?? '이동',
  };
}

List<SavedRouteStop> savedRouteStops(Iterable<JourneySegment> segments) {
  final stops = <SavedRouteStop>[];
  JourneySegment? previousTransit;
  num walking = 0;
  for (final segment in segments) {
    final mode = journeyMode(segment);
    if (!_isTransit(segment)) {
      final minutes = journeyMinutes(segment);
      if (previousTransit != null &&
          (mode == 'walk' || mode == 'transfer_walk') &&
          minutes != null &&
          minutes.isFinite &&
          minutes > 0) {
        walking += minutes;
      }
      continue;
    }
    final color = _routeColor(segment);
    final station = _stopName(
      segment['boarding_station'],
      segment['start_stop_name'],
    );
    if (previousTransit != null) {
      final previousStop = _stopName(
        previousTransit['alighting_station'],
        previousTransit['end_stop_name'],
      );
      stops.add((
        label: [
          if (station ?? previousStop case final name?) '$name 환승' else '환승',
          if (walking > 0) '도보 ${walking.round()}분',
        ].join(' · '),
        time: null,
        color: color,
      ));
    }
    stops.add((
      label: '${station ?? _segmentLabel(segment)} 승차',
      time: journeyClock(
        segment['estimated_boarding_at'] ?? segment['estimated_start_at'],
      ),
      color: color,
    ));
    previousTransit = segment;
    walking = 0;
  }

  if (previousTransit case final last?) {
    final station = _stopName(last['alighting_station'], last['end_stop_name']);
    if (station != null) {
      stops.add((
        label: '$station 하차',
        time: journeyClock(
          last['estimated_alighting_at'] ?? last['estimated_end_at'],
        ),
        color: _routeColor(last),
      ));
    }
  }
  return stops;
}

String? _stopName(Object? station, Object? fallback) => journeyStationName(
  null,
  station is Map ? station['name'] ?? fallback : fallback,
);

class SavedRouteTimeBar extends StatelessWidget {
  const SavedRouteTimeBar({
    super.key,
    required this.segments,
    required this.height,
  });

  final List<({JourneySegment segment, num minutes})> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<num>(0, (sum, entry) => sum + entry.minutes);
    return Semantics(
      label: segments
          .map(
            (entry) =>
                '${_segmentLabel(entry.segment)} ${entry.minutes.round()}분',
          )
          .join(', '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: ColoredBox(
          color: const Color(0xFFF0EFEE),
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in segments)
                  Expanded(
                    flex: (entry.minutes / total * 1000).round().clamp(1, 1000),
                    child: _TimeSegment(
                      segment: entry.segment,
                      minutes: '${entry.minutes.round()}분',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSegment extends StatelessWidget {
  const _TimeSegment({required this.segment, required this.minutes});

  final JourneySegment segment;
  final String minutes;

  @override
  Widget build(BuildContext context) {
    final transit = _isTransit(segment);
    final color = transit ? _routeColor(segment) : const Color(0xFFF0EFEE);
    final labelColor = transit && color.computeLuminance() < 0.24
        ? Colors.white
        : const Color(0xFF454A50);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth =
            MediaQuery.textScalerOf(context).scale(11) *
            (minutes.length * 0.65 + 0.8);
        final hasText = constraints.maxWidth >= textWidth;
        final hasIcon = transit && constraints.maxWidth >= 24;
        final hasBoth = hasIcon && constraints.maxWidth >= 24 + textWidth;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: hasBoth
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (hasIcon)
                Padding(
                  padding: EdgeInsets.only(left: hasBoth ? 4 : 0),
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.white,
                    child: Icon(
                      journeyMode(segment) == 'bus'
                          ? Icons.directions_bus_rounded
                          : Icons.directions_subway_rounded,
                      color: color,
                      size: 12,
                    ),
                  ),
                ),
              if (hasText && (!hasIcon || hasBoth))
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(right: hasBoth ? 6 : 0),
                    child: Text(
                      minutes,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SavedRouteTimeline extends StatelessWidget {
  const SavedRouteTimeline({
    super.key,
    required this.stops,
    required this.rowHeight,
  });

  final List<SavedRouteStop> stops;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF292F36);
    return Stack(
      children: [
        if (stops.length > 1)
          PositionedDirectional(
            start: 4,
            top: rowHeight / 2,
            bottom: rowHeight / 2,
            child: const SizedBox(
              width: 2,
              child: ColoredBox(color: Color(0xFFE4E2DE)),
            ),
          ),
        Column(
          children: [
            for (final stop in stops)
              SizedBox(
                height: rowHeight,
                child: Row(
                  spacing: 10,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: stop.color,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 10),
                    ),
                    if (stop.time case final time?)
                      Text(
                        time,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        stop.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: stop.time == null
                              ? const Color(0xFF656C72)
                              : ink,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
