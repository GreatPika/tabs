import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/src/render/tabs_frame.dart';
import 'package:tabs/tabs.dart';

import 'src/tabs_test_support.dart';

// Render-input coverage keeps gestures, pointer scroll, feedback, disabled
// behavior, and edge hit regions together around one RenderTabFrame input owner.
// ignore: cyclomatic-complexity, halstead-volume, maximum-nesting-level, source-lines-of-code, maintainability-index
void main() {
  testWidgets('preserves a content hit when a later tab child misses', (
    tester,
  ) async {
    var contentTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 80,
          child: Tabs(
            tabs: const [SizedBox.expand()],
            tabExtent: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                contentTapCount++;
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(Tabs)) + const Offset(50, 50),
    );
    await tester.pump();

    expect(contentTapCount, 1);
  });

  testWidgets('collapsed strip only hits the visible action button', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    const collapseKey = ValueKey('collapse-action');
    var collapsed = true;
    var backgroundTaps = 0;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        backgroundTaps++;
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 300,
                      height: collapsed ? 50 : 160,
                      child: Tabs(
                        controller: controller,
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
                            icon: Icons.unfold_more,
                          ),
                        ],
                        borderRadius: BorderRadius.zero,
                        tabBorderRadius: BorderRadius.zero,
                        enableFeedback: false,
                        tabs: const [Text('One'), Text('Two')],
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tapAt(
        tester.getTopLeft(find.byType(Tabs)) + const Offset(150, 25),
      );
      await tester.pump();
      expect(backgroundTaps, 1);
      expect(controller.index, 0);

      await tester.tap(find.byKey(collapseKey));
      await tester.pumpAndSettle();
      expect(collapsed, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('keeps recognizers usable after removing and reinserting Tabs', (
    tester,
  ) async {
    final controller = TabController(length: 3, vsync: tester);

    Widget buildTabs({required bool visible}) {
      return MaterialApp(
        home: SizedBox(
          width: 240,
          height: 160,
          child: visible
              ? Tabs(
                  controller: controller,
                  tabs: const [Text('One'), Text('Two'), Text('Three')],
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  child: const SizedBox.expand(),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    try {
      await tester.pumpWidget(buildTabs(visible: true));
      await tester.pumpWidget(buildTabs(visible: false));
      await tester.pumpWidget(buildTabs(visible: true));

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Two'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(controller.index, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('replaces the drag recognizer when the tab axis changes', (
    tester,
  ) async {
    final controller = TabController(length: 8, vsync: tester);

    final tabs = List<Widget>.generate(
      controller.length,
      (index) => Text('Tab $index'),
    );
    var tabEdge = TabEdge.bottom;

    try {
      await tester.pumpWidget(
        ControlledTabsTestApp(
          controller: controller,
          tabs: tabs,
          tabEdge: tabEdge,
          tabExtent: 48,
          tabMinLength: 60,
        ),
      );

      tabEdge = TabEdge.left;
      await tester.pumpWidget(
        ControlledTabsTestApp(
          controller: controller,
          tabs: tabs,
          tabEdge: tabEdge,
          tabExtent: 48,
          tabMinLength: 60,
        ),
      );

      final frameFinder = find.byType(TabFrame);
      RenderTabFrame renderFrame() =>
          tester.renderObject<RenderTabFrame>(frameFinder);

      expect(renderFrame().scrollOffset, 0);

      final tabsOrigin = tester.getTopLeft(find.byType(Tabs));
      final gesture = await tester.startGesture(
        tabsOrigin + const Offset(24, 130),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(renderFrame().scrollOffset, greaterThan(0));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('content horizontal drag outside tab labels keeps ownership', (
    tester,
  ) async {
    final controller = TabController(length: 8, vsync: tester);
    const tabsKey = ValueKey('content-drag-tabs');
    var contentDragStarts = 0;
    var contentDragUpdates = 0;
    var contentDragEnds = 0;
    var contentDragCancels = 0;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                tabs: List<Widget>.generate(
                  controller.length,
                  (index) => Text('Tab $index'),
                ),
                tabMinLength: 80,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    contentDragStarts++;
                  },
                  onHorizontalDragUpdate: (_) {
                    contentDragUpdates++;
                  },
                  onHorizontalDragEnd: (_) {
                    contentDragEnds++;
                  },
                  onHorizontalDragCancel: () {
                    contentDragCancels++;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );

      final renderFrame = tester.renderObject<RenderTabFrame>(
        find.byType(TabFrame),
      );
      final tabsOrigin = tester.getTopLeft(find.byKey(tabsKey));

      expect(renderFrame.scrollOffset, 0);

      final gesture = await tester.startGesture(
        tabsOrigin + const Offset(120, 100),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(contentDragStarts, 1);
      expect(contentDragUpdates, greaterThan(0));
      expect(contentDragEnds, 1);
      expect(contentDragCancels, 0);
      expect(renderFrame.scrollOffset, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('drag inside overflowing tab labels scrolls tab strip', (
    tester,
  ) async {
    final controller = TabController(length: 8, vsync: tester);
    const tabsKey = ValueKey('tab-label-drag-tabs');

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                tabs: List<Widget>.generate(
                  controller.length,
                  (index) => Text('Tab $index'),
                ),
                tabMinLength: 80,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      final renderFrame = tester.renderObject<RenderTabFrame>(
        find.byType(TabFrame),
      );
      final tabsOrigin = tester.getTopLeft(find.byKey(tabsKey));

      expect(renderFrame.scrollOffset, 0);

      final gesture = await tester.startGesture(
        tabsOrigin + const Offset(220, 25),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(renderFrame.scrollOffset, greaterThan(0));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('tap selection uses the configured duration and curve', (
    tester,
  ) async {
    final controller = TabController(length: 3, vsync: tester);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: Tabs(
                controller: controller,
                duration: const Duration(seconds: 1),
                curve: Curves.linear,
                tabs: const [Text('One'), Text('Two'), Text('Three')],
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Three'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.animation?.value, moreOrLessEquals(1));

      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.index, 2);
      expect(controller.animation?.value, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('bottom and right edge tabs receive taps over large content', (
    tester,
  ) async {
    final controller = TabController(length: 3, vsync: tester);

    try {
      await tapEdgeTab(
        tester: tester,
        controller: controller,
        tabEdge: TabEdge.bottom,
        tapOffset: const Offset(200, 148),
      );
      expect(controller.index, 2);

      controller.index = 0;
      await tapEdgeTab(
        tester: tester,
        controller: controller,
        tabEdge: TabEdge.right,
        tapOffset: const Offset(228, 88),
      );
      expect(controller.index, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('tap selection clamps tab strip edge targets', (tester) async {
    final controller = TabController(length: 3, vsync: tester);
    const tabsKey = ValueKey('tabs');

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                duration: const Duration(milliseconds: 1),
                curve: Curves.linear,
                tabsEnd: 0.5,
                tabs: const [Text('One'), Text('Two'), Text('Three')],
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(
        tester.getTopLeft(find.byKey(tabsKey)) + const Offset(150, 25),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.index, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('tap selection keeps index order in rtl text direction', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    const tabsKey = ValueKey('tabs');

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                duration: Duration.zero,
                textDirection: TextDirection.rtl,
                tabs: const [Text('One'), Text('Two'), Text('Three')],
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      final tabsOrigin = tester.getTopLeft(find.byKey(tabsKey));

      await tester.tapAt(tabsOrigin + const Offset(50, 25));
      await tester.pumpAndSettle();

      expect(controller.index, 0);

      await tester.tapAt(tabsOrigin + const Offset(250, 25));
      await tester.pumpAndSettle();

      expect(controller.index, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('uses configured pointer axis modifier after rebuild', (
    tester,
  ) async {
    final controller = TabController(length: 8, vsync: tester);
    const tabsKey = ValueKey('tabs');
    const modifierKey = LogicalKeyboardKey.shiftLeft;

    Widget buildTabs(Set<LogicalKeyboardKey> pointerAxisModifiers) {
      return MaterialApp(
        home: ScrollConfiguration(
          behavior: PointerAxisModifierScrollBehavior(pointerAxisModifiers),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                tabs: List<Widget>.generate(
                  controller.length,
                  (index) => Text('Tab $index'),
                ),
                tabMinLength: 80,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> sendHorizontalScroll() async {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position:
              tester.getTopLeft(find.byKey(tabsKey)) + const Offset(220, 25),
          scrollDelta: const Offset(60, 0),
        ),
      );
      await tester.pump();
    }

    RenderTabFrame renderFrame() =>
        tester.renderObject<RenderTabFrame>(find.byType(TabFrame));

    try {
      await tester.pumpWidget(buildTabs({}));
      final initialRenderFrame = renderFrame();

      await tester.sendKeyDownEvent(modifierKey);
      await sendHorizontalScroll();

      expect(renderFrame(), same(initialRenderFrame));
      expect(renderFrame().scrollOffset, 0);

      await tester.pumpWidget(buildTabs({modifierKey}));

      expect(renderFrame(), same(initialRenderFrame));
      expect(renderFrame().pointerAxisModifiers, contains(modifierKey));

      await sendHorizontalScroll();

      expect(renderFrame().scrollOffset, greaterThan(0));
    } finally {
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('updates tap feedback callback and preserves selection order', (
    tester,
  ) async {
    final controller = TabController(length: 3, vsync: tester);
    const tabsKey = ValueKey('tabs');
    final selectedIndexesAtFeedback = <int>[];

    Widget buildTabs({required bool enableFeedback, bool enabled = true}) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              key: tabsKey,
              controller: controller,
              duration: Duration.zero,
              tabs: const [Text('One'), Text('Two'), Text('Three')],
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: enableFeedback,
              enabled: enabled,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemSound.play' ||
            call.method == 'HapticFeedback.vibrate') {
          selectedIndexesAtFeedback.add(controller.index);
        }
        return null;
      },
    );

    try {
      await tester.pumpWidget(buildTabs(enableFeedback: false));
      RenderTabFrame renderFrame() =>
          tester.renderObject<RenderTabFrame>(find.byType(TabFrame));

      final initialRenderFrame = renderFrame();

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(controller.index, 1);
      expect(selectedIndexesAtFeedback, isEmpty);

      await tester.pumpWidget(buildTabs(enableFeedback: true));

      expect(renderFrame(), same(initialRenderFrame));

      await tester.tap(find.text('Three'));
      await tester.pumpAndSettle();

      expect(controller.index, 2);
      expect(selectedIndexesAtFeedback, [2]);

      await tester.pumpWidget(buildTabs(enableFeedback: false));

      expect(renderFrame(), same(initialRenderFrame));

      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();

      expect(controller.index, 0);
      expect(selectedIndexesAtFeedback, [2]);

      await tester.pumpWidget(buildTabs(enableFeedback: true, enabled: false));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(controller.index, 0);
      expect(selectedIndexesAtFeedback, [2]);
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('disabled state prevents drag and semantics selection changes', (
    tester,
  ) async {
    final controller = TabController(length: 6, initialIndex: 2, vsync: tester);
    final semantics = tester.ensureSemantics();
    const tabsKey = ValueKey('tabs');

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                tabs: List<Widget>.generate(
                  controller.length,
                  (index) => Text('Tab $index'),
                ),
                tabMinLength: 80,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                enabled: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      final renderFrame = tester.renderObject<RenderTabFrame>(
        find.byType(TabFrame),
      );

      expect(renderFrame.scrollOffset, 0);

      final tabsOrigin = tester.getTopLeft(find.byKey(tabsKey));
      final gesture = await tester.startGesture(
        tabsOrigin + const Offset(220, 25),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(renderFrame.scrollOffset, 0);
      expect(controller.index, 2);
      expect(controller.animation?.value, 2);

      final node = tester.getSemantics(find.byType(TabFrame));
      node.owner?.performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();
      node.owner?.performAction(node.id, SemanticsAction.decrease);
      await tester.pumpAndSettle();

      expect(controller.index, 2);
      expect(controller.animation?.value, 2);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}
