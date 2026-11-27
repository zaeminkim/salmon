import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:salmon/data/journeys/journey_example_api.dart';
import 'package:salmon/ui/core/widgets/journey_result_card.dart';
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
      final client = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) => handler.resolve(
              Response(requestOptions: request, data: example!.data),
            ),
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
          home: RouteResultsScreen(
            origin: place,
            destination: place,
            journeyClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('출발지 예시'), findsOneWidget);
      expect(find.textContaining('도착  목적지 예시'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '전체 8'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.widgetWithText(ChoiceChip, '5500-2 이용 0'), findsNothing);
      final firstCard = find.byType(JourneyResultCard).first;
      for (final label in [
        '65분',
        '도보 2분 · 환승 0회',
        '63분',
        '예상 잔여 12석',
        '소화초등학교 (04286)',
        '→ 서울역버스환승센터(6번승강장) (02006) 하차',
        '추천 1위 · ODsay 1위',
        '좌석 부족 위험 낮음 · 최소 예상 잔여 12석 · 잔여 5석 이하 확률 8.9%',
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
      expect(find.textContaining('좌석 여유 우수'), findsOneWidget);

      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      const camera = MethodChannel('test.journey-preview/camera');
      const overlays = MethodChannel('test.journey-preview/overlays');
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

      await tester.tap(firstCard);
      await tester.pumpAndSettle();
      expect(find.text('경로 상세'), findsOneWidget);
      expect(find.text('출발지 예시 → 목적지 예시'), findsOneWidget);
      expect(find.text('총 65분'), findsOneWidget);
      expect(find.text('점선은 추정 구간이에요.'), findsOneWidget);
      final map = tester.widget<KakaoMap>(find.byType(KakaoMap));
      expect(map.forceGesture, isFalse);
      expect(map.option?.position, const LatLng(37.2779667, 127.0519833));
      map.onMapReady(
        KakaoMapControllerImplement(camera, overlayChannel: overlays),
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'moveCamera'), hasLength(1));
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
      final guideButton = find.text('경로 안내');
      final buttonPosition = tester.getCenter(guideButton);
      final busStep = find.textContaining('M5121 버스 · 63분');
      await tester.scrollUntilVisible(busStep, 100);
      expect(busStep, findsOneWidget);
      expect(
        find.text('소화초등학교 (04286) 승차 → 서울역버스환승센터(6번승강장) (02006) 하차'),
        findsOneWidget,
      );
      expect(tester.getCenter(guideButton), buttonPosition);
      await tester.tap(guideButton);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '경로 안내'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '경로 상세'), findsOneWidget);
      final original = find.text('추천 6위 · 89분');
      await tester.scrollUntilVisible(original, 150);
      await tester.tap(original);
      await tester.pumpAndSettle();
      expect(find.text('총 89분'), findsOneWidget);
      expect(find.textContaining('좌석 부족 위험 높음'), findsOneWidget);
      final alternative = find.text('추천 1위 · 65분');
      await tester.scrollUntilVisible(alternative, 150);
      await Scrollable.ensureVisible(
        tester.element(alternative),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('24분 단축'), findsOneWidget);
      await tester.tap(alternative);
      await tester.pumpAndSettle();
      expect(find.text('총 65분'), findsOneWidget);
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
      final preferred = find.widgetWithText(ChoiceChip, expected);
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
