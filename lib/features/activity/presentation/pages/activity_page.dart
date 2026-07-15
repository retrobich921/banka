import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/activity_service.dart';

/// Экран «Активность»: кто лайкнул/прокомментировал твои банки.
/// Открытие экрана помечает всё просмотренным (гасит бейдж на колокольчике).
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<ActivityItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthBloc>().state.user?.id;
    if (userId == null) return;
    try {
      final items = await sl<ActivityService>().fetchActivity(userId);
      await sl<ActivityService>().markSeen();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить активность');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Активность')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _CenteredText(text: _error!);
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const _CenteredText(
        text:
            'Пока тихо.\nКогда кто-то лайкнет или прокомментирует '
            'твои банки — увидишь это здесь.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.outline),
        itemBuilder: (context, i) => _ActivityTile(item: items[i]),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLike = item.type == ActivityType.like;
    return ListTile(
      onTap: () => context.pushNamed(
        AppRoutes.postDetailName,
        pathParameters: {'id': item.postId},
      ),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.surfaceVariant,
        backgroundImage:
            (item.userPhotoUrl != null && item.userPhotoUrl!.isNotEmpty)
            ? NetworkImage(item.userPhotoUrl!)
            : null,
        child: (item.userPhotoUrl == null || item.userPhotoUrl!.isEmpty)
            ? Icon(
                isLike ? Icons.favorite : Icons.chat_bubble_outline,
                size: 16,
                color: isLike ? AppColors.primary : AppColors.onSurfaceMuted,
              )
            : null,
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: item.userName.isEmpty ? 'Кто-то' : item.userName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: isLike
                  ? ' лайкнул(а) «${item.postName}»'
                  : ' прокомментировал(а) «${item.postName}»',
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLike && (item.text?.isNotEmpty ?? false))
            Text(
              item.text!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          if (item.createdAt != null)
            Text(
              DateFormat('d MMM, HH:mm', 'ru_RU').format(item.createdAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceFaint,
              ),
            ),
        ],
      ),
      trailing: Icon(
        isLike ? Icons.favorite : Icons.chat_bubble_outline,
        size: 18,
        color: isLike ? AppColors.primary : AppColors.onSurfaceMuted,
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
