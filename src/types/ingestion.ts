import type { CardCollection } from './collections';
import type { TileSlot } from './hands';

// ── Manual ingestion ─────────────────────────────────────────────────────────

export interface ManualHandInput {
  readonly name: string;
  readonly displayLabel: string;
  readonly slots: TileSlot[];
  readonly pointValue?: number;
  readonly isConcealed: boolean;
}

export interface ManualIngestionPayload {
  readonly collectionName: string;
  readonly description?: string;
  readonly hands: ManualHandInput[];
}

// ── Share string (P2P) ───────────────────────────────────────────────────────

export interface SharePayload {
  /** Bump this when the serialization format changes. */
  readonly payloadVersion: '1';
  readonly collection: CardCollection;
  /** SHA-256 hex digest of JSON.stringify(collection). Verified on import. */
  readonly checksum: string;
}

// ── Ingestion result ─────────────────────────────────────────────────────────

export type IngestionErrorCode =
  | 'DECODE_FAILED'
  | 'INVALID_JSON'
  | 'CHECKSUM_MISMATCH'
  | 'VERSION_UNSUPPORTED'
  | 'SCHEMA_VALIDATION_FAILED';

export type IngestionResult =
  | { readonly success: true; readonly collection: CardCollection }
  | { readonly success: false; readonly error: string; readonly code: IngestionErrorCode };

export type ValidationResult =
  | { readonly valid: true }
  | { readonly valid: false; readonly errors: string[] };

// ── Future OCR types (v2 stub — not implemented) ─────────────────────────────

export type OCRProvider = 'ML_KIT' | 'TESSERACT';

export interface LLMCleanerConfig {
  readonly endpoint: string;
  readonly model: string;
  readonly apiKey?: string;
}

/**
 * Options for the future OCR-based ingestion path.
 * Defined here so the interface contract is locked in; implementation is v2.
 */
export interface OCRIngestionOptions {
  readonly imageBlob: ArrayBuffer;
  readonly ocrProvider: OCRProvider;
  readonly llmCleanerConfig?: LLMCleanerConfig;
}
