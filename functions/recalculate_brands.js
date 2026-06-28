// Скрипт для пересчёта postsCount для всех брендов
// Запуск: node recalculate_brands.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Нужно скачать из Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function recalculateBrandPostsCounts() {
  try {
    console.log('Starting brand posts count recalculation...');
    let updatedBrandsCount = 0;

    // Получаем все бренды
    const brandsSnapshot = await db.collection('brands').get();
    console.log(`Found ${brandsSnapshot.size} brands`);
    
    for (const brandDoc of brandsSnapshot.docs) {
      const brandId = brandDoc.id;
      const brandData = brandDoc.data();
      
      // Считаем количество постов с этим brandId
      const postsSnapshot = await db
        .collection('posts')
        .where('brandId', '==', brandId)
        .get();
      
      const actualPostsCount = postsSnapshot.size;
      const currentPostsCount = brandData.postsCount || 0;
      
      if (actualPostsCount !== currentPostsCount) {
        // Обновляем postsCount в документе бренда
        await brandDoc.ref.update({ postsCount: actualPostsCount });
        updatedBrandsCount++;
        
        console.log(`✓ Updated brand "${brandData.name}" (${brandId}): ${currentPostsCount} → ${actualPostsCount}`);
      } else {
        console.log(`- Skipped brand "${brandData.name}" (${brandId}): already correct (${actualPostsCount})`);
      }
    }

    console.log(`\n✅ Recalculation completed!`);
    console.log(`   Updated: ${updatedBrandsCount} brands`);
    console.log(`   Skipped: ${brandsSnapshot.size - updatedBrandsCount} brands (already correct)`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error recalculating brand posts counts:', error);
    process.exit(1);
  }
}

recalculateBrandPostsCounts();
