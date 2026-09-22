import admin from 'firebase-admin';
import dotenv from 'dotenv';
import { resolve } from 'path';
import bcrypt from 'bcryptjs';

dotenv.config({ path: resolve('.env') });
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : null;
if (!serviceAccount) { console.error("FIREBASE_SERVICE_ACCOUNT env var not found"); process.exit(1); }
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const email = 'casap@gmail.com';
const password = '123456';
const snapshot = await db.collection('users').where('email', '==', email).get();
if (snapshot.empty) {
  console.log(`No user found with email ${email}`);
} else {
  snapshot.forEach(doc => {
    const d = doc.data();
    const stored = (d.password || '').toString();
    const isBcrypt = stored.startsWith('$2');
    const valid = isBcrypt ? bcrypt.compareSync(password, stored) : stored === password;
    console.log('=== USER FOUND ===');
    console.log('uid:', doc.id);
    console.log('fullName:', d.fullName);
    console.log('email:', d.email);
    console.log('role (raw):', d.role);
    console.log('status:', d.status);
    console.log('contractType:', d.contractType);
    console.log('contractId:', d.contractId);
    console.log('stationId:', d.stationId);
    console.log('stations:', JSON.stringify(d.stations));
    console.log('entityId:', d.entityId);
    console.log('passwordIsBcrypt:', isBcrypt);
    console.log('passwordMatches (123456):', valid);
  });
}
await admin.app().delete();