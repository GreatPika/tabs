// Tab composition is tied to current animation/controller state in this state
// object; extracting these helpers into standalone widgets would duplicate
// transient state and make the render flow harder to follow.
// ignore_for_file: avoid-returning-widgets

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'render/tabs_frame.dart';
import 'tab_edge.dart';

/// Button appearance variants available for tab-strip action buttons.
enum TabsActionButtonVariant {
  /// Standard [IconButton].
  standard,

  /// Filled [IconButton.filled].
  filled,

  /// Filled tonal [IconButton.filledTonal].
  filledTonal,

  /// Outlined [IconButton.outlined].
  outlined,
}

/// Built-in behaviors available for tab-strip action buttons.
enum TabsActionButtonAction {
  /// Run the button's custom [TabsActionButton.onPressed] callback.
  custom,

  /// Toggle [Tabs.collapsed] through [Tabs.onCollapsedChanged].
  ///
  /// A `Tabs` instance can have at most one collapse-toggle button. When
  /// [Tabs.collapsed] is true, exactly one collapse-toggle button must be
  /// present so the collapsed strip has a visible action that can expand it.
  /// The button is disabled when [Tabs.onCollapsedChanged] is null, and its own
  /// [TabsActionButton.onPressed] callback is not invoked.
  toggleCollapse,
}

int _collapseToggleActionCount(
  List<TabsActionButton> leadingButtons,
  List<TabsActionButton> trailingButtons,
) {
  return leadingButtons.where(_isCollapseToggleAction).length +
      trailingButtons.where(_isCollapseToggleAction).length;
}

bool _isCollapseToggleAction(TabsActionButton button) {
  return button.action == TabsActionButtonAction.toggleCollapse;
}

/// An action button shown in the tab strip.
///
/// `Tabs` owns the button widget, size, shape, and tab-strip alignment. Callers
/// provide either an [IconData] or a widget and the button action.
class TabsActionButton {
  const TabsActionButton({
    required this.icon,
    this.onPressed,
    this.key,
    this.semanticLabel,
    this.variant = TabsActionButtonVariant.filledTonal,
    this.action = TabsActionButtonAction.custom,
  }) : _iconWidget = null;

  /// Creates an action button with any icon widget.
  ///
  /// Use this constructor for icons that are rendered as widgets, such as
  /// `HugeIcon` from the `hugeicons` package.
  const TabsActionButton.widget({
    required Widget icon,
    this.onPressed,
    this.key,
    this.semanticLabel,
    this.variant = TabsActionButtonVariant.filledTonal,
    this.action = TabsActionButtonAction.custom,
  }) : icon = null,
       _iconWidget = icon;

  /// Key assigned to the generated button.
  final Key? key;

  /// Icon displayed by the generated button.
  ///
  /// This can be any [IconData], including [Icons] (Material Icons),
  /// `CupertinoIcons`, or another icon-font package. Use
  /// [TabsActionButton.widget] for icons rendered as widgets.
  final IconData? icon;

  final Widget? _iconWidget;

  /// Called when the generated button is tapped.
  ///
  /// If null, the button is disabled.
  final VoidCallback? onPressed;

  /// Behavior triggered by this button.
  ///
  /// Defaults to [TabsActionButtonAction.custom].
  final TabsActionButtonAction action;

  /// Semantic label passed to the button icon.
  final String? semanticLabel;

  /// Appearance variant used by the generated button.
  ///
  /// Defaults to [TabsActionButtonVariant.filledTonal].
  final TabsActionButtonVariant variant;

  Widget _build(ButtonStyle style, {required VoidCallback? onPressed}) {
    final buttonIcon = switch (_iconWidget) {
      null => Icon(icon, semanticLabel: semanticLabel),
      final icon =>
        semanticLabel == null
            ? icon
            : Semantics(label: semanticLabel, child: icon),
    };

    return switch (variant) {
      TabsActionButtonVariant.standard => IconButton(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: buttonIcon,
      ),
      TabsActionButtonVariant.filled => IconButton.filled(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: buttonIcon,
      ),
      TabsActionButtonVariant.filledTonal => IconButton.filledTonal(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: buttonIcon,
      ),
      TabsActionButtonVariant.outlined => IconButton.outlined(
        key: key,
        onPressed: onPressed,
        style: style,
        icon: buttonIcon,
      ),
    };
  }
}

