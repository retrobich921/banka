import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/approve_join_request.dart';
import '../../domain/usecases/reject_join_request.dart';
import '../../domain/usecases/watch_join_requests.dart';

/// Страница запросов на вступление в закрытую группу.
/// Доступна только владельцу группы.
class JoinRequestsPage extends StatelessWidget {
  const JoinRequestsPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Запросы на вступление')),
      body: StreamBuilder(
        stream: sl<WatchJoinRequests>().call(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = result.fold<List<JoinRequest>>(
            (_) => const <JoinRequest>[],
            (list) => list,
          );
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Нет запросов на вступление',
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _JoinRequestTile(request: request, groupId: groupId);
            },
          );
        },
      ),
    );
  }
}

class _JoinRequestTile extends StatefulWidget {
  const _JoinRequestTile({required this.request, required this.groupId});

  final JoinRequest request;
  final String groupId;

  @override
  State<_JoinRequestTile> createState() => _JoinRequestTileState();
}

class _JoinRequestTileState extends State<_JoinRequestTile> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final result = await sl<ApproveJoinRequest>().call(
        ApproveJoinRequestParams(
          groupId: widget.groupId,
          userId: widget.request.userId,
        ),
      );
      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message ?? 'Не удалось одобрить запрос'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        },
        (_) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пользователь добавлен в группу'),
              backgroundColor: Colors.green,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _reject() async {
    setState(() => _isProcessing = true);
    try {
      final result = await sl<RejectJoinRequest>().call(
        RejectJoinRequestParams(
          groupId: widget.groupId,
          userId: widget.request.userId,
        ),
      );
      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message ?? 'Не удалось отклонить запрос'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        },
        (_) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запрос отклонен'),
              backgroundColor: Colors.orange,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: const CircleAvatar(
        backgroundColor: AppColors.surfaceVariant,
        child: Icon(Icons.person_outline, color: AppColors.onSurfaceMuted),
      ),
      title: Text(
        widget.request.displayName.isNotEmpty
            ? widget.request.displayName
            : 'ID: ${widget.request.userId.substring(0, 8)}...',
      ),
      subtitle: Text(
        _formatDate(widget.request.requestedAt),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
      ),
      trailing: _isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Одобрить',
                  onPressed: _approve,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Отклонить',
                  onPressed: _reject,
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${date.day}.${date.month}.${date.year}';
  }
}
