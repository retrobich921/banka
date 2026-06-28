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
const { onRequest } = require('firebase-functions/v2/https');
const { FieldValue } = require('firebase-admin/firestore');
const { logger } = require('firebase-functions');
const sharp = require('sharp');

initializeApp();

// Функция для очистки старых запросов на вступление без groupOwnerId
exports.cleanupJoinRequests = onRequest(
  { region: 'europe-west3' },
  async (req, res) => {
    try {
      const db = getFirestore();
      let deletedCount = 0;

      // Получаем все группы
      const groupsSnapshot = await db.collection('groups').get();

      for (const groupDoc of groupsSnapshot.docs) {
        const groupId = groupDoc.id;
        
        // Получаем все запросы на вступление для этой группы
        const requestsSnapshot = await db
          .collection('groups')
          .doc(groupId)
          .collection('join_requests')
          .get();

        for (const requestDoc of requestsSnapshot.docs) {
          const data = requestDoc.data();
          
          // Удаляем запросы без groupOwnerId или с пустым groupOwnerId
          if (!data.groupOwnerId || data.groupOwnerId === '') {
            await requestDoc.ref.delete();
            deletedCount++;
            logger.info(`Deleted join_request: ${groupId}/${requestDoc.id}`);
          }
        }
      }

      res.status(200).json({
        success: true,
        message: `Deleted ${deletedCount} old join requests`,
        deletedCount
      });
    } catch (error) {
      logger.error('Error cleaning up join requests:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
);

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

// Sprint 13: счётчик `brands/{brandId}.postsCount` обновляется только сервером.
// Клиент пишет / удаляет `posts/{postId}` с заполненным полем `brandId`,
// функции реагируют атомарным `FieldValue.increment(±1)`.

exports.onPostCreatedUpdateBrandStats = onDocumentCreated(
  { document: 'posts/{postId}', region: 'europe-west3' },
  async (event) => {
    const data = event.data?.data();
    const brandId = data?.brandId;
    if (!brandId) return;
    try {
      await getFirestore()
        .collection('brands')
        .doc(brandId)
        .update({ postsCount: FieldValue.increment(1) });
    } catch (err) {
      logger.error('onPostCreatedUpdateBrandStats failed', { brandId, err });
    }
  },
);

exports.onPostDeletedUpdateBrandStats = onDocumentDeleted(
  { document: 'posts/{postId}', region: 'europe-west3' },
  async (event) => {
    const data = event.data?.data();
    const brandId = data?.brandId;
    if (!brandId) return;
    try {
      await getFirestore()
        .collection('brands')
        .doc(brandId)
        .update({ postsCount: FieldValue.increment(-1) });
    } catch (err) {
      logger.error('onPostDeletedUpdateBrandStats failed', { brandId, err });
    }
  },
);

// Каскадное удаление группы: удаляет все subcollections (members, join_requests)
// и опционально отвязывает посты от группы
exports.onGroupDeleted = onDocumentDeleted(
  { document: 'groups/{groupId}', region: 'europe-west3' },
  async (event) => {
    const { groupId } = event.params;
    const db = getFirestore();
    
    try {
      logger.info(`Starting cascade delete for group: ${groupId}`);
      
      // Удаляем все документы из subcollection members
      const membersSnapshot = await db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();
      
      const memberDeletePromises = membersSnapshot.docs.map((doc) => doc.ref.delete());
      await Promise.all(memberDeletePromises);
      logger.info(`Deleted ${membersSnapshot.size} members for group ${groupId}`);
      
      // Удаляем все документы из subcollection join_requests
      const requestsSnapshot = await db
        .collection('groups')
        .doc(groupId)
        .collection('join_requests')
        .get();
      
      const requestDeletePromises = requestsSnapshot.docs.map((doc) => doc.ref.delete());
      await Promise.all(requestDeletePromises);
      logger.info(`Deleted ${requestsSnapshot.size} join requests for group ${groupId}`);
      
      // Отвязываем посты от группы (устанавливаем groupId = null)
      const postsSnapshot = await db
        .collection('posts')
        .where('groupId', '==', groupId)
        .get();
      
      const postUpdatePromises = postsSnapshot.docs.map((doc) => 
        doc.ref.update({ groupId: null })
      );
      await Promise.all(postUpdatePromises);
      logger.info(`Unlinked ${postsSnapshot.size} posts from group ${groupId}`);
      
      logger.info(`Successfully completed cascade delete for group: ${groupId}`);
    } catch (err) {
      logger.error('onGroupDeleted failed', { groupId, err });
    }
  },
);

// Миграция displayName для существующих участников групп
// Вызывается вручную через HTTP request
exports.migrateGroupMembersDisplayNames = onRequest(
  { region: 'europe-west3' },
  async (req, res) => {
    try {
      const db = getFirestore();
      let updatedCount = 0;
      let skippedCount = 0;

      // Получаем все группы
      const groupsSnapshot = await db.collection('groups').get();

      for (const groupDoc of groupsSnapshot.docs) {
        const groupId = groupDoc.id;
        
        // Получаем всех участников группы
        const membersSnapshot = await db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .get();

        for (const memberDoc of membersSnapshot.docs) {
          const memberData = memberDoc.data();
          const userId = memberDoc.id;
          
          // Пропускаем если displayName уже есть и не пустой
          if (memberData.displayName && memberData.displayName !== '') {
            skippedCount++;
            continue;
          }
          
          // Получаем данные пользователя из коллекции users
          const userDoc = await db.collection('users').doc(userId).get();
          
          if (userDoc.exists) {
            const userData = userDoc.data();
            const displayName = userData.displayName || userData.name || '';
            
            if (displayName) {
              // Обновляем displayName участника
              await memberDoc.ref.update({ displayName });
              updatedCount++;
              logger.info(`Updated displayName for member ${userId} in group ${groupId}: ${displayName}`);
            } else {
              skippedCount++;
              logger.warn(`No displayName found for user ${userId}`);
            }
          } else {
            skippedCount++;
            logger.warn(`User document not found for ${userId}`);
          }
        }
      }

      res.status(200).json({
        success: true,
        message: `Migration completed`,
        updatedCount,
        skippedCount
      });
    } catch (error) {
      logger.error('Error migrating group members displayNames:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
);


// Миграция: пересчёт postsCount для всех брендов на основе существующих постов
// Вызывается вручную через HTTP request: POST https://<region>-<project>.cloudfunctions.net/recalculateBrandPostsCounts
exports.recalculateBrandPostsCounts = onRequest(
  { region: 'europe-west3' },
  async (req, res) => {
    try {
      const db = getFirestore();
      let updatedBrandsCount = 0;

      // Получаем все бренды
      const brandsSnapshot = await db.collection('brands').get();
      
      for (const brandDoc of brandsSnapshot.docs) {
        const brandId = brandDoc.id;
        
        // Считаем количество постов с этим brandId
        const postsSnapshot = await db
          .collection('posts')
          .where('brandId', '==', brandId)
          .count()
          .get();
        
        const actualPostsCount = postsSnapshot.data().count;
        
        // Обновляем postsCount в документе бренда
        await brandDoc.ref.update({ postsCount: actualPostsCount });
        updatedBrandsCount++;
        
        logger.info(`Updated brand ${brandId}: postsCount = ${actualPostsCount}`);
      }

      res.status(200).json({
        success: true,
        message: `Recalculated postsCount for ${updatedBrandsCount} brands`,
        updatedBrandsCount
      });
    } catch (error) {
      logger.error('Error recalculating brand posts counts:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
);
