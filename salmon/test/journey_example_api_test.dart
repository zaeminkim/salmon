import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:salmon/data/journeys/journey_example_api.dart';
import 'package:salmon/ui/core/widgets/app_map_icon_button.dart';
import 'package:salmon/ui/core/widgets/app_primary_button.dart';
import 'package:salmon/ui/core/widgets/chip_button.dart';
import 'package:salmon/ui/core/widgets/journey_result_card.dart';
import 'package:salmon/ui/my_routes/map_location_tracker.dart';
import 'package:salmon/ui/route_results/journey_preview_map.dart';
import 'package:salmon/ui/route_results/routeresults_screen.dart';
import 'package:salmon/ui/route_search/routesearch_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Shows the recorded search response as a journey card',
    (tester) async {
      final exampleClient = Dio()..interceptors.add(JourneyExampleApi());
      addTearDown(exampleClient.close);
      final example = await tester.runAsync(() async {
        final response = await exampleClient.post<Map<String, dynamic>>(
          '/api/v1/journeys/search',
        );
        await loadJourneyExampleDetail(
          searchId: response.data?['search_id'],
          candidateId: 'odsay-0',
        );
        return response;
      });
      final detailRequests = <String>[];
      final client = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final data = example!.data!;
              if (request.method == 'GET') {
                detailRequests.add(request.path);
                final id = request.path.split('/').last;
                final candidate = (data['candidates'] as List).firstWhere(
                  (candidate) => candidate['candidate_id'] == id,
                );
                handler.resolve(
                  Response(
                    requestOptions: request,
                    data: <String, dynamic>{'candidate': candidate},
                  ),
                );
              } else {
                handler.resolve(Response(requestOptions: request, data: data));
              }
            },
          ),
        );
      addTearDown(client.close);
      const place = KakaoSearchResult(
        name: '예시 장소',
        address: '',
        latitude: 37.5,
        longitude: 127,
        isAddress: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RouteResultsScreen(
                      origin: place,
                      destination: place,
                      journeyClient: client,
                    ),
                  ),
                ),
                child: const Text('길찾기에서 검색'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('길찾기에서 검색'));
      await tester.pumpAndSettle();
      expect(find.textContaining('출발지 예시'), findsOneWidget);
      expect(find.textContaining('도착  목적지 예시'), findsOneWidget);
      expect(find.widgetWithText(ChipButton, '전체 8'), findsOneWidget);
      expect(find.byType(ChipButton), findsNWidgets(4));
      expect(find.widgetWithText(ChipButton, '5500-2 이용 0'), findsNothing);
      final firstCard = find.byType(JourneyResultCard).first;
      for (final label in [
        '65분',
        '도보 2분 · 환승 0회',
        '63분',
        '예상 잔여 12석',
        '소화초등학교 (04286)',
        '→ 서울역버스환승센터(6번승강장) (02006) 하차',
        '추천 1위 · ODsay 1위',
        '좌석 부족 위험 낮음',
        '최소 예상 잔여 12석',
        '잔여 5석 이하 확률 8.9%',
      ]) {
        expect(
          find.descendant(of: firstCard, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: firstCard,
          matching: find.textContaining('M5121 ·'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: firstCard, matching: find.text('예측 근거')),
      );
      await tester.pumpAndSettle();
      expect(find.text('좌석 예측 근거'), findsOneWidget);
      expect(find.textContaining('좌석 여유 우수'), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();

      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      final platformViewSizes = <String>[];
      const camera = MethodChannel('test.journey-preview/camera');
      const overlays = MethodChannel('test.journey-preview/overlays');
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create' || call.method == 'resize') {
          platformViewSizes.add(call.method);
        }
        return switch (call.method) {
          'create' => 0,
          'resize' => {
            'width': call.arguments['width'],
            'height': call.arguments['height'],
          },
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(camera, (call) async {
        calls.add(call);
        return null;
      });
      messenger.setMockMethodCallHandler(overlays, (call) async {
        calls.add(call);
        return '${call.method}-${calls.length}';
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(camera, null);
        messenger.setMockMethodCallHandler(overlays, null);
      });

      await tester.tap(
        find.descendant(of: firstCard, matching: find.text('65분')),
      );
      await tester.pumpAndSettle();
      final back = find.byTooltip('뒤로 가기');
      final routeCamera = find.byTooltip('전체 경로 보기');
      final gps = find.byTooltip('현재 위치로 이동');
      expect(back, findsOneWidget);
      Color? routeCameraColor() => tester
          .widget<AppMapIconButton>(
            find.ancestor(
              of: routeCamera,
              matching: find.byType(AppMapIconButton),
            ),
          )
          .iconColor;

      Future<void> expectRouteCameraCycle() async {
        final preview = tester.widget<JourneyPreviewMap>(
          find.byType(JourneyPreviewMap),
        );
        for (final center in [
          null,
          preview.origin,
          preview.destination,
          null,
        ]) {
          final count = calls
              .where((call) => call.method == 'moveCamera')
              .length;
          await tester.tap(routeCamera);
          await tester.pumpAndSettle();
          final moves = calls.where((call) => call.method == 'moveCamera');
          expect(moves, hasLength(count + 1));
          final cameraUpdate = CameraUpdate.fromMessageable(
            moves.last.arguments['cameraUpdate'],
          );
          if (center == null) {
            expect(cameraUpdate.type, CameraUpdateType.fitMapPoints);
            expect(cameraUpdate.fitPoints, [
              preview.origin,
              preview.destination,
            ]);
          } else {
            expect(cameraUpdate.type, CameraUpdateType.newCenterPoint);
            expect(cameraUpdate.position, center);
            expect(cameraUpdate.zoomLevel, 16);
          }
          expect(routeCameraColor(), const Color(0xFFD9553E));
        }
      }

      void expectMapButtonLayout() {
        final routeRect = tester.getRect(routeCamera);
        final gpsRect = tester.getRect(gps);
        expect(routeRect.size, const Size.square(48));
        expect(gpsRect.size, routeRect.size);
        expect(gpsRect.right, routeRect.right);
        expect(gpsRect.top - routeRect.bottom, 12);
        expect(
          routeRect.right,
          tester.getSize(find.byType(Scaffold)).width - 20,
        );
        expect(routeCamera.hitTestable(), findsOneWidget);
        expect(gps.hitTestable(), findsOneWidget);
      }

      expect(find.text('출발지 예시 → 목적지 예시'), findsOneWidget);
      expect(find.text('총 65분'), findsOneWidget);
      final map = tester.widget<KakaoMap>(find.byType(KakaoMap));
      expect(map.forceGesture, isTrue);
      expect(map.option?.position, const LatLng(37.2779667, 127.0519833));
      map.onMapReady(
        KakaoMapControllerImplement(camera, overlayChannel: overlays),
      );
      await tester.pumpAndSettle();
      expectMapButtonLayout();
      expect(tester.getRect(back).left, 20);
      expect(tester.getSize(back), const Size.square(48));
      expect(calls.where((call) => call.method == 'moveCamera'), hasLength(1));
      final sheet = find.byType(DraggableScrollableSheet);
      final mapFinder = find.byType(KakaoMap);
      Future<void> checkSheetKeepsMap(double extent) async {
        final element = tester.element(mapFinder);
        final bounds = tester.getRect(mapFinder);
        final sizeCallCount = platformViewSizes.length;
        final mapCallCount = calls.length;
        final controller = tester
            .widget<DraggableScrollableSheet>(sheet)
            .controller!;
        expect(controller.size, isNot(closeTo(extent, 0.001)));
        controller.jumpTo(extent);
        await tester.pumpAndSettle();
        expect(controller.size, closeTo(extent, 0.001));
        expect(tester.element(mapFinder), same(element));
        expect(tester.getRect(mapFinder), bounds);
        expect(platformViewSizes, hasLength(sizeCallCount));
        expect(calls, hasLength(mapCallCount));
      }

      await checkSheetKeepsMap(0.31);
      expect(routeCameraColor(), isNull);
      await expectRouteCameraCycle();
      final pinLabels = calls
          .where((call) => call.method == 'addPoi')
          .map((call) => call.arguments['poi']['text']);
      expect(pinLabels, [
        '출발지',
        '도착지',
        '소화초등학교 (04286)',
        '서울역버스환승센터(6번승강장) (02006)',
      ]);
      final linePoints = calls
          .where((call) => call.method == 'addPolylineShape')
          .map(
            (call) => call.arguments['polyline']['position']['points'] as List,
          );
      expect(linePoints.any((points) => points.length == 346), isTrue);
      final guideButton = find.text('안내 시작');
      final buttonPosition = tester.getCenter(guideButton);
      final vertical = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final busStep = find.textContaining('M5121 버스 · 63분');
      await tester.scrollUntilVisible(busStep, 100, scrollable: vertical);
      expect(busStep, findsOneWidget);
      expect(
        find.text('소화초등학교 (04286) 승차 → 서울역버스환승센터(6번승강장) (02006) 하차'),
        findsOneWidget,
      );
      expect(tester.getCenter(guideButton), buttonPosition);
      final original = find.text('추천 6위 · 89분');
      await tester.scrollUntilVisible(original, 150, scrollable: vertical);
      await Scrollable.ensureVisible(tester.element(original), alignment: 0.4);
      await tester.tap(original);
      await tester.pumpAndSettle();
      expect(find.text('총 89분'), findsOneWidget);
      expect(detailRequests.single, endsWith('/candidates/odsay-1'));
      expect(find.textContaining('좌석 부족 위험 높음'), findsOneWidget);
      final alternative = find.text('추천 1위 · 65분');
      await tester.scrollUntilVisible(alternative, 150, scrollable: vertical);
      await Scrollable.ensureVisible(
        tester.element(alternative),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('24분 단축'), findsOneWidget);
      await tester.tap(alternative);
      await tester.pumpAndSettle();
      expect(find.text('총 65분'), findsOneWidget);

      final previousGeolocator = geo.GeolocatorPlatform.instance;
      final locations = _GuidanceLocation();
      geo.GeolocatorPlatform.instance = locations;
      addTearDown(() {
        geo.GeolocatorPlatform.instance = previousGeolocator;
        return locations.positions.close();
      });
      tester
          .widget<KakaoMap>(find.byType(KakaoMap))
          .onMapReady(
            KakaoMapControllerImplement(camera, overlayChannel: overlays),
          );
      await tester.pumpAndSettle();
      final beforeGuidance = calls
          .where((call) => call.method == 'moveCamera')
          .length;
      final startButtonPosition = tester.getCenter(guideButton);
      await tester.tap(guideButton);
      await tester.pumpAndSettle();
      expect(back, findsNothing);
      expect(find.byType(AppMapIconButton), findsNWidgets(2));
      final endButton = find.widgetWithText(AppPrimaryButton, '안내 종료');
      expect(endButton, findsOneWidget);
      expect(
        (tester.getCenter(endButton) - startButtonPosition).distance,
        lessThan(0.01),
      );
      await checkSheetKeepsMap(
        tester.widget<DraggableScrollableSheet>(sheet).maxChildSize,
      );
      expectMapButtonLayout();
      expect(
        calls.where((call) => call.method == 'moveCamera'),
        hasLength(beforeGuidance + 1),
      );
      locations.positions.add(locations.position(37.2783));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'moveCamera'),
        hasLength(beforeGuidance + 2),
      );
      tester
          .widget<KakaoMap>(find.byType(KakaoMap))
          .onCameraMoveStart
          ?.call(GestureType.pan);
      locations.positions.add(locations.position(37.2786));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'moveCamera'),
        hasLength(beforeGuidance + 2),
      );
      await tester.tap(find.byTooltip('현재 위치로 이동'));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'moveCamera'),
        hasLength(beforeGuidance + 3),
      );
      final lastCamera = calls.lastWhere((call) => call.method == 'moveCamera');
      expect(
        lastCamera.arguments['cameraUpdate']['zoomLevel'],
        MapLocationTracker.gpsZoomLevel,
      );
      expect(routeCameraColor(), isNull);
      await expectRouteCameraCycle();
      expect(
        tester.widget<DraggableScrollableSheet>(sheet).controller!.size,
        closeTo(0.31, 0.001),
      );
      final afterRouteView = calls
          .where((call) => call.method == 'moveCamera')
          .length;
      locations.positions.add(locations.position(37.279));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'moveCamera'),
        hasLength(afterRouteView),
      );
      await tester.tap(endButton);
      await tester.pumpAndSettle();
      expect(find.text('길찾기에서 검색'), findsOneWidget);
      expect(find.text('경로추천'), findsNothing);
      expect(locations.positions.hasListener, isFalse);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('Shows the preferred bus from the submitted search', (
    tester,
  ) async {
    final example = await tester.runAsync(loadJourneyExample);
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) =>
              handler.resolve(Response(requestOptions: request, data: example)),
        ),
      );
    addTearDown(client.close);
    const place = KakaoSearchResult(
      name: '예시 장소',
      address: '',
      latitude: 37.5,
      longitude: 127,
      isAddress: false,
    );
    for (final (bus, label, expected) in [
      ('5500-2', '5500-2', '5500-2 이용 0'),
      ('234001317', 'M5121', 'M5121 이용 1'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: RouteResultsScreen(
            key: ValueKey(bus),
            origin: place,
            destination: place,
            preferredBusNumber: bus,
            preferredBusLabel: label,
            journeyClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preferred = find.widgetWithText(ChipButton, expected);
      expect(preferred, findsOneWidget);
      await tester.tap(preferred);
      await tester.pumpAndSettle();
      if (bus == '5500-2') {
        expect(find.text('표시할 경로가 없어요.'), findsOneWidget);
      } else {
        expect(find.byType(JourneyResultCard), findsOneWidget);
        expect(find.text('65분'), findsOneWidget);
        expect(find.text('5500-2 이용 0'), findsNothing);
      }
    }
  });

  test('The mock search endpoint serves the recorded candidates', () async {
    final client = Dio()..interceptors.add(JourneyExampleApi());
    addTearDown(client.close);

    final response = await client.post<Map<String, dynamic>>(
      '/api/v1/journeys/search',
    );
    final candidates = response.data?['candidates'] as List;
    expect(response.statusCode, 200);
    expect(candidates, hasLength(8));
    expect(candidates.first['candidate_id'], 'odsay-0');
    expect(candidates.first['summary']['total_minutes'], 65);
    final unrelatedDetail = await loadJourneyExampleDetail(
      searchId: response.data?['search_id'],
      candidateId: candidates[1]['candidate_id'],
    );
    expect(unrelatedDetail, isNull);
  });
}

class _GuidanceLocation extends geo.GeolocatorPlatform {
  final positions = StreamController<geo.Position>.broadcast();

  geo.Position position(double latitude) => geo.Position(
    latitude: latitude,
    longitude: 127.052,
    timestamp: DateTime(2026),
    accuracy: 6,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<geo.LocationPermission> checkPermission() async =>
      geo.LocationPermission.whileInUse;

  @override
  Future<geo.Position> getCurrentPosition({
    geo.LocationSettings? locationSettings,
  }) async => position(37.278);

  @override
  Stream<geo.Position> getPositionStream({
    geo.LocationSettings? locationSettings,
  }) => positions.stream;
}