/// Displays [children] in accordance with the tab selection.
///
/// Handles styling and animation and exposes control over tab selection through [TabController].
// Tabs is the public configuration surface for one widget; moving constructor
// fields into wrapper types would make the API harder to scan without reducing behavior.
// ignore: coupling-between-object-classes
class Tabs extends StatefulWidget {
  const Tabs({
    required this.tabs,
    super.key,
    this.duration = const Duration(milliseconds: 300),
    this.collapseDuration = const Duration(milliseconds: 220),
    this.curve = Curves.easeInOut,
    this.controller,
    this.children,
    this.child,
    this.childPadding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.tabBorderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.border,
    this.tabExtent = 50.0,
    this.tabEdge = TabEdge.top,
    this.tabsStart = 0.0,
    this.tabsEnd = 1.0,
    this.tabMinLength = 0.0,
    this.tabMaxLength = double.infinity,
    this.tabLeadingButtons = const <TabsActionButton>[],
    this.tabTrailingButtons = const <TabsActionButton>[],
    this.tabButtonGap = 4.0,
    this.collapsed = false,
    this.onCollapsedChanged,
    this.color,
    this.colors,
    this.unselectedTabColor,
    this.unselectedTabGap = 2.0,
    this.transitionBuilder,
    this.semanticsLabel,
    this.semanticsHint,
    this.semanticsValueBuilder,
    this.overrideTextProperties = false,
    this.selectedTextStyle,
    this.unselectedTextStyle,
    this.textDirection,
    this.enabled = true,
    this.enableFeedback = true,
    this.childDuration,
    this.childCurve,
  }) : assert(tabs.length > 0, 'tabs must not be empty.'),
       assert(
         (children == null) != (child == null),
         'Provide exactly one of children or child.',
       ),
       assert(
         !(children != null) || children.length == tabs.length,
         'children and tabs must have the same length.',
       ),
       assert(
         controller == null || controller.length == tabs.length,
         'controller length must match tabs length.',
       ),
       assert(
         !(color != null && colors != null),
         'Provide color or colors, not both.',
       ),
       assert(
         (colors ?? tabs).length == tabs.length,
         'colors must have the same length as tabs.',
       ),
       assert(tabExtent >= 0, 'tabExtent must be non-negative.'),
       assert(
         0.0 <= tabsStart && tabsStart < tabsEnd && tabsEnd <= 1.0,
         'tabsStart and tabsEnd must define an increasing range within 0..1.',
       ),
       assert(tabMinLength >= 0, 'tabMinLength must be non-negative.'),
       assert(tabButtonGap >= 0, 'tabButtonGap must be non-negative.'),
       assert(unselectedTabGap >= 0, 'unselectedTabGap must be non-negative.'),
       assert(
         (tabLeadingButtons.length == 0 && tabTrailingButtons.length == 0) ||
             tabButtonGap * 2 <= tabExtent,
         'tabButtonGap must leave space inside tabExtent.',
       ),
       assert(
         tabMaxLength >= tabMinLength,
         'tabMaxLength must be greater than or equal to tabMinLength.',
       ),
       assert(
         (selectedTextStyle == null) == (unselectedTextStyle == null),
         'Provide both selectedTextStyle and unselectedTextStyle, or neither.',
       );

  /// Changes tab selection from elsewhere in your app.
  ///
  /// If you provide one, you must dispose of it.
  final TabController? controller;

  /// The list of children you want to tab through, in order.
  ///
  /// Must be equal in length to [tabs] and [colors] (if provided).
  /// Must be null if [child] is supplied.
  final List<Widget>? children;

  /// Supply this if you want to control the child view yourself using [TabController].
  ///
  /// Owns the currently displayed content; its tab state is managed by the
  /// supplied [controller].
  /// Must be null if [children] is supplied;
  final Widget? child;

  /// What will be displayed in each tab, in order.
  ///
  /// Must not be empty.
  /// Must be equal in length to [children] and [colors] (if provided).
  final List<Widget> tabs;

  /// Sets the border radius surrounding the children
  ///
  /// Each value refers to its physical on-screen corner, regardless of
  /// [tabEdge].
  ///
  /// Defaults to [BorderRadius.all(Radius.circular(12.0))]
  final BorderRadius borderRadius;

