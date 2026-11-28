import 'package:flutter/material.dart';

import 'journey_presentation.dart';

class JourneyRecommendation extends StatelessWidget {
  const JourneyRecommendation({super.key, required this.route});

  final Map<String, dynamic> route;

  @override
  Widget build(BuildContext context) {
    final rank = route['recommendation_rank'];
    final providerRank = route['provider_rank'];
    final reason = route['recommendation_reason'];
    final seats = route['min_remaining_seats'];
    final probability = journeyLowSeatChance(route['max_low_seat_probability']);
    final status = route['seat_risk_status'];
    final (risk, foreground, background, icon) = switch (status) {
      'low' => (
        '좌석 부족 위험 낮음',
        const Color(0xFF31583D),
        const Color(0xFFEAF3EB),
        Icons.event_seat_outlined,
      ),
      'high' => (
        '좌석 부족 위험 높음',
        const Color(0xFF853726),
        const Color(0xFFFCEDE7),
        Icons.error_outline,
      ),
      _ => (
        journeySeatStatus(status),
        const Color(0xFF555C63),
        const Color(0xFFF2F3F3),
        Icons.info_outline,
      ),
    };
    final ranking = [
      if (rank is num) '추천 ${rank.round()}위',
      if (providerRank is num) 'ODsay ${providerRank.round()}위',
    ];
    final hasReason = reason is String && reason.trim().isNotEmpty;
    final hasMetrics = seats is num || probability != null;
    if (ranking.isEmpty && !hasReason && !hasMetrics && risk == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          if (ranking.isNotEmpty)
            Text(
              ranking.join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (hasReason || hasMetrics || risk != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: foreground),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            risk ?? '좌석 예측',
                            style: TextStyle(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (hasReason || hasMetrics)
                          TextButton(
                            onPressed: () => _showEvidence(
                              context,
                              hasReason ? reason : null,
                              hasMetrics,
                            ),
                            child: const Text('예측 근거'),
                          ),
                      ],
                    ),
                    if (hasMetrics)
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          if (seats is num)
                            Text(
                              '최소 예상 잔여 ${seats.round()}석',
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (probability != null)
                            Text(
                              probability,
                              style: TextStyle(color: foreground),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showEvidence(
    BuildContext context,
    String? reason,
    bool hasMetrics,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('좌석 예측 근거', style: Theme.of(context).textTheme.titleLarge),
            if (reason != null) Text(reason),
            if (hasMetrics)
              const Text(
                '최소 예상 잔여석은 경로 내 좌석을 예측한 구간 중 가장 적은 예상 좌석 수예요. '
                '잔여 5석 이하 확률은 그런 구간 중 가장 높은 확률이에요. '
                '실제 도착한 차량의 잔여석은 달라질 수 있어요.',
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
