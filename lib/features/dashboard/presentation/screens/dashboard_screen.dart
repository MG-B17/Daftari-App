import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../cubit/dashboard_cubit.dart';
import '../widgets/dashboard_body.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<DashboardCubit>().refreshIfDayChanged());
    }
  }

  Future<void> _refresh() async {
    final cubit = context.read<DashboardCubit>();
    final completed = Completer<void>();
    // refresh() replaces the watch; wait for its first result, not just listen().
    final subscription = cubit.stream.listen(
      (state) {
        if (!state.loading && !completed.isCompleted) completed.complete();
      },
      onDone: () {
        if (!completed.isCompleted) completed.complete();
      },
    );
    try {
      await cubit.refresh();
      await completed.future;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.dashboardTitle,
    subtitle: context.l10n.dashboardSubtitle,
    padding: EdgeInsets.zero,
    actions: [
      IconButton(
        key: const ValueKey('dashboard-search'),
        tooltip: context.l10n.searchTitle,
        onPressed: () => context.pushNamed(AppRoutes.searchName),
        icon: const Icon(Icons.search),
      ),
    ],
    body: BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) =>
          DashboardBody(state: state, onRefresh: _refresh),
    ),
  );
}
