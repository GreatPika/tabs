import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/tabs.dart';

import 'src/tabs_test_support.dart';

// Focus coverage stays together so horizontal, vertical, and RTL key routing can
// be audited against the same TabsFocus boundary without metric-only splitting.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets('TabsFocus left and right arrows select horizontal tabs', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    late BuildContext focusContext;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: TabsFocus(
                controller: controller,
                child: Builder(
                  builder: (context) {
                    focusContext = context;

                    return Tabs(
                      controller: controller,
                      duration: Duration.zero,
                      tabs: const [Text('One'), Text('Two'), Text('Three')],
                      borderRadius: BorderRadius.zero,
                      tabBorderRadius: BorderRadius.zero,
                      enableFeedback: false,
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await focusTabs(tester: tester, focusContext: focusContext);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(controller.index, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(controller.index, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(controller.index, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(controller.index, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('TabsFocus up and down arrows select vertical tabs', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    late BuildContext focusContext;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              height: 180,
              child: TabsFocus(
                controller: controller,
                tabAxis: Axis.vertical,
                child: Builder(
                  builder: (context) {
                    focusContext = context;

                    return Tabs(
                      controller: controller,
                      duration: Duration.zero,
                      tabEdge: TabEdge.right,
                      tabs: const [Text('One'), Text('Two'), Text('Three')],
                      borderRadius: BorderRadius.zero,
                      tabBorderRadius: BorderRadius.zero,
                      enableFeedback: false,
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await focusTabs(tester: tester, focusContext: focusContext);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(controller.index, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(controller.index, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(controller.index, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('TabsFocus keeps physical index-order keys in rtl', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    late BuildContext focusContext;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: TabsFocus(
                controller: controller,
                child: Builder(
                  builder: (context) {
                    focusContext = context;

                    return Tabs(
                      controller: controller,
                      duration: Duration.zero,
                      textDirection: TextDirection.rtl,
                      tabs: const [Text('One'), Text('Two'), Text('Three')],
                      borderRadius: BorderRadius.zero,
                      tabBorderRadius: BorderRadius.zero,
                      enableFeedback: false,
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await focusTabs(tester: tester, focusContext: focusContext);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(controller.index, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(controller.index, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}
