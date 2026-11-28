import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../data/journeys/journey_example_api.dart';
import '../../data/journeys/journey_search_api.dart';
import '../core/widgets/journey_map_geometry.dart';
import '../core/widgets/journey_presentation.dart';
import '../core/widgets/app_primary_button.dart';
import '../core/widgets/app_map_icon_button.dart';
import '../core/widgets/journey_recommendation.dart';
import '../core/widgets/journey_result_card.dart';
import '../my_routes/map_location_tracker.dart';
import 'journey_progress.dart';
import 'journey_preview_map.dart';
import 'journey_step.dart';

typedef JourneyPlace = ({String name, LatLng position});

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.route,
    required this.origin,
    required this.destination,
    this.searchId,
    this.candidates = const [],
    this.journeyClient,
  });

  final Map<String, dynamic> route;
  final JourneyPlace origin;
  final JourneyPlace destination;
  final Object? searchId;
  final List<Map<String, dynamic>> candidates;
  final Dio? journeyClient;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen>
    with WidgetsBindingObserver {
  static const _initialSheetSize = 0.54;
  static const _minSheetSize = 0.31;
  static const _maxSheetSize = 0.80;
  static const _mapEdgeInset = 20.0;
  static const _mapButtonSize = 48.0;
  static const _mapButtonGap = 12.0;
  static const _mapButtonsHeight = 2 * _mapButtonSize + _mapButtonGap;
  static const _brand = Color(0xFFD9553E);
  final _sheet = DraggableScrollableController();
  late final _location = MapLocationTracker(
    onChanged: () {
      if (mounted) setState(() {});
    },
    onMessage: (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    },
    onPosition: _onPosition,
    followLocation: true,
  );
  KakaoMapController? _map;
  RouteCameraView? _routeCameraView;
  bool _movingRouteCamera = false;
  JourneyProgress? _progress;
  int? _activeSegment;
  bool _starting = false;
  bool _guiding = false;
  bool _resumeFollowing = false;
  bool _locationRequested = false;

  final _detailCancel = CancelToken();
  late final _detail = _loadDetail();

  Future<Map<String, dynamic>?> _loadDetail() async {
    final searchId = widget.searchId;
    final candidateId = widget.route['candidate_id'];
    if (searchId is! String || candidateId is! String) return null;
    final example = await loadJourneyExampleDetail(
      searchId: searchId,
      candidateId: candidateId,
    );
    final client = widget.journeyClient;
    if (example != null || client == null || _detailCancel.isCancelled) {
      return example;
    }
    return fetchJourneyDetail(
      client,
      searchId: searchId,
      candidateId: candidateId,
      cancelToken: _detailCancel,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_locationRequested) return;
    switch (state) {
      case AppLifecycleState.hidden:
        _resumeFollowing = _location.isSelected;
        _location.pause();
      case AppLifecycleState.resumed:
        _location.resume(follow: _resumeFollowing);
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detailCancel.cancel();
    _location.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _onPosition(geo.Position position) {
    if (!mounted || (!_starting && !_guiding)) return;
    final next = _progress?.match(position, _activeSegment);
    if (next != _activeSegment) setState(() => _activeSegment = next);
  }

  void _onMapReady(KakaoMapController controller) {
    if (!mounted) return;
    final follow = _location.isSelected || _resumeFollowing;
    _location.attach(controller);
    setState(() {
      _map = controller;
      _routeCameraView = null;
    });
    if (_locationRequested) _location.resume(follow: follow);
  }

  Future<bool> _recenter() {
    _clearRouteCameraSelection();
    _locationRequested = true;
    return _location.recenter();
  }

  void _clearRouteCameraSelection() {
    if (_routeCameraView != null) setState(() => _routeCameraView = null);
  }

  double _maxSheetExtent(BuildContext context, double height) {
    final appBarBottom = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final reservedHeight = appBarBottom + _mapButtonsHeight + _mapButtonGap;
    return (1 - reservedHeight / height).clamp(
      _initialSheetSize,
      _maxSheetSize,
    );
  }

  Future<void> _startGuidance(List<JourneySegment> segments) async {
    if (_starting ||
        _map == null ||
        _location.isLocating ||
        _movingRouteCamera) {
      return;
    }
    _progress = JourneyProgress(segments);
    setState(() => _starting = true);
    final located = await _recenter();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _guiding = located;
      _resumeFollowing = located;
      if (!located) _activeSegment = null;
    });
    if (!located) _location.stop();
  }

  Future<void> _moveCameraToRoute(LatLng origin, LatLng destination) async {
    final map = _map;
    if (map == null || _location.isLocating || _movingRouteCamera) return;
    final next = _routeCameraView?.next ?? RouteCameraView.overview;
    _location.clearSelection();
    _resumeFollowing = false;
    setState(() {
      _routeCameraView = next;
      _movingRouteCamera = true;
    });
    if (_sheet.isAttached && _sheet.size > _minSheetSize) {
      _sheet
          .animateTo(
            _minSheetSize,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
          .ignore();
    }
    try {
      await map.moveCamera(
        next.cameraUpdate(origin, destination),
        animation: const CameraAnimation(350),
      );
    } catch (error) {
      if (mounted && _map == map && _routeCameraView == next) {
        _clearRouteCameraSelection();
      }
      debugPrint('경로 위치로 지도 이동 실패: $error');
    } finally {
      if (mounted) setState(() => _movingRouteCamera = false);
    }
  }

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

    final timed = segments
        .where((step) => (journeyMinutes(step) ?? 0) > 0)
        .toList();
    final originPosition =
        journeyPosition(detail?['origin']) ?? origin.position;
    final destinationPosition =
        journeyPosition(detail?['destination']) ?? destination.position;
    final map = loading
        ? const Center(child: CircularProgressIndicator())
        : JourneyPreviewMap(
            origin: originPosition,
            destination: destinationPosition,
            segments: segments,
            interactive: true,
            onReady: _onMapReady,
            onCameraMoveStart: (gesture) {
              _location.onCameraMoveStart(gesture);
              if (gesture != GestureType.unknown) {
                _clearRouteCameraSelection();
              }
            },
          );

    return PopScope<bool>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _location.stop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: _mapEdgeInset + _mapButtonSize,
          leading: _guiding || _starting
              ? null
              : Center(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _mapEdgeInset,
                    ),
                    child: AppMapIconButton(
                      icon: Icons.arrow_back,
                      label: '뒤로 가기',
                      size: _mapButtonSize,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                // Size the native view for the lowest sheet position once.
                // Overscan above the viewport centers the default map opening.
                Positioned.fill(
                  top:
                      -constraints.maxHeight *
                      (_initialSheetSize - _minSheetSize),
                  bottom: constraints.maxHeight * _minSheetSize,
                  child: map,
                ),
                AnimatedBuilder(
                  animation: _sheet,
                  builder: (context, child) => Positioned(
                    right: _mapEdgeInset,
                    bottom:
                        _mapButtonGap +
                        constraints.maxHeight *
                            (_sheet.isAttached
                                ? _sheet.size
                                : _initialSheetSize),
                    child: child!,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: _mapButtonGap,
                    children: [
                      AppMapIconButton(
                        label: '전체 경로 보기',
                        size: _mapButtonSize,
                        onPressed:
                            _map == null ||
                                _location.isLocating ||
                                _movingRouteCamera
                            ? null
                            : () => _moveCameraToRoute(
                                originPosition,
                                destinationPosition,
                              ),
                        icon: Icons.route_outlined,
                        iconColor: _routeCameraView != null ? _brand : null,
                      ),
                      AppMapIconButton(
                        label: '현재 위치로 이동',
                        size: _mapButtonSize,
                        onPressed:
                            _map == null ||
                                _location.isLocating ||
                                _movingRouteCamera
                            ? null
                            : _recenter,
                        icon: Icons.my_location,
                        iconColor: _location.isSelected ? _brand : null,
                      ),
                    ],
                  ),
                ),
                DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: _initialSheetSize,
                  minChildSize: _minSheetSize,
                  maxChildSize: _maxSheetExtent(context, constraints.maxHeight),
                  snap: true,
                  snapSizes: const [_initialSheetSize],
                  shouldCloseOnMinExtent: false,
                  builder: (context, scrollController) => Material(
                    color: Colors.white,
                    elevation: 4,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            children: [
                              Center(
                                child: Semantics(
                                  label: '경로 여정 패널 크기 조절',
                                  child: Container(
                                    width: 36,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD5D3D1),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '${origin.name} → ${destination.name}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (minutes is num)
                                Text(
                                  '총 ${minutes.round()}분',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              if (metrics.isNotEmpty)
                                Text(
                                  metrics.join(' · '),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              if (_guiding && _activeSegment == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('경로에서 현재 이동 구간을 확인 중이에요.'),
                                ),
                              JourneyRecommendation(route: route),
                              if (timed.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                JourneyTimeBar(segments: timed),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                '상세 이동 여정',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (times.isNotEmpty) Text(times.join(' → ')),
                              const SizedBox(height: 8),
                              if (segments.isEmpty)
                                const Text('구간별 이동 정보가 없어요.'),
                              for (final (index, step) in segments.indexed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _guiding && _activeSegment == index
                                        ? const Color(0xFFFBEDE7)
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: JourneyStep(segment: step),
                                ),
                              if (!loading &&
                                  segments.every(
                                    (step) => journeyShapePoints(step) == null,
                                  ))
                                const Text(
                                  '점선은 출발지와 도착지를 잇는 직선이에요.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                )
                              else if (segments.any(
                                (step) =>
                                    step['shape_status'] == 'fallback' ||
                                    step['is_actual_shape'] == false,
                              ))
                                const Text(
                                  '점선은 추정 구간이에요.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              if (sources.isNotEmpty)
                                Text(
                                  sources.join(' · '),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              if (!_guiding && !_starting)
                                ..._relatedRoutes(context, route),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: AppPrimaryButton(
                              label: _guiding
                                  ? '안내 종료'
                                  : _starting
                                  ? '현재 위치 확인 중…'
                                  : '안내 시작',
                              enabled:
                                  _guiding ||
                                  (!_starting &&
                                      _map != null &&
                                      !_location.isLocating &&
                                      !_movingRouteCamera),
                              onTap: _guiding
                                  ? () => Navigator.pop(context, true)
                                  : () => _startGuidance(segments),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          onTap: () async {
            final finished = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => RouteDetailScreen(
                  route: candidate,
                  searchId: widget.searchId,
                  journeyClient: widget.journeyClient,
                  origin: widget.origin,
                  destination: widget.destination,
                  candidates: widget.candidates,
                ),
              ),
            );
            if (finished == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
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
