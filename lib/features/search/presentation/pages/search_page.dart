import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../domain/entities/search_filters.dart';
import '../bloc/search_bloc.dart';
import '../widgets/filters_sheet.dart';

/// Экран поиска постов.
///
/// `SearchBloc` живёт пока экран открыт. На вход — текстовое поле
/// (debounce 300 ms) и кнопка фильтров (открывает bottom-sheet). Карточки
/// результатов — те же `PostCard`, что и в ленте, переход — на детальный
/// экран `/posts/:id`.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchBloc>(
      create: (_) => sl<SearchBloc>(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Поиск по названию, бренду, тегу…',
            border: InputBorder.none,
          ),
          onChanged: (v) =>
              context.read<SearchBloc>().add(SearchQueryChanged(v)),
        ),
        actions: [
          BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (a, b) => a.filters != b.filters,
            builder: (context, state) {
              final hasFilters = state.filters.hasAny;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Фильтры',
                    icon: const Icon(Icons.tune),
                    onPressed: () => _openFilters(context, state.filters),
                  ),
                  if (hasFilters)
                    const Positioned(right: 10, top: 10, child: _Dot()),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          if (state.status == SearchStatus.idle && !state.hasInput) {
            return const _Hint(
              text:
                  'Введи минимум 2 символа\nили выбери фильтры — найдём подходящие банки.',
            );
          }
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.hasError) {
            return _Hint(
              text: state.errorMessage ?? 'Что-то пошло не так',
              color: AppColors.error,
            );
          }
          if (state.isEmpty) {
            return const _Hint(text: 'Ничего не найдено по вашему запросу.');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: state.results.length,
            itemBuilder: (_, i) {
              final post = state.results[i];
              return PostCard(
                post: post,
                onTap: () => context.pushNamed(
                  AppRoutes.postDetailName,
                  pathParameters: {'id': post.id},
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, SearchFilters current) async {
    final bloc = context.read<SearchBloc>();
    final updated = await showModalBottomSheet<SearchFilters>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => FiltersSheet(initial: current),
    );
    if (updated != null) {
      bloc.add(SearchFiltersChanged(updated));
    }
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color ?? AppColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
    );
  }
}
