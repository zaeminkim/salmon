import 'dart:math' as math;

import 'package:geolocator/geolocator.dart' as geo;
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../core/widgets/journey_map_geometry.dart';
import '../core/widgets/journey_presentation.dart';

/// Uses supplied geometry to highlight an identifiable segment during guidance.
class JourneyProgress {
  JourneyProgress(List<JourneySegment> segments)
    : _shapes = segments.map(journeyShapePoints).toList();

  final List<List<LatLng>?> _shapes;

  int? match(geo.Position position, int? current) {
    if (!position.accuracy.isFinite || position.accuracy > 50) return current;
    final radius = position.accuracy.clamp(15, 45).toDouble();
    final longitudeScale = 111320 * math.cos(position.latitude * math.pi / 180);
    int? closest;
    double closestDistance = double.infinity;
    double secondDistance = double.infinity;
    for (var index = current ?? 0; index < _shapes.length; index++) {
      final points = _shapes[index];
      if (points == null) continue;
      final distance = _distance(points, position, longitudeScale);
      if (distance < closestDistance) {
        closest = index;
        secondDistance = closestDistance;
        closestDistance = distance;
      } else if (distance < secondDistance) {
        secondDistance = distance;
      }
    }
    // Keep the current step around a shared stop or crossing.
    if (closestDistance > radius || secondDistance - closestDistance < 10) {
      return current;
    }
    return closest ?? current;
  }

  double _distance(
    List<LatLng> points,
    geo.Position position,
    double longitudeScale,
  ) {
    (double, double) offset(LatLng point) => (
      (point.longitude - position.longitude) * longitudeScale,
      (point.latitude - position.latitude) * 111320,
    );
    var (x, y) = offset(points.first);
    var shortestSquared = double.infinity;
    for (final point in points.skip(1)) {
      final (nextX, nextY) = offset(point);
      final dx = nextX - x;
      final dy = nextY - y;
      final lengthSquared = dx * dx + dy * dy;
      final fraction = lengthSquared == 0
          ? 0.0
          : (-(x * dx + y * dy) / lengthSquared).clamp(0.0, 1.0);
      final nearestX = x + fraction * dx;
      final nearestY = y + fraction * dy;
      shortestSquared = math.min(
        shortestSquared,
        nearestX * nearestX + nearestY * nearestY,
      );
      x = nextX;
      y = nextY;
    }
    return math.sqrt(shortestSquared);
  }
}
