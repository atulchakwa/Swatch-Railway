import firebaseAdmin from 'firebase-admin';
import appConfig from '../config/index.js';

class Database {
  constructor() {
    this.admin = firebaseAdmin;
    this.db = null;
    this.bucket = null;
  }

  initialize() {
    if (this.db) return this;

    if (firebaseAdmin.apps.length === 0) {
      const serviceAccount = appConfig.firebase.serviceAccount;
      if (!serviceAccount) {
        throw new Error('Firebase service account not configured');
      }

      firebaseAdmin.initializeApp({
        credential: firebaseAdmin.credential.cert(serviceAccount)
      });
    }

    this.db = firebaseAdmin.firestore();
    this.db.settings({ ignoreUndefinedProperties: true });
    this.bucket = firebaseAdmin.storage().bucket(appConfig.firebase.storageBucket);

    return this;
  }

  getDb() {
    if (!this.db) this.initialize();
    return this.db;
  }

  getBucket() {
    if (!this.bucket) this.initialize();
    return this.bucket;
  }

  getAdmin() {
    return firebaseAdmin;
  }

  collection(name) {
    return this.getDb().collection(name);
  }

  doc(path) {
    return this.getDb().doc(path);
  }

  batch() {
    return this.getDb().batch();
  }

  runTransaction(updateFn) {
    return this.getDb().runTransaction(updateFn);
  }

  Timestamp() {
    return firebaseAdmin.firestore.FieldValue.serverTimestamp();
  }

  increment(n = 1) {
    return firebaseAdmin.firestore.FieldValue.increment(n);
  }

  arrayUnion(...elements) {
    return firebaseAdmin.firestore.FieldValue.arrayUnion(...elements);
  }

  arrayRemove(...elements) {
    return firebaseAdmin.firestore.FieldValue.arrayRemove(...elements);
  }

  documentId() {
    return firebaseAdmin.firestore.FieldPath.documentId();
  }

  async createUser(authData) {
    return firebaseAdmin.auth().createUser(authData);
  }

  async updateUser(uid, authData) {
    return firebaseAdmin.auth().updateUser(uid, authData);
  }

  async deleteUser(uid) {
    return firebaseAdmin.auth().deleteUser(uid);
  }
}

const database = new Database();
export { database as db };
export const admin = database.getAdmin();
