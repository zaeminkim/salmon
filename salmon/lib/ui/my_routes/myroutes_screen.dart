import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:geolocator/geolocator.dart' as geo; // geo: 패키지에 붙이는 별명
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../data/journeys/journey_example_api.dart';
import '../core/journey_presentation.dart';
import '../route_results/journey_preview_map.dart'
    show journeyPosition, journeyShapePoints;
import '../route_results/routeresults_screen.dart';
import '../route_search/bus_route_search_field.dart';
import '../route_search/routesearch_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/saved_routes_overlay.dart';

const _brand = Color(0xFFD9553E);

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key, this.journeyClient, this.savedRouteExample});

  final Dio? journeyClient;
  final Future<Map<String, dynamic>>? savedRouteExample;

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
  // 위젯에 사용할 상태 객체를 만들어 반환함MyRoutesScreen
}

class _MyRoutesScreenState extends State<MyRoutesScreen>
    with
        WidgetsBindingObserver // 앱의 백그라운드 전환과 복귀를 감지
        {
  static const _cityHall = LatLng(37.5665, 126.9780);

  static const _headingChannel = EventChannel('salmon/device_heading');

  KakaoMapController? _controller;
  StreamSubscription<void>? _headingSubscription;
  PoiStyle? _locationDotStyle;
  PoiStyle? _locationHeadingStyle;

  int _tabIndex = 0;
  bool _savedExampleSelected = true;
  late final _savedExample = widget.savedRouteExample ?? loadJourneyExample();
  final _savedRouteRemovals = <Future<void> Function()>[];
  final _savedRoutePinStyles = <bool, PoiStyle>{};
  PolylineStyle _savedRouteLineStyle = PolylineStyle(_brand, 4);
  Future<void> _savedRouteUpdates = Future<void>.value();
  int _savedRouteRevision = 0;
  bool get _showSavedExample => _tabIndex == 0 && _savedExampleSelected;

  // salmon.local.json의 REST API 키를 빌드 시 읽습니다.
  static const _restApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();

  KakaoSearchResult? _origin;
  KakaoSearchResult? _destination;
  final _routePins = <bool, Poi>{};
  final _routePinStyles = <bool, PoiStyle>{};
  Future<void> _routePinUpdates = Future<void>.value();
  bool? _editingOrigin; // true: 출발지, false: 목적지, null: 편집 종료
  final _routeSheet = GlassModalSheetController();
  final _busNumberController = TextEditingController();
  final _busNumberFocus = FocusNode();
  String? _selectedBusRoute;
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

  void _startPlaceEdit(bool origin) {
    final focus = origin ? _originFocus : _destinationFocus;
    if (!focus.hasFocus) return;
    _editingOrigin = origin;
    final place = origin ? _origin : _destination;
    final controller = origin ? _originController : _destinationController;
    _onSearchChanged(place == null ? controller.text : '');
  }

  void _cancelPlaceEdit() {
    if (_editingOrigin == null) return;
    _onSearchChanged('');
    setState(() => _editingOrigin = null);
  }

  void _onRouteSheetStateChanged(GlassSheetState state) {
    if (state != GlassSheetState.full) {
      _busNumberFocus.unfocus();
      _originFocus.unfocus();
      _destinationFocus.unfocus();
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
    final enteredBusNumber = _busNumberController.text
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RouteResultsScreen(
          origin: origin,
          destination: destination,
          preferredBusNumber: enteredBusNumber.isEmpty
              ? null
              : _selectedBusRoute ?? enteredBusNumber,
          preferredBusLabel: enteredBusNumber,
          journeyClient: widget.journeyClient,
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
    _originFocus.unfocus();
    _destinationFocus.unfocus();
    (editingOrigin ? _originController : _destinationController).text =
        result.name;
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
      _updateRoutePin(controller, origin: editingOrigin, place: result);
      await _moveCameraToSearchResult(controller, result);
    }
  }

  void _updateRoutePin(
    KakaoMapController controller, {
    required bool origin,
    required KakaoSearchResult? place,
  }) {
    KakaoSearchResult? activePlace() =>
        _tabIndex == 1 ? (origin ? _origin : _destination) : null;
    // Keep native add/remove calls in order when a selection quickly changes.
    _routePinUpdates = _routePinUpdates.then((_) async {
      if (!mounted ||
          _controller != controller ||
          !identical(activePlace(), place)) {
        return;
      }

      try {
        final previous = _routePins[origin];
        if (previous != null) {
          await previous.remove();
          if (!mounted || _controller != controller) return;
          _routePins.remove(origin);
        }
        if (place == null || !identical(activePlace(), place)) {
          return;
        }

        final pin = await controller.labelLayer.addPoi(
          LatLng(place.latitude, place.longitude),
          id: origin ? 'route-origin' : 'route-destination',
          text: origin ? '출발지' : '목적지',
          rank: 9000,
          style: _routePinStyles.putIfAbsent(
            origin,
            () => PoiStyle(
              icon: KImage.fromAsset('assets/images/location-pin.png', 28, 36),
              anchor: const KPoint(0.5, 1.0),
              textStyle: [
                PoiTextStyle(
                  size: 15,
                  color: origin
                      ? const Color(0xFF246046)
                      : const Color(0xFF9A3627),
                  stroke: 2,
                  strokeColor: Colors.white,
                ),
              ],
            ),
          ),
        );
        if (mounted && _controller == controller) _routePins[origin] = pin;
      } catch (error) {
        debugPrint('길찾기 핀 갱신 실패: $error');
      }
    });
  }

  void _syncSearchPins(KakaoMapController controller) {
    _updateRoutePin(
      controller,
      origin: true,
      place: _tabIndex == 1 ? _origin : null,
    );
    _updateRoutePin(
      controller,
      origin: false,
      place: _tabIndex == 1 ? _destination : null,
    );
  }

  void _onSavedExampleSelected(bool selected) {
    if (_savedExampleSelected == selected) return;
    _savedExampleSelected = selected;
    _syncSavedRouteMap();
  }

  void _syncSavedRouteMap() {
    final controller = _controller;
    if (controller == null) return;
    final revision = ++_savedRouteRevision;
    bool hasMap() => mounted && identical(_controller, controller);
    bool isCurrent() => hasMap() && revision == _savedRouteRevision;

    _savedRouteUpdates = _savedRouteUpdates.then((_) async {
      if (!isCurrent()) return;
      try {
        while (_savedRouteRemovals.isNotEmpty) {
          await _savedRouteRemovals.last();
          if (!hasMap()) return;
          _savedRouteRemovals.removeLast();
        }
        if (!isCurrent() || !_showSavedExample) return;
        final example = await _savedExample;
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
                    style: PolylineStyle(journeySegmentColor(segment), 4),
                  ),
        ];
        if (lines.isEmpty && origin != destination) {
          lines.add((
            points: [origin, destination],
            style: _savedRouteLineStyle,
          ));
        }

        for (final (position, isOrigin) in [
          (origin, true),
          (destination, false),
        ]) {
          final pin = await controller.labelLayer.addPoi(
            position,
            id: isOrigin ? 'saved-route-origin' : 'saved-route-destination',
            text: isOrigin ? '출발지' : '도착지',
            rank: 9000,
            style: _savedRoutePinStyles.putIfAbsent(
              isOrigin,
              () => PoiStyle(
                icon: KImage.fromAsset(
                  'assets/images/location-pin.png',
                  28,
                  36,
                ),
                anchor: const KPoint(0.5, 1.0),
                textStyle: [
                  PoiTextStyle(
                    size: 15,
                    color: isOrigin
                        ? const Color(0xFF246046)
                        : const Color(0xFF9A3627),
                    stroke: 2,
                    strokeColor: Colors.white,
                  ),
                ],
              ),
            ),
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
        if (_gpsSelected) setState(() => _gpsSelected = false);
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
    _routePins.clear();
    _routePinStyles.clear();
    _savedRouteRemovals.clear();
    _savedRoutePinStyles.clear();
    _savedRouteLineStyle = PolylineStyle(_brand, 4);
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

    _syncSearchPins(controller);
    _syncSavedRouteMap();

    final selected = _selectedSearchResult;
    if (_tabIndex == 1 && selected != null) {
      await _moveCameraToSearchResult(controller, selected);
    }
    await _startLocation(
      shouldMoveCamera: () =>
          !_showSavedExample &&
          (_tabIndex == 0 || _selectedSearchResult == null),
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
    _originFocus.addListener(() => _startPlaceEdit(true));
    _destinationFocus.addListener(() => _startPlaceEdit(false));
    _busNumberFocus.addListener(() {
      if (_busNumberFocus.hasFocus) _cancelPlaceEdit();
    });

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
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
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
      glassColor: const Color(0xBFFFFFFF),
      rimShade: 1.7,
      rimShadeEnds: 0.45,
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
    final pageFocusScope = FocusScope.of(context);
    const appBarPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
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
        final controller = _controller;
        if (controller != null) _syncSearchPins(controller);
        _syncSavedRouteMap();
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
      edgeStyle: GlassScrollEdgeStyle.blur,
      bottomEdgeFade: false,
      maxSigma: 24.0,
      appBar: appBar,
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
          final appBarBottom =
              safeArea.top +
              appBar.preferredSize.height +
              appBarPadding.vertical;
          final mapControlsRight = safeArea.right + 20;
          final tabBarInset = safeArea.bottom + tabBar.preferredSize.height;
          final savedCardHeight = math.min(
            SavedRoutesOverlay.maxCardHeight,
            math.max(
              0.0,
              constraints.maxHeight - appBarBottom - tabBarInset - 120,
            ),
          );
          final gpsBottom =
              math.max(keyboardHeight, tabBarInset) +
              12 +
              (_tabIndex == 0 ? savedCardHeight + 8 : 0);
          final sheetHeight = math.max(
            0.0,
            constraints.maxHeight - appBarBottom - keyboardHeight,
          );

          InputDecoration fieldDecoration(String hint, IconData icon) {
            final border = OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            );
            return InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
              filled: true,
              fillColor: Colors.white,
              border: border,
              enabledBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFFDADCE0)),
              ),
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: _brand, width: 1.5),
              ),
            );
          }

          Widget placeField({required bool origin}) {
            return TextField(
              decoration: fieldDecoration(
                origin ? '출발지' : '목적지',
                origin ? Icons.my_location : Icons.place_outlined,
              ),
              controller: origin ? _originController : _destinationController,
              focusNode: origin ? _originFocus : _destinationFocus,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                _editingOrigin = origin;
                final previous = origin ? _origin : _destination;
                if (origin) {
                  _origin = null;
                } else {
                  _destination = null;
                }
                if (previous != null) {
                  if (identical(_selectedSearchResult, previous)) {
                    _selectedSearchResult = _origin ?? _destination;
                  }
                  final controller = _controller;
                  if (controller != null) {
                    _updateRoutePin(controller, origin: origin, place: null);
                  }
                }
                _onSearchChanged(value);
              },
              onSubmitted: (value) => _onSearchChanged(value, submit: true),
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

              Positioned.fill(
                top: appBarBottom + 8,
                bottom: tabBarInset,
                left: safeArea.left,
                right: safeArea.right,
                child: Offstage(
                  offstage: _tabIndex != 0,
                  child: SavedRoutesOverlay(
                    settings: barGlassSettings,
                    cardHeight: savedCardHeight,
                    example: _savedExample,
                    onExampleSelected: _onSavedExampleSelected,
                  ),
                ),
              ),

              // GlassScaffold paints the bottom bar above this body stack.
              if (sheetHeight > 48)
                Positioned.fill(
                  top: appBarBottom,
                  bottom: keyboardHeight,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        GlassModalSheet(
                          quality: GlassQuality.minimal,
                          controller: _routeSheet,
                          initialState: _routeSheetState,
                          halfSize: math.min(
                            constraints.maxHeight * 0.46,
                            sheetHeight * 0.85,
                          ),
                          fullSize: sheetHeight,
                          resistance: 0,
                          horizontalMargin: 0,
                          bottomMargin: 0,
                          topBorderRadius: 24,
                          bottomBorderRadius: 0,
                          fullTopBorderRadius: null,
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
                              bottomInset: keyboardHeight > 0
                                  ? 0
                                  : tabBarInset + safeArea.bottom,
                              keyboardVisible: keyboardHeight > 0,
                              origin: placeField(origin: true),
                              destination: placeField(origin: false),
                              busField: BusRouteSearchField(
                                decoration: fieldDecoration(
                                  '선호 광역버스 (선택)',
                                  Icons.directions_bus_outlined,
                                ),
                                controller: _busNumberController,
                                focusNode: _busNumberFocus,
                                onSelectionChanged: (route) {
                                  _selectedBusRoute = route;
                                },
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
