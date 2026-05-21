import type { SQLiteDatabase } from 'expo-sqlite';
import {
  CREATE_COLLECTIONS_TABLE,
  CREATE_HAND_GROUPS_TABLE,
  CREATE_HANDS_TABLE,
  CREATE_SLOTS_TABLE,
  CREATE_MIGRATIONS_TABLE,
  CREATE_INDEXES,
  SCHEMA_VERSION,
} from './schema';

/**
 * Idempotent DDL runner. Creates tables if they don't exist and applies any
 * pending version-gated migrations in order. Safe to call on every app launch.
 */
export async function runMigrations(db: SQLiteDatabase): Promise<void> {
  // Ensure migration tracking table exists first
  await db.execAsync(CREATE_MIGRATIONS_TABLE);

  // Determine the highest already-applied migration version
  const row = await db.getFirstAsync<{ max_version: number | null }>(
    'SELECT MAX(version) AS max_version FROM schema_migrations;',
  );
  const currentVersion = row?.max_version ?? 0;

  if (currentVersion < 1) {
    await applyMigration1(db);
  }

  if (currentVersion < 2) {
    await applyMigration2(db);
  }
}

// ── Migration v1 — initial schema ────────────────────────────────────────────

async function applyMigration1(db: SQLiteDatabase): Promise<void> {
  await db.withTransactionAsync(async () => {
    await db.execAsync(CREATE_COLLECTIONS_TABLE);
    await db.execAsync(CREATE_HANDS_TABLE);
    await db.execAsync(CREATE_SLOTS_TABLE);
    await db.execAsync(CREATE_INDEXES);
    await db.runAsync(
      'INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?);',
      [1, Date.now()],
    );
  });
}

// ── Migration v2 — hand groups + alternate slots + constraint descriptions ────

async function applyMigration2(db: SQLiteDatabase): Promise<void> {
  await db.withTransactionAsync(async () => {
    // 1. Create hand_groups table + index
    await db.execAsync(CREATE_HAND_GROUPS_TABLE);
    await db.execAsync(
      'CREATE INDEX IF NOT EXISTS idx_hand_groups_collection ON hand_groups(collection_id);',
    );

    // 2. Add new columns to existing hands rows
    await db.execAsync('ALTER TABLE hands ADD COLUMN group_id TEXT;');
    await db.execAsync('ALTER TABLE hands ADD COLUMN groups_json TEXT;');
    await db.execAsync('ALTER TABLE hands ADD COLUMN alternate_slots_json TEXT;');
    await db.execAsync('ALTER TABLE hands ADD COLUMN alternate_groups_json TEXT;');
    await db.execAsync('ALTER TABLE hands ADD COLUMN constraint_description TEXT;');

    // 3. Migrate tags[0] → HandGroup rows and backfill group_id on each hand
    type HandMigRow = { id: string; collection_id: string; tags: string; display_label: string };
    const hands = await db.getAllAsync<HandMigRow>(
      'SELECT id, collection_id, tags, display_label FROM hands;',
    );

    // Map "collectionId:tagName" → generated groupId to avoid duplicate groups
    const groupMap = new Map<string, string>();
    let sortCounter = 0;
    const now = Date.now();

    for (const hand of hands) {
      let tags: string[] = [];
      try { tags = JSON.parse(hand.tags) as string[]; } catch { /* ignore */ }
      const tagName = tags[0];

      if (tagName) {
        const mapKey = `${hand.collection_id}:${tagName}`;
        let groupId = groupMap.get(mapKey);
        if (!groupId) {
          groupId = `grp_${now}_${Math.random().toString(36).slice(2, 8)}`;
          groupMap.set(mapKey, groupId);
          await db.runAsync(
            'INSERT INTO hand_groups (id, collection_id, name, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?);',
            [groupId, hand.collection_id, tagName, sortCounter++, now, now],
          );
        }
        await db.runAsync(
          'UPDATE hands SET group_id = ?, constraint_description = ? WHERE id = ?;',
          [groupId, hand.display_label, hand.id],
        );
      } else {
        // No tag — still migrate constraint_description from display_label
        await db.runAsync(
          'UPDATE hands SET constraint_description = ? WHERE id = ?;',
          [hand.display_label, hand.id],
        );
      }
    }

    await db.runAsync(
      'INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?);',
      [2, Date.now()],
    );
  });
}
