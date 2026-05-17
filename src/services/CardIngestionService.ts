import type { CardCollection } from '../types/collections';
import type {
  IngestionResult,
  ManualIngestionPayload,
  OCRIngestionOptions,
  SharePayload,
  ValidationResult,
} from '../types/ingestion';
import { base64Encode, base64Decode, sha256Digest } from '../utils/cryptoUtils';
import { validateCollectionSchema } from '../utils/validationUtils';

// ── CryptoProvider interface ─────────────────────────────────────────────────

/**
 * Pluggable encode/decode layer for share strings.
 * The default implementation uses Base64.
 * A future AES-256 passphrase implementation can be swapped in
 * by passing a different `CryptoProvider` without changing any calling code.
 */
export interface CryptoProvider {
  encode(data: string): string;
  decode(encoded: string): string;
}

const defaultCryptoProvider: CryptoProvider = {
  encode: base64Encode,
  decode: base64Decode,
};

// ── ICardIngestionService interface ──────────────────────────────────────────

export interface ICardIngestionService {
  /** Path A: Build and validate a collection from manual form input. */
  ingestManual(payload: ManualIngestionPayload): Promise<IngestionResult>;

  /** Path B: Decode a peer-shared Base64 (or encrypted) string back to a CardCollection. */
  ingestFromShareString(shareString: string, crypto?: CryptoProvider): Promise<IngestionResult>;

  /**
   * Path C (STUB — v1 not implemented).
   * Future: accept an image buffer, run on-device OCR, optionally clean via LLM,
   * then route to the same validateCollection() terminal node as Paths A and B.
   */
  ingestFromOCR(options: OCRIngestionOptions): Promise<IngestionResult>;

  /** Serialize a CardCollection to a shareable Base64 (or encrypted) string. */
  serializeCollection(collection: CardCollection, crypto?: CryptoProvider): Promise<string>;

  /** Validate raw JSON against the CardCollection schema. Used by all ingestion paths. */
  validateCollection(raw: unknown): ValidationResult;
}

// ── DefaultCardIngestionService ───────────────────────────────────────────────

export class DefaultCardIngestionService implements ICardIngestionService {

  validateCollection(raw: unknown): ValidationResult {
    return validateCollectionSchema(raw);
  }

  async ingestManual(payload: ManualIngestionPayload): Promise<IngestionResult> {
    const now = Date.now();
    const collection: CardCollection = {
      id: `col_${now}_${Math.random().toString(36).slice(2, 8)}`,
      name: payload.collectionName,
      description: payload.description,
      source: 'USER_CREATED',
      schemaVersion: 1,
      isReadOnly: false,
      hands: payload.hands.map((h, i) => ({
        id: `hand_${now}_${i}_${Math.random().toString(36).slice(2, 6)}`,
        collectionId: '', // filled below after collection id is known
        name: h.name,
        displayLabel: h.displayLabel,
        slots: h.slots,
        pointValue: h.pointValue,
        isConcealed: h.isConcealed,
        tags: [],
        createdAt: now,
        updatedAt: now,
      })).map((h) => ({ ...h, collectionId: `col_${now}_${Math.random().toString(36).slice(2, 8)}` })),
      createdAt: now,
      updatedAt: now,
    };

    // Re-build hands with correct collectionId
    const finalCollection: CardCollection = {
      ...collection,
      hands: payload.hands.map((h, i) => ({
        id: `hand_${now}_${i}_${Math.random().toString(36).slice(2, 6)}`,
        collectionId: collection.id,
        name: h.name,
        displayLabel: h.displayLabel,
        slots: h.slots,
        pointValue: h.pointValue,
        isConcealed: h.isConcealed,
        tags: [],
        createdAt: now,
        updatedAt: now,
      })),
    };

    const validation = this.validateCollection(finalCollection);
    if (!validation.valid) {
      return { success: false, error: validation.errors.join('; '), code: 'SCHEMA_VALIDATION_FAILED' };
    }
    return { success: true, collection: finalCollection };
  }

  async serializeCollection(
    collection: CardCollection,
    crypto: CryptoProvider = defaultCryptoProvider,
  ): Promise<string> {
    const json = JSON.stringify(collection);
    const checksum = await sha256Digest(json);
    const payload: SharePayload = { payloadVersion: '1', collection, checksum };
    return crypto.encode(JSON.stringify(payload));
  }

  async ingestFromShareString(
    shareString: string,
    crypto: CryptoProvider = defaultCryptoProvider,
  ): Promise<IngestionResult> {
    let decoded: string;
    try {
      decoded = crypto.decode(shareString.trim());
    } catch {
      return { success: false, error: 'Failed to decode share string.', code: 'DECODE_FAILED' };
    }

    let payload: SharePayload;
    try {
      payload = JSON.parse(decoded) as SharePayload;
    } catch {
      return { success: false, error: 'Share string contains invalid JSON.', code: 'INVALID_JSON' };
    }

    if (payload.payloadVersion !== '1') {
      return {
        success: false,
        error: `Unsupported share string version: ${payload.payloadVersion}`,
        code: 'VERSION_UNSUPPORTED',
      };
    }

    // Verify integrity
    const expectedChecksum = await sha256Digest(JSON.stringify(payload.collection));
    if (expectedChecksum !== payload.checksum) {
      return { success: false, error: 'Share string checksum mismatch — data may be corrupted.', code: 'CHECKSUM_MISMATCH' };
    }

    const validation = this.validateCollection(payload.collection);
    if (!validation.valid) {
      return { success: false, error: validation.errors.join('; '), code: 'SCHEMA_VALIDATION_FAILED' };
    }

    // Mark as imported
    const imported: CardCollection = { ...payload.collection, source: 'IMPORTED', isReadOnly: false };
    return { success: true, collection: imported };
  }

  /**
   * OCR ingestion — NOT IMPLEMENTED IN v1.
   *
   * Extension point for v2: this method should:
   *   1. Accept an OCRIngestionOptions containing an imageBlob and OCR provider selection.
   *   2. Run on-device OCR (e.g., Google ML Kit via @react-native-ml-kit/text-recognition).
   *   3. Optionally pass the raw text through an LLM cleaner (see LLMCleanerConfig).
   *   4. Parse the cleaned text into a ManualIngestionPayload.
   *   5. Route to this.ingestManual() — the same validated terminal node as Path A.
   *
   * The UI (CameraOCRScreen) and ScoringEngine are fully decoupled from this path.
   * Only this method needs to be implemented; no other files change.
   */
  async ingestFromOCR(_options: OCRIngestionOptions): Promise<IngestionResult> {
    throw new Error(
      'OCR ingestion is not yet implemented. This is the v2 extension point. ' +
      'See CardIngestionService.ingestFromOCR() for the implementation guide.',
    );
  }
}

/** Singleton instance for use across the app. */
export const cardIngestionService = new DefaultCardIngestionService();
