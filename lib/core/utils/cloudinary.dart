/// Хелперы для Cloudinary-URL.
///
/// Трансформации вписываются прямо в URL после `/image/upload/` и
/// выполняются (и кэшируются) на стороне Cloudinary. Это позволяет
/// показывать в лентах лёгкие превью вместо полноразмерных фото,
/// экономя бесплатный лимит трафика.
library;

const String _uploadMarker = '/image/upload/';

/// Набор ширин, из которого выбираются превью. Ограниченный список нужен,
/// чтобы Cloudinary не плодил производные под каждую пиксельную ширину
/// экрана — иначе кэш на их стороне почти всегда «мимо».
const List<int> kCloudinaryWidthBuckets = <int>[400, 600, 800, 1080, 1440];

/// Ширина превью под виджет шириной [logicalWidth] на экране с плотностью
/// [devicePixelRatio]: берём ближайшую сверху из [kCloudinaryWidthBuckets],
/// чтобы картинка не выглядела мылом на 3x-экранах.
int cloudinaryWidthFor(double logicalWidth, double devicePixelRatio) {
  final px = logicalWidth * devicePixelRatio;
  for (final bucket in kCloudinaryWidthBuckets) {
    if (px <= bucket) return bucket;
  }
  return kCloudinaryWidthBuckets.last;
}

/// URL превью для [url], загруженного в Cloudinary.
///
/// `c_limit,w_[width]` — уменьшает до ширины без кропа и апскейла,
/// `q_auto:good,f_auto` — качество выше дефолтного `q_auto` и современный
/// формат (webp/avif). Если в URL уже есть трансформация — она заменяется
/// на запрошенную (иначе превью навсегда осталось бы в той ширине, с
/// которой пост когда-то сохранили). Не-Cloudinary URL возвращается как есть.
String cloudinaryThumb(String url, {int width = 400}) {
  final marker = url.indexOf(_uploadMarker);
  if (marker < 0) return url;

  final head = url.substring(0, marker + _uploadMarker.length);
  final rest = url.substring(marker + _uploadMarker.length);
  final segments = rest.split('/');
  final first = segments.isNotEmpty ? segments.first : '';
  // Сегмент трансформации — это список параметров вида `c_limit,w_400,…`
  // (в отличие от версии `v123` и public id).
  final hasTransform =
      first.contains(',') || first.startsWith('c_') || first.startsWith('w_');
  final tail = hasTransform ? segments.skip(1).join('/') : rest;

  return '${head}c_limit,w_$width,q_auto:good,f_auto/$tail';
}