  /// Sets the border radius surrounding each tab
  ///
  /// Each value refers to its physical on-screen corner, regardless of
  /// [tabEdge].
  ///
  /// Defaults to [BorderRadius.all(Radius.circular(12.0))]
  final BorderRadius tabBorderRadius;

  /// Draws an outline around the active tab and its content as one shape.
  ///
  /// Use a uniform border such as [Border.all] so the color and thickness stay
  /// consistent around the custom tab-frame contour. Defaults to null.
  final Border? border;

  /// Sets the padding to be applied around all [children].
  ///
  /// Defaults to [EdgeInsets.zero].
  final EdgeInsets childPadding;

  /// Height of the tabs perpendicular to the [TabEdge].
  ///
  /// For left or right [tabs], this is their visual width; otherwise, it is
  /// their visual height.
  /// Defaults to 50.0.
  final double tabExtent;

  /// Determines which side the [tabs] will be on.
  ///
  /// Defaults to [TabEdge.top].
  final TabEdge tabEdge;

  /// Fraction of the way down the [TabEdge] that the first tab should begin.
  ///
  /// Defaults to 0.0.
  final double tabsStart;

  /// Fraction of the way down the [TabEdge] that the last tab should end.
  ///
  /// Defaults to 1.0.
  final double tabsEnd;

  /// Minimum width of each tab parallel to the [TabEdge].
  ///
  /// Defaults to 0.0
  final double tabMinLength;

  /// Maximum width of each tab parallel to the [TabEdge].
  ///
  /// Defaults to [double.infinity].
  final double tabMaxLength;

  /// Action buttons displayed before the tab labels.
  ///
  /// Each button is built by `Tabs`, constrained to a square [tabExtent] slot,
  /// separated from tab labels by [tabButtonGap], and shaped with
  /// [tabBorderRadius].
  final List<TabsActionButton> tabLeadingButtons;

  /// Action buttons displayed after the tab labels.
  ///
  /// Each button is built by `Tabs`, constrained to a square [tabExtent] slot,
  /// separated from tab labels by [tabButtonGap], and shaped with
  /// [tabBorderRadius].
  final List<TabsActionButton> tabTrailingButtons;

  /// Space between tab-strip buttons and tab labels.
  ///
  /// Defaults to 4.0.
  final double tabButtonGap;

  /// Whether the tab view is collapsed to its tab strip.
  ///
  /// In collapsed mode, `Tabs` keeps only the collapse-toggle action button
  /// visible and preserves the strip dimension needed to anchor leading or
  /// trailing placement.
  ///
  /// When true, exactly one [TabsActionButtonAction.toggleCollapse] button must
  /// be present in [tabLeadingButtons] or [tabTrailingButtons].
  final bool collapsed;

  /// Called when a [TabsActionButtonAction.toggleCollapse] button is pressed.
  ///
  /// If null, the collapse-toggle button is disabled.
  final ValueChanged<bool>? onCollapsedChanged;

  /// The background color of this widget.
  ///
  /// Must not be set if [colors] is provided.
  final Color? color;

  /// The list of colors used for each tab, in order.
  ///
  /// The first color in the list will be the background color when tab 1 is selected and so on.
  /// Must not be set if [color] is provided.
  final List<Color>? colors;

  /// Fills unselected labels as distinct tab surfaces on every tab edge.
  ///
  /// When null, which is the default, tab labels keep their existing joined
  /// appearance. When configured, every tab strip uses this color for every
  /// unselected label. The inner edge that meets the content frame remains
  /// square.
  final Color? unselectedTabColor;

  /// Space between separate unselected-label surfaces.
  ///
  /// Applied only when [unselectedTabColor] is configured. Defaults to 2.0.
  final double unselectedTabGap;

  /// Duration used by [controller] to animate tab changes.
  ///
  /// Defaults to Duration(milliseconds: 300).
  final Duration duration;

  /// Duration used by [Tabs] to animate collapse size changes.
  ///
  /// Defaults to Duration(milliseconds: 220).
  final Duration collapseDuration;

  /// Curve used by [controller] to animate tab changes.
  ///
  /// Defaults to Curves.easeInOut.
  final Curve curve;

