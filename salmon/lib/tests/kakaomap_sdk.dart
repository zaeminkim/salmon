import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo; // geo: 패키지에 붙이는 별명

class KakaomapSdk extends StatefulWidget {
  const KakaomapSdk({super.key});

  @override
  State<KakaomapSdk> createState() => _KakaomapSdkState();
}

class _KakaomapSdkState extends State<KakaomapSdk> {
  static const _cityHall = LatLng(37.5665, 126.9780);
  static const _seoulStation = LatLng(37.5547, 126.9707);

  KakaoMapController? _controller;
  Poi? _stationPoi;

  void _onMapReady(KakaoMapController controller) async {
    if (!mounted) return;

    setState(() {
      _controller = controller;
      _stationPoi = null;
    });
    debugPrint('거슬렁 카카오맵 준비 완료');

    try {
      await _addOverlays(controller);
    } catch (error, stackTrace) {
      debugPrint('오버레이 추가 실패 $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _printCameraPosition() async {
    final controller = _controller;
    if (controller == null) return;

    final camera = await controller.getCameraPosition();
    debugPrint(
      '지도 중심: ${camera.position.latitude}, '
      '${camera.position.longitude} / 확대 수준: ${camera.zoomLevel}',
    );
  }

  Future<void> _moveToSeoulStation() async {
    final controller = _controller;
    if (controller == null) return;

    final update = CameraUpdate.newCenterPosition(_seoulStation);
    await controller.moveCamera(update, animation: const CameraAnimation(1000));
  }

  Future<void> _addOverlays(KakaoMapController controller) async {
    final poi = await controller.labelLayer.addPoi(
      _seoulStation,
      id: 'seoul-station',
      text: '서울역',
      style: PoiStyle(
        icon: KImage.fromAsset('assets/images/pin.png', 36, 36),
        textStyle: const [PoiTextStyle(size: 20, color: Colors.black)],
      ),
    );

    await controller.routeLayer.addRoute(
      const [_cityHall, LatLng(37.5600, 126.9750), _seoulStation],
      RouteStyle(
        Colors.orange,
        16.0,
        strokeColor: Colors.white,
        strokeWidth: 2.0,
      ),
    );

    await controller.lodLabelLayer.addLodPoi(
      _cityHall,
      text: '서울시청',
      style: PoiStyle(
        icon: KImage.fromAsset('assets/images/pin.png', 36, 36),
        textStyle: const [PoiTextStyle(size: 20, color: Colors.black)],
      ),
    );

    // await controller.labelLayer.addPolylineText('시청에서 서울역 방향', const [
    //   _cityHall,
    //   LatLng(37.5600, 126.9750),
    //   _seoulStation,
    // ], style: PolylineTextStyle(24, Colors.deepPurple));

    if (!mounted) return;

    setState(() {
      _stationPoi = poi;
    });
  }

  // 2. Add MapView Widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카카오맵 SDK 테스트'),
        // 3. Move the Camera to show the map
        actions: [
          IconButton(
            tooltip: '현재 지도 중심 확인',
            onPressed: _controller == null ? null : _printCameraPosition,
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: '서울역으로 이동',
            onPressed: _controller == null ? null : _moveToSeoulStation,
            icon: Icon(Icons.gps_fixed),
          ),
        ],
      ),
      body: KakaoMap(
        option: const KakaoMapOption(
          // position: LatLng(37.5665, 126.9780), // 기본 위치
          position: _cityHall,
          zoomLevel: 16,
          mapType: MapType.normal,
        ),
        // 오류 없이 지도를 불러온다면, onMapReady 매개변수에 담긴 함수가 호출됨
        // 함수의 매개변수에는 지도를 관리하기 위한 KakaoMapController가 입력됨
        onMapReady: _onMapReady,
        onMapError: (error) {
          debugPrint('Salmon 카카오맵 오류: $error');
        },
      ),
    );
  }
}
