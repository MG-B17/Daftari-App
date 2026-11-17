import 'package:daftariapp/core/animation/screen_transition_animation/app_page_transition.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/bottom_sheet_transition_page.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/fade_transition_page.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/scale_transition_page.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/slide_right_transition_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pages = <String, AppPageTransition<void> Function(Widget)>{
    'fade': (child) => FadeTransitionPage(child: child),
    'scale': (child) => ScaleTransitionPage(child: child),
    'slide': (child) => SlideRightTransitionPage(child: child),
    'bottom': (child) => BottomSheetTransitionPage(child: child),
  };

  for (final entry in pages.entries) {
    for (final reduced in [false, true]) {
      testWidgets('${entry.key} settles with reduced motion $reduced', (
        tester,
      ) async {
        final page = entry.value(const Text('destination'));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    Navigator.of(context).push(page.createRoute(context)),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('destination'), findsOneWidget);
        final child = const SizedBox();
        final result = page.transitionsBuilder(
          tester.element(find.text('destination')),
          const AlwaysStoppedAnimation(.5),
          const AlwaysStoppedAnimation(0),
          child,
        );
        expect(identical(result, child), reduced);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
