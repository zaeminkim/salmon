import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class BusRouteSearchField extends StatefulWidget {
  const BusRouteSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.onSelectionChanged,
    this.client,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final ValueChanged<String?> onSelectionChanged;
  final Dio? client;

  @override
  State<BusRouteSearchField> createState() => _BusRouteSearchFieldState();
}

class _BusRouteSearchFieldState extends State<BusRouteSearchField> {
  late final _client =
      widget.client ??
      Dio(
        BaseOptions(
          baseUrl: 'https://geoseulleong-06469e76bb18.herokuapp.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
  Timer? _debounce;
  CancelToken? _request;
  List<Map<String, dynamic>> _routes = [];
  bool _loading = false;
  String? _message;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && _selected) return;
    _queueSearch(widget.focusNode.hasFocus ? widget.controller.text : '');
  }

  void _queueSearch(String value) {
    _debounce?.cancel();
    _request?.cancel();
    final query = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    setState(() {
      _loading = query.isNotEmpty && widget.focusNode.hasFocus;
      _routes = [];
      _message = null;
    });
    if (_loading) {
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _search(query),
      );
    }
  }

  Future<void> _search(String query) async {
    final request = _request = CancelToken();
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/bus-routes/search',
        queryParameters: {'q': query, 'limit': 6},
        cancelToken: request,
      );
      final routes = response.data?['routes'];
      if (routes is! List) throw const FormatException('Missing bus routes');
      if (!mounted || request.isCancelled) return;
      setState(() {
        _routes = routes
            .whereType<Map<String, dynamic>>()
            .where((route) => _number(route).isNotEmpty)
            .toList();
        _loading = false;
        if (_routes.isEmpty) _message = '일치하는 광역버스 노선이 없어요.';
      });
    } catch (_) {
      if (!mounted || request.isCancelled) return;
      setState(() {
        _loading = false;
        _message = '광역버스 노선을 불러오지 못했어요.';
      });
    }
  }

  String _number(Map<String, dynamic> route) =>
      (route['route_no'] ?? route['route_name'] ?? '').toString().trim();

  void _select(Map<String, dynamic> route) {
    final number = _number(route);
    _selected = true;
    widget.controller.text = number;
    final sourceId = route['source_id'];
    widget.onSelectionChanged(
      route['source'] == 'gbis' && sourceId is String && sourceId.isNotEmpty
          ? sourceId
          : number,
    );
    widget.focusNode.unfocus();
  }

  String? _subtitle(Map<String, dynamic> route) {
    final stops = [
      route['start_stop_name'],
      route['end_stop_name'],
    ].whereType<String>().where((name) => name.isNotEmpty).join(' → ');
    if (stops.isNotEmpty) return stops;
    return (route['route_display_label'] ?? route['region_name']) as String?;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _debounce?.cancel();
    _request?.cancel();
    if (widget.client == null) _client.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: widget.decoration,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) {
            _selected = false;
            widget.onSelectionChanged(null);
            _queueSearch(value);
          },
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (_message case final message?)
          Padding(padding: const EdgeInsets.all(8), child: Text(message)),
        for (final route in _routes)
          ListTile(
            dense: true,
            leading: const Icon(Icons.directions_bus_outlined),
            title: Text(_number(route)),
            subtitle: switch (_subtitle(route)) {
              final subtitle? => Text(subtitle),
              null => null,
            },
            onTap: () => _select(route),
          ),
      ],
    );
  }
}
