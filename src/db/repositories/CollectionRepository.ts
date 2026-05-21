import { useSQLiteContext, type SQLiteDatabase } from 'expo-sqlite';
import type { CardCollection, CollectionSource } from '../../types/collections';
import { HandRepository } from './HandRepository';
import { GroupRepository } from './GroupRepository';

interface CollectionRow {
  id: string;
  name: string;
  description: string | null;
  source: string;
  schema_version: number;
  is_read_only: number;
  created_at: number;
  updated_at: number;
}

function rowToCollection(row: CollectionRow, hands: CardCollection['hands'], groups: CardCollection['groups']): CardCollection {
  return {
    id: row.id,
    name: row.name,
    description: row.description ?? undefined,
    source: row.source as CollectionSource,
    schemaVersion: row.schema_version,
    isReadOnly: row.is_read_only === 1,
    hands,
    groups,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class CollectionRepository {
  private constructor(private readonly db: SQLiteDatabase) {}

  static create(db: SQLiteDatabase): CollectionRepository {
    return new CollectionRepository(db);
  }

  async findAll(): Promise<CardCollection[]> {
    const handRepo = HandRepository.create(this.db);
    const groupRepo = GroupRepository.create(this.db);
    const rows = await this.db.getAllAsync<CollectionRow>(
      'SELECT * FROM collections ORDER BY updated_at DESC;',
    );
    return Promise.all(
      rows.map(async (row) => {
        const [hands, groups] = await Promise.all([
          handRepo.findByCollectionId(row.id),
          groupRepo.findByCollectionId(row.id),
        ]);
        return rowToCollection(row, hands, groups);
      }),
    );
  }

  async findById(id: string): Promise<CardCollection | null> {
    const handRepo = HandRepository.create(this.db);
    const groupRepo = GroupRepository.create(this.db);
    const row = await this.db.getFirstAsync<CollectionRow>(
      'SELECT * FROM collections WHERE id = ?;',
      [id],
    );
    if (!row) return null;
    const [hands, groups] = await Promise.all([
      handRepo.findByCollectionId(row.id),
      groupRepo.findByCollectionId(row.id),
    ]);
    return rowToCollection(row, hands, groups);
  }

  async save(collection: CardCollection): Promise<void> {
    const handRepo = HandRepository.create(this.db);
    const groupRepo = GroupRepository.create(this.db);
    await this.db.withTransactionAsync(async () => {
      await this.db.runAsync(
        `INSERT OR REPLACE INTO collections
           (id, name, description, source, schema_version, is_read_only, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?);`,
        [
          collection.id,
          collection.name,
          collection.description ?? null,
          collection.source,
          collection.schemaVersion,
          collection.isReadOnly ? 1 : 0,
          collection.createdAt,
          collection.updatedAt,
        ],
      );
      // Persist groups (delete-replace strategy)
      await groupRepo.deleteByCollectionId(collection.id);
      for (const group of collection.groups) {
        await groupRepo.save(group);
      }
      for (const hand of collection.hands) {
        await handRepo.save(hand);
      }
    });
  }

  async update(
    id: string,
    patch: Partial<Pick<CardCollection, 'name' | 'description' | 'updatedAt'>>,
  ): Promise<void> {
    const fields: string[] = [];
    const values: (string | number | null)[] = [];
    if (patch.name !== undefined) { fields.push('name = ?'); values.push(patch.name); }
    if (patch.description !== undefined) { fields.push('description = ?'); values.push(patch.description ?? null); }
    if (patch.updatedAt !== undefined) { fields.push('updated_at = ?'); values.push(patch.updatedAt); }
    if (fields.length === 0) return;
    values.push(id);
    await this.db.runAsync(`UPDATE collections SET ${fields.join(', ')} WHERE id = ?;`, values);
  }

  async delete(id: string): Promise<void> {
    await this.db.runAsync('DELETE FROM collections WHERE id = ?;', [id]);
  }
}

export function useCollectionRepository() {
  const db = useSQLiteContext();
  const repo = CollectionRepository.create(db);
  return repo;
}
