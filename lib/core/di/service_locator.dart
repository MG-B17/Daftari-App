import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  if (!sl.isRegistered<GoRouter>()) {
    sl.registerLazySingleton<GoRouter>(
      AppRouter.create,
      dispose: (router) => router.dispose(),
    );
  }
}