  /// Duration of the child transition animation when the tab selection changes.
  ///
  /// Defaults to [duration].
  /// Not used if [child] is supplied.
  final Duration? childDuration;

  /// The curve of the child transition animation when the tab selection changes.
  ///
  /// Defaults to [curve].
  /// Not used if [child] is supplied.
  final Curve? childCurve;

  /// Sets the child transition animation when the tab selection changes.
  ///
  /// Defaults to [AnimatedSwitcher.defaultTransitionBuilder].
  /// Not used if [child] is supplied.
  final Widget Function(Widget, Animation<double>)? transitionBuilder;

  /// Accessibility label for the tab view wrapper.
  ///
  /// Defaults to 'Tab view'.
  final String? semanticsLabel;

  /// Accessibility hint for the tab view wrapper.
  ///
  /// Defaults to 'Increase or decrease to view a different tab'.
  final String? semanticsHint;

  /// Builds wrapper semantic values for current, decreased, and increased tabs.
  ///
  /// Receives the zero-based tab index and the total tab count.
  /// Defaults to 'Viewing tab N of count'.
  final String Function(int index, int count)? semanticsValueBuilder;

  /// Set to true to use each tab widget as supplied, without applying [Tabs]'
  /// implicit text animation and text properties.
  ///
  /// Defaults to false.
  final bool overrideTextProperties;

  /// The [TextStyle] applied to the text of the currently selected tab.
  ///
  /// Must specify values for the same properties as [unselectedTextStyle].
  /// Defaults to Theme.of(context).textTheme.bodyMedium.
  final TextStyle? selectedTextStyle;

  /// The [TextStyle] applied to the text of currently unselected tabs.
  ///
  /// Must specify values for the same properties as [selectedTextStyle].
  /// Defaults to Theme.of(context).textTheme.bodyMedium.
  final TextStyle? unselectedTextStyle;

  /// The [TextDirection] for tabs and semantics.
  ///
  /// Defaults to Directionality.of(context).
  final TextDirection? textDirection;

  /// Whether tab selection changes on tap.
  ///
  /// Defaults to true.
  final bool enabled;

  /// Whether detected gestures on tabs should provide acoustic and/or haptic feedback.
  ///
  /// Defaults to true.
  final bool enableFeedback;

  @override
  State<Tabs> createState() => _TabsState();

  bool _debugAssertCollapseToggleConfiguration() {
    final collapseActionCount = _collapseToggleActionCount(
      tabLeadingButtons,
      tabTrailingButtons,
    );

    if (collapseActionCount > 1) {
      throw FlutterError('Provide at most one collapse toggle action button.');
    }

    if (collapsed && collapseActionCount != 1) {
      throw FlutterError(
        'A collapsed Tabs must have exactly one collapse toggle action button.',
      );
    }

    return true;
  }

  bool _debugAssertBorderConfiguration() {
    final configuredBorder = border;
    if (configuredBorder != null && !configuredBorder.isUniform) {
      throw FlutterError('border must use the same BorderSide on every edge.');
    }

    return true;
  }

