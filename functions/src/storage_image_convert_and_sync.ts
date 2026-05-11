import { onObjectFinalized } from "firebase-functions/v2/storage";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import sharp from "sharp";
import { v4 as uuidv4 } from "uuid";

// Initialize Admin SDK only once
try { admin.app(); } catch { admin.initializeApp(); }

const DISPLAYABLE = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
const HEIC = new Set(["image/heic", "image/heif", "image/heic-sequence", "image/heif-sequence"]);

export const storage_image_convert_and_sync = onObjectFinalized({ region: "us-central1", timeoutSeconds: 540, memory: "1GiB" }, async (event) => {
  const object = event.data;
  const bucketName = object.bucket;
  const filePath = object.name || "";
  const contentType = object.contentType || "";
  const meta = object.metadata || {} as Record<string, string>;

  if (!filePath) { logger.warn("[convert] Missing filePath"); return; }

  const bucket = admin.storage().bucket(bucketName);
  const file = bucket.file(filePath);

  const firestoreDocPath = meta["firestoreDocPath"] || "";
  const firestoreField = meta["firestoreField"] || "";
  const op = (meta["op"] || "").toLowerCase(); // 'set' | 'arrayunion'

  const alreadyConverted = meta["converted"] === "true" || /(_conv)\.jpe?g$/i.test(filePath);
  if (alreadyConverted) {
    logger.log("[convert] Skip converted file:", filePath);
    return;
  }

  // Helper to compute a Firebase Storage download URL from known token
  const buildDownloadUrl = (path: string, token: string) => `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;

  const ensureTokenOn = async (f: any, currentMeta: any): Promise<string> => {
    let token: string | undefined = currentMeta?.metadata?.firebaseStorageDownloadTokens || currentMeta?.firebaseStorageDownloadTokens;
    if (!token) {
      token = uuidv4();
      // Preserve existing metadata while adding token
      const newMd = { contentType: currentMeta.contentType || contentType || "application/octet-stream", metadata: { ...(currentMeta.metadata || {}), firebaseStorageDownloadTokens: token } };
      await f.setMetadata(newMd);
      return token as string;
    }
    return token as string;
  };

  try {
    // Case A: displayable as-is (jpeg/png/webp/gif) -> optionally sync Firestore if instructed
    if (DISPLAYABLE.has(contentType)) {
      const [currentMd] = await file.getMetadata();
      const token = await ensureTokenOn(file, currentMd);
      const url = buildDownloadUrl(filePath, token);
      logger.log("[convert] Displayable asset, url:", url);

      if (firestoreDocPath && firestoreField) {
        const ref = admin.firestore().doc(firestoreDocPath);
        if (op === "arrayunion") await ref.set({ [firestoreField]: admin.firestore.FieldValue.arrayUnion(url) }, { merge: true });
        else await ref.set({ [firestoreField]: url }, { merge: true });
        // If it's a listing, ensure cover fields are set if missing
        if (firestoreDocPath.startsWith("listings/")) {
          const snap = await ref.get();
          const data = (snap.exists ? (snap.data() as Record<string, any>) : {}) || {};
          const cover = (data["coverImageUrl"] || data["imageUrl"] || "").toString();
          if (!cover || !/^https?:\/\//i.test(cover)) {
            await ref.set({ coverImageUrl: url, imageUrl: url, image: url }, { merge: true });
          }
        }
        logger.log("[convert] Firestore updated (displayable)", firestoreDocPath, firestoreField);
      }
      return;
    }

    // Case B: HEIC/HEIF -> convert to JPEG using sharp
    if (HEIC.has(contentType)) {
      logger.log("[convert] Converting HEIC to JPEG:", filePath);
      const [buf] = await file.download();
      const jpeg = await sharp(buf).rotate().jpeg({ quality: 85 }).toBuffer();

      const destPath = filePath.replace(/\.[^.]+$/, "") + "_conv.jpg";
      const dest = bucket.file(destPath);
      const token = uuidv4();
      await dest.save(jpeg, { metadata: { contentType: "image/jpeg", metadata: { ...meta, converted: "true", firebaseStorageDownloadTokens: token } } });
      const url = buildDownloadUrl(destPath, token);

      if (firestoreDocPath && firestoreField) {
        const ref = admin.firestore().doc(firestoreDocPath);
        if (op === "arrayunion") await ref.set({ [firestoreField]: admin.firestore.FieldValue.arrayUnion(url) }, { merge: true });
        else await ref.set({ [firestoreField]: url }, { merge: true });
        if (firestoreDocPath.startsWith("listings/")) {
          const snap = await ref.get();
          const data = (snap.exists ? (snap.data() as Record<string, any>) : {}) || {};
          const cover = (data["coverImageUrl"] || data["imageUrl"] || "").toString();
          if (!cover || !/^https?:\/\//i.test(cover)) {
            await ref.set({ coverImageUrl: url, imageUrl: url, image: url }, { merge: true });
          }
        }
        logger.log("[convert] Firestore updated (converted)", firestoreDocPath, firestoreField);
      }
      return;
    }

    // Case C: other non-displayable types -> log and if metadata present, still try to sync using token URL
    const [currentMd] = await file.getMetadata();
    const token = await ensureTokenOn(file, currentMd);
    const url = buildDownloadUrl(filePath, token);
    logger.log("[convert] Non-displayable contentType=", contentType, " url:", url);
    if (firestoreDocPath && firestoreField) {
      const ref = admin.firestore().doc(firestoreDocPath);
      if (op === "arrayunion") await ref.set({ [firestoreField]: admin.firestore.FieldValue.arrayUnion(url) }, { merge: true });
      else await ref.set({ [firestoreField]: url }, { merge: true });
      if (firestoreDocPath.startsWith("listings/")) {
        const snap = await ref.get();
        const data = (snap.exists ? (snap.data() as Record<string, any>) : {}) || {};
        const cover = (data["coverImageUrl"] || data["imageUrl"] || "").toString();
        if (!cover || !/^https?:\/\//i.test(cover)) {
          await ref.set({ coverImageUrl: url, imageUrl: url, image: url }, { merge: true });
        }
      }
      logger.log("[convert] Firestore updated (non-displayable)", firestoreDocPath, firestoreField);
    }
  } catch (err) {
    logger.error("[convert] Failure:", err);
  }
});
