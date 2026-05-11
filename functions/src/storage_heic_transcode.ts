import { onObjectFinalized } from "firebase-functions/v2/storage";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import sharp from "sharp";
import { v4 as uuidv4 } from "uuid";

// Initialize Admin SDK once
try { admin.initializeApp(); } catch (_) {}

// Helper to build Firebase Storage download URL given object path and token
const buildDownloadUrl = (bucket: string, objectPath: string, token: string) => {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encoded}?alt=media&token=${token}`;
};

// Only process HEIC/HEIF-like objects
const isHeicObject = (contentType?: string | null, name?: string) => {
  const ct = (contentType || '').toLowerCase();
  const nm = (name || '').toLowerCase();
  if (ct.includes('image/heic') || ct.includes('image/heif')) return true;
  if (nm.endsWith('.heic') || nm.endsWith('.heif')) return true;
  return false;
};

export const storage_heic_transcode = onObjectFinalized({
  region: "us-central1",
  memory: "1GiB",
  timeoutSeconds: 300,
}, async (event) => {
  const obj = event.data;
  const bucketName = obj.bucket;
  const contentType = obj.contentType || '';
  const name = obj.name || '';
  const metadata = obj.metadata || {} as Record<string, string>;

  // Skip if already converted or not a HEIC-like file
  if (metadata['converted'] === 'true') {
    logger.info('Skipping already-converted object', { name });
    return;
  }
  if (!isHeicObject(contentType, name)) {
    logger.info('Not HEIC/HEIF, skipping', { name, contentType });
    return;
  }

  logger.info('Processing HEIC file', { name, contentType });

  const bucket = admin.storage().bucket(bucketName);
  const srcFile = bucket.file(name);
  const [exists] = await srcFile.exists();
  if (!exists) {
    logger.error('Source file does not exist', { name });
    return;
  }

  try {
    // Download the source into memory
    const [buf] = await srcFile.download();

    // Convert to JPEG with reasonable quality
    const jpeg = await sharp(buf, { failOn: 'none' }).jpeg({ quality: 80 }).toBuffer();

    // Build destination path next to the source with .jpg extension
    const base = name.replace(/\.(heic|heif)$/i, '');
    const dstPath = `${base}.jpg`;

    // Upload JPEG with a fresh download token and a flag to avoid loops
    const downloadToken = uuidv4();
    const dstFile = bucket.file(dstPath);
    await dstFile.save(jpeg, {
      contentType: 'image/jpeg',
      metadata: {
        firebaseStorageDownloadTokens: downloadToken,
        converted: 'true',
        // Preserve a subset of original metadata to allow Firestore updates
        firestoreDocPath: metadata['firestoreDocPath'] || '',
        firestoreField: metadata['firestoreField'] || '',
        op: metadata['op'] || '',
        entity: metadata['entity'] || '',
        uid: metadata['uid'] || '',
      },
      resumable: false,
      public: false,
      validation: false,
    });

    const httpsUrl = buildDownloadUrl(bucketName, dstPath, downloadToken);
    logger.info('JPEG generated', { httpsUrl });

    // Update Firestore document if provided in metadata
    const docPath = metadata['firestoreDocPath'];
    const field = metadata['firestoreField'];
    const op = (metadata['op'] || '').toLowerCase();
    if (docPath && field) {
      try {
        const db = admin.firestore();
        const ref = db.doc(docPath);
        if (op === 'arrayunion') {
          // Replace any HEIC URL with JPEG URL
          await ref.update({
            [field]: admin.firestore.FieldValue.arrayUnion(httpsUrl),
          });
          // Best-effort: remove the original HEIC URL if it was saved earlier
          const originalToken = (obj.metadata && (obj.metadata as any)['firebaseStorageDownloadTokens']) as string | undefined;
          const originalUrl = originalToken ? buildDownloadUrl(bucketName, name, originalToken) : undefined;
          if (originalUrl) {
            await ref.update({
              [field]: admin.firestore.FieldValue.arrayRemove(originalUrl),
            }).catch(() => {});
          }
        } else {
          // Default to set/overwrite the single field
          await ref.set({ [field]: httpsUrl }, { merge: true });
        }
      } catch (e) {
        logger.error('Failed to update Firestore with JPEG URL', { e });
      }
    }

    // If this is a user avatar, also update Firebase Auth profile photoURL
    if ((metadata['entity'] || '') === 'user' && metadata['uid']) {
      try {
        await admin.auth().updateUser(metadata['uid'], { photoURL: httpsUrl });
      } catch (e) {
        logger.warn('Failed to update Auth user photoURL', { uid: metadata['uid'], e });
      }
    }

    logger.info('HEIC transcode completed', { name, dstPath });
  } catch (e) {
    logger.error('HEIC transcode failed', { name, e });
  }
});
