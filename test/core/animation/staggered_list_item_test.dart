import 'package:daftariapp/core/animation/staggered_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stagger is capped and animations settle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            StaggeredListItem(index: 0, child: Text('first')),
            StaggeredListItem(index: 2, child: Text('second')),
            StaggeredListItem(index: 1000, child: Text('last')),
          ],
        ),
      ),
    );
    double opacity(int index) => tester
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

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(0), greaterThan(opacity(2)));
    expect(opacity(1000), 0);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(opacity(1000), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion displays the child immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StaggeredListItem(index: 1000, child: Text('visible')),
        ),
      ),
    );
    expect(find.text('visible'), findsOneWidget);
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
