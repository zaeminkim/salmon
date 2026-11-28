import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo; // geo: 패키지에 붙이는 별명
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../data/location_permission.dart';

/// 현재 지도의 위치와 방향 센서 구독을 관리합니다.
class MapLocationTracker {
  MapLocationTracker({
    required this.onChanged,
    required this.onMessage,
    this.onPosition,
    this.followLocation = false,
  });

  final VoidCallback onChanged;
  final ValueChanged<String> onMessage;
  final ValueChanged<geo.Position>? onPosition;
  final bool followLocation;
  bool _disposed = false;

  static const _headingChannel = EventChannel('salmon/device_heading');
  static const gpsZoomLevel = 16;

  KakaoMapController? _controller;
  StreamSubscription<void>? _headingSubscription;
  PoiStyle? _locationDotStyle;
  PoiStyle? _locationHeadingStyle;

  // Geolocator
  Poi? _myLocationPoi; // 지도에 추가한 내 위치 객체
  geo.Position? _currentPosition; // 최근 수신한 위치

  StreamSubscription<void>? _positionSubscription; // 실시간 위치 수신을 중단할 때 사용할 구독

  bool _isLocating = false; // 권한 확인 및 최초 위치 조회 진행여부
  bool _gpsSelected = false;
  bool _isForeground = true; // 앱이 화면에 있는지 여부
  int _locationGeneration = 0; // 중단 전에 시작된 작업의 늦은 결과를 구분

  bool get isLocating => _isLocating;
  bool get isSelected => _gpsSelected;

