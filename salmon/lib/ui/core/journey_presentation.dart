import 'dart:ui';

typedef JourneySegment = Map<String, dynamic>;

Iterable<JourneySegment> journeySegments(Map<String, dynamic> route) {
  final segments = route['segments'] ?? route['legs'];
  return segments is List ? segments.whereType<JourneySegment>() : const [];
}

String? journeyMode(JourneySegment segment) =>
    (segment['type'] ?? segment['mode']) as String?;

num? journeyMinutes(JourneySegment segment) =>
    (segment['duration_minutes'] ?? segment['section_time_minutes']) as num?;

String? journeyStationName(Object? station, Object? fallback) {
  final name = station is Map ? station['name'] ?? fallback : fallback;
  if (name is! String || name.isEmpty) return null;
  final arsId = station is Map ? station['ars_id'] : null;
  return arsId is String && arsId.isNotEmpty ? '$name ($arsId)' : name;
}

String? journeyLowSeatChance(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) return null;
  final percent = (value * 100)
      .toStringAsFixed(1)
      .replaceFirst(RegExp(r'\.0$'), '');
  return '잔여 5석 이하 확률 $percent%';
}

String? journeySeatStatus(Object? status) => switch (status) {
  'available' => '예측 가능',
  'unavailable' => '좌석 예측 불가',
  'not_applicable' => '좌석 예측 대상 아님',
  _ => null,
};

String? journeyClock(Object? value) {
  final time = value is String ? DateTime.tryParse(value) : null;
  if (time == null) return null;
  final koreaTime = time.toUtc().add(const Duration(hours: 9));
  return '${koreaTime.hour.toString().padLeft(2, '0')}:${koreaTime.minute.toString().padLeft(2, '0')}';
}

Color journeySegmentColor(JourneySegment segment) {
  final hex = segment['route_color'];
  if (hex is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
    return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }
  return switch (journeyMode(segment)) {
    'bus' => const Color(0xFFB65B48),
    'subway' => const Color(0xFF697454),
    _ => const Color(0xFFF0EFEE),
  };
}
