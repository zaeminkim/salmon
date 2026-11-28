import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salmon/ui/route_search/bus_route_search_field.dart';
import 'package:salmon/ui/route_search/search_suggestions_progress.dart';

void main() {
  testWidgets('Searches by bus number and selects the official GBIS route ID', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'routes': [
                    {
                      'source': 'gbis',
                      'source_id': '234001317',
                      'route_no': 'M5121',
                      'start_stop_name': '삼성전자중앙문',
                      'end_stop_name': '서울역버스환승센터',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(client.close);
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    String? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusRouteSearchField(
            client: client,
            controller: controller,
            focusNode: focus,
            decoration: const InputDecoration(),
            onSelectionChanged: (value) => selection = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'm 512');
    await tester.pump();
    final progress = find.byType(SearchSuggestionsProgress);
    expect(progress, findsOneWidget);
    final track = find.descendant(
      of: progress,
      matching: find.byType(ClipRRect),
    );
    expect(tester.getSize(track).height, 6);
    expect(
      tester.widget<ClipRRect>(track).borderRadius,
      BorderRadius.circular(3),
    );
    expect(tester.widget<ClipRRect>(track).clipBehavior, isNot(Clip.none));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(progress, findsNothing);
    expect(requests.single.path, '/api/v1/bus-routes/search');
    expect(requests.single.queryParameters['q'], 'M512');
    expect(find.text('삼성전자중앙문 → 서울역버스환승센터'), findsOneWidget);
    await tester.tap(find.text('M5121'));
    await tester.pumpAndSettle();
    expect(controller.text, 'M5121');
    expect(selection, '234001317');
    expect(find.text('삼성전자중앙문 → 서울역버스환승센터'), findsNothing);

    await tester.tap(find.byTooltip('선호 광역버스 지우기'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(selection, isNull);
    expect(requests, hasLength(1));
  });
}
