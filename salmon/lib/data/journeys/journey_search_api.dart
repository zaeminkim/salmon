import 'package:dio/dio.dart';

import '../backend.dart';
import '../places/kakao_search_result.dart';
import 'journey_example_api.dart';

Dio createJourneySearchClient({required bool useExample}) {
  final client = Dio(
    BaseOptions(
      baseUrl: salmonBackendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );
  if (useExample) client.interceptors.add(JourneyExampleApi());
  return client;
}

/// 실제 서버와 예시 응답에 공통으로 사용할 길찾기 요청을 만들고 결과를 검증합니다.
Future<Map<String, dynamic>> searchJourneys(
  Dio client, {
  required KakaoSearchResult origin,
  required KakaoSearchResult destination,
  required String? preferredBusNumber,
  required CancelToken cancelToken,
}) async {
  Map<String, Object> coordinates(KakaoSearchResult place) => {
    'latitude': place.latitude,
    'longitude': place.longitude,
    if (place.name.runes.length <= 80) 'name': place.name,
  };
  final bus = preferredBusNumber?.trim() ?? '';
  final response = await client.post<Map<String, dynamic>>(
    '/api/v1/journeys/search',
    data: {
      'origin': coordinates(origin),
      'destination': coordinates(destination),
      if (bus.isNotEmpty) 'preferred_express_bus': bus,
    },
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data == null || data['candidates'] is! List) {
    throw const FormatException('Missing journey candidates');
  }
  return data;
}

Future<Map<String, dynamic>> fetchJourneyDetail(
  Dio client, {
  required String searchId,
  required String candidateId,
  required CancelToken cancelToken,
}) async {
  final response = await client.get<Map<String, dynamic>>(
    '/api/v1/journeys/${Uri.encodeComponent(searchId)}'
    '/candidates/${Uri.encodeComponent(candidateId)}',
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data == null || data['candidate'] is! Map<String, dynamic>) {
    throw const FormatException('Missing journey detail candidate');
  }
  return data;
}
