import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/post.dart';
import 'rating_widgets.dart';

/// Диалог «поделиться банкой»: показывает карточку-превью и по кнопке
/// рендерит её в PNG (RepaintBoundary → toImage) и открывает системный
/// шэр — можно кинуть в сторис/телегу.
Future<void> showSharePostDialog(BuildContext context, Post post) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SharePostDialog(post: post),
  );
}

class _SharePostDialog extends StatefulWidget {
  const _SharePostDialog({required this.post});

  final Post post;

  @override
  State<_SharePostDialog> createState() => _SharePostDialogState();
}

class _SharePostDialogState extends State<_SharePostDialog> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      // Даём кадру дорисоваться (фото могло только что загрузиться).
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/banka-share-${widget.post.id}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '${widget.post.drinkName} — моя коллекция в banka',
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось подготовить картинку')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: _ShareCard(post: widget.post),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.ios_share),
              label: Text(_sharing ? 'Готовим…' : 'Поделиться'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сама карточка: фото банки, название, бренд, оценка и подпись banka.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = post.photos.isNotEmpty ? post.photos.first : null;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo != null)
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: photo.url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: AppColors.surfaceVariant),
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: AppColors.surfaceVariant),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.drinkName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (post.rating != null) ...[
                      const SizedBox(width: 8),
                      RatingScoreBadge(score: post.rating!.score),
                    ],
                  ],
                ),
                if (post.brandName?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    post.brandName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.local_drink,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'banka — коллекция напитков',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (post.authorName.isNotEmpty)
                      Text(
                        '@${post.authorName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceFaint,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
