import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/src/render/tabs_frame.dart';
import 'package:tabs/tabs.dart';

Future<void> _pumpExpandableSemanticsTabs(WidgetTester tester) {
  var collapsed = true;

  return tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          return Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 300,
                maxWidth: 300,
                maxHeight: 160,
              ),
              child: Tabs(
                collapseDuration: const Duration(seconds: 1),
                curve: Curves.linear,
                collapsed: collapsed,
                onCollapsedChanged: (value) =>
                    setState(() => collapsed = value),
                tabTrailingButtons: const [
                  TabsActionButton(
                    action: TabsActionButtonAction.toggleCollapse,
                    icon: Icons.unfold_more,
                    semanticLabel: 'Toggle tabs',
                  ),
                ],
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                tabs: const [Text('Hidden tab')],
                children: const [Text('Hidden content')],
              ),
            ),
          );
        },
      ),
    ),
  );
}

List<SemanticsData> _semanticsTraversalData(WidgetTester tester) {
  return [
    for (final node in tester.semantics.simulatedAccessibilityTraversal())
      node.getSemanticsData(),
  ];
}

// Semantics coverage keeps wrapper and per-tab accessibility flows together so
// index values, actions, and caller-provided semantics stay auditable as one API.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets('render tab count updates layout and wrapper semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const tabsKey = ValueKey('tabs');

    Widget buildTabs({required int tabCount}) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            height: 160,
            child: Tabs(
              key: tabsKey,
              tabs: List<Widget>.generate(
                tabCount,
                (index) => Text('Tab $index'),
              ),
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              children: List<Widget>.generate(
                tabCount,
                (index) => Text('Content $index'),
              ),
            ),
          ),
        ),
      );
    }

    RenderTabFrame renderFrame() =>
        tester.renderObject<RenderTabFrame>(find.byType(TabFrame));

    List<double> tabOffsetSpacings() {
      final frame = renderFrame();
      final offsets = <Offset>[];
      final content = frame.firstChild;
      if (content == null) {
        throw StateError('Expected the content child to be laid out.');
      }

      for (
        var child = frame.childAfter(content);
        child != null;
        child = frame.childAfter(child)
      ) {
        offsets.add((child.parentData as TabFrameParentData).offset);
      }

      return [
        for (var index = 1; index < offsets.length; index++)
          offsets[index].dx - offsets[index - 1].dx,
      ];
    }

    try {
      await tester.pumpWidget(buildTabs(tabCount: 2));
      final initialRenderFrame = renderFrame();

      expect(initialRenderFrame.tabCount, 2);
      expect(tabOffsetSpacings(), [120]);
      expect(
        tester.getSemantics(find.byType(TabFrame)).value,
        'Viewing tab 1 of 2',
      );

      await tester.pumpWidget(buildTabs(tabCount: 4));

      expect(renderFrame(), same(initialRenderFrame));
      expect(renderFrame().tabCount, 4);
      expect(tabOffsetSpacings(), [60, 60, 60]);
      expect(
        tester.getSemantics(find.byType(TabFrame)).value,
        'Viewing tab 1 of 4',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wrapper semantics use high-level customization and defaults', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    final semantics = tester.ensureSemantics();
    final builderCalls = <(int, int)>[];

    Widget buildTabs({
      String? semanticsLabel,
      String? semanticsHint,
      String Function(int index, int count)? semanticsValueBuilder,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 160,
            child: Tabs(
              controller: controller,
              semanticsLabel: semanticsLabel,
              semanticsHint: semanticsHint,
              semanticsValueBuilder: semanticsValueBuilder,
              tabs: const [Text('One'), Text('Two'), Text('Three')],
              borderRadius: BorderRadius.zero,
              tabBorderRadius: BorderRadius.zero,
              enableFeedback: false,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    String customValue(int index, int count) {
      builderCalls.add((index, count));
      return 'Index $index of $count';
    }

    try {
      await tester.pumpWidget(
        buildTabs(
          semanticsLabel: 'Custom tab wrapper',
          semanticsHint: 'Choose another custom tab',
          semanticsValueBuilder: customValue,
        ),
      );

      var node = tester.getSemantics(find.byType(TabFrame));
      expect(node.label, 'Custom tab wrapper');
      expect(node.hint, 'Choose another custom tab');
      expect(node.value, 'Index 1 of 3');
      expect(node.decreasedValue, 'Index 0 of 3');
      expect(node.increasedValue, 'Index 2 of 3');
      expect(builderCalls, containsAllInOrder([(1, 3), (0, 3), (2, 3)]));

      builderCalls.clear();
      controller.animateTo(0, duration: Duration.zero);
      await tester.pumpAndSettle();

      node = tester.getSemantics(find.byType(TabFrame));
      expect(node.value, 'Index 0 of 3');
      expect(node.decreasedValue, 'Index 0 of 3');
      expect(node.increasedValue, 'Index 1 of 3');
      expect(builderCalls, containsAllInOrder([(0, 3), (0, 3), (1, 3)]));

      builderCalls.clear();
      controller.animateTo(2, duration: Duration.zero);
      await tester.pumpAndSettle();

      node = tester.getSemantics(find.byType(TabFrame));
      expect(node.value, 'Index 2 of 3');
      expect(node.decreasedValue, 'Index 1 of 3');
      expect(node.increasedValue, 'Index 2 of 3');
      expect(builderCalls, containsAllInOrder([(2, 3), (1, 3), (2, 3)]));

      await tester.pumpWidget(buildTabs());

      node = tester.getSemantics(find.byType(TabFrame));
      expect(node.label, 'Tab view');
      expect(node.hint, 'Increase or decrease to view a different tab');
      expect(node.value, 'Viewing tab 3 of 3');
      expect(node.decreasedValue, 'Viewing tab 2 of 3');
      expect(node.increasedValue, 'Viewing tab 3 of 3');
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('default semantics actions use configured animated selection', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    final semantics = tester.ensureSemantics();

    Future<void> performAction(SemanticsAction action) async {
      final node = tester.getSemantics(find.byType(TabFrame));
      final semanticsOwner = node.owner;
      expect(semanticsOwner, isNotNull);
      semanticsOwner?.performAction(node.id, action);
      await tester.pump();
    }

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

      await performAction(SemanticsAction.increase);
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.animation?.value, moreOrLessEquals(1.5));

      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.index, 2);
      expect(controller.animation?.value, 2);

      await performAction(SemanticsAction.decrease);
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.animation?.value, moreOrLessEquals(1.5));

      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.index, 1);
      expect(controller.animation?.value, 1);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('per-tab semantics expose state and tap selection', (
    tester,
  ) async {
    final controller = TabController(length: 3, initialIndex: 1, vsync: tester);
    final semantics = tester.ensureSemantics();

    SemanticsNode tabNode(String label) =>
        tester.getSemantics(find.text(label));
    bool isButton(SemanticsNode node) => node.flagsCollection.isButton;
    bool isSelected(SemanticsNode node) =>
        node.flagsCollection.isSelected == Tristate.isTrue;
    bool hasEnabledState(SemanticsNode node) =>
        node.flagsCollection.isEnabled != Tristate.none;
    bool isEnabled(SemanticsNode node) =>
        node.flagsCollection.isEnabled == Tristate.isTrue;

    Future<void> performTabTap(String label) async {
      final node = tabNode(label);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner?.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
    }

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
                duration: Duration.zero,
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

      var firstTab = tabNode('One');
      final secondTab = tabNode('Two');

      expect(isButton(firstTab), isTrue);
      expect(hasEnabledState(firstTab), isTrue);
      expect(isEnabled(firstTab), isTrue);
      expect(isSelected(firstTab), isFalse);
      expect(isButton(secondTab), isTrue);
      expect(isSelected(secondTab), isTrue);

      await performTabTap('Three');

      expect(controller.index, 2);
      expect(isSelected(tabNode('Three')), isTrue);
      expect(isSelected(tabNode('Two')), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: Tabs(
                controller: controller,
                duration: Duration.zero,
                enabled: false,
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

      firstTab = tabNode('One');
      expect(isButton(firstTab), isTrue);
      expect(hasEnabledState(firstTab), isTrue);
      expect(isEnabled(firstTab), isFalse);
      expect(
        firstTab.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      firstTab.owner?.performAction(firstTab.id, SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(controller.index, 2);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('per-tab semantics preserve caller-provided tab semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 160,
              child: Tabs(
                tabs: [
                  const Text('Plain label'),
                  Semantics(
                    label: 'Caller custom label',
                    hint: 'Caller custom hint',
                    child: const Text('Visual label'),
                  ),
                ],
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                children: const [Text('First content'), Text('Second content')],
              ),
            ),
          ),
        ),
      );

      final plainNode = tester.getSemantics(find.text('Plain label'));
      expect(plainNode.label, 'Plain label');
      expect(plainNode.flagsCollection.isButton, isTrue);

      final customNode = tester.getSemantics(find.text('Visual label'));
      expect(customNode.label, contains('Caller custom label'));
      expect(customNode.hint, 'Caller custom hint');
      expect(customNode.flagsCollection.isButton, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('collapsed tabs expose only the collapse action semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var collapsedValue = true;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 50,
              child: Tabs(
                collapsed: true,
                onCollapsedChanged: (value) {
                  collapsedValue = value;
                },
                tabTrailingButtons: const [
                  TabsActionButton(
                    action: TabsActionButtonAction.toggleCollapse,
                    icon: Icons.unfold_more,
                    semanticLabel: 'Expand tabs',
                  ),
                ],
                borderRadius: BorderRadius.zero,
                tabBorderRadius: BorderRadius.zero,
                enableFeedback: false,
                tabs: const [Text('Hidden tab')],
                children: const [Text('Hidden content')],
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byIcon(Icons.unfold_more)).label,
        'Expand tabs',
      );
      expect(collapsedValue, isTrue);
      final traversal = tester.semantics.simulatedAccessibilityTraversal();
      final traversalData = [
        for (final node in traversal) node.getSemanticsData(),
      ];

      expect(traversalData.map((data) => data.label), contains('Expand tabs'));
      expect(
        traversalData.map((data) => data.label),
        isNot(contains('Hidden tab')),
      );
      expect(
        traversalData.map((data) => data.label),
        isNot(contains('Hidden content')),
      );
      expect(
        traversalData.map((data) => data.label),
        isNot(contains('Tab view')),
      );
      expect(
        traversalData.map((data) => data.value),
        isNot(contains('Viewing tab 1 of 1')),
      );
      expect(
        traversalData.any((data) => data.hasAction(SemanticsAction.increase)),
        isFalse,
      );
      expect(
        traversalData.any((data) => data.hasAction(SemanticsAction.decrease)),
        isFalse,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('expanding tabs expose hidden children after fade-in starts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await _pumpExpandableSemanticsTabs(tester);

      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      var labels = _semanticsTraversalData(tester).map((data) => data.label);
      expect(labels, contains('Toggle tabs'));
      expect(labels, isNot(contains('Hidden tab')));
      expect(labels.any((label) => label.contains('Hidden content')), isFalse);

      await tester.pump(const Duration(milliseconds: 1));

      labels = _semanticsTraversalData(tester).map((data) => data.label);
      expect(labels, contains('Hidden tab'));
      expect(labels.any((label) => label.contains('Hidden content')), isTrue);
      expect(labels.any((label) => label.contains('Tab view')), isTrue);
    } finally {
      semantics.dispose();
    }
  });
}
