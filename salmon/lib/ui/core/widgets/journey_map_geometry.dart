import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'journey_presentation.dart';

enum RouteCameraView {
  overview,
  origin,
  destination;

  RouteCameraView get next => values[(index + 1) % values.length];

  CameraUpdate cameraUpdate(LatLng origin, LatLng destination) =>
      switch (this) {
        overview when origin != destination => CameraUpdate.fitMapPoints([
          origin,
          destination,
        ], padding: 120),
        _ => CameraUpdate.newCenterPosition(
          this == RouteCameraView.destination ? destination : origin,
          zoomLevel: 16,
        ),
      };
}

/// 지도 위젯과 별개로 경로 응답의 좌표를 읽습니다.
LatLng? journeyPosition(Object? place) =>
    place is Map ? _position(place['latitude'], place['longitude']) : null;

LatLng? _position(Object? latitude, Object? longitude) {
  if (latitude is! num ||
      longitude is! num ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return null;
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

List<LatLng>? journeyShapePoints(JourneySegment segment) {
  final shape = segment['shape'];
  if (shape is! Map || shape['type'] != 'LineString') return null;
  final coordinates = shape['coordinates'];
  if (coordinates is! List || coordinates.length < 2) return null;
  final points = <LatLng>[];
  for (final pair in coordinates) {
    if (pair is! List || pair.length != 2) return null;
    // GeoJSON은 경도부터, 카카오 LatLng는 위도부터 받습니다.
    final point = _position(pair[1], pair[0]);
    if (point == null) return null;
    points.add(point);
  }
  return points;
}
