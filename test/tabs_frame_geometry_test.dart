import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/src/render/tabs_frame.dart';
import 'package:tabs/tabs.dart';

import 'src/tabs_test_support.dart';

class _RenderProbe extends RenderProxyBox {
  _RenderProbe(this._onLayout, this._onPaint);

  VoidCallback _onLayout;
  VoidCallback _onPaint;

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    _onLayout();
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _onPaint();
    super.paint(context, offset);
  }
}

// This test probe must be a render-object widget so it can count parent layout
// and paint calls directly; replacing it with a shallower widget would stop
// proving the render owner contract under test.
// ignore: depth-of-inheritance-tree
class _ProbeBox extends SingleChildRenderObjectWidget {
  const _ProbeBox({
    required VoidCallback onLayout,
    required VoidCallback onPaint,
    super.child,
  }) : _onLayout = onLayout,
       _onPaint = onPaint;

  final VoidCallback _onLayout;
  final VoidCallback _onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderProbe(_onLayout, _onPaint);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderProbe renderObject,
  ) {
    renderObject
      .._onLayout = _onLayout
      .._onPaint = _onPaint;
  }
}

// Render-geometry coverage keeps paint offsets, clipping, overflow, and layout
// regressions together because they share the RenderTabFrame geometry contract.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets('border outlines the joined active tab and content shape', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                width: 120,
                height: 100,
                child: Tabs(
                  color: Colors.cyan,
                  border: const Border.fromBorderSide(
                    BorderSide(color: Colors.red, width: 4),
                  ),
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  tabExtent: 30,
                  tabs: const [SizedBox.expand(), SizedBox.expand()],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      (await readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: const Offset(0, 60),
      )).toARGB32(),
      Colors.red.toARGB32(),
    );
    expect(
      (await readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: const Offset(3, 60),
      )).toARGB32(),
      Colors.red.toARGB32(),
    );
    expect(
      (await readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: const Offset(5, 60),
      )).toARGB32(),
      Colors.cyan.toARGB32(),
    );
    expect(
      (await readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: const Offset(30, 0),
      )).toARGB32(),
      Colors.red.toARGB32(),
    );
    expect(
      (await readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: const Offset(90, 0),
      )).toARGB32(),
      Colors.white.toARGB32(),
    );
  });

  testWidgets('border radius keeps physical bottom corners for top-edge tabs', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                width: 120,
                height: 100,
                child: Tabs(
                  color: Colors.red,
                  tabExtent: 30,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                  ),
                  tabBorderRadius: BorderRadius.zero,
                  tabs: const [SizedBox.expand()],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      await readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: const Offset(1, 99),
      ),
      Colors.white,
    );
  });

  testWidgets('collapsed tabs keep strip footprint and action edge anchor', (
    tester,
  ) async {
    var collapsedValue = true;

    // The edge matrix is intentionally kept in one helper so all collapsed
    // strip anchor cases are checked against identical render-object probes.
    // ignore: halstead-volume, number-of-parameters, source-lines-of-code
    Future<void> verify({
      required TabEdge tabEdge,
      required bool collapseOnTrailing,
      required Size parentSize,
      required Size expectedSize,
      required Offset expectedActionOffset,
    }) async {
      const actionKey = ValueKey('collapse-action');

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: parentSize.width,
              height: parentSize.height,
              child: Tabs(
                collapsed: true,
                onCollapsedChanged: (value) {
                  collapsedValue = value;
                },
                tabEdge: tabEdge,
                tabExtent: 40,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                tabLeadingButtons: collapseOnTrailing
                    ? const []
                    : const [
                        TabsActionButton(
                          key: actionKey,
                          action: TabsActionButtonAction.toggleCollapse,
                          icon: Icons.unfold_more,
                        ),
                      ],
                tabTrailingButtons: collapseOnTrailing
                    ? const [
                        TabsActionButton(
                          key: actionKey,
                          action: TabsActionButtonAction.toggleCollapse,
                          icon: Icons.unfold_more,
                        ),
                      ]
                    : const [],
                tabs: const [SizedBox.expand()],
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      final renderFrame = tester.renderObject<RenderTabFrame>(
        find.byType(TabFrame),
      );
      final content = renderFrame.firstChild;
      if (content == null) {
        throw StateError('Expected collapsed content child.');
      }
      final tab = renderFrame.childAfter(content);
      if (tab == null) {
        throw StateError('Expected collapsed tab child.');
      }
      final action = renderFrame.childAfter(tab);
      if (action == null) {
        throw StateError('Expected collapsed action child.');
      }
      final actionParentData = action.parentData as TabFrameParentData;

      expect(renderFrame.size, expectedSize);
      expect(action.size, const Size.square(40));
      expect(actionParentData.offset, expectedActionOffset);
      expect(collapsedValue, isTrue);
    }

    await verify(
      tabEdge: TabEdge.top,
      collapseOnTrailing: false,
      parentSize: const Size(300, 40),
      expectedSize: const Size(300, 40),
      expectedActionOffset: const Offset(4, 0),
    );
    await verify(
      tabEdge: TabEdge.top,
      collapseOnTrailing: true,
      parentSize: const Size(300, 40),
      expectedSize: const Size(300, 40),
      expectedActionOffset: const Offset(256, 0),
    );
    await verify(
      tabEdge: TabEdge.bottom,
      collapseOnTrailing: false,
      parentSize: const Size(300, 40),
      expectedSize: const Size(300, 40),
      expectedActionOffset: const Offset(4, 0),
    );
    await verify(
      tabEdge: TabEdge.bottom,
      collapseOnTrailing: true,
      parentSize: const Size(300, 40),
      expectedSize: const Size(300, 40),
      expectedActionOffset: const Offset(256, 0),
    );
    await verify(
      tabEdge: TabEdge.left,
      collapseOnTrailing: false,
      parentSize: const Size(40, 160),
      expectedSize: const Size(40, 160),
      expectedActionOffset: const Offset(0, 4),
    );
    await verify(
      tabEdge: TabEdge.left,
      collapseOnTrailing: true,
      parentSize: const Size(40, 160),
      expectedSize: const Size(40, 160),
      expectedActionOffset: const Offset(0, 116),
    );
    await verify(
      tabEdge: TabEdge.right,
      collapseOnTrailing: false,
      parentSize: const Size(40, 160),
      expectedSize: const Size(40, 160),
      expectedActionOffset: const Offset(0, 4),
    );
    await verify(
      tabEdge: TabEdge.right,
      collapseOnTrailing: true,
      parentSize: const Size(40, 160),
      expectedSize: const Size(40, 160),
      expectedActionOffset: const Offset(0, 116),
    );
  });

  testWidgets('collapsed dry layout and intrinsics use strip footprint', (
    tester,
  ) async {
    var collapsedValue = true;

    Future<RenderTabFrame> pumpCollapsedFrame(TabEdge tabEdge) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Tabs(
                collapsed: true,
                onCollapsedChanged: (value) {
                  collapsedValue = value;
                },
                tabEdge: tabEdge,
                tabExtent: 40,
                tabTrailingButtons: const [
                  TabsActionButton(
                    action: TabsActionButtonAction.toggleCollapse,
                    icon: Icons.unfold_more,
                  ),
                ],
                tabs: const [SizedBox.expand()],
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      return tester.renderObject<RenderTabFrame>(find.byType(TabFrame));
    }

    var renderFrame = await pumpCollapsedFrame(TabEdge.top);
    expect(
      renderFrame.getDryLayout(const BoxConstraints(maxWidth: 320)),
      const Size(320, 44),
    );
    expect(
      renderFrame.getDryLayout(const BoxConstraints()),
      const Size(40, 44),
    );
    expect(renderFrame.getMinIntrinsicHeight(320), 44);
    expect(renderFrame.getMaxIntrinsicHeight(320), 44);
    expect(renderFrame.getMinIntrinsicWidth(40), 40);
    expect(renderFrame.getMaxIntrinsicWidth(40), 40);

    renderFrame = await pumpCollapsedFrame(TabEdge.left);
    expect(
      renderFrame.getDryLayout(const BoxConstraints(maxHeight: 180)),
      const Size(44, 180),
    );
    expect(
      renderFrame.getDryLayout(const BoxConstraints()),
      const Size(44, 40),
    );
    expect(renderFrame.getMinIntrinsicWidth(180), 44);
    expect(renderFrame.getMaxIntrinsicWidth(180), 44);
    expect(renderFrame.getMinIntrinsicHeight(40), 40);
    expect(renderFrame.getMaxIntrinsicHeight(40), 40);
    expect(collapsedValue, isTrue);
  });

  testWidgets('paints frame children relative to the render object offset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 30,
              top: 40,
              child: SizedBox(
                width: 100,
                height: 80,
                child: Tabs(
                  tabs: const [SizedBox.expand()],
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  tabExtent: 20,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final renderObject = tester.renderObject<RenderTabFrame>(
      find.byType(TabFrame),
    );
    final context = RecordingPaintingContext();

    renderObject.paint(context, const Offset(30, 40));

    final childOffsets = context.takeChildOffsets();
    expect(childOffsets, contains(const Offset(30, 40)));
    expect(childOffsets, contains(const Offset(30, 60)));
  });

  testWidgets('keeps content hit geometry after tab edge moves trailing', (
    tester,
  ) async {
    const tabsKey = ValueKey('tabs');
    const tabExtent = 40.0;
    var contentTapCount = 0;

    Widget buildTabs(TabEdge tabEdge) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            height: 160,
            child: Tabs(
              key: tabsKey,
              tabEdge: tabEdge,
              tabExtent: tabExtent,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              tabs: const [SizedBox.expand()],
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
    }

    RenderTabFrame renderFrame() =>
        tester.renderObject<RenderTabFrame>(find.byType(TabFrame));

    await tester.pumpWidget(buildTabs(TabEdge.left));
    final verticalFrame = renderFrame();

    await tester.pumpWidget(buildTabs(TabEdge.right));

    expect(renderFrame(), same(verticalFrame));
    await tester.tapAt(
      tester.getTopLeft(find.byKey(tabsKey)) + const Offset(20, 80),
    );
    expect(contentTapCount, 1);

    await tester.pumpWidget(buildTabs(TabEdge.top));
    final horizontalFrame = renderFrame();

    await tester.pumpWidget(buildTabs(TabEdge.bottom));

    expect(renderFrame(), same(horizontalFrame));
    await tester.tapAt(
      tester.getTopLeft(find.byKey(tabsKey)) + const Offset(120, 20),
    );
    expect(contentTapCount, 2);
  });

  testWidgets(
    'paints frame background path relative to the render object offset',
    (tester) async {
      final boundaryKey = GlobalKey();
      const backgroundColor = Color(0xffd32f2f);

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned(
                    left: 30,
                    top: 40,
                    child: SizedBox(
                      width: 100,
                      height: 80,
                      child: Tabs(
                        tabs: const [SizedBox.expand()],
                        color: backgroundColor,
                        borderRadius: BorderRadius.zero,
                        tabBorderRadius: BorderRadius.zero,
                        tabExtent: 20,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final boundary = find.byKey(boundaryKey);

      expect(
        await readBoundaryPixel(
          tester: tester,
          boundary: boundary,
          position: const Offset(35, 65),
        ),
        backgroundColor,
      );
      expect(
        await readBoundaryPixel(
          tester: tester,
          boundary: boundary,
          position: const Offset(5, 25),
        ),
        Colors.white,
      );
    },
  );

  testWidgets(
    'resets tab scroll after resize removes overflow and preserves taps',
    (tester) async {
      final controller = TabController(
        length: 6,
        initialIndex: 1,
        vsync: tester,
      );
      const tabsKey = ValueKey('tabs');
      const tabExtent = 48.0;
      const tabMinLength = 80.0;

      Widget buildTabs(double width) {
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 160,
              child: Tabs(
                key: tabsKey,
                controller: controller,
                tabs: List<Widget>.generate(
                  controller.length,
                  (index) => SizedBox.expand(key: ValueKey('tab-$index')),
                ),
                tabExtent: tabExtent,
                tabMinLength: tabMinLength,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      }

      RenderTabFrame renderFrame() =>
          tester.renderObject<RenderTabFrame>(find.byType(TabFrame));

      Offset firstTabOffset() {
        final frame = renderFrame();
        final content = frame.firstChild;
        if (content == null) {
          throw StateError('Expected the content child to be laid out.');
        }

        final firstTab = frame.childAfter(content);
        if (firstTab == null) {
          throw StateError('Expected the first tab child to be laid out.');
        }

        return (firstTab.parentData as TabFrameParentData).offset;
      }

      try {
        await tester.pumpWidget(buildTabs(240));

        final tabsOrigin = tester.getTopLeft(find.byKey(tabsKey));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tabsOrigin + const Offset(220, tabExtent / 2),
            scrollDelta: const Offset(0, 90),
          ),
        );
        await tester.pump();

        expect(renderFrame().scrollOffset, greaterThan(0));
        expect(firstTabOffset().dx, lessThan(0));

        await tester.pumpWidget(buildTabs(600));

        expect(renderFrame().scrollOffset, 0);
        expect(firstTabOffset(), Offset.zero);

        await tester.tapAt(
          tester.getTopLeft(find.byKey(tabsKey)) +
              const Offset(tabMinLength / 2, tabExtent / 2),
        );
        await tester.pump();

        expect(controller.index, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('rebuild with new colors list updates rendered selected color', (
    tester,
  ) async {
    final controller = TabController(length: 2, initialIndex: 1, vsync: tester);
    final boundaryKey = GlobalKey();

    Widget buildTabs(List<Color> colors) {
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
                  colors: colors,
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  tabs: const [Text('One'), Text('Two')],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    try {
      await tester.pumpWidget(
        buildTabs(const [Color(0xffb71c1c), Color(0xff1b5e20)]),
      );

      expect(
        await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
        const Color(0xff1b5e20),
      );

      await tester.pumpWidget(
        buildTabs(const [Color(0xff0d47a1), Color(0xffffc107)]),
      );

      expect(
        await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
        const Color(0xffffc107),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('rebuild from colors to color clears stale rendered tab color', (
    tester,
  ) async {
    final controller = TabController(length: 2, initialIndex: 1, vsync: tester);
    final boundaryKey = GlobalKey();

    Widget buildTabs({Color? color, List<Color>? colors}) {
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
                  color: color,
                  colors: colors,
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  tabs: const [Text('One'), Text('Two')],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    try {
      await tester.pumpWidget(
        buildTabs(colors: const [Color(0xffb71c1c), Color(0xff1b5e20)]),
      );

      expect(
        await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
        const Color(0xff1b5e20),
      );

      await tester.pumpWidget(buildTabs(color: const Color(0xff6a1b9a)));

      expect(
        await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
        const Color(0xff6a1b9a),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('default transparent frame keeps parent background visible', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
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
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  enableFeedback: false,
                  tabs: const [Text('One')],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      await readTabsBackgroundPixel(tester: tester, boundaryKey: boundaryKey),
      Colors.white,
    );
  });

  testWidgets('render animation owner implicitly scrolls overflow to target', (
    tester,
  ) async {
    final controller = TabController(length: 6, vsync: tester);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              height: 160,
              child: Tabs(
                controller: controller,
                duration: const Duration(seconds: 1),
                curve: Curves.linear,
                tabMinLength: 90,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                tabs: List<Widget>.generate(
                  controller.length,
                  (index) => Text('Scroll tab $index'),
                ),
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

      controller.animateTo(5, duration: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(renderFrame.scrollOffset, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 500));

      final content = renderFrame.firstChild;
      if (content == null) {
        throw StateError('Expected content to be laid out.');
      }

      final lastTab = renderFrame.childAfter(content);
      if (lastTab == null) {
        throw StateError('Expected at least one tab to be laid out.');
      }

      var visibleLastTab = lastTab;
      for (
        var nextTab = renderFrame.childAfter(visibleLastTab);
        nextTab != null;
        nextTab = renderFrame.childAfter(visibleLastTab)
      ) {
        visibleLastTab = nextTab;
      }

      final lastTabOffset =
          (visibleLastTab.parentData as TabFrameParentData).offset.dx;
      expect(lastTabOffset + visibleLastTab.size.width, lessThanOrEqualTo(240));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('progress repaint does not relayout stable tab geometry', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    final animation = controller.animation;
    if (animation == null) {
      throw StateError('Expected TabController to expose an animation.');
    }
    var layoutCount = 0;
    var paintCount = 0;

    Widget probe() {
      return _ProbeBox(
        onLayout: () {
          layoutCount++;
        },
        onPaint: () {
          paintCount++;
        },
        child: const SizedBox.expand(),
      );
    }

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 160,
              child: TabFrame(
                controller: controller,
                progressAnimation: animation,
                collapseProgressAnimation: const AlwaysStoppedAnimation<double>(
                  0,
                ),
                curve: Curves.linear,
                duration: const Duration(seconds: 1),
                tabButtonGap: 0,
                collapsed: false,
                collapsedActionIndex: null,
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                border: null,
                tabExtent: 40,
                tabEdge: TabEdge.top,
                tabAxis: Axis.horizontal,
                tabStripStart: 0,
                tabStripEnd: 1,
                tabMinLength: 0,
                tabMaxLength: double.infinity,
                color: Colors.white,
                colors: const [Color(0xffb71c1c), Color(0xff1b5e20)],
                semanticsLabel: null,
                semanticsHint: null,
                semanticsValueBuilder: null,
                enabled: true,
                enableFeedback: false,
                textDirection: TextDirection.ltr,
                tabs: [probe(), probe()],
                tabLeadingButtons: const [],
                tabTrailingButtons: const [],
                child: probe(),
              ),
            ),
          ),
        ),
      );

      controller.animateTo(1, duration: const Duration(seconds: 1));
      await tester.pump();

      final layoutCountBeforeTick = layoutCount;
      final paintCountBeforeTick = paintCount;

      await tester.pump(const Duration(milliseconds: 500));

      expect(layoutCount, layoutCountBeforeTick);
      expect(paintCount, greaterThan(paintCountBeforeTick));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('clip cache follows top tab strip geometry rebuilds', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    const tabsColor = Color(0xffd32f2f);

    Widget buildTabs({
      required double width,
      required double tabsStart,
      required double tabsEnd,
      required BorderRadius tabBorderRadius,
    }) {
      return MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: Colors.white,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 160,
                child: Tabs(
                  tabsStart: tabsStart,
                  tabsEnd: tabsEnd,
                  tabExtent: 40,
                  tabMinLength: 80,
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: tabBorderRadius,
                  enableFeedback: false,
                  tabs: List<Widget>.generate(
                    4,
                    (index) => const ColoredBox(
                      color: tabsColor,
                      child: SizedBox.expand(),
                    ),
                  ),
                  child: const ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<Color> pixel(Offset position) {
      return readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: position,
      );
    }

    await tester.pumpWidget(
      buildTabs(
        width: 240,
        tabsStart: 0,
        tabsEnd: 0.5,
        tabBorderRadius: BorderRadius.zero,
      ),
    );

    expect(await pixel(const Offset(30, 20)), tabsColor);

    await tester.pumpWidget(
      buildTabs(
        width: 240,
        tabsStart: 0.25,
        tabsEnd: 0.75,
        tabBorderRadius: BorderRadius.zero,
      ),
    );

    expect(await pixel(const Offset(30, 20)), Colors.white);
    expect(await pixel(const Offset(70, 20)), tabsColor);

    await tester.pumpWidget(
      buildTabs(
        width: 320,
        tabsStart: 0.25,
        tabsEnd: 0.75,
        tabBorderRadius: BorderRadius.zero,
      ),
    );

    expect(await pixel(const Offset(70, 20)), Colors.white);
    expect(await pixel(const Offset(90, 20)), tabsColor);

    await tester.pumpWidget(
      buildTabs(
        width: 320,
        tabsStart: 0.25,
        tabsEnd: 0.5,
        tabBorderRadius: BorderRadius.zero,
      ),
    );

    expect(await pixel(const Offset(170, 20)), Colors.white);

    await tester.pumpWidget(
      buildTabs(
        width: 240,
        tabsStart: 0.25,
        tabsEnd: 0.75,
        tabBorderRadius: BorderRadius.zero,
      ),
    );
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(170, 20),
        scrollDelta: Offset(0, 20),
      ),
    );
    await tester.pump();

    expect(await pixel(const Offset(50, 20)), Colors.white);

    await tester.pumpWidget(
      buildTabs(
        width: 240,
        tabsStart: 0.25,
        tabsEnd: 0.75,
        tabBorderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(20),
        ),
      ),
    );

    expect(await pixel(const Offset(50, 20)), Colors.white);
  });

  testWidgets(
    'clip cache follows right edge axis extent and overflow rebuilds',
    (tester) async {
      final boundaryKey = GlobalKey();
      const tabsColor = Color(0xff1976d2);

      Widget buildTabs({
        required TabEdge tabEdge,
        required double tabExtent,
        required double tabMinLength,
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
                    tabEdge: tabEdge,
                    tabsStart: 0.25,
                    tabsEnd: 0.75,
                    tabExtent: tabExtent,
                    tabMinLength: tabMinLength,
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: BorderRadius.zero,
                    enableFeedback: false,
                    tabs: List<Widget>.generate(
                      4,
                      (index) => const ColoredBox(
                        color: tabsColor,
                        child: SizedBox.expand(),
                      ),
                    ),
                    child: const ColoredBox(
                      color: Colors.white,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Future<Color> pixel(Offset position) {
        return readBoundaryPixel(
          tester: tester,
          boundary: find.byKey(boundaryKey),
          position: position,
        );
      }

      RenderTabFrame renderFrame() =>
          tester.renderObject<RenderTabFrame>(find.byType(TabFrame));

      await tester.pumpWidget(
        buildTabs(tabEdge: TabEdge.top, tabExtent: 40, tabMinLength: 80),
      );

      expect(await pixel(const Offset(70, 20)), tabsColor);

      await tester.pumpWidget(
        buildTabs(tabEdge: TabEdge.right, tabExtent: 40, tabMinLength: 80),
      );

      expect(renderFrame().alwaysNeedsCompositing, isTrue);
      expect(await pixel(const Offset(70, 20)), Colors.white);
      expect(await pixel(const Offset(220, 50)), tabsColor);

      await tester.pumpWidget(
        buildTabs(tabEdge: TabEdge.right, tabExtent: 60, tabMinLength: 80),
      );

      expect(await pixel(const Offset(175, 50)), Colors.white);
      expect(await pixel(const Offset(185, 50)), tabsColor);

      await tester.pumpWidget(
        buildTabs(tabEdge: TabEdge.right, tabExtent: 60, tabMinLength: 20),
      );

      expect(renderFrame().alwaysNeedsCompositing, isFalse);
    },
  );
}
