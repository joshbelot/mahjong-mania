import type { ConcreteTile, TileKey, TileSuit, NumberSuit } from '../types/tiles';

/** Canonical string key for a tile, e.g. "CRACKS_3", "WINDS_N", "JOKER" */
export function tileKey(tile: ConcreteTile): TileKey {
  if (tile.suit === 'JOKER') return 'JOKER';
  return `${tile.suit}_${tile.value}`;
}

/** Builds a multiset (Map of key → count) from a tile array. */
export function buildMultiset(tiles: ConcreteTile[]): Map<TileKey, number> {
  const map = new Map<TileKey, number>();
  for (const tile of tiles) {
    const k = tileKey(tile);
    map.set(k, (map.get(k) ?? 0) + 1);
  }
  return map;
}

/** Returns the cartesian product of an array of arrays. */
export function cartesianProduct<T>(arrays: T[][]): T[][] {
  if (arrays.length === 0) return [[]];
  const [first, ...rest] = arrays;
  const restProduct = cartesianProduct(rest);
  return first.flatMap((item) => restProduct.map((combo) => [item, ...combo]));
}

/** True if a suit is a number suit (can pair with numeric tile values). */
export function isNumberSuit(suit: TileSuit): suit is NumberSuit {
  return suit === 'CRACKS' || suit === 'DOTS' || suit === 'BAMS';
}

/** Groups an array by a key-extraction function. */
export function groupBy<T>(items: T[], key: (item: T) => string): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const k = key(item);
    if (!map.has(k)) map.set(k, []);
    map.get(k)!.push(item);
  }
  return map;
}
