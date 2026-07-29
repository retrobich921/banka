import 'package:flutter/material.dart';

/// Обёртка списочного элемента, который нужно «схлопнуть» перед удалением.
///
/// Используется при архивации: карточка плавно гаснет и сжимается по
/// высоте, и только после этого [onCollapsed] сообщает блоку, что пост
/// можно убрать из списка. Без этого элемент исчезал бы рывком.
class CollapsibleItem extends StatelessWidget {
  const CollapsibleItem({
    super.key,
    required this.collapsed,
    required this.onCollapsed,
    required this.child,
  });

  final bool collapsed;
  final VoidCallback onCollapsed;
  final Widget child;

  static const Duration _duration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: collapsed ? 0 : 1,
      duration: _duration,
      curve: Curves.easeOut,
      onEnd: () {
        if (collapsed) onCollapsed();
      },
      child: AnimatedSize(
        duration: _duration,
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: collapsed
            ? const SizedBox(width: double.infinity, height: 0)
            : child,
      ),
    );
  }
}
