import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:salmon/ui/my_routes/saved_route_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:salmon/ui/core/widgets/app_primary_button.dart';
import 'package:salmon/ui/core/widgets/chip_button.dart';
import 'package:salmon/ui/my_routes/map_location_tracker.dart';
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
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MyRoutesScreen(
            savedRouteExample: Future.value({
              'origin': {
                'name': '영통입구',
                'latitude': 37.27,
                'longitude': 127.05,
              },
              'destination': {
                'name': '서울역',
                'latitude': 37.55,
                'longitude': 126.97,
              },
              'candidates': [
                {
                  'summary': {
                    'total_minutes': 65,
                    'arrival_at': '2026-11-26T09:05:00+09:00',
                  },
                  'segments': [
                    {'type': 'walk', 'duration_minutes': 5},
                    {
                      'type': 'bus',
                      'route_name': 'M5121',
                      'duration_minutes': 20,
                      'boarding_station': {'name': '소화초등학교'},
                      'estimated_boarding_at': '2026-11-26T08:05:00+09:00',
                      'seat_prediction': {'estimated_remaining_seats': 0},
                    },
                    {'type': 'transfer_walk', 'duration_minutes': 5},
                    {
                      'type': 'subway',
                      'route_name': '1호선',
                      'duration_minutes': 32,
                      'boarding_station': {'name': '수원역'},
                      'estimated_boarding_at': '2026-11-26T08:30:00+09:00',
                    },
                    {'type': 'walk', 'duration_minutes': 3},
                  ],
                },
              ],
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chips = find.byType(GlassChip);
      expect(
        tester.widgetList<GlassChip>(chips).map((chip) => chip.quality),
        everyElement(GlassQuality.minimal),
      );
      final manageRoutes = find.widgetWithIcon(GlassChip, Icons.tune);
      final lastChip = tester.widget<GlassChip>(chips.last);
      expect(lastChip.label, isEmpty);
      expect(lastChip.semanticLabel, '경로 관리');
      expect(lastChip, same(tester.widget<GlassChip>(manageRoutes)));
      expect(manageRoutes.hitTestable(), findsNothing);
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      final routeCount = chips.evaluate().length - 1;
      void expectSelectedDot(int selected) {
        final indicator = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '경로 카드 ${selected + 1} / $routeCount',
        );
        final dots = find.descendant(
          of: indicator,
          matching: find.byType(AnimatedContainer),
        );
        expect(dots, findsNWidgets(routeCount));
        for (var index = 0; index < routeCount; index++) {
          final dot = tester.widget<AnimatedContainer>(dots.at(index));
          expect(
            (dot.decoration as BoxDecoration).color,
            index == selected
                ? const Color(0xFFD9553E)
                : const Color(0xFF8A8E94),
          );
        }
      }

      expectSelectedDot(0);
      expect(find.byType(SavedRouteCard), findsWidgets);
      expect(tester.getSize(find.byType(PageView)).height, 232);
      expect(find.text('영통입구 → 서울역').hitTestable(), findsOneWidget);
      expect(find.text('65분').hitTestable(), findsOneWidget);
      expect(find.text('· 09:05 도착').hitTestable(), findsOneWidget);
      expect(find.text('잔여 0석').hitTestable(), findsOneWidget);
      expect(find.text('08:05').hitTestable(), findsOneWidget);
      expect(find.text('소화초등학교 승차').hitTestable(), findsOneWidget);
      expect(find.text('수원역 환승 · 도보 5분').hitTestable(), findsOneWidget);
      expect(find.text('수원역 승차').hitTestable(), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  '도보 5분, M5121 버스 20분, 도보 5분, 1호선 32분, 도보 3분',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      await tester.tap(chips.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(pages.page, allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      expect(tester.widget<GlassChip>(chips.at(1)).selected, isTrue);
      expectSelectedDot(1);
      expect(find.text('집 → 회사').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<GlassChip>(chips.at(2)).selected, isTrue);
      expectSelectedDot(2);
      final routeTabs = find.ancestor(
        of: manageRoutes,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(routeTabs, const Offset(-640, 0));
      await tester.pumpAndSettle();
      expect(manageRoutes.hitTestable(), findsOneWidget);
      await tester.tap(manageRoutes);
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
      final screen = find.byType(Scaffold);
      final bottomBar = find.byType(GlassTabBar);
      final appBar = find.byType(GlassAppBar);
      final title = find.text('거슬렁');
      final notifications = find.widgetWithIcon(
        GlassIconButton,
        Icons.notifications_none_rounded,
      );
      final settings = find.widgetWithIcon(GlassIconButton, Icons.settings);
      final gps = find.widgetWithIcon(GlassIconButton, Icons.my_location);
      final routeCamera = find.widgetWithIcon(
        GlassIconButton,
        Icons.route_outlined,
      );

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
      for (final button in [notifications, settings]) {
        final border = find.ancestor(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground &&
                widget.decoration is ShapeDecoration,
          ),
        );
        expect(tester.getSize(button), const Size.square(48));
        expect(tester.getRect(border), tester.getRect(button));
      }
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
      const headingChannel = MethodChannel('salmon/device_heading');
      messenger.setMockMethodCallHandler(headingChannel, (_) async => null);
      addTearDown(
        () => messenger.setMockMethodCallHandler(headingChannel, null),
      );
      final pins = <String>{};
      final savedPins = <String>{};
      final pinImages = <String, Uint8List>{};
      final pinStyles = <String, Uint8List>{};
      final pinLabels = <String, Object?>{};
      final savedLines = <String>{};
      final cameraUpdates = <CameraUpdate>[];
      var styleCount = 0;
      messenger.setMockMethodCallHandler(overlays, (call) async {
        final arguments = call.arguments as Map;
        switch (call.method) {
          case 'addPoiStyle':
            final styleId = 'style-${++styleCount}';
            final style = arguments['styles'] as Map;
            final icon = style['icon'] as Map?;
            if (icon?['data'] case final Uint8List image) {
              pinStyles[styleId] = image;
            }
            return styleId;
          case 'addPoi':
            final poi = arguments['poi'] as Map;
            final id = poi['id'] as String;
            if (id.startsWith('route-') || id.startsWith('saved-route-')) {
              pinLabels[id] = poi['text'];
              pinImages[id] = pinStyles[poi['styleId']]!;
              (id.startsWith('saved-') ? savedPins : pins).add(id);
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
      final mapWidget = tester.widget<KakaoMap>(find.byType(KakaoMap));
      await tester.runAsync(() async {
        final font = FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
        await font.load();
      });
      mapWidget.onMapReady(
        _TestMapController(overlays, (update) async {
          cameraUpdates.add(update);
        }),
      );
      for (var attempt = 0; attempt < 50 && savedLines.isEmpty; attempt++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
      expect(savedPins, {'saved-route-origin', 'saved-route-destination'});
      expect(pinLabels.values, everyElement(isNull));
      final departureIcon = pinImages['saved-route-origin']!;
      final arrivalIcon = pinImages['saved-route-destination']!;
      expect(departureIcon.take(4), [137, 80, 78, 71]);
      expect(arrivalIcon.take(4), [137, 80, 78, 71]);
      expect(arrivalIcon, isNot(orderedEquals(departureIcon)));
      expect(savedLines, {'saved-route-line'});
      expect(cameraUpdates.single.type, CameraUpdateType.fitMapPoints);
      Future<void> expectRouteCameraCycle(
        LatLng origin,
        LatLng destination,
      ) async {
        for (final view in [null, origin, destination, null]) {
          final count = cameraUpdates.length;
          await tester.tap(routeCamera);
          await tester.pumpAndSettle();
          expect(cameraUpdates, hasLength(count + 1));
          final update = cameraUpdates.last;
          if (view == null) {
            expect(update.type, CameraUpdateType.fitMapPoints);
            expect(update.fitPoints, [origin, destination]);
          } else {
            expect(update.type, CameraUpdateType.newCenterPoint);
            expect(update.position, view);
            expect(update.zoomLevel, 16);
          }
          expect(
            (tester.widget<GlassIconButton>(routeCamera).icon as Icon).color,
            const Color(0xFFD9553E),
          );
        }
      }

      await expectRouteCameraCycle(
        const LatLng(37.2779667, 127.0519833),
        const LatLng(37.55515, 126.9727333),
      );
      await tester.tap(find.widgetWithText(GlassChip, '퇴근길'));
      await tester.pumpAndSettle();
      expect(savedPins, isEmpty);
      expect(savedLines, isEmpty);
      expect(tester.widget<GlassIconButton>(routeCamera).onPressed, isNull);
      await tester.tap(find.widgetWithText(GlassChip, '예시 경로'));
      await tester.pumpAndSettle();
      expect(savedPins, hasLength(2));
      expect(savedLines, {'saved-route-line'});
      final appBarElement = tester.element(appBar);
      final appBarBottom = tester.getBottomLeft(appBar).dy;
      final titleBounds = tester.getRect(title);
      expect(find.byType(GlassSearchBar), findsNothing);
      final sheet = find.byType(DraggableScrollableSheet);
      final sheetController = tester
          .widget<DraggableScrollableSheet>(sheet)
          .controller!;
      const halfSheetHeight = 844 * 0.46;
      final searchTabLabel = find.text('길찾기').hitTestable();
      expect(sheetController.size, 0);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(savedPins, isEmpty);
      expect(savedLines, isEmpty);
      expect(sheetController.pixels, closeTo(halfSheetHeight, 1));
      final searchForm = find.byType(RouteSearchPanel);
      expect(gps.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomRight(gps).dy,
        lessThan(tester.getTopLeft(searchForm).dy),
      );
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.size, 0);
      expect(tester.widget<GlassTabBar>(bottomBar).selectedIndex, 1);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.pixels, closeTo(halfSheetHeight, 1));
      Finder input(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == label,
      );
      final busInput = input('선호 광역버스 (선택)');
      expect(busInput.hitTestable(), findsOneWidget);
      await tester.tap(busInput);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(sheetController.pixels, closeTo(halfSheetHeight, 1));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final dragHandle = find.bySemanticsLabel('길찾기 패널 크기 조절');
      await tester.drag(dragHandle, const Offset(0, -530));
      await tester.pumpAndSettle();
      expect(sheetController.size, 1);
      final maxSheetTop = appBarBottom + 2 * (48 + 12);
      expect(sheetController.pixels, closeTo(844 - maxSheetTop, 1));
      expect(gps.hitTestable(), findsOneWidget);
      expect(routeCamera.hitTestable(), findsOneWidget);
      expect(tester.getTopRight(routeCamera).dy, closeTo(appBarBottom, 1));
      expect(
        tester.getTopRight(gps).dy - tester.getBottomRight(routeCamera).dy,
        closeTo(12, 1),
      );
      expect(
        tester.getTopLeft(searchForm).dy - tester.getBottomRight(gps).dy,
        closeTo(12, 1),
      );
      expect(
        tester.getTopLeft(dragHandle).dy,
        greaterThanOrEqualTo(appBarBottom),
      );
      expect(tester.takeException(), isNull);
      expect(tester.element(appBar), same(appBarElement));
      expect(searchTabLabel, findsWidgets);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.size, 0);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      await tester.drag(dragHandle, const Offset(0, -530));
      await tester.pumpAndSettle();
      expect(sheetController.size, 1);
      await tester.drag(dragHandle, const Offset(0, 340));
      await tester.pumpAndSettle();
      expect(sheetController.pixels, closeTo(halfSheetHeight, 1));
      await tester.drag(dragHandle, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(sheetController.size, 0);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();
      expect(sheetController.pixels, closeTo(halfSheetHeight, 1));

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

      final destinationInput = input('목적지');
      double inputGap() =>
          tester.getTopLeft(busInput).dy -
          tester.getBottomLeft(destinationInput).dy;
      final gapBeforeFocus = inputGap();
      final resultsPanel = find.byType(RouteSearchScreen);
      final myLocation = find.text('내 위치');
      await tester.tap(destinationInput);
      await tester.pumpAndSettle();
      expect(myLocation, findsOneWidget);
      expect(inputGap(), greaterThan(gapBeforeFocus));

      await tester.tap(searchBar);
      await tester.pumpAndSettle();
      expect(myLocation, findsOneWidget);
      expect(
        tester.getTopLeft(resultsPanel).dy,
        lessThan(tester.getTopLeft(destinationInput).dy),
      );
      await tester.tap(myLocation);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(searchBar).controller?.text, '내 위치');
      expect(pins, {'route-origin'});

      await tester.tap(searchBar);
      await tester.pumpAndSettle();
      expect(find.descendant(of: panel, matching: searchBar), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(myLocation, findsWidgets);
      expect(inputGap(), gapBeforeFocus);
      const keyboardHeight = 330.0;
      addTearDown(tester.view.resetViewInsets);
      final mapBeforeKeyboard = tester.widget<KakaoMap>(find.byType(KakaoMap));
      final halfExtentBeforeKeyboard = sheetController.size;
      final panelInsetBeforeKeyboard = tester
          .widget<RouteSearchPanel>(panel)
          .bottomInset;
      for (final inset in [20.0, 80.0, 160.0, keyboardHeight]) {
        tester.view.viewInsets = FakeViewPadding(
          bottom: inset * tester.view.devicePixelRatio,
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(sheetController.size, closeTo(halfExtentBeforeKeyboard, 0.001));
        expect(
          tester.widget<DraggableScrollableSheet>(sheet).snapSizes!.single,
          closeTo(halfExtentBeforeKeyboard, 0.001),
        );
        expect(
          tester.widget<RouteSearchPanel>(panel).bottomInset,
          math.max(0.0, panelInsetBeforeKeyboard - inset),
        );
        expect(
          tester.widget<KakaoMap>(find.byType(KakaoMap)),
          same(mapBeforeKeyboard),
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(sheetController.size, closeTo(0.85, 0.01));
      await tester.enterText(
        find.descendant(of: searchBar, matching: find.byType(EditableText)),
        '서울시청',
      );
      await tester.pump();
      expect(resultsPanel, findsOneWidget);
      final progress = find.byType(GlassProgressIndicator);
      expect(progress, findsOneWidget);
      expect(
        tester.getTopLeft(myLocation).dy,
        lessThan(tester.getTopLeft(progress).dy),
      );
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
      expect(pins, {'route-origin'});
      expect(searchBar, findsOneWidget);
      expect(tester.widget<AppPrimaryButton>(searchButton).enabled, isFalse);

      await tester.enterText(destinationInput, '서울역');
      await tester.pump();
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
      expect(pins, {'route-origin', 'route-destination'});
      expect(pinLabels.values, everyElement(isNull));
      expect(pinImages['route-origin'], orderedEquals(departureIcon));
      expect(pinImages['route-destination'], orderedEquals(arrivalIcon));
      expect(tester.widget<AppPrimaryButton>(searchButton).enabled, isTrue);
      await expectRouteCameraCycle(
        const LatLng(37.5665, 126.978),
        const LatLng(37.5547, 126.9706),
      );
      expect(sheetController.size, 0);
      await tester.tap(searchTabLabel.first);
      await tester.pumpAndSettle();

      await tester.enterText(busInput, 'm5107');
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboardHeight * tester.view.devicePixelRatio,
      );
      await tester.pumpAndSettle();
      expect(sheetController.size, closeTo(0.85, 0.01));
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
      final filterTab = find.widgetWithText(ChipButton, '전체 2');
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
      expect(find.text('안내 시작'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로 가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(busInput).controller?.text, 'm5107');
      expect(resultsPanel, findsNothing);
      expect(gps, findsOneWidget);
      await tester.tap(find.byTooltip('출발지 지우기'));
      await tester.pumpAndSettle();
      expect(pins, {'route-destination'});
      expect(tester.widget<TextField>(input('출발지')).controller!.text, isEmpty);
      expect(tester.widget<AppPrimaryButton>(searchButton).enabled, isFalse);
      await tester.tap(find.byTooltip('목적지 지우기'));
      await tester.pumpAndSettle();
      expect(pins, isEmpty);
      expect(tester.widget<TextField>(input('목적지')).controller!.text, isEmpty);
      await tester.tap(find.text('내 경로').hitTestable().first);
      await tester.pumpAndSettle();

      expect(sheetController.size, 0);
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
      final zoomLevels = <int>[];
      final rotations = <double>[];
      final headingShown = Completer<void>.sync();
      final headingUpdated = Completer<void>.sync();
      final headingHidden = Completer<void>.sync();
      var styleChanges = 0;
      messenger.setMockMethodCallHandler(headingChannel, (_) async => null);
      final controller = _TestMapController(overlayChannel, (update) async {
        centers.add(update.position);
        zoomLevels.add(update.zoomLevel);
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
      expect(zoomLevels, [-1, MapLocationTracker.gpsZoomLevel]);

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
