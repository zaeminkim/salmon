import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../core/widgets/journey_map_geometry.dart';
import '../core/widgets/journey_presentation.dart';

class JourneyPreviewMap extends StatefulWidget {
  const JourneyPreviewMap({
    super.key,
    required this.origin,
    required this.destination,
    required this.segments,
    this.interactive = false,
    this.onReady,
    this.onCameraMoveStart,
  });

  final LatLng origin;
  final LatLng destination;
  final List<JourneySegment> segments;
  final bool interactive;
  final ValueChanged<KakaoMapController>? onReady;
  final ValueChanged<GestureType>? onCameraMoveStart;

  @override
  State<JourneyPreviewMap> createState() => _JourneyPreviewMapState();
}

class _JourneyPreviewMapState extends State<JourneyPreviewMap> {
  static const _guideColor = Color(0xFF65727D);
  late final _lines = [
    for (final segment in widget.segments)
      if (journeyShapePoints(segment) case final points?)
        (
          points: points,
          color: journeySegmentColor(segment),
          estimated:
              segment['shape_status'] == 'fallback' ||
              segment['is_actual_shape'] == false,
        ),
  ];
  bool _failed = false;

  void _showMapError(Object error) {
    debugPrint('경로 미리보기 지도 오류: $error');
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _drawRoute(KakaoMapController controller) async {
    if (!mounted) return;
    try {
      final stops = <LatLng, String>{};
      for (final segment in widget.segments) {
        final mode = journeyMode(segment);
        if (mode != 'bus' && mode != 'subway') continue;
        for (final key in ['boarding_station', 'alighting_station']) {
          final stop = segment[key];
          final position = journeyPosition(stop);
          final label = journeyStationName(stop, null);
          if (position != null &&
              label != null &&
              position != widget.origin &&
              position != widget.destination) {
            stops.putIfAbsent(position, () => label);
          }
        }
      }
      final points = {
        widget.origin,
        widget.destination,
        ...stops.keys,
        for (final line in _lines) ...line.points,
      };
      if (points.length > 1) {
        await controller.moveCamera(
          CameraUpdate.fitMapPoints(points.toList(), padding: 40),
        );
      }
      for (final (position, label, color, endpoint) in [
        (widget.origin, '출발지', const Color(0xFF246046), true),
        (widget.destination, '도착지', const Color(0xFF9A3627), true),
        for (final stop in stops.entries)
          (stop.key, stop.value, const Color(0xFF475866), false),
      ]) {
        if (!mounted) return;
        await controller.labelLayer.addPoi(
          position,
          text: label,
          rank: endpoint ? 9000 : 8000,
          style: PoiStyle(
            icon: KImage.fromAsset(
              'assets/images/location-pin.png',
              endpoint ? 24 : 16,
              endpoint ? 32 : 22,
            ),
            anchor: const KPoint(0.5, 1.0),
            textStyle: [
              PoiTextStyle(
                size: 13,
                color: color,
                stroke: 2,
                strokeColor: Colors.white,
              ),
            ],
          ),
        );
      }
      if (_lines.isEmpty && points.length > 1) {
        await _drawGuide(controller, widget.origin, widget.destination);
      }
      for (final line in _lines) {
        if (!mounted) return;
        if (line.estimated) {
          for (var i = 1; i < line.points.length; i++) {
            await _drawGuide(controller, line.points[i - 1], line.points[i]);
          }
        } else {
          await controller.shapeLayer.addPolylineShape(
            MapPoint(line.points),
            PolylineStyle(line.color, 16),
            PolylineCap.round,
          );
        }
      }
      if (mounted) widget.onReady?.call(controller);
    } catch (error) {
      _showMapError(error);
    }
  }

  Future<void> _drawGuide(
    KakaoMapController controller,
    LatLng start,
    LatLng end,
  ) async {
    if (start == end) return;
    final style = PolylineStyle(_guideColor, 16);
    LatLng point(double fraction) => LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
    for (var i = 0; i < 12 && mounted; i++) {
      await controller.shapeLayer.addPolylineShape(
        MapPoint([point(i / 12), point((i + 0.56) / 12)]),
        style,
        PolylineCap.round,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.interactive) {
      return _failed
          ? const ColoredBox(
              color: Color(0xFFF4F3F2),
              child: Center(child: Text('지도를 불러오지 못했어요.')),
            )
          : KakaoMap(
              option: KakaoMapOption(position: widget.origin, zoomLevel: 15),
              onMapReady: _drawRoute,
              onMapError: _showMapError,
              onCameraMoveStart: widget.onCameraMoveStart,
            );
    }
    final guideLabel = _lines.isEmpty
        ? '점선은 출발지와 도착지를 잇는 직선이에요.'
        : '점선은 추정 구간이에요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 240,
            child: _failed
                ? const ColoredBox(
                    color: Color(0xFFF4F3F2),
                    child: Center(child: Text('지도를 불러오지 못했어요.')),
                  )
                : Semantics(
                    label: '출발지와 도착지를 보여주는 고정 지도',
                    child: IgnorePointer(
                      child: KakaoMap(
                        option: KakaoMapOption(
                          position: widget.origin,
                          zoomLevel: 15,
                        ),
                        forceGesture: false,
                        onMapReady: _drawRoute,
                        onMapError: _showMapError,
                      ),
                    ),
                  ),
          ),
        ),
        if (!_failed &&
            (_lines.isEmpty || _lines.any((line) => line.estimated)))
          Text(
            guideLabel,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
      ],
    );
  }
}
