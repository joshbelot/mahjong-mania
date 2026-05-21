import type { SQLiteDatabase } from 'expo-sqlite';
import { useSQLiteContext } from 'expo-sqlite';
import type { CustomHand, TileSlot, GroupDef } from '../../types/hands';
import { SlotRepository } from './SlotRepository';

interface HandRow {
  id: string;
  collection_id: string;
  name: string;
  display_label: string;
  point_value: number | null;
  is_concealed: number;
  tags: string;
  sort_order: number;
  created_at: number;
  updated_at: number;
  group_id: string | null;
  groups_json: string | null;
  alternate_slots_json: string | null;
  alternate_groups_json: string | null;
  constraint_description: string | null;
}

function rowToHand(row: HandRow, slots: CustomHand['slots']): CustomHand {
  let groupDefs: GroupDef[] | undefined;
  let alternateSlots: TileSlot[] | undefined;
  let alternateGroupDefs: GroupDef[] | undefined;
  try { if (row.groups_json) groupDefs = JSON.parse(row.groups_json) as GroupDef[]; } catch { /* ignore */ }
  try { if (row.alternate_slots_json) alternateSlots = JSON.parse(row.alternate_slots_json) as TileSlot[]; } catch { /* ignore */ }
  try { if (row.alternate_groups_json) alternateGroupDefs = JSON.parse(row.alternate_groups_json) as GroupDef[]; } catch { /* ignore */ }

  return {
    id: row.id,
    collectionId: row.collection_id,
    name: row.name,
    displayLabel: row.display_label,
    pointValue: row.point_value ?? undefined,
    isConcealed: row.is_concealed === 1,
    tags: JSON.parse(row.tags) as string[],
    slots,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    groupId: row.group_id ?? undefined,
    groupDefs,
    alternateSlots,
    alternateGroupDefs,
    constraintDescription: row.constraint_description ?? undefined,
  };
}

/**
 * Non-hook version used internally by CollectionRepository inside transactions.
 */
export class HandRepository {
  private slotRepo: ReturnType<typeof SlotRepository.create>;

  private constructor(private db: SQLiteDatabase) {
    this.slotRepo = SlotRepository.create(db);
  }

  static create(db: SQLiteDatabase) {
    return new HandRepository(db);
  }

  async findByCollectionId(collectionId: string): Promise<CustomHand[]> {
    const rows = await this.db.getAllAsync<HandRow>(
      'SELECT * FROM hands WHERE collection_id = ? ORDER BY sort_order ASC;',
      [collectionId],
    );
    return Promise.all(
      rows.map(async (row) => {
        const slots = await this.slotRepo.findByHandId(row.id);
        return rowToHand(row, slots);
      }),
    );
  }

  async findById(id: string): Promise<CustomHand | null> {
    const row = await this.db.getFirstAsync<HandRow>(
      'SELECT * FROM hands WHERE id = ?;',
      [id],
    );
    if (!row) return null;
    const slots = await this.slotRepo.findByHandId(row.id);
    return rowToHand(row, slots);
  }

  async save(hand: CustomHand): Promise<void> {
    await this.db.runAsync(
      `INSERT OR REPLACE INTO hands
         (id, collection_id, name, display_label, point_value, is_concealed, tags, sort_order,
          created_at, updated_at, group_id, groups_json, alternate_slots_json, alternate_groups_json,
          constraint_description)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);`,
      [
        hand.id,
        hand.collectionId,
        hand.name,
        hand.displayLabel,
        hand.pointValue ?? null,
        hand.isConcealed ? 1 : 0,
        JSON.stringify(hand.tags),
        0,
        hand.createdAt,
        hand.updatedAt,
        hand.groupId ?? null,
        hand.groupDefs ? JSON.stringify(hand.groupDefs) : null,
        hand.alternateSlots ? JSON.stringify(hand.alternateSlots) : null,
        hand.alternateGroupDefs ? JSON.stringify(hand.alternateGroupDefs) : null,
        hand.constraintDescription ?? null,
      ],
    );
    // Delete existing slots then re-insert (simpler than diffing)
    await this.slotRepo.deleteByHandId(hand.id);
    for (let i = 0; i < hand.slots.length; i++) {
      await this.slotRepo.save(hand.slots[i], hand.id, i);
    }
  }

  async delete(id: string): Promise<void> {
    await this.db.runAsync('DELETE FROM hands WHERE id = ?;', [id]);
  }
}

/** Hook-based variant for direct component/hook use. */
export function useHandRepository() {
  const db = useSQLiteContext();
  return HandRepository.create(db);
}
