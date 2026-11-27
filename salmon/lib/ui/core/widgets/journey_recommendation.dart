import 'package:flutter/material.dart';

import '../journey_presentation.dart';

class JourneyRecommendation extends StatelessWidget {
  const JourneyRecommendation({super.key, required this.route});

  final Map<String, dynamic> route;

  @override
  Widget build(BuildContext context) {
    final rank = route['recommendation_rank'];
    final providerRank = route['provider_rank'];
    final reason = route['recommendation_reason'];
    final seats = route['min_remaining_seats'];
    final risk = switch (route['seat_risk_status']) {
      'low' => '좌석 부족 위험 낮음',
      'high' => '좌석 부족 위험 높음',
      final status => journeySeatStatus(status),
    };
    final ranking = [
      if (rank is num) '추천 ${rank.round()}위',
      if (providerRank is num) 'ODsay ${providerRank.round()}위',
    ];
    final seatInfo = [
      ?risk,
      if (seats is num) '최소 예상 잔여 ${seats.round()}석',
      ?journeyLowSeatChance(route['max_low_seat_probability']),
    ];
    final hasReason = reason is String && reason.trim().isNotEmpty;
    if (ranking.isEmpty && !hasReason && seatInfo.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          if (ranking.isNotEmpty)
            Text(
              ranking.join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (hasReason) Text(reason),
          if (seatInfo.isNotEmpty)
            Text(
              seatInfo.join(' · '),
              style: TextStyle(
                color: switch (route['seat_risk_status']) {
                  'high' => const Color(0xFF9A3627),
                  'low' => const Color(0xFF386044),
                  _ => const Color(0xFF666A6E),
                },
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}
