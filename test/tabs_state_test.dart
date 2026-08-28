import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/src/render/tabs_frame.dart';
import 'package:tabs/tabs.dart';

import 'src/tabs_test_support.dart';

class _CollapseFootprintCase {
  const _CollapseFootprintCase({
    required this.tabEdge,
    required this.constraints,
    required this.expandedSize,
    required this.midpointSize,
    required this.collapsedSize,
    required this.blockedContentTapOffset,
  });

  final TabEdge tabEdge;
  final BoxConstraints constraints;
  final Size expandedSize;
  final Size midpointSize;
  final Size collapsedSize;
  final Offset blockedContentTapOffset;
}

// Keep the edge matrix in one setup so top, bottom, left, and right prove the
// same collapse-animation contract.
// ignore: halstead-volume, source-lines-of-code, maximum-nesting-level, maintainability-index
Future<bool> _verifyCollapseFootprint(
  WidgetTester tester,
  _CollapseFootprintCase testCase,
) async {
  const tabsKey = ValueKey('tabs');
  const collapseKey = ValueKey('collapse-button');
  const contentKey = ValueKey('content');
  final boundaryKey = GlobalKey();
  const contentColor = Color(0xff00ff00);
  var collapsed = false;
  var contentTaps = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: boundaryKey,
        child: StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: testCase.constraints,
                child: Tabs(
                  key: tabsKey,
                  duration: const Duration(milliseconds: 100),
                  collapseDuration: const Duration(seconds: 1),
                  curve: Curves.linear,
                  collapsed: collapsed,
                  onCollapsedChanged: (value) {
                    setState(() {
                      collapsed = value;
                    });
                  },
                  tabEdge: testCase.tabEdge,
                  tabTrailingButtons: const [
                    TabsActionButton(
                      key: collapseKey,
                      action: TabsActionButtonAction.toggleCollapse,
                      icon: Icons.unfold_less,
                    ),
                  ],
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  color: const Color(0xff0000ff),
                  enableFeedback: false,
                  tabs: const [Text('Tab one')],
                  child: GestureDetector(
                    key: contentKey,
                    onTap: () {
                      contentTaps++;
                    },
                    child: const ColoredBox(
                      color: contentColor,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  expect(tester.getSize(find.byKey(tabsKey)), testCase.expandedSize);
  expect(
    await readBoundaryPixel(
      tester: tester,
      boundary: find.byKey(boundaryKey),
      position: testCase.blockedContentTapOffset,
    ),
    contentColor,
  );

  await tester.tap(find.byKey(collapseKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  expect(tester.getSize(find.byKey(tabsKey)), testCase.midpointSize);
  final renderFrame = tester.renderObject<RenderTabFrame>(
    find.byType(TabFrame),
  );
  expect(renderFrame.alwaysNeedsCompositing, isTrue);
  final midpointPixel = await readBoundaryPixel(
    tester: tester,
    boundary: find.byKey(boundaryKey),
    position: testCase.blockedContentTapOffset,
  );
  expect(
    (midpointPixel.toARGB32() >> 24) & 0xff,
    allOf(greaterThan(0), lessThan(255)),
  );
  expect(midpointPixel, isNot(contentColor));
  await tester.tapAt(
    tester.getTopLeft(find.byKey(tabsKey)) + testCase.blockedContentTapOffset,
  );
  await tester.pump();
  expect(contentTaps, 0);

  await tester.pump(const Duration(milliseconds: 500));

  expect(tester.getSize(find.byKey(tabsKey)), testCase.collapsedSize);
  expect(renderFrame.alwaysNeedsCompositing, isFalse);

  await tester.tap(find.byKey(collapseKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  expect(tester.getSize(find.byKey(tabsKey)), testCase.midpointSize);

  await tester.pump(const Duration(milliseconds: 500));

  expect(tester.getSize(find.byKey(tabsKey)), testCase.expandedSize);
  return true;
}

// State coverage keeps controller lifecycle and child composition scenarios
// together because they share transient TabController and AnimatedSwitcher state.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets('clamps default controller selection when tabs shrink', (
    tester,
  ) async {
    Widget buildTabs({
      required List<Widget> tabs,
      required List<Widget> children,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              tabs: tabs,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              children: children,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildTabs(
        tabs: const [Text('One'), Text('Two'), Text('Three')],
        children: const [
          Text('Content one'),
          Text('Content two'),
          Text('Content three'),
        ],
      ),
    );

    await tester.tap(find.text('Three'));
    await tester.pumpAndSettle();

    expect(find.text('Content three'), findsOneWidget);

    await tester.pumpWidget(
      buildTabs(
        tabs: const [Text('One'), Text('Two')],
        children: const [Text('Content one'), Text('Content two')],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Content two'), findsOneWidget);
  });

  testWidgets('default controller can select tabs added by rebuild', (
    tester,
  ) async {
    Widget buildTabs({
      required List<Widget> tabs,
      required List<Widget> children,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              tabs: tabs,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              children: children,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildTabs(
        tabs: const [Text('One'), Text('Two')],
        children: const [Text('Content one'), Text('Content two')],
      ),
    );

    await tester.pumpWidget(
      buildTabs(
        tabs: const [Text('One'), Text('Two'), Text('Three')],
        children: const [
          Text('Content one'),
          Text('Content two'),
          Text('Content three'),
        ],
      ),
    );

    await tester.tap(find.text('Three'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Content three'), findsOneWidget);
  });

  testWidgets(
    'children mode switches only active keyed content during transition',
    (tester) async {
      final contentKeys = [
        GlobalKey(debugLabel: 'content-one'),
        GlobalKey(debugLabel: 'content-two'),
        GlobalKey(debugLabel: 'content-three'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: Tabs(
                duration: const Duration(seconds: 1),
                curve: Curves.linear,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                tabs: const [
                  Text('Tab one'),
                  Text('Tab two'),
                  Text('Tab three'),
                ],
                children: [
                  Center(key: contentKeys[0], child: const Text('Content one')),
                  Center(key: contentKeys[1], child: const Text('Content two')),
                  Center(
                    key: contentKeys[2],
                    child: const Text('Content three'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(contentKeys[0]), findsOneWidget);
      expect(find.byKey(contentKeys[1]), findsNothing);
      expect(find.byKey(contentKeys[2]), findsNothing);

      await tester.tap(find.text('Tab two'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(contentKeys[0]), findsOneWidget);
      expect(find.byKey(contentKeys[1]), findsOneWidget);
      expect(find.byKey(contentKeys[2]), findsNothing);
      expect(find.text('Content two'), findsOneWidget);

      await tester.tap(find.text('Tab one'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(contentKeys[0]), findsOneWidget);
      expect(
        find.byKey(contentKeys[1]).evaluate().length,
        lessThanOrEqualTo(1),
      );
      expect(
        find.byKey(contentKeys[2]).evaluate().length,
        lessThanOrEqualTo(1),
      );
      expect(find.text('Content one'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byKey(contentKeys[0]), findsOneWidget);
      expect(find.byKey(contentKeys[1]), findsNothing);
      expect(find.byKey(contentKeys[2]), findsNothing);
      expect(find.text('Content one'), findsOneWidget);
    },
  );

  testWidgets('children mode keeps child padding around active content', (
    tester,
  ) async {
    const tabsKey = ValueKey('tabs');
    const contentKey = ValueKey('active-content');

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              key: tabsKey,
              childPadding: const EdgeInsets.fromLTRB(12, 14, 16, 18),
              tabExtent: 40,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              tabs: const [Text('Tab one')],
              children: const [
                SizedBox(key: contentKey, width: 20, height: 20),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(tabsKey), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(contentKey),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.fromLTRB(12, 14, 16, 18),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('children mode uses duration and curve for switch timing', (
    tester,
  ) async {
    final childAnimations = <Key?, Animation<double>>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              duration: const Duration(seconds: 1),
              curve: Curves.easeIn,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              transitionBuilder: (child, animation) {
                childAnimations[child.key] = animation;
                return FadeTransition(opacity: animation, child: child);
              },
              tabs: const [Text('Tab one'), Text('Tab two')],
              children: const [Text('Content one'), Text('Content two')],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tab two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      childAnimations[const ValueKey<int>(1)]?.value,
      moreOrLessEquals(Curves.easeIn.transform(0.5)),
    );
    expect(
      childAnimations[const ValueKey<int>(0)]?.value,
      moreOrLessEquals(Curves.easeIn.transform(0.5)),
    );
  });

  testWidgets('children mode childDuration and childCurve override timing', (
    tester,
  ) async {
    final childAnimations = <Key?, Animation<double>>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              duration: const Duration(seconds: 2),
              curve: Curves.linear,
              childDuration: const Duration(seconds: 1),
              childCurve: Curves.easeIn,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              transitionBuilder: (child, animation) {
                childAnimations[child.key] = animation;
                return FadeTransition(opacity: animation, child: child);
              },
              tabs: const [Text('Tab one'), Text('Tab two')],
              children: const [Text('Content one'), Text('Content two')],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tab two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      childAnimations[const ValueKey<int>(1)]?.value,
      moreOrLessEquals(Curves.easeIn.transform(0.5)),
    );
    expect(
      childAnimations[const ValueKey<int>(0)]?.value,
      moreOrLessEquals(Curves.easeIn.transform(0.5)),
    );
  });

  testWidgets('children mode invokes custom transition for active child', (
    tester,
  ) async {
    final transitionChildKeys = <Key?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              transitionBuilder: (child, animation) {
                transitionChildKeys.add(child.key);
                return FadeTransition(opacity: animation, child: child);
              },
              tabs: const [Text('Tab one'), Text('Tab two')],
              children: const [Text('Content one'), Text('Content two')],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tab two'));
    await tester.pump();

    expect(transitionChildKeys, contains(const ValueKey<int>(0)));
    expect(transitionChildKeys, contains(const ValueKey<int>(1)));
    expect(find.text('Content two'), findsOneWidget);
  });

  testWidgets('rebuild with swapped controller reads active tab color', (
    tester,
  ) async {
    final firstController = TabController(length: 3, vsync: tester);
    final secondController = TabController(
      length: 3,
      initialIndex: 2,
      vsync: tester,
    );
    final boundaryKey = GlobalKey();

    Widget buildTabs(TabController controller) {
      return MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: Colors.white,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                height: 160,
                child: Tabs(
                  controller: controller,
                  colors: const [
                    Color(0xffb71c1c),
                    Color(0xff1b5e20),
                    Color(0xff0d47a1),
                  ],
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  tabs: const [Text('One'), Text('Two'), Text('Three')],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    try {
      await tester.pumpWidget(buildTabs(firstController));

      expect(
        await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
        const Color(0xffb71c1c),
      );

      await tester.pumpWidget(buildTabs(secondController));

      expect(
        await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
        const Color(0xff0d47a1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      firstController.dispose();
      secondController.dispose();
    }
  });

  testWidgets('swapped old controller ticks do not mutate active animation', (
    tester,
  ) async {
    final oldController = TabController(length: 2, vsync: tester);
    final newController = TabController(length: 2, vsync: tester);
    final boundaryKey = GlobalKey();

    Widget buildTabs({
      required TabController controller,
      required String prefix,
      required List<Color> colors,
    }) {
      return MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: Colors.white,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                height: 160,
                child: Tabs(
                  controller: controller,
                  duration: const Duration(seconds: 1),
                  curve: Curves.linear,
                  colors: colors,
                  selectedTextStyle: const TextStyle(color: Color(0xff00ff00)),
                  unselectedTextStyle: const TextStyle(
                    color: Color(0xff000000),
                  ),
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  tabs: [Text('$prefix label one'), Text('$prefix label two')],
                  children: [
                    Text('$prefix content one'),
                    Text('$prefix content two'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<Color> backgroundColor() {
      return readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey);
    }

    TextStyle? textStyle(String text) =>
        tester.renderObject<RenderParagraph>(find.text(text)).text.style;

    try {
      await tester.pumpWidget(
        buildTabs(
          controller: oldController,
          prefix: 'Old',
          colors: const [Color(0xffff0000), Color(0xff0000ff)],
        ),
      );

      await tester.pumpWidget(
        buildTabs(
          controller: newController,
          prefix: 'New',
          colors: const [Color(0xff00ff00), Color(0xffff0000)],
        ),
      );

      final stableBackground = await backgroundColor();
      final stableStyle = textStyle('New label one')?.color;

      oldController.animateTo(1, duration: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('New content one'), findsOneWidget);
      expect(await backgroundColor(), stableBackground);
      expect(textStyle('New label one')?.color, stableStyle);

      newController.animateTo(1, duration: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      final activeMidBackground = await backgroundColor();
      expect(redOf(activeMidBackground), greaterThan(0));
      expect(greenOf(activeMidBackground), lessThan(0xff));
      final activeLabelColor = textStyle('New label two')?.color;
      expect(activeLabelColor, isNotNull);
      final activeColor = activeLabelColor ?? Colors.transparent;
      expect(greenOf(activeColor), greaterThan(0));
      expect(greenOf(activeColor), lessThan(0xff));
      expect(find.text('New content two'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      oldController.dispose();
      newController.dispose();
    }
  });

  testWidgets('removed tabs ignore later controller animation ticks', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 240,
            height: 160,
            child: Tabs(
              controller: controller,
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              colors: const [Color(0xffff0000), Color(0xff0000ff)],
              tabs: const [
                Text('Removed label one'),
                Text('Removed label two'),
              ],
              children: const [
                Text('Removed content one'),
                Text('Removed content two'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      controller.animateTo(1, duration: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Removed content two'), findsNothing);
      expect(find.byType(TabFrame), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('default controller uses updated duration after rebuild', (
    tester,
  ) async {
    Widget buildTabs(Duration duration) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 120,
            child: Tabs(
              duration: duration,
              curve: Curves.linear,
              tabs: const [Text('One'), Text('Two')],
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTabs(const Duration(milliseconds: 100)));
    await tester.pumpWidget(buildTabs(const Duration(seconds: 1)));

    final frameFinder = find.byType(TabFrame);

    await tester.tap(find.text('Two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final renderFrame = tester.renderObject<RenderTabFrame>(frameFinder);
    expect(renderFrame.controller.animation?.value, moreOrLessEquals(0.5));

    await tester.pump(const Duration(milliseconds: 500));

    expect(renderFrame.controller.index, 1);
    expect(renderFrame.controller.animation?.value, 1);
  });

  testWidgets('collapsed tabs animate their footprint', (tester) async {
    const horizontalConstraints = BoxConstraints(
      minWidth: 300,
      maxWidth: 300,
      maxHeight: 160,
    );
    const verticalConstraints = BoxConstraints(
      maxWidth: 300,
      minHeight: 160,
      maxHeight: 160,
    );

    expect(
      await _verifyCollapseFootprint(
        tester,
        const _CollapseFootprintCase(
          tabEdge: TabEdge.top,
          constraints: horizontalConstraints,
          expandedSize: Size(300, 160),
          midpointSize: Size(300, 107),
          collapsedSize: Size(300, 54),
          blockedContentTapOffset: Offset(150, 80),
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      await _verifyCollapseFootprint(
        tester,
        const _CollapseFootprintCase(
          tabEdge: TabEdge.bottom,
          constraints: horizontalConstraints,
          expandedSize: Size(300, 160),
          midpointSize: Size(300, 107),
          collapsedSize: Size(300, 54),
          blockedContentTapOffset: Offset(150, 25),
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      await _verifyCollapseFootprint(
        tester,
        const _CollapseFootprintCase(
          tabEdge: TabEdge.left,
          constraints: verticalConstraints,
          expandedSize: Size(300, 160),
          midpointSize: Size(177, 160),
          collapsedSize: Size(54, 160),
          blockedContentTapOffset: Offset(80, 80),
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      await _verifyCollapseFootprint(
        tester,
        const _CollapseFootprintCase(
          tabEdge: TabEdge.right,
          constraints: verticalConstraints,
          expandedSize: Size(300, 160),
          midpointSize: Size(177, 160),
          collapsedSize: Size(54, 160),
          blockedContentTapOffset: Offset(25, 80),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('collapsed tabs keep active child state mounted', (tester) async {
    const collapseKey = ValueKey('collapse-button');
    const contentKey = ValueKey('stateful-content');
    var collapsed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: collapsed ? 50 : 160,
                child: Tabs(
                  collapsed: collapsed,
                  onCollapsedChanged: (value) {
                    setState(() {
                      collapsed = value;
                    });
                  },
                  tabTrailingButtons: const [
                    TabsActionButton(
                      key: collapseKey,
                      action: TabsActionButtonAction.toggleCollapse,
                      icon: Icons.unfold_less,
                    ),
                  ],
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  tabs: const [Text('Tab one')],
                  children: const [
                    _StatefulCounterContent(contentKey: contentKey),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(contentKey));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);

    await tester.tap(find.byKey(collapseKey));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(contentKey)), Size.zero);

    await tester.tap(find.byKey(collapseKey));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(tester.getSize(find.byKey(contentKey)).isEmpty, isFalse);
  });
}

class _StatefulCounterContent extends StatefulWidget {
  const _StatefulCounterContent({required this.contentKey});

  final Key contentKey;

  @override
  State<_StatefulCounterContent> createState() =>
      _StatefulCounterContentState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Key>('contentKey', contentKey));
  }
}

class _StatefulCounterContentState extends State<_StatefulCounterContent> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.contentKey,
      onTap: _increment,
      child: SizedBox(
        width: 120,
        height: 40,
        child: Center(child: Text('Count $_count')),
      ),
    );
  }

  void _increment() {
    setState(() {
      _count++;
    });
  }
}
