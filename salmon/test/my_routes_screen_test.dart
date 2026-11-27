import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/core/widgets/app_primary_button.dart';
import 'package:salmon/ui/my_routes/myroutes_screen.dart';
import 'package:salmon/ui/route_results/routeresults_screen.dart';
import 'package:salmon/ui/route_search/routesearch_screen.dart'
    show KakaoSearchResult, RouteSearchPanel, RouteSearchScreen;
import 'package:salmon/ui/settings/settings_screen.dart';

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      return switch (call.method) {
        'create' => 0,
        'resize' => {
          'width': call.arguments['width'],
          'height': call.arguments['height'],
        },
        _ => null,
      };
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets(
    'Saved route chips and cards share a selection and open management',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MyRoutesScreen()));
      final chips = find.byType(GlassChip);
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      await tester.tap(chips.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(pages.page, allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      expect(tester.widget<GlassChip>(chips.at(1)).selected, isTrue);
      expect(find.text('회사 → 집').hitTestable(), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.widget<GlassChip>(chips.at(2)).selected, isTrue);
      await tester.tap(find.widgetWithIcon(GlassIconButton, Icons.tune));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '경로 관리'), findsOneWidget);
    },
  );

  testWidgets(
    'Keeps the route sheet below the app bar and submits all three fields',
    (tester) async {
      const statusBarHeight = 59.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = const FakeViewPadding(
        top: statusBarHeight,
        bottom: 34,
      );
      tester.view.padding = tester.view.viewPadding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final journeyRequests = <RequestOptions>[];
      final journeyClient = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              journeyRequests.add(request);
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'search_id': 'test-search',
                    'candidates': [
                      {
                        'candidate_id': 'odsay-0',
                        'summary': {'total_minutes': 42},
                        'segments': [
                          {'type': 'walk', 'duration_minutes': 8},
                          {
                            'type': 'bus',
                            'duration_minutes': 34,
                            'route_name': 'M5107',
                            'boarding_station': {'name': '정류장 A'},
                            'alighting_station': {'name': '정류장 B'},
                          },
                        ],
                      },
                      {
                        'candidate_id': 'odsay-1',
                        'summary': {'total_minutes': 47},
                        'segments': [
                          {'type': 'subway', 'duration_minutes': 47},
                        ],
                      },
                    ],
                    'filters': [
                      {'key': 'all', 'label': '전체'},
                      {
                        'key': 'preferred_express_bus',
                        'label': 'M5107 이용',
                        'candidate_ids': ['odsay-0'],
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );
      addTearDown(journeyClient.close);
      final savedRouteExample = Future<Map<String, dynamic>>.value({
        'origin': {
          'name': '영통입구',
          'latitude': 37.2779667,
          'longitude': 127.0519833,
        },
        'destination': {
          'name': '서울역',
          'latitude': 37.55515,
          'longitude': 126.9727333,
        },
        'candidates': [
          {'total_time_minutes': 68},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MyRoutesScreen(
            journeyClient: journeyClient,
            savedRouteExample: savedRouteExample,
          ),
        ),
      );
      final screen = find.byType(GlassScaffold);
      final bottomBar = find.byType(GlassTabBar);
      final appBar = find.byType(GlassAppBar);
      final title = find.text('거슬렁');
      final notifications = find.widgetWithIcon(
        GlassIconButton,
        Icons.notifications_none_rounded,
      );
      final settings = find.widgetWithIcon(GlassIconButton, Icons.settings);
      final gps = find.widgetWithIcon(GlassIconButton, Icons.my_location);

      expect(settings, findsOneWidget);
      expect(find.descendant(of: appBar, matching: settings), findsOneWidget);
      expect(
        find.descendant(of: appBar, matching: notifications),
        findsOneWidget,
      );
      expect(
        tester.getTopRight(title).dx,
        lessThan(tester.getTopLeft(notifications).dx),
      );
      expect(
        tester.getTopRight(notifications).dx,
        lessThan(tester.getTopLeft(settings).dx),
      );
      expect(tester.getCenter(notifications).dy, tester.getCenter(settings).dy);
      expect(
        tester.widget<GlassIconButton>(settings).settings,
        same(tester.widget<GlassIconButton>(gps).settings),
      );
      final settingsBounds = tester.getRect(settings);
      final notificationBounds = tester.getRect(notifications);
      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('알림 내역 화면은 준비 중이에요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.getCenter(bottomBar).dx, tester.getCenter(screen).dx);
      expect(tester.getSize(bottomBar).width, 340);

      final map = tester.element(find.byType(KakaoMap));
      final originalGeolocator = geo.GeolocatorPlatform.instance;
      geo.GeolocatorPlatform.instance = _TestGeolocator();
      addTearDown(() => geo.GeolocatorPlatform.instance = originalGeolocator);
      const overlays = MethodChannel('test.route-pins/overlay');
      final pins = <String, String>{};
      final savedPins = <String, String>{};
      final savedLines = <String>{};
      final cameraUpdates = <CameraUpdate>[];
      var styleCount = 0;
      messenger.setMockMethodCallHandler(overlays, (call) async {
        final arguments = call.arguments as Map;
        switch (call.method) {
          case 'addPoiStyle':
            return 'style-${++styleCount}';
          case 'addPoi':
            final poi = arguments['poi'] as Map;
            final id = poi['id'] as String;
            if (id.startsWith('route-')) pins[id] = poi['text'] as String;
            if (id.startsWith('saved-route-')) {
              savedPins[id] = poi['text'] as String;
            }
            return id;
          case 'removePoi':
            pins.remove(arguments['poiId']);
            savedPins.remove(arguments['poiId']);
          case 'addPolylineShapeStyle':
            return 'line-style';
          case 'addPolylineShape':
            final line = arguments['polyline'] as Map;
            final id = line['id'] as String;
            savedLines.add(id);
            return id;
          case 'removePolylineShape':
            savedLines.remove(arguments['polylineId']);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(overlays, null));
      tester
          .widget<KakaoMap>(find.byType(KakaoMap))
          .onMapReady(
            _TestMapController(overlays, (update) async {
              cameraUpdates.add(update);
            }),
          );
      await tester.pumpAndSettle();
      expect(savedPins, {
        'saved-route-origin': '출발지',
        'saved-route-destination': '도착지',
      });
      expect(savedLines, {'saved-route-line'});
      expect(cameraUpdates.single.type, CameraUpdateType.fitMapPoints);
      await tester.tap(find.widgetWithText(GlassChip, '퇴근길'));
      await tester.pumpAndSettle();
      expect(savedPins, isEmpty);
      expect(savedLines, isEmpty);
      await tester.tap(find.widgetWithText(GlassChip, '예시 경로'));
      await tester.pumpAndSettle();
      expect(savedPins, hasLength(2));
      expect(savedLines, {'saved-route-line'});
      final appBarElement = tester.element(appBar);
      final appBarBottom = tester.getBottomLeft(appBar).dy;
      final titleBounds = tester.getRect(title);
      expect(find.byType(GlassSearchBar), findsNothing);
      final sheet = find.byType(GlassModalSheet);
      final sheetController = tester.widget<GlassModalSheet>(sheet).controller!;
      final searchTabLabel = find.text('길찾기').hitTestable();
      expect(sheetController.currentState, GlassSheetState.hidden);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(savedPins, isEmpty);
      expect(savedLines, isEmpty);
      expect(sheetController.currentState, GlassSheetState.half);
      expect(sheetController.value, closeTo(0.46, 0.01));
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.hidden);
      expect(sheetController.value, closeTo(0, 0.01));
      expect(tester.widget<GlassTabBar>(bottomBar).selectedIndex, 1);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.half);
      Finder input(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == label,
      );
      final busInput = input('선호 광역버스 (선택)');
      expect(busInput.hitTestable(), findsOneWidget);
      await tester.tap(busInput);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(sheetController.currentState, GlassSheetState.half);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final dragHandle = find.bySemanticsLabel('Drag handle');
      await tester.drag(dragHandle, const Offset(0, -530));
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.full);
      expect(sheetController.value * 844, closeTo(844 - appBarBottom, 1));
      expect(
        tester.getTopLeft(dragHandle).dy,
        greaterThanOrEqualTo(appBarBottom),
      );
      expect(tester.takeException(), isNull);
      expect(tester.element(appBar), same(appBarElement));
      expect(searchTabLabel, findsWidgets);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.hidden);
      expect(sheetController.value, closeTo(0, 0.01));
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      await tester.drag(dragHandle, const Offset(0, -530));
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.full);
      await tester.drag(dragHandle, const Offset(0, 340));
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.half);
      await tester.drag(dragHandle, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.hidden);
      expect(sheetController.value, closeTo(0, 0.01));
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.half);

      final searchBar = input('출발지');
      final panel = find.byType(RouteSearchPanel);
      final searchButton = find.widgetWithText(AppPrimaryButton, '경로 검색');
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.byType(TextField)),
        findsNWidgets(3),
      );
      expect(find.descendant(of: panel, matching: busInput), findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('출발지')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('목적지')),
        findsOneWidget,
      );
      expect(searchBar, findsOneWidget);
      expect(tester.widget<AppPrimaryButton>(searchButton).enabled, isFalse);
      expect(tester.getRect(settings), settingsBounds);
      expect(tester.getRect(notifications), notificationBounds);
      expect(tester.element(appBar), same(appBarElement));
      expect(tester.getRect(title), titleBounds);
      expect(tester.element(find.byType(KakaoMap)), same(map));

      await tester.tap(input('출발지'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: panel, matching: searchBar), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      const keyboardHeight = 330.0;
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboardHeight * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: searchBar, matching: find.byType(EditableText)),
        '서울시청',
      );
      await tester.pump();
      final resultsPanel = find.byType(RouteSearchScreen);
      expect(resultsPanel, findsOneWidget);
      final progress = find.byType(GlassProgressIndicator);
      expect(progress, findsOneWidget);
      expect(tester.widget<GlassProgressIndicator>(progress).value, isNull);
      expect(tester.getTopLeft(resultsPanel).dy, greaterThan(appBarBottom));
      expect(
        tester.getBottomLeft(resultsPanel).dy,
        lessThan(tester.getSize(screen).height - keyboardHeight),
      );

      const origin = KakaoSearchResult(
        name: '서울시청',
        address: '세종대로 110',
        latitude: 37.5665,
        longitude: 126.978,
        isAddress: false,
      );
      tester.widget<RouteSearchScreen>(resultsPanel).onResultSelected(origin);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(pins, {'route-origin': '출발지'});
      expect(searchBar, findsOneWidget);
      expect(tester.widget<AppPrimaryButton>(searchButton).enabled, isFalse);

      await tester.tap(input('목적지'));
      await tester.pumpAndSettle();
      expect(find.text('서울시청'), findsOneWidget);
      const destination = KakaoSearchResult(
        name: '서울역',
        address: '한강대로 405',
        latitude: 37.5547,
        longitude: 126.9706,
        isAddress: false,
      );
      tester
          .widget<RouteSearchScreen>(resultsPanel)
          .onResultSelected(destination);
      await tester.pumpAndSettle();
      expect(pins, {'route-origin': '출발지', 'route-destination': '목적지'});
      expect(tester.widget<AppPrimaryButton>(searchButton).enabled, isTrue);

      await tester.enterText(busInput, 'm5107');
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboardHeight * tester.view.devicePixelRatio,
      );
      await tester.pumpAndSettle();
      expect(sheetController.currentState, GlassSheetState.half);
      await tester.ensureVisible(searchButton);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(searchButton).dy,
        lessThan(tester.getSize(screen).height - keyboardHeight),
      );
      await tester.tap(searchButton);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final result = tester.widget<RouteResultsScreen>(
        find.byType(RouteResultsScreen),
      );
      expect(result.origin, same(origin));
      expect(result.destination, same(destination));
      expect(result.preferredBusNumber, 'M5107');
      expect(journeyRequests.single.path, '/api/v1/journeys/search');
      expect(journeyRequests.single.data, {
        'origin': {'latitude': 37.5665, 'longitude': 126.978, 'name': '서울시청'},
        'destination': {
          'latitude': 37.5547,
          'longitude': 126.9706,
          'name': '서울역',
        },
        'preferred_express_bus': 'M5107',
      });

      final fullSize = tester.view.physicalSize;
      tester.view.physicalSize = const Size(390, 500);
      await tester.pumpAndSettle();
      final recommendation = find.text('거슬렁 추천순');
      final filterTab = find.widgetWithText(ChoiceChip, '전체 2');
      final firstCard = find.text('42분');
      final recommendationTop = tester.getTopLeft(recommendation).dy;
      final filterTop = tester.getTopLeft(filterTab).dy;
      final cardTop = tester.getTopLeft(firstCard).dy;
      await tester.drag(firstCard, const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(recommendation).dy, recommendationTop);
      expect(tester.getTopLeft(filterTab).dy, filterTop);
      expect(tester.getTopLeft(firstCard).dy, lessThan(cardTop));
      tester.view.physicalSize = fullSize;
      await tester.pumpAndSettle();

      await tester.tap(find.text('M5107 이용 1'));
      await tester.pumpAndSettle();
      expect(find.text('정류장 A'), findsOneWidget);
      expect(find.text('47분'), findsNothing);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();
      expect(find.text('경로 상세'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(busInput).controller?.text, 'm5107');
      expect(resultsPanel, findsNothing);
      expect(gps, findsOneWidget);
      await tester.enterText(input('출발지'), '');
      await tester.pumpAndSettle();
      expect(pins, {'route-destination': '목적지'});
      await tester.enterText(input('목적지'), '');
      await tester.pumpAndSettle();
      expect(pins, isEmpty);
      await tester.tap(find.text('내 경로').hitTestable().first);
      await tester.pumpAndSettle();

      expect(sheetController.currentState, GlassSheetState.hidden);
      expect(searchBar.hitTestable(), findsNothing);
      expect(settings, findsOneWidget);
      expect(find.text('거슬렁'), findsOneWidget);
      expect(tester.element(appBar), same(appBarElement));
      expect(tester.element(find.byType(KakaoMap)), same(map));
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'GPS recenters the map and heading rotates the marker without movement',
    (tester) async {
      final originalGeolocator = geo.GeolocatorPlatform.instance;
      geo.GeolocatorPlatform.instance = _TestGeolocator();
      addTearDown(() => geo.GeolocatorPlatform.instance = originalGeolocator);

      const overlayChannel = MethodChannel('test.gps/overlay');
      const headingChannel = MethodChannel('salmon/device_heading');
      final initialCameraMove = Completer<void>.sync();
      final buttonCameraMove = Completer<void>();
      final centers = <LatLng?>[];
      final rotations = <double>[];
      final headingShown = Completer<void>.sync();
      final headingUpdated = Completer<void>.sync();
      final headingHidden = Completer<void>.sync();
      var styleChanges = 0;
      messenger.setMockMethodCallHandler(headingChannel, (_) async => null);
      final controller = _TestMapController(overlayChannel, (update) async {
        centers.add(update.position);
        if (centers.length == 1) {
          initialCameraMove.complete();
        } else {
          await buttonCameraMove.future;
        }
      });
      messenger.setMockMethodCallHandler(overlayChannel, (call) async {
        final arguments = call.arguments as Map;
        if (call.method == 'rotatePoi' && arguments['poiId'] == 'my-location') {
          rotations.add(arguments['angle'] as double);
          if (rotations.length == 2) headingUpdated.complete();
          return null;
        }
        if (call.method == 'changePoiStyle' &&
            arguments['poiId'] == 'my-location') {
          styleChanges++;
          if (styleChanges == 1) headingShown.complete();
          if (styleChanges == 2) headingHidden.complete();
          return null;
        }
        final poi = arguments['poi'] as Map?;
        return poi?['id'] ?? call.method;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(overlayChannel, null);
        messenger.setMockMethodCallHandler(headingChannel, null);
      });

      await tester.pumpWidget(const MaterialApp(home: MyRoutesScreen()));
      await tester.tap(find.widgetWithText(GlassChip, '퇴근길'));
      await tester.pumpAndSettle();
      final map = tester.widget<KakaoMap>(find.byType(KakaoMap));
      final gps = find.byWidgetPredicate(
        (widget) =>
            widget is GlassIconButton && widget.semanticLabel == '현재 위치로 이동',
      );
      Color? gpsColor() =>
          (tester.widget<GlassIconButton>(gps).icon as Icon).color;
      expect(tester.widget<GlassIconButton>(gps).onPressed, isNull);
      expect(
        tester.getBottomRight(gps).dy,
        lessThan(tester.getTopRight(find.byType(GlassTabBar)).dy),
      );

      await tester.runAsync(() async {
        map.onMapReady(controller);
        await initialCameraMove.future.timeout(const Duration(seconds: 5));

        Future<void> sendHeading(double? heading, Future<void> applied) async {
          await messenger.handlePlatformMessage(
            headingChannel.name,
            const StandardMethodCodec().encodeSuccessEnvelope(heading),
            null,
          );
          await applied.timeout(const Duration(seconds: 5));
        }

        await sendHeading(90, headingShown.future);
        await sendHeading(270, headingUpdated.future);
        await sendHeading(null, headingHidden.future);
      });
      await tester.pumpAndSettle();
      expect(gpsColor(), isNull);
      expect(rotations, [
        closeTo(math.pi / 2, 1e-9),
        closeTo(-math.pi / 2, 1e-9),
      ]);
      expect(styleChanges, 2);
      expect(centers, hasLength(1));

      await tester.tap(gps);
      await tester.pump();
      expect(gpsColor(), const Color(0xFFD9553E));
      expect(centers, hasLength(2));
      expect(centers.last?.latitude, _TestGeolocator.latitude);
      expect(centers.last?.longitude, _TestGeolocator.longitude);

      buttonCameraMove.complete();
      await tester.pumpAndSettle();
      expect(gpsColor(), const Color(0xFFD9553E));
      map.onCameraMoveStart!(GestureType.pan);
      await tester.pump();
      expect(gpsColor(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}

class _TestMapController extends KakaoMapControllerImplement {
  _TestMapController(MethodChannel overlays, this.onMove)
    : super(const MethodChannel('test.gps/map'), overlayChannel: overlays);

  final Future<void> Function(CameraUpdate) onMove;

  @override
  Future<void> moveCamera(CameraUpdate camera, {CameraAnimation? animation}) =>
      onMove(camera);
}

class _TestGeolocator extends geo.GeolocatorPlatform {
  static const latitude = 37.5651;
  static const longitude = 126.9895;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<geo.LocationPermission> checkPermission() async =>
      geo.LocationPermission.whileInUse;

  @override
  Future<geo.Position> getCurrentPosition({
    geo.LocationSettings? locationSettings,
  }) async => geo.Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Stream<geo.Position> getPositionStream({
    geo.LocationSettings? locationSettings,
  }) => const Stream.empty();
}