  @override
  // Diagnostics mirror the public constructor so callers can inspect every
  // configured option from one debug node.
  // ignore: halstead-volume, source-lines-of-code, maintainability-index
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<TabController?>('controller', controller),
    );
    properties.add(
      DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius),
    );
    properties.add(
      DiagnosticsProperty<BorderRadius>('tabBorderRadius', tabBorderRadius),
    );
    properties.add(DiagnosticsProperty<Border?>('border', border));
    properties.add(
      DiagnosticsProperty<EdgeInsets>('childPadding', childPadding),
    );
    properties.add(DoubleProperty('tabExtent', tabExtent));
    properties.add(EnumProperty<TabEdge>('tabEdge', tabEdge));
    properties.add(DoubleProperty('tabsStart', tabsStart));
    properties.add(DoubleProperty('tabsEnd', tabsEnd));
    properties.add(DoubleProperty('tabMinLength', tabMinLength));
    properties.add(DoubleProperty('tabMaxLength', tabMaxLength));
    properties.add(
      IterableProperty<TabsActionButton>(
        'tabLeadingButtons',
        tabLeadingButtons,
      ),
    );
    properties.add(
      IterableProperty<TabsActionButton>(
        'tabTrailingButtons',
        tabTrailingButtons,
      ),
    );
    properties.add(DoubleProperty('tabButtonGap', tabButtonGap));
    properties.add(DiagnosticsProperty<bool>('collapsed', collapsed));
    properties.add(
      ObjectFlagProperty<ValueChanged<bool>?>.has(
        'onCollapsedChanged',
        onCollapsedChanged,
      ),
    );
    properties.add(ColorProperty('color', color));
    properties.add(IterableProperty<Color>('colors', colors));
    properties.add(ColorProperty('unselectedTabColor', unselectedTabColor));
    properties.add(DoubleProperty('unselectedTabGap', unselectedTabGap));
    properties.add(DiagnosticsProperty<Duration>('duration', duration));
    properties.add(
      DiagnosticsProperty<Duration>('collapseDuration', collapseDuration),
    );
    properties.add(DiagnosticsProperty<Curve>('curve', curve));
    properties.add(
      DiagnosticsProperty<Duration?>('childDuration', childDuration),
    );
    properties.add(DiagnosticsProperty<Curve?>('childCurve', childCurve));
    properties.add(
      ObjectFlagProperty<Widget Function(Widget, Animation<double>)?>.has(
        'transitionBuilder',
        transitionBuilder,
      ),
    );
    properties.add(StringProperty('semanticsLabel', semanticsLabel));
    properties.add(StringProperty('semanticsHint', semanticsHint));
    properties.add(
      ObjectFlagProperty<String Function(int index, int count)?>.has(
        'semanticsValueBuilder',
        semanticsValueBuilder,
      ),
    );
    properties.add(
      DiagnosticsProperty<bool>(
        'overrideTextProperties',
        overrideTextProperties,
      ),
    );
    properties.add(
      DiagnosticsProperty<TextStyle?>('selectedTextStyle', selectedTextStyle),
    );
    properties.add(
      DiagnosticsProperty<TextStyle?>(
        'unselectedTextStyle',
        unselectedTextStyle,
      ),
    );
    properties.add(
      EnumProperty<TextDirection?>('textDirection', textDirection),
    );
    properties.add(DiagnosticsProperty<bool>('enabled', enabled));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback));
  }
}

// _TabsState coordinates controller lifecycle, child composition, and tab label
// ownership; splitting it would duplicate transient controller/listener state.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
class _TabsState extends State<Tabs> with TickerProviderStateMixin {
  late TabController _controller;
  TabController? _defaultController;
  late Widget _child;
  List<Widget> _tabs = <Widget>[];
  List<Widget> _tabLeadingButtons = <Widget>[];
  List<Widget> _tabTrailingButtons = <Widget>[];
  int? _collapseToggleActionIndex;
  late AnimationController _collapseController;

  late TextStyle _selectedTextStyle;
  late TextStyle _unselectedTextStyle;
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    final widgetController = widget.controller;
    if (widgetController == null) {
      final defaultController = TabController(
        vsync: this,
        animationDuration: widget.duration,
        length: widget.tabs.length,
      );
      _defaultController = defaultController;
      _controller = defaultController;
    } else {
      _controller = widgetController;
    }

    _controller.addListener(_tabListener);
    _collapseController = AnimationController(
      vsync: this,
      value: widget.collapsed ? 1.0 : 0.0,
    );

