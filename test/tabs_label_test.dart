import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/src/render/tabs_frame.dart';
import 'package:tabs/tabs.dart';

import 'src/tabs_test_support.dart';

// Label coverage keeps style, directionality, and animation assertions together
// because they verify one animated tab-label composition contract.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets('rebuild updates selected and unselected text appearance', (
    tester,
  ) async {
    Widget buildTabs({
      required TextStyle selectedTextStyle,
      required TextStyle unselectedTextStyle,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            height: 160,
            child: Tabs(
              selectedTextStyle: selectedTextStyle,
              unselectedTextStyle: unselectedTextStyle,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              tabs: const [Text('Selected tab'), Text('Unselected tab')],
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    TextStyle? textStyle(String text) =>
        tester.renderObject<RenderParagraph>(find.text(text)).text.style;

    await tester.pumpWidget(
      buildTabs(
        selectedTextStyle: const TextStyle(color: Color(0xfff44336)),
        unselectedTextStyle: const TextStyle(color: Color(0xff2196f3)),
      ),
    );

    expect(textStyle('Selected tab')?.color, const Color(0xfff44336));
    expect(textStyle('Unselected tab')?.color, const Color(0xff2196f3));

    await tester.pumpWidget(
      buildTabs(
        selectedTextStyle: const TextStyle(color: Color(0xff4caf50)),
        unselectedTextStyle: const TextStyle(color: Color(0xffff9800)),
      ),
    );

    expect(textStyle('Selected tab')?.color, const Color(0xff4caf50));
    expect(textStyle('Unselected tab')?.color, const Color(0xffff9800));
  });

  testWidgets('rebuild updates configured text direction', (tester) async {
    Widget buildTabs(TextDirection textDirection) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            height: 160,
            child: Tabs(
              textDirection: textDirection,
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              tabs: const [Text('Directional tab')],
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    TextDirection? renderedTextDirection() => tester
        .renderObject<RenderParagraph>(find.text('Directional tab'))
        .textDirection;

    await tester.pumpWidget(buildTabs(TextDirection.ltr));

    expect(renderedTextDirection(), TextDirection.ltr);

    await tester.pumpWidget(buildTabs(TextDirection.rtl));

    expect(renderedTextDirection(), TextDirection.rtl);
  });

  testWidgets(
    'animation owners update background and labels without content rebuild',
    (tester) async {
      final controller = TabController(length: 2, vsync: tester);
      final boundaryKey = GlobalKey();

      TextStyle? textStyle(String text) =>
          tester.renderObject<RenderParagraph>(find.text(text)).text.style;

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
                    height: 160,
                    child: Tabs(
                      controller: controller,
                      duration: const Duration(seconds: 1),
                      curve: Curves.linear,
                      colors: const [Color(0xffff0000), Color(0xff0000ff)],
                      selectedTextStyle: const TextStyle(
                        color: Color(0xff00ff00),
                        fontSize: 20,
                      ),
                      unselectedTextStyle: const TextStyle(
                        color: Color(0xff000000),
                        fontSize: 10,
                      ),
                      borderRadius: BorderRadius.zero,
                      tabBorderRadius: BorderRadius.zero,
                      enableFeedback: false,
                      tabs: const [
                        Text('Animated label one'),
                        Text('Animated label two'),
                      ],
                      children: const [
                        Text('Animated content one'),
                        Text('Animated content two'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final initialRenderFrame = tester.renderObject<RenderTabFrame>(
          find.byType(TabFrame),
        );

        controller.animateTo(1, duration: const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          tester.renderObject<RenderTabFrame>(find.byType(TabFrame)),
          same(initialRenderFrame),
        );
        final midBackground = await readTabsBackgroundPixel(
          tester: tester,
          boundaryKey: boundaryKey,
        );
        expect(redOf(midBackground), lessThan(0xff));
        expect(blueOf(midBackground), greaterThan(0));
        final firstLabelColor = textStyle('Animated label one')?.color;
        final secondLabelColor = textStyle('Animated label two')?.color;
        expect(firstLabelColor, isNotNull);
        expect(secondLabelColor, isNotNull);
        final firstColor = firstLabelColor ?? Colors.transparent;
        final secondColor = secondLabelColor ?? Colors.transparent;
        expect(greenOf(firstColor), greaterThan(0));
        expect(greenOf(firstColor), lessThan(0xff));
        expect(greenOf(secondColor), greaterThan(0));
        expect(greenOf(secondColor), lessThan(0xff));
        expect(textTransformScale('Animated label one'), greaterThan(1));
        expect(textTransformScale('Animated label two'), greaterThan(1));
        expect(find.text('Animated content two'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );
}
