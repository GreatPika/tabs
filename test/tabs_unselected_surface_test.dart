import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/tabs.dart';

import 'src/tabs_test_support.dart';

// Surface coverage shares one public Tabs seam so edge, opt-out, and animation
// pixels stay readable as one visible styling contract. Keeping the scenarios
// together is clearer than splitting their shared visible styling contract.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test('defaults unselected-tab styling to the opt-out configuration', () {
    final tabs = Tabs(
      tabs: const [Text('One')],
      child: const SizedBox.expand(),
    );

    expect(tabs.unselectedTabColor, isNull);
    expect(tabs.unselectedTabGap, 2);
  });

  test('rejects a negative unselected-tab gap at the public boundary', () {
    expect(
      () => Tabs(
        unselectedTabGap: -1,
        tabs: const [Text('One')],
        child: const SizedBox.expand(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets(
    'top and bottom edges paint rounded inactive surfaces with active gaps',
    (tester) async {
      const activeColor = Color(0xff1565c0);
      const inactiveColor = Color(0xffe65100);
      final boundaryKey = GlobalKey();

      Widget buildTabs(TabEdge tabEdge) {
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
                    color: activeColor,
                    unselectedTabColor: inactiveColor,
                    unselectedTabGap: 4,
                    tabEdge: tabEdge,
                    tabExtent: 40,
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(8),
                    ),
                    enableFeedback: false,
                    tabs: const [
                      SizedBox.expand(),
                      SizedBox.expand(),
                      SizedBox.expand(),
                    ],
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Future<Color> pixel(Offset position) => readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: position,
      );

      for (final tabEdge in [TabEdge.top, TabEdge.bottom]) {
        await tester.pumpWidget(buildTabs(tabEdge));

        final y = tabEdge == TabEdge.top ? 20.0 : 140.0;
        final cornerY = tabEdge == TabEdge.top ? 1.0 : 159.0;

        expect(await pixel(Offset(100, y)), inactiveColor);
        expect(await pixel(Offset(80, y)), activeColor);
        expect(await pixel(Offset(160, y)), activeColor);
        expect(await pixel(Offset(82, cornerY)), activeColor);
      }
    },
  );

  testWidgets(
    'left and right edges paint rounded inactive surfaces with active gaps',
    (tester) async {
      const activeColor = Color(0xff1565c0);
      const inactiveColor = Color(0xffe65100);
      final boundaryKey = GlobalKey();

      Widget buildTabs(TabEdge tabEdge) {
        return MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 160,
                  height: 240,
                  child: Tabs(
                    color: activeColor,
                    unselectedTabColor: inactiveColor,
                    unselectedTabGap: 4,
                    tabEdge: tabEdge,
                    tabExtent: 40,
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(8),
                    ),
                    enableFeedback: false,
                    tabs: const [
                      SizedBox.expand(),
                      SizedBox.expand(),
                      SizedBox.expand(),
                    ],
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Future<Color> pixel(Offset position) => readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: position,
      );

      for (final tabEdge in [TabEdge.left, TabEdge.right]) {
        await tester.pumpWidget(buildTabs(tabEdge));

        final x = tabEdge == TabEdge.left ? 20.0 : 140.0;
        final roundedCorner = tabEdge == TabEdge.left
            ? const Offset(1, 3)
            : const Offset(159, 3);

        expect(await pixel(Offset(x, 100)), inactiveColor);
        expect(await pixel(Offset(x, 80)), activeColor);
        expect(await pixel(Offset(x, 160)), activeColor);
        expect(await pixel(roundedCorner), activeColor);
      }
    },
  );

  testWidgets(
    'unconfigured inactive surfaces preserve the existing tab strip',
    (tester) async {
      final boundaryKey = GlobalKey();

      Widget buildTabs(TabEdge tabEdge) {
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
                    color: Colors.blue,
                    tabEdge: tabEdge,
                    tabExtent: 40,
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: BorderRadius.zero,
                    enableFeedback: false,
                    tabs: const [
                      SizedBox.expand(),
                      SizedBox.expand(),
                      SizedBox.expand(),
                    ],
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      for (final tabEdge in [TabEdge.top, TabEdge.bottom]) {
        await tester.pumpWidget(buildTabs(tabEdge));

        expect(
          await readBoundaryPixel(
            tester: tester,
            boundary: find.byKey(boundaryKey),
            position: Offset(100, tabEdge == TabEdge.top ? 20 : 140),
          ),
          Colors.white,
        );
      }
    },
  );

  testWidgets('selection animates inactive surfaces with the active frame', (
    tester,
  ) async {
    const initialActiveColor = Color(0xffd32f2f);
    const finalActiveColor = Color(0xff1565c0);
    const inactiveColor = Color(0xffe65100);
    final controller = TabController(length: 2, vsync: tester);
    final boundaryKey = GlobalKey();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 160,
                  height: 120,
                  child: Tabs(
                    controller: controller,
                    duration: const Duration(seconds: 1),
                    curve: Curves.linear,
                    colors: const [initialActiveColor, finalActiveColor],
                    unselectedTabColor: inactiveColor,
                    unselectedTabGap: 4,
                    tabExtent: 40,
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: BorderRadius.zero,
                    enableFeedback: false,
                    tabs: const [SizedBox.expand(), SizedBox.expand()],
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      Future<Color> pixel(Offset position) => readBoundaryPixel(
        tester: tester,
        boundary: find.byKey(boundaryKey),
        position: position,
      );

      expect(await pixel(const Offset(80, 20)), initialActiveColor);
      expect(await pixel(const Offset(120, 20)), inactiveColor);

      controller.animateTo(1, duration: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(await pixel(const Offset(40, 20)), inactiveColor);
      final transitionColor = await pixel(const Offset(80, 20));
      expect(redOf(transitionColor), lessThan(redOf(initialActiveColor)));
      expect(redOf(transitionColor), greaterThan(redOf(finalActiveColor)));
      expect(blueOf(transitionColor), greaterThan(blueOf(initialActiveColor)));
      expect(blueOf(transitionColor), lessThan(blueOf(finalActiveColor)));

      await tester.pump(const Duration(milliseconds: 500));

      expect(await pixel(const Offset(40, 20)), inactiveColor);
      expect(await pixel(const Offset(80, 20)), finalActiveColor);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('overflow scrolling keeps the selected surface visible', (
    tester,
  ) async {
    const activeColor = Color(0xff1565c0);
    final controller = TabController(length: 6, vsync: tester);
    final boundaryKey = GlobalKey();

    try {
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
                  height: 120,
                  child: Tabs(
                    controller: controller,
                    color: activeColor,
                    unselectedTabColor: Colors.orange,
                    tabMinLength: 90,
                    tabExtent: 40,
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: BorderRadius.zero,
                    enableFeedback: false,
                    tabs: List<Widget>.generate(
                      controller.length,
                      (_) => const SizedBox.expand(),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      controller.animateTo(5, duration: Duration.zero);
      await tester.pump();

      expect(
        await readBoundaryPixel(
          tester: tester,
          boundary: find.byKey(boundaryKey),
          position: const Offset(200, 20),
        ),
        activeColor,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('vertical overflow keeps the selected surface visible', (
    tester,
  ) async {
    const activeColor = Color(0xff1565c0);
    final boundaryKey = GlobalKey();

    for (final tabEdge in [TabEdge.left, TabEdge.right]) {
      final controller = TabController(length: 6, vsync: tester);

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.white,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 120,
                    height: 240,
                    child: Tabs(
                      controller: controller,
                      color: activeColor,
                      unselectedTabColor: Colors.orange,
                      tabEdge: tabEdge,
                      tabMinLength: 90,
                      tabExtent: 40,
                      borderRadius: BorderRadius.zero,
                      tabBorderRadius: BorderRadius.zero,
                      enableFeedback: false,
                      tabs: List<Widget>.generate(
                        controller.length,
                        (_) => const SizedBox.expand(),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        controller.animateTo(5, duration: Duration.zero);
        await tester.pump();

        expect(
          await readBoundaryPixel(
            tester: tester,
            boundary: find.byKey(boundaryKey),
            position: Offset(tabEdge == TabEdge.left ? 20 : 100, 200),
          ),
          activeColor,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
  });
}
