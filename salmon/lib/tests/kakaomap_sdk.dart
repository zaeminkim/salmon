import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo; // geo: 패키지에 붙이는 별명
import 'package:dio/dio.dart';

class KakaomapSdk extends StatefulWidget {
  const KakaomapSdk({super.key}); // 생성자: key를 상위 클래스 생성자에 넘김

  @override
  State<KakaomapSdk> createState() => _KakaomapSdkState();
  // 위젯에 사용할 상태 객체를 만들어 반환함
}

class _KakaomapSdkState extends State<KakaomapSdk>
    with
        WidgetsBindingObserver // 앱의 백그라운드 전환과 복귀를 감지
        {
  static const _cityHall = LatLng(37.5665, 126.9780);
  static const _seoulStation = LatLng(37.5547, 126.9707);

  KakaoMapController? _controller;
  Poi? _stationPoi;

  // Geolocator
  Poi? _myLocationPoi; // 지도에 추가한 파란 점 객체
  geo.Position? _currentPosition; // 최근 수신한 위치

  StreamSubscription<void>? _positionSubscription; // 실시간 위치 수신을 중단할 때 사용할 구독

  bool _isLocating = false; // 권한 확인 및 최초 위치 조회 진행여부
  bool _isForeground = true; // 앱이 화면에 있는지 여부
  int _locationGeneration = 0; // 중단 전에 시작된 작업의 늦은 결과를 구분

  void _onMapReady(KakaoMapController controller) async {
    if (!mounted) return; // 이 State가 위젯 트리에 연결되어 있는지 확인

    setState(() {
      _controller = controller;
      _stationPoi = null;
      _myLocationPoi = null;
    });
    debugPrint('거슬렁 카카오맵 준비 완료');

    // try-catch문
    // try 안에서 발생한 오류는 catch가 받음
    try {
      await _addOverlays(controller);
    } catch (error, stackTrace) {
      debugPrint('오버레이 추가 실패 $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted || _controller != controller) return;

    await _startLocation(moveCamera: true);
  }

  // 지도 조회
  Future<void> _printCameraPosition() async {
    final controller = _controller; // final 변수는 값 재할당 불가
    if (controller == null) return; // null 이라면 return으로 이 함수의 실행을 끝냄

    // 카메라 조회 완료를 기다림
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
    // 이미지가 로딩된 상태에서 합성하도록 미리 준비합니다.
    const pinImage = AssetImage('assets/images/location-pin.png');

    await precacheImage(pinImage, context);
    if (!mounted) return;

    final destinationIcon = await KImage.fromWidget(
      Stack(
        fit: StackFit.expand,
        children: [
          const Image(image: pinImage, fit: BoxFit.fill),
          Positioned(
            top: 14,
            left: 4,
            right: 4,
            child: const Text(
              '도착지',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const Size(28, 36),
      context: context,
    );

    if (!mounted) return;

    final poi = await controller.labelLayer.addPoi(
      _seoulStation,
      id: 'seoul-station',
      style: PoiStyle(icon: destinationIcon, anchor: const KPoint(0.5, 1.0)),
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
        icon: KImage.fromAsset('assets/images/location-pin.png', 24, 36),
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

  // geolocator
  // 위치 서비스와 권한을 확인하는 함수
  void _showLocationMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _checkLocationPermission({
    required bool requestPermission,
  }) async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      _showLocationMessage('기기 설정에서 위치 기능을 켠 뒤 현재 위치 버튼을 눌러 주세요.');
      return false;
    }

    var permission = await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied && requestPermission) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever) {
      _showLocationMessage('Android 설정 → 앱 → salmon → 권한에서 위치를 허용해 주세요.');
      return false;
    }

    final allowed =
        permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always;

    if (!allowed) {
      _showLocationMessage('현재 위치를 표시하려면 위치 권한이 필요합니다.');
    }

    return allowed;
  }

  // 좌표를 받아 파란 객체를 만들거나 이동시키는 함수
  bool _isLocationActive(int generation) {
    return mounted && _isForeground && generation == _locationGeneration;
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
      // 처음 받은 위치에는 파란 점을 생성합니다. 최초 한 번만 생성
      // final icon = await KImage.fromWidget(
      //   // KImage: 지도에서 사용할 수 있는 이미지를 생성하는 객체
      //   Container(
      //     decoration: BoxDecoration(
      //       color: Colors.blue,
      //       shape: BoxShape.circle,
      //       border: Border.all(color: Colors.white, width: 3),
      //     ),
      //   ),
      //   const Size(24, 24),
      // );
      final icon = KImage.fromAsset('assets/images/current-pin.png', 24, 24);

      if (!_isLocationActive(generation)) return;

      final poi = await controller.labelLayer.addPoi(
        coordinate,
        id: 'my-location',
        rank: 10000,
        style: PoiStyle(icon: icon, anchor: const KPoint(0.5, 0.5)),
      );

      if (!_isLocationActive(generation)) return;

      _myLocationPoi = poi;
    }

    if (!_isLocationActive(generation)) return;

    _currentPosition = position;

    debugPrint(
      '현재 위치 갱신 '
      '${position.latitude}, ${position.longitude} '
      '정확도 ${position.accuracy}m',
    );
  }

  // 카메라 이동과 위치 수신 중단 함수
  Future<void> _moveCameraToMyLocation(int generation) async {
    final controller = _controller;
    final position = _currentPosition;

    if (controller == null ||
        position == null ||
        !_isLocationActive(generation)) {
      return;
    }

    await controller.moveCamera(
      CameraUpdate.newCenterPosition(
        LatLng(position.latitude, position.longitude),
      ),
      animation: const CameraAnimation(500),
    );
  }

  void _stopLocation() {
    _locationGeneration++;

    final subscription = _positionSubscription;

    _positionSubscription = null;
    _currentPosition = null;
    _isLocating = false;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  // 최초 조회와 실시간 구독을 연결
  Future<void> _startLocation({
    bool moveCamera = false,
    bool requestPermission = true,
  }) async {
    if (!mounted || !_isForeground || _controller == null || _isLocating) {
      return;
    }

    final generation = _locationGeneration;

    setState(() {
      _isLocating = true;
    });

    try {
      final allowed = await _checkLocationPermission(
        requestPermission: requestPermission,
      );

      if (!allowed || !_isLocationActive(generation)) {
        return;
      }

      // 이미 위치를 수신 중이면 최근 위치로 카메라만 이동합니다.
      if (_positionSubscription != null && _currentPosition != null) {
        if (moveCamera) {
          await _moveCameraToMyLocation(generation);
        }
        return;
      }

      // 최초 위치를 한 번 조회합니다.
      final firstPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!_isLocationActive(generation)) return;

      await _showMyLocation(firstPosition, generation);

      if (!_isLocationActive(generation)) return;

      // 이후 위치 변경을 계속 수신합니다.
      _positionSubscription =
          geo.Geolocator.getPositionStream(
                locationSettings: const geo.LocationSettings(
                  accuracy: geo.LocationAccuracy.high,
                  distanceFilter: 3,
                ),
              )
              .asyncMap<void>((position) {
                return _showMyLocation(position, generation);
              })
              .listen(
                (_) {},
                onError: (Object error, StackTrace stackTrace) {
                  if (!_isLocationActive(generation)) return;

                  _stopLocation();

                  setState(() {});

                  debugPrint('위치 수신 오류 $error');
                  debugPrintStack(stackTrace: stackTrace);

                  _showLocationMessage('위치 수신이 중단됐습니다. 현재 위치 버튼으로 다시 시도하세요.');
                },
                cancelOnError: true,
              );

      if (moveCamera) {
        await _moveCameraToMyLocation(generation);
      }
    } on TimeoutException {
      if (_isLocationActive(generation)) {
        _showLocationMessage('위치를 받지 못했습니다. 위치 설정과 에뮬레이터 좌표를 확인해 주세요.');
      }
    } catch (error, stackTrace) {
      if (_isLocationActive(generation)) {
        debugPrint('위치 처리 실패 $error');
        debugPrintStack(stackTrace: stackTrace);

        _showLocationMessage('위치 처리 중 오류가 발생했습니다. 실행 로그를 확인해 주세요.');
      }
    } finally {
      if (_isLocationActive(generation)) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  // 앱 상태변화와 페이지 종료 처리
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isForeground = false;
      _stopLocation();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isForeground = true;

      unawaited(_startLocation(requestPermission: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _stopLocation();

    super.dispose();
  }

  // 현재 위치 버튼용 함수
  Future<void> _goToMyLocation() async {
    await _startLocation(moveCamera: true);
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
        // 그 함수의 매개변수에는 지도를 관리하기 위한 KakaoMapController가 입력됨
        onMapReady: _onMapReady,
        onMapError: (error) {
          debugPrint('Salmon 카카오맵 오류: $error');
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _controller == null || _isLocating ? null : _goToMyLocation,
        tooltip: '현재 위치로 이동',
        child: _isLocating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.my_location),
      ),
    );
  }
}
