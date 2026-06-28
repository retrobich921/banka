/**
 * Cloud Function для очистки старых запросов на вступление без groupOwnerId
 * 
 * Вызов: 
 * curl -X POST https://us-central1-banka-collectors-app.cloudfunctions.net/cleanupJoinRequests
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.cleanupJoinRequests = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
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
          console.log(`Deleted join_request: ${groupId}/${requestDoc.id}`);
        }
      }
    }

    res.status(200).json({
      success: true,
      message: `Deleted ${deletedCount} old join requests`,
      deletedCount
    });
  } catch (error) {
    console.error('Error cleaning up join requests:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
