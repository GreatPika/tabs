import 'dart:async';
import 'dart:math';
import 'dart:ui';

// Metric note: this render owner legitimately touches gestures, material
// controller feedback, render layout, and keyboard input in one atomic render
// contract. Splitting imports here would split the owner, not reduce coupling.
// ignore_for_file: number-of-external-imports

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../tab_edge.dart';

// =============================================================================
// TabFrame render owner
// =============================================================================
//
// This file contains one atomic render contract:
//
// 1. Small geometry/value helpers
//    - double extension
//    - _TabMetrics
//    - _TabViewport
//    - _ClipPathCacheKey
//
// 2. Widget bridge
//    - TabFrame
//    - createRenderObject / updateRenderObject
//    - widget diagnostics
//
// 3. Parent data
//    - TabFrameParentData
//
// 4. Render object
//    - constructor and mutable render inputs
//    - lifecycle
//    - hit testing and gesture routing
//    - scroll and selection
//    - layout and intrinsic sizing
//    - clipping and path geometry
//    - painting
//    - semantics
//    - diagnostics
//
// Child order contract:
//   0                 -> main child
//   1..tabCount       -> tabs
//   after tabs        -> leading action buttons
//   after leading     -> trailing action buttons
//
// Do not change child traversal order without updating:
//   - TabFrame.children
//   - RenderTabFrame.performLayout
//   - RenderTabFrame.hitTestChildren
//   - RenderTabFrame._paint
//   - RenderTabFrame.visitChildrenForSemantics

// =============================================================================
// Small helpers
// =============================================================================

extension on double {
  bool isBetween(double num1, double num2) {
    return num1 <= this && this <= num2;
  }
}

class _TabMetrics {
  _TabMetrics({
    required this.count,
    required this.range,
    required this.minLength,
    required this.maxLength,
  });

  final int count;
  final double range;
  final double minLength;
  final double maxLength;

  double get length => (range / count).clamp(minLength, maxLength);

  double get totalLength => count * length;
}

class _TabViewport {
  _TabViewport({
    required this.parentSize,
    required this.tabEdge,
    required this.tabExtent,
    required this.tabStripStart,
    required this.tabStripEnd,
  });

  final Size parentSize;
  final TabEdge tabEdge;
  final double tabExtent;
  final double tabStripStart;
  final double tabStripEnd;

  double get side => (tabEdge == TabEdge.top || tabEdge == TabEdge.bottom)
      ? parentSize.width
      : parentSize.height;

  double get start => side * tabStripStart;

  double get end => side * tabStripEnd;

  double get range => end - start;

  Size get size => (tabEdge == TabEdge.top || tabEdge == TabEdge.bottom)
      ? Size(range, tabExtent)
      : Size(tabExtent, range);
}

@immutable
class _ClipPathCacheKey {
  const _ClipPathCacheKey({
    required this.size,
    required this.tabEdge,
    required this.tabAxis,
    required this.tabExtent,
    required this.tabStripStart,
    required this.tabStripRange,
    required this.hasTabOverflow,
    required this.tabBorderRadius,
  });

  final Size size;
  final TabEdge tabEdge;
  final Axis tabAxis;
  final double tabExtent;
  final double tabStripStart;
  final double tabStripRange;
  final bool hasTabOverflow;
  final BorderRadius tabBorderRadius;

  @override
  bool operator ==(Object other) {
    return other is _ClipPathCacheKey &&
        other.size == size &&
        other.tabEdge == tabEdge &&
        other.tabAxis == tabAxis &&
        other.tabExtent == tabExtent &&
        other.tabStripStart == tabStripStart &&
        other.tabStripRange == tabStripRange &&
        other.hasTabOverflow == hasTabOverflow &&
        other.tabBorderRadius == tabBorderRadius;
  }

  @override
  int get hashCode => Object.hash(
    size,
    tabEdge,
    tabAxis,
    tabExtent,
    tabStripStart,
    tabStripRange,
    hasTabOverflow,
    tabBorderRadius,
  );
}

// =============================================================================
// Widget bridge: TabFrame
// =============================================================================

// Metric note: TabFrame is the bridge that keeps widget composition inputs
// aligned with RenderTabFrame creation and updates.
// ignore: coupling-between-object-classes, depth-of-inheritance-tree
class TabFrame extends MultiChildRenderObjectWidget {
  // Controller and animations.
  final TabController controller;
  final Animation<double> progressAnimation;
  final Animation<double> collapseProgressAnimation;
  final Curve curve;
  final Duration duration;

  // Children.
  final Widget child;
  final List<Widget> tabs;
  final List<Widget> tabLeadingButtons;
  final List<Widget> tabTrailingButtons;

  // Collapse behavior.
  final bool collapsed;
  final int? collapsedActionIndex;

  // Tab strip geometry.
  final double tabButtonGap;
  final BorderRadius borderRadius;
  final BorderRadius tabBorderRadius;
  final double tabExtent;
  final TabEdge tabEdge;
  final Axis tabAxis;
  final double tabStripStart;
  final double tabStripEnd;
  final double tabMinLength;
  final double tabMaxLength;

  // Appearance.
  final Color? color;
  final List<Color>? colors;

  // Semantics and input.
  final String? semanticsLabel;
  final String? semanticsHint;
  final String Function(int index, int count)? semanticsValueBuilder;
  final bool enabled;
  final bool enableFeedback;
  final TextDirection textDirection;

  TabFrame({
    required this.controller,
    required this.progressAnimation,
    required this.collapseProgressAnimation,
    required this.curve,
    required this.duration,
    required this.child,
    required this.tabs,
    required this.tabLeadingButtons,
    required this.tabTrailingButtons,
    required this.collapsed,
    required this.collapsedActionIndex,
    required this.tabButtonGap,
    required this.borderRadius,
    required this.tabBorderRadius,
    required this.tabExtent,
    required this.tabEdge,
    required this.tabAxis,
    required this.tabStripStart,
    required this.tabStripEnd,
    required this.tabMinLength,
    required this.tabMaxLength,
    required this.color,
    required this.colors,
    required this.semanticsLabel,
    required this.semanticsHint,
    required this.semanticsValueBuilder,
    required this.enabled,
    required this.enableFeedback,
    required this.textDirection,
    super.key,
  }) : super(
         children: [
           child,
           ...tabs,
           ...tabLeadingButtons,
           ...tabTrailingButtons,
         ],
       );

