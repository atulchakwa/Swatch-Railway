import admin from 'firebase-admin';

// Initialize Firebase Admin (assuming default env vars are set if run in the right context)
// If not, we'll see an error, but let's try reading the existing index.js
import { db } from './src/database/index.js';

async function listWorkers() {
  try {
    const validWorkerRoles = ['worker', 'railway worker', 'janitor', 'attendant', 'contractor worker', 'staff'];
    const snapshot = await db.collection('users').get();
    let count = 0;
    snapshot.forEach(doc => {
      const d = doc.data();
      const role = (d.role || '').toLowerCase();
      if (validWorkerRoles.includes(role)) {
        console.log(`ID: ${doc.id}, Name: ${d.fullName || d.name}, Email: ${d.email}, Role: ${d.role}, Status: ${d.status}`);
        count++;
      }
    });
    console.log(`Total workers found: ${count}`);
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

listWorkers();
