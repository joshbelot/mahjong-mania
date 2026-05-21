import type { TileSlot } from '../types/hands';
import type { NumberTileValue, DragonValue, WindValue } from '../types/tiles';
import type { ColorLabel, GroupDef } from '../types/hands';

// Re-export so existing imports (GroupChip, NotationHandEditor, etc.) keep working.
export type { ColorLabel, GroupDef };

// ── Public types ─────────────────────────────────────────────────────
// ColorLabel and GroupDef are defined in types/hands.ts to avoid a circular
// import (notationParser imports TileSlot from types/hands).

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Returns true if the digit characters in `token` form a strictly ascending consecutive
 * sequence (each digit exactly 1 more than the previous) with at least 2 digits.
 */
export function detectIsConsecutive(token: string): boolean {
  const digits = token.replace(/[^1-9]/g, '');
  if (digits.length < 2) return false;
  for (let i = 1; i < digits.length; i++) {
    if (parseInt(digits[i], 10) !== parseInt(digits[i - 1], 10) + 1) return false;
  }
  return true;
}

function colorToSuitGroupId(colorLabel: ColorLabel, groupIndex: number): string {
  switch (colorLabel) {
    case 'RED':  return 'SG_A';
    case 'GREEN': return 'SG_B';
    case 'BLUE':  return 'SG_C';
    case 'GRAY':  return `SG_GRAY_${groupIndex}`;
  }
}

function makeSlotId(): string {
  return `sl_${Math.random().toString(36).slice(2, 9)}`;
}

// ── Core parser ───────────────────────────────────────────────────────────────

/**
 * Parse a single notation group (one space-separated token + its options) into
 * an array of TileSlots compatible with the ScoringEngine.
 *
 * Token character guide:
 *   1-9   → number tile (SUIT_FLEXIBLE or RUN_ANCHOR/OFFSET)
 *   D     → Dragon (CONCRETE, type from dragonType)
 *   N E S W → individual Wind tiles (CONCRETE)
 *   J     → Joker slot
 *   F     → Flower — treated as Joker (no FLOWERS suit type yet)
 */
export function parseNotationGroup(group: GroupDef, groupIndex: number): TileSlot[] {
  const { token, colorLabel, isConsecRun, dragonType } = group;
  const upper = token.toUpperCase();
  const slots: TileSlot[] = [];

  // ── Joker / Flower ────────────────────────────────────────────────────────
  const jokerCount = (upper.match(/[JF]/g) ?? []).length;
  if (jokerCount > 0) {
    slots.push({
      id: makeSlotId(),
      kind: 'JOKER',
      isJokerEligible: false,
      count: jokerCount,
    });
  }

  // ── Wind tiles (N, E, W, S) ───────────────────────────────────────────────
  const windChars = (upper.match(/[NESW]/g) ?? []) as WindValue[];
  for (const w of windChars) {
    slots.push({
      id: makeSlotId(),
      kind: 'CONCRETE',
      concrete: { suit: 'WINDS', value: w },
      isJokerEligible: false,
      count: 1,
    });
  }

  // ── Dragon tiles (D) ──────────────────────────────────────────────────────
  const dragonCount = (upper.match(/D/g) ?? []).length;
  if (dragonCount > 0) {
    slots.push({
      id: makeSlotId(),
      kind: 'CONCRETE',
      concrete: { suit: 'DRAGONS', value: dragonType },
      isJokerEligible: false,
      count: dragonCount,
    });
  }

  // ── Number tiles (digits 1-9) ─────────────────────────────────────────────
  const digitChars = (upper.match(/[1-9]/g) ?? []).map(Number) as NumberTileValue[];
  if (digitChars.length === 0) return slots;

  const allSame = digitChars.every((d) => d === digitChars[0]);

  if (allSame) {
    // Pung / pair / kong / single — all the same value
    slots.push({
      id: makeSlotId(),
      kind: 'SUIT_FLEXIBLE',
      flexValue: digitChars[0],
      suitGroupId: colorToSuitGroupId(colorLabel, groupIndex),
      isJokerEligible: true,
      count: digitChars.length,
    });
  } else if (detectIsConsecutive(upper) && isConsecRun) {
    // Any consecutive run of the detected length (RUN_ANCHOR + RUN_OFFSETs)
    // runGroupId is unique per run group; offsets use it for both value + suit lookup.
    const runGroupId = `RG_${groupIndex}`;
    slots.push({
      id: makeSlotId(),
      kind: 'RUN_ANCHOR',
      runGroupId,
      runSuitGroupId: runGroupId, // offsets look up suit via runGroupRef === runGroupId
      isJokerEligible: true,
      count: 1,
    });
    for (let i = 1; i < digitChars.length; i++) {
      slots.push({
        id: makeSlotId(),
        kind: 'RUN_OFFSET',
        runGroupRef: runGroupId,
        offset: i,
        isJokerEligible: true,
        count: 1,
      });
    }
  } else {
    // Fixed specific values (non-consecutive, or consecutive but marked as fixed)
    const suitGroupId = colorToSuitGroupId(colorLabel, groupIndex);
    for (const val of digitChars) {
      // Aggregate repeated digits into a single slot (e.g. "112" → one count-2 slot for 1 + one for 2)
      const existingIdx = slots.findIndex(
        (s) => s.kind === 'SUIT_FLEXIBLE' && s.flexValue === val && s.suitGroupId === suitGroupId,
      );
      if (existingIdx >= 0) {
        const prev = slots[existingIdx];
        slots[existingIdx] = { ...prev, count: prev.count + 1 };
      } else {
        slots.push({
          id: makeSlotId(),
          kind: 'SUIT_FLEXIBLE',
          flexValue: val,
          suitGroupId,
          isJokerEligible: true,
          count: 1,
        });
      }
    }
  }

  return slots;
}

/**
 * Parse an array of GroupDefs into a flat TileSlot array for use in a CustomHand.
 */
export function parseFullNotation(groups: GroupDef[]): TileSlot[] {
  return groups.flatMap((g, i) => parseNotationGroup(g, i));
}
