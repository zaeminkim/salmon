import '../core/widgets/journey_presentation.dart';

List<Map<String, dynamic>> journeyResultFilters(
  Map<String, dynamic> data,
  List<Map<String, dynamic>> candidates, {
  required String? preferredBusNumber,
  required String? preferredBusLabel,
}) {
  const preferredKey = 'preferred_express_bus';
  final responseFilters = ((data['filters'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>();
  final filters = [
    for (final filter in responseFilters)
      if (filter['key'] is String &&
          filter['label'] is String &&
          filter['key'] != preferredKey)
        filter,
  ];
  if (filters.isEmpty) {
    filters.addAll([
      {'key': 'all', 'label': '전체'},
      {'key': 'bus', 'label': '버스'},
      {'key': 'subway', 'label': '지하철'},
      {'key': 'mixed', 'label': '버스 + 지하철'},
    ]);
  }

  final bus = preferredBusNumber?.trim() ?? '';
  if (bus.isEmpty) return filters;

  final display = preferredBusLabel?.trim();
  final busLabel = display == null || display.isEmpty ? bus : display;
  // 저장된 예시 응답의 버스 번호가 현재 선택과 다를 수 있습니다.
  final responseBus = (data['query'] as Map?)?[preferredKey];
  final sameRequest =
      responseBus is! String ||
      responseBus.trim().toUpperCase() == bus.toUpperCase();
  final responseFilter = responseFilters
      .where((filter) => filter['key'] == preferredKey)
      .firstOrNull;
  filters.insert(1, {
    if (sameRequest && responseFilter != null)
      ...responseFilter
    else
      'candidate_ids': [
        for (final route in candidates)
          if (journeySegments(route).any(
            (segment) =>
                journeyMode(segment) == 'bus' &&
                (segment['route_id']?.toString() == bus ||
                    segment['route_name']?.toString().trim().toUpperCase() ==
                        busLabel.toUpperCase()),
          ))
            route['candidate_id'],
      ],
    'key': preferredKey,
    'label': '$busLabel 이용',
  });
  return filters;
}

bool journeyMatchesFilter(
  Map<String, dynamic> route,
  Map<String, dynamic> filter,
) {
  final key = filter['key'];
  if (key == 'all') return true;
  final ids = filter['candidate_ids'];
  if (ids is List) return ids.contains(route['candidate_id']);
  final modes = journeySegments(route).map(journeyMode).toSet();
  final bus = modes.contains('bus');
  final subway = modes.contains('subway');
  return switch (key) {
    'bus' => bus && !subway,
    'subway' => subway && !bus,
    'mixed' => bus && subway,
    'preferred_express_bus' => route['uses_preferred_express_bus'] == true,
    _ => false,
  };
}
