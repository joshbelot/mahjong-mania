import type { ConcreteTile, TileSuit, NumberSuit, NumberTileValue } from '../types/tiles';
import type { CustomHand, TileSlot, SuitGroupId, RunGroupId } from '../types/hands';
import type {
  HandScoringResult,
  SlotMatchResult,
  ProximityTier,
  ViewMode,
} from '../types/scoring';
import { tileKey, buildMultiset, cartesianProduct, groupBy, isNumberSuit } from '../utils/tileUtils';

const NUMBER_SUITS: NumberSuit[] = ['CRACKS', 'DOTS', 'BAMS'];

// ── Binding types ─────────────────────────────────────────────────────────────

interface Binding {
  suitBindings: Record<SuitGroupId, TileSuit>;
  runAnchors: Record<RunGroupId, NumberTileValue>;
}

// ── Slot resolution ───────────────────────────────────────────────────────────

function resolveSlot(slot: TileSlot, binding: Binding): ConcreteTile | null {
  switch (slot.kind) {
    case 'CONCRETE':
      return slot.concrete ?? null;

    case 'SUIT_FLEXIBLE': {
      const suit = binding.suitBindings[slot.suitGroupId!];
      if (!suit || !isNumberSuit(suit)) return null;
      return { suit, value: slot.flexValue! };
    }

    case 'RUN_ANCHOR': {
      const suit = binding.suitBindings[slot.runSuitGroupId!] ?? binding.suitBindings[slot.runGroupId!];
      const anchor = binding.runAnchors[slot.runGroupId!];
      if (!suit || !isNumberSuit(suit) || anchor === undefined) return null;
      return { suit, value: anchor };
    }

    case 'RUN_OFFSET': {
      // Find the anchor slot to get its suit + base value
      const anchorValue = binding.runAnchors[slot.runGroupRef!];
      if (anchorValue === undefined) return null;
      const computedValue = (anchorValue + (slot.offset ?? 0)) as NumberTileValue;
      if (computedValue < 1 || computedValue > 9) return null;
      // Suit inherited from the anchor's suit binding — stored using same runGroupRef key
      const suit = binding.suitBindings[slot.runGroupRef!];
      if (!suit || !isNumberSuit(suit)) return null;
      return { suit, value: computedValue };
    }

    case 'JOKER':
      return { suit: 'JOKER', value: 'JOKER' };

    default:
      return null;
  }
}

// ── Core distance calculator ──────────────────────────────────────────────────

