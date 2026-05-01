// Cloud Functions для Banka.
//
// На текущем спринте (Sprint 7) активна только заготовка
// `onPostImageUploaded`: после того как клиент закидывает фото в
// `posts/{postId}/{n}_{filename}.jpg`, функция собирает thumbnail 400×400
// через `sharp`, кладёт рядом с суффиксом `_thumb.jpg` и обновляет
// `posts/{postId}.photos[i].thumbUrl`.
//
// Деплой: `cd functions && npm install && npm run deploy`.
// До деплоя приложение продолжит работать — поле `thumbUrl` стартует со
// значения `url` (см. `lib/features/post/data/datasources/post_image_data_source.dart`).

const path = require('node:path');
const os = require('node:os');
const fs = require('node:fs');
const { initializeApp } = require('firebase-admin/app');
const { getStorage } = require('firebase-admin/storage');
const { getFirestore } = require('firebase-admin/firestore');
const { onObjectFinalized } = require('firebase-functions/v2/storage');
const {
  onDocumentCreated,
  onDocumentDeleted,
} = require('firebase-functions/v2/firestore');
const { FieldValue } = require('firebase-admin/firestore');
const { logger } = require('firebase-functions');
const sharp = require('sharp');

initializeApp();

exports.onPostImageUploaded = onObjectFinalized(
  { region: 'europe-west3', memory: '512MiB' },
  async (event) => {
    const filePath = event.data.name;
    if (!filePath) return;
    if (!filePath.startsWith('posts/')) return;
    if (filePath.endsWith('_thumb.jpg')) return;
    if (!event.data.contentType?.startsWith('image/')) return;

    const parts = filePath.split('/');
    if (parts.length < 3) return;
    const postId = parts[1];
    const fileName = parts.slice(2).join('/');

    const bucket = getStorage().bucket(event.data.bucket);
    const tmpOriginal = path.join(os.tmpdir(), fileName.replace(/\//g, '_'));
    const thumbName = `${path.basename(fileName, path.extname(fileName))}_thumb.jpg`;
    const thumbPath = `posts/${postId}/${thumbName}`;
    const tmpThumb = path.join(os.tmpdir(), thumbName);

    try {
      await bucket.file(filePath).download({ destination: tmpOriginal });
      await sharp(tmpOriginal)
        .resize({ width: 400, height: 400, fit: 'cover' })
        .jpeg({ quality: 80 })
        .toFile(tmpThumb);

      await bucket.upload(tmpThumb, {
        destination: thumbPath,
        contentType: 'image/jpeg',
      });

      const [thumbMeta] = await bucket.file(thumbPath).getSignedUrl({
        action: 'read',
        expires: '12-31-2099',
      });

      // Обновляем запись поста: подменяем thumbUrl у соответствующего фото.
      const firestore = getFirestore();
      const ref = firestore.collection('posts').doc(postId);
      await firestore.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const photos = (snap.data().photos || []).map((photo) => {
          if (photo.url && photo.url.includes(encodeURIComponent(filePath))) {
            return { ...photo, thumbUrl: thumbMeta };
          }
          return photo;
        });
        tx.update(ref, { photos });
      });
    } catch (err) {
      logger.error('onPostImageUploaded failed', { filePath, err });
    } finally {
      if (fs.existsSync(tmpOriginal)) fs.unlinkSync(tmpOriginal);
      if (fs.existsSync(tmpThumb)) fs.unlinkSync(tmpThumb);
    }
  },
);

// Sprint 10: счётчик `likesCount` обновляется только сервером.
// Клиент пишет / удаляет `posts/{postId}/likes/{userId}`,
// функции реагируют атомарным `FieldValue.increment(±1)`.

exports.onLikeCreated = onDocumentCreated(
  { document: 'posts/{postId}/likes/{userId}', region: 'europe-west3' },
  async (event) => {
    const { postId } = event.params;
    try {
      await getFirestore()
        .collection('posts')
        .doc(postId)
        .update({ likesCount: FieldValue.increment(1) });
    } catch (err) {
      logger.error('onLikeCreated failed', { postId, err });
    }
  },
);

exports.onLikeDeleted = onDocumentDeleted(
  { document: 'posts/{postId}/likes/{userId}', region: 'europe-west3' },
  async (event) => {
    const { postId } = event.params;
    try {
      await getFirestore()
        .collection('posts')
        .doc(postId)
        .update({ likesCount: FieldValue.increment(-1) });
    } catch (err) {
      logger.error('onLikeDeleted failed', { postId, err });
    }
  },
);

// Sprint 11: счётчик `commentsCount` обновляется только сервером.
// Клиент пишет / удаляет `posts/{postId}/comments/{commentId}`,
// функции реагируют атомарным `FieldValue.increment(±1)`.

exports.onCommentCreated = onDocumentCreated(
  { document: 'posts/{postId}/comments/{commentId}', region: 'europe-west3' },
  async (event) => {
    const { postId } = event.params;
    try {
      await getFirestore()
        .collection('posts')
        .doc(postId)
        .update({ commentsCount: FieldValue.increment(1) });
    } catch (err) {
      logger.error('onCommentCreated failed', { postId, err });
    }
  },
);

exports.onCommentDeleted = onDocumentDeleted(
  { document: 'posts/{postId}/comments/{commentId}', region: 'europe-west3' },
  async (event) => {
    const { postId } = event.params;
    try {
      await getFirestore()
        .collection('posts')
        .doc(postId)
        .update({ commentsCount: FieldValue.increment(-1) });
    } catch (err) {
      logger.error('onCommentDeleted failed', { postId, err });
    }
  },
);
