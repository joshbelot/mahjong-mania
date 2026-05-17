import type { ConcreteTile, TileSuit, NumberTileValue } from './tiles';
import type { SuitGroupId, RunGroupId } from './hands';

export type ViewMode = 'ASSIST' | 'FOCUS' | 'SCOUT';
export type ProximityTier = 'COMPLETE' | 'ONE_AWAY' | 'CLOSE' | 'FAR';

export interface SlotMatchResult {
  readonly slotId: string;
  readonly isMatched: boolean;
  /** The concrete tile this slot resolves to under the best scoring binding. */
  readonly resolvedTile?: ConcreteTile;
}

export interface HandScoringResult {
  readonly handId: string;
  readonly collectionId: string;
  /** Number of tiles still needed to complete this hand. 0 = complete. */
  readonly distanceScore: number;
  /** Exact list of tiles still required (under the best binding). */
  readonly tilesNeeded: ConcreteTile[];
  readonly slotResults: SlotMatchResult[];
  readonly resolvedSuitBindings: Partial<Record<SuitGroupId, TileSuit>>;
  readonly resolvedRunAnchors: Partial<Record<RunGroupId, NumberTileValue>>;
  readonly proximityTier: ProximityTier;
  /** True when distanceScore > tiles remaining to draw (mathematically impossible). */
  readonly isImpossible: boolean;
  readonly isComplete: boolean;
  /** Used in SCOUT mode: can this hand legally contain all active (exposed) tiles? */
  readonly canContainExposures: boolean;
}

export interface ScoringSession {
  readonly activeTiles: ConcreteTile[];
  readonly viewMode: ViewMode;
  readonly collectionId: string;
  readonly results: HandScoringResult[];
  /** 14 minus activeTiles.length */
  readonly tilesRemaining: number;
}