export function calculateDistance(
  activeTiles: ConcreteTile[],
  hand: CustomHand,
): HandScoringResult {
  const jokerCount = activeTiles.filter((t) => t.suit === 'JOKER').length;
  const concretePool = buildMultiset(activeTiles.filter((t) => t.suit !== 'JOKER'));

  // ── Build candidate bindings ─────────────────────────────────────────────

  // SuitGroup candidates
  const suitGroupIds = [...new Set(
    hand.slots.flatMap((s) => [s.suitGroupId, s.runSuitGroupId, s.runGroupRef].filter(Boolean) as string[]),
  )];
  const suitCandidates: TileSuit[][] = suitGroupIds.map(() => NUMBER_SUITS);

  // RunGroup candidates
  const runGroupIds = [...new Set(
    hand.slots.filter((s) => s.kind === 'RUN_ANCHOR').map((s) => s.runGroupId!).filter(Boolean),
  )];
  const runGroupCandidates: NumberTileValue[][] = runGroupIds.map((rgId) => {
    const maxOffset = Math.max(
      0,
      ...hand.slots.filter((s) => s.kind === 'RUN_OFFSET' && s.runGroupRef === rgId).map((s) => s.offset ?? 0),
    );
    const maxAnchor = (9 - maxOffset) as NumberTileValue;
    return Array.from({ length: maxAnchor }, (_, i) => (i + 1) as NumberTileValue);
  });

  // Cartesian product of all candidates
  const allCombos = cartesianProduct(
    ([...suitCandidates, ...runGroupCandidates]) as (TileSuit | NumberTileValue)[][],
  ) as (TileSuit | NumberTileValue)[][];

  let bestDistance = Infinity;
  let bestBinding: Binding = { suitBindings: {}, runAnchors: {} };

  for (const combo of allCombos.length > 0 ? allCombos : [[]]) {
    const suitPart = combo.slice(0, suitGroupIds.length) as TileSuit[];
    const runPart = combo.slice(suitGroupIds.length) as NumberTileValue[];

    const binding: Binding = {
      suitBindings: Object.fromEntries(suitGroupIds.map((id, i) => [id, suitPart[i]])),
      runAnchors: Object.fromEntries(runGroupIds.map((id, i) => [id, runPart[i]])),
    };

    // Build requirements map under this binding
    const requirements = new Map<string, { needed: number; jokerEligible: boolean }>();
    for (const slot of hand.slots) {
      if (slot.kind === 'JOKER') continue; // literal joker slots don't consume pool tiles
      const resolved = resolveSlot(slot, binding);
      if (!resolved) continue;
      const k = tileKey(resolved);
      const existing = requirements.get(k) ?? { needed: 0, jokerEligible: false };
      requirements.set(k, {
        needed: existing.needed + slot.count,
        jokerEligible: existing.jokerEligible || slot.isJokerEligible,
      });
    }

    // Count literal JOKER slots required
    const literalJokersNeeded = hand.slots
      .filter((s) => s.kind === 'JOKER')
      .reduce((sum, s) => sum + s.count, 0);

    // Score this binding
    let distance = 0;
    let jokersLeft = jokerCount;
    const available = new Map(concretePool);

    for (const [k, { needed, jokerEligible }] of requirements) {
      const have = available.get(k) ?? 0;
      let deficit = Math.max(0, needed - have);
      available.set(k, Math.max(0, have - needed));

      if (deficit > 0 && jokerEligible) {
        const fill = Math.min(deficit, jokersLeft);
        jokersLeft -= fill;
        deficit -= fill;
      }
      distance += deficit;
    }

    // Remaining literal joker slots needed
    const jokersDeficit = Math.max(0, literalJokersNeeded - jokersLeft);
    distance += jokersDeficit;

    if (distance < bestDistance) {
      bestDistance = distance;
      bestBinding = binding;
    }
  }

  // ── Derive tilesNeeded and slotResults under bestBinding ──────────────────

  const tilesNeeded: ConcreteTile[] = [];
  const slotResults: SlotMatchResult[] = [];
  const working = new Map(concretePool);
  let jokersLeft = jokerCount;

  for (const slot of hand.slots) {
    if (slot.kind === 'JOKER') {
      const have = Math.min(slot.count, jokersLeft);
      jokersLeft -= have;
      const needed = slot.count - have;
      slotResults.push({ slotId: slot.id, isMatched: needed === 0 });
      if (needed > 0) {
        for (let i = 0; i < needed; i++) tilesNeeded.push({ suit: 'JOKER', value: 'JOKER' });
      }
      continue;
    }

    const resolved = resolveSlot(slot, bestBinding);
    if (!resolved) {
      slotResults.push({ slotId: slot.id, isMatched: false });
      continue;
    }

    const k = tileKey(resolved);
    const have = working.get(k) ?? 0;
    const deficit = Math.max(0, slot.count - have);
    working.set(k, Math.max(0, have - slot.count));

    let remainingDeficit = deficit;
    if (remainingDeficit > 0 && slot.isJokerEligible) {
      const fill = Math.min(remainingDeficit, jokersLeft);
      jokersLeft -= fill;
      remainingDeficit -= fill;
    }

    for (let i = 0; i < remainingDeficit; i++) tilesNeeded.push(resolved);
    slotResults.push({ slotId: slot.id, isMatched: remainingDeficit === 0, resolvedTile: resolved });
  }

  const tilesRemaining = 14 - activeTiles.length;
  const isImpossible = bestDistance > tilesRemaining;
  const isComplete = bestDistance === 0;

  const proximityTier: ProximityTier =
    bestDistance === 0 ? 'COMPLETE' :
    bestDistance === 1 ? 'ONE_AWAY' :
    bestDistance <= 3  ? 'CLOSE' : 'FAR';

  return {
    handId: hand.id,
    collectionId: hand.collectionId,
    distanceScore: bestDistance,
    tilesNeeded,
    slotResults,
    resolvedSuitBindings: bestBinding.suitBindings,
    resolvedRunAnchors: bestBinding.runAnchors,
    proximityTier,
    isImpossible,
    isComplete,
    canContainExposures: false, // computed by scoutFilter if needed
  };
}

