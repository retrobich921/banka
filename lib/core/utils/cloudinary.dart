/// Хелперы для Cloudinary-URL.
///
/// Трансформации вписываются прямо в URL после `/image/upload/` и
/// выполняются (и кэшируются) на стороне Cloudinary. Это позволяет
/// показывать в лентах лёгкие превью (~30 КБ) вместо полноразмерных
/// фото (~500 КБ), экономя бесплатный лимит трафика в ~10 раз.
library;

const String _uploadMarker = '/image/upload/';

/// URL превью для [url], загруженного в Cloudinary.
///
/// `c_limit,w_[width]` — уменьшает до ширины без кропа и апскейла,
/// `q_auto,f_auto` — автокачество и современный формат (webp/avif).
/// Если [url] не похож на Cloudinary upload-URL (или уже содержит
/// трансформацию) — возвращается как есть.
String cloudinaryThumb(String url, {int width = 400}) {
  final i = url.indexOf(_uploadMarker);
  if (i < 0) return url;
  final rest = url.substring(i + _uploadMarker.length);
  // Уже есть трансформация (сегмент с параметрами вида `x_y,…/`) — не трогаем.
  final firstSegment = rest.split('/').first;
  if (firstSegment.contains(',') || firstSegment.startsWith('c_')) return url;
  return url.replaceFirst(
    _uploadMarker,
    '${_uploadMarker}c_limit,w_$width,q_auto,f_auto/',
  );
}