  Future<geo.Position?> locateForSearch(
    ValueChanged<String> showMessage,
  ) async {
    try {
      if (!await checkLocationPermission(
        requestPermission: true,
        onMessage: showMessage,
      )) {
        return null;
      }
      return await _readCurrentPosition();
    } on TimeoutException {
      showMessage('현재 위치를 받지 못했어요. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      showMessage('현재 위치를 확인할 수 없어요. 위치 설정을 확인해 주세요.');
    }
    return null;
  }

  Future<geo.Position> _readCurrentPosition() =>
      geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

  void attach(KakaoMapController controller) {
    if (_controller == controller) return;
    if (_controller != null) _stopLocation();
    _controller = controller;
    _locationDotStyle = PoiStyle(
      icon: KImage.fromAsset('assets/images/current-pin.png', 40, 40),
      anchor: const KPoint(0.5, 0.5),
    );
    _locationHeadingStyle = PoiStyle(
      icon: KImage.fromAsset('assets/images/current-pin.png', 40, 40),
      anchor: const KPoint(0.5, 0.5),
    );
    _myLocationPoi = null;
  }

  void pause() {
    _isForeground = false;
    _stopLocation();
  }

  void resume({bool follow = false}) {
    _isForeground = true;
    if (follow) {
      unawaited(recenter(requestPermission: false));
    } else {
      unawaited(start(requestPermission: false));
    }
  }

  void stop() => _stopLocation();

  void dispose() {
    _disposed = true;
    _stopLocation();
    _controller = null;
  }

  void clearSelection() {
    if (!_gpsSelected) return;
    _gpsSelected = false;
    onChanged();
  }

  // 좌표를 받아 내 위치 객체를 만들거나 이동시키는 함수
  // 지도를 바꾸거나 화면을 벗어나면 이전 기기 응답을 무시합니다.
  bool _isLocationActive(int generation) {
    return !_disposed && _isForeground && generation == _locationGeneration;
  }

  Future<void> _showMyLocation(geo.Position position, int generation) async {
    final controller = _controller;

    if (controller == null || !_isLocationActive(generation)) {
      return;
    }

    final coordinate = LatLng(position.latitude, position.longitude);

    final existingPoi = _myLocationPoi;

    if (existingPoi != null) {
      // 두 번째 위치부터는 기존 점을 이동시킵니다. 이후에는 기존 객체를 이동
      await existingPoi.move(coordinate);
    } else {
      // 처음 받은 위치에는 내 위치 객체를 생성합니다. 최초 한 번만 생성

      if (!_isLocationActive(generation)) return;

      final poi = await controller.labelLayer.addPoi(
        coordinate,
        id: 'my-location',
        rank: 10000,
        style: _locationDotStyle!,
        transform: TransformMethod.absoluteRoatation,
      );

      if (!_isLocationActive(generation)) return;

      _myLocationPoi = poi;
    }

    if (!_isLocationActive(generation)) return;

    _currentPosition = position;
    onPosition?.call(position);

    debugPrint(
      '현재 위치 갱신 '
      '${position.latitude}, ${position.longitude} '
      '정확도 ${position.accuracy}m',
    );
  }

  void _startHeading(geo.Position position, int generation) {
    final poi = _myLocationPoi;
    if (poi == null ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final dotStyle = _locationDotStyle!;
    final headingStyle = _locationHeadingStyle!;
    _headingSubscription = _headingChannel
        .receiveBroadcastStream({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
        })
        .map((event) {
          final degrees = (event as num?)?.toDouble();
          return degrees != null && degrees.isFinite ? degrees : null;
        })
        .distinct()
        .asyncMap<void>((degrees) async {
          if (!_isLocationActive(generation)) return;
          if (degrees == null) {
            if (poi.style != dotStyle) await poi.changeStyles(dotStyle);
            return;
          }

          // Kakao Maps uses radians clockwise from north.
          final rotation = ((degrees + 180) % 360 - 180) * math.pi / 180;
          await poi.rotate(rotation);
          if (_isLocationActive(generation) && poi.style != headingStyle) {
            await poi.changeStyles(headingStyle);
          }
        })
        .listen(
          (_) {},
          onError: (Object error) => debugPrint('방향 수신 오류 $error'),
        );
  }

  // 카메라 이동과 위치 수신 중단 함수
  Future<bool> _moveCameraToMyLocation(int generation, {int? zoomLevel}) async {
    final controller = _controller;
    final position = _currentPosition;

    if (controller == null ||
        position == null ||
        !_isLocationActive(generation)) {
      return false;
    }

    await controller.moveCamera(
      CameraUpdate.newCenterPosition(
        LatLng(position.latitude, position.longitude),
        zoomLevel: zoomLevel,
      ),
      animation: const CameraAnimation(500),
    );
    return _isLocationActive(generation) && _controller == controller;
  }

  void _stopLocation() {
    _locationGeneration++;

    final subscription = _positionSubscription;
    final headingSubscription = _headingSubscription;

    _positionSubscription = null;
    _headingSubscription = null;
    _currentPosition = null;
    _isLocating = false;
    _gpsSelected = false;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    if (headingSubscription != null) {
      unawaited(headingSubscription.cancel());
    }
  }

  // 위치 수신을 시작하고 카메라까지 이동했으면 true를 반환합니다.
  Future<bool> start({
    bool Function()? shouldMoveCamera,
    bool requestPermission = true,
    int? zoomLevel,
  }) async {
    if (_disposed || !_isForeground || _controller == null || _isLocating) {
      return false;
    }

    final generation = _locationGeneration;

    _isLocating = true;
    onChanged();

    try {
      final allowed = await checkLocationPermission(
        onMessage: onMessage,
        requestPermission: requestPermission,
      );

      if (!allowed || !_isLocationActive(generation)) {
        return false;
      }

      // 이미 위치를 수신 중이면 최근 위치로 카메라만 이동합니다.
      if (_positionSubscription != null && _currentPosition != null) {
        if (shouldMoveCamera?.call() ?? false) {
          return await _moveCameraToMyLocation(
            generation,
            zoomLevel: zoomLevel,
          );
        }
        return false;
      }

      // 최초 위치를 한 번 조회합니다.
      final firstPosition = await _readCurrentPosition();

      if (!_isLocationActive(generation)) return false;

      await _showMyLocation(firstPosition, generation);

      if (!_isLocationActive(generation)) return false;

      _startHeading(firstPosition, generation);

      // 이후 위치 변경을 계속 수신합니다.
      _positionSubscription =
          geo.Geolocator.getPositionStream(
                locationSettings: const geo.LocationSettings(
                  accuracy: geo.LocationAccuracy.high,
                  distanceFilter: 3,
                ),
              )
              .asyncMap<void>((position) async {
                await _showMyLocation(position, generation);
                if (followLocation && _gpsSelected) {
                  await _moveCameraToMyLocation(generation);
                }
              })
              .listen(
                (_) {},
                onError: (Object error, StackTrace stackTrace) {
                  if (!_isLocationActive(generation)) return;

                  _stopLocation();

                  onChanged();

                  debugPrint('위치 수신 오류 $error');
                  debugPrintStack(stackTrace: stackTrace);

                  onMessage('위치 수신이 중단됐습니다. 현재 위치 버튼으로 다시 시도하세요.');
                },
                cancelOnError: true,
              );

      if (shouldMoveCamera?.call() ?? false) {
        return await _moveCameraToMyLocation(generation, zoomLevel: zoomLevel);
      }
    } on TimeoutException {
      if (_isLocationActive(generation)) {
        onMessage('위치를 받지 못했습니다. 위치 설정과 에뮬레이터 좌표를 확인해 주세요.');
      }
    } catch (error, stackTrace) {
      if (_isLocationActive(generation)) {
        debugPrint('위치 처리 실패 $error');
        debugPrintStack(stackTrace: stackTrace);

        onMessage('위치 처리 중 오류가 발생했습니다. 실행 로그를 확인해 주세요.');
      }
    } finally {
      if (_isLocationActive(generation)) {
        _isLocating = false;
        onChanged();
      }
    }
    return false;
  }

  // 현재 위치 버튼용 함수
  Future<bool> recenter({bool requestPermission = true}) async {
    if (_controller == null || _isLocating || !_isForeground) return false;

    final generation = _locationGeneration;
    _gpsSelected = true;
    onChanged();
    final moved = await start(
      shouldMoveCamera: () => _gpsSelected,
      requestPermission: requestPermission,
      zoomLevel: gpsZoomLevel,
    );
    if (!moved && _isLocationActive(generation) && _gpsSelected) {
      clearSelection();
    }
    return moved;
  }

  void onCameraMoveStart(GestureType gesture) {
    if (gesture != GestureType.unknown && _gpsSelected) {
      clearSelection();
    }
  }
}
