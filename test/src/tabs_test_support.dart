import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabs/tabs.dart';

class PointerAxisModifierScrollBehavior extends MaterialScrollBehavior {
  const PointerAxisModifierScrollBehavior(this._pointerAxisModifiers);

  final Set<LogicalKeyboardKey> _pointerAxisModifiers;

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers => _pointerAxisModifiers;
}

class RecordingPaintingContext extends PaintingContext {
  RecordingPaintingContext() : super(ContainerLayer(), Rect.largest);

  final _childOffsets = <Offset>[];

  List<Offset> takeChildOffsets() => _childOffsets;

  @override
  void paintChild(RenderObject child, Offset offset) {
    _childOffsets.add(offset);
  }
}

Future<Color> readBoundaryPixel({
  required WidgetTester tester,
  required Finder boundary,
  required Offset position,
}) async {
  final renderObject = tester.renderObject<RenderRepaintBoundary>(boundary);
  final color = await tester.runAsync(() async {
    final image = await renderObject.toImage();
    final byteData = await image.toByteData();
    image.dispose();
    if (byteData == null) {
      throw StateError('Unable to read repaint boundary pixels.');
    }

    final pixels = byteData.buffer.asUint8List();
    final pixelOffset =
        (position.dy.toInt() * image.width + position.dx.toInt()) * 4;

    return Color.fromARGB(
      pixels[pixelOffset + 3],
      pixels[pixelOffset],
      pixels[pixelOffset + 1],
      pixels[pixelOffset + 2],
    );
  });

  if (color == null) {
    throw StateError('Unable to capture repaint boundary pixel.');
  }

  return color;
}

Future<Color> readTabsBackgroundPixel({
  required WidgetTester tester,
  required GlobalKey boundaryKey,
}) {
  return readBoundaryPixel(
    tester: tester,
    boundary: find.byKey(boundaryKey),
    position: const Offset(24, 72),
  );
}

int redOf(Color color) => (color.toARGB32() >> 16) & 0xff;

int greenOf(Color color) => (color.toARGB32() >> 8) & 0xff;

int blueOf(Color color) => color.toARGB32() & 0xff;

double textTransformScale(String text) {
  final transform = find
      .ancestor(of: find.text(text), matching: find.byType(Transform))
      .evaluate()
      .map((element) => element.widget)
      .whereType<Transform>()
      .single;

  return transform.transform.getMaxScaleOnAxis();
}

class ControlledTabsTestApp extends StatelessWidget {
  const ControlledTabsTestApp({
    required TabController controller,
    required List<Widget> tabs,
    required TabEdge tabEdge,
    super.key,
    double tabExtent = 50,
    double tabMinLength = 0,
  }) : _controller = controller,
       _tabs = tabs,
       _tabEdge = tabEdge,
       _tabExtent = tabExtent,
       _tabMinLength = tabMinLength;

  final TabController _controller;
  final List<Widget> _tabs;
  final TabEdge _tabEdge;
  final double _tabExtent;
  final double _tabMinLength;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Center(
        child: SizedBox(
          width: 240,
          height: 160,
          child: Tabs(
            controller: _controller,
            tabs: _tabs,
            tabEdge: _tabEdge,
            tabExtent: _tabExtent,
            tabMinLength: _tabMinLength,
            borderRadius: BorderRadius.zero,
            tabBorderRadius: BorderRadius.zero,
            enableFeedback: false,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

Future<void> tapEdgeTab({
  required WidgetTester tester,
  required TabController controller,
  required TabEdge tabEdge,
  required Offset tapOffset,
}) async {
  const tabsKey = ValueKey('edge-hit-test-tabs');
  var contentTapCount = 0;

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
            duration: Duration.zero,
            tabEdge: tabEdge,
            tabExtent: 24,
            tabs: const [Text('One'), Text('Two'), Text('Three')],
            borderRadius: BorderRadius.zero,
            tabBorderRadius: BorderRadius.zero,
            enableFeedback: false,
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
    ),
  );

  await tester.tapAt(tester.getTopLeft(find.byKey(tabsKey)) + tapOffset);
  await tester.pumpAndSettle();

  expect(contentTapCount, 0);
}

Future<void> focusTabs({
  required WidgetTester tester,
  required BuildContext focusContext,
}) async {
  Focus.of(focusContext).requestFocus();
  await tester.pump();
}
