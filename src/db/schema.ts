/**
 * Schema version — increment when adding/changing tables.
 * runMigrations() uses this to apply only new DDL.
 */
export const SCHEMA_VERSION = 2;

/**
 * DDL for the `collections` table.
 * All collection metadata is stored flat; the hands array is NOT stored here —
 * it is reconstructed by joining `hands` + `slots` in the repository layer.
 */
export const CREATE_COLLECTIONS_TABLE = `
  CREATE TABLE IF NOT EXISTS collections (
    id             TEXT PRIMARY KEY NOT NULL,
    name           TEXT NOT NULL,
    description    TEXT,
    source         TEXT NOT NULL DEFAULT 'USER_CREATED',
    schema_version INTEGER NOT NULL DEFAULT 1,
    is_read_only   INTEGER NOT NULL DEFAULT 0,
    created_at     INTEGER NOT NULL,
    updated_at     INTEGER NOT NULL
  );
`;

/**
 * DDL for the `hand_groups` table.
 * Each group is a named section heading inside a collection (e.g. "QUINTS", "2468").
 */
export const CREATE_HAND_GROUPS_TABLE = `
  CREATE TABLE IF NOT EXISTS hand_groups (
    id            TEXT PRIMARY KEY NOT NULL,
    collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    created_at    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL
  );
`;

/**
 * DDL for the `hands` table.
 * Each hand belongs to exactly one collection.
 */
export const CREATE_HANDS_TABLE = `
  CREATE TABLE IF NOT EXISTS hands (
    id                    TEXT PRIMARY KEY NOT NULL,
    collection_id         TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    name                  TEXT NOT NULL,
    display_label         TEXT NOT NULL,
    point_value           INTEGER,
    is_concealed          INTEGER NOT NULL DEFAULT 0,
    tags                  TEXT NOT NULL DEFAULT '[]',
    sort_order            INTEGER NOT NULL DEFAULT 0,
    created_at            INTEGER NOT NULL,
    updated_at            INTEGER NOT NULL,
    group_id              TEXT,
    groups_json           TEXT,
    alternate_slots_json  TEXT,
    alternate_groups_json TEXT,
    constraint_description TEXT
  );
`;

/**
 * DDL for the `slots` table.
 * All TileSlot fields are stored flat. Nullable fields correspond to optional
 * TileSlot properties (only populated for the relevant `kind`).
 */
export const CREATE_SLOTS_TABLE = `
  CREATE TABLE IF NOT EXISTS slots (
    id                TEXT PRIMARY KEY NOT NULL,
    hand_id           TEXT NOT NULL REFERENCES hands(id) ON DELETE CASCADE,
    kind              TEXT NOT NULL,
    sort_order        INTEGER NOT NULL DEFAULT 0,

    -- CONCRETE kind
    concrete_suit     TEXT,
    concrete_value    TEXT,

    -- SUIT_FLEXIBLE kind
    flex_value        INTEGER,
    suit_group_id     TEXT,

    -- RUN_ANCHOR kind
    run_group_id      TEXT,
    run_suit_group_id TEXT,

    -- RUN_OFFSET kind
    run_group_ref     TEXT,
    offset_val        INTEGER,

    -- Universal
    is_joker_eligible INTEGER NOT NULL DEFAULT 0,
    slot_count        INTEGER NOT NULL DEFAULT 1
  );
`;

/** DDL for the migration tracking table. */
export const CREATE_MIGRATIONS_TABLE = `
  CREATE TABLE IF NOT EXISTS schema_migrations (
    version    INTEGER PRIMARY KEY NOT NULL,
    applied_at INTEGER NOT NULL
  );
`;

/** Indexes to speed up common queries. */
export const CREATE_INDEXES = `
  CREATE INDEX IF NOT EXISTS idx_hands_collection ON hands(collection_id);
  CREATE INDEX IF NOT EXISTS idx_slots_hand ON slots(hand_id);
  CREATE INDEX IF NOT EXISTS idx_hand_groups_collection ON hand_groups(collection_id);
`;
