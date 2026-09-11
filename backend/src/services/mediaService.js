import { db } from '../database/index.js';
import { StorageService } from '../storage/index.js';
import { v4 as uuidv4 } from 'uuid';
import multer from 'multer';
import * as evidence from '../../evidence_manager.js';
import { NotFoundError, ValidationError } from '../errors/index.js';

const storageService = new StorageService();

class MediaService {
  getMulterUpload() {
    return multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });
  }

  async uploadFile(file, user) {
    if (!file) throw new ValidationError('No file uploaded.');
    const originalExt = file.originalname.split('.').pop() || 'jpg';
    const uniqueToken = uuidv4();
    const fileName = `${uuidv4()}_${Date.now()}.${originalExt}`;

    const result = await storageService.uploadFile(file.buffer, fileName, {
      contentType: file.mimetype
    });

    return { success: true, message: 'Image uploaded successfully.', imageUrl: result.url };
  }

  async uploadEvidence(userData, files, body) {
    return { message: 'Evidence upload endpoint (implemented via media/upload)' };
  }

  async uploadEvidenceBase64(userData, body) {
    return { message: 'Base64 evidence upload' };
  }

  async getEvidenceTypes() {
    return { types: ['image/jpeg', 'image/png', 'image/webp'] };
  }

  async searchEvidence(params) {
    return { results: [] };
  }

  async getEvidenceById(id) {
    const doc = await db.collection('evidence').doc(id).get();
    if (!doc.exists) throw new NotFoundError('Not found');
    return doc.data();
  }

  async getEvidence(filters) {
    const { id } = filters;
    return this.getEvidenceById(id);
  }

  async updateEvidence(id, body, user) {
    const allowed = ['remarks', 'gpsLat', 'gpsLng', 'evidenceType'];
    const updates = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }
    updates.updatedAt = db.Timestamp();

    const doc = await db.collection('evidence_metadata').doc(id).get();
    if (!doc.exists) throw new NotFoundError('Evidence not found');

    await doc.ref.update(updates);
    await evidence.logAudit(db, 'EVIDENCE_UPDATED', {
      evidenceId: id, userId: user.uid, userName: user.fullName,
      userRole: user.role, details: `Updated fields: ${Object.keys(updates).join(', ')}`
    });

    return { success: true, message: 'Evidence updated' };
  }

  async deleteEvidence(uid, userData) {
    const doc = await db.collection('evidence_metadata').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Evidence not found');

    await doc.ref.update({
      deleted: true, deletedAt: db.Timestamp()
    });

    await evidence.logAudit(db, 'EVIDENCE_DELETED', {
      evidenceId: uid, userId: userData.uid, userName: userData.fullName,
      userRole: userData.role, details: 'Evidence soft-deleted'
    });

    return { success: true, message: 'Evidence deleted' };
  }

  async archiveEvidence(id) {
    return { message: 'Archived' };
  }

  async restoreEvidence(id) {
    return { message: 'Restored' };
  }

  async compareFace(body) {
    const { image1Url, image2Url } = body;
    if (!image1Url || !image2Url) {
      throw new ValidationError('Both image1Url and image2Url are required.');
    }
    const { compareFaces } = await import('./rekognitionService.js');
    return compareFaces(image1Url, image2Url);
  }

  async verifyFace(body) {
    const { imageUrl, expectedChallenge } = body;
    if (!imageUrl) {
      throw new ValidationError('imageUrl is required.');
    }
    const { verifyFaceLiveness } = await import('./rekognitionService.js');
    return verifyFaceLiveness(imageUrl, expectedChallenge || 'SMILE');
  }
}

export const mediaService = new MediaService();
