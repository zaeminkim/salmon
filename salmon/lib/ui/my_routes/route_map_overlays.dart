import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../data/journeys/journey_example_api.dart';
import '../../data/places/kakao_search_result.dart';
import '../core/widgets/journey_map_geometry.dart';
import '../core/widgets/journey_presentation.dart';

/// 탭이나 장소 선택이 바뀔 때 지도 핀과 경로선을 순서대로 갱신합니다.
class RouteMapOverlays {
  RouteMapOverlays({
    required this.activeSearchPlace,
    required this.shouldShowSavedExample,
    required this.loadSavedExample,
    required this.onSavedRouteCameraMove,
    required this.buildPinIcon,
  });

  final KakaoSearchResult? Function(bool origin) activeSearchPlace;
  final bool Function() shouldShowSavedExample;
  final Future<Map<String, dynamic>> Function() loadSavedExample;
  final VoidCallback onSavedRouteCameraMove;
  final Future<KImage?> Function(String label) buildPinIcon;

  KakaoMapController? _controller;
  final _savedRouteRemovals = <Future<void> Function()>[];
  final _savedRoutePinStyles = <bool, PoiStyle>{};
  Future<void> _savedRouteUpdates = Future<void>.value();
  int _savedRouteRevision = 0;
  final _routePins = <bool, Poi>{};
  final _routePinStyles = <bool, PoiStyle>{};
  final _routePinIcons = <bool, Future<KImage?>>{};
  Future<void> _routePinUpdates = Future<void>.value();

  void attach(KakaoMapController controller) {
    _controller = controller;
    _routePins.clear();
    _routePinStyles.clear();
    _savedRouteRemovals.clear();
    _savedRoutePinStyles.clear();
  }

  void dispose() {
    _controller = null;
  }

  void syncSearchPins() {
    updateSearchPin(origin: true, place: activeSearchPlace(true));
    updateSearchPin(origin: false, place: activeSearchPlace(false));
  }

  void updateSearchPin({
    required bool origin,
    required KakaoSearchResult? place,
  }) {
    final controller = _controller;
    if (controller == null) return;
    // Keep native add/remove calls in order when a selection quickly changes.
    _routePinUpdates = _routePinUpdates.then((_) async {
      if (_controller != controller ||
          !identical(activeSearchPlace(origin), place)) {
        return;
      }

      try {
        final previous = _routePins[origin];
        if (previous != null) {
          await previous.remove();
          if (_controller != controller) return;
          _routePins.remove(origin);
        }
        if (place == null || !identical(activeSearchPlace(origin), place)) {
          return;
        }

        final style = await _routePinStyle(origin, _routePinStyles);
        if (style == null ||
            _controller != controller ||
            !identical(activeSearchPlace(origin), place)) {
          return;
        }
        final pin = await controller.labelLayer.addPoi(
          LatLng(place.latitude, place.longitude),
          id: origin ? 'route-origin' : 'route-destination',
          rank: 9000,
          style: style,
        );
        if (_controller == controller) _routePins[origin] = pin;
      } catch (error) {
        debugPrint('길찾기 핀 갱신 실패: $error');
      }
    });
  }

  void syncSavedRoute() {
    final controller = _controller;
    if (controller == null) return;
    final revision = ++_savedRouteRevision;
    bool hasMap() => identical(_controller, controller);
    // 새 선택이 대기 중이어도 이미 그린 요소의 삭제 함수를 보관합니다.
    // 다음 갱신에서 기존 요소를 지운 뒤 새 경로를 그립니다.
    bool isCurrent() => hasMap() && revision == _savedRouteRevision;

    _savedRouteUpdates = _savedRouteUpdates.then((_) async {
      if (!isCurrent()) return;
      try {
        while (_savedRouteRemovals.isNotEmpty) {
          await _savedRouteRemovals.last();
          if (!hasMap()) return;
          _savedRouteRemovals.removeLast();
        }
        if (!isCurrent() || !shouldShowSavedExample()) return;
        final example = await loadSavedExample();
        if (!isCurrent()) return;
        final origin = journeyPosition(example['origin']);
        final destination = journeyPosition(example['destination']);
        if (origin == null || destination == null) return;
        final candidates = example['candidates'];
        final candidate = candidates is List
            ? candidates.whereType<Map<String, dynamic>>().firstOrNull
            : null;
        final detail = await loadJourneyExampleDetail(
          searchId: example['search_id'],
          candidateId: candidate?['candidate_id'],
        );
        if (!isCurrent()) return;
        final route = detail?['candidate'];
        final lines = [
          if (route is Map<String, dynamic>)
            for (final segment in journeySegments(route))
              if (segment['is_actual_shape'] == true)
                if (journeyShapePoints(segment) case final points?)
                  (
                    points: points,
                    style: PolylineStyle(journeySegmentColor(segment), 16),
                  ),
        ];
        if (lines.isEmpty && origin != destination) {
          lines.add((
            points: [origin, destination],
            style: PolylineStyle(const Color(0xFFD9553E), 16),
          ));
        }

        for (final (position, isOrigin) in [
          (origin, true),
          (destination, false),
        ]) {
          final style = await _routePinStyle(isOrigin, _savedRoutePinStyles);
          if (style == null || !isCurrent()) return;
          final pin = await controller.labelLayer.addPoi(
            position,
            id: isOrigin ? 'saved-route-origin' : 'saved-route-destination',
            rank: 9000,
            style: style,
          );
          if (!hasMap()) return;
          _savedRouteRemovals.add(pin.remove);
          if (!isCurrent()) return;
        }
        for (final (index, segment) in lines.indexed) {
          final line = await controller.shapeLayer.addPolylineShape(
            MapPoint(segment.points),
            segment.style,
            PolylineCap.round,
            id: index == 0 ? 'saved-route-line' : 'saved-route-line-$index',
          );
          if (!hasMap()) return;
          _savedRouteRemovals.add(line.remove);
          if (!isCurrent()) return;
        }
        if (!isCurrent()) return;
        onSavedRouteCameraMove();
        final points = {
          origin,
          destination,
          for (final line in lines) ...line.points,
        };
        await controller.moveCamera(
          points.length == 1
              ? CameraUpdate.newCenterPosition(origin)
              : CameraUpdate.fitMapPoints(points.toList(), padding: 120),
        );
      } catch (error) {
        debugPrint('내 경로 지도 갱신 실패: $error');
      }
    });
  }

  Future<PoiStyle?> _routePinStyle(
    bool origin,
    Map<bool, PoiStyle> styles,
  ) async {
    // 저장 경로와 길찾기가 같은 출발·도착 이미지를 재사용합니다.
    final pending = _routePinIcons.putIfAbsent(
      origin,
      () => buildPinIcon(origin ? '출발' : '도착'),
    );
    final KImage? icon;
    try {
      icon = await pending;
    } catch (_) {
      if (identical(_routePinIcons[origin], pending)) {
        _routePinIcons.remove(origin);
      }
      rethrow;
    }
    if (icon == null) return null;
    return styles.putIfAbsent(
      origin,
      () => PoiStyle(icon: icon, anchor: const KPoint(0.5, 1.0)),
    );
  }
}
