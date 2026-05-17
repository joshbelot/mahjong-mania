import type { ConcreteTile, NumberSuit, TileSuit, WindValue, DragonValue, TileKey } from '../types/tiles';

// ── Number suits ─────────────────────────────────────────────────────────────

export const NUMBER_SUITS: NumberSuit[] = ['CRACKS', 'DOTS', 'BAMS'];

export const NUMBER_VALUES = [1, 2, 3, 4, 5, 6, 7, 8, 9] as const;

// ── Honor tiles ───────────────────────────────────────────────────────────────

export const WIND_VALUES: WindValue[] = ['E', 'S', 'W', 'N'];

export const DRAGON_VALUES: DragonValue[] = ['RED', 'WHITE', 'GREEN'];

// ── Tile pool (4 of each number tile + honors, 8 jokers) ─────────────────────

export const ALL_NUMBER_TILES: ConcreteTile[] = NUMBER_SUITS.flatMap((suit) =>
  NUMBER_VALUES.map((value) => ({ suit, value } as ConcreteTile)),
);

export const ALL_WIND_TILES: ConcreteTile[] = WIND_VALUES.map((value) => ({
  suit: 'WINDS' as const,
  value,
}));

export const ALL_DRAGON_TILES: ConcreteTile[] = DRAGON_VALUES.map((value) => ({
  suit: 'DRAGONS' as const,
  value,
}));

export const JOKER_TILE: ConcreteTile = { suit: 'JOKER', value: 'JOKER' };

/** All unique tile types (one of each). Used to build TileGrid. */
export const ALL_TILES: ConcreteTile[] = [
  ...ALL_NUMBER_TILES,
  ...ALL_WIND_TILES,
  ...ALL_DRAGON_TILES,
  JOKER_TILE,
];

// ── Display metadata ──────────────────────────────────────────────────────────

export const SUIT_DISPLAY_NAMES: Record<TileSuit, string> = {
  CRACKS: 'Cracks',
  DOTS: 'Dots',
  BAMS: 'Bams',
  WINDS: 'Winds',
  DRAGONS: 'Dragons',
  JOKER: 'Joker',
};

export const SUIT_SECTION_ORDER: TileSuit[] = [
  'CRACKS',
  'DOTS',
  'BAMS',
  'WINDS',
  'DRAGONS',
  'JOKER',
];

/** Short text labels used as fallback when SVG assets are unavailable. */
export const TILE_SHORT_LABEL: Record<string, string> = {
  // Number tiles
  CRACKS_1: '1C', CRACKS_2: '2C', CRACKS_3: '3C',
  CRACKS_4: '4C', CRACKS_5: '5C', CRACKS_6: '6C',
  CRACKS_7: '7C', CRACKS_8: '8C', CRACKS_9: '9C',
  DOTS_1: '1D', DOTS_2: '2D', DOTS_3: '3D',
  DOTS_4: '4D', DOTS_5: '5D', DOTS_6: '6D',
  DOTS_7: '7D', DOTS_8: '8D', DOTS_9: '9D',
  BAMS_1: '1B', BAMS_2: '2B', BAMS_3: '3B',
  BAMS_4: '4B', BAMS_5: '5B', BAMS_6: '6B',
  BAMS_7: '7B', BAMS_8: '8B', BAMS_9: '9B',
  // Honors
  WINDS_E: 'E', WINDS_S: 'S', WINDS_W: 'W', WINDS_N: 'N',
  DRAGONS_RED: 'RD', DRAGONS_WHITE: 'WD', DRAGONS_GREEN: 'GD',
  JOKER: 'JKR',
};

/** Builds the canonical TileKey for a ConcreteTile. */
export function tileKey(tile: ConcreteTile): TileKey {
  if (tile.suit === 'JOKER') return 'JOKER';
  return `${tile.suit}_${tile.value}`;
}

/** Parses a TileKey back into a ConcreteTile. Returns null for unrecognised keys. */
export function parseTileKey(key: TileKey): ConcreteTile | null {
  if (key === 'JOKER') return { suit: 'JOKER', value: 'JOKER' };
  const idx = key.indexOf('_');
  if (idx === -1) return null;
  const suit = key.slice(0, idx) as ConcreteTile['suit'];
  const rawValue = key.slice(idx + 1);
  const value = isNaN(Number(rawValue)) ? rawValue : (Number(rawValue) as ConcreteTile['value']);
  return { suit, value } as ConcreteTile;
}