// ── SCOUT mode helper ─────────────────────────────────────────────────────────

/**
 * Returns true if there exists at least one valid binding under which every
 * exposure tile can be matched to a slot in this hand.
 */
function canHandContainAllExposures(hand: CustomHand, exposures: ConcreteTile[]): boolean {
  if (exposures.length === 0) return true;

  const suitGroupIds = [...new Set(
    hand.slots.flatMap((s) => [s.suitGroupId, s.runSuitGroupId, s.runGroupRef].filter(Boolean) as string[]),
  )];
  const suitCandidates: TileSuit[][] = suitGroupIds.map(() => NUMBER_SUITS);
  const runGroupIds = [...new Set(
    hand.slots.filter((s) => s.kind === 'RUN_ANCHOR').map((s) => s.runGroupId!),
  )];
  const runGroupCandidates: NumberTileValue[][] = runGroupIds.map((rgId) => {
    const maxOffset = Math.max(
      0,
      ...hand.slots.filter((s) => s.kind === 'RUN_OFFSET' && s.runGroupRef === rgId).map((s) => s.offset ?? 0),
    );
    return Array.from({ length: 9 - maxOffset }, (_, i) => (i + 1) as NumberTileValue);
  });

  const allCombos = cartesianProduct(
    ([...suitCandidates, ...runGroupCandidates]) as (TileSuit | NumberTileValue)[][],
  ) as (TileSuit | NumberTileValue)[][];

  for (const combo of allCombos.length > 0 ? allCombos : [[]]) {
    const suitPart = combo.slice(0, suitGroupIds.length) as TileSuit[];
    const runPart = combo.slice(suitGroupIds.length) as NumberTileValue[];
    const binding: Binding = {
      suitBindings: Object.fromEntries(suitGroupIds.map((id, i) => [id, suitPart[i]])),
      runAnchors: Object.fromEntries(runGroupIds.map((id, i) => [id, runPart[i]])),
    };

    const resolvedKeys = new Set(
      hand.slots
        .map((s) => resolveSlot(s, binding))
        .filter(Boolean)
        .map((t) => tileKey(t!)),
    );

    const allExposuresAccountedFor = exposures.every((exp) => resolvedKeys.has(tileKey(exp)));
    if (allExposuresAccountedFor) return true;
  }

  return false;
}

// ── View mode filters ─────────────────────────────────────────────────────────

export function applyViewMode(
  results: HandScoringResult[],
  mode: ViewMode,
  activeTiles: ConcreteTile[],
  hands: CustomHand[],
): HandScoringResult[] {
  const handMap = new Map(hands.map((h) => [h.id, h]));

  switch (mode) {
    case 'ASSIST':
      return [...results].sort((a, b) => a.distanceScore - b.distanceScore);

    case 'FOCUS':
      return results
        .filter((r) => !r.isImpossible)
        .sort((a, b) => a.distanceScore - b.distanceScore);

    case 'SCOUT': {
      return results
        .map((r) => {
          const hand = handMap.get(r.handId);
          const canContain = hand ? canHandContainAllExposures(hand, activeTiles) : false;
          return { ...r, canContainExposures: canContain };
        })
        .filter((r) => r.canContainExposures)
        .sort((a, b) => a.distanceScore - b.distanceScore);
    }

    default:
      return results;
  }
}
