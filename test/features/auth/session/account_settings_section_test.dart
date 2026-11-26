import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/auth/widgets/account_settings_section.dart';
import 'package:daftariapp/features/auth/widgets/ledger_link_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth_test_fakes.dart';

const _widgetUser = AuthUser(
  id: 'user-a',
  email: 'shop@example.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

void main() {
  testWidgets('account section shows signed-out and signed-in states', (
    tester,
  ) async {
    final signedOutBackend = FakeAuthBackend();
    final signedOutCubit = await createInitializedSessionCubit(
      signedOutBackend,
    );
    addTearDown(() async {
      await signedOutCubit.close();
      await signedOutBackend.dispose();
    });

    await pumpAuthScreen(
      tester,
      const Scaffold(body: AccountSettingsSection()),
      providers: [BlocProvider<AuthSessionCubit>.value(value: signedOutCubit)],
    );
    final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

    expect(find.text(l10n.authAccountSignedOutTitle), findsOneWidget);
    expect(find.text(l10n.authAccountSignedOutDescription), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, l10n.authAccountSignIn),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, l10n.authAccountCreate),
      findsOneWidget,
    );

    final signedInBackend = FakeAuthBackend(
      currentUser: _widgetUser,
      linkedUserId: _widgetUser.id,
    );
    final signedInCubit = await createInitializedSessionCubit(signedInBackend);
    addTearDown(() async {
      await signedInCubit.close();
      await signedInBackend.dispose();
    });

    await pumpAuthScreen(
      tester,
      const Scaffold(body: AccountSettingsSection()),
      providers: [BlocProvider<AuthSessionCubit>.value(value: signedInCubit)],
    );
    final signedInL10n = tester
        .element(find.byType(AccountSettingsSection))
        .l10n;

    expect(find.text(signedInL10n.authAccountLinkedTitle), findsOneWidget);
    expect(
      find.text(signedInL10n.authAccountLinkedTo('shop@example.com')),
      findsOneWidget,
    );
    expect(find.text('Al-Amana Grocery'), findsOneWidget);
    expect(find.text(signedInL10n.authAccountVerified), findsOneWidget);
    expect(find.text(signedInL10n.authAccountSignOut), findsOneWidget);
    expect(l10n.authAccountTitle, signedInL10n.authAccountTitle);
  });

  testWidgets('signing out asks for confirmation and preserves local data', (
    tester,
  ) async {
    final backend = FakeAuthBackend(
      currentUser: _widgetUser,
      linkedUserId: _widgetUser.id,
    );
    final cubit = await createInitializedSessionCubit(backend);
    addTearDown(() async {
      await cubit.close();
      await backend.dispose();
    });

    await pumpAuthScreen(
      tester,
      const Scaffold(body: AccountSettingsSection()),
      providers: [BlocProvider<AuthSessionCubit>.value(value: cubit)],
    );
    final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

    await tester.tap(find.text(l10n.authAccountSignOut));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.authAccountSignOutMessage),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(AppButton, l10n.authAccountSignOut),
      ),
    );
    await tester.pumpAndSettle();

    expect(backend.signOutCalls, 1);
    expect(backend.linkedUserId, _widgetUser.id);
    expect(cubit.state.status, AuthStatus.unauthenticated);
    expect(find.text(l10n.authSignedOutSuccess), findsOneWidget);
  });

  testWidgets('ledger link confirmation returns the user decision', (
    tester,
  ) async {
    bool? decision;
    await pumpAuthScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'open',
              onPressed: () async {
                decision = await LedgerLinkConfirmationDialog.show(context);
              },
            ),
          ),
        ),
      ),
    );
    final l10n = tester.element(find.text('open')).l10n;

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.authLinkDialogTitle), findsOneWidget);
    expect(find.text(l10n.authLinkDialogMessage), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(decision, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(AppButton, l10n.authLinkDialogConfirm),
      ),
    );
    await tester.pumpAndSettle();
    expect(decision, isTrue);
  });
}
