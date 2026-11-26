import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:geolocator/geolocator.dart' as geo; // geo: 패키지에 붙이는 별명
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../route_results/routeresults_screen.dart';
import '../route_search/routesearch_screen.dart';
import '../settings/settings_screen.dart';

const _brand = Color(0xFFD9553E);

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key}); // 생성자: key를 상위 클래스 생성자에 넘김

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
  // 위젯에 사용할 상태 객체를 만들어 반환함MyRoutesScreen
}

class _MyRoutesScreenState extends State<MyRoutesScreen>
    with
        WidgetsBindingObserver // 앱의 백그라운드 전환과 복귀를 감지
        {
  static const _cityHall = LatLng(37.5665, 126.9780);
  static const _seoulStation = LatLng(37.5547, 126.9707);

  static const _headingChannel = EventChannel('salmon/device_heading');

  KakaoMapController? _controller;
  StreamSubscription<void>? _headingSubscription;
  PoiStyle? _locationDotStyle;
  PoiStyle? _locationHeadingStyle;

  int _tabIndex = 0;

  // salmon.local.json의 REST API 키를 빌드 시 읽습니다.
  static const _restApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');
  final _searchController = TextEditingController(); // 검색창의 텍스트 관리
  final _searchFocus = FocusNode(); // 검색창의 입력 포커스 관리

  KakaoSearchResult? _origin;
  KakaoSearchResult? _destination;
  bool? _editingOrigin; // true: 출발지, false: 목적지, null: 편집 종료
  final _routeSheet = GlassModalSheetController();
  final _busNumberController = TextEditingController();
  final _busNumberFocus = FocusNode();
  GlassSheetState _routeSheetState = GlassSheetState.hidden;

  // 카카오 검색 API 호출
  final _searchDio = Dio(
    BaseOptions(
      baseUrl: 'https://dapi.kakao.com/v2/local/search',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  Timer? _searchDebounce;
  CancelToken? _searchCancelToken;
  int _searchGeneration = 0;
  bool _isSearching = false;
  String? _searchMessage;
  List<KakaoSearchResult> _searchResults = [];
  KakaoSearchResult? _selectedSearchResult;

  // 새 입력이 오면 이전 타이머/요청을 중단하고 400ms 후 검색합니다.
  void _onSearchChanged(String value, {bool submit = false}) {
    if (_editingOrigin == null) return;
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel();
    final generation = ++_searchGeneration;
    final query = value.trim();
    setState(() {
      _searchResults = [];
      _searchMessage = null;
      _isSearching = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    if (submit) {
      unawaited(_searchPlaces(query, generation));
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_searchPlaces(query, generation));
    });
  }

  String _searchErrorMessage(DioException error) {
    return switch (error.response?.statusCode) {
      401 => 'REST API 키가 올바른지 확인해 주세요. (401)',
      403 => '카카오 API 사용 권한과 키 제한 설정을 확인해 주세요. (403)',
      429 => '검색 요청 한도를 초과했습니다. 잠시 후 다시 시도해 주세요. (429)',
      _ => '검색에 실패했습니다. 네트워크를 확인하고 다시 검색해 주세요.',
    };
  }

  Future<void> _searchPlaces(String query, int generation) async {
    if (!mounted || generation != _searchGeneration) return;
    if (_restApiKey.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchMessage =
            'salmon.local.json에 KAKAO_REST_API_KEY를 추가한 뒤 다시 빌드해 주세요.';
      });
      return;
    }

    final cancelToken = CancelToken();
    _searchCancelToken = cancelToken;

    // 한 API가 실패해도 다른 API의 성공 결과는 표시합니다.
    Future<({List<KakaoSearchResult> results, String? error})> fetch(
      bool isAddress,
    ) async {
      try {
        final response = await _searchDio.get<Map<String, dynamic>>(
          isAddress ? '/address.json' : '/keyword.json',
          queryParameters: {
            'query': query,
            'size': 10,
            if (isAddress) 'analyze_type': 'similar',
          },
          options: Options(headers: {'Authorization': 'KakaoAK $_restApiKey'}),
          cancelToken: cancelToken,
        );
        final documents = response.data?['documents'] as List<dynamic>? ?? [];
        final results = documents
            .map(
              (item) => KakaoSearchResult.fromDocument(
                Map<String, dynamic>.from(item as Map),
                isAddress: isAddress,
              ),
            )
            .whereType<KakaoSearchResult>()
            .toList();
        return (results: results, error: null);
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          return (results: <KakaoSearchResult>[], error: null);
        }
        return (
          results: <KakaoSearchResult>[],
          error: _searchErrorMessage(error),
        );
      } catch (_) {
        return (
          results: <KakaoSearchResult>[],
          error: '검색 결과를 해석하지 못했습니다. 다시 시도해 주세요.',
        );
      }
    }

    final responses = await Future.wait([fetch(false), fetch(true)]);
    if (!mounted ||
        generation != _searchGeneration ||
        cancelToken.isCancelled) {
      return;
    }
    final results = responses.expand((response) => response.results).toList();
    final errors = responses
        .map((response) => response.error)
        .whereType<String>()
        .toSet();
    setState(() {
      _searchResults = results;
      _isSearching = false;
      _searchMessage = errors.isNotEmpty
          ? errors.join('\n')
          : results.isEmpty
          ? '검색 결과가 없습니다. 장소명이나 주소를 더 입력해 주세요.'
          : null;
    });
  }

  void _editPlace({required bool origin}) {
    _searchController.clear();
    setState(() => _editingOrigin = origin);
    _onSearchChanged('');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingOrigin == origin) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _cancelPlaceEdit() {
    _searchFocus.unfocus();
    _searchController.clear();
    _onSearchChanged('');
    setState(() => _editingOrigin = null);
  }

  void _onRouteSheetStateChanged(GlassSheetState state) {
    if (state != GlassSheetState.full) {
      _busNumberFocus.unfocus();
      _searchFocus.unfocus();
    }
    if (state == GlassSheetState.hidden && _editingOrigin != null) {
      _cancelPlaceEdit();
    }
    setState(() => _routeSheetState = state);
  }

  void _openRouteResults() {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return;
    final busNumber = _busNumberController.text.trim().toUpperCase();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RouteResultsScreen(
          origin: origin,
          destination: destination,
          preferredBusNumber: busNumber.isEmpty ? null : busNumber,
        ),
      ),
    );
  }

  Future<void> _selectSearchResult(KakaoSearchResult result) async {
    final editingOrigin = _editingOrigin;
    if (editingOrigin == null) return;

    _searchDebounce?.cancel();
    _searchCancelToken?.cancel();
    ++_searchGeneration;
    _searchFocus.unfocus();
    _searchController.text = result.name;
    setState(() {
      if (editingOrigin) {
        _origin = result;
      } else {
        _destination = result;
      }
      _editingOrigin = null;

      _gpsSelected = false;
      _selectedSearchResult = result;
      _searchResults = [];
      _searchMessage = null;
      _isSearching = false;
    });
    final controller = _controller;
    if (controller != null) {
      await _moveCameraToSearchResult(controller, result);
    }
  }

  Future<void> _moveCameraToSearchResult(
    KakaoMapController controller,
    KakaoSearchResult result,
  ) async {
    try {
      await controller.moveCamera(
        CameraUpdate.newCenterPosition(
          LatLng(result.latitude, result.longitude),
        ),
        animation: const CameraAnimation(500),
      );
    } catch (_) {
      if (mounted &&
          _controller == controller &&
          _selectedSearchResult == result) {
        _showLocationMessage('검색 정보는 선택됐지만 지도 이동에 실패했습니다.');
      }
    }
  }

  // Geolocator
  Poi? _myLocationPoi; // 지도에 추가한 파란 점 객체
  geo.Position? _currentPosition; // 최근 수신한 위치

  StreamSubscription<void>? _positionSubscription; // 실시간 위치 수신을 중단할 때 사용할 구독

  bool _isLocating = false; // 권한 확인 및 최초 위치 조회 진행여부
  bool _gpsSelected = false;
  bool _isForeground = true; // 앱이 화면에 있는지 여부
  int _locationGeneration = 0; // 중단 전에 시작된 작업의 늦은 결과를 구분

  void _onMapReady(KakaoMapController controller) async {
    if (!mounted) return; // 이 State가 위젯 트리에 연결되어 있는지 확인
    if (_controller == controller) return;

    if (_controller != null) _stopLocation();
    setState(() {
      _controller = controller;
      _locationDotStyle = PoiStyle(
        icon: KImage.fromAsset('assets/images/current-pin.png', 24, 24),
        anchor: const KPoint(0.5, 0.5),
      );
      _locationHeadingStyle = PoiStyle(
        icon: KImage.fromAsset('assets/images/current-heading.png', 40, 40),
        anchor: const KPoint(0.5, 0.5),
      );
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

    final selected = _selectedSearchResult;
    if (selected != null) {
      await _moveCameraToSearchResult(controller, selected);
    }
    await _startLocation(shouldMoveCamera: () => _selectedSearchResult == null);
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

    await controller.labelLayer.addPoi(
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
  }

  // geolocator
  // 위치 서비스와 권한을 확인하는 함수
  void _showLocationMessage(String message) {
    if (!mounted) return;

    GlassToast.show(context, message: message, type: GlassToastType.info);
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
  Future<bool> _moveCameraToMyLocation(int generation) async {
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
  Future<bool> _startLocation({
    bool Function()? shouldMoveCamera,
    bool requestPermission = true,
  }) async {
    if (!mounted || !_isForeground || _controller == null || _isLocating) {
      return false;
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
        return false;
      }

      // 이미 위치를 수신 중이면 최근 위치로 카메라만 이동합니다.
      if (_positionSubscription != null && _currentPosition != null) {
        if (shouldMoveCamera?.call() ?? false) {
          return await _moveCameraToMyLocation(generation);
        }
        return false;
      }

      // 최초 위치를 한 번 조회합니다.
      final firstPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

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

      if (shouldMoveCamera?.call() ?? false) {
        return await _moveCameraToMyLocation(generation);
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
    return false;
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
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel();
    _searchDio.close(force: true);
    _searchController.dispose();
    _searchFocus.dispose();
    _busNumberController.dispose();
    _busNumberFocus.dispose();
    super.dispose();
  }

  // 현재 위치 버튼용 함수
  Future<void> _goToMyLocation() async {
    if (_controller == null || _isLocating || !_isForeground) return;

    final generation = _locationGeneration;
    setState(() => _gpsSelected = true);
    final moved = await _startLocation(shouldMoveCamera: () => _gpsSelected);
    if (!moved && _isLocationActive(generation) && _gpsSelected) {
      setState(() => _gpsSelected = false);
    }
  }

  void _onCameraMoveStart(GestureType gesture) {
    if (gesture != GestureType.unknown && _gpsSelected) {
      setState(() => _gpsSelected = false);
    }
  }

  // 2. Add MapView Widget
  @override
  Widget build(BuildContext context) {
    final barGlassSettings = LiquidGlassSettings.ios27Light.copyWith(
      glassColor: const Color(0x7DF8F8F8),
      frostOpacity: 0.6,
    );
    const mapButtonSize = 48.0;
    GlassIconButton glassIconButton({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      double size = mapButtonSize,
      Color? iconColor,
    }) {
      return GlassIconButton(
        icon: Icon(icon, color: iconColor),
        quality: GlassQuality.standard,
        size: size,
        semanticLabel: label,
        onPressed: onPressed,
        surfaceStyle: GlassSurfaceStyle.glass,
        style: GlassButtonStyle.filled,
        settings: barGlassSettings,
      );
    }

    const searchTabIndex = 1;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final routeSheetVisible = _routeSheetState != GlassSheetState.hidden;
    final hideAppBar =
        _routeSheetState == GlassSheetState.full ||
        (routeSheetVisible && keyboardHeight > 0);
    final pageFocusScope = FocusScope.of(context);
    const appBarPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    final appBar = GlassAppBar(
      padding: appBarPadding,
      title: const Text(
        '거슬렁',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      ),
      centerTitle: false,
      actions: [
        glassIconButton(
          icon: Icons.notifications_none_rounded,
          label: '알림 내역',
          size: 44,
          onPressed: () {
            GlassToast.show(
              context,
              message: '알림 내역 화면은 준비 중이에요.',
              type: GlassToastType.info,
            );
          },
        ),
        glassIconButton(
          icon: Icons.settings,
          label: '설정',
          size: 44,
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
    const tabWidth = 150.0;
    const tabs = [
      GlassTab(icon: Icon(Icons.route), label: '내 경로'),
      GlassTab(icon: Icon(Icons.map), label: '길찾기'),
    ];
    final tabBar = GlassTabBar.bottom(
      quality: GlassQuality.standard,
      tabWidth: tabWidth,
      settings: barGlassSettings,
      selectedIconColor: _brand,
      selectedLabelColor: _brand,
      tabs: tabs,
      selectedIndex: _tabIndex,
      onTabSelected: (index) {
        if (index == _tabIndex) {
          if (index == searchTabIndex) {
            _routeSheet.snapToState(
              _routeSheetState == GlassSheetState.hidden
                  ? GlassSheetState.half
                  : GlassSheetState.hidden,
            );
          }
          return;
        }
        FocusScope.of(context).unfocus();
        if (_editingOrigin != null) _cancelPlaceEdit();

        setState(() {
          _tabIndex = index;
        });
        _routeSheet.snapToState(
          index == searchTabIndex
              ? GlassSheetState.half
              : GlassSheetState.hidden,
        );
      },
    );

    // UI Build
    return GlassScaffold(
      resizeToAvoidBottomInset:
          false, // 키보드가 표시돼도 본문을 줄이지 않고, 키보드가 본문 위를 덮도록 한다.
      appBar: PreferredSize(
        preferredSize: appBar.preferredSize,
        child: Offstage(offstage: hideAppBar, child: appBar),
      ),
      bottomBar: PreferredSize(
        preferredSize: tabBar.preferredSize,
        child: Center(
          heightFactor: 1,
          child: SizedBox(
            width: tabWidth * tabs.length + 2 * tabBar.horizontalPadding,
            child: tabBar,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safeArea = MediaQuery.viewPaddingOf(context);
          final mapControlsRight = safeArea.right + 16;
          final tabBarInset = safeArea.bottom + tabBar.preferredSize.height;
          final gpsBottom = math.max(keyboardHeight, tabBarInset) + 12;
          final sheetHeight = math.max(
            0.0,
            constraints.maxHeight - safeArea.top - keyboardHeight,
          );

          Widget placeRow({
            required bool origin,
            required KakaoSearchResult? place,
          }) {
            final label = origin ? '출발지' : '목적지';

            if (_editingOrigin == origin) {
              return RouteSearchField(
                key: ValueKey(label),
                label: label,
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onSubmitted: (value) => _onSearchChanged(value, submit: true),
                settings: barGlassSettings,
                onCancel: _cancelPlaceEdit,
              );
            }

            return RoutePanelRow(
              icon: origin ? Icons.my_location : Icons.place_outlined,
              title: place?.name ?? label,
              subtitle: place == null ? null : label,
              onTap: () => _editPlace(origin: origin),
            );
          }

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
                  onCameraMoveStart: _onCameraMoveStart,
                  onMapError: (error) {
                    debugPrint('Salmon 카카오맵 오류: $error');
                  },
                ),
              ),

              Positioned(
                right: mapControlsRight,
                bottom: gpsBottom,
                child: glassIconButton(
                  icon: Icons.my_location,
                  label: '현재 위치로 이동',
                  iconColor: _gpsSelected ? _brand : null,
                  onPressed: _controller == null || _isLocating
                      ? null
                      : _goToMyLocation,
                ),
              ),

              // GlassScaffold paints the bottom bar above this body stack.
              if (sheetHeight > 48)
                Positioned.fill(
                  top: safeArea.top,
                  bottom: keyboardHeight,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        GlassModalSheet(
                          controller: _routeSheet,
                          initialState: _routeSheetState,
                          halfSize: math.min(
                            constraints.maxHeight * 0.42,
                            sheetHeight * 0.85,
                          ),
                          fullSize: sheetHeight,
                          resistance: 0,
                          horizontalMargin: 0,
                          bottomMargin: 0,
                          topBorderRadius: 24,
                          bottomBorderRadius: 0,
                          fullTopBorderRadius: 0,
                          settings: barGlassSettings.copyWith(
                            glassColor: Colors.white,
                            blur: 0,
                            frost: 0,
                          ),
                          enableInteractionGlow: false,
                          enableSaturationGlow: false,
                          maintainContentGlass: false,
                          onStateChanged: _onRouteSheetStateChanged,
                          // Inputs use the page focus scope so the keyboard
                          // does not trigger the sheet's default full snap.
                          child: Focus(
                            parentNode: pageFocusScope,
                            canRequestFocus: false,
                            descendantsAreFocusable: routeSheetVisible,
                            child: RouteSearchPanel(
                              settings: barGlassSettings,
                              bottomInset: keyboardHeight > 0
                                  ? 0
                                  : tabBarInset + safeArea.bottom,
                              keyboardVisible: keyboardHeight > 0,
                              origin: placeRow(origin: true, place: _origin),
                              destination: placeRow(
                                origin: false,
                                place: _destination,
                              ),
                              busField: TextField(
                                controller: _busNumberController,
                                focusNode: _busNumberFocus,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.directions_bus_outlined,
                                  ),
                                  labelText: '선호 광역버스 (선택)',
                                  hintText: '예: M5107',
                                  border: OutlineInputBorder(),
                                ),
                                autocorrect: false,
                                textCapitalization:
                                    TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                              ),
                              suggestions: _editingOrigin == null
                                  ? null
                                  : RouteSearchScreen(
                                      isSearching: _isSearching,
                                      message: _searchMessage,
                                      results: _searchResults,
                                      onResultSelected: _selectSearchResult,
                                    ),
                              onSearch: _origin == null || _destination == null
                                  ? null
                                  : _openRouteResults,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
