import type { SQLiteDatabase } from 'expo-sqlite';
import type { TileSlot, TileSlotKind } from '../../types/hands';
import type { TileSuit } from '../../types/tiles';

interface SlotRow {
  id: string;
  hand_id: string;
  kind: string;
  sort_order: number;
  concrete_suit: string | null;
  concrete_value: string | null;
  flex_value: number | null;
  suit_group_id: string | null;
  run_group_id: string | null;
  run_suit_group_id: string | null;
  run_group_ref: string | null;
  offset_val: number | null;
  is_joker_eligible: number;
  slot_count: number;
}

function rowToSlot(row: SlotRow): TileSlot {
  const base = {
    id: row.id,
    kind: row.kind as TileSlotKind,
    isJokerEligible: row.is_joker_eligible === 1,
    count: row.slot_count,
  };

  switch (row.kind as TileSlotKind) {
    case 'CONCRETE':
      return {
        ...base,
        concrete: {
          suit: row.concrete_suit! as TileSuit,
          value: isNaN(Number(row.concrete_value!))
            ? (row.concrete_value! as any)
            : (Number(row.concrete_value!) as any),
        },
      };
    case 'SUIT_FLEXIBLE':
      return { ...base, flexValue: row.flex_value! as any, suitGroupId: row.suit_group_id! };
    case 'RUN_ANCHOR':
      return { ...base, runGroupId: row.run_group_id!, runSuitGroupId: row.run_suit_group_id ?? undefined };
    case 'RUN_OFFSET':
      return { ...base, runGroupRef: row.run_group_ref!, offset: row.offset_val! };
    case 'JOKER':
      return base;
    default:
      return base;
  }
}

export class SlotRepository {
  private constructor(private db: SQLiteDatabase) {}

  static create(db: SQLiteDatabase) {
    return new SlotRepository(db);
  }

  async findByHandId(handId: string): Promise<TileSlot[]> {
    const rows = await this.db.getAllAsync<SlotRow>(
      'SELECT * FROM slots WHERE hand_id = ? ORDER BY sort_order ASC;',
      [handId],
    );
    return rows.map(rowToSlot);
  }

  async save(slot: TileSlot, handId: string, sortOrder: number): Promise<void> {
    await this.db.runAsync(
      `INSERT OR REPLACE INTO slots
         (id, hand_id, kind, sort_order,
          concrete_suit, concrete_value,
          flex_value, suit_group_id,
          run_group_id, run_suit_group_id,
          run_group_ref, offset_val,
          is_joker_eligible, slot_count)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);`,
      [
        slot.id,
        handId,
        slot.kind,
        sortOrder,
        slot.concrete?.suit ?? null,
        slot.concrete?.value !== undefined ? String(slot.concrete.value) : null,
        slot.flexValue ?? null,
        slot.suitGroupId ?? null,
        slot.runGroupId ?? null,
        slot.runSuitGroupId ?? null,
        slot.runGroupRef ?? null,
        slot.offset ?? null,
        slot.isJokerEligible ? 1 : 0,
        slot.count,
      ],
    );
  }

  async deleteByHandId(handId: string): Promise<void> {
    await this.db.runAsync('DELETE FROM slots WHERE hand_id = ?;', [handId]);
  }
}
