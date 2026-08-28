import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/tabs.dart';

// Keep public root-import smoke and boundary checks together so compatibility
// and invalid-configuration behavior stay auditable from one public call site.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets('renders supported public API from the package root import', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: tester);
    var customButtonTaps = 0;
    var collapseFallbackTaps = 0;
    var publicCollapsed = false;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 240,
            height: 160,
            child: TabsFocus(
              controller: controller,
              tabAxis: Axis.vertical,
              child: Tabs(
                controller: controller,
                tabEdge: TabEdge.right,
                collapseDuration: Duration.zero,
                collapsed: publicCollapsed,
                onCollapsedChanged: (value) {
                  publicCollapsed = value;
                },
                semanticsLabel: 'Public tabs',
                semanticsHint: 'Change the public tab',
                semanticsValueBuilder: (index, count) =>
                    'Public tab ${index + 1} of $count',
                tabTrailingButtons: [
                  TabsActionButton(
                    icon: Icons.more_horiz,
                    onPressed: () => customButtonTaps++,
                  ),
                  TabsActionButton(
                    action: TabsActionButtonAction.toggleCollapse,
                    icon: Icons.unfold_less,
                    onPressed: () => collapseFallbackTaps++,
                  ),
                ],
                tabs: const [Text('First tab'), Text('Second tab')],
                children: const [Text('First content'), Text('Second content')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('First tab'), findsOneWidget);
      expect(find.text('First content'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(customButtonTaps, 1);

      await tester.tap(find.byIcon(Icons.unfold_less));
      await tester.pumpAndSettle();
      expect(publicCollapsed, isTrue);
      expect(collapseFallbackTaps, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('disables public collapse action without change callback', (
    tester,
  ) async {
    var fallbackTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 160,
          child: Tabs(
            tabTrailingButtons: [
              TabsActionButton(
                action: TabsActionButtonAction.toggleCollapse,
                icon: Icons.unfold_less,
                onPressed: () => fallbackTaps++,
              ),
            ],
            tabs: const [Text('First tab')],
            child: const Text('First content'),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.unfold_less));
    await tester.pumpAndSettle();

    expect(fallbackTaps, 0);
  });

  testWidgets('rejects invalid public collapse action configurations', (
    tester,
  ) async {
    var collapsedChangeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Tabs(
          collapsed: true,
          tabs: const [Text('First tab')],
          child: const Text('First content'),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('A collapsed Tabs must have exactly one collapse toggle'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Tabs(
          onCollapsedChanged: (_) {
            collapsedChangeCalls++;
          },
          tabLeadingButtons: const [
            TabsActionButton(
              action: TabsActionButtonAction.toggleCollapse,
              icon: Icons.unfold_less,
            ),
          ],
          tabTrailingButtons: const [
            TabsActionButton(
              action: TabsActionButtonAction.toggleCollapse,
              icon: Icons.unfold_less,
            ),
          ],
          tabs: const [Text('First tab')],
          child: const Text('First content'),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('Provide at most one collapse toggle action button'),
      ),
    );
    expect(collapsedChangeCalls, 0);
  });

  test('rejects empty tabs at the public constructor boundary', () {
    expect(
      () => Tabs(tabs: const [], child: const SizedBox.expand()),
      throwsAssertionError,
    );
  });

  test('defaults collapse animation to the public collapse duration', () {
    final tabs = Tabs(
      tabs: const [Text('Tab')],
      child: const SizedBox.expand(),
    );

    expect(tabs.collapseDuration, const Duration(milliseconds: 220));
  });

  test('accepts a uniform border for the joined active frame', () {
    const border = Border.fromBorderSide(
      BorderSide(color: Colors.blue, width: 2),
    );
    final tabs = Tabs(
      border: border,
      tabs: const [Text('Tab')],
      child: const SizedBox.expand(),
    );

    expect(tabs.border, border);
  });

  testWidgets('rejects a non-uniform active frame border', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Tabs(
          border: const Border(top: BorderSide(color: Colors.blue)),
          tabs: const [Text('Tab')],
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('border must use the same BorderSide'),
      ),
    );
  });

  testWidgets('renders tab content from the tabs package import', (
    tester,
  ) async {
    const tabWidgets = <Widget>[Text('First tab'), Text('Second tab')];
    const contentWidgets = <Widget>[
      Text('First content'),
      Text('Second content'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 160,
          child: Tabs(tabs: tabWidgets, children: contentWidgets),
        ),
      ),
    );

    expect(find.text('First tab'), findsOneWidget);
    expect(find.text('First content'), findsOneWidget);
  });
}