  @override
  RenderTabFrame createRenderObject(BuildContext context) {
    return RenderTabFrame(
      controller: controller,
      progressAnimation: progressAnimation,
      collapseProgressAnimation: collapseProgressAnimation,
      curve: curve,
      duration: duration,
      tabCount: tabs.length,
      tabLeadingActionCount: tabLeadingButtons.length,
      tabTrailingActionCount: tabTrailingButtons.length,
      tabButtonGap: tabButtonGap,
      collapsed: collapsed,
      collapsedActionIndex: collapsedActionIndex,
      pointerAxisModifiers: _pointerAxisModifiersOf(context),
      onTapFeedback: _onTapFeedbackOf(context),
      borderRadius: borderRadius,
      tabBorderRadius: tabBorderRadius,
      tabExtent: tabExtent,
      tabEdge: tabEdge,
      tabAxis: tabAxis,
      tabStripStart: tabStripStart,
      tabStripEnd: tabStripEnd,
      tabMinLength: tabMinLength,
      tabMaxLength: tabMaxLength,
      color: color,
      colors: colors,
      semanticsLabel: semanticsLabel,
      semanticsHint: semanticsHint,
      semanticsValueBuilder: semanticsValueBuilder,
      enabled: enabled,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTabFrame renderObject) {
    renderObject
      ..controller = controller
      ..progressAnimation = progressAnimation
      ..collapseProgressAnimation = collapseProgressAnimation
      ..curve = curve
      ..duration = duration
      ..tabCount = tabs.length
      ..tabLeadingActionCount = tabLeadingButtons.length
      ..tabTrailingActionCount = tabTrailingButtons.length
      ..tabButtonGap = tabButtonGap
      ..collapsed = collapsed
      ..collapsedActionIndex = collapsedActionIndex
      ..pointerAxisModifiers = _pointerAxisModifiersOf(context)
      ..onTapFeedback = _onTapFeedbackOf(context)
      ..borderRadius = borderRadius
      ..tabBorderRadius = tabBorderRadius
      ..tabExtent = tabExtent
      ..tabEdge = tabEdge
      ..tabAxis = tabAxis
      ..tabStripStart = tabStripStart
      ..tabStripEnd = tabStripEnd
      ..tabMinLength = tabMinLength
      ..tabMaxLength = tabMaxLength
      ..color = color
      ..colors = colors
      ..semanticsLabel = semanticsLabel
      ..semanticsHint = semanticsHint
      ..semanticsValueBuilder = semanticsValueBuilder
      ..enabled = enabled
      ..textDirection = textDirection;
  }

  Set<LogicalKeyboardKey> _pointerAxisModifiersOf(BuildContext context) {
    return ScrollConfiguration.of(context).pointerAxisModifiers;
  }

  VoidCallback? _onTapFeedbackOf(BuildContext context) {
    return enableFeedback ? () => unawaited(Feedback.forTap(context)) : null;
  }

  @override
  // Diagnostics intentionally list every render input in one place so debug
  // output mirrors the constructor/updateRenderObject contract.
  // ignore: halstead-volume, source-lines-of-code
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // Controller and animations.
    properties.add(
      DiagnosticsProperty<TabController>('controller', controller),
    );
    properties.add(
      DiagnosticsProperty<Animation<double>>(
        'progressAnimation',
        progressAnimation,
      ),
    );
    properties.add(
      DiagnosticsProperty<Animation<double>>(
        'collapseProgressAnimation',
        collapseProgressAnimation,
      ),
    );
    properties.add(DiagnosticsProperty<Curve>('curve', curve));
    properties.add(DiagnosticsProperty<Duration>('duration', duration));

    // Children and collapse behavior.
    properties.add(
      IterableProperty<Widget>('tabLeadingButtons', tabLeadingButtons),
    );
    properties.add(
      IterableProperty<Widget>('tabTrailingButtons', tabTrailingButtons),
    );
    properties.add(DoubleProperty('tabButtonGap', tabButtonGap));
    properties.add(DiagnosticsProperty<bool>('collapsed', collapsed));
    properties.add(IntProperty('collapsedActionIndex', collapsedActionIndex));

    // Tab strip geometry.
    properties.add(
      DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius),
    );
    properties.add(
      DiagnosticsProperty<BorderRadius>('tabBorderRadius', tabBorderRadius),
    );
    properties.add(DoubleProperty('tabExtent', tabExtent));
    properties.add(EnumProperty<TabEdge>('tabEdge', tabEdge));
    properties.add(EnumProperty<Axis>('tabAxis', tabAxis));
    properties.add(DoubleProperty('tabStripStart', tabStripStart));
    properties.add(DoubleProperty('tabStripEnd', tabStripEnd));
    properties.add(DoubleProperty('tabMinLength', tabMinLength));
    properties.add(DoubleProperty('tabMaxLength', tabMaxLength));

    // Appearance.
    properties.add(ColorProperty('color', color));
    properties.add(IterableProperty<Color>('colors', colors));

    // Semantics and input.
    properties.add(StringProperty('semanticsLabel', semanticsLabel));
    properties.add(StringProperty('semanticsHint', semanticsHint));
    properties.add(
      ObjectFlagProperty<String Function(int index, int count)?>.has(
        'semanticsValueBuilder',
        semanticsValueBuilder,
      ),
    );
    properties.add(DiagnosticsProperty<bool>('enabled', enabled));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
  }
}

// =============================================================================
// Parent data
// =============================================================================

class TabFrameParentData extends ContainerBoxParentData<RenderBox> {}

// =============================================================================
// Render object: RenderTabFrame
// =============================================================================

// RenderTabFrame owns layout, gestures, animation progress, clipping, painting,
// and wrapper semantics for one render object; splitting those responsibilities
// would add synchronization paths between state that must update atomically.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
class RenderTabFrame extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TabFrameParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TabFrameParentData> {
  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  RenderTabFrame({
    required TabController controller,
    required Animation<double> progressAnimation,
    required Animation<double> collapseProgressAnimation,
    required Curve curve,
    required Duration duration,
    required int tabCount,
    required int tabLeadingActionCount,
    required int tabTrailingActionCount,
    required double tabButtonGap,
    required bool collapsed,
    required int? collapsedActionIndex,
    required Set<LogicalKeyboardKey> pointerAxisModifiers,
    required VoidCallback? onTapFeedback,
    required BorderRadius borderRadius,
    required BorderRadius tabBorderRadius,
    required double tabExtent,
    required TabEdge tabEdge,
    required Axis tabAxis,
    required double tabStripStart,
    required double tabStripEnd,
    required double tabMinLength,
    required double tabMaxLength,
    required Color? color,
    required List<Color>? colors,
    required String? semanticsLabel,
    required String? semanticsHint,
    required String Function(int index, int count)? semanticsValueBuilder,
    required bool enabled,
    required TextDirection textDirection,
  }) : _controller = controller,
       _progressAnimation = progressAnimation,
       _progress = progressAnimation.value,
       _collapseProgressAnimation = collapseProgressAnimation,
       _collapseProgress = collapseProgressAnimation.value,
       _curve = curve,
       _duration = duration,
       _tabCount = tabCount,
       _tabLeadingActionCount = tabLeadingActionCount,
       _tabTrailingActionCount = tabTrailingActionCount,
       _tabButtonGap = tabButtonGap,
       _collapsed = collapsed,
       _collapsedActionIndex = collapsedActionIndex,
       _pointerAxisModifiers = pointerAxisModifiers,
       _onTapFeedback = onTapFeedback,
       _borderRadius = borderRadius,
       _tabBorderRadius = tabBorderRadius,
       _tabExtent = tabExtent,
       _tabEdge = tabEdge,
       _tabAxis = tabAxis,
       _tabStripStart = tabStripStart,
       _tabStripEnd = tabStripEnd,
       _tabMinLength = tabMinLength,
       _tabMaxLength = tabMaxLength,
       _color = color,
       _colors = colors,
       _semanticsLabel = semanticsLabel,
       _semanticsHint = semanticsHint,
       _semanticsValueBuilder = semanticsValueBuilder,
       _enabled = enabled,
       _textDirection = textDirection,
       assert(tabCount > 0, 'tabCount must be greater than zero.'),
       assert(
         tabLeadingActionCount >= 0,
         'tabLeadingActionCount must be non-negative.',
       ),
       assert(
         tabTrailingActionCount >= 0,
         'tabTrailingActionCount must be non-negative.',
       ),
       assert(tabButtonGap >= 0, 'tabButtonGap must be non-negative.'),
       assert(
         !collapsed ||
             (collapsedActionIndex != null &&
                 collapsedActionIndex >= 0 &&
                 collapsedActionIndex <
                     tabLeadingActionCount + tabTrailingActionCount),
         'collapsedActionIndex must identify an action button when collapsed.',
       ),
       super() {
    _progressAnimation.addListener(_handleProgressAnimationTick);
    _collapseProgressAnimation.addListener(_handleCollapseProgressTick);
    _tapGestureRecognizer = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = enabled ? _onTapDown : null;
    _createDragGestureRecognizer();
  }

  // Setter invalidation rule:
  //
  // - Geometry or child order changes: markNeedsLayout.
  // - Visual-only changes: markNeedsPaint.
  // - Accessibility text/state changes: markNeedsSemanticsUpdate.
  // - Overflow/compositing changes: markNeedsCompositingBitsUpdate.
  // - Gesture axis changes: replace the drag recognizer.

  // ---------------------------------------------------------------------------
  // Render inputs: controller and animations
  // ---------------------------------------------------------------------------

