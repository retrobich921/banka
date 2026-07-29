// Генератор иконки приложения.
//
// Рисует «банку» в фирменных цветах (чёрный фон #000000, янтарный акцент
// #FFB300) и складывает два PNG:
//   assets/icon/app_icon.png            — обычная иконка (непрозрачный фон);
//   assets/icon/app_icon_foreground.png — foreground для adaptive icon
//                                          (прозрачный фон, safe zone 66%).
//
// Запуск:  dart run tool/generate_app_icon.dart
// Затем:   dart run flutter_launcher_icons
import 'dart:io';

import 'package:image/image.dart' as img;

const int _size = 1024;

final img.Color _black = img.ColorRgba8(0, 0, 0, 255);
final img.Color _amber = img.ColorRgba8(0xFF, 0xB3, 0x00, 255);
final img.Color _amberLight = img.ColorRgba8(0xFF, 0xD1, 0x66, 255);
final img.Color _transparent = img.ColorRgba8(0, 0, 0, 0);

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Обычную иконку рисуем крупнее: её кропает маска лаунчера, а у
  // adaptive-foreground есть обязательная safe zone (центральные 66%).
  File('assets/icon/app_icon.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(_draw(withBackground: true, scale: 1.25)));

  File('assets/icon/app_icon_foreground.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(_draw(withBackground: false, scale: 1)));

  stdout.writeln('assets/icon/app_icon.png + app_icon_foreground.png готовы');
}

img.Image _draw({required bool withBackground, required double scale}) {
  final image = img.Image(width: _size, height: _size, numChannels: 4);
  img.fill(image, color: withBackground ? _black : _transparent);

  const center = _size / 2;
  int sx(num v) => (center + (v - center) * scale).round();
  int sy(num v) => (center + (v - center) * scale).round();
  int sr(num v) => (v * scale).round();

  void rect(num x1, num y1, num x2, num y2, num radius, img.Color color) {
    img.fillRect(
      image,
      x1: sx(x1),
      y1: sy(y1),
      x2: sx(x2),
      y2: sy(y2),
      radius: sr(radius),
      color: color,
    );
  }

  // Крышка.
  rect(392, 206, 632, 264, 28, _amberLight);
  // Корпус банки.
  rect(368, 244, 656, 790, 60, _amber);
  // Тёмная этикетка поперёк корпуса.
  rect(368, 430, 656, 566, 8, _black);
  // Блики слева — чтобы банка не выглядела плоским прямоугольником.
  rect(398, 300, 424, 420, 13, _amberLight);
  rect(398, 592, 424, 730, 13, _amberLight);

  // Капля-акцент на этикетке.
  img.fillCircle(image, x: sx(512), y: sy(498), radius: sr(34), color: _amber);

  return image;
}
