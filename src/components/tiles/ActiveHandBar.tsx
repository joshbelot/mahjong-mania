import React from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import type { ConcreteTile } from '../../types/tiles';
import { tileKey } from '../../utils/tileUtils';
import { TILE_SHORT_LABEL } from '../../constants/tiles';

const MAX_SLOTS = 14;

interface ActiveHandBarProps {
  tiles: ConcreteTile[];
  onRemoveTile: (index: number) => void;
  onReset: () => void;
}

export function ActiveHandBar({ tiles, onRemoveTile, onReset }: ActiveHandBarProps) {
  const slots = Array.from({ length: MAX_SLOTS }, (_, i) => tiles[i] ?? null);

  return (
    <View style={s.container}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={s.row}>
        {slots.map((tile, i) => (
          <Pressable
            key={i}
            style={[s.slot, tile ? s.filledSlot : s.emptySlot]}
            onPress={() => tile && onRemoveTile(i)}
            accessibilityLabel={tile ? `Remove ${TILE_SHORT_LABEL[tileKey(tile)] ?? tileKey(tile)}` : 'Empty slot'}
            accessibilityRole={tile ? 'button' : 'none'}
          >
            {tile ? (
              <Text style={s.tileText}>{TILE_SHORT_LABEL[tileKey(tile)] ?? tileKey(tile)}</Text>
            ) : (
              <Text style={s.emptyText}>·</Text>
            )}
          </Pressable>
        ))}
      </ScrollView>
      <Pressable style={s.resetBtn} onPress={onReset} accessibilityLabel="Reset hand" accessibilityRole="button">
        <Text style={s.resetText}>✕ Clear</Text>
      </Pressable>
    </View>
  );
}

const s = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1A1A2E',
    paddingVertical: 8,
    paddingHorizontal: 8,
  },
  row: {
    flexDirection: 'row',
    gap: 4,
    paddingRight: 4,
  },
  slot: {
    width: 36,
    height: 44,
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
  },
  filledSlot: {
    backgroundColor: '#2C3E70',
    borderColor: '#4A6CF7',
  },
  emptySlot: {
    backgroundColor: '#0D0D1A',
    borderColor: '#333',
  },
  tileText: {
    color: '#E0E0FF',
    fontSize: 10,
    fontWeight: '700',
  },
  emptyText: {
    color: '#444',
    fontSize: 18,
    fontWeight: '300',
  },
  resetBtn: {
    marginLeft: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
    backgroundColor: '#3D1010',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#8B2020',
  },
  resetText: {
    color: '#FF6B6B',
    fontSize: 11,
    fontWeight: '700',
  },
});
