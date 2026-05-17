import React, { useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useCollections } from '../../src/hooks/useCollections';
import { useActiveTiles } from '../../src/hooks/useActiveTiles';
import { useViewMode } from '../../src/hooks/useViewMode';
import { useScoringEngine } from '../../src/hooks/useScoringEngine';
import { TileGrid } from '../../src/components/tiles/TileGrid';
import { ActiveHandBar } from '../../src/components/tiles/ActiveHandBar';
import { ViewModeToggle } from '../../src/components/scoring/ViewModeToggle';
import { ScoredHandList } from '../../src/components/scoring/ScoredHandList';
import type { ConcreteTile } from '../../src/types/tiles';

export default function TrackerScreen() {
  const { collections, activeCollectionId, isLoading, setActiveCollection } = useCollections();
  const { activeTiles, addTile, removeTile, resetHand } = useActiveTiles();
  const { viewMode, setViewMode } = useViewMode();
  const scoredHands = useScoringEngine();
  const [showPicker, setShowPicker] = useState(false);

  const activeCollection = collections.find((c) => c.id === activeCollectionId) ?? null;

  function handleTilePress(tile: ConcreteTile) {
    addTile(tile);
  }

  return (
    <View style={s.root}>
      {/* Collection picker bar */}
      <Pressable style={s.pickerBar} onPress={() => setShowPicker((v) => !v)} accessibilityRole="button">
        <Text style={s.pickerLabel} numberOfLines={1}>
          {isLoading ? 'Loading…' : (activeCollection?.name ?? 'No collection selected')}
        </Text>
        <Text style={s.pickerChevron}>{showPicker ? '▴' : '▾'}</Text>
      </Pressable>

      {showPicker && (
        <View style={s.pickerDropdown}>
          <ScrollView style={s.pickerScroll}>
            {collections.map((c) => (
              <Pressable
                key={c.id}
                style={[s.pickerOption, c.id === activeCollectionId && s.pickerOptionActive]}
                onPress={() => {
                  setActiveCollection(c.id);
                  setShowPicker(false);
                }}
                accessibilityRole="radio"
                accessibilityState={{ checked: c.id === activeCollectionId }}
              >
                <Text style={[s.pickerOptionText, c.id === activeCollectionId && s.pickerOptionTextActive]}>
                  {c.name}
                </Text>
                <Text style={s.pickerOptionCount}>{c.hands.length} hands</Text>
              </Pressable>
            ))}
          </ScrollView>
        </View>
      )}

      <ViewModeToggle current={viewMode} onChange={setViewMode} />

      {/* Scored results */}
      <View style={s.listContainer}>
        <ScoredHandList
          results={scoredHands}
          collection={activeCollection}
        />
      </View>

      {/* Tile input */}
      <ActiveHandBar
        tiles={activeTiles}
        onRemoveTile={(i) => removeTile(i)}
        onReset={resetHand}
      />

      <View style={s.gridContainer}>
        <TileGrid
          onTilePress={handleTilePress}
          activeTiles={activeTiles}
          disabled={activeTiles.length >= 14}
        />
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
  pickerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#1C1C2E',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#2A2A2A',
  },
  pickerLabel: { color: '#DDD', fontSize: 14, fontWeight: '600', flex: 1 },
  pickerChevron: { color: '#777', fontSize: 12, marginLeft: 8 },
  pickerDropdown: {
    position: 'absolute',
    top: 50,
    left: 0,
    right: 0,
    zIndex: 100,
    backgroundColor: '#1A1A2E',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
    maxHeight: 220,
    elevation: 8,
    shadowColor: '#000',
    shadowOpacity: 0.4,
    shadowRadius: 8,
  },
  pickerScroll: {},
  pickerOption: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  pickerOptionActive: { backgroundColor: '#161630' },
  pickerOptionText: { color: '#BBB', fontSize: 14 },
  pickerOptionTextActive: { color: '#7C9FF7', fontWeight: '700' },
  pickerOptionCount: { color: '#555', fontSize: 12 },
  listContainer: { flex: 1 },
  gridContainer: { maxHeight: 260 },
});
