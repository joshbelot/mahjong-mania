import React, { useMemo } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import type { ConcreteTile } from '../../types/tiles';
import { ALL_TILES, SUIT_DISPLAY_NAMES, SUIT_SECTION_ORDER } from '../../constants/tiles';
import { tileKey } from '../../utils/tileUtils';
import { TileChip } from './TileChip';

interface TileGridProps {
  onTilePress: (tile: ConcreteTile) => void;
  activeTiles: ConcreteTile[];
  /** When true, all tiles are dimmed (e.g. when active hand is full). */
  disabled?: boolean;
}

export function TileGrid({ onTilePress, activeTiles, disabled = false }: TileGridProps) {
  // Build a count map of active tiles for badge display
  const activeCountMap = useMemo(() => {
    const map = new Map<string, number>();
    for (const t of activeTiles) {
      const k = tileKey(t);
      map.set(k, (map.get(k) ?? 0) + 1);
    }
    return map;
  }, [activeTiles]);

  // Group ALL_TILES by suit in defined section order
  const sections = useMemo(() => {
    const bySection = new Map<string, ConcreteTile[]>();
    for (const suit of SUIT_SECTION_ORDER) bySection.set(suit, []);
    for (const tile of ALL_TILES) {
      bySection.get(tile.suit)?.push(tile);
    }
    return SUIT_SECTION_ORDER.map((suit) => ({
      suit,
      label: SUIT_DISPLAY_NAMES[suit],
      tiles: bySection.get(suit) ?? [],
    }));
  }, []);

  return (
    <ScrollView contentContainerStyle={s.container} showsVerticalScrollIndicator={false}>
      {sections.map((section) => (
        <View key={section.suit} style={s.section}>
          <Text style={s.sectionLabel}>{section.label}</Text>
          <View style={s.row}>
            {section.tiles.map((tile) => {
              const k = tileKey(tile);
              return (
                <TileChip
                  key={k}
                  tile={tile}
                  badgeCount={activeCountMap.get(k)}
                  dimmed={disabled}
                  onPress={disabled ? undefined : onTilePress}
                  size="md"
                />
              );
            })}
          </View>
        </View>
      ))}
    </ScrollView>
  );
}

const s = StyleSheet.create({
  container: {
    paddingHorizontal: 8,
    paddingBottom: 16,
  },
  section: {
    marginBottom: 10,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: '#666',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 4,
    marginLeft: 4,
  },
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
});
