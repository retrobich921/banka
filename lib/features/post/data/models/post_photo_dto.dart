import '../../../../core/utils/cloudinary.dart';
import '../../domain/entities/post.dart';

/// DTO-конверсия `PostPhoto` ↔ Map (вложенный в `posts/{postId}.photos`).
abstract final class PostPhotoDto {
  const PostPhotoDto._();

  static const String fUrl = 'url';
  static const String fThumbUrl = 'thumbUrl';
  static const String fWidth = 'width';
  static const String fHeight = 'height';

  static PostPhoto fromMap(Map<String, dynamic> data) {
    final url = (data[fUrl] as String?) ?? '';
    final rawThumb = (data[fThumbUrl] as String?) ?? '';
    // Легаси-посты писались с thumbUrl == url (полноразмер) — превью
    // строим на лету Cloudinary-трансформацией.
    final thumb = (rawThumb.isEmpty || rawThumb == url)
        ? cloudinaryThumb(url)
        : rawThumb;
    return PostPhoto(
      url: url,
      thumbUrl: thumb,
      width: (data[fWidth] as num?)?.toInt() ?? 0,
      height: (data[fHeight] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> toMap(PostPhoto photo) {
    return <String, dynamic>{
      fUrl: photo.url,
      fThumbUrl: photo.thumbUrl,
      fWidth: photo.width,
      fHeight: photo.height,
    };
  }
}
