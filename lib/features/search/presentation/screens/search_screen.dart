import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/search_body.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.searchTitle,
    padding: EdgeInsets.zero,
    body: const SearchBody(),
  );
}
