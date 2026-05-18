import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { ConcreteTile } from '../../types/tiles';
import { tileKey } from '../../utils/tileUtils';
import { TILE_SHORT_LABEL } from '../../constants/tiles';
import { TileSvg } from './TileSvg';


interface TileChipProps {
  tile: ConcreteTile;
  /** Count badge shown in the top-right corner (e.g. how many are in active hand). */
  badgeCount?: number;
  /** If true, the chip renders with reduced opacity (tile unavailable / capped). */
  dimmed?: boolean;
  onPress?: (tile: ConcreteTile) => void;
  size?: 'sm' | 'md' | 'lg';
}

const SIZE_DIMS: Record<'sm' | 'md' | 'lg', { width: number; height: number }> = {
  sm: { width: 36, height: 44 },
  md: { width: 44, height: 54 },
  lg: { width: 54, height: 66 },
};

export function TileChip({ tile, badgeCount, dimmed = false, onPress, size = 'md' }: TileChipProps) {
  const key = tileKey(tile);
  const label = TILE_SHORT_LABEL[key] ?? key;
  const { width, height } = SIZE_DIMS[size];

  return (
    <Pressable
      onPress={() => onPress?.(tile)}
      style={({ pressed }) => [s.chip, { width, height, opacity: dimmed ? 0.4 : 1 }, pressed && s.pressed]}
      accessibilityLabel={`Tile ${label}`}
      accessibilityRole="button"
    >
      <TileSvg tile={tile} width={width} height={height} />
      {badgeCount !== undefined && badgeCount > 0 && (
        <View style={s.badge}>
          <Text style={s.badgeText}>{badgeCount}</Text>
        </View>
      )}
    </Pressable>
  );
}

const s = StyleSheet.create({
  chip: {
    margin: 3,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.12,
    shadowRadius: 2,
  },
  pressed: {
    opacity: 0.65,
    transform: [{ scale: 0.94 }],
  },
  label: {
    fontWeight: '700',
    letterSpacing: 0.3,
  },
  badge: {
    position: 'absolute',
    top: 2,
    right: 2,
    backgroundColor: '#333',
    borderRadius: 7,
    width: 14,
    height: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: {
    color: '#FFF',
    fontSize: 9,
    fontWeight: '800',
  },
});
