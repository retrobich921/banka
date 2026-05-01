import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/like.dart';
import '../bloc/who_liked_bloc.dart';

/// Экран «Кто лайкнул пост». Подписан на стрим лайков, обновляется в
/// реальном времени.
class WhoLikedPage extends StatelessWidget {
  const WhoLikedPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WhoLikedBloc>(
      create: (_) =>
          sl<WhoLikedBloc>()..add(WhoLikedSubscribeRequested(postId)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Кто лайкнул')),
        body: BlocBuilder<WhoLikedBloc, WhoLikedState>(
          builder: (context, state) {
            if (state.status == WhoLikedStatus.error &&
                state.errorMessage != null) {
              return _CenteredText(text: state.errorMessage!);
            }
            if (state.isLoading && state.likes.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.likes.isEmpty) {
              return const _CenteredText(text: 'Лайков ещё нет');
            }
            return ListView.separated(
              itemCount: state.likes.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.outline, height: 1),
              itemBuilder: (context, i) => _LikerTile(like: state.likes[i]),
            );
          },
        ),
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  const _LikerTile({required this.like});

  final Like like;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: like.userPhotoUrl != null && like.userPhotoUrl!.isNotEmpty
          ? CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(like.userPhotoUrl!),
            )
          : const CircleAvatar(
              backgroundColor: AppColors.surfaceVariant,
              child: Icon(Icons.person_outline),
            ),
      title: Text(like.userName.isNotEmpty ? like.userName : 'Аноним'),
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
