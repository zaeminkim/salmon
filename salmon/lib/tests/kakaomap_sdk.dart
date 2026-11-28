import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../data/location_permission.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo; // geo: 패키지에 붙이는 별명

import '../data/places/kakao_search_result.dart';
import '../ui/route_search/kakao_place_suggestions.dart';
import 'demo_map_overlays.dart';

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

  final _searchController = TextEditingController(); // 검색창의 텍스트 관리
  final _searchFocus = FocusNode(); // 검색창의 입력 포커스 관리
  // salmon.local.json의 REST API 키를 빌드 시 읽습니다.
  // 카카오 검색 API 호출
  final _placeSuggestions = KakaoPlaceSuggestions();
  KakaoSearchResult? _selectedSearchResult;

  // 새 입력이 오면 이전 타이머/요청을 중단하고 400ms 후 검색합니다.
  void _onSearchChanged(String value) {
    _selectedSearchResult = null;
    // 한 API가 실패해도 다른 API의 성공 결과는 표시합니다.
    _placeSuggestions.update(value);
  }

  Future<void> _selectSearchResult(KakaoSearchResult result) async {
    _placeSuggestions.update('');
    _searchFocus.unfocus();
    _searchController.text = result.name;
    setState(() {
      _selectedSearchResult = result;
    });
    // 정보는 메모리에만 보관하며 백엔드 요청은 보내지 않습니다.
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.moveCamera(
        CameraUpdate.newCenterPosition(
          LatLng(result.latitude, result.longitude),
        ),
        animation: const CameraAnimation(500),
      );
    } catch (_) {
      if (mounted) _showLocationMessage('검색 정보는 선택됐지만 지도 이동에 실패했습니다.');
    }
  }

  Widget _buildSearchPanel() {
    final selected = _selectedSearchResult;
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '장소명 또는 주소 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  tooltip: '검색 지우기',
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _searchFocus.requestFocus();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            if (_placeSuggestions.isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (_placeSuggestions.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_placeSuggestions.message!),
              ),
            if (_placeSuggestions.results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _placeSuggestions.results.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _placeSuggestions.results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        result.isAddress
                            ? Icons.home_outlined
                            : Icons.place_outlined,
                      ),
                      title: Text(result.name),
                      subtitle: Text(
                        [
                          result.isAddress ? '주소' : '장소',
                          if (result.address != result.name) result.address,
                          if (result.category.isNotEmpty) result.category,
                        ].join(' · '),
                      ),
                      onTap: () => _selectSearchResult(result),
                    );
                  },
                ),
              ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    '선택한 ${selected.isAddress ? '주소' : '장소'}: ${selected.name}\n'
                    '주소: ${selected.address}\n'
                    '위도: ${selected.latitude} / 경도: ${selected.longitude}'
                    '${selected.placeId == null ? '' : '\n장소 ID: ${selected.placeId}'}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
      _myLocationPoi = null;
    });
    debugPrint('거슬렁 카카오맵 준비 완료');

    // try-catch문
    // try 안에서 발생한 오류는 catch가 받음
    try {
      await addDemoMapOverlays(
        context,
        controller,
        cityHall: _cityHall,
        seoulStation: _seoulStation,
      );
    } catch (error, stackTrace) {
      debugPrint('오버레이 추가 실패 $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted || _controller != controller) return;

    await _startLocation(moveCamera: _selectedSearchResult == null);
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

  // geolocator
  // 위치 서비스와 권한을 확인하는 함수
  void _showLocationMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      final allowed = await checkLocationPermission(
        onMessage: _showLocationMessage,
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
    _placeSuggestions.addListener(() => setState(() {}));

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
    _placeSuggestions.dispose();
    _searchController.dispose();
    _searchFocus.dispose();

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
      resizeToAvoidBottomInset:
          false, // 키보드가 표시돼도 본문을 줄이지 않고, 키보드가 본문 위를 덮도록 한다.
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
      body:
          // Column(
          //   children: [
          //     _buildSearchPanel(),
          //     Expanded(
          //       child: KakaoMap(
          //         option: const KakaoMapOption(
          //           // position: LatLng(37.5665, 126.9780), // 기본 위치
          //           position: _cityHall,
          //           zoomLevel: 16,
          //           mapType: MapType.normal,
          //         ),
          //         // 오류 없이 지도를 불러온다면, onMapReady 매개변수에 담긴 함수가 호출됨
          //         // 그 함수의 매개변수에는 지도를 관리하기 위한 KakaoMapController가 입력됨
          //         onMapReady: _onMapReady,
          //         onMapError: (error) {
          //           debugPrint('Salmon 카카오맵 오류: $error');
          //         },
          //       ),
          //     ),
          //   ],
          // ),
          LayoutBuilder(
            builder: (context, constraints) {
              // 현재 키보드가 차지하는 높이입니다.
              final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

              // 검색 패널만 키보드 위의 공간에 들어가도록 제한합니다.
              final searchMaxHeight =
                  (constraints.maxHeight - keyboardHeight - 8)
                      .clamp(0.0, constraints.maxHeight)
                      .toDouble();

              return Stack(
                children: [
                  // 지도는 항상 같은 본문 영역을 채웁니다.
                  Positioned.fill(
                    child: KakaoMap(
                      option: const KakaoMapOption(
                        position: _cityHall,
                        zoomLevel: 16,
                        mapType: MapType.normal,
                      ),
                      onMapReady: _onMapReady,
                      onMapError: (error) {
                        debugPrint('Salmon 카카오맵 오류: $error');
                      },
                    ),
                  ),

                  // 검색창과 검색 결과는 지도 위에 표시합니다.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: searchMaxHeight),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: _buildSearchPanel(),
                      ),
                    ),
                  ),
                ],
              );
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
