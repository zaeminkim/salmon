import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../data/journeys/journey_example_api.dart';
import '../core/journey_presentation.dart';
import '../core/widgets/journey_result_card.dart';
import '../route_search/routesearch_screen.dart';
import 'journey_preview_map.dart';
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
  late final _client = widget.journeyClient ?? _createClient();
  late Future<Map<String, dynamic>> _request = _search();
  String _filter = 'all';

  Dio _createClient() {
    final client = Dio(
      BaseOptions(
        baseUrl: 'https://geoseulleong-06469e76bb18.herokuapp.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 45),
      ),
    );
    if (_usingExample) client.interceptors.add(JourneyExampleApi());
    return client;
  }

  Future<Map<String, dynamic>> _search() async {
    Map<String, Object> coordinates(KakaoSearchResult place) => {
      'latitude': place.latitude,
      'longitude': place.longitude,
      if (place.name.runes.length <= 80) 'name': place.name,
    };
    final bus = widget.preferredBusNumber?.trim() ?? '';
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/journeys/search',
      data: {
        'origin': coordinates(widget.origin),
        'destination': coordinates(widget.destination),
        if (bus.isNotEmpty) 'preferred_express_bus': bus,
      },
      cancelToken: _cancelToken,
    );
    final data = response.data;
    if (data == null || data['candidates'] is! List) {
      throw const FormatException('Missing journey candidates');
    }
    return data;
  }

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
        : _resultFilters(data, candidates);
    final selected = filters
        .where((filter) => filter['key'] == _filter)
        .firstOrNull;
    final results = selected == null
        ? candidates
        : candidates.where((route) => _matchesFilter(route, selected)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text('경로추천'),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '좌석 여유와 이동 시간을 고려하는 추천 경로예요.',
                    style: TextStyle(color: Colors.white),
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
                      ChoiceChip(
                        label: Text(
                          '${filter['label']} ${filter['count'] ?? candidates.where((route) => _matchesFilter(route, filter)).length}',
                        ),
                        selected: _filter == filter['key'],
                        selectedColor: const Color(0xFFFBE6E1),
                        showCheckmark: false,
                        onSelected: (_) =>
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

  List<Map<String, dynamic>> _resultFilters(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> candidates,
  ) {
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

    final bus = widget.preferredBusNumber?.trim() ?? '';
    if (bus.isEmpty) return filters;

    final display = widget.preferredBusLabel?.trim();
    final busLabel = display == null || display.isEmpty ? bus : display;
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

  bool _matchesFilter(Map<String, dynamic> route, Map<String, dynamic> filter) {
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
        onTap: () {
          final data = snapshot.requireData;
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => RouteDetailScreen(
                route: results[index],
                candidates: candidates,
                searchId: data['search_id'],
                origin: _detailPlace(data['origin'], widget.origin),
                destination: _detailPlace(
                  data['destination'],
                  widget.destination,
                ),
              ),
            ),
          );
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
