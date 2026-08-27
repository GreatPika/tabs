import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wrapper for a tabs widget that provides a basic focus implementation.
class TabsFocus extends StatefulWidget {
  const TabsFocus({
    required this.controller,
    required this.child,
    super.key,
    this.tabAxis = Axis.horizontal,
    this.focusDecoration,
    this.focusPadding,
  });

  /// Needs to be the same [TabController] used by [child].
  final TabController controller;

  /// The tabs widget you want to wrap.
  ///
  /// Its [TabController] must be the same as [controller].
  final Widget child;

  /// The tab strip axis used to decide which arrow keys move selection.
  ///
  /// Horizontal tabs handle left/right keys. Vertical tabs handle up/down keys.
  final Axis tabAxis;

  /// The [BoxDecoration] displayed around [child] when it has focus.
  ///
  /// This could simply be a rounded black border.
  final BoxDecoration? focusDecoration;

  /// The padding displayed around [child] when it has focus.
  final EdgeInsets? focusPadding;

  @override
  State<TabsFocus> createState() => _TabsFocusState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<TabController>('controller', controller));
    properties.add(EnumProperty<Axis>('tabAxis', tabAxis));
    properties.add(DiagnosticsProperty<BoxDecoration?>(
      'focusDecoration',
      focusDecoration,
    ));
    properties.add(DiagnosticsProperty<EdgeInsets?>(
      'focusPadding',
      focusPadding,
    ));
  }
}

// Focus handling stays with the wrapper state so decoration, padding, and key
// routing observe the same focus boundary.
// ignore: coupling-between-object-classes
class _TabsFocusState extends State<TabsFocus> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: _hasFocus ? widget.focusDecoration : null,
        padding: _hasFocus ? widget.focusPadding : null,
        child: widget.child,
      ),
    );
  }

  void _handleFocusChange(bool focused) {
    setState(() {
      _hasFocus = focused;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    return _handleDirectionalTabKey(widget.controller, widget.tabAxis, event);
  }
}

KeyEventResult _handleDirectionalTabKey(
  TabController controller,
  Axis tabAxis,
  KeyEvent event,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }

  final previousKey = switch (tabAxis) {
    Axis.horizontal => LogicalKeyboardKey.arrowLeft,
    Axis.vertical => LogicalKeyboardKey.arrowUp,
  };
  final nextKey = switch (tabAxis) {
    Axis.horizontal => LogicalKeyboardKey.arrowRight,
    Axis.vertical => LogicalKeyboardKey.arrowDown,
  };

  if (event.logicalKey == previousKey) {
    controller.animateTo(max(controller.index - 1, 0));
    return KeyEventResult.handled;
  } else if (event.logicalKey == nextKey) {
    controller.animateTo(min(controller.index + 1, controller.length - 1));
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
}
