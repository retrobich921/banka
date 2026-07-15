import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_colors.dart';

/// Доступное обновление из GitHub Releases.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });

  final String version;
  final String apkUrl;
  final String notes;
}

/// Самообновление через GitHub Releases (приложение раздаётся APK'ом, не через
/// Play Store). Проверяем последний релиз, сравниваем версию, скачиваем APK и
/// открываем системный установщик.
class AppUpdater {
  const AppUpdater();

  static const String _repo = 'retrobich921/banka';

  /// Проверка наличия обновления. Возвращает `null`, если уже актуально или
  /// что-то пошло не так (сеть/нет релизов) — обновление не критично.
  Future<AppUpdate?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final latest = tag.replaceFirst(RegExp('^v'), '').trim();
      if (latest.isEmpty) return null;
      if (!_isNewer(latest, info.version)) return null;

      final assets = (json['assets'] as List<dynamic>?) ?? const [];
      String? apkUrl;
      for (final a in assets.whereType<Map<String, dynamic>>()) {
        final name = (a['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null) return null;

      return AppUpdate(
        version: latest,
        apkUrl: apkUrl,
        notes: (json['body'] as String?)?.trim() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Сравнение версий `a > b` по компонентам (semver-подобно).
  bool _isNewer(String a, String b) {
    List<int> parts(String v) => v
        .split('.')
        .map((s) => int.tryParse(RegExp(r'\d+').stringMatch(s) ?? '') ?? 0)
        .toList();
    final pa = parts(a);
    final pb = parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Скачивает APK во временную папку с прогрессом (0..1).
  Future<File> download(String url, void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final resp = await client.send(req);
      final total = resp.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/banka-update.apk');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Открывает скачанный APK — система покажет установщик.
  Future<void> install(File apk) => OpenFilex.open(apk.path);
}

/// Проверяет обновление и, если есть, показывает диалог. Безопасно вызывать
/// при старте — при ошибке/отсутствии обновления ничего не делает.
Future<void> maybePromptUpdate(BuildContext context) async {
  final update = await const AppUpdater().check();
  if (update == null || !context.mounted) return;
  await _showUpdateDialog(context, update);
}

Future<void> _showUpdateDialog(BuildContext context, AppUpdate update) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      var downloading = false;
      var progress = 0.0;
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> startUpdate() async {
            setState(() => downloading = true);
            const updater = AppUpdater();
            try {
              final apk = await updater.download(
                update.apkUrl,
                (p) => setState(() => progress = p),
              );
              await updater.install(apk);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              if (!dialogContext.mounted) return;
              setState(() => downloading = false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Не удалось скачать обновление')),
              );
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Доступно обновление ${update.version}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (update.notes.isNotEmpty)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        update.notes,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                if (downloading) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Скачивание ${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
            actions: downloading
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Позже'),
                    ),
                    FilledButton(
                      onPressed: startUpdate,
                      child: const Text('Обновить'),
                    ),
                  ],
          );
        },
      );
    },
  );
}
