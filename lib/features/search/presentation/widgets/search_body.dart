import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/animation/staggered_list_item.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../../customers/presentation/customer_error_message.dart';
import '../../../customers/presentation/widgets/customer_list_card.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import 'search_illustration_state.dart';

class SearchBody extends StatefulWidget {
  const SearchBody({super.key});

  @override
  State<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<SearchBody> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<SearchCubit>().state.query,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearQuery() {
    _controller.clear();
    context.read<SearchCubit>().clearQuery();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        final results = state.results;
        return Column(
          children: [
            Padding(
              padding: AppSpacing.pagePadding,
              child: TextField(
                key: const ValueKey('search-input'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: context.read<SearchCubit>().setQuery,
                decoration: InputDecoration(
                  hintText: l10n.customersSearch,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('search-clear'),
                          tooltip: l10n.searchClear,
                          onPressed: _clearQuery,
                          icon: const Icon(Icons.close),
                        ),
                  fillColor: context.colorScheme.surface,
                ),
              ),
            ),
            Expanded(
              child: state.loading
                  ? const DaftariLoading.screen()
                  : state.failure != null
                  ? Center(
                      child: AppErrorState(
                        message: customerErrorMessage(
                          context,
                          state.failure!.errorCode,
                        ),
                        onRetry: () => context.read<SearchCubit>().load(),
                      ),
                    )
                  : !state.hasQuery
                  ? SearchIllustrationState(
                      key: const ValueKey('search-empty-state'),
                      title: l10n.searchEmptyTitle,
                      message: l10n.searchEmptyMessage,
                      illustrationLabel: l10n.searchIllustrationLabel,
                      staticIcon: Icons.search_rounded,
                    )
                  : results.isEmpty
                  ? SearchIllustrationState(
                      key: const ValueKey('search-no-results'),
                      title: l10n.customersNoResults,
                      message: l10n.searchNoResultsHint,
                      illustrationLabel: l10n.searchNoResultsIllustrationLabel,
                      staticIcon: Icons.search_off_rounded,
                    )
                  : ListView.separated(
                      key: const ValueKey('search-results-list'),
                      padding: AppSpacing.pagePadding,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => StaggeredListItem(
                        key: ValueKey(results[index].id),
                        index: index,
                        child: CustomerListCard(customer: results[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
