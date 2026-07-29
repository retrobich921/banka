// Push-уведомления (FCM).
//
// Триггеры вешаются отдельно от счётчиков (`index.js`), чтобы ошибка
// доставки не мешала инкрементам: на один и тот же документ Firestore
// может быть несколько функций.
//
// Что шлём:
//   • лайк моего поста        → автору поста;
//   • комментарий к моему посту → автору поста;
//   • новая банка              → подписчикам автора и участникам группы.
//
// Токены устройств лежат в `users/{uid}.fcmTokens` (пишет клиент, см.
// lib/core/notifications/push_notifications_service.dart). Протухшие
// токены удаляем прямо здесь — иначе массив растёт вечно.
//
// ⚠️ Требуется Blaze-план: на Spark Cloud Functions не выполняются.

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { logger } = require('firebase-functions');

const REGION = 'europe-west3';
const MULTICAST_LIMIT = 500;

/// Собирает токены получателей: { token: uid }.
async function collectTokens(uids) {
  const db = getFirestore();
  const unique = [...new Set(uids.filter(Boolean))];
  const owners = {};
  // `getAll` принимает до 100 ссылок за раз (лимит транзакции чтения).
  for (let i = 0; i < unique.length; i += 100) {
    const refs = unique
      .slice(i, i + 100)
      .map((uid) => db.collection('users').doc(uid));
    const snaps = await db.getAll(...refs);
    for (const snap of snaps) {
      const tokens = snap.get('fcmTokens') || [];
      for (const token of tokens) {
        if (typeof token === 'string' && token.length > 0) {
          owners[token] = snap.id;
        }
      }
    }
  }
  return owners;
}

/// Отправляет одно и то же уведомление на все токены и чистит мёртвые.
async function sendToTokens(owners, { title, body, postId }) {
  const tokens = Object.keys(owners);
  if (tokens.length === 0) return;

  const db = getFirestore();
  const messaging = getMessaging();
  const stale = {};

  for (let i = 0; i < tokens.length; i += MULTICAST_LIMIT) {
    const chunk = tokens.slice(i, i + MULTICAST_LIMIT);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: { postId: postId || '' },
      android: {
        priority: 'high',
        notification: { channelId: 'banka_default' },
      },
    });

    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error && result.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/invalid-argument'
      ) {
        const token = chunk[index];
        const uid = owners[token];
        if (!stale[uid]) stale[uid] = [];
        stale[uid].push(token);
      }
    });
  }

  await Promise.all(
    Object.entries(stale).map(([uid, deadTokens]) =>
      db
        .collection('users')
        .doc(uid)
        .update({ fcmTokens: FieldValue.arrayRemove(...deadTokens) })
        .catch((err) => logger.warn('token cleanup failed', { uid, err })),
    ),
  );
}

async function getPost(postId) {
  const snap = await getFirestore().collection('posts').doc(postId).get();
  return snap.exists ? snap.data() : null;
}

exports.onLikeNotify = onDocumentCreated(
  { document: 'posts/{postId}/likes/{userId}', region: REGION },
  async (event) => {
    const { postId, userId } = event.params;
    try {
      const post = await getPost(postId);
      if (!post || !post.authorId || post.authorId === userId) return;
      const liker = (event.data && event.data.data()) || {};
      const name = liker.userName || 'Кто-то';
      await sendToTokens(await collectTokens([post.authorId]), {
        title: 'Новый лайк',
        body: `${name} оценил(а) «${post.drinkName || 'вашу банку'}»`,
        postId,
      });
    } catch (err) {
      logger.error('onLikeNotify failed', { postId, err });
    }
  },
);

exports.onCommentNotify = onDocumentCreated(
  { document: 'posts/{postId}/comments/{commentId}', region: REGION },
  async (event) => {
    const { postId } = event.params;
    try {
      const comment = (event.data && event.data.data()) || {};
      const post = await getPost(postId);
      if (!post || !post.authorId || post.authorId === comment.authorId) return;
      const name = comment.authorName || 'Кто-то';
      const text = (comment.text || '').slice(0, 120);
      await sendToTokens(await collectTokens([post.authorId]), {
        title: `${name} — комментарий`,
        body: text,
        postId,
      });
    } catch (err) {
      logger.error('onCommentNotify failed', { postId, err });
    }
  },
);

exports.onPostNotify = onDocumentCreated(
  { document: 'posts/{postId}', region: REGION },
  async (event) => {
    const postId = event.params.postId;
    try {
      const post = (event.data && event.data.data()) || {};
      if (post.archived) return;
      const authorId = post.authorId;
      if (!authorId) return;

      const db = getFirestore();
      const recipients = new Set();

      // Подписчики автора (зеркало подписок, см. FollowRemoteDataSource).
      const followers = await db
        .collection('users')
        .doc(authorId)
        .collection('followers')
        .get();
      followers.docs.forEach((doc) => recipients.add(doc.id));

      // Участники группы, если банка опубликована в группу.
      if (post.groupId) {
        const group = await db.collection('groups').doc(post.groupId).get();
        (group.get('membersUids') || []).forEach((uid) => recipients.add(uid));
      }

      recipients.delete(authorId);
      if (recipients.size === 0) return;

      const author = post.authorName || 'Коллекционер';
      await sendToTokens(await collectTokens([...recipients]), {
        title: post.groupName
          ? `Новая банка в «${post.groupName}»`
          : 'Новая банка',
        body: `${author}: ${post.drinkName || 'смотреть'}`,
        postId,
      });
    } catch (err) {
      logger.error('onPostNotify failed', { postId, err });
    }
  },
);
