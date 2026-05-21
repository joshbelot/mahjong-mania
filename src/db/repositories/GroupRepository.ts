import type { SQLiteDatabase } from 'expo-sqlite';
import { useSQLiteContext } from 'expo-sqlite';
import type { HandGroup } from '../../types/collections';

interface HandGroupRow {
  id: string;
  collection_id: string;
  name: string;
  sort_order: number;
  created_at: number;
  updated_at: number;
}

function rowToGroup(row: HandGroupRow): HandGroup {
  return {
    id: row.id,
    collectionId: row.collection_id,
    name: row.name,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class GroupRepository {
  private constructor(private readonly db: SQLiteDatabase) {}

  static create(db: SQLiteDatabase): GroupRepository {
    return new GroupRepository(db);
  }

  async findByCollectionId(collectionId: string): Promise<HandGroup[]> {
    const rows = await this.db.getAllAsync<HandGroupRow>(
      'SELECT * FROM hand_groups WHERE collection_id = ? ORDER BY sort_order ASC, created_at ASC;',
      [collectionId],
    );
    return rows.map(rowToGroup);
  }

  async save(group: HandGroup): Promise<void> {
    await this.db.runAsync(
      `INSERT OR REPLACE INTO hand_groups
         (id, collection_id, name, sort_order, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?);`,
      [group.id, group.collectionId, group.name, group.sortOrder, group.createdAt, group.updatedAt],
    );
  }

  async deleteByCollectionId(collectionId: string): Promise<void> {
    await this.db.runAsync('DELETE FROM hand_groups WHERE collection_id = ?;', [collectionId]);
  }
}

export function useGroupRepository() {
  const db = useSQLiteContext();
  return GroupRepository.create(db);
}
