import type { ConcreteTile, NumberTileValue } from './tiles';

/**
 * Opaque group IDs used to link slots that share a constraint.
 * All slots sharing the same SuitGroupId must resolve to the same suit at scoring time.
 */
export type SuitGroupId = string;

/**
 * All RUN_OFFSET slots sharing a RunGroupId are numerically relative to their RUN_ANCHOR.
 */
export type RunGroupId = string;

export type TileSlotKind =
  | 'CONCRETE'       // exact tile is known — stored in `concrete`      (v1 hand entry)
  | 'SUIT_FLEXIBLE'  // numeric value fixed; suit resolved via suitGroupId  (v2)
  | 'RUN_ANCHOR'     // anchor tile of a numeric run                        (v2)
  | 'RUN_OFFSET'     // value = anchor.value + offset, same suit            (v2)
  | 'JOKER';         // must be a Joker tile

export interface TileSlot {
  readonly id: string;
  readonly kind: TileSlotKind;

  // ── CONCRETE kind ───────────────────────────────────────────────────────
  readonly concrete?: ConcreteTile;

  // ── SUIT_FLEXIBLE kind ──────────────────────────────────────────────────
  readonly flexValue?: NumberTileValue;
  readonly suitGroupId?: SuitGroupId;

  // ── RUN_ANCHOR kind ─────────────────────────────────────────────────────
  readonly runGroupId?: RunGroupId;
  readonly runSuitGroupId?: SuitGroupId;

  // ── RUN_OFFSET kind ─────────────────────────────────────────────────────
  readonly runGroupRef?: RunGroupId;
  /** Value = anchor.value + offset. Must keep anchor+offset within 1-9. */
  readonly offset?: number;

  // ── Universal ────────────────────────────────────────────────────────────
  /** Whether a Joker tile may substitute this slot during scoring. */
  readonly isJokerEligible: boolean;
  /** Number of tiles required at this position. 1=single 2=pair 3=pung 4=kong */
  readonly count: number;
}

export interface CustomHand {
  readonly id: string;
  readonly collectionId: string;
  /** Short internal label, e.g. "FF 2025 NEWS" */
  readonly name: string;
  /** User-facing notation, e.g. "FF 2 0 2 5 N E W S" */
  readonly displayLabel: string;
  readonly slots: TileSlot[];
  readonly pointValue?: number;
  /** True if the hand must remain concealed (no exposed melds). */
  readonly isConcealed: boolean;
  readonly tags: string[];
  readonly createdAt: number;
  readonly updatedAt: number;
}