    _buildChild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveTextConfiguration();
    _remountController();
    _buildChild();
    _buildTabs();
  }

  @override
  void didUpdateWidget(covariant Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.tabs.length != oldWidget.tabs.length ||
        widget.duration != oldWidget.duration) {
      _remountController();
    }
    if (widget.collapsed != oldWidget.collapsed) {
      _animateCollapse();
    }
    _resolveTextConfiguration();
    _buildChild();
    _buildTabs();
  }

  @override
  void dispose() {
    _controller.removeListener(_tabListener);
    _defaultController?.dispose();
    _collapseController.dispose();

    super.dispose();
  }

  Animation<double> get _controllerAnimation {
    final animation = _controller.animation;
    if (animation == null) {
      throw StateError('TabController animation is not available.');
    }
    return animation;
  }

  void _resolveTextConfiguration() {
    _selectedTextStyle =
        widget.selectedTextStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    _unselectedTextStyle =
        widget.unselectedTextStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    _textDirection = widget.textDirection ?? Directionality.of(context);
  }

  void _tabListener() {
    setState(_buildChild);
  }

  void _animateCollapse() {
    final target = widget.collapsed ? 1.0 : 0.0;
    if (widget.collapseDuration == Duration.zero) {
      _collapseController.value = target;
      return;
    }

    _collapseController.animateTo(
      target,
      duration: widget.collapseDuration,
      curve: widget.curve,
    );
  }

  int _clampControllerIndex(int index) {
    final lastIndex = widget.tabs.length - 1;
    if (lastIndex < 0) {
      return 0;
    }

    return index.clamp(0, lastIndex);
  }

  void _remountController() {
    final widgetController = widget.controller;
    if (widgetController != null) {
      if (widgetController == _controller) {
        return;
      }
    } else {
      final defaultController = _defaultController;
      if (defaultController == _controller &&
          defaultController != null &&
          defaultController.length == widget.tabs.length &&
          defaultController.animationDuration == widget.duration) {
        return;
      }
    }

    final previousController = _controller;
    final previousIndex = previousController.index;

    previousController.removeListener(_tabListener);
    _defaultController?.dispose();
    _defaultController = null;

    if (widgetController != null) {
      _controller = widgetController;
    } else {
      final defaultController = TabController(
        vsync: this,
        animationDuration: widget.duration,
        initialIndex: _clampControllerIndex(previousIndex),
        length: widget.tabs.length,
      );
      _defaultController = defaultController;
      _controller = defaultController;
    }

    _controller.addListener(_tabListener);
  }

  Widget _getTab(int index) {
    final tab = widget.tabs[index];

    if (widget.overrideTextProperties) {
      return tab;
    }

    return Directionality(
      textDirection: _textDirection,
      child: _AnimatedTabLabel(
        controller: _controller,
        progressAnimation: _controllerAnimation,
        index: index,
        selectedTextStyle: _selectedTextStyle,
        unselectedTextStyle: _unselectedTextStyle,
        child: tab,
      ),
    );
  }

  void _buildTabs() {
    final tabs = <Widget>[];

    for (var index = 0; index < widget.tabs.length; index++) {
      tabs.add(_getAccessibleTab(index));
    }

    _tabs = tabs;
    _tabLeadingButtons = _buildTabButtons(widget.tabLeadingButtons);
    _tabTrailingButtons = _buildTabButtons(widget.tabTrailingButtons);
    _collapseToggleActionIndex = _findCollapseToggleActionIndex();
  }

  List<Widget> _buildTabButtons(List<TabsActionButton> buttons) {
    return <Widget>[
      for (final button in buttons)
        _TabButtonSlot(
          borderRadius: widget.tabBorderRadius,
          button: button,
          onPressed: _resolveActionButtonPress(button),
        ),
    ];
  }

  int? _findCollapseToggleActionIndex() {
    var actionIndex = 0;

    for (final button in widget.tabLeadingButtons) {
      if (_isCollapseToggleAction(button)) {
        return actionIndex;
      }
      actionIndex++;
    }

    for (final button in widget.tabTrailingButtons) {
      if (_isCollapseToggleAction(button)) {
        return actionIndex;
      }
      actionIndex++;
    }

    return null;
  }

  VoidCallback? _resolveActionButtonPress(TabsActionButton button) {
    switch (button.action) {
      case TabsActionButtonAction.custom:
        return button.onPressed;
      case TabsActionButtonAction.toggleCollapse:
        final onCollapsedChanged = widget.onCollapsedChanged;
        if (onCollapsedChanged == null) {
          return null;
        }

        return () {
          onCollapsedChanged(!widget.collapsed);
        };
    }
  }

  Widget _getAccessibleTab(int index) {
    return ExcludeSemantics(
      excluding: widget.collapsed,
      child: _TabSemantics(
        controller: _controller,
        progressAnimation: _controllerAnimation,
        index: index,
        enabled: widget.enabled,
        duration: widget.duration,
        curve: widget.curve,
        enableFeedback: widget.enableFeedback,
        child: _getTab(index),
      ),
    );
  }

  void _buildChild() {
    final configuredChild = widget.child;
    if (configuredChild != null) {
      _child = configuredChild;
      return;
    }

    final children = widget.children;
    if (children == null) {
      throw StateError('Tabs children must be provided when child is null.');
    }

    _child = Padding(
      padding: widget.childPadding,
      child: AnimatedSwitcher(
        duration: widget.childDuration ?? widget.duration,
        reverseDuration: widget.childDuration ?? widget.duration,
        switchInCurve: widget.childCurve ?? widget.curve,
        switchOutCurve: widget.childCurve ?? widget.curve,
        layoutBuilder: _buildChildTransitionLayout,
        transitionBuilder:
            widget.transitionBuilder ??
            AnimatedSwitcher.defaultTransitionBuilder,
        child: KeyedSubtree(
          key: ValueKey<int>(_controller.index),
          child: children[_controller.index],
        ),
      ),
    );
  }

  Widget _buildChildTransitionLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    final currentKey = currentChild?.key;
    final transitionChildren = <Widget>[
      for (final previousChild in previousChildren)
        if (previousChild.key != currentKey) previousChild,
      ?currentChild,
    ];

    return Stack(alignment: Alignment.center, children: transitionChildren);
  }

  @override
  // Keep the widget-to-render handoff in one place so every public Tabs input
  // remains auditable against the TabFrame constructor.
  // ignore: halstead-volume, source-lines-of-code
  Widget build(BuildContext context) {
    assert(
      widget._debugAssertCollapseToggleConfiguration(),
      'Tabs collapse action configuration must be valid.',
    );
    assert(
      widget._debugAssertBorderConfiguration(),
      'Tabs border configuration must be valid.',
    );

    return TabFrame(
      controller: _controller,
      progressAnimation: _controllerAnimation,
      collapseProgressAnimation: _collapseController.view,
      curve: widget.curve,
      duration: widget.duration,
      tabs: _tabs,
      tabLeadingButtons: _tabLeadingButtons,
      tabTrailingButtons: _tabTrailingButtons,
      tabButtonGap: widget.tabButtonGap,
      collapsed: widget.collapsed,
      collapsedActionIndex: _collapseToggleActionIndex,
      borderRadius: widget.borderRadius,
      tabBorderRadius: widget.tabBorderRadius,
      border: widget.border,
      tabExtent: widget.tabExtent,
      tabEdge: widget.tabEdge,
      tabAxis:
          (widget.tabEdge == TabEdge.left || widget.tabEdge == TabEdge.right)
          ? Axis.vertical
          : Axis.horizontal,
      tabStripStart: widget.tabsStart,
      tabStripEnd: widget.tabsEnd,
      tabMinLength: widget.tabMinLength,
      tabMaxLength: widget.tabMaxLength,
      color: widget.color,
      colors: widget.colors,
      unselectedTabColor: widget.unselectedTabColor,
      unselectedTabGap: widget.unselectedTabGap,
      semanticsLabel: widget.semanticsLabel,
      semanticsHint: widget.semanticsHint,
      semanticsValueBuilder: widget.semanticsValueBuilder,
      enabled: widget.enabled,
      enableFeedback: widget.enableFeedback,
      textDirection: _textDirection,
      child: ExcludeSemantics(excluding: widget.collapsed, child: _child),
    );
  }
}

