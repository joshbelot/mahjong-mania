import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { ConcreteTile } from '../../types/tiles';
import { tileKey } from '../../utils/tileUtils';
import { TILE_SHORT_LABEL } from '../../constants/tiles';

// ── Suit colour palette ───────────────────────────────────────────────────────

const SUIT_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  CRACKS:  { bg: '#FFF3E0', text: '#E65100', border: '#FF9800' },
  DOTS:    { bg: '#E3F2FD', text: '#0D47A1', border: '#1E88E5' },
  BAMS:    { bg: '#E8F5E9', text: '#1B5E20', border: '#43A047' },
  WINDS:   { bg: '#F3E5F5', text: '#4A148C', border: '#8E24AA' },
  DRAGONS: { bg: '#FCE4EC', text: '#880E4F', border: '#E91E63' },
  JOKER:   { bg: '#FFFDE7', text: '#F57F17', border: '#FDD835' },
};

interface TileChipProps {
  tile: ConcreteTile;
  /** Count badge shown in the top-right corner (e.g. how many are in active hand). */
  badgeCount?: number;
  /** If true, the chip renders with reduced opacity (tile unavailable / capped). */
  dimmed?: boolean;
  onPress?: (tile: ConcreteTile) => void;
  size?: 'sm' | 'md' | 'lg';
}

export function TileChip({ tile, badgeCount, dimmed = false, onPress, size = 'md' }: TileChipProps) {
  const key = tileKey(tile);
  const label = TILE_SHORT_LABEL[key] ?? key;
  const colors = SUIT_COLORS[tile.suit] ?? SUIT_COLORS.JOKER;
  const dim = StyleSheet.flatten([s.chip, sizeStyle[size], { backgroundColor: colors.bg, borderColor: colors.border, opacity: dimmed ? 0.4 : 1 }]);

  return (
    <Pressable
      onPress={() => onPress?.(tile)}
      style={({ pressed }) => [dim, pressed && s.pressed]}
      accessibilityLabel={`Tile ${label}`}
      accessibilityRole="button"
    >
      <Text style={[s.label, { color: colors.text }, sizeLabelStyle[size]]}>
        {label}
      </Text>
      {badgeCount !== undefined && badgeCount > 0 && (
        <View style={s.badge}>
          <Text style={s.badgeText}>{badgeCount}</Text>
        </View>
      )}
    </Pressable>
  );
}

const sizeStyle: Record<string, object> = {
  sm: { width: 36, height: 44, borderRadius: 6 },
  md: { width: 44, height: 54, borderRadius: 8 },
  lg: { width: 54, height: 66, borderRadius: 10 },
};

const sizeLabelStyle: Record<string, object> = {
  sm: { fontSize: 10 },
  md: { fontSize: 13 },
  lg: { fontSize: 16 },
};

const s = StyleSheet.create({
  chip: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
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
