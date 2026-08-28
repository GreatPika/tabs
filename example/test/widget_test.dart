import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/tabs.dart';

import 'package:tabs_example/main.dart';

void main() {
  testWidgets('renders the tabs example app', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Image 1'), findsOneWidget);
  });

  testWidgets('first example shows gray inactive tab-label surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final firstTabs = tester.widget<Tabs>(find.byType(Tabs).first);
    expect(firstTabs.tabEdge, TabEdge.top);
    expect(firstTabs.border, isNull);
    expect(firstTabs.unselectedTabColor, const Color(0xffb0bec5));
    expect(
      firstTabs.unselectedTabShadow,
      const BoxShadow(
        color: Color.fromARGB(255, 107, 107, 107),
        blurRadius: 1,
        blurStyle: BlurStyle.outer,
      ),
    );
    expect(firstTabs.unselectedTextStyle?.color, Colors.black);
    expect(firstTabs.unselectedTabGap, 4);
  });

  testWidgets('first example collapse button keeps the top trailing anchor', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final collapseButton = find.byKey(
      const ValueKey('collapse-credit-card-tabs'),
    );
    final pageScroll = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      collapseButton,
      200,
      scrollable: pageScroll,
    );

    final tabsFinder = find.byType(Tabs).first;
    expect(tester.getSize(tabsFinder), const Size(400, 320));
    expect(
      find.descendant(
        of: collapseButton,
        matching: find.byIcon(Icons.keyboard_arrow_down),
      ),
      findsOneWidget,
    );

    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    final tabsRect = tester.getRect(tabsFinder);
    final buttonRect = tester.getRect(collapseButton);
    final tabButtonGap = tester.widget<Tabs>(tabsFinder).tabButtonGap;

    expect(tester.widget<Tabs>(tabsFinder).collapsed, isTrue);
    expect(tabsRect.size, const Size(400, 54));
    expect(buttonRect.top, tabsRect.top);
    expect(buttonRect.right + tabButtonGap, tabsRect.right);
    expect(
      find.descendant(
        of: collapseButton,
        matching: find.byIcon(Icons.keyboard_arrow_up),
      ),
      findsOneWidget,
    );

    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    expect(tester.widget<Tabs>(tabsFinder).collapsed, isFalse);
    expect(tester.getSize(tabsFinder), const Size(400, 320));
  });

  testWidgets('image tab buttons clamp at controller bounds', (tester) async {
    await tester.pumpWidget(const MyApp());

    final previousButton = find.byKey(const ValueKey('previous-image-tab'));
    final nextButton = find.byKey(const ValueKey('next-image-tab'));
    final pageScroll = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      previousButton,
      200,
      scrollable: pageScroll,
    );

    await tester.tap(previousButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 4; i++) {
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