class _TabSemantics extends StatelessWidget {
  const _TabSemantics({
    required TabController controller,
    required Animation<double> progressAnimation,
    required int index,
    required bool enabled,
    required Duration duration,
    required Curve curve,
    required bool enableFeedback,
    required Widget child,
  }) : _controller = controller,
       _progressAnimation = progressAnimation,
       _index = index,
       _enabled = enabled,
       _duration = duration,
       _curve = curve,
       _enableFeedback = enableFeedback,
       _child = child;

  final TabController _controller;
  final Animation<double> _progressAnimation;
  final int _index;
  final bool _enabled;
  final Duration _duration;
  final Curve _curve;
  final bool _enableFeedback;
  final Widget _child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      child: _child,
      builder: (context, child) {
        return Semantics(
          container: true,
          button: true,
          selected: _controller.index == _index,
          enabled: _enabled,
          onTap: _enabled
              ? () {
                  _controller.animateTo(
                    _index,
                    duration: _duration,
                    curve: _curve,
                  );
                  if (_enableFeedback) {
                    unawaited(Feedback.forTap(context));
                  }
                }
              : null,
          child: child,
        );
      },
    );
  }
}

// Button slots own generated-button geometry so buttons align with tab labels
// without caller-side shape wiring.
// ignore: coupling-between-object-classes
class _TabButtonSlot extends StatelessWidget {
  const _TabButtonSlot({
    required this.borderRadius,
    required this.button,
    required this.onPressed,
  });

