import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../data/journeys/journey_example_api.dart';
import '../route_results/routeresults_screen.dart';
import '../route_search/bus_route_search_field.dart';
import '../route_search/kakao_place_suggestions.dart';
import '../route_search/routesearch_screen.dart';
import '../route_search/search_field_clear_button.dart';
import '../settings/settings_screen.dart';
import 'map_location_tracker.dart';
import 'route_map_overlays.dart';
import 'route_sheet.dart';
import '../core/widgets/app_map_icon_button.dart';
import '../core/widgets/journey_map_geometry.dart';
import '../core/widgets/saved_routes_overlay.dart';

const _brand = Color(0xFFD9553E);
const _appBarButtonSize = 48.0;
const _mapButtonSize = 48.0;
const _mapButtonGap = 12.0;
const _mapControlsHeight = 2 * _mapButtonSize + _mapButtonGap;

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key, this.journeyClient, this.savedRouteExample});

  final Dio? journeyClient;
  final Future<Map<String, dynamic>>? savedRouteExample;

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
  // 위젯에 사용할 상태 객체를 만들어 반환함: MyRoutesScreen
}

class _MyRoutesScreenState extends State<MyRoutesScreen>
    with
        WidgetsBindingObserver // 앱의 백그라운드 전환과 복귀를 감지
        {
  static const _searchTabIndex = 1;
  static const _cityHall = LatLng(37.5665, 126.9780);

  KakaoMapController? _controller;
  bool _locationRouteVisible = true;
  bool _locationAppVisible = true;
  late final _location = MapLocationTracker(
    onChanged: () {
      if (mounted) setState(() {});
    },
    onMessage: _showLocationMessage,
  );

  late final _mapOverlays = RouteMapOverlays(
    activeSearchPlace: (origin) =>
        _tabIndex == _searchTabIndex ? (origin ? _origin : _destination) : null,
    shouldShowSavedExample: () => _showSavedExample,
    loadSavedExample: () => _savedExample,
    onSavedRouteCameraMove: _location.clearSelection,
    buildPinIcon: _buildRoutePinIcon,
  );

  int _tabIndex = 0;
  bool _savedExampleSelected = true;
  late final _savedExample = widget.savedRouteExample ?? loadJourneyExample();
  bool get _showSavedExample => _tabIndex == 0 && _savedExampleSelected;
  ({LatLng origin, LatLng destination})? _savedRouteEndpoints;
  RouteCameraView? _routeCameraView;
  bool _movingRouteCamera = false;

  ({LatLng origin, LatLng destination})? get _activeRouteEndpoints {
    if (_tabIndex == 0) return _showSavedExample ? _savedRouteEndpoints : null;
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return null;
    return (
      origin: LatLng(origin.latitude, origin.longitude),
      destination: LatLng(destination.latitude, destination.longitude),
    );
  }

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();

  KakaoSearchResult? _origin;
  KakaoSearchResult? _destination;
  bool? _editingOrigin; // true: 출발지, false: 목적지, null: 편집 종료
  late final _routeSheet = RouteSheetController(
    onPositionChanged: _onRouteSheetPositionChanged,
  );
  final _busNumberController = TextEditingController();
  final _busNumberFocus = FocusNode();
  String? _selectedBusRoute;
  final _placeSuggestions = KakaoPlaceSuggestions();
  int _placeEditRevision = 0;
  bool _locatingForPlace = false;
  KakaoSearchResult? _selectedSearchResult;

  // 새 입력이 오면 이전 타이머/요청을 중단하고 400ms 후 검색합니다.
  void _onSearchChanged(String value, {bool submit = false}) {
    if (_editingOrigin == null) return;
    ++_placeEditRevision;
    _placeSuggestions.update(value, submit: submit);
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

  void _onRouteSheetPositionChanged(
    RouteSheetPosition previous,
    RouteSheetPosition position,
  ) {
    if (position != RouteSheetPosition.full &&
        (position == RouteSheetPosition.hidden ||
            previous == RouteSheetPosition.full)) {
      _busNumberFocus.unfocus();
      _originFocus.unfocus();
      _destinationFocus.unfocus();
    }
    if (position == RouteSheetPosition.hidden && _editingOrigin != null) {
      _cancelPlaceEdit();
    }
    setState(() {});
  }

  Future<void> _openRouteResults() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return;
    final enteredBusNumber = _busNumberController.text
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    FocusScope.of(context).unfocus();
    final finished = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) {
          return RouteResultsScreen(
            origin: origin,
            destination: destination,
            preferredBusNumber: enteredBusNumber.isEmpty
                ? null
                : _selectedBusRoute ?? enteredBusNumber,
            preferredBusLabel: enteredBusNumber,
            journeyClient: widget.journeyClient,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final position = animation
              .drive(CurveTween(curve: Curves.easeInOutCubic))
              .drive(
                Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
              );

          return SlideTransition(position: position, child: child);
        },
      ),
    );
    if (finished == true && mounted) {
      _routeSheet.moveTo(RouteSheetPosition.half);
    }
  }

  Future<void> _selectMyLocation() async {
    if (_editingOrigin == null || _locatingForPlace) return;
    final revision = _placeEditRevision;
    bool isCurrentEdit() =>
        mounted && _editingOrigin != null && _placeEditRevision == revision;

    setState(() => _locatingForPlace = true);
    try {
      final position = await _location.locateForSearch((message) {
        if (isCurrentEdit()) _showLocationMessage(message);
      });
      if (position == null || !isCurrentEdit()) return;
      await _selectSearchResult(
        KakaoSearchResult(
          name: '내 위치',
          address: '',
          latitude: position.latitude,
          longitude: position.longitude,
          isAddress: false,
        ),
      );
    } finally {
      if (mounted) setState(() => _locatingForPlace = false);
    }
  }

  Future<void> _selectSearchResult(KakaoSearchResult result) async {
    final editingOrigin = _editingOrigin;
    if (editingOrigin == null) return;

    _placeSuggestions.update('');
    _originFocus.unfocus();
    _destinationFocus.unfocus();
    (editingOrigin ? _originController : _destinationController).text =
        result.name;
    _location.clearSelection();
    setState(() {
      if (editingOrigin) {
        _origin = result;
      } else {
        _destination = result;
      }
      _editingOrigin = null;

      _selectedSearchResult = result;
      _routeCameraView = null;
    });
    final controller = _controller;
    if (controller != null) {
      _mapOverlays.updateSearchPin(origin: editingOrigin, place: result);
      await _moveCameraToSearchResult(controller, result);
    }
  }

  void _onSavedExampleSelected(bool selected) {
    if (_savedExampleSelected == selected) return;
    setState(() {
      _savedExampleSelected = selected;
      _routeCameraView = null;
    });
    _mapOverlays.syncSavedRoute();
  }

  void _clearRouteCameraSelection() {
    if (_routeCameraView != null) setState(() => _routeCameraView = null);
  }

  Future<void> _moveCameraToRoute() async {
    final controller = _controller;
    final endpoints = _activeRouteEndpoints;
    if (controller == null || endpoints == null || _movingRouteCamera) return;

    final next = _routeCameraView?.next ?? RouteCameraView.overview;
    final update = next.cameraUpdate(endpoints.origin, endpoints.destination);

    _location.clearSelection();
    if (_tabIndex == _searchTabIndex) {
      FocusScope.of(context).unfocus();
      if (_routeSheet.heightFraction > 0) {
        _routeSheet.moveTo(RouteSheetPosition.hidden);
      }
    }
    setState(() {
      _routeCameraView = next;
      _movingRouteCamera = true;
    });
    try {
      await controller.moveCamera(
        update,
        animation: const CameraAnimation(350),
      );
    } catch (_) {
      if (!mounted || _controller != controller || _routeCameraView != next) {
        return;
      }
      _clearRouteCameraSelection();
      _showLocationMessage('경로 위치로 지도 이동에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _movingRouteCamera = false);
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

  Future<KImage?> _buildRoutePinIcon(String label) async {
    final asset = ExactAssetImage(
      'assets/images/location-pin.png',
      bundle: DefaultAssetBundle.of(context),
    );
    await precacheImage(asset, context);
    if (!mounted) return null;

    return KImage.fromWidget(
      Stack(
        fit: StackFit.expand,
        children: [
          Image(image: asset, fit: BoxFit.fill),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            height: 13,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      const Size(26, 33),
      context: context,
    );
  }

  void _onMapReady(KakaoMapController controller) async {
    if (!mounted) return; // 이 State가 위젯 트리에 연결되어 있는지 확인
    if (_controller == controller) return;

    _mapOverlays.attach(controller);
    setState(() {
      _controller = controller;
      _location.attach(controller);
      _routeCameraView = null;
    });
    debugPrint('거슬렁 카카오맵 준비 완료');

    _mapOverlays.syncSearchPins();
    _mapOverlays.syncSavedRoute();

    final selected = _selectedSearchResult;
    if (_tabIndex == _searchTabIndex && selected != null) {
      await _moveCameraToSearchResult(controller, selected);
    }
    await _location.start(
      shouldMoveCamera: () =>
          !_showSavedExample &&
          (_tabIndex == 0 || _selectedSearchResult == null),
    );
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;

    GlassToast.show(context, message: message, type: GlassToastType.info);
  }

  // 앱 상태변화와 페이지 종료 처리
  @override
  void initState() {
    super.initState();
    _savedExample.then<void>((example) {
      final origin = journeyPosition(example['origin']);
      final destination = journeyPosition(example['destination']);
      if (!mounted || origin == null || destination == null) return;
      setState(() {
        _savedRouteEndpoints = (origin: origin, destination: destination);
      });
    }, onError: (Object _) {});
    _placeSuggestions.addListener(() => setState(() {}));
    _originFocus.addListener(() => _startPlaceEdit(true));
    _destinationFocus.addListener(() => _startPlaceEdit(false));
    _busNumberFocus.addListener(() {
      if (_busNumberFocus.hasFocus) _cancelPlaceEdit();
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.isCurrentOf(context) ?? true;
    if (visible == _locationRouteVisible) return;
    _locationRouteVisible = visible;
    _syncLocationVisibility();
  }

  void _syncLocationVisibility() {
    if (_locationRouteVisible && _locationAppVisible) {
      _location.resume();
    } else {
      _location.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _locationAppVisible = false;
      _syncLocationVisibility();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _locationAppVisible = true;
      _syncLocationVisibility();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeSheet.dispose();

    _mapOverlays.dispose();
    _location.dispose();
    _placeSuggestions.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _busNumberController.dispose();
    _busNumberFocus.dispose();
    super.dispose();
  }

  // 탭을 바꾸면 지도 오버레이와 길찾기 시트도 함께 갱신합니다.
  void _onTabSelected(int index) {
    if (index == _tabIndex) {
      if (index == _searchTabIndex) {
        _routeSheet.toggle();
      }
      return;
    }
    FocusScope.of(context).unfocus();
    if (_editingOrigin != null) _cancelPlaceEdit();

    setState(() {
      _tabIndex = index;
      _routeCameraView = null;
    });
    _mapOverlays.syncSearchPins();
    _mapOverlays.syncSavedRoute();
    _routeSheet.moveTo(
      index == _searchTabIndex
          ? RouteSheetPosition.half
          : RouteSheetPosition.hidden,
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
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

  // 장소 입력이 바뀌면 이전 선택과 지도 핀을 지웁니다.
  void _onPlaceChanged(
    bool origin,
    String value, {
    bool updateSuggestions = true,
  }) {
    final previous = origin ? _origin : _destination;
    if (previous != null) {
      setState(() {
        if (origin) {
          _origin = null;
        } else {
          _destination = null;
        }
        if (identical(_selectedSearchResult, previous)) {
          _selectedSearchResult = _origin ?? _destination;
        }
        _routeCameraView = null;
      });
      _mapOverlays.updateSearchPin(origin: origin, place: null);
    }
    if (updateSuggestions) {
      _editingOrigin = origin;
      _onSearchChanged(value);
    }
  }

  Widget _placeField({required bool origin}) {
    final label = origin ? '출발지' : '목적지';
    final controller = origin ? _originController : _destinationController;
    final focusNode = origin ? _originFocus : _destinationFocus;
    return TextField(
      key: ValueKey(label),
      decoration:
          _fieldDecoration(
            label,
            origin ? Icons.my_location : Icons.place_outlined,
          ).copyWith(
            suffixIcon: SearchFieldClearButton(
              controller: controller,
              tooltip: '$label 지우기',
              onCleared: () => _onPlaceChanged(
                origin,
                '',
                updateSuggestions:
                    focusNode.hasFocus || _editingOrigin == origin,
              ),
            ),
          ),
      controller: controller,
      focusNode: focusNode,
      autocorrect: false,
      textInputAction: TextInputAction.search,
      onChanged: (value) => _onPlaceChanged(origin, value),
      onSubmitted: (value) => _onSearchChanged(value, submit: true),
    );
  }

  Widget _positionMapControls({
    required Widget controls,
    required double viewportHeight,
    required double appBarBottom,
    required double routeSheetTop,
    required double right,
    required double tabBarInset,
    required double savedCardHeight,
  }) {
    return AnimatedBuilder(
      animation: _routeSheet.heightChanges,
      child: controls,
      builder: (context, child) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final sheetViewport = viewportHeight - routeSheetTop - keyboard;
        final sheetHeight = _tabIndex == _searchTabIndex && sheetViewport > 48
            ? sheetViewport * _routeSheet.heightFraction
            : 0.0;
        final cardOffset = _tabIndex == 0
            ? savedCardHeight + SavedRoutesOverlay.paginationHeight + 8
            : 0.0;
        final restingBottom =
            math.max(keyboard, tabBarInset) + _mapButtonGap + cardOffset;
        // 시트를 끝까지 올려도 지도 버튼 두 개가 모두 보입니다.
        final bottom = math.min(
          math.max(restingBottom, keyboard + sheetHeight + _mapButtonGap),
          math.max(0.0, viewportHeight - appBarBottom - _mapControlsHeight),
        );
        return Padding(
          padding: EdgeInsets.only(right: right, bottom: bottom),
          child: Align(alignment: Alignment.bottomRight, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.viewPaddingOf(context);
    final pageFocusScope = FocusScope.of(context);
    const appBarPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    final appBar = GlassAppBar(
      toolbarHeight: _appBarButtonSize,
      padding: appBarPadding,
      title: const Text(
        '거슬렁',
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
      ),
      centerTitle: false,
      actions: [
        AppMapIconButton(
          icon: Icons.notifications_none_rounded,
          label: '알림 내역',
          size: _appBarButtonSize,
          onPressed: () {
            GlassToast.show(
              context,
              message: '알림 내역 화면은 준비 중이에요.',
              type: GlassToastType.info,
            );
          },
        ),
        AppMapIconButton(
          icon: Icons.settings,
          label: '설정',
          size: _appBarButtonSize,
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
    final appBarHeight = appBar.preferredSize.height + appBarPadding.vertical;
    const tabWidth = 150.0;
    const tabs = [
      GlassTab(icon: Icon(Icons.route), label: '내 경로'),
      GlassTab(icon: Icon(Icons.map), label: '길찾기'),
    ];
    final tabBar = GlassTabBar.bottom(
      textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      quality: GlassQuality.minimal,
      tabWidth: tabWidth,
      settings: appMapGlassSettings,
      selectedIconColor: _brand,
      selectedLabelColor: _brand,
      tabs: tabs,
      selectedIndex: _tabIndex,
      onTabSelected: _onTabSelected,
    );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset:
          false, // 키보드가 표시돼도 본문을 줄이지 않고, 키보드가 본문 위를 덮도록 한다.
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: ColoredBox(color: const ui.Color(0x02FFFFFF), child: appBar),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: defaultTargetPlatform == TargetPlatform.android,
        child: GlassIsolationScope(
          isolated: true,
          defaultQuality: GlassQuality.minimal,
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              width: tabWidth * tabs.length + 2 * tabBar.horizontalPadding,
              child: Stack(
                children: [
                  tabBar,
                  Positioned(
                    left: tabBar.horizontalPadding,
                    right: tabBar.horizontalPadding,
                    top: tabBar.verticalPadding,
                    height: tabBar.barHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tabBar.barBorderRadius,
                            ),
                            side: appMapGlassOutline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final appBarBottom = safeArea.top + appBarHeight;
          final routeSheetTop =
              appBarBottom + _mapControlsHeight + _mapButtonGap;
          final mapControlsRight = safeArea.right + 20;
          final tabBarInset = safeArea.bottom + tabBar.preferredSize.height;
          final savedCardHeight = math.min(
            SavedRoutesOverlay.maxCardHeight,
            math.max(
              0.0,
              constraints.maxHeight -
                  appBarBottom -
                  tabBarInset -
                  SavedRoutesOverlay.paginationHeight -
                  120,
            ),
          );
          final mapControls = Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _mapButtonGap,
            children: [
              AppMapIconButton(
                icon: Icons.route_outlined,
                label: '경로 위치 보기',
                size: _mapButtonSize,
                iconColor: _routeCameraView != null ? _brand : null,
                onPressed:
                    _controller == null ||
                        _activeRouteEndpoints == null ||
                        _location.isLocating ||
                        _movingRouteCamera
                    ? null
                    : _moveCameraToRoute,
              ),
              AppMapIconButton(
                icon: Icons.my_location,
                label: '현재 위치로 이동',
                size: _mapButtonSize,
                iconColor: _location.isSelected ? _brand : null,
                onPressed:
                    _controller == null ||
                        _location.isLocating ||
                        _movingRouteCamera
                    ? null
                    : () {
                        _clearRouteCameraSelection();
                        _location.recenter();
                      },
              ),
            ],
          );

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
                  onCameraMoveStart: (gesture) {
                    _location.onCameraMoveStart(gesture);
                    if (gesture != GestureType.unknown) {
                      _clearRouteCameraSelection();
                    }
                  },
                  onMapError: (error) {
                    debugPrint('Salmon 카카오맵 오류: $error');
                  },
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
                    settings: appMapGlassSettings,
                    cardHeight: savedCardHeight,
                    example: _savedExample,
                    onExampleSelected: _onSavedExampleSelected,
                  ),
                ),
              ),
              Positioned.fill(
                top: routeSheetTop,
                child: RouteSheet(
                  controller: _routeSheet,
                  availableHeight: constraints.maxHeight - routeSheetTop,
                  halfHeight: constraints.maxHeight * 0.46,
                  bottomInset: tabBarInset + safeArea.bottom,
                  pageFocusScope: pageFocusScope,
                  builder: (scrollController, bottomInset, keyboardVisible) =>
                      RouteSearchPanel(
                        scrollController: scrollController,
                        bottomInset: bottomInset,
                        keyboardVisible: keyboardVisible,
                        origin: _placeField(origin: true),
                        destination: _placeField(origin: false),
                        busField: BusRouteSearchField(
                          decoration: _fieldDecoration(
                            '선호 광역버스 (선택)',
                            Icons.directions_bus_outlined,
                          ),
                          controller: _busNumberController,
                          focusNode: _busNumberFocus,
                          onSelectionChanged: (route) {
                            _selectedBusRoute = route;
                          },
                        ),
                        suggestionsAfterOrigin: _editingOrigin == true,
                        suggestions: _editingOrigin != null
                            ? RouteSearchScreen(
                                isSearching: _placeSuggestions.isSearching,
                                message: _placeSuggestions.message,
                                results: _placeSuggestions.results,
                                onResultSelected: _selectSearchResult,
                                isLocating: _locatingForPlace,
                                onCurrentLocation: _selectMyLocation,
                              )
                            : null,
                        onSearch: _origin == null || _destination == null
                            ? null
                            : _openRouteResults,
                      ),
                ),
              ),
              Positioned.fill(
                child: _positionMapControls(
                  controls: mapControls,
                  viewportHeight: constraints.maxHeight,
                  appBarBottom: appBarBottom,
                  routeSheetTop: routeSheetTop,
                  right: mapControlsRight,
                  tabBarInset: tabBarInset,
                  savedCardHeight: savedCardHeight,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
