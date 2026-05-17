import type { SQLiteDatabase } from 'expo-sqlite';
import {
  CREATE_COLLECTIONS_TABLE,
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

  // Future migrations slot in here:
  // if (currentVersion < 2) await applyMigration2(db);
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
