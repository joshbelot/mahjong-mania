export type NumberTileValue = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;
export type WindValue = 'N' | 'S' | 'E' | 'W';
export type DragonValue = 'RED' | 'WHITE' | 'GREEN';
export type NumberSuit = 'CRACKS' | 'DOTS' | 'BAMS';
export type HonorSuit = 'WINDS' | 'DRAGONS';
export type TileSuit = NumberSuit | HonorSuit | 'JOKER';
export type TileValue = NumberTileValue | WindValue | DragonValue | 'JOKER';
/** Canonical string key. e.g. "CRACKS_3", "WINDS_N", "DRAGONS_RED", "JOKER" */
export type TileKey = string;

export interface ConcreteTile {
  readonly suit: TileSuit;
  readonly value: TileValue;
}
