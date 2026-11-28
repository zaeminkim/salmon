import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/places/kakao_place_search_api.dart';
import '../../data/places/kakao_search_result.dart';

/// 검색 중인 결과를 보관하고 입력이 바뀌면 이전 요청을 취소합니다.
class KakaoPlaceSuggestions extends ChangeNotifier {
  final _api = KakaoPlaceSearchApi();
  Timer? _debounce;
  CancelToken? _request;
  int _generation = 0;

  List<KakaoSearchResult> _results = const [];
  bool _isSearching = false;
  String? _message;

  List<KakaoSearchResult> get results => _results;
  bool get isSearching => _isSearching;
  String? get message => _message;

  void update(String value, {bool submit = false}) {
    _debounce?.cancel();
    _request?.cancel();
    final generation = ++_generation;
    final query = value.trim();
    _results = const [];
    _message = null;
    _isSearching = query.isNotEmpty;
    notifyListeners();

    if (query.isEmpty || generation != _generation) return;
    if (submit) {
      unawaited(_search(query, generation));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(query, generation),
    );
  }

  Future<void> _search(String query, int generation) async {
    if (generation != _generation) return;
    final request = _request = CancelToken();
    final response = await _api.search(query, cancelToken: request);

    // 늦게 도착한 이전 응답으로 최신 검색 결과를 덮어쓰지 않습니다.
    if (generation != _generation || request.isCancelled) return;
    _results = response.results;
    _message = response.message;
    _isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_generation;
    _debounce?.cancel();
    _request?.cancel();
    _api.close();
    super.dispose();
  }
}
