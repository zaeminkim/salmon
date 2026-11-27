import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

Future<Map<String, dynamic>> loadJourneyExample() async {
  final files = await Future.wait([
    rootBundle.loadString('assets/examples/journey_api_inputs.json'),
    rootBundle.loadString('assets/examples/journey_search.json'),
  ]);
  final inputs = jsonDecode(files[0]) as Map<String, dynamic>;
  final body = inputs['search']['body'] as Map<String, dynamic>;
  final result = jsonDecode(files[1]) as Map<String, dynamic>;
  return {
    'origin': body['origin'],
    'destination': body['destination'],
    ...result,
  };
}

Map<String, dynamic>? _recordedDetail;

Future<Map<String, dynamic>?> loadJourneyExampleDetail({
  required Object? searchId,
  required Object? candidateId,
}) async {
  if (searchId is! String || candidateId is! String) return null;
  final detail = _recordedDetail ??= jsonDecode(
    await rootBundle.loadString('assets/examples/journey_candidate_detail.json'),
  ) as Map<String, dynamic>;
  if (detail['search_id'] != searchId ||
      detail['candidate_id'] != candidateId) {
    return null;
  }
  return detail;
}

/// Serves a recorded API response through the normal search request.
class JourneyExampleApi extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method != 'POST' || options.path != '/api/v1/journeys/search') {
      handler.next(options);
      return;
    }
    try {
      final result = await loadJourneyExample();
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: result,
        ),
      );
    } catch (error) {
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }
}
