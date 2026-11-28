import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum RouteSheetPosition { hidden, half, full }

/// 탭으로 시트를 열고 닫거나, 드래그·키보드에 맞춰 높이를 조정합니다.
class RouteSheetController {
  RouteSheetController({required this.onPositionChanged}) {
    _scrollable.addListener(_onExtentChanged);
  }

  final void Function(RouteSheetPosition previous, RouteSheetPosition next)
  onPositionChanged;
  final _scrollable = DraggableScrollableController();
  bool _disposed = false;
  RouteSheetPosition _position = RouteSheetPosition.hidden;
  RouteSheetPosition? _target;
  final _halfExtent = ValueNotifier(0.5);
  Timer? _keyboardSettleTimer;
  double? _lastKeyboardInset;
  double? _pendingHalfExtent;

  double _extentFor(RouteSheetPosition position) => switch (position) {
    RouteSheetPosition.hidden => 0,
    RouteSheetPosition.half => _halfExtent.value,
    RouteSheetPosition.full => 1,
  };

  RouteSheetPosition? get _settledPosition {
    if (!_scrollable.isAttached) return null;
    final size = _scrollable.size;
    for (final position in RouteSheetPosition.values) {
      if ((size - _extentFor(position)).abs() < 0.0001) {
        return position;
      }
    }
    return null;
  }

  void _onExtentChanged() {
    if (_settledPosition == null) return;
    // 레이아웃 도중 높이가 바뀔 수 있어 현재 프레임이 끝난 뒤 화면에 알립니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final position = _settledPosition;
      if (position == null) return;
      if (position == _target) _target = null;
      _updatePosition(position);
    });
  }

  void moveTo(
    RouteSheetPosition position, {
    Duration duration = const Duration(milliseconds: 240),
  }) {
    if (!_scrollable.isAttached) {
      _updatePosition(position);
      return;
    }
    _target = position;
    unawaited(
      _scrollable.animateTo(
        _extentFor(position),
        duration: duration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _syncHalfExtent(double keyboardInset, double extent) {
    final previousInset = _lastKeyboardInset;
    _lastKeyboardInset = keyboardInset;
    if (_keyboardSettleTimer == null &&
        (previousInset == null || previousInset == keyboardInset)) {
      _updateHalfExtent(extent);
      return;
    }
    if (previousInset == keyboardInset && _pendingHalfExtent == extent) return;

    // 안드로이드 키보드가 움직이는 동안에는 시트가 멈출 높이를 유지합니다.
    _pendingHalfExtent = extent;
    _keyboardSettleTimer?.cancel();
    _keyboardSettleTimer = Timer(const Duration(milliseconds: 80), () {
      _keyboardSettleTimer = null;
      _pendingHalfExtent = null;
      _updateHalfExtent(extent, animate: true);
    });
  }

  void _updateHalfExtent(double extent, {bool animate = false}) {
    if (_halfExtent.value == extent) return;
    final wasAtHalf = _settledPosition == RouteSheetPosition.half;
    _halfExtent.value = extent;
    if (!wasAtHalf && _target != RouteSheetPosition.half) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_scrollable.isAttached) return;
      if (_target == RouteSheetPosition.half) {
        moveTo(RouteSheetPosition.half);
      } else if (_target == null && _position == RouteSheetPosition.half) {
        if (animate) {
          moveTo(
            RouteSheetPosition.half,
            duration: const Duration(milliseconds: 120),
          );
        } else {
          _scrollable.jumpTo(_halfExtent.value);
        }
      }
    });
  }

  bool get isVisible => _position != RouteSheetPosition.hidden;

  Listenable get heightChanges => _scrollable;
  double get heightFraction => _scrollable.isAttached ? _scrollable.size : 0;

  void toggle() => moveTo(
    (_target ?? _position) == RouteSheetPosition.hidden
        ? RouteSheetPosition.half
        : RouteSheetPosition.hidden,
  );

  void _updatePosition(RouteSheetPosition position) {
    if (_position == position) return;
    final previous = _position;
    _position = position;
    onPositionChanged(previous, position);
  }

  void dispose() {
    _disposed = true;
    _keyboardSettleTimer?.cancel();
    _halfExtent.dispose();
    _scrollable.dispose();
  }
}

/// 키보드 높이를 시트 내부에서 읽어 지도 화면의 재빌드를 줄입니다.
class RouteSheet extends StatelessWidget {
  const RouteSheet({
    super.key,
    required this.controller,
    required this.availableHeight,
    required this.halfHeight,
    required this.bottomInset,
    required this.pageFocusScope,
    required this.builder,
  });

  final RouteSheetController controller;
  final double availableHeight;
  final double halfHeight;
  final double bottomInset;
  final FocusScopeNode pageFocusScope;
  final Widget Function(
    ScrollController scroll,
    double inset,
    bool keyboardVisible,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = availableHeight - keyboardHeight;
    if (sheetHeight <= 48) return const SizedBox.shrink();

    controller._syncHalfExtent(
      keyboardHeight,
      math.min(halfHeight / sheetHeight, 0.85),
    );
    final sheet = ValueListenableBuilder<double>(
      valueListenable: controller._halfExtent,
      builder: (context, halfExtent, _) => DraggableScrollableSheet(
        controller: controller._scrollable,
        initialChildSize: controller._extentFor(controller._position),
        minChildSize: 0,
        snap: true,
        snapSizes: [halfExtent],
        expand: false,
        shouldCloseOnMinExtent: false,
        builder: (context, scrollController) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Focus(
            parentNode: pageFocusScope,
            canRequestFocus: false,
            descendantsAreFocusable: controller.isVisible,
            child: builder(
              scrollController,
              math.max(0.0, bottomInset - keyboardHeight),
              keyboardHeight > 0,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 && notification.dragDetails != null) {
              controller._target = null;
            }
            return false;
          },
          child: sheet,
        ),
      ),
    );
  }
}
