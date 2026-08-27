import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/tabs.dart';

// Action-button coverage keeps layout, shape, callback routing, and tab
// selection assertions together because they describe one generated button slot
// contract; splitting only for metrics would hide those dependencies.
// ignore: halstead-volume, source-lines-of-code, maintainability-index, maximum-nesting-level
void main() {
  testWidgets('tab strip buttons keep material buttons outside tab selection', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    const tabsKey = ValueKey('tabs');
    const leadingKey = ValueKey('leading-button');
    const trailingKey = ValueKey('trailing-button');
    const firstTabKey = ValueKey('first-tab');
    const contentKey = ValueKey('content');
    const tabRadius = BorderRadius.all(Radius.circular(20));
    const buttonRadius = BorderRadius.all(Radius.circular(16));
    const buttonGap = 4.0;
    var leadingTaps = 0;
    var trailingTaps = 0;

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
                tabBorderRadius: tabRadius,
                tabLeadingButtons: [
                  TabsActionButton(
                    key: leadingKey,
                    onPressed: () => leadingTaps++,
                    icon: Icons.chevron_left,
                  ),
                ],
                tabTrailingButtons: [
                  TabsActionButton(
                    key: trailingKey,
                    onPressed: () => trailingTaps++,
                    icon: Icons.chevron_right,
                  ),
                ],
                tabs: const [
                  SizedBox.expand(key: firstTabKey),
                  SizedBox.expand(),
                ],
                borderRadius: BorderRadius.zero,
                enableFeedback: false,
                child: const SizedBox.expand(key: contentKey),
              ),
            ),
          ),
        ),
      );

      final leadingClip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byKey(leadingKey),
          matching: find.byType(ClipRRect),
        ),
      );
      final trailingClip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byKey(trailingKey),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(leadingClip.borderRadius, buttonRadius);
      expect(trailingClip.borderRadius, buttonRadius);
      final leadingButton = tester.widget<IconButton>(find.byKey(leadingKey));
      final leadingShape = leadingButton.style?.shape?.resolve({});
      expect(leadingShape, isA<RoundedRectangleBorder>());
      if (leadingShape is! RoundedRectangleBorder) {
        fail('Expected tab action button shape to be rounded rectangle.');
      }
      expect(leadingShape.borderRadius, buttonRadius);
      expect(leadingButton.style?.padding?.resolve({}), EdgeInsets.zero);
      final tabsRect = tester.getRect(find.byKey(tabsKey));
      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final trailingRect = tester.getRect(find.byKey(trailingKey));
      final firstTabRect = tester.getRect(find.byKey(firstTabKey));
      final contentRect = tester.getRect(find.byKey(contentKey));
      expect(leadingRect.left, tabsRect.left);
      expect(leadingRect.top, tabsRect.top);
      expect(leadingRect.size, const Size.square(50));
      expect(firstTabRect.left, leadingRect.right + buttonGap);
      expect(contentRect.top, leadingRect.bottom + buttonGap);
      expect(trailingRect.right, tabsRect.right);
      expect(trailingRect.top, tabsRect.top);
      expect(trailingRect.size, const Size.square(50));

      await tester.tap(find.byKey(leadingKey));
      await tester.pumpAndSettle();
      expect(leadingTaps, 1);
      expect(controller.index, 0);

      await tester.tap(find.byKey(trailingKey));
      await tester.pumpAndSettle();
      expect(trailingTaps, 1);
      expect(controller.index, 0);

      await tester.tapAt(
        tester.getTopLeft(find.byKey(tabsKey)) + const Offset(175, 25),
      );
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('collapse action leaves only its leading or trailing button', (
    tester,
  ) async {
    // Keep the leading/trailing collapse checks together so the same setup
    // proves the action slot stays anchored on both sides.
    // ignore: halstead-volume, source-lines-of-code, maintainability-index
    Future<void> verify({required bool collapseOnTrailing}) async {
      const tabsKey = ValueKey('tabs');
      const collapseKey = ValueKey('collapse-button');
      const otherKey = ValueKey('other-button');
      const firstTabKey = ValueKey('first-tab');
      const contentKey = ValueKey('content');
      var collapsed = false;
      var otherTaps = 0;

      // The widget tree is intentionally inline so callback routing, collapsed
      // sizing, and slot placement stay visible in one assertion setup.
      // ignore: halstead-volume, source-lines-of-code
      Widget buildTabs() {
        const collapseButton = TabsActionButton(
          key: collapseKey,
          action: TabsActionButtonAction.toggleCollapse,
          icon: Icons.unfold_less,
        );
        final otherButton = TabsActionButton(
          key: otherKey,
          onPressed: () => otherTaps++,
          icon: Icons.more_horiz,
        );

        return MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  height: collapsed ? 50 : 160,
                  child: Tabs(
                    key: tabsKey,
                    collapsed: collapsed,
                    onCollapsedChanged: (value) {
                      setState(() {
                        collapsed = value;
                      });
                    },
                    tabLeadingButtons: [
                      collapseOnTrailing ? otherButton : collapseButton,
                    ],
                    tabTrailingButtons: [
                      collapseOnTrailing ? collapseButton : otherButton,
                    ],
                    borderRadius: BorderRadius.zero,
                    tabBorderRadius: BorderRadius.zero,
                    enableFeedback: false,
                    tabs: const [
                      SizedBox.expand(key: firstTabKey),
                      SizedBox.expand(),
                    ],
                    child: const SizedBox.expand(key: contentKey),
                  ),
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildTabs());
      expect(tester.getSize(find.byKey(collapseKey)), const Size.square(50));
      expect(tester.getSize(find.byKey(otherKey)), const Size.square(50));

      await tester.tap(find.byKey(collapseKey));
      await tester.pumpAndSettle();

      final tabsRect = tester.getRect(find.byKey(tabsKey));
      final collapseRect = tester.getRect(find.byKey(collapseKey));
      expect(collapsed, isTrue);
      expect(tabsRect.size, const Size(300, 50));
      expect(tester.getSize(find.byKey(otherKey)), Size.zero);
      expect(tester.getSize(find.byKey(firstTabKey)), Size.zero);
      expect(tester.getSize(find.byKey(contentKey)), Size.zero);
      expect(otherTaps, 0);

      expect(collapseRect.top, tabsRect.top);
      expect(collapseRect.bottom, tabsRect.bottom);
      if (collapseOnTrailing) {
        expect(collapseRect.right, tabsRect.right);
      } else {
        expect(collapseRect.left, tabsRect.left);
      }

      await tester.tap(find.byKey(collapseKey));
      await tester.pumpAndSettle();

      expect(collapsed, isFalse);
      expect(tester.getSize(find.byKey(otherKey)), const Size.square(50));
    }

    await verify(collapseOnTrailing: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await verify(collapseOnTrailing: true);
  });
}
