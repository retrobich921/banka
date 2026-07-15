import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/fetch_archived_posts.dart';
import '../../domain/usecases/set_post_archived.dart';
import '../widgets/post_card.dart';

/// Архив текущего пользователя: посты, скрытые из лент. Каждый можно
/// вернуть кнопкой — мягкая альтернатива удалению.
class ArchivedPostsPage extends StatefulWidget {
  const ArchivedPostsPage({super.key});

  @override
  State<ArchivedPostsPage> createState() => _ArchivedPostsPageState();
}

class _ArchivedPostsPageState extends State<ArchivedPostsPage> {
  List<Post>? _posts;
  String? _error;
  final _restoring = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthBloc>().state.user?.id;
    if (userId == null) return;
    final result = await sl<FetchArchivedPosts>()(userId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(
        () => _error = failure.message ?? 'Не удалось загрузить архив',
      ),
      (posts) => setState(() {
        _posts = posts;
        _error = null;
      }),
    );
  }

  Future<void> _restore(Post post) async {
    setState(() => _restoring.add(post.id));
    final result = await sl<SetPostArchived>()(
      SetPostArchivedParams(postId: post.id, archived: false),
    );
    if (!mounted) return;
    setState(() => _restoring.remove(post.id));
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Не удалось вернуть пост')),
      ),
      (_) {
        setState(() => _posts = _posts?.where((p) => p.id != post.id).toList());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Пост возвращён в ленту')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Архив')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _CenteredText(text: _error!);
    final posts = _posts;
    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return const _CenteredText(
        text:
            'Архив пуст.\nНа экране поста можно убрать его в архив '
            'вместо удаления — он спрячется из лент, но не потеряется.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final post = posts[i];
          final busy = _restoring.contains(post.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PostCard(
                post: post,
                onTap: () => context.pushNamed(
                  AppRoutes.postDetailName,
                  pathParameters: {'id': post.id},
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _restore(post),
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: Text(busy ? 'Возвращаем…' : 'Вернуть из архива'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CenteredText extends StatelessWidget {
  const _CenteredText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}
