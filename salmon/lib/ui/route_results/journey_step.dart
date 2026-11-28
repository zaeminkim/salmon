import 'package:flutter/material.dart';

import '../core/widgets/journey_presentation.dart';

/// 경로 한 구간의 정류장과 좌석 정보를 표시합니다.
class JourneyStep extends StatelessWidget {
  const JourneyStep({super.key, required this.segment});

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
