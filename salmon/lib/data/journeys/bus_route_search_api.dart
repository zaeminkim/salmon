import 'package:dio/dio.dart';

import '../backend.dart';

Dio createBusRouteSearchClient() => Dio(
  BaseOptions(
    baseUrl: salmonBackendUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ),
);

/// 입력 및 선택 상태와 분리해 광역버스 추천 노선을 조회합니다.
Future<List<Map<String, dynamic>>> searchBusRoutes(
  Dio client,
  String query, {
  required CancelToken cancelToken,
}) async {
  final response = await client.get<Map<String, dynamic>>(
    '/api/v1/bus-routes/search',
    queryParameters: {'q': query, 'limit': 6},
    cancelToken: cancelToken,
  );
  final routes = response.data?['routes'];
  if (routes is! List) throw const FormatException('Missing bus routes');
  return routes.whereType<Map<String, dynamic>>().toList();
}
