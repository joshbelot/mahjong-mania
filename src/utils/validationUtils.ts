import type { CardCollection } from '../types/collections';
import type { CustomHand } from '../types/hands';
import type { TileSlot } from '../types/hands';
import type { ValidationResult } from '../types/ingestion';

const REQUIRED_COLLECTION_FIELDS: (keyof CardCollection)[] = [
  'id', 'name', 'source', 'schemaVersion', 'hands', 'createdAt', 'updatedAt', 'isReadOnly',
];

const REQUIRED_HAND_FIELDS: (keyof CustomHand)[] = [
  'id', 'collectionId', 'name', 'displayLabel', 'slots', 'isConcealed', 'tags', 'createdAt', 'updatedAt',
];

const VALID_SLOT_KINDS = new Set(['CONCRETE', 'SUIT_FLEXIBLE', 'RUN_ANCHOR', 'RUN_OFFSET', 'JOKER']);
const VALID_SOURCES = new Set(['USER_CREATED', 'IMPORTED', 'DEMO']);

export function validateCollectionSchema(raw: unknown): ValidationResult {
  const errors: string[] = [];

  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return { valid: false, errors: ['Root value must be an object'] };
  }

  const col = raw as Record<string, unknown>;

  for (const field of REQUIRED_COLLECTION_FIELDS) {
    if (!(field in col)) errors.push(`Missing required field: ${field}`);
  }

  if (errors.length) return { valid: false, errors };

  if (typeof col.id !== 'string' || col.id.trim() === '') {
    errors.push('collection.id must be a non-empty string');
  }
  if (typeof col.name !== 'string' || col.name.trim() === '') {
    errors.push('collection.name must be a non-empty string');
  }
  if (!VALID_SOURCES.has(col.source as string)) {
    errors.push(`collection.source must be one of: ${[...VALID_SOURCES].join(', ')}`);
  }
  if (typeof col.schemaVersion !== 'number') {
    errors.push('collection.schemaVersion must be a number');
  }
  if (!Array.isArray(col.hands)) {
    errors.push('collection.hands must be an array');
    return { valid: false, errors };
  }

  (col.hands as unknown[]).forEach((hand, hi) => {
    if (typeof hand !== 'object' || hand === null) {
      errors.push(`hands[${hi}] must be an object`);
      return;
    }
    const h = hand as Record<string, unknown>;
    for (const field of REQUIRED_HAND_FIELDS) {
      if (!(field in h)) errors.push(`hands[${hi}] missing field: ${field}`);
    }
    if (!Array.isArray(h.slots)) {
      errors.push(`hands[${hi}].slots must be an array`);
      return;
    }
    (h.slots as unknown[]).forEach((slot, si) => {
      if (typeof slot !== 'object' || slot === null) {
        errors.push(`hands[${hi}].slots[${si}] must be an object`);
        return;
      }
      const s = slot as Record<string, unknown>;
      if (!VALID_SLOT_KINDS.has(s.kind as string)) {
        errors.push(`hands[${hi}].slots[${si}].kind is invalid: ${s.kind}`);
      }
      if (typeof s.count !== 'number' || s.count < 1) {
        errors.push(`hands[${hi}].slots[${si}].count must be a positive number`);
      }
    });
  });

  return errors.length ? { valid: false, errors } : { valid: true };
}
