import 'package:dio/dio.dart';

import 'kakao_search_result.dart';

/// 앱과 데모에서 사용할 카카오 장소명·주소 검색 결과를 합칩니다.
class KakaoPlaceSearchApi {
  // salmon.local.json의 REST API 키를 빌드 시 읽습니다.
  static const _restApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');

  // 카카오 검색 API 호출
  final _searchDio = Dio(
    BaseOptions(
      baseUrl: 'https://dapi.kakao.com/v2/local/search',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<({List<KakaoSearchResult> results, String? message})> search(
    String query, {
    required CancelToken cancelToken,
  }) async {
    if (_restApiKey.trim().isEmpty) {
      return (
        results: <KakaoSearchResult>[],
        message: 'salmon.local.json에 KAKAO_REST_API_KEY를 추가한 뒤 다시 빌드해 주세요.',
      );
    }

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
    final results = responses.expand((response) => response.results).toList();
    final errors = responses
        .map((response) => response.error)
        .whereType<String>()
        .toSet();
    return (
      results: results,
      message: errors.isNotEmpty
          ? errors.join('\n')
          : results.isEmpty
          ? '검색 결과가 없습니다. 장소명이나 주소를 더 입력해 주세요.'
          : null,
    );
  }

  String _searchErrorMessage(DioException error) {
    return switch (error.response?.statusCode) {
      401 => 'REST API 키가 올바른지 확인해 주세요. (401)',
      403 => '카카오 API 사용 권한과 키 제한 설정을 확인해 주세요. (403)',
      429 => '검색 요청 한도를 초과했습니다. 잠시 후 다시 시도해 주세요. (429)',
      _ => '검색에 실패했습니다. 네트워크를 확인하고 다시 검색해 주세요.',
    };
  }

  void close() => _searchDio.close(force: true);
}
