/**
 * Migration Script: Rename *ID fields to *Id
 * 
 * This script updates all Firestore documents to use Swift naming conventions:
 * - categoryID → categoryId
 * - productDetailsID → productDetailsId
 * - productID → productId
 * 
 * Collections affected: products, users/{uid}/favorites
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

/**
 * Migrate a single document's field names
 */
function migrateFields(data) {
  const updates = {};
  
  // Rename categoryID → categoryId
  if (data.categoryID !== undefined) {
    updates.categoryId = data.categoryID;
    updates.categoryID = admin.firestore.FieldValue.delete();
  }
  
  // Rename productDetailsID → productDetailsId
  if (data.productDetailsID !== undefined) {
    updates.productDetailsId = data.productDetailsID;
    updates.productDetailsID = admin.firestore.FieldValue.delete();
  }
  
  // Rename productID → productId (for favorites)
  if (data.productID !== undefined) {
    updates.productId = data.productID;
    updates.productID = admin.firestore.FieldValue.delete();
  }
  
  return Object.keys(updates).length > 0 ? updates : null;
}

/**
 * Migrate all documents in a collection
 */
async function migrateCollection(collectionPath) {
  console.log(`\nMigrating collection: ${collectionPath}`);
  
  const snapshot = await db.collection(collectionPath).get();
  console.log(`Found ${snapshot.size} documents`);
  
  let updatedCount = 0;
  const batch = db.batch();
  
  snapshot.docs.forEach(doc => {
    const updates = migrateFields(doc.data());
    if (updates) {
      batch.update(doc.ref, updates);
      updatedCount++;
    }
  });
  
  if (updatedCount > 0) {
    await batch.commit();
    console.log(`✓ Updated ${updatedCount} documents`);
  } else {
    console.log('No updates needed');
  }
  
  return updatedCount;
}

/**
 * Migrate all favorites subcollections for all users
 */
async function migrateFavorites() {
  console.log('\nMigrating user favorites...');
  
  const usersSnapshot = await db.collection('users').get();
  console.log(`Found ${usersSnapshot.size} users`);
  
  let totalUpdated = 0;
  
  for (const userDoc of usersSnapshot.docs) {
    const favoritesSnapshot = await userDoc.ref.collection('favorites').get();
    
    if (favoritesSnapshot.size === 0) continue;
    
    console.log(`  User ${userDoc.id}: ${favoritesSnapshot.size} favorites`);
    
    const batch = db.batch();
    let userUpdated = 0;
    
    favoritesSnapshot.docs.forEach(doc => {
      const updates = migrateFields(doc.data());
      if (updates) {
        batch.update(doc.ref, updates);
        userUpdated++;
      }
    });
    
    if (userUpdated > 0) {
      await batch.commit();
      totalUpdated += userUpdated;
    }
  }
  
  console.log(`✓ Updated ${totalUpdated} favorite documents`);
  return totalUpdated;
}

/**
 * Main migration function
 */
async function runMigration() {
  console.log('🚀 Starting ID → Id field migration\n');
  console.log('This will rename:');
  console.log('  - categoryID → categoryId');
  console.log('  - productDetailsID → productDetailsId');
  console.log('  - productID → productId');
  console.log('='.repeat(50));
  
  try {
    // Migrate products collection
    await migrateCollection('products');

    // Migrate product details collection (if it has ID fields)
    await migrateCollection('product_details');
    
    // Migrate brands collection (if it has ID fields)
    await migrateCollection('brands');
    
    // Migrate all user favorites
    await migrateFavorites();
    
    console.log('\n' + '='.repeat(50));
    console.log('✅ Migration completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  } finally {
    // Close Firebase connection
    await admin.app().delete();
  }
}

// Run the migration
runMigration();
