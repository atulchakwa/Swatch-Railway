import admin from 'firebase-admin';
import dotenv from 'dotenv';
import { resolve } from 'path';

dotenv.config({ path: resolve('.env') });

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT 
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT) 
  : null;

if (!serviceAccount) {
  console.error("FIREBASE_SERVICE_ACCOUNT env var not found");
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const snapshot = await db.collection('users').get();
console.log(`Fetched ${snapshot.size} users:`);
snapshot.forEach(doc => {
  const data = doc.data();
  console.log(`- ID: ${doc.id}, Name: ${data.fullName}, Email: ${data.email}, Role: ${data.role}, StationId: ${data.stationId}, Depot: ${data.depot}, AreaId: ${data.areaId}, PlatformId: ${data.platformId}`);
});

await admin.app().delete();
