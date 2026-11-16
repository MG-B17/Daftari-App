import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final completed in [false, true]) {
    testWidgets('initial route for onboardingCompleted=$completed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': completed,
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final router = AppRouter.create(localStorage: storage);
      await tester.pumpWidget(DaftariApp(router: router));
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/splash');
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        completed ? '/' : '/onboarding',
      );
      expect(
        find.byType(OnboardingScreen),
        completed ? findsNothing : findsOneWidget,
      );
      if (completed) {
        router.go('/onboarding');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }

  testWidgets('without storage the placeholder root remains available', (
    tester,
  ) async {
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/splash');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    router.go('/onboarding');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
