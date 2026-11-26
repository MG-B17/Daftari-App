import 'package:daftariapp/core/animation/staggered_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double opacity(WidgetTester tester, int index) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is StaggeredListItem && widget.index == index,
          ),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  Finder fadeFor(int index) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is StaggeredListItem && widget.index == index,
    ),
    matching: find.byType(FadeTransition),
  );

  testWidgets(
    'first row and overflow rows show immediately while subsequent rows stagger noticeably',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              StaggeredListItem(index: 0, child: Text('first')),
              StaggeredListItem(index: 1, child: Text('second')),
              StaggeredListItem(index: 3, child: Text('fourth')),
              StaggeredListItem(index: 6, child: Text('seventh')),
              StaggeredListItem(index: 1000, child: Text('scrolled')),
            ],
          ),
        ),
      );

      // First row and rows beyond the initial viewport stagger cap are immediately visible.
      expect(find.text('first'), findsOneWidget);
      expect(find.text('scrolled'), findsOneWidget);
      expect(fadeFor(0), findsNothing);
      expect(fadeFor(1000), findsNothing);

      // Subsequent rows animate with visible stagger progression.
      expect(fadeFor(1), findsOneWidget);
      expect(fadeFor(3), findsOneWidget);
      expect(fadeFor(6), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(opacity(tester, 1), greaterThan(opacity(tester, 3)));
      expect(opacity(tester, 3), greaterThan(opacity(tester, 6)));
      expect(opacity(tester, 6), 0);

      await tester.pumpAndSettle();
      expect(opacity(tester, 1), 1);
      expect(opacity(tester, 3), 1);
      expect(opacity(tester, 6), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('subsequent rows stay interactive throughout their entrance', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StaggeredListItem(
                index: 1,
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Tap me'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Tap me'));
    await tester.tap(find.text('Tap me'));
    expect(taps, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion displays every row immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Column(
            children: [
              StaggeredListItem(index: 0, child: Text('first')),
              StaggeredListItem(index: 2, child: Text('second')),
              StaggeredListItem(index: 6, child: Text('seventh')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('seventh'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StaggeredListItem),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });
}