  final BorderRadius borderRadius;
  final TabsActionButton button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonBorderRadius = _buttonBorderRadius(borderRadius);

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonSize = Size(constraints.maxWidth, constraints.maxHeight);
          final buttonStyle = IconButton.styleFrom(
            fixedSize: buttonSize,
            maximumSize: buttonSize,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: buttonBorderRadius),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );

          return ClipRRect(
            borderRadius: buttonBorderRadius,
            child: button._build(buttonStyle, onPressed: onPressed),
          );
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius),
    );
    properties.add(DiagnosticsProperty<TabsActionButton>('button', button));
    properties.add(
      ObjectFlagProperty<VoidCallback?>.has('onPressed', onPressed),
    );
  }

  BorderRadius _buttonBorderRadius(BorderRadius tabBorderRadius) {
    Radius reduce(Radius radius) {
      return Radius.elliptical(
        (radius.x - 4.0).clamp(0.0, double.infinity),
        (radius.y - 4.0).clamp(0.0, double.infinity),
      );
    }

    return BorderRadius.only(
      topLeft: reduce(tabBorderRadius.topLeft),
      topRight: reduce(tabBorderRadius.topRight),
      bottomLeft: reduce(tabBorderRadius.bottomLeft),
      bottomRight: reduce(tabBorderRadius.bottomRight),
    );
  }
}

// The label widget receives the complete text-animation context so each label
// can rebuild independently without a package-wide animation tick rebuild.
// ignore: coupling-between-object-classes
class _AnimatedTabLabel extends StatelessWidget {
  const _AnimatedTabLabel({
    required TabController controller,
    required Animation<double> progressAnimation,
    required int index,
    required TextStyle selectedTextStyle,
    required TextStyle unselectedTextStyle,
    required Widget child,
  }) : _controller = controller,
       _progressAnimation = progressAnimation,
       _index = index,
       _selectedTextStyle = selectedTextStyle,
       _unselectedTextStyle = unselectedTextStyle,
       _child = child;

  final TabController _controller;
  final Animation<double> _progressAnimation;
  final int _index;
  final TextStyle _selectedTextStyle;
  final TextStyle _unselectedTextStyle;
  final Widget _child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      child: _child,
      builder: (context, child) {
        final textScale = _calculateTextScale();

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(textScale, textScale, textScale, 1),
          child: Container(
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              overflow: TextOverflow.fade,
              style: _calculateTextStyle(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  double _currentFraction() {
    return _animationFraction(
      _progressAnimation.value,
      _controller.previousIndex,
      _controller.index,
    ).clamp(0.0, 1.0);
  }

  TextStyle _calculateTextStyle() {
    final styleTween = TextStyleTween(
      begin: _unselectedTextStyle,
      end: _selectedTextStyle,
    );
    final animationFraction = _currentFraction();

    if (_index == _controller.index) {
      return styleTween
          .lerp(animationFraction)
          .copyWith(fontSize: _unselectedTextStyle.fontSize);
    } else if (_index == _controller.previousIndex) {
      return styleTween
          .lerp(1 - animationFraction)
          .copyWith(fontSize: _unselectedTextStyle.fontSize);
    } else {
      return _unselectedTextStyle;
    }
  }

  double _calculateTextScale() {
    final selectedFontSize = _selectedTextStyle.fontSize;
    final unselectedFontSize = _unselectedTextStyle.fontSize;
    if (selectedFontSize == null || unselectedFontSize == null) {
      return 1.0;
    }

    final animationFraction = _currentFraction();
    final textRatio = selectedFontSize / unselectedFontSize;

    if (_index == _controller.index) {
      return lerpDouble(1, textRatio, animationFraction) ?? 1.0;
    } else if (_index == _controller.previousIndex) {
      return lerpDouble(textRatio, 1, animationFraction) ?? 1.0;
    } else {
      return 1.0;
    }
  }

  double _animationFraction(double current, int previous, int next) {
    if (next - previous == 0) {
      return 1;
    }
    return (current - previous) / (next - previous);
  }
}