  TabController get controller => _controller;
  TabController _controller;
  set controller(TabController value) {
    if (value == _controller) return;
    _controller = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  Animation<double> get progressAnimation => _progressAnimation;
  Animation<double> _progressAnimation;
  set progressAnimation(Animation<double> value) {
    if (value == _progressAnimation) return;
    _progressAnimation.removeListener(_handleProgressAnimationTick);
    _progressAnimation = value;
    _progressAnimation.addListener(_handleProgressAnimationTick);
    progress = _progressAnimation.value;
  }

  double get progress => _progress;
  double _progress;
  set progress(double value) {
    if (value == _progress) return;
    assert(
      value >= 0 && value <= tabCount,
      'progress must be within the tab range.',
    );

    _progress = value;

    final scrollOffsetChanged = _implicitScroll();

    if (_progress == _progress.round()) {
      markNeedsSemanticsUpdate();
    }

    if (scrollOffsetChanged) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  void _handleProgressAnimationTick() {
    progress = _progressAnimation.value;
  }

  Animation<double> get collapseProgressAnimation => _collapseProgressAnimation;
  Animation<double> _collapseProgressAnimation;
  set collapseProgressAnimation(Animation<double> value) {
    if (value == _collapseProgressAnimation) return;
    _collapseProgressAnimation.removeListener(_handleCollapseProgressTick);
    _collapseProgressAnimation = value;
    _collapseProgressAnimation.addListener(_handleCollapseProgressTick);
    collapseProgress = _collapseProgressAnimation.value;
  }

  double get collapseProgress => _collapseProgress;
  double _collapseProgress;
  set collapseProgress(double value) {
    if (value == _collapseProgress) return;
    final wasCollapseAnimating = _isCollapseAnimating;
    final wasChildSemanticsCollapsed = _childSemanticsCollapsed;
    assert(
      value >= 0 && value <= 1,
      'collapseProgress must be within the collapse animation range.',
    );

    _collapseProgress = value;
    markNeedsLayout();
    markNeedsPaint();
    if (wasCollapseAnimating != _isCollapseAnimating) {
      markNeedsCompositingBitsUpdate();
    }
    if (wasChildSemanticsCollapsed != _childSemanticsCollapsed) {
      markNeedsSemanticsUpdate();
    }
  }

  bool get _isFullyCollapsed => collapseProgress >= 1.0;

  bool get _isFullyExpanded => collapseProgress <= 0.0;

  bool get _isCollapseAnimating => !_isFullyCollapsed && !_isFullyExpanded;

  bool get _childSemanticsCollapsed => collapsed || _fadingChildAlpha == 0;

  void _handleCollapseProgressTick() {
    collapseProgress = _collapseProgressAnimation.value;
  }

  // ---------------------------------------------------------------------------
  // Render inputs: animation configuration
  // ---------------------------------------------------------------------------

  Curve get curve => _curve;
  Curve _curve;
  set curve(Curve value) {
    if (value == _curve) return;
    _curve = value;
  }

  Duration get duration => _duration;
  Duration _duration;
  set duration(Duration value) {
    if (value == _duration) return;
    _duration = value;
  }

  // ---------------------------------------------------------------------------
  // Render inputs: child model and collapse action
  // ---------------------------------------------------------------------------

  int get tabCount => _tabCount;
  int _tabCount;
  set tabCount(int value) {
    if (value == _tabCount) return;
    assert(value > 0, 'tabCount must be greater than zero.');
    _tabCount = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  int get tabLeadingActionCount => _tabLeadingActionCount;
  int _tabLeadingActionCount;
  set tabLeadingActionCount(int value) {
    if (value == _tabLeadingActionCount) return;
    assert(value >= 0, 'tabLeadingActionCount must be non-negative.');
    _tabLeadingActionCount = value;
    markNeedsLayout();
  }

  int get tabTrailingActionCount => _tabTrailingActionCount;
  int _tabTrailingActionCount;
  set tabTrailingActionCount(int value) {
    if (value == _tabTrailingActionCount) return;
    assert(value >= 0, 'tabTrailingActionCount must be non-negative.');
    _tabTrailingActionCount = value;
    markNeedsLayout();
  }

  double get tabButtonGap => _tabButtonGap;
  double _tabButtonGap;
  set tabButtonGap(double value) {
    if (value == _tabButtonGap) return;
    assert(value >= 0, 'tabButtonGap must be non-negative.');
    _tabButtonGap = value;
    markNeedsLayout();
  }

  bool get collapsed => _collapsed;
  bool _collapsed;
  set collapsed(bool value) {
    if (value == _collapsed) return;
    _collapsed = value;
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int? get collapsedActionIndex => _collapsedActionIndex;
  int? _collapsedActionIndex;
  set collapsedActionIndex(int? value) {
    if (value == _collapsedActionIndex) return;
    assert(
      value == null ||
          (value >= 0 &&
              value < tabLeadingActionCount + tabTrailingActionCount),
      'collapsedActionIndex must identify an action button.',
    );
    _collapsedActionIndex = value;
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  // ---------------------------------------------------------------------------
  // Render inputs: gestures and feedback
  // ---------------------------------------------------------------------------

  Set<LogicalKeyboardKey> get pointerAxisModifiers => _pointerAxisModifiers;
  Set<LogicalKeyboardKey> _pointerAxisModifiers;
  set pointerAxisModifiers(Set<LogicalKeyboardKey> value) {
    if (setEquals(value, _pointerAxisModifiers)) return;
    _pointerAxisModifiers = value;
  }

  VoidCallback? get onTapFeedback => _onTapFeedback;
  VoidCallback? _onTapFeedback;
  set onTapFeedback(VoidCallback? value) {
    if (value == _onTapFeedback) return;
    _onTapFeedback = value;
  }

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _tapGestureRecognizer.onTapDown = _enabled ? _onTapDown : null;
    _dragGestureRecognizer?.onUpdate = _enabled ? _onDragUpdate : null;
    markNeedsSemanticsUpdate();
  }

  // ---------------------------------------------------------------------------
  // Render inputs: geometry
  // ---------------------------------------------------------------------------

  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  BorderRadius get tabBorderRadius => _tabBorderRadius;
  BorderRadius _tabBorderRadius;
  set tabBorderRadius(BorderRadius value) {
    if (value == _tabBorderRadius) return;
    _tabBorderRadius = value;
    markNeedsLayout();
  }

  double get tabExtent => _tabExtent;
  double _tabExtent;
  set tabExtent(double value) {
    if (value == _tabExtent) return;
    assert(value >= 0, 'tabExtent must be non-negative.');
    _tabExtent = value;
    markNeedsLayout();
  }

  TabEdge get tabEdge => _tabEdge;
  TabEdge _tabEdge;
  set tabEdge(TabEdge value) {
    if (value == _tabEdge) return;
    _tabEdge = value;
    markNeedsLayout();
  }

  Axis get tabAxis => _tabAxis;
  Axis _tabAxis;
  set tabAxis(Axis value) {
    if (value == _tabAxis) return;
    _tabAxis = value;
    _replaceDragGestureRecognizer();
    markNeedsLayout();
  }

  double get tabStripStart => _tabStripStart;
  double _tabStripStart;
  set tabStripStart(double value) {
    if (value == _tabStripStart) return;
    _tabStripStart = value;
    markNeedsLayout();
  }

  double get tabStripEnd => _tabStripEnd;
  double _tabStripEnd;
  set tabStripEnd(double value) {
    if (value == _tabStripEnd) return;
    _tabStripEnd = value;
    markNeedsLayout();
  }

  double get tabMinLength => _tabMinLength;
  double _tabMinLength;
  set tabMinLength(double value) {
    if (value == _tabMinLength) return;
    _tabMinLength = value;
    markNeedsLayout();
  }

  double get tabMaxLength => _tabMaxLength;
  double _tabMaxLength;
  set tabMaxLength(double value) {
    if (value == _tabMaxLength) return;
    _tabMaxLength = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  // ---------------------------------------------------------------------------
  // Render inputs: appearance
  // ---------------------------------------------------------------------------

  Color? get color => _color;
  Color? _color;
  set color(Color? value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  List<Color>? get colors => _colors;
  List<Color>? _colors;
  set colors(List<Color>? value) {
    if (listEquals(value, _colors)) return;
    _colors = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Render inputs: semantics
  // ---------------------------------------------------------------------------

  String? get semanticsLabel => _semanticsLabel;
  String? _semanticsLabel;
  set semanticsLabel(String? value) {
    if (value == _semanticsLabel) return;
    _semanticsLabel = value;
    markNeedsSemanticsUpdate();
  }

  String? get semanticsHint => _semanticsHint;
  String? _semanticsHint;
  set semanticsHint(String? value) {
    if (value == _semanticsHint) return;
    _semanticsHint = value;
    markNeedsSemanticsUpdate();
  }

  String Function(int index, int count)? get semanticsValueBuilder =>
      _semanticsValueBuilder;
  String Function(int index, int count)? _semanticsValueBuilder;
  set semanticsValueBuilder(String Function(int index, int count)? value) {
    if (value == _semanticsValueBuilder) return;
    _semanticsValueBuilder = value;
    markNeedsSemanticsUpdate();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! TabFrameParentData) {
      child.parentData = TabFrameParentData();
    }
  }

  @override
  void dispose() {
    _progressAnimation.removeListener(_handleProgressAnimationTick);
    _collapseProgressAnimation.removeListener(_handleCollapseProgressTick);
    _clipPathLayer.layer = null;
    _collapseClipLayer.layer = null;
    _tapGestureRecognizer.dispose();
    _dragGestureRecognizer?.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing =>
      (!_isFullyCollapsed && _hasTabOverflow) || _isCollapseAnimating;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => false;

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) {
    if (collapsed) {
      return false;
    }

    return size.contains(position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (collapsed || (_isCollapseAnimating && _fadingChildAlpha == 0)) {
      final action = _collapsedActionChild;
      return action != null && _hitTestChild(result, action, position);
    }

    for (var child = lastChild; child != null; child = childBefore(child)) {
      if (_hitTestChild(result, child, position)) {
        return true;
      }
    }

    return false;
  }

  bool _hitTestChild(
    BoxHitTestResult result,
    RenderBox child,
    Offset position,
  ) {
    final childParentData = child.parentData as TabFrameParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (result, transformed) {
        assert(
          transformed == position - childParentData.offset,
          'hit test transform must match child offset.',
        );
        return child.hitTest(result, position: transformed);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture recognizers
  // ---------------------------------------------------------------------------

  late TapGestureRecognizer _tapGestureRecognizer;
  DragGestureRecognizer? _dragGestureRecognizer;
  final Paint _backgroundPaint = Paint();

  void _createDragGestureRecognizer() {
    if (tabAxis == Axis.vertical) {
      _dragGestureRecognizer = VerticalDragGestureRecognizer(debugOwner: this)
        ..onUpdate = enabled ? _onDragUpdate : null;
    } else {
      _dragGestureRecognizer = HorizontalDragGestureRecognizer(debugOwner: this)
        ..onUpdate = enabled ? _onDragUpdate : null;
    }
  }

  void _replaceDragGestureRecognizer() {
    _dragGestureRecognizer?.dispose();
    _createDragGestureRecognizer();
  }

  // ---------------------------------------------------------------------------
  // Pointer routing
  // ---------------------------------------------------------------------------

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    assert(
      debugHandleEvent(event, entry),
      'pointer events must be handled through RenderBox debug handling.',
    );

    if (collapsed) {
      return;
    }

    if (event is PointerScrollEvent) {
      if (_hasTabOverflow) {
        _onPointerScroll(event);
      }
    } else if (event is PointerPanZoomStartEvent) {
      if (_hasTabOverflow) {
        _dragGestureRecognizer?.addPointerPanZoom(event);
      }
    } else if (event is PointerDownEvent) {
      _addRecognizersForPointerDown(event);
    }
  }

  void _addRecognizersForPointerDown(PointerDownEvent event) {
    final dx = event.localPosition.dx;
    final dy = event.localPosition.dy;

    if (!_tabLabelViewportContains(dx, dy)) {
      return;
    }

    _tapGestureRecognizer.addPointer(event);
    if (_hasTabOverflow) {
      _dragGestureRecognizer?.addPointer(event);
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll and tab selection
  // ---------------------------------------------------------------------------

  double _alignScrollDelta(PointerScrollEvent event) {
    if (event.kind != PointerDeviceKind.mouse || pointerAxisModifiers.isEmpty) {
      return event.scrollDelta.dy;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final flipAxes = pressed.any(pointerAxisModifiers.contains);

    return flipAxes ? event.scrollDelta.dx : event.scrollDelta.dy;
  }

  void _handlePointerScroll(PointerSignalEvent event) {
    assert(
      event is PointerScrollEvent,
      'event must be a pointer scroll event.',
    );
    final delta = _alignScrollDelta(event as PointerScrollEvent);
    scrollOffset += delta;
  }

  void _onPointerScroll(PointerScrollEvent event) {
    final dx = event.localPosition.dx;
    final dy = event.localPosition.dy;

    if (_tabLabelViewportContains(dx, dy)) {
      final delta = _alignScrollDelta(event);
      if (delta != 0.0) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          _handlePointerScroll,
        );
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    final dx = details.localPosition.dx;
    final dy = details.localPosition.dy;

    if (_tabLabelViewportContains(dx, dy)) {
      var pos = dx;

      if (tabAxis == Axis.vertical) {
        pos = dy;
      }

      _selectTab((pos - _tabLabelStart + scrollOffset) ~/ _tabMetrics.length);
      onTapFeedback?.call();
    }

    return;
  }

  void _selectTab(int index) {
    final targetIndex = index.clamp(0, controller.length - 1);
    controller.animateTo(targetIndex, duration: duration, curve: curve);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final dx = details.localPosition.dx;
    final dy = details.localPosition.dy;

    final primaryDelta = details.primaryDelta;
    if (primaryDelta != null && _tabLabelViewportContains(dx, dy)) {
      scrollOffset -= primaryDelta;
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll state and tab metrics
  // ---------------------------------------------------------------------------

  double get scrollOffset => _scrollOffset;
  double _scrollOffset = 0;
  set scrollOffset(double value) {
    if (_setScrollOffset(value)) {
      markNeedsLayout();
    }
  }

  bool _setScrollOffset(double value) {
    if (value == _scrollOffset || !_hasTabOverflow) {
      return false;
    }

    final clampedValue = value.clamp(0.0, _tabOverflow);
    if (clampedValue == _scrollOffset) {
      return false;
    }

    _scrollOffset = clampedValue;
    return true;
  }

  bool _implicitScroll() {
    if (collapsed) {
      return false;
    }

    final (destinationStart, destinationEnd) = _getIndicatorBounds(
      controller.index.toDouble(),
    );
    if (destinationStart >= _tabLabelStart && destinationEnd <= _tabLabelEnd) {
      return false;
    }

    final (indicatorStart, indicatorEnd) = _getIndicatorBounds(progress);

    if (indicatorEnd > _tabLabelEnd && indicatorStart >= _tabLabelStart) {
      return _setScrollOffset(scrollOffset + indicatorEnd - _tabLabelEnd);
    } else if (indicatorStart < _tabLabelStart &&
        indicatorEnd <= _tabLabelEnd) {
      return _setScrollOffset(scrollOffset + indicatorStart - _tabLabelStart);
    }

    return false;
  }

  bool _hasTabOverflow = false;
  double _tabOverflow = 0;
  RenderBox? _collapsedActionChild;

  late _TabViewport _tabViewport;
  late _TabMetrics _tabMetrics;

  // ---------------------------------------------------------------------------
  // Tab strip geometry
  // ---------------------------------------------------------------------------

  double get _tabStripExtent => tabExtent + _tabButtonCrossGap;

  double get _tabButtonCrossGap =>
      (tabLeadingActionCount == 0 && tabTrailingActionCount == 0)
      ? 0.0
      : tabButtonGap;

  double get _leadingActionLength => tabLeadingActionCount * tabExtent;

  double get _trailingActionLength => tabTrailingActionCount * tabExtent;

  double get _leadingOuterButtonGap =>
      tabLeadingActionCount == 0 ? 0.0 : tabButtonGap;

  double get _trailingOuterButtonGap =>
      tabTrailingActionCount == 0 ? 0.0 : tabButtonGap;

  double get _leadingButtonGap =>
      tabLeadingActionCount == 0 ? 0.0 : tabButtonGap;

  double get _trailingButtonGap =>
      tabTrailingActionCount == 0 ? 0.0 : tabButtonGap;

  int get _actionCount => tabLeadingActionCount + tabTrailingActionCount;

  bool get _hasCollapsedAction {
    final actionIndex = collapsedActionIndex;
    return actionIndex != null &&
        actionIndex >= 0 &&
        actionIndex < _actionCount;
  }

  // ---------------------------------------------------------------------------
  // Collapse layout helpers
  // ---------------------------------------------------------------------------

  Size _collapsedStripSize(BoxConstraints constraints) {
    if (tabAxis == Axis.horizontal) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : tabExtent;
      return constraints.constrain(Size(width, tabExtent));
    }

    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : tabExtent;
    return constraints.constrain(Size(tabExtent, height));
  }

  double _lerpDimension(double expanded, double collapsed) {
    return lerpDouble(expanded, collapsed, collapseProgress) ?? collapsed;
  }

  Size _lerpCollapseSize(Size expanded, Size collapsed) {
    return Size(
      _lerpDimension(expanded.width, collapsed.width),
      _lerpDimension(expanded.height, collapsed.height),
    );
  }

  Offset _getCollapsedActionOffset(RenderBox action) {
    final actionIndex = collapsedActionIndex ?? 0;
    final isTrailingAction = actionIndex >= tabLeadingActionCount;

    switch (tabEdge) {
      case TabEdge.left:
        return Offset(
          0,
          isTrailingAction ? size.height - action.size.height : 0,
        );
      case TabEdge.top:
        return Offset(isTrailingAction ? size.width - action.size.width : 0, 0);
      case TabEdge.right:
        return Offset(
          size.width - action.size.width,
          isTrailingAction ? size.height - action.size.height : 0,
        );
      case TabEdge.bottom:
        return Offset(
          isTrailingAction ? size.width - action.size.width : 0,
          size.height - action.size.height,
        );
    }
  }

  void _layoutCollapsed() {
    assert(
      _hasCollapsedAction,
      'collapsedActionIndex must identify an action button when collapsed.',
    );

    size = _collapsedStripSize(constraints);
    _hasTabOverflow = false;
    _tabOverflow = 0;
    _scrollOffset = 0;
    _clipPath = null;
    _clipPathCacheKey = null;
    _tabViewport = _TabViewport(
      parentSize: size,
      tabEdge: tabEdge,
      tabExtent: tabExtent,
      tabStripStart: 0,
      tabStripEnd: 1,
    );
    _tabMetrics = _TabMetrics(
      count: tabCount,
      range: 0,
      minLength: 0,
      maxLength: 0,
    );

    final hiddenConstraints = BoxConstraints.tight(Size.zero);
    final actionConstraints = BoxConstraints.tightFor(
      width: tabExtent,
      height: tabExtent,
    );

    _layoutCollapsedChildren(hiddenConstraints, actionConstraints);
  }

  void _layoutCollapsedChildren(
    BoxConstraints hiddenConstraints,
    BoxConstraints actionConstraints,
  ) {
    _collapsedActionChild = null;

    var nextChild = firstChild;
    for (var childIndex = 0; nextChild != null; childIndex++) {
      final actionIndex = childIndex - tabCount - 1;
      final isVisibleAction = actionIndex == collapsedActionIndex;
      nextChild.layout(
        isVisibleAction ? actionConstraints : hiddenConstraints,
        parentUsesSize: true,
      );
      final actionParentData = nextChild.parentData as TabFrameParentData;
      actionParentData.offset = isVisibleAction
          ? _getCollapsedActionOffset(nextChild)
          : Offset.zero;
      if (isVisibleAction) {
        _collapsedActionChild = nextChild;
      }
      nextChild = childAfter(nextChild);
    }
  }

  // ---------------------------------------------------------------------------
  // Tab label geometry
  // ---------------------------------------------------------------------------

  double get _tabLabelStart =>
      _tabViewport.start +
      _leadingOuterButtonGap +
      _leadingActionLength +
      _leadingButtonGap;

  double get _tabLabelEnd => max(
    _tabLabelStart,
    _tabViewport.end -
        _trailingOuterButtonGap -
        _trailingActionLength -
        _trailingButtonGap,
  );

  double get _tabLabelRange => max(0.0, _tabLabelEnd - _tabLabelStart);

  bool _tabLabelViewportContains(double x, double y) {
    if (_tabMetrics.length <= 0) {
      return false;
    }

    final labelEnd = min(
      _tabLabelEnd,
      _tabLabelStart + _tabMetrics.totalLength,
    );

    switch (tabEdge) {
      case TabEdge.left:
        return x <= _tabStripExtent && y.isBetween(_tabLabelStart, labelEnd);
      case TabEdge.top:
        return y <= _tabStripExtent && x.isBetween(_tabLabelStart, labelEnd);
      case TabEdge.right:
        return x >= size.width - _tabStripExtent &&
            y.isBetween(_tabLabelStart, labelEnd);
      case TabEdge.bottom:
        return y >= size.height - _tabStripExtent &&
            x.isBetween(_tabLabelStart, labelEnd);
    }
  }

  Rect get _tabLabelClipRect {
    final radiusExtent = _radiusForFrame(tabBorderRadius).bottomRight.x;
    final side = tabAxis == Axis.horizontal ? size.width : size.height;
    final clipStart = tabLeadingActionCount == 0
        ? max(0.0, _tabLabelStart - radiusExtent)
        : _tabLabelStart;
    final clipEnd = tabTrailingActionCount == 0
        ? min(side, _tabLabelEnd + radiusExtent)
        : _tabLabelEnd;

    switch (tabEdge) {
      case TabEdge.left:
        return Rect.fromLTRB(0, clipStart, _tabStripExtent, clipEnd);
      case TabEdge.top:
        return Rect.fromLTRB(clipStart, 0, clipEnd, _tabStripExtent);
      case TabEdge.right:
        return Rect.fromLTRB(
          size.width - _tabStripExtent,
          clipStart,
          size.width,
          clipEnd,
        );
      case TabEdge.bottom:
        return Rect.fromLTRB(
          clipStart,
          size.height - _tabStripExtent,
          clipEnd,
          size.height,
        );
    }
  }

  Offset _getTabStripChildOffset({
    required double start,
    required double slotLength,
    required Size childSize,
  }) {
    final horizontal = tabAxis == Axis.horizontal;
    final mainSize = horizontal ? childSize.width : childSize.height;
    final crossSize = horizontal ? childSize.height : childSize.width;
    final mainInset = (slotLength - mainSize) / 2;
    final crossInset = (_tabStripExtent - crossSize) / 2;

    switch (tabEdge) {
      case TabEdge.left:
        return Offset(crossInset, start + mainInset);
      case TabEdge.top:
        return Offset(start + mainInset, crossInset);
      case TabEdge.right:
        return Offset(
          size.width - crossInset - childSize.width,
          start + mainInset,
        );
      case TabEdge.bottom:
        return Offset(
          start + mainInset,
          size.height - crossInset - childSize.height,
        );
    }
  }

  Offset _getTabButtonOffset({required double start, required Size childSize}) {
    final horizontal = tabAxis == Axis.horizontal;
    final mainSize = horizontal ? childSize.width : childSize.height;
    final mainInset = (tabExtent - mainSize) / 2;

    switch (tabEdge) {
      case TabEdge.left:
        return Offset(0, start + mainInset);
      case TabEdge.top:
        return Offset(start + mainInset, 0);
      case TabEdge.right:
        return Offset(size.width - childSize.width, start + mainInset);
      case TabEdge.bottom:
        return Offset(start + mainInset, size.height - childSize.height);
    }
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  // Layout contract:
  //
  // - Computes the expanded frame size.
  // - Interpolates expanded/collapsed size.
  // - Updates tab viewport and tab metrics.
  // - Clamps scroll offset.
  // - Rebuilds clip path cache when overflow geometry changes.
  // - Positions content, tabs, leading actions, and trailing actions.
  //
  // Keep this in sync with TabFrame.children, hitTestChildren, _paint, and
  // visitChildrenForSemantics.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  void performLayout() {
    if (_isFullyCollapsed) {
      _layoutCollapsed();
      return;
    }

    // Layout phase 1: main content child.
    // Child index 0 is always the content body.
    var child = firstChild;

    if (child == null) {
      return;
    }

    late final EdgeInsets edges;

    if (tabAxis == Axis.vertical) {
      edges = EdgeInsets.only(left: _tabStripExtent);
    } else {
      edges = EdgeInsets.only(top: _tabStripExtent);
    }

    child.layout(constraints.deflate(edges), parentUsesSize: true);

    final expandedSize = constraints.constrain(edges.inflateSize(child.size));
    size = _lerpCollapseSize(expandedSize, _collapsedStripSize(constraints));

    final childParentData = child.parentData as TabFrameParentData;

    childParentData.offset = switch (tabEdge) {
      TabEdge.left => Offset(_tabStripExtent, 0),
      TabEdge.top => Offset(0, _tabStripExtent),
      TabEdge.right || TabEdge.bottom => Offset.zero,
    };

    // Layout shared tab strip state before child slots consume it.
    child = childAfter(child);
    _collapsedActionChild = null;

    _tabViewport = _TabViewport(
      parentSize: size,
      tabEdge: tabEdge,
      tabExtent: _tabStripExtent,
      tabStripStart: tabStripStart,
      tabStripEnd: tabStripEnd,
    );

    _tabMetrics = _TabMetrics(
      count: tabCount,
      range: _tabLabelRange,
      minLength: tabMinLength,
      maxLength: tabMaxLength,
    );

    _tabOverflow = _tabMetrics.totalLength - _tabLabelRange;

    final hasOverflow = _tabOverflow > 0;
    if (_hasTabOverflow != hasOverflow) {
      markNeedsCompositingBitsUpdate();
    }
    _hasTabOverflow = hasOverflow;

    if (_hasTabOverflow) {
      _scrollOffset = _scrollOffset.clamp(0.0, _tabOverflow);
    } else {
      _scrollOffset = 0.0;
    }

    final clipPathCacheKey = _ClipPathCacheKey(
      size: size,
      tabEdge: tabEdge,
      tabAxis: tabAxis,
      tabExtent: _tabStripExtent,
      tabStripStart: _tabViewport.start,
      tabStripRange: _tabViewport.range,
      hasTabOverflow: _hasTabOverflow,
      tabBorderRadius: tabBorderRadius,
    );

    if (_hasTabOverflow) {
      if (_clipPathCacheKey != clipPathCacheKey) {
        _clipPath = _buildClipPath();
        _clipPathCacheKey = clipPathCacheKey;
      }
    } else {
      _clipPath = null;
      _clipPathCacheKey = clipPathCacheKey;
    }

    var tabConstraints = BoxConstraints(
      maxWidth: _tabMetrics.length,
      maxHeight: tabExtent,
    );

    if (tabAxis == Axis.vertical) {
      tabConstraints = tabConstraints.flipped;
    }

    // Layout phase 2: tab labels.
    // Children [1, tabCount] are scrollable tab labels.
    for (var index = 0; index < tabCount && child != null; index++) {
      child.layout(tabConstraints, parentUsesSize: true);

      final tabParentData = child.parentData as TabFrameParentData;

      final displacement = _tabMetrics.length * index - scrollOffset;

      tabParentData.offset = _getTabStripChildOffset(
        start: displacement + _tabLabelStart,
        slotLength: _tabMetrics.length,
        childSize: child.size,
      );

      child = childAfter(child);
    }

    final actionConstraints = BoxConstraints.tightFor(
      width: tabExtent,
      height: tabExtent,
    );

    // Layout phase 3: leading action buttons.
    // These are fixed slots before the tab label viewport.
    for (
      var index = 0;
      index < tabLeadingActionCount && child != null;
      index++
    ) {
      child.layout(actionConstraints, parentUsesSize: true);
      final actionParentData = child.parentData as TabFrameParentData;
      actionParentData.offset = _getTabButtonOffset(
        start: _tabViewport.start + _leadingOuterButtonGap + index * tabExtent,
        childSize: child.size,
      );
      if (index == collapsedActionIndex) {
        _collapsedActionChild = child;
      }
      child = childAfter(child);
    }

    // Layout phase 4: trailing action buttons.
    // These are fixed slots after the tab label viewport.
    for (
      var index = 0;
      index < tabTrailingActionCount && child != null;
      index++
    ) {
      child.layout(actionConstraints, parentUsesSize: true);
      final actionParentData = child.parentData as TabFrameParentData;
      actionParentData.offset = _getTabButtonOffset(
        start: _tabLabelEnd + _trailingButtonGap + index * tabExtent,
        childSize: child.size,
      );
      if (tabLeadingActionCount + index == collapsedActionIndex) {
        _collapsedActionChild = child;
      }
      child = childAfter(child);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_isFullyCollapsed) {
      return _collapsedStripSize(constraints);
    }

    final child = firstChild;

    if (child == null) {
      return Size.zero;
    }

    late final EdgeInsets edges;

    if (tabAxis == Axis.vertical) {
      edges = EdgeInsets.only(left: _tabStripExtent);
    } else {
      edges = EdgeInsets.only(top: _tabStripExtent);
    }

    final childSize = child.getDryLayout(constraints.deflate(edges));

    final expandedSize = constraints.constrain(edges.inflateSize(childSize));
    return _lerpCollapseSize(expandedSize, _collapsedStripSize(constraints));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_isFullyCollapsed) {
      return tabExtent;
    }

    final childMinIntrinsicWidth =
        firstChild?.getMinIntrinsicWidth(height) ?? 0.0;
    final expandedWidth = tabAxis == Axis.vertical
        ? childMinIntrinsicWidth + _tabStripExtent
        : childMinIntrinsicWidth;
    return _lerpDimension(expandedWidth, tabExtent);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_isFullyCollapsed) {
      return tabExtent;
    }

    final childMaxIntrinsicWidth =
        firstChild?.getMaxIntrinsicWidth(height) ?? 0.0;
    final expandedWidth = tabAxis == Axis.vertical
        ? childMaxIntrinsicWidth + _tabStripExtent
        : childMaxIntrinsicWidth;
    return _lerpDimension(expandedWidth, tabExtent);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_isFullyCollapsed) {
      return tabExtent;
    }

    final childMinIntrinsicHeight =
        firstChild?.getMinIntrinsicHeight(width) ?? 0.0;
    final expandedHeight = tabAxis == Axis.vertical
        ? childMinIntrinsicHeight
        : childMinIntrinsicHeight + _tabStripExtent;
    return _lerpDimension(expandedHeight, tabExtent);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (_isFullyCollapsed) {
      return tabExtent;
    }

    final childMaxIntrinsicHeight =
        firstChild?.getMaxIntrinsicHeight(width) ?? 0.0;
    final expandedHeight = tabAxis == Axis.vertical
        ? childMaxIntrinsicHeight
        : childMaxIntrinsicHeight + _tabStripExtent;
    return _lerpDimension(expandedHeight, tabExtent);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  // ---------------------------------------------------------------------------
  // Frame path and clipping geometry
  // ---------------------------------------------------------------------------

  Path? _clipPath;
  _ClipPathCacheKey? _clipPathCacheKey;
  final LayerHandle<ClipPathLayer> _clipPathLayer =
      LayerHandle<ClipPathLayer>();
  final LayerHandle<ClipRectLayer> _collapseClipLayer =
      LayerHandle<ClipRectLayer>();

  // The clip path geometry stays in one method so the cache key can be checked
  // against the complete set of edge, axis, extent, range, and radius inputs.
  // ignore: halstead-volume, source-lines-of-code
  Path _buildClipPath() {
    final radiusExtent = _radiusForFrame(tabBorderRadius).bottomRight.x;
    final double cutoff = max(0, _tabViewport.start - radiusExtent);

    if (tabAxis == Axis.vertical) {
      final viewportBottom = min(
        size.height,
        cutoff + _tabViewport.size.height + radiusExtent,
      );
      final tabStripRect = tabEdge == TabEdge.right
          ? Rect.fromLTRB(
              size.width - _tabStripExtent,
              cutoff,
              size.width,
              viewportBottom,
            )
          : Rect.fromLTRB(0, cutoff, _tabStripExtent, viewportBottom);
      final contentRect = tabEdge == TabEdge.right
          ? Rect.fromLTRB(0, 0, size.width - _tabStripExtent, size.height)
          : Rect.fromLTRB(_tabStripExtent, 0, size.width, size.height);

      return Path.combine(
        PathOperation.xor,
        Path()..addRect(tabStripRect),
        Path()..addRect(contentRect),
      );
    }

    final viewportRight = min(
      size.width,
      cutoff + _tabViewport.size.width + radiusExtent,
    );
    final tabStripRect = tabEdge == TabEdge.top
        ? Rect.fromLTRB(cutoff, 0, viewportRight, _tabStripExtent)
        : Rect.fromLTRB(
            cutoff,
            size.height - _tabStripExtent,
            viewportRight,
            size.height,
          );
    final contentRect = tabEdge == TabEdge.top
        ? Rect.fromLTRB(0, _tabStripExtent, size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width, size.height - _tabStripExtent);

    return Path.combine(
      PathOperation.xor,
      Path()..addRect(tabStripRect),
      Path()..addRect(contentRect),
    );
  }

  (double, double) _getIndicatorBounds(double factor) {
    final start = factor * _tabMetrics.length + _tabLabelStart - scrollOffset;
    final end = start + _tabMetrics.length;

    return (start, end);
  }

  BorderRadius _radiusForFrame(BorderRadius radius) {
    return switch (tabEdge) {
      TabEdge.top => BorderRadius.only(
        topLeft: radius.bottomLeft,
        topRight: radius.bottomRight,
        bottomRight: radius.topRight,
        bottomLeft: radius.topLeft,
      ),
      TabEdge.right => BorderRadius.only(
        topLeft: radius.topRight,
        topRight: radius.topLeft,
        bottomRight: radius.bottomLeft,
        bottomLeft: radius.bottomRight,
      ),
      TabEdge.bottom || TabEdge.left => radius,
    };
  }

  // The frame path is easier to verify as one edge-aware builder because the
  // critical points are shared by adjacent contour segments.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  Path _getPath() {
    // Path phase 1: capture current frame and indicator geometry.
    final width = size.width;
    final height = size.height;

    final (indicatorStart, indicatorEnd) = _getIndicatorBounds(progress);
    final radius = _radiusForFrame(borderRadius);
    final tabRadius = _radiusForFrame(tabBorderRadius);

    double? critical1;
    double? critical2;
    double? critical3;
    double? critical4;

    if (tabAxis == Axis.vertical) {
      // Path phase 2a: prepare vertical edge mirroring and radius blending.
      final flipX = tabEdge == TabEdge.right;
      double x(double value) => flipX ? width - value : value;

      final tbrx = tabRadius.bottomRight.x;
      final tblx = tabRadius.bottomLeft.x;
      final tly = radius.topLeft.y;
      final bly = radius.bottomLeft.y;

      final sum1 = tbrx + tly;
      if (sum1 > 0 && indicatorStart < sum1) {
        critical1 = tbrx / sum1 * indicatorStart;
        critical2 = tly / sum1 * indicatorStart;
      }

      final sum2 = tblx + bly;
      if (sum2 > 0 && height - indicatorEnd < sum2) {
        critical3 = bly / sum2 * (height - indicatorEnd);
        critical4 = tblx / sum2 * (height - indicatorEnd);
      }

      // Path phase 3a: build the vertical frame contour.
      return Path()
        ..moveTo(x(width - radius.topRight.x), 0)
        ..quadraticBezierTo(x(width), 0, x(width), radius.topRight.y)
        ..lineTo(x(width), height - radius.bottomRight.y)
        ..quadraticBezierTo(
          x(width),
          height,
          x(width - radius.bottomRight.x),
          height,
        )
        ..lineTo(x(_tabStripExtent + radius.bottomLeft.x), height)
        ..quadraticBezierTo(
          x(_tabStripExtent),
          height,
          x(_tabStripExtent),
          max(height - (critical3 ?? bly), indicatorEnd),
        )
        ..lineTo(
          x(_tabStripExtent),
          min(height, indicatorEnd + (critical4 ?? tblx)),
        )
        ..quadraticBezierTo(
          x(_tabStripExtent),
          indicatorEnd,
          x(_tabStripExtent - tabRadius.bottomLeft.y),
          indicatorEnd,
        )
        ..lineTo(x(tabRadius.topLeft.y), indicatorEnd)
        ..quadraticBezierTo(
          x(0),
          indicatorEnd,
          x(0),
          indicatorEnd - tabRadius.topLeft.x,
        )
        ..lineTo(x(0), indicatorStart + tabRadius.topRight.x)
        ..quadraticBezierTo(
          x(0),
          indicatorStart,
          x(tabRadius.topRight.y),
          indicatorStart,
        )
        ..lineTo(
          x(_tabStripExtent - tabRadius.bottomRight.y),
          indicatorStart,
        )
        ..quadraticBezierTo(
          x(_tabStripExtent),
          indicatorStart,
          x(_tabStripExtent),
          max(0, indicatorStart - (critical1 ?? tbrx)),
        )
        ..lineTo(x(_tabStripExtent), min(critical2 ?? tly, indicatorStart))
        ..quadraticBezierTo(
          x(_tabStripExtent),
          0,
          x(_tabStripExtent + radius.topLeft.x),
          0,
        )
        ..close();
    } else {
      // Path phase 2b: prepare horizontal edge mirroring and radius blending.
      final flipY = tabEdge == TabEdge.top;
      double y(double value) => flipY ? height - value : value;

      final brx = radius.bottomRight.x;
      final tblx = tabRadius.bottomLeft.x;
      final tbrx = tabRadius.topLeft.y;
      final blx = radius.bottomLeft.x;

      final sum1 = brx + tblx;
      if (sum1 > 0 && width - indicatorEnd < sum1) {
        critical1 = brx / sum1 * (width - indicatorEnd);
        critical2 = tblx / sum1 * (width - indicatorEnd);
      }

      final sum2 = tbrx + blx;
      if (sum2 > 0 && indicatorStart < sum2) {
        critical3 = tbrx / sum2 * indicatorStart;
        critical4 = blx / sum2 * indicatorStart;
      }

      // Path phase 3b: build the horizontal frame contour.
      return Path()
        ..moveTo(0, y(radius.topLeft.y))
        ..quadraticBezierTo(0, y(0), radius.topLeft.x, y(0))
        ..lineTo(width - radius.topRight.x, y(0))
        ..quadraticBezierTo(width, y(0), width, y(radius.topRight.y))
        ..lineTo(
          width,
          y(height - _tabStripExtent - radius.bottomRight.y),
        )
        ..quadraticBezierTo(
          width,
          y(height - _tabStripExtent),
          max(width - (critical1 ?? brx), indicatorEnd),
          y(height - _tabStripExtent),
        )
        ..lineTo(
          min(width, indicatorEnd + (critical2 ?? tblx)),
          y(height - _tabStripExtent),
        )
        ..quadraticBezierTo(
          indicatorEnd,
          y(height - _tabStripExtent),
          indicatorEnd,
          y(height - _tabStripExtent + tabRadius.bottomLeft.y),
        )
        ..lineTo(indicatorEnd, y(height - tabRadius.topLeft.y))
        ..quadraticBezierTo(
          indicatorEnd,
          y(height),
          indicatorEnd - tabRadius.topLeft.x,
          y(height),
        )
        ..lineTo(indicatorStart + tabRadius.topRight.x, y(height))
        ..quadraticBezierTo(
          indicatorStart,
          y(height),
          indicatorStart,
          y(height - tabRadius.topRight.y),
        )
        ..lineTo(
          indicatorStart,
          y(height - _tabStripExtent + tabRadius.bottomRight.y),
        )
        ..quadraticBezierTo(
          indicatorStart,
          y(height - _tabStripExtent),
          max(0, indicatorStart - (critical3 ?? tbrx)),
          y(height - _tabStripExtent),
        )
        ..lineTo(
          min(critical4 ?? blx, indicatorStart),
          y(height - _tabStripExtent),
        )
        ..quadraticBezierTo(
          0,
          y(height - _tabStripExtent),
          0,
          y(height - _tabStripExtent - radius.bottomLeft.y),
        )
        ..close();
    }
  }

  // ---------------------------------------------------------------------------
  // Paint state
  // ---------------------------------------------------------------------------

  double _animationFraction(double current, int previous, int next) {
    if (next - previous == 0) {
      return 1;
    }
    return (current - previous) / (next - previous);
  }

  Color get _backgroundColor {
    final tabColors = colors;
    if (tabColors == null) {
      return color ?? Colors.transparent;
    }

    final animationFraction = _animationFraction(
      progress,
      controller.previousIndex,
      controller.index,
    ).clamp(0.0, 1.0);

    return Color.lerp(
          tabColors[controller.previousIndex],
          tabColors[controller.index],
          animationFraction,
        ) ??
        Colors.transparent;
  }

  int get _fadingChildAlpha {
    if (!_isCollapseAnimating) {
      return 255;
    }

    final opacity = (1.0 - collapseProgress * 2).clamp(0.0, 1.0);
    return (opacity * 255).round();
  }

  int get _frameAlpha {
    if (!_isCollapseAnimating) {
      return 255;
    }

    return ((1.0 - collapseProgress) * 255).round();
  }

  // ---------------------------------------------------------------------------
  // Painting
  // ---------------------------------------------------------------------------
  //
  // Paint pipeline:
  //
  // paint
  //   -> collapsed: paint only the collapsed action
  //   -> collapse animation: clip to current size, then paint uncollapsed frame
  //   -> uncollapsed: optionally clip overflow, then paint
  //
  // _paint
  //   -> background path
  //   -> content child
  //   -> tab labels, clipped on overflow
  //   -> action buttons

  void _paint(PaintingContext context, Offset offset) {
    if (_isFullyCollapsed) {
      _paintCollapsed(context, offset);
      return;
    }

    final canvas = context.canvas;
    _paintBackground(canvas, offset);

    final content = firstChild;
    if (content == null) {
      return;
    }

    _paintChild(context, offset, content, fadeDuringCollapse: true);

    var child = childAfter(content);
    if (_hasTabOverflow) {
      canvas.save();
      canvas.clipRect(_tabLabelClipRect.shift(offset));
    }

    for (var index = 0; index < tabCount && child != null; index++) {
      _paintChild(context, offset, child, fadeDuringCollapse: true);
      child = childAfter(child);
    }

    if (_hasTabOverflow) {
      canvas.restore();
    }

    for (; child != null; child = childAfter(child)) {
      _paintChild(
        context,
        offset,
        child,
        fadeDuringCollapse: child != _collapsedActionChild,
      );
    }
  }

  void _paintBackground(Canvas canvas, Offset offset) {
    final frameAlpha = _frameAlpha;
    if (frameAlpha == 0) {
      return;
    }

    final backgroundColor = _backgroundColor;
    final paint = _backgroundPaint
      ..color = backgroundColor.withAlpha(
        (backgroundColor.a * 255 * frameAlpha / 255).round(),
      );
    final path = _getPath();

    if (offset == Offset.zero) {
      canvas.drawPath(path, paint);
    } else {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawPath(path, paint)
        ..restore();
    }
  }

  void _paintCollapsed(PaintingContext context, Offset offset) {
    final action = _collapsedActionChild;
    if (action == null) {
      return;
    }

    _paintChild(context, offset, action);
  }

  void _paintChild(
    PaintingContext context,
    Offset offset,
    RenderBox child, {
    bool fadeDuringCollapse = false,
  }) {
    final childOffset =
        offset + (child.parentData as TabFrameParentData).offset;
    final alpha = fadeDuringCollapse ? _fadingChildAlpha : 255;

    if (alpha == 0) {
      return;
    }
    if (alpha == 255) {
      context.paintChild(child, childOffset);
      return;
    }

    context.pushOpacity(childOffset, alpha, (context, offset) {
      context.paintChild(child, offset);
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_isFullyCollapsed) {
      _clipPathLayer.layer = null;
      _collapseClipLayer.layer = null;
      _paintCollapsed(context, offset);
      return;
    }

    if (_isCollapseAnimating) {
      _collapseClipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintUncollapsed,
        oldLayer: _collapseClipLayer.layer,
      );
      return;
    }

    _collapseClipLayer.layer = null;
    _paintUncollapsed(context, offset);
  }

  void _paintUncollapsed(PaintingContext context, Offset offset) {
    final clipPath = _clipPath;
    if (_hasTabOverflow && clipPath != null) {
      _clipPathLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        clipPath,
        _paint,
        clipBehavior: Clip.hardEdge,
        oldLayer: _clipPathLayer.layer,
      );
    } else {
      _clipPathLayer.layer = null;
      _paint(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(covariant RenderObject child) {
    return Rect.fromPoints(Offset.zero, Offset(size.width, size.height));
  }

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------
  //
  // The render object exposes the tab frame as an adjustable semantic control.
  // When collapsed or fully faded, only the collapsed action child participates.

  String _getTabSemanticText(int index, int length) {
    final valueBuilder = semanticsValueBuilder;
    if (valueBuilder != null) {
      return valueBuilder(index, length);
    }

    return 'Viewing tab ${index + 1} of $length';
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    if (collapsed) {
      return;
    }

    final int decreasedIndex = max(controller.index - 1, 0);
    final int increasedIndex = min(controller.index + 1, tabCount - 1);

    config
      ..label = semanticsLabel ?? 'Tab view'
      ..hint = semanticsHint ?? 'Increase or decrease to view a different tab'
      ..value = _getTabSemanticText(controller.index, tabCount)
      ..decreasedValue = _getTabSemanticText(decreasedIndex, tabCount)
      ..increasedValue = _getTabSemanticText(increasedIndex, tabCount)
      ..textDirection = textDirection
      ..isEnabled = enabled;

    if (enabled) {
      config.onDecrease = () {
        _selectTab(decreasedIndex);
      };
      config.onIncrease = () {
        _selectTab(increasedIndex);
      };
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_childSemanticsCollapsed) {
      super.visitChildrenForSemantics(visitor);
      return;
    }

    final action = _collapsedActionChild;
    if (action != null) {
      visitor(action);
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  // Diagnostics intentionally enumerate the render object's full mutable state
  // so debug output can catch missed updateRenderObject handoffs.
  // ignore: halstead-volume, source-lines-of-code
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // Controller, animations, and scroll state.
    properties.add(
      DiagnosticsProperty<TabController>('controller', controller),
    );
    properties.add(DoubleProperty('scrollOffset', scrollOffset));
    properties.add(DoubleProperty('progress', progress));
    properties.add(
      DiagnosticsProperty<Animation<double>>(
        'progressAnimation',
        progressAnimation,
      ),
    );
    properties.add(DoubleProperty('collapseProgress', collapseProgress));
    properties.add(
      DiagnosticsProperty<Animation<double>>(
        'collapseProgressAnimation',
        collapseProgressAnimation,
      ),
    );

    // Child model and collapse action.
    properties.add(IntProperty('tabCount', tabCount));
    properties.add(IntProperty('tabLeadingActionCount', tabLeadingActionCount));
    properties.add(
      IntProperty('tabTrailingActionCount', tabTrailingActionCount),
    );
    properties.add(DoubleProperty('tabButtonGap', tabButtonGap));
    properties.add(DiagnosticsProperty<bool>('collapsed', collapsed));
    properties.add(IntProperty('collapsedActionIndex', collapsedActionIndex));
    properties.add(DiagnosticsProperty<Curve>('curve', curve));
    properties.add(DiagnosticsProperty<Duration>('duration', duration));

    // Geometry.
    properties.add(
      DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius),
    );
    properties.add(
      DiagnosticsProperty<BorderRadius>('tabBorderRadius', tabBorderRadius),
    );
    properties.add(DoubleProperty('tabExtent', tabExtent));
    properties.add(EnumProperty<TabEdge>('tabEdge', tabEdge));
    properties.add(EnumProperty<Axis>('tabAxis', tabAxis));
    properties.add(DoubleProperty('tabStripStart', tabStripStart));
    properties.add(DoubleProperty('tabStripEnd', tabStripEnd));
    properties.add(DoubleProperty('tabMinLength', tabMinLength));
    properties.add(DoubleProperty('tabMaxLength', tabMaxLength));

    // Appearance.
    properties.add(ColorProperty('color', color));
    properties.add(IterableProperty<Color>('colors', colors));

    // Semantics and input.
    properties.add(StringProperty('semanticsLabel', semanticsLabel));
    properties.add(StringProperty('semanticsHint', semanticsHint));
    properties.add(
      ObjectFlagProperty<String Function(int index, int count)?>.has(
        'semanticsValueBuilder',
        semanticsValueBuilder,
      ),
    );
    properties.add(DiagnosticsProperty<bool>('enabled', enabled));
    properties.add(
      IterableProperty<LogicalKeyboardKey>(
        'pointerAxisModifiers',
        pointerAxisModifiers,
      ),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback?>.has('onTapFeedback', onTapFeedback),
    );
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
  }
}
